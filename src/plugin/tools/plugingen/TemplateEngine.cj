/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

import std.collection.HashMap
import std.fs.{Directory, File, Path, exists}

/**
 * TemplateEngine - 插件生成器模板引擎（PS-T013）
 *
 * 参照 crudgen 同名实现裁剪：
 * - {{key}} 变量替换
 * - AutoCreateCode 区域增量更新（重新生成时保留区域外手写代码）
 */
public class TemplateEngine {

    // ── 保护区标记常量 ──
    //
    // 保护区标记必须与目标产物的注释语法匹配，否则标记行会被当成语法错误：
    //   - 仓颉源码（.cj）：行注释 `//`
    //   - YAML / TOML：行注释 `#`
    //   - Markdown：`#` 会被解析成 ATX 标题，必须用 HTML 注释 `<!-- -->`
    //
    // ⚠️ 标记本身全是 ASCII，`findSubstring` 与切片都按字节处理，跨语言通用无乱码风险。

    /// 仓颉源码保护区标记（行注释）
    public static let CJ_REGION_START = "//#region AutoCreateCode"
    public static let CJ_REGION_END = "//#endregion AutoCreateCode"

    /// YAML / TOML 保护区标记（行注释）
    public static let CONF_REGION_START = "#region AutoCreateCode"
    public static let CONF_REGION_END = "#endregion AutoCreateCode"

    /// Markdown 保护区标记（HTML 注释，不参与渲染）
    public static let MD_REGION_START = "<!-- #region AutoCreateCode -->"
    public static let MD_REGION_END = "<!-- #endregion AutoCreateCode -->"

    /// 加载模板文件（读取失败返回空串）
    public func loadTemplate(templatePath: String): String {
        try {
            return String.fromUtf8(File.readFrom(templatePath))
        } catch (_: Exception) {
            return ""
        }
    }

    /// {{key}} 变量替换
    public func replaceVariables(template: String, variables: HashMap<String, String>): String {
        var result = template
        for ((key, value) in variables) {
            let placeholder = "{{${key}}}"
            result = result.replace(placeholder, value)
        }
        return result
    }

    /**
     * 增量更新文件（保持 AutoCreateCode 区域机制，仓颉源码用 `//` 标记）
     *
     * 目标文件存在且含 AutoCreateCode 标记对时：保留区域外自定义代码，
     * 只替换标记之间的内容；否则整文件写入。
     */
    public func updateFile(targetPath: String, newContent: String): Unit {
        this.updateFileWithMarkers(
            targetPath,
            newContent,
            TemplateEngine.CJ_REGION_START,
            TemplateEngine.CJ_REGION_END
        )
    }

    /**
     * 增量更新文件（自定义保护区标记对）
     *
     * 与 `updateFile` 同语义，但标记由调用方给定 —— YAML / TOML 用 `#region`，
     * Markdown 用 HTML 注释，否则标记行会被目标语言的解析器当语法处理。
     *
     * @param targetPath 目标文件路径
     * @param newContent 新内容（须自带一对标记）
     * @param startMark 保护区起始标记
     * @param endMark 保护区结束标记
     */
    public func updateFileWithMarkers(
        targetPath: String,
        newContent: String,
        startMark: String,
        endMark: String
    ): Unit {
        if (this.fileExists(targetPath)) {
            let existing = this.readText(targetPath)
            let startIdxOpt = findSubstring(existing, startMark)
            let endIdxOpt = findSubstring(existing, endMark)

            if (let Some(startIdx) <- startIdxOpt) {
                if (let Some(endIdx) <- endIdxOpt) {
                    if (endIdx > startIdx) {
                        let header = existing[0..startIdx]
                        let footer = existing[endIdx + endMark.size..existing.size]
                        if (let Some(newStart) <- findSubstring(newContent, startMark)) {
                            if (let Some(newEnd) <- findSubstring(newContent, endMark)) {
                                if (newEnd > newStart) {
                                    let middle = newContent[newStart..newEnd + endMark.size]
                                    this.writeFile(targetPath, header + middle + footer)
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }
        this.writeFile(targetPath, newContent)
    }

    /// 检查文件是否存在
    public func fileExists(path: String): Bool {
        exists(path)
    }

    /// 读取文本（失败返回空串）
    public func readText(path: String): String {
        try {
            return String.fromUtf8(File.readFrom(path))
        } catch (_: Exception) {
            return ""
        }
    }

    /// 写文件（自动创建父目录）
    public func writeFile(path: String, content: String): Unit {
        let parentPath = Path(path).parent
        try {
            Directory.create(parentPath.toString(), recursive: true)
        } catch (_: Exception) {
            // 目录已存在，忽略
        }
        File.writeTo(path, content.toArray())
    }

    /// 子串查找（返回首个匹配位置）
    private func findSubstring(str: String, substr: String): Option<Int> {
        if (substr.size == 0 || str.size < substr.size) {
            return None<Int>
        }
        for (i in 0..(str.size - substr.size + 1)) {
            var found = true
            for (j in 0..substr.size) {
                if (str[i + j] != substr[j]) {
                    found = false
                    break
                }
            }
            if (found) {
                return Some(i)
            }
        }
        return None<Int>
    }
}
