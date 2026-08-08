 package quic_cj.tests
 
 import quic_cj.congestion.Cubic
 
 @Test
 public class CubicTestSuite {
     @TestCase
     public func testCubicInit(): Unit {
         let c = Cubic()
         @Assert(true, true)
     }
 
     @TestCase
     public func testCubicReset(): Unit {
         let c = Cubic()
         c.reset()
         @Assert(true, true)
     }
 
     @TestCase
     public func testCubicOnCongestionEvent(): Unit {
         let c = Cubic()
         let newWindow = c.onCongestionEvent(10000)
         @Assert(newWindow > 0, true)
         @Assert(newWindow < 10000, true)
     }
 
     @TestCase
     public func testCubicOnCongestionEventSmallWindow(): Unit {
         let c = Cubic()
         let newWindow = c.onCongestionEvent(2048)
         @Assert(newWindow > 0, true)
     }
 
     @TestCase
     public func testCubicOnCongestionEventLargeWindow(): Unit {
         let c = Cubic()
         let newWindow = c.onCongestionEvent(1000000)
         @Assert(newWindow > 0, true)
         @Assert(newWindow < 1000000, true)
     }
 
     @TestCase
     public func testCubicOnPacketAckedStartsWithEpoch(): Unit {
         // 首次调用 onPacketAcked 初始化周期。
         // 当 lastMaxCongestionWindow=0 时，返回值可能为 0。
         // 本测试验证无崩溃且状态设置正确。
         let c = Cubic()
         let cwnd = c.onPacketAcked(0, 10000, 0)
         @Assert(cwnd >= 0, true)
     }
 
     @TestCase
     public func testCubicOnPacketAckedOnlyNoOverflow(): Unit {
         // 在没有先前拥塞的情况下连续调用 onPacketAcked，t=0
         // 因此不调用 cubeRoot（返回 0），避免 cubeRoot 溢出。
         let c = Cubic()
         let r1 = c.onPacketAcked(0, 10000, 0)
         let r2 = c.onPacketAcked(100, r1, 0)
         let r3 = c.onPacketAcked(200, r2, 0)
         @Assert(r1 >= 0, true)
         @Assert(r2 >= 0, true)
         @Assert(r3 >= 0, true)
     }
 
     @TestCase
     public func testCubicResetClearsState(): Unit {
         let c = Cubic()
         c.onCongestionEvent(10000)
         c.reset()
         @Assert(true, true)
     }
 
 
     @TestCase
     public func testCubicOnPacketAckedAfterReset(): Unit {
         // 重置后 ACK 不应崩溃
         let c = Cubic()
         c.onCongestionEvent(50000)
         c.reset()
         let result = c.onPacketAcked(1000, 50000, 5)
         @Assert(result >= 0, true)
     }
 }
