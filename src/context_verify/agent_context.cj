/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.context_verify

import std.collection.HashMap
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

public struct AgentContext {
    public let taskId: String
    public let parentId: Option<String>
    public let input: JsonValue
    public let constraints: HashMap<String, String>
    public let metadata: HashMap<String, String>
    public let createdAt: DateTime

    public init(taskId!: String, input!: JsonValue) {
        this.taskId = taskId
        this.parentId = None<String>
        this.input = input
        this.constraints = HashMap<String, String>()
        this.metadata = HashMap<String, String>()
        this.createdAt = DateTime.now()
    }

    public init(taskId!: String, parentId!: Option<String>, input!: JsonValue, constraints!: HashMap<String, String>, metadata!: HashMap<String, String>) {
        this.taskId = taskId
        this.parentId = parentId
        this.input = input
        this.constraints = constraints
        this.metadata = metadata
        this.createdAt = DateTime.now()
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("task_id", JsonString(this.taskId))
        if (let Some(pid) <- this.parentId) {
            map.add("parent_id", JsonString(pid))
        }
        map.add("input", this.input)
        var constraintsMap = HashMap<String, JsonValue>()
        for ((k, v) in this.constraints) {
            constraintsMap.add(k, JsonString(v))
        }
        map.add("constraints", JsonObject(constraintsMap))
        var metadataMap = HashMap<String, JsonValue>()
        for ((k, v) in this.metadata) {
            metadataMap.add(k, JsonString(v))
        }
        map.add("metadata", JsonObject(metadataMap))
        map.add("created_at", JsonString(this.createdAt.toString()))
        return JsonObject(map)
    }

    public static func fromJsonValue(json: JsonValue): Option<AgentContext> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let taskIdOpt = fields.get("task_id")
        if (taskIdOpt.isNone()) {
            return None
        }
        let taskId = jsonStringValue(taskIdOpt.getOrThrow())

        var parentId: Option<String> = None<String>
        if (let Some(v) <- fields.get("parent_id")) {
            parentId = Some(jsonStringValue(v))
        }

        let inputOpt = fields.get("input")
        let input: JsonValue = if (inputOpt.isSome()) {
            inputOpt.getOrThrow()
        } else {
            JsonObject()
        }

        var constraints = HashMap<String, String>()
        if (let Some(v) <- fields.get("constraints")) {
            constraints = jsonStringMap(v)
        }

        var metadata = HashMap<String, String>()
        if (let Some(v) <- fields.get("metadata")) {
            metadata = jsonStringMap(v)
        }

        return Some(AgentContext(taskId: taskId, parentId: parentId, input: input, constraints: constraints, metadata: metadata))
    }

    private static func jsonStringValue(v: JsonValue): String {
        if (v is JsonString) {
            return (v as JsonString).getOrThrow().getValue()
        }
        return v.toString()
    }

    private static func jsonStringMap(v: JsonValue): HashMap<String, String> {
        let result = HashMap<String, String>()
        if (v is JsonObject) {
            let obj = (v as JsonObject).getOrThrow()
            let fields = obj.getFields()
            for ((k, val) in fields) {
                result.add(k, jsonStringValue(val))
            }
        }
        return result
    }
}