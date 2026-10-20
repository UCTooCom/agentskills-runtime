/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal

import std.collection.ArrayList
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonArray}

import magic.core.message.FilePart

/**
 * 文档解析状态（契约 IF-01a / spec §6.3）。
 * - Ok：成功抽到内容
 * - Empty：解析器正常返回但读不到内容
 * - Error：解析器抛错或返回非法结构
 */
public enum ParseStatus {
    | Ok
    | Empty
    | Error
}

/**
 * 解析器能处理的格式：MIME 列表 + 扩展名列表（至少一项非空，spec §6.5）。
 */
public class ParserFormats {
    public var mimeTypes: ArrayList<String> = ArrayList<String>()
    public var extensions: ArrayList<String> = ArrayList<String>()
    public init() {}
    public init(mimeTypes: ArrayList<String>, extensions: ArrayList<String>) {
        this.mimeTypes = mimeTypes
        this.extensions = extensions
    }
}

/**
 * 解析器描述符（契约 IF-01a / spec §6.5）。注册进 `ParserRegistry` 后供命中与运维。
 */
public class ParserDescriptor {
    public let parserId: String
    public let formats: ParserFormats
    public let priority: Int64
    public let track: String
    public let version: String
    public let capabilities: ArrayList<String>
    public init(parserId: String, formats: ParserFormats, priority: Int64, track: String,
                version: String, capabilities!: ArrayList<String> = ArrayList<String>()) {
        this.parserId = parserId
        this.formats = formats
        this.priority = priority
        this.track = track
        this.version = version
        this.capabilities = capabilities
    }
}

/**
 * 解析约束（spec §6.2）。解析器必须自行遵守 maxChars / timeoutMs。
 */
public class ParseLimits {
    public let maxChars: Int64
    public let timeoutMs: Int64
    public init(maxChars: Int64, timeoutMs: Int64) {
        this.maxChars = maxChars
        this.timeoutMs = timeoutMs
    }
}

/**
 * 解析请求：宿主剥离 dataURL 前缀后下发的原始字节 + 约束（spec §6.2）。
 */
public class ParseRequest {
    public let filename: String
    public let mimeType: String
    public let bytes: Array<Byte>
    public let limits: ParseLimits
    public init(filename: String, mimeType: String, bytes: Array<Byte>, limits: ParseLimits) {
        this.filename = filename
        this.mimeType = mimeType
        this.bytes = bytes
        this.limits = limits
    }
}

/**
 * 解析结果（spec §6.3）。parts 为抽取出的 `FilePart`；status/error 用于溯源与降级判定。
 */
public class ParseResult {
    public let status: ParseStatus
    public let parts: ArrayList<FilePart>
    public let error: String
    public let parserId: String
    public let parserVersion: String
    public let costMs: Int64
    public init(status: ParseStatus, parts: ArrayList<FilePart>, error: String,
                parserId: String, parserVersion: String, costMs!: Int64 = 0) {
        this.status = status
        this.parts = parts
        this.error = error
        this.parserId = parserId
        this.parserVersion = parserVersion
        this.costMs = costMs
    }
}

/**
 * 文档解析器契约（IF-01a）。实现在插件侧（L2 进程内 / L3 进程隔离），宿主只消费此接口。
 * 注意：本接口实现绝不能抛未捕获异常——宿主靠 `status=Error` 做降级，崩溃由调度器边界兜底。
 */
public interface DocumentParser {
    func descriptor(): ParserDescriptor
    func parse(request: ParseRequest): ParseResult
}

/**
 * 单附件解析后的元数据（供落库与 `<attachment_notices>` 留痕；spec §6.4 / IF-07a）。
 */
public class AttachmentMeta {
    public let filename: String
    public let mimeType: String
    public let sizeBytes: Int64
    public let parserId: String
    public let status: String
    public let partCount: Int64
    public let notice: String
    public init(filename: String, mimeType: String, sizeBytes: Int64, parserId: String,
                status: String, partCount: Int64, notice: String) {
        this.filename = filename
        this.mimeType = mimeType
        this.sizeBytes = sizeBytes
        this.parserId = parserId
        this.status = status
        this.partCount = partCount
        this.notice = notice
    }
    public func toJsonValue(): JsonValue {
        let jo = JsonObject()
        jo.put("filename", JsonString(filename))
        jo.put("mimeType", JsonString(mimeType))
        jo.put("sizeBytes", JsonInt(sizeBytes))
        jo.put("parserId", JsonString(parserId))
        jo.put("status", JsonString(status))
        jo.put("partCount", JsonInt(partCount))
        jo.put("notice", JsonString(notice))
        jo
    }
}
