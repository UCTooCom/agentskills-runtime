/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.core.database

import std.sync.ReentrantMutex

/**
 * 全局数据库串行化锁。
 *
 * ## 为什么需要它
 *
 * 运行时里有多条互不相关的并发写路径：
 *   - `AsyncLogWriter` 后台线程批量写 `crontab_log`
 *   - `SchedulerEngine` 定时调度线程读写 `crontab`
 *   - `BillingEventHandler` / `AgentPersistenceEventHandler` 在请求线程上落库
 *   - `AgentExecutionExecutor` 加载 Agent 定义
 *
 * f_orm 的 `SqlExecutor` 虽然按线程持有连接（`ThreadLocal`），但底层
 * `NamedDatasource.connect()` 实际发下来的连接是被这些并发路径共用的：
 * 两条路径同时读写同一个 socket 就会抛
 * `Socket is already reading/writing: concurrent read is not allowed`，
 * 语句与绑定参数错位后又抛
 * `parameter index N out of range [0, N)` / `no value specified for parameter 1`。
 *
 * 此前在 `SchedulerEngine` 内部单独加的一把锁只保护了自己，挡不住
 * "本线程加锁、别的线程照样用同一条连接" 的情况，所以错误照旧。
 * 这里提供**进程级**的同一把锁，让所有 DB 访问路径都走它。
 *
 * ## 用法
 *
 *     DbSerialLock.lock()
 *     try {
 *         dao.xxx()
 *     } finally {
 *         DbSerialLock.unlock()
 *     }
 *
 * 用 `ReentrantMutex` 而不是 `Mutex`：同一线程内嵌套进入（例如事务里再查询）
 * 不会自锁。持锁区间应尽量短，不要在锁内做网络请求或耗时计算。
 */
public class DbSerialLock {
    private static let mtx = ReentrantMutex()

    public static func lock(): Unit {
        mtx.lock()
    }

    public static func unlock(): Unit {
        mtx.unlock()
    }

    /**
     * 在锁内执行一段 DB 访问，无论成功失败都保证解锁。
     *
     *     let result = DbSerialLock.withLock({ => dao.findById(id) })
     */
    public static func withLock<T>(action: () -> T): T {
        mtx.lock()
        try {
            let r = action()
            mtx.unlock()
            return r
        } catch (e: Exception) {
            mtx.unlock()
            throw e
        }
    }

}
