# JinguiSSL Contract 示例目录

本目录包含各个模块的完整使用示例。每个子目录为一个独立的 cjpm 项目，可直接编译运行。

## 示例列表

| 子目录 | 模块 | 说明 |
|--------|------|------|
| [basic](basic/) | facade 元数据 | 获取 contract facade 信息与能力概览 |
| [digest](digest/) | Digest / HMAC / HKDF | SHA-256/384/512 摘要、HMAC、HKDF 密钥派生 |
| [chacha20](chacha20/) | ChaCha20-Poly1305 | AEAD 流加密与解密 (RFC 8439) |
| [x25519](x25519/) | X25519 密钥协商 | 密钥对生成、公钥推导、密钥协商 (RFC 7748) |
| [x509](x509/) | X.509 证书链验证 | 证书链验证、指纹计算、TLS 信任材料准备 |
| [aes](aes/) | AES 后端探测 | 硬件挂载点探测、引擎解析、release plan |
| [sm](sm/) | 国密 SM3/SM4 | 中国国家密码标准能力探测 |
| [http_tls](http_tls/) | HTTP/TLS 启动材料 | TLS 配置验证与启动材料整理 |
| [ssh](ssh/) | SSH 启动捆绑包 | KEX 握手输入、主机验证策略 |
| [quic](quic/) | QUIC 初始密钥派生 | v1/v2 初始密钥派生、Header Protection、Retry 完整性 |
| [provider-gate](provider-gate/) | 提供商门禁 | 错误描述、降级决策、消费路径 |
| [tls-session-cache](tls-session-cache/) | TLS 会话缓存 | 有限容量 LRU 缓存 |
| [tls-client](tls-client/) | TLS 客户端 | HTTP 客户端 TLS 启动材料与 session attach |
| [tls-server](tls-server/) | TLS 服务端 | HTTP 服务端 TLS 启动材料与 session attach |
| [hmac-hkdf](hmac-hkdf/) | HMAC/HKDF | HMAC 消息认证码与 HKDF 密钥派生 |
| [ecc](ecc/) | ECC 能力探测 | 椭圆曲线密码学曲线与 FIPS 合规探测 |
| [ed25519](ed25519/) | Ed25519 签名探测 | Ed25519 签名能力与密钥尺寸探测 |
| [kem](kem/) | KEM 密钥封装 | 密钥封装机制 (PQ 储备) 探测 |
| [rsa](rsa/) | RSA 能力探测 | RSA 密钥尺寸、签名方案、哈希算法探测 |
| [contract-application-smoke](contract-application-smoke/) | 应用级集成冒烟 | 独立应用消费 JinguiSSL contract facade 冒烟验证 |

## 编译与运行

每个示例都是独立的 cjpm 项目：

```bash
cd examples/<场景名称>
cjpm build
cjpm run
```

## 依赖

所有示例通过 `{ path = "../.." }` 引入当前仓库的 JinguiSSL contract facade。
