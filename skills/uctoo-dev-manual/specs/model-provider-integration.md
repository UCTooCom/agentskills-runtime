# 接入新大模型通道（Model Provider）SOP

> 沉淀自 2026-09-23/24 接入 EvoMap 的实测与踩坑（含「只改了一个文件」导致的通道不可见问题）。
> 适用范围：`apps/agentskills-runtime`。

## 0. 一句话结论

**OpenAI 兼容的新通道最少要改 2 个 `.cj` 文件 + 1 个 `.env`**：

| # | 文件 | 作用 | 漏了会怎样 |
|---|------|------|-----------|
| 1 | `src/model/model_manager.cj` | 真正的通道实现入口（provider 表 + 模型构造分支） | 通道**完全不可用**（`is invalid. Only [...] are supported now.`） |
| 2 | `src/app/controllers/uctoo/model/ModelController.cj` | 管理后台「模型列表」的数据源（`providerNames` 数组） | 通道**能跑但后台看不到、选不到**——最隐蔽、最容易漏 |
| 3 | `.env` | `<P>_BASE_URL` / `<P>_API_KEY` + 切换 `MODEL_*` | 无凭据 → 启动告警 / 401 |

非 OpenAI 兼容的通道（自定义请求/响应结构）**还要再加第 4 处**：`src/model/<provider>/` 专用包。

---

## 1. 第 1 处：`src/model/model_manager.cj`

### 1.1 `DEFAULT_PROVIDER_MAP` 注册（约 40-90 行）

```cj
("evomap",    ProviderConfig("EVOMAP_BASE_URL", // OpenAI-compatible Chat Completions Gateway
                            "https://api.evomap.ai/v1",
                            "EVOMAP_API_KEY")),
```

三个字段依次是：**baseURL 的环境变量名 / 默认 baseURL / apiKey 的环境变量名**。

> 命名铁律：环境变量必须叫 `<PROVIDER 大写>_BASE_URL` 与 `<PROVIDER 大写>_API_KEY`。
> `src/config/config.cj:305` 的 `getModelBaseUrl()` 会按 `MODEL_PROVIDER.toAsciiUpper()` 拼名字去取，
> 不按这个约定命名就会取不到。

### 1.2 `createChatModel` 分支（约 289 行）

OpenAI 兼容通道直接复用 `OpenAIChatModel`，把自己的 provider 名加进 case 列表：

```cj
case "openai" | "dashscope" | "ark" | "deepseek" | ... | "atomgit" | "gmicloud" | "evomap" =>
    return OpenAIChatModel(modelConfig.provider, modelConfig.name, apiKey: modelConfig.apiKey, baseURL: modelConfig.baseURL)
```

顺便在 `createEmbeddingModel`（318 行）/ `createImageModel`（350 行）加分支 —— **前提是该通道真的提供对应能力**。
EvoMap Gateway 只有 Chat Completions，硬加 embedding/image 会在调用时报「模型不存在」。

### 1.3 `normalizeModelName` 前缀守卫（约 129 行）⚠️ 高频坑

该函数会把含 `v4-flash` / `v4.1` 等代次前缀的名字收敛成官方 ID。
若你的模型名形如 `evomap-deepseek-v4-flash`（**带本厂前缀，但不是 deepseek 官方 ID**），
不加守卫就会被改写成 `deepseek-flash`，请求发到 deepseek 官方 → 401/404。

守卫写法（已内置，新增 provider 自动生效）：

```cj
for (provider in getAllProviderNames()) {
    if (provider != "deepseek" && lower.startsWith(provider + "-")) {
        return name      // 带其它厂商前缀 → 原样返回
    }
}
```

只要第 1.1 步把 provider 注册进 map，这里就自动覆盖，**不需要再改**——但要知道它的存在。

---

## 2. 第 2 处：`src/app/controllers/uctoo/model/ModelController.cj`（最容易漏）

`ModelController.list()` 里的 `providerNames` 是硬编码数组，是管理后台模型列表的唯一数据源：

```cj
let providerNames = [
    "deepseek", "openai", "ollama", "qwen", "stepfun",
    ...
    "ark", "siliconflow", "google", "openrouter", "maas",
    "sophnet", "orbitai", "gmicloud", "atomgit", "evomap"
]
```

**这份名单必须与 `DEFAULT_PROVIDER_MAP` 逐项对齐。** 只改 `model_manager.cj` 不改这里，
后台就看不到新通道——2026-09-23 接入 EvoMap 时正是漏了这一处。

---

## 3. 第 3 处：`.env`

```dotenv
# 通道凭据
EVOMAP_BASE_URL=https://api.evomap.ai/v1
EVOMAP_API_KEY=sk-evomap-xxxxxxxx

# 切换到该通道（三件套一起改）
MODEL_PROVIDER=evomap
MODEL_NAME=evomap-deepseek-v4-flash
MODEL_CONFIG=evomap:evomap-deepseek-v4-flash
```

要点：

- `MODEL_CONFIG` 必须是 `provider:modelName` 形式（带冒号）。裸名走 `inferProvider` 按前缀推断，有风险。
- **baseURL 只写到 `/v1` 这一级**，不要带 `/chat/completions`——`OpenAIChatModel` 会在 `create()` 里自己拼
  （`src/model/openai/chat.cj:265`）。写成全路径会变成 `/v1/chat/completions/chat/completions`。
- 若该厂商 **Hub 与 Gateway 用不同的 key**（如 EvoMap：`ek_` 打 `/api/hub/kg/*`，`sk-evomap-` 只能打
  `/v1/chat/completions`），务必按你实际调用的那个端点配 baseURL 与 key，两者**不互通**。
- L3 插件进程是独立 exe，不继承宿主内存配置，走自己的 `LRT_MODEL_BASE_URL/API_KEY/NAME`，
  与 `MODEL_PROVIDER` **解耦**，想让插件也切通道要单独改那三项。

---

## 4. 第 4 处（仅非 OpenAI 兼容）：`src/model/<provider>/` 专用包

参照 `src/model/tokendance/`（chat.cj / embedding.cj / image.cj / pkg.cj）：
自己定义响应结构体 + `fromJsonValue` 解析 + 实现 `ChatModel`，再在 `createChatModel` 里
`case "<provider>" => return XxxChatModel(...)`。

判断标准：**响应 JSON 结构、鉴权头、错误格式是否与 OpenAI 一致**。
一致就复用 `OpenAIChatModel`，不要造新包。

---

## 5. 验收清单（按顺序跑，别跳）

```bash
# 1) 全局搜索：provider 名至少出现在 model_manager.cj 与 ModelController.cj
grep -rn "evomap" src/

# 2) 编译
cd apps/agentskills-runtime && cjpm build

# 3) 启动日志必须出现这两行（缺第二行说明凭据/模型名有问题）
#    INFO Using chat model: evomap:evomap-deepseek-v4-flash
#    INFO Chat model created successfully

# 4) 真实发一条聊天，确认日志里有 HTTP 200
#    非流式路径会打 [HTTP Request] URL: <baseURL>/chat/completions
#    流式路径（asyncCreate）不打这行——排查时别误判成「没调用」
```

---

## 6. 已知坑位速查

### 6.1 聊天链路的选模逻辑在另一个文件

`src/app/services/webmcp/WebMCPProtocol.cj:135`：

```cj
let modelName = if (let Some(m) <- def.model) { m } else { "tokendance:mimo-v2.5" }
let agentModel = if (modelName.contains(":")) {
    ModelManager.createChatModel(modelName)   // Agent 自带模型
} else {
    chatModel.getOrThrow()                    // 退回全局 MODEL_* 通道
}
```

**WebMCP 聊天**走的是 `agents.model` 列；该列只有**含冒号**才被采纳，否则用全局通道。
切换默认通道时，若发现「改了 `.env` 但聊天没变」，先查 `agents` 表该 Agent 的 `model` 列。

同理，**cron 链路**（`agent-loop-main` 等，走 `AgentExecutionExecutor`）也用 `agents.model`，
与全局 `MODEL_PROVIDER` 是两条独立通道——排查时要分清你改的是哪一条。

### 6.2 出站 IPv6 导致「TLS 握手 failed: Failed to read TLS record header, got 0 bytes」

**症状**：`curl` 能通、控制台能看到调用记录，但 runtime 调用必失败；换别的厂商（如 deepseek）却正常。

**根因**：runtime 的 HTTP 客户端（`libs/http_lib`，`--cfg http=cj`）用 `std.net.TcpSocket` 解析域名。
若目标域名**同时有 AAAA 记录**，而本机/本网络**没有可用的 IPv6 出口**，TCP 建连后读不到任何 TLS 数据 →
报 `Failed to read TLS record header, got 0 bytes`。

**一句话排查**（在 runtime 所在机器执行）：

```bash
nslookup api.<厂商>.com        # 看有没有 AAAA 记录
curl -4 -s -o /dev/null -w "%{http_code}\n" --max-time 20 https://api.<厂商>.com/...
curl -6 -s -o /dev/null -w "%{http_code}\n" --max-time 20 https://api.<厂商>.com/...
```

- `-4` 返回 200、`-6` 返回 000 → **命中本坑**。
- 对照：纯 IPv4 的厂商（如 `api.deepseek.com`）永远正常，双栈厂商（如 Cloudflare 背后的
  `api.evomap.ai`）必失败——这是最快的判别特征。

**修法（按推荐度）**：

1. **hosts 绑定 IPv4**（零风险、可立即验证）：在系统 hosts 文件加一行
   `43.199.94.197 api.evomap.ai`（IP 取 `nslookup` 的 A 记录之一），重启 runtime。
   > 本项目已有先例：本地开发用 hosts 把 `javatoarktsapi.uctoo.com` 映射到 `127.0.0.1`。
2. **切 curl 后端**：`cjpm.toml` 的 `--cfg` 里把 `http=cj` 改成 `http=curl`
   （`src/utils/http/http_curl.cj` 走外部 `curl.exe`，双栈回退正常）。
   ⚠️ 影响面大：所有出站 HTTP 改走进程外 curl，需全链路回归 + 重编译。
3. **关闭本机 IPv6**（网卡属性 / `netsh`）：影响面更大，仅在排除法时用。

> 注意别混淆：`logs/runtime_start.log` 里 `TLS server handshake failed … 10053` 是**浏览器侧断开**
> 造成的服务端 inbound 噪声，与出站调用无关。

### 6.3 接入前必测两件事：function calling + 空响应

很多"OpenAI 兼容"通道只兼容了 `/chat/completions` 的**纯聊天**子集，agent 一上来就带 `tools`，
于是整条链路全废。**改 `.env` 之前先用 curl 打两枪**（把 `<BASE>`/`<KEY>`/`<MODEL>` 换成实际值）：

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

判读要点（都是 2026-09-24 实测踩出来的）：

- **`HTTP 200 + 空响应体（Content-Length: 0）`**：网关吞掉了上游错误。此时**换模型再试**，
  别急着改代码——同一网关下不同模型的部署状态不一样（有的没部署、有的上游 502）。
- **`三方请求失败: 400 "auto" tool choice requires --enable-auto-tool-choice`**：
  上游是没开 tool parser 的 vLLM/ModelArts。runtime 的 `src/model/openai/chat.cj:318`
  只发 `tools`、不发 `tool_choice`，服务端默认按 `auto` 处理 → **必然 400**。
  这类通道**只能聊天，不能跑 agent 的工具调用**，别拿它当主通道。
- 通道是否挑得动 agent，看 ② 的 `tool_calls` 是否非空，不看 ①。

实测快照（2026-09-24，同一台机器）：

| 通道 | Base URL | IPv6 | 纯聊天 | function calling | 结论 |
|------|----------|------|--------|------------------|------|
| atomgit | `https://api.atomgit.com/api/v5` | 纯 A 记录（116.205.6.218） | ✅（Qwen3-30B-A3B-Instruct-2507 / Qwen3-30B-A3B / Qwen2-VL-72B / openPangu-2.0-Flash） | ❌ 400 auto tool choice | 只能聊，不能跑工具 |
| sophnet | `https://www.sophnet.com/api/open-apis/v1` | 纯 A 记录（8.147.223.88） | ✅ | ✅ `DeepSeek-V4-Pro-0813` 正常返回 `tool_calls` | **agent 主通道首选** |
| stepfun | `https://api.stepfun.com/v1` | — | ❌ `quota_exceeded` | — | 需充值 |
| deepseek | `https://api.deepseek.com` | 纯 A | ❌ 402 Insufficient Balance（`total_balance: -0.66`、`is_available:false`） | — | 欠费，充值后即恢复（历史主通道） |
| tokendance | `https://tokendance.space/gateway/v1` | — | ❌ 402 `insufficient_quota` | — | 需充值 |
| maas（华为云） | `https://api.modelarts-maas.com/v2` | — | ❌ 404 `ModelArts.81009 Invalid model` | — | 模型名已下线，需重查模型清单 |
| evomap | `https://api.evomap.ai/v1` | **双栈（Cloudflare AAAA）** | 见 §6.2 | — | 本机无 IPv6 出口 → TLS 读 0 字节 |

> 判余额不要只看 `/chat/completions` 的 402：先打 `GET https://api.deepseek.com/user/balance`，
> `is_available:false` 就说明整个 key 停用，换模型也没用（deepseek-flash / deepseek-v4-pro 都是 402）。

### 6.4 cron 表达式必须是 6 段

`SchedulerEngine` 用 f_ticktock 的 CronCompiler，口径是 **6 段（秒 分 时 日 月 周）**，且**不能有 `?`**。
5 段会被误解释（实测 `0 * * * *` 被当「秒=0, 分=*」→ **每分钟**触发），
含 `?` 的表达式会被静默判为不合法而整行跳过（表现为调度永不触发、无报错）。

---

## 7. 变更记录

| 日期 | 内容 |
|------|------|
| 2026-09-23 | 新增 EvoMap 通道（仅改 `model_manager.cj` + `.env`，**漏改 `ModelController.cj`**） |
| 2026-09-24 | 补齐 `ModelController.cj` 名单（含此前漏登记的 ark/siliconflow/google/openrouter/maas/sophnet/orbitai/gmicloud/atomgit）；定位出站 IPv6 坑并写入 §6.2；本文件建立 |
| 2026-09-24 | `.env` 主通道 evomap → atomgit；新增 §6.3「接入前必测 function calling + 空响应」与各通道实测快照 |
| 2026-09-24 | atomgit 在 runtime 内**必失败**的真因：agent 首轮就带 `tools`，该通道返回 HTTP 200 空体（curl 复现一致），不是网络问题；`.env` 回退 deepseek 官方，但该 key 欠费（402 / `is_available:false`）。实测唯一能跑满 agent 工具链的仍是 sophnet `DeepSeek-V4-Pro-0813` |
