# -*- coding: utf-8 -*-
"""从《北辰产业云社区命题 PPT.pdf》第3页提取 74 条政策目录，
生成 knowledge 种子数据 policy-seed.json。

表格为双栏布局：左表序号 1-36，右表序号 37-74。
合并单元格（所属领域/政策层级/发布部门）为空时按上一行前向填充。
PDF 提取文本含康熙部首异体字（如 ⼈ U+2F08），需规范化为标准汉字。
"""
import json
import unicodedata
import pdfplumber

PDF = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\SheNicest2026\图片和附件\北辰产业云社区命题 PPT.pdf"
OUT = r"D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\.codeartsdoer\specs\shenicestHackathon\beichen-policy-assistant\policy-seed.json"


# CJK Radicals Supplement（U+2E80-U+2EFF）无 NFKC 分解，需手动映射为标准汉字
RADICAL_MAP = {
    "⻅": "见", "⻆": "角", "⻉": "贝", "⻋": "车", "⻓": "长", "⻔": "门",
    "⻘": "青", "⻛": "风", "⻜": "飞", "⻝": "食", "⻢": "马", "⻥": "鱼",
    "⻦": "鸟", "⻧": "卤", "⻨": "麦", "⻩": "黄", "⻪": "黾", "⻫": "齐",
    "⻬": "齐", "⻭": "齿", "⻮": "齿", "⻯": "竜", "⻰": "龙", "⻱": "龟",
    "⻲": "龟", "⾦": "金", "⻱": "龟", "⽅": "方", "⻌": "辶", "⻍": "辶",
    "⻎": "辶", "⻏": "阝", "⻖": "阝", "⻗": "雨", "⻘": "青", "⾦": "金",
}


def norm(s: str) -> str:
    """规范化：康熙部首(U+2E80-U+2FDF)转标准汉字，去除空白。"""
    if not s:
        return ""
    out = []
    for ch in s:
        if ch in RADICAL_MAP:
            out.append(RADICAL_MAP[ch])
        elif 0x2E80 <= ord(ch) <= 0x2FDF:  # Kangxi Radicals 等，NFKC 可分解
            out.append(unicodedata.normalize("NFKC", ch))
        else:
            out.append(ch)
    return "".join(out).strip()


def clean_cell(c):
    if c is None:
        return ""
    return norm(c.replace("\n", "").replace(" ", ""))


# 1. 提取两栏表格
with pdfplumber.open(PDF) as pdf:
    page = pdf.pages[2]
    tables = page.extract_tables()

rows = []
for tb in tables:
    for r in tb:
        cells = [clean_cell(c) for c in r]
        # 只保留序号列是纯数字的数据行
        if cells and cells[0].isdigit():
            rows.append(cells)

rows.sort(key=lambda r: int(r[0]))

# 2. 前向填充合并单元格（领域/层级/部门）
policies = []
cur_domain = cur_level = cur_dept = ""
special_notes = []
for cells in rows:
    seq, domain, level, dept, title = (cells + [""] * 5)[:5]
    if not title:
        continue
    if domain:
        cur_domain = domain
    else:
        domain = cur_domain
    if level:
        cur_level = level
    else:
        level = cur_level
    if dept:
        cur_dept = dept
    else:
        dept = cur_dept
    note = None
    # 特判：第 74 条领域在原表中留空（前一行为"商务中心"区级政策，
    # 但本条为市级经信局 AI 政策，按政策名称推断领域）
    if seq == "74":
        domain = "人工智能"
        note = "所属领域原表留空，按政策名称推断为人工智能"
        special_notes.append(
            "policy_no 74《支持人工智能OPC创新发展行动方案（试行）》所属领域原表留空，"
            "不沿用上一行商务中心，按政策名称推断为人工智能（市级，北京市经信局）。"
        )
    entry = {
        "policy_no": seq,
        "domain": domain,
        "level": level,
        "department": dept,
        "title": title,
    }
    if note:
        entry["note"] = note
    policies.append(entry)

# 3. 校验
assert len(policies) == 74, f"政策数量应为74，实际 {len(policies)}"
nos = [int(p["policy_no"]) for p in policies]
assert nos == list(range(1, 75)), "序号必须为 1-74 连续"
domains = {}
for p in policies:
    domains.setdefault(p["domain"], []).append(p["policy_no"])

data = {
    "meta": {
        "title": "北辰产业云社区命题 · 市/区两级产业政策库种子数据（74 条）",
        "source": "《北辰产业云社区命题 PPT.pdf》第 3 页「一、政策赋能精准化 → 1、政策库」目录",
        "version": "1.0",
        "generated": "2026-08-29",
        "total": len(policies),
        "domains": {d: len(v) for d, v in domains.items()},
        "level_stat": {
            "市级": sum(1 for p in policies if p["level"] == "市级"),
            "区级": sum(1 for p in policies if p["level"] == "区级"),
        },
        "field_desc": {
            "policy_no": "命题附件政策序号（1-74），知识库条目与匹配结论溯源绑定键",
            "domain": "所属领域（人才支持/知识产权/融资服务/人工智能/智能机器人/数据要素/数字医疗/互联网3.0/高新技术产业/商务经济/金融业/文化产业/中小企业/外商投资/青年科技人才/商务中心/人工智能）",
            "level": "政策层级（市级/区级）",
            "department": "发布部门（合并单元格空值已按上一行前向填充）",
            "title": "政策名称",
        },
        "notes": [
            "所属领域/政策层级/发布部门为原表合并单元格延续的行，已按上一非空行前向填充。",
            "政策原文、申报条件、支持方式、原文链接为待补字段，由 init_policy_kb.py 生成条目骨架后人工/抓取补充。",
        ] + special_notes,
    },
    "policies": policies,
}

with open(OUT, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("saved:", OUT)
print("总条数:", len(policies))
print("领域分布:")
for d, v in domains.items():
    print(f"  {d}: {len(v)} 条")
print("层级分布:", data["meta"]["level_stat"])
