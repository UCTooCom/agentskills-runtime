package quic_cj.tests

import quic_cj.core.{TokenStore, TokenData, newTokenStore}

@Test
public class TokenStoreTestSuite {
    @TestCase
    public func testNewStoreEmpty(): Unit {
        let store = newTokenStore(8, 4)
        let token = store.pop("example.com")
        @Assert(token.data.size, 0)
    }

    @TestCase
    public func testPutAndPop(): Unit {
        let store = newTokenStore(8, 4)
        let td = TokenData([0x01u8, 0x02u8, 0x03u8], 42)
        store.put("example.com", td)
        let popped = store.pop("example.com")
        @Assert(popped.data.size, 3)
        @Assert(popped.data[0], 0x01u8)
        @Assert(popped.rttMs, 42)
    }

    @TestCase
    public func testPopNonExistentKey(): Unit {
        let store = newTokenStore(4, 2)
        let token = store.pop("nonexistent.com")
        @Assert(token.data.size, 0)
    }

    @TestCase
    public func testPutMultipleOrigins(): Unit {
        let store = newTokenStore(8, 4)
        store.put("site1.com", TokenData([0x01u8], 10))
        store.put("site2.com", TokenData([0x02u8], 20))
        store.put("site3.com", TokenData([0x03u8], 30))
        let t1 = store.pop("site1.com")
        @Assert(t1.data.size, 1)
        @Assert(t1.data[0], 0x01u8)
        let t2 = store.pop("site2.com")
        @Assert(t2.data.size, 1)
        @Assert(t2.data[0], 0x02u8)
        let t3 = store.pop("site3.com")
        @Assert(t3.data.size, 1)
        @Assert(t3.data[0], 0x03u8)
    }

    @TestCase
    public func testPutOverEvictsOldest(): Unit {
        let store = newTokenStore(2, 1)  // 最多 2 个起源
        store.put("site1.com", TokenData([0x01u8], 10))
        store.put("site2.com", TokenData([0x02u8], 20))
        store.put("site3.com", TokenData([0x03u8], 30))  // site1 被驱逐
        let t1 = store.pop("site1.com")
        @Assert(t1.data.size, 0)  // 已被驱逐
        let t3 = store.pop("site3.com")
        @Assert(t3.data.size, 1)
    }
}
