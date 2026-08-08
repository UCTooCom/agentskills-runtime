 package quic_cj.tests
 
 import quic_cj.ack.{isFrameTypeAckEliciting, isFrameAckEliciting, hasAckElicitingFrames}
 import quic_cj.wire.{Frame, PingFrame, AckFrame, CryptoFrame, ConnectionCloseFrame, ApplicationCloseFrame}
 
 @Test
 public class AckElicitingTestSuite {
     @TestCase
     public func testPingIsAckEliciting(): Unit {
         @Assert(isFrameAckEliciting(PingFrame()), true)
     }
 
     @TestCase
     public func testAckFrameNotAckEliciting(): Unit {
         @Assert(isFrameAckEliciting(AckFrame()), false)
     }
 
     @TestCase
     public func testCryptoFrameIsAckEliciting(): Unit {
         @Assert(isFrameAckEliciting(CryptoFrame()), true)
     }
 
     @TestCase
     public func testConnectionCloseNotAckEliciting(): Unit {
         @Assert(isFrameAckEliciting(ConnectionCloseFrame()), false)
     }
 
     @TestCase
     public func testApplicationCloseNotAckEliciting(): Unit {
         @Assert(isFrameAckEliciting(ApplicationCloseFrame()), false)
     }
 
     @TestCase
     public func testHasAckElicitingFramesTrue(): Unit {
         let frames: Array<Frame> = [PingFrame(), AckFrame()]
         @Assert(hasAckElicitingFrames(frames), true)
     }
 
     @TestCase
     public func testHasAckElicitingFramesFalse(): Unit {
         let frames: Array<Frame> = [AckFrame(), ConnectionCloseFrame()]
         @Assert(hasAckElicitingFrames(frames), false)
     }
 
     @TestCase
     public func testHasAckElicitingFramesEmpty(): Unit {
         let frames: Array<Frame> = []
         @Assert(hasAckElicitingFrames(frames), false)
     }
 
     @TestCase
     public func testIsFrameTypeAckEliciting(): Unit {
         @Assert(isFrameTypeAckEliciting(0x01u8), true)  // PING
         @Assert(isFrameTypeAckEliciting(0x02u8), false) // ACK
         @Assert(isFrameTypeAckEliciting(0x03u8), false) // ACK_ECN
         @Assert(isFrameTypeAckEliciting(0x04u8), true)  // RESET_STREAM
         @Assert(isFrameTypeAckEliciting(0x1cu8), false) // CONNECTION_CLOSE
         @Assert(isFrameTypeAckEliciting(0x1du8), false) // APPLICATION_CLOSE
     }
 }
