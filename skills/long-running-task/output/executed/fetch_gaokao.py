# -*- coding: utf-8 -*-
"""多源拓取 2025 年高考数学压轴题题干（仅公开页面，不绕反爬）"""
import json, os, re, sys, time, ssl

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
os.makedirs(OUT, exist_ok=True)

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")

CANDIDATES = [
    ("eol_gaokao", "https://gaokao.eol.cn/"),
    ("eol_news", "https://news.eol.cn/"),
    ("people_edu", "http://edu.people.com.cn/"),
    ("xinhua_edu", "http://education.news.cn/"),
    ("sina_edu", "https://edu.sina.com.cn/"),
    ("tencent_edu", "https://edu.qq.com/"),
    ("sohu_edu", "https://learning.sohu.com/"),
    ("baidu_s", "https://www.baidu.com/s?wd=2025%E5%B9%B4%E9%AB%98%E8%80%83%E6%95%B0%E5%AD%A6%E5%8E%8B%E8%BD%B4%E9%A2%98"),
    ("bing_s", "https://cn.bing.com/search?q=2025%E5%B9%B4%E9%AB%98%E8%80%83%E6%95%B0%E5%AD%A6%E6%96%B0%E8%AF%BE%E6%A0%87I%E5%8D%B7%E5%8E%8B%E8%BD%B4%E9%A2%98"),
    ("ddg", "https://duckduckgo.com/html/?q=2025+gaokao+math+final+problem"),
]


def fetch(name, url, timeout=20):
    rec = {"name": name, "url": url, "ok": False}
    try:
        try:
            import requests
            r = requests.get(url, headers={"User-Agent": UA,
                                          "Accept-Language": "zh-CN,zh;q=0.9"},
                             timeout=timeout, verify=False)
            r.encoding = r.apparent_encoding or "utf-8"
            text = r.text
            rec["status"] = r.status_code
        except ImportError:
            import urllib.request
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
                text = resp.read().decode("utf-8", errors="replace")
                rec["status"] = resp.status
        rec["ok"] = True
        rec["length"] = len(text)
        path = os.path.join(OUT, name + ".html")
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        rec["file"] = path
        rec["head"] = re.sub(r"\s+", " ", text[:300])
    except Exception as e:
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    return rec


results = []
for n, u in CANDIDATES:
    results.append(fetch(n, u))
    time.sleep(0.8)

with open(os.path.join(OUT, "_fetch_report.json"), "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

for r in results:
    print("%-14s ok=%-5s status=%-5s len=%-8s err=%s" % (
        r["name"], r.get("ok"), r.get("status", "-"), r.get("length", "-"), r.get("error", "")))
