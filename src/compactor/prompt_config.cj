/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */

/**
 * PromptConfig（提示词可视化配置）
 *
 * ## 为什么要有这个类
 *
 * `prompts.cj` 里的三段提示词（工具结果压缩 system/user、会话压缩 system）
 * 原先**硬编码在 .cj 源码里**。这有两个问题（用户在 2026-09-15 复核时指出）：
 *
 * 1. **不适配长程任务**：`"Summarize the tool execution result."` 这类通用措辞
 *    没有要求保留「目标 / 当前进度 / 已完成与待办步骤 / 失败项 / 下一步」，
 *    而长程任务恰恰依赖这些跨回合信息不被压缩丢失。
 * 2. **违反设计哲学**：框架主张「尽量可视化配置而不硬编码」——
 *    改一句提示词要动代码、重新编译，业务同学根本改不了。
 *
 * ## 设计
 *
 * - **内置默认仍在 `prompts.cj`**（保证「什么都不配也能跑」，零回归）；
 * - **多目录扫描**：`loadFromDirs(dirs)` 接收**有序目录列表**，依次扫描，
 *   首个命中即生效（机制对齐 `AgentLoadManager.loadFromDirs`）。
 *   组合根 `main.cj` 按「技能内 `skills/<name>/prompts`（高优先级）→
 *   全局 `PROMPTS_DIR`/`./prompts`（兜底）」顺序注入，从而让**技能内配置自动优先生效**；
 * - **可被目录下的同名文件覆盖**（`<dir>/tool-summarize.user.md` 等）；
 * - **可按 profile 再覆盖**（`<dir>/tool-summarize.user.<profile>.md`），
 *   profile 由调用方给出（`AgentTask` 传 `agent.name` / 技能名），从而让
 *   「长程任务 agent」用一套保留进度的摘要提示词，普通对话用另一套。
 *
 * 优先级：**profile 文件（高优先级目录优先）> 全局文件（高优先级目录优先）> 内置默认**。
 *
 * ## 为什么用「组合根注入目录」而不是直接读 Config
 *
 * `magic.compactor` 是下层构件，`magic.config` 是上层配置门面；
 * 让 compactor 反向 import config 会新增一条不必要的层间依赖。
 * 按本项目既定做法（见 MEMORY.md「快照 + 宿主注入回调」），
 * 由 `main.cj` 这个组合根读配置后调用 `loadFromDir` 注入。
 *
 * ## 失败策略
 *
 * 目录不存在、文件缺失、读取异常 —— 一律**静默回落到上一级默认**，
 * 绝不因为提示词配置读不到而让任务跑不起来。
 */

package magic.compactor

import std.collection.{HashMap, ArrayList}
import std.fs.{File, OpenMode, exists}
import std.io.StringReader
import magic.log.LogUtils

public class PromptConfig {
    /// 工具结果压缩：system
    public static let FILE_TOOL_SUMMARIZE_SYSTEM: String = "tool-summarize.system.md"
    /// 工具结果压缩：user（必须保留 {tool_call} / {tool_result} 占位）
    public static let FILE_TOOL_SUMMARIZE_USER: String = "tool-summarize.user.md"
    /// 工具结果压缩：user 基础名（**不含**扩展名），仅用于拼装 profile 文件。
    /// ⚠️ 不能用 `FILE_TOOL_SUMMARIZE_USER` 直接拼 `${key}.md`，否则会变成
    /// `tool-summarize.user.md.<profile>.md`（双扩展名），而磁盘上的真实文件是
    /// `tool-summarize.user.<profile>.md`，导致 profile 提示词永远命中不了、始终回落内置默认。
    public static let FILE_TOOL_SUMMARIZE_USER_BASE: String = "tool-summarize.user"
    /// 会话压缩：system
    public static let FILE_CONVERSATION_SUMMARY_SYSTEM: String = "conversation-summary.system.md"

    /// profile 名长度上限（防止构造出超长文件名）
    private static let MAX_PROFILE_LEN: Int64 = 40

    private static var _toolSummarizeSystem: String = ""
    private static var _toolSummarizeUser: String = ""
    private static var _conversationSummarySystem: String = ""
    /// profile → 对应提示词内容。命中也缓存空串（表示该 profile 无覆盖文件），
    /// 避免每次工具压缩都做一次文件探测。
    private static let _profileUser = HashMap<String, String>()

    /// 有序提示词目录列表，**index 0 优先级最高**。
    /// 组合根（main.cj）按「技能内 prompts（高）→ 全局 PROMPTS_DIR（低）」顺序注入。
    private static var _dirs = ArrayList<String>()

    /// 实际加载来源目录（空串表示全部走内置默认），供启动日志/OPS 排查
    public static prop loadedFrom: String {
        get() { String.join(_dirs.toArray(), delimiter: ";") }
    }

    /**
     * 从**多个有序目录**加载可覆盖的提示词文件。目录顺序即优先级（index 0 最高）。
     * 机制对齐 AgentLoadManager.loadFromDirs：依次扫描，首个命中即生效。
     *
     * 典型注入顺序（见 main.cj）：
     *   1. 各 `skills/<name>/prompts`（技能内配置，优先级最高）
     *   2. `PROMPTS_DIR`（默认 `./prompts`，全局兜底）
     *
     * 全局文件（tool-summarize.system/user、conversation-summary.system）按目录优先级取首个命中；
     * profile 文件（tool-summarize.user.<profile>.md）同样按目录优先级扫描。
     * 目录不存在/文件缺失都**不报错**，静默回落到上一级默认。
     *
     * @param dirs 提示词目录列表（高优先级在前）
     */
    public static func loadFromDirs(dirs: Array<String>): Unit {
        _dirs = ArrayList<String>()
        _profileUser.clear()
        for (d in dirs) {
            if (d.isEmpty()) {
                continue
            }
            if (exists(d)) {
                _dirs.add(d)
            } else {
                LogUtils.warn("PromptConfig", "提示词目录不存在，跳过: ${d}")
            }
        }
        if (_dirs.isEmpty()) {
            LogUtils.info("PromptConfig", "未配置任何有效提示词目录，全部使用内置默认提示词")
            return
        }
        var hits = 0
        let sys = PromptConfig.readFirstMatch(FILE_TOOL_SUMMARIZE_SYSTEM)
        if (!sys.isEmpty()) { _toolSummarizeSystem = sys; hits++ }
        let usr = PromptConfig.readFirstMatch(FILE_TOOL_SUMMARIZE_USER)
        if (!usr.isEmpty()) { _toolSummarizeUser = usr; hits++ }
        let conv = PromptConfig.readFirstMatch(FILE_CONVERSATION_SUMMARY_SYSTEM)
        if (!conv.isEmpty()) { _conversationSummarySystem = conv; hits++ }
        LogUtils.info("PromptConfig", "多目录提示词已加载（优先级高→低）: ${dirsToString()}（覆盖文件 ${hits} 个）")
    }

    /**
     * 兼容旧调用：等价于 `loadFromDirs([dir])`。
     */
    public static func loadFromDir(dir: String): Unit {
        PromptConfig.loadFromDirs([dir])
    }

    /// 工具结果压缩 system 提示词
    public static func resolveToolSummarizeSystem(): String {
        if (!_toolSummarizeSystem.isEmpty()) {
            return _toolSummarizeSystem
        }
        TOOL_SUMMARIZE_SYSTEM_PROMPT
    }

    /**
     * 工具结果压缩 user 提示词。**profile 可以是逗号分隔的候选链**，
     * 按书写顺序探测，首个命中即用；全未命中再依次回落到全局文件、内置默认。
     *
     * ── 为什么是候选链而不是单个名字 ──────────────────────────────────
     * 调用方（`SimpleToolCompactor`）拿到的 profile 是 `agent.name`（如 `MainAgent`），
     * 而长程任务的定制提示词文件名是 `tool-summarize.user.long-running-task.md`
     * ——技能名与 agent 名天然不一致，单个名字永远命中不了。实测日志里
     * 「命中 profile 摘要提示词」出现 0 次，全部回落到通用默认。
     * 候选链让调用方把「更具体的上下文」写在前面（如被调工具名 / 技能名），
     * 把 agent 名兜在后面。
     */
    public static func resolveToolSummarizeUser(profile: String): String {
        for (cand in profile.split(",")) {
            let key = cand.trimAscii()
            if (key.isEmpty()) {
                continue
            }
            let fromProfile = PromptConfig.tryProfileUser(key)
            if (!fromProfile.isEmpty()) {
                return fromProfile
            }
        }
        if (!_toolSummarizeUser.isEmpty()) {
            return _toolSummarizeUser
        }
        TOOL_SUMMARIZE_USER_PROMPT
    }

    /// 会话压缩 system 提示词
    public static func resolveConversationSummarySystem(): String {
        if (!_conversationSummarySystem.isEmpty()) {
            return _conversationSummarySystem
        }
        CONVERSATION_SUMMARY_SYSTEM_PROMPT
    }

    // ── 公开：按 profile 精确探测（供候选链逐项调用）─────────────────

    /**
     * 严格只查 `<dir>/tool-summarize.user.<profile>.md` 这一个文件。
     * 未命中/未配置目录返回**空串**（不回落到全局或内置默认）——
     * 回落由调用方 `resolveToolSummarizeUser` 的候选链统一负责，
     * 否则"第一个候选"就会拿到默认值，后面的候选永远轮不到。带缓存。
     */
    public static func tryProfileUser(profile: String): String {
        let key = PromptConfig.sanitizeProfile(profile)
        if (key.isEmpty()) {
            return ""
        }
        match (_profileUser.get(key)) {
            case Some(v) => return v   // 已查过（含"确认无此文件"的空串）
            case None => ()
        }
        // 按目录优先级扫描，首个命中即生效（技能内 prompts 优先于全局 ./prompts）
        let text = PromptConfig.readFirstMatch("${FILE_TOOL_SUMMARIZE_USER_BASE}.${key}.md")
        if (!text.isEmpty()) {
            LogUtils.info("PromptConfig", "命中 profile 摘要提示词: ${key}")
        }
        _profileUser[key] = text
        text
    }

    // ── 内部 ────────────────────────────────────────────────────────

    /**
     * 把任意 profile（如 `agent.name`）规整成安全的文件名片段：
     * 只保留 ASCII 小写字母/数字/`-`/`.`/`_`，大写转小写，
     * 连续的非保留字节折叠为单个 `_`（中文等多字节串不会撑出一长串下划线），
     * 总长上限 40；结果为空表示不可用（调用方回落全局/内置默认）。
     */
    private static func sanitizeProfile(profile: String): String {
        if (profile.isEmpty()) {
            return ""
        }
        let out = ArrayList<UInt8>()
        var folded = false
        var n: Int64 = 0
        for (b in profile.toArray()) {
            if (n >= MAX_PROFILE_LEN) {
                break
            }
            if ((b >= 97 && b <= 122) || (b >= 48 && b <= 57) || b == 45 || b == 46 || b == 95) {
                out.add(b)
                n++
                folded = false
            } else if (b >= 65 && b <= 90) {
                out.add(UInt8(Int32(b) + 32))
                n++
                folded = false
            } else {
                if (!folded) {
                    out.add(UInt8(95))  // '_'
                    n++
                    folded = true
                }
            }
        }
        if (out.size == 0) {
            return ""
        }
        String.fromUtf8(out.toArray())
    }

    /// 按目录优先级顺序读取相对路径文件，返回首个非空内容；全部缺失返回空串。
    /// 这是「多目录扫描」的核心：高优先级目录（技能内 prompts）命中即返回。
    private static func readFirstMatch(relPath: String): String {
        for (d in _dirs) {
            let text = PromptConfig.readText("${d}/${relPath}")
            if (!text.isEmpty()) {
                return text
            }
        }
        ""
    }

    /// 把已加载目录列表拼成可读字符串（用于启动日志）
    private static func dirsToString(): String {
        String.join(_dirs.toArray(), delimiter: " > ")
    }

    private static func readText(path: String): String {
        if (!exists(path)) {
            return ""
        }
        try {
            let file = File(path, OpenMode.Read)
            let reader = StringReader(file)
            let content = reader.readToEnd()
            file.close()
            content
        } catch (e: Exception) {
            LogUtils.warn("PromptConfig", "读取提示词失败（忽略，回落默认）: ${path}, ${e.message}")
            ""
        }
    }
}
