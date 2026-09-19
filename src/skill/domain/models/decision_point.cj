/*
 * Copyright (c) 2026. All rights reserved.
 */
package magic.skill.domain.models

import std.collection.ArrayList

/**
 * DecisionOption 表示决策点中的一个可选方案（spec 5.15.1 规则 2）。
 *
 * 选项至少含 id / label / description，建议含 tradeoff（取舍说明），
 * 供前端渲染选项卡片并让人类做出有依据的选择。
 */
public class DecisionOption {
    public let id: String  // 选项标识，必须是 default/recommended 的合法取值
    public let label: String  // 选项展示名（前端卡片标题）
    public let description: String  // 选项说明（前端卡片正文）
    public let tradeoff: String  // 取舍说明（选它要付出什么代价）；未声明时为空串

    public init(
        id!: String,
        label!: String,
        description!: String,
        tradeoff!: String
    ) {
        this.id = id
        this.label = label
        this.description = description
        this.tradeoff = tradeoff
    }

    /// 转为 JSON 文本片段，供 approval 请求的 options 字段下发。
    public func toJsonString(): String {
        return "{\"id\":${DecisionOption.jsonEscape(this.id)},\"label\":${DecisionOption.jsonEscape(this.label)},\"description\":${DecisionOption.jsonEscape(this.description)},\"tradeoff\":${DecisionOption.jsonEscape(this.tradeoff)}}"
    }

    /// 最小 JSON 字符串转义，避免选项文本里的引号破坏选项数组结构。
    /// 先追加待转义字符本身，再按需追加转义后缀——
    /// 因为 Cangjie 的 `match` 分支体是表达式，无法把「追加字符 + 追加后缀」
    /// 两种动作合并成一个分支而保持可读性。
    /// 编码依据：`rune.toString()`（Rune <: ToString，见 abs_bpe_tokenizer.cj:601）、
    /// Rune 字面量须带 `r` 前缀（见 char_delta_splitter.cj:103 的 r'\0'）。
    static func jsonEscape(s: String): String {
        let sb = StringBuilder()
        sb.append("\"")
        for (c in s.toRuneArray()) {
            sb.append(c.toString())
            match (c) {
                case r'\\' => sb.append("\\")
                case r'"' => sb.append("\\")
                case r'\n' => sb.append("n")
                case r'\r' => sb.append("r")
                case r'\t' => sb.append("t")
                case _ => ()
            }
        }
        sb.append("\"")
        return sb.toString()
    }
}

/**
 * DecisionPoint 表示技能 SKILL.md frontmatter 中声明的一个决策点（spec 5.15.1 规则 1）。
 *
 * 声明在技能，能力在 runtime：技能作者定义"在哪问、问什么、给哪些选项"，
 * runtime 负责"怎么问、怎么等、怎么回灌"。
 */
public class DecisionPoint {
    public let id: String  // 决策点标识，同一技能内唯一
    public let when: String  // 触发时机（人类可读描述或步骤名）
    public let question: String  // 向人类提出的问题
    public let options: Array<DecisionOption>  // 候选方案，规则 4 要求至少 2 项
    public let defaultOption: String  // 默认项，规则 3 要求必填，超时/通道不可用时采用
    public let recommended: String  // 推荐项，AI 倾向的方案；未声明时为空串
    public let timeoutSeconds: Int64  // 等待上限（秒），避免无限等待

    public init(
        id!: String,
        when!: String,
        question!: String,
        options!: Array<DecisionOption>,
        defaultOption!: String,
        recommended!: String,
        timeoutSeconds!: Int64
    ) {
        this.id = id
        this.when = when
        this.question = question
        this.options = options
        this.defaultOption = defaultOption
        this.recommended = recommended
        this.timeoutSeconds = timeoutSeconds
    }

    /// 所有合法选项 id。
    public func optionIds(): Array<String> {
        let ids = ArrayList<String>()
        for (opt in this.options) {
            ids.add(opt.id)
        }
        return ids.toArray()
    }

    /// 是否为合法选项 id（规则 2/3 的判定基础）。
    public func isLegalOptionId(candidate: String): Bool {
        for (opt in this.options) {
            if (opt.id == candidate) {
                return true
            }
        }
        return false
    }

    /// 把选项列表序列化为 JSON 数组文本，供 approval 请求下发。
    public func optionsJson(): String {
        let sb = StringBuilder()
        sb.append("[")
        var first = true
        for (opt in this.options) {
            if (!first) {
                sb.append(",")
            }
            sb.append(opt.toJsonString())
            first = false
        }
        sb.append("]")
        return sb.toString()
    }
}

/**
 * DecisionPointParseResult 承载"解析 + 校验"的完整产物。
 *
 * 设计要点（v15 复核问题 C 的修复）：用结构化字段而非自由文本表达"该决策点不生效"，
 * 让下游（执行器 / 审批工具 / 前端）能真正跳过失效决策点，而不是只能读一句 warning。
 */
public class DecisionPointParseResult {
    /// 校验通过、可正常参与人在回路的决策点
    public let validPoints: Array<DecisionPoint>
    /// 校验失败、**不生效**的决策点 id（问题 C 要求的结构化返回）
    public let invalidPointIds: Array<String>
    /// 人类可读的告警明细，与 invalidPointIds 一一对应（同一决策点可能有多条）
    public let warnings: Array<String>
    /// 技能 frontmatter 里是否声明了 decision-points 段
    public let declared: Bool

    public init(
        validPoints!: Array<DecisionPoint>,
        invalidPointIds!: Array<String>,
        warnings!: Array<String>,
        declared!: Bool
    ) {
        this.validPoints = validPoints
        this.invalidPointIds = invalidPointIds
        this.warnings = warnings
        this.declared = declared
    }

    /// 无决策点声明的空结果（绝大多数技能属于此类，不应产生任何告警）。
    public static func empty(): DecisionPointParseResult {
        return DecisionPointParseResult(
            validPoints: [],
            invalidPointIds: [],
            warnings: [],
            declared: false
        )
    }

    /// 是否存在失效决策点。
    public func hasInvalidPoints(): Bool {
        return this.invalidPointIds.size > 0
    }

    /// 按 id 查找一个**有效**决策点；失效的决策点查不到 ⇒ 天然"不生效"。
    public func findValid(pointId: String): Option<DecisionPoint> {
        for (dp in this.validPoints) {
            if (dp.id == pointId) {
                return Some(dp)
            }
        }
        return None
    }
}
