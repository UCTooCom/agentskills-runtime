package magic.app.services.sync.model

import std.time.DateTime

public class SyncResult {
    public var success: Bool
    public var entityType: String
    public var entityId: String
    public var status: SyncStatus
    public var message: String
    public var errorDetail: Option<String>
    public var durationMs: Int64
    public var timestamp: DateTime

    public init() {
        success = false
        entityType = ""
        entityId = ""
        status = SyncStatus.Pending
        message = ""
        errorDetail = None
        durationMs = 0
        timestamp = DateTime.now()
    }

    public init(success: Bool, entityType: String, entityId: String, status: SyncStatus, message: String) {
        this.success = success
        this.entityType = entityType
        this.entityId = entityId
        this.status = status
        this.message = message
        this.errorDetail = None
        this.durationMs = 0
        this.timestamp = DateTime.now()
    }
}