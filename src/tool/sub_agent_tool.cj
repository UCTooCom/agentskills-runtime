/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.*
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt}
import std.time.DateTime
import std.core.Duration

public struct SubAgentTiming {
    public let startTime: Int64
    public let endTime: Int64
    public let durationMs: Int64

    public init(startTime: Int64, endTime: Int64, durationMs: Int64) {
        this.startTime = startTime
        this.endTime = endTime
        this.durationMs = durationMs
    }
}

/// 子 agent 派单请求。
/// 真派生（查 agents 表 → 造 Agent → AgentAsTool → chat）由宿主侧服务实现并经 DI 注入，
/// 以避免 magic.tool 反向依赖 magic.app.services 触发包循环依赖（项目铁律）。
public struct SubAgentDispatchRequest {
    public let agentId: String
    public let skillName: String
    public let agentName: String
    public let question: String
    public let userId: String
    public let parentTaskId: String
    public let taskId: String
    public let inputFiles: String
    public let outputDir: String
    public let languageContext: String
    public let modelOverride: String
    public let background: String

    public init(
        agentId: String,
        skillName: String,
        agentName: String,
        question: String,
        userId: String,
        parentTaskId: String,
        taskId: String,
        inputFiles: String,
        outputDir: String,
        languageContext: String,
        modelOverride: String,
        background: String
    ) {
        this.agentId = agentId
        this.skillName = skillName
        this.agentName = agentName
        this.question = question
        this.userId = userId
        this.parentTaskId = parentTaskId
        this.taskId = taskId
        this.inputFiles = inputFiles
        this.outputDir = outputDir
        this.languageContext = languageContext
        this.modelOverride = modelOverride
        this.background = background
    }
}

/// 子 agent 派单结果。
public struct SubAgentDispatchResult {
    public let success: Bool
    public let output: String
    public let error: String
    public let durationMs: Int64

    public init(success: Bool, output: String, error: String, durationMs: Int64) {
        this.success = success
        this.output = output
        this.error = error
        this.durationMs = durationMs
    }
}

/// 子 agent 派发接口：真派生由宿主侧 SubAgentDispatchServiceImpl 实现并经 DI 注入。
public interface SubAgentDispatcher {
    func dispatch(req: SubAgentDispatchRequest): SubAgentDispatchResult
}

public class SubAgentTool <: NativeFuncTool {
    public static let NAME = "sub_agent_execute"

    public static let DESC = """
    Execute a sub-agent task with timing and transcript collection.
    Supports skill path, input files, and output directory parameters.
    """

    // 派发实现槽：由宿主侧组合根（AgentRuntimeBridge.init）注入；magic.tool 不自依赖宿主服务。
    private static var dispatcher: Option<SubAgentDispatcher> = None<SubAgentDispatcher>

    public static func setDispatcher(d: SubAgentDispatcher): Unit {
        dispatcher = Some(d)
        LogUtils.info("[SubAgentTool] dispatcher injected")
    }

    public init() {
        super(
            name: SubAgentTool.NAME,
            description: SubAgentTool.DESC,
            parameters: [
                ("skill_path", "Path to the skill directory to load (optional)", TypeSchema.Str),
                ("question", "Question or task for the sub-agent", TypeSchema.Str),
                ("input_files", "Array of input file paths (optional)", TypeSchema.Str),
                ("output_dir", "Output directory path (optional)", TypeSchema.Str),
                ("language_context", "Language-specific context to inject into system prompt (optional)", TypeSchema.Str),
                ("subagent_type", "Type/name of sub-agent to select (optional)", TypeSchema.Str),
                ("model_override", "Model name to override default model (optional)", TypeSchema.Str),
                ("background", "Execute asynchronously and return task_id (optional, true/false)", TypeSchema.Str),
                ("task_id", "Task ID for progress tracking (optional)", TypeSchema.Str),
                ("agent_id", "Target agent DB id; if set, dispatch by id instead of by name (optional)", TypeSchema.Str),
                ("user_id", "Calling user id, used as creator and session user (optional)", TypeSchema.Str),
                ("parent_task_id", "Parent engineering task id for grouping invocations (optional)", TypeSchema.Str)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "skill_path": "./skills/sdd",
                  "question": "Process the input data",
                  "input_files": "[\"./data/input.txt\"]",
                  "output_dir": "./output",
                  "language_context": "Cangjie language guide...",
                  "subagent_type": "code-editor",
                  "model_override": "deepseek-coder",
                  "background": "false",
                  "task_id": "",
                  "agent_id": "",
                  "user_id": "",
                  "parent_task_id": ""
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                SubAgentTool.execute(args)
            }
        )
    }

    public static func execute(args: HashMap<String, JsonValue>): String {
        let skillPath = extractString(args, "skill_path")
        let question = extractString(args, "question")
        let inputFiles = extractString(args, "input_files")
        let outputDir = extractString(args, "output_dir")
        let languageContext = extractString(args, "language_context")
        let subagentType = extractString(args, "subagent_type")
        let modelOverride = extractString(args, "model_override")
        let background = extractString(args, "background")
        let taskId = extractString(args, "task_id")
        let agentId = extractString(args, "agent_id")
        let userId = extractString(args, "user_id")
        let parentTaskId = extractString(args, "parent_task_id")
        let skillName = skillNameFromPath(skillPath)

        if (question.isEmpty()) {
            return buildErrorResponse("question is required")
        }

        let startTime = DateTime.now()
        var transcript = "SubAgent Execution Log\n====================\n"
        if (!skillPath.isEmpty()) {
            transcript = transcript + "Skill: ${skillPath}\n"
        }
        transcript = transcript + "Question: ${question}\n"
        if (!inputFiles.isEmpty()) {
            transcript = transcript + "Input Files: ${inputFiles}\n"
        }
        if (!outputDir.isEmpty()) {
            transcript = transcript + "Output Dir: ${outputDir}\n"
        }
        if (!languageContext.isEmpty()) {
            transcript = transcript + "Language Context: injected (${languageContext.size.toString()} chars)\n"
        }
        if (!subagentType.isEmpty()) {
            transcript = transcript + "SubAgent Type: ${subagentType}\n"
        }
        if (!modelOverride.isEmpty()) {
            transcript = transcript + "Model Override: ${modelOverride}\n"
        }
        if (!agentId.isEmpty()) {
            transcript = transcript + "Agent ID: ${agentId}\n"
        }
        if (!userId.isEmpty()) {
            transcript = transcript + "User ID: ${userId}\n"
        }
        if (!parentTaskId.isEmpty()) {
            transcript = transcript + "Parent Task ID: ${parentTaskId}\n"
        }
        if (background == "true") {
            transcript = transcript + "Background: async execution\n"
        }
        if (!taskId.isEmpty()) {
            transcript = transcript + "Task ID: ${taskId}\n"
        }

        LogUtils.info("[SubAgentTool] Executing question: ${question}")

        let req = SubAgentDispatchRequest(
            agentId,
            skillName,
            subagentType,
            question,
            userId,
            parentTaskId,
            taskId,
            inputFiles,
            outputDir,
            languageContext,
            modelOverride,
            background
        )

        var result = SubAgentDispatchResult(false, "", "SubAgentTool dispatcher not configured", 0)
        if (let Some(d) <- dispatcher) {
            result = d.dispatch(req)
        }

        let endTime = DateTime.now()
        let startMs = (startTime - DateTime.UnixEpoch).toMilliseconds()
        let endMs = (endTime - DateTime.UnixEpoch).toMilliseconds()
        let timing = SubAgentTiming(startMs, endMs, result.durationMs)

        if (result.success) {
            return buildSuccessResponse(result.output, timing, transcript, languageContext: languageContext, subagentType: subagentType, modelOverride: modelOverride, background: background, taskId: taskId)
        } else {
            transcript = transcript + "\nError: ${result.error}\n"
            return buildErrorResponse(result.error, timing: timing, transcript: transcript)
        }
    }

    private static func skillNameFromPath(skillPath: String): String {
        if (skillPath.isEmpty()) {
            return ""
        }
        let normalized = if (skillPath.endsWith("/")) { skillPath[0..(skillPath.size - 1)] } else { skillPath }
        let parts = normalized.split("/")
        var name = ""
        for (p in parts) {
            if (!p.isEmpty() && p != "." && p != "..") {
                name = p
            }
        }
        return name
    }

    private static func buildSuccessResponse(output: String, timing: SubAgentTiming, transcript: String, languageContext!: String = "", subagentType!: String = "", modelOverride!: String = "", background!: String = "", taskId!: String = ""): String {
        let response = JsonObject()
        response.put("success", JsonBool(true))
        response.put("output", JsonString(output))
        
        let timingObj = JsonObject()
        timingObj.put("start_time", JsonInt(timing.startTime))
        timingObj.put("end_time", JsonInt(timing.endTime))
        timingObj.put("duration_ms", JsonInt(timing.durationMs))
        response.put("timing", timingObj)
        
        response.put("transcript", JsonString(transcript))

        if (!languageContext.isEmpty()) {
            response.put("language_context_injected", JsonBool(true))
        }
        if (!subagentType.isEmpty()) {
            response.put("subagent_type", JsonString(subagentType))
        }
        if (!modelOverride.isEmpty()) {
            response.put("model_override", JsonString(modelOverride))
        }
        if (background == "true") {
            response.put("background", JsonBool(true))
        }
        if (!taskId.isEmpty()) {
            response.put("task_id", JsonString(taskId))
        }
        
        return response.toJsonString()
    }

    private static func buildErrorResponse(error: String, timing!: SubAgentTiming = SubAgentTiming(0, 0, 0), transcript!: String = ""): String {
        let response = JsonObject()
        response.put("success", JsonBool(false))
        response.put("error", JsonString(error))
        
        let timingObj = JsonObject()
        timingObj.put("start_time", JsonInt(timing.startTime))
        timingObj.put("end_time", JsonInt(timing.endTime))
        timingObj.put("duration_ms", JsonInt(timing.durationMs))
        response.put("timing", timingObj)
        
        if (!transcript.isEmpty()) {
            response.put("transcript", JsonString(transcript))
        }
        
        return response.toJsonString()
    }

    protected static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }
}
