package jinguissl.live

import std.collection.ArrayList
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.tls.{TlsContentType, tlsDecodeRecord}

private let CONTRACT_TLS_RECORD_HEADER_LEN: Int64 = 5
private let CONTRACT_TLS13_INCREMENTAL_MAX_PAYLOAD_LEN: Int64 = 18432

public enum ContractTls13IncrementalHandshakeStatus <: Equatable<ContractTls13IncrementalHandshakeStatus> & ToString {
    | NeedMoreBytes
    | RecordsReady
    | PeerAlert
    | Malformed
    | PolicyRejected
    | VerificationFailed
    | Timeout
    | Cancelled
    | Completed

    public operator func ==(right: ContractTls13IncrementalHandshakeStatus): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: ContractTls13IncrementalHandshakeStatus): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case NeedMoreBytes => 0
            case RecordsReady => 1
            case PeerAlert => 2
            case Malformed => 3
            case PolicyRejected => 4
            case VerificationFailed => 5
            case Timeout => 6
            case Cancelled => 7
            case Completed => 8
        }
    }

    public func toString(): String {
        match (this) {
            case NeedMoreBytes => "NEED_MORE_BYTES"
            case RecordsReady => "RECORDS_READY"
            case PeerAlert => "PEER_ALERT"
            case Malformed => "MALFORMED"
            case PolicyRejected => "POLICY_REJECTED"
            case VerificationFailed => "VERIFICATION_FAILED"
            case Timeout => "TIMEOUT"
            case Cancelled => "CANCELLED"
            case Completed => "COMPLETED"
        }
    }
}

public class ContractTls13IncrementalRecordFrame {
    public let version: ContractTlsVersion
    public let contentType: ContractTlsRecordContentType
    public let encodedRecord: Array<Byte>
    public let payload: Array<Byte>
    public let payloadLength: Int64
    public let wireLength: Int64

    public init(
        version: ContractTlsVersion,
        contentType: ContractTlsRecordContentType,
        encodedRecord: Array<Byte>,
        payload: Array<Byte>
    ) {
        if (encodedRecord.size < CONTRACT_TLS_RECORD_HEADER_LEN) {
            throw ContractException(ContractErrorCode.BadInput, "TLS incremental record frame is shorter than header")
        }
        if (payload.size + CONTRACT_TLS_RECORD_HEADER_LEN != encodedRecord.size) {
            throw ContractException(ContractErrorCode.BadInput, "TLS incremental record frame length mismatch")
        }
        this.version = version
        this.contentType = contentType
        this.encodedRecord = encodedRecord.clone()
        this.payload = payload.clone()
        this.payloadLength = payload.size
        this.wireLength = encodedRecord.size
    }
}

public class ContractTls13IncrementalHandshakeRecordRequest {
    public let pendingBytes: Array<Byte>
    public let incomingBytes: Array<Byte>
    public let maxRecords: Int64
    public let maxPayloadLen: Int64

    public init(
        pendingBytes!: Array<Byte> = [],
        incomingBytes!: Array<Byte> = [],
        maxRecords!: Int64 = 0,
        maxPayloadLen!: Int64 = CONTRACT_TLS13_INCREMENTAL_MAX_PAYLOAD_LEN
    ) {
        if (maxRecords < 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS incremental maxRecords must be >= 0")
        }
        if (maxPayloadLen <= 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS incremental maxPayloadLen must be > 0")
        }
        this.pendingBytes = pendingBytes.clone()
        this.incomingBytes = incomingBytes.clone()
        this.maxRecords = maxRecords
        this.maxPayloadLen = maxPayloadLen
    }
}

public class ContractTls13IncrementalHandshakeResult {
    public let status: ContractTls13IncrementalHandshakeStatus
    public let message: String
    public let code: ?ContractErrorCode
    public let igniteCode: ?ContractIgniteCryptoErrorCode
    public let records: Array<ContractTls13IncrementalRecordFrame>
    public let peerAlert: ?ContractTlsAlertMessage
    public let pendingBytes: Array<Byte>
    public let consumedBytes: Int64
    public let needBytes: Int64

    public init(
        status: ContractTls13IncrementalHandshakeStatus,
        message: String,
        code!: ?ContractErrorCode = None,
        igniteCode!: ?ContractIgniteCryptoErrorCode = None,
        records!: Array<ContractTls13IncrementalRecordFrame> = [],
        peerAlert!: ?ContractTlsAlertMessage = None,
        pendingBytes!: Array<Byte> = [],
        consumedBytes!: Int64 = 0,
        needBytes!: Int64 = 0
    ) {
        if (message.trimAscii().size == 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS incremental handshake result message must not be empty")
        }
        if (consumedBytes < 0 || needBytes < 0) {
            throw ContractException(ContractErrorCode.BadInput, "TLS incremental handshake result byte counters must be >= 0")
        }
        this.status = status
        this.message = message.trimAscii()
        this.code = code
        this.igniteCode = igniteCode
        this.records = contractTls13CopyIncrementalFrames(records)
        this.peerAlert = peerAlert
        this.pendingBytes = pendingBytes.clone()
        this.consumedBytes = consumedBytes
        this.needBytes = needBytes
    }

    public prop recordsReady: Bool {
        get() {
            records.size > 0
        }
    }

    public prop terminalFailure: Bool {
        get() {
            status == ContractTls13IncrementalHandshakeStatus.Malformed ||
            status == ContractTls13IncrementalHandshakeStatus.PolicyRejected ||
            status == ContractTls13IncrementalHandshakeStatus.VerificationFailed ||
            status == ContractTls13IncrementalHandshakeStatus.Timeout ||
            status == ContractTls13IncrementalHandshakeStatus.Cancelled
        }
    }
}

public func contractTls13CollectIncrementalHandshakeRecords(
    pendingBytes: Array<Byte>,
    incomingBytes: Array<Byte>,
    maxRecords!: Int64 = 0,
    maxPayloadLen!: Int64 = CONTRACT_TLS13_INCREMENTAL_MAX_PAYLOAD_LEN
): ContractTls13IncrementalHandshakeResult {
    if (maxRecords < 0) {
        return contractTls13IncrementalMalformed("TLS incremental maxRecords must be >= 0", [])
    }
    if (maxPayloadLen <= 0) {
        return contractTls13IncrementalMalformed("TLS incremental maxPayloadLen must be > 0", [])
    }

    let buffer = contractTls13ConcatBytes(pendingBytes, incomingBytes)
    let records = ArrayList<ContractTls13IncrementalRecordFrame>()
    var consumed: Int64 = 0

    while (consumed < buffer.size) {
        if (maxRecords > 0 && records.size >= maxRecords) {
            return contractTls13IncrementalRecordsReady(records, buffer[consumed..], consumed)
        }

        let available = buffer.size - consumed
        if (available < CONTRACT_TLS_RECORD_HEADER_LEN) {
            let need = CONTRACT_TLS_RECORD_HEADER_LEN - available
            if (records.size > 0) {
                return contractTls13IncrementalRecordsReadyWithNeed(records, buffer[consumed..], consumed, need)
            }
            return ContractTls13IncrementalHandshakeResult(
                ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
                "TLS record header is incomplete",
                pendingBytes: buffer[consumed..],
                consumedBytes: consumed,
                needBytes: need
            )
        }

        let payloadLen = contractTls13DecodeRecordPayloadLen(buffer, consumed)
        if (payloadLen > maxPayloadLen) {
            return contractTls13IncrementalMalformed(
                "TLS record payload length exceeds incremental limit",
                buffer[consumed..],
                consumedBytes: consumed
            )
        }

        let recordLen = CONTRACT_TLS_RECORD_HEADER_LEN + payloadLen
        if (available < recordLen) {
            let need = recordLen - available
            if (records.size > 0) {
                return contractTls13IncrementalRecordsReadyWithNeed(records, buffer[consumed..], consumed, need)
            }
            return ContractTls13IncrementalHandshakeResult(
                ContractTls13IncrementalHandshakeStatus.NeedMoreBytes,
                "TLS record payload is incomplete",
                pendingBytes: buffer[consumed..],
                consumedBytes: consumed,
                needBytes: need
            )
        }

        let encodedRecord = buffer[consumed..(consumed + recordLen)]
        let frame = try {
            contractTls13DecodeIncrementalRecordFrame(encodedRecord)
        } catch (e: ContractException) {
            return contractTls13IncrementalMalformed(e.message, buffer[consumed..], consumedBytes: consumed)
        } catch (e: CryptoException) {
            return contractTls13IncrementalMalformed(
                "TLS record decode failed: ${e.message}",
                buffer[consumed..],
                consumedBytes: consumed
            )
        }
        records.add(frame)
        consumed += recordLen

        if (frame.contentType == ContractTlsRecordContentType.Alert) {
            let alert = try {
                contractTlsDecodeAlertRecord(encodedRecord)
            } catch (e: ContractException) {
                return contractTls13IncrementalMalformed(e.message, buffer[consumed..], consumedBytes: consumed)
            }
            return ContractTls13IncrementalHandshakeResult(
                ContractTls13IncrementalHandshakeStatus.PeerAlert,
                "TLS peer alert received",
                records: records.toArray(),
                peerAlert: Some(alert),
                pendingBytes: buffer[consumed..],
                consumedBytes: consumed
            )
        }
    }

    contractTls13IncrementalRecordsReady(records, [], consumed)
}

public func contractTls13CollectIncrementalHandshakeRecordsRequest(
    request: ContractTls13IncrementalHandshakeRecordRequest
): ContractTls13IncrementalHandshakeResult {
    contractTls13CollectIncrementalHandshakeRecords(
        request.pendingBytes,
        request.incomingBytes,
        maxRecords: request.maxRecords,
        maxPayloadLen: request.maxPayloadLen
    )
}

private func contractTls13DecodeRecordPayloadLen(buffer: Array<Byte>, offset: Int64): Int64 {
    (Int64(buffer[offset + 3]) << 8) | Int64(buffer[offset + 4])
}

private func contractTls13DecodeIncrementalRecordFrame(
    encodedRecord: Array<Byte>
): ContractTls13IncrementalRecordFrame {
    let decoded = tlsDecodeRecord(encodedRecord)
    ContractTls13IncrementalRecordFrame(
        contractFromTlsVersion(decoded.header.version),
        contractTls13FromTlsContentType(decoded.header.contentType),
        encodedRecord,
        decoded.fragment
    )
}

private func contractTls13FromTlsContentType(contentType: TlsContentType): ContractTlsRecordContentType {
    match (contentType) {
        case TlsContentType.ChangeCipherSpec => ContractTlsRecordContentType.ChangeCipherSpec
        case TlsContentType.Alert => ContractTlsRecordContentType.Alert
        case TlsContentType.Handshake => ContractTlsRecordContentType.Handshake
        case TlsContentType.ApplicationData => ContractTlsRecordContentType.ApplicationData
    }
}

private func contractTls13IncrementalRecordsReady(
    records: ArrayList<ContractTls13IncrementalRecordFrame>,
    pendingBytes: Array<Byte>,
    consumedBytes: Int64
): ContractTls13IncrementalHandshakeResult {
    ContractTls13IncrementalHandshakeResult(
        ContractTls13IncrementalHandshakeStatus.RecordsReady,
        "TLS records are ready",
        records: records.toArray(),
        pendingBytes: pendingBytes,
        consumedBytes: consumedBytes
    )
}

private func contractTls13IncrementalRecordsReadyWithNeed(
    records: ArrayList<ContractTls13IncrementalRecordFrame>,
    pendingBytes: Array<Byte>,
    consumedBytes: Int64,
    needBytes: Int64
): ContractTls13IncrementalHandshakeResult {
    ContractTls13IncrementalHandshakeResult(
        ContractTls13IncrementalHandshakeStatus.RecordsReady,
        "TLS records are ready and more bytes are pending",
        records: records.toArray(),
        pendingBytes: pendingBytes,
        consumedBytes: consumedBytes,
        needBytes: needBytes
    )
}

private func contractTls13IncrementalMalformed(
    message: String,
    pendingBytes: Array<Byte>,
    consumedBytes!: Int64 = 0
): ContractTls13IncrementalHandshakeResult {
    ContractTls13IncrementalHandshakeResult(
        ContractTls13IncrementalHandshakeStatus.Malformed,
        message,
        code: Some(ContractErrorCode.BadInput),
        igniteCode: Some(contractMapToIgniteCryptoErrorCode(ContractErrorCode.BadInput)),
        pendingBytes: pendingBytes,
        consumedBytes: consumedBytes
    )
}

private func contractTls13ConcatBytes(left: Array<Byte>, right: Array<Byte>): Array<Byte> {
    let out = ArrayList<Byte>()
    for (b in left) {
        out.add(b)
    }
    for (b in right) {
        out.add(b)
    }
    out.toArray()
}

private func contractTls13CopyIncrementalFrames(
    records: Array<ContractTls13IncrementalRecordFrame>
): Array<ContractTls13IncrementalRecordFrame> {
    let out = ArrayList<ContractTls13IncrementalRecordFrame>()
    for (record in records) {
        out.add(record)
    }
    out.toArray()
}
