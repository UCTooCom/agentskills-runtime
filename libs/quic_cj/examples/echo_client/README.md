# QUIC 回显客户端
 
 连接回显服务器的 QUIC 客户端，发送数据并验证回显响应。
 
 ## 演示内容
 
 - 使用 `dial()` 拨号连接到远程 QUIC 服务器
 - 使用 `conn.openStream()` 打开双向流
 - 使用 `stream.write()` / `stream.read()` 进行数据传输
 - 错误处理和连接生命周期管理
 
 ## 运行
 
 先启动回显服务器，再启动客户端：
 
 ```bash
 # 终端 1：启动服务器
 cd ../echo_server
 cjpm run
 
 # 终端 2：启动客户端
 cd ../echo_client
 cjpm run
 ```
