package ystyle::cordis_host

import ystyle::cordis_core.{PluginEntry, InstanceStatus}
import ystyle::jsonrpc.{JsonRpcClient, NewlineFraming}
import std.process.{launch, SubProcess, ProcessRedirect}
import std.env.{getVariables, getVariable, setVariable, getWorkingDirectory}
import std.fs.{exists, File, OpenMode, Directory, removeIfExists}
import std.io.StringReader
import std.sync.Mutex
import std.collection.{ArrayList, HashMap}

/**
 * 插件进程管理器（stdio-only 版，v5.0 L3 集成剥离 UDS）
 *
 * 职责：
 * - launch：拉起插件子进程并建立 JSON-RPC 连接（stdio 模式：三流 Pipe，
 *   PipeTransport + NewlineFraming 换行分帧）
 * - terminate：热卸载（关闭连接 + 强杀 + wait 回收退出码，避免僵尸进程）
 * - forwardStderr：独立线程转发插件 stderr 到宿主日志
 * - isExited：探测插件连接是否已关闭（stdout EOF 判定崩溃）
 *
 * 剥离说明：原 cordis-cj 含 UDS（Unix Domain Socket）模式，依赖
 * ystyle::jsonrpc_unix.UnixServerTransport，Windows 不可用。本集成传输
 * 固定 stdio（spec REQ-PS-015 / design §5.1），故剥离 UDS 仅留 stdio，
 * 使 cordis_host 在 x86_64-w64-mingw32 下可编译。UDS 传输能力若后续
 * 在 Linux/macOS 需求可另行按 @When[os != "Windows"] 恢复。
 */
public class PluginManager {
    private let logger: (String, String) -> Unit   // (pluginId, line) 日志回调
    private let lock: Mutex = Mutex()

    public init(logger: (String, String) -> Unit) {
        this.logger = logger
    }

    public init() {
        this.logger = { _, _ => () }
    }

    /**
     * 拉起插件进程并建立 RPC 连接（不等待握手）
     * @throws ProcessException 进程创建失败时
     */
    public func launch(entry: PluginEntry): PluginInstance {
        this.launchStdio(entry)
    }

    /**
     * 热卸载：关闭 RPC 连接 → 强杀进程 → 回收退出码
     *
     * 幂等：已处于 Unloading 的实例直接返回（防重复 terminate）。
     * 注意：调用方（PluginHost.removePlugin）已先 transitionStatus(Unloading)，
     * 因此这里不能仅凭状态判断——用独立标志位防止重复执行。
     *
     * @return 子进程退出码（正常退出为退出码，被信号杀死为信号编号）
     */
    public func terminate(instance: PluginInstance): Int64 {
        if (!instance.terminateLock.tryLock()) {
            return 0   // 已有 terminate 在进行
        }
        try {
            instance.transitionTo(InstanceStatus.Unloading)
            try {
                instance.client.close()
            } catch (e: Exception) {
                ()
            }
            instance.process.terminate(force: true)
            instance.process.wait()
        } finally {
            instance.terminateLock.unlock()
        }
    }

    /**
     * 探测插件连接是否已关闭（stdout EOF）
     * 用于崩溃检测：client 因 EOF 自动停止后 isClosed() 为 true
     */
    public func isExited(instance: PluginInstance): Bool {
        instance.client.isClosed()
    }

    /**
     * 关闭监听资源（stdio 模式无操作，保留 API 兼容）
     */
    public func close(): Unit {
        ()
    }

    // ── stdio 模式 ──────────────────────────────────────────────────

    private func launchStdio(entry: PluginEntry): PluginInstance {
        // Windows: 子进程需要能找到 stdx 动态库 DLL 和宿主同目录的 DLL。
        // 方案 A（首选）：PATH 注入——通过 environment 参数和 setVariable 双保险
        // 方案 B（兜底）：DLL 同目录复制——把 stdx DLL 复制到插件 exe 所在目录
        // 实测方案 A 在某些 launch() 实现下不生效（PATH 未传递给子进程），
        // 因此同时执行方案 B，确保插件进程能加载所有依赖 DLL。

        let envMap = HashMap<String, String>()
        for ((k, v) in getVariables()) {
            envMap[k] = v
        }
        let extraDirs = ArrayList<String>()
        let stdxPath = getCangjieStdxPath()
        if (!stdxPath.isEmpty()) {
            extraDirs.add(stdxPath)
        }
        match (getHostExecutableDir()) {
            case Some(dir) =>
                if (!extraDirs.contains(dir)) {
                    extraDirs.add(dir)
                }
            case None => ()
        }
        this.logger(entry.id, "[launchStdio] stdxPath='${stdxPath}' extraDirs.size=${extraDirs.size.toString()}")
        for (i in 0..extraDirs.size) {
            this.logger(entry.id, "[launchStdio] extraDirs[${i.toString()}]='${extraDirs[i]}'")
        }

        // ── 方案 B：DLL 同目录复制 ──────────────────────────────────
        // 把 stdx DLL 复制到插件 exe 所在目录，利用 Windows DLL 加载顺序中
        // "应用目录"第一优先级的特性，确保插件进程能找到所有依赖 DLL。
        this.copyDepsToPluginDir(entry)

        // ── 方案 A：PATH 注入 ────────────────────────────────────────
        if (extraDirs.size > 0) {
            var pathKey = "PATH"
            for ((k, _) in envMap) {
                if (k.toAsciiLower() == "path") {
                    pathKey = k
                    break
                }
            }
            let currentPath = match (envMap.get(pathKey)) {
                case Some(p) => p
                case None => ""
            }
            var newPath = ""
            for (i in 0..extraDirs.size) {
                if (i > 0) {
                    newPath = "${newPath};"
                }
                newPath = "${newPath}${extraDirs[i]}"
            }
            if (!currentPath.isEmpty()) {
                newPath = "${newPath};${currentPath}"
            }
            envMap[pathKey] = newPath
            envMap["PATH"] = newPath
            this.logger(entry.id, "[launchStdio] PATH injected via envMap (pathKey='${pathKey}') newPath.length=${newPath.size.toString()}")
            setVariable("PATH", newPath)
            this.logger(entry.id, "[launchStdio] PATH also set via setVariable('PATH')")
        } else {
            this.logger(entry.id, "[launchStdio] WARNING: no extra dirs found for PATH injection")
        }
        let proc = launch(entry.source, entry.args.toArray(),
            environment: Some(envMap),
            stdIn: ProcessRedirect.Pipe,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let transport = PipeTransport(proc)
        // 帧协议必须与插件端 LineStdioTransport + NewlineFraming 一致
        // （cordis_plugin/plugin_runtime.cj 的 JsonRpcServer 固定 NewlineFraming）。
        // 若漏传则默认 ContentLengthFraming，宿主无法解析插件的换行帧消息，
        // initialize 握手永远收不到 → awaitActive 超时 → 503 "plugin not running"
        let client = JsonRpcClient(transport, framing: NewlineFraming())
        // 注意：client.start() 延迟到 registerHostHandlers 之后调用，
        // 避免 receiveLoop 在 handler 注册之前启动而丢失 initialize 请求
        let instance = PluginInstance(entry, proc, client)
        this.forwardStderr(instance)
        instance
    }

    // ── 公共辅助 ──────────────────────────────────────────────────────

    /**
     * 独立线程转发插件 stderr 到宿主日志
     * stderr 仅供插件打日志；进程退出后 readln 返回 None，线程自然结束
     */
    private func forwardStderr(instance: PluginInstance): Unit {
        spawn {
            let reader = StringReader(instance.process.stdErrPipe)
            while (let Some(line) <- reader.readln()) {
                this.logger(instance.entry.id, line)
            }
        }
    }

    /**
     * 获取 stdx DLL 所在目录
     * CANGJIE_STDX_PATH 可能指向根目录，DLL 实际在 windows_x86_64_cjnative/dynamic/stdx 子目录
     * 依次探测：
     *   1. CANGJIE_STDX_PATH 本身（如果已指向 DLL 目录）
     *   2. CANGJIE_STDX_PATH/windows_x86_64_cjnative/dynamic/stdx
     *   3. CANGJIE_STDX_PATH 下的各 arch 子目录中查找 libstdx.dll
     */
    private func getCangjieStdxPath(): String {
        let raw = match (getVariable("CANGJIE_STDX_PATH")) {
            case Some(p) => p.replace("\\", "/")
            case None => ""
        }
        if (raw.isEmpty()) {
            return ""
        }
        // 探测标准子目录路径
        let candidate = "${raw}/windows_x86_64_cjnative/dynamic/stdx"
        if (exists("${candidate}/libstdx.dll")) {
            return candidate
        }
        // 回退：CANGJIE_STDX_PATH 本身可能已指向 DLL 目录
        if (exists("${raw}/libstdx.dll")) {
            return raw
        }
        // 都没找到，返回 candidate 让 Windows DLL 加载器报错（便于诊断）
        return candidate
    }

    /**
     * 获取宿主可执行文件所在目录。
     * 该目录通常包含宿主编译产出的所有 DLL（stdx、cangjie-runtime 等），
     * 将其添加到子进程 PATH 可确保插件进程找到所有依赖 DLL。
     *
     * 探测顺序：
     *   1. HOST_BIN_DIR 环境变量（宿主显式设置）
     *   2. 当前工作目录下的 bin/ 子目录
     *   3. 当前工作目录下的 target/release/bin/ 子目录
     */
    private func getHostExecutableDir(): ?String {
        // 方案 1：HOST_BIN_DIR 环境变量
        match (getVariable("HOST_BIN_DIR")) {
            case Some(dir) =>
                if (exists(dir)) {
                    return Some(dir)
                }
            case None => ()
        }
        // 方案 2/3：通过当前工作目录推断
        // 统一使用正斜杠，避免 Windows 反斜杠与正斜杠混用导致 exists() 失败
        let cwd = getWorkingDirectory().toString().replace("\\", "/")
        // 候选 2：cwd/bin（宿主在 target/release/ 下运行时）
        let binDir = "${cwd}/bin"
        if (exists("${binDir}/libstdx.encoding.json.dll")) {
            return Some(binDir)
        }
        // 候选 3：cwd/target/release/bin（宿主在项目根目录运行时）
        let relBinDir = "${cwd}/target/release/bin"
        if (exists("${relBinDir}/libstdx.encoding.json.dll")) {
            return Some(relBinDir)
        }
        return None<String>
    }

    /**
     * 把宿主 bin 目录中的所有 DLL 复制到插件 exe 所在目录。
     *
     * Windows DLL 加载顺序中，"应用目录"（exe 所在目录）是第一优先级。
     * 把 stdx DLL 复制到插件 exe 同目录，可以确保插件进程找到所有依赖 DLL，
     * 不依赖 PATH 环境变量传递（某些 launch() 实现可能不正确传递 environment）。
     *
     * 策略：
     *   1. 从 entry.source 推断插件 exe 所在目录
     *   2. 从 getHostExecutableDir() 获取宿主 bin 目录（包含所有 DLL）
     *   3. 复制宿主 bin 目录中所有 .dll 文件到插件 exe 目录
     */
    private func copyDepsToPluginDir(entry: PluginEntry): Unit {
        // 1. 推断插件 exe 所在目录
        let pluginExeDir = match (this.inferPluginExeDir(entry.source)) {
            case Some(dir) => dir
            case None =>
                this.logger(entry.id, "[copyDepsToPluginDir] WARNING: cannot infer plugin exe dir from source='${entry.source}'")
                return
        }
        // 2. 获取 stdx DLL 源目录（不是宿主 bin 目录，避免复制不兼容的 DLL）
        let stdxSrcDir = match (getCangjieStdxPath()) {
            case d => d
        }
        if (stdxSrcDir.isEmpty()) {
            this.logger(entry.id, "[copyDepsToPluginDir] WARNING: cannot find stdx DLL source dir")
            return
        }
        // 3. 先清理插件 exe 目录中的旧 DLL（避免不兼容的 DLL 干扰）
        //     只清理 .dll 文件，保留 .exe 和 .cjo 等
        let cleanedHolder = ArrayList<Int64>(1, { _ => 0 })
        Directory.walk(pluginExeDir) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                if (name.endsWith(".dll")) {
                    removeIfExists(fileInfo.path)
                    cleanedHolder[0] = cleanedHolder[0] + 1
                }
            }
            true
        }
        this.logger(entry.id, "[copyDepsToPluginDir] cleaned ${cleanedHolder[0].toString()} old DLLs from ${pluginExeDir}")

        // 4. 只复制 stdx DLL（libstdx.*.dll）到插件 exe 目录
        let copiedHolder = ArrayList<Int64>(1, { _ => 0 })
        Directory.walk(stdxSrcDir) { fileInfo =>
            if (!fileInfo.isDirectory()) {
                let name = fileInfo.path.fileName
                // 只复制 libstdx 开头的 DLL
                if (name.endsWith(".dll") && name.startsWith("libstdx")) {
                    let destPath = "${pluginExeDir}/${name}"
                    // 强制覆盖：确保插件使用最新版本的 stdx DLL
                    this.copyFile(fileInfo.path.toString(), destPath)
                    copiedHolder[0] = copiedHolder[0] + 1
                }
            }
            true
        }
        this.logger(entry.id, "[copyDepsToPluginDir] copied ${copiedHolder[0].toString()} stdx DLLs to ${pluginExeDir}")

        // 5. 复制仓颉核心运行时 DLL（libcangjie-runtime.dll、libboundscheck.dll 等）
        //    --dy-std 编译选项需要这些 DLL 在 exe 同目录或 PATH 中
        let runtimeDllCount = ArrayList<Int64>(1, { _ => 0 })
        let cangjieHome = match (getVariable("CANGJIE_HOME")) {
            case Some(h) => h.replace("\\", "/")
            case None => ""
        }
        if (!cangjieHome.isEmpty()) {
            let runtimeDir = "${cangjieHome}/runtime/lib/windows_x86_64_cjnative"
            if (exists(runtimeDir)) {
                Directory.walk(runtimeDir) { fileInfo =>
                    if (!fileInfo.isDirectory()) {
                        let name = fileInfo.path.fileName
                        // 只复制仓颉核心运行时 DLL
                        if (name.endsWith(".dll") && (name.startsWith("libcangjie") || name.startsWith("libboundscheck"))) {
                            let destPath = "${pluginExeDir}/${name}"
                            // 强制覆盖：确保插件使用正确版本的核心运行时 DLL
                            this.copyFile(fileInfo.path.toString(), destPath)
                            runtimeDllCount[0] = runtimeDllCount[0] + 1
                        }
                    }
                    true
                }
            }
        }
        this.logger(entry.id, "[copyDepsToPluginDir] copied ${runtimeDllCount[0].toString()} runtime DLLs to ${pluginExeDir}")
    }

    /**
     * 从 entry.source 推断插件 exe 所在目录。
     *
     * entry.source 可能是：
     *   - 相对路径：./skills/codelabs/target/release/bin/skill_codelabs.exe
     *   - 绝对路径：D:/UCT/.../skills/codelabs/target/release/bin/skill_codelabs.exe
     *
     * 返回 exe 所在目录的绝对路径（正斜杠格式）。
     */
    private func inferPluginExeDir(source: String): ?String {
        if (source.isEmpty()) {
            return None<String>
        }
        // 标准化路径：统一正斜杠
        let normalized = source.replace("\\", "/")
        // 查找最后一个 / 分隔符
        let lastSlashOpt = normalized.lastIndexOf("/")
        let dirPart = match (lastSlashOpt) {
            case Some(idx) =>
                if (idx == 0) {
                    // 根目录 /，dirPart 为 "/"
                    "/"
                } else {
                    normalized[0..idx]
                }
            case None =>
                // 没有目录分隔符，可能是直接命令名
                // 返回当前工作目录
                let cwd = getWorkingDirectory().toString().replace("\\", "/")
                return Some(cwd)
        }
        // 如果是相对路径，拼接当前工作目录
        let absDir = if (dirPart.startsWith("./") || dirPart.startsWith("../")) {
            let cwd = getWorkingDirectory().toString().replace("\\", "/")
            "${cwd}/${dirPart}"
        } else if (dirPart.size >= 2 && dirPart[1..2] == ":") {
            // 绝对路径（Windows 盘符开头，如 D:/...）
            dirPart
        } else {
            // 其他情况，拼接当前工作目录
            let cwd = getWorkingDirectory().toString().replace("\\", "/")
            "${cwd}/${dirPart}"
        }
        return Some(absDir)
    }

    /**
     * 复制文件（二进制安全）。
     */
    private func copyFile(src: String, dest: String): Unit {
        try {
            let srcFile = File(src, OpenMode.Read)
            let destFile = File(dest, OpenMode.Write)
            let buffer = Array<UInt8>(8192, {_ => 0})
            while (true) {
                let read = srcFile.read(buffer)
                if (read == 0) {
                    break
                }
                destFile.write(buffer[0..read])
            }
            srcFile.close()
            destFile.close()
        } catch (_: Exception) {
            // 复制失败不中断启动流程
        }
    }
}
