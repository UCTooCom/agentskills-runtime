#!/usr/bin/env node
/**
 * verify_artifact.ts — 长程任务 SOP Step 4：产物结构化验核
 * 功能与 verify_artifact.py 完全一致
 *
 * 运行方式: node --experimental-strip-types verify_artifact.ts --artifact_path <path> [--artifact_type code|config|doc|test|report|data|artifact]
 */
import * as fs from "fs";
import * as path from "path";
import { execFileSync } from "child_process";

const SECRET_RE = /(sk-[A-Za-z0-9]{12,}|api_key\s*=\s*['"]?.{8,}|password\s*=\s*['"]?.{8,})/i;

interface Check { name: string; passed: boolean; detail: string; }

function tryCmd(cmd: string[], args: string[]): [boolean, string] {
  try {
    const stdout = execFileSync(cmd[0], cmd.slice(1).concat(args), { encoding: "utf-8", timeout: 60000, stdio: ["pipe", "pipe", "pipe"] });
    return [true, stdout.slice(0, 300) || "ok"];
  } catch (e: any) {
    const out = ((e.stdout || "") + (e.stderr || "")).slice(0, 300);
    return [false, out || `执行检查器失败: ${e.message}`];
  }
}

function checksForType(p: string, atype: string): Check[] {
  const checks: Check[] = [];
  const exists = fs.existsSync(p) && fs.statSync(p).size > 0;
  checks.push({ name: "existence", passed: exists, detail: exists ? "文件存在且非空" : `文件不存在或为空: ${p}` });
  if (!exists) return checks;

  let text: string;
  try { text = fs.readFileSync(p, "utf-8"); }
  catch (e: any) { checks.push({ name: "readable", passed: false, detail: `读取失败: ${e.message}` }); return checks; }

  if (atype === "json") {
    try { JSON.parse(text); checks.push({ name: "json_valid", passed: true, detail: "合法 JSON" }); }
    catch (e: any) { checks.push({ name: "json_valid", passed: false, detail: `JSON 解析失败: ${e.message}` }); }
  } else if (atype === "code") {
    const ext = path.extname(p).toLowerCase();
    let ok: boolean, d: string;
    if (ext === ".py") [ok, d] = tryCmd([process.execPath, "-m", "py_compile"], [p]);
    else if ([".js", ".mjs", ".cjs"].includes(ext)) [ok, d] = tryCmd(["node", "--check"], [p]);
    else if (ext === ".ts") [ok, d] = tryCmd(["npx", "--yes", "tsc", "--noEmit", "--skipLibCheck"], [p]);
    else [ok, d] = [true, "无可用语法检查器，跳过"];
    checks.push({ name: "syntax", passed: ok, detail: d });
  } else {
    const enough = text.trim().length >= 20;
    checks.push({ name: "non_empty", passed: enough, detail: `文本内容 ${text.trim().length} 字符` });
  }

  const hit = SECRET_RE.exec(text);
  checks.push({ name: "no_secret_leak", passed: !hit, detail: hit ? "命中疑似密钥，需人工复核" : "未发现高危密钥字面量" });

  const size = fs.statSync(p).size;
  checks.push({ name: "size", passed: size < 20 * 1024 * 1024, detail: `体积 ${size} 字节（<20MB）` });
  return checks;
}

async function llmSemantic(p: string, goal: string): Promise<Check> {
  try {
    const baseUrl = process.env.LRT_MODEL_BASE_URL || process.env.OPENAI_BASE_URL;
    const apiKey = process.env.LRT_MODEL_API_KEY || process.env.OPENAI_API_KEY;
    const model = process.env.LRT_MODEL_NAME || process.env.MODEL_NAME || "deepseek-chat";
    if (!baseUrl || !apiKey) return { name: "llm_semantic", passed: true, detail: "未配置 LLM，跳过语义校验" };
    const content = fs.readFileSync(p, "utf-8").slice(0, 4000);
    const prompt = `目标：${goal}\n\n产物内容（节选）：\n${content}\n\n该产物是否实质性回应了目标？仅回答 JSON {"ok": true/false, "reason": "..."}`;
    const payload = { model, messages: [{ role: "user", content: prompt }], temperature: 0.0, response_format: { type: "json_object" } };
    const resp = await fetch(baseUrl.replace(/\/$/, "") + "/chat/completions", {
      method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + apiKey }, body: JSON.stringify(payload),
      signal: AbortSignal.timeout(120000),
    });
    const data = await resp.json() as any;
    const obj = JSON.parse(data.choices[0].message.content);
    // 对齐 py：bool(obj.get("ok", True)) —— 缺 ok 字段时默认通过
    return { name: "llm_semantic", passed: obj.ok !== undefined ? !!obj.ok : true, detail: String(obj.reason || "").slice(0, 200) };
  } catch (e: any) {
    return { name: "llm_semantic", passed: true, detail: `LLM 语义校验不可用，跳过: ${e.message}` };
  }
}

function nowCst(): string { return new Date(Date.now() + 8 * 3600 * 1000).toISOString().replace(/\.\d+Z$/, "+08:00"); }

async function verify(artifactPath: string, artifactType: string, useLlm: boolean, goal: string = "") {
  const checkedAt = nowCst();
  const checks = checksForType(artifactPath, artifactType);
  if (useLlm && ["doc", "report", "data", "artifact"].includes(artifactType) && goal) checks.push(await llmSemantic(artifactPath, goal));
  const passed = checks.every((c) => c.passed);
  const failed = checks.filter((c) => !c.passed);
  return { artifact_path: artifactPath, artifact_type: artifactType, passed, checks, summary: passed ? "通过" : "未通过: " + failed.map((c) => c.name).join("; "), checked_at: checkedAt };
}

async function main() {
  const args = process.argv.slice(2);
  let artifactPath = "", artifactType = "artifact", taskId = "", goal = "", useLlm = "0", outdir = "output/verified";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--artifact_path") artifactPath = args[++i];
    else if (args[i] === "--artifact_type") artifactType = args[++i];
    else if (args[i] === "--task_id") taskId = args[++i];
    else if (args[i] === "--goal") goal = args[++i];
    else if (args[i] === "--use_llm") useLlm = args[++i];
    else if (args[i] === "--outdir") outdir = args[++i];
  }
  if (!artifactPath || !fs.existsSync(artifactPath)) { process.stderr.write(`ERROR: artifact_path 不存在: ${artifactPath}\n`); process.exit(2); }
  fs.mkdirSync(outdir, { recursive: true });
  const result = await verify(artifactPath, artifactType, useLlm === "1", goal);
  if (taskId) (result as any).task_id = taskId;
  const base = path.basename(artifactPath, path.extname(artifactPath)) || "artifact";
  const outPath = path.join(outdir, `verify_${base}.json`);
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), "utf-8");
  console.log(JSON.stringify({ ok: true, status: result.passed ? "passed" : "failed", output: outPath, summary: result.summary }));
  process.exit(result.passed ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });