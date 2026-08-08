/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_group

import std.collection.HashMap
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonNull}

public enum MessageType {
    | TASK_ASSIGN
    | RESULT_REPORT
    | STATUS_UPDATE
    | ERROR_REPORT
    | CONTEXT_PASS
    | VALIDATION_RESULT
    | DEGRADATION_NOTICE
    | INCREMENTAL_RESULT
    | TASK_DECOMPOSE
    | AGENT_SELECT
    | RESULT_MERGE
    | CONFLICT_RESOLVE
    | HANDOVER
    | COLLABORATION_REQUEST
}

public class TeamMessage {
    public var sender: String = ""
    public var receiver: String = ""
    public var messageType: MessageType = MessageType.STATUS_UPDATE
    public var payload: String = ""
    public var timestamp: DateTime = DateTime.now()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("sender", JsonString(this.sender))
        map.add("receiver", JsonString(this.receiver))
        map.add("message_type", JsonString(messageTypeToString(this.messageType)))
        map.add("payload", JsonString(this.payload))
        map.add("timestamp", JsonString(this.timestamp.toString()))
        return JsonObject(map)
    }

    public func toJson(): String {
        return this.toJsonValue().toString()
    }

    private static func messageTypeToString(mt: MessageType): String {
        match (mt) {
            case MessageType.TASK_ASSIGN => "TASK_ASSIGN"
            case MessageType.RESULT_REPORT => "RESULT_REPORT"
            case MessageType.STATUS_UPDATE => "STATUS_UPDATE"
            case MessageType.ERROR_REPORT => "ERROR_REPORT"
            case MessageType.CONTEXT_PASS => "CONTEXT_PASS"
            case MessageType.VALIDATION_RESULT => "VALIDATION_RESULT"
            case MessageType.DEGRADATION_NOTICE => "DEGRADATION_NOTICE"
            case MessageType.INCREMENTAL_RESULT => "INCREMENTAL_RESULT"
            case MessageType.TASK_DECOMPOSE => "TASK_DECOMPOSE"
            case MessageType.AGENT_SELECT => "AGENT_SELECT"
            case MessageType.RESULT_MERGE => "RESULT_MERGE"
            case MessageType.CONFLICT_RESOLVE => "CONFLICT_RESOLVE"
            case MessageType.HANDOVER => "HANDOVER"
            case MessageType.COLLABORATION_REQUEST => "COLLABORATION_REQUEST"
        }
    }
}
