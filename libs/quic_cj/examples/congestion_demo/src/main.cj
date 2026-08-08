package sample_congestion_demo

/**
 * congestion_demo.cj — 拥塞控制演示
 *
 * 演示 CUBIC 拥塞控制的实现。
 * 展示数据传输过程中拥塞窗口的变化。
 *
 * QUIC 使用 CUBIC（RFC 9438）进行拥塞控制，包括：
 *   - 混合慢启动
 *   - 令牌桶调速
 *   - 带宽估计
 *   - ACK 触发的窗口增长
 */

import quic_cj.congestion.{CubicSender, newCubicSender, Pacer, bandwidthFromDelta}

main(): Int64 {
    println("=== CUBIC Congestion Control Demo ===\n")

    // ── 基本发送器状态 ──
    println("── Basic Sender State ──")
    let sender = newCubicSender()
    println("  Initial CWND: " + sender.getCwnd().toString() + " bytes")
    println("  In slow start: " + sender.inSlowStart().toString())
    println("  In recovery: " + sender.inRecovery().toString())

    // ── 慢启动增长 ──
    println("\n── Slow Start Growth ──")
    let cwnd0 = sender.getCwnd()
    var i: Int64 = 0
    while (i < 20) {
        sender.onPacketAcked(1000, sender.getCwnd())
        i += 1
    }
    let cwnd1 = sender.getCwnd()
    println("  After 20 ACKs: " + cwnd1.toString() + " bytes")
    println("  Growth: " + (cwnd1 - cwnd0).toString() + " bytes")

    // ── 拥塞事件 ──
    println("\n── Congestion Event ──")
    let beforeCwnd = sender.getCwnd()
    println("  Window before loss: " + beforeCwnd.toString())
    sender.onCongestionEvent(beforeCwnd / 3, beforeCwnd)
    let afterCwnd = sender.getCwnd()
    println("  Window after loss: " + afterCwnd.toString())
    println("  Reduction: " + (beforeCwnd - afterCwnd).toString() + " bytes")
    println("  In recovery: " + sender.inRecovery().toString())
    println("  In slow start: " + sender.inSlowStart().toString())

    // ── 发送资格 ──
    println("\n── Send Eligibility ──")
    println("  Can send 100 bytes: " + sender.canSend(100).toString())
    println("  Can send " + (sender.getCwnd() * 2).toString() + " bytes: " + sender.canSend(sender.getCwnd() * 2).toString())

    // ── 调速 ──
    println("\n── Pacing ──")
    let pacer = Pacer()
    pacer.setBandwidth(10000000u64)  // 10 MB/秒
    let budget0 = pacer.budget(0)
    println("  Initial pacing budget: " + budget0.toString())
    let budgetLater = pacer.budget(100000)  // 100 毫秒后
    println("  Budget after 100ms: " + budgetLater.toString())

    // ── 带宽估计 ──
    println("\n── Bandwidth Estimation ──")
    let bw = bandwidthFromDelta(10000, 100000000)  // 100 毫秒内 10KB
    println("  Estimated bandwidth: " + bw.toString() + " 字节/秒")
    let bw2 = bandwidthFromDelta(0, 100000000)
    println("  Zero bytes bandwidth: " + bw2.toString())

    println("\n=== Congestion Control Demo Complete ===")
    0
}
