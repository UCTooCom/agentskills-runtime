#!/usr/bin/env node
/**
 * 批量尽调任务编排（T5.5） - TypeScript 版本
 * 功能与 run_batch_dd.py 完全一致
 * 运行：node --experimental-strip-types scripts/run_batch_dd.ts [参数]
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

type Dict = Record<string, any>;

const __filename = fileURLToPath(import.meta.url);
const SCRIPTS_DIR = path.dirname(__filename);

const DEFAULT_HOST_BASE_URL = 'https://javatoarktsapi.uctoo.com';

function formatDateTime(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

function resolveBaseUrl(): string {
  const envValue = (process.env.HOST_BASE_URL ?? '').trim();
  if (envValue) return envValue.replace(/\/$/, '');

  let current = SCRIPTS_DIR;
  for (let i = 0; i < 6; i++) {
    const candidate = path.join(current, '.env');
    if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
      try {
        const content = fs.readFileSync(candidate, 'utf-8');
        for (const line of content.split(/\r?\n/)) {
          const trimmed = line.trim();
          if (trimmed.startsWith('BACKEND_URL=')) {
            let value = trimmed.substring(trimmed.indexOf('=') + 1).trim()
              .replace(/^"+/, '').replace(/"+$/, '').replace(/^'+/, '').replace(/'+$/, '');
            if (value) return value.replace(/\/$/, '');
          }
        }
      } catch { /* ignore */ }
      break;
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return DEFAULT_HOST_BASE_URL;
}

async function callHostApi(baseUrl: string, apiPath: string, body: Dict): Promise<Dict> {
  const url = `${baseUrl.replace(/\/$/, '')}${apiPath}`;
  const data = JSON.stringify(body);
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 120000);
    const resp = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: data,
      signal: controller.signal,
    });
    clearTimeout(timeout);
    const text = await resp.text();
    if (!resp.ok) {
      return { errno: String(resp.status), errmsg: text };
    }
    return JSON.parse(text);
  } catch (e: any) {
    if (e.name === 'AbortError') {
      return { errno: '-1', errmsg: '请求超时' };
    }
    return { errno: '-1', errmsg: String(e) };
  }
}

async function ddFetch(baseUrl: string, enterprise: string, mcpAlias: string, scene: string): Promise<Dict> {
  return await callHostApi(baseUrl, '/api/v1/uctoo/due_diligence/dd-fetch', {
    enterprise_name: enterprise,
    mcp_alias: mcpAlias,
    scene
  });
}

async function ddSave(baseUrl: string, enterprise: string, data: Dict): Promise<Dict> {
  return await callHostApi(baseUrl, '/api/v1/uctoo/due_diligence/dd-save', {
    enterprise_name: enterprise,
    data
  });
}

function runScript(scriptName: string, args: string[]): Dict {
  const scriptBase = scriptName.replace(/\.(py|ts)$/, '');
  const tsPath = path.join(SCRIPTS_DIR, `${scriptBase}.ts`);
  const pyPath = path.join(SCRIPTS_DIR, `${scriptBase}.py`);

  // 优先 TypeScript 版本，失败降级 Python
  if (fs.existsSync(tsPath)) {
    try {
      const stdout = execFileSync('node', ['--experimental-strip-types', tsPath, ...args], {
        encoding: 'utf-8',
        timeout: 120000,
        maxBuffer: 10 * 1024 * 1024,
      });
      return stdout.trim() ? JSON.parse(stdout) : {};
    } catch (e: any) {
      const stdout = e.stdout?.toString().trim() ?? '';
      const stderr = e.stderr?.toString().trim() ?? '';
      if (stdout) {
        try { return JSON.parse(stdout); } catch { /* fall through */ }
      }
      return runPythonScript(pyPath, args, stderr || stdout || String(e));
    }
  }
  return runPythonScript(pyPath, args, 'TS 版本不存在');
}

function runPythonScript(pyPath: string, args: string[], fallbackError: string): Dict {
  try {
    const stdout = execFileSync('python', [pyPath, ...args], {
      encoding: 'utf-8',
      timeout: 120000,
      maxBuffer: 10 * 1024 * 1024,
    });
    return stdout.trim() ? JSON.parse(stdout) : {};
  } catch (e: any) {
    const stdout = e.stdout?.toString().trim() ?? '';
    const stderr = e.stderr?.toString().trim() ?? '';
    if (stdout) {
      try { return JSON.parse(stdout); } catch { /* fall through */ }
    }
    return { error: stderr || stdout || String(e) || fallbackError };
  }
}

async function processSingleEnterprise(
  enterprise: string, baseUrl: string, mcpAlias: string, scene: string, outdir: string
): Promise<Dict> {
  const result: Dict = { enterprise, status: 'processing', errors: [] };

  // 1. dd-fetch
  const fetchResult = await ddFetch(baseUrl, enterprise, mcpAlias, scene);
  if ((fetchResult.errno ?? '0') !== '0') {
    result.status = 'failed';
    result.errors.push(`dd-fetch 失败：${fetchResult.errmsg ?? '未知错误'}`);
    return result;
  }

  const fetchData: Dict = fetchResult.data ?? {};
  const basicInfo: Dict = fetchData.basic_info ?? {};
  const equityData: Dict = fetchData.equity_data ?? {};
  const riskData: Dict = fetchData.risk_data ?? {};

  // 2. 穿透
  const penInput = path.join(outdir, `_tmp_${enterprise}_equity.json`);
  fs.writeFileSync(penInput, JSON.stringify(equityData), 'utf-8');
  const penResult = runScript('penetrate_equity', [
    '--input', penInput, '--enterprise', enterprise,
    '--outdir', path.join(outdir, 'penetration')
  ]);
  if (fs.existsSync(penInput)) fs.unlinkSync(penInput);
  if (penResult.error) result.errors.push(`穿透失败：${penResult.error}`);

  // 3. 分级
  const riskInput = path.join(outdir, `_tmp_${enterprise}_risk.json`);
  fs.writeFileSync(riskInput, JSON.stringify(riskData), 'utf-8');
  const tierResult = runScript('tier_risks', [
    '--input', riskInput, '--enterprise', enterprise,
    '--outdir', path.join(outdir, 'risks')
  ]);
  if (fs.existsSync(riskInput)) fs.unlinkSync(riskInput);
  if (tierResult.error) result.errors.push(`分级失败：${tierResult.error}`);

  // 4. 报告
  const penFile = penResult.output_path ?? '';
  const riskFile = tierResult.output_path ?? '';
  const basicFile = path.join(outdir, `_tmp_${enterprise}_basic.json`);
  fs.writeFileSync(basicFile, JSON.stringify(basicInfo), 'utf-8');
  const reportResult = runScript('generate_dd_report', [
    '--enterprise', enterprise,
    '--basic-info', basicFile,
    '--penetration', penFile,
    '--risks', riskFile,
    '--format', 'md,html',
    '--outdir', path.join(outdir, 'report')
  ]);
  if (fs.existsSync(basicFile)) fs.unlinkSync(basicFile);

  // 5. dd-save
  const saveData = {
    basic_info: basicInfo,
    penetration: penResult,
    risks: tierResult,
    report_paths: reportResult.output_paths ?? []
  };
  const saveResult = await ddSave(baseUrl, enterprise, saveData);
  if ((saveResult.errno ?? '0') !== '0') {
    result.errors.push(`dd-save 失败：${saveResult.errmsg ?? '未知错误'}`);
  }

  result.status = result.errors.length === 0 ? 'completed' : 'completed_with_errors';
  result.report_paths = reportResult.output_paths ?? [];
  result.risk_summary = tierResult.summary ?? {};
  return result;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  let enterprisesArg = '', enterprisesFile = '', scene = 'supplier', outdir = 'output';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--enterprises' && i + 1 < args.length) enterprisesArg = args[++i];
    else if (args[i] === '--enterprises-file' && i + 1 < args.length) enterprisesFile = args[++i];
    else if (args[i] === '--scene' && i + 1 < args.length) scene = args[++i];
    else if (args[i] === '--outdir' && i + 1 < args.length) outdir = args[++i];
  }

  const validScenes = ['supplier', 'credit', 'investment', 'competitor', 'related_risk'];
  if (!validScenes.includes(scene)) {
    console.error(`错误：--scene 必须是 ${validScenes.join(', ')} 之一`);
    process.exit(1);
  }

  const baseUrl = resolveBaseUrl();
  const mcpAlias = process.env.MCP_ALIAS ?? 'tianyancha';

  // 1. 名单校验
  let enterprisesStr = enterprisesArg;
  if (enterprisesFile) {
    const content = fs.readFileSync(enterprisesFile, 'utf-8');
    enterprisesStr = content.split(/\r?\n/).map(line => line.trim()).filter(line => line).join(',');
  }

  const valResult = runScript('validate_enterprise_list', [
    '--input', enterprisesStr, '--scene', scene
  ]);

  if (!valResult.valid) {
    console.log(JSON.stringify({ error: valResult.error ?? '名单校验失败', validation: valResult }, null, 2));
    process.exit(1);
  }

  const enterpriseList: string[] = valResult.enterprises;
  if (valResult.duplicates_removed?.length) {
    console.error(`去重：${valResult.duplicates_removed.join(', ')}`);
  }
  if (valResult.invalid_entries?.length) {
    console.error(`无效条目：${JSON.stringify(valResult.invalid_entries)}`);
  }

  fs.mkdirSync(outdir, { recursive: true });

  // 2. 逐企业处理
  const results: Dict[] = [];
  const total = enterpriseList.length;
  for (let i = 0; i < enterpriseList.length; i++) {
    const enterprise = enterpriseList[i];
    const idx = i + 1;
    console.error(`[${idx}/${total}] 正在尽调：${enterprise} ...`);
    const startTimeMs = Date.now();
    let r: Dict;
    try {
      r = await processSingleEnterprise(enterprise, baseUrl, mcpAlias, scene, outdir);
    } catch (e) {
      r = { enterprise, status: 'failed', errors: [String(e)] };
    }
    r.duration_seconds = Number(((Date.now() - startTimeMs) / 1000).toFixed(2));
    results.push(r);

    const statusIcon = ({ completed: '✓', completed_with_errors: '⚠', failed: '✗' } as Dict)[r.status] ?? '?';
    console.error(`  ${statusIcon} ${r.status} (${r.duration_seconds}s)`);
  }

  // 3. 汇总
  const completed = results.filter(r => r.status === 'completed');
  const withErrors = results.filter(r => r.status === 'completed_with_errors');
  const failed = results.filter(r => r.status === 'failed');

  const summary: Dict = {
    total,
    completed: completed.length,
    completed_with_errors: withErrors.length,
    failed: failed.length,
    failed_enterprises: failed.map(r => ({ name: r.enterprise, errors: r.errors ?? [] })),
    scene,
    generated_at: formatDateTime(new Date()),
    results
  };

  const summaryPath = path.join(outdir, 'batch_summary.json');
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2), 'utf-8');

  console.log(JSON.stringify({
    summary: { total: summary.total, completed: summary.completed, completed_with_errors: summary.completed_with_errors, failed: summary.failed },
    summary_path: summaryPath,
    failed_enterprises: summary.failed_enterprises
  }, null, 2));

  if (failed.length > 0) {
    process.exit(1);
  }
}

main();