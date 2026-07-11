/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.aip

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.uctoo.{UctooUserPO, AgentsPO}
import magic.app.dao.uctoo.{UctooUserDAO, AgentsDAO}
import magic.app.core.response.APIResult
import magic.app.services.aip.model.AgentLoginResult
import magic.app.utils.auth.JWTUtil
import magic.log.LogUtils

public class AgentAuthService {
    private let jwtUtil: JWTUtil

    public init() {
        this.jwtUtil = JWTUtil("aip-agent-secret-key", 172800, 604800)
    }

    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    public func agentAutoLogin(agentId: String): APIResult<AgentLoginResult> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<AgentLoginResult>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            if (agent.userId.isNone()) {
                return APIResult<AgentLoginResult>(false, "智能体未关联用户帐号")
            }

            let userOpt = getExecutor().findUctooUserById(agent.userId.getOrThrow())
            if (userOpt.isNone()) {
                return APIResult<AgentLoginResult>(false, "智能体关联的用户帐号不存在")
            }
            let user = userOpt.getOrThrow()

            if (user.userType != "agent") {
                return APIResult<AgentLoginResult>(false, "AUTH-AGENT-001: 该帐号不是智能体帐号，无法使用自动登录")
            }

            let statusVal = match (agent.status) {
                case Some(v) => Int64(v)
                case None => 0
            }
            if (statusVal != 1) {
                return APIResult<AgentLoginResult>(false, "智能体未处于运行状态")
            }

            let token = generateAgentToken(user.id)
            user.accessToken = Some(token)
            user.updatedAt = DateTime.now()
            getExecutor().updateUctooUser(user)

            let result = AgentLoginResult(token, "agent_auto", 172800)
            return APIResult<AgentLoginResult>(result)
        } catch (e: Exception) {
            LogUtils.error("Agent auto login failed: ${e.message}")
            return APIResult<AgentLoginResult>(false, "智能体自动登录失败: ${e.message}")
        }
    }

    public func generateAgentToken(userId: String): String {
        let sessionId = "agent_auto_${dateTimeToTimestamp(DateTime.now())}"
        return jwtUtil.generateAccessToken(userId, sessionId)
    }

    private func dateTimeToTimestamp(dt: DateTime): Int64 {
        let epoch = DateTime.ofEpoch(second: 0, nanosecond: 0)
        let duration = dt - epoch
        duration.toSeconds()
    }
}
