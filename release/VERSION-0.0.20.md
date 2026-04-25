# AgentSkills Runtime v0.0.20

**发布日期**: 2026-04-25  
**代号**: UMI-Architecture

## 版本摘要

v0.0.20是一个重要的架构升级版本，实现了完整的UMI（Unified Model Interface）全栈模型同构架构，发布了Web-Admin管理端项目，并重构了CRUD代码生成器。

## 核心更新

### 1. CRUD代码生成器重构 ✨
- 实现确定性代码生成，生成的代码与标准模块100%一致
- 采用模板引擎，支持Model/DAO/Service/Controller/Route各层生成
- 支持增量更新，保留自定义代码区域

### 2. Web-Admin管理端发布 🎉
- 基于Vue 3 + TypeScript + OpenTiny Vue构建
- 实现完整UMI架构：数据模型同构、状态管理同构、API调用同构
- 支持WebMCP协议，集成AI智能体功能

### 3. UMI架构完整实现 🏗️
- 前端Pinia ORM模型与后端完全一致
- 通过Pinia ORM实现服务端状态缓存与同步
- 模型层直接集成API调用方法

### 4. API对接完成 🔗
- Web-Admin与AgentSkills-Runtime完整对接
- 用户认证、CRUD操作、技能管理、AI对话全部打通
- 统一UCToo V4 API规范

## 技术栈

**后端 (AgentSkills-Runtime)**:
- Cangjie + Fountain ORM
- 三层架构: Controller → Service → DAO
- 支持PostgreSQL/MySQL/OpenGauss

**前端 (Web-Admin)**:
- Vue 3.5+ + TypeScript
- OpenTiny Vue 3.28+
- Pinia 2.1.7 + Pinia ORM 1.10.2
- Axios 1.7.9

## 快速开始

### 安装Runtime
```bash
npm install @opencangjie/skills@1.1.0
npx skills install-runtime --runtime-version 0.0.20
npx skills start
```

### 生成CRUD模块
```bash
npx skills run crud-generator
# 或
crudgen --db uctoo --table <table_name>
```

### 部署Web-Admin
```bash
git clone https://gitee.com/UCT/uctoo-app-client-pc.git
cd uctoo-app-client-pc
start-installer.bat
```

## 下载

| 平台 | 文件 | 大小 |
|------|------|------|
| Windows x64 | agentskills-runtime-win-x64.tar.gz | ~160MB |
| Linux x64 | agentskills-runtime-linux-x64.tar.gz | ~150MB |
| macOS x64 | agentskills-runtime-darwin-x64.tar.gz | ~145MB |
| macOS ARM64 | agentskills-runtime-darwin-arm64.tar.gz | ~140MB |

## 文档

- [完整发布说明](./release-notes-0.0.20.md)
- [CRUD生成器指南](../docs/crudgen-migration.md)
- [Web-Admin部署指南](../docs/web-admin-deployment.md)
- [UMI架构开发指南](../docs/umi-architecture.md)

## 支持

- GitHub: https://atomgit.com/UCToo/agentskills-runtime
- 邮箱: support@uctoo.com
- 问题反馈: https://atomgit.com/UCToo/agentskills-runtime/issues

---

**上一版本**: [v0.0.19](./release-notes-0.0.19.md)  
**下一版本**: v0.0.21 (计划中)
