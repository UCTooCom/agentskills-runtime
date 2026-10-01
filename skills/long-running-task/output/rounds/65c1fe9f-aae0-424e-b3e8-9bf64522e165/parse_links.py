# -*- coding: utf-8 -*-
import os, re, json, html

OUT = os.path.dirname(os.path.abspath(__file__))

def load(name):
    p = os.path.join(OUT, name)
    if not os.path.exists(p):
        return ''
    with open(p, encoding='utf-8') as f:
        return f.read()

KEY = ['化学', '试题', '答案', '真题', '解析', '2025']

def extract(txt, base=''):
    res = []
    # 抓取 a 标签
    for m in re.finditer(r'<a\b([^>]*)>(.*?)</a>', txt, re.S | re.I):
        attrs, inner = m.group(1), m.group(2)
        hm = re.search(r'href="([^"]+)"', attrs)
        if not hm:
            continue
        href = html.unescape(hm.group(1))
        title = re.sub(r'<[^>]+>', ' ', inner)
        title = html.unescape(re.sub(r'\s+', ' ', title)).strip()
        # 也可从 title 属性取
        tm = re.search(r'title="([^"]+)"', attrs)
        if tm:
            t2 = html.unescape(tm.group(1)).strip()
            if len(t2) > len(title):
                title = t2
        if len(title) < 6:
            continue
        score = sum(1 for k in KEY if k in title)
        if score == 0:
            continue
        res.append((score, title[:160], href))
    res.sort(key=lambda x: -x[0])
    seen, out = set(), []
    for s, t, h in res:
        if h in seen:
            continue
        seen.add(h)
        out.append({'score': s, 'title': t, 'href': h})
    return out[:40]

if __name__ == '__main__':
    report = {}
    for f in ['toutiao.html', 'sogou.html', 'so.html']:
        txt = load(f)
        report[f] = extract(txt)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    with open(os.path.join(OUT, 'links.json'), 'w', encoding='utf-8') as fp:
        json.dump(report, fp, ensure_ascii=False, indent=2)
