package sample_error_handling

 /**
 * error_handling.cj — QUIC 错误处理演示
 *
 * 展示 QUIC 的传输层和应用层错误处理机制。
 * 包括错误码、错误类型的转换和连接关闭时的错误传递。
 */
 
 import quic_cj.*
 import quic_cj.util.{NO_ERROR, INTERNAL_ERROR, PROTOCOL_VIOLATION}
 
 main(): Int64 {
     println("=== QUIC Error Handling Demo ===\n")
 
     // ── 1. 传输层错误 ──
     println("── 1. Transport Errors ──")
     let err1 = newTransportError(NO_ERROR, "no error")
     println("  NO_ERROR: code=" + err1.transportCode.toString() +
             " msg=\"" + err1.errorMessage + "\"" +
             " isTransport=" + err1.isTransport.toString())
 
     let err2 = newTransportError(INTERNAL_ERROR, "internal error")
     println("  INTERNAL_ERROR: code=" + err2.transportCode.toString() +
             " msg=\"" + err2.errorMessage + "\"")
 
     let err3 = newTransportError(PROTOCOL_VIOLATION, "protocol violation")
     println("  PROTOCOL_VIOLATION: code=" + err3.transportCode.toString() +
             " msg=\"" + err3.errorMessage + "\"")
 
     // ── 2. 应用层错误 ──
     println("\n── 2. Application Errors ──")
     let appErr = newApplicationError(0x100u64, "application error")
     println("  App error: code=0x" + appErr.appCode.toString() +
             " msg=\"" + appErr.errorMessage + "\"" +
             " isTransport=" + appErr.isTransport.toString())
 
     let httpErr = newApplicationError(0x1u64, "HTTP/3 internal error")
     println("  HTTP/3 error: code=0x" + httpErr.appCode.toString() +
             " msg=\"" + httpErr.errorMessage + "\"")
 
     // ── 3. 标准错误码 ──
     println("\n── 3. Standard Error Codes ──")
     println("  NO_ERROR:          " + NO_ERROR.toString() + " (" + NO_ERROR.toString() + ")")
     println("  INTERNAL_ERROR:    " + INTERNAL_ERROR.toString() + " (" + INTERNAL_ERROR.toString() + ")")
     println("  PROTOCOL_VIOLATION: " + PROTOCOL_VIOLATION.toString() + " (" + PROTOCOL_VIOLATION.toString() + ")")
 
     // ── 4. 错误类型识别 ──
     println("\n── 4. Error Type Discrimination ──")
     let transportErr = newTransportError(0x0au64, "protocol violation")
     let appError = newApplicationError(0x100u64, "custom app error")
     println("  Transport error check: isTransport=" + transportErr.isTransport.toString())
     println("  Application error check: isTransport=" + appError.isTransport.toString())
 
      // ── 5. 连接关闭错误 ──
      println("\n── 5. Connection Close Errors ──")
      let cfg = defaultConfig()
      if (let Some(conn) <- dialAddr("127.0.0.1:4433", cfg)) {
          conn.closeWithError(0x01u64, "client shutdown")
          println("  Connection closed with code=1, reason='client shutdown'")
          let closeErr = conn.getConnState()
          println("  Connection closed gracefully")
      }
 
     println("\n=== Error Handling Demo Complete ===")
     0
 }
