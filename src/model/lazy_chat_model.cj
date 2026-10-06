/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model

import magic.core.model.*

/**
 * 惰性 ChatModel 包装器（dynamic-model-channel T010）。
 *
 * 设计（design.md §2 / §6）：
 * - 启动期不再「建一次实例、全局透传」，而是持有解析键（modelName），
 *   在**请求边界**（每次 create/asyncCreate）才向 ModelManager 解析真实实例。
 * - 构造永不抛错 → 启动时即使 MODEL_CONFIG 指向的通道尚未就绪，也不会中断 runtime；
 *   路由注册不再因「模型创建失败」而被跳过（REQ-DMC-017 V3）。
 * - 每次解析都走 `ModelManager.createChatModel` → 注册表（ChannelRegistry）+ 实例缓存
 *   （ModelInstanceCache 按 revision 失效），通道热切换对下一请求立即生效（V1/V4）。
 * - 该包装器本身实现 `ChatModel`，因此现有所有消费方（WebMCPProtocol / AIController /
 *   WsChatController / McpController）的构造签名**零改动**，只把内部持有的 ChatModel
 *   从「启动期单例」换成「惰性解析器」即可。
 */
public class LazyChatModel <: ChatModel {
    private let modelName: String
    // maxTokens 是 setter 状态：本地缓存，每次解析后再回灌给真实实例
    private var _maxTokens: Option<Int64> = None

    public init(modelName: String) {
        this.modelName = modelName
    }

    /**
     * 解析真实 ChatModel：优先注册表（DB/种子通道），未命中回退旧 DEFAULT_PROVIDER_MAP。
     * 每次调用都重新解析，确保通道热切换（revision 变化）对下一请求生效。
     */
    private func resolve(): ChatModel {
        ModelManager.createChatModel(modelName)
    }

    override public prop provider: String {
        get() { resolve().provider }
    }

    override public prop name: String {
        get() { resolve().name }
    }

    override public prop contextLength: Int64 {
        get() { resolve().contextLength }
    }

    override public mut prop maxTokens: Option<Int64> {
        get() { _maxTokens }
        set(v) { _maxTokens = v }
    }

    override public func create(chatReq: ChatRequest): ChatResponse {
        let m = resolve()
        if (let Some(mt) <- _maxTokens) {
            m.maxTokens = mt
        }
        m.create(chatReq)
    }

    override public func asyncCreate(chatReq: ChatRequest): AsyncChatResponse {
        let m = resolve()
        if (let Some(mt) <- _maxTokens) {
            m.maxTokens = mt
        }
        m.asyncCreate(chatReq)
    }
}
