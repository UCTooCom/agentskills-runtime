package http_lib.http3

import http_lib.core.HttpHeaders

/**
 * HTTP/3 帧、QPACK、设置、流类型基准测试。
 */
@Test public class Http3FrameTypeBench {
    @Bench
    public func frameTypeToUInt8ToString(): Unit {
        let ft = Http3FrameType.DATA
        let _ = ft.toUInt8()
        let _ = ft.toString()
    }

    @Bench
    public func frameTypeEquality(): Unit {
        let _ = Http3FrameType.DATA == Http3FrameType.DATA
        let _ = Http3FrameType.DATA == Http3FrameType.HEADERS
    }
}

@Test public class Http3FrameEncodeBench {
    @Bench
    public func encodeSettingsFrame(): Unit {
        let settings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096),
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536),
            (Http3SettingsId.SETTINGS_QPACK_BLOCKED_STREAMS, 100),
        ]
        let _ = buildH3SettingsFrame(settings)
    }

    @Bench
    public func encodeGoawayFrame(): Unit {
        let _ = buildH3GoawayFrame(42u64)
    }

    @Bench
    public func decodeFrameHeader(): Unit {
        let frame = encodeH3Frame(Http3FrameType.HEADERS, Array<UInt8>(128, repeat: 0x41))
        let (header, _) = decodeH3FrameHeader(frame)
        let _ = header.frameType
        let _ = header.payloadLength
    }
}

@Test public class Http3SettingsIdBench {
    @Bench
    public func settingsIdRoundtrip(): Unit {
        let id = Http3SettingsId.QPACK_MAX_TABLE_CAPACITY
        let v = id.toUInt16()
        let _ = Http3SettingsId.fromUInt16(v)
    }
}

@Test public class QpackBench {
    @Bench
    public func qpackEncode(): Unit {
        let headers = HttpHeaders()
        headers.set(":method", "GET")
        headers.set(":path", "/api/v2/users?page=1")
        headers.set(":authority", "example.com")
        headers.set("accept", "application/json")
        headers.set("cache-control", "no-cache")
        let encoder = QpackEncoder(maxTableCapacity: 4096)
        let _ = encoder.encode(headers)
        let _ = encoder.getEncoderStreamData()
    }
}

@Test public class QuicStreamTypeBench {
    @Bench
    public func streamTypeEquality(): Unit {
        let _ = QuicStreamType.BIDIRECTIONAL == QuicStreamType.BIDIRECTIONAL
        let _ = QuicStreamType.BIDIRECTIONAL != QuicStreamType.UNIDIRECTIONAL
        let _ = QuicStreamType.UNIDIRECTIONAL == QuicStreamType.UNIDIRECTIONAL
        let _ = QuicStreamType.UNIDIRECTIONAL != QuicStreamType.BIDIRECTIONAL
    }
}

@Test public class Http3ConfigBench {
    @Bench
    public func configConstruction(): Unit {
        let _ = Http3Config()
    }
}


// ======== QPACK 基准测试 ========

@Test public class QpackEncodeBench {
    @Bench
    public func encodeSmallHeaders(): Unit {
        let encoder = QpackEncoder()
        let headers = HttpHeaders()
        headers.set("content-type", "application/json")
        let _ = encoder.encode(headers)
    }

    @Bench
    public func encodeMediumHeaders(): Unit {
        let encoder = QpackEncoder()
        let headers = HttpHeaders()
        var i: Int64 = 0
        while (i < 8) {
            headers.set("header" + i.toString(), "value" + i.toString())
            i += 1
        }
        let _ = encoder.encode(headers)
    }
}

@Test public class QpackDecodeBench {
    @Bench
    public func decodeMediumHeaders(): Unit {
        let encoder = QpackEncoder()
        let decoder = QpackDecoder()
        let headers = HttpHeaders()
        var i: Int64 = 0
        while (i < 8) {
            headers.set("header" + i.toString(), "value" + i.toString())
            i += 1
        }
        let encoded = encoder.encode(headers)
        let _ = decoder.decode(encoded)
    }
}

@Test public class H3FrameDecodeBench {
    @Bench
    public func decodeSettingsFrame(): Unit {
        let settings: Array<(Http3SettingsId, UInt64)> = [
            (Http3SettingsId.QPACK_MAX_TABLE_CAPACITY, 4096),
            (Http3SettingsId.MAX_FIELD_SECTION_SIZE, 65536),
            (Http3SettingsId.SETTINGS_QPACK_BLOCKED_STREAMS, 100),
        ]
        let encoded = buildH3SettingsFrame(settings)
        for (_ in 0..100) {
            let _ = decodeH3FrameHeader(encoded)
        }
    }

    @Bench
    public func decodeLargeDataFrameHeader(): Unit {
        let payload = Array<UInt8>(1024, repeat: 0x41u8)
        let encoded = encodeH3Frame(Http3FrameType.DATA, payload)
        for (_ in 0..100) {
            let _ = decodeH3FrameHeader(encoded)
        }
    }
}
