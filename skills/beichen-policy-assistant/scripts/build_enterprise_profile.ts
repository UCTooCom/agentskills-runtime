#!/usr/bin/env node
/**
 * build_enterprise_profile.ts — 产业政策智能体 Step 1: 全景企业画像
 * 功能与 build_enterprise_profile.py 完全一致
 *
 * 运行方式: node --experimental-strip-types build_enterprise_profile.ts --company "北京XXX科技有限公司"
 */
import * as path from "path";
import * as fs from "fs";
import { spawnSync } from "child_process";

const __dirname = import.meta.dirname;

/* ---------------------------------------------------------------------------
 * T-12：缺失字段经检索采集并标来源，禁止编造（REQ-PD-020/021、spec §6.5 第 2 条）
 *   - 外部信息不可用时调用 yuanbao-search（--industry news）补采；
 *   - 每条属性在 field_sources 中记录采集通道（预填 / 检索采集 / 未获取）；
 *   - 检索失败或证据不足时字段留空，绝不用推测值填充。
 * ------------------------------------------------------------------------- */

/** 可被检索补采的字段（画像路径 ↔ 中文名） */
const SEARCHABLE_FIELDS: Array<[string, string]> = [
  ["business.registered_capital", "注册资本"],
  ["business.established_time", "成立日期"],
  ["business.legal_representative", "法定代表人"],
  ["business.business_scope", "经营范围"],
  ["operation.scale", "企业规模"],
  ["operation.products", "产品/业务"],
  ["industry", "所属行业"],
  ["qualification", "资质认定"],
];

/** 检索脚本路径（TS 版在本脚本内调用同语言版本，保证行为一致） */
function searchScript(): string {
  return path.join(__dirname, "..", "..", "yuanbao-search", "scripts", "yuanbao_search.ts");
}

function getByPath(obj: any, p: string): any {
  return p.split(".").reduce((o: any, k: string) => (o == null ? o : o[k]), obj);
}

function setByPath(obj: any, p: string, v: any): void {
  const ks = p.split(".");
  let cur = obj;
  for (let i = 0; i < ks.length - 1; i++) {
    if (cur[ks[i]] == null) cur[ks[i]] = {};
    cur = cur[ks[i]];
  }
  cur[ks[ks.length - 1]] = v;
}

function isBlank(v: any): boolean {
  if (Array.isArray(v)) return v.length === 0;
  const s = String(v ?? "").trim();
  return !s || s === "待补充" || s === "待核实";
}

/**
 * 调用 yuanbao-search 检索补采。失败返回空证据（降级不中断，G11）。
 */
function runYuanbaoSearch(company: string, fields: string[]): { evidence: any[]; warnings: string[]; requestId: string } {
  const warnings: string[] = [];
  if (!fields.length) return { evidence: [], warnings, requestId: "" };
  const script = searchScript();
  if (!fs.existsSync(script)) {
    warnings.push(`检索脚本不存在，跳过补采：${script}`);
    return { evidence: [], warnings, requestId: "" };
  }
  const query = `${company} ${fields.join(" ")}`;
  const res = spawnSync(
    process.execPath,
    ["--experimental-strip-types", script, "--query", query, "--industry", "news", "--cnt", "5", "--no-kb"],
    { encoding: "utf-8", timeout: 90000, maxBuffer: 20 * 1024 * 1024 }
  );
  if (res.error) {
    warnings.push(`检索补采失败，字段留空：${res.error.message}`);
    return { evidence: [], warnings, requestId: "" };
  }
  const out = String(res.stdout || "").trim();
  if (!out) {
    warnings.push("检索补采无输出（可能配额受限或网络异常），字段留空");
    return { evidence: [], warnings, requestId: "" };
  }
  let data: any = null;
  try {
    data = JSON.parse(out);
  } catch {
    warnings.push("检索补采输出无法解析，字段留空");
    return { evidence: [], warnings, requestId: "" };
  }
  if (data && data.ok === false) {
    warnings.push(`检索通道降级（${data.error || "未知原因"}），字段留空`);
  }
  const evidence: any[] = [];
  for (const it of ((data && data.items) || [])) {
    evidence.push({
      title: it.title || "",
      url: it.url || "",
      site: it.site || "",
      date: it.date || "",
      passage: String(it.passage || "").slice(0, 500),
      status: (it.credibility && it.credibility.status) || "",
    });
  }
  return { evidence, warnings, requestId: (data && data.requestId) || "" };
}

/**
 * 从检索证据中抽取字段：仅在 LLM 可用时执行，且**只填证据中明确出现的字段**。
 * 返回 { filled: { 路径: {value, ref} }, note }。
 */
async function extractFromEvidence(company: string, evidence: any[], fields: string[]): Promise<any> {
  if (!evidence.length || !fields.length) return { filled: {}, note: "" };
  if (!llmAvailable()) {
    return { filled: {}, note: "未配置 LLM，检索证据仅存档，字段保持未获取（禁止推测填充）" };
  }
  const want = SEARCHABLE_FIELDS.filter(([p]) => fields.includes(p));
  const evidenceText = evidence
    .map((e, i) => `[${i + 1}] 标题：${e.title}\n链接：${e.url}\n摘要：${e.passage}`)
    .join("\n\n");
  const prompt =
    "下面是关于企业「" + company + "」的公开检索结果。请只抽取**证据中明确写出**的字段；\n"
    + "证据中没有的字段一律返回 null，禁止推测、禁止编造、禁止用行业常识补全。\n"
    + "返回 JSON（不要任何多余文字）：{\"注册资本\": {\"value\": \"...\"或null, \"ref\": \"证据编号\"}, ...}\n"
    + "需要抽取的字段：" + want.map(([, cn]) => cn).join("、") + "\n\n"
    + "检索证据：\n" + evidenceText;
  try {
    const out = await callLlm(prompt, "你是企业信息抽取助手。只依据给定证据抽取，证据没有的一律返回 null。");
    const m = out.match(/\{[\s\S]*\}/);
    if (!m) throw new Error("LLM 未返回 JSON");
    const data = JSON.parse(m[0]);
    const filled: Record<string, { value: any; ref: string }> = {};
    for (const [p, cn] of want) {
      const cell = data[cn];
      const val = cell && typeof cell === "object" ? cell.value : cell;
      if (val === null || val === undefined) continue;
      const s = String(val).trim();
      if (!s || s === "待补充" || s === "null") continue;
      const refIdx = cell && typeof cell === "object" && cell.ref ? String(cell.ref) : "";
      const e = evidence[Number(refIdx.replace(/\D/g, "")) - 1];
      filled[p] = { value: s, ref: e ? e.url : "" };
    }
    return { filled, note: "" };
  } catch (e: any) {
    return { filled: {}, note: `证据抽取失败（${e && e.message ? e.message : e}），字段保持未获取` };
  }
}
const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地日期 YYYY-MM-DD（对齐 Python datetime.now()，Python 用本地时间）
function localDateStr(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function parseArgs(): Record<string, string | boolean> {
  const args: Record<string, string | boolean> = {};
  for (let i = 2; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = process.argv[i + 1];
      if (next && !next.startsWith("--")) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    }
  }
  return args;
}

function defaultOutdir(): string {
  return path.normalize(path.join(__dirname, "..", "output", "profiles"));
}

function makeSlug(companyName: string): string {
  let s = (companyName || "").replace(/[\s\u3000]+/g, "");
  s = s.replace(/[()（）【】\[\]《》·,.，。、/\\:：;；'"""']/g, "");
  return s || "company";
}

function llmAvailable(): boolean {
  return Boolean(process.env.LLM_API_KEY || process.env.OPENAI_API_KEY);
}

async function callLlm(prompt: string, system: string): Promise<string> {
  const base = process.env.LLM_BASE_URL || process.env.OPENAI_BASE_URL || "https://api-ai.gitcode.com/v1";
  const key = process.env.LLM_API_KEY || process.env.OPENAI_API_KEY || "sk-dummy-key";
  const model = process.env.LLM_MODEL || "deepseek-flash";
  const url = `${base.replace(/\/$/, "")}/chat/completions`;
  const payload = {
    model,
    stream: false,
    messages: [
      { role: "system", content: system },
      { role: "user", content: prompt },
    ],
  };
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(120000), // 对齐 py timeout=120
  });
  if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
  const data = await resp.json();
  const choices = data.choices || [];
  if (!choices.length) throw new Error("LLM 返回空 choices");
  return choices[0].message?.content || "";
}

function buildSkeleton(companyName: string, prefill: Record<string, any>): Record<string, any> {
  return {
    company_name: companyName,
    slug: makeSlug(companyName),
    region: prefill.region || "北京市朝阳区",
    industry: prefill.industry || [],
    qualification: prefill.qualification || [],
    stage: prefill.stage || "待核实",
    business: {
      registered_capital: prefill.registered_capital || "待补充",
      established_time: prefill.established_time || "待补充",
      legal_representative: prefill.legal_representative || "待补充",
      business_scope: prefill.business_scope || "待补充",
    },
    operation: {
      scale: prefill.scale || "待补充",
      products: prefill.products || "待补充",
      qualifications: prefill.qualifications || [],
    },
    public_opinion: {
      positive: prefill.positive || [],
      negative: prefill.negative || [],
      neutral: prefill.neutral || [],
    },
    profile_date: localDateStr(),
    source_note: "公开信息聚合（工商/经营/舆情，未获取字段已标记待补充）",
    pending_fields: [],
    // T-12：采集通道留痕（预填 / 检索采集 / 未获取）
    field_sources: {},
    search_evidence: [],
    search_meta: { used: false, request_id: "", channel: "", note: "" },
  };
}

/** T-12：为已填/未填字段打来源标记 */
function markSources(profile: Record<string, any>, prefill: Record<string, any>): void {
  const src: Record<string, string> = {};
  for (const [p] of SEARCHABLE_FIELDS) {
    const v = getByPath(profile, p);
    if (!isBlank(v)) {
      src[p] = Object.prototype.hasOwnProperty.call(prefill, p.split(".").pop() || "") ? "预填" : "原接口";
    } else {
      src[p] = "未获取";
    }
  }
  profile.field_sources = src;
}

function fillPending(profile: Record<string, any>): void {
  const pend: string[] = [];
  if (profile.business.registered_capital === "待补充") pend.push("注册资本");
  if (profile.business.established_time === "待补充") pend.push("成立日期");
  if (profile.business.business_scope === "待补充") pend.push("经营范围");
  if (profile.operation.scale === "待补充") pend.push("企业规模");
  if (profile.operation.products === "待补充") pend.push("产品/业务");
  if (!profile.industry.length) pend.push("所属行业");
  if (!profile.qualification.length) pend.push("资质认定");
  profile.pending_fields = pend;
}

async function summarize(profile: Record<string, any>): Promise<string> {
  const infoText = {
    企业: profile.company_name,
    注册区域: profile.region,
    所属行业: profile.industry.join("、") || "待核实",
    资质: profile.qualification.join("、") || "暂无",
    注册资本: profile.business.registered_capital,
    成立日期: profile.business.established_time,
    经营范围: profile.business.business_scope,
    规模: profile.operation.scale,
    产品: profile.operation.products,
  };
  if (llmAvailable()) {
    const prompt = "请基于以下企业公开信息，生成一段不超过 120 字的企业画像摘要（不含法律意见）。\n" + JSON.stringify(infoText, null, 2);
    try {
      const out = await callLlm(prompt, "你是园区产业服务助理，负责提炼企业画像要点，输出简洁客观。");
      if (out.trim()) return out.trim();
    } catch (e: any) {
      console.error(`LLM 萃取失败，降级规则组装: ${e}`);
    }
  }
  const parts: string[] = [profile.company_name, "注册于" + profile.region];
  if (profile.industry.length) parts.push("属于" + profile.industry.join("、") + "行业");
  if (profile.qualification.length) parts.push("具备" + profile.qualification.join("、"));
  if (profile.business.registered_capital !== "待补充") parts.push("注册资本" + String(profile.business.registered_capital));
  return parts[parts.length - 1].endsWith("。") ? parts.join("，") : parts.join("，") + "。";
}

function renderMd(profile: Record<string, any>): string {
  const lines = [
    `# 企业画像 - ${profile.company_name}`, "",
    `- 注册区域：${profile.region}`,
    `- 所属行业：${profile.industry.join("、") || "待核实"}`,
    `- 企业资质：${profile.qualification.join("、") || "暂无"}`,
    `- 发展阶段：${profile.stage}`, "",
    "## 工商信息", "",
    `- 注册资本：${profile.business.registered_capital}`,
    `- 成立日期：${profile.business.established_time}`,
    `- 法定代表人：${profile.business.legal_representative}`,
    `- 经营范围：${profile.business.business_scope}`, "",
    "## 经营信息", "",
    `- 企业规模：${profile.operation.scale}`,
    `- 产品/业务：${profile.operation.products}`, "",
    "## 舆情信息", "",
    `- 正面：${profile.public_opinion.positive.join("、") || "无"}`,
    `- 负面：${profile.public_opinion.negative.join("、") || "无"}`, "",
    "## 采集来源（T-12：每条属性的采集通道）", "",
    ...SEARCHABLE_FIELDS.map(([p, cn]) => `- ${cn}：${(profile.field_sources || {})[p] || "未记录"}`),
    ...(((profile.search_evidence || []).length)
      ? ["", "检索证据：", ...(profile.search_evidence as any[]).slice(0, 5).map((e: any, i: number) => `- [${i + 1}] [${e.title || e.url}](${e.url})（${e.site || ""} ${e.date || ""}）`)]
      : []), "",
    "## 画像摘要", "", profile.summary, "",
    `> 生成日期：${profile.profile_date}；${profile.source_note}`,
  ];
  return lines.join("\n");
}

async function main() {
  const args = parseArgs();
  const company = typeof args.company === "string" ? args.company : "";
  const outdir = typeof args.outdir === "string" ? args.outdir : defaultOutdir();
  const data = typeof args.data === "string" ? args.data : null;

  // T-12 / spec §5.3.3 第 1 条：企业名称为必填项，缺失以非零状态退出
  if (!company || !company.trim()) {
    console.error("错误: --company 不能为空（企业名称为必填项）");
    process.exit(2);
  }

  const companies = company.split(/[,，;；]/).map((c) => c.trim()).filter(Boolean);
  if (!companies.length) {
    console.error("错误: --company 不能为空（企业名称为必填项）");
    process.exit(2);
  }

  const prefillMap: Record<string, any> = {};
  if (data) {
    let raw: any = null;
    if (fs.existsSync(data)) {
      raw = JSON.parse(fs.readFileSync(data, "utf-8"));
    } else {
      try {
        raw = JSON.parse(data);
      } catch {
        raw = null;
      }
    }
    if (raw !== null) {
      let items: any[] = [];
      if (Array.isArray(raw)) items = raw;
      else if (typeof raw === "object" && "companies" in raw) items = raw.companies;
      else if (typeof raw === "object") items = [raw];
      for (const it of items) {
        if (typeof it === "object" && it !== null) {
          prefillMap[it.company_name || ""] = it;
        }
      }
    }
  }

  fs.mkdirSync(outdir, { recursive: true });
  const results: any[] = [];
  for (const name of companies) {
    const slug = makeSlug(name);
    const prefill = prefillMap[name] || {};
    const profile = buildSkeleton(name, prefill);
    fillPending(profile);
    markSources(profile, prefill);

    // T-12：对缺失字段走检索补采；失败不中断，字段留空
    const noSearch = args["no-search"] === true || args["no-search"] === "true";
    if (!noSearch) {
      const wantPaths = profile.pending_fields
        .map((cn: string) => (SEARCHABLE_FIELDS.find(([, c]) => c === cn) || ["", ""])[0])
        .filter(Boolean);
      if (wantPaths.length) {
        const r = runYuanbaoSearch(name, wantPaths.map((p) => (SEARCHABLE_FIELDS.find(([pp]) => pp === p) || ["", ""])[1]));
        profile.search_evidence = r.evidence;
        profile.search_meta = {
          used: true,
          request_id: r.requestId,
          channel: "yuanbao-search",
          note: r.warnings.concat(r.evidence.length ? [] : ["检索无可用证据"]).join("；"),
        };
        if (r.evidence.length) {
          const ex = await extractFromEvidence(name, r.evidence, wantPaths);
          for (const [p, cell] of Object.entries(ex.filled)) {
            const cur = getByPath(profile, p);
            if (isBlank(cur)) {
              setByPath(profile, p, (cell as any).value);
              profile.field_sources[p] = (cell as any).ref ? `检索采集（${(cell as any).ref}）` : "检索采集";
            }
          }
          if (ex.note) {
            profile.search_meta.note = [profile.search_meta.note, ex.note].filter(Boolean).join("；");
          }
          fillPending(profile); // 抽取后重算待补充清单
        }
      }
    } else {
      profile.search_meta = { used: false, request_id: "", channel: "", note: "已通过 --no-search 关闭检索补采" };
    }

    profile.summary = await summarize(profile);
    const jpath = path.join(outdir, `${slug}.json`);
    const mpath = path.join(outdir, `${slug}.md`);
    fs.writeFileSync(jpath, JSON.stringify(profile, null, 2), "utf-8");
    fs.writeFileSync(mpath, renderMd(profile), "utf-8");
    results.push({
      company: name, slug, profile_json: jpath, profile_md: mpath,
      pending_fields: profile.pending_fields,
      field_sources: profile.field_sources,
      search_evidence_count: (profile.search_evidence || []).length,
    });
  }

  console.log(JSON.stringify({
    success: true, count: results.length, profiles: results,
    output: results.length === 1 ? results[0].profile_json : outdir,
    llm_used: llmAvailable(),
  }));
}

main();