package ystyle::cordis_tests

import ystyle::cordis_host.PipeTransport
import std.process.{launch, SubProcess, ProcessRedirect}
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

/**
 * PipeTransport 测试：用真实子进程 cat（stdin 回显到 stdout）验证管道收发
 */
@Test
class PipeTransportTest {

    private static func spawnCat(): (PipeTransport, SubProcess) {
        let proc = launch("/bin/cat", [],
            stdIn: ProcessRedirect.Pipe,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        (PipeTransport(proc), proc)
    }

    @TestCase
    func testSendReceiveEcho(): Unit {
        let (transport, proc) = spawnCat()
        let payload = "hello pipe".toArray()
        transport.send(payload)
        match (transport.receive()) {
            case Some(data) => @Expect(String.fromUtf8(data), "hello pipe")
            case None => @Fail("expected echo from cat")
        }
        // 清理：强制终止 cat 避免残留，wait 回收退出码
        proc.terminate(force: true)
        proc.wait()
    }

    @TestCase
    func testCloseThenIsClosed(): Unit {
        let (transport, proc) = spawnCat()
        @Expect(!transport.isClosed())
        transport.close()
        @Expect(transport.isClosed())
        proc.terminate(force: true)
        proc.wait()
    }

    @TestCase
    func testSendAfterCloseIsNoop(): Unit {
        let (transport, proc) = spawnCat()
        transport.close()
        // 关闭后 send 不抛异常（内部静默返回）
        transport.send("ignored".toArray())
        @Expect(transport.isClosed())
        proc.terminate(force: true)
        proc.wait()
    }

    @TestCase
    func testEofWhenProcessExits(): Unit {
        // /bin/true 立即退出：stdout EOF → receive 返回 None
        let proc = launch("/bin/true", [],
            stdIn: ProcessRedirect.Pipe,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let transport = PipeTransport(proc)
        // 子进程已退出，read 返回 0/EOF → None
        let result = transport.receive()
        @Expect(result.isNone())
        proc.wait()
    }

    @TestCase
    func testLongMessageRoundTrip(): Unit {
        // 超过单次管道读缓冲（4096）的消息往返：循环 receive 直到收满
        let (transport, proc) = spawnCat()
        var big = StringBuilder()
        for (i in 0..5000) {
            big.append("a")
        }
        let payload = big.toString().toArray()
        transport.send(payload)
        let buffer = ByteBuffer()
        var receivedCount: Int64 = 0
        while (receivedCount < payload.size) {
            match (transport.receive()) {
                case Some(data) =>
                    buffer.write(data)
                    receivedCount += data.size
                case None => break
            }
        }
        @Expect(receivedCount, payload.size)
        let received = String.fromUtf8(buffer.bytes())
        @Expect(received, big.toString())
        proc.terminate(force: true)
        proc.wait()
    }
}
