/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

public class LocalMessageRequest {
    public var sessionId: String = ""
    public var senderAgentId: String = ""
    public var senderRole: String = "requester"
    public var taskId: Option<String> = None<String>
    public var dataItems: Option<String> = None<String>
    public var content: Option<String> = None<String>
    public var messageType: String = "aip_interaction"

    public init() {}

    public init(sessionId: String, senderAgentId: String, senderRole: String,
        taskId: Option<String>, dataItems: Option<String>, content: Option<String>,
        messageType: String) {
        this.sessionId = sessionId
        this.senderAgentId = senderAgentId
        this.senderRole = senderRole
        this.taskId = taskId
        this.dataItems = dataItems
        this.content = content
        this.messageType = messageType
    }
}