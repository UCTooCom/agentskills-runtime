#!/usr/bin/env node
/**
 * build_enterprise_profile.ts — 产业政策智能体 Step 1: 全景企业画像
 * 功能与 build_enterprise_profile.py 完全一致
 *
 * 运行方式: node --experimental-strip-types build_enterprise_profile.ts --company "北京XXX科技有限公司"
 */
import * as path from "path";
import * as fs from "fs";

const __dirname = import.meta.dirname;
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
  };
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

  if (!company) {
    console.error("错误: --company 不能为空");
    process.exit(2);
  }

  const companies = company.split(/[,，;；]/).map((c) => c.trim()).filter(Boolean);
  if (!companies.length) {
    console.error("错误: --company 不能为空");
    process.exit(1);
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
    const profile = buildSkeleton(name, prefillMap[name] || {});
    fillPending(profile);
    profile.summary = await summarize(profile);
    const jpath = path.join(outdir, `${slug}.json`);
    const mpath = path.join(outdir, `${slug}.md`);
    fs.writeFileSync(jpath, JSON.stringify(profile, null, 2), "utf-8");
    fs.writeFileSync(mpath, renderMd(profile), "utf-8");
    results.push({
      company: name, slug, profile_json: jpath, profile_md: mpath,
      pending_fields: profile.pending_fields,
    });
  }

  console.log(JSON.stringify({
    success: true, count: results.length, profiles: results,
    output: results.length === 1 ? results[0].profile_json : outdir,
    llm_used: llmAvailable(),
  }));
}

main();