# -*- coding: utf-8 -*-
import os, sys, io, json, glob
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

BASE = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output"

def show(p, n=3000):
    print("="*70)
    print("FILE:", p)
    try:
        t = open(p, 'r', encoding='utf-8', errors='replace').read()
    except Exception as e:
        print("ERR", e); return
    print("len=", len(t))
    print(t[:n])

show(os.path.join(BASE, "checkpoint", "progress.md"), 4000)

# search corpus for physics keywords
kw = ["物理", "压轴", "电磁", "动量", "圆周运动", "带电粒子"]
t1 = os.path.join(BASE, "executed", "t1")
print("\n"+"#"*70)
print("T1 dir listing:")
for p in sorted(glob.glob(os.path.join(t1, "*"))):
    print("  ", os.path.basename(p), os.path.getsize(p) if os.path.isfile(p) else "<dir>")

plain = os.path.join(t1, "eol_2025st_txt.plain.txt")
if os.path.exists(plain):
    t = open(plain, 'r', encoding='utf-8', errors='replace').read()
    print("\nplain.txt len=", len(t))
    for k in kw:
        print("  kw", k, "count=", t.count(k))
    print("----- first 2500 -----")
    print(t[:2500])
