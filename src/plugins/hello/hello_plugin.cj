/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.hello

import stdx.encoding.json.{JsonValue, JsonObject, JsonString}
import magic.log.LogUtils
import plugin_spi.{Plugin, PluginContext, PluginAnnotation}

/**
 * GreetingService - 问候服务接口（插件对外契约）
 *
 * 服务注册名 = 接口全限定名 "magic.plugins.hello.GreetingService"，
 * 消费方经 ServiceRegistry.getService<GreetingService>() 类型安全轨获取
 */
public interface GreetingService {
    /// 生成问候语
    func greet(name: String): String
}

/**
 * DefaultGreetingService - 默认问候实现
 *
 * 问候前缀经 plugins.yaml 的 config.greetingPrefix 注入（缺省 "Hello"）
 */
public class DefaultGreetingService <: GreetingService {
    private let prefix: String

    public init(prefix!: String = "Hello") {
        this.prefix = prefix
    }

    public func greet(name: String): String {
        return "${this.prefix}, ${name}!"
    }
}

/**
 * HelloPlugin - 纯 Service 示例插件（PS-T009）
 *
 * 演示最小插件形态：仅注册确定性服务，无 SKILL.md、无路由。
 * plugins.yaml 置 enabled=false 后本插件不加载。
 *
 * 生命周期演示：onLoad 注册服务 + 登记可逆清理；卸载时清理栈逆序注销服务
 */
@PluginAnnotation[name: "hello", version: "1.0.0", dependencies: ""]
public class HelloPlugin <: Plugin {
    public init() {}

    public func getName(): String {
        return "hello"
    }

    public func onLoad(context: PluginContext): Unit {
        // config 参数注入（plugins.yaml 的 config.greetingPrefix，缺省 "Hello"）
        let prefix = HelloPlugin.readGreetingPrefix(context.config)
        let service = DefaultGreetingService(prefix: prefix)

        // 注册服务（注册名 = 服务接口全限定名，服务命名契约见 ServiceRegistry）
        let ok = context.registerService("magic.plugins.hello.GreetingService", service)
        if (ok) {
            LogUtils.info("[HelloPlugin] greeting service registered (prefix='${prefix}')")
        } else {
            LogUtils.error("[HelloPlugin] greeting service register failed: name conflict")
        }

        // 可逆清理：插件卸载时注销服务（清理栈逆序执行）
        context.onCleanup({ =>
            let removed = context.serviceRegistry.unregister("magic.plugins.hello.GreetingService")
            LogUtils.info("[HelloPlugin] greeting service cleanup: removed=${removed}")
        })
    }

    public func onActivate(): Unit {
        LogUtils.info("[HelloPlugin] activated")
    }

    public func onDeactivate(): Unit {
        LogUtils.info("[HelloPlugin] deactivated")
    }

    public func onUnload(): Unit {
        LogUtils.info("[HelloPlugin] unloaded")
    }

    /// 从 config JSON 读取问候前缀（缺省 "Hello"）
    private static func readGreetingPrefix(config: JsonValue): String {
        if (config is JsonObject) {
            let fields = (config as JsonObject).getOrThrow().getFields()
            if (let Some(prefixVal) <- fields.get("greetingPrefix")) {
                if (prefixVal is JsonString) {
                    return (prefixVal as JsonString).getOrThrow().getValue()
                }
            }
        }
        return "Hello"
    }
}
