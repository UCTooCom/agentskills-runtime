package http_lib.server
/**
 * MIME 类型嗅探（Content-Type 推断）。
 * 通过读取文件魔术数字判断 MIME 类型。
 */

/**
 * Content-Type 嗅探（基于文件魔数检测）。
 *
 * 读取数据的前几个字节以在文件扩展名缺失或不可靠时
 * 检测内容类型。
 *
 * 嗅探优先级：
 * 1. HTML/XML 标签
 * 2. 魔数（PDF、PNG、GIF、JPEG 等）
 * 3. 文本 vs 二进制检测
 * 4. 默认：application/octet-stream
 *
 * 读取前 512 字节检测内容类型。
 * 完整算法基于 WHATWG MIME Sniffing 标准，此处是
 * 覆盖所有常见类型。
 */

/**
 * 从数据的前几个字节检测 Content-Type。
 * 最多读取 sniffLen（512）字节。
 */
public func detectContentType(data: Array<UInt8>): String {
    let len = if (data.size > 512) { 512 } else { data.size }
    if (len == 0) { return "application/octet-stream" }

    // 检测 HTML
    if (len >= 4 && data[0] == b'<' && data[1] == b'h' && data[2] == b't' && data[3] == b'm') {
        return "text/html; charset=utf-8"
    }
    if (len >= 4 && data[0] == b'<' && data[1] == b'H' && data[2] == b'T' && data[3] == b'M') {
        return "text/html; charset=utf-8"
    }
    if (len >= 3 && data[0] == b'<' && data[1] == b'h' && data[2] == b' ') {
        return "text/html; charset=utf-8"
    }
    if (len >= 3 && data[0] == b'<' && data[1] == b'H' && data[2] == b' ') {
        return "text/html; charset=utf-8"
    }

    // 检测 XML
    if (len >= 2 && data[0] == b'<' && data[1] == b'?') {
        return "text/xml; charset=utf-8"
    }
    if (len >= 2 && data[0] == b'<' && data[1] == b'!') {
        let tag = if (len >= 4) {
            try {
                String.fromUtf8(data[0..4])
            } catch (_: Exception) { "" }
        } else { "" }
        if (tag.startsWith("<!--") || tag.startsWith("<!DO")) {
            return "text/html; charset=utf-8"
        }
    }

    // 检测 PDF
    if (len >= 4 && data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46) {
        return "application/pdf"
    }

    // 检测 PNG
    if (len >= 8 &&
        data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 &&
        data[4] == 0x0D && data[5] == 0x0A && data[6] == 0x1A && data[7] == 0x0A) {
        return "image/png"
    }

    // 检测 GIF
    if (len >= 3 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) {
        return "image/gif"
    }

    // 检测 JPEG
    if (len >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
        return "image/jpeg"
    }

    // 检测 BMP
    if (len >= 2 && data[0] == 0x42 && data[1] == 0x4D) {
        return "image/bmp"
    }

    // 检测 WebP（RIFF + WEBP）
    if (len >= 12 &&
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50) {
        return "image/webp"
    }

    // 检测 ZIP/DOCX/XLSX
    if (len >= 2 && data[0] == 0x50 && data[1] == 0x4B) {
        // 检测 ZIP 内的签名
        if (len >= 30) {
            // 尝试通过内容检测 Office 文档
            let str = try { String.fromUtf8(data[0..30]) } catch (_: Exception) { "" }
            if (str.contains("word/")) { return "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
            if (str.contains("xl/")) { return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
            if (str.contains("ppt/")) { return "application/vnd.openxmlformats-officedocument.presentationml.presentation" }
        }
        return "application/zip"
    }

    // 检测 GZip
    if (len >= 2 && data[0] == 0x1F && data[1] == 0x8B) {
        return "application/gzip"
    }

    // 检测 MP4（ISO 基础媒体文件格式：偏移 4 处的 ftyp box）
    if (len >= 12 && data[4] == 0x66 && data[5] == 0x74 && data[6] == 0x79 && data[7] == 0x70) {
        return "video/mp4"
    }

    // 检测 UTF-16BE BOM
    if (len >= 2 && data[0] == 0xFE && data[1] == 0xFF) {
        if (len >= 4 && data[2] == 0x00) { return "text/plain; charset=utf-16be" }
    }
    // 检测 UTF-16LE BOM
    if (len >= 2 && data[0] == 0xFF && data[1] == 0xFE) {
        if (len >= 4 && data[3] == 0x00) { return "text/plain; charset=utf-16le" }
    }
    // 检测 UTF-8 BOM
    if (len >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) {
        return "text/plain; charset=utf-8"
    }

    // 检测 SVG — 在前几个字节中查找 <svg 或 <SVG
    if (len >= 4) {
        try {
            let str = String.fromUtf8(data[0..len])
            if (str.contains("<svg") || str.contains("<SVG") || str.contains("<!DOCTYPE svg")) {
                return "image/svg+xml"
            }
        } catch (_: Exception) {
            // 无效 UTF-8，非 SVG 文本
        }
    }

    // 检查是否为纯文本（无空字节，可打印 ASCII）

    // 检测 MP3（开头的 ID3 标签）
    if (len >= 3 && data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33) {
        return "audio/mpeg"
    }
    // 检测 MP3（MPEG 同步字 0xFFFx：第一个字节 0xFF，第二个字节 0xF0-0xFF）
    if (len >= 2 && data[0] == 0xFF && (data[1] & 0xF0) == 0xF0) {
        return "audio/mpeg"
    }

    // 检测 OGG（OggS 魔数）
    if (len >= 4 && data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53) {
        return "application/ogg"
    }

    // 检测 FLAC（fLaC 魔数）
    if (len >= 4 && data[0] == 0x66 && data[1] == 0x4C && data[2] == 0x61 && data[3] == 0x43) {
        return "audio/flac"
    }

    // 检测 WOFF（wOFF 魔数）
    if (len >= 4 && data[0] == 0x77 && data[1] == 0x4F && data[2] == 0x46 && data[3] == 0x46) {
        return "font/woff"
    }

    // 检测 WOFF2（wOF2 魔数）
    if (len >= 4 && data[0] == 0x77 && data[1] == 0x4F && data[2] == 0x46 && data[3] == 0x32) {
        return "font/woff2"
    }

    // 检测 TIFF 小端（II 魔数）
    if (len >= 2 && data[0] == 0x49 && data[1] == 0x49) {
        return "image/tiff"
    }
    // 检测 TIFF 大端（MM 魔数）
    if (len >= 2 && data[0] == 0x4D && data[1] == 0x4D) {
        return "image/tiff"
    }

    // 检测 PostScript（%!PS-Adobe-）
    if (len >= 9 &&
        data[0] == 0x25 && data[1] == 0x21 && data[2] == 0x50 && data[3] == 0x53 &&
        data[4] == 0x2D && data[5] == 0x41 && data[6] == 0x64 && data[7] == 0x6F && data[8] == 0x62) {
        return "application/postscript"
    }

    // 检测 ICO（Windows 图标）
    if (len >= 4 && data[0] == 0x00 && data[1] == 0x00 && data[2] == 0x01 && data[3] == 0x00) {
        return "image/x-icon"
    }

    // 检测 WebM / Matroska
    if (len >= 4 && data[0] == 0x1A && data[1] == 0x45 && data[2] == 0xDF && data[3] == 0xA3) {
        return "video/webm"
    }

    // 检测 AVI（RIFF + AVI ）
    if (len >= 12 &&
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x41 && data[9] == 0x56 && data[10] == 0x49 && data[11] == 0x20) {
        return "video/avi"
    }

    // 检测 WAVE（RIFF + WAVE）
    if (len >= 12 &&
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x41 && data[10] == 0x56 && data[11] == 0x45) {
        return "audio/wave"
    }

    // 检测 AIFF（FORM + AIFF）
    if (len >= 12 &&
        data[0] == 0x46 && data[1] == 0x4F && data[2] == 0x52 && data[3] == 0x4D &&
        data[8] == 0x41 && data[9] == 0x49 && data[10] == 0x46 && data[11] == 0x46) {
        return "audio/aiff"
    }

    // 检测 MIDI（MThd）
    if (len >= 8 &&
        data[0] == 0x4D && data[1] == 0x54 && data[2] == 0x68 && data[3] == 0x64 &&
        data[4] == 0x00 && data[5] == 0x00 && data[6] == 0x00 && data[7] == 0x06) {
        return "audio/midi"
    }

    // 检测 TTF（TrueType）
    if (len >= 5 && data[0] == 0x00 && data[1] == 0x01 && data[2] == 0x00 && data[3] == 0x00 && data[4] == 0x00) {
        return "font/ttf"
    }

    // 检测 OTF（OpenType）
    if (len >= 4 && data[0] == 0x4F && data[1] == 0x54 && data[2] == 0x54 && data[3] == 0x4F) {
        return "font/otf"
    }

    // 检测 RAR
    if (len >= 7 &&
        data[0] == 0x52 && data[1] == 0x61 && data[2] == 0x72 && data[3] == 0x21 &&
        data[4] == 0x1A && data[5] == 0x07) {
        return "application/x-rar-compressed"
    }

    // 检测 7z
    if (len >= 6 &&
        data[0] == 0x37 && data[1] == 0x7A && data[2] == 0xBC && data[3] == 0xAF &&
        data[4] == 0x27 && data[5] == 0x1C) {
        return "application/x-7z-compressed"
    }

    // 检测 WASM
    if (len >= 4 && data[0] == 0x00 && data[1] == 0x61 && data[2] == 0x73 && data[3] == 0x6D) {
        return "application/wasm"
    }

    if (isPlainText(data, len)) {
        return "text/plain; charset=utf-8"
    }

    "application/octet-stream"
}

/**
 * 检查数据是否为纯文本（UTF-8/ASCII）。
 */
private func isPlainText(data: Array<UInt8>, len: Int64): Bool {
    var i: Int64 = 0
    while (i < len) {
        let b = data[i]
        // 空字节 → 二进制
        if (b == 0) { return false }
        // 控制字符（制表符、换行符、回车符除外）→ 二进制
        if (b < 32 && b != 9 && b != 10 && b != 13) { return false }
        i += 1
    }
    true
}

/**
 * 嗅探字节数（512 字节）。
 */
public func sniffLen(): Int64 { 512 }
