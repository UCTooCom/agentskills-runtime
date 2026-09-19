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
 *   - script：经 std.process.launch（必须传 workingDirectory=cwd）执行脚本
 *   - plugin：调用插件路由
 *   - output：聚合输出（无副作用）
 *
 * 变量插值支持三类：${input.xxx} / ${step-name.output} / ${env.YYYYMMDD}；
 * 引用未就绪产出时**报错并指出缺失依赖**，禁止静默替换为空串（spec 5.14）。
 *
 * 2026-09-13 迁移动机（tasks.md §4.2 #242）：原文件位于 runtime 侧 src/skill/，
 * 与插件进程（skills/long-running-task，独立进程）无法互相调用，故**迁移到插件侧**，
 * 由 LrtExecutor 实例化并驱动整条 COMPOSITION（替换宿主 Agent 经 ReAct 读 COMPOSITION 后逐步走 Python 的旧流程）。
 * 适配点：
 *   - package magic.skill → skill_long_running_task
 *   - magic.log.LogUtils → eprintln（插件统一走 stderr 日志）
 *   - 子进程执行改走 std.process.launch（stdOut/stdErr 走 Pipe，复用原有 capture 读流；替代 runtime 侧 newProcess 工具）
 *   - yaml4cj 作为插件依赖新增（plugin cjpm.toml）
 */
package skill_long_running_task

import std.collection.{ArrayList, HashMap}
import std.fs.{File, Path, FileInfo, exists}
import std.time.DateTime
import std.env.getVariable
import std.core.Duration
import std.io.InputStream
import std.process.*
import stdx.encoding.json.{JsonValue as StdJsonValue, JsonObject, JsonKind}
import yaml4cj.yaml.decode
// host.* 服务（ctx.invoke）返回的是 jsonvalue 库的 JsonValue，与 YAML 解析用的
// stdx.encoding.json.JsonValue 是两套不同实现，故两套并存：
//   - YAML 侧：StdJsonValue（别名） / JsonObject / JsonKind（scalarToString 等）
//   - host 服务侧：JsonValue / HashMap<String, JsonValue>（injectDataContract/formatSchemaBlock 等）
import jsonvalue.*

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
///
/// `SqlOnly`（spec 5.9.1 规则 5「数据库连接降级」）：**同一个脚本**追加 `--sql-only` 再跑一次，
/// 让它在不连库的前提下产出可人工导入的 SQL 文件。它不是"另一个后端"，而是 script 步的
/// **参数级降级**——脚本本身已支持该开关（见 `save_to_db.py` 的 `--sql-only`），
/// 故这里只需换 argv，不必新写执行通道。
public enum LrtDegradationTarget <: Equatable<LrtDegradationTarget> {
    | CliExecute
    | BuiltinTool
    | Llm
    | Template
    | SqlOnly

    public operator func ==(right: LrtDegradationTarget): Bool {
        match ((this, right)) {
            case (LrtDegradationTarget.CliExecute, LrtDegradationTarget.CliExecute) => true
            case (LrtDegradationTarget.BuiltinTool, LrtDegradationTarget.BuiltinTool) => true
            case (LrtDegradationTarget.Llm, LrtDegradationTarget.Llm) => true
            case (LrtDegradationTarget.Template, LrtDegradationTarget.Template) => true
            case (LrtDegradationTarget.SqlOnly, LrtDegradationTarget.SqlOnly) => true
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
        case "sql_only" => Some(LrtDegradationTarget.SqlOnly)
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
                eprintln("[LrtCompositionRunner] COMPOSITION.yaml not found: ${filePath}")
                return None
            }
            let bytes = File.readFrom(filePath)
            let content = String.fromUtf8(bytes)
            return parseFromString(content)
        } catch (e: Exception) {
            eprintln("[LrtCompositionRunner] Failed to read ${filePath}: ${e.message}")
            return None
        }
    }

    public func parseFromString(content: String): Option<LrtComposition> {
        try {
            let parsed = decode(content.toArray())
            if (!(parsed is JsonObject)) {
                eprintln("[LrtCompositionRunner] COMPOSITION.yaml root is not a mapping")
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
            eprintln("[LrtCompositionRunner] Failed to parse COMPOSITION.yaml: ${e.message}")
            return None
        }
    }

    private static func parseStep(obj: JsonObject): Option<LrtStep> {
        let step = LrtStep()
        step.name = optString(obj, "name")
        if (step.name.isEmpty()) {
            eprintln("[LrtCompositionRunner] step without name, skipped")
            return None
        }
        let typeStr = optString(obj, "step_type")
        match (parseLrtStepType(typeStr)) {
            case Some(t) => step.stepType = t
            case None =>
                eprintln("[LrtCompositionRunner] step '${step.name}' has invalid step_type: '${typeStr}'")
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
                    eprintln("[LrtCompositionRunner] step '${step.name}' is script but has no 'script'")
                    return None
                }
            case LrtStepType.Plugin =>
                if (step.pluginRoute.isEmpty()) {
                    eprintln("[LrtCompositionRunner] step '${step.name}' is plugin but has no 'plugin_route'")
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
                    eprintln("[LrtCompositionRunner] step '${step.name}' depends on unknown step '${dep}'")
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
            eprintln("[LrtCompositionRunner] topological sort failed: possible cycle among steps")
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
            eprintln("[LrtCompositionRunner] cannot evaluate condition '${condition}': ${err}")
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
            eprintln("[LrtCompositionRunner] step '${step.name}' skipped (condition not met) trace=${traceId}")
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
                eprintln("[LrtCompositionRunner] ${result.errorMessage} trace=${traceId}")
                return result
            }
            resolved.add(k, val)
        }

        // §14.2 按步注入数据契约（best-effort：查表结构后注入 resolved，供脚本 / D 层消费）
        this.injectDataContract(step, resolved)

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
                eprintln("[LrtCompositionRunner] step '${step.name}' attempt ${attempt} failed: ${err}, retrying... trace=${traceId}")
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
                            eprintln("[LrtCompositionRunner] step '${step.name}' 主路径失败，"
                                + "经降级后端 '${raw}' 完成（产出已标记 degraded）trace=${traceId}")
                            return result
                        }
                        report = report + "；降级 '${raw}' 失败：${dErr}"
                    case None =>
                        eprintln("[LrtCompositionRunner] step '${step.name}' 声明了未知降级后端 '${raw}'"
                            + "（支持 cli_execute/sql_only/builtin_tool/llm/template），已跳过")
                }
            }
        }

        result.status = LrtStepStatus.Failed
        result.attempts = attempt
        result.errorMessage = "步骤 '${step.name}' 主路径与降级链均失败 —— ${report}"
        result.durationMs = LrtCompositionRunner.nowMs() - start
        eprintln("[LrtCompositionRunner] ${result.errorMessage} trace=${traceId}")
        return result
    }

    // ── §14.2 按步注入数据契约（spec 5.16 规则 8：单回合注入 ≤2000 token）────────
    // 仅注入当前步骤 uses_tables 声明的表（1-2 张），经 host.db_schema_lookup 查结构，
    // 拼成「可用数据契约」块注入 step 的 resolved input（键 data_contract），
    // 由 runScriptStep 透传为 --data_contract，供 D 层脚本（如 parse_goal.py）构建
    // ReAct system prompt 时填入「可用数据契约」小节。
    // best-effort：任一表查不到 / 解析失败则跳过该表；超 token 预算按表顺序裁剪。绝不阻断编排。

    /// 在 executeStep 插值后调用：把 data_contract 注入 resolvedInput（原地修改 HashMap）。
    private func injectDataContract(
        step: LrtStep,
        resolvedInput: HashMap<String, String>
    ): Unit {
        if (step.usesTables.isEmpty()) {
            return
        }
        let budget: Int64 = 6000   // ≈2000 token（保守 3 字符 / token）
        // 注：buildContractBlock 的 trimSamples 是位置参数（仓颉仅命名参数可带默认值/按名传），
        // 故此处按位置传，不能写 trimSamples: false。
        var block = this.buildContractBlock(step, false)
        if (block.size > budget) {
            block = this.buildContractBlock(step, true)
        }
        if (!block.isEmpty()) {
            resolvedInput["data_contract"] = block
        }
    }

    /// 拼装数据契约块；trimSamples=true 时去掉示例行与列注释以压缩体积。
    private func buildContractBlock(step: LrtStep, trimSamples: Bool): String {
        match (LrtPersistService.currentCtx()) {
            case None =>
                eprintln("[LrtCompositionRunner][data-contract] 无 ctx，跳过数据契约注入")
                return ""
            case Some(ctx) =>
                let budget: Int64 = 6000
                let sb = StringBuilder()
                sb.append("## 可用数据契约（仅当前步骤用到的表）\n")
                for (t in step.usesTables) {
                    let args = HashMap<String, JsonValue>()
                    args["table"] = JsonValue.String(t)
                    var raw: JsonValue = JsonValue.Null
                    try {
                        // 第三参形状：单元素数组包一个查询参数对象。
                        // 依据宿主契约 cordis_host_services.cj:318 unwrapInvokeParams —— 它读
                        // InvokeParams{service,method,args:Array<JsonValue>}（cordis_core/message.cj:277），
                        // 再取 args[0] 作真正的参数。裸传对象会让宿主取不到 table 字段，勿改。
                        let invokeArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
                        invokeArgs[0] = JsonValue.from(args)
                        // 必须显式写 <JsonValue, JsonValue>，原因（已由编译实测确认，别改回去）：
                        //   · 不写类型实参 → 重载解析面对两个同形候选，报
                        //       "ambiguous match for function call 'invoke'"
                        //     （候选 plugin_runtime.cj:115 非泛型版 / :131 泛型版，均在 Class-PluginContext）
                        //   · 写 <PluginContext, JsonValue> → 编译器把形参按 T **重写**为
                        //       Array<PluginContext>，报 mismatched types（显式类型实参是"指定"形参类型，
                        //       不是"消歧提示"，所以不能用不满足约束的类型去排除泛型重载）
                        //   · 只有 T 取 JsonValue（与实参元素类型一致）时，形参才仍是 Array<JsonValue>，
                        //     且泛型版自身也满足 T <: JsonSerializable（JsonValue 实现该接口，
                        //     plugin_runtime.cj:133 内部即调 JsonValue.fromObject），
                        //     显式类型实参把选择收敛到泛型版 → 唯一确定，编译通过。
                        // 返回值 R 取 JsonValue：直接拿到 JSON，无需再 match 拆包。
                        raw = ctx.invoke<JsonValue, JsonValue>(
                            "host.db_schema_lookup", "lookup", invokeArgs)
                    } catch (e: Exception) {
                        eprintln("[LrtCompositionRunner][data-contract] 查表 '${t}' 结构失败（跳过）: ${e}")
                        continue
                    }
                    let part = this.formatSchemaBlock(t, raw, trimSamples)
                    if (sb.toString().size + part.size > budget) {
                        sb.append("...（数据契约已超 token 预算，余表略）\n")
                        break
                    }
                    sb.append(part)
                }
                return sb.toString()
        }
    }

    /// 把单表结构格式化为可读文本块。raw 结构见 host.db_schema_lookup 返回：
    /// { table, columns:[{name,type,nullable,comment}], idempotency_keys:[...], sample_rows:[...] }。
    private func formatSchemaBlock(table: String, raw: JsonValue, trimSamples: Bool): String {
        let sb = StringBuilder()
        sb.append("\n### 表 ${table}\n")
        match (raw) {
            case JsonValue.Map(f) =>
                match (f.get("columns")) {
                    case Some(JsonValue.Array(cols)) =>
                        sb.append("列（name:type:nullable:comment）:\n")
                        for (c in cols) {
                            match (c) {
                                case JsonValue.Map(cm) =>
                                    let name = this.strField(cm, "name")
                                    let typ = this.strField(cm, "type")
                                    let nullable = this.strField(cm, "nullable")
                                    let comment = if (trimSamples) { "" } else { this.strField(cm, "comment") }
                                    sb.append("- ${name}:${typ}:${nullable}:${comment}\n")
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
                match (f.get("idempotency_keys")) {
                    case Some(JsonValue.Array(keys)) =>
                        let ks = ArrayList<String>()
                        for (k in keys) {
                            match (k) {
                                case JsonValue.String(s) => ks.add(s)
                                case _ => ()
                            }
                        }
                        if (!ks.isEmpty()) {
                            sb.append("幂等键: ")
                            var first = true
                            for (k in ks) {
                                if (!first) { sb.append(", ") }
                                sb.append(k)
                                first = false
                            }
                            sb.append("\n")
                        }
                    case _ => ()
                }
                if (!trimSamples) {
                    match (f.get("sample_rows")) {
                        case Some(JsonValue.Array(rows)) =>
                            if (!rows.isEmpty()) {
                                sb.append("示例行:\n")
                                for (r in rows) {
                                    sb.append("- ${r.stringify()}\n")
                                }
                            }
                        case _ => ()
                    }
                }
            case _ => sb.append("(结构查询返回格式异常)\n")
        }
        return sb.toString()
    }

    private func strField(m: HashMap<String, JsonValue>, key: String): String {
        match (m.get(key)) {
            case Some(JsonValue.String(s)) => s
            case _ => ""
        }
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
                return runCliFallback(step, resolvedInput, traceId, "cli_execute", ArrayList<String>())
            case LrtDegradationTarget.SqlOnly =>
                // spec 5.9.1 规则 5「数据库连接降级」：数据库连不上时**同一个脚本**加 `--sql-only`
                // 再跑一次，产出可人工导入的 SQL 文件，而不是让整步判失败。
                // 与 cli_execute 同通道、只多一个开关：脚本侧已支持该参数（save_to_db.py），
                // 这里不必新写执行逻辑，也避免了"降级通道各写一套 argv 装配"的维护债。
                if (step.stepType != LrtStepType.Script || step.script.isEmpty()) {
                    return (false, "", "sql_only 降级仅适用于 script 步骤，本步类型为 '${lrtStepTypeToString(step.stepType)}'")
                }
                let sqlFlags = ArrayList<String>()
                sqlFlags.add("--sql-only")
                return runCliFallback(step, resolvedInput, traceId, "sql_only", sqlFlags)
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

    /// cli_execute / sql_only 降级：把 input 摊平成 `--k=v` 命令行参数再跑一次脚本
    ///
    /// @param label     降级后端名，用于日志与 degraded 标记（`cli_execute` / `sql_only`）
    /// @param extraFlags 额外开关（如 `--sql-only`）；为空表示与主路径同参数、只换 argv 形态
    private func runCliFallback(
        step: LrtStep,
        resolvedInput: HashMap<String, String>,
        traceId: String,
        label: String,
        extraFlags: ArrayList<String>
    ): (Bool, String, String) {
        let scriptAbs = LrtCompositionRunner.joinPath(_skillDir, step.script)
        if (!exists(scriptAbs)) {
            return (false, "", "${label} 降级失败：脚本不存在 ${scriptAbs}")
        }
        eprintln("[LrtCompositionRunner] step '${step.name}' 转入 ${label} 降级 trace=${traceId}")
        let argv = ArrayList<String>()
        argv.add(scriptAbs)
        for (k in LrtCompositionRunner.sortedKeys(resolvedInput)) {
            match (resolvedInput.get(k)) {
                case Some(v) => argv.add("--" + k + "=" + v)
                case None => ()
            }
        }
        for (f in extraFlags) {
            argv.add(f)
        }
        // 参数形式刻意与 runScriptStep 区分：那里是 `--k v`，这里是 `--k=v`。
        // 目的不是玩花样，而是让降级路径与主路径在进程参数层面就不一样，
        // 万一主路径卡在某个 argv 装配环节，降级仍有机会跑通。
        // workingDirectory 必须为技能目录：脚本里的 output/xxx 相对路径依赖它。
        try {
            let sub = launch(
                LrtCompositionRunner.resolveInterpreter(),
                argv.toArray(),
                workingDirectory: Some(Path(_skillDir)),
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )
            let (code, out, errOut) = LrtCompositionRunner.capture(sub)
            if (code != 0) {
                return (false, "", "${label} 退出码 ${code}：${errOut}")
            }
            if (out.trimAscii().isEmpty()) {
                return (false, "", "${label} 无输出")
            }
            return (true, LrtCompositionRunner.markDegraded(step.name, label, out), "")
        } catch (e: Exception) {
            return (false, "", "${label} 执行异常：${e.message}")
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

    /// script 分发：经 std.process.launch 执行脚本，**必须传 workingDirectory=cwd**
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
            let sub = launch(
                LrtCompositionRunner.resolveInterpreter(),
                args.toArray(),
                workingDirectory: Some(Path(cwd)),
                stdIn: ProcessRedirect.Pipe,
                stdOut: ProcessRedirect.Pipe,
                stdErr: ProcessRedirect.Pipe
            )
            let (code, out, errOut) = LrtCompositionRunner.capture(sub)
            if (code == 0) {
                eprintln("[LrtCompositionRunner] script step '${step.name}' ok, cwd=${cwd} trace=${traceId}")
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
                    eprintln("[LrtCompositionRunner] plugin step '${step.name}' route='${step.pluginRoute}' trace=${traceId}")
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

    /// 技能根目录（COMPOSITION.yaml / scripts/ / output/ 的基准）。
    /// 优先 env LRT_SKILL_ROOT（plugin.yaml 部署建议显式设置，mode:process 下 cwd 不保证是技能根）；
    /// 未设置时回退进程当前目录。
    public static func resolveSkillDir(): String {
        match (getVariable("LRT_SKILL_ROOT")) {
            case Some(v) => if (!v.trimAscii().isEmpty()) { return v }
            case None => ()
        }
        return "."
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
            eprintln("[LrtCompositionRunner] readStream error: ${e.message}")
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
            eprintln("[LrtCompositionRunner] stat '${path}' failed, treat as missing: ${e.message}")
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

    private static func scalarToString(v: StdJsonValue): String {
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
