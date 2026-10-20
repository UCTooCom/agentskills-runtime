/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal.builtin

import std.collection.ArrayList

import magic.plugin.multimodal.{DocumentParser, ParserDescriptor, ParserFormats,
    ParseRequest, ParseResult, ParseStatus, ParseLimits, ParserRegistry}

import magic.core.message.FilePart
import magic.log.LogUtils

/**
 * 宿主内置「零依赖参考解析器」（spec R5 / 架构调整 v2 说明）。
 *
 * 这些解析器把既有的自研抽取器（pdf_text / office_text / zip_lite / xml_text）包成
 * `DocumentParser` 契约实现，经 `ParserRegistry` 注册。它们是**首个参考实现**，与
 * 宿主调度内核解耦：将来 `doc-parser-plugins` 子系统（L2/L3 轨，安装期决定）可无缝替换，
 * 无需改动 host-attach-core 的调度逻辑。
 */

// ==================== 文本类（txt/md/json/csv/代码…） ====================

public class BuiltinTextParser <: DocumentParser {
    public func descriptor(): ParserDescriptor {
        let mime = ArrayList<String>()
        mime.add("text/*")
        mime.add("application/json")
        mime.add("application/xml")
        mime.add("application/x-yaml")
        mime.add("application/yaml")
        let ext = ArrayList<String>()
        for (e in ["txt", "md", "markdown", "json", "csv", "tsv", "yaml", "yml", "xml",
                   "html", "htm", "log", "sql", "ini", "toml", "properties", "js", "ts",
                   "tsx", "vue", "py", "java", "go", "rs", "c", "h", "cpp", "cj", "sh", "bat", "ps1"]) {
            ext.add("." + e)
        }
        ParserDescriptor("builtin.text", ParserFormats(mime, ext), 100, "L2", "1.0.0")
    }

    public func parse(request: ParseRequest): ParseResult {
        let raw = request.bytes
        if (raw.size == 0) {
            return emptyResult()
        }
        match (tryDecodeUtf8(raw)) {
            case Some(t) =>
                if (isMostlyPrintable(t)) {
                    let parts = ArrayList<FilePart>()
                    parts.add(FilePart(request.filename, truncate(t, request.limits.maxChars)))
                    return ParseResult(ParseStatus.Ok, parts, "", "builtin.text", "1.0.0")
                }
                return ParseResult(ParseStatus.Empty, ArrayList<FilePart>(), "binary content", "builtin.text", "1.0.0")
            case None =>
                return ParseResult(ParseStatus.Empty, ArrayList<FilePart>(), "not utf-8", "builtin.text", "1.0.0")
        }
    }

    private func emptyResult(): ParseResult {
        ParseResult(ParseStatus.Empty, ArrayList<FilePart>(), "empty", "builtin.text", "1.0.0")
    }

    private func tryDecodeUtf8(bytes: Array<Byte>): Option<String> {
        try {
            return Some(String.fromUtf8(bytes))
        } catch (_: Exception) {
            return None
        }
    }

    private func isMostlyPrintable(text: String): Bool {
        if (text.isEmpty()) {
            return false
        }
        let probe = if (text.size > 4096) { text[0..4096] } else { text }
        var printable = 0
        for (b in probe.toArray()) {
            let v = Int64(b)
            if (v == 9 || v == 10 || v == 13 || (v >= 32 && v < 127)) {
                printable = printable + 1
            }
        }
        printable * 100 / probe.toArray().size > 80
    }
}

// ==================== PDF ====================

public class BuiltinPdfParser <: DocumentParser {
    public func descriptor(): ParserDescriptor {
        let mime = ArrayList<String>()
        mime.add("application/pdf")
        let ext = ArrayList<String>()
        ext.add(".pdf")
        ParserDescriptor("builtin.pdf", ParserFormats(mime, ext), 100, "L2", "1.0.0")
    }

    public func parse(request: ParseRequest): ParseResult {
        let raw = request.bytes
        if (raw.size == 0) {
            return emptyResult()
        }
        let pages = PdfTextExtractor.extractPages(raw)
        if (pages.size == 0) {
            return emptyResult()
        }
        let parts = ArrayList<FilePart>()
        var used: Int64 = 0
        var index: Int64 = 1
        for (page in pages) {
            let text = page.trimAscii()
            if (!text.isEmpty() && used < request.limits.maxChars) {
                let chunk = truncate(text, request.limits.maxChars)
                parts.add(FilePart("${request.filename} [p.${index}]", chunk))
                used = used + Int64(chunk.toRuneArray().size)
            }
            index = index + 1
        }
        if (parts.size == 0) {
            return emptyResult()
        }
        ParseResult(ParseStatus.Ok, parts, "", "builtin.pdf", "1.0.0")
    }

    private func emptyResult(): ParseResult {
        ParseResult(ParseStatus.Empty, ArrayList<FilePart>(), "no readable content", "builtin.pdf", "1.0.0")
    }
}

// ==================== DOCX ====================

public class BuiltinDocxParser <: DocumentParser {
    public func descriptor(): ParserDescriptor {
        let mime = ArrayList<String>()
        mime.add("application/vnd.openxmlformats-officedocument.wordprocessingml.document")
        let ext = ArrayList<String>()
        ext.add(".docx")
        ext.add(".doc")
        ParserDescriptor("builtin.docx", ParserFormats(mime, ext), 100, "L2", "1.0.0")
    }

    public func parse(request: ParseRequest): ParseResult {
        let raw = request.bytes
        if (raw.size == 0) {
            return emptyResult()
        }
        let text = OfficeTextExtractor.extractDocx(raw)
        if (text.trimAscii().isEmpty()) {
            return emptyResult()
        }
        let parts = ArrayList<FilePart>()
        parts.add(FilePart(request.filename, truncate(text, request.limits.maxChars)))
        ParseResult(ParseStatus.Ok, parts, "", "builtin.docx", "1.0.0")
    }

    private func emptyResult(): ParseResult {
        ParseResult(ParseStatus.Empty, ArrayList<FilePart>(), "no readable content", "builtin.docx", "1.0.0")
    }
}

// ==================== PPTX ====================

public class BuiltinPptxParser <: DocumentParser {
    public func descriptor(): ParserDescriptor {
        let mime = ArrayList<String>()
        mime.add("application/vnd.openxmlformats-officedocument.presentationml.presentation")
        let ext = ArrayList<String>()
        ext.add(".pptx")
        ext.add(".ppt")
        ParserDescriptor("builtin.pptx", ParserFormats(mime, ext), 100, "L2", "1.0.0")
    }

    public func parse(request: ParseRequest): ParseResult {
        let raw = request.bytes
        if (raw.size == 0) {
            return emptyResult()
        }
        let slides = OfficeTextExtractor.extractPptxSlides(raw)
        if (slides.size == 0) {
            return emptyResult()
        }
        let parts = ArrayList<FilePart>()
        var used: Int64 = 0
        var index: Int64 = 1
        for (slide in slides) {
            let text = slide.trimAscii()
            if (!text.isEmpty() && used < request.limits.maxChars) {
                let chunk = truncate(text, request.limits.maxChars)
                parts.add(FilePart("${request.filename} [slide ${index}]", chunk))
                used = used + Int64(chunk.toRuneArray().size)
            }
            index = index + 1
        }
        if (parts.size == 0) {
            return emptyResult()
        }
        ParseResult(ParseStatus.Ok, parts, "", "builtin.pptx", "1.0.0")
    }

    private func emptyResult(): ParseResult {
        ParseResult(ParseStatus.Empty, ArrayList<FilePart>(), "no readable content", "builtin.pptx", "1.0.0")
    }
}

// ==================== 公共工具 + 注册入口 ====================

private func truncate(text: String, maxChars: Int64): String {
    let runes = text.toRuneArray()
    if (Int64(runes.size) <= maxChars) {
        return text
    }
    let cut = Array<Rune>(maxChars, { i => runes[i] })
    String(cut) + "\n…（内容过长，已截断至 ${maxChars} 字符）"
}

/**
 * 把全部内置参考解析器注册进注册表（幂等：重复调用按 parserId 覆盖）。
 * 由宿主在初始化期调用一次（见 WebMCPProtocol.init）。
 */
public func registerAllBuiltinParsers(registry: ParserRegistry): Unit {
    registry.register(BuiltinTextParser())
    registry.register(BuiltinPdfParser())
    registry.register(BuiltinDocxParser())
    registry.register(BuiltinPptxParser())
    LogUtils.info("[BuiltinParsers] registered 4 built-in reference parsers")
}
