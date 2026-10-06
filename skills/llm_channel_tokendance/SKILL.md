---
name: llm_channel_tokendance
description: >
  L3 通道适配器插件（模式B）。为 protocol=plugin:llm_channel_tokendance 的
  llm_channel 通道提供 adapter.describe / chat / chatStream / probe 四个契约方法，
  经 stdio JSON-RPC 被宿主调用。密钥经 host.secret 按引用名代取，进程内不落明文。
  Triggers on: llm_channel 通道 protocol=plugin: 模式的探测/对话/能力发现，
  Tokendance 专用网关接入。
license: MIT
plugin: llm_channel_tokendance
---

# llm_channel_tokendance（L3 通道适配器）

本插件是**大模型通道适配器**，是「动态大模型通道」模式 B（私有协议）的参考实现。

## 为什么需要它

模式 A（宿主内直通）覆盖 `openai-chat` / `ollama` / `llamacpp` / `tokendance` 这类
**协议现成**的通道。剩下的是**私有协议**对端：HTTP 调用本身不复杂，复杂的是鉴权方式、
请求体形状、流式分帧。为每家写一个 `MagicXxxChatModel` 塞进宿主会造成两个问题：

1. **宿主膨胀** —— 每接一家多一个模型实现 + 一份依赖，宿主发布节奏被外部需求绑架；
2. **密钥扩散** —— 非标准鉴权头的处理逻辑散落宿主各处，难以统一约束。

模式 B 把这类通道整体推到 L3 进程插件：宿主只保留「跨进程调用 + 熔断 + 回退」骨架。

契约全文：[`docs/ref/llm-adapter-contract.md`](../../../docs/ref/llm-adapter-contract.md)

## 接入方式

1. **落库一条通道记录**（或在界面「大模型通道」新增）：

   | 字段 | 值 |
   |------|-----|
   | `code` | `tokendance` |
   | `protocol` | `plugin:llm_channel_tokendance` |
   | `base_url` | `https://tokendance.space/gateway/v1` |
   | `secret_ref` | `env:TOKENDANCE_API_KEY` |

2. **宿主 `.env` 配密钥**：`TOKENDANCE_API_KEY=sk-xxx`（插件进程读不到它，靠宿主代取）

3. **同步模型清单**：界面「模型清单 → 拉取清单」会调 `adapter.describe` 写入 `llm_channel_model`

4. **探测验证**：界面「探测」按钮调 `adapter.probe` 跑三枪（chat / stream / tools），
   结果直接显示在探测面板——包括网关返回的**原始错误文本**

## 四个契约方法

| 方法 | 用途 | 宿主侧消费者 |
|------|------|-------------|
| `adapter.describe` | 能力位 + 模型清单（纯静态声明，不出网） | `syncChannelModels` / 通道详情 |
| `adapter.chat` | 非流式对话 | `PluginChatModel.create` |
| `adapter.chatStream` | 分帧流式（NDJSON） | `PluginChatModel.asyncCreate`（**宿主侧当前未启用**，见下） |
| `adapter.probe` | 三枪探测，只报事实 | `ChannelProbe.probeViaPlugin` |

### 流式当前不可用（已知且有明确原因）

`PluginChatModel.asyncCreate` 抛 `plugin_stream_unsupported`：仓颉 `AsyncChatChunk`
构造函数是 `protected`（包级可见），`magic.model.channel` 跨包造不出流帧；要打通需改
`magic.core.model` 公共基础设施。插件侧 `adapter.chatStream` 实现齐备，
等宿主放开后**只需解除宿主侧那一处抛异常**，插件零改动即可工作。

当前调用会返回 `ok=false` + 明确原因，而不是假装成功返回空流。

## 密钥安全边界（V5）

插件进程**不继承**宿主环境变量，命令行也不带密文。需要密钥时：

```jsonc
// 插件 → 宿主
{ "method": "host.secret", "params": { "method": "get", "ref": "env:TOKENDANCE_API_KEY" } }
// 宿主 → 插件
{ "result": { "ok": true, "value": "sk-****" } }
```

- `ref` 支持 `env:NAME`（环境变量）与通道 `code`（宿主从 `llm_channel.secret_ref` 解析）；
- 只想知道"配没配"用 `has` → 返回 `{ok, has}`，**不返回明文**；
- 宿主每次 `get` 写审计（谁、何时、按哪个引用取）；
- 插件**不把**明文写进日志、配置或 `.env`。

## 排障

插件侧自检（不依赖密钥的明文外流）：

```jsonc
// service = "llm_channel_tokendance/selftest"
{ "ok": true, "pid_alive": true, "secret_configured": false, ... }
```

| 现象 | 排查方向 |
|------|---------|
| 通道显示「不可用」 | 插件进程没起来 → 看宿主日志 `[cordis][llm_channel_tokendance]`，再看 `logs/await_trace.txt` |
| `secret_configured: false` | 宿主 `.env` 缺 `TOKENDANCE_API_KEY`，或 `llm_channel.secret_ref` 没配 |
| 探测三枪全红且 detail 是 `curl 调用失败` | 网络不通 / curl 不在 PATH（插件用 `curl` 出网，见 `src/adapter_http.cj`） |
| 探测 `chat` 红但 `stream` 绿 | 网关支持流式但 chat 端点行为不同 —— 看 detail 里的原始响应片段 |
| `stream_not_enabled` | 预期内：宿主侧流式未放开，走 `adapter.chat` |

## 约束（改代码前必读）

1. **stdout 是 JSON-RPC 协议通道**（cordis NewlineFraming 逐行解析）。
   日志/诊断只能走 `stderr`（`eprintln`）。任何 `print`/`println` 会破坏协议帧。
2. **失败不抛 JSON-RPC error**，返回 `{ ok: false, error, error_code }`。
   这样宿主能把原始错误原文透传到界面（契约 §3.2 / T017）。
3. **密钥不落盘不打日志**，只用 `host.secret` 代取。
4. 本目录是**独立 cjpm 工程**：`cd skills/llm_channel_tokendance && cjpm build`，
   **不需要重编宿主**；宿主侧通过 T025 的周期调谐（默认 60s）或 `plugin_refresh`
   工具发现新插件。
