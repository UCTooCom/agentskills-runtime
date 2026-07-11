/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import std.collection.*
import stdx.encoding.json.*
import json4cj.JsonValueSerializable

public class IdentityInfo {
    public var agentId: String = ""
    public var userId: String = ""
    public var userType: String = "agent"
    public var identityStatus: String = "none"
    public var aic: Option<String> = None<String>
    public var aipRegisteredAt: Option<String> = None<String>

    public init() {}

    public init(agentId: String, userId: String, userType: String,
        identityStatus: String, aic: Option<String>, aipRegisteredAt: Option<String>) {
        this.agentId = agentId
        this.userId = userId
        this.userType = userType
        this.identityStatus = identityStatus
        this.aic = aic
        this.aipRegisteredAt = aipRegisteredAt
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("agent_id", this.agentId.toJsonValue())
        map.add("user_id", this.userId.toJsonValue())
        map.add("user_type", this.userType.toJsonValue())
        map.add("identity_status", this.identityStatus.toJsonValue())
        map.add("aic", optionToJsonValue(this.aic))
        map.add("aip_registered_at", optionToJsonValue(this.aipRegisteredAt))
        return JsonObject(map)
    }

    private static func optionToJsonValue<T>(opt: Option<T>): JsonValue where T <: JsonValueSerializable<T> {
        if (let Some(v) <- opt) {
            return v.toJsonValue()
        } else {
            return JsonNull()
        }
    }
}