/*
 * Copyright (c) 2026. All rights reserved.
 */
public package magic.core.agent

import std.collection.ArrayList
import std.io.IOException
import std.fs.{File, Path}
import stdx.encoding.json.*
import magic.jsonable.JsonUtils
import magic.skill.infrastructure.utils.MarkdownUtils

/**
 * Agent 类型枚举
 */
public enum AgentType {
    /** 主 Agent，负责任务分解和协调 */
    | MAIN
    /** 子 Agent，执行特定任务 */
    | SUB
    /** 分析 Agent，分析结果并生成建议 */
    | ANALYZER
    /** 比较 Agent，盲评比较输出 */
    | COMPARATOR
    /** 评估 Agent，评估期望是否达成 */
    | GRADER
    
    public func ordinal(): Int64 {
        match (this) {
            case MAIN => 0
            case SUB => 1
            case ANALYZER => 2
            case COMPARATOR => 3
            case GRADER => 4
        }
    }
    
    public func toString(): String {
        match (this) {
            case MAIN => "MAIN"
            case SUB => "SUB"
            case ANALYZER => "ANALYZER"
            case COMPARATOR => "COMPARATOR"
            case GRADER => "GRADER"
        }
    }
    
    public operator func ==(other: AgentType): Bool {
        this.ordinal() == other.ordinal()
    }
}

/**
 * Agent 权限定义
 */
public struct AgentPermission {
    public let resource: String
    public let action: String
    
    public init(resource: String, action: String) {
        this.resource = resource
        this.action = action
    }
    
    /**
     * 解析权限字符串，格式："resource:action"
     */
    public static func parse(permissionStr: String): Option<AgentPermission> {
        let parts = permissionStr.split(":")
        if (parts.size == 2) {
            let resource = parts.get(0)
            let action = parts.get(1)
            if (resource.isSome() && action.isSome()) {
                return Some(AgentPermission(resource.getOrThrow(), action.getOrThrow()))
            }
        }
        return None
    }
    
    /**
     * 转换为字符串表示
     */
    public func toString(): String {
        return "${resource}:${action}"
    }
}

/**
 * Agent 内存范围
 */
public enum AgentMemory {
    /** 用户级内存 */
    | USER
    /** 项目级内存 */
    | PROJECT
    /** 本地内存 */
    | LOCAL
    
    public func toString(): String {
        match (this) {
            case USER => "USER"
            case PROJECT => "PROJECT"
            case LOCAL => "LOCAL"
        }
    }
}

/**
 * Agent 定义
 * 
 * 从 Markdown 文件的 frontmatter 解析得到
 */
public class AgentDefinition {
    /** Agent 名称 */
    public let name: String
    
    /** Agent 类型 */
    public let `type`: AgentType
    
    /** Agent 描述 */
    public let description: String
    
    /** 版本号 */
    public let version: String
    
    /** 作者 */
    public let author: Option<String>
    
    /** 可用工具列表 */
    public let tools: Array<String>
    
    /** 使用的模型 */
    public let model: Option<String>
    
    /** 最大对话轮数 */
    public let maxTurns: Int64
    
    /** 内存范围 */
    public let memory: AgentMemory
    
    /** 是否后台运行 */
    public let background: Bool
    
    /** 权限列表 */
    public let permissions: Array<AgentPermission>
    
    /** 显示颜色 */
    public let color: Option<String>
    
    /** 隔离模式 */
    public let isolation: Option<String>
    
    /** 系统提示词 */
    public let systemPrompt: String
    
    /** 源文件路径 */
    public let sourcePath: Path
    
    /** 基础目录 */
    public let baseDir: Path
    
    public init(
        name: String,
        `type`: AgentType,
        description: String,
        version: String,
        author: Option<String>,
        tools: Array<String>,
        model: Option<String>,
        maxTurns: Int64,
        memory: AgentMemory,
        background: Bool,
        permissions: Array<AgentPermission>,
        color: Option<String>,
        isolation: Option<String>,
        systemPrompt: String,
        sourcePath: Path,
        baseDir: Path
    ) {
        this.name = name
        this.`type` = `type`
        this.description = description
        this.version = version
        this.author = author
        this.tools = tools
        this.model = model
        this.maxTurns = maxTurns
        this.memory = memory
        this.background = background
        this.permissions = permissions
        this.color = color
        this.isolation = isolation
        this.systemPrompt = systemPrompt
        this.sourcePath = sourcePath
        this.baseDir = baseDir
    }
    
    /**
     * 构建 AgentDefinition
     */
    public static func builder(): AgentDefinitionBuilder {
        return AgentDefinitionBuilder()
    }
    
    /**
     * 转换为 JSON 对象
     */
    public func toJson(): JsonObject {
        let items = ArrayList<(String, JsonValue)>()
        
        items.add(("name", JsonString(name)))
        items.add(("type", JsonString(`type`.toString())))
        items.add(("description", JsonString(description)))
        items.add(("version", JsonString(version)))
        
        if (let Some(authorVal) <- author) {
            items.add(("author", JsonString(authorVal)))
        }
        
        items.add(("tools", JsonUtils.buildJsonArray(tools)))
        
        if (let Some(modelVal) <- model) {
            items.add(("model", JsonString(modelVal)))
        }
        
        items.add(("maxTurns", JsonInt(maxTurns)))
        items.add(("memory", JsonString(memory.toString())))
        items.add(("background", JsonBool(background)))
        
        let permArray = Array<JsonValue>(permissions.size, { i: Int64 =>
            JsonString(permissions[i].toString())
        })
        items.add(("permissions", JsonArray(permArray)))
        
        if (let Some(colorVal) <- color) {
            items.add(("color", JsonString(colorVal)))
        }
        
        if (let Some(isolationVal) <- isolation) {
            items.add(("isolation", JsonString(isolationVal)))
        }
        
        return JsonUtils.buildJsonObject(items.toArray())
    }
}

/**
 * AgentDefinition 构建器
 */
public class AgentDefinitionBuilder {
    private var name: Option<String> = None
    private var `type`: Option<AgentType> = None
    private var description: Option<String> = None
    private var version: String = "1.0.0"
    private var author: Option<String> = None
    private var tools: Array<String> = []
    private var model: Option<String> = None
    private var maxTurns: Int64 = 200
    private var memory: AgentMemory = AgentMemory.USER
    private var background: Bool = false
    private var permissions: Array<AgentPermission> = []
    private var color: Option<String> = None
    private var isolation: Option<String> = None
    private var systemPrompt: Option<String> = None
    private var sourcePath: Option<Path> = None
    private var baseDir: Option<Path> = None
    
    public func setName(name: String): AgentDefinitionBuilder {
        this.name = Some(name)
        return this
    }
    
    public func setType(`type`: AgentType): AgentDefinitionBuilder {
        this.`type` = Some(`type`)
        return this
    }
    
    public func setType(`type`: String): AgentDefinitionBuilder {
        this.`type` = Some(parseAgentType(`type`))
        return this
    }
    
    public func setDescription(description: String): AgentDefinitionBuilder {
        this.description = Some(description)
        return this
    }
    
    public func setVersion(version: String): AgentDefinitionBuilder {
        this.version = version
        return this
    }
    
    public func setAuthor(author: String): AgentDefinitionBuilder {
        this.author = Some(author)
        return this
    }
    
    public func setTools(tools: Array<String>): AgentDefinitionBuilder {
        this.tools = tools
        return this
    }
    
    public func setModel(model: String): AgentDefinitionBuilder {
        this.model = Some(model)
        return this
    }
    
    public func setMaxTurns(maxTurns: Int64): AgentDefinitionBuilder {
        this.maxTurns = maxTurns
        return this
    }
    
    public func setMemory(memory: AgentMemory): AgentDefinitionBuilder {
        this.memory = memory
        return this
    }
    
    public func setMemory(memory: String): AgentDefinitionBuilder {
        this.memory = parseAgentMemory(memory)
        return this
    }
    
    public func setBackground(background: Bool): AgentDefinitionBuilder {
        this.background = background
        return this
    }
    
    public func setPermissions(permissions: Array<AgentPermission>): AgentDefinitionBuilder {
        this.permissions = permissions
        return this
    }
    
    public func setColor(color: String): AgentDefinitionBuilder {
        this.color = Some(color)
        return this
    }
    
    public func setIsolation(isolation: String): AgentDefinitionBuilder {
        this.isolation = Some(isolation)
        return this
    }
    
    public func setSystemPrompt(systemPrompt: String): AgentDefinitionBuilder {
        this.systemPrompt = Some(systemPrompt)
        return this
    }
    
    public func setSourcePath(sourcePath: Path): AgentDefinitionBuilder {
        this.sourcePath = Some(sourcePath)
        return this
    }
    
    public func setBaseDir(baseDir: Path): AgentDefinitionBuilder {
        this.baseDir = Some(baseDir)
        return this
    }
    
    public func build(): Option<AgentDefinition> {
        if (name.isNone() || `type`.isNone() || description.isNone() || systemPrompt.isNone()) {
            return None
        }
        
        return Some(AgentDefinition(
            name.getOrThrow(),
            `type`.getOrThrow(),
            description.getOrThrow(),
            version,
            author,
            tools,
            model,
            maxTurns,
            memory,
            background,
            permissions,
            color,
            isolation,
            systemPrompt.getOrThrow(),
            sourcePath.getOrThrow(),
            baseDir.getOrThrow()
        ))
    }
    
    private func parseAgentType(typeStr: String): AgentType {
        match (typeStr.toAsciiLower()) {
            case "main" => AgentType.MAIN
            case "sub" => AgentType.SUB
            case "analyzer" => AgentType.ANALYZER
            case "comparator" => AgentType.COMPARATOR
            case "grader" => AgentType.GRADER
            case _ => AgentType.SUB // 默认为子 Agent
        }
    }
    
    private func parseAgentMemory(memoryStr: String): AgentMemory {
        match (memoryStr.toAsciiLower()) {
            case "user" => AgentMemory.USER
            case "project" => AgentMemory.PROJECT
            case "local" => AgentMemory.LOCAL
            case _ => AgentMemory.USER // 默认为用户级
        }
    }
}
