# TLS 会话缓存 API 参考

## ContractTlsSessionCache

有限容量 LRU 缓存，用于存储 TLS 会话。

### ContractTlsSessionCache(maxEntries, defaultTtlSeconds)
创建会话缓存。`maxEntries` 和 `defaultTtlSeconds` 必须为正数。

### cache.upsert(entry: ContractTlsSessionCacheEntry)
插入或更新会话。超过容量时淘汰最早条目。

### cache.get(sessionId: String): ?ContractTlsSessionCacheEntry
按 sessionId 查询会话。未命中返回 `None`。

### cache.has(sessionId: String): Bool
检查 sessionId 是否存在（不更新访问时间）。

### cache.clear()
清空所有缓存条目并重置统计。

### cache.size: Int64
当前缓存条目数。

### cache.stats(): ContractTlsSessionCacheStats
返回命中和淘汰统计。

## ContractTlsSessionCacheEntry

| 字段 | 类型 | 说明 |
|------|------|------|
| `sessionId` | `String` | 会话标识 |
| `serverName` | `String` | 服务器名称 |
| `masterSecret` | `Array<Byte>` | 主密钥（32 字节） |
| `sessionTicket` | `Array<Byte>` | 会话票据 |

## ContractTlsSessionCacheStats

| 字段 | 类型 | 说明 |
|------|------|------|
| `size` | `Int64` | 当前条目数 |
| `hits` | `Int64` | 命中次数 |
| `misses` | `Int64` | 未命中次数 |
| `evictions` | `Int64` | 淘汰次数 |
| `expiredRemovals` | `Int64` | 过期移除次数 |

## 错误处理

- `maxEntries=0` 或 `defaultTtlSeconds<0` 抛出 `BAD_INPUT`
