# QUIC 回显服务器
 
 一个简单的回显服务器，监听 QUIC 连接，接收流并回显数据。
 
 ## 演示内容
 
 - 使用 `Transport` 和 `listen()` 监听传入的 QUIC 连接
 - 使用 `listener.accept()` 接收连接
 - 使用 `conn.acceptStream()` 接收双向流
 - 读取和写入流数据
 - 优雅地关闭连接
 
 ## 运行
 
 先启动回显服务器，再启动客户端。
 
 ```bash
 # 服务器
 cjpm run
 ```
