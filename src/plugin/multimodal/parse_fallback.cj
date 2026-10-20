/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal

import std.collection.ArrayList
import std.core.StringBuilder

import magic.core.message.FilePart

/**
 * 降级结果载体：解析文本块 + 对应的留痕元数据（spec §2「兜底块」）。
 * 兜底块必须含文件名、失败原因分类，绝不伪造内容（spec §5.2.3）。
 */
public class FallbackResult {
    public let parts: ArrayList<FilePart>
    public let meta: AttachmentMeta
    public init(parts: ArrayList<FilePart>, meta: AttachmentMeta) {
        this.parts = parts
        this.meta = meta
    }
}

/**
 * 无任何解析器可处理该格式（SC-04 / spec §5.2.3.1）。
 */
public func fallbackNoPlugin(filename: String, mimeType: String, sizeBytes: Int64): FallbackResult {
    let notice = "用户上传了文件「${filename}」（类型 ${mimeType}），但当前运行时未安装可解析该格式的解析插件，" +
        "无法读取其内容。请建议用户改用文本/代码文件，或把关键内容直接粘贴到对话中。"
    let parts = ArrayList<FilePart>()
    parts.add(FilePart(filename, "（附件 ${filename} 内容无法解析：未安装对应格式的解析插件。）"))
    let meta = AttachmentMeta(filename, mimeType, sizeBytes, "", "no_plugin", 1, notice)
    FallbackResult(parts, meta)
}

/**
 * 单附件原始字节超过上限（DFX 4.1.3，默认 10MB），拒绝并留痕，不下发解析。
 */
public func fallbackTooLarge(filename: String, sizeBytes: Int64): FallbackResult {
    let mb = (sizeBytes / 1048576).toString()
    let notice = "附件「${filename}」体积过大（约 ${mb}MB），超出单附件解析上限（10MB），未做内容解析。"
    let parts = ArrayList<FilePart>()
    parts.add(FilePart(filename, "（附件 ${filename} 体积过大，已跳过内容解析。）"))
    let meta = AttachmentMeta(filename, "", sizeBytes, "", "too_large", 1, notice)
    FallbackResult(parts, meta)
}

/**
 * dataURL / base64 为空或非法，解不出原始字节。
 */
public func fallbackUnsupported(filename: String, sizeBytes: Int64, reason: String): FallbackResult {
    let notice = "附件「${filename}」无法解码（${reason}），未做内容解析。"
    let parts = ArrayList<FilePart>()
    parts.add(FilePart(filename, "（附件 ${filename} 内容无法解码，已跳过。）"))
    let meta = AttachmentMeta(filename, "", sizeBytes, "", "unsupported", 1, notice)
    FallbackResult(parts, meta)
}

/**
 * 所有候选解析器尝试后仍读不到内容（SC-03 / spec §5.2.3.3）。
 */
public func fallbackParseFailed(filename: String, sizeBytes: Int64, notices: ArrayList<String>): FallbackResult {
    let sb = StringBuilder()
    sb.append("附件「${filename}」经所有可用解析器尝试后仍无法读取内容：")
    for (n in notices) {
        sb.append("；")
        sb.append(n)
    }
    let parts = ArrayList<FilePart>()
    parts.add(FilePart(filename, "（附件 ${filename} 内容解析失败，已跳过。具体原因：${sb.toString()}）"))
    let meta = AttachmentMeta(filename, "", sizeBytes, "", "parse_failed", 1, sb.toString())
    FallbackResult(parts, meta)
}
