# -*- coding: utf-8 -*-
import os, sys, io, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\skills\long-running-task\output\rounds\7e3b3121-4fa2-44b6-9938-8bd8afeb0c02"
IMG = os.path.join(OUT, "img")
PROC = os.path.join(OUT, "proc")
os.makedirs(PROC, exist_ok=True)

report = {"pil": None, "outputs": []}
try:
    from PIL import Image
    report["pil"] = Image.__version__
    print("PIL", Image.__version__)
    for name in ["yn_stem.jpg", "yn_ans.jpg", "hjlm_stem.jpg"]:
        p = os.path.join(IMG, name)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        w, h = im.size
        print(name, "size=", im.size)
        # tiny test png
        tiny = im.resize((320, int(320 * h / w)), Image.LANCZOS)
        tp = os.path.join(PROC, name.replace('.jpg', '_tiny.png'))
        tiny.save(tp)
        report["outputs"].append({"file": tp, "kind": "tiny", "size": tiny.size})
        # 4 vertical slices, downscaled to width 1400 for readability
        n = 4
        for i in range(n):
            top = int(h * i / n)
            bot = int(h * (i + 1) / n)
            seg = im.crop((0, top, w, bot))
            sw = 1400.0
            nh = int(seg.size[1] * sw / seg.size[0])
            seg = seg.resize((int(sw), nh), Image.LANCZOS)
            sp = os.path.join(PROC, name.replace('.jpg', '') + '_s%d.png' % (i + 1))
            seg.save(sp)
            report["outputs"].append({"file": sp, "kind": "slice", "part": i + 1, "size": seg.size, "bytes": os.path.getsize(sp)})
except Exception as e:
    report["pil_error"] = repr(e)[:300]
    print("PIL ERROR:", repr(e)[:300])

json.dump(report, open(os.path.join(OUT, "_img_process.json"), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
for o in report["outputs"]:
    print(json.dumps(o, ensure_ascii=False))
