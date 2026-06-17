package magic.app.services.sync.model

import std.time.DateTime

public class SyncEntityStatus {
    public var entityType: String
    public var entityId: String
    public var sourcePath: String
    public var syncStatus: String
    public var lastSyncAt: Option<DateTime>
    public var errorMessage: Option<String>

    public init() {
        entityType = ""
        entityId = ""
        sourcePath = ""
        syncStatus = "pending"
        lastSyncAt = None
        errorMessage = None
    }
}