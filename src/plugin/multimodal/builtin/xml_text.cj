/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.multimodal.builtin

import std.core.StringBuilder

/**
 * 从 OOXML 的 XML 里按标签名抽文本。
 *
 * 【为什么不用通用 XML 解析器】这里只要「取出若干指定标签的正文」，输入是受控的 OOXML
 * 片段；自写扫描器既不引入新的 XML 依赖，也不会因为 XML 声明、命名空间前缀不统一、
 * 个别非法实体而整份失败。
 *
 * 【为什么按 Rune 扫描】标签名是 ASCII，正文可能是中文（多字节）。按 Rune 遍历既不会
 * 截断字符，也不必关心 String 字节下标与字符边界的关系。
 */
public class XmlTextExtractor {

    /**
     * @param xml      待扫描的 XML 文本
     * @param textTag  承载正文的标签名，如 w:t（DOCX 段落文本）/ a:t（PPTX 文本）
     * @param breakTags 表示「此处换行」的标签名，如 w:p / w:br / a:p / a:br。
     *                  只在闭合标签或自闭合标签上生效，避免开闭各插一次空行。
     */
    public static func extract(xml: String, textTag: String, breakTags: Array<String>): String {
        let rs = xml.toRuneArray()
        let n = Int64(rs.size)
        let out = StringBuilder()
        var inText = false
        var i: Int64 = 0
        while (i < n) {
            if (rs[i] == r'<') {
                var j = i + 1
                while (j < n && rs[j] != r'>') {
                    j++
                }
                if (j >= n) {
                    break
                }
                let tag = runesToString(rs, i + 1, j)
                i = j + 1
                let isClosing = tag.startsWith("/")
                let selfClose = tag.endsWith("/")
                let core = tagCore(tag)
                if (core == textTag) {
                    if (isClosing || selfClose) {
                        inText = false
                    } else {
                        inText = true
                    }
                } else if (isClosing || selfClose) {
                    for (bt in breakTags) {
                        if (core == bt) {
                            out.append("\n")
                            break
                        }
                    }
                }
            } else {
                if (inText) {
                    out.append(rs[i].toString())
                }
                i++
            }
        }
        decodeEntities(out.toString())
    }

    /**
     * 只解 OOXML 真正会用到的五个预定义实体。顺序重要：&amp; 必须最后解，
     * 否则会把 &amp;lt; 二次解成 <。
     */
    public static func decodeEntities(text: String): String {
        text.replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&apos;", "'")
            .replace("&amp;", "&")
    }

    // ==================== 内部工具 ====================

    private static func runesToString(rs: Array<Rune>, start: Int64, end: Int64): String {
        let len = end - start
        if (len <= 0) {
            return ""
        }
        let buf = Array<Rune>(len, repeat: r'\0')
        var k: Int64 = 0
        while (k < len) {
            buf[k] = rs[start + k]
            k++
        }
        String(buf)
    }

    /**
     * 取标签名：去掉开头的斜杠（闭合）、结尾的斜杠（自闭合）、首尾空白，
     * 并截断到第一个空白（属性之前）。
     */
    private static func tagCore(tag: String): String {
        let rs = tag.toRuneArray()
        let n = Int64(rs.size)
        var start: Int64 = 0
        var end: Int64 = n
        if (start < end && rs[start] == r'/') {
            start++
        }
        if (end > start && rs[end - 1] == r'/') {
            end--
        }
        while (start < end && isSpaceRune(rs[start])) {
            start++
        }
        var k = start
        while (k < end && !isSpaceRune(rs[k])) {
            k++
        }
        runesToString(rs, start, k)
    }

    private static func isSpaceRune(r: Rune): Bool {
        r == r' ' || r == r'\t' || r == r'\n' || r == r'\r'
    }
}
