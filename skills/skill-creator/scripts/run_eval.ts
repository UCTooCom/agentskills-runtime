/**
 * run_eval.ts — Run trigger evaluation for a skill description.
 * 功能与 run_eval.py 完全一致
 */
import * as fs from "fs";
import * as path from "path";
import { spawn } from "child_process";
import { fileURLToPath } from "url";
import { parseSkillMd } from "./utils.ts";

export function findProjectRoot(): string {
  let current = process.cwd();
  while (true) {
    if (fs.existsSync(path.join(current, ".claude")) && fs.statSync(path.join(current, ".claude")).isDirectory()) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return process.cwd();
}

function runSingleQuery(
  query: string,
  skillName: string,
  skillDescription: string,
  timeout: number,
  projectRoot: string,
  model: string | null = null,
): Promise<boolean> {
  return new Promise((resolve) => {
    const uniqueId = Math.random().toString(16).slice(2, 10);
    const cleanName = `${skillName}-skill-${uniqueId}`;
    const projectCommandsDir = path.join(projectRoot, ".claude", "commands");
    const commandFile = path.join(projectCommandsDir, `${cleanName}.md`);

    fs.mkdirSync(projectCommandsDir, { recursive: true });
    const indentedDesc = skillDescription.split("\n").join("\n  ");
    const commandContent =
      `---\n` +
      `description: |\n` +
      `  ${indentedDesc}\n` +
      `---\n\n` +
      `# ${skillName}\n\n` +
      `This skill handles: ${skillDescription}\n`;
    fs.writeFileSync(commandFile, commandContent);

    const cmd: string[] = ["claude", "-p", query, "--output-format", "stream-json", "--verbose", "--include-partial-messages"];
    if (model) {
      cmd.push("--model", model);
    }

    const env: Record<string, string> = {};
    for (const [k, v] of Object.entries(process.env)) {
      if (k !== "CLAUDECODE" && v !== undefined) {
        env[k] = v;
      }
    }

    const child = spawn(cmd[0], cmd.slice(1), {
      cwd: projectRoot,
      env,
      stdio: ["pipe", "pipe", "ignore"],
    });

    let triggered = false;
    let buffer = "";
    let pendingToolName: string | null = null;
    let accumulatedJson = "";
    let resolved = false;

    const timeoutId = setTimeout(() => {
      if (!resolved) {
        resolved = true;
        try { child.kill(); } catch {}
        cleanup();
        resolve(triggered);
      }
    }, timeout * 1000);

    function cleanup() {
      clearTimeout(timeoutId);
      try {
        if (fs.existsSync(commandFile)) {
          fs.unlinkSync(commandFile);
        }
      } catch {}
    }

    child.stdout!.on("data", (chunk: Buffer) => {
      if (resolved) return;
      buffer += chunk.toString("utf-8");

      while (buffer.includes("\n")) {
        const idx = buffer.indexOf("\n");
        const line = buffer.slice(0, idx).trim();
        buffer = buffer.slice(idx + 1);
        if (!line) continue;

        let event: any;
        try {
          event = JSON.parse(line);
        } catch {
          continue;
        }

        if (event.type === "stream_event") {
          const se = event.event ?? {};
          const seType = se.type ?? "";

          if (seType === "content_block_start") {
            const cb = se.content_block ?? {};
            if (cb.type === "tool_use") {
              const toolName = cb.name ?? "";
              if (toolName === "Skill" || toolName === "Read") {
                pendingToolName = toolName;
                accumulatedJson = "";
              } else {
                resolved = true;
                try { child.kill(); } catch {}
                cleanup();
                resolve(false);
                return;
              }
            }
          } else if (seType === "content_block_delta" && pendingToolName) {
            const delta = se.delta ?? {};
            if (delta.type === "input_json_delta") {
              accumulatedJson += delta.partial_json ?? "";
              if (cleanName.includes(accumulatedJson) || accumulatedJson.includes(cleanName)) {
                resolved = true;
                try { child.kill(); } catch {}
                cleanup();
                resolve(true);
                return;
              }
            }
          } else if (seType === "content_block_stop" || seType === "message_stop") {
            if (pendingToolName) {
              resolved = true;
              try { child.kill(); } catch {}
              cleanup();
              resolve(accumulatedJson.includes(cleanName));
              return;
            }
            if (seType === "message_stop") {
              resolved = true;
              try { child.kill(); } catch {}
              cleanup();
              resolve(false);
              return;
            }
          }
        } else if (event.type === "assistant") {
          const message = event.message ?? {};
          for (const contentItem of message.content ?? []) {
            if (contentItem.type !== "tool_use") continue;
            const toolName = contentItem.name ?? "";
            const toolInput = contentItem.input ?? {};
            if (toolName === "Skill" && (toolInput.skill ?? "").includes(cleanName)) {
              triggered = true;
            } else if (toolName === "Read" && (toolInput.file_path ?? "").includes(cleanName)) {
              triggered = true;
            }
          }
          resolved = true;
          try { child.kill(); } catch {}
          cleanup();
          resolve(triggered);
          return;
        } else if (event.type === "result") {
          resolved = true;
          try { child.kill(); } catch {}
          cleanup();
          resolve(triggered);
          return;
        }
      }
    });

    child.on("close", () => {
      if (!resolved) {
        resolved = true;
        cleanup();
        resolve(triggered);
      }
    });

    child.on("error", () => {
      if (!resolved) {
        resolved = true;
        cleanup();
        resolve(false);
      }
    });
  });
}

interface EvalItem {
  query: string;
  should_trigger: boolean;
}

interface EvalResult {
  query: string;
  should_trigger: boolean;
  trigger_rate: number;
  triggers: number;
  runs: number;
  pass: boolean;
}

export async function runEval(
  evalSet: EvalItem[],
  skillName: string,
  description: string,
  numWorkers: number,
  timeout: number,
  projectRoot: string,
  runsPerQuery = 1,
  triggerThreshold = 0.5,
  model: string | null = null,
): Promise<Record<string, any>> {
  const tasks: { item: EvalItem; runIdx: number }[] = [];

  for (const item of evalSet) {
    for (let runIdx = 0; runIdx < runsPerQuery; runIdx++) {
      tasks.push({ item, runIdx });
    }
  }

  // N 并发池（对齐 py 的 ProcessPoolExecutor(max_workers=N) + as_completed）：
  // worker 当前任务完成后才领取下一个，避免一次性 spawn 全部 claude 进程
  const queryTriggers: Record<string, boolean[]> = {};
  const queryItems: Record<string, EvalItem> = {};
  let cursor = 0;

  async function worker(): Promise<void> {
    while (true) {
      const idx = cursor++;
      if (idx >= tasks.length) return;
      const { item } = tasks[idx];
      const query = item.query;
      let triggered = false;
      try {
        triggered = await runSingleQuery(item.query, skillName, description, timeout, projectRoot, model);
      } catch (e) {
        process.stderr.write(`Warning: query failed: ${e}\n`);
        triggered = false;
      }
      // 按完成顺序追加（对齐 py 的 as_completed 迭代序）
      queryItems[query] = item;
      if (!queryTriggers[query]) queryTriggers[query] = [];
      queryTriggers[query].push(triggered);
    }
  }

  const workerCount = Math.max(1, Math.min(numWorkers, tasks.length));
  await Promise.all(Array.from({ length: workerCount }, () => worker()));

  const results: EvalResult[] = [];
  for (const [query, triggers] of Object.entries(queryTriggers)) {
    const item = queryItems[query];
    const triggerRate = triggers.filter(t => t).length / triggers.length;
    let didPass: boolean;
    if (item.should_trigger) {
      didPass = triggerRate >= triggerThreshold;
    } else {
      didPass = triggerRate < triggerThreshold;
    }
    results.push({
      query,
      should_trigger: item.should_trigger,
      trigger_rate: triggerRate,
      triggers: triggers.filter(t => t).length,
      runs: triggers.length,
      pass: didPass,
    });
  }

  const passed = results.filter(r => r.pass).length;
  const total = results.length;

  return {
    skill_name: skillName,
    description,
    results,
    summary: {
      total,
      passed,
      failed: total - passed,
    },
  };
}

function main() {
  const args = process.argv.slice(2);
  let evalSetPath = "";
  let skillPathArg = "";
  let descriptionOverride: string | null = null;
  let numWorkers = 10;
  let timeout = 30;
  let runsPerQuery = 3;
  let triggerThreshold = 0.5;
  let model: string | null = null;
  let verbose = false;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case "--eval-set": evalSetPath = args[++i]; break;
      case "--skill-path": skillPathArg = args[++i]; break;
      case "--description": descriptionOverride = args[++i]; break;
      case "--num-workers": numWorkers = parseInt(args[++i], 10); break;
      case "--timeout": timeout = parseInt(args[++i], 10); break;
      case "--runs-per-query": runsPerQuery = parseInt(args[++i], 10); break;
      case "--trigger-threshold": triggerThreshold = parseFloat(args[++i]); break;
      case "--model": model = args[++i]; break;
      case "--verbose": verbose = true; break;
    }
  }

  if (!evalSetPath || !skillPathArg) {
    console.log("Usage: node run_eval.ts --eval-set <path> --skill-path <path> [--description DESC] [--num-workers N] [--timeout N] [--runs-per-query N] [--trigger-threshold F] [--model M] [--verbose]");
    process.exit(1);
  }

  const evalSet = JSON.parse(fs.readFileSync(evalSetPath, "utf-8"));
  const skillPath = skillPathArg;

  if (!fs.existsSync(path.join(skillPath, "SKILL.md"))) {
    process.stderr.write(`Error: No SKILL.md found at ${skillPath}\n`);
    process.exit(1);
  }

  const { name, description: originalDescription } = parseSkillMd(skillPath);
  const description = descriptionOverride || originalDescription;
  const projectRoot = findProjectRoot();

  if (verbose) {
    process.stderr.write(`Evaluating: ${description}\n`);
  }

  runEval(
    evalSet,
    name,
    description,
    numWorkers,
    timeout,
    projectRoot,
    runsPerQuery,
    triggerThreshold,
    model,
  ).then((output) => {
    if (verbose) {
      const summary = output.summary;
      process.stderr.write(`Results: ${summary.passed}/${summary.total} passed\n`);
      for (const r of output.results) {
        const status = r.pass ? "PASS" : "FAIL";
        const rateStr = `${r.triggers}/${r.runs}`;
        process.stderr.write(`  [${status}] rate=${rateStr} expected=${r.should_trigger}: ${r.query.slice(0, 70)}\n`);
      }
    }

    console.log(JSON.stringify(output, null, 2));
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  main();
}