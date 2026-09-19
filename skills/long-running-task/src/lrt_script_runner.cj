/*
 * 脚本运行器（long-running-task / Ch3-7 公用）
 * 经 std.process 调 D 层 Python 脚本（scripts/），捕获 stdout JSON。
 *
 * 编码依据：src/tool/cli_tool.cj 的 executeWithCapture 范式
 *   - launch(name, args, workingDirectory, environment, stdIn/stdOut/stdErr: ProcessRedirect.Pipe)
 *   - subProcess.stdOutPipe / stdErrPipe / wait(timeout: Duration): Int32
 *
 * 解释器：env LRT_PYTHON 优先，否则 "python3" → "python"
 * 脚本目录：env LRT_SCRIPTS_DIR 优先，否则进程 cwd 下的 "scripts/"
 *
 * ── 工作目录（Ch8 修复）──────────────────────────────────────────────
 * **子进程 cwd 必须是技能根目录，而不是 scripts 目录**。
 * 依据：COMPOSITION.yaml 中每步的 `outdir` 都写成相对技能根的路径
 * （如 `output/parsed`、`output/planned`），D 层脚本按此相对路径 mkdir + 写文件。
 * 若把 cwd 设为 scripts/，产物会落到 `scripts/output/...`，与 SOP 约定的
 * `output/{parsed,planned,executed,extended,verified}/` 布局不一致，
 * 且后续步骤按 `output/...` 找文件时会找不到。
 * 脚本本身仍用**绝对路径**调用（scriptAbs = scriptsDir + "/" + scriptName），
 * 因此改 cwd 不影响脚本定位。
 */
package skill_long_running_task

import std.process.*
import std.env.getVariable
import jsonvalue.*
import std.io.InputStream
import std.core.Duration
import std.fs.{Path, FileInfo, exists, canonicalize}
import std.collection.ArrayList
import std.convert.*

public class LrtScriptRunner {
    /// 运行脚本，返回 (exitCode, stdout, stderr)
    public static func runScript(scriptName: String, args: ArrayList<String>): (Int64, String, String) {
        let interpreter = LrtScriptRunner.resolveInterpreter()
        let scriptsDir = LrtScriptRunner.resolveScriptsDir()
        let scriptAbs = scriptsDir + "/" + scriptName
        if (!exists(scriptAbs)) {
            return (-1, "", "脚本不存在: ${scriptAbs}")
        }
        let allArgs = ArrayList<String>()
        allArgs.add(scriptAbs)
        for (a in args) {
            allArgs.add(a)
        }

        // 子进程 cwd = 技能根（scripts/ 的上一级），使 `output/xxx` 相对路径正确落盘
        let workDir: ?Path = LrtScriptRunner.resolveSkillRoot(scriptsDir)

        let sub = launch(
            interpreter, allArgs.toArray(),
            workingDirectory: workDir,
            stdIn: ProcessRedirect.Pipe,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe
        )

        let stdoutFuture = spawn { => LrtScriptRunner.readStreamToEnd(sub.stdOutPipe) }
        let stderrFuture = spawn { => LrtScriptRunner.readStreamToEnd(sub.stdErrPipe) }
        let exitCode = sub.wait(timeout: Duration.second * 180)
        let stdout = stdoutFuture.get()
        let stderr = stderrFuture.get()
        return (Int64(exitCode), stdout, stderr)
    }

    /// 运行脚本并解析 stdout 最后一行为 JSON（脚本用 print(json.dumps(...)) 输出）
    public static func runScriptJson(scriptName: String, args: ArrayList<String>): JsonValue {
        let (code, out, err) = LrtScriptRunner.runScript(scriptName, args)
        if (code != 0) {
            eprintln("[lrt-runner] ${scriptName} exit=${code}, stderr=${err}")
            return JsonValue.Null
        }
        let jsonStr = LrtScriptRunner.extractLastJsonLine(out)
        if (jsonStr.isEmpty()) {
            eprintln("[lrt-runner] ${scriptName} 无 JSON 输出: ${out}")
            return JsonValue.Null
        }
        try {
            return JsonValue.parse(jsonStr)
        } catch (e: Exception) {
            eprintln("[lrt-runner] ${scriptName} JSON 解析失败: ${e.message}; raw=${out}")
            return JsonValue.Null
        }
    }

    // ── 内部 ──────────────────────────────────────────────────────

    private static func resolveInterpreter(): String {
        let envInterp = LrtScriptRunner.getEnv("LRT_PYTHON")
        if (!envInterp.isEmpty()) {
            return envInterp
        }
        // 顺序探测：python3 → python
        if (LrtScriptRunner.canRun("python3")) {
            return "python3"
        }
        return "python"
    }

    /**
     * 解析脚本目录，**尽量返回绝对路径**。
     *
     * 为何要绝对化：本方法在插件进程（`mode: process`，由宿主经 stdio 拉起）中执行，
     * 进程当前目录**不保证**是技能根。若返回相对的 `"scripts"`，则 `exists(scriptAbs)`
     * 会依赖进程 cwd 而时对时错。
     *
     * 解析顺序（逐级回退，并对每一步留日志）：
     *   1. env `LRT_SCRIPTS_DIR`（最高优先级：部署可显式指定）
     *   2. env `LRT_SKILL_ROOT` + `/scripts`
     *   3. 进程 cwd 下的 `scripts`（存在才用）
     *   4. 兜底返回 `"scripts"`（相对），交由调用方 exists 判断并给出明确错误
     */
    private static func resolveScriptsDir(): String {
        let envDir = LrtScriptRunner.getEnv("LRT_SCRIPTS_DIR")
        if (!envDir.isEmpty()) {
            return LrtScriptRunner.toAbsoluteIfPossible(envDir)
        }

        let skillRoot = LrtScriptRunner.getEnv("LRT_SKILL_ROOT")
        if (!skillRoot.isEmpty()) {
            let candidate = LrtScriptRunner.joinPath(skillRoot, "scripts")
            if (exists(candidate)) {
                return LrtScriptRunner.toAbsoluteIfPossible(candidate)
            }
            eprintln("[lrt-runner] LRT_SKILL_ROOT=${skillRoot} 下未找到 scripts/，继续回退")
        }

        if (exists("scripts")) {
            return LrtScriptRunner.toAbsoluteIfPossible("scripts")
        }

        eprintln("[lrt-runner] 未能确定脚本目录（LRT_SCRIPTS_DIR / LRT_SKILL_ROOT / cwd 均未命中），回退相对路径 'scripts'")
        return "scripts"
    }

    /// 用简单拼接而非 Path.join：避免对 Path 构造器做多余假设；分隔符统一为 "/"（std.fs 在 Windows 上也接受）
    private static func joinPath(base: String, child: String): String {
        if (base.endsWith("/") || base.endsWith("\\")) {
            return base + child
        }
        return base + "/" + child
    }

    /// 能 canonicalize 就返回绝对路径；失败则原样返回（调用方仍能靠 exists 判断）
    private static func toAbsoluteIfPossible(p: String): String {
        try {
            return canonicalize(Path(p)).toString()
        } catch (e: Exception) {
            eprintln("[lrt-runner] canonicalize('${p}') 失败，沿用原路径: ${e.message}")
            return p
        }
    }

    /**
     * 由 scriptsDir 反推技能根目录，作为子进程 cwd。
     *
     * 为何需要：COMPOSITION.yaml 各步的 `outdir`（如 `output/parsed`）以**技能根**为基准，
     * 而脚本以绝对路径调用，因此把 cwd 设成脚本的父目录（技能根）才能让相对产物落到
     * 约定的 `output/` 布局下，而非 `scripts/output/`。
     *
     * 解析顺序：
     *   1. 明确目录且能取到 parent → 用 parent（scriptAbs 已确认存在，路径可信）
     *   2. 回退 None（子进程继承 runtime 当前目录），并告警——不静默装作成功
     */
    /**
     * 对外暴露技能根目录解析结果（anti_regression 注册表等需要落盘到技能根的组件共用）。
     *
     * 复用内部的三级回退策略（LRT_SKILL_ROOT → scriptsDir 反推 → None），
     * 空串表示解析失败——调用方必须显式报错，不能拿它去拼路径。
     */
    public static func skillRoot(): String {
        let envRoot = LrtScriptRunner.getEnv("LRT_SKILL_ROOT")
        if (!envRoot.isEmpty()) {
            return LrtScriptRunner.toAbsoluteIfPossible(envRoot)
        }
        let dir = LrtScriptRunner.resolveScriptsDir()
        match (LrtScriptRunner.resolveSkillRoot(dir)) {
            case Some(p) => return p.toString()
            case None => return ""
        }
    }

    private static func resolveSkillRoot(scriptsDir: String): ?Path {
        try {
            if (exists(scriptsDir) && FileInfo(scriptsDir).isDirectory()) {
                let abs = canonicalize(Path(scriptsDir))
                let parent = abs.parent
                if (exists(parent) && FileInfo(parent).isDirectory()) {
                    return Some(parent)
                }
            }
        } catch (e: Exception) {
            eprintln("[lrt-runner] resolveSkillRoot failed: ${e.message}")
        }
        eprintln("[lrt-runner] 无法解析技能根目录（scriptsDir=${scriptsDir}），子进程将继承 runtime 当前目录；" +
                  "D 层脚本的相对路径产物可能落到非预期位置")
        return None<Path>
    }

    private static func canRun(cmd: String): Bool {
        let r = launch(cmd, ["--version"], stdIn: ProcessRedirect.Pipe, stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        let _ = spawn { => LrtScriptRunner.readStreamToEnd(r.stdOutPipe) }
        let _ = spawn { => LrtScriptRunner.readStreamToEnd(r.stdErrPipe) }
        let code = r.wait(timeout: Duration.second * 10)
        return code == 0
    }

    private static func getEnv(name: String): String {
        match (getVariable(name)) {
            case Some(s) => s
            case None => ""
        }
    }

    private static func readStreamToEnd(stream: InputStream): String {
        let buffer = Array<Byte>(4096, { _ => 0 })
        let result = StringBuilder()
        try {
            while (true) {
                let n = stream.read(buffer)
                if (n <= 0) {
                    break
                }
                result.append(String.fromUtf8(buffer[0..n]))
            }
        } catch (e: Exception) {
            eprintln("[lrt-runner] readStream error: ${e.message}")
        }
        return result.toString()
    }

    /// 从多行 stdout 中提取最后一个非空且像 JSON 的行（脚本 print(json.dumps(...)) 在末尾）
    private static func extractLastJsonLine(out: String): String {
        let lines = out.split("\n")
        var i = lines.size - 1
        while (i >= 0) {
            let line = lines[i].trimAscii()
            if (!line.isEmpty() && (line.startsWith("{") || line.startsWith("["))) {
                return line
            }
            i = i - 1
        }
        return ""
    }
}
