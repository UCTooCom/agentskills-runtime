# -*- coding: utf-8 -*-
import sys, io, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
OUT = os.path.dirname(os.path.abspath(__file__))
for fn in ['r3dump_gaosan_ct.txt','r3dump_tt2.txt','r3dump_tt1.txt','r3dump_gaosan_1125350.txt','r3dump_wx_sogou.txt','r3dump_r3c.txt','r3dump_weixin2.txt']:
    p = os.path.join(OUT, fn)
    print('\n' + '='*90)
    print('### ' + fn)
    print('='*90)
    if not os.path.exists(p):
        print('  (missing)')
        continue
    with open(p, 'r', encoding='utf-8', errors='replace') as f:
        txt = f.read()
    print(txt[:6000])
