# -*- coding: utf-8 -*-
import sys, ssl, re
import urllib.request, urllib.parse

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"

def get(url, timeout=25):
    req = urllib.request.Request(url, headers={
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        "Connection": "close",
    })
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        data = r.read()
        enc = r.headers.get_content_charset() or "utf-8"
        return data.decode(enc, errors="ignore")

urls = [
    "https://www.sogou.com/web?query=" + urllib.parse.quote("2025年全国甲卷物理25题题干"),
    "https://www.so.com/s?q=" + urllib.parse.quote("2025年全国甲卷物理25题题干"),
    "https://cn.bing.com/search?q=" + urllib.parse.quote("2025高考物理压轴题 题号 25 题干"),
    "https://www.baidu.com/s?wd=" + urllib.parse.quote("2025年全国甲卷物理25题 题干 原文"),
]

for u in urls:
    print("="*80)
    print("URL:", u)
    try:
        h = get(u)
        # strip scripts/styles
        h2 = re.sub(r"<script[\s\S]*?</script>", " ", h, flags=re.I)
        h2 = re.sub(r"<style[\s\S]*?</style>", " ", h2, flags=re.I)
        txt = re.sub(r"<[^>]+>", " ", h2)
        txt = re.sub(r"&nbsp;", " ", txt)
        txt = re.sub(r"\s+", " ", txt)
        print("LEN:", len(h), "TEXTLEN:", len(txt))
        # look for keywords
        for kw in ["25题", "压轴", "题干", "滑块", "木板", "磁场", "电场", "导体棒", "2025"]:
            i = txt.find(kw)
            if i >= 0:
                print("[%s] ..." % kw, txt[max(0,i-80):i+200])
        print("HEAD:", txt[:500])
    except Exception as e:
        print("ERR:", repr(e))
