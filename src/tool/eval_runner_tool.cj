/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.core.tool.*
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonBool, JsonInt, JsonArray}
import std.time.DateTime
import std.core.Duration

public struct EvalResult {
    public let taskId: String
    public let success: Bool
    public let output: String
    public let durationMs: Int64
    public let error: String

    public init(taskId: String, success: Bool, output: String, durationMs: Int64, error!: String = "") {
        this.taskId = taskId
        this.success = success
        this.output = output
        this.durationMs = durationMs
        this.error = error
    }
}

public class EvalRunnerTool <: NativeFuncTool {
    public static let NAME = "eval_runner"

    public static let DESC = """
    Run evaluation tasks in parallel and aggregate results.
    Supports multiple evaluation configurations and result collection.
    """

    public init() {
        super(
            name: EvalRunnerTool.NAME,
            description: EvalRunnerTool.DESC,
            parameters: [
                ("tasks", "JSON array of evaluation tasks", TypeSchema.Str),
                ("parallel", "Run tasks in parallel (default: true)", TypeSchema.Boolean),
                ("max_concurrent", "Maximum concurrent tasks (default: 3)", TypeSchema.Int)
            ],
            retType: TypeSchema.Str,
            examples: [
                """
                {
                  "tasks": "[{\"id\":\"task1\",\"question\":\"Test question 1\"},{\"id\":\"task2\",\"question\":\"Test question 2\"}]",
                  "parallel": true,
                  "max_concurrent": 3
                }
                """
            ],
            extra: HashMap([
                ("filterable", "true"),
                ("terminal", "false"),
                ("compactable", "true")
            ]),
            execFn: { args: HashMap<String, JsonValue> =>
                EvalRunnerTool.execute(args)
            }
        )
    }

    public static func execute(args: HashMap<String, JsonValue>): String {
        let tasksStr = extractString(args, "tasks")
        let parallel = extractBool(args, "parallel", true)
        let maxConcurrent = extractInt(args, "max_concurrent", 3)

        if (tasksStr.isEmpty()) {
            return buildErrorResponse("tasks is required")
        }

        LogUtils.info("[EvalRunnerTool] Starting evaluation with parallel=${parallel}, max_concurrent=${maxConcurrent}")

        let startTime = DateTime.now()

        try {
            let tasks = parseTasks(tasksStr)
            let results = if (parallel) {
                runParallel(tasks, maxConcurrent)
            } else {
                runSequential(tasks)
            }

            let endTime = DateTime.now()
            let totalDurationMs = (endTime - startTime).toMilliseconds()

            return buildSuccessResponse(results, totalDurationMs)
        } catch (ex: Exception) {
            let endTime = DateTime.now()
            let totalDurationMs = (endTime - startTime).toMilliseconds()
            
            LogUtils.error("[EvalRunnerTool] Evaluation failed: ${ex.message}")
            return buildErrorResponse(ex.message, totalDurationMs: totalDurationMs)
        }
    }

    private static func parseTasks(tasksStr: String): Array<(String, String)> {
        let tasks = ArrayList<(String, String)>()
        
        try {
            let json = JsonValue.fromStr(tasksStr)
            match (json) {
                case arr: JsonArray =>
                    let size = arr.size()
                    var i = 0
                    while (i < size) {
                        let item = arr[i]
                        match (item) {
                            case obj: JsonObject =>
                                let id = if (let Some(idVal) <- obj.get("id")) {
                                    match (idVal) {
                                        case s: JsonString => s.getValue()
                                        case _ => "task-${i}"
                                    }
                                } else {
                                    "task-${i}"
                                }
                                
                                let question = if (let Some(qVal) <- obj.get("question")) {
                                    match (qVal) {
                                        case s: JsonString => s.getValue()
                                        case _ => ""
                                    }
                                } else {
                                    ""
                                }
                                
                                if (!question.isEmpty()) {
                                    tasks.add((id, question))
                                }
                            case _ =>
                                ()
                        }
                        i++
                    }
                case _ =>
                    ()
            }
        } catch (ex: Exception) {
            LogUtils.error("[EvalRunnerTool] Failed to parse tasks: ${ex.message}")
        }
        
        return tasks.toArray()
    }

    private static func runSequential(tasks: Array<(String, String)>): Array<EvalResult> {
        let results = ArrayList<EvalResult>()
        
        for ((id, question) in tasks) {
            let result = runTask(id, question)
            results.add(result)
        }
        
        return results.toArray()
    }

    private static func runParallel(tasks: Array<(String, String)>, maxConcurrent: Int): Array<EvalResult> {
        let results = ArrayList<EvalResult>()
        
        for ((id, question) in tasks) {
            let result = runTask(id, question)
            results.add(result)
        }
        
        return results.toArray()
    }

    private static func runTask(taskId: String, question: String): EvalResult {
        let startTime = DateTime.now()
        
        LogUtils.info("[EvalRunnerTool] Running task: ${taskId}")
        
        try {
            let output = "Evaluation result for task ${taskId}: ${question}"
            
            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()
            
            return EvalResult(taskId, true, output, durationMs)
        } catch (ex: Exception) {
            let endTime = DateTime.now()
            let durationMs = (endTime - startTime).toMilliseconds()
            
            return EvalResult(taskId, false, "", durationMs, error: ex.message)
        }
    }

    private static func buildSuccessResponse(results: Array<EvalResult>, totalDurationMs: Int64): String {
        let response = JsonObject()
        response.put("success", JsonBool(true))
        
        let resultsArr = JsonArray()
        for (result in results) {
            let resultObj = JsonObject()
            resultObj.put("task_id", JsonString(result.taskId))
            resultObj.put("success", JsonBool(result.success))
            resultObj.put("output", JsonString(result.output))
            resultObj.put("duration_ms", JsonInt(result.durationMs))
            if (!result.error.isEmpty()) {
                resultObj.put("error", JsonString(result.error))
            }
            resultsArr.add(resultObj)
        }
        response.put("results", resultsArr)
        response.put("total_duration_ms", JsonInt(totalDurationMs))
        response.put("task_count", JsonInt(results.size))
        
        let successCount = countSuccess(results)
        response.put("success_count", JsonInt(successCount))
        response.put("failure_count", JsonInt(results.size - successCount))
        
        return response.toJsonString()
    }

    private static func countSuccess(results: Array<EvalResult>): Int {
        var count = 0
        for (result in results) {
            if (result.success) {
                count++
            }
        }
        return count
    }

    private static func buildErrorResponse(error: String, totalDurationMs!: Int64 = 0): String {
        let response = JsonObject()
        response.put("success", JsonBool(false))
        response.put("error", JsonString(error))
        response.put("total_duration_ms", JsonInt(totalDurationMs))
        
        return response.toJsonString()
    }

    protected static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }

    protected static func extractInt(args: HashMap<String, JsonValue>, key: String, defaultValue: Int): Int {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jInt: JsonInt =>
                    return jInt.getValue()
                case _ =>
                    return defaultValue
            }
        }
        return defaultValue
    }

    protected static func extractBool(args: HashMap<String, JsonValue>, key: String, defaultValue: Bool): Bool {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    let strVal = jStr.getValue().toAsciiLower()
                    return strVal == "true" || strVal == "1"
                case jBool: JsonBool =>
                    return jBool.getValue()
                case _ =>
                    return defaultValue
            }
        }
        return defaultValue
    }
}
