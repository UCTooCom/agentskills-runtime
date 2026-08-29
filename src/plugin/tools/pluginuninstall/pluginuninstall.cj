/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.pluginuninstall

import std.collection.ArrayList
import std.fs.{Path, File, exists, Directory, remove}

/**
 * pluginuninstall - 插件卸载命令行工具（PS-T019）
 *
 * 与 plugingen 同构的 CLI 工具，负责卸载指定插件：
 * 1. 从 plugins.yaml 中移除指定插件条目
 * 2. 调用 PluginHostManager.deactivate(name) 执行运行态卸载
 * 3. 可选：删除插件目录 plugins/<name>/
 *
 * 用法：
 *   pluginuninstall --name <插件名> [--purge] [--config <plugins.yaml路径>]
 *
 * 示例：
 *   pluginuninstall --name entity
 *   pluginuninstall --name entity --purge
 *   pluginuninstall --name entity --config ./plugins.yaml
 *
 *   pluginuninstall --help
 */
main(args: Array<String>) {
    println("Plugin Uninstaller (pluginuninstall) starting...")
    println("Args: ${args}")

    var pluginName = ""
    var purge = false
    var configPath = "./plugins.yaml"
    var pluginsRoot = "./plugins"
    var mode = "sync"  // 缺省 sync 轨；process 轨时经 CordisHostManager.terminate 杀进程

    var i = 0
    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--name" =>
                if (i + 1 < args.size) {
                    pluginName = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--purge" =>
                purge = true
                i += 1
            case "--config" =>
                if (i + 1 < args.size) {
                    configPath = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--plugins-root" =>
                if (i + 1 < args.size) {
                    pluginsRoot = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--mode" =>
                if (i + 1 < args.size) {
                    mode = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--help" | "-h" =>
                printHelp()
                return
            case _ =>
                println("未知参数: ${arg}")
                printHelp()
                return
        }
    }

    // 参数校验
    if (pluginName.isEmpty()) {
        println("错误: 必须指定 --name <插件名>")
        printHelp()
        return
    }

    // mode 校验：仅支持 sync/dylib/process
    if (mode != "sync" && mode != "dylib" && mode != "process") {
        println("错误: --mode 仅支持 sync/dylib/process，当前值: ${mode}")
        printHelp()
        return
    }

    println("卸载插件: ${pluginName}")
    println("配置文件: ${configPath}")
    println("插件根目录: ${pluginsRoot}")
    println("加载轨: ${mode}")
    println("删除插件目录: ${if (purge) { "是" } else { "否" }}")

    // Step 1: 从 plugins.yaml 中移除指定插件条目
    let yamlModified = removeFromYaml(configPath, pluginName)
    match (yamlModified) {
        case true => println("已从 ${configPath} 移除插件 '${pluginName}'")
        case false => println("警告: ${configPath} 中未找到插件 '${pluginName}'，跳过 YAML 修改")
    }

    // Step 2: 运行态卸载提示（CLI 工具不直接调用 PluginHostManager.deactivate）
    // PS-T020 设计决策：CLI 工具中初始化完整插件系统（PluginHostManager + 依赖注入）
    // 过于重量级，且与运行中的宿主进程存在状态隔离。采用"配置修改 + 重启提示"模式：
    // 1. CLI 工具修改 plugins.yaml（Step 1 已完成）
    // 2. 可选删除插件目录（Step 3）
    // 3. 提示用户重启宿主进程，使卸载在运行态生效
    // 注：运行态热卸载（不重启宿主）由 Agent 工具 plugin_deactivate 负责，
    // 该工具通过 PluginAgentTools.deactivate(name) 调用 PluginHostManager.deactivate。
    println("运行态卸载提示:")
    if (mode == "process") {
        // L3 进程轨：CordisHostManager.removePlugin 经 cordis terminate 杀进程 + OS 资源回收
        println("  [process 轨] 运行中的宿主经 CordisHostManager.removePlugin('${pluginName}') 终止插件进程")
        println("  plugins.yaml 已修改，需重启宿主进程使卸载在运行态生效")
        println("  或使用 Agent 工具 plugin_deactivate 执行运行态热卸载（经 CordisHostManager.deactivateProcessPlugin）")
    } else {
        println("  plugins.yaml 已修改，需重启宿主进程使卸载生效")
        println("  或使用 Agent 工具 plugin_deactivate 执行运行态热卸载")
    }

    // Step 3: 可选删除插件目录
    if (purge) {
        let pluginDir = "${pluginsRoot}/${pluginName}"
        if (exists(Path(pluginDir))) {
            println("删除插件目录: ${pluginDir}")
            // 仓颉标准库的 Directory 递归删除能力有限，
            // PS-T020 采用简化策略：仅删除目录本身（要求目录为空）
            // 非空目录的递归删除待 PS-T021 完善
            match (deleteDirectory(Path(pluginDir))) {
                case true => println("  插件目录已删除")
                case false => println("  警告: 目录非空或删除失败，请手动删除")
            }
        } else {
            println("警告: 插件目录不存在: ${pluginDir}")
        }
    }

    println("插件卸载完成: ${pluginName}")
}

/**
 * 从 plugins.yaml 中精确移除指定插件条目（PS-T020）
 *
 * plugins.yaml 结构：
 * ```yaml
 * plugins:
 *   - name: <插件名>
 *     className: ...
 *     enabled: true
 *     order: 1
 *     config: {}
 * ```
 *
 * 移除算法：
 * 1. 按行分割 YAML 内容
 * 2. 找到 `- name: <pluginName>` 所在行（支持引号变体）
 * 3. 从该行向前回溯删除连续的前导注释行（如 `  # plugingen 生成的插件`）
 * 4. 从该行向后删除直到下一个 `- name:` 行或文件末尾
 * 5. 将修改后的内容写回文件
 *
 * 返回：是否找到并移除了插件条目
 */
func removeFromYaml(configPath: String, pluginName: String): Bool {
    let path = Path(configPath)
    if (!exists(path)) {
        return false
    }

    // 读取 YAML 文件内容
    let content = match (readFileContent(path)) {
        case Some(c) => c
        case None => return false
    }

    // 按行分割
    let lines = content.split('\n')
    let arr = Array<String>(lines.size, { i => lines[i] })
    let n = arr.size

    // 找到 `- name: <pluginName>` 所在行
    var targetIdx = -1
    for (i in 0..n) {
        let line = arr[i]
        // 匹配 `- name: <pluginName>` 及引号变体
        if (line.contains("- name: ${pluginName}") ||
            line.contains("- name: \"${pluginName}\"") ||
            line.contains("- name: '${pluginName}'")) {
            targetIdx = i
            break
        }
    }

    if (targetIdx == -1) {
        return false  // 未找到插件条目
    }

    // 向前回溯：删除连续的前导注释行（如 `  # plugingen 生成的插件`）
    var startIdx = targetIdx
    var j = targetIdx - 1
    while (j >= 0) {
        let prevLine = arr[j].trimAscii()
        if (prevLine.startsWith("#")) {
            startIdx = j
            j -= 1
        } else if (prevLine.isEmpty()) {
            // 空行也删除（保持格式整洁）
            startIdx = j
            j -= 1
        } else {
            break
        }
    }

    // 向后删除：直到下一个 `- name:` 行或文件末尾
    var endIdx = targetIdx
    var k = targetIdx + 1
    while (k < n) {
        let nextLine = arr[k]
        // 遇到下一个插件条目（`- name:`）则停止
        if (nextLine.contains("- name:")) {
            break
        }
        // 遇到非缩进的顶层键（如非 `plugins:` 的其他顶层配置）则停止
        // 但 plugins.yaml 通常只有 `plugins:` 顶层键，这里简化处理
        endIdx = k
        k += 1
    }

    // 构建移除后的新内容
    let newLines = ArrayList<String>()
    for (i in 0..startIdx) {
        newLines.add(arr[i])
    }
    for (i in (endIdx + 1)..n) {
        newLines.add(arr[i])
    }

    // 将修改后的内容写回文件
    var newContent = ""
    for (i in 0..newLines.size) {
        newContent += newLines[i]
        if (i < newLines.size - 1) {
            newContent += "\n"
        }
    }

    match (writeFileContent(path, newContent)) {
        case true => true
        case false => false
    }
}

/**
 * 读取文件内容（辅助函数）
 *
 * 返回：文件内容（Option<String>，读取失败返回 None）
 */
func readFileContent(path: Path): Option<String> {
    try {
        // 使用仓颉标准库的 File.readFrom 读取文件全部字节
        let content = String.fromUtf8(File.readFrom(path))
        Some(content)
    } catch (e: Exception) {
        None
    }
}

/**
 * 写入文件内容（辅助函数）
 *
 * 返回：是否写入成功
 */
func writeFileContent(path: Path, content: String): Bool {
    try {
        // 使用仓颉标准库的 File.writeTo 写入文件全部字节
        File.writeTo(path, content.toArray())
        true
    } catch (e: Exception) {
        false
    }
}

/**
 * 递归删除目录及其全部内容（PS-T020）
 *
 * 算法参考 skill_package_manager._removeDirectoryRecursively：
 * 1. Directory.walk 遍历删除所有文件
 * 2. 再次 walk 删除空子目录
 * 3. 最后删除根目录
 *
 * 返回：是否删除成功
 */
func deleteDirectory(dirPath: Path): Bool {
    if (!exists(dirPath)) {
        return false
    }
    try {
        // Step 1: 删除所有文件
        Directory.walk(dirPath.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                remove(fileInfo.path.toString())
            }
            true
        }
        // Step 2: 删除空子目录
        Directory.walk(dirPath.toString()) { fileInfo =>
            if (fileInfo.isDirectory()) {
                remove(fileInfo.path.toString())
            }
            true
        }
        // Step 3: 删除根目录
        remove(dirPath.toString())
        true
    } catch (e: Exception) {
        false
    }
}

/**
 * 打印帮助信息
 */
func printHelp(): Unit {
    println("用法: pluginuninstall --name <插件名> [选项]")
    println("")
    println("选项:")
    println("  --name <插件名>          要卸载的插件名（必选）")
    println("  --mode <轨>              加载轨：sync（缺省）/ dylib / process")
    println("  --purge                  同时删除插件目录 plugins/<name>/")
    println("  --config <路径>          plugins.yaml 路径（默认: ./plugins.yaml）")
    println("  --plugins-root <路径>    插件根目录（默认: ./plugins）")
    println("  --help, -h               显示帮助信息")
    println("")
    println("示例:")
    println("  pluginuninstall --name entity")
    println("  pluginuninstall --name entity --purge")
    println("  pluginuninstall --name entity --config ./config/plugins.yaml")
}
