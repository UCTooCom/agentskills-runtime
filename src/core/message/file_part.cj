/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.core.message

import magic.jsonable.{FromJsonValue, ToJsonValue, JsonUtils}

import std.collection.ArrayList
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}

/**
 * 文档 ingestion 的抽取结果（工程 `specs/multimodal-native-chat`，SDD R1 / T-MC-012）。
 *
 * 【为什么要有这个类型】deepseek 等多数 OpenAI 兼容网关**不接受文件块**，PPT/PDF 也
 * 不能直接当图像发给模型。所以文档必须先由后端抽取成「文本（+ 必要的页面图像）」，
 * 再作为普通 content part 喂给 LLM —— 即 SDD §5 的「默认策略 B」。`FilePart` 就是
 * 抽取结果的载体：一个文件可产生多个 part（例如 PDF 每页一块）。
 *
 * - `source`：来源标注，形如 `[PDF p.3]` / `[PPT slide 5]`，让模型回答时可引用出处（AC3）。
 * - `text`：该块抽取出的正文。
 * - `images`：可选，页面渲染图 / 图表截图（P2 的 slide→图像与 OCR 会用到）。
 */
public class FilePart <: ToString & FromJsonValue<FilePart> & ToJsonValue {
    public let source: String
    public let text: String
    public let images: ArrayList<String>

    public init(source: String, text: String, images!: ArrayList<String> = ArrayList<String>()) {
        this.source = source
        this.text = text
        this.images = images
    }

    override public func toString(): String {
        "[${source}] ${text}"
    }

    override public func toJsonValue(): JsonValue {
        let jo = JsonObject()
        jo.put("source", JsonString(source))
        jo.put("text", JsonString(text))
        if (images.size > 0) {
            let arr = JsonArray()
            for (img in images) {
                arr.add(JsonString(img))
            }
            jo.put("images", arr)
        }
        return jo
    }

    redef public static func fromJsonValue(json: JsonValue): FilePart {
        let imgs = ArrayList<String>()
        if (let Some(arr) <- JsonUtils.getJsonArray(json, "images")) {
            for (item in arr.getItems()) {
                if (let Some(s) <- JsonUtils.toString(item)) {
                    imgs.add(s)
                }
            }
        }
        FilePart(
            JsonUtils.getString(json, "source") ?? "",
            JsonUtils.getString(json, "text") ?? "",
            images: imgs
        )
    }
}
