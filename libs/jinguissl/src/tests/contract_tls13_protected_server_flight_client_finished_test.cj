package jinguissl.tests

import std.collection.ArrayList
import std.fs.File
import jinguissl.live.*

private let LIVE_SOURCE_ROOT: String = ""
private let TEST_HOST_WWW: String = "www." + "example.com"

private class ProtectedServerFlightFixture {
    let clientHello: ContractTls13HttpClientHelloX25519
    let serverFlight: ContractTls13HttpServerFlight
    let trust: ContractHttpClientTlsTrustRequest
    let records: Array<Array<Byte>>

    init(
        clientHello: ContractTls13HttpClientHelloX25519,
        serverFlight: ContractTls13HttpServerFlight,
        trust: ContractHttpClientTlsTrustRequest,
        records: Array<Array<Byte>>
    ) {
        this.clientHello = clientHello
        this.serverFlight = serverFlight
        this.trust = trust
        this.records = records
    }
}

private func readText(path: String): String {
    String.fromUtf8(File.readFrom("${LIVE_SOURCE_ROOT}${path}"))
}

private func incrementalBytes(size: Int64, start!: Int64 = 0): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i = 0
    while (i < size) {
        out[i] = UInt8((start + i) & 0xff)
        i += 1
    }
    out
}

private func concatRecords(records: Array<Array<Byte>>): Array<Byte> {
    let out = ArrayList<Byte>()
    for (record in records) {
        for (b in record) {
            out.add(b)
        }
    }
    out.toArray()
}

private func buildProtectedFixture(): ProtectedServerFlightFixture {
    let serverName = TEST_HOST_WWW
    let leafPem = readText("testdata/x509/policy_leaf.pem")
    let intermediatePem = readText("testdata/x509/policy_intermediate.pem")
    let rootPem = readText("testdata/x509/policy_root.pem")
    let certChainPem = "${leafPem}\n${intermediatePem}"
    let leafKeyPem = readText("testdata/x509/policy_leaf_key_pkcs8.pem")
    let policy = ContractTlsHttpNegotiationPolicy(
        requireServerName: true,
        allowedServerNames: [serverName],
        alpnPreference: ["h2", "http/1.1"]
    )
    let plan = contractPlanHttpServerAttachRequest(
        ContractHttpServerLibraryStartupRequest(
            ContractHttpServerTlsConfigRequest(
                certChainPem,
                leafKeyPem,
                alpnProtocols: ["h2", "http/1.1"],
                requireHttp2Alpn: true
            ),
            aesBackendHint: "shim"
        )
    )
    let clientHello = contractTls13BuildHttpClientHelloX25519(
        serverName,
        alpnProtocols: ["h2", "http/1.1"],
        clientPrivateKey: Some(incrementalBytes(32, start: 48))
    )
    let session = contractAttachStableAcceptedTransportTls13X25519(
        ContractAcceptedTransportDescriptor(
            "c186-protected-server-flight",
            localEndpoint: "127.0.0.1:443",
            remoteEndpoint: "127.0.0.1:55443"
        ),
        plan,
        clientHello.encodedClientHello,
        incrementalBytes(32, start: 80),
        policy: policy
    )
    let trust = ContractHttpClientTlsTrustRequest(
        rootPem,
        intermediatesPemBundle: intermediatePem,
        hostname: serverName,
        policy: policy
    )
    ProtectedServerFlightFixture(
        clientHello,
        session.result.serverFlight,
        trust,
        session.initialHandshake.records
    )
}

private func collectProtectedRecords(fixture: ProtectedServerFlightFixture): ContractTls13IncrementalHandshakeResult {
    let wire = concatRecords(fixture.records)
    contractTls13CollectIncrementalHandshakeRecords(wire[0..3], wire[3..])
}

private func tamperByte(input: Array<Byte>, offsetFromEnd!: Int64 = 1): Array<Byte> {
    let out = input.clone()
    let index = out.size - 1 - offsetFromEnd
    if (out[index] == UInt8(0)) {
        out[index] = UInt8(1)
    } else {
        out[index] = UInt8(0)
    }
    out
}

@Test
public class ContractTls13ProtectedServerFlightClientFinishedTestSuite {
    @TestCase
    public func testProtectedServerFlightOpensRuntimeAndClientFinishedRecord(): Unit {
        let fixture = buildProtectedFixture()
        let collected = collectProtectedRecords(fixture)
        let outcome = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            collected
        )

        @Assert(outcome.ok, true)
        @Assert(outcome.status.toString(), "COMPLETED")
        @Assert(outcome.recordsObserved, Int64(5))
        if (let Some(result) <- outcome.result) {
            @Assert(result.runtime.status.toString(), "READY")
            @Assert(result.runtime.result.selectedAlpn, "h2")
            @Assert(result.mappedFlight.decodedProtectedRecordCount, Int64(4))
            @Assert(result.mappedFlight.encryptedExtensions, fixture.serverFlight.encryptedExtensions)
            @Assert(result.mappedFlight.finishedHandshake, fixture.serverFlight.finishedHandshake)
            @Assert(result.clientFinished.deferred, false)
            @Assert(result.clientFinished.writeSurface, "tls13-client-finished-record")
            @Assert(result.clientFinished.encodedFinishedHandshake[0], UInt8(20))
            @Assert(result.clientFinished.encodedRecord[0], UInt8(23))
        } else {
            @Fail("protected server flight outcome should carry result")
        }
    }

    @TestCase
    public func testProtectedServerFlightRequestWrapper(): Unit {
        let fixture = buildProtectedFixture()
        let collected = collectProtectedRecords(fixture)
        let result = contractTls13OpenHttpClientRuntimeFromProtectedServerFlightRequest(
            ContractTls13ProtectedServerFlightRequest(
                fixture.clientHello,
                fixture.serverFlight,
                fixture.trust,
                collected
            )
        )

        @Assert(result.runtime.secureSessionReady, true)
        @Assert(result.clientFinished.encodedRecord[0], UInt8(23))
        @Assert(result.mappedFlight.certificateVerifyHandshake, fixture.serverFlight.certificateVerifyHandshake)
    }

    @TestCase
    public func testProtectedServerFlightRejectsBadProtectedRecordShape(): Unit {
        let fixture = buildProtectedFixture()
        let records = fixture.records.clone()
        records[2] = tamperByte(records[2])
        let collected = contractTls13CollectIncrementalHandshakeRecords([], concatRecords(records))
        let outcome = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            collected
        )

        @Assert(outcome.ok, false)
        @Assert(outcome.message.contains("TLS record open failed"), true)
        if (let Some(code) <- outcome.code) {
            @Assert(code.toString().size > 0, true)
        } else {
            @Fail("bad protected record outcome should carry code")
        }
    }

    @TestCase
    public func testProtectedServerFlightRejectsBadFinishedPayload(): Unit {
        let fixture = buildProtectedFixture()
        let badFinished = tamperByte(fixture.serverFlight.finishedHandshake, offsetFromEnd: 0)
        let expected = ContractTls13HttpServerFlight(
            fixture.serverFlight.serverHello,
            fixture.serverFlight.encryptedExtensions,
            fixture.serverFlight.certificateHandshake,
            fixture.serverFlight.certificateVerifyHandshake,
            badFinished,
            fixture.serverFlight.transcriptHash,
            selectedAlpn: fixture.serverFlight.selectedAlpn,
            requestedServerName: fixture.serverFlight.requestedServerName,
            acknowledgedServerName: fixture.serverFlight.acknowledgedServerName
        )
        let collected = collectProtectedRecords(fixture)
        let outcome = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
            fixture.clientHello,
            expected,
            fixture.trust,
            collected
        )

        @Assert(outcome.ok, false)
        @Assert(outcome.status.toString(), "VERIFICATION_FAILED")
        @Assert(outcome.message.contains("Finished payload does not match"), true)
    }

    @TestCase
    public func testProtectedServerFlightSurfacesTrustAndAlpnRejections(): Unit {
        let fixture = buildProtectedFixture()
        let collected = collectProtectedRecords(fixture)
        let hostnameRejected = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            ContractHttpClientTlsTrustRequest(
                fixture.trust.trustAnchorsPemBundle,
                intermediatesPemBundle: fixture.trust.intermediatesPemBundle,
                hostname: "wrong.example.com",
                policy: fixture.trust.policy
            ),
            collected
        )
        @Assert(hostnameRejected.ok, false)
        @Assert(hostnameRejected.status.toString(), "VERIFICATION_FAILED")

        let alpnRejected = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            ContractHttpClientTlsTrustRequest(
                fixture.trust.trustAnchorsPemBundle,
                intermediatesPemBundle: fixture.trust.intermediatesPemBundle,
                hostname: TEST_HOST_WWW,
                policy: ContractTlsHttpNegotiationPolicy(
                    requireServerName: true,
                    allowedServerNames: [TEST_HOST_WWW],
                    alpnPreference: ["http/1.1"]
                )
            ),
            collected
        )
        @Assert(alpnRejected.ok, false)
        @Assert(alpnRejected.status.toString(), "VERIFICATION_FAILED")
        @Assert(alpnRejected.message.contains("ALPN"), true)
    }

    @TestCase
    public func testProtectedServerFlightSurfacesCollectorTerminalStates(): Unit {
        let fixture = buildProtectedFixture()
        let needMore = contractTls13CollectIncrementalHandshakeRecords([], fixture.records[0][0..3])
        let needMoreOutcome = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            needMore
        )
        @Assert(needMoreOutcome.ok, false)
        @Assert(needMoreOutcome.status.toString(), "NEED_MORE_BYTES")

        let alert = contractTls13CollectIncrementalHandshakeRecords(
            [],
            contractTlsEncodeAlertRecord(
                ContractTlsVersion.Tls13,
                ContractTlsAlertLevel.AlertFatal,
                ContractTlsAlertDescription.AlertHandshakeFailure
            )
        )
        let alertOutcome = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            alert
        )
        @Assert(alertOutcome.ok, false)
        @Assert(alertOutcome.status.toString(), "PEER_ALERT")

        let malformed = contractTls13CollectIncrementalHandshakeRecords(
            [],
            [UInt8(0xff), UInt8(0x03), UInt8(0x04), UInt8(0x00), UInt8(0x00)]
        )
        let malformedOutcome = contractTryTls13OpenHttpClientRuntimeFromProtectedServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            malformed
        )
        @Assert(malformedOutcome.ok, false)
        @Assert(malformedOutcome.status.toString(), "MALFORMED")
    }
}
