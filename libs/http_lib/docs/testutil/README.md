 # Testutil 文档

 
 ## 概述

 `testutil` 模块提供 HTTP 服务的测试工具，包括测试服务器和响应记录器，
 用于编写集成测试和单元测试。

 ## 快速参考

 ```cangjie
 import http_lib.testutil.*
 ```

 ## TestServer

 完整的 HTTP 测试服务器，在随机端口上启动真实 HTTP 服务，用于集成测试：

 ```cangjie
 import http_lib.testutil.TestServer

 let server = TestServer(handler)
 server.start()  // 在随机端口启动
 let port = server.port()  // 获取实际端口

 // 发送测试请求
 let resp = server.get("/test")
 assertTrue(resp.status.code == 200)

 // 清理
 server.stop()
 ```

 TestServer 特性：
 - 自动分配随机端口，避免端口冲突
 - 完整的 HTTP 请求/响应周期
 - 支持自定义处理器和配置

 ## ResponseRecorder

 响应记录器，捕获处理器返回的 `HttpResponse` 供测试断言：

 ```cangjie
 let handler = {req: HttpRequest => HttpResponse.text(HttpStatus.OK, "hello")}
 let recorder = ResponseRecorder(handler)

 recorder.serve(HttpRequest(url: "/test"))

 assertTrue(recorder.code() == 200u16)
 assertTrue(recorder.bodyAsString() == "hello")

 // 检查响应头
 match (recorder.header("content-type")) {
     case Some(ct) => println("Content-Type: ${ct}")
     case None => ()
 }

 // 检查是否有 handler 错误
 assertFalse(recorder.hasError())
 ```

 在 handler 抛出异常时，记录器会捕获异常而非崩溃：

 ```cangjie
 let handler = {req => throw Exception("intentional")}
 let recorder = ResponseRecorder(handler)

 recorder.serve(HttpRequest(url: "/test"))
 assertTrue(recorder.hasError())
 assertTrue(recorder.code() == 0u16)
 ```

 ## 注意事项

 - `TestServer` 启动真实 TCP 服务，测试完成后务必调用 `stop()`
 - `ResponseRecorder` 仅记录最近一次 `serve()` 调用的结果
 - 如果 handler 抛出异常，`code()` 返回 0，`bodyAsString()` 返回空字符串
 - TestServer 的端口是运行时分配的，通过 `port()` 获取
