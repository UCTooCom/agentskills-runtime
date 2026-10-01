#!/usr/bin/env node
/**
 * generate_report.ts — 智能投研助理 Step 4: 研报生成
 * 功能与 generate_report.py 完全一致
 *
 * 运行方式: node --experimental-strip-types generate_report.ts --factors <factors.json> [--outdir output/brief]
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;
const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地日期 YYYY-MM-DD（对齐 Python datetime.now()，Python 用本地时间）
function localDateStr(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function llmAvailable(): boolean { return !!(process.env.LLM_API_KEY || process.env.OPENAI_API_KEY); }

async function callLlm(prompt: string): Promise<string> {
  const base = process.env.LLM_BASE_URL || process.env.OPENAI_BASE_URL || "https://api-ai.gitcode.com/v1";
  const key = process.env.LLM_API_KEY || process.env.OPENAI_API_KEY || "sk-dummy-key";
  const model = process.env.LLM_MODEL || "deepseek-flash";
  const url = `${base.replace(/\/$/, "")}/chat/completions`;
  const payload = { model, messages: [{ role: "system", content: "你是专业金融投研助理，输出结构化每日投资简报。内容仅供技术交流，不构成投资建议。" }, { role: "user", content: prompt }], stream: false };
  const resp = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` }, body: JSON.stringify(payload), signal: AbortSignal.timeout(120000) });
  const data = await resp.json() as any;
  const choices = data.choices || [];
  if (!choices.length) throw new Error("LLM 返回空 choices");
  return choices[0].message?.content || "";
}

function buildTemplateBrief(factorsData: any): string {
  const lines: string[] = [];
  const date = factorsData.date || localDateStr();
  for (const comp of factorsData.companies || []) {
    const mf = comp.market_factors || {};
    lines.push(`# 每日投资简报 - ${comp.name || comp.code}`);
    lines.push("");
    lines.push("## 行情概览");
    lines.push(`- 收盘价: ${mf.close_price}  涨跌幅: ${mf.change_pct}%`);
    lines.push(`- PE: ${mf.pe}  PB: ${mf.pb}  总市值: ${mf.market_cap}`);
    lines.push(`- 情绪: ${mf.sentiment}`);
    lines.push("");
    lines.push("## 核心看点");
    lines.push(`- 当日事件/新闻数量: ${comp.event_count || 0} 条`);
    lines.push("");
    lines.push("## 风险提示");
    for (const r of comp.risk_flags || []) lines.push(`- ${r}`);
    lines.push("");
    lines.push("## 数据来源与免责声明");
    lines.push("> 本简报由智能投研助理自动生成，数据来源于公开市场接口，仅供技术交流，不构成任何投资建议。");
    lines.push("");
    lines.push("---");
    lines.push("");
  }
  lines.push(`> 生成时间: ${date}`);
  return lines.join("\n");
}

async function main() {
  const args = process.argv.slice(2);
  let factors = "", outdir = path.normalize(path.join(__dirname, "..", "output", "brief"));
  for (let i = 0; i < args.length; i++) { if (args[i] === "--factors") factors = args[++i]; else if (args[i] === "--outdir") outdir = args[++i]; }
  const factorsData = JSON.parse(fs.readFileSync(factors, "utf-8"));
  const date = factorsData.date || localDateStr();
  let report: string;
  if (llmAvailable()) {
    try { report = await callLlm(`请基于以下数据生成 ${date} 每日投资简报：\n${JSON.stringify(factorsData, null, 2)}`); }
    catch (e: any) { process.stderr.write(`LLM 调用失败，降级模板生成: ${e.message}\n`); report = buildTemplateBrief(factorsData); }
  } else report = buildTemplateBrief(factorsData);
  fs.mkdirSync(outdir, { recursive: true });
  const outFile = path.join(outdir, `${date}.md`);
  fs.writeFileSync(outFile, report, "utf-8");
  console.log(JSON.stringify({ success: true, output: outFile, llm_used: llmAvailable() }));
}

main().catch((e) => { console.error(e); process.exit(1); });