/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

/// SQL 参数处理函数 - 用于 setSql 模板字符串中
/// 与 crudgen.CrudGenerator.arg 同构，供权限节点生成逻辑复用
/// @param value 参数值
/// @return 格式化后的参数字符串
public func arg<T>(value: T): String where T <: ToString {
    let str = value.toString()
    if (str == "None") {
        return "NULL"
    }
    // 检查是否是 Some(xxx) 格式
    if (str.size > 6 && str.startsWith("Some(")) {
        // 提取括号内的值
        var content = ""
        let startPos = 5
        let endPos = str.size - 1
        var i = startPos
        while (i < endPos) {
            let ch = str[i]
            // 将 UInt8 字符转换为对应的字符
            let charArr = Array<UInt8>(1, repeat: ch)
            content = content + String.fromUtf8(charArr)
            i += 1
        }
        // 检查是否为数字类型
        var isNumber = true
        var hasDot = false
        for (ch in content) {
            if (ch == 46 && !hasDot) { // '.' 的 ASCII 值是 46
                hasDot = true
            } else if (ch < 48 || ch > 57) { // '0'-'9' 的 ASCII 值范围
                isNumber = false
                break
            }
        }
        if (isNumber) {
            return content
        }
        // 检查是否为布尔类型
        if (content == "true" || content == "false") {
            return content
        }
        // 检查是否为 DateTime 类型（包含 T 和 + 等字符）
        var isDateTime = false
        for (ch in content) {
            if (ch == 84 || ch == 43 || ch == 45) { // 'T', '+', '-' 的 ASCII 值
                isDateTime = true
                break
            }
        }
        if (isDateTime) {
            return "'${content}'"
        }
        // 其他情况当作字符串处理（包括 UUID）
        return "'${content}'"
    }
    // 非 Optional 值，直接返回
    return "'${str}'"
}

public func optArg<T>(value: T): String where T <: ToString {
    let str = value.toString()
    if (str == "None") {
        return "NULL"
    }
    // 检查是否是 Some(xxx) 格式
    if (str.size > 6 && str.startsWith("Some(")) {
        // 提取括号内的值
        var content = ""
        let startPos = 5
        let endPos = str.size - 1
        var i = startPos
        while (i < endPos) {
            let ch = str[i]
            // 将 UInt8 字符转换为对应的字符
            let charArr = Array<UInt8>(1, repeat: ch)
            content = content + String.fromUtf8(charArr)
            i += 1
        }
        // 检查是否为数字类型（简单的数字格式检查）
        var isNumber = true
        var hasDot = false
        for (ch in content) {
            if (ch == 46 && !hasDot) { // '.' 的 ASCII 值是 46
                hasDot = true
            } else if (ch < 48 || ch > 57) { // '0'-'9' 的 ASCII 值范围
                isNumber = false
                break
            }
        }
        if (isNumber) {
            return content
        }
        // 检查是否为布尔类型
        if (content == "true" || content == "false") {
            return content
        }
        // 检查是否为 DateTime 类型（包含 T 和 + 等字符）
        var isDateTime = false
        for (ch in content) {
            if (ch == 84 || ch == 43 || ch == 45) { // 'T', '+', '-' 的 ASCII 值
                isDateTime = true
                break
            }
        }
        if (isDateTime) {
            return "'${content}'"
        }
        // 其他情况当作字符串处理（包括 UUID）
        return "'${content}'"
    }
    // 非 Optional 值，直接返回
    return "'${str}'"
}
