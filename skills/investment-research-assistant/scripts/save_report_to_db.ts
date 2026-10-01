#!/usr/bin/env node
/**
 * save_report_to_db.ts — 智能投研助理 Step 5: 结果落库
 * 功能与 save_report_to_db.py 完全一致
 *
 * 运行方式: node --experimental-strip-types save_report_to_db.ts --report <brief.md> [--factors <factors.json>] [--sql-only]
 */
import * as fs from "fs";
import * as path from "path";
import { randomUUID } from "crypto";

const __dirname = import.meta.dirname;

function esc(s: string): string { return (s || "").replace(/\\/g, "\\\\").replace(/'/g, "''"); }

const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地时间 ISO（对齐 Python datetime.now().isoformat()，Python 用本地时间）
function localIso(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}
// 本地日期 YYYY-MM-DD
function localDateStr(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}
// 本地时间戳 YYYYMMDD_HHMMSS（对齐 Python datetime.now().strftime('%Y%m%d_%H%M%S')）
function localStamp(d: Date = new Date()): string {
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}_${pad2(d.getHours())}${pad2(d.getMinutes())}${pad2(d.getSeconds())}`;
}

function splitReportByCompany(reportMd: string): any[] {
  const sections: any[] = []; let current: any = { title: "", content: "" };
  for (const line of reportMd.split(/\r?\n/)) {
    const m = /^#*\s*每日投资简报\s*-\s*(.+)/.exec(line.trim());
    if (m) { if (current.title || current.content) sections.push(current); current = { title: m[1].trim(), content: line + "\n" }; }
    else current.content += line + "\n";
  }
  if (current.title || current.content) sections.push(current);
  return sections;
}

function buildCompanyUpsertSql(companyName: string, factors: any): string {
  let orgDescription = "";
  if (factors && factors.market_factors) {
    const mf = factors.market_factors;
    orgDescription = `投资简报日期 ${factors.date || ""}：收盘 ${mf.close_price}，涨跌幅 ${mf.change_pct}%，PE ${mf.pe}，PB ${mf.pb}，市值 ${mf.market_cap}`;
  }
  const cne = esc(companyName);
  return [
    `UPDATE public.company SET org_description = '${esc(orgDescription)}', updated_at = CURRENT_TIMESTAMP WHERE company_name = '${cne}' AND deleted_at IS NULL;`,
    `INSERT INTO public.company (company_name, region, org_description, org_type, is_verified) SELECT '${cne}', '中国', '${esc(orgDescription)}', 'investment-research', false WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '${cne}' AND deleted_at IS NULL);`,
  ].join("\n");
}

function buildTaskInsertSql(companyName: string, reportContent: string, factors: any): string {
  const taskId = randomUUID();
  const tags = JSON.stringify(["investment-research", "daily-brief"]);
  const reportDate = (factors?.date || "") || localDateStr();
  let companyCode = "";
  if (factors?.companies) for (const comp of factors.companies) if (comp.name === companyName) { companyCode = comp.code || ""; break; }
  const extra = JSON.stringify({ report_date: reportDate, code: companyCode });
  const title = `每日投资简报 - ${companyName}`;
  return `INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, tags, extra_data, created_at, updated_at) SELECT '${taskId}', '${esc(title)}', '${esc(reportContent)}', 'research', 'completed', 'normal', c.id, '${esc(tags)}'::jsonb, '${esc(extra)}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '${esc(companyName)}' AND c.deleted_at IS NULL AND NOT EXISTS (SELECT 1 FROM public.tasks t WHERE t.company_id = c.id AND t.title = '${esc(title)}' AND t.deleted_at IS NULL);`;
}

async function main() {
  const args = process.argv.slice(2);
  let report = "", factors: string | null = null, sqlOnly = false, outdir = path.normalize(path.join(__dirname, "..", "output", "sql")), dbUrl = process.env.DATABASE_URL || "";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--report") report = args[++i];
    else if (args[i] === "--factors") factors = args[++i];
    else if (args[i] === "--sql-only") sqlOnly = true;
    else if (args[i] === "--outdir") outdir = args[++i];
    else if (args[i] === "--db-url") dbUrl = args[++i];
  }
  if (!report) { console.error("错误: 缺少必填参数 --report"); process.exit(2); }
  const reportMd = fs.readFileSync(report, "utf-8");
  let factorsData: any = null;
  if (factors && fs.existsSync(factors)) factorsData = JSON.parse(fs.readFileSync(factors, "utf-8"));
  let sections = splitReportByCompany(reportMd);
  if (!sections.length) sections = [{ title: "投资简报", content: reportMd }];
  const sqlLines = ["-- 智能投研助理落库 SQL", `-- 生成时间: ${localIso()}`, ""];
  for (const sec of sections) {
    sqlLines.push(buildCompanyUpsertSql(sec.title, factorsData));
    sqlLines.push(buildTaskInsertSql(sec.title, sec.content, factorsData));
    sqlLines.push("");
  }
  fs.mkdirSync(outdir, { recursive: true });
  const sqlFile = path.join(outdir, `report_${localStamp()}.sql`);
  fs.writeFileSync(sqlFile, sqlLines.join("\n"), "utf-8");
  const result: any = { success: true, sql_file: sqlFile, company_count: sections.length, db_written: false };
  // 直连数据库（对齐 Python psycopg2 行为）：未 --sql-only 且提供 db_url 时尝试 pg 驱动；
  // pg 为可选惰性依赖（npm install pg），未安装时降级为仅生成 SQL 文件
  if (!sqlOnly && dbUrl) {
    try {
      const { Client } = await import("pg") as any;
      const client = new Client({ connectionString: dbUrl });
      await client.connect();
      try {
        await client.query("BEGIN");
        for (const stmt of sqlLines) {
          const s = stmt.trim();
          if (s && !s.startsWith("--")) await client.query(s);
        }
        await client.query("COMMIT");
        result.db_written = true;
      } catch (qe: any) {
        await client.query("ROLLBACK").catch(() => {});
        result.error = String(qe.message || qe);
      }
      await client.end().catch(() => {});
    } catch (e: any) {
      if ((e as any).code === "ERR_MODULE_NOT_FOUND") {
        console.error("警告: 未安装 pg，仅生成 SQL 文件。可用: npm install pg");
      } else {
        result.error = String((e as any).message || e);
      }
    }
  } else if (!sqlOnly && !dbUrl) {
    // 对齐 Python：无 db_url 时仅生成 SQL 文件（不报错）
  }
  console.log(JSON.stringify(result));
}

main().catch((e) => { console.error(e); process.exit(1); });