/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.ws_support

import stdx.net.http.{WebSocket, WebSocketFrameType}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt}
import std.time.DateTime
import magic.log.LogUtils

public class WebSocketMessage {
    public let messageType: String
    public let payload: JsonObject
    public let timestamp: Int64

    public init(messageType: String, payload: JsonObject, timestamp: Int64) {
        this.messageType = messageType
        this.payload = payload
        this.timestamp = timestamp
    }

    public func toJsonString(): String {
        let jo = JsonObject()
        jo.put("type", JsonString(messageType))
        jo.put("payload", payload)
        jo.put("timestamp", JsonInt(timestamp))
        return jo.toJsonString()
    }
}

public class WebSocketSession {
    public let sessionId: String
    public let websocket: WebSocket
    private let _connectedAt: Int64

    public init(sessionId: String, websocket: WebSocket) {
        this.sessionId = sessionId
        this.websocket = websocket
        this._connectedAt = (DateTime.now() - DateTime.UnixEpoch).toMilliseconds()
    }

    public prop connectedAt: Int64 {
        get() { _connectedAt }
    }

    public func sendMessage(message: WebSocketMessage): Unit {
        try {
            let jsonStr = message.toJsonString()
            let bytes = jsonStr.toArray()
            websocket.write(WebSocketFrameType.TextWebFrame, bytes)
        } catch (ex: Exception) {
            LogUtils.error("Failed to send message to session ${sessionId}: ${ex.message}")
        }
    }

    public func close(): Unit {
        try {
            websocket.writeCloseFrame()
        } catch (ex: Exception) {
            LogUtils.error("Error closing WebSocket session ${sessionId}: ${ex.message}")
        }
    }
}