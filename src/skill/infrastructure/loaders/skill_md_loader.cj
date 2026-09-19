/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.skill.infrastructure.loaders

import std.io.*
import std.fs.*
import std.collection.HashMap
import magic.skill.domain.models.{SkillManifest, SkillParameter, DecisionPointParseResult}
import magic.skill.infrastructure.utils.YamlUtils
import magic.skill.infrastructure.utils.MarkdownUtils
import magic.skill.infrastructure.validators.DecisionPointValidator
import magic.log.LogUtils
import std.fs.{exists, Directory}

/**
 * SkillMdLoader loads skills from SKILL.md files.
 */
public class SkillMdLoader {
    /**
     * Load a skill from a file path
     */
    public func loadSkillFromPath(path: String): Option<SkillManifest> {
        try {
            // Read the content of the SKILL.md file
            let file = File(path, OpenMode.Read)  // Open for reading
            if (!file.canRead()) {
                return None
            }
            
            let reader = StringReader(file)
            let content = reader.readToEnd()
            reader.close()
            file.close()
            
            // Parse the YAML frontmatter
            let yamlParser = YamlFrontmatterParser()
            let yamlFrontmatterOpt = yamlParser.parseYamlFrontmatter(content)
            
            if (yamlFrontmatterOpt.isNone()) {
                return None
            }
            
            let yamlFrontmatter = yamlFrontmatterOpt.getOrThrow()
            
            // Extract the markdown body (everything after the second ---)
            let markdownBody = extractMarkdownBody(content)

            // Process the markdown content using markdown4cj library
            let processedMarkdown = MarkdownUtils.parseMarkdownContent(markdownBody)
            
            // Check for existence of external resource directories
            let lastSlashIndexOpt = path.lastIndexOf('/')
            let skillDir = if (lastSlashIndexOpt.isSome()) {
                let lastSlashIndex = lastSlashIndexOpt.getOrThrow()
                path[0..lastSlashIndex]
            } else {
                path  // If no slash found, use the whole path
            }
            let scriptsDirExists = exists("${skillDir}/scripts/")
            let referencesDirExists = exists("${skillDir}/references/")
            let assetsDirExists = exists("${skillDir}/assets/")

            // ── Ch13.1 决策点校验（spec 5.15.1 规则 4 / 5.15.3 异常场景 3）──────
            // 这里持有 SKILL.md 原文，是唯一能校验 decision-points 的位置。
            // 校验失败不阻断加载：只告警，并把失效决策点 id 挂进 manifest，
            // 下游（执行器 / 审批工具）据此跳过 ⇒ "该决策点不生效"。
            let decisionPointResult = DecisionPointValidator().parseAndValidate(content)
            for (warning in decisionPointResult.warnings) {
                LogUtils.warn("Skill '${yamlFrontmatter.name}' 决策点校验告警: ${warning}")
            }
            if (decisionPointResult.hasInvalidPoints()) {
                LogUtils.warn("Skill '${yamlFrontmatter.name}' 有 ${decisionPointResult.invalidPointIds.size} 个决策点因校验失败被禁用（不生效）")
            }
            if (decisionPointResult.validPoints.size > 0) {
                LogUtils.info("Skill '${yamlFrontmatter.name}' 载入 ${decisionPointResult.validPoints.size} 个有效决策点")
            }
            
            // Create the SkillManifest
            return Some(
                SkillManifest(
                    name: yamlFrontmatter.name,
                    description: yamlFrontmatter.description,
                    license: yamlFrontmatter.license,
                    compatibility: yamlFrontmatter.compatibility,
                    metadata: yamlFrontmatter.metadata,
                    allowedTools: yamlFrontmatter.allowedTools,
                    instructions: processedMarkdown,
                    skillPath: path,
                    scriptsDirExists: scriptsDirExists,
                    referencesDirExists: referencesDirExists,
                    assetsDirExists: assetsDirExists,
                    parameters: [],  // Parameters would be extracted from the markdown content or YAML
                    decisionPoints: decisionPointResult.validPoints,
                    invalidDecisionPointIds: decisionPointResult.invalidPointIds
                )
            )
        } catch (ex: Exception) {
            // Log the exception or handle it appropriately
            return None
        }
    }
    
    /**
     * Extract the markdown body from the content (everything after the second ---)
     */
    private func extractMarkdownBody(content: String): String {
        let lines = content.split("\n")
        
        var firstSeparatorIndex = -1
        var secondSeparatorIndex = -1
        
        for (i in 0..lines.size) {
            if (lines[i].trimAscii() == "---") {
                if (firstSeparatorIndex == -1) {
                    firstSeparatorIndex = i
                } else if (secondSeparatorIndex == -1) {
                    secondSeparatorIndex = i
                    break
                }
            }
        }
        
        if (secondSeparatorIndex != -1 && secondSeparatorIndex < lines.size - 1) {
            let bodyLines = lines[(secondSeparatorIndex + 1)..lines.size]
            return String.join(bodyLines, delimiter: "\n")
        }
        
        return ""  // Return empty string if no markdown body found
    }
}