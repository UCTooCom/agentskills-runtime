# uctoo V4.0 子系统架构说明

## 文档信息
- **版本**: 1.0.0
- **创建日期**: 2026-03-13
- **状态**: 实施阶段
- **目标**: 提供与 backend 一致的架构设计和使用方式

## 1. 架构概述

### 1.1 设计原则
uctoo V4.0 应用服务器遵循与 `apps/backend` 一致的架构设计原则：
- **三层架构**: Controllers → Services → Models
- **中间件机制**: 认证、权限、日志等
- **RESTful API**: 统一的API规范
- **UMI架构**: 全栈模型同构设计

### 1.2 架构层次
```
┌─────────────────────────────────────────────────────────┐
│                   HTTP Server Layer                      │  HTTP服务器，WebSocket支持
├─────────────────────────────────────────────────────────┤
│                   Middleware Layer                      │  认证、权限、缓存、日志等中间件
├─────────────────────────────────────────────────────────┤
│                   Routes Layer                          │  路由定义，URL映射
├─────────────────────────────────────────────────────────┤
│                   Controllers Layer                     │  请求处理，参数验证，响应封装
├─────────────────────────────────────────────────────────┤
│                   Services Layer                        │  业务逻辑，数据操作
├─────────────────────────────────────────────────────────┤
│                   ORM Layer                             │  fountain ORM，数据持久化
├─────────────────────────────────────────────────────────┤
│                   Database Layer                        │  PostgreSQL，多数据库支持
└─────────────────────────────────────────────────────────┘
```

## 2. 目录结构

### 2.1 标准目录结构
```
src/app/
├── controllers/                    # 控制器层
│   └── {database}/                # 按数据库名分隔
│       └── {table}/               # 按表名分隔
│           └── {Table}Controller.cj
├── routes/                         # 路由层
│   └── {database}/                # 按数据库名分隔
│       └── {table}/               # 按表名分隔
│           └── {Table}Route.cj
├── services/                       # 服务层
│   └── {database}/                # 按数据库名分隔
│       └── {Table}.cj             # 按表名分隔
├── middlewares/                    # 中间件
│   ├── auth/                      # 认证中间件
│   │   └── JWTAuthMiddleware.cj
│   └── permission/                # 权限中间件
│       └── PermissionMiddleware.cj
├── models/                         # 数据模型
│   └── {database}/                # 按数据库名分隔
│       └── {Table}PO.cj           # 持久化对象
├── core/                           # 核心组件
│   ├── server/                    # HTTP服务器
│   ├── router/                    # 路由系统
│   ├── middleware/                # 中间件基础
│   ├── response/                  # 响应封装
│   ├── cache/                     # 缓存管理
│   ├── database/                  # 数据库连接
│   └── log/                       # 日志系统
└── main.cj                         # 应用入口
```

### 2.2 已实现模块示例
```
src/app/
├── controllers/
│   └── uctoo/
│       └── entity/
│           └── EntityController.cj    # entity表控制器
├── routes/
│   └── uctoo/
│       └── entity/
│           └── EntityRoute.cj         # entity表路由
├── services/
│   └── uctoo/
│       └── EntityService.cj           # entity表服务
├── middlewares/
│   ├── auth/
│   │   └── JWTAuthMiddleware.cj       # JWT认证中间件
│   └── permission/
│       └── PermissionMiddleware.cj    # 权限中间件
├── models/
│   └── uctoo/
│       └── EntityPO.cj                # entity持久化对象
└── main.cj
```

## 3. 核心组件说明

### 3.1 HTTP服务器 (core/server/)
自研HTTP服务器，支持：
- HTTP/1.1 协议
- 静态文件服务
- 动态路由
- 中间件链
- WebSocket支持

### 3.2 路由系统 (core/router/)
路由系统支持：
- 动态路由参数
- 路由分组
- 中间件挂载
- RESTful风格路由

### 3.3 中间件机制 (core/middleware/)
中间件接口定义：
```cangjie
public interface Middleware {
    func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit
}
```

### 3.4 响应封装 (core/response/)
统一API响应格式：
```cangjie
public class APIResponse<T> {
    public var data: T
    public var currentPage: Int32 = 0
    public var totalCount: Int64 = 0
    public var totalPage: Int32 = 0
}

public class APIError {
    public var errno: String = ""
    public var errmsg: String = ""
}
```

### 3.5 数据库连接 (core/database/)
数据库连接管理：
- 连接池管理
- 事务支持
- 多数据库支持

### 3.6 日志系统 (core/log/)
日志记录器：
- 多级别日志（DEBUG、INFO、WARN、ERROR）
- 文件输出
- 控制台输出
- 日志轮转

## 4. 与 backend 的对应关系

| backend (TypeScript) | uctoo V4.0 (Cangjie) | 说明 |
|---------------------|------------------------------|------|
| `src/app/controllers/` | `src/app/controllers/` | 控制器层 |
| `src/app/routes/` | `src/app/routes/` | 路由层 |
| `src/app/services/` | `src/app/services/` | 服务层 |
| `prisma/schema.prisma` | `src/app/models/` | 数据模型 |
| `src/app/middlewares/` | `src/app/middlewares/` | 中间件 |
| Prisma ORM | fountain ORM | ORM框架 |
| Hyper-Express | 自研HTTP服务器 | HTTP框架 |

## 5. 技术栈

| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 编程语言 | 仓颉 (Cangjie) | 华为自研编程语言 |
| HTTP服务器 | 自研 | 基于仓颉标准库 |
| ORM框架 | fountain ORM | 仓颉ORM框架 |
| 数据库驱动 | opengauss-driver | PostgreSQL驱动 |
| 数据库 | PostgreSQL | 主数据库 |
| 认证 | JWT | jwt4cj库 |
| 缓存 | Redis | redis-sdk库 |
| 日志 | log-cj | 仓颉日志库 |

## 6. 开发流程

### 6.1 新增数据表模块

1. **定义模型** (`models/{database}/{Table}PO.cj`)
   - 使用 `@QueryMappersGenerator` 注解指定表名
   - 使用 `@ORMField` 注解标记字段

2. **创建服务** (`services/{database}/{Table}.cj`)
   - 实现 CRUD 方法
   - 处理业务逻辑

3. **创建控制器** (`controllers/{database}/{table}/{Table}Controller.cj`)
   - 处理 HTTP 请求
   - 调用服务层方法
   - 封装响应

4. **注册路由** (`routes/{database}/{table}/{Table}Route.cj`)
   - 定义 URL 映射
   - 配置中间件

### 6.2 运行项目

```bash
# 编译项目
cjpm build

# 运行项目（开发态）
cjpm run --skip-build --name magic.api
```

## 7. 参考文档

- [uctoo API设计规范](../../../backend/docs/uctoo-api-design-specification.md)
- [uctoo 数据库设计规范](../../../backend/docs/uctoo-database-design-specification.md)
- [uctoo 模块设计规范](../../../backend/docs/uctoo-module-design-specification.md)
- [用户权限体系](../../../backend/docs/user-permission-system.md)
- [uctoo V4.0 升级方案](../../../../specs/004-agent-skill-runtime/uctoo-v4-upgrade.md)
