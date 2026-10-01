#!/usr/bin/env node
/**
 * fetch_pages_2025.ts — 抓取候选页面正文，提取 2025 高考数学压轴题题干
 * 功能与 fetch_pages_2025.py 完全一致
 *
 * 运行方式: node --experimental-strip-types fetch_pages_2025.ts
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

async function fetchUrl(url: string, timeout = 25000): Promise<[number, string]> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);
  try {
    const resp = await fetch(url, { headers: HEADERS, signal: controller.signal });
    const text = await resp.text();
    return [resp.status, text];
  } finally {
    clearTimeout(timeoutId);
  }
}

const SCRIPT_RE = /<(script|style)\b[\s\S]*?<\/\1>/gi;
const TAGS_RE = /<[^>]+>/g;

function toText(html: string): string {
  let h = html.replace(SCRIPT_RE, " ");
  h = h.replace(/<br\s*\/?>/gi, "\n");
  h = h.replace(/<\/(p|div|li|h[1-6]|tr)>\n?/gi, "\n");
  h = h.replace(TAGS_RE, " ");
  h = h.replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&quot;/g, '"');
  h = h.replace(/&lt;/g, "<").replace(/&gt;/g, ">");
  const lines = h.split("\n").map((ln) => ln.replace(/[ \t]+/g, " ").trim());
  return lines.filter((ln) => ln).join("\n");
}

// 候选来源：精确关键词搜索 + 具体文档页
const TARGETS: [string, string][] = [
  ["search_exact_1", "https://www.so.com/s?q=" + encodeURIComponent("2025年新高考一卷数学第19题 原题")],
  ["search_exact_2", "https://www.so.com/s?q=" + encodeURIComponent("2025年高考数学 压轴题 第19题 题干")],
  ["search_exact_3", "https://www.so.com/s?q=" + encodeURIComponent("2025 新高考 I 卷 数学 19题 数列")],
  ["wenku_1", "https://wenku.so.com/d/85c5b7db0b7eb2ea2e6c87c824f3c230"],
  ["wenku_2", "https://wenku.so.com/d/fe77ff322f9cead09e99c918d1d27847"],
];

async function main() {
  for (const [name, url] of TARGETS) {
    try {
      const [st, html] = await fetchUrl(url);
      const txt = toText(html);
      const fn = `page_${name}.txt`;
      fs.writeFileSync(fn, `URL: ${url}\nSTATUS: ${st}\nLEN: ${txt.length}\n\n` + txt, "utf-8");
      console.log("=== %s status=%s textlen=%d -> %s", name, st, txt.length, fn);
      // 打印含关键词的片段
      for (const kw of ["压轴", "第19题", "19题", "19.", "设", "已知"]) {
        const idx = txt.indexOf(kw);
        if (idx >= 0) {
          const s = Math.max(0, idx - 60);
          const e = Math.min(txt.length, idx + 200);
          const seg = txt.slice(s, e).replace(/\n/g, " ");
          console.log("   [%s] %s", kw, seg.slice(0, 240));
        }
      }
    } catch (e: any) {
      console.log("=== %s ERROR %s: %s", name, e.constructor.name, e.message);
    }
    await new Promise((r) => setTimeout(r, 1500));
  }
  console.log("DONE");
}

main();