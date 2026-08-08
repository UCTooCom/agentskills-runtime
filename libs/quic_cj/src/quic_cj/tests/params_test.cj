 package quic_cj.tests
 
 import quic_cj.protocol.{MAX_BYTE_COUNT, INVALID_BYTE_COUNT, MAX_PACKET_BUFFER_SIZE, MAX_LARGE_PACKET_BUFFER_SIZE, MIN_INITIAL_PACKET_SIZE, MAX_CONN_ID_LEN, MIN_CONN_ID_LEN_INITIAL, DEFAULT_ACK_DELAY_EXPONENT, MAX_ACK_DELAY_EXPONENT, DEFAULT_ACTIVE_CONNECTION_ID_LIMIT, DEFAULT_IDLE_TIMEOUT_MS, DEFAULT_HANDSHAKE_IDLE_TIMEOUT_MS, DEFAULT_MAX_INCOMING_STREAMS, INITIAL_PACKET_SIZE, TIMER_GRANULARITY_MS, MAX_ACK_DELAY_MS, KEY_UPDATE_INTERVAL}
 
 @Test
 public class ParamsTestSuite {
     @TestCase
     public func testMaxByteCount(): Unit {
         @Assert(MAX_BYTE_COUNT > 0, true)
     }
 
     @TestCase
     public func testInvalidByteCount(): Unit {
         @Assert(INVALID_BYTE_COUNT, -1)
     }
 
     @TestCase
     public func testPacketBufferSizes(): Unit {
         @Assert(MAX_PACKET_BUFFER_SIZE, 1452)
         @Assert(MAX_LARGE_PACKET_BUFFER_SIZE, 20 * 1024)
     }
 
     @TestCase
     public func testMinInitialPacketSize(): Unit {
         @Assert(MIN_INITIAL_PACKET_SIZE, 1200)
     }
 
     @TestCase
     public func testConnIdLen(): Unit {
         @Assert(MAX_CONN_ID_LEN, 20)
         @Assert(MIN_CONN_ID_LEN_INITIAL, 8)
     }
 
     @TestCase
     public func testAckDelayExponent(): Unit {
         @Assert(DEFAULT_ACK_DELAY_EXPONENT, 3)
         @Assert(MAX_ACK_DELAY_EXPONENT, 20)
     }
 
     @TestCase
     public func testActiveConnIdLimit(): Unit {
         @Assert(DEFAULT_ACTIVE_CONNECTION_ID_LIMIT, 2)
     }
 
     @TestCase
     public func testIdleTimeout(): Unit {
         @Assert(DEFAULT_IDLE_TIMEOUT_MS, 30000)
         @Assert(DEFAULT_HANDSHAKE_IDLE_TIMEOUT_MS, 5000)
     }
 
     @TestCase
     public func testMaxIncomingStreams(): Unit {
         @Assert(DEFAULT_MAX_INCOMING_STREAMS, 100)
     }
 
     @TestCase
     public func testInitialPacketSize(): Unit {
         @Assert(INITIAL_PACKET_SIZE, 1280)
     }
 
     @TestCase
     public func testTimerGranularity(): Unit {
         @Assert(TIMER_GRANULARITY_MS, 1)
         @Assert(MAX_ACK_DELAY_MS, 25)
     }
 
     @TestCase
     public func testKeyUpdateInterval(): Unit {
         @Assert(KEY_UPDATE_INTERVAL, 100000)
     }
 
     @TestCase
     public func testConstantsConsistency(): Unit {
         // 初始包大小必须至少是最小值
         @Assert(INITIAL_PACKET_SIZE >= MIN_INITIAL_PACKET_SIZE, true)
     }
 }
