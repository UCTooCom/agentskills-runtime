#!/usr/bin/env node
/**
 * cangjie_precompile_scan.ts — 仓颉「编译前一轮排净」静态扫描脚本
 * 功能与 cangjie_precompile_scan.py 完全一致
 *
 * 背景:
 *   cjpm/cjc 按包编译，某包失败即中止该包检查；未轮到的包、以及本包
 *   尚未检查到的文件，其同类错误**不会出现在这一轮日志里**。修复因而沦为
 *   "报错 → 改 → 再编译 → 再报错"的多轮往返。本脚本在修复前/后把形态固定的
 *   高频编译错误做一次全域扫描，让一轮修复真正修干净。
 *
 * 用法:
 *   node --experimental-strip-types cangjie_precompile_scan.ts --src <源码根> [--quiet] [--json]
 *
 * 规则:
 *   E1 后置 `?` 类型注解（Rust 风格）：仓颉可选类型是**前置** `?T`
 *   E2 match 臂多语句块 `case X => {`：`{` 会被解析为 lambda 起始
 *   E4 `Array<T>` 变量调用了只有 ArrayList 才有的增删方法
 *   E5 if/while/for 的分支体没写花括号（`do{...}while(cond)` 的尾 while 除外）
 *   E6 main 无返回类型标注、且函数体末句是返回 Nothing 的调用（如 std.env.exit）
 *   W1 `let` 声明的变量被重新赋值（不可变变量）
 *   （E3「缺 std.collection import」已实证为误报而废止）
 */
import * as fs from "fs";
import * as path from "path";
import { pathToFileURL } from "url";

interface Issue {
  rule: string;
  severity: "ERROR" | "WARN";
  file: string;
  line: number;
  message: string;
  hint: string;
  snippet: string;
}

// Array<T> 上没有、只有 ArrayList 等动态容器才有的方法
export const MUTATING_METHODS = ["add", "append", "remove", "insert", "clear"];

// 行尾出现 `=> {`
const MATCH_ARM_BLOCK_RE = /=>\s*\{\s*$/;
// 语句级赋值：`  name = ...`
const ASSIGN_STMT_RE = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)/;
// let/var 声明
const DECL_RE = /^\s*(let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*([^=]+?))?\s*=/;
// 函数/方法签名起点：用于划分 W1 的作用域边界
const FUNC_SIG_RE =
  /^\s*(?:(?:public|protected|private|internal)\s+)?(?:(?:static|open|override|abstract|redef|mut|unsafe)\s+)*(?:func|init|operator func)\s/;
// E1: `: Type?` 后置问号
const POSTFIX_OPTION_RE =
  /:\s*([A-Za-z_][A-Za-z0-9_]*(?:\s*<[^{};()]*(?:\s*<[^{};()]*>\s*)?>)?)\s*\?(?=\s*(?:=|;|,|\)|$))/;
// E5: if/while/for 的条件括号起点（前置 do{} 右括号的情况由调用方排除）
const CTRL_FLOW_RE = /(?:(?<=^)|(?<=[\s};]))(if|while|for)\s*\(/;
// E6: 返回 bottom type 的已知调用（见 checkE6）
const NOTHING_RETURN_CALLS = ["exit"];
// E6: main 且**没有**显式返回类型标注（`)` 之后直接是 `{`）
const MAIN_NO_RET_RE = /^main\s*\([^)]*\)\s*\{/;

function stripComment(line: string): string {
  const idx = line.indexOf("//");
  return idx >= 0 ? line.slice(0, idx) : line;
}

function findCjFiles(root: string): string[] {
  const st = fs.statSync(root);
  if (!st.isDirectory()) return root.endsWith(".cj") ? [root] : [];
  const out: string[] = [];
  const walk = (dir: string) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith(".cj")) out.push(p);
    }
  };
  walk(root);
  return out.sort();
}

/** E1: 后置 `?` 类型注解（Rust 风格）。仓颉可选类型是前置 `?T`。 */
export function checkE1(lines: string[], rel: string, issues: Issue[]): void {
  lines.forEach((raw, idx) => {
    const line = stripComment(raw);
    if (!line.includes("?")) return;
    const m = POSTFIX_OPTION_RE.exec(line);
    if (!m) return;
    issues.push({
      rule: "E1",
      severity: "ERROR",
      file: rel,
      line: idx + 1,
      message: "后置 `?` 类型注解（Rust 风格）。仓颉可选类型是前置 `?T`",
      hint: `改为 \`?${m[1]}\` 或 \`Option<${m[1]}>\``,
      snippet: line.trim(),
    });
  });
}

/**
 * E2: `case X => {` —— `{` 被解析为 lambda 起始，块内首条语句会报
 * `expected '=>' in lambda expression`。
 * 合法例外：下一行去空白后以裸 `=>` 开头（零参 lambda 写法）。
 * 注意：src/test/ 下不在主 build 图中，其形态不可作为合法先例。
 */
export function checkE2(lines: string[], rel: string, issues: Issue[]): void {
  lines.forEach((raw, idx) => {
    if (!MATCH_ARM_BLOCK_RE.test(stripComment(raw))) return;
    const next = idx + 1 < lines.length ? lines[idx + 1].trim() : "";
    if (next.startsWith("=>")) return; // 零参 lambda，合法
    issues.push({
      rule: "E2",
      severity: "ERROR",
      file: rel,
      line: idx + 1,
      message: "match 臂写了 `{` 多语句块，会被解析为 lambda 起始",
      hint: "改为 if/else 分支表达式，或把逻辑外提成函数，臂只留单表达式",
      snippet: stripComment(raw).trim(),
    });
  });
}

/** E4: `Array<T>` 是定长数组，没有 add/append/remove 等方法。 */
export function checkE4(lines: string[], rel: string, issues: Issue[]): void {
  const text = lines.map(stripComment);
  const declared = new Map<string, { type: string }>();
  text.forEach((l) => {
    const m = DECL_RE.exec(l);
    if (m && m[3]) {
      const type = m[3].trim();
      if (!declared.has(m[2])) declared.set(m[2], { type });
    }
  });
  declared.forEach((info, name) => {
    if (!/^Array\s*</.test(info.type)) return;
    text.forEach((l, idx) => {
      for (const meth of MUTATING_METHODS) {
        const re = new RegExp(`\\b${name}\\.${meth}\\s*\\(`);
        if (re.test(l)) {
          issues.push({
            rule: "E4",
            severity: "ERROR",
            file: rel,
            line: idx + 1,
            message: `\`${name}\` 声明为 \`${info.type}\`（定长），却调用了 \`.${meth}()\``,
            hint: "若需动态增删改用 ArrayList<T>（属 prelude，无需 import）",
            snippet: l.trim(),
          });
        }
      }
    });
  });
}

/**
 * E5: if/while/for 的分支体必须是代码块 `{...}`。
 *
 * 语法依据（language.basic_concepts.3-表达式.3-2-if-条件判断）：
 *   `if (cond) { exprs1 } else { exprs2 }` / `while (cond) { exprs }`
 * 花括号是语法的一部分，**不能省**，分支体不能只写单个表达式。
 * 典型报错：`expected '{', found 'XXX'`。
 *
 * 合法例外（必须内置，否则会误报）：
 *   `do { exprs } while (cond)` —— 尾部 while 是**语句终结符**，本就无块。
 *   判据：该行去空白后以 `}` 开头。实证：src/dsl/parser.cj:34/46。
 *
 * 必须用括号配平而非 `\)\s*[^ {]`：正则会把 `if (hasValue(args, idx)) {` 里
 * `hasValue(...)` 的**第一个** `)` 当成条件结束，在本仓 installer/src 上
 * 一次性炸出 20 条假阳性。
 */
export function checkE5(lines: string[], rel: string, issues: Issue[]): void {
  const text = lines.map(stripComment);
  text.forEach((code, idx) => {
    const n = idx + 1;
    const gre = new RegExp(CTRL_FLOW_RE.source, "g");
    let m: RegExpExecArray | null;
    while ((m = gre.exec(code)) !== null) {
      const kw = m[1];
      let j = m.index + m[0].length - 1; // 指向 '('
      let depth = 0;
      while (j < code.length) {
        if (code[j] === "(") depth++;
        else if (code[j] === ")") {
          depth--;
          if (depth === 0) break;
        }
        j++;
      }
      if (j >= code.length || depth !== 0) continue; // 条件跨行，本规则不处理
      // do { } while (cond) 的尾子句合法且必无块，两个分支都要排除
      if (kw === "while" && code.trim().startsWith("}")) continue;
      const rest = code.slice(j + 1).trim();
      if (!rest) {
        const nxt = text[n] !== undefined ? text[n].trim() : "";
        if (!nxt.startsWith("{")) {
          issues.push({
            rule: "E5",
            severity: "ERROR",
            file: rel,
            line: n,
            message: `\`${kw}\` 条件在行尾，但下一行不是 \`{\``,
            hint: "仓颉分支体必须是代码块 `{...}`，不能只写单个表达式",
            snippet: code.trim(),
          });
        }
        continue;
      }
      if (rest.startsWith("{")) continue;
      issues.push({
        rule: "E5",
        severity: "ERROR",
        file: rel,
        line: n,
        message: `\`${kw}\` 条件之后的分支体不是代码块`,
        hint: `写成 \`${kw} (cond) { ... }\`；用作值时同理：\`let x = if (c) { a } else { b }\``,
        snippet: code.trim(),
      });
    }
  });
}

/**
 * 从函数签名行起做花括号配平，返回 body 内最后一个有效语句。
 * 必须剔除字符串字面量与注释：否则 sb.append("{") 里的花括号会被当成代码块，
 * 使 body「提前收尾」，末句判定失准。
 */
export function findBodyLastStmt(lines: string[], startIdx: number): [number, string] {
  let depth = 0;
  let started = false;
  let lastLn = -1;
  let lastTxt = "";
  let inStr = false;
  let triple = false;
  for (let i = startIdx; i < lines.length; i++) {
    const raw = inStr ? lines[i] : stripComment(lines[i]);
    let j = 0;
    while (j < raw.length) {
      const c = raw[j];
      if (inStr) {
        if (triple && raw.slice(j, j + 3) === '"""') {
          inStr = false;
          triple = false;
          j += 3;
          continue;
        }
        if (!triple && c === '"') {
          inStr = false;
          j += 1;
          continue;
        }
        if (!triple && c === "\\") {
          j += 2;
          continue;
        }
        j += 1;
        continue;
      }
      if (raw.slice(j, j + 3) === '"""') {
        inStr = true;
        triple = true;
        j += 3;
        continue;
      }
      if (c === '"') {
        inStr = true;
        triple = false;
        j += 1;
        continue;
      }
      if (c === "{") {
        depth += 1;
        started = true;
      } else if (c === "}") {
        depth -= 1;
        if (started && depth <= 0) return [lastLn, lastTxt];
      }
      j += 1;
    }
    const t = raw.trim();
    if (started && t) {
      lastLn = i + 1;
      lastTxt = t;
    }
  }
  return [lastLn, lastTxt];
}

/**
 * E6: main 没有显式返回类型标注，且函数体末句是返回 Nothing 的调用。
 * 报错原文：`return type of 'main' is not 'Integer' or 'Unit'`。
 * 根因：省略返回类型时按函数体最后一个表达式推断；`std.env.exit(code: Int64): Nothing`
 * 是 bottom type，推断结果即 Nothing，而 main 的返回类型只允许 Unit 或整数类型。
 */
export function checkE6(lines: string[], rel: string, issues: Issue[]): void {
  lines.forEach((raw, idx) => {
    const code = stripComment(raw).trim();
    if (!MAIN_NO_RET_RE.test(code)) return;
    const [, lastStmt] = findBodyLastStmt(lines, idx);
    if (!lastStmt) return;
    const hit = NOTHING_RETURN_CALLS.find((name) =>
      new RegExp(`(?<![A-Za-z0-9_.])${name}\\s*\\(`).test(lastStmt)
    );
    if (!hit) return;
    issues.push({
      rule: "E6",
      severity: "ERROR",
      file: rel,
      line: idx + 1,
      message: `main 未标注返回类型，而函数体末句是返回 Nothing 的 \`${hit}(...)\` 调用`,
      hint: "显式标注 `main(args: Array<String>): Unit`（或改为返回整数类型后用 return 退出）",
      snippet: code,
    });
  });
}

/**
 * W1: `let` 声明的变量被重新赋值 → `cannot assign to immutable value`。
 * 作用域近似：以函数/方法签名为边界，取作用域内每个名字「最后一次」声明的 kind。
 *
 * 教训：早先用「整个文件的 let 名字集合」判定，在本仓 src/ 上炸出 564 条误报
 * ——典型如 agent_task.cj：387 行是 `let toolResult`（某方法内），416 行在另一
 * 方法里是 `var toolResult`，424 行的合法赋值因此被误报。静态检查必须划作用域。
 */
export function checkW1(lines: string[], rel: string, issues: Issue[]): void {
  const text = lines.map(stripComment);
  const lastKind = new Map<string, string>();
  const declaredAt = new Map<string, number>();
  text.forEach((l, idx) => {
    const n = idx + 1;
    if (FUNC_SIG_RE.test(l)) {
      lastKind.clear();
      declaredAt.clear();
      return;
    }
    const d = DECL_RE.exec(l);
    if (d) {
      lastKind.set(d[2], d[1]);
      declaredAt.set(d[2], n);
      return;
    }
    const a = ASSIGN_STMT_RE.exec(l);
    if (!a) return;
    const name = a[1];
    if (lastKind.get(name) !== "let") return;
    issues.push({
      rule: "W1",
      severity: "WARN",
      file: rel,
      line: n,
      message: `\`${name}\` 于第 ${declaredAt.get(name) ?? "?"} 行由 \`let\` 声明（不可变），此处却在重新赋值`,
      hint: "改为 `var`；若是类成员的 prop setter 或跨作用域同名，可忽略",
      snippet: l.trim(),
    });
  });
}

export function scanFile(file: string, root: string): Issue[] {
  let content: string;
  try {
    content = fs.readFileSync(file, "utf-8");
  } catch (e) {
    return [{ rule: "E0", severity: "ERROR", file, line: 0, message: `读取失败: ${e}`, hint: "", snippet: "" }];
  }
  const lines = content.split(/\r?\n/);
  const rel = path.relative(root, file) || path.basename(file);
  const issues: Issue[] = [];
  checkE1(lines, rel, issues);
  checkE2(lines, rel, issues);
  checkE4(lines, rel, issues);
  checkE5(lines, rel, issues);
  checkE6(lines, rel, issues);
  checkW1(lines, rel, issues);
  return issues;
}

interface ScanResult {
  scanned_files: number;
  root: string;
  error_count: number;
  warn_count: number;
  passed: boolean;
  issues: Issue[];
}

export function scan(rootPath: string): ScanResult {
  const files = findCjFiles(rootPath);
  const all: Issue[] = [];
  for (const f of files) all.push(...scanFile(f, rootPath));
  const errors = all.filter((i) => i.severity === "ERROR");
  const warns = all.filter((i) => i.severity === "WARN");
  return {
    scanned_files: files.length,
    root: rootPath,
    error_count: errors.length,
    warn_count: warns.length,
    passed: errors.length === 0,
    issues: all,
  };
}

// 简单参数解析
function parseArgs(): { root: string; json: boolean; quiet: boolean } {
  const args = process.argv.slice(2);
  let root = ".";
  let json = false;
  let quiet = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--src") root = args[++i];
    else if (args[i] === "--json") json = true;
    else if (args[i] === "--quiet") quiet = true;
    else if (!args[i].startsWith("--")) root = args[i];
  }
  return { root, json, quiet };
}

// package.json 为 "type": "module"（ESM），故不能用 require.main 判定入口，
// 改用 import.meta.url 与 argv[1] 比对。
const invokedDirectly =
  process.argv[1] !== undefined &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;
if (invokedDirectly) {
  run();
}

function run(): void {
  const { root, json, quiet } = parseArgs();
  const abs = path.resolve(root);
  if (!fs.existsSync(abs)) {
    console.log(JSON.stringify({ error: `path not found: ${abs}` }));
    process.exit(2);
  }
  const result = scan(abs);
  if (json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    if (!quiet) {
      for (const i of result.issues) {
        console.log(`[${i.severity}][${i.rule}] ${i.file}:${i.line}`);
        console.log(`    ${i.message}`);
        if (i.hint) console.log(`    -> ${i.hint}`);
        if (i.snippet) console.log(`    | ${i.snippet}`);
        console.log("");
      }
      console.log("=".repeat(60));
    }
    console.log(
      `扫描 ${result.scanned_files} 个 .cj 文件 | ERROR=${result.error_count} WARN=${result.warn_count} | ${
        result.passed ? "可提交编译" : "需修完 ERROR 再编译"
      }`
    );
  }
  process.exit(result.passed ? 0 : 1);
}
