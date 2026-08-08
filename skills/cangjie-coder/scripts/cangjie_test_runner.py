#!/usr/bin/env python3
"""仓颉代码测试运行脚本

使用cjpm test命令运行仓颉项目测试，验证代码正确性。

用法:
    python cangjie_test_runner.py --project /path/to/project [--timeout 300]

输出:
    JSON格式的测试结果
"""

import argparse
import json
import subprocess
import sys
import os
import re
from pathlib import Path


def run_cjpm_test(project_path: str, timeout: int = 300) -> dict:
    result = {
        "tool": "cangjie_test_runner",
        "project_path": project_path,
        "passed": False,
        "total": 0,
        "passed_count": 0,
        "failed_count": 0,
        "skipped_count": 0,
        "test_cases": [],
        "output": "",
        "duration_seconds": 0
    }

    if not os.path.isdir(project_path):
        result["test_cases"].append({
            "name": "project_check",
            "status": "fail",
            "message": f"项目目录不存在: {project_path}"
        })
        return result

    cjpm_path = os.environ.get("CJPM_PATH", "cjpm")

    try:
        import time
        start_time = time.time()

        proc = subprocess.run(
            [cjpm_path, "test"],
            cwd=project_path,
            capture_output=True,
            text=True,
            timeout=timeout,
            encoding="utf-8",
            errors="replace"
        )

        result["duration_seconds"] = round(time.time() - start_time, 2)
        result["output"] = proc.stdout + proc.stderr

        test_cases = parse_test_output(proc.stdout + proc.stderr)
        result["test_cases"] = test_cases
        result["total"] = len(test_cases)
        result["passed_count"] = sum(1 for tc in test_cases if tc["status"] == "pass")
        result["failed_count"] = sum(1 for tc in test_cases if tc["status"] == "fail")
        result["skipped_count"] = sum(1 for tc in test_cases if tc["status"] == "skip")

        result["passed"] = result["failed_count"] == 0 and result["total"] > 0

    except subprocess.TimeoutExpired:
        result["test_cases"].append({
            "name": "timeout",
            "status": "fail",
            "message": f"测试执行超时（{timeout}秒）"
        })
    except FileNotFoundError:
        result["test_cases"].append({
            "name": "cjpm_not_found",
            "status": "fail",
            "message": "cjpm命令未找到，请确保仓颉SDK已安装并配置PATH环境变量"
        })
    except Exception as e:
        result["test_cases"].append({
            "name": "execution_error",
            "status": "fail",
            "message": f"测试执行异常: {str(e)}"
        })

    return result


def parse_test_output(output: str) -> list:
    test_cases = []

    pass_pattern = re.compile(r'(?:PASS|✓|passed)\s*:?\s*(.+)', re.IGNORECASE)
    fail_pattern = re.compile(r'(?:FAIL|✗|failed)\s*:?\s*(.+)', re.IGNORECASE)
    skip_pattern = re.compile(r'(?:SKIP|⊘|skipped)\s*:?\s*(.+)', re.IGNORECASE)

    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue

        match = pass_pattern.match(line)
        if match:
            test_cases.append({
                "name": match.group(1).strip(),
                "status": "pass",
                "message": ""
            })
            continue

        match = fail_pattern.match(line)
        if match:
            test_cases.append({
                "name": match.group(1).strip(),
                "status": "fail",
                "message": line
            })
            continue

        match = skip_pattern.match(line)
        if match:
            test_cases.append({
                "name": match.group(1).strip(),
                "status": "skip",
                "message": ""
            })
            continue

    if not test_cases:
        if "PASS" in output.upper() or "passed" in output.lower():
            test_cases.append({
                "name": "all_tests",
                "status": "pass",
                "message": "所有测试通过（无法解析具体测试用例）"
            })
        elif "FAIL" in output.upper() or "failed" in output.lower():
            test_cases.append({
                "name": "all_tests",
                "status": "fail",
                "message": output[-500:] if len(output) > 500 else output
            })

    return test_cases


def main():
    parser = argparse.ArgumentParser(description="仓颉代码测试运行")
    parser.add_argument("--project", required=True, help="项目根目录路径")
    parser.add_argument("--timeout", type=int, default=300, help="测试超时时间（秒）")
    args = parser.parse_args()

    result = run_cjpm_test(args.project, args.timeout)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result["passed"] else 1)


if __name__ == "__main__":
    main()