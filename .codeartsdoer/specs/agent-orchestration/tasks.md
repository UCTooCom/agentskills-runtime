# 任务分解与DAG编排引擎 - 任务清单

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
| ORCH-T001 | 数据库表设计与创建 | P0 | 0.5天 | 无 | ✅已完成 |
| ORCH-T002 | DagConfig配置解析器 | P0 | 1天 | 无 | ✅已完成 |
| ORCH-T003 | DagScheduler核心调度引擎 | P0 | 2天 | ORCH-T002 | ✅已完成 |
| ORCH-T004 | ConditionEvaluator条件求值 | P0 | 1天 | ORCH-T003 | ✅已完成 |
| ORCH-T005 | ResultAggregator结果聚合 | P0 | 1天 | ORCH-T003 | ✅已完成 |
| ORCH-T006 | DynamicReplanner动态重编排 | P1 | 1天 | ORCH-T003 | ⏳待完成 |
| ORCH-T007 | ResourceArbiter资源仲裁 | P1 | 1天 | ORCH-T003 | ⏳待完成 |
| ORCH-T008 | CRUD模块与API实现 | P0 | 1天 | ORCH-T001 | ✅已完成(crudgen已生成) |
| ORCH-T009 | 与AgentTeams集成 | P0 | 1天 | ORCH-T003, agent-teams | ✅已完成 |
| ORCH-T010 | 集成测试与验证 | P0 | 1天 | ORCH-T001~T009 | ⏳待完成 |

---

## 仓颉规范合规性要求（来自cangjie-compliance-review.md）

- [ ] DagScheduler类添加`public`修饰符（需被继承的使用`open public`）
- [ ] schedule等方法返回值改用`Option<Unit>`或`APIResult<Unit>`
- [ ] PlantUML数据模型中`JsonObject`改为`JsonValue`（JSONB字段对应JsonValue类型）
- [ ] PO类补充`@DataAssist[fields]`和`@QueryMappersGenerator`注解
- [ ] DAO接口使用`@DAO`注解并继承`RootDAO`
- [ ] Service方法统一返回`APIResult<T>`
- [ ] 补充标准包名和import说明

---

## ORCH-T001: 数据库表设计与创建

**描述**: 创建 orchestration_plans 和 orchestration_steps 数据库表。

**子任务**:
1. **[自动化]** 编写DDL文件放置在 `sql/incremental/` 目录
2. **[人工操作]** 通知人工执行数据库变更
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表
4. **[人工操作]** 人工使用 `crudgen` 生成Model/DAO/Service/Controller/Route骨架，使用 `crudweb` 生成Web管理界面

**验收标准**:
- [ ] orchestration_plans表创建成功
- [ ] orchestration_steps表创建成功，外键约束正确
- [ ] 索引创建成功

---

## ORCH-T002: DagConfig配置解析器

**描述**: 实现dag_plans.yaml配置文件解析器，将YAML配置转换为DagConfig对象。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义DagConfig和StepConfig数据类
2. 实现YamlDagConfigParser解析器
3. 支持步骤依赖关系解析和拓扑排序
4. 实现循环依赖检测
5. 编写单元测试

**关键文件**:
- `src/agent_executor/dag_config.cj`
- `src/agent_executor/yaml_dag_config_parser.cj`

**验收标准**:
- [x] dag_plans.yaml可正确解析为DagConfig
- [x] 拓扑排序正确处理依赖关系
- [x] 循环依赖正确检测和报错

---

## ORCH-T003: DagScheduler核心调度引擎

**描述**: 实现DAG调度引擎，支持步骤的并行执行和状态管理。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现DagScheduler类
2. 实现拓扑排序算法
3. 实现并行步骤识别和调度
4. 实现步骤状态管理（pending→running→completed/failed）
5. 实现WebSocket状态变更通知
6. 与OrchestrationPlanService集成

**关键文件**:
- `src/agent_executor/dag_scheduler.cj`

**验收标准**:
- [ ] DAG步骤按拓扑顺序正确执行
- [ ] 无依赖步骤并行执行
- [ ] 步骤状态正确流转
- [ ] WebSocket推送状态变更

---

## ORCH-T004: ConditionEvaluator条件求值

**描述**: 实现条件表达式解析和求值，支持基于前序步骤结果的条件分支。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义条件表达式语法（简化版：${step.result.field} == value）
2. 实现ConditionEvaluator
3. 支持基本比较运算（==、!=、>、<、contains）
4. 支持逻辑运算（and、or、not）
5. 编写单元测试

**关键文件**:
- `src/agent_executor/condition_evaluator.cj`

**验收标准**:
- [ ] 条件表达式正确解析和求值
- [ ] 基于前序步骤结果的条件分支正确工作
- [ ] 逻辑运算正确

---

## ORCH-T005: ResultAggregator结果聚合

**描述**: 实现结构化的结果聚合框架。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义StepResult数据类（status、output、metrics、errors）
2. 定义聚合规则（merge、vote、arbitrate）
3. 实现ResultAggregator
4. 支持冲突检测和解决策略
5. 支持增量聚合

**关键文件**:
- `src/agent_executor/result_aggregator.cj`

**验收标准**:
- [ ] 多步骤结果正确聚合
- [ ] 冲突检测和解决正确
- [ ] 增量聚合正确工作

---

## ORCH-T006: DynamicReplanner动态重编排

**描述**: 实现运行时动态调整执行计划。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现DynamicReplanner
2. 支持动态插入/删除步骤
3. 支持替换失败的Agent
4. 支持根据执行结果调整并行度
5. 重编排后重新拓扑排序

**关键文件**:
- `src/agent_executor/dynamic_replanner.cj`

**验收标准**:
- [ ] 运行时可动态调整计划
- [ ] 重编排后执行顺序正确

---

## ORCH-T007: ResourceArbiter资源仲裁

**描述**: 实现资源锁和配额管理。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现ResourceArbiter
2. 支持资源锁（文件锁、数据库行锁）
3. 支持资源配额（Agent并发数、内存限制）
4. 实现死锁检测

**关键文件**:
- `src/agent_executor/resource_arbiter.cj`

**验收标准**:
- [ ] 资源锁正确工作
- [ ] 配额限制正确执行
- [ ] 死锁检测正确

---

## ORCH-T008: CRUD模块与API实现

**描述**: 基于crudgen生成的标准CRUD模块，迭代开发执行调度API。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 使用crudgen生成OrchestrationPlanPO和OrchestrationStepPO的CRUD代码
2. 实现OrchestrationPlanService扩展方法：
   - executePlan(input) - 执行计划
   - pausePlan() - 暂停执行
   - replanPlan(adjustment) - 动态重编排
3. 遵循uctoo-v4 API规范

**验收标准**:
- [ ] 标准 CRUD API可正常调用
- [ ] executePlan API正确触发DAG调度
- [ ] API遵循uctoo-v4规范

---

## ORCH-T009: 与AgentTeams集成

**描述**: 将DAG编排引擎与AgentTeams分层架构集成。

**子任务**:
1. Manager使用DagScheduler分解和调度任务
2. DAG步骤与TeamLeader/Worker映射
3. 步骤结果通过TeamMessenger传递
4. 执行状态与团队状态同步

**验收标准**:
- [ ] Manager可通过DagScheduler调度TeamLeader
- [ ] DAG步骤正确映射到TeamLeader/Worker
- [ ] 步骤结果正确传递

---

## ORCH-T010: 集成测试与验证

**描述**: 编写集成测试，验证DAG编排引擎的完整功能。

**子任务**:
1. 编写DagScheduler集成测试
2. 编写条件分支测试
3. 编写动态重编排测试
4. 编写与AgentTeams集成测试
5. 创建Demo场景：多步骤DAG执行

**验收标准**:
- [ ] 所有集成测试通过
- [ ] Demo可重复运行
- [ ] DAG调度正确
- [ ] 条件分支正确