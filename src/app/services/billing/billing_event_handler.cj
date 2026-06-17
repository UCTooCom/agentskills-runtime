/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.billing

import magic.interaction.{ChatModelEndEvent, ChatModelFailureEvent, AgentEndEvent, EventHandlerManager, ChatModelEndEventHandler, ChatModelFailureEventHandler, AgentEndEventHandler, EventResponse}
import magic.core.model.ChatUsage
import magic.app.models.uctoo.LlmUsageLogsPO
import magic.app.services.uctoo.LlmUsageLogsService
import magic.log.LogUtils

func billingReasonStr(reason: ?String): String {
    match (reason) { case Some(s) => s; case None => "unknown" }
}

public class BillingEventHandler {
    private let usageService = LlmUsageLogsService()

    public func registerGlobalHandlers(): Unit {
        let manager = EventHandlerManager.global
        let handler = this

        let endHandler: ChatModelEndEventHandler = { evt => handler.onChatModelEnd(evt) }
        manager.addHandler(endHandler)

        let failureHandler: ChatModelFailureEventHandler = { evt =>
            handler.onChatModelFailure(evt)
            EventResponse.Continue
        }
        manager.addHandler(failureHandler)

        let agentEndHandler: AgentEndEventHandler = { evt => handler.onAgentEnd(evt) }
        manager.addHandler(agentEndHandler)

        let quotaHandler = QuotaCheckHandler()
        quotaHandler.registerGlobalHandlers()

        LogUtils.info("BillingEventHandler", "已注册3个计费事件处理器+配额检查到EventHandlerManager.global")
    }

    public func onChatModelEnd(event: ChatModelEndEvent): Unit {
        try {
            let log = LlmUsageLogsPO()
            let agentName = event.agent.name
            let modelName = event.chatResponse.model
            log.agentId = Some(agentName)
            log.provider = extractProvider(modelName)
            log.model = extractModel(modelName)
            log.modelId = modelName
            log.requestType = "chat"

            if (let Some(usage) <- event.chatResponse.usage) {
                log.promptTokens = usage.promptTokens
                log.completionTokens = usage.completionTokens
                log.totalTokens = usage.totalTokens
                if (let Some(tc) <- usage.timeCost) {
                    log.timeCostMs = Int32(tc.toMilliseconds())
                }
            }

            spawn {
                try {
                    let result = usageService.create(log, agentName)
                    if (result.success) {
                        LogUtils.info("BillingEventHandler: saved llm_usage_log for agent ${agentName}, model ${modelName}")
                    } else {
                        LogUtils.error("BillingEventHandler: save llm_usage_log FAILED for agent ${agentName}, reason: ${billingReasonStr(result.reason)}")
                    }
                } catch (e: Exception) {
                    LogUtils.error("BillingEventHandler.onChatModelEnd spawn failed: ${e.message}")
                }
            }
        } catch (e: Exception) {
            LogUtils.error("BillingEventHandler.onChatModelEnd failed: ${e.message}")
        }
    }

    public func onChatModelFailure(event: ChatModelFailureEvent): Unit {
        try {
            let log = LlmUsageLogsPO()
            log.provider = "unknown"
            log.model = "unknown"
            log.modelId = "unknown"
            log.promptTokens = 0
            log.completionTokens = 0
            log.totalTokens = 0
            log.errorMessage = Some(event.error)
            log.requestType = "chat"

            spawn {
                try {
                    let result = usageService.create(log, "system")
                    if (!result.success) {
                        LogUtils.error("BillingEventHandler: save llm_usage_log FAILED for failure event, reason: ${billingReasonStr(result.reason)}")
                    }
                } catch (e: Exception) {
                    LogUtils.error("BillingEventHandler.onChatModelFailure spawn failed: ${e.message}")
                }
            }
        } catch (e: Exception) {
            LogUtils.error("BillingEventHandler.onChatModelFailure failed: ${e.message}")
        }
    }

    public func onAgentEnd(event: AgentEndEvent): Unit {
        try {
            if (let Some(resp) <- event.agentResponse) {
                LogUtils.info("Agent '${event.agent.name}' completed with status: ${resp.status}")
            }
        } catch (_: Exception) {}
    }

    private func extractProvider(modelId: String): String {
        let parts = modelId.split(":")
        if (parts.size >= 1) {
            parts[0]
        } else {
            "unknown"
        }
    }

    private func extractModel(modelId: String): String {
        let parts = modelId.split(":")
        if (parts.size >= 2) {
            parts[1]
        } else if (parts.size == 1) {
            parts[0]
        } else {
            "unknown"
        }
    }
}