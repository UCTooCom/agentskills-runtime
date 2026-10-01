# -*- coding: utf-8 -*-
import sys, io, json, re, os, html
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "raw")
fn = os.path.join(base, "bing_q0.html")
with open(fn, 'r', encoding='utf-8') as f:
    txt = f.read()

def clean(s):
    return html.unescape(re.sub('<[^>]+>', ' ', s)).strip()

# find all class b_algo blocks
blocks = re.findall(r'<li class="b_algo".*?</li>', txt, re.S)
print("b_algo blocks:", len(blocks))
for b in blocks[:12]:
    m = re.search(r'<h2[^>]*>(.*?)</h2>', b, re.S)
    title = clean(m.group(1)) if m else ""
    hm = re.search(r'href="(https?://[^"]+)"', b)
    link = hm.group(1) if hm else ""
    print("-", title, "|", link)

print("==== all external hrefs sample ====")
hrefs = re.findall(r'href="(https?://[^"]+)"', txt)
seen = []
for h in hrefs:
    if 'bing.com' in h or 'microsoft' in h or 'msn.com' in h:
        continue
    if h not in seen:
        seen.append(h)
print("unique external:", len(seen))
for h in seen[:40]:
    print("  ", h)

print("==== contains keywords? ====")
for kw in ["物理", "高考", "压轴", "试题", "答案"]:
    print(kw, txt.count(kw))
