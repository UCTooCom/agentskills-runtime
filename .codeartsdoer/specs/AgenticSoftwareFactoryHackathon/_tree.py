import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SKIP = {".git", "node_modules", "target", ".venv", "dist", ".codeartsdoer", "build",
        ".idea", "__pycache__", ".cache", "coverage", ".next"}

root = sys.argv[1]
maxdepth = int(sys.argv[2]) if len(sys.argv) > 2 else 3
skip_extra = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else []
skip = SKIP | set(skip_extra)

root = os.path.abspath(root)
base_depth = root.rstrip(os.sep).count(os.sep)

print("===== TREE %s (depth<=%d) =====" % (root, maxdepth))
for cur, dirs, files in os.walk(root):
    dirs[:] = sorted(d for d in dirs if d not in skip)
    depth = cur.rstrip(os.sep).count(os.sep) - base_depth
    if depth >= maxdepth:
        dirs[:] = []
    rel = os.path.relpath(cur, root)
    indent = "  " * depth
    if depth == 0:
        print("%s./" % indent)
    else:
        print("%s%s/" % (indent, os.path.basename(cur)))
    if depth >= maxdepth:
        continue
    for f in sorted(files):
        if f.endswith((".map",)):
            continue
        fp = os.path.join(cur, f)
        try:
            size = os.path.getsize(fp)
        except OSError:
            size = -1
        print("%s  %s  (%d)" % (indent, f, size))
print("===== END TREE =====")
