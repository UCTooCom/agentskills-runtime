package jinguissl.contract

import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}
import jinguissl_core.crypto.x25519.{
    X25519_KEY_LEN as Core_X25519_KEY_LEN,
    X25519_SHARED_SECRET_LEN as Core_X25519_SHARED_SECRET_LEN,
    x25519ClampPrivateKey,
    x25519DeriveSharedSecret,
    x25519GeneratePrivateKey,
    x25519PublicFromPrivate
}

public let CONTRACT_X25519_KEY_LEN: Int64 = Core_X25519_KEY_LEN
public let CONTRACT_X25519_SHARED_SECRET_LEN: Int64 = Core_X25519_SHARED_SECRET_LEN
public let CONTRACT_X25519_ALGORITHM: String = "X25519"

public class ContractX25519KeyPair {
    public let privateKey: Array<Byte>
    public let publicKey: Array<Byte>

    public init(privateKey: Array<Byte>, publicKey: Array<Byte>) {
        contractRequireX25519KeyLength(privateKey, "X25519 private key")
        contractRequireX25519KeyLength(publicKey, "X25519 public key")
        this.privateKey = privateKey.clone()
        this.publicKey = publicKey.clone()
    }
}

public class ContractX25519KeyAgreementRequest {
    public let privateKey: Array<Byte>
    public let peerPublicKey: Array<Byte>

    public init(privateKey: Array<Byte>, peerPublicKey: Array<Byte>) {
        contractRequireX25519KeyLength(privateKey, "X25519 private key")
        contractRequireX25519KeyLength(peerPublicKey, "X25519 peer public key")
        this.privateKey = privateKey.clone()
        this.peerPublicKey = peerPublicKey.clone()
    }
}

public class ContractX25519KeyAgreementResult {
    public let algorithm: String
    public let publicKey: Array<Byte>
    public let sharedSecret: Array<Byte>

    public init(publicKey: Array<Byte>, sharedSecret: Array<Byte>) {
        contractRequireX25519KeyLength(publicKey, "X25519 public key")
        contractRequireX25519KeyLength(sharedSecret, "X25519 shared secret")
        this.algorithm = CONTRACT_X25519_ALGORITHM
        this.publicKey = publicKey.clone()
        this.sharedSecret = sharedSecret.clone()
    }
}

public class ContractX25519KeyAgreementOutcome {
    public let ok: Bool
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractX25519KeyAgreementResult

    public init(
        ok: Bool,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractX25519KeyAgreementResult = None
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "X25519 key agreement outcome message must not be empty"
            )
        }
        contractValidateX25519OutcomeState(ok, code, igniteCode, result)
        this.ok = ok
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
    }
}

public func contractX25519GenerateKeyPair(): ContractX25519KeyPair {
    let privateKey = x25519GeneratePrivateKey()
    ContractX25519KeyPair(privateKey, contractX25519PublicFromPrivate(privateKey))
}

public func contractX25519ClampPrivateKey(privateKey: Array<Byte>): Array<Byte> {
    try {
        x25519ClampPrivateKey(privateKey)
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapX25519CryptoErrorCode(e.code),
            "X25519 private key clamp failed: ${e.message}"
        )
    }
}

public func contractX25519PublicFromPrivate(privateKey: Array<Byte>): Array<Byte> {
    try {
        x25519PublicFromPrivate(privateKey)
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapX25519CryptoErrorCode(e.code),
            "X25519 public key derivation failed: ${e.message}"
        )
    }
}

public func contractX25519DeriveKeyAgreement(
    request: ContractX25519KeyAgreementRequest
): ContractX25519KeyAgreementResult {
    try {
        let publicKey = x25519PublicFromPrivate(request.privateKey)
        let sharedSecret = x25519DeriveSharedSecret(request.privateKey, request.peerPublicKey)
        ContractX25519KeyAgreementResult(publicKey, sharedSecret)
    } catch (e: CryptoException) {
        throw ContractException(
            contractMapX25519CryptoErrorCode(e.code),
            "X25519 key agreement failed: ${e.message}"
        )
    }
}

public func contractX25519DeriveKeyAgreement(
    privateKey: Array<Byte>,
    peerPublicKey: Array<Byte>
): ContractX25519KeyAgreementResult {
    contractX25519DeriveKeyAgreement(ContractX25519KeyAgreementRequest(privateKey, peerPublicKey))
}

public func contractTryX25519DeriveKeyAgreement(
    request: ContractX25519KeyAgreementRequest
): ContractX25519KeyAgreementOutcome {
    try {
        let result = contractX25519DeriveKeyAgreement(request)
        ContractX25519KeyAgreementOutcome(true, "OK", result: Some(result))
    } catch (e: ContractException) {
        ContractX25519KeyAgreementOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

public func contractTryX25519DeriveKeyAgreement(
    privateKey: Array<Byte>,
    peerPublicKey: Array<Byte>
): ContractX25519KeyAgreementOutcome {
    try {
        let request = ContractX25519KeyAgreementRequest(privateKey, peerPublicKey)
        contractTryX25519DeriveKeyAgreement(request)
    } catch (e: ContractException) {
        ContractX25519KeyAgreementOutcome(
            false,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code))
        )
    }
}

private func contractRequireX25519KeyLength(key: Array<Byte>, label: String): Unit {
    if (key.size != CONTRACT_X25519_KEY_LEN) {
        throw ContractException(ContractErrorCode.BadInput, "${label} must be 32 bytes")
    }
}

private func contractValidateX25519OutcomeState(
    ok: Bool,
    code: ?ContractErrorCode,
    igniteCode: ?ContractIgniteCryptoErrorCode,
    result: ?ContractX25519KeyAgreementResult
): Unit {
    if (ok) {
        match (code) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "X25519 key agreement outcome code must be empty when ok is true"
                )
            case None => ()
        }
        match (igniteCode) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "X25519 key agreement outcome ignite code must be empty when ok is true"
                )
            case None => ()
        }
        match (result) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "X25519 key agreement outcome result must exist when ok is true"
                )
        }
    } else {
        match (code) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "X25519 key agreement outcome code must exist when ok is false"
                )
        }
        match (igniteCode) {
            case Some(_) => ()
            case None =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "X25519 key agreement outcome ignite code must exist when ok is false"
                )
        }
        match (result) {
            case Some(_) =>
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "X25519 key agreement outcome result must be empty when ok is false"
                )
            case None => ()
        }
    }
}

private func contractMapX25519CryptoErrorCode(code: CryptoErrorCode): ContractErrorCode {
    match (code) {
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
