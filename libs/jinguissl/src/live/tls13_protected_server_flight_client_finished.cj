package jinguissl.live

import std.collection.ArrayList
import jinguissl_core.crypto.digest.{sha256, sha384}
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.tls.{
    TLS13_CIPHER_SUITE_AES_256_GCM_SHA384,
    tls13ComputeFinishedVerifyData,
    tls13DeriveSecretsFromX25519ForCipherSuite,
    tls13ExtractServerX25519KeyShare,
    tlsEncodeFinishedHandshake
}

public class ContractTls13ProtectedServerFlightRequest {
    public let clientHello: ContractTls13HttpClientHelloX25519
    public let serverFlight: ContractTls13HttpServerFlight
    public let trust: ContractHttpClientTlsTrustRequest
    public let recordResult: ContractTls13IncrementalHandshakeResult

    public init(
        clientHello: ContractTls13HttpClientHelloX25519,
        serverFlight: ContractTls13HttpServerFlight,
        trust: ContractHttpClientTlsTrustRequest,
        recordResult: ContractTls13IncrementalHandshakeResult
    ) {
        this.clientHello = clientHello
        this.serverFlight = serverFlight
        this.trust = trust
        this.recordResult = recordResult
    }
}

public class ContractTls13ProtectedServerFlightMapping {
    public let serverFlight: ContractTls13HttpServerFlight
    public let serverHello: Array<Byte>
    public let encryptedExtensions: Array<Byte>
    public let certificateHandshake: Array<Byte>
    public let certificateVerifyHandshake: Array<Byte>
    public let finishedHandshake: Array<Byte>
    public let decodedProtectedRecordCount: Int64

    public init(
        serverFlight: ContractTls13HttpServerFlight,
        serverHello: Array<Byte>,
        encryptedExtensions: Array<Byte>,
        certificateHandshake: Array<Byte>,
        certificateVerifyHandshake: Array<Byte>,
        finishedHandshake: Array<Byte>,
        decodedProtectedRecordCount: Int64
    ) {
        if (decodedProtectedRecordCount < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 protected server flight decoded record count must be >= 0"
            )
        }
        this.serverFlight = serverFlight
        this.serverHello = serverHello.clone()
        this.encryptedExtensions = encryptedExtensions.clone()
        this.certificateHandshake = certificateHandshake.clone()
        this.certificateVerifyHandshake = certificateVerifyHandshake.clone()
        this.finishedHandshake = finishedHandshake.clone()
        this.decodedProtectedRecordCount = decodedProtectedRecordCount
    }
}

public class ContractTls13ClientFinishedOutput {
    public let encodedFinishedHandshake: Array<Byte>
    public let encodedRecord: Array<Byte>
    public let writeSurface: String
    public let deferred: Bool

    public init(
        encodedFinishedHandshake: Array<Byte>,
        encodedRecord: Array<Byte>,
        writeSurface!: String = "tls13-client-finished-record",
        deferred!: Bool = false
    ) {
        if (encodedFinishedHandshake.size == 0 || encodedRecord.size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 client Finished output must carry non-empty handshake and record bytes"
            )
        }
        if (writeSurface.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 client Finished output write surface must not be empty"
            )
        }
        this.encodedFinishedHandshake = encodedFinishedHandshake.clone()
        this.encodedRecord = encodedRecord.clone()
        this.writeSurface = writeSurface.trimAscii()
        this.deferred = deferred
    }
}

public class ContractTls13ProtectedServerFlightClientRuntime {
    public let runtime: ContractTls13HttpClientVerifiedSessionRuntime
    public let mappedFlight: ContractTls13ProtectedServerFlightMapping
    public let clientFinished: ContractTls13ClientFinishedOutput

    public init(
        runtime: ContractTls13HttpClientVerifiedSessionRuntime,
        mappedFlight: ContractTls13ProtectedServerFlightMapping,
        clientFinished: ContractTls13ClientFinishedOutput
    ) {
        this.runtime = runtime
        this.mappedFlight = mappedFlight
        this.clientFinished = clientFinished
    }
}

public class ContractTls13ProtectedServerFlightOutcome {
    public let ok: Bool
    public let status: ContractTls13IncrementalHandshakeStatus
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractTls13ProtectedServerFlightClientRuntime
    public let peerAlert: ?ContractTlsAlertMessage
    public let recordsObserved: Int64
    public let pendingBytes: Array<Byte>
    public let needBytes: Int64

    public init(
        ok: Bool,
        status: ContractTls13IncrementalHandshakeStatus,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractTls13ProtectedServerFlightClientRuntime = None,
        peerAlert!: ?ContractTlsAlertMessage = None,
        recordsObserved!: Int64 = 0,
        pendingBytes!: Array<Byte> = [],
        needBytes!: Int64 = 0
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 protected server flight outcome message must not be empty"
            )
        }
        if (recordsObserved < 0 || needBytes < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 protected server flight outcome counters must be >= 0"
            )
        }
        if (ok && status != ContractTls13IncrementalHandshakeStatus.Completed) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 protected server flight success must use COMPLETED status"
            )
        }
        if (!ok && status == ContractTls13IncrementalHandshakeStatus.Completed) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 protected server flight failure must not use COMPLETED status"
            )
        }
        if (ok) {
            if (let Some(_value) <- result) {
                ()
            } else {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.3 protected server flight success must carry result"
                )
            }
            if (let Some(_value) <- code) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.3 protected server flight success must not carry ContractErrorCode"
                )
            }
            if (let Some(_value) <- igniteCode) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.3 protected server flight success must not carry Ignite error code"
                )
            }
        } else {
            if (let Some(_value) <- result) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.3 protected server flight failure must not carry result"
                )
            }
        }
        this.ok = ok
        this.status = status
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
        this.peerAlert = peerAlert
        this.recordsObserved = recordsObserved
        this.pendingBytes = pendingBytes.clone()
        this.needBytes = needBytes
    }
}

private class C186ProtectedServerFlightArtifacts {
    let mappedFlight: ContractTls13ProtectedServerFlightMapping
    let clientFinished: ContractTls13ClientFinishedOutput

    init(
        mappedFlight: ContractTls13ProtectedServerFlightMapping,
        clientFinished: ContractTls13ClientFinishedOutput
    ) {
        this.mappedFlight = mappedFlight
        this.clientFinished = clientFinished
    }
}

private class C186ProtectedServerFlightMapAttempt {
    let failure: ?ContractTls13ProtectedServerFlightOutcome
    let artifacts: ?C186ProtectedServerFlightArtifacts

    init(
        failure!: ?ContractTls13ProtectedServerFlightOutcome = None,
        artifacts!: ?C186ProtectedServerFlightArtifacts = None
    ) {
        if (let Some(_failure) <- failure) {
            if (let Some(_artifacts) <- artifacts) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.3 protected server flight map attempt cannot carry failure and artifacts together"
                )
            }
        }
        this.failure = failure
        this.artifacts = artifacts
    }
}

public func contractTls13OpenHttpClientRuntimeFromProtectedServerFlight(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    trust: ContractHttpClientTlsTrustRequest,
    recordResult: ContractTls13IncrementalHandshakeResult
): ContractTls13ProtectedServerFlightClientRuntime {
    let outcome = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
        clientHello,
        serverFlight,
        trust,
        recordResult
    )
    if (let Some(result) <- outcome.result) {
        return result
    }
    let code = match (outcome.code) {
        case Some(value) => value
        case None => ContractErrorCode.VerifyFailed
    }
    throw ContractException(code, outcome.message)
}

public func contractTls13OpenHttpClientRuntimeFromProtectedServerFlightRequest(
    request: ContractTls13ProtectedServerFlightRequest
): ContractTls13ProtectedServerFlightClientRuntime {
    contractTls13OpenHttpClientRuntimeFromProtectedServerFlight(
        request.clientHello,
        request.serverFlight,
        request.trust,
        request.recordResult
    )
}

public func contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    trust: ContractHttpClientTlsTrustRequest,
    recordResult: ContractTls13IncrementalHandshakeResult
): ContractTls13ProtectedServerFlightOutcome {
    let mapAttempt = c186TryMapProtectedServerFlight(clientHello, serverFlight, recordResult)
    if (let Some(failure) <- mapAttempt.failure) {
        return failure
    }
    let artifacts = match (mapAttempt.artifacts) {
        case Some(value) => value
        case None => return c186ProtectedFailure(
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS1.3 protected server flight mapping artifacts are unavailable",
            ContractErrorCode.InternalError,
            recordResult.records.size
        )
    }

    let runtimeOutcome = contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
        clientHello,
        serverFlight,
        trust,
        recordResult
    )
    if (!runtimeOutcome.ok) {
        return ContractTls13ProtectedServerFlightOutcome(
            false,
            runtimeOutcome.status,
            runtimeOutcome.message,
            code: runtimeOutcome.code,
            igniteCode: runtimeOutcome.igniteCode,
            peerAlert: runtimeOutcome.peerAlert,
            recordsObserved: runtimeOutcome.recordsObserved,
            pendingBytes: runtimeOutcome.pendingBytes,
            needBytes: runtimeOutcome.needBytes
        )
    }
    let runtime = match (runtimeOutcome.runtime) {
        case Some(value) => value
        case None => return c186ProtectedFailure(
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS1.3 protected server flight runtime result is unavailable",
            ContractErrorCode.InternalError,
            recordResult.records.size
        )
    }

    ContractTls13ProtectedServerFlightOutcome(
        true,
        ContractTls13IncrementalHandshakeStatus.Completed,
        "TLS1.3 protected server flight mapped and client Finished output is ready",
        result: Some(ContractTls13ProtectedServerFlightClientRuntime(
            runtime,
            artifacts.mappedFlight,
            artifacts.clientFinished
        )),
        recordsObserved: recordResult.records.size
    )
}

public func contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlightRequest(
    request: ContractTls13ProtectedServerFlightRequest
): ContractTls13ProtectedServerFlightOutcome {
    contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
        request.clientHello,
        request.serverFlight,
        request.trust,
        request.recordResult
    )
}

private func c186TryMapProtectedServerFlight(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    recordResult: ContractTls13IncrementalHandshakeResult
): C186ProtectedServerFlightMapAttempt {
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.NeedMoreBytes) {
        return C186ProtectedServerFlightMapAttempt(failure: Some(ContractTls13ProtectedServerFlightOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            recordResult.message,
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        )))
    }
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.PeerAlert) {
        return C186ProtectedServerFlightMapAttempt(failure: Some(ContractTls13ProtectedServerFlightOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.PeerAlert,
            recordResult.message,
            code: Some(ContractErrorCode.VerifyFailed),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.VerifyFailed)),
            peerAlert: recordResult.peerAlert,
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        )))
    }
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.Malformed ||
        recordResult.status == ContractTls13IncrementalHandshakeStatus.PolicyRejected ||
        recordResult.status == ContractTls13IncrementalHandshakeStatus.VerificationFailed ||
        recordResult.status == ContractTls13IncrementalHandshakeStatus.Timeout ||
        recordResult.status == ContractTls13IncrementalHandshakeStatus.Cancelled) {
        return C186ProtectedServerFlightMapAttempt(failure: Some(c186FailureFromCollector(recordResult)))
    }
    if (recordResult.status != ContractTls13IncrementalHandshakeStatus.RecordsReady &&
        recordResult.status != ContractTls13IncrementalHandshakeStatus.Completed) {
        return C186ProtectedServerFlightMapAttempt(failure: Some(c186ProtectedFailure(
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS1.3 protected server flight record status is not usable",
            ContractErrorCode.BadInput,
            recordResult.records.size
        )))
    }
    if (recordResult.pendingBytes.size > 0) {
        return C186ProtectedServerFlightMapAttempt(failure: Some(ContractTls13ProtectedServerFlightOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            "TLS1.3 protected server flight still has pending partial bytes",
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        )))
    }
    if (recordResult.records.size < 5) {
        return C186ProtectedServerFlightMapAttempt(failure: Some(ContractTls13ProtectedServerFlightOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            "TLS1.3 protected server flight needs five TLS records",
            recordsObserved: recordResult.records.size,
            needBytes: 1
        )))
    }
    if (recordResult.records.size > 5) {
        return C186ProtectedServerFlightMapAttempt(failure: Some(c186ProtectedFailure(
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS1.3 protected server flight first slice accepts exactly five records",
            ContractErrorCode.BadInput,
            recordResult.records.size
        )))
    }

    let first = recordResult.records[0]
    if (first.version != ContractTlsVersion.Tls13 ||
        first.contentType != ContractTlsRecordContentType.Handshake ||
        !c186BytesEqual(first.payload, serverFlight.serverHello)) {
        return C186ProtectedServerFlightMapAttempt(failure: Some(c186ProtectedFailure(
            ContractTls13IncrementalHandshakeStatus.VerificationFailed,
            "TLS1.3 protected server flight ServerHello record does not match expected flight",
            ContractErrorCode.VerifyFailed,
            recordResult.records.size
        )))
    }
    var i: Int64 = 1
    while (i < 5) {
        let record = recordResult.records[i]
        if (!c186IsTls13ProtectedRecordEnvelope(record)) {
            return C186ProtectedServerFlightMapAttempt(failure: Some(c186ProtectedFailure(
                ContractTls13IncrementalHandshakeStatus.Malformed,
                "TLS1.3 protected server flight encrypted handshake record envelope is invalid",
                ContractErrorCode.BadInput,
                recordResult.records.size
            )))
        }
        i += 1
    }

    try {
        let binding = contractTls13ResolveCipherBindingFromServerFlight(serverFlight)
        let serverPublicKey = tls13ExtractServerX25519KeyShare(serverFlight.serverHello)
        let secrets = tls13DeriveSecretsFromX25519ForCipherSuite(
            clientHello.clientPrivateKey,
            serverPublicKey,
            serverFlight.transcriptHash,
            binding.cipherSuite
        )
        let (clientHandshakeKey, clientHandshakeIv) = contractTls13DeriveApplicationTrafficKeyIv(
            secrets.clientHsTrafficSecret,
            keyLen: binding.keyLen,
            ivLen: binding.ivLen
        )
        let (serverHandshakeKey, serverHandshakeIv) = contractTls13DeriveApplicationTrafficKeyIv(
            secrets.serverHsTrafficSecret,
            keyLen: binding.keyLen,
            ivLen: binding.ivLen
        )
        let handshakeKeyMaterial = ContractTls13ApplicationKeyMaterial(
            clientHandshakeKey,
            clientHandshakeIv,
            serverHandshakeKey,
            serverHandshakeIv
        )
        let clientHandshakeChannel = contractTls13CreateClientRecordChannel(
            handshakeKeyMaterial,
            algorithm: binding.algorithm
        )

        let encryptedExtensions = c186OpenExpectedProtectedHandshake(
            clientHandshakeChannel,
            recordResult.records[1],
            serverFlight.encryptedExtensions,
            "EncryptedExtensions"
        )
        let certificateHandshake = c186OpenExpectedProtectedHandshake(
            clientHandshakeChannel,
            recordResult.records[2],
            serverFlight.certificateHandshake,
            "Certificate"
        )
        let certificateVerifyHandshake = c186OpenExpectedProtectedHandshake(
            clientHandshakeChannel,
            recordResult.records[3],
            serverFlight.certificateVerifyHandshake,
            "CertificateVerify"
        )
        let finishedHandshake = c186OpenExpectedProtectedHandshake(
            clientHandshakeChannel,
            recordResult.records[4],
            serverFlight.finishedHandshake,
            "Finished"
        )
        let fullTranscriptHash = c186Tls13FullServerFlightTranscriptHash(
            binding.cipherSuite,
            clientHello.encodedClientHello,
            serverFlight.serverHello,
            encryptedExtensions,
            certificateHandshake,
            certificateVerifyHandshake,
            finishedHandshake
        )
        let encodedClientFinished = tlsEncodeFinishedHandshake(
            tls13ComputeFinishedVerifyData(secrets.clientHsTrafficSecret, fullTranscriptHash)
        )
        let encodedClientFinishedRecord = clientHandshakeChannel.seal(
            ContractTlsRecordContentType.Handshake,
            encodedClientFinished
        )
        let mapped = ContractTls13ProtectedServerFlightMapping(
            serverFlight,
            serverFlight.serverHello,
            encryptedExtensions,
            certificateHandshake,
            certificateVerifyHandshake,
            finishedHandshake,
            Int64(4)
        )
        let clientFinished = ContractTls13ClientFinishedOutput(
            encodedClientFinished,
            encodedClientFinishedRecord
        )
        C186ProtectedServerFlightMapAttempt(
            artifacts: Some(C186ProtectedServerFlightArtifacts(mapped, clientFinished))
        )
    } catch (e: ContractException) {
        let status = if (e.code == ContractErrorCode.BadInput) {
            ContractTls13IncrementalHandshakeStatus.Malformed
        } else {
            ContractTls13IncrementalHandshakeStatus.VerificationFailed
        }
        C186ProtectedServerFlightMapAttempt(failure: Some(c186ProtectedFailure(
            status,
            e.message,
            e.code,
            recordResult.records.size
        )))
    } catch (e: CryptoException) {
        C186ProtectedServerFlightMapAttempt(failure: Some(c186ProtectedFailure(
            ContractTls13IncrementalHandshakeStatus.VerificationFailed,
            "TLS1.3 protected server flight crypto mapping failed: ${e.message}",
            ContractErrorCode.VerifyFailed,
            recordResult.records.size
        )))
    }
}

private func c186IsTls13ProtectedRecordEnvelope(record: ContractTls13IncrementalRecordFrame): Bool {
    (
        record.version == ContractTlsVersion.Tls13 ||
        record.version == ContractTlsVersion.Tls12
    ) && record.contentType == ContractTlsRecordContentType.ApplicationData
}

private func c186OpenExpectedProtectedHandshake(
    channel: ContractTlsRecordChannel,
    record: ContractTls13IncrementalRecordFrame,
    expected: Array<Byte>,
    label: String
): Array<Byte> {
    let plain = channel.open(record.encodedRecord)
    if (plain.contentType != ContractTlsRecordContentType.Handshake) {
        throw ContractException(
            ContractErrorCode.BadInput,
            "TLS1.3 protected server flight ${label} record did not open as HANDSHAKE"
        )
    }
    if (!c186BytesEqual(plain.fragment, expected)) {
        throw ContractException(
            ContractErrorCode.VerifyFailed,
            "TLS1.3 protected server flight ${label} payload does not match expected flight"
        )
    }
    plain.fragment
}

private func c186Tls13FullServerFlightTranscriptHash(
    cipherSuite: Int64,
    encodedClientHello: Array<Byte>,
    serverHello: Array<Byte>,
    encryptedExtensions: Array<Byte>,
    certificateHandshake: Array<Byte>,
    certificateVerifyHandshake: Array<Byte>,
    finishedHandshake: Array<Byte>
): Array<Byte> {
    let transcript = c186ConcatBytes([
        encodedClientHello,
        serverHello,
        encryptedExtensions,
        certificateHandshake,
        certificateVerifyHandshake,
        finishedHandshake
    ])
    if (cipherSuite == TLS13_CIPHER_SUITE_AES_256_GCM_SHA384) {
        return sha384(transcript)
    }
    sha256(transcript)
}

private func c186ConcatBytes(parts: Array<Array<Byte>>): Array<Byte> {
    let out = ArrayList<Byte>()
    for (part in parts) {
        for (b in part) {
            out.add(b)
        }
    }
    out.toArray()
}

private func c186FailureFromCollector(
    recordResult: ContractTls13IncrementalHandshakeResult
): ContractTls13ProtectedServerFlightOutcome {
    let code = match (recordResult.code) {
        case Some(value) => value
        case None => ContractErrorCode.BadInput
    }
    ContractTls13ProtectedServerFlightOutcome(
        false,
        recordResult.status,
        recordResult.message,
        code: Some(code),
        igniteCode: Some(contractMapToIgniteCryptoErrorCode(code)),
        peerAlert: recordResult.peerAlert,
        recordsObserved: recordResult.records.size,
        pendingBytes: recordResult.pendingBytes,
        needBytes: recordResult.needBytes
    )
}

private func c186ProtectedFailure(
    status: ContractTls13IncrementalHandshakeStatus,
    message: String,
    code: ContractErrorCode,
    recordsObserved: Int64
): ContractTls13ProtectedServerFlightOutcome {
    ContractTls13ProtectedServerFlightOutcome(
        false,
        status,
        message,
        code: Some(code),
        igniteCode: Some(contractMapToIgniteCryptoErrorCode(code)),
        recordsObserved: recordsObserved
    )
}

private func c186BytesEqual(left: Array<Byte>, right: Array<Byte>): Bool {
    if (left.size != right.size) {
        return false
    }
    var i: Int64 = 0
    while (i < left.size) {
        if (left[i] != right[i]) {
            return false
        }
        i += 1
    }
    true
}
