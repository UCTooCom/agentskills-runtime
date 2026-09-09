---
name: entity
description: >
  CRUD capability for the entity table (uctoo database)
  provided by the entity plugin. Supports create, update, soft-delete,
  restore, paged list with Prisma-style filter/sort. Triggers on:
  entity data management requests, entity plugin capability discovery.
license: MIT
plugin: entity
service: magic.plugins.entity.EntityService
route: /api/v1/uctoo/entity
---

# Entity CRUD Skill

本技能由 entity 插件三维一体提供（Service + Skill + Route），
覆盖 uctoo 库 entity 表的标准 CRUD 能力。

## 能力说明

- 新增 / 编辑 / 删除（软删 + 硬删）/ 恢复
- 分页列表（Prisma 风格 filter/sort 查询参数）
- 按创建者过滤与计数

## 使用方式

1. **服务调用（确定性通道）**：宿主经 `ServiceRegistry.getService<EntityService>()` 类型安全轨获取服务。
2. **HTTP 调用（插件路由通道）**：
   - `POST /api/v1/uctoo/entity/add`
   - `POST /api/v1/uctoo/entity/edit`
   - `POST /api/v1/uctoo/entity/del`
   - `GET  /api/v1/uctoo/entity/:id`
   - `GET  /api/v1/uctoo/entity/:limit/:page?sort=&filter=`

## 约束

- 遵循 uctoo-v4 API 规范：成功直接返回数据对象，错误返回 `{ errno, errmsg }`。
- 列表响应格式 `{ currentPage, totalCount, totalPage, entitys }`。
- 插件停用后 HTTP 路由降级为 503（路由注册不删除），服务注销后类型安全轨取值为 None。
