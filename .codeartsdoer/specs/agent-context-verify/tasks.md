# Agent间上下文传递与结果验证 - 编码任务清单

## 任务总览

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| ACV-T001 | AgentContext结构化上下文 | spec REQ-ACV-001 | AgentContext struct + 序列化/反序列化 | 上下文对象可创建、序列化、反序列化；子上下文继承父约束 | 4h | 无 | 仓颉 |
| ACV-T002 | ContextPasser上下文传递器 | AgentContext, TeamMessenger | ContextPasser class | 通过TeamMessenger正确传递/广播/接收上下文；记录执行证据 | 6h | ACV-T001 | 仓颉 |
| ACV-T003 | MessageType枚举扩展 | 现有MessageType | 扩展后的MessageType | 新增CONTEXT_PASS/VALIDATION_RESULT/DEGRADATION_NOTICE/INCREMENTAL_RESULT | 2h | 无 | 仓颉 |
| ACV-T004 | OutputValidationRule验证规则 | spec REQ-ACV-002 | OutputValidationRule + ValidationRuleType + ValidationStatus | 规则可创建、序列化、反序列化；支持5种规则类型 | 4h | 无 | 仓颉 |
| ACV-T005 | AgentResultValidator结果验证器 | SkillOutput, OutputValidationRule | AgentResultValidator + ValidationResult + AgentValidationSummary | 验证器可对SkillOutput执行规则验证；返回valid/invalid/partial；记录验证证据 | 8h | ACV-T004 | 仓颉 |
| ACV-T006 | SKILL.md outputs规则解析 | SKILL.md outputs字段格式 | loadRulesFromSkillOutputs方法 | 从JsonValue解析为ArrayList<OutputValidationRule>；兼容无验证规则场景 | 4h | ACV-T004 | 仓颉 |
| ACV-T007 | ValidationRetryHandler重试处理器 | AgentValidationSummary, DegradationConfig | ValidationRetryHandler class | 验证失败时正确判断是否重试；重试耗尽后执行降级；记录证据 | 6h | ACV-T005 | 仓颉 |
| ACV-T008 | DegradationConfig降级策略 | spec REQ-ACV-003 | DegradationConfig + DegradationStrategyType | 支持4种降级策略；可配置默认值/替代步骤/简化输入 | 4h | ACV-T005 | 仓颉 |
| ACV-T009 | IncrementalResultPusher增量推送 | WebSocketSessionManager, ResultAggregator | IncrementalResultPusher class | 步骤结果/验证结果/上下文传递均可推送；广播到所有session | 6h | ACV-T003 | 仓颉 |
| ACV-T010 | DagScheduler验证增强 | AgentResultValidator, ValidationRetryHandler, ContextPasser | 增强后的DagScheduler.executeStep | 步骤执行后自动验证；验证失败重试；重试耗尽降级；推送增量结果 | 8h | ACV-T002, ACV-T005, ACV-T007, ACV-T009 | 仓颉 |
| ACV-T011 | DagTeamOrchestrator上下文集成 | ContextPasser, IncrementalResultPusher | 增强后的DagTeamOrchestrator | 编排时创建根上下文；步骤间传递子上下文；推送增量结果 | 6h | ACV-T002, ACV-T009 | 仓颉 |
| ACV-T012 | agent_verification_records DDL | 设计文档数据模型 | DDL脚本 + PO + DAO + Service + Controller + Route | DDL符合uctoo-v4规范；CRUD完整；验证记录可持久化 | 8h | ACV-T005 | 仓颉+crudgen |
| ACV-T013 | 集成测试 | 全部模块 | 测试用例 | 上下文传递端到端；验证成功/失败/部分；重试+降级；增量推送 | 8h | ACV-T010, ACV-T011, ACV-T012 | 仓颉 |

## 任务详细说明

### ACV-T001: AgentContext结构化上下文

- **描述**: 实现AgentContext struct，作为Agent间传递的标准化上下文对象
- **实现要点**:
  - 定义为`public struct AgentContext`，包含taskId/parentId/input/constraints/metadata/createdAt字段
  - 实现toJsonValue()序列化方法，将所有字段转为JsonValue
  - 实现static fromJsonValue(json: JsonValue)反序列化方法，从JsonValue还原AgentContext
  - constraints和metadata使用HashMap<String, String>，序列化为JsonObject
  - parentId为Option<String>，None时不输出到JSON
  - createdAt默认DateTime.now()
- **测试要点**:
  - 创建根上下文，验证所有字段正确
  - 序列化后反序列化，验证往返一致性
  - parentId为None时序列化不包含该字段
  - constraints/metadata为空时序列化正确

### ACV-T002: ContextPasser上下文传递器

- **描述**: 实现ContextPasser，封装AgentContext的创建、传递、接收
- **实现要点**:
  - 依赖注入TeamMessenger和ExecutionEvidenceRecorder
  - passContext: 将AgentContext序列化为JsonValue字符串，设置MessageType.CONTEXT_PASS，通过TeamMessenger.send发送，记录执行证据
  - broadcastContext: 通过TeamMessenger.broadcast广播上下文
  - receiveContext: 从TeamMessenger.getMessagesTo获取CONTEXT_PASS类型消息，反序列化为AgentContext
  - createContext: 创建根上下文，taskId由调用方指定
  - createChildContext: 创建子上下文，继承父上下文的constraints，parentId指向父taskId
- **测试要点**:
  - passContext后receiveContext能正确还原上下文
  - createChildContext继承父约束
  - broadcastContext所有角色可接收
  - 传递过程记录执行证据

### ACV-T003: MessageType枚举扩展

- **描述**: 在现有MessageType枚举中新增上下文传递和验证相关消息类型
- **实现要点**:
  - 在`agent_group/team_message.cj`的MessageType枚举中新增: CONTEXT_PASS, VALIDATION_RESULT, DEGRADATION_NOTICE, INCREMENTAL_RESULT
  - 同步更新messageTypeToString方法
  - 同步更新TeamMessenger.messageTypeToString方法
  - 确保向后兼容，现有消息类型不受影响
- **测试要点**:
  - 新增枚举值可正确序列化/反序列化
  - 现有消息类型功能不受影响
  - TeamMessenger可发送/接收新增类型消息

### ACV-T004: OutputValidationRule验证规则

- **描述**: 实现验证规则数据结构，支持从SKILL.md outputs字段解析
- **实现要点**:
  - 定义ValidationRuleType枚举: SchemaCheck, AssertionCheck, FieldRequired, TypeCheck, CustomExpression
  - 定义ValidationStatus枚举: Valid, Invalid, Partial
  - 定义OutputValidationRule class: name/ruleType/expression/required
  - 实现toJsonValue/fromJsonValue序列化/反序列化
  - expression字段为验证表达式字符串，如"files.size > 0"
- **测试要点**:
  - 5种规则类型均可创建和序列化
  - fromJsonValue可正确解析规则
  - required字段默认为true

### ACV-T005: AgentResultValidator结果验证器

- **描述**: 实现Agent执行结果的自动验证框架
- **实现要点**:
  - 依赖注入VerificationEvidenceCollector
  - validate(output: SkillOutput, rules): 遍历规则列表，对SkillOutput执行验证
    - FieldRequired: 检查output.data/fields中是否包含指定字段
    - TypeCheck: 检查字段值类型是否匹配
    - SchemaCheck: 检查output结构是否符合预期
    - AssertionCheck: 执行断言表达式(复用ConditionEvaluator逻辑)
    - CustomExpression: 自定义表达式验证
  - 每条规则生成ValidationResult(ruleName/status/details/actualValue)
  - 汇总为AgentValidationSummary(overallStatus/results/validCount/invalidCount/partialCount)
  - overallStatus: 全部Valid→Valid，任一Invalid→Invalid，其余→Partial
  - 验证完成后调用evidenceCollector.recordBusinessRule记录验证证据
- **测试要点**:
  - 全部规则通过→Valid
  - 任一规则失败→Invalid
  - 部分规则通过、部分跳过→Partial
  - 空规则列表→Valid(无验证要求)
  - 验证证据正确记录

### ACV-T006: SKILL.md outputs规则解析

- **描述**: 实现从SKILL.md的outputs字段解析验证规则
- **实现要点**:
  - loadRulesFromSkillOutputs(outputsDef: JsonValue): ArrayList<OutputValidationRule>
  - outputsDef为JsonArray格式，每个元素包含name/type/required/validation字段
  - validation为JsonArray，每个元素包含rule/expression字段
  - 将validation中的rule字符串映射为ValidationRuleType
  - 无validation字段的output项不生成规则
  - 兼容outputsDef为空或格式不完整的场景
- **测试要点**:
  - 标准格式outputs正确解析为规则列表
  - 无validation字段时不生成规则
  - 空outputs返回空列表
  - 格式异常不崩溃，跳过无效项

### ACV-T007: ValidationRetryHandler重试处理器

- **描述**: 实现验证失败时的自动重试和降级执行
- **实现要点**:
  - 依赖注入maxRetries、degradationConfig、evidenceRecorder
  - shouldRetry(summary, attemptCount): attemptCount < maxRetries && summary.overallStatus == Invalid → true
  - executeDegradation(step, context): 根据DegradationStrategyType执行降级
    - SkipStep: 返回Skipped状态StepResult
    - UseDefault: 使用defaultValue作为output返回Completed
    - RetryWithSimplerInput: 使用simplerInput重新执行(需外部调用方配合)
    - FallbackToAlternative: 使用alternativeStep替代执行(需外部调用方配合)
  - 降级执行记录执行证据
- **测试要点**:
  - 验证失败且未超重试次数→shouldRetry=true
  - 验证失败且超重试次数→shouldRetry=false
  - 验证成功→shouldRetry=false
  - SkipStep降级返回Skipped状态
  - UseDefault降级返回默认值
  - 无降级配置时重试耗尽返回Failed

### ACV-T008: DegradationConfig降级策略

- **描述**: 实现降级策略配置数据结构
- **实现要点**:
  - 定义DegradationStrategyType枚举: SkipStep, UseDefault, RetryWithSimplerInput, FallbackToAlternative
  - 定义DegradationConfig class: strategy/defaultValue/alternativeStep/simplerInput
  - 实现toJsonValue/fromJsonValue
  - 可从StepConfig的metadata或DAG配置中解析
- **测试要点**:
  - 4种策略类型均可创建和序列化
  - fromJsonValue正确解析
  - Optional字段为None时序列化正确

### ACV-T009: IncrementalResultPusher增量推送

- **描述**: 实现通过WebSocket推送增量结果
- **实现要点**:
  - 依赖注入WebSocketSessionManager和ResultAggregator
  - pushIncrementalResult: 构建WebSocketMessage(type="incremental_result", payload含stepName/result摘要/timestamp)，发送到指定session
  - pushValidationResult: 构建WebSocketMessage(type="validation_result", payload含stepName/overallStatus/results摘要)
  - pushContextPass: 构建WebSocketMessage(type="context_pass", payload含from/to/taskId)
  - broadcastIncrementalResult: 遍历所有session推送增量结果
  - 复用ResultAggregator.incrementalAggregate进行增量聚合
  - 推送失败不影响主流程(try-catch包裹)
- **测试要点**:
  - 指定session可收到增量结果
  - 广播消息所有session可收到
  - 推送失败不中断主流程
  - 消息格式符合WebSocketMessage规范

### ACV-T010: DagScheduler验证增强

- **描述**: 在DagScheduler.executeStep中嵌入验证、重试、降级流程
- **实现要点**:
  - 新增成员变量: _validator(AgentResultValidator), _retryHandler(ValidationRetryHandler), _contextPasser(ContextPasser), _incrementalPusher(IncrementalResultPusher)
  - 改造executeStep为"执行→验证→重试/降级"三段式:
    1. 解析StepConfig中的验证规则(从metadata中获取或从SKILL.md outputs加载)
    2. 执行技能/Agent
    3. 对执行结果调用validator.validate
    4. IF Invalid: 循环重试(shouldRetry判断)，每次重试重新执行
    5. 重试耗尽: 调用retryHandler.executeDegradation
    6. 调用incrementalPusher.pushIncrementalResult推送增量结果
    7. 调用incrementalPusher.pushValidationResult推送验证结果
  - 保持现有接口签名不变，新增验证逻辑为增强而非替换
  - 验证规则为空时跳过验证环节(向后兼容)
- **测试要点**:
  - 无验证规则时行为与原逻辑一致
  - 验证通过时正常完成
  - 验证失败时正确重试
  - 重试耗尽时正确降级
  - 增量结果正确推送
  - 验证证据正确记录

### ACV-T011: DagTeamOrchestrator上下文集成

- **描述**: 在DagTeamOrchestrator中集成上下文传递和增量推送
- **实现要点**:
  - 新增成员变量: _contextPasser(ContextPasser), _incrementalPusher(IncrementalResultPusher)
  - orchestrateWithTeam:
    1. 创建根AgentContext(taskId=config.name, input=全局输入)
    2. 每个步骤执行前创建子上下文
    3. 通过ContextPasser传递上下文到目标Agent
    4. 步骤执行后推送增量结果
  - dispatchStepToLeader:
    1. 创建步骤级AgentContext
    2. 通过ContextPasser传递上下文到Leader
    3. 推送增量结果
  - 复用现有TeamMessenger和ExecutionEvidenceRecorder
- **测试要点**:
  - 编排时根上下文正确创建
  - 步骤间子上下文正确传递
  - 增量结果在编排过程中推送
  - 与现有证据链正确关联

### ACV-T012: agent_verification_records持久化

- **描述**: 新建验证记录表，实现完整CRUD
- **实现要点**:
  - 在sql/incremental目录生成DDL脚本
  - 使用crudgen生成PO/DAO/Service/Controller/Route
  - PO: AgentVerificationRecordsPO，使用@DataAssist和@QueryMappersGenerator注解
  - DAO: AgentVerificationRecordsDAO，使用@DAO注解，继承RootDAO
  - Service: AgentVerificationRecordsService，方法返回APIResult<T>
  - JSONB字段对应JsonValue类型
  - 验证记录在AgentResultValidator.validate完成后写入
- **测试要点**:
  - DDL可正确执行
  - CRUD接口完整可用
  - JSONB字段正确读写
  - 验证记录与执行证据链关联正确

### ACV-T013: 集成测试

- **描述**: 端到端集成测试，覆盖全部需求场景
- **实现要点**:
  - 测试场景1: 上下文传递端到端 - Manager→Leader→Worker上下文传递，验证子上下文继承约束
  - 测试场景2: 验证成功 - 执行结果符合验证规则，状态为Valid
  - 测试场景3: 验证失败+重试 - 执行结果不符合规则，自动重试指定次数
  - 测试场景4: 验证失败+降级 - 重试耗尽后执行降级策略
  - 测试场景5: 增量推送 - 步骤执行中间结果通过WebSocket推送
  - 测试场景6: 验证记录持久化 - 验证结果写入数据库并可查询
  - 测试场景7: 证据链完整性 - 验证环节与执行证据链正确关联
- **测试要点**:
  - 7个场景全部通过
  - 无内存泄漏
  - 异常场景不崩溃