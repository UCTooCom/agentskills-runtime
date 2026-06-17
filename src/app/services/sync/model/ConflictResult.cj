package magic.app.services.sync.model

public class ConflictResult {
    public var winner: SyncWinner
    public var message: String

    public init() {
        winner = SyncWinner.NoChange
        message = ""
    }
}
