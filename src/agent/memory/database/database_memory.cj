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
            // v12 修复：Embedding model 未设置时降级为数据库 CRUD 查询（最近 N 条记录）
            // 根因：searchByContent 依赖 Embedding 语义搜索，未配置 Embedding model 时抛异常
            LogUtils.warn("DatabaseMemory.search failed (embedding), falling back to CRUD: ${e.message}")
            return searchRecent(5)
        }
    }

    /**
     * v12 修复：降级查询，直接从数据库读取最近 N 条记录（不依赖 Embedding）
     */
    public func searchRecent(limit: Int64): Array<String> {
        try {
            let (results, _) = memoriesService.findByAgentIdAndScope(agentId, scope, 1, limit)
            let segments = ArrayList<String>()
            for (po in results) {
                segments.add(po.content)
            }
            return segments.toArray()
        } catch (e: Exception) {
            LogUtils.error("DatabaseMemory.searchRecent failed: ${e.message}")
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