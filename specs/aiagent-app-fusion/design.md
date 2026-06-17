# 设计文档：AIAgent 框架与 App 层全栈有机融合

## 文档信息
- **项目名称**: agentskills-runtime 全栈有机融合
- **版本**: 1.0.0
- **创建日期**: 2026-06-05
- **基于规格**: spec.md v1.1.0
- **作者**: UCToo team
- **状态**: 草稿

## 1. 概述

### 1.1 设计目标

以数据库为数据流枢纽，实现 CangjieMagic 框架与 UCToo V4 App 层的运行时有机融合，使：

1. **Agent 运行时桥接**：CangjieMagic 内存 Agent ↔ App 层数据库 Agent 双向映射
2. **全栈数据同构（UMI）**：后端 PO ↔ 前端 ORM 模型自动同构，API 契约一致
3. **持久化增强**：记忆、任务、计费数据持久化到 PostgreSQL，超越文件为中心模式
4. **能力开放**：CangjieMagic 核心能力（执行策略/协作/记忆/模型/RAG/事件/存储/技能验证）通过标准化 API/CLI 开放
5. **计费闭环**：Token 记录 → 费率计算 → 统计仪表板 → 配额控制 → 报表导出

### 1.2 设计原则

| 原则 | 说明 |
|------|------|
| 数据库为真相源 | 所有数据变更通过数据库 API，可追踪、可审计 |
| UMI 通模一体 | 后端 PO ↔ 前端 ORM 同构，crudgen + crudweb 一键全栈生成 |
| 确定性优先 | 可确定性实现的逻辑用代码，需推理判断的由 AI 驱动 |
| 技能一等公民 | 优先使用技能排列组合解决需求，SkillToToolAdapter 适配 |
| 降级容错 | 桥接失败时 Agent 仍可内存执行，数据库不可用时降级为纯内存模式 |
| 无侵入集成 | 通过 EventHandlerManager 事件驱动 + AOP 拦截器实现，不侵入已有代码 |

### 1.3 架构总览

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Web Admin 前端 (Vue 3 + Vite)                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │ pinia-orm│ │TinyRobot │ │ WebMCP   │ │ Token    │ │ Agent Monitor    │  │
│  │ 数据模型 │ │ AI聊天UI │ │ 前端工具 │ │ Dashboard│ │ 监控仪表板      │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
│              │ REST API / WebSocket / WebMCP                               │
└──────────────┼──────────────────────────────────────────────────────────────┘
               │
┌──────────────┼──────────────────────────────────────────────────────────────┐
│              ▼        App 层 (src/app)                                     │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  REST Controllers + WebSocket + WebMCP + CLI                        │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │  Services: AgentRuntimeBridge + DatabaseMemory + BillingService     │   │
│  │           + WebSocketEventBridge + AgentExecutionExecutor            │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │  DAOs: 9 新增 CRUD 模块 (agent_groups/agent_memories/...)          │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │  SyncManager + SyncInterceptor(AOP) + SchedulerEngine(Crontab)     │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │  PostgreSQL (pgvector) + PermissionMiddleware + OperateLog          │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│              │ AgentRuntimeBridge                                          │
└──────────────┼──────────────────────────────────────────────────────────────┘
               │
┌──────────────┼──────────────────────────────────────────────────────────────┐
│              ▼    CangjieMagic 框架 (src/agent/...)                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │  Agent   │ │AgentGroup│ │  Memory  │ │  Skill   │ │ EventHandlerMgr │  │
│  │ +Executor│ │ 5种协作  │ │Short+DB  │ │ +Tool    │ │ 13种事件        │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                       │
│  │  Model   │ │   RAG    │ │ Storage  │ │Interaction│                      │
│  │ 18提供商 │ │ Retriever│ │KV+Vec+Gph│ │ 13种事件  │                      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 2. 架构设计

### 2.1 整体分层架构

| 层级 | 包路径 | 职责 | 新增/修改 |
|------|--------|------|----------|
| **CangjieMagic** | `magic.agent.*` | AI Agent 框架核心 | 修改：Memory 接口扩展 |
| **Bridge** | `magic.app.services.bridge` | 运行时桥接层 | **新增** |
| **App** | `magic.app.*` | 服务端应用层 | **新增** 9 CRUD 模块 |
| **API** | `magic.app.controllers/routes` | REST/WebSocket/CLI 接口 | **新增** 能力开放 API |
| **Frontend** | `web-admin/web` | Vue 3 前端 | **新增** 6 页面 + N 模型 |

### 2.2 新增模块清单

| 模块 | 包路径 | 层级 | 优先级 | 依赖 |
|------|--------|------|--------|------|
| AgentRuntimeBridge | `magic.app.services.bridge` | Bridge | P0 | - |
| DatabaseMemory | `magic.agent.memory.database` | CangjieMagic | P0 | Bridge |
| WebSocketEventBridge | `magic.app.services.bridge` | Bridge | P1 | Bridge |
| AgentExecutionExecutor | `magic.app.services.crontab.executor` | App | P1 | Bridge |
| AgentGroups CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.agent_groups` | App | P1 | Bridge |
| AgentMemories CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.agent_memories` | App | P0 | Bridge |
| AgentApprovals CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.agent_approvals` | App | P2 | WebSocket |
| LlmUsageLogs CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.llm_usage_logs` | App | P0 | Bridge |
| ModelPricing CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.model_pricing` | App | P0 | - |
| UsageQuotas CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.usage_quotas` | App | P2 | Billing |
| AgentExecutors CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.agent_executors` | App | P1 | Bridge |
| Retrievers CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.retrievers` | App | P1 | - |
| EventHandlers CRUD | `magic.app.models/dao/services/controllers/routes.uctoo.event_handlers` | App | P2 | - |
| BillingService | `magic.app.services.billing` | App | P0 | LlmUsageLogs, ModelPricing |
| WebHumanAgent | `magic.agent.human.web` | CangjieMagic | P2 | WebSocket |
| SkillAsAgent | `magic.agent.skill` | CangjieMagic | P2 | Bridge |

### 2.3 模块依赖关系

```
AgentRuntimeBridge (P0)
  ├── DatabaseMemory (P0)
  │     └── AgentMemories CRUD (P0)
  ├── LlmUsageLogs CRUD (P0)
  │     └── BillingService (P0)
  │           └── ModelPricing CRUD (P0)
  ├── WebSocketEventBridge (P1)
  │     └── WebHumanAgent (P2)
  │           └── AgentApprovals CRUD (P2)
  ├── AgentExecutionExecutor (P1)
  ├── AgentGroups CRUD (P1)
  │     └── SkillAsAgent (P2)
  ├── AgentExecutors CRUD (P1)
  ├── Retrievers CRUD (P1)
  ├── EventHandlers CRUD (P2)
  └── UsageQuotas CRUD (P2)
```

## 3. 核心组件设计

### 3.1 AgentRuntimeBridge（P0）

#### 3.1.1 类定义

```cangjie
package magic.app.services.bridge

import magic.agent.agent.{BaseAgent, AgentState}
import magic.agent.agent.definition.AgentDefinition
import magic.app.models.uctoo.AgentsPO
import magic.app.dao.uctoo.AgentsDAO
import magic.app.services.uctoo.AgentsService
import magic.app.core.orm.ORM
import magic.app.core.result.APIResult
import std.collection.{HashMap, ArrayList}
import std.concurrent.{Mutex, ConcurrentHashMap}

public class AgentRuntimeBridge {
    private static var instance_: Option<AgentRuntimeBridge> = None
    private let runtimeAgents = ConcurrentHashMap<String, BaseAgent>()
    private let agentMutex = Mutex()
    private let agentsService = AgentsService()

    public static prop instance: AgentRuntimeBridge {
        get() {
            match (instance_) {
                case Some(v) => v
                case None => {
                    let inst = AgentRuntimeBridge()
                    instance_ = Some(inst)
                    inst
                }
            }
        }
    }

    public init() {}

    public func createRuntimeAgent(definition: AgentDefinition): APIResult<BaseAgent> {
        try {
            let agent = buildAgentFromDefinition(definition)
            runtimeAgents.put(definition.id, agent)
            let po = mapDefinitionToPO(definition)
            po.status = "idle"
            let result = agentsService.create(po, definition.id)
            if (result.success) {
                return APIResult<BaseAgent>(agent)
            }
            return APIResult<BaseAgent>(false, "数据库持久化失败")
        } catch (e: Exception) {
            return APIResult<BaseAgent>(false, e.message)
        }
    }

    public func syncToDatabase(agent: BaseAgent): Unit {
        spawn {
            try {
                let po = mapAgentToPO(agent)
                agentsService.update(agent.id, po)
            } catch (_: Exception) {}
        }
    }

    public func loadFromDatabase(agentId: String): APIResult<BaseAgent> {
        try {
            if (let Some(existing) <- runtimeAgents.get(agentId)) {
                return APIResult<BaseAgent>(existing)
            }
            let result = agentsService.getById(agentId)
            if (!result.success) { return APIResult<BaseAgent>(false, result.reason) }
            let po = result.data
            let definition = mapPOToDefinition(po)
            let agent = buildAgentFromDefinition(definition)
            runtimeAgents.put(agentId, agent)
            return APIResult<BaseAgent>(agent)
        } catch (e: Exception) {
            return APIResult<BaseAgent>(false, e.message)
        }
    }

    public func loadAllFromDatabase(): ArrayList<BaseAgent> {
        let agents = ArrayList<BaseAgent>()
        let (pos, _) = agentsService.getListWithFilter(1, 1000, "", "")
        for (po in pos) {
            if (let Some(_) <- runtimeAgents.get(po.id)) { continue }
            try {
                let definition = mapPOToDefinition(po)
                let agent = buildAgentFromDefinition(definition)
                runtimeAgents.put(po.id, agent)
                agents.append(agent)
            } catch (_: Exception) {}
        }
        return agents
    }

    public func updateRuntimeState(agentId: String, state: String): Unit {
        spawn {
            try {
                let po = AgentsPO()
                po.id = agentId
                po.status = state
                po.updatedAt = DateTime.now()
                agentsService.update(agentId, po)
            } catch (_: Exception) {}
        }
    }

    public func getRuntimeAgent(agentId: String): Option<BaseAgent> {
        runtimeAgents.get(agentId)
    }

    public func removeRuntimeAgent(agentId: String): Unit {
        runtimeAgents.remove(agentId)
    }

    private func buildAgentFromDefinition(definition: AgentDefinition): BaseAgent { ... }
    private func mapDefinitionToPO(definition: AgentDefinition): AgentsPO { ... }
    private func mapPOToDefinition(po: AgentsPO): AgentDefinition { ... }
    private func mapAgentToPO(agent: BaseAgent): AgentsPO { ... }
}
```

#### 3.1.2 AgentDefinition ↔ AgentsPO 字段映射表

| AgentDefinition 字段 | AgentsPO 字段 | 映射规则 | 说明 |
|---------------------|--------------|---------|------|
| `id` | `id` | 直接映射 | UUID |
| `name` | `name` | 直接映射 | Agent 名称 |
| `agentType` | `agentType` | 直接映射 | ai_func/conversation/dispatch/human/tool |
| `model` | `model` | 直接映射 | 模型标识 |
| `tools` | `tools` | JSON 序列化 | 工具名称列表 |
| `systemPrompt` | `systemPrompt` | 直接映射 | 系统提示词 |
| `maxTurns` | `maxTurns` | 直接映射 | 最大轮次 |
| `memory.scope` | `memoryScope` | 枚举映射 | user/project/local |
| `background` | `background` | 直接映射 | 后台执行标记 |
| `permissions` | `permissions` | JSON 序列化 | 权限声明列表 |
| - | `status` | 运行时状态 | idle/running/completed/failed/paused |
| - | `parentId` | 直接映射 | 父 Agent ID |
| - | `userId` | 直接映射 | 所属用户 |
| - | `config` | JSON 序列化 | 扩展配置 |
| - | `sourcePath` | 直接映射 | AGENTS.md 文件路径 |
| - | `syncStatus` | 同步状态 | synced/pending/conflict |

#### 3.1.3 运行时状态同步流程

```
Agent 执行开始
  │
  ├── AgentRuntimeBridge.updateRuntimeState(id, "running")
  │     └── spawn { agentsService.update(id, po{status="running"}) }
  │
  ├── Agent 执行步骤...
  │     └── EventHandlerManager → AgentStepEvent
  │           └── WebSocketEventBridge → WebSocket 推送
  │
  ├── Agent 执行完成
  │     └── AgentRuntimeBridge.updateRuntimeState(id, "completed")
  │
  └── Agent 执行失败
        └── AgentRuntimeBridge.updateRuntimeState(id, "failed")
              └── spawn { agentsService.update(id, po{status="failed", config.errorMessage=...}) }
```

#### 3.1.4 降级模式设计

```cangjie
public func createWithFallback(definition: AgentDefinition): BaseAgent {
    let result = createRuntimeAgent(definition)
    if (result.success) { return result.data }
    let agent = buildAgentFromDefinition(definition)
    runtimeAgents.put(definition.id, agent)
    return agent
}
```

- 数据库不可用时：仅创建内存 Agent，标记 `syncStatus = "pending"`
- 数据库恢复后：`SyncScanJob` 扫描 pending 状态记录，补写数据库
- 内存 Agent 执行不受数据库状态影响

### 3.2 AgentGroups CRUD 模块（P1）

#### 3.2.1 AgentGroupsPO 字段定义

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["agent_groups"]
public class AgentGroupsPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['name']
    public var name: String = ""

    @ORMField['group_type']
    public var groupType: String = "leader"

    @ORMField['leader_id']
    public var leaderId: Option<String> = None<String>

    @ORMField['member_ids']
    public var memberIds: String = "[]"

    @ORMField['config']
    public var config: String = "{}"

    @ORMField['status']
    public var status: String = "idle"

    @ORMField['max_round']
    public var maxRound: Int64 = 10

    @ORMField['description']
    public var description: Option<String> = None<String>

    @ORMField['creator']
    public var creator: Option<String> = None<String>

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}
    public init(name!: String, groupType!: String, leaderId!: Option<String>,
                memberIds!: String, config!: String, status!: String,
                maxRound!: Int64, description!: Option<String>,
                creator!: Option<String>) { ... }
    public func toJsonValue(): JsonValue { ... }
    public func toJson(): String { ... }
}
```

#### 3.2.2 AgentGroupsDAO

```cangjie
package magic.app.dao.uctoo

@DAO
public interface AgentGroupsDAO <: RootDAO {
    prop executor: SqlExecutor

    func insertAgentGroup(entity: AgentGroupsPO): String {
        executor.setSql('''
            insert into agent_groups(name, group_type, leader_id, member_ids, config,
                status, max_round, description, creator, created_at, updated_at)
            values(${arg(entity.name)}, ${arg(entity.groupType)}, ${arg(entity.leaderId)},
                ${arg(entity.memberIds)}, ${arg(entity.config)}, ${arg(entity.status)},
                ${arg(entity.maxRound)}, ${arg(entity.description)}, ${arg(entity.creator)},
                ${arg(entity.createdAt)}, ${arg(entity.updatedAt)})
            returning id
        ''').singleFirst<String>() ?? ""
    }

    func findAgentGroupById(id: String): Option<AgentGroupsPO> {
        executor.setSql('''
            select id, name, group_type, leader_id, member_ids, config, status,
                max_round, description, creator, created_at, updated_at, deleted_at
            from agent_groups where id = ${arg(id)} and deleted_at is null
        ''').first<AgentGroupsPO>()
    }

    func updateAgentGroup(entity: AgentGroupsPO): Int64 {
        executor.setSql('''
            update agent_groups set name = ${arg(entity.name)},
                group_type = ${arg(entity.groupType)}, leader_id = ${arg(entity.leaderId)},
                member_ids = ${arg(entity.memberIds)}, config = ${arg(entity.config)},
                status = ${arg(entity.status)}, max_round = ${arg(entity.maxRound)},
                description = ${arg(entity.description)}, updated_at = ${arg(DateTime.now())}
            where id = ${arg(entity.id)}
        ''').update
    }

    func softDeleteAgentGroupById(id: String): Int64 { ... }
    func deleteAgentGroupById(id: String): Int64 { ... }
    func findAllAgentGroupPage(page: Int64, size: Int64): Pagination<AgentGroupsPO> { ... }
    func findAgentGroupByCondition(whereClause: String, orderByClause: String,
        page: Int64, size: Int64): Pagination<AgentGroupsPO> { ... }
}
```

#### 3.2.3 AgentGroupsService

```cangjie
package magic.app.services.uctoo

public class AgentGroupsService {
    private func getExecutor(): SqlExecutor { ORM.executor() }
    private let requestParser = RequestParserService()
    public init() {}

    public func create(entity: AgentGroupsPO, creatorId: String): APIResult<AgentGroupsPO> { ... }
    public func update(entityId: String, entity: AgentGroupsPO): APIResult<AgentGroupsPO> { ... }
    public func delete(entityId: String, force: Bool): APIResult<Bool> { ... }
    public func getById(entityId: String): APIResult<AgentGroupsPO> { ... }

    public func addMember(groupId: String, agentId: String): APIResult<AgentGroupsPO> {
        let result = getById(groupId)
        if (!result.success) { return APIResult<AgentGroupsPO>(false, result.reason) }
        let group = result.data
        let members = parseMemberIds(group.memberIds)
        if (!members.contains(agentId)) { members.append(agentId) }
        group.memberIds = serializeMemberIds(members)
        return update(groupId, group)
    }

    public func removeMember(groupId: String, agentId: String): APIResult<AgentGroupsPO> { ... }

    public func getListWithFilter(page: Int32, pageSize: Int32, sort: String,
        filter: String): (ArrayList<AgentGroupsPO>, Int64) { ... }
}
```

#### 3.2.4 AgentGroupsController

```cangjie
package magic.app.controllers.uctoo.agent_groups

import magic.app.core.http.{HttpRequest, HttpResponse}

public class AgentGroupsController {
    private var service: AgentGroupsService
    private var bridge: AgentRuntimeBridge
    public init(service: AgentGroupsService, bridge: AgentRuntimeBridge) {
        this.service = service
        this.bridge = bridge
    }

    public func add(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func edit(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func delete(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func getSingle(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit { ... }

    public func addMember(req: HttpRequest, res: HttpResponse): Unit {
        let groupId = req.pathParam("id")
        let body = parseBody(req)
        let agentId = body["agentId"].toString()
        let result = service.addMember(groupId, agentId)
        ...
    }

    public func removeMember(req: HttpRequest, res: HttpResponse): Unit { ... }

    public func execute(req: HttpRequest, res: HttpResponse): Unit {
        let groupId = req.pathParam("id")
        let groupResult = service.getById(groupId)
        if (!groupResult.success) { res.status(404).json(...); return }
        let group = groupResult.data
        let agentGroup = bridge.createAgentGroup(group)
        spawn {
            let execResult = agentGroup.execute(...)
            service.update(groupId, AgentGroupsPO{id=groupId, status="completed", ...})
        }
        res.status(200).json("{\"status\":\"running\"}")
    }

    public func getStatus(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

#### 3.2.5 AgentGroupsRoute

```cangjie
package magic.app.routes.uctoo.agent_groups

import magic.app.core.router.Router

public class AgentGroupsRoute {
    private var router: Router
    private var controller: AgentGroupsController

    public init(router: Router, controller: AgentGroupsController) {
        this.router = router
        this.controller = controller
    }

    public func register(): Router {
        registerCustomRoutes()
        router.post("/api/v1/uctoo/agent_groups/add", controller.add)
        router.post("/api/v1/uctoo/agent_groups/edit", controller.edit)
        router.post("/api/v1/uctoo/agent_groups/del", controller.delete)
        router.get("/api/v1/uctoo/agent_groups/:id", controller.getSingle)
        router.get("/api/v1/uctoo/agent_groups/:limit/:page", controller.getManyWithPathParams)
        return router
    }

    public func registerCustomRoutes(): Router {
        router.post("/api/v1/uctoo/agent_groups/:id/add-member", controller.addMember)
        router.post("/api/v1/uctoo/agent_groups/:id/remove-member", controller.removeMember)
        router.post("/api/v1/uctoo/agent_groups/:id/execute", controller.execute)
        router.get("/api/v1/uctoo/agent_groups/:id/status", controller.getStatus)
        return router
    }
}
```

#### 3.2.6 AgentGroup 类型 → CangjieMagic 实现映射

| agent_groups.group_type | CangjieMagic 类 | 说明 |
|------------------------|----------------|------|
| `leader` | `LeaderGroup` | 领导者调度，leader 分配任务给 members |
| `linear` | `LinearGroup` | 线性管道，按顺序依次执行 |
| `free` | `FreeGroup` | 自由讨论，任意发言 |
| `auto_discuss` | `AutoDiscussGroup` | 自动选择发言者讨论 |
| `round_robin` | `RoundRobinDiscussGroup` | 轮询讨论 |

```cangjie
public func createAgentGroup(po: AgentGroupsPO): AgentGroup {
    let members = loadMembers(po.memberIds)
    match (po.groupType) {
        case "leader" => {
            let leader = bridge.loadFromDatabase(po.leaderId.getOrElse(""))
            LeaderGroup(leader, members, configFromJson(po.config))
        }
        case "linear" => LinearGroup(members, configFromJson(po.config))
        case "free" => FreeGroup(members, configFromJson(po.config))
        case "auto_discuss" => AutoDiscussGroup(members, configFromJson(po.config))
        case "round_robin" => RoundRobinDiscussGroup(members, configFromJson(po.config))
        case _ => LeaderGroup(members[0], members, configFromJson(po.config))
    }
}
```

### 3.3 DatabaseMemory 记忆持久化（P0）

#### 3.3.1 DatabaseMemory 类实现 Memory 接口

```cangjie
package magic.agent.memory.database

import magic.agent.memory.Memory
import magic.agent.memory.segment.MemorySegment
import magic.agent.model.embedding.EmbeddingModel
import magic.app.models.uctoo.AgentMemoriesPO
import magic.app.services.uctoo.AgentMemoriesService
import std.collection.ArrayList

public class DatabaseMemory <: Memory {
    private let agentId: String
    private let scope: String
    private let embeddingModel: EmbeddingModel
    private let memoriesService = AgentMemoriesService()

    public init(agentId!: String, scope!: String = "episodic",
                embeddingModel!: EmbeddingModel) {
        this.agentId = agentId
        this.scope = scope
        this.embeddingModel = embeddingModel
    }

    public func update(segment: MemorySegment): Unit {
        let embedding = embeddingModel.embed(segment.content)
        let po = AgentMemoriesPO()
        po.agentId = agentId
        po.content = segment.content
        po.embeddingVector = serializeVector(embedding)
        po.scope = scope
        po.weight = segment.weight.getOrElse(1.0)
        po.tags = serializeTags(segment.tags)
        po.metadata = segment.metadata.getOrElse("{}")
        spawn { memoriesService.create(po, agentId) }
    }

    public func search(question: String, topK!: Int64 = 5): ArrayList<MemorySegment> {
        let queryEmbedding = embeddingModel.embed(question)
        let results = memoriesService.searchByVector(agentId, serializeVector(queryEmbedding), topK)
        let segments = ArrayList<MemorySegment>()
        for (po in results) {
            segments.append(mapPOToSegment(po))
        }
        return segments
    }

    public func clear(): Unit {
        memoriesService.clearByAgentId(agentId, scope)
    }

    private func serializeVector(vec: Array<Float64>): String { ... }
    private func mapPOToSegment(po: AgentMemoriesPO): MemorySegment { ... }
}
```

#### 3.3.2 AgentMemoriesPO 字段定义

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["agent_memories"]
public class AgentMemoriesPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['agent_id']
    public var agentId: String = ""

    @ORMField['content']
    public var content: String = ""

    @ORMField['embedding_vector']
    public var embeddingVector: Option<String> = None<String>

    @ORMField['scope']
    public var scope: String = "episodic"

    @ORMField['weight']
    public var weight: Float64 = 1.0

    @ORMField['tags']
    public var tags: String = "[]"

    @ORMField['metadata']
    public var metadata: String = "{}"

    @ORMField['task_id']
    public var taskId: Option<String> = None<String>

    @ORMField['session_id']
    public var sessionId: Option<String> = None<String>

    @ORMField['creator']
    public var creator: Option<String> = None<String>

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}
    public init(agentId!: String, content!: String, scope!: String, ...) { ... }
    public func toJsonValue(): JsonValue { ... }
    public func toJson(): String { ... }
}
```

#### 3.3.3 AgentMemoriesDAO（含向量搜索）

```cangjie
@DAO
public interface AgentMemoriesDAO <: RootDAO {
    prop executor: SqlExecutor

    func insertAgentMemory(entity: AgentMemoriesPO): String { ... }
    func findAgentMemoryById(id: String): Option<AgentMemoriesPO> { ... }
    func updateAgentMemory(entity: AgentMemoriesPO): Int64 { ... }
    func deleteAgentMemoryById(id: String): Int64 { ... }

    func searchByVector(agentId: String, queryVector: String, limit: Int64): ArrayList<AgentMemoriesPO> {
        executor.setSql('''
            select id, agent_id, content, embedding_vector, scope, weight, tags,
                metadata, task_id, session_id, creator, created_at, updated_at
            from agent_memories
            where agent_id = ${arg(agentId)} and deleted_at is null
                and embedding_vector is not null
            order by embedding_vector <=> ${arg(queryVector)}::vector
            limit ${arg(limit)}
        ''').list<AgentMemoriesPO>()
    }

    func findByAgentIdAndScope(agentId: String, scope: String,
        page: Int64, size: Int64): Pagination<AgentMemoriesPO> { ... }
    func findAgentMemoryByCondition(whereClause: String, orderByClause: String,
        page: Int64, size: Int64): Pagination<AgentMemoriesPO> { ... }
}
```

#### 3.3.4 记忆分层存储策略

| 作用域 | scope 值 | 存储位置 | 检索方式 | 生命周期 |
|--------|---------|---------|---------|---------|
| 工作记忆 | `working` | AgentContexts.messages | 顺序读取 | 会话级，会话结束可清理 |
| 情景记忆 | `episodic` | agent_memories | 向量相似度 | 长期，按需清理 |
| 语义记忆 | `semantic` | agent_memories (weight=2.0) | 向量相似度 | 永久，高权重 |
| 程序记忆 | `procedural` | agent_memories (tags含procedural) | 标签+向量 | 永久，技能级 |

#### 3.3.5 ShortMemory + DatabaseMemory 双层缓存

```cangjie
package magic.agent.memory.tiered

public class TieredMemory <: Memory {
    private let shortMemory: ShortMemory
    private let databaseMemory: DatabaseMemory

    public init(agentId!: String, embeddingModel!: EmbeddingModel) {
        this.shortMemory = ShortMemory(embeddingModel)
        this.databaseMemory = DatabaseMemory(agentId, "episodic", embeddingModel)
    }

    public func update(segment: MemorySegment): Unit {
        shortMemory.update(segment)
        spawn { databaseMemory.update(segment) }
    }

    public func search(question: String, topK!: Int64 = 5): ArrayList<MemorySegment> {
        let memResults = shortMemory.search(question, topK: topK)
        if (memResults.size >= topK) { return memResults }
        let dbResults = databaseMemory.search(question, topK: topK - memResults.size)
        let merged = mergeDedup(memResults, dbResults)
        return merged
    }

    public func clear(): Unit {
        shortMemory.clear()
        databaseMemory.clear()
    }

    private func mergeDedup(a: ArrayList<MemorySegment>,
        b: ArrayList<MemorySegment>): ArrayList<MemorySegment> { ... }
}
```

### 3.4 AgentExecutionExecutor 长任务（P1）

#### 3.4.1 实现 CrontabExecutor 接口

```cangjie
package magic.app.services.crontab.executor

import magic.app.services.crontab.executor.CrontabExecutor
import magic.app.services.crontab.context.CrontabExecutionContext
import magic.app.services.bridge.AgentRuntimeBridge
import magic.app.services.uctoo.AgentTasksService

public class AgentExecutionExecutor <: CrontabExecutor {
    private let bridge = AgentRuntimeBridge.instance
    private let tasksService = AgentTasksService()

    public prop scheme: String { get() { "agent_execution" } }

    public func execute(context: CrontabExecutionContext): ExecutionResult {
        let taskId = context.parameters["taskId"].toString()
        let agentId = context.parameters["agentId"].toString()
        let taskResult = tasksService.getById(taskId)

        if (!taskResult.success) {
            return ExecutionResult(success: false, output: "", error: "任务不存在")
        }

        let agentResult = bridge.loadFromDatabase(agentId)
        if (!agentResult.success) {
            return ExecutionResult(success: false, output: "", error: "Agent 加载失败")
        }

        bridge.updateRuntimeState(agentId, "running")

        try {
            let agent = agentResult.data
            let input = context.parameters["input"].toString()
            let result = agent.run(input)
            bridge.updateRuntimeState(agentId, "completed")
            tasksService.updateTaskResult(taskId, result.toString(), "completed")
            return ExecutionResult(success: true, output: result.toString(), error: "")
        } catch (e: Exception) {
            bridge.updateRuntimeState(agentId, "failed")
            tasksService.updateTaskResult(taskId, "", "failed")
            return ExecutionResult(success: false, output: "", error: e.message)
        }
    }

    public func validate(taskUri: String): Bool {
        !taskUri.isEmpty()
    }
}
```

#### 3.4.2 检查点机制

```cangjie
public func saveCheckpoint(agentId: String, taskId: String,
    messages: ArrayList<Message>): Unit {
    let context = AgentContextsPO()
    context.agentId = agentId
    context.taskId = taskId
    context.messages = serializeMessages(messages)
    context.contextType = "checkpoint"
    context.metadata = "{\"step\": ${currentStep}, \"timestamp\": ${DateTime.now().toUnixTimestamp()}}"
    spawn { agentContextsService.create(context, agentId) }
}

public func loadLatestCheckpoint(agentId: String,
    taskId: String): Option<ArrayList<Message>> {
    let result = agentContextsService.findLatestCheckpoint(agentId, taskId)
    if (let Some(ctx) <- result) {
        return Some(deserializeMessages(ctx.messages))
    }
    return None<ArrayList<Message>>
}
```

#### 3.4.3 子任务树

- 复用 AgentTasks 的 `parentId` 字段建立层级关系
- 新增 `subtaskFailureStrategy` 字段：`any_fail` / `majority_success` / `all_complete`
- 子任务状态变更时，根据策略决定是否终止父任务

### 3.5 WebSocketEventBridge 事件推送（P1）

#### 3.5.1 注册为 EventHandlerManager 全局处理器

```cangjie
package magic.app.services.bridge

import magic.agent.interaction.event.{EventHandlerManager, Event}
import magic.agent.interaction.event.{
    AgentStartEvent, AgentEndEvent, AgentStepEvent,
    ToolCallStartEvent, ToolCallEndEvent,
    ChatModelEndEvent, ChatModelFailureEvent,
    AgentTimeoutEvent, UserInputEvent
}
import magic.app.controllers.uctoo.ws.WsChatController

public class WebSocketEventBridge {
    private static var instance_: Option<WebSocketEventBridge> = None
    private let wsController: WsChatController
    private let eventHandlerManager: EventHandlerManager

    public static prop instance: WebSocketEventBridge { ... }

    public init(wsController!: WsChatController,
                eventHandlerManager!: EventHandlerManager) {
        this.wsController = wsController
        this.eventHandlerManager = eventHandlerManager
    }

    public func register(): Unit {
        eventHandlerManager.register(AgentStartEvent, { event =>
            pushEvent("agent_start", event); event
        })
        eventHandlerManager.register(AgentStepEvent, { event =>
            pushEvent("agent_step", event); event
        })
        eventHandlerManager.register(AgentEndEvent, { event =>
            pushEvent("agent_end", event); event
        })
        eventHandlerManager.register(ToolCallStartEvent, { event =>
            pushEvent("tool_call_start", event); event
        })
        eventHandlerManager.register(ToolCallEndEvent, { event =>
            pushEvent("tool_call_end", event); event
        })
        eventHandlerManager.register(AgentTimeoutEvent, { event =>
            pushEvent("agent_timeout", event); event
        })
        eventHandlerManager.register(UserInputEvent, { event =>
            pushEvent("user_input_required", event); event
        })
    }

    private func pushEvent(type: String, event: Event): Unit {
        let message = buildWsMessage(type, event)
        wsController.broadcastToSubscribers("agent-execution", message)
    }

    private func buildWsMessage(type: String, event: Event): String { ... }
}
```

#### 3.5.2 事件 → WebSocket 消息映射表

| CangjieMagic 事件 | WebSocket type | payload 字段 |
|-------------------|---------------|-------------|
| `AgentStartEvent` | `agent_start` | `{agent_id, task_id, agent_name, timestamp}` |
| `AgentStepEvent` | `agent_step` | `{agent_id, task_id, step, content, timestamp}` |
| `AgentEndEvent` | `agent_end` | `{agent_id, task_id, result, total_tokens, timestamp}` |
| `ToolCallStartEvent` | `tool_call_start` | `{agent_id, task_id, tool_name, tool_args, timestamp}` |
| `ToolCallEndEvent` | `tool_call_end` | `{agent_id, task_id, tool_name, result, timestamp}` |
| `AgentTimeoutEvent` | `agent_timeout` | `{agent_id, task_id, timeout_ms, timestamp}` |
| `UserInputEvent` | `user_input_required` | `{agent_id, task_id, prompt, approval_id, timestamp}` |

#### 3.5.3 复用 WsChatController 的 WebSocket 端点

- 复用 `/api/v1/uctoo/ws/chat` 端点
- 新增 `subProtocols: ["skill-chat", "agent-execution"]`
- `agent-execution` 子协议用于 Agent 事件推送
- `WsChatController.broadcastToSubscribers(subProtocol, message)` 广播消息

### 3.6 WebHumanAgent 人机审批（P2）

#### 3.6.1 agent_approvals 表 CRUD

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["agent_approvals"]
public class AgentApprovalsPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['agent_id']
    public var agentId: String = ""

    @ORMField['task_id']
    public var taskId: String = ""

    @ORMField['approval_type']
    public var approvalType: String = "confirm"

    @ORMField['content']
    public var content: String = ""

    @ORMField['status']
    public var status: String = "pending"

    @ORMField['user_response']
    public var userResponse: Option<String> = None<String>

    @ORMField['timeout_ms']
    public var timeoutMs: Int64 = 300000

    @ORMField['creator']
    public var creator: Option<String> = None<String>

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}
    public init(agentId!: String, taskId!: String, approvalType!: String,
                content!: String, ...) { ... }
    public func toJsonValue(): JsonValue { ... }
    public func toJson(): String { ... }
}
```

#### 3.6.2 WebHumanAgent 扩展 HumanAgent

```cangjie
package magic.agent.human.web

import magic.agent.human.HumanAgent
import magic.app.services.bridge.WebSocketEventBridge
import magic.app.services.uctoo.AgentApprovalsService

public class WebHumanAgent <: HumanAgent {
    private let wsBridge = WebSocketEventBridge.instance
    private let approvalsService = AgentApprovalsService()

    public init(name!: String, model!: ChatModel, tools!: Array<Tool>) {
        super(name, model, tools)
    }

    public override func askHuman(prompt: String): String {
        let approval = AgentApprovalsPO()
        approval.agentId = this.id
        approval.taskId = this.currentTaskId
        approval.approvalType = "confirm"
        approval.content = prompt
        approval.status = "pending"
        let result = approvalsService.create(approval, this.id)

        wsBridge.pushApprovalRequest(approval)

        let response = waitForApproval(approval.id, timeout: approval.timeoutMs)
        return response
    }

    private func waitForApproval(approvalId: String,
        timeout: Int64): String { ... }
}
```

#### 3.6.3 审批工作流状态机

```
pending ──approve──→ approved ──→ Agent 继续执行
  │
  ├── reject ──→ rejected ──→ Agent 调整策略
  │
  ├── modify ──→ modified ──→ Agent 使用修改后内容继续
  │
  └── timeout ──→ expired ──→ Agent 使用默认策略
```

### 3.7 SkillAsAgent 技能组合融合（P2）

#### 3.7.1 SkillAsAgent 继承 BaseAgent

```cangjie
package magic.agent.skill

import magic.agent.agent.BaseAgent
import magic.skill.{Skill, SkillManager}
import magic.agent.tool.SkillToToolAdapter

public class SkillAsAgent <: BaseAgent {
    private let skill: Skill
    private let skillManager: SkillManager

    public init(skill!: Skill, skillManager!: SkillManager) {
        this.skill = skill
        this.skillManager = skillManager
        super(
            name: skill.name,
            systemPrompt: skill.readme,
            tools: SkillToToolAdapter.adapt(skill),
            model: skill.config.model
        )
    }

    public override func run(input: String): String {
        let toolToExecute = selectTool(input)
        let result = skillManager.execute(skill.name, toolToExecute, input)
        return result
    }
}
```

#### 3.7.2 组合模式 → AgentGroup 类型映射

| 组合模式 | AgentGroup 类型 | 映射逻辑 |
|---------|----------------|---------|
| 串行组合（skill1 → skill2 → skill3） | `LinearGroup` | 按序创建 SkillAsAgent，组成 LinearGroup |
| 并行组合（skill1 \| skill2 \| skill3） | `LeaderGroup` | leader 为编排器，members 为各 SkillAsAgent |
| 评估-改进循环 | 自定义 Group | grader → comparator → analyzer → 改进 → 重新评估 |

#### 3.7.3 组合执行结果写入 AgentTasks

```cangjie
public func executeComposition(skills: ArrayList<Skill>,
    mode: String): APIResult<AgentTasksPO> {
    let agents = ArrayList<BaseAgent>()
    for (skill in skills) {
        agents.append(SkillAsAgent(skill, skillManager))
    }
    let group = match (mode) {
        case "serial" => LinearGroup(agents)
        case "parallel" => LeaderGroup(orchestrator, agents)
        case _ => LinearGroup(agents)
    }
    let result = group.execute(input)
    let task = writeResultToAgentTasks(group.id, result)
    return APIResult<AgentTasksPO>(task)
}
```

### 3.8 Agent 监控仪表板 API（P2）

#### 3.8.1 Dashboard API 端点设计

```cangjie
public class AgentDashboardController {
    private var agentsService: AgentsService
    private var tasksService: AgentTasksService
    private var memoriesService: AgentMemoriesService
    private var usageService: LlmUsageLogsService

    public func dashboard(req: HttpRequest, res: HttpResponse): Unit {
        let activeAgents = bridge.getActiveAgentCount()
        let agentTypeDistribution = bridge.getAgentTypeDistribution()
        let runningTasks = tasksService.getRunningTasks()
        let memoryStats = memoriesService.getGlobalStats()
        let errorStats = tasksService.getErrorStats()
        let tokenStats = usageService.getRecentTokenStats()
        let data = buildDashboardJson(activeAgents, agentTypeDistribution,
            runningTasks, memoryStats, errorStats, tokenStats)
        res.status(200).json(data)
    }

    public func executionLog(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func memoryView(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func conversationView(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

#### 3.8.2 汇总数据查询逻辑

```cangjie
public func getActiveAgentCount(): Int64 {
    runtimeAgents.values().filter({ agent => agent.state == AgentState.Running }).size
}

public func getAgentTypeDistribution(): HashMap<String, Int64> {
    let dist = HashMap<String, Int64>()
    for (agent in runtimeAgents.values()) {
        let count = dist.get(agent.agentType).getOrElse(0)
        dist.put(agent.agentType, count + 1)
    }
    return dist
}
```

## 4. CangjieMagic 能力开放 API 设计

### 4.1 ExecutorController - 执行策略 API（P1）

#### 4.1.1 路由设计

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/uctoo/executors` | 执行策略列表 |
| GET | `/api/v1/uctoo/executors/:name` | 策略详情 |
| POST | `/api/v1/uctoo/executors/add` | 注册策略 |
| POST | `/api/v1/uctoo/executors/edit` | 更新策略配置 |

#### 4.1.2 Controller 代码骨架

```cangjie
package magic.app.controllers.uctoo.executors

public class ExecutorController {
    private var service: AgentExecutorsService
    public init(service: AgentExecutorsService) { this.service = service }

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        let (items, total) = service.getListWithFilter(1, 100, "", "")
        let json = buildListJson("executors", items, total)
        res.status(200).json(json)
    }

    public func getByName(req: HttpRequest, res: HttpResponse): Unit {
        let name = req.pathParam("name")
        let result = service.getByName(name)
        if (result.success) { res.status(200).json(result.data.toJson()) }
        else { res.status(404).json("{\"errno\":\"40401\",\"errmsg\":\"策略不存在\"}") }
    }

    public func add(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func edit(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

#### 4.1.3 五种预置执行策略

| 策略名 | CangjieMagic 类 | 默认配置 |
|--------|----------------|---------|
| `naive` | `NaiveExecutor` | `{}` |
| `react` | `ReactExecutor` | `{"maxLoop": 10}` |
| `plan-react` | `PlanReactExecutor` | `{"maxPlanSteps": 5, "maxLoop": 10}` |
| `tool-loop` | `ToolLoopExecutor` | `{"maxLoop": 20}` |
| `dsl` | `UserDefinedExecutor` | `{"script": ""}` |

### 4.2 AgentGroupController 扩展 - 协作模式 API（P1）

#### 4.2.1 discuss 端点

```cangjie
public func discuss(req: HttpRequest, res: HttpResponse): Unit {
    let groupId = req.pathParam("id")
    let body = parseBody(req)
    let topic = body["topic"].toString()
    let maxRound = body["maxRound"].toInt64().getOrElse(10)
    let groupResult = service.getById(groupId)
    if (!groupResult.success) { res.status(404).json(...); return }
    let group = groupResult.data
    let agentGroup = bridge.createAgentGroup(group)
    spawn {
        match (group.groupType) {
            case "free" => {
                let result = (agentGroup as FreeGroup).discuss(topic, maxRound: maxRound)
                writeDiscussResult(groupId, result)
            }
            case "auto_discuss" => {
                let result = (agentGroup as AutoDiscussGroup).discuss(maxRound: maxRound)
                writeDiscussResult(groupId, result)
            }
            case "round_robin" => {
                let result = (agentGroup as RoundRobinDiscussGroup).discuss(maxRound: maxRound)
                writeDiscussResult(groupId, result)
            }
            case _ => res.status(400).json("{\"errno\":\"40002\",\"errmsg\":\"该类型不支持讨论\"}")
        }
    }
    res.status(200).json("{\"status\":\"discussing\"}")
}
```

#### 4.2.2 compose（DSL 等效）端点

```cangjie
public func compose(req: HttpRequest, res: HttpResponse): Unit {
    let body = parseBody(req)
    let mode = body["mode"].toString()
    let leaderId = body["leaderId"].toString()
    let memberIds = body["memberIds"].toString()
    let group = AgentGroupsPO()
    match (mode) {
        case "leader" => {
            group.groupType = "leader"
            group.leaderId = Some(leaderId)
        }
        case "linear" => { group.groupType = "linear" }
        case "free" => { group.groupType = "free" }
        case _ => { res.status(400).json(...); return }
    }
    group.memberIds = memberIds
    group.name = body["name"].toString()
    let result = service.create(group, req.getLocals("userId"))
    res.status(200).json(result.data.toJson())
}
```

### 4.3 MemoryController - 记忆操作 API（P1）

```cangjie
package magic.app.controllers.uctoo.agents

public class MemoryController {
    private var memoriesService: AgentMemoriesService
    private var bridge: AgentRuntimeBridge

    public func update(req: HttpRequest, res: HttpResponse): Unit {
        let agentId = req.pathParam("id")
        let body = parseBody(req)
        let content = body["content"].toString()
        let scope = body["scope"].toString()
        let agentResult = bridge.getRuntimeAgent(agentId)
        if (let Some(agent) <- agentResult) {
            agent.memory.update(MemorySegment(content, scope))
        }
        let po = AgentMemoriesPO()
        po.agentId = agentId; po.content = content; po.scope = scope
        let result = memoriesService.create(po, req.getLocals("userId"))
        res.status(200).json(result.data.toJson())
    }

    public func search(req: HttpRequest, res: HttpResponse): Unit {
        let agentId = req.pathParam("id")
        let body = parseBody(req)
        let query = body["query"].toString()
        let topK = body["topK"].toInt64().getOrElse(5)
        let agentResult = bridge.getRuntimeAgent(agentId)
        if (let Some(agent) <- agentResult) {
            let results = agent.memory.search(query, topK: topK)
            res.status(200).json(serializeSearchResults(results))
            return
        }
        let results = memoriesService.searchByVector(agentId, query, topK)
        res.status(200).json(serializePOResults(results))
    }

    public func list(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func delete(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

### 4.4 ModelController - 模型管理 API（P1）

```cangjie
package magic.app.controllers.uctoo.models

public class ModelController {
    private var modelManager: ModelManager

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        let providers = modelManager.listProviders()
        let json = serializeProviders(providers)
        res.status(200).json(json)
    }

    public func register(req: HttpRequest, res: HttpResponse): Unit {
        let body = parseBody(req)
        let provider = body["provider"].toString()
        let baseURL = body["baseURL"].toString()
        let apiKey = body["apiKey"].toString()
        let kind = body["kind"].toString()
        modelManager.registerProvider(provider, baseURL, apiKey, kind)
        res.status(200).json("{\"status\":\"registered\"}")
    }

    public func test(req: HttpRequest, res: HttpResponse): Unit {
        let body = parseBody(req)
        let provider = body["provider"].toString()
        let model = body["model"].toString()
        let testResult = modelManager.testConnectivity(provider, model)
        res.status(200).json(serializeTestResult(testResult))
    }

    public func info(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

### 4.5 RetrieverController - RAG 检索器 API（P1）

```cangjie
package magic.app.controllers.uctoo.retrievers

public class RetrieverController {
    private var service: RetrieversService

    public func add(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func edit(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func delete(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func getSingle(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit { ... }

    public func search(req: HttpRequest, res: HttpResponse): Unit {
        let retrieverId = req.pathParam("id")
        let body = parseBody(req)
        let query = body["query"].toString()
        let topK = body["topK"].toInt64().getOrElse(5)
        let retriever = service.getById(retrieverId)
        if (!retriever.success) { res.status(404).json(...); return }
        let results = retriever.data.search(query, topK)
        res.status(200).json(serializeSearchResults(results))
    }
}
```

### 4.6 EventHandlerController - 事件处理器 API（P2）

```cangjie
package magic.app.controllers.uctoo.events

public class EventHandlerController {
    private var service: EventHandlersService
    private var eventHandlerManager: EventHandlerManager

    public func list(req: HttpRequest, res: HttpResponse): Unit {
        let handlers = eventHandlerManager.listHandlers()
        res.status(200).json(serializeHandlers(handlers))
    }

    public func register(req: HttpRequest, res: HttpResponse): Unit {
        let body = parseBody(req)
        let eventType = body["eventType"].toString()
        let handlerName = body["handlerName"].toString()
        let result = service.registerHandler(eventType, handlerName)
        res.status(200).json(result.toJson())
    }

    public func unregister(req: HttpRequest, res: HttpResponse): Unit { ... }

    public func recent(req: HttpRequest, res: HttpResponse): Unit {
        let typeParam = req.queryParam("type")
        let page = req.queryParam("page").toInt32().getOrElse(1)
        let pageSize = req.queryParam("pageSize").toInt32().getOrElse(20)
        let (events, total) = service.getRecentEvents(typeParam, page, pageSize)
        res.status(200).json(buildListJson("events", events, total))
    }
}
```

### 4.7 StorageController - 存储系统 API（P2）

```cangjie
package magic.app.controllers.uctoo.storage

public class StorageController {
    private var storageManager: StorageManager

    public func kvGet(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func kvSet(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func kvDel(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func kvListCollections(req: HttpRequest, res: HttpResponse): Unit { ... }

    public func vectorAdd(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func vectorSearch(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func vectorStats(req: HttpRequest, res: HttpResponse): Unit { ... }

    public func graphUpsertVertex(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func graphGetVertex(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func graphUpsertEdge(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func graphGetEdges(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func graphQuery(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

### 4.8 SkillValidationController - 技能验证 API（P2）

```cangjie
package magic.app.controllers.uctoo.skills

public class SkillValidationController {
    private var skillValidator: SkillValidator

    public func validate(req: HttpRequest, res: HttpResponse): Unit {
        let body = parseBody(req)
        let skillPath = body["path"].toString()
        let result = skillValidator.validateFormat(skillPath)
        res.status(200).json(serializeValidationResult(result))
    }

    public func validateSecurity(req: HttpRequest, res: HttpResponse): Unit {
        let body = parseBody(req)
        let skillPath = body["path"].toString()
        let result = skillValidator.validateSecurity(skillPath)
        res.status(200).json(serializeValidationResult(result))
    }

    public func executeSecure(req: HttpRequest, res: HttpResponse): Unit {
        let skillId = req.pathParam("id")
        let body = parseBody(req)
        let timeout = body["timeout"].toInt64().getOrElse(30000)
        let capabilities = body["capabilities"].toString()
        let result = skillValidator.executeSecure(skillId, timeout, capabilities)
        res.status(200).json(serializeExecutionResult(result))
    }
}
```

## 5. 计费系统设计

### 5.1 LlmUsageLog CRUD 模块（P0）

#### 5.1.1 LlmUsageLogsPO

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["llm_usage_logs"]
public class LlmUsageLogsPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['agent_id']
    public var agentId: Option<String> = None<String>

    @ORMField['task_id']
    public var taskId: Option<String> = None<String>

    @ORMField['provider']
    public var provider: String = ""

    @ORMField['model']
    public var model: String = ""

    @ORMField['model_id']
    public var modelId: String = ""

    @ORMField['prompt_tokens']
    public var promptTokens: Int64 = 0

    @ORMField['completion_tokens']
    public var completionTokens: Int64 = 0

    @ORMField['total_tokens']
    public var totalTokens: Int64 = 0

    @ORMField['time_cost_ms']
    public var timeCostMs: Int64 = 0

    @ORMField['request_type']
    public var requestType: String = "chat"

    @ORMField['is_streaming']
    public var isStreaming: Bool = false

    @ORMField['tool_calls_count']
    public var toolCallsCount: Int64 = 0

    @ORMField['user_id']
    public var userId: Option<String> = None<String>

    @ORMField['session_id']
    public var sessionId: Option<String> = None<String>

    @ORMField['cost_amount']
    public var costAmount: Float64 = 0.0

    @ORMField['cost_currency']
    public var costCurrency: String = "CNY"

    @ORMField['rate_prompt']
    public var ratePrompt: Float64 = 0.0

    @ORMField['rate_completion']
    public var rateCompletion: Float64 = 0.0

    @ORMField['request_id']
    public var requestId: Option<String> = None<String>

    @ORMField['error_message']
    public var errorMessage: Option<String> = None<String>

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    public init() {}
    public init(provider!: String, model!: String, ...) { ... }
    public func toJsonValue(): JsonValue { ... }
    public func toJson(): String { ... }
}
```

#### 5.1.2 LlmUsageLogsDAO

```cangjie
@DAO
public interface LlmUsageLogsDAO <: RootDAO {
    prop executor: SqlExecutor

    func insertLlmUsageLog(entity: LlmUsageLogsPO): String {
        executor.setSql('''
            insert into llm_usage_logs(agent_id, task_id, provider, model, model_id,
                prompt_tokens, completion_tokens, total_tokens, time_cost_ms,
                request_type, is_streaming, tool_calls_count, user_id, session_id,
                cost_amount, cost_currency, rate_prompt, rate_completion,
                request_id, error_message, created_at)
            values(${arg(entity.agentId)}, ${arg(entity.taskId)}, ${arg(entity.provider)},
                ${arg(entity.model)}, ${arg(entity.modelId)}, ${arg(entity.promptTokens)},
                ${arg(entity.completionTokens)}, ${arg(entity.totalTokens)},
                ${arg(entity.timeCostMs)}, ${arg(entity.requestType)},
                ${arg(entity.isStreaming)}, ${arg(entity.toolCallsCount)},
                ${arg(entity.userId)}, ${arg(entity.sessionId)}, ${arg(entity.costAmount)},
                ${arg(entity.costCurrency)}, ${arg(entity.ratePrompt)},
                ${arg(entity.rateCompletion)}, ${arg(entity.requestId)},
                ${arg(entity.errorMessage)}, ${arg(entity.createdAt)})
            returning id
        ''').singleFirst<String>() ?? ""
    }

    func findLlmUsageLogById(id: String): Option<LlmUsageLogsPO> { ... }

    func findLlmUsageLogByCondition(whereClause: String, orderByClause: String,
        page: Int64, size: Int64): Pagination<LlmUsageLogsPO> { ... }

    func sumTokensByAgent(agentId: String, fromTime: DateTime,
        toTime: DateTime): HashMap<String, Int64> {
        executor.setSql('''
            select coalesce(sum(prompt_tokens),0) as prompt_sum,
                   coalesce(sum(completion_tokens),0) as completion_sum,
                   coalesce(sum(total_tokens),0) as total_sum
            from llm_usage_logs
            where agent_id = ${arg(agentId)}
                and created_at >= ${arg(fromTime)} and created_at <= ${arg(toTime)}
        ''').first<HashMap<String, Int64>>() ?? HashMap<String, Int64>()
    }

    func sumCostByProvider(fromTime: DateTime,
        toTime: DateTime): ArrayList<HashMap<String, Any>> { ... }
}
```

#### 5.1.3 LlmUsageLogsService

```cangjie
package magic.app.services.uctoo

public class LlmUsageLogsService {
    private func getExecutor(): SqlExecutor { ORM.executor() }
    private let requestParser = RequestParserService()
    private let pricingService = ModelPricingService()
    public init() {}

    public func create(entity: LlmUsageLogsPO,
        creatorId: String): APIResult<LlmUsageLogsPO> {
        let pricing = pricingService.getActivePricing(entity.provider, entity.model)
        if (let Some(p) <- pricing) {
            entity.ratePrompt = p.ratePromptPerMillion
            entity.rateCompletion = p.rateCompletionPerMillion
            entity.costCurrency = p.rateCurrency
            entity.costAmount = calculateCost(entity.promptTokens,
                entity.completionTokens, p.ratePromptPerMillion, p.rateCompletionPerMillion)
        }
        try {
            let id = getExecutor().insertLlmUsageLog(entity)
            if (!id.isEmpty()) { entity.id = id; return APIResult<LlmUsageLogsPO>(entity) }
            return APIResult<LlmUsageLogsPO>(false, "写入失败")
        } catch (e: Exception) { return APIResult<LlmUsageLogsPO>(false, e.message) }
    }

    public func calculateCost(promptTokens: Int64, completionTokens: Int64,
        ratePrompt: Float64, rateCompletion: Float64): Float64 {
        (Float64(promptTokens) / 1000000.0) * ratePrompt
            + (Float64(completionTokens) / 1000000.0) * rateCompletion
    }

    public func getListWithFilter(page: Int32, pageSize: Int32, sort: String,
        filter: String): (ArrayList<LlmUsageLogsPO>, Int64) { ... }

    public func getSummary(fromTime: DateTime,
        toTime: DateTime): HashMap<String, Any> { ... }
    public func getByAgent(agentId: String, fromTime: DateTime,
        toTime: DateTime): HashMap<String, Any> { ... }
    public func getByModel(model: String, fromTime: DateTime,
        toTime: DateTime): HashMap<String, Any> { ... }
    public func getTrends(days: Int64): ArrayList<HashMap<String, Any>> { ... }
    public func getTopAgents(limit: Int64,
        fromTime: DateTime): ArrayList<HashMap<String, Any>> { ... }
}
```

#### 5.1.4 ChatModelEndEvent → 异步写入流程

```cangjie
package magic.app.services.billing

public class BillingEventHandler {
    private let usageService = LlmUsageLogsService()

    public func onChatModelEnd(event: ChatModelEndEvent): Event {
        let usage = event.usage
        let log = LlmUsageLogsPO()
        log.agentId = Some(event.agentId)
        log.taskId = Some(event.taskId)
        log.provider = event.provider
        log.model = event.model
        log.modelId = "${event.provider}:${event.model}"
        log.promptTokens = usage.promptTokens
        log.completionTokens = usage.completionTokens
        log.totalTokens = usage.totalTokens
        log.timeCostMs = usage.timeCost.map({ d => d.toUnixMilliseconds() }).getOrElse(0)
        log.requestType = "chat"
        log.isStreaming = event.isStreaming
        log.requestId = Some(event.requestId)
        spawn { usageService.create(log, event.agentId) }
        return event
    }

    public func onChatModelFailure(event: ChatModelFailureEvent): Event {
        let log = LlmUsageLogsPO()
        log.provider = event.provider
        log.model = event.model
        log.modelId = "${event.provider}:${event.model}"
        log.completionTokens = 0
        log.errorMessage = Some(event.error.message)
        spawn { usageService.create(log, "system") }
        return event
    }

    public func onAgentEnd(event: AgentEndEvent): Event {
        spawn { updateAgentTaskTokenSummary(event.agentId, event.taskId, event.totalTokens) }
        return event
    }
}
```

### 5.2 ModelPricing CRUD 模块（P0）

#### 5.2.1 ModelPricingPO

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["model_pricing"]
public class ModelPricingPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['provider']
    public var provider: String = ""

    @ORMField['model']
    public var model: String = ""

    @ORMField['model_id']
    public var modelId: String = ""

    @ORMField['rate_prompt_per_million']
    public var ratePromptPerMillion: Float64 = 0.0

    @ORMField['rate_completion_per_million']
    public var rateCompletionPerMillion: Float64 = 0.0

    @ORMField['rate_currency']
    public var rateCurrency: String = "CNY"

    @ORMField['rate_unit']
    public var rateUnit: String = "per_million_tokens"

    @ORMField['is_active']
    public var isActive: Bool = true

    @ORMField['effective_from']
    public var effectiveFrom: DateTime = DateTime.now()

    @ORMField['effective_to']
    public var effectiveTo: Option<DateTime> = None<DateTime>

    @ORMField['source']
    public var source: String = "official"

    @ORMField['remark']
    public var remark: Option<String> = None<String>

    @ORMField['creator']
    public var creator: Option<String> = None<String>

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}
    public init(provider!: String, model!: String,
                ratePromptPerMillion!: Float64, rateCompletionPerMillion!: Float64, ...) { ... }
    public func toJsonValue(): JsonValue { ... }
    public func toJson(): String { ... }
}
```

#### 5.2.2 ModelPricingService

```cangjie
package magic.app.services.uctoo

public class ModelPricingService {
    private func getExecutor(): SqlExecutor { ORM.executor() }
    public init() {}

    public func create(entity: ModelPricingPO,
        creatorId: String): APIResult<ModelPricingPO> { ... }
    public func update(entityId: String,
        entity: ModelPricingPO): APIResult<ModelPricingPO> { ... }
    public func delete(entityId: String,
        force: Bool): APIResult<Bool> { ... }
    public func getById(entityId: String): APIResult<ModelPricingPO> { ... }

    public func getActivePricing(provider: String,
        model: String): Option<ModelPricingPO> {
        let modelId = "${provider}:${model}"
        let now = DateTime.now()
        getExecutor().findActivePricingByModelId(modelId, now)
    }

    public func getListWithFilter(page: Int32, pageSize: Int32, sort: String,
        filter: String): (ArrayList<ModelPricingPO>, Int64) { ... }
}
```

#### 5.2.3 计费计算逻辑

```
cost = (prompt_tokens / 1,000,000) × rate_prompt_per_million
     + (completion_tokens / 1,000,000) × rate_completion_per_million
```

- 查询 `model_pricing` 表获取当前生效费率（`is_active = true AND effective_from <= now AND (effective_to IS NULL OR effective_to >= now)`）
- 未配置费率的模型按 0 计费
- 本地模型（ollama/llamacpp）费率预置为 0

#### 5.2.4 18个提供商费率预置数据

| provider | model | rate_prompt_per_million | rate_completion_per_million | rate_currency |
|----------|-------|------------------------|----------------------------|---------------|
| openai | gpt-4o | 17.5 | 70.0 | USD |
| openai | gpt-4o-mini | 0.15 | 0.6 | USD |
| openai | gpt-4-turbo | 70.0 | 210.0 | USD |
| openai | text-embedding-3-large | 10.0 | 0.0 | USD |
| deepseek | deepseek-chat | 1.0 | 2.0 | CNY |
| deepseek | deepseek-reasoner | 4.0 | 16.0 | CNY |
| dashscope | qwen-plus | 0.8 | 2.0 | CNY |
| dashscope | qwen-turbo | 0.3 | 0.6 | CNY |
| dashscope | qwen-max | 20.0 | 60.0 | CNY |
| zhipuai | glm-4 | 50.0 | 50.0 | CNY |
| zhipuai | glm-4-flash | 1.0 | 1.0 | CNY |
| moonshot | moonshot-v1-8k | 12.0 | 12.0 | CNY |
| stepfun | step-2-16k | 3.4 | 13.6 | CNY |
| siliconflow | Qwen/Qwen2.5-72B-Instruct | 4.13 | 4.13 | CNY |
| ark | doubao-pro-32k | 0.8 | 2.0 | CNY |
| ark | doubao-lite-32k | 0.3 | 0.6 | CNY |
| ollama | * | 0.0 | 0.0 | CNY |
| llamacpp | * | 0.0 | 0.0 | CNY |

### 5.3 Token 统计 API（P1）

#### 5.3.1 多维统计查询设计

```cangjie
public class TokenStatsController {
    private var usageService: LlmUsageLogsService

    public func summary(req: HttpRequest, res: HttpResponse): Unit {
        let from = parseTimeParam(req, "from", DateTime.now() - Duration.day * 30)
        let to = parseTimeParam(req, "to", DateTime.now())
        let data = usageService.getSummary(from, to)
        res.status(200).json(serializeSummary(data))
    }

    public func byAgent(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func byModel(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func byUser(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func byDate(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func trends(req: HttpRequest, res: HttpResponse): Unit {
        let days = req.queryParam("days").toInt64().getOrElse(7)
        let data = usageService.getTrends(days)
        res.status(200).json(serializeTrends(data))
    }
    public func topAgents(req: HttpRequest, res: HttpResponse): Unit { ... }
    public func topModels(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

#### 5.3.2 趋势数据查询

```cangjie
func getTrends(days: Int64): ArrayList<HashMap<String, Any>> {
    let from = DateTime.now() - Duration.day * days
    getExecutor().findDailyTrends(from)
}
```

SQL:
```sql
SELECT DATE(created_at) as date,
       SUM(total_tokens) as total_tokens,
       SUM(cost_amount) as total_cost
FROM llm_usage_logs
WHERE created_at >= $1
GROUP BY DATE(created_at)
ORDER BY date
```

### 5.4 UsageQuota 配额控制（P2）

#### 5.4.1 UsageQuotasPO

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["usage_quotas"]
public class UsageQuotasPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['target_type']
    public var targetType: String = "user"

    @ORMField['target_id']
    public var targetId: String = ""

    @ORMField['quota_type']
    public var quotaType: String = "daily_tokens"

    @ORMField['quota_limit']
    public var quotaLimit: Float64 = 0.0

    @ORMField['quota_used']
    public var quotaUsed: Float64 = 0.0

    @ORMField['quota_period_start']
    public var quotaPeriodStart: DateTime = DateTime.now()

    @ORMField['is_hard_limit']
    public var isHardLimit: Bool = true

    @ORMField['alert_threshold']
    public var alertThreshold: Float64 = 0.8

    @ORMField['creator']
    public var creator: Option<String> = None<String>

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}
    public init(targetType!: String, targetId!: String, quotaType!: String, ...) { ... }
    public func toJsonValue(): JsonValue { ... }
    public func toJson(): String { ... }
}
```

#### 5.4.2 配额检查流程

```cangjie
public func checkQuota(targetType: String, targetId: String,
    quotaType: String): QuotaCheckResult {
    let quota = getActiveQuota(targetType, targetId, quotaType)
    if (let Some(q) <- quota) {
        if (q.quotaUsed >= q.quotaLimit) {
            if (q.isHardLimit) {
                return QuotaCheckResult(blocked: true, reason: "配额已用尽")
            }
            return QuotaCheckResult(blocked: false, warning: "配额已超限")
        }
        if (q.quotaUsed / q.quotaLimit >= q.alertThreshold) {
            return QuotaCheckResult(blocked: false, warning: "配额接近上限")
        }
    }
    return QuotaCheckResult(blocked: false)
}
```

#### 5.4.3 周期重置 Crontab 任务

```cangjie
public class QuotaResetExecutor <: BuiltinTaskHandler {
    public prop name: String { get() { "quota-reset" } }

    public func execute(parameters: HashMap<String, Any>): ExecutionResult {
        let quotaType = parameters["quotaType"].toString()
        let now = DateTime.now()
        getExecutor().resetQuotaByType(quotaType, now)
        return ExecutionResult(success: true, output: "配额已重置", error: "")
    }
}
```

## 6. 前端融合设计

### 6.1 WebMCP 修复方案

#### 6.1.1 已知 Bug 修复

1. **WebMcpServer 工具注册时序问题**：确保 Agent 连接前工具已注册完毕
2. **WebMcpClient 调用链断裂**：修复 Agent → WebMCP → 前端工具 → 结果返回的完整链路
3. **工具响应序列化问题**：确保前端工具返回值正确序列化为 MCP 协议格式

#### 6.1.2 新增 Agent 专用工具

| 工具名 | 功能 | 实现位置 |
|--------|------|---------|
| `web_navigate` | 导航到指定前端页面 | WebMcpServer 注册 |
| `web_notify` | 向前端推送通知消息 | WebSocketEventBridge |
| `web_request_approval` | 请求用户审批 | WebHumanAgent |

#### 6.1.3 前端工具注册扩展

| 工具模块 | 工具 | 功能 |
|---------|------|------|
| `agent_control` | agent_start/stop/pause/resume | Agent 生命周期管理 |
| `task_monitor` | task_progress/task_list | 任务进度查看 |
| `memory_browse` | memory_search/memory_list | 记忆浏览和搜索 |

### 6.2 pinia-orm 模型自动生成

#### 6.2.1 全栈生成流程

```bash
crudgen --table agent_groups --full-stack
# 生成:
# 后端: AgentGroupsPO.cj + AgentGroupsDAO.cj + AgentGroupsService.cj
#        + AgentGroupsController.cj + AgentGroupsRoute.cj
# 前端: src/store/models/uctoo/agentGroups.ts (pinia-orm Model)
#        + src/views/database/uctoo/agent_groups/ (CRUD 页面)
```

#### 6.2.2 pinia-orm 模型模板

```typescript
import { Model } from 'pinia-orm'

export default class AgentGroup extends Model {
  static entity = 'agent_groups'
  static primaryKey = 'id'

  static fields() {
    return {
      id: this.string(''),
      name: this.string(''),
      groupType: this.attr('leader'),
      leaderId: this.string(null),
      memberIds: this.attr([]),
      config: this.attr({}),
      status: this.attr('idle'),
      maxRound: this.number(10),
      description: this.string(null),
      creator: this.string(null),
      createdAt: this.attr(null),
      updatedAt: this.attr(null),
    }
  }

  static apiConfig = {
    baseURL: '/api/v1/uctoo/agent_groups',
    actions: {
      add: { method: 'post', url: '/add' },
      edit: { method: 'post', url: '/edit' },
      del: { method: 'post', url: '/del' },
    },
  }
}
```

#### 6.2.3 API 契约验证

- 应用启动时，遍历所有 pinia-orm Model 的 `fields()`
- 对每个 Model，请求 `GET /api/v1/uctoo/{entity}/1/1` 获取第一条记录
- 比较返回字段与 Model 定义字段，不一致时输出告警日志
- 校验不阻塞应用启动

### 6.3 Agent 监控页面设计

#### 6.3.1 Agent 实时状态监控页面（views/ai/agent-monitor.vue）

| 组件 | 数据源 | 更新方式 |
|------|--------|---------|
| Agent 状态卡片 | agents pinia-orm + WebSocket | WebSocket 驱动实时更新 |
| 任务进度条 | agent_tasks pinia-orm | WebSocket 驱动 |
| 协作拓扑图 | agent_groups pinia-orm | DAG 可视化（D3.js/vx） |
| Token 消耗统计 | llm_usage_logs pinia-orm | 定时刷新 |

#### 6.3.2 Agent 详情页面（views/ai/agent-detail.vue）

| 标签页 | 数据源 | 说明 |
|--------|--------|------|
| 配置 | agents model | Agent 配置详情 |
| 执行历史 | agent_tasks model | 时间线展示 |
| 对话 | agent_contexts model | 对话历史 |
| 记忆 | agent_memories model | 记忆浏览和搜索 |
| 权限审批 | agent_approvals model | 审批记录 |

### 6.4 TinyRobot 深度集成

#### 6.4.1 对话自动关联 Agent

```typescript
class AgentAwareChatProvider extends CustomAgentModelProvider {
  async sendMessage(message: string) {
    if (!this.currentAgent) {
      this.currentAgent = await this.createOrLoadAgent()
      await this.persistToAgentContexts(message)
    }
    const response = await super.sendMessage(message)
    await this.recordToolCallsToAgentTasks(response)
    return response
  }

  async switchAgent(agentId: string) {
    this.currentAgent = await useAgentStore().fetchById(agentId)
    this.updateSystemPrompt(this.currentAgent.systemPrompt)
    this.updateTools(this.currentAgent.tools)
  }
}
```

#### 6.4.2 子 Agent 可视化

- 子 Agent 执行时在对话中显示为嵌套卡片（TinyRobot Bubble 组件）
- 卡片内容：Agent 名称、执行状态、进度、结果
- 支持折叠/展开查看子 Agent 结果
- Agent 请求审批时弹出审批对话框（确认/拒绝/修改后确认）

### 6.5 技能统一管理

- 技能列表页 `views/ai/agent_skills.vue` 增强：
  - 显示技能来源标签：`browser-side`（前端技能）/ `server-side`（后端技能）
  - 前端技能：WebMCP 注册的工具
  - 后端技能：SkillManager 管理的技能
- 技能详情页：显示 SKILL.md 正文、agents 声明、脚本列表
- agent_skills 表通过 SyncManager 同步到文件系统

### 6.6 全链路可观测

- 时间线页面 `views/database/uctoo/observability.vue`：
  - 数据来源：operate_log + agent_tasks + sync_log + crontab_log
  - 时间线：用户操作 → API 调用 → Agent 执行 → 工具调用 → 数据库变更 → 同步事件
  - 支持按 Agent、任务、时间范围筛选
- 数据流可视化：
  - 文件 → 数据库同步流（SyncManager 状态）
  - 数据库 → 前端数据流（pinia-orm API 调用）
  - Agent → 工具 → 结果流（AgentTasks + EventStream）

## 7. 数据库设计

### 7.1 新增表 DDL

#### agent_groups

```sql
CREATE TABLE agent_groups (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    group_type VARCHAR(20) NOT NULL DEFAULT 'leader',
    leader_id VARCHAR(36),
    member_ids JSONB NOT NULL DEFAULT '[]',
    config JSONB NOT NULL DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'idle',
    max_round BIGINT NOT NULL DEFAULT 10,
    description TEXT,
    creator VARCHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX idx_agent_groups_type ON agent_groups(group_type);
CREATE INDEX idx_agent_groups_status ON agent_groups(status);
CREATE INDEX idx_agent_groups_creator ON agent_groups(creator);
```

#### agent_memories

```sql
CREATE TABLE agent_memories (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id VARCHAR(36) NOT NULL,
    content TEXT NOT NULL,
    embedding_vector VECTOR(1536),
    scope VARCHAR(20) NOT NULL DEFAULT 'episodic',
    weight DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    tags JSONB NOT NULL DEFAULT '[]',
    metadata JSONB NOT NULL DEFAULT '{}',
    task_id VARCHAR(36),
    session_id VARCHAR(100),
    creator VARCHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX idx_agent_memories_agent ON agent_memories(agent_id);
CREATE INDEX idx_agent_memories_scope ON agent_memories(scope);
CREATE INDEX idx_agent_memories_agent_scope ON agent_memories(agent_id, scope);
CREATE INDEX idx_agent_memories_embedding ON agent_memories
    USING ivfflat (embedding_vector vector_cosine_ops) WITH (lists = 100);
```

#### agent_approvals

```sql
CREATE TABLE agent_approvals (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id VARCHAR(36) NOT NULL,
    task_id VARCHAR(36) NOT NULL,
    approval_type VARCHAR(20) NOT NULL DEFAULT 'confirm',
    content TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    user_response TEXT,
    timeout_ms BIGINT NOT NULL DEFAULT 300000,
    creator VARCHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX idx_agent_approvals_agent ON agent_approvals(agent_id);
CREATE INDEX idx_agent_approvals_status ON agent_approvals(status);
CREATE INDEX idx_agent_approvals_pending ON agent_approvals(status, created_at)
    WHERE status = 'pending';
```

#### llm_usage_logs

```sql
CREATE TABLE llm_usage_logs (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id VARCHAR(100),
    task_id VARCHAR(100),
    provider VARCHAR(50) NOT NULL,
    model VARCHAR(100) NOT NULL,
    model_id VARCHAR(200) NOT NULL,
    prompt_tokens BIGINT NOT NULL DEFAULT 0,
    completion_tokens BIGINT NOT NULL DEFAULT 0,
    total_tokens BIGINT NOT NULL DEFAULT 0,
    time_cost_ms INTEGER NOT NULL DEFAULT 0,
    request_type VARCHAR(20) NOT NULL DEFAULT 'chat',
    is_streaming BOOLEAN NOT NULL DEFAULT FALSE,
    tool_calls_count INTEGER NOT NULL DEFAULT 0,
    user_id VARCHAR(36),
    session_id VARCHAR(100),
    cost_amount DECIMAL(12,6) NOT NULL DEFAULT 0,
    cost_currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
    rate_prompt DECIMAL(12,6) NOT NULL DEFAULT 0,
    rate_completion DECIMAL(12,6) NOT NULL DEFAULT 0,
    request_id VARCHAR(100),
    error_message VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_llm_usage_agent ON llm_usage_logs(agent_id);
CREATE INDEX idx_llm_usage_model ON llm_usage_logs(model_id);
CREATE INDEX idx_llm_usage_provider ON llm_usage_logs(provider);
CREATE INDEX idx_llm_usage_created ON llm_usage_logs(created_at);
CREATE INDEX idx_llm_usage_user ON llm_usage_logs(user_id);
CREATE INDEX idx_llm_usage_agent_created ON llm_usage_logs(agent_id, created_at);
```

#### model_pricing

```sql
CREATE TABLE model_pricing (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    provider VARCHAR(50) NOT NULL,
    model VARCHAR(100) NOT NULL,
    model_id VARCHAR(200) NOT NULL,
    rate_prompt_per_million DECIMAL(12,6) NOT NULL DEFAULT 0,
    rate_completion_per_million DECIMAL(12,6) NOT NULL DEFAULT 0,
    rate_currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
    rate_unit VARCHAR(20) NOT NULL DEFAULT 'per_million_tokens',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    source VARCHAR(200) NOT NULL DEFAULT 'official',
    remark VARCHAR(500),
    creator VARCHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE UNIQUE INDEX idx_model_pricing_unique ON model_pricing(provider, model)
    WHERE deleted_at IS NULL AND is_active = TRUE;
CREATE INDEX idx_model_pricing_active ON model_pricing(is_active, effective_from, effective_to);
```

#### usage_quotas

```sql
CREATE TABLE usage_quotas (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type VARCHAR(20) NOT NULL DEFAULT 'user',
    target_id VARCHAR(100) NOT NULL,
    quota_type VARCHAR(20) NOT NULL DEFAULT 'daily_tokens',
    quota_limit DECIMAL(18,2) NOT NULL DEFAULT 0,
    quota_used DECIMAL(18,2) NOT NULL DEFAULT 0,
    quota_period_start TIMESTAMP NOT NULL DEFAULT NOW(),
    is_hard_limit BOOLEAN NOT NULL DEFAULT TRUE,
    alert_threshold DOUBLE PRECISION NOT NULL DEFAULT 0.8,
    creator VARCHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE UNIQUE INDEX idx_usage_quotas_unique ON usage_quotas(target_type, target_id, quota_type)
    WHERE deleted_at IS NULL;
```

#### agent_executors

```sql
CREATE TABLE agent_executors (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    default_config JSONB NOT NULL DEFAULT '{}',
    config_schema JSONB NOT NULL DEFAULT '{}',
    is_builtin BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    creator VARCHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);
```

#### retrievers

```sql
CREATE TABLE retrievers (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'markdown',
    source_path VARCHAR(500) NOT NULL,
    embedding_model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    config JSONB NOT NULL DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    description TEXT,
    creator VARCHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX idx_retrievers_type ON retrievers(type);
```

#### event_handlers

```sql
CREATE TABLE event_handlers (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL,
    handler_name VARCHAR(200) NOT NULL,
    handler_class VARCHAR(500) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    config JSONB NOT NULL DEFAULT '{}',
    description TEXT,
    creator VARCHAR(36),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX idx_event_handlers_type ON event_handlers(event_type);
CREATE UNIQUE INDEX idx_event_handlers_unique ON event_handlers(event_type, handler_name)
    WHERE deleted_at IS NULL;
```

### 7.2 与现有表的关联关系

```
agents (已有)
  ├── agent_groups.member_ids → agents.id (JSON 数组引用)
  ├── agent_groups.leader_id → agents.id
  ├── agent_memories.agent_id → agents.id
  ├── agent_approvals.agent_id → agents.id
  ├── llm_usage_logs.agent_id → agents.id
  └── agent_executors (独立，被 agents.config 引用)

agent_tasks (已有)
  ├── agent_approvals.task_id → agent_tasks.id
  └── llm_usage_logs.task_id → agent_tasks.id

agent_contexts (已有)
  └── agent_memories.session_id → agent_contexts.session_id

model_pricing (新增，独立)
  └── llm_usage_logs.rate_prompt/rate_completion ← model_pricing

usage_quotas (新增，独立)
  └── llm_usage_logs.user_id → usage_quotas.target_id

retrievers (新增，独立)
  └── agents.config.retrieverId → retrievers.id

event_handlers (新增，独立)
```

### 7.3 pgvector 扩展

**当前兼容方案**：若 PostgreSQL 未安装 pgvector 扩展，`embedding_vector` 列使用 `TEXT` 类型存储 JSON 序列化的浮点数组（如 `"[0.1,0.2,...]"`）。安装 pgvector 后可执行 `ALTER TABLE` 升级为 `VECTOR(1536)` 类型并创建 ivfflat 索引，详见 `docs/sql/v4_fusion_all_tables.sql` 附录。

```sql
-- 安装 pgvector 后执行升级
CREATE EXTENSION IF NOT EXISTS vector;
ALTER TABLE agent_memories ALTER COLUMN embedding_vector TYPE VECTOR(1536)
    USING embedding_vector::jsonb::text::vector;
CREATE INDEX idx_agent_memories_embedding ON agent_memories
    USING ivfflat (embedding_vector vector_cosine_ops) WITH (lists = 100);
```

agent_memories.embedding_vector 默认使用 TEXT 存储（JSON序列化向量），安装 pgvector 后可升级为 `VECTOR(1536)` 类型（OpenAI text-embedding-3-small 维度），支持 ivfflat 索引加速余弦相似度搜索。

## 8. CLI 命令设计

| 命令 | 说明 | 优先级 |
|------|------|--------|
| `agentskills bridge create <agent-id>` | 从数据库加载 Agent 并创建运行时实例 | P0 |
| `agentskills bridge sync <agent-id>` | 手动同步 Agent 状态到数据库 | P0 |
| `agentskills bridge load-all` | 加载所有持久化 Agent | P0 |
| `agentskills memory update <agent-id> --content <text> --scope <scope>` | 写入记忆 | P1 |
| `agentskills memory search <agent-id> --query <question> --top-k <n>` | 语义检索记忆 | P1 |
| `agentskills group create --name <name> --type <type> --leader <id> --members <ids>` | 创建 Agent 组 | P1 |
| `agentskills group discuss <group-id> --topic <topic> --max-round <n>` | 发起讨论 | P1 |
| `agentskills group execute <group-id> --input <text>` | 执行 Agent 组任务 | P1 |
| `agentskills executor list` | 列出执行策略 | P1 |
| `agentskills executor info <name>` | 查看策略详情 | P1 |
| `agentskills model list` | 列出模型提供商 | P1 |
| `agentskills model test <provider>/<model>` | 测试模型连通性 | P1 |
| `agentskills retriever create --type <type> --source <path>` | 创建检索器 | P1 |
| `agentskills retriever search <id> --query <question>` | 执行语义检索 | P1 |
| `agentskills event handlers` | 列出事件处理器 | P2 |
| `agentskills event recent --type <type>` | 查询最近事件 | P2 |
| `agentskills storage kv <get\|set\|del> <collection> <key>` | KV 存储操作 | P2 |
| `agentskills storage vector <add\|search> <collection>` | 向量存储操作 | P2 |
| `agentskills storage graph <vertex\|edge> <add\|get\|query> <collection>` | 图存储操作 | P2 |
| `agentskills skill validate <path>` | 验证技能格式 | P2 |
| `agentskills skill validate-security <path>` | 技能安全检查 | P2 |
| `agentskills billing summary --from <date> --to <date>` | Token 用量汇总 | P1 |
| `agentskills billing export --format <xlsx\|csv> --from <date> --to <date>` | 导出计费报表 | P2 |

## 9. 实施路线图

### P0 阶段（核心基础，约 13 人天）

| 任务 | 类型 | 工时 | 依赖 |
|------|------|------|------|
| AgentRuntimeBridge 实现 | 后端 | 3d | - |
| AgentMemories CRUD 五层 | 后端+数据库 | 2d | - |
| DatabaseMemory + TieredMemory 实现 | 后端 | 3d | AgentRuntimeBridge |
| LlmUsageLogs CRUD 五层 | 后端+数据库 | 2d | - |
| ModelPricing CRUD 五层 + 费率预置 | 后端+数据库 | 2d | - |
| BillingEventHandler 事件集成 | 后端 | 1d | LlmUsageLogs |
| WebMCP 调用链修复 | 前端+后端 | 3d | - |

**数据库迁移**：agent_memories + llm_usage_logs + model_pricing + pgvector 扩展

### P1 阶段（能力扩展，约 24 人天）

| 任务 | 类型 | 工时 | 依赖 |
|------|------|------|------|
| AgentExecutionExecutor 实现 | 后端 | 2d | AgentRuntimeBridge |
| 检查点机制实现 | 后端 | 2d | AgentExecutionExecutor |
| WebSocketEventBridge 实现 | 后端 | 2d | AgentRuntimeBridge |
| AgentGroups CRUD 五层 | 后端+数据库 | 3d | - |
| AgentGroup 执行与状态查询 | 后端 | 2d | AgentGroups, Bridge |
| AgentExecutors CRUD 五层 + 预置策略 | 后端+数据库 | 2d | - |
| ExecutorController API | 后端 | 1d | AgentExecutors |
| AgentGroupController 扩展（discuss/compose） | 后端 | 2d | AgentGroups |
| MemoryController API | 后端 | 1d | AgentMemories |
| ModelController API | 后端 | 1d | - |
| Retrievers CRUD 五层 + Controller | 后端+数据库 | 2d | - |
| Token 统计 API + 仪表板页面 | 后端+前端 | 3d | LlmUsageLogs, ModelPricing |
| pinia-orm 全栈生成集成 | 前端+后端 | 2d | Bridge |
| TinyRobot Agent 集成 | 前端 | 2d | WebMCP, WebSocket |
| EventHandlerManager 计费集成 | 后端 | 1d | BillingEventHandler |

**数据库迁移**：agent_groups + agent_executors + retrievers

### P2 阶段（增强功能，约 22 人天）

| 任务 | 类型 | 工时 | 依赖 |
|------|------|------|------|
| 记忆分层存储实现 | 后端 | 2d | DatabaseMemory |
| AgentApprovals CRUD 五层 | 后端+数据库 | 2d | - |
| WebHumanAgent 实现 | 后端 | 2d | WebSocket, Approvals |
| SkillAsAgent + 组合融合 | 后端 | 3d | Bridge, Groups |
| Agent 监控仪表板 API + 页面 | 后端+前端 | 3d | Groups, WebSocket |
| Agent 详情 + 历史页面 | 前端 | 2d | Dashboard |
| UsageQuotas CRUD + 配额检查 | 后端+数据库 | 2d | Billing |
| 配额周期重置 Crontab | 后端 | 1d | UsageQuotas |
| 计费报表 + 导出 | 后端+前端 | 2d | Token 统计 |
| EventHandlers CRUD + Controller | 后端+数据库 | 2d | - |
| StorageController API | 后端 | 1d | - |
| SkillValidationController API | 后端 | 1d | - |
| 技能统一管理页面增强 | 前端 | 1d | WebMCP |
| API 契约验证 | 前端 | 1d | pinia-orm |
| 执行策略运行时切换 | 后端 | 1d | ExecutorController |

**数据库迁移**：agent_approvals + usage_quotas + event_handlers

### P3 阶段（可观测性，约 4 人天）

| 任务 | 类型 | 工时 | 依赖 |
|------|------|------|------|
| 全链路可观测时间线页面 | 前端 | 2d | Dashboard |
| 数据流可视化 | 前端 | 1d | Observability |
| 数据资产仪表板 | 前端 | 1d | Observability |

### 总工时汇总

| 阶段 | 后端 | 前端 | 数据库 | 合计 |
|------|------|------|--------|------|
| P0 | 11d | 3d | 2d | 16d |
| P1 | 19d | 7d | 2d | 28d |
| P2 | 17d | 7d | 2d | 26d |
| P3 | 0d | 4d | 0d | 4d |
| **合计** | **47d** | **21d** | **6d** | **74d** |

---

## 11. 数据流闭环集成设计（补充）

### 11.1 问题分析

当前 WebMCP 聊天数据流存在 6 个断裂点，导致聊天后业务表无数据：

| 断裂点 | 文件 | 行号 | 影响 |
|--------|------|------|------|
| FP-1: BillingEventHandler 未注册 | main.cj | setupRoutes() | llm_usage_logs 无数据 |
| FP-2: WebSocketEventBridge 未注册 | main.cj | setupRoutes() | WebSocket 事件不推送 |
| FP-3: SkillAwareAgent 未设置 memory | WebMCPProtocol.cj:38-44 | 构造函数 | agent_memories 无数据 |
| FP-4: SkillAwareAgent 未设置 eventHandlerManager | WebMCPProtocol.cj:38-44 | 构造函数 | Agent 级事件不触发 |
| FP-5: 降级路径绕过事件系统 | WebMCPProtocol.cj:492-497 | handleCompletionComplete | 无任何事件触发 |
| FP-6: Agent 执行后无数据库同步 | WebMCPProtocol.cj:488-491 | handleCompletionComplete | agents/agent_contexts 无数据 |

### 11.2 闭环数据流设计

修复后的完整数据流：

```
前端 POST /api/v1/uctoo/webmcp/mcp (completion/complete)
  │
  ▼
WebMCPProtocol.handleCompletionComplete()
  │  [修复FP-3/4] 使用 AgentRuntimeBridge.createWithFallback() 创建 Agent
  │  设置 memory = TieredMemory(ShortMemory + DatabaseMemory)
  │  设置 eventHandlerManager = EventHandlerManager.global
  │
  ▼
AbsAgent.chat()
  │  AgentStartEvent → EventHandlerManager.global → [修复FP-1] BillingEventHandler
  │                                    → [修复FP-2] WebSocketEventBridge
  │                                    → [新增] AgentPersistenceEventHandler
  │
  ▼
ReactExecutor.run() → AgentTask.chatLLM() → AgentOp.chatLLM()
  │  ChatModelStartEvent → [已注册] QuotaCheckHandler (配额检查)
  │  → ChatModel.create() (实际 LLM 调用)
  │  ChatModelEndEvent → [修复FP-1] BillingEventHandler.onChatModelEnd()
  │                         → usageService.create(log) → llm_usage_logs 表 ✅
  │                     → [新增] AgentPersistenceEventHandler.onChatModelEnd()
  │                         → messagesService.create() → agent_messages 表 ✅
  │
  ▼
AbsAgent.chat() memory.update()
  │  [修复FP-3] TieredMemory.update()
  │    → ShortMemory.update() (内存缓存)
  │    → DatabaseMemory.update() → agent_memories 表 ✅
  │
  ▼
AgentEndEvent → [修复FP-1] BillingEventHandler.onAgentEnd()
  │            → [新增] AgentPersistenceEventHandler.onAgentEnd()
  │                → tasksService.update(status=completed) → agent_tasks 表 ✅
  │                → CheckpointManager.saveCheckpoint() → agent_contexts 表 ✅
  │
  ▼
WebMCPProtocol.handleCompletionComplete()
  │  [修复FP-6] AgentRuntimeBridge.syncToDatabase() → agents 表 ✅
  │  [新增] 写入用户消息到 agent_messages 表 ✅
  │
  ▼
返回 MCP JSON-RPC 响应
```

### 11.3 AgentPersistenceEventHandler 设计

新增事件处理器，负责 Agent 消息和任务的自动持久化：

```
class AgentPersistenceEventHandler:
  registerGlobalHandlers():
    EventHandlerManager.global.addAgentStartHandler(onAgentStart)
    EventHandlerManager.global.addChatModelEndHandler(onChatModelEnd)
    EventHandlerManager.global.addAgentEndHandler(onAgentEnd)
  
  onAgentStart(event):
    spawn {
      // 创建 agent_tasks 记录
      task = AgentTasksPO()
      task.agentId = event.agent.name
      task.status = "running"
      task.startTime = now()
      tasksService.create(task)
    }
  
  onChatModelEnd(event):
    spawn {
      // 写入助手响应到 agent_messages
      msg = AgentMessagesPO()
      msg.agentId = event.agent.name
      msg.role = "assistant"
      msg.content = event.chatResponse.message.content
      messagesService.create(msg)
    }
  
  onAgentEnd(event):
    spawn {
      // 更新 agent_tasks 状态
      tasksService.update(taskId, status="completed", endTime=now())
      
      // 写入最终响应到 agent_messages
      msg = AgentMessagesPO()
      msg.agentId = event.agent.name
      msg.role = "assistant"
      msg.content = event.agentResponse.content
      messagesService.create(msg)
      
      // 保存检查点到 agent_contexts
      CheckpointManager.saveCheckpoint(agentId, messages)
    }
```

### 11.4 main.cj 启动注册设计

在 `Application.init()` 的 `setupRoutes()` 之后添加：

```cangjie
// 注册全局事件处理器
try {
    let billingHandler = BillingEventHandler()
    billingHandler.registerGlobalHandlers()
    LogUtils.info("BillingEventHandler registered to EventHandlerManager.global")
} catch (ex: Exception) {
    LogUtils.error("Failed to register BillingEventHandler: ${ex.message}")
}

try {
    let quotaHandler = QuotaCheckHandler()
    quotaHandler.registerGlobalHandlers()
    LogUtils.info("QuotaCheckHandler registered to EventHandlerManager.global")
} catch (ex: Exception) {
    LogUtils.error("Failed to register QuotaCheckHandler: ${ex.message}")
}

try {
    WebSocketEventBridge.instance.registerGlobalHandlers()
    LogUtils.info("WebSocketEventBridge registered to EventHandlerManager.global")
} catch (ex: Exception) {
    LogUtils.error("Failed to register WebSocketEventBridge: ${ex.message}")
}

try {
    let persistenceHandler = AgentPersistenceEventHandler()
    persistenceHandler.registerGlobalHandlers()
    LogUtils.info("AgentPersistenceEventHandler registered to EventHandlerManager.global")
} catch (ex: Exception) {
    LogUtils.error("Failed to register AgentPersistenceEventHandler: ${ex.message}")
}

// 预加载数据库中的 Agent 到运行时
try {
    let agents = AgentRuntimeBridge.instance.loadAllFromDatabase()
    LogUtils.info("Loaded ${agents.size} agents from database into runtime")
} catch (ex: Exception) {
    LogUtils.error("Failed to load agents from database: ${ex.message}")
}
```

### 11.5 WebMCPProtocol 集成设计

修改 `WebMCPProtocol.init()` 中 Agent 创建方式：

```cangjie
// 修改前：
this._agent = Some(SkillAwareAgent(
    skillManager: skillManager.getOrThrow(),
    model: chatModel.getOrThrow(),
    executor: executor,
    name: "WebMCP Skill Assistant",
    description: "..."
))

// 修改后：
let agentId = "webmcp-skill-assistant"
let memory = TieredMemory(
    shortMemory: ShortMemory(),
    databaseMemory: DatabaseMemory(agentId: agentId, scope: "episodic")
)
this._agent = Some(SkillAwareAgent(
    skillManager: skillManager.getOrThrow(),
    model: chatModel.getOrThrow(),
    executor: executor,
    name: "WebMCP Skill Assistant",
    description: "...",
    memory: memory,
    eventHandlerManager: EventHandlerManager.global
))
```

修改 `handleCompletionComplete()` 中 Agent 执行后逻辑：

```cangjie
// 修改前：
let agentResponse = agent.chat(agentRequest)
responseContent = agentResponse.content

// 修改后：
// 写入用户消息到 agent_messages
spawn {
    try {
        let msg = AgentMessagesPO()
        msg.agentId = agent.name
        msg.role = "user"
        msg.content = userMessage
        messagesService.create(msg)
    } catch (_: Exception) {}
}

let agentResponse = agent.chat(agentRequest)
responseContent = agentResponse.content

// 同步 Agent 状态到数据库
spawn {
    try {
        AgentRuntimeBridge.instance.syncToDatabase(agent.name, agent)
    } catch (_: Exception) {}
}
```

### 11.6 降级路径修复设计

修改 `handleCompletionComplete()` 降级路径（当 `_agent` 为 None 时）：

```cangjie
// 修改前：
let request = ChatRequest([Message(MessageRole.User, userMessage)], ...)
let chatResponse = cm.create(request)
responseContent = chatResponse.message.content

// 修改后：
let request = ChatRequest([Message(MessageRole.User, userMessage)], ...)
// 手动触发事件（因绕过 AgentOp.chatLLM()）
let startEvent = ChatModelStartEvent(agent, request)
EventHandlerManager.global.handleChatModelStart(startEvent)
let chatResponse = cm.create(request)
let endEvent = ChatModelEndEvent(agent, request, chatResponse)
EventHandlerManager.global.handleChatModelEnd(endEvent)
responseContent = chatResponse.message.content
```

### 11.7 AIController 集成设计

修改 `AIController.chat()` 改为通过 Agent 调用：

```cangjie
// 修改前：
let chatReq = ChatRequest(messages)
let response = _chatModel.create(chatReq)

// 修改后（优先使用 Agent 路径）：
if (let Some(agent) <- _defaultAgent) {
    let agentRequest = AgentRequest(lastUserMessage, messages: messages)
    let agentResponse = agent.chat(agentRequest)
    // 从 agentResponse 构建 ChatResponse
} else {
    // 降级：直接调用 ChatModel，但手动触发事件
    let chatReq = ChatRequest(messages)
    let response = _chatModel.create(chatReq)
    // 手动触发 ChatModelEndEvent
}
```