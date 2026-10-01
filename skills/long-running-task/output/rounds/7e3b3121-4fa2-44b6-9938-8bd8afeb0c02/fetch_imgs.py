# -*- coding: utf-8 -*-
import os, sys, io, json, ssl, gzip, zlib, struct
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import urllib.request

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
IMG = os.path.join(OUT, "img")
os.makedirs(IMG, exist_ok=True)
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
HDR = {"User-Agent": UA, "Accept": "image/avif,image/webp,image/*,*/*;q=0.8", "Referer": "http://gaokao.eol.cn/"}
CTX = ssl.create_default_context(); CTX.check_hostname = False; CTX.verify_mode = ssl.CERT_NONE

def png_size(b):
    return struct.unpack('>II', b[16:24]) if b[:8] == b'\x89PNG\r\n\x1a\n' else None

def jpg_size(b):
    i = 2
    while i < len(b) - 9:
        if b[i] != 0xFF:
            i += 1; continue
        m = b[i+1]
        if m in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            h, w = struct.unpack('>HH', b[i+5:i+9]); return (w, h)
        if m in (0xD8, 0xD9) or 0xD0 <= m <= 0xD7:
            i += 2; continue
        ln = struct.unpack('>H', b[i+2:i+4])[0]; i += 2 + ln
    return None

def grab(url, name):
    try:
        req = urllib.request.Request(url, headers=HDR)
        with urllib.request.urlopen(req, timeout=40, context=CTX) as r:
            raw = r.read()
        p = os.path.join(IMG, name)
        open(p, 'wb').write(raw)
        sz = None
        if raw[:2] == b'\xff\xd8': sz = jpg_size(raw)
        elif raw[:8] == b'\x89PNG\r\n\x1a\n': sz = png_size(raw)
        rec = {"ok": True, "name": name, "bytes": len(raw), "size": sz, "file": p, "url": url}
    except Exception as e:
        rec = {"ok": False, "name": name, "error": repr(e)[:200], "url": url}
    print(json.dumps(rec, ensure_ascii=False))
    return rec

urls = [
    ("yn_stem.jpg", "https://img.eol.cn/e_images/gk/2025/st/yn/wl00.jpg"),
    ("yn_ans.jpg", "https://img.eol.cn/e_images/gk/2025/st/yn/wld00.jpg"),
    ("hjlm_stem.jpg", "https://img.eol.cn/e_images/gk/2025/st/hjlm/wld00.jpg"),
]
res = [grab(u, n) for n, u in urls]
json.dump(res, open(os.path.join(OUT, "_img_probe.json"), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
try:
    from PIL import Image
    print("PIL available:", Image.__version__)
except Exception as e:
    print("PIL NOT available:", e)
