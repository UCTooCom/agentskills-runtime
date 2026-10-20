# 接入新大模型通道（Model Provider）SOP

> 沉淀自 2026-09-23/24 接入 EvoMap 的实测与踩坑，以及 2026-10-05「动态大模型通道」上线后的路径调整。
> 适用范围：`apps/agentskills-runtime`。

## 0. 一句话结论（2026-10-05 起）

**新增一个通道，默认不改代码 —— 在界面「大模型通道」里配置即可。**

| 通道类型 | 走哪条路 | 要改代码吗 |
|---------|---------|-----------|
| **OpenAI 兼容**（含绝大多数网关/聚合平台） | 界面新增，`protocol = openai-chat` | **不改** |
| 已有协议的本地推理（Ollama / LlamaCPP） | 界面新增，选对应 `protocol` | **不改** |
| **私有协议**（对端既非 OpenAI 兼容也非 Ollama） | 写一个 **L3 适配器插件**，`protocol = plugin:<name>` | 只在插件内改，**不动宿主** |

代码路径（`model_manager.cj` / `ModelController.cj`）从**主路径降级为兜底**：
只在「需要新增一种全新协议形态」时才走，而那种情况现在有了更好的落点（L3 插件）。

---

## 1. 主路径：界面配置（不改代码）

### 1.1 前置：建库表（仅首次）

通道体系 5 张表（`llm_channel` / `llm_channel_model` / `llm_route_rule` /
`llm_channel_health` / `llm_channel_audit`）。已在目标环境落库的可跳过；
新环境用增量 SQL（幂等、不含 DROP、可直接粘 psql）：

```
sql/incremental/20261004_llm_channel.sql          -- 5 张表
sql/incremental/20261005_llm_channel_menu.sql     -- 菜单与角色授权
sql/incremental/20261005_llm_channel_probe_models_permissions.sql
sql/incremental/20261005_llm_route_rule_permissions.sql
```

执行后必须 `loaddbinfo`（让 ORM 看到新表结构）。

### 1.2 新增通道

界面路径：**AI → 大模型通道 → 新增通道**（路由 `/ai/model_channel/index`，
菜单节点 parent `00000000-0000-0000-0000-000000000032`）。

| 字段 | 说明 |
|------|------|
| `code` | 通道唯一标识，选路时按 `provider:model` 或 `channel:model` 引用 |
| `display_name` | 界面展示名 |
| `protocol` | `openai-chat` / `ollama` / `llamacpp` / `tokendance` / `plugin:<name>` |
| `base_url` | **只写到 `/v1` 这一级**，不要带 `/chat/completions`（见 §4.1） |
| `secret_ref` | 密钥**引用名**，不是明文。两种形式：`env:NAME` 或留空（本地推理无密钥） |
| `capabilities` | JSON 数组字符串：`["chat","stream","tools","embedding","image"]` |
| `is_default` | 是否全局默认通道（同时只能一个） |

密钥本体写在宿主 `.env`（插件进程读不到它，靠宿主按引用名代取）：

```dotenv
ARCBENCH_API_KEY=sk-xxx
```

### 1.3 同步模型清单

点「模型清单 → 拉取清单」，系统按 `protocol` 走对应路径拉模型列表写入
`llm_channel_model`。私有协议走 `adapter.describe`（插件侧声明）。

拉不到的可以手工在「模型」弹窗里加行。

### 1.4 探测验证（三枪）

点「探测」跑三枪：`chat` / `stream` / `tools`。

**探测结果里显示的是后端返回的原始错误原文**（如 `provider_not_selected`、
HTTP 状态码 + 响应体片段），不要在代码或配置里做二次包装——错误可辨是排障第一要素。

结果落 `llm_channel_health`；周期探活（默认 60s）会持续更新，连续失败自动置
`degraded` 并从选路候选里摘除，恢复后自动归位。

### 1.5 设为默认 / 热切换

- **界面切**：「设为默认」按钮。写 `llm_channel` 的 `is_default` + 记审计（`source=ui`），
  **不需要重启**（注册表 2s 定时轮询 + 写后同步广播）。
- **Agent 切**：`llm_channel_switch` 工具。**默认关闭**，需 `.env` 里
  `LLM_CHANNEL_AUTO_SWITCH=true` 并重启。关闭时工具**前置拒绝**并提示改用界面。
  > 为什么不默认开：Agent 擅自改全局默认通道影响面太大，切换权应留在管理员手里。

### 1.6 验收

```bash
# 1) 注册表已加载（日志里能看到 revision 变化）
grep -n "ChannelRegistry" logs/*.log | tail -5

# 2) 真实发一条聊天，确认选中的是新通道
#    界面「当前通道」Tag 应显示新通道名
```

---

## 2. 私有协议：L3 适配器插件（模式 B）

### 2.1 什么时候需要

对端**既不是 OpenAI 兼容也不是 Ollama** —— 鉴权头特殊、请求体形状特殊、流式分帧特殊。
判断标准：**响应 JSON 结构、鉴权头、错误格式是否与 OpenAI 一致**。
一致就走 §1（`protocol = openai-chat`），**不要造插件**。

### 2.2 为什么要插件而不是宿主加包

在宿主 `src/model/<provider>/` 加专用包，每接一家就多一个模型实现 + 一份依赖：
宿主代码与发布节奏被外部需求绑架，且非标准鉴权的密钥处理逻辑会散落宿主各处，
难以统一约束「插件/子进程不接触明文」。

插件模式把这类通道整体推到独立进程：宿主只保留「跨进程调用 + 熔断 + 回退」骨架。

### 2.3 三步

```bash
# 1) 生成骨架（确定性工具，不要手搓）
cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args \
  "--name <plugin_name> --mode process"
# 产出 skills/<plugin_name>/：plugin.yaml + cjpm.toml + src/{main,handlers,effects}.cj

# 2) 改 src/ 里的 handlers 实现 adapter.* 四个方法
#    契约全文：docs/ref/llm-adapter-contract.md
#    参考实现：skills/llm_channel_tokendance/src/adapter.cj + adapter_http.cj

# 3) 独立编译（**不需要重编宿主**）
cd skills/<plugin_name> && cjpm build
```

登记：通道表加一行，`protocol = plugin:<plugin_name>`，
`secret_ref = env:<PROVIDER>_API_KEY`。

生效：等周期调谐（默认 60s）**或** 调 Agent 工具 `plugin_refresh` **或** 重启宿主。
> 新增插件目录不重启宿主即可生效，见 `PluginHostManager.reconcile`
> （`PLUGIN_RECONCILE_INTERVAL_SECONDS=0` 可关闭周期调谐，只用工具手动触发）。

### 2.4 四个契约方法

| 方法 | 用途 |
|------|------|
| `adapter.describe` | 能力位 + 模型清单（静态声明，不出网） |
| `adapter.chat` | 非流式对话 |
| `adapter.chatStream` | 分帧流式（NDJSON） |
| `adapter.probe` | 三枪探测，**只报事实**不做熔断判断 |

### 2.5 插件侧四条铁律

1. **stdout 是 JSON-RPC 协议通道**：日志/诊断只走 `stderr`（`eprintln`）。
   任何 `print`/`println` 会破坏帧解析导致握手失败。
2. **失败不抛 JSON-RPC error**，返回 `{ ok: false, error, error_code }`。
   抛异常会被 cordis 包成 `INVOKE-ERROR: ...` 字符串，**丢失结构与原始错误文本**。
3. **密钥不落盘不打日志**：经 `ctx.invoke("host.secret", "get", { ref })` 代取，
   宿主每次 `get` 写审计。想知道"配没配"用 `has`（返回布尔，不返明文）。
4. **依赖只有 cordis + jsonvalue + 仓颉标准库** —— 一旦 import 任何 `magic.*` 包
   就编译失败（插件不进宿主编译图）。

### 2.6 已知限制

`adapter.chatStream`（流式）**当前在宿主侧不可用**：`AsyncChatChunk` 构造函数是
`protected`（包级可见），`magic.model.channel` 跨包造不出流帧。插件侧实现齐备，
等 core 开放帧工厂后**只需解除宿主侧那一处抛异常**，插件零改动即可工作。
当前调用返回 `ok=false` + 明确原因（`plugin_stream_unsupported`），上层降级到
`adapter.chat`（功能正确，无逐字增量）。

---

## 3. 兜底路径：改宿主代码（仅新协议形态）

以下场景才走这条路：需要一种**全新的协议形态**（不是"某家的私有协议"，
而是"宿主建模能力本身要扩展"，如新的流式抽象、新的多模态输入形态）。

| # | 文件 | 作用 | 漏了会怎样 |
|---|------|------|-----------|
| 1 | `src/model/model_manager.cj` | provider 表 `DEFAULT_PROVIDER_MAP` + `createChatModel` 分支 | 通道**完全不可用**（`is invalid. Only [...] are supported now.`） |
| 2 | `src/app/controllers/uctoo/model/ModelController.cj` | 管理后台模型列表数据源（`providerNames` 数组） | 通道**能跑但后台看不到、选不到**（最隐蔽） |
| 3 | `.env` | `<P>_BASE_URL` / `<P>_API_KEY` | 无凭据 → 启动告警 / 401 |
| 4 | `src/model/<provider>/` | 专用包（响应结构体 + `fromJsonValue` + `ChatModel` 实现） | 仅非 OpenAI 兼容时需要 |

> `DEFAULT_PROVIDER_MAP` 现在是**兜底路径**：动态通道选路失败时才回退到这里
> （见 `ModelManager.createChatModel` 的「注册表优先 → Legacy 兜底」）。
> 所以新增通道不再需要动它。

### 3.1 `DEFAULT_PROVIDER_MAP` 注册

```cj
("evomap",    ProviderConfig("EVOMAP_BASE_URL", // OpenAI-compatible Chat Completions Gateway
                            "https://api.evomap.ai/v1",
                            "EVOMAP_API_KEY")),
```

三个字段：**baseURL 的环境变量名 / 默认 baseURL / apiKey 的环境变量名**。

> 命名铁律：环境变量必须叫 `<PROVIDER 大写>_BASE_URL` 与 `<PROVIDER 大写>_API_KEY`。
> `src/config/config.cj:305` 的 `getModelBaseUrl()` 按 `MODEL_PROVIDER.toAsciiUpper()`
> 拼名字去取，不按这个约定命名就取不到。

### 3.2 `createChatModel` 分支

OpenAI 兼容通道直接复用 `OpenAIChatModel`，把 provider 名加进 case 列表：

```cj
case "openai" | "dashscope" | "ark" | "deepseek" | ... | "evomap" =>
    return OpenAIChatModel(modelConfig.provider, modelConfig.name, apiKey: modelConfig.apiKey, baseURL: modelConfig.baseURL)
```

顺便在 `createEmbeddingModel` / `createImageModel` 加分支 —— **前提是该通道真提供该能力**。
硬加会在调用时报「模型不存在」。

### 3.3 `ModelController.cj` 的 `providerNames` 必须逐项对齐

只改 `model_manager.cj` 不改这里，后台就看不到新通道 —— 2026-09-23 接入 EvoMap 正是漏了这处。

---

## 4. 已知坑位速查

### 4.1 `base_url` 只写到 `/v1`

不要带 `/chat/completions` —— `OpenAIChatModel` 会在 `create()` 里自己拼
（`src/model/openai/chat.cj:265`）。写成全路径会变成 `/v1/chat/completions/chat/completions`。

若厂商 **Hub 与 Gateway 用不同的 key**（如 EvoMap：`ek_` 打 `/api/hub/kg/*`，
`sk-evomap-` 只能打 `/v1/chat/completions`），按实际调用的端点配，两者**不互通**。

### 4.2 `MODEL_CONFIG` 必须是 `provider:modelName`（兜底路径才需要）

带冒号，程序不替你补前缀也不猜通道，裸名直接报错退出。
L3 插件进程走自己的 `LRT_MODEL_*`，与 `MODEL_PROVIDER` 解耦。

**LRT 模型通道**：插件侧 `LRT_MODEL_*` 与宿主 `llm_channel` 是两套。
若要让插件也用新通道，改插件的 `LRT_MODEL_BASE_URL` / `API_KEY` / `NAME`
（`.codeartsdoer/specs/dynamic-model-channel` 设计里这条是已知缺口，
插件轨切通道尚未接入注册表）。

### 4.3 聊天链路的选模逻辑在另一个文件

`src/app/services/webmcp/WebMCPProtocol.cj:135`：

```cj
let modelName = if (let Some(m) <- def.model) { m } else { { /* 兜底 */ } }
let agentModel = if (modelName.contains(":")) {
    ModelManager.createChatModel(modelName)   // Agent 自带模型
} else {
    chatModel.getOrThrow()                    // 退回全局通道
}
```

**WebMCP 聊天**走 `agents.model` 列；只有**含冒号**才被采纳。
改了默认通道但聊天没变 → 先查 `agents` 表该 Agent 的 `model` 列。

cron 链路（走 `AgentExecutionExecutor`）同样用 `agents.model`，与全局通道是两条独立链路。

### 4.4 出站 IPv6 导致「TLS 握手 failed: Failed to read TLS TLS record header, got 0 bytes」

**症状**：`curl` 能通、网关能看到调用记录，但 runtime 调用必失败；换别的厂商却正常。

**根因**：runtime 的 HTTP 客户端（`libs/http_lib`，`--cfg http=cj`）用 `std.net.TcpSocket`
解析域名。目标域名**同时有 AAAA 记录**而本机**无可用 IPv6 出口**时，
TCP 建连后读不到任何 TLS 数据。

**一句话排查**：

```bash
nslookup api.<厂商>.com        # 看有没有 AAAA 记录
curl -4 -s -o /dev/null -w "%{http_code}\n" --max-time 20 https://api.<厂商>.com/...
curl -6 -s -o /dev/null -w "%{http_code}\n" --max-time 20 https://api.<厂商>.com/...
```

`-4` 返回 200、`-6` 返回 000 → **命中本坑**。纯 IPv4 厂商永远正常，
双栈厂商（Cloudflare 背后）必失败 —— 这是最快的判别特征。

**修法（按推荐度）**：

1. **hosts 绑定 IPv4**（零风险、可立即验证）：加一行 A 记录 IP，重启 runtime。
2. **切 curl 后端**：`cjpm.toml` 的 `--cfg` 里 `http=cj` → `http=curl`。
   ⚠️ 影响面大：所有出站 HTTP 改走进程外 curl，需全链路回归 + 重编译。
3. **关闭本机 IPv6**：影响面更大，仅在排除法时用。

> L3 适配器插件默认走 `curl`（`src/adapter_http.cj`），**天然规避本坑**。

### 4.5 接入前必测两件事：function calling + 空响应

很多「OpenAI 兼容」通道只兼容 `/chat/completions` 的**纯聊天**子集，
agent 一上来就带 `tools`，整条链路全废。**配 `.env` / 配通道之前先打两枪**：

```bash
# ① 纯聊天：必须返回非空 choices
curl -4 -s --max-time 60 -X POST "<BASE>/chat/completions" \
  -H "Authorization: Bearer <KEY>" -H "Content-Type: application/json" \
  -d '{"model":"<MODEL>","messages":[{"role":"user","content":"hi"}],"stream":false}' | head -c 300

# ② 工具调用：choices[0].message 里必须出现 tool_calls
curl -4 -s --max-time 60 -X POST "<BASE>/chat/completions" \
  -H "Authorization: Bearer <KEY>" -H "Content-Type: application/json" \
  -d '{"model":"<MODEL>","messages":[{"role":"user","content":"北京时间几点？用工具"}],
       "tools":[{"type":"function","function":{"name":"get_time","description":"get time",
       "parameters":{"type":"object","properties":{"tz":{"type":"string"}},"required":["tz"]}}}],
       "stream":false}' | head -c 500
```

判读要点：

- **`HTTP 200 + 空响应体`**：网关吞掉了上游错误。此时**换模型再试**，
  同一网关下不同模型的部署状态不一样。
- **`400 "auto" tool choice requires --enable-auto-tool-choice`**：
  上游是没开 tool parser 的 vLLM/ModelArts。宿主只发 `tools` 不发 `tool_choice`，
  服务端默认按 `auto` → **必然 400**。这类通道**只能聊天，不能跑 agent 工具调用**。
- 通道挑不挑得动 agent，看 ② 的 `tool_calls` 是否非空，不看 ①。

> 界面「探测」按钮跑的就是这两枪（外加流式），所以**优先用界面探测**，
> 手工 curl 只在需要看完整响应体时才用。

### 4.6 网关登记名与厂商官方名冲突（ArcBench 实证）

**症状**：配了 `arcbench:deepseek-v4-flash` 却失败，网关返回
`provider_not_selected: no provider selected`（报「模型不存在」，极易误判成没部署）。

**判别特征**：该通道是**网关 / 聚合平台** —— 一个 key 代理多家模型，
`GET {base}/models` 返回的 id 里含别家厂商名。

**修法**：以网关自报的登记名为准，`curl {base}/models` 拉下来逐字抄。
程序侧**不做任何规范化**（历史上有过 `normalizeModelName()` 把
`deepseek-v4-flash` 收敛成官方 `deepseek-flash`，在 ArcBench 上实测 `provider_not_selected`，
已于 2026-10-01 删除）。

> 界面「拉取清单」取的就是 `GET {base}/models`，所以**优先用界面**，
> 抄错名字的概率最低。

### 4.7 cron 表达式必须是 6 段

`SchedulerEngine` 用 f_ticktock 的 CronCompiler，口径是 **6 段（秒 分 时 日 月 周）**，
且**不能有 `?`**。5 段会被误解释（`0 * * * *` 被当「秒=0, 分=*」→ 每分钟），
含 `?` 的表达式被静默判为不合法整行跳过（表现为调度永不触发、无报错）。

---

## 5. 选路：多通道并存时怎么决定用哪个

`llm_route_rule`（界面「路由规则」）按作用域配策略：

| 策略 | 行为 |
|------|------|
| `priority` | 按通道 `priority` 数值升序 |
| `health` | 按健康分降序（连续失败自动降权） |
| `system1` | 难度打分 → 快/强模型分流（难度低走快通道） |
| `cost` | 按 `model_pricing` 单价升序（便宜的优先） |

- **作用域**：`scope` + `require_capabilities`（如「要 vision 就只挑声明了 image 的通道」）
- **回退链**：`fallback_chain` —— 首选通道失败自动切下一个，无需人工介入
- **影子流量**：`shadow_percent` —— 影子请求永不替换主结果，只旁路记账用于对比
  （界面「影子对比」页看延迟/失败率差异）

---

## 6. 变更记录

| 日期 | 内容 |
|------|------|
| 2026-09-23 | 新增 EvoMap 通道（仅改 `model_manager.cj` + `.env`，**漏改 `ModelController.cj`**） |
| 2026-09-24 | 补齐 `ModelController.cj` 名单；定位出站 IPv6 坑（§4.4）；本文件建立 |
| 2026-09-24 | 新增「接入前必测 function calling + 空响应」（§4.5）与各通道实测快照 |
| 2026-09-24 | atomgit 在 runtime 内**必失败**的真因：agent 首轮就带 `tools`，该通道返回 HTTP 200 空体；实测唯一能跑满 agent 工具链的是 sophnet `DeepSeek-V4-Pro-0813` |
| 2026-10-01 | 新增 **ArcBench** 通道（`https://api.arc-bench.com/v1`）。新增 §4.6「网关登记名与厂商官方名冲突」并落地 `parseModel` 的 provider 守卫 |
| 2026-10-01 | **重构**：`parseModel` 恢复"写什么发什么"，删除 `normalizeModelName()` 与 `inferProvider()` + 裸名兜底。原则：**用户配置即事实，程序不做隐藏二次处理** |
| 2026-10-05 | **路径调整（本文档重写）**：「动态大模型通道」上线。新增通道改为**界面配置为主**（§1），原「改 2-3 个 `.cj` + `.env`」降级为兜底（§3，仅新协议形态时走）。新增**私有协议 L3 适配器插件**路径（§2），参考实现 `skills/llm_channel_tokendance/`。新增选路策略说明（§5）与插件侧四条铁律（§2.5） |
| 2026-10-05 | 记录已知限制：插件轨流式（`adapter.chatStream`）在宿主侧未启用（core 未开放流帧工厂）；插件轨切通道仍走 `LRT_MODEL_*`，未接入注册表（§4.2） |
