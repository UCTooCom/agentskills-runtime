package sample_connection_lifecycle

 /**
 * connection_lifecycle.cj — QUIC 连接生命周期演示
 *
 * 展示 QUIC 连接的状态机：Initial → Handshake → Established → Closing → Closed。
 * 演示连接创建、状态转换、空闲超时机制和优雅关闭。
 */
 
 import quic_cj.*
 import quic_cj.core.{newClientConnection, ConnectionState}
 
 main(): Int64 {
     println("=== QUIC Connection Lifecycle Demo ===\n")
 
     // 创建连接 ID
     let destId: Array<Byte> = [0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8, 0x08u8]
     let srcId: Array<Byte> = [0x0au8, 0x0bu8, 0x0cu8, 0x0du8, 0x0eu8, 0x0fu8, 0x10u8, 0x11u8]
 
     // ── 1. Initial 状态 ──
     println("── 1. Initial State ──")
     let conn = newClientConnection(destId, srcId)
     println("  Connection created")
     println("  State: " + stateStr(conn.getState()))
     println("  Version: " + conn.getVersion().toString())
     println("  Src ConnID: " + conn.getSrcConnId().size.toString() + " bytes")
     println("  Dest ConnID: " + conn.getDestConnId().size.toString() + " bytes")
 
     // ── 2. Handshake 状态 ──
     println("\n── 2. Handshake ──")
     conn.setState(ConnectionState.Handshake)
     println("  State: " + stateStr(conn.getState()))
     println("  Handshake in progress...")
 
     // ── 3. Established 状态 ──
     println("\n── 3. Established ──")
     conn.setState(ConnectionState.Established)
     println("  State: " + stateStr(conn.getState()))
     println("  Connection ready for data transfer")
 
      // 在已建立状态下测试流操作
      if (let Some(stream) <- conn.openStream()) {
          println("  Opened stream: " + stream.getStreamId().toString())
      }
 
     // ── 4. Closing 状态 ──
     println("\n── 4. Closing ──")
     conn.closeWithError(0u64, "normal shutdown")
     println("  State: " + stateStr(conn.getState()))
     println("  Close error code: 0 (NO_ERROR)")
 
     // ── 5. Closed 状态 ──
     println("\n── 5. Closed ──")
     conn.tick(5000)  // 空闲超时期满
     println("  State: " + stateStr(conn.getState()))
     println("  Is closed: " + conn.isClosed().toString())
 
     // ── 6. 空闲超时 ──
     println("\n── 6. Idle Timeout ──")
     let timeoutConn = newClientConnection(destId, srcId)
     timeoutConn.setIdleTimeout(100)  // 100 毫秒空闲超时
     println("  Idle timeout set to 100ms")
     println("  State before timeout: " + stateStr(timeoutConn.getState()))
     timeoutConn.tick(500)  // 超过超时时间
     let isClosed = match (timeoutConn.getState()) {
         case ConnectionState.Closed => true
         case _ => false
     }
     println("  State after timeout: " + stateStr(timeoutConn.getState()))
     println("  Connection timed out: " + isClosed.toString())
 
     println("\n=== Lifecycle Demo Complete ===")
     0
 }
 
 private func stateStr(s: ConnectionState): String {
     match (s) {
         case ConnectionState.Initial => "Initial"
         case ConnectionState.Handshake => "Handshake"
         case ConnectionState.Established => "Established"
         case ConnectionState.Closing => "Closing"
         case ConnectionState.Closed => "Closed"
     }
 }
