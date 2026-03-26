# Architecture Overview

The CangjieMagic framework follows clean architecture principles with clear separation of concerns:

## Layered Architecture

### Domain Layer
Contains business logic and entities:
- SkillManifest
- SkillParameter
- ValidationResult
- Skill models and interfaces

### Application Layer
Orchestrates use cases:
- SkillLoadingService
- SkillValidationService
- SkillManagementService
- SkillParsingService

### Infrastructure Layer
Handles external concerns:
- File loading and YAML processing
- Database access
- External API integrations
- Logging and monitoring

### Presentation Layer
Manages skill and tool interactions:
- CLI commands
- API controllers
- MCP protocol handlers

## Component Structure

### Skill Module
The skill module contains all skill-related functionality:

```
skill/
├── api/                        # Skill API interfaces
├── application/                # Skill application services
│   ├── skill_loading_service.cj      # Service for loading skills from files
│   ├── skill_validation_service.cj   # Service for validating skills
│   ├── skill_management_service.cj   # Main service for skill lifecycle management
│   ├── skill_parsing_service.cj      # Core skill parsing logic
│   ├── progressive_skill_loader.cj   # Progressive skill loading from directories
│   ├── enhanced_progressive_skill_loader.cj # Enhanced progressive skill loader
│   ├── skill_factory.cj              # Skill factory and registry implementation
│   └── skill_registry.cj             # Skill registry for managing skill types
├── domain/                     # Domain layer - business logic and entities
│   ├── models/                 # Core data models
│   │   ├── skill_manifest.cj         # Model representing parsed SKILL.md content
│   │   ├── skill_parameter.cj        # Model for skill parameters
│   │   └── validation_result.cj      # Model for validation results
│   ├── interfaces/             # Domain interfaces/abstractions
│   │   ├── skill_repository.cj       # Abstraction for skill persistence
│   │   └── skill_validator.cj        # Abstraction for skill validation
│   └── services/               # Domain services with business logic
│       ├── skill_parsing_service.cj  # Core skill parsing logic
│       └── skill_management_service.cj # Core skill management logic
└── infrastructure/             # Infrastructure layer - external concerns
    ├── loaders/                # Components for loading skills from various sources
    │   ├── skill_md_loader.cj        # Loader for SKILL.md files
    │   ├── yaml_frontmatter_parser.cj # Parser for YAML frontmatter in SKILL.md
    │   └── resource_loader.cj        # Loader for external resources (scripts, references, assets)
    ├── validators/             # Validation components
    │   ├── skill_validator_impl.cj   # Implementation of skill validator interface
    │   ├── skill_manifest_validator.cj # Validator for skill manifest structure
    │   └── yaml_validator.cj         # Validator for YAML frontmatter
    ├── repositories/           # Repository implementations
    │   └── file_based_skill_repository.cj # File-based skill persistence
    ├── adapters/               # Adapters for external systems
    │   └── skill_to_tool_adapter.cj  # Adapts skills to tool interface
    └── utils/                  # Utility functions
        ├── yaml_utils.cj             # Utilities for YAML processing
        ├── file_utils.cj             # Utilities for file operations
        └── markdown_utils.cj         # Utilities for markdown processing
```

## Key Components

### HTTP/HTTPS Server
- `HTTPServer`: Core HTTP server with support for both HTTP and HTTPS modes
- **HTTP Mode**: Standard HTTP server for development and non-secure environments
- **HTTPS Mode**: Secure HTTPS server with TLS/SSL encryption for production
- **Auto-detection**: Automatically switches between HTTP and HTTPS based on `BACKEND_URL` configuration
- **Certificate Support**: Loads PEM format certificates from `./ssl/` directory
- **TLS Support**: Supports TLS 1.2 and TLS 1.3 protocols

### Skill Management
- `SkillManagementService`: Main service for managing skills throughout their lifecycle
- `SkillLoadingService`: Service for loading skills from SKILL.md files
- `ProgressiveSkillLoader`: Component for automatic discovery and loading of skills from configurable directories

### Skill Validation
- `SkillValidationService`: Service for validating skills against the agentskills specification
- `StandardSkillValidator`: Implementation of skill validation logic

### Skill Execution
- `SkillExecution`: Core logic for executing skills with proper context and security

### MCP Integration
- `MCP Server`: Model Context Protocol server for integration with AI agents
- `SkillToToolAdapter`: Adapter to make skills compatible with tool interface

## Design Patterns

### Clean Architecture
The framework follows clean architecture principles:
- Independence of frameworks
- Testable business rules
- Independence of UI
- Independence of database

### Factory Pattern
- `SkillFactory`: Creates skill instances based on skill manifest
- `SkillRegistry`: Maintains mapping of skill names to their factories

### Adapter Pattern
- `SkillToToolAdapter`: Makes skills compatible with tool interface

### Repository Pattern
- `SkillRepository`: Abstracts skill persistence operations

## Security Architecture

### WASM Sandbox
- Component Model support for secure execution
- Capability-based access control
- Resource quotas and execution limits

### Capability-Based Security
- Fine-grained permissions for resource access
- Network, filesystem, and execution controls

## Data Flow

1. SKILL.md file is loaded by `SkillLoader`
2. YAML frontmatter and markdown content are parsed by `SkillParser`
3. Skill manifest is validated by `SkillValidator`
4. Skill instance is created by `SkillFactory`
5. Skill is registered with `SkillManager`
6. Skill can be executed via `SkillToToolAdapter` when needed

---

# 完整聊天与技能执行流程

## 1. 系统架构总览

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          智能体聊天与技能执行完整架构                               │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                      用户交互层 (Web 客户端)                                     │ │
│  │  ┌───────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │  uctoo-app-client-pc (Vue 3 + Ant Design X)                              │ │ │
│  │  │  - 聊天界面 (index.vue)                                                    │ │ │
│  │  │  - WebSocket 实时通信                                                      │ │ │
│  │  │  - 技能执行与参数配置                                                      │ │ │
│  │  │  - 消息渲染与状态管理                                                      │ │ │
│  │  └───────────────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                                │
│                                    ▼                                                │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                      运行时内核层 (agentskills-runtime)                        │ │
│  │  ┌───────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │  CangjieMagic框架 (仓颉语言)                                              │ │ │
│  │  │  ┌─────────────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │ 1. 感知层 (Perception)                                             │  │ │ │
│  │  │  │    - WebSocketHandler (websocket_handler.cj)                       │  │ │ │
│  │  │  │    - 接收用户聊天消息                                               │  │ │ │
│  │  │  │    - 接收技能执行请求                                               │  │ │ │
│  │  │  └─────────────────────────────────────────────────────────────────────┘  │ │ │
│  │  │                          │                                                │ │ │
│  │  │                          ▼                                                │ │ │
│  │  │  ┌─────────────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │ 2. 决策层 (Decision Making)                                        │  │ │ │
│  │  │  │    - ReactExecutor (react_executor.cj)                             │  │ │ │
│  │  │  │    - SkillAwareAgent (skill_aware_agent.cj)                        │  │ │ │
│  │  │  │    - 大模型调用 (ChatModel)                                         │  │ │ │
│  │  │  │    - 思考 (Thought)、行动 (Action)、观察 (Observation)             │  │ │ │
│  │  │  └─────────────────────────────────────────────────────────────────────┘  │ │ │
│  │  │                          │                                                │ │ │
│  │  │                          ▼                                                │ │ │
│  │  │  ┌─────────────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │ 3. 执行层 (Execution)                                              │  │ │ │
│  │  │  │    - CompositeSkillToolManager                                     │  │ │ │
│  │  │  │    - SkillToToolAdapter                                             │  │ │ │
│  │  │  │    - SkillExecutionEngine                                           │  │ │ │
│  │  │  │    - 技能安全执行与沙箱隔离                                         │  │ │ │
│  │  │  └─────────────────────────────────────────────────────────────────────┘  │ │ │
│  │  │                          │                                                │ │ │
│  │  │                          ▼                                                │ │ │
│  │  │  ┌─────────────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │ 4. 记忆层 (Memory)                                                 │  │ │ │
│  │  │  │    - ShortMemory                                                     │  │ │ │
│  │  │  │    - MemoryService (memory/workspace/memory_service.cj)            │  │ │ │
│  │  │  │    - AgentWorkspace (agent_workspace.cj)                            │  │ │ │
│  │  │  │    - 工作空间记忆文件加载 (SOUL.md, MEMORY.md, AGENTS.md 等)        │  │ │ │
│  │  │  └─────────────────────────────────────────────────────────────────────┘  │ │ │
│  │  └───────────────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                                │
│                                    ▼                                                │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │                      大模型服务层 (LLM Providers)                              │ │
│  │  ┌───────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │  DeepSeek / OpenAI / 其他大模型                                           │ │ │
│  │  │  - 自然语言理解 (NLU)                                                     │ │ │
│  │  │  - 工具选择与决策                                                         │ │ │
│  │  │  - 参数提取与推理                                                         │ │ │
│  │  └───────────────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 2. 完整流程详解

### 阶段 1: 用户输入与 WebSocket 连接建立

**前端页面** (`apps/uctoo-app-client-pc/src/views/uctoo/chat/index.vue`):
1. 用户在聊天界面输入消息并点击"发送"
2. `onMounted()` 钩子调用 `connectWebSocket()` 建立连接
3. WebSocket 连接到 `ws://127.0.0.1:8080/ws/chat`
4. 连接建立后，前端接收 `welcome` 消息，获取 `session_id`

**前端关键代码**:
```typescript
// index.vue
onMounted(() => {
  connectWebSocket();
});

const connectWebSocket = () => {
  ws.value = new WebSocket(wsUrl.value);
  ws.value.onopen = () => { /* 连接打开 */ };
  ws.value.onmessage = handleWebSocketMessage;
};
```

---

### 阶段 2: 消息发送与接收

**用户发送消息**:
1. 前端调用 `sendMessage()` 函数
2. 构造用户消息并添加到 `messages` 数组
3. 通过 WebSocket 发送 JSON 格式的聊天请求:
   ```json
   {
     "type": "chat",
     "content": "用户输入的消息"
   }
   ```
4. 创建加载状态的助手消息，显示"正在思考..."

**后端 WebSocket 处理** (`src/api/websocket_handler.cj`):
1. `WebSocketChatHandler` 接收消息
2. 解析消息类型和内容
3. 调用 `SkillAwareAgent` 进行处理

---

### 阶段 3: 智能体决策与技能选择

**SkillAwareAgent 处理流程** (`src/skill/skill_aware_agent.cj`):
1. 接收用户查询
2. 将查询和上下文传递给大模型
3. 大模型分析用户意图，决定是否需要调用技能
4. 如果需要，选择合适的技能工具

**ReactExecutor 执行** (`src/agent_executor/react/react_executor.cj`):
- **Thought (思考)**: 分析用户需求，确定行动计划
- **Action (行动)**: 选择并调用技能工具
- **Observation (观察)**: 获取技能执行结果
- **循环执行**直到任务完成或达到最大循环次数

---

### 阶段 4: 技能执行

**技能管理** (`src/skill/composite_skill_tool_manager.cj`):
1. `CompositeSkillToolManager` 管理所有可用技能
2. 通过 `SkillToToolAdapter` 将技能转换为工具接口
3. 从 `ProgressiveSkillLoader` 加载技能

**技能安全执行** (`src/skill/skill_execution_engine.cj`):
1. 安全验证: 检查技能执行权限
2. 资源限制: 超时、内存、CPU 控制
3. 执行技能逻辑
4. 返回执行结果

---

### 阶段 5: 结果返回与前端渲染

**WebSocket 响应** (`src/api/websocket_handler.cj`):
1. 构造响应消息:
   - `chat_response`: 普通聊天回复
   - `skill_result`: 技能执行结果
   - `status`: 状态更新
2. 通过 WebSocket 发送给前端

**前端处理** (`apps/uctoo-app-client-pc/src/views/uctoo/chat/index.vue`):
1. `handleWebSocketMessage()` 接收消息
2. 根据消息类型更新 UI:
   - 更新助手消息内容
   - 显示技能执行结果
   - 处理错误状态
3. 调用 `scrollToBottom()` 滚动到底部

**技能结果消息示例**:
```json
{
  "type": "skill_result",
  "payload": {
    "skill_id": "pdf-analyzer",
    "output": "PDF 分析结果...",
    "success": "true"
  }
}
```

---

## 3. 工作空间记忆集成

**记忆系统架构** (`src/memory/workspace/`):

| 组件 | 文件 | 功能 |
|------|------|------|
| `AgentWorkspace` | `agent_workspace.cj` | 工作空间结构，包含所有记忆文件 |
| `WorkspaceLoader` | `workspace_loader.cj` | 加载 AGENTS.md, SOUL.md, MEMORY.md 等 |
| `MemoryService` | `memory_service.cj` | 记忆服务，支持追加、检索、更新 |

**工作空间文件结构**:
```
workspace/
├── AGENTS.md        # 智能体定义
├── SOUL.md          # 灵魂/人格设定
├── TOOLS.md         # 工具定义
├── IDENTITY.md      # 身份信息
├── USER.md          # 用户信息
├── MEMORY.md        # 长期记忆
├── HEARTBEAT.md     # 心跳/状态
└── memory/          # 每日记忆目录
    ├── 2026-02-22.md
    └── 2026-02-23.md
```

---

## 4. 关键数据流图

```
用户输入 (index.vue)
    │
    ▼
WebSocket 消息发送
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  agentskills-runtime (仓颉)                                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐     ┌──────────────────┐           │
│  │ WebSocketHandler │────▶│ SkillAwareAgent  │           │
│  │  (感知层)        │     │  (决策层)        │           │
│  └──────────────────┘     └──────────────────┘           │
│           │                        │                        │
│           │                        ▼                        │
│           │              ┌──────────────────┐           │
│           │              │   ReactExecutor   │           │
│           │              │   (ReAct 模式)    │           │
│           │              └──────────────────┘           │
│           │                        │                        │
│           │                        ▼                        │
│           │              ┌──────────────────┐           │
│           │              │ CompositeSkill-  │           │
│           │              │ ToolManager      │           │
│           │              └──────────────────┘           │
│           │                        │                        │
│           │                        ▼                        │
│           │              ┌──────────────────┐           │
│           │              │ SkillExecution   │           │
│           │              │ Engine           │           │
│           │              └──────────────────┘           │
│           │                        │                        │
│           ▼                        ▼                        │
│  ┌──────────────────┐     ┌──────────────────┐           │
│  │  MemoryService   │◀────│  ShortMemory     │           │
│  │  (记忆服务)      │     │  (短期记忆)      │           │
│  └──────────────────┘     └──────────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
WebSocket 响应返回
    │
    ▼
前端渲染 (index.vue)
```

---

## 5. 消息类型说明

| 消息类型 | 方向 | 说明 |
|---------|------|------|
| `welcome` | Runtime → 前端 | 连接建立成功，返回 session_id |
| `chat` | 前端 → Runtime | 用户发送聊天消息 |
| `chat_response` | Runtime → 前端 | 智能体聊天回复 |
| `list_skills` | 前端 → Runtime | 请求技能列表 |
| `skills_list` | Runtime → 前端 | 返回可用技能列表 |
| `execute_skill` | 前端 → Runtime | 执行特定技能 |
| `skill_result` | Runtime → 前端 | 技能执行结果 |
| `status` | Runtime → 前端 | 状态更新 |
| `error` | Runtime → 前端 | 错误信息 |
| `ping`/`pong` | 双向 | 心跳保活 |

---

## 6. 核心模块文件索引

| 功能模块 | 文件路径 | 说明 |
|---------|---------|------|
| 前端聊天界面 | `apps/uctoo-app-client-pc/src/views/uctoo/chat/index.vue` | Vue 3 聊天界面 |
| WebSocket 处理 | `apps/agentskills-runtime/src/api/websocket_handler.cj` | WebSocket 消息处理 |
| 技能感知 Agent | `apps/agentskills-runtime/src/skill/skill_aware_agent.cj` | 集成技能的智能体 |
| ReAct 执行器 | `apps/agentskills-runtime/src/agent_executor/react/react_executor.cj` | 思考-行动-观察循环 |
| 技能管理器 | `apps/agentskills-runtime/src/skill/composite_skill_tool_manager.cj` | 统一技能/工具管理 |
| 技能适配器 | `apps/agentskills-runtime/src/skill/skill_to_tool_adapter.cj` | 技能转工具接口 |
| 渐进式加载器 | `apps/agentskills-runtime/src/skill/application/progressive_skill_loader.cj` | 技能目录扫描加载 |
| 工作空间结构 | `apps/agentskills-runtime/src/memory/workspace/agent_workspace.cj` | 记忆文件结构定义 |
| 工作空间加载器 | `apps/agentskills-runtime/src/memory/workspace/workspace_loader.cj` | 加载工作空间文件 |
| 记忆服务 | `apps/agentskills-runtime/src/memory/workspace/memory_service.cj` | 记忆管理服务 |