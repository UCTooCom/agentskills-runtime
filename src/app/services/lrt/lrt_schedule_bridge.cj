package magic.app.services.lrt

import magic.log.LogUtils

// ─────────────────────────────────────────────────────────────
// 调度注册出口（依赖倒置）
//
// 为什么需要一个"出口"而不是直接 import：
//   magic.app.services.crontab.executor 里的 LrtPluginExecutor 要驱动本包的
//   LrtHostExecutor / LrtPluginClient，已存在 crontab.executor -> lrt 这条边；
//   而 lrt 在新建 crontab 行之后需要通知调度引擎（SchedulerEngine.reloadTask），
//   若直接 import magic.app.services.crontab 就会形成
//     crontab -> crontab.executor -> lrt -> crontab
//   的包级循环依赖，cjpm 直接拒绝构建。
//
// 解法与工程内既有范式一致（LogUtils.setWatermarkAlerter，见 log_utils_impl.cj:49）：
//   本包只声明一个函数槽，由**组合根**（app/main.cj，在 SchedulerEngine.initialize 之后）
//   注入真正的实现。lrt 因此不再反向依赖 crontab。
//
// 未注入时的行为：只告警并返回 false，不抛异常 —— 调度注册是增强能力，
// 不能因为组合根改动而让任务提交失败。
// ─────────────────────────────────────────────────────────────
public class LrtScheduleBridge {
    /// 由组合根注入：(crontabId) -> Unit
    private static var _reloadCrontab: Option<(String) -> Unit> = None

    /// 由组合根注入：(crontabId) -> Unit
    /// 【取消自动续跑 · 2026-09-23】把一个 crontab 行从运行中的调度引擎里摘除。
    /// 与 reloadCrontab 同一套依赖倒置机制（lrt 不反向 import crontab）。
    private static var _stopCrontab: Option<(String) -> Unit> = None

    /// 注入"把某条 crontab 注册进运行中的调度引擎"的实现。
    /// 由 app/main.cj 在 SchedulerEngine.initialize 成功后调用一次。
    public static func setCrontabReloader(f: (String) -> Unit): Unit {
        LrtScheduleBridge._reloadCrontab = f
    }

    /// 通知调度引擎加载（或重载）指定 crontab 行。
    /// 返回：true = 已交给引擎；false = 组合根未注入或引擎未就绪。
    public static func reloadCrontab(crontabId: String): Bool {
        match (LrtScheduleBridge._reloadCrontab) {
            case Some(f) =>
                try {
                    f(crontabId)
                    return true
                } catch (e: Exception) {
                    LogUtils.warn(
                        "[LrtScheduleBridge] 调度注册回调抛异常: crontabId=${crontabId}, error=${e.message}"
                    )
                    return false
                }
            case None =>
                LogUtils.warn(
                    "[LrtScheduleBridge] 组合根未注入调度注册出口，本进程内该调度不会被周期触发: crontabId=${crontabId}"
                )
                return false
        }
    }

    /// 注入"把某条 crontab 从运行中的调度引擎里摘除"的实现。
    /// 由 app/main.cj 在 SchedulerEngine.initialize 成功后调用一次。
    public static func setCrontabStopper(f: (String) -> Unit): Unit {
        LrtScheduleBridge._stopCrontab = f
    }

    /// 从调度引擎摘除指定 crontab 行（用于停用 LRT 的自动续跑调度行）。
    /// 返回：true = 已交给引擎；false = 组合根未注入。
    /// 未注入只告警不抛异常：停表是收敛动作，不该让调用方（执行器）失败。
    public static func stopCrontab(crontabId: String): Bool {
        match (LrtScheduleBridge._stopCrontab) {
            case Some(f) =>
                try {
                    f(crontabId)
                    return true
                } catch (e: Exception) {
                    LogUtils.warn(
                        "[LrtScheduleBridge] 调度摘除回调抛异常: crontabId=${crontabId}, error=${e.message}"
                    )
                    return false
                }
            case None =>
                LogUtils.warn(
                    "[LrtScheduleBridge] 组合根未注入调度摘除出口，该调度在本进程内仍会继续触发: crontabId=${crontabId}"
                )
                return false
        }
    }
}
