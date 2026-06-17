package magic.app.services.sync.model

import std.time.DateTime

public class SyncStatusSummary {
    public var totalEntities: Int32
    public var syncedCount: Int32
    public var pendingCount: Int32
    public var failedCount: Int32
    public var dependencyMissingCount: Int32
    public var lastSyncAt: Option<DateTime>

    public init() {
        totalEntities = 0
        syncedCount = 0
        pendingCount = 0
        failedCount = 0
        dependencyMissingCount = 0
        lastSyncAt = None
    }
}