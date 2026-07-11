# Agent 编排引擎需求规格

## 项目背景

当前 agentskills-runtime 已实现 Agent 的创建、生命周期管理和消息传递，但缺乏高级编排能力。多 Agent 协作需要编排引擎来管理复杂的执行计划、动态调度、资源分配和结果聚合，这是实现 AI 驱动开发框架进行长时间、多 Agent 协作任务的关键基础设施。

## 核心问题

1. **缺乏执行计划引擎**: 当前 Agent 执行是即时性的，无法定义和持久化多步骤、多 Agent 的执行计划
2. **缺乏动态调度**: 无法根据运行时状态动态调整 Agent 分配和执行顺序
3. **缺乏资源仲裁**: 多个 Agent 竞争同一资源时无仲裁机制
4. **缺乏结果聚合框架**: 各 Agent 结果的合并缺乏结构化支持
5. **缺乏执行回滚**: 编排失败时无法回滚已完成的步骤

## 功能需求

### REQ-ORCH-001: 执行计划定义与持久化

- 支持定义多步骤执行计划（DAG 形式），每个步骤关联技能或 Agent
- 执行计划持久化到数据库（orchestration_plan 表）
- 支持计划的版本管理和模板复用
- 支持从 AGENTS.md 的协作模式自动生成执行计划

### REQ-ORCH-002: DAG 调度引擎

- 基于有向无环图（DAG）调度步骤执行
- 自动识别可并行执行的步骤
- 支持条件分支（基于前序步骤结果决定后续路径）
- 支持循环结构（评估-改进循环）
- 拓扑排序确保依赖顺序正确

### REQ-ORCH-003: 动态重编排

- 运行时根据 Agent 执行结果动态调整后续计划
- 支持动态插入/删除步骤
- 支持替换失败的 Agent
- 支持根据资源可用性调整并行度

### REQ-ORCH-004: 资源仲裁

- Agent 竞争共享资源时的仲裁机制
- 支持资源锁（文件锁、数据库行锁）
- 支持资源配额（每个 Agent 的最大并发数、内存限制）
- 死锁检测与预防

### REQ-ORCH-005: 结果聚合框架

- 定义结构化的结果聚合规则（合并、投票、仲裁）
- 支持冲突检测和解决策略
- 支持结果验证（schema 校验、断言检查）
- 支持增量聚合（流式汇总，不等待所有 Agent 完成）

### REQ-ORCH-006: 执行回滚

- 记录每个步骤的副作用（文件修改、数据库变更）
- 编排失败时支持按逆序回滚已完成步骤
- 支持检查点（checkpoint），可从最近检查点恢复
- 回滚策略可配置（全部回滚 / 部分回滚 / 标记失败）

## 非功能需求

- 单个编排计划支持最多 100 个步骤
- 调度延迟 ≤ 50ms
- 支持最多 20 个 Agent 并行执行
- 执行计划状态变更实时通知（WebSocket）

## 数据模型

### orchestration_plans 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| name | varchar(100) | 计划名称 |
| status | varchar(20) | 状态：draft/running/paused/completed/failed/rolled_back |
| dag_definition | jsonb | DAG 定义（步骤、依赖、条件） |
| current_step | varchar(100) | 当前执行步骤 |
| checkpoint | jsonb | 最新检查点数据 |
| result | jsonb | 聚合结果 |
| creator | bigint | 创建者 |
| created_at | timestamp | 创建时间 |
| updated_at | timestamp | 更新时间 |

### orchestration_steps 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| plan_id | bigint | 所属计划 |
| step_name | varchar(100) | 步骤名称 |
| step_type | varchar(20) | 类型：skill/agent/sub_plan |
| target_ref | varchar(200) | 目标引用（技能名/Agent名） |
| input_mapping | jsonb | 输入映射（从前序步骤获取） |
| condition | varchar(500) | 执行条件表达式 |
| status | varchar(20) | 状态：pending/running/completed/failed/skipped |
| result | jsonb | 步骤结果 |
| side_effects | jsonb | 副作用记录（用于回滚） |
| started_at | timestamp | 开始时间 |
| completed_at | timestamp | 完成时间 |

## 验收标准

1. 可创建 DAG 形式的执行计划并持久化
2. DAG 调度引擎正确识别并行步骤并并行执行
3. 条件分支根据前序结果正确选择路径
4. 动态重编排可在运行时调整计划
5. 资源仲裁正确处理竞争和死锁
6. 结果聚合按规则正确合并多 Agent 结果
7. 执行回滚可正确撤销已完成步骤的副作用
8. 检查点恢复可从最近检查点继续执行