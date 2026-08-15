#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智能投研助理 - Step 5: 结果落库（Save Report to DB）
将投资研报按公司写入 company 表（upsert），研报内容写入关联 tasks 表（task_type='research'），
复用 aibuilder 模块呈现。

用法:
    # 方式一：直接写库（需 psycopg2 或 psql）
    python3 save_report_to_db.py --report output/brief/2026-08-07.md --factors output/factors/2026-08-07.json
    # 方式二：仅生成 SQL 文件（无数据库驱动时）
    python3 save_report_to_db.py --report output/brief/2026-08-07.md --sql-only --outdir output/sql

环境变量（或 --db-url 参数）:
    DATABASE_URL=postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo
"""

import argparse
import json
import os
import re
import sys
import uuid
from datetime import datetime


def load_report(report_path: str) -> str:
    with open(report_path, encoding="utf-8") as f:
        return f.read()


def split_report_by_company(report_md: str) -> list:
    """将简报按公司拆分（按 '每日投资简报 - ' 标题行切分）"""
    sections = []
    current = {"title": "", "content": ""}
    for line in report_md.splitlines():
        m = re.match(r"^#*\s*每日投资简报\s*-\s*(.+)", line.strip())
        if m:
            if current["title"] or current["content"]:
                sections.append(current)
            current = {"title": m.group(1).strip(), "content": line + "\n"}
        else:
            current["content"] += line + "\n"
    if current["title"] or current["content"]:
        sections.append(current)
    return sections


def esc(s: str) -> str:
    """SQL 字符串转义（单引号 + 反斜杠）"""
    return (s or "").replace("\\", "\\\\").replace("'", "''")


def build_company_upsert_sql(company_name: str, factors: dict) -> str:
    """生成 company 表去重写入 SQL。

    注意：company 表只有 id 主键，没有 company_name 唯一索引/约束，
    因此不能使用 `ON CONFLICT (company_name)`（会报
    "there is no unique or exclusion constraint matching the ON CONFLICT specification"）。
    改为两步：
      1) 若公司已存在（按 company_name + deleted_at IS NULL）则 UPDATE 组织描述；
      2) 若不存在则 INSERT。
    这样已有公司（如之前导入的"贵州茅台"）不会被重复创建，每日新研报会
    通过 tasks 插入时的子查询关联到已有 company.id。
    """
    org_description = ""
    if factors and factors.get("market_factors"):
        mf = factors["market_factors"]
        org_description = (
            f"投资简报日期 {factors.get('date', '')}："
            f"收盘 {mf.get('close_price')}，涨跌幅 {mf.get('change_pct')}%，"
            f"PE {mf.get('pe')}，PB {mf.get('pb')}，市值 {mf.get('market_cap')}"
        )
    company_name_esc = esc(company_name)
    return "\n".join([
        # 1) 已存在 → 更新组织描述（不重复创建公司）
        "UPDATE public.company SET org_description = "
        f"'{esc(org_description)}', updated_at = CURRENT_TIMESTAMP "
        f"WHERE company_name = '{company_name_esc}' AND deleted_at IS NULL;",
        # 2) 不存在 → 插入新公司
        "INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) "
        f"SELECT '{company_name_esc}', '中国', '{esc(org_description)}', 'investment-research', false "
        f"WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '{company_name_esc}' AND deleted_at IS NULL);",
    ])


def build_task_insert_sql(company_name: str, report_content: str, factors: dict) -> str:
    """生成 tasks 表插入 SQL（研报内容写入 description，关联已有 company_id）。

    去重策略：同一公司 + 同一简报标题（每日简报）已存在且未删除时不重复插入，
    避免重复导入同一期研报。
    """
    task_id = str(uuid.uuid4())
    tags = json.dumps(["investment-research", "daily-brief"], ensure_ascii=False)
    report_date = (factors.get("date", "") if factors else "") or datetime.now().strftime("%Y-%m-%d")
    # v11修复：按当前 section 公司名匹配 factors.companies 中的 code，不再始终取 companies[0]
    company_code = ""
    if factors and factors.get("companies"):
        for comp in factors["companies"]:
            if comp.get("name", "") == company_name:
                company_code = comp.get("code", "")
                break
    extra = json.dumps({
        "report_date": report_date,
        "code": company_code,
    }, ensure_ascii=False)
    title = f"每日投资简报 - {company_name}"
    return (
        "INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) "
        "SELECT "
        f"'{task_id}', '{esc(title)}', '{esc(report_content)}', 'research', 'completed', 'normal', "
        "c.id, "
        f"'{esc(tags)}'::jsonb, '{esc(extra)}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP "
        "FROM public.company c WHERE c.company_name = "
        f"'{esc(company_name)}' AND c.deleted_at IS NULL "
        # 同一公司同一期简报（按标题去重）已存在时不重复插入
        "AND NOT EXISTS ("
        "  SELECT 1 FROM public.tasks t "
        "  WHERE t.company_id = c.id AND t.title = "
        f"'{esc(title)}' AND t.deleted_at IS NULL"
        ");"
    )


def main():
    parser = argparse.ArgumentParser(description="保存投资简报到 company/tasks 表")
    parser.add_argument("--report", required=True, help="简报 Markdown 文件")
    parser.add_argument("--factors", default=None, help="要素 JSON（可选）")
    parser.add_argument("--sql-only", action="store_true", help="仅生成 SQL 文件不直连数据库")
    # v17修复：--outdir 默认值改为基于脚本所在目录的绝对路径，避免 cwd 不一致导致相对路径写到了别处
    _script_dir = os.path.dirname(os.path.abspath(__file__))
    _default_outdir = os.path.normpath(os.path.join(_script_dir, "..", "output", "sql"))
    parser.add_argument("--outdir", default=_default_outdir, help="SQL 输出目录")
    parser.add_argument("--db-url", default=os.environ.get("DATABASE_URL", ""), help="数据库连接串")
    args = parser.parse_args()

    report_md = load_report(args.report)
    factors_data = None
    if args.factors and os.path.exists(args.factors):
        with open(args.factors, encoding="utf-8") as f:
            factors_data = json.load(f)

    sections = split_report_by_company(report_md)
    if not sections:
        # 没有按公司拆分时，整体作为一条
        sections = [{"title": "投资简报", "content": report_md}]

    sql_lines = ["-- 智能投研助理落库 SQL", f"-- 生成时间: {datetime.now().isoformat()}", ""]
    for sec in sections:
        company_name = sec["title"]
        sql_lines.append(build_company_upsert_sql(company_name, factors_data))
        sql_lines.append(build_task_insert_sql(company_name, sec["content"], factors_data))
        sql_lines.append("")

    os.makedirs(args.outdir, exist_ok=True)
    sql_file = os.path.join(args.outdir, f"report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql")
    with open(sql_file, "w", encoding="utf-8") as f:
        f.write("\n".join(sql_lines))

    result = {"success": True, "sql_file": sql_file, "company_count": len(sections), "db_written": False}

    if not args.sql_only and args.db_url:
        try:
            import psycopg2  # type: ignore
            conn = psycopg2.connect(args.db_url)
            cur = conn.cursor()
            for stmt in sql_lines:
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
