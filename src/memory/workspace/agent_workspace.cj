package magic.memory.workspace

import std.collection.ArrayList
import std.time.DateTime
import std.sort.*

public enum WorkspaceFileType {
    | Agents
    | Soul
    | Tools
    | Identity
    | User
    | Memory
    | Heartbeat
    | DailyMemory
}

public class WorkspaceFile {
    public let fileType: WorkspaceFileType
    public let filePath: String
    public let content: Option<String>
    public let lastModified: Option<DateTime>
    
    public init(
        fileType: WorkspaceFileType,
        filePath: String,
        content: Option<String>,
        lastModified: Option<DateTime>
    ) {
        this.fileType = fileType
        this.filePath = filePath
        this.content = content
        this.lastModified = lastModified
    }
    
    public static func create(fileType: WorkspaceFileType, filePath: String): WorkspaceFile {
        return WorkspaceFile(fileType, filePath, None, None)
    }
    
    public func withContent(content: String): WorkspaceFile {
        return WorkspaceFile(this.fileType, this.filePath, Some(content), this.lastModified)
    }
    
    public func withLastModified(time: DateTime): WorkspaceFile {
        return WorkspaceFile(this.fileType, this.filePath, this.content, Some(time))
    }
}

public class AgentWorkspace {
    public let workspacePath: String
    public let agentsFile: Option<WorkspaceFile>
    public let soulFile: Option<WorkspaceFile>
    public let toolsFile: Option<WorkspaceFile>
    public let identityFile: Option<WorkspaceFile>
    public let userFile: Option<WorkspaceFile>
    public let memoryFile: Option<WorkspaceFile>
    public let heartbeatFile: Option<WorkspaceFile>
    public let dailyMemoryFiles: ArrayList<WorkspaceFile>

    /** 由 profile 技能收敛而来的上下文（真源收敛：非空时 getCombinedMemory 优先使用并关闭旧 SOUL/IDENTITY/USER/MEMORY 路径，T106/T107） */
    public var profileContext: Option<String> = None

    public init(
        workspacePath: String,
        agentsFile: Option<WorkspaceFile>,
        soulFile: Option<WorkspaceFile>,
        toolsFile: Option<WorkspaceFile>,
        identityFile: Option<WorkspaceFile>,
        userFile: Option<WorkspaceFile>,
        memoryFile: Option<WorkspaceFile>,
        heartbeatFile: Option<WorkspaceFile>,
        dailyMemoryFiles: ArrayList<WorkspaceFile>,
        profileContext!: Option<String> = None
    ) {
        this.workspacePath = workspacePath
        this.agentsFile = agentsFile
        this.soulFile = soulFile
        this.toolsFile = toolsFile
        this.identityFile = identityFile
        this.userFile = userFile
        this.memoryFile = memoryFile
        this.heartbeatFile = heartbeatFile
        this.dailyMemoryFiles = dailyMemoryFiles
        this.profileContext = profileContext
    }
    
    public static func createEmpty(workspacePath: String): AgentWorkspace {
        return AgentWorkspace(workspacePath, None, None, None, None, None, None, None, ArrayList())
    }

    /**
     * 注入由 profile 技能收敛而来的上下文（真源收敛入口，T106/T107）。
     * 高层（magic.skill.parallel 装配器）把 profile 技能渲染结果写入此处，
     * 随后 getCombinedMemory 优先使用它并关闭旧文件路径，避免双份注入。
     */
    public func withProfileContext(profileContext: String): AgentWorkspace {
        this.profileContext = Some(profileContext)
        return this
    }
    
    public func getFile(fileType: WorkspaceFileType): Option<WorkspaceFile> {
        match (fileType) {
            case WorkspaceFileType.Agents =>
                return this.agentsFile
            case WorkspaceFileType.Soul =>
                return this.soulFile
            case WorkspaceFileType.Tools =>
                return this.toolsFile
            case WorkspaceFileType.Identity =>
                return this.identityFile
            case WorkspaceFileType.User =>
                return this.userFile
            case WorkspaceFileType.Memory =>
                return this.memoryFile
            case WorkspaceFileType.Heartbeat =>
                return this.heartbeatFile
            case _ =>
                return None
        }
    }
    
    public func getSortedDailyMemoryFiles(): ArrayList<WorkspaceFile> {
        var sorted = ArrayList<WorkspaceFile>()
        for (file in this.dailyMemoryFiles) {
            sorted.add(file)
        }
        return sorted
    }
    
    public func getCombinedMemory(): String {
        // 真源收敛：若已注入 profile 技能上下文，则以其为准，关闭旧 SOUL/IDENTITY/USER/MEMORY 路径（T107 禁止双份注入）
        if (this.profileContext.isSome()) {
            var combined = StringBuilder()
            combined.append(this.profileContext.getOrThrow())
            combined.append("\n\n")
            // 仅保留非 profile 来源（工具 / 智能体 / 心跳）
            let keep = ArrayList<Option<WorkspaceFile>>()
            keep.add(this.toolsFile)
            keep.add(this.agentsFile)
            keep.add(this.heartbeatFile)
            for (part in keep) {
                if (part.isSome()) {
                    let file = part.getOrThrow()
                    if (file.content.isSome()) {
                        combined.append(file.content.getOrThrow())
                        combined.append("\n\n")
                    }
                }
            }
            return combined.toString()
        }
        // 向后兼容：未迁移环境行为不变（T108）
        var combined = StringBuilder()
        let parts = ArrayList<Option<WorkspaceFile>>()
        parts.add(this.soulFile)
        parts.add(this.identityFile)
        parts.add(this.userFile)
        parts.add(this.memoryFile)
        parts.add(this.heartbeatFile)
        parts.add(this.toolsFile)
        parts.add(this.agentsFile)
        for (part in parts) {
            if (part.isSome()) {
                let file = part.getOrThrow()
                if (file.content.isSome()) {
                    let content = file.content.getOrThrow()
                    combined.append(content)
                    combined.append("\n\n")
                }
            }
        }
        return combined.toString()
    }
}
