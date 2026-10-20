package uc_installer.platform

import std.env.getVariables
import std.fs.Path
import std.io.InputStream
import std.process.{launch, ProcessRedirect}
import std.time.DateTime
import std.collection.{ArrayList, HashMap}

// 子进程超时强杀（Phase 1 / T006）
//
// 三条实测约束（决定了本文件的实现方式，勿凭其它语言经验改写）：
//
// 1. `std.process.executeWithOutput` 没有 `timeout!` —— 等待上限必须自建。
//    本文件選用 `launch` + `SubProcess.wait(timeout!:)` 的组合。
// 2. **`wait(timeout:)` 超时时抛 `TimeoutException`，不是返回哨兵值**。
//    契约原文（`references/api/std/process/classes/subprocess/wait.md`）：
//      “timeout 值大于 Duration.Zero 时，阻塞等待子进程执行返回或等待超时后抛出超时异常”
//      “异常：TimeoutException - 当等待超时，子进程未退出时，抛出异常”
//    ⚠️ 这与 design.md §4.3.2 伪代码里的 `if (code != TIMEOUT_SENTINEL)` 不符 ——
//      那里假设返回哨兵值，真实实现必须用 try-catch 捕获异常。下面的作哨兵是我们自己定的。
// 3. **Pipe 模式必须在等待前排空管道，否则死锁**。契约原文警告：
//      “对于需要操作标准流的场景（Pipe 模式），使用者需要优先处理标准流，
//        避免子进程标准流缓冲区满后调用本函数产生死锁。”
//    即：子进程写满管道缓冲区会阻塞，从而永远不退出，wait 的超时也救不回来。
//    本文件用两个仓颉线程分别排空 stdout / stderr。

/// 超时判定的退出码哨兵值。
///
/// 真实退出码不会是负值（正常退出码 >= 0，被信号杀死时返回的是**信号编号**，亦为正数），
/// 因此用负数做哨兵是安全的。注意这是**本文件自己约定**的值，
/// 而非 `wait` 的返回值 —— `wait` 超时只会抛异常。
public let WAIT_TIMEOUT_SENTINEL: Int64 = -9

/// 进程树兜底清理自身的等待上限（防止 taskkill 卡住反向拖死安装器）。
private let KILL_WAIT_CAP: Duration = Duration.second * 5

/// 管道收敛的等待上限：进程被杀后管道 EOF，正常会很快结束；
/// 设置上限只为兜住极端情况，超时返回空数组而不向上抛。
private let DRAIN_JOIN_CAP: Duration = Duration.second * 3

/// 排空管道时的读取缓冲区大小。
private let DRAIN_BUFFER_SIZE: Int64 = 8192

/// 子进程执行结果。
///
/// `timedOut` 为真时 `exitCode` 恒为 `WAIT_TIMEOUT_SENTINEL` —— 调用方**不得**
/// 用退出码判断成功，必须先看 `timedOut`（对应 AC-035 的“禁止依赖不存在的超时入参”，
/// 也对应 §4.3.2 要点 4「禁止以退出码 0 冒充成功」）。
public struct RunResult {
    public let exitCode: Int64
    public let stdout: Array<Byte>
    public let stderr: Array<Byte>
    public let timedOut: Bool
    public let killedTree: Bool
    public let elapsed: Duration

    public init(exitCode: Int64, stdout: Array<Byte>, stderr: Array<Byte>,
                timedOut: Bool, killedTree: Bool, elapsed: Duration) {
        this.exitCode = exitCode
        this.stdout = stdout
        this.stderr = stderr
        this.timedOut = timedOut
        this.killedTree = killedTree
        this.elapsed = elapsed
    }
}

/// 按行切分子进程输出，兼容 Windows 的 \r\n 与 Unix 的 \n 两种换行。
///
/// 放在这里而不是各自文件里重抄一份：平台层四个模块都要解析命令行输出
/// （tasklist / reg / netstat），三份同逻辑的私有函数一旦某份修正了换行 handling，
/// 另两份就会静默漂移。这里统一实现，其余模块直接调用。
public func splitLines(text: String): ArrayList<String> {
    let normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    let out = ArrayList<String>()
    for (seg in normalized.split("\n")) {
        out.add(seg)
    }
    return out
}

/// 把 stdout / stderr 的字节数组按 UTF-8 宽松解码为字符串。
///
/// 宽松的含义：严格 UTF-8 解码失败时退化为 unchecked 解码。
/// 理由同宿主 `ScriptExecutor.decodeOutput` —— Windows 下 `tasklist` / `psql` 等
/// 命令的输出常含 GBK 字节，严格解码会抛 "Invalid utf8 byte sequence"，
/// 一旦异常冒泡到外层，一次编码问题会让**已成功的命令被判成失败**，
/// 且错误信息完全误导排查方向。宁可 mojibake 也不丢内容。
public func decodeOutput(bytes: Array<Byte>): String {
    if (bytes.size == 0) {
        return ""
    }
    // ⚠️ `fromUtf8Unchecked` 是 unsafe 函数，**必须用 unsafe 块包裹**。
    // 宿主实证：`ScriptExecutor.cj:96`、`lrt_host_executor.cj:911`、
    // `CrudGenService.cj:213` 等 5 处一律写成 unsafe 形式。
    let text = try {
        String.fromUtf8(bytes)
    } catch (_: Exception) {
        unsafe { String.fromUtf8Unchecked(bytes) }
    }
    return text
}

/// 构造子进程的完整环境变量（**红线：environment 是整体替换，不是合并**）。
///
/// `launch` / `executeWithOutput` 的 `environment!` 传值是**整体替换**子进程环境，
/// 而非增量合并。只塞自定义键会丢掉 PATH，导致 `where psql` 之类的命令
/// 直接找不到可执行文件 —— 这是极隐蔽的故障，症状表现为“命令不存在”。
///
/// 工程实证：宿主 `ScriptExecutor.childEnv()`（`src/app/services/crontab/executor/ScriptExecutor.cj:76`）
/// 与 `skills/llm_channel_tokendance/src/adapter_http.cj:284` 都是这个做法。
///
/// - extra: 需要叠加/覆盖的键值对
/// - returns: 父进程全量环境 + extra
public func fullEnv(extra: HashMap<String, String>): HashMap<String, String> {
    // 与宿主三处写法保持一致（`ScriptExecutor.cj:76`、`utils/os.cj:62`、`:92` 一律不带泛型实参），
    // 泛型靠左侧类型标注给出 —— 这是已验证能编过的形态。
    let all: HashMap<String, String> = HashMap(getVariables())
    for ((k, v) in extra) {
        all[k] = v
    }
    return all
}

/// 从输入流读到 EOF，返回全部字节。
///
/// `InputStream` 只有 `read(buffer: Array<Byte>): Int64`（返回本次读到的字节数），
/// 没有 readToEnd —— 那个是 `StringReader` 的成员，别混用。
private func drainToArray(stream: InputStream): Array<Byte> {
    let buffer = Array<Byte>(DRAIN_BUFFER_SIZE, {_ => 0u8})
    let acc = ArrayList<Byte>()
    while (true) {
        let n = stream.read(buffer)
        if (n <= 0) {
            break
        }
        var i: Int64 = 0
        while (i < n) {
            acc.add(buffer[i])
            i = i + 1
        }
    }
    return acc.toArray()
}

/// 取排空线程的结果，取不到就返回空数组（不向上抛）。
///
/// 用 `Future.get(timeout:)` 而非无参 `get()`：进程若被强杀后仍有孙进程
/// 持有管道写端，读端不会立即 EOF，无参 get 会把管线卡住 ——
/// 那就背离了 T006「避免 hang」的根本目标。
private func awaitDrainedBytes(fut: Future<Array<Byte>>): Array<Byte> {
    // ⚠️ `get(timeout: Duration)` 的 timeout **不是**命名参数（签名里没有感叹号），
    // 因此这里只能按位置传 `get(cap)`；写成 `get(timeout: cap)` 会报
    // “invalid named arguments prefix”。对照 `wait(timeout!: ...)` —— 那个带感叹号，
    // 才是命名参数。有无感叹号是唯一判据，别按“看起来像配置项”来猜。
    try {
        return fut.get(DRAIN_JOIN_CAP)
    } catch (_: TimeoutException) {
        return Array<Byte>()
    } catch (_: Exception) {
        return Array<Byte>()
    }
}

/// 终止进程树（Windows：`taskkill /PID <pid> /T /F`，`/T` = 含子进程）。
///
/// ⚠️ 这里**不能**调用 runCapped 自己：清理路径再走一遍超时控制会形成递归依赖，
/// 且清理失败也必须如实返回 false 而不是抛 —— 详见下方两处 try 的用意。
/// 三条标准流一律 Discard：既不产生管道死锁风险，也不需要它们的输出。
///
/// - pid: 待终止进程树根进程的 pid
/// - returns: taskkill 是否报告成功（退出码 0）
public func killProcessTree(pid: Int64): Bool {
    try {
        let killer = launch(
            "taskkill",
            ["/PID", "${pid}", "/T", "/F"],
            environment: HashMap(getVariables()),
            stdIn: ProcessRedirect.Discard,
            stdOut: ProcessRedirect.Discard,
            stdErr: ProcessRedirect.Discard
        )
        let code = try {
            killer.wait(timeout: KILL_WAIT_CAP)
        } catch (_: TimeoutException) {
            -1
        }
        return code == 0
    } catch (_: Exception) {
        // 进程已退出 / 权限不足 / taskkill 不存在等情况，
        // 一律如实返回 false，由上层决定是否需要人工介入。
        return false
    }
}

/// 带等待上限地执行一次外部命令；超时则强杀进程树。
///
/// 这是**整个 installer 唯一的子进程入口**，其余平台层能力（T007 进程表、
/// T030 openssl、T032 下载、DevKit 的 git clone）都必须经由它，
/// 这样 AC-035「禁止依赖不存在的超时入参」才不会被某个漏网的调用点破坏。
///
/// - cmd: 可执行文件名或路径
/// - args: 参数列表
/// - cap: 等待上限，默认 5s（AC-057：任一子探测命令的等待上限）
/// - cwd: 子进程工作目录，省略则继承当前进程
/// - env: 需要叠加的环境变量；内部会先取父进程全量环境再叠加（见 fullEnv 红线）
/// - returns: 执行结果；`timedOut` 为真表示**未等到退出**，不代表命令执行失败
public func runCapped(cmd: String, args: Array<String>, cap!: Duration = Duration.second * 5,
                      cwd!: ?Path = None, env!: ?HashMap<String, String> = None): RunResult {
    let startedAt = DateTime.now()

    let childEnv = buildChildEnv(env)

    let p = launch(
        cmd, args,
        workingDirectory: cwd,
        environment: childEnv,
        stdIn: ProcessRedirect.Discard,
        stdOut: ProcessRedirect.Pipe,
        stdErr: ProcessRedirect.Pipe
    )

    // 必须在 wait 之前取出管道并把排空交给独立线程，否则子进程输出写满管道缓冲区后会阻塞，
    // 进而永远不退出 —— 届时 wait 超时也救不回来（契约明确警告过这个死锁）。
    let outPipe = p.stdOutPipe
    let errPipe = p.stdErrPipe

    let outFuture: Future<Array<Byte>> = spawn { drainToArray(outPipe) }
    let errFuture: Future<Array<Byte>> = spawn { drainToArray(errPipe) }

    let outcome = try {
        p.wait(timeout: cap)
    } catch (_: TimeoutException) {
        WAIT_TIMEOUT_SENTINEL
    }
    let timedOut = outcome == WAIT_TIMEOUT_SENTINEL

    var killedTree = false
    if (timedOut) {
        // 先温和/强制终止直接子进程，再兜进程树 —— terminate 只对直接子进程生效，
        // psql / openssl / git 都可能再拉孙进程，兜底不可省（§4.3.2 要点 3）。
        try {
            p.terminate(force: true)
        } catch (_: Exception) {
            // 进程可能刚好在 wait 超时与 terminate 之间自行退出，忽略。
        }
        killedTree = killProcessTree(p.pid)
    }

    let stdoutBytes = awaitDrainedBytes(outFuture)
    let stderrBytes = awaitDrainedBytes(errFuture)

    let elapsed = DateTime.now().toUnixTimeStamp() - startedAt.toUnixTimeStamp()

    let finalExitCode = if (timedOut) {
        WAIT_TIMEOUT_SENTINEL
    } else {
        outcome
    }

    return RunResult(finalExitCode, stdoutBytes, stderrBytes, timedOut, killedTree, elapsed)
}

/// 按 environment 的整体替换语义构造子进程环境。
///
/// 无论调用方是否给 extra，都以父进程全量环境为基底 —— 这样即便将来有人在
/// 调用点只传一个键，也不会出现 PATH 丢失。
private func buildChildEnv(extra: ?HashMap<String, String>): HashMap<String, String> {
    // 基底先算出来再进 match：match 臂要保持单表达式（多语句块会被解析成 lambda），
    // 且这样两个臂的类型都由已标注的 base 锚定，不依赖返回值位置的类型推断。
    let base: HashMap<String, String> = HashMap(getVariables())
    match (extra) {
        case Some(m) => fullEnv(m)
        case None => base
    }
}

/// 判断一次执行结果是否为真正的成功。
///
/// 成功 = 未超时 **且** 退出码为 0。`timedOut` 为真时即便拿到退出码 0 也不算成功 ——
/// 那正是 §4.3.2 要点 4「禁止以退出码 0 冒充成功」要挡住的场景。
public func succeeded(r: RunResult): Bool {
    (!r.timedOut) && r.exitCode == 0
}
