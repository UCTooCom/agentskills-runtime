# GOAI2026 设计文档全面复核报告

**复核日期**: 2026-07-24  
**复核范围**: 9个P0工程 + 2个P1工程的design.md  
**复核依据**: uctooDB.sql数据库结构 + 现有源代码基础设施 + uctoo-v4数据库设计规范  
**复核重点**: 数据库规范合规性 + 基础设施复用  

---

## 复核总结

| 严重程度 | 数量 | 说明 |
|---------|------|------|
| 🔴 严重 | 12 | 数据库规范严重违规，影响与现有系统兼容性 |
| 🟡 中等 | 8 | 基础设施可复用但未复用，增加开发量和维护成本 |
| 🟢 轻微 | 5 | 设计冗余或可优化项 |

---

## 1. 数据库规范问题清单（按严重程度排序）

### 🔴 严重问题

#### DB-S01: 所有新建表主键使用BIGSERIAL而非UUID

**涉及文档**: agent-teams, agent-orchestration, execution-audit, skill-composition-engine, agent-memory-persistence（共5个）

**问题描述**: 所有design.md中的DDL使用 `id BIGSERIAL PRIMARY KEY`，但uctooDB.sql中的标准规范是 `id uuid NOT NULL DEFAULT gen_random_uuid()`。

**现有规范示例**（uctooDB.sql中的agents表）:
```sql
"id" uuid NOT NULL DEFAULT gen_random_uuid()
```

**设计文档中的错误示例**（agent-teams/design.md）:
```sql
id BIGSERIAL PRIMARY KEY
```

**影响**: 
- 与现有agents、agent_tasks、agent_contexts、agent_messages等表的UUID主键不兼容
- agent_id、team_id等外键字段使用BIGINT无法关联UUID主键
- 导致JOIN查询和关联关系断裂

**修改建议**: 所有 `id BIGSERIAL PRIMARY KEY` 改为 `id uuid NOT NULL DEFAULT gen_random_uuid()`

---

#### DB-S02: 所有时间字段使用TIMESTAMP而非timestamptz(6)

**涉及文档**: agent-teams, agent-orchestration, execution-audit, skill-composition-engine, agent-memory-persistence（共5个）

**问题描述**: 所有DDL使用 `TIMESTAMP DEFAULT CURRENT_TIMESTAMP`，但uctooDB.sql中的标准规范是 `timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP`。

**现有规范示例**:
```sql
"created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
"updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
"deleted_at" timestamptz(6)
```

**设计文档中的错误示例**:
```sql
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
deleted_at TIMESTAMP
```

**影响**:
- 缺少时区信息，国际化场景下时间显示不一致
- 精度不足（TIMESTAMP默认微秒精度，timestamptz(6)明确6位小数）
- created_at/updated_at缺少NOT NULL约束

**修改建议**: 
- `created_at TIMESTAMP` → `created_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at TIMESTAMP` → `updated_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `deleted_at TIMESTAMP` → `deleted_at timestamptz(6)`（可空，无DEFAULT）

---

#### DB-S03: creator字段使用BIGINT而非UUID

**涉及文档**: agent-teams, agent-orchestration, execution-audit, skill-composition-engine, agent-memory-persistence（共5个）

**问题描述**: 所有DDL使用 `creator BIGINT`，但uctooDB.sql中的标准规范是 `creator uuid`。

**现有规范示例**:
```sql
"creator" uuid
```

**设计文档中的错误示例**:
```sql
creator BIGINT
```

**影响**: 与现有用户体系（uctoo_user.id为UUID）不兼容，无法关联创建人

**修改建议**: `creator BIGINT` → `creator uuid`

---

#### DB-S04: agent_id等外键字段使用BIGINT而非UUID

**涉及文档**: agent-teams, agent-orchestration, execution-audit, agent-memory-persistence（共4个）

**问题描述**: 所有关联agents表的字段使用BIGINT，但agents.id是UUID类型。

**具体问题清单**:
| 文档 | 字段 | 当前类型 | 应改为 |
|------|------|---------|--------|
| agent-teams | agent_team_members.agent_id | BIGINT | uuid |
| agent-teams | agent_team_members.parent_agent_id | BIGINT | uuid |
| agent-teams | agent_teams.manager_agent_id | BIGINT | uuid |
| execution-audit | execution_evidences.agent_id | BIGINT | uuid |
| execution-audit | verification_evidences.agent_id | BIGINT | uuid |
| agent-memory-persistence | agent_memories.agent_id | BIGINT | uuid |
| agent-memory-persistence | agent_memories.source_agent | BIGINT | uuid |

**影响**: 无法与agents表正确关联，JOIN查询类型不匹配

**修改建议**: 所有关联agents表的字段改为uuid类型

---

#### DB-S05: agent_memories表与uctooDB.sql中已有表冲突

**涉及文档**: agent-memory-persistence

**问题描述**: design.md中定义了新的agent_memories表DDL，但uctooDB.sql中已存在agent_memories表，且结构不同。

**现有表结构**（uctooDB.sql）:
```sql
CREATE TABLE "public"."agent_memories" (
  "id" varchar(36) NOT NULL DEFAULT gen_random_uuid(),
  "agent_id" varchar(36) NOT NULL,
  "content" text NOT NULL,
  "embedding_vector" text,
  "scope" varchar(20) NOT NULL DEFAULT 'episodic',
  "weight" float8 NOT NULL DEFAULT 1.0,
  "tags" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "metadata" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "task_id" varchar(36),
  "session_id" varchar(100),
  "creator" varchar(36),
  "created_at" timestamptz(6) NOT NULL DEFAULT now(),
  "updated_at" timestamptz(6) NOT NULL DEFAULT now(),
  "deleted_at" timestamptz(6)
);
```

**设计文档中的表**（agent-memory-persistence/design.md）:
```sql
CREATE TABLE agent_memories (
    id BIGSERIAL PRIMARY KEY,
    agent_id BIGINT NOT NULL,
    scope VARCHAR(20) NOT NULL,
    sharing VARCHAR(20) DEFAULT 'private',
    content TEXT NOT NULL,
    embedding VECTOR(1536),
    tags TEXT[],
    weight FLOAT DEFAULT 0.5,
    access_count INTEGER DEFAULT 0,
    source_session VARCHAR(100),
    source_agent BIGINT,
    expires_at TIMESTAMP,
    ...
);
```

**冲突点**:
1. id类型不同：varchar(36) vs BIGSERIAL
2. agent_id类型不同：varchar(36) vs BIGINT
3. creator类型不同：varchar(36) vs BIGINT
4. 已有字段缺失：task_id、metadata
5. 新增字段需ALTER TABLE而非CREATE TABLE

**修改建议**: 不新建表，改为ALTER TABLE增量扩展已有agent_memories表，添加sharing、access_count、source_session、source_agent、expires_at字段

---

#### DB-S06: agent_teams表与已有agent_groups表功能重叠

**涉及文档**: agent-teams

**问题描述**: 新建的agent_teams表与uctooDB.sql中已有的agent_groups表功能高度重叠。

**已有agent_groups表结构**:
```sql
CREATE TABLE "public"."agent_groups" (
  "id" varchar(36) NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar(200) NOT NULL,
  "group_type" varchar(20) NOT NULL DEFAULT 'leader',
  "leader_id" varchar(36),
  "member_ids" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "config" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "status" varchar(20) NOT NULL DEFAULT 'idle',
  "max_round" int8 NOT NULL DEFAULT 10,
  "description" text,
  "creator" varchar(36),
  ...
);
```

**重叠分析**:
| agent_teams字段 | agent_groups字段 | 说明 |
|----------------|-----------------|------|
| name | name | 完全相同 |
| config | config | 完全相同 |
| status | status | 完全相同 |
| manager_agent_id | leader_id | 语义相同 |
| description | description | 完全相同 |

**修改建议**: 不新建agent_teams表，改为扩展agent_groups表：
1. 新增group_type值：'manager'（Manager-TeamLeader-Worker模式）
2. 新增config中的team层级结构定义（通过JSONB配置，无需新表）
3. agent_team_members表改为agent_group_members（或直接使用agent_groups.member_ids的JSONB扩展）

---

#### DB-S07: agent_approvals表已存在，审批回滚工程应复用

**涉及文档**: 间接影响P1-4 approval-rollback工程

**问题描述**: uctooDB.sql中已存在agent_approvals表（人机审批记录表），具备完整的审批流程字段（approval_type、status、user_response、timeout_ms），但P1-4审批与回滚工程可能重复设计。

**已有表结构**:
```sql
CREATE TABLE "public"."agent_approvals" (
  "id" varchar(36) NOT NULL DEFAULT gen_random_uuid(),
  "agent_id" varchar(36) NOT NULL,
  "task_id" varchar(36) NOT NULL,
  "approval_type" varchar(20) NOT NULL DEFAULT 'confirm',
  "content" text NOT NULL,
  "status" varchar(20) NOT NULL DEFAULT 'pending',
  "user_response" text,
  "timeout_ms" int8 NOT NULL DEFAULT 300000,
  "creator" varchar(36),
  ...
);
```

**修改建议**: P1-4审批与回滚工程应直接复用agent_approvals表，扩展而非新建

---

#### DB-S08: orchestration_plans/steps表id和team_id类型不合规

**涉及文档**: agent-orchestration

**问题描述**: 
1. `id BIGSERIAL` 应为 `id uuid`
2. `team_id BIGINT` 应为 `team_id uuid`（关联agent_groups.id）
3. `plan_id BIGINT` 应为 `plan_id uuid`
4. `creator BIGINT` 应为 `creator uuid`

---

#### DB-S09: execution_evidences/verification_evidences表类型不合规

**涉及文档**: execution-audit

**问题描述**: 同DB-S01/S02/S03/S04，所有id、agent_id、creator、时间字段类型均不合规

---

#### DB-S10: skill_compositions/composition_executions表类型不合规

**涉及文档**: skill-composition-engine

**问题描述**: 同DB-S01/S02/S03，所有id、composition_id、creator、时间字段类型均不合规

---

#### DB-S11: agent_team_members表外键类型不合规

**涉及文档**: agent-teams

**问题描述**: 
1. `team_id BIGINT NOT NULL REFERENCES agent_teams(id)` — 如果agent_teams.id改为UUID，此处也应为uuid
2. `agent_id BIGINT NOT NULL` — 应为uuid关联agents.id
3. `parent_agent_id BIGINT` — 应为uuid关联agents.id
4. `skills TEXT[]` — 应为jsonb，与agent_groups.member_ids保持一致

---

#### DB-S12: 部分已有表id使用varchar(36)而非uuid

**涉及文档**: 间接影响agent-teams、agent-orchestration等

**问题描述**: uctooDB.sql中部分表（agent_approvals、agent_executors、agent_groups、agent_memories）的id使用varchar(36)而非uuid类型。这是历史遗留问题，但新建表应统一使用uuid类型。

**修改建议**: 新建表统一使用uuid类型；与已有varchar(36)表的关联字段也使用uuid类型（PostgreSQL的uuid和varchar(36)可隐式转换，但uuid更规范）

---

### 🟡 中等问题

#### DB-M01: 缺少COMMENT ON COLUMN和COMMENT ON TABLE

**涉及文档**: 所有包含DDL的design.md

**问题描述**: uctooDB.sql中每个表和字段都有COMMENT，但design.md中的DDL缺少COMMENT。

**修改建议**: 所有DDL补充COMMENT ON COLUMN和COMMENT ON TABLE

---

#### DB-M02: 缺少必要的索引

**涉及文档**: agent-teams, execution-audit

**问题描述**: 
- agent_teams表缺少status、manager_agent_id索引
- execution_evidences缺少step_id、hash索引
- verification_evidences缺少agent_id索引

---

#### DB-M03: agent_memories的embedding字段类型需确认

**涉及文档**: agent-memory-persistence

**问题描述**: design.md使用 `embedding VECTOR(1536)`，但uctooDB.sql中已有字段为 `embedding_vector text`（JSON序列化浮点数组）。需确认是否已安装pgvector扩展。

**修改建议**: 如果pgvector可用，使用VECTOR(1536)；否则保持text类型并JSON序列化

---

## 2. 基础设施复用建议清单

### 🟡 中等优先级

#### REUSE-01: AgentLoop观测评估飞轮应复用crontab调度机制

**涉及文档**: P1-3 agent-loop（未在本次复核的design.md中，但在gap-analysis.md中定义）

**问题描述**: AgentLoop需要周期性评估Agent执行效果，设计为独立的新模块。但系统已有完善的crontab调度机制（crontab表 + crontab_log表 + CrontabScheduler），具备：
- 定时任务注册和调度
- 执行日志记录
- 重试机制
- 并发控制
- 手动触发

**复用建议**: 
- AgentLoop的周期性评估任务注册为crontab任务
- 评估结果记录到crontab_log表
- 复用CrontabScheduler的调度能力
- 仅需新增评估逻辑（EvaluationEngine），调度基础设施完全复用

---

#### REUSE-02: 记忆持久化应复用已有agent_memories表和DatabaseMemory

**涉及文档**: agent-memory-persistence

**问题描述**: design.md设计了全新的agent_memories表，但：
1. uctooDB.sql中已有agent_memories表（含content、embedding_vector、scope、tags、metadata、task_id、session_id）
2. src/agent/memory/database/database_memory.cj 已有DatabaseMemory实现
3. src/agent/memory/tiered/ 已有分层记忆实现（tiered_memory.cj、layered_memory.cj）

**复用建议**:
- 不新建表，ALTER TABLE扩展已有agent_memories表
- 复用DatabaseMemory的读写接口
- 复用TieredMemory的分层策略
- 仅需新增：sharing字段、access_count字段、MemorySharingManager

---

#### REUSE-03: 执行证据链应复用operate_log表和ToolAuditLog

**涉及文档**: execution-audit

**问题描述**: design.md设计了全新的execution_evidences表，但：
1. uctooDB.sql中已有operate_log表（记录所有API和工具调用）
2. src/tool/tool_audit_log.cj 已有ToolAuditLog实现
3. src/tool/audit_provider.cj 已有审计提供者接口

**复用建议**:
- 方案A（推荐）：扩展operate_log表，新增agent_id(uuid)、session_id、step_id、step_type、input、output、duration_ms、side_effects、hash字段
- 方案B：新建execution_evidences表但确保与operate_log的关联关系
- verification_evidences可新建（无现有表可复用）
- 复用ToolAuditLog的审计记录接口

---

#### REUSE-04: 审批与回滚应复用已有HITL机制和agent_approvals表

**涉及文档**: P1-4 approval-rollback

**问题描述**: 系统已有完善的HITL（Human-in-the-Loop）机制：
1. EventHandlerManager三级事件处理（@handler/@interact/@asyncInteract）
2. agent_approvals表（审批记录持久化）
3. 敏感操作二次确认机制

**复用建议**:
- 审批流程直接复用agent_approvals表和HITL事件处理
- 回滚机制新增RollbackManager，但审批记录复用已有基础设施
- 不新建审批相关的表

---

#### REUSE-05: 错误恢复应复用已有RetryManager和CrontabScheduler重试机制

**涉及文档**: agent-error-recovery

**问题描述**: 系统已有：
1. RetryManager（src/app/中的同步系统重试）
2. crontab表中的max_retries、retry_count字段
3. crontab_log表中的retry_attempt字段

**复用建议**:
- ErrorClassifier和CircuitBreaker可新增（无现有实现）
- 智能重试应扩展现有RetryManager而非重写
- 降级执行和补偿事务可新增

---

#### REUSE-06: AgentTeams应复用agent_groups表而非新建

**涉及文档**: agent-teams

**问题描述**: 如DB-S06所述，agent_groups表已具备团队定义能力（name、group_type、leader_id、member_ids、config、status），只需扩展group_type值和config结构。

**复用建议**:
- 新增group_type='manager'表示Manager-TeamLeader-Worker模式
- 团队层级结构通过config JSONB字段定义（manager→leaders→workers）
- 成员角色通过member_ids的JSONB结构扩展（添加role字段）
- 仅需新增agent_group_members表（如需独立角色和层级关系）

---

#### REUSE-07: 协同技能集应通过SKILL.md技能实现而非硬编码

**涉及文档**: P1-7 collaboration-skills

**问题描述**: 协同技能集（Kanban、任务队列等）设计为硬编码模块，但项目原则明确"技能是一等公民"。

**复用建议**:
- Kanban功能通过sdd-task技能 + agent_tasks表实现
- 任务队列通过agent_tasks表的status和priority字段实现
- 协同流程通过COMPOSITION.yaml组合模板定义
- 不需要新建硬编码模块

---

#### REUSE-08: DAG编排引擎与技能组合引擎存在功能重叠

**涉及文档**: agent-orchestration, skill-composition-engine

**问题描述**: 
- DagScheduler：DAG解析、拓扑排序、并行调度、条件分支
- CompositionExecutor：串行/并行/条件分支执行、数据传递

两者核心调度逻辑高度重叠。

**复用建议**:
- CompositionExecutor作为底层执行引擎
- DagScheduler复用CompositionExecutor的并行/条件执行能力
- DagScheduler额外提供：持久化、状态机、动态重编排、资源仲裁
- 避免两套独立的调度引擎

---

## 3. 设计冗余清单

### 🟢 轻微问题

#### REDUNDANT-01: agent_team_members表可合并到agent_groups的member_ids

**涉及文档**: agent-teams

**问题描述**: agent_groups表已有member_ids(jsonb)字段存储成员列表。如果仅需要角色和层级信息，可以通过扩展member_ids的JSONB结构实现，无需独立表。

**修改建议**: 评估是否需要独立表。如果需要复杂查询（如按角色查询所有Worker），则保留独立表；否则通过JSONB扩展。

---

#### REDUNDANT-02: verification_evidences表可合并到execution_evidences

**涉及文档**: execution-audit

**问题描述**: verification_evidences的字段（agent_id、session_id、verification_type、command、status、exit_code、output_summary）大部分与execution_evidences重叠。

**修改建议**: 考虑将verification_evidences作为execution_evidences的step_type='verification'记录，减少表数量。

---

#### REDUNDANT-03: fullstack-codegen与code-gen-skills的COMPOSITION.yaml重叠

**涉及文档**: fullstack-codegen, code-gen-skills

**问题描述**: 两个工程都定义了代码生成的组合模板，fullstack-codegen的步骤是code-gen-skills的超集。

**修改建议**: fullstack-codegen直接引用code-gen-skills的code-gen-optimize组合模板，仅额外添加model-sync步骤。

---

#### REDUNDANT-04: P1-7 collaboration-skills与agent_tasks表功能重叠

**涉及文档**: P1-7 collaboration-skills

**问题描述**: agent_tasks表已具备任务队列能力（status、priority、parent_task_id、payload、result），Kanban视图可通过前端状态筛选实现。

**修改建议**: 不新建Kanban表，通过agent_tasks表的状态和优先级字段实现看板视图。

---

#### REDUNDANT-05: P2-3 memory-provider与agent-memory-persistence重叠

**涉及文档**: P2-3 memory-provider, P1-2 agent-memory-persistence

**问题描述**: memory-provider是agent-memory-persistence的插件化扩展，但两者可以合并为一个工程，通过Provider接口实现可插拔。

**修改建议**: 合并为一个工程，在agent-memory-persistence中设计MemoryProvider接口。

---

## 4. 具体修改建议

### 4.1 agent-teams/design.md 修改

| 修改项 | 当前 | 修改为 | 优先级 |
|--------|------|--------|--------|
| agent_teams表 | 新建表 | 扩展agent_groups表，新增group_type='manager' | 🔴 |
| id BIGSERIAL | BIGSERIAL | uuid NOT NULL DEFAULT gen_random_uuid() | 🔴 |
| manager_agent_id BIGINT | BIGINT | uuid | 🔴 |
| created_at TIMESTAMP | TIMESTAMP | timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP | 🔴 |
| updated_at TIMESTAMP | TIMESTAMP | timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP | 🔴 |
| deleted_at TIMESTAMP | TIMESTAMP | timestamptz(6) | 🔴 |
| creator BIGINT | BIGINT | uuid | 🔴 |
| agent_team_members.agent_id | BIGINT | uuid | 🔴 |
| agent_team_members.parent_agent_id | BIGINT | uuid | 🔴 |
| agent_team_members.team_id | BIGINT REFERENCES | uuid REFERENCES | 🔴 |
| agent_team_members.skills | TEXT[] | jsonb | 🟡 |
| 补充COMMENT | 无 | 所有字段和表添加COMMENT | 🟡 |
| 补充索引 | 部分缺失 | 补充status、manager_agent_id索引 | 🟡 |

### 4.2 agent-orchestration/design.md 修改

| 修改项 | 当前 | 修改为 | 优先级 |
|--------|------|--------|--------|
| id BIGSERIAL | BIGSERIAL | uuid NOT NULL DEFAULT gen_random_uuid() | 🔴 |
| team_id BIGINT | BIGINT | uuid | 🔴 |
| plan_id BIGINT | BIGINT | uuid | 🔴 |
| creator BIGINT | BIGINT | uuid | 🔴 |
| 所有时间字段 | TIMESTAMP | timestamptz(6) | 🔴 |
| depends_on TEXT[] | TEXT[] | jsonb | 🟡 |
| 补充COMMENT | 无 | 所有字段和表添加COMMENT | 🟡 |
| 与CompositionExecutor复用 | 独立调度 | 复用CompositionExecutor的并行/条件执行 | 🟡 |

### 4.3 execution-audit/design.md 修改

| 修改项 | 当前 | 修改为 | 优先级 |
|--------|------|--------|--------|
| id BIGSERIAL | BIGSERIAL | uuid NOT NULL DEFAULT gen_random_uuid() | 🔴 |
| agent_id BIGINT | BIGINT | uuid | 🔴 |
| creator BIGINT | BIGINT | uuid | 🔴 |
| 所有时间字段 | TIMESTAMP | timestamptz(6) | 🔴 |
| 与operate_log复用 | 新建独立表 | 评估扩展operate_log表的可行性 | 🟡 |
| verification_evidences | 独立表 | 考虑合并为step_type='verification' | 🟢 |
| 补充COMMENT | 无 | 所有字段和表添加COMMENT | 🟡 |

### 4.4 skill-composition-engine/design.md 修改

| 修改项 | 当前 | 修改为 | 优先级 |
|--------|------|--------|--------|
| id BIGSERIAL | BIGSERIAL | uuid NOT NULL DEFAULT gen_random_uuid() | 🔴 |
| composition_id BIGINT | BIGINT | uuid | 🔴 |
| creator BIGINT | BIGINT | uuid | 🔴 |
| 所有时间字段 | TIMESTAMP | timestamptz(6) | 🔴 |
| 补充COMMENT | 无 | 所有字段和表添加COMMENT | 🟡 |

### 4.5 agent-memory-persistence/design.md 修改

| 修改项 | 当前 | 修改为 | 优先级 |
|--------|------|--------|--------|
| agent_memories表 | CREATE TABLE | ALTER TABLE扩展已有表 | 🔴 |
| id BIGSERIAL | BIGSERIAL | 已有varchar(36)，保持不变 | 🔴 |
| agent_id BIGINT | BIGINT | 已有varchar(36)，保持不变 | 🔴 |
| 新增字段 | CREATE TABLE中 | ALTER TABLE ADD COLUMN | 🔴 |
| embedding VECTOR(1536) | VECTOR | 确认pgvector可用性，否则保持text | 🟡 |
| 与DatabaseMemory复用 | 未提及 | 复用src/agent/memory/database/ | 🟡 |
| 与TieredMemory复用 | 未提及 | 复用src/agent/memory/tiered/ | 🟡 |

### 4.6 agent-error-recovery/design.md 修改

| 修改项 | 当前 | 修改为 | 优先级 |
|--------|------|--------|--------|
| 与RetryManager复用 | 未提及 | 扩展现有RetryManager | 🟡 |
| 与CrontabScheduler复用 | 未提及 | 复用重试机制 | 🟡 |

---

## 5. 可以删除或合并的工程

| 工程 | 建议 | 理由 |
|------|------|------|
| P1-7 collaboration-skills | **合并到agent-teams** | Kanban/任务队列通过agent_tasks表和技能组合实现，无需独立工程 |
| P2-3 memory-provider | **合并到P1-2 agent-memory-persistence** | 两者是同一领域的不同层次，通过Provider接口统一 |
| P0-8 fullstack-codegen | **合并到P0-6 code-gen-skills** | fullstack-codegen是code-gen-skills的超集组合模板，无需独立工程 |

**合并后工程调整**:

| 原工程 | 合并到 | 新增内容 |
|--------|--------|---------|
| P1-7 collaboration-skills | P0-1 agent-teams | agent_tasks表的Kanban视图查询 + 协同COMPOSITION.yaml |
| P2-3 memory-provider | P1-2 agent-memory-persistence | MemoryProvider接口定义 + 默认实现 |
| P0-8 fullstack-codegen | P0-6 code-gen-skills | fullstack-codegen COMPOSITION.yaml + ModelSyncAdapter |

---

## 6. 合规DDL模板

以下是符合uctoo-v4规范的DDL模板，供所有design.md参考：

```sql
-- 标准新建表模板
CREATE TABLE "public"."table_name" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "status" varchar(20) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'draft'::character varying,
  "config" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "description" text COLLATE "pg_catalog"."default",
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6)
)
;

-- 标准ALTER TABLE扩展模板
ALTER TABLE "public"."existing_table" 
  ADD COLUMN "new_field" varchar(20) COLLATE "pg_catalog"."default" DEFAULT 'default_value'::character varying;
  
COMMENT ON COLUMN "public"."existing_table"."new_field" IS '新字段说明';
```

**关键规范要点**:
1. `id` 使用 `uuid NOT NULL DEFAULT gen_random_uuid()`
2. `created_at`/`updated_at` 使用 `timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP`
3. `deleted_at` 使用 `timestamptz(6)`（可空，无DEFAULT）
4. `creator` 使用 `uuid`
5. 所有外键关联UUID字段使用 `uuid` 类型
6. JSON数据使用 `jsonb` 而非 `json`
7. 数组数据优先使用 `jsonb` 而非 `TEXT[]`
8. 每个字段和表必须有 `COMMENT ON`