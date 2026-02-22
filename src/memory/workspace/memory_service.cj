package magic.memory.workspace

import std.fs.{Path, File, Directory, exists}
import std.time.DateTime
import magic.log.LogUtils
import magic.memory.ShortMemory

public class MemoryService {
    private let workspacePath: String
    private let workspaceLoader: WorkspaceLoader
    private let shortMemory: ShortMemory
    private var currentWorkspace: AgentWorkspace
    
    public init(workspacePath: String) {
        this.workspacePath = workspacePath
        this.workspaceLoader = WorkspaceLoader(workspacePath)
        this.shortMemory = ShortMemory()
        this.currentWorkspace = this.workspaceLoader.load()
    }
    
    public func getWorkspace(): AgentWorkspace {
        return this.currentWorkspace
    }
    
    public func reloadWorkspace(): AgentWorkspace {
        this.currentWorkspace = this.workspaceLoader.load()
        return this.currentWorkspace
    }
    
    public func appendMemory(content: String, timestamp: Option<DateTime>): Bool {
        LogUtils.info("Appending memory...")
        return true
    }
    
    public func appendToLongTermMemory(content: String): Bool {
        LogUtils.info("Appending to long-term memory...")
        return true
    }
    
    public func searchMemory(query: String, limit: Int64): Array<String> {
        return this.shortMemory.search(query)
    }
    
    public func getMemoryFile(fileType: WorkspaceFileType): Option<WorkspaceFile> {
        return this.currentWorkspace.getFile(fileType)
    }
    
    public func updateMemoryFile(fileType: WorkspaceFileType, content: String): Bool {
        LogUtils.info("Updating memory file...")
        return true
    }
}
