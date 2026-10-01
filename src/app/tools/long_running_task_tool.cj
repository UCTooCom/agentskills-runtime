/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.tools

import magic.core.AgentSessionContext
import magic.core.tool.{ToolParameter, ToolResponse}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.tool.AbsTool
import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import magic.app.services.lrt.LongTaskApiService

/**
 * 长程任务专用工具：把"调用 long-running-task 工具"这条自然语言指令真正接到 LRT 子系统。
 *
 * 背景：此前 long-running-task 技能被 SkillToToolAdapter 包成工具，但其 BaseSkill.execute()
 * 只返回占位串 "Skill ... executed"，导致 agent 调用该工具后"以为跑完了，实则什么都没发生"（死路）。
 * 本工具直接调用 LongTaskApiService.submitTask（与 WebMCP 前缀路由 handleLongRunningTaskRoute
 * 同一调用），让 AGENTS.md 中"调用 long-running-task 工具"的自然语言指令真正生效。
 *
 * 放在 magic.app.tools：它要调用 magic.app.services.lrt.LongTaskApiService，同属 magic.app 子树，
 * 不会引入跨包循环依赖（magic.app 已是依赖树的较高层）。
 *
 * 继承 magic.tool.AbsTool（而非直接实现 Tool 接口）：Tool 接口除 invoke 外还要求 extra 属性与
 * toJsonValue()（因为 Tool <: ToJsonValue），AbsTool 已提供二者的标准实现（extra 空表 + 完整
 * JSON schema 序列化），与工程内 HttpTool / WebFetchTool / SkillSearchTool 等工具同一口径。
 * magic.app 本就依赖 magic.tool（main.cj / ToolRoutes.cj 等 11 处），而 magic.tool 不反向依赖
 * magic.app 或 magic.skill，故不会形成包循环。
 */
public class LongRunningTaskTool <: AbsTool {
    private let _ctx: AgentSessionContext
    private static let NAME: String = "long-running-task"

    public init(sessionContext!: AgentSessionContext) {
        super()
        _ctx = sessionContext
        // 与内置工具同款口径：可被过滤、不终止 agent 执行、结果可压缩。
        // 注意 terminal 若置 "true" 会立刻 stop agent 执行（agent_task.cj:431 消费该字段），
        // 仅 answer 工具这么用；此处保持 false，提交后由模型继续向用户复述提交结果。
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { LongRunningTaskTool.NAME }
    }

    public prop description: String {
        get() {
            "提交一个长程任务：把复杂、多步骤、需要长时间运行的目标交给长程任务子系统进行规划并后台执行。" +
            "当用户需求复杂、需要多轮工具调用或耗时较长时使用。参数 query 为要完成的任务的自然语言描述。"
        }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter(
                    "query",
                    "要完成的复杂目标的自然语言描述，例如：查找去年高考物理题并解题。",
                    TypeSchema.Str
                )
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() { [] }
    }

    public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let goal = _extractString(args, "query").trimAscii()
        if (goal.isEmpty()) {
            return ToolResponse("长程任务目标不能为空，请提供要完成的任务描述。", isError: true)
        }

        try {
            let service = LongTaskApiService()
            let result = service.submitTask(
                goal,
                _ctx.agentId,
                None<Int32>,
                None<String>,
                ArrayList<String>(),
                _ctx.userId,
                _ctx.sessionId,
                ""
            )

            if (result.success) {
                let outText = match (result.data) {
                    case Some(d) =>
                        let taskId = _readJsonString(d, "taskId")
                        let crontabId = _readJsonString(d, "crontabId")
                        "已提交长程任务。\n任务 ID：${taskId}\n调度 ID：${crontabId}\n" +
                            "系统已完成目标解析与规划，并立即触发首回合；后续回合由调度器按周期续跑。"
                    case None => "已提交长程任务。"
                }
                return ToolResponse(outText, isError: false)
            } else {
                let reason = match (result.reason) {
                    case Some(r) => r
                    case None => "未知原因"
                }
                return ToolResponse("长程任务创建失败：${reason}", isError: true)
            }
        } catch (e: Exception) {
            LogUtils.error("[LongRunningTaskTool] submitTask 异常: ${e.message}")
            return ToolResponse("长程任务创建失败：${e.message}", isError: true)
        }
    }

    private func _extractString(args: HashMap<String, JsonValue>, key: String): String {
        match (args.get(key)) {
            case Some(v) =>
                if (v is JsonString) {
                    return v.asString().getValue()
                }
                return v.toString()
            case None => return ""
        }
    }

    private func _readJsonString(obj: JsonObject, key: String): String {
        match (obj.get(key)) {
            case Some(v) =>
                if (v is JsonString) {
                    return v.asString().getValue()
                }
                return ""
            case None => return ""
        }
    }
}
