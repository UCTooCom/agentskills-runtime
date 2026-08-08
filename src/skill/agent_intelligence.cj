/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray}
import magic.log.LogUtils

public class RepoNode {
    public var name: String = ""
    public var nodeType: String = ""
    public var filePath: String = ""
    public var importance: Float64 = 0.0
    public var connections: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("name", JsonString(this.name))
        map.add("node_type", JsonString(this.nodeType))
        map.add("file_path", JsonString(this.filePath))
        map.add("importance", JsonString(this.importance.toString()))
        var connArr = ArrayList<JsonValue>()
        for (c in this.connections) { connArr.add(JsonString(c)) }
        map.add("connections", JsonArray(connArr))
        JsonObject(map)
    }
}

public class RepoMap {
    private var _nodes: HashMap<String, RepoNode>
    private let _scanDirectory: (String) -> ArrayList<RepoNode>

    public init(scanDirectory!: (String) -> ArrayList<RepoNode>) {
        _nodes = HashMap<String, RepoNode>()
        _scanDirectory = scanDirectory
    }

    public func buildMap(directory: String): Int64 {
        _nodes = HashMap<String, RepoNode>()
        let nodes = _scanDirectory(directory)
        for (node in nodes) {
            _nodes.add(node.name, node)
        }
        calculatePageRank()
        LogUtils.info("[RepoMap] Built map with ${_nodes.size.toString()} nodes from: ${directory}")
        Int64(_nodes.size)
    }

    public func getTopNodes(limit: Int64): ArrayList<RepoNode> {
        let all = ArrayList<RepoNode>()
        for ((_, node) in _nodes) { all.add(node) }
        let result = ArrayList<RepoNode>()
        let remaining = all
        let count = if (limit < Int64(remaining.size)) { limit } else { Int64(remaining.size) }
        for (_ in 0..count) {
            var maxIdx = 0
            for (i in 1..remaining.size) {
                if (remaining[i].importance > remaining[maxIdx].importance) { maxIdx = i }
            }
            result.add(remaining[maxIdx])
            remaining.remove(at: maxIdx)
        }
        result
    }

    public func getNode(name: String): Option<RepoNode> {
        _nodes.get(name)
    }

    public func getContextFor(query: String, limit!: Int64 = 20): ArrayList<RepoNode> {
        let relevant = ArrayList<RepoNode>()
        for ((_, node) in _nodes) {
            if (node.name.contains(query) || node.filePath.contains(query)) {
                relevant.add(node)
            }
        }
        if (relevant.size == 0) {
            return getTopNodes(limit)
        }
        relevant
    }

    private func calculatePageRank(): Unit {
        if (_nodes.size == 0) { return }
        let damping = 0.85
        let initialRank = 1.0 / Float64(_nodes.size)
        for ((_, node) in _nodes) {
            node.importance = initialRank
        }
        for (_ in 0..10) {
            for ((_, node) in _nodes) {
                var rank = (1.0 - damping) / Float64(_nodes.size)
                for (connName in node.connections) {
                    if (let Some(conn) <- _nodes.get(connName)) {
                        if (conn.connections.size > 0) {
                            rank = rank + damping * conn.importance / Float64(conn.connections.size)
                        }
                    }
                }
                node.importance = rank
            }
        }
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        for ((k, v) in _nodes) {
            map.add(k, v.toJsonValue())
        }
        JsonObject(map)
    }
}

public class AgentDynamicGenerator {
    private let _generateConfig: (String, String, Option<JsonValue>) -> Option<JsonValue>
    private let _saveConfig: (String, JsonValue) -> Bool

    public init(generateConfig!: (String, String, Option<JsonValue>) -> Option<JsonValue>, saveConfig!: (String, JsonValue) -> Bool) {
        _generateConfig = generateConfig
        _saveConfig = saveConfig
    }

    public func generateAgent(taskDescription: String, language: String, context!: Option<JsonValue> = None<JsonValue>): Option<String> {
        LogUtils.info("[AgentDynamicGenerator] Generating agent for: ${taskDescription}, language: ${language}")

        let configOpt = _generateConfig(taskDescription, language, context)
        if (configOpt.isNone()) {
            LogUtils.error("[AgentDynamicGenerator] Failed to generate agent config")
            return None<String>
        }

        let config = configOpt.getOrThrow()
        let agentId = "dynamic_${language}_${(DateTime.now() - DateTime.UnixEpoch).toMilliseconds()}"
        let success = _saveConfig(agentId, config)

        if (success) {
            LogUtils.info("[AgentDynamicGenerator] Agent generated and saved: ${agentId}")
            return Some(agentId)
        }
        LogUtils.error("[AgentDynamicGenerator] Failed to save agent config")
        None<String>
    }
}