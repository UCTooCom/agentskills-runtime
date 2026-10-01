/**
 * run_loop.ts — Run the eval + improve loop until all pass or max iterations reached.
 * 功能与 run_loop.py 完全一致
 */
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { exec } from "child_process";
import { fileURLToPath } from "url";
import { generateHtml } from "./generate_report.ts";
import { improveDescription } from "./improve_description.ts";
import { findProjectRoot, runEval } from "./run_eval.ts";
import { parseSkillMd } from "./utils.ts";

const pad2 = (n: number): string => String(n).padStart(2, "0");
// 本地时间戳 YYYYMMDD_HHMMSS（对齐 py 的 time.strftime("%Y%m%d_%H%M%S")，本地时间）
function localCompact(d: Date = new Date()): string {
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}_${pad2(d.getHours())}${pad2(d.getMinutes())}${pad2(d.getSeconds())}`;
}
// 本地时间戳 YYYY-MM-DD_HHMMSS（对齐 py 的 time.strftime("%Y-%m-%d_%H%M%S")，本地时间）
function localDashed(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}_${pad2(d.getHours())}${pad2(d.getMinutes())}${pad2(d.getSeconds())}`;
}

interface EvalItem {
  query: string;
  should_trigger: boolean;
}

function splitEvalSet(evalSet: EvalItem[], holdout: number, seed = 42): [EvalItem[], EvalItem[]] {
  // 简单的 seeded shuffle
  let rng = seed;
  function random(): number {
    rng = (rng * 1664525 + 1013904223) & 0xffffffff;
    return rng / 0xffffffff;
  }
  function shuffle(arr: EvalItem[]): EvalItem[] {
    const result = [...arr];
    for (let i = result.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  }

  const trigger = evalSet.filter(e => e.should_trigger);
  const noTrigger = evalSet.filter(e => !e.should_trigger);

  const shuffledTrigger = shuffle(trigger);
  const shuffledNoTrigger = shuffle(noTrigger);

  const nTriggerTest = Math.max(1, Math.floor(trigger.length * holdout));
  const nNoTriggerTest = Math.max(1, Math.floor(noTrigger.length * holdout));

  const testSet = shuffledTrigger.slice(0, nTriggerTest).concat(shuffledNoTrigger.slice(0, nNoTriggerTest));
  const trainSet = shuffledTrigger.slice(nTriggerTest).concat(shuffledNoTrigger.slice(nNoTriggerTest));

  return [trainSet, testSet];
}

function openBrowser(url: string): void {
  const platform = process.platform;
  let cmd: string;
  if (platform === "win32") {
    cmd = `start "" "${url}"`;
  } else if (platform === "darwin") {
    cmd = `open "${url}"`;
  } else {
    cmd = `xdg-open "${url}"`;
  }
  exec(cmd, () => {});
}

interface HistoryItem {
  iteration: number;
  description: string;
  train_passed: number;
  train_failed: number;
  train_total: number;
  train_results: any[];
  test_passed: number | null;
  test_failed: number | null;
  test_total: number | null;
  test_results: any[] | null;
  passed: number;
  failed: number;
  total: number;
  results: any[];
}

async function runLoop(
  evalSet: EvalItem[],
  skillPath: string,
  descriptionOverride: string | null,
  numWorkers: number,
  timeout: number,
  maxIterations: number,
  runsPerQuery: number,
  triggerThreshold: number,
  holdout: number,
  model: string,
  verbose: boolean,
  liveReportPath: string | null = null,
  logDir: string | null = null,
): Promise<Record<string, any>> {
  const projectRoot = findProjectRoot();
  const { name, description: originalDescription, content } = parseSkillMd(skillPath);
  let currentDescription = descriptionOverride || originalDescription;

  let trainSet: EvalItem[];
  let testSet: EvalItem[];
  if (holdout > 0) {
    [trainSet, testSet] = splitEvalSet(evalSet, holdout);
    if (verbose) {
      process.stderr.write(`Split: ${trainSet.length} train, ${testSet.length} test (holdout=${holdout})\n`);
    }
  } else {
    trainSet = evalSet;
    testSet = [];
  }

  const history: HistoryItem[] = [];
  let exitReason = "unknown";

  for (let iteration = 1; iteration <= maxIterations; iteration++) {
    if (verbose) {
      process.stderr.write(`\n${"=".repeat(60)}\n`);
      process.stderr.write(`Iteration ${iteration}/${maxIterations}\n`);
      process.stderr.write(`Description: ${currentDescription}\n`);
      process.stderr.write(`${"=".repeat(60)}\n`);
    }

    const allQueries = trainSet.concat(testSet);
    const t0 = Date.now();
    const allResults = await runEval(
      allQueries,
      name,
      currentDescription,
      numWorkers,
      timeout,
      projectRoot,
      runsPerQuery,
      triggerThreshold,
      model,
    );
    const evalElapsed = (Date.now() - t0) / 1000;

    const trainQueriesSet = new Set(trainSet.map(q => q.query));
    const trainResultList = allResults.results.filter((r: any) => trainQueriesSet.has(r.query));
    const testResultList = allResults.results.filter((r: any) => !trainQueriesSet.has(r.query));

    const trainPassed = trainResultList.filter((r: any) => r.pass).length;
    const trainTotal = trainResultList.length;
    const trainSummary = { passed: trainPassed, failed: trainTotal - trainPassed, total: trainTotal };
    const trainResults = { results: trainResultList, summary: trainSummary };

    let testResults: { results: any[]; summary: { passed: number; failed: number; total: number } } | null = null;
    let testSummary: { passed: number; failed: number; total: number } | null = null;
    if (testSet.length > 0) {
      const testPassed = testResultList.filter((r: any) => r.pass).length;
      const testTotal = testResultList.length;
      testSummary = { passed: testPassed, failed: testTotal - testPassed, total: testTotal };
      testResults = { results: testResultList, summary: testSummary };
    }

    history.push({
      iteration,
      description: currentDescription,
      train_passed: trainSummary.passed,
      train_failed: trainSummary.failed,
      train_total: trainSummary.total,
      train_results: trainResults.results,
      test_passed: testSummary ? testSummary.passed : null,
      test_failed: testSummary ? testSummary.failed : null,
      test_total: testSummary ? testSummary.total : null,
      test_results: testResults ? testResults.results : null,
      passed: trainSummary.passed,
      failed: trainSummary.failed,
      total: trainSummary.total,
      results: trainResults.results,
    });

    if (liveReportPath) {
      const partialOutput = {
        original_description: originalDescription,
        best_description: currentDescription,
        best_score: "in progress",
        iterations_run: history.length,
        holdout,
        train_size: trainSet.length,
        test_size: testSet.length,
        history,
      };
      fs.writeFileSync(liveReportPath, generateHtml(partialOutput, true, name));
    }

    if (verbose) {
      const printEvalStats = (label: string, results: any[], elapsed: number) => {
        const pos = results.filter((r: any) => r.should_trigger);
        const neg = results.filter((r: any) => !r.should_trigger);
        const tp = pos.reduce((sum: number, r: any) => sum + r.triggers, 0);
        const posRuns = pos.reduce((sum: number, r: any) => sum + r.runs, 0);
        const fn = posRuns - tp;
        const fp = neg.reduce((sum: number, r: any) => sum + r.triggers, 0);
        const negRuns = neg.reduce((sum: number, r: any) => sum + r.runs, 0);
        const tn = negRuns - fp;
        const total = tp + tn + fp + fn;
        const precision = tp + fp > 0 ? tp / (tp + fp) : 1.0;
        const recall = tp + fn > 0 ? tp / (tp + fn) : 1.0;
        const accuracy = total > 0 ? (tp + tn) / total : 0.0;
        process.stderr.write(`${label}: ${tp + tn}/${total} correct, precision=${(precision * 100).toFixed(0)}% recall=${(recall * 100).toFixed(0)}% accuracy=${(accuracy * 100).toFixed(0)}% (${elapsed.toFixed(1)}s)\n`);
        for (const r of results) {
          const status = r.pass ? "PASS" : "FAIL";
          const rateStr = `${r.triggers}/${r.runs}`;
          process.stderr.write(`  [${status}] rate=${rateStr} expected=${r.should_trigger}: ${r.query.slice(0, 60)}\n`);
        }
      };

      printEvalStats("Train", trainResults.results, evalElapsed);
      if (testSummary) {
        printEvalStats("Test ", testResults!.results, 0);
      }
    }

    if (trainSummary.failed === 0) {
      exitReason = `all_passed (iteration ${iteration})`;
      if (verbose) {
        process.stderr.write(`\nAll train queries passed on iteration ${iteration}!\n`);
      }
      break;
    }

    if (iteration === maxIterations) {
      exitReason = `max_iterations (${maxIterations})`;
      if (verbose) {
        process.stderr.write(`\nMax iterations reached (${maxIterations}).\n`);
      }
      break;
    }

    if (verbose) {
      process.stderr.write("\nImproving description...\n");
    }

    const t1 = Date.now();
    const blindedHistory = history.map(h => {
      const result: Record<string, any> = {};
      for (const [k, v] of Object.entries(h)) {
        if (!k.startsWith("test_")) {
          result[k] = v;
        }
      }
      return result;
    });
    // 对齐 py：不向优化 prompt 传 test 结果，保持 train/test 防过拟合语义
    // （py 调用 improve_description 时 test_results 缺省，prompt 只显示 Train: x/y）
    const newDescription = improveDescription(
      name,
      content,
      currentDescription,
      trainResults as any,
      blindedHistory,
      model,
      undefined as any,
      logDir,
      iteration,
    );
    const improveElapsed = (Date.now() - t1) / 1000;

    if (verbose) {
      process.stderr.write(`Proposed (${improveElapsed.toFixed(1)}s): ${newDescription}\n`);
    }

    currentDescription = newDescription;
  }

  let best: HistoryItem;
  let bestScore: string;
  if (testSet.length > 0) {
    best = history.reduce((b, h) => ((h.test_passed ?? 0) > (b.test_passed ?? 0) ? h : b), history[0]);
    bestScore = `${best.test_passed}/${best.test_total}`;
  } else {
    best = history.reduce((b, h) => h.train_passed > b.train_passed ? h : b, history[0]);
    bestScore = `${best.train_passed}/${best.train_total}`;
  }

  if (verbose) {
    process.stderr.write(`\nExit reason: ${exitReason}\n`);
    process.stderr.write(`Best score: ${bestScore} (iteration ${best.iteration})\n`);
  }

  return {
    exit_reason: exitReason,
    original_description: originalDescription,
    best_description: best.description,
    best_score: bestScore,
    best_train_score: `${best.train_passed}/${best.train_total}`,
    best_test_score: testSet.length > 0 ? `${best.test_passed}/${best.test_total}` : null,
    final_description: currentDescription,
    iterations_run: history.length,
    holdout,
    train_size: trainSet.length,
    test_size: testSet.length,
    history,
  };
}

function main() {
  const args = process.argv.slice(2);
  let evalSetPath = "";
  let skillPathArg = "";
  let descriptionOverride: string | null = null;
  let numWorkers = 10;
  let timeout = 30;
  let maxIterations = 5;
  let runsPerQuery = 3;
  let triggerThreshold = 0.5;
  let holdout = 0.4;
  let model = "";
  let verbose = false;
  let report = "auto";
  let resultsDirArg: string | null = null;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
      case "--eval-set": evalSetPath = args[++i]; break;
      case "--skill-path": skillPathArg = args[++i]; break;
      case "--description": descriptionOverride = args[++i]; break;
      case "--num-workers": numWorkers = parseInt(args[++i], 10); break;
      case "--timeout": timeout = parseInt(args[++i], 10); break;
      case "--max-iterations": maxIterations = parseInt(args[++i], 10); break;
      case "--runs-per-query": runsPerQuery = parseInt(args[++i], 10); break;
      case "--trigger-threshold": triggerThreshold = parseFloat(args[++i]); break;
      case "--holdout": holdout = parseFloat(args[++i]); break;
      case "--model": model = args[++i]; break;
      case "--verbose": verbose = true; break;
      case "--report": report = args[++i]; break;
      case "--results-dir": resultsDirArg = args[++i]; break;
    }
  }

  if (!evalSetPath || !skillPathArg || !model) {
    console.log("Usage: node run_loop.ts --eval-set <path> --skill-path <path> --model <model> [--description DESC] [--num-workers N] [--timeout N] [--max-iterations N] [--runs-per-query N] [--trigger-threshold F] [--holdout F] [--verbose] [--report PATH] [--results-dir DIR]");
    process.exit(1);
  }

  const evalSet = JSON.parse(fs.readFileSync(evalSetPath, "utf-8"));
  const skillPath = skillPathArg;

  if (!fs.existsSync(path.join(skillPath, "SKILL.md"))) {
    process.stderr.write(`Error: No SKILL.md found at ${skillPath}\n`);
    process.exit(1);
  }

  const { name } = parseSkillMd(skillPath);

  let liveReportPath: string | null = null;
  if (report !== "none") {
    if (report === "auto") {
      const timestamp = localCompact();
      liveReportPath = path.join(os.tmpdir(), `skill_description_report_${path.basename(skillPath)}_${timestamp}.html`);
    } else {
      liveReportPath = report;
    }
    fs.writeFileSync(liveReportPath, "<html><body><h1>Starting optimization loop...</h1><meta http-equiv='refresh' content='5'></body></html>");
    openBrowser(liveReportPath);
  }

  let resultsDir: string | null = null;
  if (resultsDirArg) {
    const timestamp = localDashed();
    resultsDir = path.join(resultsDirArg, timestamp);
    fs.mkdirSync(resultsDir, { recursive: true });
  }

  const logDir = resultsDir ? path.join(resultsDir, "logs") : null;

  runLoop(
    evalSet,
    skillPath,
    descriptionOverride,
    numWorkers,
    timeout,
    maxIterations,
    runsPerQuery,
    triggerThreshold,
    holdout,
    model,
    verbose,
    liveReportPath,
    logDir,
  ).then((output) => {
    const jsonOutput = JSON.stringify(output, null, 2);
    console.log(jsonOutput);
    if (resultsDir) {
      fs.writeFileSync(path.join(resultsDir, "results.json"), jsonOutput);
    }

    if (liveReportPath) {
      fs.writeFileSync(liveReportPath, generateHtml(output, false, name));
      process.stderr.write(`\nReport: ${liveReportPath}\n`);
    }

    if (resultsDir && liveReportPath) {
      fs.writeFileSync(path.join(resultsDir, "report.html"), generateHtml(output, false, name));
    }

    if (resultsDir) {
      process.stderr.write(`Results saved to: ${resultsDir}\n`);
    }
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  main();
}