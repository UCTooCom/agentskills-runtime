/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 *
 * LrtCompositionRunner —— 长程任务编排执行器（design 2.4.4 方案 A）
 *
 * 背景：技能实际在用的 COMPOSITION.yaml 是「文件态」格式（script / plugin / output），
 * 与 composition_yaml_parser.cj / composition_executor.cj / composition_definition.cj
 * 所描述的「DB 存储态 schema」不同源（后者仅供 SkillCompositionsService 的 CRUD 持久化使用）。
 *
 * 本类只解析文件态 COMPOSITION.yaml，并复用 CompositionExecutor 骨架中的
 * 拓扑排序 / 环检测 / 条件跳过 / 步骤级缓存 / 产出聚合五项能力，
 * 但**替换**其 executeStep 的「按 skillName 查找技能」语义为三路分发：
 *   - script：经 magic.utils.newProcess（必须传 workingDirectory=cwd）执行脚本
 *   - plugin：调用插件路由
 *   - output：聚合输出（无副作用）
 *
 * 变量插值支持三类：${input.xxx} / ${step-name.output} / ${env.YYYYMMDD}；
 * 引用未就绪产出时**报错并指出缺失依赖**，禁止静默替换为空串（spec 5.14）。
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import std.fs.{File, Path, FileInfo, exists}
import std.time.DateTime
import std.env.getVariable
import std.core.Duration
import std.io.InputStream
import std.process.{SubProcess, ProcessRedirect}
import stdx.encoding.json.{JsonValue, JsonObject, JsonKind}
import yaml4cj.yaml.decode
import magic.log.LogUtils
import magic.utils.newProcess

/// 步骤类型（方案 A 文件态）
///
/// 补充说明：仓颉枚举不自动支持 `==`/`!=`。此处虽以 `match` 消费为主，
/// 但仍显式声明 `Equatable` 以便后续在条件表达式中直接比较（与 LrtStepStatus 保持一致）。
public enum LrtStepType <: Equatable<LrtStepType> {
    | Script
    | Plugin
    | Output

    public operator func ==(right: LrtStepType): Bool {
        match ((this, right)) {
            case (LrtStepType.Script, LrtStepType.Script) => true
            case (LrtStepType.Plugin, LrtStepType.Plugin) => true
            case (LrtStepType.Output, LrtStepType.Output) => true
            case _ => false
        }
    }

    public operator func !=(right: LrtStepType): Bool {
        return !(this == right)
    }
}

public func lrtStepTypeToString(t: LrtStepType): String {
    match (t) {
        case LrtStepType.Script => "script"
        case LrtStepType.Plugin => "plugin"
        case LrtStepType.Output => "output"
    }
}

public func parseLrtStepType(s: String): Option<LrtStepType> {
    match (s.trimAscii().toAsciiLower()) {
        case "script" => Some(LrtStepType.Script)
        case "plugin" => Some(LrtStepType.Plugin)
        case "output" => Some(LrtStepType.Output)
        case _ => None
    }
}

/// 单个步骤定义（文件态）
public class LrtStep {
    public var name: String = ""
    public var stepType: LrtStepType = LrtStepType.Script
    public var script: String = ""          // step_type=script 时的脚本相对路径
    public var pluginRoute: String = ""     // step_type=plugin 时的插件路由
    public var dependsOn: ArrayList<String> = ArrayList<String>()
    public var usesTables: ArrayList<String> = ArrayList<String>()
    public var input: HashMap<String, String> = HashMap<String, String>()   // 原始（未插值）模板
    public var condition: String = ""       // 可选，控制是否执行
    /// 验收条件（tasks.md #375）。此前编排靠"退出码 0"顶替验收，把"跑了但没跑到"判成成功。
    public var acceptanceCriteria: ArrayList<String> = ArrayList<String>()
    /// 降级策略链（tasks.md #387）：主路径重试耗尽后按序尝试，全部失败才判 Failed。
    public var degradationChain: ArrayList<String> = ArrayList<String>()

    public init() {}
}

/// 编排定义（文件态）
public class LrtComposition {
    public var name: String = ""
    public var description: String = ""
    public var version: String = ""
    public var steps: ArrayList<LrtStep> = ArrayList<LrtStep>()

    public init() {}
}

/// 步骤执行状态
///
/// 注意：仓颉枚举默认不实现 `==`，必须显式 `Equatable` 才能在 if/while 中直接比较
/// （否则报 "invalid binary operator '==' on type 'Enum-LrtStepStatus'"）。
public enum LrtStepStatus <: Equatable<LrtStepStatus> {
    | Pending
    | Running
    | Completed
    | Failed
    | Skipped

    public operator func ==(right: LrtStepStatus): Bool {
        match ((this, right)) {
            case (LrtStepStatus.Pending, LrtStepStatus.Pending) => true
            case (LrtStepStatus.Running, LrtStepStatus.Running) => true
            case (LrtStepStatus.Completed, LrtStepStatus.Completed) => true
            case (LrtStepStatus.Failed, LrtStepStatus.Failed) => true
            case (LrtStepStatus.Skipped, LrtStepStatus.Skipped) => true
            case _ => false
        }
    }

    public operator func !=(right: LrtStepStatus): Bool {
        return !(this == right)
    }
}

public func lrtStepStatusToString(s: LrtStepStatus): String {
    match (s) {
        case LrtStepStatus.Pending => "pending"
        case LrtStepStatus.Running => "running"
        case LrtStepStatus.Completed => "completed"
        case LrtStepStatus.Failed => "failed"
        case LrtStepStatus.Skipped => "skipped"
    }
}

/// 单步执行结果
public class LrtStepResult {
    public var stepName: String = ""
    public var status: LrtStepStatus = LrtStepStatus.Pending
    public var output: String = ""          // 步骤产出（脚本 stdout / 插件返回文本）
    public var errorMessage: String = ""
    public var durationMs: Int64 = 0
    public var fromCache: Bool = false
    public var attempts: Int64 = 0          // 实际尝试次数（含重试）

    public init() {}
}

/// 编排执行结果
public class LrtCompositionResult {
    public var compositionName: String = ""
    public var status: LrtStepStatus = LrtStepStatus.Pending
    public var stepResults: HashMap<String, LrtStepResult> = HashMap<String, LrtStepResult>()
    public var finalOutput: String = ""
    public var totalDurationMs: Int64 = 0
    public var cacheHits: Int64 = 0
    public var errorMessage: String = ""

    public init() {}
}

/// 三路分发用的插件路由调用器（由调用方注入，避免本类直接依赖 HTTP 层）
public type LrtPluginCaller = (String, HashMap<String, String>) -> String

/// 降级后端（tasks.md #244/#387 / spec §5.4：cli_execute → builtin_tool → llm → template）
///
/// 语义：**主路径（script/plugin）重试耗尽后**才依次尝试这些后端。每一步降级都必须
/// 在结果里留下"降级了、为什么降级"的痕迹——降级是为了"不停"，不是为了"假装成功"。
public enum LrtDegradationTarget <: Equatable<LrtDegradationTarget> {
    | CliExecute
    | BuiltinTool
    | Llm
    | Template

    public operator func ==(right: LrtDegradationTarget): Bool {
        match ((this, right)) {
            case (LrtDegradationTarget.CliExecute, LrtDegradationTarget.CliExecute) => true
            case (LrtDegradationTarget.BuiltinTool, LrtDegradationTarget.BuiltinTool) => true
            case (LrtDegradationTarget.Llm, LrtDegradationTarget.Llm) => true
            case (LrtDegradationTarget.Template, LrtDegradationTarget.Template) => true
            case _ => false
        }
    }

    public operator func !=(right: LrtDegradationTarget): Bool {
        return !(this == right)
    }
}

public func parseLrtDegradationTarget(s: String): Option<LrtDegradationTarget> {
    match (s.trimAscii().toAsciiLower()) {
        case "cli_execute" => Some(LrtDegradationTarget.CliExecute)
        case "builtin_tool" => Some(LrtDegradationTarget.BuiltinTool)
        case "llm" => Some(LrtDegradationTarget.Llm)
        case "template" => Some(LrtDegradationTarget.Template)
        case _ => None
    }
}

/// builtin_tool 降级用的内置工具调用器：(工具名, 入参) -> 结果文本
public type LrtToolCaller = (String, HashMap<String, String>) -> String

/// llm 降级用的兜底调用器：(需求描述, 验收条件列表) -> 结果文本
public type LrtLlmCaller = (String, ArrayList<String>) -> String

public class LrtCompositionRunner {
    /// 技能目录的绝对路径（其下应有 COMPOSITION.yaml 与 scripts/、output/）
    private let _skillDir: String
    /// 编排级输入（对应 ${input.xxx}）
    private let _input: HashMap<String, String>
    /// 步骤级缓存：cacheKey -> 产出
    private var _cache: HashMap<String, String>
    /// 插件路由调用器（step_type=plugin 时使用；为 None 时该步报错）
    private let _pluginCaller: ?LrtPluginCaller
    /// 单步重试次数（遵循「遇挫不停」：失败先重试 1 次）
    private let _retryCount: Int64
    /// builtin_tool 降级调用器（为 None 时该后端不可用，跳过并记录原因）
    private let _toolCaller: ?LrtToolCaller
    /// llm 降级调用器（为 None 时该后端不可用，跳过并记录原因）
    private let _llmCaller: ?LrtLlmCaller

    public init(
        skillDir: String,
        input!: HashMap<String, String> = HashMap<String, String>(),
        pluginCaller!: ?LrtPluginCaller = None,
        toolCaller!: ?LrtToolCaller = None,
        llmCaller!: ?LrtLlmCaller = None,
        retryCount!: Int64 = 1
    ) {
        _skillDir = skillDir
        _input = input
        _cache = HashMap<String, String>()
        _pluginCaller = pluginCaller
        _toolCaller = toolCaller
        _llmCaller = llmCaller
        _retryCount = retryCount
    }

    // ── 解析：文件态 COMPOSITION.yaml ───────────────────────────────

    /// 从技能目录加载并解析 COMPOSITION.yaml
    public func loadComposition(): Option<LrtComposition> {
        let path = Path(_skillDir).join("COMPOSITION.yaml").toString()
        return parseFromFile(path)
    }

    public func parseFromFile(filePath: String): Option<LrtComposition> {
        try {
            if (!exists(filePath)) {
                LogUtils.error("[LrtCompositionRunner] COMPOSITION.yaml not found: ${filePath}")
                return None
            }
            let bytes = File.readFrom(filePath)
            let content = String.fromUtf8(bytes)
            return parseFromString(content)
        } catch (e: Exception) {
            LogUtils.error("[LrtCompositionRunner] Failed to read ${filePath}: ${e.message}")
            return None
        }
    }

    public func parseFromString(content: String): Option<LrtComposition> {
        try {
            let parsed = decode(content.toArray())
            if (!(parsed is JsonObject)) {
                LogUtils.error("[LrtCompositionRunner] COMPOSITION.yaml root is not a mapping")
                return None
            }
            let root = (parsed as JsonObject).getOrThrow()
            let comp = LrtComposition()
            comp.name = LrtCompositionRunner.optString(root, "name")
            comp.description = LrtCompositionRunner.optString(root, "description")
            comp.version = LrtCompositionRunner.optString(root, "version")

            let stepsVal = root.get("steps")
            match (stepsVal) {
                case Some(sv) =>
                    // JsonKind 未实现 Equatable，须用 match 判别，不能用 ==
                    match (sv.kind()) {
                        case JsonKind.JsArray =>
                            for (item in sv.asArray().getItems()) {
                                match (item.kind()) {
                                    case JsonKind.JsObject =>
                                        match (LrtCompositionRunner.parseStep(item.asObject())) {
                                            case Some(step) => comp.steps.add(step)
                                            case None => ()
                                        }
                                    case _ => ()
                                }
                            }
                        case _ => ()
                    }
                case None => ()
            }
            return Some(comp)
        } catch (e: Exception) {
            LogUtils.error("[LrtCompositionRunner] Failed to parse COMPOSITION.yaml: ${e.message}")
            return None
        }
    }

    private static func parseStep(obj: JsonObject): Option<LrtStep> {
        let step = LrtStep()
        step.name = optString(obj, "name")
        if (step.name.isEmpty()) {
            LogUtils.error("[LrtCompositionRunner] step without name, skipped")
            return None
        }
        let typeStr = optString(obj, "step_type")
        match (parseLrtStepType(typeStr)) {
            case Some(t) => step.stepType = t
            case None =>
                LogUtils.error("[LrtCompositionRunner] step '${step.name}' has invalid step_type: '${typeStr}'")
                return None
        }
        step.script = optString(obj, "script")
        step.pluginRoute = optString(obj, "plugin_route")
        step.condition = optString(obj, "condition")

        step.dependsOn = stringArray(obj, "depends_on")
        step.usesTables = stringArray(obj, "uses_tables")
        step.acceptanceCriteria = stringArray(obj, "acceptance_criteria")
        step.degradationChain = stringArray(obj, "degradation_chain")

        // input 是 map<string, string>；非字符串值统一 stringify
        match (obj.get("input")) {
            case Some(inVal) =>
                match (inVal.kind()) {
                    case JsonKind.JsObject =>
                        for ((k, v) in inVal.asObject().getFields()) {
                            step.input.add(k, LrtCompositionRunner.scalarToString(v))
                        }
                    case _ => ()
                }
            case None => ()
        }

        // 合法性：script 必须有 script；plugin 必须有 plugin_route
        match (step.stepType) {
            case LrtStepType.Script =>
                if (step.script.isEmpty()) {
                    LogUtils.error("[LrtCompositionRunner] step '${step.name}' is script but has no 'script'")
                    return None
                }
            case LrtStepType.Plugin =>
                if (step.pluginRoute.isEmpty()) {
                    LogUtils.error("[LrtCompositionRunner] step '${step.name}' is plugin but has no 'plugin_route'")
                    return None
                }
            case LrtStepType.Output => ()
        }

        return Some(step)
    }

    // ── 拓扑排序 + 环检测（借鉴 CompositionExecutor.topologicalSort） ──

    public func topologicalSort(steps: ArrayList<LrtStep>): ArrayList<LrtStep> {
        let result = ArrayList<LrtStep>()
        let stepMap = HashMap<String, LrtStep>()
        let inDegree = HashMap<String, Int64>()
        let adjacency = HashMap<String, ArrayList<String>>()

        for (step in steps) {
            stepMap.add(step.name, step)
            inDegree.add(step.name, 0)
            adjacency.add(step.name, ArrayList<String>())
        }

        for (step in steps) {
            for (dep in step.dependsOn) {
                if (!stepMap.contains(dep)) {
                    LogUtils.warn("[LrtCompositionRunner] step '${step.name}' depends on unknown step '${dep}'")
                    continue
                }
                if (let Some(deps) <- adjacency.get(dep)) {
                    deps.add(step.name)
                }
                if (let Some(deg) <- inDegree.get(step.name)) {
                    inDegree.add(step.name, deg + 1)
                }
            }
        }

        let queue = ArrayList<String>()
        for (step in steps) {
            if (let Some(deg) <- inDegree.get(step.name)) {
                if (deg == 0) {
                    queue.add(step.name)
                }
            }
        }

        var idx = 0
        while (idx < queue.size) {
            let current = queue[idx]
            idx = idx + 1
            if (let Some(step) <- stepMap.get(current)) {
                result.add(step)
            }
            if (let Some(neighbors) <- adjacency.get(current)) {
                for (neighbor in neighbors) {
                    if (let Some(deg) <- inDegree.get(neighbor)) {
                        let newDeg = deg - 1
                        inDegree.add(neighbor, newDeg)
                        if (newDeg == 0) {
                            queue.add(neighbor)
                        }
                    }
                }
            }
        }

        // 排序结果少于步数 => 存在环
        if (result.size != steps.size) {
            LogUtils.error("[LrtCompositionRunner] topological sort failed: possible cycle among steps")
            return ArrayList<LrtStep>()
        }
        return result
    }

    // ── 变量插值引擎 ──────────────────────────────────────────────

    /// 解析单个模板串。支持：
    ///   \${input.xxx}          → 编排级输入
    ///   \${step-name.output}   → 前序步骤产出
    ///   \${env.YYYYMMDD}       → 环境/日期（YYYYMMDD/YYYY-MM-DD/task_id/goal 等）
    /// 未就绪引用 => 返回错误说明（非空串），由调用方判定失败，**不静默替换为空串**。
    public func interpolate(template: String, stepOutputs: HashMap<String, String>): (String, String) {
        // 注意：仓颉字符串中 '\$' 是转义写法的字面量'$'，'${' 组合才是插值起始，
        // 因此判断“是否含插值起点”必须写成 "\${"，否则源码本身会被当成未闭合插值。
        if (!template.contains("\${")) {
            return (template, "")
        }
        let parts = ArrayList<String>()
        var i = 0
        let n = template.size
        while (i < n) {
            // 注意：String 下标 s[i] 返回 UTF-8 字节（Byte），不是 Rune，故用 b'$' / b'{' / b'}' 比较
            if (i + 1 < n && template[i] == b'$' && template[i + 1] == b'{') {
                let close = findCloseBrace(template, i + 2)
                if (close < 0) {
                    return ("", "变量插值缺少 '}'：'${template}'")
                }
                let expr = template[i + 2..close].trimAscii()
                let (val, err) = resolveExpr(expr, stepOutputs)
                if (!err.isEmpty()) {
                    return ("", err)
                }
                parts.add(val)
                i = close + 1
            } else {
                // 逐字节累积（多字节字符会分多次拼接，但 UTF-8 字节序拼回后等价于原字符）
                parts.add(template[i..i + 1])
                i = i + 1
            }
        }
        return (LrtCompositionRunner.join(parts), "")
    }

    /// 解析单个 \${} 表达式
    private func resolveExpr(expr: String, stepOutputs: HashMap<String, String>): (String, String) {
        // `${file:<相对技能目录的路径>}` —— **专供 condition 使用**：文件存在且非空返回 "true"，
        // 否则返回空串（evaluateCondition 按"非空即真"判定）。
        // 为什么不做成返回文件内容：插值的消费方（condition）只认"非空/空"，
        // 返回内容会让"文件存在但内容恰好为空"与"文件不存在"无法区分，且可能把大文件塞进入参。
        if (expr.startsWith("file:")) {
            let rel = expr["file:".size..expr.size].trimAscii()
            if (rel.isEmpty()) {
                return ("", "变量表达式 '${expr}' 缺少文件路径")
            }
            if (fileNonEmpty(LrtCompositionRunner.joinPath(_skillDir, rel))) {
                return ("true", "")
            }
            return ("", "")
        }
        let segs = expr.split(".")
        if (segs.size < 2) {
            return ("", "无法识别的变量表达式：'${expr}'（应为 \\\${input.xxx} / \\\${step.output} / \\\${env.YYYYMMDD}）")
        }
        let head = segs[0]
        if (head == "input") {
            let key = segs[1]
            match (_input.get(key)) {
                case Some(v) => return (v, "")
                case None => return ("", "编排输入缺失：input.${key}（未提供该输入，禁止静默置空）")
            }
        }
        if (head == "env") {
            let key = segs[1]
            return (resolveEnv(key), "")
        }
        // 其余视为 `${stepName.output}`（可带子路径，如 ${plan-tasks.output}/plan.json）
        let stepName = head
        match (stepOutputs.get(stepName)) {
            case Some(v) => return (v, "")
            case None => return ("", "依赖产出未就绪：步骤 '${stepName}' 尚未执行或执行失败，无法引用其 output")
        }
    }

    private func resolveEnv(key: String): String {
        let now = DateTime.now()
        match (key) {
            case "YYYYMMDD" => now.format("yyyyMMdd")
            case "YYYY-MM-DD" => now.format("yyyy-MM-dd")
            case "HHmmss" => now.format("HHmmss")
            case "ISO" => now.toString()
            case "task_id" => match (_input.get("task_id")) { case Some(v) => v; case None => "" }
            case "goal" => match (_input.get("goal")) { case Some(v) => v; case None => "" }
            case _ => match (_input.get(key)) { case Some(v) => v; case None => "" }
        }
    }

    private func findCloseBrace(s: String, from: Int64): Int64 {
        var j = from
        let n = s.size
        while (j < n) {
            if (s[j] == b'}') {
                return j
            }
            j = j + 1
        }
        return -1
    }

    // ── 条件求值 ─────────────────────────────────────────────────

    /// 条件求值：支持 "true"/"false" 字面量、`${step.output}` 是否非空
    public func evaluateCondition(condition: String, stepOutputs: HashMap<String, String>): Bool {
        let c = condition.trimAscii()
        if (c.isEmpty() || c == "true") {
            return true
        }
        if (c == "false") {
            return false
        }
        // `${step-x.output}` => 该步产出非空即真
        let (val, err) = interpolate(c, stepOutputs)
        if (!err.isEmpty()) {
            LogUtils.warn("[LrtCompositionRunner] cannot evaluate condition '${condition}': ${err}")
            return false
        }
        return !val.trimAscii().isEmpty()
    }

    // ── 三路分发执行 ──────────────────────────────────────────────

    public func buildCacheKey(step: LrtStep, stepOutputs: HashMap<String, String>): String {
        var key = lrtStepTypeToString(step.stepType) + ":" + step.name
        if (step.stepType == LrtStepType.Script) {
            key = key + ":" + step.script
        }
        // 编排输入参与键（保证不同 input 不误命中）
        for (k in LrtCompositionRunner.sortedKeys(_input)) {
            match (_input.get(k)) {
                case Some(v) => key = key + ":" + k + "=" + v
                case None => ()
            }
        }
        // 依赖产出参与键
        for (dep in step.dependsOn) {
            match (stepOutputs.get(dep)) {
                case Some(v) => key = key + ":" + dep + "=" + v
                case None => ()
            }
        }
        return key
    }

    /// 执行单个步骤（三路分发）
    public func executeStep(
        step: LrtStep,
        stepOutputs: HashMap<String, String>,
        traceId: String
    ): LrtStepResult {
        let result = LrtStepResult()
        result.stepName = step.name
        let start = LrtCompositionRunner.nowMs()

        // 条件跳过
        if (!step.condition.isEmpty() && !evaluateCondition(step.condition, stepOutputs)) {
            result.status = LrtStepStatus.Skipped
            result.durationMs = LrtCompositionRunner.nowMs() - start
            LogUtils.info("[LrtCompositionRunner] step '${step.name}' skipped (condition not met) trace=${traceId}")
            return result
        }

        // 步骤级缓存
        let cacheKey = buildCacheKey(step, stepOutputs)
        if (let Some(cached) <- _cache.get(cacheKey)) {
            result.status = LrtStepStatus.Completed
            result.output = cached
            result.fromCache = true
            result.durationMs = LrtCompositionRunner.nowMs() - start
            return result
        }

        // 插值 step.input
        let resolved = HashMap<String, String>()
        for ((k, tmpl) in step.input) {
            let (val, err) = interpolate(tmpl, stepOutputs)
            if (!err.isEmpty()) {
                result.status = LrtStepStatus.Failed
                result.errorMessage = "步骤 '${step.name}' 的输入 '${k}' 插值失败：${err}"
                result.durationMs = LrtCompositionRunner.nowMs() - start
                LogUtils.error("[LrtCompositionRunner] ${result.errorMessage} trace=${traceId}")
                return result
            }
            resolved.add(k, val)
        }

        // 三路分发 + 重试（遇挫不停：先重试 _retryCount 次）
        var attempt: Int64 = 0
        var lastErr = ""
        while (attempt <= _retryCount) {
            attempt = attempt + 1
            let (ok, out, err) = dispatch(step, resolved, traceId)
            if (ok) {
                result.status = LrtStepStatus.Completed
                result.output = out
                result.attempts = attempt
                _cache.add(cacheKey, out)
                result.durationMs = LrtCompositionRunner.nowMs() - start
                return result
            }
            lastErr = err
            if (attempt <= _retryCount) {
                LogUtils.warn("[LrtCompositionRunner] step '${step.name}' attempt ${attempt} failed: ${err}, retrying... trace=${traceId}")
            }
        }

        // ── 降级策略链（tasks.md #244/#387）──────────────────────────────
        // 主路径重试耗尽 ≠ 任务失败：按 step.degradation_chain 依次换方案。
        // 任一后端成功 → 步骤判 Completed，但产出必须带 degraded 标记，
        // 让下游能看出"这一步不是按原计划跑通的"。
        var report = "主路径经 ${attempt} 次尝试失败：${lastErr}"
        if (!step.degradationChain.isEmpty()) {
            for (raw in step.degradationChain) {
                match (parseLrtDegradationTarget(raw)) {
                    case Some(target) =>
                        let (dOk, dOut, dErr) = dispatchDegraded(step, resolved, target, traceId)
                        if (dOk) {
                            result.status = LrtStepStatus.Completed
                            result.output = dOut
                            result.attempts = attempt
                            result.durationMs = LrtCompositionRunner.nowMs() - start
                            _cache.add(cacheKey, dOut)
                            LogUtils.warn("[LrtCompositionRunner] step '${step.name}' 主路径失败，"
                                + "经降级后端 '${raw}' 完成（产出已标记 degraded）trace=${traceId}")
                            return result
                        }
                        report = report + "；降级 '${raw}' 失败：${dErr}"
                    case None =>
                        LogUtils.warn("[LrtCompositionRunner] step '${step.name}' 声明了未知降级后端 '${raw}'"
                            + "（支持 cli_execute/builtin_tool/llm/template），已跳过")
                }
            }
        }

        result.status = LrtStepStatus.Failed
        result.attempts = attempt
        result.errorMessage = "步骤 '${step.name}' 主路径与降级链均失败 —— ${report}"
        result.durationMs = LrtCompositionRunner.nowMs() - start
        LogUtils.error("[LrtCompositionRunner] ${result.errorMessage} trace=${traceId}")
        return result
    }

    /// 降级后端分发。返回 (是否成功, 产出, 错误信息)
    ///
    /// 纪律：后端不可用（调用器未注入 / 脚本缺失）**必须返回失败而不是偷偷成功**，
    /// 否则降级就变成了把失败粉饰成成功的通道。
    private func dispatchDegraded(
        step: LrtStep,
        resolvedInput: HashMap<String, String>,
        target: LrtDegradationTarget,
        traceId: String
    ): (Bool, String, String) {
        match (target) {
            case LrtDegradationTarget.CliExecute =>
                // 换执行通道：不经 MagiContext 的脚本装配，直接用解释器把 input 作为 argv 传入
                if (step.stepType != LrtStepType.Script || step.script.isEmpty()) {
                    return (false, "", "cli_execute 降级仅适用于 script 步骤，本步类型为 '${lrtStepTypeToString(step.stepType)}'")
                }
                return runCliFallback(step, resolvedInput, traceId)
            case LrtDegradationTarget.BuiltinTool =>
                match (_toolCaller) {
                    case Some(caller) =>
                        let out = caller(step.name, resolvedInput)
                        if (out.trimAscii().isEmpty()) {
                            return (false, "", "内置工具 '${step.name}' 返回空结果")
                        }
                        return (true, LrtCompositionRunner.markDegraded(step.name, "builtin_tool", out), "")
                    case None => return (false, "", "builtin_tool 降级不可用：调用方未注入 toolCaller")
                }
            case LrtDegradationTarget.Llm =>
                match (_llmCaller) {
                    case Some(caller) =>
                        let need = "请补齐步骤 '${step.name}' 的产出"
                        let out = caller(need, step.acceptanceCriteria)
                        if (out.trimAscii().isEmpty()) {
                            return (false, "", "LLM 兜底返回空结果")
                        }
                        return (true, LrtCompositionRunner.markDegraded(step.name, "llm", out), "")
                    case None => return (false, "", "llm 降级不可用：调用方未注入 llmCaller")
                }
            case LrtDegradationTarget.Template =>
                // 最后兜底：只做"把失败如实结构化"，绝不编造业务产出
                if (step.acceptanceCriteria.isEmpty()) {
                    return (false, "", "template 降级需要 acceptance_criteria 作为依据，本步未声明")
                }
                let body = LrtCompositionRunner.join(step.acceptanceCriteria)
                return (true,
                    LrtCompositionRunner.markDegraded(step.name, "template",
                        "本步未能真正执行，以下为待办验收条件（需后续补）：" + body), "")
        }
    }

    /// cli_execute 降级：把 input 摊平成 `--k=v` 命令行参数再跑一次脚本
    private func runCliFallback(
        step: LrtStep,
        resolvedInput: HashMap<String, String>,
        traceId: String
    ): (Bool, String, String) {
        let scriptAbs = LrtCompositionRunner.joinPath(_skillDir, step.script)
        if (!exists(scriptAbs)) {
            return (false, "", "cli_execute 降级失败：脚本不存在 ${scriptAbs}")
        }
        LogUtils.warn("[LrtCompositionRunner] step '${step.name}' 转入 cli_execute 降级 trace=${traceId}")
        let argv = ArrayList<String>()
        argv.add(scriptAbs)
        for (k in LrtCompositionRunner.sortedKeys(resolvedInput)) {
            match (resolvedInput.get(k)) {
                case Some(v) => argv.add("--" + k + "=" + v)
                case None => ()
            }
        }
        // 参数形式刻意与 runScriptStep 区分：那里是 `--k v`，这里是 `--k=v`。
        // 目的不是玩花样，而是让降级路径与主路径在进程参数层面就不一样，
        // 万一主路径卡在某个 argv 装配环节，降级仍有机会跑通。
        // workingDirectory 必须为技能目录：脚本里的 output/xxx 相对路径依赖它。
        try {
            let sub = newProcess(
                LrtCompositionRunner.resolveInterpreter(),
                argv.toArray(),
                workingDirectory: Some(Path(_skillDir)),
                redirectErr: true
            )
            let (code, out, errOut) = LrtCompositionRunner.capture(sub)
            if (code != 0) {
                return (false, "", "cli_execute 退出码 ${code}：${errOut}")
            }
            if (out.trimAscii().isEmpty()) {
                return (false, "", "cli_execute 无输出")
            }
            return (true, LrtCompositionRunner.markDegraded(step.name, "cli_execute", out), "")
        } catch (e: Exception) {
            return (false, "", "cli_execute 执行异常：${e.message}")
        }
    }

    /// 给产出打上降级标记，让下游（与人）一眼看出这不是按原计划跑通的结果
    private static func markDegraded(stepName: String, backend: String, output: String): String {
        return "[degraded by ${backend}] step=${stepName}\n" + output
    }

    /// 三路分发实现。返回 (是否成功, 产出, 错误信息)
    private func dispatch(
        step: LrtStep,
        resolvedInput: HashMap<String, String>,
        traceId: String
    ): (Bool, String, String) {
        match (step.stepType) {
            case LrtStepType.Script => runScriptStep(step, resolvedInput, traceId)
            case LrtStepType.Plugin => runPluginStep(step, resolvedInput, traceId)
            case LrtStepType.Output => (true, aggregateOutput(step, resolvedInput), "")
        }
    }

    /// script 分发：经 magic.utils.newProcess 执行脚本，**必须传 workingDirectory=cwd**
    private func runScriptStep(
        step: LrtStep,
        resolvedInput: HashMap<String, String>,
        traceId: String
    ): (Bool, String, String) {
        let cwd = _skillDir
        if (!exists(cwd) || !FileInfo(cwd).isDirectory()) {
            return (false, "", "技能目录不存在或不是目录：${cwd}")
        }
        let scriptPath = Path(cwd).join(step.script).toString()
        if (!exists(scriptPath)) {
            return (false, "", "脚本不存在：${scriptPath}")
        }
        // 参数：--key value 形式传递 input
        let args = ArrayList<String>()
        args.add(scriptPath)
        for (k in LrtCompositionRunner.sortedKeys(resolvedInput)) {
            match (resolvedInput.get(k)) {
                case Some(v) =>
                    args.add("--" + k)
                    args.add(v)
                case None => ()
            }
        }

        try {
            // 关键：workingDirectory 必须传，否则相对路径脚本会解析到 runtime 根目录（1.2.11 缺陷）
            let sub = newProcess(
                LrtCompositionRunner.resolveInterpreter(),
                args.toArray(),
                workingDirectory: Some(Path(cwd)),
                redirectErr: true
            )
            let (code, out, errOut) = LrtCompositionRunner.capture(sub)
            if (code == 0) {
                LogUtils.info("[LrtCompositionRunner] script step '${step.name}' ok, cwd=${cwd} trace=${traceId}")
                return (true, out, "")
            }
            return (false, out + errOut, "脚本退出码 ${code}：${errOut}")
        } catch (e: Exception) {
            return (false, "", "脚本执行异常：${e.message}")
        }
    }

    /// plugin 分发：经注入的 LrtPluginCaller 调用插件路由
    private func runPluginStep(
        step: LrtStep,
        resolvedInput: HashMap<String, String>,
        traceId: String
    ): (Bool, String, String) {
        match (_pluginCaller) {
            case Some(caller) =>
                try {
                    let out = caller(step.pluginRoute, resolvedInput)
                    LogUtils.info("[LrtCompositionRunner] plugin step '${step.name}' route='${step.pluginRoute}' trace=${traceId}")
                    return (true, out, "")
                } catch (e: Exception) {
                    return (false, "", "插件路由调用异常：${e.message}")
                }
            case None =>
                return (false, "", "步骤 '${step.name}' 是 plugin 类型，但未注入 LrtPluginCaller（无法调用路由 '${step.pluginRoute}'）")
        }
    }

    /// output 分发：聚合（无副作用）。将 input 中已解析的值拼成报告文本。
    private func aggregateOutput(step: LrtStep, resolvedInput: HashMap<String, String>): String {
        let sb = StringBuilder()
        sb.append("# 编排产出聚合：${step.name}\n")
        for (k in LrtCompositionRunner.sortedKeys(resolvedInput)) {
            match (resolvedInput.get(k)) {
                case Some(v) => sb.append("- ${k}: ${v}\n")
                case None => ()
            }
        }
        return sb.toString()
    }

    // ── 编排主流程 ────────────────────────────────────────────────

    /// 执行整条编排。按拓扑序执行；失败后续步骤标记 Skipped 并传播。
    public func run(traceId!: String = ""): LrtCompositionResult {
        let result = LrtCompositionResult()
        let start = LrtCompositionRunner.nowMs()

        match (loadComposition()) {
            case None =>
                result.status = LrtStepStatus.Failed
                result.errorMessage = "无法加载 COMPOSITION.yaml（技能目录：${_skillDir}）"
                result.totalDurationMs = LrtCompositionRunner.nowMs() - start
                return result
            case Some(comp) =>
                result.compositionName = comp.name
                let sorted = topologicalSort(comp.steps)
                if (sorted.isEmpty()) {
                    if (comp.steps.isEmpty()) {
                        result.status = LrtStepStatus.Completed
                        result.totalDurationMs = LrtCompositionRunner.nowMs() - start
                        return result
                    }
                    result.status = LrtStepStatus.Failed
                    result.errorMessage = "拓扑排序失败：步骤依赖存在环"
                    result.totalDurationMs = LrtCompositionRunner.nowMs() - start
                    return result
                }

                let stepOutputs = HashMap<String, String>()
                var hasFailure = false

                for (step in sorted) {
                    if (hasFailure) {
                        let skipped = LrtStepResult()
                        skipped.stepName = step.name
                        skipped.status = LrtStepStatus.Skipped
                        result.stepResults.add(step.name, skipped)
                        continue
                    }
                    let sr = executeStep(step, stepOutputs, traceId)
                    result.stepResults.add(step.name, sr)
                    if (sr.status == LrtStepStatus.Failed) {
                        hasFailure = true
                    } else if (sr.status == LrtStepStatus.Completed) {
                        stepOutputs.add(step.name, sr.output)
                    }
                }

                if (hasFailure) {
                    result.status = LrtStepStatus.Failed
                    // 收集首个失败原因，便于上层报告
                    // 注意：这里必须用不同变量名，不能也叫 `sr`——否则内侧 `sr` 会遮蔽
                    // 外层 for-in 的 `sr`，触发"unused variable"告警且易误读。
                    for (step in sorted) {
                        match (result.stepResults.get(step.name)) {
                            case Some(failedRes) =>
                                if (failedRes.status == LrtStepStatus.Failed && result.errorMessage.isEmpty()) {
                                    result.errorMessage = failedRes.errorMessage
                                }
                            case None => ()
                        }
                    }
                } else {
                    result.status = LrtStepStatus.Completed
                    result.finalOutput = buildFinalOutput(stepOutputs)
                }

                result.cacheHits = LrtCompositionRunner.countCacheHits(result)
                result.totalDurationMs = LrtCompositionRunner.nowMs() - start
                return result
        }
    }

    /// 产出聚合（借鉴 CompositionExecutor.buildFinalOutput 的骨架）
    private func buildFinalOutput(stepOutputs: HashMap<String, String>): String {
        let sb = StringBuilder()
        for (name in LrtCompositionRunner.sortedKeys(stepOutputs)) {
            match (stepOutputs.get(name)) {
                case Some(v) =>
                    sb.append("\n--- ${name} ---\n")
                    sb.append(v)
                case None => ()
            }
        }
        return sb.toString()
    }

    public func clearCache(): Unit {
        _cache.clear()
    }

    // ── 工具函数 ─────────────────────────────────────────────────

    /// 稳定排序键（HashMap 迭代序不稳定，用于拼 key 与聚合时的确定性）
    private static func sortedKeys(m: HashMap<String, String>): ArrayList<String> {
        let out = ArrayList<String>()
        for ((k, _) in m) {
            out.add(k)
        }
        // 简单插入排序，避免依赖 std.sort 的包级函数导入
        var i = 1
        while (i < out.size) {
            let cur = out[i]
            var j = i - 1
            while (j >= 0 && out[j] > cur) {
                out[j + 1] = out[j]
                j = j - 1
            }
            out[j + 1] = cur
            i = i + 1
        }
        return out
    }

    private static func join(parts: ArrayList<String>): String {
        let sb = StringBuilder()
        for (p in parts) {
            sb.append(p)
        }
        return sb.toString()
    }

    private static func countCacheHits(result: LrtCompositionResult): Int64 {
        var count: Int64 = 0
        for ((_, sr) in result.stepResults) {
            if (sr.fromCache) {
                count = count + 1
            }
        }
        return count
    }

    private static func nowMs(): Int64 {
        return (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    }

    /// 解释器：env LRT_PYTHON 优先，否则 python3
    private static func resolveInterpreter(): String {
        let envPath = LrtCompositionRunner.envOr("LRT_PYTHON", "")
        if (!envPath.isEmpty()) {
            return envPath
        }
        return "python3"
    }

    private static func envOr(name: String, dflt: String): String {
        match (getVariable(name)) {
            case Some(v) => v
            case None => dflt
        }
    }

    /// 读空 stdout/stderr 直到进程结束，返回 (exitCode, stdout, stderr)
    private static func capture(sub: SubProcess): (Int64, String, String) {
        let outFuture = spawn { => LrtCompositionRunner.readAll(sub.stdOutPipe) }
        let errFuture = spawn { => LrtCompositionRunner.readAll(sub.stdErrPipe) }
        let code = sub.wait(timeout: Duration.minute * 30)
        let out = outFuture.get()
        let err = errFuture.get()
        return (Int64(code), out, err)
    }

    private static func readAll(stream: InputStream): String {
        let buf = Array<Byte>(4096, { _ => 0 })
        let sb = StringBuilder()
        try {
            while (true) {
                let n = stream.read(buf)
                if (n <= 0) {
                    break
                }
                sb.append(String.fromUtf8(buf[0..n]))
            }
        } catch (e: Exception) {
            LogUtils.warn("[LrtCompositionRunner] readStream error: ${e.message}")
        }
        return sb.toString()
    }

    // ── 路径 / 文件小工具 ────────────────────────────────────────

    /// 拼接技能目录下的相对路径（统一 "/" 分隔，Windows 上 std.fs 同样接受）
    private static func joinPath(base: String, child: String): String {
        let b = if (base.endsWith("/") || base.endsWith("\\")) { base } else { base + "/" }
        let c = if (child.startsWith("/") || child.startsWith("\\")) { child[1..child.size] } else { child }
        return b + c
    }

    /// 文件存在且非空。用于 `${file:xxx}` 条件判定：读不到 / 读失败一律按"不存在"处理。
    private static func fileNonEmpty(path: String): Bool {
        try {
            if (!exists(path)) {
                return false
            }
            return FileInfo(path).size > 0
        } catch (e: Exception) {
            LogUtils.warn("[LrtCompositionRunner] stat '${path}' failed, treat as missing: ${e.message}")
            return false
        }
    }

    // ── JSON 取值小工具 ───────────────────────────────────────────

    private static func optString(obj: JsonObject, key: String): String {
        match (obj.get(key)) {
            case Some(v) => scalarToString(v)
            case None => ""
        }
    }

    private static func scalarToString(v: JsonValue): String {
        // JsonValue 是 sealed abstract，不能用 case JsonString(s) 直接匹配；
        // 须先 kind() 判别形态，再 asXxx() 取值。
        match (v.kind()) {
            case JsonKind.JsString => v.asString().getValue()
            case JsonKind.JsInt => v.asInt().getValue().toString()
            case JsonKind.JsFloat => v.asFloat().getValue().toString()
            case JsonKind.JsBool => v.asBool().getValue().toString()
            case JsonKind.JsNull => ""
            case _ => v.toString()
        }
    }

    private static func stringArray(obj: JsonObject, key: String): ArrayList<String> {
        let out = ArrayList<String>()
        match (obj.get(key)) {
            case Some(v) =>
                match (v.kind()) {
                    case JsonKind.JsArray =>
                        for (item in v.asArray().getItems()) {
                            out.add(scalarToString(item))
                        }
                    case JsonKind.JsString =>
                        let s = v.asString().getValue()
                        if (!s.trimAscii().isEmpty()) {
                            out.add(s)
                        }
                    case _ => ()
                }
            case None => ()
        }
        return out
    }
}
