package quic_cj.tls

import quic_cj.wire.{readVarint, appendVarint, appendBytes}
import quic_cj.wire.{TransportParameters, marshalTransportParameters, parseTransportParameters}
 import jinguissl.live.{ContractTlsSessionCache, ContractTlsSessionIdentity, ContractTlsSessionTicket, ContractTlsVersion}
 import jinguissl.live.{contractTlsCreateSessionTicket, contractTlsEncodeSessionTicket, contractTlsDecodeSessionTicket, contractTlsIsSessionTicketExpired}
 

public let SESSION_TICKET_REVISION: Int64 = 5

 /// SessionTicketStore — 基于 jinguissl ContractTlsSessionCache 的会话 ticket 存储。
 /// 提供 store/load/encode/decode 方法以替代手动 TokenStore 管理。
 public class SessionTicketStore {
     private var cache: ContractTlsSessionCache
 
     public init(maxEntries!: Int64 = 1024, ttlSeconds!: Int64 = 7200) {
         cache = ContractTlsSessionCache(maxEntries: maxEntries, defaultTtlSeconds: ttlSeconds)
     }
 
     /// 将 session ticket 存储到缓存。
     public func store(
         identity: ContractTlsSessionIdentity,
         secret: Array<Byte>,
         nonce: Array<Byte>,
         ttlSeconds!: Int64 = 7200
     ): ?ContractTlsSessionTicket {
         try {
             let now = 1
             let ticket = cache.storeFromSecret(identity, secret, nonce: nonce, nowUnixSeconds: now, ttlSeconds: ttlSeconds)
             Some(ticket)
         } catch (_: Exception) {
             None
         }
     }
 
     /// 从缓存加载 session ticket。
     public func load(
         identity: ContractTlsSessionIdentity,
         nowUnixSeconds!: Int64 = 0
     ): ?ContractTlsSessionTicket {
         let now = if (nowUnixSeconds > 0) { nowUnixSeconds } else { 1 }
         cache.load(identity, nowUnixSeconds: now)
     }
 
     /// 清除过期 ticket。
     public func purgeExpired(nowUnixSeconds!: Int64 = 0): Int64 {
         let now = if (nowUnixSeconds > 0) { nowUnixSeconds } else { 1 }
         cache.purgeExpired(nowUnixSeconds: now)
     }
 
     /// 返回缓存统计信息。
     public func stats(): (Int64, Int64, Int64, Int64, Int64) {
         let s = cache.stats()
         (s.size, s.hits, s.misses, s.evictions, s.expiredRemovals)
     }
 
     /// 清除所有条目。
     public func clear(): Unit { cache.clear() }
 }
 
/// 保存会话恢复的传输参数。
public class SessionTicket {
    public var parameters: TransportParameters = TransportParameters()

    /// 序列化会话票据。
    public func marshal(): Array<Byte> {
        var buf: Array<Byte> = []
        buf = appendVarint(buf, SESSION_TICKET_REVISION)
        let tpData = marshalTransportParameters(parameters)
        buf = appendBytes(buf, tpData)
        buf
    }

    /// 反序列化会话票据。
    public func unmarshal(data: Array<Byte>): Bool {
        let (rev, n1) = readVarint(data)
        if (n1 == 0) { return false }
        if (rev != SESSION_TICKET_REVISION) { return false }
        let rest = data[n1..]
        if (let Some(tp) <- parseTransportParameters(rest)) {
            parameters = tp
        } else { return false }
        true
    }
}

/// 将会话状态额外数据添加 quic-go 前缀。
public func addSessionStateExtraPrefix(data: Array<Byte>): Array<Byte> {
    let 前缀: Array<Byte> = [0x71u8, 0x75u8, 0x69u8, 0x63u8, 0x2du8, 0x67u8, 0x6fu8, 0x31u8]
    let 前缀Size = 前缀.size
    let total = 前缀Size + data.size
    var out = Array<Byte>(total, repeat: 0)
    var i: Int64 = 0
    while (i < 前缀Size) { out[i] = 前缀[i]; i += 1 }
    i = 0
    while (i < data.size) { out[前缀Size + i] = data[i]; i += 1 }
    out
}

/// 查找并返回会话状态额外数据（减去前缀）。
public func findSessionStateExtraData(extras: Array<Array<Byte>>): Array<Byte> {
    let 前缀: Array<Byte> = [0x71u8, 0x75u8, 0x69u8, 0x63u8, 0x2du8, 0x67u8, 0x6fu8, 0x31u8]
    let 前缀Size = 前缀.size
    var i: Int64 = 0
    while (i < extras.size) {
        let extra = extras[i]
        if (extra.size >= 前缀Size) {
            var isMatch = true
            var j: Int64 = 0
            while (j < 前缀Size) {
                if (extra[j] != 前缀[j]) { isMatch = false; break }
                j += 1
            }
            if (isMatch) {
                return extra[前缀Size..]
            }
        }
        i += 1
    }
    []
}
