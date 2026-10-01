#!/usr/bin/env node
/**
 * save_to_db.ts — 金融匹配智能体 Step 6: 结果落库（Save to DB）
 * 功能与 save_to_db.py 完全一致
 * 企业 upsert 到 company 表，融资方案写入 tasks（task_type='finance-plan'），
 * SOP 阶段服务任务写入 tasks（task_type='finance-service'），复用 aibuilder 呈现。
 *
 * 用法:
 *     node --experimental-strip-types scripts/save_to_db.ts --need {需求json} --plan {方案md} --tracking {跟踪json} [--sql-only]
 *
 * 说明:
 *     - company 表无 company_name 唯一约束，采用 UPDATE + INSERT WHERE NOT EXISTS 两步去重；
 *     - --sql-only 仅生成 SQL 文件；直连需 DATABASE_URL + pg（npm install pg）。
 */
import * as fs from "fs";
import * as path from "path";
import { randomUUID } from "crypto";

const __dirname = import.meta.dirname;
const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地时间 ISO（对齐 Python datetime.now().isoformat()）
function localIso(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}

function defaultOutdir(): string {
  return path.normalize(path.join(__dirname, "..", "output", "sql"));
}

function esc(s: any): string {
  return String(s || "").replace(/\\/g, "\\\\").replace(/'/g, "''");
}

function buildCompanyUpsert(need: any): string {
  const name = esc(need.company_name || "");
  const region = esc((need.profile || {}).region || "北京市朝阳区");
  const desc = esc(`融资需求 ${need.amount || ""}（${need.purpose || ""}）| 企业画像摘要：${(need.profile || {}).summary || ""}`);
  return [
    `UPDATE public.company SET org_description = '${desc}', region = '${region}', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP WHERE company_name = '${name}' AND deleted_at IS NULL;`,
    `INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '${name}', '${region}', '${desc}', 'beichen-enterprise', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '${name}' AND deleted_at IS NULL);`,
  ].join("\n");
}

function buildTaskInsert(companyName: string, title: string, description: string, taskType: string, taskStatus: string, extra: any): string {
  const taskId = randomUUID();
  const tags = JSON.stringify(["beichen", taskType]);
  const extraJson = JSON.stringify(extra);
  return (
    "INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) " +
    "SELECT " +
    `'${taskId}', '${esc(title)}', '${esc(description)}', '${taskType}', '${taskStatus}', 'normal', ` +
    "c.id, " +
    `'${esc(tags)}'::jsonb, '${esc(extraJson)}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP ` +
    "FROM public.company c WHERE c.company_name = " +
    `'${esc(companyName)}' AND c.deleted_at IS NULL ` +
    "AND NOT EXISTS (" +
    "  SELECT 1 FROM public.tasks t " +
    `  WHERE t.company_id = c.id AND t.title = '${esc(title)}' AND t.deleted_at IS NULL` +
    ");"
  );
}

/** 本地时间戳，格式 YYYYMMDD_HHMMSS，与 Python strftime('%Y%m%d_%H%M%S') 一致 */
function localTimestamp(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

async function main() {
  const args = process.argv.slice(2);
  let needFile = "",
    planFile = "",
    trackingFile: string | null = null,
    matchesFile: string | null = null,
    sqlOnly = false,
    outdir = defaultOutdir(),
    dbUrl = process.env.DATABASE_URL || "";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--need") needFile = args[++i];
    else if (args[i] === "--plan") planFile = args[++i];
    else if (args[i] === "--tracking") trackingFile = args[++i];
    else if (args[i] === "--matches") matchesFile = args[++i];
    else if (args[i] === "--sql-only") sqlOnly = true;
    else if (args[i] === "--outdir") outdir = args[++i];
    else if (args[i] === "--db-url") dbUrl = args[++i];
  }
  // 对齐 py argparse required=True（缺失 exit 2）
  if (!needFile) { console.error("错误: 缺少必填参数 --need"); process.exit(2); }
  if (!planFile) { console.error("错误: 缺少必填参数 --plan"); process.exit(2); }

  const need = JSON.parse(fs.readFileSync(needFile, "utf-8"));
  const planMd = fs.readFileSync(planFile, "utf-8");

  let tracking: any = null;
  if (trackingFile && fs.existsSync(trackingFile)) tracking = JSON.parse(fs.readFileSync(trackingFile, "utf-8"));

  let matches: any = null;
  if (matchesFile && fs.existsSync(matchesFile)) matches = JSON.parse(fs.readFileSync(matchesFile, "utf-8"));

  const companyName = need.company_name || "";
  const caseId = need.case_id || "";
  const partners: string[] = matches ? (matches.matches || []).map((m: any) => m.partner) : [];

  const lines: string[] = ["-- 金融匹配智能体落库 SQL", `-- 生成时间: ${localIso()}`, ""];
  lines.push(buildCompanyUpsert(need));
  lines.push("");

  lines.push(
    buildTaskInsert(companyName, `融资方案 - ${companyName}`, planMd, "finance-plan", "completed", {
      case_id: caseId,
      amount: need.amount,
      purpose: need.purpose,
      partners,
    }),
  );
  lines.push("");

  let serviceTasks = 0;
  if (tracking) {
    for (const h of tracking.history || []) {
      const st = h.status || "in_progress";
      const tstatus = ({ in_progress: "in-progress", completed: "completed", overdue: "overdue" } as Record<string, string>)[st] || "in-progress";
      const title = `${h.name} - ${companyName}`;
      const desc = `SOP 阶段 ${h.stage}：${h.name}。责任人：${h.owner || "待分配"}。截止：${h.due_date}`;
      lines.push(
        buildTaskInsert(companyName, title, desc, "finance-service", tstatus, {
          case_id: caseId,
          sop_stage: h.stage,
          due_date: h.due_date,
          owner: h.owner || "",
        }),
      );
      lines.push("");
      serviceTasks++;
    }
  }

  fs.mkdirSync(outdir, { recursive: true });
  const sqlFile = path.join(outdir, `finance_${localTimestamp()}.sql`);
  fs.writeFileSync(sqlFile, lines.join("\n"), "utf-8");

  const result: any = {
    success: true,
    sql_file: sqlFile,
    company: companyName,
    finance_plan_tasks: 1,
    finance_service_tasks: serviceTasks,
    db_written: false,
  };

  if (!sqlOnly && dbUrl) {
    try {
      const pg = await import("pg");
      const client = new pg.Client(dbUrl);
      await client.connect();
      for (const stmt of lines) {
        if (stmt.trim() && !stmt.startsWith("--")) await client.query(stmt);
      }
      await client.end();
      result.db_written = true;
    } catch (e: any) {
      const msg = String(e?.message || e);
      if (msg.includes("Cannot find package") || msg.includes("ERR_MODULE_NOT_FOUND")) {
        process.stderr.write("警告: 未安装 pg，仅生成 SQL 文件。可用: npm install pg\n");
      } else {
        result.error = msg;
      }
    }
  }

  console.log(JSON.stringify(result));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});