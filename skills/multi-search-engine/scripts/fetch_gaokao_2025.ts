#!/usr/bin/env node
/**
 * fetch_gaokao_2025.ts — 多引擎抓取 2025 年高考数学压轴大题
 * 功能与 fetch_gaokao_2025.py 完全一致
 *
 * 运行方式: node --experimental-strip-types fetch_gaokao_2025.ts
 */
import * as fs from "fs";

const HEADERS: Record<string, string> = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
  "Accept-Encoding": "gzip, deflate",
  Connection: "close",
};

const QUERY = "2025年高考数学压轴题 原题";
const q = encodeURIComponent(QUERY);

const ENGINES: [string, string][] = [
  ["bing_cn", `https://cn.bing.com/search?q=${q}&ensearch=0`],
  ["so360", `https://www.so.com/s?q=${q}`],
  ["sogou", `https://www.sogou.com/web?query=${q}`],
  ["shenma", `https://m.sm.cn/s?q=${q}`],
];

const TAG_RE = /<a\b[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;
const TAG_CLEAN = /<[^>]+>/g;

function clean(s: string): string {
  s = s.replace(TAG_CLEAN, "");
  s = s.replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&quot;/g, '"');
  return s.replace(/\s+/g, " ").trim();
}

async function fetchUrl(url: string): Promise<[number, string]> {
  const resp = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(25000) }); // 对齐 py timeout=25
  const text = await resp.text();
  return [resp.status, text];
}

async function main() {
  const out: any = { query: QUERY, engines: {} };
  for (const [name, url] of ENGINES) {
    const rec: any = { url, ok: false, count: 0, results: [], error: "" };
    try {
      const [status, html] = await fetchUrl(url);
      rec.status = status;
      rec.len = html.length;
      const hits: any[] = [];
      let m: RegExpExecArray | null;
      TAG_RE.lastIndex = 0;
      while ((m = TAG_RE.exec(html)) !== null) {
        const href = m[1];
        const txt = clean(m[2]);
        if (txt.length < 8 || txt.length > 120) continue;
        if (href.startsWith("javascript") || href.startsWith("#")) continue;
        hits.push({ title: txt, url: href });
        if (hits.length >= 30) break;
      }
      rec.ok = true;
      rec.results = hits;
      rec.count = hits.length;
      // 保存原始 html
      fs.writeFileSync(`raw_${name}.html`, html, "utf-8");
    } catch (e: any) {
      rec.error = `${e.constructor.name}: ${e.message}`;
    }
    out.engines[name] = rec;
    console.log(
      "=== %s status=%s ok=%s count=%s err=%s",
      name, rec.status, rec.ok, rec.count, rec.error
    );
    for (const it of rec.results.slice(0, 20)) {
      console.log("   -", it.title, "|", it.url.slice(0, 110));
    }
    await new Promise((r) => setTimeout(r, 1500));
  }

  fs.writeFileSync("output_search_2025.json", JSON.stringify(out, null, 2), "utf-8");
  console.log("\nSAVED output_search_2025.json");
}

main();