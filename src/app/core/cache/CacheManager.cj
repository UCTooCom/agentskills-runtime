package magic.app.core.cache

import std.time.DateTime
import std.collection.HashMap
import std.collection.HashSet
import std.sync.ReentrantMutex
import std.convert.*

public class CacheConfig {
    public var host: String = "127.0.0.1"
    public var port: Int32 = 6379
    public var password: String = ""
    public var database: Int32 = 0
    public var connectionTimeout: Int64 = 30000
    public var readTimeout: Int64 = 60000
    public var writeTimeout: Int64 = 30000
    public var maxConnections: Int32 = 10
    public var defaultTTL: Int64 = 3600
    
    public init() {}
    
    public init(
        host: String,
        port: Int32,
        password: String,
        database: Int32,
        connectionTimeout: Int64,
        readTimeout: Int64,
        writeTimeout: Int64,
        maxConnections: Int32,
        defaultTTL: Int64
    ) {
        this.host = host
        this.port = port
        this.password = password
        this.database = database
        this.connectionTimeout = connectionTimeout
        this.readTimeout = readTimeout
        this.writeTimeout = writeTimeout
        this.maxConnections = maxConnections
        this.defaultTTL = defaultTTL
    }
    
    public static func fromEnv(): CacheConfig {
        let config = CacheConfig()
        config.host = getEnv("REDIS_HOST") ?? "127.0.0.1"
        config.port = Int32.parse(getEnv("REDIS_PORT") ?? "6379")
        config.password = getEnv("REDIS_PASSWORD") ?? ""
        config.database = Int32.parse(getEnv("REDIS_DATABASE") ?? "0")
        config.defaultTTL = Int64.parse(getEnv("REDIS_DEFAULT_TTL") ?? "3600")
        return config
    }
    
    private static func getEnv(key: String): ?String {
        return None<String>
    }
}

public interface CacheClient {
    func get(key: String): ?String
    func set(key: String, value: String): Bool
    func set(key: String, value: String, ttl: Int64): Bool
    func delete(key: String): Bool
    func exists(key: String): Bool
    func expire(key: String, ttl: Int64): Bool
    func ttl(key: String): Int64
    func incr(key: String): Int64
    func decr(key: String): Int64
    func hget(key: String, field: String): ?String
    func hset(key: String, field: String, value: String): Bool
    func hdel(key: String, field: String): Bool
    func hgetall(key: String): HashMap<String, String>
    func lpush(key: String, value: String): Int64
    func rpush(key: String, value: String): Int64
    func lpop(key: String): ?String
    func rpop(key: String): ?String
    func llen(key: String): Int64
    func sadd(key: String, member: String): Int64
    func srem(key: String, member: String): Int64
    func smembers(key: String): HashSet<String>
    func publish(channel: String, message: String): Bool
    func close(): Unit
}

public class RedisCacheClient <: CacheClient {
    private var config: CacheConfig
    private var connected: Bool = false
    private let mutex = ReentrantMutex()
    
    public init(config: CacheConfig) {
        this.config = config
    }
    
    public func connect(): Bool {
        synchronized(mutex) {
            connected = true
            return true
        }
    }
    
    public func get(key: String): ?String {
        synchronized(mutex) {
            if (!connected) {
                return None<String>
            }
            return None<String>
        }
    }
    
    public func set(key: String, value: String): Bool {
        return set(key, value, config.defaultTTL)
    }
    
    public func set(key: String, value: String, ttl: Int64): Bool {
        synchronized(mutex) {
            if (!connected) {
                return false
            }
            return true
        }
    }
    
    public func delete(key: String): Bool {
        synchronized(mutex) {
            if (!connected) {
                return false
            }
            return true
        }
    }
    
    public func exists(key: String): Bool {
        synchronized(mutex) {
            if (!connected) {
                return false
            }
            return false
        }
    }
    
    public func expire(key: String, ttl: Int64): Bool {
        synchronized(mutex) {
            if (!connected) {
                return false
            }
            return true
        }
    }
    
    public func ttl(key: String): Int64 {
        synchronized(mutex) {
            if (!connected) {
                return -1
            }
            return -1
        }
    }
    
    public func incr(key: String): Int64 {
        synchronized(mutex) {
            if (!connected) {
                return 0
            }
            return 0
        }
    }
    
    public func decr(key: String): Int64 {
        synchronized(mutex) {
            if (!connected) {
                return 0
            }
            return 0
        }
    }
    
    public func hget(key: String, field: String): ?String {
        synchronized(mutex) {
            if (!connected) {
                return None<String>
            }
            return None<String>
        }
    }
    
    public func hset(key: String, field: String, value: String): Bool {
        synchronized(mutex) {
            if (!connected) {
                return false
            }
            return true
        }
    }
    
    public func hdel(key: String, field: String): Bool {
        synchronized(mutex) {
            if (!connected) {
                return false
            }
            return true
        }
    }
    
    public func hgetall(key: String): HashMap<String, String> {
        synchronized(mutex) {
            if (!connected) {
                return HashMap<String, String>()
            }
            return HashMap<String, String>()
        }
    }
    
    public func lpush(key: String, value: String): Int64 {
        synchronized(mutex) {
            if (!connected) {
                return 0
            }
            return 0
        }
    }
    
    public func rpush(key: String, value: String): Int64 {
        synchronized(mutex) {
            if (!connected) {
                return 0
            }
            return 0
        }
    }
    
    public func lpop(key: String): ?String {
        synchronized(mutex) {
            if (!connected) {
                return None<String>
            }
            return None<String>
        }
    }
    
    public func rpop(key: String): ?String {
        synchronized(mutex) {
            if (!connected) {
                return None<String>
            }
            return None<String>
        }
    }
    
    public func llen(key: String): Int64 {
        synchronized(mutex) {
            if (!connected) {
                return 0
            }
            return 0
        }
    }
    
    public func sadd(key: String, member: String): Int64 {
        synchronized(mutex) {
            if (!connected) {
                return 0
            }
            return 0
        }
    }
    
    public func srem(key: String, member: String): Int64 {
        synchronized(mutex) {
            if (!connected) {
                return 0
            }
            return 0
        }
    }
    
    public func smembers(key: String): HashSet<String> {
        synchronized(mutex) {
            if (!connected) {
                return HashSet<String>()
            }
            return HashSet<String>()
        }
    }
    
    public func publish(channel: String, message: String): Bool {
        synchronized(mutex) {
            if (!connected) {
                return false
            }
            return true
        }
    }
    
    public func close(): Unit {
        synchronized(mutex) {
            connected = false
        }
    }
}

public class MemoryCacheClient <: CacheClient {
    private var cache: HashMap<String, CacheEntry> = HashMap<String, CacheEntry>()
    private let mutex = ReentrantMutex()
    
    public init() {}
    
    public func get(key: String): ?String {
        synchronized(mutex) {
            if (let Some(entry) <- cache.get(key)) {
                if (entry.isExpired()) {
                    cache.remove(key)
                    return None<String>
                }
                return entry.value
            }
            return None<String>
        }
    }
    
    public func set(key: String, value: String): Bool {
        synchronized(mutex) {
            cache[key] = CacheEntry(value, 0)
            return true
        }
    }
    
    public func set(key: String, value: String, ttl: Int64): Bool {
        synchronized(mutex) {
            let expireAt = DateTime.now().toUnixTimeStamp().toSeconds() + ttl
            cache[key] = CacheEntry(value, expireAt)
            return true
        }
    }
    
    public func delete(key: String): Bool {
        synchronized(mutex) {
            cache.remove(key)
            return true
        }
    }
    
    public func exists(key: String): Bool {
        synchronized(mutex) {
            if (let Some(entry) <- cache.get(key)) {
                if (entry.isExpired()) {
                    cache.remove(key)
                    return false
                }
                return true
            }
            return false
        }
    }
    
    public func expire(key: String, ttl: Int64): Bool {
        synchronized(mutex) {
            if (let Some(entry) <- cache.get(key)) {
                let expireAt = DateTime.now().toUnixTimeStamp().toSeconds() + ttl
                entry.expireAt = expireAt
                return true
            }
            return false
        }
    }
    
    public func ttl(key: String): Int64 {
        synchronized(mutex) {
            if (let Some(entry) <- cache.get(key)) {
                if (entry.expireAt == 0) {
                    return -1
                }
                let now = DateTime.now().toUnixTimeStamp().toSeconds()
                return entry.expireAt - now
            }
            return -2
        }
    }
    
    public func incr(key: String): Int64 {
        synchronized(mutex) {
            if (let Some(entry) <- cache.get(key)) {
                if (entry.isExpired()) {
                    cache.remove(key)
                    cache[key] = CacheEntry("1", 0)
                    return 1
                }
                let num = parseToInt64(entry.value)
                let newVal = num + 1
                entry.value = newVal.toString()
                return newVal
            }
            cache[key] = CacheEntry("1", 0)
            return 1
        }
    }
    
    public func decr(key: String): Int64 {
        synchronized(mutex) {
            if (let Some(entry) <- cache.get(key)) {
                if (entry.isExpired()) {
                    cache.remove(key)
                    cache[key] = CacheEntry("-1", 0)
                    return -1
                }
                let num = parseToInt64(entry.value)
                let newVal = num - 1
                entry.value = newVal.toString()
                return newVal
            }
            cache[key] = CacheEntry("-1", 0)
            return -1
        }
    }
    
    private func parseToInt64(s: String): Int64 {
        let result = Int64.parse(s)
        if (let n <- result) {
            return n
        }
        return 0
    }
    
    public func hget(key: String, field: String): ?String {
        return None<String>
    }
    
    public func hset(key: String, field: String, value: String): Bool {
        return true
    }
    
    public func hdel(key: String, field: String): Bool {
        return true
    }
    
    public func hgetall(key: String): HashMap<String, String> {
        return HashMap<String, String>()
    }
    
    public func lpush(key: String, value: String): Int64 {
        return 0
    }
    
    public func rpush(key: String, value: String): Int64 {
        return 0
    }
    
    public func lpop(key: String): ?String {
        return None<String>
    }
    
    public func rpop(key: String): ?String {
        return None<String>
    }
    
    public func llen(key: String): Int64 {
        return 0
    }
    
    public func sadd(key: String, member: String): Int64 {
        return 0
    }
    
    public func srem(key: String, member: String): Int64 {
        return 0
    }
    
    public func smembers(key: String): HashSet<String> {
        return HashSet<String>()
    }
    
    public func publish(channel: String, message: String): Bool {
        return true
    }
    
    public func close(): Unit {
        synchronized(mutex) {
            cache.clear()
        }
    }
}

public class CacheEntry {
    public var value: String
    public var expireAt: Int64
    
    public init(value: String, expireAt: Int64) {
        this.value = value
        this.expireAt = expireAt
    }
    
    public func isExpired(): Bool {
        if (expireAt == 0) {
            return false
        }
        let now = DateTime.now().toUnixTimeStamp().toSeconds()
        return now > expireAt
    }
}

public class CacheManager {
    private static var instance: ?CacheManager = None<CacheManager>
    private var client: CacheClient
    private var config: CacheConfig
    
    private init(config: CacheConfig) {
        this.config = config
        this.client = MemoryCacheClient()
    }

    public static func getInstance(config: CacheConfig): CacheManager {
        return instance ?? CacheManager(config)
    }

    public static func getInstance(): CacheManager {
        return instance ?? CacheManager(CacheConfig())
    }
    
    public func getClient(): CacheClient {
        return client
    }
    
    public func setClient(client: CacheClient): Unit {
        this.client = client
    }
    
    public func get(key: String): ?String {
        return client.get(key)
    }
    
    public func set(key: String, value: String): Bool {
        return client.set(key, value)
    }
    
    public func set(key: String, value: String, ttl: Int64): Bool {
        return client.set(key, value, ttl)
    }
    
    public func delete(key: String): Bool {
        return client.delete(key)
    }
    
    public func exists(key: String): Bool {
        return client.exists(key)
    }
    
    public func close(): Unit {
        client.close()
    }
}
