package ystyle::cordis_host

import ystyle::jsonrpc.{Transport}
import std.process.SubProcess
import std.io.{InputStream, OutputStream}
import std.sync.Mutex

/**
 * 子进程管道传输层（docs/design-impl.md §3.2）
 *
 * 实现 jsonrpc 的 Transport 接口，将宿主与插件子进程间的 JSON-RPC 消息
 * 映射到进程管道：
 * - send(data)    → 写入子进程 stdin（宿主 → 插件）
 * - receive()     → 从子进程 stdout 读取（宿主 ← 插件），EOF 返回 None
 * - close()       → 关闭写端并标记关闭（JsonRpcClient 收到 None 后自动停止）
 *
 * 说明：stdout EOF 即插件进程退出，JsonRpcClient.receiveLoop 据此自动
 * 停止，宿主据此判定意外退出（docs/design-impl.md §8 崩溃检测）。
 */
public class PipeTransport <: Transport {
    private let stdin: OutputStream
    private let stdout: InputStream
    private let lock: Mutex = Mutex()
    private var closed: Bool = false

    public init(sub: SubProcess) {
        this.stdin = sub.stdInPipe
        this.stdout = sub.stdOutPipe
    }

    // 宿主 → 插件：写子进程 stdin
    public func send(data: Array<Byte>): Unit {
        synchronized(this.lock) {
            if (this.closed) {
                return
            }
            this.stdin.write(data)
            this.stdin.flush()
        }
    }

    // 宿主 ← 插件：读子进程 stdout（阻塞；EOF 返回 None → JsonRpcClient 自动关闭）
    public func receive(): ?Array<Byte> {
        let buffer = Array<Byte>(4096, repeat: 0)
        let len = this.stdout.read(buffer)
        if (len <= 0) {
            None
        } else {
            buffer[0..len]
        }
    }

    public func close(): Unit {
        synchronized(this.lock) {
            if (this.closed) {
                return
            }
            this.closed = true
        }
        // 注意：OutputStream 无 close() 接口（与 jsonrpc StdioTransport 一致）。
        // 通知插件 EOF 由 PluginManager.terminate 的进程强杀完成（stdout 关闭 → 宿主 receive EOF）。
    }

    public func isClosed(): Bool {
        synchronized(this.lock) {
            this.closed
        }
    }
}
