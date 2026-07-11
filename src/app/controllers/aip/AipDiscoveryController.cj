/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.aip

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.aip.AipDiscoveryService
import magic.app.services.aip.model.LocalDiscoveryRequest
import magic.log.LogUtils
import stdx.encoding.json.{JsonValue, JsonObject}

public class AipDiscoveryController {
    private var discoveryService: AipDiscoveryService

    public init() {
        this.discoveryService = AipDiscoveryService()
    }

    public func discoverLocal(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            let obj = jsonValue.asObject()

            let request = LocalDiscoveryRequest()
            let nameVal = obj.get("name")
            if (nameVal.isSome()) {
                let s = nameVal.getOrThrow() as String
                if (let Some(str) <- s) { request.name = Some<String>(str) }
            }
            let skillKwVal = obj.get("skill_keyword")
            if (skillKwVal.isSome()) {
                let s = skillKwVal.getOrThrow() as String
                if (let Some(str) <- s) { request.skillKeyword = Some<String>(str) }
            }
            let descKwVal = obj.get("description_keyword")
            if (descKwVal.isSome()) {
                let s = descKwVal.getOrThrow() as String
                if (let Some(str) <- s) { request.descriptionKeyword = Some<String>(str) }
            }
            let pageVal = obj.get("page")
            if (pageVal.isSome()) {
                let n = pageVal.getOrThrow() as Int64
                if (let Some(v) <- n) { request.page = v }
            }
            let limitVal = obj.get("limit")
            if (limitVal.isSome()) {
                let n = limitVal.getOrThrow() as Int64
                if (let Some(v) <- n) { request.limit = v }
            }

            let result = discoveryService.discoverLocal(request)
            if (result.success) {
                if (result.data.isSome()) {
                    let agents = result.data.getOrThrow()
                    var arr = "["
                    var first = true
                    for (agent in agents) {
                        if (!first) { arr = arr + "," }
                        arr = arr + agent.toJson()
                        first = false
                    }
                    arr = arr + "]"
                    res.status(200).json(arr)
                } else {
                    res.status(200).json("[]")
                }
            } else {
                let reason = result.reason ?? "本地智能体发现失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryController", "discoverLocal failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func discoverInterconnection(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let body = req.body
            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                res.status(400).json("{\"errno\":\"40001\",\"errmsg\":\"请求格式错误\"}")
                return
            }
            let obj = jsonValue.asObject()

            var queryCondition = ""
            let queryVal = obj.get("query")
            if (queryVal.isSome()) {
                let s = queryVal.getOrThrow() as String
                if (let Some(str) <- s) { queryCondition = str }
            }
            if (queryCondition.isEmpty()) {
                queryCondition = body
            }

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = discoveryService.discoverInterconnection(queryCondition, creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow())
                } else {
                    res.status(200).json("[]")
                }
            } else {
                let reason = result.reason ?? "互联智能体发现失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryController", "discoverInterconnection failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func getDiscoveryCache(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let queryHash = req.pathParam("queryHash")
            if (queryHash.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少queryHash参数\"}")
                return
            }

            let result = discoveryService.getDiscoveryCache(queryHash.getOrThrow())
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"未找到有效的发现缓存\"}")
                }
            } else {
                let reason = result.reason ?? "查询失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryController", "getDiscoveryCache failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func cleanExpiredCache(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let result = discoveryService.cleanExpiredCache()
            if (result.success) {
                let count = result.data.getOrDefault({ => 0 })
                res.status(200).json("{\"errno\":\"0\",\"errmsg\":\"success\",\"data\":{\"cleanedCount\":${count}}}")
            } else {
                let reason = result.reason ?? "清理失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryController", "cleanExpiredCache failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }

    public func refreshCache(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let userId = req.getLocals("userId")
            if (userId.isNone()) {
                res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"未登录或登录已过期\"}")
                return
            }

            let queryHash = req.pathParam("queryHash")
            if (queryHash.isNone()) {
                res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"缺少queryHash参数\"}")
                return
            }

            var creatorId = ""
            let userIdStr = userId.getOrThrow() as String
            if (let Some(s) <- userIdStr) { creatorId = s }

            let result = discoveryService.refreshCache(queryHash.getOrThrow(), creatorId)
            if (result.success) {
                if (result.data.isSome()) {
                    res.status(200).json(result.data.getOrThrow().toJsonValue().toString())
                } else {
                    res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"刷新发现缓存失败\"}")
                }
            } else {
                let reason = result.reason ?? "刷新失败"
                res.status(500).json("{\"errno\":\"50001\",\"errmsg\":\"${reason}\"}")
            }
        } catch (e: Exception) {
            LogUtils.error("AipDiscoveryController", "refreshCache failed: ${e.message}")
            res.status(500).json("{\"errno\":\"50000\",\"errmsg\":\"${e.message}\"}")
        }
    }
}