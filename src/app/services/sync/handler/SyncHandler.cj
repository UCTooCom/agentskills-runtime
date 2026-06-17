package magic.app.services.sync.handler

import magic.app.services.sync.model.{SyncResult, FileChange}
import magic.app.services.sync.context.SyncContext

public interface SyncHandler {
    prop entityType: String
    prop basePath: String
    prop fileExtension: String
    prop dependencies: Array<String>

    func syncFromFileSystem(sourcePath: String, context: SyncContext): SyncResult

    func syncToFileSystem(entityId: String, context: SyncContext): SyncResult

    func detectChanges(): Array<FileChange>

    func buildFilePath(sourcePath: String): String
}
