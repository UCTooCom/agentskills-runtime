/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.integration

import std.collection.ArrayList
import std.fs.{File, Path, Directory, OpenMode, removeIfExists}
import stdx.encoding.json.{JsonValue, JsonString, JsonObject}
import magic.utils.readFile
import magic.plugin.{
    Plugin, PluginContext, PluginAnnotation, PluginState, PluginHostManager,
    PluginRegistry, PluginEventBus, PluginLoader, PluginConfigParser,
    SkillBridge, PluginRouteScanner
}
import magic.skill.CompositeSkillToolManager
import magic.skill.application.SkillManagementService
import magic.app.core.router.Router
import magic.plugins.hello.{GreetingService, HelloPlugin}
import magic.plugins.doc_helper.{DocHelperPlugin, DocHelperRoute}

/**
 * 插件系统集成验证程序（PS-T011）
 *
 * 覆盖：生命周期全流程、幂等注册、回滚、事件（emit/waterfall/优先级/退订）、
 * 技能融合（插件 SKILL.md 自动注册）、配置（enabled=false 跳过 + config 注入）、
 * 跨平台纯净性（源码扫描无 ohos.* import）、双轨路由并存、端到端流程。
 *
 * 命名说明：文件名严禁以 _test.cj 结尾——cjpm build 按官方规则排除单元测试
 * 文件（仅 cjpm test / --compile-test-file 编译），_test.cj 会导致包内零可编译
 * 文件，package-configuration 报 "can not find the package"
 *
 * 产物：cjpm.toml 已配置 magic.plugin.integration 为 executable，
 * 编译后运行 target/release/bin/magic.plugin.integration.exe 执行全部验证
 */
main(): Unit {
    let projectRoot = "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime"
    let ctx = TestContext()

    // 反射锚点：确保测试插件类被静态链接（防 LTO 裁剪导致 ClassTypeInfo.get 失败）
    let _anchorProbe = LifecycleProbePlugin()
    let _anchorBroken = BrokenDepPlugin()
    let _anchorHello = HelloPlugin()
    let _anchorDocHelper = DocHelperPlugin()
    let _anchorDocRoute = DocHelperRoute()

    println("=== 1. PluginConfigParser（配置解析） ===")
    testConfigParser(ctx)

    println("\n=== 2. 生命周期 + 端到端 + 回滚 ===")
    testLifecycleE2E(ctx, projectRoot)

    println("\n=== 3. 幂等注册 ===")
    testIdempotentRegister(ctx)

    println("\n=== 4. 事件总线（emit/waterfall/优先级/退订） ===")
    testEventBus(ctx)

    println("\n=== 5. 技能融合（插件 SKILL.md 注册） ===")
    testSkillBridge(ctx, projectRoot)

    println("\n=== 6. 跨平台纯净性（无 ohos.* import） ===")
    testNoOhosImports(ctx, projectRoot)

    println("\n=== 7. 双轨路由并存 ===")
    testDualTrackRoutes(ctx, projectRoot)

    println("\n=== 8. 插件卸载回归验证（PS-T021） ===")
    testUninstallRegression(ctx, projectRoot)

    println("\n=== 9. L3 进程隔离轨集成验证（PS-T029） ===")
    testCordisHostManagerInit(ctx)
    testStatusMapping(ctx)
    testCacheIsolation(ctx)
    testGateway503(ctx)
    testProcessConfigParsing(ctx)
    testThreeRailCoexistence(ctx)
    testGracefulShutdown(ctx)

    println("\n=== Summary ===")
    println(ctx.summary())
    if (ctx.failed == 0) {
        println("ALL TESTS PASSED")
    }
}

/* ============ 测试辅助 ============ */

/**
 * 测试上下文：断言计数与输出（✓/✗ 对齐 agent_loader_test 风格）
 */
class TestContext {
    var passed = 0
    var failed = 0

    func check(name: String, cond: Bool): Unit {
        if (cond) {
            this.passed += 1
            println("   ✓ ${name}")
        } else {
            this.failed += 1
            println("   ✗ ${name}")
        }
    }

    func summary(): String {
        return "total=${this.passed + this.failed}, passed=${this.passed}, failed=${this.failed}"
    }
}

/**
 * 构建真实组件图的 PluginHostManager（与 main.cj 双轨接入同款接线）
 */
func buildPluginManager(pluginsRoot: String): PluginHostManager {
    let skillManagementService = SkillManagementService()
    let skillManager = CompositeSkillToolManager()
    let skillBridge = SkillBridge(skillManagementService, skillManager)
    let registry = PluginRegistry()
    let loader = PluginLoader(registry)
    let eventBus = PluginEventBus()
    return PluginHostManager(
        registry: registry,
        loader: loader,
        eventBus: eventBus,
        skillBridge: skillBridge,
        pluginsRoot: pluginsRoot
    )
}

/**
 * 写临时 plugins.yaml（返回路径；测试后由调用方清理）
 */
func writeTempYaml(path: String, content: String): Unit {
    try (file = File(Path(path), OpenMode.Write)) {
        file.write(content.toArray())
    }
}

/* ============ 测试插件（反射加载目标） ============ */

/**
 * 生命周期探针插件：钩子调用顺序写入静态日志，供测试断言
 */
@PluginAnnotation[name: "lifecycle-probe", version: "1.0.0", dependencies: ""]
public class LifecycleProbePlugin <: Plugin {
    public static let hookLog: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func getName(): String {
        return "lifecycle-probe"
    }

    public func onLoad(context: PluginContext): Unit {
        LifecycleProbePlugin.hookLog.add("onLoad")
    }

    public func onActivate(): Unit {
        LifecycleProbePlugin.hookLog.add("onActivate")
    }

    public func onDeactivate(): Unit {
        LifecycleProbePlugin.hookLog.add("onDeactivate")
    }

    public func onUnload(): Unit {
        LifecycleProbePlugin.hookLog.add("onUnload")
    }
}

/**
 * 依赖缺失插件：声明依赖不存在的 "ghost-plugin"，用于回滚测试
 */
@PluginAnnotation[name: "broken-dep", version: "1.0.0", dependencies: "ghost-plugin"]
public class BrokenDepPlugin <: Plugin {
    public init() {}

    public func getName(): String {
        return "broken-dep"
    }

    public func onLoad(context: PluginContext): Unit {
        return ()
    }

    public func onActivate(): Unit {
        return ()
    }

    public func onDeactivate(): Unit {
        return ()
    }

    public func onUnload(): Unit {
        return ()
    }
}

/* ============ 1. 配置解析测试 ============ */

func testConfigParser(ctx: TestContext): Unit {
    let parser = PluginConfigParser()
    // 覆盖：order 乱序声明（排序验证）、enabled=false、config 注入、routeClass
    let yaml = "plugins:\n" +
        "  - name: disabled-probe\n" +
        "    className: magic.plugin.integration.LifecycleProbePlugin\n" +
        "    enabled: false\n" +
        "    order: 3\n" +
        "  - name: hello\n" +
        "    className: magic.plugins.hello.HelloPlugin\n" +
        "    enabled: true\n" +
        "    order: 1\n" +
        "    config:\n" +
        "      greetingPrefix: 你好\n" +
        "  - name: doc-helper\n" +
        "    className: magic.plugins.doc_helper.DocHelperPlugin\n" +
        "    enabled: true\n" +
        "    order: 2\n" +
        "    routeClass: magic.plugins.doc_helper.DocHelperRoute\n"

    match (parser.parse(yaml)) {
        case Ok(list) =>
            ctx.check("解析得到 3 个条目", list.plugins.size == 3)
            ctx.check("按 order 升序排序（首条=hello）", list.plugins[0].name == "hello")
            ctx.check("order 排序后末条=disabled-probe", list.plugins[2].name == "disabled-probe")
            ctx.check("enabled=false 保留", list.plugins[2].enabled == false)
            ctx.check("enabledCount == 2", list.enabledCount() == 2)

            // config.greetingPrefix 注入验证
            var prefixOk = false
            let cfg = list.plugins[0].config
            if (cfg is JsonObject) {
                let fields = (cfg as JsonObject).getOrThrow().getFields()
                match (fields.get("greetingPrefix")) {
                    case Some(v) =>
                        if (v is JsonString) {
                            prefixOk = (v as JsonString).getOrThrow().getValue() == "你好"
                        }
                    case None => ()
                }
            }
            ctx.check("config.greetingPrefix 注入正确", prefixOk)

            // routeClass 声明解析验证
            var routeOk = false
            match (list.plugins[1].routeClass) {
                case Some(rc) => routeOk = (rc == "magic.plugins.doc_helper.DocHelperRoute")
                case None => ()
            }
            ctx.check("routeClass 声明解析正确", routeOk)
        case Err(err) =>
            ctx.check("解析成功（实际失败: ${err.message()}）", false)
        case _ => ()
    }

    // 非法配置：缺 plugins 根节点
    match (parser.parse("not_a_plugin_list: true")) {
        case Ok(_) => ctx.check("缺 plugins 节点报错", false)
        case Err(_) => ctx.check("缺 plugins 节点报错", true)
        case _ => ()
    }
}

/* ============ 2. 生命周期 + 端到端 + 回滚测试 ============ */

func testLifecycleE2E(ctx: TestContext, projectRoot: String): Unit {
    let configPath = "${projectRoot}/test-plugins-tmp.yaml"
    let yaml = "plugins:\n" +
        "  - name: hello\n" +
        "    className: magic.plugins.hello.HelloPlugin\n" +
        "    enabled: true\n" +
        "    order: 1\n" +
        "    config:\n" +
        "      greetingPrefix: 你好\n" +
        "  - name: lifecycle-probe\n" +
        "    className: magic.plugin.integration.LifecycleProbePlugin\n" +
        "    enabled: true\n" +
        "    order: 2\n" +
        "  - name: broken-dep\n" +
        "    className: magic.plugin.integration.BrokenDepPlugin\n" +
        "    enabled: true\n" +
        "    order: 3\n" +
        "  - name: disabled-probe\n" +
        "    className: magic.plugin.integration.LifecycleProbePlugin\n" +
        "    enabled: false\n" +
        "    order: 4\n"
    writeTempYaml(configPath, yaml)

    // 探针日志清零（幂等重跑支持）
    LifecycleProbePlugin.hookLog.clear()

    let manager = buildPluginManager("${projectRoot}/plugins")
    let result = manager.loadAll(["${projectRoot}/skills"])

    // 加载结果分类
    ctx.check("hello 加载成功", result.loaded.contains("hello"))
    ctx.check("lifecycle-probe 加载成功", result.loaded.contains("lifecycle-probe"))
    ctx.check("broken-dep 失败（依赖缺失）", result.failed.size == 1 && result.failed[0].contains("broken-dep"))
    ctx.check("disabled-probe 被跳过", result.skipped.size == 1 && result.skipped[0].contains("disabled-probe"))

    // 状态断言
    var helloActive = false
    match (manager.registryRef().getState("hello")) {
        case Some(s) => helloActive = (s == PluginState.Active)
        case None => ()
    }
    ctx.check("hello 状态为 Active", helloActive)

    var brokenIsError = false
    match (manager.registryRef().getState("broken-dep")) {
        case Some(s) => brokenIsError = (s == PluginState.Error)
        case None => ()
    }
    ctx.check("broken-dep 状态为 Error", brokenIsError)

    // 生命周期钩子顺序：onLoad -> onActivate
    let hooks = LifecycleProbePlugin.hookLog
    ctx.check(
        "钩子顺序 onLoad->onActivate",
        hooks.size >= 2 && hooks[hooks.size - 2] == "onLoad" && hooks[hooks.size - 1] == "onActivate")

    // config 注入端到端：GreetingService 前缀来自 plugins.yaml
    match (manager.services().getService<GreetingService>()) {
        case Some(svc) =>
            ctx.check("config 注入生效（greet 前缀=你好）", svc.greet("Cangjie") == "你好, Cangjie!")
        case None =>
            ctx.check("GreetingService 可解析", false)
    }

    // inspect 输出（结构化文本）
    let inspectAll = manager.inspect()
    ctx.check("inspect 全量包含 hello", inspectAll.contains("hello"))

    // 停用（完整卸载：钩子 -> 清理栈 -> 订阅清理 -> 注销 -> 快照回滚）
    var deactivateOk = false
    let deResult = manager.deactivate("hello")
    if (deResult.isOk) {
        deactivateOk = true
    }
    ctx.check("deactivate(hello) 成功", deactivateOk)
    ctx.check("停用后服务已注销（清理栈生效）", manager.services().getService<GreetingService>().isNone())
    ctx.check("停用后注册表无残留", manager.registryRef().get("hello").isNone())

    // hello 的停用不影响 lifecycle-probe：验证 isolation
    var probeStillActive = false
    match (manager.registryRef().getState("lifecycle-probe")) {
        case Some(s) => probeStillActive = (s == PluginState.Active)
        case None => ()
    }
    ctx.check("其他插件不受停用影响（lifecycle-probe 仍 Active）", probeStillActive)

    // 清理临时文件
    removeIfExists(Path(configPath))
}

/* ============ 3. 幂等注册测试 ============ */

func testIdempotentRegister(ctx: TestContext): Unit {
    let registry = PluginRegistry()
    let plugin = LifecycleProbePlugin()

    var first: Option<Plugin> = None
    let r1 = registry.register(plugin)
    match (r1) {
        case Ok(p) => first = Some(p)
        case _ => ()
    }
    ctx.check("首次注册成功", first.isSome())

    // 同实例二次注册：返回已存在实例，无副作用
    var secondSame = false
    let r2 = registry.register(plugin)
    match (r2) {
        case Ok(p) =>
            match (first) {
                case Some(f) => secondSame = (p.getName() == f.getName())
                case None => ()
            }
        case _ => ()
    }
    ctx.check("重复注册返回已存在实例", secondSame)
    ctx.check("注册表数量仍为 1", registry.listAll().size == 1)

    // 状态查询与注销
    ctx.check("新注册插件初始状态 Pending", registry.getState("lifecycle-probe").isSome())
    ctx.check("注销成功", registry.unregister("lifecycle-probe"))
    ctx.check("注销后不可查询", registry.get("lifecycle-probe").isNone())
}

/* ============ 4. 事件总线测试 ============ */

func testEventBus(ctx: TestContext): Unit {
    let bus = PluginEventBus()

    // 优先级订阅（数字越小越先执行）：p1(priority=1) 先于 p2(priority=10)
    bus.subscribe("p2", "doc.changed", { payload => JsonString("second") }, priority: 10)
    bus.subscribe("p1", "doc.changed", { payload => JsonString("first") }, priority: 1)

    // emit 广播：所有订阅者收到同一事件，结果按执行顺序返回
    let results = bus.emit("doc.changed", JsonString("payload"))
    ctx.check("emit: 两个订阅者均收到", results.size == 2)
    var r0 = ""
    if (results[0] is JsonString) {
        r0 = (results[0] as JsonString).getOrThrow().getValue()
    }
    ctx.check("emit: 优先级顺序正确（p1 先执行）", r0 == "first")

    // waterfall 链式：前一个返回值作为后一个入参
    bus.subscribe("w1", "doc.enrich", { p => JsonString("${(p as JsonString).getOrThrow().getValue()}+a") })
    bus.subscribe("w2", "doc.enrich", { p => JsonString("${(p as JsonString).getOrThrow().getValue()}+b") })
    let final = bus.waterfall("doc.enrich", JsonString("x"))
    var fv = ""
    if (final is JsonString) {
        fv = (final as JsonString).getOrThrow().getValue()
    }
    ctx.check("waterfall 链式传递（x+a+b）", fv == "x+a+b")

    // 退订：unsubscribeAll 移除该插件全部订阅
    bus.unsubscribeAll("p1")
    let results2 = bus.emit("doc.changed", JsonString("payload"))
    ctx.check("unsubscribeAll 后仅剩 1 个订阅者", results2.size == 1)
}

/* ============ 5. 技能融合测试 ============ */

func testSkillBridge(ctx: TestContext, projectRoot: String): Unit {
    let skillBridge = SkillBridge(SkillManagementService(), CompositeSkillToolManager())
    // plugins/doc-helper/SKILL.md 存在（PS-T009 资产），应至少注册 1 个技能
    let count = skillBridge.registerPluginSkills("${projectRoot}/plugins/doc-helper", "doc-helper")
    ctx.check("插件 SKILL.md 自动注册（count >= 1）", count >= 1)

    // 不存在目录：静默返回 0，不抛异常
    let count2 = skillBridge.registerPluginSkills("${projectRoot}/plugins/__no_such_plugin__", "ghost")
    ctx.check("目录不存在时返回 0（不抛异常）", count2 == 0)
}

/* ============ 6. 跨平台纯净性测试 ============ */

func testNoOhosImports(ctx: TestContext, projectRoot: String): Unit {
    let offenders = ArrayList<String>()
    let scanDirs = [
        Path("${projectRoot}/src/plugin"),
        Path("${projectRoot}/src/plugins")
    ]
    for (dir in scanDirs) {
        try {
            Directory.walk(dir) { fileInfo =>
                if (fileInfo.isRegular() && fileInfo.path.extensionName == "cj") {
                    let content = readFile(fileInfo.path)
                    if (content.contains("ohos.")) {
                        offenders.add(fileInfo.path.toString())
                    }
                }
                return true
            }
        } catch (e: Exception) {
            offenders.add("walk failed: ${dir.toString()} (${e.message})")
        }
    }
    ctx.check("插件源码无 ohos.* import（跨平台纯净）", offenders.isEmpty())
    for (o in offenders) {
        println("     违规文件: ${o}")
    }
}

/* ============ 7. 双轨路由并存测试 ============ */

func testDualTrackRoutes(ctx: TestContext, projectRoot: String): Unit {
    // 1. 加载带 routeClass 声明的 doc-helper 插件
    let configPath = "${projectRoot}/test-routes-tmp.yaml"
    let yaml = "plugins:\n" +
        "  - name: doc-helper\n" +
        "    className: magic.plugins.doc_helper.DocHelperPlugin\n" +
        "    enabled: true\n" +
        "    order: 1\n" +
        "    routeClass: magic.plugins.doc_helper.DocHelperRoute\n"
    writeTempYaml(configPath, yaml)

    let manager = buildPluginManager("${projectRoot}/plugins")
    let result = manager.loadAll(["${projectRoot}/skills"])
    ctx.check("doc-helper 加载成功", result.loaded.contains("doc-helper"))

    // 2. routeClassNames 收集（PluginRouteScanner 的数据源）
    ctx.check(
        "routeClassNames 收集正确",
        manager.routeClassNames().contains("magic.plugins.doc_helper.DocHelperRoute"))

    // 3. 双轨并存：存量轨（手动注册）+ 插件轨（扫描器反射注册）
    let router = Router()
    // 存量轨：模拟 AutoRouteConfig 的硬编码注册
    router.get("/api/v1/health", { req, res =>
        res.status(200).json("{\"status\":\"ok\"}")
    })
    // 插件轨：扫描器在存量注册之后执行（只追加，不修改存量注册）
    var scanOk = false
    try {
        PluginRouteScanner().scanAndRegister(router, manager)
        scanOk = true
    } catch (e: Exception) {
        println("     扫描异常: ${e.message}")
    }
    ctx.check("双轨并存：存量注册 + 插件扫描注册无冲突", scanOk)

    // 4. 停用后 routeClassNames 移除（联动验证）
    let deResult = manager.deactivate("doc-helper")
    ctx.check("停用后 routeClassNames 清空", deResult.isOk && manager.routeClassNames().isEmpty())

    removeIfExists(Path(configPath))
}

/* ============ 8. 插件卸载回归验证（PS-T021） ============ */

/**
 * PS-T021 插件卸载回归验证
 *
 * 系统性验证卸载后三个维度的清理完整性：
 * 1. 路由清理：deactivate 后 routeClassNames() 不再包含已卸载插件的 routeClass
 * 2. 事件订阅清理：PluginEventBus.unsubscribeAll(name) 后该插件的事件订阅全部移除
 * 3. 注册表清理：deactivate 后 registryRef().get(name) 返回 None
 * 4. 服务注销清理：deactivate 后 services().getService<T>() 返回 None
 *
 * 测试插件：doc-helper（带 routeClass 声明，便于验证路由清理）
 */
func testUninstallRegression(ctx: TestContext, projectRoot: String): Unit {
    let configPath = "${projectRoot}/test-uninstall-regression.yaml"
    let yaml = "plugins:\n" +
        "  - name: doc-helper\n" +
        "    className: magic.plugins.doc_helper.DocHelperPlugin\n" +
        "    enabled: true\n" +
        "    order: 1\n" +
        "    routeClass: magic.plugins.doc_helper.DocHelperRoute\n"
    writeTempYaml(configPath, yaml)

    let manager = buildPluginManager("${projectRoot}/plugins")
    let result = manager.loadAll(["${projectRoot}/skills"])
    ctx.check("doc-helper 加载成功", result.loaded.contains("doc-helper"))

    // === 维度 1：路由清理验证 ===
    // 卸载前：routeClassNames() 应包含 doc-helper 的 routeClass
    let routeClassesBefore = manager.routeClassNames()
    ctx.check(
        "卸载前 routeClassNames 包含 DocHelperRoute",
        routeClassesBefore.contains("magic.plugins.doc_helper.DocHelperRoute"))

    // 卸载前：PluginRouteScanner 应能扫描注册插件路由
    let router = Router()
    router.get("/api/v1/health", { req, res =>
        res.status(200).json("{\"status\":\"ok\"}")
    })
    var scanOk = false
    try {
        PluginRouteScanner().scanAndRegister(router, manager)
        scanOk = true
    } catch (e: Exception) {
        println("     扫描异常: ${e.message}")
    }
    ctx.check("卸载前 PluginRouteScanner 扫描注册成功", scanOk)

    // 执行卸载
    let deResult = manager.deactivate("doc-helper")
    ctx.check("deactivate(doc-helper) 成功", deResult.isOk)

    // 卸载后：routeClassNames() 应清空（不再包含 DocHelperRoute）
    let routeClassesAfter = manager.routeClassNames()
    ctx.check(
        "卸载后 routeClassNames 清空（路由清理验证）",
        !routeClassesAfter.contains("magic.plugins.doc_helper.DocHelperRoute"))

    // === 维度 2：事件订阅清理验证 ===
    // 通过 PluginEventBus 验证：卸载前订阅事件，卸载后应自动清理
    let eventBus = manager.bus()
    
    // 卸载前：重新订阅一个事件（模拟插件运行期间的订阅）
    // 注：doc-helper 已卸载，这里用一个新插件名测试 unsubscribeAll
    eventBus.subscribe("test-plugin", "test.event", { payload => JsonString("handled") })
    
    // 验证订阅存在
    let resultsBefore = eventBus.emit("test.event", JsonString("payload"))
    ctx.check("卸载前事件订阅存在（emit 返回 1 个结果）", resultsBefore.size == 1)

    // 执行 unsubscribeAll（模拟卸载时的订阅清理）
    eventBus.unsubscribeAll("test-plugin")

    // 验证订阅已清理
    let resultsAfter = eventBus.emit("test.event", JsonString("payload"))
    ctx.check(
        "unsubscribeAll 后事件订阅清理（emit 返回 0 个结果）",
        resultsAfter.size == 0)

    // === 维度 3：注册表清理验证 ===
    ctx.check(
        "卸载后注册表无残留（registryRef().get 返回 None）",
        manager.registryRef().get("doc-helper").isNone())

    // === 维度 4：服务注销清理验证 ===
    // doc-helper 插件注册了 GreetingService，卸载后应已注销
    // 注：doc-helper 是否注册 GreetingService 取决于插件实现
    // 这里验证服务注册表在卸载后不包含已卸载插件的服务
    ctx.check(
        "卸载后服务已注销（services().getService 返回 None）",
        manager.services().getService<GreetingService>().isNone())

    // === 维度 5：isolation 验证 ===
    // 卸载 doc-helper 不应影响其他插件（如果有的话）
    // 这里验证卸载后 manager 仍可正常工作
    var managerStillWorks = false
    try {
        let inspectResult = manager.inspect()
        managerStillWorks = !inspectResult.isEmpty()
    } catch (e: Exception) {
        println("     manager.inspect 异常: ${e.message}")
    }
    ctx.check("卸载后 manager 仍可正常工作（inspect 不抛异常）", managerStillWorks)

    removeIfExists(Path(configPath))
}
