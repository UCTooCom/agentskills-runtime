#!/usr/bin/env node
/**
 * llm_fallback.ts — 降级链 llm 环节：让模型按验收条件产出兜底内容
 * 功能与 llm_fallback.py 完全一致
 *
 * 运行方式: node --experimental-strip-types llm_fallback.ts --task_id <id> --round N --failure <desc> --criteria <text>
 */
import * as fs from "fs";
import * as path from "path";

const SYSTEM_PROMPT = `你是长程任务系统的兜底生成器。某个步骤的前两级降级都已失败。
请依据给定的「验收条件」产出最小可用内容：
- content: 兜底正文（可以是未完成的最小骨架，但必须真实可用，且开头写明这是降级兜底）
- caveats: 字符串数组，列出这份内容相对验收条件还缺什么（缺失项必须如实列出）
只输出 JSON，不要解释。`;

function modelCfg() {
  return {
    base_url: process.env.LRT_MODEL_BASE_URL || process.env.OPENAI_BASE_URL || "https://api.deepseek.com/v1",
    api_key: process.env.LRT_MODEL_API_KEY || process.env.OPENAI_API_KEY || "",
    model: process.env.LRT_MODEL_NAME || process.env.MODEL_NAME || "deepseek-chat",
  };
}

async function callLlm(failure: string, criteria: string, taskId: string, roundNo: number): Promise<any> {
  const cfg = modelCfg();
  if (!cfg.api_key) throw new Error("缺少模型 API Key：请设置 LRT_MODEL_API_KEY 或 OPENAI_API_KEY");
  const payload = {
    model: cfg.model,
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: `任务ID: ${taskId}\n回合: ${roundNo}\n失败情况:\n${failure || "(未给出)"}\n\n验收条件:\n${criteria || "(未给出)"}` },
    ],
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
  const content = data.choices[0].message.content;
  const obj = JSON.parse(content);
  return { content: String(obj.content || "").trim(), caveats: (obj.caveats || []).filter((x: any) => x).map(String), model: cfg.model };
}

function nowCst(): string {
  return new Date(Date.now() + 8 * 3600 * 1000).toISOString().replace(/\.\d+Z$/, "+08:00");
}

async function main() {
  const args = process.argv.slice(2);
  let taskId = "", round = 0, failure = "", criteria = "", outdir = "output/executed";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--task_id") taskId = args[++i];
    else if (args[i] === "--round") { const v = args[++i]; if (!/^-?\d+$/.test(v)) { console.error(`错误: --round 必须为整数: ${v}`); process.exit(2); } round = parseInt(v, 10); }
    else if (args[i] === "--failure") failure = args[++i];
    else if (args[i] === "--criteria") criteria = args[++i];
    else if (args[i] === "--outdir") outdir = args[++i];
  }
  // 对齐 py argparse required=True（缺失 exit 2）
  if (!taskId) { console.error("错误: 缺少必填参数 --task_id"); process.exit(2); }
  fs.mkdirSync(outdir, { recursive: true });
  const generatedAt = nowCst();
  try {
    const got = await callLlm(failure, criteria, taskId, round);
    if (!got.content) { console.log(JSON.stringify({ ok: false, output: "", content: "", errmsg: "LLM 返回空内容" })); return; }
    const doc = { task_id: taskId, round, generated_at: generatedAt, degraded: true, content: got.content, caveats: got.caveats, model: got.model };
    const outPath = path.join(outdir, `llm_fallback_${round}.json`);
    fs.writeFileSync(outPath, JSON.stringify(doc, null, 2), "utf-8");
    console.log(JSON.stringify({ ok: true, output: outPath, content: got.content, caveats: got.caveats, model: got.model }));
  } catch (e: any) {
    process.stderr.write(`llm_fallback LLM 失败: ${e.message}\n`);
    console.log(JSON.stringify({ ok: false, output: "", content: "", errmsg: e.message }));
  }
}

main().catch((e) => { console.error(e); process.exit(1); });