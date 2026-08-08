/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray, JsonNull}
import magic.log.LogUtils

public enum KanbanTaskState {
    | Todo | InProgress | Review | Done | Blocked
}

public class KanbanTask {
    public var id: String = ""
    public var title: String = ""
    public var description: String = ""
    public var state: KanbanTaskState = KanbanTaskState.Todo
    public var assignee: String = ""
    public var priority: Int64 = 0
    public var parentTaskId: Option<String> = None<String>
    public var subTaskIds: ArrayList<String> = ArrayList<String>()
    public var dependencies: ArrayList<String> = ArrayList<String>()
    public var result: Option<JsonValue> = None<JsonValue>
    public var createdAt: DateTime = DateTime.now()
    public var updatedAt: DateTime = DateTime.now()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("id", JsonString(this.id))
        map.add("title", JsonString(this.title))
        map.add("description", JsonString(this.description))
        map.add("state", JsonString(kanbanTaskStateToString(this.state)))
        map.add("assignee", JsonString(this.assignee))
        map.add("priority", JsonInt(this.priority))
        if (let Some(pid) <- this.parentTaskId) {
            map.add("parent_task_id", JsonString(pid))
        }
        var subArr = ArrayList<JsonValue>()
        for (s in this.subTaskIds) { subArr.add(JsonString(s)) }
        map.add("sub_task_ids", JsonArray(subArr))
        var depArr = ArrayList<JsonValue>()
        for (d in this.dependencies) { depArr.add(JsonString(d)) }
        map.add("dependencies", JsonArray(depArr))
        if (let Some(r) <- this.result) { map.add("result", r) }
        map.add("created_at", JsonString(this.createdAt.toString()))
        map.add("updated_at", JsonString(this.updatedAt.toString()))
        JsonObject(map)
    }

    public static func kanbanTaskStateToString(s: KanbanTaskState): String {
        match (s) {
            case KanbanTaskState.Todo => "todo"
            case KanbanTaskState.InProgress => "in_progress"
            case KanbanTaskState.Review => "review"
            case KanbanTaskState.Done => "done"
            case KanbanTaskState.Blocked => "blocked"
        }
    }

    public static func parseKanbanTaskState(s: String): KanbanTaskState {
        match (s.toAsciiLower()) {
            case "todo" => KanbanTaskState.Todo
            case "in_progress" => KanbanTaskState.InProgress
            case "review" => KanbanTaskState.Review
            case "done" => KanbanTaskState.Done
            case "blocked" => KanbanTaskState.Blocked
            case _ => KanbanTaskState.Todo
        }
    }
}

public class KanbanBoard {
    private var _tasks: HashMap<String, KanbanTask>
    private let _persistTask: (KanbanTask) -> Bool

    public init(persistTask!: (KanbanTask) -> Bool) {
        _tasks = HashMap<String, KanbanTask>()
        _persistTask = persistTask
    }

    public func addTask(task: KanbanTask): Unit {
        _tasks.add(task.id, task)
        _persistTask(task)
        LogUtils.info("[KanbanBoard] Task added: ${task.id} - ${task.title}")
    }

    public func getTask(taskId: String): Option<KanbanTask> {
        _tasks.get(taskId)
    }

    public func updateTaskState(taskId: String, newState: KanbanTaskState): Bool {
        if (let Some(task) <- _tasks.get(taskId)) {
            task.state = newState
            task.updatedAt = DateTime.now()
            _persistTask(task)
            LogUtils.info("[KanbanBoard] Task state updated: ${taskId} → ${KanbanTask.kanbanTaskStateToString(newState)}")
            return true
        }
        false
    }

    public func assignTask(taskId: String, assignee: String): Bool {
        if (let Some(task) <- _tasks.get(taskId)) {
            task.assignee = assignee
            task.updatedAt = DateTime.now()
            _persistTask(task)
            return true
        }
        false
    }

    public func setTaskResult(taskId: String, result: JsonValue): Bool {
        if (let Some(task) <- _tasks.get(taskId)) {
            task.result = Some(result)
            task.updatedAt = DateTime.now()
            _persistTask(task)
            return true
        }
        false
    }

    public func getTasksByState(state: KanbanTaskState): ArrayList<KanbanTask> {
        let result = ArrayList<KanbanTask>()
        for ((_, task) in _tasks) {
            if (KanbanDispatcher.isSameKanbanTaskState(task.state, state)) { result.add(task) }
        }
        result
    }

    public func getReadyTasks(): ArrayList<KanbanTask> {
        let result = ArrayList<KanbanTask>()
        for ((_, task) in _tasks) {
            if (!KanbanDispatcher.isSameKanbanTaskState(task.state, KanbanTaskState.Todo)) { continue }
            var allDepsDone = true
            for (depId in task.dependencies) {
                if (let Some(dep) <- _tasks.get(depId)) {
                    if (!KanbanDispatcher.isSameKanbanTaskState(dep.state, KanbanTaskState.Done)) { allDepsDone = false; break }
                } else { allDepsDone = false; break }
            }
            if (allDepsDone) { result.add(task) }
        }
        result
    }

    public func getAllTasks(): ArrayList<KanbanTask> {
        let result = ArrayList<KanbanTask>()
        for ((_, task) in _tasks) { result.add(task) }
        result
    }
}

public class KanbanDispatcher {
    private let _board: KanbanBoard
    private let _executeTask: (KanbanTask) -> Option<JsonValue>
    private var _counter: Int64 = 0

    public init(board!: KanbanBoard, executeTask!: (KanbanTask) -> Option<JsonValue>) {
        _board = board
        _executeTask = executeTask
    }

    public func dispatchNext(): Option<String> {
        let readyTasks = _board.getReadyTasks()
        if (readyTasks.size == 0) {
            LogUtils.info("[KanbanDispatcher] No ready tasks to dispatch")
            return None<String>
        }

        var selectedTask = readyTasks[0]
        for (task in readyTasks) {
            if (task.priority > selectedTask.priority) { selectedTask = task }
        }

        _board.updateTaskState(selectedTask.id, KanbanTaskState.InProgress)
        LogUtils.info("[KanbanDispatcher] Dispatching task: ${selectedTask.id} - ${selectedTask.title}")

        let result = _executeTask(selectedTask)

        if (let Some(r) <- result) {
            _board.setTaskResult(selectedTask.id, r)
            _board.updateTaskState(selectedTask.id, KanbanTaskState.Done)
            LogUtils.info("[KanbanDispatcher] Task completed: ${selectedTask.id}")
            return Some(selectedTask.id)
        } else {
            _board.updateTaskState(selectedTask.id, KanbanTaskState.Blocked)
            LogUtils.error("[KanbanDispatcher] Task failed: ${selectedTask.id}")
            return Some(selectedTask.id)
        }
    }

    public func dispatchAll(): ArrayList<String> {
        let dispatched = ArrayList<String>()
        var hasMore = true
        while (hasMore) {
            let result = dispatchNext()
            if (let Some(taskId) <- result) {
                dispatched.add(taskId)
            } else {
                hasMore = false
            }
            _counter = _counter + 1
            if (_counter > 1000) { hasMore = false }
        }
        dispatched
    }

    public func decomposeTask(parentTask: KanbanTask, subTaskDefs: ArrayList<KanbanTask>): ArrayList<String> {
        let subTaskIds = ArrayList<String>()
        for (def in subTaskDefs) {
            _counter = _counter + 1
            let subId = "kanban_${_counter.toString()}"
            def.id = subId
            def.parentTaskId = Some(parentTask.id)
            _board.addTask(def)
            subTaskIds.add(subId)
        }

        if (let Some(parent) <- _board.getTask(parentTask.id)) {
            for (sid in subTaskIds) { parent.subTaskIds.add(sid) }
        }

        LogUtils.info("[KanbanDispatcher] Task decomposed: ${parentTask.id} → ${subTaskIds.size.toString()} subtasks")
        subTaskIds
    }

    public static func isSameKanbanTaskState(a: KanbanTaskState, b: KanbanTaskState): Bool {
        match (a) {
            case KanbanTaskState.Todo => match (b) { case KanbanTaskState.Todo => true case _ => false }
            case KanbanTaskState.InProgress => match (b) { case KanbanTaskState.InProgress => true case _ => false }
            case KanbanTaskState.Review => match (b) { case KanbanTaskState.Review => true case _ => false }
            case KanbanTaskState.Done => match (b) { case KanbanTaskState.Done => true case _ => false }
            case KanbanTaskState.Blocked => match (b) { case KanbanTaskState.Blocked => true case _ => false }
        }
    }
}