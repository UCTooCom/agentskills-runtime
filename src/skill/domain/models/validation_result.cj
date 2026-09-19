/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.skill.domain.models

import std.collection.ArrayList
import std.time.DateTime

/**
 * ValidationResult represents the result of validating a skill or SKILL.md file. Part of the domain layer.
 */
public class ValidationResult {
    public let isValid: Bool  // Whether the validation passed
    public let errors: Array<String>  // List of validation errors if any
    public let warnings: Array<String>  // List of warnings if any
    public let validationDate: Int64  // Timestamp of validation

    public init(
        isValid!: Bool,
        errors!: Array<String>,
        warnings!: Array<String>,
        validationDate!: Int64
    ) {
        this.isValid = isValid
        this.errors = errors
        this.warnings = warnings
        this.validationDate = validationDate
    }

    /**
     * 当前时间的毫秒级 Unix 时间戳。
     *
     * 提取为单一出处，避免「同一表达式在 4 处工厂里各写一遍」的重复
     * （v15 修复轮编译报错的根因之一就是这类散落表达式缺少统一的 import 保障）。
     */
    private static func nowMillis(): Int64 {
        return (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    }

    /**
     * Factory method to create a successful validation result
     */
    public static func success(): ValidationResult {
        return ValidationResult(
            isValid: true,
            errors: [],
            warnings: [],
            validationDate: nowMillis()
        )
    }

    /**
     * Factory method to create a failed validation result with errors
     */
    public static func failure(errors: Array<String>, warnings: Array<String>): ValidationResult {
        return ValidationResult(
            isValid: false,
            errors: errors,
            warnings: warnings,
            validationDate: nowMillis()
        )
    }

    /**
     * Factory method to create a passing result that carries non-blocking warnings.
     * Used when validation succeeded but something deserves the author's attention
     * (e.g. a decision point disabled by an illegal option id — spec 5.15.3 case 3).
     */
    public static func withWarnings(warnings: Array<String>): ValidationResult {
        return ValidationResult(
            isValid: true,
            errors: [],
            warnings: warnings,
            validationDate: nowMillis()
        )
    }

    /**
     * Merge two results: errors decide validity, warnings are unioned.
     * Prevents the "warning overwrite" regression where one side's warnings are dropped.
     */
    public static func mergeValidations(primary: ValidationResult, secondary: ValidationResult): ValidationResult {
        let mergedWarnings = ArrayList<String>()
        mergedWarnings.add(all: primary.warnings)
        mergedWarnings.add(all: secondary.warnings)

        let mergedErrors = ArrayList<String>()
        mergedErrors.add(all: primary.errors)
        mergedErrors.add(all: secondary.errors)

        return ValidationResult(
            isValid: primary.isValid && secondary.isValid,
            errors: mergedErrors.toArray(),
            warnings: mergedWarnings.toArray(),
            validationDate: nowMillis()
        )
    }
}