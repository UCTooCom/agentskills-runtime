# AgentLoop观测评估飞轮 - 编码任务清单

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

| 任务ID | 任务名称 | 输入 | 输出 | 验收标准 | 工时 | 依赖 | 技能要求 |
|--------|---------|------|------|---------|------|------|---------|
| AL-T001 | 数据库表设计与DDL生成 | design.md数据模型 | sql/incremental/goai2026_p1_agent_loop.sql | DDL脚本符合uctoo-v4规范，包含2张表+索引+crontab注册 | 0.5天 | P0-3已完成 | SQL |
| AL-T002 | CRUD模块生成(loaddbinfo+crudgen) | DDL已执行 | Model/DAO/Service/Controller/Route骨架 | crudgen生成AgentLoopMetricsPO/DAO/Service和AgentLoopTuningConfigsPO/DAO/Service | 0.5天 | AL-T001(人工执行DDL后) | crudgen工具 |
| AL-T003 | AgentLoopTracer全链路追踪器 | EventHandlerManager, AuditEventHandler | src/interaction/agent_loop_tracer.cj | 可追踪Agent全生命周期，累计Token消耗，推送WebSocket事件 | 2天 | AL-T002 | cangjie-coder |
| AL-T004 | EvaluationEngine评估引擎 | ExecutionEvidencesDAO, AgentLoopMetricsService | src/interaction/evaluation_engine.cj | 可计算成功率/平均耗时/Token消耗/工具调用次数，结果持久化 | 2天 | AL-T002 | cangjie-coder |
| AL-T005 | EvaluationExecutor Crontab执行器 | SchedulerEngine, EvaluationEngine | src/app/services/crontab/executor/EvaluationExecutor.cj | 注册到ExecutorRegistry，可被Crontab调度触发评估 | 1天 | AL-T004 | cangjie-coder |
| AL-T006 | TuningEngine自进化调优引擎 | AgentLoopMetricsService, AgentLoopTuningConfigsService | src/interaction/tuning_engine.cj | 可基于评估结果选择调优策略，可应用提示词/工具选择/执行路径优化 | 2天 | AL-T004 | cangjie-coder |
| AL-T007 | WebSocket追踪事件集成 | AgentLoopTracer, WebSocketEventBridge | 扩展websocket_event_bridge.cj | 追踪事件可通过WebSocket实时推送到前端 | 1天 | AL-T003 | cangjie-coder |
| AL-T008 | AgentLoopMetrics API与Controller | AgentLoopMetricsService | AgentLoopMetricsController/Route | RESTful API可查询指标、手动触发评估、获取仪表板数据 | 1天 | AL-T004, AL-T002 | cangjie-coder |
| AL-T009 | Vue3仪表板前端 | AgentLoopMetrics API | web-admin前端页面 | 实时展示Agent运行状态、Token消耗统计、协作拓扑可视化 | 3天 | AL-T007, AL-T008 | tiny-vue-skill, frontend-design |
| AL-T010 | 集成测试与端到端验证 | 所有组件 | 测试报告 | 全链路追踪可观测、评估指标可持久化、调优策略可应用、仪表板可展示 | 1.5天 | AL-T003~T009 | Python测试 |

---

## 任务详细说明

### AL-T001: 数据库表设计与DDL生成

- **描述**: 创建 agent_loop_metrics 和 agent_loop_tuning_configs 数据库表，注册evaluation执行器到crontab_task_registry，创建评估定时任务
- **实现要点**:
  1. 编写DDL文件放置在 `sql/incremental/goai2026_p1_agent_loop.sql`
  2. agent_loop_metrics表：id(uuid), agent_id(uuid), session_id(varchar), evaluation_type(varchar), success_rate(float8), avg_duration_ms(int8), prompt_tokens(int8), completion_tokens(int8), total_tokens(int8), tool_call_count(int8), side_effect_count(int8), metrics_detail(jsonb), time_range_start(timestamptz(6)), time_range_end(timestamptz(6)), creator(uuid), created_at(timestamptz(6)), updated_at(timestamptz(6)), deleted_at(timestamptz(6))
  3. agent_loop_tuning_configs表：id(uuid), agent_id(uuid), strategy_type(varchar), config(jsonb), is_enabled(bool), last_applied_at(timestamptz(6)), creator(uuid), created_at(timestamptz(6)), updated_at(timestamptz(6)), deleted_at(timestamptz(6))
  4. 在crontab_task_registry注册evaluation执行器
  5. 在crontab表创建agent-loop-evaluation定时任务（每小时）
  6. 所有id字段使用 `uuid NOT NULL DEFAULT gen_random_uuid()`
  7. 所有时间字段使用 `timestamptz(6)`
- **测试要点**:
  - DDL脚本可在PostgreSQL上无错误执行
  - 表和索引创建成功
  - crontab_task_registry和crontab数据插入成功

---

### AL-T002: CRUD模块生成(loaddbinfo+crudgen)

- **描述**: 执行loaddbinfo刷新db_info表，使用crudgen生成AgentLoopMetrics和AgentLoopTuningConfigs的标准CRUD模块
- **实现要点**:
  1. **[人工操作]** 执行DDL脚本
  2. **[人工操作]** 运行 `loaddbinfo` 刷新db_info表
  3. **[人工操作]** 运行 `crudgen` 生成Model/DAO/Service/Controller/Route骨架
  4. **[人工操作]** 运行 `crudweb` 生成Web管理界面
  5. 验证生成的代码包含：AgentLoopMetricsPO, AgentLoopMetricsDAO, AgentLoopMetricsService, AgentLoopMetricsController, AgentLoopMetricsRoute
  6. 验证生成的代码包含：AgentLoopTuningConfigsPO, AgentLoopTuningConfigsDAO, AgentLoopTuningConfigsService, AgentLoopTuningConfigsController, AgentLoopTuningConfigsRoute
- **测试要点**:
  - crudgen生成代码无编译错误
  - DAO接口包含标准CRUD方法
  - Service方法返回APIResult<T>
  - PO类包含@DataAssist[fields]和@QueryMappersGenerator注解

---

### AL-T003: AgentLoopTracer全链路追踪器

- **描述**: 实现AgentLoopTracer，整合AuditEventHandler证据记录+Token消耗累计+WebSocket实时推送，实现Agent执行全链路追踪
- **实现要点**:
  1. 创建 `src/interaction/agent_loop_tracer.cj`，package magic.interaction
  2. 定义SessionTrace数据类：sessionId, agentName, startTime, endTime, status, evidenceIds, tokenUsage, toolCallCount, sideEffectCount
  3. 定义TokenUsage数据类：promptTokens, completionTokens, totalTokens
  4. AgentLoopTracer持有AuditEventHandler和WebSocketEventBridge引用
  5. 实现onAgentStart：委托AuditEventHandler.onAgentStart，创建SessionTrace，推送agent_start事件
  6. 实现onAgentEnd：委托AuditEventHandler.onAgentEnd，更新SessionTrace，推送agent_end事件
  7. 实现onToolCall：委托AuditEventHandler.onToolCall，累计toolCallCount，推送tool_call事件
  8. 实现onTokenUsage：累计Token消耗到SessionTrace，推送token_usage事件
  9. 实现pushTraceEvent：通过WebSocketEventBridge推送事件
  10. 实现getSessionTrace/getActiveTraces查询方法
  11. 在EventHandlerManager.global注册AgentLoopTracer的事件处理器
- **关键文件**:
  - `src/interaction/agent_loop_tracer.cj`（新增）
- **测试要点**:
  - Agent启动/结束可追踪
  - Token消耗可累计
  - 工具调用次数可统计
  - 追踪事件可推送到WebSocket

---

### AL-T004: EvaluationEngine评估引擎

- **描述**: 实现EvaluationEngine，基于execution_evidences表数据计算Agent执行质量评估指标，持久化到agent_loop_metrics表
- **实现要点**:
  1. 创建 `src/interaction/evaluation_engine.cj`，package magic.interaction
  2. EvaluationEngine持有ExecutionEvidencesService和AgentLoopMetricsService引用
  3. 实现evaluateSession(sessionId)：查询execution_evidences按session_id，计算成功率/平均耗时/工具调用次数/副作用数量，创建AgentLoopMetricsPO持久化
  4. 实现evaluateAgent(agentId, timeRangeStart, timeRangeEnd)：查询execution_evidences按agent_id和时间范围，聚合计算指标
  5. 实现evaluateAll(timeRangeStart, timeRangeEnd)：遍历所有Agent执行评估
  6. calculateSuccessRate：统计Completed/Failed比例
  7. calculateAvgDuration：计算duration_ms平均值
  8. calculateToolCallCount：统计step_type=tool_call的数量
  9. 评估结果写入agent_loop_metrics表
  10. 评估结果同时推送到WebSocket（仪表板实时更新）
- **关键文件**:
  - `src/interaction/evaluation_engine.cj`（新增）
- **测试要点**:
  - 单会话评估可计算成功率/平均耗时
  - Agent维度评估可聚合指标
  - 评估结果可持久化到agent_loop_metrics表
  - 评估结果可推送到WebSocket

---

### AL-T005: EvaluationExecutor Crontab执行器

- **描述**: 实现EvaluationExecutor，注册到ExecutorRegistry，使评估任务可被Crontab调度引擎周期性触发
- **实现要点**:
  1. 创建 `src/app/services/crontab/executor/EvaluationExecutor.cj`，package magic.app.services.crontab.executor
  2. 实现CrontabExecutor接口：validate(taskUri)和execute(context)
  3. validate：验证evaluation://URI格式
  4. execute：解析parameters获取evaluationType和timeRangeHours，调用EvaluationEngine.evaluateAll()
  5. 在SchedulerEngine.initExecutors()中注册：`executorRegistry.register("evaluation", EvaluationExecutor())`
  6. 执行结果写入crontab_log表（已有AsyncLogWriter机制）
  7. 支持手动触发（通过CrontabSchedulerService.triggerTask）
- **关键文件**:
  - `src/app/services/crontab/executor/EvaluationExecutor.cj`（新增）
  - `src/app/services/crontab/SchedulerEngine.cj`（修改：注册执行器）
- **测试要点**:
  - evaluation://URI验证通过
  - Crontab调度可触发评估
  - 评估结果记录到crontab_log
  - 手动触发评估可执行

---

### AL-T006: TuningEngine自进化调优引擎

- **描述**: 实现TuningEngine，基于评估结果自动选择和应用调优策略，支持提示词优化/工具选择优化/执行路径优化
- **实现要点**:
  1. 创建 `src/interaction/tuning_engine.cj`，package magic.interaction
  2. 定义TuningStrategy数据类：strategyType, promptOptimization, toolSelectionOptimization, executionPathOptimization
  3. 定义PromptOptimization：templateId, adjustments
  4. 定义ToolSelectionOptimization：preferredTools, excludedTools
  5. 定义ExecutionPathOptimization：maxRetries, timeoutMs, parallelism
  6. 定义TuningResult：agentId, strategy, beforeMetrics, afterMetrics, appliedAt
  7. TuningEngine持有AgentLoopMetricsService和AgentLoopTuningConfigsService引用
  8. analyzeAndTune(agentId)：读取最近评估指标，选择调优策略，应用调优
  9. selectStrategy(metrics)：基于阈值判断选择策略类型
     - successRate < 0.7 → prompt_optimization
     - toolCallCount异常高 → tool_selection_optimization
     - avgDurationMs异常高 → execution_path_optimization
  10. applyTuning(agentId, strategy)：将策略写入agent_loop_tuning_configs表，更新lastAppliedAt
  11. getTuningHistory(agentId)：查询调优历史
  12. 调优策略可配置（通过agent_loop_tuning_configs表的is_enabled字段）
- **关键文件**:
  - `src/interaction/tuning_engine.cj`（新增）
- **测试要点**:
  - 低成功率可触发提示词优化
  - 高工具调用可触发工具选择优化
  - 高耗时可触发执行路径优化
  - 调优策略可持久化到agent_loop_tuning_configs表
  - 调优历史可查询

---

### AL-T007: WebSocket追踪事件集成

- **描述**: 扩展WebSocketEventBridge，支持AgentLoopTracer的追踪事件实时推送到前端
- **实现要点**:
  1. 在WebSocketEventBridge.registerGlobalHandlers()中新增AgentLoopTracer相关事件处理器
  2. 新增事件类型：trace_start, trace_step, trace_token_usage, trace_end, evaluation_result, tuning_applied
  3. 追踪事件包含：sessionId, agentName, eventType, timestamp, data
  4. 评估结果事件包含：agentId, successRate, avgDurationMs, totalTokens
  5. 调优事件包含：agentId, strategyType, appliedAt
  6. 事件格式与已有WebSocketEventBridge事件格式保持一致
  7. 使用WebSocketSessionManager推送消息到已连接的前端客户端
- **关键文件**:
  - `src/app/services/bridge/websocket_event_bridge.cj`（修改）
- **测试要点**:
  - 追踪事件可通过WebSocket推送
  - 评估结果事件可通过WebSocket推送
  - 前端可接收到实时事件

---

### AL-T008: AgentLoopMetrics API与Controller

- **描述**: 实现AgentLoopMetrics的RESTful API，支持指标查询、手动触发评估、获取仪表板数据
- **实现要点**:
  1. 基于crudgen生成的AgentLoopMetricsController扩展定制方法
  2. 新增 triggerEvaluation()：POST /api/agent-loop-metrics/evaluate，接收agentId/evaluationType/timeRangeHours参数，调用EvaluationEngine
  3. 新增 getDashboardData()：GET /api/agent-loop-metrics/dashboard，返回仪表板聚合数据
     - 各Agent成功率排行
     - Token消耗Top N
     - 最近24小时执行趋势
     - 活跃Agent列表
  4. 新增 getTuningConfigs()：GET /api/agent-loop-metrics/tuning-configs，返回调优策略配置
  5. 新增 updateTuningConfig()：PUT /api/agent-loop-metrics/tuning-configs/:id，更新调优策略配置
  6. 在AutoRouteConfig中注册路由
  7. 定制代码写在 `//#region AutoCreateCode` 区域外
- **关键文件**:
  - `src/app/controllers/uctoo/agent_loop_metrics/AgentLoopMetricsController.cj`（修改）
  - `src/app/routes/uctoo/agent_loop_metrics/AgentLoopMetricsRoute.cj`（修改）
- **测试要点**:
  - GET /api/agent-loop-metrics 可分页查询指标
  - POST /api/agent-loop-metrics/evaluate 可手动触发评估
  - GET /api/agent-loop-metrics/dashboard 可获取仪表板数据
  - API返回格式符合uctoo-v4规范

---

### AL-T009: Vue3仪表板前端

- **描述**: 使用Vue 3 + OpenTiny Vue实现Agent运行状态实时展示仪表板，包含Token消耗统计、协作拓扑可视化
- **实现要点**:
  1. 创建AgentLoop仪表板页面组件
  2. 使用OpenTiny Vue组件库：TinyChart（图表）、TinyGrid（数据表格）、TinyCard（卡片）
  3. 页面布局：
     - 顶部：实时状态概览卡片（活跃Agent数、总Token消耗、平均成功率、平均耗时）
     - 中部左：Token消耗趋势图（折线图，按小时聚合）
     - 中部右：成功率排行（柱状图，按Agent分组）
     - 底部左：Agent执行列表（数据表格，支持分页和筛选）
     - 底部右：协作拓扑可视化（展示Agent间消息传递关系）
  4. WebSocket实时数据更新：连接WebSocket接收trace/evaluation/tuning事件
  5. 使用pinia-orm管理前端状态
  6. 符合UMI规范的路由配置
  7. 协作拓扑可视化：基于TeamMessenger消息历史，展示Agent间消息传递的有向图
- **关键文件**:
  - 前端页面组件（web-admin目录下）
- **测试要点**:
  - 仪表板可正确展示Agent运行状态
  - Token消耗统计图表可展示
  - WebSocket实时数据可更新
  - 协作拓扑可视化可展示Agent间关系

---

### AL-T010: 集成测试与端到端验证

- **描述**: 编写集成测试，验证AgentLoop观测评估飞轮的完整功能链路
- **实现要点**:
  1. 使用Python编写测试脚本（test_agent_loop.py）
  2. 测试场景1：全链路追踪
     - 触发Agent执行
     - 验证execution_evidences表有记录
     - 验证WebSocket事件推送
     - 验证SessionTrace数据完整
  3. 测试场景2：周期性评估
     - 手动触发评估API
     - 验证agent_loop_metrics表有记录
     - 验证评估指标计算正确
  4. 测试场景3：自进化调优
     - 设置低成功率场景
     - 触发评估
     - 验证agent_loop_tuning_configs表有调优策略记录
  5. 测试场景4：仪表板数据
     - 调用dashboard API
     - 验证返回数据格式正确
  6. 测试场景5：Crontab调度
     - 验证evaluation执行器注册成功
     - 验证定时任务可触发评估
- **测试要点**:
  - 全链路追踪可观测
  - 评估指标可持久化且计算正确
  - 调优策略可自动选择和应用
  - 仪表板API返回数据正确
  - Crontab调度可触发评估