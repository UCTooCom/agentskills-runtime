package sample_tls_session_cache

/** tls-session-cache — TLS 会话缓存基础操作 */
import jinguissl.contract.*

main() {
    println("=== TLS Session Cache Sample ===")

    // Create a session cache (contract facade)
    let cache = ContractTlsSessionCache(maxEntries: 10, defaultTtlSeconds: 3600)
    println("Cache created: maxEntries=10, ttl=3600s")
    println("Initial cache size: ${cache.size}")

    // Cache stats (all zeros)
    let initialStats = cache.stats()
    println("Initial stats: size=${initialStats.size}, hits=${initialStats.hits}, misses=${initialStats.misses}")
    println("  evictions=${initialStats.evictions}, expired=${initialStats.expiredRemovals}")

    // Clear the cache
    cache.clear()
    println("After clear: size=${cache.size}")

    // Create cache with bad parameters (error handling)
    try {
        _ = ContractTlsSessionCache(maxEntries: 0, defaultTtlSeconds: 60)
        println("FAIL: should have rejected maxEntries=0")
    } catch (e: ContractException) {
        println("Expected error: ${e.code.toString()} — ${e.message}")
    }

    try {
        _ = ContractTlsSessionCache(maxEntries: 5, defaultTtlSeconds: -1)
        println("FAIL: should have rejected negative TTL")
    } catch (e: ContractException) {
        println("Expected error: ${e.code.toString()} — ${e.message}")
    }

    println("TLS session cache sample completed.")
}
