#!/usr/bin/env node
/**
 * cangjie_syntax_check.ts — 仓颉代码语法检查脚本
 * 功能与 cangjie_syntax_check.py 完全一致
 *
 * 用法:
 *   node --experimental-strip-types cangjie_syntax_check.ts --file /path/to/file.cj [--strict]
 *
 * 输出: JSON格式的检查结果
 */
import * as fs from "fs";

const CANGJIE_KEYWORDS = new Set([
  "Bool", "Rune", "Float16", "Float32", "Float64",
  "Int8", "Int16", "Int32", "Int64", "IntNative",
  "UInt8", "UInt16", "UInt32", "UInt64", "UIntNative",
  "Array", "VArray", "String", "Nothing", "Unit",
  "break", "case", "catch", "continue", "do", "else",
  "finally", "for", "if", "match", "return", "spawn",
  "try", "throw", "while",
  "as", "abstract", "class", "const", "enum", "extend",
  "func", "foreign", "import", "init", "interface",
  "let", "macro", "main", "mut", "open", "operator",
  "override", "package", "private", "prop", "protected",
  "public", "redef", "static", "struct", "super",
  "synchronized", "this", "This", "type", "unsafe", "where",
  "false", "true", "quote",
]);

interface Issue {
  line: number;
  column: number;
  message: string;
  severity: string;
  category: string;
}

interface CheckResult {
  tool: string;
  file_path: string;
  passed: boolean;
  issues: Issue[];
  warnings: Issue[];
}

function checkSyntax(filePath: string, strict: boolean = false): CheckResult {
  const result: CheckResult = {
    tool: "cangjie_syntax_check",
    file_path: filePath,
    passed: true,
    issues: [],
    warnings: [],
  };

  let lines: string[];
  try {
    const content = fs.readFileSync(filePath, "utf-8");
    lines = content.split(/\r?\n/);
    // 对齐 py str.splitlines()：去掉尾随换行产生的尾部空元素（空文件 → []，
    // 否则空文件会误报"缺少package声明"，两版对空文件的退出码不同）
    if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
  } catch (e: any) {
    result.passed = false;
    result.issues.push({
      line: 0, column: 0,
      message: e.code === "ENOENT" ? `文件不存在: ${filePath}` : `文件读取失败: ${e.message}`,
      severity: "error", category: "file",
    });
    return result;
  }

  checkPackageDeclaration(lines, result);
  checkImportStatements(lines, result);
  checkVariableDeclarations(lines, result, strict);
  checkFunctionDeclarations(lines, result, strict);
  checkClassDeclarations(lines, result, strict);
  checkErrorHandling(lines, result, strict);
  checkNamingConventions(lines, result, strict);

  if (result.issues.length > 0) result.passed = false;
  return result;
}

function checkPackageDeclaration(lines: string[], result: CheckResult): void {
  let hasPackage = false;
  for (let i = 0; i < lines.length; i++) {
    const stripped = lines[i].trim();
    if (stripped.startsWith("package ")) { hasPackage = true; break; }
    if (stripped && !stripped.startsWith("//") && !stripped.startsWith("/*")) {
      if (!stripped.startsWith("import ")) break;
    }
  }
  if (!hasPackage && lines.length > 0) {
    result.warnings.push({ line: 1, column: 1, message: "文件缺少package声明", severity: "warning", category: "package" });
  }
}

function checkImportStatements(lines: string[], result: CheckResult): void {
  let codeStarted = false;
  for (let i = 0; i < lines.length; i++) {
    const stripped = lines[i].trim();
    if (stripped.startsWith("import ")) {
      if (codeStarted) {
        result.issues.push({ line: i + 1, column: 1, message: "import语句应在文件顶部，package声明之后", severity: "warning", category: "import" });
      }
    } else if (stripped && !stripped.startsWith("//") && !stripped.startsWith("/*")) {
      codeStarted = true;
    }
  }
}

function checkVariableDeclarations(lines: string[], result: CheckResult, strict: boolean): void {
  const varPattern = /^\s*(let|var|const)\s+(\w+)\s*:\s*(\w+)/;
  for (let i = 0; i < lines.length; i++) {
    const stripped = lines[i].trim();
    if (stripped.startsWith("//") || stripped.startsWith("/*") || stripped.startsWith("*")) continue;
    const match = varPattern.exec(stripped);
    if (match) {
      const declType = match[1], varName = match[2];
      if (strict && declType === "var") {
        result.warnings.push({ line: i + 1, column: 1, message: `建议使用let替代var声明不可变变量 '${varName}'`, severity: "warning", category: "best_practice" });
      }
    }
  }
}

function checkFunctionDeclarations(lines: string[], result: CheckResult, strict: boolean): void {
  const funcPattern = /^\s*func\s+(\w+)\s*\(/;
  for (let i = 0; i < lines.length; i++) {
    const stripped = lines[i].trim();
    const match = funcPattern.exec(stripped);
    if (match) {
      const funcName = match[1];
      if (strict && funcName[0] !== funcName[0].toLowerCase()) {
        result.warnings.push({ line: i + 1, column: 1, message: `函数名 '${funcName}' 应使用camelCase命名`, severity: "warning", category: "naming" });
      }
    }
  }
}

function checkClassDeclarations(lines: string[], result: CheckResult, strict: boolean): void {
  const classPattern = /^\s*(public\s+|open\s+|abstract\s+)*(class|struct|enum|interface)\s+(\w+)/;
  for (let i = 0; i < lines.length; i++) {
    const stripped = lines[i].trim();
    const match = classPattern.exec(stripped);
    if (match) {
      const modifiers = match[1] || "", typeKeyword = match[2], typeName = match[3];
      if (strict && typeKeyword === "class" && !modifiers.includes("public")) {
        result.warnings.push({ line: i + 1, column: 1, message: `类 '${typeName}' 建议添加public修饰符`, severity: "warning", category: "visibility" });
      }
    }
  }
}

function checkErrorHandling(lines: string[], result: CheckResult, strict: boolean): void {
  let hasTryCatch = false, hasOption = false, hasThrow = false;
  for (const line of lines) {
    const stripped = line.trim();
    if (stripped.includes("try") && stripped.includes("{")) hasTryCatch = true;
    if (stripped.includes("Option<") || stripped.includes("?Int") || stripped.includes("?String")) hasOption = true;
    if (stripped.includes("throw")) hasThrow = true;
  }
  if (strict && !hasTryCatch && !hasOption) {
    result.warnings.push({ line: 0, column: 0, message: "文件未使用try-catch或Option<T>进行错误处理", severity: "warning", category: "error_handling" });
  }
}

function checkNamingConventions(lines: string[], result: CheckResult, strict: boolean): void {
  for (let i = 0; i < lines.length; i++) {
    const stripped = lines[i].trim();
    if (stripped.startsWith("//") || stripped.startsWith("/*")) continue;
    if (stripped.includes("Int") && !stripped.includes("Int32") && !stripped.includes("Int64") && !stripped.includes("Int8") && !stripped.includes("Int16")) {
      if (/\bInt\b/.test(stripped) && !stripped.includes("Int64")) {
        if (strict) {
          result.warnings.push({ line: i + 1, column: 0, message: "建议使用Int64替代Int，显式指定整数位宽", severity: "warning", category: "type_safety" });
        }
      }
    }
  }
}

// 简单参数解析
function parseArgs(): { file: string; strict: boolean } {
  const args = process.argv.slice(2);
  let file = "", strict = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--file") file = args[++i];
    else if (args[i] === "--strict") strict = true;
  }
  if (!file) {
    console.error("用法: node cangjie_syntax_check.ts --file <path> [--strict]");
    process.exit(2);
  }
  return { file, strict };
}

const { file, strict } = parseArgs();
const result = checkSyntax(file, strict);
console.log(JSON.stringify(result, null, 2));
process.exit(result.passed ? 0 : 1);