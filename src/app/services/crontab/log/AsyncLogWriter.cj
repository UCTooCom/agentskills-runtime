package magic.app.services.crontab.log

import std.sync.ReentrantMutex
import std.time.DateTime
import std.core.Duration
import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import magic.log.LogUtils
import magic.app.models.uctoo.CrontabLogPO
import magic.app.dao.uctoo.CrontabLogDAO

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
                        for (log in batch) {
                            dao.insertCrontabLog(log)
                        }
                    } catch (e: Exception) {
                        LogUtils.error("AsyncLogWriter", "批量写入失败, 重试一次: ${e.message}")
                        try {
                            for (log in batch) {
                                dao.insertCrontabLog(log)
                            }
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
                    for (log in queue) {
                        dao.insertCrontabLog(log)
                    }
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
