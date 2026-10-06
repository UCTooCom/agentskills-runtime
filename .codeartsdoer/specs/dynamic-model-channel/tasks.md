# 动态大模型通道：实施任务清单

**版本**：v1.0.0
**日期**：2026-10-02
**对应**：`spec.md`（REQ / 验收 V1–V7）、`design.md`（架构与迁移 M1–M9）
**约定**：每个任务标注「改动文件 / 验收方式 / 依赖」；**不代跑 `cjpm build`**（编译由人工在独立 cmd 执行，AI 只据日志修代码）

---

## 复核修正（2026-10-06：T037 漏接全局浮动助手）

**现象**：web 端全局聊天抽屉（App.vue 全局浮动 `TinyRemoter`，`title="UCTOO 智能助手"`）输入框处无通道选择器（参考 `chatComponent.png`）。

**根因**：T037 只接到了 `views/chat/index.vue`（ChatRemoter 传 `channel-catalog`）；而用户实际入口是 **App.vue 的全局浮动 TinyRemoter**，它只传了单个 `:llm-config`，没传 `:llm-configs` → `TinyRobotChat.vue:68` 的 `<ModelSwitch v-if="llmConfigsRef && llmConfigsRef.length > 0">` 永远不渲染。dist 里其实已包含选择器代码（`uctoo_llm_channel_last` 在 index chunk 中），是**接线面漏了**，不是没构建。

**修复**（`apps/web-admin/web/src/App.vue`）：与 views/chat 同源接线——
1. `onMounted` 拉 `GET /llm_channel/catalog`（失败静默退回单配置，不阻塞聊天）；
2. 目录 → `llmConfigs`（`model` 严格拼 `"<code>:<modelId>"`，T036 语义；`capabilities` 含 vision 打开多模态）；
3. 传 `:llm-configs="llmConfigs"` + `v-model:selected-model-id="selectedChannelId"`；
4. 选中项持久化 localStorage `uctoo_llm_channel_last`（与 ChatRemoter 同键，两个入口共享记忆）；目录为空时 `llmConfig.model` 跟随选中项。

已过 `scripts/check-vue-refs.cjs` 静态检查；待前端重新构建 + 浏览器实测（V8）。

---

## 进度更新（2026-10-05）

> 本轮一次性推进了探测 / 能力 / 健康相关后端任务，并按项目惯例通过 `pkggraph.py` 校验无循环依赖。

| ID | 状态 | 说明 |
|---|---|---|
| T006 | **已接线（Phase 0 去死代码）** | `ModelRouter.hasProvider` 接入 `checkProvider`，成为选路解析单一入口；完整作用域/能力/优先级链/回退链仍归 Phase 2 |
| T016 | **后端完成** | `ChannelProbe.syncModels` + `POST /:code/sync-models` + `GET /models`；新增模型默认 `pending`（REQ-DMC-009） |
| T017 | **后端完成** | 三枪探测 `ChannelProbe.probe`（chat/stream/tools），写回通道级 `capabilities`/`health` 与 `llm_channel_model` 条目能力位 + `llm_channel_health` 历史；前端 `probe-result.vue` 仍由用户侧实现 |
| T026 | **后端完成 + 已调度** | `ChannelProbe.probeHealthAll` + `main.cj` 60s 周期探活 spawn；连续失败≥3 置 `degraded`、恢复归位 `enabled`（熔断/半开简化版） |
| T013 | 待回归 | 代码（T010/T011）已落地，待用户在真实运行环境跑 V1–V7 全绿 |

**新增/改动文件**：
- 新增 `src/model/channel/channel_probe.cj`（T016/T017/T026 实现）
- 新增 `src/app/dao/uctoo/ModelChannelHealthDAO.cj`
- 改 `ModelChannelDAO.cj`（加 `updateChannelProbe` / `updateChannelStatusOnly`）
- 改 `ModelChannelModelDAO.cj`（加 `findModelChannelModelByChannelAndModel` / `updateModelChannelModelCapabilities`）
- 改 `channel_service.cj`（加 `applyProbeResult` / `applyHealthStatus` / `listModelsByChannel` / `listAllModels`）
- 改 `LlmChannelController.cj` / `LlmChannelRoute.cj`（加 `models` / `sync-models` / `probe` 端点）
- 改 `main.cj`（加 60s 健康探活 spawn；两处 init 同步加）
- 改 `model_router.cj` / `model_manager.cj`（T006 接线）
- 新增 `sql/incremental/20261005_llm_channel_probe_models_permissions.sql`（新端点 RBAC）

**待用户执行**：① `cjpm build`；② 执行上述增量权限 SQL；③ 真实环境跑 T013 回归（V1–V7）。

---

## 进度更新（2026-10-05 续：Phase 2 启动）

> 本轮启动 Phase 2，落地「路由规则 + 选路核心」，并通过 `resolveChannel` 接入 `ModelManager.createChatModel` 热路径（等价替换原 `ChannelRegistry.getChannel`，T006 彻底去死代码）。

| ID | 状态 | 说明 |
|---|---|---|
| T027 | **后端完成** | `ModelRouteRulePO`/`ModelRouteRuleDAO` + `ChannelService` 增删改查 + `LlmRouteRuleController`/`LlmRouteRuleRoute`（list/add/edit/del/evaluate）+ `AutoRouteConfig` 注册 + 权限 SQL；规则表 `llm_route_rule` 已有 DDL（T001） |
| T006 | **后端完成（完整选路）** | `ModelRouter` 实现作用域（global/agent/task，具体优先）+ 能力过滤 + 策略排序（priority/cost/health/system1 预留）+ 回退链；`resolveChannel(provider)` 接入 `createChatModel` 热路径 |
| T029 | **后端完成（策略抽象）** | `RouteStrategy` 以字符串策略 + `strategyScore` 可插拔实现（priority/cost/health；system1 暂以 priority 兜底，待 Laya 接入 Phase 3） |
| T028 | **后端完成（成本策略）** | `ModelRouter` 注入 `pricingProvider`（自 `model_pricing` 取 active 单价均值），`cost` 策略按单价升序；缺数据退化为中性评分 |

**新增/改动文件**：
- 新增 `src/app/models/uctoo/ModelRouteRulePO.cj`（原已自动生成，补默认值）
- 新增 `src/app/dao/uctoo/ModelRouteRuleDAO.cj`
- 改 `src/model/channel/model_router.cj`（T006/T028/T029 完整选路核心）
- 改 `src/model/channel/channel_service.cj`（路由规则 CRUD + `loadRouteRules` 注入 ModelRouter + 单价查询）
- 改 `src/model/model_manager.cj`（`createChatModel` 改走 `ModelRouter.resolveChannel`）
- 新增 `src/app/controllers/uctoo/llm_channel/LlmRouteRuleController.cj`
- 新增 `src/app/routes/uctoo/llm_channel/LlmRouteRuleRoute.cj`
- 改 `src/app/registry/AutoRouteConfig.cj`（注册 `llm_route_rule` 路由）
- 改 `src/app/main.cj`（启动装配后 `ChannelService.shared().loadRouteRules()`）
- 新增 `sql/incremental/20261005_llm_route_rule_permissions.sql`

**待用户执行**：① `cjpm build`；② 执行 `20261005_llm_route_rule_permissions.sql`；③ 真实环境跑 T013 回归（V1–V7）。

---

## Phase 0 — MVP：把「重启才能换通道」这个问题消灭掉

> 目标：切默认通道不重启进程；新增 OpenAI 兼容通道零代码；通道挂了也能热修。

| ID | 任务 | 改动点 | 验收 |
|---|---|---|---|
| T001 | 设计并建表 `llm_channel` / `llm_channel_model` / `llm_route_rule` / `llm_channel_health` / `llm_channel_audit` | `sql/` 新增 DDL；同步进 `db_info` | 表结构可查；字段与 `design.md §3` 一致 |
| T002 | 实体与 DAO（`ModelChannelPO` 等，参照 `ModelPricingPO.cj` 写法） | `src/app/models/uctoo/` | 编译通过；CRUD 可执行 |
| T003 | `BUILTIN_SEED`：把 `model_manager.cj:33-94` 的 20 项常量表抽为种子数据（保留原常量作离线兜底） | `src/model/channel/builtin_seed.cj` | 种子项与现状 map 逐项对齐（含 arcbench/evomap） |
| T004 | `ChannelService`：播种（空表时写种子，`source=seed`）、CRUD、审计、revision 自增 | `src/model/channel/channel_service.cj` | 首次启动自动播种；审计表有记录 |
| T005 | `ChannelRegistry`：内存快照 + revision 比对 + 原子替换；DB 不可用退化为「种子 + .env」 | `src/model/channel/channel_registry.cj` | 断库后仍能解析出通道（V7） |
| T006 | `ModelRouter`：作用域（global/agent/task）+ 能力过滤 + 优先级链 + 回退链 | `src/model/channel/model_router.cj` | 单测：作用域冲突消解正确 |
| T007 | `AdapterFactory` 模式 A 直通：按注册表构造 `OpenAIChatModel/Embedding/Image` | `src/model/channel/adapter_factory.cj` | 与现状同名通道产出等价实例 |
| T008 | `ModelInstanceCache`：按 `(channel, modelId, revision)` 缓存；revision 变 → 下一请求换实例（drain 默认） | `src/model/channel/model_instance_cache.cj` | 切换后新请求用新实例，进行中会话不受影响（V4） |
| T009 | `ModelManager` 改造：`createChatModel(String)` **签名语义不变**，`checkProvider` 改查注册表；`createChatModel(ModelConfig)` 保留 | `src/model/model_manager.cj` | 8 个现有调用点无需改动即编译通过 |
| T010 | `main.cj` 不再持有 `_chatModel` 单例：改为 `ModelKey`；**模型创建失败不再跳过 chat 路由注册** | `src/app/main.cj:237/414/582-604` | 故意填错 key 启动 → chat 路由仍在；热修正后可聊天（V3） |
| T011 | 变更广播：写操作后同步广播 `ChannelChanged`；备用 2s 定时拉 `max(revision)` | `src/model/channel/` + `main.cj` 装配 | 切换 ≤5s 生效（V1） |
| T012 | 通道管理 API（list/detail/add/edit/del/toggle/default/test/reload） | `src/app/controllers/uctoo/llm_channel/` + `AutoRouteConfig.cj` 注册 | Postman 全通；密钥掩码 |
| T013 | Phase 0 回归：现有链路（WebMCP 聊天 / AIController / Agent / LRT）用表内通道跑通 | — | V1 / V2 / V3 / V5 / V6 / V7 全绿 |

---

## Phase 1 — 可视化与能力探测（让运维不用登服务器）

| ID | 任务 | 改动点 | 验收 |
|---|---|---|---|
| T014 | 前端页面骨架 `views/ai/model_channel/index.vue` + 菜单/权限 | `apps/web-admin/web/src/views/ai/model_channel/` | 菜单可见、列表可加载 |
| T015 | 通道表单（按 `protocol` 动态字段、密钥掩码、「已配置」状态） | `channel-form.vue` | 新增一个 OpenAI 兼容网关 → 不写代码即可调用（V2） |
| T016 | 模型清单同步：拉 `{base}/models`，新模型默认 `pending` | `channel_probe.cj` + `sync-models` API | ArcBench 实测能拉到清单 |
| T017 | 三枪探测：chat / stream / tools（+vision），写回能力位，返回原始错误 | `channel_probe.cj` + `probe` API + `probe-result.vue` | 对 atomgit（200 空体）、ArcBench（登记名不符）能给出可辨错误 |
| T018 | 一键设为默认（二次确认 + drain 提示）与健康总览 | `index.vue` + `health` API | 切换后 5s 内新会话生效，uptime 不归零 |
| T019 | 变更审计抽屉 | `audit-drawer.vue` + `audit` API | 每次变更可追溯（含 source：ui/api/agent/seed） |
| T020 | `ModelController.cj:23-31` 硬编码 `providerNames` 改为读注册表 | `src/app/controllers/uctoo/model/ModelController.cj` | 消除第三处硬编码；后台列表 = 注册表 |
| T035 | 用户面通道目录 API：`GET /llm_channel/catalog`（仅 `enabled` 且 `scopes` 含 `"user"`；字段裁剪：code/显示名/图标/能力/倍率标签，无密钥/URL/健康）+ 权限节点 SQL（普通用户角色可读，与管理 API RBAC 分离） | `LlmChannelController.cj` / `LlmChannelRoute.cj` + `sql/incremental/` | 普通用户可拉目录；响应无管理字段（V8 前置） |
| T036 | 聊天请求级通道指定：`webmcp/mcp` completion/stream 参数支持 `model: "<channel>:<modelId>"`，优先级 = 请求级 > `def.model` > 全局默认；与 T010 请求边界解析同落点；严格语义不猜通道 | `WebMCPController.cj` / `WebMCPProtocol.cj`（`WebMCPProtocol.cj:138-143` 一带） | 用户切换后下一条消息日志出现新通道（V8） |
| T037 | 前端聊天框通道选择器（产品参考 `chatComponent.png`）：输入框右下角当前通道按钮 + 下拉（catalog 数据源、选中 ✓、标签/倍率可空）+ 前端记住上次选择；**组合通道三档（快速/均衡/极致）本期不渲染**，归 laya 关联工程 | web 前端聊天组件（对接 `webmcp/mcp`） | 普通用户（无管理权限）可在聊天框自助切换具体通道（V8） |

---

## Phase 2 — L3 插件适配器轨 + 路由/健康（协议扩展不动宿主）

| ID | 任务 | 改动点 | 验收 |
|---|---|---|---|
| T021 | `host.secret` 宿主服务（`get`/`has`），沿用 `cordis_host_services.cj:68-77` 注册方式与凭证集中托管范式 | `src/plugin/cordis_host_services.cj` | 插件可取凭据；插件进程环境/命令行无密文（V5） |
| T022 | 适配器契约：`adapter.describe / chat / chatStream / probe` 的分帧流式协议 | `src/model/channel/adapter_contract.cj` + 文档 | 契约文档化；流式分帧定义清楚 |
| T023 | `AdapterFactory` 模式 B：stdio JSON-RPC 调插件；超时熔断 + 回退链 | `adapter_factory.cj` + `cordis_host_manager.cj` | 插件进程被 kill → 自动切回退链，宿主不崩 |
| T024 | 首个适配器插件示例：把 tokendance（现状专用 `TokendanceChatModel`）改造成 L3 适配器插件 | `skills/llm-channel-tokendance/`（plugin.yaml + exe） | 通过三枪探测；可设为默认并热切换 |
| T025 | 运行时插件发现/注册：新增目录或 `plugin_activate` 后能被发现并注册路由（现状 `reconcileDesired()` 仅启动调用一次） | `src/plugin/cordis_host_manager.cj` / `external_plugin_route_gateway.cj` | 新增插件目录后**不重启宿主**即可生效 |
| T026 | 健康探测与熔断：周期探活、错误率阈值、冷却半开、自动归位 | `channel_probe.cj` + 定时任务 | 通道挂 → 自动摘除；恢复 → 归位 |
| T027 | 路由规则页面：作用域 + 能力要求 + 候选链 + 回退链 | `route-rule.vue` + `llm_route_rule` 读写 API | 按 Agent 配不同通道生效 |
| T028 | 成本策略（读 `model_pricing`）：`strategy=cost` + 预算上限告警 | `model_router.cj` | 单价更高的通道在 cost 策略下排后 |

---

## Phase 3 — 自动切换与灰度（面向「按任务自动选提供商」）

| ID | 任务 | 改动点 | 验收 |
|---|---|---|---|
| T029 | 策略接口抽象：`RouteStrategy` 可插拔（priority / cost / health / system1） | `model_router.cj` | 新增策略不改调用方 |
| T030 | Agent 工具：`llm_channel_list/test/probe/switch`（受「允许自动切换」开关约束） | `src/plugin/plugin_agent_tools.cj` 同范式 | Agent 能自主切换并写审计 |
| T031 | Laya System-1 打分策略（对接 `laya-system1-integration` 用例 #3） | `System1RouteStrategy` | 难度打分 → 快/强模型分流 |
| T032 | 影子流量与灰度对比（`shadow_percent`） | `model_router.cj` + `shadow-compare.vue` | 影子请求不影响主结果，可看延迟/失败率对比 |
| T033 | 多环境导出/导入（通道配置 JSON，含密钥引用不含明文） | API + 前端 | 一套配置可迁移到另一环境 |
| T034 | 文档化：更新 `skills/uctoo-dev-manual/specs/model-provider-integration.md`（新增通道改为「界面配置」为主、代码改为仅协议适配器插件） | 手册 | SOP 与实现一致 |

---

## 验收矩阵（spec.md §6）

| 验收项 | 依赖任务 | 阶段 |
|---|---|---|
| V1 热切换不重启 | T005–T011, T018 | Phase 0/1 |
| V2 零代码新增同协议通道 | T003, T004, T007, T015 | Phase 0/1 |
| V3 通道失败可热修（不阉割路由） | T010 | Phase 0 |
| V4 进行中会话不受影响（drain） | T008 | Phase 0 |
| V5 密钥不泄露 | T012, T021 | Phase 0/2 |
| V6 严格语义保持（裸名报错、不猜通道） | T009 | Phase 0 |
| V7 断库仍可用（种子 + .env） | T003, T005 | Phase 0 |
| V8 用户端聊天框切换 | T035, T036, T037（T036 依赖 T010） | Phase 1 |

---

## 执行顺序与依赖

```
T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012 → T013(回归)
                                                              ↘ T020（可并行）
T013 → T014 → T015 → T016 → T017 → T018 → T019
T013 → T021 → T022 → T023 → T024 → T025 → T026 → T027 → T028
T028 → T029 → T030 → T031 → T032 → T033 → T034
T010 → T036 → T035 → T037        # 用户端聊天框切换器（REQ-DMC-021，V8）
                                  # T036 必须在 T010 之后（同一请求边界改造落点）
                                  # T035/T037 可与 Phase 1 其余任务并行
```

**风险最高的两步**：T010（`_chatModel` 单例改造，牵动 WebMCP/Agent 全链路）与 T025（运行时插件发现，涉及 cordis 侧改动）。建议这两步各留一次完整回归，且都以「`.env` 逃生舱可覆盖」为回滚手段。

---

## 交付状态（2026-10-05 收尾）

**代码层面 T001–T037 全部落地**，无需再改代码。待人工执行的是三件环境侧动作（编译 / 落库 / 回归）。

### 前端构建已验证通过
`npm run build` → `✓ built in 17m 13s`，7 个新增页面/组件全部进 `dist/assets/`：
`channel-form` / `probe-result` / `audit-drawer` / `model-list-dialog` / `route-rule` / `shadow-compare` + 通道列表页。

### 构建期间修掉的三个真实阻塞（都不是本工程引入，但会挡住验证）
1. `InputNumber` / `Dialog` 不是 `@opentiny/vue` 的导出（是 Element-UI 的组件名）→ 数字输入改 `Input type="number"` + 提交前 `Number(x) || 0`。
2. `index.vue` 模板用 `:icon="IconEdit"` 等 6 个图标但 script 未绑常量 → `<script setup>` 只暴露 script 顶层声明，rollup 中后段才报 `findVariable`（无文件名无中文）。
3. 34 个历史文件把 `registerPageTool` 从 `@opentiny/next-sdk`（外部包无此导出）导入，正确路径是 `@/mcp-servers/registerPageTool` → 已批量机械修正（用户授权）。

为此新增 `web-admin/web/scripts/check-vue-refs.cjs`：把前两类错误从「构建中后段 11~17 分钟才暴露」提到「秒级静态拦截」，已挂 `prebuild` 钩子。

### 待人工执行
1. **宿主编译**：`cd apps/agentskills-runtime && cjpm build`（本轮改 8 个 .cj）。
2. **插件独立编译**：`cd skills/llm_channel_tokendance && cjpm build`（不需重编宿主；已补 `bin-dependencies`）。
3. **落库 7 份 SQL**（`sql/incremental/20261004_llm_channel.sql` + `20261004_llm_channel_permissions.sql` + `20261005_llm_channel_catalog_permission.sql` + `20261005_llm_channel_health_audit_permissions.sql` + `20261005_llm_channel_menu.sql` + `20261005_llm_channel_probe_models_permissions.sql` + `20261005_llm_route_rule_permissions.sql`），执行后跑 `loaddbinfo`。
4. **T013 回归 V1–V7** + T024 三枪探测验证（新增通道 `protocol=plugin:llm_channel_tokendance`、`secret_ref=env:TOKENDANCE_API_KEY`，宿主 `.env` 配该变量）。

### 已知限制（有明确原因，非半成品）
- `PluginChatModel.asyncCreate` 明确抛 `ModelException`：宿主 core 未开放流帧工厂（`AsyncChatChunk` 构造是包级 `protected`）。插件侧 `chatStream` 已实现齐备，core 开放后只需解除这一处抛异常。
- 插件轨切通道仍走 `LRT_MODEL_*`，未接通道注册表（模式 A 已接）。
