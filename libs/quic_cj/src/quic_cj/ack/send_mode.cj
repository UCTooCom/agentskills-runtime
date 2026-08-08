package quic_cj.ack

/// SendMode 指出可以发送哪种包。
/// 匹配 quic-go 的 SendMode 常量。
public enum SendMode {
    | None          // 不应发送任何包
    | Ack           // 仅 ACK 包
    | PTOInitial    // 初始探测包
    | PTOHandshake  // 握手探测包
    | PTOAppData    // 应用数据探测包
    | PacingLimited // 调速发送（将很快允许）
    | Any           // 可以发送任何包
}
