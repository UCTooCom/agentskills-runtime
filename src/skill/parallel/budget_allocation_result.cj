/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import std.collection.HashMap

public class BudgetAllocationResult {
    public var allocated: Array<String>
    public var evicted: Array<String>
    public var usedTokens: Int64
    public var totalBudget: Int64
    public var degraded: Array<String>
    public var contentLevels: HashMap<String, ContentLevel>

    public init(
        allocated!: Array<String> = [],
        evicted!: Array<String> = [],
        usedTokens!: Int64 = 0,
        totalBudget!: Int64 = 0,
        degraded!: Array<String> = [],
        contentLevels!: HashMap<String, ContentLevel> = HashMap<String, ContentLevel>()
    ) {
        this.allocated = allocated
        this.evicted = evicted
        this.usedTokens = usedTokens
        this.totalBudget = totalBudget
        this.degraded = degraded
        this.contentLevels = contentLevels
    }
}