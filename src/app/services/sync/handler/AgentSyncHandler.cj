package magic.app.services.sync.handler

import std.time.DateTime
import std.fs.{Path, exists, Directory, File}
import f_orm.*
import magic.app.dao.uctoo.AgentsDAO
import magic.app.models.uctoo.AgentsPO
import magic.app.services.sync.model.{SyncResult, FileChange, SyncStatus}
import magic.app.services.sync.context.SyncContext
import magic.app.services.sync.mapper.DataMapper
import magic.app.services.sync.status.SyncStatusManager
import magic.app.services.sync.detector.ChangeDetector
import magic.core.agent.{AgentLoader, AgentDefinition}
import magic.log.LogUtils

public class AgentSyncHandler <: SyncHandler {
    private let dataMapper = DataMapper()
    private let statusManager = SyncStatusManager()
    private let basePath_: String

    public init(basePath: String) {
        this.basePath_ = basePath
    }

    public prop entityType: String {
        get() { "agent" }
    }

    public prop basePath: String {
        get() { basePath_ }
    }

    public prop fileExtension: String {
        get() { ".md" }
    }

    public prop dependencies: Array<String> {
        get() { [] }
    }

    public func syncFromFileSystem(sourcePath: String, context: SyncContext): SyncResult {
        statusManager.markAgentPending(context.entityId)
        try {
            let fullPath = buildFilePath(sourcePath)
            if (!exists(fullPath)) {
                return SyncResult(false, entityType, context.entityId, SyncStatus.Error, "File not found: ${fullPath}")
            }
            let loader = AgentLoader(basePath_)
            let definitionOpt = loader.loadAgentFromFile(Path(fullPath))
            if (definitionOpt.isNone()) {
                return SyncResult(false, entityType, context.entityId, SyncStatus.Error, "Failed to parse agent from file: ${fullPath}")
            }
            let definition = definitionOpt.getOrThrow()
            let normalizedSourcePath = ChangeDetector().normalizePath(fullPath)
            let agentsDAO = ORM.executor() as AgentsDAO
            let existingPO = if (let Some(dao) <- agentsDAO) {
                findAgentBySourcePath(dao, normalizedSourcePath)
            } else {
                None<AgentsPO>
            }
            let po = dataMapper.agentDefinitionToPO(definition, existingPO)
            po.sourcePath = Some(normalizedSourcePath)
            if (let Some(dao) <- agentsDAO) {
                if (existingPO.isSome()) {
                    dao.updateAgents(po)
                    LogUtils.info("AgentSyncHandler: updated agent '${po.name}' from file")
                } else {
                    let newId = dao.insertAgents(po)
                    LogUtils.info("AgentSyncHandler: inserted agent '${po.name}' with id ${newId}")
                }
            }
            statusManager.markAgentSynced(context.entityId)
            return SyncResult(true, entityType, context.entityId, SyncStatus.Synced, "Synced from file: ${normalizedSourcePath}")
        } catch (e: Exception) {
            statusManager.markAgentError(context.entityId)
            LogUtils.error("AgentSyncHandler.syncFromFileSystem failed: ${e.message}")
            return SyncResult(false, entityType, context.entityId, SyncStatus.Error, e.message)
        }
    }

    public func syncToFileSystem(entityId: String, context: SyncContext): SyncResult {
        try {
            let agentsDAO = ORM.executor() as AgentsDAO
            if (let Some(dao) <- agentsDAO) {
                if (let Some(po) <- dao.findAgentsById(entityId)) {
                    if (let Some(sourcePath) <- po.sourcePath) {
                        let definitionOpt = dataMapper.poToAgentDefinition(po)
                        if (definitionOpt.isNone()) {
                            return SyncResult(false, entityType, entityId, SyncStatus.Error, "Failed to convert PO to AgentDefinition")
                        }
                        let definition = definitionOpt.getOrThrow()
                        let content = buildAgentMarkdown(definition)
                        let fullPath = buildFilePath(sourcePath)
                        writeToFile(fullPath, content)
                        statusManager.markAgentSynced(entityId)
                        LogUtils.info("AgentSyncHandler: synced agent '${po.name}' to file")
                        return SyncResult(true, entityType, entityId, SyncStatus.Synced, "Synced to file: ${sourcePath}")
                    }
                    return SyncResult(false, entityType, entityId, SyncStatus.Error, "Agent has no sourcePath")
                }
            }
            return SyncResult(false, entityType, entityId, SyncStatus.Error, "Agent not found: ${entityId}")
        } catch (e: Exception) {
            statusManager.markAgentError(entityId)
            LogUtils.error("AgentSyncHandler.syncToFileSystem failed: ${e.message}")
            return SyncResult(false, entityType, entityId, SyncStatus.Error, e.message)
        }
    }

    public func detectChanges(): Array<FileChange> {
        let detector = ChangeDetector()
        return detector.detectAgentChanges(basePath_)
    }

    public func buildFilePath(sourcePath: String): String {
        // 如果 sourcePath 已经是绝对路径，直接返回（规范化）
        if (sourcePath.startsWith("/") || sourcePath.contains(":")) {
            return normalizePath(sourcePath)
        }
        let trimmedSource = sourcePath.trimStart("/").trimStart("\\")
        if (trimmedSource.isEmpty()) {
            return normalizePath(basePath_)
        }
        // 拼接路径
        let combined = if (basePath_.endsWith("/") || basePath_.endsWith("\\")) {
            basePath_ + trimmedSource
        } else {
            basePath_ + "/" + trimmedSource
        }
        return normalizePath(combined)
    }
    
    private func normalizePath(path: String): String {
        let normalized = path
            .replace("\\\\", "/")  // 将双反斜杠转换为正斜杠
            .replace("//", "/")    // 去除重复的正斜杠
        // 处理 ./ 和 ../
        let parts = normalized.split("/")
        let result = ArrayList<String>()
        for (part in parts) {
            if (part == ".") {
                continue  // 跳过当前目录
            } else if (part == ".." && result.size > 0) {
                result.remove(result.size - 1..result.size)  // 回退到上一级目录（使用 Range）
            } else if (part != "") {
                result.add(part)
            }
        }
        // 如果是 Windows 路径，保留驱动器号后的冒号
        let joined = joinList(result, "/")
        if (path.startsWith("/")) {
            return "/" + joined
        } else if (isWindowsPath(path)) {
            let drive = path[0..2]
            if (joined.size > 2) {
                let rest = joined[2..]
                if (rest.startsWith("/")) {
                    return drive + rest
                }
                return drive + "/" + rest
            }
            return drive + "/"
        }
        return joined
    }
    
    private func joinList(list: ArrayList<String>, separator: String): String {
        if (list.size == 0) {
            return ""
        }
        let result = StringBuilder()
        for (i in 0..list.size) {
            if (i > 0) {
                result.append(separator)
            }
            result.append(list[i])
        }
        return result.toString()
    }
    
    private func isWindowsPath(path: String): Bool {
        if (path.size < 2) {
            return false
        }
        let firstChar = path[0]
        let secondChar = path[1]
        // ASCII values: 'A'-'Z' = 65-90, 'a'-'z' = 97-122, ':' = 58
        let isLetter = (firstChar >= 65 && firstChar <= 90) || (firstChar >= 97 && firstChar <= 122)
        let isColon = secondChar == 58
        return isLetter && isColon
    }


    private func findAgentBySourcePath(dao: AgentsDAO, sourcePath: String): Option<AgentsPO> {
        try {
            let agents = dao.listAllAgents()
            for (agent in agents) {
                match (agent.sourcePath) {
                    case Some(sp) =>
                        if (sp == sourcePath) {
                            return Some(agent)
                        }
                    case None => ()
                }
            }
            return None
        } catch (_: Exception) {
            return None
        }
    }

    private func buildAgentMarkdown(definition: AgentDefinition): String {
        var sb = StringBuilder()
        sb.append("---\n")
        sb.append("name: ${definition.name}\n")
        sb.append("agent_type: ${definition.agentType.toString()}\n")
        sb.append("description: ${definition.description}\n")
        sb.append("version: ${definition.version}\n")
        if (let Some(author) <- definition.author) {
            sb.append("author: ${author}\n")
        }
        if (definition.tools.size > 0) {
            sb.append("tools:\n")
            for (tool in definition.tools) {
                sb.append("  - ${tool}\n")
            }
        }
        if (let Some(model) <- definition.model) {
            sb.append("model: ${model}\n")
        }
        sb.append("maxTurns: ${definition.maxTurns}\n")
        sb.append("memory: ${definition.memory.toString()}\n")
        sb.append("background: ${definition.background}\n")
        if (definition.permissions.size > 0) {
            sb.append("permissions:\n")
            for (perm in definition.permissions) {
                sb.append("  - ${perm.toString()}\n")
            }
        }
        if (let Some(color) <- definition.color) {
            sb.append("color: ${color}\n")
        }
        if (let Some(isolation) <- definition.isolation) {
            sb.append("isolation: ${isolation}\n")
        }
        sb.append("---\n\n")
        sb.append(definition.systemPrompt)
        return sb.toString()
    }

    private func writeToFile(filePath: String, content: String): Unit {
        try {
            let path = Path(filePath)
            let parent = path.parent
            if (!exists(parent.toString())) {
                Directory.create(parent.toString(), recursive: true)
            }
            File.writeTo(filePath, content.toArray())
        } catch (e: Exception) {
            LogUtils.error("AgentSyncHandler.writeToFile failed: ${e.message}")
            throw e
        }
    }
}
