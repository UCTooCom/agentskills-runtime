# 基本 QUIC 库使用模式
 
 演示 quic_cj 库的核心 API 使用模式。
 涵盖配置、连接生命周期、流操作以及错误处理的基础用法。
 
 ## 关键概念
 
 - `Config` & `defaultConfig()` — 连接配置
 - `dial()` / `listen()` — 便捷入口函数
 - `Transport` — UDP 传输层管理
 - `Conn` — QUIC 连接句柄
 - `Stream` — 双向数据流
 - `QError` — 传输层/应用层错误
 
 ## 运行
 
 此示例作为参考代码使用，展示 API 使用模式。
 
 ```bash
 cjpm run
 ```
