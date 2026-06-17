/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.core.agent.{AgentExecution, AgentResponse}
import magic.core.message.{Message, MessageList, MessageRole}
import magic.app.models.uctoo.AgentContextsPO
import magic.app.services.uctoo.AgentContextsService
import magic.app.core.response.APIResult
import magic.log.LogUtils
import std.collection.ArrayList
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString}
import std.time.DateTime

public class CheckpointManager {
    private let contextsService = AgentContextsService()

    public func saveCheckpoint(agentId: String, execution: AgentExecution, taskId: Option<String>): String {
        try {
            let messagesJson = serializeMessages(execution.messages)
            let metadata = JsonObject()
            metadata.put("taskId", if (let Some(t) <- taskId) { JsonString(t) } else { JsonString("") })
            metadata.put("chatRound", JsonString(execution.chatRound.toString()))
            metadata.put("savedAt", JsonString(DateTime.now().toString()))

            let po = AgentContextsPO()
            po.agentId = agentId
            po.messages = Some(messagesJson)
            po.metadata = Some(metadata.toString())

            let result = contextsService.create(po, agentId)
            if (result.success) {
                if (let Some(data) <- result.data) {
                    LogUtils.info("CheckpointManager", "检查点已保存: agentId=${agentId}, contextId=${data.id}")
                    return data.id
                }
            }
            let reasonStr = match (result.reason) { case Some(r) => r; case None => "保存失败" }
            LogUtils.error("CheckpointManager", "检查点保存失败: ${reasonStr}")
            return ""
        } catch (e: Exception) {
            LogUtils.error("CheckpointManager", "检查点保存异常: ${e.message}")
            return ""
        }
    }

    public func loadLatestCheckpoint(agentId: String): Option<Array<Message>> {
        try {
            let (records, total) = contextsService.getListWithFilter(1, 1, "agent_id='${agentId}'", "created_at DESC")
            if (records.isEmpty()) {
                return None
            }
            let po = records[0]
            if (let Some(msgStr) <- po.messages) {
                return Some(deserializeMessages(msgStr))
            }
            return None
        } catch (e: Exception) {
            LogUtils.error("CheckpointManager", "检查点加载异常: ${e.message}")
            return None
        }
    }

    public func getCheckpointById(contextId: String): Option<AgentContextsPO> {
        try {
            let result = contextsService.getById(contextId)
            if (result.success) {
                if (let Some(data) <- result.data) {
                    return Some<AgentContextsPO>(data)
                }
            }
            return None
        } catch (_: Exception) {
            return None
        }
    }

    public func listCheckpoints(agentId: String, page: Int64, pageSize: Int64): (ArrayList<AgentContextsPO>, Int64) {
        try {
            contextsService.getListWithFilter(Int32(page), Int32(pageSize), "agent_id='${agentId}'", "created_at DESC")
        } catch (_: Exception) {
            (ArrayList<AgentContextsPO>(), 0)
        }
    }

    public func deleteCheckpoint(contextId: String): Bool {
        try {
            let result = contextsService.delete(contextId, true)
            return result.success
        } catch (_: Exception) {
            false
        }
    }

    private func serializeMessages(messages: MessageList): String {
        try {
            let arr = JsonArray()
            for (msg in messages) {
                let obj = JsonObject()
                obj.put("role", JsonString(msg.role.toString()))
                obj.put("content", JsonString(msg.content))
                arr.add(obj)
            }
            arr.toString()
        } catch (_: Exception) {
            "[]"
        }
    }

    private func deserializeMessages(jsonStr: String): Array<Message> {
        try {
            let json = JsonValue.fromStr(jsonStr)
            if (!(json is JsonArray)) { return [] }
            let arr = json.asArray()
            let messages = ArrayList<Message>()
            for (i in 0..arr.size()) {
                if (let Some(item) <- arr.get(i)) {
                    if (item is JsonObject) {
                        let obj = item.asObject()
                        var role = MessageRole.User
                        var content = ""
                        if (let Some(r) <- obj.get("role")) {
                            if (r is JsonString) {
                                let roleStr = r.asString().getValue()
                                if (roleStr == "assistant") { role = MessageRole.Assistant }
                                else if (roleStr == "system") { role = MessageRole.System }
                            }
                        }
                        if (let Some(c) <- obj.get("content")) {
                            if (c is JsonString) { content = c.asString().getValue() }
                        }
                        messages.add(Message(role, content))
                    }
                }
            }
            messages.toArray()
        } catch (_: Exception) {
            []
        }
    }
}