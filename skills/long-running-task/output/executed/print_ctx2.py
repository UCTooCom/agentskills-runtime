# -*- coding: utf-8 -*-
import os, io, json
BASE = os.path.dirname(os.path.abspath(__file__))
T1 = os.path.join(BASE, "t1")


def show(fname, kws, before=600, after=900, maxhits=3):
    p = os.path.join(T1, fname)
    if not os.path.exists(p):
        print("MISSING|%s" % fname)
        return
    with io.open(p, "r", encoding="utf-8", errors="replace") as f:
        t = f.read()
    print("FILE|%s|len=%d" % (fname, len(t)))
    for kw in kws:
        hits = 0
        start = 0
        while hits < maxhits:
            i = t.find(kw, start)
            if i < 0:
                break
            ctx = t[max(0, i - before): i + after]
            print("CTX|%s|%s|%s" % (fname, json.dumps(kw, ensure_ascii=True), json.dumps(ctx, ensure_ascii=True)))
            hits += 1
            start = i + len(kw)


show("qg_pingxi_html.plain.txt", ["19"], maxhits=6)
show("qg_pingxi_html.plain.txt", ["\u65b0\u5b9a\u4e49"], maxhits=3)
show("qg1_st_html.plain.txt", ["\u8003\u8bd5\u65f6\u95f4"], maxhits=1)
show("qg2_st_html.plain.txt", ["\u8003\u8bd5\u65f6\u95f4"], maxhits=1)
