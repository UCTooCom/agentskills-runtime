# AgentSkills Runtime API 服务运行指南

## 概述

本文档介绍了如何运行 AgentSkills Runtime 的 API 层服务。API 层向上层的多语言生态系统提供 API 能力，包括技能管理、执行、搜索等功能。

## 环境要求

- 仓颉编程语言环境 (Cangjie 1.0 或更高版本)
- 支持的操作系统：Windows/Linux/macOS
- 至少 2GB 可用内存

## 快速开始

### 1. 安装依赖

确保已安装仓颉编程语言环境：

```bash
# 验证仓颉环境
cjpm --version
```

### 2. 构建项目

```bash
# 在项目根目录下执行
cjpm build
```

### 3. 运行 API 服务

```bash
# 使用默认端口 8080 运行 API 服务
cjpm run --skip-build --name magic.api

# 或者指定自定义端口
cjpm run --skip-build --name magic.api 8081
```

## API 服务配置

### 端口配置

API 服务默认运行在 8080 端口。可以通过以下方式更改：

1. 在命令行中传递端口号参数：
   ```bash
   cjpm run --skip-build --name magic.api <port_number>
   ```

2. 默认情况下，如果未提供端口号，服务将在 8080 端口启动。

## API 接口列表

### 健康检查接口

- **GET /**/hello**
- **描述**: 用于检查 API 服务是否正常运行
- **请求示例**: `curl http://localhost:8080/hello`
- **响应示例**:
  ```json
  {
    "message": "Hello World"
  }
  ```

### 技能管理接口

- **GET /skills**: 获取技能列表
- **GET /skills/:id**: 获取特定技能详情
- **POST /skills/add**: 添加新技能
- **POST /skills/edit**: 编辑技能
- **POST /skills/del**: 删除技能
- **POST /skills/execute**: 执行技能
- **POST /skills/search**: 搜索技能

### 详细接口说明

#### POST /skills/add
- **功能**: 从本地路径或远程URL安装技能
- **实现详情**: 该接口现在使用底层的SkillPackageManager执行实际的安装操作。系统会解析请求体中的source参数，如果是Git URL则通过GitManager从远程仓库克隆并安装，如果是本地路径则直接从路径安装。安装完成后会重新加载技能列表以包含新安装的技能。
- **请求示例**:
  ```bash
  curl -X POST http://localhost:8080/skills/add \
    -H "Content-Type: application/json" \
    -d '{"source": "./my-skill", "validate": true, "creator": "user-id"}'
  ```

#### POST /skills/edit
- **功能**: 更新现有技能
- **实现详情**: 该接口使用SkillPackageManager执行实际的更新操作。系统会解析请求体中的技能ID和更新参数，然后调用updateSkill方法更新技能。更新完成后会重新加载技能列表以反映变更。
- **请求示例**:
  ```bash
  curl -X POST http://localhost:8080/skills/edit \
    -H "Content-Type: application/json" \
    -d '{"id": "my-skill-abc", "description": "Updated description", "creator": "user-id"}'
  ```

#### POST /skills/del
- **功能**: 卸载技能
- **实现详情**: 该接口使用SkillPackageManager执行实际的卸载操作。系统会解析请求体中的技能ID，然后调用uninstallSkill方法从系统中移除技能。卸载完成后会重新加载技能列表以排除已删除的技能。
- **请求示例**:
  ```bash
  curl -X POST http://localhost:8080/skills/del \
    -H "Content-Type: application/json" \
    -d '{"id": "my-skill-abc"}'
  ```

### MCP 相关接口

- **GET /mcp/stream**: MCP 服务器流式接口

## 服务管理

### 启动服务

```bash
# 启动 API 服务
cjpm run --skip-build --name magic.api
```

### 停止服务

目前，可以通过 `Ctrl+C` 组合键终止服务。

## 日志查看

API 服务会在控制台输出日志信息，包括：

- 服务启动和停止信息
- 请求处理日志
- 错误信息

## 故障排除

### 常见问题

1. **端口被占用**
   - 确保指定的端口没有被其他服务占用
   - 尝试使用不同的端口号启动服务

2. **权限不足**
   - 确保有足够的权限运行仓颉程序
   - 在某些系统上可能需要管理员权限

3. **依赖缺失**
   - 确保已正确安装仓颉编程语言环境
   - 运行 `cjpm install` 确保所有依赖都已安装

### 调试技巧

- 查看控制台输出的日志信息
- 确认 API 服务是否在正确的端口上运行
- 使用 curl 或 Postman 等工具测试 API 接口

## 多语言生态系统集成

API 层为多语言生态系统提供了统一的接口，支持：

- JavaScript/TypeScript SDK
- Python SDK
- Java SDK
- Go SDK
- Rust SDK
- C# SDK

各语言 SDK 可以通过 HTTP API 与 AgentSkills Runtime 进行交互。

## 性能优化

- 根据系统资源调整并发连接数
- 启用适当的缓存策略
- 定期监控服务性能指标

## 安全注意事项

- 在生产环境中使用 HTTPS
- 实施适当的认证和授权机制
- 限制 API 请求频率以防止滥用