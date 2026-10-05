import io, sys, os, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
BASE = r'D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\.codeartsdoer\specs\AgenticSoftwareFactoryHackathon'

# 1) sizes of the SDD docs already present
for f in ['hackathon-info.md', 'spec.md', 'design.md', 'tasks.md']:
    p = os.path.join(BASE, f)
    if os.path.exists(p):
        t = open(p, encoding='utf-8', errors='replace').read()
        print('%-22s chars=%-8d lines=%d' % (f, len(t), t.count(chr(10)) + 1))
    else:
        print('%-22s MISSING' % f)

# 2) compact requirement tree for both competition tasks
for name in ['hackathon--github', 'hackathon--sheet']:
    p = os.path.join(BASE, 'arcbench-hackathon-requirements', name, 'requirements.yaml')
    lines = open(p, encoding='utf-8', errors='replace').read().splitlines()
    print('')
    print('=' * 78)
    print('REQ TREE: %s   (lines=%d)' % (name, len(lines)))
    print('=' * 78)
    for i, l in enumerate(lines, 1):
        s = l.strip()
        if re.match(r'^(- )?(id|name|type|dependencies|priority|module):\s', s):
            print('%5d|%s' % (i, s))
