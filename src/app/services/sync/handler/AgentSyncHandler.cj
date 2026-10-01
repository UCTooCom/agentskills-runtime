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
    // 技能根目录（如 ./skills）：其下各技能的 bundled 子 agent 声明文件也要参与文件→DB 同步
    private let skillBasePath_: String

    public init(basePath: String, skillBasePath!: String = "") {
        this.basePath_ = basePath
        this.skillBasePath_ = skillBasePath
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
        // entityId 在 file->db 方向是 sourcePath（文件路径），必须用 BySourcePath 版本更新状态，
        // 否则将路径字符串传入 findAgentsById 会触发 "无效的类型 uuid 输入语法"。
        let normalizedId = ChangeDetector().normalizePath(context.entityId)
        statusManager.markAgentPendingBySourcePath(normalizedId)
        try {
            let fullPath = buildFilePath(sourcePath)
            if (!exists(fullPath)) {
                statusManager.markAgentErrorBySourcePath(normalizedId)
                return SyncResult(false, entityType, context.entityId, SyncStatus.Error, "File not found: ${fullPath}")
            }
            let loader = AgentLoader(basePath_)
            let definitionOpt = loader.loadAgentFromFile(Path(fullPath))
            if (definitionOpt.isNone()) {
                statusManager.markAgentErrorBySourcePath(normalizedId)
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
            // T-14: 子 agent 落库时绑定所属技能名（skills/<skill_name>/agents/*.md），供 REQ-SDD-011 自动探测
            po.skillName = deriveSkillName(normalizedSourcePath)
            if (let Some(dao) <- agentsDAO) {
                if (existingPO.isSome()) {
                    dao.updateAgents(po)
                    LogUtils.info("AgentSyncHandler: updated agent '${po.name}' from file (matched by sourcePath)")
                } else {
                    // sourcePath 未匹配，尝试通过 name 查找已有记录
                    // 逻辑上应该更新 AGENTS.md 中的 name 和 agents 表 name 一致的数据
                    // 而不是新创建相同 name 的数据
                    match (findAgentByName(dao, definition.name)) {
                        case Some(existingByName) =>
                            // 找到同名记录，更新它（包括 sourcePath）
                            po.id = existingByName.id
                            dao.updateAgents(po)
                            LogUtils.info("AgentSyncHandler: updated agent '${po.name}' from file (matched by name, existing id=${existingByName.id})")
                        case None =>
                            // 既无 sourcePath 匹配也无 name 匹配，插入新记录
                            let newId = dao.insertAgents(po)
                            LogUtils.info("AgentSyncHandler: inserted agent '${po.name}' with id ${newId}")
                    }
                }
            }
            statusManager.markAgentSyncedBySourcePath(normalizedSourcePath)
            return SyncResult(true, entityType, context.entityId, SyncStatus.Synced, "Synced from file: ${normalizedSourcePath}")
        } catch (e: Exception) {
            statusManager.markAgentErrorBySourcePath(normalizedId)
            LogUtils.error("AgentSyncHandler.syncFromFileSystem failed: ${e.message}")
            return SyncResult(false, entityType, context.entityId, SyncStatus.Error, e.message)
        }
    }

    /**
     * **删除即下线**（2026-09-28 补齐）：声明文件被删 → `agents` 表对应行**软删**（置 deleted_at）。
     *
     * 此前 `SyncManager.syncAll` 对 `ChangeType.Deleted` 只跳过，导致"删文件即下线"
     * 这条约定只说了一半——文件删了、库里行还在，子 agent 仍可被派单。
     *
     * 两个刻意的保守选择：
     *   1. **只软删不做物理删除**：同步链路的删除判定可能因目录临时不可见而误判，
     *      不可逆的物理删除代价太大；软删后仍可恢复。
     *   2. **按 source_path 精确定位**：不用 name 兜底，避免误伤同名但来源不同的记录。
     */
    public func offlineBySourcePath(sourcePath: String): Bool {
        let normalized = ChangeDetector().normalizePath(sourcePath)
        try {
            let agentsDAO = ORM.executor() as AgentsDAO
            if (let Some(dao) <- agentsDAO) {
                match (findAgentBySourcePath(dao, normalized)) {
                    case Some(po) =>
                        if (po.deletedAt.isSome()) {
                            return true
                        }
                        po.deletedAt = Some<DateTime>(DateTime.now())
                        dao.updateAgents(po)
                        LogUtils.info("AgentSyncHandler: 声明文件已删除，软删下线 agent '${po.name}' source=${normalized}")
                        return true
                    case None =>
                        LogUtils.warn("AgentSyncHandler: 声明文件已删除但库里无对应行（无需下线）: ${normalized}")
                        return false
                }
            }
        } catch (e: Exception) {
            LogUtils.error("AgentSyncHandler.offlineBySourcePath 失败: ${normalized}, ${e.message}")
        }
        false
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
                        // 用 sourcePath（文件路径）更新状态，避免把路径当 UUID 传入 findAgentsById
                        statusManager.markAgentSyncedBySourcePath(sourcePath)
                        LogUtils.info("AgentSyncHandler: synced agent '${po.name}' to file")
                        return SyncResult(true, entityType, entityId, SyncStatus.Synced, "Synced to file: ${sourcePath}")
                    }
                    return SyncResult(false, entityType, entityId, SyncStatus.Error, "Agent has no sourcePath")
                }
            }
            return SyncResult(false, entityType, entityId, SyncStatus.Error, "Agent not found: ${entityId}")
        } catch (e: Exception) {
            // syncToFileSystem 入参 entityId 理论上是 UUID，但 SyncInterceptor 从 DAO 返回值
            // 提取的 entityId 可能是路径字符串。用 BySourcePath 版本更新状态，
            // 即使 entityId 是路径也不会触发 "无效的类型 uuid 输入语法" 错误。
            statusManager.markAgentErrorBySourcePath(entityId)
            LogUtils.error("AgentSyncHandler.syncToFileSystem failed: ${e.message}")
            return SyncResult(false, entityType, entityId, SyncStatus.Error, e.message)
        }
    }

    /**
     * 文件侧变更检测：`<basePath>` 下的 AGENTS.md / agents 目录 **加上** 技能目录里
     * 各技能的 bundled 子 agent 声明文件（`skills/<skill>/agents/<name>.md`）。
     *
     * 后者是 T-19 落库的关键：漏掉它，`agents` 表里就只有主 agent（2026-09-28 实测现象）。
     */
    public func detectChanges(): Array<FileChange> {
        let detector = ChangeDetector()
        if (skillBasePath_.isEmpty()) {
            return detector.detectAgentChanges(basePath_)
        }
        return detector.detectAgentChanges(basePath_, bundledSkillRoots: [skillBasePath_])
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

    /// 通过 name 查找已有 agent 记录（避免创建重复的同名记录）
    private func findAgentByName(dao: AgentsDAO, name: String): Option<AgentsPO> {
        try {
            let agents = dao.listAllAgents()
            for (agent in agents) {
                if (agent.name == name) {
                    return Some(agent)
                }
            }
            return None
        } catch (_: Exception) {
            return None
        }
    }

    /// 从 agent 来源路径推导所属技能名。
    /// 约定（REQ-SDD-011）：子 agent 声明于 skills/<skill_name>/agents/<name>.md，
    /// 仅当文件路径包含 "/agents/" 段时才归属该技能；主 agent（AGENTS.md 或全局 agent）留空（见迁移注释：主agent为空）。
    private func deriveSkillName(sourcePath: String): Option<String> {
        let parts = sourcePath.split("/")
        let n = parts.size
        for (i in 0..n) {
            if (parts[i] == "agents" && i > 0) {
                return Some(parts[i - 1])
            }
        }
        return None<String>
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
        if (let Some(aic) <- definition.aic) {
            sb.append("aic: ${aic}\n")
        }
        if (definition.identityStatus != "none") {
            sb.append("identity_status: ${definition.identityStatus}\n")
        }
        if (let Some(capabilities) <- definition.capabilities) {
            sb.append("capabilities: ${capabilities}\n")
        }
        if (let Some(defaultInputTypes) <- definition.defaultInputTypes) {
            sb.append("default_input_types: ${defaultInputTypes}\n")
        }
        if (let Some(defaultOutputTypes) <- definition.defaultOutputTypes) {
            sb.append("default_output_types: ${defaultOutputTypes}\n")
        }
        if (!definition.discoverable) {
            sb.append("discoverable: false\n")
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
