/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.context_verify

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonString}
import magic.agent_group.{TeamMessenger, TeamMessage, MessageType, AgentRole}
import magic.interaction.{ExecutionEvidenceRecorder, EvidenceType}

public class ContextPasser {
    private let _messenger: TeamMessenger
    private let _evidenceRecorder: ExecutionEvidenceRecorder

    public init(messenger!: TeamMessenger, evidenceRecorder!: ExecutionEvidenceRecorder) {
        _messenger = messenger
        _evidenceRecorder = evidenceRecorder
    }

    public func passContext(from: String, to: String, context: AgentContext): String {
        let evidenceId = _evidenceRecorder.recordStart(
            context.taskId,
            from,
            "ContextPass",
            EvidenceType.AgentExecution,
            Some(context.toJsonValue())
        )

        let msg = TeamMessage()
        msg.sender = from
        msg.receiver = to
        msg.messageType = MessageType.CONTEXT_PASS
        msg.payload = context.toJsonValue().toString()

        _messenger.send(from, to, msg)

        _evidenceRecorder.recordEnd(evidenceId, Some(context.toJsonValue()))
        return evidenceId
    }

    public func broadcastContext(from: String, role: AgentRole, context: AgentContext): Unit {
        let msg = TeamMessage()
        msg.sender = from
        msg.messageType = MessageType.CONTEXT_PASS
        msg.payload = context.toJsonValue().toString()

        _messenger.broadcast(from, role, msg)
    }

    public func receiveContext(receiver: String): Option<AgentContext> {
        let messages = _messenger.getMessagesTo(receiver)
        for (msg in messages) {
            var isContextPass = false
            match (msg.messageType) {
                case MessageType.CONTEXT_PASS => isContextPass = true
                case _ => isContextPass = false
            }
            if (isContextPass) {
                let jsonStr = msg.payload
                let jsonVal = JsonString(jsonStr)
                return AgentContext.fromJsonValue(jsonVal)
            }
        }
        return None
    }

    public func createContext(taskId: String, input: JsonValue, constraints: HashMap<String, String>): AgentContext {
        return AgentContext(taskId: taskId, parentId: None<String>, input: input, constraints: constraints, metadata: HashMap<String, String>())
    }

    public func createChildContext(parentContext: AgentContext, input: JsonValue): AgentContext {
        var mergedConstraints = HashMap<String, String>()
        for ((k, v) in parentContext.constraints) {
            mergedConstraints.add(k, v)
        }
        return AgentContext(taskId: "${parentContext.taskId}_child", parentId: Some(parentContext.taskId), input: input, constraints: mergedConstraints, metadata: HashMap<String, String>())
    }
}