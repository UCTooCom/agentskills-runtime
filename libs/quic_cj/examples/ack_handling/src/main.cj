package sample_ack_handling

 /**
 * ack_handling.cj — ACK 处理与丢包检测演示
 *
 * 展示 QUIC 的 ACK 处理机制，包括已发送包追踪、
 * 已接收包记录、RTT 计算和丢包检测。
 */
 
 import quic_cj.ack.{newAckHandler, newSentPacketHandler, SendMode, SequentialPacketNumberGenerator, ReceivedPacketHistory, SentPacket}
 import quic_cj.protocol.{EncryptionLevel, ECN}
 
 main(): Int64 {
     println("=== ACK Handling & Loss Detection Demo ===\n")
 
     // ── 1. ACK 处理器 ──
     println("── 1. Ack Handler ──")
     let handler = newAckHandler()
     let mode = handler.sendMode()
     let modeStr = match (mode) {
         case SendMode.None => "None"
         case SendMode.Ack => "Ack"
         case SendMode.PTOInitial => "PTOInitial"
         case SendMode.PTOHandshake => "PTOHandshake"
         case SendMode.PTOAppData => "PTOAppData"
         case SendMode.PacingLimited => "PacingLimited"
         case SendMode.Any => "Any"
     }
     println("  Initial send mode: " + modeStr)
     println("  Loss detection timeout: " + handler.getLossDetectionTimeout().toString())
 
     // ── 2. 包编号生成器 ──
     println("\n── 2. Packet Number Generator ──")
     let gen = SequentialPacketNumberGenerator(0)
     println("  Peek first: " + gen.peek().toString())
     let (skipped, pn) = gen.pop()
     println("  Pop: skipped=" + skipped.toString() + " pn=" + pn.toString())
     println("  Peek next: " + gen.peek().toString())
 
     // ── 3. 已接收包历史 ──
     println("\n── 3. Received Packet History ──")
     let hist = ReceivedPacketHistory()
     println("  Received pkt 5: new=" + hist.receivedPacket(5).toString())
     println("  Received pkt 5 again: new=" + hist.receivedPacket(5).toString())
     println("  Received pkt 6: new=" + hist.receivedPacket(6).toString())
     hist.deleteBelow(6)
     println("  After deleteBelow(6):")
     println("    pkt 1 is potentially dup: " + hist.isPotentiallyDuplicate(1).toString())
     println("    pkt 7 is potentially dup: " + hist.isPotentiallyDuplicate(7).toString())
 
     // ── 4. 已发送包 ──
     println("\n── 4. Sent Packet ──")
     let sent = SentPacket()
     println("  Default packet number: " + sent.packetNumber.toString())
     println("  Is outstanding: " + sent.outstanding().toString())
 
     // ── 5. 已发送包处理器 ──
     println("\n── 5. Sent Packet Handler ──")
     let sentHandler = newSentPacketHandler()
     let mode2 = sentHandler.sendMode()
     let modeStr2 = match (mode2) {
         case SendMode.Any => "Any"
         case SendMode.Ack => "Ack"
         case _ => "Other"
     }
     println("  Initial send mode: " + modeStr2)
 
     println("\n=== ACK Handling Demo Complete ===")
     0
 }
