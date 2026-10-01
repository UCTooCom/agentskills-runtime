/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.bridge

import magic.log.LogUtils

// ─────────────────────────────────────────────────────────────
// SDD 编排的调度注册出口（依赖倒置）
//
// 为什么不能直接 import：
//   `SddOrchestrationExecutor` 落在 magic.app.services.crontab.executor，
//   它要调本包的 SddOrchestrationService，已存在 crontab.executor -> bridge 这条边；
//   而编排跑完/失败后需要通知调度引擎（注册 / 摘除 crontab 行），若直接 import
//   magic.app.services.crontab 就会形成
//     crontab -> crontab.executor -> bridge -> crontab
//   的包级循环依赖，cjpm 直接拒绝构建。
//
// 解法与 LrtScheduleBridge 完全一致（工程内既有范式）：本包只声明函数槽，
// 由**组合根**（src/app/main.cj，在 SchedulerEngine.initialize 之后）注入实现。
//
// 未注入时的行为：只告警并返回 false，不抛异常 —— 调度注册是增强能力，
// 不能因为组合根改动而让编排失败。
// ─────────────────────────────────────────────────────────────
public class SddScheduleBridge {
    /// 由组合根注入：(crontabId) -> Unit —— 把某条 crontab 注册进运行中的调度引擎
    private static var _reloadCrontab: Option<(String) -> Unit> = None

    /// 由组合根注入：(crontabId) -> Unit —— 把某条 crontab 从运行中的调度引擎摘除
    private static var _stopCrontab: Option<(String) -> Unit> = None

    public static func setCrontabReloader(f: (String) -> Unit): Unit {
        SddScheduleBridge._reloadCrontab = f
    }

    public static func setCrontabStopper(f: (String) -> Unit): Unit {
        SddScheduleBridge._stopCrontab = f
    }

    /// 通知调度引擎加载（或重载）指定 crontab 行。
    /// 返回：true = 已交给引擎；false = 组合根未注入或引擎未就绪。
    public static func reloadCrontab(crontabId: String): Bool {
        match (SddScheduleBridge._reloadCrontab) {
            case Some(f) =>
                try {
                    f(crontabId)
                    return true
                } catch (e: Exception) {
                    LogUtils.warn(
                        "[SddScheduleBridge] 调度注册回调抛异常: crontabId=${crontabId}, error=${e.message}"
                    )
                    return false
                }
            case None =>
                LogUtils.warn(
                    "[SddScheduleBridge] 组合根未注入调度注册出口，本进程内该调度不会被周期触发: crontabId=${crontabId}"
                )
                return false
        }
    }

    /// 从调度引擎摘除指定 crontab 行（六步跑完 / 某步失败 / 单步模式执行完毕）。
    /// 未注入只告警不抛异常：停表是收敛动作，不该让调用方（执行器）失败。
    public static func stopCrontab(crontabId: String): Bool {
        match (SddScheduleBridge._stopCrontab) {
            case Some(f) =>
                try {
                    f(crontabId)
                    return true
                } catch (e: Exception) {
                    LogUtils.warn(
                        "[SddScheduleBridge] 调度摘除回调抛异常: crontabId=${crontabId}, error=${e.message}"
                    )
                    return false
                }
            case None =>
                LogUtils.warn(
                    "[SddScheduleBridge] 组合根未注入调度摘除出口，该调度在本进程内仍会继续触发: crontabId=${crontabId}"
                )
                return false
        }
    }
}
