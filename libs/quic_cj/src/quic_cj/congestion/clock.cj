package quic_cj.congestion

/// Clock 为拥塞控制操作提供当前时间。
open public class Clock {
    open public func now(): Int64 { 0 }
}

/// DefaultClock 返回单调时间。
public class DefaultClock <: Clock {
    public func now(): Int64 {
        // 占位：返回 0。真实实现将使用 System.nanoTime()
        0
    }
}
