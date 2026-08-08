# 协同技能集与Kanban - 任务清单

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
| CS-T001 | 数据库表设计与创建 | P0 | 0.5天 | 无 |
| CS-T002 | Kanban CRUD模块生成与基础API | P0 | 1天 | CS-T001 |
| CS-T003 | KanbanService业务逻辑扩展 | P0 | 1.5天 | CS-T002 |
| CS-T004 | KanbanDispatcher长循环调度器 | P0 | 2天 | CS-T003 |
| CS-T005 | TeamMessage扩展（协同消息类型） | P0 | 0.5天 | 无 |
| CS-T006 | task-decompose协同技能 | P0 | 1天 | CS-T003 |
| CS-T007 | agent-select协同技能 | P0 | 0.5天 | CS-T003 |
| CS-T008 | context-pass协同技能 | P0 | 0.5天 | CS-T005 |
| CS-T009 | result-merge协同技能 | P0 | 0.5天 | CS-T005 |
| CS-T010 | conflict-resolve协同技能 | P0 | 0.5天 | CS-T005 |
| CS-T011 | handover协同技能 | P0 | 0.5天 | CS-T005 |
| CS-T012 | 协同流程COMPOSITION.yaml模板 | P1 | 0.5天 | CS-T006~CS-T011 |
| CS-T013 | 协同技能与AgentTeams集成 | P0 | 1.5天 | CS-T004, CS-T005 |
| CS-T014 | 集成测试与Demo验证 | P0 | 1天 | CS-T004, CS-T013 |

---

## CS-T001: 数据库表设计与创建

**描述**: 创建 agent_kanban_tasks 数据库表，遵循 uctoo-v4 数据库设计规范。

**子任务**:
1. **[自动化]** 编写 DDL 文件放置在 `sql/incremental/` 目录
2. **[人工操作]** 通知人工执行数据库变更
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表
4. **[人工操作]** 人工使用 `crudgen` 生成 Model/DAO/Service/Controller/Route 骨架，使用 `crudweb` 生成Web管理界面

**关键文件**:
- `sql/incremental/goai2026_p1_kanban_tasks.sql` - DDL脚本

**验收标准**:
- [ ] agent_kanban_tasks 表创建成功，包含所有必要字段
- [ ] 外键约束正确（team_id→agent_groups, assignee_id→agents, claimed_by→agents, parent_task_id→agent_kanban_tasks）
- [ ] 索引创建成功（status, team_id, assignee_id, claimed_by, parent_task_id, priority, claimed_at）
- [ ] db_info 表已更新
- [ ] crudgen 已生成标准CRUD模块

---

## CS-T002: Kanban CRUD模块生成与基础API

**描述**: 基于crudgen生成的标准CRUD模块，确认基础增删改查API可用。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 确认crudgen生成的AgentKanbanTasksPO/DAO/Service/Controller/Route代码
2. 验证PO类字段与DDL一致（@DataAssist[fields]和@QueryMappersGenerator注解）
3. 验证DAO接口（@DAO注解，继承RootDAO）
4. 验证Service方法返回APIResult<T>
5. 验证Controller和Route注册
6. 补充缺失字段或修正类型

**关键文件**:
- `src/app/models/uctoo/AgentKanbanTasksPO.cj`
- `src/app/dao/uctoo/AgentKanbanTasksDAO.cj`
- `src/app/services/uctoo/AgentKanbanTasksService.cj`
- `src/app/controllers/uctoo/agent_kanban_tasks/AgentKanbanTasksController.cj`
- `src/app/routes/uctoo/agent_kanban_tasks/AgentKanbanTasksRoute.cj`

**验收标准**:
- [ ] 标准 CRUD API 可正常调用（add/edit/del/query/page）
- [ ] PO类字段与DDL完全一致
- [ ] DAO接口注解正确
- [ ] Service方法返回APIResult<T>
- [ ] Controller和Route正确注册

---

## CS-T003: KanbanService业务逻辑扩展

**描述**: 在crudgen生成的KanbanService基础上，扩展Kanban任务生命周期相关的业务方法。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现 claimTask 方法（原子认领，调用DAO的atomicClaim）
2. 实现 completeTask 方法（完成任务，触发依赖任务检查）
3. 实现 blockTask 方法（阻塞任务，记录原因）
4. 实现 unblockTask 方法（解除阻塞，重置状态为assigned）
5. 实现 assignTask 方法（分配任务给Agent）
6. 实现 getTasksByStatus 方法（按状态查询）
7. 实现 getTasksByAgent 方法（按Agent查询）
8. 实现 getReadyTasksForAgent 方法（获取Agent可认领的任务）
9. 实现 triggerDependentTasks 方法（完成后触发依赖任务状态提升）
10. 在DAO中实现对应的查询方法

**关键文件**:
- `src/app/services/uctoo/AgentKanbanTasksService.cj` - 扩展业务方法
- `src/app/dao/uctoo/AgentKanbanTasksDAO.cj` - 扩展查询方法

**验收标准**:
- [ ] claimTask 原子认领正确工作（CAS防并发）
- [ ] completeTask 正确完成并触发依赖任务
- [ ] blockTask/unblockTask 正确工作
- [ ] assignTask 正确分配
- [ ] 按状态/Agent查询正确
- [ ] triggerDependentTasks 正确提升依赖任务状态

---

## CS-T004: KanbanDispatcher长循环调度器

**描述**: 实现KanbanDispatcher长循环调度器，负责任务队列的自动调度。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义 KanbanDispatcher 类（核心调度器）
2. 实现 start/stop 方法（启动/停止调度循环）
3. 实现 runOnce 方法（单次调度循环）
4. 实现 reclaimExpired 方法（回收过期claim）
   - 查询 claimed_at + claim_timeout_seconds < NOW() 的任务
   - 重置状态为assigned/ready，failCount++
   - 清空claimed_by和claimed_at
5. 实现 promoteReady 方法（提升ready任务）
   - 查询status=created且depends_on中所有任务都completed的任务
   - 更新状态为ready
6. 实现 atomicClaim 方法（原子claim操作）
   - SQL: UPDATE ... SET status='claimed', claimed_by=?, claimed_at=NOW() WHERE id=? AND status IN ('ready','assigned') AND (claimed_by IS NULL OR claimed_at < NOW() - interval)
   - 返回是否成功
7. 实现 checkAndBlockOverdue 方法（失败保护）
   - 查询 fail_count >= max_fail_count 的任务
   - 更新状态为blocked，记录blocked_reason
8. 注册为CrontabScheduler的BuiltinTask（可选，支持CRON触发模式）
9. 编写单元测试

**关键文件**:
- `src/agent_group/kanban_dispatcher.cj` - KanbanDispatcher主类

**验收标准**:
- [ ] 调度循环可正常启动和停止
- [ ] 过期claim正确回收，failCount递增
- [ ] 依赖满足的任务正确提升为ready
- [ ] 原子claim操作防并发冲突
- [ ] 连续失败超限任务自动block
- [ ] 单元测试覆盖核心调度逻辑

---

## CS-T005: TeamMessage扩展（协同消息类型）

**描述**: 扩展TeamMessage的消息类型枚举和payload类型，支持协同技能的结构化消息传递。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 在MessageType枚举中新增6个协同消息类型：
   - CONTEXT_PASS（上下文传递）
   - CONFLICT_NOTIFY（冲突通知）
   - HANDOVER_REQUEST（移交请求）
   - HANDOVER_ACK（移交确认）
   - KANBAN_CLAIM（Kanban认领通知）
   - KANBAN_COMPLETE（Kanban完成通知）
   - KANBAN_BLOCK（Kanban阻塞通知）
2. 扩展TeamMessage的payload字段类型从String到JsonValue
3. 保持向后兼容（现有消息类型不受影响）
4. 更新TeamMessenger中payload的序列化/反序列化逻辑

**关键文件**:
- `src/agent_group/team_message.cj` - 消息定义扩展
- `src/agent_group/team_messenger.cj` - 消息传递器适配

**验收标准**:
- [ ] 新增7个MessageType枚举值
- [ ] payload字段支持JsonValue类型
- [ ] 现有消息类型和逻辑不受影响
- [ ] TeamMessenger正确处理新消息类型

---

## CS-T006: task-decompose协同技能

**描述**: 实现task-decompose协同技能，将复杂任务分解为子任务DAG并创建Kanban任务。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 创建 skills/task-decompose/SKILL.md 技能定义文件
2. 定义技能输入：task_description(任务描述), team_id(团队ID), max_depth(最大分解深度,默认2)
3. 定义技能输出：sub_tasks(子任务列表), dag_edges(DAG依赖边), task_ids(创建的Kanban任务ID列表)
4. 实现技能逻辑：
   - 调用LLM分解任务为子任务DAG
   - 复用DagScheduler的拓扑排序逻辑确定执行顺序
   - 为每个子任务调用KanbanService.createTask()创建Kanban任务
   - 设置子任务间的depends_on关系
5. 编写技能使用示例

**关键文件**:
- `skills/task-decompose/SKILL.md` - 技能定义

**验收标准**:
- [ ] SKILL.md格式符合规范
- [ ] 任务分解为子任务DAG正确
- [ ] 每个子任务创建Kanban任务记录
- [ ] 子任务间依赖关系正确设置
- [ ] 通过SkillToToolAdapter可被Agent调用

---

## CS-T007: agent-select协同技能

**描述**: 实现agent-select协同技能，根据子任务特征选择最合适的Agent。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 创建 skills/agent-select/SKILL.md 技能定义文件
2. 定义技能输入：task_id(Kanban任务ID), candidate_agents(候选Agent列表), selection_strategy(选择策略,默认skill_match)
3. 定义技能输出：selected_agent_id(选中的Agent ID), selection_reason(选择原因)
4. 实现技能逻辑：
   - 查询Kanban任务详情获取任务要求
   - 查询候选Agent的技能列表和负载情况
   - 根据选择策略（skill_match/load_balance/priority）匹配Agent
   - 调用KanbanService.assignTask()分配任务
5. 编写技能使用示例

**关键文件**:
- `skills/agent-select/SKILL.md` - 技能定义

**验收标准**:
- [ ] SKILL.md格式符合规范
- [ ] 根据技能匹配选择Agent正确
- [ ] 调用KanbanService.assignTask()正确分配
- [ ] 通过SkillToToolAdapter可被Agent调用

---

## CS-T008: context-pass协同技能

**描述**: 实现context-pass协同技能，在Agent间传递结构化上下文。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 创建 skills/context-pass/SKILL.md 技能定义文件
2. 定义技能输入：from_agent_id(发送Agent), to_agent_id(接收Agent), context_data(上下文数据), task_id(关联Kanban任务)
3. 定义技能输出：pass_result(传递结果), message_id(消息ID)
4. 实现技能逻辑：
   - 构造CONTEXT_PASS类型的TeamMessage
   - payload为结构化JsonValue（包含context_data和task_id）
   - 通过TeamMessenger.send()发送
   - 更新Kanban任务的context字段
5. 编写技能使用示例

**关键文件**:
- `skills/context-pass/SKILL.md` - 技能定义

**验收标准**:
- [ ] SKILL.md格式符合规范
- [ ] 通过TeamMessenger正确传递结构化上下文
- [ ] Kanban任务的context字段正确更新
- [ ] 通过SkillToToolAdapter可被Agent调用

---

## CS-T009: result-merge协同技能

**描述**: 实现result-merge协同技能，聚合多个Agent的执行结果。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 创建 skills/result-merge/SKILL.md 技能定义文件
2. 定义技能输入：task_ids(Kanban任务ID列表), merge_strategy(合并策略,默认hierarchical)
3. 定义技能输出：merged_result(合并结果), has_conflicts(是否存在冲突), conflicts(冲突详情)
4. 实现技能逻辑：
   - 查询所有Kanban任务的结果
   - 通过TeamMessenger.getMessagesTo()收集RESULT_REPORT消息
   - 根据合并策略（hierarchical/voting/sequential）聚合结果
   - 检测冲突（结果不一致时标记）
5. 编写技能使用示例

**关键文件**:
- `skills/result-merge/SKILL.md` - 技能定义

**验收标准**:
- [ ] SKILL.md格式符合规范
- [ ] 正确聚合多个Agent的执行结果
- [ ] 冲突检测正确
- [ ] 支持hierarchical/voting/sequential合并策略
- [ ] 通过SkillToToolAdapter可被Agent调用

---

## CS-T010: conflict-resolve协同技能

**描述**: 实现conflict-resolve协同技能，解决Agent间的执行冲突。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 创建 skills/conflict-resolve/SKILL.md 技能定义文件
2. 定义技能输入：conflicting_results(冲突结果列表), resolve_strategy(解决策略,默认priority_based)
3. 定义技能输出：resolved_result(解决后的结果), resolution_method(解决方法)
4. 实现技能逻辑：
   - 构造CONFLICT_NOTIFY类型的TeamMessage
   - 通过TeamMessenger.broadcast()广播冲突通知
   - 根据解决策略（priority_based/voting/manager_decide）解决冲突
   - 返回解决后的结果
5. 编写技能使用示例

**关键文件**:
- `skills/conflict-resolve/SKILL.md` - 技能定义

**验收标准**:
- [ ] SKILL.md格式符合规范
- [ ] 正确识别和解决Agent间冲突
- [ ] 通过TeamMessenger广播冲突通知
- [ ] 支持priority_based/voting/manager_decide策略
- [ ] 通过SkillToToolAdapter可被Agent调用

---

## CS-T011: handover协同技能

**描述**: 实现handover协同技能，将控制权移交给另一个Agent。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 创建 skills/handover/SKILL.md 技能定义文件
2. 定义技能输入：from_agent_id(当前Agent), to_agent_id(目标Agent), task_id(关联Kanban任务), handover_context(移交上下文)
3. 定义技能输出：handover_result(移交结果), ack_received(是否确认)
4. 实现技能逻辑：
   - 构造HANDOVER_REQUEST类型的TeamMessage
   - 通过TeamMessenger.send()发送移交请求
   - 等待HANDOVER_ACK确认
   - 更新Kanban任务的claimed_by字段
5. 编写技能使用示例

**关键文件**:
- `skills/handover/SKILL.md` - 技能定义

**验收标准**:
- [ ] SKILL.md格式符合规范
- [ ] 通过TeamMessenger正确发送移交请求
- [ ] 等待HANDOVER_ACK确认
- [ ] Kanban任务的claimed_by正确更新
- [ ] 通过SkillToToolAdapter可被Agent调用

---

## CS-T012: 协同流程COMPOSITION.yaml模板

**描述**: 创建协同流程的COMPOSITION.yaml组合模板，定义标准协同流程。

**子任务**:
1. 创建 skills/collaboration-flow/COMPOSITION.yaml
2. 定义协同流程步骤：decompose-task → select-agents → pass-context → merge-results → resolve-conflicts → handover
3. 设置步骤间的依赖关系和条件分支
4. 定义输入输出映射
5. 创建 skills/collaboration-flow/SKILL.md 技能定义文件
6. 编写使用示例

**关键文件**:
- `skills/collaboration-flow/COMPOSITION.yaml` - 组合模板
- `skills/collaboration-flow/SKILL.md` - 技能定义

**验收标准**:
- [ ] COMPOSITION.yaml格式正确，可被CompositionYamlParser解析
- [ ] 步骤依赖关系正确
- [ ] 条件分支正确（conflict-resolve仅在has_conflicts时执行）
- [ ] 通过CompositionExecutor可执行协同流程
- [ ] SKILL.md格式符合规范

---

## CS-T013: 协同技能与AgentTeams集成

**描述**: 实现协同技能与AgentTeams的集成，使ManagerGroup通过协同技能驱动协作而非固定程序式流程。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 修改ManagerGroup的chat方法，集成协同技能调用：
   - Manager使用task-decompose分解任务
   - Manager使用agent-select选择Agent
   - TeamLeader使用context-pass传递上下文
   - TeamLeader使用result-merge聚合结果
2. 集成KanbanDispatcher与TeamMessenger：
   - KanbanDispatcher状态变更时发送TeamMessage通知
   - KANBAN_CLAIM/KANBAN_COMPLETE/KANBAN_BLOCK消息类型
3. 实现ManagerGroup的技能驱动模式：
   - 检测是否配置了协同技能
   - 有协同技能时走技能驱动流程
   - 无协同技能时保持原有固定程序式流程
4. 实现协同流程的COMPOSITION.yaml执行：
   - ManagerGroup可加载collaboration-flow模板
   - 通过CompositionExecutor执行协同流程
5. 编写集成测试

**关键文件**:
- `src/agent_group/manager_group.cj` - 修改chat方法集成协同技能
- `src/agent_group/kanban_dispatcher.cj` - 与TeamMessenger集成
- `src/agent_executor/dag_team_orchestrator.cj` - 协同流程编排

**验收标准**:
- [ ] ManagerGroup通过task-decompose分解任务
- [ ] ManagerGroup通过agent-select选择Agent
- [ ] TeamLeader通过context-pass传递上下文
- [ ] TeamLeader通过result-merge聚合结果
- [ ] KanbanDispatcher状态变更通过TeamMessenger通知
- [ ] 无协同技能时保持原有流程兼容
- [ ] 集成测试通过

---

## CS-T014: 集成测试与Demo验证

**描述**: 编写集成测试，验证协同技能集与Kanban的完整功能。

**子任务**:
1. 编写KanbanDispatcher调度循环测试
2. 编写6个协同技能的端到端测试
3. 编写协同技能与AgentTeams集成测试
4. 编写COMPOSITION.yaml协同流程执行测试
5. 创建Demo场景：ManagerGroup通过协同技能驱动完成一个开发任务
6. 编写Python测试脚本验证RESTful API

**关键文件**:
- `tests/kanban_dispatcher_test.cj` - Dispatcher测试
- `tests/collaboration_skills_test.cj` - 协同技能测试
- `tests/collaboration_integration_test.cj` - 集成测试
- `sdk/python/tests/test_kanban_api.py` - API测试

**验收标准**:
- [ ] KanbanDispatcher调度循环测试通过
- [ ] 6个协同技能可正确执行
- [ ] 协同技能与AgentTeams正确集成
- [ ] COMPOSITION.yaml协同流程可执行
- [ ] Demo可重复运行
- [ ] Python API测试通过