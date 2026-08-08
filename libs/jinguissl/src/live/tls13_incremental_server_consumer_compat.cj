package jinguissl.live

import std.collection.ArrayList

public class ContractTls13IncrementalServerStartRequest {
    public let transport: ContractAcceptedTransportDescriptor
    public let plan: ContractHttpServerAttachPlan
    public let serverKeyExchangePrivate: Array<Byte>
    public let policy: ContractTlsHttpNegotiationPolicy
    public let pendingBytes: Array<Byte>
    public let incomingBytes: Array<Byte>

    public init(
        transport: ContractAcceptedTransportDescriptor,
        plan: ContractHttpServerAttachPlan,
        serverKeyExchangePrivate: Array<Byte>,
        policy!: ContractTlsHttpNegotiationPolicy = ContractTlsHttpNegotiationPolicy(),
        pendingBytes!: Array<Byte> = [],
        incomingBytes!: Array<Byte> = []
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
        this.pendingBytes = pendingBytes.clone()
        this.incomingBytes = incomingBytes.clone()
    }
}

public class ContractTls13IncrementalServerContinuation {
    public let selectedAlpn: String
    public let requestedServerName: String
    public let serverFlightRecords: Array<Array<Byte>>
    public let pendingBytes: Array<Byte>

    let state: ContractTls13IncrementalServerHandshakeState

    init(state: ContractTls13IncrementalServerHandshakeState) {
        this.selectedAlpn = state.negotiatedAlpn
        this.requestedServerName = state.requestedServerName
        this.serverFlightRecords = c192CloneRecords(state.initialHandshake.records)
        this.pendingBytes = state.pendingBytes.clone()
        this.state = state
    }
}

public class ContractTls13IncrementalServerStartResult {
    public let continuation: ContractTls13IncrementalServerContinuation
    public let records: Array<Array<Byte>>

    public init(continuation: ContractTls13IncrementalServerContinuation) {
        this.continuation = continuation
        this.records = c192CloneRecords(continuation.serverFlightRecords)
    }
}

public class ContractTls13IncrementalServerStartOutcome {
    public let ok: Bool
    public let status: ContractTls13IncrementalHandshakeStatus
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let result: ?ContractTls13IncrementalServerStartResult
    public let peerAlert: ?ContractTlsAlertMessage
    public let pendingBytes: Array<Byte>
    public let needBytes: Int64
    public let alertBytes: Array<Byte>

    public init(
        ok: Bool,
        status: ContractTls13IncrementalHandshakeStatus,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        result!: ?ContractTls13IncrementalServerStartResult = None,
        peerAlert!: ?ContractTlsAlertMessage = None,
        pendingBytes!: Array<Byte> = [],
        needBytes!: Int64 = 0,
        alertBytes!: Array<Byte> = []
    ) {
        if (message.trimAscii().size == 0 || needBytes < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server start outcome is invalid"
            )
        }
        if (ok && status != ContractTls13IncrementalHandshakeStatus.RecordsReady) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server start success must be RECORDS_READY"
            )
        }
        if (ok && result.isNone()) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server start success requires a result"
            )
        }
        if (!ok && result.isSome()) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server start failure must not carry a result"
            )
        }
        this.ok = ok
        this.status = status
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.result = result
        this.peerAlert = peerAlert
        this.pendingBytes = pendingBytes.clone()
        this.needBytes = needBytes
        this.alertBytes = alertBytes.clone()
    }
}

public class ContractTls13IncrementalServerFinishRequest {
    public let continuation: ContractTls13IncrementalServerContinuation
    public let pendingBytes: Array<Byte>
    public let incomingBytes: Array<Byte>

    public init(
        continuation: ContractTls13IncrementalServerContinuation,
        pendingBytes: Array<Byte>,
        incomingBytes: Array<Byte>
    ) {
        this.continuation = continuation
        this.pendingBytes = pendingBytes.clone()
        this.incomingBytes = incomingBytes.clone()
    }
}

public class ContractTls13IncrementalServerFinishOutcome {
    public let ok: Bool
    public let status: ContractTls13IncrementalHandshakeStatus
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let runtime: ?ContractTls13IncrementalServerReadyRuntime
    public let peerAlert: ?ContractTlsAlertMessage
    public let pendingBytes: Array<Byte>
    public let needBytes: Int64
    public let alertBytes: Array<Byte>

    public init(
        ok: Bool,
        status: ContractTls13IncrementalHandshakeStatus,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        runtime!: ?ContractTls13IncrementalServerReadyRuntime = None,
        peerAlert!: ?ContractTlsAlertMessage = None,
        pendingBytes!: Array<Byte> = [],
        needBytes!: Int64 = 0,
        alertBytes!: Array<Byte> = []
    ) {
        if (message.trimAscii().size == 0 || needBytes < 0) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server finish outcome is invalid"
            )
        }
        if (ok && status != ContractTls13IncrementalHandshakeStatus.Completed) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server finish success must be COMPLETED"
            )
        }
        if (ok && runtime.isNone()) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server finish success requires a runtime"
            )
        }
        if (!ok && runtime.isSome()) {
            throw ContractException(
                ContractErrorCode.BadInput,
                "TLS1.3 incremental server finish failure must not carry a runtime"
            )
        }
        this.ok = ok
        this.status = status
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.runtime = runtime
        this.peerAlert = peerAlert
        this.pendingBytes = pendingBytes.clone()
        this.needBytes = needBytes
        this.alertBytes = alertBytes.clone()
    }
}

public func contractTryTls13StartIncrementalHttpServerHandshake(
    request: ContractTls13IncrementalServerStartRequest
): ContractTls13IncrementalServerStartOutcome {
    let collected = contractTls13CollectIncrementalHandshakeRecords(
        request.pendingBytes,
        request.incomingBytes
    )
    let outcome = contractTryTls13AcceptIncrementalServerClientHello(
        request.transport,
        request.plan,
        request.serverKeyExchangePrivate,
        collected,
        policy: request.policy
    )
    if (let Some(state) <- outcome.result) {
        let continuation = ContractTls13IncrementalServerContinuation(state)
        return ContractTls13IncrementalServerStartOutcome(
            true,
            ContractTls13IncrementalHandshakeStatus.RecordsReady,
            "TLS1.3 server flight records are ready for caller write",
            result: Some(ContractTls13IncrementalServerStartResult(continuation)),
            pendingBytes: continuation.pendingBytes
        )
    }
    ContractTls13IncrementalServerStartOutcome(
        false,
        outcome.status,
        outcome.message,
        code: outcome.code,
        igniteCode: c192IgniteCode(outcome.code),
        peerAlert: outcome.peerAlert,
        pendingBytes: outcome.pendingBytes,
        needBytes: outcome.needBytes,
        alertBytes: outcome.alertOutput
    )
}

public func contractTryTls13FinishIncrementalHttpServerHandshake(
    request: ContractTls13IncrementalServerFinishRequest
): ContractTls13IncrementalServerFinishOutcome {
    let collected = contractTls13CollectIncrementalHandshakeRecords(
        request.pendingBytes,
        request.incomingBytes,
        maxRecords: 1
    )
    let outcome = contractTryTls13VerifyIncrementalServerClientFinished(
        request.continuation.state,
        collected
    )
    if (let Some(runtime) <- outcome.result) {
        return ContractTls13IncrementalServerFinishOutcome(
            true,
            ContractTls13IncrementalHandshakeStatus.Completed,
            outcome.message,
            runtime: Some(runtime),
            pendingBytes: outcome.pendingBytes
        )
    }
    ContractTls13IncrementalServerFinishOutcome(
        false,
        outcome.status,
        outcome.message,
        code: outcome.code,
        igniteCode: c192IgniteCode(outcome.code),
        peerAlert: outcome.peerAlert,
        pendingBytes: outcome.pendingBytes,
        needBytes: outcome.needBytes,
        alertBytes: outcome.alertOutput
    )
}

private func c192IgniteCode(code: ?ContractErrorCode): ?ContractIgniteCryptoErrorCode {
    match (code) {
        case Some(value) => Some(contractMapToIgniteCryptoErrorCode(value))
        case None => None
    }
}

private func c192CloneRecords(records: Array<Array<Byte>>): Array<Array<Byte>> {
    let out = ArrayList<Array<Byte>>()
    for (record in records) {
        out.add(record.clone())
    }
    out.toArray()
}
