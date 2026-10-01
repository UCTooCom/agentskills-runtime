#!/usr/bin/env node
/**
 * _tmp_read_pending.ts — 临时脚本：读取 pending 流水和 policy-index 并打印统计
 * 功能与 _tmp_read_pending.py 完全一致
 *
 * 运行方式: node --experimental-strip-types _tmp_read_pending.ts
 */
import * as fs from "fs";

const pendingPath = "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/beichen-policy-assistant/output/pending/2026-09-11.json";
const idxPath = "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/skills/beichen-policy-assistant/knowledge/policy-index.json";

const p = JSON.parse(fs.readFileSync(pendingPath, "utf-8"));
console.log("=== PENDING 2026-09-11 ===");
console.log("count:", p.count, "fetched_at:", p.fetched_at);
let i = 1;
for (const it of (p.items || [])) {
  console.log(`[${i}] status=${it.status} | url=${it.url}`);
  console.log(`    title=${it.title}`);
  console.log(`    dept=${it.department} | level=${it.level} | domain=${it.domain} | date=${it.published_date}`);
  if (it.error) {
    console.log(`    ERROR=${it.error}`);
  }
  i++;
}

const idx = JSON.parse(fs.readFileSync(idxPath, "utf-8"));
console.log("\n=== POLICY INDEX ===");
console.log("count:", idx.count, "generated_at:", idx.generated_at);

const dom: Record<string, number> = {};
const lvl: Record<string, number> = {};
const dg: Record<string, any[]> = {};
for (const pol of (idx.policies || [])) {
  const d = pol.domain;
  const l = pol.level;
  dom[d] = (dom[d] || 0) + 1;
  lvl[l] = (lvl[l] || 0) + 1;
  if (!dg[d]) dg[d] = [];
  dg[d].push(pol);
}

console.log("--- by domain ---");
for (const [d, c] of Object.entries(dom)) {
  console.log(`${d}: ${c}`);
}
console.log("--- by level ---");
for (const [l, c] of Object.entries(lvl)) {
  console.log(`${l}: ${c}`);
}
console.log("--- titles by domain ---");
for (const [d, lst] of Object.entries(dg)) {
  console.log(`\n[${d}]`);
  for (const pol of lst) {
    console.log(`  ${pol.policy_no}. ${pol.title} (${pol.level} / ${pol.department})`);
  }
}
console.log("\nDONE");