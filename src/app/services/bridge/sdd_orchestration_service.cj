/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

// 跳步校验里要用 ArrayList（本文件原先只用到 Array，故此前没引 std.collection）
import std.collection.ArrayList
import magic.tool.{SubAgentDispatchRequest, SubAgentDispatcher}
import magic.app.services.uctoo.{
    SddProjectsService, CrontabService, LongRunningTaskArtifactService, AgentApprovalsService
}
import magic.app.models.uctoo.CrontabPO
import magic.app.models.uctoo.LongRunningTaskArtifactPO
import magic.app.models.uctoo.AgentApprovalsPO
import magic.app.core.response.APIResult
import stdx.encoding.json.{JsonObject, JsonString, JsonBool}
import std.fs.{Path, exists, Directory, File, OpenMode}
import std.time.DateTime
// StringReader.close()/readToEnd() 走 InputStream 接口扩展，只 import StringReader 不够，
// 必须同时让 InputStream 可见（否则报 'close' is not a member of class 'StringReader<...>'）。
// 同款先例见 src/skill/application/skill_management_service.cj:14-18。
import std.io.{StringReader, InputStream}
import std.env.getWorkingDirectory
import magic.log.LogUtils
import magic.agent.base.BaseAgent
import magic.core.agent.{AgentRequest, AgentResponseStatus}
import magic.skill.SkillAwareAgent

/**
 * SDD 六步编排服务（**宿主侧**）。
 *
 * ## 为什么落在宿主侧（tasks.md v8 架构决策）
 * 宿主向 L3 插件进程只暴露 `host.db` / `host.mcp` / `host.event` /
 * `host.db_schema_lookup` / `host.cache` / `host.log`
 * （`src/plugin/cordis_host_services.cj:70-76` 注册），**没有 `host.agent.invoke` RPC**；
 * `SubAgentTool` 是宿主内建工具（`builtin_tools_registry.cj:120`），Agent 运行时全在宿主进程内，
 * 不向插件开放。因此「插件进程内调 SubAgentTool」在架构上不可实现，
 * 六步编排的真派生必须落在宿主侧（与 `lrt_composition_runner` 同层）。
 *
 * ## 每步做什么（两条路径）
 * - **派生步**（research/spec/design/task/test）：
 *     查 agents 表（skill_name='sdd' + 子 agent 名）
 *     → AgentRuntimeBridge 造 Agent → AgentAsTool(Isolated) 真执行（T-15）
 *     → 派单前后写 sub_agent_invocations（beginInvocation / finishInvocation）
 * - **直执行步**（`code`，见 HOST_DIRECT_STAGES）：
 *     主 agent + 编程技能 + SOP（runHostDirectStage），**不派生、不写 sub_agent_invocations**
 *     —— 2026-09-27 拍板："换脑子的才派生，换说明书的用技能"，编码不需要换脑子。
 *
 * 两条路径成功时都推进 sdd_projects 的 current_stage / status。
 *
 * 派生步的子 agent 缺失时由派发层**立即失败并提示**（T-15 红线：禁静默降级为"主 agent 自己写"）；
 * 直执行步的"主 agent 自己写"是**设计如此**，不是降级——但编程技能未挂载同样立即失败。
 */
public struct SddStageResult {
    public let stage: String
    public let agentName: String
    public let success: Bool
    public let output: String
    public let error: String
    public let durationMs: Int64
    /// 本阶段产物落盘后的**相对路径**（`specs/{feature_name}/{file}`）；未落盘时为空串
    public let artifactPath: String

    public init(
        stage: String,
        agentName: String,
        success: Bool,
        output: String,
        error: String,
        durationMs: Int64,
        artifactPath!: String = ""
    ) {
        this.stage = stage
        this.agentName = agentName
        this.success = success
        this.output = output
        this.error = error
        this.durationMs = durationMs
        this.artifactPath = artifactPath
    }
}

public class SddOrchestrationService {
    /// 六步固定顺序（对齐 skills/sdd/COMPOSITION.yaml 的六个 plugin 步）
    public static let STAGES = ["research", "spec", "design", "task", "code", "test"]

    /**
     * **主 agent 直执行**的阶段（不派生子 agent）：仅 `code`。
     *
     * 依据（2026-09-27 拍板，对齐 COMPOSITION.yaml code 步 acceptance_criteria 与
     * prompts/code.md）："换脑子的才派生，换说明书的用技能"——编码不需要换脑子，
     * 需要的是**确定的 API 依据 + 工程内既有范式**。语言能力以**技能**形式提供：
     * 主 agent 加载 `cangjie-coder` / `web-coder` / `app-coder`（过渡期路由
     * `fullstack-codegen` / `frontend-dev`）后按 SOP 自行执行。
     *
     * 因此：code 步**不查 agents 表子 agent、不写 sub_agent_invocations**，
     * 派生链里也不再有 `sdd-code-dispatcher`（声明文件已删，"约定即注册、删文件即下线"）。
     */
    public static let HOST_DIRECT_STAGES = ["code"]

    /// 技能名：派生时用于限定子 agent 归属（约定即注册）
    public static let SKILL_NAME = "sdd"

    private let dispatcher: SubAgentDispatcher
    private let projectsService: SddProjectsService
    private let artifactService: LongRunningTaskArtifactService

    public init(dispatcher: SubAgentDispatcher) {
        this.dispatcher = dispatcher
        this.projectsService = SddProjectsService()
        this.artifactService = LongRunningTaskArtifactService()
    }

    /**
     * 便捷构造：直接挂宿主侧真派生实现。
     *
     * 组合根与 T-15 一致——`SubAgentDispatchServiceImpl` 需要 `AgentRuntimeBridge`
     * 才能 `loadFromDatabase` 造 Agent。
     */
    public static func withHostDispatcher(): SddOrchestrationService {
        SddOrchestrationService(SubAgentDispatchServiceImpl(AgentRuntimeBridge.instance))
    }

    /**
     * 六步 → 子 agent 名映射（**仅派生步**）。
     *
     * 名称取自 skills/sdd/agents/ 目录下各声明文件的 frontmatter `name:`（约定即注册，
     * 删文件即下线，禁硬编码名单之外的名字）。
     *
     * code 步返回**空串**：该步由主 agent 直执行（见 `HOST_DIRECT_STAGES`），无子 agent。
     * 调用方须先判 `isHostDirectStage`，不得拿空串去派单。
     *
     * 注：此处不可写该目录的通配形式（「agents/」后接星号点 md）——块注释内出现
     * 斜杠紧跟星号会被词法器识别为嵌套块注释起始，导致本注释无法闭合
     * （cjc 报 unterminated block comment）。
     */
    public static func subAgentForStage(stage: String): String {
        if (stage == "research") { return "sdd-researcher" }
        if (stage == "spec") { return "sdd-spec-writer" }
        if (stage == "design") { return "sdd-design-writer" }
        if (stage == "task") { return "sdd-task-planner" }
        // code：主 agent 直执行（加载编程技能 + SOP），**不派生**（见 HOST_DIRECT_STAGES）
        if (stage == "test") { return "sdd-tester" }
        return ""
    }

    /// 是否为主 agent 直执行阶段（不派生子 agent）。
    public static func isHostDirectStage(stage: String): Bool {
        for (s in SddOrchestrationService.HOST_DIRECT_STAGES) {
            if (s == stage) {
                return true
            }
        }
        false
    }

    /**
     * 语言标签 → 编程技能候选链（对齐 COMPOSITION.yaml code 步的 degradation_chain）。
     *
     * 逐个候选检查主 agent 的 SkillManager 是否已挂载，取**第一个命中**的；
     * 全不命中 → 由调用方显式失败并提示缺口（铁律：查不到依据须标注缺口请人工确认，
     * 禁止静默猜写）。过渡期路由（web-coder/app-coder 待建）必须在回传里写明。
     */
    public static func codingSkillChain(language: String): Array<String> {
        if (language == "cangjie") { return ["cangjie-coder"] }
        if (language == "web") { return ["web-coder", "fullstack-codegen", "frontend-dev"] }
        if (language == "app") { return ["app-coder", "frontend-dev"] }
        // 未给语言标签：按 COMPOSITION 的 degradation_chain 顺序全量候选
        ["cangjie-coder", "web-coder", "app-coder", "fullstack-codegen", "frontend-dev"]
    }

    /**
     * 阶段产物文件名（对齐 skills/sdd/COMPOSITION.yaml 各步 acceptance_criteria）。
     *
     * code 步的验收是「至少一份 usage=deliverable 代码产物入库」，本体为散落源文件、
     * 无单一文件名，故此处落一份汇总文档（artifact_type 仍记 code）。
     */
    public static func artifactFileForStage(stage: String): String {
        if (stage == "research") { return "research.md" }
        if (stage == "spec") { return "spec.md" }
        if (stage == "design") { return "design.md" }
        if (stage == "task") { return "tasks.md" }
        if (stage == "code") { return "code-summary.md" }
        if (stage == "test") { return "test-report.md" }
        return "${stage}.md"
    }

    /// artifact_type：取 LRT DATA_CONTRACT 枚举 [code, config, doc, test, report, data, artifact]，不自造。
    public static func artifactTypeForStage(stage: String): String {
        if (stage == "code") { return "code" }
        if (stage == "test") { return "test" }
        return "doc"
    }

    /// 产物**相对**路径（入库口径：契约要求相对路径，便于跨机迁移）
    public static func relativeArtifactPath(featureName: String, stage: String): String {
        "specs/${featureName}/${SddOrchestrationService.artifactFileForStage(stage)}"
    }

    /**
     * 落盘根目录：显式给了 output_dir 就用它，否则回落 runtime 工作目录下的 specs 子目录。
     *
     * 红线：阶段文档落 runtime 自有 specs 目录，禁落 .codeartsdoer/specs/（归属 CodeArts Agent）。
     */
    private static func resolveOutputDir(featureName: String, outputDir: String): String {
        if (!outputDir.isEmpty()) {
            return outputDir
        }
        var base = "specs"
        try {
            base = getWorkingDirectory().toString()
        } catch (_: Exception) {
            // 拿不到工作目录就退回相对路径（落盘位置随进程 cwd，仍可写）
        }
        "${base}/specs/${featureName}"
    }

    /**
     * 阶段产物落盘 + 入库（long_running_task_artifact）。
     *
     * 入库口径对齐 LRT DATA_CONTRACT.yaml 的 long_running_task_artifact 契约：
     *   - append-only：每步产出追加一条，不做 UPDATE 覆盖；
     *   - artifact_path 存相对路径；
     *   - verification_status 默认 pending，待 T-21 契约校验器回填 passed/failed；
     *   - usage=deliverable 是**逻辑概念**（LRT 亦不入表，见其 write_rule 的缺件判定）；
     *     实测表结构 11 列无 usage / stage 列，故把 stage 维度记入 verification_result jsonb，
     *     可按 verification_result 的 stage 键查询——不动公共表结构。
     *
     * @return 落盘后的相对路径；写文件或入库失败返回空串。
     *         产物登记失败**不让已跑完的阶段判失败**（编排主链路是子 agent 执行）。
     */
    private func persistArtifact(
        stage: String,
        featureName: String,
        content: String,
        userId: String,
        taskId: String,
        outputDir: String
    ): String {
        let relPath = SddOrchestrationService.relativeArtifactPath(featureName, stage)
        let dir = SddOrchestrationService.resolveOutputDir(featureName, outputDir)
        let absPath = "${dir}/${SddOrchestrationService.artifactFileForStage(stage)}"

        // 1) 落盘（先写文件：文件都没落就没必要登记一条指向空气的 artifact 记录）
        try {
            // revise 重做会再次写同一个文件——先把上一版归档成 .prev，
            // 满足 T-11「回退重做不覆盖已 confirm 产物」：库里 append-only 留痕，
            // 盘上保留上一版，两侧都可回溯。
            if (exists(absPath)) {
                try {
                    let prev = File(absPath, OpenMode.Read)
                    let pr = StringReader(prev)
                    let body = pr.readToEnd()
                    pr.close()
                    prev.close()
                    File.writeTo("${absPath}.prev", body.toArray())
                } catch (_: Exception) {
                    LogUtils.warn("[SddOrchestration] 归档上一版产物失败（本次直接覆盖）: ${absPath}")
                }
            }
            let parent = Path(absPath).parent
            if (!exists(parent.toString())) {
                Directory.create(parent.toString(), recursive: true)
            }
            File.writeTo(absPath, content.toArray())
        } catch (e: Exception) {
            LogUtils.error("[SddOrchestration] 产物落盘失败（跳过入库）: ${absPath}, ${e.message}")
            return ""
        }

        // 2) 入库
        try {
            let po = LongRunningTaskArtifactPO()
            po.artifactPath = relPath
            po.artifactType = SddOrchestrationService.artifactTypeForStage(stage)
            po.verificationStatus = "pending"
            // task_id 在库里是 uuid：空串必须转 None，否则触发 22P02
            po.taskId = if (taskId.isEmpty()) { None<String> } else { Some(taskId) }

            let meta = JsonObject()
            meta.put("stage", JsonString(stage))
            meta.put("feature_name", JsonString(featureName))
            meta.put("usage", JsonString("deliverable"))
            meta.put("source", JsonString("sdd-runStage"))
            po.verificationResult = Some<String>(meta.toString())

            let r = this.artifactService.create(po, userId)
            if (!r.success) {
                let why = match (r.reason) {
                    case Some(v) => v
                    case None => "unknown"
                }
                LogUtils.error("[SddOrchestration] 产物入库失败: ${relPath}, ${why}")
                return ""
            }
            LogUtils.info("[SddOrchestration] 产物已登记: ${relPath} (abs=${absPath})")
            return relPath
        } catch (e: Exception) {
            LogUtils.error("[SddOrchestration] 产物入库异常: ${relPath}, ${e.message}")
            return ""
        }
    }

    /**
     * 读取指定阶段已落盘的产物，供下游阶段作为上下文。
     *
     * 这是六步之间「框架显式传递上下文」的落点：下游不再靠各自猜 output_dir
     * 去捞前序文件，而是直接读到上游确定落盘的产物。
     *
     * @param maxChars 截断上限，防上游产物过长撑爆子 agent 上下文窗口
     */
    public func readStageArtifact(
        featureName: String,
        stage: String,
        outputDir: String,
        maxChars!: Int64 = 6000
    ): Option<String> {
        let dir = SddOrchestrationService.resolveOutputDir(featureName, outputDir)
        let absPath = "${dir}/${SddOrchestrationService.artifactFileForStage(stage)}"
        try {
            if (!exists(absPath)) {
                return None<String>
            }
            let file = File(absPath, OpenMode.Read)
            let reader = StringReader(file)
            let content = reader.readToEnd()
            reader.close()
            file.close()
            return Some(SddOrchestrationService.truncateChars(content, maxChars))
        } catch (e: Exception) {
            LogUtils.warn("[SddOrchestration] 读取阶段产物失败（当作无上游产物）: ${absPath}, ${e.message}")
            return None<String>
        }
    }

    /**
     * 按**字符**（Rune）安全截断。
     *
     * 仓颉 String 是 UTF-8，直接字节切片 `s[0..n]` 会把多字节的中文切成半个字
     * （"中" 占 3 字节）——产物文档是中文的，必须按 Rune 切。
     * 依据见同包 `char_delta_splitter.cj:9-17` 的复核结论。
     */
    private static func truncateChars(s: String, maxChars: Int64): String {
        let runes = s.toRuneArray()
        if (runes.size <= maxChars) {
            return s
        }
        let slice = Array<Rune>(maxChars, { i => runes[i] })
        String(slice)
    }

    /// 上一阶段（用于下游取上游产物）；首阶段返回空串。
    public static func previousStage(stage: String): String {
        var prev = ""
        for (s in SddOrchestrationService.STAGES) {
            if (s == stage) {
                return prev
            }
            prev = s
        }
        ""
    }

    /**
     * **所有**上游阶段（用于"跳步执行"的前置校验）。
     *
     * 与 `previousStage` 的区别：`previousStage` 只给紧邻的一步（下游拼上下文用），
     * 而显式指定阶段时会**跳步**（例：research/spec/design/tasks 已完成，用户直接点
     * "开始编码"），此时紧邻上游可能缺失中间几份产物，必须一次性把缺件全找出来。
     *
     * 未知阶段返回六步全集（调用方须先过 `isKnownStage`）。
     */
    public static func upstreamStages(stage: String): ArrayList<String> {
        var found = false
        var count: Int64 = 0
        for (s in SddOrchestrationService.STAGES) {
            if (s == stage) {
                found = true
            }
            if (!found) {
                count = count + 1
            }
        }
        let out = ArrayList<String>()
        for (i in 0..count) {
            out.add(SddOrchestrationService.STAGES[i])
        }
        out
    }

    /**
     * 显式指定阶段时的**上游产物前置校验**（跳步执行红线）。
     *
     * 为什么必须挡：指定阶段跑 code 而 tasks.md 不存在时，旧行为只是在 prompt 里
     * 写一句"上游未找到"，子 agent 转头自己编前提——这就是"无依据编码"。
     * 按项目口径（配置即事实、缺依据必须显式告知），这里直接拦下并给出**可操作**的
     * 修复提示（把 output_dir 指到已落盘阶段文档的目录）。
     *
     * `allowMissing=true` 是唯一的逃生口，含义是"我明知上游缺，仍要跳步"，
     * 此时不拦，但仍把缺件写进返回文案供日志/前端回显。
     *
     * @param stage 目标阶段（须先过 `isKnownStage`）
     * @param outputDir 阶段文档所在目录（为空则按 runtime 自有 specs/{feature}/ 查）
     */
    public func checkUpstream(
        stage: String,
        featureName: String,
        outputDir: String,
        allowMissing!: Bool = false
    ): APIResult<String> {
        let skipResearch = this.skipResearchFor(featureName)
        let missing = ArrayList<String>()
        let ups = SddOrchestrationService.upstreamStages(stage)
        for (i in 0..ups.size) {
            let up = ups[i]
            // 研究步被 enable_research 关掉时，它不算缺件（COMPOSITION condition 同款信号）
            var skipUp = skipResearch && up == "research"
            if (!skipUp) {
                // maxChars=1：只问"在不在"，不把正文读进来
                if (this.readStageArtifact(featureName, up, outputDir, maxChars: 1).isNone()) {
                    missing.add(up)
                }
            }
        }

        var names = ""
        for (j in 0..missing.size) {
            let m = missing[j]
            if (!names.isEmpty()) {
                names = names + ", "
            }
            names = names + m
        }

        if (missing.isEmpty()) {
            return APIResult<String>("upstream ok: stage='${stage}' 所需上游产物齐备（输出目录：${outputDir}）")
        }

        let why = "阶段 '${stage}' 在输出目录 '${outputDir}' 下找不到上游产物 [${names}]"
        if (allowMissing) {
            return APIResult<String>("upstream missing(allowed): ${why} —— 已按 allow_missing_upstream=true 放行，缺件由本阶段自行补齐前提")
        }
        APIResult<String>(false, why
            + "；请先用 output_dir 指到已落盘阶段文档的目录（例：.codeartsdoer/specs/<feature>/ 或 specs/<feature>/），"
            + "或显式传 allow_missing_upstream=true 表示你接受跳步缺件")
    }

    /// 工程是否关闭研究步（COMPOSITION condition 信号）：关闭时上游校验跳过 research。
    private func skipResearchFor(featureName: String): Bool {
        var skip = false
        try {
            match (this.projectsService.getByFeatureName(featureName)) {
                case Some(po) => skip = !po.enableResearch
                case None => ()
            }
        } catch (_: Exception) {
            // 读不到工程态时保守按"研究步未跑"处理，缺件照样报出来，不让调用方在不知情下跳步
            skip = false
        }
        skip
    }

    /**
     * 执行单个 SDD 阶段：真派生子 agent + 推进工程阶段。
     *
     * @param stage        阶段名（research/spec/design/task/code/test）
     * @param featureName  工程唯一键（对应 specs/{feature_name}）
     * @param question     交给子 agent 的问题/上下文包（Isolated 模式下全部上下文塞此字段）
     * @param userId       执行者（creator）
     * @param taskId       本步任务 ID（agent_contexts 按 task_id 隔离）
     * @param parentTaskId 父任务 ID
     * @param outputDir    产物落盘目录
     * @param agentId      主 agent 定义 id（仅 `code` 等直执行步需要，派生步忽略）
     * @param language     语言标签 cangjie/web/app（仅 `code` 步用于选编程技能）
     */
    public func runStage(
        stage: String,
        featureName: String,
        question: String,
        userId: String,
        taskId: String,
        parentTaskId: String,
        outputDir: String,
        agentId!: String = "",
        language!: String = "",
        sessionId!: String = "",
        notifyAgentId!: String = ""
    ): SddStageResult {
        // T-12：进度事件在阶段边界各推一次（开始 / 结束），子 agent 派生另推
        // spawn/done。sessionId 为空时（cron 场景常态）只走 WebSocket 广播。
        let events = SddEventBridge()
        events.pushStepStart(
            featureName, sessionId, notifyAgentId, stage,
            SddOrchestrationService.stageIndex(stage), SddOrchestrationService.STAGES.size
        )

        // 主 agent 直执行步（code）：不派单，走"主 agent + 编程技能 + SOP"路径
        if (SddOrchestrationService.isHostDirectStage(stage)) {
            return this.runHostDirectStage(
                stage, featureName, question, userId, taskId, parentTaskId, outputDir,
                agentId, language, sessionId: sessionId, notifyAgentId: notifyAgentId
            )
        }

        let agentName = SddOrchestrationService.subAgentForStage(stage)
        if (agentName.isEmpty()) {
            let msg = "unknown sdd stage '${stage}': no sub-agent mapping"
            LogUtils.error("[SddOrchestration] ${msg}")
            return SddStageResult(stage, "", false, "", msg, 0)
        }

        // agentId 留空 → 派发层按 skill_name + agentName 解析 agents 表
        let req = SubAgentDispatchRequest(
            "",
            SddOrchestrationService.SKILL_NAME,
            agentName,
            question,
            userId,
            parentTaskId,
            taskId,
            "",      // inputFiles
            outputDir,
            "",      // languageContext
            "",      // modelOverride
            ""       // background
        )

        events.pushSubagentSpawn(featureName, sessionId, notifyAgentId, stage, agentName)
        let r = this.dispatcher.dispatch(req)
        events.pushSubagentDone(featureName, sessionId, notifyAgentId, stage, agentName, r.success, r.durationMs)

        var artifactPath = ""
        if (r.success) {
            // 产物落盘 + 入库。登记失败**不翻转本步成功**（编排主链路是子 agent 执行，
            // 产物登记属留痕），仅告警并让 artifactPath 留空，便于下游识别"无上游产物"。
            artifactPath = this.persistArtifact(stage, featureName, r.output, userId, taskId, outputDir)

            let adv = this.projectsService.advanceStage(featureName, stage, "running", userId)
            if (!adv.success) {
                let why = match (adv.reason) {
                    case Some(v) => v
                    case None => "unknown"
                }
                LogUtils.error("[SddOrchestration] advanceStage 失败 feature='${featureName}' stage='${stage}': ${why}")
            }
        } else {
            // 子 agent 缺失 / 执行失败：立即失败，禁止静默降级
            LogUtils.error("[SddOrchestration] stage '${stage}' 派单失败（不降级）: ${r.error}")
        }

        let result = SddStageResult(
            stage, agentName, r.success, r.output, r.error, r.durationMs, artifactPath: artifactPath
        )
        emitStageEnd(events, result, featureName, sessionId, notifyAgentId)
        result
    }

    /**
     * 阶段终态事件：完成带产物路径与耗时，失败带原因。
     *
     * 抽成方法是因为两条路径（派生 / 直执行）都要发，且**必须在返回前发**——
     * 前端靠 step_complete 决定要不要刷新产物列表。
     */
    private func emitStageEnd(
        events: SddEventBridge,
        result: SddStageResult,
        featureName: String,
        sessionId: String,
        notifyAgentId: String
    ): Unit {
        let idx = SddOrchestrationService.stageIndex(result.stage)
        let total = SddOrchestrationService.STAGES.size
        if (result.success) {
            events.pushStepComplete(
                featureName, sessionId, notifyAgentId, result.stage, idx, total,
                result.artifactPath, result.durationMs
            )
        } else {
            let why = if (result.error.isEmpty()) { "unknown" } else { result.error }
            events.pushStepFailed(featureName, sessionId, notifyAgentId, result.stage, why)
        }
    }

    /// 阶段序号（从 1 开始）；未知阶段返回 0
    public static func stageIndex(stage: String): Int64 {
        var i: Int64 = 0
        for (s in SddOrchestrationService.STAGES) {
            i = i + 1
            if (s == stage) {
                return i
            }
        }
        0
    }

    /**
     * 主 agent 直执行阶段（当前仅 `code`）：加载主 agent → 校验编程技能挂载 → 按 SOP 执行。
     *
     * 与派生路径的三点差异（对齐 COMPOSITION.yaml code 步 acceptance_criteria）：
     *   1. 不查 agents 表子 agent、**不写 sub_agent_invocations**；
     *   2. 执行者是**主 agent 自己**（agentId 指向的 agent 定义），不是子 agent 实例；
     *   3. 编程技能必须命中 `codingSkillChain` 之一，全不命中即显式失败
     *      （铁律：查不到确定依据须标注缺口请人工确认，禁止静默猜写）。
     *
     * @param agentId 主 agent 定义 id —— **必填**。没有主 agent 上下文就谈不上"主 agent 执行"，
     *                此处不兜底造 agent（T-15 红线：禁静默降级）。
     */
    public func runHostDirectStage(
        stage: String,
        featureName: String,
        question: String,
        userId: String,
        taskId: String,
        parentTaskId: String,
        outputDir: String,
        agentId: String,
        language: String,
        sessionId!: String = "",
        notifyAgentId!: String = ""
    ): SddStageResult {
        let startMs = SddOrchestrationService.nowMillis()
        if (agentId.isEmpty()) {
            let msg = "stage '${stage}' 由主 agent 直执行，但未提供 agent_id（请在请求体或调度 parameters 中带上主 agent id）"
            LogUtils.error("[SddOrchestration] ${msg}")
            return emitAndReturn(stage, "main-agent", false, "", msg, 0, "", featureName, sessionId, notifyAgentId)
        }

        // 1) 造主 agent（与派生路径同一个 bridge，保证技能 / 工具 / 记忆口径一致）
        let loaded = AgentRuntimeBridge.instance.loadFromDatabase(agentId, userId: userId)
        if (!loaded.success || loaded.data.isNone()) {
            let why = match (loaded.reason) {
                case Some(v) => v
                case None => "unknown"
            }
            let msg = "主 agent 加载失败: agentId='${agentId}': ${why}"
            LogUtils.error("[SddOrchestration] ${msg}")
            return emitAndReturn(stage, "main-agent", false, "", msg, SddOrchestrationService.nowMillis() - startMs, "",
                featureName, sessionId, notifyAgentId)
        }
        let agent = loaded.data.getOrThrow()

        // 2) 编程技能校验：候选链第一个命中即可；全不命中 → 显式失败，不允许无依据编码
        let skillOpt = SddOrchestrationService.resolveCodingSkill(agent, language)
        if (skillOpt.isNone()) {
            let msg = "stage '${stage}': 主 agent 未挂载任何可用编程技能（language='${language}'），"
                + "请先加载对应编程技能（cangjie-coder / web-coder / app-coder；"
                + "过渡期可路由 fullstack-codegen / frontend-dev，但必须在回传中写明）"
            LogUtils.error("[SddOrchestration] ${msg}")
            return emitAndReturn(stage, "main-agent", false, "", msg, SddOrchestrationService.nowMillis() - startMs, "",
                featureName, sessionId, notifyAgentId)
        }
        let codingSkill = skillOpt.getOrThrow()

        // 3) 执行：主 agent 自己跑一轮（ReactExecutor 多步工具调用：读技能 / 读文件 / 写代码）
        let prompt = SddOrchestrationService.buildHostDirectPrompt(
            stage, featureName, question, codingSkill, language, outputDir
        )
        var output = ""
        var error = ""
        var ok = false
        try {
            let resp = agent.chat(AgentRequest(prompt))
            output = resp.content
            ok = resp.status == AgentResponseStatus.Success
            if (!ok) {
                error = "主 agent 执行未成功: status=${resp.status}"
            }
        } catch (e: Exception) {
            error = "主 agent 执行异常: ${e.message}"
            LogUtils.error("[SddOrchestration] ${error}")
        }
        let durationMs = SddOrchestrationService.nowMillis() - startMs

        // 4) 产物落盘 + 推进阶段（与派生路径同口径：登记失败不翻转本步成功）
        var artifactPath = ""
        if (ok) {
            artifactPath = this.persistArtifact(stage, featureName, output, userId, taskId, outputDir)
            let adv = this.projectsService.advanceStage(featureName, stage, "running", userId)
            if (!adv.success) {
                let why = match (adv.reason) {
                    case Some(v) => v
                    case None => "unknown"
                }
                LogUtils.error("[SddOrchestration] advanceStage 失败 feature='${featureName}' stage='${stage}': ${why}")
            }
        } else {
            LogUtils.error("[SddOrchestration] stage '${stage}' 主 agent 直执行失败（不降级）: ${error}")
        }

        return emitAndReturn(stage, "main-agent", ok, output, error, durationMs, artifactPath,
            featureName, sessionId, notifyAgentId)
    }

    /**
     * 构造阶段结果 + 发终态事件 + 返回。
     *
     * 直执行路径有多个提前 return（缺 agent_id / 加载失败 / 技能未挂载），
     * 若不在每个出口发事件，前端会永远停在 `sdd_step_start` 上——
     * 故统一走这一个出口函数。
     */
    private func emitAndReturn(
        stage: String,
        agentName: String,
        success: Bool,
        output: String,
        error: String,
        durationMs: Int64,
        artifactPath: String,
        featureName: String,
        sessionId: String,
        notifyAgentId: String
    ): SddStageResult {
        let result = SddStageResult(stage, agentName, success, output, error, durationMs, artifactPath: artifactPath)
        emitStageEnd(SddEventBridge(), result, featureName, sessionId, notifyAgentId)
        result
    }

    /**
     * 在主 agent 的技能管理器里按候选链找第一个**已挂载**的编程技能。
     *
     * 非 `SkillAwareAgent`（没有 SkillManager）时返回 None —— 无法校验挂载情况，
     * 按铁律不得当作"技能已就绪"，由调用方显式失败。
     */
    private static func resolveCodingSkill(agent: BaseAgent, language: String): Option<String> {
        let saOpt = agent as SkillAwareAgent
        if (saOpt.isNone()) {
            return None<String>
        }
        let sa = saOpt.getOrThrow()
        for (name in SddOrchestrationService.codingSkillChain(language)) {
            if (sa.skillManager.getSkill(name).isSome()) {
                return Some(name)
            }
        }
        None<String>
    }

    /**
     * 直执行阶段的上下文包：把"不派生 / 用哪个技能 / SOP 铁律 / 回传契约"全部写进 question。
     *
     * 主 agent 是通用执行者，它不知道 SDD 的编码规约——这些约束只能靠 prompt 传，
     * 与派生子 agent 时"约束写在声明文件里"是同一个信息，只是载体不同。
     */
    private static func buildHostDirectPrompt(
        stage: String,
        featureName: String,
        question: String,
        codingSkill: String,
        language: String,
        outputDir: String
    ): String {
        let dir = if (outputDir.isEmpty()) { "specs/${featureName}/（runtime 工作目录下）" } else { outputDir }
        let head = "[SDD 主 agent 直执行阶段：${stage}] 工程：${featureName}；产物目录：${dir}。"
        let mode = " 本步**不派生子 agent**：由你（主 agent）加载编程技能后按其 SOP 执行。"
        let skillLine = " 已为你定位的编程技能：${codingSkill}（语言标签 '${language}'；"
            + "若走过渡期路由必须在回传中写明，禁止静默 fallback）。"
        let sop = " SOP 铁律：(1) 先查依据再写代码——工程内既有 import 先例 / 同类实现 / 调用范式，"
            + "加上技术栈官方文档技能确认 API 契约；"
            + "(2) 复制粘贴 + 二次编辑——定位既有正确代码 → 复制 → 最小适配，"
            + "禁止从零凭空生成、禁止凭跨语言经验臆造 API；"
            + "(3) 查不到依据必须显式标注缺口并请人工确认，禁止静默猜写；"
            + "(4) 不编译——cjpm build 与日志回传由人工在独立 cmd 完成；"
            + "(5) 改动只落在目标工程目录内，SDD 阶段文档仍落 specs/${featureName}/。"
        let ret = " 回传 JSON：{\"changed_files\": [...], \"verify_passed\": true|false, "
            + "\"language\": \"cangjie|web|app\", \"skill_used\": \"${codingSkill}\"}；"
            + "verify_passed=false 时须附失败项清单。"
        head + mode + skillLine + sop + ret + "\n\n[本阶段任务]\n" + question
    }

    /**
     * 阶段上下文包（**两条执行路径共用**，异步 crontab 与同步 run-stage 都走这里）。
     *
     * 原本只有异步 `SddOrchestrationExecutor.buildQuestion` 有这份逻辑，同步
     * `run-stage` 直接把请求体里的 question 原样丢给子 agent——用户指定阶段跑 code
     * 时必须自己把 tasks.md 内容粘进 question，与"框架显式交接上游产物"的红线自相
     * 矛盾。抽到服务层后两条路径口径一致：question 可空，上游产物由框架读。
     *
     * @param base 调用方自带的补充说明（可空；为空时给一句通用引导）
     */
    public func buildStageQuestion(
        base: String,
        featureName: String,
        stage: String,
        outputDir: String
    ): String {
        let idx = SddOrchestrationService.stageIndex(stage)
        let head = if (base.isEmpty()) { "请执行 SDD 六步编排中的本阶段工作。" } else { base }
        var tail = "\n\n[SDD 编排] 当前阶段：${stage}（第 ${idx}/6 步）；工程：${featureName}。"
        if (!outputDir.isEmpty()) {
            tail = tail + " 产物目录：${outputDir}。"
        } else {
            tail = tail + " 产物目录：specs/${featureName}/ 下（runtime 工作目录）。"
        }
        tail = tail + " 请把本阶段产物写入该目录。"

        // 上游产物：显式读取，读不到就明确说"没有"，避免子 agent 瞎猜
        var upstreamBlock = ""
        let upstream = SddOrchestrationService.previousStage(stage)
        if (!upstream.isEmpty()) {
            match (this.readStageArtifact(featureName, upstream, outputDir)) {
                case Some(body) =>
                    upstreamBlock = "\n\n[上游阶段产物 ${upstream}]\n${body}"
                case None =>
                    upstreamBlock = "\n\n[上游阶段产物 ${upstream}] 未找到（上游可能未产出，请按本阶段模板自行补齐前提）"
            }
        }
        head + tail + upstreamBlock
    }

    private static func nowMillis(): Int64 {
        (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    }

    // ── 闸口（T-11 / REQ-SDD-008）─────────────────────────────────

    /**
     * 阶段 → 闸口名（对齐 skills/sdd/SKILL.md 的 decision-points）。
     *
     * 五个闸口：spec / design / task / code / test 各一步之后。research 后不设闸口
     * （研究是可选步，且结论要由 spec 步复核，单独设闸会拖慢节奏）。
     */
    public static func gateForStage(stage: String): String {
        if (stage == "research") { return "" }
        "gate-${stage}"
    }

    /**
     * 应用人在回路的闸口决策（confirm / revise / abandon）。
     *
     * - **confirm**：`current_stage` 停在本步、status 回 running，下次触发会推进到下一步。
     * - **revise**：`current_stage` 退回**上一步**（`previousStage`），于是下次
     *    `nextStage` 仍算出本步 → 重跑本步；同时 `bumpRound` 表示进入新一轮。
     *   重跑用**新 task_id**（由调用方生成后传入），避免子 agent 读到上一轮
     *   `agent_contexts` 里的旧消息（上下文串味是本项目已知坑）。
     *   产物不覆盖：盘上归档 `.prev`、库里 append-only（见 `persistArtifact`）。
     * - **abandon**：置 `abandoned` 并写 `agent_approvals` 留痕（谁、何时、为什么终止）。
     *
     * @return 说明文案（给调用方回给前端）；失败时 reason 说明原因。
     */
    public func applyGateDecision(
        featureName: String,
        stage: String,
        decision: String,
        userId: String,
        comment: String,
        newTaskId!: String = ""
    ): APIResult<String> {
        if (featureName.isEmpty()) {
            return APIResult<String>(false, "applyGateDecision: feature_name 为空")
        }
        if (!SddOrchestrationService.isKnownStage(stage)) {
            return APIResult<String>(false, "applyGateDecision: 未知阶段 '${stage}'")
        }

        if (decision == "confirm") {
            let r = this.projectsService.advanceStage(featureName, stage, "running", userId)
            if (!r.success) {
                return APIResult<String>(false, "confirm 失败: ${SddOrchestrationService.reasonOf(r.reason)}")
            }
            return APIResult<String>("confirmed: stage='${stage}' 已确认，可继续下一步")
        }

        if (decision == "revise") {
            let back = SddOrchestrationService.previousStage(stage)
            let target = if (back.isEmpty()) { "" } else { back }
            // 首阶段（research）没有上一步：用空串让 nextStage 从头开始
            let r = this.projectsService.advanceStage(featureName, target, "running", userId)
            if (!r.success) {
                return APIResult<String>(false, "revise 失败: ${SddOrchestrationService.reasonOf(r.reason)}")
            }
            let rr = this.projectsService.bumpRound(featureName, userId)
            if (!rr.success) {
                LogUtils.warn("[SddOrchestration] revise: bumpRound 失败（不影响回退）: ${SddOrchestrationService.reasonOf(rr.reason)}")
            }
            let tid = if (newTaskId.isEmpty()) { "(未提供新 task_id，请调用方生成后重跑)" } else { newTaskId }
            return APIResult<String>("revised: 已回退重做 stage='${stage}'，新 task_id=${tid}，"
                + "上一版产物归档为 .prev，库里保留 append-only 记录")
        }

        if (decision == "abandon") {
            let r = this.projectsService.advanceStage(featureName, stage, "abandoned", userId)
            if (!r.success) {
                return APIResult<String>(false, "abandon 失败: ${SddOrchestrationService.reasonOf(r.reason)}")
            }
            SddOrchestrationService.recordAbandon(featureName, stage, userId, comment)
            return APIResult<String>("abandoned: 工程已终止于 stage='${stage}'，决策已留痕 agent_approvals")
        }

        APIResult<String>(false, "applyGateDecision: 未知决策 '${decision}'（可选 confirm / revise / abandon）")
    }

    /// abandon 留痕：写 agent_approvals（ADR-001：走 create，不改既有表结构）
    private static func recordAbandon(featureName: String, stage: String, userId: String, comment: String): Unit {
        try {
            let po = AgentApprovalsPO()
            // agent_approvals.agent_id / task_id 是 NOT NULL 的 uuid 列：SDD 闸口没有
            // 对应的 agent/task 实体，按项目口径留空串会触发 22P02，故用 feature_name
            // 占位——留痕的价值在 approval_type + content + status，这两列只是外键位。
            po.agentId = "00000000-0000-0000-0000-000000000000"
            po.taskId = "00000000-0000-0000-0000-000000000000"
            po.approvalType = "sdd-gate-abandon"
            po.content = "feature=${featureName}, stage=${stage}, comment=${comment}"
            po.status = "abandoned"
            po.userResponse = if (comment.isEmpty()) { None<String> } else { Some(comment) }
            let r = AgentApprovalsService().create(po, userId)
            if (!r.success) {
                LogUtils.warn("[SddOrchestration] abandon 留痕失败: ${SddOrchestrationService.reasonOf(r.reason)}")
            }
        } catch (e: Exception) {
            LogUtils.warn("[SddOrchestration] abandon 留痕异常（不影响终止语义）: ${e.message}")
        }
    }

    private static func reasonOf(reason: ?String): String {
        match (reason) {
            case Some(v) => v
            case None => "unknown"
        }
    }

    /// 阶段是否在六步白名单内（闸口与路由共用一处判定）
    public static func isKnownStage(stage: String): Bool {
        for (s in SddOrchestrationService.STAGES) {
            if (s == stage) {
                return true
            }
        }
        false
    }

    /**
     * 异步启动六步编排：建一条 `sdd://<feature_name>` 调度行并注册进调度引擎。
     *
     * HTTP 侧拿到 crontab_id 即可返回，真正的阶段执行在调度线程里推进
     * （每 tick 一步，见 `SddOrchestrationExecutor`），避免子 agent chat 把
     * HTTP 连接拖死。
     *
     * 调度行口径：
     *   - `concurrentable = false`：重叠 tick 由 `SchedulerEngine.triggerTask`
     *     的内存态 `runningTasks` 跳过（进程重启自然清空，无陈旧锁）；
     *   - `once = false`：由执行器在跑完/失败时**自己停表**（引擎摘除 + 库里置 2）；
     *   - cron 六段、无 `?`（Ticktock 口径），每分钟一跳。
     *
     * @param startStage 起始阶段（**可选**）：给了就只跑这一步然后停表，用于
     *                   "前面几步已确认、现在直接接着跑 code"这类跳步续跑；
     *                   不给则按 `sdd_projects.current_stage` 自动推进下一步。
     *                   与异步执行器 `SddParams.stage` 是同一个键，见 `SddOrchestrationExecutor`。
     * @param allowMissingUpstream 指定 startStage 且上游产物缺失时是否放行（默认拦）
     *
     * @return `APIResult<String>` —— data 为新建的 crontab_id
     */
    public func startPipeline(
        featureName: String,
        question: String,
        userId: String,
        taskId: String,
        parentTaskId: String,
        outputDir: String,
        auto: Bool,
        agentId!: String = "",
        language!: String = "",
        sessionId!: String = "",
        notifyAgentId!: String = "",
        startStage!: String = "",
        allowMissingUpstream!: Bool = false
    ): APIResult<String> {
        if (featureName.isEmpty()) {
            return APIResult<String>(false, "startPipeline: feature_name 为空")
        }

        // 显式指定起始阶段 = 跳步执行：先拦"上游产物根本不存在"这种跑空的情况
        if (!startStage.isEmpty()) {
            if (!SddOrchestrationService.isKnownStage(startStage)) {
                return APIResult<String>(false, "startPipeline: 未知阶段 '${startStage}'"
                    + "（可选 research/spec/design/task/code/test）")
            }
            let chk = this.checkUpstream(startStage, featureName, outputDir, allowMissing: allowMissingUpstream)
            if (!chk.success) {
                let why = match (chk.reason) {
                    case Some(v) => v
                    case None => "unknown"
                }
                return APIResult<String>(false, "startPipeline: 跳步校验未通过，未建调度行: ${why}")
            }
        }

        try {
            // 工程必须存在，否则执行器 nextStage 查不到 current_stage 会直接停表
            match (this.projectsService.getByFeatureName(featureName)) {
                case Some(_) => ()
                case None =>
                    let up = this.projectsService.upsertProject(featureName, "", taskId, true, "{}", userId)
                    if (!up.success) {
                        let why = match (up.reason) {
                            case Some(v) => v
                            case None => "unknown"
                        }
                        return APIResult<String>(false, "startPipeline: 建工程失败 feature='${featureName}': ${why}")
                    }
            }

            let params = JsonObject()
            params.put("feature_name", JsonString(featureName))
            params.put("question", JsonString(question))
            params.put("task_id", JsonString(taskId))
            params.put("parent_task_id", JsonString(parentTaskId))
            params.put("output_dir", JsonString(outputDir))
            params.put("user_id", JsonString(userId))
            params.put("auto", JsonBool(auto))
            // 主 agent 直执行步（code）需要这两个：缺 agent_id 时 code 步会显式失败并提示
            params.put("agent_id", JsonString(agentId))
            params.put("language", JsonString(language))
            // T-12：进度事件回推通道（cron 驱动时无 session，事件只走 WebSocket 广播）
            params.put("session_id", JsonString(sessionId))
            params.put("notify_agent_id", JsonString(notifyAgentId))
            // 给了 stage：执行器只跑这一步然后停表（停在哪一步由执行器的
            // "p.stage 非空即停在闸口"分支决定）；不给则按 current_stage 自动推进。
            params.put("stage", JsonString(startStage))
            params.put("allow_missing_upstream", JsonBool(allowMissingUpstream))

            let po = CrontabPO()
            po.name = "sdd-${featureName}"
            po.groupName = "1"
            po.task = "sdd://${featureName}"
            po.cron = "0 * * * * *"
            po.tactics = "1"
            po.remark = "SDD 六步编排（宿主侧异步）"
            po.status = 1
            po.concurrentable = Some<Bool>(false)
            po.once = Some<Bool>(false)
            po.parameters = Some<String>(params.toString())
            if (!userId.isEmpty()) {
                po.creator = Some<String>(userId)
                po.ownerUserId = Some<String>(userId)
            }

            let r = CrontabService().create(po, userId)
            if (!r.success) {
                let why = match (r.reason) {
                    case Some(v) => v
                    case None => "unknown"
                }
                return APIResult<String>(false, "startPipeline: 建调度行失败 feature='${featureName}': ${why}")
            }
            match (r.data) {
                case Some(created) =>
                    let registered = SddScheduleBridge.reloadCrontab(created.id)
                    LogUtils.info("[SddOrchestration] 编排已启动: feature='${featureName}', crontabId=${created.id}, registeredToEngine=${registered}")
                    return APIResult<String>(created.id)
                case None =>
                    return APIResult<String>(false, "startPipeline: 建调度行返回空 data, feature='${featureName}'")
            }
        } catch (e: Exception) {
            return APIResult<String>(false, "startPipeline 异常: ${e.message}")
        }
    }
}
