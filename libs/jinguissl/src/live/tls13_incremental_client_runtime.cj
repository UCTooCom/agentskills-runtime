package jinguissl.live

public class ContractTls13IncrementalClientRuntimeRequest {
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

public class ContractTls13IncrementalClientRuntimeOutcome {
    public let ok: Bool
    public let status: ContractTls13IncrementalHandshakeStatus
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let runtime: ?ContractTls13HttpClientVerifiedSessionRuntime
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
        runtime!: ?ContractTls13HttpClientVerifiedSessionRuntime = None,
        peerAlert!: ?ContractTlsAlertMessage = None,
        recordsObserved!: Int64 = 0,
        pendingBytes!: Array<Byte> = [],
        needBytes!: Int64 = 0
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS incremental client runtime outcome message must not be empty"
            )
        }
        if (recordsObserved < 0 || needBytes < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS incremental client runtime outcome counters must be >= 0"
            )
        }
        if (ok && status != ContractTls13IncrementalHandshakeStatus.Completed) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS incremental client runtime success must use COMPLETED status"
            )
        }
        if (!ok && status == ContractTls13IncrementalHandshakeStatus.Completed) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS incremental client runtime failure must not use COMPLETED status"
            )
        }
        if (ok) {
            if (let Some(_value) <- code) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS incremental client runtime success must not carry ContractErrorCode"
                )
            }
            if (let Some(_value) <- igniteCode) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS incremental client runtime success must not carry Ignite error code"
                )
            }
            if (let Some(_value) <- runtime) {
                ()
            } else {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS incremental client runtime success must carry runtime"
                )
            }
        } else {
            if (let Some(_value) <- runtime) {
                throw ContractException(
                    ContractErrorCode.BadInput,
                    "TLS incremental client runtime failure must not carry runtime"
                )
            }
        }
        this.ok = ok
        this.status = status
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.runtime = runtime
        this.peerAlert = peerAlert
        this.recordsObserved = recordsObserved
        this.pendingBytes = pendingBytes.clone()
        this.needBytes = needBytes
    }
}

public func contractTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    trust: ContractHttpClientTlsTrustRequest,
    recordResult: ContractTls13IncrementalHandshakeResult
): ContractTls13HttpClientVerifiedSessionRuntime {
    let outcome = contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
        clientHello,
        serverFlight,
        trust,
        recordResult
    )
    if (let Some(runtime) <- outcome.runtime) {
        return runtime
    }
    let code = match (outcome.code) {
        case Some(value) => value
        case None => ContractErrorCode.VerifyFailed
    }
    throw ContractException(code, outcome.message)
}

public func contractTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlightRequest(
    request: ContractTls13IncrementalClientRuntimeRequest
): ContractTls13HttpClientVerifiedSessionRuntime {
    contractTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
        request.clientHello,
        request.serverFlight,
        request.trust,
        request.recordResult
    )
}

public func contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
    clientHello: ContractTls13HttpClientHelloX25519,
    serverFlight: ContractTls13HttpServerFlight,
    trust: ContractHttpClientTlsTrustRequest,
    recordResult: ContractTls13IncrementalHandshakeResult
): ContractTls13IncrementalClientRuntimeOutcome {
    let gate = contractTls13ValidateCollectedServerFlightRecords(recordResult, serverFlight)
    if (let Some(failure) <- gate) {
        return failure
    }

    try {
        let session = contractTls13VerifyHttpServerFlightX25519WithSession(
            clientHello,
            serverFlight,
            trust.trustAnchorsPemBundle,
            intermediatesPemBundle: trust.intermediatesPemBundle,
            hostname: trust.hostname,
            validationTime: trust.validationTime,
            pinPolicy: trust.pinPolicy,
            policy: trust.policy
        )
        let runtime = contractTls13OpenHttpClientVerifiedSessionRuntime(session)
        ContractTls13IncrementalClientRuntimeOutcome(
            true,
            ContractTls13IncrementalHandshakeStatus.Completed,
            "TLS1.3 HTTP client verified session runtime is ready",
            runtime: Some(runtime),
            recordsObserved: recordResult.records.size
        )
    } catch (e: ContractException) {
        let status = contractTls13IncrementalStatusFromContractError(e.code)
        ContractTls13IncrementalClientRuntimeOutcome(
            false,
            status,
            e.message,
            code: Some(e.code),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(e.code)),
            recordsObserved: recordResult.records.size
        )
    }
}

public func contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlightRequest(
    request: ContractTls13IncrementalClientRuntimeRequest
): ContractTls13IncrementalClientRuntimeOutcome {
    contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
        request.clientHello,
        request.serverFlight,
        request.trust,
        request.recordResult
    )
}

private func contractTls13ValidateCollectedServerFlightRecords(
    recordResult: ContractTls13IncrementalHandshakeResult,
    serverFlight: ContractTls13HttpServerFlight
): ?ContractTls13IncrementalClientRuntimeOutcome {
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.NeedMoreBytes) {
        return Some(ContractTls13IncrementalClientRuntimeOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            recordResult.message,
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        ))
    }
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.PeerAlert) {
        return Some(ContractTls13IncrementalClientRuntimeOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.PeerAlert,
            recordResult.message,
            code: Some(ContractErrorCode.VerifyFailed),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.VerifyFailed)),
            peerAlert: recordResult.peerAlert,
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        ))
    }
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.Malformed) {
        return Some(contractTls13IncrementalClientRuntimeFailureFromCollector(recordResult))
    }
    if (recordResult.status == ContractTls13IncrementalHandshakeStatus.PolicyRejected ||
        recordResult.status == ContractTls13IncrementalHandshakeStatus.VerificationFailed ||
        recordResult.status == ContractTls13IncrementalHandshakeStatus.Timeout ||
        recordResult.status == ContractTls13IncrementalHandshakeStatus.Cancelled) {
        return Some(contractTls13IncrementalClientRuntimeFailureFromCollector(recordResult))
    }
    if (recordResult.status != ContractTls13IncrementalHandshakeStatus.RecordsReady &&
        recordResult.status != ContractTls13IncrementalHandshakeStatus.Completed) {
        return Some(ContractTls13IncrementalClientRuntimeOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.Malformed,
            "TLS incremental server flight record status is not usable for runtime composition",
            code: Some(ContractErrorCode.BadInput),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.BadInput)),
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        ))
    }
    if (recordResult.pendingBytes.size > 0) {
        return Some(ContractTls13IncrementalClientRuntimeOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            "TLS incremental server flight still has pending partial bytes",
            recordsObserved: recordResult.records.size,
            pendingBytes: recordResult.pendingBytes,
            needBytes: recordResult.needBytes
        ))
    }
    if (recordResult.records.size < 5) {
        return Some(ContractTls13IncrementalClientRuntimeOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
            "TLS incremental server flight needs the full five-record TLS1.3 server flight",
            recordsObserved: recordResult.records.size,
            needBytes: 1
        ))
    }
    let first = recordResult.records[0]
    if (first.version != ContractTlsVersion.Tls13 ||
        first.contentType != ContractTlsRecordContentType.Handshake ||
        !contractTls13IncrementalBytesEqual(first.payload, serverFlight.serverHello)) {
        return Some(ContractTls13IncrementalClientRuntimeOutcome(
            false,
            ContractTls13IncrementalHandshakeStatus.VerificationFailed,
            "TLS incremental server flight ServerHello record does not match expected server flight",
            code: Some(ContractErrorCode.VerifyFailed),
            igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.VerifyFailed)),
            recordsObserved: recordResult.records.size
        ))
    }
    var i: Int64 = 1
    while (i < 5) {
        if (!contractTls13IncrementalIsProtectedEnvelope(recordResult.records[i])) {
            return Some(ContractTls13IncrementalClientRuntimeOutcome(
                false,
                ContractTls13IncrementalHandshakeStatus.VerificationFailed,
                "TLS incremental server flight encrypted handshake record envelope is invalid",
                code: Some(ContractErrorCode.VerifyFailed),
                igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.VerifyFailed)),
                recordsObserved: recordResult.records.size
            ))
        }
        i += 1
    }
    None
}

private func contractTls13IncrementalIsProtectedEnvelope(record: ContractTls13IncrementalRecordFrame): Bool {
    (
        record.version == ContractTlsVersion.Tls13 ||
        record.version == ContractTlsVersion.Tls12
    ) && record.contentType == ContractTlsRecordContentType.ApplicationData
}

private func contractTls13IncrementalClientRuntimeFailureFromCollector(
    recordResult: ContractTls13IncrementalHandshakeResult
): ContractTls13IncrementalClientRuntimeOutcome {
    let code = match (recordResult.code) {
        case Some(value) => value
        case None => ContractErrorCode.BadInput
    }
    ContractTls13IncrementalClientRuntimeOutcome(
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

private func contractTls13IncrementalStatusFromContractError(
    code: ContractErrorCode
): ContractTls13IncrementalHandshakeStatus {
    match (code) {
        case ContractErrorCode.BadInput => ContractTls13IncrementalHandshakeStatus.Malformed
        case ContractErrorCode.ComplianceRejected => ContractTls13IncrementalHandshakeStatus.PolicyRejected
        case ContractErrorCode.Unsupported => ContractTls13IncrementalHandshakeStatus.PolicyRejected
        case ContractErrorCode.VerifyFailed => ContractTls13IncrementalHandshakeStatus.VerificationFailed
        case ContractErrorCode.KeyNotFound => ContractTls13IncrementalHandshakeStatus.VerificationFailed
        case ContractErrorCode.CryptoUnavailable => ContractTls13IncrementalHandshakeStatus.VerificationFailed
        case ContractErrorCode.InternalError => ContractTls13IncrementalHandshakeStatus.VerificationFailed
    }
}

private func contractTls13IncrementalBytesEqual(left: Array<Byte>, right: Array<Byte>): Bool {
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
