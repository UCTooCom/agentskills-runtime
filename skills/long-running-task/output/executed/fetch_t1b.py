# -*- coding: utf-8 -*-
import os, re, io, json, urllib.request, ssl

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
T1 = os.path.join(BASE, "t1")
IMG = os.path.join(T1, "img")
os.makedirs(IMG, exist_ok=True)

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE
HDR = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36",
    "Accept-Language": "zh-CN,zh;q=0.9",
}


def rd(name):
    p = os.path.join(RAW, name)
    if not os.path.exists(p):
        return ""
    for enc in ("utf-8", "gbk", "gb18030"):
        try:
            with io.open(p, "r", encoding=enc, errors="strict") as f:
                return f.read()
        except Exception:
            continue
    with io.open(p, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


# ---------- A. 抽取 qg1/qg2 试题图片直链 ----------
result = {"images": {}, "text_sources": []}
for name, tag in (("qg1_st.html", "qg1"), ("qg2_st.html", "qg2")):
    t = rd(name)
    urls = re.findall(r'''(?:src|data-src)\s*=\s*["']([^"']+\.(?:jpg|jpeg|png|gif|webp))["']''', t, re.I)
    keep = []
    for u in urls:
        if ("qg1" in u or "qg2" in u or "/st/" in u) and u not in keep:
            keep.append(u)
    result["images"][tag] = keep

print("IMG_LIST|" + json.dumps(result["images"], ensure_ascii=True))

# ---------- B. 下载试题图片 ----------
dl = []
for tag, urls in result["images"].items():
    for i, u in enumerate(urls[:12]):
        fn = "%s_%02d%s" % (tag, i, os.path.splitext(u.split("?")[0])[1] or ".png")
        fp = os.path.join(IMG, fn)
        try:
            req = urllib.request.Request(u, headers=HDR)
            with urllib.request.urlopen(req, timeout=20, context=CTX) as r:
                data = r.read()
            with open(fp, "wb") as f:
                f.write(data)
            dl.append({"url": u, "file": fn, "bytes": len(data)})
        except Exception as e:
            dl.append({"url": u, "file": fn, "error": str(e)[:120]})
result["downloads"] = dl
print("DL|" + json.dumps(dl, ensure_ascii=True))

# ---------- C. 直连候选文字版源 ----------
CAND = [
    "http://gaokao.eol.cn/shiti/sx/202506/t20250607_2673303.shtml",
    "https://gaokao.eol.cn/shiti/sx/202506/t20250607_2673303.shtml",
    "http://gaokao.eol.cn/e_html/gk/2025gkshiti/index.shtml",
]
KWS = ["19.", "19\uff0e", "\u7b2c19\u9898", "\u65b0\u5b9a\u4e49", "\u4e09\u89d2\u51fd\u6570",
       "\u5bfc\u6570", "f(x)", "sin", "cos", "\u8bc1\u660e", "\u6c42"]
for url in CAND:
    rec = {"url": url}
    try:
        req = urllib.request.Request(url, headers=HDR)
        with urllib.request.urlopen(req, timeout=25, context=CTX) as r:
            data = r.read()
        for enc in ("utf-8", "gbk", "gb18030"):
            try:
                txt = data.decode(enc)
                rec["encoding"] = enc
                break
            except Exception:
                txt = None
        if txt is None:
            txt = data.decode("utf-8", "replace")
            rec["encoding"] = "utf-8(replace)"
        rec["bytes"] = len(data)
        rec["hits"] = {k: txt.count(k) for k in KWS}
        # 抓 19. 上下文
        c = []
        for k in ("19.", "\u7b2c19\u9898"):
            i = txt.find(k)
            if i >= 0:
                c.append(txt[max(0, i - 200): i + 800])
        rec["ctx"] = c[:2]
    except Exception as e:
        rec["error"] = str(e)[:160]
    result["text_sources"].append(rec)
    print("SRC|" + json.dumps(rec, ensure_ascii=True))

with io.open(os.path.join(T1, "fetch_t1b.json"), "w", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)
print("DONE")
