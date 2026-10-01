/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.utils

import std.fs.{File, Path, OpenMode}
import std.time.DateTime
import std.env.getWorkingDirectory

/**
 * 启动期卡死诊断：无缓冲、绕过 stdout 的落盘 trace。
 *
 * 【为什么不用 println】cmd 捕获 runtime stdout 走的是 4KB 带缓冲的管道，进程被
 * Ctrl+C / kill 时尾部整段丢失（实测单次启动丢失近 3.9KB 未落盘）。历次启动日志
 * 都因此看不到 awaitActive 之后的真实落点，只能靠猜。
 *
 * 这里直接用 File(OpenMode.Append) 写文件：不经 stdout、不经日志子系统、进程被杀也
 * 落盘，因此能给出启动路径上「最后一条执行到的语句」。
 *
 * 【注意】调用点必须串行落在主线程关键路径上；不要在多条线程写同一个文件（会交错）。
 *
 * 定位到根因后可整体删除本文件及其所有调用点。
 */
public func traceStartup(msg: String): Unit {
    let ts = DateTime.now().format("HHmmss.SSS")
    // 【路径必须绝对】cjpm run 会把子进程工作目录设在 target/release/bin，相对路径
    // `logs/...` 在该 cwd 下也可能写失败，而这里用 try 吞异常 → 文件永远不出现，
    // 曾经因此误判「trace 埋点没走到」。用 getWorkingDirectory() 取实际 cwd 拼绝对路径。
    let base = getWorkingDirectory().toString()
    try (f = File(Path("${base}/logs/startup-trace.txt"), OpenMode.Append)) {
        f.write("[${ts}] ${msg}\n".toArray())
    }
}
