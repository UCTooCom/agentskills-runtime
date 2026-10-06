# 问题分析：大模型通道硬编码与重启依赖

> 工程：动态大模型通道（dynamic-model-channel）
> 日期：2026-10-02
> 方法：源码实证（路径 + 行号），不臆造

---

## 1. 现状：通道清单是编译期常量，配置是启动期快照

### 1.1 硬编码点（三处，缺一不可）

| # | 位置 | 内容 | 性质 |
|---|---|---|---|
| 1 | `src/model/model_manager.cj:33-94` | `DEFAULT_PROVIDER_MAP`：20 个 provider 的 `urlEnvVar / urlEnvValue / keyEnvVar` | **编译期常量**，新增通道必须改代码 |
| 2 | `src/model/model_manager.cj:229-233` | `createChatModel` 的 `match (modelConfig.provider)` case 列表（`"openai" \| "dashscope" \| ... \| "arcbench"`） | **编译期分支**，provider 不在列表里直接 `Unreachable` |
| 3 | `src/app/controllers/uctoo/model/ModelController.cj:23-31` | `providerNames` 数组（后台模型列表数据源） | 硬编码名单，与第 1 处需人工对齐，历史已漏改过两次 |

配套事实：`src/model/` 下只有 openai / ollama / dashscope / llamacpp / siliconflow / zhipuai / stepfun / tokendance 八个包真正实现协议，其余 provider 全部复用 `OpenAIChatModel`。**即：绝大多数通道之间的差别，只是 base_url + api_key + 模型名三元组**，没有任何理由把它们写进代码。

### 1.2 「必须重启」的成因（四条证据链）

1. **配置读一次就固化**：`src/config/config.cj:281-283`
   ```cj
   public static var MODEL_PROVIDER: String = getEnv("MODEL_PROVIDER").getOrDefault({ => "stepfun" })
   public static var MODEL_NAME:     String = getEnv("MODEL_NAME").getOrDefault({ => "step-3" })
   public static var MODEL_CONFIG:   String = getEnv("MODEL_CONFIG").getOrDefault({ => "stepfun:step-3" })
   ```
   Cangjie 的 `static var` 在类初始化时求值一次，没有失效/重载机制。
2. **模型实例是启动期单例并一路透传**：`src/app/main.cj:237 / :414` 建 `_chatModel`，经 `WebMCPRoutes.cj:19` → `WebMCPController.cj:216` → `WebMCPProtocol` 透传；同 session 复用。**换模型 = 换进程。**
3. **失败即阉割路由**：`src/app/main.cj:582-604` 模型创建失败会**跳过 chat 路由注册**——一旦通道不可用，runtime 起来就没有聊天能力，只能修配置重启。
4. **改配置不热生效**：`src/app/services/uctoo/ConfigService.cj:1011-1048` 的 `updateConfigByKey` 是「写 .env + 写 config 表」双写，全程**没有 reload / 事件通知**；`.env` 的改动也不会注入已运行进程。L3 插件是独立 exe，凭据只能靠**启动时** `std.env.setVariable` + `launchStdio` 传参（`.env` 注释 102-105 行已自陈此约束）。

> 结论：现有链路里，「换通道」在物理上等价于「重建进程状态」，重启不是习惯问题，是架构决定的。

### 1.3 已有可复用资产（不是从零开始）

| 资产 | 位置 | 可用度 |
|---|---|---|
| `config` 表 + 按 key 读写 API | `ConfigPO.cj:23`（`key/value/env_key/config_group/config_type/is_sensitive/validation_rule/editable/status`）、`ConfigRoute.cj:53-58`（`metadata` / `key/:key` / `batch`） | ✅ 可直接承载通道配置，但需扩字段或另建表 |
| 前端系统配置页（已有 `model` / `api_key` 分组） | `apps/web-admin/web/src/views/system/config/components/config-tab.vue:27-37` | ✅ 复用分组与控件渲染；**缺**专门的通道管理页 |
| 事件总线 | `src/plugin/spi_reexport.cj:28` `PluginEventBus`，`main.cj:764-778` 装配 | ✅ 可作配置变更广播载体 |
| 宿主服务代理（凭证集中托管范式） | `src/plugin/cordis_host_services.cj:68-77`（`host.db/log/cache/mcp/event/db_schema_lookup`），`:33-34` 明确「凭证由宿主集中管理，插件不接触凭证本体」 | ✅ 通道密钥的理想藏身处 |
| 计费与用量表 | `model_pricing`（`ModelPricingPO.cj:23`）、`llm_usage_logs`（`LlmUsageLogsPO.cj:25-97`） | ✅ 成本感知路由的现成数据源 |
| 每 Agent 自带模型串 | `AgentsPO.cj:52-53` `@ORMField['model']` | ✅ 天然的「按 Agent 选通道」落点 |

**没有的东西**：通道配置表、模型通道管理页面、配置变更 → 重建模型实例的通知链路、文件/表变更监听（全项目无 `FileWatch`；`SyncManager` 是显式触发的文件↔DB 同步，handler 只有 agent / agent_skill）。

---

## 2. 痛点分级

| 级别 | 痛点 | 影响 |
|---|---|---|
| **P0 阻塞** | 切换通道要重启 runtime | 生产环境不可接受；正在跑的长程任务/会话被打断；黑客松现场演示无法临场换通道 |
| **P0 阻塞** | 新增通道要改 3 处代码 + 重新编译（仓颉编译耗时） | 接入一个新厂商走上小时级；与「插件化、不硬编码」红线正面冲突 |
| **P1 严重** | 通道清单真相分散在代码 / .env / DB 三处 | 已发生过两次「改了 map 漏改 controller」；排查靠人肉对齐 |
| **P1 严重** | 凭证散落在 .env，改 key 要重启；插件进程靠启动传参 | 密钥轮换 = 停机；插件侧永远慢一拍 |
| **P1 严重** | 无能力探测，通道能力（tools / streaming / vision）靠文档口口相传 | 已踩坑：atomgit 首轮带 tools 返回 200 空体；ArcBench 登记名 ≠ 官方名（`provider_not_selected`） |
| **P2 体验** | 后台看不到通道列表、不能一键切默认、不能测连通 | 每次调通道都要登服务器改 .env |
| **P2 体验** | 通道挂了只能整体不可用，无降级 | 无健康探测 / 熔断 / 备用链 |

---

## 3. 与框架设计哲学的冲突（这是必须改的根本理由）

`docs/ref/AIDrivenArchitecture.md` 观点 1：**「不硬编码业务功能到系统中，所有功能均可通过可视化配置实现动态调整」**。

大模型通道是最典型的**业务功能**（选哪家厂商、用哪个模型、花多少钱），而当前它是全项目硬编码密度最高的地方之一。同时：

- 与 `plugin-system` 的「存量冻结红线 / 一切皆技能」矛盾：新能力应以插件形态交付，而每接一个厂商都要改宿主 `src/model` 代码；
- 与「双驱动」矛盾：无 AI 时这套硬编码清单仍需人工改代码重启（确定性路径不完备）；有 AI 时 AI 也无法自主切换通道（没有工具、没有数据）；
- 与 `AIDrivenArchitecture.md` 观点 2 的「确定性代码做确定的事」**一致**的部分要保留：**协议实现（如何发 HTTP、如何解析 SSE）是确定性的，应该写死在适配器里；选哪家厂商、用哪个模型是业务决策，应该是数据**。这条边界划清了，方案就不会滑向「配置地狱」。

---

## 4. 需求边界与约束

1. **不改**：`src/model/openai/` 等协议实现代码（确定性部分），`ChatModel` 接口语义。
2. **不动**：`.env` 作为**引导（bootstrap）配置**的地位，但要降级为「种子 + 逃生舱」，不再是唯一真相。
3. **保持**：`parseModel` 的严格解析（`provider:modelName` 必须显式写，程序不补前缀、不猜通道、不改写模型 ID）——这是 2026-10-01 刚定的口径，动态化后 provider 的合法集合来自注册表，但**不做隐式兜底**的原则不变。
4. **新增能力一律插件形态**：私有协议适配器走 L3 进程轨（`skills/<name>/plugin.yaml`，`mode: process`），不进宿主编译图。
5. **凭证不落插件进程参数**：沿用 `host.mcp` 的「宿主集中托管」范式。
6. **要能回退**：任何时刻 `.env` 的 `MODEL_CONFIG` 仍能覆盖（逃生舱），DB 不可用时退化为内置种子（离线可用 = 双驱动的「无 AI/无 DB 仍完备」要求）。

---

## 5. 问题定义（一句话）

> 需要一个**运行时可变、可视化可管、插件可扩展**的大模型通道注册与路由层，使「支持哪些通道、当前用哪个通道、谁来兜底」成为**数据**而非**代码**，并让通道切换在一次请求边界内平滑生效、无需重启进程。
