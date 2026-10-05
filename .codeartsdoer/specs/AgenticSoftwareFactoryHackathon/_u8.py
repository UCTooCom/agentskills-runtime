import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

argv = sys.argv[1:]
head = None
grep = None
paths = []
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--head":
        i += 1
        head = int(argv[i])
    elif a == "--grep":
        i += 1
        grep = argv[i]
    else:
        paths.append(a)
    i += 1

for p in paths:
    if not os.path.exists(p):
        print("=== MISSING: %s ===" % p)
        continue
    if os.path.isdir(p):
        for root, dirs, files in os.walk(p):
            dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "target", ".venv", "dist")]
            for f in sorted(files):
                fp = os.path.join(root, f)
                try:
                    size = os.path.getsize(fp)
                except OSError:
                    size = -1
                print("%10d  %s" % (size, fp))
        continue
    text = io.open(p, encoding="utf-8", errors="replace").read()
    lines = text.splitlines()
    if grep is not None:
        hits = [(idx + 1, ln) for idx, ln in enumerate(lines) if grep.lower() in ln.lower()]
        print("===== GREP %s -> %d hits in %s (lines=%d) =====" % (grep, len(hits), p, len(lines)))
        for idx, ln in hits:
            print("%6d | %s" % (idx, ln))
        print("===== END GREP %s =====" % p)
        continue
    printed = lines if head is None else lines[:head]
    print("===== FILE: %s (chars=%d, lines=%d) =====" % (p, len(text), len(lines)))
    for idx, ln in enumerate(printed):
        print("%s" % ln)
    if head is not None and len(lines) > head:
        print("... [%d more lines]" % (len(lines) - head))
    print("===== END: %s =====" % p)
