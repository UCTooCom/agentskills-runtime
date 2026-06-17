/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent.memory.tiered

import magic.core.memory.Memory
import magic.memory.ShortMemory
import magic.agent.memory.database.DatabaseMemory
import magic.log.LogUtils
import std.collection.{ArrayList, HashSet}

public class LayeredMemory <: Memory {
    private let agentId: String
    private let workingMemory: ShortMemory
    private let episodicMemory: DatabaseMemory
    private let semanticMemory: DatabaseMemory
    private let proceduralMemory: DatabaseMemory

    public init(agentId!: String) {
        this.agentId = agentId
        this.workingMemory = ShortMemory()
        this.episodicMemory = DatabaseMemory(agentId: agentId, scope: "episodic")
        this.semanticMemory = DatabaseMemory(agentId: agentId, scope: "semantic")
        this.proceduralMemory = DatabaseMemory(agentId: agentId, scope: "procedural")
    }

    override public func update(segment: String): Unit {
        try {
            workingMemory.update(segment)
            spawn {
                try { episodicMemory.update(segment) } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            LogUtils.error("LayeredMemory.update failed: ${e.message}")
        }
    }

    override public func search(question: String): Array<String> {
        try {
            let workingResults = workingMemory.search(question)
            if (workingResults.size >= 5) { return workingResults }

            let episodicResults = episodicMemory.search(question)
            let allResults = mergeDedup(workingResults, episodicResults)
            if (allResults.size >= 5) { return allResults }

            let semanticResults = semanticMemory.search(question)
            let withSemantic = mergeDedupArray(allResults, semanticResults)
            if (withSemantic.size >= 5) { return withSemantic }

            let proceduralResults = proceduralMemory.search(question)
            mergeDedupArray(withSemantic, proceduralResults)
        } catch (e: Exception) {
            LogUtils.error("LayeredMemory.search failed: ${e.message}")
            return []
        }
    }

    public func updateSemantic(segment: String): Unit {
        try {
            semanticMemory.update(segment)
        } catch (e: Exception) {
            LogUtils.error("LayeredMemory.updateSemantic failed: ${e.message}")
        }
    }

    public func updateProcedural(segment: String): Unit {
        try {
            proceduralMemory.update(segment)
        } catch (e: Exception) {
            LogUtils.error("LayeredMemory.updateProcedural failed: ${e.message}")
        }
    }

    public func clearEpisodic(): Unit { episodicMemory.clear() }
    public func clearSemantic(): Unit { semanticMemory.clear() }
    public func clearProcedural(): Unit { proceduralMemory.clear() }
    public func clearAll(): Unit {
        episodicMemory.clear()
        semanticMemory.clear()
        proceduralMemory.clear()
    }

    private func mergeDedup(a: Array<String>, b: Array<String>): Array<String> {
        let seen = HashSet<String>()
        let result = ArrayList<String>()
        for (s in a) { if (!seen.contains(s)) { seen.add(s); result.add(s) } }
        for (s in b) { if (!seen.contains(s)) { seen.add(s); result.add(s) } }
        result.toArray()
    }

    private func mergeDedupArray(a: Array<String>, b: Array<String>): Array<String> {
        mergeDedup(a, b)
    }
}