#!/usr/bin/env node
/**
 * T7.1 验证 2b：直接调用天眼查 MCP - TypeScript 版本
 * 功能与 test_tianyancha_direct.py 完全一致
 * MCP 协议：JSON-RPC 2.0 over Streamable HTTP
 * 运行：node --experimental-strip-types scripts/test_tianyancha_direct.ts
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

type Dict = Record<string, any>;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const MCP_ENDPOINT = process.env.MCP_ENDPOINT ?? 'https://mcp.tianyancha.com/mcp';
let API_TOKEN = process.env.TIANYANCHA_MCP_TOKEN ?? '';
const ENTERPRISE = '腾讯科技（深圳）有限公司';
const BUSINESS_TOOLS = [
  'get_company_registration_info',
  'get_shareholder_info',
  'get_judicial_case',
];

if (!API_TOKEN) {
  const envPath = path.join(__dirname, '..', '..', '..', '..', '.env');
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, 'utf-8');
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (trimmed.startsWith('TIANYANCHA_MCP_TOKEN=')) {
        API_TOKEN = trimmed.substring(trimmed.indexOf('=') + 1);
        break;
      }
    }
  }
}

if (!API_TOKEN) {
  console.log('❌ 未找到 TIANYANCHA_MCP_TOKEN，请设置环境变量或在 .env 中配置');
  process.exit(1);
}

console.log(`[direct] MCP端点: ${MCP_ENDPOINT}`);
console.log(`[direct] Token: ${API_TOKEN.substring(0, 10)}...${API_TOKEN.substring(API_TOKEN.length - 4)}`);
console.log(`[direct] 企业: ${ENTERPRISE}`);
console.log(`[direct] 业务工具: ${BUSINESS_TOOLS}`);
console.log();

const headers: Dict = {
  'Content-Type': 'application/json',
  'Accept': 'application/json, text/event-stream',
  'Authorization': API_TOKEN,
};

let sessionId: string | null = null;
let reqId = 0;

function nextId(): number {
  return ++reqId;
}

class HttpError extends Error {
  httpCode: number;
  httpBody: string;
  constructor(code: number, body: string) {
    super(`HTTP ${code}: ${body}`);
    this.httpCode = code;
    this.httpBody = body;
  }
}

async function mcpPost(method: string, params?: any, isNotification = false): Promise<any> {
  const payload: Dict = { jsonrpc: '2.0', method };
  if (params !== undefined) payload.params = params;
  if (!isNotification) payload.id = nextId();

  const reqHeaders: Dict = { ...headers };
  if (sessionId) reqHeaders['Mcp-Session-Id'] = sessionId;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    const resp = await fetch(MCP_ENDPOINT, {
      method: 'POST',
      headers: reqHeaders,
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    const sid = resp.headers.get('Mcp-Session-Id') || resp.headers.get('mcp-session-id');
    if (sid && !sessionId) {
      sessionId = sid;
      console.log(`[direct] 获取 Session ID: ${sid.substring(0, 20)}...`);
    }

    const raw = await resp.text();
    if (!resp.ok) {
      console.log(`  HTTP ${resp.status}: ${raw.substring(0, 500)}`);
      return null;
    }

    const contentType = resp.headers.get('Content-Type') || '';

    if (contentType.includes('text/event-stream')) {
      for (const line of raw.split('\n')) {
        const trimmed = line.trim();
        if (trimmed.startsWith('data:')) {
          const data = trimmed.slice(5).trim();
          if (data) return JSON.parse(data);
        }
      }
      return null;
    } else {
      if (raw.trim()) return JSON.parse(raw);
      return {};
    }
  } catch (e: any) {
    if (e.name === 'AbortError') {
      console.log('  异常: 请求超时');
    } else {
      console.log(`  异常: ${e}`);
    }
    return null;
  }
}

async function main(): Promise<void> {
  // Step 1: initialize
  console.log('--- Step 1: MCP initialize ---');
  const result = await mcpPost('initialize', {
    protocolVersion: '2025-03-26',
    capabilities: {},
    clientInfo: { name: 'Node.js Direct Test', version: '1.0' }
  });
  if (result === null) {
    console.log('❌ initialize 失败');
    process.exit(1);
  }

  const proto = result?.result?.protocolVersion ?? '?';
  console.log(`  protocolVersion: ${proto}`);
  console.log(`  serverInfo: ${JSON.stringify(result?.result?.serverInfo ?? {})}`);

  // Step 2: notifications/initialized
  console.log('\n--- Step 2: notifications/initialized ---');
  await mcpPost('notifications/initialized', undefined, true);
  console.log('  已发送');

  // Step 3: call_tool 代理调用业务工具
  console.log(`\n--- Step 3: call_tool 代理调用 ${BUSINESS_TOOLS.length} 个业务工具 ---`);
  const results: Dict = {};

  for (const bizTool of BUSINESS_TOOLS) {
    console.log(`\n  → ${bizTool}`);
    const res = await mcpPost('tools/call', {
      name: 'call_tool',
      arguments: {
        company_name: ENTERPRISE,
        tool_name: bizTool,
        page: 1,
        page_size: 20,
      }
    });

    if (res === null) {
      results[bizTool] = { ok: false, error: '无响应' };
      console.log('    ❌ 无响应');
      continue;
    }

    if (res.error) {
      const err = res.error;
      results[bizTool] = { ok: false, error: `${err.code ?? '?'}: ${err.message ?? '?'}` };
      console.log(`    ❌ MCP错误: ${err.code}: ${(err.message ?? '').substring(0, 200)}`);
      continue;
    }

    const content = res?.result?.content ?? [];
    const isError = res?.result?.isError ?? false;

    if (content.length > 0) {
      const textParts: string[] = [];
      for (const item of content) {
        if (item.type === 'text') textParts.push(item.text ?? '');
      }
      const fullText = textParts.join('\n');
      console.log(`    ${isError ? '❌ isError' : '✅ 成功'}, 内容长度: ${fullText.length} 字符`);
      if (fullText) {
        console.log(`    前300字符: ${fullText.substring(0, 300)}`);
      }
      results[bizTool] = { ok: !isError, data_len: fullText.length, is_error: isError };
    } else {
      results[bizTool] = { ok: false, error: '空内容' };
      console.log('    ❌ 空内容');
    }
  }

  // 汇总
  console.log('\n' + '='.repeat(60));
  console.log('验收检查：');
  for (const tool of BUSINESS_TOOLS) {
    const r: Dict = results[tool] ?? {};
    const icon = r.ok ? '✅' : '❌';
    const detail = r.ok ? `data=${r.data_len ?? '?'}字符` : (r.error ?? '?');
    console.log(`  ${icon} ${tool}: ${detail}`);
  }

  const successCount = Object.values(results).filter((r: any) => r.ok).length;
  console.log(`\n成功: ${successCount}/${BUSINESS_TOOLS.length}`);

  if (successCount >= 3) {
    console.log('✅ 天眼查 MCP 连通性验证通过（Node.js 直连，3个工具全部成功）');
  } else if (successCount >= 1) {
    console.log('⚠ 部分工具调用成功');
  } else {
    console.log('❌ 天眼查 MCP 连通性验证失败');
    process.exit(1);
  }
}

main();