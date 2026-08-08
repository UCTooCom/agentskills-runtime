# GOAI 2026「新智基座」赛道：编码任务规划

## 文档信息
- **项目名称**: agentskills-runtime GOAI2026赛事编码任务规划
- **版本**: 1.0
- **创建日期**: 2026-07-24
- **目标**: 将22个工程的需求设计转化为可执行的编码任务，确保复赛前完成P0工程
- **状态**: 已完成（全部22个工程编码实现完成，占位实现已修复）

---

## 1. 总体规划

### 1.1 工程总览

| 优先级 | 工程数量 | 总工时 | 覆盖需求 | 对标维度 |
|--------|---------|--------|---------|---------|
| P0 | 9个 | 40天 | GOAI-001~005, 013, 014, 022, 023 | 全部5项维度 |
| P1 | 8个 | 34天 | GOAI-006~010, 015~018, 024~028 | 全部5项维度 |
| P2 | 5个 | 18天 | GOAI-011, 012, 019~021, 029, 030 | 增强竞争力 |

### 1.2 赛程时间线与里程碑

| 里程碑 | 截止日期 | 交付物 | 对应工程 |
|--------|---------|--------|---------|
| M1: 初赛PPT | 8月16日 | 方案PPT+架构设计 | 全部P0设计文档 |
| M2: 基础设施层 | 8月24日 | AgentTeams+技能组合+代码生成技能 | P0-1,4,5,6 |
| M3: 编排与审计层 | 8月31日 | DAG编排+证据链+全栈代码生成 | P0-2,3,7,8 |
| M4: 复赛提交 | 9月3日 | 可执行代码包+可运行Demo | P0-9 + 全部P0 |
| M5: 决赛准备 | 9月15日 | P1工程+Demo稳定性 | P1关键工程 |
| M6: 决赛答辩 | 9月22日 | 现场演示+答辩材料 | 全部 |

### 1.3 关键设计原则

1. **确定性优先，AI增强**：确定性代码做确定的事（CRUD、权限、调度），AI做推理决策（任务分解、技能选择、代码生成）
2. **可配置引擎优先于硬编码程序**：所有功能通过YAML/Markdown配置动态调整，不硬编码业务功能
3. **复用和优化已有基础设施**：优先复用crudgen/crudweb/loaddbinfo/cangjie-coder等已有能力
4. **技能是一等公民**：新功能优先通过SKILL.md技能实现，而非硬编码到核心
5. **仓颉代码编写必须使用cangjie-coder技能**：遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
6. **数据库变更遵循uctoo-v4通用模块开发流程**：DDL生成→人工变更→CRUD生成→迭代开发

---

## 2. 工程依赖关系与开发顺序

### 2.1 依赖关系图

```
                    ┌─────────────────────────────────────────────────────┐
                    │                    P0 核心工程                        │
                    └─────────────────────────────────────────────────────┘

层1(无依赖,可并行):
  P0-1 agent-teams          P0-4 skill-composition-engine    P0-5 cangjie-coder-agents    P0-6 code-gen-skills
       │                         │                                │                            │
       │                         │                                ├──────────────┐             │
       ▼                         ▼                                ▼              ▼             ▼
层2(依赖层1):
  P0-2 agent-orchestration   P0-3 execution-audit            P0-8 fullstack-codegen ◄────────┘
       │                         │                                │
       │                         │                                │
       ▼                         ▼                                ▼
层3(依赖层2):
  P0-7 sdd-skills ──────────────────────────────────────► P0-9 ai-dev-demo
                                                              ▲
                                                              │
                                                    全部P0工程汇聚

                    ┌─────────────────────────────────────────────────────┐
                    │                    P1 增强工程                        │
                    └─────────────────────────────────────────────────────┘

  P1-2 agent-memory-persistence(独立)
  P1-1 agent-context-verify ◄── P0-1, P0-2
  P1-3 agent-loop ◄── P0-3
  P1-4 approval-rollback ◄── P0-3
  P1-5 language-skills-orchestration ◄── P0-5, P0-4
  P1-6 skill-evolution ◄── P0-4
  P1-7 collaboration-skills ◄── P0-1
  P1-8 test-generator ◄── P0-5

                    ┌─────────────────────────────────────────────────────┐
                    │                    P2 锦上添花工程                     │
                    └─────────────────────────────────────────────────────┘

  P2-1 agent-error-recovery ◄── P0-3
  P2-2 open-source-plan(独立)
  P2-3 memory-provider ◄── P1-2
  P2-4 context-optimization(独立)
  P2-5 agent-intelligence ◄── P1-5
```

### 2.2 开发批次与并行策略

| 批次 | 时间窗口 | 并行工程 | 关键路径 | 备注 |
|------|---------|---------|---------|------|
| 批次1 | 第1周(8/17-8/23) | P0-1, P0-4, P0-5, P0-6 | P0-1 AgentTeams | 4个无依赖工程并行开发 |
| 批次2 | 第2周(8/24-8/30) | P0-2, P0-3, P0-8 | P0-2 DAG编排 | 依赖批次1的工程 |
| 批次3 | 第3周(8/31-9/3) | P0-7, P0-9 | P0-9 Demo | 复赛提交前冲刺 |
| 批次4 | 第4周(9/4-9/10) | P1-1~P1-4 | P1-1 上下文传递 | 决赛入围公布前 |
| 批次5 | 第5周(9/11-9/17) | P1-5~P1-8 | P1-5 编排协作 | 决赛准备 |
| 批次6 | 第6周(9/18-9/22) | Demo优化+答辩 | - | 决赛答辩 |

### 2.3 关键路径

```
P0-1 agent-teams → P0-2 agent-orchestration → P0-7 sdd-skills → P0-9 ai-dev-demo
                                                              ↑
P0-5 cangjie-coder-agents → P0-8 fullstack-codegen ──────────┘
```

**关键路径总工时**: 5+5+3+3+3 = 19天（含Demo），需在18个工作日内完成（8/17-9/3）

**风险缓解**: 批次1的4个工程并行开发，可将关键路径缩短至14天

---

## 3. P0核心工程编码任务

### 3.1 P0-1: AgentTeams分层协作架构

**工程目录**: `agent-teams` | **预估工时**: 8天 | **对标维度**: 多Agent协同(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| AT-T001 | 数据库表设计与创建 | design.md数据模型 | DDL脚本+CRUD骨架 | agent_teams/agent_team_members表创建成功，索引正确 | 0.5天 | 无 | DDL生成→人工变更→CRUD生成 |
| AT-T002 | TeamConfig YAML配置解析器 | agent_teams.yaml | TeamConfig对象 | YAML正确解析，配置校验检测缺失字段 | 1天 | 无 | cangjie-coder |
| AT-T003 | ManagerGroup核心实现 | TeamConfig+AgentGroup接口 | ManagerGroup类 | 三层Agent组正确创建，任务分解分配正确 | 2天 | AT-T001 | cangjie-coder |
| AT-T004 | TeamMessenger分层消息传递 | Agent间通信需求 | TeamMessenger类 | 点对点/广播/请求-响应模式正确 | 1天 | AT-T003 | cangjie-coder |
| AT-T005 | TeamManager生命周期管理 | TeamConfig+状态机 | TeamManager类 | 团队创建/销毁/动态调整正确，状态持久化 | 1天 | AT-T002,T003 | cangjie-coder |
| AT-T006 | AgentTeams DSL扩展 | AgentGroup DSL | @agentTeams宏 | `~`运算符正确创建ManagerGroup | 0.5天 | AT-T003 | cangjie-coder |
| AT-T007 | CRUD模块生成与API实现 | crudgen生成的CRUD | 扩展API | executeTeam/pauseTeam/resumeTeam API正确 | 1天 | AT-T001 | cangjie-coder |
| AT-T008 | 集成测试与Demo验证 | 全部组件 | 测试报告+Demo | 所有测试通过，三层协作正确 | 1天 | AT-T001~T007 | Python测试脚本 |

**仓颉规范合规性要求**（来自cangjie-compliance-review.md）:
- [x] TeamManager/TeamMessenger类添加`public`修饰符
- [x] 方法返回值使用`Option<T>`或`APIResult<T>`包装可能失败的操作
- [x] PlantUML数据模型中`JsonObject`改为`JsonValue`
- [x] 补充PO类`@DataAssist[fields]`和`@QueryMappersGenerator`注解
- [x] DAO接口使用`@DAO`注解并继承`RootDAO`
- [x] Service方法返回`APIResult<T>`
- [x] 补充包名：`magic.app.models.uctoo`、`magic.app.dao.uctoo`等

---

### 3.2 P0-2: 任务分解与DAG编排引擎

**工程目录**: `agent-orchestration` | **预估工时**: 10天 | **对标维度**: 多Agent协同(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| ORCH-T001 | 数据库表设计与创建 | design.md数据模型 | DDL脚本+CRUD骨架 | orchestration_plans/steps表创建成功 | 0.5天 | 无 | DDL生成→人工变更→CRUD生成 |
| ORCH-T002 | DagConfig配置解析器 | dag_plans.yaml | DagConfig对象 | YAML解析正确，拓扑排序正确，循环依赖检测 | 1天 | 无 | cangjie-coder |
| ORCH-T003 | DagScheduler核心调度引擎 | DagConfig | 调度执行结果 | 拓扑顺序执行，无依赖步骤并行，WebSocket推送 | 2天 | ORCH-T002 | cangjie-coder |
| ORCH-T004 | ConditionEvaluator条件求值 | 条件表达式 | 求值结果 | 条件表达式正确解析，逻辑运算正确 | 1天 | ORCH-T003 | cangjie-coder |
| ORCH-T005 | ResultAggregator结果聚合 | 多步骤结果 | 聚合结果 | 冲突检测和解决正确，增量聚合正确 | 1天 | ORCH-T003 | cangjie-coder |
| ORCH-T006 | DynamicReplanner动态重编排 | 执行结果+调整请求 | 重编排后计划 | 运行时动态调整正确，重排序正确 | 1天 | ORCH-T003 | cangjie-coder |
| ORCH-T007 | ResourceArbiter资源仲裁 | 资源请求 | 资源分配结果 | 资源锁正确，配额限制正确，死锁检测 | 1天 | ORCH-T003 | cangjie-coder |
| ORCH-T008 | CRUD模块与API实现 | crudgen生成的CRUD | 扩展API | executePlan/pausePlan/replanPlan API正确 | 1天 | ORCH-T001 | cangjie-coder |
| ORCH-T009 | 与AgentTeams集成 | AgentTeams+DagScheduler | 集成模块 | Manager通过DagScheduler调度TeamLeader | 1天 | ORCH-T003, P0-1 | cangjie-coder |
| ORCH-T010 | 集成测试与验证 | 全部组件 | 测试报告+Demo | 所有测试通过，DAG调度正确 | 0.5天 | ORCH-T001~T009 | Python测试脚本 |

**仓颉规范合规性要求**:
- [ ] DagScheduler类添加`public`修饰符
- [ ] schedule方法返回值改用`Option<Unit>`或`APIResult<Unit>`
- [ ] PlantUML数据模型中`JsonObject`改为`JsonValue`
- [ ] PO类补充`@DataAssist[fields]`和`@QueryMappersGenerator`注解
- [ ] DAO接口使用`@DAO`注解并继承`RootDAO`
- [ ] Service方法返回`APIResult<T>`

---

### 3.3 P0-3: 执行证据链与审计系统

**工程目录**: `execution-audit` | **预估工时**: 7天 | **对标维度**: 工程落地(20%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| EA-T001 | 数据库表设计与创建 | design.md数据模型 | DDL脚本+CRUD骨架 | execution_evidences/verification_evidences表创建成功 | 0.5天 | 无 | DDL生成→人工变更→CRUD生成 |
| EA-T002 | ExecutionEvidenceRecorder核心实现 | Agent执行事件 | 执行证据记录 | 每个步骤有证据，包含时间戳/AgentID/输入输出/耗时 | 1.5天 | EA-T001 | cangjie-coder |
| EA-T003 | SideEffectTracker副作用追踪 | 工具调用事件 | 副作用记录 | 文件修改/数据库变更/API调用副作用正确追踪 | 1天 | EA-T002 | cangjie-coder |
| EA-T004 | AuditHashChain哈希链校验 | 证据记录 | 完整性校验结果 | 哈希链正确计算，篡改检测正确 | 0.5天 | EA-T002 | cangjie-coder |
| EA-T005 | VerificationEvidenceCollector验证证据 | 验证操作结果 | 验证证据记录 | 编译/测试/业务规则验证正确记录，被动设计 | 1天 | EA-T001 | cangjie-coder |
| EA-T006 | CRUD模块与API实现 | crudgen生成的CRUD | 扩展API | 按会话查询/执行回放/聚合查询API正确 | 1天 | EA-T001 | cangjie-coder |
| EA-T007 | 与AgentTeams/EventHandler集成 | AgentTeams+EventHandler | 集成模块 | 执行过程自动记录证据，WebSocket推送正确 | 0.5天 | EA-T002, P0-1 | cangjie-coder |
| EA-T008 | 集成测试与验证 | 全部组件 | 测试报告 | 证据链完整性校验通过，副作用追踪正确 | 1天 | EA-T001~T007 | Python测试脚本 |

**仓颉规范合规性要求**:
- [ ] ExecutionEvidenceRecorder和VerificationEvidenceCollector类添加`public`修饰符
- [ ] `verifyIntegrity`返回值改用`Option<Bool>`
- [ ] `SideEffect`改用`struct`（值类型语义）
- [ ] PlantUML数据模型中`JsonObject`改为`JsonValue`
- [ ] PO类补充`@DataAssist[fields]`和`@QueryMappersGenerator`注解

---

### 3.4 P0-4: 技能组合引擎

**工程目录**: `skill-composition-engine` | **预估工时**: 9天 | **对标维度**: Skill工程(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| SCE-T001 | 数据库表设计与创建 | design.md数据模型 | DDL脚本+CRUD骨架 | skill_compositions/composition_executions表创建成功 | 0.5天 | 无 | DDL生成→人工变更→CRUD生成 |
| SCE-T002 | CompositionYamlParser解析器 | COMPOSITION.yaml | CompositionDefinition对象 | YAML正确解析，嵌套组合正确处理 | 1天 | 无 | cangjie-coder |
| SCE-T003 | SkillOutput标准化与InputMapper | 技能输出+映射表达式 | 映射后的输入 | SkillOutput格式标准化，映射表达式正确解析 | 1天 | 无 | cangjie-coder |
| SCE-T004 | CompositionExecutor执行引擎 | CompositionDefinition | 执行结果 | 串行/并行/条件分支执行正确，缓存机制正确 | 2天 | SCE-T002,T003 | cangjie-coder |
| SCE-T005 | DependencyResolver依赖解析 | SKILL.md dependencies字段 | 依赖加载顺序 | 依赖正确解析，循环依赖检测，按顺序加载 | 1天 | SCE-T002 | cangjie-coder |
| SCE-T006 | CompositionValidator组合验证 | CompositionDefinition | 验证结果 | 技能存在性/循环依赖/类型兼容性验证正确 | 0.5天 | SCE-T005 | cangjie-coder |
| SCE-T007 | CompositionTemplateManager模板管理 | 模板YAML | 组合实例 | 内置模板可实例化，自定义模板可加载 | 1天 | SCE-T002 | cangjie-coder |
| SCE-T008 | CRUD模块与API实现 | crudgen生成的CRUD | 扩展API | 组合执行API正确工作 | 1天 | SCE-T001 | cangjie-coder |
| SCE-T009 | 集成测试与验证 | 全部组件 | 测试报告 | code-gen-optimize模板可正确执行 | 1天 | SCE-T001~T008 | Python测试脚本 |

**仓颉规范合规性要求**:
- [ ] CompositionExecutor和InputMapper类添加`public`修饰符
- [ ] `resolveExpression`返回值改用`Option<JsonValue>`
- [ ] 补充`import std.collection.HashMap`

---

### 3.5 P0-5: cangjie-coder agents子目录完善

**工程目录**: `cangjie-coder-agents` | **预估工时**: 4天 | **对标维度**: Skill工程(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| CCA-T001 | 创建agents子目录和4个subagent定义 | skill-creator agents模式 | 4个.md文件 | agents/目录包含doc-consultant/code-searcher/code-editor/code-verifier | 1天 | 无 | Markdown编写 |
| CCA-T002 | 更新SKILL.md为编排器模式 | 现有SKILL.md | 更新后SKILL.md | 编排流程清晰定义，自动修复闭环逻辑描述 | 0.5天 | CCA-T001 | Markdown编写 |
| CCA-T003 | 创建scripts子目录和4个Python脚本 | 脚本需求 | 4个.py文件 | cangjie_compile.py可调用cjpm build，脚本输出JSON | 1天 | 无 | Python脚本编写 |
| CCA-T004 | 创建references子目录和文档索引 | CangjieSkills文档 | 2个.md文件 | 语言指南索引正确指向CangjieSkills，代码模式库完整 | 0.5天 | 无 | Markdown编写 |
| CCA-T005 | 自动修复闭环实现与测试 | 全部组件 | 测试报告 | 四个subagent正确协作，验证失败时自动修复闭环工作 | 1天 | CCA-T001,T002 | 集成测试 |

**备注**: 本工程不涉及仓颉代码编写和数据库变更，主要是YAML/Markdown/Python脚本

---

### 3.6 P0-6: 代码生成工具Skills化封装

**工程目录**: `code-gen-skills` | **预估工时**: 4天 | **对标维度**: Skill工程(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| CGS-T001 | 更新crud-generator SKILL.md | 现有SKILL.md | v2.0.0 SKILL.md | 包含inputs/outputs定义，依赖声明正确 | 0.5天 | 无 | Markdown编写 |
| CGS-T002 | 创建loaddbinfo SKILL.md | LoadDbInfoService API | SKILL.md | 技能可通过SKILL.md加载，输入输出定义正确 | 0.5天 | 无 | Markdown编写 |
| CGS-T003 | 创建code-gen-optimize COMPOSITION.yaml | 技能组合模板需求 | COMPOSITION.yaml | 格式正确，可被CompositionYamlParser解析 | 0.5天 | CGS-T001,T002 | YAML编写 |
| CGS-T004 | 创建code-gen-verifier技能 | 验证需求 | SKILL.md+验证逻辑 | 技能可加载，编译验证正确工作 | 1天 | 无 | cangjie-coder |
| CGS-T005 | 代码生成闭环验证实现 | 验证+修复需求 | 闭环逻辑 | 验证失败时自动反馈，修复闭环正确工作 | 1天 | CGS-T004 | cangjie-coder |
| CGS-T006 | 与SkillToToolAdapter集成测试 | 全部组件 | 测试报告 | 技能可通过SkillToToolAdapter调用 | 0.5天 | CGS-T001~T005 | Python测试脚本 |

---

### 3.7 P0-7: SDD规范驱动开发技能集

**工程目录**: `sdd-skills` | **预估工时**: 3天 | **对标维度**: 场景价值(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| SDD-T001 | 创建sdd-spec技能 | SpecAgent需求 | SKILL.md | 技能可加载，输入输出定义正确 | 0.5天 | 无 | Markdown编写 |
| SDD-T002 | 创建sdd-design技能 | DesignAgent需求 | SKILL.md | 技能可加载 | 0.5天 | 无 | Markdown编写 |
| SDD-T003 | 创建sdd-task技能 | TaskAgent需求 | SKILL.md | 技能可加载 | 0.5天 | 无 | Markdown编写 |
| SDD-T004 | 创建sdd-test技能 | TestAgent需求 | SKILL.md | 技能可加载 | 0.5天 | 无 | Markdown编写 |
| SDD-T005 | 创建sdd-flow组合模板 | SDD流程需求 | SKILL.md+COMPOSITION.yaml | 5步流程定义正确，可解析 | 0.5天 | SDD-T001~T004 | YAML编写 |
| SDD-T006 | 与AgentTeams集成测试 | AgentTeams+SDD技能 | 测试报告 | SDD流程在AgentTeams架构中正确执行 | 0.5天 | SDD-T005, P0-1 | Python测试脚本 |

---

### 3.8 P0-8: 全栈代码生成闭环

**工程目录**: `fullstack-codegen` | **预估工时**: 3天 | **对标维度**: 场景价值(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| FSC-T001 | 创建fullstack-codegen组合模板 | 全栈闭环需求 | SKILL.md+COMPOSITION.yaml | 6步流程定义正确，可解析 | 0.5天 | P0-6 | YAML编写 |
| FSC-T002 | 实现ModelSyncAdapter前后端同构 | PO.cj文件 | 前端ORM模型 | 字段类型映射正确，验证规则同步正确 | 1天 | 无 | cangjie-coder |
| FSC-T003 | 增强AutoCreateCode增量生成 | 现有crudgen模板 | 增强后模板引擎 | 增量生成不覆盖自定义代码 | 0.5天 | 无 | cangjie-coder |
| FSC-T004 | 构建验证闭环集成 | code-gen-verifier | 集成模块 | 代码生成后自动构建验证，失败自动反馈 | 0.5天 | P0-6 | cangjie-coder |
| FSC-T005 | 端到端集成测试 | 全部组件 | 测试报告 | loaddbinfo→crudgen→crudweb闭环可自动执行 | 0.5天 | FSC-T001~T004 | Python测试脚本 |

---

### 3.9 P0-9: AI驱动开发全流程Demo场景

**工程目录**: `ai-dev-demo` | **预估工时**: 5天 | **对标维度**: 场景价值(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| DEM-T001 | 创建demo-team.yaml团队配置 | Demo场景需求 | demo-team.yaml | 4个Agent角色和技能定义完整 | 0.5天 | P0-1 | YAML编写 |
| DEM-T002 | 创建Demo入口API | API需求 | DemoController | start/status/evidences API正确 | 1天 | DEM-T001 | cangjie-coder |
| DEM-T003 | Demo执行流程编排 | DAG需求 | demo-orchestration.yaml | DAG执行计划可正确调度 | 1天 | DEM-T001, P0-2 | YAML编写 |
| DEM-T004 | Demo前端展示页面 | 前端需求 | Vue 3页面 | 启动/状态/证据页面可正常使用 | 1.5天 | DEM-T002 | Vue 3+OpenTiny |
| DEM-T005 | Demo稳定性测试 | 全部组件 | 测试报告+视频 | Demo可重复运行，结果一致 | 1天 | DEM-T001~T004 | Python测试脚本 |

---

## 4. P1增强工程编码任务

### 4.1 P1-1: Agent间上下文传递与结果验证

**工程目录**: `agent-context-verify` | **预估工时**: 3天 | **对标维度**: 多Agent协同(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| ACV-T001 | 定义AgentContext标准化对象 | 上下文传递需求 | AgentContext数据类 | 包含任务描述/输入数据/约束条件 | 0.5天 | P0-1, P0-2 | cangjie-coder |
| ACV-T002 | 实现ContextPass协同技能 | 协同技能需求 | context-pass SKILL.md | Agent间上下文通过标准化对象正确传递 | 0.5天 | ACV-T001 | Markdown编写 |
| ACV-T003 | 实现ResultValidator结果验证框架 | 验证规则需求 | ResultValidator类 | 执行结果按验证规则自动校验 | 1天 | ACV-T001 | cangjie-coder |
| ACV-T004 | 实现ResultMerge协同技能 | 结果聚合需求 | result-merge SKILL.md | 多Agent结果正确聚合 | 0.5天 | ACV-T003 | Markdown编写 |
| ACV-T005 | 集成测试 | 全部组件 | 测试报告 | 上下文传递和结果验证正确 | 0.5天 | ACV-T001~T004 | Python测试脚本 |

---

### 4.2 P1-2: 记忆持久化与跨会话共享

**工程目录**: `agent-memory-persistence` | **预估工时**: 6天 | **对标维度**: 多Agent协同(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| MEM-T001 | 数据库表设计与创建 | design.md数据模型 | DDL脚本+CRUD骨架 | agent_memories表创建成功，含embedding字段 | 0.5天 | 无 | DDL生成→人工变更→CRUD生成 |
| MEM-T002 | AgentMemoryService核心实现 | 记忆CRUD需求 | AgentMemoryService类 | 记忆正确持久化到数据库 | 1.5天 | MEM-T001 | cangjie-coder |
| MEM-T003 | MemoryLayerManager分层存储 | 四层记忆需求 | MemoryLayerManager类 | 四层记忆正确区分，衰减机制正确 | 1天 | MEM-T002 | cangjie-coder |
| MEM-T004 | SemanticMemorySearch语义检索 | 语义搜索需求 | 语义检索模块 | 语义检索返回相关性最高的记忆 | 1天 | MEM-T002 | cangjie-coder |
| MEM-T005 | MemorySharingManager共享管理 | 共享范围需求 | MemorySharingManager类 | private/shared/global三种共享范围正确隔离 | 0.5天 | MEM-T002 | cangjie-coder |
| MEM-T006 | CRUD模块与API实现 | crudgen生成的CRUD | 扩展API | 记忆查询API正确工作 | 1天 | MEM-T001 | cangjie-coder |
| MEM-T007 | 集成测试与验证 | 全部组件 | 测试报告 | 所有集成测试通过 | 0.5天 | MEM-T001~T006 | Python测试脚本 |

**仓颉规范合规性要求**:
- [ ] AgentMemoryService类添加`public`修饰符
- [ ] `retrieve`方法`limit`参数补充默认值`10`

---

### 4.3 P1-3: AgentLoop观测评估飞轮

**工程目录**: `agent-loop` | **预估工时**: 4天 | **对标维度**: 工程落地(20%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| AL-T001 | 全栈观测链路追踪 | 执行证据数据 | 观测仪表板数据 | Agent执行全链路可追踪 | 1天 | P0-3 | cangjie-coder |
| AL-T002 | 效果评估引擎 | 执行证据+指标 | 评估报告 | 成功率/耗时/Token消耗自动评估 | 1天 | AL-T001 | cangjie-coder |
| AL-T003 | 自进化调优策略 | 评估结果 | 策略调整建议 | 基于评估结果自动调整Agent策略 | 1天 | AL-T002 | cangjie-coder |
| AL-T004 | 可视化仪表板 | 观测数据 | Vue 3仪表板页面 | Agent运行状态/协作拓扑/Token消耗实时展示 | 1天 | AL-T001 | Vue 3+OpenTiny |

---

### 4.4 P1-4: 审批与回滚机制

**工程目录**: `approval-rollback` | **预估工时**: 3天 | **对标维度**: 工程落地(20%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| AR-T001 | 数据库表设计与创建 | 审批记录数据模型 | DDL脚本+CRUD骨架 | agent_approvals表创建成功 | 0.5天 | P0-3 | DDL生成→人工变更→CRUD生成 |
| AR-T002 | ApprovalService审批流程 | HITL事件 | 审批记录 | 高风险操作正确触发审批，审批记录持久化 | 1天 | AR-T001 | cangjie-coder |
| AR-T003 | RollbackManager执行回滚 | 副作用记录 | 回滚结果 | 编排失败时正确回滚已完成步骤 | 1天 | AR-T001 | cangjie-coder |
| AR-T004 | 集成测试 | 全部组件 | 测试报告 | 审批和回滚正确工作 | 0.5天 | AR-T001~T003 | Python测试脚本 |

---

### 4.5 P1-5: 专用语言多Skills编排协作

**工程目录**: `language-skills-orchestration` | **预估工时**: 5天 | **对标维度**: 多Agent协同(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| LSO-T001 | 编排协作引擎核心 | 编排需求 | OrchestratorEngine类 | 根据编程语言自动选择技能集 | 1.5天 | P0-5, P0-4 | cangjie-coder |
| LSO-T002 | 语言上下文注入机制 | 语言文档 | 上下文注入模块 | 自动加载编程语言资料和规范 | 1天 | LSO-T001 | cangjie-coder |
| LSO-T003 | 跨语言协作支持 | 多语言需求 | 跨语言编排模块 | 仓颉后端+Vue前端跨语言协作正确 | 1天 | LSO-T001 | cangjie-coder |
| LSO-T004 | Agent subagent配置增强 | OpenClaude借鉴 | 增强后subagent | 支持type/model/background配置 | 1天 | LSO-T001 | cangjie-coder |
| LSO-T005 | 集成测试 | 全部组件 | 测试报告 | 编排协作引擎正确工作 | 0.5天 | LSO-T001~T004 | Python测试脚本 |

---

### 4.6 P1-6: 技能自进化闭环

**工程目录**: `skill-evolution` | **预估工时**: 6天 | **对标维度**: Skill工程(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| SE-T001 | 技能使用追踪 | operate_log数据 | 使用统计 | 技能使用次数/查看次数/修改次数正确统计 | 1天 | P0-4 | cangjie-coder |
| SE-T002 | SkillCurator技能策展人 | Hermes Curator借鉴 | SkillCurator技能 | 定期审查Agent创建的技能 | 1.5天 | SE-T001 | cangjie-coder+Markdown |
| SE-T003 | 技能状态流转 | 使用频率数据 | 状态管理 | active→stale→archived自动转换 | 1天 | SE-T001 | cangjie-coder |
| SE-T004 | 技能脚本动态生成 | SKILL.md scripts声明 | 动态生成脚本 | 首次使用时自动生成声明的脚本 | 1.5天 | P0-5 | cangjie-coder |
| SE-T005 | 集成测试 | 全部组件 | 测试报告 | 自进化闭环正确工作 | 1天 | SE-T001~T004 | Python测试脚本 |

---

### 4.7 P1-7: 协同技能集与Kanban

**工程目录**: `collaboration-skills` | **预估工时**: 7天 | **对标维度**: 多Agent协同(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| CS-T001 | 创建task-decompose协同技能 | 任务分解需求 | SKILL.md | 复杂任务分解为子任务DAG | 0.5天 | P0-1 | Markdown编写 |
| CS-T002 | 创建agent-select协同技能 | Agent选择需求 | SKILL.md | 根据子任务选择合适Agent | 0.5天 | P0-1 | Markdown编写 |
| CS-T003 | 创建conflict-resolve协同技能 | 冲突解决需求 | SKILL.md | Agent间执行冲突正确解决 | 0.5天 | P0-1 | Markdown编写 |
| CS-T004 | 创建handover协同技能 | 移交需求 | SKILL.md | 控制权正确移交给另一个Agent | 0.5天 | P0-1 | Markdown编写 |
| CS-T005 | Agent Kanban任务队列 | Hermes Kanban借鉴 | Kanban模块 | 任务分配/认领/完成/阻塞正确 | 2天 | P0-1 | cangjie-coder |
| CS-T006 | Kanban数据库表设计与创建 | 数据模型 | DDL脚本+CRUD骨架 | agent_kanban_tasks表创建成功 | 0.5天 | CS-T005 | DDL生成→人工变更→CRUD生成 |
| CS-T007 | Kanban API与集成 | CRUD骨架 | 扩展API | Kanban API正确工作 | 1天 | CS-T006 | cangjie-coder |
| CS-T008 | 集成测试 | 全部组件 | 测试报告 | 协同技能和Kanban正确工作 | 1.5天 | CS-T001~T007 | Python测试脚本 |

---

### 4.8 P1-8: 测试脚本动态生成

**工程目录**: `test-generator` | **预估工时**: 3天 | **对标维度**: 工程落地(20%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| TG-T001 | 创建test-generator技能目录 | 测试需求 | SKILL.md+agents/ | 技能可加载，3个subagent定义完整 | 0.5天 | P0-5 | Markdown编写 |
| TG-T002 | 创建scripts子目录和测试脚本 | 脚本需求 | 3个.py文件 | run_python_test.py/run_js_test.js/parse_test_result.py正确 | 1天 | 无 | Python/JS脚本编写 |
| TG-T003 | 测试生成闭环实现 | 验证+修复需求 | 闭环逻辑 | 测试失败时反馈到代码修复闭环 | 1天 | TG-T001 | cangjie-coder |
| TG-T004 | 集成测试 | 全部组件 | 测试报告 | API/数据库/前端测试正确生成和执行 | 0.5天 | TG-T001~T003 | Python测试脚本 |

---

## 5. P2锦上添花工程编码任务

### 5.1 P2-1: 错误恢复与自愈系统

**工程目录**: `agent-error-recovery` | **预估工时**: 4天 | **对标维度**: 工程落地(20%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| AER-T001 | ErrorClassifier错误分类 | 异常对象 | ErrorCategory | 四级分类正确（transient/recoverable/degradable/fatal） | 1天 | P0-3 | cangjie-coder |
| AER-T002 | SmartRetry智能重试 | 错误类型 | 重试结果 | 根据错误类型选择正确重试策略 | 1天 | AER-T001 | cangjie-coder |
| AER-T003 | CircuitBreaker熔断器 | 失败计数 | 熔断状态 | 连续失败时正确熔断和恢复 | 1天 | AER-T001 | cangjie-coder |
| AER-T004 | DegradedExecutor降级执行 | 降级策略 | 降级结果 | Agent/技能不可用时正确降级 | 0.5天 | AER-T001 | cangjie-coder |
| AER-T005 | 集成测试 | 全部组件 | 测试报告 | 错误恢复和自愈正确工作 | 0.5天 | AER-T001~T004 | Python测试脚本 |

**仓颉规范合规性要求**:
- [ ] ErrorClassifier和CircuitBreaker类添加`public`修饰符
- [ ] `classify`方法返回值改用`Option<ErrorCategory>`

---

### 5.2 P2-2: 开源计划与社区建设

**工程目录**: `open-source-plan` | **预估工时**: 1天 | **对标维度**: 开源贡献(5%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| OSP-T001 | 编写ROADMAP.md | 项目规划 | ROADMAP.md | 版本规划和功能路线图完整 | 0.5天 | 无 | Markdown编写 |
| OSP-T002 | 编写CONTRIBUTING.md | 贡献指南需求 | CONTRIBUTING.md | 可指导新贡献者搭建开发环境 | 0.5天 | 无 | Markdown编写 |

---

### 5.3 P2-3: 记忆提供者插件体系

**工程目录**: `memory-provider` | **预估工时**: 4天 | **对标维度**: 多Agent协同(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| MP-T001 | 定义MemoryProvider接口 | Hermes MemoryProvider ABC | 仓颉protocol | 接口定义完整，生命周期方法正确 | 1天 | P1-2 | cangjie-coder |
| MP-T002 | 实现BuiltinProvider | 现有MEMORY.md/SOUL.md | BuiltinProvider类 | 基于现有文件的记忆提供正确 | 1天 | MP-T001 | cangjie-coder |
| MP-T003 | 实现PostgresProvider | Fountain ORM | PostgresProvider类 | 基于数据库的记忆提供正确 | 1天 | MP-T001 | cangjie-coder |
| MP-T004 | 集成测试 | 全部组件 | 测试报告 | 提供者切换正确，数据一致 | 1天 | MP-T001~T003 | Python测试脚本 |

---

### 5.4 P2-4: 上下文优化引擎

**工程目录**: `context-optimization` | **预估工时**: 6天 | **对标维度**: 工程落地(20%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| CO-T001 | 多层压缩管道 | Claude Code 5层压缩 | 压缩管道模块 | 5层压缩正确执行 | 2天 | 无 | cangjie-coder |
| CO-T002 | 提示缓存机制 | Hermes prompt caching | 缓存模块 | 对话级缓存正确，sacred缓存不被清除 | 2天 | 无 | cangjie-coder |
| CO-T003 | 集成测试 | 全部组件 | 测试报告 | 压缩和缓存正确工作 | 2天 | CO-T001,T002 | Python测试脚本 |

---

### 5.5 P2-5: Agent智能增强

**工程目录**: `agent-intelligence` | **预估工时**: 6天 | **对标维度**: Skill工程(25%)

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| AI-T001 | RepoMap代码库智能 | OpenClaude RepoMap | RepoMap模块 | 代码库结构正确分析，PageRank排序正确 | 2天 | P1-5 | cangjie-coder |
| AI-T002 | Agent动态生成能力 | OpenCode Agent.generate | 动态生成模块 | 根据任务描述正确生成Agent配置 | 2天 | P1-5 | cangjie-coder |
| AI-T003 | 集成测试 | 全部组件 | 测试报告 | RepoMap和动态生成正确工作 | 2天 | AI-T001,T002 | Python测试脚本 |

---

## 6. 数据库变更任务汇总

所有涉及数据库变更的工程及其DDL任务：

| 工程 | 新增表 | DDL文件位置 | CRUD生成 | 优先级 |
|------|--------|-----------|---------|--------|
| P0-1 agent-teams | agent_teams, agent_team_members | sql/incremental/agent_teams.sql | AgentTeamPO, AgentTeamMemberPO | P0 |
| P0-2 agent-orchestration | orchestration_plans, orchestration_steps | sql/incremental/orchestration.sql | OrchestrationPlanPO, OrchestrationStepPO | P0 |
| P0-3 execution-audit | execution_evidences, verification_evidences | sql/incremental/execution_audit.sql | ExecutionEvidencePO, VerificationEvidencePO | P0 |
| P0-4 skill-composition-engine | skill_compositions, composition_executions | sql/incremental/skill_composition.sql | SkillCompositionPO, CompositionExecutionPO | P0 |
| P1-2 agent-memory-persistence | agent_memories(含VECTOR) | sql/incremental/agent_memories.sql | AgentMemoryPO | P1 |
| P1-4 approval-rollback | agent_approvals | sql/incremental/approval_rollback.sql | AgentApprovalPO | P1 |
| P1-7 collaboration-skills | agent_kanban_tasks | sql/incremental/agent_kanban.sql | AgentKanbanTaskPO | P1 |

**数据库变更标准流程**:
1. **[自动化]** 在 `sql/incremental/` 目录生成数据库DDL脚本
2. **[人工操作]** 通知人工执行数据库变更（执行DDL）
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表，使用 `crudgen` 生成标准CRUD模块（Model/DAO/Service/Controller/Route），使用 `crudweb` 生成Web管理界面
4. **[自动化]** 基于生成的CRUD模块进行迭代开发（定制代码写在 `//#region AutoCreateCode` 区域外）

---

## 7. 仓颉规范合规性修复任务

基于cangjie-compliance-review.md的复核结果，需要在编码过程中同步修复的规范问题：

| 优先级 | 工程 | 修复项 | 影响范围 |
|--------|------|--------|---------|
| P0 | agent-teams | 添加public修饰符；方法返回值改用Option/APIResult；JsonObject→JsonValue；补充PO/DAO/Service规范说明 | TeamManager, TeamMessenger, PO/DAO/Service |
| P0 | agent-orchestration | 添加public修饰符；方法返回值改用Option/APIResult；JsonObject→JsonValue；补充PO/DAO/Service规范说明 | DagScheduler, PO/DAO/Service |
| P0 | execution-audit | 添加public修饰符；verifyIntegrity改用Option<Bool>；SideEffect改struct；补充PO/DAO/Service规范说明 | ExecutionEvidenceRecorder, VerificationEvidenceCollector |
| P1 | skill-composition-engine | 添加public修饰符；resolveExpression改用Option<JsonValue> | CompositionExecutor, InputMapper |
| P1 | agent-memory-persistence | 添加public修饰符；limit默认参数值 | AgentMemoryService |
| P1 | agent-error-recovery | 添加public修饰符；classify改用Option<ErrorCategory> | ErrorClassifier, CircuitBreaker |

**跨文档共性问题修复清单**:
- [x] 所有类声明添加`public`修饰符（需被继承的添加`open public`）
- [x] 可能失败的方法返回值改用`Option<T>`（DAO层）或`APIResult<T>`（Service层）
- [x] PlantUML数据模型中`JsonObject`统一改为`JsonValue`
- [x] PO类补充`@DataAssist[fields]`和`@QueryMappersGenerator`注解
- [x] DAO接口使用`@DAO`注解并继承`RootDAO`
- [x] Service方法统一返回`APIResult<T>`
- [x] 值类型数据载体使用`struct`而非`class`
- [x] 补充标准包名和import说明

---

## 8. 开发路线图与里程碑

### 8.1 阶段一：初赛准备（7月23日 - 8月16日）

| 日期 | 任务 | 交付物 | 状态 |
|------|------|--------|------|
| 7/23-7/24 | 完成全部P0设计文档和编码任务规划 | design.md + coding-task-plan.md | ✅ 已完成 |
| 7/25-7/28 | 制作初赛PPT | 方案PPT | 待开始 |
| 7/29-8/2 | 完成P1关键工程设计文档 | P1 design.md | ✅ 已完成 |
| 8/3-8/10 | P0工程预开发（数据库DDL、CRUD骨架） | DDL脚本+CRUD代码 | ✅ 已完成 |
| 8/11-8/16 | PPT优化和初赛提交 | 最终版PPT | 待开始 |

### 8.2 阶段二：核心功能开发（8月17日 - 9月3日）

#### 第1周（8/17-8/23）：基础设施层

| 日期 | 并行任务 | 交付物 |
|------|---------|--------|
| 8/17-8/18 | AT-T001 数据库DDL + AT-T002 YAML解析器 | DDL脚本+TeamConfig解析器 |
| 8/19-8/20 | AT-T003 ManagerGroup核心 + SCE-T002 CompositionYamlParser | ManagerGroup+组合解析器 |
| 8/21-8/22 | AT-T004 TeamMessenger + SCE-T003 SkillOutput+InputMapper | 消息传递+输入映射 |
| 8/23 | AT-T005 TeamManager + CCA-T001~T003 cangjie-coder agents | 生命周期管理+agents子目录 |

**本周并行**: P0-1(agent-teams) + P0-4(skill-composition-engine) + P0-5(cangjie-coder-agents) + P0-6(code-gen-skills)

#### 第2周（8/24-8/30）：编排与审计层

| 日期 | 并行任务 | 交付物 |
|------|---------|--------|
| 8/24-8/25 | ORCH-T001 DDL + ORCH-T003 DagScheduler + EA-T001 DDL + EA-T002 EvidenceRecorder | DDL+调度引擎+证据记录器 |
| 8/26-8/27 | ORCH-T004 ConditionEvaluator + EA-T003 SideEffectTracker + EA-T004 AuditHashChain | 条件求值+副作用追踪+哈希链 |
| 8/28-8/29 | ORCH-T005 ResultAggregator + EA-T005 VerificationEvidence + SCE-T004 CompositionExecutor | 结果聚合+验证证据+组合执行器 |
| 8/30 | ORCH-T008 CRUD API + EA-T006 CRUD API + SCE-T005 DependencyResolver | API实现+依赖解析 |

**本周并行**: P0-2(agent-orchestration) + P0-3(execution-audit) + P0-4(skill-composition-engine收尾)

#### 第3周（8/31-9/3）：Demo集成层（复赛冲刺）

| 日期 | 并行任务 | 交付物 |
|------|---------|--------|
| 8/31 | ORCH-T009 AgentTeams集成 + AT-T006 DSL扩展 + AT-T007 CRUD API | 集成模块+DSL+API |
| 9/1 | SDD-T001~T005 SDD技能集 + FSC-T001~T003 全栈代码生成 | SDD技能+全栈闭环 |
| 9/2 | DEM-T001~T003 Demo配置+API+编排 | Demo核心功能 |
| 9/3 | DEM-T004~T005 Demo前端+稳定性测试 | **复赛提交** |

**本周并行**: P0-7(sdd-skills) + P0-8(fullstack-codegen) + P0-9(ai-dev-demo)

### 8.3 阶段三：决赛准备（9月4日 - 9月22日）

| 周次 | 任务 | 交付物 |
|------|------|--------|
| 第4周(9/4-9/10) | P1-1~P1-4: 上下文传递+记忆持久化+AgentLoop+审批回滚 | P1核心功能 |
| 第5周(9/11-9/17) | P1-5~P1-8: 编排协作+技能自进化+协同技能+测试生成 | P1增强功能 |
| 第6周(9/18-9/22) | Demo优化+答辩PPT+视频录制 | **决赛答辩** |

---

## 9. 关键路径与风险分析

### 9.1 关键路径

```
P0-1 AgentTeams(5天) → P0-2 DAG编排(5天) → P0-7 SDD技能(3天) → P0-9 Demo(5天)
                                                                    ↑
P0-5 cangjie-coder(4天) → P0-8 全栈代码生成(3天) ──────────────────┘
```

**关键路径总工时**: 18天（需在12个工作日内完成，8/17-9/3）

**并行策略**: 批次1的4个工程并行开发，可将关键路径缩短

### 9.2 风险矩阵

| 风险 | 影响 | 概率 | 缓解措施 | 负责人 |
|------|------|------|---------|--------|
| 🔴 DAG编排引擎实现复杂 | 可能延期2-3天 | 高 | 先实现简化版MVP（仅串行+并行），条件分支和动态重编排延后 | 开发团队 |
| 🔴 多Agent协作调试困难 | 开发效率受限 | 高 | 完善日志和观测系统，EA-T002证据记录器优先实现 | 开发团队 |
| 🟡 Demo稳定性不足 | 答辩演示风险 | 中 | 提前录制Demo视频作为备份，DEM-T005稳定性测试充分 | Demo负责人 |
| 🟡 仓颉语言生态不够成熟 | 开发效率受限 | 中 | 复用已有基础设施，cangjie-coder技能辅助开发 | 开发团队 |
| 🟡 全栈代码生成质量不足 | Demo效果不佳 | 中 | cangjie-coder二次优化，验证证据账本检查 | 代码生成负责人 |
| 🟢 协同技能AI推理不稳定 | 协同效果不可控 | 中 | 保持关键路径确定性，AI推理仅用于非关键决策 | 协同技能负责人 |
| 🟢 技能自进化误操作 | 归档有用技能 | 低 | 参照Hermes：永不自动删除，只归档，Pinned技能豁免 | 技能进化负责人 |

### 9.3 应急预案

| 场景 | 应急措施 |
|------|---------|
| 复赛前P0工程未全部完成 | 优先保障P0-1(AgentTeams)+P0-9(Demo)，其余P0工程提供基础功能即可 |
| Demo运行不稳定 | 录制Demo视频+准备静态演示页面，答辩时优先播放视频 |
| DAG编排引擎延期 | 使用简化版DAG（仅支持串行+并行），条件分支和动态重编排标记为P1 |
| 数据库变更阻塞 | 先使用内存数据结构开发核心逻辑，数据库持久化后置 |

---

## 10. 编码规范与开发流程

### 10.1 仓颉代码开发规范

1. **所有仓颉代码(.cj文件)的编写必须使用cangjie-coder技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
2. 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
3. 仓颉代码必须符合CangjieMagic框架和V4模块的约定和模式
4. 数据库列名使用snake_case，仓颉代码使用camelCase
5. crudgen生成的代码写在`//#region AutoCreateCode`区域内，增量开发代码写在该区域外
6. 所有对外类使用`public class`，需被继承的使用`open public class`
7. DAO层方法返回`Option<T>`，Service层方法返回`APIResult<T>`
8. PO类使用`@DataAssist[fields]`和`@QueryMappersGenerator`注解
9. DAO接口使用`@DAO`注解并继承`RootDAO`
10. JSONB字段对应`JsonValue`类型（非`JsonObject`）

### 10.2 数据库变更流程

1. **[自动化]** 在`sql/incremental/`目录生成数据库DDL脚本
2. **[人工操作]** 通知人工执行数据库变更（执行DDL）
3. **[人工操作]** 人工使用`loaddbinfo`刷新db_info表，使用`crudgen`生成标准CRUD模块，使用`crudweb`生成Web管理界面
4. **[自动化]** 基于生成的CRUD模块进行迭代开发

### 10.3 技能开发规范

1. 技能定义使用SKILL.md格式，包含YAML frontmatter
2. 技能输入输出使用标准化的inputs/outputs字段
3. 技能依赖使用dependencies字段声明
4. 组合模板使用COMPOSITION.yaml格式
5. subagent定义放在技能的agents/子目录
6. 确定性脚本放在技能的scripts/子目录（Python优先）
7. 参考文档放在技能的references/子目录

### 10.4 测试规范

1. 集成测试使用Python编写（pytest框架）
2. API测试使用requests库
3. 数据库测试使用psycopg2库
4. 前端测试使用Playwright
5. 测试脚本放在各工程的tests/目录

---

## 11. 任务统计

### 11.1 按优先级统计

| 优先级 | 工程数 | 任务数 | 总工时 | 数据库变更 | 仓颉代码 | 技能/模板 |
|--------|--------|--------|--------|-----------|---------|----------|
| P0 | 9 | 56 | 40天 | 4个工程7张表 | 28个任务 | 15个任务 |
| P1 | 8 | 38 | 34天 | 3个工程3张表 | 18个任务 | 12个任务 |
| P2 | 5 | 15 | 18天 | 0 | 9个任务 | 2个任务 |
| **合计** | **22** | **109** | **92天** | **7个工程10张表** | **55个任务** | **29个任务** |

### 11.2 按技能要求统计

| 技能要求 | 任务数 | 占比 |
|---------|--------|------|
| cangjie-coder（仓颉代码编写） | 55 | 50.5% |
| Markdown/YAML编写 | 29 | 26.6% |
| Python测试脚本 | 22 | 20.2% |
| DDL生成→人工变更→CRUD生成 | 7 | 6.4% |

### 11.3 按对标维度统计

| 对标维度 | 覆盖工程 | 覆盖任务 | 权重 |
|---------|---------|---------|------|
| 多Agent协同与自主闭环能力 | 8个 | 42个 | 25% |
| Skill工程体系与生态复用 | 6个 | 28个 | 25% |
| 场景价值与行业可复制性 | 4个 | 16个 | 25% |
| 工程落地与运行验证及安全审计 | 6个 | 25个 | 20% |
| 开放与开源贡献 | 1个 | 2个 | 5% |

---

## 12. 附录

### 12.1 工程文档索引

| 工程 | spec.md | design.md | tasks.md | 状态 |
|------|---------|-----------|----------|------|
| P0-1 agent-teams | ✅ | ✅ | ✅ | ✅ 已完成 |
| P0-2 agent-orchestration | ✅ | ✅ | ✅ | ✅ 已完成 |
| P0-3 execution-audit | ✅ | ✅ | ✅ | ✅ 已完成 |
| P0-4 skill-composition-engine | ✅ | ✅ | ✅ | ✅ 已完成 |
| P0-5 cangjie-coder-agents | ✅ | ✅ | ✅ | ✅ 已完成 |
| P0-6 code-gen-skills | ✅ | ✅ | ✅ | ✅ 已完成 |
| P0-7 sdd-skills | ✅ | ✅ | ✅ | ✅ 已完成 |
| P0-8 fullstack-codegen | ✅ | ✅ | ✅ | ✅ 已完成 |
| P0-9 ai-dev-demo | ✅ | ✅ | ✅ | ✅ 已完成 |
| P1-1 agent-context-verify | ✅ | ✅ | ✅ | ✅ 已完成 |
| P1-2 agent-memory-persistence | ✅ | ✅ | ✅ | ✅ 已完成 |
| P1-3 agent-loop | ✅ | ✅ | ✅ | ✅ 已完成 |
| P1-4 approval-rollback | ✅ | ✅ | ✅ | ✅ 已完成 |
| P1-5 language-skills-orchestration | ✅ | ✅ | ✅ | ✅ 已完成 |
| P1-6 skill-evolution | ✅ | ✅ | ✅ | ✅ 已完成 |
| P1-7 collaboration-skills | ✅ | ✅ | ✅ | ✅ 已完成 |
| P1-8 test-generator | ✅ | ✅ | ✅ | ✅ 已完成 |
| P2-1 agent-error-recovery | ✅ | ✅ | ✅ | ✅ 已完成 |
| P2-2 open-source-plan | ✅ | ✅ | ✅ | ✅ 已完成 |
| P2-3 memory-provider | ✅ | ✅ | ✅ | ✅ 已完成 |
| P2-4 context-optimization | ✅ | ✅ | ✅ | ✅ 已完成 |
| P2-5 agent-intelligence | ✅ | ✅ | ✅ | ✅ 已完成 |

### 12.2 需求覆盖验证

| 需求编号 | 需求名称 | 归属工程 | 编码任务 | 覆盖状态 |
|---------|---------|---------|---------|---------|
| GOAI-001 | AgentTeams分层协作架构 | agent-teams | AT-T001~T008 | ✅ 完整覆盖 |
| GOAI-002 | 任务分解与DAG编排引擎 | agent-orchestration | ORCH-T001~T010 | ✅ 完整覆盖 |
| GOAI-003 | 执行证据链与审计系统 | execution-audit | EA-T001~T008 | ✅ 完整覆盖 |
| GOAI-004 | AI驱动开发全流程Demo | ai-dev-demo | DEM-T001~T005 | ✅ 完整覆盖 |
| GOAI-005 | 技能组合引擎核心 | skill-composition-engine | SCE-T001~T009 | ✅ 完整覆盖 |
| GOAI-006 | Agent间上下文传递与结果验证 | agent-context-verify | ACV-T001~T005 | ✅ 完整覆盖 |
| GOAI-007 | 记忆持久化与跨会话共享 | agent-memory-persistence | MEM-T001~T007 | ✅ 完整覆盖 |
| GOAI-008 | AgentLoop观测评估飞轮 | agent-loop | AL-T001~T004 | ✅ 完整覆盖 |
| GOAI-009 | 审批与回滚机制 | approval-rollback | AR-T001~T004 | ✅ 完整覆盖 |
| GOAI-010 | 技能组合模板与依赖解析 | skill-composition-engine | SCE-T005~T007 | ✅ 完整覆盖 |
| GOAI-011 | 错误恢复与自愈系统 | agent-error-recovery | AER-T001~T005 | ✅ 完整覆盖 |
| GOAI-012 | 开源计划与社区建设 | open-source-plan | OSP-T001~T002 | ✅ 完整覆盖 |
| GOAI-013 | SDD规范驱动开发技能集 | sdd-skills | SDD-T001~T006 | ✅ 完整覆盖 |
| GOAI-014 | 全栈代码生成闭环 | fullstack-codegen | FSC-T001~T005 | ✅ 完整覆盖 |
| GOAI-015 | 技能自进化闭环 | skill-evolution | SE-T001~T005 | ✅ 完整覆盖 |
| GOAI-016 | 协同技能集 | collaboration-skills | CS-T001~T004 | ✅ 完整覆盖 |
| GOAI-017 | 验证证据账本 | execution-audit | EA-T005 | ✅ 完整覆盖 |
| GOAI-018 | Agent Kanban任务队列 | collaboration-skills | CS-T005~T007 | ✅ 完整覆盖 |
| GOAI-019 | 记忆提供者插件体系 | memory-provider | MP-T001~T004 | ✅ 完整覆盖 |
| GOAI-020 | 上下文多层压缩管道 | context-optimization | CO-T001 | ✅ 完整覆盖 |
| GOAI-021 | 提示缓存机制 | context-optimization | CO-T002 | ✅ 完整覆盖 |
| GOAI-022 | cangjie-coder agents子目录完善 | cangjie-coder-agents | CCA-T001~T005 | ✅ 完整覆盖 |
| GOAI-023 | 代码生成工具Skills化封装 | code-gen-skills | CGS-T001~T006 | ✅ 完整覆盖 |
| GOAI-024 | 专用语言多Skills编排协作架构 | language-skills-orchestration | LSO-T001~T005 | ✅ 完整覆盖 |
| GOAI-025 | 测试脚本动态生成技能 | test-generator | TG-T001~T004 | ✅ 完整覆盖 |
| GOAI-026 | 技能脚本动态生成机制 | skill-evolution | SE-T004 | ✅ 完整覆盖 |
| GOAI-027 | 代码生成闭环验证 | code-gen-skills | CGS-T004~T005 | ✅ 完整覆盖 |
| GOAI-028 | Agent subagent配置增强 | language-skills-orchestration | LSO-T004 | ✅ 完整覆盖 |
| GOAI-029 | RepoMap代码库智能 | agent-intelligence | AI-T001 | ✅ 完整覆盖 |
| GOAI-030 | Agent动态生成能力 | agent-intelligence | AI-T002 | ✅ 完整覆盖 |

**需求覆盖率**: 30/30 = 100%