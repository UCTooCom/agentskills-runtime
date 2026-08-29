---
name: {{name}}
description: >
  CRUD capability for the {{tableName}} table ({{dbName}} database)
  provided by the {{name}} plugin. Supports create, update, soft-delete,
  restore, paged list with Prisma-style filter/sort. Triggers on:
  {{tableName}} data management requests, {{name}} plugin capability discovery.
license: MIT
plugin: {{name}}
service: skill_{{name}}.{{className}}Service
route: /api/v1/{{dbName}}/{{tableName}}
---

# {{className}} CRUD Skill

本技能由 {{name}} 插件三维一体提供（Service + Skill + Route），
覆盖 {{dbName}} 库 {{tableName}} 表的标准 CRUD 能力。

## 能力说明

- 新增 / 编辑 / 删除（软删 + 硬删）/ 恢复
- 分页列表（Prisma 风格 filter/sort 查询参数）
- 按创建者过滤与计数

## 使用方式

1. **服务调用（确定性通道）**：宿主经 `ServiceRegistry.getService<{{className}}Service>()` 类型安全轨获取服务。
2. **HTTP 调用（插件路由通道）**：
   - `POST /api/v1/{{dbName}}/{{tableName}}/add`
   - `POST /api/v1/{{dbName}}/{{tableName}}/edit`
   - `POST /api/v1/{{dbName}}/{{tableName}}/del`
   - `GET  /api/v1/{{dbName}}/{{tableName}}/:id`
   - `GET  /api/v1/{{dbName}}/{{tableName}}/:limit/:page?sort=&filter=`

## 约束

- 遵循 uctoo-v4 API 规范：成功直接返回数据对象，错误返回 `{ errno, errmsg }`。
- 列表响应格式 `{ currentPage, totalCount, totalPage, {{tableName}}s }`。
- 插件停用后 HTTP 路由降级为 503（路由注册不删除），服务注销后类型安全轨取值为 None。
