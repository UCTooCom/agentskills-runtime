#!/usr/bin/env python3
"""仓颉代码编译验证脚本

使用cjpm build命令编译仓颉项目，验证代码编译正确性。

用法:
    python cangjie_compile.py --project /path/to/project [--verbose] [--timeout 300]

输出:
    JSON格式的编译结果
"""

import argparse
import json
import subprocess
import sys
import os
from pathlib import Path


def run_cjpm_build(project_path: str, verbose: bool = False, timeout: int = 300) -> dict:
    result = {
        "tool": "cjpm_build",
        "project_path": project_path,
        "passed": False,
        "errors": [],
        "warnings": [],
        "output": "",
        "duration_seconds": 0
    }

    if not os.path.isdir(project_path):
        result["errors"].append({
            "line": 0,
            "column": 0,
            "message": f"项目目录不存在: {project_path}",
            "severity": "error"
        })
        return result

    cjpm_path = os.environ.get("CJPM_PATH", "cjpm")

    try:
        import time
        start_time = time.time()

        cmd = [cjpm_path, "build"]
        if verbose:
            cmd.append("-V")

        proc = subprocess.run(
            cmd,
            cwd=project_path,
            capture_output=True,
            text=True,
            timeout=timeout,
            encoding="utf-8",
            errors="replace"
        )

        result["duration_seconds"] = round(time.time() - start_time, 2)
        result["output"] = proc.stdout + proc.stderr

        if proc.returncode == 0:
            result["passed"] = True
        else:
            errors, warnings = parse_cjpm_output(proc.stdout + proc.stderr)
            result["errors"] = errors
            result["warnings"] = warnings

    except subprocess.TimeoutExpired:
        result["errors"].append({
            "line": 0,
            "column": 0,
            "message": f"编译超时（{timeout}秒）",
            "severity": "error"
        })
    except FileNotFoundError:
        result["errors"].append({
            "line": 0,
            "column": 0,
            "message": f"cjpm命令未找到，请确保仓颉SDK已安装并配置PATH环境变量",
            "severity": "error"
        })
    except Exception as e:
        result["errors"].append({
            "line": 0,
            "column": 0,
            "message": f"编译执行异常: {str(e)}",
            "severity": "error"
        })

    return result


def parse_cjpm_output(output: str) -> tuple:
    errors = []
    warnings = []

    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue

        if "error" in line.lower():
            error_info = parse_error_line(line)
            if error_info:
                errors.append(error_info)
        elif "warning" in line.lower():
            warning_info = parse_error_line(line, severity="warning")
            if warning_info:
                warnings.append(warning_info)

    return errors, warnings


def parse_error_line(line: str, severity: str = "error") -> dict:
    import re

    patterns = [
        r"(.+?):(\d+):(\d+):\s*(error|warning):\s*(.+)",
        r"(.+?):(\d+):\s*(error|warning):\s*(.+)",
        r"(error|warning):\s*(.+)",
    ]

    for pattern in patterns:
        match = re.match(pattern, line, re.IGNORECASE)
        if match:
            groups = match.groups()
            if len(groups) == 5:
                return {
                    "file": groups[0],
                    "line": int(groups[1]),
                    "column": int(groups[2]),
                    "message": groups[4],
                    "severity": severity
                }
            elif len(groups) == 4:
                return {
                    "file": groups[0],
                    "line": int(groups[1]),
                    "column": 0,
                    "message": groups[3],
                    "severity": severity
                }
            elif len(groups) == 2:
                return {
                    "file": "",
                    "line": 0,
                    "column": 0,
                    "message": groups[1],
                    "severity": severity
                }

    return {
        "file": "",
        "line": 0,
        "column": 0,
        "message": line,
        "severity": severity
    }


def main():
    parser = argparse.ArgumentParser(description="仓颉代码编译验证")
    parser.add_argument("--project", required=True, help="项目根目录路径")
    parser.add_argument("--verbose", action="store_true", help="详细输出")
    parser.add_argument("--timeout", type=int, default=300, help="编译超时时间（秒）")
    args = parser.parse_args()

    result = run_cjpm_build(args.project, args.verbose, args.timeout)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()