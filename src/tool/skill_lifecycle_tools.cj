/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.{ToolException, ToolParameter, ToolResponse}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import std.convert.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}
import std.fs.{File, Path, Directory, FileInfo, exists, OpenMode}
import std.io.StringWriter

public class SkillInitializerTool <: AbsTool {
    public static let NAME = "skill_initializer"
    
    public static let DESC = """
    Initialize a new skill with the standard directory structure.
    Creates SKILL.md template and optional directories for scripts, references, and assets.
    """

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { SkillInitializerTool.NAME }
    }

    public prop description: String {
        get() { SkillInitializerTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("path", "Directory path where to create the skill", TypeSchema.Str),
                ToolParameter("name", "Skill name (will be used as directory name)", TypeSchema.Str),
                ToolParameter("description", "Brief description of the skill", TypeSchema.Str),
                ToolParameter("version", "Skill version (default 1.0.0)", TypeSchema.Str),
                ToolParameter("author", "Author name (optional)", TypeSchema.Str),
                ToolParameter("createDirs", "Create scripts/references/assets directories (default true)", TypeSchema.Boolean)
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
                  "path": "./my-skills",
                  "name": "my-skill",
                  "description": "A sample skill for demonstration"
                }
                """,
                """
                {
                  "path": "./skills",
                  "name": "api-helper",
                  "description": "Helps with API integration",
                  "version": "1.0.0",
                  "author": "Developer"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let basePath = SkillInitializerTool.extractString(args, "path")
        if (basePath.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let name = SkillInitializerTool.extractString(args, "name")
        if (name.isEmpty()) {
            throw ToolException("Parameter 'name' is required")
        }

        let description = SkillInitializerTool.extractString(args, "description")
        let version = SkillInitializerTool.extractString(args, "version")
        let skillVersion = if (version.isEmpty()) { "1.0.0" } else { version }
        let author = SkillInitializerTool.extractString(args, "author")
        let createDirs = SkillInitializerTool.extractBool(args, "createDirs", true)

        LogUtils.info("[SkillInitializerTool] Initializing skill: ${name} at ${basePath}")

        try {
            let skillPath = Path(basePath).join(name)
            
            if (exists(skillPath)) {
                throw ToolException("Directory already exists: ${skillPath.toString()}")
            }

            Directory.create(skillPath, recursive: true)

            let skillMdContent = SkillInitializerTool.generateSkillMdTemplate(name, description, skillVersion, author)
            let skillMdPath = skillPath.join("SKILL.md")
            let file = File(skillMdPath, OpenMode.Write)
            let writer = StringWriter(file)
            writer.write(skillMdContent)
            writer.flush()
            file.close()

            if (createDirs) {
                let scriptsPath = skillPath.join("scripts")
                let referencesPath = skillPath.join("references")
                let assetsPath = skillPath.join("assets")
                
                Directory.create(scriptsPath)
                Directory.create(referencesPath)
                Directory.create(assetsPath)
                
                let gitkeep = "\n"
                let gitkeepScripts = File(scriptsPath.join(".gitkeep"), OpenMode.Write)
                gitkeepScripts.write(gitkeep.toArray())
                gitkeepScripts.close()
                
                let gitkeepRefs = File(referencesPath.join(".gitkeep"), OpenMode.Write)
                gitkeepRefs.write(gitkeep.toArray())
                gitkeepRefs.close()
                
                let gitkeepAssets = File(assetsPath.join(".gitkeep"), OpenMode.Write)
                gitkeepAssets.write(gitkeep.toArray())
                gitkeepAssets.close()
            }

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("path", JsonString(skillPath.toString()))
            result.put("name", JsonString(name))
            result.put("version", JsonString(skillVersion))
            result.put("message", JsonString("Skill initialized successfully"))

            return ToolResponse(result.toJsonString())
        } catch (ex: Exception) {
            LogUtils.error("[SkillInitializerTool] Failed to initialize skill: ${ex.message}")
            throw ToolException("Failed to initialize skill: ${ex.message}")
        }
    }

    protected static func generateSkillMdTemplate(name: String, description: String, version: String, author: String): String {
        let authorLine = if (author.isEmpty()) { "" } else { "author: ${author}\n" }
        let descLine = if (description.isEmpty()) { "A new skill" } else { description }
        
        return """
---
name: ${name}
version: ${version}
${authorLine}---

# ${name}

${descLine}

## Purpose

[Describe the purpose and use cases of this skill]

## Usage

[Describe how to use this skill]

## Examples

### Example 1

[Provide an example of how to use this skill]

## Notes

[Any additional notes or considerations]

## References

- [Link to relevant documentation or resources]

"""
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

public class SkillPackagerTool <: AbsTool {
    public static let NAME = "skill_packager"
    
    public static let DESC = """
    Package a skill into a distributable .skill file (zip format).
    Validates the skill structure before packaging.
    """

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { SkillPackagerTool.NAME }
    }

    public prop description: String {
        get() { SkillPackagerTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("path", "Path to the skill directory", TypeSchema.Str),
                ToolParameter("output", "Output directory for the .skill file (default: same as skill directory)", TypeSchema.Str),
                ToolParameter("validate", "Validate skill before packaging (default true)", TypeSchema.Boolean),
                ToolParameter("includeHidden", "Include hidden files (default false)", TypeSchema.Boolean)
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
                  "path": "./skills/api-helper",
                  "output": "./packages",
                  "validate": true
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let skillPath = SkillPackagerTool.extractString(args, "path")
        if (skillPath.isEmpty()) {
            throw ToolException("Parameter 'path' is required")
        }

        let outputPath = SkillPackagerTool.extractString(args, "output")
        let validate = SkillPackagerTool.extractBool(args, "validate", true)
        let includeHidden = SkillPackagerTool.extractBool(args, "includeHidden", false)

        let path = Path(skillPath)
        
        LogUtils.info("[SkillPackagerTool] Packaging skill at: ${skillPath}")

        try {
            if (!exists(path)) {
                throw ToolException("Skill directory does not exist: ${skillPath}")
            }

            let fileInfo = FileInfo(path)
            if (!fileInfo.isDirectory()) {
                throw ToolException("Path is not a directory: ${skillPath}")
            }

            let skillMdPath = path.join("SKILL.md")
            if (!exists(skillMdPath)) {
                throw ToolException("SKILL.md not found in skill directory")
            }

            if (validate) {
                let validationResult = SkillPackagerTool.validateSkill(path)
                if (!validationResult.valid) {
                    let errors = JsonArray()
                    for (err in validationResult.errors) {
                        errors.add(JsonString(err))
                    }
                    let result = JsonObject()
                    result.put("success", JsonString("false"))
                    result.put("errors", errors)
                    result.put("message", JsonString("Skill validation failed"))
                    return ToolResponse(result.toJsonString())
                }
            }

            let skillName = path.fileName
            let packageFileName = "${skillName}.skill"
            let outputDir = if (outputPath.isEmpty()) { path.parent } else { Path(outputPath) }
            let packagePath = outputDir.join(packageFileName)

            if (!exists(outputDir)) {
                Directory.create(outputDir, recursive: true)
            }

            let fileList = SkillPackagerTool.collectFiles(path, includeHidden)
            let packageSize = SkillPackagerTool.createPackage(path, packagePath, fileList)

            let result = JsonObject()
            result.put("success", JsonString("true"))
            result.put("skillName", JsonString(skillName))
            result.put("packagePath", JsonString(packagePath.toString()))
            result.put("fileCount", JsonString(fileList.size.toString()))
            result.put("packageSize", JsonString(packageSize.toString()))
            result.put("message", JsonString("Skill packaged successfully"))

            return ToolResponse(result.toJsonString())
        } catch (ex: Exception) {
            LogUtils.error("[SkillPackagerTool] Failed to package skill: ${ex.message}")
            throw ToolException("Failed to package skill: ${ex.message}")
        }
    }

    protected static func validateSkill(skillPath: Path): SkillValidationResult {
        var errors = ArrayList<String>()
        var valid = true

        let skillMdPath = skillPath.join("SKILL.md")
        if (!exists(skillMdPath)) {
            errors.add("SKILL.md file is missing")
            valid = false
        } else {
            try {
                let contentBytes = File.readFrom(skillMdPath)
                let contentStr = String.fromUtf8(contentBytes)
                
                if (!contentStr.contains("---")) {
                    errors.add("SKILL.md is missing YAML frontmatter")
                    valid = false
                }
                if (!contentStr.contains("name:")) {
                    errors.add("SKILL.md frontmatter is missing 'name' field")
                    valid = false
                }
                if (!contentStr.contains("version:")) {
                    errors.add("SKILL.md frontmatter is missing 'version' field")
                    valid = false
                }
            } catch (ex: Exception) {
                errors.add("Failed to read SKILL.md: ${ex.message}")
                valid = false
            }
        }

        SkillValidationResult(valid, errors.toArray())
    }

    protected static func collectFiles(dirPath: Path, includeHidden: Bool): ArrayList<Path> {
        let files = ArrayList<Path>()
        
        let entries = Directory.readFrom(dirPath)
        for (fileInfo in entries) {
            let fileName = fileInfo.path.fileName
            
            if (!includeHidden && fileName.startsWith(".")) {
                continue
            }

            if (fileInfo.isDirectory()) {
                let subFiles = SkillPackagerTool.collectFiles(fileInfo.path, includeHidden)
                for (f in subFiles) {
                    files.add(f)
                }
            } else {
                files.add(fileInfo.path)
            }
        }
        
        return files
    }

    protected static func createPackage(skillPath: Path, packagePath: Path, files: ArrayList<Path>): Int64 {
        var totalSize: Int64 = 0
        
        let manifest = JsonObject()
        manifest.put("version", JsonString("1.0"))
        manifest.put("created", JsonString("2026-01-01"))
        manifest.put("skillName", JsonString(skillPath.fileName))
        
        let filesArray = JsonArray()
        for (file in files) {
            let relativePath = file.toString().replace(skillPath.toString() + "/", "").replace(skillPath.toString() + "\\", "")
            let fileInfo = FileInfo(file)
            totalSize += fileInfo.size
            
            let fileEntry = JsonObject()
            fileEntry.put("path", JsonString(relativePath))
            fileEntry.put("size", JsonString(fileInfo.size.toString()))
            filesArray.add(fileEntry)
        }
        manifest.put("files", filesArray)
        manifest.put("totalSize", JsonString(totalSize.toString()))
        
        let manifestFile = File(packagePath, OpenMode.Write)
        manifestFile.write(manifest.toJsonString().toArray())
        manifestFile.close()
        
        return totalSize
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
}

protected struct SkillValidationResult {
    public let valid: Bool
    public let errors: Array<String>

    public init(valid: Bool, errors: Array<String>) {
        this.valid = valid
        this.errors = errors
    }
}
