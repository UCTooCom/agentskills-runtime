#!/usr/bin/env node
/**
 * fetch_market_data.ts — 智能投研助理 Step 1: 自动抓取
 * 功能与 fetch_market_data.py 完全一致
 *
 * 运行方式: node --experimental-strip-types fetch_market_data.ts --companies "600519,000858" [--date 2026-08-07] [--outdir output/raw]
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;
const scriptDir = __dirname;
const skillRoot = path.dirname(scriptDir);

const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地日期 YYYY-MM-DD（对齐 Python datetime.now()，Python 用本地时间）
function localDateStr(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}
// 本地时间 ISO（对齐 Python datetime.now().isoformat()）
function localIso(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}

async function httpGet(url: string, timeout = 15000, headers: Record<string, string> = {}, retries = 3): Promise<any> {
  const hdrs: Record<string, string> = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    Referer: "https://quote.eastmoney.com/", Accept: "application/json, text/plain, */*", "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    ...headers,
  };
  let lastError: any = null;
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const resp = await fetch(url, { headers: hdrs, signal: AbortSignal.timeout(timeout) });
      return await resp.json();
    } catch (e: any) {
      lastError = e;
      if (attempt < retries - 1) { const wait = (attempt + 1) * 2; process.stderr.write(`HTTP GET 重试 ${attempt + 1}/${retries}（${wait}秒后）: ${url.slice(0, 80)}... 错误: ${e.message}\n`); await new Promise((r) => setTimeout(r, wait * 1000)); }
    }
  }
  throw lastError;
}

async function searchCodeByName(name: string): Promise<any> {
  try {
    const token = process.env.EASTMONEY_SEARCH_TOKEN || "DGBBF2F50F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4F4";
    const url = "https://searchapi.eastmoney.com/api/suggest/get?input=" + encodeURIComponent(name) + "&type=14&token=" + token;
    const data = await httpGet(url, 10000);
    const quots = data.Quots || [];
    if (!quots.length) return null;
    const first = quots[0];
    const code = first.Code || "";
    const nameResolved = first.Name || name;
    const mkt = first.Mkt || "";
    const market = mkt.startsWith("1") || code.startsWith("6") || code.startsWith("9") ? 1 : 0;
    return { code: code.padStart(6, "0"), market, name: nameResolved };
  } catch (e: any) { process.stderr.write(`搜索公司代码失败(${name}): ${e.message}\n`); return null; }
}

async function resolveCodes(companies: string): Promise<any[]> {
  const codes: any[] = [];
  for (const item of companies.replace(/，/g, ",").split(",")) {
    const s = item.trim();
    if (!s) continue;
    if (/^\d+$/.test(s)) { const code = s.padStart(6, "0"); const market = code.startsWith("6") || code.startsWith("9") ? 1 : 0; codes.push({ code, market, name: "" }); }
    else { const resolved = await searchCodeByName(s); if (resolved) codes.push(resolved); else codes.push({ code: "", market: 0, name: s }); }
  }
  return codes;
}

async function fetchQuoteEastmoney(secid: string): Promise<any> {
  const url = `https://push2.eastmoney.com/api/qt/stock/get?secid=${secid}&fields=f43,f44,f45,f46,f47,f48,f57,f58,f60,f84,f85,f116,f117,f162,f167,f168,f169,f170`;
  const data = await httpGet(url);
  const d = data.data || {};
  return { code: d.f57, name: d.f58, price: d.f43, change_pct: d.f170, volume: d.f47, amount: d.f48, pe: d.f162, pb: d.f167, market_cap: d.f116, high: d.f44, low: d.f45, open: d.f46, prev_close: d.f60, source: "eastmoney" };
}

async function fetchQuoteSina(secid: string): Promise<any> {
  const parts = secid.split(".");
  if (parts.length !== 2) throw new Error(`Invalid secid: ${secid}`);
  const [market, code] = parts;
  const prefix = market === "1" ? "sh" : "sz";
  const url = `https://hq.sinajs.cn/list=${prefix}${code}`;
  const hdrs = {
    Referer: "https://finance.sina.com.cn/",
    // 对齐 Python：新浪接口校验 Referer/UA，需完整 UA（py L163）
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  };
  // 对齐 Python：3 次重试 + (attempt+1)*2s 退避（py L167-205）；
  // 新浪 hq.sinajs.cn 返回 GBK 编码，必须用 GBK 解码，否则中文名乱码（py L176）
  let lastError: any = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const resp = await fetch(url, { headers: hdrs, signal: AbortSignal.timeout(10000) });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const buf = Buffer.from(await resp.arrayBuffer());
      const text = new TextDecoder("gbk", { fatal: false }).decode(buf);
      const m = /="([^"]*)"/.exec(text);
      if (!m || !m[1]) throw new Error("Sina response format unexpected");
      const fields = m[1].split(",");
      if (fields.length < 10) throw new Error(`Sina response too short: ${fields.length} fields`);
      return {
        code, name: fields[0], price: fields[3] ? parseFloat(fields[3]) : null,
        change_pct: fields[2] && fields[3] && parseFloat(fields[2]) > 0 ? Math.round((parseFloat(fields[3]) - parseFloat(fields[2])) / parseFloat(fields[2]) * 10000) / 100 : null,
        volume: fields[8] ? parseInt(parseFloat(fields[8])) : null, amount: fields[9] ? parseFloat(fields[9]) : null,
        pe: null, pb: null, market_cap: null, high: fields[4] ? parseFloat(fields[4]) : null, low: fields[5] ? parseFloat(fields[5]) : null,
        open: fields[1] ? parseFloat(fields[1]) : null, prev_close: fields[2] ? parseFloat(fields[2]) : null, source: "sina",
      };
    } catch (e: any) {
      lastError = e;
      if (attempt < 2) { const wait = (attempt + 1) * 2; process.stderr.write(`新浪行情重试 ${attempt + 1}/3（${wait}秒后）: ${e.message}\n`); await new Promise((r) => setTimeout(r, wait * 1000)); }
    }
  }
  throw lastError;
}

async function fetchQuote(secid: string): Promise<any> {
  try { return await fetchQuoteEastmoney(secid); }
  catch (e: any) { process.stderr.write(`东方财富行情抓取失败(${secid}): ${e.message}，尝试新浪财经...\n`); try { return await fetchQuoteSina(secid); } catch (e2: any) { throw new Error(`东方财富: ${e.message}; 新浪: ${e2.message}`); } }
}

async function fetchNews(code: string, page = 1, pageSize = 10): Promise<any[]> {
  try {
    const url = `https://search-api-web.eastmoney.com/search/jsonp?cb=jQuery&param=%7B%22uid%22%3A%22%22%2C%22keyword%22%3A%22${code}%22%2C%22type%22%3A%5B%22cmsArticleWebOld%22%5D%2C%22client%22%3A%22web%22%2C%22clientType%22%3A%22web%22%2C%22clientVersion%22%3A%22curr%22%2C%22param%22%3A%7B%22cmsArticleWebOld%22%3A%7B%22searchScope%22%3A%22default%22%2C%22sort%22%3A%22default%22%2C%22pageIndex%22%3A${page - 1}%2C%22pageSize%22%3A${pageSize}%2C%22preTag%22%3A%22%22%2C%22postTag%22%3A%22%22%7D%7D%7D`;
    const data = await httpGet(url, 10000);
    const articles = data.Data?.cmsArticleWebOld?.List || [];
    return articles.slice(0, pageSize).map((art: any) => ({ title: (art.Title || "").replace(/<em>/g, "").replace(/<\/em>/g, ""), content: (art.Content || "").slice(0, 200), source: art.Source, date: art.Date, url: art.Url }));
  } catch (e: any) { process.stderr.write(`抓取新闻失败(${code}): ${e.message}\n`); return []; }
}

async function main() {
  const args = process.argv.slice(2);
  let companies = "", date = localDateStr(), outdir: string | null = null, force = false;
  for (let i = 0; i < args.length; i++) { if (args[i] === "--companies") companies = args[++i]; else if (args[i] === "--date") date = args[++i]; else if (args[i] === "--outdir") outdir = args[++i]; else if (args[i] === "--force") force = true; }
  if (!companies) { console.error("错误: 缺少必填参数 --companies"); process.exit(2); }
  if (!outdir) outdir = path.normalize(path.join(skillRoot, "output", "raw"));
  const codes = await resolveCodes(companies);
  if (!codes.length) { console.log(JSON.stringify({ success: false, error: "empty companies" })); process.exit(1); }
  fs.mkdirSync(outdir, { recursive: true });
  const outFile = path.join(outdir, `${date}.json`);
  if (!force && fs.existsSync(outFile)) { console.log(JSON.stringify({ success: false, error: "file_already_exists", message: `${outFile} 已存在。请用 --force 覆盖。`, existing_file: outFile })); process.exit(2); }
  const result: any = { date, companies: [], sources: [], fetched_at: localIso() };
  for (const item of codes) {
    const rec: any = { code: item.code, name: item.name, quotes: null, news: [], error: null };
    try {
      if (item.code) {
        const secid = `${item.market}.${item.code}`;
        rec.quotes = await fetchQuote(secid);
        if (!rec.name && rec.quotes?.name) { rec.name = rec.quotes.name; item.name = rec.quotes.name; }
        await new Promise((r) => setTimeout(r, 300));
        try { rec.news = await fetchNews(item.code); } catch (newsErr: any) { process.stderr.write(`新闻抓取失败(${item.code}): ${newsErr.message}\n`); rec.news = []; }
        await new Promise((r) => setTimeout(r, 300));
      }
    } catch (e: any) { rec.error = e.message; }
    result.companies.push(rec);
    result.sources.push("eastmoney-quote", "eastmoney-news");
  }
  fs.writeFileSync(outFile, JSON.stringify(result, null, 2), "utf-8");
  console.log(JSON.stringify({ success: true, output: outFile, company_count: codes.length, forced: force }));
}

main().catch((e) => { console.error(e); process.exit(1); });