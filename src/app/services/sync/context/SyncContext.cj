package magic.app.services.sync.context

import magic.app.services.sync.model.{SyncDirection, TriggerSource}

public class SyncContext {
    public let triggerSource: TriggerSource
    public let direction: SyncDirection
    public let entityType: String
    public let entityId: String

    public init(triggerSource: TriggerSource, direction: SyncDirection, entityType: String, entityId: String) {
        this.triggerSource = triggerSource
        this.direction = direction
        this.entityType = entityType
        this.entityId = entityId
    }

    public static func enter(context: SyncContext): Unit {
        threadLocal.set(context)
    }

    public static func exit(): Unit {
        threadLocal.remove()
    }

    public static func isPresent(): Bool {
        threadLocal.get().isSome()
    }

    public static func current(): Option<SyncContext> {
        threadLocal.get()
    }

    private static let threadLocal: ThreadLocal<SyncContext> = ThreadLocal<SyncContext>()
}

extend<T> ThreadLocal<T> {
    public func remove(): Unit {
        set(None<T>)
    }
}
