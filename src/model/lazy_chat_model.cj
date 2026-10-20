/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model

import magic.core.model.*
import magic.model.channel.ChannelRegistry
import magic.log.LogUtils

/**
 * 惰性 ChatModel 包装器（dynamic-model-channel T010）。
 *
 * 默认通道解析（Plan A，2026-10-14）：
 * - 构造时不再把 .env 的 MODEL_CONFIG 当作「硬默认」；.env 退化为兜底/逃生舱。
 * - 默认聊天通道的真相来自 DB：llm_channel.is_default 标记的通道（ChannelRegistry.getDefault()），
 *   解析键为 "<code>:<default_model>"。这保证了「界面上看到的默认通道 = 实际聊天走的通道」。
 * - 仅当 DB 默认通道不可用（注册表无默认 / 断库退化为种子且无默认 / 其他异常）时，
 *   才回落到 .env 的 MODEL_CONFIG（fallbackSpec）。再往后没有静默的供应商兜底 ——
 *   历史版本在这里硬编码 `stepfun:step-3`（2026-10-16 已移除）：用户在界面上看的是一个
 *   通道、实际聊天走的却是另一个从不显示的厂商，属于「不可见的真相源」，与本工程
 *   dynamic-model-channel 的「真相在数据、界面所见即所得」相悖。
 *
 * 请求级覆盖（WebMCPProtocol.params.model）优先级高于以上所有默认，逻辑在协议层处理，
 * 因此「用户在界面切换器选的通道」一定先于本默认生效。
 */
public class LazyChatModel <: ChatModel {
    /** 哨兵：表示「解析时取 DB 默认通道」，而非 .env 字面量。 */
    public static let DB_DEFAULT_SPEC = "__DB_DEFAULT__"

    private let modelName: String
    /** .env 的 MODEL_CONFIG，仅作兜底。空串表示无兜底。 */
    private let fallbackSpec: String
    // maxTokens 是 setter 状态：本地缓存，每次解析后再回灌给真实实例
    private var _maxTokens: Option<Int64> = None

    // 仓颉：**只有命名参数（声明写 `para!: Type`）才能带默认值**；位置参数写
    // `para: Type = value` 会直接报 "expected ',' or ')'"。
    // 调用点按命名传值 `fallbackSpec: x`（不带 `!`）。
    public init(modelName: String, fallbackSpec!: String = "") {
        this.modelName = modelName
        this.fallbackSpec = fallbackSpec
    }

    /**
     * 解析真实 ChatModel：
     * - 哨兵键：DB 默认通道优先，失败回落 .env，再回落 legacy。
     * - 其它键（如显式 channel:model）：原样交给 ModelManager。
     */
    private func resolve(): ChatModel {
        if (this.modelName == DB_DEFAULT_SPEC) {
            if (let Some(def) <- ChannelRegistry.shared().getDefault()) {
                let modelId = def.defaultModel
                if (!modelId.isEmpty()) {
                    return ModelManager.createChatModel("${def.code}:${modelId}")
                }
            }
            if (!this.fallbackSpec.isEmpty()) {
                return ModelManager.createChatModel(this.fallbackSpec)
            }
            // 走到这里是配置缺失，**必须可见**：打 ERROR 让排障的人一眼看到，
            // 而不是悄悄用某个写死的供应商顶上（用户会发现"我选的是 A，回答我的是谁？"）。
            LogUtils.error("LazyChatModel: llm_channel 无 is_default 通道且无 .env 兜底，" +
                "暂按 deepseek 解析；请在通道管理界面设置一个可用默认通道（DELETE 掉这个隐患）")
            return ModelManager.createChatModel("deepseek:deepseek-flash")
        }
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
