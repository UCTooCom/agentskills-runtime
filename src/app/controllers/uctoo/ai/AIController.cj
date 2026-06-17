/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.uctoo.ai

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.core.model.{ChatModel, ChatRequest, ChatResponse, AsyncChatResponse}
import magic.core.message.{Message, MessageList, MessageRole}
import magic.core.skill.SkillManager
import magic.skill.SkillAwareAgent
import magic.agent_executor.react.ReactExecutor
import magic.core.agent.{AgentRequest, AgentResponse}
import magic.agent.memory.tiered.TieredMemory
import magic.interaction.EventHandlerManager
import magic.log.LogUtils
import stdx.net.http.HttpHeaders
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull}
import magic.jsonable.JsonUtils
import std.time.DateTime
import std.convert.*
import std.collection.{ArrayList, HashMap}

/**
 * AI 聊天控制器
 * 提供 OpenAI 兼容的聊天 API
 */
public class AIController {
    private let _chatModel: ChatModel
    private let _skillManager: SkillManager
    private let _agent: SkillAwareAgent

    public init(chatModel: ChatModel, skillManager: SkillManager) {
        this._chatModel = chatModel
        this._skillManager = skillManager
        let executor = ReactExecutor()
        let memory = TieredMemory(agentId: "ai-api-assistant")
        this._agent = SkillAwareAgent(
            skillManager: skillManager,
            model: chatModel,
            executor: executor,
            name: "AI API Assistant",
            description: "An intelligent assistant for OpenAI-compatible API",
            memory: Some(memory),
            eventHandlerManager: Some(EventHandlerManager.global)
        )
    }

    /**
     * 处理 responses 请求（AI SDK 流式响应端点）
     * POST /api/v1/ai/responses
     */
    public func handleResponses(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"error\": \"Empty request body\"}")
                return
            }

            let jsonBody = JsonValue.fromStr(body)
            if (!(jsonBody is JsonObject)) {
                res.status(400).json("{\"error\": \"Invalid request body\"}")
                return
            }

            let requestJson = jsonBody.asObject()

            let stream = getJsonBool(requestJson, "stream", true)
            let model = getJsonString(requestJson, "model", "default")
            let messages = parseMessages(requestJson.get("messages"))

            LogUtils.info("=== AI Responses Request ===")
            LogUtils.info("Model: ${model}")
            LogUtils.info("Stream: ${stream}")
            LogUtils.info("Message count: ${messages.size}")

            if (stream) {
                handleStreamChat(req, res, messages)
            } else {
                handleNonStreamChat(req, res, messages)
            }
        } catch (e: Exception) {
            LogUtils.error("AI responses error: ${e.message}")
            res.status(500).json("{\"error\": \"${e.message}\"}")
        }
    }

    /**
     * 处理聊天请求
     * POST /api/v1/ai/chat/completions
     */
    public func handleChatCompletions(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = req.body
            if (body.isEmpty()) {
                res.status(400).json("{\"error\": \"Empty request body\"}")
                return
            }

            let jsonBody = JsonValue.fromStr(body)
            if (!(jsonBody is JsonObject)) {
                res.status(400).json("{\"error\": \"Invalid request body\"}")
                return
            }

            let requestJson = jsonBody.asObject()

            let stream = getJsonBool(requestJson, "stream", false)
            let model = getJsonString(requestJson, "model", "default")
            let messages = parseMessages(requestJson.get("messages"))

            LogUtils.info("=== AI Chat Request ===")
            LogUtils.info("Model: ${model}")
            LogUtils.info("Stream: ${stream}")
            LogUtils.info("Message count: ${messages.size}")

            if (stream) {
                handleStreamChat(req, res, messages)
            } else {
                handleNonStreamChat(req, res, messages)
            }
        } catch (e: Exception) {
            LogUtils.error("AI chat error: ${e.message}")
            res.status(500).json("{\"error\": \"${e.message}\"}")
        }
    }

    /**
     * 获取 JSON 布尔值
     */
    private func getJsonBool(obj: JsonObject, key: String, defaultValue: Bool): Bool {
        if (let Some(value) <- obj.get(key)) {
            if (value is JsonBool) {
                return value.asBool().getValue()
            }
        }
        return defaultValue
    }

    /**
     * 获取 JSON 字符串
     */
    private func getJsonString(obj: JsonObject, key: String, defaultValue: String): String {
        if (let Some(value) <- obj.get(key)) {
            if (value is JsonString) {
                return value.asString().getValue()
            }
        }
        return defaultValue
    }

    /**
     * 处理非流式聊天请求
     */
    private func handleNonStreamChat(req: HttpRequest, res: HttpResponse, messages: Array<Message>): Unit {
        try {
            var lastUserMessage = ""
            for (msg in messages) {
                if (msg.role == MessageRole.User) {
                    lastUserMessage = msg.content
                }
            }
            if (!lastUserMessage.isEmpty()) {
                let agentRequest = AgentRequest(lastUserMessage)
                let agentResponse = _agent.chat(agentRequest)
                let chatResponse = ChatResponse(
                    "agent",
                    Message(MessageRole.Assistant, agentResponse.content),
                    usage: None
                )
                let jsonResponse = buildResponse(chatResponse)
                res.status(200)
                   .header("Content-Type", "application/json")
                   .json(jsonResponse)
                return
            }
        } catch (e: Exception) {
            LogUtils.error("AI chat via Agent failed, falling back to direct ChatModel: ${e.message}")
        }
        let chatReq = ChatRequest(messages)
        let response = _chatModel.create(chatReq)
        let jsonResponse = buildResponse(response)
        res.status(200)
           .header("Content-Type", "application/json")
           .json(jsonResponse)
    }

    /**
     * 处理流式聊天请求
     */
    private func handleStreamChat(req: HttpRequest, res: HttpResponse, messages: Array<Message>): Unit {
        let startTime = DateTime.now()
        let epoch = DateTime.UnixEpoch
        let created = (startTime - epoch).toMilliseconds() / 1000
        
        try {
            let chatReq = ChatRequest(messages)
            let asyncResponse = _chatModel.asyncCreate(chatReq)
            
            res.status(200)
               .header("Content-Type", "text/event-stream")
               .header("Cache-Control", "no-cache")
               .header("Connection", "keep-alive")
               .header("Access-Control-Allow-Origin", "*")

            var responseBuilder = StringBuilder()
            
            for (chunk in asyncResponse.chunks) {
                let content = chunk.message.content
                let done = chunk.done
                
                // AI SDK 期望的响应格式：response.output_text.delta
                let chunkJson = if (!content.isEmpty()) {
                    "{\"type\":\"response.output_text.delta\",\"output_index\":0,\"delta\":\"${escapeJson(content)}\"}"
                } else if (done) {
                    "{\"type\":\"response.completed\",\"response\":{\"role\":\"assistant\",\"content\":\"\",\"finish_reason\":\"stop\"}}"
                } else {
                    ""
                }
                
                if (!chunkJson.isEmpty()) {
                    responseBuilder.append("data: ${chunkJson}\n\n")
                }
                
                if (done) {
                    break
                }
            }
            
            responseBuilder.append("data: [DONE]\n\n")
            res.send(responseBuilder.toString())
        } catch (e: Exception) {
            LogUtils.error("Stream chat error: ${e.message}")
            // AI SDK 期望的错误响应格式：response.failed
            let errorChunk = "{\"type\":\"response.failed\",\"response\":{\"error\":{\"message\":\"${escapeJson(e.message)}\"}}}"
            res.send("data: ${errorChunk}\n\ndata: [DONE]\n\n")
        }
    }

    /**
     * 解析请求消息
     */
    private func parseMessages(messagesValue: Option<JsonValue>): Array<Message> {
        let messages = ArrayList<Message>()
        
        if (let Some(msgArray) <- messagesValue) {
            if (!(msgArray is JsonArray)) {
                return messages.toArray()
            }
            
            for (item in msgArray.asArray().getItems()) {
                if (!(item is JsonObject)) {
                    continue
                }
                
                let obj = item.asObject()
                let role = getJsonString(obj, "role", "user")
                let content = getJsonString(obj, "content", "")
                
                let messageRole = match (role) {
                    case "system" => MessageRole.System
                    case "assistant" => MessageRole.Assistant
                    case _ => MessageRole.User
                }
                
                messages.add(Message(messageRole, content))
            }
        }
        
        return messages.toArray()
    }

    /**
     * 构建非流式响应
     */
    private func buildResponse(response: ChatResponse): String {
        let message = response.message
        
        // AI SDK 期望的响应格式
        let responseJson = JsonUtils.buildJsonObject(
            ("type", JsonString("response.completed")),
            ("response", JsonUtils.buildJsonObject(
                ("role", JsonString(message.role.toString())),
                ("content", JsonString(message.content)),
                ("finish_reason", JsonString("stop"))
            ))
        )
        
        return responseJson.toJsonString()
    }

    /**
     * JSON 转义
     */
    private func escapeJson(str: String): String {
        return str.replace("\\", "\\\\")
                  .replace("\"", "\\\"")
                  .replace("\n", "\\n")
                  .replace("\r", "\\r")
                  .replace("\t", "\\t")
    }
}