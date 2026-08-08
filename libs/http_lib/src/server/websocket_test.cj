package http_lib.server

import http_lib.core.{assertTrue, assertFalse}
import http_lib.connection.MockConnection
import std.collection.ArrayList

/**
 * WebSocket 消息和连接的单元测试。
 */
@Test
public class WebSocketTest {

    // ---- WebSocketMessage 类型检查 ----

    @TestCase
    public func testTextMessageType(): Unit {
        let msg = WebSocketMessage(opcode: WebSocketOpcode.Text, data: [])
        assertTrue(msg.isText(), message: "文本消息 isText() 应为 true")
        assertFalse(msg.isBinary(), message: "文本消息 isBinary() 应为 false")
        assertFalse(msg.isPing(), message: "文本消息 isPing() 应为 false")
        assertFalse(msg.isPong(), message: "文本消息 isPong() 应为 false")
        assertFalse(msg.isClose(), message: "文本消息 isClose() 应为 false")
    }

    @TestCase
    public func testBinaryMessageType(): Unit {
        let msg = WebSocketMessage(opcode: WebSocketOpcode.Binary, data: [0x01, 0x02])
        assertFalse(msg.isText(), message: "二进制消息 isText() 应为 false")
        assertTrue(msg.isBinary(), message: "二进制消息 isBinary() 应为 true")
    }

    @TestCase
    public func testPingMessageType(): Unit {
        let msg = WebSocketMessage(opcode: WebSocketOpcode.Ping, data: [])
        assertTrue(msg.isPing(), message: "Ping 消息 isPing() 应为 true")
    }

    @TestCase
    public func testPongMessageType(): Unit {
        let msg = WebSocketMessage(opcode: WebSocketOpcode.Pong, data: [])
        assertTrue(msg.isPong(), message: "Pong 消息 isPong() 应为 true")
    }

    @TestCase
    public func testCloseMessageType(): Unit {
        let msg = WebSocketMessage(opcode: WebSocketOpcode.Close, data: [0x03, 0xe8])
        assertTrue(msg.isClose(), message: "Close 消息 isClose() 应为 true")
    }

    // ---- WebSocketMessage 文本内容 ----

    @TestCase
    public func testTextMessageContent(): Unit {
        let helloBytes = unsafe { "你好，WebSocket".rawData() }
        let msg = WebSocketMessage(opcode: WebSocketOpcode.Text, data: helloBytes)
        assertTrue(msg.text() == "你好，WebSocket", message: "文本内容应正确")
        assertTrue(msg.isText(), message: "应为文本类型")
    }

    @TestCase
    public func testEmptyTextMessage(): Unit {
        let msg = WebSocketMessage(opcode: WebSocketOpcode.Text, data: [])
        assertTrue(msg.text() == "", message: "空文本消息应返回空字符串")
    }

    // ---- WebSocketMessage 操作码一致性 ----

    @TestCase
    public func testOpcodeConsistency(): Unit {
        let ops: Array<WebSocketOpcode> = [
            WebSocketOpcode.Text, WebSocketOpcode.Binary,
            WebSocketOpcode.Ping, WebSocketOpcode.Pong,
            WebSocketOpcode.Close
        ]
        for (op in ops) {
            let msg = WebSocketMessage(opcode: op, data: [])
            match (op) {
                case WebSocketOpcode.Text => assertTrue(msg.isText())
                case WebSocketOpcode.Binary => assertTrue(msg.isBinary())
                case WebSocketOpcode.Ping => assertTrue(msg.isPing())
                case WebSocketOpcode.Pong => assertTrue(msg.isPong())
                case WebSocketOpcode.Close => assertTrue(msg.isClose())
                case _ => assertTrue(false, message: "未识别的操作码")
            }
        }
    }

    // ---- WebSocketConn 基础操作 ----

    @TestCase
    public func testWebSocketConnInitialState(): Unit {
        let conn = MockConnection([])
        let ws = WebSocketConn(conn)
        assertFalse(ws.isClosed(), message: "新建连接不应处于关闭状态")
    }

    @TestCase
    public func testWebSocketConnWriteText(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        ws.writeText("你好")
        let written = mc.getWrittenBytes()
        assertTrue(written.size > 0, message: "写入文本后应有数据")
        // 检查帧头：FIN=1, opcode=Text(0x01) => 0x81
        assertTrue(written[0] == 0x81, message: "文本帧第一个字节应为 0x81")
    }

    @TestCase
    public func testWebSocketConnWriteBinary(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        ws.writeBinary([0x01, 0x02, 0x03])
        let written = mc.getWrittenBytes()
        assertTrue(written.size > 0, message: "写入二进制后应有数据")
        assertTrue(written[0] == 0x82, message: "二进制帧第一个字节应为 0x82")
    }

    @TestCase
    public func testWebSocketConnWritePing(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        ws.writePing([])
        let written = mc.getWrittenBytes()
        assertTrue(written.size > 0, message: "写入 Ping 后应有数据")
        assertTrue(written[0] == 0x89, message: "Ping 帧第一个字节应为 0x89")
    }

    @TestCase
    public func testWebSocketConnWritePong(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        ws.writePong([])
        let written = mc.getWrittenBytes()
        assertTrue(written.size > 0, message: "写入 Pong 后应有数据")
        assertTrue(written[0] == 0x8A, message: "Pong 帧第一个字节应为 0x8A")
    }

    @TestCase
    public func testWebSocketConnWritePingNoPayload(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        ws.writePing()
        let written = mc.getWrittenBytes()
        assertTrue(written.size > 0, message: "写入空 Ping 后应有数据")
        assertTrue(written[0] == 0x89, message: "Ping 帧第一个字节应为 0x89")
    }

    @TestCase
    public func testWebSocketConnClose(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        assertFalse(ws.isClosed(), message: "关闭前不应显示已关闭")
        ws.close(1000)
        assertTrue(ws.isClosed(), message: "关闭后应显示已关闭")
        let written = mc.getWrittenBytes()
        assertTrue(written.size > 0, message: "关闭后应有数据")
        assertTrue(written[0] == 0x88, message: "Close 帧第一个字节应为 0x88")
    }

    @TestCase
    public func testWebSocketConnCloseMultipleTimes(): Unit {
        let mc = MockConnection([])
        let ws = WebSocketConn(mc)
        ws.close(1000)
        let count1 = mc.getWriteCount()
        ws.close(1001) // 第二次关闭应被忽略
        let count2 = mc.getWriteCount()
        assertTrue(count1 == count2, message: "重复关闭不应增加写入次数")
        assertTrue(ws.isClosed(), message: "关闭后应保持关闭状态")
    }

    // ---- WebSocketConn 读取消息 ----

    @TestCase
    public func testWebSocketConnReadTextFrame(): Unit {
        // 构造一个未掩码的文本帧："Hello"
        let frameData: Array<UInt8> = [
            0x81,  // FIN + 文本操作码
            0x05,  // 负载长度 = 5
            b'H', b'e', b'l', b'l', b'o'
        ]
        let mc = MockConnection(frameData)
        let ws = WebSocketConn(mc)
        let msg = ws.readMessage()
        assertTrue(msg.isSome(), message: "应读取到消息")
        match (msg) {
            case Some(m) =>
                assertTrue(m.isText(), message: "应为文本消息")
                assertTrue(m.text() == "Hello", message: "文本内容应为 Hello")
            case None => assertTrue(false, message: "读取消息失败")
        }
    }

    @TestCase
    public func testWebSocketConnReadBinaryFrame(): Unit {
        let frameData: Array<UInt8> = [
            0x82,  // FIN + 二进制操作码
            0x03,  // 负载长度 = 3
            0x01, 0x02, 0x03
        ]
        let mc = MockConnection(frameData)
        let ws = WebSocketConn(mc)
        let msg = ws.readMessage()
        assertTrue(msg.isSome(), message: "应读取到二进制消息")
        match (msg) {
            case Some(m) =>
                assertTrue(m.isBinary(), message: "应为二进制消息")
                assertTrue(m.data.size == 3, message: "数据长度应为 3")
            case None => assertTrue(false, message: "读取二进制消息失败")
        }
    }

    @TestCase
    public func testWebSocketConnReadCloseFrame(): Unit {
        // 构造一个 Close 帧：状态码 1000 (0x03e8)
        let frameData: Array<UInt8> = [
            0x88,  // FIN + 关闭操作码
            0x02,  // 负载长度 = 2
            0x03, 0xe8
        ]
        let mc = MockConnection(frameData)
        let ws = WebSocketConn(mc)
        let msg = ws.readMessage()
        assertTrue(msg.isSome(), message: "应读取到关闭消息")
        match (msg) {
            case Some(m) =>
                assertTrue(m.isClose(), message: "应为关闭消息")
            case None => assertTrue(false, message: "读取关闭消息失败")
        }
        assertTrue(ws.isClosed(), message: "收到 Close 帧后应关闭")
    }

    @TestCase
    public func testWebSocketConnReadPingPongHandling(): Unit {
        // Ping 帧后紧跟文本帧：Ping 应被自动响应，文本帧应被读取
        let pingFrame: Array<UInt8> = [
            0x89,  // FIN + Ping 操作码
            0x00   // 空负载
        ]
        let textFrame: Array<UInt8> = [
            0x81,  // FIN + 文本操作码
            0x01,  // 负载长度 = 1
            b'A'
        ]
        let combined = ArrayList<UInt8>()
        for (b in pingFrame) { combined.add(b) }
        for (b in textFrame) { combined.add(b) }
        let mc = MockConnection(combined.toArray())
        let ws = WebSocketConn(mc)
        // 读取时应跳过 Ping 帧自动响应 Pong，并读取文本帧
        let msg = ws.readMessage()
        assertTrue(msg.isSome(), message: "Ping 后应读取到文本消息")
        match (msg) {
            case Some(m) =>
                assertTrue(m.isText(), message: "应为文本消息")
                assertTrue(m.text() == "A", message: "文本内容应为 A")
            case None => assertTrue(false, message: "读取消息失败")
        }
    }
}
