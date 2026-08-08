package quic_cj.congestion

import quic_cj.protocol.{PacketNumber, INITIAL_PACKET_SIZE}

// 定点 CUBIC 常量（基于 Chromium 的实现）
private let CUBE_SCALE: Int64 = 40
private let CUBE_CONGESTION_WINDOW_SCALE: Int64 = 410
private let MAX_DATAGRAM_SIZE: Int64 = INITIAL_PACKET_SIZE
private let CUBE_FACTOR: Int64 = 1 << CUBE_SCALE / CUBE_CONGESTION_WINDOW_SCALE / MAX_DATAGRAM_SIZE

private let DEFAULT_NUM_CONNECTIONS: Int64 = 1
private let BETA_FIXED: Int64 = 717  // 定点数 0.7（717/1024 = 0.700）
private let BETA_LAST_MAX_FIXED: Int64 = 870 // 定点数 0.85（870/1024 = 0.850）
private let SCALE_FACTOR: Int64 = 1024  // 2^10

/// 实现 CUBIC 拥塞控制算法（RFC 9438）。
public class Cubic {
    private var numConnections: Int64 = DEFAULT_NUM_CONNECTIONS
    private var epochStart: Int64 = 0
    private var lastMaxCongestionWindow: Int64 = 0
    private var ackedBytesCount: Int64 = 0
    private var estimatedTcpCongestionWindow: Int64 = 0
    private var originPointCongestionWindow: Int64 = 0
    private var timeToOriginPoint: Int64 = 0
    private var lastTargetCongestionWindow: Int64 = 0

    public init() {}

    /// 清除 CUBIC 状态（超时后调用）。
    public func reset(): Unit {
        epochStart = 0
        lastMaxCongestionWindow = 0
        ackedBytesCount = 0
        estimatedTcpCongestionWindow = 0
        originPointCongestionWindow = 0
        timeToOriginPoint = 0
        lastTargetCongestionWindow = 0
    }

    /// 返回 N 连接模拟的 TCP 友好 alpha。
    private func alpha(): Int64 {
        let b = beta()
        // alpha = 3 * N^2 * (1 - beta) / (1 + beta)
        let numerator = 3 * numConnections * numConnections * (SCALE_FACTOR - b)
        numerator / (SCALE_FACTOR + b)
    }

    /// 返回 N 连接模拟的回退因子。
    private func beta(): Int64 {
        (numConnections - 1) * SCALE_FACTOR + BETA_FIXED * SCALE_FACTOR / SCALE_FACTOR
        // 简化：(N - 1 + 0.7) / N = (N - 1 + 0.7) / N
        (numConnections - 1 + BETA_FIXED) / numConnections
    }

    // 使用牛顿法的定点立方根占位
    private func cubeRoot(val: Int64): Int64 {
        if (val <= 0) { return 0 }
        var x: Int64 = val
        var i: Int64 = 0
        while (i < 20) {
            let x3 = (x * x * x) >> CUBE_SCALE
            if (x3 == 0) { break }
            let delta = (val / x3 - x) / 3
            x += delta
            if (delta == 0) { break }
            i += 1
        }
        x
    }

    /// 检测到丢包时调用。
    public func onCongestionEvent(currentWindow: Int64): Int64 {
        epochStart = 0
        if (currentWindow < lastMaxCongestionWindow) {
            lastMaxCongestionWindow = currentWindow * BETA_LAST_MAX_FIXED / SCALE_FACTOR
        } else {
            lastMaxCongestionWindow = currentWindow
        }
        estimatedTcpCongestionWindow = 0
        ackedBytesCount = 0
        currentWindow * BETA_FIXED / SCALE_FACTOR
    }

    /// 收到 ACK 时更新 CUBIC 状态。
    public func onPacketAcked(now: Int64, currentWindow: Int64, delayMs: Int64): Int64 {
        ackedBytesCount += 1
        if (epochStart == 0) {
            epochStart = now
            ackedBytesCount = 1
            originPointCongestionWindow = currentWindow
            let t = (lastMaxCongestionWindow - originPointCongestionWindow) * CUBE_CONGESTION_WINDOW_SCALE * MAX_DATAGRAM_SIZE
            let target = if (t > 0) { cubeRoot(t) } else { 0 }
            timeToOriginPoint = target

            estimatedTcpCongestionWindow = originPointCongestionWindow
        }

        let t = (now - epochStart)  // 自纪元以来的时间（毫秒）
        let tInSeconds = t * SCALE_FACTOR / 1000  // 缩放后的秒

        // 计算 CUBIC 目标：C * (t - K)^3 + Wmax
        var offT = tInSeconds - timeToOriginPoint
        if (offT < 0) { offT = -offT }

        // delta = (CUBE_FACTOR * offT^3 * MAX_DATAGRAM_SIZE) >> CUBE_SCALE
        let offT3 = (offT * offT * offT) >> CUBE_SCALE
        var cubicTarget = (CUBE_FACTOR * offT3 * MAX_DATAGRAM_SIZE) >> CUBE_SCALE
        cubicTarget = cubicTarget + lastMaxCongestionWindow

        if (tInSeconds < timeToOriginPoint) {
            // 凹区域
            if (cubicTarget > currentWindow) {
                cubicTarget
            } else {
                currentWindow
            }
        } else {
            // 凸区域
            if (cubicTarget > currentWindow) {
                currentWindow + (cubicTarget - currentWindow) / SCALE_FACTOR
            } else {
                cubicTarget
            }
        }
    }
}
