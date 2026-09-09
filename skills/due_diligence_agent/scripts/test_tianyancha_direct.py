#!/usr/bin/env python3
"""
T7.1 验证 2b：直接调用天眼查 MCP（Python 原生，绕过仓颉 http_lib chunked bug）
MCP 协议：JSON-RPC 2.0 over Streamable HTTP
1. POST initialize → 获取 session
2. POST notifications/initialized → 完成握手
3. POST tools/call (call_tool 代理) → 获取业务数据
用法：python scripts/test_tianyancha_direct.py
"""
import json
import urllib.request
import urllib.error
import sys
import os

MCP_ENDPOINT = os.environ.get("MCP_ENDPOINT", "https://mcp.tianyancha.com/mcp")
API_TOKEN = os.environ.get("TIANYANCHA_MCP_TOKEN", "")
ENTERPRISE = "腾讯科技（深圳）有限公司"
BUSINESS_TOOLS = [
    "get_company_registration_info",
    "get_shareholder_info",
    "get_judicial_case",
]

if not API_TOKEN:
    env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), ".env")
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("TIANYANCHA_MCP_TOKEN="):
                    API_TOKEN = line.split("=", 1)[1]
                    break

if not API_TOKEN:
    print("❌ 未找到 TIANYANCHA_MCP_TOKEN，请设置环境变量或在 .env 中配置")
    sys.exit(1)

print(f"[direct] MCP端点: {MCP_ENDPOINT}")
print(f"[direct] Token: {API_TOKEN[:10]}...{API_TOKEN[-4:]}")
print(f"[direct] 企业: {ENTERPRISE}")
print(f"[direct] 业务工具: {BUSINESS_TOOLS}")
print()

headers = {
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
    "Authorization": API_TOKEN,
}

session_id = None
req_id = 0


def next_id():
    global req_id
    req_id += 1
    return req_id


def mcp_post(method, params=None, is_notification=False):
    global session_id
    payload = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        payload["params"] = params
    if not is_notification:
        payload["id"] = next_id()

    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(MCP_ENDPOINT, data=body, method="POST")
    for k, v in headers.items():
        req.add_header(k, v)
    if session_id:
        req.add_header("Mcp-Session-Id", session_id)

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            sid = resp.headers.get("Mcp-Session-Id") or resp.headers.get("mcp-session-id")
            if sid and not session_id:
                session_id = sid
                print(f"[direct] 获取 Session ID: {sid[:20]}...")

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
                if raw.strip():
                    return json.loads(raw)
                return {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"  HTTP {e.code}: {body[:500]}")
        return None
    except Exception as e:
        print(f"  异常: {e}")
        return None


# Step 1: initialize
print("--- Step 1: MCP initialize ---")
result = mcp_post("initialize", {
    "protocolVersion": "2025-03-26",
    "capabilities": {},
    "clientInfo": {"name": "Python Direct Test", "version": "1.0"}
})
if result is None:
    print("❌ initialize 失败")
    sys.exit(1)

proto = result.get("result", {}).get("protocolVersion", "?")
print(f"  protocolVersion: {proto}")
print(f"  serverInfo: {result.get('result', {}).get('serverInfo', {})}")

# Step 2: notifications/initialized
print("\n--- Step 2: notifications/initialized ---")
mcp_post("notifications/initialized", is_notification=True)
print("  已发送")

# Step 3: call_tool 代理调用业务工具
print(f"\n--- Step 3: call_tool 代理调用 {len(BUSINESS_TOOLS)} 个业务工具 ---")
results = {}

for biz_tool in BUSINESS_TOOLS:
    print(f"\n  → {biz_tool}")
    result = mcp_post("tools/call", {
        "name": "call_tool",
        "arguments": {
            "company_name": ENTERPRISE,
            "tool_name": biz_tool,
            "page": 1,
            "page_size": 20,
        }
    })

    if result is None:
        results[biz_tool] = {"ok": False, "error": "无响应"}
        print(f"    ❌ 无响应")
        continue

    if "error" in result:
        err = result["error"]
        results[biz_tool] = {"ok": False, "error": f"{err.get('code', '?')}: {err.get('message', '?')}"}
        print(f"    ❌ MCP错误: {err.get('code')}: {err.get('message', '')[:200]}")
        continue

    content = result.get("result", {}).get("content", [])
    is_error = result.get("result", {}).get("isError", False)

    if content:
        text_parts = []
        for item in content:
            if item.get("type") == "text":
                text_parts.append(item.get("text", ""))
        full_text = "\n".join(text_parts)
        print(f"    {'❌ isError' if is_error else '✅ 成功'}, 内容长度: {len(full_text)} 字符")
        if full_text:
            print(f"    前300字符: {full_text[:300]}")
        results[biz_tool] = {"ok": not is_error, "data_len": len(full_text), "is_error": is_error}
    else:
        results[biz_tool] = {"ok": False, "error": "空内容"}
        print(f"    ❌ 空内容")

# 汇总
print("\n" + "=" * 60)
print("验收检查：")
for tool in BUSINESS_TOOLS:
    r = results.get(tool, {})
    icon = "✅" if r.get("ok") else "❌"
    detail = f"data={r.get('data_len', '?')}字符" if r.get("ok") else r.get("error", "?")
    print(f"  {icon} {tool}: {detail}")

success_count = sum(1 for r in results.values() if r.get("ok"))
print(f"\n成功: {success_count}/{len(BUSINESS_TOOLS)}")

if success_count >= 3:
    print("✅ 天眼查 MCP 连通性验证通过（Python 直连，3个工具全部成功）")
elif success_count >= 1:
    print("⚠ 部分工具调用成功")
else:
    print("❌ 天眼查 MCP 连通性验证失败")
    sys.exit(1)