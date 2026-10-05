import re, io, os, sys
src = r'D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/design.md'
outdir = r'D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/_ddl'
os.makedirs(outdir, exist_ok=True)
s = io.open(src, encoding='utf-8').read()
blocks = re.findall(r'```(?:sql)?\s*\n(.*?)```', s, re.S)
count = 0
for i, b in enumerate(blocks):
    txt = b.strip()
    if not txt:
        continue
    creates = re.findall(r'CREATE TABLE (?:IF NOT EXISTS )?(\w+)', txt, re.I)
    for c in creates:
        m = re.search(r'CREATE TABLE (?:IF NOT EXISTS )?' + re.escape(c) + r'\s*\((.*?)\)\s*;', txt, re.I | re.S)
        if m:
            fn = os.path.join(outdir, c + '.sql')
            io.open(fn, 'w', encoding='utf-8').write('CREATE TABLE ' + c + ' (\n' + m.group(1).strip() + '\n);\n')
            count += 1
            print('EXTRACTED:', c)
print('TOTAL:', count)
