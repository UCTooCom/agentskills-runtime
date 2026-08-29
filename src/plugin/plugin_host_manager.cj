/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.{ArrayList, HashMap}
import std.fs.{exists, File, OpenMode}
import std.io.StringReader
import f_base.Result
import magic.log.LogUtils
import magic.app.core.router.Router
import magic.app.core.http.HttpMethod
import stdx.encoding.json.{JsonObject, JsonString}
import plugin_spi.{Plugin, PluginState, PluginError, LoadResult, PluginContext, ServiceRegistry, PluginSpiLogger}

/**
 * PluginHostManager - 插件生命周期编排器
 *
 * 启动期（main.cj 在存量路由注册之后调用 loadAll）：
 * 读 plugins.yaml -> 依 order 逐个（load -> onLoad -> onActivate
 * -> 注册 -> 技能注册），单插件失败不阻断其他插件（记 failed 继续）。
 *
 * 状态机触发条件（design.md §2.1.4）：
 * - onLoad/onActivate 抛异常 -> Error 态（可修复后重试）
 * - onDeactivate/onUnload 抛异常 -> 捕获记日志，清理栈仍逆序执行完毕
 * - 事件/Service 业务异常 -> 不触发状态迁移
 */
public class PluginHostManager {
    private let registry: PluginRegistry
    private let loader: PluginLoader
    private let eventBus: PluginEventBus
    private let skillBridge: SkillBridge
    private let configParser: PluginConfigParser

    /// 插件根目录（插件目录约定 plugins/<name>/，内含 plugin.yaml 与 SKILL.md）
    private let pluginsRoot: String

    /// 宿主路由表（process 轨 V4 CRUD 路由注册用）
    private let router: ?Router

    /// 全部插件与宿主共用的服务注册表
    private let serviceRegistry: ServiceRegistry

    /// 各插件上下文（卸载时执行清理栈）
    private let contexts: HashMap<String, PluginContext>

    /// 各插件类名登记（inspect 展示用）
    private let classNames: HashMap<String, String>

    /// 已激活插件声明的 Route 类全名登记（PluginRouteScanner 消费）
    private let routeClasses: HashMap<String, String>

    /// L3 进程隔离轨总控（cordis-cj 集成，PS-T025）
    /// 懒初始化：仅当 plugins.yaml 含 mode:process 条目时才创建
    private var cordisHostManager: ?CordisHostManager = None

    public init(
        registry!: PluginRegistry,
        loader!: PluginLoader,
        eventBus!: PluginEventBus,
        skillBridge!: SkillBridge,
        configParser!: PluginConfigParser,
        pluginsRoot!: String = "./plugins",
        router!: ?Router = None
    ) {
        this.registry = registry
        this.loader = loader
        this.eventBus = eventBus
        this.skillBridge = skillBridge
        this.configParser = configParser
        this.pluginsRoot = pluginsRoot
        this.router = router
        this.serviceRegistry = BeanFactoryServiceRegistry()
        this.contexts = HashMap<String, PluginContext>()
        this.classNames = HashMap<String, String>()
        this.routeClasses = HashMap<String, String>()
        // SPI 日志钩子接入宿主日志（PS-T017：plugin_spi 包不得依赖 magic.log，
        // PluginContext/ServiceRegistry/PluginEventBus 内部日志经此汇入 LogUtils）
        PluginSpiLogger.errorSink = { msg => LogUtils.error(msg) }
        PluginSpiLogger.warnSink = { msg => LogUtils.warn(msg) }
        PluginSpiLogger.infoSink = { msg => LogUtils.info(msg) }
    }

    /**
     * 获取或懒初始化 CordisHostManager（三轨分发 process 轨用）
     *
     * 仅当 plugins.yaml 含 mode:process 条目时才创建实例，
     * 避免无进程插件时引入 cordis_host 依赖开销。
     */
    private func ensureCordisHostManager(): CordisHostManager {
        match (this.cordisHostManager) {
            case Some(mgr) => return mgr
            case None =>
                let mgr = CordisHostManager()
                this.cordisHostManager = Some(mgr)
                return mgr
        }
    }

    /**
     * 获取 CordisHostManager（ExternalPluginRouteGateway / 宿主侧服务代理用）
     *
     * @return Option<CordisHostManager>——None 表示未启用 L3 进程轨
     */
    public func cordisHost(): ?CordisHostManager {
        this.cordisHostManager
    }

    /**
     * 启动时全量加载（读 plugins.yaml -> 依序加载 -> 激活 -> 注册技能）
     *
     * 单插件失败不阻断其他插件；plugins.yaml 缺失时静默返回空结果
     * （插件系统为可选增强，未配置即无插件）
     */
    public func loadAll(configPath: String): LoadResult {
        let result = LoadResult()

        if (!exists(configPath)) {
            LogUtils.info("[PluginHostManager] plugins.yaml not found at ${configPath}, plugin system disabled")
            return result
        }

        let parsed = this.configParser.parseFromFile(configPath)
        match (parsed) {
            case Err(err) =>
                LogUtils.error("[PluginHostManager] failed to parse plugins.yaml: ${err.message()}")
                return result
            case Ok(list) =>
                LogUtils.info(
                    "[PluginHostManager] loading plugins: total=${list.plugins.size}, enabled=${list.enabledCount()}")
                // 三轨分发：sync/dylib 走 loadSingle（反射实例化）；
                // process 委托 CordisHostManager（cordis-cj 进程隔离轨，PS-T025）
                var hasProcess = false
                for (entry in list.plugins) {
                    if (!entry.enabled) {
                        result.skipped.add("${entry.name}(disabled)")
                        continue
                    }
                    match (entry.mode) {
                        case PluginMode.Sync | PluginMode.Dylib =>
                            this.loadSingle(entry, result)
                        case PluginMode.Process =>
                            hasProcess = true
                    }
                }
                // process 轨批量启动（期望状态生成 → reconcile → awaitActive）
                if (hasProcess) {
                    let mgr = this.ensureCordisHostManager()
                    let procResult = mgr.loadProcessPlugins(list)
                    for (name in procResult.loaded) {
                        result.loaded.add(name)
                    }
                    for (name in procResult.failed) {
                        result.failed.add(name)
                    }
                    for (name in procResult.skipped) {
                        result.skipped.add(name)
                    }
                    // process 轨 V4 CRUD 路由注册（ExternalPluginRouteGateway）
                    this.registerProcessPluginRoutes(list, mgr)
                }
                LogUtils.info("[PluginHostManager] load finished: ${result.summary()}")
                return result
            case _ =>
                LogUtils.error("[PluginHostManager] unexpected parse result for plugins.yaml")
                return result
        }
    }

    /// process 轨 V4 CRUD 路由注册
    /// 读取每个 process 插件 plugin.yaml 的 routes 字段，
    /// 经 ExternalPluginRouteGateway 注册到宿主路由表
    private func registerProcessPluginRoutes(list: PluginList, mgr: CordisHostManager): Unit {
        match (this.router) {
            case None =>
                LogUtils.warn("[PluginHostManager] router not provided, skipping process plugin route registration")
                return
            case Some(router) =>
                let host = mgr.host()
                let gateway = ExternalPluginRouteGateway(router, host)
                for (entry in list.plugins) {
                    if (entry.mode != PluginMode.Process || !entry.enabled) {
                        continue
                    }
                    // 读取 plugin.yaml 的 routes 字段
                    // process 轨插件在 skills/{name}/ 目录下
                    let pluginYamlPath = "./skills/${entry.name}/plugin.yaml"
                    match (this.parsePluginYamlRoutes(pluginYamlPath)) {
                        case Ok(routes) =>
                            if (routes.size > 0) {
                                let count = gateway.registerPluginRoutes(entry.name, routes)
                                LogUtils.info("[PluginHostManager] process plugin '${entry.name}' routes registered: ${count}/${routes.size}")
                            }
                        case Err(msg) =>
                            LogUtils.warn("[PluginHostManager] process plugin '${entry.name}' routes parse failed: ${msg}")
                        case _ => ()
                    }
                }
        }
    }

    /// 解析 plugin.yaml 的 routes 字段
    /// @return Ok(ArrayList<ExternalRoute>) 或 Err(错误消息)
    private func parsePluginYamlRoutes(yamlPath: String): Result<ArrayList<ExternalRoute>, String> {
        if (!exists(yamlPath)) {
            return Err("plugin.yaml not found: ${yamlPath}")
        }
        // 读取 plugin.yaml 文件内容
        let content = match (readFileContent(yamlPath)) {
            case Some(c) => c
            case None => return Err("failed to read plugin.yaml: ${yamlPath}")
        }
        // 解析 YAML routes 字段
        // plugin.yaml 格式：
        // routes:
        //   - method: POST
        //     path: /api/v1/uctoo/codelabs/add
        let routes = ArrayList<ExternalRoute>()
        let lines = content.split("\n")
        var inRoutesSection = false
        var i = 0
        while (i < lines.size) {
            let line = lines[i]
            if (line.startsWith("routes:")) {
                inRoutesSection = true
                i += 1
                continue
            }
            if (inRoutesSection) {
                // routes section 结束条件：遇到非缩进的顶层 key
                if (line.size > 0 && !line.startsWith(" ") && !line.startsWith("\t") && !line.startsWith("-")) {
                    inRoutesSection = false
                    i += 1
                    continue
                }
                // 解析 "- method: XXX" 行
                if (line.contains("- method:") || line.contains("-   method:")) {
                    var methodStr = ""
                    var pathStr = ""
                    // 提取 method
                    let methodIdx = match (line.indexOf("method:")) { case Some(i) => i + 7; case None => line.size }
                    let methodPart = if (methodIdx < line.size) { line[methodIdx..] } else { "" }
                    methodStr = methodPart.trimStart(" \t\r\n").trimEnd(" \t\r\n")
                    // 下一行应该是 path
                    if (i + 1 < lines.size) {
                        let nextLine = lines[i + 1]
                        if (nextLine.contains("path:")) {
                            let pathIdx = match (nextLine.indexOf("path:")) { case Some(i) => i + 5; case None => nextLine.size }
                            let pathPart = if (pathIdx < nextLine.size) { nextLine[pathIdx..] } else { "" }
                            pathStr = pathPart.trimStart(" \t\r\n").trimEnd(" \t\r\n")
                            i += 2
                            // 构造 ExternalRoute
                            let httpMethod = match (methodStr) {
                                case "GET" => HttpMethod.GET
                                case "POST" => HttpMethod.POST
                                case "PUT" => HttpMethod.PUT
                                case "DELETE" => HttpMethod.DELETE
                                case _ => HttpMethod.POST
                            }
                            routes.add(ExternalRoute(httpMethod, pathStr))
                            continue
                        }
                    }
                    i += 1
                    continue
                }
            }
            i += 1
        }
        return Ok(routes)
    }

    /// 读取文件内容（辅助方法）
    private func readFileContent(path: String): ?String {
        try {
            let file = File(path, OpenMode.Read)
            let reader = StringReader(file)
            let content = reader.readToEnd()
            file.close()
            return Some(content)
        } catch (e: Exception) {
            return None
        }
    }

    /// 加载单个插件条目（load -> onLoad -> onActivate -> 注册 -> 技能）
    private func loadSingle(entry: PluginManifestEntry, result: LoadResult): Unit {
        let name = entry.name

        // 幂等：已注册则跳过
        match (this.registry.get(name)) {
            case Some(_) =>
                result.skipped.add("${name}(already-loaded)")
                return
            case None => ()
        }

        this.registry.setState(name, PluginState.Loading)

        // 构造插件上下文（容器句柄 + 参数注入）
        let context = PluginContext(
            name,
            this.serviceRegistry,
            this.eventBus,
            this.skillBridge,
            entry.config
        )

        // 反射发现与实例化（含注解/依赖校验）
        match (this.loader.load(entry.className, context)) {
            case Err(err) =>
                LogUtils.error("[PluginHostManager] load failed '${name}': ${err.message()}")
                this.registry.setState(name, PluginState.Error)
                this.emitLifecycle("plugin.error", name, error: err.message())
                result.failed.add("${name}(${err.message()})")
                return
            case Ok(plugin) =>
                // onLoad 钩子（异常 -> Error 态）
                try {
                    plugin.onLoad(context)
                } catch (e: Exception) {
                    LogUtils.error("[PluginHostManager] onLoad failed '${name}': ${e.message}")
                    this.registry.setState(name, PluginState.Error)
                    this.emitLifecycle("plugin.error", name, error: e.message)
                    result.failed.add("${name}(onLoad: ${e.message})")
                    return
                }
                // onActivate 钩子（异常 -> Error 态）
                try {
                    plugin.onActivate()
                } catch (e: Exception) {
                    LogUtils.error("[PluginHostManager] onActivate failed '${name}': ${e.message}")
                    this.registry.setState(name, PluginState.Error)
                    this.emitLifecycle("plugin.error", name, error: e.message)
                    result.failed.add("${name}(onActivate: ${e.message})")
                    return
                }
                // 注册 + 技能桥接
                match (this.registry.register(plugin)) {
                    case Ok(_) =>
                        this.contexts[name] = context
                        this.classNames[name] = entry.className
                        match (entry.routeClass) {
                            case Some(routeClass) => this.routeClasses[name] = routeClass
                            case None => ()
                        }
                        this.registry.setState(name, PluginState.Active)
                        let pluginDir = "${this.pluginsRoot}/${name}"
                        let skillCount = this.skillBridge.registerPluginSkills(pluginDir, name)
                        LogUtils.info("[PluginHostManager] plugin activated: ${name} (skills=${skillCount})")
                        result.loaded.add(name)
                        this.emitLifecycle("plugin.activated", name)
                    case Err(err) =>
                        this.registry.setState(name, PluginState.Error)
                        this.emitLifecycle("plugin.error", name, error: err.message())
                        result.failed.add("${name}(${err.message()})")
                    case _ =>
                        this.registry.setState(name, PluginState.Error)
                        this.emitLifecycle("plugin.error", name, error: "register: unexpected result")
                        result.failed.add("${name}(register: unexpected result)")
                }
            case _ =>
                this.registry.setState(name, PluginState.Error)
                this.emitLifecycle("plugin.error", name, error: "load: unexpected result")
                result.failed.add("${name}(load: unexpected result)")
        }
    }

    /**
     * 激活单个已加载插件（Pending 态 -> Active）
     *
     * Error 态插件须修复后经 loadAll 重载
     */
    public func activate(name: String): Result<Unit, PluginError> {
        match (this.registry.get(name)) {
            case None => return Err(PluginError.NotFound(name))
            case Some(plugin) =>
                match (this.registry.getState(name)) {
                    case Some(PluginState.Pending) =>
                        try {
                            plugin.onActivate()
                            this.registry.setState(name, PluginState.Active)
                            return Ok(())
                        } catch (e: Exception) {
                            this.registry.setState(name, PluginState.Error)
                            return Err(PluginError.LifecycleError("onActivate: ${e.message}"))
                        }
                    case Some(PluginState.Active) =>
                        return Ok(())  // 幂等
                    case Some(state) =>
                        return Err(PluginError.LifecycleError(
                            "cannot activate from state ${stateToString(state)}"))
                    case None =>
                        return Err(PluginError.NotFound(name))
                }
        }
    }

    /**
     * 停用单个插件（完整卸载：钩子 -> 清理栈 -> 订阅清理 -> 注销 -> 快照回滚）
     *
     * 钩子异常不阻断清理流程（design.md §2.1.4 约定）
     */
    public func deactivate(name: String): Result<Unit, PluginError> {
        let snapshot = this.registry.snapshot()
        match (this.registry.get(name)) {
            case None => return Err(PluginError.NotFound(name))
            case Some(plugin) =>
                // onDeactivate（异常记日志继续）
                try {
                    plugin.onDeactivate()
                } catch (e: Exception) {
                    LogUtils.error("[PluginHostManager] onDeactivate error '${name}': ${e.message}")
                }
                // onUnload（异常记日志继续）
                try {
                    plugin.onUnload()
                } catch (e: Exception) {
                    LogUtils.error("[PluginHostManager] onUnload error '${name}': ${e.message}")
                }
                // 清理栈逆序执行 + 订阅清理 + 技能登记清理
                match (this.contexts.get(name)) {
                    case Some(context) => context.executeCleanups()
                    case None => ()
                }
                this.eventBus.unsubscribeAll(name)
                this.skillBridge.clearPluginSkills(name)
                this.contexts.remove(name)
                this.classNames.remove(name)
                this.routeClasses.remove(name)
                // 注销 + 回滚快照（移除快照后新注册项，保持注册表一致性）
                this.registry.unregister(name)
                this.registry.restore(snapshot)
                LogUtils.info("[PluginHostManager] plugin deactivated: ${name}")
                this.emitLifecycle("plugin.deactivated", name)
                this.emitLifecycle("plugin.unloaded", name)
                return Ok(())
        }
    }

    /**
     * 检视（Agent 工具 pluginInspect 用）
     *
     * 无参：全量插件列表（名 + 状态）；指定 name：插件详情（含技能目录）
     */
    public func inspect(name!: Option<String> = None): String {
        match (name) {
            case Some(n) =>
                match (this.registry.get(n)) {
                    case None => return "plugin not found: ${n}"
                    case Some(plugin) =>
                        let state = match (this.registry.getState(n)) {
                            case Some(s) => stateToString(s)
                            case None => "unknown"
                        }
                        let className = match (this.classNames.get(n)) {
                            case Some(cn) => cn
                            case None => "(unknown)"
                        }
                        let catalog = this.skillBridge.buildCapabilityCatalog(n)
                        return "plugin=${plugin.getName()}\nstate=${state}\nclass=${className}\nskills=${catalog.toString()}"
                }
            case None =>
                let all = this.registry.listAll()
                if (all.isEmpty()) {
                    return "no plugins loaded"
                }
                var sb = ""
                for (plugin in all) {
                    let n = plugin.getName()
                    let state = match (this.registry.getState(n)) {
                        case Some(s) => stateToString(s)
                        case None => "unknown"
                    }
                    sb += "- ${n}: ${state}\n"
                }
                return sb
        }
    }

    /// 发射插件生命周期事件（PluginSyncBridge 等订阅方消费，design.md §2.3）
    ///
    /// 事件类型：plugin.activated / plugin.deactivated / plugin.error / plugin.unloaded
    private func emitLifecycle(eventType: String, name: String, error!: String = ""): Unit {
        let payload = JsonObject()
        payload.put("name", JsonString(name))
        if (!error.isEmpty()) {
            payload.put("error", JsonString(error))
        }
        this.eventBus.emit(eventType, payload)
    }

    /// 事件总线句柄（供宿主直接广播插件事件）
    public func bus(): PluginEventBus {
        return this.eventBus
    }

    /**
     * 已激活插件声明的 Route 类全名清单（PluginRouteScanner 消费）
     *
     * 仅返回 Active 插件在 plugins.yaml 中声明的 routeClass；
     * 插件停用后对应条目随之移除（未声明 routeClass 的插件不出现在清单中）
     */
    public func routeClassNames(): ArrayList<String> {
        let result = ArrayList<String>()
        for (name in this.routeClasses.keys()) {
            // 只暴露当前仍处于注册表中的插件（防御 routeClasses 残留）
            if (this.registry.get(name).isSome()) {
                match (this.routeClasses.get(name)) {
                    case Some(routeClass) => result.add(routeClass)
                    case None => ()
                }
            }
        }
        return result
    }

    /// 服务注册表句柄（供宿主消费插件服务）
    public func services(): ServiceRegistry {
        return this.serviceRegistry
    }

    /// 注册表句柄（供宿主查询插件状态）
    public func registryRef(): PluginRegistry {
        return this.registry
    }

    /// 状态显式转字符串（避免依赖 enum 默认字符串化行为）
    private static func stateToString(state: PluginState): String {
        match (state) {
            case PluginState.Pending => "Pending"
            case PluginState.Loading => "Loading"
            case PluginState.Active => "Active"
            case PluginState.Error => "Error"
            case PluginState.Disposed => "Disposed"
        }
    }
}
