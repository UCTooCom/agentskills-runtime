#!/usr/bin/env node
/**
 * T7.1 全链路验证：Node.js 直连天眼查 MCP + 串联穿透/分级/报告 - TypeScript 版本
 * 功能与 run_dd_pipeline.py 完全一致
 * 运行：node --experimental-strip-types scripts/run_dd_pipeline.ts [参数]
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

type Dict = Record<string, any>;

const __filename = fileURLToPath(import.meta.url);
const SCRIPTS_DIR = path.dirname(__filename);
const RUNTIME_DIR = path.dirname(path.dirname(path.dirname(SCRIPTS_DIR)));
const LOG_DIR = path.join(path.dirname(SCRIPTS_DIR), 'log');

const MCP_ENDPOINT = 'https://mcp.tianyancha.com/mcp';

const BUSINESS_TOOLS = [
  'get_company_registration_info',
  'get_risk_overview',
];

function formatDateTime(d: Date): string {
  const pad = (n: number, len = 2) => String(n).padStart(len, '0');
  const us = pad(d.getMilliseconds(), 3) + '000';
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.${us}+08:00`;
}

function formatDateTimeFile(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function loadToken(): string {
  const envPath = path.join(RUNTIME_DIR, '.env');
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, 'utf-8');
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (trimmed.startsWith('TIANYANCHA_MCP_TOKEN=')) {
        return trimmed.substring(trimmed.indexOf('=') + 1);
      }
    }
  }
  return process.env.TIANYANCHA_MCP_TOKEN ?? '';
}

// ── 日志记录 ──────────────────────────────────────────────────
const LOG_ENTRIES: any[] = [];

function log(step: string, action: string, detail: string, status: string = 'info', extra?: any): void {
  const entry: Dict = {
    timestamp: formatDateTime(new Date()),
    step,
    action,
    detail,
    status,
  };
  if (extra) entry.extra = extra;
  LOG_ENTRIES.push(entry);
  console.log(`  [${step}] ${action}: ${detail}`);
}

function saveLog(enterprise: string): string {
  fs.mkdirSync(LOG_DIR, { recursive: true });
  const ts = formatDateTimeFile(new Date());
  const safeName = enterprise.replace(/[^\p{L}\p{N}_]/gu, '_');
  const logPath = path.join(LOG_DIR, `dd_pipeline_${safeName}_${ts}.json`);
  fs.writeFileSync(logPath, JSON.stringify({
    enterprise,
    log_entries: LOG_ENTRIES,
    summary: {
      total_entries: LOG_ENTRIES.length,
      mcp_calls: LOG_ENTRIES.filter((e: Dict) => e.step === 'mcp').length,
      script_calls: LOG_ENTRIES.filter((e: Dict) => e.step === 'script').length,
      success_count: LOG_ENTRIES.filter((e: Dict) => e.status === 'success').length,
      error_count: LOG_ENTRIES.filter((e: Dict) => e.status === 'error').length,
    }
  }, null, 2), 'utf-8');
  console.log(`\n日志已保存: ${logPath}`);
  return logPath;
}

// ── 天眼查 MCP 客户端 ────────────────────────────────────────
class HttpError extends Error {
  httpCode: number;
  httpBody: string;
  constructor(code: number, body: string) {
    super(`HTTP ${code}: ${body}`);
    this.httpCode = code;
    this.httpBody = body;
  }
}

class TianyanchaMCP {
  token: string;
  sessionId: string | null = null;
  reqId = 0;
  headers: Dict;

  constructor(token: string) {
    this.token = token;
    this.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      'Authorization': token,
    };
  }

  private nextId(): number {
    return ++this.reqId;
  }

  private async post(method: string, params?: any, isNotification = false): Promise<any> {
    const payload: Dict = { jsonrpc: '2.0', method };
    if (params !== undefined) payload.params = params;
    if (!isNotification) payload.id = this.nextId();

    const reqHeaders: Dict = { ...this.headers };
    if (this.sessionId) reqHeaders['Mcp-Session-Id'] = this.sessionId;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);
    try {
      const resp = await fetch(MCP_ENDPOINT, {
        method: 'POST',
        headers: reqHeaders,
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      clearTimeout(timeout);

      const sid = resp.headers.get('Mcp-Session-Id') || resp.headers.get('mcp-session-id');
      if (sid && !this.sessionId) this.sessionId = sid;

      const raw = await resp.text();
      if (!resp.ok) {
        throw new HttpError(resp.status, raw);
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
        return raw.trim() ? JSON.parse(raw) : {};
      }
    } catch (e) {
      clearTimeout(timeout);
      throw e;
    }
  }

  async initialize(): Promise<void> {
    const result = await this.post('initialize', {
      protocolVersion: '2025-03-26',
      capabilities: {},
      clientInfo: { name: 'DD Pipeline', version: '1.0' }
    });
    const proto = result?.result?.protocolVersion ?? '?';
    const serverInfo = result?.result?.serverInfo ?? {};
    log('mcp', 'initialize', `protocolVersion=${proto}, server=${serverInfo.name ?? '?'}, session=${this.sessionId ? this.sessionId.substring(0, 20) : 'N/A'}...`, 'success');
    await this.post('notifications/initialized', undefined, true);
    log('mcp', 'notifications/initialized', '已发送', 'success');
  }

  async callTool(companyName: string, toolName: string): Promise<{ ok: boolean; text?: string; is_error?: boolean; error?: string }> {
    log('mcp', 'call_tool', `company=${companyName}, tool=${toolName}`);
    try {
      const result = await this.post('tools/call', {
        name: 'call_tool',
        arguments: {
          company_name: companyName,
          tool_name: toolName,
          page: 1,
          page_size: 20,
        }
      });
      if (result === null) {
        log('mcp', 'call_tool_result', `tool=${toolName}: 无响应`, 'error');
        return { ok: false, error: '无响应' };
      }
      if (result.error) {
        const err = result.error;
        const errMsg = `${err.code}: ${err.message ?? ''}`;
        log('mcp', 'call_tool_result', `tool=${toolName}: ${errMsg.substring(0, 300)}`, 'error', { full_error: err });
        return { ok: false, error: errMsg };
      }

      const content = result?.result?.content ?? [];
      const isError = result?.result?.isError ?? false;
      const textParts = content.filter((item: Dict) => item.type === 'text').map((item: Dict) => item.text ?? '');
      const fullText = textParts.join('\n');
      log('mcp', 'call_tool_result', `tool=${toolName}: ${isError ? 'isError' : 'success'}, ${fullText.length} 字符`, isError ? 'error' : 'success', { data_preview: fullText.substring(0, 500) });
      return { ok: !isError, text: fullText, is_error: isError };
    } catch (e: any) {
      if (e instanceof HttpError) {
        log('mcp', 'call_tool_result', `tool=${toolName}: HTTP ${e.httpCode}: ${e.httpBody.substring(0, 300)}`, 'error', { http_code: e.httpCode, body: e.httpBody.substring(0, 1000) });
        return { ok: false, error: `HTTP ${e.httpCode}: ${e.httpBody.substring(0, 200)}` };
      }
      log('mcp', 'call_tool_result', `tool=${toolName}: ${e}`, 'error');
      return { ok: false, error: String(e) };
    }
  }

  close(): void {
    log('mcp', 'close', 'MCP 会话关闭', 'success');
  }
}

// ── 辅助函数 ──────────────────────────────────────────────────
function parseBasicInfo(markdownText: string, enterpriseName: string): Dict {
  const info: Dict = { enterprise_name: enterpriseName, data_source: 'tianyancha' };
  const patterns: Record<string, RegExp> = {
    credit_code: /统一社会信用代码\s*\|\s*([^|]+)\s*\|/,
    legal_representative: /法定代表人\s*\|\s*([^|]+)\s*\|/,
    registered_capital: /注册资本\s*\|\s*([^|]+)\s*\|/,
    registration_status: /登记状态\s*\|\s*([^|]+)\s*\|/,
    business_scope: /经营范围\s*\|\s*([^|]+)/,
  };
  for (const [key, pattern] of Object.entries(patterns)) {
    const m = pattern.exec(markdownText);
    if (m) info[key] = m[1].trim();
  }
  return info;
}

function runScript(scriptName: string, args: string[]): Dict {
  const scriptBase = scriptName.replace(/\.(py|ts)$/, '');
  const tsPath = path.join(SCRIPTS_DIR, `${scriptBase}.ts`);
  const pyPath = path.join(SCRIPTS_DIR, `${scriptBase}.py`);

  log('script', 'run', `${scriptName} ${args.join(' ')}`);

  // 优先 TypeScript 版本，失败降级 Python
  if (fs.existsSync(tsPath)) {
    try {
      const stdout = execFileSync('node', ['--experimental-strip-types', tsPath, ...args], {
        encoding: 'utf-8',
        timeout: 120000,
        maxBuffer: 10 * 1024 * 1024,
      });
      const parsed = stdout.trim() ? JSON.parse(stdout) : {};
      log('script', 'result', `${scriptName}: returncode=0, stdout=${stdout.length} 字符`, 'success', { stdout_preview: stdout.substring(0, 500) });
      return parsed;
    } catch (e: any) {
      const stdout = e.stdout?.toString().trim() ?? '';
      const stderr = e.stderr?.toString().trim() ?? '';
      if (stdout) {
        try {
          const parsed = JSON.parse(stdout);
          log('script', 'result', `${scriptName}: returncode=${e.status ?? 1}, stdout=${stdout.length} 字符`, 'success', { stdout_preview: stdout.substring(0, 500) });
          return parsed;
        } catch { /* fall through to Python */ }
      }
      log('script', 'result', `${scriptName}: TS 失败，降级 Python: ${stderr.substring(0, 300)}`, 'error');
      return runPythonScript(pyPath, args);
    }
  }
  return runPythonScript(pyPath, args);
}

function runPythonScript(pyPath: string, args: string[]): Dict {
  try {
    const env = { ...process.env, PYTHONIOENCODING: 'utf-8' };
    const stdout = execFileSync('python', [pyPath, ...args], {
      encoding: 'utf-8',
      timeout: 120000,
      maxBuffer: 10 * 1024 * 1024,
      env,
    });
    const parsed = stdout.trim() ? JSON.parse(stdout) : {};
    log('script', 'result', `Python: returncode=0, stdout=${stdout.length} 字符`, 'success', { stdout_preview: stdout.substring(0, 500) });
    return parsed;
  } catch (e: any) {
    const stdout = e.stdout?.toString().trim() ?? '';
    const stderr = e.stderr?.toString().trim() ?? '';
    log('script', 'result', `Python: returncode=${e.status ?? 1}, stderr=${(stderr || stdout).substring(0, 300)}`, 'error', { stderr: (stderr || stdout).substring(0, 1000) });
    return { error: stderr || stdout || String(e) };
  }
}

// ── 主流程 ────────────────────────────────────────────────────
async function processEnterprise(enterprise: string, mcp: TianyanchaMCP, outdir: string, scene: string): Promise<Dict> {
  const result: Dict = { enterprise, status: 'processing', errors: [], steps: {} };
  fs.mkdirSync(outdir, { recursive: true });

  // Step 1: 数据采集
  console.log('\n  [1/5] 数据采集（天眼查 MCP）...');
  const fetchData: Dict = {};
  const mcpLogs: any[] = [];
  for (const tool of BUSINESS_TOOLS) {
    process.stdout.write(`    → ${tool}`);
    const r = await mcp.callTool(enterprise, tool);
    if (r.ok) {
      console.log(` ✅ (${r.text!.length} 字符)`);
      fetchData[tool] = r.text;
      mcpLogs.push({ tool, status: 'success', len: r.text!.length });
    } else {
      console.log(` ❌ ${(r.error ?? '?').substring(0, 120)}`);
      fetchData[tool] = '';
      mcpLogs.push({ tool, status: 'failed', error: r.error ?? '?' });
    }
  }
  result.steps.fetch = mcpLogs;

  // 保存采集的原始数据
  const fetchDir = path.join(outdir, 'fetched');
  fs.mkdirSync(fetchDir, { recursive: true });
  for (const [tool, text] of Object.entries(fetchData)) {
    if (text) {
      fs.writeFileSync(path.join(fetchDir, `${tool}.md`), text as string, 'utf-8');
    }
  }

  // 解析基础信息
  const basicInfo = parseBasicInfo(fetchData['get_company_registration_info'] ?? '', enterprise);
  const basicFile = path.join(outdir, `${enterprise}_basic.json`);
  fs.writeFileSync(basicFile, JSON.stringify(basicInfo, null, 2), 'utf-8');

  // Step 2: 股权穿透
  console.log('  [2/5] 股权穿透...');
  const equityData = { enterprise_name: enterprise, shareholders: [], source: 'tianyancha_free' };
  const equityFile = path.join(outdir, `${enterprise}_equity.json`);
  fs.writeFileSync(equityFile, JSON.stringify(equityData, null, 2), 'utf-8');

  const penResult = runScript('penetrate_equity', [
    '--input', equityFile, '--enterprise', enterprise,
    '--outdir', path.join(outdir, 'penetration')
  ]);
  if (penResult.error) {
    result.errors.push(`穿透: ${penResult.error.substring(0, 100)}`);
    console.log(`    ⚠ ${penResult.error.substring(0, 80)}`);
  } else {
    console.log('    ✅ 穿透完成');
  }
  result.steps.penetrate = penResult;

  // Step 3: 风险分级
  console.log('  [3/5] 风险分级...');
  const riskMd = fetchData['get_risk_overview'] ?? '';
  const riskData = { risk_overview_md: riskMd, judicial_cases: [], admin_penalties: [], operation_anomalies: [] };
  const riskFile = path.join(outdir, `${enterprise}_risk.json`);
  fs.writeFileSync(riskFile, JSON.stringify(riskData, null, 2), 'utf-8');

  const tierResult = runScript('tier_risks', [
    '--input', riskFile, '--enterprise', enterprise,
    '--outdir', path.join(outdir, 'risks')
  ]);
  if (tierResult.error) {
    result.errors.push(`分级: ${tierResult.error.substring(0, 100)}`);
    console.log(`    ⚠ ${tierResult.error.substring(0, 80)}`);
  } else {
    console.log('    ✅ 分级完成');
  }
  result.steps.tier = tierResult;

  // Step 4: 报告生成
  console.log('  [4/5] 报告生成...');
  const penJson = penResult.output_path ?? '';
  const riskJson = tierResult.output_path ?? '';
  const reportArgs = [
    '--enterprise', enterprise,
    '--basic-info', basicFile,
    '--format', 'md,html',
    '--outdir', path.join(outdir, 'report'),
  ];
  if (penJson && fs.existsSync(penJson)) reportArgs.push('--penetration', penJson);
  if (riskJson && fs.existsSync(riskJson)) reportArgs.push('--risks', riskJson);
  const reportResult = runScript('generate_dd_report', reportArgs);
  if (reportResult.error) {
    result.errors.push(`报告: ${reportResult.error.substring(0, 100)}`);
    console.log(`    ⚠ ${reportResult.error.substring(0, 80)}`);
  } else {
    const paths = reportResult.output_paths ?? [];
    console.log(`    ✅ 报告生成: ${paths.length} 个文件`);
    for (const p of paths) console.log(`       - ${p}`);
  }
  result.steps.report = reportResult;

  // Step 5: 汇总
  console.log('  [5/5] 汇总...');
  result.status = result.errors.length === 0 ? 'completed' : 'completed_with_errors';
  result.report_paths = reportResult.output_paths ?? [];
  result.basic_info = basicInfo;
  log('pipeline', 'complete', `status=${result.status}, errors=${result.errors.length}`, result.status);
  return result;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  let enterprise = '腾讯科技（深圳）有限公司';
  let scene = 'supplier';
  let outdir = 'output';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--enterprise' && i + 1 < args.length) enterprise = args[++i];
    else if (args[i] === '--scene' && i + 1 < args.length) scene = args[++i];
    else if (args[i] === '--outdir' && i + 1 < args.length) outdir = args[++i];
  }

  const token = loadToken();
  if (!token) {
    console.log('❌ 未找到 TIANYANCHA_MCP_TOKEN');
    process.exit(1);
  }

  console.log('=== 尽调全链路 ===');
  console.log(`企业: ${enterprise}`);
  console.log(`场景: ${scene}`);
  console.log(`输出: ${outdir}`);
  console.log(`日志: ${LOG_DIR}`);
  console.log('\n--- MCP 初始化 ---');
  const mcp = new TianyanchaMCP(token);
  await mcp.initialize();

  console.log(`\n--- 处理企业: ${enterprise} ---`);
  const result = await processEnterprise(enterprise, mcp, outdir, scene);

  const summaryPath = path.join(outdir, 'pipeline_result.json');
  fs.writeFileSync(summaryPath, JSON.stringify(result, null, 2), 'utf-8');

  console.log(`\n${'='.repeat(60)}`);
  console.log(`状态: ${result.status}`);
  console.log(`基础信息: ${JSON.stringify(result.basic_info ?? {})}`);
  console.log(`报告文件: ${JSON.stringify(result.report_paths ?? [])}`);
  if (result.errors.length > 0) {
    console.log(`错误: ${JSON.stringify(result.errors)}`);
  }
  console.log(`结果已保存: ${summaryPath}`);

  mcp.close();
  const logPath = saveLog(enterprise);
  console.log(`日志已保存: ${logPath}`);
}

main();