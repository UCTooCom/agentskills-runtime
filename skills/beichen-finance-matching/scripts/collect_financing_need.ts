#!/usr/bin/env node
/**
 * collect_financing_need.ts — 金融匹配智能体 Step 1: 融资需求采集与初步审核
 * 功能与 collect_financing_need.py 完全一致
 */
import * as fs from "fs";
import * as path from "path";
import { randomUUID } from "crypto";

const __dirname = import.meta.dirname;

const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地日期 YYYY-MM-DD（对齐 Python datetime.now()，Python 用本地时间）
function localDateStr(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}
// 本地时间 ISO（对齐 Python datetime.now().isoformat()）
function localIso(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}

function makeSlug(s: string): string {
  // 剔除集与 py L39 完全一致（含弯引号 U+201C/U+201D，显式转义避免码点歧义）
  return (s || "").replace(/[\s\u3000]+/g, "").replace(/[()（）【】\[\]《》·,.，。、/\\:：;；'"\u201C\u201D]/g, "") || "company";
}

function parseAmount(amount: string): [number | null, string | null] {
  const m = /([\d.]+)\s*(万|亿|元|千)?/.exec(amount || "");
  if (!m) return [null, null];
  return [parseFloat(m[1]), m[2] || "元"];
}

function amountToWan(value: number, unit: string): number {
  if (unit === "亿") return value * 10000;
  if (unit === "万") return value;
  return value / 10000;
}

function addWorkdays(start: Date, days: number): string {
  const d = new Date(start);
  while (days > 0) { d.setDate(d.getDate() + 1); if (d.getDay() < 6) days--; }
  return localDateStr(d);
}

function feasibilityCheck(need: any): string[] {
  const tips: string[] = [];
  const [val, unit] = parseAmount(need.amount || "");
  if (val === null) tips.push("金额格式无法识别，请使用如 500万 / 3000万");
  if (need.revenue) {
    const [revVal, revUnit] = parseAmount(need.revenue);
    if (val !== null && revVal !== null) {
      const amt = amountToWan(val, unit!); const rev = amountToWan(revVal, revUnit!);
      if (rev > 0 && amt / rev > 1.0) tips.push("融资金额超过上年度营收，建议补充抵质押或降低额度");
    }
  }
  const purpose = need.purpose || "";
  if (purpose && !["流动资金", "研发投入", "设备采购", "股权融资", "并购", "其他"].includes(purpose)) tips.push("融资用途建议从 流动资金/研发投入/设备采购/股权融资/并购 中选择");
  return tips;
}

async function main() {
  const args = process.argv.slice(2);
  let company = "", amount = "", purpose = "", term = "", guarantee = "", revenue = "", outdir = path.normalize(path.join(__dirname, "..", "output", "needs"));
  for (let i = 0; i < args.length; i++) { if (args[i] === "--company") company = args[++i]; else if (args[i] === "--amount") amount = args[++i]; else if (args[i] === "--purpose") purpose = args[++i]; else if (args[i] === "--term") term = args[++i]; else if (args[i] === "--guarantee") guarantee = args[++i]; else if (args[i] === "--revenue") revenue = args[++i]; else if (args[i] === "--outdir") outdir = args[++i]; }
  // 对齐 py argparse required=True（缺失 exit 2）
  if (!company) { console.error("错误: 缺少必填参数 --company"); process.exit(2); }
  if (!amount) { console.error("错误: 缺少必填参数 --amount"); process.exit(2); }
  if (!purpose) { console.error("错误: 缺少必填参数 --purpose"); process.exit(2); }
  company = company.trim();
  if (!company) { process.stderr.write("错误: --company 不能为空\n"); process.exit(1); }
  const now = new Date();
  const need: any = { case_id: `FC-${localDateStr(now).replace(/-/g, "")}-${randomUUID().slice(0, 6).toUpperCase()}`, company_name: company, amount, purpose, term: term || "待补充", guarantee: guarantee || "待补充", revenue: revenue || "待补充", created_at: localIso(now), profile: {} };
  const profilesDir = path.normalize(path.join(__dirname, "..", "..", "beichen-policy-assistant", "output", "profiles"));
  const profilePath = path.join(profilesDir, `${makeSlug(company)}.json`);
  if (fs.existsSync(profilePath)) need.profile = JSON.parse(fs.readFileSync(profilePath, "utf-8"));
  const missing = (["amount", "purpose"] as const).filter((k) => !need[k]);
  const feasibility = feasibilityCheck(need);
  if (missing.length || feasibility.length) { need.status = "draft"; need.validation = { missing, feasibility_tips: feasibility }; }
  else { need.status = "intaked"; need.validation = { missing: [], feasibility_tips: [] }; need.sop_stage = 1; need.sop_stage_name = "资料提交与审核"; need.due_date = addWorkdays(now, 1); need.owner = ""; }
  fs.mkdirSync(outdir, { recursive: true });
  const out = path.join(outdir, `${need.case_id}.json`);
  fs.writeFileSync(out, JSON.stringify(need, null, 2), "utf-8");
  console.log(JSON.stringify({ success: true, case_id: need.case_id, status: need.status, output: out, missing, feasibility_tips: feasibility, due_date: need.due_date || "" }));
}

main().catch((e) => { console.error(e); process.exit(1); });