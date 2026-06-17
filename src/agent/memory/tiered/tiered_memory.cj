/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent.memory.tiered

import magic.core.memory.Memory
import magic.memory.ShortMemory
import magic.agent.memory.database.DatabaseMemory
import magic.log.LogUtils
import std.collection.{ArrayList, HashSet}

public class TieredMemory <: Memory {
    private let shortMemory: ShortMemory
    private let databaseMemory: DatabaseMemory

    public init(agentId!: String) {
        this.shortMemory = ShortMemory()
        this.databaseMemory = DatabaseMemory(agentId: agentId, scope: "episodic")
    }

    public init(agentId!: String, scope!: String) {
        this.shortMemory = ShortMemory()
        this.databaseMemory = DatabaseMemory(agentId: agentId, scope: scope)
    }

    override public func update(segment: String): Unit {
        try {
            shortMemory.update(segment)
            spawn {
                try {
                    databaseMemory.update(segment)
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            LogUtils.error("TieredMemory.update failed: ${e.message}")
        }
    }

    override public func search(question: String): Array<String> {
        try {
            let memResults = shortMemory.search(question)
            if (memResults.size >= 5) {
                return memResults
            }
            let dbResults = databaseMemory.search(question)
            let merged = mergeDedup(memResults, dbResults)
            return merged
        } catch (e: Exception) {
            LogUtils.error("TieredMemory.search failed: ${e.message}")
            return []
        }
    }

    public func clear(): Unit {
        try {
            shortMemory.update("")
            databaseMemory.clear()
        } catch (e: Exception) {
            LogUtils.error("TieredMemory.clear failed: ${e.message}")
        }
    }

    private func mergeDedup(a: Array<String>, b: Array<String>): Array<String> {
        let seen = HashSet<String>()
        let result = ArrayList<String>()
        for (s in a) {
            if (!seen.contains(s)) {
                seen.add(s)
                result.add(s)
            }
        }
        for (s in b) {
            if (!seen.contains(s)) {
                seen.add(s)
                result.add(s)
            }
        }
        result.toArray()
    }
}