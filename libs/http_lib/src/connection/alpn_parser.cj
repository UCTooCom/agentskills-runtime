package http_lib.connection
/**
 * ALPN（应用层协议协商）TLS 扩展帧解析器（RFC 7301）。
 * 在 TLS 握手中协商 HTTP 协议版本（h2 vs http/1.1）。
 */

import std.collection.ArrayList

/**
 * ALPN 扩展解析器（TLS ClientHello）。
 * TLS ALPN（Application-Layer Protocol Negotiation）协议列表解析。
 * 从 ClientHello 的 TLS 扩展中提取客户端支持的协议列表。
 */

/**
 * 从 TLS ClientHello 消息中提取 ALPN 协议列表.
 * 若无 ALPN 扩展则返回空数组。
 */
public func extractAlpnFromClientHello(clientHello: Array<Byte>): Array<String> {
    // 输入是 ClientHello 握手正文（TLS 记录头已被
    // receiveRawRecord() 剥离）。结构如下：
    //   握手头：type(1) + length(3) = 4 字节
    //   ClientHello 正文从偏移 4 开始

    if (clientHello.size < 39) { return [] }  // ClientHello 最小长度

    var offset: Int64 = 4  // 跳过握手头部
    // 跳过：version(2) + random(32) = 34 字节
    offset += 2 + 32  // = 43
    if (offset >= clientHello.size) { return [] }

    // 跳过会话 ID
    let sessionIdLen: Int64 = Int64(clientHello[offset])
    offset += 1 + sessionIdLen
    if (offset + 2 >= clientHello.size) { return [] }

    // 跳过密码套件
    let cipherSuitesLen: Int64 = (Int64(clientHello[offset]) << 8) | Int64(clientHello[offset + 1])
    offset += 2 + cipherSuitesLen
    if (offset + 2 >= clientHello.size) { return [] }

    // 跳过压缩方法
    let compressionLen: Int64 = Int64(clientHello[offset])
    offset += 1 + compressionLen
    if (offset + 2 >= clientHello.size) { return [] }

    // 扩展段
    let extensionsLen: Int64 = (Int64(clientHello[offset]) << 8) | Int64(clientHello[offset + 1])
    offset += 2
    let extensionsEnd = offset + extensionsLen
    if (extensionsEnd > clientHello.size) { return [] }

    // 扫描扩展以查找 ALPN（类型 0x0010）
    while (offset + 4 <= extensionsEnd) {
        let extType = (Int64(clientHello[offset]) << 8) | Int64(clientHello[offset + 1])
        let extLen = (Int64(clientHello[offset + 2]) << 8) | Int64(clientHello[offset + 3])
        offset += 4

        if (extType == 16) {  // ALPN 扩展
            return parseAlpnExtension(clientHello, offset, extLen)
        }
        offset += extLen
    }
    []
}

/**
 * 将 ALPN 扩展数据解析为协议名称列表。
 */
private func parseAlpnExtension(data: Array<Byte>, offset: Int64, length: Int64): Array<String> {
    if (length < 2) { return [] }
    let listLen: Int64 = (Int64(data[offset]) << 8) | Int64(data[offset + 1])
    if (listLen > length - 2) { return [] }

    var pos = offset + 2
    let end = pos + listLen

    let protocols = ArrayList<String>()
    while (pos < end) {
        let nameLen: Int64 = Int64(data[pos])
        pos += 1
        if (pos + nameLen > end) { break }

        let nameBytes = Array<UInt8>(nameLen, repeat: 0)
        var i: Int64 = 0
        while (i < nameLen) { nameBytes[i] = data[pos + i]; i += 1 }

        let name = String.fromUtf8(nameBytes)
        if (name.size > 0) {
            protocols.add(name)
        }
        pos += nameLen
    }
    protocols.toArray()
}


/**
 * 从 TLS ServerHello 消息中提取协商的 ALPN 协议。
 * ServerHello 在其扩展（类型 0x0010）中包含服务器选择的 ALPN 协议。
 * 若无 ALPN 扩展或 server hello 太短无法解析则返回空字符串。
 * 
 *
 * ServerHello 结构（TLS 记录内）：
 *   握手类型：1 字节（0x02）
 *   握手长度：3 字节
 *   版本：2 字节
 *   Random：32 字节
 * 会话 ID 长度：1 字节
 * 会话 ID：可变
 * 密码套件：2 字节
 * 压缩：1 字节
 * 扩展长度：2 字节
 * 扩展：可变（每个：类型 2 + 长度 2 + 数据）
 */
public func extractAlpnFromServerHello(serverHello: Array<Byte>): String {
    if (serverHello.size < 39) { return "" }

    // 跳过：握手类型(1) + 长度(3) + 版本(2) + 随机数(32) = 38
    var offset: Int64 = 38
    if (offset >= serverHello.size) { return "" }

    // 跳过会话 ID
    let sessionIdLen: Int64 = Int64(serverHello[offset])
    offset += 1 + sessionIdLen
    if (offset + 3 > serverHello.size) { return "" }

    // 跳过密码套件（2 字节）+ 压缩（1 字节）
    offset += 3
    if (offset + 2 > serverHello.size) { return "" }

    // 扩展段
    let extensionsLen: Int64 = (Int64(serverHello[offset]) << 8) | Int64(serverHello[offset + 1])
    offset += 2
    let extensionsEnd = offset + extensionsLen
    if (extensionsEnd > serverHello.size) { return "" }

    // 扫描扩展以查找 ALPN（类型 0x0010）
    while (offset + 4 <= extensionsEnd) {
        let extType = (Int64(serverHello[offset]) << 8) | Int64(serverHello[offset + 1])
        let extLen = (Int64(serverHello[offset + 2]) << 8) | Int64(serverHello[offset + 3])
        offset += 4

        if (extType == 16) {  // ALPN 扩展
            return parseSingleAlpnProtocol(serverHello, offset, extLen)
        }
        offset += extLen
    }
    ""
}

/**
 * 解析包含单个协议名称的 ALPN 扩展数据。
 * 返回协议名称字符串，失败时返回空字符串。
 */
private func parseSingleAlpnProtocol(data: Array<Byte>, offset: Int64, length: Int64): String {
    if (length < 2) { return "" }
    let listLen: Int64 = (Int64(data[offset]) << 8) | Int64(data[offset + 1])
    if (listLen > length - 2 || listLen < 1) { return "" }

    let nameLen: Int64 = Int64(data[offset + 2])
    if (nameLen < 1 || nameLen > listLen - 1) { return "" }

    let nameBytes = Array<UInt8>(nameLen, repeat: 0)
    var i: Int64 = 0
    while (i < nameLen) {
        nameBytes[i] = data[offset + 3 + i]
        i += 1
    }
    String.fromUtf8(nameBytes)
}

/**
 * 解析 ClientHello 并提取 ALPN 协议以进行协商。
 */
public func parseClientHelloAlpn(clientHelloBytes: Array<Byte>): Array<String> {
    extractAlpnFromClientHello(clientHelloBytes)
}
