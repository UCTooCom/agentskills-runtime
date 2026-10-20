/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

public class InjectionDecisionRecord {
    public var skillName: String
    public var decision: SkillLoadDecision
    public var reason: String
    public var sessionId: String
    public var timestamp: Int64
    public var injectSource: InjectSource
    public var contentLevel: ContentLevel

    public init(
        skillName!: String = "",
        decision!: SkillLoadDecision = SkillLoadDecision.Loaded,
        reason!: String = "",
        sessionId!: String = "",
        timestamp!: Int64 = 0,
        injectSource!: InjectSource = InjectSource.AutoInit,
        contentLevel!: ContentLevel = ContentLevel.Full
    ) {
        this.skillName = skillName
        this.decision = decision
        this.reason = reason
        this.sessionId = sessionId
        this.timestamp = timestamp
        this.injectSource = injectSource
        this.contentLevel = contentLevel
    }
}