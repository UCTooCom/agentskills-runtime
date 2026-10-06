# 动态大模型通道：架构设计

**版本**：v1.0.0
**日期**：2026-10-02
**对应需求**：`spec.md`（REQ-DMC-001~020）
**前置**：`problem-analysis.md`（现状证据）、`research.md`（业界对比）

---

## 1. 设计原则

1. **真相在数据，确定性在代码**：「用哪家厂商、哪个模型、如何选路」是数据（表 + 版本戳）；「怎么按 OpenAI 兼容协议发请求、怎么解 SSE」是代码（既有 `src/model/openai/*` 原样保留）。这条边界不模糊，就不滑向配置地狱。
2. **不做隐式兜底**：沿用 2026-10-01 定的口径——`provider:modelName` 必须显式，程序不补前缀、不猜通道、不改写模型 ID。动态化只改变「provider 的合法集合从哪里来」，不改变「写什么就发什么」。
3. **新能力一律插件形态**：协议适配器走 L3 进程轨，不进宿主编译图，不触 `src/app` 存量冻结红线。
4. **双驱动兜底**：有 DB 用 DB；无 DB 退化「内置种子 + .env」仍完整可用；AI 缺失时人工可视化切换仍完备。
5. **密钥不落插件进程**：沿用 `host.mcp` 的「凭证宿主集中管理」范式，扩展为 `host.secret`。

> **对接边界（务必区分两条链路，禁止接错接口）**
> - **聊天对接点（web-admin ↔ runtime）= `WebMCPController` 的 `webmcp/mcp` 接口**：路由定义在 `src/app/routes/webmcp/WebMCPRoutes.cj`，对外暴露 `/api/v1/uctoo/webmcp/mcp`（WS + streamableHttp POST）与兼容端点 `/api/v1/webmcp/mcp`。聊天调用链为 `WebMCPRoutes → WebMCPController → WebMCPProtocol`，**模型解析就落在 `WebMCPProtocol`（`ModelManager.createChatModel(def.model)`）**。动态切换大模型、按 Agent/会话选通道，必须落在这条聊天链路（T010 / M4），**绝不走 `llm_channel` 管理 API**。
> - **`src/app/controllers/uctoo/llm_channel/*`（T012，`/api/v1/uctoo/llm_channel/*`）只是通道元数据的「管理 / 控制面」**：负责增删改、设为默认、启停、探测、测试、reload。它本身**不聊天、不做模型解析**，只写入 DB 并广播 `ChannelChanged` → `ChannelRegistry.refresh()`，由聊天链路在请求边界读取新注册表实现热生效。
> - 两平面**只通过 `ChannelRegistry` 内存快照耦合**，互不直接调用：`llm_channel` 是触发者，`webmcp/mcp` 是消费者。任何「让聊天用上新通道」的改动，入口都在 `webmcp/mcp`（`WebMCPController`/`WebMCPProtocol`/`ModelManager`），不在 `llm_channel` 控制器。
> - **用户端聊天框的通道切换（REQ-DMC-021）同样走 `webmcp/mcp`，不走管理 API**：用户在聊天框选中的通道随**下一条聊天请求显式传参**（`model: "<channel>:<modelId>"`），由 `WebMCPProtocol` 在请求边界解析，优先级 = 请求级指定 > Agent `def.model` > 全局默认。普通用户可见的通道列表由只读 `catalog` API 提供（见 §8），与管理 API 权限分离。

---

## 2. 总体架构

```
┌────────────────────────── 配置源（真相） ──────────────────────────┐
│  llm_channel / llm_channel_model / llm_route_rule  (PostgreSQL)    │
│  ↕ 双向：.env 引导 + 覆盖（逃生舱）   ↕ 内置种子（DEFAULT_PROVIDER_MAP 退化）│
└───────────────────────────────┬───────────────────────────────────┘
                                │ 变更（写） / 版本戳（读）
                    ┌───────────▼────────────┐
                    │  ChannelRegistry       │ ← 内存缓存 + revision 原子替换
                    │  (ModelChannelService) │ ← 广播 ChannelChanged 事件
                    └───────────┬────────────┘
                                │ 查询（版本未变 → 零 DB 查询）
       ┌────────────────────────▼─────────────────────────┐
       │  ModelRouter（选路）                              │
       │  作用域: global / agent:<id> / task:<type>        │
       │  策略: 能力匹配 → 优先级链 → 健康 → (成本) → 回退链 │
       │  预留: System-1 打分策略（Laya）                   │
       └────────────────────────┬─────────────────────────┘
                                │ 解析结果: (channel, modelId, adapter)
       ┌────────────────────────▼─────────────────────────┐
       │  AdapterFactory + ModelInstanceCache              │
       │   模式A 直通: OpenAI 兼容 → OpenAIChatModel(...)   │
       │   模式B 代理: 私有协议 → L3 插件进程 (stdio JSON-RPC 流式)│
       └────────────────────────┬─────────────────────────┘
                                │ ChatModel 实例（按 revision 失效重建）
    ┌──────────┬────────────────┼─────────────────┬──────────────┐
    ▼          ▼                ▼                 ▼              ▼
 WebMCP    AgentLoop     长程任务(LRT)      AIController   Agent 工具/API
（现状是启动期单例 _chatModel 透传 → 改为按 revision 取实例）
```

**与现状的关键差异**：`_chatModel`（`main.cj:237/414`）不再是「启动期建一次、全局透传」，而是**持有 `(channelId, modelId, revision)` 的解析键**，在请求边界向 `ModelInstanceCache` 取实例。

---

## 3. 数据模型（4 张业务表 + 1 张审计表）

> 命名与既有表风格一致（下划线复数：`model_pricing` / `llm_usage_logs`）；主键沿用自增 id + 软删 `deleted_at`。

### 3.1 `llm_channel`（通道 = 一个可调用端点）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | bigint PK | |
| `code` | varchar(64) UNIQUE | 通道编码，即 `provider`（`arcbench` / `deepseek` / `ollama`…） |
| `display_name` | varchar(128) | 界面显示名 |
| `protocol` | varchar(32) | `openai-chat` / `openai-embedding` / `openai-image` / `plugin:<name>`（L3 适配器插件） |
| `base_url` | varchar(512) | 只写到 `/v1` 级（沿用 SOP 约定） |
| `secret_ref` | varchar(256) | `env:ARCBENCH_API_KEY` / `db:<id>` / `vault:<path>`；**不存明文** |
| `default_model` | varchar(128) | 默认模型 ID（该通道自报登记名） |
| `capabilities` | jsonb | 通道级能力位：`chat/stream/tools/vision/embedding/image/reasoning` |
| `scopes` | jsonb | 允许的作用域（默认 `["global"]`） |
| `priority` | int | 同级候选排序 |
| `status` | varchar(16) | `enabled` / `disabled` / `probing` / `degraded` |
| `is_default` | bool | 全局默认通道（唯一） |
| `health` | jsonb | 探测结果快照（成功率/p95/最近错误） |
| `probe_at` | timestamp | 最近探测时间 |
| `config` | jsonb | 协议相关附加参数（超时、组织 ID、自定义 header 引用） |
| `revision` | bigint | 行级版本（变更自增） |
| `creator` / `created_at` / `updated_at` / `deleted_at` | | 沿用既有审计字段 |

### 3.2 `llm_channel_model`（通道下的模型条目）

`id / channel_id / model_id（登记名，原样）/ display_name / capabilities(jsonb) / context_len / max_output / pricing_ref(→model_pricing) / status(enabled|pending|disabled) / probed_at / revision`

> `status=pending` 是默认：网关悄悄上线的新模型**不自动可用**（呼应 REQ-DMC-009）。

### 3.3 `llm_route_rule`（路由规则）

`id / scope(global|agent:<id>|task:<type>) / require_capabilities(jsonb) / channel_chain(jsonb 有序候选) / fallback_chain(jsonb) / strategy(priority|cost|health|system1) / shadow_percent / enabled / priority / revision`

冲突消解：作用域更具体者优先（`task > agent > global`），同级按 `priority` 降序。

### 3.4 `llm_channel_health`（探测与健康历史，可裁剪）

`id / channel_id / model_id / ok / latency_ms / error_code / error_message / checked_at`

### 3.5 `llm_channel_audit`（变更审计）

`id / channel_id / action(add|edit|switch|probe|toggle|delete) / before(jsonb, 密钥掩码) / after(jsonb, 密钥掩码) / operator / source(ui|api|agent|seed) / created_at`

> 种子写入记 `source=seed`，便于区分「用户改的」与「系统内置的」。

---

## 4. 热生效链路（核心机制）

```
写操作（UI/API/Agent）
  → ChannelService.write()：DB 事务 + revision 自增 + 审计
  → 广播 ChannelChanged(channelId, revision)（PluginEventBus 或轻量广播器）
  → ChannelRegistry.refresh()：
        重新加载受影响通道 → 构造新快照 → **原子替换** currentSnapshot（copy-on-write）
  → ModelInstanceCache.invalidate(channelId)：标记旧实例待回收
  → 下游：WebMCPProtocol / AgentLoop 在**请求边界**取新实例
```

**四条硬约束**：

1. **读多写少**：热路径只做 `revision` 比对，版本未变零 DB 查询（满足 REQ-DMC-018）。
2. **原子替换**：快照不可变；切换不是「改 HashMap」而是「换指针」，并发读无锁。
3. **请求边界生效（drain 默认）**：
   - 新请求 → 用新快照实例；
   - 进行中的流式会话 → 沿用旧实例直到本轮结束；`immediate` 策略下则下一段生成即切换（按通道可配）。
4. **刷新失败不影响服务**：refresh 抛错则保留上一版快照 + 告警，绝不因配置错误让 runtime 失去聊天能力（改变现状 `main.cj:582-604` 的「失败即跳过路由注册」行为）。

**刷新触发方式（三选一，按可靠性排序）**：
- 主：写操作后**同步广播**（同进程内事件）
- 备：多实例/外部改库场景 → 定时拉取 `max(revision)`（默认 2s，可配）
- 可选：DB `LISTEN/NOTIFY`（PostgreSQL原生）→ 后续优化

---

## 5. 适配器双轨

### 5.1 模式 A：内置直通（覆盖 ~90% 通道）

`protocol ∈ {openai-chat, openai-embedding, openai-image}` → 直接复用 `OpenAIChatModel / OpenAIEmbeddingModel / OpenAIImageModel`，参数全部来自注册表：

```cj
// 伪代码（实际签名以仓颉实现为准）
let ch = registry.getChannel(code)
let secret = hostSecret.resolve(ch.secretRef)     // 宿主集中解析，密文不出宿主
OpenAIChatModel(ch.code, modelId, apiKey: secret, baseURL: ch.baseUrl)
```

**新增一个 OpenAI 兼容厂商 = 插一条 `llm_channel` 记录**（REQ-DMC-005，零代码零编译）。

### 5.2 模式 B：L3 插件代理（私有协议 / 特殊实现）

`protocol = plugin:<name>` → 宿主经 stdio JSON-RPC 调用同名 L3 插件进程：

```yaml
# skills/llm-channel-tokendance/plugin.yaml（示例）
name: llm-channel-tokendance
mode: process                      # L3 进程隔离轨
command: ./skills/llm-channel-tokendance/target/release/bin/skill_llm_channel_tokendance.exe
enabled: true
autoRestart: true                  # 崩溃自愈（既有机制）
tableWhitelist:                    # 走既有白名单机制
  - llm_channel
  - llm_channel_model
  - llm_channel_health
routes:                            # 可选：暴露探测/管理子路由
  - {method: POST, path: /api/v1/uctoo/llm_channel/adapter/tokendance/probe}
env: {}                            # ⚠ 不放密钥
```

**契约（宿主 ⇄ 适配器插件）**：

| 方法 | 方向 | 说明 |
|---|---|---|
| `adapter.describe` | 宿主→插件 | 返回协议名、支持能力、需要的配置字段（驱动 UI 动态表单） |
| `adapter.chat` / `adapter.chatStream` | 宿主→插件 | 请求体为 runtime 标准消息数组；流式以分帧 JSON 事件返回（`delta` / `tool_call` / `done` / `error`） |
| `adapter.probe` | 宿主→插件 | 三枪探测，返回能力位与错误明细 |
| `host.secret.get` | 插件→宿主 | **插件按需取凭据**，宿主不把密文放进进程环境/命令行 |
| `host.db.*` / `host.log` | 插件→宿主 | 复用既有宿主服务（受 `tableWhitelist` 约束） |

**性能与稳定性约束**：首字节 ≤ 50ms 本地开销；插件进程崩溃 → 宿主熔断该通道并切回退链；`autoRestart` 自愈后自动重新纳管（复用现有 reconcile 语义）。

### 5.3 为什么不是「全部走插件」

热路径（每个 token 的流式）过一次进程间序列化，对本地 stdio 是 ~毫秒级但会叠加背压与故障面；而 OpenAI 兼容已是事实标准（现状 20 个 provider 里 17 个复用 `OpenAIChatModel`）。**直通保性能，插件保扩展性**，由 `protocol` 字段决定走哪条——这是明确的工程取舍，不是折中。

---

## 6. `ModelManager` 改造（兼容优先）

现状（`model_manager.cj`）：`DEFAULT_PROVIDER_MAP`（:33-94）+ `createChatModel` match（:229-233）+ `parseModel`（:185-211）。

改造后：

| 现状 | 改造 |
|---|---|
| `DEFAULT_PROVIDER_MAP` 常量表 | 退化为 **`BUILTIN_SEED`**（仅用于首次播种与 DB 不可用兜底）；运行时不再直接读它 |
| `parseModel(model, kind)` | 保留拆分与严格校验；`checkProvider(provider)` 改为 **查注册表**（注册表不可用时回退种子） |
| `createChatModel(String)` | **签名与语义不变**（8 个调用点零改动）：内部改为 `router.resolve(model) → adapter.build(...) → cache.get(...)` |
| `createChatModel(ModelConfig)` | 保留；作为「已解析通道直连」入口 |
| `getDefaultApiKey/getDefaultBaseURL` | 改为 `ChannelRegistry` 提供的 `resolveSecret` / `resolveBaseUrl`（`env:` 引用仍走 `getEnv`，保持现状语义） |

**新增组件（均在 `src/model/` 下，不触碰存量）**：

```
src/model/channel/
  model_channel.cj        通道实体（表映射）
  channel_registry.cj     内存快照 + revision 刷新 + 原子替换
  channel_service.cj      读写/审计/种子播种（供 Controller 调用）
  model_router.cj         作用域解析 + 能力匹配 + 优先级链 + 回退 + 熔断
  adapter_factory.cj      模式A直通 / 模式B插件代理
  model_instance_cache.cj 按 (channel,model,revision) 缓存实例
  channel_probe.cj        模型清单同步 + 三枪能力探测
```

消费方改造（`_chatModel` 单例 → 解析键）：

```cj
// main.cj（示意）：不再持有 ChatModel 实例，改为持有解析键
let modelKey = ModelKey(config: Config.MODEL_CONFIG)   // "arcbench:deepseek-v4-flash"
WebMCPController(skillManager, modelKey, agentLoadManager)
// WebMCPProtocol 内：按 session 缓存实例，revision 变化 → 下一请求用新实例
```

> 对 `WebMCPProtocol.cj:132-137`（`def.model` 含 `:` 时新建模型）无需改动：它本就是「按 Agent 定义选通道」的天然落点，改由 router 解析即可实现 **Agent 级通道**。

---

## 7. 选路与自动切换

```
resolve(requestCtx) :
  1. 收集候选规则：global + agent:<id> + task:<type>（具体者优先）
  2. 按 require_capabilities 过滤通道与模型（tools/vision/stream…）
  3. 按 strategy 排序：
       priority → 规则内 channel_chain 顺序
       cost     → model_pricing 单价 × 预估 token（可配预算上限）
       health   → 成功率/p95 加权
       system1  → **预留**：调用 Laya 打分（laya-system1-integration 用例#3）
  4. 逐个尝试，失败/熔断 → fallback_chain
  5. shadow_percent > 0 → 主结果照常返回，影子请求异步打到影子通道，结果入对比表
```

**熔断**：连续 N 次失败或错误率超阈值 → 通道置 `degraded` 并冷却；冷却结束半开探测，成功后归位（REQ-DMC-011）。

**Agent 自主切换**：`llm_channel_switch` 工具受「允许自动切换」开关约束；每次自动切换写审计（operator=agent）。

---

## 8. API 设计

> 前缀沿用 `/api/v1/uctoo/...`；插件轨路由由 `external_plugin_route_gateway.registerPluginRoutes` 注册（现状为启动期注册，Phase 2 需增加运行时注册入口）。

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/v1/uctoo/llm_channel/list` | 通道列表（含状态/健康/是否默认，密钥掩码） |
| GET | `/api/v1/uctoo/llm_channel/:id` | 详情 |
| POST | `/api/v1/uctoo/llm_channel/add` / `edit` / `del` | 增删改（写审计） |
| POST | `/api/v1/uctoo/llm_channel/:id/toggle` | 启停 |
| POST | `/api/v1/uctoo/llm_channel/:id/default` | **一键设为默认**（热生效核心动作） |
| POST | `/api/v1/uctoo/llm_channel/:id/test` | 连通性测试（返回错误明细） |
| POST | `/api/v1/uctoo/llm_channel/:id/probe` | 三枪能力探测 + 写回能力位 |
| POST | `/api/v1/uctoo/llm_channel/:id/sync-models` | 拉 `{base}/models` 同步清单（新模型 `pending`） |
| GET | `/api/v1/uctoo/llm_channel/models` | 全通道可用模型（供下拉选择） |
| GET | `/api/v1/uctoo/llm_channel/health` | 健康总览 |
| GET | `/api/v1/uctoo/llm_channel/audit` | 变更审计 |
| POST | `/api/v1/uctoo/llm_channel/reload` | 手动触发注册表刷新（救急） |
| GET | `/api/v1/uctoo/llm_channel/catalog` | **用户面（REQ-DMC-021）**：普通用户可读的通道目录——仅 `enabled` 且 `scopes` 含 `"user"` 的通道；只含 code / 显示名 / 图标 / 能力标签 / 倍率标签（可空）；**不含** base_url / secret_ref / 健康 / 审计等管理字段。独立权限节点，与管理 API 的 RBAC 分离 |

**请求级通道指定（用户切换的 runtime 落点）**：聊天请求（`webmcp/mcp` 的 completion / stream 参数）支持显式携带 `model: "<channel>:<modelId>"`；`WebMCPProtocol` 解析优先级 = **请求级显式指定 > Agent `def.model` > 全局默认**。该改造与 T010（`_chatModel` 单例 → 请求边界解析）是同一处落点；语义仍走 `parseModel` 严格校验（`provider:model` 必须显式，不猜通道、不改写）。切换只影响后续请求，进行中流式会话按 drain 语义完成（REQ-DMC-004）。

**Agent 工具**（对齐 `plugin_activate` 等既有范式）：`llm_channel_list` / `llm_channel_test` / `llm_channel_probe` / `llm_channel_switch`。

**宿主服务扩展**：`host.secret`（`get` / `has`），沿用 `cordis_host_services.cj:68-77` 的注册方式，纳入白名单/权限校验。

---

## 9. 前端设计（web-admin）

新增 `apps/web-admin/web/src/views/ai/model_channel/`：

- `index.vue`：通道卡片/表格列表（状态徽标、默认标记、健康条、最近探测时间）
- `components/channel-form.vue`：按 `protocol` 动态渲染字段（OpenAI 兼容只显示 URL+密钥；`plugin:*` 显示插件自定义字段，来自 `adapter.describe`）
- `components/probe-result.vue`：三枪结果（chat/stream/tools/vision）+ 原始错误（如 `provider_not_selected`）
- `components/model-list.vue`：模型清单、能力位、启停（`pending` 高亮）、同步按钮
- `components/route-rule.vue`：作用域 + 能力要求 + 候选链 + 回退链（Phase 2）
- `components/audit-drawer.vue`：变更记录
- `components/shadow-compare.vue`：影子流量对比（Phase 3）

交互要点：**设为默认**按钮需二次确认并提示「进行中的会话将在 drain 策略下沿用旧通道」；密钥输入框永远掩码 + 「已配置」状态；测试按钮返回可复制的错误原文。

菜单与权限：挂在既有系统管理下（参考 `views/system/config` 与 `menu-routing-from-permissions.md` 的菜单-权限驱动方式）。

### 9.1 聊天框通道切换器（REQ-DMC-021，产品参考 `chatComponent.png`）

位置：web 聊天输入框**右下角「当前模型」按钮**（截图中 `Hy3 ⌄`），点击弹出通道下拉。

下拉结构与截图逐项对照：

| 截图元素 | 本期处理 | 说明 |
|---|---|---|
| 具体通道列表（Hy4 preview / Hy3 ✓ / Space-Bunny / Deepseek-V4.1-Flash / GLM-5.3 …，含标签与倍率） | **本期实现** | 数据源 = `catalog` API；当前选中打 ✓；标签（夜间免费/限时折扣）与倍率可空 |
| 「快速 / 均衡 / 极致」三档 | **本期不实现** | 组合通道（预设路由），归 `laya-system1-integration` 关联工程（§12）；前端本期不渲染或置灰 |
| 「Max 模式」开关 | **本期不实现** | 未在需求范围内 |
| 「配置自定义模型」入口 | **本期不做独立功能** | 管理员可跳转通道管理页；普通用户隐藏 |

交互要点：用户选择后**每条聊天请求显式带** `model: "<channel>:<modelId>"`（无状态，服务端不额外建会话态）；前端持久化用户上次选择（localStorage 或用户偏好），新会话默认沿用；切换仅影响后续消息（drain），下拉内如需提示沿用 §9 的 drain 文案。普通用户无任何 `llm_channel` 管理 API 权限，目录字段已裁剪（无密钥/URL/健康）。

### 9.2 Web 聊天入口文件地图与二次开发注意事项

> 落地复盘（2026-10-06）：T037 的通道选择器在 `/chat` 路由页（`views/chat/index.vue` 的 `ChatRemoter` 已接 `channel-catalog`）可见，但用户实际最常用的**全局浮动抽屉**（`App.vue` 的 `TinyRemoter`）看不到——因为只给全局抽屉传了 `:llm-config`（单数），没传 `:llm-configs`（复数）。`TinyRobotChat.vue:68` 的 `v-if="llmConfigsRef && llmConfigsRef.length > 0"` 因此恒假，选择器静默不渲染。dist 里其实已含选择器代码，是**接线漏了不是没构建**。下文是改聊天代码前的定位地图，避免再改错入口。

#### 9.2.1 文件地图（改之前先认准文件）

| 层 | 文件（相对 `apps/web-admin/web/`） | 角色 | 关键事实 |
|---|---|---|---|
| **入口 A（最常用）** | `src/App.vue` | 全局浮动 `TinyRemoter`（抽屉，`title="UCTOO 智能助手"`），挂在根组件，任何页面可唤起 | 用 `TinyRemoter`（`@opentiny/next-remoter`）。**必须同时传 `:llm-config` 和 `:llm-configs` + `v-model:selected-model-id`**，通道按钮才出现 |
| **入口 B** | `src/views/chat/index.vue` | `/chat` 路由页（「AI 助手」整页） | 用 `ChatRemoter` 组件，传 `:channel-catalog="channelCatalog"`；同样调 `getChannelCatalog()` |
| 共享 SDK 层 | `src/lib/webmcp-sdk/packages/next-remoter/src/components/ChatRemoter.vue` | 封装 `TinyRemoter`，把 `channel-catalog` 透传 | 一般**不要改**，只改调用方（App.vue / views/chat） |
| 共享 SDK 层 | `src/lib/webmcp-sdk/packages/next-remoter/src/components/TinyRobotChat.vue` | 真正渲染输入框 + `ModelSwitch` | **第 68 行**：`<ModelSwitch v-if="llmConfigsRef && llmConfigsRef.length > 0">` —— 选择器仅在 `llmConfigs` 非空时渲染。SDK 内部，非必要不碰 |
| 数据层（store） | `src/store/models/uctoo/llm_channel.ts` | Pinia ORM store，封装所有通道 API | `getChannelCatalog()` → `GET /api/v1/uctoo/llm_channel/catalog`（用户面只读目录）；其余是管理 API |

两个入口共用**同一只读目录 API**（`/llm_channel/catalog`）和**同一 localStorage 记忆键**（`uctoo_llm_channel_last`），所以用户在一个入口选的通道，在另一个入口也生效。

#### 9.2.2 二次开发七条铁律

1. **双入口必须同步改**：涉及「通道选择器显示/行为/记忆」的改动要同时落在 `App.vue` 与 `views/chat/index.vue`，只改一个两入口表现会分裂（T037 教训）。
2. **通道选择器靠 `llm-configs`（复数）驱动，不是 `llm-config`（单数）**：`TinyRobotChat.vue:68` 的 `v-if` 只看 `llmConfigsRef`；只传单数 prop 时按钮**静默消失、无报错**（最隐蔽的坑）。`App.vue` 需 `:llm-config` 且 `:llm-configs`；`views/chat` 需 `:channel-catalog`。
3. **model id 严格用 `"<code>:<modelId>"`**：`llmConfigs` 的 `id`/`model` 必须拼 `${c.code}:${c.default_model}`，与 T036 严格语义一致（不补前缀、不猜通道）。拼错 → 后端 `parseModel` 直接拒。
4. **前端只消费只读 `catalog` 目录 API，绝不用 `llm_channel` 管理 API 喂选择器**：管理 API 含 `base_url`/`secret_ref`/`health` 且普通用户无权限；目录已裁剪，直接 `getChannelCatalog()`。
5. **用户可见通道由后端决定**：选择器只渲染 `catalog` 返回项（`status=enabled` 且 `scopes` 含 `"user"`），前端不要自己再过滤或硬编码；想加用户可选通道 → 改后端 `scopes`/`status`。
6. **别动 `TinyRobotChat.vue` / `TinyRemoter` 内部**（在 `lib/webmcp-sdk`，属 vendored SDK）。接线逻辑写在 `App.vue` 与 `views/chat/index.vue`；只有确需改 SDK 交互才碰，且改动影响全工程所有 `TinyRemoter` 用法。
7. **改完必须 `npm run build` + 跑 `scripts/check-vue-refs.cjs`**：仅凭「dist 里有相关字符串」不能证明接线正确（T037 的 dist 已含选择器代码却不渲染）。

> 完整版（含「改 X 动哪个文件」对照表与自检清单）见二次开发手册 `skills/uctoo-dev-manual/specs/web-chat-entry-points.md`。

---

## 10. 迁移路径（不改变现状语义的前提下推进）

| 步骤 | 动作 | 风险 |
|---|---|---|
| M1 | 建 4+1 张表；写 `channel_service.seed()`（把 `DEFAULT_PROVIDER_MAP` 20 项落成种子记录） | 低 |
| M2 | `ChannelRegistry` 上线：启动时「DB 优先、空则播种、DB 不可用则种子兜底」 | 低 |
| M3 | `ModelManager` 改为查注册表；`BUILTIN_SEED` 保留 | 中（8 个调用点需回归） |
| M4 | `_chatModel` 单例 → `ModelKey` + 实例缓存；`main.cj` 不再因模型失败跳过路由注册 | **中高**（WebMCP/Agent 全链路回归） |
| M5 | 通道管理 API + Agent 工具 | 低 |
| M6 | 前端页面 + 探测 + 模型同步 | 低 |
| M7 | `host.secret` + L3 适配器插件轨 + 运行时插件发现/注册 | 中高（cordis 侧改造） |
| M8 | 路由规则、健康熔断、成本策略、System-1 预留接口 | 中 |
| M9 | 影子/灰度 | 低 |

**回滚**：每步都可用 `.env` 的 `MODEL_CONFIG` 覆盖（逃生舱）；M3/M4 出问题可一键回退到旧 `ModelManager` 行为（保留 `BUILTIN_SEED` 常量表即保留回滚能力）。

---

## 11. 风险与对策

| 风险 | 对策 |
|---|---|
| 热路径 + DB 依赖引入新故障面 | 内存快照 + revision；DB 挂了用最后一份快照，再退化种子 |
| 切换时会话割裂 | drain 默认策略 + 显式提示；`immediate` 可选 |
| 插件代理流式背压 | 分帧协议 + 超时熔断 + 回退链；适配器必须先过「三枪」才允许设为默认 |
| 凭证泄露 | `host.secret` + 掩码 + 审计不含明文 |
| 配置字段膨胀 | 通道/模型/路由三表分层；`config` jsonb 只放协议级附加参数 |
| 与现有 `system-config` 职责重叠 | 明确分工：`config` 表管通用系统配置；通道配置独立建表（避免 config 表语义膨胀），仅在 `config` 页保留入口跳转 |
| 插件目录新增不被发现 | Phase 2 增加运行时发现/注册入口（现状 `reconcileDesired()` 仅启动调用一次） |

---

## 12. 与 Laya System-1 的衔接（后续）

`laya-system1-integration/spec.md` 用例 #3「模型路由」正是本设计的 `strategy=system1`：

- 本设计负责**执行面**（通道数据、实例、切换、回退、可观测）；
- Laya 负责**决策面**（用 `laya score/predict` 评估请求难度 → 快模型 / 强模型）；
- 接口约定：`ModelRouter` 的 `strategy` 为可插拔策略，Phase 3 增加 `System1RouteStrategy`，通过 Laya MCP 工具打分后返回候选排序。

这样「按任务自动切换大模型提供商」就有了两条腿：**规则（确定性）+ 打分（AI）**，双驱动在这里再次成立。

> **组合通道归 laya 关联工程**：`chatComponent.png` 中的「快速 / 均衡 / 极致」三档即**组合通道**——把多个具体通道按场景（快/均衡/强）打包成一档的预设路由，是 `strategy` 决策面的产品化形态。归 `laya-system1-integration` 工程与 System-1 打分一起实现；本 spec 只交付其数据地基：**具体通道目录（catalog）+ 请求级通道指定 + 请求边界热生效**。前端本期对这三档不渲染或置灰，避免做出空壳入口。
