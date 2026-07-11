# 需求规格文档：AIAgent 框架与 App 层全栈有机融合

## 文档信息
- **项目名称**: agentskills-runtime 全栈有机融合
- **版本**: 1.1.0
- **创建日期**: 2026-06-05
- **作者**: UCToo team
- **状态**: 草稿

## 1. 概述

### 1.1 项目背景

agentskills-runtime 由 CangjieMagic 框架（Agent/Skill/Tool/Memory/Interaction）和 UCToo V4 App 层（PostgreSQL/CRUD/SyncManager/Crontab/权限）两部分组成。当前两套系统并行存在但缺乏有机融合：CangjieMagic Agent 在内存中创建和执行，App 层 agents 表仅存元数据，两者无运行时桥接。本规格定义融合后系统应具备的行为和能力，以数据库为数据流枢纽，实现全栈数据同构（通模一体），超越 Harness Engineering 以文件为中心的模式。

### 1.2 项目范围

**包含**：
- CangjieMagic 框架与 App 层的运行时桥接（8 个后端融合需求 FUSION-001~008）
- Web 前端与 Runtime 后端的深度融合（6 个前端融合需求 FUSION-FE-001~006）
- Token 统计与计费系统（7 个计费需求 BILLING-001~007）
- CangjieMagic 核心能力标准化 API/CLI 开放（10 个能力开放需求 REQ-API-001~010）
- 全栈数据同构（通模一体）规范

**不包含**：
- DAG 调度引擎、动态重编排、执行回滚（属 agent-orchestration spec）
- 错误分类、降级执行、熔断器、补偿事务（属 agent-error-recovery spec）
- 组合 DSL、技能间数据传递、依赖解析（属 skill-composition-engine spec）
- 记忆衰减、跨会话自动加载（属 agent-memory-persistence spec 扩展）

### 1.3 术语定义

| 术语 | 定义 |
|------|------|
| CangjieMagic | AI Agent 框架层，提供 Agent/AgentExecutor/AgentGroup/Memory/Skill/Tool/Interaction |
| App 层 | UCToo V4 服务端应用层，提供 PostgreSQL/CRUD/SyncManager/Crontab/权限 |
| AgentRuntimeBridge | Agent 运行时桥接层，连接 CangjieMagic 内存 Agent 与 App 层数据库 Agent |
| 通模一体（UMI） | 全栈数据同构：后端 PO ↔ 前端 ORM 模型自动同构，API 契约一致 |
| WebMCP | Web Model Context Protocol，前端注册为工具供 Agent 调用的协议 |
| SyncManager | 文件系统与数据库双向同步管理器 |
| SkillToToolAdapter | 技能适配为工具的适配器，技能是一等公民 |
| ChatUsage | LLM 调用的 token 使用量数据结构（promptTokens/completionTokens/totalTokens/timeCost） |
| Tokendance | LLM 计费网关，提供统一调用代理和 token 计量 |

## 2. 系统需求

### 2.1 功能需求

#### 2.1.1 Agent 运行时桥接

##### REQ-BRIDGE-001: Agent 运行时实例创建
**需求描述**: 当 App 层收到创建 Agent 的请求时，系统应同时创建 CangjieMagic 运行时 Agent 实例并在数据库中持久化 Agent 定义。

**验收标准**:
- [ ] 通过 API 创建 Agent 后，数据库 agents 表存在对应记录
- [ ] 通过 API 创建 Agent 后，内存中存在可执行的 BaseAgent 实例
- [ ] Agent 定义字段（name/agentType/model/tools/systemPrompt/maxTurns/memory/background/permissions）在数据库与运行时之间正确映射
- [ ] 创建失败时返回明确错误信息，不产生部分数据

**优先级**: P0

##### REQ-BRIDGE-002: Agent 运行时状态同步
**需求描述**: 当 Agent 执行状态发生变化时，系统应自动将运行时状态同步到数据库。

**验收标准**:
- [ ] Agent 开始执行时，数据库 status 字段更新为 running
- [ ] Agent 执行完成时，数据库 status 字段更新为 completed
- [ ] Agent 执行失败时，数据库 status 字段更新为 failed，错误信息写入数据库
- [ ] Agent 暂停/恢复时，数据库 status 字段相应更新
- [ ] 状态同步不阻塞 Agent 执行主流程

**优先级**: P0

##### REQ-BRIDGE-003: Agent 从数据库恢复
**需求描述**: 当系统启动或 Agent 需要恢复时，系统应能从数据库加载 Agent 定义并重建运行时实例。

**验收标准**:
- [ ] 系统重启后，可从数据库加载所有持久化 Agent 并重建运行时实例
- [ ] 加载的 Agent 保持原有配置（model/tools/systemPrompt 等）
- [ ] 加载的 Agent 可立即执行任务
- [ ] 批量加载时不影响系统启动性能

**优先级**: P0

#### 2.1.2 AgentGroup 可视化管理

##### REQ-GROUP-001: AgentGroup 持久化与 CRUD
**需求描述**: 系统应提供 AgentGroup 的创建、查询、更新、删除操作，并将 AgentGroup 定义持久化到数据库。

**验收标准**:
- [ ] 可创建 AgentGroup 并指定组类型（leader/linear/free/auto_discuss/round_robin）
- [ ] 可为 AgentGroup 添加和移除成员 Agent
- [ ] 可查询 AgentGroup 列表和详情
- [ ] 可更新 AgentGroup 配置和删除 AgentGroup
- [ ] AgentGroup 定义持久化到数据库，重启后可恢复

**优先级**: P1

##### REQ-GROUP-002: AgentGroup 执行与状态查询
**需求描述**: 当用户请求执行 AgentGroup 任务时，系统应创建对应 CangjieMagic AgentGroup 实例并执行，执行状态可通过 API 查询。

**验收标准**:
- [ ] 通过 API 触发 AgentGroup 执行
- [ ] 执行过程中可通过 API 查询执行状态
- [ ] 执行结果写入 AgentTasks 表
- [ ] AgentGroup 类型正确映射到 CangjieMagic 对应实现

**优先级**: P1

#### 2.1.3 Memory 数据库持久化

##### REQ-MEMORY-001: 记忆数据库持久化
**需求描述**: 当 Agent 更新记忆时，系统应将记忆内容同时写入内存向量数据库和 PostgreSQL 数据库。

**验收标准**:
- [ ] Agent 记忆更新时，数据库 agent_memories 表存在对应记录
- [ ] 记忆内容包含文本和嵌入向量
- [ ] 写入内存和数据库不阻塞 Agent 主流程
- [ ] 进程重启后记忆不丢失

**优先级**: P0

##### REQ-MEMORY-002: 记忆语义检索
**需求描述**: 当 Agent 检索记忆时，系统应支持基于向量相似度的语义检索，且内存未命中时从数据库加载。

**验收标准**:
- [ ] 记忆检索返回语义最相关的结果
- [ ] 内存缓存命中时直接返回，未命中时从数据库加载
- [ ] 数据库检索使用向量相似度搜索
- [ ] 检索结果按相关度排序

**优先级**: P0

##### REQ-MEMORY-003: 记忆分层存储
**需求描述**: 系统应支持工作记忆、情景记忆、语义记忆、程序记忆四种分层存储。

**验收标准**:
- [ ] 工作记忆（working）存储在 AgentContexts 表
- [ ] 情景记忆（episodic）存储在 agent_memories 表
- [ ] 语义记忆（semantic）存储在 agent_memories 表，权重更高
- [ ] 程序记忆（procedural）存储在 agent_memories 表，标记为 procedural
- [ ] 各层记忆可独立检索和清理

**优先级**: P1

#### 2.1.4 Crontab 驱动长任务

##### REQ-LONGTASK-001: Agent 长任务调度
**需求描述**: 当 Agent 任务需要长时间执行时，系统应将其注册为 Crontab 任务，支持暂停/恢复/超时/重试控制。

**验收标准**:
- [ ] Agent 长任务可注册为 Crontab 任务
- [ ] 支持暂停和恢复长任务执行
- [ ] 超时后自动终止并记录超时信息
- [ ] 失败后按配置重试（指数退避）
- [ ] 并发执行数量受配置限制
- [ ] 任务状态持久化到 AgentTasks 表

**优先级**: P1

##### REQ-LONGTASK-002: 长任务检查点
**需求描述**: 当长任务执行过程中完成一个步骤时，系统应自动保存当前上下文为检查点，恢复时从最新检查点继续。

**验收标准**:
- [ ] 每完成一个步骤，当前对话上下文保存为检查点
- [ ] 任务中断后可从最新检查点恢复执行
- [ ] 检查点存储在 AgentContexts 的 messages 字段
- [ ] 检查点不显著影响执行性能

**优先级**: P1

#### 2.1.5 Agent 执行事件实时通知

##### REQ-EVENT-001: Agent 事件 WebSocket 推送
**需求描述**: 当 Agent 执行事件发生时，系统应通过 WebSocket 将事件实时推送到前端。

**验收标准**:
- [ ] AgentStart/End/Step 事件正确推送
- [ ] ToolCallStart/End 事件正确推送
- [ ] AgentTimeout 事件正确推送
- [ ] UserInput 事件推送并等待用户响应（人机协作）
- [ ] 事件消息格式统一且包含 agent_id 和 task_id
- [ ] 使用已有 WebSocket 端点 `/api/v1/uctoo/ws/chat`

**优先级**: P1

#### 2.1.6 人机协作增强

##### REQ-HITL-001: Web 端人机审批
**需求描述**: 当 Agent 执行需要人工审批的步骤时，系统应通过 WebSocket 请求用户审批，支持确认/拒绝/修改建议三种操作。

**验收标准**:
- [ ] Agent 可发起审批请求，审批记录持久化到 agent_approvals 表
- [ ] 用户可通过 API 查询待审批项
- [ ] 用户可执行批准/拒绝/修改后批准操作
- [ ] 审批结果返回给 Agent，决定后续执行策略
- [ ] 审批超时有默认处理策略

**优先级**: P2

#### 2.1.7 Skill 组合与 AgentGroup 融合

##### REQ-SKILLGROUP-001: 技能组合自动映射 AgentGroup
**需求描述**: 当技能组合执行时，系统应自动创建对应类型的 AgentGroup：串行组合映射为 LinearGroup，并行组合映射为 LeaderGroup。

**验收标准**:
- [ ] 串行技能组合自动创建 LinearGroup 执行
- [ ] 并行技能组合自动创建 LeaderGroup 执行
- [ ] 评估-改进循环创建含循环逻辑的自定义 Group
- [ ] 组合执行结果写入 AgentTasks 表
- [ ] 技能可包装为 SkillAsAgent 参与 AgentGroup

**优先级**: P2

#### 2.1.8 Agent 可视化监控仪表板

##### REQ-DASHBOARD-001: Agent 监控数据汇总
**需求描述**: 系统应提供 Agent 运行状态的汇总数据 API，包含活跃数量、执行任务、协作拓扑、记忆统计、错误率、资源消耗。

**验收标准**:
- [ ] 仪表板 API 返回活跃 Agent 数量及类型分布
- [ ] 返回正在执行的任务及进度
- [ ] 返回 Agent 组协作拓扑数据
- [ ] 返回记忆使用统计
- [ ] 返回错误率和重试统计
- [ ] 返回 Token 消耗和执行时间统计

**优先级**: P2

#### 2.1.9 WebMCP 协议完善

##### REQ-WEBMCP-001: WebMCP 工具调用链修复
**需求描述**: 当 Agent 通过 WebMCP 调用前端注册的工具时，系统应正确完成 Agent → WebMCP → 前端工具 → 结果返回的完整调用链。

**验收标准**:
- [ ] 修复 WebMCP Server 工具注册和调用的已知 bug
- [ ] Agent 可通过 WebMcpClient 调用前端注册的 entity CRUD 工具
- [ ] 前端工具执行结果通过 WebMCP 协议正确返回给 Agent
- [ ] 新增 Agent 专用工具：web_navigate、web_notify、web_request_approval

**优先级**: P0

##### REQ-WEBMCP-002: 前端工具注册扩展
**需求描述**: 当前端需要为 Agent 提供更多操作能力时，系统应支持注册 agent_control、task_monitor、memory_browse 工具模块。

**验收标准**:
- [ ] agent_control 工具支持 Agent 启动/停止/暂停/恢复
- [ ] task_monitor 工具支持任务进度查看
- [ ] memory_browse 工具支持记忆浏览和搜索
- [ ] 工具注册后 Agent 可发现并调用

**优先级**: P1

#### 2.1.10 pinia-orm 与后端 API 通模一体

##### REQ-UMI-001: 前端模型自动生成
**需求描述**: 当后端新增数据库实体时，系统应能自动生成与后端 PO 同构的前端 pinia-orm 模型文件。

**验收标准**:
- [ ] 从 db_info 表读取表结构，生成 pinia-orm 模型文件
- [ ] 生成的模型字段与后端 PO 字段保持同构
- [ ] 生成的模型包含 CRUD actions
- [ ] 全栈生成命令同时生成后端 CRUD + 前端 ORM 模型 + 前端 CRUD 页面

**优先级**: P1

##### REQ-UMI-002: API 契约验证
**需求描述**: 当前端应用启动时，系统应自动校验前端模型字段与后端 API 响应字段的一致性。

**验收标准**:
- [ ] 启动时自动校验前端模型与后端 API 的字段一致性
- [ ] 不一致时输出告警日志，包含差异详情
- [ ] 校验不阻塞应用启动

**优先级**: P2

#### 2.1.11 Agent 实时监控前端

##### REQ-FEMONITOR-001: Agent 实时状态监控页面
**需求描述**: 系统应提供 Agent 实时状态监控页面，展示 Agent 运行状态、任务进度、协作拓扑、Token 消耗。

**验收标准**:
- [ ] Agent 实时状态卡片由 WebSocket 驱动更新
- [ ] 任务执行进度条显示步骤完成数/总步骤数
- [ ] Agent 组协作拓扑图以可视化 DAG 展示
- [ ] Token 消耗和执行时间实时统计

**优先级**: P2

##### REQ-FEMONITOR-002: Agent 详情与历史页面
**需求描述**: 系统应提供 Agent 详情页面，展示配置、执行历史、对话、记忆、权限审批记录。

**验收标准**:
- [ ] Agent 配置详情来自 agents pinia-orm model
- [ ] 执行历史时间线来自 agent_tasks model
- [ ] 对话历史来自 agent_contexts model
- [ ] 记忆浏览和搜索来自 agent_memories model
- [ ] 权限和审批记录来自 agent_approvals model

**优先级**: P2

#### 2.1.12 TinyRobot 与 Agent 系统深度集成

##### REQ-TINYROBOT-001: 对话自动关联 Agent
**需求描述**: 当用户通过 TinyRobot 发起对话时，系统应自动创建或关联 Agent 实例，对话历史持久化到 agent_contexts 表。

**验收标准**:
- [ ] 每次对话创建或关联一个 Agent 实例
- [ ] 对话历史自动持久化到 agent_contexts 表
- [ ] 工具调用记录到 agent_tasks 表
- [ ] 支持多 Agent 切换，切换时加载对应 systemPrompt 和 tools

**优先级**: P1

##### REQ-TINYROBOT-002: 子 Agent 可视化与人机审批
**需求描述**: 当子 Agent 执行时，系统应在 TinyRobot 对话中显示子 Agent 执行卡片，并支持人机审批操作。

**验收标准**:
- [ ] 子 Agent 执行时在对话中显示为嵌套卡片
- [ ] 子 Agent 结果可折叠/展开查看
- [ ] 子 Agent 执行进度实时更新
- [ ] Agent 请求审批时弹出审批对话框
- [ ] 支持确认/拒绝/修改后确认三种审批操作

**优先级**: P1

#### 2.1.13 前端/后端技能统一管理

##### REQ-SKILLUNIFY-001: 技能统一视图
**需求描述**: 系统应提供前端技能和后端技能的统一管理视图，标识技能来源。

**验收标准**:
- [ ] 技能列表显示技能来源（browser-side/server-side）
- [ ] 技能详情页显示 SKILL.md 正文、agents 声明、脚本列表
- [ ] 后端技能通过 SkillManager 管理，前端技能通过 WebMCP 注册
- [ ] agent_skills 表通过 SyncManager 同步到文件系统

**优先级**: P2

#### 2.1.14 数据库驱动全链路可观测

##### REQ-OBSERV-001: 全链路时间线
**需求描述**: 系统应提供从用户操作到数据库变更的全链路可观测时间线。

**验收标准**:
- [ ] 时间线覆盖：用户操作 → API 调用 → Agent 执行 → 工具调用 → 数据库变更 → 同步事件
- [ ] 数据来源：operate_log + agent_tasks + sync_log + crontab_log
- [ ] 支持按 Agent、任务、时间范围筛选
- [ ] 数据流可视化：文件→数据库同步流、数据库→前端数据流、Agent→工具→结果流

**优先级**: P3

#### 2.1.15 Token 使用记录持久化

##### REQ-BILLING-001: LLM 调用 Token 记录
**需求描述**: 当 LLM 调用完成时，系统应将 ChatUsage 数据持久化到 llm_usage_logs 表。

**验收标准**:
- [ ] 每次成功的 LLM 调用后，promptTokens/completionTokens/totalTokens/timeCost 写入数据库
- [ ] 记录包含 agent_id、task_id、provider、model、request_type、is_streaming
- [ ] 调用失败时也记录（completion_tokens=0，error_message 非空）
- [ ] 通过 EventHandlerManager 的 ChatModelEndEvent 自动触发，不侵入各模型实现
- [ ] 记录异步执行，不阻塞 LLM 调用主流程

**优先级**: P0

#### 2.1.16 模型提供商费率配置

##### REQ-BILLING-002: 费率配置与计费计算
**需求描述**: 系统应提供各模型提供商的 token 单价配置，并在 LLM 调用记录时自动计算费用。

**验收标准**:
- [ ] model_pricing 表存储各提供商各模型的输入/输出 token 单价
- [ ] 预置 18 个提供商的主流模型官方费率
- [ ] 计费公式：cost = (prompt_tokens/1M) × rate_prompt + (completion_tokens/1M) × rate_completion
- [ ] 本地模型（ollama/llamacpp）费率为 0
- [ ] 支持费率生效时间范围，自动选择当前生效费率
- [ ] 未配置费率的模型按 0 计费

**优先级**: P0

#### 2.1.17 Token 用量统计与仪表板

##### REQ-BILLING-003: Token 用量多维统计
**需求描述**: 系统应提供按 Agent、模型、用户、时间维度的 Token 用量统计 API。

**验收标准**:
- [ ] 支持总量汇总（总 token、总费用、按提供商分布）
- [ ] 支持按 Agent/模型/用户/时间维度统计
- [ ] 支持趋势数据（近 7 天/30 天）
- [ ] 支持消耗最高的 Agent/模型排行

**优先级**: P1

##### REQ-BILLING-004: Token 用量仪表板页面
**需求描述**: 系统应提供 Token 用量仪表板页面，展示概览、趋势、分布、排行、费率。

**验收标准**:
- [ ] 概览卡片：今日 token 数、今日费用、本月 token 数、本月费用
- [ ] 趋势图：token 用量和费用随时间变化
- [ ] 模型分布饼图和提供商分布饼图
- [ ] Agent 排行榜和费率表
- [ ] 支持时间范围筛选

**优先级**: P1

#### 2.1.18 用户/租户配额与预算

##### REQ-BILLING-005: Token 用量配额控制
**需求描述**: 当 LLM 调用发生时，系统应检查用户/租户/Agent 的 token 用量配额，超限时拒绝或告警。

**验收标准**:
- [ ] 配额支持按日/月、按 token 数/费用四种组合
- [ ] 硬限制超限时拒绝调用并返回错误
- [ ] 软限制超限时允许调用但发送告警
- [ ] 达到告警阈值百分比时通过 WebSocket 推送告警
- [ ] 周期自动重置（通过 Crontab 定时任务）

**优先级**: P2

#### 2.1.19 计费报表与导出

##### REQ-BILLING-006: 计费报表生成与导出
**需求描述**: 系统应提供按日/月的计费报表，支持导出为 XLSX 和 CSV 格式。

**验收标准**:
- [ ] 日报和月报包含：时间范围、总 token 数、总费用、按提供商/模型/用户/Agent 分项
- [ ] 支持导出为 XLSX 和 CSV 格式
- [ ] 前端报表页面支持日报/月报切换、图表+表格双视图、导出按钮

**优先级**: P2

#### 2.1.20 EventHandlerManager 集成计费

##### REQ-BILLING-007: 事件驱动 Token 记录
**需求描述**: 系统应通过 EventHandlerManager 事件驱动实现无侵入的 Token 记录和计费。

**验收标准**:
- [ ] ChatModelEndEvent 触发 usage 写入 llm_usage_logs 表
- [ ] ChatModelFailureEvent 触发失败调用记录
- [ ] AgentEndEvent 触发该 Agent 本次执行总 token 汇总，更新 AgentTasks
- [ ] 事件处理异步执行，不阻塞主流程

**优先级**: P1

#### 2.1.21 Tokendance 计费网关增强

##### REQ-BILLING-008: Tokendance 统一计费代理
**需求描述**: 当配置使用 Tokendance 网关时，系统应通过 Tokendance 代理 LLM 调用并实现双重记录。

**验收标准**:
- [ ] LLM 调用可通过 Tokendance 代理
- [ ] Tokendance 自动记录 token 用量到其计费系统
- [ ] 同时写入本地 llm_usage_logs 表（双重记录）
- [ ] 支持查询 Tokendance 账户余额和用量统计
- [ ] 支持本地费率与 Tokendance 费率对比和差异告警

**优先级**: P2

#### 2.1.22 AgentExecutor 执行策略 API

##### REQ-API-001: 执行策略注册与查询
**需求描述**: 系统应提供 AgentExecutor 五种执行策略（naive/react/plan-react/tool-loop/dsl）的注册、查询和配置 API，使用户和 AI 可按需选择和配置 Agent 执行策略。

**验收标准**:
- [ ] API 返回所有已注册执行策略列表（name/description/defaultConfig）
- [ ] API 查询指定策略的详细配置参数（如 react 的 loop 次数、plan-react 的分解策略）
- [ ] Agent 创建或更新时可指定执行策略名称
- [ ] Agent 执行时使用指定策略，未指定则使用默认策略（react）
- [ ] CLI 支持 `agentskills executor list` 和 `agentskills executor info <name>`
- [ ] 执行策略配置变更持久化到数据库

**优先级**: P1

##### REQ-API-002: 执行策略运行时切换
**需求描述**: 当 Agent 执行过程中需要切换执行策略时，系统应支持通过 API 动态切换当前 Agent 的执行策略。

**验收标准**:
- [ ] 通过 API 可切换运行中 Agent 的执行策略
- [ ] 切换后下一次 Agent 步骤使用新策略执行
- [ ] 切换操作记录到 AgentTasks 执行日志
- [ ] 不支持切换的策略组合返回明确错误（如 dsl 仅支持 UserDefinedAgent）

**优先级**: P2

#### 2.1.23 AgentGroup 协作模式 API

##### REQ-API-003: AgentGroup 协作模式与讨论 API
**需求描述**: 系统应提供 AgentGroup 五种协作模式的完整 API，包括讨论模式（FreeGroup/AutoDiscussGroup/RoundRobinDiscussGroup）的发起、参与和结果查询。

**验收标准**:
- [ ] API 支持创建五种协作模式的 AgentGroup（leader/linear/free/auto_discuss/round_robin）
- [ ] FreeGroup 支持 `discuss(topic, initiator, speech, mode, maxRound)` API
- [ ] AutoDiscussGroup 支持 `discuss(maxRound)` 和 `selectSpeaker()` API
- [ ] RoundRobinDiscussGroup 支持轮询讨论 API
- [ ] 讨论过程中可通过 API 查询当前轮次、发言者、讨论内容
- [ ] 讨论结果（Selection: Speaker/Summary/Failure）通过 API 返回
- [ ] CLI 支持 `agentskills group discuss <group-id> --topic <topic> --max-round <n>`

**优先级**: P1

##### REQ-API-004: AgentGroup DSL 操作符 API
**需求描述**: 系统应提供 AgentGroup DSL 操作符（<=创建LeaderGroup、|创建FreeGroup、线性管道）的等效 API，使用户和 AI 可通过 REST/CLI 使用声明式语法构建 Agent 协作拓扑。

**验收标准**:
- [ ] API 支持 LeaderGroup 声明式创建：指定 leader + members
- [ ] API 支持 LinearGroup 管道式创建：指定有序 Agent 列表
- [ ] API 支持 FreeGroup 并行式创建：指定 Agent 列表
- [ ] API 支持将 AgentGroup 包装为 Agent（GroupAsAgent）参与更上层编排
- [ ] CLI 支持 `agentskills group create --leader <id> --members <id1,id2>` 等声明式语法
- [ ] 创建的 AgentGroup 可嵌套组合（子 Group 作为成员参与父 Group）

**优先级**: P1

#### 2.1.24 Memory 记忆系统 API

##### REQ-API-005: 记忆读写与检索 API
**需求描述**: 系统应提供 Agent 记忆的写入（update）、检索（search）、查看、删除的标准化 API，使用户和 AI 可直接操作 Agent 记忆。

**验收标准**:
- [ ] API `POST /api/v1/uctoo/agents/{id}/memory/update` 写入记忆段落
- [ ] API `POST /api/v1/uctoo/agents/{id}/memory/search` 语义检索记忆，返回相关度排序结果
- [ ] API `GET /api/v1/uctoo/agents/{id}/memory` 查看全部记忆（分页）
- [ ] API `DELETE /api/v1/uctoo/agents/{id}/memory/{memory-id}` 删除指定记忆
- [ ] API 支持按作用域（working/episodic/semantic/procedural）筛选记忆
- [ ] CLI 支持 `agentskills memory update <agent-id> --content <text>`
- [ ] CLI 支持 `agentskills memory search <agent-id> --query <question>`

**优先级**: P1

#### 2.1.25 ModelManager 模型管理 API

##### REQ-API-006: 模型提供商注册与查询
**需求描述**: 系统应提供模型提供商的注册、查询、测试的标准化 API，使用户和 AI 可动态管理可用模型。

**验收标准**:
- [ ] API 返回所有已注册模型提供商列表（provider/kind/name/status）
- [ ] API 返回每个提供商支持的模型类型（ChatModel/EmbeddingModel/ImageModel）
- [ ] API 支持动态注册新模型提供商（provider/baseURL/apiKey/kind）
- [ ] API 支持测试模型连通性（`POST /api/v1/uctoo/models/test`，发送测试请求验证可用性）
- [ ] API 支持查询模型配置参数（contextLength/temperature 范围等）
- [ ] CLI 支持 `agentskills model list`、`agentskills model test <provider>/<model>`
- [ ] 模型配置变更通过 SyncManager 同步到环境变量/配置文件

**优先级**: P1

#### 2.1.26 RAG 检索系统 API

##### REQ-API-007: RAG 检索器管理与查询
**需求描述**: 系统应提供 RAG 检索器的创建、配置、检索的标准化 API，使用户和 AI 可为 Agent 动态配置知识库。

**验收标准**:
- [ ] API 支持创建检索器（类型：markdown/sqlite/sqlite_table，指定数据源路径）
- [ ] API 支持检索器列表查询和详情查看
- [ ] API `POST /api/v1/uctoo/retrievers/{id}/search` 执行语义检索
- [ ] Agent 创建时可关联检索器，执行时自动使用关联检索器增强上下文
- [ ] CLI 支持 `agentskills retriever create --type markdown --source <path>`
- [ ] CLI 支持 `agentskills retriever search <id> --query <question>`

**优先级**: P1

#### 2.1.27 EventHandler 交互事件 API

##### REQ-API-008: 事件处理器注册与查询
**需求描述**: 系统应提供 EventHandlerManager 事件处理器的注册、查询、注销的标准化 API，使用户和 AI 可动态插拔事件处理器。

**验收标准**:
- [ ] API 返回所有已注册事件处理器列表（事件类型/处理器名称/状态）
- [ ] API 支持动态注册事件处理器（指定事件类型和处理器逻辑）
- [ ] API 支持注销事件处理器
- [ ] API `GET /api/v1/uctoo/events/recent` 查询最近事件流（分页，按类型/Agent 筛选）
- [ ] 13 种事件类型均可通过 API 查询历史记录
- [ ] CLI 支持 `agentskills event handlers`、`agentskills event recent --type <type>`

**优先级**: P2

#### 2.1.28 Storage 存储系统 API

##### REQ-API-009: 存储实例管理与查询
**需求描述**: 系统应提供 KV 存储、向量存储、图存储的创建、查询、操作的标准化 API，使用户和 AI 可直接使用底层存储能力。

**验收标准**:
- [ ] KV 存储 API：创建集合、get/upsert/remove 键值对、列出集合
- [ ] 向量存储 API：创建集合、addVector/search 向量、查询集合统计
- [ ] 图存储 API：upsertVertex/getVertex/upsertEdge/getEdges、查询顶点类型和边关系
- [ ] 存储实例持久化到数据库，重启后可恢复
- [ ] CLI 支持 `agentskills storage kv <get|set|del> <collection> <key>`
- [ ] CLI 支持 `agentskills storage vector <add|search> <collection>`
- [ ] CLI 支持 `agentskills storage graph <vertex|edge> <add|get|query> <collection>`

**优先级**: P2

#### 2.1.29 Skill 验证与安全执行 API

##### REQ-API-010: 技能验证与安全执行
**需求描述**: 系统应提供技能格式验证、安全检查、资源验证和沙箱执行的标准化 API，使用户和 AI 可在安装和执行技能前进行安全评估。

**验收标准**:
- [ ] API `POST /api/v1/uctoo/skills/validate` 验证技能格式（SKILL.md frontmatter 完整性）
- [ ] API `POST /api/v1/uctoo/skills/validate-security` 安全检查（权限声明、资源访问范围）
- [ ] API `POST /api/v1/uctoo/skills/validate-resources` 资源验证（依赖可用性、脚本可执行性）
- [ ] 验证结果包含通过/失败状态和详细错误列表
- [ ] API `POST /api/v1/uctoo/skills/{id}/execute-secure` 安全执行（指定超时、能力白名单）
- [ ] 安全执行返回 ExecutionResult（success/output/error/executionTime/resourcesUsed）
- [ ] CLI 支持 `agentskills skill validate <path>`、`agentskills skill validate-security <path>`

**优先级**: P2

#### 2.2.1 性能需求
- Agent 运行时桥接的状态同步延迟应小于 100ms
- 记忆语义检索响应时间应小于 200ms（1000 条记忆以内）
- Token 记录写入不增加 LLM 调用延迟超过 50ms（异步写入）
- WebSocket 事件推送延迟应小于 500ms
- 全栈生成命令（crudgen --full-stack）应在 30 秒内完成单表生成
- 仪表板 API 响应时间应小于 2 秒（10 万条 usage 记录以内）

#### 2.2.2 安全需求
- Agent 的 permissions 声明必须覆盖其所有操作所需的权限
- Token 使用记录不可篡改，仅支持追加和查询
- 费率配置修改需审计记录
- 配额检查在 LLM 调用前执行，不可绕过
- WebSocket 连接需 JWT 认证
- WebMCP 工具调用需权限校验

#### 2.2.3 可用性需求
- Agent 运行时桥接失败时，Agent 仍可在内存中执行（降级模式）
- 数据库不可用时，记忆系统降级为纯内存模式
- WebSocket 断连时自动重连，重连后补发缺失事件
- Tokendance 网关不可用时，回退到直接调用模型提供商

#### 2.2.4 可维护性需求
- 新增模型提供商时，仅需添加费率配置，无需修改计费代码
- 新增 Agent 类型时，仅需实现 BaseAgent 接口和字段映射
- 前后端模型同构变更通过全栈生成命令一键同步
- 事件处理器可插拔，新增事件类型无需修改已有处理器

#### 2.2.5 兼容性需求
- AgentRuntimeBridge 兼容所有 BaseAgent 子类型（AiFuncAgent/ConversationAgent/DispatchAgent/HumanAgent/ToolAgent）
- AgentGroup 兼容所有五种 CangjieMagic 协作模式
- 计费系统兼容所有 18 个模型提供商
- 前端兼容 OpenTiny Vue 3 组件库和 TinyRobot 组件

### 2.3 约束性需求
- 后端使用仓颉（Cangjie）编程语言，前端使用 TypeScript + Vue 3
- 数据库为 PostgreSQL，ORM 为 ent（仓颉）
- 前端 ORM 为 pinia-orm，状态持久化为 pinia-plugin-persistedstate
- 通信协议：REST API、WebSocket、WebMCP、MCP
- 技能是一等公民，优先使用技能排列组合解决需求
- 确定性优先，AI 增强：可确定性实现的逻辑用代码，需推理判断的由 AI 驱动
- 数据库为数据流枢纽（Single Source of Truth）

## 3. 接口需求

### 3.1 用户接口

| 页面 | 路径 | 功能 |
|------|------|------|
| Agent 监控 | views/ai/agent-monitor.vue | 实时状态、任务进度、协作拓扑、Token 消耗 |
| Agent 详情 | views/ai/agent-detail.vue | 配置、执行历史、对话、记忆、权限审批 |
| 技能编排 | views/ai/skill-composer.vue | 拖拽式 DAG 编辑、依赖可视化、组合执行 |
| Token 仪表板 | views/ai/token-dashboard.vue | 概览、趋势、分布、排行、费率 |
| 计费报表 | views/ai/billing-report.vue | 日报/月报、图表+表格、导出 |
| 全链路可观测 | views/database/uctoo/observability.vue | 时间线、数据流可视化、数据资产 |
| 模型管理 | views/ai/model-management.vue | 提供商列表、模型测试、连通性状态 |
| 检索器管理 | views/ai/retriever-management.vue | RAG 检索器 CRUD、知识库配置、检索测试 |

### 3.2 系统接口

| 接口 | 端点 | 说明 |
|------|------|------|
| AgentGroup CRUD | /api/v1/uctoo/agent_groups/* | 创建/查询/更新/删除 Agent 组 |
| AgentGroup 执行 | /api/v1/uctoo/agent_groups/{id}/execute | 执行 Agent 组任务 |
| AgentGroup 成员 | /api/v1/uctoo/agent_groups/{id}/add-member, /remove-member | 管理组成员 |
| Agent 审批 | /api/v1/uctoo/agent_approvals/* | 查询待审批、批准/拒绝/修改 |
| Agent 仪表板 | /api/v1/uctoo/agents/dashboard | 监控汇总数据 |
| Agent 执行日志 | /api/v1/uctoo/agents/{id}/execution-log | 执行日志查询 |
| Agent 记忆 | /api/v1/uctoo/agents/{id}/memory | 记忆查看和搜索 |
| 费率配置 | /api/v1/uctoo/model_pricing/* | 费率 CRUD |
| Token 统计 | /api/v1/uctoo/llm-usage/* | 多维统计和趋势 |
| 计费报表 | /api/v1/uctoo/llm-usage/report/* | 日报/月报/导出 |
| 配额管理 | /api/v1/uctoo/usage_quotas/* | 配额 CRUD |
| Tokendance | /api/v1/uctoo/tokendance/* | 余额/用量查询 |
| 执行策略 | /api/v1/uctoo/executors/* | 策略列表/详情/配置 |
| AgentGroup 讨论 | /api/v1/uctoo/agent_groups/{id}/discuss | 发起/查询讨论 |
| AgentGroup DSL | /api/v1/uctoo/agent_groups/compose | 声明式组合创建 |
| 记忆操作 | /api/v1/uctoo/agents/{id}/memory/* | update/search/delete |
| 模型管理 | /api/v1/uctoo/models/* | 提供商注册/列表/测试 |
| RAG 检索器 | /api/v1/uctoo/retrievers/* | 创建/配置/检索 |
| 事件处理器 | /api/v1/uctoo/events/* | 注册/注销/查询 |
| 存储系统 | /api/v1/uctoo/storage/* | KV/Vector/Graph 操作 |
| 技能验证 | /api/v1/uctoo/skills/validate* | 格式/安全/资源验证 |

### 3.3 数据接口

| 数据实体 | 同步方式 | 说明 |
|----------|---------|------|
| agents | SyncManager 双向同步 | AGENTS.md ↔ 数据库 ↔ 运行时 |
| agent_groups | SyncManager 双向同步 | AgentGroup 定义 ↔ 数据库 |
| agent_memories | SyncManager 双向同步 | 记忆文件 ↔ 数据库 |
| agent_approvals | 仅数据库 | 审批记录仅存数据库 |
| llm_usage_logs | 仅数据库追加 | Token 使用记录仅追加不可改 |
| model_pricing | SyncManager 双向同步 | 费率配置 ↔ 数据库 |
| usage_quotas | 仅数据库 | 配额数据仅存数据库 |
| agent_executors | SyncManager 双向同步 | 执行策略配置 ↔ 数据库 |
| retrievers | SyncManager 双向同步 | RAG 检索器定义 ↔ 数据库 |
| event_handlers | 仅数据库 | 事件处理器注册信息 |

## 4. 数据需求

### 4.1 数据模型

本节定义新增数据实体的业务语义和约束，不包含具体 schema 定义。

| 实体 | 业务语义 | 核心字段语义 | 生命周期 |
|------|---------|------------|---------|
| agent_groups | Agent 协作组定义 | 组类型、领导者、成员列表、配置 | 创建→配置→执行→归档 |
| agent_memories | Agent 记忆持久化 | 记忆内容、嵌入向量、作用域、权重、标签 | 写入→检索→衰减→清理 |
| agent_approvals | 人机审批记录 | 审批类型、内容、状态、用户响应 | 发起→待审批→已处理 |
| llm_usage_logs | LLM 调用 Token 记录 | 提供商、模型、token 数、耗时、费用 | 追加-only，不可修改 |
| model_pricing | 模型费率配置 | 提供商、模型、输入单价、输出单价、生效时间 | 配置→生效→过期→归档 |
| usage_quotas | 用量配额 | 对象类型、配额类型、上限、已用量、周期 | 配置→使用→重置 |
| agent_executors | 执行策略配置 | 策略名称、配置参数、默认参数 | 注册→配置→使用 |
| retrievers | RAG 检索器定义 | 类型、数据源、嵌入模型、检索模式 | 创建→配置→检索→归档 |
| event_handlers | 事件处理器注册 | 事件类型、处理器名称、状态 | 注册→启用→注销 |

### 4.2 数据存储
- 所有新增实体存储在 PostgreSQL 数据库
- agent_memories 的嵌入向量使用 pgvector 扩展存储
- llm_usage_logs 为追加-only 表，按月分区

### 4.3 数据迁移
- 新增 6 张数据库表及对应 CRUD 模块
- 新增 3 张能力开放相关表（agent_executors/retrievers/event_handlers）
- 预置 18 个模型提供商的费率数据
- 预置 AgentGroup 五种类型的默认配置
- 预置 5 种执行策略的默认配置

## 5. 验收标准

### 5.1 功能验收

| 编号 | 验收条件 | 对应需求 |
|------|---------|---------|
| AC-001 | AgentRuntimeBridge 正确创建运行时 Agent 并同步状态到数据库 | REQ-BRIDGE-001/002 |
| AC-002 | Agent 可从数据库加载并重建运行时实例 | REQ-BRIDGE-003 |
| AC-003 | AgentGroup 可通过 API CRUD 管理并执行 | REQ-GROUP-001/002 |
| AC-004 | 记忆持久化到 PostgreSQL 且支持语义检索和分层存储 | REQ-MEMORY-001/002/003 |
| AC-005 | Crontab 可驱动 Agent 长任务，支持暂停/恢复/超时/重试/检查点 | REQ-LONGTASK-001/002 |
| AC-006 | Agent 执行事件通过 WebSocket 实时推送 | REQ-EVENT-001 |
| AC-007 | HumanAgent 可通过 WebSocket 等待用户审批 | REQ-HITL-001 |
| AC-008 | 技能组合可自动创建对应 AgentGroup 执行 | REQ-SKILLGROUP-001 |
| AC-009 | Agent 监控仪表板正确展示运行状态和执行历史 | REQ-DASHBOARD-001 |
| AC-010 | WebMCP 前端工具调用链正确工作 | REQ-WEBMCP-001/002 |
| AC-011 | pinia-orm 模型与后端 PO 同构，全栈生成命令正确工作 | REQ-UMI-001/002 |
| AC-012 | TinyRobot 对话自动关联 Agent，支持多 Agent 切换和子 Agent 可视化 | REQ-TINYROBOT-001/002 |
| AC-013 | 前端/后端技能统一管理，来源标识清晰 | REQ-SKILLUNIFY-001 |
| AC-014 | 全链路可观测页面正确展示完整数据流 | REQ-OBSERV-001 |
| AC-015 | 每次 LLM 调用后 ChatUsage 正确写入 llm_usage_logs | REQ-BILLING-001 |
| AC-016 | 各模型提供商费率正确配置，计费金额计算准确 | REQ-BILLING-002 |
| AC-017 | Token 用量仪表板正确展示各维度统计 | REQ-BILLING-003/004 |
| AC-018 | 配额超限时正确拒绝或告警 | REQ-BILLING-005 |
| AC-019 | 计费报表可按日/月生成并导出 | REQ-BILLING-006 |
| AC-020 | EventHandlerManager 事件正确触发 Token 记录 | REQ-BILLING-007 |
| AC-021 | Tokendance 网关余额和用量查询正确工作 | REQ-BILLING-008 |
| AC-022 | 执行策略可通过 API 查询和配置，Agent 可指定执行策略 | REQ-API-001/002 |
| AC-023 | AgentGroup 五种协作模式和讨论 API 正确工作 | REQ-API-003/004 |
| AC-024 | 记忆读写和语义检索 API 正确工作 | REQ-API-005 |
| AC-025 | 模型提供商可动态注册、查询和测试连通性 | REQ-API-006 |
| AC-026 | RAG 检索器可创建、配置和执行语义检索 | REQ-API-007 |
| AC-027 | 事件处理器可动态注册、注销和查询历史事件 | REQ-API-008 |
| AC-028 | KV/向量/图存储可通过 API 操作 | REQ-API-009 |
| AC-029 | 技能验证和安全执行 API 正确工作 | REQ-API-010 |

### 5.2 性能验收
- Agent 状态同步延迟 < 100ms
- 记忆检索响应 < 200ms（1000 条以内）
- Token 记录不增加 LLM 调用延迟 > 50ms
- WebSocket 事件推送延迟 < 500ms
- 仪表板 API 响应 < 2s（10 万条记录以内）

### 5.3 安全验收
- Agent 操作均在 permissions 声明范围内
- Token 记录不可篡改
- 费率修改有审计记录
- 配额检查不可绕过
- WebSocket 连接需 JWT 认证

## 6. 附录

### 6.1 参考文档
- research.md - AIAgent 框架与 App 层有机融合研究材料
- docs/ref/AIDrivenArchitecture.md - AI 驱动开发框架架构
- docs/standard/agents/ - agents 开放标准
- AGENTS.md v2.0.0 - 主 Agent 定义
- agent-orchestration/spec.md - Agent 编排引擎规格
- long-running-task/spec.md - 长时间运行任务规格
- agent-memory-persistence/spec.md - 记忆持久化规格
- agent-error-recovery/spec.md - 错误恢复与自愈规格
- skill-composition-engine/spec.md - 技能组合引擎规格

### 6.2 实施优先级总览

| 优先级 | 需求 | 依赖 |
|--------|------|------|
| P0 | REQ-BRIDGE-001/002/003 Agent 运行时桥接 | 无 |
| P0 | REQ-MEMORY-001/002 记忆持久化与检索 | BRIDGE |
| P0 | REQ-WEBMCP-001 WebMCP 修复 | 无 |
| P0 | REQ-BILLING-001/002 Token 记录与费率 | BRIDGE |
| P1 | REQ-LONGTASK-001/002 长任务调度 | BRIDGE |
| P1 | REQ-EVENT-001 事件 WebSocket 推送 | BRIDGE |
| P1 | REQ-GROUP-001/002 AgentGroup 管理 | BRIDGE |
| P1 | REQ-API-001 执行策略 API | BRIDGE |
| P1 | REQ-API-003/004 AgentGroup 协作模式与 DSL API | GROUP |
| P1 | REQ-API-005 记忆读写检索 API | MEMORY |
| P1 | REQ-API-006 模型管理 API | 无 |
| P1 | REQ-API-007 RAG 检索器 API | 无 |
| P1 | REQ-UMI-001 通模一体 | BRIDGE |
| P1 | REQ-TINYROBOT-001/002 TinyRobot 集成 | WEBMCP, EVENT |
| P1 | REQ-BILLING-003/004/007 统计仪表板与事件集成 | BILLING-001/002 |
| P2 | REQ-MEMORY-003 记忆分层 | MEMORY-001 |
| P2 | REQ-HITL-001 人机审批 | EVENT |
| P2 | REQ-SKILLGROUP-001 技能组合融合 | BRIDGE, GROUP |
| P2 | REQ-DASHBOARD-001 监控仪表板 | GROUP, EVENT |
| P2 | REQ-FEMONITOR-001/002 前端监控 | GROUP, EVENT |
| P2 | REQ-BILLING-005/006/008 配额/报表/Tokendance | BILLING-001/003 |
| P2 | REQ-SKILLUNIFY-001 技能统一管理 | WEBMCP |
| P2 | REQ-UMI-002 API 契约验证 | UMI-001 |
| P2 | REQ-API-002 执行策略运行时切换 | API-001 |
| P2 | REQ-API-008 事件处理器 API | EVENT |
| P2 | REQ-API-009 存储系统 API | 无 |
| P2 | REQ-API-010 技能验证与安全执行 | 无 |
| P3 | REQ-OBSERV-001 全链路可观测 | DASHBOARD |

### 6.4 数据流闭环需求（补充）

#### 6.4.1 问题背景

当前 WebMCP 聊天流程（`POST /api/v1/uctoo/webmcp/mcp` → `completion/complete`）能正确返回大模型响应，但所有聊天过程应触发的数据均未在业务表中生成。根因是"双重断裂"：

1. **事件处理器未注册**：`BillingEventHandler.registerGlobalHandlers()` 和 `WebSocketEventBridge.registerGlobalHandlers()` 从未在 `main.cj` 启动时调用，`EventHandlerManager.global` 中无任何数据库写入处理器
2. **聊天流程未集成桥接层**：WebMCPProtocol/WsChatController/AIController 三条聊天入口均未调用 AgentRuntimeBridge/CheckpointManager，也未为 Agent 设置 DatabaseMemory

#### 6.4.2 WebMCP 聊天数据流闭环需求

##### REQ-FLOW-001: WebMCP 聊天→数据库数据流闭环
**需求描述**: 当用户通过 WebMCP 聊天（`POST /api/v1/uctoo/webmcp/mcp` → `completion/complete`）发送消息并收到大模型响应后，系统应自动将聊天过程中的所有数据写入对应业务表。

**验收标准**:
- [ ] 每次聊天后 `llm_usage_logs` 表有新记录（promptTokens/completionTokens/totalTokens/timeCostMs）
- [ ] 每次聊天后 `agent_contexts` 表有新记录（对话上下文持久化）
- [ ] 每次聊天后 `agent_messages` 表有新记录（用户消息和助手响应）
- [ ] 每次聊天后 `agent_tasks` 表有新记录（任务执行记录）
- [ ] Agent 使用记忆时 `agent_memories` 表有新记录
- [ ] Agent 状态同步到 `agents` 表（status 字段更新）
- [ ] 数据写入异步执行，不阻塞聊天响应返回
- [ ] 降级模式：数据库不可用时仍可正常聊天，但日志记录写入失败

**优先级**: P0

##### REQ-FLOW-002: 全局事件处理器启动时注册
**需求描述**: 系统启动时，应自动注册 BillingEventHandler、QuotaCheckHandler、WebSocketEventBridge 到 EventHandlerManager.global，使事件驱动的数据写入生效。

**验收标准**:
- [ ] 应用启动后 `EventHandlerManager.global` 中已注册 ChatModelEndEvent 处理器
- [ ] 应用启动后 `EventHandlerManager.global` 中已注册 ChatModelFailureEvent 处理器
- [ ] 应用启动后 `EventHandlerManager.global` 中已注册 AgentStartEvent/AgentEndEvent 处理器
- [ ] 应用启动后 `EventHandlerManager.global` 中已注册 ChatModelStartEvent 处理器（配额检查）
- [ ] 应用启动后 WebSocket 事件桥接处理器已注册
- [ ] 注册失败时输出告警日志，不阻塞应用启动

**优先级**: P0

##### REQ-FLOW-003: 聊天流程集成 AgentRuntimeBridge 和 DatabaseMemory
**需求描述**: WebMCPProtocol 和 WsChatController 创建 Agent 时，应通过 AgentRuntimeBridge 创建并设置 DatabaseMemory，使 Agent 执行过程中的状态同步和记忆持久化生效。

**验收标准**:
- [ ] WebMCPProtocol 创建 Agent 时传入 `memory` 参数（DatabaseMemory 或 TieredMemory）
- [ ] WsChatController 创建 Agent 时传入 `memory` 参数
- [ ] Agent 执行完成后调用 `AgentRuntimeBridge.syncToDatabase()` 同步状态
- [ ] Agent 执行完成后调用 `CheckpointManager.saveCheckpoint()` 保存上下文
- [ ] 降级模式：AgentRuntimeBridge 不可用时回退到纯内存 Agent

**优先级**: P0

##### REQ-FLOW-004: Agent 消息和任务自动持久化
**需求描述**: Agent 执行过程中的消息和任务应自动持久化到数据库，无需业务代码显式调用。

**验收标准**:
- [ ] AgentStartEvent 触发时自动创建 `agent_tasks` 记录（status=running）
- [ ] ChatModelEndEvent 触发时自动写入 `agent_messages`（助手响应）
- [ ] AgentEndEvent 触发时自动更新 `agent_tasks`（status=completed）+ 写入 `agent_messages`（最终响应）+ 调用 `CheckpointManager.saveCheckpoint()`
- [ ] 用户消息在聊天入口处写入 `agent_messages`
- [ ] 所有写入异步执行，不阻塞主流程

**优先级**: P0

##### REQ-FLOW-005: AI API 通道事件触发
**需求描述**: AIController（OpenAI 兼容 API）应通过 Agent 框架调用 LLM，确保事件系统被触发，而非直接调用 ChatModel.create()。

**验收标准**:
- [ ] AI API 聊天请求触发 ChatModelStartEvent/ChatModelEndEvent
- [ ] AI API 聊天后 `llm_usage_logs` 表有新记录
- [ ] 降级模式：Agent 创建失败时回退到直接 ChatModel 调用，但手动触发事件

**优先级**: P1

### 6.5 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0.0 | 2026-06-05 | UCToo team | 初始版本，基于 research.md 研究材料创建 |
| 1.1.0 | 2026-06-05 | UCToo team | 补充 CangjieMagic 核心能力标准化 API/CLI 开放需求（REQ-API-001~010） |
| 1.2.0 | 2026-06-09 | weiyoho | 补充数据流闭环需求 REQ-FLOW-001~005，基于 WebMCP 聊天数据流断裂分析 |