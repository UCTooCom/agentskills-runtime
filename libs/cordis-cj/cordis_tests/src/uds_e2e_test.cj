package ystyle::cordis_tests

import ystyle::cordis_host.*
import ystyle::cordis_core.*
import ystyle::jsonrpc.*
import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.sync.Mutex
import std.fs.{Path, exists, File, OpenMode, removeIfExists}
import std.env.getProcessId
import std.unittest.*
import std.unittest.testmacro.*

/**
 * UDS 模式端到端测试（docs/design-impl.md §3.4）
 *
 * 真实宿主（PluginHost + PluginManager(udsPath)）拉起真实插件进程
 * （ystyle::cordis_plugin.examples.e2e，支持 --uds 参数），验证
 * UDS 传输下的握手/服务注册/invoke 转发/热卸载全流程。
 *
 * 与 EndToEndTest（stdio）的区别：宿主 bind UnixServerSocket，插件
 * 经 --uds <path> 参数连接上来，使用 ContentLengthFraming。
 */
@Test
class UdsModeEndToEndTest {

    // 每次测试独立 socket 路径（pid 隔离并发）
    private static func sockPath(tag: String): String {
        "/tmp/cordis_e2e_${tag}_${getProcessId()}.sock"
    }

    private static func pluginBinary(): String {
        "./target/release/bin/ystyle::cordis_plugin.examples.e2e"
    }

    @TestCase
    func testUdsPluginLifecycle(): Unit {
        // 前置：插件二进制存在
        @Expect(exists(Path(pluginBinary())))
        let path = sockPath("life")
        removeIfExists(Path(path))
        let manager = PluginManager(path)
        let host = PluginHost(manager)
        let entry = PluginEntry("e2e-uds", pluginBinary(),
            provide: ArrayList<String>.of(["echo", "add"]))

        // 1. 拉起插件（UDS：宿主 bind + spawn，插件 connect，宿主 accept）
        let instance = host.launchPlugin(entry)

        // 2. 等待插件 Active（initialize 握手完成）+ 服务注册完成
        var active = false
        for (i in 0..200) {
            if (instance.status == InstanceStatus.Active) {
                active = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(active)
        @Expect(host.state.hasService("echo"))
        @Expect(host.state.hasService("add"))

        // 3. invoke 转发：宿主 → 插件服务调用（add 2+3=5）
        let invokeResult = instance.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                [JsonValue.Number(2.0), JsonValue.Number(3.0)]))))
        match (invokeResult) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 5.0)
                    case _ => @Fail("expected number result")
                }
            case Err(e) => @Fail("uds invoke failed: ${e}")
        }

        // echo 服务
        let echoResult = instance.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("echo", "echo",
                [JsonValue.String("hello-uds")]))))
        match (echoResult) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.String(s) => @Expect(s, "hello-uds")
                    case _ => @Fail("expected string result")
                }
            case Err(e) => @Fail("uds echo failed: ${e}")
        }

        // 4. 热卸载：终止插件，服务注册表清理
        host.removePlugin("e2e-uds")
        @Expect(!host.state.hasService("echo"))
        @Expect(!host.state.hasService("add"))
        @Expect(host.state.actual.size, 0)

        // 5. 关闭 UDS 监听 + 清理 socket 文件
        manager.close()
        removeIfExists(Path(path))
    }

    @TestCase
    func testUdsReconcileFromConfig(): Unit {
        // 写一个临时 TOML（transport=uds），验证宿主按服务参数拉起插件
        let path = sockPath("recon")
        removeIfExists(Path(path))
        let configPath = "./.e2e_uds_config.toml"
        let toml = """
            interval = 5
            ping_interval = 30
            transport = "uds"
            uds_path = "${path}"

            [[plugins]]
            id = "e2e-uds"
            source = "${pluginBinary()}"
            provide = ["echo", "add"]
        """
        let file = File(configPath, OpenMode.Write)
        file.write(toml.toArray())
        file.flush()

        // 宿主应用侧：读配置 → 按 transport 构造 UDS 模式 PluginManager
        let cfg = ConfigLoader.load(configPath)
        @Expect(cfg.transport, "uds")
        @Expect(cfg.udsPath, path)

        let manager = PluginManager(cfg.udsPath)
        let host = PluginHost(manager)
        host.reconcile(configPath)

        // 等待插件 Active + 服务注册
        var ready = false
        for (i in 0..200) {
            if (host.state.hasService("echo") && host.state.hasService("add")) {
                ready = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(ready)

        // 通过 UDS invoke 验证
        let inst = host.state.getInstance("e2e-uds")
        match (inst) {
            case Some(instance) =>
                let result = instance.client.call<JsonValue, JsonValue>("invoke",
                    params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                        [JsonValue.Number(7.0), JsonValue.Number(8.0)]))))
                match (result) {
                    case Ok(v) =>
                        match (v) {
                            case JsonValue.Number(n) => @Expect(n, 15.0)
                            case _ => @Fail("expected 15")
                        }
                    case Err(e) => @Fail("uds reconcile invoke failed: ${e}")
                }
            case None => @Fail("instance not found")
        }

        // 清理
        host.removePlugin("e2e-uds")
        manager.close()
        removeIfExists(Path(configPath))
        removeIfExists(Path(path))
    }

    @TestCase
    func testUdsCrashRestart(): Unit {
        // UDS 模式崩溃自愈：插件被杀 → socket EOF → 检测退出 → 重启
        let path = sockPath("crash")
        removeIfExists(Path(path))
        let manager = PluginManager(path)
        let host = PluginHost(manager)
        let entry = PluginEntry("e2e-uds", pluginBinary(),
            provide: ArrayList<String>.of(["echo", "add"]))
        let instance = host.launchPlugin(entry)

        var active = false
        for (i in 0..200) {
            if (instance.status == InstanceStatus.Active) {
                active = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(active)

        // 强制杀死进程（模拟崩溃）→ socket 关闭
        instance.process.terminate(force: true)
        instance.process.wait()

        // 期望检测到退出（UDS EOF）
        host.state.addDesired(entry)
        var exited = false
        for (i in 0..100) {
            if (manager.isExited(instance)) {
                exited = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(exited)

        // 触发调谐 → 重启（UDS 监听复用）
        host.reconcileDesired()
        var restarted = false
        for (i in 0..200) {
            let inst = host.state.getInstance("e2e-uds")
            match (inst) {
                case Some(i2) =>
                    if (i2.status == InstanceStatus.Active) {
                        restarted = true
                        break
                    }
                case None => ()
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(restarted)

        host.removePlugin("e2e-uds")
        manager.close()
        removeIfExists(Path(path))
    }
}
