# 性能调优指南
 
 本文档提供 quic_cj 的性能优化建议和参数调整指南。
 
 ## QUIC 性能关键参数
 
 ### 初始包大小（Initial Packet Size）
 
 初始包大小决定了握手阶段的数据包大小。
 
 ```cangjie
 let cfg = Config()
 cfg.initialPacketSize = 1450  // 接近以太网 MTU，提高吞吐量
 ```
 
 - **最小值**：1200（RFC 9000 强制要求）
 - **推荐值**：1450（标准以太网 MTU 1500 - IPv4/UDP 开销）
 - **调大收益**：减少包数量，提高大文件传输效率
 - **调大风险**：可能触发路径 MTU 问题
 
 ### 接收窗口大小
 
 接收窗口控制接收方的缓冲区大小，影响吞吐量。
 
 ```cangjie
 let cfg = Config()
 cfg.initialStreamReceiveWindow = 1024 * 1024        // 1 MB 初始流窗口
 cfg.maxStreamReceiveWindow = 4 * 1024 * 1024        // 4 MB 最大流窗口
 cfg.initialConnectionReceiveWindow = 16 * 1024 * 1024   // 16 MB 初始连接窗口
 cfg.maxConnectionReceiveWindow = 64 * 1024 * 1024       // 64 MB 最大连接窗口
 ```
 
 - **大窗口**：适合高带宽、高延迟网络（如卫星链路）
 - **小窗口**：适合低内存设备或低延迟本地网络
 
 ### 流数量限制
 
 ```cangjie
 let cfg = Config()
 cfg.maxIncomingStreams = 100      // 并发双向流上限
 cfg.maxIncomingUniStreams = 100   // 并发单向流上限
 ```
 
 ### 空闲超时
 
 ```cangjie
 let cfg = Config()
 cfg.maxIdleTimeoutMs = 60000       // 60 秒空闲超时
 cfg.handshakeIdleTimeoutMs = 10000 // 10 秒握手超时
 ```
 
 - **长超时**：保留连接状态，减少重连开销
 - **短超时**：节省服务端资源，加速连接释放
 
 ## 拥塞控制优化
## 拥塞控制优化
quic_cj 实现 CUBIC（RFC 9438）和 NewReno（RFC 6582）拥塞控制。
 - **默认算法：** CUBIC — 适用于高带宽远距离网络
 - **可选算法：** NewReno — 适用于低丢包率环境，更保守的窗口调整
 - **慢启动**：初始窗口的指数增长阶段
 - **拥塞避免**：达到慢启动阈值后的线性增长阶段
 - **调节器（Pacer）**：平滑数据发送，避免突发
 
 ## 内存管理
 
 quic_cj 使用环形缓冲区对象池来减少内存分配：
 
 ```cangjie
 import quic_cj.sys.UdpBufferPool
 let pool = UdpBufferPool()
 let buf = pool.get()  // 从池中获取缓冲区
 // ... 使用缓冲区 ...
 pool.put(buf)          // 归还缓冲区复用
 ```
 
 ## 性能对比场景
 
 | 场景 | 窗口大小 | 包大小 | 超时 | 流数 |
 |------|---------|-------|------|------|
 | 高吞吐下载 | 64 MB | 1450 | 5 min | 1000 |
 | 实时通信 | 256 KB | 1200 | 10 s | 20 |
 | IoT 设备 | 64 KB | 1200 | 30 s | 10 |
 | 网关转发 | 1 MB | 1450 | 2 min | 500 |
 
 ## 构建优化
 
 ```bash
 # 发布构建（优化级别更高）
 cjpm build --release
 
 # 清理后构建
 rm -rf target/release
 cjpm build
 ```
 
 ## 基准测试
 
 对于性能敏感的生产环境，建议：
 1. 使用 `initialPacketSize = 1450`（接近 MTU）
 2. 计算带宽延迟积（BDP）设置合适的接收窗口
 3. 监控丢包率，适时调整拥塞控制参数
 4. 测试不同并发流数下的吞吐表现


---

## 基准测试数据

以下是在标准环境下运行 `cjpm bench` 得到的基准测试结果（单位：纳秒），基于 81 个基准测试用例：

| 模块 | 关键操作 | 中位数 (ns) | 误差 |
|------|---------|------------|------|
| 变长整数 | readVarint1Byte | 74.79 | ±12.4% |
| 变长整数 | appendVarintLarge | 406.4 | ±9.1% |
| 帧序列化 | serializePing | 99.13 | ±5.4% |
| 帧序列化 | serializeCrypto | 5519 | ±8.9% |
| CUBIC | cubicInit | 34.07 | ±14.3% |
| CUBIC | bandwidthEstimate | 11.27 | ±13.3% |
| ACK | newAckHandlerCreate | 11.23 | ±13.5% |
| 流量控制 | streamFlowControllerNew | 299.9 | ±12.5% |
| 流 | sendStreamWriteSmall | 286.8 | ±5.3% |
| 核心 | packetPackerShortHeader | 651.4 | ±10.5% |
| 核心 | packetPackerLongHeader | 1801 | ±10.2% |
| 工具 | rttStatsUpdate | 46.16 | ±10.6% |
| PathManager | pathManagerMigrationDisabled | 62.68 | ±13.6% |
| Error 类型 | newProtocolViolationCreate | 52.59 | ±10.0% |

运行全部基准测试：
```bash
cjpm bench
```

完整基准结果请参阅 [README.md](../README.md#基准测试)。
