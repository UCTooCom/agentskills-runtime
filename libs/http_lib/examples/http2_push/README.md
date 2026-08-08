# HTTP/2 Server Push 示例

演示 HTTP/2 服务器推送，服务器在客户端请求之前主动发送资源。

## 构建和运行

```bash
cd sample/http2_push
cjpm build
cjpm run
```

测试：`curl --http2-prior-knowledge http://127.0.0.1:8083/ -v`

## 主要特性

- HTTP/2 PUSH_PROMISE 帧（RFC 7540 第 8.2 节）
- 服务器在发送 HTML 的同时推送 CSS 和 JS
- 为 HTTP/1.1 提供 Link rel=preload 回退
- 交错的 DATA 帧传输

## 预期输出

服务器在 8083 端口启动。当客户端请求根页面时，服务器使用 PUSH_PROMISE 帧主动推送 /style.css 和 /app.js。
