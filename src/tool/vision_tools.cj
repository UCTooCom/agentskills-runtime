/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import magic.config.Config
import magic.core.message.Message
import magic.core.model.ChatRequest
import magic.core.tool.{ToolException, ToolParameter, ToolResponse}
import magic.jsonable.TypeSchema
import magic.log.LogUtils
import magic.model.ModelManager
import magic.utils.imageFileToBase64
import std.collection.HashMap
import std.fs.exists
import stdx.encoding.json.{JsonValue, JsonObject, JsonString}

/**
 * 图片理解工具（vision 直传）。
 *
 * ## 为什么需要它
 *
 * 运行时连接的模型（如 deepseek-flash）本身是**原生多模态**的，
 * 传输层也早已具备能力：`core/message/message.cj` 的 `Message.image`
 * 会被 `model/openai/chat.cj` 组装成 `image_url` content part 发给模型。
 * 但此前**没有任何工具能把一张图片塞进 `Message.image`**——`image` 只能来自
 * 入口 `AgentRequest.image`。于是 agent 抓到图片版资料（扫描件/截图/题图）时，
 * 只能干瞪眼或被迫去找并不存在的 OCR 模块，白白烧掉大量推理步数。
 *
 * 本工具补的就是这一层：**把图片送进模型，把模型看到的内容以文字返回**。
 * 有了它，非文本载体（图片/PDF 扫描件）应当**直接走视觉理解**，而不是降级 OCR。
 *
 * ## 用法
 *
 * - `path`：本地图片路径（png/jpg/jpeg/webp/gif/bmp）→ 读文件转 base64 data URL
 * - `url` ：远程图片直链 → 直接交给模型（省去下载）
 * - 二者必填其一，同时给出时以 `path` 为准
 */
public class ImageUnderstandTool <: AbsTool {
    public static let NAME = "image_understand"

    public static let DESC = """
    Understand an image with the connected multimodal model (vision).
    Reads a local image file (or a remote image URL) and asks the model to
    describe / transcribe / extract information from it.
    Use this when content is only available as an image: scanned documents,
    screenshots, exam papers, charts, photos of text.
    Prefer this over OCR - the model understands images natively.
    Returns the model's textual answer about the image.
    """

    /// 未显式给 question 时的默认提问：偏向"忠实转录"，避免模型自由发挥
    public static let DEFAULT_QUESTION =
        "请仔细阅读这张图片，完整、忠实地输出你看到的内容。若图片中包含文字/公式，请逐字转录，保留原有结构、标点与数学符号，不要改写、不要总结、不要遗漏。"

    /// 图片理解的 system 提示词：强调"只依据图片，不臆测"
    public static let SYSTEM_PROMPT = """
    你是一个高精度的图片内容识别引擎。请严格依据图片实际内容作答。
    规则：
    1. 只输出图片中确实存在的内容，绝不臆测、绝不补充外部知识。
    2. 若含文字/公式，逐字忠实转录，保留原有排版结构与数学符号。
    3. 若图片模糊或某部分无法辨认，明确标注「[无法辨认]」，不要编造。
    4. 除转录内容外，不要添加任何评价、解释或客套话。
    """

    /// base64 体积保护（字符数）。约 10MB，超过则需先裁剪/降采样
    public static let MAX_IMAGE_CHARS: Int64 = 10 * 1024 * 1024

    public init() {
        super()
        _extra = HashMap([
            ("filterable", "true"),
            ("terminal", "false"),
            ("compactable", "true")
        ])
    }

    public prop name: String {
        get() { ImageUnderstandTool.NAME }
    }

    public prop description: String {
        get() { ImageUnderstandTool.DESC }
    }

    public prop parameters: Array<ToolParameter> {
        get() {
            [
                ToolParameter("path", "Local image file path (png/jpg/jpeg/webp/gif/bmp). Required unless 'url' is given.", TypeSchema.Str),
                ToolParameter("url", "Remote image URL. Used when the image is only available online.", TypeSchema.Str),
                ToolParameter("question", "What to extract from the image. Defaults to faithful full transcription.", TypeSchema.Str),
                ToolParameter("model", "Optional model name override (default: the runtime's configured model).", TypeSchema.Str)
            ]
        }
    }

    public prop retType: TypeSchema {
        get() { TypeSchema.Str }
    }

    public prop examples: Array<String> {
        get() {
            [
                """
                {
                  "path": "D:/tmp/sx01.png",
                  "question": "请完整输出图片中的数学题题干原文，保留所有公式与符号"
                }
                """,
                """
                {
                  "url": "https://example.com/paper.png",
                  "question": "Transcribe all text in this image"
                }
                """
            ]
        }
    }

    override public func invoke(args: HashMap<String, JsonValue>): ToolResponse {
        let path = ImageUnderstandTool.extractString(args, "path")
        let url = ImageUnderstandTool.extractString(args, "url")
        let modelOverride = ImageUnderstandTool.extractString(args, "model")
        var question = ImageUnderstandTool.extractString(args, "question")
        if (question.isEmpty()) {
            question = ImageUnderstandTool.DEFAULT_QUESTION
        }

        // 1) 解析图片来源：本地文件 → base64 data URL；否则用远程直链
        var imageRef = ""
        var source = ""
        if (!path.isEmpty()) {
            if (!exists(path)) {
                throw ToolException("Image file not found: ${path}")
            }
            let dataUrl = imageFileToBase64(path, head: true)
            if (dataUrl.size > ImageUnderstandTool.MAX_IMAGE_CHARS) {
                throw ToolException(
                    "Image too large after base64 encoding (${dataUrl.size} chars > ${ImageUnderstandTool.MAX_IMAGE_CHARS}). " +
                    "Please downscale the image or crop to the relevant region first.")
            }
            imageRef = dataUrl
            source = path
        } else if (!url.isEmpty()) {
            imageRef = url
            source = url
        } else {
            throw ToolException("Parameter 'path' or 'url' is required for image_understand")
        }

        let modelName = if (modelOverride.isEmpty()) { Config.MODEL_NAME } else { modelOverride }

        LogUtils.info("[ImageUnderstandTool] Understanding image: ${source} (model=${modelName}, ${imageRef.size} chars)")

        try {
            // 2) 走已有的 Message.image 链路：Message.user(content, image:) 
            //    会被 openai chat 组装成 image_url content part 发给模型
            let model = ModelManager.createChatModel(modelName)
            let answer = model.create(
                ChatRequest([
                    Message.system(ImageUnderstandTool.SYSTEM_PROMPT),
                    Message.user(question, image: Some(imageRef))
                ])
            ).message.content

            let response = JsonObject()
            response.put("success", JsonString("true"))
            response.put("source", JsonString(source))
            response.put("model", JsonString(modelName))
            response.put("question", JsonString(question))
            response.put("content", JsonString(answer))
            return ToolResponse(response.toJsonString())
        } catch (ex: Exception) {
            LogUtils.error("[ImageUnderstandTool] Failed to understand image ${source}: ${ex.message}")
            throw ToolException("Failed to understand image: ${ex.message}")
        }
    }

    public static func extractString(args: HashMap<String, JsonValue>, key: String): String {
        if (let Some(value) <- args.get(key)) {
            match (value) {
                case jStr: JsonString =>
                    return jStr.getValue()
                case _ =>
                    let strValue = value.toString()
                    if (strValue.startsWith("\"") && strValue.endsWith("\"")) {
                        return strValue[1..(strValue.size - 1)]
                    }
                    return strValue
            }
        }
        return ""
    }
}
