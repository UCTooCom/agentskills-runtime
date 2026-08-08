/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_group

import std.collection.ArrayList
import std.time.DateTime
import magic.log.LogUtils

public class TeamMessenger {
    private let messageHistory = ArrayList<TeamMessage>()
    private let subscribers = ArrayList<(TeamMessage) -> Unit>()

    public init() {}

    public func send(from: String, to: String, message: TeamMessage): Unit {
        let msg = TeamMessage()
        msg.sender = from
        msg.receiver = to
        msg.messageType = message.messageType
        msg.payload = message.payload
        msg.timestamp = DateTime.now()
        messageHistory.add(msg)
        LogUtils.info("[TeamMessenger] ${from} -> ${to}: ${messageTypeToString(msg.messageType)}")
        notifySubscribers(msg)
    }

    public func broadcast(from: String, role: AgentRole, message: TeamMessage): Unit {
        let msg = TeamMessage()
        msg.sender = from
        msg.receiver = roleToString(role)
        msg.messageType = message.messageType
        msg.payload = message.payload
        msg.timestamp = DateTime.now()
        messageHistory.add(msg)
        LogUtils.info("[TeamMessenger] ${from} -> [${roleToString(role)}]: ${messageTypeToString(msg.messageType)}")
        notifySubscribers(msg)
    }

    public func request(from: String, to: String, message: TeamMessage): Option<TeamMessage> {
        send(from, to, message)
        let responses = getMessagesTo(from)
        if (!responses.isEmpty()) {
            return Some(responses[responses.size - 1])
        }
        return None
    }

    public func getMessagesTo(receiver: String): ArrayList<TeamMessage> {
        let result = ArrayList<TeamMessage>()
        for (msg in messageHistory) {
            if (msg.receiver == receiver) {
                result.add(msg)
            }
        }
        return result
    }

    public func getMessagesFrom(sender: String): ArrayList<TeamMessage> {
        let result = ArrayList<TeamMessage>()
        for (msg in messageHistory) {
            if (msg.sender == sender) {
                result.add(msg)
            }
        }
        return result
    }

    public func getHistory(): ArrayList<TeamMessage> {
        return messageHistory
    }

    public func subscribe(handler: (TeamMessage) -> Unit): Unit {
        subscribers.add(handler)
    }

    public func clearHistory(): Unit {
        messageHistory.clear()
    }

    private func notifySubscribers(msg: TeamMessage): Unit {
        for (handler in subscribers) {
            try {
                handler(msg)
            } catch (e: Exception) {
                LogUtils.error("[TeamMessenger] Subscriber error: ${e.message}")
            }
        }
    }

    private static func roleToString(role: AgentRole): String {
        match (role) {
            case AgentRole.Manager => "manager"
            case AgentRole.TeamLeader => "team_leader"
            case AgentRole.Worker => "worker"
        }
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