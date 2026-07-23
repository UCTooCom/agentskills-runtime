/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import std.convert.Parsable

public class ValidationResult {
    public var isValid: Bool = true
    public var errorMessage: Option<String> = None<String>

    public init() {}

    public init(valid!: Bool, message!: Option<String>) {
        this.isValid = valid
        this.errorMessage = message
    }

    public static func ok(): ValidationResult {
        ValidationResult(valid: true, message: None<String>)
    }

    public static func fail(message: String): ValidationResult {
        ValidationResult(valid: false, message: Some(message))
    }
}

public class ConfigValidator {
    public init() {}

    public func validate(configType: String, validationRule: Option<String>, value: String): ValidationResult {
        if (validationRule.isSome()) {
            let ruleResult = validateByRule(validationRule.getOrThrow(), value)
            if (!ruleResult.isValid) {
                return ruleResult
            }
        }
        match (configType) {
            case "string" => validateString(value)
            case "int" => validateInt(value)
            case "bool" => validateBool(value)
            case "url" => validateUrl(value)
            case "password" => validatePassword(value)
            case "path" => validatePath(value)
            case "json" => validateJson(value)
            case _ => ValidationResult.ok()
        }
    }

    public func validateString(value: String): ValidationResult {
        ValidationResult.ok()
    }

    public func validateInt(value: String): ValidationResult {
        if (value.isEmpty()) {
            return ValidationResult.ok()
        }
        try {
            Int32.parse(value)
            ValidationResult.ok()
        } catch (e: Exception) {
            ValidationResult.fail("Invalid integer value: ${value}")
        }
    }

    public func validateBool(value: String): ValidationResult {
        if (value.isEmpty()) {
            return ValidationResult.ok()
        }
        let lower = value.toAsciiLower()
        if (lower == "true" || lower == "false" || lower == "1" || lower == "0") {
            ValidationResult.ok()
        } else {
            ValidationResult.fail("Invalid boolean value: ${value}, expected true/false or 1/0")
        }
    }

    public func validateUrl(value: String): ValidationResult {
        if (value.isEmpty()) {
            return ValidationResult.ok()
        }
        if (value.startsWith("http://") || value.startsWith("https://") || value.startsWith("ws://") || value.startsWith("wss://")) {
            ValidationResult.ok()
        } else {
            ValidationResult.fail("Invalid URL format: ${value}")
        }
    }

    public func validatePassword(value: String): ValidationResult {
        ValidationResult.ok()
    }

    public func validatePath(value: String): ValidationResult {
        ValidationResult.ok()
    }

    public func validateJson(value: String): ValidationResult {
        if (value.isEmpty()) {
            return ValidationResult.ok()
        }
        if (value.startsWith("{") || value.startsWith("[")) {
            ValidationResult.ok()
        } else {
            ValidationResult.fail("Invalid JSON format: ${value}")
        }
    }

    public func validateByRule(rule: String, value: String): ValidationResult {
        if (rule.startsWith("port:")) {
            return validatePort(rule, value)
        }
        if (rule == "url") {
            return validateUrl(value)
        }
        if (rule.startsWith("bool:")) {
            return validateBool(value)
        }
        if (rule == "not_empty") {
            if (value.isEmpty()) {
                return ValidationResult.fail("Value cannot be empty")
            }
            return ValidationResult.ok()
        }
        if (rule.startsWith("path:exists")) {
            return validatePath(value)
        }
        ValidationResult.ok()
    }

    private func validatePort(rule: String, value: String): ValidationResult {
        let parts = rule.split(":")
        if (parts.size < 2) {
            return ValidationResult.ok()
        }
        let rangeStr = parts[1]
        let rangeParts = rangeStr.split("-")
        if (rangeParts.size == 2) {
            try {
                let minPort = Int32.parse(rangeParts[0])
                let maxPort = Int32.parse(rangeParts[1])
                try {
                    let port = Int32.parse(value)
                    if (port < minPort || port > maxPort) {
                        return ValidationResult.fail("Port ${value} out of range ${minPort}-${maxPort}")
                    }
                    ValidationResult.ok()
                } catch (e: Exception) {
                    ValidationResult.fail("Invalid port number: ${value}")
                }
            } catch (e: Exception) {
                ValidationResult.ok()
            }
        } else {
            ValidationResult.ok()
        }
    }
}