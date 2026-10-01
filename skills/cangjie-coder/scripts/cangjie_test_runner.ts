#!/usr/bin/env node
/**
 * cangjie_test_runner.ts — 仓颉代码测试运行脚本
 * 功能与 cangjie_test_runner.py 完全一致
 *
 * 用法:
 *   node --experimental-strip-types cangjie_test_runner.ts --project /path/to/project [--timeout 300]
 */
import * as fs from "fs";
import { spawnSync } from "child_process";

interface TestCase { name: string; status: string; message: string; }
interface TestResult {
  tool: string; project_path: string; passed: boolean; total: number;
  passed_count: number; failed_count: number; skipped_count: number;
  test_cases: TestCase[]; output: string; duration_seconds: number;
}

function parseTestOutput(output: string): TestCase[] {
  const testCases: TestCase[] = [];
  const passPattern = /(?:PASS|✓|passed)\s*:?\s*(.+)/i;
  const failPattern = /(?:FAIL|✗|failed)\s*:?\s*(.+)/i;
  const skipPattern = /(?:SKIP|⊘|skipped)\s*:?\s*(.+)/i;
  for (const line of output.split(/\r?\n/)) {
    const l = line.trim();
    if (!l) continue;
    let m = passPattern.exec(l);
    if (m) { testCases.push({ name: m[1].trim(), status: "pass", message: "" }); continue; }
    m = failPattern.exec(l);
    if (m) { testCases.push({ name: m[1].trim(), status: "fail", message: l }); continue; }
    m = skipPattern.exec(l);
    if (m) { testCases.push({ name: m[1].trim(), status: "skip", message: "" }); continue; }
  }
  if (testCases.length === 0) {
    if (/PASS/i.test(output) || /passed/i.test(output)) {
      testCases.push({ name: "all_tests", status: "pass", message: "所有测试通过（无法解析具体测试用例）" });
    } else if (/FAIL/i.test(output) || /failed/i.test(output)) {
      testCases.push({ name: "all_tests", status: "fail", message: output.slice(-500) });
    }
  }
  return testCases;
}

function runCjpmTest(projectPath: string, timeout = 300): TestResult {
  const result: TestResult = {
    tool: "cangjie_test_runner", project_path: projectPath, passed: false,
    total: 0, passed_count: 0, failed_count: 0, skipped_count: 0,
    test_cases: [], output: "", duration_seconds: 0,
  };
  if (!fs.existsSync(projectPath) || !fs.statSync(projectPath).isDirectory()) {
    result.test_cases.push({ name: "project_check", status: "fail", message: `项目目录不存在: ${projectPath}` });
    return result;
  }
  const cjpmPath = process.env.CJPM_PATH || "cjpm";
  const start = Date.now();
  try {
    // 对齐 py subprocess.run(capture_output)：合并 stdout+stderr 作为 output，
    // 成功/失败路径均记录真实耗时（2 位小数）
    const r = spawnSync(cjpmPath, ["test"], {
      cwd: projectPath, encoding: "utf-8", timeout: timeout * 1000,
    }) as { status: number | null; stdout: string; stderr: string; error?: any };
    result.duration_seconds = Math.round((Date.now() - start) / 100) / 100;
    const output = String(r.stdout || "") + String(r.stderr || "");
    result.output = output;
    if (r.error && (r.error as any).code === "ENOENT") {
      result.test_cases.push({ name: "cjpm_not_found", status: "fail", message: "cjpm命令未找到，请确保仓颉SDK已安装并配置PATH环境变量" });
      return result;
    }
    if (r.error) {
      // 对齐 py except Exception：记录 execution_error 用例而非静默
      result.test_cases.push({ name: "execution_error", status: "fail", message: `测试执行异常: ${(r.error as any).message || r.error}` });
      return result;
    }
    if (r.status === 0) {
      const testCases = parseTestOutput(output);
      result.test_cases = testCases;
      result.total = testCases.length;
      result.passed_count = testCases.filter((tc) => tc.status === "pass").length;
      result.failed_count = testCases.filter((tc) => tc.status === "fail").length;
      result.skipped_count = testCases.filter((tc) => tc.status === "skip").length;
      result.passed = result.failed_count === 0 && result.total > 0;
    } else {
      const testCases = parseTestOutput(output);
      result.test_cases = testCases;
      result.total = testCases.length;
      result.passed_count = testCases.filter((tc) => tc.status === "pass").length;
      result.failed_count = testCases.filter((tc) => tc.status === "fail").length;
      result.skipped_count = testCases.filter((tc) => tc.status === "skip").length;
      result.passed = result.failed_count === 0 && result.total > 0;
    }
  } catch (e: any) {
    result.duration_seconds = Math.round((Date.now() - start) / 100) / 100;
    result.test_cases.push({ name: "execution_error", status: "fail", message: `测试执行异常: ${e.message}` });
  }
  return result;
}

// 参数解析
const args = process.argv.slice(2);
let project = "", timeout = 300;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--project") project = args[++i];
  else if (args[i] === "--timeout") { const v = args[++i]; if (!/^\d+$/.test(v)) { console.error(`错误: --timeout 必须为整数: ${v}`); process.exit(2); } timeout = parseInt(v, 10); }
}
if (!project) { console.error("用法: node cangjie_test_runner.ts --project <path> [--timeout 300]"); process.exit(2); }
const result = runCjpmTest(project, timeout);
console.log(JSON.stringify(result, null, 2));
process.exit(result.passed ? 0 : 1);