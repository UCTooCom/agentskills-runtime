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
 *                   [--mode sync|dylib|process] [--plugins-root <plugins目录>]
 *                   [--skills-root <skills目录>] [--bin-root <bin目录>] [--force]
 *
 * 示例：
 *   pluginuninstall --name entity
 *   pluginuninstall --name entity --purge
 *   pluginuninstall --name entity --config ./plugins.yaml
 *
 *   # L3 进程轨：自动从 skills/<name>/plugin.yaml 的 `mode: process` 识别，
 *   # --purge 会清理 skills/<name>/（源码+target/）与发布态 bin/skills/<name>/、bin/plugins/<name>/
 *   pluginuninstall --name long-running-task --purge --force
 *
 *   pluginuninstall --help
 *
 * L3（process 轨）说明：
 *   进程插件的可执行文件与随包资源**不在 plugins/<name> 下**，而是：
 *     - 开发态：skills/<name>/target/release/bin/skill_<name>.exe
 *     - 发布态：bin/skills/<name>/target/release/bin/skill_<name>.exe（+ scripts/ 等随包资源）
 *     - 清单副本：bin/plugins/<name>/（plugin.yaml + SKILL.md）
 *   因此 process 轨的 --purge 走独立清理路径（见 purgeProcessPlugin），
 *   且因涉及源码递归删除，必须显式追加 --force 才会真正执行。
 */
main(args: Array<String>) {
    println("Plugin Uninstaller (pluginuninstall) starting...")
    println("Args: ${args}")

    var pluginName = ""
    var purge = false
    var configPath = "./plugins.yaml"
    var pluginsRoot = "./plugins"
    var mode = "sync"  // 缺省 sync 轨；process 轨时经 CordisHostManager.terminate 杀进程
    // L3 进程轨专用：源码树与发布态解包根目录（见 printHelp）
    var skillsRoot = "./skills"
    var binRoot = "./bin"
    // 递归删除确认闸：process 轨含源码与构建产物，默认只列计划、不真删
    var force = false
    // 标记用户是否显式给了 --mode：未显式时可从 plugin.yaml 自动识别
    var modeExplicit = false

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
            case "--force" =>
                force = true
                i += 1
            case "--skills-root" =>
                if (i + 1 < args.size) {
                    skillsRoot = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
            case "--bin-root" =>
                if (i + 1 < args.size) {
                    binRoot = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }
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
                    modeExplicit = true
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
    println("技能根目录: ${skillsRoot}")
    println("发布包根目录: ${binRoot}")

    // ===== L3 适配：未显式 --mode 时从 plugin.yaml 自动识别加载轨 =====
    // plugingen 的 process 轨会把 `mode: process` 写进 skills/<name>/plugin.yaml；
    // 若此处仍按缺省 sync 处理，--purge 会去删 plugins/<name>/（进程插件根本不在那里），
    // 表现为「卸载成功但 exe 与随包资源全部残留」。自动识别可以避免这种静默失效。
    if (!modeExplicit) {
        match (detectPluginMode(skillsRoot, pluginName)) {
            case Some(detected) =>
                mode = detected
                println("加载轨: ${mode}（自动识别自 ${skillsRoot}/${pluginName}/plugin.yaml）")
            case None =>
                println("加载轨: ${mode}（未找到 plugin.yaml，按缺省值处理；可用 --mode 显式指定）")
        }
    } else {
        // 显式指定时做一次交叉校验，防止把 process 插件当 sync 插件清理错目录
        match (detectPluginMode(skillsRoot, pluginName)) {
            case Some(detected) =>
                if (detected != mode) {
                    println("警告: plugin.yaml 声明为 ${detected} 轨，与 --mode ${mode} 不一致")
                    println("      如与事实不符请改用 --mode ${detected}，以免清理到错误的目录")
                }
            case None => ()
        }
        println("加载轨: ${mode}")
    }
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
        // L3 进程轨：CordisHostManager.deactivateProcessPlugin(name) 内部调用
        // cordisHost.removePlugin(name)，由 cordis 运行时发出 terminate 并回收 OS 资源
        // （父进程侧等待子进程句柄退出），不是简单地从表里摘掉条目。
        println("  [process 轨] 运行中的宿主经 CordisHostManager.deactivateProcessPlugin('${pluginName}') 终止插件进程")
        println("  plugins.yaml 已修改，需重启宿主进程使卸载在运行态生效")
        println("  或使用 Agent 工具 plugin_deactivate 执行运行态热卸载")
        println("  注意: --purge 只清理磁盘产物，进程内实例必须经上面两种方式之一回收，")
        println("        否则 .exe 会因被占用而删除失败（Windows 尤为常见）")
    } else {
        println("  plugins.yaml 已修改，需重启宿主进程使卸载生效")
        println("  或使用 Agent 工具 plugin_deactivate 执行运行态热卸载")
    }

    // Step 3: 可选删除插件目录
    // sync/dylib 轨产物在 plugins/<name>/；L3 进程轨产物在 skills/<name>/ 与发布态
    // bin/skills/<name>/、bin/plugins/<name>/，走独立清理路径（PS-T030）。
    if (purge) {
        if (mode == "process") {
            purgeProcessPlugin(pluginName, skillsRoot, binRoot, force)
        } else {
            let pluginDir = "${pluginsRoot}/${pluginName}"
            if (exists(Path(pluginDir))) {
                println("删除插件目录: ${pluginDir}")
                match (deleteDirectory(Path(pluginDir))) {
                    case true => println("  插件目录已删除")
                    case false => println("  警告: 删除失败（目录非空或文件被占用），请手动删除")
                }
            } else {
                println("警告: 插件目录不存在: ${pluginDir}")
            }
        }
    }

    println("插件卸载完成: ${pluginName}")
}

/**
 * 清理 L3 进程轨插件的磁盘产物（PS-T030）
 *
 * 与 sync 轨不同，进程插件的可执行文件与随包资源**不在 plugins/<name> 下**：
 *   - skills/<name>/      源码 + target/release/bin/skill_<name>.exe（开发态）
 *   - bin/skills/<name>/  发布态 exe + scripts/ 等随包资源（package_release 的 PS-T029 / PS-LRT-01）
 *   - bin/plugins/<name>/ 发布态清单副本（plugin.yaml + SKILL.md，PS-T016）
 *
 * 这三者都可能是一整棵含源码的目录树，故默认只列计划，须 --force 才真正删除。
 */
func purgeProcessPlugin(pluginName: String, skillsRoot: String, binRoot: String, force: Bool): Unit {
    let candidates = ArrayList<String>()
    candidates.add("${skillsRoot}/${pluginName}")
    candidates.add("${binRoot}/skills/${pluginName}")
    candidates.add("${binRoot}/plugins/${pluginName}")

    let targets = ArrayList<String>()
    for (dir in candidates) {
        if (!targets.contains(dir) && exists(Path(dir))) {
            targets.add(dir)
        }
    }

    if (targets.size == 0) {
        println("[L3] 未发现待清理目录（以下路径均不存在）:")
        for (dir in candidates) {
            println("       - ${dir}")
        }
        return
    }

    println("[L3] 进程轨待清理目录:")
    for (dir in targets) {
        println("       - ${dir}")
    }

    if (!force) {
        println("[L3] 以上内容含源码与构建产物，本次未执行删除。")
        println("      确认无误后追加 --force 重跑本命令即可真正清理。")
        return
    }

    println("[L3] 执行删除...")
    for (dir in targets) {
        match (deleteDirectory(Path(dir))) {
            case true => println("  [OK] 已删除: ${dir}")
            case false => println("  [WARN] 删除失败或文件被占用: ${dir}")
        }
    }

    // 收尾核对：仍存在的路径要显式告知（最常见原因是 .exe 被运行中进程占用）
    let residual = ArrayList<String>()
    for (dir in targets) {
        if (exists(Path(dir))) {
            residual.add(dir)
        }
    }
    if (residual.size > 0) {
        println("[L3] 以下目录仍存在，通常是插件进程仍在运行并占用了 .exe:")
        for (dir in residual) {
            println("       - ${dir}")
        }
        println("       请先经 plugin_deactivate 或重启宿主后再执行清理。")
    } else {
        println("[L3] 进程轨磁盘产物已全部清理")
    }
}

/**
 * 从 skills/<name>/plugin.yaml 读取加载轨（PS-T030）
 *
 * plugingen 的 process 轨会把 `mode: process` 写进 plugin.yaml，据此即可区分三轨。
 *
 * 返回：Some(<mode>)；文件不存在或未声明 mode 时返回 None
 */
func detectPluginMode(skillsRoot: String, pluginName: String): Option<String> {
    let yamlPath = Path("${skillsRoot}/${pluginName}/plugin.yaml")
    if (!exists(yamlPath)) {
        return None
    }
    match (readFileContent(yamlPath)) {
        case Some(content) => readModeFromYaml(content)
        case None => None
    }
}

/**
 * 从 plugin.yaml 文本中提取 `mode:` 取值。
 *
 * 用 trimAscii 后的整行等值判断而非 contains：注释行里出现的模式说明、
 * 或嵌套结构中的其它 mode 键都不应被误判，同时兼顾 YAML 的引号变体。
 */
func readModeFromYaml(content: String): Option<String> {
    let lines = content.split('\n')
    let arr = Array<String>(lines.size, { i => lines[i] })
    for (i in 0..arr.size) {
        let line = arr[i].trimAscii()
        if (line == "mode: process" || line == "mode: \"process\"" || line == "mode: 'process'") {
            return Some("process")
        }
        if (line == "mode: sync" || line == "mode: \"sync\"" || line == "mode: 'sync'") {
            return Some("sync")
        }
        if (line == "mode: dylib" || line == "mode: \"dylib\"" || line == "mode: 'dylib'") {
            return Some("dylib")
        }
    }
    None
}

/**
 * 判断某行是否为 `<pluginName>` 的条目起始行（PS-T030 修复）
 *
 * 原实现用 contains 做子串判定，`- name: entity-ext` 会被
 * `contains("- name: entity")` 命中，导致卸载 entity 时把 **entity-ext**
 * 的条目整段删除——清单顺序越靠后越容易踩到。改为整行等值比较。
 */
func isPluginEntryLine(line: String, pluginName: String): Bool {
    let trimmed = line.trimAscii()
    if (trimmed == "- name: ${pluginName}") {
        return true
    }
    if (trimmed == "- name: \"${pluginName}\"") {
        return true
    }
    if (trimmed == "- name: '${pluginName}'") {
        return true
    }
    return false
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
        // 精确等值匹配（见 isPluginEntryLine）：原先用 contains 做子串判定，
        // 卸载 `entity` 时会命中 `- name: entity-ext` 这一行，误删另一个插件的条目。
        if (isPluginEntryLine(line, pluginName)) {
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
    println("                          缺省时自动从 <skills-root>/<插件名>/plugin.yaml 的 mode 识别")
    println("  --purge                  同时删除插件目录")
    println("                            sync/dylib 轨: plugins/<name>/")
    println("                            process 轨  : skills/<name>/ + bin/skills/<name>/ + bin/plugins/<name>/")
    println("  --force                  允许 --purge 真正执行 process 轨的递归删除（否则只列计划）")
    println("  --config <路径>          plugins.yaml 路径（默认: ./plugins.yaml）")
    println("  --plugins-root <路径>    插件根目录，sync/dylib 轨用（默认: ./plugins）")
    println("  --skills-root <路径>     技能根目录，process 轨源码树（默认: ./skills）")
    println("  --bin-root <路径>        发布包 bin 目录，process 轨发布态产物（默认: ./bin）")
    println("  --help, -h               显示帮助信息")
    println("")
    println("示例:")
    println("  pluginuninstall --name entity")
    println("  pluginuninstall --name entity --purge")
    println("  pluginuninstall --name entity --config ./config/plugins.yaml")
    println("")
    println("  # L3 进程轨：识别 mode 后先列出待清理计划，确认无误再加 --force")
    println("  pluginuninstall --name long-running-task --purge")
    println("  pluginuninstall --name long-running-task --purge --force")
}
