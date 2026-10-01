# -*- coding: utf-8 -*-
import sys, io, os, re, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))
CHEM = ['化学','有机','mol','摩尔','溶液','反应','合成','催化剂','酯化','水解','方程式','氧化','还原','电极','离子','同分异构','苯','乙烯','高分子','聚合']

def strip_tags(s):
    s = re.sub(r'<script[\s\S]*?</script>','',s,flags=re.I)
    s = re.sub(r'<style[\s\S]*?</style>','',s,flags=re.I)
    s = re.sub(r'<!--[\s\S]*?-->','',s)
    s = re.sub(r'<(br|/p|/div|/li|/h[1-6]|/tr)[^>]*>','\n',s,flags=re.I)
    s = re.sub(r'<[^>]+>',' ',s)
    for a,b in [('&nbsp;',' '),('&amp;','&'),('&quot;','"'),('&#39;',"'"),('&lt;','<'),('&gt;','>')]:
        s = s.replace(a,b)
    s = re.sub(r'[ \t\xa0]+',' ',s)
    s = re.sub(r'\n{2,}','\n',s)
    return s.strip()

def dump_file(rel, outname):
    p = os.path.join(OUT, rel)
    if not os.path.exists(p):
        print('  missing %s' % rel); return None
    with open(p,'r',encoding='utf-8',errors='replace') as f:
        html = f.read()
    plain = strip_tags(html)
    with open(os.path.join(OUT, outname),'w',encoding='utf-8',errors='replace') as f:
        f.write(plain)
    lines = [x.strip() for x in plain.split('\n') if len(x.strip())>10]
    scored = []
    for i, ln in enumerate(lines):
        sc = sum(1 for kw in CHEM if kw in ln)
        if re.match(r'^\d{1,2}[\.、．]', ln): sc += 2
        if ('（1）' in ln or '(1)' in ln) and ('（2）' in ln or '(2)' in ln): sc += 2
        if sc >= 2: scored.append((sc, ln))
    scored.sort(key=lambda x:-x[0])
    print('\n===== %s -> %s  (plain=%d, hits=%d) =====' % (rel, outname, len(plain), len(scored)))
    for sc, ln in scored[:6]:
        print('  [%d] %s' % (sc, ln[:200]))
    return plain

targets = [
    ('probe/gaosan_ct.html','r3dump_gaosan_ct.txt'),
    ('tt/tt1.html','r3dump_tt1.txt'),
    ('tt/tt2.html','r3dump_tt2.txt'),
    ('pages/weixin_2.html','r3dump_weixin2.txt'),
    ('r3c_95ca4017.html','r3dump_r3c.txt'),
    ('r3e_wx_sogou.html','r3dump_wx_sogou.txt'),
    ('r3e_toutiao_so.html','r3dump_toutiao_so.txt'),
    ('r3e_yandex.html','r3dump_yandex.txt'),
    ('gaosan_1125274.html','r3dump_gaosan_1125274.txt'),
    ('gaosan_1125350.html','r3dump_gaosan_1125350.txt'),
]
for rel, out in targets:
    dump_file(rel, out)
print('\nDONE dump')
