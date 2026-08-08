package jinguissl.tests

import std.collection.ArrayList
import jinguissl.live.*

private func concatBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = ArrayList<Byte>()
    for (b in left) {
        out.add(b)
    }
    for (b in right) {
        out.add(b)
    }
    out.toArray()
}

@Test
public class ContractTls13IncrementalHandshakeTestSuite {
    @TestCase
    public func testNeedMoreThenCompleteRecord(): Unit {
        let payload = "client-hello-fragment".toArray()
        let record = contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            payload
        )

        let headerOnly = contractTls13CollectIncrementalHandshakeRecords([], record[0..3])
        @Assert(headerOnly.status.toString(), "NEED_MORE_BYTES")
        @Assert(headerOnly.needBytes, Int64(2))
        @Assert(headerOnly.pendingBytes, record[0..3])
        @Assert(headerOnly.recordsReady, false)

        let full = contractTls13CollectIncrementalHandshakeRecords(
            headerOnly.pendingBytes,
            record[3..]
        )
        @Assert(full.status.toString(), "RECORDS_READY")
        @Assert(full.recordsReady, true)
        @Assert(full.records.size, Int64(1))
        @Assert(full.records[0].contentType.toString(), "HANDSHAKE")
        @Assert(full.records[0].payload, payload)
        @Assert(full.pendingBytes.size, Int64(0))
    }

    @TestCase
    public func testMultiRecordFlightAndPendingPayload(): Unit {
        let first = contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            "server-hello".toArray()
        )
        let second = contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            "encrypted-extensions".toArray()
        )
        let third = contractTlsEncodePlaintextRecord(
            ContractTlsVersion.Tls13,
            ContractTlsRecordContentType.Handshake,
            "certificate".toArray()
        )
        let flight = concatBytes(concatBytes(first, second), third[0..8])

        let result = contractTls13CollectIncrementalHandshakeRecords([], flight)
        @Assert(result.status.toString(), "RECORDS_READY")
        @Assert(result.records.size, Int64(2))
        @Assert(result.records[0].payload, "server-hello".toArray())
        @Assert(result.records[1].payload, "encrypted-extensions".toArray())
        @Assert(result.pendingBytes, third[0..8])
        @Assert(result.needBytes, third.size - Int64(8))

        let completed = contractTls13CollectIncrementalHandshakeRecords(result.pendingBytes, third[8..])
        @Assert(completed.status.toString(), "RECORDS_READY")
        @Assert(completed.records.size, Int64(1))
        @Assert(completed.records[0].payload, "certificate".toArray())
        @Assert(completed.pendingBytes.size, Int64(0))
    }

    @TestCase
    public func testPlaintextPeerAlertOutcome(): Unit {
        let alertRecord = contractTlsEncodeAlertRecord(
            ContractTlsVersion.Tls13,
            ContractTlsAlertLevel.AlertFatal,
            ContractTlsAlertDescription.AlertHandshakeFailure
        )

        let result = contractTls13CollectIncrementalHandshakeRecords([], alertRecord)
        @Assert(result.status.toString(), "PEER_ALERT")
        @Assert(result.records.size, Int64(1))
        @Assert(result.records[0].contentType.toString(), "ALERT")
        if (let Some(alert) <- result.peerAlert) {
            @Assert(alert.level.toString(), "FATAL")
            @Assert(alert.description.toString(), "HANDSHAKE_FAILURE")
        } else {
            @Fail("peer alert should be present")
        }
    }

    @TestCase
    public func testMalformedRecordOutcome(): Unit {
        let malformed = [
            UInt8(0xff),
            UInt8(0x03),
            UInt8(0x04),
            UInt8(0x00),
            UInt8(0x00)
        ]

        let result = contractTls13CollectIncrementalHandshakeRecords([], malformed)
        @Assert(result.status.toString(), "MALFORMED")
        @Assert(result.terminalFailure, true)
        if (let Some(code) <- result.code) {
            @Assert(code.toString(), "BAD_INPUT")
        } else {
            @Fail("malformed outcome should carry a ContractErrorCode")
        }
    }
}
