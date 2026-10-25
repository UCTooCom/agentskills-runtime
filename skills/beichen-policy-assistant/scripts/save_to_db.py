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
import re
import sys
import uuid
from datetime import datetime


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_outdir():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "sql"))


def esc(s) -> str:
    return (s or "").replace("\\", "\\\\").replace("'", "''")


# company 表必填列（线上实测：17 列 NOT NULL 且无默认值，见 uctooDB.sql 建表 +
# 后续企业认证扩展）。缺失值一律写空串表示「未采集」，**禁止编造**统一社会信用代码、
# 法人手机号等（spec §6.5 第 2 条）。
COMPANY_REQUIRED_COLS = [
    "company_name", "region", "social_credit_code", "established_time", "registered_capital",
    "registered_address", "mailing_address", "legal_representative", "legal_representativemobile",
    "legal_representative_email", "contact_name", "contact_mobile", "contact_email",
    "contact_title", "website", "company_introduction", "business_licence",
]


def clean_val(v):
    """画像中的占位值视为未采集。"""
    s = str(v if v is not None else "").strip()
    if not s or s in ("待补充", "待核实", "None", "null"):
        return ""
    return s


def build_company_values(profile: dict, credit_code: str):
    biz = profile.get("business") or {}
    values = {
        "company_name": clean_val(profile.get("company_name")),
        "region": clean_val(profile.get("region")) or "北京市朝阳区",
        "social_credit_code": clean_val(credit_code or profile.get("social_credit_code")),
        "established_time": clean_val(biz.get("established_time")),
        "registered_capital": clean_val(biz.get("registered_capital")),
        "registered_address": clean_val(profile.get("registered_address")),
        "mailing_address": clean_val(profile.get("mailing_address")),
        "legal_representative": clean_val(biz.get("legal_representative")),
        "legal_representativemobile": "",
        "legal_representative_email": "",
        "contact_name": "",
        "contact_mobile": "",
        "contact_email": "",
        "contact_title": "",
        "website": "",
        "company_introduction": clean_val(profile.get("summary")) or clean_val(profile.get("company_name")),
        "business_licence": "",
    }
    unfilled = [c for c in COMPANY_REQUIRED_COLS if not values[c]]
    return values, unfilled


def build_company_upsert(profile: dict, credit_code: str):
    """返回 (sql, unfilled 列名清单)。"""
    name = esc(profile.get("company_name", ""))
    region = esc(profile.get("region", "北京市朝阳区"))
    desc = esc(profile.get("summary", "") or profile.get("company_name", ""))
    values, unfilled = build_company_values(profile, credit_code)

    cols = COMPANY_REQUIRED_COLS + ["org_description", "org_type"]
    vals = [f"'{esc(values[c])}'" for c in COMPANY_REQUIRED_COLS] + [f"'{desc}'", "'beichen-enterprise'"]

    lines = [
        "UPDATE public.company SET org_description = "
        f"'{desc}', region = '{region}', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP "
        f"WHERE company_name = '{name}' AND deleted_at IS NULL;",
        f"INSERT INTO public.company ({', '.join(cols)}) "
        f"SELECT {', '.join(vals)} "
        f"WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '{name}' AND deleted_at IS NULL);",
    ]
    if unfilled:
        lines.append(f"-- 以下必填列未采集到，已写空串（未编造）：{'、'.join(unfilled)}")
    return "\n".join(lines), unfilled


# ---------------------------------------------------------------------------
# T-15：申报任务落库字段
# ---------------------------------------------------------------------------

# 跟进状态（中文）→ tasks.task_status 取值。
# DB 注释枚举为 open/in_progress/.../closed，故中文状态写入 extra_data.follow_status，
# 列值取对应枚举，避免写入库内不存在的取值。
FOLLOW_STATUS_MAP = {
    "待启动": "open",
    "进行中": "in_progress",
    "已完成": "completed",
    "已终止": "closed",
}
DEFAULT_FOLLOW_STATUS = "待启动"

# tasks.creator_id 在无可用用户时的占位（该列 NOT NULL 且无外键约束）
CREATOR_PLACEHOLDER = "00000000-0000-0000-0000-000000000000"


def normalize_deadline(v):
    """截止时间规范化：只接受明确日期，禁止推测值。返回 None 表示「截止时间未知」。"""
    s = str(v if v is not None else "").strip()
    if not s:
        return None
    m = re.match(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?', s)
    if not m:
        return None
    if m.group(4):
        return f"{m.group(1)}-{m.group(2)}-{m.group(3)}T{m.group(4)}:{m.group(5)}:00"
    return f"{m.group(1)}-{m.group(2)}-{m.group(3)}"


def build_materials(m: dict):
    """申报材料清单：条目未提供时不做推测填充。"""
    raw = [x for x in (m.get("materials") or []) if str(x or "").strip()] if isinstance(m.get("materials"), list) else []
    if raw:
        return raw, "政策条目已提供"
    return ["以主管部门发布的申报通知为准"], "条目未提供材料清单，未作推测填充"


def creator_expr(creator: str) -> str:
    """creator_id 取值表达式：显式 --creator 优先，否则取一个可用用户，再兜底占位 uuid。"""
    if re.match(r'^[0-9a-fA-F-]{36}$', creator or ""):
        return f"'{creator}'::uuid"
    return ("COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL "
            f"ORDER BY u.created_at LIMIT 1), '{CREATOR_PLACEHOLDER}'::uuid)")


def build_task_insert(company_name: str, title: str, description: str, task_type: str,
                      task_status: str, extra: dict, deadline, creator: str) -> str:
    task_id = str(uuid.uuid4())
    tags = json.dumps(["beichen", task_type], ensure_ascii=False)
    extra_json = json.dumps(extra, ensure_ascii=False)
    deadline_val = f"'{esc(deadline)}'::timestamptz" if deadline else "NULL"
    return (
        "INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, "
        "company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) "
        "SELECT "
        f"'{task_id}', '{esc(title)}', '{esc(description)}', '{task_type}', '{task_status}', 'normal', "
        "c.id, " + creator_expr(creator) + ", "
        f"'{esc(tags)}'::jsonb, '{esc(extra_json)}'::jsonb, {deadline_val}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP "
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
    parser.add_argument("--deadline", default="", help="全局申报截止日 YYYY-MM-DD（条目自带 deadline 优先）")
    parser.add_argument("--creator", default="", help="tasks.creator_id（缺省自动取一个可用用户）")
    parser.add_argument("--follow-status", default=DEFAULT_FOLLOW_STATUS,
                        choices=sorted(FOLLOW_STATUS_MAP.keys()), help="申报任务跟进状态")
    parser.add_argument("--credit-code", default="",
                        help="统一社会信用代码（缺省则写空串表示未采集，不编造）")
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
    global_deadline = normalize_deadline(args.deadline)
    follow_status = args.follow_status

    lines = ["-- 产业政策智能体落库 SQL", f"-- 生成时间: {datetime.now().isoformat()}", ""]
    cu_sql, unfilled = build_company_upsert(profile, args.credit_code)
    lines.append(cu_sql)
    lines.append("")

    lines.append(build_task_insert(
        company_name, f"政策适配报告 - {company_name}", report_md, "policy-match",
        FOLLOW_STATUS_MAP["已完成"],
        {"profile_date": profile_date, "matched_count": matched_count,
         "policy_nos": [m.get("policy_no") for m in matched],
         "follow_status": "已完成",
         "report_file": os.path.basename(args.report)},
        None, args.creator))
    lines.append("")

    apply_tasks = 0
    unknown_deadline = 0
    for m in matched:
        title = f"政策申报 - {m.get('title')}"
        dl = normalize_deadline(m.get("deadline")) or global_deadline
        if not dl:
            unknown_deadline += 1
        materials, materials_source = build_materials(m)
        desc = (f"政策编号：{m.get('policy_no')}\n支持方式：{m.get('support') or '待补充'}\n"
                f"匹配依据：{m.get('basis')}\n"
                f"截止时间：{dl or '截止时间未知（主管部门尚未公布或未获取到明确日期）'}\n"
                f"申报材料以主管部门通知为准。")
        if not dl:
            lines.append(f"-- 截止时间未知：政策编号 {m.get('policy_no')} 未获取到明确截止日期，"
                         "deadline 写 NULL，不作推测填充")
        lines.append(build_task_insert(
            company_name, title, desc, "policy-apply", FOLLOW_STATUS_MAP[follow_status],
            {"policy_no": m.get("policy_no"), "domain": m.get("domain"), "level": m.get("level"),
             "department": m.get("department"), "deadline": dl, "deadline_known": bool(dl),
             "follow_status": follow_status,
             "materials": materials, "materials_source": materials_source,
             "source": m.get("source", ""), "url": m.get("url", "")},
            dl, args.creator))
        lines.append("")
        apply_tasks += 1

    os.makedirs(args.outdir, exist_ok=True)
    sql_file = os.path.join(args.outdir, f"policy_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql")
    with open(sql_file, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    result = {"success": True, "sql_file": sql_file, "company": company_name,
              "policy_match_tasks": 1, "policy_apply_tasks": apply_tasks,
              "unknown_deadline": unknown_deadline,
              "company_unfilled_cols": unfilled,
              "products": [sql_file],
              "db_written": False}
    notes = []
    if unknown_deadline > 0:
        notes.append(f"{unknown_deadline} 条申报任务「截止时间未知」，deadline 已写 NULL，未作推测填充")
    if unfilled:
        notes.append(f"company 必填列未采集 {len(unfilled)} 项（{'、'.join(unfilled)}），已写空串，未编造")
    if notes:
        result["notes"] = notes

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
            print(f"落库失败，已生成产物文件：{sql_file}（未安装 psycopg2，可用: pip install psycopg2）",
                  file=sys.stderr)
            result["error"] = "未安装 psycopg2 驱动"
        except Exception as e:
            result["error"] = str(e)
            print(f"落库失败，已生成产物文件：{sql_file}", file=sys.stderr)

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()