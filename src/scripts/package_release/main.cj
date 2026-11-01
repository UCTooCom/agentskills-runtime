/*
 * Copyright (c) UCToo Co., Ltd. 2024-2026. All rights reserved.
 */
package magic.scripts.package_release

import std.fs.*
import std.process.{launch, ProcessRedirect, SubProcess}
import std.convert.*
import std.collection.{ArrayList, HashSet}
import std.env.getVariable
import std.time.DateTime
import std.unicode.*
// InputStream 必须显式导入：File 的 read()/close() 来自 InputStream 接口扩展，
// 只 import std.fs 会导致 read/close 不可见（同款坑见
// src/app/services/bridge/sdd_orchestration_service.cj:19-22 的说明）。
import std.io.InputStream
// SHA256 标准实现位于扩展标准库 stdx（官方文档："SHA-256 的实现来自扩展标准库"）。
import stdx.crypto.digest.*
import stdx.encoding.hex.*
import stdx.encoding.json.{JsonValue, JsonObject, JsonKind}

// ===== OQ-D3: 生成 SHA256SUMS 包完整性清单 =====
// 遍历 target/release 下所有常规文件，计算 SHA256，写出 Debian 风格清单
// target/release/SHA256SUMS（相对路径 + 正斜杠）。安装器解压后逐条复核，
// 任一不匹配即判定介质被篡改或不完整，拒绝安装。
//
// 内存安全改造（2026-10-12）：
// 旧实现用 File.readFrom() 把每个文件整个读进堆，再交给一次性的 pgsql.sha256。
// target/release 下存在数百 MB 级文件（如 libcangjie-lsp.dll 约 200MB，且它在
// release 根目录与 release/bin 各存一份），逐个整读会直接 Out of memory —— 打包
// 恰恰卡死在最后一步 SHA256SUMS。前置拷贝步骤之所以安然无恙，是因为 safeCopy()
// 走的是 std copy()，内部本身是流式的。
//
// 新实现两点改动：
//   ① 改用 stdx.crypto.digest.SHA256 的增量接口（write() 可分次喂数据、finish()
//      取摘要），按固定 1MiB 分块读取文件 —— 堆占用恒定约 1MiB，与文件大小无关；
//   ② 清单行用 StringBuilder 拼接，取代旧版 `content = content + line` 的 O(N²)
//      重复拷贝（1400+ 个文件时会制造大量垃圾数据）。
// 注：SHA256 是标准化算法，更换实现不改变摘要值，安装器侧校验结果保持一致。
let SHA256SUMS_CHUNK_BYTES = 1024 * 1024

/// 以恒定内存占用流式计算文件 SHA256，返回小写十六进制串。
/// 出错返回 None（由调用方打 WARN，不中断整体打包流程）。
///
/// 分块读法参照 src/app/services/tool/CrudGenService.cj:191 readStreamToEnd()
/// 的同款写法（read() 返回读取字节数，<=0 即 EOF，切片用 buffer[0..bytesRead]）。
func hashFileSha256Hex(filePath: Path, chunkSize: Int64): Option<String> {
    try {
        // 用 File(String, OpenMode) 这个已在项目中验证过的重载
        let file = File(filePath.toString(), OpenMode.Read)
        let sha = SHA256()
        let buffer = Array<Byte>(chunkSize, { _ => 0 })
        while (true) {
            let bytesRead = file.read(buffer)
            if (bytesRead <= 0) {
                break
            }
            sha.write(buffer[0..bytesRead])
        }
        file.close()
        return Some(toHexString(sha.finish()))
    } catch (e: Exception) {
        return None
    }
}

/// 递归收集目录下全部常规文件（深度优先）。
///
/// 关键：std.fs.Directory.walk 的官方契约就是**非递归**的——「遍历 path 对应的
/// 目录下的子项目（非递归，即不包含子目录的子项目）」（见 CangjieSkills 官方文档
/// references/api/std/fs/classes/directory/walk.md）。旧实现直接拿它遍历
/// target/release，结果 SHA256SUMS 只覆盖了根目录十几个顶层文件，bin/ 下的全部 exe
/// （含 ucInstaller.exe）与数百个 DLL 一条都没进清单，安装器解压后的 OQ-D3 校验
/// 形同空跑。故这里改用 Directory.readFrom 自行递归。
func collectReleaseFiles(dirPath: String, out: ArrayList<FileInfo>): Unit {
    try {
        for (info in Directory.readFrom(dirPath)) {
            if (info.isDirectory()) {
                collectReleaseFiles(info.path.toString(), out)
            } else {
                out.add(info)
            }
        }
    } catch (_: Exception) {
        // 单个子目录不可读时不中断整体清单生成
    }
}

func generateSha256Sums(releaseRoot: Path): Int64 {
    let lines = ArrayList<String>()  // 每行形如 "<hex>  <relpath>"
    let rootStr = releaseRoot.toString()
    let files = ArrayList<FileInfo>()
    collectReleaseFiles(rootStr, files)
    for (fileInfo in files) {
        let name = fileInfo.path.fileName
        if (name == "SHA256SUMS") {
            continue
        }
        let full = fileInfo.path.toString()
        var relp = full
        if (full.startsWith(rootStr)) {
            relp = full.replace(rootStr, "")
        }
        if (relp.startsWith("\\") || relp.startsWith("/")) {
            relp = relp[1..]
        }
        relp = relp.replace("\\", "/")
        if (let Some(hex) <- hashFileSha256Hex(fileInfo.path, SHA256SUMS_CHUNK_BYTES)) {
            lines.add("${hex}  ${relp}")
        } else {
            println("  [WARN] Failed to hash ${full}")
        }
    }
    // StringBuilder 替代旧版字符串反复 + 拼接，避免 O(N²) 拷贝
    let sb = StringBuilder()
    for (l in lines) {
        sb.append(l)
        sb.append("\n")
    }
    let sumPath = Path("${releaseRoot}/SHA256SUMS")
    try {
        File.writeTo(sumPath, sb.toString().toArray())
        println("  [OK] Wrote SHA256SUMS with ${lines.size.toString()} entries -> ${sumPath.toString()}")
    } catch (e: Exception) {
        println("  [ERROR] Failed to write SHA256SUMS: ${e.message}")
    }
    return lines.size
}

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


// ===== PS-SEED-00: 打包前自动重新导出数据库种子（db export）=====
// 让发布包里的 sql/uctooDB.sql 永远来自 installer 统一机制（export-policy.json /
// sanitize-policy.json 驱动），而不是手搓或过期的文件。
//
// 前置：
//   ① installer 须已构建（installer/target/release/bin/main.exe；本脚本也会把它收为
//      release/bin/ucInstaller.exe）。db export 由该二进制承担，与 runtime 本体构建无关。
//   ② 仓库根 .env 须含 DATABASE_URL，指向一台可连接的源库（dev uctoo，含 entity /
//      agent_skills 等种子数据）。
//
// 行为：
//   - 调 installer db export（cwd = 仓库根，故从仓库根 .env 读 DATABASE_URL，写 sql/uctooDB.sql，
//     与手动 `cjpm run db export` 行为完全一致）。
//   - 成功则把种子双拷进 target/release/sql/ 与 target/release/bin/sql/（seed-init 以 cwd 解析
//     sql/uctooDB.sql，独立发布包从 release 根启动 cwd=release 根，与 AGENTS.md 双拷贝策略一致）。
//   - 任一环节失败 → 返回 false，调用方中止打包，避免把"缺种子 / 过期种子"打进发布包。
func runSeedExportStep(rootPath: Path): Bool {
    println("")
    println("[STEP] Auto-exporting database seed via installer (db export)...")

    let installerExe = Path("${rootPath}/installer/target/release/bin/main.exe")
    if (!exists(installerExe)) {
        println("  [ERROR] installer not built: ${installerExe}")
        println("         `db export` 依赖 installer 二进制；请先 `cd installer && cjpm build`，")
        println("         再重跑 package_release。已中止打包，避免产出缺种子的发布包。")
        return false
    }

    let args = ArrayList<String>()
    args.add("db")
    args.add("export")
    // cwd = 仓库根：db export 从 cwd 读 .env 的 DATABASE_URL，并写 sql/uctooDB.sql。
    try {
        let proc = launch(installerExe.toString(), args, workingDirectory: Some(rootPath))
        let exitCode = proc.wait()
        if (exitCode != 0) {
            println("  [ERROR] `uc_installer db export` 退出码 ${exitCode.toString()}，种子导出失败。")
            println("         请确认：① 仓库根 .env 含可用 DATABASE_URL；② 源库（dev uctoo）可连接且含数据。")
            println("         已中止打包，避免把过期/缺失的种子打进发布包。")
            return false
        }
    } catch (e: Exception) {
        println("  [ERROR] 执行 installer db export 异常: ${e.message}")
        return false
    }

    let srcSql = Path("${rootPath}/sql/uctooDB.sql")
    if (!exists(srcSql)) {
        println("  [ERROR] db export 声称成功，但 ${srcSql} 不存在；中止打包。")
        return false
    }

    // 拷进发布包：release 根与 bin 各一份。
    let okRoot = safeCopy(srcSql.toString(), Path("${rootPath}/target/release/sql/uctooDB.sql").toString(), true)
    let okBin = safeCopy(srcSql.toString(), Path("${rootPath}/target/release/bin/sql/uctooDB.sql").toString(), true)
    if (okRoot && okBin) {
        println("  [OK] 种子已自动导出并打进发布包 -> release/sql/uctooDB.sql + release/bin/sql/uctooDB.sql")
        return true
    }
    println("  [ERROR] 种子文件已导出，但拷入发布包失败；中止打包。")
    return false
}

/// 解析 skills/release-skills.json：返回 (技能名列表, 排除目录集合, 排除文件集合)。
/// 解析失败或字段缺失时返回空集合，由调用方决定是否中止打包。
func parseReleaseSkillsJson(text: String): (ArrayList<String>, HashSet<String>, HashSet<String>) {
    let skills = ArrayList<String>()
    let exclude = HashSet<String>()
    let excludeFiles = HashSet<String>()
    try {
        let v = JsonValue.fromStr(text)
        match (v.kind()) {
            case JsonKind.JsObject =>
                let obj = v.asObject()
                match (obj.get("skills")) {
                    case Some(sv) =>
                        match (sv.kind()) {
                            case JsonKind.JsArray =>
                                for (item in sv.asArray().getItems()) {
                                    match (item.kind()) {
                                        case JsonKind.JsString => skills.add(item.asString().getValue())
                                        case _ => ()
                                    }
                                }
                            case _ => ()
                        }
                    case None => ()
                }
                match (obj.get("excludeDirs")) {
                    case Some(ev) =>
                        match (ev.kind()) {
                            case JsonKind.JsArray =>
                                for (item in ev.asArray().getItems()) {
                                    match (item.kind()) {
                                        case JsonKind.JsString => exclude.add(item.asString().getValue())
                                        case _ => ()
                                    }
                                }
                            case _ => ()
                        }
                    case None => ()
                }
                match (obj.get("excludeFiles")) {
                    case Some(fv) =>
                        match (fv.kind()) {
                            case JsonKind.JsArray =>
                                for (item in fv.asArray().getItems()) {
                                    match (item.kind()) {
                                        case JsonKind.JsString => excludeFiles.add(item.asString().getValue())
                                        case _ => ()
                                    }
                                }
                            case _ => ()
                        }
                    case None => ()
                }
            case _ => ()
        }
    } catch (_: Exception) {
        return (skills, exclude, excludeFiles)
    }
    return (skills, exclude, excludeFiles)
}

/// 判断相对路径 rel 是否应被排除（不随包）。
/// 规则优先级：
///   1. target 目录：仅保留 target/release/bin（L3 进程轨编译产物 + 运行时依赖 DLL），
///      target 的其余部分（.cjpm-history/.dep-cache/.build-logs 等构建缓存）一律排除；
///   2. 文件名精确命中 excludeFiles（依赖 example 泄漏产物等）；
///   3. 所有 .cjo 中间对象文件（exe 已自包含，运行时不需要）；
///   4. 任一路径段命中 exclude 目录名（src / .git / node_modules ...）。
func isExcludedBy(rel: String, exclude: HashSet<String>, excludeFiles: HashSet<String>): Bool {
    let norm = rel.replace("\\", "/")
    var r = norm
    while (r.startsWith("\\") || r.startsWith("/")) {
        r = r[1..]
    }
    // 规则 1：target 仅放行 target/release/bin
    if (r.startsWith("target/") && !r.startsWith("target/release/bin/")) {
        return true
    }
    let parts = r.split("/")
    let base = parts[parts.size - 1]
    // 规则 2：文件名精确排除
    if (excludeFiles.contains(base)) {
        return true
    }
    // 规则 3：.cjo 中间对象文件
    if (base.endsWith(".cjo")) {
        return true
    }
    // 规则 3.5：日志文件永不随包（运行/构建产物，非资产）
    if (base.endsWith(".log")) {
        return true
    }
    // 规则 4：目录名段排除
    for (p in parts) {
        if (exclude.contains(p)) {
            return true
        }
    }
    return false
}

/// 递归复制技能目录到 destDir，跳过 exclude 中的目录与 excludeFiles 中的文件
/// （src / .git / node_modules / 构建缓存，以及 target 下除 release/bin 外的部分，
/// 还有依赖 example 泄漏产物与 .cjo 中间对象）。
/// 复用 safeCopy（自动创建父目录、失败仅告警），返回复制的文件数。
func copySkillDir(srcDir: Path, destDir: Path, exclude: HashSet<String>, excludeFiles: HashSet<String>): Int64 {
    let count = [0]
    let srcStr = srcDir.toString()
    Directory.walk(srcDir.toString()) { fileInfo =>
        if (!fileInfo.isDirectory()) {
            let full = fileInfo.path.toString()
            var rel = full
            if (full.startsWith(srcStr)) {
                rel = full.replace(srcStr, "")
            }
            while (rel.startsWith("\\") || rel.startsWith("/")) {
                rel = rel[1..]
            }
            if (!isExcludedBy(rel, exclude, excludeFiles)) {
                let dest = Path("${destDir}/${rel}")
                if (safeCopy(full, dest.toString(), true)) {
                    count[0] = count[0] + 1
                }
            }
        }
    }
    return count[0]
}

/// PS-SKILLS: 按 skills/release-skills.json 白名单，把开发目录 skills/{name} 整目录
/// 复制到发布包 bin/skills/{name} 与 skills/{name}（cwd-from-root 兜底，与 AGENTS.md 双拷贝一致）。
/// 该文件是技能随包发布的唯一真相源；缺失或为空则中止打包，避免发布不完整的技能目录。
func runSkillCopyStep(rootPath: Path): Bool {
    println("")
    println("[STEP] Packaging allowlisted skills (skills/release-skills.json -> bin/skills/ + skills/)...")
    let configPath = Path("${rootPath}/skills/release-skills.json")
    if (!exists(configPath)) {
        println("  [ERROR] 未找到 skills/release-skills.json（随 runtime 发布的技能白名单配置文件）。")
        println("          该文件是技能随包发布的唯一真相源；缺失则中止打包，避免发布不完整的技能目录。")
        return false
    }
    let text = String.fromUtf8(File.readFrom(configPath))
    let (skills, exclude, excludeFiles) = parseReleaseSkillsJson(text)
    if (skills.isEmpty()) {
        println("  [ERROR] release-skills.json 中 skills 列表为空或解析失败，中止打包。")
        return false
    }
    if (exclude.isEmpty()) {
        // 缺省排除：编译期输入(src) + 版本控制/依赖缓存 + 构建缓存。
        // 注意：target 不在默认排除中——L3 进程轨的 target/release/bin 是运行时产品，必须随包；
        // 其下的构建缓存由 isExcludedBy 的 target 专有规则单独剔除。
        exclude.add("src")
        exclude.add(".git")
        exclude.add("node_modules")
        exclude.add("__pycache__")
        exclude.add(".idea")
        exclude.add(".vscode")
        exclude.add("dist")
        exclude.add("build")
        exclude.add(".cjpm-history")
        exclude.add(".dep-cache")
        exclude.add(".build-logs")
    }
    if (excludeFiles.isEmpty()) {
        excludeFiles.add("jsonvalue.examples.basic.exe")
        excludeFiles.add("jsonvalue.examples.basic.cjo")
    }
    let targetDir = Path("${rootPath}/target/release")
    let binDir = Path("${targetDir}/bin")
    let binSkills = Path("${binDir}/skills")
    let rootSkills = Path("${targetDir}/skills")
    if (!exists(binSkills)) {
        Directory.create(binSkills, recursive: true)
    }
    if (!exists(rootSkills)) {
        Directory.create(rootSkills, recursive: true)
    }
    var copiedSkills = 0
    var missingSkills = 0
    var totalFiles = 0
    for (name in skills) {
        let srcDir = Path("${rootPath}/skills/${name}")
        if (!exists(srcDir)) {
            println("  [WARN] 白名单技能 '${name}' 在 skills/ 下不存在，跳过。")
            missingSkills = missingSkills + 1
            continue
        }
        let n1 = copySkillDir(srcDir, Path("${binSkills}/${name}"), exclude, excludeFiles)
        let n2 = copySkillDir(srcDir, Path("${rootSkills}/${name}"), exclude, excludeFiles)
        copiedSkills = copiedSkills + 1
        totalFiles = totalFiles + n1 + n2
        println("  [OK] ${name}: bin/skills + skills 各 ${n1.toString()} 文件")
    }
    var exclStr = ""
    var firstExcl = true
    for (x in exclude) {
        if (!firstExcl) {
            exclStr = exclStr + ", "
        }
        exclStr = exclStr + x
        firstExcl = false
    }
    var fileStr = ""
    var firstFile = true
    for (x in excludeFiles) {
        if (!firstFile) {
            fileStr = fileStr + ", "
        }
        fileStr = fileStr + x
        firstFile = false
    }
    println("  [INFO] 共发布 ${copiedSkills.toString()} 个技能（缺失 ${missingSkills.toString()}），复制文件 ${totalFiles.toString()} 个")
    println("  [INFO] 排除目录：${exclStr}")
    println("  [INFO] 排除文件：${fileStr}")
    println("  [INFO] 排除目录：${exclStr}")
    return true
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

    // ===== PS-SEED-00: 打包前自动重新导出数据库种子（db export）=====
    // 失败即中止，避免把过期/缺失的种子打进发布包（详见 runSeedExportStep 注释）。
    // 置于最早，fail-fast：installer 未构建 / 源库不可连时直接退出，不浪费后续 DLL 拷贝。
    if (!runSeedExportStep(rootPath)) {
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
    // plugin_spi：L3 插件轨 SPI 契约包（path 依赖，dynamic 产物）。2026-10-24 事故：
    // 它没在清单里 ⇒ libplugin_spi.dll 没进 bin ⇒ 主 exe 加载期 0xC0000135 秒退。
    let extraDeps = ["cos", "pgsql", "cj_mail", "activemq4cj", "hyperion", "plugin_spi"]
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
    
    // ---------------------------------------------------------------------
    // 兜底补漏：上面是一张**手写清单**，新增依赖忘了登记就会漏拷 DLL。
    // Windows 只搜 exe 所在目录（bin），漏一个的后果是主 exe 在加载期即失败：
    // 退出码 0xC0000135，进程一行输出都没有，表现为"启动就崩、重启还是崩"
    // （2026-10-24 的 plugin_spi 就是这么漏的）。
    // 这里遍历 target/release 下全部依赖目录，把 bin 里还缺的 DLL 补齐，
    // 使打包不依赖清单的完整性。只补缺失项，不覆盖已有的正确副本。
    // ---------------------------------------------------------------------
    println("")
    println("[STEP] Sweeping any remaining dependency DLLs into bin (catch-all)...")
    
    let depDirs = ArrayList<String>()
    Directory.walk(targetDir.toString()) { entry =>
        if (entry.isDirectory()) {
            let dirName = entry.path.fileName
            if (dirName != "bin" && !shouldExcludeDirectory(dirName)) {
                depDirs.add(entry.path.toString())
            }
        }
        true
    }
    
    let sweptDlls = ArrayList<String>()
    for (depPath in depDirs) {
        Directory.walk(depPath) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                
                if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                    if (!shouldExcludeDll(name)) {
                        let destPath = Path("${binDir}/${name}")
                        if (!exists(destPath)) {
                            safeCopy(fileInfo.path.toString(), destPath.toString(), true)
                            sweptDlls.add(name)
                            totalDlls.add(name)
                        }
                    }
                }
            }
            true
        }
    }
    
    println("  [OK] Swept ${sweptDlls.size.toString()} missing DLLs into bin/")
    if (sweptDlls.size > 0) {
        for (swept in sweptDlls) {
            println("       + ${swept}")
        }
        println("  [HINT] 这些 DLL 不在手写清单里，说明有新增依赖未登记——请把对应包名补进清单。")
    }
    
    println("")
    println("[STEP] Copying cangjie-stdx libraries to bin...")

    // CANGJIE_STDX_DYNAMIC_PATH 可能已经指向 dynamic/stdx 目录，
    // 也可能指向 stdx 根目录（需要拼接 windows_x86_64_cjnative/dynamic/stdx）。
    // 优先使用 CANGJIE_STDX_PATH（指向 stdx 根目录），再探测各候选路径。
    let stdxCandidates = ArrayList<String>()
    match (getVariable("CANGJIE_STDX_DYNAMIC_PATH")) {
        case Some(p) =>
            // p 本身可能就是 dynamic/stdx 目录
            stdxCandidates.add(p)
            // 也可能需要拼接子目录
            stdxCandidates.add("${p}/windows_x86_64_cjnative/dynamic/stdx")
        case None => ()
    }
    match (getVariable("CANGJIE_STDX_PATH")) {
        case Some(p) =>
            stdxCandidates.add("${p}/windows_x86_64_cjnative/dynamic/stdx")
            stdxCandidates.add(p)
        case None => ()
    }
    // 项目内本地化的 stdx 目录（优先 1.1.3.1，回退 1.0.5.1）
    stdxCandidates.add("${rootPath}/libs/cangjie-stdx-windows-x64-1.1.3.1/windows_x86_64_cjnative/dynamic/stdx")
    stdxCandidates.add("${rootPath}/libs/cangjie-stdx-windows-x64-1.0.5.1/windows_x86_64_cjnative/dynamic/stdx")

    // 找到第一个存在且包含 libstdx.dll 的目录
    var stdxDir: ?Path = None
    for (candidate in stdxCandidates) {
        let candidatePath = Path(candidate)
        if (exists(candidatePath) && exists("${candidate}/libstdx.dll")) {
            stdxDir = Some(candidatePath)
            break
        }
    }

    match (stdxDir) {
        case Some(dir) =>
            if (exists(binDir)) {
                let stdxCount = ArrayList<String>()
                Directory.walk(dir.toString()) { fileInfo =>
                    if (!fileInfo.isDirectory()) {
                        let name = fileInfo.path.fileName
                        if (name.endsWith(".dll") || name.endsWith(".so") || name.endsWith(".dylib")) {
                            // 强制覆盖：确保发布包使用最新版本 stdx DLL
                            let destPath = Path("${binDir}/${name}")
                            if (safeCopy(fileInfo.path.toString(), destPath.toString(), true)) {
                                stdxCount.add(name)
                                totalDlls.add(name)
                            }
                        }
                    }
                    true
                }
                println("  [OK] Copied ${stdxCount.size.toString()} stdx DLLs to bin/ (source: ${dir})")
            } else {
                println("  [WARN] bin/ directory not found, skip stdx DLLs")
            }
        case None =>
            println("  [WARN] stdx directory not found in any candidate path:")
            for (c in stdxCandidates) {
                println("         - ${c}")
            }
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
    println("[STEP] Normalizing OpenSSL 3.x DLL filenames for the stdx loader...")

    // ── 背景（社区上报：新机器搭环境后登录接口 401）──────────────────────────
    // stdx 的 libcangjie-dynamicLoader-opensslFFI.dll 把文件名写死成 libcrypto-3-x64.dll /
    // libssl-3-x64.dll（版本号 3 与 -x64 后缀都在二进制里），而上面这一步拷进来的是
    // libcrypto-3.dll（无 -x64）→ Windows 只会去 PATH 找 OpenSSL：机器上装的是 4.x 时找不到，
    // SHA256_Init 符号解析失败抛异常 → JWTUtil.cj:50-53 的 catch 吞掉并返回空 token "" →
    // 前端拿到空 token → DeserializeUserMiddleware 验不出来 → 401（表现为"密码错误"）。
    // 这里把自带的那份 OpenSSL 3.0.13 复制成加载器认的名字，exe 目录优先于 PATH，
    // 于是宿主自带 3.x，用户系统装 3.x/4.x/没装都不再影响。
    // 详见 skills/uctoo-dev-manual/specs/runtime-openssl-dll-guide.md。
    var opensslCount = 0
    let libCrypto3 = Path("${binDir}/libcrypto-3.dll")
    if (exists(libCrypto3)) {
        if (safeCopy(libCrypto3.toString(), Path("${binDir}/libcrypto-3-x64.dll").toString(), true)) {
            opensslCount = opensslCount + 1
        }
    }
    let libSsl3 = Path("${binDir}/libssl-3.dll")
    if (exists(libSsl3)) {
        if (safeCopy(libSsl3.toString(), Path("${binDir}/libssl-3-x64.dll").toString(), true)) {
            opensslCount = opensslCount + 1
        }
    }
    if (opensslCount > 0) {
        println("  [OK] Ensured ${opensslCount.toString()} OpenSSL 3.x DLL(s) named as the stdx loader expects (*-x64.dll)")
    } else {
        println("  [WARN] No libcrypto-3.dll / libssl-3.dll in bin/ - stdx openssl FFI may fall back to system OpenSSL")
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

    // ===== PS-LRT-01: 技能随包资源打包（skills/* -> bin/skills/{name}/，融合机制权威目录）=====
    println("")
    println("[STEP] Packaging skill assets into bin/skills/ (fusion layout)...")
    let skillsDir = Path("${rootPath}/skills")
    if (exists(skillsDir)) {
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
            println("  [INFO] No plugins (skills with plugin.yaml) found under skills/")
        } else {
            for (pluginName in pluginNames) {
                // ===== PS-LRT-01: 技能随包资源（scripts/ + 技能资产）=====
                // L3 进程插件 exe 落在 bin/skills/{name}/（见 PS-T029）。
                // 进程插件的函数体虽已静态链接进 exe，但外层 Python 脚本（D 层降级后端）
                // 和 COMPOSITION.yaml / DATA_CONTRACT.yaml 是运行时按相对路径读取的：
                // LrtScriptRunner 按 <skillRoot>/scripts 解析脚本目录，脚本则用相对路径
                // 读写 output/xxx。只打 plugin.yaml + SKILL.md 会让已安装的进程插件
                // 「能起来、跑不出结果」——所有 cli_execute/llm/template 降级后端全部失效。
                // 因此资源必须与 exe 同根（bin/skills/{name}/）。
                let skillAssetRoot = Path("${binDir}/skills/${pluginName}")
                let skillAssets = ["scripts", "COMPOSITION.yaml", "DATA_CONTRACT.yaml",
                                   "OPS.md", "README.md", "AGENTS.md", "agents"]
                // 用 `let` 绑定到可变容器（数组单元），避免在闭包中捕获可变局部变量
                // （Cangjie：捕获 mutable 变量的 lambda 只能被直接调用，而 Directory.walk
                // 把 lambda 作为逃逸参数传递，故此用数组单元计数）。
                let skillAssetCount = [0]
                for (asset in skillAssets) {
                    let assetSrc = Path("${rootPath}/skills/${pluginName}/${asset}")
                    if (!exists(assetSrc)) {
                        continue
                    }
                    if (asset == "scripts") {
                        let assetRootNorm = assetSrc.toString().replace("\\", "/")
                        Directory.walk(assetSrc.toString()) { assetInfo =>
                            if (!assetInfo.isDirectory()) {
                                let assetPathNorm = assetInfo.path.toString().replace("\\", "/")
                                // 相对 assetRoot 的路径（含子目录），保持目录结构
                                let rel = assetPathNorm[assetRootNorm.size + 1..]
                                if (safeCopy(assetInfo.path.toString(),
                                             "${skillAssetRoot}/scripts/${rel}", true)) {
                                    skillAssetCount[0] = skillAssetCount[0] + 1
                                }
                            }
                            true
                        }
                    } else if (safeCopy(assetSrc.toString(), "${skillAssetRoot}/${asset}", true)) {
                        skillAssetCount[0] = skillAssetCount[0] + 1
                    }
                }
                if (skillAssetCount[0] > 0) {
                    println("  [OK] Packaged ${skillAssetCount[0].toString()} skill asset file(s) for '${pluginName}' to bin/skills/")
                }
            }
            println("  [OK] Copied skill assets for ${pluginNames.size.toString()} plugin(s) into bin/skills/")
        }
    } else {
        println("  [INFO] skills/ directory not found, skip skill assets")
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

    // ===== PS-SKILLS: 按白名单打包技能（置于 L3 步骤之后、清理/校验之前）=====
    if (!runSkillCopyStep(rootPath)) {
        return
    }

    // ===== PS-T029: cordis-cj 依赖库 DLL 打包 =====
    // cordis-cj 的传递依赖（jsonvalue、jsonrpc）和 cordis-cj 本身的产物
    // 需要被打包到 bin/ 下，以便进程插件运行时能找到这些 DLL
    println("")
    println("[STEP] Copying cordis-cj dependency DLLs to bin...")
    // 依赖目录名可能带 organization 后缀：cjpm 对 `organization="ystyle"` 的包
    // 产出目录是 `<name>@ystyle/`，不是 `<name>/`。漏了后缀会静默跳过整批 DLL，
    // 进程插件起不来且没有任何报错（这里也只是 [INFO] 级）。
    // gjson / tomlcj 是 cordis-cj 的传递依赖，同样需要参与 DLL 收集。
    let cordisDeps = ["jsonvalue", "jsonrpc", "cordis_core", "cordis_host", "cordis_plugin",
                      "gjson", "tomlcj"]
    for (depName in cordisDeps) {
        var depDir = Path("${targetDir}/${depName}")
        if (!exists(depDir)) {
            let orgDir = Path("${targetDir}/${depName}@ystyle")
            if (exists(orgDir)) {
                depDir = orgDir
            }
        }
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

    // PS-T016 已废弃：不再生成 bin/plugins/ 与 plugin_manifest.json（融合机制仅 bin/skills/{name}/）。

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
    println("[STEP] Packaging installer (ucInstaller.exe) into release/bin/ (T013 / REQ-PCI-005)...")
    // D1 轨道：installer 作为构件随 runtime 发行包分发，与 runtime 共用 DLL、零额外分发成本。
    // installer 是独立 cjpm 子工程，须先 `cd installer && cjpm build` 产出 main.exe，
    // 本步骤将其重命名为 ucInstaller.exe 一并打进 release/bin/（PC 解压后从同目录取用，OQ-D2）。
    let installerExe = Path("${rootPath}/installer/target/release/bin/main.exe")
    let installerDst = Path("${binDir}/ucInstaller.exe")
    if (exists(installerExe)) {
        if (safeCopy(installerExe.toString(), installerDst.toString(), true)) {
            println("  [OK] Packaged ucInstaller.exe -> release/bin/ucInstaller.exe")
        } else {
            println("  [WARN] Failed to copy ucInstaller.exe into release/bin/")
        }
    } else {
        println("  [WARN] installer not built: ${installerExe}")
        println("         run `cd installer && cjpm build` first, then re-run package_release.")
        println("         release/bin/ucInstaller.exe will be absent (REQ-PCI-005 unmet).")
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
    
    // ===== PS-LRT-03: 打包运行时根级资源（AGENTS.md + prompts/）=====
    // 运行时以 cwd（release 根或 bin）为基，启动时加载：
    //   - ${currentDir}/AGENTS.md       主 agent 定义（agent_type: main），缺失则 WARN 并退回 DB 兜底
    //   - ${currentDir}/prompts/        全局提示词模板（会话压缩 / 工具结果摘要），PROMPTS_DIR 默认 ./prompts
    // 此前这两类根级资源从没被收进 target/release ⇒ 已发布实例里"改 AGENTS.md 生效"这条文件化
    // 编辑路径是断的，且会话压缩 / 工具摘要会丢掉项目定制模板。
    // 同时拷到 release 根与 bin/ 两处：PC 端 cwd=release 根（runtime.ts:248），独立发布包从 bin 启动时
    // cwd=bin，两处都放才能覆盖两种启动方式（与 .env.example 的双拷贝策略一致）。
    println("")
    println("[STEP] Packaging runtime root resources (AGENTS.md, prompts/)...")

    let agentsMdSrc = Path("${rootPath}/AGENTS.md")
    if (exists(agentsMdSrc)) {
        safeCopy(agentsMdSrc.toString(), Path("${targetDir}/AGENTS.md").toString(), true)
        safeCopy(agentsMdSrc.toString(), Path("${binDir}/AGENTS.md").toString(), true)
        println("  [OK] Copied AGENTS.md -> release/AGENTS.md + release/bin/AGENTS.md")
    } else {
        println("  [WARN] AGENTS.md not found at ${agentsMdSrc}, main agent will fall back to DB/cfg")
    }

    let promptsSrcDir = Path("${rootPath}/prompts")
    if (exists(promptsSrcDir)) {
        let promptsCopied = [0]
        let promptsRootNorm = promptsSrcDir.toString().replace("\\", "/")
        Directory.walk(promptsSrcDir.toString()) { pInfo =>
            if (!pInfo.isDirectory()) {
                let pNorm = pInfo.path.toString().replace("\\", "/")
                let rel = pNorm[promptsRootNorm.size + 1..]
                safeCopy(pInfo.path.toString(), "${targetDir}/prompts/${rel}", true)
                safeCopy(pInfo.path.toString(), "${binDir}/prompts/${rel}", true)
                promptsCopied[0] = promptsCopied[0] + 1
            }
            true
        }
        if (promptsCopied[0] > 0) {
            println("  [OK] Copied ${promptsCopied[0].toString()} prompt file(s) -> release/prompts/ + release/bin/prompts/")
        }
    } else {
        println("  [INFO] prompts/ not found at ${promptsSrcDir}, skip global prompt templates")
    }

    // ===== PS-LRT-02: 写 VERSION 文件 =====
    // README「发布包目录结构」声明 release 根含 VERSION；此前脚本只在收尾打印里写到它，
    // 从不落盘，导致解压后没有版本标识别，现场排查版本只能靠包文件名。
    println("")
    println("[STEP] Writing VERSION file...")
    let versionFilePath = Path("${targetDir}/VERSION")
    let versionContent = "agentskills-runtime ${version}\nplatform: ${platform}\nbuild date: ${buildDate}\n"
    try {
        File.writeTo(versionFilePath, versionContent.toArray())
        println("  [OK] Wrote VERSION (${version}, ${platform})")
    } catch (e: Exception) {
        println("  [WARN] Failed to write VERSION to ${versionFilePath.toString()}: ${e.message}")
    }
    
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
    println("[STEP] Generating SHA256SUMS (OQ-D3)...")
    let sumCount = generateSha256Sums(targetDir)
    println("  [INFO] ${sumCount.toString()} files hashed into release/SHA256SUMS")

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
    println("L3 process plugin executables: ${processPluginCount.size.toString()}")
    if (excludedDlls.size > 0) {
        println("Excluded DLLs: ${excludedDlls.size.toString()}")
    }
    println("")
    println("Directory structure in archive:")
    println("  release/")
    println("    bin/              - Executables, ALL DLLs, ALL CJOs, .env.example, ssl/, logs/")
    println("    bin/skills/       - 技能-插件融合权威目录：每个技能/插件同住 bin/skills/{name}/，")
    println("                      含 SKILL.md + plugin.yaml + 随包资源(scripts/、COMPOSITION.yaml 等) + L3 exe")
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
    println("    AGENTS.md         - Main agent definition (agent_type: main)")
    println("    prompts/          - Global prompt templates (conversation/tool-summary)")
    println("    sql/              - Database seed (uctooDB.sql, auto-exported via `db export` before packaging)")
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
