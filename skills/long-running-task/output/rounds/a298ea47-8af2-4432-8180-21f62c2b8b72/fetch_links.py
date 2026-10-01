# -*- coding: utf-8 -*-
import urllib.parse, urllib.request, ssl, re, json

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
    text = text.replace("\u0000", " ")
    text = re.sub(r"\s+", " ", text)
    return text

def extract_links(html, pattern):
    return re.findall(pattern, html)

# 360 搜索更易解析
engines = [
    ("so360", "https://www.so.com/s?q="),
    ("sogou", "https://www.sogou.com/web?query="),
]

queries = [
    "2025 高考 物理 压轴题 物块 圆弧轨道 弹簧 原题",
    "2025新课标卷物理压轴题 解析",
]

for name, base in engines:
    for q in queries:
        url = base + urllib.parse.quote(q)
        code, text = fetch(url)
        print("===== ENGINE:", name, "| QUERY:", q)
        print("STATUS:", code, "LEN:", len(text))
        if code == 200:
            # 提取所有 http 链接
            links = re.findall(r'href="(https?://[^"\s]+)"', text)
            seen = []
            for l in links:
                if any(k in l for k in ["so.com", "sogou", "360", "baidu.com/s"]):
                    continue
                if l not in seen:
                    seen.append(l)
            print("CANDIDATE_LINKS:", len(seen))
            for l in seen[:40]:
                print("  ", l)
            t = strip_tags(text)
            # 找出含关键字段的片段
            for kw in ["压轴", "圆弧", "弹簧", "物块"]:
                idx = t.find(kw)
                if idx >= 0:
                    print("SNIPPET[", kw, "]:", t[max(0,idx-200):idx+400])
        print()
