#!/usr/bin/env python3
"""
T7.1 全链路验证：Python 直连天眼查 MCP + 串联穿透/分级/报告
绕过仓颉 http_lib chunked bug，全流程用 Python 完成。
所有调用日志保存到 log/ 目录，用作赛事提交资料。

用法：
  python scripts/run_dd_pipeline.py --enterprise "腾讯科技（深圳）有限公司" --scene supplier --outdir output
"""
import argparse
import json
import urllib.request
import urllib.error
import subprocess
import sys
import os
import re
from datetime import datetime

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
RUNTIME_DIR = os.path.dirname(os.path.dirname(os.path.dirname(SCRIPTS_DIR)))
LOG_DIR = os.path.join(os.path.dirname(SCRIPTS_DIR), "log")

MCP_ENDPOINT = "https://mcp.tianyancha.com/mcp"

BUSINESS_TOOLS = [
    "get_company_registration_info",
    "get_risk_overview",

]


def load_token():
    env_path = os.path.join(RUNTIME_DIR, ".env")
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("TIANYANCHA_MCP_TOKEN="):
                    return line.split("=", 1)[1]
    return os.environ.get("TIANYANCHA_MCP_TOKEN", "")


# ── 日志记录 ──────────────────────────────────────────────────
LOG_ENTRIES = []

def log(step, action, detail, status="info", extra=None):
    entry = {
        "timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f+08:00"),
        "step": step,
        "action": action,
        "detail": detail,
        "status": status,
    }
    if extra:
        entry["extra"] = extra
    LOG_ENTRIES.append(entry)
    print(f"  [{step}] {action}: {detail}")


def save_log(enterprise):
    os.makedirs(LOG_DIR, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_name = re.sub(r'[^\w]', '_', enterprise)
    log_path = os.path.join(LOG_DIR, f"dd_pipeline_{safe_name}_{ts}.json")
    with open(log_path, "w", encoding="utf-8") as f:
        json.dump({
            "enterprise": enterprise,
            "log_entries": LOG_ENTRIES,
            "summary": {
                "total_entries": len(LOG_ENTRIES),
                "mcp_calls": sum(1 for e in LOG_ENTRIES if e["step"] == "mcp"),
                "script_calls": sum(1 for e in LOG_ENTRIES if e["step"] == "script"),
                "success_count": sum(1 for e in LOG_ENTRIES if e["status"] == "success"),
                "error_count": sum(1 for e in LOG_ENTRIES if e["status"] == "error"),
            }
        }, f, ensure_ascii=False, indent=2)
    print(f"\n日志已保存: {log_path}")
    return log_path


# ── 天眼查 MCP 客户端 ────────────────────────────────────────
class TianyanchaMCP:
    def __init__(self, token):
        self.token = token
        self.session_id = None
        self.req_id = 0
        self.headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Authorization": token,
        }

    def _next_id(self):
        self.req_id += 1
        return self.req_id

    def _post(self, method, params=None, is_notification=False):
        payload = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            payload["params"] = params
        if not is_notification:
            payload["id"] = self._next_id()

        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(MCP_ENDPOINT, data=body, method="POST")
        for k, v in self.headers.items():
            req.add_header(k, v)
        if self.session_id:
            req.add_header("Mcp-Session-Id", self.session_id)

        with urllib.request.urlopen(req, timeout=60) as resp:
            sid = resp.headers.get("Mcp-Session-Id") or resp.headers.get("mcp-session-id")
            if sid and not self.session_id:
                self.session_id = sid
            raw = resp.read().decode("utf-8")
            content_type = resp.headers.get("Content-Type", "")

            if "text/event-stream" in content_type:
                for line in raw.split("\n"):
                    line = line.strip()
                    if line.startswith("data:"):
                        data = line[5:].strip()
                        if data:
                            return json.loads(data)
                return None
            else:
                return json.loads(raw) if raw.strip() else {}

    def initialize(self):
        result = self._post("initialize", {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "DD Pipeline", "version": "1.0"}
        })
        proto = result.get("result", {}).get("protocolVersion", "?")
        server_info = result.get("result", {}).get("serverInfo", {})
        log("mcp", "initialize", f"protocolVersion={proto}, server={server_info.get('name', '?')}, session={self.session_id[:20] if self.session_id else 'N/A'}...", "success")
        self._post("notifications/initialized", is_notification=True)
        log("mcp", "notifications/initialized", "已发送", "success")

    def call_tool(self, company_name, tool_name):
        log("mcp", "call_tool", f"company={company_name}, tool={tool_name}")
        try:
            result = self._post("tools/call", {
                "name": "call_tool",
                "arguments": {
                    "company_name": company_name,
                    "tool_name": tool_name,
                    "page": 1,
                    "page_size": 20,
                }
            })
            if result is None:
                log("mcp", "call_tool_result", f"tool={tool_name}: 无响应", "error")
                return {"ok": False, "error": "无响应"}
            if "error" in result:
                err = result["error"]
                err_msg = f"{err.get('code')}: {err.get('message', '')}"
                log("mcp", "call_tool_result", f"tool={tool_name}: {err_msg[:300]}", "error", {"full_error": err})
                return {"ok": False, "error": err_msg}

            content = result.get("result", {}).get("content", [])
            is_error = result.get("result", {}).get("isError", False)
            text_parts = [item.get("text", "") for item in content if item.get("type") == "text"]
            full_text = "\n".join(text_parts)
            log("mcp", "call_tool_result", f"tool={tool_name}: {'isError' if is_error else 'success'}, {len(full_text)} 字符", "success" if not is_error else "error", {"data_preview": full_text[:500]})
            return {"ok": not is_error, "text": full_text, "is_error": is_error}
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            log("mcp", "call_tool_result", f"tool={tool_name}: HTTP {e.code}: {body[:300]}", "error", {"http_code": e.code, "body": body[:1000]})
            return {"ok": False, "error": f"HTTP {e.code}: {body[:200]}"}
        except Exception as e:
            log("mcp", "call_tool_result", f"tool={tool_name}: {e}", "error")
            return {"ok": False, "error": str(e)}

    def close(self):
        log("mcp", "close", "MCP 会话关闭", "success")


# ── 辅助函数 ──────────────────────────────────────────────────
def parse_basic_info(markdown_text, enterprise_name):
    info = {"enterprise_name": enterprise_name, "data_source": "tianyancha"}
    patterns = {
        "credit_code": r"统一社会信用代码\s*\|\s*([^\|]+)\s*\|",
        "legal_representative": r"法定代表人\s*\|\s*([^\|]+)\s*\|",
        "registered_capital": r"注册资本\s*\|\s*([^\|]+)\s*\|",
        "registration_status": r"登[记记]状态\s*\|\s*([^\|]+)\s*\|",
        "business_scope": r"经营范围\s*\|\s*([^\|]+)",
    }
    for key, pattern in patterns.items():
        m = re.search(pattern, markdown_text)
        if m:
            info[key] = m.group(1).strip()
    return info


def run_script(script_name, args):
    script_path = os.path.join(SCRIPTS_DIR, script_name)
    cmd = [sys.executable, script_path] + args
    log("script", "run", f"{script_name} {' '.join(args)}")
    try:
        env = dict(os.environ)
        env["PYTHONIOENCODING"] = "utf-8"
        result = subprocess.run(cmd, capture_output=True, timeout=120, env=env)
        stdout = result.stdout.decode("utf-8", errors="replace") if result.stdout else ""
        stderr = result.stderr.decode("utf-8", errors="replace") if result.stderr else ""
        if result.returncode == 0:
            parsed = json.loads(stdout) if stdout.strip() else {}
            log("script", "result", f"{script_name}: returncode=0, stdout={len(stdout)} 字符", "success", {"stdout_preview": stdout[:500]})
            return parsed
        else:
            log("script", "result", f"{script_name}: returncode={result.returncode}, stderr={stderr[:300]}", "error", {"stderr": stderr[:1000]})
            return {"error": stderr or stdout}
    except Exception as e:
        log("script", "result", f"{script_name}: 异常 {e}", "error")
        return {"error": str(e)}


# ── 主流程 ────────────────────────────────────────────────────
def process_enterprise(enterprise, mcp, outdir, scene):
    result = {"enterprise": enterprise, "status": "processing", "errors": [], "steps": {}}
    os.makedirs(outdir, exist_ok=True)

    # Step 1: 数据采集
    print(f"\n  [1/5] 数据采集（天眼查 MCP）...")
    fetch_data = {}
    mcp_logs = []
    for tool in BUSINESS_TOOLS:
        print(f"    → {tool}", end="")
        r = mcp.call_tool(enterprise, tool)
        if r["ok"]:
            print(f" ✅ ({len(r['text'])} 字符)")
            fetch_data[tool] = r["text"]
            mcp_logs.append({"tool": tool, "status": "success", "len": len(r["text"])})
        else:
            print(f" ❌ {r.get('error', '?')[:120]}")
            fetch_data[tool] = ""
            mcp_logs.append({"tool": tool, "status": "failed", "error": r.get("error", "?")})
    result["steps"]["fetch"] = mcp_logs

    # 保存采集的原始数据
    fetch_dir = os.path.join(outdir, "fetched")
    os.makedirs(fetch_dir, exist_ok=True)
    for tool, text in fetch_data.items():
        if text:
            with open(os.path.join(fetch_dir, f"{tool}.md"), "w", encoding="utf-8") as f:
                f.write(text)

    # 解析基础信息
    basic_info = parse_basic_info(fetch_data.get("get_company_registration_info", ""), enterprise)
    basic_file = os.path.join(outdir, f"{enterprise}_basic.json")
    with open(basic_file, "w", encoding="utf-8") as f:
        json.dump(basic_info, f, ensure_ascii=False, indent=2)

    # Step 2: 股权穿透
    print(f"  [2/5] 股权穿透...")
    equity_data = {"enterprise_name": enterprise, "shareholders": [], "source": "tianyancha_free"}
    equity_file = os.path.join(outdir, f"{enterprise}_equity.json")
    with open(equity_file, "w", encoding="utf-8") as f:
        json.dump(equity_data, f, ensure_ascii=False, indent=2)

    pen_result = run_script("penetrate_equity.py", [
        "--input", equity_file, "--enterprise", enterprise,
        "--outdir", os.path.join(outdir, "penetration")
    ])
    if "error" in pen_result:
        result["errors"].append(f"穿透: {pen_result['error'][:100]}")
        print(f"    ⚠ {pen_result['error'][:80]}")
    else:
        print(f"    ✅ 穿透完成")
    result["steps"]["penetrate"] = pen_result

    # Step 3: 风险分级
    print(f"  [3/5] 风险分级...")
    risk_md = fetch_data.get("get_risk_overview", "")
    risk_data = {"risk_overview_md": risk_md, "judicial_cases": [], "admin_penalties": [], "operation_anomalies": []}
    risk_file = os.path.join(outdir, f"{enterprise}_risk.json")
    with open(risk_file, "w", encoding="utf-8") as f:
        json.dump(risk_data, f, ensure_ascii=False, indent=2)

    tier_result = run_script("tier_risks.py", [
        "--input", risk_file, "--enterprise", enterprise,
        "--outdir", os.path.join(outdir, "risks")
    ])
    if "error" in tier_result:
        result["errors"].append(f"分级: {tier_result['error'][:100]}")
        print(f"    ⚠ {tier_result['error'][:80]}")
    else:
        print(f"    ✅ 分级完成")
    result["steps"]["tier"] = tier_result

    # Step 4: 报告生成
    print(f"  [4/5] 报告生成...")
    pen_json = pen_result.get("output_path", "")
    risk_json = tier_result.get("output_path", "")
    report_args = [
        "--enterprise", enterprise,
        "--basic-info", basic_file,
        "--format", "md,html",
        "--outdir", os.path.join(outdir, "report"),
    ]
    if pen_json and os.path.exists(pen_json):
        report_args += ["--penetration", pen_json]
    if risk_json and os.path.exists(risk_json):
        report_args += ["--risks", risk_json]
    report_result = run_script("generate_dd_report.py", report_args)
    if "error" in report_result:
        result["errors"].append(f"报告: {report_result['error'][:100]}")
        print(f"    ⚠ {report_result['error'][:80]}")
    else:
        paths = report_result.get("output_paths", [])
        print(f"    ✅ 报告生成: {len(paths)} 个文件")
        for p in paths:
            print(f"       - {p}")
    result["steps"]["report"] = report_result

    # Step 5: 汇总
    print(f"  [5/5] 汇总...")
    result["status"] = "completed" if not result["errors"] else "completed_with_errors"
    result["report_paths"] = report_result.get("output_paths", [])
    result["basic_info"] = basic_info
    log("pipeline", "complete", f"status={result['status']}, errors={len(result['errors'])}", result["status"])
    return result


def main():
    parser = argparse.ArgumentParser(description="尽调全链路（Python 直连天眼查 MCP）")
    parser.add_argument("--enterprise", type=str, default="腾讯科技（深圳）有限公司")
    parser.add_argument("--scene", type=str, default="supplier")
    parser.add_argument("--outdir", type=str, default="output")
    args = parser.parse_args()

    token = load_token()
    if not token:
        print("❌ 未找到 TIANYANCHA_MCP_TOKEN")
        sys.exit(1)

    print(f"=== 尽调全链路 ===")
    print(f"企业: {args.enterprise}")
    print(f"场景: {args.scene}")
    print(f"输出: {args.outdir}")
    print(f"日志: {LOG_DIR}")
    print(f"\n--- MCP 初始化 ---")
    mcp = TianyanchaMCP(token)
    mcp.initialize()

    print(f"\n--- 处理企业: {args.enterprise} ---")
    result = process_enterprise(args.enterprise, mcp, args.outdir, args.scene)

    summary_path = os.path.join(args.outdir, "pipeline_result.json")
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"\n{'=' * 60}")
    print(f"状态: {result['status']}")
    print(f"基础信息: {result.get('basic_info', {})}")
    print(f"报告文件: {result.get('report_paths', [])}")
    if result["errors"]:
        print(f"错误: {result['errors']}")
    print(f"结果已保存: {summary_path}")

    mcp.close()
    log_path = save_log(args.enterprise)
    print(f"日志已保存: {log_path}")


if __name__ == "__main__":
    main()
