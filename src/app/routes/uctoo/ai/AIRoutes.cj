/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.uctoo.ai

import magic.app.core.router.Router
import magic.app.controllers.uctoo.ai.AIController
import magic.core.skill.SkillManager
import magic.core.model.ChatModel
import magic.log.LogUtils

/**
 * AI 聊天路由配置
 * 提供 OpenAI 兼容的聊天 API 端点
 */
public class AIRoutes {
    private let _router: Router
    private let _controller: AIController

    public init(router: Router, skillManager: SkillManager, chatModel: ChatModel) {
        this._router = router
        this._controller = AIController(chatModel, skillManager)
    }

    /**
     * 注册所有 AI 路由
     */
    public func register(): Unit {
        // AI SDK responses 端点（流式响应）
        _router.post("/api/v1/ai/responses", { req, res =>
            _controller.handleResponses(req, res)
        })
        
        // OpenAI 兼容的聊天端点
        _router.post("/api/v1/ai/chat/completions", { req, res =>
            _controller.handleChatCompletions(req, res)
        })
        
        // 健康检查端点
        _router.get("/api/v1/ai/health", { req, res =>
            res.status(200).json("{\"status\":\"ok\",\"service\":\"ai-api\"}")
        })
        
        LogUtils.info("AI routes registered successfully")
    }
}