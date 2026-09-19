# -*- coding: utf-8 -*-
import os, io, json, shutil
mods = []
for m in ("pytesseract", "PIL", "paddleocr", "cnocr", "easyocr", "cv2", "numpy"):
    try:
        __import__(m)
        mods.append(m)
    except Exception:
        pass
print("OCR_MODS|" + json.dumps(mods))
print("TESSERACT_BIN|" + json.dumps(shutil.which("tesseract")))
print("TESSDATA|" + json.dumps(os.environ.get("TESSDATA_PREFIX", "")))
BASE = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(BASE, "t1", "img")
if os.path.isdir(IMG):
    for fn in sorted(os.listdir(IMG)):
        p = os.path.join(IMG, fn)
        print("IMG|%s|%d" % (fn, os.path.getsize(p)))
