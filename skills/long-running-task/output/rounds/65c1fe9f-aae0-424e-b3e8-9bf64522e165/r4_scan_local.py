# -*- coding: utf-8 -*-
"""Round4: scan ALL local corpus (html/txt) for 2025 chemistry exam content."""
import os, re, json, io

ROOT = os.path.dirname(os.path.abspath(__file__))
ENCS = ["utf-8", "gb18030", "gbk", "big5", "utf-16"]

MARK = [
    "压轴", "有机合成", "电解池", "水解", "平衡常数", "Ksp", "焓变",
    "选择题", "非选择题", "化学方程式", "结构简式", "物质的量",
    "2025", "新课标", "全国卷", "高考化学", "参考答案", "解析",
]
CHEM_HINT = re.compile(r"(化学|H2O|CO2|mol/L|△H|电极|催化剂|官能团|同分异构|滴定|Ka|pH)", re.I)

hits = []
files = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    for fn in filenames:
        if fn.lower().endswith((".html", ".htm", ".txt")):
            files.append(os.path.join(dirpath, fn))

print("TOTAL FILES:", len(files))

for fp in files:
    raw = open(fp, "rb").read()
    if len(raw) > 6_000_000:
        raw = raw[:6_000_000]
    best = None
    for cs in ENCS:
        try:
            t = raw.decode(cs)
        except Exception:
            continue
        # score: count of chinese chars + markers
        cjk = len(re.findall(r"[\u4e00-\u9fff]", t))
        mk = sum(t.count(m) for m in MARK)
        score = cjk + mk * 5
        if best is None or score > best[0]:
            best = (score, cs, t)
    if not best:
        continue
    score, cs, text = best
    if CHEM_HINT.search(text) is None:
        continue
    # extract windows around chemistry exam markers
    passages = []
    for m in re.finditer(r"压轴|有机合成|电解池|平衡常数|参考答案|解析|第\s*1[5-9]\s*题|15\.|16\.", text):
        s = max(0, m.start() - 300)
        e = min(len(text), m.end() + 600)
        seg = text[s:e]
        seg = re.sub(r"<script.*?</script>", " ", seg, flags=re.S | re.I)
        seg = re.sub(r"<style.*?</style>", " ", seg, flags=re.S | re.I)
        seg = re.sub(r"<[^>]+>", " ", seg)
        seg = re.sub(r"\s+", " ", seg).strip()
        if len(re.findall(r"[\u4e00-\u9fff]", seg)) > 40:
            passages.append(seg[:1200])
    if passages:
        hits.append({"file": os.path.relpath(fp, ROOT).replace("\\", "/"), "bytes": len(raw), "enc": cs, "cjk": len(re.findall(r"[\u4e00-\u9fff]", text)), "n_pass": len(passages), "passages": passages[:6]})

hits.sort(key=lambda h: (h["n_pass"], h["cjk"]), reverse=True)
json.dump(hits, open(os.path.join(ROOT, "r4_local_hits.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("HITS:", len(hits))
for h in hits[:12]:
    print("==", h["file"], "|", h["bytes"], "B|", h["enc"], "| cjk=", h["cjk"], "| pass=", h["n_pass"])
    for p in h["passages"][:2]:
        print("   >", p[:260])
print("\nWROTE r4_local_hits.json")
