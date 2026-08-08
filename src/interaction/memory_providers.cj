/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import magic.log.LogUtils

public class BuiltinProvider <: MemoryProvider {
    private var _memories: HashMap<String, MemoryEntry>

    public init() {
        _memories = HashMap<String, MemoryEntry>()
    }

    public func store(agentId: String, content: String, layer: String, scope: String, metadata: Option<JsonValue>): Option<String> {
        let id = "builtin_${(DateTime.now() - DateTime.UnixEpoch).toMilliseconds()}"
        let entry = MemoryEntry()
        entry.id = id
        entry.agentId = agentId
        entry.content = content
        entry.layer = MemoryEntry.parseMemoryLayer(layer)
        entry.scope = scope
        _memories.add(id, entry)
        LogUtils.info("[BuiltinProvider] Stored memory: ${id} for agent: ${agentId}")
        Some(id)
    }

    public func retrieve(agentId: String, query: String, limit: Int64): ArrayList<MemoryEntry> {
        let result = ArrayList<MemoryEntry>()
        for ((_, entry) in _memories) {
            if (entry.agentId == agentId) {
                result.add(entry)
                if (Int64(result.size) >= limit) { break }
            }
        }
        result
    }

    public func search(agentId: String, query: String, limit: Int64): ArrayList<MemoryEntry> {
        let result = ArrayList<MemoryEntry>()
        for ((_, entry) in _memories) {
            if (entry.agentId == agentId && entry.content.contains(query)) {
                result.add(entry)
                if (Int64(result.size) >= limit) { break }
            }
        }
        result
    }

    public func delete(memoryId: String): Bool {
        if (_memories.contains(memoryId)) {
            _memories.remove(memoryId)
            true
        } else {
            false
        }
    }

    public func getProviderName(): String {
        "builtin"
    }
}

public class PostgresProvider <: MemoryProvider {
    private let _storeToDb: (String, String, String, String, String) -> Option<String>
    private let _retrieveFromDb: (String, String, Int64) -> ArrayList<MemoryEntry>
    private let _searchFromDb: (String, String, Int64) -> ArrayList<MemoryEntry>
    private let _deleteFromDb: (String) -> Bool

    public init(storeToDb!: (String, String, String, String, String) -> Option<String>, retrieveFromDb!: (String, String, Int64) -> ArrayList<MemoryEntry>, searchFromDb!: (String, String, Int64) -> ArrayList<MemoryEntry>, deleteFromDb!: (String) -> Bool) {
        _storeToDb = storeToDb
        _retrieveFromDb = retrieveFromDb
        _searchFromDb = searchFromDb
        _deleteFromDb = deleteFromDb
    }

    public func store(agentId: String, content: String, layer: String, scope: String, metadata: Option<JsonValue>): Option<String> {
        _storeToDb(agentId, content, layer, scope, if (metadata.isSome()) { metadata.getOrThrow().toString() } else { "" })
    }

    public func retrieve(agentId: String, query: String, limit: Int64): ArrayList<MemoryEntry> {
        _retrieveFromDb(agentId, query, limit)
    }

    public func search(agentId: String, query: String, limit: Int64): ArrayList<MemoryEntry> {
        _searchFromDb(agentId, query, limit)
    }

    public func delete(memoryId: String): Bool {
        _deleteFromDb(memoryId)
    }

    public func getProviderName(): String {
        "postgres"
    }
}