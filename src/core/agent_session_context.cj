/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.core

/**
 * 一次 WebMCP 会话的上下文，供 agent 内部工具（如长程任务工具）提交任务时使用。
 *
 * 为什么需要它：SkillAwareAgent 里的工具此前拿不到会话的 userId / sessionId / agentId，
 * 导致 long-running-task 工具只能走 BaseSkill 的占位 execute()。把这三个值封装成上下文、
 * 在构造 agent 时注入，工具即可直接调用 LongTaskApiService.submitTask，
 * 让"调用 long-running-task 工具"这条自然语言指令真正触发长程任务。
 *
 * 放在 magic.core 而非 magic.skill：magic.skill 已经依赖 magic.tool，
 * 若上下文放 skill 包、再由 tool 包引用会形成循环依赖。magic.core 是更底层的公共包。
 */
public class AgentSessionContext {
    public var userId: String
    public var sessionId: String
    public var agentId: String

    public init(userId!: String, sessionId!: String, agentId!: String) {
        this.userId = userId
        this.sessionId = sessionId
        this.agentId = agentId
    }

    // setSessionInfo 在 agent 构造之后才拿到真实用户信息，故需可更新。
    // agent 与长程任务工具持有同一引用，更新后双方都能看到最新值。
    public func update(userId!: String, sessionId!: String, agentId!: String): Unit {
        this.userId = userId
        this.sessionId = sessionId
        this.agentId = agentId
    }
}
