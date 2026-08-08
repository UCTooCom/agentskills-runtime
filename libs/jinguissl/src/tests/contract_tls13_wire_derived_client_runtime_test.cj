package jinguissl.tests

import std.collection.ArrayList
import std.fs.File
import jinguissl.live.*
import jinguissl_core.crypto.tls.{tls13DeriveSecretsFromX25519ForCipherSuite, tls13ExtractServerX25519KeyShare}

private let LIVE_SOURCE_ROOT: String = ""
private let TEST_HOST_WWW: String = "www." + "example.com"

private class WireDerivedFixture {
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

private func tamperByte(input: Array<Byte>, offsetFromEnd!: Int64 = 0): Array<Byte> {
    let out = input.clone()
    let index = out.size - 1 - offsetFromEnd
    if (out[index] == UInt8(0)) {
        out[index] = UInt8(1)
    } else {
        out[index] = UInt8(0)
    }
    out
}

private func buildWireFixture(): WireDerivedFixture {
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
            "c188-wire-derived-client-runtime",
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
    WireDerivedFixture(
        clientHello,
        session.result.serverFlight,
        trust,
        session.initialHandshake.records
    )
}

private func collectRecords(records: Array<Array<Byte>>): ContractTls13IncrementalHandshakeResult {
    contractTls13CollectIncrementalHandshakeRecords([], concatRecords(records))
}

private func rebuildProtectedRecords(
    fixture: WireDerivedFixture,
    certificateVerifyOverride!: ?Array<Byte> = None,
    finishedOverride!: ?Array<Byte> = None
): Array<Array<Byte>> {
    let binding = contractTls13ResolveCipherBindingFromServerFlight(fixture.serverFlight)
    let serverPublicKey = tls13ExtractServerX25519KeyShare(fixture.serverFlight.serverHello)
    let secrets = tls13DeriveSecretsFromX25519ForCipherSuite(
        fixture.clientHello.clientPrivateKey,
        serverPublicKey,
        fixture.serverFlight.transcriptHash,
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
    let channel = contractTls13CreateServerRecordChannel(
        ContractTls13ApplicationKeyMaterial(
            clientHandshakeKey,
            clientHandshakeIv,
            serverHandshakeKey,
            serverHandshakeIv
        ),
        algorithm: binding.algorithm
    )
    let certificateVerify = match (certificateVerifyOverride) {
        case Some(value) => value
        case None => fixture.serverFlight.certificateVerifyHandshake
    }
    let finished = match (finishedOverride) {
        case Some(value) => value
        case None => fixture.serverFlight.finishedHandshake
    }
    [
        contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            fixture.serverFlight.serverHello
        ),
        channel.seal(ContractTlsRecordContentType.Handshake, fixture.serverFlight.encryptedExtensions),
        channel.seal(ContractTlsRecordContentType.Handshake, fixture.serverFlight.certificateHandshake),
        channel.seal(ContractTlsRecordContentType.Handshake, certificateVerify),
        channel.seal(ContractTlsRecordContentType.Handshake, finished)
    ]
}

private func openWireDerived(
    fixture: WireDerivedFixture,
    records: Array<Array<Byte>>
): ContractTls13WireDerivedClientHandshakeOutcome {
    contractTryTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
        fixture.clientHello,
        fixture.trust,
        collectRecords(records)
    )
}

@Test
public class ContractTls13WireDerivedClientRuntimeTestSuite {
    @TestCase
    public func testWireDerivedRuntimeCompletesFromFragmentedServerRecords(): Unit {
        let fixture = buildWireFixture()
        let wire = concatRecords(fixture.records)
        let needMore = contractTls13CollectIncrementalHandshakeRecords([], wire[0..3])
        let needMoreOutcome = contractTryTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
            fixture.trust,
            needMore
        )
        @Assert(needMoreOutcome.ok, false)
        @Assert(needMoreOutcome.status.toString(), "NEED_MORE_BYTES")
        @Assert(needMoreOutcome.needBytes, Int64(2))

        let collected = contractTls13CollectIncrementalHandshakeRecords(needMore.pendingBytes, wire[3..])
        let outcome = contractTryTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
            fixture.trust,
            collected
        )
        @Assert(outcome.ok, true)
        @Assert(outcome.status.toString(), "COMPLETED")
        if (let Some(result) <- outcome.result) {
            @Assert(result.runtime.status.toString(), "READY")
            @Assert(result.runtime.result.selectedAlpn, "h2")
            @Assert(result.mappedFlight.serverFlight.selectedAlpn, "h2")
            @Assert(result.mappedFlight.serverHello, fixture.serverFlight.serverHello)
            @Assert(result.clientFinished.encodedFinishedHandshake[0], UInt8(20))
            @Assert(result.clientFinished.encodedRecord[0], UInt8(23))
        } else {
            @Fail("wire-derived success should carry result")
        }
    }

    @TestCase
    public func testWireDerivedRuntimeCompletesFromCoalescedServerRecordsAndAppDataWorks(): Unit {
        let fixture = buildWireFixture()
        let outcome = openWireDerived(fixture, fixture.records)

        @Assert(outcome.ok, true)
        @Assert(outcome.recordsObserved, Int64(5))
        if (let Some(result) <- outcome.result) {
            @Assert(result.runtime.secureSessionReady, true)
            @Assert(result.runtime.result.chainLength, Int64(3))
            @Assert(result.mappedFlight.encryptedExtensions, fixture.serverFlight.encryptedExtensions)
            @Assert(result.mappedFlight.certificateHandshake, fixture.serverFlight.certificateHandshake)
            let encodedAppData = result.runtime.channelSet.clientChannel.sealApplicationData("ping".toArray())
            let opened = result.runtime.channelSet.serverChannel.openApplicationData(encodedAppData)
            @Assert(opened, "ping".toArray())
        } else {
            @Fail("wire-derived coalesced success should carry result")
        }
    }

    @TestCase
    public func testWireDerivedRequestWrapper(): Unit {
        let fixture = buildWireFixture()
        let runtime = contractTls13OpenHttpClientRuntimeFromWireDerivedServerFlightRequest(
            ContractTls13WireDerivedClientHandshakeRequest(
                fixture.clientHello,
                fixture.trust,
                collectRecords(fixture.records)
            )
        )

        @Assert(runtime.runtime.status.toString(), "READY")
        @Assert(runtime.mappedFlight.decodedProtectedRecordCount, Int64(4))
        @Assert(runtime.clientFinished.writeSurface, "tls13-client-finished-record")
    }

    @TestCase
    public func testWireDerivedRuntimeSurfacesPeerAlertAndMalformedRecord(): Unit {
        let fixture = buildWireFixture()
        let alert = contractTls13CollectIncrementalHandshakeRecords(
            [],
            contractTlsEncodeAlertRecord(
                ContractTlsVersion.Tls13,
                ContractTlsAlertLevel.AlertFatal,
                ContractTlsAlertDescription.AlertHandshakeFailure
            )
        )
        let alertOutcome = contractTryTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
            fixture.trust,
            alert
        )
        @Assert(alertOutcome.ok, false)
        @Assert(alertOutcome.status.toString(), "PEER_ALERT")
        if (let Some(peerAlert) <- alertOutcome.peerAlert) {
            @Assert(peerAlert.description.toString(), "HANDSHAKE_FAILURE")
        } else {
            @Fail("peer alert outcome should carry alert")
        }

        let malformed = contractTls13CollectIncrementalHandshakeRecords(
            [],
            [UInt8(0xff), UInt8(0x03), UInt8(0x04), UInt8(0x00), UInt8(0x00)]
        )
        let malformedOutcome = contractTryTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
            fixture.trust,
            malformed
        )
        @Assert(malformedOutcome.ok, false)
        @Assert(malformedOutcome.status.toString(), "MALFORMED")
    }

    @TestCase
    public func testWireDerivedRuntimeSurfacesTrustHostnameAndAlpnRejections(): Unit {
        let fixture = buildWireFixture()
        let collected = collectRecords(fixture.records)
        let trustRejected = contractTryTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
            ContractHttpClientTlsTrustRequest(
                readText("testdata/x509/crl_test_root.pem"),
                intermediatesPemBundle: fixture.trust.intermediatesPemBundle,
                hostname: TEST_HOST_WWW,
                policy: fixture.trust.policy
            ),
            collected
        )
        @Assert(trustRejected.ok, false)
        @Assert(trustRejected.status.toString(), "VERIFICATION_FAILED")

        let hostnameRejected = contractTryTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
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

        let alpnRejected = contractTryTls13OpenHttpClientRuntimeFromWireDerivedServerFlight(
            fixture.clientHello,
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
    public func testWireDerivedRuntimeRejectsBadCertificateVerifyAndFinished(): Unit {
        let fixture = buildWireFixture()
        let badCertificateVerifyRecords = rebuildProtectedRecords(
            fixture,
            certificateVerifyOverride: Some(tamperByte(fixture.serverFlight.certificateVerifyHandshake))
        )
        let badCertificateVerify = openWireDerived(fixture, badCertificateVerifyRecords)
        @Assert(badCertificateVerify.ok, false)
        @Assert(badCertificateVerify.status.toString(), "VERIFICATION_FAILED")
        @Assert(badCertificateVerify.message.contains("CertificateVerify"), true)

        let badFinishedRecords = rebuildProtectedRecords(
            fixture,
            finishedOverride: Some(tamperByte(fixture.serverFlight.finishedHandshake))
        )
        let badFinished = openWireDerived(fixture, badFinishedRecords)
        @Assert(badFinished.ok, false)
        @Assert(badFinished.status.toString(), "VERIFICATION_FAILED")
        @Assert(badFinished.message.contains("Finished"), true)
    }
}
