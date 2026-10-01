/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.core

import magic.core.tool.Tool

/**
 * 长程任务工具的工厂接口（放在 magic.core，避免 magic.skill / magic.tool 反向依赖 magic.app）。
 *
 * 为什么需要它：long-running-task 的真实实现（LongRunningTaskTool）位于 magic.app（它要调用
 * magic.app.services.lrt.LongTaskApiService）。而 magic.app 已经依赖 magic.skill / magic.tool，
 * 若这两个底层包直接引用 magic.app 中的类，会形成包循环依赖、无法编译。
 *
 * 因此由 magic.app 侧的调用方（WebMCPProtocol）提供本工厂的具体实现，magic.skill 只依赖这个
 * 位于 magic.core 的接口，从而切断循环依赖。
 */
public interface LongRunningTaskToolFactory {
    func create(sessionContext: AgentSessionContext): Tool
}
