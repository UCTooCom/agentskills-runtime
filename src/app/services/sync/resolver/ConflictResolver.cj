package magic.app.services.sync.resolver

import std.time.DateTime
import magic.app.services.sync.model.{ConflictResult, SyncWinner}

public class ConflictResolver {
    public static func detectByTimestamp(
        fileModifiedAt: DateTime,
        dbUpdatedAt: DateTime,
        lastSyncAt: Option<DateTime>
    ): Option<ConflictResult> {
        match (lastSyncAt) {
            case Some(syncAt) =>
                if (fileModifiedAt > syncAt && dbUpdatedAt > syncAt) {
                    Some(resolveByTimestamp(fileModifiedAt, dbUpdatedAt))
                } else {
                    None
                }
            case None =>
                None
        }
    }

    private static func resolveByTimestamp(
        fileModifiedAt: DateTime,
        dbUpdatedAt: DateTime
    ): ConflictResult {
        let result = ConflictResult()
        if (fileModifiedAt > dbUpdatedAt) {
            result.winner = SyncWinner.FileSystem
            result.message = "文件侧较新，以文件覆盖数据库"
        } else if (dbUpdatedAt > fileModifiedAt) {
            result.winner = SyncWinner.Database
            result.message = "数据库侧较新，以数据库覆盖文件"
        } else {
            result.winner = SyncWinner.NoChange
            result.message = "两侧时间戳相同，跳过同步"
        }
        result
    }
}
