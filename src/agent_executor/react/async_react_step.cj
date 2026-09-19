/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.agent_executor.react

import magic.core.*
import magic.core.message.{Message, MessageList, Tag, WithTag}
import magic.log.LogUtils
import magic.model.ModelUtils
import magic.utils.sleep2
import magic.parser.{TagStreamParser, ParserException}

import std.collection.{ArrayList, map, collectArray}

class AsyncReactAnswer <: Iterator<String> {
    private var finished = false
    private let parser: Option<TagStreamParser>
    private let collectedChunks: ArrayList<String>
    private var chunkIndex: Int64 = 0

    init(parser: TagStreamParser) {
        this.parser = Some(parser)
        this.collectedChunks = ArrayList<String>()
        if ((parser.currTag ?? Tag.Fail) != Tag.Answer) {
            throw AgentExecutionException("Invalid async react ${Tag.Answer}. Content: ${parser.currContent}")
        }
        // Remove the prefix of tag
        parser.removeTag(Tag.Answer)
    }

    // 从已收集的 chunks 创建实例（用于嵌套 Action 检测后返回 answer 内容）
    init(chunks: ArrayList<String>) {
        this.parser = None
        this.collectedChunks = chunks
    }

    override public func next(): Option<String> {
        if (finished) {
            return None
        }
        match (parser) {
            case Some(p) =>
                if (let Some((content, _isClosed)) <- p.readContentUntilClosed(Tag.Answer)) {
                    finished = _isClosed
                    return content
                }
                return None
            case None =>
                if (chunkIndex < collectedChunks.size) {
                    let chunk = collectedChunks[chunkIndex]
                    chunkIndex += 1
                    return chunk
                } else {
                    finished = true
                    return None
                }
        }
    }
}

class AsyncReactStep {
    AsyncReactStep(
        let parser: TagStreamParser
    ) { }

    // Each react step has [Thought], so we parse thoughts and save them
    private let thoughts = ArrayList<String>()

    private func readThoughts(): Unit {
        while (let Some(tag) <- this.parser.currTag) {
            if (tag == Tag.Thought) {
                thoughts.add(this.parser.readTagAndContent(Tag.Thought))
            } else if (tag == Tag.Action || tag == Tag.Answer) {
                break
            } else {
                throw ParserException("Invalid react tag `${tag}`")
            }
        }
    }

   func peekTag(): Tag {
        this.readThoughts()
        // If there are no tags, this step is a single [Thought]?
        if (let Some(tag) <- this.parser.currTag) {
            return tag
        } else {
            return Tag.Thought
        }
    }

    func getStepOf(tag: Tag): ReactStep {
        try {
            let thought = String.join(this.thoughts.toArray(), delimiter: "\n")
            let action = if (tag == Tag.Thought) {
                ""
            } else if (tag == Tag.Action) {
                this.parser.readTagAndContent(Tag.Action)
            } else {
                throw AgentExecutionException("Unreachable")
            }
            let content = "${thought}\n${action}"
            LogUtils.debug("React action content: ${content}")
            return ReactStep.fromStr(content)
        } catch (ex: Exception) {
            return ReactStep.Failure(
                FailureInfo(
                    FailureLevel.Fatal,
                    message: "",
                    reason: ex.toString(),
                    suggestion: ""
                )
            )
        }
    }

    /**
     * Round2 新增：判断当前流是否**真的**以显式的 `<answer>` 开标签开头。
     *
     * 必须在 getAsyncAnswer() 之前调用 —— AsyncReactAnswer 构造时会 removeTag(Tag.Answer)
     * 把开标签抹掉，之后再判断就永远拿不到真实结果了。
     *
     * 用途：区分「模型确实给出了最终答案」与「解析器兜底出来的假 Answer」，
     * 后者属于格式错误，应该走 Repairable 重试而不是终止 ReAct 循环。
     */
    func hasAnswerOpenTag(): Bool {
        this.parser.currContent.trimAsciiStart().startsWithTag(Tag.Answer)
    }

    /**
     * Round3: 返回解析器当前已读到的内容。
     * 用于 Repairable 失败时把模型自己那段不合规输出回灌给它看（与同步路径
     * `handleStep(Repairable)` 的 `addMessage(Message.assistant(...))` 对齐），
     * 否则模型只看到一句"你的输出不合法"却不知道自己输出了什么。
     */
    func currentContent(): String {
        this.parser.currContent
    }

    /**
     * Round3: 读完剩余流并返回完整内容。
     * 兜底路径专用 —— 否则只拿得到首个 chunk，前端只显示半句话。
     */
    func readAllRemaining(): String {
        this.parser.readAllRemaining()
    }

    func getAsyncAnswer(): (String, AsyncReactAnswer) {
        let thought = String.join(this.thoughts.toArray(), delimiter: "\n")
        (thought, AsyncReactAnswer(this.parser))
    }
}
