/**
 * L3 进程隔离轨集成冒烟（PS-T024 子任务4）
 *
 * 目的：验证 cordis_host 依赖可解析、类型可引用（不启用运行时集成）。
 * 运行时集成见 CordisHostManager（PS-T025）。
 *
 * 用 HostState 而非 PluginHostManager：magic.plugin 已有同名的 PluginHostManager
 * （L1 轨宿主侧），裸名 PluginHostManager 会被同包遮蔽解析到宿主侧 6 参构造器，
 * 故改用 cordis_host 独有的 HostState 类型做引用冒烟，避免同名冲突。
 *
 * 设计依据：spec.md REQ-PS-015 / design.md §5.2.1 / tasks.md PS-T024
 */
package magic.plugin

import ystyle::cordis_host.HostState

internal func cordisHostSmoke(): ?HostState {
    None
}
