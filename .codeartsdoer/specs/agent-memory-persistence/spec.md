# Agent 记忆持久化与跨会话共享需求规格

## 项目背景

当前 agentskills-runtime 的 Memory 接口仅定义了 `update` 和 `search` 两个方法，AgentMemory 枚举定义了 USER/PROJECT/LOCAL 三种作用域，但缺乏实际的持久化实现和跨会话共享机制。AI 驱动开发框架需要 Agent 在长时间、多会话的任务中保持和积累记忆，实现"越用越聪明"。

## 核心问题

1. **记忆无持久化实现**: Memory 接口仅有定义，无数据库或文件存储实现
2. **无跨会话记忆**: Agent 重启后丢失所有记忆，无法从历史经验中学习
3. **无记忆分层**: 缺乏短期记忆（对话内）和长期记忆（跨对话）的区分
4. **无记忆检索**: 缺乏基于语义的记忆检索（仅关键词匹配不够）
5. **无记忆共享**: 不同 Agent 之间无法共享记忆（如主 Agent 的经验传递给子 Agent）
6. **无记忆衰减**: 长期记忆无衰减机制，可能积累过多低价值信息

## 功能需求

### REQ-MEM-001: 记忆持久化存储

- 实现 Memory 接口，支持将记忆存储到数据库（agent_memories 表）
- 每条记忆包含：内容、来源 Agent、作用域、标签、时间戳、访问计数
- 支持记忆的 CRUD 操作
- 支持批量写入和读取

### REQ-MEM-002: 记忆分层

- **短期记忆**（Working Memory）: 当前对话内的临时信息，对话结束可丢弃
- **情景记忆**（Episodic Memory）: 历史对话中的事件和经验，跨会话保留
- **语义记忆**（Semantic Memory）: 提取的通用知识和规则，长期保留
- **程序记忆**（Procedural Memory）: 学到的操作模式和最佳实践
- 各层记忆有不同的保留策略和检索优先级

### REQ-MEM-003: 语义记忆检索

- 基于向量嵌入的语义检索（利用已有的 RAG/Embedding 能力）
- 记忆写入时自动生成嵌入向量
- 检索时支持相似度阈值过滤
- 支持混合检索：语义相似度 + 关键词匹配 + 时间衰减
- 检索结果按相关性排序

### REQ-MEM-004: 跨会话记忆

- Agent 启动时自动加载其历史记忆（按作用域）
- 新对话中 Agent 可引用历史经验："上次处理类似任务时..."
- 支持记忆的版本化（同一知识的不同时间版本）
- 支持记忆的来源追踪（哪次对话、哪个 Agent 产生的）

### REQ-MEM-005: Agent 间记忆共享

- 支持记忆的共享作用域：
  - `private`: 仅创建 Agent 可访问
  - `shared`: 同 parent_id 的 Agent 可访问
  - `global`: 所有 Agent 可访问
- 主 Agent 可将关键经验标记为 shared，子 Agent 自动继承
- 子 Agent 的新发现可上报给主 Agent 记忆

### REQ-MEM-006: 记忆衰减与压缩

- 基于时间的衰减：越早的记忆权重越低（可配置衰减函数）
- 基于访问的强化：频繁访问的记忆权重提升
- 定期压缩：将相似记忆合并，低价值记忆归档或删除
- 记忆容量限制：每个 Agent 的长期记忆上限（可配置）
- 压缩策略：保留高权重记忆，合并相似记忆，删除过期记忆

### REQ-MEM-007: 记忆与同步集成

- 记忆变更通过 SyncManager 同步到文件系统
- 支持将记忆导出为 Markdown 文件（便于人工审查）
- 支持从 Markdown 文件导入记忆（便于初始化和迁移）

## 非功能需求

- 记忆写入延迟 ≤ 50ms
- 语义检索延迟 ≤ 200ms（1000 条记忆内）
- 单个 Agent 最多 10000 条活跃记忆
- 记忆压缩不影响在线服务

## 数据模型

### agent_memories 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| agent_id | bigint | 所属 Agent |
| scope | varchar(20) | 作用域：working/episodic/semantic/procedural |
| sharing | varchar(20) | 共享范围：private/shared/global |
| content | text | 记忆内容 |
| embedding | vector(1536) | 语义嵌入向量 |
| tags | varchar[] | 标签 |
| weight | float | 权重（0.0-1.0） |
| access_count | integer | 访问计数 |
| source_session | varchar(100) | 来源会话 |
| source_agent | bigint | 来源 Agent |
| expires_at | timestamp | 过期时间（可选） |
| creator | bigint | 创建者 |
| created_at | timestamp | 创建时间 |
| updated_at | timestamp | 更新时间 |
| last_accessed_at | timestamp | 最后访问时间 |

## 验收标准

1. Memory 接口正确持久化到数据库
2. 四层记忆正确区分和使用
3. 语义检索返回相关性最高的记忆
4. Agent 重启后可加载历史记忆继续工作
5. Agent 间记忆共享按作用域正确隔离
6. 记忆衰减和压缩按策略正确执行
7. 记忆变更通过同步系统正确同步到文件