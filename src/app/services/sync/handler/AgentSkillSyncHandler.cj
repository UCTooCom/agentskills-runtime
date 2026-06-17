package magic.app.services.sync.handler

import std.time.DateTime
import std.fs.{Path, exists, Directory, File}
import f_orm.*
import magic.app.dao.uctoo.AgentSkillsDAO
import magic.app.models.uctoo.AgentSkillsPO
import magic.app.services.sync.model.{SyncResult, FileChange, SyncStatus}
import magic.app.services.sync.context.SyncContext
import magic.app.services.sync.mapper.DataMapper
import magic.app.services.sync.status.SyncStatusManager
import magic.app.services.sync.detector.ChangeDetector
import magic.skill.infrastructure.loaders.SkillMdLoader
import magic.skill.domain.models.SkillManifest
import magic.log.LogUtils

public class AgentSkillSyncHandler <: SyncHandler {
    private let dataMapper = DataMapper()
    private let statusManager = SyncStatusManager()
    private let basePath_: String

    public init(basePath: String) {
        this.basePath_ = basePath
    }

    public prop entityType: String {
        get() { "agent_skill" }
    }

    public prop basePath: String {
        get() { basePath_ }
    }

    public prop fileExtension: String {
        get() { ".md" }
    }

    public prop dependencies: Array<String> {
        get() { ["agent"] }
    }

    public func syncFromFileSystem(sourcePath: String, context: SyncContext): SyncResult {
        statusManager.markAgentSkillPending(context.entityId)
        try {
            let fullPath = buildFilePath(sourcePath)
            let skillMdPath = fullPath + "/SKILL.md"
            if (!exists(skillMdPath)) {
                return SyncResult(false, entityType, context.entityId, SyncStatus.Error, "SKILL.md not found: ${skillMdPath}")
            }
            let loader = SkillMdLoader()
            let manifestOpt = loader.loadSkillFromPath(fullPath)
            if (manifestOpt.isNone()) {
                return SyncResult(false, entityType, context.entityId, SyncStatus.Error, "Failed to parse skill from: ${fullPath}")
            }
            let manifest = manifestOpt.getOrThrow()
            let normalizedSourcePath = ChangeDetector().normalizePath(fullPath)
            let skillsDAO = ORM.executor() as AgentSkillsDAO
            let existingPO = if (let Some(dao) <- skillsDAO) {
                findAgentSkillBySourcePath(dao, normalizedSourcePath)
            } else {
                None<AgentSkillsPO>
            }
            let po = dataMapper.skillManifestToPO(manifest, existingPO)
            po.sourcePath = Some(normalizedSourcePath)
            if (let Some(dao) <- skillsDAO) {
                if (existingPO.isSome()) {
                    dao.updateAgentSkills(po)
                    LogUtils.info("AgentSkillSyncHandler: updated skill '${po.name}' from file")
                } else {
                    let newId = dao.insertAgentSkills(po)
                    LogUtils.info("AgentSkillSyncHandler: inserted skill '${po.name}' with id ${newId}")
                }
            }
            statusManager.markAgentSkillSynced(context.entityId)
            return SyncResult(true, entityType, context.entityId, SyncStatus.Synced, "Synced from file: ${normalizedSourcePath}")
        } catch (e: Exception) {
            statusManager.markAgentSkillError(context.entityId)
            LogUtils.error("AgentSkillSyncHandler.syncFromFileSystem failed: ${e.message}")
            return SyncResult(false, entityType, context.entityId, SyncStatus.Error, e.message)
        }
    }

    public func syncToFileSystem(entityId: String, context: SyncContext): SyncResult {
        try {
            let skillsDAO = ORM.executor() as AgentSkillsDAO
            if (let Some(dao) <- skillsDAO) {
                if (let Some(po) <- dao.findAgentSkillsById(entityId)) {
                    if (let Some(sourcePath) <- po.sourcePath) {
                        let manifestOpt = dataMapper.poToSkillManifest(po)
                        if (manifestOpt.isNone()) {
                            return SyncResult(false, entityType, entityId, SyncStatus.Error, "Failed to convert PO to SkillManifest")
                        }
                        let manifest = manifestOpt.getOrThrow()
                        let content = buildSkillMarkdown(manifest)
                        let fullPath = buildFilePath(sourcePath)
                        let skillMdPath = fullPath + "/SKILL.md"
                        writeToFile(skillMdPath, content)
                        statusManager.markAgentSkillSynced(entityId)
                        LogUtils.info("AgentSkillSyncHandler: synced skill '${po.name}' to file")
                        return SyncResult(true, entityType, entityId, SyncStatus.Synced, "Synced to file: ${sourcePath}")
                    }
                    return SyncResult(false, entityType, entityId, SyncStatus.Error, "AgentSkill has no sourcePath")
                }
            }
            return SyncResult(false, entityType, entityId, SyncStatus.Error, "AgentSkill not found: ${entityId}")
        } catch (e: Exception) {
            statusManager.markAgentSkillError(entityId)
            LogUtils.error("AgentSkillSyncHandler.syncToFileSystem failed: ${e.message}")
            return SyncResult(false, entityType, entityId, SyncStatus.Error, e.message)
        }
    }

    public func detectChanges(): Array<FileChange> {
        let detector = ChangeDetector()
        return detector.detectAgentSkillChanges(basePath_)
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


    private func findAgentSkillBySourcePath(dao: AgentSkillsDAO, sourcePath: String): Option<AgentSkillsPO> {
        try {
            let skills = dao.listAllAgentSkills()
            for (skill in skills) {
                match (skill.sourcePath) {
                    case Some(sp) =>
                        if (sp == sourcePath) {
                            return Some(skill)
                        }
                    case None => ()
                }
            }
            return None
        } catch (_: Exception) {
            return None
        }
    }

    private func buildSkillMarkdown(manifest: SkillManifest): String {
        var sb = StringBuilder()
        sb.append("---\n")
        sb.append("name: ${manifest.name}\n")
        sb.append("description: ${manifest.description}\n")
        if (let Some(lic) <- manifest.license) {
            sb.append("license: ${lic}\n")
        }
        if (let Some(compat) <- manifest.compatibility) {
            sb.append("compatibility: \"${compat}\"\n")
        }
        if (let Some(tools) <- manifest.allowedTools) {
            sb.append("allowed-tools: ${tools}\n")
        }
        sb.append("---\n\n")
        sb.append(manifest.instructions)
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
            LogUtils.error("AgentSkillSyncHandler.writeToFile failed: ${e.message}")
            throw e
        }
    }
}
