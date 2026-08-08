# 执行证据链与审计系统 - 任务清单

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
| EA-T001 | 数据库表设计与创建 | P0 | 0.5天 | 无 | ✅已完成 |
| EA-T002 | ExecutionEvidenceRecorder核心实现 | P0 | 1.5天 | EA-T001 | ✅已完成 |
| EA-T003 | SideEffectTracker副作用追踪 | P0 | 1天 | EA-T002 | ✅已完成 |
| EA-T004 | AuditHashChain哈希链校验 | P0 | 0.5天 | EA-T002 | ✅已完成 |
| EA-T005 | VerificationEvidenceCollector验证证据 | P0 | 1天 | EA-T001 | ✅已完成 |
| EA-T006 | CRUD模块与API实现 | P0 | 1天 | EA-T001 | ✅已完成(crudgen已生成) |
| EA-T007 | 与AgentTeams/EventHandler集成 | P0 | 0.5天 | EA-T002, agent-teams | ✅已完成 |
| EA-T008 | 集成测试与验证 | P0 | 1天 | EA-T001~T007 | ⏳待完成 |

---

## 仓颉规范合规性要求（来自cangjie-compliance-review.md）

- [ ] ExecutionEvidenceRecorder和VerificationEvidenceCollector类添加`public`修饰符
- [ ] `verifyIntegrity`返回值改用`Option<Bool>`（校验可能失败）
- [ ] `SideEffect`改用`struct`（值类型语义，纯数据载体）
- [ ] PlantUML数据模型中`JsonObject`改为`JsonValue`（JSONB字段对应JsonValue类型）
- [ ] PO类补充`@DataAssist[fields]`和`@QueryMappersGenerator`注解
- [ ] DAO接口使用`@DAO`注解并继承`RootDAO`
- [ ] Service方法统一返回`APIResult<T>`
- [ ] 补充标准包名和import说明

---

## EA-T001: 数据库表设计与创建

**描述**: 创建 execution_evidences 和 verification_evidences 数据库表。

**子任务**:
1. **[自动化]** 编写DDL文件放置在 `sql/incremental/` 目录
2. **[人工操作]** 通知人工执行数据库变更
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表
4. **[人工操作]** 人工使用 `crudgen` 生成Model/DAO/Service/Controller/Route骨架，使用 `crudweb` 生成Web管理界面

**验收标准**:
- [ ] execution_evidences表创建成功
- [ ] verification_evidences表创建成功
- [ ] 索引创建成功

---

## EA-T002: ExecutionEvidenceRecorder核心实现

**描述**: 实现执行证据记录器，记录Agent执行的每个步骤。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义ExecutionEvidence数据类
2. 实现ExecutionEvidenceRecorder
3. 实现recordStart/recordEnd/recordError方法
4. 与EventHandlerManager集成，监听AgentStartEvent/AgentEndEvent
5. 实现证据链查询方法

**关键文件**:
- `src/interaction/execution_evidence_recorder.cj`

**验收标准**:
- [x] Agent执行的每个步骤都有证据记录
- [x] 证据包含时间戳、Agent ID、输入输出、耗时
- [x] 证据链按执行顺序正确链接

---

## EA-T003: SideEffectTracker副作用追踪

**描述**: 实现副作用追踪器，记录每个步骤的副作用。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义SideEffect数据类
2. 实现SideEffectTracker
3. 追踪文件修改副作用（file_write）
4. 追踪数据库变更副作用（db_insert/db_update/db_delete）
5. 追踪API调用副作用（api_call）
6. 副作用记录与执行证据关联

**关键文件**:
- `src/interaction/side_effect_tracker.cj`

**验收标准**:
- [ ] 文件修改副作用正确追踪
- [ ] 数据库变更副作用正确追踪
- [ ] 副作用与执行证据正确关联

---

## EA-T004: AuditHashChain哈希链校验

**描述**: 实现哈希链校验，确保审计日志不可篡改。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现AuditHashChain
2. 每条证据记录包含前一条记录的哈希
3. 实现完整性校验方法
4. 篡改检测和告警

**关键文件**:
- `src/interaction/audit_hash_chain.cj`

**验收标准**:
- [ ] 哈希链正确计算
- [ ] 完整性校验正确检测篡改
- [ ] 篡改告警正确触发

---

## EA-T005: VerificationEvidenceCollector验证证据

**描述**: 实现验证证据收集器，记录Agent的验证操作结果。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义VerificationEvidence数据类
2. 实现VerificationEvidenceCollector
3. 支持编译验证（cjpm build）
4. 支持代码检查（lint）
5. 支持测试运行（test）
6. 支持业务规则验证
7. 实现会话级和仓库级聚合
8. 被动设计：记录但不阻止Agent

**关键文件**:
- `src/interaction/verification_evidence_collector.cj`

**验收标准**:
- [ ] 编译验证结果正确记录
- [ ] 测试运行结果正确记录
- [ ] 会话级聚合正确
- [ ] 被动设计：验证失败不阻止Agent

---

## EA-T006: CRUD模块与API实现

**描述**: 基于crudgen生成的标准CRUD模块，迭代开发证据查询和回放API。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 使用crudgen生成ExecutionEvidencePO和VerificationEvidencePO的CRUD代码
2. 实现按会话查询证据API
3. 实现执行回放API
4. 实现验证证据聚合查询API
5. 遵循uctoo-v4 API规范

**验收标准**:
- [ ] 标准 CRUD API可正常调用
- [ ] 按会话查询证据正确
- [ ] 执行回放正确工作

---

## EA-T007: 与AgentTeams/EventHandler集成

**描述**: 将执行证据系统与AgentTeams和EventHandler集成。

**子任务**:
1. ManagerGroup自动记录执行证据
2. TeamMessenger消息记录为证据
3. EventHandlerManager事件触发证据记录
4. WebSocket推送证据更新

**验收标准**:
- [ ] AgentTeams执行过程自动记录证据
- [ ] 消息传递记录为证据
- [ ] WebSocket推送正确

---

## EA-T008: 集成测试与验证

**描述**: 编写集成测试，验证执行证据系统的完整功能。

**子任务**:
1. 编写ExecutionEvidenceRecorder集成测试
2. 编写SideEffectTracker集成测试
3. 编写AuditHashChain集成测试
4. 编写VerificationEvidenceCollector集成测试
5. 编写与AgentTeams集成测试

**验收标准**:
- [ ] 所有集成测试通过
- [ ] 证据链完整性校验通过
- [ ] 副作用追踪正确
- [ ] 验证证据正确记录