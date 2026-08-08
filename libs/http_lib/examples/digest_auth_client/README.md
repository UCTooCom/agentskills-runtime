# 摘要认证客户端示例

演示 HTTP Digest 认证（RFC 7616），支持 MD5 和 SHA-256。

## 构建和运行

```bash
cd sample/digest_auth_client
cjpm build
cjpm run
```

## 主要特性

- 解析 `WWW-Authenticate` 挑战头
- 使用 `buildDigestAuthHeader()` 计算摘要响应
- 使用计算得到的 `Authorization` 头重试请求
- 支持 MD5 和 SHA-256 摘要算法

```cangjie
let params = parseDigestChallenge(challenge)
let authHeader = buildDigestAuthHeader(
    username, password, realm, nonce,
    HttpMethod.GET.toString(), "/digest-auth/auth/user/passwd/MD5",
    qop: Some("auth")
)
```

## 预期输出

示例向 httpbin.org 的摘要认证端点发送请求，解析 401 挑战，计算摘要响应，携带认证重试，并打印成功或失败信息。
