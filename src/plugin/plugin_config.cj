/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.fs.File
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool}
import yaml4cj.yaml.decode
import magic.app.core.http.HttpMethod
import magic.log.LogUtils

/**
 * PluginMode - 插件加载轨（三轨并存，缺省 Sync 向后兼容）
 *
 * - Sync:    内嵌轨，源码经 build-sync 进入宿主 magic 包编译图（开发期增量编译友好）
 * - Dylib:   L2 动态库轨，预编译动态库经 PackageInfo.load 热加载（不重编宿主）
 * - Process: L3 进程隔离轨（cordis-cj 集成），插件=独立可执行文件，经 JSON-RPC over stdio 通信
 *            （故障隔离、闭源发布、第三方市场、AI 动态启停）
 *
 * 详见 design.md §0.3 双轨并存实际形态 / §5 L3 进程隔离插件轨设计。
 */
public enum PluginMode {
    | Sync
    | Dylib
    | Process

    public operator func ==(other: PluginMode): Bool {
        match ((this, other)) {
            case (Sync, Sync) | (Dylib, Dylib) | (Process, Process) => true
            case _ => false
        }
    }

    public operator func !=(other: PluginMode): Bool {
        !(this == other)
    }
}

/**
 * PluginManifestEntry - plugin.yaml 中的单个插件清单条目
 *
 * plugin.yaml 结构示例（去中心化自完备描述）：
 * ```yaml
 * plugins:
 *   - name: memory-postgres
 *     className: magic.plugins.memory.MemoryPostgresPlugin
 *     mode: sync            # 缺省 sync；可选 sync/dylib/process
 *     enabled: true
 *     order: 1
 *     config:
 *       connectionString: "postgres://user:pass@localhost:5432/uctoo"
 *   - name: entity
 *     className: magic.plugins.entity.EntityPlugin
 *     mode: sync
 *     enabled: true
 *     routeClass: magic.plugins.entity.scripts.routes.EntityRoute
 *     config: {}
 *   - name: external-tool
 *     mode: process         # L3 进程隔离轨
 *     command: ./skills/external-tool/target/release/skill_external_tool.exe
 *     args: ["--log-level", "info"]
 *     env:
 *       LOG_LEVEL: "info"
 *     autoRestart: true     # 缺省 true
 *     enabled: true
 * ```
 *
 * 注：mode=process 时 className 非必填（进程插件不经 cordis PluginHostManager 拉起，
 * 不走 PluginLoader 反射实例化）；command 为 process 模式必填项。
 */
public class PluginManifestEntry {
    /// 插件名（须与 @PluginAnnotation.name 一致；process 模式下须与 plugin.yaml.name 一致）
    public var name: String = ""

    /// 插件类全名（PluginLoader 反射用；process 模式下可空，进程插件不经反射实例化）
    public var className: String = ""

    /// 加载轨（缺省 Sync）
    public var mode: PluginMode = PluginMode.Sync

    /// 是否启用（false 则 loadAll 跳过）
    public var enabled: Bool = true

    /// 参数注入（传给 PluginContext.config）
    public var config: JsonValue = JsonObject()

    /// 加载顺序（数字越小越先加载，默认 0；同序按声明顺序）
    public var order: Int32 = 0

    /// 可选：插件 Route 类全名（阶段二 PluginRouteScanner 用）
    public var routeClass: Option<String> = None

    /// L3 进程轨：插件可执行文件路径（process 模式必填；sync/dylib 模式忽略）
    public var command: Option<String> = None

    /// L3 进程轨：传递给插件进程的命令行参数（缺省空列表）
    public var args: ArrayList<String> = ArrayList<String>()

    /// L3 进程轨：插件进程环境变量（缺省空映射，宿主侧不自动注入宿主环境）
    public var env: HashMap<String, String> = HashMap<String, String>()

    /// L3 进程轨：崩溃自愈开关（缺省 true，reconcile 检测到 stdout EOF 自动重拉）
    public var autoRestart: Bool = true

    /// host.db 表白名单（声明式配置，插件仅可访问白名单内表；缺省空列表=拒绝全部表）
    /// 在 plugin.yaml 中通过 tableWhitelist: ["table1", "table2"] 声明
    public var tableWhitelist: ArrayList<String> = ArrayList<String>()

    /// HTTP 路由声明（process 模式插件用，从 plugin.yaml routes 字段解析）
    /// sync/dylib 模式下为空（路由经 PluginRouteScanner + routeClass 反射注册）
    public var httpRoutes: ArrayList<ExternalRoute> = ArrayList<ExternalRoute>()

    public init() {}

    /**
     * 从 JsonValue（yaml4cj 解析产物）构建条目
     *
     * 返回 None 当 name 缺失，或当 sync/dylib 模式下 className 缺失，
     * 或当 process 模式下 command 缺失。
     */
    public static func fromJsonValue(json: JsonValue): Option<PluginManifestEntry> {
        if (!(json is JsonObject)) {
            return None
        }
        let jsonObj = (json as JsonObject).getOrThrow()
        let fields = jsonObj.getFields()

        let entry = PluginManifestEntry()

        if (let Some(nameVal) <- fields.get("name")) {
            entry.name = jsonToString(nameVal)
        }
        // name 为所有模式的必填项
        if (entry.name.isEmpty()) {
            return None
        }

        // mode 解析（缺省 Sync）
        if (let Some(modeVal) <- fields.get("mode")) {
            entry.mode = parseMode(jsonToString(modeVal))
        }

        // className 解析：sync/dylib 模式必填，process 模式可空
        if (let Some(classVal) <- fields.get("className")) {
            entry.className = jsonToString(classVal)
        }
        match (entry.mode) {
            case PluginMode.Sync | PluginMode.Dylib =>
                if (entry.className.isEmpty()) {
                    return None
                }
            case PluginMode.Process => ()
        }

        if (let Some(enabledVal) <- fields.get("enabled")) {
            if (enabledVal is JsonBool) {
                entry.enabled = (enabledVal as JsonBool).getOrThrow().getValue()
            }
        }
        if (let Some(orderVal) <- fields.get("order")) {
            if (orderVal is JsonInt) {
                entry.order = Int32((orderVal as JsonInt).getOrThrow().getValue())
            }
        }
        if (let Some(configVal) <- fields.get("config")) {
            entry.config = configVal
        }
        if (let Some(routeVal) <- fields.get("routeClass")) {
            if (routeVal is JsonString) {
                entry.routeClass = Some((routeVal as JsonString).getOrThrow().getValue())
            }
        }

        // L3 进程轨字段解析（仅 process 模式有意义，其他模式忽略）
        if (let Some(cmdVal) <- fields.get("command")) {
            entry.command = Some(jsonToString(cmdVal))
        }
        if (let Some(argsVal) <- fields.get("args")) {
            parseStringArray(argsVal, entry.args)
        }
        if (let Some(envVal) <- fields.get("env")) {
            parseEnvMap(envVal, entry.env)
        }
        if (let Some(restartVal) <- fields.get("autoRestart")) {
            if (restartVal is JsonBool) {
                entry.autoRestart = (restartVal as JsonBool).getOrThrow().getValue()
            }
        }

        // host.db 表白名单解析（声明式配置，替代宿主代码硬编码）
        if (let Some(whitelistVal) <- fields.get("tableWhitelist")) {
            parseStringArray(whitelistVal, entry.tableWhitelist)
        }

        // process 模式必填校验：command 必须提供
        if (entry.mode == PluginMode.Process) {
            match (entry.command) {
                case None => return None
                case Some(cmd) =>
                    if (cmd.isEmpty()) {
                        return None
                    }
            }
        }

        return Some(entry)
    }

    /**
     * 从 plugin.yaml 文件构建条目（去中心化自动发现用）
     *
     * 解析全量字段：基本字段经 fromJsonValue，routes 字段解析为 HTTP 路由声明。
     * 返回 None 当文件不存在、YAML 解析失败、或必填字段缺失。
     */
    public static func fromPluginYaml(yamlPath: String): Option<PluginManifestEntry> {
        try {
            let bytes = File.readFrom(yamlPath)
            let parsedYaml = decode(bytes)
            match (PluginManifestEntry.fromJsonValue(parsedYaml)) {
                case Some(entry) =>
                    if (entry.mode == PluginMode.Process && (parsedYaml is JsonObject)) {
                        let jsonObj = (parsedYaml as JsonObject).getOrThrow()
                        let fields = jsonObj.getFields()
                        if (let Some(routesVal) <- fields.get("routes")) {
                            if (routesVal is JsonArray) {
                                let arr = (routesVal as JsonArray).getOrThrow()
                                for (i in 0..arr.size()) {
                                    let routeElem = arr[i]
                                    if (routeElem is JsonObject) {
                                        let routeObj = (routeElem as JsonObject).getOrThrow()
                                        let routeFields = routeObj.getFields()
                                        var methodStr = "POST"
                                        var pathStr = ""
                                        if (let Some(mVal) <- routeFields.get("method")) {
                                            if (mVal is JsonString) {
                                                methodStr = (mVal as JsonString).getOrThrow().getValue()
                                            }
                                        }
                                        if (let Some(pVal) <- routeFields.get("path")) {
                                            if (pVal is JsonString) {
                                                pathStr = (pVal as JsonString).getOrThrow().getValue()
                                            }
                                        }
                                        if (!pathStr.isEmpty()) {
                                            let httpMethod = match (methodStr) {
                                                case "GET" => HttpMethod.GET
                                                case "POST" => HttpMethod.POST
                                                case "PUT" => HttpMethod.PUT
                                                case "DELETE" => HttpMethod.DELETE
                                                case _ => HttpMethod.POST
                                            }
                                            entry.httpRoutes.add(ExternalRoute(httpMethod, pathStr))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return Some(entry)
                case None => return None
            }
        } catch (e: Exception) {
            LogUtils.error("[PluginManifestEntry] failed to parse plugin.yaml: ${yamlPath}, error: ${e.message}")
            return None
        }
    }

    /// 解析 mode 字符串为 PluginMode（未知值降级为 Sync，保持向后兼容）
    private static func parseMode(s: String): PluginMode {
        match (s) {
            case "sync" => PluginMode.Sync
            case "dylib" => PluginMode.Dylib
            case "process" => PluginMode.Process
            case _ => PluginMode.Sync
        }
    }

    /// 从 JsonValue 解析字符串数组到目标 ArrayList
    /// 期望 args 为 JsonArray，每个元素为 JsonString
    private static func parseStringArray(v: JsonValue, out: ArrayList<String>): Unit {
        if (!(v is JsonArray)) {
            return
        }
        let arr = (v as JsonArray).getOrThrow()
        for (i in 0..arr.size()) {
            let elem = arr[i]
            if (elem is JsonString) {
                out.add((elem as JsonString).getOrThrow().getValue())
            } else {
                // 非字符串元素降级为 toString 描述
                out.add(elem.toString())
            }
        }
    }

    /// 从 JsonValue 解析环境变量映射到目标 HashMap
    /// 期望 env 为 JsonObject，每个键值对为 String->String
    private static func parseEnvMap(v: JsonValue, out: HashMap<String, String>): Unit {
        if (!(v is JsonObject)) {
            return
        }
        let obj = (v as JsonObject).getOrThrow()
        let fields = obj.getFields()
        for (key in fields.keys()) {
            match (fields.get(key)) {
                case Some(val) =>
                    if (val is JsonString) {
                        out[key] = (val as JsonString).getOrThrow().getValue()
                    } else {
                        out[key] = val.toString()
                    }
                case None => ()
            }
        }
    }

    /// JsonValue 取字符串（JsonString 直取，其余转字符串描述）
    private static func jsonToString(v: JsonValue): String {
        if (v is JsonString) {
            return (v as JsonString).getOrThrow().getValue()
        }
        return v.toString()
    }
}

/**
 * PluginList - 插件清单（去中心化自动发现产物）
 */
public class PluginList {
    public var plugins: ArrayList<PluginManifestEntry>

    public init() {
        this.plugins = ArrayList<PluginManifestEntry>()
    }

    /// 按 order 升序稳定排序（冒泡，RouteRegistry 同款模式；同序保持声明顺序）
    public func sortByOrder(): Unit {
        let arr = this.plugins
        let n = arr.size
        for (i in 0..n) {
            for (j in 0..(n - 1 - i)) {
                if (arr[j].order > arr[j + 1].order) {
                    let tmp = arr[j]
                    arr[j] = arr[j + 1]
                    arr[j + 1] = tmp
                }
            }
        }
    }

    /// 已启用条目数
    public func enabledCount(): Int64 {
        var count = 0
        for (entry in this.plugins) {
            if (entry.enabled) {
                count += 1
            }
        }
        return count
    }
}
