#!/usr/bin/env node
/**
 * track_service.ts — 金融匹配智能体 Step 5: SOP 六阶段跟踪（Track Service）
 * 功能与 track_service.py 完全一致
 * 北辰金融 SOP 时效引擎：阶段推进（--advance）、超期扫描（--check）、回访提醒（--review）。
 *
 * 用法:
 *     node --experimental-strip-types scripts/track_service.ts --case FC-... --advance --owner 张工
 *     node --experimental-strip-types scripts/track_service.ts --check
 *     node --experimental-strip-types scripts/track_service.ts --case FC-... --review
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;

const SOP_STAGES: Array<{ stage: number; name: string; sla_days: number | null }> = [
  { stage: 1, name: "资料提交与审核", sla_days: 1 },
  { stage: 2, name: "方案制定与洽谈", sla_days: 1 },
  { stage: 3, name: "金融机构对接", sla_days: 2 },
  { stage: 4, name: "落地执行", sla_days: 5 },
  { stage: 5, name: "服务闭环", sla_days: null },
  { stage: 6, name: "长期维护", sla_days: null },
];

function defaultTracking(): string {
  return path.normalize(path.join(__dirname, "..", "output", "tracking"));
}

function defaultNeeds(): string {
  return path.normalize(path.join(__dirname, "..", "output", "needs"));
}

/** 格式化日期为 YYYY-MM-DD（本地时间），与 Python strftime('%Y-%m-%d') 一致 */
function dateStr(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function isWeekday(d: Date): boolean {
  const day = d.getDay();
  return day >= 1 && day <= 5;
}

function addWorkdays(start: Date, days: number): Date {
  const d = new Date(start);
  let n = days;
  while (n > 0) {
    d.setDate(d.getDate() + 1);
    if (isWeekday(d)) n--;
  }
  return d;
}

function dueStr(start: Date, slaDays: number | null): string {
  if (slaDays === null) return "约定时限";
  return dateStr(addWorkdays(start, slaDays));
}

function loadOrInit(caseId: string, trackingDir: string): [any, string] {
  const filePath = path.join(trackingDir, `${caseId}.json`);
  if (fs.existsSync(filePath)) {
    return [JSON.parse(fs.readFileSync(filePath, "utf-8")), filePath];
  }
  // 从需求档案初始化
  const needPath = path.join(defaultNeeds(), `${caseId}.json`);
  let company = caseId;
  if (fs.existsSync(needPath)) {
    const need = JSON.parse(fs.readFileSync(needPath, "utf-8"));
    company = need.company_name || caseId;
  }
  const s1 = SOP_STAGES[0];
  const now = new Date();
  const doc: any = {
    case_id: caseId,
    company_name: company,
    current_stage: 1,
    history: [
      {
        stage: 1,
        name: s1.name,
        started_at: dateStr(now),
        due_date: dueStr(now, s1.sla_days),
        owner: "",
        status: "in_progress",
      },
    ],
    overdue: false,
  };
  fs.mkdirSync(trackingDir, { recursive: true });
  return [doc, filePath];
}

function saveDoc(doc: any, filePath: string): void {
  fs.writeFileSync(filePath, JSON.stringify(doc, null, 2), "utf-8");
}

function advanceMode(doc: any, owner: string): void {
  const cur = doc.current_stage;
  for (const h of doc.history) {
    if (h.stage === cur) {
      h.status = "completed";
      h.completed_at = dateStr(new Date());
    }
  }
  if (cur >= SOP_STAGES.length) {
    console.log(JSON.stringify({ success: true, note: "已处于最后阶段", stage: cur }));
    return;
  }
  const nextStage = SOP_STAGES[cur]; // SOP_STAGES[cur] 是下一阶段（0-indexed）
  doc.current_stage = cur + 1;
  const now = new Date();
  doc.history.push({
    stage: nextStage.stage,
    name: nextStage.name,
    started_at: dateStr(now),
    due_date: dueStr(now, nextStage.sla_days),
    owner,
    status: "in_progress",
  });
}

function reviewMode(doc: any): any {
  doc.review_plan = {
    period: "每季度回访",
    next_review_date: dateStr(addWorkdays(new Date(), 90)),
    note: "服务闭环后按约定周期回访维护",
  };
  return doc;
}

function checkMode(trackingDir: string): void {
  fs.mkdirSync(trackingDir, { recursive: true });
  const today = new Date();
  const report: any[] = [];
  for (const fn of fs.readdirSync(trackingDir)) {
    if (!fn.endsWith(".json")) continue;
    const filePath = path.join(trackingDir, fn);
    const doc = JSON.parse(fs.readFileSync(filePath, "utf-8"));
    for (const h of doc.history || []) {
      if (h.status === "in_progress" && h.due_date && h.due_date !== "约定时限") {
        const due = new Date(h.due_date);
        if (!isNaN(due.getTime()) && due < today) {
          h.status = "overdue";
          report.push({
            case_id: doc.case_id,
            stage: h.stage,
            name: h.name,
            due_date: h.due_date,
            owner: h.owner,
          });
        }
      }
    }
    saveDoc(doc, filePath);
  }
  console.log(JSON.stringify({ success: true, overdue_count: report.length, overdue: report }));
}

async function main() {
  const args = process.argv.slice(2);
  let caseId: string | null = null,
    advance = false,
    check = false,
    review = false,
    owner = "",
    tracking = defaultTracking();
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--case") caseId = args[++i];
    else if (args[i] === "--advance") advance = true;
    else if (args[i] === "--check") check = true;
    else if (args[i] === "--review") review = true;
    else if (args[i] === "--owner") owner = args[++i];
    else if (args[i] === "--tracking") tracking = args[++i];
  }

  if (check) {
    checkMode(tracking);
    return;
  }
  if (!caseId) {
    process.stderr.write("错误: --advance/--review 必须指定 --case\n");
    process.exit(1);
  }

  const [doc, filePath] = loadOrInit(caseId, tracking);
  if (advance) {
    advanceMode(doc, owner);
  } else if (review) {
    reviewMode(doc);
  }
  saveDoc(doc, filePath);
  console.log(
    JSON.stringify({
      success: true,
      case_id: doc.case_id,
      current_stage: doc.current_stage,
      history: doc.history,
      review_plan: doc.review_plan,
      output: filePath,
    }),
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});