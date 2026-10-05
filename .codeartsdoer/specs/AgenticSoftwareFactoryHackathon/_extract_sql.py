import re, io, sys
p = r'D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/design.md'
s = io.open(p, encoding='utf-8').read()
blocks = re.findall(r'```(?:sql)?\s*\n(.*?)```', s, re.S)
out = io.open(r'D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/_extracted_sql.txt', 'w', encoding='utf-8')
out.write('TOTAL BLOCKS: %d\n' % len(blocks))
for i, b in enumerate(blocks):
    out.write('\n===== BLOCK %d =====\n%s\n' % (i, b.strip()))
out.close()
print('TOTAL BLOCKS:', len(blocks))
for i, b in enumerate(blocks):
    print('----- BLOCK %d (%d chars) -----' % (i, len(b.strip())))
    print(b.strip()[:1200])
