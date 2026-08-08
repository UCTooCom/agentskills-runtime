/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_group

import magic.core.agent.Agent
import magic.agent.base.AbsAgent
import magic.agent.base.BaseAgent
import std.collection.ArrayList

public func agentTeams(manager: Agent, leaders: Array<Agent>, workers!: Array<Agent> = Array<Agent>()): ManagerGroup {
    let config = TeamConfig()
    config.name = "team-${manager.name}"
    config.description = "Team created via agentTeams DSL"
    config.manager = AgentRoleConfig()
    config.manager.agentType = manager.name
    let leaderList = ArrayList<Agent>()
    for (leader in leaders) {
        leaderList.add(leader)
    }
    let workerList = ArrayList<Agent>()
    for (worker in workers) {
        workerList.add(worker)
    }
    return ManagerGroup(config, manager, leaderList, workerList)
}

public func managerGroup(manager: Agent, config: TeamConfig): ManagerGroup {
    let leaderList = ArrayList<Agent>()
    let workerList = ArrayList<Agent>()
    ManagerGroup(config, manager, leaderList, workerList)
}
