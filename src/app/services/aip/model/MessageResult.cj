/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import std.collection.*
import stdx.encoding.json.*
import json4cj.JsonValueSerializable

public class MessageResult {
    public var messageId: String = ""
    public var sessionId: String = ""
    public var senderRole: String = ""
    public var createdAt: String = ""

    public init() {}

    public init(messageId: String, sessionId: String, senderRole: String, createdAt: String) {
        this.messageId = messageId
        this.sessionId = sessionId
        this.senderRole = senderRole
        this.createdAt = createdAt
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("message_id", this.messageId.toJsonValue())
        map.add("session_id", this.sessionId.toJsonValue())
        map.add("sender_role", this.senderRole.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
        return JsonObject(map)
    }
}