#!/usr/bin/env node
/**
 * match_policy.ts — 产业政策智能体 Step 2: 多元政策匹配
 * 功能与 match_policy.py 完全一致
 *
 * 运行方式: node --experimental-strip-types match_policy.ts --profile output/profiles/{slug}.json [--topn 10]
 */
import * as path from "path";
import * as fs from "fs";

// 等价 Python json.dumps(v, ensure_ascii=False)（默认分隔符 ": " / ", "，非 ASCII 不转义），
// 保证发给 LLM 的 prompt 与 py 版逐字节一致
function pyDumps(v: any): string {
  if (v === null) return "null";
  const t = typeof v;
  if (t === "string") return JSON.stringify(v);
  if (t === "number" || t === "boolean") return String(v);
  if (Array.isArray(v)) return "[" + v.map(pyDumps).join(", ") + "]";
  if (t === "object") {
    const ks = Object.keys(v as object);
    return ks.length ? "{" + ks.map((k) => JSON.stringify(k) + ": " + pyDumps((v as any)[k])).join(", ") + "}" : "{}";
  }
  return "null";
}

const __dirname = import.meta.dirname;

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

function defaultKb(): string {
  return path.normalize(path.join(__dirname, "..", "knowledge"));
}

function defaultOutdir(): string {
  return path.normalize(path.join(__dirname, "..", "output", "matches"));
}

function todayStr(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
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

function hardFilter(policy: any, profile: any): string | null {
  if (policy.status === "expired") return "已过期";
  const cond = policy.conditions || {};
  const regionReq = cond.region || "";
  const level = policy.level || "";
  const profRegion = profile.region || "";
  if (level === "区级" && regionReq) {
    const m = regionReq.match(/(朝阳|海淀|东城|西城|丰台|石景山|通州|大兴|顺义|昌平|房山|门头沟|平谷|怀柔|密云|延庆|经开)/);
    if (m && !profRegion.includes(m[1])) return "注册区域不符";
  }
  return null;
}

function ruleScore(policy: any, profile: any): number {
  let score = 0;
  const cond = policy.conditions || {};
  const industries = cond.industry || [];
  const profAll = new Set<string>([...(profile.industry || []), ...(profile.tags || [])]);
  if (industries.length) {
    if (industries.some((x: string) => profAll.has(x))) score += 40;
  } else {
    const domain = policy.domain || "";
    if (domain && profAll.size) {
      let hit = false;
      for (const t of profAll) {
        if (domain.includes(t) || t.includes(domain)) { hit = true; break; }
      }
      score += hit ? 35 : 20;
    } else {
      score += 20;
    }
  }
  const qualReq = cond.qualification || "";
  const profQual = (profile.qualification || []).join("、");
  if (qualReq) {
    if (profQual.includes(qualReq) || ["高新技术", "专精特新", "科技型"].some(k => profQual.includes(k))) score += 30;
  }
  const regionReq = cond.region || "";
  const profRegion = profile.region || "";
  if (regionReq) {
    if (profRegion.includes(regionReq) || regionReq.includes(profRegion) || regionReq === "北京市") score += 20;
  }
  if (policy.status === "active") score += 10;
  return score;
}

function buildBasis(policy: any, profile: any): string {
  const cond = policy.conditions || {};
  const parts = [`层级${policy.level || ""}·领域${policy.domain || ""}`];
  const profAll = new Set<string>([...(profile.industry || []), ...(profile.tags || [])]);
  const condInd = cond.industry || [];
  if (condInd.length && profAll.size) {
    const inter = condInd.filter((x: string) => profAll.has(x));
    if (inter.length) parts.push("行业命中文：" + inter.join("、"));
  } else {
    const domain = policy.domain || "";
    if (domain && profAll.size) {
      let hit = false;
      for (const t of profAll) {
        if (domain.includes(t) || t.includes(domain)) { hit = true; break; }
      }
      if (hit) parts.push("领域命中：" + domain);
    }
  }
  if (cond.qualification && profile.qualification?.length) {
    parts.push("资质对标：" + cond.qualification);
  }
  return parts.join("；");
}

async function llmScore(policy: any, profile: any): Promise<[number, string, any[]]> {
  const prompt = "请评估该企业与政策的匹配度，返回 JSON：{\"score\": 0-100 整数, \"basis\": \"匹配依据一句话\", \"gap\": [\"缺口项\"]}。\n企业画像："
    + pyDumps(profile) + "\n政策：" + pyDumps(policy);
  try {
    const out = await callLlm(prompt, "你是园区政策匹配助手，只输出 JSON。");
    const m = out.match(/\{.*\}/s);
    if (!m) throw new Error("LLM 未返回 JSON");
    const data = JSON.parse(m[0]);
    return [parseInt(data.score, 10) || 0, data.basis || "", data.gap || []];
  } catch {
    return [ruleScore(policy, profile), buildBasis(policy, profile), []];
  }
}

async function main() {
  const args = parseArgs();
  const profilePath = typeof args.profile === "string" ? args.profile : "";
  const kb = typeof args.kb === "string" ? args.kb : defaultKb();
  if (typeof args.topn === "string" && !/^\d+$/.test(args.topn)) { console.error(`错误: --topn 必须为整数: ${args.topn}`); process.exit(2); }
  const topn = typeof args.topn === "string" ? Math.max(1, parseInt(args.topn, 10) || 10) : 10;
  const outdir = typeof args.outdir === "string" ? args.outdir : defaultOutdir();
  const date = typeof args.date === "string" ? args.date : todayStr();
  const web = typeof args.web === "string" ? args.web : null;

  if (!profilePath) {
    console.error("错误: --profile 必填");
    process.exit(2);
  }

  const profile = JSON.parse(fs.readFileSync(profilePath, "utf-8"));

  const indexPath = path.join(kb, "policy-index.json");
  if (!fs.existsSync(indexPath)) {
    console.error("错误: 未找到 policy-index.json，请先运行 init_policy_kb.ts");
    process.exit(1);
  }
  const index = JSON.parse(fs.readFileSync(indexPath, "utf-8"));

  const matches: any[] = [];
  const eliminated: any[] = [];
  for (const policy of (index.policies || [])) {
    const reason = hardFilter(policy, profile);
    if (reason) {
      eliminated.push({ policy_no: policy.policy_no, title: policy.title, reason });
      continue;
    }
    let score: number, basis: string, gap: any[];
    if (llmAvailable()) {
      [score, basis, gap] = await llmScore(policy, profile);
    } else {
      score = ruleScore(policy, profile);
      basis = buildBasis(policy, profile);
      gap = [];
    }
    matches.push({
      policy_no: policy.policy_no,
      title: policy.title,
      domain: policy.domain,
      level: policy.level,
      department: policy.department,
      support: policy.support,
      score,
      basis,
      gap,
      conditions: policy.conditions || {},
      status: "matched",
      source: `policy-original/${policy.file || ""}`,
    });
  }

  matches.sort((a, b) => b.score - a.score);
  const top = matches.slice(0, topn);

  const pendingVerify: any[] = [];
  if (web && fs.existsSync(web)) {
    const webData = JSON.parse(fs.readFileSync(web, "utf-8"));
    for (const item of (webData.policies || [])) {
      if (!("policy_no" in item)) {
        pendingVerify.push({ title: item.title || "", source: item.url || "", status: "待核实", note: "无法绑定政策原文库 policy_no" });
      }
    }
  }

  fs.mkdirSync(outdir, { recursive: true });
  const slug = profile.slug || path.parse(profilePath).name;
  const outPath = path.join(outdir, `${slug}-${date}.json`);
  const result = {
    slug,
    company_name: profile.company_name,
    match_date: date,
    total_policies: (index.policies || []).length,
    eliminated,
    matches: top,
    matched_count: matches.filter(m => m.score > 0).length,
    pending_verify: pendingVerify,
  };
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), "utf-8");

  console.log(JSON.stringify({
    success: true, output: outPath, matched_count: top.length,
    eliminated: eliminated.length, pending_verify: pendingVerify.length,
    llm_used: llmAvailable(),
  }));
}

main();