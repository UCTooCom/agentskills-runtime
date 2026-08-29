package ystyle::jsonrpc

import std.convert.*
import std.unicode.*

public interface Framing {
    func encode(body: Array<Byte>): Array<Byte>
    func decode(data: Array<Byte>): ?(Array<Byte>, Int64)
}

public class ContentLengthFraming <: Framing {
    public func encode(body: Array<Byte>): Array<Byte> {
        let header = "Content-Length: ${body.size}\r\n\r\n"
        let headerBytes = header.toArray()
        let result = Array<Byte>(headerBytes.size + body.size, repeat: 0)
        var idx: Int64 = 0
        for (b in headerBytes) {
            result[idx] = b
            idx++
        }
        for (b in body) {
            result[idx] = b
            idx++
        }
        result
    }

    public func decode(data: Array<Byte>): ?(Array<Byte>, Int64) {
        let headerEnd = findHeaderEnd(data)
        if (headerEnd < 0) { return None }
        let header = String.fromUtf8(data[0..headerEnd])
        let length = parseContentLength(header)
        if (length < 0) { return None }
        let bodyStart = headerEnd + 4
        if (data.size < bodyStart + length) { return None }
        let body = data[bodyStart..(bodyStart + length)]
        Some((body, bodyStart + length))
    }
}

public class NewlineFraming <: Framing {
    public func encode(body: Array<Byte>): Array<Byte> {
        let result = Array<Byte>(body.size + 1, repeat: 0)
        for (i in 0..body.size) { result[i] = body[i] }
        result[body.size] = 10
        result
    }

    public func decode(data: Array<Byte>): ?(Array<Byte>, Int64) {
        for (i in 0..data.size) {
            if (data[i] == 10) {
                let bodyEnd = if (i > 0 && data[i - 1] == 13) { i - 1 } else { i }
                return Some((data[0..bodyEnd], i + 1))
            }
        }
        None
    }
}

private func findHeaderEnd(content: Array<Byte>): Int64 {
    if (content.size < 4) { return -1 }
    var i: Int64 = 0
    let end = content.size - 4
    while (i <= end) {
        if (content[i] == 13 && content[i + 1] == 10 && content[i + 2] == 13 && content[i + 3] == 10) {
            return i
        }
        i++
    }
    -1
}

private func parseContentLength(header: String): Int64 {
    let lines = header.split('\n')
    for (line in lines) {
        let trimmed = line.trim()
        if (trimmed.startsWith("Content-Length:")) {
            let valueStr = trimmed[16..].trimAscii()
            match (Int64.tryParse(valueStr)) {
                case Some(v) => return v
                case None => return -1
            }
        }
    }
    -1
}

public func encode(body: Array<Byte>): Array<Byte> {
    ContentLengthFraming().encode(body)
}

public func decode(content: Array<Byte>): ?(Array<Byte>, Int64) {
    ContentLengthFraming().decode(content)
}
