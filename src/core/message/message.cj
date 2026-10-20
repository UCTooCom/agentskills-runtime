/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.core.message

import magic.jsonable.{FromJsonValue, ToJsonValue, JsonUtils}

import std.collection.ArrayList
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonArray}

public class Message <: ToString & FromJsonValue<Message> & ToJsonValue {
    /**
     * Name of the message sender
     */
    public let name: String

    /**
     * Role of the message sender
     */
    public let role: MessageRole

    /**
     * Content of the message
     */
    public let content: String

    /**
     * Optional image of the message
     */
    public let image: Option<String> // url or base64

    /**
     * 多图（dataURL 或 http URL）。
     *
     * 工程 `specs/multimodal-native-chat`（SDD R1 / T-MC-004）：原生多模态要求一条消息
     * 可携带多个图片块。`image` 保留为「旧单图」字段以兼容既有调用方与已持久化的会话，
     * 新链路一律写 `images`；读取时二者取并集（见 `allImages()`），避免回归。
     */
    public let images: ArrayList<String>

    /**
     * 文档抽取结果（SDD R1 / T-MC-012，P1）。PPT/PDF/DOC 经 ingestion 抽取后的
     * 「文本 + 可选页面图像」块，每块自带来源标注（如 `[PDF p.3]`）。
     */
    public let fileParts: ArrayList<FilePart>

    /**
     * The reasoning content
     * A reason model, like deepseek-r1, may generate reasoning content
     */
    public let reason: Option<String>

    public init(
        role: MessageRole,
        content: String,
        name!: String = "",
        image!: Option<String> = None,
        reason!: Option<String> = None,
        images!: ArrayList<String> = ArrayList<String>(),
        fileParts!: ArrayList<FilePart> = ArrayList<FilePart>()) {
        this.name = name
        this.role = role
        this.content = content
        this.image = image
        this.reason = reason
        this.images = images
        this.fileParts = fileParts
    }

    /**
     * 本条消息携带的全部图片（旧单图字段 + 新的多图列表，去重保序）。
     *
     * 消费方（ChatModel 序列化、执行器组装）统一读这里，这样「只填了 image 的老调用方」
     * 和「只填了 images 的新调用方」都能被正确序列化，无需一次性改完所有调用点。
     */
    public func allImages(): ArrayList<String> {
        let out = ArrayList<String>()
        if (let Some(img) <- this.image) {
            if (!img.isEmpty()) {
                out.add(img)
            }
        }
        for (img in this.images) {
            if (!img.isEmpty() && !out.contains(img)) {
                out.add(img)
            }
        }
        out
    }

    override public func toString(): String {
        let reason = this.reason.map({ s => ">${s}<" }) ?? ""
        return "${role}: ${reason}${content}"
    }

    override public func toJsonValue(): JsonValue {
        let jo = JsonObject()
        jo.put("role", JsonString(role.toString()))
        jo.put("content", JsonString(content))
        if (this.name != "") {
            jo.put("name", JsonString(name))
        }
        if (let Some(img) <- this.image) {
            jo.put("image", JsonString(img))
        }
        if (this.images.size > 0) {
            let arr = JsonArray()
            for (img in this.images) {
                arr.add(JsonString(img))
            }
            jo.put("images", arr)
        }
        if (this.fileParts.size > 0) {
            let arr = JsonArray()
            for (fp in this.fileParts) {
                arr.add(fp.toJsonValue())
            }
            jo.put("file_parts", arr)
        }
        if (let Some(r) <- this.reason) {
            jo.put("reason", JsonString(r))
        }
        return jo
    }

    redef public static func fromJsonValue(json: JsonValue): Message {
        let images = ArrayList<String>()
        if (let Some(arr) <- JsonUtils.getJsonArray(json, "images")) {
            for (item in arr.getItems()) {
                if (let Some(s) <- JsonUtils.toString(item)) {
                    images.add(s)
                }
            }
        }
        let fileParts = ArrayList<FilePart>()
        if (let Some(arr) <- JsonUtils.getJsonArray(json, "file_parts")) {
            for (item in arr.getItems()) {
                fileParts.add(FilePart.fromJsonValue(item))
            }
        }
        return Message(
            MessageRole.fromStr(JsonUtils.getString(json, "role").getOrThrow()),
            JsonUtils.getString(json, "content") ?? "",
            name: JsonUtils.getString(json, "name") ?? "",
            image: JsonUtils.getString(json, "image"),
            reason: JsonUtils.getString(json, "reason"),
            images: images,
            fileParts: fileParts
        )
    }

    //---------------------------------------------------------------------
    // Builder methods
    //---------------------------------------------------------------------
    public static func system(content: String): Message {
        Message(MessageRole.System, content, name: "System")
    }

    public static func assistant(content: String, name!: String = "Assistant", reason!: Option<String> = None): Message {
        Message(MessageRole.Assistant, content, name: name, reason: reason)
    }

    public static func user(content: String,
                            image!: Option<String> = None,
                            images!: ArrayList<String> = ArrayList<String>(),
                            fileParts!: ArrayList<FilePart> = ArrayList<FilePart>()): Message {
        Message(MessageRole.User, content, name: "User", image: image, images: images,
            fileParts: fileParts)
    }
}