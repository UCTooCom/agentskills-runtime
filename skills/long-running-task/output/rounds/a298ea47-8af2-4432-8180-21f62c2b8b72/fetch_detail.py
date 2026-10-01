# -*- coding: utf-8 -*-
import sys, json, urllib.parse, urllib.request, ssl, re

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36",
    "Accept-Language": "zh-CN,zh;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

def fetch(url, timeout=25):
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            data = resp.read()
        return resp.status, data.decode("utf-8", errors="ignore")
    except Exception as e:
        return -1, repr(e)

def strip_tags(html):
    html = re.sub(r"<script[\s\S]*?</script>", " ", html, flags=re.I)
    html = re.sub(r"<style[\s\S]*?</style>", " ", html, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"&nbsp;?", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text

queries = [
    "2025 新课标卷 物理 压轴题 物块P 小球 弹簧 原题",
    "2025全国甲卷物理最后一题 原题 物块 圆弧轨道 弹簧",
]

for q in queries:
    url = "https://www.baidu.com/s?wd=" + urllib.parse.quote(q)
    code, text = fetch(url)
    print("===== QUERY:", q)
    print("STATUS:", code, "LEN:", len(text))
    t = strip_tags(text)
    print(t[:3500])
    print()
