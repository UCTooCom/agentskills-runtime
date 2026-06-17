/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent.memory.database

import magic.core.memory.Memory
import magic.app.models.uctoo.AgentMemoriesPO
import magic.app.services.uctoo.AgentMemoriesService
import magic.log.LogUtils
import std.collection.ArrayList

public class DatabaseMemory <: Memory {
    private let agentId: String
    private let scope: String
    private let memoriesService = AgentMemoriesService()

    public init(agentId!: String, scope!: String = "episodic") {
        this.agentId = agentId
        this.scope = scope
    }

    override public func update(segment: String): Unit {
        try {
            let po = AgentMemoriesPO()
            po.agentId = agentId
            po.content = segment
            po.scope = scope
            po.weight = 1.0
            po.tags = "[]"
            po.metadata = "{}"
            spawn {
                try {
                    memoriesService.create(po, agentId)
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            LogUtils.error("DatabaseMemory.update failed: ${e.message}")
        }
    }

    override public func search(question: String): Array<String> {
        try {
            let results = memoriesService.searchByContent(agentId, scope, question, 5)
            let segments = ArrayList<String>()
            for (po in results) {
                segments.add(po.content)
            }
            return segments.toArray()
        } catch (e: Exception) {
            LogUtils.error("DatabaseMemory.search failed: ${e.message}")
            return []
        }
    }

    public func clear(): Unit {
        try {
            memoriesService.clearByAgentId(agentId, scope)
        } catch (e: Exception) {
            LogUtils.error("DatabaseMemory.clear failed: ${e.message}")
        }
    }
}