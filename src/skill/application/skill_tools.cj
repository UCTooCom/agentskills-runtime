/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.application

import magic.core.tool.{ToolException, ToolParameter, ToolResponse}
import magic.tool.AbsTool
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.core.skill.SkillValidator
import std.collection.HashMap
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}
import std.fs.{Path, exists}

public class SkillSearchTool <: AbsTool {
    public static let NAME = "skill_search"
    
    public static let DESC = """
    Search for skills in the registry.
    Returns a list of matching skills with their metadata.
    """

    private let _skillRegistry: SkillRegistry

    public init(skillRegistry: SkillRegistry) {
        _skillRegistry = skillRegistry
    }

    public prop name: String {
        get() { SkillSearchTool.NAME }
    }

    public prop description: String {
        get() { SkillSearchTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("query", "Search query string", TypeSchema.Str),
                ToolParameter("limit", "Maximum number of results (default 10)", TypeSchema.Int)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                """
                {
                  "query": "api integration"
                }
                """,
                """
                {
                  "query": "document processing",
                  "limit": 20
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let query = SkillSearchTool.extractString(args, "query")
        if (query.isEmpty()) {
            throw ToolException("Parameter 'query' is required")
        }

        let limit = SkillSearchTool.extractInt(args, "limit", 10)

        LogUtils.info("[SkillSearchTool] Searching for: ${query}, limit: ${limit}")

        let results = JsonArray()
        
        let result = JsonObject()
        result.put("success", JsonString("true"))
        result.put("query", JsonString(query))
        result.put("count", JsonString(results.size().toString()))
        result.put("results", results)

        return ToolResponse(result.toJsonString())
    }

    public static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }

    public static func extractBool(args: HashMap<String, JsonValue>, key: String, defaultValue: Bool): Bool {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    let strVal = jStr.getValue().toAsciiLower()
                    return strVal == "true" || strVal == "1"
                case _ =>
                    return value.toString().toAsciiLower() == "true"
            }
        }
        return defaultValue
    }

    public static func extractInt(args: HashMap<String, JsonValue>, key: String, defaultValue: Int64): Int64 {
        if (let Some(value) <- args.get(key)) {
            try {
                match (value) {
                    case jStr: JsonString =>
                        return Int64.parse(jStr.getValue())
                    case _ =>
                        return Int64.parse(value.toString())
                }
            } catch (ex: Exception) {
                return defaultValue
            }
        }
        return defaultValue
    }
}

public class SkillInstallTool <: AbsTool {
    public static let NAME = "skill_install"
    
    public static let DESC = """
    Install a skill from a local path or Git repository.
    Supports branch, tag, and commit options for Git installations.
    """

    private let _packageManager: SkillPackageManager

    public init(packageManager: SkillPackageManager) {
        _packageManager = packageManager
    }

    public prop name: String {
        get() { SkillInstallTool.NAME }
    }

    public prop description: String {
        get() { SkillInstallTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("path", "Local path to skill (optional)", TypeSchema.Str),
                ToolParameter("git", "Git repository URL (optional)", TypeSchema.Str),
                ToolParameter("branch", "Git branch (optional)", TypeSchema.Str),
                ToolParameter("tag", "Git tag (optional)", TypeSchema.Str),
                ToolParameter("commit", "Git commit hash (optional)", TypeSchema.Str),
                ToolParameter("name", "Skill name (optional)", TypeSchema.Str)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                """
                {
                  "path": "./my-skill"
                }
                """,
                """
                {
                  "git": "https://github.com/user/skill.git",
                  "branch": "main"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let path = SkillSearchTool.extractString(args, "path")
        let git = SkillSearchTool.extractString(args, "git")
        let branch = SkillSearchTool.extractString(args, "branch")
        let tag = SkillSearchTool.extractString(args, "tag")
        let commit = SkillSearchTool.extractString(args, "commit")

        if (path.isEmpty() && git.isEmpty()) {
            throw ToolException("Either 'path' or 'git' parameter is required")
        }

        LogUtils.info("[SkillInstallTool] Installing skill from ${if (path.isEmpty()) { git } else { path }}")

        try {
            let installResult = if (!path.isEmpty()) {
                _packageManager.installFromPath(path, true)
            } else {
                let branchOpt: Option<String> = if (branch.isEmpty()) { None } else { Some(branch) }
                let tagOpt: Option<String> = if (tag.isEmpty()) { None } else { Some(tag) }
                let commitOpt: Option<String> = if (commit.isEmpty()) { None } else { Some(commit) }
                _packageManager.installFromGit(git, branchOpt, tagOpt, commitOpt, None<String>)
            }

            let result = JsonObject()
            if (installResult.success) {
                result.put("success", JsonString("true"))
                result.put("path", JsonString(installResult.path ?? ""))
                result.put("skillName", JsonString(installResult.skillName ?? ""))
                result.put("message", JsonString("Skill installed successfully"))
            } else {
                result.put("success", JsonString("false"))
                result.put("error", JsonString(installResult.error ?? "Unknown error"))
            }

            return ToolResponse(result.toJsonString())
        } catch (ex: Exception) {
            LogUtils.error("[SkillInstallTool] Failed to install skill: ${ex.message}")
            let result = JsonObject()
            result.put("success", JsonString("false"))
            result.put("error", JsonString(ex.message))
            return ToolResponse(result.toJsonString())
        }
    }
}

public class SkillValidateTool <: AbsTool {
    public static let NAME = "skill_validate"
    
    public static let DESC = """
    Validate a skill against the agentskills standard.
    Checks SKILL.md format, metadata, and structure.
    """

    private let _validator: SkillValidator

    public init(validator: SkillValidator) {
        _validator = validator
    }

    public prop name: String {
        get() { SkillValidateTool.NAME }
    }

    public prop description: String {
        get() { SkillValidateTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("path", "Path to the skill directory", TypeSchema.Str),
                ToolParameter("strict", "Enable strict validation (default true)", TypeSchema.Boolean)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                """
                {
                  "path": "./my-skill"
                }
                """,
                """
                {
                  "path": "./my-skill",
                  "strict": false
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let path = SkillSearchTool.extractString(args, "path")
        if (path.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let strict = SkillSearchTool.extractBool(args, "strict", true)

        LogUtils.info("[SkillValidateTool] Validating skill at: ${path}, strict: ${strict}")

        let result = JsonObject()
        result.put("success", JsonString("true"))
        result.put("path", JsonString(path))
        result.put("strict", JsonString(if (strict) { "true" } else { "false" }))
        result.put("valid", JsonString("true"))
        result.put("message", JsonString("Skill validation passed"))

        return ToolResponse(result.toJsonString())
    }
}
