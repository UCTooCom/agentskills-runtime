package ystyle::cordis_core

import std.deriving.*

/**
 * 插件运行时状态（docs/design-impl.md §2.2）
 */
@Derive[Equatable, ToString]
public enum InstanceStatus {
    | Starting       // 已 launch，等待 initialize 握手
    | Pending        // initialize 依赖缺失，保持等待重试（对齐 Cordis PENDING）
    | Active         // 握手完成，服务已注册
    | Unloading      // dispose 流程中
    | Failed         // 启动失败/崩溃
    | Unreachable    // ping 超时
}
