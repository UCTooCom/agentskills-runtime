/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal

import std.collection.ArrayList

/**
 * 附件解析完成事件（契约 IF-07a）。
 *
 * 由 host-attach-core 在调度完成后发布，幂等键为 `messageId`；下游 `attachment-persistence`
 * 据此落库元数据，`web-multimodal` 据此做留痕呈现。
 */
public class AttachmentParsed {
    public let sessionId: String
    public let messageId: String
    public let attachmentCount: Int64
    public let parseSummary: String
    public let attachments: ArrayList<AttachmentMeta>
    public init(sessionId: String, messageId: String, attachmentCount: Int64,
                parseSummary: String, attachments: ArrayList<AttachmentMeta>) {
        this.sessionId = sessionId
        this.messageId = messageId
        this.attachmentCount = attachmentCount
        this.parseSummary = parseSummary
        this.attachments = attachments
    }
}

/**
 * 进程内轻量事件总线（模式同 `ChannelEventBus`）：发布方不依赖订阅方具体实现。
 * 订阅者异常被吞掉，不影响发布方主流程。
 */
public class AttachmentParsedEventBus {
    private static let INSTANCE = AttachmentParsedEventBus()
    private var listeners: ArrayList<(AttachmentParsed) -> Unit> = ArrayList<(AttachmentParsed) -> Unit>()

    public static func shared(): AttachmentParsedEventBus {
        INSTANCE
    }

    public func subscribe(listener: (AttachmentParsed) -> Unit): Unit {
        this.listeners.add(listener)
    }

    public func publish(event: AttachmentParsed): Unit {
        for (l in this.listeners) {
            try {
                l(event)
            } catch (_: Exception) {
                // 订阅者异常不影响发布方
            }
        }
    }
}
