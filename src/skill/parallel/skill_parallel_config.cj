/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

public class SkillParallelConfig {
    public var totalBudgetTokens: Int64
    public var reservedForAlwaysOn: Float64
    public var defaultLoadPolicy: LoadPolicy
    public var defaultPriority: SkillPriority
    public var defaultContextBudgetTokens: Int64
    public var enableConflictFilter: Bool
    public var enableBudgetAllocator: Bool
    // TG26/T103：profile 层独立预算，不挤占 capability 预算
    public var profileBudgetTokens: Int64

    public init(
        totalBudgetTokens!: Int64 = 8192,
        reservedForAlwaysOn!: Float64 = 0.3,
        defaultLoadPolicy!: LoadPolicy = LoadPolicy.OnDemand,
        defaultPriority!: SkillPriority = SkillPriority.Medium,
        defaultContextBudgetTokens!: Int64 = 2000,
        enableConflictFilter!: Bool = true,
        enableBudgetAllocator!: Bool = true,
        profileBudgetTokens!: Int64 = 2048
    ) {
        this.totalBudgetTokens = totalBudgetTokens
        this.reservedForAlwaysOn = reservedForAlwaysOn
        this.defaultLoadPolicy = defaultLoadPolicy
        this.defaultPriority = defaultPriority
        this.defaultContextBudgetTokens = defaultContextBudgetTokens
        this.enableConflictFilter = enableConflictFilter
        this.enableBudgetAllocator = enableBudgetAllocator
        this.profileBudgetTokens = profileBudgetTokens
    }

    public static func default(): SkillParallelConfig {
        return SkillParallelConfig()
    }

    /**
     * TG28/T109：按模型上下文窗口推导总预算。
     *
     * `derived = windowTokens * ratio`，默认取窗口的 15%。
     * 当 `windowTokens <= 0` 或推导结果非正时回退到已配置值（固定 8192 或显式值），
     * 避免派生出无意义预算。
     *
     * 注意：显式配置优先由调用方（配置加载器）保证——仅当未显式指定
     * `totalBudgetTokens` 时才调用本方法覆盖；本方法本身只负责计算。
     */
    public func deriveFromModelWindow(windowTokens: Int64, ratio!: Float64 = 0.15): Int64 {
        if (windowTokens <= 0) {
            return this.totalBudgetTokens
        }
        let derived = Int64(Float64(windowTokens) * ratio)
        if (derived <= 0) {
            return this.totalBudgetTokens
        }
        return derived
    }

    /**
     * TG28/T110 配套：将派生预算写回配置（仅在未显式配置时由调用方调用）。
     */
    public func applyDerivedBudget(windowTokens: Int64, ratio!: Float64 = 0.15): Unit {
        this.totalBudgetTokens = deriveFromModelWindow(windowTokens, ratio: ratio)
    }
}