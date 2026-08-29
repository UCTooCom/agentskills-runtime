package ystyle::cordis_tests

import ystyle::cordis_host.*
import ystyle::cordis_core.*
import ystyle::jsonrpc.*
import jsonvalue.*
import stdx.serialization.serialization.*
import std.collection.{HashMap, ArrayList}
import std.sync.Mutex
import std.fs.{Path, exists}
import std.unittest.*
import std.unittest.testmacro.*

/**
 * Fiber 状态机测试（docs/cordis-comparison.md §4 Fiber 状态机完善）
 *
 * 对齐 Cordis Fiber 的 await()/restart()/update() 语义：
 * - awaitActive：阻塞等待插件进入 Active（Failed → Err；Pending 等依赖；超时 Err）
 * - restartPlugin：终止并用当前 entry 重新拉起（对齐 Cordis restart）
 * - updatePlugin：校验新 config → 重启 → awaitActive（对齐 Cordis update）
 * - transitionStatus + statusListeners：状态转换统一入口与通知（对齐 internal/status）
 *
 * 用真实插件进程（e2e 示例，提供 echo/add，支持 config.offset）。
 */
@Test
class FiberStateTest {

    private static func pluginBinary(): String {
        "./target/release/bin/ystyle::cordis_plugin.examples.e2e"
    }

    /** 构造带 config.offset 的 entry（config 是 DataModel） */
    private static func makeEntry(offset: Int64): PluginEntry {
        let cfg = DataModelStruct()
            .add(field<Int64>("offset", offset))
        PluginEntry("fiber-plugin", pluginBinary(),
            provide: ArrayList<String>.of(["echo", "add"]),
            config: cfg)
    }

    @TestCase
    func testAwaitActiveWaitsForHandshake(): Unit {
        // awaitActive：launch 后立即等待，应等到 Active（替代测试轮询 sleep）
        @Expect(exists(Path(pluginBinary())))
        let host = PluginHost(PluginManager())
        let instance = host.launchPlugin(makeEntry(0))

        let result = host.awaitActive("fiber-plugin", timeout: 10 * Duration.second)
        match (result) {
            case Ok(inst) =>
                @Expect(inst.status, InstanceStatus.Active)
                @Expect(inst.entry.id, instance.entry.id)
            case Err(e) => @Fail("awaitActive should succeed: ${e}")
        }
        @Expect(host.state.hasService("add"))

        host.removePlugin("fiber-plugin")
    }

    @TestCase
    func testAwaitActiveTimeout(): Unit {
        // awaitActive 超时：用一个永不握手的"插件"（/bin/sleep）→ 一直 Starting
        let host = PluginHost(PluginManager())
        let entry = PluginEntry("sleep-plugin", "/bin/sleep",
            args: ArrayList<String>.of(["30"]))
        host.launchPlugin(entry)

        let result = host.awaitActive("sleep-plugin", timeout: 300 * Duration.millisecond)
        match (result) {
            case Ok(_) => @Fail("awaitActive should time out for non-handshaking plugin")
            case Err(e) => @Expect(e.contains("timeout"))
        }

        // 清理：终止 sleep 进程
        host.removePlugin("sleep-plugin")
    }

    @TestCase
    func testAwaitActiveFailedWhenProcessDies(): Unit {
        // awaitActive：进程死亡（未握手就退出）→ 应标记 Failed 并返回 Err
        let host = PluginHost(PluginManager())
        // /bin/false 立即退出，永不握手
        let entry = PluginEntry("false-plugin", "/bin/false")
        let instance = host.launchPlugin(entry)

        let result = host.awaitActive("false-plugin", timeout: 5 * Duration.second)
        match (result) {
            case Ok(_) => @Fail("awaitActive should fail for dead process")
            case Err(e) => @Expect(e.contains("failed") || e.contains("exit"))
        }
        // 状态应为 Failed
        @Expect(instance.status, InstanceStatus.Failed)

        host.removePlugin("false-plugin")
    }

    @TestCase
    func testRestartPluginKeepsEntry(): Unit {
        // restartPlugin：终止并重新拉起，新实例 Active 且服务可用
        let host = PluginHost(PluginManager())
        host.launchPlugin(makeEntry(0))
        match (host.awaitActive("fiber-plugin", timeout: 10 * Duration.second)) {
            case Ok(_) => ()
            case Err(e) => @Fail("initial await failed: ${e}")
        }

        let result = host.restartPlugin("fiber-plugin")
        match (result) {
            case Ok(newInst) =>
                @Expect(newInst.status, InstanceStatus.Active)
                @Expect(newInst.entry.id, "fiber-plugin")
                // 新实例服务已注册
                @Expect(host.state.hasService("add"))
                // 调用 add(2,3) = 5（offset=0）
                let r = newInst.client.call<JsonValue, JsonValue>("invoke",
                    params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                        [JsonValue.Number(2.0), JsonValue.Number(3.0)]))))
                match (r) {
                    case Ok(v) =>
                        match (v) {
                            case JsonValue.Number(n) => @Expect(n, 5.0)
                            case other => @Fail("expected 5.0, got: ${other}")
                        }
                    case Err(e) => @Fail("invoke after restart failed: ${e}")
                }
            case Err(e) => @Fail("restartPlugin should succeed: ${e}")
        }

        host.removePlugin("fiber-plugin")
    }

    @TestCase
    func testRestartPluginNotFound(): Unit {
        // restartPlugin：实例不存在 → Err（对齐 Cordis assertActive/已 dispose）
        let host = PluginHost(PluginManager())
        let result = host.restartPlugin("no-such-plugin")
        match (result) {
            case Ok(_) => @Fail("restartPlugin should fail for missing plugin")
            case Err(e) => @Expect(e.contains("not found"))
        }
    }

    @TestCase
    func testUpdatePluginConfigRestarts(): Unit {
        // updatePlugin：新 config（offset=100）→ 重启 → add(2,3) = 105
        let host = PluginHost(PluginManager())
        host.launchPlugin(makeEntry(0))
        match (host.awaitActive("fiber-plugin", timeout: 10 * Duration.second)) {
            case Ok(_) => ()
            case Err(e) => @Fail("initial await failed: ${e}")
        }

        let result = host.updatePlugin("fiber-plugin", makeEntry(100))
        match (result) {
            case Ok(newInst) =>
                @Expect(newInst.status, InstanceStatus.Active)
                let r = newInst.client.call<JsonValue, JsonValue>("invoke",
                    params: Some(JsonValue.fromObject(InvokeParams("add", "add",
                        [JsonValue.Number(2.0), JsonValue.Number(3.0)]))))
                match (r) {
                    case Ok(v) =>
                        match (v) {
                            case JsonValue.Number(n) => @Expect(n, 105.0)
                            case _ => @Fail("expected 105.0 with offset 100")
                        }
                    case Err(e) => @Fail("invoke after update failed: ${e}")
                }
            case Err(e) => @Fail("updatePlugin should succeed: ${e}")
        }

        host.removePlugin("fiber-plugin")
    }

    @TestCase
    func testUpdatePluginInvalidConfigRejected(): Unit {
        // updatePlugin：config schema 校验失败 → Err，且不重启（原实例仍在）
        let host = PluginHost(PluginManager())
        // 注册 schema：offset 必填
        let schema = ConfigSchema(ArrayList<ConfigFieldSpec>.of(
            ConfigFieldSpec("offset", "int", required: true)))
        host.registerSchema("fiber-plugin", schema)
        host.launchPlugin(makeEntry(0))
        match (host.awaitActive("fiber-plugin", timeout: 10 * Duration.second)) {
            case Ok(inst) =>
                // 记录原进程 pid，验证更新失败后未重启
                let oldPid = inst.process.pid
                // 新 entry 缺 offset → 校验失败
                let badEntry = PluginEntry("fiber-plugin", pluginBinary(),
                    provide: ArrayList<String>.of(["echo", "add"]))
                let result = host.updatePlugin("fiber-plugin", badEntry)
                match (result) {
                    case Ok(_) => @Fail("updatePlugin should reject invalid config")
                    case Err(e) => @Expect(e.contains("validation failed"))
                }
                // 实例仍在且 pid 未变（未重启）
                match (host.state.getInstance("fiber-plugin")) {
                    case Some(inst2) => @Expect(inst2.process.pid, oldPid)
                    case None => @Fail("instance should still exist")
                }
            case Err(e) => @Fail("initial await failed: ${e}")
        }

        host.removePlugin("fiber-plugin")
    }

    @TestCase
    func testStatusListenersReceiveTransitions(): Unit {
        // statusListeners：状态转换通知（对齐 Cordis internal/status 事件）
        let host = PluginHost(PluginManager())
        let transitions = ArrayList<String>()
        let lock = Mutex()
        host.onStatusChange({ id, oldStatus, newStatus =>
            synchronized(lock) {
                transitions.add("${id}:${oldStatus}->${newStatus}")
            }
        })

        host.launchPlugin(makeEntry(0))
        match (host.awaitActive("fiber-plugin", timeout: 10 * Duration.second)) {
            case Ok(_) => ()
            case Err(e) => @Fail("await failed: ${e}")
        }

        // 至少应有 Starting->Active（或 Starting->Pending->Active 若依赖缺失）
        // 注意：InstanceStatus ToString 输出 "InstanceStatus.Active"（含限定名）
        var sawActive = false
        synchronized(lock) {
            for (t in transitions) {
                if (t.contains("InstanceStatus.Active")) {
                    sawActive = true
                }
            }
        }
        @Expect(sawActive)

        host.removePlugin("fiber-plugin")
    }
}
