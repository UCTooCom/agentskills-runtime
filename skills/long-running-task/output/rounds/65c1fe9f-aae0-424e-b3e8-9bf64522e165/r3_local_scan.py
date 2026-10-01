# -*- coding: utf-8 -*-
import sys, io, os, re, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))
CHEM = ['化学','有机','mol','摩尔','溶液','反应','合成','催化剂','酯化','水解','方程式','氧化','还原','电极','离子','摩尔质量','同分异构']

def strip_tags(s):
    s = re.sub(r'<script[\s\S]*?</script>','',s,flags=re.I)
    s = re.sub(r'<style[\s\S]*?</style>','',s,flags=re.I)
    s = re.sub(r'<!--[\s\S]*?-->','',s)
    s = re.sub(r'<[^>]+>','\n',s)
    for a,b in [('&nbsp;',' '),('&amp;','&'),('&quot;','"'),('&#39;',"'"),('&lt;','<'),('&gt;','>')]:
        s = s.replace(a,b)
    s = re.sub(r'[ \t\xa0]+',' ',s)
    s = re.sub(r'\n{2,}','\n',s)
    return s.strip()

files = []
for root, dirs, fs in os.walk(OUT):
    for f in fs:
        if f.endswith('.html'):
            files.append(os.path.join(root, f))
print('scanning %d html files' % len(files))

report = {}
for p in files:
    try:
        sz = os.path.getsize(p)
        if sz < 3000:
            continue
        with open(p, 'r', encoding='utf-8', errors='replace') as f:
            html = f.read()
        plain = strip_tags(html)
        # split into paragraphs
        paras = [x.strip() for x in plain.split('\n') if len(x.strip()) > 15]
        scored = []
        for para in paras:
            sc = sum(1 for kw in CHEM if kw in para)
            # question-like markers
            if re.match(r'^\s*\d{1,2}[\.、．]', para):
                sc += 2
            if ('\(1\)' in para or '（1）' in para) and ('\(2\)' in para or '（2）' in para):
                sc += 2
            if sc >= 3:
                scored.append((sc, para))
        scored.sort(key=lambda x: -x[0])
        tot_chem = sum(1 for kw in CHEM if kw in plain)
        report[os.path.relpath(p, OUT)] = {
            'size': sz, 'plain_len': len(plain), 'chem_kinds': tot_chem,
            'top': [{'score': s, 'text': t[:300]} for s, t in scored[:8]],
        }
        if scored:
            print('\n##### %s  size=%d chem=%d paras=%d' % (os.path.relpath(p,OUT), sz, tot_chem, len(scored)))
            for s, t in scored[:3]:
                print('   [%d] %s' % (s, t[:150].replace('\n',' ')))
    except Exception as e:
        report.setdefault('errors', []).append('%s: %s' % (p, repr(e)[:80]))

with open(os.path.join(OUT, 'r3_local_scan.json'), 'w', encoding='utf-8') as f:
    json.dump(report, f, ensure_ascii=False, indent=1)
print('\nsaved r3_local_scan.json ; files with chem paras: %d' % sum(1 for v in report.values() if isinstance(v, dict) and v.get('top')))
