package magic.memory.workspace

import std.collection.ArrayList
import std.fs.{FileInfo, Directory, exists, Path, File}
import std.time.DateTime
import stdx.log.LogLevel
import magic.log.LogUtils

public class WorkspaceLoader {
    private let workspacePath: String
    
    public init(workspacePath: String) {
        this.workspacePath = workspacePath
    }
    
    public func load(): AgentWorkspace {
        LogUtils.info("Loading workspace from: ${this.workspacePath}")
        
        var workspace = AgentWorkspace.createEmpty(this.workspacePath)
        
        if (!exists(Path(this.workspacePath))) {
            LogUtils.info("Workspace directory does not exist: ${this.workspacePath}")
            return workspace
        }
        
        let agentsFile: Option<WorkspaceFile> = None
        let soulFile: Option<WorkspaceFile> = None
        let toolsFile: Option<WorkspaceFile> = None
        let identityFile: Option<WorkspaceFile> = None
        let userFile: Option<WorkspaceFile> = None
        let memoryFile: Option<WorkspaceFile> = None
        let heartbeatFile: Option<WorkspaceFile> = None
        
        let dailyMemoryFiles = ArrayList<WorkspaceFile>()
        
        return AgentWorkspace(
            this.workspacePath,
            agentsFile,
            soulFile,
            toolsFile,
            identityFile,
            userFile,
            memoryFile,
            heartbeatFile,
            dailyMemoryFiles
        )
    }
    
    public func reload(): AgentWorkspace {
        return this.load()
    }
}
