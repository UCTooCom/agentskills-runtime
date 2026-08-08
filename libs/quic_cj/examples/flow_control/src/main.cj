package sample_flow_control

 /**
 * flow_control.cj — 流量控制演示
 *
 * 展示 QUIC 的流量控制机制，包括流级别和连接级别的窗口管理。
 * QUIC 使用逐流和连接级别的流量控制来防止接收方被数据淹没。
 */
 
 import quic_cj.flow.{StreamFlowController, ConnectionFlowController}
 
 main(): Int64 {
     println("=== QUIC Flow Control Demo ===\n")
 
     // ── 1. 流级别流量控制 ──
     println("── 1. Stream-Level Flow Control ──")
     let streamFc = StreamFlowController(0)
     let initialSendWindow = streamFc.sendWindowSize()
     println("  Initial send window: " + initialSendWindow.toString() + " bytes")
     println("  Is blocked initially: " + streamFc.isBlocked().toString())
 
     // 消耗发送窗口
     streamFc.addBytesSent(initialSendWindow)
     println("  After exhausting window:")
     println("  Send window: " + streamFc.sendWindowSize().toString() + " bytes")
     println("  Is blocked: " + streamFc.isBlocked().toString())
 
     // 对端提高窗口上限
     streamFc.updateSendWindow(initialSendWindow * 2)
     println("  After peer update to " + (initialSendWindow * 2).toString() + ":")
     println("  Send window: " + streamFc.sendWindowSize().toString() + " bytes")
     println("  Is blocked: " + streamFc.isBlocked().toString())
 
     // ── 2. 部分阻塞 ──
     println("\n── 2. Partial Blocking ──")
     let partialFc = StreamFlowController(0)
     let halfWindow = partialFc.sendWindowSize() / 2
     partialFc.addBytesSent(halfWindow)
     println("  Sent " + halfWindow.toString() + " bytes:")
     println("  Remaining window: " + partialFc.sendWindowSize().toString() + " bytes")
     println("  Is blocked: " + partialFc.isBlocked().toString())
 
     // ── 3. 连接级别流量控制 ──
     println("\n── 3. Connection-Level Flow Control ──")
     let connFc = ConnectionFlowController()
     println("  Initial receive window: " + connFc.getReceiveWindow().toString() + " bytes")
     println("  Has window update: " + connFc.hasWindowUpdate().toString())
 
     // 消耗接收窗口
     connFc.addBytesRead(200000)
     println("  After reading 200KB:")
     println("  Bytes read: " + connFc.getBytesRead().toString())
     println("  Has window update: " + connFc.hasWindowUpdate().toString())
 
     // ── 4. 窗口自动增长阈值 ──
     println("\n── 4. Update Threshold ──")
     let growthFc = ConnectionFlowController()
     growthFc.addBytesRead(10000)
     println("  After reading 10KB: hasUpdate=" + growthFc.hasWindowUpdate().toString())
     growthFc.addBytesRead(200000)
     println("  After reading 200KB: hasUpdate=" + growthFc.hasWindowUpdate().toString())
 
     println("\n=== Flow Control Demo Complete ===")
     0
 }
