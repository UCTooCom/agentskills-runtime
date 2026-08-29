# -*- coding: utf-8 -*-
"""临时脚本：用 zipfile+xml 解析 xlsx，输出全部单元格文本（不依赖 openpyxl）。"""
import sys, zipfile, re
import xml.etree.ElementTree as ET

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"

def main(path):
    z = zipfile.ZipFile(path)
    # shared strings
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in root.findall(NS + "si"):
            texts = [t.text or "" for t in si.iter(NS + "t")]
            shared.append("".join(texts))
    # workbook sheets -> rels mapping
    out = []
    for name in sorted(z.namelist()):
        if re.match(r"xl/worksheets/sheet\d+\.xml$", name):
            root = ET.fromstring(z.read(name))
            rows = root.findall(".//" + NS + "row")
            out.append(f"===== {name} =====")
            for row in rows:
                cells = []
                for c in row.findall(NS + "c"):
                    v = c.find(NS + "v")
                    if v is None:
                        cells.append("")
                        continue
                    val = v.text or ""
                    t = c.get("t")
                    if t == "s":
                        val = shared[int(val)] if int(val) < len(shared) else val
                    cells.append(val)
                line = " | ".join(cells).rstrip()
                if line.strip(" |"):
                    out.append(line)
    sys.stdout.reconfigure(encoding="utf-8")
    print("\n".join(out))

if __name__ == "__main__":
    main(sys.argv[1])