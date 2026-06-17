/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.event_handlers

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.services.uctoo.EventHandlersService
import magic.app.models.uctoo.EventHandlersPO
import magic.app.core.response.APIResult
import magic.log.LogUtils
import stdx.encoding.json.*
import std.collection.ArrayList
import std.time.DateTime

public class EventHandlersManagementController {
    private let service = EventHandlersService()

    public func listActive(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (handlers, total) = service.getListWithFilter(1, 10000, "", "created_at DESC")

            let activeArray = JsonArray()
            for (handler in handlers) {
                if (handler.deletedAt.isSome()) {
                    continue
                }
                let obj = JsonObject()
                obj.put("id", JsonString(handler.id))
                obj.put("eventType", JsonString(handler.eventType))
                obj.put("handlerName", JsonString(handler.handlerName))
                obj.put("handlerClass", JsonString(handler.handlerClass))
                obj.put("status", JsonString(handler.status))
                let descStr = match (handler.description) { case Some(d) => d; case None => "" }
                obj.put("description", JsonString(descStr))
                obj.put("createdAt", JsonString(handler.createdAt.toString()))
                activeArray.add(obj)
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", activeArray)
            result.put("total", JsonInt(total))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("EventHandlersManagement listActive error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func registerHandler(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonObj = JsonValue.fromStr(body).asObject()

            let eventType = _getStr(jsonObj, "eventType", "")
            let handlerName = _getStr(jsonObj, "handlerName", "")
            let handlerClass = _getStr(jsonObj, "handlerClass", "")
            let description = _getStr(jsonObj, "description", "")

            if (eventType.isEmpty() || handlerName.isEmpty() || handlerClass.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"eventType, handlerName, handlerClass are required\"}")
                return
            }

            let handler = EventHandlersPO()
            handler.id = ""
            handler.eventType = eventType
            handler.handlerName = handlerName
            handler.handlerClass = handlerClass
            handler.status = "active"
            handler.description = if (description.isEmpty()) { None<String> } else { Some(description) }
            handler.creator = None<String>
            handler.createdAt = DateTime.now()
            handler.updatedAt = DateTime.now()
            handler.deletedAt = None<DateTime>

            let createResult = service.create(handler, "system")

            let result = JsonObject()
            result.put("success", JsonBool(createResult.success))
            if (createResult.success) {
                if (let Some(data) <- createResult.data) {
                    result.put("data", data.toJsonValue())
                }
            } else {
                result.put("reason", JsonString(createResult.reason ?? "create failed"))
            }
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("EventHandlersManagement registerHandler error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func unregisterHandler(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonObj = JsonValue.fromStr(body).asObject()

            let handlerId = _getStr(jsonObj, "id", "")
            if (handlerId.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"id is required\"}")
                return
            }

            let deleteResult = service.delete(handlerId, false)

            let result = JsonObject()
            result.put("success", JsonBool(deleteResult.success))
            if (!deleteResult.success) {
                result.put("reason", JsonString(deleteResult.reason ?? "delete failed"))
            }
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("EventHandlersManagement unregisterHandler error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func toggleHandler(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            let jsonObj = JsonValue.fromStr(body).asObject()

            let handlerId = _getStr(jsonObj, "id", "")
            let enabled = _getStr(jsonObj, "isEnabled", "true") == "true"

            if (handlerId.isEmpty()) {
                res.status(400).json("{\"success\":false,\"reason\":\"id is required\"}")
                return
            }

            let getResult = service.getById(handlerId)
            if (!getResult.success) {
                res.status(404).json("{\"success\":false,\"reason\":\"Handler not found\"}")
                return
            }

            let handler = getResult.data.getOrThrow()
            handler.status = if (enabled) { "active" } else { "disabled" }
            handler.updatedAt = DateTime.now()

            let updateResult = service.update(handlerId, handler)

            let result = JsonObject()
            result.put("success", JsonBool(updateResult.success))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("EventHandlersManagement toggleHandler error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    public func history(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let (handlers, total) = service.getListWithFilter(1, 10000, "", "created_at DESC")

            let historyArray = JsonArray()
            for (handler in handlers) {
                let obj = JsonObject()
                obj.put("id", JsonString(handler.id))
                obj.put("eventType", JsonString(handler.eventType))
                obj.put("handlerName", JsonString(handler.handlerName))
                obj.put("handlerClass", JsonString(handler.handlerClass))
                obj.put("status", JsonString(handler.status))
                let descStr = match (handler.description) { case Some(d) => d; case None => "" }
                obj.put("description", JsonString(descStr))
                obj.put("createdAt", JsonString(handler.createdAt.toString()))
                obj.put("updatedAt", JsonString(handler.updatedAt.toString()))
                let deletedAtStr = match (handler.deletedAt) {
                    case Some(dt) => dt.toString()
                    case None => ""
                }
                obj.put("deletedAt", JsonString(deletedAtStr))
                historyArray.add(obj)
            }

            let result = JsonObject()
            result.put("success", JsonBool(true))
            result.put("data", historyArray)
            result.put("total", JsonInt(total))
            res.status(200).json(result.toString())
        } catch (e: Exception) {
            LogUtils.error("EventHandlersManagement history error: ${e.message}")
            res.status(500).json("{\"success\":false,\"reason\":\"" + e.message + "\"}")
        }
    }

    private func _getStr(jsonObj: JsonObject, key: String, default: String): String {
        match (jsonObj.get(key)) {
            case Some(v) => if (v is JsonString) { v.asString().getValue() } else { default }
            case None => default
        }
    }
}
