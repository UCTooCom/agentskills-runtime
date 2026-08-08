 package quic_cj.core

 import quic_cj.protocol.EncryptionLevel
 import quic_cj.wire.CryptoFrame

 /// CryptoStreamManager 管理三个加密级别的 CRYPTO 流。
 /// 将收到的 CRYPTO 帧路由到对应的流，并从对应流获取待发送数据。
 public class CryptoStreamManager {
     private var initialStream: InitialCryptoStream = InitialCryptoStream()
     private var handshakeStream: CryptoStream = CryptoStream()
     private var oneRTTStream: CryptoStream = CryptoStream()

     public init(initial: InitialCryptoStream, handshake: CryptoStream, oneRTT: CryptoStream) {
         initialStream = initial
         handshakeStream = handshake
         oneRTTStream = oneRTT
     }

     /// 根据加密级别处理收到的 CRYPTO 帧。
     public func handleCryptoFrame(frame: CryptoFrame, encLevel: EncryptionLevel): Bool {
         match (encLevel) {
             case EncryptionLevel.Initial => initialStream.handleCryptoFrame(frame)
             case EncryptionLevel.Handshake => handshakeStream.handleCryptoFrame(frame)
             case EncryptionLevel.OneRTT => oneRTTStream.handleCryptoFrame(frame)
             case _ => return false
         }
     }

     /// 获取指定加密级别的已排序 CRYPTO 数据。
     public func getCryptoData(encLevel: EncryptionLevel): Array<Byte> {
         match (encLevel) {
             case EncryptionLevel.Initial => initialStream.getCryptoData()
             case EncryptionLevel.Handshake => handshakeStream.getCryptoData()
             case EncryptionLevel.OneRTT => oneRTTStream.getCryptoData()
             case _ => return []
         }
     }

    /// 弹出下一个待发送的握手后 CRYPTO 帧。
    public func getPostHandshakeData(maxSize: Int64): Option<CryptoFrame> {
        if (!oneRTTStream.hasData()) { return None }
        oneRTTStream.popCryptoFrame(maxSize)
    }

     /// 丢弃指定加密级别的 CRYPTO 流。
     public func drop(encLevel: EncryptionLevel): Bool {
         match (encLevel) {
             case EncryptionLevel.Initial => initialStream.finish()
             case EncryptionLevel.Handshake => handshakeStream.finish()
             case _ => return false
         }
     }

     public func getInitialStream(): InitialCryptoStream { initialStream }
     public func getHandshakeStream(): CryptoStream { handshakeStream }
     public func getOneRTTStream(): CryptoStream { oneRTTStream }
 }

 /// 创建新的 CryptoStreamManager。
 public func newCryptoStreamManager(): CryptoStreamManager {
     CryptoStreamManager(newInitialCryptoStream(), newCryptoStream(), newCryptoStream())
 }
