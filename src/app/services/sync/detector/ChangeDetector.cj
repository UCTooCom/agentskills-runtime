package magic.app.services.sync.detector

import std.collection.{HashMap, ArrayList}
import std.fs.{FileInfo, Directory, exists}
import std.time.DateTime
import f_orm.*
import magic.app.dao.uctoo.{AgentsDAO, AgentSkillsDAO}
import magic.app.services.sync.model.{FileChange, ChangeType}
import magic.log.LogUtils

public class ChangeDetector {

    public init() {}

    public func detectAgentChanges(basePath: String): Array<FileChange> {
        let changes = ArrayList<FileChange>()
        try {
            if (!exists(basePath)) {
                return changes.toArray()
            }
            let dbSourcePaths = HashMap<String, DateTime>()
            let agentsDAO = ORM.executor() as AgentsDAO
            if (let Some(dao) <- agentsDAO) {
                let agents = dao.listAllAgents()
                for (agent in agents) {
                    match (agent.sourcePath) {
                        case Some(sp) =>
                            dbSourcePaths.add(sp, agent.updatedAt)
                        case None => ()
                    }
                }
            }
            let fileSourcePaths = HashMap<String, DateTime>()
            let mdFiles = collectMdFiles(basePath)
            for (filePath in mdFiles) {
                let normalizedPath = normalizePath(filePath)
                fileSourcePaths.add(normalizedPath, DateTime.now())
            }
            for ((normalizedPath, modTime) in fileSourcePaths.iterator()) {
                match (dbSourcePaths.get(normalizedPath)) {
                    case Some(dbModTime) =>
                        let change = FileChange()
                        change.path = normalizedPath
                        change.sourcePath = normalizedPath
                        change.changeType = ChangeType.Modified
                        change.lastModified = modTime
                        change.entityType = "agent"
                        changes.add(change)
                    case None =>
                        let change = FileChange()
                        change.path = normalizedPath
                        change.sourcePath = normalizedPath
                        change.changeType = ChangeType.Created
                        change.lastModified = modTime
                        change.entityType = "agent"
                        changes.add(change)
                }
            }
            for ((dbPath, dbModTime) in dbSourcePaths.iterator()) {
                if (!fileSourcePaths.contains(dbPath)) {
                    let change = FileChange()
                    change.path = dbPath
                    change.sourcePath = dbPath
                    change.changeType = ChangeType.Deleted
                    change.lastModified = dbModTime
                    change.entityType = "agent"
                    changes.add(change)
                }
            }
        } catch (e: Exception) {
            LogUtils.error("ChangeDetector.detectAgentChanges failed: ${e.message}")
        }
        return changes.toArray()
    }

    public func detectAgentSkillChanges(basePath: String): Array<FileChange> {
        let changes = ArrayList<FileChange>()
        try {
            if (!exists(basePath)) {
                return changes.toArray()
            }
            let dbSourcePaths = HashMap<String, DateTime>()
            let skillsDAO = ORM.executor() as AgentSkillsDAO
            if (let Some(dao) <- skillsDAO) {
                let skills = dao.listAllAgentSkills()
                for (skill in skills) {
                    match (skill.sourcePath) {
                        case Some(sp) =>
                            dbSourcePaths.add(sp, skill.updatedAt)
                        case None => ()
                    }
                }
            }
            let fileSourcePaths = HashMap<String, DateTime>()
            let skillDirs = collectSkillDirs(basePath)
            for (skillDir in skillDirs) {
                let normalizedPath = normalizePath(skillDir)
                fileSourcePaths.add(normalizedPath, DateTime.now())
            }
            for ((normalizedPath, modTime) in fileSourcePaths.iterator()) {
                match (dbSourcePaths.get(normalizedPath)) {
                    case Some(dbModTime) =>
                        let change = FileChange()
                        change.path = normalizedPath
                        change.sourcePath = normalizedPath
                        change.changeType = ChangeType.Modified
                        change.lastModified = modTime
                        change.entityType = "agent_skill"
                        changes.add(change)
                    case None =>
                        let change = FileChange()
                        change.path = normalizedPath
                        change.sourcePath = normalizedPath
                        change.changeType = ChangeType.Created
                        change.lastModified = modTime
                        change.entityType = "agent_skill"
                        changes.add(change)
                }
            }
            for ((dbPath, dbModTime) in dbSourcePaths.iterator()) {
                if (!fileSourcePaths.contains(dbPath)) {
                    let change = FileChange()
                    change.path = dbPath
                    change.sourcePath = dbPath
                    change.changeType = ChangeType.Deleted
                    change.lastModified = dbModTime
                    change.entityType = "agent_skill"
                    changes.add(change)
                }
            }
        } catch (e: Exception) {
            LogUtils.error("ChangeDetector.detectAgentSkillChanges failed: ${e.message}")
        }
        return changes.toArray()
    }

    private func collectMdFiles(dirPath: String): Array<String> {
        let result = ArrayList<String>()
        try {
            if (!exists(dirPath)) {
                return result.toArray()
            }
            Directory.walk(dirPath) { fileInfo =>
                if (!fileInfo.isDirectory() && fileInfo.path.toString().endsWith(".md")) {
                    result.add(fileInfo.path.toString())
                }
                return true
            }
        } catch (_: Exception) {}
        return result.toArray()
    }

    private func collectSkillDirs(basePath: String): Array<String> {
        let result = ArrayList<String>()
        try {
            if (!exists(basePath)) {
                return result.toArray()
            }
            Directory.walk(basePath) { fileInfo =>
                if (fileInfo.isDirectory()) {
                    let skillMdPath = fileInfo.path.toString() + "/SKILL.md"
                    if (exists(skillMdPath)) {
                        result.add(fileInfo.path.toString())
                    }
                }
                return true
            }
        } catch (_: Exception) {}
        return result.toArray()
    }

    public func normalizePath(path: String): String {
        let normalized = path.replace("\\", "/")
        let parts = normalized.split("/")
        let result = ArrayList<String>()
        for (part in parts) {
            if (part == ".") {
                continue
            } else if (part == ".." && result.size > 0) {
                result.remove(result.size - 1..result.size)
            } else if (part != "") {
                result.add(part)
            }
        }
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
        let isLetter = (firstChar >= 65 && firstChar <= 90) || (firstChar >= 97 && firstChar <= 122)
        let isColon = secondChar == 58
        return isLetter && isColon
    }
}
