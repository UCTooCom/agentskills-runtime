#!/usr/bin/env python3
"""
T7.1 验证 2：调用宿主 McpOpenController 验证天眼查 MCP 连通性
端点：POST /api/v1/uctoo/mcp/open/call（宿主直接注册）
方式：通过 call_tool 代理调用天眼查业务工具（MCP默认只公开17个工具，162个业务能力需经 call_tool 代理）
用法：python scripts/test_dd_fetch.py
"""
import json
import urllib.request
import urllib.error
import sys
import os

HOST = os.environ.get("HOST_BASE_URL", "https://javatoarktsapi.uctoo.com")
ACCESS_TOKEN = os.environ.get("ACCESS_TOKEN", "ewogICJhbGciOiAiSFMyNTYiLAogICJ0eXAiOiAiSldUIgp9.ewogICJ1c2VyIjogIjUwNWNmOTA5LTVlMGUtNGRkZS1iMjE1LTc0Mjc0ZDJjYzU0OCIsCiAgInNlc3Npb24iOiAiMmU5Y2E5ZjUtNzc0Ny00MjM2LTg4MGQtOTdlOWJlZDhmZjlhIiwKICAiaWF0IjogMTc4ODkzMzM1NCwKICAiZXhwIjogMTc5MDY2MTM1NAp9.dLatqZm9Copbh9K73shL0y7yeaIb4sZQ18ABN8WdQts")

ENTERPRISE = "腾讯科技（深圳）有限公司"
MCP_ALIAS = "tianyancha"
PATH = "/api/v1/uctoo/mcp/open/call"

# 天眼查 MCP 业务工具名（非CLI命令名），需通过 call_tool 代理调用
BUSINESS_TOOLS = [
    "get_company_registration_info",
    "get_shareholder_info",
    "get_judicial_case",
]


def call_mcp(tool_name, arguments):
    body = json.dumps({
        "mcpAlias": MCP_ALIAS,
        "tool": tool_name,
        "arguments": arguments
    }, ensure_ascii=False).encode("utf-8")

    url = f"{HOST.rstrip('/')}{PATH}"
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {ACCESS_TOKEN}")

    with urllib.request.urlopen(req, timeout=120) as resp:
        status = resp.getcode()
        raw = resp.read().decode("utf-8")
        return status, raw


print(f"[test_dd_fetch] HOST: {HOST}")
print(f"[test_dd_fetch] 端点: POST {PATH}")
print(f"[test_dd_fetch] 企业: {ENTERPRISE}")
print(f"[test_dd_fetch] MCP别名: {MCP_ALIAS}")
print(f"[test_dd_fetch] 业务工具: {BUSINESS_TOOLS}")
print(f"[test_dd_fetch] 调用方式: call_tool 代理（MCP默认17个公开工具，业务工具需代理）")
print(f"[test_dd_fetch] 等待宿主响应...\n")

results = {}

for biz_tool in BUSINESS_TOOLS:
    print(f"--- call_tool → {biz_tool} ---")
    try:
        arguments = {
            "company_name": ENTERPRISE,
            "tool_name": biz_tool,
            "page": 1,
            "page_size": 20,
        }
        status, raw = call_mcp("call_tool", arguments)
        print(f"HTTP {status}")
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            print(f"响应非JSON，前300字符：\n{raw[:300]}")
            results[biz_tool] = {"ok": False, "error": "non-JSON response"}
            continue

        errno = data.get("errno", "N/A")
        errmsg = data.get("errmsg", "")
        meta = data.get("meta", {})

        if errno == "0":
            print(f"  errno=0, status={meta.get('status', '?')}, duration={meta.get('durationMs', '?')}ms")
            data_str = data.get("data", "")
            print(f"  data长度: {len(data_str)} 字符")
            if len(data_str) > 0:
                print(f"  data前300字符: {data_str[:300]}")
            results[biz_tool] = {"ok": True, "data_len": len(data_str)}
        else:
            print(f"  ❌ errno={errno}, errmsg={errmsg}")
            print(f"  meta: {json.dumps(meta, ensure_ascii=False)}")
            results[biz_tool] = {"ok": False, "errno": errno, "errmsg": errmsg}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:300]
        print(f"  ❌ HTTP错误 {e.code}: {body}")
        results[biz_tool] = {"ok": False, "error": f"HTTP {e.code}"}
    except Exception as e:
        print(f"  ❌ 异常: {e}")
        results[biz_tool] = {"ok": False, "error": str(e)}
    print()

print("=" * 60)
print("验收检查：")
for tool in BUSINESS_TOOLS:
    r = results.get(tool, {})
    icon = "✅" if r.get("ok") else "❌"
    detail = f"data={r.get('data_len', '?')}字符" if r.get("ok") else r.get("errmsg", r.get("error", "?"))
    print(f"  {icon} {tool}: {detail}")

success_count = sum(1 for r in results.values() if r.get("ok"))
print(f"\n成功: {success_count}/{len(BUSINESS_TOOLS)}")

if success_count >= 3:
    print("✅ 天眼查 MCP 连通性验证通过（3个工具全部成功）")
elif success_count >= 1:
    print("⚠ 部分工具调用成功，天眼查 MCP 连通但部分工具可能有问题")
else:
    print("❌ 天眼查 MCP 连通性验证失败（所有工具调用失败）")
    sys.exit(1)
