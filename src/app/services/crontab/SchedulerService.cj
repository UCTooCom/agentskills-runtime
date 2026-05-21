package magic.app.services.crontab

import std.time.DateTime
import std.collection.ArrayList
import magic.log.LogUtils
import magic.app.services.crontab.model.{SchedulerStatus, TriggerType}

public class SchedulerService {
    public func triggerTask(crontabId: String): Bool {
        match (SchedulerEngine.instance) {
            case Some(engine) =>
                engine.triggerTask(crontabId, TriggerType.Manual)
                return true
            case None =>
                LogUtils.error("SchedulerService", "调度引擎未初始化")
                return false
        }
    }

    public func pauseTask(crontabId: String): Bool {
        match (SchedulerEngine.instance) {
            case Some(engine) =>
                engine.removeTask(crontabId)
                return true
            case None =>
                return false
        }
    }

    public func resumeTask(crontabId: String): Bool {
        match (SchedulerEngine.instance) {
            case Some(engine) =>
                engine.reloadTask(crontabId)
                return true
            case None =>
                return false
        }
    }

    public func reloadAllTasks(): Unit {
        match (SchedulerEngine.instance) {
            case Some(engine) =>
                engine.loadAllActiveTasks()
            case None =>
                LogUtils.error("SchedulerService", "调度引擎未初始化")
        }
    }

    public func getSchedulerStatus(): SchedulerStatus {
        match (SchedulerEngine.instance) {
            case Some(engine) =>
                engine.getStatus()
            case None =>
                SchedulerStatus(isRunning: false, totalTasks: 0, activeTasks: 0, runningTasks: 0, lastTickTime: DateTime.now())
        }
    }

    public func getRunningTasks(): ArrayList<String> {
        match (SchedulerEngine.instance) {
            case Some(engine) =>
                engine.getRunningTasks()
            case None =>
                ArrayList<String>()
        }
    }

    public func isEngineRunning(): Bool {
        match (SchedulerEngine.instance) {
            case Some(engine) => engine.getStatus().isRunning
            case None => false
        }
    }
}
