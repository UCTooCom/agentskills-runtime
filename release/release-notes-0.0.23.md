# AgentSkills Runtime v0.0.23 发布说明

**发布日期**: 2026-06-22  
**版本**: 0.0.23  
**代号**: WebMCP-FullStack  
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 1. WebMCP + WebAgent + WebSkills 全链路功能

本版本采用仓颉编程语言重写 OpenTiny 技术体系中的 WebMCP 全链路功能，实现了 Agent 通过 MCP 协议调用前端注册工具的完整闭环：工具发现 → 工具调用请求转发 → 前端执行 → 结果回传 → Agent 继续推理。

#### 技术架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        前端 (web-admin)                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ TinyRemoter │  │ WebMcpClient│  │ WebMcpServer│  │navigator.MC │    │
│  │   对话框    │  │             │  │             │  │ 工具注册    │    │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
│         │                │                │                │           │
│         └────────────────┴────────────────┴────────────────┘           │
│                              │                                          │
│                    MCP 协议 (StreamableHTTP)                           │
└──────────────────────────────┼─────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              后端 (agentskills-runtime) - MCP 中枢层                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              工具链路基础设施（全新开发）                          │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────┐  │   │
│  │  │SSEConnection │ │FrontendTool  │ │PendingTool   │ │MenuData│  │   │
│  │  │   Manager    │ │   Registry   │ │  CallManager │ │Provider│  │   │
│  │  │  SSE连接管理  │ │  前端工具注册  │ │ 待处理调用管理 │ │菜单数据 │  │   │
│  │  └───────┬──────┘ └───────┬──────┘ └───────┬──────┘ └───┬────┘  │   │
│  └──────────┼────────────────┼────────────────┼─────────────┼───────┘   │
│             │                │                │             │           │
│  ┌──────────▼────────────────▼────────────────▼─────────────▼───────┐   │
│  │              协议层与工具层（改造完善）                          │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────┐  │   │
│  │  │ WebMCPProtocol││ WebNavigate  │ │WebNotifyTool │ │Frontend│  │   │
│  │  │  协议处理引擎  ││    Tool      │ │ WebRequest   │ │ToolAdapter││   │
│  │  │tools/register ││ 页面导航      │ │   Approval   │ │前端工具适配││   │
│  │  │tools/list     ││              │ │   用户审批    │ │          │  │   │
│  │  │tool/invoke    ││              │ │              │ │          │  │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘ └────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              ▼                                          │
│                    ┌─────────────────┐                                 │
│                    │  SkillAwareAgent│                                 │
│                    │  技能感知智能体  │                                 │
│                    └────────┬────────┘                                 │
└─────────────────────────────┼─────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   AI 大模型     │
                    │ Tokendance/StepFun/MaaS/OrbitAI │
                    └─────────────────┘
```

#### 核心组件

##### 1.1 SSEConnectionManager - SSE 连接管理器

- **REQ-SSE-001**: SSE 连接注册与管理 - 维护前端 SSE 连接池
- **REQ-SSE-002**: 消息推送 - 通过 SSE 向前端推送工具调用指令
- **REQ-SSE-003**: 连接状态监控 - 检测断开连接并清理资源
- **REQ-SSE-004**: 会话绑定 - 支持多会话隔离

##### 1.2 FrontendToolRegistry - 前端工具注册表

- **REQ-FTR-001**: 工具注册 - 接收前端通过 `tools/register` 注册的工具
- **REQ-FTR-002**: 工具查询 - 通过 `tools/list` 返回所有已注册工具
- **REQ-FTR-003**: 工具元数据管理 - 存储工具名称、描述、输入 Schema、路由信息
- **REQ-FTR-004**: 工具去重 - 同一路由的同名工具自动覆盖

##### 1.3 PendingToolCallManager - 待处理工具调用管理器

- **REQ-PTCM-001**: 调用记录 - 记录 Agent 发起的工具调用请求
- **REQ-PTCM-002**: 结果等待 - 阻塞等待前端执行结果回传
- **REQ-PTCM-003**: 超时处理 - 工具调用超时自动释放
- **REQ-PTCM-004**: 结果匹配 - 根据 requestId 匹配回传结果

##### 1.4 WebMCPToolContext - 工具执行上下文

- **REQ-WMTC-001**: 会话管理 - 维护会话级别的工具执行上下文
- **REQ-WMTC-002**: 连接获取 - 提供当前会话的 SSE 连接引用
- **REQ-WMTC-003**: 用户上下文 - 存储 userId 和菜单数据

##### 1.5 MenuDataProvider - 菜单数据提供者

- **REQ-MDP-001**: 用户菜单查询 - 根据 userId 获取菜单树
- **REQ-MDP-002**: 菜单扁平化 - 提供扁平化菜单列表供工具使用
- **REQ-MDP-003**: 菜单缓存 - 减少重复查询

#### 工具调用闭环流程

```
Agent 发起工具调用
        │
        ▼
┌─────────────────┐
│  ToolManager    │ ← 查找可用工具
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ WebNavigateTool │ ← invoke(args)
│ WebNotifyTool   │
│ WebRequestApproval│
│ FrontendToolAdapter│
└────────┬────────┘
         │ 获取 SSE 连接 + sessionId
         ▼
┌─────────────────┐
│ WebMCPToolContext│ ← 获取会话上下文
└────────┬────────┘
         │ 推送指令
         ▼
┌─────────────────┐
│SSEConnectionMgr │ ← SSE 推送到前端
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│PendingToolCallMgr│ ← 等待结果回传
└────────┬────────┘
         │ 结果返回
         ▼
┌─────────────────┐
│   Agent 继续    │ ← 收到结果，继续推理
└─────────────────┘
```

### 2. 前端工具注册与调用体系

实现完整的前端工具注册和调用机制。

#### 前端工具注册

| 工具名称 | 说明 | 注册位置 |
|----------|------|----------|
| `navigate_url` | 页面导航工具 | App.vue |
| `system-overview` | 系统概览工具 | App.vue |
| `query-entity-list` | Entity 列表查询 | entity-table.vue |
| `create-entity` | 创建 Entity | entity-table.vue |
| `edit-entity` | 编辑 Entity | entity-table.vue |
| `delete-entity` | 删除 Entity | entity-table.vue |
| `restore-entity` | 恢复 Entity | entity-table.vue |
| `get_skill_content` | 获取技能内容 | App.vue |

#### 工具注册流程

```
前端页面加载
        │
        ▼
registerPageTool() ← 页面工具注册
        │
        ▼
navigator.modelContext.registerTool() ← WebMCP Polyfill 注册
        │
        ▼
syncFrontendToolsToBackend() ← 通过 MCP 协议同步到后端
        │
        ▼
POST /api/v1/uctoo/webmcp/mcp
method: tools/register ← 后端 FrontendToolRegistry 存储
```

#### 工具调用流程

```
Agent 选择工具
        │
        ▼
工具调用请求 → SSE 推送 → 前端接收 → 执行工具 → POST /tool-result → 后端接收 → 返回 Agent
```

### 3. 多模型聚合网关

实现 OpenAI 兼容的多模型聚合服务端，支持多种模型提供商。

#### 支持的模型提供商

| 提供商 | 说明 | 配置方式 |
|--------|------|----------|
| Tokendance | 腾点科技大模型 | MODEL_PROVIDER=tokendance |
| StepFun | 步数科技大模型 | MODEL_PROVIDER=stepfun |
| MaaS | Model as a Service | MODEL_PROVIDER=maas |
| OrbitAI | Orbit AI 大模型 | MODEL_PROVIDER=orbitai |
| OpenAI | OpenAI 原生 | MODEL_PROVIDER=openai |

#### 模型路由架构

```
前端请求 → OpenAI 兼容接口 → 模型路由 → ChatModel 抽象层 → 具体模型提供商
```

#### 使用示例

```typescript
// 前端只需配置单一 endpoint
const llmConfig = {
  apiKey: 'sk-dummy-key',
  baseURL: `${AGENT_URL}/api/v1/ai/chat/completions`,
  providerType: 'openai',
  model: 'default',
}
```

### 4. 用户认证与上下文体系

实现基于 JWT 的用户认证和上下文管理。

#### 认证流程

```
用户登录 → UCToo 后端返回 access_token → 前端存储 → 请求携带 Authorization 头
→ JWTAuthMiddleware 解析 → 获取 userId → 设置到 WebMCPProtocol → 获取用户菜单数据
```

#### 会话上下文

每个 WebMCP 会话维护：
- **sessionId**: 会话唯一标识
- **userId**: 当前用户 ID
- **menuData**: 用户菜单数据
- **sseConnection**: SSE 连接引用

## 新增功能

### 1. tools/register 接口

前端工具注册端点，接收前端工具定义：

```json
{
  "jsonrpc": "2.0",
  "method": "tools/register",
  "params": {
    "tools": [
      {
        "name": "query-entity-list",
        "title": "查询 Entity 列表",
        "description": "查询数据库 Entity 表数据",
        "inputSchema": {
          "type": "object",
          "properties": {
            "page": { "type": "integer" },
            "size": { "type": "integer" }
          }
        },
        "route": "/database/uctoo/entity"
      }
    ]
  }
}
```

### 2. /tool-result 端点

工具执行结果回传端点：

```json
{
  "requestId": "abc-123",
  "success": true,
  "result": {
    "data": [...],
    "total": 100
  }
}
```

### 3. WebMCP 工具增强

改造以下工具，实现通过 SSE 推送指令到前端：

| 工具 | 功能 | 推送类型 |
|------|------|----------|
| `web_navigate` | 页面导航 | navigate |
| `web_notify` | 消息通知 | notify |
| `web_request_approval` | 用户审批 | approval_request |
| `FrontendToolAdapter` | 前端工具适配 | tool_invoke |

### 4. 技能感知系统提示词

`buildAgentSystemPrompt` 自动注入：
- 前端工具列表和描述
- 页面导航信息（基于菜单数据）
- 技能元数据

### 5. WebMCP Polyfill 集成

前端集成 `@mcp-b/webmcp-polyfill`，提供浏览器原生 WebMCP API：

```typescript
import { initializeWebMCPPolyfill } from '@mcp-b/webmcp-polyfill'
initializeWebMCPPolyfill()
```

## 改进

### 1. 请求体读取修复

修复 HTTPS 请求中 `bodySize` 为 None 或 0 时无法读取请求体的问题，确保 `tools/register` 请求能正确解析。

### 2. WebMCPController 增强

- 添加详细的请求体日志
- 改进 CORS 头部配置
- 支持 StreamableHTTP 和 WebSocket 双模式

### 3. 中间件优化

- `RequirePermissionMiddleware` 支持 `/webmcp/` 路径公开访问
- `CORSMiddleware` 支持自定义跨域配置

### 4. 错误处理完善

- 工具调用超时处理
- 连接断开自动清理
- 详细的错误日志

## 数据库变更

### 新增表

| 表名 | 说明 |
|------|------|
| agent_tools | Agent 工具注册表 |
| webmcp_sessions | WebMCP 会话表 |
| webmcp_tool_calls | 工具调用记录表 |

### 迁移脚本

```bash
# 运行数据库迁移
psql -d uctoo -f sql/uctooDB.sql
```

## 依赖更新

### 仓颉运行时

| 依赖 | 版本 | 说明 |
|------|------|------|
| cangjie | 1.0.4+ | 仓颉编程语言运行时 |
| fountain | latest | Web 框架 |
| f_orm | latest | ORM 框架 |
| f_aspect | latest | AOP 切面框架 |
| stdx.net.http | latest | HTTP/HTTPS 支持 |
| stdx.net.tls | latest | TLS 支持 |

### 前端依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| Vue | 3.5+ | 前端框架 |
| Pinia ORM | 1.10.2+ | 状态管理 |
| OpenTiny Vue | 3.28+ | UI 组件库 |
| OpenTiny TinyRemoter | 0.2.7+ | AI 对话组件 |
| @mcp-b/webmcp-polyfill | 2.0.0+ | WebMCP 浏览器 API |

## 迁移指南

### 从 v0.0.22 升级

1. **更新数据库表结构**
   ```bash
   # 运行完整数据库迁移脚本
   psql -d uctoo -f sql/uctooDB.sql
   ```

2. **更新环境变量**
   ```bash
   # 添加 WebMCP 相关配置
   export MODEL_PROVIDER=tokendance
   export WEB_MCP_URL=https://javatoarktsapi.uctoo.com/api/v1/uctoo/webmcp/mcp
   ```

3. **部署 Web-Admin 更新**
   ```bash
   cd apps/web-admin
   git pull
   npm install
   npm run build
   ```

4. **重启 Runtime 服务**
   ```bash
   # 使用 SDK 重新安装
   npm install @opencangjie/skills@1.0.4
   npx skills install-runtime --runtime-version 0.0.23
   npx skills restart
   ```

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~168MB
- 包含: 所有依赖 DLL

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~158MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

## 安装使用

### 使用 JavaScript SDK

```bash
# 安装 SDK
npm install @opencangjie/skills@1.0.4

# 安装 runtime
npx skills install-runtime --runtime-version 0.0.23

# 启动 runtime
npx skills start

# 注册前端工具
npx skills tool register --name "query-entity-list" --route "/database/uctoo/entity"

# 列出所有工具
npx skills tool list
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.23/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑 .env 文件配置 API 密钥和模型提供商

# 4. 运行
./bin/agentskills-runtime.exe 443
```

### 构建说明

```bash
# 构建项目（自动打包）
cjpm build

# 手动打包（可选）
cjpm run --skip-build --name magic.scripts.package_release
```

## 相关文档

| 文档 | 说明 |
|------|------|
| [WebMCP 新版完善设计](./.codeartsdoer/specs/webmcp-new-completion/design.md) | WebMCP 新版实现方案 |
| [WebMCP 工具链路闭环设计](./.codeartsdoer/specs/webmcp-tool-chain/design.md) | 工具调用闭环实现方案 |
| [AIAgent 融合设计](./.codeartsdoer/specs/aiagent-app-fusion/design.md) | 框架与 App 层融合详细设计 |
| [用户权限系统](./.codeartsdoer/specs/user-permission-system.md) | UCTOO V4 权限体系 |

## 已知问题

- 无

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区
- OpenTiny 开源社区

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

## 下一版本计划

v0.0.24 计划功能：
- DAG 调度引擎
- 错误分类与降级执行
- 技能组合 DSL
- 跨会话记忆自动加载
- 技能市场 Web UI
- 性能监控面板
- 集群部署支持
- 更多数据库支持

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)