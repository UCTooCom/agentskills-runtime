/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import std.collection.*
import stdx.encoding.json.*
import json4cj.JsonValueSerializable

public class AgentLoginResult {
    public var accessToken: String = ""
    public var authType: String = "agent_auto"
    public var expiresIn: Int64 = 172800

    public init() {}

    public init(accessToken: String, authType: String, expiresIn: Int64) {
        this.accessToken = accessToken
        this.authType = authType
        this.expiresIn = expiresIn
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("access_token", this.accessToken.toJsonValue())
        map.add("auth_type", this.authType.toJsonValue())
        map.add("expires_in", this.expiresIn.toJsonValue())
        return JsonObject(map)
    }
}