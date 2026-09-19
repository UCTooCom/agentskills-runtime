# -*- coding: utf-8 -*-
import os

p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                 'output', 'reports', 'policy-summary-2026-09-11.md')
d = open(p, encoding='utf-8').read()
lines = d.splitlines()
print('exists=%s' % os.path.exists(p))
print('bytes=%d' % len(d.encode('utf-8')))
print('lines=%d' % len(lines))
print('h2_sections=%d' % sum(1 for l in lines if l.startswith('## ')))
print('table_rows=%d' % sum(1 for l in lines if l.startswith('| ')))
print('has_row_74=%s' % any(l.startswith('| 74 |') for l in lines))
print('has_row_1=%s' % any(l.startswith('| 1 |') for l in lines))
print('has_disclaimer=%s' % any('不构成法律意见' in l for l in lines))
print('has_pending_section=%s' % any('最新政策动态' in l for l in lines))
