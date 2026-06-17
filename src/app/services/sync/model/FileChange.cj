package magic.app.services.sync.model

import std.time.DateTime

public class FileChange {
    public var path: String
    public var sourcePath: String
    public var changeType: ChangeType
    public var lastModified: DateTime
    public var entityType: String

    public init() {
        path = ""
        sourcePath = ""
        changeType = ChangeType.Modified
        lastModified = DateTime.now()
        entityType = ""
    }
}