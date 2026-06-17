/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.agent.base.BaseAgent
import magic.agent_group.{LinearGroup, LeaderGroup, FreeGroup}
import magic.agent.GroupAsAgent
import magic.core.agent.{Agent, AgentRequest, AgentResponse, AgentGroup, AgentResponseStatus}
import magic.core.skill.{Skill, SkillManager}
import magic.core.model.ChatModel
import magic.core.agent.AgentExecutor
import magic.skill.SkillToToolAdapter
import magic.app.services.uctoo.AgentTasksService
import magic.app.models.uctoo.AgentTasksPO
import magic.log.LogUtils
import f_util.UUID
import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import std.core.Duration

public class SkillAsAgent <: BaseAgent {
    private let _skill: Skill
    private let _skillManager: SkillManager

    public init(
        skill: Skill,
        skillManager: SkillManager,
        model!: ChatModel,
        executor!: Option<AgentExecutor> = None<AgentExecutor>,
        name!: String = "",
        description!: String = ""
    ) {
        super (
            model: model,
            name: if (name.isEmpty()) { skill.name } else { name },
            description: if (description.isEmpty()) { skill.description } else { description },
            systemPrompt: skill.instructions,
            executor: executor
        )
        this._skill = skill
        this._skillManager = skillManager
        _registerSkillTools()
    }

    private func _registerSkillTools(): Unit {
        let adapter = SkillToToolAdapter(skill: _skill)
        _toolManager.addTool(adapter)

        if (let Some(allowedToolsStr) <- _skill.allowedTools) {
            if (!allowedToolsStr.isEmpty()) {
                let toolNames = allowedToolsStr.split(" ")
                for (toolName in toolNames) {
                    let trimmed = toolName.trimAscii()
                    if (!trimmed.isEmpty()) {
                        match (_skillManager.getSkill(trimmed)) {
                            case Some(subSkill) =>
                                let subAdapter = SkillToToolAdapter(skill: subSkill)
                                _toolManager.addTool(subAdapter)
                            case None => ()
                        }
                    }
                }
            }
        }
    }

    public prop skill: Skill {
        get() { _skill }
    }

    public prop skillManager: SkillManager {
        get() { _skillManager }
    }

    public static func createLinearChain(agents: Array<SkillAsAgent>): LinearGroup {
        if (agents.size < 2) {
            throw Exception("Linear chain requires at least 2 agents")
        }
        var group = LinearGroup(agents[0], agents[1])
        var i = 2
        while (i < agents.size) {
            group = group.addNext(agents[i])
            i = i + 1
        }
        return group
    }

    public static func createLeaderGroup(leader: SkillAsAgent, members: Array<SkillAsAgent>): LeaderGroup {
        let memberArray = ArrayList<Agent>()
        for (m in members) {
            memberArray.add(m)
        }
        return LeaderGroup(leader, memberArray.toArray())
    }

    public static func createFreeDiscussion(agents: Array<SkillAsAgent>): FreeGroup {
        if (agents.size < 2) {
            throw Exception("Free discussion requires at least 2 agents")
        }
        var group = FreeGroup(agents[0], agents[1])
        var i = 2
        while (i < agents.size) {
            group = group | agents[i]
            i = i + 1
        }
        return group
    }

    public static func wrapGroupAsAgent(group: AgentGroup, description!: String = "Composed skill group"): GroupAsAgent {
        return GroupAsAgent(group, description: description)
    }
}

public class SkillCompositionOrchestrator {
    private let _skillManager: SkillManager
    private let _model: ChatModel
    private let _agentTasksService: AgentTasksService

    public init(skillManager: SkillManager, model: ChatModel) {
        this._skillManager = skillManager
        this._model = model
        this._agentTasksService = AgentTasksService()
    }

    public func composeLinear(skillNames: Array<String>, request: AgentRequest): AgentResponse {
        let agents = _createAgents(skillNames)
        if (agents.size < 2) {
            throw Exception("Linear composition requires at least 2 skills")
        }
        let group = SkillAsAgent.createLinearChain(agents)
        let taskId = _createTaskRecord("linear", skillNames)
        let response = group.chat(request)
        _updateTaskRecord(taskId, response)
        return response
    }

    public func composeLeader(leaderSkillName: String, memberSkillNames: Array<String>, request: AgentRequest): AgentResponse {
        let leaderOpt = _createAgent(leaderSkillName)
        if (leaderOpt.isNone()) {
            throw Exception("Leader skill '${leaderSkillName}' not found")
        }
        let leader = leaderOpt.getOrThrow()
        let members = ArrayList<SkillAsAgent>()
        for (name in memberSkillNames) {
            match (_createAgent(name)) {
                case Some(agent) => members.add(agent)
                case None => LogUtils.warn("Member skill '${name}' not found, skipping")
            }
        }
        if (members.isEmpty()) {
            throw Exception("No valid member skills found")
        }
        let group = SkillAsAgent.createLeaderGroup(leader, members.toArray())
        let allNames = ArrayList<String>()
        allNames.add(leaderSkillName)
        for (n in memberSkillNames) { allNames.add(n) }
        let taskId = _createTaskRecord("leader", allNames.toArray())
        let response = group.chat(request)
        _updateTaskRecord(taskId, response)
        return response
    }

    public func composeParallel(skillNames: Array<String>, request: AgentRequest): AgentResponse {
        let agents = _createAgents(skillNames)
        if (agents.size < 2) {
            throw Exception("Parallel composition requires at least 2 skills")
        }
        let group = SkillAsAgent.createFreeDiscussion(agents)
        let taskId = _createTaskRecord("parallel", skillNames)
        let response = group.chat(request)
        _updateTaskRecord(taskId, response)
        return response
    }

    private func _createAgents(skillNames: Array<String>): Array<SkillAsAgent> {
        let agents = ArrayList<SkillAsAgent>()
        for (name in skillNames) {
            match (_createAgent(name)) {
                case Some(agent) => agents.add(agent)
                case None => LogUtils.warn("Skill '${name}' not found, skipping")
            }
        }
        return agents.toArray()
    }

    private func _createAgent(skillName: String): Option<SkillAsAgent> {
        match (_skillManager.getSkill(skillName)) {
            case Some(skill) =>
                try {
                    let agent = SkillAsAgent(
                        skill,
                        _skillManager,
                        model: _model,
                        executor: None<AgentExecutor>,
                        name: "",
                        description: ""
                    )
                    Some(agent)
                } catch (ex: Exception) {
                    LogUtils.error("Failed to create SkillAsAgent for '${skillName}': ${ex.message}")
                    None<SkillAsAgent>
                }
            case None => None<SkillAsAgent>
        }
    }

    private func _createTaskRecord(compositionType: String, skillNames: Array<String>): String {
        let taskId = UUID.random().toString()
        try {
            let task = AgentTasksPO()
            task.id = taskId
            task.agentId = "skill_composition"
            let statusValue: Int32 = 1
            task.status = Some(statusValue) // 1 = running
            let payloadStr = "Skill composition: ${compositionType} [${String.join(skillNames, delimiter: ",")}]"
            task.payload = Some(payloadStr)
            task.result = None<String>
            task.creator = Some("system")
            task.createdAt = DateTime.now()
            task.updatedAt = DateTime.now()
            task.deletedAt = None<DateTime>
            _agentTasksService.create(task, "system")
        } catch (ex: Exception) {
            LogUtils.error("Failed to create task record: ${ex.message}")
        }
        return taskId
    }

    private func _updateTaskRecord(taskId: String, response: AgentResponse): Unit {
        try {
            let task = AgentTasksPO()
            task.id = taskId
            let statusValue: Int32 = if (response.status == AgentResponseStatus.Success) { 2 } else { 3 } // 2 = completed, 3 = failed
            task.status = Some(statusValue)
            task.result = Some(response.content)
            task.updatedAt = DateTime.now()
            _agentTasksService.update(taskId, task)
        } catch (ex: Exception) {
            LogUtils.error("Failed to update task record: ${ex.message}")
        }
    }
}