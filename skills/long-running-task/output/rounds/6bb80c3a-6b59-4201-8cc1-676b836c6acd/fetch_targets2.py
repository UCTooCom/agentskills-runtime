# -*- coding: utf-8 -*-
"""直接抓取候选页面（教育网站/文库），宽容解码，落盘并打印正文。"""
import sys, re, os, time, gzip, ssl, html as htmlmod
import urllib.request

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

OUT = os.path.dirname(os.path.abspath(__file__))
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Accept-Encoding": "gzip, deflate",
    "Connection": "close",
}

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout, context=CTX) as r:
        raw = r.read()
        if (r.headers.get("Content-Encoding") or "").lower().find("gzip") >= 0:
            try:
                raw = gzip.decompress(raw)
            except Exception:
                pass
        # 宽容解码：先 utf-8，失败再 gb18030
        txt = None
        for enc in ("utf-8", "gb18030"):
            try:
                txt = raw.decode(enc)
                break
            except Exception:
                continue
        if txt is None:
            txt = raw.decode("utf-8", errors="replace")
        return r.status, txt

def to_text(h):
    h = re.sub(r"(?is)<script.*?</script>", " ", h)
    h = re.sub(r"(?is)<style.*?</style>", " ", h)
    h = re.sub(r"(?i)<br\s*/?>", "\n", h)
    h = re.sub(r"(?i)</(p|div|li|h[1-6]|tr|table|section|article)>\s*", "\n", h)
    h = re.sub(r"<[^>]+>", " ", h)
    h = htmlmod.unescape(h)
    h = h.replace("\u00a0", " ")
    h = re.sub(r"[ \t\r\f\v]+", " ", h)
    h = re.sub(r"\n\s*\n+", "\n", h)
    return h.strip()

TARGETS = [
    ("haedu_pingxi", "https://gaokao.haedu.cn/lnzt/2025/0608/138453.html"),
    ("renren_gd", "https://m.renrendoc.com/p-476510943.html"),
    ("renren_pingxi", "https://m.renrendoc.com/paper/529645999.html"),
    ("renren_tj", "https://m.renrendoc.com/paper/529511622.html"),
]

for name, url in TARGETS:
    try:
        st, body = fetch(url)
        txt = to_text(body)
        fn = os.path.join(OUT, "page2_%s.txt" % name)
        with open(fn, "w", encoding="utf-8") as f:
            f.write("URL: %s\nSTATUS: %s\nLEN: %d\n\n" % (url, st, len(txt)))
            f.write(txt)
        print("\n\n########## %s status=%s textlen=%d -> %s" % (name, st, len(txt), fn))
        print(txt[:4000])
    except Exception as e:
        print("\n\n########## %s ERROR %s: %s" % (name, type(e).__name__, e))
    time.sleep(1.0)

print("\nDONE")
