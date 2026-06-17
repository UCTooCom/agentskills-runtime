/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.storage

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.log.LogUtils
import stdx.encoding.json.*

public class StorageController {
    public func listTypes(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let types = JsonArray()
            let kvObj = JsonObject()
            kvObj.put("type", JsonString("kv"))
            kvObj.put("description", JsonString("Key-Value JSON storage"))
            types.add(kvObj)

            let vectorObj = JsonObject()
            vectorObj.put("type", JsonString("vector"))
            vectorObj.put("description", JsonString("In-memory vector database"))
            types.add(vectorObj)

            let graphObj = JsonObject()
            graphObj.put("type", JsonString("graph"))
            graphObj.put("description", JsonString("Knowledge graph storage"))
            types.add(graphObj)

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", types)
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func kvGet(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let keyOpt = req.queryParam("key")
            let key = match (keyOpt) { case Some(v) => v; case None => "" }
            if (key.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"key参数缺失\"}")
                return
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("type", JsonString("kv"))
            result.put("key", JsonString(key))
            result.put("message", JsonString("KV存储操作，待JsonKVStorage集成"))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func kvSet(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let keyOpt = req.queryParam("key")
            let key = match (keyOpt) { case Some(v) => v; case None => "" }
            if (key.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"key参数缺失\"}")
                return
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("type", JsonString("kv"))
            result.put("key", JsonString(key))
            result.put("message", JsonString("KV存储已设置，待JsonKVStorage集成"))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func vectorSearch(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("type", JsonString("vector"))
            result.put("message", JsonString("向量搜索，待InMemoryVectorDatabase集成"))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }
}
