#!/usr/bin/env node
/**
 * save_to_db.ts — 产业政策智能体 Step 5: 结果落库
 * 功能与 save_to_db.py 完全一致
 *
 * 运行方式: node --experimental-strip-types save_to_db.ts --profile {画像json} --report {报告md} --matches {匹配json} [--sql-only] [--deadline YYYY-MM-DD] [--creator <uuid>]
 *
 * T-15（REQ-PD-025/029、G9）：
 *   - tasks 复用既有表，task_type 仅取 policy-match / policy-apply；
 *   - extra_data(jsonb) 存申报材料清单与跟进状态，deadline 存截止时间；
 *   - 截止时间未知时 deadline 写 NULL 并在产物中明示"截止时间未知"（spec §6.7 第 4 条）；
 *   - 全程禁止 CREATE TABLE（G9）；连接失败时保留产物文件（spec §5.3.3 第 4 条）。
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

/**
 * company 表必填列（线上实测：17 列 NOT NULL 且无默认值，见 uctooDB.sql 建表 +
 * 后续企业认证扩展）。缺失值一律写空串表示「未采集」，**禁止编造**统一社会信用代码、
 * 法人手机号等（spec §6.5 第 2 条）。返回未采集列名清单供产物标注。
 */
const COMPANY_REQUIRED_COLS = [
  "company_name", "region", "social_credit_code", "established_time", "registered_capital",
  "registered_address", "mailing_address", "legal_representative", "legal_representativemobile",
  "legal_representative_email", "contact_name", "contact_mobile", "contact_email",
  "contact_title", "website", "company_introduction", "business_licence",
];

/** 画像中的占位值视为未采集 */
function cleanVal(v: any): string {
  const s = String(v ?? "").trim();
  if (!s || s === "待补充" || s === "待核实" || s === "None" || s === "null") return "";
  return s;
}

function buildCompanyValues(profile: any, creditCode: string): { values: Record<string, string>; unfilled: string[] } {
  const biz = profile.business || {};
  const values: Record<string, string> = {
    company_name: cleanVal(profile.company_name),
    region: cleanVal(profile.region) || "北京市朝阳区",
    social_credit_code: cleanVal(creditCode || profile.social_credit_code),
    established_time: cleanVal(biz.established_time),
    registered_capital: cleanVal(biz.registered_capital),
    registered_address: cleanVal(profile.registered_address),
    mailing_address: cleanVal(profile.mailing_address),
    legal_representative: cleanVal(biz.legal_representative),
    legal_representativemobile: "",
    legal_representative_email: "",
    contact_name: "",
    contact_mobile: "",
    contact_email: "",
    contact_title: "",
    website: "",
    company_introduction: cleanVal(profile.summary) || cleanVal(profile.company_name),
    business_licence: "",
  };
  const unfilled = COMPANY_REQUIRED_COLS.filter((c) => !values[c]);
  return { values, unfilled };
}

function buildCompanyUpsert(profile: any, creditCode: string): { sql: string; unfilled: string[] } {
  const name = esc(profile.company_name || "");
  const region = esc(profile.region || "北京市朝阳区");
  const desc = esc(profile.summary || profile.company_name || "");
  const { values, unfilled } = buildCompanyValues(profile, creditCode);

  const cols = COMPANY_REQUIRED_COLS.concat(["org_description", "org_type"]);
  const vals = COMPANY_REQUIRED_COLS.map((c) => `'${esc(values[c])}'`)
    .concat([`'${desc}'`, "'beichen-enterprise'"]);

  const update = `UPDATE public.company SET org_description = '${desc}', region = '${region}', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP WHERE company_name = '${name}' AND deleted_at IS NULL;`;
  const insert = `INSERT INTO public.company (${cols.join(", ")}) SELECT ${vals.join(", ")} WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '${name}' AND deleted_at IS NULL);`;
  const note = unfilled.length
    ? `-- 以下必填列未采集到，已写空串（未编造）：${unfilled.join("、")}`
    : "";
  return { sql: [update, insert, note].filter(Boolean).join("\n"), unfilled };
}

/* ---------------------------------------------------------------------------
 * T-15：申报任务落库字段
 * ------------------------------------------------------------------------- */

/**
 * 跟进状态（中文）→ tasks.task_status 取值。
 * DB 注释枚举为 open/in_progress/.../closed，故中文状态写入 extra_data.follow_status，
 * 列值取对应枚举，避免写入库内不存在的取值。
 */
const FOLLOW_STATUS_MAP: Record<string, string> = {
  "待启动": "open",
  "进行中": "in_progress",
  "已完成": "completed",
  "已终止": "closed",
};
const DEFAULT_FOLLOW_STATUS = "待启动";

/** tasks.creator_id 在无可用用户时的占位（该列 NOT NULL 且无外键约束） */
const CREATOR_PLACEHOLDER = "00000000-0000-0000-0000-000000000000";

/**
 * 截止时间规范化：只接受明确日期，禁止推测值（spec §6.7 第 4 条）。
 * 返回 null 表示"截止时间未知"。
 */
function normalizeDeadline(v: any): string | null {
  const s = String(v ?? "").trim();
  if (!s) return null;
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?/);
  if (!m) return null;
  return m[4] ? `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:00` : `${m[1]}-${m[2]}-${m[3]}`;
}

/**
 * 申报材料清单：条目未提供时不做推测填充，只写"以主管部门通知为准"并标注来源。
 */
function buildMaterials(m: any): { materials: string[]; materials_source: string } {
  const raw = Array.isArray(m.materials) ? m.materials.filter((x: any) => String(x ?? "").trim()) : [];
  if (raw.length) return { materials: raw, materials_source: "政策条目已提供" };
  return { materials: ["以主管部门发布的申报通知为准"], materials_source: "条目未提供材料清单，未作推测填充" };
}

/** creator_id 取值表达式：显式 --creator 优先，否则取一个可用用户，再兜底占位 uuid */
function creatorExpr(creator: string): string {
  if (/^[0-9a-fA-F-]{36}$/.test(creator)) return `'${creator}'::uuid`;
  return "COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1)"
    + `, '${CREATOR_PLACEHOLDER}'::uuid)`;
}

function buildTaskInsert(
  companyName: string, title: string, description: string, taskType: string,
  taskStatus: string, extra: any, deadline: string | null, creator: string
): string {
  const taskId = crypto.randomUUID();
  const tags = pyDumps(["beichen", taskType]);
  const extraJson = pyDumps(extra);
  const deadlineVal = deadline ? `'${esc(deadline)}'::timestamptz` : "NULL";
  return (
    "INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) "
    + "SELECT "
    + `'${taskId}', '${esc(title)}', '${esc(description)}', '${taskType}', '${taskStatus}', 'normal', `
    + "c.id, " + creatorExpr(creator) + ", "
    + `'${esc(tags)}'::jsonb, '${esc(extraJson)}'::jsonb, ${deadlineVal}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP `
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
  // --deadline 为全局申报截止日（条目自带 deadline 优先）；--creator 指定 creator_id
  const globalDeadline = normalizeDeadline(typeof args.deadline === "string" ? args.deadline : "");
  const creator = typeof args.creator === "string" ? args.creator : "";
  const creditCode = typeof args["credit-code"] === "string" ? args["credit-code"] : "";
  const followStatus = typeof args["follow-status"] === "string" && FOLLOW_STATUS_MAP[args["follow-status"]]
    ? args["follow-status"] : DEFAULT_FOLLOW_STATUS;

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
  const cu = buildCompanyUpsert(profile, creditCode);
  lines.push(cu.sql);
  lines.push("");

  lines.push(buildTaskInsert(
    companyName, `政策适配报告 - ${companyName}`, reportMd, "policy-match",
    FOLLOW_STATUS_MAP["已完成"],
    {
      profile_date: profileDate, matched_count: matchedCount,
      policy_nos: matched.map((m: any) => m.policy_no),
      follow_status: "已完成",
      report_file: path.basename(reportPath),
    },
    null, creator
  ));
  lines.push("");

  let applyTasks = 0;
  let unknownDeadline = 0;
  for (const m of matched) {
    const title = `政策申报 - ${m.title}`;
    const dl = normalizeDeadline(m.deadline) || globalDeadline;
    if (!dl) unknownDeadline++;
    const mat = buildMaterials(m);
    const desc = `政策编号：${m.policy_no}\n支持方式：${m.support || "待补充"}\n匹配依据：${m.basis}\n截止时间：${dl || "截止时间未知（主管部门尚未公布或未获取到明确日期）"}\n申报材料以主管部门通知为准。`;
    if (!dl) lines.push(`-- 截止时间未知：政策编号 ${m.policy_no} 未获取到明确截止日期，deadline 写 NULL，不作推测填充`);
    lines.push(buildTaskInsert(
      companyName, title, desc, "policy-apply", FOLLOW_STATUS_MAP[followStatus],
      {
        policy_no: m.policy_no, domain: m.domain, level: m.level, department: m.department,
        deadline: dl, deadline_known: Boolean(dl),
        follow_status: followStatus,
        materials: mat.materials, materials_source: mat.materials_source,
        source: m.source || "", url: m.url || "",
      },
      dl, creator
    ));
    lines.push("");
    applyTasks++;
  }

  fs.mkdirSync(outdir, { recursive: true });
  const sqlFile = path.join(outdir, `policy_${timestampStr()}.sql`);
  fs.writeFileSync(sqlFile, lines.join("\n"), "utf-8");

  const result: any = {
    success: true, sql_file: sqlFile, company: companyName,
    policy_match_tasks: 1, policy_apply_tasks: applyTasks,
    unknown_deadline: unknownDeadline,
    company_unfilled_cols: cu.unfilled,
    products: [sqlFile],
    db_written: false,
  };
  const notes: string[] = [];
  if (unknownDeadline > 0) {
    notes.push(`${unknownDeadline} 条申报任务「截止时间未知」，deadline 已写 NULL，未作推测填充`);
  }
  if (cu.unfilled.length) {
    notes.push(`company 必填列未采集 ${cu.unfilled.length} 项（${cu.unfilled.join("、")}），已写空串，未编造`);
  }
  if (notes.length) result.notes = notes;

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
        console.error(`落库失败，已生成产物文件：${sqlFile}（未安装 pg，可用: npm install pg）`);
        result.error = "未安装 pg 驱动";
      } else {
        result.error = String(e);
        console.error(`落库失败，已生成产物文件：${sqlFile}`);
      }
    }
  }

  console.log(JSON.stringify(result));
}

main();