#!/usr/bin/env python3
"""仓颉代码修复建议脚本

分析仓颉代码编译错误，生成修复建议。

用法:
    python cangjie_fix_suggest.py --file /path/to/file.cj --error "error output"

输出:
    JSON格式的修复建议
"""

import argparse
import json
import re
import sys
from pathlib import Path


COMMON_FIXES = {
    "type mismatch": {
        "Int32": "Int64",
        "Int": "Int64",
        "Float": "Float64",
    },
    "cannot find module": {
        "suggestion": "检查import语句和cjpm.toml依赖配置",
    },
    "cannot find symbol": {
        "suggestion": "检查标识符拼写和导入语句",
    },
    "cjc-version mismatch": {
        "suggestion": "更新SDK或修改cjpm.toml中的cjc-version字段",
    },
    "circular dependency": {
        "suggestion": "运行cjpm check检查依赖，重构代码移除循环依赖",
    },
}


def generate_fix_suggestions(file_path: str, error_output: str) -> dict:
    result = {
        "tool": "cangjie_fix_suggest",
        "file_path": file_path,
        "suggestions": [],
        "auto_fixable": False
    }

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except FileNotFoundError:
        result["suggestions"].append({
            "line": 0,
            "description": f"文件不存在: {file_path}",
            "original": "",
            "suggested": "",
            "confidence": 0.0
        })
        return result

    error_lines = parse_errors(error_output)

    for error_info in error_lines:
        line_num = error_info.get("line", 0)
        message = error_info.get("message", "")
        file_ref = error_info.get("file", "")

        if file_ref and file_path.endswith(file_ref.replace("/", os.sep)):
            pass
        elif file_ref and not file_path.endswith(file_ref.replace("/", os.sep)):
            continue

        suggestions = generate_suggestions_for_error(message, line_num, lines)
        result["suggestions"].extend(suggestions)

    if result["suggestions"]:
        result["auto_fixable"] = any(s.get("confidence", 0) >= 0.8 for s in result["suggestions"])

    return result


def parse_errors(error_output: str) -> list:
    errors = []

    patterns = [
        r"(.+?):(\d+):(\d+):\s*error:\s*(.+)",
        r"(.+?):(\d+):\s*error:\s*(.+)",
        r"error:\s*(.+)",
    ]

    for line in error_output.splitlines():
        line = line.strip()
        if not line:
            continue

        for pattern in patterns:
            match = re.match(pattern, line)
            if match:
                groups = match.groups()
                if len(groups) == 4:
                    errors.append({
                        "file": groups[0],
                        "line": int(groups[1]),
                        "column": int(groups[2]),
                        "message": groups[3]
                    })
                elif len(groups) == 3:
                    errors.append({
                        "file": groups[0],
                        "line": int(groups[1]),
                        "message": groups[2]
                    })
                elif len(groups) == 1:
                    errors.append({
                        "file": "",
                        "line": 0,
                        "message": groups[0]
                    })
                break

    return errors


def generate_suggestions_for_error(message: str, line_num: int, lines: list) -> list:
    suggestions = []

    for error_type, fixes in COMMON_FIXES.items():
        if error_type.lower() in message.lower():
            if error_type == "type mismatch":
                for old_type, new_type in fixes.items():
                    if old_type in message:
                        if 0 < line_num <= len(lines):
                            original_line = lines[line_num - 1].rstrip()
                            if old_type in original_line:
                                suggested_line = original_line.replace(old_type, new_type)
                                suggestions.append({
                                    "line": line_num,
                                    "description": f"将{old_type}改为{new_type}",
                                    "original": original_line.strip(),
                                    "suggested": suggested_line.strip(),
                                    "confidence": 0.9
                                })
            else:
                suggestions.append({
                    "line": line_num,
                    "description": fixes.get("suggestion", message),
                    "original": lines[line_num - 1].strip() if 0 < line_num <= len(lines) else "",
                    "suggested": "",
                    "confidence": 0.6
                })

    if "unused" in message.lower():
        if 0 < line_num <= len(lines):
            original_line = lines[line_num - 1].rstrip()
            suggestions.append({
                "line": line_num,
                "description": f"移除未使用的声明或添加使用",
                "original": original_line.strip(),
                "suggested": f"// {original_line.strip()}  // 未使用，暂时注释",
                "confidence": 0.5
            })

    if "missing" in message.lower() and "return" in message.lower():
        if 0 < line_num <= len(lines):
            suggestions.append({
                "line": line_num,
                "description": "添加缺失的return语句",
                "original": lines[line_num - 1].strip(),
                "suggested": "return None  // 添加默认返回值",
                "confidence": 0.4
            })

    if not suggestions:
        suggestions.append({
            "line": line_num,
            "description": f"无法自动修复: {message}",
            "original": lines[line_num - 1].strip() if 0 < line_num <= len(lines) else "",
            "suggested": "",
            "confidence": 0.0
        })

    return suggestions


def main():
    parser = argparse.ArgumentParser(description="仓颉代码修复建议")
    parser.add_argument("--file", required=True, help="仓颉代码文件路径")
    parser.add_argument("--error", required=True, help="编译错误输出")
    args = parser.parse_args()

    result = generate_fix_suggestions(args.file, args.error)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0)


if __name__ == "__main__":
    main()