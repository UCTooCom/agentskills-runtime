/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import std.collection.ArrayList

public class TaskMatchResult {
    public var skillName: String
    public var matchScore: Float64
    public var matchStrategy: TaskMatchStrategy
    public var matchedKeywords: ArrayList<String>

    public init(
        skillName!: String = "",
        matchScore!: Float64 = 0.0,
        matchStrategy!: TaskMatchStrategy = TaskMatchStrategy.Keyword,
        matchedKeywords!: ArrayList<String> = ArrayList<String>()
    ) {
        this.skillName = skillName
        this.matchScore = matchScore
        this.matchStrategy = matchStrategy
        this.matchedKeywords = matchedKeywords
    }
}