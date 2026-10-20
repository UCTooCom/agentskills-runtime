/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal.builtin

import std.collection.ArrayList
import std.core.StringBuilder

/**
 * DOCX / PPTX 文本抽取（工程 `specs/multimodal-native-chat`，T-MC-013 的后半段）。
 *
 * 两者都是「ZIP 容器 + OOXML」：
 * - DOCX 正文在 word/document.xml，文本节点是 w:t，段落边界是 w:p，软换行是 w:br。
 * - PPTX 每页一张 ppt/slides/slideN.xml，文本节点是 a:t，段落边界是 a:p。
 *
 * 因此解压靠 ZipLite，抽文本靠 XmlTextExtractor，本文件只负责「路径 + 标签」的映射
 * 与结果整理。任何一步失败都返回空串 / 空列表，由 DocumentIngestion 转兜底块。
 */
public class OfficeTextExtractor {
    /** 单个 XML 解压上限（32MB），防御解压炸弹 */
    private static let MAX_XML_BYTES: Int64 = 33554432

    /**
     * 抽 DOCX 正文文本。取不到就返回空串。
     */
    public static func extractDocx(bytes: Array<Byte>): String {
        let entries = ZipLite.entries(bytes)
        match (ZipLite.find(entries, "word/document.xml")) {
            case Some(entry) =>
                let xml = decodeXml(ZipLite.read(bytes, entry, maxOutputSize: MAX_XML_BYTES))
                let breaks = ["w:p", "w:br"]
                return normalize(XmlTextExtractor.extract(xml, "w:t", breaks))
            case None => ()
        }
        ""
    }

    /**
     * 抽 PPTX 每页文本，按 slide 编号升序返回（与文件名一一对应，缺失的页跳过）。
     *
     * 【为什么按编号遍历而不是排序】PPTX 的 slideN.xml 编号连续且无前导零，
     * 直接按 1..N 查表即可天然得到正确顺序，避免引入字符串比较排序的实现风险。
     */
    public static func extractPptxSlides(bytes: Array<Byte>): ArrayList<String> {
        let result = ArrayList<String>()
        let entries = ZipLite.entries(bytes)
        var slideCount: Int64 = 0
        for (entry in entries) {
            if (entry.name.startsWith("ppt/slides/slide") && entry.name.endsWith(".xml")) {
                slideCount++
            }
        }
        if (slideCount == 0) {
            return result
        }
        // 上限放宽一些：编号不连续（有删页）时仍能覆盖到最后一页。
        let limit = slideCount + 64
        var idx: Int64 = 1
        while (idx <= limit) {
            let name = "ppt/slides/slide${idx}.xml"
            match (ZipLite.find(entries, name)) {
                case Some(entry) =>
                    let xml = decodeXml(ZipLite.read(bytes, entry, maxOutputSize: MAX_XML_BYTES))
                    let breaks = ["a:p", "a:br"]
                    result.add(normalize(XmlTextExtractor.extract(xml, "a:t", breaks)))
                case None => ()
            }
            idx++
        }
        result
    }

    // ==================== 内部工具 ====================

    private static func decodeXml(bytes: Array<Byte>): String {
        if (bytes.size == 0) {
            return ""
        }
        try {
            String.fromUtf8(bytes)
        } catch (_: Exception) {
            unsafe { String.fromUtf8Unchecked(bytes) }
        }
    }

    /**
     * 整理空白：逐行 trimAscii，连续空行压成一个，去掉首尾空行。
     * OOXML 的缩进会让原文带上大量无意义空白，不整理会白白吃掉上下文。
     */
    private static func normalize(text: String): String {
        let lines = text.split("\n")
        let kept = ArrayList<String>()
        var blank: Int64 = 0
        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.isEmpty()) {
                blank++
                if (blank <= 1) {
                    kept.add("")
                }
            } else {
                blank = 0
                kept.add(trimmed)
            }
        }
        String.join(kept.toArray(), delimiter: "\n").trimAscii()
    }
}
