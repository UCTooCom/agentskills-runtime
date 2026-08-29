#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
产业政策智能体 - Step 0: 三层知识库初始化（Init Policy KB）
以命题附件政策目录种子（policy-seed.json）为输入，生成：
  1) 政策原文库条目 knowledge/policy-original/{policy_no}-{title}.md（front-matter + 要点区）
  2) 政策索引 knowledge/policy-index.json（供匹配脚本硬性条件初筛）

用法:
    python init_policy_kb.py --seed knowledge/policy-seed.json [--kb knowledge] [--force]
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_kb():
    return os.path.normpath(os.path.join(script_dir(), "..", "knowledge"))


def sanitize_filename(s: str) -> str:
    """清洗文件名，保留中英文数字与连字符，去除非法字符。"""
    if not s:
        return "policy"
    s = re.sub(r'[\s\u3000]+', '', s)
    s = re.sub(r'[\\/:*?"<>|]', '', s)
    return s or "policy"


def load_seed(seed_path: str) -> list:
    with open(seed_path, encoding="utf-8") as f:
        data = json.load(f)
    policies = data.get("policies", [])
    if not policies:
        print("错误: 种子文件无 policies 数据", file=sys.stderr)
        sys.exit(1)
    return policies


def render_markdown(p: dict) -> str:
    """生成政策原文库条目 Markdown（front-matter + 要点区）。"""
    cond = p.get("conditions") or {}
    region = cond.get("region", "")
    qualification = cond.get("qualification", "")
    industry = cond.get("industry", [])
    lines = [
        "---",
        f'policy_no: "{p.get("policy_no", "")}"',
        f'domain: {p.get("domain", "")}',
        f'level: {p.get("level", "")}',
        f'department: {p.get("department", "")}',
        f'title: {p.get("title", "")}',
        f'status: {p.get("status", "active")}',
        "conditions:",
    ]
    if region:
        lines.append(f"  region: {region}")
    if qualification:
        lines.append(f"  qualification: {qualification}")
    lines.append(f"  industry: {json.dumps(industry, ensure_ascii=False)}")
    lines += [
        f'support: "{p.get("support", "")}"',
        f'source: {p.get("source", "")}',
        "---",
        "",
        f'# {p.get("title", "")}',
        "",
        "## 政策要点",
        "",
        "（申报条件、支持方式、申报周期、材料清单——待运营方依据政策原文补全；匹配时以 front-matter 条件为准）",
        "",
        f"- 所属领域：{p.get('domain', '')}",
        f"- 政策层级：{p.get('level', '')}",
        f"- 发布部门：{p.get('department', '')}",
        f"- 申报条件（区域）：{region or '待补充'}",
        f"- 资质要求：{qualification or '待补充'}",
        f"- 支持方式：{p.get('support', '待补充')}",
        "",
    ]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="初始化产业政策三层知识库")
    parser.add_argument("--seed", required=True, help="政策种子 JSON 文件")
    parser.add_argument("--kb", default=default_kb(), help="知识库根目录（默认 knowledge/）")
    parser.add_argument("--force", action="store_true", help="覆盖已存在条目")
    args = parser.parse_args()

    orig_dir = os.path.join(args.kb, "policy-original")
    os.makedirs(orig_dir, exist_ok=True)
    for sub in ("policy-interpretation", "policy-insight"):
        os.makedirs(os.path.join(args.kb, sub), exist_ok=True)

    policies = load_seed(args.seed)
    index = {"version": "1.0.0", "generated_at": datetime.now().isoformat(),
             "count": len(policies), "policies": []}
    created = skipped = 0
    for p in policies:
        no = str(p.get("policy_no", "")).strip()
        title = p.get("title", "")
        fname = f"{no}-{sanitize_filename(title)}.md"
        fpath = os.path.join(orig_dir, fname)
        if os.path.exists(fpath) and not args.force:
            skipped += 1
        else:
            with open(fpath, "w", encoding="utf-8") as f:
                f.write(render_markdown(p))
            created += 1
        index["policies"].append({
            "policy_no": no,
            "domain": p.get("domain", ""),
            "level": p.get("level", ""),
            "department": p.get("department", ""),
            "title": title,
            "status": p.get("status", "active"),
            "conditions": p.get("conditions", {}),
            "support": p.get("support", ""),
            "file": os.path.join("policy-original", fname),
        })

    index_path = os.path.join(args.kb, "policy-index.json")
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    print(json.dumps({
        "success": True,
        "index": index_path,
        "count": len(policies),
        "created": created,
        "skipped": skipped,
        "output": index_path,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()