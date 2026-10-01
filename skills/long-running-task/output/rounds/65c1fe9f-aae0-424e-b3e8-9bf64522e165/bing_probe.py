# -*- coding: utf-8 -*-
import os, re, ssl, html, json
import urllib.request, urllib.parse

OUT = os.path.dirname(os.path.abspath(__file__))
ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
HDRS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
}


def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers=HDRS)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        raw = r.read(); enc = r.headers.get_content_charset() or 'utf-8'
        try:
            return r.status, raw.decode(enc, 'ignore')
        except Exception:
            return r.status, raw.decode('utf-8', 'ignore')


q = '2025年高考化学真题及答案全国卷'
url = 'https://cn.bing.com/search?q=' + urllib.parse.quote(q) + poo
