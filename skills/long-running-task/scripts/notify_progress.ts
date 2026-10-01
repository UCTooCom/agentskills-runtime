#!/usr/bin/env node
/**
 * notify_progress.ts — 长程任务 SOP Step 4：进度通知
 * 功能与 notify_progress.py 完全一致
 *
 * 运行方式: node --experimental-strip-types notify_progress.ts --task_id <uuid> [--outdir output/executed] [--round N]
 */
import * as fs from "fs";
import * as path from "path";

const EVENT_PROGRESS = "progress_update";
const EVENT_STEP_FAILED = "step_failed";
const DEFAULT_ENDPOINT_ENV = "LRT_NOTIFY_ENDPOINT";

function nowCst(): string { return new Date(Date.now() + 8 * 3600 * 1000).toISOString().replace(/\.\d+Z$/, "+08:00"); }

function loadJson(p: string): any {
  if (!p || !fs.existsSync(p)) return {};
  try { const obj = JSON.parse(fs.readFileSync(p, "utf-8")); return typeof obj === "object" && obj !== null ? obj : {}; }
  catch (e: any) { process.stderr.write(`notify_progress: 读取 ${p} 失败（按空处理）: ${e.message}\n`); return {}; }
}

function loadJsonl(p: string): any[] {
  if (!fs.existsSync(p)) return [];
  const rows: any[] = [];
  try {
    for (const line of fs.readFileSync(p, "utf-8").split(/\r?\n/)) {
      const l = line.trim();
      if (!l) continue;
      try { rows.push(JSON.parse(l)); } catch { continue; }
    }
  } catch (e: any) { process.stderr.write(`notify_progress: 读取 ${p} 失败: ${e.message}\n`); }
  return rows;
}

function collectRoundState(outdir: string, planFile: string, roundNo: number): any {
  const plan = loadJson(planFile);
  const state = loadJson(path.join(outdir, "round_state.json"));
  let total = state.total_steps;
  let completed = state.completed_steps;
  if (total === undefined) total = (plan.steps || plan.sub_goals || []).length;
  if (completed === undefined) completed = 0;
  const failed = state.failed_steps || 0;
  let current = state.current_step || ((plan.steps || plan.sub_goals || [null])[Math.min(completed, Math.max(total - 1, 0))] || "");
  if (typeof current === "object") current = current.name || current.description || "";
  const elapsed = state.elapsed_ms;
  return {
    total_steps: parseInt(total || 0), completed_steps: parseInt(completed || 0), failed_steps: parseInt(failed || 0),
    current_step: String(current || ""), round: parseInt(roundNo || state.round || 0),
    elapsed_ms: typeof elapsed === "number" ? parseInt(elapsed) : null,
    source: state ? "round_state.json" : (plan ? "plan.json" : "none"),
  };
}

function buildEvents(taskId: string, agentId: string, sessionId: string, traceId: string, st: any): any[] {
  const total = st.total_steps, completed = st.completed_steps;
  let remainingMs: number | null = null;
  const elapsedMs = st.elapsed_ms;
  if (typeof elapsedMs === "number" && completed > 0 && total > completed) remainingMs = parseInt(String(elapsedMs / completed * (total - completed)));
  const events: any[] = [];
  const base: any = { type: EVENT_PROGRESS, task_id: taskId, agent_id: agentId, session_id: sessionId, trace_id: traceId, round: st.round, timestamp: nowCst() };
  const evt = { ...base, data: { completedSteps: completed, totalSteps: total, currentStep: st.current_step, estimatedRemaining: remainingMs, intermediateResult: `第 ${st.round} 回合：完成 ${completed}/${total} 步` } };
  events.push(evt);
  if (st.failed_steps > 0) {
    events.push({ ...base, type: EVENT_STEP_FAILED, data: { step: st.current_step, errorMessage: `本回合有 ${st.failed_steps} 个步骤失败，已进入降级重试`, retryable: true, hasNextStep: true, round: st.round } });
  }
  return events;
}

async function push(endpoint: string, events: any[], timeout = 10): Promise<number> {
  if (!endpoint || !events.length) return 0;
  let pushed = 0;
  for (const evt of events) {
    try {
      const resp = await fetch(endpoint.replace(/\/$/, "") + "/events", {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(evt),
        signal: AbortSignal.timeout(timeout * 1000),
      });
      if (resp.status >= 200 && resp.status < 300) pushed++;
      else process.stderr.write(`notify_progress: 推送返回 ${resp.status}，跳过\n`);
    } catch (e: any) { process.stderr.write(`notify_progress: 推送失败（不阻断）: ${e.message}\n`); }
  }
  return pushed;
}

function writeEvents(jsonlPath: string, events: any[], roundNo: number): void {
  const existing = loadJsonl(jsonlPath).filter((e) => e.round !== roundNo);
  existing.push(...events);
  fs.writeFileSync(jsonlPath, existing.map((e) => JSON.stringify(e)).join("\n") + "\n", "utf-8");
}

async function main() {
  const args = process.argv.slice(2);
  let taskId = "", outdir = "output/executed", planFile = "", round = 0, agentId = "", sessionId = "", traceId = "", endpoint = process.env[DEFAULT_ENDPOINT_ENV] || "", dataContract = "";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--task_id") taskId = args[++i];
    else if (args[i] === "--outdir") outdir = args[++i];
    else if (args[i] === "--plan_file") planFile = args[++i];
    else if (args[i] === "--round") round = parseInt(args[++i]);
    else if (args[i] === "--agent_id") agentId = args[++i];
    else if (args[i] === "--session_id") sessionId = args[++i];
    else if (args[i] === "--trace_id") traceId = args[++i];
    else if (args[i] === "--endpoint") endpoint = args[++i];
    else if (args[i] === "--data_contract") dataContract = args[++i];
  }
  fs.mkdirSync(outdir, { recursive: true });
  const st = collectRoundState(outdir, planFile, round);
  const events = buildEvents(taskId, agentId, sessionId, traceId, st);
  const progressPath = path.join(outdir, "progress.json");
  const summary = { ...st, task_id: taskId, updated_at: nowCst(), event_count: events.length };
  fs.writeFileSync(progressPath, JSON.stringify(summary, null, 2), "utf-8");
  writeEvents(path.join(outdir, "progress_events.jsonl"), events, st.round);
  const pushed = await push(endpoint, events);
  console.log(JSON.stringify({ ok: true, output: progressPath, events, pushed }));
}

main().catch((e) => { console.error(e); process.exit(1); });