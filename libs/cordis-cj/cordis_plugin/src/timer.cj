package ystyle::cordis_plugin

import std.sync.{Timer, Mutex}
import std.time.MonoTime

/**
 * 可撤销定时器工具（docs/cordis-comparison.md §4 timer，对齐 Cordis `ctx.timeout/interval`）
 *
 * 基于 std.sync.Timer 实现：
 * - timeout：一次性定时（Timer.once）
 * - interval：周期定时（Timer.repeat）
 * - throttle：节流（最小执行间隔内合并调用）
 * - debounce：防抖（静默后执行最后一次）
 *
 * 所有定时器返回撤销函数：调用后不再触发（timer.cancel()）。
 */
public class PluginTimers {

    /**
     * 一次性定时（对齐 Cordis ctx.timeout）
     * @param delayMs 延迟（毫秒）
     * @param callback 到期回调
     * @return 撤销函数（调用后不再触发）
     */
    public func timeout(delayMs: Int64, callback: () -> Unit): () -> Unit {
        let timer = Timer.once(delayMs * Duration.millisecond, callback)
        { => timer.cancel() }
    }

    /**
     * 周期定时（对齐 Cordis ctx.interval）
     * @param periodMs 周期（毫秒）
     * @param callback 每次到期回调
     * @return 撤销函数（调用后停止周期触发）
     */
    public func interval(periodMs: Int64, callback: () -> Unit): () -> Unit {
        let timer = Timer.repeat(Duration.Zero, periodMs * Duration.millisecond, callback)
        { => timer.cancel() }
    }

    /**
     * 节流（对齐 Cordis ctx.throttle）：最小执行间隔内合并调用
     * @param intervalMs 最小执行间隔（毫秒）
     * @param callback 回调
     * @return 触发函数（调用于需要节流的调用点）
     */
    public func throttle(intervalMs: Int64, callback: () -> Unit): () -> Unit {
        let state = ThrottleState(intervalMs, callback)
        { => state.invoke() }
    }

    /**
     * 防抖（对齐 Cordis ctx.debounce）：停止调用 intervalMs 后执行一次
     * @param intervalMs 静默间隔（毫秒）
     * @param callback 回调
     * @return 触发函数（连续调用只执行最后一次）
     */
    public func debounce(intervalMs: Int64, callback: () -> Unit): () -> Unit {
        let state = DebounceState(intervalMs, callback)
        { => state.invoke() }
    }
}

/**
 * 节流状态：锁内记录上次执行时间，间隔内合并；首次调用立即执行
 */
internal class ThrottleState {
    private let intervalMs: Int64
    private let callback: () -> Unit
    private let lock: Mutex = Mutex()
    private var lastRun: ?MonoTime = None

    init(intervalMs: Int64, callback: () -> Unit) {
        this.intervalMs = intervalMs
        this.callback = callback
    }

    func invoke(): Unit {
        synchronized(this.lock) {
            let now = MonoTime.now()
            let allowed = match (this.lastRun) {
                case None => true                       // 首次：立即执行
                case Some(t) => now - t >= this.intervalMs * Duration.millisecond
            }
            if (allowed) {
                this.lastRun = Some(now)
                this.callback()
            }
        }
    }
}

/**
 * 防抖状态：每次调用取消旧 Timer 并新建（静默 intervalMs 后执行）
 */
internal class DebounceState {
    private let intervalMs: Int64
    private let callback: () -> Unit
    private let lock: Mutex = Mutex()
    private var timer: ?Timer = None

    init(intervalMs: Int64, callback: () -> Unit) {
        this.intervalMs = intervalMs
        this.callback = callback
    }

    func invoke(): Unit {
        synchronized(this.lock) {
            match (this.timer) {
                case Some(t) => t.cancel()
                case None => ()
            }
            this.timer = Some(Timer.once(this.intervalMs * Duration.millisecond, this.callback))
        }
    }
}
