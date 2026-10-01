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

    /**
     * 检测 agent 声明文件的变更（文件侧 vs `agents` 表）。
     *
     * @param bundledSkillRoots 额外扫描根：技能目录（如 `./skills`）。其下各技能的
     *   bundled 子 agent 声明文件（`skills/<skill>/agents/<name>.md`）**同样参与同步**——
     *   这是 T-19「约定即注册」真正落库的入口（此前只扫 `<basePath>/AGENTS.md` 与
     *   `<basePath>/agents/`，技能内声明文件从未入库，故 agents 表只有主 agent）。
     */
    public func detectAgentChanges(basePath: String, bundledSkillRoots!: Array<String> = []): Array<FileChange> {
        let changes = ArrayList<FileChange>()
        try {
            if (!exists(basePath)) {
                LogUtils.warn("ChangeDetector.detectAgentChanges: basePath does not exist: ${basePath}, skip detection")
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
            let mdFiles = collectAgentDeclarationFiles(basePath, bundledSkillRoots)
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
            // v5 实测修复：identityStatus 为 None 等配置缺失是降级场景，降为 WARN 避免每次同步报 ERROR 噪声
            LogUtils.warn("ChangeDetector.detectAgentChanges failed: ${e.message}")
        }
        return changes.toArray()
    }

    public func detectAgentSkillChanges(basePath: String): Array<FileChange> {
        let changes = ArrayList<FileChange>()
        try {
            if (!exists(basePath)) {
                LogUtils.warn("ChangeDetector.detectAgentSkillChanges: basePath does not exist: ${basePath}, skip detection")
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

    /**
     * 汇总本次参与同步的 agent 声明文件：
     *   ① `<basePath>/AGENTS.md` —— 主 Agent；
     *   ② `<basePath>/agents/` 下的 md —— 全局子 Agent；
     *   ③ 各技能根目录（`bundledSkillRoots`）下 `skills/<skill>/agents/` 的 md —— bundled 子 Agent。
     *
     * ③ 是 T-19「约定即注册」的落库入口：缺了它，各技能目录下 bundled 声明文件
     * 永远进不了 `agents` 表，子 agent 派单自然查不到记录。
     *
     * 注：本注释不写目录通配形式（「agents」后接星号点 md）——块注释内斜杠紧跟星号
     * 会被词法器识别为嵌套块注释起始，导致注释无法闭合（cjc 报 unterminated block comment）。
     */
    private func collectAgentDeclarationFiles(basePath: String, bundledSkillRoots: Array<String>): Array<String> {
        let result = ArrayList<String>()
        for (f in collectMdFiles(basePath)) {
            result.add(f)
        }
        for (root in bundledSkillRoots) {
            if (root.isEmpty()) {
                continue
            }
            for (f in collectBundledAgentMdFiles(root)) {
                result.add(f)
            }
        }
        result.toArray()
    }

    /**
     * 收集技能根目录下各技能的 bundled 子 agent 声明文件。
     *
     * **关键坑（2026-09-28 实测）**：`Directory.walk` **非递归**（只遍历直接子项，不含子目录的子项）。
     * 因此不能指望一条 `walk(skillRoot)` 直接落到 `skills/<skill>/agents/` 下的声明文件（那是第三层）。
     * 必须先 walk 出各技能目录（第一层），再对每个技能目录的 `agents/` 子目录 walk 一次
     * ——与 `BundledAgentScanner.scan(skillDir)` 的可用口径一致，否则永远收不到声明文件，
     * agents 表就只剩主 agent（与 134 行 `BundledAgentScanner` 内存探测到 5 个却落不了库是同一处）。
     *
     * 判定口径与 `AgentSyncHandler.deriveSkillName` **保持一致**：路径含 `/agents/` 段才算技能内子 agent。
     */
    private func collectBundledAgentMdFiles(skillRoot: String): Array<String> {
        let result = ArrayList<String>()
        try {
            if (!exists(skillRoot)) {
                LogUtils.warn("ChangeDetector.collectBundledAgentMdFiles: skillRoot does not exist: ${skillRoot}")
                return result.toArray()
            }
            // 第一层：枚举 skillRoot 下的各技能目录（非递归）。
            // 只认含 SKILL.md 的目录，避免把无关子目录当技能扫进去。
            Directory.walk(skillRoot) { skillInfo =>
                if (skillInfo.isDirectory()) {
                    let skillDir = skillInfo.path.toString()
                    let skillMd = if (skillDir.endsWith("/") || skillDir.endsWith("\\")) {
                        "${skillDir}SKILL.md"
                    } else {
                        "${skillDir}/SKILL.md"
                    }
                    if (exists(skillMd)) {
                        // 第二层：walk 该技能的 agents/ 子目录，其直接子项即声明文件。
                        let agentsDir = if (skillDir.endsWith("/") || skillDir.endsWith("\\")) {
                            "${skillDir}agents"
                        } else {
                            "${skillDir}/agents"
                        }
                        if (exists(agentsDir)) {
                            Directory.walk(agentsDir) { fileInfo =>
                                if (!fileInfo.isDirectory() && fileInfo.path.toString().endsWith(".md")) {
                                    let raw = fileInfo.path.toString()
                                    // Windows 反斜杠统一成正斜杠后再判段，避免路径分隔符差异导致漏判
                                    let p = raw.replace("\\", "/")
                                    if (p.contains("/agents/")) {
                                        result.add(raw)
                                    }
                                }
                                return true
                            }
                        }
                    }
                }
                return true
            }
        } catch (_: Exception) {}
        return result.toArray()
    }

    private func collectMdFiles(dirPath: String): Array<String> {
        let result = ArrayList<String>()
        try {
            if (!exists(dirPath)) {
                LogUtils.warn("ChangeDetector.collectMdFiles: dirPath does not exist: ${dirPath}")
                return result.toArray()
            }
            // 只收集 AGENTS.md（主 Agent 定义文件）
            // 不递归扫描整个项目目录，避免把 README.md、docs/*.md 等非 Agent 定义文件同步到 agents 表
            let agentsMdPath = if (dirPath.endsWith("/") || dirPath.endsWith("\\")) {
                "${dirPath}AGENTS.md"
            } else {
                "${dirPath}/AGENTS.md"
            }
            if (exists(agentsMdPath)) {
                result.add(agentsMdPath)
            }
            // 同时支持 agents/ 子目录下的 .md 文件（多 Agent 场景）
            let agentsSubDir = if (dirPath.endsWith("/") || dirPath.endsWith("\\")) {
                "${dirPath}agents"
            } else {
                "${dirPath}/agents"
            }
            if (exists(agentsSubDir)) {
                Directory.walk(agentsSubDir) { fileInfo =>
                    if (!fileInfo.isDirectory() && fileInfo.path.toString().endsWith(".md")) {
                        result.add(fileInfo.path.toString())
                    }
                    return true
                }
            }
        } catch (_: Exception) {}
        return result.toArray()
    }

    private func collectSkillDirs(basePath: String): Array<String> {
        let result = ArrayList<String>()
        try {
            if (!exists(basePath)) {
                LogUtils.warn("ChangeDetector.collectSkillDirs: basePath does not exist: ${basePath}")
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
