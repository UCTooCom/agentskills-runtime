# -*- coding: utf-8 -*-
import os, sys, io, json, shutil, subprocess
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
rep = {}
for m in ['pytesseract', 'easyocr', 'paddleocr', 'cnocr', 'rapidocr_onnxruntime', 'PIL', 'cv2', 'numpy']:
    try:
        __import__(m)
        rep[m] = 'OK'
    except Exception as e:
        rep[m] = 'NO: ' + type(e).__name__
rep['tesseract_exe'] = shutil.which('tesseract')
try:
    r = subprocess.run(['tesseract', '--version'], capture_output=True, text=True, timeout=20)
    rep['tesseract_ver'] = (r.stdout or r.stderr)[:120]
except Exception as e:
    rep['tesseract_ver'] = 'ERR ' + repr(e)[:120]
print(json.dumps(rep, ensure_ascii=False, indent=2))
