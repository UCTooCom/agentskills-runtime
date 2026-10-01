package ystyle::cordis_tests

import ystyle::cordis_host.{PluginManager, PluginInstance}
import ystyle::cordis_core.{PluginEntry, InstanceStatus}
import std.unittest.*
import std.unittest.testmacro.*

/**
 * PluginManager 测试：launch/terminate 生命周期 + isExited 崩溃自愈
 * 使用真实可执行文件作为"插件"（/bin/sh、/bin/true）
 *
 * 注：stderr 转发（forwardStderr）已移除——子进程 stderr 改为 Inherit 直接
 * 继承宿主 stderr（见 cordis_host/src/plugin_manager.cj 启动挂死修复），
 * 不再经 logger 回调，故本测试不再覆盖 stderr 转发行为。
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
