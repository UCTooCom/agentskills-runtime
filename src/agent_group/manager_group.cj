/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_group

import magic.core.agent.{Agent, AgentRequest, AgentResponse, AsyncAgentResponse}
import magic.agent.base.BaseAgent
import magic.tool.AgentAsTool
import magic.log.LogUtils

import std.collection.ArrayList

public class ManagerGroup <: AgentGroup {
    private let manager: Agent
    private let leaders: ArrayList<Agent>
    private let workers: ArrayList<Agent>
    private let config: TeamConfig
    private let messenger: TeamMessenger

    public init(config: TeamConfig, manager: Agent, leaders: ArrayList<Agent>, workers: ArrayList<Agent>) {
        this.config = config
        this.manager = manager
        this.leaders = leaders
        this.workers = workers
        this.messenger = TeamMessenger()

        assembleTeam()
    }

    private func assembleTeam(): Unit {
        for (leader in leaders) {
            manager.toolManager.addTool(AgentAsTool(leader))
        }
        for (worker in workers) {
            let parentIdx = findParentLeaderIdx(worker)
            if (parentIdx >= 0 && parentIdx < leaders.size) {
                leaders[parentIdx].toolManager.addTool(AgentAsTool(worker))
            } else {
                manager.toolManager.addTool(AgentAsTool(worker))
            }
        }
        LogUtils.info("[ManagerGroup] Team assembled: ${config.name}, 1 manager, ${leaders.size} leaders, ${workers.size} workers")
    }

    private func findParentLeaderIdx(worker: Agent): Int64 {
        let workerName = worker.name
        for (i in 0..config.leaders.size) {
            let leaderCfg = config.leaders[i]
            for (wCfg in leaderCfg.workers) {
                if (wCfg.agentType == workerName || workerName.contains(wCfg.agentType)) {
                    return i
                }
            }
        }
        return -1
    }

    override public func chat(request: AgentRequest): AgentResponse {
        return chat(request, maxRound: 14)
    }

    override public func chat(request: AgentRequest, maxRound!: Int64): AgentResponse {
        LogUtils.info("[ManagerGroup] Manager '${manager.name}' receiving task: ${request.question}")

        let assignMsg = TeamMessage()
        assignMsg.sender = manager.name
        assignMsg.messageType = MessageType.TASK_ASSIGN
        assignMsg.payload = request.question
        messenger.broadcast(manager.name, AgentRole.Manager, assignMsg)

        let response = manager.chat(request)

        let resultMsg = TeamMessage()
        resultMsg.sender = manager.name
        resultMsg.messageType = MessageType.RESULT_REPORT
        resultMsg.payload = response.content
        messenger.broadcast(manager.name, AgentRole.Manager, resultMsg)

        return response
    }

    override public func asyncChat(request: AgentRequest): AsyncAgentResponse {
        return manager.asyncChat(request)
    }

    override public operator func [](memberName: String): Agent {
        if (manager.name == memberName) {
            return manager
        }
        for (leader in leaders) {
            if (leader.name == memberName) {
                return leader
            }
        }
        for (worker in workers) {
            if (worker.name == memberName) {
                return worker
            }
        }
        throw Exception("Access unknown agent member: ${memberName}")
    }

    public func getManager(): Agent {
        return manager
    }

    public func getLeaders(): ArrayList<Agent> {
        return leaders
    }

    public func getWorkers(): ArrayList<Agent> {
        return workers
    }

    public func getConfig(): TeamConfig {
        return config
    }

    public func getMessenger(): TeamMessenger {
        return messenger
    }
}