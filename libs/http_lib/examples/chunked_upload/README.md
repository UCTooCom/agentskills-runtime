# 分块上传示例

演示使用分块传输编码发送 HTTP 请求体。

## 构建和运行

```bash
cd sample/chunked_upload
cjpm build
cjpm run
```

## 主要特性

本示例展示如何使用 `ChunkedWriter.encodeChunked()` 将数据编码为分块格式，并通过 `HttpClient` 发送。分块传输编码适用于流式上传大文件或内容总大小未知的场景。

```cangjie
let msg = unsafe { "Hello, this is a chunked message!".rawData() }
let chunkedData = ChunkedWriter.encodeChunked(msg)

let req2 = HttpRequestBuilder()
    .post()
    .withUrl("https://httpbin.org/post")
    .withBody(chunkedData)
    .withHeader("Transfer-Encoding", "chunked")
    .build()
```

## 预期输出

示例发送一个分块 POST 请求到 httpbin.org，并打印响应状态码和响应体大小。
