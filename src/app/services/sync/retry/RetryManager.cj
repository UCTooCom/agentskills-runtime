package magic.app.services.sync.retry

import std.core.Duration
import std.sync.{Mutex, AtomicInt32}
import magic.app.services.sync.model.{SyncResult, SyncStatus}
import magic.log.LogUtils

public class RetryManager {
    private let maxRetries_: Int32
    private let mutex = Mutex()

    public init(maxRetries: Int32) {
        this.maxRetries_ = maxRetries
    }

    public init() {
        this.maxRetries_ = 3
    }

    public prop maxRetries: Int32 {
        get() { maxRetries_ }
    }

    public func executeWithRetry(
        entityType: String,
        entityId: String,
        operation: () -> SyncResult
    ): SyncResult {
        var attempt: Int32 = 0
        var lastResult: Option<SyncResult> = None
        while (attempt <= maxRetries_) {
            try {
                let result = operation()
                if (result.success) {
                    return result
                }
                lastResult = Some(result)
            } catch (e: Exception) {
                let failResult = SyncResult(false, entityType, entityId, SyncStatus.Error, e.message)
                lastResult = Some(failResult)
            }
            attempt++
            if (attempt <= maxRetries_) {
                let delayMs = calculateRetryDelay(attempt - 1)
                LogUtils.warn("RetryManager: attempt ${attempt}/${maxRetries_} failed for ${entityType}/${entityId}, retrying in ${delayMs}ms")
                try {
                    sleep(Duration.millisecond * Int64(delayMs))
                } catch (_: Exception) {}
            }
        }
        if (let Some(r) <- lastResult) {
            return r
        }
        return SyncResult(false, entityType, entityId, SyncStatus.Error, "All retry attempts exhausted")
    }

    public func calculateRetryDelay(attempt: Int32): Int64 {
        let baseMs: Int64 = 1000
        baseMs * (Int64(1) << Int64(attempt))
    }
}