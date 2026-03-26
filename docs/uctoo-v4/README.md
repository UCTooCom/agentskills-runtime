# uctoo V4.0 应用服务器文档

## 文档信息
- **版本**: 1.0.0
- **创建日期**: 2026-03-13
- **状态**: 实施阶段
- **目标**: 提供与 backend 一致的架构设计和使用方式

## 文档目录

### 架构设计
- [子系统架构说明](./uctoo-v4-architecture.md) - 整体架构设计和目录结构
- [API规范](./uctoo-v4-api-specification.md) - RESTful API设计规范

### 开发指南
- [模块开发指南](./uctoo-v4-module-development.md) - 如何开发标准CRUD模块
- [中间件使用指南](./uctoo-v4-middleware-guide.md) - 认证、权限等中间件使用

### 参考文档
- [uctoo API设计规范](../../../backend/docs/uctoo-api-design-specification.md)
- [uctoo 数据库设计规范](../../../backend/docs/uctoo-database-design-specification.md)
- [uctoo 模块设计规范](../../../backend/docs/uctoo-module-design-specification.md)
- [用户权限体系](../../../backend/docs/user-permission-system.md)
- [uctoo V4.0 升级方案](../../../../specs/004-agent-skill-runtime/uctoo-v4-upgrade.md)

## 快速开始

### 运行项目
```bash
# 编译项目
cjpm build

# 运行项目（开发态）
cjpm run --skip-build --name magic.api
```

### 目录结构
```
src/app/
├── controllers/     # 控制器层
├── routes/          # 路由层
├── services/        # 服务层
├── models/          # 数据模型
├── middlewares/     # 中间件
├── core/            # 核心组件
└── main.cj          # 应用入口
```

## 实施进度

| 阶段 | 状态 | 说明 |
|------|------|------|
| 基础架构搭建 | ✅ 已完成 | HTTP服务器、路由系统、中间件机制 |
| 核心功能开发 | 🔄 进行中 | JWT认证、权限系统、ORM集成 |
| 业务模块开发 | 🔄 进行中 | entity示例模块已完成 |
| 测试与优化 | 📅 待开始 | - |
