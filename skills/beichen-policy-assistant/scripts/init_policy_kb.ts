#!/usr/bin/env node
/**
 * init_policy_kb.ts — 产业政策智能体 Step 0: 三层知识库初始化
 * 功能与 init_policy_kb.py 完全一致
 *
 * 运行方式: node --experimental-strip-types init_policy_kb.ts --seed knowledge/policy-seed.json [--kb knowledge] [--force]
 */
import * as path from "path";
import * as fs from "fs";

const __dirname = import.meta.dirname;
const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地时间 ISO（对齐 Python datetime.now().isoformat()）
function localIso(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}
// 等价 Python json.dumps(v, ensure_ascii=False)（默认分隔符 ": " / ", "，非 ASCII 不转义），
// 避免写入文件的 JSON 片段与 py 版字节不一致
function pyDumps(v: any): string {
  if (v === null) return "null";
  const t = typeof v;
  if (t === "string") return JSON.stringify(v);
  if (t === "number" || t === "boolean") return String(v);
  if (Array.isArray(v)) return "[" + v.map(pyDumps).join(", ") + "]";
  if (t === "object") {
    const ks = Object.keys(v as object);
    return ks.length ? "{" + ks.map((k) => JSON.stringify(k) + ": " + pyDumps((v as any)[k])).join(", ") + "}" : "{}";
  }
  return "null";
}

function parseArgs(): Record<string, string | boolean> {
  const args: Record<string, string | boolean> = {};
  for (let i = 2; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = process.argv[i + 1];
      if (next && !next.startsWith("--")) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    }
  }
  return args;
}

function defaultKb(): string {
  return path.normalize(path.join(__dirname, "..", "knowledge"));
}

function sanitizeFilename(s: string): string {
  if (!s) return "policy";
  let r = s.replace(/[\s\u3000]+/g, "");
  r = r.replace(/[\\/:*?"<>|]/g, "");
  return r || "policy";
}

function loadSeed(seedPath: string): any[] {
  const data = JSON.parse(fs.readFileSync(seedPath, "utf-8"));
  const policies = data.policies || [];
  if (!policies.length) {
    console.error("错误: 种子文件无 policies 数据");
    process.exit(1);
  }
  return policies;
}

function renderMarkdown(p: any): string {
  const cond = p.conditions || {};
  const region = cond.region || "";
  const qualification = cond.qualification || "";
  const industry = cond.industry || [];
  const lines = [
    "---",
    `policy_no: "${p.policy_no || ""}"`,
    `domain: ${p.domain || ""}`,
    `level: ${p.level || ""}`,
    `department: ${p.department || ""}`,
    `title: ${p.title || ""}`,
    `status: ${p.status || "active"}`,
    "conditions:",
  ];
  if (region) lines.push(`  region: ${region}`);
  if (qualification) lines.push(`  qualification: ${qualification}`);
  lines.push(`  industry: ${pyDumps(industry)}`);
  lines.push(
    `support: "${p.support || ""}"`,
    `source: ${p.source || ""}`,
    "---",
    "",
    `# ${p.title || ""}`,
    "",
    "## 政策要点",
    "",
    "（申报条件、支持方式、申报周期、材料清单——待运营方依据政策原文补全；匹配时以 front-matter 条件为准）",
    "",
    `- 所属领域：${p.domain || ""}`,
    `- 政策层级：${p.level || ""}`,
    `- 发布部门：${p.department || ""}`,
    `- 申报条件（区域）：${region || "待补充"}`,
    `- 资质要求：${qualification || "待补充"}`,
    `- 支持方式：${p.support || "待补充"}`,
    "",
  );
  return lines.join("\n");
}

function main() {
  const args = parseArgs();
  const seed = typeof args.seed === "string" ? args.seed : "";
  const kb = typeof args.kb === "string" ? args.kb : defaultKb();
  const force = args.force === true;

  if (!seed) {
    console.error("错误: --seed 必填");
    process.exit(2);
  }

  const origDir = path.join(kb, "policy-original");
  fs.mkdirSync(origDir, { recursive: true });
  for (const sub of ["policy-interpretation", "policy-insight"]) {
    fs.mkdirSync(path.join(kb, sub), { recursive: true });
  }

  const policies = loadSeed(seed);
  const index: any = {
    version: "1.0.0",
    generated_at: localIso(),
    count: policies.length,
    policies: [],
  };
  let created = 0, skipped = 0;
  for (const p of policies) {
    const no = String(p.policy_no || "").trim();
    const title = p.title || "";
    const fname = `${no}-${sanitizeFilename(title)}.md`;
    const fpath = path.join(origDir, fname);
    if (fs.existsSync(fpath) && !force) {
      skipped++;
    } else {
      fs.writeFileSync(fpath, renderMarkdown(p), "utf-8");
      created++;
    }
    index.policies.push({
      policy_no: no,
      domain: p.domain || "",
      level: p.level || "",
      department: p.department || "",
      title: title,
      status: p.status || "active",
      conditions: p.conditions || {},
      support: p.support || "",
      file: path.join("policy-original", fname),
    });
  }

  const indexPath = path.join(kb, "policy-index.json");
  fs.writeFileSync(indexPath, JSON.stringify(index, null, 2), "utf-8");

  console.log(JSON.stringify({
    success: true,
    index: indexPath,
    count: policies.length,
    created,
    skipped,
    output: indexPath,
  }));
}

main();