/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.retriever

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.uctoo.RetrieversService
import magic.app.models.uctoo.RetrieversPO
import magic.app.core.response.APIResult
import magic.log.LogUtils
import stdx.encoding.json.*
import std.collection.ArrayList

public class RetrieverController {
    private let retrieversService = RetrieversService()

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (records, total) = retrieversService.getListWithFilter(1, 100, "", "")
            let arr = JsonArray()
            for (po in records) {
                arr.add(po.toJsonValue())
            }
            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", arr)
            result.put("total", JsonInt(total))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func getById(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let idOpt = req.pathParam("id")
            if (idOpt.isNone()) {
                res.status(400).json("{\"success\":false,\"reason\":\"id参数缺失\"}")
                return
            }
            let id = idOpt.getOrThrow()
            let result = retrieversService.getById(id)
            if (result.success) {
                if (let Some(data) <- result.data) {
                    res.status(200).json("{\"success\":true,\"data\":" + data.toJson() + "}")
                } else {
                    res.status(404).json("{\"success\":false,\"reason\":\"未找到数据\"}")
                }
            } else {
                let reasonStr = match (result.reason) { case Some(r) => r; case None => "未找到" }
                res.status(404).json("{\"success\":false,\"reason\":\"${reasonStr}\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func search(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let idOpt = req.pathParam("id")
            if (idOpt.isNone()) {
                res.status(400).json("{\"success\":false,\"reason\":\"id参数缺失\"}")
                return
            }
            let id = idOpt.getOrThrow()

            let body = req.body
            let query = extractJsonString(body, "query")
            if (query.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"query参数缺失\"}")
                return
            }

            let result = retrieversService.getById(id)
            if (!result.success) {
                res.status(404).json("{\"success\":false,\"reason\":\"检索器不存在\"}")
                return
            }

            let respObj = JsonObject()
            respObj.put("success", JsonBool(true))
            respObj.put("retrieverId", JsonString(id))
            respObj.put("query", JsonString(query))
            respObj.put("message", JsonString("检索请求已接收，实际检索逻辑待RAG集成"))
            res.status(200).json(respObj.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    private func extractJsonString(body: String, key: String): String {
        try {
            let json = JsonValue.fromStr(body)
            if (json is JsonObject) {
                let obj = json.asObject()
                if (let Some(v) <- obj.get(key)) {
                    if (v is JsonString) { return v.asString().getValue() }
                }
            }
            ""
        } catch (_: Exception) { "" }
    }
}
