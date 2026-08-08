 package quic_cj.tests
 
 import quic_cj.ack.SendMode
 
 /// SendMode 枚举全面测试
 @Test
 public class SendModeTestSuite {
     @TestCase
     public func testSendModeAllVariants(): Unit {
         let modes: Array<SendMode> = [
             SendMode.None,
             SendMode.Ack,
             SendMode.PTOInitial,
             SendMode.PTOHandshake,
             SendMode.PTOAppData,
             SendMode.PacingLimited,
             SendMode.Any
         ]
         @Assert(modes.size, 7)
     }
 
     @TestCase
     public func testSendModeNone(): Unit {
         let m = SendMode.None
         let isNone = match (m) { case SendMode.None => true; case _ => false }
         @Assert(isNone, true)
     }
 
     @TestCase
     public func testSendModeAck(): Unit {
         let m = SendMode.Ack
         let isAck = match (m) { case SendMode.Ack => true; case _ => false }
         @Assert(isAck, true)
     }
 
     @TestCase
     public func testSendModePTOInitial(): Unit {
         let m = SendMode.PTOInitial
         let isPTOInit = match (m) { case SendMode.PTOInitial => true; case _ => false }
         @Assert(isPTOInit, true)
     }
 
     @TestCase
     public func testSendModePTOHandshake(): Unit {
         let m = SendMode.PTOHandshake
         let isPTOHs = match (m) { case SendMode.PTOHandshake => true; case _ => false }
         @Assert(isPTOHs, true)
     }
 
     @TestCase
     public func testSendModePTOAppData(): Unit {
         let m = SendMode.PTOAppData
         let isPTOApp = match (m) { case SendMode.PTOAppData => true; case _ => false }
         @Assert(isPTOApp, true)
     }
 
     @TestCase
     public func testSendModePacingLimited(): Unit {
         let m = SendMode.PacingLimited
         let isPacing = match (m) { case SendMode.PacingLimited => true; case _ => false }
         @Assert(isPacing, true)
     }
 
     @TestCase
     public func testSendModeAny(): Unit {
         let m = SendMode.Any
         let isAny = match (m) { case SendMode.Any => true; case _ => false }
         @Assert(isAny, true)
     }
 }
