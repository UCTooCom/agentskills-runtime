/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.core.model

import magic.core.message.{Message, MessageRole, MessageList}

import std.sync.AtomicBool

public struct AsyncChatChunk <: ToString {
    protected AsyncChatChunk(
        public let message!: Message,
        public let done!: Bool = false,
        public let usage!: Option<ChatUsage> = None
    ) { }

    override public func toString(): String {
        let strBuilder = StringBuilder()
        strBuilder.append("AsyncChatChunk: Usage[${usage.toString()}]\n")
        strBuilder.append("${this.message}")
        strBuilder.toString()
    }
}

/**
 * Wrap the async chat response as a string iterator
 */
private class AsyncChatResponseIterator <: Iterator<String> {
    AsyncChatResponseIterator(
        private let asyncChatResp: AsyncChatResponse,
        private let withReason: Bool
    ) { }

    override public func next(): Option<String> {
        return match (this.asyncChatResp.next()) {
            case Some(chunk) =>
                if (withReason) {
                    chunk.message.reason ?? chunk.message.content
                } else {
                    chunk.message.content
                }
            case None => None
        }
    }
}

public class AsyncChatResponse <: ChatResponse {
    public let chunks: Iterator<AsyncChatChunk>
    // The following fields will be update during receiving chunks
    private var role = MessageRole.Assistant
    private let content = StringBuilder()
    /**
     * Round3: reasoning_content（思维链）单独累积，不再与 content 混用。
     *
     * 背景：ReAct 的标签流解析器只能吃 content（<thinking>/<action>/<answer> 在里面）。
     * 旧实现 `AsyncChatResponseIterator(withReason: true)` 用 `reason ?? content`，
     * 一旦模型是推理模型（先吐 reasoning_content），真正的 content 就被整段丢弃，
     * 解析器只看到纯散文的 reasoning → 判定格式错误 → 反复重试直到步数耗尽。
     * 现在二者各走各路：content 供解析，reasoning 供前端展示思维链。
     */
    private let reasoning = StringBuilder()
    // The following fields will be set when the response stream is finished
    private var _usage: Option<ChatUsage> = None
    private var _message = Message.assistant("")
    private let finished = AtomicBool(false)

    protected init(model: String, chunks: Iterator<AsyncChatChunk>) {
        super(model)
        this.chunks = chunks
    }

    override public prop usage: Option<ChatUsage> {
        get() {
            if (!finished.load()) {
                return None
            } else {
                _usage
            }
        }
    }

    /**
     * This method is synchronous, it will wait until the chat response completes.
     */
    override public prop message: Message {
        get() {
            if (!finished.load()) {
                // Consume all chunks
                while (let Some(_) <- this.next()) { }
            }
            this._message
        }
    }

    /**
     * Round3: 已收到的 reasoning_content（思维链）累计值。
     *
     * 注意：只在流被消费后才有值。ReAct 的异步链路里，模型会**先**吐 reasoning
     * **再**吐 content，所以在 peekTag() 之后读取即可拿到本步完整的思维链。
     */
    public prop reasoningContent: String {
        get() {
            reasoning.toString()
        }
    }

    /**
     * Used by AsyncChatResponseIterator
     */
    func next(): Option<AsyncChatChunk> {
        if (finished.load()) {
            return None
        }
        while (let Some(chunk) <- chunks.next()) {
            if (chunk.message.role != this.role) {
                throw ModelException("Inconsistent message role")
            }
            content.append(chunk.message.content)
            // Round3: 单独累积思维链，不覆盖 content
            if (let Some(r) <- chunk.message.reason) {
                reasoning.append(r)
            }
            if (chunk.done) {
                this._message = Message(
                    this.role,
                    content.toString(),
                    reason: if (reasoning.toString().isEmpty()) {
                        None
                    } else {
                        Some(reasoning.toString())
                    }
                )
                this._usage = chunk.usage
                finished.store(true)
                return None
            } else {
                return chunk
            }
        }
        throw UnsupportedException("Unreachable")
    }

    public func iter(withReason!: Bool = true): Iterator<String> {
        AsyncChatResponseIterator(this, withReason)
    }
}