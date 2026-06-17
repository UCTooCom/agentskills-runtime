# Agent 动态生成与多 Agent 协作系统 - 技术设计文档

## 文档信息
- **项目名称**: Agent 动态生成与多 Agent 协作系统
- **版本**: 1.0.0
- **创建日期**: 2026-05-29
- **作者**: SDD Agent
- **状态**: 草稿
- **关联需求**: spec.md v1.0

---

# **1. 实现模型**

## **1.1 上下文视图**

### 系统上下文图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Agent 系统上下文视图                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────┐     ┌──────────────┐     ┌──────────────┐               │
│  │   CLI 终端  │────>│   HTTP API   │────>│   数据库      │               │
│  │  (管理员)   │     │ /api/v1/...  │     │  PostgreSQL  │               │
│  └────────────┘     └──────────────┘     └──────────────┘               │
│                          │                        │                     │
│                          ▼                        ▼                     │
│              ┌─────────────────────────────────────────────┐            │
│              │           Agent Manager                      │            │
│              │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │            │
│              │  │Loader    │  │Factory   │  │Lifecycle │   │            │
│              │  │(加载定义) │  │(创建实例) │  │(生命周期) │   │            │
│              │  └──────────┘  └──────────┘  └──────────┘   │            │
│              └───────────────────┬─────────────────────────┘            │
│                                  │                                      │
│              ┌───────────────────┼───────────────────┐                  │
│              │                   │                   │                  │
│       ┌──────┴──────┐    ┌──────┴──────┐    ┌──────┴──────┐           │
│       │   MainAgent │    │  SubAgent1  │    │  SubAgent2  │           │
│       │ (主Agent)   │    │  (分析器)   │    │  (比较器)   │           │
│       └──────┬──────┘    └──────┬──────┘    └──────┬──────┘           │
│              │                   │                   │                  │
│              └───────────────────┼───────────────────┘                  │
│                                  │                                      │
│              ┌───────────────────┴───────────────────┐                  │
│              │           Collaboration Service        │                  │
│              │     (任务分配 / 消息传递 / 结果汇总)     │                  │
│              └───────────────────────────────────────┘                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 核心参与者

| 参与者 | 角色 | 交互方式 |
|--------|------|----------|
| 管理员 | 创建/管理 Agent | CLI / HTTP API |
| AgentLoader | 加载 AGENTS.md 和 Agent 定义 | 文件系统读取 |
| AgentFactory | 创建 Agent 实例 | 动态类加载 |
| AgentLifecycleManager | 管理 Agent 生命周期 | 状态机控制 |
| AgentContextManager | 管理 Agent 上下文 | 内存/数据库存储 |
| CollaborationService | Agent 协作协调 | 消息队列 |
| 数据库 | 持久化 Agent 定义和状态 | ORM |

## **1.2 服务/组件总体架构**

### 架构分层图

```
┌──────────────────────────────────────────────────────────────────────┐
│                     接入层 (Entry Layer)                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │ AgentController  │  │ AgentTaskController│ │  AgentCLI       │   │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘   │
├───────────┼──────────────────────┼──────────────────────┼────────────┤
│           │        服务层 (Service Layer)               │            │
│  ┌────────┴─────────┐  ┌────────┴─────────┐  ┌────────┴─────────┐  │
│  │ AgentService     │  │ AgentTaskService │  │CollaborationService│ │
│  │  (CRUD+权限)     │  │  (任务管理)       │  │ (协作协调)       │  │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘  │
├───────────┼──────────────────────┼──────────────────────┼────────────┤
│           │        Agent 管理层 (Agent Management)        │            │
│  ┌────────┴────────────────────────────────────────────┴─────────┐  │
│  │                    AgentManager                               │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │  │
│  │  │Loader    │  │Factory   │  │Lifecycle │  │ContextManager│ │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────┘ │  │
│  └────────────────────────┬──────────────────────────────────────┘  │
├───────────────────────────┼─────────────────────────────────────────┤
│       Agent 实例层 (Agent Instance Layer)                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  MainAgent   │  │  SubAgent    │  │  SubAgent    │             │
│  │  (独立上下文) │  │  (独立上下文) │  │  (独立上下文) │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
├────────────────────────────────────────────────────────────────────┤
│       数据层 (Data Access Layer)                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  AgentDAO    │  │AgentContextDAO│ │AgentTaskDAO │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
├────────────────────────────────────────────────────────────────────┤
│       基础设施层 (Infrastructure)                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │  f_orm   │  │  f_log   │  │MessageQueue│ │ PermissionUtils │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

### 数据流图

```
Agent 创建流程:
  CLI/API ──> AgentService.create() ──> AgentDAO.insert() ──> DB
                                            │
                                            └──> AgentFactory.create() ──> Agent实例

Agent 加载流程:
  应用启动 ──> AgentLoader.loadAgentsMd() ──> 解析 YAML + 内容
                                                │
                                                ├──> AgentDAO.batchInsert()
                                                └──> AgentFactory.createAll()

任务分配流程:
  MainAgent ──> CollaborationService.assignTask() ──> AgentTaskDAO.insert()
                                                        │
                                                        └──> MessageQueue.publish() ──> SubAgent.receive()

上下文更新流程:
  Agent 消息 ──> AgentContextManager.update() ──> AgentContextDAO.upsert()
```

### 应用启动流程

```
Application.init()
    │
    ├── ORM.initialize()                    (现有)
    ├── setupMiddlewares()                  (现有)
    ├── setupRoutes()                       (现有)
    │       └── AutoRouteRegistry.registerAllRoutes()
    │               └── AgentRoute.register()
    │
    └── [新增] AgentManager.initialize()
            │
            ├── AgentLoader.loadAgentsMd()      (加载 AGENTS.md)
            ├── AgentFactory.createAll()        (创建 Agent 实例)
            ├── AgentLifecycleManager.startAll() (启动所有 Agent)
            └── CollaborationService.initialize() (初始化协作服务)
```

---

# **2. 接口设计**

## **2.1 总体设计**

### API 设计原则
1. 遵循 UCTOO V4 RESTful 规范，路由前缀 `/api/v1/uctoo/agent/`
2. 复用现有 CRUD 接口模式
3. 所有接口受 JWT 认证 + RBAC 权限保护
4. 响应格式统一使用 `APIResult<T>`

### CLI 设计原则
1. 命令入口: `skill agent <sub-command> [options]`
2. 支持 `--json` 输出格式
3. 提供完整的 Agent 生命周期管理命令

## **2.2 接口清单**

### 2.2.1 HTTP API 接口

#### CRUD 接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/uctoo/agent/create` | 创建 Agent | agent:write |
| PUT | `/api/v1/uctoo/agent/:id` | 更新 Agent | agent:write |
| DELETE | `/api/v1/uctoo/agent/:id` | 删除 Agent | agent:write |
| GET | `/api/v1/uctoo/agent/:id` | 获取 Agent 详情 | agent:read |
| GET | `/api/v1/uctoo/agent/list/:limit/:page` | 分页查询 Agent | agent:read |

#### 生命周期接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/uctoo/agent/:id/start` | 启动 Agent | agent:write |
| POST | `/api/v1/uctoo/agent/:id/stop` | 停止 Agent | agent:write |
| POST | `/api/v1/uctoo/agent/:id/pause` | 暂停 Agent | agent:write |
| POST | `/api/v1/uctoo/agent/:id/resume` | 恢复 Agent | agent:write |

#### 任务接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/uctoo/agent/:id/task` | 分配任务 | agent:write |
| GET | `/api/v1/uctoo/agent/:id/tasks` | 获取任务列表 | agent:read |
| GET | `/api/v1/uctoo/agent/task/:taskId` | 获取任务详情 | agent:read |

#### 协作接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/uctoo/agent/collaborate` | 创建协作任务 | agent:write |
| GET | `/api/v1/uctoo/agent/collaborations` | 获取协作列表 | agent:read |

### 2.2.2 CLI 命令体系

```
skill agent <command> [options]

命令列表:
  create          创建 Agent
  list            列出所有 Agent
  show <id>       显示 Agent 详情
  update <id>     更新 Agent
  delete <id>     删除 Agent
  start <id>      启动 Agent
  stop <id>       停止 Agent
  pause <id>      暂停 Agent
  resume <id>     恢复 Agent
  task            任务管理子命令
  collaborate     协作管理子命令

create/update 选项:
  --name <value>        Agent 名称
  --type <value>        Agent 类型 (analyzer/comparator/grader)
  --file <path>         Agent 声明文件路径
  --content <json>      Agent 声明内容 (JSON)
  --description <text>  Agent 描述
  --model <name>        模型名称

通用选项:
  --json                JSON 格式输出
  --limit <n>           限制条数
  --page <n>            页码
```

---

# **3. 集成设计**

## **3.1 AgentManager 集成**

### 集成架构

```
AgentManager (新增)
    │
    ├── AgentLoader: 加载 AGENTS.md 和目录下的 agent 定义文件
    │       └── loadAgentsMd(path: String): Array<AgentDefinition>
    │
    ├── AgentFactory: 根据定义创建 Agent 实例
    │       └── create(definition: AgentDefinition): AgentInstance
    │
    ├── AgentLifecycleManager: 管理 Agent 生命周期状态
    │       ├── start(agentId: String): Unit
    │       ├── stop(agentId: String): Unit
    │       ├── pause(agentId: String): Unit
    │       └── resume(agentId: String): Unit
    │
    └── AgentContextManager: 管理 Agent 对话上下文
            ├── getContext(agentId: String): AgentContext
            ├── updateContext(agentId: String, messages: Array<Message>): Unit
            └── clearContext(agentId: String): Unit
```

## **3.2 权限系统集成**

### 用户组设计

```
用户组结构:
├── agents (主 Agent 用户组)
│       ├── 权限: agent:read, agent:write, agent:execute
│       └── 成员: 所有主 Agent 账号
│
└── subagents (子 Agent 用户组)
        ├── 权限: agent:read, agent:execute
        └── 成员: 所有 SubAgent 账号
```

### 集成流程

```
Agent 创建时:
  1. 创建 Agent 数据库记录
  2. 创建对应用户账号 (username = "agent_${agentId}")
  3. 根据 Agent 类型加入对应用户组
  4. 分配默认权限

权限检查时:
  1. 获取当前 Agent 用户
  2. 检查用户组权限
  3. 验证操作权限
```

## **3.3 协作系统集成**

### 协作模式

```
┌──────────────────────────────────────────────────────────────────┐
│                     协作模式架构                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  链式协作 (Chain):                                               │
│    MainAgent ──> SubAgent1 ──> SubAgent2 ──> MainAgent          │
│                                                                  │
│  并行协作 (Parallel):                                            │
│    MainAgent                                                     │
│       ├──> SubAgent1                                             │
│       ├──> SubAgent2                                             │
│       └──> SubAgent3                                             │
│            │           │           │                             │
│            └───────────┼───────────┘                             │
│                        ▼                                         │
│                   结果汇总                                        │
│                                                                  │
│  分层协作 (Hierarchy):                                           │
│    MainAgent                                                     │
│       └──> ManagerAgent                                          │
│               ├──> WorkerAgent1                                  │
│               └──> WorkerAgent2                                  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

# **4. 数据模型**

## **4.1 设计目标**

1. 支持 Agent 的完整生命周期管理
2. 支持上下文持久化和恢复
3. 支持任务追踪和协作
4. 与现有用户权限系统集成

## **4.2 模型实现**

### 4.2.1 agents 表 DDL

```sql
CREATE TABLE IF NOT EXISTS agents (
    id              VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name            VARCHAR(100) NOT NULL,
    type            VARCHAR(50) NOT NULL,
    description     TEXT DEFAULT '',
    status          INT4 DEFAULT 0,                    -- 0:停用 1:运行 2:暂停
    config          JSON DEFAULT '{}',
    system_prompt   TEXT DEFAULT '',
    tools           JSON DEFAULT '[]',
    model           VARCHAR(50) DEFAULT '',
    parent_id       VARCHAR(36) REFERENCES agents(id),
    user_id         VARCHAR(36) REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_agents_status ON agents(status);
CREATE INDEX IF NOT EXISTS idx_agents_type ON agents(type);
CREATE INDEX IF NOT EXISTS idx_agents_parent_id ON agents(parent_id);
CREATE INDEX IF NOT EXISTS idx_agents_user_id ON agents(user_id);
```

### 4.2.2 AgentPO 持久化对象

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["agents"]
public class AgentPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['name']
    public var name: String = ""

    @ORMField['type']
    public var type: String = ""

    @ORMField['description']
    public var description: String = ""

    @ORMField['status']
    public var status: Int32 = 0

    @ORMField['config']
    public var config: String = "{}"

    @ORMField['system_prompt']
    public var systemPrompt: String = ""

    @ORMField['tools']
    public var tools: String = "[]"

    @ORMField['model']
    public var model: String = ""

    @ORMField['parent_id']
    public var parentId: String = ""

    @ORMField['user_id']
    public var userId: String = ""

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}
}
```

### 4.2.3 agent_contexts 表 DDL

```sql
CREATE TABLE IF NOT EXISTS agent_contexts (
    id              VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    agent_id        VARCHAR(36) NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    messages        JSON DEFAULT '[]',
    metadata        JSON DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_contexts_agent_id ON agent_contexts(agent_id);
```

### 4.2.4 agent_tasks 表 DDL

```sql
CREATE TABLE IF NOT EXISTS agent_tasks (
    id              VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    agent_id        VARCHAR(36) NOT NULL REFERENCES agents(id),
    parent_task_id  VARCHAR(36) REFERENCES agent_tasks(id),
    status          INT4 DEFAULT 0,                    -- 0:待处理 1:进行中 2:完成 3:失败
    priority        INT4 DEFAULT 3,                    -- 1-5
    payload         JSON DEFAULT '{}',
    result          JSON DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_agent_id ON agent_tasks(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_status ON agent_tasks(status);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_parent_id ON agent_tasks(parent_task_id);
```

---

# **5. Agent 组件设计**

## **5.1 AgentLoader 组件**

```cangjie
package magic.app.services.agent

public class AgentLoader {
    /// 从 AGENTS.md 文件加载 Agent 定义
    public func loadAgentsMd(filePath: String): Array<AgentDefinition> {
        // 1. 读取文件内容
        // 2. 解析 YAML frontmatter
        // 3. 提取 Agent 元数据
        // 4. 返回 AgentDefinition 数组
    }

    /// 从目录加载所有 Agent 定义文件
    public func loadFromDirectory(dirPath: String): Array<AgentDefinition> {
        // 1. 扫描目录下的 .md 文件
        // 2. 逐个解析
        // 3. 返回所有 AgentDefinition
    }

    /// 解析单个 Markdown 文件
    public func parseFromMarkdown(content: String, source: String): AgentDefinition {
        // 1. 解析 YAML frontmatter
        // 2. 提取 name, description, tools, model 等字段
        // 3. Markdown 内容作为 systemPrompt
        // 4. 返回 AgentDefinition
    }
}
```

## **5.2 AgentFactory 组件**

```cangjie
package magic.app.services.agent

public class AgentFactory {
    /// 根据定义创建 Agent 实例
    public func create(definition: AgentDefinition): AgentInstance {
        // 1. 创建 Agent 实例
        // 2. 设置系统提示词
        // 3. 加载工具列表
        // 4. 初始化上下文
        // 5. 返回 AgentInstance
    }

    /// 批量创建 Agent 实例
    public func createAll(definitions: Array<AgentDefinition>): Array<AgentInstance> {
        // 批量调用 create
    }

    /// 获取 Agent 类型对应的实现类
    private func getAgentClass(type: String): Class<AgentInstance> {
        // 根据类型返回对应的 Agent 实现类
    }
}
```

## **5.3 AgentLifecycleManager 组件**

```cangjie
package magic.app.services.agent

public enum AgentStatus {
    | Stopped     // 已停用
    | Running     // 运行中
    | Paused      // 已暂停
}

public class AgentLifecycleManager {
    /// 启动 Agent
    public func start(agentId: String): Unit {
        // 1. 检查 Agent 状态
        // 2. 初始化上下文
        // 3. 启动消息循环
        // 4. 更新状态为 Running
    }

    /// 停止 Agent
    public func stop(agentId: String): Unit {
        // 1. 停止消息循环
        // 2. 保存上下文
        // 3. 更新状态为 Stopped
    }

    /// 暂停 Agent
    public func pause(agentId: String): Unit {
        // 1. 暂停消息处理
        // 2. 保留上下文
        // 3. 更新状态为 Paused
    }

    /// 恢复 Agent
    public func resume(agentId: String): Unit {
        // 1. 恢复消息处理
        // 2. 更新状态为 Running
    }

    /// 获取 Agent 状态
    public func getStatus(agentId: String): AgentStatus {
        // 查询数据库或缓存获取状态
    }
}
```

## **5.4 AgentContextManager 组件**

```cangjie
package magic.app.services.agent

public class AgentContext {
    public var agentId: String
    public var messages: Array<Message>
    public var metadata: HashMap<String, String>
    public var lastActivityAt: DateTime
}

public class AgentContextManager {
    /// 获取 Agent 上下文
    public func getContext(agentId: String): AgentContext {
        // 1. 先从缓存获取
        // 2. 缓存不存在则从数据库加载
        // 3. 返回 AgentContext
    }

    /// 更新 Agent 上下文
    public func updateContext(agentId: String, messages: Array<Message>): Unit {
        // 1. 更新内存中的上下文
        // 2. 异步写入数据库
        // 3. 更新 lastActivityAt
    }

    /// 清空 Agent 上下文
    public func clearContext(agentId: String): Unit {
        // 1. 清空内存缓存
        // 2. 删除数据库记录
    }

    /// 持久化所有上下文
    public func persistAll(): Unit {
        // 批量保存所有内存中的上下文到数据库
    }
}
```

## **5.5 CollaborationService 组件**

```cangjie
package magic.app.services.agent

public enum CollaborationMode {
    | Chain      // 链式协作
    | Parallel   // 并行协作
    | Hierarchy  // 分层协作
}

public class CollaborationTask {
    public var id: String
    public var parentAgentId: String
    public var childAgentIds: Array<String>
    public var mode: CollaborationMode
    public var payload: String
    public var results: HashMap<String, String>
    public var status: TaskStatus
}

public class CollaborationService {
    /// 创建协作任务
    public func createTask(task: CollaborationTask): String {
        // 1. 保存任务到数据库
        // 2. 根据协作模式分配任务
        // 3. 返回任务 ID
    }

    /// 分配任务给 SubAgent
    public func assignTask(agentId: String, task: TaskPayload): Unit {
        // 1. 发送任务消息到消息队列
        // 2. 更新任务状态
        // 3. 记录任务分配日志
    }

    /// 收集任务结果
    public func collectResults(taskId: String): Array<TaskResult> {
        // 1. 查询所有子任务结果
        // 2. 汇总结果
        // 3. 返回结果数组
    }

    /// 处理协作消息
    public func handleMessage(message: CollaborationMessage): Unit {
        // 1. 解析消息
        // 2. 根据消息类型处理
        // 3. 更新状态或转发消息
    }
}
```

---

# **6. AGENTS.md 文件格式**

## **6.1 文件结构**

```markdown
---
name: MainAgent
type: main
description: 主 Agent，负责协调和管理所有子 Agent
model: claude-3-sonnet
tools:
  - file_read
  - file_write
  - bash
  - agent
color: blue
background: true
---

# Main Agent 系统提示词

你是一个智能 Agent 管理器，负责：
1. 理解用户需求
2. 分配任务给合适的 SubAgent
3. 汇总并反馈结果给用户

## 工作流程

1. **分析需求** - 理解用户的问题和目标
2. **任务分解** - 将复杂任务分解为子任务
3. **任务分配** - 将子任务分配给合适的 SubAgent
4. **结果汇总** - 收集所有 SubAgent 的结果并总结

## 可用工具

- `agent` - 调用 SubAgent 执行任务
```

## **6.2 Frontmatter 字段说明**

| 字段 | 类型 | 说明 | 必填 |
|------|------|------|------|
| name | String | Agent 名称 | 是 |
| type | String | Agent 类型 (main/sub/analyzer/comparator/grader) | 是 |
| description | String | Agent 描述 | 是 |
| model | String | 模型名称 | 否 |
| tools | Array<String> | 工具列表 | 否 |
| disallowedTools | Array<String> | 禁用工具列表 | 否 |
| color | String | 显示颜色 | 否 |
| background | Boolean | 是否后台运行 | 否 |
| memory | String | 内存范围 (user/project/local) | 否 |
| isolation | String | 隔离模式 (worktree/remote) | 否 |
| maxTurns | Int | 最大对话轮数 | 否 |
| initialPrompt | String | 初始提示 | 否 |

---

# **7. 部署与集成**

## **7.1 依赖与环境**

| 依赖 | 版本 | 说明 |
|------|------|------|
| f_orm | latest | 数据库 ORM |
| f_log | latest | 日志框架 |
| fountain.bean | latest | IOC 容器 |
| f_ticktock | latest | 定时任务 |

## **7.2 配置项**

```yaml
agent:
  # AGENTS.md 文件路径
  definition-file: ./AGENTS.md
  
  # Agent 定义目录
  definition-dir: ./agents
  
  # 上下文缓存过期时间（秒）
  context-ttl: 3600
  
  # 最大并发 Agent 数量
  max-agents: 100
  
  # 是否启用协作模式
  collaboration-enabled: true
  
  # 消息队列配置
  message-queue:
    type: redis
    host: localhost
    port: 6379
```

## **7.3 启动流程**

```
Application.init()
    │
    ├── 加载配置文件
    │
    ├── 初始化 ORM
    │
    ├── 初始化 AgentManager
    │       ├── AgentLoader.loadAgentsMd()
    │       ├── AgentFactory.createAll()
    │       └── AgentLifecycleManager.startAll()
    │
    ├── 初始化 CollaborationService
    │       └── 连接消息队列
    │
    └── 注册路由
            └── AgentRoute.register()
```

---

# **8. 安全性考虑**

## **8.1 权限控制**

- Agent 账号必须属于 agents 或 subagents 用户组
- 细粒度权限控制：agent:read, agent:write, agent:execute
- 禁止 Agent 越权访问资源
- 敏感操作需要额外验证

## **8.2 隔离性**

- 每个 Agent 拥有独立的上下文空间
- Agent 之间无法直接访问彼此的内存
- 资源配额限制（API 调用次数、内存使用等）

## **8.3 审计日志**

- 记录所有 Agent 创建、启动、停止操作
- 记录任务分配和执行结果
- 记录权限变更
- 日志保留期可配置