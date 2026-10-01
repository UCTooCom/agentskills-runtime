# -*- coding: utf-8 -*-
import os, re, sys
OUT = os.path.dirname(os.path.abspath(__file__))
TARGETS = [
    "gaosan_1125274.txt", "gaosan_1125350.txt",
    "r3dump_gaosan_1125274.txt", "r3dump_weixin2.txt",
    "pages/weixin_2.html", "r3dump_toutiao_so.txt", "r3dump_wx_sogou.txt",
    "cnjy_23616335.html", "zxxk_3508877.html",
]
ENCS = ["utf-8", "gb18030", "gbk"]

def clean(t):
    t = re.sub(r"<script.*?</script>", " ", t, flags=re.S|re.I)
    t = re.sub(r"<style.*?</style>", " ", t, flags=re.S|re.I)
    t = re.sub(r"<[^>]+>", " ", t)
    t = t.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    t = re.sub(r"[ \t\xa0]+", " ", t)
    t = re.sub(r"\n{2,}", "\n", t)
    return t.strip()

for rel in TARGETS:
    fp = os.path.join(OUT, rel)
    if not os.path.exists(fp):
        print("### MISSING:", rel); continue
    raw = open(fp, "rb").read()
    best = None
    for cs in ENCS:
        try:
            t = raw.decode(cs)
        except Exception:
            continue
        cjk = len(re.findall(r"[\u4e00-\u9fff]", t))
        if best is None or cjk > best[0]:
            best = (cjk, cs, t)
    if not best:
        print("### UNDECODABLE:", rel); continue
    cjk, cs, text = best
    body = clean(text)
    print("\n" + "="*90)
    print("### FILE:", rel, "| bytes=", len(raw), "| enc=", cs, "| cjk=", cjk, "| cleanlen=", len(body))
    print("="*90)
    # print chem-relevant windows
    printed = 0
    for m in re.finditer(r"压轴|有机合成|电解|平衡常数|参考答案|【解析】|解析】：|第\s*1[5-9]\s*题|15\.\(|16\.\(|化学方程式", body):
        s = max(0, m.start()-200); e = min(len(body), m.end()+800)
        seg = body[s:e]
        print("---window---")
        print(seg)
        printed += 1
        if printed >= 5: break
    if printed == 0:
        print(body[:1500])
