/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal

import std.collection.ArrayList
import std.sync.{Mutex, AtomicBool}
import std.core.Duration
import std.core.StringBuilder
import stdx.encoding.base64.fromBase64String

import magic.core.agent.Attachment
import magic.core.message.FilePart
import magic.log.LogUtils

/**
 * 单附件的调度结果：解析出的 `FilePart` 列表 + 实际命中的解析器 + 留痕元数据。
 */
public class DispatchOutcome {
    public let parts: ArrayList<FilePart>
    public let usedParserId: String
    public let meta: AttachmentMeta
    public init(parts: ArrayList<FilePart>, usedParserId: String, meta: AttachmentMeta) {
        this.parts = parts
        this.usedParserId = usedParserId
        this.meta = meta
    }
}

/**
 * 跨线程结果兜底层：spawn 闭包不可捕获可变局部变量，用引用型 holder 传递结果。
 * 置于顶层（Cangjie 不允许在 class body 内嵌声明 class）。
 */
private class ParseResultCell {
    public var value: Option<ParseResult> = None
    public init() {}
}

/**
 * 解析调度器（spec §5.2）：命中 → 下发 → 超时(10s)/失败 → 次优 → 兜底。
 *
 * 它**不解析**任何格式，只通过 `ParserRegistry` 调度；所有失败路径都降级成告知性文本块，
 * 绝不抛异常、绝不令请求失败（DFX 4.2）。
 */
public class ParseDispatcher {
    private static let MAX_FILE_BYTES: Int64 = 10485760   // DFX 4.1.3 单附件原始字节上限 10MB
    private static let DEFAULT_TIMEOUT_MS: Int64 = 10000   // DFX 4.1.1 单附件解析总耗时上限 10s
    private static let MAX_TEXT_CHARS: Int64 = 100000      // DFX 4.1.4 单附件解析文本累计上限 10 万字符

    /** 便捷入口：仅取文本块（合并文本时使用）。 */
    public static func dispatch(attachment: Attachment): ArrayList<FilePart> {
        dispatchWithMeta(attachment).parts
    }

    /**
     * 完整入口：返回文本块 + 命中元数据。永不抛异常。
     */
    public static func dispatchWithMeta(attachment: Attachment): DispatchOutcome {
        let name = attachment.filename
        let registry = ParserRegistry.shared()

        // 1. 剥离 dataURL 前缀，解出原始字节
        let payload = attachment.base64Payload()
        let bytes = match (fromBase64String(payload)) {
            case Some(b) => b
            case None => Array<Byte>()
        }
        if (bytes.size == 0) {
            let r = fallbackUnsupported(name, 0, "dataURL/base64 为空或非法")
            return DispatchOutcome(r.parts, "decode_error", r.meta)
        }
        // 2. 体积门槛（DFX 4.1.3）
        if (bytes.size > MAX_FILE_BYTES) {
            let r = fallbackTooLarge(name, bytes.size)
            return DispatchOutcome(r.parts, "too_large", r.meta)
        }
        // 3. 解析器命中
        let candidates = registry.resolve(name, attachment.mimeType)
        if (candidates.size == 0) {
            let r = fallbackNoPlugin(name, attachment.mimeType, bytes.size)
            return DispatchOutcome(r.parts, "no_plugin", r.meta)
        }
        // 4. 依次尝试（首选 → 次优），全部失败转兜底
        var notices = ArrayList<String>()
        for (parser in candidates) {
            let desc = parser.descriptor()
            let resultOpt = runWithTimeout(parser, attachment, bytes)
            match (resultOpt) {
                case Some(result) =>
                    let ok = match (result.status) {
                        case ParseStatus.Ok => true
                        case _ => false
                    }
                    registry.report(desc.parserId, ok, result.costMs)
                    match (result.status) {
                        case ParseStatus.Ok =>
                            if (result.parts.size > 0) {
                                return DispatchOutcome(truncateParts(result.parts), desc.parserId,
                                    AttachmentMeta(name, attachment.mimeType, bytes.size, desc.parserId,
                                        "ok", result.parts.size, ""))
                            }
                            notices.add("解析器 ${desc.parserId} 未从该文件读到内容")
                        case ParseStatus.Empty =>
                            notices.add("解析器 ${desc.parserId} 返回空内容")
                        case ParseStatus.Error =>
                            LogUtils.warn("[ParseDispatcher] parser ${desc.parserId} error: ${result.error}")
                            notices.add("解析器 ${desc.parserId} 执行失败：${result.error}")
                    }
                case None =>
                    registry.report(desc.parserId, false, DEFAULT_TIMEOUT_MS)
                    LogUtils.warn("[ParseDispatcher] parser ${desc.parserId} timed out (${DEFAULT_TIMEOUT_MS}ms)")
                    notices.add("解析器 ${desc.parserId} 解析超时（>${DEFAULT_TIMEOUT_MS}ms）")
            }
        }
        let r = fallbackParseFailed(name, bytes.size, notices)
        DispatchOutcome(r.parts, "all_failed", r.meta)
    }

    /**
     * 带 10s 超时的解析调用。用 spawn 工作协程 + holder + AtomicBool 标志 + 轮询实现，
     * 不依赖 Future.cancel：超时后直接忽略工作协程的结果并转次优（解析器是黑盒，无法注入取消）。
     */
    private static func runWithTimeout(parser: DocumentParser, attachment: Attachment,
                                       bytes: Array<Byte>): Option<ParseResult> {
        let req = ParseRequest(attachment.filename, attachment.mimeType, bytes,
            ParseLimits(MAX_TEXT_CHARS, DEFAULT_TIMEOUT_MS))
        let mutex = Mutex()
        let cell = ParseResultCell()
        let done = AtomicBool(false)
        spawn {
            try {
                let r = parser.parse(req)
                synchronized(mutex) { cell.value = Some(r) }
                done.store(true)
            } catch (e: Exception) {
                LogUtils.warn("[ParseDispatcher] parser threw: ${e.message}")
                done.store(true)
            }
        }
        var waited: Int64 = 0
        let step: Int64 = 50
        while (!done.load() && waited < DEFAULT_TIMEOUT_MS) {
            sleep(Duration.millisecond * step)
            waited = waited + step
        }
        synchronized(mutex) { cell.value }
    }

    private static func truncateParts(parts: ArrayList<FilePart>): ArrayList<FilePart> {
        let out = ArrayList<FilePart>()
        for (p in parts) {
            out.add(FilePart(p.source, truncate(p.text), images: p.images))
        }
        out
    }

    /** 按 Rune 截断：字节切片会切断多字节字符导致抛异常（见 char_delta_splitter 注释）。 */
    private static func truncate(text: String): String {
        let runes = text.toRuneArray()
        if (Int64(runes.size) <= MAX_TEXT_CHARS) {
            return text
        }
        let cut = Array<Rune>(MAX_TEXT_CHARS, { i => runes[i] })
        String(cut) + "\n…（内容过长，已截断至 ${MAX_TEXT_CHARS} 字符）"
    }
}
