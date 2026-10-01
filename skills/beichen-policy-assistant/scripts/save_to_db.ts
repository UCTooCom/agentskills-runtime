#!/usr/bin/env node
/**
 * save_to_db.ts — 产业政策智能体 Step 5: 结果落库
 * 功能与 save_to_db.py 完全一致
 *
 * 运行方式: node --experimental-strip-types save_to_db.ts --profile {画像json} --report {报告md} --matches {匹配json} [--sql-only]
 */
import * as path from "path";
import * as fs from "fs";
import * as crypto from "crypto";

const __dirname = import.meta.dirname;
const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地日期 YYYY-MM-DD（对齐 Python datetime.now()，Python 用本地时间）
function localDateStr(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}
// 本地时间 ISO（对齐 Python datetime.now().isoformat()）
function localIso(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}
// 等价 Python json.dumps(v, ensure_ascii=False)（默认分隔符 ": " / ", "，非 ASCII 不转义），
// 保证写入 SQL 的 JSONB 字面量与 py 版逐字节一致
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

function defaultOutdir(): string {
  return path.normalize(path.join(__dirname, "..", "output", "sql"));
}

function esc(s: any): string {
  return String(s || "").replace(/\\/g, "\\\\").replace(/'/g, "''");
}

function buildCompanyUpsert(profile: any): string {
  const name = esc(profile.company_name || "");
  const region = esc(profile.region || "北京市朝阳区");
  const desc = esc(profile.summary || profile.company_name || "");
  return [
    `UPDATE public.company SET org_description = '${desc}', region = '${region}', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP WHERE company_name = '${name}' AND deleted_at IS NULL;`,
    `INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '${name}', '${region}', '${desc}', 'beichen-enterprise', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '${name}' AND deleted_at IS NULL);`,
  ].join("\n");
}

function buildTaskInsert(companyName: string, title: string, description: string, taskType: string, taskStatus: string, extra: any): string {
  const taskId = crypto.randomUUID();
  const tags = pyDumps(["beichen", taskType]);
  const extraJson = pyDumps(extra);
  return (
    "INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) "
    + "SELECT "
    + `'${taskId}', '${esc(title)}', '${esc(description)}', '${taskType}', '${taskStatus}', 'normal', `
    + "c.id, "
    + `'${esc(tags)}'::jsonb, '${esc(extraJson)}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP `
    + "FROM public.company c WHERE c.company_name = "
    + `'${esc(companyName)}' AND c.deleted_at IS NULL `
    + "AND NOT EXISTS ("
    + "  SELECT 1 FROM public.tasks t "
    + `  WHERE t.company_id = c.id AND t.title = '${esc(title)}' AND t.deleted_at IS NULL`
    + ");"
  );
}

function timestampStr(): string {
  const now = new Date();
  const p = (n: number, l = 2) => String(n).padStart(l, "0");
  return `${p(now.getFullYear(), 4)}${p(now.getMonth() + 1)}${p(now.getDate())}_${p(now.getHours())}${p(now.getMinutes())}${p(now.getSeconds())}`;
}

async function main() {
  const args = parseArgs();
  const profilePath = typeof args.profile === "string" ? args.profile : "";
  const reportPath = typeof args.report === "string" ? args.report : "";
  const matchesPath = typeof args.matches === "string" ? args.matches : "";
  const topn = typeof args.topn === "string" ? Math.max(1, parseInt(args.topn, 10) || 5) : 5;
  const sqlOnly = args["sql-only"] === true || args["sql-only"] === "true";
  const outdir = typeof args.outdir === "string" ? args.outdir : defaultOutdir();
  const dbUrl = typeof args["db-url"] === "string" ? args["db-url"] : (process.env.DATABASE_URL || "");

  if (!profilePath || !reportPath || !matchesPath) {
    console.error("错误: --profile, --report, --matches 必填");
    process.exit(2);
  }

  const profile = JSON.parse(fs.readFileSync(profilePath, "utf-8"));
  const reportMd = fs.readFileSync(reportPath, "utf-8");
  const matches = JSON.parse(fs.readFileSync(matchesPath, "utf-8"));

  const companyName = profile.company_name || "";
  const profileDate = profile.profile_date || localDateStr();
  const matched = (matches.matches || []).slice(0, Math.max(1, topn));
  const matchedCount = matches.matched_count ?? matched.length;

  const lines: string[] = ["-- 产业政策智能体落库 SQL", `-- 生成时间: ${localIso()}`, ""];
  lines.push(buildCompanyUpsert(profile));
  lines.push("");

  lines.push(buildTaskInsert(
    companyName, `政策适配报告 - ${companyName}`, reportMd, "policy-match", "completed",
    { profile_date: profileDate, matched_count: matchedCount, policy_nos: matched.map((m: any) => m.policy_no) }
  ));
  lines.push("");

  let applyTasks = 0;
  for (const m of matched) {
    const title = `政策申报 - ${m.title}`;
    const desc = `政策编号：${m.policy_no}\n支持方式：${m.support || "待补充"}\n匹配依据：${m.basis}\n申报材料以主管部门通知为准。`;
    lines.push(buildTaskInsert(
      companyName, title, desc, "policy-apply", "pending",
      { policy_no: m.policy_no, domain: m.domain, level: m.level, department: m.department, deadline: "待定" }
    ));
    lines.push("");
    applyTasks++;
  }

  fs.mkdirSync(outdir, { recursive: true });
  const sqlFile = path.join(outdir, `policy_${timestampStr()}.sql`);
  fs.writeFileSync(sqlFile, lines.join("\n"), "utf-8");

  const result: any = { success: true, sql_file: sqlFile, company: companyName, policy_match_tasks: 1, policy_apply_tasks: applyTasks, db_written: false };

  if (!sqlOnly && dbUrl) {
    try {
      const { Client } = await import("pg");
      const client = new Client({ connectionString: dbUrl });
      await client.connect();
      for (const stmt of lines) {
        if (stmt.trim() && !stmt.startsWith("--")) {
          await client.query(stmt);
        }
      }
      await client.end();
      result.db_written = true;
    } catch (e: any) {
      if (e.code === "ERR_MODULE_NOT_FOUND" || e.code === "MODULE_NOT_FOUND") {
        console.error("警告: 未安装 pg，仅生成 SQL 文件。可用: npm install pg");
      } else {
        result.error = String(e);
      }
    }
  }

  console.log(JSON.stringify(result));
}

main();