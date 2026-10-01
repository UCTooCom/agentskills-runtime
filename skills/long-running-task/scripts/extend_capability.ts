#!/usr/bin/env node
/**
 * extend_capability.ts — 长程任务 SOP Step 5：能力扩展
 * 功能与 extend_capability.py 完全一致
 *
 * 运行方式: node --experimental-strip-types extend_capability.ts --plan_file <plan.json> [--outdir output/extended]
 */
import * as fs from "fs";
import * as path from "path";

const BUILTIN_TOOLS = new Set(["python_execute", "cli_execute", "db_query", "web_search", "web_fetch", "file_read", "file_write", "file_edit", "glob", "grep", "bash"]);
const CODE_SIGNALS = ["cangjie", "cj_", "_cj", "仓颉"];
const VERIFIER_TASK = "code-gen-verifier";
const VERIFIER_ENTRY = `../${VERIFIER_TASK}/scripts/verify.py`;
const AGENT_DRIVEN_HANDLERS = new Set(["cangjie-coder", "skill-creator"]);

function nowCst(): string { return new Date(Date.now() + 8 * 3600 * 1000).toISOString().replace(/\.\d+Z$/, "+08:00"); }

function loadJson(p: string): any {
  if (!p || !fs.existsSync(p)) return null;
  try { return JSON.parse(fs.readFileSync(p, "utf-8")); }
  catch (e: any) { process.stderr.write(`extend_capability: 读取 ${p} 失败（按空处理）: ${e.message}\n`); return null; }
}

function loadInstalled(skillsArg: string, fileArg: string): Set<string> {
  let raw = "";
  if (skillsArg) raw = skillsArg;
  else if (fileArg) {
    const obj = loadJson(fileArg);
    if (Array.isArray(obj)) return new Set(obj.map(String).map((s) => s.trim()).filter(Boolean));
    if (obj && typeof obj === "object") {
      const names = obj.skills || obj.names || [];
      return new Set(names.map((x: any) => String(x.name || "").trim()).filter(Boolean));
    }
    return new Set();
  } else if (process.env.LRT_INSTALLED_SKILLS) raw = process.env.LRT_INSTALLED_SKILLS;
  return new Set(raw.split(",").map((s) => s.trim()).filter(Boolean));
}

function extractRequired(plan: any): any[] {
  if (!plan || typeof plan !== "object") return [];
  const out: any[] = [];
  function push(name: any, task = "", language = "") {
    if (typeof name === "object" && name !== null) {
      language = name.language || language;
      task = name.name || name.description || task;
      name = name.skill || name.name || "";
    }
    name = String(name || "").trim();
    if (name) out.push({ name, task: String(task || ""), language: String(language || "") });
  }
  for (const v of plan.skill_sequence || []) push(v);
  for (const v of plan.required_skills || []) push(v);
  for (const st of plan.steps || plan.sub_goals || []) {
    if (typeof st === "object" && st !== null) {
      if (st.skill) push(st.skill, st.name || st.description || "", st.language || "");
      for (const v of st.skills || []) push(v, st.name || "", st.language || "");
    }
  }
  const seen = new Set(), uniq: any[] = [];
  for (const r of out) { if (!seen.has(r.name)) { seen.add(r.name); uniq.push(r); } }
  return uniq;
}

function classify(req: any): any {
  const name = req.name;
  if (BUILTIN_TOOLS.has(name)) return { handler: "builtin", builtin_available: true, action: `直接使用内置工具 ${name}，无需新建技能`, verifier: null };
  const lower = (name + " " + (req.language || "")).toLowerCase();
  if (CODE_SIGNALS.some((s) => lower.includes(s)) || (req.language || "").toLowerCase() === "cangjie") return { handler: "cangjie-coder", builtin_available: false, action: `编排 cangjie-coder 编写仓颉代码子任务补齐能力 ${name}`, verifier: VERIFIER_TASK };
  return { handler: "skill-creator", builtin_available: false, action: `编排 skill-creator 创建技能 ${name}`, verifier: VERIFIER_TASK };
}

function generatorCmd(gap: any): string {
  const handler = gap.handler || "", name = gap.name || "";
  if (AGENT_DRIVEN_HANDLERS.has(handler)) return `# [agent-skill] 由宿主 LLM 调度技能 ${handler} 补齐「${name}」（无 CLI 入口，不出可执行命令）`;
  if (handler === "builtin") return `# [builtin] 「${name}」已由内置工具覆盖，无需补齐命令`;
  return `# [unknown] 「${name}」的 handler=${handler} 无已知执行方式，需人工介入`;
}

function verifierCmd(gap: any): string {
  const name = gap.name || "";
  return `python ${VERIFIER_ENTRY} --files "\${${name}.generated_files}" --project-path "\${project_path}" --verify-level compile`;
}

async function main() {
  const args = process.argv.slice(2);
  let planFile = "", outdir = "output/extended", installedSkills = "", installedSkillsFile = "", taskId = "", dataContract = "";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--plan_file") planFile = args[++i];
    else if (args[i] === "--outdir") outdir = args[++i];
    else if (args[i] === "--installed-skills") installedSkills = args[++i];
    else if (args[i] === "--installed-skills-file") installedSkillsFile = args[++i];
    else if (args[i] === "--task_id") taskId = args[++i];
    else if (args[i] === "--data_contract") dataContract = args[++i];
  }
  fs.mkdirSync(outdir, { recursive: true });
  const plan = loadJson(planFile) || {};
  const installed = loadInstalled(installedSkills, installedSkillsFile);
  const required = extractRequired(plan);
  const gaps: any[] = [], covered: any[] = [];
  for (const req of required) {
    if (installed.has(req.name) || BUILTIN_TOOLS.has(req.name)) { covered.push({ name: req.name, status: "installed_or_builtin" }); continue; }
    const item = { ...req, ...classify(req) };
    item.acceptance_criteria = [item.verifier ? `产物通过 ${item.verifier} 验证` : "能力可直接调用", "补齐后以最小用例实跑一次，产出非空且不报错"];
    gaps.push(item);
  }
  const gapsPath = path.join(outdir, "skill_gaps.json");
  const planPath = path.join(outdir, "extension_plan.json");
  const generatedAt = nowCst();
  const gapDoc = { task_id: taskId, generated_at: generatedAt, gap_count: gaps.length, installed_count: installed.size, gaps };
  const planDoc = { task_id: taskId, generated_at: generatedAt, covered, quality_gate: { generator_to_verifier: `cangjie-coder / skill-creator → ${VERIFIER_TASK}`, on_verify_failed: "回 cangjie-coder 修复后重试，最多 2 轮；仍失败则上报人工", max_retry: 2 }, steps: gaps };
  fs.writeFileSync(gapsPath, JSON.stringify(gapDoc, null, 2), "utf-8");
  fs.writeFileSync(planPath, JSON.stringify(planDoc, null, 2), "utf-8");
  const cmds: string[] = [];
  if (gaps.length > 0) {
    for (const g of gaps) {
      cmds.push(`# ${g.name} → ${g.handler}${g.verifier ? " → " + g.verifier : ""}`);
      cmds.push(generatorCmd(g));
      if (g.verifier) cmds.push(verifierCmd(g));
    }
    fs.writeFileSync(path.join(outdir, "commands.txt"), cmds.join("\n") + "\n", "utf-8");
  }
  console.log(JSON.stringify({ ok: true, output: gapsPath, extension_plan: planPath, gap_count: gaps.length, covered_count: covered.length, commands: cmds }));
}

main().catch((e) => { console.error(e); process.exit(1); });