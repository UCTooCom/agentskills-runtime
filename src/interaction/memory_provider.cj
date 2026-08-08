/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.ArrayList
import stdx.encoding.json.JsonValue

public interface MemoryProvider {
    func store(agentId: String, content: String, layer: String, scope: String, metadata: Option<JsonValue>): Option<String>

    func retrieve(agentId: String, query: String, limit: Int64): ArrayList<MemoryEntry>

    func search(agentId: String, query: String, limit: Int64): ArrayList<MemoryEntry>

    func delete(memoryId: String): Bool

    func getProviderName(): String
}