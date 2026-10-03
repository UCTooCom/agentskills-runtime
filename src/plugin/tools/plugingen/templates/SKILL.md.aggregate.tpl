---
name: {{name}}
description: >
  CRUD capability plugin {{name}} (plugingen 生成，覆盖 {{dbName}} 库下表：{{tablesInline}})
  provided by the {{name}} plugin. Supports create, update, soft-delete,
  restore, paged list with Prisma-style filter/sort. Triggers on:
  {{dbName}} data management requests, {{name}} plugin capability discovery.
license: MIT
plugin: {{name}}
---

# {{name}} CRUD Plugin

本插件由 {{name}} 聚合入口三维一体提供（Service + Skill + Route），
由 {{aggregateClassName}}Plugin 统一装配、{{aggregateClassName}}Route 统一注册，
覆盖 {{dbName}} 库下以下表的标准 CRUD 能力：

{{tablesList}}

## 能力说明

- 每张表均支持 新增 / 编辑 / 删除（软删 + 硬删）/ 恢复
- 分页列表（Prisma 风格 filter/sort 查询参数）
- 按创建者过滤与计数
- 导出 CSV

## 使用方式

1. **服务调用（确定性通道）**：宿主经 `ServiceRegistry.getService<{{firstControllerClass}}Service>()` 类型安全轨获取服务（其余表服务类名类同：各表对应 `<Pascal表名>Service`，见上方表清单）。
2. **HTTP 调用（插件路由通道）**：路由由 {{aggregateClassName}}Route 统一注册，按表归类：
   - `POST /api/v1/{{dbName}}/<table>/add`
   - `POST /api/v1/{{dbName}}/<table>/edit`
   - `POST /api/v1/{{dbName}}/<table>/del`
   - `GET  /api/v1/{{dbName}}/<table>/:id`
   - `GET  /api/v1/{{dbName}}/<table>/:limit/:page?sort=&filter=`

## 约束

- 遵循 uctoo-v4 API 规范：成功直接返回数据对象，错误返回 `{ errno, errmsg }`。
- 列表响应格式 `{ currentPage, totalCount, totalPage, <table>s }`。
- 插件停用后 HTTP 路由降级为 503（路由注册不删除），服务注销后类型安全轨取值为 None。
