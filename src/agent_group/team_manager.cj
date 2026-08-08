/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_group

import std.collection.{ArrayList, HashMap}
import magic.core.agent.{Agent, AgentRequest, AgentResponse}
import magic.core.model.ChatModel
import magic.agent.base.BaseAgent
import magic.tool.AgentAsTool
import magic.log.LogUtils

public enum TeamStatus {
    | Draft
    | Initializing
    | Ready
    | Running
    | Paused
    | Completed
    | Failed
}

public class TeamInfo {
    public var teamId: String = ""
    public var name: String = ""
    public var status: TeamStatus = TeamStatus.Draft
    public var managerAgentId: String = ""
    public var leaderCount: Int64 = 0
    public var workerCount: Int64 = 0

    public init() {}
}

public class TeamManager {
    private let teams = HashMap<String, ManagerGroup>()
    private let teamStatuses = HashMap<String, TeamStatus>()
    private let parser = YamlTeamConfigParser()

    public init() {}

    public func createTeam(config: TeamConfig): Option<ManagerGroup> {
        let teamId = config.name
        teamStatuses.add(teamId, TeamStatus.Initializing)
        LogUtils.info("[TeamManager] Creating team: ${teamId}")

        try {
            let manager = createAgent(config.manager.agentType, "${config.name}-manager")

            let leaders = ArrayList<Agent>()
            for (i in 0..config.leaders.size) {
                let leaderCfg = config.leaders[i]
                let leader = createAgent(leaderCfg.agentType, "${config.name}-leader-${i}")
                leaders.add(leader)

                for (j in 0..leaderCfg.workers.size) {
                    let workerCfg = leaderCfg.workers[j]
                    leader.toolManager.addTool(AgentAsTool(createAgent(workerCfg.agentType, "${config.name}-worker-${i}-${j}")))
                }
            }

            let group = ManagerGroup(config, manager, leaders, ArrayList<Agent>())
            teams.add(teamId, group)
            teamStatuses.add(teamId, TeamStatus.Ready)

            LogUtils.info("[TeamManager] Team created: ${teamId}")
            return Some(group)
        } catch (e: Exception) {
            teamStatuses.add(teamId, TeamStatus.Failed)
            LogUtils.error("[TeamManager] Failed to create team: ${e.message}")
            return None
        }
    }

    public func createTeamFromYaml(yamlContent: String): Option<ManagerGroup> {
        if (let Some(config) <- parser.parseFromString(yamlContent)) {
            let validation = parser.validate(config)
            if (!validation.valid) {
                LogUtils.error("[TeamManager] Invalid team config: ${String.join(validation.errors.toArray(), delimiter: ", ")}")
                return None
            }
            return createTeam(config)
        }
        return None
    }

    public func createTeamFromYamlFile(filePath: String): Option<ManagerGroup> {
        if (let Some(config) <- parser.parseFromFile(filePath)) {
            let validation = parser.validate(config)
            if (!validation.valid) {
                LogUtils.error("[TeamManager] Invalid team config: ${String.join(validation.errors.toArray(), delimiter: ", ")}")
                return None
            }
            return createTeam(config)
        }
        return None
    }

    public func destroyTeam(teamId: String): Unit {
        teams.remove(teamId)
        teamStatuses.remove(teamId)
        LogUtils.info("[TeamManager] Team destroyed: ${teamId}")
    }

    public func addWorker(teamId: String, leaderIdx: Int64, workerConfig: AgentRoleConfig): Option<Agent> {
        if (let Some(group) <- teams.get(teamId)) {
            let worker = createAgent(workerConfig.agentType, "${teamId}-worker-dynamic-${group.getWorkers().size}")
            if (leaderIdx >= 0 && leaderIdx < group.getLeaders().size) {
                group.getLeaders()[leaderIdx].toolManager.addTool(AgentAsTool(worker))
            }
            group.getWorkers().add(worker)
            LogUtils.info("[TeamManager] Worker added to team: ${teamId}")
            return Some(worker)
        }
        return None
    }

    public func removeWorker(teamId: String, workerId: String): Unit {
        if (let Some(group) <- teams.get(teamId)) {
            let workers = group.getWorkers()
            var idx: Int64 = -1
            for (i in 0..workers.size) {
                if (workers[i].name == workerId) {
                    idx = i
                    break
                }
            }
            if (idx >= 0) {
                let removed = workers.remove(at: idx)
                LogUtils.info("[TeamManager] Worker removed from team: ${teamId}")
            }
        }
    }

    public func getTeamStatus(teamId: String): Option<TeamStatus> {
        teamStatuses.get(teamId)
    }

    public func setTeamStatus(teamId: String, status: TeamStatus): Unit {
        teamStatuses.add(teamId, status)
    }

    public func listTeams(): ArrayList<TeamInfo> {
        let result = ArrayList<TeamInfo>()
        for ((teamId, group) in teams) {
            let info = TeamInfo()
            info.teamId = teamId
            info.name = group.getConfig().name
            let statusOpt = teamStatuses.get(teamId)
            if (statusOpt.isSome()) {
                info.status = statusOpt.getOrThrow()
            }
            info.leaderCount = group.getLeaders().size
            info.workerCount = group.getWorkers().size
            result.add(info)
        }
        return result
    }

    public func getTeam(teamId: String): Option<ManagerGroup> {
        teams.get(teamId)
    }

    private func createAgent(agentType: String, name: String): Agent {
        BaseAgent(
            model: unsafe { zeroValue<ChatModel>() },
            name: name,
            description: "Agent role: ${agentType}"
        )
    }

    private static func teamStatusToString(status: TeamStatus): String {
        match (status) {
            case TeamStatus.Draft => "draft"
            case TeamStatus.Initializing => "initializing"
            case TeamStatus.Ready => "ready"
            case TeamStatus.Running => "running"
            case TeamStatus.Paused => "paused"
            case TeamStatus.Completed => "completed"
            case TeamStatus.Failed => "failed"
        }
    }
}
