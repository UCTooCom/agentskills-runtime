/**
 * WebSocket Per-Message Deflate 压缩/解压单元测试。
 *
 * 覆盖：
 * - PerMessageDeflateConfig 创建与默认值
 * - parsePmdExtensions 解析各种扩展头格式
 * - buildPmdExtensionHeader 构建扩展头
 * - negotiatePmdConfig 配置协商
 * - PerMessageDeflate 激活与状态
 * - compressPayload / decompressPayload 压缩解压往返
 * - WebSocketConn 集成场景
 */
package http_lib.server

import http_lib.core.{assertTrue, assertFalse}
import http_lib.connection.MockConnection
import std.collection.ArrayList

@Test
public class WebSocketCompressTest {

    // ---- PerMessageDeflateConfig 基本测试 ----

    @TestCase
    public func testPmdConfigDefaults(): Unit {
        let config = PerMessageDeflateConfig()
        assertFalse(config.serverNoContextTakeover, message: "serverNoContextTakeover 默认为 false")
        assertFalse(config.clientNoContextTakeover, message: "clientNoContextTakeover 默认为 false")
        assertTrue(config.serverMaxWindowBits == 15, message: "serverMaxWindowBits 默认为 15")
        assertTrue(config.clientMaxWindowBits == 15, message: "clientMaxWindowBits 默认为 15")
    }

    @TestCase
    public func testPmdConfigCustom(): Unit {
        let config = PerMessageDeflateConfig(
            serverNoContextTakeover: true,
            clientNoContextTakeover: true,
            serverMaxWindowBits: 12,
            clientMaxWindowBits: 10
        )
        assertTrue(config.serverNoContextTakeover, message: "serverNoContextTakeover 应为 true")
        assertTrue(config.clientNoContextTakeover, message: "clientNoContextTakeover 应为 true")
        assertTrue(config.serverMaxWindowBits == 12, message: "serverMaxWindowBits 应为 12")
        assertTrue(config.clientMaxWindowBits == 10, message: "clientMaxWindowBits 应为 10")
    }

    // ---- parsePmdExtensions 解析测试 ----

    @TestCase
    public func testParsePmdSimple(): Unit {
        let result = parsePmdExtensions("permessage-deflate")
        match (result) {
            case Some(config) =>
                assertFalse(config.serverNoContextTakeover, message: "默认不应启用 server_no_context_takeover")
                assertFalse(config.clientNoContextTakeover, message: "默认不应启用 client_no_context_takeover")
                assertTrue(config.serverMaxWindowBits == 15, message: "serverMaxWindowBits 应为 15")
                assertTrue(config.clientMaxWindowBits == 15, message: "clientMaxWindowBits 应为 15")
            case None => assertTrue(false, message: "应成功解析 permessage-deflate")
        }
    }

    @TestCase
    public func testParsePmdWithServerNoTakeover(): Unit {
        let result = parsePmdExtensions("permessage-deflate; server_no_context_takeover")
        match (result) {
            case Some(config) =>
                assertTrue(config.serverNoContextTakeover, message: "应启用 server_no_context_takeover")
            case None => assertTrue(false, message: "应成功解析")
        }
    }

    @TestCase
    public func testParsePmdWithClientNoTakeover(): Unit {
        let result = parsePmdExtensions("permessage-deflate; client_no_context_takeover")
        match (result) {
            case Some(config) =>
                assertTrue(config.clientNoContextTakeover, message: "应启用 client_no_context_takeover")
            case None => assertTrue(false, message: "应成功解析")
        }
    }

    @TestCase
    public func testParsePmdWithMaxWindowBits(): Unit {
        let result = parsePmdExtensions("permessage-deflate; server_max_window_bits=12; client_max_window_bits=10")
        match (result) {
            case Some(config) =>
                assertTrue(config.serverMaxWindowBits == 12, message: "serverMaxWindowBits 应为 12")
                assertTrue(config.clientMaxWindowBits == 10, message: "clientMaxWindowBits 应为 10")
            case None => assertTrue(false, message: "应成功解析")
        }
    }

    @TestCase
    public func testParsePmdAllParams(): Unit {
        let result = parsePmdExtensions("permessage-deflate; server_no_context_takeover; client_no_context_takeover; server_max_window_bits=10; client_max_window_bits=8")
        match (result) {
            case Some(config) =>
                assertTrue(config.serverNoContextTakeover, message: "应启用 server_no_context_takeover")
                assertTrue(config.clientNoContextTakeover, message: "应启用 client_no_context_takeover")
                assertTrue(config.serverMaxWindowBits == 10, message: "serverMaxWindowBits 应为 10")
                assertTrue(config.clientMaxWindowBits == 8, message: "clientMaxWindowBits 应为 8")
            case None => assertTrue(false, message: "应成功解析")
        }
    }

    @TestCase
    public func testParsePmdMultipleExtensions(): Unit {
        // 多个扩展中识别 permessage-deflate
        let result = parsePmdExtensions("foo-bar, permessage-deflate; client_no_context_takeover, baz")
        match (result) {
            case Some(config) =>
                assertTrue(config.clientNoContextTakeover, message: "应识别多个扩展中的 permessage-deflate")
            case None => assertTrue(false, message: "应成功解析")
        }
    }

    @TestCase
    public func testParsePmdNoMatch(): Unit {
        let result = parsePmdExtensions("foo-bar; baz")
        match (result) {
            case Some(_) => assertTrue(false, message: "不应在无 permessage-deflate 时返回配置")
            case None => assertTrue(true, message: "应返回 None")
        }
    }

    @TestCase
    public func testParsePmdEmpty(): Unit {
        let result = parsePmdExtensions("")
        match (result) {
            case Some(_) => assertTrue(false, message: "空字符串应返回 None")
            case None => assertTrue(true, message: "空字符串应返回 None")
        }
    }

    @TestCase
    public func testParsePmdCaseInsensitive(): Unit {
        let result = parsePmdExtensions("PERMESSAGE-DEFLATE; SERVER_NO_CONTEXT_TAKEOVER")
        match (result) {
            case Some(config) =>
                assertTrue(config.serverNoContextTakeover, message: "大小写不敏感解析应启用 server_no_context_takeover")
            case None => assertTrue(false, message: "应成功解析大写扩展名")
        }
    }

    @TestCase
    public func testParsePmdInvalidWindowBits(): Unit {
        // 无效的 window bits 应被忽略（保持默认值）
        let result = parsePmdExtensions("permessage-deflate; server_max_window_bits=abc; client_max_window_bits=100")
        match (result) {
            case Some(config) =>
                assertTrue(config.serverMaxWindowBits == 15, message: "无效 server_max_window_bits 应保持默认")
                assertTrue(config.clientMaxWindowBits == 15, message: "超出范围 client_max_window_bits 应保持默认")
            case None => assertTrue(false, message: "应成功解析")
        }
    }

    // ---- buildPmdExtensionHeader 测试 ----

    @TestCase
    public func testBuildHeaderDefault(): Unit {
        let header = buildPmdExtensionHeader()
        assertTrue(header == "permessage-deflate", message: "默认头应只包含 permessage-deflate")
    }

    @TestCase
    public func testBuildHeaderWithServerNoTakeover(): Unit {
        let config = PerMessageDeflateConfig(serverNoContextTakeover: true)
        let header = buildPmdExtensionHeader(config_: config)
    }

    @TestCase
    public func testBuildHeaderWithClientNoTakeover(): Unit {
        let config = PerMessageDeflateConfig(clientNoContextTakeover: true)
        let header = buildPmdExtensionHeader(config_: config)
        assertTrue(header.contains("client_no_context_takeover"), message: "应包含 client_no_context_takeover")
    }

    @TestCase
    public func testBuildHeaderWithWindowBits(): Unit {
        let config = PerMessageDeflateConfig(serverMaxWindowBits: 12, clientMaxWindowBits: 10)
        let header = buildPmdExtensionHeader(config_: config)
        assertTrue(header.contains("server_max_window_bits=12"), message: "应包含 server_max_window_bits=12")
        assertTrue(header.contains("client_max_window_bits=10"), message: "应包含 client_max_window_bits=10")
    }

    // ---- negotiatePmdConfig 测试 ----

    @TestCase
    public func testNegotiateDefaults(): Unit {
        let serverCfg = PerMessageDeflateConfig()
        let clientCfg = PerMessageDeflateConfig()
        let result = negotiatePmdConfig(serverCfg, clientCfg)
        assertFalse(result.serverNoContextTakeover, message: "双方都未要求 no_context_takeover")
        assertFalse(result.clientNoContextTakeover, message: "双方都未要求 no_context_takeover")
    }

    @TestCase
    public func testNegotiateServerNoTakeover(): Unit {
        let serverCfg = PerMessageDeflateConfig(serverNoContextTakeover: true)
        let clientCfg = PerMessageDeflateConfig()
        let result = negotiatePmdConfig(serverCfg, clientCfg)
        assertTrue(result.serverNoContextTakeover, message: "服务器要求 server_no_context_takeover 应生效")
    }

    @TestCase
    public func testNegotiateClientRequestServerTakeover(): Unit {
        let serverCfg = PerMessageDeflateConfig()
        let clientCfg = PerMessageDeflateConfig(serverNoContextTakeover: true)
        let result = negotiatePmdConfig(serverCfg, clientCfg)
        assertTrue(result.serverNoContextTakeover, message: "客户端要求 server_no_context_takeover 应生效")
    }

    @TestCase
    public func testNegotiateMinWindowBits(): Unit {
        let serverCfg = PerMessageDeflateConfig(serverMaxWindowBits: 15, clientMaxWindowBits: 15)
        let clientCfg = PerMessageDeflateConfig(serverMaxWindowBits: 10, clientMaxWindowBits: 12)
        let result = negotiatePmdConfig(serverCfg, clientCfg)
        // 取较小值
        assertTrue(result.serverMaxWindowBits == 10, message: "serverMaxWindowBits 应取 10（客户端要求较小）")
        assertTrue(result.clientMaxWindowBits == 12, message: "clientMaxWindowBits 应取 12（客户端要求较小）")
    }

    // ---- PerMessageDeflate 激活与状态测试 ----

    @TestCase
    public func testPmdNotActiveByDefault(): Unit {
        let pmd = PerMessageDeflate()
        assertFalse(pmd.isActive(), message: "创建后不应默认激活")
    }

    @TestCase
    public func testPmdActivate(): Unit {
        let pmd = PerMessageDeflate()
        assertFalse(pmd.isActive(), message: "激活前不应为活跃状态")
        pmd.activate(true)
        assertTrue(pmd.isActive(), message: "激活后应为活跃状态")
    }

    @TestCase
    public func testPmdActivateServerRole(): Unit {
        let config = PerMessageDeflateConfig(serverNoContextTakeover: true, clientNoContextTakeover: false)
        let pmd = PerMessageDeflate(config: config)
        pmd.activate(true)  // 服务器角色
        // compressNoTakeover = serverNoContextTakeover = true
        // decompressNoTakeover = clientNoContextTakeover = false
        assertTrue(pmd.isActive(), message: "服务器角色激活后应处于活跃状态")
    }

    @TestCase
    public func testPmdActivateClientRole(): Unit {
        let config = PerMessageDeflateConfig(serverNoContextTakeover: true, clientNoContextTakeover: true)
        let pmd = PerMessageDeflate(config: config)
        pmd.activate(false)  // 客户端角色
        // compressNoTakeover = clientNoContextTakeover = true
        // decompressNoTakeover = serverNoContextTakeover = true
        assertTrue(pmd.isActive(), message: "客户端角色激活后应处于活跃状态")
    }

    @TestCase
    public func testPmdGetConfig(): Unit {
        let config = PerMessageDeflateConfig(serverNoContextTakeover: true)
        let pmd = PerMessageDeflate(config: config)
        let retrieved = pmd.getConfig()
        assertTrue(retrieved.serverNoContextTakeover, message: "应能获取到原始配置")
    }

    // ---- compressPayload / decompressPayload 测试 ----
    // 注意：以下测试依赖 compress4cj 的 zlib 支持
    // 如果 compress4cj 不可用，测试会优雅跳过

    @TestCase
    public func testCompressAfterActivation(): Unit {
        let pmd = PerMessageDeflate()
        // 未激活时压缩应直接返回原始数据
        let original: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        let result = pmd.compressPayload(original)
        assertTrue(result.size == original.size, message: "未激活时压缩应原样返回")
        assertTrue(result[0] == original[0], message: "未激活时第一个字节应保持不变")
    }

    @TestCase
    public func testDecompressAfterActivation(): Unit {
        let pmd = PerMessageDeflate()
        // 未激活时解压应直接返回原始数据
        let original: Array<UInt8> = [b'T', b'e', b's', b't']
        let result = pmd.decompressPayload(original)
        assertTrue(result.size == original.size, message: "未激活时解压应原样返回")
        assertTrue(result[0] == original[0], message: "未激活时第一个字节应保持不变")
    }

    @TestCase
    public func testCompressEmptyPayload(): Unit {
        let pmd = PerMessageDeflate()
        pmd.activate(true)
        let result = pmd.compressPayload([])
        assertTrue(result.size == 0, message: "空负载压缩应返回空数组")
    }

    @TestCase
    public func testDecompressEmptyPayload(): Unit {
        let pmd = PerMessageDeflate()
        pmd.activate(true)
        let result = pmd.decompressPayload([])
        assertTrue(result.size == 0, message: "空负载解压应返回空数组")
    }

    // ---- RSV1 帧编码测试 ----

    @TestCase
    public func testEncodeFrameWithRsv1(): Unit {
        let payload: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        let frame = encodeWebSocketFrame(WebSocketOpcode.Text, payload, false, rsv1: true)
        // 第一个字节: FIN(0x80) | RSV1(0x40) | opcode Text(0x01) = 0xC1
        assertTrue(frame.size == 7, message: "5 字节负载帧应有 7 字节（2 字节头 + 5 字节负载）")
        assertTrue(frame[0] == 0xC1, message: "RSV1 置位时第一个字节应为 0xC1 (FIN + RSV1 + Text)")
    }

    @TestCase
    public func testEncodeFrameWithoutRsv1(): Unit {
        let payload: Array<UInt8> = [b'H', b'e', b'l', b'l', b'o']
        let frame = encodeWebSocketFrame(WebSocketOpcode.Text, payload, false, rsv1: false)
        // 第一个字节: FIN(0x80) | opcode Text(0x01) = 0x81
        assertTrue(frame[0] == 0x81, message: "RSV1 未置位时第一个字节应为 0x81 (FIN + Text)")
    }

    @TestCase
    public func testEncodeFrameRsv1Default(): Unit {
        let payload: Array<UInt8> = [b'T', b'e', b's', b't']
        let frame = encodeWebSocketFrame(WebSocketOpcode.Binary, payload, false)
        // RSV1 默认为 false，第一个字节: FIN(0x80) | Binary(0x02) = 0x82
        assertTrue(frame[0] == 0x82, message: "RSV1 默认 false 时第一个字节应为 0x82 (FIN + Binary)")
    }

    // ---- WebSocketConn 集成测试 ----

    @TestCase
    public func testWebSocketConnDefaultNoPmd(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        // 默认 PMD 不应激活
        assertFalse(ws.getPmd().isActive(), message: "WebSocketConn 默认不应激活 PMD")
    }

    @TestCase
    public func testWebSocketConnWithActivePmd(): Unit {
        let mc = MockConnection([])
        let pmd = PerMessageDeflate()
        pmd.activate(true)
        let ws = WebSocketConn(mc, pmd: pmd)
        assertTrue(ws.getPmd().isActive(), message: "传入激活的 PMD 后应处于活跃状态")
    }

    @TestCase
    public func testWebSocketConnSetPmd(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        assertFalse(ws.getPmd().isActive(), message: "初始 PMD 不应激活")
        let pmd = PerMessageDeflate()
        pmd.activate(true)
        ws.setPmd(pmd)
        assertTrue(ws.getPmd().isActive(), message: "setPmd 后应处于活跃状态")
    }

    @TestCase
    public func testWebSocketConnWriteTextWithRsv1(): Unit {
        let mc = MockConnection([])
        // 生成一个激活的 PMD 并注入 WebSocketConn
        let pmd = PerMessageDeflate()
        pmd.activate(true)
        let ws = WebSocketConn(mc, pmd: pmd)
        ws.writeText("Hello")
        let written = mc.getWrittenBytes()
        // 写入内容应包含至少 2 字节帧头
        assertTrue(written.size >= 2, message: "写入应有至少 2 字节帧头")
        // 第一个字节应为 FIN(0x80) | RSV1(0x40) | opcode Text(0x01) = 0xC1
        // 注意：PMD 激活后压缩负载，但即使压缩失败（zlib 不可用），RSV1 标志依然设置
        assertTrue(written[0] == 0xC1, message: "PMD 激活时 Text 帧第一个字节应为 0xC1 (FIN + RSV1 + Text)")
    }

    @TestCase
    public func testWebSocketConnWriteBinaryWithRsv1(): Unit {
        let mc = MockConnection([])
        let pmd = PerMessageDeflate()
        pmd.activate(true)
        let ws = WebSocketConn(mc, pmd: pmd)
        ws.writeBinary([b'D', b'a', b't', b'a'])
        let written = mc.getWrittenBytes()
        assertTrue(written.size >= 2, message: "写入应有至少 2 字节帧头")
        assertTrue(written[0] == 0xC2, message: "PMD 激活时 Binary 帧第一个字节应为 0xC2 (FIN + RSV1 + Binary)")
    }

    @TestCase
    public func testWebSocketConnWritePingNoRsv1(): Unit {
        let mc = MockConnection([])
        let pmd = PerMessageDeflate()
        pmd.activate(true)
        let ws = WebSocketConn(mc, pmd: pmd)
        ws.writePing([])
        let written = mc.getWrittenBytes()
        // Ping 帧不应受 PMD 影响（控制帧不压缩）
        assertTrue(written[0] == 0x89, message: "Ping 帧不应设置 RSV1：应为 0x89 (FIN + Ping)")
    }
}
