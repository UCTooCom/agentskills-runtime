# WebMCP 新版完善 - 需求规格文档

## 1. 组件定位

### 1.1 核心职责

本组件负责完善 UCToo 系统中 agentskills-runtime（仓颉语言后端）与 web-admin（Vue3 前端）之间的 WebMCP 协议对接，基于 tiny-pro 官方最新版本的 webmcp-sdk 和 next-remoter 组件，实现 AI Agent 通过 MCP 标准协议控制 Web 应用的完整闭环。

agentskills-runtime 本身是一个聚合了多个大模型提供商（Tokendance、StepFun、MaaS、DashScope、OrbitAI、GMI Cloud 等）的 OpenAI 兼容服务端项目，前端 llmConfig 配置指向 runtime 即可，无需直接配置第三方模型 API Key。

### 1.2 技术栈升级

| 组件 | 旧版本 | 新版本 |
|------|--------|--------|
| webmcp-sdk | 旧版 doc-ai-angular | 官方最新版本（含 next-remoter, next-sdk, webmcp-cli） |
| 前端工具注册 | WebMcpServer | navigator.modelContext.registerTool（浏览器原生 API） |
| WebMCP Polyfill | 无 | @mcp-b/webmcp-polyfill@^2.0.0 |
| TinyRemoter | 复杂配置 | 简洁配置（agentRoot + llmConfig + mcpServers） |
| 后端 WebAgent | 需独立部署 | agentskills-runtime 内置（仓颉实现） |
| LLM 提供商 | 单一模型 | 多模型聚合（Tokendance、StepFun、MaaS 等） |

### 1.3 核心输入

1. **TinyRemoter 组件发送的对话请求**：通过 OpenAI 兼容 API 格式的 completion/complete 请求
2. **前端注册的工具定义**：通过 `navigator.modelContext.registerTool` 注册的前端工具元数据
3. **后端 Agent 的 AI 响应**：SkillAwareAgent 产生的流式/非流式对话内容和工具调用请求
4. **前端工具执行结果**：前端执行工具后返回的结果数据
5. **MCP 工具调用**：通过 mcpServers 配置的前端 MCP 服务器工具

### 1.4 核心输出

1. **流式 AI 响应**：以 SSE 格式逐块推送的 AI 对话内容
2. **工具列表响应**：通过 MCP 协议返回的前端工具清单
3. **前端工具调用结果**：Agent 调用前端工具后的执行结果
4. **错误响应**：符合规范的错误信息

### 1.5 职责边界

- **不负责**：AI 模型的训练和推理逻辑（由 ChatModel 和 SkillAwareAgent 承担）
- **不负责**：前端 UI 渲染和交互（由 TinyRemoter 组件承担）
- **不负责**：后端技能的具体执行逻辑（由 SkillManager 和各技能实现承担）
- **不负责**：用户认证和权限控制（由系统级中间件 JWTAuthMiddleware 承担，从 access_token 解析 userId）

### 1.6 用户认证机制

#### 1.6.1 用户 ID 获取流程

系统已在 `JWTAuthMiddleware` 中实现了从 access_token 解析用户信息的机制：

1. **认证中间件**：`JWTAuthMiddleware` 从请求头 `Authorization: Bearer <token>` 提取 JWT Token
2. **Token 验证**：验证 Token 有效性，解析出 userId、username、roles、permissions
3. **上下文注入**：将用户信息注入 HttpRequest.locals["user"]
4. **业务使用**：WebMCPController 通过 `_extractUserId()` 方法从请求中提取 userId

#### 1.6.2 userId 传递优先级

| 优先级 | 获取方式 | 说明 |
|--------|----------|------|
| 1 | 查询参数 `?userId=xxx` | 适用于调试场景 |
| 2 | 请求头 `X-User-Id` | 适用于客户端主动传递 |
| 3 | JWT Token 解析 | 默认方式，从 Authorization 头解析 |
| 4 | 空字符串 | 默认值，表示匿名用户 |

#### 1.6.3 注意事项

- Web 端调用 runtime 接口时必须携带有效的 access_token
- runtime 通过 `BACKEND_URL=https://javatoarktsapi.uctoo.com` 验证 Token 有效性
- 用户权限菜单数据通过 `getUserMenuTree(userId)` 获取，用于注入 Agent 上下文

---

## 2. 领域术语

**TinyRemoter**
: OpenTiny 官方提供的 AI 对话组件，基于 WebMCP 协议与后端 Agent 通信，支持流式对话、工具调用、会话管理等功能。

**navigator.modelContext**
: 浏览器原生 API，用于注册前端工具。TinyRemoter 会自动从中读取已注册的工具列表。

**@mcp-b/webmcp-polyfill**
: WebMCP Polyfill 库，在低版本浏览器中注入标准的 modelContext 接口，实现跨浏览器兼容。

**agentRoot**
: TinyRemoter 配置项，指向后端 WebAgent 代理服务的地址。格式如：`http://localhost:3060/api/v1/uctoo/webmcp/`

**llmConfig**
: TinyRemoter 配置项，定义与大模型通信的配置，包括 apiKey、baseURL、model、maxSteps 等。

**mcpServers**
: TinyRemoter 配置项，定义预置 MCP 服务器配置，用于注册前端工具到 MCP 协议。

**webmcp-cli**
: 官方新增的命令行工具，支持在浏览器中执行 MCP 工具调用、状态管理、标签页操作等。

**前端工具（Frontend Tool）**
: 注册在前端 Web 应用中的工具，通过 `navigator.modelContext.registerTool` 注册，由前端页面执行。

**后端技能（Backend Skill）**
: 注册在 agentskills-runtime 中的技能，由后端直接执行。

---

## 3. 架构设计

### 3.1 前端架构

```plantuml
@startuml
skinparam componentStyle rectangle

rectangle "web-admin 前端" {
  [TinyRemoter] as Remoter
  [App.vue] as App
  [navigator.modelContext] as MC
  [skills/SKILL.md] as SkillDoc
}

rectangle "WebMCP 层" {
  [initializeWebMCPPolyfill] as Polyfill
  [registerTool] as RegTool
}

rectangle "后端连接" {
  [agentRoot] as AgentRoot
  [llmConfig] as LLMConfig
  [mcpServers] as MCPServers
}

App -> Polyfill : 初始化 WebMCP Polyfill
App -> Remoter : 配置并渲染 TinyRemoter
Remoter -> MC : 注册工具
Remoter -> AgentRoot : 连接 WebAgent
Remoter -> LLMConfig : 配置 LLM
Remoter -> MCPServers : 注册 MCP 服务器
App -> SkillDoc : 加载系统技能文档

@enduml
```

### 3.2 后端架构

```plantuml
@startuml
skinparam componentStyle rectangle

rectangle "agentskills-runtime（仓颉后端）" {
  [WebMCPController] as Controller
  [WebMCPProtocol] as Protocol
  [SkillAwareAgent] as Agent
  [SkillManager] as SM
  [ChatModel] as CM
  [FrontendToolRegistry] as FTR
  [SSEConnectionManager] as SSE
}

rectangle "传输层" {
  [WebSocket] as WS
  [StreamableHTTP] as HTTP
  [SSE] as SSETransport
}

Controller -> Protocol : 消息分发
Protocol -> Agent : 对话/工具调用
Protocol -> SM : 后端技能查询/执行
Protocol -> FTR : 前端工具注册/查询
Agent -> CM : 模型推理
WS <-> Controller : WebSocket 连接
HTTP <-> Controller : HTTP 请求
SSETransport <-> Controller : SSE 流

@enduml
```

---

## 4. 核心能力

### 4.1 TinyRemoter 对话功能

#### 4.1.1 业务规则

1. **TinyRemoter 渲染规则**：在 App.vue 中正确配置并渲染 TinyRemoter 组件

   a. 验收条件：[前端应用启动] → [右下角显示 AI 助手悬浮图标，点击展开对话界面]

2. **agentRoot 配置规则**：agentRoot 必须指向后端 WebAgent 代理地址

   a. 验收条件：[agentRoot 配置] → [指向 `${AGENT_URL}/api/v1/uctoo/webmcp/`]

3. **llmConfig 配置规则**：llmConfig 必须指向 OpenAI 兼容的 LLM 接口

   a. 验收条件：[llmConfig 配置] → [baseURL 指向 `${AGENT_URL}/api/v1/ai/chat/completions`]

4. **mcpServers 配置规则**：mcpServers 配置前端 MCP 服务器

   a. 验收条件：[mcpServers 配置] → [包含前端工具的 MCP 服务器配置]

### 4.2 前端工具注册

#### 4.2.1 业务规则

1. **工具注册 API 规则**：使用 `navigator.modelContext.registerTool` 注册前端工具

   a. 验收条件：[页面 onMounted] → [注册 navigate_url 和 system-overview 工具]

2. **工具定义完整性规则**：工具定义必须包含 name、title、description、inputSchema、execute

   a. 验收条件：[工具注册] → [包含完整的工具元数据]

3. **工具执行规则**：execute 函数必须返回 `{ content: [{ type: 'text', text: string }] }` 格式

   a. 验收条件：[工具执行] → [返回符合 MCP 协议的工具结果]

### 4.3 后端 Agent 集成

#### 4.3.1 业务规则

1. **Agent 对话规则**：后端 Agent 必须能处理来自 TinyRemoter 的对话请求

   a. 验收条件：[用户在 TinyRemoter 输入消息] → [Agent 返回 AI 响应]

2. **工具调用规则**：Agent 必须能发现和调用前端工具

   a. 验收条件：[Agent 需要调用前端工具] → [通过 MCP 协议调用前端工具]

3. **会话管理规则**：支持多会话并发连接

   a. 验收条件：[多个用户同时使用] → [每个用户有独立的会话上下文]

---

## 5. DFX约束

### 5.1 性能

- TinyRemoter 首次渲染时间：≤ 2秒
- 工具注册完成时间：≤ 1秒
- Agent 首次响应时间：≤ 5秒（不含模型推理时间）
- 流式响应延迟：≤ 500ms

### 5.2 可靠性

- WebMCP Polyfill 初始化成功率：≥ 99%
- TinyRemoter 组件加载成功率：≥ 99%
- 工具调用成功率：≥ 99%

### 5.3 兼容性

- 浏览器支持：Chrome 90+, Firefox 90+, Safari 14+, Edge 90+
- 前端框架：Vue 3.5+
- 后端框架：agentskills-runtime（仓颉）

### 5.4 可维护性

- 前端工具注册代码必须简洁清晰
- 后端 WebMCP 实现必须符合 MCP 协议标准
- 所有配置必须支持环境变量覆盖

---

## 6. 开发规范

### 6.1 仓颉代码开发规范

**重要**：如果涉及到开发仓颉代码，必须使用 `cangjie-coder` 技能。

`cangjie-coder` 技能确保所有仓颉代码完全符合语言规范，并提供最佳实践指导。使用方式：

```
在对话中明确说明需要编写仓颉代码，AI 会自动调用 cangjie-coder 技能
```

### 6.2 数据库表结构变更规范

如果涉及到新增和变更数据库表结构，必须遵循 `uctoo-v4-module-development.md` 文档中的通用模块开发流程：

#### 通用模块开发流程

1. **数据库建模**：根据业务需求设计表结构以及表变更的 DDL 文件
2. **执行数据库变更**：人工执行数据库结构新增和变更
3. **刷新数据库信息**：使用 `/api/v1/uctoo/db_info/load-db-info` 接口刷新 db_info 表数据库信息
4. **生成标准 CRUD 模块**：
   - 使用 `crudgen` 生成新增表或变更表的标准 CRUD 模块
   - 使用 `crudweb` 生成 web 项目中的数据库表管理界面
5. **迭代开发**：在生成的标准模块基础上进行迭代开发

#### 数据模型定义规范

在 `src/app/models/{database}/` 目录下创建 `{Table}PO.cj` 文件，遵循 UCTOO V4 ORM 规范：

```cangjie
@DataAssist[fields]
@QueryMappersGenerator["{table_name}"]
public class {Table}PO {
    @ORMField['id']
    public var id: String = ""
    
    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()
    
    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()
    
    // ... 其他字段
}
```

### 6.3 代码扩展区域规范

- **后端模块**：自定义扩展代码写在 `//#region AutoCreateCode` 之外的区域
- **前端模块**：自定义扩展代码写在 `//#region Human-Code Preservation` 区域内

---

## 7. DFX约束

### 7.1 性能

- TinyRemoter 首次渲染时间：≤ 2秒
- 工具注册完成时间：≤ 1秒
- Agent 首次响应时间：≤ 5秒（不含模型推理时间）
- 流式响应延迟：≤ 500ms

### 7.2 可靠性

- WebMCP Polyfill 初始化成功率：≥ 99%
- TinyRemoter 组件加载成功率：≥ 99%
- 工具调用成功率：≥ 99%

### 7.3 兼容性

- 浏览器支持：Chrome 90+, Firefox 90+, Safari 14+, Edge 90+
- 前端框架：Vue 3.5+
- 后端框架：agentskills-runtime（仓颉）

---

## 8. 环境配置

### 8.1 前端环境变量

```env
# Agent 服务地址（指向 agentskills-runtime）
VITE_AGENT_ROOT=http://localhost:3060

# WebSocket 连接地址
VITE_WS_URL=http://localhost:3060/api/v1/uctoo/webmcp/mcp

# OpenAI API Key（非必需，runtime 已配置）
VITE_OPENAI_API_KEY=sk-dummy-key

# LLM 模型名称（通过 runtime 动态配置）
VITE_OPENAI_MODEL=default
```

### 8.2 后端环境变量

```env
# 服务端口（本地开发使用 443，需配置 SSL）
PORT=443

# UCToo 后端 API URL（用于 Token 验证和数据查询）
BACKEND_URL=https://javatoarktsapi.uctoo.com

# SSL 证书配置（HTTPS 必须）
CERT_FILE_NAME=ssl/javatoarktsapi.uctoo.com_bundle.crt
KEY_FILE_NAME=ssl/javatoarktsapi.uctoo.com.key

# 前端跨域配置
FRONTEND_URL=http://localhost:3031

# ============================================
# LLM 模型配置（runtime 聚合多模型提供商）
# ============================================

# 默认模型提供商
MODEL_PROVIDER=tokendance
MODEL_NAME=deepseek-v4-pro
MODEL_CONFIG=tokendance:deepseek-v4-pro

# Tokendance 大模型聚合平台
TOKENDANCE_API_KEY=sk-xxx
TOKENDANCE_BASE_URL=https://tokendance.space/gateway/v1

# StepFun 大模型平台
STEPFUN_API_KEY=xxx
STEPFUN_BASE_URL=https://api.stepfun.com/v1

# 华为云 MaaS
MAAS_API_KEY=xxx
MAAS_BASE_URL=https://api.modelarts-maas.com/v2

# OrbitAI
ORBITAI_API_KEY=sk-xxx
ORBITAI_BASE_URL=https://aiapi.orbitai.global/v1

# ============================================
# Token 配置
# ============================================
ACCESS_TOKEN_VALIDITY_SEC=1728000    # 20天
REFRESH_TOKEN_VALIDITY_SEC=6048000   # 70天
AUTH_CORE_SECRET=uctoo
TOKEN_ISSUER=demoapi.uctoo.com
TOKEN_AUDIENCE=uctoo.com

# ============================================
# WebMCP 配置
# ============================================
WEBMCP_REQUEST_TIMEOUT=600    # WebMCP 请求超时时间（秒）

# ============================================
# 数据库配置
# ============================================
DATABASE_URL=postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo
```

---

## 9. 测试验证

### 9.1 前端测试

1. **TinyRemoter 渲染测试**

   ```bash
   # 启动前端
   cd apps/web-admin/web && npm start
   
   # 验证
   # 1. 右下角显示 AI 助手图标
   # 2. 点击图标展开对话界面
   # 3. 输入消息测试对话功能
   ```

2. **前端工具注册测试**

   ```javascript
   // 在浏览器控制台执行
   navigator.modelContext.listTools()
   // 应该看到 navigate_url 和 system-overview 工具
   ```

### 9.2 后端测试

1. **WebMCP 端点测试**

   ```bash
   # 健康检查
   curl http://localhost:3060/api/v1/uctoo/webmcp/health
   
   # 会话数量
   curl http://localhost:3060/api/v1/uctoo/webmcp/sessions/count
   ```

2. **Agent 对话测试**

   ```bash
   # 发送测试消息
   curl -X POST http://localhost:3060/api/v1/ai/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"messages":[{"role":"user","content":"你好"}],"stream":false}'
   ```

### 9.3 集成测试

1. **完整对话流程测试**

   - 用户在 TinyRemoter 输入："帮我查询 entity 表的前10条数据"
   - Agent 理解意图并调用工具
   - 前端工具执行查询
   - 返回查询结果给用户

2. **页面导航测试**

   - 用户在 TinyRemoter 输入："跳转到用户管理页面"
   - Agent 调用 navigate_url 工具
   - 前端执行路由跳转
   - 页面成功导航到目标页面
