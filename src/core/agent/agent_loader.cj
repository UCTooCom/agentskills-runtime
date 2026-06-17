/*
 * Copyright (c) 2026. All rights reserved.
 */
public package magic.core.agent

import std.collection.{ArrayList, HashMap}
import std.io.{IOException, StringReader}
import std.fs.{File, Path, exists, Directory, FileInfo, OpenMode}
import std.convert.*
import stdx.encoding.json.*
import magic.jsonable.JsonUtils
import magic.skill.infrastructure.utils.{YamlUtils, MarkdownUtils}
import magic.log.LogUtils

/**
 * Agent 加载器
 * 
 * 负责从 Markdown 文件加载 Agent 定义，参考现有的 SkillLoadingService 实现
 */
public class AgentLoader {
    private let baseDir: Path
    
    public init(baseDir: String) {
        this.baseDir = Path(baseDir)
    }
    
    /**
     * 从目录或文件加载所有 Agent 定义
     * 支持两种路径类型：
     * - 目录路径：遍历目录中的 .md 文件
     * - 文件路径：直接加载单个 .md 文件
     */
    public func loadAgentsFromDir(dir: String): Array<AgentDefinition> {
        // 首先检查路径是否存在
        if (!exists(dir)) {
            LogUtils.error("[AgentLoader] Path not found: ${dir}")
            return []
        }
        
        // 检查是文件还是目录（使用 try-catch 处理，因为 FileInfo.get 可能不适用于目录）
        let dirPath = Path(dir)
        try {
            let testFile = File(dir, OpenMode.Read)
            testFile.close()
            // 如果能打开文件，说明是文件
            LogUtils.info("[AgentLoader] Loading agent from file: ${dir}")
            match (loadAgentFromFile(dirPath)) {
                case Some(agent) => return [agent]
                case None => 
                    LogUtils.warn("[AgentLoader] Failed to load agent from file: ${dir}")
                    return []
            }
        } catch (_: Exception) {
            // 打开文件失败，可能是目录，继续按目录处理
        }
        
        // 是目录，遍历加载所有 .md 文件
        let agents = ArrayList<AgentDefinition>()
        
        try {
            // 获取所有子目录中的 .md 文件
            let mdFiles = ArrayList<Path>()
            Directory.walk(dir) { fileInfo =>
                if (fileInfo.isRegular() && fileInfo.path.extensionName == "md") {
                    mdFiles.add(fileInfo.path)
                }
                return true
            }
            
            for (filePath in mdFiles.toArray()) {
                match (loadAgentFromFile(filePath)) {
                    case Some(agent) => agents.add(agent)
                    case None => LogUtils.warn("[AgentLoader] Failed to load agent from: ${filePath}")
                }
            }
        } catch (e: IOException) {
            LogUtils.error("[AgentLoader] Error listing directory ${dir}: ${e.message}")
        }
        
        return agents.toArray()
    }
    
    /**
     * 从文件加载单个 Agent 定义
     */
    public func loadAgentFromFile(filePath: Path): Option<AgentDefinition> {
        if (!exists(filePath.toString())) {
            LogUtils.warn("[AgentLoader] File not found: ${filePath}")
            return None
        }
        
        try {
            let content = readFileContent(filePath.toString())
            return parseAgentFromMarkdown(filePath, content)
        } catch (e: IOException) {
            LogUtils.error("[AgentLoader] Error reading file ${filePath}: ${e.message}")
            return None
        }
    }
    
    /**
     * 读取文件内容
     */
    private func readFileContent(path: String): String {
        let file = File(path, OpenMode.Read)
        let reader = StringReader(file)
        let content = reader.readToEnd()
        file.close()
        return content
    }
    
    /**
     * 从 Markdown 内容解析 Agent 定义
     */
    private func parseAgentFromMarkdown(filePath: Path, content: String): Option<AgentDefinition> {
        // 使用现有的 YamlUtils 提取 frontmatter
        let frontmatterContentOpt = YamlUtils.extractYamlFrontmatter(content)
        
        if (frontmatterContentOpt.isNone()) {
            LogUtils.warn("[AgentLoader] No frontmatter found in: ${filePath}")
            return None
        }
        
        // 使用现有的 YamlUtils 解析 YAML
        let parsedYamlOpt = YamlUtils.parseYamlContent(frontmatterContentOpt.getOrThrow())
        if (parsedYamlOpt.isNone()) {
            LogUtils.warn("[AgentLoader] Failed to parse frontmatter in: ${filePath}")
            return None
        }
        
        let parsedYaml = parsedYamlOpt.getOrThrow()
        
        // 提取 markdown body
        let markdownBody = extractMarkdownBody(content)
        
        // 从 YAML 构建 AgentDefinition
        return buildAgentFromYaml(filePath, parsedYaml, markdownBody)
    }
    
    /**
     * 提取 markdown body（第二个 --- 之后的内容）
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
            return String.join(bodyLines, delimiter: "\n").trimAscii()
        }
        
        return ""
    }
    
    /**
     * 从 YAML 数据构建 AgentDefinition
     */
    private func buildAgentFromYaml(filePath: Path, yaml: HashMap<String, String>, body: String): Option<AgentDefinition> {
        let builder = AgentDefinition.builder()
        
        // 必填字段
        let name = yaml.get("name")
        let agentType = yaml.get("agent_type")
        let description = yaml.get("description")
        
        if (name.isNone() || agentType.isNone() || description.isNone()) {
            LogUtils.warn("[AgentLoader] Missing required fields in: ${filePath}")
            return None
        }
        
        builder
            .setName(name.getOrThrow())
            .setAgentType(agentType.getOrThrow())
            .setDescription(description.getOrThrow())
            .setSystemPrompt(body)
            .setSourcePath(filePath)
            .setBaseDir(filePath.parent)
        
        // 可选字段
        if (let Some(version) <- yaml.get("version")) {
            builder.setVersion(version)
        }
        
        if (let Some(author) <- yaml.get("author")) {
            builder.setAuthor(author)
        }
        
        // 解析工具列表（YAML 数组）
        if (let Some(toolsStr) <- yaml.get("tools")) {
            let tools = parseYamlArray(toolsStr)
            builder.setTools(tools)
        }
        
        if (let Some(model) <- yaml.get("model")) {
            builder.setModel(model)
        }
        
        if (let Some(maxTurnsStr) <- yaml.get("maxTurns")) {
            let parsed = Int64.parse(maxTurnsStr)
            if (let maxTurns <- parsed) {
                builder.setMaxTurns(maxTurns)
            }
        }
        
        if (let Some(memory) <- yaml.get("memory")) {
            builder.setMemory(memory)
        }
        
        if (let Some(backgroundStr) <- yaml.get("background")) {
            builder.setBackground(backgroundStr.toAsciiLower() == "true")
        }
        
        // 解析权限列表（YAML 数组）
        if (let Some(permissionsStr) <- yaml.get("permissions")) {
            let permissions = ArrayList<AgentPermission>()
            for (permStr in parseYamlArray(permissionsStr)) {
                match (AgentPermission.parse(permStr)) {
                    case Some(perm) => permissions.add(perm)
                    case None => LogUtils.warn("[AgentLoader] Invalid permission: ${permStr}")
                }
            }
            builder.setPermissions(permissions.toArray())
        }
        
        if (let Some(color) <- yaml.get("color")) {
            builder.setColor(color)
        }
        
        if (let Some(isolation) <- yaml.get("isolation")) {
            builder.setIsolation(isolation)
        }
        
        return builder.build()
    }
    
    /**
     * 解析 YAML 数组字符串
     */
    private func parseYamlArray(arrayStr: String): Array<String> {
        let items = ArrayList<String>()
        
        // 去除方括号
        let inner = arrayStr.trimAscii()
        if (!inner.startsWith("[") || !inner.endsWith("]")) {
            return items.toArray()
        }
        
        let content = inner[1..(inner.size - 1)]
        let parts = content.split(",")
        
        for (part in parts) {
            let trimmed = part.trimAscii().replace("\"", "").replace("'", "")
            if (!trimmed.isEmpty()) {
                items.add(trimmed)
            }
        }
        
        return items.toArray()
    }
}

/**
 * Agent 加载管理器
 * 
 * 管理多个目录的 Agent 加载，参考现有的 SkillLoadingService 实现
 */
public class AgentLoadManager {
    private let loader: AgentLoader
    private let agents: ArrayList<AgentDefinition>
    
    public init(baseDir: String) {
        this.loader = AgentLoader(baseDir)
        this.agents = ArrayList<AgentDefinition>()
    }
    
    /**
     * 从多个目录加载 Agents
     */
    public func loadFromDirs(dirs: Array<String>): Unit {
        LogUtils.info("[AgentLoadManager] Starting to load agents from ${dirs.size} directories")
        
        for (dir in dirs) {
            LogUtils.info("[AgentLoadManager] Loading agents from: ${dir}")
            let dirAgents = loader.loadAgentsFromDir(dir)
            for (agent in dirAgents) {
                agents.add(agent)
                LogUtils.info("[AgentLoadManager] Loaded agent: ${agent.name} (${agent.agentType.toString()})")
            }
        }
        
        LogUtils.info("[AgentLoadManager] Total agents loaded: ${agents.size}")
    }
    
    /**
     * 获取所有已加载的 Agent
     */
    public func getAllAgents(): Array<AgentDefinition> {
        return agents.toArray()
    }
    
    /**
     * 根据名称获取 Agent
     */
    public func getAgentByName(name: String): Option<AgentDefinition> {
        for (agent in agents) {
            if (agent.name == name) {
                return Some(agent)
            }
        }
        return None
    }
    
    /**
     * 根据类型获取 Agents
     */
    public func getAgentsByType(agentType: AgentType): Array<AgentDefinition> {
        let result = ArrayList<AgentDefinition>()
        for (agent in agents) {
            if (agent.agentType == agentType) {
                result.add(agent)
            }
        }
        return result.toArray()
    }
    
    /**
     * 重新加载所有 Agents
     */
    public func reload(): Unit {
        agents.clear()
        LogUtils.info("[AgentLoadManager] Agent cache cleared, ready for reload")
    }
    
    /**
     * 获取主 Agent（类型为 MAIN 的 Agent）
     */
    public func getMainAgent(): Option<AgentDefinition> {
        let mainAgents = getAgentsByType(AgentType.MAIN)
        if (mainAgents.size > 0) {
            return mainAgents.get(0)
        }
        return None
    }
}
