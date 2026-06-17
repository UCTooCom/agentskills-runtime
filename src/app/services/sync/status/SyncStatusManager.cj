package magic.app.services.sync.status

import std.time.DateTime
import std.sync.Mutex
import f_orm.*
import magic.app.dao.uctoo.{AgentsDAO, AgentSkillsDAO}
import magic.app.models.uctoo.{AgentsPO, AgentSkillsPO}
import magic.app.services.sync.model.{SyncStatusSummary, SyncEntityStatus, SyncStatus}
import magic.log.LogUtils

public class SyncStatusManager {
    private let mutex = Mutex()

    public init() {}

    public func getAgentStatus(sourcePath: String): Option<SyncEntityStatus> {
        mutex.lock()
        try {
            let agentsDAO = ORM.executor() as AgentsDAO
            if (let Some(dao) <- agentsDAO) {
                let agents = dao.listAllAgents()
                for (agent in agents) {
                    match (agent.sourcePath) {
                        case Some(sp) =>
                            if (sp == sourcePath) {
                                let status = SyncEntityStatus()
                                status.entityType = "agent"
                                status.entityId = agent.id
                                status.sourcePath = sp
                                match (agent.syncStatus) {
                                    case Some(s) => status.syncStatus = s
                                    case None => status.syncStatus = "pending"
                                }
                                status.lastSyncAt = agent.lastSyncAt
                                return Some(status)
                            }
                        case None => ()
                    }
                }
            }
            return None
        } catch (e: Exception) {
            LogUtils.error("SyncStatusManager.getAgentStatus failed: ${e.message}")
            return None
        } finally {
            mutex.unlock()
        }
    }

    public func getAgentSkillStatus(sourcePath: String): Option<SyncEntityStatus> {
        mutex.lock()
        try {
            let skillsDAO = ORM.executor() as AgentSkillsDAO
            if (let Some(dao) <- skillsDAO) {
                let skills = dao.listAllAgentSkills()
                for (skill in skills) {
                    match (skill.sourcePath) {
                        case Some(sp) =>
                            if (sp == sourcePath) {
                                let status = SyncEntityStatus()
                                status.entityType = "agent_skill"
                                status.entityId = skill.id
                                status.sourcePath = sp
                                match (skill.syncStatus) {
                                    case Some(s) => status.syncStatus = s
                                    case None => status.syncStatus = "pending"
                                }
                                status.lastSyncAt = skill.lastSyncAt
                                return Some(status)
                            }
                        case None => ()
                    }
                }
            }
            return None
        } catch (e: Exception) {
            LogUtils.error("SyncStatusManager.getAgentSkillStatus failed: ${e.message}")
            return None
        } finally {
            mutex.unlock()
        }
    }

    public func updateAgentSyncStatus(id: String, status: String): Bool {
        mutex.lock()
        try {
            let agentsDAO = ORM.executor() as AgentsDAO
            if (let Some(dao) <- agentsDAO) {
                if (let Some(agent) <- dao.findAgentsById(id)) {
                    agent.syncStatus = Some(status)
                    agent.lastSyncAt = Some(DateTime.now())
                    dao.updateAgents(agent)
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("SyncStatusManager.updateAgentSyncStatus failed: ${e.message}")
            return false
        } finally {
            mutex.unlock()
        }
    }

    public func updateAgentSkillSyncStatus(id: String, status: String): Bool {
        mutex.lock()
        try {
            let skillsDAO = ORM.executor() as AgentSkillsDAO
            if (let Some(dao) <- skillsDAO) {
                if (let Some(skill) <- dao.findAgentSkillsById(id)) {
                    skill.syncStatus = Some(status)
                    skill.lastSyncAt = Some(DateTime.now())
                    dao.updateAgentSkills(skill)
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("SyncStatusManager.updateAgentSkillSyncStatus failed: ${e.message}")
            return false
        } finally {
            mutex.unlock()
        }
    }

    public func getAgentSummary(): SyncStatusSummary {
        let summary = SyncStatusSummary()
        try {
            let agentsDAO = ORM.executor() as AgentsDAO
            if (let Some(dao) <- agentsDAO) {
                let agents = dao.listAllAgents()
                summary.totalEntities = Int32(agents.size)
                for (agent in agents) {
                    let statusStr = match (agent.syncStatus) {
                        case Some(s) => s
                        case None => "pending"
                    }
                    if (statusStr == "synced") {
                        summary.syncedCount++
                    } else if (statusStr == "pending") {
                        summary.pendingCount++
                    } else if (statusStr == "error") {
                        summary.failedCount++
                    } else if (statusStr == "dependency_missing") {
                        summary.dependencyMissingCount++
                    }
                    if (let Some(lsa) <- agent.lastSyncAt) {
                        match (summary.lastSyncAt) {
                            case Some(current) =>
                                if (lsa > current) {
                                    summary.lastSyncAt = Some(lsa)
                                }
                            case None =>
                                summary.lastSyncAt = Some(lsa)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            LogUtils.error("SyncStatusManager.getAgentSummary failed: ${e.message}")
        }
        return summary
    }

    public func getAgentSkillSummary(): SyncStatusSummary {
        let summary = SyncStatusSummary()
        try {
            let skillsDAO = ORM.executor() as AgentSkillsDAO
            if (let Some(dao) <- skillsDAO) {
                let skills = dao.listAllAgentSkills()
                summary.totalEntities = Int32(skills.size)
                for (skill in skills) {
                    let statusStr = match (skill.syncStatus) {
                        case Some(s) => s
                        case None => "pending"
                    }
                    if (statusStr == "synced") {
                        summary.syncedCount++
                    } else if (statusStr == "pending") {
                        summary.pendingCount++
                    } else if (statusStr == "error") {
                        summary.failedCount++
                    } else if (statusStr == "dependency_missing") {
                        summary.dependencyMissingCount++
                    }
                    if (let Some(lsa) <- skill.lastSyncAt) {
                        match (summary.lastSyncAt) {
                            case Some(current) =>
                                if (lsa > current) {
                                    summary.lastSyncAt = Some(lsa)
                                }
                            case None =>
                                summary.lastSyncAt = Some(lsa)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            LogUtils.error("SyncStatusManager.getAgentSkillSummary failed: ${e.message}")
        }
        return summary
    }

    public func markAgentPending(id: String): Bool {
        return updateAgentSyncStatus(id, "pending")
    }

    public func markAgentSynced(id: String): Bool {
        return updateAgentSyncStatus(id, "synced")
    }

    public func markAgentError(id: String): Bool {
        return updateAgentSyncStatus(id, "error")
    }

    public func markAgentSkillPending(id: String): Bool {
        return updateAgentSkillSyncStatus(id, "pending")
    }

    public func markAgentSkillSynced(id: String): Bool {
        return updateAgentSkillSyncStatus(id, "synced")
    }

    public func markAgentSkillError(id: String): Bool {
        return updateAgentSkillSyncStatus(id, "error")
    }
}
