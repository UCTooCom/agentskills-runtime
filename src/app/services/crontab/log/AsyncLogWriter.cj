package magic.app.services.crontab.log

import std.sync.ReentrantMutex
import std.time.DateTime
import std.core.Duration
import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import magic.log.LogUtils
import magic.app.models.uctoo.CrontabLogPO
import magic.app.dao.uctoo.CrontabLogDAO
import magic.app.core.database.DbSerialLock

public class AsyncLogWriter {
    private var running = false
    private let queue = ArrayList<CrontabLogPO>()
    private let mutex = ReentrantMutex()
    private let batchSize = 100
    private var maxQueueSize = Int64(1000)
    private let dao: CrontabLogDAO

    public init(dao: CrontabLogDAO, maxQueueSize!: Int64 = 1000) {
        this.dao = dao
        this.maxQueueSize = maxQueueSize
    }

    public func start(): Unit {
        running = true
        spawn {
            consume()
        }
        LogUtils.info("AsyncLogWriter", "异步日志写入器启动, 队列容量: ${maxQueueSize}")
    }

    public func writeLog(log: CrontabLogPO): Unit {
        synchronized (mutex) {
            if (queue.size >= maxQueueSize) {
                if (queue.size > 0) {
                    queue.remove(at: 0)
                }
                LogUtils.error("AsyncLogWriter", "队列已满, 丢弃最早日志")
            }
            queue.add(log)
        }
    }

    /**
     * 批量落库（持全局 DB 锁）。
     *
     * 本写入器跑在独立线程上，与 SchedulerEngine、事件处理器共用同一条
     * ORM 连接；不加全局锁就会出现
     * `Socket is already reading/writing` 与 `parameter index N out of range`
     * 这类「两条路径同时操作一个 socket」的错误。
     */
    private func insertBatch(batch: ArrayList<CrontabLogPO>): Unit {
        DbSerialLock.lock()
        try {
            for (log in batch) {
                dao.insertCrontabLog(log)
            }
        } finally {
            DbSerialLock.unlock()
        }
    }

    private func consume(): Unit {
        while (running) {
            try {
                let batch = ArrayList<CrontabLogPO>()
                synchronized (mutex) {
                    var count = 0
                    while (count < batchSize && queue.size > 0) {
                        batch.add(queue.remove(at: 0))
                        count++
                    }
                }

                if (batch.size > 0) {
                    try {
                        insertBatch(batch)
                    } catch (e: Exception) {
                        LogUtils.error("AsyncLogWriter", "批量写入失败, 重试一次: ${e.message}")
                        // 失败多半是连接被别的线程占用后状态错乱，等一下再重试
                        sleep(Duration.millisecond * 50)
                        try {
                            insertBatch(batch)
                        } catch (e2: Exception) {
                            LogUtils.error("AsyncLogWriter", "重试写入仍失败: ${e2.message}")
                        }
                    }
                }

                if (batch.size == 0) {
                    sleep(Duration.millisecond * 100)
                }
            } catch (e: Exception) {
                LogUtils.error("AsyncLogWriter", "消费循环异常: ${e.message}")
            }
        }

        flushRemaining()
    }

    private func flushRemaining(): Unit {
        synchronized (mutex) {
            if (queue.size > 0) {
                try {
                    insertBatch(queue)
                    LogUtils.info("AsyncLogWriter", "关闭前刷新${queue.size}条剩余日志")
                } catch (e: Exception) {
                    LogUtils.error("AsyncLogWriter", "刷新剩余日志失败: ${e.message}")
                }
                queue.clear()
            }
        }
    }

    public func close(timeout!: Duration = Duration.second * 10): Unit {
        running = false
        LogUtils.info("AsyncLogWriter", "异步日志写入器关闭")
    }
}
