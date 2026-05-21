package magic.app.services.crontab.model

import std.time.DateTime

public class SchedulerStatus {
    public var isRunning: Bool = false
    public var totalTasks: Int32 = 0
    public var activeTasks: Int32 = 0
    public var runningTasks: Int32 = 0
    public var lastTickTime: DateTime = DateTime.now()

    public init() {}

    public init(isRunning!: Bool, totalTasks!: Int32, activeTasks!: Int32, runningTasks!: Int32, lastTickTime!: DateTime) {
        this.isRunning = isRunning
        this.totalTasks = totalTasks
        this.activeTasks = activeTasks
        this.runningTasks = runningTasks
        this.lastTickTime = lastTickTime
    }
}
