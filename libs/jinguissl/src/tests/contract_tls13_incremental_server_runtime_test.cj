package jinguissl.tests

import std.collection.ArrayList
import std.fs.File
import jinguissl.live.*

private let C187_LIVE_SOURCE_ROOT: String = ""
private let C187_TEST_HOST: String = "www." + "example.com"

private class C187Fixture {
    let transport: ContractAcceptedTransportDescriptor
    let plan: ContractHttpServerAttachPlan
    let policy: ContractTlsHttpNegotiationPolicy
    let trust: ContractHttpClientTlsTrustRequest
    let clientHello: ContractTls13HttpClientHelloX25519
    let serverPrivateKey: Array<Byte>

    init(
        transport: ContractAcceptedTransportDescriptor,
        plan: ContractHttpServerAttachPlan,
        policy: ContractTlsHttpNegotiationPolicy,
        trust: ContractHttpClientTlsTrustRequest,
        clientHello: ContractTls13HttpClientHelloX25519,
        serverPrivateKey: Array<Byte>
    ) {
        this.transport = transport
        this.plan = plan
        this.policy = policy
        this.trust = trust
        this.clientHello = clientHello
        this.serverPrivateKey = serverPrivateKey.clone()
    }
}

private func c187ReadText(path: String): String {
    String.fromUtf8(File.readFrom("${C187_LIVE_SOURCE_ROOT}${path}"))
}

private func c187IncrementalBytes(size: Int64, start!: Int64 = 0): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i: Int64 = 0
    while (i < size) {
        out[i] = UInt8((start + i) & 0xff)
        i += 1
    }
    out
}

private func c187Concat(parts: Array<Array<Byte>>): Array<Byte> {
    let out = ArrayList<Byte>()
    for (part in parts) {
        for (b in part) {
            out.add(b)
        }
    }
    out.toArray()
}

private func c187TamperLastByte(input: Array<Byte>): Array<Byte> {
    let out = input.clone()
    let index = out.size - 1
    if (out[index] == UInt8(0)) {
        out[index] = UInt8(1)
    } else {
        out[index] = UInt8(0)
    }
    out
}

private func c187BuildFixture(alpn: String): C187Fixture {
    let leafPem = c187ReadText("testdata/x509/policy_leaf.pem")
    let intermediatePem = c187ReadText("testdata/x509/policy_intermediate.pem")
    let rootPem = c187ReadText("testdata/x509/policy_root.pem")
    let certChainPem = "${leafPem}\n${intermediatePem}"
    let leafKeyPem = c187ReadText("testdata/x509/policy_leaf_key_pkcs8.pem")
    let policy = ContractTlsHttpNegotiationPolicy(
        requireServerName: true,
        allowedServerNames: [C187_TEST_HOST],
        alpnPreference: [alpn]
    )
    let plan = contractPlanHttpServerAttachRequest(
        ContractHttpServerLibraryStartupRequest(
            ContractHttpServerTlsConfigRequest(
                certChainPem,
                leafKeyPem,
                alpnProtocols: [alpn],
                requireHttp2Alpn: alpn == "h2"
            ),
            aesBackendHint: "shim"
        )
    )
    let clientHello = contractTls13BuildHttpClientHelloX25519(
        C187_TEST_HOST,
        alpnProtocols: [alpn],
        clientPrivateKey: Some(c187IncrementalBytes(32, start: 48))
    )
    let trust = ContractHttpClientTlsTrustRequest(
        rootPem,
        intermediatesPemBundle: intermediatePem,
        hostname: C187_TEST_HOST,
        policy: policy
    )
    C187Fixture(
        ContractAcceptedTransportDescriptor(
            "c187-${alpn}",
            localEndpoint: "127.0.0.1:443",
            remoteEndpoint: "127.0.0.1:55443"
        ),
        plan,
        policy,
        trust,
        clientHello,
        c187IncrementalBytes(32, start: 80)
    )
}

private func c187ClientHelloWire(fixture: C187Fixture): Array<Byte> {
    let hello = fixture.clientHello.encodedClientHello
    let split = Int64(17)
    c187Concat([
        contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            hello[0..split]
        ),
        contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            hello[split..]
        )
    ])
}

private func c187OpenServerState(
    fixture: C187Fixture
): ContractTls13IncrementalServerHandshakeState {
    let wire = c187ClientHelloWire(fixture)
    let collected = contractTls13CollectIncrementalHandshakeRecords([], wire)
    contractTls13AcceptIncrementalServerClientHello(
        fixture.transport,
        fixture.plan,
        fixture.serverPrivateKey,
        collected,
        policy: fixture.policy
    )
}

private func c187RunClientAgainstServerFlight(
    fixture: C187Fixture,
    state: ContractTls13IncrementalServerHandshakeState
): ContractTls13WireDerivedClientHandshakeRuntime {
    let serverRecords = contractTls13CollectIncrementalHandshakeRecords(
        [],
        c187Concat(state.initialHandshake.records)
    )
    contractTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
        fixture.clientHello,
        fixture.trust,
        serverRecords
    )
}

private func c187CompleteHandshakeAndApplicationRoundTrip(alpn: String): Unit {
    let fixture = c187BuildFixture(alpn)
    let clientHelloWire = c187ClientHelloWire(fixture)

    let partialRecord = contractTls13CollectIncrementalHandshakeRecords([], clientHelloWire[0..3])
    let needMore = contractTryTls13AcceptIncrementalServerClientHello(
        fixture.transport,
        fixture.plan,
        fixture.serverPrivateKey,
        partialRecord,
        policy: fixture.policy
    )
    @Assert(needMore.ok, false)
    @Assert(needMore.status.toString(), "NEED_MORE_BYTES")

    let completeRecords = contractTls13CollectIncrementalHandshakeRecords(
        partialRecord.pendingBytes,
        clientHelloWire[3..]
    )
    let accepted = contractTryTls13AcceptIncrementalServerClientHelloRequest(
        ContractTls13IncrementalServerClientHelloRequest(
            fixture.transport,
            fixture.plan,
            fixture.serverPrivateKey,
            completeRecords,
            policy: fixture.policy
        )
    )
    @Assert(accepted.ok, true)
    @Assert(accepted.status.toString(), "COMPLETED")
    let state = match (accepted.result) {
        case Some(value) => value
        case None => throw ContractException(ContractErrorCode.InternalError, "C187 accepted state missing")
    }
    @Assert(state.negotiatedAlpn, alpn)
    @Assert(state.requestedServerName, C187_TEST_HOST)
    @Assert(state.initialHandshake.recordCount, Int64(5))

    let client = c187RunClientAgainstServerFlight(fixture, state)
    @Assert(client.runtime.secureSessionReady, true)
    @Assert(client.runtime.result.selectedAlpn, alpn)

    let requestPayload = "request-${alpn}".toArray()
    let applicationRecord = client.runtime.channelSet.clientChannel.sealApplicationData(requestPayload)
    let partialNextRecord = [UInt8(23), UInt8(3)]
    let clientWire = c187Concat([
        client.clientFinished.encodedRecord,
        applicationRecord,
        partialNextRecord
    ])
    let collectedClientFlight = contractTls13CollectIncrementalHandshakeRecords([], clientWire)
    @Assert(collectedClientFlight.records.size, Int64(2))
    @Assert(collectedClientFlight.pendingBytes, partialNextRecord)

    let finished = contractTryTls13VerifyIncrementalServerClientFinishedRequest(
        ContractTls13IncrementalServerFinishedRequest(state, collectedClientFlight)
    )
    @Assert(finished.ok, true)
    @Assert(finished.status.toString(), "COMPLETED")
    let server = match (finished.result) {
        case Some(value) => value
        case None => throw ContractException(ContractErrorCode.InternalError, "C187 server runtime missing")
    }
    @Assert(server.secureSessionReady, true)
    @Assert(server.negotiatedAlpn, alpn)
    @Assert(server.pendingApplicationRecords.size, Int64(1))
    @Assert(server.pendingBytes, partialNextRecord)
    @Assert(
        server.session.recordChannel.openApplicationData(server.pendingApplicationRecords[0]),
        requestPayload
    )

    let responsePayload = "response-${alpn}".toArray()
    let responseRecord = server.session.recordChannel.sealApplicationData(responsePayload)
    @Assert(
        client.runtime.channelSet.clientChannel.openApplicationData(responseRecord),
        responsePayload
    )
}

@Test
public class ContractTls13IncrementalServerRuntimeTestSuite {
    @TestCase
    public func testIncrementalServerCompletesH2HandshakeAndApplicationData(): Unit {
        c187CompleteHandshakeAndApplicationRoundTrip("h2")
    }

    @TestCase
    public func testIncrementalServerCompletesHttp11HandshakeAndApplicationData(): Unit {
        c187CompleteHandshakeAndApplicationRoundTrip("http/1.1")
    }

    @TestCase
    public func testIncrementalServerSurfacesPeerAlertMalformedAndPolicyRejection(): Unit {
        let fixture = c187BuildFixture("h2")
        let peerAlert = contractTls13CollectIncrementalHandshakeRecords(
            [],
            contractTlsEncodeAlertRecord(
                ContractTlsVersion.Tls13,
                ContractTlsAlertLevel.AlertFatal,
                ContractTlsAlertDescription.AlertHandshakeFailure
            )
        )
        let peerOutcome = contractTryTls13AcceptIncrementalServerClientHello(
            fixture.transport,
            fixture.plan,
            fixture.serverPrivateKey,
            peerAlert,
            policy: fixture.policy
        )
        @Assert(peerOutcome.ok, false)
        @Assert(peerOutcome.status.toString(), "PEER_ALERT")

        let malformed = contractTls13CollectIncrementalHandshakeRecords(
            [],
            contractTlsEncodePlaintextRecord(
                ContractTlsVersion.Tls13,
                ContractTlsRecordContentType.Handshake,
                [UInt8(2), UInt8(0), UInt8(0), UInt8(0)]
            )
        )
        let malformedOutcome = contractTryTls13AcceptIncrementalServerClientHello(
            fixture.transport,
            fixture.plan,
            fixture.serverPrivateKey,
            malformed,
            policy: fixture.policy
        )
        @Assert(malformedOutcome.ok, false)
        @Assert(malformedOutcome.status.toString(), "MALFORMED")
        @Assert(malformedOutcome.alertOutput.size > 0, true)
        @Assert(malformedOutcome.alertOutput[0], UInt8(21))

        let policyRejected = contractTryTls13AcceptIncrementalServerClientHello(
            fixture.transport,
            fixture.plan,
            fixture.serverPrivateKey,
            contractTls13CollectIncrementalHandshakeRecords([], c187ClientHelloWire(fixture)),
            policy: ContractTlsHttpNegotiationPolicy(
                requireServerName: true,
                allowedServerNames: ["other.example.com"],
                alpnPreference: ["h2"]
            )
        )
        @Assert(policyRejected.ok, false)
        @Assert(policyRejected.status.toString(), "POLICY_REJECTED")
        @Assert(policyRejected.alertOutput.size > 0, true)
    }

    @TestCase
    public func testIncrementalServerRejectsBadFinishedAndReturnsProtectedAlert(): Unit {
        let fixture = c187BuildFixture("h2")
        let state = c187OpenServerState(fixture)
        let client = c187RunClientAgainstServerFlight(fixture, state)
        let badFinished = contractTls13CollectIncrementalHandshakeRecords(
            [],
            c187TamperLastByte(client.clientFinished.encodedRecord)
        )
        let outcome = contractTryTls13VerifyIncrementalServerClientFinished(state, badFinished)
        @Assert(outcome.ok, false)
        @Assert(outcome.status.toString(), "VERIFICATION_FAILED")
        @Assert(outcome.alertOutput.size > 0, true)
        @Assert(outcome.alertOutput[0], UInt8(23))
    }

    @TestCase
    public func testIncrementalServerFinishedNeedMoreAndUnexpectedRecordStayDistinct(): Unit {
        let fixture = c187BuildFixture("h2")
        let state = c187OpenServerState(fixture)
        let needMoreRecords = contractTls13CollectIncrementalHandshakeRecords(
            [],
            [UInt8(23), UInt8(3), UInt8(3)]
        )
        let needMore = contractTryTls13VerifyIncrementalServerClientFinished(state, needMoreRecords)
        @Assert(needMore.ok, false)
        @Assert(needMore.status.toString(), "NEED_MORE_BYTES")

        let unexpected = contractTls13CollectIncrementalHandshakeRecords(
            [],
            contractTlsEncodePlaintextRecord(
                ContractTlsVersion.Tls13,
                ContractTlsRecordContentType.Handshake,
                fixture.clientHello.encodedClientHello
            )
        )
        let malformed = contractTryTls13VerifyIncrementalServerClientFinished(state, unexpected)
        @Assert(malformed.ok, false)
        @Assert(malformed.status.toString(), "MALFORMED")
        @Assert(malformed.alertOutput.size > 0, true)
    }

    @TestCase
    public func testConsumerCompatibilityStartFinishCompletesH2Handshake(): Unit {
        let fixture = c187BuildFixture("h2")
        let startOutcome = contractTryTls13StartIncrementalHttpServerHandshake(
            ContractTls13IncrementalServerStartRequest(
                fixture.transport,
                fixture.plan,
                fixture.serverPrivateKey,
                policy: fixture.policy,
                incomingBytes: c187ClientHelloWire(fixture)
            )
        )
        @Assert(startOutcome.ok, true)
        @Assert(startOutcome.status.toString(), "RECORDS_READY")
        let start = match (startOutcome.result) {
            case Some(value) => value
            case None => throw ContractException(ContractErrorCode.InternalError, "C192 start result missing")
        }
        @Assert(start.continuation.selectedAlpn, "h2")
        @Assert(start.records.size, Int64(5))

        let client = contractTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
            fixture.trust,
            contractTls13CollectIncrementalHandshakeRecords([], c187Concat(start.records))
        )
        let applicationRecord = client.runtime.channelSet.clientChannel.sealApplicationData(
            "compat-request".toArray()
        )
        let finishOutcome = contractTryTls13FinishIncrementalHttpServerHandshake(
            ContractTls13IncrementalServerFinishRequest(
                start.continuation,
                start.continuation.pendingBytes,
                c187Concat([client.clientFinished.encodedRecord, applicationRecord])
            )
        )
        @Assert(finishOutcome.ok, true)
        @Assert(finishOutcome.status.toString(), "COMPLETED")
        let runtime = match (finishOutcome.runtime) {
            case Some(value) => value
            case None => throw ContractException(ContractErrorCode.InternalError, "C192 runtime missing")
        }
        @Assert(runtime.secureSessionReady, true)
        @Assert(runtime.selectedAlpn, "h2")
        @Assert(finishOutcome.pendingBytes, applicationRecord)
    }

    @TestCase
    public func testConsumerCompatibilityMapsBadFinishedToProtectedAlert(): Unit {
        let fixture = c187BuildFixture("http/1.1")
        let startOutcome = contractTryTls13StartIncrementalHttpServerHandshake(
            ContractTls13IncrementalServerStartRequest(
                fixture.transport,
                fixture.plan,
                fixture.serverPrivateKey,
                policy: fixture.policy,
                incomingBytes: contractTlsEncodePlaintextRecord(
                    ContractTlsVersion.Tls13,
                    ContractTlsRecordContentType.Handshake,
                    fixture.clientHello.encodedClientHello
                )
            )
        )
        let start = match (startOutcome.result) {
            case Some(value) => value
            case None => throw ContractException(ContractErrorCode.InternalError, "C192 start result missing")
        }
        let client = contractTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
            fixture.trust,
            contractTls13CollectIncrementalHandshakeRecords([], c187Concat(start.records))
        )
        let finishOutcome = contractTryTls13FinishIncrementalHttpServerHandshake(
            ContractTls13IncrementalServerFinishRequest(
                start.continuation,
                start.continuation.pendingBytes,
                c187TamperLastByte(client.clientFinished.encodedRecord)
            )
        )
        @Assert(finishOutcome.ok, false)
        @Assert(finishOutcome.status.toString(), "VERIFICATION_FAILED")
        @Assert(finishOutcome.alertBytes.size > 0, true)
        @Assert(finishOutcome.alertBytes[0], UInt8(23))
        @Assert(finishOutcome.igniteCode.isSome(), true)
    }
}
