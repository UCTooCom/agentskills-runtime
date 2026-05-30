package magic.app.tools.crudgen

import std.collection.*
import std.fs.*
import std.convert.*

/**
 * 模板引擎
 * 
 * 负责模板文件的加载、变量替换和代码生成
 */
public class TemplateEngine {
    
    /**
     * 加载模板文件
     */
    public func loadTemplate(templatePath: String): String {
        File.readFrom(templatePath).toString()
    }
    
    /**
     * 变量替换
     * 
     * @param template 模板内容
     * @param variables 变量映射表
     * @return 替换后的内容
     */
    public func replaceVariables(template: String, variables: HashMap<String, String>): String {
        var result = template
        
        for ((key, value) in variables) {
            let placeholder = "{{${key}}}"
            result = result.replace(placeholder, value)
        }
        
        return result
    }
    
    /**
     * 增量更新文件
     * 
     * 保留自定义代码区域,只更新AutoCreateCode区域
     * 
     * 实现逻辑:
     * 1. 如果目标文件存在且包含 AutoCreateCode 标记对
     * 2. 保留标记之外的自定义代码（头部和尾部）
     * 3. 只替换标记之间的内容
     * 4. 标记本身保持不变
     */
    public func updateFile(targetPath: String, newContent: String): Unit {
        let autoCodeStart = "//#region AutoCreateCode"
        let autoCodeEnd = "//#endregion AutoCreateCode"
        let autoCodeEndSize = autoCodeEnd.size
        
        if (fileExists(targetPath)) {
            let bytes = File.readFrom(targetPath)
            let existingContent = String.fromUtf8(bytes)
            
            // 调试：输出文件内容的前100个字符
            println("DEBUG - 文件存在: ${targetPath}")
            println("DEBUG - 文件内容前100字符: ${existingContent[0..(min(existingContent.size, 100))]}")
            
            // 使用不同的方式查找标记
            let startIdxOpt = findSubstring(existingContent, autoCodeStart)
            let endIdxOpt = findSubstring(existingContent, autoCodeEnd)
            
            println("DEBUG - startIdxOpt: ${startIdxOpt}")
            println("DEBUG - endIdxOpt: ${endIdxOpt}")
            
            if (let Some(startIdx) <- startIdxOpt) {
                if (let Some(endIdx) <- endIdxOpt) {
                    if (endIdx > startIdx) {
                        println("DEBUG - 找到有效标记对，开始增量更新")
                        
                        // 保留头部自定义代码（开始标记之前）
                        let header = existingContent[0..startIdx]
                        // 保留尾部自定义代码（结束标记之后）
                        let footer = existingContent[endIdx + autoCodeEndSize..existingContent.size]
                        
                        // 提取新生成的代码中间部分（包含完整的标记对）
                        let newStartIdxOpt = findSubstring(newContent, autoCodeStart)
                        let newEndIdxOpt = findSubstring(newContent, autoCodeEnd)
                        
                        println("DEBUG - 新内容 startIdxOpt: ${newStartIdxOpt}")
                        println("DEBUG - 新内容 endIdxOpt: ${newEndIdxOpt}")
                        
                        if (let Some(newStartIdx) <- newStartIdxOpt) {
                            if (let Some(newEndIdx) <- newEndIdxOpt) {
                                if (newEndIdx > newStartIdx) {
                                    // 提取包含完整标记对的中间部分
                                    let newMiddle = newContent[newStartIdx..newEndIdx + autoCodeEndSize]
                                    
                                    // 组合: 头部 + 新代码（含标记） + 尾部
                                    let finalContent = header + newMiddle + footer
                                    writeFile(targetPath, finalContent)
                                    println("已增量更新文件: ${targetPath}")
                                    return
                                } else {
                                    println("DEBUG - 新内容标记顺序错误")
                                }
                            } else {
                                println("DEBUG - 新内容找不到结束标记")
                            }
                        } else {
                            println("DEBUG - 新内容找不到开始标记")
                        }
                    } else {
                        println("DEBUG - 标记顺序错误，开始标记位置 >= 结束标记位置")
                    }
                } else {
                    println("DEBUG - 找不到结束标记: ${autoCodeEnd}")
                }
            } else {
                println("DEBUG - 找不到开始标记: ${autoCodeStart}")
                // 尝试查找包含 AutoCreateCode 的行
                let lines = existingContent.split("\n")
                for (i in 0..lines.size) {
                    if (lines[i].contains("AutoCreateCode")) {
                        println("DEBUG - 在第${i}行找到 AutoCreateCode: ${lines[i]}")
                    }
                }
            }
        } else {
            println("DEBUG - 文件不存在")
        }
        
        // 文件不存在或没有AutoCreateCode标记,直接写入
        writeFile(targetPath, newContent)
        println("已创建新文件: ${targetPath}")
    }
    
    /**
     * 自定义字符串查找方法
     * 手动遍历字符串查找子串位置
     */
    private func findSubstring(str: String, substr: String): Option<Int> {
        if (substr.size == 0 || str.size < substr.size) {
            return None<Int>
        }
        
        let strSize = str.size
        let substrSize = substr.size
        
        for (i in 0..(strSize - substrSize + 1)) {
            var found = true
            for (j in 0..substrSize) {
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
    
    /**
     * 检查文件是否存在
     */
    public func fileExists(path: String): Bool {
        try {
            let content = File.readFrom(path)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 写入文件
     */
    public func writeFile(path: String, content: String): Unit {
        // 确保目录存在
        let p = Path(path)
        let parentPath = p.parent
        try {
            Directory.create(parentPath, recursive: true)
        } catch (e: Exception) {
            // 目录已存在,忽略错误
        }
        
        // 写入文件
        File.writeTo(path, content.toArray())
    }
}
