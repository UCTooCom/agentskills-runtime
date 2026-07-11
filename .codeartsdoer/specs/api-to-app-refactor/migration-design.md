# API 模块重构 - 依赖更新与迁移设计文档

## 文档信息
- **项目名称**: agentskills-runtime API 模块重构 - 依赖更新
- **版本**: 1.0.0
- **创建日期**: 2026-03-14
- **最后更新**: 2026-03-14
- **作者**: SDD Agent
- **状态**: 设计中
- **关联需求**: spec.md v1.1.0
- **关联设计**: design.md v1.2.0

## 1. 概述

### 1.1 背景
由于我们将原 `magic.api` 模块的功能重构到了 `magic.app` 模块，并且统一了 API 路径规范，所有依赖原 api 模块的程序、应用、SDK 都需要进行相应的修改或重构。

### 1.2 重构目标
1. 统一所有 API 路径到 `/api/v1/uctoo/` 前缀下
2. 更新所有客户端 SDK 以适配新的 API 路径
3. 更新所有文档以反映新的 API 规范
4. 确保向后兼容性或提供迁移指南
5. 删除或标记废弃原 `magic.api` 模块

### 1.3 影响范围

#### 高影响区域
- API 路由路径（所有客户端需要更新）
- WebSocket 连接地址
- JavaScript SDK
- 集成测试
- 部署配置

#### 中影响区域
- 文档（README、API 文档、部署指南）
- 示例代码
- 配置文件

#### 低影响区域
- 核心业务逻辑（SkillManager、ModelManager 等）
- 数据库操作
- 技能执行逻辑

## 2. API 路径映射表

### 2.1 技能管理 API

| 原 API 路径 | 新 API 路径 | HTTP 方法 | 功能 |
|-----------|-----------|----------|------|
| `/skills` | `/api/v1/uctoo/agent_skills` | GET | 获取技能列表 |
| `/skills/:id` | `/api/v1/uctoo/agent_skills/:id` | GET | 获取技能详情 |
| `/skills/add` | `/api/v1/uctoo/agent_skills/add` | POST | 添加技能 |
| `/skills/edit` | `/api/v1/uctoo/agent_skills/edit` | POST | 编辑技能 |
| `/skills/del` | `/api/v1/uctoo/agent_skills/del` | POST | 删除技能 |
| `/skills/execute` | `/api/v1/uctoo/skills/execute` | POST | 执行技能 |
| `/skills/search` | `/api/v1/uctoo/skills/search` | POST | 搜索技能 |
| - | `/api/v1/uctoo/skills` | GET | 获取运行时技能列表 |
| - | `/api/v1/uctoo/skills/install` | POST | 安装技能 |

### 2.2 WebSocket API

| 原 API 路径 | 新 API 路径 | 协议 | 功能 |
|-----------|-----------|------|------|
| `/ws/chat` | `/api/v1/uctoo/ws/chat` | WebSocket | WebSocket 聊天 |

### 2.3 MCP API

| 原 API 路径 | 新 API 路径 | HTTP 方法 | 功能 |
|-----------|-----------|----------|------|
| `/mcp/stream` | `/api/v1/uctoo/mcp/stream` | GET | MCP 流式接口 |

### 2.4 其他 API

| 原 API 路径 | 新 API 路径 | HTTP 方法 | 功能 |
|-----------|-----------|----------|------|
| `/hello` | `/api/v1/health` | GET | 健康检查 |
| `/api/v1/uctoo/entity/*` | `/api/v1/uctoo/entity/*` | * | 实体管理（无变化） |
| `/api/v1/health` | `/api/v1/health` | GET | 健康检查（无变化） |
| `/api/v1/info` | `/api/v1/info` | GET | 服务信息（无变化） |

## 3. 需要重构的模块清单

### 3.1 源代码文件

#### 3.1.1 原 API 模块（需要处理）

| 文件路径 | 当前状态 | 处理方案 |
|---------|---------|---------|
| `src/api/api_router.cj` | 已重构到 app | 标记为废弃或删除 |
| `src/api/main.cj` | 已重构到 app | 标记为废弃或删除 |
| `src/api/websocket_handler.cj` | 已重构到 app | 标记为废弃或删除 |

**处理建议**：
- 方案 A：直接删除 `src/api/` 目录
- 方案 B：添加 `@Deprecated` 注解并保留一段时间
- 方案 C：重命名为 `src/api_deprecated/` 作为参考

#### 3.1.2 配置文件

| 文件路径 | 需要修改的内容 |
|---------|--------------|
| `cjpm.toml` | 移除或注释 `[package.package-configuration."magic.api"]` 配置 |

### 3.2 SDK 文件

#### 3.2.1 JavaScript SDK

| 文件路径 | 需要修改的内容 |
|---------|--------------|
| `sdk/javascript/src/agentskills-client.js` | 更新所有 API 路径 |
| `sdk/javascript/src/config.js` | 更新默认 API 基础路径 |
| `sdk/javascript/examples/*.js` | 更新示例代码中的 API 路径 |
| `sdk/javascript/test/*.js` | 更新测试代码中的 API 路径 |

**具体修改**：
```javascript
// 旧代码
const BASE_URL = 'http://localhost:8080';
client.getSkills(); // GET /skills

// 新代码
const BASE_URL = 'http://localhost:8080/api/v1/uctoo';
client.getSkills(); // GET /api/v1/uctoo/agent_skills
```

### 3.3 文档文件

| 文件路径 | 需要修改的内容 |
|---------|--------------|
| `README.md` | 更新 API 路径说明、示例代码 |
| `README_cn.md` | 更新 API 路径说明、示例代码 |
| `docs/agentskills-api-service-run.md` | 更新部署说明、API 路径 |
| `docs/agentskills-api-testing-guide.md` | 更新测试用例、API 路径 |
| `docs/uctoo-v4/README.md` | 更新架构说明 |
| `docs/uctoo-v4/uctoo-v4-architecture.md` | 更新架构图和说明 |
| `sdk/javascript/README.md` | 更新 SDK 使用说明 |
| `sdk/javascript/README_cn.md` | 更新 SDK 使用说明 |

### 3.4 测试文件

| 文件路径 | 需要修改的内容 |
|---------|--------------|
| `tests/api/*.cj` | 更新测试用例中的 API 路径 |
| `tests/integration/*.cj` | 更新集成测试中的 API 路径 |

### 3.5 示例代码

| 文件路径 | 需要修改的内容 |
|---------|--------------|
| `examples/*.cj` | 更新示例代码中的 API 路径 |
| `examples/*.js` | 更新 JavaScript 示例代码 |

## 4. 重构任务规划

### 4.1 阶段一：源代码重构（已完成）
- [x] 实现 AgentSkillsService 真实功能
- [x] 实现 AgentSkillsController 真实功能
- [x] 实现 WsChatController 真实功能
- [x] 实现 McpController 真实功能
- [x] 更新 main.cj 初始化所有组件
- [x] 编译验证

### 4.2 阶段二：SDK 更新
- [ ] 更新 JavaScript SDK API 路径
- [ ] 更新 SDK 配置文件
- [ ] 更新 SDK 示例代码
- [ ] 更新 SDK 测试代码
- [ ] 发布新版本 SDK

### 4.3 阶段三：文档更新
- [ ] 更新 README.md
- [ ] 更新 README_cn.md
- [ ] 更新 API 文档
- [ ] 更新部署文档
- [ ] 更新测试文档
- [ ] 创建迁移指南

### 4.4 阶段四：测试验证
- [ ] 更新单元测试
- [ ] 更新集成测试
- [ ] 运行完整测试套件
- [ ] 性能测试
- [ ] 兼容性测试

### 4.5 阶段五：清理工作
- [ ] 标记或删除原 api 模块
- [ ] 更新 cjpm.toml 配置
- [ ] 清理废弃代码
- [ ] 代码审查

## 5. 向后兼容性策略

### 5.1 版本策略
- 主版本号升级（v1.x.x → v2.0.0）表示不兼容的 API 变更
- 提供迁移指南和兼容性说明
- 保留旧版本 SDK 一段时间

### 5.2 兼容层方案（可选）
如果需要保持向后兼容，可以在 `magic.app` 中添加兼容路由：

```cangjie
// 兼容旧 API 路径
router.get("/skills", { req, res =>
    // 重定向到新路径或直接处理
    res.redirect("/api/v1/uctoo/agent_skills")
})
```

### 5.3 迁移指南
创建详细的迁移指南，包括：
1. API 路径映射表
2. 代码修改示例
3. 常见问题解答
4. 迁移检查清单

## 6. 风险评估

### 6.1 高风险项
| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| 客户端未及时更新 | 服务不可用 | 提供兼容层或详细迁移指南 |
| 文档更新不及时 | 用户困惑 | 优先更新核心文档 |
| 测试覆盖不足 | 功能缺陷 | 增加测试用例 |

### 6.2 中风险项
| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| SDK 版本混乱 | 用户困惑 | 清晰的版本管理和发布说明 |
| 配置遗漏 | 部署失败 | 提供配置检查工具 |

### 6.3 低风险项
| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| 示例代码过时 | 学习困难 | 及时更新示例 |
| 注释不一致 | 代码可读性下降 | 代码审查时修正 |

## 7. 验收标准

### 7.1 功能验收
- [ ] 所有 API 路径已更新到新规范
- [ ] 所有功能测试通过
- [ ] 性能无明显下降
- [ ] 无编译错误和警告

### 7.2 文档验收
- [ ] 所有文档已更新
- [ ] API 文档准确完整
- [ ] 迁移指南清晰易懂
- [ ] 示例代码可运行

### 7.3 SDK 验收
- [ ] SDK 功能测试通过
- [ ] SDK 文档完整
- [ ] SDK 示例可运行
- [ ] 发布流程正常

## 8. 时间规划

| 阶段 | 预计工作量 | 优先级 |
|-----|----------|--------|
| 阶段一：源代码重构 | 已完成 | P0 |
| 阶段二：SDK 更新 | 2-3 天 | P0 |
| 阶段三：文档更新 | 1-2 天 | P1 |
| 阶段四：测试验证 | 2-3 天 | P0 |
| 阶段五：清理工作 | 1 天 | P2 |

## 9. 附录

### 9.1 相关文档
- [spec.md](./spec.md) - 需求规格文档
- [design.md](./design.md) - 技术设计文档
- [tasks.md](./tasks.md) - 任务规划文档

### 9.2 参考资料
- [uctoo v4 架构规范](../../docs/uctoo-v4/)
- [API 设计规范](../../docs/api-specification.md)
- [SDK 开发指南](../../docs/sdk-development-guide.md)
