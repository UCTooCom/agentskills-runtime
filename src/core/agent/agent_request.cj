/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.core.agent

import magic.core.message.{Conversation, MessageList}
import magic.core.interaction.EventStream
import magic.jsonable.TypeSchema
import magic.utils.ImportedFile

import std.collection.{ArrayList, HashMap}
import std.fs.Path

/**
 * The execution request to an agent executor
 * This type encodes the agent communication protocol
 */
public class AgentRequest {
    /**
     * The current user question
     */
    public let question: String

    /**
     * The user input question for using VLM
     */
    public let image: Option<String>

    /**
     * 随消息上传的多张图片（dataURL 或 http URL）。
     *
     * 工程 `specs/multimodal-native-chat`（SDD R2 / T-MC-005）：`image` 只表达「单图」，
     * 撑不住原生多模态（一次上传多张）。新增 `images` 承载多图；`image` 保留以兼容
     * 既有调用方，消费方统一读 `allImages()`（两者并集）。
     */
    public let images: ArrayList<String>

    /**
     * 随消息上传的文档附件（PDF/PPT/DOC 等，内联 base64）。
     * 由后端 ingestion 抽取成文本后再喂给模型 —— 多数网关不接受文件块（SDD §5 策略 B）。
     */
    public let files: ArrayList<Attachment>

    /**
     * Conversation between the user and agent
     */
    public let conversation: Option<Conversation>

    /**
     * Dump internal execution information
     */
    public let verbose: Bool

    /**
     * The maximum number of tools that can be used when enable tool filter
     */
    public let maxTool: Int64

    /**
     * 长程任务（LRT）宿主回合标记。
     *
     * 非空表示本次执行来自 LRT 的一个回合（`LrtHostExecutor.runRound`），
     * 为空表示普通对话/聊天请求。执行器据此区分失败文案：
     * - 任务回合 → 「任务执行异常中断（第 N 步）…」（保留产物/输出目录提示）
     * - 普通对话 → 「本次回复失败…」（2026-09-23 定夺：普通聊天套用任务中断模板，
     *   会让用户误以为系统在自动续跑遗留的 agent_tasks）
     */
    public let lrtTaskId: Option<String>

    /**
     * 本轮附件的解析摘要（工程 `specs/multimodal-native-chat`，host-attach-core）。
     * 由 WebMCPProtocol 在调度完附件解析后填充，随请求透传给持久化层，
     * 用于把附件元数据写入 `agent_messages.attachments` 列。无附件时为 None。
     */
    public let attachmentSummary: Option<AttachmentSummary>

    public init(question: String,
                image!: Option<String> = None,
                conversation!: Option<Conversation> = None,
                verbose!: Bool = false,
                maxTool!: Int64 = 10,
                lrtTaskId!: Option<String> = None,
                images!: ArrayList<String> = ArrayList<String>(),
                files!: ArrayList<Attachment> = ArrayList<Attachment>(),
                attachmentSummary!: Option<AttachmentSummary> = None<AttachmentSummary>) {
        this.question = question
        this.image = image
        this.conversation = conversation
        this.verbose = verbose
        this.maxTool = maxTool
        this.lrtTaskId = lrtTaskId
        this.images = images
        this.files = files
        this.attachmentSummary = attachmentSummary
    }

    /**
     * 全部图片（旧单图字段 + 新多图列表，去重保序）。
     * 消费方统一读这里，老调用方填 `image` 也能正确走到多模态序列化。
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

    //-----------------------------------------------------------------
    // The following fields are used internally by the agent executor
    //-----------------------------------------------------------------

    /**
     * Subagent may need to access the previous execution context
     */
    protected var parentContext: Option<MessageList> = None

    /**
     * Subagents may inherit the event stream of the parent agent
     */
    protected var eventStream: Option<EventStream> = None

     /**
      * Users can register event handlers for each request
      */
    protected var eventHandlerManager: Option<Object> = None // Avoid circular import

    /**
     * Output schema for structured output
     */
    protected var outputSchema: Option<TypeSchema> = None

    /**
     * Imported files from the request question
     * Processed by the importer utility
     */
    protected var importedFiles = ArrayList<ImportedFile>()

    /**
     * Whether the request has been dispatched to a subagent
     */
    protected var dispatchToSubagent : Bool = false

    /**
     * Clone the request with some fields changed
     */
    protected func clone(question!: Option<String> = None,
                         image!: Option<String> = None,
                         conversation!: Option<Conversation> = None,
                         verbose!: Option<Bool> = None,
                         maxTool!: Option<Int64> = None,
                         lrtTaskId!: Option<String> = None,
                         images!: Option<ArrayList<String>> = None,
                         files!: Option<ArrayList<Attachment>> = None,
                         attachmentSummary!: Option<AttachmentSummary> = None): AgentRequest {
        let req = AgentRequest(
            question ?? this.question,
            image: image ?? this.image,
            conversation: conversation ?? this.conversation,
            verbose: verbose ?? this.verbose,
            maxTool: maxTool ?? this.maxTool,
            lrtTaskId: lrtTaskId ?? this.lrtTaskId,
            images: images ?? this.images,
            files: files ?? this.files,
            attachmentSummary: attachmentSummary ?? this.attachmentSummary
        )

        req.parentContext = this.parentContext
        req.eventStream = this.eventStream
        req.eventHandlerManager = this.eventHandlerManager
        req.outputSchema = this.outputSchema
        req.importedFiles = this.importedFiles
        req.dispatchToSubagent = this.dispatchToSubagent
        // lrtTaskId 已在构造器里透传（public let，不可再赋值）
        return req
    }
}
