# COS SDK 需求规格文档

## 1. 核心职责

### 1.1 职责概述

本项目旨在开发一个仓颉编程语言版本的腾讯云对象存储（COS）SDK，为仓颉应用提供访问腾讯云对象存储服务的能力。SDK 应支持文件上传、下载、删除、查询等核心操作，并实现完整的签名认证机制。

### 1.2 核心能力清单

| 能力编号 | 能力名称 | 描述 | 来源 |
| :--- | :--- | :--- | :--- |
| CAP-001 | 对象上传 | 支持将文件或数据流上传到 COS 存储桶 | 腾讯云 COS API |
| CAP-002 | 对象下载 | 支持从 COS 存储桶下载文件到本地或读取到内存 | 腾讯云 COS API |
| CAP-003 | 对象删除 | 支持删除 COS 存储桶中的指定对象 | 腾讯云 COS API |
| CAP-004 | 对象查询 | 支持查询存储桶中的对象列表和对象元数据 | 腾讯云 COS API |
| CAP-005 | 签名认证 | 实现腾讯云 COS 请求签名机制（HMAC-SHA1） | 腾讯云 COS 签名规范 |
| CAP-006 | 分块上传 | 支持大文件分块上传 | 腾讯云 COS API |
| CAP-007 | 预签名 URL | 支持生成临时访问 URL | 腾讯云 COS API |

## 2. 输入输出规范

### 2.1 客户端初始化

**输入参数：**

| 参数名 | 类型 | 必填 | 描述 |
| :--- | :--- | :--- | :--- |
| secretId | String | 是 | 腾讯云 API SecretId |
| secretKey | String | 是 | 腾讯云 API SecretKey |
| region | String | 是 | COS 存储区域（如 ap-guangzhou） |
| bucket | String | 否 | 默认存储桶名称 |

**输出：**

| 返回值 | 类型 | 描述 |
| :--- | :--- | :--- |
| client | CosClient | COS 客户端实例 |

### 2.2 上传对象 (putObject)

**输入参数：**

| 参数名 | 类型 | 必填 | 描述 |
| :--- | :--- | :--- | :--- |
| bucket | String | 是 | 存储桶名称 |
| key | String | 是 | 对象键（文件路径） |
| body | File \| InputStream \| String | 是 | 上传内容 |
| contentType | String | 否 | Content-Type 类型 |
| contentLength | Int | 否 | 内容长度 |

**输出：**

| 返回值 | 类型 | 描述 |
| :--- | :--- | :--- |
| result | PutObjectResult | 上传结果 |

### 2.3 下载对象 (getObject)

**输入参数：**

| 参数名 | 类型 | 必填 | 描述 |
| :--- | :--- | :--- | :--- |
| bucket | String | 是 | 存储桶名称 |
| key | String | 是 | 对象键（文件路径） |

**输出：**

| 返回值 | 类型 | 描述 |
| :--- | :--- | :--- |
| result | GetObjectResult | 下载结果（包含数据流和元数据） |

### 2.4 删除对象 (deleteObject)

**输入参数：**

| 参数名 | 类型 | 必填 | 描述 |
| :--- | :--- | :--- | :--- |
| bucket | String | 是 | 存储桶名称 |
| key | String | 是 | 对象键（文件路径） |

**输出：**

| 返回值 | 类型 | 描述 |
| :--- | :--- | :--- |
| result | DeleteObjectResult | 删除结果 |

### 2.5 查询对象列表 (listObjects)

**输入参数：**

| 参数名 | 类型 | 必填 | 描述 |
| :--- | :--- | :--- | :--- |
| bucket | String | 是 | 存储桶名称 |
| prefix | String | 否 | 对象键前缀过滤 |
| marker | String | 否 | 分页标记 |
| maxKeys | Int | 否 | 最大返回数量 |

**输出：**

| 返回值 | 类型 | 描述 |
| :--- | :--- | :--- |
| result | ListObjectsResult | 对象列表结果 |

## 3. 职责边界

### 3.1 本项目负责

- 实现 COS API 请求的签名认证
- 封装 HTTP 请求与响应处理
- 提供简洁的客户端 API 接口
- 处理常见错误场景和异常

### 3.2 本项目不负责

- 存储桶的创建与管理（需通过腾讯云控制台或其他方式）
- 复杂的业务逻辑封装（如文件版本管理、生命周期规则）
- 图形化界面（纯 SDK 库，无 UI 组件）

## 4. 领域术语

| 术语 | 定义 |
| :--- | :--- |
| COS | Cloud Object Storage，腾讯云对象存储服务 |
| Bucket | 存储桶，COS 中用于存储对象的容器 |
| Object | 对象，COS 中的基本存储单元，即文件 |
| Key | 对象键，对象在存储桶中的唯一标识（文件路径） |
| Region | 存储区域，COS 的物理位置 |
| SecretId/SecretKey | 腾讯云 API 密钥，用于身份认证 |
| Signature | 签名，用于验证请求合法性的加密字符串 |
| ACL | Access Control List，访问控制列表 |
| ETag | 对象的实体标签，用于标识对象内容的哈希值 |

## 5. 角色与边界

### 5.1 用户角色

| 角色 | 职责 |
| :--- | :--- |
| SDK 用户 | 使用 COS SDK 进行文件上传、下载等操作 |
| 系统管理员 | 配置腾讯云 API 密钥和存储桶权限 |

### 5.2 外部依赖

| 依赖 | 说明 |
| :--- | :--- |
| 腾讯云 COS API | 本 SDK 需要调用腾讯云 COS REST API |
| 仓颉标准库 | 使用 std.net.http 进行 HTTP 请求 |
| 仓颉扩展库 | 使用 stdx.crypto 进行签名计算 |

## 6. DFX 约束

### 6.1 安全性

- 密钥（SecretId/SecretKey）仅用于签名计算，不记录日志
- 请求签名使用 HMAC-SHA1 算法，确保请求合法性
- 支持 HTTPS 协议，加密传输数据

### 6.2 性能

- 支持分块上传，优化大文件传输
- HTTP 连接复用，减少连接建立开销

### 6.3 可用性

- 提供错误码和错误信息，便于问题排查
- 支持重试机制，提高请求成功率

### 6.4 兼容性

- 兼容腾讯云 COS XML API
- 支持所有 COS 存储区域

## 7. 核心能力详细描述

### 7.1 CAP-001 对象上传

**业务规则：**
- 上传内容可以是文件、数据流或字符串
- 支持设置 Content-Type 和其他自定义头部
- 返回 ETag 和存储路径信息

**交互流程：**
1. 用户构造 PutObjectRequest
2. SDK 生成请求签名
3. 发送 HTTP PUT 请求到 COS
4. 解析响应，返回 PutObjectResult

### 7.2 CAP-002 对象下载

**业务规则：**
- 支持下载到文件或读取到内存
- 返回对象元数据（Content-Type、Content-Length 等）

**交互流程：**
1. 用户构造 GetObjectRequest
2. SDK 生成请求签名
3. 发送 HTTP GET 请求到 COS
4. 解析响应，返回 GetObjectResult（包含数据流）

### 7.3 CAP-003 对象删除

**业务规则：**
- 删除后不可恢复（除非开启版本控制）
- 返回删除状态

**交互流程：**
1. 用户构造 DeleteObjectRequest
2. SDK 生成请求签名
3. 发送 HTTP DELETE 请求到 COS
4. 解析响应，返回 DeleteObjectResult

### 7.4 CAP-004 对象查询

**业务规则：**
- 支持前缀过滤和分页查询
- 返回对象列表和存储桶信息

**交互流程：**
1. 用户构造 ListObjectsRequest
2. SDK 生成请求签名
3. 发送 HTTP GET 请求到 COS
4. 解析响应，返回 ListObjectsResult

### 7.5 CAP-005 签名认证

**业务规则：**
- 使用 HMAC-SHA1 算法计算签名
- 签名有效期默认 900 秒
- 支持临时密钥（STS）签名

**签名流程：**
1. 构造规范化请求字符串
2. 构造字符串 ToSign
3. 使用 SecretKey 进行 HMAC-SHA1 签名
4. 进行 Base64 编码

### 7.6 CAP-006 分块上传

**业务规则：**
- 分块大小默认 1MB
- 支持并发上传
- 支持断点续传

**交互流程：**
1. 初始化分块上传（InitiateMultipartUpload）
2. 上传分块（UploadPart）
3. 完成分块上传（CompleteMultipartUpload）

### 7.7 CAP-007 预签名 URL

**业务规则：**
- 支持 GET、PUT 等方法的预签名
- 可设置 URL 有效期
- 无需密钥即可访问

**交互流程：**
1. 用户指定方法、Key 和有效期
2. SDK 生成预签名 URL
3. 返回 URL 给用户使用

## 8. 数据模型

### 8.1 CosClientConfig（客户端配置）

| 字段 | 类型 | 必填 | 描述 |
| :--- | :--- | :--- | :--- |
| secretId | String | 是 | 腾讯云 API SecretId |
| secretKey | String | 是 | 腾讯云 API SecretKey |
| region | String | 是 | COS 存储区域 |
| bucket | String | 否 | 默认存储桶 |
| protocol | String | 否 | 协议（http/https），默认 https |
| timeout | Int | 否 | 请求超时时间（秒），默认 60 |

### 8.2 PutObjectRequest（上传请求）

| 字段 | 类型 | 必填 | 描述 |
| :--- | :--- | :--- | :--- |
| bucket | String | 是 | 存储桶名称 |
| key | String | 是 | 对象键 |
| body | Object | 是 | 上传内容（File/InputStream/String） |
| contentType | String | 否 | Content-Type |
| contentLength | Int | 否 | 内容长度 |
| acl | String | 否 | 访问控制（private/public-read 等） |

### 8.3 PutObjectResult（上传结果）

| 字段 | 类型 | 描述 |
| :--- | :--- | :--- |
| eTag | String | 对象的 ETag 值 |
| location | String | 对象存储路径 |
| versionId | String | 版本 ID（开启版本控制时） |

### 8.4 GetObjectRequest（下载请求）

| 字段 | 类型 | 必填 | 描述 |
| :--- | :--- | :--- | :--- |
| bucket | String | 是 | 存储桶名称 |
| key | String | 是 | 对象键 |

### 8.5 GetObjectResult（下载结果）

| 字段 | 类型 | 描述 |
| :--- | :--- | :--- |
| content | InputStream | 对象内容流 |
| contentType | String | Content-Type |
| contentLength | Int | 内容长度 |
| eTag | String | ETag 值 |
| lastModified | String | 最后修改时间 |

### 8.6 ListObjectsResult（列表结果）

| 字段 | 类型 | 描述 |
| :--- | :--- | :--- |
| objects | Array<Object> | 对象列表 |
| name | String | 存储桶名称 |
| prefix | String | 查询前缀 |
| marker | String | 分页标记 |
| maxKeys | Int | 最大返回数量 |
| isTruncated | Bool | 是否还有更多 |
| nextMarker | String | 下一页标记 |

## 9. 错误处理

### 9.1 错误码定义

| 错误码 | 描述 |
| :--- | :--- |
| CosError | 通用 COS 错误 |
| CosAuthError | 认证错误 |
| CosNotFoundError | 对象或存储桶不存在 |
| CosPermissionError | 权限不足 |
| CosNetworkError | 网络错误 |

### 9.2 错误结构

| 字段 | 类型 | 描述 |
| :--- | :--- | :--- |
| code | String | 错误码 |
| message | String | 错误消息 |
| requestId | String | 请求 ID（用于腾讯云排查） |
| resource | String | 资源路径 |

## 10. 非功能需求

### 10.1 性能要求

- 小文件（<1MB）上传响应时间 < 1s
- 大文件分块上传支持并发
- HTTP 连接池复用

### 10.2 可靠性要求

- 网络超时自动重试（最多 3 次）
- 分块上传支持断点续传
- 完善的错误处理和日志记录

### 10.3 可维护性要求

- 代码结构清晰，遵循仓颉编码规范
- 提供完整的 API 文档
- 单元测试覆盖率 > 80%

---

**版本**: 1.0.0  
**日期**: 2026-06-23  
**状态**: 已接受