package quic_cj.tls

import quic_cj.protocol.{PacketNumber, KeyPhase, KeyPhaseBit, KEY_UPDATE_INTERVAL, INVALID_PACKET_NUMBER, TIMER_GRANULARITY_MS}
import quic_cj.util.RTTStats

/// UpdatableAEADFull 是完整的 1-RTT AEAD，支持密钥更新（Key Update）。
/// 管理当前/下一个接收和发送密钥，以及密钥阶段回退。
public class UpdatableAEADFull {
    private var keyPhase: KeyPhase = 0
    private var largestAcked: PacketNumber = INVALID_PACKET_NUMBER
    private var firstPacketNumber: PacketNumber = INVALID_PACKET_NUMBER
    private var handshakeConfirmed: Bool = false

    // 当前密钥
    private var rcvKey: Array<Byte> = []
    private var rcvIv: Array<Byte> = []
    private var sendKey: Array<Byte> = []
    private var sendIv: Array<Byte> = []

    // 下一个密钥（滚动后）
    private var nextRcvKey: Array<Byte> = []
    private var nextRcvIv: Array<Byte> = []
    private var nextSendKey: Array<Byte> = []
    private var nextSendIv: Array<Byte> = []

    // 前一个 AEAD（回滚支持）
    private var prevRcvKey: Array<Byte> = []
    private var prevRcvIv: Array<Byte> = []
    private var prevExpiryNs: Int64 = 0

    // 包计数
    private var firstRcvdWithCurrentKey: PacketNumber = INVALID_PACKET_NUMBER
    private var firstSentWithCurrentKey: PacketNumber = INVALID_PACKET_NUMBER
    private var highestRcvdPn: PacketNumber = INVALID_PACKET_NUMBER
    private var numRcvdWithCurrentKey: UInt64 = 0u64
    private var numSentWithCurrentKey: UInt64 = 0u64

    private var invalidPacketCount: UInt64 = 0u64
    private var invalidPacketLimit: UInt64 = 128u64 // AES-GCM: 2^23

    private var rttStats: RTTStats = RTTStats()
    private var keyLen: Int64 = 16
    private var ivLen: Int64 = 12

    public init(key: Array<Byte>, iv: Array<Byte>) {
        rcvKey = key
        rcvIv = iv
        sendKey = key
        sendIv = iv
        keyLen = key.size
        ivLen = iv.size
        nextRcvKey = key
        nextRcvIv = iv
        nextSendKey = key
        nextSendIv = iv
    }

    /// 设置接收密钥。
    public func setReadKey(key: Array<Byte>, iv: Array<Byte>): Unit {
        rcvKey = key
        rcvIv = iv
        nextRcvKey = deriveNextKey(key)
        nextRcvIv = deriveNextIv(iv)
    }

    /// 设置发送密钥。
    public func setWriteKey(key: Array<Byte>, iv: Array<Byte>): Unit {
        sendKey = key
        sendIv = iv
        nextSendKey = deriveNextKey(key)
        nextSendIv = deriveNextIv(iv)
    }

    /// 打开（解密）一个包。
    /// 尝试当前密钥阶段，如果失败则尝试前一个密钥（回滚）或下一个密钥（对端已更新）。
    public func open(pn: PacketNumber, keyPhaseBit: Int64, ciphertext: Array<Byte>, aad: Array<Byte>, timeNs: Int64): Option<Array<Byte>> {
        // 检查前一个密钥是否到期
        if (prevRcvKey.size > 0 && prevExpiryNs > 0 && timeNs >= prevExpiryNs) {
            prevRcvKey = []
            prevRcvIv = []
            prevExpiryNs = 0
        }

        // 尝试用前一个密钥解密（对端滚动较慢）
        if (keyPhaseBit != keyPhase && prevRcvKey.size > 0) {
            let aead = UpdatableAEAD(prevRcvKey, prevRcvIv)
            let result = aead.decrypt(pn, ciphertext, aad)
            if (result.size > 0) { return Some(result) }
            return None
        }

        // 尝试用下一个密钥解密（对端已先滚动）
        if (keyPhaseBit != keyPhase) {
            let nextAead = UpdatableAEAD(nextRcvKey, nextRcvIv)
            let result = nextAead.decrypt(pn, ciphertext, aad)
            if (result.size > 0) {
                // 对端已更新密钥，我们也滚动
                rollKeys()
                firstRcvdWithCurrentKey = pn
                startKeyDropTimer(timeNs)
                return Some(result)
            }
            invalidPacketCount += 1
            if (invalidPacketCount >= invalidPacketLimit) { return None }
            return None
        }

        // 当前密钥解密
        let aead = UpdatableAEAD(rcvKey, rcvIv)
        let result = aead.decrypt(pn, ciphertext, aad)
        if (result.size == 0) {
            invalidPacketCount += 1
            if (invalidPacketCount >= invalidPacketLimit) { return None }
            return None
        }

        numRcvdWithCurrentKey += 1
        highestRcvdPn = max(highestRcvdPn, pn)
        if (firstRcvdWithCurrentKey == INVALID_PACKET_NUMBER) {
            if (keyPhase != 0) {
                // 对端确认了我们的密钥更新，启动旧密钥丢弃定时器
                startKeyDropTimer(timeNs)
            }
            firstRcvdWithCurrentKey = pn
        }
        Some(result)
    }

    /// 密封（加密）一个包。
    public func seal(pn: PacketNumber, plaintext: Array<Byte>, aad: Array<Byte>): Array<Byte> {
        if (firstSentWithCurrentKey == INVALID_PACKET_NUMBER) {
            firstSentWithCurrentKey = pn
        }
        if (firstPacketNumber == INVALID_PACKET_NUMBER) {
            firstPacketNumber = pn
        }
        numSentWithCurrentKey += 1
        let aead = UpdatableAEAD(sendKey, sendIv)
        aead.encrypt(pn, plaintext, aad)
    }

    /// 获取当前密钥阶段位。如果需要则滚动密钥。
    public func currentKeyPhase(): KeyPhase {
        if (shouldInitiateKeyUpdate()) {
            rollKeys()
        }
        keyPhase
    }

    /// 设置最大确认包编号。
    public func setLargestAcked(pn: PacketNumber): Bool {
        largestAcked = pn
        true
    }

    /// 设置握手已确认。
    public func setHandshakeConfirmed(): Unit { handshakeConfirmed = true }

    /// 检查是否允许密钥更新。
    public func updateAllowed(): Bool {
        if (!handshakeConfirmed) { return false }
        if (keyPhase == 0) { return true }
        firstSentWithCurrentKey != INVALID_PACKET_NUMBER && largestAcked != INVALID_PACKET_NUMBER && largestAcked >= firstSentWithCurrentKey
    }

    private func shouldInitiateKeyUpdate(): Bool {
        if (!updateAllowed()) { return false }
        if (keyPhase == 0) {
            if (numRcvdWithCurrentKey >= 100 || numSentWithCurrentKey >= 100) { return true }
        }
        numRcvdWithCurrentKey >= UInt64(KEY_UPDATE_INTERVAL) || numSentWithCurrentKey >= UInt64(KEY_UPDATE_INTERVAL)
    }

    private func rollKeys(): Unit {
        // 保存当前密钥为前一个
        if (prevRcvKey.size == 0) {
            prevRcvKey = rcvKey
            prevRcvIv = rcvIv
        }

        keyPhase = nextKeyPhase(keyPhase)
        firstRcvdWithCurrentKey = INVALID_PACKET_NUMBER
        firstSentWithCurrentKey = INVALID_PACKET_NUMBER
        numRcvdWithCurrentKey = 0u64
        numSentWithCurrentKey = 0u64

        // 提升密钥
        rcvKey = nextRcvKey
        rcvIv = nextRcvIv
        sendKey = nextSendKey
        sendIv = nextSendIv

        // 派生下一组
        nextRcvKey = deriveNextKey(rcvKey)
        nextRcvIv = deriveNextIv(rcvIv)
        nextSendKey = deriveNextKey(sendKey)
        nextSendIv = deriveNextIv(sendIv)
    }

    private func startKeyDropTimer(nowNs: Int64): Unit {
        var pto = rttStats.pto(true)
        if (pto < TIMER_GRANULARITY_MS * 3) { pto = TIMER_GRANULARITY_MS * 3 }
        prevExpiryNs = nowNs + pto * 3
    }

    /// 返回旁路预算（字节）。
    public func overhead(): Int64 { 16 }
}

/// 从当前密钥派生下一组密钥（RFC 9001 §6）。
/// 使用 HKDF-Expand-Label("quic ku", "", keyLen) 进行密钥更新。
private func deriveNextKey(key: Array<Byte>): Array<Byte> {
    quicHkdfExpandLabel(key, "quic ku", [], key.size)
}

private func deriveNextIv(iv: Array<Byte>): Array<Byte> {
    quicHkdfExpandLabel(iv, "quic ku", [], iv.size)
}

private func nextKeyPhase(kp: Int64): KeyPhase {
    match (kp) {
        case 0 => 1
        case _ => 0
    }
}

private func max(a: PacketNumber, b: PacketNumber): PacketNumber {
    if (a > b) { a } else { b }
}

public func newUpdatableAEADFull(key: Array<Byte>, iv: Array<Byte>): UpdatableAEADFull {
    UpdatableAEADFull(key, iv)
}
