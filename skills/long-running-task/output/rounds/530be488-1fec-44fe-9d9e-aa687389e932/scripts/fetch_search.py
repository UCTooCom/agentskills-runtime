# -*- coding: utf-8 -*-
import sys, io, json, urllib.parse
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

try:
    import requests
except Exception as e:
    print(json.dumps({"ok": False, "stage": "import", "error": str(e)}, ensure_ascii=False))
    sys.exit(0)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
}

queries = [
    "2025年高考物理压轴题 最后一题",
    "2025 高考物理 压轴题 解析",
]
engines = {
    "bing": "https://www.bing.com/search?q={q}",
    "duckduckgo_html": "https://html.duckduckgo.com/html/?q={q}",
    "sogou": "https://www.sogou.com/web?query={q}",
    "so360": "https://www.so.com/s?q={q}",
}

out = []
for ename, tpl in engines.items():
    for q in queries[:1]:
        url = tpl.format(q=urllib.parse.quote(q))
        rec = {"engine": ename, "url": url}
        try:
            r = requests.get(url, headers=HEADERS, timeout=20)
            rec["status"] = r.status_code
            rec["len"] = len(r.text)
            rec["head"] = r.text[:300]
        except Exception as e:
            rec["error"] = repr(e)
        out.append(rec)

print(json.dumps(out, ensure_ascii=False, indent=2))
