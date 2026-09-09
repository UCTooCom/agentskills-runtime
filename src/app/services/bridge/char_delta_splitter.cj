/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 *
 * 字符增量拆分器（CharDeltaSplitter）
 *
 * 功能：将完整的 reasoning_content 或 content 字符串拆分为多个 1-10 字符的增量块，
 *       供 SSEEventBridge 逐字推送，模拟大模型逐字输出效果。
 *
 * 仓颉规范约束（已复核）：
 * 1. 仓颉 String 为 UTF-8 编码，字节切片 content[0..chunkSize] 会截断多字节中文字符
 *    （如 "中" 占 3 字节）。必须先调用 content.toRuneArray() 转换为 Array<Rune>，
 *    再按 chunkSize 切分 Rune 数组，最后用 String(runeSlice) 还原为字符串增量块。
 * 2. 仓颉默认参数约束：带默认值的参数（chunkSize: Int64 = 5）必须排在无默认值参数
 *    （content: String）之后，当前签名满足此约束。
 * 3. 返回类型 Array<String> 为定长数组，构建时需先计算块数量，
 *    再用 Array<String>(blockCount, {_ => ""}) 初始化并按索引赋值。
 *    禁止使用 ArrayList<String>.append（仓颉 ArrayList 没有 append/add/push 方法）。
 * 4. 仓颉不支持三元运算符 cond ? a : b，必须用 if-else 表达式替代。
 *
 * 参考：
 * - std/core/core_package_structs.md: toRuneArray()、String.init(Array<Rune>)
 * - kernel/source_zh_cn/basic_data_type/array.md: Array<T>(size, init) 定长初始化
 */
package magic.app.services.bridge

/**
 * 字符增量拆分器
 *
 * 将完整字符串按 chunkSize 拆分为字符增量数组，处理多字节字符（按 Rune 切分，
 * 避免截断中文字符）。空字符串返回空数组。
 *
 * 示例：
 *   CharDeltaSplitter.split("中文测试", 2) => ["中文", "测试"]
 *   CharDeltaSplitter.split("abcde", 2)   => ["ab", "cd", "e"]
 *   CharDeltaSplitter.split("", 5)        => []
 */
public class CharDeltaSplitter {

    /// 静态实例（CharDeltaSplitter 无状态，可复用单例）
    public static let instance: CharDeltaSplitter = CharDeltaSplitter()

    public init() {}

    /**
     * 按 chunkSize 切分字符串为字符增量数组
     *
     * 处理多字节字符（按 Rune 切分，避免截断中文字符）。空字符串返回空数组。
     *
     * 仓颉规范约束：
     * - 先调用 content.toRuneArray() 转换为 Array<Rune>
     * - 按 chunkSize 切分 Rune 数组
     * - 用 String(runeSlice) 还原为字符串增量块
     * - 禁止直接用 content[0..chunkSize] 字节切片（会截断中文）
     *
     * 参数：
     * - content: 待切分的字符串（可为空）
     * - chunkSize: 每块的最大字符数（按 Rune 计数），默认 5，范围 1-100
     *
     * 返回：字符增量数组，每块长度 ≤ chunkSize（按 Rune 计数）
     *
     * 异常：无异常抛出，空输入或非法 chunkSize 返回空数组
     */
    public static func split(content: String, chunkSize: Int64): Array<String> {
        // 边界条件 1：空字符串返回空数组
        if (content.isEmpty()) {
            return Array<String>(0, {_ => ""})
        }

        // 边界条件 2：chunkSize 非法（≤0），返回单元素数组（整段）
        if (chunkSize <= 0) {
            let result = Array<String>(1, {_ => ""})
            result[0] = content
            return result
        }

        // 仓颉规范：必须按 Rune 切分，字节切片会截断中文
        let runes = content.toRuneArray()
        let runeCount = Int64(runes.size)

        // 边界条件 3：runeCount 为 0（理论上不会到这，因为 content.isEmpty 已处理）
        if (runeCount == 0) {
            return Array<String>(0, {_ => ""})
        }

        // 计算增量块数量（仓颉不支持三元运算符，用 if-else 表达式）
        let blockCount: Int64 = if (runeCount % chunkSize == 0) {
            runeCount / chunkSize
        } else {
            runeCount / chunkSize + 1
        }

        // 初始化定长数组（仓颉 Array 为定长，必须预先分配）
        let result = Array<String>(blockCount, {_ => ""})

        // 按块切分 Rune 数组并还原为字符串
        var idx: Int64 = 0
        while (idx < blockCount) {
            let start = idx * chunkSize
            // 仓颉不支持三元运算符，用 if-else 表达式计算 end
            let end: Int64 = if (start + chunkSize <= runeCount) {
                start + chunkSize
            } else {
                runeCount
            }

            // 切分 Rune 数组（Range 切片，左闭右开）
            // 仓颉 Range 语法：start..end（左闭右开），切片需用 runes.slice(start..end)
            // 或直接索引构造子数组
            var runeSlice = Array<Rune>(Int64(end - start), repeat: r'\0')
            var j: Int64 = start
            var k: Int64 = 0
            while (j < end) {
                runeSlice[k] = runes[j]
                j++
                k++
            }

            // 还原为字符串（String.init(Array<Rune>) 构造函数）
            result[idx] = String(runeSlice)

            idx++
        }

        return result
    }

    /**
     * 计算给定长度下推荐的 chunkSize
     *
     * 当 reasoning_content 长度超过 5000 字符时，逐字推送总耗时将超过 30 秒，
     * 远超前端 resetTimeoutOnProgress 的 15 秒保活间隔。
     * 因此动态调整 chunkSize，确保总推送耗时不超过 30 秒。
     *
     * 参数：
     * - totalLength: reasoning_content 总长度（按 Rune 计数）
     * - intervalMs: 推送间隔（毫秒），默认 30ms
     * - maxTotalMs: 最大总耗时（毫秒），默认 30000ms（30 秒）
     *
     * 返回：推荐的 chunkSize，范围 5-200
     */
    public static func recommendChunkSize(
        totalLength: Int64,
        intervalMs: Int64,
        maxTotalMs: Int64
    ): Int64 {
        if (totalLength <= 0 || intervalMs <= 0 || maxTotalMs <= 0) {
            return 5 // 默认值
        }

        // 计算最大块数（受总耗时限制）
        let maxBlocks = maxTotalMs / intervalMs

        if (maxBlocks <= 0) {
            return 5
        }

        // 推荐 chunkSize = ceil(totalLength / maxBlocks)
        let recommended: Int64 = if (totalLength % maxBlocks == 0) {
            totalLength / maxBlocks
        } else {
            totalLength / maxBlocks + 1
        }

        // 限制范围 5-200
        let clamped: Int64 = if (recommended < 5) {
            5
        } else if (recommended > 200) {
            200
        } else {
            recommended
        }

        return clamped
    }
}
