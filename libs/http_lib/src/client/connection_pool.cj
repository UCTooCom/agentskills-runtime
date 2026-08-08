package http_lib.client
import std.overflow.*
/**
 * HTTP 连接池。
 * 按主机分组管理空闲连接，支持最大连接数和空闲超时淘汰。
 * 减少频繁建立 TCP/TLS 连接的开销。
 */

import std.collection.{ArrayList, HashMap}
import std.sync.Mutex
import std.time.DateTime
import http_lib.connection.Connection

/**
 * 跟踪元数据以供复用的池化连接封装。
 */
class PooledConnection {
    public let connection: Connection
    public var lastUsed: DateTime
    public var host: String
    public var port: UInt16
    public var isSecure: Bool

    public init(connection: Connection, host: String, port: UInt16, isSecure: Bool) {
        this.connection = connection
        this.host = host
        this.port = port
        this.isSecure = isSecure
        this.lastUsed = DateTime.now()
    }

    public func touch(): Unit {
        lastUsed = DateTime.now()
    }
}

/**
 * HTTP 连接池 for 连接复用 (Keep-Alive).
 *
 * 使用锁条带化按 "host:port:isSecure" 键池化连接
 * （16 个互斥锁分片）以减少高并发下的争用。
 * 每个分片保护池中由池键哈希键控的子集。
 */
public class ConnectionPool {
    private var pool: HashMap<String, ArrayList<PooledConnection>>
    // 锁条带化：16 个互斥锁分片，通过池键的哈希索引
    private var poolMutexes: Array<Mutex>
    private static let MUTEX_SHARDS: Int64 = 16
    private var maxPerHost: Int64
    private var idleTimeout: Duration
    private var running: Bool = false

    public init(maxPerHost!: Int64 = 5, idleTimeout!: Duration = Duration.second * 60) {
        this.pool = HashMap<String, ArrayList<PooledConnection>>()
        this.poolMutexes = Array<Mutex>(MUTEX_SHARDS, repeat: Mutex())
        var i: Int64 = 0
        while (i < MUTEX_SHARDS) {
            this.poolMutexes[i] = Mutex()
            i += 1
        }
        this.maxPerHost = maxPerHost
        this.idleTimeout = idleTimeout
    }

    /**
     * 从连接参数构建池键。
     */
    private static func poolKey(host: String, port: UInt16, isSecure: Bool): String {
        "${host}:${port}:${isSecure}"
    }

    /**
     * 使用基于哈希的条带化获取给定池键的互斥锁分片。
     */
    private func shardMutex(key: String): Mutex {
        var hash: Int64 = 0
        let bytes = unsafe { key.rawData() }
        for (b in bytes) { hash = hash.wrappingMul(31).wrappingAdd(Int64(b)) }
        let idx = if (hash < 0) { (hash & 0x7fffffffffffffff) % MUTEX_SHARDS } else { hash % MUTEX_SHARDS }
        poolMutexes[idx]
    }

    /**
     * 锁定所有互斥锁分片。用于批量操作（closeAll、closeIdle、size）。
     */
    private func lockAll(): Unit {
        for (m in poolMutexes) { m.lock() }
    }

    private func unlockAll(): Unit {
        for (m in poolMutexes) { m.unlock() }
    }

    /**
     * 从池中借用可复用的连接。
     * 如果没有空闲连接可用则返回 None。
     */
    public func borrow(host: String, port: UInt16, isSecure: Bool): ?Connection {
        let key = poolKey(host, port, isSecure)
        var result: ?Connection = None
        let mu = shardMutex(key)
        synchronized(mu) {
            result = borrowInternal(key)
        }
        result
    }

    private func borrowInternal(key: String): ?Connection {
        match (pool.get(key)) {
            case Some(conns) =>
                let now = DateTime.now()
                while (conns.size > 0) {
                    let lastIdx = conns.size - 1
                    let pooled = conns[lastIdx]
                    conns.remove(lastIdx..lastIdx + 1)
                    if (now - pooled.lastUsed > idleTimeout || !pooled.connection.canReuseTransport() || !pooled.connection.isConnected()) {
                        try { pooled.connection.close() } catch (_: Exception) {}
                        continue
                    }
                    pooled.touch()
                    return Some(pooled.connection)
                }
                if (conns.size == 0) {
                    pool.remove(key)
                }
                None
            case None => None
        }
    }

    /**
     * 将连接释放回池中。
     */
    public func release(host: String, port: UInt16, isSecure: Bool, connection: Connection, reusable: Bool): Unit {
        if (!reusable) {
            try { connection.close() } catch (_: Exception) {}
            return
        }
        var connToClose: ?Connection = None
        let key = poolKey(host, port, isSecure)
        let mu = shardMutex(key)
        synchronized(mu) {
            match (pool.get(key)) {
                case Some(conns) =>
                    if (conns.size >= maxPerHost) {
                        connToClose = Some(connection)
                    } else {
                        let pooled = PooledConnection(connection, host, port, isSecure)
                        conns.add(pooled)
                    }
                case None =>
                    let conns = ArrayList<PooledConnection>()
                    let pooled = PooledConnection(connection, host, port, isSecure)
                    conns.add(pooled)
                    pool[key] = conns
            }
        }
        match (connToClose) {
            case Some(c) => try { c.close() } catch (_: Exception) {}
            case None => ()
        }
    }

    /**
     * 移除并关闭所有分片中的所有空闲连接。
     */
    public func closeIdle(): Unit {
        let toClose = ArrayList<PooledConnection>()
        lockAll()
        let now = DateTime.now()
        let emptyKeys = ArrayList<String>()
        for ((key, conns) in pool) {
            var i = conns.size - 1
            while (i >= 0) {
                let pooled = conns[i]
                if (now - pooled.lastUsed > idleTimeout || !pooled.connection.canReuseTransport()) {
                    toClose.add(pooled)
                    conns.remove(i..i + 1)
                }
                i -= 1
            }
            if (conns.size == 0) {
                emptyKeys.add(key)
            }
        }
        for (key in emptyKeys) {
            pool.remove(key)
        }
        unlockAll()
        for (pooled in toClose) {
            try { pooled.connection.close() } catch (_: Exception) {}
        }
    }

    /**
     * 关闭所有连接并清空池。
     */
    public func closeAll(): Unit {
        lockAll()
        for ((_, conns) in pool) {
            for (pooled in conns) {
                try { pooled.connection.close() } catch (_: Exception) {}
            }
        }
        pool.clear()
        unlockAll()
    }

    /**
     * 从池中移除所有条目（不关闭连接）。
     */
    public func clear(): Unit {
        lockAll()
        pool.clear()
        unlockAll()
    }

    /**
     * 获取所有分片中的当前池化连接数。
     */
    public func size(): Int64 {
        lockAll()
        var count: Int64 = 0
        for ((_, conns) in pool) {
            count += conns.size
        }
        unlockAll()
        count
    }

    /**
     * 启动空闲连接的后台淘汰。
     */
    public func startBackgroundEviction(interval!: ?Duration = None): Unit {
        let evictInterval = match (interval) {
            case Some(iv) => iv
            case None => Duration.second * 30
        }
        running = true
        spawn {
            while (running) {
                try { sleep(evictInterval) } catch (_: Exception) { break }
                if (!running) { break }
                closeIdle()
            }
        }
    }

    /**
     * 停止后台淘汰线程。
     */
    public func stopBackgroundEviction(): Unit {
        running = false
    }
}
