# -*- coding: utf-8 -*-
import sys, io, os, re, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))

def links_from_html(path, base=''):
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            html = f.read()
    except Exception as e:
        return []
    out = []
    for m in re.finditer(r'<a\s[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>', html, re.S | re.I):
        url, txt = m.group(1), re.sub(r'<[^>]+>', '', m.group(2))
        txt = re.sub(r'\s+', ' ', txt).strip()
        if txt:
            out.append((url, txt))
    return out

files = sorted([f for f in os.listdir(OUT) if f.startswith('r3_') and f.endswith('.html')])
allres = {}
for fn in files:
    ls = links_from_html(os.path.join(OUT, fn))
    allres[fn] = ls
    print("\n===== %s  (%d links) =====" % (fn, len(ls)))
    for u, t in ls[:60]:
        print("  - %s | %s" % (t[:60], u[:150]))

with open(os.path.join(OUT, 'r3_links.json'), 'w', encoding='utf-8') as f:
    json.dump(allres, f, ensure_ascii=False, indent=1)
print("\nsaved r3_links.json")
