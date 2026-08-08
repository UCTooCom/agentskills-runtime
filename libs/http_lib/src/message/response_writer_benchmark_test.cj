package http_lib.message

import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.connection.MockConnection

/**
 * ResponseBuilder 流式写入性能基准测试。
 */
@Test public class ResponseBuilderBench {
    @Bench
    public func smallJsonResponse(): Unit {
        let mockConn = MockConnection([])
        let w = ResponseBuilder(mockConn)
        w.setHeader("Content-Type", "application/json")
        w.setHeader("Content-Length", "17")
        w.writeHeader(HttpStatus.OK)
        w.writeString("{\"status\":\"ok\"}")
        w.finish()
    }

    @Bench
    public func chunked800Kb(): Unit {
        let mockConn = MockConnection([])
        let w = ResponseBuilder(mockConn)
        w.writeHeader(HttpStatus.OK)
        let chunk = Array<UInt8>(8192, repeat: 0x41)
        var j: Int64 = 0
        while (j < 100) {
            w.write(chunk)
            j += 1
        }
        w.finish()
    }

    @Bench
    public func withTrailers(): Unit {
        let mockConn = MockConnection([])
        let w = ResponseBuilder(mockConn)
        w.addTrailer("X-Checksum", "abc123def456")
        w.writeHeader(HttpStatus.OK)
        w.writeString("response body content here")
        w.finish()
    }
}
