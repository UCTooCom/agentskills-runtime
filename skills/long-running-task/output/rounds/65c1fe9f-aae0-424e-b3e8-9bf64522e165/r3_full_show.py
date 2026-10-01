# -*- coding: utf-8 -*-
import sys, io, os, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
OUT = os.path.dirname(os.path.abspath(__file__))

for fn in ['r3dump_gaosan_ct.txt']:
    p = os.path.join(OUT, fn)
    print('\n' + '='*100)
    print('### FULL: ' + fn)
    print('='*100)
    with open(p, 'r', encoding='utf-8', errors='replace') as f:
        txt = f.read()
    print(txt)

# grep 艾拉莫德 across all txt files
print('\n' + '#'*100)
print('# GREP: 艾拉莫德 / 合成路线 / 29题')
print('#'*100)
for root, dirs, fs in os.walk(OUT):
    for f in fs:
        if not f.endswith('.txt'):
            continue
        p = os.path.join(root, f)
        try:
            with open(p, 'r', encoding='utf-8', errors='replace') as fh:
                t = fh.read()
        except Exception:
            continue
        for kw in ['艾拉莫德', '艾拉莫', '拉莫德']:
            if kw in t:
                print('\n[%s]  contains "%s"' % (os.path.relpath(p,OUT), kw))
                for m in re.finditer(kw, t):
                    s = max(0, m.start()-200); e = min(len(t), m.end()+400)
                    print('   ...%s...' % t[s:e].replace('\n',' '))
                break
