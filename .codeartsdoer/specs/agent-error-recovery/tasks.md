# Agent错误恢复与自愈系统 - 编码任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式
- ErrorClassifier和CircuitBreaker类添加 `public` 修饰符
- classify方法返回值改用 `Option<ErrorCategory>`

---

## 任务总览

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| AER-T001 | 错误分类枚举与ErrorClassifier | spec REQ-ERR-001, 存量Exception体系 | ErrorCategory枚举 + ErrorClassifier类 | classify返回Option\<ErrorCategory\>，分类延迟≤10ms | 4h | 无 | 仓颉基础 |
| AER-T002 | 智能重试策略扩展 | spec REQ-ERR-002, 存量RetryManager | GenericRetryManager + 多策略支持 | 支持指数退避/固定间隔/抖动，按错误类型选择策略 | 6h | AER-T001 | 仓颉并发 |
| AER-T003 | 降级执行管理器 | spec REQ-ERR-003, Agent/技能定义 | DegradationManager类 | Agent不可用时自动降级到替代方案，决策记录日志 | 6h | AER-T001 | 仓颉基础 |
| AER-T004 | 错误传播控制网关 | spec REQ-ERR-004, 子Agent错误场景 | ErrorGateway类 | absorb/transform/escalate/isolate四种策略正确执行 | 5h | AER-T001 | 仓颉基础 |
| AER-T005 | 自愈诊断引擎 | spec REQ-ERR-005, 错误日志/堆栈/资源状态 | SelfHealingDiagnostic类 | 自动诊断生成报告，诊断超时≤30s | 8h | AER-T001, AER-T002 | 仓颉基础 |
| AER-T006 | 熔断器实现 | spec REQ-ERR-006 | CircuitBreaker类 | closed/open/half_open三态正确切换，切换延迟≤5ms | 6h | AER-T001 | 仓颉并发 |
| AER-T007 | 补偿事务管理器 | spec REQ-ERR-007, 存量SideEffectTracker | CompensationManager类 | 编排失败时按逆序执行补偿，部分失败时记录告警 | 6h | AER-T001 | 仓颉基础 |
| AER-T008 | 错误恢复集成编排 | 全部组件 | ErrorRecoveryOrchestrator | 错误发生→分类→策略选择→执行恢复全链路贯通 | 8h | AER-T001~T007 | 仓颉架构 |
| AER-T009 | 集成测试与验收验证 | 全部组件 | 测试用例 + 验收报告 | 7项验收标准全部通过 | 6h | AER-T008 | 仓颉测试 |

---

## 任务详细说明

### AER-T001: 错误分类枚举与ErrorClassifier

- **描述**: 实现错误四级分类体系（transient/recoverable/degradable/fatal）和错误分级（critical/error/warning/info），提供自动分类器将Exception映射到对应分类。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `error_category.cj`，定义 `ErrorCategory` 枚举（Transient/Recoverable/Degradable/Fatal）和 `ErrorLevel` 枚举（Critical/Error/Warning/Info）
  2. 在 `src/interaction/` 下新建 `error_classifier.cj`，实现 `public class ErrorClassifier`
  3. `classify(error: Exception): Option<ErrorCategory>` 方法基于错误消息关键词和异常类型自动分类：
     - 网络超时/连接拒绝 → Transient
     - 参数错误/技能缺失 → Recoverable
     - Agent不可用/服务降级 → Degradable
     - 权限不足/数据损坏 → Fatal
  4. 支持自定义分类规则注册：`registerRule(rule: ErrorClassificationRule): Unit`
  5. 分类规则优先级：自定义规则 > 内置规则，按注册顺序匹配
  6. 分类结果附带置信度，低于阈值时返回 `None`
- **测试要点**:
  - 各类典型Exception的分类正确性
  - 自定义规则覆盖内置规则
  - 分类延迟≤10ms
  - 未知错误返回None

---

### AER-T002: 智能重试策略扩展

- **描述**: 将存量 `RetryManager`（`src/app/services/sync/retry/RetryManager.cj`）扩展为通用组件，支持多种退避策略和按错误类型选择策略。保持存量RetryManager不变，新组件独立于 `src/interaction/` 包。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `retry_strategy.cj`，定义 `RetryStrategy` 枚举（ExponentialBackoff/FixedInterval/CustomBackoff）和 `RetryConfig` 配置类
  2. 在 `src/interaction/` 下新建 `generic_retry_manager.cj`，实现 `GenericRetryManager`：
     - `executeWithRetry<T>(operation: () -> T, config: RetryConfig): Option<T>` 泛型重试执行
     - `calculateDelay(attempt: Int32, strategy: RetryStrategy, config: RetryConfig): Int64` 延迟计算
     - 支持抖动（jitter）：`delay = baseDelay * (1 + random(-jitter, +jitter))`
     - 按错误类型选择策略：transient用指数退避+抖动，recoverable用固定间隔
  3. 重试前调用 ErrorClassifier 判断是否值得重试：fatal类错误直接跳过
  4. 重试时可调整参数：`adjustParameters(context: RetryContext): RetryConfig`
  5. 参考存量 RetryManager 的指数退避实现（`calculateRetryDelay`），扩展固定间隔和抖动
- **测试要点**:
  - 指数退避延迟计算正确（1s/2s/4s/8s）
  - 抖动延迟在合理范围内
  - fatal错误不重试
  - transient错误使用指数退避+抖动
  - 最大重试次数配置生效

---

### AER-T003: 降级执行管理器

- **描述**: 实现Agent/技能不可用时的自动降级机制，支持多级降级策略。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `degradation_manager.cj`，实现 `DegradationManager`：
     - `registerDegradation(targetName: String, fallbacks: ArrayList<DegradationLevel>): Unit` 注册降级链
     - `executeWithDegradation<T>(targetName: String, operation: () -> T): Option<T>` 降级执行
  2. 定义 `DegradationLevel`：包含优先级、替代方案描述、执行函数
  3. 降级链示例：复杂Agent → 基础Agent → 直接技能执行 → 内置工具操作
  4. 技能降级：使用旧版本 / 使用相似替代技能 / 使用内置工具
  5. 降级决策记录到 operate_log，包含原始目标、降级原因、替代方案
  6. 降级执行结果标记为降级结果，与正常结果区分
- **测试要点**:
  - Agent不可用时正确降级到替代方案
  - 多级降级链按优先级依次尝试
  - 所有降级均失败时返回None
  - 降级决策正确记录到日志

---

### AER-T004: 错误传播控制网关

- **描述**: 实现子Agent错误的传播控制，支持absorb/transform/escalate/isolate四种策略，防止错误直接传播导致整体任务失败。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `error_gateway.cj`，实现 `ErrorGateway`：
     - `handleError(error: Exception, context: ErrorContext): ErrorHandlingResult` 统一错误处理入口
  2. 定义 `PropagationStrategy` 枚举：Absorb/Transform/Escalate/Isolate
  3. 定义 `ErrorContext`：包含agentId、taskId、errorCategory、propagationConfig
  4. 四种策略实现：
     - `absorb`: 返回默认值，主Agent继续执行
     - `transform`: 转换为警告，调整后续执行计划
     - `escalate`: 升级错误，通知主Agent重新决策
     - `isolate`: 标记子任务失败，不影响其他子任务
  5. 策略配置：`configurePropagation(agentType: String, errorCategory: ErrorCategory, strategy: PropagationStrategy): Unit`
  6. 错误聚合：`aggregateErrors(errors: ArrayList<Exception>): AggregatedError` 同类错误合并
- **测试要点**:
  - 四种策略按配置正确执行
  - absorb策略返回默认值不中断主流程
  - isolate策略不影响兄弟子任务
  - 同类错误正确聚合

---

### AER-T005: 自愈诊断引擎

- **描述**: 实现错误发生后的自动诊断流程，分析根因并生成修复建议，诊断结果存入记忆系统。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `self_healing_diagnostic.cj`，实现 `SelfHealingDiagnostic`：
     - `diagnose(error: Exception, context: ErrorContext): DiagnosisReport` 诊断入口
  2. 诊断流程四步骤：
     - 步骤1：分析错误日志和堆栈 → `analyzeStackTrace(error: Exception): StackAnalysis`
     - 步骤2：检查相关资源状态 → `checkResourceStatus(context: ErrorContext): ResourceStatus`
     - 步骤3：匹配已知错误模式 → `matchErrorPattern(error: Exception): Option<ErrorPattern>`
     - 步骤4：生成诊断报告和修复建议 → `generateReport(analysis, status, pattern): DiagnosisReport`
  3. 在 `src/interaction/` 下新建 `error_pattern_library.cj`，实现错误模式库：
     - 预置常见错误模式（网络超时、权限不足、资源耗尽等）
     - 支持动态注册新模式：`registerPattern(pattern: ErrorPattern): Unit`
  4. 基于诊断结果自动调整：
     - 修改输入参数 → 重新执行
     - 更换执行策略 → 降级/重试
     - 请求用户干预 → HITL交互
  5. 诊断结果存入AgentMemories，避免同类错误重复诊断
  6. 诊断超时控制：整体≤30s，单步骤≤10s
- **测试要点**:
  - 常见错误模式正确匹配
  - 诊断报告包含根因分析和修复建议
  - 诊断超时正确触发
  - 诊断结果存入记忆系统

---

### AER-T006: 熔断器实现

- **描述**: 为Agent和技能实现熔断器保护，连续失败时自动熔断，恢复时逐步放行。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `circuit_breaker.cj`，实现 `public class CircuitBreaker`：
     - `allowRequest(targetId: String): Bool` 判断是否放行请求
     - `recordSuccess(targetId: String): Unit` 记录成功
     - `recordFailure(targetId: String): Unit` 记录失败
     - `getState(targetId: String): Option<CircuitState>` 查询状态
  2. 定义 `CircuitState` 枚举：Closed/Open/HalfOpen
  3. 定义 `CircuitBreakerConfig`：failureThreshold（连续失败N次触发熔断）、failureRateThreshold（时间窗口内失败率阈值）、halfOpenMaxRequests（半开状态最大探测请求数）、openTimeout（熔断持续时间，超时进入半开）
  4. 三态转换逻辑：
     - Closed → Open：连续失败≥failureThreshold 或 时间窗口内失败率≥failureRateThreshold
     - Open → HalfOpen：超过openTimeout时间
     - HalfOpen → Closed：探测成功次数≥halfOpenMaxRequests
     - HalfOpen → Open：探测失败
  5. 熔断事件通知：状态变更时通过EventHandlerManager发布事件
  6. 熔断器实例按targetId隔离，使用HashMap存储
  7. 状态切换延迟≤5ms，参考存量RetryManager的Mutex用法保证并发安全
- **测试要点**:
  - 连续失败达到阈值时正确熔断
  - 熔断后请求直接拒绝
  - 半开状态允许探测请求
  - 探测成功后恢复正常
  - 状态切换延迟≤5ms

---

### AER-T007: 补偿事务管理器

- **描述**: 基于存量 `SideEffectTracker`（`src/interaction/side_effect_tracker.cj`）的副作用追踪能力，实现编排失败时的逆序补偿事务。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `compensation_manager.cj`，实现 `CompensationManager`：
     - `registerCompensation(evidenceId: String, action: CompensationAction): Unit` 注册补偿动作
     - `executeCompensation(evidenceId: String): CompensationResult` 执行补偿（逆序）
     - `executeCompensationForSession(sessionId: String): CompensationResult` 按会话补偿
  2. 定义 `CompensationAction`：包含target、actionType、parameters、isCritical
  3. 复用 `SideEffectTracker.getRollbackPlan(evidenceId)` 获取逆序补偿计划
  4. 补偿动作执行器（解析rollbackAction字符串）：
     - `restore_file:filePath` → 删除文件或恢复内容
     - `db_delete:table:id` → 删除记录
     - `db_insert:table:id` → 插入记录（需beforeState）
     - `db_update:table:id` → 恢复到beforeState
     - `skill_uninstall:skillName` → 卸载技能
  5. 部分补偿失败处理：非关键补偿失败记录告警继续执行；关键补偿失败中止并告警
  6. 补偿结果记录到 operate_log
  7. 补偿执行超时：整体≤60s，单动作≤10s
- **测试要点**:
  - 编排失败时按逆序执行补偿
  - 文件写入→删除文件补偿正确
  - 数据库插入→删除记录补偿正确
  - 部分补偿失败时正确记录告警
  - 补偿超时正确触发

---

### AER-T008: 错误恢复集成编排

- **描述**: 将所有错误恢复组件集成到统一的编排器中，实现错误发生→分类→策略选择→执行恢复的全链路贯通。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `error_recovery_orchestrator.cj`，实现 `ErrorRecoveryOrchestrator`：
     - `handleError(error: Exception, context: ErrorContext): RecoveryResult` 统一错误恢复入口
  2. 编排流程：
     - 步骤1：ErrorClassifier 分类错误
     - 步骤2：CircuitBreaker 检查是否熔断
     - 步骤3：ErrorGateway 确定传播策略
     - 步骤4：根据分类选择恢复策略：
       - Transient → GenericRetryManager 重试
       - Recoverable → SelfHealingDiagnostic 诊断 + 调整后重试
       - Degradable → DegradationManager 降级执行
       - Fatal → CompensationManager 补偿回滚
     - 步骤5：记录恢复结果到 ExecutionEvidenceRecorder
  3. 与存量系统集成：
     - 在 `ExecutionEvidenceRecorder.recordError` 中触发恢复编排
     - 恢复结果更新 ExecutionEvidence 状态
     - 熔断事件通过 EventHandlerManager 发布
  4. 恢复结果定义：`RecoveryResult`（success/recovered/degraded/failed + 原始错误 + 恢复策略 + 恢复详情）
  5. 恢复策略可配置：`configureRecovery(errorCategory: ErrorCategory, strategy: RecoveryStrategy): Unit`
- **测试要点**:
  - 全链路贯通：错误→分类→策略→恢复
  - transient错误自动重试成功
  - degradable错误自动降级执行
  - fatal错误触发补偿回滚
  - 熔断状态下请求直接拒绝
  - 恢复结果正确记录到证据链

---

### AER-T009: 集成测试与验收验证

- **描述**: 编写集成测试验证全部7项验收标准，生成验收报告。
- **实现要点**:
  1. 在 `src/interaction/` 下新建 `error_recovery_test.cj`，编写集成测试：
     - 测试1：错误自动分类为四种类型，分类准确率≥90%
     - 测试2：智能重试根据错误类型选择正确策略
     - 测试3：降级执行在Agent/技能不可用时正确降级
     - 测试4：错误传播按配置策略正确处理
     - 测试5：自愈诊断生成有效的诊断报告和修复建议
     - 测试6：熔断器在连续失败时正确熔断和恢复
     - 测试7：补偿事务正确回滚已执行操作的副作用
  2. 构造典型错误场景：
     - 网络超时（transient + 重试）
     - 技能缺失（recoverable + 诊断调整）
     - Agent不可用（degradable + 降级）
     - 权限不足（fatal + 补偿回滚）
     - 连续失败（熔断触发与恢复）
  3. 性能验证：
     - 错误分类延迟≤10ms
     - 熔断器状态切换延迟≤5ms
     - 诊断流程超时≤30s
     - 补偿事务执行超时≤60s
  4. 生成验收报告文档
- **测试要点**:
  - 7项验收标准全部通过
  - 性能指标全部达标
  - 边界场景覆盖（空输入、并发错误、嵌套错误）

---

## 文件产出清单

| 任务ID | 新增文件 | 修改文件 |
|--------|---------|---------|
| AER-T001 | `src/interaction/error_category.cj`, `src/interaction/error_classifier.cj` | 无 |
| AER-T002 | `src/interaction/retry_strategy.cj`, `src/interaction/generic_retry_manager.cj` | 无 |
| AER-T003 | `src/interaction/degradation_manager.cj` | 无 |
| AER-T004 | `src/interaction/error_gateway.cj` | 无 |
| AER-T005 | `src/interaction/self_healing_diagnostic.cj`, `src/interaction/error_pattern_library.cj` | 无 |
| AER-T006 | `src/interaction/circuit_breaker.cj` | 无 |
| AER-T007 | `src/interaction/compensation_manager.cj` | 无 |
| AER-T008 | `src/interaction/error_recovery_orchestrator.cj` | `src/interaction/execution_evidence_recorder.cj` |
| AER-T009 | `src/interaction/error_recovery_test.cj` | 无 |

---

## 依赖关系图

```
AER-T001 (错误分类)
  ├── AER-T002 (智能重试)
  ├── AER-T003 (降级执行)
  ├── AER-T004 (错误传播)
  ├── AER-T005 (自愈诊断) ← 依赖 T001 + T002
  ├── AER-T006 (熔断器)
  └── AER-T007 (补偿事务)
         │
         ▼
  AER-T008 (集成编排) ← 依赖 T001~T007
         │
         ▼
  AER-T009 (集成测试) ← 依赖 T008
```

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 仓颉泛型支持限制 | GenericRetryManager泛型实现受阻 | 改用Any类型+类型转换，或为常用类型生成特化版本 |
| 错误分类规则覆盖不全 | 分类准确率不达标 | 提供自定义规则注册机制，逐步积累规则库 |
| 补偿动作执行失败 | 副作用无法完全回滚 | 关键补偿失败告警，非关键补偿继续执行 |
| 熔断器并发安全 | 多线程状态不一致 | 使用Mutex保护状态变更，参考存量RetryManager的Mutex用法 |
| 诊断流程耗时过长 | 影响主流程响应 | 设置每步骤超时，整体超时≤30s |
