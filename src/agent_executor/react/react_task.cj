/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.agent_executor.react

import magic.agent_executor.common.{AgentTask, PromptBuilder}
import magic.core.*
import magic.core.message.{Message, MessageList, MessageRole, WithTag, Tag}
import magic.log.LogUtils
import magic.model.ModelUtils
import magic.parser.{TagStreamParser, ParserException}
import magic.utils.sleep2
import std.collection.ArrayList

protected class ReactTask <: AgentTask {
    /**
     * v15: Buffer to collect reasoning_content (思维链) from all ReAct steps
     * The LLM generates reasoning_content for each step, we collect all of them
     * and forward to the frontend for display via setAnswerReason
     */
    private let _reasoningBuffer = StringBuilder("")

    /**
     * v15: Get the collected reasoning content for forwarding to execution info
     */
    protected prop reasoningContent: String {
        get() { _reasoningBuffer.toString() }
    }

    /**
     * Round3: 当前这一步的异步响应，用于单独取 reasoning_content（思维链）。
     * 每步都会重建，配合 `_reasoningConsumed` 保证只回收集一次。
     */
    private var _asyncResp: Option<AsyncChatResponse> = None
    private var _reasoningConsumed = false

    protected init(agent: Agent, request: AgentRequest) {
        super(agent, request)

        PromptBuilder()
            .system(ReactPromptUtils.buildReactSystemPrompt(this))
            .tool(PromptBuilder.buildAgentToolsPrompt(this))
            .system(this.agent.systemPrompt)
            .retrieval(PromptBuilder.buildAgentRetrievalPrompt(this))
            .memory(PromptBuilder.buildAgentMemoryPrompt(this))
            .conversation(request.conversation, withStepMessage: true)
            .request(request)
            .fillTo(this)
    }

    /**
     * If the answer is generated, return its value;
     * otherwise, just add messages to the messageList
     */
    private func handleStep(step: ReactStep): Option<String> {
        LogUtils.info(this.agent.name, step.toString())
        match (step) {
            case ReactStep.Thought(thought) =>
                this.execution.addStep(MessageRole.Assistant, thought, Tag.Thought)
            case ReactStep.Action(tc) =>
                if (tc.thought != "") {
                    this.execution.addStep(MessageRole.Assistant, tc.thought, Tag.Thought)
                }
                // LLM may generate parallel tools to run, but we run them sequentially currently
                for (toolRequest in tc.requests) {
                    this.execution.addStep(MessageRole.Assistant, toolRequest.toJsonValue().toJsonString(), Tag.Action, toolRequest: toolRequest)
                    let observation = this.invokeTool(toolRequest)
                    this.execution.addStep(MessageRole.User, observation, Tag.Observation)
                    this.notify(Tag.Observation, observation)
                }
            case ReactStep.Answer(answer) =>
                if (answer.thought != "") {
                    this.execution.addStep(MessageRole.Assistant, answer.thought, Tag.Thought)
                }
                // v15: Forward collected reasoning_content to execution info
                if (_reasoningBuffer.size > 0) {
                    this.execution.setAnswerReason(_reasoningBuffer.toString())
                }
                return answer.content
            case ReactStep.Failure(failureInfo) =>
                match (failureInfo.level) {
                    case FailureLevel.Repairable =>
                        // If the model returns an empty reply, just retry;
                        // else, add hint messages to fix.
                        if (!failureInfo.message.isEmpty()) {
                            // Add the reply message to the messageList and fix the failure
                            this.execution.addMessage(Message.assistant(failureInfo.message))
                            this.execution.addMessage( // and add the repair message
                                Message.user("Output is invalid because ${failureInfo.reason}. ${failureInfo.suggestion}")
                            )
                        } else {
                            LogUtils.info(this.agent.name, "React backoff")
                            sleep2(1000) // Backoff when getting empty messages
                        }
                    case FailureLevel.Fatal =>
                        throw AgentExecutionException(failureInfo.reason)
                }
        }
        return None
    }

    private func notifyStep(step: ReactStep): Unit {
        match (step) {
            case Action(toolCall) =>
                if (!toolCall.thought.isEmpty()) {
                    this.notify(Tag.Thought, toolCall.thought)
                }
                // tool call is notified in its own event handler
            case Thought(thought) =>
                this.notify(Tag.Thought, thought)
            case Answer(answer) =>
                if (!answer.thought.isEmpty()) {
                    this.notify(Tag.Thought, answer.thought)
                }
                this.notify(Tag.Answer, answer.content)
            case Failure(_) => ()
        }
    }

    //------------------------------------------------------
    protected func runOnce(): Option<String> {
        LogUtils.info(this.agent.name, "Run Step")
        let step = try {
            // Add a hint message
            this.execution.addMessage(
                Message.system(REACT_STEP_PROMPT)
            )
            this.getNextReactStep()
        } finally {
            // Remove the hint message
            this.execution.removeLastMessage()
        }

        this.notifyStep(step)
        if (let Some(answer) <- handleStep(step)) {
            return answer
        } else {
            return None
        }
    }

    private func getNextReactStep(): ReactStep {
        // The LLM may generates [Observation] itself,
        // I.e., it may generate
        // [Thought] ... [Thought]
        // [Action] ... [/Action]
        // [Observation] ... [Observation],
        // so we truncate it with `stop` words.
        try {
            let chatResp = this.chatLLM(this.execution.messages, stop: [Tag.Observation.open])
            let msg = chatResp.message
            // v15: Collect reasoning_content (思维链) from each ReAct step
            if (let Some(r) <- msg.reason) {
                if (!r.isEmpty()) {
                    if (_reasoningBuffer.size > 0) {
                        _reasoningBuffer.append("\n\n")
                    }
                    _reasoningBuffer.append(r)
                }
            }
            return ReactStep.fromStr(msg.content)
        } catch (ex: Exception) {
            LogUtils.error(this.agent.name, ex.toString())
            return ReactStep.Failure(
                FailureInfo(
                    FailureLevel.Fatal,
                    message: "",
                    reason: "Fail to get chat model response",
                    suggestion: ""
                )
            )
        }
    }

    /**
     * Ch0 / 中断语义：标记当前 ReAct 循环已耗尽步数预算但未收敛。
     * 将原因写入共享的 AgentExecution，使同步/异步路径的响应对象都能反映。
     */
    public func markMaxStepsExhausted(): Unit {
        this.execution.setTerminationReason(AgentTerminationReason.MaxStepsExhausted)
    }

    /**
     * Summarize an answer according to the react execution history.
     **/
    protected func summarize(): String {
        let messages = MessageList(
            ReactPromptUtils.buildReactSummarizePrompt(this)
        )
        let chatResp = this.chatLLM(messages)
        let msg = chatResp.message
        // v15: Collect reasoning from summarize step
        if (let Some(r) <- msg.reason) {
            if (!r.isEmpty()) {
                if (_reasoningBuffer.size > 0) {
                    _reasoningBuffer.append("\n\n")
                }
                _reasoningBuffer.append(r)
                this.execution.setAnswerReason(_reasoningBuffer.toString())
            }
        }
        return Tag.extract(msg.content, Tag.Answer).getOrThrow({ =>
            AgentExecutionException("Chat model response has no answers")
        })
    }

    //-----------------------------------------------------------------------------------------
    // The following methods are used to implement asynchronous execution,
    // but these are outdated implementations with bugs (they may directly pass incorrect LLM outputs to verbose info).
    // These methods are currently not in use and are temporarily retained for reference.
    func asyncRunOnce(): Option<AsyncReactAnswer> {
        LogUtils.info(this.agent.name, "Run Step")
        // Add a hint message
        this.execution.addMessage(
            Message.system(REACT_STEP_PROMPT)
        )
        let asyncReactStep = this.getAsyncReactStep()
        // remove the hint message
        this.execution.removeLastMessage()
        try {
            let tag = asyncReactStep.peekTag()
            // Round3：推理模型的 reasoning 先于 content 到达，peek 后即可回收本步思维链
            this.collectAsyncReasoning()
            LogUtils.info(this.agent.name, "asyncRunOnce peek tag: ${tag}")
            if (tag == Tag.Thought || tag == Tag.Action) {
                let step = asyncReactStep.getStepOf(tag)
                this.notifyStep(step)
                this.handleStep(step)
                return None
            } else if (tag == Tag.Answer) {
                // Round2 护栏：先确认流里真的有 <answer> 开标签（必须在 getAsyncAnswer 前取，
                // 它内部会 removeTag(Tag.Answer) 抹掉开标签）。没有开标签 = 格式错误，
                // 属于 Repairable 失败，重试而不是把畸形输出当成最终答案终止循环。
                let hasAnswerOpenTag = asyncReactStep.hasAnswerOpenTag()
                let (thought, asyncAnswer) = asyncReactStep.getAsyncAnswer()
                if (!thought.trimAscii().isEmpty()) {
                    this.execution.addStep(MessageRole.Assistant, thought, Tag.Thought)
                }
                // 修复：检测 Answer 内嵌套 Action 的情况（异步路径）
                // LLM 可能生成 <answer>...<thinking>...</thinking><action>...</action></answer>
                // 此时需要优先解析为 Action，否则工具调用被忽略导致只思考一轮就停止
                var fullContent = StringBuilder()
                var chunks = ArrayList<String>()
                while (let Some(chunk) <- asyncAnswer.next()) {
                    fullContent.append(chunk)
                    chunks.add(chunk)
                }
                let answerStr = fullContent.toString()
                if (let Some(_) <- Tag.extract(answerStr, Tag.Action)) {
                    LogUtils.info("ReactStep: detected nested <action> inside <answer> (async path), parsing as Action")
                    let step = ReactStep.fromStr(answerStr)
                    this.notifyStep(step)
                    this.handleStep(step)
                    return None
                }

                // Round2：没有显式 <answer> 开标签 → 判定为格式错误，回灌修复消息后重试
                if (!hasAnswerOpenTag) {
                    LogUtils.info(this.agent.name,
                        "Answer without <answer> open tag, treating as repairable failure instead of final answer")
                    this.execution.addMessage(Message.assistant(answerStr))
                    this.execution.addMessage(
                        Message.user(
                            "Output is invalid because it does not start with ${Tag.Thought}, ${Tag.Action} or ${Tag.Answer}. "
                            + "Never write plain prose before the first tag and never put ${Tag.Thought} at the end. "
                            + "If the task is not finished, output ${Tag.Thought} followed by ${Tag.Action}. "
                            + "Only output ${Tag.Answer} when the task is fully finished."
                        )
                    )
                    return None
                }
                // v15：异步链路此前从不回传思维链，前端只能显示 "no reasoning_content"
                if (_reasoningBuffer.size > 0) {
                    this.execution.setAnswerReason(_reasoningBuffer.toString())
                }
                return AsyncReactAnswer(chunks)
            } else {
                throw UnsupportedException()
            }
        } catch (ex: ParserException) {
            // Add the repair message
            // Round2：把失败原因写进提示，让模型知道该改成什么，而不是笼统一句"语法不合法"
            LogUtils.info(this.agent.name, "Repairable parse failure: ${ex.reason}")
            // Round3：把模型自己那段不合规输出回灌给它，与同步路径 Repairable 处理对齐
            let badOutput = asyncReactStep.currentContent().trimAscii()
            if (!badOutput.isEmpty()) {
                this.execution.addMessage(Message.assistant(badOutput))
            }
            this.execution.addMessage(
                Message.system(
                    "Your last output was invalid: ${ex.reason}. "
                    + "You MUST start with ${Tag.Thought} or ${Tag.Action} "
                    + "(or a single ${Tag.Answer} if the task is fully done). "
                    + "Do NOT write plain prose or explanations before the tags, "
                    + "and do NOT put ${Tag.Thought} after your text."
                )
            )
            return None
        }
    }

    private func getAsyncReactStep(): AsyncReactStep {
        // The LLM may generates [Observation] itself,
        // I.e., it may generate
        // [Thought] ... [/Thought]
        // [Action] ... [/Action]
        // [Observation} ... [/Observation],
        // so we truncate it with `stop` words.
        let asyncChatResp = agent.model.asyncCreate(
            ChatRequest(this.execution.messages, stop: [Tag.Observation.open])
        )
        this._asyncResp = Some(asyncChatResp)
        this._reasoningConsumed = false
        // Round3 关键修复：这里必须 withReason: false。
        // withReason: true 时迭代器返回 `reason ?? content` —— 推理模型先吐的
        // reasoning_content（纯散文）会顶掉真正的 content，导致 ReAct 标签流里
        // 一个 `<thinking>/<action>/<answer>` 都看不到，只能反复重试到步数耗尽。
        // 思维链改由 collectAsyncReasoning() 单独回收。
        let parser = TagStreamParser(asyncChatResp.iter(withReason: false))
        return AsyncReactStep(parser)
    }

    /**
     * Round3: 回收本步的 reasoning_content（思维链）。
     *
     * 必须在 peekTag() 之后调用 —— 推理模型的 reasoning 先于 content 到达，
     * 此时才已完整累积。回收后写入 _reasoningBuffer，供 setAnswerReason 输出到前端。
     */
    private func collectAsyncReasoning(): Unit {
        if (this._reasoningConsumed) {
            return
        }
        this._reasoningConsumed = true
        if (let Some(resp) <- this._asyncResp) {
            let r = resp.reasoningContent.trimAscii()
            if (!r.isEmpty()) {
                LogUtils.info(this.agent.name, "collected reasoning_content for this step, size=${r.size}")
                if (_reasoningBuffer.size > 0) {
                    _reasoningBuffer.append("\n\n")
                }
                _reasoningBuffer.append(r)
            }
        }
    }

    /**
     * Summarize an answer according to the react execution history.
     **/
    func asyncSummarize(): AsyncReactAnswer {
        let asyncChatResp = agent.model.asyncCreate(
            ChatRequest(ReactPromptUtils.buildReactSummarizePrompt(this))
        )
        this._asyncResp = Some(asyncChatResp)
        this._reasoningConsumed = false
        // Round3：与 asyncRunOnce 保持一致，只把 content 交给标签解析器，
        // 否则推理模型的 reasoning 会顶掉真正的 <answer>。
        let parser = TagStreamParser(asyncChatResp.iter(withReason: false))
        let asyncReactStep = AsyncReactStep(parser)
        // Round2 兜底：summarize 是步数耗尽后的最后一道防线，它的输出同样可能不带 <answer>
        // 开标签（此时 currTag 会抛 ParserException）。这里先探测一次，
        // 拿不到合法 <answer> 就直接把已读内容原样返回，避免"跑满步数 + 兜底又抛异常"整条流中断。
        let tag = try {
            asyncReactStep.peekTag()
        } catch (ex: Exception) {
            LogUtils.info(this.agent.name, "asyncSummarize: fail to peek tag (${ex.message}), fallback to raw content")
            Tag.Fail
        }
        this.collectAsyncReasoning()
        if (_reasoningBuffer.size > 0) {
            this.execution.setAnswerReason(_reasoningBuffer.toString())
        }
        if (tag != Tag.Answer || !asyncReactStep.hasAnswerOpenTag()) {
            LogUtils.info(this.agent.name, "asyncSummarize: no explicit <answer> tag, returning raw content")
            let chunks = ArrayList<String>()
            // Round3 修复：旧实现只回传 parser.currContent —— 那时才读到第一个 chunk，
            // 前端于是只收到 "The user wants" 这种半句话。这里必须把剩余流读完。
            chunks.add(asyncReactStep.readAllRemaining())
            // AsyncReactAnswer 仅是内容迭代器，不带 terminationReason：
            // 中断原因已由 task.markMaxStepsExhausted() 写到共享 execution，
            // 外层 AsyncAgentResponse 通过 terminationReason getter 读取。
            return AsyncReactAnswer(chunks)
        }
        let (_, asyncAnswer) = asyncReactStep.getAsyncAnswer()
        return asyncAnswer
    }
}