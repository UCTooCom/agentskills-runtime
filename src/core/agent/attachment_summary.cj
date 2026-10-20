/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.core.agent

/**
 * 一轮请求中全部附件的解析摘要（宿主侧生成，随 `AgentRequest` 透传给持久化层）。
 *
 * 刻意只持有「可序列化字段 + 已序列化的附件元数据 JSON」，不引用 `magic.plugin.multimodal`
 * 的任何类型，以避免 `core` → `plugin` 的反向依赖（会成环）。附件元数据的 JSON 由
 * WebMCPProtocol 在调度完成后从 `AttachmentMeta` 列表拼出。
 *
 * - `messageId`：本轮宿主生成的消息标识（与 `AttachmentParsed` 事件同源）；
 * - `attachmentsJson`：附件元数据数组的 JSON 字符串，直接落 `agent_messages.attachments` 列。
 */
public class AttachmentSummary {
    public let messageId: String
    public let sessionId: String
    public let attachmentCount: Int64
    public let parseSummary: String
    public let attachmentsJson: String

    public init(messageId: String, sessionId: String, attachmentCount: Int64,
                parseSummary: String, attachmentsJson: String) {
        this.messageId = messageId
        this.sessionId = sessionId
        this.attachmentCount = attachmentCount
        this.parseSummary = parseSummary
        this.attachmentsJson = attachmentsJson
    }

    public static func empty(): AttachmentSummary {
        AttachmentSummary("", "", 0, "", "[]")
    }
}
