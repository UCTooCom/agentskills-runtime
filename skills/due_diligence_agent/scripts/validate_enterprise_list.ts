#!/usr/bin/env node
/**
 * 企业名单校验/清洗/去重（T5.1） - TypeScript 版本
 * 功能与 validate_enterprise_list.py 完全一致
 * 运行：node --experimental-strip-types scripts/validate_enterprise_list.ts [参数]
 */
import * as fs from 'node:fs';

type Dict = Record<string, any>;

const INVALID_CHAR_PATTERN = /[\x00-\x1f\x7f-\x9f]/;
// Python 的 ^[\s\W_]+$ 在 Unicode 模式下等价于"不包含任何 Unicode 字母或数字"
const PURE_PUNCT_PATTERN = /^[^\p{L}\p{N}]+$/u;

interface ValidationResult {
  valid: boolean;
  enterprises: string[];
  invalid_entries: { original: string; reason: string }[];
  duplicates_removed: string[];
  scene: string;
  error: string | null;
}

function validateAndClean(enterprises: string[], scene: string = ''): ValidationResult {
  if (!enterprises || enterprises.every(e => e.trim() === '')) {
    return {
      valid: false,
      enterprises: [],
      invalid_entries: [],
      duplicates_removed: [],
      scene,
      error: '企业名单不能为空'
    };
  }

  const seen = new Set<string>();
  const validEnterprises: string[] = [];
  const invalidEntries: { original: string; reason: string }[] = [];
  const duplicatesRemoved: string[] = [];

  for (const raw of enterprises) {
    const cleaned = raw.trim();
    if (!cleaned) continue;

    if (INVALID_CHAR_PATTERN.test(cleaned)) {
      invalidEntries.push({ original: raw, reason: '含控制字符/非法字符' });
      continue;
    }

    if (PURE_PUNCT_PATTERN.test(cleaned)) {
      invalidEntries.push({ original: raw, reason: '纯标点/符号，非有效企业名称' });
      continue;
    }

    if (seen.has(cleaned)) {
      duplicatesRemoved.push(cleaned);
      continue;
    }

    seen.add(cleaned);
    validEnterprises.push(cleaned);
  }

  if (validEnterprises.length === 0) {
    return {
      valid: false,
      enterprises: [],
      invalid_entries: invalidEntries,
      duplicates_removed: duplicatesRemoved,
      scene,
      error: '企业名单不能为空（所有条目均无效）'
    };
  }

  return {
    valid: true,
    enterprises: validEnterprises,
    invalid_entries: invalidEntries,
    duplicates_removed: duplicatesRemoved,
    scene,
    error: null
  };
}

function main(): void {
  const args = process.argv.slice(2);
  let input = '';
  let inputFile = '';
  let scene = '';

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--input' && i + 1 < args.length) input = args[++i];
    else if (args[i] === '--input-file' && i + 1 < args.length) inputFile = args[++i];
    else if (args[i] === '--scene' && i + 1 < args.length) scene = args[++i];
  }

  const validScenes = ['', 'supplier', 'credit', 'investment', 'competitor', 'related_risk'];
  if (!validScenes.includes(scene)) {
    console.error(`错误：--scene 必须是 ${validScenes.filter(s => s).join(', ')} 之一`);
    process.exit(1);
  }

  let enterprises: string[] = [];
  if (inputFile) {
    const content = fs.readFileSync(inputFile, 'utf-8');
    enterprises = content.split(/\r?\n/);
  } else if (input) {
    enterprises = input.split(',');
  } else {
    console.log(JSON.stringify({
      valid: false, enterprises: [], invalid_entries: [],
      duplicates_removed: [], scene,
      error: '请通过 --input 或 --input-file 提供企业名单'
    }, null, 2));
    process.exit(1);
  }

  const result = validateAndClean(enterprises, scene);
  console.log(JSON.stringify(result, null, 2));

  if (!result.valid) {
    process.exit(1);
  }
}

main();