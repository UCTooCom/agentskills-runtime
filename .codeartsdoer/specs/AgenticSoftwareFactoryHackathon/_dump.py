import io, sys, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
BASE = r'D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\.codeartsdoer\specs\AgenticSoftwareFactoryHackathon'
files = sys.argv[1:]
for f in files:
    p = os.path.join(BASE, f)
    if not os.path.exists(p):
        print('=== MISSING: %s ===' % f); continue
    txt = open(p, encoding='utf-8', errors='replace').read()
    print('===== FILE: %s (chars=%d) =====' % (f, len(txt)))
    print(txt)
    print('===== END: %s =====' % f)
