## Package http
- [Package http](#package-http)
  - [概述](#概述)
  - [实现方式](#实现方式)
  - [struct HttpUtils](#struct-httputils)
    - [func get](#func-get)
    - [func post](#func-post)
    - [func asyncGet](#func-asyncget)
    - [func asyncPost](#func-asyncpost)
    - [func hybridPost](#func-hybridpost)
    - [func sseConnect](#func-sseconnect)
  - [class HttpStream](#class-httpstream)
    - [func next](#func-next)
    - [func read](#func-read)
    - [func close](#func-close)
  - [class HttpResult](#class-httpresult)
    - [func isSuccess](#func-issuccess)
    - [func isAccepted](#func-isaccepted)
    - [func isNotFound](#func-isnotfound)
    - [func isBadRequest](#func-isbadrequest)
  - [enum HttpResultOption](#enum-httpresultoption)
  - [class HttpException](#class-httpexception)
  - [使用示例](#使用示例)
    - [同步 GET 请求](#同步-get-请求)
    - [同步 POST 请求](#同步-post-请求)
    - [异步流式请求](#异步流式请求)
    - [混合请求](#混合请求)

---

### 概述

`magic.utils.http` 包提供了 HTTP 客户端功能，支持同步请求、异步流式请求和 Server-Sent Events (SSE) 连接。该包封装了底层 HTTP 实现，提供统一的 API 接口，方便在 Agent Skills Runtime 中进行网络请求。

**主要功能：**
- 同步 HTTP GET/POST 请求
- 异步流式 HTTP 请求（适用于大模型流式响应）
- 混合请求（自动判断响应类型）
- SSE (Server-Sent Events) 连接支持
- 支持 HTTPS 和证书验证控制

---

### 实现方式

该包提供两种底层实现，通过编译条件自动选择：

| 实现文件 | 条件 | 说明 |
|---------|------|------|
| `http_cj.cj` | `http != "curl"` | 使用仓颉标准库 `stdx.net.http` 实现 |
| `http_curl.cj` | `http == "curl"` | 使用 curl 命令行工具实现 |

**推荐使用仓颉标准库实现**，curl 实现主要用于兼容性场景。

---

### struct HttpUtils

HTTP 工具类，提供静态方法进行 HTTP 请求。

#### func get

```cangjie
static func get(url: String,
                header: HashMap<String, String>,
                body: Option<JsonObject>,
                verify!: Bool = false): Option<String>
```

- **Description**: 发送同步 HTTP GET 请求
- **Parameters**:
  - `url`: `String`, 请求的 URL 地址
  - `header`: `HashMap<String, String>`, 请求头
  - `body`: `Option<JsonObject>`, 请求体（可选）
  - `verify`: `Bool`, 是否验证 SSL 证书，默认 `false`
- **Returns**: `Option<String>`, 响应内容，失败返回 `None`

#### func post

```cangjie
static func post(url: String,
                 header: HashMap<String, String>,
                 body: JsonObject,
                 verify!: Bool = false): Option<String>
```

- **Description**: 发送同步 HTTP POST 请求
- **Parameters**:
  - `url`: `String`, 请求的 URL 地址
  - `header`: `HashMap<String, String>`, 请求头
  - `body`: `JsonObject`, 请求体（JSON 格式）
  - `verify`: `Bool`, 是否验证 SSL 证书，默认 `false`
- **Returns**: `Option<String>`, 响应内容，失败返回 `None`

#### func asyncGet

```cangjie
static func asyncGet(url: String,
                     header: HashMap<String, String>,
                     body: Option<JsonObject>,
                     verify!: Bool = false): HttpStream
```

- **Description**: 发送异步 HTTP GET 请求，返回流式响应
- **Parameters**:
  - `url`: `String`, 请求的 URL 地址
  - `header`: `HashMap<String, String>`, 请求头
  - `body`: `Option<JsonObject>`, 请求体（可选）
  - `verify`: `Bool`, 是否验证 SSL 证书，默认 `false`
- **Returns**: `HttpStream`, 流式响应对象

#### func asyncPost

```cangjie
static func asyncPost(url: String,
                      header: HashMap<String, String>,
                      body: JsonObject,
                      verify!: Bool = false): HttpStream
```

- **Description**: 发送异步 HTTP POST 请求，返回流式响应
- **Parameters**:
  - `url`: `String`, 请求的 URL 地址
  - `header`: `HashMap<String, String>`, 请求头
  - `body`: `JsonObject`, 请求体（JSON 格式）
  - `verify`: `Bool`, 是否验证 SSL 证书，默认 `false`
- **Returns**: `HttpStream`, 流式响应对象

#### func hybridPost

```cangjie
static func hybridPost(url: String,
                       header: HashMap<String, String>,
                       body: JsonObject,
                       verify!: Bool = false): HttpResult
```

- **Description**: 发送混合 HTTP POST 请求，根据响应头自动判断返回类型
- **Parameters**:
  - `url`: `String`, 请求的 URL 地址
  - `header`: `HashMap<String, String>`, 请求头
  - `body`: `JsonObject`, 请求体（JSON 格式）
  - `verify`: `Bool`, 是否验证 SSL 证书，默认 `false`
- **Returns**: `HttpResult`, HTTP 结果对象，包含状态码、响应头和响应内容
- **Note**: 如果响应头包含 `text/event-stream`，返回流式响应；否则返回 JSON 字符串

#### func sseConnect

```cangjie
static func sseConnect(url: String, verify!: Bool = false): SSEventStream
```

- **Description**: 建立 Server-Sent Events (SSE) 连接
- **Parameters**:
  - `url`: `String`, SSE 端点的 URL 地址
  - `verify`: `Bool`, 是否验证 SSL 证书，默认 `false`
- **Returns**: `SSEventStream`, SSE 事件流对象

---

### class HttpStream

HTTP 流式响应类，实现 `Iterator<String>` 和 `InputStream` 接口，用于处理流式 HTTP 响应。

#### func next

```cangjie
override public func next(): Option<String>
```

- **Description**: 获取流中的下一行数据
- **Returns**: `Option<String>`, 下一行字符串，流结束时返回 `None`

#### func read

```cangjie
override public func read(buffer: Array<Byte>): Int64
```

- **Description**: 从流中读取字节数据到缓冲区
- **Parameters**:
  - `buffer`: `Array<Byte>`, 目标缓冲区
- **Returns**: `Int64`, 实际读取的字节数，流结束时返回 0

#### func close

```cangjie
public func close(): Unit
```

- **Description**: 关闭流并释放资源

---

### class HttpResult

HTTP 请求结果类，包含状态码、响应头和响应内容。

#### func isSuccess

```cangjie
public func isSuccess(): Bool
```

- **Description**: 判断 HTTP 状态码是否为成功（200-299）
- **Returns**: `Bool`, 状态码在 200-299 范围内返回 `true`

#### func isAccepted

```cangjie
public func isAccepted(): Bool
```

- **Description**: 判断 HTTP 状态码是否为 202 Accepted
- **Returns**: `Bool`, 状态码为 202 返回 `true`

#### func isNotFound

```cangjie
public func isNotFound(): Bool
```

- **Description**: 判断 HTTP 状态码是否为 404 Not Found
- **Returns**: `Bool`, 状态码为 404 返回 `true`

#### func isBadRequest

```cangjie
public func isBadRequest(): Bool
```

- **Description**: 判断 HTTP 状态码是否为 400 Bad Request
- **Returns**: `Bool`, 状态码为 400 返回 `true`

---

### enum HttpResultOption

HTTP 结果选项枚举，表示响应内容的类型。

```cangjie
public enum HttpResultOption {
    | Json(String)      // JSON 字符串响应
    | Stream(HttpStream) // 流式响应
}
```

---

### class HttpException

HTTP 异常类，继承自 `Exception`，用于表示 HTTP 请求过程中的错误。

```cangjie
protected class HttpException <: Exception {
    protected HttpException(protected let error: String)
}
```

---

### 使用示例

#### 同步 GET 请求

```cangjie
import magic.utils.http.HttpUtils
import std.collection.HashMap

let header = HashMap<String, String>()
header.add("Authorization", "Bearer your_token")

let response = HttpUtils.get(
    "https://api.example.com/data",
    header,
    None
)

match (response) {
    case Some(data) => println("Response: ${data}")
    case None => println("Request failed")
}
```

#### 同步 POST 请求

```cangjie
import magic.utils.http.HttpUtils
import std.collection.HashMap
import stdx.encoding.json.JsonObject

let header = HashMap<String, String>()
header.add("Content-Type", "application/json")

let body = JsonObject()
body.put("query", "Hello")

let response = HttpUtils.post(
    "https://api.example.com/chat",
    header,
    body
)
```

#### 异步流式请求

```cangjie
import magic.utils.http.HttpUtils
import std.collection.HashMap
import stdx.encoding.json.JsonObject

let header = HashMap<String, String>()
header.add("Content-Type", "application/json")

let body = JsonObject()
body.put("messages", messages)

let stream = HttpUtils.asyncPost(
    "https://api.example.com/chat/completions",
    header,
    body
)

// 迭代处理流式响应
while (let Some(line) <- stream.next()) {
    println("Received: ${line}")
}
```

#### 混合请求

```cangjie
import magic.utils.http.{HttpUtils, HttpResultOption}
import std.collection.HashMap
import stdx.encoding.json.JsonObject

let header = HashMap<String, String>()
header.add("Content-Type", "application/json")

let body = JsonObject()
body.put("prompt", "Hello")

let result = HttpUtils.hybridPost(
    "https://api.example.com/completions",
    header,
    body
)

if (result.isSuccess()) {
    match (result.value) {
        case HttpResultOption.Json(json) =>
            println("JSON Response: ${json}")
        case HttpResultOption.Stream(stream) =>
            // 处理流式响应
            while (let Some(line) <- stream.next()) {
                println("Stream: ${line}")
            }
    }
}
```

---

### 配置项

HTTP 客户端行为可通过以下配置项控制（在 `Config` 中定义）：

| 配置项 | 说明 | 默认值 |
|-------|------|-------|
| `httpConnectTimeout` | HTTP 连接超时时间（毫秒） | - |
| `httpReadWriteTimeout` | HTTP 读写超时时间（毫秒） | - |
| `modelRequestDir` | 临时请求文件存储目录 | - |
| `saveModelRequest` | 是否保存模型请求记录 | `false` |

---

### 注意事项

1. **SSL 证书验证**: 默认不验证 SSL 证书（`verify: false`），适用于开发环境。生产环境建议启用验证。

2. **流式响应**: 使用 `asyncPost` 或 `asyncGet` 时，响应会在后台线程中处理，主线程可以迭代读取数据。

3. **超时处理**: HTTP 请求有默认的超时时间，可通过配置项调整。

4. **错误处理**: 所有 HTTP 错误会抛出 `HttpException` 异常，建议使用 try-catch 捕获。

5. **代理支持**: 当前版本暂不支持 HTTP 代理配置，相关代码已注释保留。
