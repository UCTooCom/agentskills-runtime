#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
产业政策智能体 - Step 5: 结果落库（Save to DB）
企业画像 upsert 到 company 表，匹配报告写入 tasks（task_type='policy-match'），
Top N 匹配政策生成申报任务写入 tasks（task_type='policy-apply'），复用 aibuilder 呈现。

用法:
    python save_to_db.py --profile {画像json} --report {报告md} --matches {匹配json} [--sql-only]

说明:
    - company 表无 company_name 唯一约束，采用 UPDATE + INSERT WHERE NOT EXISTS 两步去重；
    - tasks 表通过子查询关联已有 company.id；
    - --sql-only 仅生成 SQL 文件（无需数据库驱动）；直连需 DATABASE_URL + psycopg2。
"""

import argparse
import json
import os
import sys
import uuid
from datetime import datetime


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_outdir():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "sql"))


def esc(s) -> str:
    return (s or "").replace("\\", "\\\\").replace("'", "''")


def build_company_upsert(profile: dict) -> str:
    name = esc(profile.get("company_name", ""))
    region = esc(profile.get("region", "北京市朝阳区"))
    desc = esc(profile.get("summary", "") or profile.get("company_name", ""))
    return "\n".join([
        "UPDATE public.company SET org_description = "
        f"'{desc}', region = '{region}', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP "
        f"WHERE company_name = '{name}' AND deleted_at IS NULL;",
        "INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) "
        f"SELECT '{name}', '{region}', '{desc}', 'beichen-enterprise', false "
        f"WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '{name}' AND deleted_at IS NULL);",
    ])


def build_task_insert(company_name: str, title: str, description: str, task_type: str, task_status: str, extra: dict) -> str:
    task_id = str(uuid.uuid4())
    tags = json.dumps(["beichen", task_type], ensure_ascii=False)
    extra_json = json.dumps(extra, ensure_ascii=False)
    return (
        "INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) "
        "SELECT "
        f"'{task_id}', '{esc(title)}', '{esc(description)}', '{task_type}', '{task_status}', 'normal', "
        "c.id, "
        f"'{esc(tags)}'::jsonb, '{esc(extra_json)}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP "
        "FROM public.company c WHERE c.company_name = "
        f"'{esc(company_name)}' AND c.deleted_at IS NULL "
        "AND NOT EXISTS ("
        "  SELECT 1 FROM public.tasks t "
        f"  WHERE t.company_id = c.id AND t.title = '{esc(title)}' AND t.deleted_at IS NULL"
        ");"
    )


def main():
    parser = argparse.ArgumentParser(description="产业政策技能结果落库")
    parser.add_argument("--profile", required=True, help="企业画像 JSON")
    parser.add_argument("--report", required=True, help="适配报告 Markdown")
    parser.add_argument("--matches", required=True, help="匹配矩阵 JSON")
    parser.add_argument("--topn", type=int, default=5, help="生成申报任务数量")
    parser.add_argument("--sql-only", action="store_true", help="仅生成 SQL 文件")
    parser.add_argument("--outdir", default=default_outdir(), help="SQL 输出目录")
    parser.add_argument("--db-url", default=os.environ.get("DATABASE_URL", ""), help="数据库连接串")
    args = parser.parse_args()

    with open(args.profile, encoding="utf-8") as f:
        profile = json.load(f)
    with open(args.report, encoding="utf-8") as f:
        report_md = f.read()
    with open(args.matches, encoding="utf-8") as f:
        matches = json.load(f)

    company_name = profile.get("company_name", "")
    profile_date = profile.get("profile_date", datetime.now().strftime("%Y-%m-%d"))
    matched = matches.get("matches", [])[:max(1, args.topn)]
    matched_count = matches.get("matched_count", len(matched))

    lines = ["-- 产业政策智能体落库 SQL", f"-- 生成时间: {datetime.now().isoformat()}", ""]
    lines.append(build_company_upsert(profile))
    lines.append("")

    lines.append(build_task_insert(
        company_name, f"政策适配报告 - {company_name}", report_md, "policy-match", "completed",
        {"profile_date": profile_date, "matched_count": matched_count, "policy_nos": [m.get("policy_no") for m in matched]}))
    lines.append("")

    apply_tasks = 0
    for m in matched:
        title = f"政策申报 - {m.get('title')}"
        desc = f"政策编号：{m.get('policy_no')}\n支持方式：{m.get('support', '待补充')}\n匹配依据：{m.get('basis')}\n申报材料以主管部门通知为准。"
        lines.append(build_task_insert(
            company_name, title, desc, "policy-apply", "pending",
            {"policy_no": m.get("policy_no"), "domain": m.get("domain"), "level": m.get("level"),
             "department": m.get("department"), "deadline": "待定"}))
        lines.append("")
        apply_tasks += 1

    os.makedirs(args.outdir, exist_ok=True)
    sql_file = os.path.join(args.outdir, f"policy_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql")
    with open(sql_file, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    result = {"success": True, "sql_file": sql_file, "company": company_name,
              "policy_match_tasks": 1, "policy_apply_tasks": apply_tasks, "db_written": False}

    if not args.sql_only and args.db_url:
        try:
            import psycopg2  # type: ignore
            conn = psycopg2.connect(args.db_url)
            cur = conn.cursor()
            for stmt in lines:
                if stmt.strip() and not stmt.startswith("--"):
                    cur.execute(stmt)
            conn.commit()
            cur.close()
            conn.close()
            result["db_written"] = True
        except ImportError:
            print("警告: 未安装 psycopg2，仅生成 SQL 文件。可用: pip install psycopg2", file=sys.stderr)
        except Exception as e:
            result["error"] = str(e)

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()