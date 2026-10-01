/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.tools

import magic.core.AgentSessionContext
import magic.core.tool.Tool
import magic.core.LongRunningTaskToolFactory

/**
 * LongRunningTaskToolFactory 的 magic.app 侧具体实现。
 *
 * 由 WebMCPProtocol 在构造 SkillAwareAgent 时注入；它持有对 magic.app 内
 * LongRunningTaskTool 的引用，从而把"底层包不直接依赖 magic.app"的约束在 magic.app 这一层收口。
 */
public class LrtToolFactory <: LongRunningTaskToolFactory {
    public init() {}

    public func create(sessionContext: AgentSessionContext): Tool {
        return LongRunningTaskTool(sessionContext: sessionContext)
    }
}
