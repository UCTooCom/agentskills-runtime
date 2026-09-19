/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.skill.application

import magic.skill.domain.models.{SkillManifest, ValidationResult, DecisionPointParseResult}
import magic.skill.infrastructure.validators.{SkillValidatorImpl, YamlValidator, DecisionPointValidator}

/**
 * SkillValidationService implements validation of skills against the agentskills specification.
 */
public class SkillValidationService {
    private let skillValidator: SkillValidatorImpl
    private let yamlValidator: YamlValidator
    private let decisionPointValidator: DecisionPointValidator

    public init() {
        this.skillValidator = SkillValidatorImpl()
        this.yamlValidator = YamlValidator()
        this.decisionPointValidator = DecisionPointValidator()
    }

    /**
     * Validate a skill manifest against the agentskills specification
     */
    public func validateSkillManifest(manifest: SkillManifest): ValidationResult {
        // Use the skill validator to validate the manifest
        return this.skillValidator.validate(manifest)
    }

    /**
     * Validate a skill name per agentskills specification
     */
    public func validateSkillName(name: String): (Bool, String) {
        let isValid = this.skillValidator.isValidName(name)
        let message = if (isValid) {
            "Skill name is valid"
        } else {
            "Skill name '${name}' does not follow agentskills standard: must be 1-64 characters, lowercase, with hyphens only, not starting or ending with hyphen"
        }
        return (isValid, message)
    }

    /**
     * Validate a skill description per agentskills specification
     */
    public func validateSkillDescription(description: String): (Bool, String) {
        let isValid = this.skillValidator.isValidDescription(description)
        let message = if (isValid) {
            "Skill description is valid"
        } else {
            "Skill description does not follow agentskills standard: must be 1-1024 characters and not empty"
        }
        return (isValid, message)
    }

    /**
     * Validate skill content (YAML and markdown)
     */
    public func validateSkillContent(content: String): ValidationResult {
        // Validate YAML syntax
        let yamlValidation = this.yamlValidator.validateYamlSyntax(content)
        
        if (!yamlValidation.isValid) {
            return yamlValidation
        }
        
        // Validate YAML frontmatter structure
        let frontmatterValidation = this.yamlValidator.validateYamlFrontmatter(content)

        // Validate decision-points (Ch13.1: options.length>=2, default/recommended valid id)
        let dpValidation = this.decisionPointValidator.validate(content)

        // Merge: frontmatter errors are blocking, decision-point issues are warnings only.
        // 修复（v15 复核问题 B）：两处 warnings 取**并集**，不再用 dp 侧覆盖 frontmatter 侧，
        // 避免新代码削弱既有 frontmatter 告警能力。
        return ValidationResult.mergeValidations(frontmatterValidation, dpValidation)
    }

    /**
     * 解析并校验技能内容中的决策点，返回结构化结果。
     *
     * 供加载链（SkillManagementService.loadSkillFromPath）消费：
     *   - validPoints      → 可正常参与人在回路的决策点
     *   - invalidPointIds  → **不生效**的决策点（spec 5.15.3 异常场景 3）
     */
    public func validateDecisionPoints(content: String): DecisionPointParseResult {
        return this.decisionPointValidator.parseAndValidate(content)
    }
}