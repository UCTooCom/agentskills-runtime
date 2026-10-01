#!/usr/bin/env node
/**
 * evolve.ts — 长程任务 LrtSelfEvolutionLoop 闭环
 * 功能与 evolve.py 完全一致
 *
 * 运行方式: node --experimental-strip-types evolve.ts --agent_id <uuid> --round <int> --context <text>
 */
import * as fs from "fs";
import * as path from "path";

const SYSTEM_PROMPT = `你是「自主 Agent 自进化」引擎。给定某次长程任务执行失败的现象与上下文，
请输出 JSON：
- root_cause: 根因分析（聚焦机制/系统性原因，不要停在表面现象）
- optimization_plan: 增量优化方案（必须复用现有基础设施，避免大改写）
- anti_regression: 防回退约束文本（明确写出「错误行为示例」与「正确行为示例」）
- skill_md_updates: 数组，每项 {skill, section, before, after}（对 SKILL.md 的具体修订建议；无则空数组）
只输出 JSON，不要解释。`;

function modelCfg() {
  return {
    base_url: process.env.LRT_MODEL_BASE_URL || process.env.OPENAI_BASE_URL || "https://api.deepseek.com/v1",
    api_key: process.env.LRT_MODEL_API_KEY || process.env.OPENAI_API_KEY || "",
    model: process.env.LRT_MODEL_NAME || process.env.MODEL_NAME || "deepseek-chat",
  };
}

async function chat(userText: string): Promise<string> {
  const cfg = modelCfg();
  if (!cfg.api_key) throw new Error("缺少模型 API Key");
  const payload = { model: cfg.model, messages: [{ role: "system", content: SYSTEM_PROMPT }, { role: "user", content: userText }], temperature: 0.3, response_format: { type: "json_object" } };
  const resp = await fetch(cfg.base_url.replace(/\/$/, "") + "/chat/completions", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + cfg.api_key }, body: JSON.stringify(payload), signal: AbortSignal.timeout(120000) });
  return (await resp.json() as any).choices[0].message.content;
}

const FRONTEND_EXTS = [".vue", ".tsx", ".jsx", ".scss", ".less", ".svelte"];
const FRONTEND_DIR_MARKERS = ["web/src", "frontend/", "web-admin", "/components/", "/composable/"];
const BACKEND_DIR_MARKERS = ["apps/agentskills-runtime/src", "/store/models/"];

function isFrontendPath(p: string): boolean {
  if (!p) return false;
  const low = p.replace(/\\/g, "/").toLowerCase();
  if (BACKEND_DIR_MARKERS.some((m) => low.includes(m))) return false;
  if (FRONTEND_EXTS.some((ext) => low.endsWith(ext))) return true;
  if ([".ts", ".js", ".css", ".html"].some((ext) => low.endsWith(ext))) return FRONTEND_DIR_MARKERS.some((m) => low.includes(m));
  return false;
}

function extractPathTokens(text: string): string[] {
  const pat = /[A-Za-z0-9_\-./]+\.(?:vue|tsx|jsx|ts|js|css|scss|less|html)\b/g;
  return (text || "").match(pat) || [];
}

function collectFrontendFiles(skillMdUpdates: any[], context: string): string[] {
  const found: string[] = [], seen = new Set<string>();
  function add(p: string) { p = (p || "").trim(); if (p && isFrontendPath(p) && !seen.has(p)) { seen.add(p); found.push(p); } }
  for (const item of skillMdUpdates || []) {
    if (typeof item === "object" && item !== null) {
      add(item.skill || "");
      for (const key of ["before", "after", "section"]) { const v = item[key]; if (typeof v === "string") for (const tok of extractPathTokens(v)) add(tok); }
    }
  }
  for (const tok of extractPathTokens(context || "")) add(tok);
  return found;
}

function buildFrontendCoordination(skillMdUpdates: any[], context: string): any {
  const files = collectFrontendFiles(skillMdUpdates, context);
  const root = (process.env.LRT_FRONTEND_ROOT || "").trim();
  const detected = files.length > 0;
  const tasks: any[] = [];
  if (detected && root) {
    tasks.push({ type: "cli_execute", command: "npm run build", cwd: root, reason: "前端文件已修改，需重新构建产物（§7.3 前后端协同）" });
    tasks.push({ type: "sync", target: root, reason: "构建产物经 sync 服务同步到数据库（SyncManager + ChangeDetector）" });
  }
  let note: string;
  if (detected && !root) note = "检测到前端改动，但 LRT_FRONTEND_ROOT 未配置——**不臆造构建命令**。请设置该环境变量（前端工程根目录）以启用自动构建与同步。";
  else if (detected) note = "已编排构建 + 同步两条子任务，交编排层经 cli_execute / sync 服务执行。";
  else note = "本轮未检测到前端文件改动，无需构建。";
  return { detected, changed_files: files, frontend_root: root, build_tasks: tasks, note };
}

function readContext(context: string): string {
  if (context && fs.existsSync(context)) { try { return fs.readFileSync(context, "utf-8").slice(0, 6000); } catch {} }
  return (context || "").slice(0, 6000);
}

function nowCst(): string { return new Date(Date.now() + 8 * 3600 * 1000).toISOString().replace(/\.\d+Z$/, "+08:00"); }

async function evolve(agentId: string, round: number, context: string, skill: string): Promise<any> {
  const generatedAt = nowCst();
  const base: any = { agent_id: agentId, round, root_cause: "", optimization_plan: "", anti_regression: "", skill_md_updates: [], generated_at: generatedAt, model: "", frontend_coordination: { detected: false, changed_files: [], frontend_root: "", build_tasks: [], note: "" } };
  const ctx = readContext(context);
  try {
    let user = `agent_id=${agentId}, round=${round}\n`;
    if (skill) user += `skill=${skill}\n`;
    user += `上下文/失败现象：\n${ctx}`;
    const obj = JSON.parse(await chat(user));
    for (const k of ["root_cause", "optimization_plan", "anti_regression"]) if (typeof obj[k] === "string") base[k] = obj[k];
    if (Array.isArray(obj.skill_md_updates)) base.skill_md_updates = obj.skill_md_updates;
    base.model = modelCfg().model;
  } catch (e: any) {
    process.stderr.write(`evolve LLM 失败，降级骨架: ${e.message}\n`);
    base.root_cause = "LLM 不可用，无法自动定位根因（请看 context 人工分析）";
    base.optimization_plan = "待人工基于 context 制定增量优化";
    base.anti_regression = "禁止复现本轮观察到的失败行为";
  }
  try { base.frontend_coordination = buildFrontendCoordination(base.skill_md_updates || [], ctx); }
  catch (fe: any) {
    process.stderr.write(`frontend_coordination 计算失败（已降级为空）: ${fe.message}\n`);
    base.frontend_coordination = { detected: false, changed_files: [], frontend_root: "", build_tasks: [], note: "计算失败，已降级为未检测到前端改动" };
  }
  return base;
}

async function main() {
  const args = process.argv.slice(2);
  let agentId = "", roundStr = "", context = "", skill = "", outdir = "output/extended";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--agent_id") agentId = args[++i];
    else if (args[i] === "--round") roundStr = args[++i];
    else if (args[i] === "--context") context = args[++i];
    else if (args[i] === "--skill") skill = args[++i];
    else if (args[i] === "--outdir") outdir = args[++i];
  }
  if (!agentId) { process.stderr.write("ERROR: 缺少必填参数 --agent_id\n"); process.exit(2); }
  if (!roundStr) { process.stderr.write("ERROR: 缺少必填参数 --round\n"); process.exit(2); }
  const roundN = parseInt(roundStr);
  if (!/^-?\d+$/.test(roundStr) || isNaN(roundN)) { process.stderr.write("ERROR: round 必须为整数\n"); process.exit(2); }
  fs.mkdirSync(outdir, { recursive: true });
  const result = await evolve(agentId, roundN, context, skill);
  const outPath = path.join(outdir, `evolution_${roundN}.json`);
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), "utf-8");
  console.log(JSON.stringify({ ok: true, output: outPath, evolution: result }));
}

main().catch((e) => { console.error(e); process.exit(1); });