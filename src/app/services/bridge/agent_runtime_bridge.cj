/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.agent.base.BaseAgent
import magic.core.agent.{AgentDefinition, AgentType, AgentMemory, AgentPermission}
import magic.core.agent.AgentExecutor
import magic.agent_executor.AgentExecutorManager
import magic.model.ModelManager
import magic.app.models.uctoo.AgentsPO
import magic.app.services.uctoo.AgentsService
import magic.app.core.response.APIResult
import magic.log.LogUtils
import f_util.UUID
import std.collection.{HashMap, ArrayList, concurrent.ConcurrentHashMap}
import std.time.DateTime
import std.fs.Path

public class AgentRuntimeBridge {
    private static var instance_: Option<AgentRuntimeBridge> = None<AgentRuntimeBridge>

    private let runtimeAgents = ConcurrentHashMap<String, BaseAgent>()

    private let agentsService = AgentsService()

    public static prop instance: AgentRuntimeBridge {
        get() {
            match (instance_) {
                case Some(v) => v
                case None =>
                    let inst = AgentRuntimeBridge()
                    instance_ = Some(inst)
                    inst
            }
        }
    }

    public init() {}

    public func createRuntimeAgent(definition: AgentDefinition): APIResult<BaseAgent> {
        try {
            let agentId = UUID.random().toString()
            let agent = buildAgentFromDefinition(definition)
            runtimeAgents.add(agentId, agent)
            let po = mapDefinitionToPO(definition, agentId)
            po.status = Some(0)
            let result = agentsService.create(po, agentId)
            if (result.success) {
                return APIResult<BaseAgent>(agent)
            }
            return APIResult<BaseAgent>(false, "数据库持久化失败")
        } catch (e: Exception) {
            return APIResult<BaseAgent>(false, e.message)
        }
    }

    public func syncToDatabase(agentId: String, agent: BaseAgent): Unit {
        spawn {
            try {
                let po = mapAgentToPO(agentId, agent)
                agentsService.update(agentId, po)
            } catch (_: Exception) {}
        }
    }

    public func loadFromDatabase(agentId: String): APIResult<BaseAgent> {
        try {
            if (let Some(existing) <- runtimeAgents.get(agentId)) {
                return APIResult<BaseAgent>(existing)
            }
            let result = agentsService.getById(agentId)
            if (!result.success) {
                let reasonStr = match (result.reason) { case Some(r) => r; case None => "未找到" }
                return APIResult<BaseAgent>(false, reasonStr)
            }
            if (let Some(po) <- result.data) {
                let definition = mapPOToDefinition(po)
                let agent = buildAgentFromDefinition(definition)
                runtimeAgents.add(agentId, agent)
                return APIResult<BaseAgent>(agent)
            }
            return APIResult<BaseAgent>(false, "数据为空")
        } catch (e: Exception) {
            return APIResult<BaseAgent>(false, e.message)
        }
    }

    public func loadAllFromDatabase(): ArrayList<BaseAgent> {
        let agents = ArrayList<BaseAgent>()
        let (pos, _) = agentsService.getListWithFilter(1, 1000, "", "")
        for (po in pos) {
            if (let Some(_) <- runtimeAgents.get(po.id)) {
                continue
            }
            try {
                let definition = mapPOToDefinition(po)
                let agent = buildAgentFromDefinition(definition)
                runtimeAgents.add(po.id, agent)
                agents.add(agent)
            } catch (_: Exception) {}
        }
        return agents
    }

    public func updateRuntimeState(agentId: String, state: Int32): Unit {
        spawn {
            try {
                let po = AgentsPO()
                po.id = agentId
                po.status = Some(state)
                agentsService.update(agentId, po)
            } catch (_: Exception) {}
        }
    }

    public func getRuntimeAgent(agentId: String): Option<BaseAgent> {
        runtimeAgents.get(agentId)
    }

    public func removeRuntimeAgent(agentId: String): Unit {
        runtimeAgents.remove(agentId)
    }

    public func createWithFallback(definition: AgentDefinition): BaseAgent {
        let result = createRuntimeAgent(definition)
        if (result.success) {
            if (let Some(data) <- result.data) {
                return data
            }
        }
        let agent = buildAgentFromDefinition(definition)
        let agentId = UUID.random().toString()
        runtimeAgents.add(agentId, agent)
        return agent
    }

    public func getRuntimeAgentCount(): Int64 {
        runtimeAgents.size
    }

    public func getAllRuntimeAgentIds(): ArrayList<String> {
        let ids = ArrayList<String>()
        for ((k, _) in runtimeAgents) {
                ids.add(k)
        }
        ids
    }

    private func buildAgentFromDefinition(definition: AgentDefinition): BaseAgent {
        let modelName = if (let Some(m) <- definition.model) { m } else { "deepseek:deepseek-chat" }
        let chatModel = ModelManager.createChatModel(modelName)
        BaseAgent(
            model: chatModel,
            name: definition.name,
            description: definition.description,
            systemPrompt: definition.systemPrompt
        )
    }

    private func mapDefinitionToPO(definition: AgentDefinition, agentId: String): AgentsPO {
        let po = AgentsPO()
        po.id = agentId
        po.name = definition.name
        po.agentType = definition.agentType.toString().toAsciiLower()
        po.description = Some(definition.description)
        po.version = Some(definition.version)
        po.author = definition.author
        po.model = definition.model
        po.systemPrompt = Some(definition.systemPrompt)
        po.maxTurns = Some(Int32(definition.maxTurns))
        po.memoryScope = Some(definition.memory.toString().toAsciiLower())
        po.background = Some(definition.background)
        po.color = definition.color
        po.isolationMode = definition.isolation
        po.sourcePath = Some(definition.sourcePath.toString())
        po.syncStatus = Some("synced")

        if (definition.tools.size > 0) {
            let sb = StringBuilder()
            sb.append("[")
            for (i in 0..definition.tools.size) {
                if (i > 0) { sb.append(",") }
                sb.append("\"${definition.tools[i]}\"")
            }
            sb.append("]")
            po.tools = Some(sb.toString())
        }

        if (definition.permissions.size > 0) {
            let sb = StringBuilder()
            sb.append("[")
            for (i in 0..definition.permissions.size) {
                if (i > 0) { sb.append(",") }
                sb.append("\"${definition.permissions[i].toString()}\"")
            }
            sb.append("]")
            po.permissions = Some(sb.toString())
        }

        po
    }

    private func mapPOToDefinition(po: AgentsPO): AgentDefinition {
        let agentType = parseAgentType(po.agentType)
        let memory = parseAgentMemory(if (let Some(s) <- po.memoryScope) { s } else { "user" })
        let tools = parseStringArray(if (let Some(s) <- po.tools) { s } else { "[]" })
        let permissions = parsePermissionsArray(if (let Some(s) <- po.permissions) { s } else { "[]" })
        let maxTurns = if (let Some(t) <- po.maxTurns) { Int64(t) } else { 200 }

        AgentDefinition(
            po.name,
            agentType,
            if (let Some(d) <- po.description) { d } else { "" },
            if (let Some(v) <- po.version) { v } else { "1.0.0" },
            po.author,
            tools,
            po.model,
            maxTurns,
            memory,
            if (let Some(b) <- po.background) { b } else { false },
            permissions,
            po.color,
            po.isolationMode,
            if (let Some(s) <- po.systemPrompt) { s } else { "" },
            Path(if (let Some(s) <- po.sourcePath) { s } else { "." }),
            Path(".")
        )
    }

    private func mapAgentToPO(agentId: String, agent: BaseAgent): AgentsPO {
        let po = AgentsPO()
        po.id = agentId
        po.name = agent.name
        po.systemPrompt = Some(agent.systemPrompt)
        po.updatedAt = DateTime.now()
        po
    }

    private func parseAgentType(typeStr: String): AgentType {
        match (typeStr.toAsciiLower()) {
            case "main" => AgentType.MAIN
            case "sub" => AgentType.SUB
            case "analyzer" => AgentType.ANALYZER
            case "comparator" => AgentType.COMPARATOR
            case "grader" => AgentType.GRADER
            case _ => AgentType.SUB
        }
    }

    private func parseAgentMemory(memoryStr: String): AgentMemory {
        match (memoryStr.toAsciiLower()) {
            case "user" => AgentMemory.USER
            case "project" => AgentMemory.PROJECT
            case "local" => AgentMemory.LOCAL
            case _ => AgentMemory.USER
        }
    }

    private func parseStringArray(jsonStr: String): Array<String> {
        try {
            let trimmed = jsonStr.trimAscii()
            if (trimmed.size < 2) { return [] }
            let inner = trimmed[1..trimmed.size - 1]
            if (inner.size == 0) { return [] }
            let items = ArrayList<String>()
            var current = StringBuilder()
            var inQuote = false
            for (i in 0..inner.size) {
                let ch = inner[i]
                if (ch == 34) {
                    inQuote = !inQuote
                } else if (ch == 44 && !inQuote) {
                    let val = current.toString().trimAscii()
                    if (val.size > 0) { items.add(val) }
                    current = StringBuilder()
                } else if (inQuote) {
                    current.append(Rune(ch))
                }
            }
            let lastVal = current.toString().trimAscii()
            if (lastVal.size > 0) { items.add(lastVal) }
            items.toArray()
        } catch (_: Exception) {
            []
        }
    }

    private func parsePermissionsArray(jsonStr: String): Array<AgentPermission> {
        let strings = parseStringArray(jsonStr)
        let perms = ArrayList<AgentPermission>()
        for (s in strings) {
            if (let Some(p) <- AgentPermission.parse(s)) {
                perms.add(p)
            }
        }
        perms.toArray()
    }
}