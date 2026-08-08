package jinguissl.live

import std.collection.ArrayList
import jinguissl_core.crypto.digest.{sha256, sha384}
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.tls.{
    TLS13_CIPHER_SUITE_AES_256_GCM_SHA384,
    Tls13HandshakeSecrets,
    tls13ComputeFinishedVerifyData,
    tlsDecodeClientHelloHandshake,
    tlsDecodeFinishedHandshake
}
import jinguissl_core.crypto.utils.constantTimeEquals

private let C187_TLS_HANDSHAKE_HEADER_LEN: Int64 = 4

public class ContractTls13IncrementalServerClientHelloRequest {
    public let transport: ContractAcceptedTransportDescriptor
    public let plan: ContractHttpServerAttachPlan
    public let serverKeyExchangePrivate: Array<Byte>
    public let policy: ContractTlsHttpNegotiationPolicy
    public let recordResult: ContractTls13IncrementalHandshakeResult

    public init(
        transport: ContractAcceptedTransportDescriptor,
        plan: ContractHttpServerAttachPlan,
        serverKeyExchangePrivate: Array<Byte>,
        recordResult: ContractTls13IncrementalHandshakeResult,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
    ) {
        if (serverKeyExchangePrivate.size != 32) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server X25519 private key must be 32 bytes"
            )
        }
        this.transport = transport
        this.plan = plan
        this.serverKeyExchangePrivate = serverKeyExchangePrivate.clone()
        this.policy = policy
        this.recordResult = recordResult
    }
}

public class ContractTls13IncrementalServerHandshakeState {
    public let initialHandshake: ContractHttpServerInitialHandshakeFacade
    public let negotiatedAlpn: String
    public let requestedServerName: String
    public let acknowledgedServerName: Bool
    public let pendingBytes: Array<Byte>

    let context: ContractAcceptedTransportTls13X25519Context
    let encodedClientHello: Array<Byte>

    internal init(
        context: ContractAcceptedTransportTls13X25519Context,
        encodedClientHello: Array<Byte>,
        pendingBytes: Array<Byte>
    ) {
        this.initialHandshake = context.session.initialHandshake
        this.negotiatedAlpn = context.session.result.negotiatedAlpn
        this.requestedServerName = context.session.result.requestedServerName
        this.acknowledgedServerName = context.session.result.acknowledgedServerName
        this.pendingBytes = pendingBytes.clone()
        this.context = context
        this.encodedClientHello = encodedClientHello.clone()
    }
}

public class ContractTls13IncrementalServerClientHelloOutcome {
    public let ok: Bool
    public let status: ContractTls13IncrementalHandshakeStatus
    public let message: String
    public let code: ?ContractErrorCode
    public let result: ?ContractTls13IncrementalServerHandshakeState
    public let peerAlert: ?ContractTlsAlertMessage
    public let alertOutput: Array<Byte>
    public let recordsObserved: Int64
    public let pendingBytes: Array<Byte>
    public let needBytes: Int64

    public init(
        ok: Bool,
        status: ContractTls13IncrementalHandshakeStatus,
        message: String,
        code!: ?ContractErrorCode = None,
        result!: ?ContractTls13IncrementalServerHandshakeState = None,
        peerAlert!: ?ContractTlsAlertMessage = None,
        alertOutput!: Array<Byte> = [],
        recordsObserved!: Int64 = 0,
        pendingBytes!: Array<Byte> = [],
        needBytes!: Int64 = 0
    ) {
        if (message.trimAscii().size == 0 || recordsObserved < 0 || needBytes < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server ClientHello outcome fields are invalid"
            )
        }
        if (ok && status != ContractTls13IncrementalHandshakeStatus.Completed) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server ClientHello success must use COMPLETED status"
            )
        }
        if (ok) {
            if (let Some(_value) <- result) {
                ()
            } else {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.3 incremental server ClientHello success must carry state"
                )
            }
        }
        this.ok = ok
        this.status = status
        this.message = message.trimAscii()
        this.code = code
        this.result = result
        this.peerAlert = peerAlert
        this.alertOutput = alertOutput.clone()
        this.recordsObserved = recordsObserved
        this.pendingBytes = pendingBytes.clone()
        this.needBytes = needBytes
    }
}

public class ContractTls13IncrementalServerFinishedRequest {
    public let state: ContractTls13IncrementalServerHandshakeState
    public let recordResult: ContractTls13IncrementalHandshakeResult

    public init(
        state: ContractTls13IncrementalServerHandshakeState,
        recordResult: ContractTls13IncrementalHandshakeResult
    ) {
        this.state = state
        this.recordResult = recordResult
    }
}

public class ContractTls13IncrementalServerReadyRuntime {
    public let session: ContractHttpServerAcceptedTransportSession
    public let negotiatedAlpn: String
    public let requestedServerName: String
    public let acknowledgedServerName: Bool
    public let pendingApplicationRecords: Array<Array<Byte>>
    public let pendingBytes: Array<Byte>

    internal init(
        state: ContractTls13IncrementalServerHandshakeState,
        pendingApplicationRecords: Array<Array<Byte>>,
        pendingBytes: Array<Byte>
    ) {
        this.session = state.context.session
        this.negotiatedAlpn = state.negotiatedAlpn
        this.requestedServerName = state.requestedServerName
        this.acknowledgedServerName = state.acknowledgedServerName
        this.pendingApplicationRecords = c187CloneRecordWire(pendingApplicationRecords)
        this.pendingBytes = pendingBytes.clone()
    }

    public prop secureSessionReady: Bool {
        get() {
            session.secureSessionReady
        }
    }

    public prop selectedAlpn: String {
        get() {
            negotiatedAlpn
        }
    }
}

public class ContractTls13IncrementalServerFinishedOutcome {
    public let ok: Bool
    public let status: ContractTls13IncrementalHandshakeStatus
    public let message: String
    public let code: ?ContractErrorCode
    public let result: ?ContractTls13IncrementalServerReadyRuntime
    public let peerAlert: ?ContractTlsAlertMessage
    public let alertOutput: Array<Byte>
    public let recordsObserved: Int64
    public let pendingBytes: Array<Byte>
    public let needBytes: Int64

    public init(
        ok: Bool,
        status: ContractTls13IncrementalHandshakeStatus,
        message: String,
        code!: ?ContractErrorCode = None,
        result!: ?ContractTls13IncrementalServerReadyRuntime = None,
        peerAlert!: ?ContractTlsAlertMessage = None,
        alertOutput!: Array<Byte> = [],
        recordsObserved!: Int64 = 0,
        pendingBytes!: Array<Byte> = [],
        needBytes!: Int64 = 0
    ) {
        if (message.trimAscii().size == 0 || recordsObserved < 0 || needBytes < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server Finished outcome fields are invalid"
            )
        }
        if (ok && status != ContractTls13IncrementalHandshakeStatus.Completed) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server Finished success must use COMPLETED status"
            )
        }
        if (ok) {
            if (let Some(_value) <- result) {
                ()
            } else {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS1.3 incremental server Finished success must carry runtime"
                )
            }
        }
        this.ok = ok
        this.status = status
        this.message = message.trimAscii()
        this.code = code
        this.result = result
        this.peerAlert = peerAlert
        this.alertOutput = alertOutput.clone()
        this.recordsObserved = recordsObserved
        this.pendingBytes = pendingBytes.clone()
        this.needBytes = needBytes
    }
}

public func contractTls13AcceptIncrementalServerClientHello(
    transport: ContractAcceptedTransportDescriptor,
    plan: ContractHttpServerAttachPlan,
    serverKeyExchangePrivate: Array<Byte>,
    recordResult: ContractTls13IncrementalHandshakeResult,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTls13IncrementalServerHandshakeState {
    let outcome = contractTryTls13AcceptIncrementalServerClientHello(
        transport,
        plan,
        serverKeyExchangePrivate,
        recordResult,
        policy: policy
    )
    if (let Some(result) <- outcome.result) {
        return result
    }
    throw ContractException(c187OutcomeCode(outcome.code), outcome.message)
}

public func contractTls13AcceptIncrementalServerClientHelloRequest(
    request: ContractTls13IncrementalServerClientHelloRequest
): ContractTls13IncrementalServerHandshakeState {
    contractTls13AcceptIncrementalServerClientHello(
        request.transport,
        request.plan,
        request.serverKeyExchangePrivate,
        request.recordResult,
        policy: request.policy
    )
}

public func contractTryTls13AcceptIncrementalServerClientHelloRequest(
    request: ContractTls13IncrementalServerClientHelloRequest
): ContractTls13IncrementalServerClientHelloOutcome {
    contractTryTls13AcceptIncrementalServerClientHello(
        request.transport,
        request.plan,
        request.serverKeyExchangePrivate,
        request.recordResult,
        policy: request.policy
    )
}

public func contractTryTls13AcceptIncrementalServerClientHello(
    transport: ContractAcceptedTransportDescriptor,
    plan: ContractHttpServerAttachPlan,
    serverKeyExchangePrivate: Array<Byte>,
    recordResult: ContractTls13IncrementalHandshakeResult,
    policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy()
): ContractTls13IncrementalServerClientHelloOutcome {
    if (serverKeyExchangePrivate.size != 32) {
        return c187ClientHelloFailure(
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS1.3 incremental server X25519 private key must be 32 bytes",
            ContractErrorCode.BadInput,
            recordResult,
            alertOutput: c187PlainFatalAlert(ContractTlsAlertDescription.AlertIllegalParameter)
        )
    }
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.PeerAlert) {
        return ContractTls13IncrementalServerClientHelloOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.PeerAlert,
            recordResult.message,
            code: recordResult.code,
            peerAlert: recordResult.peerAlert,
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        )
    }
    if (c187CollectorTerminal(recordResult.status)) {
        let alertOutput = if (recordResult.status == ContractTls13IncrementalHandshakeStatus.Timeout ||
            recordResult.status == ContractTls13IncrementalHandshakeStatus.Cancelled) {
            Array<Byte>()
        } else {
            c187PlainFatalAlert(c187AlertForTerminalStatus(recordResult.status))
        }
        return ContractTls13IncrementalServerClientHelloOutcome(
            false,
            recordResult.status,
            recordResult.message,
            code: recordResult.code,
            peerAlert: recordResult.peerAlert,
            alertOutput: alertOutput,
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        )
    }
    if (recordResult.records.size == 0) {
        return ContractTls13IncrementalServerClientHelloOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            "TLS1.3 incremental server ClientHello needs a complete TLS record",
            recordsObserved: 0,
            pendingBytes: recordResult.pendingBytes,
            needBytes: if (recordResult.needBytes > 0) { recordResult.needBytes } else { Int64(1) }
        )
    }

    let handshakeBytes = ArrayList<Byte>()
    for (record in recordResult.records) {
        if (!c187IsPlainHandshakeRecord(record)) {
            return c187ClientHelloFailure(
                ContractTls13IncrementalHandshakeStatus.Malformed,
                "TLS1.3 incremental server ClientHello requires HANDSHAKE records",
                ContractErrorCode.BadInput,
                recordResult,
                alertOutput: c187PlainFatalAlert(ContractTlsAlertDescription.AlertUnexpectedMessage)
            )
        }
        c187AppendBytes(handshakeBytes, record.payload)
    }
    let encodedClientHello = handshakeBytes.toArray()
    if (encodedClientHello.size < C187_TLS_HANDSHAKE_HEADER_LEN) {
        return ContractTls13IncrementalServerClientHelloOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            "TLS1.3 incremental server ClientHello needs more handshake header bytes",
            recordsObserved: recordResult.records.size,
            pendingBytes: c187RecordResultCarryBytes(recordResult),
            needBytes: C187_TLS_HANDSHAKE_HEADER_LEN - encodedClientHello.size
        )
    }
    let expectedHandshakeLen = C187_TLS_HANDSHAKE_HEADER_LEN + c187DecodeUInt24(encodedClientHello, 1)
    if (encodedClientHello.size < expectedHandshakeLen) {
        return ContractTls13IncrementalServerClientHelloOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            "TLS1.3 incremental server ClientHello needs more handshake payload bytes",
            recordsObserved: recordResult.records.size,
            pendingBytes: c187RecordResultCarryBytes(recordResult),
            needBytes: expectedHandshakeLen - encodedClientHello.size
        )
    }
    if (encodedClientHello.size != expectedHandshakeLen) {
        return c187ClientHelloFailure(
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS1.3 incremental server ClientHello carries trailing handshake bytes",
            ContractErrorCode.BadInput,
            recordResult,
            alertOutput: c187PlainFatalAlert(ContractTlsAlertDescription.AlertDecodeError)
        )
    }

    try {
        _ = tlsDecodeClientHelloHandshake(encodedClientHello)
        let context = contractBuildAcceptedTransportTls13X25519Context(
            transport,
            plan,
            encodedClientHello,
            serverKeyExchangePrivate,
            policy: policy
        )
        return ContractTls13IncrementalServerClientHelloOutcome(
            true,
            ContractTls13IncrementalHandshakeStatus.Completed,
            "TLS1.3 incremental server ClientHello accepted and server flight is ready",
            result: Some(ContractTls13IncrementalServerHandshakeState(
                context,
                encodedClientHello,
                recordResult.pendingBytes
            )),
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes
        )
    } catch (e: ContractException) {
        let status = c187StatusFromContractException(e)
        return c187ClientHelloFailure(
            status,
            e.message,
            e.code,
            recordResult,
            alertOutput: c187PlainFatalAlert(c187AlertForClientHelloFailure(status, e.message))
        )
    } catch (e: CryptoException) {
        return c187ClientHelloFailure(
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS1.3 incremental server ClientHello decoding failed: ${e.message}",
            ContractErrorCode.BadInput,
            recordResult,
            alertOutput: c187PlainFatalAlert(ContractTlsAlertDescription.AlertDecodeError)
        )
    }
}

public func contractTls13VerifyIncrementalServerClientFinished(
    state: ContractTls13IncrementalServerHandshakeState,
    recordResult: ContractTls13IncrementalHandshakeResult
): ContractTls13IncrementalServerReadyRuntime {
    let outcome = contractTryTls13VerifyIncrementalServerClientFinished(state, recordResult)
    if (let Some(result) <- outcome.result) {
        return result
    }
    throw ContractException(c187OutcomeCode(outcome.code), outcome.message)
}

public func contractTls13VerifyIncrementalServerClientFinishedRequest(
    request: ContractTls13IncrementalServerFinishedRequest
): ContractTls13IncrementalServerReadyRuntime {
    contractTls13VerifyIncrementalServerClientFinished(request.state, request.recordResult)
}

public func contractTryTls13VerifyIncrementalServerClientFinishedRequest(
    request: ContractTls13IncrementalServerFinishedRequest
): ContractTls13IncrementalServerFinishedOutcome {
    contractTryTls13VerifyIncrementalServerClientFinished(request.state, request.recordResult)
}

public func contractTryTls13VerifyIncrementalServerClientFinished(
    state: ContractTls13IncrementalServerHandshakeState,
    recordResult: ContractTls13IncrementalHandshakeResult
): ContractTls13IncrementalServerFinishedOutcome {
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.PeerAlert) {
        return ContractTls13IncrementalServerFinishedOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.PeerAlert,
            recordResult.message,
            code: recordResult.code,
            peerAlert: recordResult.peerAlert,
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        )
    }
    if (c187CollectorTerminal(recordResult.status)) {
        if (recordResult.status != ContractTls13IncrementalHandshakeStatus.Timeout &&
            recordResult.status != ContractTls13IncrementalHandshakeStatus.Cancelled) {
            return c187FinishedFailure(
                state,
                recordResult.status,
                recordResult.message,
                c187OutcomeCode(recordResult.code),
                recordResult,
                c187AlertForTerminalStatus(recordResult.status)
            )
        }
        return ContractTls13IncrementalServerFinishedOutcome(
            false,
            recordResult.status,
            recordResult.message,
            code: recordResult.code,
            peerAlert: recordResult.peerAlert,
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        )
    }
    if (recordResult.records.size == 0) {
        return ContractTls13IncrementalServerFinishedOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            "TLS1.3 incremental server client Finished needs a complete protected record",
            recordsObserved: 0,
            pendingBytes: recordResult.pendingBytes,
            needBytes: if (recordResult.needBytes > 0) { recordResult.needBytes } else { Int64(1) }
        )
    }
    if (!c187IsProtectedRecordEnvelope(recordResult.records[0])) {
        return c187FinishedFailure(
            state,
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS1.3 incremental server client Finished requires a protected record",
            ContractErrorCode.BadInput,
            recordResult,
            ContractTlsAlertDescription.AlertUnexpectedMessage
        )
    }

    let channel = try {
        c187CreateServerHandshakeChannel(state)
    } catch (e: ContractException) {
        return ContractTls13IncrementalServerFinishedOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.VerificationFailed,
            e.message,
            code: Some(e.code),
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes
        )
    }

    let plain = try {
        channel.open(recordResult.records[0].encodedRecord)
    } catch (e: ContractException) {
        return c187FinishedFailureWithChannel(
            channel,
            ContractTls13IncrementalHandshakeStatus.VerificationFailed,
            e.message,
            ContractErrorCode.VerifyFailed,
            recordResult,
            ContractTlsAlertDescription.AlertDecryptError
        )
    }

    try {
        if (plain.contentType == ContractTlsRecordContentType.Alert) {
            let peerAlert = contractTlsDecodeAlertPayload(plain.fragment)
            return ContractTls13IncrementalServerFinishedOutcome(
                false,
                ContractTls13IncrementalHandshakeStatus.PeerAlert,
                "TLS1.3 incremental server received a protected peer alert",
                code: Some(ContractErrorCode.VerifyFailed),
                peerAlert: Some(peerAlert),
                recordsObserved: recordResult.records.size,
                pendingBytes: recordResult.pendingBytes
            )
        }
        if (plain.contentType != ContractTlsRecordContentType.Handshake) {
            return c187FinishedFailureWithChannel(
                channel,
                ContractTls13IncrementalHandshakeStatus.Malformed,
                "TLS1.3 incremental server client Finished did not open as HANDSHAKE",
                ContractErrorCode.BadInput,
                recordResult,
                ContractTlsAlertDescription.AlertUnexpectedMessage
            )
        }
        if (plain.fragment.size == 0 || plain.fragment[0] != UInt8(20)) {
            return c187FinishedFailureWithChannel(
                channel,
                ContractTls13IncrementalHandshakeStatus.Malformed,
                "TLS1.3 incremental server client Finished handshake type is invalid",
                ContractErrorCode.BadInput,
                recordResult,
                ContractTlsAlertDescription.AlertUnexpectedMessage
            )
        }
        let verifyData = tlsDecodeFinishedHandshake(plain.fragment)
        let fullTranscriptHash = c187FullServerFlightTranscriptHash(state)
        let expected = tls13ComputeFinishedVerifyData(
            state.context.secrets.clientHsTrafficSecret,
            fullTranscriptHash
        )
        if (!constantTimeEquals(verifyData, expected)) {
            return c187FinishedFailureWithChannel(
                channel,
                ContractTls13IncrementalHandshakeStatus.VerificationFailed,
                "TLS1.3 incremental server client Finished verify_data mismatch",
                ContractErrorCode.VerifyFailed,
                recordResult,
                ContractTlsAlertDescription.AlertDecryptError
            )
        }

        let trailingRecords = ArrayList<Array<Byte>>()
        var i: Int64 = 1
        while (i < recordResult.records.size) {
            let record = recordResult.records[i]
            if (!c187IsProtectedRecordEnvelope(record)) {
                return c187FinishedFailureWithChannel(
                    channel,
                    ContractTls13IncrementalHandshakeStatus.Malformed,
                    "TLS1.3 incremental server trailing record is not protected application data",
                    ContractErrorCode.BadInput,
                    recordResult,
                    ContractTlsAlertDescription.AlertUnexpectedMessage
                )
            }
            trailingRecords.add(record.encodedRecord.clone())
            i += 1
        }

        return ContractTls13IncrementalServerFinishedOutcome(
            true,
            ContractTls13IncrementalHandshakeStatus.Completed,
            "TLS1.3 incremental server client Finished verified and application channel is ready",
            result: Some(ContractTls13IncrementalServerReadyRuntime(
                state,
                trailingRecords.toArray(),
                recordResult.pendingBytes
            )),
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes
        )
    } catch (e: ContractException) {
        return c187FinishedFailureWithChannel(
            channel,
            c187StatusFromContractException(e),
            e.message,
            e.code,
            recordResult,
            ContractTlsAlertDescription.AlertDecryptError
        )
    } catch (e: CryptoException) {
        return c187FinishedFailureWithChannel(
            channel,
            ContractTls13IncrementalHandshakeStatus.VerificationFailed,
            "TLS1.3 incremental server client Finished verification failed: ${e.message}",
            ContractErrorCode.VerifyFailed,
            recordResult,
            ContractTlsAlertDescription.AlertDecryptError
        )
    }
}

private func c187CreateServerHandshakeChannel(
    state: ContractTls13IncrementalServerHandshakeState
): ContractTlsRecordChannel {
    let secrets = state.context.secrets
    let binding = state.context.binding
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
    let channel = contractTls13CreateServerRecordChannel(
        ContractTls13ApplicationKeyMaterial(
            clientHandshakeKey,
            clientHandshakeIv,
            serverHandshakeKey,
            serverHandshakeIv
        ),
        algorithm: binding.algorithm
    )
    let flight = state.context.session.result.serverFlight
    _ = channel.seal(ContractTlsRecordContentType.Handshake, flight.encryptedExtensions)
    _ = channel.seal(ContractTlsRecordContentType.Handshake, flight.certificateHandshake)
    _ = channel.seal(ContractTlsRecordContentType.Handshake, flight.certificateVerifyHandshake)
    _ = channel.seal(ContractTlsRecordContentType.Handshake, flight.finishedHandshake)
    channel
}

private func c187FullServerFlightTranscriptHash(
    state: ContractTls13IncrementalServerHandshakeState
): Array<Byte> {
    let flight = state.context.session.result.serverFlight
    let transcript = c187ConcatBytes([
        state.encodedClientHello,
        flight.serverHello,
        flight.encryptedExtensions,
        flight.certificateHandshake,
        flight.certificateVerifyHandshake,
        flight.finishedHandshake
    ])
    if (state.context.binding.cipherSuite == TLS13_CIPHER_SUITE_AES_256_GCM_SHA384) {
        return sha384(transcript)
    }
    sha256(transcript)
}

private func c187FinishedFailure(
    state: ContractTls13IncrementalServerHandshakeState,
    status: ContractTls13IncrementalHandshakeStatus,
    message: String,
    code: ContractErrorCode,
    recordResult: ContractTls13IncrementalHandshakeResult,
    alertDescription: ContractTlsAlertDescription
): ContractTls13IncrementalServerFinishedOutcome {
    let alertOutput = try {
        c187ProtectedFatalAlert(c187CreateServerHandshakeChannel(state), alertDescription)
    } catch (_: ContractException) {
        Array<Byte>()
    }
    ContractTls13IncrementalServerFinishedOutcome(
        false,
        status,
        message,
        code: Some(code),
        alertOutput: alertOutput,
        recordsObserved: recordResult.records.size,
        pendingBytes: recordResult.pendingBytes,
        needBytes: recordResult.needBytes
    )
}

private func c187FinishedFailureWithChannel(
    channel: ContractTlsRecordChannel,
    status: ContractTls13IncrementalHandshakeStatus,
    message: String,
    code: ContractErrorCode,
    recordResult: ContractTls13IncrementalHandshakeResult,
    alertDescription: ContractTlsAlertDescription
): ContractTls13IncrementalServerFinishedOutcome {
    let alertOutput = try {
        c187ProtectedFatalAlert(channel, alertDescription)
    } catch (_: ContractException) {
        Array<Byte>()
    }
    ContractTls13IncrementalServerFinishedOutcome(
        false,
        status,
        message,
        code: Some(code),
        alertOutput: alertOutput,
        recordsObserved: recordResult.records.size,
        pendingBytes: recordResult.pendingBytes,
        needBytes: recordResult.needBytes
    )
}

private func c187ProtectedFatalAlert(
    channel: ContractTlsRecordChannel,
    description: ContractTlsAlertDescription
): Array<Byte> {
    channel.seal(
        ContractTlsRecordContentType.Alert,
        contractTlsEncodeAlertPayload(ContractTlsAlertLevel.AlertFatal, description)
    )
}

private func c187ClientHelloFailure(
    status: ContractTls13IncrementalHandshakeStatus,
    message: String,
    code: ContractErrorCode,
    recordResult: ContractTls13IncrementalHandshakeResult,
    alertOutput!: Array<Byte> = []
): ContractTls13IncrementalServerClientHelloOutcome {
    ContractTls13IncrementalServerClientHelloOutcome(
        false,
        status,
        message,
        code: Some(code),
        alertOutput: alertOutput,
        recordsObserved: recordResult.records.size,
        pendingBytes: recordResult.pendingBytes,
        needBytes: recordResult.needBytes
    )
}

private func c187PlainFatalAlert(description: ContractTlsAlertDescription): Array<Byte> {
    contractTlsEncodeAlertRecord(
        ContractTlsVersion.Tls13,
        ContractTlsAlertLevel.AlertFatal,
        description
    )
}

private func c187StatusFromContractException(
    e: ContractException
): ContractTls13IncrementalHandshakeStatus {
    match (e.code) {
        case ContractErrorCode.BadInput =>
            if (c187LooksLikePolicyRejection(e.message)) {
                ContractTls13IncrementalHandshakeStatus.PolicyRejected
            } else {
                ContractTls13IncrementalHandshakeStatus.Malformed
            }
        case ContractErrorCode.ComplianceRejected => ContractTls13IncrementalHandshakeStatus.PolicyRejected
        case ContractErrorCode.Unsupported => ContractTls13IncrementalHandshakeStatus.PolicyRejected
        case ContractErrorCode.VerifyFailed =>
            if (c187LooksLikePolicyRejection(e.message)) {
                ContractTls13IncrementalHandshakeStatus.PolicyRejected
            } else {
                ContractTls13IncrementalHandshakeStatus.VerificationFailed
            }
        case ContractErrorCode.KeyNotFound => ContractTls13IncrementalHandshakeStatus.VerificationFailed
        case ContractErrorCode.CryptoUnavailable => ContractTls13IncrementalHandshakeStatus.VerificationFailed
        case ContractErrorCode.InternalError => ContractTls13IncrementalHandshakeStatus.VerificationFailed
    }
}

private func c187LooksLikePolicyRejection(message: String): Bool {
    let normalized = message.toAsciiLower()
    normalized.contains("alpn") ||
    normalized.contains("server name") ||
    normalized.contains("sni") ||
    normalized.contains("policy")
}

private func c187AlertForClientHelloFailure(
    status: ContractTls13IncrementalHandshakeStatus,
    message: String
): ContractTlsAlertDescription {
    if (status == ContractTls13IncrementalHandshakeStatus.PolicyRejected) {
        let normalized = message.toAsciiLower()
        if (normalized.contains("alpn")) {
            return ContractTlsAlertDescription.AlertNoApplicationProtocol
        }
        if (normalized.contains("server name") || normalized.contains("sni")) {
            return ContractTlsAlertDescription.AlertUnrecognizedName
        }
        return ContractTlsAlertDescription.AlertHandshakeFailure
    }
    ContractTlsAlertDescription.AlertDecodeError
}

private func c187AlertForTerminalStatus(
    status: ContractTls13IncrementalHandshakeStatus
): ContractTlsAlertDescription {
    match (status) {
        case ContractTls13IncrementalHandshakeStatus.Malformed => ContractTlsAlertDescription.AlertDecodeError
        case ContractTls13IncrementalHandshakeStatus.PolicyRejected => ContractTlsAlertDescription.AlertHandshakeFailure
        case ContractTls13IncrementalHandshakeStatus.VerificationFailed => ContractTlsAlertDescription.AlertDecryptError
        case _ => ContractTlsAlertDescription.AlertInternalError
    }
}

private func c187CollectorTerminal(status: ContractTls13IncrementalHandshakeStatus): Bool {
    status == ContractTls13IncrementalHandshakeStatus.Malformed ||
    status == ContractTls13IncrementalHandshakeStatus.PolicyRejected ||
    status == ContractTls13IncrementalHandshakeStatus.VerificationFailed ||
    status == ContractTls13IncrementalHandshakeStatus.Timeout ||
    status == ContractTls13IncrementalHandshakeStatus.Cancelled
}

private func c187IsPlainHandshakeRecord(record: ContractTls13IncrementalRecordFrame): Bool {
    (
        record.version == ContractTlsVersion.Tls13 ||
        record.version == ContractTlsVersion.Tls12
    ) && record.contentType == ContractTlsRecordContentType.Handshake
}

private func c187IsProtectedRecordEnvelope(record: ContractTls13IncrementalRecordFrame): Bool {
    (
        record.version == ContractTlsVersion.Tls13 ||
        record.version == ContractTlsVersion.Tls12
    ) && record.contentType == ContractTlsRecordContentType.ApplicationData
}

private func c187DecodeUInt24(input: Array<Byte>, offset: Int64): Int64 {
    (Int64(UInt8(input[offset])) << 16) |
    (Int64(UInt8(input[offset + 1])) << 8) |
    Int64(UInt8(input[offset + 2]))
}

private func c187RecordResultCarryBytes(
    recordResult: ContractTls13IncrementalHandshakeResult
): Array<Byte> {
    let out = ArrayList<Byte>()
    for (record in recordResult.records) {
        c187AppendBytes(out, record.encodedRecord)
    }
    c187AppendBytes(out, recordResult.pendingBytes)
    out.toArray()
}

private func c187ConcatBytes(parts: Array<Array<Byte>>): Array<Byte> {
    let out = ArrayList<Byte>()
    for (part in parts) {
        c187AppendBytes(out, part)
    }
    out.toArray()
}

private func c187AppendBytes(out: ArrayList<Byte>, input: Array<Byte>): Unit {
    for (b in input) {
        out.add(b)
    }
}

private func c187CloneRecordWire(records: Array<Array<Byte>>): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    for (record in records) {
        out.add(record.clone())
    }
    out.toArray()
}

private func c187OutcomeCode(code: ?ContractErrorCode): ContractErrorCode {
    match (code) {
        case Some(value) => value
        case None => ContractErrorCode.VerifyFailed
    }
}
