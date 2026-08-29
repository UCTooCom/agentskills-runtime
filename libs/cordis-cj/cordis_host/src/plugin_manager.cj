package ystyle::cordis_host

import ystyle::cordis_core.{PluginEntry, InstanceStatus}
import ystyle::jsonrpc.JsonRpcClient
import std.process.{launch, SubProcess, ProcessRedirect}
import std.env.{getVariables, getVariable}
import std.fs.exists
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
        // Windows: 子进程需要能找到 stdx 动态库 DLL
        // 设置 PATH 环境变量包含 stdx DLL 目录
        let envMap = HashMap<String, String>()
        for ((k, v) in getVariables()) {
            envMap[k] = v
        }
        let stdxPath = getCangjieStdxPath()
        if (!stdxPath.isEmpty()) {
            let currentPath = match (envMap.get("PATH")) {
                case Some(p) => p
                case None => ""
            }
            envMap["PATH"] = "${stdxPath};${currentPath}"
        }
        let proc = launch(entry.source, entry.args.toArray(),
            environment: Some(envMap),
            stdIn: ProcessRedirect.Pipe,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let transport = PipeTransport(proc)
        let client = JsonRpcClient(transport)
        client.start()
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
            case Some(p) => p
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
}
