/**
 * aggregate_benchmark.ts — Aggregate individual run results into benchmark summary statistics.
 * 功能与 aggregate_benchmark.py 完全一致
 */
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

interface Stats {
  mean: number;
  stddev: number;
  min: number;
  max: number;
}

function calculateStats(values: number[]): Stats {
  if (values.length === 0) {
    return { mean: 0, stddev: 0, min: 0, max: 0 };
  }

  const n = values.length;
  const mean = values.reduce((a, b) => a + b, 0) / n;

  let stddev = 0;
  if (n > 1) {
    const variance = values.reduce((sum, x) => sum + (x - mean) ** 2, 0) / (n - 1);
    stddev = Math.sqrt(variance);
  }

  return {
    mean: round(mean, 4),
    stddev: round(stddev, 4),
    min: round(Math.min(...values), 4),
    max: round(Math.max(...values), 4),
  };
}

function round(x: number, digits: number): number {
  const factor = 10 ** digits;
  return Math.round(x * factor) / factor;
}

interface RunResult {
  eval_id: number | string;
  run_number: number;
  pass_rate: number;
  passed: number;
  failed: number;
  total: number;
  time_seconds: number;
  tokens?: number;
  tool_calls: number;
  errors: number;
  expectations: unknown[];
  notes: unknown[];
}

function loadRunResults(benchmarkDir: string): Record<string, RunResult[]> {
  const runsDir = path.join(benchmarkDir, "runs");
  let searchDir: string;

  if (fs.existsSync(runsDir) && fs.statSync(runsDir).isDirectory()) {
    searchDir = runsDir;
  } else {
    const evalDirs = fs.readdirSync(benchmarkDir)
      .filter(d => d.startsWith("eval-"))
      .map(d => path.join(benchmarkDir, d));
    if (evalDirs.length > 0) {
      searchDir = benchmarkDir;
    } else {
      console.log(`No eval directories found in ${benchmarkDir} or ${runsDir}`);
      return {};
    }
  }

  const results: Record<string, RunResult[]> = {};

  const evalDirs = fs.readdirSync(searchDir)
    .filter(d => d.startsWith("eval-"))
    .sort()
    .map(d => path.join(searchDir, d));

  for (let evalIdx = 0; evalIdx < evalDirs.length; evalIdx++) {
    const evalDir = evalDirs[evalIdx];
    const evalDirName = path.basename(evalDir);

    let evalId: number | string = evalIdx;
    const metadataPath = path.join(evalDir, "eval_metadata.json");
    if (fs.existsSync(metadataPath)) {
      try {
        const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf-8"));
        evalId = metadata.eval_id ?? evalIdx;
      } catch {
        evalId = evalIdx;
      }
    } else {
      try {
        evalId = parseInt(evalDirName.split("-")[1], 10);
      } catch {
        evalId = evalIdx;
      }
    }

    const configDirs = fs.readdirSync(evalDir)
      .filter(d => fs.statSync(path.join(evalDir, d)).isDirectory())
      .sort()
      .map(d => path.join(evalDir, d));

    for (const configDir of configDirs) {
      const runDirs = fs.readdirSync(configDir)
        .filter(d => d.startsWith("run-"))
        .sort()
        .map(d => path.join(configDir, d));
      if (runDirs.length === 0) continue;

      const config = path.basename(configDir);
      if (!(config in results)) {
        results[config] = [];
      }

      for (const runDir of runDirs) {
        const runNumber = parseInt(path.basename(runDir).split("-")[1], 10);
        const gradingFile = path.join(runDir, "grading.json");

        if (!fs.existsSync(gradingFile)) {
          console.log(`Warning: grading.json not found in ${runDir}`);
          continue;
        }

        let grading: any;
        try {
          grading = JSON.parse(fs.readFileSync(gradingFile, "utf-8"));
        } catch (e) {
          console.log(`Warning: Invalid JSON in ${gradingFile}: ${e}`);
          continue;
        }

        const result: RunResult = {
          eval_id: evalId,
          run_number: runNumber,
          pass_rate: grading.summary?.pass_rate ?? 0.0,
          passed: grading.summary?.passed ?? 0,
          failed: grading.summary?.failed ?? 0,
          total: grading.summary?.total ?? 0,
          time_seconds: 0,
          tokens: undefined,
          tool_calls: 0,
          errors: 0,
          expectations: [],
          notes: [],
        };

        const timing = grading.timing ?? {};
        result.time_seconds = timing.total_duration_seconds ?? 0.0;
        const timingFile = path.join(runDir, "timing.json");
        if (result.time_seconds === 0.0 && fs.existsSync(timingFile)) {
          try {
            const timingData = JSON.parse(fs.readFileSync(timingFile, "utf-8"));
            result.time_seconds = timingData.total_duration_seconds ?? 0.0;
            result.tokens = timingData.total_tokens ?? 0;
          } catch {
            // ignore
          }
        }

        const metrics = grading.execution_metrics ?? {};
        result.tool_calls = metrics.total_tool_calls ?? 0;
        if (result.tokens === undefined) {
          result.tokens = metrics.output_chars ?? 0;
        }
        result.errors = metrics.errors_encountered ?? 0;

        const rawExpectations = grading.expectations ?? [];
        for (const exp of rawExpectations) {
          if (!("text" in exp) || !("passed" in exp)) {
            console.log(`Warning: expectation in ${gradingFile} missing required fields (text, passed, evidence): ${JSON.stringify(exp)}`);
          }
        }
        result.expectations = rawExpectations;

        const notesSummary = grading.user_notes_summary ?? {};
        const notes: unknown[] = [];
        notes.push(...(notesSummary.uncertainties ?? []));
        notes.push(...(notesSummary.needs_review ?? []));
        notes.push(...(notesSummary.workarounds ?? []));
        result.notes = notes;

        results[config].push(result);
      }
    }
  }

  return results;
}

function aggregateResults(results: Record<string, RunResult[]>): Record<string, unknown> {
  const runSummary: Record<string, unknown> = {};
  const configs = Object.keys(results);

  for (const config of configs) {
    const runs = results[config] ?? [];

    if (runs.length === 0) {
      runSummary[config] = {
        pass_rate: { mean: 0, stddev: 0, min: 0, max: 0 },
        time_seconds: { mean: 0, stddev: 0, min: 0, max: 0 },
        tokens: { mean: 0, stddev: 0, min: 0, max: 0 },
      };
      continue;
    }

    const passRates = runs.map(r => r.pass_rate);
    const times = runs.map(r => r.time_seconds);
    const tokens = runs.map(r => r.tokens ?? 0);

    runSummary[config] = {
      pass_rate: calculateStats(passRates),
      time_seconds: calculateStats(times),
      tokens: calculateStats(tokens),
    };
  }

  let primary: any = {};
  let baseline: any = {};
  if (configs.length >= 2) {
    primary = runSummary[configs[0]] ?? {};
    baseline = runSummary[configs[1]] ?? {};
  } else if (configs.length >= 1) {
    primary = runSummary[configs[0]] ?? {};
  }

  const deltaPassRate = (primary.pass_rate?.mean ?? 0) - (baseline.pass_rate?.mean ?? 0);
  const deltaTime = (primary.time_seconds?.mean ?? 0) - (baseline.time_seconds?.mean ?? 0);
  const deltaTokens = (primary.tokens?.mean ?? 0) - (baseline.tokens?.mean ?? 0);

  runSummary["delta"] = {
    pass_rate: `${deltaPassRate >= 0 ? "+" : ""}${deltaPassRate.toFixed(2)}`,
    time_seconds: `${deltaTime >= 0 ? "+" : ""}${deltaTime.toFixed(1)}`,
    tokens: `${deltaTokens >= 0 ? "+" : ""}${deltaTokens.toFixed(0)}`,
  };

  return runSummary;
}

function generateBenchmark(benchmarkDir: string, skillName = "", skillPath = ""): Record<string, unknown> {
  const results = loadRunResults(benchmarkDir);
  const runSummary = aggregateResults(results);

  const runs: unknown[] = [];
  for (const config of Object.keys(results)) {
    for (const result of results[config]) {
      runs.push({
        eval_id: result.eval_id,
        configuration: config,
        run_number: result.run_number,
        result: {
          pass_rate: result.pass_rate,
          passed: result.passed,
          failed: result.failed,
          total: result.total,
          time_seconds: result.time_seconds,
          tokens: result.tokens ?? 0,
          tool_calls: result.tool_calls,
          errors: result.errors,
        },
        expectations: result.expectations,
        notes: result.notes,
      });
    }
  }

  const evalIds = Array.from(new Set(
    Object.values(results).flat().map(r => r.eval_id)
  )).sort();

  const timestamp = new Date().toISOString().replace(/\.\d+Z$/, "Z");

  return {
    metadata: {
      skill_name: skillName || "<skill-name>",
      skill_path: skillPath || "<path/to/skill>",
      executor_model: "<model-name>",
      analyzer_model: "<model-name>",
      timestamp,
      evals_run: evalIds,
      runs_per_configuration: 3,
    },
    runs,
    run_summary: runSummary,
    notes: [],
  };
}

function generateMarkdown(benchmark: Record<string, any>): string {
  const metadata = benchmark.metadata;
  const runSummary = benchmark.run_summary;

  const configs = Object.keys(runSummary).filter(k => k !== "delta");
  const configA = configs[0] ?? "config_a";
  const configB = configs[1] ?? "config_b";
  const labelA = configA.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
  const labelB = configB.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());

  const lines: string[] = [
    `# Skill Benchmark: ${metadata.skill_name}`,
    "",
    `**Model**: ${metadata.executor_model}`,
    `**Date**: ${metadata.timestamp}`,
    `**Evals**: ${metadata.evals_run.map(String).join(", ")} (${metadata.runs_per_configuration} runs each per configuration)`,
    "",
    "## Summary",
    "",
    `| Metric | ${labelA} | ${labelB} | Delta |`,
    "|--------|------------|---------------|-------|",
  ];

  const aSummary = runSummary[configA] ?? {};
  const bSummary = runSummary[configB] ?? {};
  const delta = runSummary.delta ?? {};

  const aPr = aSummary.pass_rate ?? {};
  const bPr = bSummary.pass_rate ?? {};
  lines.push(`| Pass Rate | ${(aPr.mean ?? 0) * 100 | 0}% ± ${(aPr.stddev ?? 0) * 100 | 0}% | ${(bPr.mean ?? 0) * 100 | 0}% ± ${(bPr.stddev ?? 0) * 100 | 0}% | ${delta.pass_rate ?? "—"} |`);

  const aTime = aSummary.time_seconds ?? {};
  const bTime = bSummary.time_seconds ?? {};
  lines.push(`| Time | ${(aTime.mean ?? 0).toFixed(1)}s ± ${(aTime.stddev ?? 0).toFixed(1)}s | ${(bTime.mean ?? 0).toFixed(1)}s ± ${(bTime.stddev ?? 0).toFixed(1)}s | ${delta.time_seconds ?? "—"}s |`);

  const aTokens = aSummary.tokens ?? {};
  const bTokens = bSummary.tokens ?? {};
  lines.push(`| Tokens | ${(aTokens.mean ?? 0).toFixed(0)} ± ${(aTokens.stddev ?? 0).toFixed(0)} | ${(bTokens.mean ?? 0).toFixed(0)} ± ${(bTokens.stddev ?? 0).toFixed(0)} | ${delta.tokens ?? "—"} |`);

  if (benchmark.notes && benchmark.notes.length > 0) {
    lines.push("", "## Notes", "");
    for (const note of benchmark.notes) {
      lines.push(`- ${note}`);
    }
  }

  return lines.join("\n");
}

function parseArgs(): { benchmarkDir: string; skillName: string; skillPath: string; output: string | null } {
  const args = process.argv.slice(2);
  let benchmarkDir = "";
  let skillName = "";
  let skillPath = "";
  let output: string | null = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--skill-name") {
      skillName = args[++i];
    } else if (args[i] === "--skill-path") {
      skillPath = args[++i];
    } else if (args[i] === "--output" || args[i] === "-o") {
      output = args[++i];
    } else if (!args[i].startsWith("-")) {
      benchmarkDir = args[i];
    }
  }

  return { benchmarkDir, skillName, skillPath, output };
}

function main() {
  const args = parseArgs();
  if (!args.benchmarkDir) {
    console.log("Usage: node aggregate_benchmark.ts <benchmark_dir> [--skill-name NAME] [--skill-path PATH] [--output PATH]");
    process.exit(1);
  }

  if (!fs.existsSync(args.benchmarkDir)) {
    console.log(`Directory not found: ${args.benchmarkDir}`);
    process.exit(1);
  }

  const benchmark = generateBenchmark(args.benchmarkDir, args.skillName, args.skillPath);

  const outputJson = args.output || path.join(args.benchmarkDir, "benchmark.json");
  const outputMd = outputJson.replace(/\.json$/, ".md");

  fs.writeFileSync(outputJson, JSON.stringify(benchmark, null, 2));
  console.log(`Generated: ${outputJson}`);

  const markdown = generateMarkdown(benchmark);
  fs.writeFileSync(outputMd, markdown);
  console.log(`Generated: ${outputMd}`);

  const runSummary = benchmark.run_summary as Record<string, any>;
  const configs = Object.keys(runSummary).filter(k => k !== "delta");
  const delta = runSummary.delta ?? {};

  console.log("\nSummary:");
  for (const config of configs) {
    const pr = runSummary[config].pass_rate.mean;
    const label = config.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    console.log(`  ${label}: ${(pr * 100).toFixed(1)}% pass rate`);
  }
  console.log(`  Delta:         ${delta.pass_rate ?? "—"}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  main();
}