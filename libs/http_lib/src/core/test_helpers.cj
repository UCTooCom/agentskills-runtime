package http_lib.core

/**
 * 单元测试辅助断言函数集合。
 * 提供 assertTrue() 和 assertFalse() 方法，
 * 简化 HTTP 库测试代码的编写。
 */

/**
 * 单元测试断言辅助函数。
 */
public func assertEqual(actual: String, expected: String, message!: String = ""): Unit {
    if (actual != expected) {
        let msg = if (message.size > 0) { message } else { "期望 '${expected}'，实际为 '${actual}'" }
        throw Exception("断言失败: ${msg}")
    }
}

public func assertEqual(actual: Int64, expected: Int64, message!: String = ""): Unit {
    if (actual != expected) {
        let msg = if (message.size > 0) { message } else { "期望 ${expected}，实际为 ${actual}" }
        throw Exception("断言失败: ${msg}")
    }
}

public func assertTrue(condition: Bool, message!: String = ""): Unit {
    if (!condition) {
        let msg = if (message.size > 0) { message } else { "期望为真，实际为假" }
        throw Exception("断言失败: ${msg}")
    }
}

public func assertFalse(condition: Bool, message!: String = ""): Unit {
    if (condition) {
        let msg = if (message.size > 0) { message } else { "期望为假，实际为真" }
        throw Exception("断言失败: ${msg}")
    }
}
