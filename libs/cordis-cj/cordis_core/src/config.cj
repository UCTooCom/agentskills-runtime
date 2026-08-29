package ystyle::cordis_core

import tomlcj.*
import stdx.serialization.serialization.*
import stdx.encoding.json.*
import std.collection.ArrayList
import std.fs.{File, OpenMode}
import std.io.ByteBuffer

/**
 * 配置条目（对应 docs/design-impl.md §2.1）
 *
 * 实现 Serializable<T>：以 DataModel 为中间表示，TOML（DataModel.fromToml）
 * 与 JSON（DataModel.fromJson）均可统一读写，无需针对具体格式手写解析。
 */
public class PluginEntry <: Serializable<PluginEntry> {
    public var id: String = ""            // 稳定身份，Reconciler diff 的 key
    public var source: String = ""        // 可执行文件路径（launch 的 command）
    public var args: ArrayList<String> = ArrayList()  // 附加参数（默认空）
    public var inject: ArrayList<String> = ArrayList() // 依赖的服务 Key
    public var provide: ArrayList<String> = ArrayList() // 提供的服务 Key
    public var config: DataModel = DataModelNull()    // 插件私有配置（透传）
    public var enabled: Bool = true       // disabled 语义

    public init() {}

    public init(id: String, source: String, args!: ArrayList<String> = ArrayList(),
                inject!: ArrayList<String> = ArrayList(), provide!: ArrayList<String> = ArrayList(),
                config!: DataModel = DataModelNull(), enabled!: Bool = true) {
        this.id = id
        this.source = source
        this.args = args
        this.inject = inject
        this.provide = provide
        this.config = config
        this.enabled = enabled
    }

    public func serialize(): DataModel {
        DataModelStruct()
            .add(field<String>("id", this.id))
            .add(field<String>("source", this.source))
            .add(field<ArrayList<String>>("args", this.args))
            .add(field<ArrayList<String>>("inject", this.inject))
            .add(field<ArrayList<String>>("provide", this.provide))
            .add(Field("config", this.config))
            .add(field<Bool>("enabled", this.enabled))
    }

    public static func deserialize(dm: DataModel): PluginEntry {
        let dms = match (dm) {
            case s: DataModelStruct => s
            case _ => throw Exception("PluginEntry: expected DataModelStruct")
        }
        let r = PluginEntry()
        r.id = match (dms.get("id")) { case s: DataModelString => s.getValue(); case _ => "" }
        r.source = match (dms.get("source")) { case s: DataModelString => s.getValue(); case _ => "" }
        r.args = match (dms.get("args")) {
            case seq: DataModelSeq => deserializeStringList(seq)
            case _ => ArrayList<String>()
        }
        r.inject = match (dms.get("inject")) {
            case seq: DataModelSeq => deserializeStringList(seq)
            case _ => ArrayList<String>()
        }
        r.provide = match (dms.get("provide")) {
            case seq: DataModelSeq => deserializeStringList(seq)
            case _ => ArrayList<String>()
        }
        r.config = dms.get("config")
        r.enabled = match (dms.get("enabled")) {
            case b: DataModelBool => b.getValue()
            case _ => true
        }
        r
    }

    private static func deserializeStringList(seq: DataModelSeq): ArrayList<String> {
        let result = ArrayList<String>()
        for (item in seq.getItems()) {
            match (item) {
                case s: DataModelString => result.add(s.getValue())
                case _ => ()
            }
        }
        result
    }
}

/**
 * 完整配置（根 TOML/JSON 解析结果）
 */
public class CordisConfig <: Serializable<CordisConfig> {
    public var interval: Int64 = 5        // 调谐周期（秒），默认 5
    public var pingInterval: Int64 = 30   // 探活周期（秒），默认 30
    public var transport: String = "stdio" // 传输模式："stdio"（管道）| "uds"（Unix Domain Socket）
    public var udsPath: String = ""       // UDS 模式下的监听 socket 路径（如 "/tmp/cordis.sock"）
    public var entries: ArrayList<PluginEntry> = ArrayList()

    public init() {}

    public init(interval: Int64, pingInterval: Int64, entries: ArrayList<PluginEntry>) {
        this.interval = interval
        this.pingInterval = pingInterval
        this.entries = entries
    }

    public init(interval: Int64, pingInterval: Int64, transport: String, udsPath: String,
                entries: ArrayList<PluginEntry>) {
        this.interval = interval
        this.pingInterval = pingInterval
        this.transport = transport
        this.udsPath = udsPath
        this.entries = entries
    }

    public func serialize(): DataModel {
        DataModelStruct()
            .add(field<Int64>("interval", this.interval))
            .add(field<Int64>("ping_interval", this.pingInterval))
            .add(field<String>("transport", this.transport))
            .add(field<String>("uds_path", this.udsPath))
            .add(field<ArrayList<PluginEntry>>("plugins", this.entries))
    }

    public static func deserialize(dm: DataModel): CordisConfig {
        let dms = match (dm) {
            case s: DataModelStruct => s
            case _ => throw Exception("CordisConfig: expected DataModelStruct")
        }
        let r = CordisConfig()
        r.interval = match (dms.get("interval")) { case i: DataModelInt => i.getValue(); case _ => 5 }
        r.pingInterval = match (dms.get("ping_interval")) { case i: DataModelInt => i.getValue(); case _ => 30 }
        r.transport = match (dms.get("transport")) { case s: DataModelString => s.getValue(); case _ => "stdio" }
        r.udsPath = match (dms.get("uds_path")) { case s: DataModelString => s.getValue(); case _ => "" }
        r.entries = match (dms.get("plugins")) {
            case seq: DataModelSeq =>
                let list = ArrayList<PluginEntry>()
                for (item in seq.getItems()) {
                    list.add(PluginEntry.deserialize(item))
                }
                list
            case _ => ArrayList<PluginEntry>()
        }
        r
    }
}

/**
 * 配置加载器（docs/design-impl.md §7）
 *
 * 统一泛型入口：任意实现了 Serializable<T> 的配置结构，均可
 * 通过 TOML（unmarshal/DataModel.fromToml）或 JSON（DataModel.fromJson）读取。
 *
 * 示例 TOML：
 * ```toml
 * interval = 5
 * ping_interval = 30
 *
 * [[plugins]]
 * id = "db"
 * source = "./target/release/bin/plugin-db"
 * args = []
 * inject = []
 * provide = ["db"]
 * enabled = true
 *
 * [plugins.config]
 * host = "127.0.0.1"
 * port = 5432
 * ```
 */
public class ConfigLoader {
    private init() {}

    /**
     * 从 TOML 文件读取任意 Serializable 配置结构
     * @param path 配置文件路径
     * @return 反序列化后的配置
     */
    public static func loadToml<T>(path: String): T where T <: Serializable<T> {
        let file = File(path, OpenMode.Read)
        let decoder = Decoder(file)
        let root = decoder.decode()
        let dm = DataModel.fromToml(root)
        return T.deserialize(dm)
    }

    /**
     * 从 TOML 字符串解析任意 Serializable 配置结构（测试友好）
     */
    public static func parseTomlString<T>(content: String): T where T <: Serializable<T> {
        let buffer = ByteBuffer(content.toArray())
        let decoder = Decoder(buffer)
        let root = decoder.decode()
        let dm = DataModel.fromToml(root)
        return T.deserialize(dm)
    }

    /**
     * 从 JSON 字符串解析任意 Serializable 配置结构（测试友好）
     */
    public static func parseJsonString<T>(content: String): T where T <: Serializable<T> {
        let jv = JsonValue.fromStr(content)
        let dm = DataModel.fromJson(jv)
        return T.deserialize(dm)
    }

    /**
     * 便捷方法：从 TOML 文件加载 CordisConfig
     */
    public static func load(path: String): CordisConfig {
        return loadToml<CordisConfig>(path)
    }

    /**
     * 便捷方法：从 TOML 字符串解析 CordisConfig（测试友好）
     */
    public static func parseString(content: String): CordisConfig {
        return parseTomlString<CordisConfig>(content)
    }
}
