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
import magic.config.Config as AppConfig
import magic.log.LogUtils

/// agent 自动登录模式：
/// - Local：本地独立运行的 agent 用 config 密钥（jwtSecret，与用户同钥）签发，可被现有 DeserializeUserMiddleware 验过；
/// - Interconnection：GB/Z 185 智能体互联模式，使用专用 aip-agent-secret-key（保持 AIP 专用，不并入本地校验）。
public enum AgentLoginMode {
    | Local
    | Interconnection
}

public class AgentAuthService {
    private let jwtUtil: JWTUtil
    // 本地模式签发 agent token 用 config 密钥（与用户 token 同源），使 agent token 可被现有 DeserializeUserMiddleware 验过
    private let localJwtUtil: JWTUtil

    public init() {
        this.jwtUtil = JWTUtil("aip-agent-secret-key", 172800, 604800)
        this.localJwtUtil = JWTUtil(AppConfig.jwtSecret, 172800, 604800)
    }

    private func getExecutor(): SqlExecutor {
        ORM.executor()
    }

    public func agentAutoLogin(agentId: String, mode!: AgentLoginMode = AgentLoginMode.Interconnection): APIResult<AgentLoginResult> {
        try {
            let agentOpt = getExecutor().findAgentsById(agentId)
            if (agentOpt.isNone()) {
                return APIResult<AgentLoginResult>(false, "智能体不存在")
            }
            let agent = agentOpt.getOrThrow()

            // agents.user_id 缺失时按 uctoo_user.agent_id 反查（双账号绑定的另一条路径）：
            // DDL 20260921_dual_identity_owner_user_id.sql 会同时建帐号并回填 agents.user_id，
            // 这里保留反查兜底，避免历史/手工建的智能体因列未回填就永远无法自动登录。
            var userOpt: Option<UctooUserPO> = None<UctooUserPO>
            if (agent.userId.isSome()) {
                userOpt = getExecutor().findUctooUserById(agent.userId.getOrThrow())
            } else {
                userOpt = getExecutor().findUctooUserByAgentId(agentId)
            }
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

            // 按模式签发：Interconnection 用 aip 专用密钥；Local 用 config 密钥（与用户同钥）
            let token = match (mode) {
                case AgentLoginMode.Interconnection => generateAgentToken(user.id)
                case AgentLoginMode.Local => localJwtUtil.generateAccessToken(user.id, "agent_auto_${dateTimeToTimestamp(DateTime.now())}")
            }
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
