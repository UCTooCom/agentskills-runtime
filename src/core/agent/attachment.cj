/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.core.agent

/**
 * 随聊天消息上传的附件（工程 `specs/multimodal-native-chat`，SDD R2 / T-MC-005）。
 *
 * 【与既有 ImportedFile 的区别】`magic.utils.ImportedFile` 是「用户在提问文本里用
 * `@path` 引用本地文件」时由 importer 工具读盘的产物；`Attachment` 是「用户在聊天框
 * 直接上传、内联在 content 块里」的附件，二者来源不同、生命周期不同，不复用。
 *
 * `data` 是 `data:<mime>;base64,...` 形式的内联 dataURL（SDD §4 契约），
 * 因此无需独立的上传接口，也意味着附件随会话生命周期存在、不做持久化（P2 才落库）。
 */
public class Attachment <: ToString {
    /** 原始文件名，用于来源标注与错误提示。 */
    public let filename: String

    /** MIME 类型，ingestion 据此分发到 PDF / PPTX / DOCX / 文本抽取器。 */
    public let mimeType: String

    /** 内联 base64 dataURL（含 `data:` 前缀）。 */
    public let data: String

    public init(filename: String, mimeType: String, data: String) {
        this.filename = filename
        this.mimeType = mimeType
        this.data = data
    }

    override public func toString(): String {
        "Attachment(${filename}, ${mimeType}, ${data.size} chars)"
    }

    /**
     * 从 dataURL 中剥离 `data:<mime>;base64,` 前缀，只留裸 base64。
     * 非 dataURL 形态（例如已是裸 base64 或 http URL）原样返回。
     */
    public func base64Payload(): String {
        // String.indexOf 返回 Option<Int64>，不是 -1（`match` 而非比较）。
        match (data.indexOf(",")) {
            case Some(i) =>
                let head = data[0..i]
                if (head.startsWith("data:")) {
                    data[i + 1..data.size]
                } else {
                    data
                }
            case None => data
        }
    }
}
