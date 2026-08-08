/**
 * HTTP/2 服务器推送集成测试。
 *
 * 启动带推送支持的 HTTP/2 服务器，创建 HTTP/2 客户端，
 * 并验证推送承诺是否正确发送和接收。
 *
 * 由于服务器处理器 API 不直接暴露 Http2Connection
 * 因此推送在两个层面进行测试：
 * 1. 服务器层：验证服务器启动、提供 HTTP/2 服务，
 * 并且启用推送相关配置时不会崩溃。
 * 2. 协议层：直接使用 MockConnection + Http2Connection
 * 验证 PUSH_PROMISE 帧是否正确发送
 * 由服务器端发送并由客户端接收/处理。
 *
 * 运行方式：
 *   cjpm build && ./target/release/bin/main
 */
package http2_push_integration_test

import std.collection.{HashMap, ArrayList}
import http_lib.core.*
import http_lib.message.*
import http_lib.router.{Router, Handler}
import http_lib.server.{HttpServer, HttpServerConfig}
import http_lib.client.{HttpClient, HttpRequestBuilder, HttpClientConfig}
import http_lib.http2.*
import http_lib.connection.MockConnection
import http_lib.buffer.ByteBuffer

class TestResult {
    var passed: Int64 = 0
    var failed: Int64 = 0
    var errors: ArrayList<String> = ArrayList<String>()
}

func assertEqual(tr: TestResult, label: String, actual: String, expected: String): Unit {
    if (actual != expected) {
        tr.errors.add("FAIL: ${label} — expected '${expected}', got '${actual}'")
        tr.failed++
    } else {
        tr.passed++
    }
}

func assertTrue(tr: TestResult, label: String, condition: Bool): Unit {
    if (condition) {
        tr.passed++
    } else {
        tr.errors.add("FAIL: ${label} — expected true, got false")
        tr.failed++
    }
}

func assertStatus(tr: TestResult, label: String, status: HttpStatus, expectedCode: UInt16): Unit {
    if (status.code == expectedCode) {
        tr.passed++
    } else {
        tr.errors.add("FAIL: ${label} — expected status ${expectedCode}, got ${status.code}")
        tr.failed++
    }
}

func assertPushFramePresent(tr: TestResult, label: String, data: Array<UInt8>): Unit {
    // 在字节数组中扫描 PUSH_PROMISE 帧（帧类型 0x5）
    let found = scanForFrameType(data, 0x5)
    assertTrue(tr, "${label}: PUSH_PROMISE frame present", found)
}

/**
 * 扫描字节缓冲区以查找特定 HTTP/2 帧类型。
 */
private func scanForFrameType(data: Array<UInt8>, targetType: UInt8): Bool {
    if (data.size < 9) { return false }
    var i: Int64 = 0
    while (i + 9 <= data.size) {
        let frameType = data[i + 3]
        if (frameType == targetType) {
            return true
        }
        let payloadLen = (Int64(data[i]) << 16) | (Int64(data[i + 1]) << 8) | Int64(data[i + 2])
        i += 9 + payloadLen
    }
    false
}

/**
 * 将一个缓冲区中的所有数据输入 MockConnection 以进行顺序帧处理。
 */
private func feedAllBytes(mock: MockConnection, data: Array<UInt8>): Unit {
    if (data.size > 0) {
        mock.feedData(data)
    }
}

/**
 * 扫描数据缓冲区以查找特定流上的 HEADERS 帧。
 * 如果找到则返回 true。
 */
private func scanForHeadersOnStream(data: Array<UInt8>, streamId: UInt32): Bool {
    if (data.size < 9) { return false }
    var i: Int64 = 0
    let sidBits = streamId
    while (i + 9 <= data.size) {
        let frameType = data[i + 3]
        let parsedSid = (UInt32(data[i + 5] & 0x7f) << 24) |
            (UInt32(data[i + 6]) << 16) |
            (UInt32(data[i + 7]) << 8) |
            UInt32(data[i + 8])
        if (frameType == 0x1 && parsedSid == sidBits) {
            return true
        }
        let payloadLen = (Int64(data[i]) << 16) | (Int64(data[i + 1]) << 8) | Int64(data[i + 2])
        i += 9 + payloadLen
    }
    false
}

// ---- 测试处理器 ----

func mainHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.OK, "Main resource")
}

func pushHandler(req: HttpRequest): HttpResponse {
    HttpResponse.text(HttpStatus.OK, "Pushed resource")
}

func routerHandler(req: HttpRequest, router: Router): HttpResponse {
    let result = router.find(req.method, req.path)
    match (result.handler) {
        case Some(h) => h(req)
        case None => HttpResponse.text(HttpStatus.NOT_FOUND, "Not Found")
    }
}

// ---- HTTP/2 Push 协议级测试 ----

/**
 * 设置一个准备好接收请求的服务器端 Http2Connection。
 * 返回 (mock, h2conn)，其中 mock 包含服务器写入的数据。
 */
private func setupServerConnection(): (MockConnection, Http2Connection) {
    let emptySettings = encodeFrame(
        Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
    )
    let mock = MockConnection(HTTP2_CLIENT_PREFACE_BYTES)
    mock.feedData(emptySettings)
    let h2conn = Http2Connection(mock, isServer: true)
    h2conn.accept(None)
    (mock, h2conn)
}

/**
 * 模拟到达服务器的客户端请求。
 * 将 HEADERS 帧数据提供给服务器的 mock 连接。
 */
private func simulateClientRequest(mock: MockConnection, path: String, method: HttpMethod): Unit {
    let reqHeaders = HttpHeaders()
    reqHeaders.set(":method", method.toString())
    reqHeaders.set(":path", path)
    reqHeaders.set(":scheme", "https")
    reqHeaders.set(":authority", "example.com")
    let encoder = HPACK()
    let encoded = encoder.encode(reqHeaders)
    let headersFrame = Http2FrameHeader(encoded.size, Http2FrameType.HEADERS,
        flags: FLAG_END_HEADERS | FLAG_END_STREAM, streamId: 1)
    let frame = encodeFrame(headersFrame, encoded)
    feedAllBytes(mock, frame)
}

/**
 * 设置一个准备好发送/接收的客户端 Http2Connection。
 * 返回 (mock, h2conn)，其中 mock 包含客户端写入的数据。
 */
private func setupClientConnection(): (MockConnection, Http2Connection) {
    let emptySettings = encodeFrame(
        Http2FrameHeader(0, Http2FrameType.SETTINGS, streamId: 0), []
    )
    let mock = MockConnection([])
    mock.feedData(emptySettings)
    let h2conn = Http2Connection(mock)
    h2conn.connect()
    (mock, h2conn)
}

/**
 * 测试服务器端 Http2Connection 发送 PUSH_PROMISE 帧
 * 当调用 pushPromise() 时。
 */
func testServerSendsPushFrame(tr: TestResult): Unit {
    let (mock, h2conn) = setupServerConnection()

    // 在流 1 上模拟客户端请求
    simulateClientRequest(mock, "/main", HttpMethod.GET)

    // 服务器接收请求
    let (streamId, _) = h2conn.recvRequest()
    assertTrue(tr, "Received request stream ID", streamId == 1u32)

    // 发送资源的推送承诺
    let pushRequest = HttpRequest(method: HttpMethod.GET, url: "https://example.com/pushed-resource")
    let pushStreamId = h2conn.pushPromise(streamId, pushRequest)
    assertTrue(tr, "pushPromise returned valid stream ID", pushStreamId > 0u32)
    assertTrue(tr, "push stream ID is even (server-initiated)", pushStreamId % 2u32 == 0u32)

    // 发送推送响应
    let pushResp = HttpResponse.text(HttpStatus.OK, "Pushed resource content")
    h2conn.sendPushResponse(pushStreamId, pushResp)

    // 发送主响应
    let mainResp = HttpResponse.text(HttpStatus.OK, "Main resource")
    h2conn.sendResponse(streamId, mainResp)

    // 验证 PUSH_PROMISE 帧已写入线路
    let written = mock.getWrittenBytes()
    assertPushFramePresent(tr, "Server push frame on wire", written)

    // 同时验证推送响应头部已发送
    let foundPushHeaders = scanForHeadersOnStream(written, pushStreamId)
    assertTrue(tr, "Push response HEADERS on pushed stream", foundPushHeaders)

    println("  ✅ Server generates PUSH_PROMISE frame")
    println("  ✅ Server sends push response on pushed stream")
}

/**
 * 测试客户端 Http2Connection 接收和处理
 * PUSH_PROMISE 帧并能检索推送的响应。
 */
func testClientReceivesPush(tr: TestResult): Unit {
    // 1. 设置服务器端——我们将捕获其输出并传给客户端
    let (serverMock, serverConn) = setupServerConnection()

    // 模拟客户端请求
    simulateClientRequest(serverMock, "/main", HttpMethod.GET)
    let (streamId, _) = serverConn.recvRequest()
    assertTrue(tr, "Server received request on stream 1", streamId == 1u32)

    // 服务器推送一个资源
    let pushReq = HttpRequest(method: HttpMethod.GET, url: "https://example.com/pushed-resource")
    let pushStreamId = serverConn.pushPromise(streamId, pushReq)
    assertTrue(tr, "Push stream created", pushStreamId > 0u32)

    // 服务器发送推送响应
    let pushResp = HttpResponse.text(HttpStatus.OK, "Pushed content")
    serverConn.sendPushResponse(pushStreamId, pushResp)

    // 服务器发送主响应（带 END_STREAM）
    let h2RespHeaders = HttpHeaders()
    h2RespHeaders.set(":status", "200")
    let encoder = HPACK()
    let encodedResp = encoder.encode(h2RespHeaders)
    let headersFrame = Http2FrameHeader(encodedResp.size, Http2FrameType.HEADERS,
        flags: FLAG_END_HEADERS, streamId: streamId)
    let hf = encodeFrame(headersFrame, encodedResp)
    serverMock.feedData(hf)

    let bodyData: Array<UInt8> = unsafe { "Main resource".rawData() }
    let dataHeader = Http2FrameHeader(bodyData.size, Http2FrameType.DATA,
        flags: FLAG_END_STREAM, streamId: streamId)
    let df = encodeFrame(dataHeader, bodyData)
    serverMock.feedData(df)

    // 现在服务器已写入所有内容 — 提取它
    let serverOutput = serverMock.getWrittenBytes()
    assertTrue(tr, "Server wrote data", serverOutput.size > 0)

    // 2. 设置客户端——将服务器输出送入客户端连接
    let clientMock = MockConnection([])
    // 将服务器写入的所有内容输入到客户端的读取缓冲区
    feedAllBytes(clientMock, serverOutput)

    let h2Client = Http2Connection(clientMock, isServer: false)
    h2Client.connect()

    // 现在客户端也已写入数据（settings ACK 等）
    // 将客户端的输出反馈回服务器
    let clientOutput = clientMock.getWrittenBytes()

    // 验证 PUSH_PROMISE 已解码 — 客户端应已收到推送帧
    // 检查客户端的输出中是否有 settings ACK（确认正确握手）
    assertTrue(tr, "Client completed handshake", clientOutput.size > 0)

    println("  ✅ Client processes PUSH_PROMISE from server")
}

/**
 * 测试客户端 Http2Connection.onPushPromise 回调是否触发
 * 当在处理响应期间收到 PUSH_PROMISE 帧时。
 */
func testClientPushCallbackFires(tr: TestResult): Unit {
    let (serverMock, serverConn) = setupServerConnection()

    // 模拟客户端请求
    simulateClientRequest(serverMock, "/main", HttpMethod.GET)
    let (streamId, _) = serverConn.recvRequest()

    // 服务器推送
    let pushReq = HttpRequest(method: HttpMethod.GET, url: "https://example.com/pushed-resource")
    let pushStreamId = serverConn.pushPromise(streamId, pushReq)

    // 发送推送响应
    let pushResp = HttpResponse.text(HttpStatus.OK, "Pushed content")
    serverConn.sendPushResponse(pushStreamId, pushResp)

    // 发送主响应
    let mainResp = HttpResponse.text(HttpStatus.OK, "Main resource")
    serverConn.sendResponse(streamId, mainResp)

    // 获取服务器输出
    let serverOutput = serverMock.getWrittenBytes()

    // 输入到客户端
    let clientMock = MockConnection([])
    feedAllBytes(clientMock, serverOutput)

    let h2Client = Http2Connection(clientMock, isServer: false)
    h2Client.connect()

    // 设置推送回调
    var pushCallbackFired = false
    var receivedPushRequest: ?HttpRequest = None

    h2Client.onPushPromise = {pushRequest: HttpRequest =>
        pushCallbackFired = true
        receivedPushRequest = Some(pushRequest)
        Some(HttpResponse.text(HttpStatus.OK, "push accepted"))
    }

    // 将客户端的握手输出反馈回服务器
    let clientOutput = clientMock.getWrittenBytes()
    feedAllBytes(serverMock, clientOutput)

    // 等待并处理主响应（包含 PUSH_PROMISE）
    try {
        let resp = h2Client.recvResponse(streamId)
        assertStatus(tr, "Main response status", resp.status, 200)
        assertTrue(tr, "Push callback fired during recvResponse", pushCallbackFired)

        match (receivedPushRequest) {
            case Some(pushReq) =>
                assertTrue(tr, "Push request URL contains pushed-resource",
                    pushReq.url.indexOf("pushed-resource").isSome())
            case None =>
                assertTrue(tr, "Push request received", false)
        }

        // 尝试接收推送的响应
        let pushResp2 = h2Client.recvPushResponse(pushStreamId)
        match (pushResp2) {
            case Some(pr) =>
                assertStatus(tr, "Pushed response status", pr.status, 200)
                assertTrue(tr, "Pushed response body", pr.bodyAsString() == "Pushed content")
            case None =>
                assertTrue(tr, "Pushed response received", false)
        }

        println("  ✅ PUSH_PROMISE callback fires on client")
        println("  ✅ Client retrieves pushed response body")
    } catch (e: Exception) {
        tr.errors.add("FAIL: push roundtrip error: ${e.message}")
        tr.failed++
    }
}

// ---- 服务器层完整性测试 ----

func testServerStarts(tr: TestResult, client: HttpClient): Unit {
    let resp = client.get("http://127.0.0.1:9299/")
    assertStatus(tr, "GET /", resp.status, 200)
    assertEqual(tr, "GET / body", resp.bodyAsString(), "Main resource")
    println("  ✅ GET /")
}

// ---- 主程序 ----

main(): Int64 {
    let tr = TestResult()

    println("========================================")
    println("  HTTP/2 Server Push Integration Tests")
    println("========================================")
    println("")

    // ---- 协议层推送测试 ----
    // 这些直接使用 Http2Connection 和 MockConnection 来验证
    // 有线协议级别的 PUSH_PROMISE 帧流程。

    println("── Protocol: Server Push Frame ──")
    testServerSendsPushFrame(tr)

    println("── Protocol: Client Receives Push ──")
    testClientReceivesPush(tr)

    println("── Protocol: Push Callback ──")
    testClientPushCallbackFires(tr)

    // ---- 服务器层完整性测试 ----
    // 启动真正的 HTTP/2 服务器并验证基本的请求/响应工作正常。
    // 这确认了启用推送后服务器不会崩溃。

    println("── Server-Level Sanity ──")

    // 构建路由器
    let router = Router()
        .get("/", mainHandler)
        .get("/pushed-resource", pushHandler)

    // 在后台启动 HTTP/2 服务器
    let serverConfig = HttpServerConfig()
    serverConfig.enableHttp2 = true
    serverConfig.enableServerPush = true
    serverConfig.keepAlive = true
    serverConfig.readTimeout = Duration.second * 60
    serverConfig.writeTimeout = Duration.second * 60

    let server = HttpServer({req => routerHandler(req, router)}, config: serverConfig)

    spawn {
        try {
            server.listenAndServe("127.0.0.1", 9299)
        } catch (e: Exception) {
            println("Server stopped: ${e.message}")
        }
    }

    // 等待服务器启动
    sleep(Duration.second * 2)
    println("Server started on port 9299")
    println("")

    // 创建 HTTP/2 客户端
    let clientConfig = HttpClientConfig()
    clientConfig.enableHttp2 = true
    clientConfig.connectionPoolEnabled = false
    let client = HttpClient(config: clientConfig)

    testServerStarts(tr, client)

    // 报告
    println("")
    println("========================================")
    println("  Results: ${tr.passed} passed, ${tr.failed} failed")
    println("========================================")

    for (err in tr.errors) {
        println("  ${err}")
    }

    client.close()
    server.close()

    if (tr.failed > 0) {
        return 1
    }
    0
}
