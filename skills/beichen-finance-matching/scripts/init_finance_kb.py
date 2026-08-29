#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
金融匹配智能体 - Step 0: 金融工具数据库初始化（Init Finance KB）
以金融伙伴种子（finance-seed.json）为输入，生成：
  1) 金融伙伴库 knowledge/finance-partners/{banks,securities,funds,investors}.json
  2) 产品要素库 knowledge/finance-products/{机构}-{产品}.md
  3) 总索引 knowledge/finance-index.json（机构/类型/优势领域/产品数）

用法:
    python init_finance_kb.py --seed knowledge/finance-seed.json [--kb knowledge] [--force]
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime

TYPE_CN = {"bank": "银行", "securities": "证券", "fund": "基金", "investor": "投资公司"}
TYPE_FILE = {"bank": "banks", "securities": "securities", "fund": "funds", "investor": "investors"}


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_kb():
    return os.path.normpath(os.path.join(script_dir(), "..", "knowledge"))


def sanitize_filename(s: str) -> str:
    s = re.sub(r'[\s\u3000]+', '', s or "")
    s = re.sub(r'[\\/:*?"<>|()（）/]', '', s)
    return s or "product"


def main():
    parser = argparse.ArgumentParser(description="初始化金融工具数据库")
    parser.add_argument("--seed", required=True, help="金融伙伴种子 JSON")
    parser.add_argument("--kb", default=default_kb(), help="知识库根目录")
    parser.add_argument("--force", action="store_true", help="覆盖已存在条目")
    args = parser.parse_args()

    with open(args.seed, encoding="utf-8") as f:
        seed = json.load(f)

    partners_dir = os.path.join(args.kb, "finance-partners")
    products_dir = os.path.join(args.kb, "finance-products")
    experience_dir = os.path.join(args.kb, "finance-experience")
    for d in (partners_dir, products_dir, experience_dir):
        os.makedirs(d, exist_ok=True)

    partners = seed.get("partners", [])
    grouped = {}
    for p in partners:
        ftype = TYPE_FILE.get(p.get("type", "bank"), "banks")
        grouped.setdefault(ftype, []).append(p)

    # 写四类伙伴库 JSON
    for ftype in ("banks", "securities", "funds", "investors"):
        items = grouped.get(ftype, [])
        fpath = os.path.join(partners_dir, f"{ftype}.json")
        if items or not os.path.exists(fpath) or args.force:
            with open(fpath, "w", encoding="utf-8") as f:
                json.dump({"file": ftype, "partners": items}, f, ensure_ascii=False, indent=2)

    # 写产品要素库 + 汇总索引
    index = {"version": "1.0.0", "generated_at": datetime.now().isoformat(),
             "partner_count": len(partners), "partners": []}
    product_total = 0
    for p in partners:
        products = p.get("products", [])
        product_list = []
        for prod in products:
            fname = f"{sanitize_filename(p['name'])}-{sanitize_filename(prod['name'])}.md"
            fpath = os.path.join(products_dir, fname)
            if not os.path.exists(fpath) or args.force:
                lines = ["---",
                         f"partner: {p['name']}",
                         f"partner_type: {TYPE_CN.get(p.get('type'), p.get('type'))}",
                         f"product: {prod['name']}",
                         f"type: {prod.get('type', '')}",
                         f"amount: {prod.get('amount', '')}",
                         f"term: {prod.get('term', '')}",
                         f"guarantee: {prod.get('guarantee', '')}",
                         f"target: {prod.get('target', '')}",
                         f"rate: {prod.get('rate', '')}",
                         "---",
                         "",
                         f"# {prod['name']}",
                         "",
                         f"- 机构：{p['name']}",
                         f"- 产品类型：{prod.get('type', '')}",
                         f"- 额度：{prod.get('amount', '')}",
                         f"- 期限：{prod.get('term', '')}",
                         f"- 担保方式：{prod.get('guarantee', '')}",
                         f"- 适用客群：{prod.get('target', '')}",
                         ""]
                with open(fpath, "w", encoding="utf-8") as f:
                    f.write("\n".join(lines))
            product_list.append({
                "name": prod["name"], "type": prod.get("type", ""),
                "amount": prod.get("amount", ""), "term": prod.get("term", ""),
                "guarantee": prod.get("guarantee", ""), "target": prod.get("target", ""),
                "purpose": prod.get("purpose", []), "file": os.path.join("finance-products", fname),
            })
        index["partners"].append({
            "partner_no": p.get("partner_no"), "name": p["name"], "type": p.get("type"),
            "strength_domains": p.get("strength_domains", []),
            "service_count": p.get("service_count", 0), "avg_cycle_days": p.get("avg_cycle_days", 0),
            "products": product_list,
        })
        product_total += len(products)

    index["product_count"] = product_total
    index["finance_policies"] = seed.get("finance_policies", [])
    index_path = os.path.join(args.kb, "finance-index.json")
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    print(json.dumps({"success": True, "index": index_path, "partner_count": len(partners),
                      "product_count": product_total, "output": index_path}, ensure_ascii=False))


if __name__ == "__main__":
    main()