# 故障排除指南
 
 本文档提供 quic_cj 使用过程中的常见问题及解决方案。
 
 ## 构建问题
 
 ### 编译失败：`cjc: command not found`
 
 确保已安装仓颉编译器并配置了 PATH：
 ```bash
 export PATH=/path/to/cangjie/bin:$PATH
 export CANGJIE_HOME=/path/to/cangjie
 ```
 
 ### 依赖解析失败：`jinguissl_core` 或 `jinguissl` 拉取失败
 
 确保网络可以访问 GitCode：
 ```bash
 git clone https://gitcode.com/changeden/JinguiCore.git
 ```
 如果使用代理，请正确配置：
 ```bash
 export http_proxy=http://proxy:port
 export https_proxy=http://proxy:port
 ```
 
 ### 首次构建很慢
 
 首次构建需要 30-60 秒编译依赖项。增量构建约 3-8 秒。
 
 ## 运行时问题
 
 ### 连接拨号失败
 
 可能原因及解决方案：
 
 1. **服务端未运行** — 确认目标地址和端口正确
 2. **防火墙阻止 UDP** — 检查防火墙规则，开放 UDP 端口
 3. **配置不兼容** — 确认客户端和服务端的 QUIC 版本匹配
 4. **TLS 证书问题** — 确认 `serverName` 配置正确
 
 ### 连接超时
 
 调整超时参数：
 ```cangjie
 let cfg = Config()
 cfg.handshakeIdleTimeoutMs = 10000  // 增加握手超时
 cfg.maxIdleTimeoutMs = 60000        // 增加空闲超时
 ```
 
 ### 流操作失败
 
 如果 `openStream()` 返回 `(stream, false)`：
 - 连接可能已关闭
 - 流数量已达上限（增加 `maxIncomingStreams`）
 - 连接尚处于握手阶段
 
 ### 内存占用过高
 
 调整窗口大小和流限制：
 ```cangjie
 let cfg = Config()
 cfg.maxIncomingStreams = 10
 cfg.initialStreamReceiveWindow = 65536      // 64 KB
 cfg.initialConnectionReceiveWindow = 262144 // 256 KB
 ```
 
 ## 测试问题
 
 ### 测试失败
 
 清理后重试：
 ```bash
 rm -rf target/release
 cjpm build
 cjpm test
 ```
 
 ### 特定测试失败
 
 如果某个模块的测试失败，可能是依赖版本不匹配：
 ```bash
 # 检查依赖版本
 cat cjpm.lock
 
 # 更新依赖
 cjpm update
 ```
 
 ## 更多帮助
 
 如果以上步骤不能解决您的问题，请：
 1. 查阅 [API 参考](api_reference.md) 确认使用方式
 2. 参考 [示例代码](../examples/) 检查实现
 3. 提交 Issue 到项目仓库
