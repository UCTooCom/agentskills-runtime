/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.skill.domain.models

import std.collection.HashMap
import stdx.encoding.json.JsonValue

/**
 * SkillManifest represents the parsed content of a SKILL.md file according to the agentskills specification.
 * Part of the domain layer.
 */
public class SkillManifest {
    public let name: String  // Unique identifier for the skill (from YAML frontmatter, 1-64 chars)
    public let description: String  // Description of the skill (from YAML frontmatter, 1-1024 chars)
    public let license: Option<String>  // License information (from YAML frontmatter)
    public let compatibility: Option<String>  // Compatibility requirements (from YAML frontmatter, max 500 chars)
    public let metadata: HashMap<String, String>  // Additional metadata (from YAML frontmatter)
    public let allowedTools: Option<String>  // Pre-approved tools list (from YAML frontmatter)
    public let instructions: String  // Skill instructions and guidelines (from markdown body)
    public let skillPath: String  // Path to the skill directory
    public let scriptsDirExists: Bool  // Whether scripts/ directory exists
    public let referencesDirExists: Bool  // Whether references/ directory exists
    public let assetsDirExists: Bool  // Whether assets/ directory exists
    public let parameters: Array<SkillParameter>  // Definition of parameters the skill accepts
    public let decisionPoints: Array<DecisionPoint>  // 校验通过、可参与人在回路的决策点（spec 5.15）
    public let invalidDecisionPointIds: Array<String>  // 校验失败、**不生效**的决策点 id（spec 5.15.3 异常场景 3）

    public init(
        name!: String,
        description!: String,
        license!: Option<String>,
        compatibility!: Option<String>,
        metadata!: HashMap<String, String>,
        allowedTools!: Option<String>,
        instructions!: String,
        skillPath!: String,
        scriptsDirExists!: Bool,
        referencesDirExists!: Bool,
        assetsDirExists!: Bool,
        parameters!: Array<SkillParameter>,
        decisionPoints!: Array<DecisionPoint> = [],
        invalidDecisionPointIds!: Array<String> = []
    ) {
        this.name = name
        this.description = description
        this.license = license
        this.compatibility = compatibility
        this.metadata = metadata
        this.allowedTools = allowedTools
        this.instructions = instructions
        this.skillPath = skillPath
        this.scriptsDirExists = scriptsDirExists
        this.referencesDirExists = referencesDirExists
        this.assetsDirExists = assetsDirExists
        this.parameters = parameters
        this.decisionPoints = decisionPoints
        this.invalidDecisionPointIds = invalidDecisionPointIds
    }

    /// 按 id 查找一个**有效**决策点。
    /// 失效决策点查不到 ⇒ 天然"不生效"，下游据此跳过（spec 5.15.3 异常场景 3）。
    public func findDecisionPoint(pointId: String): Option<DecisionPoint> {
        for (dp in this.decisionPoints) {
            if (dp.id == pointId) {
                return Some(dp)
            }
        }
        return None
    }

    /// 该决策点是否已因校验失败而被禁用。
    public func isDecisionPointDisabled(pointId: String): Bool {
        for (id in this.invalidDecisionPointIds) {
            if (id == pointId) {
                return true
            }
        }
        return false
    }
}