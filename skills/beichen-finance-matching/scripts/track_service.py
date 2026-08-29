#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
金融匹配智能体 - Step 5: SOP 六阶段跟踪（Track Service）
北辰金融 SOP 时效引擎：阶段推进（--advance）、超期扫描（--check）、回访提醒（--review）。

用法:
    python track_service.py --case FC-... --advance --owner 张工
    python track_service.py --check
    python track_service.py --case FC-... --review
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta

SOP_STAGES = [
    {"stage": 1, "name": "资料提交与审核", "sla_days": 1},
    {"stage": 2, "name": "方案制定与洽谈", "sla_days": 1},
    {"stage": 3, "name": "金融机构对接", "sla_days": 2},
    {"stage": 4, "name": "落地执行", "sla_days": 5},
    {"stage": 5, "name": "服务闭环", "sla_days": None},
    {"stage": 6, "name": "长期维护", "sla_days": None},
]


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_tracking():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "tracking"))


def default_needs():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "needs"))


def add_workdays(start: datetime, days: int) -> datetime:
    d = start
    n = days
    while n > 0:
        d += timedelta(days=1)
        if d.weekday() < 5:
            n -= 1
    return d


def due_str(start: datetime, sla_days):
    if sla_days is None:
        return "约定时限"
    return add_workdays(start, sla_days).strftime("%Y-%m-%d")


def load_or_init(case_id: str, tracking_dir: str):
    path = os.path.join(tracking_dir, f"{case_id}.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f), path
    # 从需求档案初始化
    need_path = os.path.join(default_needs(), f"{case_id}.json")
    company = case_id
    if os.path.exists(need_path):
        with open(need_path, encoding="utf-8") as f:
            need = json.load(f)
        company = need.get("company_name", case_id)
    s1 = SOP_STAGES[0]
    doc = {"case_id": case_id, "company_name": company, "current_stage": 1,
           "history": [{"stage": 1, "name": s1["name"], "started_at": datetime.now().strftime("%Y-%m-%d"),
                        "due_date": due_str(datetime.now(), s1["sla_days"]), "owner": "",
                        "status": "in_progress"}], "overdue": False}
    os.makedirs(tracking_dir, exist_ok=True)
    return doc, path


def save_doc(doc, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)


def advance_mode(doc, owner):
    cur = doc["current_stage"]
    for h in doc["history"]:
        if h["stage"] == cur:
            h["status"] = "completed"
            h["completed_at"] = datetime.now().strftime("%Y-%m-%d")
    if cur >= len(SOP_STAGES):
        print(json.dumps({"success": True, "note": "已处于最后阶段", "stage": cur}, ensure_ascii=False))
        return
    next_stage = SOP_STAGES[cur]  # SOP_STAGES[cur] 是下一阶段（0-indexed）
    doc["current_stage"] = cur + 1
    now = datetime.now()
    doc["history"].append({"stage": next_stage["stage"], "name": next_stage["name"],
                           "started_at": now.strftime("%Y-%m-%d"),
                           "due_date": due_str(now, next_stage["sla_days"]),
                           "owner": owner, "status": "in_progress"})


def review_mode(doc):
    doc["review_plan"] = {"period": "每季度回访", "next_review_date": add_workdays(datetime.now(), 90).strftime("%Y-%m-%d"),
                          "note": "服务闭环后按约定周期回访维护"}
    return doc


def check_mode(tracking_dir):
    os.makedirs(tracking_dir, exist_ok=True)
    today = datetime.now()
    report = []
    for fn in os.listdir(tracking_dir):
        if not fn.endswith(".json"):
            continue
        path = os.path.join(tracking_dir, fn)
        with open(path, encoding="utf-8") as f:
            doc = json.load(f)
        for h in doc.get("history", []):
            if h.get("status") == "in_progress" and h.get("due_date") and h["due_date"] != "约定时限":
                try:
                    due = datetime.strptime(h["due_date"], "%Y-%m-%d")
                    if due < today:
                        h["status"] = "overdue"
                        report.append({"case_id": doc.get("case_id"), "stage": h.get("stage"),
                                       "name": h.get("name"), "due_date": h.get("due_date"),
                                       "owner": h.get("owner")})
                except ValueError:
                    pass
        save_doc(doc, path)
    print(json.dumps({"success": True, "overdue_count": len(report), "overdue": report}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description="SOP 六阶段跟踪")
    parser.add_argument("--case", default=None, help="服务单号 case_id")
    parser.add_argument("--advance", action="store_true", help="阶段推进")
    parser.add_argument("--check", action="store_true", help="批量超期扫描")
    parser.add_argument("--review", action="store_true", help="创建回访任务")
    parser.add_argument("--owner", default="", help="责任人")
    parser.add_argument("--tracking", default=default_tracking(), help="跟踪目录")
    args = parser.parse_args()

    if args.check:
        check_mode(args.tracking)
        return
    if not args.case:
        print("错误: --advance/--review 必须指定 --case", file=sys.stderr)
        sys.exit(1)

    doc, path = load_or_init(args.case, args.tracking)
    if args.advance:
        advance_mode(doc, args.owner)
    elif args.review:
        review_mode(doc)
    save_doc(doc, path)
    print(json.dumps({"success": True, "case_id": doc["case_id"], "current_stage": doc["current_stage"],
                      "history": doc["history"], "review_plan": doc.get("review_plan"),
                      "output": path}, ensure_ascii=False))


if __name__ == "__main__":
    main()