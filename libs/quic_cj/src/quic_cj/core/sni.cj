package quic_cj.core

/// SNI 和 ECH 扩展类型。
private let EXT_TYPE_SNI: UInt16 = 0u16
private let EXT_TYPE_ECH: UInt16 = 0xfe0du16

/// FindSniAndEch 解析 ClientHello，定位 SNI 和 ECH 扩展的位置。
/// 返回 (sniPos, sniLen, echPos, ok)。
/// 如果未找到 SNI，sniPos 为 -1。
/// 如果未找到 ECH，echPos 为 -1。
public func findSniAndEch(data: Array<Byte>): Option<(Int64, Int64, Int64)> {
    if (data.size < 4) { return None }
    if (data[0] != 1u8) { return None } // 不是 ClientHello

    let handshakeLen = (Int64(data[1]) << 16) | (Int64(data[2]) << 8) | Int64(data[3])
    if (Int64(data.size) != 4 + handshakeLen) { return None }

    var parsePos: Int64 = 4

    // 跳过协议版本（2 字节）
    if (parsePos + 2 > Int64(data.size)) { return None }
    parsePos += 2

    // 跳过随机数（32 字节）
    if (parsePos + 32 > Int64(data.size)) { return None }
    parsePos += 32

    // 会话 ID
    if (parsePos + 1 > Int64(data.size)) { return None }
    let sessionIdLen = Int64(data[parsePos])
    parsePos += 1
    if (parsePos + sessionIdLen > Int64(data.size)) { return None }
    parsePos += sessionIdLen

    // 密码套件
    if (parsePos + 2 > Int64(data.size)) { return None }
    let cipherSuitesLen = readUint16BE(data, parsePos)
    parsePos += 2
    if (parsePos + Int64(cipherSuitesLen) > Int64(data.size)) { return None }
    parsePos += Int64(cipherSuitesLen)

    // 压缩方法
    if (parsePos + 1 > Int64(data.size)) { return None }
    let compLen = Int64(data[parsePos])
    parsePos += 1
    if (parsePos + compLen > Int64(data.size)) { return None }
    parsePos += compLen

    // 扩展
    if (parsePos + 2 > Int64(data.size)) { return None }
    let extLen = readUint16BE(data, parsePos)
    parsePos += 2
    if (parsePos + Int64(extLen) > Int64(data.size)) { return None }
    let extStart = parsePos

    var sniPos: Int64 = -1
    var sniLen: Int64 = 0
    var echPos: Int64 = -1
    var extOffset: Int64 = 0

    while (extOffset + 4 <= Int64(extLen)) {
        let extType = readUint16BE(data, extStart + extOffset)
        let extDataLen = readUint16BE(data, extStart + extOffset + 2)

        if (extOffset + 4 + Int64(extDataLen) > Int64(extLen)) { break }

        if (extType == EXT_TYPE_SNI && sniPos == -1) {
            let sniDataStart = extStart + extOffset + 4
            let sniDataLen = Int64(extDataLen)
            if (sniDataLen >= 2) {
                let nameListLen = readUint16BE(data, sniDataStart)
                if (sniDataLen == 2 + Int64(nameListLen)) {
                    var listPos: Int64 = 2
                    while (listPos + 3 <= Int64(nameListLen) + 2) {
                        let nameType = data[sniDataStart + listPos]
                        let nameLen = readUint16BE(data, sniDataStart + listPos + 1)
                        if (listPos + 3 + Int64(nameLen) > Int64(sniDataLen)) { break }
                        if (nameType == 0u8) { // host_name
                            sniPos = sniDataStart + listPos + 3
                            sniLen = Int64(nameLen)
                            break
                        }
                        listPos += 3 + Int64(nameLen)
                    }
                }
            }
        }

        if (extType == EXT_TYPE_ECH && echPos == -1) {
            echPos = extStart + extOffset
        }

        if (sniPos != -1 && echPos != -1) { break }
        extOffset += 4 + Int64(extDataLen)
    }

    Some((sniPos, sniLen, echPos))
}

private func readUint16BE(data: Array<Byte>, offset: Int64): UInt16 {
    if (offset + 1 >= data.size) { return 0u16 }
    (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
}
