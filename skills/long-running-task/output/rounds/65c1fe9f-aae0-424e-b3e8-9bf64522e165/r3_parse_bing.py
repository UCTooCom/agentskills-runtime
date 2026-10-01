# -*- coding: utf-8 -*-
import sys, io, os, re, json, urllib.parse
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))

def strip_tags(s):
    s = re.sub(r'<[^>]+>', '', s)
    s = s.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&quot;', '"')
    s = s.replace('&#39;', "'").replace('&lt;', '<').replace('&gt;', '>')
    return re.sub(r'\s+', ' ', s).strip()

KEY = ['化学', '真题', '答案', '试题', '解析', '2025', '高考']
BAD = ['bing.com', 'microsoft', 'go.microsoft', 'privacy', 'javascript:', 'baidu.com/link']

def parse(path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        html = f.read()
    items = []
    # Bing result blocks: <h2><a href=...>title</a></h2>
    for m in re.finditer(r'<h2[^>]*>\s*<a[^>]+href="(http[^"]+)"[^>]*>(.*?)</a>', html, re.S | re.I):
        url, title = m.group(1), strip_tags(m.group(2))
        if any(b in url for b in BAD):
            continue
        if any(k in title for k in KEY) or any(k in url for k in ['huaxue', 'hx', 'chem']):
            items.append({'title': title, 'url': url})
    # also capture cite/domain text
    return items

all_items = []
for fn in ['r3_bing_cn.html', 'r3_bing_www.html']:
    p = os.path.join(OUT, fn)
    if not os.path.exists(p):
        continue
    its = parse(p)
    print("===== %s : %d items =====" % (fn, len(its)))
    for it in its:
        print("  * %s" % it['title'][:80])
        print("      %s" % it['url'][:180])
    all_items.extend(its)

# dedupe
seen = set()
uniq = []
for it in all_items:
    k = it['url']
    if k in seen: continue
    seen.add(k)
    uniq.append(it)

with open(os.path.join(OUT, 'r3_bing_items.json'), 'w', encoding='utf-8') as f:
    json.dump(uniq, f, ensure_ascii=False, indent=1)
print("\nTotal unique: %d -> r3_bing_items.json" % len(uniq))
