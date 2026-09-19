/*
 * LrtConfig（long-running-task / Ch4.1）
 * 读取 plugin.yaml 的 `config` 段，让 maxRounds 这类参数有**单一事实来源**。
 *
 * ── 为什么要有这个类 ────────────────────────────────────────────────────
 * tasks.md 4.1 第 4 条要求：maxRounds 必须读 plugin.yaml 的 `config.maxRounds`
 * （默认 30），与 `Config.maxReactNumber` 统一。此前插件侧写的是硬编码
 * `let maxRounds: Int64 = 30`——宿主引入了 cordis 的插件配置机制，
 * 但插件进程自己并不解析 plugin.yaml，于是配置与代码各存一份，
 * 改 plugin.yaml 完全不起作用（tasks.md 已点名此为偏差）。
 *
 * ── 为什么是"按行扫描"而不是引完整 YAML 解析器 ──────────────────────────
 * 1. 插件是独立的 L3 进程可执行文件，依赖越少越好；为一个 6 个键的扁平
 *    config 段拖进整套 YAML 库，收益不成比例。
 * 2. 只需要 `config` 段下的**标量键**，结构固定：`<key>: <value>`。
 *    行扫描对这种结构足够可靠。
 * 3. 扫描失败（文件缺失/键不存在/值非整数）一律回退默认值，
 *    绝不因为读不到配置就让长程任务跑不起来。
 *
 * ── 优先级 ──────────────────────────────────────────────────────────────
 * 环境变量 LRT_* > plugin.yaml config > 内置默认值。
 * 环境变量置顶是因为容器化部署时改配置文件的成本远高于注入环境变量。
 */
package skill_long_running_task

import std.fs.{File, OpenMode, exists}
import std.io.StringReader
import std.env.getVariable
// `Int64.tryParse` 是 std.convert 里对 Parsable 的扩展，不是 Int64 的原生静态方法。
// 不 import 这个继承接口，cjc 只报 "undeclared identifier 'tryParse'"，信息完全指不到
// 缺 import 这一层（宿主 src/agent_executor/agent_executor_manager.cj:15 同款写法）。
import std.convert.Parsable

public class LrtConfig {
    public static let DEFAULT_MAX_ROUNDS: Int64 = 30
    public static let DEFAULT_MAX_ROUND_DURATION_MS: Int64 = 1800000
    public static let DEFAULT_MAX_TASK_DURATION_MS: Int64 = 86400000
    public static let DEFAULT_MAX_CONCURRENT_TASKS: Int64 = 100
    /// 是否允许同一任务的重叠触发并发执行。默认 **false**（禁止重叠）。
    /// 理由：一次 runTask 是一整轮收敛循环，重叠触发会重复调用 LLM、重复写产物。
    public static let DEFAULT_CONCURRENTABLE: Bool = false

    // ── §11.3 监控告警阈值（单一事实来源）────────────────────────────
    // 优先级：环境变量 LRT_MONITOR_* > plugin.yaml config > 内置默认值。
    // 阈值含义见 LrtMonitorService。rate 类以 0.0~1.0 浮点表示（如 0.3 = 30%）。
    public static let DEFAULT_MONITOR_ENABLED: Bool = true
    public static let DEFAULT_MONITOR_WINDOW_SIZE: Int64 = 50
    public static let DEFAULT_MONITOR_FAILURE_RATE: Float64 = 0.3
    public static let DEFAULT_MONITOR_ROUND_TIMEOUT_RATE: Float64 = 0.2
    public static let DEFAULT_MONITOR_CHECKPOINT_LATENCY_MS: Int64 = 30000
    public static let DEFAULT_MONITOR_PROGRESS_LATENCY_MS: Int64 = 1000

    /// 收敛循环的最大轮次
    public static func maxRounds(): Int64 {
        match (LrtConfig.envInt("LRT_MAX_ROUNDS")) {
            case Some(v) => return v
            case None => return LrtConfig.yamlInt("maxRounds", LrtConfig.DEFAULT_MAX_ROUNDS)
        }
    }

    /// 单回合时长上限（毫秒）。超时 → 保存检查点并置 status=6，**不得置 0**
    public static func maxRoundDurationMs(): Int64 {
        match (LrtConfig.envInt("LRT_MAX_ROUND_DURATION_MS")) {
            case Some(v) => return v
            case None => return LrtConfig.yamlInt("maxRoundDurationMs", LrtConfig.DEFAULT_MAX_ROUND_DURATION_MS)
        }
    }

    /// 单任务总时长上限（毫秒）
    public static func maxTaskDurationMs(): Int64 {
        match (LrtConfig.envInt("LRT_MAX_TASK_DURATION_MS")) {
            case Some(v) => return v
            case None => return LrtConfig.yamlInt("maxTaskDurationMs", LrtConfig.DEFAULT_MAX_TASK_DURATION_MS)
        }
    }

    /// 并发任务上限（0 或缺失表示不限制）
    public static func maxConcurrentTasks(): Int64 {
        match (LrtConfig.envInt("LRT_MAX_CONCURRENT_TASKS")) {
            case Some(v) => return v
            case None => return LrtConfig.yamlInt("maxConcurrentTasks", LrtConfig.DEFAULT_MAX_CONCURRENT_TASKS)
        }
    }

    /// 是否允许**同一任务**的重叠触发并发执行（默认 false）。
    /// 此前该值从 crontab.concurrentable 读，用户无从配置、且默认 true 会重叠触发；
    /// 现收敛为 plugin.yaml 的 `config.concurrentable`（可被 `LRT_CONCURRENTABLE` 覆盖）。
    public static func concurrentable(): Bool {
        match (LrtConfig.envBool("LRT_CONCURRENTABLE")) {
            case Some(v) => return v
            case None => return LrtConfig.yamlBool("concurrentable", LrtConfig.DEFAULT_CONCURRENTABLE)
        }
    }

    // ── §11.3 监控告警阈值 ─────────────────────────────────────────

    /// 监控告警总开关
    public static func monitorEnabled(): Bool {
        match (LrtConfig.envBool("LRT_MONITOR_ENABLED")) {
            case Some(v) => return v
            case None => return LrtConfig.yamlBool("monitorEnabled", LrtConfig.DEFAULT_MONITOR_ENABLED)
        }
    }

    /// 滑动窗口样本数（参与比率计算的近 N 次任务完成）
    public static func monitorWindowSize(): Int64 {
        match (LrtConfig.envInt("LRT_MONITOR_WINDOW_SIZE")) {
            case Some(v) => return if (v > 0) { v } else { LrtConfig.DEFAULT_MONITOR_WINDOW_SIZE }
            case None => return LrtConfig.yamlInt("monitorWindowSize", LrtConfig.DEFAULT_MONITOR_WINDOW_SIZE)
        }
    }

    /// 任务失败率阈值（非 completed 占比，0.0~1.0）
    public static func monitorFailureRate(): Float64 {
        match (LrtConfig.envFloat("LRT_MONITOR_FAILURE_RATE")) {
            case Some(v) => return v
            case None => return LrtConfig.yamlFloat("monitorFailureRate", LrtConfig.DEFAULT_MONITOR_FAILURE_RATE)
        }
    }

    /// 回合超时率阈值（round_timeout 占比，0.0~1.0）
    public static func monitorRoundTimeoutRate(): Float64 {
        match (LrtConfig.envFloat("LRT_MONITOR_ROUND_TIMEOUT_RATE")) {
            case Some(v) => return v
            case None => return LrtConfig.yamlFloat("monitorRoundTimeoutRate", LrtConfig.DEFAULT_MONITOR_ROUND_TIMEOUT_RATE)
        }
    }

    /// 检查点保存平均延迟阈值（毫秒）
    public static func monitorCheckpointLatencyMs(): Int64 {
        match (LrtConfig.envInt("LRT_MONITOR_CHECKPOINT_LATENCY_MS")) {
            case Some(v) => return if (v > 0) { v } else { LrtConfig.DEFAULT_MONITOR_CHECKPOINT_LATENCY_MS }
            case None => return LrtConfig.yamlInt("monitorCheckpointLatencyMs", LrtConfig.DEFAULT_MONITOR_CHECKPOINT_LATENCY_MS)
        }
    }

    /// 进度通知平均延迟阈值（毫秒；以「单轮耗时」为代理指标）
    public static func monitorProgressLatencyMs(): Int64 {
        match (LrtConfig.envInt("LRT_MONITOR_PROGRESS_LATENCY_MS")) {
            case Some(v) => return if (v > 0) { v } else { LrtConfig.DEFAULT_MONITOR_PROGRESS_LATENCY_MS }
            case None => return LrtConfig.yamlInt("monitorProgressLatencyMs", LrtConfig.DEFAULT_MONITOR_PROGRESS_LATENCY_MS)
        }
    }

    // ── 内部 ────────────────────────────────────────────────────────

    private static func envInt(name: String): ?Int64 {
        match (getVariable(name)) {
            case Some(s) =>
                if (s.isEmpty()) {
                    return None<Int64>
                }
                return Int64.tryParse(s)
            case None => return None<Int64>
        }
    }

    private static func envBool(name: String): ?Bool {
        match (getVariable(name)) {
            case Some(s) =>
                if (s.isEmpty()) {
                    return None<Bool>
                }
                let lower = s.trimAscii().toAsciiLower()
                return Some<Bool>(lower == "true" || lower == "1" || lower == "yes")
            case None => return None<Bool>
        }
    }

    private static func envFloat(name: String): ?Float64 {
        match (getVariable(name)) {
            case Some(s) =>
                if (s.isEmpty()) {
                    return None<Float64>
                }
                return Float64.tryParse(s)
            case None => return None<Float64>
        }
    }

    /**
     * 在 plugin.yaml 里找 `<key>: <int>` 形式的行并返回整数。
     * 找不到/格式不对一律返回 default——配置读取失败不应该阻断任务。
     */
    private static func yamlInt(key: String, default: Int64): Int64 {
        let root = LrtScriptRunner.skillRoot()
        if (root.isEmpty()) {
            return default
        }
        let path = "${root}/plugin.yaml"
        if (!exists(path)) {
            return default
        }
        let text = LrtConfig.readText(path)
        if (text.isEmpty()) {
            return default
        }
        let lines = text.split("\n")
        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.startsWith(key + ":")) {
                if (trimmed.size <= key.size + 1) {
                    return default
                }
                let raw = trimmed[key.size + 1..trimmed.size].trimAscii()
                match (Int64.tryParse(raw)) {
                    case Some(v) => return v
                    case None => return default
                }
            }
        }
        return default
    }

    /// 同 yamlInt，但解析为 Bool（true/1/yes 视为真）
    private static func yamlBool(key: String, default: Bool): Bool {
        let root = LrtScriptRunner.skillRoot()
        if (root.isEmpty()) {
            return default
        }
        let path = "${root}/plugin.yaml"
        if (!exists(path)) {
            return default
        }
        let text = LrtConfig.readText(path)
        if (text.isEmpty()) {
            return default
        }
        for (line in text.split("\n")) {
            let trimmed = line.trimAscii()
            if (trimmed.startsWith(key + ":")) {
                if (trimmed.size <= key.size + 1) {
                    return default
                }
                let raw = trimmed[key.size + 1..trimmed.size].trimAscii().toAsciiLower()
                return raw == "true" || raw == "1" || raw == "yes"
            }
        }
        return default
    }

    /// 同 yamlInt，但解析为 Float64（用于 0.0~1.0 的比率阈值）
    private static func yamlFloat(key: String, default: Float64): Float64 {
        let root = LrtScriptRunner.skillRoot()
        if (root.isEmpty()) {
            return default
        }
        let path = "${root}/plugin.yaml"
        if (!exists(path)) {
            return default
        }
        let text = LrtConfig.readText(path)
        if (text.isEmpty()) {
            return default
        }
        for (line in text.split("\n")) {
            let trimmed = line.trimAscii()
            if (trimmed.startsWith(key + ":")) {
                if (trimmed.size <= key.size + 1) {
                    return default
                }
                let raw = trimmed[key.size + 1..trimmed.size].trimAscii()
                match (Float64.tryParse(raw)) {
                    case Some(v) => return v
                    case None => return default
                }
            }
        }
        return default
    }

    private static func readText(path: String): String {
        try {
            let file = File(path, OpenMode.Read)
            let reader = StringReader(file)
            let content = reader.readToEnd()
            file.close()
            return content
        } catch (e: Exception) {
            eprintln("[lrt-config] 读取失败 ${path}: ${e.message}")
            return ""
        }
    }
}
