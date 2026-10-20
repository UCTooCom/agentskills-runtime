/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

public class AutoInjectConfig {
    public var autoInjectEnabled: Bool
    public var taskMatchThreshold: Float64
    public var taskMatchStrategy: TaskMatchStrategy
    public var maxAutoInjectSkills: Int64
    public var fallbackToolRetained: Bool
    public var dedupOnReinject: Bool

    public init(
        autoInjectEnabled!: Bool = true,
        taskMatchThreshold!: Float64 = 0.3,  // T093: 原 0.6 在中文 bigram 分词下系统性欠注入，下调至 0.3（仍可由调用方覆盖）
        taskMatchStrategy!: TaskMatchStrategy = TaskMatchStrategy.Keyword,
        maxAutoInjectSkills!: Int64 = 5,
        fallbackToolRetained!: Bool = true,
        dedupOnReinject!: Bool = true
    ) {
        this.autoInjectEnabled = autoInjectEnabled
        this.taskMatchThreshold = taskMatchThreshold
        this.taskMatchStrategy = taskMatchStrategy
        this.maxAutoInjectSkills = maxAutoInjectSkills
        this.fallbackToolRetained = fallbackToolRetained
        this.dedupOnReinject = dedupOnReinject
    }

    public static func default(): AutoInjectConfig {
        return AutoInjectConfig()
    }
}