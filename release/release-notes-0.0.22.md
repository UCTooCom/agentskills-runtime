# AgentSkills Runtime v0.0.22 发布说明

**发布日期**: 2026-06-16  
**版本**: 0.0.22  
**代号**: AIAgent-Fusion  
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 1. AIAgent 框架与 App 层全栈有机融合

本版本实现了 CangjieMagic Agent 框架层与 UCToo V4 App 层的运行时桥接，以数据库为数据流枢纽，实现全栈数据同构（通模一体）。

#### 核心特性

- **Agent 运行时桥接**: 数据库 agents 表与内存 Agent 实例双向同步
- **AgentGroup 可视化管理**: 支持多种协作模式（leader/linear/free/auto_discuss/round_robin）
- **Memory 数据库持久化**: 记忆内容同时写入向量数据库和 PostgreSQL
- **Crontab 驱动长任务**: 支持暂停/恢复/超时/重试控制

#### 融合架构

```
┌─────────────────────────────────────────────────────────────┐
│                    UCToo V4 App 层                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │PostgreSQL│  │   CRUD   │  │SyncManager│  │  Crontab │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │             │             │          │
│       └─────────────┴─────────────┴─────────────┘          │
│                            │                                │
│                            ▼                                │
│                    ┌──────────────┐                        │
│                    │Runtime Bridge│                        │
│                    └──────┬───────┘                        │
└───────────────────────────┼─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   CangjieMagic 框架层                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Agent   │  │  Skill   │  │  Memory  │  │   Tool   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### 核心功能

##### Agent 运行时桥接

- **REQ-BRIDGE-001**: Agent 运行时实例创建 - 数据库 agents 表与内存实例同步
- **REQ-BRIDGE-002**: Agent 运行时状态同步 - 开始/完成/失败/暂停状态自动同步
- **REQ-BRIDGE-003**: Agent 从数据库恢复 - 系统重启后自动重建运行时实例

##### Memory 分层存储

- **工作记忆（Working）**: 存储在 AgentContexts 表
- **情景记忆（Episodic）**: 存储在 agent_memories 表，标记为 episodic
- **语义记忆（Semantic）**: 存储在 agent_memories 表，权重更高
- **程序记忆（Procedural）**: 存储在 agent_memories 表，标记为 procedural

### 2. Agent 动态生成与多 Agent 协作系统

支持从 AGENTS.md 声明文件动态生成主 Agent，通过命令行工具和 API 动态生成 SubAgent。

#### AGENTS.md 文件格式

```yaml
---
name: CodeAnalyzer
description: 代码分析 Agent
type: analyzer
model: gpt-4o
tools:
  - file_read
  - file_search
system_prompt: |
  你是一个专业的代码分析师...
---

# CodeAnalyzer Agent

## 职责

分析代码质量和安全性...

## 工作流程

1. 读取代码文件
2. 分析代码结构
3. 输出分析报告
```

#### 核心功能

- **REQ-AGENTS-MD-001**: AGENTS.md 格式定义 - YAML frontmatter + Markdown 内容结构
- **REQ-AGENTS-MD-002**: AGENTS.md 加载机制 - 应用启动时自动加载
- **REQ-SUBAGENT-001**: 命令行工具生成 SubAgent
- **REQ-SUBAGENT-002**: API 接口生成 SubAgent
- **REQ-SUBAGENT-003**: SubAgent 声明文件格式

#### Agent 协作模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| leader | 主 Agent 协调模式 | 复杂任务分解 |
| linear | 线性链式执行 | 顺序处理流程 |
| free | 自由协作模式 | 灵活的任务分配 |
| auto_discuss | 自动讨论模式 | 多角度分析 |
| round_robin | 轮询执行模式 | 负载均衡 |

#### 使用示例

```bash
# 从 AGENTS.md 加载主 Agent
skills agent load --file ./AGENTS.md

# 动态创建 SubAgent
skills agent create --type analyzer --name "CodeAnalyzer"

# 查看 Agent 列表
skills agent list

# 启动/停止 Agent
skills agent start <agent_id>
skills agent stop <agent_id>
```

### 3. 文件系统与数据库双向同步 MVP

实现 Agent/AgentSkill 实体的文件系统与数据库双向数据同步，采用"最后写入胜出"策略解决冲突。

#### 同步机制

| 同步方向 | 触发时机 | 实现方式 |
|----------|----------|----------|
| 文件系统 → 数据库 | 启动初始化、定时扫描、手动触发 | Upsert 语义 |
| 数据库 → 文件系统 | AOP 拦截业务 DAO | 覆盖写语义 |

#### 核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                    同步管理器 (SyncManager)                   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   变更检测器    │  │   AOP 拦截器    │  │  数据映射器  │ │
│  │  (定时扫描)     │  │  (f_aspect)     │  │  (双向转换)  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 同步特性

- **幂等性保证**: Upsert 语义确保重复执行结果一致
- **循环同步防护**: SyncContext 标记防止递归同步
- **拓扑排序**: 被依赖实体先同步（如 agent_skill 依赖 agent）
- **冲突解决**: Last-Write-Wins 以时间戳较晚的版本为准

#### 使用示例

```bash
# 手动触发同步
skills sync --mode fs_to_db
skills sync --mode db_to_fs

# 查看同步状态
skills sync --status

# 重试失败同步
skills sync --retry
```

### 4. WebMCP 协议完善

修复并完善 WebMCP 工具调用链，支持 Agent 专用工具。

#### 新增工具

| 工具名称 | 说明 | 优先级 |
|----------|------|--------|
| `web_navigate` | Agent 控制前端页面导航 | P0 |
| `web_notify` | Agent 通知前端显示消息 | P0 |
| `web_request_approval` | Agent 请求用户审批 | P0 |
| `agent_control` | Agent 启动/停止/暂停/恢复 | P1 |
| `task_monitor` | 任务进度查看 | P1 |
| `memory_browse` | 记忆浏览和搜索 | P1 |

#### 工具调用链

```
Agent → WebMcpClient → WebAgent → WebMcpServer → 前端工具
                                                    ↓
Agent ← WebMcpClient ← WebAgent ← WebMcpServer ← 前端工具
```

#### 前端集成示例

```javascript
// App.vue 配置
const llmConfig = ref({
  apiKey: import.meta.env.VITE_OPENAI_API_KEY,
  baseURL: `${AGENT_URL}/api/v1/uctoo/webmcp/mcp`,
  maxSteps: 30,
  timeout: 600000, // 10分钟超时
})

// 处理 WebNotifyTool 通知
async function handleWebNotify(params) {
  const message = params.message || '通知消息'
  const notifyType = params.type || 'info'
  // 显示通知...
}

// 处理 WebRequestApprovalTool 审批
async function handleApprovalRequest(params) {
  const requestId = params.request_id
  const content = params.content
  // 显示审批对话框...
}
```

### 5. 人机协作增强

实现人在回路（Human-in-the-loop）交互机制。

#### 审批流程

```
Agent 请求审批 → WebSocket 推送 → 用户审批 → 结果返回 Agent
```

#### 审批操作

| 操作 | 说明 |
|------|------|
| 确认 | 同意 Agent 请求，继续执行 |
| 拒绝 | 拒绝 Agent 请求，终止执行 |
| 修改后确认 | 修改参数后同意请求 |

#### 审批数据表

```sql
CREATE TABLE agent_approvals (
    id uuid PRIMARY KEY,
    agent_id uuid NOT NULL,
    task_id uuid,
    request_type varchar NOT NULL,
    content text NOT NULL,
    status int DEFAULT 0,  -- 0:待审批, 1:已批准, 2:已拒绝
    response_content text,
    approver_id uuid,
    approved_at timestamptz,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP
);
```

## 新增功能

### 1. Agent 执行事件实时通知

通过 WebSocket 将 Agent 执行事件实时推送到前端：

| 事件类型 | 说明 |
|----------|------|
| AgentStart | Agent 开始执行 |
| AgentEnd | Agent 执行完成 |
| AgentStep | Agent 执行步骤 |
| ToolCallStart | 工具调用开始 |
| ToolCallEnd | 工具调用结束 |
| AgentTimeout | Agent 执行超时 |
| UserInput | 需要用户输入 |

### 2. Token 使用记录与计费

实现 LLM 调用 Token 使用量的完整记录和计费功能：

- **REQ-BILLING-001**: LLM 调用 Token 记录 - 持久化到 llm_usage_logs 表
- **REQ-BILLING-002**: 模型提供商费率配置 - model_pricing 表存储各模型单价
- **REQ-BILLING-003**: Token 用量多维统计 - 按 Agent/模型/用户/时间维度统计
- **REQ-BILLING-005**: Token 用量配额控制 - 硬限制/软限制/告警阈值

#### 计费字段

| 字段 | 说明 |
|------|------|
| prompt_tokens | 输入 token 数 |
| completion_tokens | 输出 token 数 |
| total_tokens | 总 token 数 |
| time_cost | 调用耗时（毫秒） |
| cost | 计算费用 |

### 3. 执行策略 API

AgentExecutor 提供五种执行策略的注册、查询和配置：

| 策略名称 | 说明 |
|----------|------|
| naive | 朴素执行策略 |
| react | ReAct 推理策略 |
| plan-react | 计划 + ReAct 策略 |
| tool-loop | 工具循环策略 |
| dsl | DSL 执行策略 |

### 4. 前端模型自动生成

实现后端 PO 与前端 pinia-orm 模型的自动同构生成：

- **REQ-UMI-001**: 从 db_info 表读取表结构，生成前端模型文件
- **REQ-UMI-002**: 启动时校验前后端字段一致性

## 改进

### 1. 超时配置优化

- Runtime WebMCP 请求超时：120秒 → 300秒
- Web 端请求超时：5分钟 → 10分钟
- 支持 Agent 长任务执行

### 2. 路径处理增强

- 内置工具路径检测流程
- 自动转换为绝对路径
- 防止目录检测错误

### 3. 编译错误修复

修复仓颉语法错误：
- 修复 `for (i in 0..<lines.size)` 语法问题
- 修正为 `for (i in 0..lines.size-1)`

### 4. 工具注册机制

- 内置工具自动注册
- 工具管理器初始化优化
- Agent 可正确发现和使用工具

## 数据库变更

### 新增表

| 表名 | 说明 |
|------|------|
| agents | Agent 定义表 |
| agent_contexts | Agent 上下文表 |
| agent_tasks | Agent 任务表 |
| agent_memories | Agent 记忆表 |
| agent_approvals | Agent 审批表 |
| llm_usage_logs | LLM 使用记录表 |
| model_pricing | 模型费率配置表 |
| sync_status | 同步状态表 |
| sync_log | 同步日志表 |

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

### 前端依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| Vue | 3.5+ | 前端框架 |
| Pinia ORM | 1.10.2+ | 状态管理 |
| OpenTiny Vue | 3.28+ | UI 组件库 |
| OpenTiny TinyRobot | latest | AI 对话组件 |
| OpenTiny TinyAgent | latest | AI Agent 组件 |

## 迁移指南

### 从 v0.0.21 升级

1. **更新数据库表结构**
   ```bash
   # 运行完整数据库迁移脚本
   psql -d uctoo -f sql/uctooDB.sql
   ```

2. **更新环境变量**
   ```bash
   # 添加 WebMCP 相关配置
   export WEBMCP_TIMEOUT=300000
   export LLM_API_KEY=your_api_key
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
   npm install @opencangjie/skills@1.0.3
   npx skills install-runtime --runtime-version 0.0.22
   npx skills restart
   ```

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~165MB
- 包含: 所有依赖 DLL

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~155MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

## 安装使用

### 使用 JavaScript SDK

```bash
# 安装 SDK
npm install @openangjie/skills@1.0.3

# 安装 runtime
npx skills install-runtime --runtime-version 0.0.22

# 启动 runtime
npx skills start

# 创建 Agent
npx skills run agent-creator --name "MyAgent"

# 触发同步
npx skills run sync-manager --mode fs_to_db
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.22/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑 .env 文件配置 API 密钥

# 4. 运行
./bin/agentskills-runtime.exe 8080
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
| [AIAgent 融合设计](./.codeartsdoer/specs/aiagent-app-fusion/design.md) | 框架与 App 层融合详细设计 |
| [Agent 动态生成设计](./.codeartsdoer/specs/agents/design.md) | Agent 生成与协作系统设计 |
| [文件系统同步设计](./.codeartsdoer/specs/filesystem-database-sync-mvp/design.md) | 双向同步 MVP 设计 |
| [用户权限系统](./.codeartsdoer/specs/user-permission-system.md) | UCTOO V4 权限体系 |

## 已知问题

- 无

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

## 下一版本计划

v0.0.23 计划功能：
- DAG 调度引擎
- 错误分类与降级执行
- 技能组合 DSL
- 跨会话记忆自动加载
- 技能市场Web UI
- 性能监控面板
- 集群部署支持
- 更多数据库支持

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
