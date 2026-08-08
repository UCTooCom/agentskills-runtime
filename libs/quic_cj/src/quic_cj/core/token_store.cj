package quic_cj.core

/// TokenData 表示一个令牌及其 RTT 信息。
public class TokenData {
    public var data: Array<Byte> = []
    public var rttMs: Int64 = 0
    public init() {}
    public init(data: Array<Byte>, rttMs: Int64) {
        this.data = data
        this.rttMs = rttMs
    }
}

/// SingleOriginTokenStore 为单个来源存储多个令牌（循环缓冲区）。
internal class SingleOriginTokenStore {
    private var tokens: Array<TokenData> = []
    private var len: Int64 = 0
    private var head: Int64 = 0

    public init(size: Int64) {
        tokens = Array<TokenData>(size, repeat: TokenData())
    }

    public func add(token: TokenData): Unit {
        tokens[head] = token
        head = (head + 1) % tokens.size
        len = min(len + 1, tokens.size)
    }

    public func pop(): TokenData {
        head = (head - 1 + tokens.size) % tokens.size
        let token = tokens[head]
        tokens[head] = TokenData()
        len = max(len - 1, 0)
        token
    }

    public func size(): Int64 { len }
}

/// TokenStoreEntry 保存一个起源的令牌缓存。
internal class TokenStoreEntry {
    public var key: String = ""
    public var cache: SingleOriginTokenStore = SingleOriginTokenStore(4)
}

/// TokenStore 提供令牌缓存。
/// 使用 LRU 策略，最多缓存 maxOrigins 个起源，每个起源最多 tokensPerOrigin 个令牌。
public class TokenStore {
    private var entries: Array<TokenStoreEntry> = []
    private var keys: Array<String> = []
    private var capacity: Int64 = 8
    private var perOriginSize: Int64 = 4

    public init(maxOrigins: Int64, tokensPerOrigin: Int64) {
        capacity = maxOrigins
        perOriginSize = tokensPerOrigin
    }

    /// 存储一个令牌。
    public func put(key: String, token: TokenData): Unit {
        let idx = findKey(key)
        if (idx >= 0) {
            entries[idx].cache.add(token)
            return
        }

        if (entries.size < capacity) {
            let entry = TokenStoreEntry()
            entry.key = key
            entry.cache = SingleOriginTokenStore(perOriginSize)
            entry.cache.add(token)
            entries = appendStoreEntry(entries, entry)
            keys = appendString(keys, key)
            return
        }

        // 驱逐最旧的
        entries = entries[1..]
        keys = keys[1..]
        let entry = TokenStoreEntry()
        entry.key = key
        entry.cache = SingleOriginTokenStore(perOriginSize)
        entry.cache.add(token)
        entries = appendStoreEntry(entries, entry)
        keys = appendString(keys, key)
    }

    /// 弹出指定起源的令牌。
    public func pop(key: String): TokenData {
        let idx = findKey(key)
        if (idx < 0) { return TokenData() }
        let token = entries[idx].cache.pop()
        if (entries[idx].cache.size() == 0) {
            var newEntries: Array<TokenStoreEntry> = []
            var newKeys: Array<String> = []
            var i: Int64 = 0
            while (i < entries.size) {
                if (i != idx) {
                    newEntries = appendStoreEntry(newEntries, entries[i])
                    newKeys = appendString(newKeys, keys[i])
                }
                i += 1
            }
            entries = newEntries
            keys = newKeys
        }
        token
    }

    private func findKey(key: String): Int64 {
        var i: Int64 = 0
        while (i < keys.size) {
            if (keys[i] == key) { return i }
            i += 1
        }
        -1
    }
}

internal func appendStoreEntry(arr: Array<TokenStoreEntry>, entry: TokenStoreEntry): Array<TokenStoreEntry> {
    let n = arr.size
    var out = Array<TokenStoreEntry>(n + 1, repeat: TokenStoreEntry())
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = entry
    out
}

internal func appendString(arr: Array<String>, s: String): Array<String> {
    let n = arr.size
    var out = Array<String>(n + 1, repeat: "")
    var i: Int64 = 0
    while (i < n) { out[i] = arr[i]; i += 1 }
    out[n] = s
    out
}

public func newTokenStore(maxOrigins: Int64, tokensPerOrigin: Int64): TokenStore {
    TokenStore(maxOrigins, tokensPerOrigin)
}
