# COS SDK 编码任务规划

## 1. 任务概述

本文档规划了 COS SDK 的编码任务，按照规范驱动开发流程，分阶段实现各个模块。

## 2. 任务总览

| 阶段 | 任务数 | 优先级 | 预计工时 |
| :--- | :--- | :--- | :--- |
| 阶段一：项目基础设施 | 2 | 高 | 2h |
| 阶段二：数据模型 | 8 | 高 | 4h |
| 阶段三：签名认证 | 1 | 高 | 4h |
| 阶段四：HTTP 请求 | 1 | 高 | 2h |
| 阶段五：响应解析 | 1 | 高 | 2h |
| 阶段六：客户端核心 | 1 | 高 | 4h |
| 阶段七：API 方法 | 5 | 高 | 6h |
| 阶段八：错误处理 | 1 | 高 | 1h |
| 阶段九：测试验证 | 1 | 中 | 4h |

## 3. 阶段一：项目基础设施

### 任务 1.1：创建项目目录结构

**关联需求：** design.md - 目录结构

**优先级：** 高

**复杂度：** 低

**依赖：** 无

**涉及文件：**
- 创建 `libs/cos-sdk/` 目录
- 创建 `libs/cos-sdk/src/` 目录
- 创建 `libs/cos-sdk/src/model/` 目录
- 创建 `libs/cos-sdk/src/sign/` 目录
- 创建 `libs/cos-sdk/src/request/` 目录
- 创建 `libs/cos-sdk/src/parser/` 目录
- 创建 `libs/cos-sdk/src/error/` 目录
- 创建 `libs/cos-sdk/tests/` 目录

**验收标准：**
- 所有目录创建成功
- 目录结构符合设计文档

### 任务 1.2：配置 cjpm.toml

**关联需求：** design.md - 项目配置

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 1.1

**涉及文件：**
- `libs/cos-sdk/cjpm.toml`

**验收标准：**
- cjpm.toml 配置正确
- 依赖声明完整

## 4. 阶段二：数据模型

### 任务 2.1：实现 CosClientConfig

**关联需求：** spec.md - CosClientConfig

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 1.2

**涉及文件：**
- `libs/cos-sdk/src/CosClientConfig.cj`

**验收标准：**
- 包含所有必要字段（secretId、secretKey、region、bucket、protocol、timeout）
- 默认值设置正确

### 任务 2.2：实现 PutObjectRequest

**关联需求：** spec.md - PutObjectRequest

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 2.1

**涉及文件：**
- `libs/cos-sdk/src/model/PutObjectRequest.cj`

**验收标准：**
- 包含所有必要字段（bucket、key、body、contentType、contentLength、acl、metadata）

### 任务 2.3：实现 PutObjectResult

**关联需求：** spec.md - PutObjectResult

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 2.2

**涉及文件：**
- `libs/cos-sdk/src/model/PutObjectResult.cj`

**验收标准：**
- 包含所有必要字段（eTag、location、versionId）

### 任务 2.4：实现 GetObjectRequest

**关联需求：** spec.md - GetObjectRequest

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 2.3

**涉及文件：**
- `libs/cos-sdk/src/model/GetObjectRequest.cj`

**验收标准：**
- 包含所有必要字段（bucket、key）

### 任务 2.5：实现 GetObjectResult

**关联需求：** spec.md - GetObjectResult

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 2.4

**涉及文件：**
- `libs/cos-sdk/src/model/GetObjectResult.cj`

**验收标准：**
- 包含所有必要字段（content、contentType、contentLength、eTag、lastModified）

### 任务 2.6：实现 DeleteObjectRequest 和 DeleteObjectResult

**关联需求：** spec.md - DeleteObjectRequest/Result

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 2.5

**涉及文件：**
- `libs/cos-sdk/src/model/DeleteObjectRequest.cj`
- `libs/cos-sdk/src/model/DeleteObjectResult.cj`

**验收标准：**
- DeleteObjectRequest 包含 bucket、key
- DeleteObjectResult 包含 statusCode

### 任务 2.7：实现 ListObjectsRequest 和 ListObjectsResult

**关联需求：** spec.md - ListObjectsRequest/Result

**优先级：** 高

**复杂度：** 中

**依赖：** 任务 2.6

**涉及文件：**
- `libs/cos-sdk/src/model/ListObjectsRequest.cj`
- `libs/cos-sdk/src/model/ListObjectsResult.cj`
- `libs/cos-sdk/src/model/CosObject.cj`

**验收标准：**
- ListObjectsRequest 包含 bucket、prefix、marker、maxKeys
- ListObjectsResult 包含 objects、name、prefix、marker、maxKeys、isTruncated、nextMarker

### 任务 2.8：实现 ObjectMetadata

**关联需求：** spec.md - ObjectMetadata

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 2.7

**涉及文件：**
- `libs/cos-sdk/src/model/ObjectMetadata.cj`

**验收标准：**
- 支持常见元数据字段

## 5. 阶段三：签名认证

### 任务 3.1：实现 CosSigner

**关联需求：** spec.md - CAP-005 签名认证

**优先级：** 高

**复杂度：** 高

**依赖：** 任务 2.8

**涉及文件：**
- `libs/cos-sdk/src/sign/CosSigner.cj`

**验收标准：**
- 实现 generateSignature 方法
- 实现 buildAuthorization 方法
- 签名算法正确（HMAC-SHA1）
- 支持临时密钥签名

## 6. 阶段四：HTTP 请求

### 任务 4.1：实现 CosRequest

**关联需求：** spec.md - HTTP 请求封装

**优先级：** 高

**复杂度：** 中

**依赖：** 任务 3.1

**涉及文件：**
- `libs/cos-sdk/src/request/CosRequest.cj`

**验收标准：**
- 实现 send 方法，支持 GET/PUT/DELETE 等方法
- 实现 buildUrl 方法
- 支持 HTTPS
- 支持自定义请求头

## 7. 阶段五：响应解析

### 任务 5.1：实现 CosParser

**关联需求：** spec.md - 响应解析

**优先级：** 高

**复杂度：** 中

**依赖：** 任务 4.1

**涉及文件：**
- `libs/cos-sdk/src/parser/CosParser.cj`

**验收标准：**
- 实现 parsePutObjectResult 方法
- 实现 parseGetObjectResult 方法
- 实现 parseListObjectsResult 方法
- 实现 parseError 方法

## 8. 阶段六：客户端核心

### 任务 6.1：实现 CosClient

**关联需求：** spec.md - CosClient

**优先级：** 高

**复杂度：** 中

**依赖：** 任务 5.1

**涉及文件：**
- `libs/cos-sdk/src/CosClient.cj`

**验收标准：**
- 构造函数接收 CosClientConfig
- 初始化 CosSigner、CosRequest、CosParser
- 提供客户端配置访问方法

## 9. 阶段七：API 方法

### 任务 7.1：实现 putObject 方法

**关联需求：** spec.md - CAP-001 对象上传

**优先级：** 高

**复杂度：** 中

**依赖：** 任务 6.1

**涉及文件：**
- `libs/cos-sdk/src/CosClient.cj`

**验收标准：**
- 支持字符串上传
- 支持文件上传
- 返回 PutObjectResult
- 处理异常

### 任务 7.2：实现 getObject 方法

**关联需求：** spec.md - CAP-002 对象下载

**优先级：** 高

**复杂度：** 中

**依赖：** 任务 7.1

**涉及文件：**
- `libs/cos-sdk/src/CosClient.cj`

**验收标准：**
- 支持下载到内存
- 支持下载到文件
- 返回 GetObjectResult
- 处理异常

### 任务 7.3：实现 deleteObject 方法

**关联需求：** spec.md - CAP-003 对象删除

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 7.2

**涉及文件：**
- `libs/cos-sdk/src/CosClient.cj`

**验收标准：**
- 删除指定对象
- 返回 DeleteObjectResult
- 处理异常

### 任务 7.4：实现 listObjects 方法

**关联需求：** spec.md - CAP-004 对象查询

**优先级：** 高

**复杂度：** 中

**依赖：** 任务 7.3

**涉及文件：**
- `libs/cos-sdk/src/CosClient.cj`

**验收标准：**
- 支持前缀过滤
- 支持分页
- 返回 ListObjectsResult
- 处理异常

### 任务 7.5：实现 preSignedUrl 方法

**关联需求：** spec.md - CAP-007 预签名 URL

**优先级：** 高

**复杂度：** 中

**依赖：** 任务 7.4

**涉及文件：**
- `libs/cos-sdk/src/CosClient.cj`

**验收标准：**
- 支持 GET/PUT 方法
- 支持自定义有效期
- 返回预签名 URL

## 10. 阶段八：错误处理

### 任务 8.1：实现 CosError

**关联需求：** spec.md - 错误处理

**优先级：** 高

**复杂度：** 低

**依赖：** 任务 7.5

**涉及文件：**
- `libs/cos-sdk/src/error/CosError.cj`

**验收标准：**
- 定义 CosError 类
- 包含 code、message、requestId、resource 字段
- 实现错误类型判断方法

## 11. 阶段九：测试验证

### 任务 9.1：编写单元测试

**关联需求：** spec.md - 非功能需求

**优先级：** 中

**复杂度：** 中

**依赖：** 任务 8.1

**涉及文件：**
- `libs/cos-sdk/tests/CosClientTest.cj`

**验收标准：**
- 测试签名生成
- 测试 URL 构建
- 测试 XML 解析
- 测试错误处理
- 单元测试通过

## 12. 任务依赖关系图

```
任务 1.1 ──→ 任务 1.2 ──→ 任务 2.1 ──→ 任务 2.2 ──→ 任务 2.3 ──→ 任务 2.4
                                                            │
                                                            ↓
任务 2.5 ──→ 任务 2.6 ──→ 任务 2.7 ──→ 任务 2.8 ──→ 任务 3.1 ──→ 任务 4.1
                                                            │
                                                            ↓
任务 5.1 ──→ 任务 6.1 ──→ 任务 7.1 ──→ 任务 7.2 ──→ 任务 7.3 ──→ 任务 7.4
                                                            │
                                                            ↓
任务 7.5 ──→ 任务 8.1 ──→ 任务 9.1
```

## 13. 里程碑

| 里程碑 | 完成条件 | 预计日期 |
| :--- | :--- | :--- |
| M1: 基础设施完成 | 目录结构和 cjpm.toml 配置完成 | Day 1 |
| M2: 数据模型完成 | 所有请求/响应模型实现完成 | Day 2 |
| M3: 核心模块完成 | 签名、HTTP 请求、解析模块完成 | Day 3 |
| M4: 客户端完成 | CosClient 及所有 API 方法实现完成 | Day 4 |
| M5: 测试完成 | 单元测试编写完成并通过 | Day 5 |

---

**版本**: 1.0.0  
**日期**: 2026-06-23  
**状态**: 已接受