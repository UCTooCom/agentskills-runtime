/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.skill.{Skill, SkillManager}
import magic.core.tool.{ToolParameter, ToolResponse}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import std.collection.HashMap
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}

/**
 * GetSkillContentTool - 获取技能完整内容的内置工具
 *
 * 支持渐进式技能加载：
 * - 系统提示只注入技能摘要（name+description）
 * - Agent 按需调用此工具获取完整 SKILL.md 内容
 *
 * 三种对外暴露方式：
 * - 内置工具：agent 通过 tool call 调用
 * - REST API：GET /api/v1/skills/:name/content
 * - MCP 协议：skills/get_content 方法
 */
public class GetSkillContentTool <: AbsTool {
    public static let NAME = "get_skill_content"

    public static let DESC = """
    Get the full content of a skill by its name.
    Returns the skill's complete SKILL.md instructions, metadata, and description.
    Use this tool when you need detailed information about how to execute a skill.
    """

    private static var _skillManager: Option<SkillManager> = None<SkillManager>

    public static func setSkillManager(sm: SkillManager): Unit {
        _skillManager = Some(sm)
        LogUtils.info("[GetSkillContentTool] SkillManager injected")
    }

    public static func getSkillManager(): Option<SkillManager> {
        _skillManager
    }

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { GetSkillContentTool.NAME }
    }

    public prop description: String {
        get() { GetSkillContentTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("skill_name", "The name of the skill to get content for", TypeSchema.Str),
                ToolParameter("section", "Optional section to retrieve (e.g. 'SOP', 'data_sources'). If not specified, returns full content.", TypeSchema.Str)
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
                  "skill_name": "investment-research-assistant"
                }
                """,
                """
                {
                  "skill_name": "investment-research-assistant",
                  "section": "SOP"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let skillName = _extractString(args, "skill_name")
        if (skillName.isEmpty()) {
            return ToolResponse("{\"error\": \"Parameter 'skill_name' is required\"}", isError: true)
        }

        let section = _extractString(args, "section")

        LogUtils.info("[GetSkillContentTool] Getting content for skill: ${skillName}, section: ${section}")

        if (_skillManager.isNone()) {
            LogUtils.error("[GetSkillContentTool] SkillManager not injected")
            return ToolResponse("{\"error\": \"SkillManager not initialized\"}", isError: true)
        }

        let sm = _skillManager.getOrThrow()
        match (sm.getSkill(skillName)) {
            case Some(skill) =>
                let result = _buildSkillContentJson(skill, section)
                LogUtils.info("[GetSkillContentTool] Successfully retrieved content for skill: ${skillName}, length: ${result.size.toString()}")
                return ToolResponse(result, isError: false)
            case None =>
                LogUtils.error("[GetSkillContentTool] Skill not found: ${skillName}")
                let available = sm.availableSkills.keys().toArray()
                let availableStr = String.join(available, delimiter: ", ")
                return ToolResponse("{\"error\": \"Skill '${skillName}' not found\", \"available_skills\": [\"${availableStr}\"]}", isError: true)
        }
    }

    private static func _extractString(args: HashMap<String, JsonValue>, key: String): String {
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

    private func _buildSkillContentJson(skill: Skill, section: String): String {
        let obj = JsonObject()
        obj.put("name", JsonString(skill.name))
        obj.put("description", JsonString(skill.description))

        if (let Some(license) <- skill.license) {
            obj.put("license", JsonString(license))
        }

        if (let Some(compatibility) <- skill.compatibility) {
            obj.put("compatibility", JsonString(compatibility))
        }

        if (let Some(allowedTools) <- skill.allowedTools) {
            obj.put("allowed_tools", JsonString(allowedTools))
        }

        obj.put("skill_path", JsonString(skill.skillPath))

        let metadataObj = JsonObject()
        for ((key, value) in skill.metadata) {
            metadataObj.put(key, JsonString(value))
        }
        obj.put("metadata", metadataObj)

        let instructions = if (section.isEmpty()) {
            skill.instructions
        } else {
            _extractSection(skill.instructions, section)
        }
        obj.put("instructions", JsonString(instructions))

        return obj.toString()
    }

    private func _extractSection(content: String, section: String): String {
        let sectionMarker = "## " + section
        match (content.indexOf(sectionMarker)) {
            case Some(startIdx) =>
                let afterMarker = startIdx + sectionMarker.size
                let searchStr = "\n## "
                match (content.indexOf(searchStr, afterMarker)) {
                    case Some(endIdx) =>
                        return content[startIdx..endIdx]
                    case None =>
                        return content[startIdx..content.size]
                }
            case None =>
                return "Section '${section}' not found in skill content. Available sections can be found in the full content."
        }
    }
}