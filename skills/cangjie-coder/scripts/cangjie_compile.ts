#!/usr/bin/env node
/**
 * cangjie_compile.ts — 仓颉代码编译验证脚本
 * 功能与 cangjie_compile.py 完全一致
 *
 * 用法:
 *   node --experimental-strip-types cangjie_compile.ts --project /path/to/project [--verbose] [--timeout 300]
 */
import * as path from "path";
import * as fs from "fs";
import { spawnSync } from "child_process";

interface CompileIssue { file: string; line: number; column: number; message: string; severity: string; }
interface CompileResult {
  tool: string; project_path: string; passed: boolean;
  errors: CompileIssue[]; warnings: CompileIssue[]; output: string; duration_seconds: number;
}

function parseErrorLine(line: string, severity = "error"): CompileIssue {
  const patterns = [
    /^(.+?):(\d+):(\d+):\s*(error|warning):\s*(.+)/i,
    /^(.+?):(\d+):\s*(error|warning):\s*(.+)/i,
    /^(error|warning):\s*(.+)/i,
  ];
  for (const p of patterns) {
    const m = p.exec(line);
    if (m) {
      if (m.length === 6) return { file: m[1], line: parseInt(m[2]), column: parseInt(m[3]), message: m[5], severity };
      if (m.length === 5) return { file: m[1], line: parseInt(m[2]), column: 0, message: m[4], severity };
      if (m.length === 3) return { file: "", line: 0, column: 0, message: m[2], severity };
    }
  }
  return { file: "", line: 0, column: 0, message: line, severity };
}

function parseCjpmOutput(output: string): { errors: CompileIssue[]; warnings: CompileIssue[] } {
  const errors: CompileIssue[] = [], warnings: CompileIssue[] = [];
  for (const line of output.split(/\r?\n/)) {
    const l = line.trim();
    if (!l) continue;
    if (/error/i.test(l)) errors.push(parseErrorLine(l));
    else if (/warning/i.test(l)) warnings.push(parseErrorLine(l, "warning"));
  }
  return { errors, warnings };
}

function runCjpmBuild(projectPath: string, verbose = false, timeout = 300): CompileResult {
  const result: CompileResult = {
    tool: "cjpm_build", project_path: projectPath, passed: false,
    errors: [], warnings: [], output: "", duration_seconds: 0,
  };
  if (!fs.existsSync(projectPath) || !fs.statSync(projectPath).isDirectory()) {
    result.errors.push({ file: "", line: 0, column: 0, message: `项目目录不存在: ${projectPath}`, severity: "error" });
    return result;
  }
  const cjpmPath = process.env.CJPM_PATH || "cjpm";
  const start = Date.now();
  const cmd = verbose ? [cjpmPath, "build", "-V"] : [cjpmPath, "build"];
  try {
    // 对齐 py subprocess.run(capture_output)：合并 stdout+stderr 作为 output，
    // 成功/失败路径均记录真实耗时（2 位小数）
    const r = spawnSync(cmd[0], cmd.slice(1), {
      cwd: projectPath, encoding: "utf-8", timeout: timeout * 1000,
    }) as { status: number | null; stdout: string; stderr: string; error?: any };
    result.duration_seconds = Math.round((Date.now() - start) / 100) / 100;
    const output = String(r.stdout || "") + String(r.stderr || "");
    result.output = output;
    if (r.error && (r.error as any).code === "ENOENT") {
      result.errors.push({ file: "", line: 0, column: 0, message: "cjpm命令未找到，请确保仓颉SDK已安装并配置PATH环境变量", severity: "error" });
      return result;
    }
    if (r.error) {
      // 对齐 py except Exception：记录执行异常而非静默
      result.errors.push({ file: "", line: 0, column: 0, message: `编译执行异常: ${(r.error as any).message || r.error}`, severity: "error" });
      return result;
    }
    if (r.status === 0) {
      result.passed = true;
    } else {
      const { errors, warnings } = parseCjpmOutput(output);
      result.errors = errors;
      result.warnings = warnings;
    }
  } catch (e: any) {
    result.duration_seconds = Math.round((Date.now() - start) / 100) / 100;
    result.errors.push({ file: "", line: 0, column: 0, message: `编译执行异常: ${e.message}`, severity: "error" });
  }
  return result;
}

// 参数解析
const args = process.argv.slice(2);
let project = "", verbose = false, timeout = 300;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--project") project = args[++i];
  else if (args[i] === "--verbose") verbose = true;
  else if (args[i] === "--timeout") { const v = args[++i]; if (!/^\d+$/.test(v)) { console.error(`错误: --timeout 必须为整数: ${v}`); process.exit(2); } timeout = parseInt(v, 10); }
}
if (!project) { console.error("用法: node cangjie_compile.ts --project <path> [--verbose] [--timeout 300]"); process.exit(2); }
const result = runCjpmBuild(project, verbose, timeout);
console.log(JSON.stringify(result, null, 2));
process.exit(result.passed ? 0 : 1);