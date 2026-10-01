#!/usr/bin/env node
/**
 * cangjie_fix_suggest.ts — 仓颉代码修复建议脚本
 * 功能与 cangjie_fix_suggest.py 完全一致
 *
 * 用法:
 *   node --experimental-strip-types cangjie_fix_suggest.ts --file /path/to/file.cj --error "error output"
 */
import * as fs from "fs";
import * as path from "path";

const COMMON_FIXES: Record<string, any> = {
  "type mismatch": { Int32: "Int64", Int: "Int64", Float: "Float64" },
  "cannot find module": { suggestion: "检查import语句和cjpm.toml依赖配置" },
  "cannot find symbol": { suggestion: "检查标识符拼写和导入语句" },
  "cjc-version mismatch": { suggestion: "更新SDK或修改cjpm.toml中的cjc-version字段" },
  "circular dependency": { suggestion: "运行cjpm check检查依赖，重构代码移除循环依赖" },
};

interface Suggestion { line: number; description: string; original: string; suggested: string; confidence: number; }
interface FixResult { tool: string; file_path: string; suggestions: Suggestion[]; auto_fixable: boolean; }

function parseErrors(errorOutput: string): any[] {
  const errors: any[] = [];
  const patterns = [/^(.+?):(\d+):(\d+):\s*error:\s*(.+)/, /^(.+?):(\d+):\s*error:\s*(.+)/, /^error:\s*(.+)/];
  for (const line of errorOutput.split(/\r?\n/)) {
    const l = line.trim();
    if (!l) continue;
    for (const p of patterns) {
      const m = p.exec(l);
      if (m) {
        if (m.length === 5) errors.push({ file: m[1], line: parseInt(m[2]), column: parseInt(m[3]), message: m[4] });
        else if (m.length === 4) errors.push({ file: m[1], line: parseInt(m[2]), message: m[3] });
        else if (m.length === 2) errors.push({ file: "", line: 0, message: m[1] });
        break;
      }
    }
  }
  return errors;
}

function generateSuggestionsForError(message: string, lineNum: number, lines: string[]): Suggestion[] {
  const suggestions: Suggestion[] = [];
  for (const [errorType, fixes] of Object.entries(COMMON_FIXES)) {
    if (message.toLowerCase().includes(errorType.toLowerCase())) {
      if (errorType === "type mismatch") {
        for (const [oldType, newType] of Object.entries(fixes)) {
          if (message.includes(oldType)) {
            if (lineNum > 0 && lineNum <= lines.length) {
              const originalLine = lines[lineNum - 1].replace(/\r?\n$/, "");
              if (originalLine.includes(oldType)) {
                suggestions.push({
                  line: lineNum, description: `将${oldType}改为${newType}`,
                  original: originalLine.trim(), suggested: originalLine.replace(oldType, newType).trim(), confidence: 0.9,
                });
              }
            }
          }
        }
      } else {
        suggestions.push({
          line: lineNum, description: fixes.suggestion || message,
          original: lineNum > 0 && lineNum <= lines.length ? lines[lineNum - 1].trim() : "",
          suggested: "", confidence: 0.6,
        });
      }
    }
  }
  if (message.toLowerCase().includes("unused")) {
    if (lineNum > 0 && lineNum <= lines.length) {
      const originalLine = lines[lineNum - 1].replace(/\r?\n$/, "");
      suggestions.push({
        line: lineNum, description: "移除未使用的声明或添加使用",
        original: originalLine.trim(), suggested: `// ${originalLine.trim()}  // 未使用，暂时注释`, confidence: 0.5,
      });
    }
  }
  if (message.toLowerCase().includes("missing") && message.toLowerCase().includes("return")) {
    if (lineNum > 0 && lineNum <= lines.length) {
      suggestions.push({
        line: lineNum, description: "添加缺失的return语句",
        original: lines[lineNum - 1].trim(), suggested: "return None  // 添加默认返回值", confidence: 0.4,
      });
    }
  }
  if (suggestions.length === 0) {
    suggestions.push({
      line: lineNum, description: `无法自动修复: ${message}`,
      original: lineNum > 0 && lineNum <= lines.length ? lines[lineNum - 1].trim() : "",
      suggested: "", confidence: 0.0,
    });
  }
  return suggestions;
}

function generateFixSuggestions(filePath: string, errorOutput: string): FixResult {
  const result: FixResult = { tool: "cangjie_fix_suggest", file_path: filePath, suggestions: [], auto_fixable: false };
  let lines: string[];
  try { lines = fs.readFileSync(filePath, "utf-8").split(/\r?\n/); }
  catch (e: any) {
    result.suggestions.push({ line: 0, description: `文件不存在: ${filePath}`, original: "", suggested: "", confidence: 0.0 });
    return result;
  }
  const errorLines = parseErrors(errorOutput);
  for (const errorInfo of errorLines) {
    const lineNum = errorInfo.line || 0;
    const message = errorInfo.message || "";
    const fileRef = errorInfo.file || "";
    if (fileRef && !filePath.endsWith(fileRef.replace(/\//g, path.sep))) continue;
    result.suggestions.push(...generateSuggestionsForError(message, lineNum, lines));
  }
  if (result.suggestions.length > 0) {
    result.auto_fixable = result.suggestions.some((s) => s.confidence >= 0.8);
  }
  return result;
}

// 参数解析
const args = process.argv.slice(2);
let file = "", error = "";
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--file") file = args[++i];
  else if (args[i] === "--error") error = args[++i];
}
if (!file || !error) { console.error("用法: node cangjie_fix_suggest.ts --file <path> --error <error_output>"); process.exit(2); }
const result = generateFixSuggestions(file, error);
console.log(JSON.stringify(result, null, 2));
process.exit(0);