 package jinguissl.contract

 import jinguissl_core.crypto.compliance.FipsProfile
 import jinguissl_core.crypto.ecc.{EcPrivateKey, EcPublicKey}
 import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}
 import jinguissl_core.crypto.rsa.RsaPrivateKey
 import jinguissl_core.crypto.tls.{
     Tls13AuthFlight,
     Tls13ClientHandshakeResult,
     Tls13HandshakeSecrets,
     Tls13ServerHandshakeContext,
     Tls13ServerHandshakeFlight,
     tls13BuildCertificateHandshakeFromDerChain,
     tls13BuildClientAuthFlightEcdsa,
     tls13BuildClientAuthFlightRsaPss,
     tls13BuildEncryptedExtensions,
     tls13BuildServerAuthFlightEcdsa,
     tls13BuildServerAuthFlightRsaPss,
     tls13BuildServerHandshakeContextX25519,
     tls13BuildServerHelloForX25519,
     tls13DeriveSecretsFromX25519ForCipherSuite,
     tls13ProcessServerHandshakeFlightX25519,
     tls13VerifyClientAuthFlight,
     tls13VerifyServerAuthFlight
 }
 import jinguissl_core.crypto.x509.{X509VerificationPolicy, X509VerificationResult}

 /// 使用服务端 X25519 密钥构建 ServerHello 消息。
 /// encodedClientHello: 完整的 ClientHello 消息字节
 /// serverKeyShare: 服务端 X25519 公钥（32 字节）
 /// 返回: 编码的 ServerHello 消息字节
 public func contractTls13BuildServerHelloForX25519(
     encodedClientHello: Array<Byte>,
     serverKeyShare: Array<Byte>
 ): Array<Byte> {
     try {
         tls13BuildServerHelloForX25519(encodedClientHello, serverKeyShare)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 server hello building failed: ${e.message}"
         )
     }
 }

 /// 构建完整的服务端握手上下文（X25519 ECDHE）。
 /// 返回: Tls13ServerHandshakeContext 包含 ServerHello + 后续飞行 + 握手密钥
 public func contractTls13BuildServerHandshakeContextX25519(
     encodedClientHello: Array<Byte>,
     serverKeyExchangePrivate: Array<Byte>,
     serverKeyShare: Array<Byte>,
     certChainDer: Array<Array<Byte>>,
     certificatePrivateKeyEcdsa!: ?EcPrivateKey = None,
     certificatePrivateKeyRsa!: ?RsaPrivateKey = None,
     alpnPreference!: Array<String> = [],
     acknowledgeServerName!: Bool = true
 ): Tls13ServerHandshakeContext {
     try {
         tls13BuildServerHandshakeContextX25519(
             encodedClientHello,
             serverKeyExchangePrivate,
             serverKeyShare,
             certChainDer,
             certificatePrivateKeyEcdsa: certificatePrivateKeyEcdsa,
             certificatePrivateKeyRsa: certificatePrivateKeyRsa,
             alpnPreference: alpnPreference,
             acknowledgeServerName: acknowledgeServerName
         )
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 server handshake context building failed: ${e.message}"
         )
     }
 }

 /// 处理完整的服务端握手飞行（客户端视角）。
 /// 返回: 握手结果，包含协商的密钥和证书验证结果
 public func contractTls13ProcessServerHandshakeFlightX25519(
     encodedClientHello: Array<Byte>,
     clientKeyExchangePrivate: Array<Byte>,
     flight: Tls13ServerHandshakeFlight,
     policy: X509VerificationPolicy,
     profile!: ?FipsProfile = None
 ): Tls13ClientHandshakeResult {
     try {
         tls13ProcessServerHandshakeFlightX25519(
             encodedClientHello,
             clientKeyExchangePrivate,
             flight,
             policy,
             profile: profile
         )
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 server handshake flight processing failed: ${e.message}"
         )
     }
 }

 /// 构建 EncryptedExtensions 消息。
 /// selectedAlpn: 选定的 ALPN 协议（如 "h2"）
 /// acknowledgeServerName: 是否确认服务端名称
 /// 返回: 编码的 EncryptedExtensions 消息字节
 public func contractTls13BuildEncryptedExtensions(
     selectedAlpn!: String = "",
     acknowledgeServerName!: Bool = false
 ): Array<Byte> {
     try {
         tls13BuildEncryptedExtensions(
             selectedAlpn: selectedAlpn,
             acknowledgeServerName: acknowledgeServerName
         )
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building encrypted extensions failed: ${e.message}"
         )
     }
 }

 /// 从 DER 证书链构建 Certificate 握手消息。
 /// certChainDer: 证书的 DER 字节数组
 /// requestContext: CertificateRequest 上下文（可选）
 /// 返回: 编码的 Certificate 消息字节
 public func contractTls13BuildCertificateHandshakeFromDerChain(
     certChainDer: Array<Array<Byte>>,
     requestContext!: Array<Byte> = []
 ): Array<Byte> {
     try {
         tls13BuildCertificateHandshakeFromDerChain(certChainDer, requestContext: requestContext)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building certificate handshake from DER chain failed: ${e.message}"
         )
     }
 }

 /// 使用 ECDSA 构建服务端完整认证飞行（Certificate + CertificateVerify + Finished）。
 /// certChainDer: 服务端证书链 DER 字节数组
 /// privateKey: ECDSA 私钥
 /// transcriptHash: 到证书的交互记录哈希
 /// serverHsTrafficSecret: 服务端握手流量密钥（用于 Finished 计算）
 /// requestContext: CertificateRequest 上下文（可选）
 /// 返回: 服务端认证飞行
 public func contractTls13BuildServerAuthFlightEcdsa(
     certChainDer: Array<Array<Byte>>,
     privateKey: EcPrivateKey,
     transcriptHash: Array<Byte>,
     serverHsTrafficSecret: Array<Byte>,
     requestContext!: Array<Byte> = []
 ): Tls13AuthFlight {
     try {
         tls13BuildServerAuthFlightEcdsa(
             certChainDer,
             privateKey,
             transcriptHash,
             serverHsTrafficSecret,
             requestContext: requestContext
         )
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building ECDSA server auth flight failed: ${e.message}"
         )
     }
 }

 /// 使用 RSA-PSS 构建服务端完整认证飞行（Certificate + CertificateVerify + Finished）。
 public func contractTls13BuildServerAuthFlightRsaPss(
     certChainDer: Array<Array<Byte>>,
     privateKey: RsaPrivateKey,
     transcriptHash: Array<Byte>,
     serverHsTrafficSecret: Array<Byte>,
     requestContext!: Array<Byte> = []
 ): Tls13AuthFlight {
     try {
         tls13BuildServerAuthFlightRsaPss(
             certChainDer,
             privateKey,
             transcriptHash,
             serverHsTrafficSecret,
             requestContext: requestContext
         )
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building RSA-PSS server auth flight failed: ${e.message}"
         )
     }
 }

 /// 验证服务端 Certificate + CertificateVerify 飞行。
 public func contractTls13VerifyServerAuthFlight(
     flight: Tls13AuthFlight,
     policy: X509VerificationPolicy,
     transcriptHash: Array<Byte>,
     serverHsTrafficSecret: Array<Byte>
 ): X509VerificationResult {
     try {
         tls13VerifyServerAuthFlight(flight, policy, transcriptHash, serverHsTrafficSecret)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 server auth flight verification failed: ${e.message}"
         )
     }
 }

 /// 验证客户端 Certificate + CertificateVerify 飞行。
 public func contractTls13VerifyClientAuthFlight(
     flight: Tls13AuthFlight,
     policy: X509VerificationPolicy,
     transcriptHash: Array<Byte>,
     clientHsTrafficSecret: Array<Byte>
 ): X509VerificationResult {
     try {
         tls13VerifyClientAuthFlight(flight, policy, transcriptHash, clientHsTrafficSecret)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 client auth flight verification failed: ${e.message}"
         )
     }
 }

 /// 使用 ECDSA 构建客户端认证飞行（Certificate + CertificateVerify + Finished）。
 public func contractTls13BuildClientAuthFlightEcdsa(
     certChainDer: Array<Array<Byte>>,
     privateKey: EcPrivateKey,
     transcriptHash: Array<Byte>,
     clientHsTrafficSecret: Array<Byte>,
     requestContext!: Array<Byte> = []
 ): Tls13AuthFlight {
     try {
         tls13BuildClientAuthFlightEcdsa(
             certChainDer,
             privateKey,
             transcriptHash,
             clientHsTrafficSecret,
             requestContext: requestContext
         )
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building ECDSA client auth flight failed: ${e.message}"
         )
     }
 }

 /// 使用 RSA-PSS 构建客户端认证飞行（Certificate + CertificateVerify + Finished）。
 public func contractTls13BuildClientAuthFlightRsaPss(
     certChainDer: Array<Array<Byte>>,
     privateKey: RsaPrivateKey,
     transcriptHash: Array<Byte>,
     clientHsTrafficSecret: Array<Byte>,
     requestContext!: Array<Byte> = []
 ): Tls13AuthFlight {
     try {
         tls13BuildClientAuthFlightRsaPss(
             certChainDer,
             privateKey,
             transcriptHash,
             clientHsTrafficSecret,
             requestContext: requestContext
         )
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 building RSA-PSS client auth flight failed: ${e.message}"
         )
     }
 }

/// 使用 X25519 派生 TLS 1.3 握手密钥。
 /// privateKey: 本地 X25519 私钥
 /// peerPublicKey: 对端 X25519 公钥
 /// transcriptHash: 当前 Transcript 哈希
/// cipherSuite: 选定的密码套件 ID
 /// appTranscriptHash: 应用层 Transcript 哈希覆盖（可选）
/// 返回: 握手密钥结构体
public func contractTls13DeriveSecretsFromX25519(
     privateKey: Array<Byte>,
     peerPublicKey: Array<Byte>,
     transcriptHash: Array<Byte>,
     cipherSuite: Int64,
     appTranscriptHash!: Array<Byte> = []
): Tls13HandshakeSecrets {
    try {
         tls13DeriveSecretsFromX25519ForCipherSuite(
             privateKey, peerPublicKey, transcriptHash, cipherSuite,
             appTranscriptHash: appTranscriptHash
         )
    } catch (e: CryptoException) {
        throw ContractException(
            mapCryptoErrorForOperation(e, "tls"),
            "TLS 1.3 deriving secrets from X25519 failed: ${e.message}"
        )
    }
}

 private func mapCryptoErrorForOperation(e: CryptoException, operation: String): ContractErrorCode {
     match (e.code) {
         case CryptoErrorCode.InvalidArgument => ContractErrorCode.BadInput
         case CryptoErrorCode.OutOfBounds => ContractErrorCode.BadInput
         case CryptoErrorCode.DivideByZero => ContractErrorCode.BadInput
         case CryptoErrorCode.NoModInverse => ContractErrorCode.BadInput
         case CryptoErrorCode.ParseError => ContractErrorCode.BadInput
         case CryptoErrorCode.ComplianceRejected => ContractErrorCode.ComplianceRejected
         case CryptoErrorCode.Unsupported => ContractErrorCode.Unsupported
         case CryptoErrorCode.InternalError => ContractErrorCode.InternalError
         case _ => ContractErrorCode.InternalError
     }
 }
