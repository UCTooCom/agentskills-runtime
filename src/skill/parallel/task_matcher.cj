/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import magic.core.skill.Skill
import std.collection.{ArrayList, HashSet}

public class TaskMatcher {
    private let _config: AutoInjectConfig

    public init(config!: AutoInjectConfig) {
        _config = config
    }

    public prop config: AutoInjectConfig {
        get() { _config }
    }

    public func matchSkills(taskDescription: String, skills: Array<Skill>): Array<TaskMatchResult> {
        if (!_config.autoInjectEnabled || taskDescription.isEmpty() || skills.size == 0) {
            return []
        }

        let results = ArrayList<TaskMatchResult>()
        for (skill in skills) {
            let score = matchByStrategy(taskDescription, skill.description)
            if (score >= _config.taskMatchThreshold) {
                let matchedKw = getMatchedKeywords(taskDescription, skill.description)
                results.add(TaskMatchResult(
                    skillName: skill.name,
                    matchScore: score,
                    matchStrategy: _config.taskMatchStrategy,
                    matchedKeywords: matchedKw
                ))
            }
        }

        sortDescending(results)

        let maxCount = Int64(_config.maxAutoInjectSkills)
        if (Int64(results.size) <= maxCount) {
            return results.toArray()
        }

        let limited = ArrayList<TaskMatchResult>()
        var i = 0
        while (Int64(i) < maxCount) {
            limited.add(results[i])
            i++
        }
        return limited.toArray()
    }

    // 按配置的策略分派匹配算法（Keyword / Semantic / Hybrid）。
    // enum 不支持 ==，必须用 match 分派（见工程红线）。
    private func matchByStrategy(taskDescription: String, skillDescription: String): Float64 {
        match (_config.taskMatchStrategy) {
            case TaskMatchStrategy.Semantic => matchBySemantic(taskDescription, skillDescription)
            case TaskMatchStrategy.Hybrid => matchHybrid(taskDescription, skillDescription)
            case TaskMatchStrategy.Keyword => matchByKeyword(taskDescription, skillDescription)
        }
    }

    private func matchHybrid(taskDescription: String, skillDescription: String): Float64 {
        let k = matchByKeyword(taskDescription, skillDescription)
        let s = matchBySemantic(taskDescription, skillDescription)
        if (k >= s) { return k } else { return s }
    }

    public func matchByKeyword(taskDescription: String, skillDescription: String): Float64 {
        let taskTokens = tokenize(taskDescription)
        let skillTokens = tokenize(skillDescription)

        if (taskTokens.size == 0 || skillTokens.size == 0) {
            return 0.0
        }

        let intersection = HashSet<String>()
        for (token in taskTokens) {
            if (skillTokens.contains(token)) {
                intersection.add(token)
            }
        }

        let union = HashSet<String>()
        for (token in taskTokens) {
            union.add(token)
        }
        for (token in skillTokens) {
            union.add(token)
        }

        if (union.size == 0) {
            return 0.0
        }

        return Float64(intersection.size) / Float64(union.size)
    }

    public func matchBySemantic(taskDescription: String, skillDescription: String): Float64 {
        // 语义匹配模型（embedding / LLM 通道）尚未接入。在未接入时降级为关键词匹配，
        // 禁止返回常量 0 —— 那会导致 Semantic 策略下永不命中，比关键词策略更糟（D2 修复）。
        eprintln("[TaskMatcher] semantic model not wired; matchBySemantic degrades to keyword matching")
        return matchByKeyword(taskDescription, skillDescription)
    }

    // 将文本规范化为可比较的 token 集合（D1 修复）：
    //  - ASCII 字母/数字/下划线序列（英文单词、代码标识符）整体保留并转小写；
    //  - 连续的 CJK 字符段拆解为「字符 bigram」（长度为 2 的重叠 n-gram），
    //    使中文文本无需分词器即可产生可重叠特征，Jaccard 才有意义。
    // 原实现仅 split(" ")，中文无空格 → 整句 1 token → 相似度恒 0 → 自动注入对中文永不触发。
    private func tokenize(text: String): HashSet<String> {
        let tokens = HashSet<String>()
        let runes = text.toRuneArray()
        var asciiBuf = ""
        var cjkRunes = ArrayList<Rune>()
        for (r in runes) {
            if (isAsciiAlnum(r)) {
                if (cjkRunes.size > 0) {
                    flushCjk(cjkRunes, tokens)
                    cjkRunes = ArrayList<Rune>()
                }
                asciiBuf = asciiBuf + r.toString()
            } else if (isCjk(r)) {
                if (!asciiBuf.isEmpty()) {
                    flushAscii(asciiBuf, tokens)
                    asciiBuf = ""
                }
                cjkRunes.add(r)
            } else {
                // 空白 / 标点 / 其它：冲刷两侧缓冲
                if (!asciiBuf.isEmpty()) {
                    flushAscii(asciiBuf, tokens)
                    asciiBuf = ""
                }
                if (cjkRunes.size > 0) {
                    flushCjk(cjkRunes, tokens)
                    cjkRunes = ArrayList<Rune>()
                }
            }
        }
        if (!asciiBuf.isEmpty()) { flushAscii(asciiBuf, tokens) }
        if (cjkRunes.size > 0) { flushCjk(cjkRunes, tokens) }
        return tokens
    }

    private func flushAscii(buf: String, tokens: HashSet<String>): Unit {
        let t = buf.toAsciiLower()
        if (!t.isEmpty()) { tokens.add(t) }
    }

    private func flushCjk(buf: ArrayList<Rune>, tokens: HashSet<String>): Unit {
        let n = buf.size
        if (n == 0) { return }
        if (n == 1) {
            tokens.add(buf[0].toString())
            return
        }
        for (i in 0..n - 1) {
            let bigram = buf[i].toString() + buf[i + 1].toString()
            tokens.add(bigram)
        }
    }

    // 直接按 Rune 码点比较（沿用 unicode_tokenizer.cj:51 的 proven 写法），
    // 避免 Rune→UInt32 的显式转换（Byte/Rune 无隐式数值转换，红线）。
    private func isAsciiAlnum(r: Rune): Bool {
        return (r >= r'0' && r <= r'9') ||
               (r >= r'A' && r <= r'Z') ||
               (r >= r'a' && r <= r'z') ||
               (r == r'_')
    }

    private func isCjk(r: Rune): Bool {
        return (r >= r'\u{4E00}' && r <= r'\u{9FFF}') ||   // CJK Unified Ideographs
               (r >= r'\u{3400}' && r <= r'\u{4DBF}')      // CJK Extension A
    }

    private func getMatchedKeywords(taskDescription: String, skillDescription: String): ArrayList<String> {
        let taskTokens = tokenize(taskDescription)
        let skillTokens = tokenize(skillDescription)
        let matched = ArrayList<String>()
        for (token in taskTokens) {
            if (skillTokens.contains(token)) {
                matched.add(token)
            }
        }
        return matched
    }

    private func sortDescending(results: ArrayList<TaskMatchResult>): Unit {
        let n = results.size
        for (i in 0..n - 1) {
            for (j in 0..n - 1 - i) {
                if (results[j].matchScore < results[j + 1].matchScore) {
                    let tmp = results[j]
                    results[j] = results[j + 1]
                    results[j + 1] = tmp
                }
            }
        }
    }
}
