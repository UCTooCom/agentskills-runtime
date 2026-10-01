# -*- coding: utf-8 -*-
"""纯标准库抓取：多查询搜索 -> 抽取候选URL -> 抓正文 -> 关键词段落提取"""
import sys, os, re, json, ssl, time
from urllib.parse import quote, urljoin

if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

import urllib.request

BASE = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output"
RAW = os.path.join(BASE, "raw")
os.makedirs(RAW, exist_ok=True)

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

HDRS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Connection": "close",
}


def get(url, timeout=25):
    req = urllib.request.Request(url, headers=HDRS)
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
        data = r.read()
    for enc in ("utf-8", "gb18030", "latin-1"):
        try:
            return data.decode(enc)
        except Exception:
            continue
    return data.decode("utf-8", "replace")


def to_plain(html):
    t = re.sub(r"<script[\s\S]*?</script>", " ", html, flags=re.I)
    t = re.sub(r"<style[\s\S]*?</style>", " ", t, flags=re.I)
    t = re.sub(r"<[^>]+>", " ", t)
    t = re.sub(r"&nbsp;|&#160;", " ", t)
    t = re.sub(r"&[a-zA-Z]+;", " ", t)
    t = re.sub(r"\s+", " ", t)
    return t


QUERIES = [
    "2025年高考物理最后一题原题",
    "2025高考物理压轴题 第18题 题目原文",
    "2025全国甲卷物理压轴题原题",
    "2025年高考物理新课标一卷 计算题 最后一题",
]

KW = ["最后一题", "最后一道", "压轴题", "第18题", "17.", "18.", "19."]

serp_report = []
all_candidates = []

for i, q in enumerate(QUERIES, 1):
    url = "https://cn.bing.com/search?q=" + quote(q) + "&ensearch=0"
    rec = {"query": q, "url": url}
    try:
        html = get(url)
        rec["status"] = "ok"
        rec["len"] = len(html)
        with open(os.path.join(RAW, "serp_%d.html" % i), "w", encoding="utf-8") as f:
            f.write(html[:800000])
        plain = to_plain(html)
        with open(os.path.join(RAW, "serp_%d.txt" % i), "w", encoding="utf-8") as f:
            f.write(plain)
        links = re.findall(r'<h2[^>]*>\s*<a[^>]+href="(https?://[^"]+)"', html, flags=re.I)
        if not links:
            links = re.findall(r'href="(https?://(?!www\.bing|cn\.bing|go\.microsoft|support\.microsoft)[^"]+)"', html)
        seen, uniq = set(), []
        for l in links:
            if l not in seen:
                seen.add(l)
                uniq.append(l)
        rec["links"] = uniq[:25]
        all_candidates.extend(uniq[:15])
    except Exception as e:
        rec["status"] = "error"
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    serp_report.append(rec)
    print("[SERP %d]" % i, rec.get("status"), rec.get("len", ""), "links=", len(rec.get("links", [])))
    for l in rec.get("links", [])[:8]:
        print("   ", l[:160])
    time.sleep(1.5)

with open(os.path.join(RAW, "serp_report.json"), "w", encoding="utf-8") as f:
    json.dump(serp_report, f, ensure_ascii=False, indent=2)

# 抓取候选正文页
doc_report = []
seen_url = set()
for u in all_candidates:
    if u in seen_url:
        continue
    seen_url.add(u)
    if len(seen_url) > 12:
        break
    idx = len(doc_report) + 1
    rec = {"url": u}
    try:
        html = get(u, timeout=20)
        plain = to_plain(html)
        rec["status"] = "ok"
        rec["len"] = len(plain)
        with open(os.path.join(RAW, "doc_%d.txt" % idx), "w", encoding="utf-8") as f:
            f.write(plain[:400000])
        hits = []
        for m in re.finditer("|".join(re.escape(k) for k in KW), plain):
            s = max(0, m.start() - 120)
            e = min(len(plain), m.end() + 400)
            hits.append(plain[s:e])
        rec["hits"] = hits[:6]
    except Exception as e:
        rec["status"] = "error"
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    doc_report.append(rec)
    print("[DOC %d]" % idx, rec.get("status"), rec.get("len", ""), u[:110])
    time.sleep(1.2)

with open(os.path.join(RAW, "doc_report.json"), "w", encoding="utf-8") as f:
    json.dump(doc_report, f, ensure_ascii=False, indent=2)

print("\n===== DOC HITS =====")
for rec in doc_report:
    if rec.get("hits"):
        print("\n### ", rec["url"][:120])
        for h in rec["hits"][:4]:
            print("  ---", h[:420])
