# Cookie 演示示例

演示 Cookie 的设置、读取和过滤功能。

## 构建和运行

```bash
cd sample/cookie_demo
cjpm build
cjpm run
```

## 主要特性

- 会话 Cookie（HttpOnly）、持久 Cookie（Max-Age）、路径限制 Cookie
- 通过 `req.cookie()` 从请求中读取 Cookie
- 基于路径和域名的 Cookie 过滤
- 使用 `HttpClientCookieJar` 的自动化客户端测试

```cangjie
resp.withCookie("cj-session", "abc123", httpOnly: true)
resp.withCookie("pref-theme", "dark", maxAge: Some(3600))
resp.withCookie("internal-token", "xyz789", path: "/restricted", httpOnly: true)
```

## 预期输出

示例在 `127.0.0.1:9091` 启动服务器，运行自动化 Cookie 测试，并打印通过/失败结果。
