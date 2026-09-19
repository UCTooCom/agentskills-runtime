/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.parser

import magic.log.LogUtils
import magic.core.message.{Tag, WithTag, OPEN_TAG_SYMBOL, CLOSE_TAG_SYMBOL}

import std.collection.ArrayList
import std.regex.Regex

/**
 * Parsing a sequence of tagged content
 * Each tagged content is of form [tag] ... [/tag]
 * ATTENTION: the tag name must be of less than 20 letters!
 */
protected class TagStreamParser {
    private static const MAX_TAG_NAME_SIZE = 20

    protected TagStreamParser(
        /**
         * Data chunks of the tag sequence
        */
        private let chunks: Iterator<String>,
        /**
        * Callback function used to print internal messages
        */
        protected var onChunkFn!: Option<(String) -> Unit> = None
    ) { }

    private var finished = false

    /**
     * Save content has been read
     */
    private let buffer = StringBuilder()

    /**
     * Read a chunk to the buffer
     */
    private func readChunk(): Bool {
        if (let Some(chunk) <- this.chunks.next()) {
            buffer.append(chunk)
            if (let Some(fn) <- this.onChunkFn) {
                fn(chunk)
            }
            return true
        }
        return false
    }

    /**
     * Read all chunks to the buffer
     */
    private func readAllChunk(): Unit {
        for (chunk in this.chunks) {
            buffer.append(chunk)
        }
    }

    protected func resetBuffer(content: String): Unit {
        this.buffer.reset()
        this.buffer.append(content)
    }

    protected prop currContent: String {
        get() {
            buffer.toString()
        }
    }

    protected prop currTag: Option<Tag> {
        get() {
            while (this.currContent.trimAscii().size < Tag.longestTagSize) {
                if (!this.readChunk()) { break }
            }
            // Check whether the current content starts with a tag
            let content = this.currContent.trimAscii()
            for (tag in Tag.allTags) {
                if (content.startsWithTag(tag)) {
                    return tag
                }
            }
            if (!content.isEmpty()) {
                // Round2 修复：内容不以任何已知标签开头属于**格式错误**，
                // 上一轮这里兜底成 `return Tag.Answer`，导致畸形输出被静默判定为最终答案。
                //
                // Round3 补充容错：先继续往后读，尝试在缓冲区里定位第一个开标签。
                // 定位到就把标签之前的散文前缀丢掉（推理模型常见行为），
                // 读完整条流还是没有任何标签，才判定为格式错误抛 ParserException，
                // 由上层 asyncRunOnce 的 catch 分支追加修复提示后重试（Repairable）。
                var pos = this.indexOfFirstOpenTag()
                while (pos.isNone()) {
                    if (!this.readChunk()) {
                        break
                    }
                    pos = this.indexOfFirstOpenTag()
                }
                if (let Some(p) <- pos) {
                    if (p > 0) {
                        LogUtils.info(
                            "TagStreamParser: skipped ${p} byte(s) of untagged prose before the first tag"
                        )
                        this.resetBuffer(this.currContent[p..])
                    }
                    let trimmed = this.currContent.trimAscii()
                    for (tag in Tag.allTags) {
                        if (trimmed.startsWithTag(tag)) {
                            return tag
                        }
                    }
                }
                throw ParserException(
                    "Output does not start with any known tag (${Tag.Thought}/${Tag.Action}/${Tag.Answer}): `${this.currContent}`"
                )
            }
            return None
        }
    }

    /**
     * Round3: 在**已缓冲内容**里定位第一个已知开标签的起始下标。
     *
     * 用途：部分模型（尤其是推理模型）会先输出一段散文（复述问题、自言自语），
     * 之后才给出 `<thinking>/<action>/<answer>`。只要缓冲区里已经能看到开标签，
     * 就把标签之前的散文丢弃、从标签处开始解析；一个标签都找不到才是格式错误。
     */
    private func indexOfFirstOpenTag(): Option<Int64> {
        var found: Option<Int64> = None
        for (tag in Tag.allTags) {
            let regex = Regex("\\${OPEN_TAG_SYMBOL}\\s*${tag.name}\\s*\\${CLOSE_TAG_SYMBOL}")
            if (let Some(md) <- regex.find(this.currContent)) {
                let start = md.matchPosition().start
                if (let Some(v) <- found) {
                    if (start < v) {
                        found = Some(start)
                    }
                } else {
                    found = Some(start)
                }
            }
        }
        return found
    }

    /**
     * Round3: 读完剩余所有 chunk 并返回完整缓冲内容。
     *
     * 兜底路径专用。此前 asyncSummarize 只回传 `currContent`，
     * 而那时只读到第一个 chunk，前端就只收到 "The user wants" 这种半句话。
     */
    protected func readAllRemaining(): String {
        this.readAllChunk()
        return this.currContent
    }

    protected func readTagAndContent(tag: Tag): String {
        let strBuilder = StringBuilder()
        while (let Some((content, isClosed)) <- this.readContentUntilClosed(tag)) {
            strBuilder.append(content)
            if (isClosed) { break }
        }
        let content = strBuilder.toString().trimTag(tag)
        return content.withTag(tag)
    }

    protected func removeTag(tag: Tag): Unit {
        this.resetBuffer(this.currContent.trimAsciiStart().trimTag(tag))
    }

    /**
     * Return part content and whether the close tag is read
     */
    protected func readContentUntilClosed(tag: Tag): Option<(String, Bool)> {
        if (finished) {
            if (this.readChunk()) {
                LogUtils.debug("Tag stream is finished but the stream is not finished")
            }
            return None
        }
        // Read a chunk
        let exhausted = !this.readChunk()
        let (left, closeTag, right) = this.splitByCloseTag(tag)
        if (exhausted) {
            if (tag == Tag.Answer) {
                // Case 1: The answer tag is special, we always treat the stream is over
                finished = true
                this.resetBuffer("")
            } else if (right.trimAscii().isEmpty()) {
                // Case 2: If the rest is empty, we can consider the tag is closed
                finished = true
                this.resetBuffer("")
            } else if (closeTag.isNone()) {
                // Case 3: If the rest is not empty and does not contain the close tag
                throw ParserException("Fail to read async react ${tag} content. Rest: `${right}`")
            } else { // Otherwise
                this.resetBuffer(right)
            }
            return (left.trimAsciiEnd(), true)
        } else {
            // If the rest starts with the complete close tag, remove it
            this.resetBuffer(right)
            if (closeTag.isSome()) {
                return (left.trimAsciiEnd(), true)
            } else {
                return (left, false)
            }
        }
    }

    private func splitByCloseTag(tag: Tag): (String, ?String, String) {
        let tagName = tag.name
        let content = this.currContent
        // The current content contains the full close tag
        let regex = Regex("\\${OPEN_TAG_SYMBOL}\\s*/\\s*${tagName}\\s*\\${CLOSE_TAG_SYMBOL}")
        if (let Some(md) <- regex.find(content)) {
            let pos = md.matchPosition()
            let left = content[..pos.start]
            let right = content[pos.end..]
            return (left, tag.close, right)
        }

        // Check whether the content ends with a prefix of the close tag
        let regexToCheck = ArrayList<Regex>()
        for (index in tagName.size..=1 : -1) {
            let prefix = tagName[0..index]
            regexToCheck.add(Regex("\\${OPEN_TAG_SYMBOL}\\s*/\\s*${prefix}\\s*$"))
        }
        // Add the regex to check the prefix symbols of closed tags
        regexToCheck.add(Regex("\\${OPEN_TAG_SYMBOL}\\s*/?\\s*$"))

        for (regex in regexToCheck) {
            if (let Some(md) <- regex.find(content)) {
                let pos = md.matchPosition()
                let pivot = pos.start
                return (content[0..pivot], None, content[pivot..])
            }
        }
        return (content, None, "")
    }
}
