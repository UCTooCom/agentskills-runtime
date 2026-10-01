# -*- coding: utf-8 -*-
import sys, io, json, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
try:
    import requests
except Exception as e:
    print('NO_REQUESTS', e); sys.exit(0)

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}

sources = [
    ('baidu', 'https://www.baidu.com/s?wd=2025%E5%B9%B4%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6%E6%96%B0%E8%AF%BE%E6%A0%87%E5%8D%B7%E7%9C%9F%E9%A2%98%E5%8F%8A%E7%AD%94%E6%A1%88'),
    ('baidu2', 'https://www.baidu.com/s?wd=2025%E5%B9%B4%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6%E6%9C%80%E5%90%8E%E4%B8%80%E9%81%93%E5%A4%A7%E9%A2%98'),
    ('sogou', 'https://www.sogou.com/web?query=2025%E5%B9%B4%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6%E5%8E%8B%E8%BD%B4%E9%A2%98%E5%8F%8A%E8%A7%A3%E6%9E%90'),
    ('toutiao', 'https://so.toutiao.com/search?keyword=2025%E5%B9%B4%E9%AB%98%E8%80%83%E5%8C%96%E5%AD%A6%E6%9C%80%E5%90%8E%E4%B8%80%E9%81%93%E5%A4%A7%E9%A2%98%E8%A7%A3%E6%9E%90'),
]

out = {}
for name, url in sources:
    try:
        r = requests.get(url, headers=HEADERS, timeout=20)
        txt = r.text
        out[name] = {'status': r.status_code, 'len': len(txt), 'head': txt[:1500]}
        print('===', name, r.status_code, len(txt))
        print(txt[:800].replace('\n', ' ')[:800])
    except Exception as e:
        out[name] = {'error': str(e)}
        print('===', name, 'ERR', e)

with open('fetch_chem_results.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print('DONE')
