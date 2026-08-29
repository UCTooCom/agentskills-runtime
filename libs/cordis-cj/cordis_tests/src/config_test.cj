package ystyle::cordis_tests

import ystyle::cordis_core.*
import stdx.serialization.serialization.*
import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
class ConfigLoaderTest {
    @TestCase
    func testParseTomlMinimal(): Unit {
        let toml = """
            interval = 5
            ping_interval = 30

            [[plugins]]
            id = "db"
            source = "./target/release/bin/plugin-db"
            provide = ["db"]
        """
        let cfg = ConfigLoader.parseString(toml)
        @Expect(cfg.interval, 5)
        @Expect(cfg.pingInterval, 30)
        @Expect(cfg.entries.size, 1)
        let e = cfg.entries[0]
        @Expect(e.id, "db")
        @Expect(e.source, "./target/release/bin/plugin-db")
        @Expect(e.enabled)
        @Expect(e.inject.size, 0)
        @Expect(e.provide, ArrayList<String>.of(["db"]))
        @Expect(e.args.size, 0)
    }

    @TestCase
    func testParseTomlFull(): Unit {
        let toml = """
            interval = 10
            ping_interval = 60

            [[plugins]]
            id = "api"
            source = "./target/release/bin/plugin-api"
            args = ["--debug"]
            inject = ["db"]
            provide = ["api"]
            enabled = true

            [plugins.config]
            host = "127.0.0.1"
            port = 8080

            [[plugins]]
            id = "disabled-plugin"
            source = "./bin/x"
            enabled = false
        """
        let cfg = ConfigLoader.parseString(toml)
        @Expect(cfg.interval, 10)
        @Expect(cfg.pingInterval, 60)
        @Expect(cfg.entries.size, 2)

        let api = cfg.entries[0]
        @Expect(api.id, "api")
        @Expect(api.args, ArrayList<String>.of(["--debug"]))
        @Expect(api.inject, ArrayList<String>.of(["db"]))
        @Expect(api.provide, ArrayList<String>.of(["api"]))
        @Expect(api.enabled)
        // config 为 DataModelStruct，检查字段
        match (api.config) {
            case s: DataModelStruct =>
                match (s.get("host")) {
                    case h: DataModelString => @Expect(h.getValue(), "127.0.0.1")
                    case _ => @Fail("config.host missing")
                }
                match (s.get("port")) {
                    case p: DataModelInt => @Expect(p.getValue(), 8080)
                    case _ => @Fail("config.port missing")
                }
            case _ => @Fail("config should be DataModelStruct")
        }

        let disabled = cfg.entries[1]
        @Expect(!disabled.enabled)
    }

    @TestCase
    func testParseTomlDefaults(): Unit {
        let toml = """
            [[plugins]]
            id = "x"
            source = "./bin/x"
        """
        let cfg = ConfigLoader.parseString(toml)
        @Expect(cfg.interval, 5)       // 默认 5
        @Expect(cfg.pingInterval, 30)  // 默认 30
        @Expect(cfg.transport, "stdio") // 默认 stdio（管道）
        @Expect(cfg.udsPath, "")        // 默认空
        @Expect(cfg.entries.size, 1)
        @Expect(cfg.entries[0].enabled)   // enabled 缺省为 true
    }

    @TestCase
    func testParseTomlUdsMode(): Unit {
        // UDS 模式：transport + uds_path 配置
        let toml = """
            transport = "uds"
            uds_path = "/tmp/cordis-test.sock"

            [[plugins]]
            id = "db"
            source = "./bin/db"
            provide = ["db"]
        """
        let cfg = ConfigLoader.parseString(toml)
        @Expect(cfg.transport, "uds")
        @Expect(cfg.udsPath, "/tmp/cordis-test.sock")
        @Expect(cfg.entries.size, 1)
        @Expect(cfg.entries[0].id, "db")
    }

    @TestCase
    func testSerializeRoundTripUds(): Unit {
        // UDS 字段 serialize → deserialize 往返一致
        let entry = PluginEntry("a", "./bin/a")
        let entries = ArrayList<PluginEntry>()
        entries.add(entry)
        let cfg = CordisConfig(3, 15, "uds", "/tmp/cordis-r.sock", entries)
        let dm = cfg.serialize()
        let restored = CordisConfig.deserialize(dm)
        @Expect(restored.interval, 3)
        @Expect(restored.pingInterval, 15)
        @Expect(restored.transport, "uds")
        @Expect(restored.udsPath, "/tmp/cordis-r.sock")
        @Expect(restored.entries.size, 1)
    }

    @TestCase
    func testParseTomlEmpty(): Unit {
        let toml = "interval = 5"
        let cfg = ConfigLoader.parseString(toml)
        @Expect(cfg.entries.size, 0)
    }

    @TestCase
    func testParseJsonConfig(): Unit {
        // 同一 Serializable<CordisConfig> 结构，JSON 也能解析
        let json = ##"{
            "interval": 8,
            "ping_interval": 45,
            "plugins": [
                {
                    "id": "json-plugin",
                    "source": "./bin/json-plugin",
                    "inject": ["svc"],
                    "provide": ["json-svc"],
                    "enabled": true,
                    "config": {"host": "10.0.0.1"}
                }
            ]
        }"##
        let cfg = ConfigLoader.parseJsonString<CordisConfig>(json)
        @Expect(cfg.interval, 8)
        @Expect(cfg.pingInterval, 45)
        @Expect(cfg.entries.size, 1)
        let e = cfg.entries[0]
        @Expect(e.id, "json-plugin")
        @Expect(e.inject, ArrayList<String>.of(["svc"]))
        @Expect(e.provide, ArrayList<String>.of(["json-svc"]))
    }

    @TestCase
    func testSerializeRoundTrip(): Unit {
        // serialize → deserialize 往返一致（DataModel 中间表示）
        let entry = PluginEntry("a", "./bin/a", args: ArrayList<String>.of(["-x"]),
            inject: ArrayList<String>.of(["db"]), provide: ArrayList<String>.of(["api"]),
            enabled: true)
        let entries = ArrayList<PluginEntry>()
        entries.add(entry)
        let cfg = CordisConfig(3, 15, entries)
        let dm = cfg.serialize()
        let restored = CordisConfig.deserialize(dm)
        @Expect(restored.interval, 3)
        @Expect(restored.pingInterval, 15)
        @Expect(restored.entries.size, 1)
        let re = restored.entries[0]
        @Expect(re.id, "a")
        @Expect(re.args, ArrayList<String>.of(["-x"]))
        @Expect(re.inject, ArrayList<String>.of(["db"]))
        @Expect(re.provide, ArrayList<String>.of(["api"]))
        @Expect(re.enabled)
    }
}
