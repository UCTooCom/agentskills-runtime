#!/usr/bin/env node
/**
 * T7.1 验证 2：调用宿主 McpOpenController 验证天眼查 MCP 连通性 - TypeScript 版本
 * 功能与 test_dd_fetch.py 完全一致
 * 运行：node --experimental-strip-types scripts/test_dd_fetch.ts
 */
type Dict = Record<string, any>;

const HOST = process.env.HOST_BASE_URL ?? 'https://javatoarktsapi.uctoo.com';
const ACCESS_TOKEN = process.env.ACCESS_TOKEN ?? 'ewogICJhbGciOiAiSFMyNTYiLAogICJ0eXAiOiAiSldUIgp9.ewogICJ1c2VyIjogIjUwNWNmOTA5LTVlMGUtNGRkZS1iMjE1LTc0Mjc0ZDJjYzU0OCIsCiAgInNlc3Npb24iOiAiMmU5Y2E5ZjUtNzc0Ny00MjM2LTg4MGQtOTdlOWJlZDhmZjlhIiwKICAiaWF0IjogMTc4ODkzMzM1NCwKICAiZXhwIjogMTc5MDY2MTM1NAp9.dLatqZm9Copbh9K73shL0y7yeaIb4sZQ18ABN8WdQts';

const ENTERPRISE = '腾讯科技（深圳）有限公司';
const MCP_ALIAS = 'tianyancha';
const API_PATH = '/api/v1/uctoo/mcp/open/call';

const BUSINESS_TOOLS = [
  'get_company_registration_info',
  'get_shareholder_info',
  'get_judicial_case',
];

class HttpError extends Error {
  httpCode: number;
  httpBody: string;
  constructor(code: number, body: string) {
    super(`HTTP ${code}: ${body}`);
    this.httpCode = code;
    this.httpBody = body;
  }
}

async function callMcp(toolName: string, args: Dict): Promise<[number, string]> {
  const body = JSON.stringify({
    mcpAlias: MCP_ALIAS,
    tool: toolName,
    arguments: args
  });

  const url = `${HOST.replace(/\/$/, '')}${API_PATH}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 120000);
  try {
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${ACCESS_TOKEN}`,
      },
      body,
      signal: controller.signal,
    });
    clearTimeout(timeout);
    const raw = await resp.text();
    if (!resp.ok) {
      throw new HttpError(resp.status, raw);
    }
    return [resp.status, raw];
  } catch (e) {
    clearTimeout(timeout);
    throw e;
  }
}

async function main(): Promise<void> {
  console.log(`[test_dd_fetch] HOST: ${HOST}`);
  console.log(`[test_dd_fetch] 端点: POST ${API_PATH}`);
  console.log(`[test_dd_fetch] 企业: ${ENTERPRISE}`);
  console.log(`[test_dd_fetch] MCP别名: ${MCP_ALIAS}`);
  console.log(`[test_dd_fetch] 业务工具: ${BUSINESS_TOOLS}`);
  console.log(`[test_dd_fetch] 调用方式: call_tool 代理（MCP默认17个公开工具，业务工具需代理）`);
  console.log(`[test_dd_fetch] 等待宿主响应...\n`);

  const results: Dict = {};

  for (const bizTool of BUSINESS_TOOLS) {
    console.log(`--- call_tool → ${bizTool} ---`);
    try {
      const args = {
        company_name: ENTERPRISE,
        tool_name: bizTool,
        page: 1,
        page_size: 20,
      };
      const [status, raw] = await callMcp('call_tool', args);
      console.log(`HTTP ${status}`);
      let data: Dict;
      try {
        data = JSON.parse(raw);
      } catch {
        console.log(`响应非JSON，前300字符：\n${raw.substring(0, 300)}`);
        results[bizTool] = { ok: false, error: 'non-JSON response' };
        continue;
      }

      const errno = data.errno ?? 'N/A';
      const errmsg: string = data.errmsg ?? '';
      const meta: Dict = data.meta ?? {};

      if (errno === '0') {
        console.log(`  errno=0, status=${meta.status ?? '?'}, duration=${meta.durationMs ?? '?'}ms`);
        const dataStr: string = data.data ?? '';
        console.log(`  data长度: ${dataStr.length} 字符`);
        if (dataStr.length > 0) {
          console.log(`  data前300字符: ${dataStr.substring(0, 300)}`);
        }
        results[bizTool] = { ok: true, data_len: dataStr.length };
      } else {
        console.log(`  ❌ errno=${errno}, errmsg=${errmsg}`);
        console.log(`  meta: ${JSON.stringify(meta)}`);
        results[bizTool] = { ok: false, errno, errmsg };
      }
    } catch (e: any) {
      if (e instanceof HttpError) {
        console.log(`  ❌ HTTP错误 ${e.httpCode}: ${e.httpBody.substring(0, 300)}`);
        results[bizTool] = { ok: false, error: `HTTP ${e.httpCode}` };
      } else {
        console.log(`  ❌ 异常: ${e}`);
        results[bizTool] = { ok: false, error: String(e) };
      }
    }
    console.log();
  }

  console.log('='.repeat(60));
  console.log('验收检查：');
  for (const tool of BUSINESS_TOOLS) {
    const r: Dict = results[tool] ?? {};
    const icon = r.ok ? '✅' : '❌';
    const detail = r.ok ? `data=${r.data_len ?? '?'}字符` : (r.errmsg ?? r.error ?? '?');
    console.log(`  ${icon} ${tool}: ${detail}`);
  }

  const successCount = Object.values(results).filter((r: any) => r.ok).length;
  console.log(`\n成功: ${successCount}/${BUSINESS_TOOLS.length}`);

  if (successCount >= 3) {
    console.log('✅ 天眼查 MCP 连通性验证通过（3个工具全部成功）');
  } else if (successCount >= 1) {
    console.log('⚠ 部分工具调用成功，天眼查 MCP 连通但部分工具可能有问题');
  } else {
    console.log('❌ 天眼查 MCP 连通性验证失败（所有工具调用失败）');
    process.exit(1);
  }
}

main();