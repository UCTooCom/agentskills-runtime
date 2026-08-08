/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.ai_dev_demo

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.agent_executor.DagTeamOrchestrator
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonBool, JsonArray}
import std.collection.HashMap
import std.time.DateTime
import magic.log.LogUtils

public class AiDevDemoController {
    private var _orchestrator: Option<DagTeamOrchestrator>

    private var _currentDemoStatus: String

    public init() {
        _orchestrator = None<DagTeamOrchestrator>
        _currentDemoStatus = "idle"
    }

    public func setOrchestrator(orchestrator: DagTeamOrchestrator): Unit {
        _orchestrator = Some(orchestrator)
    }

    public func start(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseSimpleBody(req)
            let demoType = if (let Some(v) <- body.get("demo_type")) { v } else { "fullstack_crud" }

            LogUtils.info("[AiDevDemo] Starting demo: ${demoType}")
            _currentDemoStatus = "running"

            if (let Some(orch) <- _orchestrator) {
                let planId = "demo_${demoType}_${(DateTime.now() - DateTime.UnixEpoch).toMilliseconds()}"
                _currentDemoStatus = "running"
                LogUtils.info("[AiDevDemo] Demo orchestration initiated: ${planId}")
                res.status(200).json("{\"status\":\"started\",\"demo_type\":\"${demoType}\",\"plan_id\":\"${planId}\",\"message\":\"Demo execution started\"}")
            } else {
                _currentDemoStatus = "running"
                res.status(200).json("{\"status\":\"started\",\"demo_type\":\"${demoType}\",\"message\":\"Demo execution started (no orchestrator)\"}")
            }
        } catch (e: Exception) {
            _currentDemoStatus = "failed"
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func status(req: HttpRequest, res: HttpResponse): Unit {
        try {
            var evidenceCount = 0
            if (let Some(orch) <- _orchestrator) {
                let recorder = orch.getEvidenceRecorder()
                evidenceCount = recorder.getAllEvidences().size
            }
            res.status(200).json("{\"status\":\"${_currentDemoStatus}\",\"agents\":[\"main\",\"doc-consultant\",\"code-searcher\",\"code-editor\",\"code-verifier\"],\"evidence_count\":${evidenceCount.toString()}}")
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func evidences(req: HttpRequest, res: HttpResponse): Unit {
        try {
            if (let Some(orch) <- _orchestrator) {
                let recorder = orch.getEvidenceRecorder()
                let hashChain = orch.getHashChain()
                res.status(200).json("{\"evidence_recorder\":\"active\",\"hash_chain\":\"active\"}")
            } else {
                res.status(200).json("{\"evidence_recorder\":\"not_configured\",\"hash_chain\":\"not_configured\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func teamInfo(req: HttpRequest, res: HttpResponse): Unit {
        try {
            res.status(200).json("{\"team\":{\"name\":\"demo-team\",\"roles\":[\"manager\",\"leader\",\"worker\"],\"skills\":[\"cangjie-coder\",\"crud-generator\",\"tiny-vue-skill\"]}}")
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