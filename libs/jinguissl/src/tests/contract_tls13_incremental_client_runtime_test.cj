package jinguissl.tests

import std.collection.ArrayList
import std.fs.File
import jinguissl.live.*

private let LIVE_SOURCE_ROOT: String = ""
private let TEST_HOST_WWW: String = "www." + "example.com"

private class IncrementalClientRuntimeFixture {
    let clientHello: ContractTls13HttpClientHelloX25519
    let serverFlight: ContractTls13HttpServerFlight
    let trust: ContractHttpClientTlsTrustRequest

    init(
        clientHello: ContractTls13HttpClientHelloX25519,
        serverFlight: ContractTls13HttpServerFlight,
        trust: ContractHttpClientTlsTrustRequest
    ) {
        this.clientHello = clientHello
        this.serverFlight = serverFlight
        this.trust = trust
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

private func appDataRecord(label: String): Array<Byte> {
    contractTlsEncodePlaintextRecord(
        ContractTlsVersion.Tls13,
        ContractTlsRecordContentType.ApplicationData,
        label.toArray()
    )
}

private func buildRuntimeFixture(): IncrementalClientRuntimeFixture {
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
    let clientHello = contractTls13BuildHttpClientHelloX25519(
        serverName,
        alpnProtocols: ["h2", "http/1.1"],
        clientPrivateKey: Some(incrementalBytes(32, start: 48))
    )
    let serverFlight = contractTls13BuildHttpServerFlightX25519(
        clientHello.encodedClientHello,
        incrementalBytes(32, start: 80),
        certChainPem,
        leafKeyPem,
        policy: policy
    )
    let trust = ContractHttpClientTlsTrustRequest(
        rootPem,
        intermediatesPemBundle: intermediatePem,
        hostname: serverName,
        policy: policy
    )
    IncrementalClientRuntimeFixture(clientHello, serverFlight, trust)
}

private func buildServerFlightRecords(serverFlight: ContractTls13HttpServerFlight): Array<Array<Byte>> {
    [
        contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            serverFlight.serverHello
        ),
        appDataRecord("encrypted-extensions-envelope"),
        appDataRecord("certificate-envelope"),
        appDataRecord("certificate-verify-envelope"),
        appDataRecord("finished-envelope")
    ]
}

private func collectServerFlightRecords(serverFlight: ContractTls13HttpServerFlight): ContractTls13IncrementalHandshakeResult {
    contractTls13CollectIncrementalHandshakeRecords(
        [],
        concatRecords(buildServerFlightRecords(serverFlight))
    )
}

@Test
public class ContractTls13IncrementalClientRuntimeTestSuite {
    @TestCase
    public func testIncrementalServerFlightOpensVerifiedRuntime(): Unit {
        let fixture = buildRuntimeFixture()
        let collected = collectServerFlightRecords(fixture.serverFlight)
        let outcome = contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            collected
        )

        @Assert(outcome.ok, true)
        @Assert(outcome.status.toString(), "COMPLETED")
        @Assert(outcome.recordsObserved, Int64(5))
        if (let Some(runtime) <- outcome.runtime) {
            @Assert(runtime.status.toString(), "READY")
            @Assert(runtime.secureSessionReady, true)
            @Assert(runtime.result.selectedAlpn, "h2")
            @Assert(runtime.result.requestedServerName, TEST_HOST_WWW)
            @Assert(runtime.channelSet.clientChannel.version.toString(), "TLS1.3")
        } else {
            @Fail("incremental client runtime outcome should carry runtime")
        }
    }

    @TestCase
    public func testIncrementalServerFlightRequestWrapper(): Unit {
        let fixture = buildRuntimeFixture()
        let collected = collectServerFlightRecords(fixture.serverFlight)
        let request = ContractTls13IncrementalClientRuntimeRequest(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            collected
        )
        let runtime = contractTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlightRequest(request)

        @Assert(runtime.status.toString(), "READY")
        @Assert(runtime.result.selectedAlpn, "h2")
        @Assert(runtime.result.chainLength, Int64(3))
    }

    @TestCase
    public func testIncrementalRuntimeWaitsForMoreBytes(): Unit {
        let fixture = buildRuntimeFixture()
        let serverHelloRecord = contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            fixture.serverFlight.serverHello
        )
        let collected = contractTls13CollectIncrementalHandshakeRecords([], serverHelloRecord[0..3])
        let outcome = contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            collected
        )

        @Assert(outcome.ok, false)
        @Assert(outcome.status.toString(), "NEED_MORE_BYTES")
        @Assert(outcome.needBytes, Int64(2))
        if (let Some(_runtime) <- outcome.runtime) {
            @Fail("need-more outcome must not carry runtime")
        }
    }

    @TestCase
    public func testIncrementalRuntimeSurfacesPeerAlert(): Unit {
        let fixture = buildRuntimeFixture()
        let alertRecord = contractTlsEncodeAlertRecord(
            ContractTlsVersion.Tls13,
            ContractTlsAlertLevel.AlertFatal,
            ContractTlsAlertDescription.AlertHandshakeFailure
        )
        let collected = contractTls13CollectIncrementalHandshakeRecords([], alertRecord)
        let outcome = contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            collected
        )

        @Assert(outcome.ok, false)
        @Assert(outcome.status.toString(), "PEER_ALERT")
        if (let Some(alert) <- outcome.peerAlert) {
            @Assert(alert.description.toString(), "HANDSHAKE_FAILURE")
        } else {
            @Fail("peer alert outcome should carry alert")
        }
    }

    @TestCase
    public func testIncrementalRuntimeSurfacesMalformedRecord(): Unit {
        let fixture = buildRuntimeFixture()
        let malformed = [
            UInt8(0xff),
            UInt8(0x03),
            UInt8(0x04),
            UInt8(0x00),
            UInt8(0x00)
        ]
        let collected = contractTls13CollectIncrementalHandshakeRecords([], malformed)
        let outcome = contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            collected
        )

        @Assert(outcome.ok, false)
        @Assert(outcome.status.toString(), "MALFORMED")
        if (let Some(code) <- outcome.code) {
            @Assert(code.toString(), "BAD_INPUT")
        } else {
            @Fail("malformed outcome should carry code")
        }
    }

    @TestCase
    public func testIncrementalRuntimeRejectsServerHelloMismatch(): Unit {
        let fixture = buildRuntimeFixture()
        let badServerHello = fixture.serverFlight.serverHello.clone()
        if (badServerHello[0] == UInt8(0)) {
            badServerHello[0] = UInt8(1)
        } else {
            badServerHello[0] = UInt8(0)
        }
        let records = [
            contractTlsEncodePlaintextRecord(
                ContractTlsVersion.Tls13,
                ContractTlsRecordContentType.Handshake,
                badServerHello
            ),
            appDataRecord("encrypted-extensions-envelope"),
            appDataRecord("certificate-envelope"),
            appDataRecord("certificate-verify-envelope"),
            appDataRecord("finished-envelope")
        ]
        let collected = contractTls13CollectIncrementalHandshakeRecords([], concatRecords(records))
        let outcome = contractTryTls13OpenHttpClientVerifiedSessionRuntimeFromIncrementalServerFlight(
            fixture.clientHello,
            fixture.serverFlight,
            fixture.trust,
            collected
        )

        @Assert(outcome.ok, false)
        @Assert(outcome.status.toString(), "VERIFICATION_FAILED")
        if (let Some(code) <- outcome.code) {
            @Assert(code.toString(), "VERIFY_FAILED")
        } else {
            @Fail("mismatch outcome should carry code")
        }
    }
}
