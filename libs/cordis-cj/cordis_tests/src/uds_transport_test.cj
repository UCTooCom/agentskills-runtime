package ystyle::cordis_tests

import ystyle::jsonrpc.{JsonRpcClient, JsonRpcServer, ContentLengthFraming, HandlerResult}
import ystyle::jsonrpc_unix.{UnixServerTransport, UnixClientTransport, UnixConnectionTransport}
import jsonvalue.*
import std.fs.{removeIfExists, exists, Path}
import std.env.getProcessId
import std.unittest.*
import std.unittest.testmacro.*

/**
 * UDS（Unix Domain Socket）传输层测试（docs/design-impl.md §3.4）
 *
 * 验证 jsonrpc_unix 提供的 UDS 传输在 cordis 场景下的可用性：
 * - 回环：UnixServerTransport（监听）+ UnixClientTransport（连接）走通
 *   JsonRpcClient/Server 完整请求-响应（Content-Length 帧）
 * - 生命周期：对端关闭 → receive 返回 None → isClosed 感知
 * - 残留 socket 文件清理
 *
 * 说明：UDS 仅支持 Linux/macOS（std.net 文档明确不支持 Windows），
 * 本测试在 CI/Linux 下运行；stdio 模式测试不受影响。
 */
@Test
class UdsTransportTest {

    // 测试 socket 路径（每次用 pid 避免并发冲突；测试前清理残留）
    private static func sockPath(tag: String): String {
        "/tmp/cordis_uds_${tag}_${getProcessId()}.sock"
    }

    @TestCase
    func testEchoRoundTrip(): Unit {
        let path = sockPath("echo")
        removeIfExists(Path(path))   // 清理上次残留（bind 要求文件不存在）
        let server = UnixServerTransport(path)
        // 客户端连接（UDS connect 进入 backlog，无需先 accept）
        let client = UnixClientTransport(path)

        // 宿主侧（接受连接）
        let conn = server.acceptConnection()
        @Expect(conn.isSome())
        let connTransport = match (conn) {
            case Some(t) => t
            case None => return
        }

        // 传输两端配 JSON-RPC：服务端（连接侧）+ 客户端（连接侧）
        let rpcServer = JsonRpcServer(connTransport, framing: ContentLengthFraming())
        rpcServer.register("echo", { ctx =>
            match (ctx.getRawParams()) {
                case Some(p) => HandlerResult.ok(p)
                case None => HandlerResult.ok(JsonValue.Null)
            }
        })
        rpcServer.start()

        let rpcClient = JsonRpcClient(client, framing: ContentLengthFraming())
        rpcClient.start()

        // 请求-响应回环
        let result = rpcClient.call<JsonValue, JsonValue>("echo",
            params: Some(JsonValue.String("uds-hello")))
        match (result) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.String(s) => @Expect(s, "uds-hello")
                    case _ => @Fail("expected string result")
                }
            case Err(e) => @Fail("uds echo failed: ${e}")
        }

        // 数字参数回环
        let result2 = rpcClient.call<JsonValue, JsonValue>("echo",
            params: Some(JsonValue.Number(42.0)))
        match (result2) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 42.0)
                    case _ => @Fail("expected number result")
                }
            case Err(e) => @Fail("uds echo number failed: ${e}")
        }

        // 清理
        rpcClient.close()
        rpcServer.close()
        server.close()
        removeIfExists(Path(path))
    }

    @TestCase
    func testUdsTransportLifecycle(): Unit {
        let path = sockPath("lifecycle")
        removeIfExists(Path(path))
        let server = UnixServerTransport(path)
        let client = UnixClientTransport(path)

        let conn = server.acceptConnection()
        @Expect(conn.isSome())
        let connTransport = match (conn) {
            case Some(t) => t
            case None => return
        }

        // 初始未关闭
        @Expect(!connTransport.isClosed())
        @Expect(!client.isClosed())

        // 服务端关闭 → 对端（客户端）receive 返回 None（EOF 语义），随后 isClosed 为 true
        connTransport.close()
        @Expect(connTransport.isClosed())
        @Expect(client.receive().isNone())
        @Expect(client.isClosed())

        // 已关闭的传输层 send 不抛异常（静默丢弃）
        client.close()
        client.send(Array<Byte>(3, repeat: 1))

        server.close()
        removeIfExists(Path(path))
    }

    @TestCase
    func testServerAcceptsMultipleConnections(): Unit {
        let path = sockPath("multi")
        removeIfExists(Path(path))
        let server = UnixServerTransport(path)

        // 两个客户端先后连接，均可被 accept
        let client1 = UnixClientTransport(path)
        let conn1 = server.acceptConnection()
        @Expect(conn1.isSome())

        let client2 = UnixClientTransport(path)
        let conn2 = server.acceptConnection()
        @Expect(conn2.isSome())

        match (conn1) {
            case Some(t) => t.close()
            case None => ()
        }
        match (conn2) {
            case Some(t) => t.close()
            case None => ()
        }
        client1.close()
        client2.close()
        server.close()
        removeIfExists(Path(path))
    }

    @TestCase
    func testServerCloseRejectsFurtherConnections(): Unit {
        let path = sockPath("closed")
        removeIfExists(Path(path))
        let server = UnixServerTransport(path)
        let client = UnixClientTransport(path)
        let conn = server.acceptConnection()
        @Expect(conn.isSome())
        match (conn) {
            case Some(t) => t.close()
            case None => ()
        }
        client.close()
        server.close()

        // server 关闭后 acceptConnection 返回 None
        @Expect(server.acceptConnection().isNone())
        removeIfExists(Path(path))
    }

    @TestCase
    func testResidualSocketFileCleanup(): Unit {
        // 场景：上次运行留下 socket 文件 → bind 前 remove 后可重新绑定
        let path = sockPath("residual")
        removeIfExists(Path(path))

        // 第一次绑定 + 关闭（文件残留）
        let server1 = UnixServerTransport(path)
        server1.close()

        // 第二次绑定前清理 → 成功
        removeIfExists(Path(path))
        let server2 = UnixServerTransport(path)
        server2.close()
        removeIfExists(Path(path))
        @Expect(!exists(Path(path)))
    }
}
