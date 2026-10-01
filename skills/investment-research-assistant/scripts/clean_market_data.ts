#!/usr/bin/env node
/**
 * clean_market_data.ts — 智能投研助理 Step 2: 数据清洗
 * 功能与 clean_market_data.py 完全一致
 *
 * 运行方式: node --experimental-strip-types clean_market_data.ts --input <raw.json> [--outdir output/clean]
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;
const scriptDir = __dirname;
const skillRoot = path.dirname(scriptDir);

function cleanValue(v: any): any { if (v == null) return null; try { return Math.round(parseFloat(v) / 100.0 * 10000) / 10000; } catch { return v; } }
function cleanRaw(v: any): any { if (v == null) return null; try { return Math.round(parseFloat(v) * 10000) / 10000; } catch { return v; } }
function cleanMarketCap(v: any): any { if (v == null) return null; try { return Math.round(parseFloat(v) / 100000000.0 * 10000) / 10000; } catch { return v; } }

function cleanQuote(q: any): any {
  if (!q) return {};
  const source = (q.source || "").toLowerCase();
  const isSina = source.includes("sina");
  const cleanPrice = isSina ? cleanRaw : cleanValue;
  return {
    code: q.code, name: q.name, price: cleanPrice(q.price), change_pct: cleanPrice(q.change_pct),
    volume: q.volume, amount: q.amount, pe: cleanPrice(q.pe), pb: cleanPrice(q.pb),
    market_cap: cleanMarketCap(q.market_cap), high: cleanPrice(q.high), low: cleanPrice(q.low),
    open: cleanPrice(q.open), prev_close: cleanPrice(q.prev_close),
  };
}

function cleanRecords(raw: any): any {
  const cleaned: any = { date: raw.date, companies: [], cleaned_at: null };
  const seenTitles = new Set<string>();
  for (const comp of raw.companies || []) {
    const q = cleanQuote(comp.quotes || {});
    if (!q.code || q.price == null) continue;
    const news: any[] = [];
    for (const n of comp.news || []) {
      const title = (n.title || "").trim();
      if (!title || seenTitles.has(title)) continue;
      seenTitles.add(title); news.push(n);
    }
    cleaned.companies.push({ code: q.code, name: q.name || comp.name, quotes: q, news, raw_news_count: (comp.news || []).length });
  }
  return cleaned;
}

async function main() {
  const args = process.argv.slice(2);
  let input = "", outdir: string | null = null;
  for (let i = 0; i < args.length; i++) { if (args[i] === "--input") input = args[++i]; else if (args[i] === "--outdir") outdir = args[++i]; }
  if (!outdir) outdir = path.normalize(path.join(skillRoot, "output", "clean"));
  let inputPath = input;
  if (!path.isAbsolute(inputPath) && !fs.existsSync(inputPath)) {
    const candidate = path.join(skillRoot, "output", "raw", path.basename(inputPath));
    if (fs.existsSync(candidate)) inputPath = candidate;
  }
  inputPath = path.normalize(inputPath);
  const raw = JSON.parse(fs.readFileSync(inputPath, "utf-8"));
  const cleaned = cleanRecords(raw);
  fs.mkdirSync(outdir, { recursive: true });
  const outFile = path.join(outdir, path.basename(inputPath));
  fs.writeFileSync(outFile, JSON.stringify(cleaned, null, 2), "utf-8");
  console.log(JSON.stringify({ success: true, output: outFile, total: (raw.companies || []).length, kept: cleaned.companies.length, dropped: (raw.companies || []).length - cleaned.companies.length }));
}

main().catch((e) => { console.error(e); process.exit(1); });