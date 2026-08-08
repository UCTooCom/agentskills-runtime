 package quic_cj.tests
 
 import quic_cj.protocol.{generateConnectionId, isValidConnectionIdLen, MAX_CONN_ID_LEN, MIN_CONN_ID_LEN_INITIAL}
 
 @Test
 public class ConnectionIdExtendedTestSuite {
     @TestCase
     public func testGenerateConnIdDefaultSizeEight(): Unit {
         let cid = generateConnectionId(8)
         @Assert(cid.size, 8)
     }
 
     @TestCase
     public func testGenerateConnIdSmall(): Unit {
         let cid = generateConnectionId(4)
         @Assert(cid.size, 4)
     }
 
     @TestCase
     public func testGenerateConnIdMax(): Unit {
         let cid = generateConnectionId(MAX_CONN_ID_LEN)
         @Assert(cid.size, MAX_CONN_ID_LEN)
     }
 
     @TestCase
     public func testGenerateConnIdLargeReturnsSize(): Unit {
         let cid = generateConnectionId(100)
         @Assert(cid.size, 100)
     }
 
     @TestCase
     public func testGenerateConnIdZeroLength(): Unit {
         let cid = generateConnectionId(0)
         @Assert(cid.size, 0)
     }
 
     @TestCase
     public func testIsValidConnIdLenMin(): Unit {
         @Assert(isValidConnectionIdLen(MIN_CONN_ID_LEN_INITIAL), true)
     }
 
     @TestCase
     public func testIsValidConnIdLenMax(): Unit {
         @Assert(isValidConnectionIdLen(MAX_CONN_ID_LEN), true)
     }
 
     @TestCase
     public func testIsValidConnIdLenZero(): Unit {
         @Assert(isValidConnectionIdLen(0), true)
     }
 
     @TestCase
     public func testIsValidConnIdLenTooLarge(): Unit {
         @Assert(isValidConnectionIdLen(MAX_CONN_ID_LEN + 1), false)
     }
 
     @TestCase
     public func testGenerateConnIdUnique(): Unit {
         let cid1 = generateConnectionId(8)
         let cid2 = generateConnectionId(8)
         // 检查两个生成的 ID 不同（概率上）
         var diff = false
         var i: Int64 = 0
         while (i < cid1.size) {
             if (cid1[i] != cid2[i]) { diff = true; break }
             i += 1
         }
         // 只有极低概率会相同
         @Assert(diff, true)
     }
 
     @TestCase
     public func testGenerateConnIdContainsRandom(): Unit {
         let cid = generateConnectionId(8)
         @Assert(cid.size, 8)
         // 验证不全是零
         var allZero = true
         var i: Int64 = 0
         while (i < cid.size) {
             if (cid[i] != 0u8) { allZero = false; break }
             i += 1
         }
         @Assert(allZero, false)
     }
 }
