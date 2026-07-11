/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import magic.app.models.uctoo.{UctooUserPO, AgentsPO, UserHasRolesPO, UserHasGroupPO, UserGroupPO}
import magic.app.dao.uctoo.{UctooUserDAO, AgentsDAO, UserHasRolesDAO, UserHasGroupDAO}
import magic.app.core.response.APIResult
import magic.app.services.aip.model.{LocalIdentityRequest, LocalIdentityResult, IdentityInfo}
import f_orm.sql.Pagination
import magic.log.LogUtils
import magic.app.services.aip.acps.{AcpsRegistryAdapter, AcpsCaAdapter}
import stdx.encoding.json.*
import f_util.UUID

public class AipIdentityService {
    private static let AGENTS_ROLE_ID = "a686ff1f-7fb4-48df-8609-2b2d5267c682"
    private static let AGENTS_GROUP_CODE = "agents"

    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    public func registerLocalIdentity(request: LocalIdentityRequest, creatorId: String): APIResult<LocalIdentityResult> {
        try {
            let agentId = UUID.random().toString()

            let shortId = if (agentId.size >= 8) { agentId[0..8] } else { agentId }
            let username = "agent_${shortId}"
            let email = "agent_${shortId}@agents.internal"
            let unloginablePassword = UUID.random().toString() + UUID.random().toString()

            let user = UctooUserPO()
            user.name = if (request.name.isEmpty()) { username } else { request.name }
            user.username = username
            user.email = email
            user.password = unloginablePassword
            user.userType = "agent"
            user.agentId = Some<String>(agentId)
            user.createdAt = DateTime.now()
            user.updatedAt = DateTime.now()

            let userId = getExecutor().insertUctooUser(user)
            if (userId.isEmpty()) {
                return APIResult<LocalIdentityResult>(false, "AIP-LOCAL-001: 创建智能体用户帐号失败")
            }
            user.id = userId

            let userRole = UserHasRolesPO()
            userRole.userId = userId
            userRole.roleId = AGENTS_ROLE_ID
            userRole.creator = creatorId
            userRole.createdAt = DateTime.now()
            getExecutor().insertUserHasRoles(userRole)

            let agentGroupOpt = getExecutor().setSql(
                "select * from user_group where code = '${AGENTS_GROUP_CODE}' and deleted_at is null limit 1"
            ).first<UserGroupPO>()
            if (agentGroupOpt.isSome()) {
                let userGroup = UserHasGroupPO()
                userGroup.groupableId = userId
                userGroup.groupId = agentGroupOpt.getOrThrow().id
                userGroup.creator = creatorId
                userGroup.createdAt = DateTime.now()
                getExecutor().insertUserHasGroup(userGroup)
            }

            let agent = AgentsPO()
            agent.id = agentId
            agent.name = user.name
            agent.agentType = if (request.agentType.isEmpty()) { "general" } else { request.agentType }
            agent.description = if (request.description.isSome()) { request.description } else { Some<String>("") }
            agent.userId = Some<String>(userId)
            agent.identityStatus = "none"
            agent.discoverable = true
            agent.createdAt = DateTime.now()
            agent.updatedAt = DateTime.now()
            agent.creator = creatorId

            let insertedAgentId = getExecutor().insertAgents(agent)
            if (insertedAgentId.isEmpty()) {
                LogUtils.warn("AipIdentityService", "Agent record inserted but id empty, agentId: ${agentId}")
            }

            let result = LocalIdentityResult()
            result.agentId = agentId
            result.userId = userId
            result.identityStatus = "none"
            result.createdAt = DateTime.now().toString()

            LogUtils.info("AipIdentityService", "Local identity registered: agentId=${agentId}, userId=${userId}")

            return APIResult<LocalIdentityResult>(result)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "registerLocalIdentity failed: ${e.message}")
            return APIResult<LocalIdentityResult>(false, "AIP-LOCAL-001: 创建智能体本地身份失败: ${e.message}")
        }
    }

    public func getIdentityInfo(agentId: String): APIResult<IdentityInfo> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<IdentityInfo>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            var userId = ""
            var userType = ""
            if (agent.userId.isSome()) {
                let uid = agent.userId.getOrThrow()
                let userOpt = getExecutor().findUctooUserById(uid)
                if (userOpt.isSome()) {
                    let user = userOpt.getOrThrow()
                    userId = user.id
                    userType = user.userType
                }
            }

            let result = IdentityInfo()
            result.agentId = agentId
            result.userId = userId
            result.userType = userType
            result.identityStatus = agent.identityStatus
            result.aic = agent.aic


            return APIResult<IdentityInfo>(result)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "getIdentityInfo failed: ${e.message}")
            return APIResult<IdentityInfo>(false, "查询智能体身份信息失败: ${e.message}")
        }
    }

    public func listIdentities(page: Int64, size: Int64): APIResult<Pagination<AgentsPO>> {
        try {
            let pagination = getExecutor().findDiscoverableAgentsPage(page, size)
            return APIResult<Pagination<AgentsPO>>(pagination)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "listIdentities failed: ${e.message}")
            return APIResult<Pagination<AgentsPO>>(false, "查询智能体列表失败: ${e.message}")
        }
    }

    public func disableAgent(agentId: String, operatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            agent.status = Some<Int32>(0)
            agent.updatedAt = DateTime.now()
            getExecutor().updateAgents(agent)

            if (agent.userId.isSome()) {
                let userId = agent.userId.getOrThrow()
                let userOpt = getExecutor().findUctooUserById(userId)
                if (userOpt.isSome()) {
                    let user = userOpt.getOrThrow()
                    user.status = 0
                    user.updatedAt = DateTime.now()
                    getExecutor().updateUctooUser(user)
                }
            }

            LogUtils.info("AipIdentityService", "Agent disabled: ${agentId} by ${operatorId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "disableAgent failed: ${e.message}")
            return APIResult<Bool>(false, "禁用智能体失败: ${e.message}")
        }
    }

    public func enableAgent(agentId: String, operatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            agent.status = Some<Int32>(1)
            agent.updatedAt = DateTime.now()
            getExecutor().updateAgents(agent)

            if (agent.userId.isSome()) {
                let userId = agent.userId.getOrThrow()
                let userOpt = getExecutor().findUctooUserById(userId)
                if (userOpt.isSome()) {
                    let user = userOpt.getOrThrow()
                    user.status = 1
                    user.updatedAt = DateTime.now()
                    getExecutor().updateUctooUser(user)
                }
            }

            LogUtils.info("AipIdentityService", "Agent enabled: ${agentId} by ${operatorId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "enableAgent failed: ${e.message}")
            return APIResult<Bool>(false, "启用智能体失败: ${e.message}")
        }
    }

    public func registerInterconnectionIdentity(agentId: String, operatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            let registryAdapter = AcpsRegistryAdapter()
            var reqMap = HashMap<String, JsonValue>()
            reqMap.add("agent_id", JsonString(agentId))
            reqMap.add("agent_name", JsonString(agent.name))
            reqMap.add("agent_type", JsonString(agent.agentType))
            let reqBody = JsonObject(reqMap)

            let regResult = registryAdapter.submitRegistration(reqBody)
            if (regResult.isNone()) {
                return APIResult<Bool>(false, "AIP-INTER-001: ACPs注册服务请求失败")
            }

            let regJson = JsonValue.fromStr(regResult.getOrThrow())
            if (!(regJson is JsonObject)) {
                return APIResult<Bool>(false, "AIP-INTER-001: ACPs注册服务返回格式错误")
            }
            let regObj = regJson.asObject()
            let aicVal = regObj.get("aic")
            if (aicVal.isNone()) {
                return APIResult<Bool>(false, "AIP-INTER-001: ACPs注册服务未返回AIC")
            }
            let aicStr = aicVal.getOrThrow() as String
            var aic = ""
            if (let Some(s) <- aicStr) { aic = s }

            let aicValidation = AicValidator.validate(aic)
            if (!aicValidation.valid) {
                LogUtils.warn("AipIdentityService", "AIC validation warning: ${aicValidation.errorMsg}, aic=${aic}")
            }

            agent.aic = Some<String>(aic)
            agent.identityStatus = "registered"
            agent.aipRegisteredAt = Some<DateTime>(DateTime.now())
            agent.updatedAt = DateTime.now()
            getExecutor().updateAgents(agent)

            LogUtils.info("AipIdentityService", "Interconnection identity registered: agentId=${agentId}, aic=${aic}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "registerInterconnectionIdentity failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-INTER-001: 互联身份注册失败: ${e.message}")
        }
    }

    public func updateIdentity(agentId: String, operatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()
            if (agent.aic.isNone()) {
                return APIResult<Bool>(false, "智能体尚未注册互联身份")
            }
            let aic = agent.aic.getOrThrow()

            let registryAdapter = AcpsRegistryAdapter()
            var reqMap = HashMap<String, JsonValue>()
            reqMap.add("agent_name", JsonString(agent.name))
            reqMap.add("agent_type", JsonString(agent.agentType))
            let reqBody = JsonObject(reqMap)

            let result = registryAdapter.submitUpdate(aic, reqBody)
            if (result.isNone()) {
                return APIResult<Bool>(false, "AIP-INTER-002: ACPs注册服务更新请求失败")
            }

            agent.identityStatus = "updated"
            agent.updatedAt = DateTime.now()
            getExecutor().updateAgents(agent)

            LogUtils.info("AipIdentityService", "Interconnection identity updated: agentId=${agentId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "updateIdentity failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-INTER-002: 互联身份更新失败: ${e.message}")
        }
    }

    public func lockIdentity(agentId: String, operatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            agent.identityStatus = "locked"
            agent.updatedAt = DateTime.now()
            getExecutor().updateAgents(agent)

            LogUtils.info("AipIdentityService", "Interconnection identity locked: agentId=${agentId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "lockIdentity failed: ${e.message}")
            return APIResult<Bool>(false, "锁定互联身份失败: ${e.message}")
        }
    }

    public func unlockIdentity(agentId: String, operatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            agent.identityStatus = "registered"
            agent.updatedAt = DateTime.now()
            getExecutor().updateAgents(agent)

            LogUtils.info("AipIdentityService", "Interconnection identity unlocked: agentId=${agentId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "unlockIdentity failed: ${e.message}")
            return APIResult<Bool>(false, "解锁互联身份失败: ${e.message}")
        }
    }

    public func revokeIdentity(agentId: String, operatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()
            if (agent.aic.isSome()) {
                let registryAdapter = AcpsRegistryAdapter()
                registryAdapter.submitRevocation(agent.aic.getOrThrow())
            }

            agent.aic = None<String>
            agent.identityStatus = "revoked"
            agent.aipRegisteredAt = None<DateTime>
            agent.updatedAt = DateTime.now()
            getExecutor().updateAgents(agent)

            LogUtils.info("AipIdentityService", "Interconnection identity revoked: agentId=${agentId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipIdentityService", "revokeIdentity failed: ${e.message}")
            return APIResult<Bool>(false, "注销互联身份失败: ${e.message}")
        }
    }
}