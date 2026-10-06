/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import magic.model.openai.{OpenAIChatModel, OpenAIEmbeddingModel, OpenAIImageModel}
import magic.model.ollama.{OllamaChatModel, OllamaEmbeddingModel}
import magic.model.llamacpp.LlamacppEmbeddingModel
import magic.model.tokendance.{TokendanceChatModel, TokendanceEmbeddingModel}
import magic.core.model.*

/**
 * AdapterFactory — 模式A 直通（覆盖 ~90% 通道，design.md §5.1）。
 *
 * 根据通道 protocol + kind 复用既有模型实现；密钥经 ChannelRegistry.resolveSecret 解析
 * （env: 引用走 getEnv），插件进程绝不接收明文（REQ-DMC-007）。
 *
 * 模式B（plugin:<name> 私有协议）在 Phase 2 接入 L3 插件轨，MVP 暂不支持。
 */
public class AdapterFactory {

    public static func buildChatModel(channel: ChannelSnapshot, modelId: String): ChatModel {
        let apiKey = ChannelRegistry.shared().resolveSecret(channel.code)
        let baseURL = ChannelRegistry.shared().resolveBaseUrl(channel.code)
        match (channel.protocol) {
            case "openai-chat" =>
                return OpenAIChatModel(channel.code, modelId, apiKey: apiKey, baseURL: baseURL)
            case "ollama" =>
                return OllamaChatModel(modelId, baseURL: baseURL)
            case "tokendance" =>
                return TokendanceChatModel(channel.code, modelId, apiKey: apiKey, baseURL: baseURL)
            // T023 模式B：协议私有 → 交给 L3 插件适配器（协议见 docs/ref/llm-adapter-contract.md）
            case p =>
                if (PluginAdapterBridge.isPluginProtocol(p)) {
                    return PluginChatModel(channel, modelId)
                }
                throw Exception("协议 ${channel.protocol} 暂不支持 chat")
        }
    }

    public static func buildEmbeddingModel(channel: ChannelSnapshot, modelId: String): EmbeddingModel {
        let apiKey = ChannelRegistry.shared().resolveSecret(channel.code)
        let baseURL = ChannelRegistry.shared().resolveBaseUrl(channel.code)
        match (channel.protocol) {
            case "openai-chat" =>
                return OpenAIEmbeddingModel(modelId, apiKey: apiKey, baseURL: baseURL)
            case "ollama" =>
                return OllamaEmbeddingModel(modelId, baseURL: baseURL)
            case "llamacpp" =>
                return LlamacppEmbeddingModel(baseURL: baseURL)
            case "tokendance" =>
                return TokendanceEmbeddingModel(modelId, apiKey: apiKey, baseURL: baseURL)
            case _ =>
                throw Exception("协议 ${channel.protocol} 暂不支持 embedding")
        }
    }

    public static func buildImageModel(channel: ChannelSnapshot, modelId: String): ImageModel {
        let apiKey = ChannelRegistry.shared().resolveSecret(channel.code)
        let baseURL = ChannelRegistry.shared().resolveBaseUrl(channel.code)
        match (channel.protocol) {
            case "openai-chat" =>
                return OpenAIImageModel(modelId, apiKey: apiKey, baseURL: baseURL)
            case "tokendance" =>
                return OpenAIImageModel(modelId, apiKey: apiKey, baseURL: baseURL)
            case _ =>
                throw Exception("协议 ${channel.protocol} 暂不支持 image")
        }
    }
}
