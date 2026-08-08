/*
 * buffer.cj —— 协议报文的字节级读写原语。
 *
 * 依据 54.6 节的基础数据类型实现：
 *   - Intn：网络字节序（大端）整数；
 *   - String：以 NUL 结尾的 C 字符串；
 *   - Byten：定长字节序列。
 *
 * MessageWriter 负责拼装前端报文，MessageReader 负责解析后端报文体。
 */

package pgsql

import std.collection.*
import std.database.sql.*

/**
 * 前端报文构造器。
 *
 * 链式追加各字段后，再由 `build` / `buildUntyped` 加上报文头（类型字节 + 长度）。
 * 长度字段按协议规定包含其自身的 4 个字节，但不包含前置的类型标识字节。
 */
public class MessageWriter {
    private let buf: ArrayList<Byte>

    public init() {
        buf = ArrayList<Byte>()
    }

    /** 追加单个字节。 */
    public func putByte(b: Byte): MessageWriter {
        buf.add(b)
        return this
    }

    /** 以大端序追加 16 位整数。 */
    public func putInt16(v: Int16): MessageWriter {
        buf.add(UInt8((v >> 8) & 0xFF))
        buf.add(UInt8(v & 0xFF))
        return this
    }

    /** 以大端序追加 32 位整数（NULL 长度 -1 等负值按补码写出）。 */
    public func putInt32(v: Int32): MessageWriter {
        buf.add(UInt8((v >> 24) & 0xFF))
        buf.add(UInt8((v >> 16) & 0xFF))
        buf.add(UInt8((v >> 8) & 0xFF))
        buf.add(UInt8(v & 0xFF))
        return this
    }

    /** 以 NUL 结尾追加 UTF-8 C 字符串。 */
    public func putCString(s: String): MessageWriter {
        buf.add(all: s.toArray())
        buf.add(0x00)
        return this
    }

    /** 追加原始字节序列（不含长度前缀）。 */
    public func putBytes(arr: Array<Byte>): MessageWriter {
        buf.add(all: arr)
        return this
    }

    /** 当前报文体的字节数。 */
    public func size(): Int64 {
        return buf.size
    }

    /** 导出当前累积的字节（不含报文头）。 */
    public func toArray(): Array<Byte> {
        return buf.toArray()
    }

    /**
     * 组装带类型标识的完整报文：`msgType | Int32(len) | body`，
     * 其中 `len = body.size + 4`。
     */
    public func build(msgType: Byte): Array<Byte> {
        let body = buf.toArray()
        let len = Int32(body.size + 4)
        let out = MessageWriter()
        out.putByte(msgType).putInt32(len).putBytes(body)
        return out.toArray()
    }

    /**
     * 组装无类型标识的报文：`Int32(len) | body`，
     * 用于 StartupMessage、SSLRequest 等启动阶段报文。
     */
    public func buildUntyped(): Array<Byte> {
        let body = buf.toArray()
        let len = Int32(body.size + 4)
        let out = MessageWriter()
        out.putInt32(len).putBytes(body)
        return out.toArray()
    }
}

/**
 * 后端报文体解析器。
 *
 * 持有一段已完整接收的报文体字节（不含类型与长度头），按游标顺序读取字段。
 * 越界读取会抛出 [SqlException]，对应损坏或非预期的协议数据。
 */
public class MessageReader {
    private let data: Array<Byte>
    private var pos: Int64

    public init(data: Array<Byte>) {
        this.data = data
        this.pos = 0
    }

    // 读取前确保剩余字节充足。
    private func ensure(n: Int64): Unit {
        if (pos + n > data.size) {
            throw SqlException("protocol error: unexpected end of message (need ${n} bytes at ${pos}, have ${data.size})")
        }
    }

    /** 读取单个字节。 */
    public func readByte(): Byte {
        ensure(1)
        let b = data[pos]
        pos += 1
        return b
    }

    /** 以大端序读取带符号 16 位整数（如类型长度 typlen 可能为负）。 */
    public func readInt16(): Int16 {
        ensure(2)
        // 左移会自动截断高位，因此可直接用 Int16 运算还原补码。
        let v = (Int16(data[pos]) << 8) | Int16(data[pos + 1])
        pos += 2
        return v
    }

    /** 以大端序读取无符号 16 位整数，返回 Int64（用于列数、格式码等非负计数）。 */
    public func readUInt16(): Int64 {
        ensure(2)
        let v = (Int64(data[pos]) << 8) | Int64(data[pos + 1])
        pos += 2
        return v
    }

    /** 以大端序读取带符号 32 位整数（如列值长度 -1 表示 NULL）。 */
    public func readInt32(): Int32 {
        ensure(4)
        let v = (Int32(data[pos]) << 24) | (Int32(data[pos + 1]) << 16) |
            (Int32(data[pos + 2]) << 8) | Int32(data[pos + 3])
        pos += 4
        return v
    }

    /** 读取以 NUL 结尾的 C 字符串并返回其 UTF-8 解码结果。 */
    public func readCString(): String {
        let start = pos
        while (pos < data.size && data[pos] != 0x00) {
            pos += 1
        }
        if (pos >= data.size) {
            throw SqlException("protocol error: unterminated C-string")
        }
        let slice = data[start..pos]
        pos += 1 // 跳过 NUL 终止符
        return String.fromUtf8(slice)
    }

    /** 读取定长 n 个字节。 */
    public func readBytes(n: Int64): Array<Byte> {
        ensure(n)
        let slice = data[pos..pos + n]
        pos += n
        return slice
    }

    /** 剩余未读字节数。 */
    public func remaining(): Int64 {
        return data.size - pos
    }

    /** 是否仍有未读字节。 */
    public func hasMore(): Bool {
        return pos < data.size
    }

    /** 读取并返回剩余的全部字节。 */
    public func readRemaining(): Array<Byte> {
        let slice = data[pos..data.size]
        pos = data.size
        return slice
    }
}
