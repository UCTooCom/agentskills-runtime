import io, sys, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
BASE = r'D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\.codeartsdoer\specs\AgenticSoftwareFactoryHackathon'
n = int(sys.argv[1])
for f in sys.argv[2:]:
    p = os.path.join(BASE, f)
    if not os.path.exists(p):
        print('=== MISSING: %s ===' % f); continue
    t = open(p, encoding='utf-8', errors='replace').read()
    ls = t.splitlines()
    print('===== HEAD %s (lines=%d chars=%d) =====' % (f, len(ls), len(t)))
    print(chr(10).join(ls[:n]))
    print('===== END HEAD %s =====' % f)
