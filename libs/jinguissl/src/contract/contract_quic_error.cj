package jinguissl.contract

import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}

func contractQuicMapCryptoErrorCode(
    exception: CryptoException,
    verificationFailure: Bool
): ContractErrorCode {
    if (verificationFailure &&
        (exception.code == CryptoErrorCode.InvalidArgument ||
        exception.code == CryptoErrorCode.ParseError)) {
        return ContractErrorCode.VerifyFailed
    }

    match (exception.code) {
        case CryptoErrorCode.InvalidArgument => ContractErrorCode.BadInput
        case CryptoErrorCode.OutOfBounds => ContractErrorCode.BadInput
        case CryptoErrorCode.DivideByZero => ContractErrorCode.InternalError
        case CryptoErrorCode.NoModInverse => ContractErrorCode.InternalError
        case CryptoErrorCode.ComplianceRejected => ContractErrorCode.ComplianceRejected
        case CryptoErrorCode.ParseError => ContractErrorCode.VerifyFailed
        case CryptoErrorCode.Unsupported => ContractErrorCode.Unsupported
        case CryptoErrorCode.InternalError => ContractErrorCode.InternalError
        case _ => ContractErrorCode.InternalError
    }
}

func contractQuicException(
    operation: String,
    exception: CryptoException,
    verificationFailure: Bool
): ContractException {
    ContractException(
        contractQuicMapCryptoErrorCode(exception, verificationFailure),
        "${operation} failed: ${exception.message}"
    )
}
