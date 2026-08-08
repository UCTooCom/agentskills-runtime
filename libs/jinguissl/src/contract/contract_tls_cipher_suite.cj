 package jinguissl.contract

import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}
import jinguissl_core.crypto.tls.{
    TlsAeadAlgorithm,
    tls13CipherSuiteAeadAlgorithm,
    tls13CipherSuiteKeyLen,
    tls13CipherSuiteHashAlgorithm,
    tls13CipherSuiteHashLen,
    tls13CipherSuiteIvLen
}

 /// 合约层面的 TlsAeadAlgorithm 枚举映射。
 public enum ContractTlsAeadAlgorithm <: ToString {
     | AesGcm
     | ChaCha20Poly1305

     public func toString(): String {
         match (this) {
             case AesGcm => "AES-GCM"
             case ChaCha20Poly1305 => "ChaCha20-Poly1305"
         }
     }
 }

 /// 将核心 TlsAeadAlgorithm 转换为合约枚举。
 private func contractFromTlsAeadAlgorithm(alg: TlsAeadAlgorithm): ContractTlsAeadAlgorithm {
     match (alg) {
         case TlsAeadAlgorithm.AES_GCM => ContractTlsAeadAlgorithm.AesGcm
         case TlsAeadAlgorithm.CHACHA20_POLY1305 => ContractTlsAeadAlgorithm.ChaCha20Poly1305
     }
 }

 /// 返回密码套件对应的 AEAD 算法。
 /// suite: TLS 1.3 密码套件 ID（如 0x1301）
 public func contractTls13CipherSuiteAeadAlgorithm(suite: Int64): ContractTlsAeadAlgorithm {
     try {
         contractFromTlsAeadAlgorithm(tls13CipherSuiteAeadAlgorithm(suite))
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 cipher suite AEAD algorithm lookup failed: ${e.message}"
         )
     }
 }

 /// 返回密码套件的密钥长度。
 /// suite: TLS 1.3 密码套件 ID
 public func contractTls13CipherSuiteKeyLen(suite: Int64): Int64 {
     try {
         tls13CipherSuiteKeyLen(suite)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 cipher suite key length lookup failed: ${e.message}"
         )
     }
 }

 /// 返回密码套件的哈希算法。
 /// suite: TLS 1.3 密码套件 ID
 public func contractTls13CipherSuiteHashAlgorithm(suite: Int64): HashAlgorithm {
     try {
         tls13CipherSuiteHashAlgorithm(suite)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 cipher suite hash algorithm lookup failed: ${e.message}"
         )
     }
 }

 /// 返回密码套件的哈希输出长度。
 /// suite: TLS 1.3 密码套件 ID
 public func contractTls13CipherSuiteHashLen(suite: Int64): Int64 {
     try {
         tls13CipherSuiteHashLen(suite)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 cipher suite hash length lookup failed: ${e.message}"
         )
     }
 }

 /// 返回密码套件的 IV 长度。
 /// suite: TLS 1.3 密码套件 ID
 public func contractTls13CipherSuiteIvLen(suite: Int64): Int64 {
     try {
         tls13CipherSuiteIvLen(suite)
     } catch (e: CryptoException) {
         throw ContractException(
             mapCryptoErrorForOperation(e, "tls"),
             "TLS 1.3 cipher suite IV length lookup failed: ${e.message}"
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
