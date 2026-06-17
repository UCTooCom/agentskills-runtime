# Agent 系统数据库设计文档

## 文档信息
- **项目名称**: Agent 动态生成与多 Agent 协作系统
- **版本**: 1.0.0
- **创建日期**: 2026-05-29
- **作者**: SDD Agent
- **状态**: 草稿

---

## 1. 数据库设计概述

### 1.1 设计目标

根据需求规格文档，本数据库设计需满足以下目标：

1. **Agent 管理**: 支持 Agent 的创建、查询、更新、删除操作
2. **上下文管理**: 支持 Agent 对话上下文的持久化和恢复
3. **任务管理**: 支持 Agent 任务的分配、执行和追踪
4. **权限集成**: 与现有用户权限系统无缝集成
5. **协作支持**: 支持多 Agent 之间的协作和消息传递

### 1.2 设计原则

遵循 uctoo V4.0 数据库设计规范：
1. **命名规范**: 表名、列名均采用小写命名法，单词间以下划线连接
2. **通用字段**: 所有表均包含 `created_at`、`updated_at`、`deleted_at`、`creator` 四个列
3. **外键关联**: `creator` 列关联 `uctoo_user` 表的 `id` 列
4. **软删除**: 使用 `deleted_at` 字段实现软删除
5. **扩展性**: 预留扩展字段，支持未来功能扩展

---

## 2. 数据库表设计

### 2.1 表结构总览

| 表名 | 说明 | 状态 |
|------|------|------|
| agents | Agent 主表，存储 Agent 基本信息 | 新增 |
| agent_contexts | Agent 上下文表，存储对话历史 | 新增 |
| agent_tasks | Agent 任务表，存储任务信息 | 新增 |
| agent_messages | Agent 消息表，存储协作消息 | 新增 |

### 2.2 agents 表

#### 表定义

```sql
CREATE TABLE "public"."agents" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" varchar(100) NOT NULL,
  "type" varchar(50) NOT NULL,
  "description" text,
  "status" int4 DEFAULT 0,
  "config" json DEFAULT '{}',
  "system_prompt" text,
  "tools" json DEFAULT '[]',
  "model" varchar(50),
  "parent_id" uuid,
  "user_id" uuid,
  "color" varchar(20),
  "background" bool DEFAULT false,
  "memory_scope" varchar(20) DEFAULT 'user',
  "isolation_mode" varchar(20),
  "max_turns" int4 DEFAULT 200,
  "initial_prompt" text,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  CONSTRAINT "agents_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "agents_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."agents" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "agents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."uctoo_user" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_agents_status" ON "public"."agents" USING btree ("status");
CREATE INDEX IF NOT EXISTS "idx_agents_type" ON "public"."agents" USING btree ("type");
CREATE INDEX IF NOT EXISTS "idx_agents_parent_id" ON "public"."agents" USING btree ("parent_id");
CREATE INDEX IF NOT EXISTS "idx_agents_user_id" ON "public"."agents" USING btree ("user_id");
CREATE INDEX IF NOT EXISTS "idx_agents_deleted_at" ON "public"."agents" USING btree ("deleted_at");
```

#### 字段说明

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | uuid | Agent 唯一标识 |
| name | varchar(100) | Agent 名称 |
| type | varchar(50) | Agent 类型 (main/sub/analyzer/comparator/grader) |
| description | text | Agent 描述 |
| status | int4 | 状态：0-停用，1-运行，2-暂停 |
| config | json | 配置信息 |
| system_prompt | text | 系统提示词 |
| tools | json | 工具列表 |
| model | varchar(50) | 模型名称 |
| parent_id | uuid | 父 Agent ID |
| user_id | uuid | 关联用户 ID |
| color | varchar(20) | 显示颜色 |
| background | bool | 是否后台运行 |
| memory_scope | varchar(20) | 内存范围 (user/project/local) |
| isolation_mode | varchar(20) | 隔离模式 (worktree/remote) |
| max_turns | int4 | 最大对话轮数 |
| initial_prompt | text | 初始提示 |
| creator | uuid | 创建人，关联 uctoo_user.id |
| created_at | timestamptz | 创建时间 |
| updated_at | timestamptz | 更新时间 |
| deleted_at | timestamptz | 删除时间（软删除） |

### 2.3 agent_contexts 表

#### 表定义

```sql
CREATE TABLE "public"."agent_contexts" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "agent_id" uuid NOT NULL,
  "messages" json DEFAULT '[]',
  "metadata" json DEFAULT '{}',
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  CONSTRAINT "agent_contexts_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "agent_contexts_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "public"."agents" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_agent_contexts_agent_id" ON "public"."agent_contexts" USING btree ("agent_id");
```

#### 字段说明

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | uuid | 上下文唯一标识 |
| agent_id | uuid | 关联 Agent ID |
| messages | json | 消息历史 |
| metadata | json | 元数据 |
| creator | uuid | 创建人，关联 uctoo_user.id |
| created_at | timestamptz | 创建时间 |
| updated_at | timestamptz | 更新时间 |
| deleted_at | timestamptz | 删除时间（软删除） |

### 2.4 agent_tasks 表

#### 表定义

```sql
CREATE TABLE "public"."agent_tasks" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "agent_id" uuid NOT NULL,
  "parent_task_id" uuid,
  "status" int4 DEFAULT 0,
  "priority" int4 DEFAULT 3,
  "payload" json DEFAULT '{}',
  "result" json DEFAULT '{}',
  "error_message" text,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completed_at" timestamptz(6),
  "deleted_at" timestamptz(6),
  CONSTRAINT "agent_tasks_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "agent_tasks_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "public"."agents" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "agent_tasks_parent_task_id_fkey" FOREIGN KEY ("parent_task_id") REFERENCES "public"."agent_tasks" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_agent_tasks_agent_id" ON "public"."agent_tasks" USING btree ("agent_id");
CREATE INDEX IF NOT EXISTS "idx_agent_tasks_status" ON "public"."agent_tasks" USING btree ("status");
CREATE INDEX IF NOT EXISTS "idx_agent_tasks_parent_task_id" ON "public"."agent_tasks" USING btree ("parent_task_id");
CREATE INDEX IF NOT EXISTS "idx_agent_tasks_priority" ON "public"."agent_tasks" USING btree ("priority");
```

#### 字段说明

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | uuid | 任务唯一标识 |
| agent_id | uuid | 关联 Agent ID |
| parent_task_id | uuid | 父任务 ID |
| status | int4 | 状态：0-待处理，1-进行中，2-完成，3-失败 |
| priority | int4 | 优先级：1-5 |
| payload | json | 任务内容 |
| result | json | 任务结果 |
| error_message | text | 错误信息 |
| creator | uuid | 创建人，关联 uctoo_user.id |
| created_at | timestamptz | 创建时间 |
| updated_at | timestamptz | 更新时间 |
| completed_at | timestamptz | 完成时间 |
| deleted_at | timestamptz | 删除时间（软删除） |

### 2.5 agent_messages 表

#### 表定义

```sql
CREATE TABLE "public"."agent_messages" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "from_agent_id" uuid,
  "to_agent_id" uuid,
  "task_id" uuid,
  "type" varchar(50) NOT NULL,
  "content" json DEFAULT '{}',
  "status" int4 DEFAULT 0,
  "creator" uuid,
  "created_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" timestamptz(6),
  CONSTRAINT "agent_messages_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "agent_messages_from_agent_id_fkey" FOREIGN KEY ("from_agent_id") REFERENCES "public"."agents" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "agent_messages_to_agent_id_fkey" FOREIGN KEY ("to_agent_id") REFERENCES "public"."agents" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "agent_messages_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."agent_tasks" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_agent_messages_from_agent_id" ON "public"."agent_messages" USING btree ("from_agent_id");
CREATE INDEX IF NOT EXISTS "idx_agent_messages_to_agent_id" ON "public"."agent_messages" USING btree ("to_agent_id");
CREATE INDEX IF NOT EXISTS "idx_agent_messages_task_id" ON "public"."agent_messages" USING btree ("task_id");
CREATE INDEX IF NOT EXISTS "idx_agent_messages_status" ON "public"."agent_messages" USING btree ("status");
```

#### 字段说明

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | uuid | 消息唯一标识 |
| from_agent_id | uuid | 发送方 Agent ID |
| to_agent_id | uuid | 接收方 Agent ID |
| task_id | uuid | 关联任务 ID |
| type | varchar(50) | 消息类型 |
| content | json | 消息内容 |
| status | int4 | 状态：0-待处理，1-已处理，2-失败 |
| creator | uuid | 创建人，关联 uctoo_user.id |
| created_at | timestamptz | 创建时间 |
| updated_at | timestamptz | 更新时间 |
| deleted_at | timestamptz | 删除时间（软删除） |

---

## 3. 实体关系图 (ERD)

```
┌──────────────┐       ┌────────────────┐       ┌──────────────┐
│    agents    │       │ agent_contexts │       │ agent_tasks  │
├──────────────┤       ├────────────────┤       ├──────────────┤
│ id (PK)      │<──────│ id (PK)        │       │ id (PK)      │
│ name         │       │ agent_id (FK)  │       │ agent_id (FK)│
│ type         │       │ messages       │       │ parent_task_id│
│ status       │       │ metadata       │       │ status       │
│ config       │       │ creator        │       │ priority     │
│ system_prompt│       │ created_at     │       │ payload      │
│ tools        │       │ updated_at     │       │ result       │
│ model        │       │ deleted_at     │       │ completed_at │
│ parent_id(FK)│       └────────────────┘       │ deleted_at   │
│ user_id(FK)  │                               └──────────────┘
│ creator      │                                       │
│ created_at   │                                       │
│ updated_at   │                                       │
│ deleted_at   │                                       │
└──────────────┘                                       │
       │                                               │
       └──────────────┐                    ┌───────────┘
                      │                    │
                      ▼                    ▼
              ┌──────────────────────────────────┐
              │         agent_messages           │
              ├──────────────────────────────────┤
              │ id (PK)                         │
              │ from_agent_id (FK) ──────────────┘
              │ to_agent_id (FK) ────────────────┘
              │ task_id (FK) ────────────────────┘
              │ type                            │
              │ content                         │
              │ status                          │
              │ creator                         │
              │ created_at                      │
              │ updated_at                      │
              │ deleted_at                      │
              └──────────────────────────────────┘
```

---

## 4. 数据迁移

### 4.1 迁移步骤

| 阶段 | 操作 | 风险 | 回滚方案 |
|------|------|------|----------|
| Phase 1 | CREATE TABLE agents | 低 | DROP TABLE agents |
| Phase 2 | CREATE TABLE agent_contexts | 低 | DROP TABLE agent_contexts |
| Phase 3 | CREATE TABLE agent_tasks | 低 | DROP TABLE agent_tasks |
| Phase 4 | CREATE TABLE agent_messages | 低 | DROP TABLE agent_messages |
| Phase 5 | CREATE INDEX | 低 | DROP INDEX |

### 4.2 迁移脚本位置

迁移脚本应放置在：`sql/uctooDB.sql` 文件末尾

---

## 5. CRUD 代码生成

### 5.1 生成命令

使用 crudgen 工具生成 CRUD 模块代码：

```bash
# 生成 agents 表 CRUD 代码
cjpm run --skip-build --name magic.app.tools.crudgen -- --db uctoo --table agents

# 生成 agent_contexts 表 CRUD 代码
cjpm run --skip-build --name magic.app.tools.crudgen -- --db uctoo --table agent_contexts

# 生成 agent_tasks 表 CRUD 代码
cjpm run --skip-build --name magic.app.tools.crudgen -- --db uctoo --table agent_tasks

# 生成 agent_messages 表 CRUD 代码
cjpm run --skip-build --name magic.app.tools.crudgen -- --db uctoo --table agent_messages
```

### 5.2 生成的文件结构

```
src/app/
├── models/uctoo/agents/AgentsPO.cj
├── dao/uctoo/AgentsDAO.cj
├── services/uctoo/AgentsService.cj
├── controllers/uctoo/agents/AgentsController.cj
└── routes/uctoo/agents/AgentsRoute.cj
```

---

## 6. 权限集成

### 6.1 权限节点

使用 crudgen 生成权限节点：

| 权限标识 | 说明 |
|----------|------|
| database.uctoo.agents | Agent 管理 |
| database.uctoo.agent_contexts | Agent 上下文管理 |
| database.uctoo.agent_tasks | Agent 任务管理 |
| database.uctoo.agent_messages | Agent 消息管理 |

### 6.2 用户组设计

| 用户组名 | 说明 | 权限 |
|----------|------|------|
| agents | 主 Agent 用户组 | database.uctoo.agents:* |
| subagents | 子 Agent 用户组 | database.uctoo.agent_tasks:* |

---

## 7. 索引优化建议

### 7.1 查询场景分析

| 查询场景 | 涉及表 | 推荐索引 |
|----------|--------|----------|
| 按状态查询 Agent | agents | idx_agents_status |
| 按类型查询 Agent | agents | idx_agents_type |
| 查询子 Agent | agents | idx_agents_parent_id |
| 查询 Agent 上下文 | agent_contexts | idx_agent_contexts_agent_id |
| 查询 Agent 任务 | agent_tasks | idx_agent_tasks_agent_id, idx_agent_tasks_status |
| 查询 Agent 消息 | agent_messages | idx_agent_messages_from, idx_agent_messages_to |

---

## 8. 数据安全

### 8.1 敏感数据保护

- **配置信息**: config 字段可能包含敏感信息，需加密存储
- **系统提示词**: 可能包含敏感业务逻辑，需限制访问权限
- **用户关联**: user_id 关联用户表，需确保用户权限正确

### 8.2 访问控制

- 所有表的访问需经过权限检查
- 敏感字段需加密存储
- 日志记录需脱敏处理