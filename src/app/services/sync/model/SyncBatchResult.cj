package magic.app.services.sync.model

import std.collection.ArrayList

public class SyncBatchResult {
    public var totalCount: Int32
    public var successCount: Int32
    public var failedCount: Int32
    public var details: ArrayList<SyncResult>

    public init() {
        totalCount = 0
        successCount = 0
        failedCount = 0
        details = ArrayList<SyncResult>()
    }
}
