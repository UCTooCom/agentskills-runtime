# ystyle::jsonrpc

JSON-RPC 2.0 通用框架（仓颉语言）

## 安装

```toml
[dependencies]
  "ystyle::jsonrpc" = "0.1.0"
  # 按需选择传输层
  "ystyle::jsonrpc_stdio" = "0.1.0"      # Stdio
  "ystyle::jsonrpc_tcp" = "0.1.0"        # TCP
  "ystyle::jsonrpc_unix" = "0.1.0"       # Unix Socket
  "ystyle::jsonrpc_http" = "0.1.0"       # HTTP POST
  "ystyle::jsonrpc_websocket" = "0.1.0"  # WebSocket
```

## 快速开始

### 服务端

```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_stdio.*

main() {
    let transport = StdioTransport()
    let server = JsonRpcServer(transport)
    
    server.register("echo", { ctx =>
        HandlerResult.ok(ctx.getRawParams() ?? JsonValue.Null)
    })
    
    server.start()
}
```

### 客户端

```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_stdio.*

main() {
    let transport = StdioTransport()
    let client = JsonRpcClient(transport)
    client.start()
    
    let result = client.call<JsonValue, JsonValue>("echo",
        params: Some(JsonValue.Map(HashMap<String, JsonValue>())))
    match (result) {
        case Ok(v) => println(v.stringify())
        case Err(e) => println("错误: ${e}")
    }
    
    client.close()
}
```

## 传输层

| 包 | 类 | 用途 |
|------|------|------|
| jsonrpc_stdio | StdioTransport | LSP、进程管道 |
| jsonrpc_tcp | TcpClientTransport / TcpServerTransport | 网络服务 |
| jsonrpc_unix | UnixClientTransport / UnixServerTransport | 本地高性能通信 |
| jsonrpc_http | HttpClientTransport / HttpRpcHandler / HttpRpcHelper | HTTP POST 短连接 |
| jsonrpc_websocket | WebSocketClientTransport / WebSocketServerHandler | WebSocket 长连接 |

### TCP

服务端：
```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_tcp.*

main() {
    let server = TcpServerTransport(port: 8080)
    while (let Some(conn) <- server.acceptConnection()) {
        let rpc = JsonRpcServer(conn)
        rpc.register("echo", { ctx =>
            HandlerResult.ok(ctx.getRawParams() ?? JsonValue.Null)
        })
        rpc.start()
    }
}
```

客户端：
```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_tcp.*

main() {
    let transport = TcpClientTransport("127.0.0.1", 8080)
    let client = JsonRpcClient(transport)
    client.start()
    
    let result = client.call<JsonValue, JsonValue>("echo",
        params: Some(JsonValue.Map(HashMap<String, JsonValue>())))
    // ...
    client.close()
}
```

### Unix Socket

服务端：
```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_unix.*

main() {
    let server = UnixServerTransport(path: "/tmp/rpc.sock")
    while (let Some(conn) <- server.acceptConnection()) {
        let rpc = JsonRpcServer(conn)
        rpc.register("echo", { ctx =>
            HandlerResult.ok(ctx.getRawParams() ?? JsonValue.Null)
        })
        rpc.start()
    }
}
```

客户端：
```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_unix.*

main() {
    let transport = UnixClientTransport(path: "/tmp/rpc.sock")
    let client = JsonRpcClient(transport)
    client.start()
    // ...
    client.close()
}
```

### HTTP POST

集成到现有 HTTP Server：
```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_http.*
import stdx.net.http.*

let httpServer = ServerBuilder().addr("0.0.0.0").port(8080).build()
let rpcServer = JsonRpcServer(/* transport 由 handler 内部处理 */)
rpcServer.register("echo", { ctx => HandlerResult.ok(ctx.getRawParams() ?? JsonValue.Null) })

httpServer.route("/rpc", HttpRpcHandler(rpcServer))
httpServer.start()
```

客户端（复用现有 HTTP Client）：
```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_http.*
import stdx.net.http.*

let httpClient = ClientBuilder().build()
let transport = HttpClientTransport(httpClient, "http://localhost:8080/rpc")
let rpcClient = JsonRpcClient(transport)
rpcClient.start()
```

### WebSocket 长连接

服务端（集成到现有 HTTP Server）：
```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_websocket.*
import stdx.net.http.*

let httpServer = ServerBuilder().addr("0.0.0.0").port(8080).build()
let rpcServer = JsonRpcServer(/* transport 由 handler 内部处理 */)
rpcServer.register("echo", { ctx => HandlerResult.ok(ctx.getRawParams() ?? JsonValue.Null) })

httpServer.route("/ws", WebSocketServerHandler(rpcServer))
httpServer.start()
```

客户端：
```cangjie
import ystyle::jsonrpc.*
import ystyle::jsonrpc_websocket.*
import stdx.net.http.*

let httpClient = ClientBuilder().build()
let transport = WebSocketClientTransport.connect(httpClient, "ws://localhost:8080/ws")
let rpcClient = JsonRpcClient(transport)
rpcClient.start()
```

## API

### JsonRpcServer

| 方法 | 说明 |
|------|------|
| `register(method, handler)` | 注册方法处理器 |
| `use(middleware)` | 添加中间件 |
| `start()` | 启动服务（后台线程，非阻塞） |
| `serve()` | 启动服务（当前线程，阻塞至 close） |
| `close()` | 关闭服务 |

### JsonRpcClient

| 方法 | 说明 |
|------|------|
| `call<T, R>(method, params)` | 同步调用，返回 `Result<R>` |
| `notify<T>(method, params)` | 发送通知（无响应） |
| `start()` | 启动客户端 |
| `close()` | 关闭客户端 |

### HandlerContext

| 方法 | 说明 |
|------|------|
| `getParam(key)` | 获取单个参数 |
| `getParamAs<T>(key)` | 获取并转换类型 |
| `getParams<T>()` | 获取整个参数对象 |
| `getRawParams()` | 获取原始 JsonValue |

### HandlerResult

| 方法 | 说明 |
|------|------|
| `ok<T>(value)` | 返回成功结果 |
| `err(code, message)` | 返回错误 |

### Result

| 成员 | 说明 |
|------|------|
| `Ok(value)` | 成功结果 |
| `Err(message)` | 错误信息 |

## 错误码

| 常量 | 代码 |
|------|------|
| ErrorCodes.PARSE_ERROR | -32700 |
| ErrorCodes.INVALID_REQUEST | -32600 |
| ErrorCodes.METHOD_NOT_FOUND | -32601 |
| ErrorCodes.INVALID_PARAMS | -32602 |
| ErrorCodes.INTERNAL_ERROR | -32603 |

## 文档

- [设计文档](docs/design.md)
- [性能基准报告](docs/performance.md)（gjson 快速路由 + 流式直连反序列化）
- [进度追踪](docs/progress-tracking.md)

## License

MIT