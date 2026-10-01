/**
 * improve_description.ts — Improve a skill description based on eval results.
 * 功能与 improve_description.py 完全一致
 */
import * as fs from "fs";
import * as path from "path";
import { execFileSync } from "child_process";
import { fileURLToPath } from "url";
import { parseSkillMd } from "./utils.ts";

function callClaude(prompt: string, model: string | null, timeout = 300): string {
  const cmd: string[] = ["claude", "-p", "--output-format", "text"];
  if (model) {
    cmd.push("--model", model);
  }

  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (k !== "CLAUDECODE" && v !== undefined) {
      env[k] = v;
    }
  }

  try {
    const stdout = execFileSync("claude", cmd.slice(1), {
      input: prompt,
      encoding: "utf-8",
      env,
      timeout: timeout * 1000,
      maxBuffer: 50 * 1024 * 1024,
    });
    return stdout;
  } catch (e: any) {
    throw new Error(`claude -p exited with error: ${e.message}`);
  }
}

interface EvalResultItem {
  query: string;
  should_trigger: boolean;
  pass: boolean;
  triggers: number;
  runs: number;
}

interface EvalResults {
  results: EvalResultItem[];
  summary: { passed: number; failed: number; total: number };
  description: string;
}

interface HistoryItem {
  description?: string;
  train_passed?: number;
  train_total?: number;
  passed?: number;
  total?: number;
  test_passed?: number | null;
  test_total?: number | null;
  results?: EvalResultItem[];
  note?: string;
}

export function improveDescription(
  skillName: string,
  skillContent: string,
  currentDescription: string,
  evalResults: EvalResults,
  history: HistoryItem[],
  model: string,
  testResults: { summary: { passed: number; total: number } } | null = null,
  logDir: string | null = null,
  iteration: number | null = null,
): string {
  const failedTriggers = evalResults.results.filter(r => r.should_trigger && !r.pass);
  const falseTriggers = evalResults.results.filter(r => !r.should_trigger && !r.pass);

  const trainScore = `${evalResults.summary.passed}/${evalResults.summary.total}`;
  let scoresSummary: string;
  if (testResults) {
    const testScore = `${testResults.summary.passed}/${testResults.summary.total}`;
    scoresSummary = `Train: ${trainScore}, Test: ${testScore}`;
  } else {
    scoresSummary = `Train: ${trainScore}`;
  }

  let prompt = `You are optimizing a skill description for a Claude Code skill called "${skillName}". A "skill" is sort of like a prompt, but with progressive disclosure -- there's a title and description that Claude sees when deciding whether to use the skill, and then if it does use the skill, it reads the .md file which has lots more details and potentially links to other resources in the skill folder like helper files and scripts and additional documentation or examples.

The description appears in Claude's "available_skills" list. When a user sends a query, Claude decides whether to invoke the skill based solely on the title and on this description. Your goal is to write a description that triggers for relevant queries, and doesn't trigger for irrelevant ones.

Here's the current description:
<current_description>
"${currentDescription}"
</current_description>

Current scores (${scoresSummary}):
<scores_summary>
`;

  if (failedTriggers.length > 0) {
    prompt += "FAILED TO TRIGGER (should have triggered but didn't):\n";
    for (const r of failedTriggers) {
      prompt += `  - "${r.query}" (triggered ${r.triggers}/${r.runs} times)\n`;
    }
    prompt += "\n";
  }

  if (falseTriggers.length > 0) {
    prompt += "FALSE TRIGGERS (triggered but shouldn't have):\n";
    for (const r of falseTriggers) {
      prompt += `  - "${r.query}" (triggered ${r.triggers}/${r.runs} times)\n`;
    }
    prompt += "\n";
  }

  if (history.length > 0) {
    prompt += "PREVIOUS ATTEMPTS (do NOT repeat these — try something structurally different):\n\n";
    for (const h of history) {
      const trainS = `${h.train_passed ?? h.passed ?? 0}/${h.train_total ?? h.total ?? 0}`;
      const testS = h.test_passed !== null && h.test_passed !== undefined ? `${h.test_passed}/${h.test_total}` : null;
      const scoreStr = `train=${trainS}` + (testS ? `, test=${testS}` : "");
      prompt += `<attempt ${scoreStr}>\n`;
      prompt += `Description: "${h.description}"\n`;
      if (h.results) {
        prompt += "Train results:\n";
        for (const r of h.results) {
          const status = r.pass ? "PASS" : "FAIL";
          prompt += `  [${status}] "${r.query.slice(0, 80)}" (triggered ${r.triggers}/${r.runs})\n`;
        }
      }
      if (h.note) {
        prompt += `Note: ${h.note}\n`;
      }
      prompt += "</attempt>\n\n";
    }
  }

  prompt += `</scores_summary>

Skill content (for context on what the skill does):
<skill_content>
${skillContent}
</skill_content>

Based on the failures, write a new and improved description that is more likely to trigger correctly. When I say "based on the failures", it's a bit of a tricky line to walk because we don't want to overfit to the specific cases you're seeing. So what I DON'T want you to do is produce an ever-expanding list of specific queries that this skill should or shouldn't trigger for. Instead, try to generalize from the failures to broader categories of user intent and situations where this skill would be useful or not useful. The reason for this is twofold:

1. Avoid overfitting
2. The list might get loooong and it's injected into ALL queries and there might be a lot of skills, so we don't want to blow too much space on any given description.

Concretely, your description should not be more than about 100-200 words, even if that comes at the cost of accuracy. There is a hard limit of 1024 characters — descriptions over that will be truncated, so stay comfortably under it.

Here are some tips that we've found to work well in writing these descriptions:
- The skill should be phrased in the imperative -- "Use this skill for" rather than "this skill does"
- The skill description should focus on the user's intent, what they are trying to achieve, vs. the implementation details of how the skill works.
- The description competes with other skills for Claude's attention — make it distinctive and immediately recognizable.
- If you're getting lots of failures after repeated attempts, change things up. Try different sentence structures or wordings.

I'd encourage you to be creative and mix up the style in different iterations since you'll have multiple opportunities to try different approaches and we'll just grab the highest-scoring one at the end. 

Please respond with only the new description text in <new_description> tags, nothing else.`;

  const text = callClaude(prompt, model);

  let match = text.match(/<new_description>(.*?)<\/new_description>/s);
  let description = match ? match[1].trim().replace(/^["']|["']$/g, "") : text.trim().replace(/^["']|["']$/g, "");

  const transcript: Record<string, unknown> = {
    iteration,
    prompt,
    response: text,
    parsed_description: description,
    char_count: description.length,
    over_limit: description.length > 1024,
  };

  if (description.length > 1024) {
    const shortenPrompt =
      `${prompt}\n\n` +
      `---\n\n` +
      `A previous attempt produced this description, which at ` +
      `${description.length} characters is over the 1024-character hard limit:\n\n` +
      `"${description}"\n\n` +
      `Rewrite it to be under 1024 characters while keeping the most ` +
      `important trigger words and intent coverage. Respond with only ` +
      `the new description in <new_description> tags.`;
    const shortenText = callClaude(shortenPrompt, model);
    match = shortenText.match(/<new_description>(.*?)<\/new_description>/s);
    const shortened = match ? match[1].trim().replace(/^["']|["']$/g, "") : shortenText.trim().replace(/^["']|["']$/g, "");

    transcript.rewrite_prompt = shortenPrompt;
    transcript.rewrite_response = shortenText;
    transcript.rewrite_description = shortened;
    transcript.rewrite_char_count = shortened.length;
    description = shortened;
  }

  transcript.final_description = description;

  if (logDir) {
    fs.mkdirSync(logDir, { recursive: true });
    const logFile = path.join(logDir, `improve_iter_${iteration ?? "unknown"}.json`);
    fs.writeFileSync(logFile, JSON.stringify(transcript, null, 2));
  }

  return description;
}

function main() {
  const args = process.argv.slice(2);
  let evalResultsPath = "";
  let skillPathArg = "";
  let historyPath: string | null = null;
  let model = "";
  let verbose = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--eval-results") {
      evalResultsPath = args[++i];
    } else if (args[i] === "--skill-path") {
      skillPathArg = args[++i];
    } else if (args[i] === "--history") {
      historyPath = args[++i];
    } else if (args[i] === "--model") {
      model = args[++i];
    } else if (args[i] === "--verbose") {
      verbose = true;
    }
  }

  if (!evalResultsPath || !skillPathArg || !model) {
    console.log("Usage: node improve_description.ts --eval-results <path> --skill-path <path> --model <model> [--history <path>] [--verbose]");
    process.exit(1);
  }

  const skillPath = skillPathArg;
  if (!fs.existsSync(path.join(skillPath, "SKILL.md"))) {
    process.stderr.write(`Error: No SKILL.md found at ${skillPath}\n`);
    process.exit(1);
  }

  const evalResults = JSON.parse(fs.readFileSync(evalResultsPath, "utf-8"));
  let history: HistoryItem[] = [];
  if (historyPath) {
    history = JSON.parse(fs.readFileSync(historyPath, "utf-8"));
  }

  const { name, content } = parseSkillMd(skillPath);
  const currentDescription = evalResults.description;

  if (verbose) {
    process.stderr.write(`Current: ${currentDescription}\n`);
    process.stderr.write(`Score: ${evalResults.summary.passed}/${evalResults.summary.total}\n`);
  }

  const newDescription = improveDescription(
    name,
    content,
    currentDescription,
    evalResults,
    history,
    model,
  );

  if (verbose) {
    process.stderr.write(`Improved: ${newDescription}\n`);
  }

  const output = {
    description: newDescription,
    history: history.concat([{
      description: currentDescription,
      passed: evalResults.summary.passed,
      failed: evalResults.summary.failed,
      total: evalResults.summary.total,
      results: evalResults.results,
    }]),
  };
  console.log(JSON.stringify(output, null, 2));
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  main();
}