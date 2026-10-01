#!/usr/bin/env node
/**
 * parse_goal.ts — 长程任务 SOP Step 1：目标解析
 * 功能与 parse_goal.py 完全一致
 *
 * 运行方式: node --experimental-strip-types parse_goal.ts --goal "<目标>" [--outdir output/parsed] [--task_id <uuid>]
 */
import * as fs from "fs";
import * as path from "path";

const __dirname = import.meta.dirname;

const SYSTEM_PROMPT = `你是一个「长程自主任务」规划助手。用户会给你一个自然语言目标。
请将其结构化为 JSON，字段：
- goal: 复述目标
- success_criteria: 字符串数组，每条是一个可验证的完成标准（具体、可判定）
- constraints: 字符串数组，约束（技术栈/合规/资源/时间等）
- sub_goals: 字符串数组，建议的执行子目标分解（2-6 个，有序）
只输出 JSON，不要解释。`;

function modelCfg() {
  return {
    base_url: process.env.LRT_MODEL_BASE_URL || process.env.OPENAI_BASE_URL || "https://api.deepseek.com/v1",
    api_key: process.env.LRT_MODEL_API_KEY || process.env.OPENAI_API_KEY || "",
    model: process.env.LRT_MODEL_NAME || process.env.MODEL_NAME || "deepseek-chat",
  };
}

async function chat(userText: string, dataContract: string = ""): Promise<string> {
  const cfg = modelCfg();
  if (!cfg.api_key) throw new Error("缺少模型 API Key：请设置 LRT_MODEL_API_KEY 或 OPENAI_API_KEY");
  let system = SYSTEM_PROMPT;
  if (dataContract) system += "\n\n" + dataContract;
  const payload = {
    model: cfg.model,
    messages: [{ role: "system", content: system }, { role: "user", content: userText }],
    temperature: 0.2,
    response_format: { type: "json_object" },
  };
  const resp = await fetch(cfg.base_url.replace(/\/$/, "") + "/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer " + cfg.api_key },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(120000),
  });
  const data = await resp.json() as any;
  return data.choices[0].message.content;
}

function nowCst(): string {
  return new Date(Date.now() + 8 * 3600 * 1000).toISOString().replace(/\.\d+Z$/, "+08:00");
}

async function parseGoal(goal: string, dataContract: string = ""): Promise<any> {
  const parsedAt = nowCst();
  const base: any = { goal, success_criteria: [], constraints: [], sub_goals: [], parsed_at: parsedAt, model: "" };
  try {
    const raw = await chat("目标：\n" + goal, dataContract);
    const obj = JSON.parse(raw);
    for (const k of ["success_criteria", "constraints", "sub_goals"]) {
      if (Array.isArray(obj[k])) base[k] = obj[k].map((x: any) => String(x));
    }
    if (typeof obj.goal === "string" && obj.goal.trim()) base.goal = obj.goal.trim();
    base.model = modelCfg().model;
  } catch (e: any) {
    process.stderr.write(`parse_goal LLM 失败，使用确定性骨架: ${e.message}\n`);
    base.constraints = ["LLM 解析不可用，已降级为最小骨架"];
  }
  return base;
}

async function main() {
  const args = process.argv.slice(2);
  let goal = "", taskId = "", outdir = "output/parsed", dataContract = "";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--goal") goal = args[++i];
    else if (args[i] === "--task_id") taskId = args[++i];
    else if (args[i] === "--outdir") outdir = args[++i];
    else if (args[i] === "--data_contract") dataContract = args[++i];
  }
  if (!goal || !goal.trim()) { process.stderr.write("ERROR: goal 不能为空\n"); process.exit(2); }
  fs.mkdirSync(outdir, { recursive: true });
  const result = await parseGoal(goal.trim(), dataContract);
  if (taskId) result.task_id = taskId;
  const outPath = path.join(outdir, "goal.json");
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), "utf-8");
  console.log(JSON.stringify({ ok: true, output: outPath, goal: result }));
}

main().catch((e) => { console.error(e); process.exit(1); });