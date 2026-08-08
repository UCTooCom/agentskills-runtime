/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray, JsonFloat}
import magic.log.LogUtils

public enum SubAgentTaskStatus {
    | Queued | Running | Completed | Failed | Cancelled
}

public class SubAgentTaskProgress {
    public var taskId: String = ""
    public var agentName: String = ""
    public var language: String = ""
    public var status: SubAgentTaskStatus = SubAgentTaskStatus.Queued
    public var progress: Float64 = 0.0
    public var startedAt: Option<DateTime> = None<DateTime>
    public var completedAt: Option<DateTime> = None<DateTime>
    public var result: Option<JsonValue> = None<JsonValue>
    public var errorMessage: Option<String> = None<String>

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("task_id", JsonString(this.taskId))
        map.add("agent_name", JsonString(this.agentName))
        map.add("language", JsonString(this.language))
        map.add("status", JsonString(subAgentTaskStatusToString(this.status)))
        map.add("progress", JsonFloat(this.progress))
        if (let Some(sa) <- this.startedAt) {
            map.add("started_at", JsonString(sa.toString()))
        }
        if (let Some(ca) <- this.completedAt) {
            map.add("completed_at", JsonString(ca.toString()))
        }
        if (let Some(r) <- this.result) {
            map.add("result", r)
        }
        if (let Some(e) <- this.errorMessage) {
            map.add("error_message", JsonString(e))
        }
        JsonObject(map)
    }

    public static func subAgentTaskStatusToString(s: SubAgentTaskStatus): String {
        match (s) {
            case SubAgentTaskStatus.Queued => "queued"
            case SubAgentTaskStatus.Running => "running"
            case SubAgentTaskStatus.Completed => "completed"
            case SubAgentTaskStatus.Failed => "failed"
            case SubAgentTaskStatus.Cancelled => "cancelled"
        }
    }
}

public class SubAgentProgressTracker {
    private var _tasks: HashMap<String, SubAgentTaskProgress>

    public init() {
        _tasks = HashMap<String, SubAgentTaskProgress>()
    }

    public func registerTask(taskId: String, agentName: String, language: String): Unit {
        let progress = SubAgentTaskProgress()
        progress.taskId = taskId
        progress.agentName = agentName
        progress.language = language
        progress.status = SubAgentTaskStatus.Queued
        _tasks.add(taskId, progress)
        LogUtils.info("[SubAgentProgressTracker] Task registered: ${taskId}")
    }

    public func updateProgress(taskId: String, progress: Float64): Unit {
        if (let Some(task) <- _tasks.get(taskId)) {
            task.progress = progress
            if (isSameSubAgentTaskStatus(task.status, SubAgentTaskStatus.Queued)) {
                task.status = SubAgentTaskStatus.Running
                task.startedAt = Some(DateTime.now())
            }
        }
    }

    public func completeTask(taskId: String, result: JsonValue): Unit {
        if (let Some(task) <- _tasks.get(taskId)) {
            task.status = SubAgentTaskStatus.Completed
            task.progress = 1.0
            task.result = Some(result)
            task.completedAt = Some(DateTime.now())
            LogUtils.info("[SubAgentProgressTracker] Task completed: ${taskId}")
        }
    }

    public func failTask(taskId: String, errorMessage: String): Unit {
        if (let Some(task) <- _tasks.get(taskId)) {
            task.status = SubAgentTaskStatus.Failed
            task.errorMessage = Some(errorMessage)
            task.completedAt = Some(DateTime.now())
            LogUtils.error("[SubAgentProgressTracker] Task failed: ${taskId}, error: ${errorMessage}")
        }
    }

    public func cancelTask(taskId: String): Unit {
        if (let Some(task) <- _tasks.get(taskId)) {
            task.status = SubAgentTaskStatus.Cancelled
            task.completedAt = Some(DateTime.now())
            LogUtils.info("[SubAgentProgressTracker] Task cancelled: ${taskId}")
        }
    }

    public func getProgress(taskId: String): Option<SubAgentTaskProgress> {
        _tasks.get(taskId)
    }

    public func getActiveTasks(): ArrayList<SubAgentTaskProgress> {
        let result = ArrayList<SubAgentTaskProgress>()
        for ((_, task) in _tasks) {
            if (isSameSubAgentTaskStatus(task.status, SubAgentTaskStatus.Running) || isSameSubAgentTaskStatus(task.status, SubAgentTaskStatus.Queued)) {
                result.add(task)
            }
        }
        result
    }

    public func aggregateResults(taskIds: ArrayList<String>): Option<JsonValue> {
        var resultsArr = ArrayList<JsonValue>()
        for (taskId in taskIds) {
            if (let Some(task) <- _tasks.get(taskId)) {
                if (let Some(r) <- task.result) {
                    resultsArr.add(r)
                }
            }
        }
        if (resultsArr.size > 0) {
            return Some(JsonArray(resultsArr))
        }
        None<JsonValue>
    }

    public func getOverallProgress(taskIds: ArrayList<String>): Float64 {
        if (taskIds.size == 0) { return 0.0 }
        var totalProgress = 0.0
        var count = 0
        for (taskId in taskIds) {
            if (let Some(task) <- _tasks.get(taskId)) {
                totalProgress = totalProgress + task.progress
                count = count + 1
            }
        }
        if (count == 0) { return 0.0 }
        totalProgress / Float64(count)
    }

    public func getAllTasks(): ArrayList<SubAgentTaskProgress> {
        let result = ArrayList<SubAgentTaskProgress>()
        for ((_, task) in _tasks) {
            result.add(task)
        }
        result
    }

    public static func isSameSubAgentTaskStatus(a: SubAgentTaskStatus, b: SubAgentTaskStatus): Bool {
        match (a) {
            case SubAgentTaskStatus.Queued => match (b) { case SubAgentTaskStatus.Queued => true case _ => false }
            case SubAgentTaskStatus.Running => match (b) { case SubAgentTaskStatus.Running => true case _ => false }
            case SubAgentTaskStatus.Completed => match (b) { case SubAgentTaskStatus.Completed => true case _ => false }
            case SubAgentTaskStatus.Failed => match (b) { case SubAgentTaskStatus.Failed => true case _ => false }
            case SubAgentTaskStatus.Cancelled => match (b) { case SubAgentTaskStatus.Cancelled => true case _ => false }
        }
    }
}