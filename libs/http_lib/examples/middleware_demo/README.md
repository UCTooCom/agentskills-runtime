# 中间件演示示例

演示使用洋葱模型的组合式中间件链。

## 构建和运行

```bash
cd sample/middleware_demo
cjpm build
cjpm run
```

测试：`curl -v http://127.0.0.1:8082/`

## 主要特性

- 自定义中间件：请求 ID、响应计时、恐慌恢复
- 内置中间件：日志、安全头、HSTS、速率限制器
- 通过函数包装组合中间件
- 端点：/（信息）、/api（JSON）、/slow（500ms 延迟）、/error（触发恢复）

```cangjie
var handler = routeHandler
handler = loggingMiddleware()(handler)
handler = timingMiddleware()(handler)
handler = RateLimiter(maxRequests: 100).middleware()(handler)
handler = securityHeadersMiddleware()(handler)
handler = recoveryMiddleware()(handler)
```

## 预期输出

服务器在 8082 端口启动。响应头包括 X-Request-ID、X-Response-Time 和安全头。/error 端点演示恐慌恢复，返回 JSON 500 错误。
