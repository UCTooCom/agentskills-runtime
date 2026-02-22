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
    
    public init(
        workspacePath: String,
        agentsFile: Option<WorkspaceFile>,
        soulFile: Option<WorkspaceFile>,
        toolsFile: Option<WorkspaceFile>,
        identityFile: Option<WorkspaceFile>,
        userFile: Option<WorkspaceFile>,
        memoryFile: Option<WorkspaceFile>,
        heartbeatFile: Option<WorkspaceFile>,
        dailyMemoryFiles: ArrayList<WorkspaceFile>
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
    }
    
    public static func createEmpty(workspacePath: String): AgentWorkspace {
        return AgentWorkspace(workspacePath, None, None, None, None, None, None, None, ArrayList())
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
