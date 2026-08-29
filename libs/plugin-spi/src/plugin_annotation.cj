/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package plugin_spi

import std.reflect.Annotation

/**
 * PluginAnnotation - 插件声明注解
 *
 * 用于标记插件实现类，PluginLoader 通过反射读取该注解完成发现与校验。
 *
 * 使用示例：
 * ```cangjie
 * @PluginAnnotation[
 *     name: "memory-postgres",
 *     version: "1.0.0",
 *     dependencies: "core-db,tool-http"
 * ]
 * public class MemoryPostgresPlugin <: Plugin {
 *     // ...
 * }
 * ```
 *
 * 语言约束说明：
 * - 注解类须提供 const init 构造器，字段必须为 let（不可变）
 * - const 表达式不支持 Array<String> 注解参数（官方文档：const 的 Array
 *   字面量不能是 Array 类型，仅 VArray 可用，而 VArray 定长不适用），
 *   故 dependencies 用逗号分隔 String 承载，加载时按逗号拆分
 */
@Annotation
public class PluginAnnotation {
    /// 插件唯一名（须与 plugins.yaml 的 name 一致）
    public let name: String

    /// 插件版本号
    public let version: String

    /// 依赖插件名列表（逗号分隔，如 "core-db,tool-http"；无依赖传空串）
    public let dependencies: String

    public const init(
        name!: String,
        version!: String,
        dependencies!: String
    ) {
        this.name = name
        this.version = version
        this.dependencies = dependencies
    }
}
