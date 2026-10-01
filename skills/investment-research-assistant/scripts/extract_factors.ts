#!/usr/bin/env node
/**
 * extract_factors.ts — 智能投研助理 Step 3: 要素提取
 * 功能与 extract_factors.py 完全一致
 *
 * 运行方式: node --experimental-strip-types extract_factors.ts --input <clean.json> [--outdir output/factors]
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;

function extractQuoteFactors(q: any): any {
  if (!q) return {};
  const changePct = q.change_pct, price = q.price, pe = q.pe, pb = q.pb, marketCap = q.market_cap;
  let sentiment = "neutral";
  if (changePct != null) { if (changePct > 2) sentiment = "positive"; else if (changePct < -2) sentiment = "negative"; }
  return { close_price: price, change_pct: changePct, pe, pb, market_cap: marketCap, sentiment, volatility_flag: changePct != null && Math.abs(changePct) >= 5 };
}

function extractRiskFactors(factors: any, newsCount: number): string[] {
  const risks: string[] = [];
  if (factors.volatility_flag) risks.push("当日涨跌幅波动较大（≥5%），注意短期波动风险");
  if (typeof factors.pe === "number" && factors.pe > 60) risks.push("市盈率偏高（>60），估值需谨慎");
  if (factors.sentiment === "negative") risks.push("当日市场情绪偏负面");
  if (newsCount === 0) risks.push("当日未获取到有效公告/新闻数据，信息覆盖有限");
  if (!risks.length) risks.push("未发现显著风险信号");
  return risks;
}

async function main() {
  const args = process.argv.slice(2);
  let input = "", outdir = path.normalize(path.join(__dirname, "..", "output", "factors"));
  for (let i = 0; i < args.length; i++) { if (args[i] === "--input") input = args[++i]; else if (args[i] === "--outdir") outdir = args[++i]; }
  const cleaned = JSON.parse(fs.readFileSync(input, "utf-8"));
  const result: any = { date: cleaned.date, companies: [] };
  for (const comp of cleaned.companies || []) {
    const qf = extractQuoteFactors(comp.quotes || {});
    const newsCount = (comp.news || []).length;
    const risks = extractRiskFactors(qf, newsCount);
    result.companies.push({ code: comp.code, name: comp.name, market_factors: qf, event_count: newsCount, risk_flags: risks });
  }
  fs.mkdirSync(outdir, { recursive: true });
  const outFile = path.join(outdir, path.basename(input));
  fs.writeFileSync(outFile, JSON.stringify(result, null, 2), "utf-8");
  console.log(JSON.stringify({ success: true, output: outFile, company_count: result.companies.length }));
}

main().catch((e) => { console.error(e); process.exit(1); });