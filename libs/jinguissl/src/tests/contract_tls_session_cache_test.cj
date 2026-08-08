package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractTlsSessionCacheTestSuite {
    @TestCase
    public func testContractTlsSessionCacheStaysLinkable(): Unit {
        let cache = ContractTlsSessionCache(maxEntries: 2, defaultTtlSeconds: 60)
        @Assert(cache.size, 0)

        let stats = cache.stats()
        @Assert(stats.size, 0)
        @Assert(stats.hits, 0)
        @Assert(stats.misses, 0)
        @Assert(stats.evictions, 0)
        @Assert(stats.expiredRemovals, 0)
    }

    @TestCase
    public func testContractTlsSessionCacheRejectsBadCapacity(): Unit {
        try {
            _ = ContractTlsSessionCache(maxEntries: 0, defaultTtlSeconds: 60)
            @Fail("session cache maxEntries=0 should fail through the contract facade")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }
}


@Test
public class ContractSupplementarySessionCacheTestSuite {
    @TestCase
    public func testContractTlsSessionCacheClear(): Unit {
        let cache = ContractTlsSessionCache(maxEntries: 10, defaultTtlSeconds: 60)
        @Assert(cache.size, 0)
        let before = cache.stats()
        @Assert(before.size, 0)
        cache.clear()
        let after = cache.stats()
        @Assert(after.size, 0)
    }

    @TestCase
    public func testContractTlsSessionCacheRejectsNegativeTtl(): Unit {
        try {
            _ = ContractTlsSessionCache(maxEntries: 5, defaultTtlSeconds: -1)
            @Fail("negative TTL should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractTlsSessionCacheRejectsZeroMaxEntries(): Unit {
        try {
            _ = ContractTlsSessionCache(maxEntries: 0, defaultTtlSeconds: 60)
            @Fail("zero maxEntries should be rejected")
        } catch (e: ContractException) {
            @Assert(e.code.toString(), "BAD_INPUT")
        }
    }

    @TestCase
    public func testContractTlsSessionCacheInitialStats(): Unit {
        let cache = ContractTlsSessionCache(maxEntries: 10, defaultTtlSeconds: 600)
        @Assert(cache.size, 0)
        let stats = cache.stats()
        @Assert(stats.size, 0)
        @Assert(stats.hits, 0)
        @Assert(stats.misses, 0)
        @Assert(stats.evictions, 0)
        @Assert(stats.expiredRemovals, 0)
    }

    @TestCase
    public func testContractTlsSessionCacheMultipleStatsCheck(): Unit {
        let cache = ContractTlsSessionCache(maxEntries: 10, defaultTtlSeconds: 600)
        let s1 = cache.stats()
        @Assert(s1.size, 0)
        let s2 = cache.stats()
        @Assert(s2.size, 0)
        @Assert(s1.size, s2.size)
    }

    @TestCase
    public func testContractTlsSessionCacheLargeCapacity(): Unit {
        let cache = ContractTlsSessionCache(maxEntries: 10000, defaultTtlSeconds: 86400)
        @Assert(cache.size, 0)
        let stats = cache.stats()
        @Assert(stats.size, 0)
        @Assert(stats.hits, 0)
        @Assert(stats.misses, 0)
        @Assert(stats.evictions, 0)
        @Assert(stats.expiredRemovals, 0)
    }
}
