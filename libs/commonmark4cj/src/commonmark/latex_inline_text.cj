/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */

package commonmark4cj.commonmark

/**
 * 为了\(...\)数学公式的解析，自定义一个Text节点
 * 若不特殊处理，其表现为Text
 */
public open class LatexInlineText <: CustomNode {
    public LatexInlineText(let literal: String) {}
    public func getLiteral(): String {
        return literal
    }
    public func getNodeType() {
        "LatexInlineText"
    }
}

public let needLatexInlineParse = [false]
