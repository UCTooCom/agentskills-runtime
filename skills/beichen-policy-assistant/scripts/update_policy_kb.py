#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
产业政策智能体 - 政策库自动更新（Update Policy KB）
抓取模式（默认，供每日 cron 触发）：从政府网站抓取最新政策 → 储备库 output/pending/{date}.json（状态 pending）。
commit 模式（人工研判确认后）：读取储备库中被确认条目 → 转入政策原文库（active）→ 更新索引。

用法:
    # 抓取模式
    python update_policy_kb.py --sources default
    python update_policy_kb.py --demo          # 生成示例储备流水（便于演示闭环）
    # commit 研判入库（需留痕研判人）
    python update_policy_kb.py --commit --date 2026-08-29 --reviewer 张工
"""

import argparse
import json
import os
import re
import sys
import urllib.request
from datetime import datetime

SOURCE_URLS = {
    "北京市人民政府": "https://www.beijing.gov.cn/",
    "朝阳区人民政府": "http://www.bjchy.gov.cn/",
    "北京市科委": "https://kw.beijing.gov.cn/",
    "中关村管委会": "https://zgcgw.beijing.gov.cn/",
}


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_kb():
    return os.path.normpath(os.path.join(script_dir(), "..", "knowledge"))


def default_pending():
    return os.path.normpath(os.path.join(script_dir(), "..", "output", "pending"))


def sanitize_filename(s: str) -> str:
    s = re.sub(r'[\s\u3000]+', '', s or "")
    s = re.sub(r'[\\/:*?"<>|]', '', s)
    return s or "policy"


def fetch_source(url: str) -> list:
    """尽力抓取来源页，解析疑似政策条目（标题 + 链接）。失败返回空列表。"""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as r:
            html = r.read().decode("utf-8", errors="ignore")
    except Exception as e:
        return [{"error": str(e)}]
    items = []
    for m in re.finditer(r'<a[^>]+href="([^"]+)"[^>]*>([^<]*)</a>', html):
        title = re.sub(r'\s+', '', m.group(2))
        if re.search(r'政策|申报|通知|补贴|支持', title) and len(title) > 6:
            href = m.group(1)
            if href.startswith("/"):
                href = url.rstrip("/") + href
            items.append({"title": title, "url": href})
        if len(items) >= 20:
            break
    return items


def demo_pending(date: str) -> list:
    """生成示例储备流水（模拟抓取结果，覆盖 pending 与 confirmed 状态）。"""
    return [
        {"policy_no": None, "title": "朝阳区关于支持数据要素产业高质量发展的若干措施（征求意见稿）",
         "url": "https://example.gov.cn/notice/demo-1", "department": "朝阳区数据局",
         "level": "区级", "domain": "数据要素", "published_date": date, "status": "pending"},
        {"policy_no": None, "title": "北京市关于进一步支持人工智能创新应用的通知",
         "url": "https://example.gov.cn/notice/demo-2", "department": "北京市经信局",
         "level": "市级", "domain": "人工智能", "published_date": date, "status": "confirmed",
         "reviewer": "待填", "reviewed_at": date},
    ]


def fetch_mode(args):
    pending = []
    if args.demo:
        pending = demo_pending(args.date)
    else:
        sources = SOURCE_URLS if args.sources == "default" else {u: u for u in args.sources.split(",")}
        for name, url in sources.items():
            items = fetch_source(url)
            for it in items:
                if "error" in it:
                    pending.append({"source": name, "url": url, "error": it["error"]})
                else:
                    it.update({"source": name, "department": name, "published_date": args.date, "status": "pending"})
                    pending.append(it)
    os.makedirs(args.pending, exist_ok=True)
    out = os.path.join(args.pending, f"{args.date}.json")
    payload = {"date": args.date, "fetched_at": datetime.now().isoformat(), "count": len(pending), "items": pending}
    with open(out, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(json.dumps({"success": True, "mode": "fetch", "output": out, "count": len(pending)}, ensure_ascii=False))


def render_markdown(item: dict, new_no: str) -> str:
    cond = {"region": item.get("region", ""), "qualification": item.get("qualification", ""),
            "industry": item.get("industry", [])}
    return "\n".join([
        "---",
        f'policy_no: "{new_no}"',
        f'domain: {item.get("domain", "")}',
        f'level: {item.get("level", "")}',
        f'department: {item.get("department", "")}',
        f'title: {item.get("title", "")}',
        "status: active",
        "conditions:",
        f'  region: {cond["region"]}',
        f'  qualification: {cond["qualification"]}',
        f'  industry: {json.dumps(cond["industry"], ensure_ascii=False)}',
        f'support: "{item.get("support", "")}"',
        f'source: {item.get("url", "")}',
        "---",
        "",
        f'# {item.get("title", "")}',
        "",
        "## 政策要点",
        "",
        "（申报条件、支持方式、申报周期、材料清单——待运营方补全）",
        "",
    ])


def commit_mode(args):
    pending_file = os.path.join(args.pending, f"{args.date}.json")
    if not os.path.exists(pending_file):
        print("错误: 未找到当日储备流水，请先执行抓取模式", file=sys.stderr)
        sys.exit(1)
    with open(pending_file, encoding="utf-8") as f:
        payload = json.load(f)
    confirmed = [it for it in payload.get("items", []) if it.get("status") == "confirmed" and not it.get("policy_no")]
    if not confirmed:
        print(json.dumps({"success": True, "mode": "commit", "committed": 0,
                          "note": "无已确认待入库条目"}, ensure_ascii=False))
        return

    index_path = os.path.join(args.kb, "policy-index.json")
    with open(index_path, encoding="utf-8") as f:
        index = json.load(f)
    existing_nos = {str(p.get("policy_no")) for p in index.get("policies", [])}
    max_no = max([int(n) for n in existing_nos if n.isdigit()] + [0])

    orig_dir = os.path.join(args.kb, "policy-original")
    os.makedirs(orig_dir, exist_ok=True)
    committed = 0
    for item in confirmed:
        max_no += 1
        new_no = str(max_no)
        review_time = datetime.now().strftime("%Y-%m-%d")
        fname = f"{new_no}-{sanitize_filename(item.get('title', ''))}.md"
        with open(os.path.join(orig_dir, fname), "w", encoding="utf-8") as f:
            f.write(render_markdown(item, new_no))
        index["policies"].append({
            "policy_no": new_no, "domain": item.get("domain", ""), "level": item.get("level", ""),
            "department": item.get("department", ""), "title": item.get("title", ""),
            "status": "active", "conditions": {}, "support": item.get("support", ""),
            "file": os.path.join("policy-original", fname),
        })
        item["policy_no"] = new_no
        item["reviewer"] = args.reviewer
        item["reviewed_at"] = review_time
        committed += 1

    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)
    with open(pending_file, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(json.dumps({"success": True, "mode": "commit", "committed": committed,
                      "reviewer": args.reviewer, "next_policy_no": str(max_no)}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description="政策库自动更新")
    parser.add_argument("--sources", default="default", help="抓取来源（default 或逗号分隔 URL）")
    parser.add_argument("--commit", action="store_true", help="研判确认入库模式")
    parser.add_argument("--reviewer", default="", help="研判人（commit 模式必填）")
    parser.add_argument("--date", default=datetime.now().strftime("%Y-%m-%d"), help="日期")
    parser.add_argument("--demo", action="store_true", help="生成示例储备流水")
    parser.add_argument("--kb", default=default_kb(), help="知识库根目录")
    parser.add_argument("--pending", default=default_pending(), help="储备库目录")
    args = parser.parse_args()

    if args.commit:
        if not args.reviewer:
            print("错误: commit 模式必须指定 --reviewer（研判人留痕）", file=sys.stderr)
            sys.exit(1)
        commit_mode(args)
    else:
        fetch_mode(args)


if __name__ == "__main__":
    main()