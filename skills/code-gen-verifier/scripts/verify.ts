#!/usr/bin/env node
/**
 * verify.ts — code-gen-verifier 技能的质量闸门执行体
 * 功能与 verify.py 完全一致
 *
 * 运行方式: node --experimental-strip-types verify.ts --files <files> [--project-path <path>] [--verify-level compile]
 */
import * as fs from "fs";
import * as path from "path";
import { execFileSync, spawnSync } from "child_process";

const __dirname = import.meta.dirname;

const LAYER_SUFFIX: [string, string][] = [
  ["PO.cj", "Model"], ["DAO.cj", "DAO"], ["Service.cj", "Service"], ["Controller.cj", "Controller"], ["Route.cj", "Route"],
];
const SPEC_RULES: Record<string, [string, string][]> = {
  "PO.cj": [["@DataAssist", "PO 类缺少 @DataAssist 注解"]],
  "DAO.cj": [["<:\\s*RootDAO", "DAO 未继承 RootDAO"]],
  "Service.cj": [["APIResult<", "Service 方法未返回 APIResult<T>"]],
  "Controller.cj": [["\\bres\\.", "Controller 未使用 res.* 输出响应"], ["public\\s+func", "Controller 无 public func 处理函数"]],
  "Route.cj": [["router\\.(post|get|put|delete)\\s*\\(", "Route 未注册任何端点"], ["/api/v1/uctoo/", "Route 端点未遵循 /api/v1/uctoo/ 前缀"]],
};
const SECRET_RE = /(sk-[A-Za-z0-9]{12,}|api_key\s*=\s*['"]?.{8,}|password\s*=\s*['"]?.{8,})/i;
const LEVELS = ["syntax", "compile", "test"];

function nowCst(): string { return new Date(Date.now() + 8 * 3600 * 1000).toISOString().replace(/\.\d+Z$/, "+08:00"); }

function cangjieScriptsDir(explicit: string): string {
  if (explicit) return explicit;
  const env = process.env.CANGJIE_CODER_SCRIPTS || "";
  if (env && fs.existsSync(env) && fs.statSync(env).isDirectory()) return env;
  return path.normalize(path.join(__dirname, "..", "..", "cangjie-coder", "scripts"));
}

function splitFiles(raw: string): string[] {
  if (!raw) return [];
  return raw.split(/[,;、\n]+/).map((p) => p.trim()).filter(Boolean);
}

/**
 * 运行检查器脚本。
 * TS 优先 / Python 降级策略（与技能其他脚本一致）：
 *  - 若存在同名 .ts 检查器：`node --experimental-strip-types <checker.ts>`
 *  - 否则降级执行 .py 检查器（需 python 命令可用）
 */
function runHelper(scriptPath: string, args: string[], timeout: number): any {
  let pyPath = scriptPath;
  let tsPath = "";
  if (scriptPath.endsWith(".py")) tsPath = scriptPath.slice(0, -3) + ".ts";
  let cmd: string, cmdArgs: string[];
  if (tsPath && fs.existsSync(tsPath)) {
    pyPath = tsPath;
    cmd = process.execPath;
    cmdArgs = ["--experimental-strip-types", tsPath, ...args];
  } else {
    cmd = "python";
    cmdArgs = [pyPath, ...args];
  }
  if (!fs.existsSync(pyPath)) return { ok: false, data: null, detail: `检查器不存在: ${scriptPath}`, missing: true };
  let r: { status: number | null; stdout: string; stderr: string; error?: any; killed?: boolean };
  try {
    r = spawnSync(cmd, cmdArgs, { encoding: "utf-8", timeout: timeout * 1000 }) as any;
  } catch (e: any) {
    return { ok: false, data: null, detail: `执行检查器失败: ${e.message}`, missing: false };
  }
  if (r.error && (r.error as any).code === "ENOENT") {
    // 命令不存在（如无 python）→ 视为检查器缺失，交由上层降级逻辑
    return { ok: false, data: null, detail: `检查器不可用: 命令 "${cmd}" 不存在 (${(r.error as any).message})`, missing: true };
  }
  const out = String(r.stdout || "") + String(r.stderr || "");
  let data: any = null;
  try { if (out.trim()) data = JSON.parse(out.trim()); } catch {}
  const ok = r.status === 0;
  return { ok, data, detail: out.trim().slice(0, 500) || (ok ? "无输出" : `执行检查器失败: exit=${r.status}${r.killed ? "（超时）" : ""}`), missing: false };
}

function stripComments(text: string): string {
  const out: string[] = [];
  let i = 0, n = text.length, inStr = false, inChar = false, esc = false;
  while (i < n) {
    const c = text[i], nxt = i + 1 < n ? text[i + 1] : "";
    if (inStr) { out.push(c); if (esc) esc = false; else if (c === "\\") esc = true; else if (c === '"') inStr = false; i++; continue; }
    if (inChar) { out.push(c); if (esc) esc = false; else if (c === "\\") esc = true; else if (c === "'") inChar = false; i++; continue; }
    if (c === '"') { inStr = true; out.push(c); i++; continue; }
    if (c === "'") { inChar = true; out.push(c); i++; continue; }
    if (c === "/" && nxt === "/") { while (i < n && text[i] !== "\n") i++; continue; }
    if (c === "/" && nxt === "*") { i += 2; while (i < n && !(text[i] === "*" && i + 1 < n && text[i + 1] === "/")) { if (text[i] === "\n") out.push("\n"); i++; } i += 2; continue; }
    out.push(c); i++;
  }
  return out.join("");
}

function layerOf(p: string): string { const base = path.basename(p); for (const [suffix] of LAYER_SUFFIX) if (base.endsWith(suffix)) return suffix; return ""; }

function stepCompleteness(files: string[], table: string, projectPath: string): [any[], any[]] {
  const errors: any[] = [], warnings: any[] = [];
  for (const f of files) {
    if (!fs.existsSync(f)) errors.push({ file: f, code: "missing_file", message: `文件不存在: ${f}` });
    else if (fs.statSync(f).size === 0) errors.push({ file: f, code: "empty_file", message: `文件为空: ${f}` });
  }
  if (table && projectPath && fs.existsSync(projectPath) && fs.statSync(projectPath).isDirectory()) {
    const found: Record<string, string> = {};
    function walk(dir: string) { for (const name of fs.readdirSync(dir)) { const full = path.join(dir, name); if (fs.statSync(full).isDirectory()) walk(full); else if (name.startsWith(table)) for (const [suffix, layer] of LAYER_SUFFIX) if (name.endsWith(suffix)) found[layer] = full; } }
    walk(projectPath);
    for (const [, layer] of LAYER_SUFFIX) if (!found[layer]) errors.push({ file: `${table}*${layer}`, code: "missing_layer", message: `五层缺 ${layer} 层（表名 ${table}）` });
  } else if (table && !(projectPath && fs.existsSync(projectPath))) warnings.push({ file: table, code: "no_project_path", message: "未给 --project-path 或目录不存在，跳过五层完整性检查" });
  return [errors, warnings];
}

function stepSyntax(files: string[], scriptsDir: string, strict: boolean, timeout: number): [any[], any[], boolean] {
  const errors: any[] = [], warnings: any[] = []; let missing = false;
  const checker = path.join(scriptsDir, "cangjie_syntax_check.py");
  for (const f of files) {
    if (!f.toLowerCase().endsWith(".cj") || !fs.existsSync(f)) continue;
    const res = runHelper(checker, ["--file", f, ...(strict ? ["--strict"] : [])], timeout);
    if (res.missing) { missing = true; warnings.push({ file: f, code: "no_syntax_checker", message: res.detail }); continue; }
    const issues = res.data?.issues || [];
    for (const it of issues) { const sev = String(it?.severity || "warning").toLowerCase(); const msg = `${it?.message || ""}（第 ${it?.line || 0} 行）`; if (sev === "error") errors.push({ file: f, code: "syntax_error", message: msg }); else warnings.push({ file: f, code: "syntax_warning", message: msg }); }
    if (!res.ok && !issues.length) errors.push({ file: f, code: "syntax_error", message: res.detail });
  }
  return [errors, warnings, missing];
}

function stepCompile(projectPath: string, scriptsDir: string, timeout: number): [any[], any[], boolean] {
  const errors: any[] = [], warnings: any[] = []; let missing = false;
  if (!(projectPath && fs.existsSync(projectPath))) return [[], [{ file: projectPath || "", code: "no_project_path", message: "未提供有效的 --project-path，跳过编译验证" }], true];
  const checker = path.join(scriptsDir, "cangjie_compile.py");
  const res = runHelper(checker, ["--project", projectPath, "--timeout", String(timeout)], timeout + 30);
  if (res.missing) return [[], [{ file: projectPath, code: "no_compile_checker", message: res.detail }], true];
  const data = res.data || {};
  for (const e of data.errors || []) errors.push({ file: typeof e === "object" ? String(e.file || projectPath) : projectPath, code: "compile_error", message: typeof e === "object" ? String(e.message || e) : String(e) });
  for (const w of data.warnings || []) warnings.push({ file: typeof w === "object" ? String(w.file || projectPath) : projectPath, code: "compile_warning", message: typeof w === "object" ? String(w.message || w) : String(w) });
  if (!res.ok && !(data.errors || []).length) errors.push({ file: projectPath, code: "compile_error", message: res.detail });
  return [errors, warnings, missing];
}

function stepSpec(files: string[]): [any[], any[]] {
  const errors: any[] = [], warnings: any[] = [];
  for (const f of files) {
    const suffix = layerOf(f);
    if (!suffix || !SPEC_RULES[suffix]) { warnings.push({ file: f, code: "unknown_layer", message: "无法判定所属分层（PO/DAO/Service/Controller/Route），跳过规范检查" }); continue; }
    if (!fs.existsSync(f)) continue;
    let text: string; try { text = fs.readFileSync(f, "utf-8"); } catch (e: any) { errors.push({ file: f, code: "unreadable", message: `读取失败: ${e.message}` }); continue; }
    const code = stripComments(text);
    for (const [pattern, msg] of SPEC_RULES[suffix]) if (!new RegExp(pattern).test(code)) errors.push({ file: f, code: "spec_violation", message: msg });
    if (SECRET_RE.test(code)) errors.push({ file: f, code: "secret_leak", message: "疑似硬编码密钥，需人工复核" });
  }
  return [errors, warnings];
}

function stepFixSuggest(files: string[], errors: any[], scriptsDir: string, timeout: number): any[] {
  const suggestions: any[] = [];
  const checker = path.join(scriptsDir, "cangjie_fix_suggest.py");
  if (!fs.existsSync(checker)) return suggestions;
  const bad = [...new Set(errors.filter((e) => e.file).map((e) => e.file))].sort();
  for (const f of bad) {
    if (!fs.existsSync(f) || !f.toLowerCase().endsWith(".cj")) continue;
    const errText = errors.filter((e) => e.file === f).map((e) => e.message).join("\n").slice(0, 2000);
    const res = runHelper(checker, ["--file", f, "--error", errText], timeout);
    for (const s of res.data?.suggestions || []) suggestions.push({ file: f, suggestion: s });
  }
  return suggestions;
}

function verify(files: string[], projectPath: string, level: string, table: string, scriptsDir: string, strict: boolean, timeout: number): any {
  const steps: any[] = [], errors: any[] = [], warnings: any[] = []; let degraded = false; const reasons: string[] = [];
  let e: any[], w: any[];
  [e, w] = stepCompleteness(files, table, projectPath); errors.push(...e); warnings.push(...w);
  steps.push({ name: "completeness", passed: !e.length, detail: !e.length ? "文件与五层齐全" : `${e.length} 项缺失/为空` });
  let miss: boolean;
  [e, w, miss] = stepSyntax(files, scriptsDir, strict, timeout); errors.push(...e); warnings.push(...w);
  if (miss) { degraded = true; reasons.push("syntax 检查器不可用"); }
  steps.push({ name: "syntax", passed: !e.length, detail: !e.length ? "语法检查通过" : `${e.length} 处语法错误` });
  if (["compile", "test"].includes(level)) { [e, w, miss] = stepCompile(projectPath, scriptsDir, timeout); errors.push(...e); warnings.push(...w); if (miss) { degraded = true; reasons.push("compile 检查器不可用或无有效 --project-path"); } steps.push({ name: "compile", passed: !e.length, detail: !e.length ? "编译通过" : `${e.length} 处编译错误` }); }
  else steps.push({ name: "compile", passed: true, detail: `verify_level=${level}，按约定跳过编译验证` });
  [e, w] = stepSpec(files); errors.push(...e); warnings.push(...w);
  steps.push({ name: "spec", passed: !e.length, detail: !e.length ? "符合 uctoo-v4 规范" : `${e.length} 处规范违规` });
  const fixSuggestions = stepFixSuggest(files, errors, scriptsDir, timeout);
  steps.push({ name: "fix_suggest", passed: true, detail: `产出 ${fixSuggestions.length} 条修复建议` });
  let passed = !errors.length;
  if (degraded && !errors.length) passed = false;
  const failed = steps.filter((s) => !s.passed).map((s) => s.name);
  const summary = passed ? "通过" : "未通过: " + (failed.join("; ") || "闸门降级未真正验证");
  return { tool: "code-gen-verifier", passed, verify_level: level, project_path: projectPath, files, table, degraded, degraded_reasons: reasons, on_missing_toolchain: null, steps, errors, warnings, fix_suggestions: fixSuggestions, summary, checked_at: nowCst() };
}

// 参数解析
const args = process.argv.slice(2);
let filesArg = "", filesFile = "", projectPath = "", verifyLevel = "compile", table = "", outdir = "output/verified", output = "", strict = false, timeout = 300, onMissingToolchain = "fail", cangjieScripts = "";
for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case "--files": filesArg = args[++i]; break;
    case "--files-file": filesFile = args[++i]; break;
    case "--project-path": projectPath = args[++i]; break;
    case "--verify-level": verifyLevel = args[++i]; break;
    case "--table": table = args[++i]; break;
    case "--outdir": outdir = args[++i]; break;
    case "--output": output = args[++i]; break;
    case "--strict": strict = true; break;
    case "--timeout": timeout = parseInt(args[++i]); break;
    case "--on-missing-toolchain": onMissingToolchain = args[++i]; break;
    case "--cangjie-scripts": cangjieScripts = args[++i]; break;
  }
}
let files = splitFiles(filesArg);
if (filesFile) { if (!fs.existsSync(filesFile)) { process.stderr.write(`ERROR: --files-file 不存在: ${filesFile}\n`); process.exit(2); } files.push(...splitFiles(fs.readFileSync(filesFile, "utf-8"))); }
const seen = new Set(); files = files.filter((f) => !seen.has(f) && (seen.add(f), true));
if (!files.length && !table) { process.stderr.write("ERROR: --files 与 --table 至少要提供一个\n"); process.exit(2); }
const scriptsDir = cangjieScriptsDir(cangjieScripts);
const result = verify(files, projectPath, verifyLevel, table, scriptsDir, strict, timeout);
result.on_missing_toolchain = onMissingToolchain;
if (onMissingToolchain === "warn" && result.degraded && !result.errors.length) { result.passed = true; result.summary = `通过（降级：${(result.degraded_reasons || ["部分步骤未执行"]).join("、")}）`; }
const outPath = output || path.join(outdir, "verify_code_gen.json");
fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(result, null, 2), "utf-8");
console.log(JSON.stringify({ ok: true, status: result.passed ? "passed" : "failed", degraded: result.degraded, output: outPath, summary: result.summary, error_count: result.errors.length, fix_suggestion_count: result.fix_suggestions.length }));
process.exit(result.passed ? 0 : 1);