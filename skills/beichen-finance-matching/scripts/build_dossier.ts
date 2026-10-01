#!/usr/bin/env node
/**
 * build_dossier.ts — 金融匹配智能体 Step 4: 对接材料包
 * 功能与 build_dossier.py 完全一致
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;

const BANK_MATERIALS: [string, string][] = [
  ["营业执照（副本）", "提供企业营业执照复印件并加盖公章"],
  ["近两年财务报告", "提供近两个完整年度审计报告或财务报表"],
  ["纳税记录", "电子税务局打印最近 12 个月完税证明"],
  ["经营流水", "主要对公账户近 6 个月银行流水"],
  ["融资用途说明", "说明融资金额、用途与还款来源"],
  ["担保/抵质押材料", "如涉及抵质押，提供资产权属证明"],
];
const EQUITY_MATERIALS: [string, string][] = [
  ["商业计划书（BP）", "含商业模式、市场、团队、财务预测"],
  ["股权结构说明", "提供股东名册与股权结构图"],
  ["近两年财务报告", "提供审计报告或财务报表"],
  ["尽调材料", "业务合同、知识产权、合规证明等"],
  ["融资需求与估值说明", "说明融资额度、出让比例与资金用途"],
];

function findPartnerType(kb: string, name: string): string {
  const indexPath = path.join(kb, "finance-index.json");
  if (!fs.existsSync(indexPath)) return "bank";
  const index = JSON.parse(fs.readFileSync(indexPath, "utf-8"));
  for (const p of index.partners || []) if (p.name === name) return p.type || "bank";
  return "bank";
}

async function main() {
  const args = process.argv.slice(2);
  let need = "", partner = "", kb = path.normalize(path.join(__dirname, "..", "knowledge")), outdir = path.normalize(path.join(__dirname, "..", "output", "dossiers"));
  for (let i = 0; i < args.length; i++) { if (args[i] === "--need") need = args[++i]; else if (args[i] === "--partner") partner = args[++i]; else if (args[i] === "--kb") kb = args[++i]; else if (args[i] === "--outdir") outdir = args[++i]; }
  if (!need) { console.error("错误: 缺少必填参数 --need"); process.exit(2); }
  if (!partner) { console.error("错误: 缺少必填参数 --partner"); process.exit(2); }
  const needData = JSON.parse(fs.readFileSync(need, "utf-8"));
  const ptype = findPartnerType(kb, partner);
  const materials = ["securities", "fund", "investor"].includes(ptype) ? EQUITY_MATERIALS : BANK_MATERIALS;
  const profile = needData.profile || {};
  const region = profile.region || "待补充";
  const lines = [`# 对接材料包 - ${needData.company_name || ""} → ${partner}`, "", "## 融资需求信息（预填）", "", `- 企业名称：${needData.company_name || ""}`, `- 注册区域：${region}`, `- 融资金额：${needData.amount || ""}`, `- 融资期限：${needData.term || ""}`, `- 融资用途：${needData.purpose || ""}`, `- 担保方式：${needData.guarantee || ""}`, `- 营收概况：${needData.revenue || ""}`, `- 服务单号：${needData.case_id || ""}`, "", "## 需准备材料清单", "", "| 序号 | 材料 | 说明 / 获取路径 | 状态 |", "|------|------|----------------|------|"];
  materials.forEach(([name, note], i) => lines.push(`| ${i + 1} | ${name} | ${note} | 待提交 |`));
  lines.push("", "## 提示", "", "- 带“待补充”字段请在对接前补齐；", "- 财务信息属敏感数据，请通过合规渠道提交并做好脱敏。", "");
  fs.mkdirSync(outdir, { recursive: true });
  const caseId = needData.case_id || path.basename(need, path.extname(need));
  const out = path.join(outdir, `${caseId}-${partner}.md`);
  fs.writeFileSync(out, lines.join("\n"), "utf-8");
  console.log(JSON.stringify({ success: true, output: out, partner, material_count: materials.length }));
}

main().catch((e) => { console.error(e); process.exit(1); });