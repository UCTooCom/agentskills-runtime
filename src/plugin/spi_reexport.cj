/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin

/**
 * plugin-spi 转发层（PS-T017）
 *
 * 插件契约自本包迁入 libs/plugin-spi（包名 plugin_spi）：Plugin 接口/
 * 注解/PluginContext/ServiceRegistry/PluginEventBus/类型枚举等。
 *
 * 经 public import 转发，存量 `import magic.plugin.{Plugin, ...}` 的
 * 使用方（框架内部、三个 L1 插件、集成测试、plugingen 生成代码）全部
 * 零改动；阶段三插件独立包化后，插件包将直接 import plugin_spi。
 */
public import plugin_spi.{
    Plugin,
    PluginState,
    PluginError,
    RegistrySnapshot,
    LoadResult,
    PluginAnnotation,
    ModuleRouteAnnotation,
    PluginRoute,
    PluginContext,
    PluginSkillBridge,
    ServiceRegistry,
    PluginEventBus,
    PluginSpiLogger
}
