# GOAI2026 设计文档仓颉编程语言规范合规性复核报告

**复核日期**: 2026-07-23  
**复核范围**: 11个设计文档（9个P0核心工程 + 2个P1增强工程）  
**复核依据**: 仓颉编程语言规范 + uctoo-v4模块开发规范 + 现有代码库实际模式

---

## 复核总结

| 严重程度 | 数量 | 说明 |
|---------|------|------|
| 严重 | 8 | 影响编译或运行时行为的规范违规 |
| 中等 | 12 | 不符合项目约定但不影响核心功能 |
| 轻微 | 9 | 代码风格和命名一致性问题 |

---

## 1. agent-teams/design.md

### 严重问题

| # | 问题描述 | 当前代码 | 修改建议 |
|---|---------|---------|---------|
| S1 | TeamManager/TeamMessenger类缺少`public`修饰符 | `class TeamManager {` | `public class TeamManager {` |
| S2 | 内部接口方法返回值未使用`Option<T>`或`APIResult<T>`包装可能失败的操作 | `func createTeam(config: TeamConfig): ManagerGroup` | `func createTeam(config: TeamConfig): Option<ManagerGroup>` |
| S3 | PlantUML数据模型中`JsonObject`应明确为`JsonValue`类型 | `config: JsonObject` | `config: JsonValue`（JsonObject是JsonValue的子类型，PO中config字段对应JSONB，应使用JsonValue表示任意JSON值） |
| S4 | PlantUML数据模型中`DateTime`缺少包引用说明 | `createdAt: DateTime` | 应注明`import std.time.DateTime` |

### 中等问题

| # | 问题描述 | 当前代码 | 修改建议 |
|---|---------|---------|---------|
| M1 | TeamManager类若需被继承应使用`open`修饰符 | `class TeamManager` | `open public class TeamManager` |
| M2 | PO类缺少`@DataAssist[fields]`和`@QueryMappersGenerator`注解说明 | PlantUML中仅列出字段 | 在持久化策略中补充注解要求 |
| M3 | DAO层未说明需继承`RootDAO`接口并使用`@DAO`注解 | 文中仅提及"AgentTeamDAO(数据访问)" | 补充DAO规范：`@DAO public interface AgentTeamDAO <: RootDAO` |
| M4 | Service层方法应返回`APIResult<T>`而非直接类型 | 内部接口直接返回类型 | 补充说明Service层统一使用`APIResult<T>`返回 |

### 轻微问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| L1 | PlantUML中`skills: Array<String>`在DDL中为`TEXT[]`，PO中应为`String`（JSONB序列化） | 补充说明skills字段在PO中以JsonValue存储 |
| L2 | 缺少包名说明 | 补充包名：`magic.app.models.uctoo`、`magic.app.dao.uctoo`等 |

---

## 2. agent-orchestration/design.md

### 严重问题

| # | 问题描述 | 当前代码 | 修改建议 |
|---|---------|---------|---------|
| S5 | DagScheduler类缺少`public`修饰符，方法返回值未使用错误处理模式 | `func schedule(plan: OrchestrationPlanPO): Unit` | `public func schedule(plan: OrchestrationPlanPO): Option<Unit>` 或使用`APIResult<Unit>` |
| S6 | PlantUML数据模型中`JsonObject`应统一为`JsonValue` | `dagDefinition: JsonObject`等 | 改为`dagDefinition: JsonValue` |

### 中等问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| M5 | DagScheduler若需被继承应使用`open`修饰符 | `open public class DagScheduler` |
| M6 | PO类和DAO类缺少uctoo-v4注解和继承规范说明 | 补充`@DataAssist`、`@QueryMappersGenerator`、`@DAO`、`RootDAO`规范 |
| M7 | Service层应使用`APIResult<T>`统一返回 | 补充说明 |

### 轻微问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| L3 | 缺少包名和import说明 | 补充标准包名 |

---

## 3. execution-audit/design.md

### 严重问题

| # | 问题描述 | 当前代码 | 修改建议 |
|---|---------|---------|---------|
| S7 | ExecutionEvidenceRecorder和VerificationEvidenceCollector类缺少`public`修饰符 | `class ExecutionEvidenceRecorder {` | `public class ExecutionEvidenceRecorder {` |
| S8 | `verifyIntegrity`返回`Bool`但校验可能失败，应使用`Option<Bool>` | `func verifyIntegrity(sessionId: String): Bool` | `func verifyIntegrity(sessionId: String): Option<Bool>` |

### 中等问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| M8 | PlantUML中`SideEffect`应为`struct`而非`class`（值类型语义） | `struct SideEffect {` |
| M9 | PO类和DAO类缺少uctoo-v4注解和继承规范说明 | 补充规范 |

### 轻微问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| L4 | 缺少包名和import说明 | 补充标准包名 |

---

## 4. skill-composition-engine/design.md

### 中等问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| M10 | CompositionExecutor和InputMapper类缺少`public`修饰符 | `public class CompositionExecutor {` |
| M11 | `resolveExpression`返回`JsonValue`可能失败，应使用`Option<JsonValue>` | `func resolveExpression(...): Option<JsonValue>` |

### 轻微问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| L5 | HashMap使用正确但缺少import说明 | 补充`import std.collection.HashMap` |

---

## 5. cangjie-coder-agents/design.md

### 轻微问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| L6 | subagent定义中`agent_type: sub`与系统约定一致，无问题 | - |
| L7 | Python脚本使用符合项目约定 | - |

**结论**: 本文档无仓颉规范合规性问题，仅涉及YAML定义和Python脚本。

---

## 6. code-gen-skills/design.md

### 轻微问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| L8 | SKILL.md中inputs/outputs定义使用YAML格式，与技能规范一致 | - |

**结论**: 本文档无仓颉规范合规性问题。

---

## 7. sdd-skills/design.md

**结论**: 本文档无仓颉规范合规性问题，仅涉及YAML组合模板定义。

---

## 8. fullstack-codegen/design.md

**结论**: 本文档无仓颉规范合规性问题，仅涉及YAML组合模板定义。

---

## 9. ai-dev-demo/design.md

**结论**: 本文档无仓颉规范合规性问题。

---

## 10. agent-memory-persistence/design.md

### 中等问题

| # | 问题描述 | 当前代码 | 修改建议 |
|---|---------|---------|---------|
| M12 | AgentMemoryService类缺少`public`修饰符 | `class AgentMemoryService {` | `public class AgentMemoryService {` |

### 轻微问题

| # | 问题描述 | 修改建议 |
|---|---------|---------|
| L9 | `limit!: Int64`命名参数语法正确，但默认参数值缺失 | `func retrieve(agentId: String, query: String, limit!: Int64)` | `func retrieve(agentId: String, query: String, limit!: Int64 = 10)` |

---

## 11. agent-error-recovery/design.md

### 中等问题

| # | 问题描述 | 当前代码 | 修改建议 |
|---|---------|---------|---------|
| M13 | ErrorClassifier和CircuitBreaker类缺少`public`修饰符 | `class ErrorClassifier {` | `public class ErrorClassifier {` |
| M14 | `classify`方法返回`ErrorCategory`可能失败，应使用`Option<ErrorCategory>` | `func classify(error: Exception): ErrorCategory` | `func classify(error: Exception): Option<ErrorCategory>` |

---

## 跨文档共性问题汇总

### 1. 类声明缺少`public`修饰符（严重/中等）
所有文档中的类声明均缺少`public`修饰符。根据现有代码库规范（ConfigPO、ConfigService、ConfigController等），所有对外类均使用`public class`。

**涉及文档**: #1, #2, #3, #4, #10, #11

### 2. 方法返回值未使用`Option<T>`或`APIResult<T>`（严重）
可能失败的方法直接返回类型值，未使用仓颉的错误处理模式。根据现有代码库，DAO层使用`Option<T>`，Service层使用`APIResult<T>`。

**涉及文档**: #1, #2, #3, #4, #10, #11

### 3. PlantUML数据模型中`JsonObject`应统一为`JsonValue`（严重）
在仓颉标准库中，`JsonValue`是JSON值的通用类型（来自`stdx.encoding.json`），`JsonObject`是其子类型。PO类中对应JSONB字段的属性应使用`JsonValue`类型声明。

**涉及文档**: #1, #2, #3

### 4. PO/DAO/Service层规范说明不完整（中等）
设计文档未完整说明uctoo-v4模块开发规范中的关键约束：
- PO类需使用`@DataAssist[fields]`和`@QueryMappersGenerator`注解
- DAO接口需使用`@DAO`注解并继承`RootDAO`
- Service方法需返回`APIResult<T>`
- Controller方法签名为`func add(req: HttpRequest, res: HttpResponse): Unit`

**涉及文档**: #1, #2, #3, #10

### 5. 值类型应使用`struct`而非`class`（中等）
`SideEffect`等纯数据载体应使用`struct`（值类型语义），而非`class`（引用类型语义）。

**涉及文档**: #3

---

## 修改执行清单

| 优先级 | 文档 | 修改项 |
|-------|------|--------|
| P0 | agent-teams/design.md | 添加public修饰符；方法返回值改用Option/APIResult；JsonObject→JsonValue；补充PO/DAO/Service规范说明 |
| P0 | agent-orchestration/design.md | 添加public修饰符；方法返回值改用Option/APIResult；JsonObject→JsonValue；补充PO/DAO/Service规范说明 |
| P0 | execution-audit/design.md | 添加public修饰符；verifyIntegrity改用Option<Bool>；SideEffect改struct；补充PO/DAO/Service规范说明 |
| P1 | skill-composition-engine/design.md | 添加public修饰符；resolveExpression改用Option<JsonValue> |
| P1 | agent-memory-persistence/design.md | 添加public修饰符；limit默认参数值 |
| P1 | agent-error-recovery/design.md | 添加public修饰符；classify改用Option<ErrorCategory> |