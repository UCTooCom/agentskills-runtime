# -*- coding: utf-8 -*-
import os, re, json, html, ssl
import urllib.request, urllib.parse

OUT = os.path.dirname(os.path.abspath(__file__))


def load_urls():
    p = os.path.join(OUT, 'urls.txt')
    if not os.path.exists(p):
        return []
    return [l.strip() for l in open(p, encoding='utf-8') if l.strip()]


if __name__ == '__main__':
    us = load_urls()
    print('TOTAL', len(us))
    gaosan = [u for u in us if 'gaosan.com' in u]
    jy = [u for u in us if '21cnjy' in u or 'zxxk' in u]
    jump = [u for u in us if '/search/jump' in u or 'toutiaoapi' in u]
    print('=== gaosan (%d) ===' % len(gaosan))
    print(json.dumps(sorted(set(gaosan))[:60], ensure_ascii=False, indent=2))
    print('=== jy/zxxk (%d) ===' % len(jy))
    print(json.dumps(sorted(set(jy))[:40], ensure_ascii=False, indent=2))
    print('=== jump (%d) ===' % len(jump))
    print(json.dumps(sorted(set(jump))[:5], ensure_ascii=False, indent=2)[:1500])
