# 审批与回滚机制需求规格

## 项目背景

GOAI 2026赛事要求高风险操作有人工审批和编排失败时的执行回滚机制。当前HITL三级事件处理框架已有基础，但审批记录未持久化，执行回滚机制缺失。

## 核心问题

1. **缺少审批流程**: 高风险操作无人工审批流程
2. **缺少审批记录持久化**: 审批记录无数据库存储
3. **缺少执行回滚**: 编排失败时无法回滚已完成步骤
4. **缺少检查点恢复**: 无法从最近检查点恢复执行

## 功能需求

### REQ-AR-001: 审批流程
- 高风险操作暂停等待人工审批（确认/拒绝/修改）
- 审批触发条件可配置（操作类型、影响范围）
- 复用现有HITL @interact事件处理

### REQ-AR-002: 审批记录持久化
- 审批记录写入agent_approvals表
- 包含：操作描述、审批人、审批结果、审批时间、备注

### REQ-AR-003: 执行回滚
- 编排失败时按逆序回滚已完成步骤的副作用
- 复用execution-audit的副作用追踪
- 回滚策略可配置（全部回滚/部分回滚/标记失败）

### REQ-AR-004: 检查点恢复
- 支持从最近检查点恢复执行
- 检查点数据持久化到orchestration_plans的checkpoint字段
- 恢复时自动跳过已完成步骤

## 非功能需求
- 审批超时默认30秒，可配置
- 回滚操作本身需记录到副作用追踪
- 检查点写入不阻塞主流程（异步持久化）

## 验收标准

- [ ] 高风险操作正确触发审批流程
- [ ] 审批记录持久化且可查询
- [ ] 编排失败时正确回滚已完成步骤
- [ ] 可从最近检查点恢复执行
- [ ] 回滚操作本身被副作用追踪记录

## 数据模型

### agent_approvals 表（已存在，复用）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | varchar(36) | 审批记录ID |
| agent_id | varchar(36) | 关联Agent ID |
| task_id | varchar(36) | 关联任务ID |
| approval_type | varchar(50) | 审批类型 |
| content | text | 操作描述 |
| status | varchar(20) | 审批状态(pending/approved/rejected/timeout) |
| user_response | text | 用户响应 |
| timeout_ms | int8 | 超时时间(毫秒) |
| creator | varchar(36) | 创建人 |
| created_at | timestamptz(6) | 创建时间 |
| updated_at | timestamptz(6) | 更新时间 |
| deleted_at | timestamptz(6) | 删除时间 |

### orchestration_plans 表（已存在，复用checkpoint字段）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | varchar(36) | 编排计划ID |
| name | varchar(200) | 计划名称 |
| status | varchar(20) | 计划状态 |
| dag_definition | text | DAG定义 |
| current_step | varchar(100) | 当前步骤 |
| checkpoint | text | 检查点数据(JSONB) |
| result | text | 执行结果 |
| team_id | varchar(36) | 团队ID |
| creator | varchar(36) | 创建人 |
| created_at | timestamptz(6) | 创建时间 |
| updated_at | timestamptz(6) | 更新时间 |
| deleted_at | timestamptz(6) | 删除时间 |

## 依赖

- 依赖execution-audit工程的副作用追踪(SideEffectTracker)
- 复用现有HITL三级事件处理(EventHandlerManager, @interact)
- 复用现有agent_approvals表(AgentApprovalsPO)
- 复用现有orchestration_plans表(OrchestrationPlansPO)
