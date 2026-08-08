# Server + Client 组合示例

演示启动 HTTP 服务器并对其运行自动化客户端测试。

## 构建和运行

```bash
cd sample/combined
cjpm build
cjpm run
```

## 主要特性

- 提供多个端点的服务器：JSON、表单、多部分、回显
- 所有 HTTP 方法的自动化客户端测试
- 内存数据处理（无需文件系统）
- 通过/失败报告

```cangjie
let router = Router()
    .get("/", handleRoot).post("/echo", handleEcho)
let server = HttpServer({req => serveHTTP(req, router)})
spawn { server.listenAndServe("127.0.0.1", 9090) }
testAll(HttpClient(), "http://127.0.0.1:9090")
```

## 预期输出

示例在 `127.0.0.1:9090` 启动服务器，对所有端点运行客户端测试，并打印测试通过和失败的摘要。
