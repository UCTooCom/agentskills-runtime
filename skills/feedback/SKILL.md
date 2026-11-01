---
name: feedback
description: >
  CRUD capability for the feedback table (uctoo database)
  provided by the feedback plugin. Supports create, update, soft-delete,
  restore, paged list with Prisma-style filter/sort. Triggers on:
  feedback data management requests, feedback plugin capability discovery.
license: MIT
plugin: feedback
service: magic.plugins.feedback.FeedbackService
route: /api/v1/uctoo/feedback
---

# Feedback CRUD Skill

本技能由 feedback 插件三维一体提供（Service + Skill + Route），
覆盖 uctoo 库 feedback 表的标准 CRUD 能力。

## 能力说明

- 新增 / 编辑 / 删除（软删 + 硬删）/ 恢复
- 分页列表（Prisma 风格 filter/sort 查询参数）
- 按创建者过滤与计数

## 使用方式

1. **服务调用（确定性通道）**：宿主经 `ServiceRegistry.getService<FeedbackService>()` 类型安全轨获取服务。
2. **HTTP 调用（插件路由通道）**：
   - `POST /api/v1/uctoo/feedback/add`
   - `POST /api/v1/uctoo/feedback/edit`
   - `POST /api/v1/uctoo/feedback/del`
   - `GET  /api/v1/uctoo/feedback/:id`
   - `GET  /api/v1/uctoo/feedback/:limit/:page?sort=&filter=`

## 约束

- 遵循 uctoo-v4 API 规范：成功直接返回数据对象，错误返回 `{ errno, errmsg }`。
- 列表响应格式 `{ currentPage, totalCount, totalPage, feedbacks }`。
- 插件停用后 HTTP 路由降级为 503（路由注册不删除），服务注销后类型安全轨取值为 None。
