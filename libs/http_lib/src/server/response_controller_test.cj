/**
 * ResponseController 单元测试。
 *
 * 覆盖所有公共方法：
 * - flush() — 刷新缓冲
 * - hijack() — 劫持连接
 * - setReadDeadline() — 设置读取截止时间
 * - setWriteDeadline() — 设置写入截止时间
 * - enableFullDuplex() — 启用全双工模式
 */
package http_lib.server

import http_lib.core.{assertTrue, assertFalse}
import http_lib.connection.{Connection, MockConnection}
import std.time.DateTime

@Test
public class ResponseControllerTest {

    /**
     * 测试创建 ResponseController 并调用 flush 不抛出异常。
     */
    @TestCase
    public func testFlush(): Unit {
        let builder = ResponseBuilder()
        let conn: Connection = MockConnection([])
        let ctrl = ResponseController(builder, conn)
        ctrl.flush()
        assertTrue(true)
    }

    /**
     * 测试 hijack 返回底层连接。
     */
    @TestCase
    public func testHijackReturnsConnection(): Unit {
        let builder = ResponseBuilder()
        let conn: Connection = MockConnection([])
        let ctrl = ResponseController(builder, conn)
        let hijacked = ctrl.hijack()
        assertTrue(hijacked.isConnected())
    }

    /**
     * 测试设置读取截止时间不会抛出异常。
     */
    @TestCase
    public func testSetReadDeadline(): Unit {
        let builder = ResponseBuilder()
        let conn: Connection = MockConnection([])
        let ctrl = ResponseController(builder, conn)
        let future = DateTime.now() + Duration.second * 10
        ctrl.setReadDeadline(future)
        assertTrue(true)
    }

    /**
     * 测试设置写入截止时间不会抛出异常。
     */
    @TestCase
    public func testSetWriteDeadline(): Unit {
        let builder = ResponseBuilder()
        let conn: Connection = MockConnection([])
        let ctrl = ResponseController(builder, conn)
        let future = DateTime.now() + Duration.second * 10
        ctrl.setWriteDeadline(future)
        assertTrue(true)
    }

    /**
     * 测试设置过去的时间作为读取截止时间不会抛出异常。
     */
    @TestCase
    public func testSetReadDeadlinePast(): Unit {
        let builder = ResponseBuilder()
        let conn: Connection = MockConnection([])
        let ctrl = ResponseController(builder, conn)
        let past = DateTime.now() - Duration.second * 10
        ctrl.setReadDeadline(past)
        assertTrue(true)
    }

    /**
     * 测试 enableFullDuplex 不会抛出异常。
     */
    @TestCase
    public func testEnableFullDuplex(): Unit {
        let builder = ResponseBuilder()
        let conn: Connection = MockConnection([])
        let ctrl = ResponseController(builder, conn)
        ctrl.enableFullDuplex()
        assertTrue(true)
    }

    /**
     * 测试多次调用 flush 不抛出异常。
     */
    @TestCase
    public func testMultipleFlush(): Unit {
        let builder = ResponseBuilder()
        let conn: Connection = MockConnection([])
        let ctrl = ResponseController(builder, conn)
        ctrl.flush()
        ctrl.flush()
        ctrl.flush()
        assertTrue(true)
    }

    /**
     * 测试持劫持后原始控制器仍可正常使用。
     */
    @TestCase
    public func testHijackThenFlush(): Unit {
        let builder = ResponseBuilder()
        let conn: Connection = MockConnection([])
        let ctrl = ResponseController(builder, conn)
        let _ = ctrl.hijack()
        ctrl.flush()
        ctrl.enableFullDuplex()
        assertTrue(true)
    }
}
