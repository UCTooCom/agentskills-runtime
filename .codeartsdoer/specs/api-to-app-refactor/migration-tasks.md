# API 模块重构 - 迁移任务清单

## 文档信息
- **项目名称**: agentskills-runtime API 模块重构 - 迁移任务
- **版本**: 1.0.0
- **创建日期**: 2026-03-14
- **最后更新**: 2026-03-14
- **作者**: SDD Agent
- **状态**: 待执行
- **关联设计**: migration-design.md v1.0.0

## 任务概述

本文档详细列出了将原 `magic.api` 模块功能迁移到 `magic.app` 模块后，所有需要更新的依赖项和任务清单。

---

## 阶段一：源代码重构（已完成 ✅）

### 1.1 核心功能实现 ✅
- [x] 实现 AgentSkillsService 真实功能
- [x] 实现 AgentSkillsController 真实功能
- [x] 实现 WsChatController 真实功能
- [x] 实现 McpController 真实功能
- [x] 更新 main.cj 初始化所有组件
- [x] 编译验证通过

---

## 阶段二：SDK 更新

### 2.1 JavaScript SDK 核心文件

#### 任务 2.1.1：更新 SDK 配置文件
**文件**: `sdk/javascript/src/config.js`

**修改内容**:
```javascript
// 旧配置
module.exports = {
  BASE_URL: 'http://localhost:8080',
  API_VERSION: 'v1'
};

// 新配置
module.exports = {
  BASE_URL: 'http://localhost:8080/api/v1/uctoo',
  API_VERSION: 'v1',
  API_PREFIX: '/api/v1/uctoo'
};
```

**验收标准**:
- [ ] 配置文件已更新
- [ ] 默认基础路径正确
- [ ] 环境变量支持正常

---

#### 任务 2.1.2：更新 SDK 客户端类
**文件**: `sdk/javascript/src/agentskills-client.js`

**修改内容**:

1. **技能管理 API 路径更新**:
```javascript
// 旧代码
async getSkills(page = 0, limit = 10) {
  return this.get(`/skills?page=${page}&limit=${limit}`);
}

// 新代码
async getSkills(page = 0, limit = 10) {
  return this.get(`/agent_skills?page=${page}&limit=${limit}`);
}
```

2. **技能安装 API 路径更新**:
```javascript
// 旧代码
async installSkill(source, options = {}) {
  return this.post('/skills/add', { source, ...options });
}

// 新代码
async installSkill(source, options = {}) {
  return this.post('/skills/install', { source, ...options });
}
```

3. **技能执行 API 路径更新**:
```javascript
// 旧代码
async executeSkill(skillId, params = {}) {
  return this.post('/skills/execute', { skill_id: skillId, params });
}

// 新代码
async executeSkill(skillId, params = {}) {
  return this.post('/skills/execute', { skill_id: skillId, params });
}
```

4. **WebSocket 连接地址更新**:
```javascript
// 旧代码
connectWebSocket(onMessage) {
  const ws = new WebSocket(`ws://${this.host}:${this.port}/ws/chat`);
}

// 新代码
connectWebSocket(onMessage) {
  const ws = new WebSocket(`ws://${this.host}:${this.port}/api/v1/uctoo/ws/chat`);
}
```

**验收标准**:
- [ ] 所有 API 路径已更新
- [ ] WebSocket 连接地址已更新
- [ ] 方法签名保持兼容
- [ ] 单元测试通过

---

#### 任务 2.1.3：更新 SDK 示例代码
**文件**: `sdk/javascript/examples/*.js`

**需要更新的文件**:
- `sdk/javascript/examples/basic-usage.js`
- `sdk/javascript/examples/skill-management.js`
- `sdk/javascript/examples/websocket-chat.js`

**修改内容**:
```javascript
// 旧代码
const client = new AgentSkillsClient('localhost', 8080);

// 新代码
const client = new AgentSkillsClient({
  host: 'localhost',
  port: 8080,
  basePath: '/api/v1/uctoo'
});
```

**验收标准**:
- [ ] 所有示例代码已更新
- [ ] 示例代码可运行
- [ ] 输出结果正确

---

#### 任务 2.1.4：更新 SDK 测试代码
**文件**: `sdk/javascript/test/*.js`

**需要更新的文件**:
- `sdk/javascript/test/client.test.js`
- `sdk/javascript/test/skills.test.js`
- `sdk/javascript/test/websocket.test.js`

**修改内容**:
```javascript
// 旧代码
describe('AgentSkillsClient', () => {
  it('should get skills', async () => {
    const response = await client.get('/skills');
  });
});

// 新代码
describe('AgentSkillsClient', () => {
  it('should get skills', async () => {
    const response = await client.get('/agent_skills');
  });
});
```

**验收标准**:
- [ ] 所有测试用例已更新
- [ ] 测试通过
- [ ] 覆盖率保持或提高

---

#### 任务 2.1.5：更新 SDK 文档
**文件**: 
- `sdk/javascript/README.md`
- `sdk/javascript/README_cn.md`

**修改内容**:
1. 更新 API 路径说明
2. 更新使用示例
3. 添加迁移指南链接
4. 更新版本号

**验收标准**:
- [ ] 文档已更新
- [ ] 示例代码正确
- [ ] 链接有效

---

### 2.2 SDK 发布

#### 任务 2.2.1：更新 package.json
**文件**: `sdk/javascript/package.json`

**修改内容**:
```json
{
  "name": "@uctoo/agentskills-sdk",
  "version": "2.0.0",
  "description": "AgentSkills Runtime JavaScript SDK (uctoo v4 compatible)",
  "main": "src/agentskills-client.js",
  "scripts": {
    "test": "jest",
    "build": "webpack --mode production"
  },
  "keywords": [
    "agentskills",
    "uctoo",
    "sdk",
    "websocket"
  ],
  "author": "UCToo",
  "license": "MIT",
  "dependencies": {
    "ws": "^8.0.0"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "webpack": "^5.0.0"
  }
}
```

**验收标准**:
- [ ] 版本号已更新为 2.0.0
- [ ] 依赖项正确
- [ ] 脚本命令正确

---

#### 任务 2.2.2：创建 CHANGELOG
**文件**: `sdk/javascript/CHANGELOG.md`

**内容**:
```markdown
# Changelog

## [2.0.0] - 2026-03-14

### Changed
- **BREAKING**: All API paths updated to use `/api/v1/uctoo/` prefix
- **BREAKING**: WebSocket endpoint changed from `/ws/chat` to `/api/v1/uctoo/ws/chat`
- Updated skill management API paths
- Updated MCP stream endpoint

### Migration Guide
See [MIGRATION.md](./MIGRATION.md) for detailed migration instructions.

### API Changes
| Old Path | New Path |
|----------|----------|
| `/skills` | `/api/v1/uctoo/agent_skills` |
| `/skills/:id` | `/api/v1/uctoo/agent_skills/:id` |
| `/skills/add` | `/api/v1/uctoo/skills/install` |
| `/skills/execute` | `/api/v1/uctoo/skills/execute` |
| `/ws/chat` | `/api/v1/uctoo/ws/chat` |
| `/mcp/stream` | `/api/v1/uctoo/mcp/stream` |
```

**验收标准**:
- [ ] CHANGELOG 已创建
- [ ] 变更记录完整
- [ ] 迁移指南链接正确

---

#### 任务 2.2.3：创建迁移指南
**文件**: `sdk/javascript/MIGRATION.md`

**内容**:
```markdown
# Migration Guide: v1.x to v2.0

This guide helps you migrate from AgentSkills SDK v1.x to v2.0.

## Breaking Changes

### 1. API Base Path

**v1.x:**
```javascript
const client = new AgentSkillsClient('localhost', 8080);
// API calls: http://localhost:8080/skills
```

**v2.0:**
```javascript
const client = new AgentSkillsClient({
  host: 'localhost',
  port: 8080,
  basePath: '/api/v1/uctoo'
});
// API calls: http://localhost:8080/api/v1/uctoo/agent_skills
```

### 2. WebSocket Endpoint

**v1.x:**
```javascript
ws://localhost:8080/ws/chat
```

**v2.0:**
```javascript
ws://localhost:8080/api/v1/uctoo/ws/chat
```

### 3. Method Changes

| Method | v1.x Path | v2.0 Path |
|--------|-----------|-----------|
| `getSkills()` | `/skills` | `/agent_skills` |
| `installSkill()` | `/skills/add` | `/skills/install` |
| `executeSkill()` | `/skills/execute` | `/skills/execute` |

## Step-by-Step Migration

1. Update SDK version in package.json
2. Update client initialization
3. Update WebSocket connection URL
4. Test all functionality
5. Deploy to production

## Need Help?

If you encounter issues during migration, please:
1. Check the [documentation](./README.md)
2. Open an issue on GitHub
3. Contact support@uctoo.com
```

**验收标准**:
- [ ] 迁移指南已创建
- [ ] 步骤清晰
- [ ] 示例代码正确

---

## 阶段三：文档更新

### 3.1 主文档

#### 任务 3.1.1：更新 README.md
**文件**: `README.md`

**修改内容**:
1. 更新 API 路径说明
2. 更新快速开始示例
3. 更新 API 端点列表
4. 添加迁移说明

**验收标准**:
- [ ] 文档已更新
- [ ] 示例代码正确
- [ ] 链接有效

---

#### 任务 3.1.2：更新 README_cn.md
**文件**: `README_cn.md`

**修改内容**:
同 README.md，但使用中文

**验收标准**:
- [ ] 文档已更新
- [ ] 翻译准确
- [ ] 示例代码正确

---

### 3.2 API 文档

#### 任务 3.2.1：更新 API 文档
**文件**: `docs/api/*.md`

**需要更新的文件**:
- `docs/api/skills-api.md`
- `docs/api/websocket-api.md`
- `docs/api/mcp-api.md`

**修改内容**:
1. 更新所有 API 路径
2. 更新请求/响应示例
3. 更新错误码说明

**验收标准**:
- [ ] 所有 API 文档已更新
- [ ] 示例正确
- [ ] 格式规范

---

### 3.3 部署文档

#### 任务 3.3.1：更新部署文档
**文件**: `docs/agentskills-api-service-run.md`

**修改内容**:
1. 更新服务启动说明
2. 更新配置说明
3. 更新健康检查端点
4. 添加迁移注意事项

**验收标准**:
- [ ] 文档已更新
- [ ] 步骤清晰
- [ ] 配置说明准确

---

#### 任务 3.3.2：更新测试文档
**文件**: `docs/agentskills-api-testing-guide.md`

**修改内容**:
1. 更新测试用例中的 API 路径
2. 更新 curl 命令示例
3. 更新预期结果

**验收标准**:
- [ ] 文档已更新
- [ ] 测试用例正确
- [ ] 示例可执行

---

### 3.4 架构文档

#### 任务 3.4.1：更新架构文档
**文件**: 
- `docs/uctoo-v4/README.md`
- `docs/uctoo-v4/uctoo-v4-architecture.md`

**修改内容**:
1. 更新架构图
2. 更新模块说明
3. 添加 API 路径规范说明
4. 更新依赖关系图

**验收标准**:
- [ ] 文档已更新
- [ ] 架构图准确
- [ ] 说明清晰

---

## 阶段四：测试验证

### 4.1 单元测试

#### 任务 4.1.1：更新单元测试
**文件**: `tests/unit/*.cj`

**修改内容**:
1. 更新测试用例中的 API 路径
2. 更新 mock 数据
3. 添加新功能的测试用例

**验收标准**:
- [ ] 所有测试通过
- [ ] 覆盖率 >= 80%
- [ ] 无警告

---

### 4.2 集成测试

#### 任务 4.2.1：更新集成测试
**文件**: `tests/integration/*.cj`

**修改内容**:
1. 更新 API 路径
2. 更新测试数据
3. 添加端到端测试用例

**验收标准**:
- [ ] 所有测试通过
- [ ] 覆盖主要功能
- [ ] 性能符合预期

---

### 4.3 性能测试

#### 任务 4.3.1：执行性能测试
**文件**: `tests/performance/*.cj`

**测试内容**:
1. API 响应时间测试
2. 并发请求测试
3. WebSocket 连接测试
4. 内存使用测试

**验收标准**:
- [ ] 响应时间 < 100ms (P95)
- [ ] 支持 1000+ 并发连接
- [ ] 内存使用稳定
- [ ] 无内存泄漏

---

## 阶段五：清理工作

### 5.1 代码清理

#### 任务 5.1.1：标记废弃代码
**文件**: `src/api/*.cj`

**处理方案**:
```cangjie
/**
 * @deprecated
 * This module has been migrated to magic.app
 * Please use magic.app.controllers.* instead
 * 
 * Migration Guide: docs/migration/api-to-app.md
 */
@Deprecated["Use magic.app.controllers instead"]
public class APIRouter {
  // ...
}
```

**验收标准**:
- [ ] 废弃标记已添加
- [ ] 迁移指南链接正确
- [ ] 编译警告正常

---

#### 任务 5.1.2：更新 cjpm.toml
**文件**: `cjpm.toml`

**修改内容**:
```toml
# 注释或删除原 api 模块配置
# [package.package-configuration."magic.api"]
# outputType = "executable"
```

**验收标准**:
- [ ] 配置已更新
- [ ] 编译正常
- [ ] 打包正常

---

### 5.2 文档清理

#### 任务 5.2.1：创建迁移总结文档
**文件**: `docs/migration/api-to-app-migration-summary.md`

**内容**:
1. 迁移概述
2. 主要变更
3. 影响范围
4. 迁移步骤
5. 常见问题
6. 联系方式

**验收标准**:
- [ ] 文档已创建
- [ ] 内容完整
- [ ] 格式规范

---

## 验收清单

### 功能验收
- [ ] 所有 API 功能正常
- [ ] WebSocket 连接正常
- [ ] MCP 流式接口正常
- [ ] 健康检查正常
- [ ] 错误处理正常

### 性能验收
- [ ] 响应时间符合要求
- [ ] 并发性能符合要求
- [ ] 内存使用稳定
- [ ] CPU 使用合理

### 文档验收
- [ ] 所有文档已更新
- [ ] 示例代码可运行
- [ ] 迁移指南完整
- [ ] API 文档准确

### SDK 验收
- [ ] SDK 功能正常
- [ ] SDK 文档完整
- [ ] SDK 测试通过
- [ ] SDK 可发布

### 代码质量验收
- [ ] 无编译错误
- [ ] 无编译警告（除废弃警告）
- [ ] 代码格式规范
- [ ] 注释完整

---

## 时间估算

| 阶段 | 任务数 | 预计时间 | 优先级 |
|-----|--------|---------|--------|
| 阶段一 | 6 | 已完成 | P0 |
| 阶段二 | 8 | 2-3 天 | P0 |
| 阶段三 | 7 | 1-2 天 | P1 |
| 阶段四 | 3 | 2-3 天 | P0 |
| 阶段五 | 3 | 1 天 | P2 |
| **总计** | **27** | **6-9 天** | - |

---

## 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|-----|------|------|---------|
| SDK 用户未及时更新 | 高 | 高 | 提供详细迁移指南，保留兼容层 |
| 文档更新遗漏 | 中 | 中 | 使用检查清单，代码审查 |
| 测试覆盖不足 | 中 | 高 | 增加测试用例，自动化测试 |
| 性能下降 | 低 | 高 | 性能测试，优化关键路径 |

---

## 联系方式

如有问题，请联系：
- 技术支持: support@uctoo.com
- GitHub Issues: https://github.com/uctoo/agentskills-runtime/issues
- 文档: https://docs.uctoo.com/agentskills
