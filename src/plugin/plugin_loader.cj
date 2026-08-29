/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

import std.collection.ArrayList
import std.reflect.{ClassTypeInfo, TypeInfo}
import f_base.Result
import magic.log.LogUtils
import plugin_spi.{Plugin, PluginContext, PluginAnnotation, PluginError}

/**
 * PluginLoader - 反射插件加载器
 *
 * 加载管线（design.md §2.2.2）：
 * ClassTypeInfo.get(全限定名) -> findAnnotation<PluginAnnotation>()
 * -> 注解/依赖校验 -> 无参构造 ConstructorInfo.apply -> as Plugin
 *
 * 反射实现参考（v2.3，均为 fountain 框架生产级先例）：
 * - ClassTypeInfo.get + try-catch 优雅降级：f_app/App.cj L133-137
 * - findAnnotation<BeanMeta> 读注解模式：f_bean/BeanFactory.cj L124
 *
 * v4.0 优化方案 3.8 修正：TypeInfos.get() 返回 TypeInfo（无 constructors 属性），
 * 而 PluginLoader 需要 typeInfo.constructors 遍历无参构造。故此文件保留
 * ClassTypeInfo.get()。TypeInfos.get() 的缓存优势仅在多次重复查找同一类型时
 * 有收益，而插件加载是一次性冷路径操作，缓存收益可忽略。
 *
 * 注意：ConstructorInfo.apply 返回 Any 且可能抛反射异常
 * （InfoNotFoundException/IllegalArgumentException/IllegalTypeException 等），
 * 统一 try/catch 包装并映射为 InstantiationFailed。
 */
public class PluginLoader {
    private let registry: PluginRegistry

    public init(registry: PluginRegistry) {
        this.registry = registry
    }

    /**
     * 按类全名反射发现并实例化插件（不触发 onLoad，由 PluginHostManager 驱动）
     *
     * 参数：
     *   - className: 插件类全限定名（如 "magic.plugins.memory.MemoryPostgresPlugin"）
     *   - context: 已构造的插件上下文（注解校验用其 pluginName）
     */
    public func load(className: String, context: PluginContext): Result<Plugin, PluginError> {
        // 1. 按全限定名解析类型（类型不存在抛异常，优雅降级为错误码）
        let typeInfo: ClassTypeInfo
        try {
            typeInfo = ClassTypeInfo.get(className)
        } catch (e: Exception) {
            return Err(PluginError.InstantiationFailed(
                "class not found: ${className} (${e.message})"))
        }

        // 2. 读取 @PluginAnnotation 注解声明
        let annotation = typeInfo.findAnnotation<PluginAnnotation>()
        match (annotation) {
            case None =>
                return Err(PluginError.AnnotationInvalid(
                    "class ${className} is not annotated with @PluginAnnotation"))
            case Some(anno) =>
                // 3. 注解 name 须与 plugins.yaml 的 name（即 context.pluginName）一致
                if (anno.name != context.pluginName) {
                    return Err(PluginError.AnnotationInvalid(
                        "annotation name '${anno.name}' != config name '${context.pluginName}'"))
                }
                // 4. 依赖校验（逗号拆分后逐个检查已注册）
                let dependencies = splitDependencies(anno.dependencies)
                if (!this.checkDependencies(dependencies)) {
                    return Err(PluginError.DependencyMissing(
                        "${anno.name} depends on [${anno.dependencies}]"))
                }
        }

        // 5. 查找 public 无参构造并实例化
        let instance: Any
        try {
            var invoked: Option<Any> = None
            for (constructor in typeInfo.constructors) {
                if (constructor.parameters.size == 0) {
                    invoked = Some(constructor.apply(Array<Any>()))
                    break
                }
            }
            match (invoked) {
                case Some(inst) => instance = inst
                case None =>
                    return Err(PluginError.InstantiationFailed(
                        "no public no-arg constructor: ${className}"))
            }
        } catch (e: Exception) {
            return Err(PluginError.InstantiationFailed(
                "constructor invoke failed: ${className} (${e.message})"))
        }

        // 6. 转换为 Plugin 接口（失败即非插件实现类）
        if (let plugin: Plugin <- instance) {
            return Ok(plugin)
        }
        return Err(PluginError.InstantiationFailed(
            "class ${className} does not implement Plugin"))
    }

    /**
     * 校验插件声明一致性（load 后、register 前复查）
     *
     * 同名冲突的幂等处理由 PluginRegistry.register 承担（同名返回已存在实例），
     * 此处仅做名称合法性检查
     */
    public func validate(plugin: Plugin): Result<Unit, PluginError> {
        let name = plugin.getName()
        if (name.isEmpty()) {
            return Err(PluginError.AnnotationInvalid("plugin name is empty"))
        }
        return Ok(())
    }

    /**
     * 校验依赖插件是否已全部注册
     */
    public func checkDependencies(dependencies: Array<String>): Bool {
        for (dep in dependencies) {
            if (this.registry.get(dep).isNone()) {
                LogUtils.error("[PluginLoader] dependency not registered: ${dep}")
                return false
            }
        }
        return true
    }

    /**
     * 逗号拆分依赖串（过滤空项与首尾空白）
     *
     * 空串返回空数组；"a, b" 返回 ["a", "b"]
     */
    private func splitDependencies(dependencies: String): Array<String> {
        let result = ArrayList<String>()
        if (dependencies.isEmpty()) {
            return result.toArray()
        }
        for (part in dependencies.split(",")) {
            let trimmed = part.trimAscii()
            if (!trimmed.isEmpty()) {
                result.add(trimmed)
            }
        }
        return result.toArray()
    }
}
