# -*- coding: utf-8 -*-
import sys, io, os, re, json, time, gzip, zlib, ssl, urllib.parse
import urllib.request, urllib.error
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = os.path.dirname(os.path.abspath(__file__))
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
H = {
    "User-Agent": UA,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9",
    "Accept-Encoding": "gzip, deflate",
    "Connection": "close",
}
CTX = ssl.create_default_context(); CTX.check_hostname=False; CTX.verify_mode=ssl.CERT_NONE

def decode(resp):
    data = resp.read()
    enc = (resp.headers.get("Content-Encoding") or "").lower()
    if "gzip" in enc:
        try: data = gzip.decompress(data)
        except Exception: pass
    elif "deflate" in enc:
        try: data = zlib.decompress(data, -zlib.MAX_WBITS)
        except Exception:
            try: data = zlib.decompress(data)
            except Exception: pass
    ctype = resp.headers.get("Content-Type", "")
    m = re.search(r'charset=([\w\-]+)', ctype, re.I)
    cs = m.group(1) if m else 'utf-8'
    for cand in [cs, 'utf-8', 'gb18030', 'gbk', 'latin-1']:
        try: return data.decode(cand, errors='strict'), cand
        except Exception: continue
    return data.decode('utf-8', errors='replace'), 'utf-8(replace)'

def fetch(name, url, referer=None, timeout=25):
    h = dict(H)
    if referer: h["Referer"] = referer
    try:
        req = urllib.request.Request(url, headers=h)
        with urllib.request.urlopen(req, timeout=timeout, context=CTX) as resp:
            txt, cs = decode(resp)
            with open(os.path.join(OUT, 'r3_%s.html' % name), 'w', encoding='utf-8', errors='replace') as f:
                f.write(txt)
            print("[OK ] %-16s len=%7d cs=%s" % (name, len(txt), cs))
            return txt
    except Exception as e:
        print("[ERR] %-16s %s" % (name, repr(e)[:130]))
        return None

def strip_tags(s):
    s = re.sub(r'<[^>]+>', '', s)
    for a,b in [('&nbsp;',' '),('&amp;','&'),('&quot;','"'),('&#39;',"'"),('&lt;','<'),('&gt;','>')]:
        s = s.replace(a,b)
    return re.sub(r'\s+',' ',s).strip()

def parse_bing(html):
    items=[]
    for m in re.finditer(r'<h2[^>]*>\s*<a[^>]+href="(http[^"]+)"[^>]*>(.*?)</a>', html, re.S|re.I):
        url, title = m.group(1), strip_tags(m.group(2))
        if any(b in url for b in ['bing.com','microsoft','privacy','javascript:']): continue
        items.append({'title':title,'url':url})
    return items

queries = {
  'q_hx1': '2025年高考化学 新课标卷 试题 有机推断 答案',
  'q_hx2': '2025高考化学 压轴题 解析 工艺流程',
  'q_hx3': '2025年全国甲卷 化学 真题 最后一题',
  'q_hx4': '2025高考化学试题 18题 有机化学基础',
}
allitems = {}
for key, q in queries.items():
    u = 'https://cn.bing.com/search?q=%s&count=30' % urllib.parse.quote(q)
    t = fetch(key, u)
    if t:
        its = parse_bing(t)
        allitems[key] = {'query':q, 'items':its}
        print("   %s -> %d items" % (key, len(its)))
        for it in its[:15]:
            print("     * %s" % it['title'][:70])
            print("        %s" % it['url'][:160])
    time.sleep(1.0)

with open(os.path.join(OUT,'r3_search2.json'),'w',encoding='utf-8') as f:
    json.dump(allitems, f, ensure_ascii=False, indent=1)
print('saved r3_search2.json')
