package ystyle::cordis_plugin

import ystyle::jsonrpc.Transport
import std.env.{getStdIn, getStdOut}
import std.sync.Mutex

/**
 * 插件侧标准流传输（换行帧版）
 *
 * 仓颉 ConsoleReader.read(Array<Byte>) 在管道 stdin（子进程被 launch 拉起的场景）
 * 下会永久阻塞，无法用于 Content-Length 帧的精确字节读取；而 readln() 可靠。
 * 因此插件侧使用逐行读取 + 换行分隔帧（与 mcp-cj 生产方案一致），
 * 宿主侧 PipeTransport 同步使用 NewlineFraming 保持两端一致。
 *
 * - send：getStdOut().write + flush（宿主侧 PipeTransport.receive 读取）
 * - receive：getStdIn().readln() 逐行读取，EOF 返回 None
 */
public class LineStdioTransport <: Transport {
    private let lock: Mutex = Mutex()
    private var closed: Bool = false

    public init() {}

    // 插件 → 宿主：写 stdout
    public func send(data: Array<Byte>): Unit {
        synchronized(this.lock) {
            if (this.closed) {
                return
            }
            let stdout = getStdOut()
            stdout.write(data)
            stdout.flush()
        }
    }

    // 插件 ← 宿主：逐行读 stdin（换行帧协议；EOF 返回 None）
    // 注意：readln 会去掉行尾换行符，需补回 '\n' 让 NewlineFraming 正常解析
    public func receive(): ?Array<Byte> {
        match (getStdIn().readln()) {
            case Some(line) =>
                let bytes = line.toArray()
                let result = Array<Byte>(bytes.size + 1, repeat: 0)
                for (i in 0..bytes.size) {
                    result[i] = bytes[i]
                }
                result[bytes.size] = 10
                Some(result)
            case None => None
        }
    }

    public func close(): Unit {
        synchronized(this.lock) {
            this.closed = true
        }
    }

    public func isClosed(): Bool {
        synchronized(this.lock) {
            this.closed
        }
    }
}
