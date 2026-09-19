# AI 自主驱动长程任务系统 — 编码任务分解

> 基于 spec.md 需求规格与 design.md 技术设计文档生成。
> 实施原则：**复用优先**（复用已有 SchedulerEngine/DagScheduler/CheckpointManager/AIP/WebSocket/SkillBridge/三轨插件/评估调优等基础设施）、**L3 进程隔离**（mode:process 插件形式实现）、**D-P-H-E 四层分层**、**确定性优先**。
> 仓颉代码编写须使用 cangjie-coder 技能，严禁运行 cjpm build 编译（编译由人工在独立 cmd 环境执行）。

## 1. 数据库表与 CRUD 基础设施

### 1.1 编写长程任务专用表 DDL
- [ ] 编写 `sql/incremental/long_running_task.sql` DDL 文件，包含 4 张新增表建表语句：`long_running_task_config`（长程任务配置表，含 task_id/max_rounds/max_round_duration_ms/max_task_duration_ms/checkpoint_strategy/degradation_chain/quality_gate）、`long_running_task_progress`（进度表，含 task_id/completed_steps/total_steps/current_step/estimated_remaining_ms/intermediate_result）、`long_running_task_artifact`（产物表，含 task_id/artifact_path/artifact_type/verification_status/verification_result）、`long_running_task_evolution`（自进化记录表，含 agent_id/round/root_cause/optimization_plan/anti_regression/skill_md_updates），各表均含 id(UUID)/creator/created_at/updated_at 标准字段
- [ ] 在 DDL 中为 4 张表添加必要索引：`long_running_task_config.task_id` 唯一索引、`long_running_task_progress.task_id` 唯一索引、`long_running_task_artifact.task_id` 普通索引、`long_running_task_evolution.agent_id` 普通索引，确保任务树递归查询延迟 ≤ 100ms

### 1.2 执行 DDL 并生成标准 CRUD
- [ ] 通知人工在数据库环境执行 `sql/incremental/long_running_task.sql` DDL，确认 4 张表创建成功
- [ ] 运行 `loaddbinfo` 刷新数据库表元信息，确认 4 张新表已被识别
- [ ] 运行 `crudgen` 生成 4 张表的标准 CRUD 代码（Controller/Service/PO/DAO），遵循 uctoo-v4 模块开发流程
- [ ] 运行 `crudweb` 生成前端 CRUD 页面（如需），确认生成代码无报错
- [ ] 验证 4 张表的 CRUD API（add/edit/del/:id/:limit/:page）均可正常调用，行级权限（creator=userId）过滤生效

## 2. L3 插件工程骨架搭建

### 2.1 创建插件目录结构
- [ ] 创建 `skills/long-running-task/` 目录，参照 `skills/due_diligence_agent/` 工程结构建立子目录：`src/`（P 层仓颉插件代码）、`scripts/`（D 层 Python 脚本）、`output/`（产物目录），并在 `output/` 下按 SOP 阶段建立 `parsed/planned/executed/extended/verified/` 子目录

### 2.2 编写 P 层仓颉插件工程文件
- [ ] 编写 `skills/long-running-task/cjpm.toml`，声明插件为独立 executable 工程，依赖 `ystyle::cordis_plugin`、`ystyle::cordis_core`、`jsonvalue`、`ystyle::jsonrpc`，参照 `skills/due_diligence_agent/cjpm.toml` 配置
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/main.cj`，实现 L3 插件进程入口，经 `PluginRuntime.run` 拉起，注册 `LrtHandlers` 和 `LrtEffects`，参照 `skills/due_diligence_agent/src/main.cj:15-29` 的 JSON-RPC over stdio 通信模式
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_handlers.cj`，实现路由分发，注册 `long_running_task_config/progress/artifact/evolution` 四张表标准 CRUD 路由 + 自定义路由（`lrt-plan`/`lrt-execute`/`lrt-intervene`/`lrt-verify`/`lrt-evolve`），参照 `skills/due_diligence_agent/src/dd_handlers.cj` 路由分发模式
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_persist_service.cj`，实现幂等读写封装（先查后写 + 行级权限 creator=userId + 批量隔离单条失败不中断），复用 `skills/due_diligence_agent/src/persist_service.cj:17-73` 的 PersistService 模式
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_effects.cj`，实现可逆效果注册（卸载时逆序执行清理），参照 `skills/due_diligence_agent/src/dd_effects.cj` 可逆效果注册框架

### 2.3 编写 E 层插件配置与声明文件
- [ ] 编写 `skills/long-running-task/plugin.yaml`，声明 `mode: process`、`protocol: jsonrpc-stdio`、`autoRestart: true`、`enabled: true`，配置 `config`（maxRounds/maxRoundDurationMs/maxTaskDurationMs/maxConcurrentTasks/checkpointStrategy/degradationChain/qualityGate）、`tableWhitelist`（列出 agent_tasks/agent_contexts/crontab/crontab_log/agent_loop_metrics/agent_loop_tuning_configs/long_running_task_config/progress/artifact/evolution/aip_interaction_session/aip_interaction_task 全部需访问表）、`routes`（4 张表 CRUD 路由 + 7 个自定义路由），参照 `skills/due_diligence_agent/plugin.yaml` 配置模式
- [ ] 编写 `skills/long-running-task/COMPOSITION.yaml` 初版骨架，声明 6 步 SOP 步骤名（parse-goal/plan-tasks/execute-rounds/notify-progress/extend-capability/verify-and-deliver）和 depends_on 依赖关系，step_type 和 input 待各组件实现后补充完善
- [ ] 编写 `skills/long-running-task/SKILL.md` 初版骨架，声明 6 步 SOP 流程（目标解析→任务规划→调度执行→进度通知→能力扩展→验核交付）和显式约束框架（任务完成判定/遇挫不停重试/SOP 全步完成强制约束/产出文件校验），错误行为示例待自进化闭环运行后补充

### 2.4 编译验证插件骨架
- [ ] 通知人工在单独 cmd 环境执行 `cjpm build` 编译 `skills/long-running-task/` 插件工程，收集编译结果反馈
- [ ] 若编译失败，使用 cangjie-coder 技能根据编译错误修复代码，重新通知人工编译，直至编译通过
- [ ] 验证插件经 `CordisHostManager` 加载成功，`agent_skills.runtime_status` 回写为 running，4 张表 CRUD 路由可经 JSON-RPC 调用

## 3. AI 自主规划组件实现（LrtPlanner）

### 3.1 实现目标解析与任务树分解
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_planner.cj`，实现 `LrtPlanner.plan` 方法：接收任务目标（自然语言）+ 环境状态，复用 `plan_react_executor` 的 `problem_decompose/subtask` 能力分解任务树，输出含 parent_task_id/payload/skill_sequence/acceptance_criteria 的任务树结构
- [ ] 在 `LrtPlanner.plan` 中实现规划结果持久化：将分解的子任务经 `LrtPersistService` 写入 `agent_tasks` 表，根任务 parent_task_id=NULL，子任务 parent_task_id 指向根任务，遵循幂等落库（先查后写 + creator=userId）
- [ ] 实现 `LrtPlanner` 的技能发现：复用 `SkillManager` 获取已安装技能清单（含 cangjie-coder/crud-generator/sdd-flow/skill-creator 等），供 AI 自主选择技能编排

### 3.2 实现动态重规划
- [ ] 在 `LrtPlanner` 中实现 `LrtPlanner.replan` 方法：接收重规划触发事件（子任务失败/环境变更/目标调整/追加约束）+ 已有规划上下文，基于已完成子任务结果增量调整未执行部分规划，保留已完成子任务不重复执行
- [ ] 在 `LrtPlanner.replan` 中实现重规划结果持久化：更新 `agent_tasks` 表中未执行子任务的 payload/skill_sequence，新增调整后的子任务记录

### 3.3 实现能力缺口检测与编排
- [ ] 在 `LrtPlanner` 规划阶段实现能力缺口检测：当目标所需技能不存在于已安装技能清单时，自主编排"skill-creator 创建技能"或"cangjie-coder 编写代码"子任务，经质量闸门后注册到 `agent_skills` 表
- [ ] 在 `LrtPlanner` 编排代码生成子任务时，强制追加 `code-gen-verifier` 验证子任务，未通过则触发 `cangjie-coder` 修复子任务，形成质量闸门闭环
- [ ] 在 `LrtHandlers` 中注册 `lrt-plan` 自定义路由，调用 `LrtPlanner.plan/replan`，经 JSON-RPC over stdio 暴露给宿主

## 4. 执行回合与子任务派发实现（LrtExecutor）

### 4.1 实现执行回合循环
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_executor.cj`，实现 `LrtExecutor.executeRound` 方法：包装扩展 `AgentExecutionExecutor` 多步循环，回合内遵循"加载检查点→AI 自主规划→DAG 步骤执行→产物校验→保存检查点→进度通知→SOP 完成判定"流程
- [ ] 在 `LrtExecutor` 中实现检查点恢复：回合开始时复用 `CheckpointManager.loadLatestCheckpoint` 加载最新检查点，从断点续执行而非从头开始；回合结束后复用 `CheckpointManager.saveCheckpoint` 保存检查点到 `agent_contexts` 表，metadata 含 task_id/chat_round/saved_at
- [ ] 在 `LrtExecutor` 中实现回合超时处理：单回合超过 `maxRoundDurationMs`（默认 30 分钟）时保存检查点，标记回合超时，更新 `agent_tasks.status=0`（待处理）等待下次调度触发

### 4.2 实现 DAG 步骤执行与降级策略链
- [ ] 在 `LrtExecutor` 中集成 `DagScheduler`：解析 `COMPOSITION.yaml` 构建步骤 DAG，按依赖关系拓扑排序执行，无依赖步骤可并行，步骤间产出通过 `${step.output}` 引用传递
- [ ] 在 `LrtExecutor` 中实现降级策略链执行：每步声明 `degradation_chain`（cli_execute→builtin_tool→llm→template），按链依次尝试，遵循"遇挫不停"原则——任何步骤失败先重试 1 次，重试仍失败才换方案，全部失败时在 answer 中报告尝试次数和失败原因
- [ ] 在 `LrtExecutor` 中实现 step_type 分发：`script` 类型经 cli_execute 运行脚本、`plugin` 类型调用插件路由、`output` 类型聚合输出，支持条件执行（condition 字段控制步骤是否执行）

### 4.3 实现子任务派发与结果聚合
- [ ] 在 `LrtExecutor` 中实现子任务派发：主 Agent 决策执行子任务时创建子 Agent 并派发，子任务经 `LrtPersistService` 写入 `agent_tasks` 表（parent_task_id 指向父任务），复用 `dag_team_orchestrator` 子 Agent 编排能力
- [ ] 在 `LrtExecutor` 中实现子任务结果聚合：子任务完成后回调更新子任务 `result` 字段并通知父任务，主 Agent 收到通知后决策下一步动作（重试/跳过/降级/上报）
- [ ] 在 `LrtExecutor` 中实现并发控制：遵守 `crontab.concurrentable` 配置，concurrentable=false 时同一任务新触发等待前一次执行完成
- [ ] 在 `LrtHandlers` 中注册 `lrt-execute` 自定义路由，调用 `LrtExecutor.executeRound`，经 JSON-RPC over stdio 暴露给宿主

## 5. 用户干预服务实现（LrtInterventionService）

### 5.1 实现暂停与恢复
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_intervention_service.cj`，实现 `LrtInterventionService.pause` 方法：等待当前回合完成或超时后，更新 `agent_tasks.status=5`（暂停）、`crontab.status=2`（禁用），保存检查点不删除
- [ ] 实现 `LrtInterventionService.resume` 方法：更新 `crontab.status=1`（启用）、`agent_tasks.status=1`（进行中），下次调度触发从最新检查点恢复执行

### 5.2 实现取消与目标调整
- [ ] 实现 `LrtInterventionService.cancel` 方法：优雅取消，当前步骤完成后更新 `agent_tasks.status=4`（已取消），保留 result 已有结果
- [ ] 实现 `LrtInterventionService.forceCancel` 方法：强制取消，立即终止执行，更新 `agent_tasks.status=4`（已取消）
- [ ] 实现 `LrtInterventionService.adjustGoal` 方法：接收新目标，触发 `LrtPlanner.replan` 基于新目标调整后续规划
- [ ] 实现 `LrtInterventionService.addConstraint` 方法：接收新约束，触发 `LrtPlanner.replan` 基于新约束调整后续规划

### 5.3 实现干预渠道与路由注册
- [ ] 在 `LrtInterventionService` 中实现干预操作的状态校验：已完成的任务不能暂停、已取消的任务不能恢复等，非法操作返回 40003 错误码
- [ ] 在 `LrtHandlers` 中注册 `lrt-intervene` 自定义路由，调用 `LrtInterventionService` 各方法，经 JSON-RPC over stdio 暴露给宿主
- [ ] 确保干预操作可通过标准 API（HTTP RESTful）和 WebSocket 均可触发，复用已有 API 路由和 WebSocket 通道

## 6. 产物校验与验核交付实现

### 6.1 实现每步产物校验（LrtArtifactVerifier）
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_artifact_verifier.cj`，实现 `LrtArtifactVerifier.verify` 方法：校验产出文件存在且非空（经 file_read 或 cli_execute 检查）
- [ ] 在 `LrtArtifactVerifier` 中实现日期匹配校验：检查产出文件日期是否匹配用户要求，旧日期文件不算完成（如用户要 2026-08-10 的产出，output/brief/2026-08-11.md 旧文件不算完成）
- [ ] 在 `LrtArtifactVerifier` 中实现内容校验：打开产出文件检查内容是否包含本次执行的数据，非空文件且非旧内容才算完成
- [ ] 在 `LrtArtifactVerifier` 中实现 answer 前终检：生成最终 answer 前确认全部关键产出物均已存在，缺失则补执行对应步骤，禁止提前终止
- [ ] 在 `LrtArtifactVerifier` 中实现校验失败处理：校验失败触发补执行，补执行后仍失败则触发降级策略链

### 6.2 实现自主验核与报告生成（LrtVerifier）
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_verifier.cj`，实现 `LrtVerifier.verify` 方法：AI 自主比对产物与原始目标，生成结构化验核报告（含 goalAchievement 目标达成度 0.0-1.0/artifacts 产物清单/testResults 测试结果/knownIssues 已知问题/suggestions 建议）
- [ ] 在 `LrtVerifier` 中实现验核报告持久化：将验核结果写入 `long_running_task_artifact` 表（verification_status/verification_result 字段）
- [ ] 在 `LrtVerifier` 中实现验核指标上报：复用 `EvaluationExecutor` 将验核结果上报到 `agent_loop_metrics` 表（success_rate/total_tokens/tool_call_count 等）

### 6.3 实现用户评审闭环与产物交付
- [ ] 在 `LrtVerifier` 中实现用户评审推送：验核报告生成后经 `WebSocketEventBridge` 推送给用户评审，用户可确认交付/要求改进/放弃
- [ ] 在 `LrtVerifier` 中实现产物交付：用户确认交付后，产物落地到文件系统，经 `SyncManager`+`ChangeDetector` 同步到数据库，更新 `agent_tasks.status=2`（完成）
- [ ] 在 `LrtVerifier` 中实现迭代改进闭环：用户要求改进时，基于反馈触发 `LrtPlanner.replan` 调整规划并继续执行，形成闭环
- [ ] 在 `LrtHandlers` 中注册 `lrt-verify` 自定义路由，调用 `LrtVerifier.verify`，经 JSON-RPC over stdio 暴露给宿主

## 7. 自进化闭环实现

### 7.1 实现问题分级（LrtIssueClassifier）
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_issue_classifier.cj`，实现 `LrtIssueClassifier.classify` 方法：基于日志（crontab_log + agent_tasks.error_message）和评估指标（agent_loop_metrics）按 P0 阻断/P1 严重/P2 中等/P3 低分级
- [ ] 在 `LrtIssueClassifier` 中实现分级规则：P0=任务完全阻断无法继续、P1=核心功能异常但有 workaround、P2=非核心功能异常、P3=优化建议，输出含分级+根因+修复建议的问题列表

### 7.2 实现防回退注册表（LrtAntiRegressionRegistry）
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_anti_regression_registry.cj`，实现 `LrtAntiRegressionRegistry.register` 方法：结构化记录错误行为示例和正确行为示例（含问题 ID/错误行为描述/正确行为描述/修复版本）
- [ ] 在 `LrtAntiRegressionRegistry` 中实现显式约束注入：将防回退约束（任务完成判定/遇挫不停重试/SOP 全步完成强制约束/产出文件校验等）注入 `SKILL.md`，生成 SKILL.md 显式约束片段

### 7.3 实现自进化五环节闭环（LrtSelfEvolutionLoop）
- [ ] 使用 cangjie-coder 技能编写 `skills/long-running-task/src/lrt_self_evolution_loop.cj`，实现 `LrtSelfEvolutionLoop.run` 方法，串联五环节闭环：
- [ ] 环节 1 实测驱动：复用 `EvaluationExecutor` 采集 `agent_loop_metrics` 指标 + `crontab_log` 日志，基于实测日志证据而非猜测
- [ ] 环节 2 根因分析：从日志中定位问题根因，追溯到底层代码或配置缺陷而非仅看表面现象，调用 `LrtIssueClassifier` 按 P0-P3 分级
- [ ] 环节 3 增量优化：沿用原有设计架构增量优化，复用现有基础设施不重建已有能力，制定优化方案并修复代码/配置
- [ ] 环节 4 防回退：调用 `LrtAntiRegressionRegistry.register` 增加防御性设计和错误行为示例（严禁复现）
- [ ] 环节 5 显式约束注入：将防回退约束注入 `SKILL.md`，更新 `agent_loop_tuning_configs` 调优策略，记录自进化轮次到 `long_running_task_evolution` 表
- [ ] 在 `LrtSelfEvolutionLoop` 中实现前后端协同：修复前端代码后自主编排"npm run build"子任务，经 cli_execute 执行，产物经 sync 服务同步
- [ ] 在 `LrtHandlers` 中注册 `lrt-evolve` 自定义路由，调用 `LrtSelfEvolutionLoop.run`，经 JSON-RPC over stdio 暴露给宿主

## 8. D 层脚本与 E 层声明实现

### 8.1 编写 D 层 Python 脚本
- [ ] 编写 `skills/long-running-task/scripts/parse_goal.py` 目标解析脚本：接收自然语言目标，结构化解析为 goal_struct.json（含目标类型/约束/预期产物），经 HTTP API 调用宿主 MCP 开放服务（POST /api/v1/uctoo/mcp/open/call），使用 http_lib 库，不禁用 SSL 校验（verify=True）
- [ ] 编写 `skills/long-running-task/scripts/notify_progress.py` 进度通知脚本：接收任务进度数据，经 WebSocket/SSE 推送进度事件给用户，复用宿主通知通道
- [ ] 编写 `skills/long-running-task/scripts/extend_capability.py` 能力扩展脚本：接收技能缺口信息，自主编排"skill-creator 创建技能"或"cangjie-coder 编写代码"子任务，经 cli_execute 调用对应技能

### 8.2 完善 COMPOSITION.yaml 步骤编排声明
- [ ] 完善 `skills/long-running-task/COMPOSITION.yaml`，声明 6 步 SOP 完整编排：parse-goal（script，depends_on:[]）→plan-tasks（plugin，depends_on:[parse-goal]）→execute-rounds（plugin，depends_on:[plan-tasks]，含 degradation_chain）→notify-progress（script，depends_on:[execute-rounds]）→extend-capability（script，depends_on:[execute-rounds]，含 condition）→verify-and-deliver（plugin，depends_on:[notify-progress,extend-capability]）→output-result（output，depends_on:[verify-and-deliver]）
- [ ] 在 `COMPOSITION.yaml` 每步声明 input（支持 `${input.xxx}` 和 `${step-name.output}` 引用）、acceptance_criteria（验收条件）、step_type（script/plugin/output）、script/plugin_route 路径
- [ ] 在 `COMPOSITION.yaml` 的 execute-rounds 步骤声明 degradation_chain（cli_execute→builtin_tool→llm→template），在 extend-capability 步骤声明 condition（skill_gaps.json 非空时执行）

### 8.3 完善 SKILL.md SOP 声明与显式约束
- [ ] 完善 `skills/long-running-task/SKILL.md`，声明 6 步 SOP 全流程（目标解析→任务规划→调度执行→进度通知→能力扩展→验核交付），每步含脚本/技能、输入、输出、验收条件说明
- [ ] 在 `SKILL.md` 中编写显式约束：任务完成判定（禁止误判完成，必须校验日期匹配+内容校验）、遇挫不停重试（失败先重试 1 次再换方案）、SOP 全步完成强制约束（禁止跳过中间步骤直接 answer）、产出文件校验（每步校验产出存在且非空）
- [ ] 在 `SKILL.md` 中编写降级策略链说明：工具优先级 cli_execute→builtin_tool→llm→template，LLM 不可用降级模板生成，数据库连接失败降级生成 SQL 文件

## 9. 用户 API 与进度通知扩展

### 9.1 实现 7 个用户 API
- [ ] 实现 `POST /api/v1/uctoo/long_running_task/add` 提交长程任务目标 API：接收 goal/priority/cron/constraints/agentId，创建根任务到 agent_tasks 表（status=0），创建 crontab 记录（task=agent_execution://<agentId>），返回 taskId/agentId/crontabId
- [ ] 实现 `POST /api/v1/uctoo/long_running_task/intervene` 用户干预 API：接收 taskId/action（pause/resume/cancel/force_cancel/adjust_goal/add_constraint）/content，调用 `LrtInterventionService` 对应方法
- [ ] 实现 `GET /api/v1/uctoo/long_running_task/tree/:rootId` 查询任务树 API：递归查询 parent_task_id 关联的全部子任务，构建树形结构返回，各节点含状态和进度信息
- [ ] 实现 `GET /api/v1/uctoo/long_running_task/progress/:taskId` 查询任务进度 API：从 `long_running_task_progress` 表读取 completed_steps/total_steps/current_step/estimated_remaining_ms/intermediate_result
- [ ] 实现 `GET /api/v1/uctoo/long_running_task/checkpoints/:taskId` 查询检查点列表 API：复用 `CheckpointManager.listCheckpoints` 按 task_id 查询检查点列表
- [ ] 实现 `POST /api/v1/uctoo/long_running_task/verify/:taskId` 触发自主验核 API：调用 `LrtVerifier.verify` 生成验核报告
- [ ] 实现 `POST /api/v1/uctoo/long_running_task/evolve/:agentId` 触发自进化闭环 API：调用 `LrtSelfEvolutionLoop.run` 执行五环节闭环

### 9.2 扩展进度通知事件类型
- [ ] 扩展 `WebSocketEventBridge` 和 `SseEventBridge`，新增 8 类长程任务专用事件 handler：`step_start`/`step_complete`/`step_failed`/`checkpoint_saved`/`progress_update`/`subtask_dispatched`/`subtask_completed`/`goal_achieved`，复用已有 `buildEventJson`/`pushEvent` 基础设施
- [ ] 在长程任务专用事件中增加扩展字段：`stepIndex`（当前步骤序号）/`totalSteps`（总步骤数）/`estimatedRemaining`（预估剩余时间）/`intermediateResult`（中间结果预览），确保进度通知延迟 ≤ 1s

### 9.3 扩展任务树可视化查询
- [ ] 扩展 `AgentTasksService`，新增 `getTaskTree(rootTaskId)` 方法：递归查询 parent_task_id 关联的全部子任务，构建树形结构返回，确保单层子任务数 ≤ 100 时查询延迟 ≤ 100ms
- [ ] 在 `LrtExecutor` 执行过程中更新 `long_running_task_progress` 表：每步完成后更新 completed_steps/current_step/estimated_remaining_ms/intermediate_result，供进度查询 API 读取

## 10. 集成测试与端到端验证

### 10.1 单元测试
- [ ] 编写 `LrtPlanner` 单元测试：验证目标解析、任务树分解、技能选择、动态重规划的正确性，覆盖目标模糊不可规划、技能不可用等异常场景
- [ ] 编写 `LrtExecutor` 单元测试：验证执行回合循环、检查点保存与恢复、DAG 步骤执行、降级策略链、子任务派发与结果聚合的正确性，覆盖回合超时、子 Agent 失败、检查点损坏等异常场景
- [ ] 编写 `LrtInterventionService` 单元测试：验证暂停/恢复/取消/强制取消/目标调整/追加约束的正确性，覆盖暂停时回合未完成、恢复时检查点丢失等异常场景
- [ ] 编写 `LrtArtifactVerifier` 和 `LrtVerifier` 单元测试：验证产物校验（文件存在/非空/日期匹配/内容校验）、验核报告生成、用户评审闭环的正确性，覆盖产物校验反复失败、旧文件干扰判定等异常场景

### 10.2 集成测试
- [ ] 编写 L3 插件加载集成测试：验证插件经 `CordisHostManager` 加载、CRUD 路由可用、自定义路由（lrt-plan/lrt-execute/lrt-intervene/lrt-verify/lrt-evolve）可调用的正确性
- [ ] 编写 6 步 SOP 全流程集成测试：验证 parse-goal→plan-tasks→execute-rounds→notify-progress→extend-capability→verify-and-deliver 全步骤串行/并行执行、产物传递、降级策略链的正确性
- [ ] 编写调度引擎集成测试：验证长程任务经 crontab 配置驱动 `SchedulerEngine` 按 CRON 触发执行回合、检查点恢复、并发控制的正确性

### 10.3 端到端测试
- [ ] 编写端到端测试用例：用户提交目标"为某业务生成完整 CRUD 模块并上线"→系统自主规划→调度执行→进度推送→验核交付→用户确认，验证全闭环可执行
- [ ] 编写端到端测试用例：用户执行过程中暂停→恢复→调整目标→继续执行→验核交付，验证干预闭环可执行
- [ ] 编写端到端测试用例：模拟插件进程崩溃→autoRestart 自动重启→从检查点恢复执行，验证故障隔离与恢复可执行
- [ ] 编写端到端测试用例：触发自进化闭环→基于实测日志根因分析→增量优化→防回退约束注入→验证下一轮执行改善

### 10.4 回归测试
- [ ] 编写回归测试用例：验证已有 `AgentExecutionExecutor` 执行流程不受长程任务系统影响，现有 Agent 执行正常
- [ ] 编写回归测试用例：验证已有 `SchedulerEngine` 调度不受长程任务系统影响，现有计划任务调度正常
- [ ] 编写回归测试用例：验证已有插件三轨架构不受长程任务插件影响，现有插件加载正常

## 11. 部署配置与文档

### 11.1 环境配置
- [ ] 配置 `plugin.yaml` 的 `config` 参数默认值：maxRounds=10、maxRoundDurationMs=1800000、maxTaskDurationMs=86400000、maxConcurrentTasks=100、checkpointStrategy=every_round、degradationChain=[cli_execute,builtin_tool,llm,template]、qualityGate={staticCheck:true,testCoverage:true,manualReview:false}
- [ ] 配置 `tableWhitelist` 确保列出全部 11 张需访问表（agent_tasks/agent_contexts/crontab/crontab_log/agent_loop_metrics/agent_loop_tuning_configs/long_running_task_config/progress/artifact/evolution/aip_interaction_session/aip_interaction_task），未配置时 host.db 调用被拒绝
- [ ] 配置本地开发环境访问宿主服务使用域名（如 https://javatoarktsapi.uctoo.com），不用 127.0.0.1:443（会返回 404）

### 11.2 数据迁移与初始化
- [ ] 确认 `sql/incremental/long_running_task.sql` DDL 已由人工在目标数据库环境执行，4 张新增表创建成功
- [ ] 编写长程任务配置初始化脚本：为已有 Agent 创建默认 `long_running_task_config` 记录（使用默认配置参数），支持存量 Agent 平滑使用长程任务能力

### 11.3 监控埋点
- [ ] 在 `LrtExecutor` 执行过程中输出结构化日志：包含任务 ID/回合数/步骤名/耗时/状态等关键信息，写入 crontab_log
- [ ] 在 `LrtSelfEvolutionLoop` 自进化闭环中输出优化报告日志：包含轮次/根因/优化方案/防回退约束，写入 long_running_task_evolution 表
- [ ] 配置关键指标监控告警：任务失败率、回合超时率、检查点保存延迟、进度通知延迟超阈值时告警

### 11.4 文档更新
- [ ] 更新 `skills/long-running-task/SKILL.md`，补充实际运行中发现的错误行为示例和正确行为示例（防回退约束），完善显式约束内容
- [ ] 编写 `skills/long-running-task/README.md` 接口文档：说明 7 个用户 API + 6 个插件 RPC 的接口签名、请求/响应格式、业务说明、异常映射
- [ ] 更新项目运维手册：说明长程任务系统的部署配置、插件加载验证、故障排查、日志查看方法

## 12. 审查与验证

### 12.1 代码审查
- [ ] 审查 P 层仓颉插件代码（main.cj/lrt_handlers.cj/lrt_planner.cj/lrt_executor.cj/lrt_intervention_service.cj/lrt_verifier.cj/lrt_artifact_verifier.cj/lrt_self_evolution_loop.cj/lrt_issue_classifier.cj/lrt_anti_regression_registry.cj/lrt_persist_service.cj/lrt_effects.cj）：确认复用已有基础设施、未重新开发已有能力、遵循 D-P-H-E 分层架构
- [ ] 审查 D 层 Python 脚本（parse_goal.py/notify_progress.py/extend_capability.py）：确认经 HTTP API 调用宿主 MCP 开放服务、未直连数据库、未禁用 SSL 校验、使用 http_lib 库
- [ ] 审查 E 层声明文件（plugin.yaml/COMPOSITION.yaml/SKILL.md）：确认 mode:process、tableWhitelist 已配置、6 步 SOP 编排声明完整、显式约束注入到位

### 12.2 设计回顾
- [ ] 核对 design.md 中 9 类新增组件是否全部实现：L3 插件本体/LrtPlanner/LrtInterventionService/LrtVerifier/LrtArtifactVerifier/LrtAntiRegressionRegistry/LrtSelfEvolutionLoop/LrtIssueClassifier/4 张专用表
- [ ] 核对 design.md 中 7 个用户 API + 6 个插件 RPC + 4 个内部服务接口是否全部实现且接口签名一致
- [ ] 核对 design.md 中 5 阶段增量实施路径是否全部完成：阶段 1 数据库表与 CRUD/阶段 2 L3 插件骨架/阶段 3 核心组件/阶段 4 自进化闭环/阶段 5 D 层脚本与 E 层声明
- [ ] 核对 spec.md 中 13 个核心能力域（5.1-5.13）的业务规则是否全部覆盖，逐条验证验收条件

### 12.3 变更确认
- [ ] 确认复用清单中 14 项已有基础设施未被重新开发：SchedulerEngine/AgentExecutionExecutor/CheckpointManager/DagScheduler/PluginHostManager/CordisHostManager/SkillBridge/WebSocketEventBridge/AipInteractionService/AgentTasksService/EvaluationExecutor/plan_react_executor/due_diligence_agent 插件结构/PersistService 幂等读写
- [ ] 确认新增变更范围：4 张数据库表 DDL + 1 个 L3 插件工程（12 个仓颉源文件）+ 3 个 Python 脚本 + 3 个 E 层声明文件 + 7 个用户 API + WebSocket 事件扩展，未修改已有基础设施核心代码
- [ ] 确认编译验证通过：通知人工在单独 cmd 环境执行 `cjpm build` 编译插件工程，编译结果反馈已确认无错误
- [ ] 确认端到端验证通过：用户提交目标→自主规划→调度执行→进度推送→验核交付→用户确认全闭环测试通过