/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip.model

import std.collection.*

public class LocalSessionRequest {
    public var requesterAgentId: String = ""
    public var receiverAgentIds: ArrayList<String> = ArrayList<String>()
    public var interactionMode: String = "p2p"
    public var context: Option<String> = None<String>

    public init() {}

    public init(requesterAgentId: String, receiverAgentIds: ArrayList<String>,
        interactionMode: String, context: Option<String>) {
        this.requesterAgentId = requesterAgentId
        this.receiverAgentIds = receiverAgentIds
        this.interactionMode = interactionMode
        this.context = context
    }
}