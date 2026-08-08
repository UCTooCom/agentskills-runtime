package quic_cj.protocol

import std.random.Random


public func generateConnectionId(len: Int64): Array<Byte> {
    let rand = Random()
    let out = Array<Byte>(len, repeat: 0)
    var i: Int64 = 0
    while (i < len) {
        out[i] = UInt8(rand.nextInt64() & 0xFF)
        i += 1
    }
    out
}

public func isValidConnectionIdLen(len: Int64): Bool {
    len >= 0 && len <= MAX_CONN_ID_LEN
}
