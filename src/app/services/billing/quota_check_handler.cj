/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.billing

import magic.interaction.{EventHandlerManager, ChatModelStartEvent, ChatModelEndEvent, ChatModelStartEventHandler, EventResponse}
import magic.interaction.EventResponse
import magic.core.model.ChatResponse
import magic.core.message.Message
import magic.app.services.uctoo.{UsageQuotasService, LlmUsageLogsService}
import magic.app.models.uctoo.UsageQuotasPO
import magic.log.LogUtils
import std.collection.ArrayList
import std.time.DateTime

public class QuotaCheckHandler {
    private let quotasService = UsageQuotasService()

    public func registerGlobalHandlers(): Unit {
        let manager = EventHandlerManager.global
        let handler = this

        let startHandler: ChatModelStartEventHandler = { evt => handler.onChatModelStart(evt) }
        manager.addHandler(startHandler)
    }

    public func onChatModelStart(event: ChatModelStartEvent): EventResponse<ChatResponse> {
        let agentName = event.agent.name

        try {
            let (quotas, _) = quotasService.getListWithFilter(1, 10000, "", "")

            for (quota in quotas) {
                if (quota.deletedAt.isSome()) {
                    continue
                }

                if (!_isQuotaApplicable(quota, agentName)) {
                    continue
                }

                if (quota.quotaUsed >= quota.quotaLimit) {
                    if (quota.isHardLimit) {
                        LogUtils.warn("Quota exceeded (hard limit): ${quota.quotaType} for ${quota.targetType}/${quota.targetId}, used=${quota.quotaUsed}, limit=${quota.quotaLimit}")
                        let chatResponse = ChatResponse(
                            "quota-blocked",
                            Message.user("配额超限：${quota.quotaType} 已用 ${quota.quotaUsed}/${quota.quotaLimit}，请联系管理员调整配额")
                        )
                        return EventResponse.Terminate(chatResponse)
                    } else {
                        LogUtils.warn("Quota exceeded (soft limit): ${quota.quotaType} for ${quota.targetType}/${quota.targetId}, used=${quota.quotaUsed}, limit=${quota.quotaLimit}")
                    }
                } else if (quota.alertThreshold > 0.0 && quota.quotaLimit > 0.0) {
                    let usageRatio = quota.quotaUsed / quota.quotaLimit
                    if (usageRatio >= quota.alertThreshold) {
                        LogUtils.warn("Quota alert: ${quota.quotaType} for ${quota.targetType}/${quota.targetId}, usage=${usageRatio * 100.0}% (threshold=${quota.alertThreshold * 100.0}%)")
                    }
                }
            }
        } catch (ex: Exception) {
            LogUtils.error("Error checking quota: ${ex.message}")
        }

        return EventResponse.Continue
    }

    public func incrementUsage(targetType: String, targetId: String, quotaType: String, amount: Float64): Unit {
        try {
            let (quotas, _) = quotasService.getListWithFilter(1, 10000, "", "")

            for (quota in quotas) {
                if (quota.deletedAt.isSome()) {
                    continue
                }

                if (quota.targetType == targetType && quota.targetId == targetId && quota.quotaType == quotaType) {
                    quota.quotaUsed = quota.quotaUsed + amount
                    quota.updatedAt = DateTime.now()

                    try {
                        quotasService.update(quota.id, quota)
                    } catch (ex: Exception) {
                        LogUtils.error("Failed to increment quota usage for ${quota.id}: ${ex.message}")
                    }
                }
            }
        } catch (ex: Exception) {
            LogUtils.error("Error incrementing usage: ${ex.message}")
        }
    }

    private func _isQuotaApplicable(quota: UsageQuotasPO, agentName: String): Bool {
        if (quota.targetType == "agent" && quota.targetId == agentName) {
            return true
        }
        if (quota.targetType == "global" && quota.targetId == "*") {
            return true
        }
        return false
    }
}