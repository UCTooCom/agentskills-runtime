#!/usr/bin/env python3
"""
企业名单校验/清洗/去重（T5.1）

功能：
  - 名单非空校验（空名单返回"企业名单不能为空"）
  - 首尾空白清洗
  - 非法字符标注（控制字符、纯标点等）
  - 自动去重（保留首次出现，提示去重结果）

用法：
  python validate_enterprise_list.py --input "腾讯科技,阿里巴巴,,  字节跳动 ,腾讯科技"
  python validate_enterprise_list.py --input-file enterprises.txt
  python validate_enterprise_list.py --input "腾讯科技" --scene supplier

输出 JSON：
  {
    "valid": true/false,
    "enterprises": ["腾讯科技", "阿里巴巴", "字节跳动"],
    "invalid_entries": [{"original": "??", "reason": "非法字符"}],
    "duplicates_removed": ["腾讯科技"],
    "scene": "supplier",
    "error": null  // 或 "企业名单不能为空"
  }
"""
import argparse
import json
import re
import sys
from typing import List, Dict, Any


INVALID_CHAR_PATTERN = re.compile(r'[\x00-\x1f\x7f-\x9f]')
PURE_PUNCT_PATTERN = re.compile(r'^[\s\W_]+$')


def validate_and_clean(enterprises: List[str], scene: str = "") -> Dict[str, Any]:
    if not enterprises or all(e.strip() == "" for e in enterprises):
        return {
            "valid": False,
            "enterprises": [],
            "invalid_entries": [],
            "duplicates_removed": [],
            "scene": scene,
            "error": "企业名单不能为空"
        }

    seen = set()
    valid_enterprises = []
    invalid_entries = []
    duplicates_removed = []

    for raw in enterprises:
        cleaned = raw.strip()

        if not cleaned:
            continue

        if INVALID_CHAR_PATTERN.search(cleaned):
            invalid_entries.append({
                "original": raw,
                "reason": "含控制字符/非法字符"
            })
            continue

        if PURE_PUNCT_PATTERN.match(cleaned):
            invalid_entries.append({
                "original": raw,
                "reason": "纯标点/符号，非有效企业名称"
            })
            continue

        if cleaned in seen:
            duplicates_removed.append(cleaned)
            continue

        seen.add(cleaned)
        valid_enterprises.append(cleaned)

    if not valid_enterprises:
        return {
            "valid": False,
            "enterprises": [],
            "invalid_entries": invalid_entries,
            "duplicates_removed": duplicates_removed,
            "scene": scene,
            "error": "企业名单不能为空（所有条目均无效）"
        }

    return {
        "valid": True,
        "enterprises": valid_enterprises,
        "invalid_entries": invalid_entries,
        "duplicates_removed": duplicates_removed,
        "scene": scene,
        "error": None
    }


def main():
    parser = argparse.ArgumentParser(description="企业名单校验/清洗/去重")
    parser.add_argument("--input", type=str, default="", help="企业名单（逗号分隔）")
    parser.add_argument("--input-file", type=str, default="", help="从文件读取企业名单（每行一个）")
    parser.add_argument("--scene", type=str, default="",
                        choices=["", "supplier", "credit", "investment", "competitor", "related_risk"],
                        help="尽调场景维度")
    args = parser.parse_args()

    enterprises: List[str] = []
    if args.input_file:
        with open(args.input_file, "r", encoding="utf-8") as f:
            enterprises = [line.rstrip("\n\r") for line in f]
    elif args.input:
        enterprises = args.input.split(",")
    else:
        print(json.dumps({
            "valid": False, "enterprises": [], "invalid_entries": [],
            "duplicates_removed": [], "scene": args.scene,
            "error": "请通过 --input 或 --input-file 提供企业名单"
        }, ensure_ascii=False, indent=2))
        sys.exit(1)

    result = validate_and_clean(enterprises, args.scene)
    print(json.dumps(result, ensure_ascii=False, indent=2))

    if not result["valid"]:
        sys.exit(1)


if __name__ == "__main__":
    main()