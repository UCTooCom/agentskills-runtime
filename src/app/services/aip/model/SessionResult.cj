/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import std.collection.*
import stdx.encoding.json.*
import json4cj.JsonValueSerializable

public class SessionResult {
    public var sessionId: String = ""
    public var requesterAgentId: String = ""
    public var receiverAgentIds: ArrayList<String> = ArrayList<String>()
    public var interactionMode: String = "p2p"
    public var sessionStatus: String = "active"
    public var createdAt: String = ""

    public init() {}

    public init(sessionId: String, requesterAgentId: String, receiverAgentIds: ArrayList<String>,
        interactionMode: String, sessionStatus: String, createdAt: String) {
        this.sessionId = sessionId
        this.requesterAgentId = requesterAgentId
        this.receiverAgentIds = receiverAgentIds
        this.interactionMode = interactionMode
        this.sessionStatus = sessionStatus
        this.createdAt = createdAt
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("session_id", this.sessionId.toJsonValue())
        map.add("requester_agent_id", this.requesterAgentId.toJsonValue())
        var arr = JsonArray()
        for (id in this.receiverAgentIds) {
            arr.add(id.toJsonValue())
        }
        map.add("receiver_agent_ids", arr)
        map.add("interaction_mode", this.interactionMode.toJsonValue())
        map.add("session_status", this.sessionStatus.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
        return JsonObject(map)
    }
}