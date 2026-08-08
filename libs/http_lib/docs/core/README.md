# http_lib 核心模块（core）

## 概述

`core` 模块提供 HTTP 协议的核心类型定义，包括请求方法、状态码、请求头、
协议版本、异常类型等所有模块共享的基础类型。

## 主要类型

| 类型 | 说明 |
|------|------|
| `HttpMethod` | HTTP 请求方法枚举（GET、POST、PUT、DELETE 等） |
| `HttpStatus` | HTTP 状态码枚举（200 OK、404 Not Found、500 Internal Server Error 等） |
| `HttpHeaders` | HTTP 头部容器（支持大小写不敏感的增删改查） |
| `HttpVersion` | HTTP 版本枚举（HTTP/1.0、HTTP/1.1、HTTP/2、HTTP/3） |
| `ProtocolException` | 协议异常，表示 HTTP 协议层面的错误 |
| `Context` | 请求上下文，在中间件和处理器之间共享数据 |

## API 参考

请参阅 [核心 API 参考](api.md) 获取详细的类型和方法说明。
