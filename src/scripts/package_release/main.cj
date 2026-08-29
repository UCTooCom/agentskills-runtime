/*
 * Copyright (c) UCToo Co., Ltd. 2024-2026. All rights reserved.
 */
package magic.scripts.package_release

import std.fs.*
import std.process.{launch, ProcessRedirect, SubProcess}
import std.convert.*
import std.collection.ArrayList
import std.env.getVariable
import std.time.DateTime
import std.unicode.*

func getVersionFromCjpm(): String {
    let cjpmPath = Path("./cjpm.toml")
    if (exists(cjpmPath)) {
        try {
            let contentBytes = File.readFrom(cjpmPath)
            let content = String.fromUtf8(contentBytes)
            let lines = content.split('\n')
            for (line in lines) {
                if (line.trim().startsWith("version = ")) {
                    let versionPart = line.trim()["version = ".size..]
                    let version = versionPart.trim().replace("\"", "")
                    return version
                }
            }
        } catch (e: Exception) {
            println("[WARN] Failed to read version from cjpm.toml: ${e.message}")
        }
    }
    return "0.0.1"
}

func getPlatformSuffix(): String {
    let os = getVariable("OS")
    if (os.isSome()) {
        let osName = os.getOrThrow()
        let osLower = osName.toLower()
        if (osLower.contains("windows") || osLower.contains("win")) {
            return ".exe"
        }
    }
    return ""
}

func getCurrentPlatform(): String {
    let os = getVariable("OS")
    let arch = getVariable("PROCESSOR_ARCHITECTURE")
    
    if (os.isSome()) {
        let osName = os.getOrThrow()
        let osLower = osName.toLower()
        let archName = if (arch.isSome()) { 
            let archValue = arch.getOrThrow()
            archValue.toLower() 
        } else { 
            "x64" 
        }
        
        if (osLower.contains("windows") || osLower.contains("win")) {
            if (archName.contains("arm64") || archName.contains("aarch64")) {
                return "win-arm64"
            }
            return "win-x64"
        }
    }
    return "win-x64"
}

func getProjectRoot(): ?Path {
    var currentDir = canonicalize(Path("."))
    
    for (i in 0..10) {
        let cjpmPath = Path("${currentDir}/cjpm.toml")
        if (exists(cjpmPath)) {
            return currentDir
        }
        let parent = currentDir.parent
        if (parent.isEmpty()) {
            break
        }
        currentDir = parent
    }
    return None
}

func shouldExcludeDll(name: String): Bool {
    let excludePatterns = [
        "libmagic.examples.",
        "libmagic.test_",
        "libmagic.tests.",
        "magic.examples.",
        "magic.test_",
        "magic.tests."
    ]
    
    for (pattern in excludePatterns) {
        if (name.contains(pattern)) {
            return true
        }
    }
    return false
}

func shouldExcludeDirectory(dirName: String): Bool {
    let excludeDirs = [
        "examples",
        "test_",
        "tests",
        ".build-logs",
        ".bin-cache",
        ".cjpm-history"
    ]
    
    for (pattern in excludeDirs) {
        if (dirName.contains(pattern)) {
            return true
        }
    }
    return false
}

/// 安全复制文件到目标路径（支持自动创建目标父目录；存在冲突时可选覆盖）
func safeCopy(from: String, to: String, overwrite: Bool): Bool {
    try {
        // 自动创建目标父目录，避免 copy 到不存在的子目录抛错
        let dest = Path(to)
        let destParent = dest.parent
        // Path.parent 空路径时返回空 Path，用 isEmpty() 判断（见同文件 L80 获取 cjpm 根目录的用法）
        if (!destParent.isEmpty()) {
            if (!exists(destParent)) {
                Directory.create(destParent, recursive: true)
            }
        }
        copy(from, to: to, overwrite: overwrite)
        return true
    } catch (e: Exception) {
        println("  [WARN] Failed to copy ${from} -> ${to}: ${e.message}")
        return false
    }
}

// ===== PS-T016: 插件清单打包适配 =====

/**
 * PluginInfo - plugin.yaml 元信息（plugin_manifest.json 数据载体）
 */
class PluginInfo {
    var name: String = ""
    var version: String = ""
    var description: String = ""
    var entry: String = ""
    var dependencies: String = ""
    var tables: ArrayList<String> = ArrayList<String>()
    var routes: ArrayList<String> = ArrayList<String>()
}

/// JSON 字符串转义（引号/反斜杠/控制字符）
func jsonEscape(s: String): String {
    var result = s.replace("\\", "\\\\")
    result = result.replace("\"", "\\\"")
    result = result.replace("\n", "\\n")
    result = result.replace("\r", "\\r")
    result = result.replace("\t", "\\t")
    return result
}

/// 去除标量值两端成对的单/双引号
func stripPairedQuotes(s: String): String {
    if (s.size >= 2) {
        if ((s.startsWith("\"") && s.endsWith("\"")) || (s.startsWith("'") && s.endsWith("'"))) {
            return s[1..s.size - 1]
        }
    }
    return s
}

/// 从 plugin.yaml 文本解析插件元信息（轻量行级解析，避免链接 yaml4cj；name 缺失返回 None）
func parsePluginYaml(content: String): Option<PluginInfo> {
    let info = PluginInfo()
    // 当前行归属的块列表：0=无 1=tables 2=routes（skills 等其他列表不采集）
    var listTarget = 0
    for (rawLine in content.split("\n")) {
        let line = rawLine.trim()
        if (line.size == 0 || line.startsWith("#")) {
            continue
        }
        if (line.startsWith("- ")) {
            let item = stripPairedQuotes(line["- ".size..].trim())
            if (item.size > 0 && listTarget == 1) {
                info.tables.add(item)
            } else if (item.size > 0 && listTarget == 2) {
                info.routes.add(item)
            }
            continue
        }
        let colonIdx = line.indexOf(":")
        if (colonIdx.isNone()) {
            listTarget = 0
            continue
        }
        let idx = colonIdx.getOrThrow()
        let key = line[0..idx].trim()
        let valueRaw = if (idx + 1 < line.size) { line[idx + 1..line.size] } else { "" }
        let value = stripPairedQuotes(valueRaw.trim())
        if (key == "name") {
            info.name = value
            listTarget = 0
        } else if (key == "version") {
            info.version = value
            listTarget = 0
        } else if (key == "description") {
            info.description = value
            listTarget = 0
        } else if (key == "entry") {
            info.entry = value
            listTarget = 0
        } else if (key == "dependencies") {
            info.dependencies = value
            listTarget = 0
        } else if (key == "tables") {
            listTarget = 1
        } else if (key == "routes") {
            listTarget = 2
        } else {
            listTarget = 0
        }
    }
    if (info.name.isEmpty()) {
        return None<PluginInfo>
    }
    return Some(info)
}

/// JSON 字符串数组序列化（["a","b"]）
func jsonStringArray(items: ArrayList<String>): String {
    let sb = StringBuilder()
    sb.append("[")
    for (i in 0..items.size) {
        if (i > 0) {
            sb.append(",")
        }
        sb.append("\"${jsonEscape(items[i])}\"")
    }
    sb.append("]")
    return sb.toString()
}

/// 生成 plugin_manifest.json 内容（记录所有已打包插件的元信息）
func buildPluginManifestJson(infos: ArrayList<PluginInfo>): String {
    let sb = StringBuilder()
    sb.append("[\n")
    for (i in 0..infos.size) {
        let info = infos[i]
        sb.append("  {\n")
        sb.append("    \"name\": \"${jsonEscape(info.name)}\",\n")
        sb.append("    \"version\": \"${jsonEscape(info.version)}\",\n")
        sb.append("    \"description\": \"${jsonEscape(info.description)}\",\n")
        sb.append("    \"entry\": \"${jsonEscape(info.entry)}\",\n")
        sb.append("    \"dependencies\": \"${jsonEscape(info.dependencies)}\",\n")
        sb.append("    \"tables\": ${jsonStringArray(info.tables)},\n")
        sb.append("    \"routes\": ${jsonStringArray(info.routes)}\n")
        sb.append("  }")
        if (i < infos.size - 1) {
            sb.append(",")
        }
        sb.append("\n")
    }
    sb.append("]\n")
    return sb.toString()
}

main(args: Array<String>): Unit {
    println("========================================")
    println("AgentSkills Runtime Package Script")
    println("========================================")
    println("")
    
    let projectRoot = getProjectRoot()
    if (projectRoot.isNone()) {
        println("[ERROR] Could not find project root (directory containing cjpm.toml)")
        println("Please run this script from the project root directory or a subdirectory.")
        return
    }
    
    let rootPath = projectRoot.getOrThrow()
    println("[INFO] Project root: ${rootPath}")
    
    let version = getVersionFromCjpm()
    let platform = if (args.size > 0) { args[0] } else { getCurrentPlatform() }
    let buildDate = DateTime.now().toString()
    
    let targetDir = Path("${rootPath}/target/release")
    let releaseDir = Path("${rootPath}/release")
    let binDir = Path("${targetDir}/bin")
    
    println("Version: ${version}")
    println("Platform: ${platform}")
    println("Target dir: ${targetDir}")
    println("")
    
    if (!exists(targetDir)) {
        println("[ERROR] Build directory not found: ${targetDir}")
        println("Please run 'cjpm build' first from the project root directory.")
        return
    }
    
    if (!exists(releaseDir)) {
        Directory.create(releaseDir, recursive: true)
        println("[INFO] Created release directory: ${releaseDir}")
    }
    
    let totalDlls = ArrayList<String>()
    let excludedDlls = ArrayList<String>()
    
    println("")
    println("[STEP] Copying magic DLLs to bin (excluding examples/tests)...")
    
    let magicDir = Path("${targetDir}/magic")
    if (exists(magicDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(magicDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    if (shouldExcludeDll(name)) {
                        excludedDlls.add(name)
                        return true
                    }
                    
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} magic DLLs to bin/")
        if (excludedDlls.size > 0) {
            println("  [INFO] Excluded ${excludedDlls.size.toString()} example/test DLLs")
        }
    } else {
        println("  [WARN] Directory not found: ${magicDir}")
    }
    
    println("")
    println("[STEP] Copying commonmark4cj DLLs to bin...")
    
    let commonmarkDir = Path("${targetDir}/commonmark4cj")
    if (exists(commonmarkDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(commonmarkDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} commonmark4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${commonmarkDir}")
    }
    
    println("")
    println("[STEP] Copying json4cj DLLs to bin...")
    
    let jsonDir = Path("${targetDir}/json4cj")
    if (exists(jsonDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(jsonDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    if (shouldExcludeDll(name)) {
                        excludedDlls.add(name)
                        return true
                    }
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} json4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${jsonDir}")
    }
    
    println("")
    println("[STEP] Copying yaml4cj DLLs to bin...")
    
    let yamlDir = Path("${targetDir}/yaml4cj")
    if (exists(yamlDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(yamlDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} yaml4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${yamlDir}")
    }
    
    println("")
    println("[STEP] Copying f_orm DLLs to bin...")
    
    let fOrmDir = Path("${targetDir}/f_orm")
    if (exists(fOrmDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(fOrmDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} f_orm DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${fOrmDir}")
    }
    
    println("")
    println("[STEP] Copying charset4cj DLLs to bin...")
    
    let charsetDir = Path("${targetDir}/charset4cj")
    if (exists(charsetDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(charsetDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} charset4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${charsetDir}")
    }
    
    println("")
    println("[STEP] Copying jwt4cj DLLs to bin...")
    
    let jwtDir = Path("${targetDir}/jwt4cj")
    if (exists(jwtDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(jwtDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} jwt4cj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${jwtDir}")
    }
    
    println("")
    println("[STEP] Copying logcj DLLs to bin...")
    
    let logDir = Path("${targetDir}/logcj")
    if (exists(logDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(logDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} logcj DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${logDir}")
    }
    
    println("")
    println("[STEP] Copying f_data DLLs to bin...")
    
    let fDataDir = Path("${targetDir}/f_data")
    if (exists(fDataDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(fDataDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} f_data DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${fDataDir}")
    }
    
    println("")
    println("[STEP] Copying f_config DLLs to bin...")
    
    let fConfigDir = Path("${targetDir}/f_config")
    if (exists(fConfigDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(fConfigDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} f_config DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${fConfigDir}")
    }
    
    println("")
    println("[STEP] Copying opengauss DLLs to bin...")
    
    let opengaussDir = Path("${targetDir}/opengauss")
    if (exists(opengaussDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(opengaussDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} opengauss DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${opengaussDir}")
    }
    
    println("")
    println("[STEP] Copying blowfish DLLs to bin...")
    
    let blowfishDir = Path("${targetDir}/blowfish")
    if (exists(blowfishDir) && exists(binDir)) {
        let dllCount = ArrayList<String>()
        
        Directory.walk(blowfishDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                    dllCount.add(name)
                    totalDlls.add(name)
                }
            }
            true
        }
        
        println("  [OK] Copied ${dllCount.size.toString()} blowfish DLLs to bin/")
    } else {
        println("  [WARN] Directory not found: ${blowfishDir}")
    }
    
    // Copy 0.0.26+ dependency DLLs (http_lib + 7 transitive deps are static libs, no DLL output, skipped here)
    // cos produces DLLs; pgsql/cj_mail/activemq4cj/hyperion are CJO-only, walk yields 0 DLLs harmlessly
    let extraDeps = ["cos", "pgsql", "cj_mail", "activemq4cj", "hyperion"]
    for (depName in extraDeps) {
        println("")
        println("[STEP] Copying ${depName} DLLs to bin...")
        
        let depDir = Path("${targetDir}/${depName}")
        if (exists(depDir) && exists(binDir)) {
            let dllCount = ArrayList<String>()
            
            Directory.walk(depDir.toString()) { fileInfo =>
                if (!fileInfo.isDirectory()) {
                    let name = fileInfo.path.fileName
                    
                    if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                        let destPath = Path("${binDir}/${name}")
                        safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
                true
            }
            
            println("  [OK] Copied ${dllCount.size.toString()} ${depName} DLLs to bin/")
        } else {
            println("  [WARN] Directory not found: ${depDir}")
        }
    }
    
    // Copy all remaining Fountain framework modules
    let fountainModules = [
        "f_aspect", "f_base", "f_bean", "f_cache", "f_cmd", 
        "f_collection", "f_concurrent", "f_exception", "f_io", 
        "f_log", "f_macros", "f_mockdb", "f_pool", 
        "f_random", "f_regex", "f_ticktock", "f_time", "f_util", "f_version"
    ]
    
    for (moduleName in fountainModules) {
        println("")
        println("[STEP] Copying ${moduleName} DLLs to bin...")
        
        let moduleDir = Path("${targetDir}/${moduleName}")
        if (exists(moduleDir) && exists(binDir)) {
            let dllCount = ArrayList<String>()
            
            Directory.walk(moduleDir.toString()) { fileInfo =>
                if (!fileInfo.isDirectory()) {
                    let name = fileInfo.path.fileName
                    
                    if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                        let destPath = Path("${binDir}/${name}")
                        safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                        dllCount.add(name)
                        totalDlls.add(name)
                    }
                }
                true
            }
            
            println("  [OK] Copied ${dllCount.size.toString()} ${moduleName} DLLs to bin/")
        } else {
            println("  [WARN] Directory not found: ${moduleDir}")
        }
    }
    
    println("")
    println("[STEP] Copying cangjie-stdx libraries to bin...")
    
    let stdxDynamicPath = getVariable("CANGJIE_STDX_DYNAMIC_PATH")
    let stdxDir = if (stdxDynamicPath.isSome()) {
        let p = stdxDynamicPath.getOrThrow()
        Path("${p}/windows_x86_64_cjnative/dynamic/stdx")
    } else {
        // 优先使用 1.1.3.1（cjc 1.1.3 升级后的版本），回退到 1.0.5.1
        let v113 = Path("${rootPath}/libs/cangjie-stdx-windows-x64-1.1.3.1/windows_x86_64_cjnative/dynamic/stdx")
        if (exists(v113)) {
            v113
        } else {
            Path("${rootPath}/libs/cangjie-stdx-windows-x64-1.0.5.1/windows_x86_64_cjnative/dynamic/stdx")
        }
    }
    if (exists(stdxDir) && exists(binDir)) {
        let stdxCount = ArrayList<String>()
        
        Directory.walk(stdxDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    let destPath = Path("${binDir}/${name}")
                    if (!exists(destPath)) {
                        if (safeCopy(fileInfo.path.toString(), destPath.toString(), true)) {
                            stdxCount.add(name)
                            totalDlls.add(name)
                        }
                    }
                }
            }
            true
        }
        
        println("  [OK] Copied ${stdxCount.size.toString()} stdx DLLs to bin/")
    } else {
        println("  [WARN] stdx directory not found: ${stdxDir}")
    }
    
    println("")
    println("[STEP] Copying cangjie runtime libraries to bin...")
    println("  [INFO] Only copying DLLs not already in bin/ (build outputs are authoritative)")
    
    let cangjieHome = getVariable("CANGJIE_HOME")
    if (cangjieHome.isSome()) {
        let home = cangjieHome.getOrThrow()
        let runtimeDir = Path("${home}/runtime/lib/windows_x86_64_cjnative")
        if (exists(runtimeDir) && exists(binDir)) {
            let runtimeCount = ArrayList<String>()
            let runtimeSkipped = ArrayList<String>()
            
            Directory.walk(runtimeDir.toString()) { fileInfo =>
                if (!fileInfo.isDirectory()) {
                    let name = fileInfo.path.fileName
                    
                    if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                        let destPath = Path("${binDir}/${name}")
                        if (!exists(destPath)) {
                            if (safeCopy(fileInfo.path.toString(), destPath.toString(), true)) {
                                runtimeCount.add(name)
                                totalDlls.add(name)
                            }
                        } else {
                            runtimeSkipped.add(name)
                        }
                    }
                }
                true
            }
            
            println("  [OK] Copied ${runtimeCount.size.toString()} new runtime DLLs to bin/")
            if (runtimeSkipped.size > 0) {
                println("  [INFO] Skipped ${runtimeSkipped.size.toString()} existing runtime DLLs (already in bin/)")
            }
        } else {
            println("  [WARN] runtime directory not found: ${runtimeDir}")
        }
    } else {
        println("  [WARN] CANGJIE_HOME environment variable not set")
        println("  [INFO] Please ensure CANGJIE runtime DLLs are available in PATH")
    }
    
    println("")
    println("[STEP] Copying LLVM/MinGW runtime DLLs to bin and release root...")
    
    if (cangjieHome.isSome()) {
        let home = cangjieHome.getOrThrow()
        let llvmRtDirs = [
            Path("${home}/third_party/llvm/bin"),
            Path("${home}/third_party/mingw/bin"),
            Path("${home}/tools/bin")
        ]
        let rtCount = ArrayList<String>()
        
        for (rtDir in llvmRtDirs) {
            if (exists(rtDir)) {
                Directory.walk(rtDir.toString()) { fileInfo =>
                    if (!fileInfo.isDirectory()) {
                        let name = fileInfo.path.fileName
                        
                        if (name.endsWith(".dll")) {
                            let destBin = Path("${binDir}/${name}")
                            if (!exists(destBin)) {
                                if (safeCopy(fileInfo.path.toString(), destBin.toString(), true)) {
                                    rtCount.add(name)
                                    totalDlls.add(name)
                                }
                            }
                            safeCopy(fileInfo.path.toString(), Path("${targetDir}/${name}").toString(), true)
                        }
                    }
                    true
                }
            }
        }
        
        if (rtCount.size > 0) {
            println("  [OK] Copied ${rtCount.size.toString()} LLVM/MinGW runtime DLLs to bin/ and release root")
        } else {
            println("  [WARN] No LLVM/MinGW runtime DLLs found")
        }
    }
    
    println("")
    println("[STEP] Creating SSL directory structure...")
    
    // Create SSL directories (but DO NOT copy actual certificates - they are sensitive)
    let sslDest = Path("${targetDir}/ssl")
    let sslBinDest = Path("${binDir}/ssl")
    
    if (!exists(sslDest)) {
        Directory.create(sslDest, recursive: true)
        println("  [OK] Created ssl directory in release root")
    }
    
    if (!exists(sslBinDest)) {
        Directory.create(sslBinDest, recursive: true)
        println("  [OK] Created ssl directory in bin")
    }
    
    // Create README in ssl directory to guide users
    let sslReadme = """
# SSL Certificates Directory

This directory should contain your SSL certificates for HTTPS support.

## Required Files

- `server.crt` - SSL certificate file
- `server.key` - SSL private key file

## How to Generate Self-Signed Certificates (for development)

```bash
# Using OpenSSL
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes

# Or using the provided script
../bin/generate_ssl_cert.sh
```

## Production Use

For production, use certificates from a trusted CA like Let's Encrypt:

```bash
# Using certbot
certbot certonly --standalone -d yourdomain.com
```

Then copy the certificates to this directory:
- `fullchain.pem` -> `server.crt`
- `privkey.pem` -> `server.key`

## Security Note

**NEVER commit actual SSL certificates to version control!**
"""
    
    let sslReadmePath = Path("${sslDest}/README.md")
    File.writeTo(sslReadmePath, sslReadme.toArray())
    println("  [OK] Created SSL README with instructions")
    
    let sslReadmeBinPath = Path("${sslBinDest}/README.md")
    File.writeTo(sslReadmeBinPath, sslReadme.toArray())
    println("  [OK] Created SSL README in bin directory")
    
    // Note: Actual SSL certificates should NOT be packaged
    println("  [INFO] SSL certificates will NOT be packaged (sensitive information)")
    println("  [INFO] Users should generate or copy their own certificates")
    
    println("")
    println("[STEP] Creating logs directory...")
    
    let logsDir = Path("${targetDir}/logs")
    let logsBinDir = Path("${binDir}/logs")
    
    if (!exists(logsDir)) {
        Directory.create(logsDir, recursive: true)
        println("  [OK] Created logs directory in release")
    }
    
    if (!exists(logsBinDir)) {
        Directory.create(logsBinDir, recursive: true)
        println("  [OK] Created logs directory in bin")
    }
    
    println("")
    println("[STEP] Copying CJO files to bin...")
    
    let cjoCount = ArrayList<String>()
    
    // Copy all CJO files from target/release subdirectories to bin
    Directory.walk(targetDir.toString()) { fileInfo =>
        if (!fileInfo.isDirectory()) {
            let name = fileInfo.path.fileName
            
            // Skip if already in bin directory
            let parentPath = fileInfo.path.parent
            if (parentPath.toString() == binDir.toString()) {
                return true
            }
            
            if (name.endsWith(".cjo")) {
                let destPath = Path("${binDir}/${name}")
                safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                cjoCount.add(name)
            }
        }
        true
    }
    
    println("  [OK] Copied ${cjoCount.size.toString()} CJO files to bin/")

    // ===== PS-T016: 插件产物识别验证（target/release/magic/plugins/）=====
    // 插件产物（包名 magic.plugins.{name}）落在 magic/plugins/ 子树，
    // 上方 DLL walk（递归 magic/ 全目录）与 CJO walk（递归 target/ 全目录）
    // 已自动收集；排除规则 shouldExcludeDll 只匹配 examples/tests 前缀，
    // magic.plugins.* 产物不受影响。此处显式计数核验覆盖情况。
    println("")
    println("[STEP] Verifying plugin build artifacts (magic/plugins/)...")
    let pluginDlls = ArrayList<String>()
    let pluginCjos = ArrayList<String>()
    let pluginArtifactDir = Path("${targetDir}/magic/plugins")
    if (exists(pluginArtifactDir)) {
        Directory.walk(pluginArtifactDir.toString()) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    pluginDlls.add(name)
                } else if (name.endsWith(".cjo")) {
                    pluginCjos.add(name)
                }
            }
            true
        }
        println("  [OK] Plugin artifacts covered by bin copy: ${pluginDlls.size.toString()} DLLs, ${pluginCjos.size.toString()} CJOs")
    } else {
        println("  [INFO] No plugin artifacts (magic/plugins/ not found, L1 plugin code is statically linked)")
    }

    // ===== PS-T016: 插件清单打包（skills/*/plugin.yaml -> bin/plugins/{name}/）=====
    println("")
    println("[STEP] Packaging plugin manifests (skills/ -> bin/plugins/)...")
    let skillsDir = Path("${rootPath}/skills")
    let pluginsBinDir = Path("${binDir}/plugins")
    let packagedPlugins = ArrayList<PluginInfo>()
    if (exists(skillsDir)) {
        // 目录存在时跳过创建，避免重复打包时抛 "The path of directory exists" 异常
        if (!exists(pluginsBinDir)) {
            Directory.create(pluginsBinDir, recursive: true)
        }

        // 发现含 plugin.yaml 的技能插件目录（skills/{name}/plugin.yaml）
        let pluginNames = ArrayList<String>()
        let skillsRootNorm = skillsDir.toString().replace("\\", "/")
        Directory.walk(skillsDir.toString()) { fileInfo =>
            if (fileInfo.isDirectory()) {
                let dir = fileInfo.path.toString()
                let dirNorm = dir.replace("\\", "/")
                if (dirNorm != skillsRootNorm && exists("${dir}/plugin.yaml")) {
                    let parts = dirNorm.split("/")
                    let lastName = parts[parts.size - 1]
                    if (!lastName.isEmpty() && !pluginNames.contains(lastName)) {
                        pluginNames.add(lastName)
                    }
                }
            }
            true
        }

        if (pluginNames.size == 0) {
            println("  [INFO] No plugin manifests found under skills/")
        } else {
            for (pluginName in pluginNames) {
                // 复制 plugin.yaml（插件静态元数据，按需启用/禁用的载体）
                let yamlSrc = Path("${rootPath}/skills/${pluginName}/plugin.yaml")
                let yamlDest = Path("${pluginsBinDir}/${pluginName}/plugin.yaml")
                if (safeCopy(yamlSrc.toString(), yamlDest.toString(), true)) {
                    // 解析元信息登记 manifest
                    try {
                        let yamlContent = String.fromUtf8(File.readFrom(yamlSrc))
                        match (parsePluginYaml(yamlContent)) {
                            case Some(info) => packagedPlugins.add(info)
                            case None => println("  [WARN] plugin.yaml missing 'name', skipped from manifest: ${pluginName}")
                        }
                    } catch (e: Exception) {
                        println("  [WARN] Failed to read ${yamlSrc.toString()}: ${e.message}")
                    }
                }

                // 复制 SKILL.md（SkillBridge 运行时扫描 plugins/<name>/SKILL.md）
                let skillSrc = Path("${rootPath}/skills/${pluginName}/SKILL.md")
                if (exists(skillSrc)) {
                    let skillDest = Path("${pluginsBinDir}/${pluginName}/SKILL.md")
                    safeCopy(skillSrc.toString(), skillDest.toString(), true)
                }
            }
            println("  [OK] Packaged ${packagedPlugins.size.toString()} plugin manifest(s) to bin/plugins/")
        }
    } else {
        println("  [INFO] skills/ directory not found, skip plugin manifests")
    }

    // ===== PS-T029: L3 进程插件可执行文件打包 =====
    // cordis-cj 进程轨插件（skills/{name}/target/release/bin/skill_{name}.exe）
    // 需要被打包到 bin/skills/{name}/ 下，以便宿主在发布包中能找到并启动进程插件
    println("")
    println("[STEP] Packaging L3 process plugin executables (skills/ -> bin/skills/)...")
    let skillsBinDir = Path("${binDir}/skills")
    let processPluginCount = ArrayList<String>()
    if (exists(skillsDir)) {
        if (!exists(skillsBinDir)) {
            Directory.create(skillsBinDir, recursive: true)
        }
        // 遍历 skills/ 下的每个插件目录
        Directory.walk(skillsDir.toString()) { fileInfo =>
            if (fileInfo.isDirectory()) {
                let pluginDir = fileInfo.path.toString()
                let pluginDirNorm = pluginDir.replace("\\", "/")
                let parts = pluginDirNorm.split("/")
                let pluginName = parts[parts.size - 1]
                // 查找 skill_{name}.exe 可执行文件
                let pluginExeDir = Path("${pluginDir}/target/release/bin")
                if (exists(pluginExeDir)) {
                    Directory.walk(pluginExeDir.toString()) { exeInfo =>
                        if (!exeInfo.isDirectory()) {
                            let exeName = exeInfo.path.fileName
                            if (exeName.endsWith(".exe") && exeName.startsWith("skill_")) {
                                let destPluginDir = Path("${skillsBinDir}/${pluginName}/target/release/bin")
                                if (!exists(destPluginDir)) {
                                    Directory.create(destPluginDir, recursive: true)
                                }
                                let destExe = Path("${destPluginDir}/${exeName}")
                                if (safeCopy(exeInfo.path.toString(), destExe.toString(), true)) {
                                    processPluginCount.add("${pluginName}/${exeName}")
                                }
                            }
                        }
                        true
                    }
                }
            }
            true
        }
        if (processPluginCount.size > 0) {
            println("  [OK] Packaged ${processPluginCount.size.toString()} L3 process plugin executable(s):")
            for (exePath in processPluginCount) {
                println("         - ${exePath}")
            }
        } else {
            println("  [INFO] No L3 process plugin executables found")
        }
    } else {
        println("  [INFO] skills/ directory not found, skip L3 process plugin executables")
    }

    // ===== PS-T029: cordis-cj 依赖库 DLL 打包 =====
    // cordis-cj 的传递依赖（jsonvalue、jsonrpc）和 cordis-cj 本身的产物
    // 需要被打包到 bin/ 下，以便进程插件运行时能找到这些 DLL
    println("")
    println("[STEP] Copying cordis-cj dependency DLLs to bin...")
    let cordisDeps = ["jsonvalue", "jsonrpc", "cordis_core", "cordis_host", "cordis_plugin"]
    for (depName in cordisDeps) {
        let depDir = Path("${targetDir}/${depName}")
        if (exists(depDir) && exists(binDir)) {
            let dllCount = ArrayList<String>()
            Directory.walk(depDir.toString()) { fileInfo =>
                if (!fileInfo.isDirectory()) {
                    let name = fileInfo.path.fileName
                    if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                        let destPath = Path("${binDir}/${name}")
                        if (safeCopy(fileInfo.path.toString(), destPath.toString(), true)) {
                            dllCount.add(name)
                            totalDlls.add(name)
                        }
                    }
                }
                true
            }
            if (dllCount.size > 0) {
                println("  [OK] Copied ${dllCount.size.toString()} ${depName} DLLs to bin/")
            }
        }
    }

    // ===== PS-T016: 生成 plugin_manifest.json =====
    println("")
    println("[STEP] Generating plugin_manifest.json...")
    let manifestPath = Path("${pluginsBinDir}/plugin_manifest.json")
    if (packagedPlugins.size > 0) {
        try {
            File.writeTo(manifestPath, buildPluginManifestJson(packagedPlugins).toArray())
            println("  [OK] Wrote ${packagedPlugins.size.toString()} plugin entries to ${manifestPath.toString()}")
        } catch (e: Exception) {
            println("  [WARN] Failed to write plugin_manifest.json: ${e.message}")
        }
    } else {
        println("  [INFO] No packaged plugins, plugin_manifest.json not generated")
    }
    
    println("")
    println("[STEP] Creating entry point...")
    
    let entryExe = Path("${binDir}/agentskills-runtime.exe")
    let appExe = Path("${binDir}/magic.app.exe")
    if (exists(appExe)) {
        safeCopy(appExe.toString(), entryExe.toString(), true)
        println("  [OK] Created agentskills-runtime.exe from magic.app.exe")
    } else if (exists(entryExe)) {
        println("  [OK] agentskills-runtime.exe already exists")
    } else {
        println("  [WARN] magic.app.exe not found, entry point may be missing")
    }
    
    println("")
    println("[STEP] Copying .env.example...")
    
    // Copy .env.example to release root (configuration template)
    let envExampleSrc = Path("${rootPath}/.env.example")
    let envExampleDest = Path("${targetDir}/.env.example")
    if (exists(envExampleSrc)) {
        safeCopy(envExampleSrc.toString(), envExampleDest.toString(), true)
        println("  [OK] Copied .env.example to release package")
        
        // Also copy to bin directory for convenience
        let envExampleBinDest = Path("${binDir}/.env.example")
        safeCopy(envExampleSrc.toString(), envExampleBinDest.toString(), true)
        println("  [OK] Copied .env.example to bin directory")
    } else {
        println("  [WARN] .env.example not found at ${envExampleSrc}, skipping")
    }
    
    // Note: .env file should NOT be packaged as it contains sensitive information
    // Users should create .env from .env.example after extracting the package
    println("  [INFO] .env file will NOT be packaged (contains sensitive information)")
    println("  [INFO] Users should create .env from .env.example after extraction")
    
    println("")
    println("[STEP] Updating package.json runtime version...")
    
    let packageJsonPath = Path("${rootPath}/sdk/javascript/package.json")
    if (exists(packageJsonPath)) {
        try {
            let packageJsonBytes = File.readFrom(packageJsonPath)
            let packageJsonContent = String.fromUtf8(packageJsonBytes)
            let updatedContent = packageJsonContent.replace(
                "\"version\": \"${version}\"",
                "\"version\": \"${version}\""
            )
            let versionPattern = "\"runtime\": {\n    \"version\": \""
            let versionEndPattern = "\","
            let startIdx = updatedContent.indexOf(versionPattern)
            if (startIdx.isSome()) {
                let start = startIdx.getOrThrow() + versionPattern.size
                let endIdx = updatedContent.indexOf(versionEndPattern, start)
                if (endIdx.isSome()) {
                    let end = endIdx.getOrThrow()
                    let oldVersion = updatedContent[start..end]
                    if (oldVersion != version) {
                        let beforeVersion = updatedContent[0..start]
                        let afterVersion = updatedContent[end..updatedContent.size]
                        let newContent = beforeVersion + version + afterVersion
                        File.writeTo(packageJsonPath, newContent.toArray())
                        println("  [OK] Updated runtime version in package.json: ${oldVersion} -> ${version}")
                    } else {
                        println("  [OK] Runtime version already up to date: ${version}")
                    }
                }
            }
        } catch (e: Exception) {
            println("  [WARN] Could not update package.json: ${e.message}")
        }
    } else {
        println("  [WARN] package.json not found at ${packageJsonPath}")
    }
    
    println("")
    println("[STEP] Removing unnecessary directories from release package...")
    
    let dirsToRemove = ["examples", "tests", ".build-logs", ".bin-cache", ".cjpm-history"]
    for (dirName in dirsToRemove) {
        let dirPath = Path("${targetDir}/${dirName}")
        if (exists(dirPath)) {
            try {
                remove(dirPath, recursive: true)
                println("  [OK] Removed: ${dirName}/")
            } catch (e: Exception) {
                println("  [WARN] Could not remove ${dirName}: ${e.message}")
            }
        }
    }
    
    println("")
    println("[STEP] Creating archive...")
    
    let archiveName = "agentskills-runtime-${platform}.tar.gz"
    let archivePath = Path("${releaseDir}/${archiveName}")
    
    let tarArgs = ["-czf", archivePath.toString(), "-C", "${rootPath}/target", "release"]
    let tarProcess = launch("tar", tarArgs)
    let exitCode = tarProcess.wait()
    
    if (exitCode == 0) {
        println("  [OK] Archive created: ${releaseDir}/${archiveName}")
    } else {
        println("  [ERROR] Failed to create archive (exit code: ${exitCode.toString()})")
        return
    }
    
    println("")
    println("========================================")
    println("Package completed successfully!")
    println("========================================")
    println("Output: ${releaseDir}/${archiveName}")
    println("Version: ${version}")
    println("Platform: ${platform}")
    println("Build Date: ${buildDate}")
    println("Total DLLs copied: ${totalDlls.size.toString()}")
    println("Total CJOs copied: ${cjoCount.size.toString()}")
    println("Plugin manifests packaged: ${packagedPlugins.size.toString()}")
    println("L3 process plugin executables: ${processPluginCount.size.toString()}")
    if (excludedDlls.size > 0) {
        println("Excluded DLLs: ${excludedDlls.size.toString()}")
    }
    println("")
    println("Directory structure in archive:")
    println("  release/")
    println("    bin/              - Executables, ALL DLLs, ALL CJOs, .env.example, ssl/, logs/, plugins/")
    println("    bin/plugins/      - Plugin manifests ({name}/plugin.yaml + {name}/SKILL.md, plugin_manifest.json)")
    println("    bin/skills/       - L3 process plugin executables (skills/{name}/target/release/bin/skill_{name}.exe)")
    println("    magic/            - Runtime modules")
    println("    commonmark4cj/    - Markdown parser")
    println("    yaml4cj/          - YAML parser")
    println("    f_orm/            - ORM database framework")
    println("    f_data/           - Data processing framework")
    println("    f_config/         - Configuration management")
    println("    charset4cj/       - Character encoding library")
    println("    jwt4cj/           - JWT authentication library")
    println("    logcj/            - Logging library")
    println("    opengauss/        - OpenGauss database driver")
    println("    blowfish/         - Blowfish encryption library")
    println("    http_lib/         - HTTP/HTTPS/WebSocket/SSE unified library (0.0.26+, static, CJO only)")
    println("    kaca_json/        - JSON parsing library (0.0.26+, static, CJO only)")
    println("    jinguissl/        - TLS/SSL library (0.0.26+, static, CJO only)")
    println("    jinguissl_core/   - TLS core library (0.0.26+, static, CJO only)")
    println("    kaca_cookies/     - HTTP cookies library (0.0.26+, static, CJO only)")
    println("    compress4cj/      - Compression library (0.0.26+, static, CJO only)")
    println("    quic_cj/          - QUIC protocol library (0.0.26+, static, CJO only)")
    println("    channel_cj/       - Channel communication library (0.0.26+, static, CJO only)")
    println("    cos/              - Tencent COS SDK (0.0.26+, DLL + CJO)")
    println("    pgsql/            - PostgreSQL driver (0.0.26+, CJO only)")
    println("    cj_mail/          - Email library (0.0.26+, CJO only)")
    println("    activemq4cj/      - ActiveMQ client (0.0.26+, CJO only)")
    println("    hyperion/         - Hyperion toolkit (0.0.26+, CJO only)")
    println("    ssl/              - SSL certificates directory (empty, users provide their own)")
    println("    logs/             - Log output directory")
    println("    VERSION           - Version info")
    println("    .env.example      - Configuration template (users create .env from this)")
    println("")
    println("Setup Instructions:")
    println("  1. Extract the archive to your desired location")
    println("  2. Copy .env.example to .env and configure:")
    println("     - Database connection settings")
    println("     - API tokens (STEPFUN_API_KEY, MAAS_API_KEY, etc.)")
    println("     - SSL certificate paths")
    println("     - Other required settings")
    println("  3. Generate or copy SSL certificates to ssl/ directory:")
    println("     - ssl/server.crt (certificate)")
    println("     - ssl/server.key (private key)")
    println("  4. Run from release directory: bin/agentskills-runtime.exe [port]")
    println("     Or from bin directory: agentskills-runtime.exe [port]")
    println("")
    println("Security Notes:")
    println("  - .env file contains sensitive information, NEVER commit it to version control")
    println("  - SSL certificates are private, NEVER share or commit them")
    println("  - Always use environment variables or secure storage for production")
    println("========================================")
}
