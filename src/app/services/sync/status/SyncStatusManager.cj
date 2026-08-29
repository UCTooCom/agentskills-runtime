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

    /**
     * 按 sourcePath 更新 agent_skills 同步状态。
     * SyncManager / RetryManager 传的 entityId 是 sourcePath（文件路径），不是 UUID，
     * 必须先按 sourcePath 找行再 update，避免 "无效的类型 uuid 输入语法" 错误。
     * 找不到行时返回 false（新技能首次同步时 insert 还未发生，属正常场景，不打 ERROR）。
     */
    public func updateAgentSkillSyncStatusBySourcePath(sourcePath: String, status: String): Bool {
        mutex.lock()
        try {
            let skillsDAO = ORM.executor() as AgentSkillsDAO
            if (let Some(dao) <- skillsDAO) {
                let found = this.findAgentSkillBySourcePath(dao, sourcePath)
                if (let Some(skill) <- found) {
                    skill.syncStatus = Some(status)
                    skill.lastSyncAt = Some(DateTime.now())
                    dao.updateAgentSkills(skill)
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("SyncStatusManager.updateAgentSkillSyncStatusBySourcePath failed: ${e.message}")
            return false
        } finally {
            mutex.unlock()
        }
    }

    /**
     * 按 sourcePath 更新 agents 同步状态（与 updateAgentSkillSyncStatusBySourcePath 同构）。
     */
    public func updateAgentSyncStatusBySourcePath(sourcePath: String, status: String): Bool {
        mutex.lock()
        try {
            let agentsDAO = ORM.executor() as AgentsDAO
            if (let Some(dao) <- agentsDAO) {
                let found = this.findAgentBySourcePath(dao, sourcePath)
                if (let Some(agent) <- found) {
                    agent.syncStatus = Some(status)
                    agent.lastSyncAt = Some(DateTime.now())
                    dao.updateAgents(agent)
                    return true
                }
            }
            return false
        } catch (e: Exception) {
            LogUtils.error("SyncStatusManager.updateAgentSyncStatusBySourcePath failed: ${e.message}")
            return false
        } finally {
            mutex.unlock()
        }
    }

    private func findAgentSkillBySourcePath(dao: AgentSkillsDAO, sourcePath: String): Option<AgentSkillsPO> {
        let skills = dao.listAllAgentSkills()
        for (skill in skills) {
            match (skill.sourcePath) {
                case Some(sp) =>
                    if (sp == sourcePath) {
                        return Some(skill)
                    }
                case None => ()
            }
        }
        return None
    }

    private func findAgentBySourcePath(dao: AgentsDAO, sourcePath: String): Option<AgentsPO> {
        let agents = dao.listAllAgents()
        for (agent in agents) {
            match (agent.sourcePath) {
                case Some(sp) =>
                    if (sp == sourcePath) {
                        return Some(agent)
                    }
                case None => ()
            }
        }
        return None
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

    public func markAgentPendingBySourcePath(sourcePath: String): Bool {
        return updateAgentSyncStatusBySourcePath(sourcePath, "pending")
    }

    public func markAgentSyncedBySourcePath(sourcePath: String): Bool {
        return updateAgentSyncStatusBySourcePath(sourcePath, "synced")
    }

    public func markAgentErrorBySourcePath(sourcePath: String): Bool {
        return updateAgentSyncStatusBySourcePath(sourcePath, "error")
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

    public func markAgentSkillPendingBySourcePath(sourcePath: String): Bool {
        return updateAgentSkillSyncStatusBySourcePath(sourcePath, "pending")
    }

    public func markAgentSkillSyncedBySourcePath(sourcePath: String): Bool {
        return updateAgentSkillSyncStatusBySourcePath(sourcePath, "synced")
    }

    public func markAgentSkillErrorBySourcePath(sourcePath: String): Bool {
        return updateAgentSkillSyncStatusBySourcePath(sourcePath, "error")
    }
}
