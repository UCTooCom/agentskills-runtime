# AgentTeams 分层协作架构需求规格

## 项目背景

GOAI 2026「新智基座」赛道要求参赛作品实现 Manager–TeamLeader–Worker 分层协作架构（AgentTeams），这是赛事的必选协同设计基点。当前 agentskills-runtime 的 Agent 协作模式（LinearGroup、LeaderGroup、FreeGroup、AutoDiscussGroup）均为扁平结构，无法满足赛事对分层协作、任务编排和混合框架调度的要求。

## 核心问题

1. **缺少分层协作架构**: 当前 LeaderGroup 仅有 Leader-Follower 两层，缺少赛事要求的 Manager-TeamLeader-Worker 三层架构
2. **缺少可配置的角色定义**: Agent 角色和层级关系硬编码在代码中，无法通过配置动态定义
3. **缺少动态组队能力**: 无法在运行时根据任务需要动态创建/销毁 Team 和 Worker
4. **缺少层级消息传递**: Manager↔TeamLeader↔Worker 间的结构化消息传递机制缺失
5. **缺少团队生命周期管理**: Team 的创建、运行、暂停、销毁缺乏统一管理

## 功能需求

### REQ-AT-001: Manager Agent 角色

- Manager Agent 负责任务接收、全局规划和结果汇总
- 支持将用户任务分解为子任务并分配给 TeamLeader
- 支持监控所有 TeamLeader 的执行进度
- 支持聚合所有 TeamLeader 的执行结果
- Manager 通过 agent_teams.yaml 配置定义

### REQ-AT-002: TeamLeader Agent 角色

- TeamLeader Agent 负责子团队管理和任务分配
- 支持管理一组 Worker Agent
- 支持将子任务进一步分解并分配给 Worker
- 支持监控 Worker 执行进度
- 支持聚合 Worker 执行结果并上报给 Manager
- TeamLeader 通过 agent_teams.yaml 配置定义

### REQ-AT-003: Worker Agent 角色

- Worker Agent 负责具体子任务执行
- 支持执行技能或工具调用
- 支持返回执行结果和执行证据
- Worker 通过 agent_teams.yaml 配置定义

### REQ-AT-004: agent_teams.yaml 配置驱动

- 通过 YAML 配置文件定义 Agent 角色和层级关系
- 配置项包括：团队名称、角色类型、技能绑定、模型选择、权限声明
- 引擎根据配置动态创建 Agent 实例
- 支持多套团队配置，按场景选择
- 配置示例：
  ```yaml
  team:
    name: "dev-team"
    description: "AI驱动开发团队"
    manager:
      agent_type: "product-manager"
      skills: ["requirement-analysis", "task-decomposition"]
      model: "deepseek"
    leaders:
      - agent_type: "developer"
        skills: ["code-generation", "code-review"]
        workers:
          - agent_type: "coder-worker"
            skills: ["crudgen", "crudweb", "cangjie-coder"]
          - agent_type: "qa-worker"
            skills: ["test-generation", "code-verification"]
  ```

### REQ-AT-005: 分层通信机制

- Manager→TeamLeader: 任务分配消息、进度查询消息
- TeamLeader→Manager: 结果上报消息、状态更新消息
- TeamLeader→Worker: 子任务分配消息、执行指令消息
- Worker→TeamLeader: 结果返回消息、证据提交消息
- 消息格式标准化：包含 sender、receiver、type、payload、timestamp

### REQ-AT-006: 动态组队

- 运行时根据任务需要动态创建 Team 和 Worker
- 支持从 agent_teams.yaml 加载预定义团队配置
- 支持通过 API 动态创建团队
- 支持运行时动态调整 Team 组成（添加/移除 Worker）
- 支持团队实例的生命周期管理（创建→运行→暂停→销毁）

### REQ-AT-007: AgentTeams DSL 扩展

- 扩展现有 AgentGroup DSL，新增 `@agentTeams` 宏
- 支持在 AGENTS.md 中声明团队配置
- 支持通过 DSL 运算符创建分层团队

### REQ-AT-008: 团队持久化

- 团队配置持久化到 agent_teams 数据库表
- 团队实例状态持久化（运行中/暂停/已完成）
- 支持团队实例的查询和恢复

## 非功能需求

- 团队创建延迟 ≤ 500ms
- 支持最多 3 层层级（Manager→TeamLeader→Worker）
- 单个 Manager 最多管理 5 个 TeamLeader
- 单个 TeamLeader 最多管理 10 个 Worker
- 分层消息传递延迟 ≤ 100ms

## 验收标准

- [ ] 可通过 agent_teams.yaml 配置创建 Manager-TeamLeader-Worker 三层 Agent 组
- [ ] Manager 正确分解任务并分配给 TeamLeader
- [ ] TeamLeader 正确管理 Worker 并聚合结果
- [ ] Worker 执行任务并返回结果和执行证据
- [ ] 三层 Agent 间消息正确传递
- [ ] 支持运行时动态调整 Team 组成
- [ ] 团队配置和状态正确持久化到数据库
- [ ] @agentTeams 宏正确解析和执行

## 数据模型

### agent_teams 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| name | varchar(100) | 团队名称 |
| description | text | 团队描述 |
| config | jsonb | 团队配置（YAML解析后的JSON） |
| status | varchar(20) | 状态：draft/running/paused/completed/failed |
| manager_agent_id | bigint | Manager Agent ID |
| created_at | timestamp | 创建时间 |
| updated_at | timestamp | 更新时间 |
| creator | bigint | 创建者 |

### agent_team_members 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| team_id | bigint | 所属团队 |
| agent_id | bigint | Agent ID |
| role | varchar(20) | 角色：manager/leader/worker |
| parent_agent_id | bigint | 上级 Agent ID |
| skills | varchar[] | 绑定的技能列表 |
| config | jsonb | Agent 配置 |
| created_at | timestamp | 创建时间 |

## 依赖

- 复用现有 AgentGroup 框架（LeaderGroup、AgentGroup DSL）
- 复用现有 Agent 基础设施（AbsAgent、BaseAgent、SkillAwareAgent）
- 复用现有 Interaction 事件系统
- 复用现有 SubAgentTool

## 对标赛事维度

- **多Agent协同与自主闭环能力(25%)**: AgentTeams 是赛事必选基点
- **场景价值与行业可复制性(25%)**: 分层架构可迁移到多种行业场景