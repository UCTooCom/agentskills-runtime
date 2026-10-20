import std.process.*
import std.fs.*
import std.io.{StringReader}
import std.collection.*
import std.env.getVariable

func getOsInfo() {
    @When[os == "Linux"]
    let os = "linux"

    @When[os == "Windows"]
    let os = "windows"

    @When[os == "macOS"]
    let os = "mac"

    @When[os != "Linux" && os != "Windows" && os != "macOS"]
    let os = "unknown"

    @When[arch == "aarch64"]
    let arch = "aarch64"

    @When[arch == "x86_64"]
    let arch = "x64"

    @When[arch != "x86_64" && arch != "aarch64"]
    let arch = "unknown"

    return (os, arch)
}

func downloadAndExtract(os: String, arch: String): Int64 {
    let version = "1.0.0.1"
    let url = "https://gitcode.com/Cangjie/cangjie-stdx-bin/releases/download/v${version}/cangjie-stdx-${os}-${arch}-${version}.zip"

    let installDir = "./libs"
    let targetDir = "${installDir}/cangjie-stdx-${os}-${arch}-${version}"
    let zipFile = "${installDir}/cangjie-stdx-${os}-${arch}-${version}.zip"

    // create target directory
    let targetDirPath = Path(targetDir)
    if (exists(targetDirPath)) {
        println("target dir ${targetDir} exists，skip downloading and unzipping")
        return 0
    } else {
        Directory.create(targetDirPath, recursive: true)
    }

    // download stdx zip file
    if (!exists(zipFile)) {
        println("download from ${url} ...")
        let downloadProc = if (os == "windows") {
            launch("powershell", ["-Command", "Invoke-WebRequest", "-Uri", url, "-OutFile", zipFile])
        } else {
            launch("curl", ["-L", "-o", zipFile, url])
        }
        let downloadResult = downloadProc.wait()

        if (downloadResult != 0) {
            println("download failed")
            remove(targetDirPath, recursive: true)
            return downloadResult
        }
    }

    // unzip file
    println("unzip file ${zipFile} to ${targetDir}...")
    let unzipProc = if (os == "windows") {
        launch("powershell", ["-Command", "Expand-Archive", "-Path", zipFile, "-DestinationPath", targetDir, "-Force"])
    } else {
        launch("unzip", ["-q", zipFile, "-d", targetDir])
    }
    let unzipResult = unzipProc.wait()

    // delete zip file
    let filePath = Path(zipFile)
    remove(filePath)

    if (unzipResult != 0) {
        println("unzipping failed")
        remove(targetDirPath, recursive: true)
        return unzipResult
    }

    return 0
}

func stagePreBuild(): Int64 {
    let (os, arch) = getOsInfo()

    if (os == "unknown" || arch == "unknown") {
        println("unsupported os or arch")
        return 1
    }

    println("os: ${os}, arch: ${arch}")
    let downloadResult = downloadAndExtract(os, arch)
    if (downloadResult != 0) {
        return downloadResult
    }
    return stagePluginBuildSync()
}

// ===== 插件目录 build-sync（PS-T015，附7.8.1 方案三过渡态）=====
//
// canonical 源码在 skills/{name}/scripts/cj/，构建期同步到 src/plugins/{name}/
// （包名 magic.plugins.{name}，与 design.md §2.6 包名规范一致）。
// 说明：不采用文档原表述 src/generated/skill-plugins/——仓颉包管理规格要求
// 包名 = 模块名 + src 相对目录路径，目录名含连字符无法构成合法包名；
// src/plugins/{name} 路径与包名天然一致，且阶段三升格方案二时插件身份不变。
// 同步产物不入库（见 .gitignore），以 .sync-manifest 登记支持孤儿清理。

let SYNC_SKILLS_ROOT = "./skills"
let SYNC_PLUGINS_TARGET = "./src/plugins"
let SYNC_MANIFEST = "./src/plugins/.sync-manifest"

func syncNormalize(p: String): String {
    return p.replace("\\", "/")
}

/// 按唯一标记提取插件源文件相对路径（plugingen 产物为平铺布局）
/// walk 实测返回绝对路径（如 D:/.../skills/<name>/scripts/cj/X.cj），
/// 定长切片会把绝对路径切成垃圾嵌套路径，故改用标记定位
func syncRelUnderName(name: String, file: String): Option<String> {
    let marker = "/skills/${name}/scripts/cj/"
    let idx = file.indexOf(marker)
    if (idx.isNone()) {
        return None<String>
    }
    return Some(file[idx.getOrThrow() + marker.size..])
}

func syncLastName(dir: String): String {
    let parts = syncNormalize(dir).split("/")
    return parts[parts.size - 1]
}

func syncReadText(path: String): String {
    try {
        return String.fromUtf8(File.readFrom(path))
    } catch (_: Exception) {
        return ""
    }
}

func syncSameFile(srcFile: String, destFile: String): Bool {
    if (!exists(destFile)) {
        return false
    }
    let srcBytes = File.readFrom(srcFile)
    let destBytes = File.readFrom(destFile)
    if (srcBytes.size != destBytes.size) {
        return false
    }
    for (i in 0..srcBytes.size) {
        if (srcBytes[i] != destBytes[i]) {
            return false
        }
    }
    return true
}

/// plugin.yaml 依赖校验（warn 级：硬校验由运行期 PluginLoader 承担）
func syncWarnDependencies(name: String): Unit {
    let yamlText = syncReadText("${SYNC_SKILLS_ROOT}/${name}/plugin.yaml")
    for (line in yamlText.split("\n")) {
        let t = line.trimAscii()
        if (t.startsWith("dependencies:")) {
            let value = t["dependencies:".size..].replace("\"", "")
            for (dep in value.split(",")) {
                let d = dep.trimAscii()
                if (!d.isEmpty()) {
                    if (!exists("${SYNC_SKILLS_ROOT}/${d}")) {
                        println("plugin-build-sync: WARN dependency '${d}' of '${name}' has no skills/${d}/ directory")
                    }
                }
            }
        }
    }
}

func syncCopyPlugin(name: String): Int64 {
    let srcDir = "${SYNC_SKILLS_ROOT}/${name}/scripts/cj"
    let destDir = "${SYNC_PLUGINS_TARGET}/${name}"
    if (!exists(destDir)) {
        Directory.create(destDir, recursive: true)
    }
    let copiedFiles = ArrayList<String>()
    try {
        Directory.walk(srcDir) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let srcFile = fileInfo.path.toString()
                let normalized = syncNormalize(srcFile)
                if (let Some(rel) <- syncRelUnderName(name, normalized)) {
                    let destFile = "${destDir}/${rel}"
                    if (!syncSameFile(srcFile, destFile)) {
                        File.writeTo(destFile, File.readFrom(srcFile))
                        copiedFiles.add(srcFile)
                    }
                }
            }
            return true
        }
    } catch (e: Exception) {
        println("plugin-build-sync: copy '${name}' failed: ${e.message}")
    }
    return Int64(copiedFiles.size)
}

/// 目录是否直接包含 .cj 文件（不满足则需 pkg.cj 占位以满足包管理规格）
/// walk 返回绝对路径，按目录最后一段标记定位（如 .../entity/X.cj）
func syncHasDirectCj(dir: String): Bool {
    let marker = "/${syncLastName(dir)}/"
    let hits = ArrayList<String>()
    try {
        Directory.walk(dir) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let n = syncNormalize(fileInfo.path.toString())
                if (n.endsWith(".cj")) {
                    let idx = n.indexOf(marker)
                    if (idx.isNone()) {
                        return true
                    }
                    let rel = n[idx.getOrThrow() + marker.size..]
                    if (!rel.contains("/")) {
                        hits.add(n)
                        return false
                    }
                }
            }
            return true
        }
    } catch (_: Exception) {
        return false
    }
    return hits.size > 0
}

// ===== L1 反射锚点自动生成（PS-T015 补充，配合 PS-T013 晋级门槛）=====
//
// 问题：cjpm/LTO 只保留可达代码——同步进 src/plugins/ 的插件类若无编译期引用，
// 会被链接器剪除，运行时 ClassTypeInfo.get 找不到类（main.cj 原手工锚点仅覆盖
// 示例插件，每上新插件都要改 main.cj，违背"不经框架代码修改上线"晋级门槛）。
// 方案：同步后扫描 skills/{name}/plugin.yaml 的 entry 与 routes 类名，自动生成
// src/plugins/generated_anchors.cj；main.cj 一次性调用 GeneratedPluginAnchors.touch()
// 即形成可达链，之后新插件上线零框架改动（阶段三 L2 动态库落地后可整体退役）。

let SYNC_ANCHORS_FILE = "./src/plugins/generated_anchors.cj"

/// 取类全限定名的最后一段（包名段）
func syncShortName(cls: String): String {
    let parts = cls.split(".")
    return parts[parts.size - 1]
}

/// 从 plugin.yaml 提取 entry 与 routes 类全名（轻量行级解析，与 package_release 同款风格）
func syncParsePluginYamlClasses(name: String): ArrayList<String> {
    let classNames = ArrayList<String>()
    var inRoutes = false
    let yamlText = syncReadText("${SYNC_SKILLS_ROOT}/${name}/plugin.yaml")
    for (rawLine in yamlText.split("\n")) {
        let line = rawLine.trimAscii()
        if (line.size == 0 || line.startsWith("#")) {
            continue
        }
        if (line.startsWith("- ")) {
            var item = line["- ".size..].trimAscii()
            if (item.size >= 2 && ((item.startsWith("\"") && item.endsWith("\"")) ||
                (item.startsWith("'") && item.endsWith("'")))) {
                item = item[1..item.size - 1]
            }
            if (inRoutes && (item.startsWith("magic.plugins.") || item.startsWith("skill_")) && !classNames.contains(item)) {
                classNames.add(item)
            }
            continue
        }
        let colonIdx = line.indexOf(":")
        if (colonIdx.isNone()) {
            inRoutes = false
            continue
        }
        let idx = colonIdx.getOrThrow()
        let key = line[0..idx].trimAscii()
        var value = if (idx + 1 < line.size) {
            line[idx + 1..line.size].trimAscii()
        } else {
            ""
        }
        if (value.size >= 2 && ((value.startsWith("\"") && value.endsWith("\"")) ||
            (value.startsWith("'") && value.endsWith("'")))) {
            value = value[1..value.size - 1]
        }
        if (key == "entry" && (value.startsWith("magic.plugins.") || value.startsWith("skill_"))) {
            if (!classNames.contains(value)) {
                classNames.add(value)
            }
            inRoutes = false
        } else if (key == "routes") {
            inRoutes = value.isEmpty()
        } else {
            inRoutes = false
        }
    }
    return classNames
}

/// 生成/更新锚点文件（内容未变不写盘，保护增量编译缓存）
func syncGenerateAnchors(names: ArrayList<String>): Unit {
    // 汇总去重（跨插件依赖同一包时 import 不重复）
    let allClasses = ArrayList<String>()
    for (name in names) {
        for (cls in syncParsePluginYamlClasses(name)) {
            if (!allClasses.contains(cls)) {
                allClasses.add(cls)
            }
        }
    }
    let sb = StringBuilder()
    sb.append("// 本文件由 build-sync 自动生成（勿手改、不入库，见 build.cj 锚点说明）\n")
    sb.append("// L1 反射锚点：确保静态链接保留插件类，运行时 ClassTypeInfo.get 可发现\n")
    sb.append("package magic.plugins\n\n")
    for (cls in allClasses) {
        sb.append("import ${cls}\n")
    }
    sb.append("\npublic class GeneratedPluginAnchors {\n")
    sb.append("    public static func touch(): Unit {\n")
    var count = 0
    for (cls in allClasses) {
        sb.append("        let _anchor_${count.toString()} = ${syncShortName(cls)}()\n")
        count += 1
    }
    sb.append("    }\n}\n")
    let content = sb.toString()
    if (!syncSameText(SYNC_ANCHORS_FILE, content)) {
        File.writeTo(SYNC_ANCHORS_FILE, content.toArray())
        println("plugin-build-sync: generated anchors for ${allClasses.size.toString()} plugin class(es)")
    }
}

/// 文本内容与目标文件是否一致（不存在即不一致）
func syncSameText(path: String, content: String): Bool {
    if (!exists(path)) {
        return false
    }
    return syncReadText(path) == content
}

func stagePluginBuildSync(): Int64 {
    if (!exists(SYNC_SKILLS_ROOT)) {
        println("plugin-build-sync: no skills/ directory, skip")
        // 兜底生成空锚点：保证 generated_anchors.cj 始终存在，main.cj import 不悬空
        let emptyNames = ArrayList<String>()
        syncGenerateAnchors(emptyNames)
        return 0
    }

    // 1. 发现含仓颉源码的技能插件（skills/{name}/plugin.yaml + scripts/cj/）
    let names = ArrayList<String>()
    try {
        Directory.walk(SYNC_SKILLS_ROOT) { fileInfo =>
            if (fileInfo.isDirectory()) {
                let dir = fileInfo.path.toString()
                if (syncNormalize(dir) != syncNormalize(SYNC_SKILLS_ROOT) &&
                    exists("${dir}/plugin.yaml") && exists("${dir}/scripts/cj")) {
                    let name = syncLastName(dir)
                    if (!name.isEmpty() && !names.contains(name)) {
                        names.add(name)
                    }
                }
            }
            return true
        }
    } catch (e: Exception) {
        println("plugin-build-sync: scan skills/ failed: ${e.message}")
        return 1
    }

    if (names.isEmpty()) {
        println("plugin-build-sync: no skill plugins with scripts/cj, skip")
        // 兜底生成空锚点（同上：main.cj import 不悬空）
        syncGenerateAnchors(names)
        return 0
    }

    // 2. 保留名保护（示例插件手工维护于 src/plugins/，禁止被同步覆盖）
    let reserved = ArrayList<String>()
    reserved.add("hello")
    reserved.add("doc_helper")

    // 3. 孤儿清理：上次同步过、但 skills/ 已删除的插件
    let manifest = ArrayList<String>()
    if (exists(SYNC_MANIFEST)) {
        for (line in syncReadText(SYNC_MANIFEST).split("\n")) {
            let t = line.trimAscii()
            if (!t.isEmpty()) {
                manifest.add(t)
            }
        }
    }
    for (oldName in manifest) {
        if (!names.contains(oldName) && exists("${SYNC_PLUGINS_TARGET}/${oldName}")) {
            remove(Path("${SYNC_PLUGINS_TARGET}/${oldName}"), recursive: true)
            println("plugin-build-sync: removed orphan '${oldName}' (no skills/${oldName}/ anymore)")
        }
    }

    // 4. 逐插件：依赖校验（warn）+ 增量复制 + pkg.cj 兜底
    let syncedNames = ArrayList<String>()
    var totalCopied = 0
    for (name in names) {
        if (reserved.contains(name)) {
            println("plugin-build-sync: WARN '${name}' collides with reserved example plugin, skip sync")
            continue
        }
        syncWarnDependencies(name)
        totalCopied += syncCopyPlugin(name)
        if (!syncHasDirectCj("${SYNC_PLUGINS_TARGET}/${name}")) {
            File.writeTo("${SYNC_PLUGINS_TARGET}/${name}/pkg.cj",
                "package magic.plugins.${name}\n".toArray())
        }
        syncedNames.add(name)
    }

    // 5. 写回同步清单（孤儿清理依据）
    let sb = StringBuilder()
    for (name in syncedNames) {
        sb.append(name)
        sb.append("\n")
    }
    File.writeTo(SYNC_MANIFEST, sb.toString().toArray())

    // 6. 生成 L1 反射锚点（entry/routes 数据驱动，新插件上线零框架改动）
    syncGenerateAnchors(syncedNames)

    println("plugin-build-sync: synced ${syncedNames.size.toString()} plugin(s), copied/updated ${totalCopied.toString()} file(s)")
    return 0
}

// ===== post-build 递归红线（2026-10-11 事故复盘，勿回退）=====
//
// 旧实现这一句是：
//     let proc = launch("cjpm", ["run", "--name", "magic.scripts.package_release"])
//
// 致命点在于 cjpm 的 run 语义是「先构建、再运行」，而构建会再次触发本构建脚本的
// 钩子（pre-build 重写 src/plugins/.sync-manifest，post-build 再拉起一次 cjpm run），
// 于是形成无限递归：cjpm 到 build，再到 post-build，再到 cjpm run，周而复始。
// 实测症状：12 小时内拉起 12 层嵌套 cjpm 进程，每层都要跑一遍完整构建
// （约 50 到 80 分钟），同一批 target/release/bin 产物被反复重链接、修改时间不断刷新；
// 又因为每层都在阻塞等待子进程，打包步骤从未真正跑起来
// （release 目录下的 tar.gz 一直停在本次构建开始之前的时间戳）。
//
// 铁律：本工程的构建钩子内禁止再拉起任何会触发构建的 cjpm 子命令。
// 打包只允许直接执行已构建好的产物可执行文件。
//
// 开关（同时支持 OS 环境变量 与 工程根目录 .env 中的同名键，OS 环境变量优先）：
// 日常 cjpm build 若不需要跟随打包（拷贝数百 MB 的 DLL 并生成数百 MB 的
// 归档，开销可观），在 .env 设 AGENTSKILLS_SKIP_POST_BUILD_PACKAGE=1 即可跳过；
// 需要打包时设为 0 或删去该行，再手工跑 cjpm run --name magic.scripts.package_release。
let POST_BUILD_SKIP_ENV = "AGENTSKILLS_SKIP_POST_BUILD_PACKAGE"

/// 打包产物的可执行文件路径（随平台带或不带 .exe 后缀）
func packageReleaseExe(): String {
    let info = getOsInfo()
    let os = info[0]
    return if (os == "windows") {
        "./target/release/bin/magic.scripts.package_release.exe"
    } else {
        "./target/release/bin/magic.scripts.package_release"
    }
}

let INSTALLER_DIR = "./installer"
let INSTALLER_SKIP_ENV = "AGENTSKILLS_SKIP_INSTALLER_BUILD"

// ---- 构建开关读取：OS 环境变量优先，回退到工程根目录 .env ----
// 历史实现只认 OS 环境变量，发现性极差；现允许在 .env 中配置同名键，
// 与运行时配置统一管理。取值为真（1/true/yes/on，大小写不敏感）即视为开启。
func readEnvFileValue(key: String): Option<String> {
    if (!exists(".env")) {
        return None
    }
    let file = File(".env", OpenMode.Read)
    let reader = StringReader(file)
    let content = reader.readToEnd()
    file.close()
    for (line in content.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed.isEmpty() || trimmed.startsWith("#")) {
            continue
        }
        if (let Some(eqIdx) <- trimmed.indexOf("=")) {
            let k = trimmed[0..eqIdx].trimAscii()
            if (k == key) {
                var v = trimmed[(eqIdx + 1)..trimmed.size].trimAscii()
                // 去除值两端的双引号（.env 中常见写法）
                if (v.startsWith("\"") && v.endsWith("\"") && v.size >= 2) {
                    v = v[1..(v.size - 1)]
                }
                return Some(v)
            }
        }
    }
    return None
}

func isTruthy(v: String): Bool {
    let t = v.trimAscii()
    return t == "1" || t == "true" || t == "TRUE" || t == "yes" || t == "YES" || t == "on" || t == "ON"
}

// 读取构建开关：OS 环境变量优先，未设置时回退 .env 同名键
func skipSwitch(envName: String): Bool {
    if (let Some(v) <- getVariable(envName)) {
        return isTruthy(v)
    }
    if (let Some(v) <- readEnvFileValue(envName)) {
        return isTruthy(v)
    }
    return false
}

/// 构建 installer 独立子工程（T013 / REQ-PCI-005 的前置步骤）
///
/// 为什么必须在这里补：installer 是**独立 cjpm 子工程**（自有 installer/cjpm.toml，
/// 不写在根 cjpm.toml 的 [dependencies] 里），所以根工程 `cjpm build` 永远不会构建它。
/// 而 package_release 只是「发现 installer/target/release/bin/main.exe 不存在就打 WARN
/// 并跳过」，于是 ucInstaller.exe 长期缺席（2026-10-10 排查结论）。
///
/// 递归安全性：**installer 目录下没有 build.cj**，因此这里拉起 `cjpm build` 不会再次
/// 触发本文件的钩子，不存在 438 行所述的递归风险。
/// [!] 若日后给 installer 增加 build.cj，本函数必须改为直接复用已构建产物，否则红线复燃。
///
/// 返回：true = installer 产物已就绪，可供 package_release 打包
func stageBuildInstaller(): Bool {
    if (skipSwitch(INSTALLER_SKIP_ENV)) {
        println("post-build: ${INSTALLER_SKIP_ENV} is set (env or .env), skip installer build")
        return false
    }
    if (!exists("${INSTALLER_DIR}/cjpm.toml")) {
        println("post-build: ${INSTALLER_DIR}/cjpm.toml not found, skip installer build")
        return false
    }

    println("post-build: building installer sub-project (${INSTALLER_DIR}) ...")
    let args: Array<String> = ["build"]
    let proc = launch("cjpm", args, workingDirectory: Some(Path(INSTALLER_DIR)))
    let result = proc.wait()
    if (result != 0) {
        println("post-build: [WARN] installer build failed with exit code ${result}")
        println("         release/bin/ucInstaller.exe will be absent (REQ-PCI-005 unmet)")
        return false
    }

    let installerExe = "${INSTALLER_DIR}/target/release/bin/main.exe"
    if (!exists(installerExe)) {
        println("post-build: [WARN] installer built but ${installerExe} not found")
        return false
    }
    println("post-build: installer built -> ${installerExe}")
    return true
}

func stagePostBuild(): Int64 {
    if (skipSwitch(POST_BUILD_SKIP_ENV)) {
        println("post-build: ${POST_BUILD_SKIP_ENV} is set (env or .env), skip packaging")
        return 0
    }

    // 先构建 installer，让随后的 package_release 能取到 main.exe 并改名为 ucInstaller.exe
    stageBuildInstaller()

    let exe = packageReleaseExe()
    if (!exists(exe)) {
        println("post-build: ${exe} not found, skip packaging (build must succeed first)")
        return 0
    }

    println("post-build: running ${exe} ...")
    let noArgs: Array<String> = Array<String>()
    let proc = launch(exe, noArgs)
    let result = proc.wait()
    if (result != 0) {
        println("post-build: package_release failed with exit code ${result}")
    } else {
        println("post-build: package_release completed successfully")
    }
    return result
}

main(): Int64 {
    match (Process.current.arguments[0]) {
        case "pre-build" => stagePreBuild()
        case "post-build" => stagePostBuild()
        case _ => 0
    }
}
