/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import std.collection.*
import stdx.encoding.json.*
import json4cj.JsonValueSerializable

public class LocalIdentityResult {
    public var agentId: String = ""
    public var userId: String = ""
    public var identityStatus: String = "none"
    public var createdAt: String = ""

    public init() {}

    public init(agentId: String, userId: String, identityStatus: String, createdAt: String) {
        this.agentId = agentId
        this.userId = userId
        this.identityStatus = identityStatus
        this.createdAt = createdAt
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("user_id", this.userId.toJsonValue())
        map.add("identity_status", this.identityStatus.toJsonValue())
        map.add("created_at", this.createdAt.toJsonValue())
        return JsonObject(map)
    }
}