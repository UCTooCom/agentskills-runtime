# -*- coding: utf-8 -*-
"""诊断已抓取的高考试题页：提取正文候选段 + 图片/PDF 直链"""
import os, re, json, io

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
OUT = os.path.join(BASE)

TARGETS = ["qg1_st.html", "qg2_st.html", "qg1_st.txt", "qg2_st.txt",
           "eol_2025st.txt", "qg_pingxi.txt", "qg_pingxi.html"]

KEYWORDS = ["压轴", "19.", "第19题", "19题", "新定义", "导数", "解析几何",
            "椭圆", "抛物线", "数列", "对折", "调性", "最小正周期",
            "新课标", "全国卷", "f(x)", "答题"]

report = {"files": [], "generated_at": "2026-09-16", "cwd": os.getcwd()}

for name in TARGETS:
    p = os.path.join(RAW, name)
    rec = {"file": name, "exists": os.path.exists(p)}
    if not rec["exists"]:
        report["files"].append(rec)
        continue
    rec["size"] = os.path.getsize(p)
    # 尝试多种编码读取
    text = None
    used_enc = None
    for enc in ("utf-8", "utf-8-sig", "gbk", "gb18030", "big5"):
        try:
            with io.open(p, "r", encoding=enc, errors="strict") as f:
                text = f.read()
            used_enc = enc
            break
        except Exception:
            continue
    if text is None:
        with io.open(p, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
        used_enc = "utf-8(replace)"
    rec["encoding"] = used_enc
    rec["text_len"] = len(text)

    # 关键词命中（带上下文）
    hits = {}
    for kw in KEYWORDS:
        idx = text.find(kw)
        if idx >= 0:
            hits[kw] = {"count": text.count(kw), "ctx": text[max(0,idx-120): idx+200]}
    rec["keyword_hits"] = {k: v["count"] for k, v in hits.items()}
    rec["hit_contexts"] = {k: v["ctx"] for k, v in hits.items()}

    # 图片 / PDF 直链
    imgs = re.findall(r'''(?:src|href)\s*=\s*["']([^"']+\.(?:jpg|jpeg|png|gif|webp|pdf)(?:\?[^"']*)?)["']''', text, re.I)
    rec["media_links"] = imgs[:40]

    # 纯文本视图（去标签）用于人工阅读
    plain = re.sub(r"<script[^>]*>.*?</script>", " ", text, flags=re.S | re.I)
    plain = re.sub(r"<style[^>]*>.*?</style>", " ", plain, flags=re.S | re.I)
    plain = re.sub(r"<[^>]+>", "\n", plain)
    plain = re.sub(r"&nbsp;", " ", plain)
    plain = re.sub(r"[ \t\r\f\v]+", " ", plain)
    plain = re.sub(r"\n{2,}", "\n", plain)
    rec["plain_len"] = len(plain)
    rec["plain_head"] = plain[:1500]

    # 找含“题”或数字小问的段落
    segs = [s.strip() for s in plain.split("\n") if len(s.strip()) > 12]
    rec["candidate_segments"] = [s for s in segs if ("(" in s and ")" in s) or "题" in s][:25]

    report["files"].append(rec)

with io.open(os.path.join(OUT, "probe_qg.json"), "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)

print("OK probe_qg.json written")
for rec in report["files"]:
    print("-", rec["file"], "exists=", rec["exists"], "enc=", rec.get("encoding"),
          "size=", rec.get("size"), "plain_len=", rec.get("plain_len"),
          "media=", len(rec.get("media_links", [])), "hits=", rec.get("keyword_hits"))
