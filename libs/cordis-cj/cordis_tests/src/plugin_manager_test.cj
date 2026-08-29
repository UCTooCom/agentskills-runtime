package ystyle::cordis_tests

import ystyle::cordis_host.{PluginManager, PluginInstance}
import ystyle::cordis_core.{PluginEntry, InstanceStatus}
import std.collection.ArrayList
import std.sync.{Mutex, Condition}
import std.process.{launch, ProcessRedirect}
import std.io.StringReader
import std.unittest.*
import std.unittest.testmacro.*

/**
 * PluginManager 测试：launch/terminate 生命周期 + stderr 转发
 * 使用真实可执行文件作为"插件"（/bin/sh、/bin/true）
 */
@Test
class PluginManagerTest {

    @TestCase
    func testLaunchAndTerminate(): Unit {
        let manager = PluginManager()
        let entry = PluginEntry("true-plugin", "/bin/true")
        let instance = manager.launch(entry)
        @Expect(instance.entry.id, "true-plugin")
        @Expect(instance.status, InstanceStatus.Starting)
        @Expect(!manager.isExited(instance))
        let exitCode = manager.terminate(instance)
        @Expect(instance.status, InstanceStatus.Unloading)
        // /bin/true 正常退出码为 0；强杀后 wait 返回信号编号或退出码
        @Expect(exitCode >= 0)
    }

    @TestCase
    func testStderrForwarding(): Unit {
        // 用 sh 向 stderr 写一行，验证 forwardStderr 转发到 logger 回调
        let lines = ArrayList<String>()
        let lock = Mutex()
        let cond = synchronized(lock) { lock.condition() }
        let manager = PluginManager({ _, line =>
            synchronized(lock) {
                lines.add(line)
                cond.notifyAll()
            }
        })
        let entry = PluginEntry("err-plugin", "/bin/sh",
            args: ArrayList<String>.of(["-c", "echo hello-stderr >&2"]))
        let instance = manager.launch(entry)
        // 等待 stderr 行到达（最多 5 秒）
        synchronized(lock) {
            var waited = 0
            while (lines.size == 0 && waited < 100) {
                cond.wait(timeout: 50 * Duration.millisecond)
                waited++
            }
        }
        // 终止并回收
        manager.terminate(instance)
        @Expect(lines.size > 0)
        if (lines.size > 0) {
            @Expect(lines[0].contains("hello-stderr"))
        }
    }

    @TestCase
    func testIsExitedAfterProcessDeath(): Unit {
        // 启动后进程自然退出（/bin/true 立即退出）→ client 因 EOF 自动停止
        let manager = PluginManager()
        let entry = PluginEntry("quick-exit", "/bin/true")
        let instance = manager.launch(entry)
        // 轮询等待 client 关闭（最多 5 秒）
        var exited = false
        for (i in 0..100) {
            if (manager.isExited(instance)) {
                exited = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(exited)
        // 清理：进程已退出，wait 回收
        instance.process.wait()
    }
}
