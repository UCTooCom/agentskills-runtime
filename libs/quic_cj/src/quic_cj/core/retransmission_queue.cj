package quic_cj.core

import quic_cj.protocol.EncryptionLevel
import quic_cj.wire.{Frame, CryptoFrame, StreamFrame}

 /// FramesToRetransmit 跟踪待重传的帧，按类型分组。
 internal class FramesToRetransmit {
     public var crypto: Array<CryptoFrame> = []
     public var other: Array<Frame> = []
 }

 /// RetransmissionQueue 按加密级别管理待重传的帧。
 /// 用于在检测到丢包时重新发送握手和 CRYPTO 帧。
 public class RetransmissionQueue {
     private var initial: FramesToRetransmit = FramesToRetransmit()
     private var handshake: FramesToRetransmit = FramesToRetransmit()
     private var appData: FramesToRetransmit = FramesToRetransmit()
     private var initialDropped: Bool = false
     private var handshakeDropped: Bool = false


     /// 添加帧到初始级别重传。
     public func addInitial(f: Frame): Unit {
         if (initialDropped) { return }
         match (f as CryptoFrame) {
             case Some(cf) => initial.crypto = appendCrypto(initial.crypto, cf)
             case None => initial.other = appendFrameToArray(initial.other, f)
         }
     }

     /// 添加帧到握手级别重传。
     public func addHandshake(f: Frame): Unit {
         if (handshakeDropped) { return }
         match (f as CryptoFrame) {
             case Some(cf) => handshake.crypto = appendCrypto(handshake.crypto, cf)
             case None => handshake.other = appendFrameToArray(handshake.other, f)
         }
     }

     /// 添加帧到应用数据级别重传。
     public func addAppData(f: Frame): Unit {
         match (f as CryptoFrame) {
             case Some(cf) => appData.crypto = appendCrypto(appData.crypto, cf)
             case None => appData.other = appendFrameToArray(appData.other, f)
         }
     }

     /// 检查指定加密级别是否有待重传数据。
     public func hasData(encLevel: EncryptionLevel): Bool {
         match (encLevel) {
             case EncryptionLevel.Initial =>
                 !initialDropped && (initial.crypto.size > 0 || initial.other.size > 0)
             case EncryptionLevel.Handshake =>
                 !handshakeDropped && (handshake.crypto.size > 0 || handshake.other.size > 0)
             case EncryptionLevel.OneRTT =>
                 appData.crypto.size > 0 || appData.other.size > 0
             case _ => false
         }
     }

    /// 获取下一个待重传帧（如果适合 maxLen 内）。
    public func getFrame(encLevel: EncryptionLevel): Option<Frame> {
        let r = getRetransmitRef(encLevel)
        if (r.crypto.size > 0) {
            let cf = r.crypto[0]
            r.crypto = r.crypto[1..]
            return Some(cf)
        }
        if (r.other.size > 0) {
            let f = r.other[0]
            r.other = r.other[1..]
            return Some(f)
        }
        None
    }

     /// 丢弃指定加密级别的重传数据。
     public func dropPackets(encLevel: EncryptionLevel): Unit {
         match (encLevel) {
             case EncryptionLevel.Initial => initialDropped = true; initial = FramesToRetransmit()
             case EncryptionLevel.Handshake => handshakeDropped = true; handshake = FramesToRetransmit()
             case _ => ()
         }
     }

     private func getRetransmitRef(encLevel: EncryptionLevel): FramesToRetransmit {
         match (encLevel) {
             case EncryptionLevel.Initial => initial
             case EncryptionLevel.Handshake => handshake
             case _ => appData
         }
     }
 }

 internal func appendCrypto(arr: Array<CryptoFrame>, cf: CryptoFrame): Array<CryptoFrame> {
     let n = arr.size
     var out = Array<CryptoFrame>(n + 1, repeat: CryptoFrame())
     var i: Int64 = 0
     while (i < n) { out[i] = arr[i]; i += 1 }
     out[n] = cf
     out
 }


public func newRetransmissionQueue(): RetransmissionQueue { RetransmissionQueue() }
