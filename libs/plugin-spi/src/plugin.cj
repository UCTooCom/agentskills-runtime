/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package plugin_spi

/**
 * 插件 SPI 接口 —— 所有插件的实现契约
 *
 * 插件 = Service（确定性能力）+ Skill（AI 行为，可选）+ 数据资产（同目录）
 *
 * PS-T017：自 magic.plugin 包迁入本 SPI 包（阶段三硬前置，design.md §2.7
 * 方案二——插件独立包化/动态库插件编译期只允许依赖本包，不得 import 宿主
 * magic 包）。
 *
 * 生命周期调用顺序：
 *   onLoad(context) -> onActivate() -> [运行期] -> onDeactivate() -> onUnload()
 *
 * 钩子异常约定（design.md §2.1.4 触发条件表）：
 * - onLoad/onActivate 抛异常：插件进入 Error 态（可修复后重试）
 * - onDeactivate/onUnload 抛异常：捕获记日志，清理栈仍逆序执行完毕
 * - 事件回调/Service 调用异常：不触发状态迁移
 */
public interface Plugin {
    /// 插件唯一名（须与 @PluginAnnotation.name 及 plugins.yaml 的 name 一致）
    func getName(): String

    /// 加载期：注入 PluginContext（容器句柄、配置参数）
    /// 此阶段可调用 context.registerService 注册服务、context.eventBus 订阅事件
    func onLoad(context: PluginContext): Unit

    /// 激活期：插件对外可用（服务开始对外提供）
    func onActivate(): Unit

    /// 停用期：停止对外提供服务（订阅仍在，等待重新激活或卸载）
    func onDeactivate(): Unit

    /// 卸载期：释放全部资源（onCleanup 清理栈由框架逆序执行）
    func onUnload(): Unit
}
