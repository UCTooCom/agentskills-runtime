/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray}
import magic.log.LogUtils

public class CollaborationSkillInput {
    public var skillName: String = ""
    public var taskId: String = ""
    public var agentId: String = ""
    public var teamId: String = ""
    public var input: Option<JsonValue> = None<JsonValue>
    public var context: HashMap<String, String> = HashMap<String, String>()

    public init() {}
}

public class CollaborationSkillOutput {
    public var skillName: String = ""
    public var success: Bool = false
    public var output: Option<JsonValue> = None<JsonValue>
    public var message: String = ""
    public var nextAgent: Option<String> = None<String>
    public var contextUpdates: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("skill_name", JsonString(this.skillName))
        map.add("success", JsonBool(this.success))
        if (let Some(o) <- this.output) { map.add("output", o) }
        map.add("message", JsonString(this.message))
        if (let Some(na) <- this.nextAgent) { map.add("next_agent", JsonString(na)) }
        var ctxMap = HashMap<String, JsonValue>()
        for ((k, v) in this.contextUpdates) { ctxMap.add(k, JsonString(v)) }
        map.add("context_updates", JsonObject(ctxMap))
        JsonObject(map)
    }
}

public class TaskDecomposeSkill {
    private let _createKanbanTask: (String, String, String, String, Int64) -> String

    public init(createKanbanTask!: (String, String, String, String, Int64) -> String) {
        _createKanbanTask = createKanbanTask
    }

    public func execute(input: CollaborationSkillInput): CollaborationSkillOutput {
        LogUtils.info("[TaskDecompose] Decomposing task: ${input.taskId}")
        let output = CollaborationSkillOutput()
        output.skillName = "task-decompose"

        if (let Some(json) <- input.input) {
            if (json is JsonObject) {
                let obj = json.asObject()
                var subtaskCount = 0
                if (let Some(val) <- obj.get("subtasks")) {
                    if (val is JsonArray) {
                        for (item in val.asArray().getItems()) {
                            if (item is JsonObject) {
                                let subObj = item.asObject()
                                var title = ""
                                var description = ""
                                var assignee = ""
                                if (let Some(t) <- subObj.get("title")) {
                                    if (t is JsonString) { title = t.asString().getValue() }
                                }
                                if (let Some(d) <- subObj.get("description")) {
                                    if (d is JsonString) { description = d.asString().getValue() }
                                }
                                if (let Some(a) <- subObj.get("assignee")) {
                                    if (a is JsonString) { assignee = a.asString().getValue() }
                                }
                                if (title.size > 0) {
                                    _createKanbanTask(input.teamId, title, description, assignee, 1)
                                    subtaskCount = subtaskCount + 1
                                }
                            }
                        }
                    }
                }
                output.success = true
                output.message = "Decomposed into ${subtaskCount.toString()} subtasks"
            }
        } else {
            output.message = "No input provided for decomposition"
        }
        output
    }
}

public class AgentSelectSkill {
    private let _getAvailableAgents: (String) -> ArrayList<String>

    public init(getAvailableAgents!: (String) -> ArrayList<String>) {
        _getAvailableAgents = getAvailableAgents
    }

    public func execute(input: CollaborationSkillInput): CollaborationSkillOutput {
        LogUtils.info("[AgentSelect] Selecting agent for task: ${input.taskId}")
        let output = CollaborationSkillOutput()
        output.skillName = "agent-select"

        let agents = _getAvailableAgents(input.teamId)
        if (agents.size > 0) {
            output.success = true
            output.nextAgent = Some(agents[0])
            output.message = "Selected agent: ${agents[0]} from ${agents.size.toString()} available agents"
        } else {
            output.message = "No available agents in team: ${input.teamId}"
        }
        output
    }
}

public class ContextPassSkill {
    public init() {}

    public func execute(input: CollaborationSkillInput): CollaborationSkillOutput {
        LogUtils.info("[ContextPass] Passing context for task: ${input.taskId}")
        let output = CollaborationSkillOutput()
        output.skillName = "context-pass"
        output.success = true
        output.contextUpdates = input.context
        output.message = "Context passed: ${input.context.size.toString()} entries"
        output
    }
}

public class ResultMergeSkill {
    public init() {}

    public func execute(input: CollaborationSkillInput): CollaborationSkillOutput {
        LogUtils.info("[ResultMerge] Merging results for task: ${input.taskId}")
        let output = CollaborationSkillOutput()
        output.skillName = "result-merge"

        if (let Some(json) <- input.input) {
            if (json is JsonArray) {
                let arr = json.asArray()
                output.success = true
                output.output = Some(json)
                output.message = "Merged ${arr.size().toString()} results"
            } else {
                output.success = true
                output.output = Some(json)
                output.message = "Single result passed through"
            }
        } else {
            output.message = "No results to merge"
        }
        output
    }
}

public class ConflictResolveSkill {
    private let _strategy: String

    public init(strategy!: String = "last_writer_wins") {
        _strategy = strategy
    }

    public func execute(input: CollaborationSkillInput): CollaborationSkillOutput {
        LogUtils.info("[ConflictResolve] Resolving conflicts for task: ${input.taskId}, strategy=${_strategy}")
        let output = CollaborationSkillOutput()
        output.skillName = "conflict-resolve"
        output.success = true
        output.message = "Conflicts resolved using strategy: ${_strategy}"
        output
    }
}

public class HandoverSkill {
    public init() {}

    public func execute(input: CollaborationSkillInput): CollaborationSkillOutput {
        LogUtils.info("[Handover] Handing over task: ${input.taskId} from ${input.agentId}")
        let output = CollaborationSkillOutput()
        output.skillName = "handover"

        if (let Some(nextAgent) <- input.context.get("next_agent")) {
            output.success = true
            output.nextAgent = Some(nextAgent)
            output.message = "Handed over from ${input.agentId} to ${nextAgent}"
        } else {
            output.message = "No next_agent specified for handover"
        }
        output
    }
}