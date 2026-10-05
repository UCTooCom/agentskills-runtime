import re, io, os
src = r'D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/design.md'
outdir = r'D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/_ddl2'
os.makedirs(outdir, exist_ok=True)
s = io.open(src, encoding='utf-8').read()
blocks = re.findall(r'```(?:sql)?\s*\n(.*?)```', s, re.S)
for i, b in enumerate(blocks):
    txt = b.strip()
    if not txt:
        continue
    fn = os.path.join(outdir, 'block_%02d.sql' % i)
    io.open(fn, 'w', encoding='utf-8').write(txt + '\n')
print('BLOCKS:', len(blocks))
