# -*- coding: utf-8 -*-
"""第二轮多源拓取：Bing RSS + 教育站专题页 + 百科"""
import json, os, re, time, ssl, urllib.parse

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
os.makedirs(RAW, exist_ok=True)

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")

queries = [
    "2025年高考数学新课标I卷压轴题",
    "2025高考数学最后一题题干",
    "2025年高考数学全国一卷19题",
]

sources = []
for i, q in enumerate(queries, 1):
    e = urllib.parse.quote(q)
    sources.append(("bing_rss_%d" % i, "https://cn.bing.com/search?q=%s&format=rss" % e))

sources += [
    ("baike_gaokao2025", "https://baike.baidu.com/item/2025%E5%B9%B4%E6%99%AE%E9%80%9A%E9%AB%98%E7%AD%89%E5%AD%A6%E6%A0%A1%E6%8B%9B%E7%94%9F%E5%85%A8%E5%9B%BD%E7%BB%9F%E4%B8%80%E8%80%83%E8%AF%95%E6%95%B0%E5%AD%A6"),
    ("eol_zhenti", "https://gaokao.eol.cn/e_html/gk/zhenti/index.shtml"),
    ("sina_zhenti", "https://edu.sina.com.cn/gaokao/2025-06-07/doc-gaokao-math.shtml"),
    ("xinhuanet_gaokao", "http://www.news.cn/edu/20250607/index.htm"),
]


def fetch(name, url, timeout=20):
    rec = {"name": name, "url": url, "ok": False}
    try:
        import requests
        r = requests.get(url, headers={"User-Agent": UA,
                                       "Accept-Language": "zh-CN,zh;q=0.9",
                                       "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
                         timeout=timeout, verify=False)
        r.encoding = r.apparent_encoding or "utf-8"
        text = r.text
        rec["status"] = r.status_code
        rec["ok"] = r.status_code == 200
        rec["length"] = len(text)
        p = os.path.join(RAW, name + ".html")
        with open(p, "w", encoding="utf-8") as f:
            f.write(text)
        rec["file"] = p
        hits = {k: text.count(k) for k in ["压轴", "新课标", "19题", "导数", "椭圆", "数列", "解析几何", "新定义"]}
        rec["hits"] = hits
    except Exception as e:
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    return rec


res = []
for n, u in sources:
    res.append(fetch(n, u))
    time.sleep(0.6)

with open(os.path.join(RAW, "_round2_report.json"), "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=2)

for r in res:
    print("%-18s ok=%-5s st=%-5s len=%-8s hits=%s err=%s" % (
        r["name"], r.get("ok"), r.get("status", "-"), r.get("length", "-"),
        json.dumps(r.get("hits", {}), ensure_ascii=False), r.get("error", "")))
