/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.language_orchestration

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.skill.{LanguageOrchestrator, LanguageMappingConfig, LanguageContextProvider, LanguageSkillMapping, OrchestrationRequest, OrchestrationResult, CrossLanguageOrchestrator, CrossLanguageRequest, CrossLanguageResult, CrossLanguageStep, SubAgentProgressTracker, SubAgentTaskProgress}
import std.collection.{HashMap, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray}
import magic.log.LogUtils

public class LanguageOrchestrationController {
    private var _languageOrchestrator: Option<LanguageOrchestrator>
    private var _crossLanguageOrchestrator: Option<CrossLanguageOrchestrator>
    private var _progressTracker: Option<SubAgentProgressTracker>

    public init() {
        _languageOrchestrator = None<LanguageOrchestrator>
        _crossLanguageOrchestrator = None<CrossLanguageOrchestrator>
        _progressTracker = None<SubAgentProgressTracker>
    }

    public func setLanguageOrchestrator(orchestrator: LanguageOrchestrator): Unit {
        _languageOrchestrator = Some(orchestrator)
    }

    public func setCrossLanguageOrchestrator(orchestrator: CrossLanguageOrchestrator): Unit {
        _crossLanguageOrchestrator = Some(orchestrator)
    }

    public func setProgressTracker(tracker: SubAgentProgressTracker): Unit {
        _progressTracker = Some(tracker)
    }

    public func listLanguages(req: HttpRequest, res: HttpResponse): Unit {
        try {
            if (let Some(orch) <- _languageOrchestrator) {
                let languages = orch.listSupportedLanguages()
                var langsJson = ""
                for (l in languages) {
                    if (langsJson.size > 0) { langsJson = langsJson + "," }
                    langsJson = langsJson + "\"${l}\""
                }
                res.status(200).json("{\"languages\":[${langsJson}]}")
            } else {
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"LanguageOrchestrator not configured\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getMapping(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let language = req.pathParam("language")
            if (let Some(lang) <- language) {
                if (let Some(orch) <- _languageOrchestrator) {
                    let mappingOpt = orch.getMapping(lang)
                    if (let Some(mapping) <- mappingOpt) {
                        res.status(200).json(mapping.toJsonValue().toString())
                    } else {
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"No mapping found for language: ${lang}\"}")
                    }
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"LanguageOrchestrator not configured\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"Missing language parameter\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func orchestrate(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseSimpleBody(req)
            let language = if (let Some(v) <- body.get("language")) { v } else { "cangjie" }
            let task = if (let Some(v) <- body.get("task")) { v } else { "" }
            let modelOverride = body.get("model_override")
            let backgroundStr = if (let Some(v) <- body.get("background")) { v } else { "false" }

            if (task.size == 0) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"task is required\"}")
                return
            }

            if (let Some(orch) <- _languageOrchestrator) {
                let request = OrchestrationRequest()
                request.language = language
                request.task = task
                request.modelOverride = modelOverride
                request.background = backgroundStr == "true"

                let result = orch.orchestrate(request)
                res.status(200).json(result.toJsonValue().toString())
            } else {
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"LanguageOrchestrator not configured\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func crossLanguageOrchestrate(req: HttpRequest, res: HttpResponse): Unit {
        try {
            if (let Some(crossOrch) <- _crossLanguageOrchestrator) {
                let body = parseSimpleBody(req)
                let request = CrossLanguageRequest()
                request.task = if (let Some(v) <- body.get("task")) { v } else { "" }
                request.background = (if (let Some(v) <- body.get("background")) { v } else { "false" }) == "true"

                if (request.task.size == 0) {
                    res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"task is required\"}")
                    return
                }

                let result = crossOrch.orchestrate(request)
                res.status(200).json(result.toJsonValue().toString())
            } else {
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"CrossLanguageOrchestrator not configured\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getTaskProgress(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let taskId = req.pathParam("task_id")
            if (let Some(tid) <- taskId) {
                if (let Some(tracker) <- _progressTracker) {
                    let progressOpt = tracker.getProgress(tid)
                    if (let Some(progress) <- progressOpt) {
                        res.status(200).json(progress.toJsonValue().toString())
                    } else {
                        res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"Task not found: ${tid}\"}")
                    }
                } else {
                    res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"ProgressTracker not configured\"}")
                }
            } else {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"Missing task_id parameter\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getActiveTasks(req: HttpRequest, res: HttpResponse): Unit {
        try {
            if (let Some(tracker) <- _progressTracker) {
                let tasks = tracker.getActiveTasks()
                var tasksJson = ""
                for (t in tasks) {
                    if (tasksJson.size > 0) { tasksJson = tasksJson + "," }
                    tasksJson = tasksJson + t.toJsonValue().toString()
                }
                res.status(200).json("{\"tasks\":[${tasksJson}]}")
            } else {
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"ProgressTracker not configured\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    private func parseSimpleBody(req: HttpRequest): HashMap<String, String> {
        let result = HashMap<String, String>()
        try {
            let bodyStr = req.body
            if (bodyStr.size > 0) {
                let json = JsonValue.fromStr(bodyStr)
                if (json is JsonObject) {
                    for ((k, v) in json.asObject().getFields()) {
                        if (v is JsonString) { result.add(k, v.asString().getValue()) }
                        else { result.add(k, v.toString()) }
                    }
                }
            }
        } catch (_: Exception) {}
        result
    }
}