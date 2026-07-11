# WebMCP 新版完善 - 实现方案文档

## 1. 实现模型

### 1.1 技术栈概览

| 层级 | 组件 | 技术选型 | 说明 |
|------|------|----------|------|
| 前端框架 | Vue 3 | TypeScript | 基于 tiny-pro 官方模板 |
| 对话组件 | TinyRemoter | @opentiny/next-remoter@0.2.7 | 官方最新版本 |
| WebMCP | navigator.modelContext | @mcp-b/webmcp-polyfill@2.0.0 | 浏览器原生 API |
| 后端框架 | agentskills-runtime | 仓颉语言 | 自研 WebAgent，聚合多模型提供商 |
| AI 模型 | ChatModel | OpenAI 兼容 | 支持 Tokendance、StepFun、MaaS、OrbitAI 等多模型 |

### 1.1.1 多模型聚合架构

agentskills-runtime 作为 OpenAI 兼容的多模型聚合服务端，前端只需配置单一 endpoint，runtime 内部根据配置选择具体模型提供商：

```plantuml
@startuml
skinparam componentStyle rectangle

rectangle "前端 (web-admin)" {
  [TinyRemoter] as Remoter
}

rectangle "agentskills-runtime（多模型聚合网关）" {
  [OpenAI 兼容接口] as API
  [模型路由] as Router
  [ChatModel 抽象层] as ChatModel
}

rectangle "模型提供商" {
  [Tokendance] as Tokendance
  [StepFun] as StepFun
  [MaaS] as MaaS
  [OrbitAI] as OrbitAI
}

Remoter -> API : POST /api/v1/ai/chat/completions
API -> Router : 根据 MODEL_PROVIDER 路由
Router -> ChatModel : 调用对应模型
ChatModel -> Tokendance : API 调用
ChatModel -> StepFun : API 调用
ChatModel -> MaaS : API 调用
ChatModel -> OrbitAI : API 调用

@enduml
```

### 1.1.2 用户认证架构

```plantuml
@startuml
skinparam componentStyle rectangle

rectangle "前端 (web-admin)" {
  [用户登录] as Login
  [存储 access_token] as TokenStore
}

rectangle "agentskills-runtime" {
  [JWTAuthMiddleware] as JWT
  [WebMCPController] as Controller
  [WebMCPProtocol] as Protocol
}

rectangle "UCToo 后端" {
  [BACKEND_URL=https://javatoarktsapi.uctoo.com] as Backend
}

Login -> Backend : 登录请求
Backend --> Login : 返回 access_token
Login -> TokenStore : 存储 Token
TokenStore -> Controller : 请求携带 Authorization 头
Controller -> JWT : 解析 access_token
JWT -> Controller : 返回 userId
Controller -> Protocol : 设置 userId
Protocol -> Protocol : 获取用户菜单数据

@enduml
```

### 1.2 前端实现方案

#### 1.2.1 main.ts 修改

```typescript
// 1. 导入 WebMCP Polyfill
import { initializeWebMCPPolyfill } from '@mcp-b/webmcp-polyfill'

// 2. 在应用启动前初始化
initializeWebMCPPolyfill()

// 3. 创建 Vue 应用
const app = createApp(App)
app.use(router)
app.use(store)
// ...
app.mount('#app')
```

#### 1.2.2 App.vue 配置

```vue
<script setup lang="ts">
import { TinyRemoter } from '@opentiny/next-remoter'
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { skills, uctooOperatorSkillText } from '@/skills'
import { sleep } from '@/utils/base-utils'

// 环境配置
// runtime 服务地址，前端统一指向 runtime，由 runtime 内部聚合多模型
const AGENT_URL = import.meta.env.VITE_AGENT_ROOT || 'http://localhost:3060'

// 智能体对话框显示状态
const showRemoter = ref(false)

// TinyRemoter 配置
// llmConfig 只需指向 runtime 的 OpenAI 兼容接口
// runtime 内部已配置多模型提供商（Tokendance、StepFun、MaaS、OrbitAI 等）
const llmConfig = {
  apiKey: import.meta.env.VITE_OPENAI_API_KEY || 'sk-dummy-key',
  baseURL: `${AGENT_URL}/api/v1/ai/chat/completions`,
  providerType: 'openai' as const,
  model: 'default',
  maxSteps: 30,
}

const mcpServers = {
  'local-tools': {
    url: `${AGENT_URL}/api/v1/uctoo/webmcp/mcp`,
    name: '本地工具',
    description: '前端页面工具集，包含页面导航和系统概览',
  },
}

const systemPrompt = `你是一个智能助手，工作地点是深圳。你的主要职责是：
1. 理解用户的自然语言请求
2. 调用前端工具（navigate_url）跳转到相应的页面
3. 使用 system-overview 工具获取系统功能概览
4. 指导用户完成业务操作

可用工具：
- navigate_url: 跳转到指定URL
- system-overview: 获取系统功能概览`

// 工具注册
onMounted(() => {
  navigator.modelContext.registerTool({
    name: 'navigate_url',
    title: '导航到指定URL',
    description: '当需要的工具在当前页面不可用时，使用此工具跳转到特定页面。例如：要跳转到 "/vue-pro/userManager/allInfo" 用户管理页面。',
    inputSchema: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'URL' },
      },
      required: ['url'],
    },
    execute: async ({ url }) => {
      router.push(url)
      await sleep(1000)
      return { content: [{ type: 'text', text: `收到: ${url}` }] }
    },
  })

  navigator.modelContext.registerTool({
    name: 'system-overview',
    title: '系统概览',
    description: '整体介绍网站的模块、路由、页面工具、使用规范等等内容',
    execute: async () => {
      return { content: [{ type: 'text', text: uctooOperatorSkillText }] }
    },
  })
})
</script>

<template>
  <TinyRemoter
    v-model:show="showRemoter"
    :session-id="'uctoo-session-' + Date.now()"
    title="UCTOO 智能助手"
    :system-prompt="systemPrompt"
    :llm-config="llmConfig"
    :mcp-servers="mcpServers"
    :skills="skills"
    mode="remoter"
  />
</template>
```

### 1.3 后端实现方案

#### 1.3.1 WebMCPController 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/v1/uctoo/webmcp/mcp` | GET | WebSocket 连接 |
| `/api/v1/uctoo/webmcp/mcp` | POST | StreamableHTTP |
| `/api/v1/ai/chat/completions` | POST | OpenAI 兼容接口 |
| `/api/v1/uctoo/webmcp/health` | GET | 健康检查 |
| `/api/v1/uctoo/webmcp/sessions/count` | GET | 会话统计 |

#### 1.3.3 用户 ID 提取机制

后端通过 `WebMCPController._extractUserId()` 方法提取用户 ID，支持多种获取方式：

```cangjie
/**
 * 从 HttpRequest 中提取用户 ID
 * 优先级：查询参数 userId > 请求头 X-User-Id > JWT Token 解析 > 空字符串
 */
private func _extractUserId(req: HttpRequest): String {
    // 1. 查询参数 ?userId=xxx
    let queryOpt = req.queryParam("userId")
    if (queryOpt.isSome()) {
        let userId = queryOpt.getOrThrow()
        if (!userId.isEmpty()) {
            return userId
        }
    }
    // 2. 请求头 X-User-Id
    let headerOpt = req.header("X-User-Id")
    if (headerOpt.isSome()) {
        return headerOpt.getOrThrow()
    }
    // 3. JWT Token 解析（通过 JWTAuthMiddleware 注入）
    let userOpt = req.locals("user")
    if (userOpt.isSome()) {
        let user = userOpt.getOrThrow() as JWTPayload
        if (!user.userId.isEmpty()) {
            return user.userId
        }
    }
    // 4. 默认空字符串
    return ""
}
```

#### 1.3.4 用户菜单数据注入

当 userId 有效时，后端会从 UCToo 后端获取用户菜单数据并注入到 Agent 上下文：

```cangjie
public func injectMenuContextToAgent(): Unit {
    if (_menuDataProvider.isNone() || _userId.isEmpty()) {
        LogUtils.warn("[WebMCPProtocol] Cannot inject menu context")
        return
    }
    let menuProvider = _menuDataProvider.getOrThrow()
    let menuTree = menuProvider.getUserMenuTree(_userId)
    // 将菜单数据注入到 Agent 的系统提示中
    // 使 Agent 了解用户可访问的页面和功能
}
```

### 1.4 数据流设计

```plantuml
@startuml
skinparam componentStyle rectangle

actor "用户" as User
participant "TinyRemoter" as Remoter
participant "navigator.modelContext" as MC
participant "WebMCPController" as Controller
participant "WebMCPProtocol" as Protocol
participant "SkillAwareAgent" as Agent
participant "ChatModel" as Model

User -> Remoter : 输入消息
Remoter -> Remoter : 读取 navigator.modelContext 工具
Remoter -> Controller : POST /api/v1/ai/chat/completions
Controller -> Protocol : handleChatRequest
Protocol -> Agent : chat(AgentRequest)
Agent -> Model : createChatCompletion
Model --> Agent : AI 响应
Agent --> Protocol : toolCalls 或 content
Protocol --> Controller : 响应数据
Controller --> Remoter : 流式/非流式响应
Remoter --> MC : 读取工具列表
Remoter -> MC : 调用工具
MC -> Remoter : 工具执行结果
Remoter --> User : 显示结果

@enduml
```

---

## 2. 组件设计

### 2.1 前端组件

#### 2.1.1 TinyRemoter 配置类

```typescript
interface LLMConfig {
  apiKey: string
  baseURL: string
  providerType: 'openai' | 'deepseek'
  model: string
  maxSteps: number
}

interface MCPServerConfig {
  url: string
  name: string
  description?: string
}
```

#### 2.1.2 工具注册接口

```typescript
interface ToolDefinition {
  name: string
  title: string
  description: string
  inputSchema: {
    type: 'object'
    properties: Record<string, any>
    required: string[]
  }
  execute: (params: any) => Promise<{
    content: Array<{ type: 'text'; text: string }>
  }>
}
```

### 2.2 后端组件

#### 2.2.1 WebMCPProtocol 类

```cangjie
public class WebMCPProtocol {
    private let _skillManager: SkillManager
    private let _chatModel: ChatModel
    private let _agent: ?SkillAwareAgent
    private let _frontendToolRegistry: FrontendToolRegistry
    private let _sseConnectionManager: SSEConnectionManager
    
    // 核心方法
    public func handleMessage(body: String): String
    public func handleGetTools(obj: JsonObject): String
    public func handleInvokeTool(obj: JsonObject): String
    public func handleCompletionComplete(obj: JsonObject): String
    public func handleToolsRegister(obj: JsonObject): String
}
```

#### 2.2.2 FrontendToolRegistry 类

```cangjie
public class FrontendToolRegistry {
    private let _tools: HashMap<String, FrontendTool>
    
    public func registerTool(tool: FrontendTool): Unit
    public func unregisterTool(name: String): Unit
    public func getTool(name: String): ?FrontendTool
    public func listTools(): Array<FrontendTool>
}
```

---

## 3. 接口设计

### 3.1 OpenAI 兼容接口

**POST /api/v1/ai/chat/completions**

```json
// 请求
{
  "messages": [
    {"role": "system", "content": "你是一个智能助手"},
    {"role": "user", "content": "查询用户列表"}
  ],
  "model": "default",
  "stream": true
}

// 响应（非流式）
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "已为您查询到5个用户..."
    }
  }]
}
```

### 3.2 MCP 协议接口

**tools/list**

```json
// 请求
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "params": {},
  "id": 1
}

// 响应
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "navigate_url",
        "description": "跳转到指定URL",
        "inputSchema": {
          "type": "object",
          "properties": {
            "url": {"type": "string"}
          }
        },
        "annotations": {
          "isFrontendTool": true
        }
      }
    ]
  },
  "id": 1
}
```

---

## 4. 错误处理

### 4.1 前端错误处理

| 错误类型 | 用户提示 | 处理方式 |
|----------|----------|----------|
| 连接失败 | "AI 服务连接失败" | 显示重连按钮 |
| 工具调用失败 | "工具执行失败" | 显示错误详情 |
| 会话超时 | "会话已过期" | 重新创建会话 |

### 4.2 后端错误处理

| 错误码 | 说明 | 处理方式 |
|--------|------|----------|
| -32700 | Parse error | 返回错误响应 |
| -32600 | Invalid Request | 返回错误响应 |
| -32603 | Internal error | 记录日志，返回错误 |

---

## 5. 配置说明

### 5.1 前端配置

```typescript
// 环境变量 (.env)
// 前端只需配置 runtime 地址，无需直接配置第三方模型 API Key
VITE_AGENT_ROOT=http://localhost:3060
VITE_WS_URL=http://localhost:3060/api/v1/uctoo/webmcp/mcp
VITE_OPENAI_API_KEY=sk-dummy-key    // 非必需，runtime 已配置
VITE_OPENAI_MODEL=default           // 通过 runtime 动态配置
```

### 5.2 后端配置

```env
# ============================================
# 服务基础配置
# ============================================
PORT=443                                # 服务端口（本地开发使用 HTTPS）
BACKEND_URL=https://javatoarktsapi.uctoo.com  # UCToo 后端 API 地址
FRONTEND_URL=http://localhost:3031      # 前端跨域配置

# ============================================
# SSL 证书配置（HTTPS 必须）
# ============================================
CERT_FILE_NAME=ssl/javatoarktsapi.uctoo.com_bundle.crt
KEY_FILE_NAME=ssl/javatoarktsapi.uctoo.com.key

# ============================================
# LLM 模型配置（多模型聚合）
# ============================================
MODEL_PROVIDER=tokendance              # 默认模型提供商
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

### 5.3 模型提供商切换

runtime 支持通过环境变量动态切换模型提供商：

| 提供商 | MODEL_PROVIDER | MODEL_NAME | 说明 |
|--------|----------------|------------|------|
| Tokendance | tokendance | deepseek-v4-pro | 默认推荐，聚合多模型 |
| StepFun | stepfun | stepfun-xxx | StepFun 平台模型 |
| MaaS | maas | qwen3-coder-480b-a35b-instruct | 华为云模型 |
| OrbitAI | orbitai | orbitai-xxx | OrbitAI 平台模型 |

---

## 6. 开发规范

### 6.1 仓颉代码开发规范

**重要**：如果涉及到开发仓颉代码，必须使用 `cangjie-coder` 技能。

`cangjie-coder` 技能遵循四步工作流程：
1. 查阅 CangjieSkills 技能
2. 检索代码片段
3. 编辑适配
4. 写入文件

该技能确保所有仓颉代码完全符合语言规范，并提供最佳实践指导。

### 6.2 数据库表结构变更规范

如果涉及到新增和变更数据库表结构，必须遵循 `uctoo-v4-module-development.md` 文档中的通用模块开发流程：

```
步骤1: 数据库建模 → 设计表结构和 DDL 文件
步骤2: 执行数据库变更 → 人工执行 DDL
步骤3: 刷新数据库信息 → 调用 /api/v1/uctoo/db_info/load-db-info
步骤4: 生成标准模块 → 使用 crudgen 和 crudweb
步骤5: 迭代开发 → 在生成代码基础上扩展
```

### 6.3 代码扩展区域规范

| 项目类型 | 扩展区域 | 说明 |
|----------|----------|------|
| 后端模块 | `//#region AutoCreateCode` 之外 | 自动生成代码在区域内，自定义代码在区域外 |
| 前端模块 | `//#region Human-Code Preservation` 内 | 自定义代码写在保护区域内，避免被覆盖 |

### 6.4 参考文档

- **仓颉语言规范**：`apps/CangjieMagic/resource/` 目录
- **模块开发规范**：`apps/agentskills-runtime/docs/uctoo-v4/uctoo-v4-module-development.md`
- **数据库设计规范**：`apps/agentskills-runtime/sql/uctooDB.sql`
- **API 设计规范**：`apps/agentskills-runtime/docs/uctoo-v4/uctoo-v4-api-specification.md`
