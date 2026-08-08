# 审批与回滚机制 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式
- 数据库列名使用 snake_case，仓颉代码使用 camelCase
- crudgen 生成的代码写在 `//#region AutoCreateCode` 区域内，增量开发代码写在该区域外

### 数据库结构变更流程（uctoo-v4 通用模块开发流程）
- 涉及数据库结构变更和新增时，必须遵循以下流程：
  1. **[自动化]** 在 `sql/incremental/` 目录生成数据库DDL脚本
  2. **[人工操作]** 通知人工执行数据库变更（执行DDL）
  3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表，使用 `crudgen` 生成标准CRUD模块（Model/DAO/Service/Controller/Route），使用 `crudweb` 生成Web管理界面
  4. **[自动化]** 基于生成的CRUD模块进行迭代开发（定制代码写在 `//#region AutoCreateCode` 区域外）

---

## 任务总览

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| AR-T001 | ApprovalManager审批流程管理器 | P0 | 2天 | execution-audit已完成 |
| AR-T002 | AgentApprovals CRUD扩展与审批API | P0 | 1天 | AR-T001 |
| AR-T003 | RollbackManager回滚执行管理器 | P0 | 2天 | execution-audit已完成 |
| AR-T004 | CheckpointManager检查点管理器 | P0 | 1.5天 | AR-T003 |
| AR-T005 | DagPlanStatus扩展与DagScheduler集成 | P0 | 1天 | AR-T001, AR-T003 |
| AR-T006 | ApprovalConfig审批配置 | P1 | 0.5天 | AR-T001 |
| AR-T007 | 与DagTeamOrchestrator集成 | P0 | 1天 | AR-T001~T005 |
| AR-T008 | 集成测试与验证 | P0 | 1.5天 | AR-T001~T007 |

---

## AR-T001: ApprovalManager审批流程管理器

**描述**: 实现审批流程管理器，封装审批生命周期（创建→等待→审批/超时→记录），复用HITL @interact事件处理和agent_approvals表。

**子任务**:
1. 定义ApprovalStatus枚举（Pending/Approved/Rejected/Timeout/Cancelled）
2. 定义ApprovalType枚举（HighRiskOperation/DataDeletion/SystemConfig/ResourceIntensive/Custom）
3. 定义ApprovalRequest数据类
4. 定义ApprovalResult数据类
5. 实现ApprovalManager.requestApproval() - 创建审批记录并发起HITL交互
6. 实现ApprovalManager.checkApprovalNeeded() - 根据步骤配置判断是否需要审批
7. 实现ApprovalManager.approve()/reject() - 更新审批状态
8. 实现ApprovalManager.handleTimeout() - 超时处理
9. 实现审批记录持久化到agent_approvals表
10. 通过@interact宏集成HITL事件处理

**关键文件**:
- `src/interaction/approval_manager.cj`（新建）

**验收标准**:
- [ ] 高风险步骤正确触发审批流程
- [ ] 审批记录持久化到agent_approvals表
- [ ] 审批超时正确处理
- [ ] 复用@interact宏进行人工交互

---

## AR-T002: AgentApprovals CRUD扩展与审批API

**描述**: 扩展AgentApprovalsPO的CRUD模块，新增审批操作API（approve/reject），扩展approval_type字段值。

**子任务**:
1. 确认AgentApprovalsPO的crudgen标准CRUD已生成
2. 在AgentApprovalsService中新增approve方法
3. 在AgentApprovalsService中新增reject方法
4. 在AgentApprovalsService中新增getPendingApprovals方法
5. 在AgentApprovalsService中新增getApprovalHistory方法
6. 在AgentApprovalsController中新增审批操作API端点
7. 扩展approval_type字段值（high_risk_operation/data_deletion/system_config/resource_intensive/rollback_operation）

**关键文件**:
- `src/app/services/uctoo/AgentApprovalsService.cj`
- `src/app/controllers/uctoo/AgentApprovalsController.cj`
- `src/app/models/uctoo/AgentApprovalsPO.cj`

**验收标准**:
- [ ] 审批通过API可正常调用
- [ ] 审批拒绝API可正常调用
- [ ] 待审批列表查询正确
- [ ] 审批历史查询正确

---

## AR-T003: RollbackManager回滚执行管理器

**描述**: 实现回滚执行管理器，基于SideEffectTracker的副作用记录执行逆序回滚，支持可配置的回滚策略。

**子任务**:
1. 定义RollbackStrategy枚举（FullRollback/PartialRollback/MarkFailed）
2. 定义RollbackPlan数据类
3. 定义RollbackResult数据类
4. 实现RollbackManager.createRollbackPlan() - 从SideEffectTracker获取副作用并生成回滚计划
5. 实现RollbackManager.executeRollback() - 按逆序执行回滚
6. 实现rollbackFileWrite() - 恢复文件到beforeState
7. 实现rollbackDbInsert() - 删除插入的记录
8. 实现rollbackDbUpdate() - 恢复到beforeState
9. 实现rollbackDbDelete() - 恢复删除的记录
10. 实现rollbackApiCall() - 记录不可逆API调用的回滚标记
11. 回滚操作本身记录到SideEffectTracker
12. 回滚结果记录到ExecutionEvidenceRecorder

**关键文件**:
- `src/interaction/rollback_manager.cj`（新建）

**验收标准**:
- [ ] 编排失败时正确触发回滚
- [ ] 文件修改副作用正确回滚
- [ ] 数据库变更副作用正确回滚
- [ ] 回滚操作本身被副作用追踪记录
- [ ] 三种回滚策略均正确工作

---

## AR-T004: CheckpointManager检查点管理器

**描述**: 实现检查点管理器，管理编排计划的检查点写入与恢复，数据持久化到orchestration_plans.checkpoint字段。

**子任务**:
1. 定义CheckpointData数据类（含planId/completedSteps/stepOutputs/sideEffectIds/savedAt/version）
2. 实现CheckpointData.toJsonValue()序列化
3. 实现CheckpointData.fromJsonValue()反序列化
4. 实现CheckpointManager.saveCheckpoint() - 保存检查点到orchestration_plans.checkpoint
5. 实现CheckpointManager.loadCheckpoint() - 从orchestration_plans.checkpoint读取
6. 实现CheckpointManager.recoverFromCheckpoint() - 从检查点恢复执行
7. 恢复时设置DagScheduler步骤状态，跳过已完成步骤
8. 实现CheckpointManager.clearCheckpoint() - 清除检查点
9. 检查点保存不阻塞主流程

**关键文件**:
- `src/interaction/checkpoint_manager.cj`（新建）

**验收标准**:
- [ ] 检查点数据正确持久化到orchestration_plans.checkpoint
- [ ] 检查点数据可正确反序列化
- [ ] 从检查点恢复时正确跳过已完成步骤
- [ ] 检查点保存不阻塞主流程

---

## AR-T005: DagPlanStatus扩展与DagScheduler集成

**描述**: 扩展DagPlanStatus枚举新增RollingBack状态，在DagScheduler和DagTeamOrchestrator中集成审批和回滚流程。

**子任务**:
1. DagPlanStatus枚举新增RollingBack状态
2. DagScheduler新增rollbackStep()方法
3. DagTeamOrchestrator.orchestrateWithTeam()集成ApprovalManager - 高风险步骤触发审批
4. DagTeamOrchestrator.orchestrateWithTeam()集成RollbackManager - 编排失败触发回滚
5. DagTeamOrchestrator.orchestrateWithTeam()集成CheckpointManager - 步骤完成保存检查点
6. 编排恢复入口方法

**关键文件**:
- `src/agent_executor/dag_scheduler.cj`（修改）
- `src/agent_executor/dag_team_orchestrator.cj`（修改）

**验收标准**:
- [ ] RollingBack状态正确标识回滚中
- [ ] 高风险步骤自动触发审批
- [ ] 编排失败自动触发回滚
- [ ] 步骤完成自动保存检查点

---

## AR-T006: ApprovalConfig审批配置

**描述**: 实现审批配置，定义审批触发条件和策略，支持从配置文件或数据库加载。

**子任务**:
1. 定义ApprovalConfig数据类
2. 实现默认审批配置（高风险操作需审批，低风险自动通过）
3. 实现审批条件判断逻辑（操作类型、影响范围、资源消耗阈值）
4. 支持从StepConfig中读取审批标记
5. 配置可运行时更新

**关键文件**:
- `src/interaction/approval_config.cj`（新建，或合入approval_manager.cj）

**验收标准**:
- [ ] 审批触发条件可配置
- [ ] 默认配置正确工作
- [ ] StepConfig中可标记需要审批的步骤

---

## AR-T007: 与DagTeamOrchestrator集成

**描述**: 将审批、回滚、检查点管理器与DagTeamOrchestrator完整集成，形成端到端的审批回滚闭环。

**子任务**:
1. DagTeamOrchestrator注入ApprovalManager/RollbackManager/CheckpointManager
2. 编排执行流程：步骤前检查审批→执行→保存检查点→失败时回滚
3. 审批通过WebSocket推送通知
4. 回滚结果通过WebSocket推送
5. 编排恢复API端点
6. 与AuditEventHandler集成，确保审批和回滚操作有完整审计证据

**关键文件**:
- `src/agent_executor/dag_team_orchestrator.cj`（修改）
- `src/app/controllers/uctoo/OrchestrationPlansController.cj`（修改）

**验收标准**:
- [ ] 端到端审批回滚流程正确工作
- [ ] WebSocket推送审批和回滚通知
- [ ] 审批和回滚操作有完整审计证据
- [ ] 编排恢复API可正常调用

---

## AR-T008: 集成测试与验证

**描述**: 编写集成测试，验证审批与回滚机制的完整功能。

**子任务**:
1. 编写ApprovalManager集成测试 - 审批流程生命周期
2. 编写RollbackManager集成测试 - 三种回滚策略
3. 编写CheckpointManager集成测试 - 检查点保存与恢复
4. 编写DagTeamOrchestrator端到端集成测试
5. 编写审批超时场景测试
6. 编写回滚失败场景测试
7. 编写检查点版本兼容性测试

**验收标准**:
- [ ] 审批流程全生命周期测试通过
- [ ] 三种回滚策略测试通过
- [ ] 检查点保存与恢复测试通过
- [ ] 端到端集成测试通过
- [ ] 审批超时场景测试通过
- [ ] 回滚失败场景测试通过