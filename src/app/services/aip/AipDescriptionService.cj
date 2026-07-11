/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.{AgentsPO, AgentSkillsPO, AipAgentDescriptionPO, AipAgentIdentityPO}
import magic.app.dao.uctoo.{AgentsDAO, AipAgentDescriptionDAO}
import magic.app.core.response.APIResult
import magic.app.services.aip.model.{AcsDescription, AcsSkill}
import magic.app.services.aip.acps.AcpsRegistryAdapter
import magic.log.LogUtils
import stdx.encoding.json.*
import f_util.UUID

public class AipDescriptionService {
    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    public func registerLocalDescription(agentId: String, acs: AcsDescription, creatorId: String): APIResult<AgentsPO> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<AgentsPO>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            if (agent.identityStatus == "none") {
                return APIResult<AgentsPO>(false, "智能体尚未注册本地身份，请先调用身份注册接口")
            }

            agent.name = acs.name
            agent.description = Some<String>(acs.description)
            agent.capabilities = acs.capabilities
            agent.defaultInputTypes = acs.defaultInputTypes
            agent.defaultOutputTypes = acs.defaultOutputTypes
            agent.discoverable = acs.discoverable
            agent.updatedAt = DateTime.now()

            let rows = getExecutor().updateAgents(agent)
            if (rows <= 0) {
                return APIResult<AgentsPO>(false, "更新智能体描述失败")
            }

            LogUtils.info("AipDescriptionService", "Local description registered for agent: ${agentId}")
            return APIResult<AgentsPO>(agent)
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionService", "registerLocalDescription failed: ${e.message}")
            return APIResult<AgentsPO>(false, "注册智能体描述失败: ${e.message}")
        }
    }

    public func getDescription(agentId: String): APIResult<AcsDescription> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<AcsDescription>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            let acs = AcsDescription()
            acs.name = agent.name
            acs.version = "1.0"
            acs.description = agent.description.getOrDefault({ => "" })
            acs.capabilities = agent.capabilities
            acs.defaultInputTypes = agent.defaultInputTypes
            acs.defaultOutputTypes = agent.defaultOutputTypes
            acs.discoverable = agent.discoverable

            let skills = getExecutor().setSql(
                "select * from agent_skills where id in (select skill_id from agent_has_skills where agent_id = '${agentId}' and deleted_at is null) and deleted_at is null"
            ).list<AgentSkillsPO>()
            acs.skills = AgentSkillAcsMapper.toAcsSkillList(skills)

            return APIResult<AcsDescription>(acs)
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionService", "getDescription failed: ${e.message}")
            return APIResult<AcsDescription>(false, "查询智能体描述失败: ${e.message}")
        }
    }

    public func registerInterconnectionDescription(agentId: String, acs: AcsDescription, creatorId: String): APIResult<AipAgentDescriptionPO> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<AipAgentDescriptionPO>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            if (agent.aic.isNone()) {
                return APIResult<AipAgentDescriptionPO>(false, "AIP-DESC-001: 智能体尚未注册互联身份(AIC)，请先完成身份注册")
            }
            let aic = agent.aic.getOrThrow()

            let identityOpt = getExecutor().setSql(
                "select * from aip_agent_identity where agent_id = '${agentId}' and deleted_at is null order by created_at desc limit 1"
            ).first<AipAgentIdentityPO>()
            if (identityOpt.isNone()) {
                return APIResult<AipAgentDescriptionPO>(false, "AIP-DESC-001: 未找到互联身份记录")
            }
            let identity = identityOpt.getOrThrow()

            let descOpt = getExecutor().setSql(
                "select * from aip_agent_description where agent_id = '${agentId}' and deleted_at is null order by created_at desc limit 1"
            ).first<AipAgentDescriptionPO>()

            let desc = AipAgentDescriptionPO()
            desc.agentIdentityId = identity.id
            desc.agentId = agentId
            desc.agentIdCode = aic
            desc.name = acs.name
            desc.version = acs.version
            desc.description = acs.description
            desc.capabilities = acs.capabilities.getOrDefault({ => "" })
            desc.defaultInputTypes = acs.defaultInputTypes.getOrDefault({ => "" })
            desc.defaultOutputTypes = acs.defaultOutputTypes.getOrDefault({ => "" })
            desc.skills = skillsToJsonString(acs.skills)
            desc.discoverable = acs.discoverable
            desc.publishStatus = "draft"
            desc.creator = creatorId
            desc.createdAt = DateTime.now()
            desc.updatedAt = DateTime.now()

            if (descOpt.isSome()) {
                let existing = descOpt.getOrThrow()
                desc.id = existing.id
                getExecutor().updateAipAgentDescription(desc)
            } else {
                let insertedId = getExecutor().insertAipAgentDescription(desc)
                desc.id = insertedId
            }

            let registryAdapter = AcpsRegistryAdapter()
            var reqMap = HashMap<String, JsonValue>()
            reqMap.add("agent_id_code", JsonString(aic))
            reqMap.add("name", JsonString(acs.name))
            reqMap.add("version", JsonString(acs.version))
            reqMap.add("description", JsonString(acs.description))
            reqMap.add("capabilities", JsonString(desc.capabilities))
            reqMap.add("default_input_types", JsonString(desc.defaultInputTypes))
            reqMap.add("default_output_types", JsonString(desc.defaultOutputTypes))
            reqMap.add("skills", JsonString(desc.skills))
            reqMap.add("discoverable", JsonBool(acs.discoverable))
            let reqBody = JsonObject(reqMap)

            let descResult = registryAdapter.submitDescription(aic, reqBody)
            if (descResult.isNone()) {
                LogUtils.warn("AipDescriptionService", "ACPs description sync failed for agent: ${agentId}, local record saved")
            }

            LogUtils.info("AipDescriptionService", "Interconnection description registered for agent: ${agentId}")
            return APIResult<AipAgentDescriptionPO>(desc)
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionService", "registerInterconnectionDescription failed: ${e.message}")
            return APIResult<AipAgentDescriptionPO>(false, "AIP-DESC-001: 互联描述注册失败: ${e.message}")
        }
    }

    public func publishDescription(agentId: String, creatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            if (agent.aic.isNone()) {
                return APIResult<Bool>(false, "AIP-DESC-002: 智能体尚未注册互联身份")
            }
            let aic = agent.aic.getOrThrow()

            let descOpt = getExecutor().setSql(
                "select * from aip_agent_description where agent_id = '${agentId}' and deleted_at is null order by created_at desc limit 1"
            ).first<AipAgentDescriptionPO>()
            if (descOpt.isNone()) {
                return APIResult<Bool>(false, "AIP-DESC-002: 智能体尚未注册互联描述，请先调用描述注册接口")
            }
            let desc = descOpt.getOrThrow()

            if (desc.publishStatus == "published") {
                return APIResult<Bool>(false, "AIP-DESC-002: 描述已发布，无需重复发布")
            }

            let registryAdapter = AcpsRegistryAdapter()
            let pubResult = registryAdapter.submitPublish(aic)
            if (pubResult.isNone()) {
                return APIResult<Bool>(false, "AIP-DESC-002: ACPs描述发布请求失败")
            }

            desc.publishStatus = "published"
            desc.publishedAt = Some<DateTime>(DateTime.now())
            desc.updatedAt = DateTime.now()
            getExecutor().updateAipAgentDescription(desc)

            LogUtils.info("AipDescriptionService", "Interconnection description published for agent: ${agentId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionService", "publishDescription failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-DESC-002: 互联描述发布失败: ${e.message}")
        }
    }

    public func updateInterconnectionDescription(agentId: String, acs: AcsDescription, creatorId: String): APIResult<Bool> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<Bool>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            if (agent.aic.isNone()) {
                return APIResult<Bool>(false, "AIP-DESC-003: 智能体尚未注册互联身份")
            }
            let aic = agent.aic.getOrThrow()

            let descOpt = getExecutor().setSql(
                "select * from aip_agent_description where agent_id = '${agentId}' and deleted_at is null order by created_at desc limit 1"
            ).first<AipAgentDescriptionPO>()
            if (descOpt.isNone()) {
                return APIResult<Bool>(false, "AIP-DESC-003: 智能体尚未注册互联描述，请先调用描述注册接口")
            }
            let desc = descOpt.getOrThrow()

            desc.name = acs.name
            desc.version = acs.version
            desc.description = acs.description
            desc.capabilities = acs.capabilities.getOrDefault({ => "" })
            desc.defaultInputTypes = acs.defaultInputTypes.getOrDefault({ => "" })
            desc.defaultOutputTypes = acs.defaultOutputTypes.getOrDefault({ => "" })
            desc.skills = skillsToJsonString(acs.skills)
            desc.discoverable = acs.discoverable
            desc.publishStatus = "draft"
            desc.updatedAt = DateTime.now()
            getExecutor().updateAipAgentDescription(desc)

            let registryAdapter = AcpsRegistryAdapter()
            var reqMap = HashMap<String, JsonValue>()
            reqMap.add("name", JsonString(acs.name))
            reqMap.add("version", JsonString(acs.version))
            reqMap.add("description", JsonString(acs.description))
            reqMap.add("capabilities", JsonString(desc.capabilities))
            reqMap.add("default_input_types", JsonString(desc.defaultInputTypes))
            reqMap.add("default_output_types", JsonString(desc.defaultOutputTypes))
            reqMap.add("skills", JsonString(desc.skills))
            reqMap.add("discoverable", JsonBool(acs.discoverable))
            let reqBody = JsonObject(reqMap)

            let updateResult = registryAdapter.submitDescription(aic, reqBody)
            if (updateResult.isNone()) {
                LogUtils.warn("AipDescriptionService", "ACPs description update sync failed for agent: ${agentId}, local record updated")
            }

            LogUtils.info("AipDescriptionService", "Interconnection description updated for agent: ${agentId}")
            return APIResult<Bool>(true)
        } catch (e: Exception) {
            LogUtils.error("AipDescriptionService", "updateInterconnectionDescription failed: ${e.message}")
            return APIResult<Bool>(false, "AIP-DESC-003: 互联描述更新失败: ${e.message}")
        }
    }

    private func skillsToJsonString(skills: ArrayList<AcsSkill>): String {
        var arr = JsonArray()
        for (skill in skills) {
            arr.add(skill.toJsonValue())
        }
        return arr.toString()
    }
}