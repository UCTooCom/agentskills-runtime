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

public class TemplateEngineTool <: AbsTool {
    public static let NAME = "template_engine"
    
    public static let DESC = """
    Generate code or text from templates with variable substitution.
    Supports placeholders like {{variable_name}} and conditionals.
    Useful for generating boilerplate code, configuration files, or documentation.
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
        get() { TemplateEngineTool.NAME }
    }

    public prop description: String {
        get() { TemplateEngineTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("template", "The template string with {{placeholders}}", TypeSchema.Str),
                ToolParameter("variables", "Object with variable names and values", TypeSchema.Str),
                ToolParameter("outputPath", "Optional file path to write output (if not provided, returns content)", TypeSchema.Str),
                ToolParameter("preserveWhitespace", "Preserve whitespace in template (default true)", TypeSchema.Boolean)
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
                  "template": "Hello, {{name}}!",
                  "variables": "{\"name\": \"World\"}"
                }
                """,
                """
                {
                  "template": "function {{funcName}}() {\\n  return {{value}};\\n}",
                  "variables": "{\"funcName\": \"greet\", \"value\": \"hello\"}",
                  "outputPath": "./generated.js"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let template = TemplateEngineTool.extractString(args, "template")
        if (template.isEmpty()) {
            throw ToolException("Parameter 'template' is required")
        }

        let variablesJson = TemplateEngineTool.extractString(args, "variables")
        let outputPath = TemplateEngineTool.extractString(args, "outputPath")
        let preserveWhitespace = TemplateEngineTool.extractBool(args, "preserveWhitespace", true)

        LogUtils.info("[TemplateEngineTool] Processing template")

        try {
            let variables = TemplateEngineTool.parseVariables(variablesJson)
            let result = TemplateEngineTool.processTemplate(template, variables, preserveWhitespace)

            if (!outputPath.isEmpty()) {
                let path = Path(outputPath)
                let parentDir = path.parent
                if (!exists(parentDir)) {
                    Directory.create(parentDir, recursive: true)
                }
                
                let file = File(path, OpenMode.Write)
                let writer = StringWriter(file)
                writer.write(result)
                writer.flush()
                file.close()

                let response = JsonObject()
                response.put("success", JsonString("true"))
                response.put("outputPath", JsonString(outputPath))
                response.put("contentLength", JsonString(result.size.toString()))
                response.put("message", JsonString("Template rendered and saved successfully"))

                return ToolResponse(response.toJsonString())
            } else {
                let response = JsonObject()
                response.put("success", JsonString("true"))
                response.put("content", JsonString(result))
                response.put("contentLength", JsonString(result.size.toString()))

                return ToolResponse(response.toJsonString())
            }
        } catch (ex: Exception) {
            LogUtils.error("[TemplateEngineTool] Failed to process template: ${ex.message}")
            throw ToolException("Failed to process template: ${ex.message}")
        }
    }

    protected static func parseVariables(jsonStr: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        
        if (jsonStr.isEmpty()) {
            return result
        }

        let trimmed = jsonStr.trimAscii()
        if (!trimmed.startsWith("{") || !trimmed.endsWith("}")) {
            return result
        }

        let content = trimmed[1..(trimmed.size - 1)]
        var i = 0
        var inString = false
        var currentKey = ""
        var currentValue = ""
        var parsingKey = true
        var escapeNext = false

        while (i < content.size) {
            let c = content[i..(i+1)]
            
            if (escapeNext) {
                if (parsingKey) {
                    currentKey = currentKey + c
                } else {
                    currentValue = currentValue + c
                }
                escapeNext = false
                i++
                continue
            }

            if (c == "\\") {
                escapeNext = true
                i++
                continue
            }

            if (c == "\"") {
                inString = !inString
                i++
                continue
            }

            if (!inString) {
                if (c == ":" && parsingKey) {
                    parsingKey = false
                    i++
                    continue
                }
                
                if (c == ",") {
                    if (!currentKey.isEmpty()) {
                        result.add(currentKey.trimAscii(), currentValue.trimAscii())
                    }
                    currentKey = ""
                    currentValue = ""
                    parsingKey = true
                    i++
                    continue
                }
            }

            if (parsingKey) {
                currentKey = currentKey + c
            } else {
                currentValue = currentValue + c
            }
            
            i++
        }

        if (!currentKey.isEmpty()) {
            result.add(currentKey.trimAscii(), currentValue.trimAscii())
        }

        return result
    }

    protected static func processTemplate(template: String, variables: HashMap<String, String>, preserveWhitespace: Bool): String {
        var result = template

        for ((key, value) in variables) {
            let placeholder = "{{${key}}}"
            result = result.replace(placeholder, value)
        }

        if (!preserveWhitespace) {
            result = result.trimAscii()
            while (result.contains("  ")) {
                result = result.replace("  ", " ")
            }
            while (result.contains("\n\n\n")) {
                result = result.replace("\n\n\n", "\n\n")
            }
        }

        return result
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

public class CodeSnippetGeneratorTool <: AbsTool {
    public static let NAME = "code_snippet_generator"
    
    public static let DESC = """
    Generate common code snippets for various programming languages.
    Supports functions, classes, interfaces, and common patterns.
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
        get() { CodeSnippetGeneratorTool.NAME }
    }

    public prop description: String {
        get() { CodeSnippetGeneratorTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("language", "Programming language (typescript, javascript, python, cangjie, etc.)", TypeSchema.Str),
                ToolParameter("type", "Snippet type (function, class, interface, enum, constant)", TypeSchema.Str),
                ToolParameter("name", "Name of the function/class/variable", TypeSchema.Str),
                ToolParameter("parameters", "Parameters as JSON array of objects with name and type", TypeSchema.Str),
                ToolParameter("returnType", "Return type (optional)", TypeSchema.Str),
                ToolParameter("body", "Function body or class content (optional)", TypeSchema.Str),
                ToolParameter("visibility", "Visibility modifier (public, private, protected)", TypeSchema.Str),
                ToolParameter("isAsync", "Whether function is async (default false)", TypeSchema.Boolean),
                ToolParameter("outputPath", "Optional file path to write output", TypeSchema.Str)
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
                  "language": "typescript",
                  "type": "function",
                  "name": "calculateSum",
                  "parameters": "[{\"name\": \"a\", \"type\": \"number\"}, {\"name\": \"b\", \"type\": \"number\"}]",
                  "returnType": "number",
                  "body": "return a + b;"
                }
                """,
                """
                {
                  "language": "cangjie",
                  "type": "class",
                  "name": "UserService",
                  "visibility": "public"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let language = CodeSnippetGeneratorTool.extractString(args, "language")
        let snippetType = CodeSnippetGeneratorTool.extractString(args, "type")
        let name = CodeSnippetGeneratorTool.extractString(args, "name")

        if (language.isEmpty()) {
            throw ToolException("Parameter 'language' is required")
        }
        if (snippetType.isEmpty()) {
            throw ToolException("Parameter 'type' is required")
        }
        if (name.isEmpty()) {
            throw ToolException("Parameter 'name' is required")
        }

        let parametersJson = CodeSnippetGeneratorTool.extractString(args, "parameters")
        let returnType = CodeSnippetGeneratorTool.extractString(args, "returnType")
        let body = CodeSnippetGeneratorTool.extractString(args, "body")
        let visibility = CodeSnippetGeneratorTool.extractString(args, "visibility")
        let isAsync = CodeSnippetGeneratorTool.extractBool(args, "isAsync", false)
        let outputPath = CodeSnippetGeneratorTool.extractString(args, "outputPath")

        LogUtils.info("[CodeSnippetGeneratorTool] Generating ${snippetType} for ${language}")

        try {
            let parameters = CodeSnippetGeneratorTool.parseParameters(parametersJson)
            let code = CodeSnippetGeneratorTool.generateCode(
                language.toAsciiLower(),
                snippetType.toAsciiLower(),
                name,
                parameters,
                returnType,
                body,
                visibility,
                isAsync
            )

            if (!outputPath.isEmpty()) {
                let path = Path(outputPath)
                let parentDir = path.parent
                if (!exists(parentDir)) {
                    Directory.create(parentDir, recursive: true)
                }
                
                let file = File(path, OpenMode.Write)
                let writer = StringWriter(file)
                writer.write(code)
                writer.flush()
                file.close()

                let response = JsonObject()
                response.put("success", JsonString("true"))
                response.put("outputPath", JsonString(outputPath))
                response.put("language", JsonString(language))
                response.put("type", JsonString(snippetType))
                response.put("message", JsonString("Code generated and saved successfully"))

                return ToolResponse(response.toJsonString())
            } else {
                let response = JsonObject()
                response.put("success", JsonString("true"))
                response.put("code", JsonString(code))
                response.put("language", JsonString(language))
                response.put("type", JsonString(snippetType))

                return ToolResponse(response.toJsonString())
            }
        } catch (ex: Exception) {
            LogUtils.error("[CodeSnippetGeneratorTool] Failed to generate code: ${ex.message}")
            throw ToolException("Failed to generate code: ${ex.message}")
        }
    }

    protected static func parseParameters(jsonStr: String): ArrayList<ParameterInfo> {
        let result = ArrayList<ParameterInfo>()
        
        if (jsonStr.isEmpty()) {
            return result
        }

        let trimmed = jsonStr.trimAscii()
        if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) {
            return result
        }

        return result
    }

    protected static func generateCode(
        language: String,
        snippetType: String,
        name: String,
        parameters: ArrayList<ParameterInfo>,
        returnType: String,
        body: String,
        visibility: String,
        isAsync: Bool
    ): String {
        match (snippetType) {
            case "function" => generateFunction(language, name, parameters, returnType, body, visibility, isAsync)
            case "class" => generateClass(language, name, visibility)
            case "interface" => generateInterface(language, name, visibility)
            case "enum" => generateEnum(language, name, visibility)
            case "constant" => generateConstant(language, name, returnType, visibility)
            case _ => "// Unsupported snippet type: ${snippetType}"
        }
    }

    protected static func generateFunction(
        language: String,
        name: String,
        parameters: ArrayList<ParameterInfo>,
        returnType: String,
        body: String,
        visibility: String,
        isAsync: Bool
    ): String {
        let vis = if (visibility.isEmpty()) { "" } else { "${visibility} " }
        let async = if (isAsync) { "async " } else { "" }
        let ret = if (returnType.isEmpty()) { "" } else { ": ${returnType}" }
        let funcBody = if (body.isEmpty()) { "\n    // TODO: Implement\n" } else { "\n    ${body}\n" }

        match (language) {
            case "typescript" | "javascript" => "${vis}${async}function ${name}()${ret} {${funcBody}}"
            case "python" => "${vis}def ${name}():${funcBody}"
            case "cangjie" => "${vis}func ${name}()${ret} {${funcBody}}"
            case "java" => "${vis}${async}${returnType} ${name}() {${funcBody}}"
            case _ => "// Function generation not supported for ${language}"
        }
    }

    protected static func generateClass(language: String, name: String, visibility: String): String {
        let vis = if (visibility.isEmpty()) { "" } else { "${visibility} " }

        match (language) {
            case "typescript" | "javascript" => "${vis}class ${name} {\n    // TODO: Implement\n}"
            case "python" => "${vis}class ${name}:\n    # TODO: Implement\n    pass"
            case "cangjie" => "${vis}class ${name} {\n    // TODO: Implement\n}"
            case "java" => "${vis}class ${name} {\n    // TODO: Implement\n}"
            case _ => "// Class generation not supported for ${language}"
        }
    }

    protected static func generateInterface(language: String, name: String, visibility: String): String {
        let vis = if (visibility.isEmpty()) { "" } else { "${visibility} " }

        match (language) {
            case "typescript" => "${vis}interface ${name} {\n    // TODO: Define interface\n}"
            case "cangjie" => "${vis}interface ${name} {\n    // TODO: Define interface\n}"
            case "java" => "${vis}interface ${name} {\n    // TODO: Define interface\n}"
            case _ => "// Interface generation not supported for ${language}"
        }
    }

    protected static func generateEnum(language: String, name: String, visibility: String): String {
        let vis = if (visibility.isEmpty()) { "" } else { "${visibility} " }

        match (language) {
            case "typescript" | "javascript" => "${vis}enum ${name} {\n    // TODO: Define enum values\n}"
            case "python" => "${vis}class ${name}(Enum):\n    # TODO: Define enum values\n    pass"
            case "cangjie" => "${vis}enum ${name} {\n    // TODO: Define enum values\n}" 
            case "java" => "${vis}enum ${name} {\n    // TODO: Define enum values\n}"
            case _ => "// Enum generation not supported for ${language}"
        }
    }

    protected static func generateConstant(language: String, name: String, typeStr: String, visibility: String): String {
        let vis = if (visibility.isEmpty()) { "" } else { "${visibility} " }
        let typeAnnotation = if (typeStr.isEmpty()) { "" } else { ": ${typeStr}" }

        match (language) {
            case "typescript" | "javascript" => "${vis}const ${name}${typeAnnotation} = /* value */;"
            case "python" => "${vis}${name} = None  # TODO: Set value"
            case "cangjie" => "${vis}let ${name}${typeAnnotation} = /* value */"
            case "java" => "${vis}static final ${typeStr} ${name} = /* value */;"
            case _ => "// Constant generation not supported for ${language}"
        }
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

protected struct ParameterInfo {
    public let name: String
    public let paramType: String

    public init(name: String, paramType: String) {
        this.name = name
        this.paramType = paramType
    }
}
