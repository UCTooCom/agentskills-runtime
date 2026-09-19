# -*- coding: utf-8 -*-
"""第五轮：短超时(8s)单URL容错抓取 EOL 真题入口 + 回读 offline_parse 的 bing 条目"""
import html
import json
import os
import re
import ssl
import socket
import urllib.request

socket.setdefaulttimeout(8)

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")

# ---- 回读离线解析结果中的 bing 条目 ----
op = os.path.join(RAW, "_offline_parse.json")
if os.path.exists(op):
    with open(op, "r", encoding="utf-8") as f:
        d = json.load(f)
    print("bing_html_items:", len(d.get("bing_html_items", [])))
    for it in d.get("bing_html_items", [])[:12]:
        print("  T:", it["title"][:95])
        print("  U:", it["url"][:140])
        print("  S:", it["snippet"][:180])
        print("")
else:
    print("no _offline_parse.json")


def fetch(name, url, timeout=8):
    rec = {"name": name, "url": url, "ok": False}
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(url, headers={
            "User-Agent": UA,
            "Accept-Language": "zh-CN,zh;q=0.9",
            "Accept-Encoding": "identity",
        })
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            raw = resp.read()
            rec["status"] = resp.status
        text = None
        for enc in ("utf-8", "gb18030"):
            try:
                text = raw.decode(enc)
                rec["encoding"] = enc
                break
            except UnicodeDecodeError:
                continue
        if text is None:
            text = raw.decode("utf-8", errors="replace")
        rec["ok"] = rec["status"] == 200
        rec["length"] = len(text)
        rec["file"] = os.path.join(RAW, name + ".txt")
        with open(rec["file"], "w", encoding="utf-8") as f:
            f.write(text)
    except Exception as e:
        rec["error"] = "%s: %s" % (type(e).__name__, e)
    return rec


print("\n===== fetch EOL entries (short timeout, isolated) =====")
urls = [
    ("eol_gkst", "https://gaokao.eol.cn/e_html/gk/gkst/"),
    ("eol_sx", "http://gaokao.eol.cn/shiti/sx/"),
]
res = []
for n, u in urls:
    r = fetch(n, u)
    res.append(r)
    print("  %-12s ok=%-5s st=%-5s len=%-8s err=%s" % (
        n, r.get("ok"), r.get("status", "-"), r.get("length", "-"), r.get("error", "")[:100]))

# ---- 提取链接 ----
print("\n===== extract candidate anchors =====")
allc = []
for r in res:
    fp = r.get("file")
    if not fp or not os.path.exists(fp):
        continue
    with open(fp, "r", encoding="utf-8", errors="replace") as f:
        doc = f.read()
    for m in re.finditer(r'<a[^>]+href="([^"]+)"[^>]*>(.{2,90}?)</a>', doc, re.S):
        href = html.unescape(m.group(1)).strip()
        txt = html.unescape(re.sub(r'<[^>]+>', '', m.group(2))).strip()
        if not txt:
            continue
        allc.append((r["name"], txt[:70], href[:200]))
print("  total anchors:", len(allc))
seen = set()
shown = 0
for s, t, h in allc:
    if ("数学" in t or "真题" in t or "试题" in t or "2025" in t):
        k = (t, h)
        if k in seen:
            continue
        seen.add(k)
        print("  [%s] %-46s -> %s" % (s, t, h))
        shown += 1
        if shown >= 60:
            break

with open(os.path.join(RAW, "_round5.json"), "w", encoding="utf-8") as f:
    json.dump({"res": res, "anchors": allc}, f, ensure_ascii=False, indent=2)
print("\nsaved -> raw/_round5.json")
