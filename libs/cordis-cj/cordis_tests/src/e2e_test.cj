package ystyle::cordis_tests

import ystyle::cordis_host.*
import ystyle::cordis_core.*
import ystyle::jsonrpc.*
import jsonvalue.*
import std.collection.{HashMap, ArrayList}
import std.sync.Mutex
import std.fs.{Path, exists, File, OpenMode, remove}
import std.unittest.*
import std.unittest.testmacro.*

/**
 * 端到端测试：真实宿主（PluginHost + PluginManager + PipeTransport）
 * 拉起真实插件进程（ystyle::cordis_plugin.examples.e2e），验证
 * 握手/服务注册/invoke 转发/热卸载/崩溃自愈全流程。
 *
 * 插件可执行文件通过 workspace build 产出：
 *   target/release/bin/ystyle::cordis_plugin.examples.e2e
 */
@Test
class EndToEndTest {

    // 定位插件可执行文件（相对 workspace 根）
    private static func pluginBinary(): String {
        "./target/release/bin/ystyle::cordis_plugin.examples.e2e"
    }

    private static func makeEntry(): PluginEntry {
        PluginEntry("e2e-plugin", pluginBinary(),
            provide: ArrayList<String>.of(["echo", "add"]))
    }

    @TestCase
    func testFullLifecycle(): Unit {
        // 前置：插件二进制存在
        @Expect(exists(Path(pluginBinary())))
        let manager = PluginManager()
        let host = PluginHost(manager)
        let entry = makeEntry()

        // 1. 拉起插件（启动握手在后台完成）
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

        // 3. invoke 转发：宿主 → 插件服务调用
        // 宿主侧用 instance.client 向插件发 invoke 请求
        let invokeResult = instance.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                [JsonValue.Number(2.0), JsonValue.Number(3.0)]))))
        match (invokeResult) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 5.0)
                    case _ => @Fail("expected number result")
                }
            case Err(e) => @Fail("invoke failed: ${e}")
        }

        // echo 服务
        let echoResult = instance.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("echo", "echo",
                [JsonValue.String("hello-cordis")]))))
        match (echoResult) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.String(s) => @Expect(s, "hello-cordis")
                    case _ => @Fail("expected string result")
                }
            case Err(e) => @Fail("echo failed: ${e}")
        }

        // 4. 热卸载：终止插件，服务注册表清理
        host.removePlugin("e2e-plugin")
        @Expect(!host.state.hasService("echo"))
        @Expect(!host.state.hasService("add"))
        @Expect(host.state.actual.size, 0)
    }

    @TestCase
    func testReconcileFromConfig(): Unit {
        // 写一个临时 TOML 配置，验证 Reconciler 从配置拉起插件
        let configPath = "./.e2e_config.toml"
        let toml = """
            interval = 5
            ping_interval = 30

            [[plugins]]
            id = "e2e-plugin"
            source = "${pluginBinary()}"
            provide = ["echo", "add"]
        """
        let file = File(configPath, OpenMode.Write)
        file.write(toml.toArray())
        file.flush()

        let manager = PluginManager()
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

        // 清理
        host.removePlugin("e2e-plugin")
        remove(Path(configPath))
    }

    @TestCase
    func testCrashRestart(): Unit {
        // 崩溃自愈：插件进程被杀后，下一次调谐自动重启
        let manager = PluginManager()
        let host = PluginHost(manager)
        let entry = makeEntry()
        let instance = host.launchPlugin(entry)

        // 等 Active
        var active = false
        for (i in 0..200) {
            if (instance.status == InstanceStatus.Active) {
                active = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(active)

        // 强制杀死进程（模拟崩溃）
        instance.process.terminate(force: true)
        instance.process.wait()

        // 下一次调谐应检测到崩溃并重启（desired 仍存在）
        // 手动构造 desired 状态并触发 healCrashed
        // 注：reconcileDesired 需要 desired 有该条目；通过 addDesired 模拟
        host.state.addDesired(entry)
        // 等待 client 检测到 EOF（isExited）
        var exited = false
        for (i in 0..100) {
            if (manager.isExited(instance)) {
                exited = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(exited)
        // 触发调谐
        host.reconcileDesired()
        // 等待新实例出现且 Active
        var restarted = false
        for (i in 0..200) {
            let inst = host.state.getInstance("e2e-plugin")
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
        // 清理
        host.removePlugin("e2e-plugin")
    }

    @TestCase
    func testDependencyWaitingLifecycle(): Unit {
        // Waiting 重试端到端（对齐 Cordis PENDING，docs/cordis-comparison.md §4）：
        // 消费者（inject_demo，依赖 add）先启动 → 依赖缺失 → 保持 Pending 等待；
        // 提供者（e2e 插件提供 add）后启动 → 消费者自动重试握手成功 → Active。
        let consumerBinary = "./target/release/bin/ystyle::cordis_plugin.examples.inject_demo"
        let providerBinary = "./target/release/bin/ystyle::cordis_plugin.examples.e2e"
        @Expect(exists(Path(consumerBinary)))
        @Expect(exists(Path(providerBinary)))

        let host = PluginHost(PluginManager())

        // 1. 先启动消费者（依赖 add 尚未就绪）→ 应进入 Pending 而非退出/Active
        let consumer = host.launchPlugin(PluginEntry("inject-demo", consumerBinary,
            provide: ArrayList<String>.of(["calc"])))
        var pending = false
        for (i in 0..100) {
            if (consumer.status == InstanceStatus.Pending) {
                pending = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(pending)
        @Expect(!host.state.hasService("add"))   // 依赖尚未提供

        // 2. 提供者后启动（注册 add 服务）
        let providerEntry = PluginEntry("e2e-provider", providerBinary,
            provide: ArrayList<String>.of(["echo", "add"]))
        host.launchPlugin(providerEntry)
        // 等待 add 服务注册
        var providerReady = false
        for (i in 0..100) {
            if (host.state.hasService("add")) {
                providerReady = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(providerReady)

        // 3. 消费者应自动重试握手成功 → Active（插件侧 Pending 重试循环）
        var active = false
        for (i in 0..200) {
            if (consumer.status == InstanceStatus.Active) {
                active = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(active)

        // 4. 验证消费者服务可用（calc → 内部经代理调用 add）
        let result = consumer.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("calc", "calc", []))))
        match (result) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 11.0)   // 5 + 6
                    case _ => @Fail("expected number result")
                }
            case Err(e) => @Fail("pending consumer invoke failed: ${e}")
        }

        // 5. 清理
        host.removePlugin("inject-demo")
        host.removePlugin("e2e-provider")
    }

    @TestCase
    func testDependencyNotificationOnRemove(): Unit {
        // 依赖变更通知（docs/cordis-comparison.md §4）：
        // 提供者被移除 → 宿主向 inject 了其服务的依赖者发 DEPENDENCY_LOST 通知
        let consumerBinary = "./target/release/bin/ystyle::cordis_plugin.examples.inject_demo"
        let providerBinary = "./target/release/bin/ystyle::cordis_plugin.examples.e2e"
        @Expect(exists(Path(consumerBinary)))
        @Expect(exists(Path(providerBinary)))

        // 收集宿主日志（notifyDependents 输出 "notify dependency-lost ..."）
        let logs = ArrayList<String>()
        let logLock = Mutex()
        let host = PluginHost(PluginManager(), { _, line =>
            synchronized(logLock) {
                logs.add(line)
            }
        })

        // 1. 提供者先启动（注册 add）
        let providerEntry = PluginEntry("e2e-provider", providerBinary,
            provide: ArrayList<String>.of(["echo", "add"]))
        host.launchPlugin(providerEntry)
        var providerReady = false
        for (i in 0..100) {
            if (host.state.hasService("add")) {
                providerReady = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(providerReady)

        // 2. 消费者启动（inject add）→ Active
        let consumer = host.launchPlugin(PluginEntry("inject-demo", consumerBinary,
            provide: ArrayList<String>.of(["calc"])))
        var active = false
        for (i in 0..200) {
            if (consumer.status == InstanceStatus.Active) {
                active = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(active)

        // 3. 移除提供者 → 宿主应向消费者（inject add）发 DEPENDENCY_LOST 通知
        host.removePlugin("e2e-provider")
        var notified = false
        for (i in 0..100) {
            synchronized(logLock) {
                for (line in logs) {
                    if (line.contains("notify dependency-lost add")) {
                        notified = true
                        break
                    }
                }
            }
            if (notified) {
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(notified)

        // 4. 清理
        host.removePlugin("inject-demo")
    }

    private static func buildToml(offset: Int64): String {
        "interval = 5\n" +
            "ping_interval = 30\n" +
            "\n" +
            "[[plugins]]\n" +
            "id = \"hot-plugin\"\n" +
            "source = \"${pluginBinary()}\"\n" +
            "provide = [\"echo\", \"add\"]\n" +
            "\n" +
            "[plugins.config]\n" +
            "offset = ${offset}\n"
    }

    @TestCase
    func testConfigHotReload(): Unit {
        // 配置热更新（docs/cordis-comparison.md §4）：
        // 改 TOML 的 plugins.config → reconcile → entryChanged 检测到 config 变更
        // → removePlugin + 重启 → 新配置生效（add 服务带新 offset）
        let configPath = "./.e2e_hot_reload.toml"
        // 写初始配置（offset=10）
        let file = File(configPath, OpenMode.Write)
        file.write(buildToml(10).toArray())
        file.flush()

        // 收集插件日志（验证配置下发：ready 日志带 offset）
        let logs = ArrayList<String>()
        let logLock = Mutex()
        let host = PluginHost(PluginManager(), { _, line =>
            synchronized(logLock) {
                logs.add(line)
            }
        })
        host.reconcile(configPath)

        // 1. 等待插件 Active + 服务注册 + 配置日志
        var ready = false
        for (i in 0..200) {
            if (host.state.hasService("add")) {
                ready = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(ready)

        // 1.5 确认插件收到配置（ready 日志含 offset=10）
        var offsetSeen = false
        for (i in 0..100) {
            synchronized(logLock) {
                for (line in logs) {
                    if (line.contains("offset=10")) {
                        offsetSeen = true
                        break
                    }
                }
            }
            if (offsetSeen) {
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(offsetSeen)

        // 2. invoke add(2,3) → 5 + offset(10) = 15
        let inst = host.state.getInstance("hot-plugin")
        match (inst) {
            case Some(instance) =>
                let r1 = instance.client.call<JsonValue, JsonValue>("invoke",
                    params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                        [JsonValue.Number(2.0), JsonValue.Number(3.0)]))))
                match (r1) {
                    case Ok(v) =>
                        match (v) {
                            case JsonValue.Number(n) => @Expect(n, 15.0)
                            case _ => @Fail("expected 15 with offset 10")
                        }
                    case Err(e) => @Fail("invoke failed: ${e}")
                }
            case None => @Fail("instance not found")
        }

        // 3. 修改配置（offset=100）→ 触发调谐 → 插件重启 + 新配置生效
        let file2 = File(configPath, OpenMode.Write)
        file2.write(buildToml(100).toArray())
        file2.flush()
        host.reconcile(configPath)

        // 4. 等待新实例（重启后）Active
        var restarted = false
        var newInstance: ?PluginInstance = None
        for (i in 0..200) {
            let inst2 = host.state.getInstance("hot-plugin")
            match (inst2) {
                case Some(i2) =>
                    if (i2.status == InstanceStatus.Active) {
                        restarted = true
                        newInstance = Some(i2)
                        break
                    }
                case None => ()
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(restarted)

        // 5. 新配置生效：add(2,3) → 5 + 100 = 105
        match (newInstance) {
            case Some(instance) =>
                let r2 = instance.client.call<JsonValue, JsonValue>("invoke",
                    params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                        [JsonValue.Number(2.0), JsonValue.Number(3.0)]))))
                match (r2) {
                    case Ok(v) =>
                        match (v) {
                            case JsonValue.Number(n) => @Expect(n, 105.0)
                            case _ => @Fail("expected 105 with offset 100")
                        }
                    case Err(e) => @Fail("invoke after reload failed: ${e}")
                }
            case None => @Fail("no instance after reload")
        }

        // 清理
        host.removePlugin("hot-plugin")
        remove(Path(configPath))
    }

    @TestCase
    func testMacroPluginLifecycle(): Unit {
        // 宏插件（@Plugin + @Provide 生成）端到端：握手/服务注册/invoke
        let macroBinary = "./target/release/bin/ystyle::cordis_plugin.examples.macro_demo"
        @Expect(exists(Path(macroBinary)))
        let manager = PluginManager()
        let host = PluginHost(manager)
        let entry = PluginEntry("macro-plugin", macroBinary,
            provide: ArrayList<String>.of(["echo", "add"]))

        let instance = host.launchPlugin(entry)
        // 等待 Active + 服务注册
        var ready = false
        for (i in 0..200) {
            if (host.state.hasService("echo") && host.state.hasService("add")) {
                ready = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(ready)

        // invoke add(2,3) → 5（宏生成的方法路由）
        let addResult = instance.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                [JsonValue.Number(2.0), JsonValue.Number(3.0)]))))
        match (addResult) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 5.0)
                    case _ => @Fail("expected number result")
                }
            case Err(e) => @Fail("macro invoke failed: ${e}")
        }

        // invoke echo("hello-macro") → "hello-macro"
        let echoResult = instance.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("echo", "echo",
                [JsonValue.String("hello-macro")]))))
        match (echoResult) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.String(s) => @Expect(s, "hello-macro")
                    case _ => @Fail("expected string result")
                }
            case Err(e) => @Fail("macro echo failed: ${e}")
        }

        // 热卸载清理
        host.removePlugin("macro-plugin")
        @Expect(!host.state.hasService("echo"))
        @Expect(!host.state.hasService("add"))
    }

    @TestCase
    func testExternalPluginLifecycle(): Unit {
        // 独立模块插件（不依赖宏，PluginRuntime.run 显式 API）：
        // 验证外部插件作者在「cjpm 带 org 宏包跨模块缺陷」下仍可开发插件
        let externalBinary = "./target/release/bin/ystyle::cordis_examples"
        @Expect(exists(Path(externalBinary)))
        let manager = PluginManager()
        let host = PluginHost(manager)
        let entry = PluginEntry("external-plugin", externalBinary,
            provide: ArrayList<String>.of(["echo", "add"]))

        let instance = host.launchPlugin(entry)
        // 等待 Active + 服务注册
        var ready = false
        for (i in 0..200) {
            if (host.state.hasService("echo") && host.state.hasService("add")) {
                ready = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(ready)

        // invoke add(7,8) → 15
        let addResult = instance.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                [JsonValue.Number(7.0), JsonValue.Number(8.0)]))))
        match (addResult) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 15.0)
                    case _ => @Fail("expected number result")
                }
            case Err(e) => @Fail("external invoke failed: ${e}")
        }

        // 热卸载清理
        host.removePlugin("external-plugin")
        @Expect(!host.state.hasService("echo"))
        @Expect(!host.state.hasService("add"))
    }

    @TestCase
    func testEventBusEndToEnd(): Unit {
        // 事件总线端到端：真实宿主 + 真实双插件进程
        // 订阅者（event-sub）先启动并订阅 stats/report；
        // 发布者（event-emit）后启动，emit 经宿主路由到订阅者，
        // 订阅者收到后 log 通知宿主（通过 logger 回调收集验证）
        let subBinary = "./target/release/bin/ystyle::cordis_plugin.examples.event_sub"
        let emitBinary = "./target/release/bin/ystyle::cordis_plugin.examples.event_emit"
        @Expect(exists(Path(subBinary)))
        @Expect(exists(Path(emitBinary)))

        // 收集宿主日志（验证订阅者收到事件后 log）
        let logs = ArrayList<String>()
        let logLock = Mutex()
        let host = PluginHost(PluginManager(), { _, line =>
            synchronized(logLock) {
                logs.add(line)
            }
        })

        // 1. 先拉起订阅者（保证订阅先注册）
        let subEntry = PluginEntry("event-sub", subBinary)
        host.launchPlugin(subEntry)
        // 等待订阅者注册订阅（通过宿主日志 "subscribe stats/report" 验证）
        var subscribed = false
        for (i in 0..100) {
            synchronized(logLock) {
                for (line in logs) {
                    if (line.contains("subscribe stats/report")) {
                        subscribed = true
                        break
                    }
                }
            }
            if (subscribed) {
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(subscribed)

        // 2. 拉起发布者（启动后 emit 两个事件）
        let emitEntry = PluginEntry("event-emit", emitBinary)
        host.launchPlugin(emitEntry)

        // 3. 等待订阅者收到事件并 log（"received stats/report count=..."）
        var received = false
        for (i in 0..100) {
            synchronized(logLock) {
                for (line in logs) {
                    if (line.contains("received stats/report count=1.0") ||
                        line.contains("received stats/report count=1")) {
                        received = true
                        break
                    }
                }
            }
            if (received) {
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(received)

        // 4. 清理：卸载订阅者，验证订阅被清理
        host.removePlugin("event-sub")
        @Expect(host.eventRegistry.subscriberCount("stats/report"), 0)
        host.removePlugin("event-emit")
    }

    @TestCase
    func testInjectMacroEndToEnd(): Unit {
        // @Inject 宏端到端：真实宿主 + 双插件进程
        // 提供者（e2e 插件提供 add）先启动并注册服务；
        // 消费者（inject_demo 用 @Inject["add"] 注入）后启动，
        // 经宿主 invoke 转发调用 add 服务（5+6=11）
        let providerBinary = "./target/release/bin/ystyle::cordis_plugin.examples.e2e"
        let consumerBinary = "./target/release/bin/ystyle::cordis_plugin.examples.inject_demo"
        @Expect(exists(Path(providerBinary)))
        @Expect(exists(Path(consumerBinary)))

        let host = PluginHost(PluginManager())

        // 1. 先启动提供者（e2e 插件提供 echo/add）
        let providerEntry = PluginEntry("e2e-provider", providerBinary,
            provide: ArrayList<String>.of(["echo", "add"]))
        host.launchPlugin(providerEntry)
        // 等待 add 服务注册
        var providerReady = false
        for (i in 0..100) {
            if (host.state.hasService("add")) {
                providerReady = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(providerReady)

        // 2. 启动消费者（inject_demo，@Inject["add"]）
        let consumerEntry = PluginEntry("inject-demo", consumerBinary,
            inject: ArrayList<String>.of(["add"]),
            provide: ArrayList<String>.of(["calc"]))
        let consumer = host.launchPlugin(consumerEntry)

        // 3. 等消费者 Active（initialize 依赖检查：add 已就绪）
        var active = false
        for (i in 0..100) {
            if (consumer.status == InstanceStatus.Active) {
                active = true
                break
            }
            sleep(50 * Duration.millisecond)
        }
        @Expect(active)

        // 4. 宿主 invoke 消费者的 calc 服务 → 消费者内部经代理调用 add(5,6) → 返回 11
        let result = consumer.client.call<JsonValue, JsonValue>("invoke",
            params: Some(JsonValue.fromObject(InvokeParams("calc", "calc", []))))
        match (result) {
            case Ok(v) =>
                match (v) {
                    case JsonValue.Number(n) => @Expect(n, 11.0)   // 5 + 6
                    case _ => @Fail("expected number result")
                }
            case Err(e) => @Fail("inject invoke failed: ${e}")
        }

        // 5. 清理
        host.removePlugin("inject-demo")
        host.removePlugin("e2e-provider")
    }
}
