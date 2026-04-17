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
     */
    public func updateFile(targetPath: String, newContent: String): Unit {
        let autoCodeStart = "//#region AutoCreateCode"
        let autoCodeEnd = "//#endregion AutoCreateCode"
        
        if (fileExists(targetPath)) {
            let existingContent = File.readFrom(targetPath).toString()
            let startIdxOpt = existingContent.indexOf(autoCodeStart)
            let endIdxOpt = existingContent.indexOf(autoCodeEnd)
            
            if (let Some(startIdx) <- startIdxOpt) {
                if (let Some(endIdx) <- endIdxOpt) {
                    if (endIdx > startIdx) {
                        // 保留头部和尾部自定义代码
                        let header = existingContent[0..startIdx]
                        let footer = existingContent[endIdx..existingContent.size]
                        
                        // 提取新生成的代码中间部分
                        let newStartIdxOpt = newContent.indexOf(autoCodeStart)
                        let newEndIdxOpt = newContent.indexOf(autoCodeEnd)
                        
                        if (let Some(newStartIdx) <- newStartIdxOpt) {
                            if (let Some(newEndIdx) <- newEndIdxOpt) {
                                if (newEndIdx > newStartIdx) {
                                    let newMiddle = newContent[newStartIdx..newEndIdx]
                                    
                                    // 组合: 头部 + 新代码 + 尾部
                                    let finalContent = header + newMiddle + footer
                                    writeFile(targetPath, finalContent)
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 文件不存在或没有AutoCreateCode标记,直接写入
        writeFile(targetPath, newContent)
    }
    
    /**
     * 检查文件是否存在
     */
    private func fileExists(path: String): Bool {
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
    private func writeFile(path: String, content: String): Unit {
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
