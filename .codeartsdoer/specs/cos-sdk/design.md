# COS SDK 实现方案文档

## 1. 系统上下文

### 1.1 系统定位

本项目是一个仓颉编程语言版本的腾讯云对象存储（COS）SDK，为仓颉应用提供访问腾讯云 COS 服务的能力。SDK 封装了 COS REST API 的调用细节，提供简洁的 API 接口供上层应用使用。

### 1.2 技术栈

| 层次 | 技术 | 版本 | 用途 |
| :--- | :--- | :--- | :--- |
| 语言 | 仓颉 | 1.0+ | 编程语言 |
| 包管理 | cjpm | - | 依赖管理和编译 |
| HTTP | std.net.http | - | HTTP 请求 |
| 加密 | stdx.crypto | - | HMAC-SHA1 签名 |
| 编码 | std.codec | - | Base64/URL 编码 |

### 1.3 依赖关系

```
┌─────────────────────────────────────────────────────────────┐
│                     上层应用 (Agent Skills)                  │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     CosClient (核心类)                       │
├───────────────────────────┬─────────────────────────────────┤
│  - putObject()            │  - getObject()                  │
│  - deleteObject()         │  - listObjects()                │
│  - preSignedUrl()         │  - multipartUpload()            │
└───────────────────────────┼─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   CosSigner   │   │   CosRequest  │   │   CosParser   │
│   (签名模块)   │   │   (请求模块)   │   │   (解析模块)   │
└───────────────┘   └───────────────┘   └───────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              腾讯云 COS REST API (XML API)                   │
└─────────────────────────────────────────────────────────────┘
```

## 2. 现有问题与设计目标

### 2.1 现有问题

- 腾讯云官方仅提供 Node.js、Java、Python 等语言的 SDK，缺乏仓颉版本
- 直接调用 REST API 需要处理复杂的签名逻辑和请求封装

### 2.2 设计目标

- 提供简洁易用的 COS 客户端 API
- 实现完整的签名认证机制
- 支持文件上传、下载、删除、查询等核心操作
- 支持分块上传和预签名 URL

## 3. 服务/组件总体架构

### 3.1 模块划分

| 模块 | 职责 | 文件位置 |
| :--- | :--- | :--- |
| client | COS 客户端入口类 | src/CosClient.cj |
| model | 请求/响应数据模型 | src/model/ |
| sign | 签名认证模块 | src/sign/CosSigner.cj |
| request | HTTP 请求封装 | src/request/CosRequest.cj |
| parser | 响应解析模块 | src/parser/CosParser.cj |
| error | 错误定义 | src/error/CosError.cj |

### 3.2 目录结构

```
cos-sdk/
├── cjpm.toml              # 包管理配置
├── src/
│   ├── CosClient.cj       # 客户端核心类
│   ├── CosClientConfig.cj # 客户端配置
│   ├── model/             # 数据模型
│   │   ├── PutObjectRequest.cj
│   │   ├── PutObjectResult.cj
│   │   ├── GetObjectRequest.cj
│   │   ├── GetObjectResult.cj
│   │   ├── DeleteObjectRequest.cj
│   │   ├── DeleteObjectResult.cj
│   │   ├── ListObjectsRequest.cj
│   │   ├── ListObjectsResult.cj
│   │   └── ObjectMetadata.cj
│   ├── sign/
│   │   └── CosSigner.cj   # 签名模块
│   ├── request/
│   │   └── CosRequest.cj  # HTTP 请求封装
│   ├── parser/
│   │   └── CosParser.cj   # 响应解析
│   └── error/
│       └── CosError.cj    # 错误定义
└── tests/
    └── CosClientTest.cj   # 单元测试
```

## 4. 实现设计文档

### 4.1 CosClient 类设计

**类路径：** `src/CosClient.cj`

**类职责：** 提供 COS 服务的客户端接口，封装所有 API 调用。

**核心方法：**

| 方法名 | 参数 | 返回值 | 功能 |
| :--- | :--- | :--- | :--- |
| constructor | config: CosClientConfig | CosClient | 构造函数 |
| putObject | request: PutObjectRequest | PutObjectResult | 上传对象 |
| getObject | request: GetObjectRequest | GetObjectResult | 下载对象 |
| deleteObject | request: DeleteObjectRequest | DeleteObjectResult | 删除对象 |
| listObjects | request: ListObjectsRequest | ListObjectsResult | 查询对象列表 |
| preSignedUrl | method: String, key: String, expires: Int | String | 生成预签名 URL |

**设计决策：**

| 决策 | 选项 | 理由 |
| :--- | :--- | :--- |
| 客户端类型 | 实例类 | 支持多实例，每个实例可配置不同密钥和区域 |
| 配置方式 | 构造函数注入 | 简洁明了，符合仓颉习惯 |
| 错误处理 | 异常抛出 | 便于上层统一处理 |

### 4.2 CosSigner 签名模块设计

**类路径：** `src/sign/CosSigner.cj`

**类职责：** 实现腾讯云 COS 请求签名机制。

**签名算法：**

1. 构造规范化请求字符串：
   ```
   HTTPMethod + "\n" +
   CanonicalURI + "\n" +
   CanonicalQueryString + "\n" +
   CanonicalHeaders + "\n" +
   SignedHeaders + "\n" +
   HexEncode(Hash(RequestPayload))
   ```

2. 构造字符串 ToSign：
   ```
   Algorithm + "\n" +
   RequestDate + "\n" +
   CredentialScope + "\n" +
   HexEncode(Hash(CanonicalRequest))
   ```

3. 使用 HMAC-SHA1 计算签名：
   ```
   kSecret = "COS" + SecretKey
   kDate = HMAC-SHA1(kSecret, Date)
   kRegion = HMAC-SHA1(kDate, Region)
   kService = HMAC-SHA1(kRegion, "cos")
   kSigning = HMAC-SHA1(kService, "request")
   Signature = HMAC-SHA1(kSigning, StringToSign)
   ```

**核心方法：**

| 方法名 | 参数 | 返回值 | 功能 |
| :--- | :--- | :--- | :--- |
| generateSignature | method: String, uri: String, headers: HashMap<String, String>, body: String, secretKey: String | String | 生成签名 |
| buildAuthorization | secretId: String, signature: String, date: String, credentialScope: String, signedHeaders: String | String | 构建 Authorization 头部 |

### 4.3 CosRequest HTTP 请求模块设计

**类路径：** `src/request/CosRequest.cj`

**类职责：** 封装 HTTP 请求的发送和响应处理。

**核心方法：**

| 方法名 | 参数 | 返回值 | 功能 |
| :--- | :--- | :--- | :--- |
| send | method: String, url: String, headers: HashMap<String, String>, body: String | HttpResponse | 发送 HTTP 请求 |
| buildUrl | bucket: String, key: String, region: String | String | 构建请求 URL |

**设计决策：**

| 决策 | 选项 | 理由 |
| :--- | :--- | :--- |
| URL 格式 | `{bucket}.cos.{region}.myqcloud.com/{key}` | 腾讯云 COS 标准域名格式 |
| 协议 | HTTPS | 安全传输 |

### 4.4 CosParser 响应解析模块设计

**类路径：** `src/parser/CosParser.cj`

**类职责：** 解析 COS API 的 XML 响应。

**核心方法：**

| 方法名 | 参数 | 返回值 | 功能 |
| :--- | :--- | :--- | :--- |
| parsePutObjectResult | xml: String | PutObjectResult | 解析上传结果 |
| parseGetObjectResult | response: HttpResponse | GetObjectResult | 解析下载结果 |
| parseListObjectsResult | xml: String | ListObjectsResult | 解析列表结果 |
| parseError | xml: String | CosError | 解析错误响应 |

### 4.5 数据模型设计

#### 4.5.1 CosClientConfig

```
CosClientConfig {
  secretId: String      // 必填
  secretKey: String     // 必填
  region: String        // 必填
  bucket: String?       // 可选
  protocol: String      // 默认 "https"
  timeout: Int          // 默认 60
}
```

#### 4.5.2 PutObjectRequest

```
PutObjectRequest {
  bucket: String              // 必填
  key: String                 // 必填
  body: Object                // 必填 (File/InputStream/String)
  contentType: String?        // 可选
  contentLength: Int?         // 可选
  acl: String?                // 可选
  metadata: HashMap<String, String>?  // 可选
}
```

#### 4.5.3 PutObjectResult

```
PutObjectResult {
  eTag: String           // 对象 ETag
  location: String       // 存储路径
  versionId: String?     // 版本 ID
}
```

#### 4.5.4 ListObjectsResult

```
ListObjectsResult {
  objects: Array<CosObject>
  name: String
  prefix: String
  marker: String
  maxKeys: Int
  isTruncated: Bool
  nextMarker: String?
}

CosObject {
  key: String
  lastModified: String
  eTag: String
  size: Int
  storageClass: String
}
```

## 5. 数据库与数据结构设计

本项目为纯 SDK 库，不涉及数据库设计。

## 6. API 接口设计

### 6.1 客户端接口

```
// 创建客户端
let client = CosClient {
  secretId: "AKIDxxxx",
  secretKey: "xxxx",
  region: "ap-guangzhou",
  bucket: "my-bucket"
}

// 上传文件
let result = client.putObject(PutObjectRequest {
  bucket: "my-bucket",
  key: "test.txt",
  body: "Hello COS",
  contentType: "text/plain"
})

// 下载文件
let result = client.getObject(GetObjectRequest {
  bucket: "my-bucket",
  key: "test.txt"
})

// 删除文件
let result = client.deleteObject(DeleteObjectRequest {
  bucket: "my-bucket",
  key: "test.txt"
})

// 列出对象
let result = client.listObjects(ListObjectsRequest {
  bucket: "my-bucket",
  prefix: "images/",
  maxKeys: 100
})

// 生成预签名 URL
let url = client.preSignedUrl("GET", "test.txt", 3600)
```

### 6.2 错误处理接口

```
CosError {
  code: String
  message: String
  requestId: String?
  resource: String?
}
```

## 7. 安全性设计

### 7.1 签名机制

- 使用 HMAC-SHA1 算法进行签名
- 密钥仅用于签名计算，不记录到日志
- 签名有效期可配置，默认 900 秒

### 7.2 传输安全

- 所有请求使用 HTTPS 协议
- 验证服务端证书

### 7.3 输入验证

- 验证 bucket 名称格式
- 验证 key 长度（最大 1024 字符）
- 防止路径遍历攻击

## 8. 性能优化设计

### 8.1 连接复用

- 使用 HTTP 连接池
- 保持长连接

### 8.2 分块上传

- 默认分块大小 1MB
- 支持并发上传
- 支持断点续传

### 8.3 内存优化

- 大文件使用流式处理
- 避免一次性加载整个文件到内存

## 9. 部署与集成方案

### 9.1 项目配置

**cjpm.toml 配置：**

```toml
[package]
name = "cos-sdk"
version = "1.0.0"
description = "腾讯云 COS 仓颉 SDK"
authors = ["uctoo"]

[lib]
name = "cos-sdk"
path = "src"
crate-type = ["dynamic"]

[dependencies]
std = "*"
stdx = "*"
```

### 9.2 集成方式

在项目的 cjpm.toml 中添加依赖：

```toml
[dependencies]
cos-sdk = { path = "../libs/cos-sdk" }
```

在代码中导入：

```cangjie
import cos_sdk::CosClient
import cos_sdk::model::{PutObjectRequest, GetObjectRequest}
```

## 10. 测试方案

### 10.1 单元测试

**测试用例：**

| 测试名称 | 测试内容 | 预期结果 |
| :--- | :--- | :--- |
| 签名生成 | 验证签名算法正确性 | 签名与预期一致 |
| URL 构建 | 验证 URL 格式 | 生成正确的 COS URL |
| XML 解析 | 验证响应解析 | 正确解析 XML 响应 |
| 错误处理 | 验证错误解析 | 正确解析错误响应 |

### 10.2 集成测试

**测试用例：**

| 测试名称 | 测试内容 | 预期结果 |
| :--- | :--- | :--- |
| 上传文本 | 上传字符串内容 | 返回成功，ETag 不为空 |
| 上传文件 | 上传本地文件 | 返回成功 |
| 下载对象 | 下载已上传对象 | 返回内容与上传一致 |
| 删除对象 | 删除对象后查询 | 返回空列表 |
| 查询列表 | 查询存储桶对象 | 返回对象列表 |
| 预签名 URL | 生成并验证 URL | URL 可正常访问 |

---

**版本**: 1.0.0  
**日期**: 2026-06-23  
**状态**: 已接受