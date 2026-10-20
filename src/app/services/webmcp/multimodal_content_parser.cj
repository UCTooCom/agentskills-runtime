/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.webmcp

import magic.core.agent.Attachment
import magic.log.LogUtils

import std.collection.ArrayList
import std.core.StringBuilder
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}

/**
 * 一条消息 content 的多模态解析结果（工程 `specs/multimodal-native-chat`，SDD R4 / T-MC-007）。
 *
 * 用可变 class 而非 struct：解析过程要逐块累加，struct 的 `let` 字段无法外部赋值
 * （仓颉 struct 限制），所以这里必须是 class。
 */
public class ParsedContent {
    /** 所有 `text` 块拼接出的纯文本（即原本「被拍平」的那部分，行为向后兼容）。 */
    public var text: String = ""

    /** 所有 `image_url` 块的 url（内联 dataURL 或 http URL）。 */
    public var images: ArrayList<String> = ArrayList<String>()

    /** 所有 `file` 块的附件（PDF/PPT/DOC…，待 ingestion 抽取）。 */
    public var files: ArrayList<Attachment> = ArrayList<Attachment>()

    /**
     * 被丢弃的附件说明（超量 / 超大）。
     *
     * 【为什么不静默丢弃】本工程最初的 bug 就是「非图片附件被静默丢弃」，
     * 用户以为传了、模型其实没收到。凡是丢弃都必须留痕，并回灌给用户消息，
     * 让模型能如实告知（SDD R5）。
     */
    public var notices: ArrayList<String> = ArrayList<String>()

    public func hasMultimodal(): Bool {
        this.images.size > 0 || this.files.size > 0
    }

    /**
     * 把丢弃说明渲染成一段可并入用户消息的文本；没有丢弃时返回空串。
     */
    public func renderNotices(): String {
        if (this.notices.size == 0) {
            return ""
        }
        let sb = StringBuilder()
        sb.append("\n\n<attachment_notices>\n")
        for (note in this.notices) {
            sb.append("- ")
            sb.append(note)
            sb.append("\n")
        }
        sb.append("</attachment_notices>")
        sb.toString()
    }
}

/**
 * WebMCP 入口的多模态 content 解析器。
 *
 * 【契约】见 SDD §4。content 既可能是 `string`（纯文本，旧链路），也可能是块数组：
 * - `{ type:"text", text }`
 * - `{ type:"image_url", filename, image_url:{ url } }` —— 与 OpenTiny 官方契约一致（AC6）
 * - `{ type:"file", file:{ filename, mimeType, data } }` —— 本工程自研扩展（官方仅支持图片）
 *
 * 另外**顺带**接受 AI-SDK 形状 `{ type:"image", image }`（旧链路/直连残留），
 * 但官方形状是主路径（SDD R4「以官方形状为主」）。
 */
public class MultimodalContentParser {
    /**
     * 单条消息最多带几张图。多数网关对单次请求的图片数与总 token 都有限额，
     * 超了不是「慢一点」而是整个请求 400，所以必须在入口就限住（RISK-4）。
     */
    private static let MAX_IMAGES: Int64 = 8
    /** 单张图片的 base64 字符数上限（约 5MB 原始字节） */
    private static let MAX_IMAGE_CHARS: Int64 = 5242880
    /** 单个文件的 base64 字符数上限（约 15MB 原始字节），超出说明不适合内联进对话 */
    private static let MAX_FILE_CHARS: Int64 = 20971520

    public static func parse(contentVal: JsonValue): ParsedContent {
        let result = ParsedContent()

        if (contentVal is JsonString) {
            result.text = contentVal.asString().getValue()
            return result
        }

        if (contentVal is JsonArray) {
            let arr = contentVal.asArray()
            let size = arr.size()
            var i = 0
            while (i < size) {
                let itemOpt = arr.get(i)
                if (let Some(item) <- itemOpt) {
                    parseBlock(item, result)
                }
                i = i + 1
            }
            if (result.hasMultimodal()) {
                LogUtils.info("WebMCP multimodal: parsed ${result.images.size} image(s), " +
                    "${result.files.size} file(s), text length=${result.text.size.toString()}")
            }
            return result
        }

        // 兜底：与历史行为完全一致（拍平成字符串），确保不认识的形态不回归
        result.text = contentVal.toString().replace("\"", "")
        result
    }

    private static func parseBlock(block: JsonValue, result: ParsedContent): Unit {
        if (!(block is JsonObject)) {
            return
        }
        let obj = block.asObject()
        let typeOpt = obj.get("type")
        if (typeOpt.isNone()) {
            return
        }
        let typeStr = strOf(typeOpt.getOrThrow())

        if (typeStr == "text") {
            match (obj.get("text")) {
                case Some(v) => result.text = result.text + strOf(v)
                case None => ()
            }
            return
        }

        if (typeStr == "image_url") {
            match (obj.get("image_url")) {
                case Some(v) =>
                    if (v is JsonString) {
                        addImage(result, v.asString().getValue())
                    } else if (v is JsonObject) {
                        match (v.asObject().get("url")) {
                            case Some(u) => addImage(result, strOf(u))
                            case None => ()
                        }
                    } else {
                        ()
                    }
                case None => ()
            }
            return
        }

        // AI-SDK 形状兼容：{ type:"image", image: dataURL }
        if (typeStr == "image") {
            match (obj.get("image")) {
                case Some(v) => addImage(result, strOf(v))
                case None => ()
            }
            return
        }

        if (typeStr == "file") {
            // 官方扩展形状：{ type:"file", file:{ filename, mimeType, data } }
            match (obj.get("file")) {
                case Some(v) =>
                    if (v is JsonObject) {
                        addFile(result, v.asObject())
                    } else {
                        ()
                    }
                // 也容忍扁平写法：filename/mimeType/data 直接挂在同一层
                case None => addFile(result, obj)
            }
        }
    }

    private static func addImage(result: ParsedContent, url: String): Unit {
        if (url.isEmpty()) {
            return
        }
        if (Int64(result.images.size) >= MAX_IMAGES) {
            LogUtils.warn("WebMCP multimodal: image count exceeds ${MAX_IMAGES}, dropped one")
            result.notices.add("图片数量超过上限 ${MAX_IMAGES} 张，超出的图片未发送给模型。")
            return
        }
        if (Int64(url.size) > MAX_IMAGE_CHARS) {
            LogUtils.warn("WebMCP multimodal: single image too large (${url.size} chars), dropped")
            result.notices.add("有一张图片体积过大（base64 ${url.size} 字符，上限 ${MAX_IMAGE_CHARS}），未发送给模型。")
            return
        }
        result.images.add(url)
    }

    private static func addFile(result: ParsedContent, obj: JsonObject): Unit {
        let name = match (obj.get("filename")) {
            case Some(v) => strOf(v)
            case None => "attachment"
        }
        let mime = match (obj.get("mimeType")) {
            case Some(v) => strOf(v)
            case None => ""
        }
        let data = match (obj.get("data")) {
            case Some(v) => strOf(v)
            case None => ""
        }
        if (data.isEmpty()) {
            LogUtils.warn("WebMCP multimodal: file block '${name}' has empty data, skipped")
            return
        }
        if (Int64(data.size) > MAX_FILE_CHARS) {
            LogUtils.warn("WebMCP multimodal: file '${name}' too large (${data.size} chars), skipped")
            result.notices.add("附件「${name}」体积过大（base64 ${data.size} 字符，上限 ${MAX_FILE_CHARS}），未抽取其内容。")
            return
        }
        result.files.add(Attachment(name, mime, data))
    }

    /** JsonValue → String：字符串取值，其它形态沿用历史「去引号」拍平法。 */
    private static func strOf(v: JsonValue): String {
        if (v is JsonString) {
            return v.asString().getValue()
        }
        v.toString().replace("\"", "")
    }
}
