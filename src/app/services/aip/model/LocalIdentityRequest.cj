/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import stdx.encoding.json.*

public class LocalIdentityRequest {
    public var name: String = ""
    public var agentType: String = "sub"
    public var description: Option<String> = None<String>
    public var model: Option<String> = None<String>
    public var systemPrompt: Option<String> = None<String>
    public var creatorId: String = ""

    public init() {}

    public init(name: String, agentType: String, description: Option<String>,
        model: Option<String>, systemPrompt: Option<String>, creatorId: String) {
        this.name = name
        this.agentType = agentType
        this.description = description
        this.model = model
        this.systemPrompt = systemPrompt
        this.creatorId = creatorId
    }
}