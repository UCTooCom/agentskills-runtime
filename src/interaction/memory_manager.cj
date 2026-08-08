/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}
import magic.log.LogUtils

public enum MemoryLayer {
    | Working | Episodic | Semantic | Procedural
}

public class MemoryEntry {
    public var id: String = ""
    public var agentId: String = ""
    public var content: String = ""
    public var layer: MemoryLayer = MemoryLayer.Working
    public var scope: String = "private"
    public var weight: Float64 = 1.0
    public var tags: ArrayList<String> = ArrayList<String>()
    public var accessCount: Int64 = 0
    public var createdAt: DateTime = DateTime.now()
    public var expiresAt: Option<DateTime> = None<DateTime>

    public init() {}

    public func isExpired(): Bool {
        if (let Some(exp) <- expiresAt) {
            return DateTime.now() > exp
        }
        false
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", JsonString(this.id))
        map.add("agent_id", JsonString(this.agentId))
        map.add("content", JsonString(this.content))
        map.add("layer", JsonString(memoryLayerToString(this.layer)))
        map.add("scope", JsonString(this.scope))
        map.add("weight", JsonFloat(this.weight))
        map.add("access_count", JsonInt(this.accessCount))
        map.add("created_at", JsonString(this.createdAt.toString()))
        JsonObject(map)
    }

    public static func memoryLayerToString(l: MemoryLayer): String {
        match (l) {
            case MemoryLayer.Working => "working"
            case MemoryLayer.Episodic => "episodic"
            case MemoryLayer.Semantic => "semantic"
            case MemoryLayer.Procedural => "procedural"
        }
    }

    public static func parseMemoryLayer(s: String): MemoryLayer {
        match (s.toAsciiLower()) {
            case "working" => MemoryLayer.Working
            case "episodic" => MemoryLayer.Episodic
            case "semantic" => MemoryLayer.Semantic
            case "procedural" => MemoryLayer.Procedural
            case _ => MemoryLayer.Working
        }
    }
}

public class MemoryLayerManager {
    private let _storeMemory: (MemoryEntry) -> Bool
    private let _retrieveMemories: (String, String, Int64) -> ArrayList<MemoryEntry>
    private let _deleteMemory: (String) -> Bool
    private var _workingMemory: HashMap<String, ArrayList<MemoryEntry>>
    private let _maxWorkingMemory: Int64

    public init(storeMemory!: (MemoryEntry) -> Bool, retrieveMemories!: (String, String, Int64) -> ArrayList<MemoryEntry>, deleteMemory!: (String) -> Bool, maxWorkingMemory!: Int64 = 50) {
        _storeMemory = storeMemory
        _retrieveMemories = retrieveMemories
        _deleteMemory = deleteMemory
        _workingMemory = HashMap<String, ArrayList<MemoryEntry>>()
        _maxWorkingMemory = maxWorkingMemory
    }

    public func store(entry: MemoryEntry): Bool {
        if (isSameMemoryLayer(entry.layer, MemoryLayer.Working)) {
            storeWorkingMemory(entry)
        }
        _storeMemory(entry)
    }

    public func retrieve(agentId: String, layer: MemoryLayer, limit!: Int64 = 10): ArrayList<MemoryEntry> {
        if (isSameMemoryLayer(layer, MemoryLayer.Working)) {
            if (let Some(entries) <- _workingMemory.get(agentId)) {
                let result = ArrayList<MemoryEntry>()
                let count = if (limit < Int64(entries.size)) { limit } else { Int64(entries.size) }
                for (i in 0..count) { result.add(entries[Int64(i)]) }
                return result
            }
            return ArrayList<MemoryEntry>()
        }
        _retrieveMemories(agentId, MemoryEntry.memoryLayerToString(layer), limit)
    }

    public func promoteToEpisodic(agentId: String, memoryId: String): Bool {
        let working = _workingMemory.get(agentId)
        if (let Some(entries) <- working) {
            for (entry in entries) {
                if (entry.id == memoryId) {
                    let episodicEntry = MemoryEntry()
                    episodicEntry.id = entry.id
                    episodicEntry.agentId = entry.agentId
                    episodicEntry.content = entry.content
                    episodicEntry.layer = MemoryLayer.Episodic
                    episodicEntry.scope = entry.scope
                    episodicEntry.weight = entry.weight + 1.0
                    episodicEntry.tags = entry.tags
                    episodicEntry.accessCount = entry.accessCount
                    return _storeMemory(episodicEntry)
                }
            }
        }
        false
    }

    public func applyDecay(agentId: String, decayFactor!: Float64 = 0.95): Int64 {
        let episodic = _retrieveMemories(agentId, "episodic", 100)
        var decayed = 0
        for (entry in episodic) {
            let newWeight = entry.weight * decayFactor
            if (newWeight < 0.1) {
                _deleteMemory(entry.id)
                decayed = decayed + 1
            } else {
                let updated = MemoryEntry()
                updated.id = entry.id
                updated.agentId = entry.agentId
                updated.content = entry.content
                updated.layer = entry.layer
                updated.scope = entry.scope
                updated.weight = newWeight
                updated.tags = entry.tags
                updated.accessCount = entry.accessCount
                _storeMemory(updated)
            }
        }
        Int64(decayed)
    }

    public func compressWorkingMemory(agentId: String): Unit {
        if (let Some(entries) <- _workingMemory.get(agentId)) {
            if (Int64(entries.size) > _maxWorkingMemory) {
                let keepCount = _maxWorkingMemory / 2
                let kept = ArrayList<MemoryEntry>()
                for (i in Int64(0)..keepCount) { kept.add(entries[i]) }
                _workingMemory.add(agentId, kept)
                LogUtils.info("[MemoryLayerManager] Compressed working memory for ${agentId}: ${entries.size.toString()} → ${kept.size.toString()}")
            }
        }
    }

    private func storeWorkingMemory(entry: MemoryEntry): Unit {
        if (let Some(entries) <- _workingMemory.get(entry.agentId)) {
            entries.add(entry)
        } else {
            let entries = ArrayList<MemoryEntry>()
            entries.add(entry)
            _workingMemory.add(entry.agentId, entries)
        }
    }

    public static func isSameMemoryLayer(a: MemoryLayer, b: MemoryLayer): Bool {
        match (a) {
            case MemoryLayer.Working => match (b) { case MemoryLayer.Working => true case _ => false }
            case MemoryLayer.Episodic => match (b) { case MemoryLayer.Episodic => true case _ => false }
            case MemoryLayer.Semantic => match (b) { case MemoryLayer.Semantic => true case _ => false }
            case MemoryLayer.Procedural => match (b) { case MemoryLayer.Procedural => true case _ => false }
        }
    }
}

public class SemanticMemorySearch {
    private let _searchByEmbedding: (String, Int64) -> ArrayList<MemoryEntry>
    private let _searchByKeyword: (String, String, Int64) -> ArrayList<MemoryEntry>

    public init(searchByEmbedding!: (String, Int64) -> ArrayList<MemoryEntry>, searchByKeyword!: (String, String, Int64) -> ArrayList<MemoryEntry>) {
        _searchByEmbedding = searchByEmbedding
        _searchByKeyword = searchByKeyword
    }

    public func search(agentId: String, query: String, limit!: Int64 = 10): ArrayList<MemoryEntry> {
        let keywordResults = _searchByKeyword(agentId, query, limit)
        if (keywordResults.size > 0) {
            LogUtils.info("[SemanticMemorySearch] Found ${keywordResults.size.toString()} results by keyword for: ${query}")
            return keywordResults
        }
        LogUtils.info("[SemanticMemorySearch] No keyword results, trying embedding search for: ${query}")
        _searchByEmbedding(query, limit)
    }

    public func searchByTags(agentId: String, tags: ArrayList<String>, limit!: Int64 = 10): ArrayList<MemoryEntry> {
        let tagQuery = StringBuilder()
        for (i in 0..tags.size) {
            if (i > 0) { tagQuery.append(" ") }
            tagQuery.append(tags[i])
        }
        _searchByKeyword(agentId, tagQuery.toString(), limit)
    }
}

public class MemorySharingManager {
    private let _updateSharing: (String, String) -> Bool

    public init(updateSharing!: (String, String) -> Bool) {
        _updateSharing = updateSharing
    }

    public func setPrivate(memoryId: String): Bool {
        _updateSharing(memoryId, "private")
    }

    public func setShared(memoryId: String): Bool {
        _updateSharing(memoryId, "shared")
    }

    public func setGlobal(memoryId: String): Bool {
        _updateSharing(memoryId, "global")
    }

    public func canAccess(memorySharing: String, requesterAgentId: String, ownerAgentId: String): Bool {
        match (memorySharing.toAsciiLower()) {
            case "global" => true
            case "shared" => true
            case "private" => requesterAgentId == ownerAgentId
            case _ => false
        }
    }
}