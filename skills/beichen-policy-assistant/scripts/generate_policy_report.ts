#!/usr/bin/env node
/**
 * generate_policy_report.ts — 产业政策智能体 Step 3: 适配研判报告
 * 功能与 generate_policy_report.py 完全一致
 *
 * 运行方式: node --experimental-strip-types generate_policy_report.ts --profile {画像json} --matches {匹配json}
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
  return path.normalize(path.join(__dirname, "..", "output", "reports"));
}

function llmAvailable(): boolean {
  return Boolean(process.env.LLM_API_KEY || process.env.OPENAI_API_KEY);
}

async function callLlm(prompt: string): Promise<string> {
  const base = process.env.LLM_BASE_URL || process.env.OPENAI_BASE_URL || "https://api-ai.gitcode.com/v1";
  const key = process.env.LLM_API_KEY || process.env.OPENAI_API_KEY || "sk-dummy-key";
  const model = process.env.LLM_MODEL || "deepseek-flash";
  const url = `${base.replace(/\/$/, "")}/chat/completions`;
  const payload = {
    model,
    stream: false,
    messages: [
      { role: "system", content: "你是园区产业政策研判助手，输出结构化政策适配报告。内容仅供申报参考，不构成法律意见。" },
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

function checkCondition(condVal: any, profile: any, kind: string): string {
  if (!condVal) return "满足";
  if (kind === "region") {
    const profRegion = profile.region || "";
    return (profRegion.includes(condVal) || condVal.includes(profRegion) || condVal === "北京市") ? "满足" : "不满足";
  }
  if (kind === "qualification") {
    const qual = (profile.qualification || []).join("、");
    if (qual.includes(condVal) || ["高新技术", "专精特新", "科技型"].some(k => qual.includes(k))) return "满足";
    return !qual ? "待核实" : "不满足";
  }
  if (kind === "industry") {
    const inds = new Set(profile.industry || []);
    const condArr: any[] = Array.isArray(condVal) ? condVal : [condVal];
    if (!condArr.length || condArr.some(x => inds.has(x))) return "满足";
    return "部分满足";
  }
  return "待核实";
}

function buildTemplateReport(profile: any, matches: any): string {
  const lines: string[] = [
    `# 政策适配研判报告 - ${profile.company_name || ""}`, "",
    `- 生成日期：${matches.match_date || ""}`,
    `- 注册区域：${profile.region || ""}`,
    `- 所属行业：${(profile.industry || []).join("、") || "待核实"}`,
    `- 企业资质：${(profile.qualification || []).join("、") || "暂无"}`, "",
    "## 匹配政策清单（按匹配度排序）", "",
    "| 序号 | 政策编号 | 政策名称 | 层级/领域 | 匹配度 | 匹配依据 |",
    "|------|---------|---------|----------|--------|---------|",
  ];
  let i = 1;
  for (const m of (matches.matches || [])) {
    lines.push(`| ${i} | ${m.policy_no} | ${m.title} | ${m.level}/${m.domain} | ${m.score} | ${m.basis} |`);
    i++;
  }
  lines.push("", "## 申报条件对标分析", "");
  for (const m of (matches.matches || [])) {
    lines.push(`### 政策 ${m.policy_no} - ${m.title}`);
    const cond = m.conditions || {};
    if (cond.region) {
      lines.push(`- 注册区域（条件 ${cond.region}）：${checkCondition(cond.region, profile, "region")}`);
    }
    if (cond.qualification) {
      lines.push(`- 资质要求（条件 ${cond.qualification}）：${checkCondition(cond.qualification, profile, "qualification")}`);
    }
    if (cond.industry) {
      lines.push(`- 行业要求（条件 ${cond.industry.join("、")}）：${checkCondition(cond.industry, profile, "industry")}`);
    }
    const gaps = m.gap || [];
    if (gaps.length) {
      lines.push(`- 缺口项：${gaps.join("、")}`);
    } else {
      lines.push("- 缺口项：无（以申报通知为准）");
    }
    lines.push("");
  }
  lines.push("## 申报建议与优先级", "");
  let j = 1;
  for (const m of (matches.matches || []).slice(0, 5)) {
    lines.push(`${j}. 【高优先级】可申报` + (m.score ? `（匹配度 ${m.score} 分）` : ""));
    lines.push(`   - 政策：${m.title}（编号 ${m.policy_no}）`);
    lines.push(`   - 支持方式：${m.support || "待补充"}`);
    lines.push(`   - 建议关注 ${m.department || ""} 官网申报通知`);
    j++;
  }
  lines.push("", "## 合规声明", "");
  lines.push("> 本报告由产业政策智能体自动生成，数据来源于公开渠道与政策知识库，每条匹配结论均已溯源至政策原文库编号；仅供申报参考，不构成法律意见。", "");
  return lines.join("\n");
}

async function main() {
  const args = parseArgs();
  const profilePath = typeof args.profile === "string" ? args.profile : "";
  const matchesPath = typeof args.matches === "string" ? args.matches : "";
  const outdir = typeof args.outdir === "string" ? args.outdir : defaultOutdir();

  if (!profilePath || !matchesPath) {
    console.error("错误: --profile 和 --matches 必填");
    process.exit(2);
  }

  const profile = JSON.parse(fs.readFileSync(profilePath, "utf-8"));
  const matches = JSON.parse(fs.readFileSync(matchesPath, "utf-8"));

  const date = matches.match_date || localDateStr();
  let llmUsed = false;
  let report: string;
  if (llmAvailable()) {
    const prompt = `请基于以下企业画像与匹配矩阵，生成政策适配研判报告（Markdown，含匹配清单、条件对标表、缺口分析、申报建议）。\n画像：${JSON.stringify(profile, null, 2)}\n匹配矩阵：${JSON.stringify(matches, null, 2)}`;
    try {
      report = await callLlm(prompt);
      if (report.trim()) {
        llmUsed = true;
      } else {
        report = buildTemplateReport(profile, matches);
      }
    } catch (e: any) {
      console.error(`LLM 调用失败，降级模板生成: ${e}`);
      report = buildTemplateReport(profile, matches);
    }
  } else {
    report = buildTemplateReport(profile, matches);
  }

  if (!report.trimEnd().endsWith("不构成法律意见。") && !report.includes("不构成法律意见")) {
    report += "\n\n> 本报告仅供申报参考，不构成法律意见。\n";
  }

  fs.mkdirSync(outdir, { recursive: true });
  const slug = profile.slug || path.parse(profilePath).name;
  const out = path.join(outdir, `${slug}-${date}.md`);
  fs.writeFileSync(out, report, "utf-8");

  console.log(JSON.stringify({ success: true, output: out, llm_used: llmUsed }));
}

main();