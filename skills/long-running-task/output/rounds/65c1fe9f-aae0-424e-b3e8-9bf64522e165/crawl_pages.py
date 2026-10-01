# -*- coding: utf-8 -*-
import os, re, json, ssl, html
import urllib.request, urllib.parse

OUT = os.path.dirname(os.path.abspath(__file__))
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
HDRS = {
 'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
 'Accept-Language':'zh-CN,zh;q=0.9',
 'Accept':'text/html,application/xhtml+xml,*/*;q=0.8',
}

def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers=HDRS)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        raw = r.read()
        enc = r.headers.get_content_charset() or 'utf-8'
        try: return r.status, r.geturl(), raw.decode(enc,'ignore')
        except: return r.status, r.geturl(), raw.decode('utf-8','ignore')

def text_of(t):
    t = re.sub(r'(?is)<script.*?</script>',' ',t)
    t = re.sub(r'(?is)<style.*?</style>',' ',t)
    t = re.sub(r'(?is)<[^>]+>',' ',t)
    t = html.unescape(t)
    t = re.sub(r'[ \t\r\f\v]+',' ',t)
    t = re.sub(r'\n\s*\n+','\n',t)
    return t.strip()

CAND = [
 ('gaosan_home','https://www.gaosan.com/'),
 ('gaokao_cn','https://www.gaokao.cn/'),
 ('zxxk','https://www.zxxk.com/'),
 ('21cnjy','https://www.21cnjy.com/'),
 ('eol','https://www.eol.cn/e_html/gk/'),
]

if __name__ == '__main__':
    rep = {}
    for name,url in CAND:
        try:
            st,fin,txt = fetch(url)
            print('===',name,st,fin,len(txt))
            with open(os.path.join(OUT,name+'.html'),'w',encoding='utf-8') as f: f.write(txt)
            rep[name]={'status':st,'final':fin,'len':len(txt),'head':text_of(txt)[:600]}
        except Exception as e:
            print('===',name,'ERR',repr(e))
            rep[name]='ERR: %r'%(e,)
    with open(os.path.join(OUT,'crawl_report.json'),'w',encoding='utf-8') as f:
        json.dump(rep,f,ensure_ascii=False,indent=2)
    print(json.dumps({k:(v if isinstance(v,str) else v.get('head','')) for k,v in rep.items()},ensure_ascii=False,indent=2)[:3000])
