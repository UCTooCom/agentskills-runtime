/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.crontab.executor

import magic.log.LogUtils
import magic.app.services.crontab.model.{CrontabExecutionContext, ExecutionResult}
import magic.skill.{SkillCuratorHandler, CuratorRuleSet, CuratorReport}
import std.time.DateTime
import std.collection.ArrayList

public class SkillCuratorExecutor <: CrontabExecutor {
    public prop scheme: String {
        get() { "skill-curator" }
    }

    private var _handler: Option<SkillCuratorHandler>

    public init() {
        _handler = None<SkillCuratorHandler>
    }

    public func setHandler(handler: SkillCuratorHandler): Unit {
        _handler = Some(handler)
    }

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let startTime = DateTime.now()

        LogUtils.info("SkillCuratorExecutor", "开始执行Curator审查: taskName=${context.taskName}")

        try {
            if (let Some(h) <- _handler) {
                let report = h.execute()
                let durationMs = (DateTime.now() - startTime).toMilliseconds()

                LogUtils.info("SkillCuratorExecutor", "Curator审查完成: scanned=${report.totalScanned}, transitions=${report.stateTransitions.size}, duration=${durationMs}ms")

                ExecutionResult.successResult(report.toJsonValue().toString(), durationMs, "Curator审查完成")
            } else {
                let durationMs = (DateTime.now() - startTime).toMilliseconds()
                LogUtils.error("SkillCuratorExecutor", "Curator handler not configured")
                ExecutionResult.failureResult("Curator handler not configured", durationMs, -1)
            }
        } catch (ex: Exception) {
            let durationMs = (DateTime.now() - startTime).toMilliseconds()
            LogUtils.error("SkillCuratorExecutor", "Curator执行失败: ${ex.message}")
            ExecutionResult.failureResult(ex.message, durationMs, -1)
        }
    }

    public func validate(taskUri: String): Bool {
        let lower = taskUri.toAsciiLower()
        if (!lower.startsWith("skill-curator://")) {
            return false
        }
        let path = taskUri[16..]
        path.size > 0
    }
}
