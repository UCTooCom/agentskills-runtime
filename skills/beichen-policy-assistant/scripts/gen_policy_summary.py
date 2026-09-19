# -*- coding: utf-8 -*-
"""Generate aggregate policy summary report for beichen-policy-assistant.

Reads knowledge/policy-index.json and output/pending/<today>.json,
writes output/reports/policy-summary-<date>.md (UTF-8),
and prints ASCII-only stats to stdout (encoding-safe).
"""
import json
import os
import sys
import datetime
import collections

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_json(path):
    with open(path, 'r', encoding='utf-8-sig') as f:
        return json.load(f)


def find_records(obj):
    """Return (key, list) for the first list-of-dict value in obj."""
    if isinstance(obj, list):
        return 'items', obj
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, list) and v and isinstance(v[0], dict):
                return k, v
        for k, v in obj.items():
            if isinstance(v, list):
                return k, v
    return None, []


def g(d, *keys, default=''):
    for k in keys:
        if isinstance(d, dict) and d.get(k):
            return d.get(k)
    return default


def counter_table(counter, label):
    lines = ['| ' + label + ' | 政策数量 |', '|------|------|']
    for name, cnt in sorted(counter.items(), key=lambda x: (-x[1], str(x[0]))):
        lines.append('| %s | %d |' % (name, cnt))
    return '\n'.join(lines)


def main():
    today = datetime.date.today().isoformat()
    idx_path = os.path.join(BASE, 'knowledge', 'policy-index.json')
    out_dir = os.path.join(BASE, 'output', 'reports')
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, 'policy-summary-%s.md' % today)

    idx = load_json(idx_path)
    key, policies = find_records(idx)

    domains = collections.Counter()
    levels = collections.Counter()
    depts = collections.Counter()
    statuses = collections.Counter()
    no_conditions = 0
    rows = []
    for p in policies:
        domain = str(g(p, 'domain', default='未分类'))
        level = str(g(p, 'level', default='未标注'))
        dept = str(g(p, 'department', default='未标注'))
        title = str(g(p, 'title', default='(无标题)'))
        no = str(g(p, 'policy_no', default=''))
        st = str(g(p, 'status', default='active'))
        f = str(g(p, 'file', default=''))
        domains[domain] += 1
        levels[level] += 1
        depts[dept] += 1
        statuses[st] += 1
        cond = p.get('conditions')
        if not cond:
            no_conditions += 1
        rows.append((no, domain, level, dept, title, st, f))

    def sort_key(r):
        try:
            return (0, int(r[0]))
        except Exception:
            return (1, r[0])
    rows.sort(key=sort_key)

    # pending / freshly fetched items
    pending_path = os.path.join(BASE, 'output', 'pending', '%s.json' % today)
    pending = None
    pending_items = []
    pending_meta = ''
    if os.path.exists(pending_path):
        pending = load_json(pending_path)
        _, pending_items = find_records(pending)
        pending_meta = str(g(pending, 'fetched_at', default=''))

    lines = []
    lines.append('# 北京市产业政策汇总报告')
    lines.append('')
    lines.append('**报告日期**：%s  ' % today)
    lines.append('**生成方式**：北辰产业政策智能体（beichen-policy-assistant）政策库聚合，三层知识库 + 全网实时检索  ')
    lines.append('**数据来源**：北辰命题附件政策目录（74 条）+ 北京市政府公开网站最新政策抓取  ')
    lines.append('**报告性质**：政策库汇总与动态通报，非单一企业适配研判')
    lines.append('')
    lines.append('---')
    lines.append('')
    lines.append('## 一、报告说明')
    lines.append('')
    lines.append('本报告对政策智能体的三层知识库（政策原文库 / 官方解读库 / 实操洞察库）进行全量聚合统计，')
    lines.append('并汇总最新一轮政府公开网站政策抓取结果，输出可溯源的政策全景与动态清单。')
    lines.append('所有条目均绑定 `policy_no` 编号，可回溯至 `knowledge/policy-original/` 原文文件。')
    lines.append('')
    lines.append('## 二、政策库总览')
    lines.append('')
    lines.append('- 政策原文库条目数：**%d** 条' % len(policies))
    lines.append('- 政策索引版本：%s' % str(g(idx, 'version', default='-')))
    lines.append('- 索引生成时间：%s' % str(g(idx, 'generated_at', default='-')))
    lines.append('- 状态分布：%s' % '，'.join('%s=%d' % (k, v) for k, v in statuses.items()))
    lines.append('- 待补充结构化要素（条件/支持力度）条目数：%d 条（需人工或 LLM 抽取补充）' % no_conditions)
    lines.append('- 官方解读库文件数：3 份（编号 5 / 12 / 17）')
    lines.append('- 实操洞察库文件数：3 份（中小企业 / 人工智能 / 高新技术产业）')
    lines.append('')
    lines.append('## 三、政策领域分布')
    lines.append('')
    lines.append(counter_table(domains, '政策领域'))
    lines.append('')
    lines.append('## 四、政策层级与发布部门分布')
    lines.append('')
    lines.append(counter_table(levels, '政策层级'))
    lines.append('')
    lines.append(counter_table(depts, '发布部门'))
    lines.append('')
    lines.append('## 五、政策原文库清单（按编号）')
    lines.append('')
    lines.append('| 编号 | 政策名称 | 领域 | 层级 | 状态 | 原文文件 |')
    lines.append('|------|----------|------|------|------|----------|')
    for no, domain, level, dept, title, st, f in rows:
        lines.append('| %s | %s | %s | %s | %s | `%s` |' % (no, title, domain, level, st, f))
    lines.append('')
    lines.append('## 六、最新政策动态（%s 抓取）' % today)
    lines.append('')
    if pending is None:
        lines.append('本轮未发现抓取流水文件。')
    else:
        lines.append('- 抓取时间：%s' % (pending_meta or '-'))
        lines.append('- 抓取条目数：**%d** 条' % len(pending_items))
        ok_items = [x for x in pending_items if str(g(x, 'status', default='')).lower() != 'error']
        err_items = [x for x in pending_items if str(g(x, 'status', default='')).lower() == 'error']
        lines.append('- 待研判（pending）条目数：%d 条 | 抓取失败条目数：%d 条' % (len(ok_items), len(err_items)))
        lines.append('- 入库门禁：储备库 → 正式库须经人工研判 commit（`--reviewer` 留痕）')
        lines.append('')
        lines.append('| 序号 | 标题 | 发布单位 | 发布日期 | 状态 | 链接 |')
        lines.append('|------|------|----------|----------|------|------|')
        for i, it in enumerate(pending_items, 1):
            title = str(g(it, 'title', default='(未解析)'))
            dept = str(g(it, 'department', 'source', default='(未解析)'))
            pub = str(g(it, 'published_date', default='-'))
            st = str(g(it, 'status', default='pending'))
            url = str(g(it, 'url', default='-'))
            if str(st).lower() == 'error':
                title = '(抓取失败) ' + str(g(it, 'error', default=''))
            lines.append('| %d | %s | %s | %s | %s | %s |' % (i, title, dept, pub, st, url))
    lines.append('')
    lines.append('## 七、申报要点与建议')
    lines.append('')
    lines.append('1. **领域聚焦**：政策库覆盖人才创业、知识产权、金融支持、人工智能与机器人、数据要素、')
    lines.append('   数字医疗健康、互联网 3.0/元宇宙、科技创新与高新技术、商务文化消费、中小企业与外资、')
    lines.append('   国际消费中心城市建设等方向，可按企业主营领域快速定位。')
    lines.append('2. **层级联动**：市、区两级政策并存，建议按“市级普惠 + 区级叠加”组合申报，提高支持叠加度。')
    lines.append('3. **要素补全**：原文库中条件与支持力度字段尚未结构化，正式匹配前需完成要素抽取，')
    lines.append('   否则匹配结果应标记“待核实”，不得进入正式报告。')
    lines.append('4. **时效跟踪**：储备库条目须经人工研判后转入正式库；建议每日定时抓取并定期清理超期条目。')
    lines.append('5. **企业适配**：如需针对具体企业输出可申报清单与适配研判报告，请提供企业名称，')
    lines.append('   智能体将执行“企业画像 → 政策匹配 → 适配报告 → 申报任务 → 落库”全流程。')
    lines.append('')
    lines.append('## 八、合规声明')
    lines.append('')
    lines.append('- 本报告数据仅来源于公开工商信息、政府公开网站与公开政策目录，已记录来源与抓取时间。')
    lines.append('- 储备库条目须经人工研判门禁方可转入正式库，本报告不对未确认条目作确定性结论。')
    lines.append('- 本报告仅供申报参考，不构成法律意见；最终以主管部门发布的政策原文与审批结果为准。')
    lines.append('')

    content = '\n'.join(lines)
    with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)

    # ASCII-only stdout stats
    print('OK report=%s' % out_path)
    print('bytes=%d' % len(content.encode('utf-8')))
    print('policies=%d domains=%d levels=%d depts=%d no_conditions=%d' % (
        len(policies), len(domains), len(levels), len(depts), no_conditions))
    print('pending_items=%d' % len(pending_items))
    print('domain_counts=' + ';'.join('%d' % c for _, c in sorted(domains.items(), key=lambda x: -x[1])))
    print('level_counts=' + ';'.join('%d' % c for _, c in levels.items()))


if __name__ == '__main__':
    main()
