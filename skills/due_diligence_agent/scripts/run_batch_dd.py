#!/usr/bin/env python3
"""
批量尽调任务编排（T5.5）

功能：
  - 名单校验 → 创建任务记录 → 逐企业（dd-fetch 采集 → 穿透 → 分级 → 报告 → dd-save 落库）
  - 汇总横向对比 + 汇总报告
  - 部分失败隔离（单企业失败不中断批次）
  - 进度反馈（已完成/失败/剩余）

用法：
  python run_batch_dd.py --enterprises "腾讯科技,阿里巴巴,字节跳动" --scene supplier --outdir output/
  python run_batch_dd.py --enterprises-file enterprises.txt --scene credit --outdir output/

环境变量：
  HOST_BASE_URL：宿主 API 基地址（默认 http://localhost:8080）
  MCP_ALIAS：MCP 别名（默认 tianyancha）
"""
import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error
from typing import Dict, List, Any, Optional
from datetime import datetime

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))


def call_host_api(base_url: str, path: str, body: Dict) -> Dict[str, Any]:
    url = f"{base_url.rstrip('/')}{path}"
    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return {"errno": str(e.code), "errmsg": e.read().decode("utf-8", errors="replace")}
    except Exception as e:
        return {"errno": "-1", "errmsg": str(e)}


def dd_fetch(base_url: str, enterprise: str, mcp_alias: str, scene: str) -> Dict[str, Any]:
    return call_host_api(base_url, "/api/v1/uctoo/due_diligence/dd-fetch", {
        "enterprise_name": enterprise,
        "mcp_alias": mcp_alias,
        "scene": scene
    })


def dd_save(base_url: str, enterprise: str, data: Dict) -> Dict[str, Any]:
    return call_host_api(base_url, "/api/v1/uctoo/due_diligence/dd-save", {
        "enterprise_name": enterprise,
        "data": data
    })


def run_script(script_name: str, args: List[str]) -> Dict[str, Any]:
    import subprocess
    script_path = os.path.join(SCRIPTS_DIR, script_name)
    cmd = [sys.executable, script_path] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120, encoding="utf-8")
        if result.returncode == 0:
            return json.loads(result.stdout) if result.stdout.strip() else {}
        else:
            return {"error": result.stderr or result.stdout}
    except Exception as e:
        return {"error": str(e)}


def process_single_enterprise(
    enterprise: str,
    base_url: str,
    mcp_alias: str,
    scene: str,
    outdir: str
) -> Dict[str, Any]:
    result: Dict[str, Any] = {"enterprise": enterprise, "status": "processing", "errors": []}

    # 1. dd-fetch
    fetch_result = dd_fetch(base_url, enterprise, mcp_alias, scene)
    if fetch_result.get("errno", "0") != "0":
        result["status"] = "failed"
        result["errors"].append(f"dd-fetch 失败：{fetch_result.get('errmsg', '未知错误')}")
        return result

    fetch_data = fetch_result.get("data", {})
    basic_info = fetch_data.get("basic_info", {})
    equity_data = fetch_data.get("equity_data", {})
    risk_data = fetch_data.get("risk_data", {})

    # 2. 穿透
    pen_input = os.path.join(outdir, f"_tmp_{enterprise}_equity.json")
    with open(pen_input, "w", encoding="utf-8") as f:
        json.dump(equity_data, f, ensure_ascii=False)
    pen_result = run_script("penetrate_equity.py", [
        "--input", pen_input, "--enterprise", enterprise,
        "--outdir", os.path.join(outdir, "penetration")
    ])
    os.remove(pen_input) if os.path.exists(pen_input) else None
    if "error" in pen_result:
        result["errors"].append(f"穿透失败：{pen_result['error']}")

    # 3. 分级
    risk_input = os.path.join(outdir, f"_tmp_{enterprise}_risk.json")
    with open(risk_input, "w", encoding="utf-8") as f:
        json.dump(risk_data, f, ensure_ascii=False)
    tier_result = run_script("tier_risks.py", [
        "--input", risk_input, "--enterprise", enterprise,
        "--outdir", os.path.join(outdir, "risks")
    ])
    os.remove(risk_input) if os.path.exists(risk_input) else None
    if "error" in tier_result:
        result["errors"].append(f"分级失败：{tier_result['error']}")

    # 4. 报告
    pen_file = pen_result.get("output_path", "")
    risk_file = tier_result.get("output_path", "")
    basic_file = os.path.join(outdir, f"_tmp_{enterprise}_basic.json")
    with open(basic_file, "w", encoding="utf-8") as f:
        json.dump(basic_info, f, ensure_ascii=False)
    report_result = run_script("generate_dd_report.py", [
        "--enterprise", enterprise,
        "--basic-info", basic_file,
        "--penetration", pen_file,
        "--risks", risk_file,
        "--format", "md,html",
        "--outdir", os.path.join(outdir, "report")
    ])
    os.remove(basic_file) if os.path.exists(basic_file) else None

    # 5. dd-save
    save_data = {
        "basic_info": basic_info,
        "penetration": pen_result,
        "risks": tier_result,
        "report_paths": report_result.get("output_paths", [])
    }
    save_result = dd_save(base_url, enterprise, save_data)
    if save_result.get("errno", "0") != "0":
        result["errors"].append(f"dd-save 失败：{save_result.get('errmsg', '未知错误')}")

    result["status"] = "completed" if not result["errors"] else "completed_with_errors"
    result["report_paths"] = report_result.get("output_paths", [])
    result["risk_summary"] = tier_result.get("summary", {})
    return result


def main():
    parser = argparse.ArgumentParser(description="批量尽调任务编排")
    parser.add_argument("--enterprises", type=str, default="", help="企业名单（逗号分隔）")
    parser.add_argument("--enterprises-file", type=str, default="", help="企业名单文件（每行一个）")
    parser.add_argument("--scene", type=str, default="supplier",
                        choices=["supplier", "credit", "investment", "competitor", "related_risk"],
                        help="尽调场景")
    parser.add_argument("--outdir", type=str, default="output", help="输出根目录")
    args = parser.parse_args()

    base_url = os.environ.get("HOST_BASE_URL", "http://localhost:8080")
    mcp_alias = os.environ.get("MCP_ALIAS", "tianyancha")

    # 1. 名单校验
    enterprises_str = args.enterprises
    if args.enterprises_file:
        with open(args.enterprises_file, "r", encoding="utf-8") as f:
            enterprises_str = ",".join(line.strip() for line in f if line.strip())

    val_result = run_script("validate_enterprise_list.py", [
        "--input", enterprises_str, "--scene", args.scene
    ])

    if not val_result.get("valid", False):
        print(json.dumps({"error": val_result.get("error", "名单校验失败"), "validation": val_result},
                         ensure_ascii=False, indent=2))
        sys.exit(1)

    enterprises = val_result["enterprises"]
    if val_result.get("duplicates_removed"):
        print(f"去重：{', '.join(val_result['duplicates_removed'])}", file=sys.stderr)
    if val_result.get("invalid_entries"):
        print(f"无效条目：{json.dumps(val_result['invalid_entries'], ensure_ascii=False)}", file=sys.stderr)

    os.makedirs(args.outdir, exist_ok=True)

    # 2. 逐企业处理
    results: List[Dict] = []
    total = len(enterprises)
    for i, enterprise in enumerate(enterprises, 1):
        print(f"[{i}/{total}] 正在尽调：{enterprise} ...", file=sys.stderr)
        start_time = time.time()
        try:
            r = process_single_enterprise(enterprise, base_url, mcp_alias, args.scene, args.outdir)
        except Exception as e:
            r = {"enterprise": enterprise, "status": "failed", "errors": [str(e)]}
        r["duration_seconds"] = round(time.time() - start_time, 2)
        results.append(r)

        status_icon = {"completed": "✓", "completed_with_errors": "⚠", "failed": "✗"}.get(r["status"], "?")
        print(f"  {status_icon} {r['status']} ({r['duration_seconds']}s)", file=sys.stderr)

    # 3. 汇总
    completed = [r for r in results if r["status"] == "completed"]
    with_errors = [r for r in results if r["status"] == "completed_with_errors"]
    failed = [r for r in results if r["status"] == "failed"]

    summary = {
        "total": total,
        "completed": len(completed),
        "completed_with_errors": len(with_errors),
        "failed": len(failed),
        "failed_enterprises": [{"name": r["enterprise"], "errors": r.get("errors", [])} for r in failed],
        "scene": args.scene,
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "results": results
    }

    summary_path = os.path.join(args.outdir, "batch_summary.json")
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    print(json.dumps({
        "summary": {k: summary[k] for k in ("total", "completed", "completed_with_errors", "failed")},
        "summary_path": summary_path,
        "failed_enterprises": summary["failed_enterprises"]
    }, ensure_ascii=False, indent=2))

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()