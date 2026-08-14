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
        // v13修复：分别try-catch shortMemory和databaseMemory，确保任一失败不影响另一个
        // 根因：ShortMemory使用Config.defaultEmbeddingModel，未配置时抛出"Embedding model is not set"
        // v12修复的databaseMemory降级逻辑因此从未执行（shortMemory先抛异常导致整体catch）
        var memResults: Array<String> = []
        try {
            memResults = shortMemory.search(question)
        } catch (e: Exception) {
            LogUtils.warn("TieredMemory.search shortMemory failed (embedding not configured?): ${e.message}")
        }

        if (memResults.size >= 5) {
            return memResults
        }

        var dbResults: Array<String> = []
        try {
            dbResults = databaseMemory.search(question)
        } catch (e: Exception) {
            LogUtils.warn("TieredMemory.search databaseMemory failed: ${e.message}")
        }

        return mergeDedup(memResults, dbResults)
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