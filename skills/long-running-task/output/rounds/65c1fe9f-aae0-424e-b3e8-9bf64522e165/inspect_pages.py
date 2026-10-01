# -*- coding: utf-8 -*-
import sys, io, os, re, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def to_text(html):
    html = re.sub(r'<script[^>]*>.*?</script>', ' ', html, flags=re.S|re.I)
    html = re.sub(r'<style[^>]*>.*?</style>', ' ', html, flags=re.S|re.I)
    html = re.sub(r'<[^>]+>', ' ', html)
    html = re.sub(r'&nbsp;', ' ', html)
    html = re.sub(r'\s+', ' ', html)
    return html.strip()

for d in ['pages', 'articles']:
    if not os.path.isdir(d): continue
    for fn in sorted(os.listdir(d)):
        p = os.path.join(d, fn)
        try:
            with open(p, encoding='utf-8') as f:
                html = f.read()
        except Exception as e:
            print(fn, 'READERR', e); continue
        txt = to_text(html)
        kw = {k: txt.count(k) for k in ['化学', '高考', '压轴', '真题', '答案', '解析', '有机', '反应', 'WAF', '验证', 'captcha'] if txt.count(k) > 0}
        print('=====', fn, 'html=%d text=%d' % (len(html), len(txt)), kw)
        print(txt[:400])
        print()
print('DONE')
