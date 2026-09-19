/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.compactor

import magic.core.tool.{ToolRequest, ToolResponse, ToolCompactor}
import magic.core.model.{ChatModel, ChatRequest}
import magic.core.message.{Message, MessageList}
import magic.prompt.Template
import magic.log.LogUtils

/**
 * Compact the tool invocation
 */
public class SimpleToolCompactor <: ToolCompactor {
    private let name = "Simple Tool Compactor"
    private let model: ChatModel
    /// 提示词 profile（由调用方传入，通常是 agent.name）。用于命中
    /// `<promptsDir>/tool-summarize.user.<profile>.md` 这一"按任务类型定制摘要提示词"
    /// 的覆盖文件，见 PromptConfig。空串表示只用全局/内置默认。
    private let profile: String

    public SimpleToolCompactor(model: ChatModel, profile!: String = "") {
        this.model = model
        this.profile = profile
    }

    /**
    * This agent attempts to summarize the tool execution results into concise and structured summaries.
    **/
    override public func compact(toolRequest: ToolRequest, toolResponse: ToolResponse): String {
        LogUtils.info(this.name, "Start to summarize tool result (profile=${this.profile})")
        let summary = this.model.create(
            ChatRequest([
                Message.system(PromptConfig.resolveToolSummarizeSystem()),
                Message.user(PromptConfig.resolveToolSummarizeUser(this.profile).format([
                    ("tool_call", toolRequest.toJsonValue().toJsonString()),
                    ("tool_result", toolResponse.content)
                ]))
            ])
        ).message.content
        LogUtils.debug(
            this.name,
            String.join(
                [
                    "#Bytes of tool result: ${toolResponse.content.size} => ${summary.size}",
                    "--------------------------------------",
                    "Summary:", summary
                ],
                delimiter: "\n"
            )
        )
        return summary
    }
}