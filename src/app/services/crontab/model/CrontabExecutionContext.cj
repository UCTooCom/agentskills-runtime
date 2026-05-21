package magic.app.services.crontab.model

import std.time.DateTime

public class CrontabExecutionContext {
    public var crontabId: String = ""
    public var taskName: String = ""
    public var taskUri: String = ""
    public var parameters: String = "{}"
    public var timeout: Int32 = 0
    public var triggerType: TriggerType = TriggerType.Cron
    public var retryAttempt: Int32 = 0
    public var maxRetries: Int32 = 0
    public var startTime: DateTime = DateTime.now()

    public init() {}

    public init(crontabId!: String, taskName!: String, taskUri!: String, parameters!: String, timeout!: Int32, triggerType!: TriggerType, retryAttempt!: Int32, maxRetries!: Int32) {
        this.crontabId = crontabId
        this.taskName = taskName
        this.taskUri = taskUri
        this.parameters = parameters
        this.timeout = timeout
        this.triggerType = triggerType
        this.retryAttempt = retryAttempt
        this.maxRetries = maxRetries
        this.startTime = DateTime.now()
    }
}
