#!/usr/bin/env node
/**
 * verify_summary.ts — beichen-policy-assistant 技能：验证政策摘要报告
 * 功能与 verify_summary.py 完全一致
 *
 * 运行方式: node --experimental-strip-types verify_summary.ts
 */
import * as path from "path";
import * as fs from "fs";

const __dirname = import.meta.dirname;

const p = path.join(__dirname, "..", "output", "reports", "policy-summary-2026-09-11.md");
const d = fs.readFileSync(p, "utf-8");
const lines = d.split(/\r?\n/);
console.log("exists=%s", fs.existsSync(p));
console.log("bytes=%d", Buffer.byteLength(d, "utf-8"));
console.log("lines=%d", lines.length);
console.log("h2_sections=%d", lines.filter((l) => l.startsWith("## ")).length);
console.log("table_rows=%d", lines.filter((l) => l.startsWith("| ")).length);
console.log("has_row_74=%s", lines.some((l) => l.startsWith("| 74 |")));
console.log("has_row_1=%s", lines.some((l) => l.startsWith("| 1 |")));
console.log("has_disclaimer=%s", lines.some((l) => l.includes("不构成法律意见")));
console.log("has_pending_section=%s", lines.some((l) => l.includes("最新政策动态")));