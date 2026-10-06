# llm_channel_tokendance 插件（L3 进程隔离轨 · 大模型通道适配器）

独立 cjpm executable 工程。**不提供 HTTP 路由**，只向宿主暴露 `adapter.*` 四个契约方法，
供 `protocol = plugin:llm_channel_tokendance` 的通道使用（模式 B：私有协议适配器）。

业务语义见 [`SKILL.md`](./SKILL.md)；契约全文见
[`docs/ref/llm-adapter-contract.md`](../../docs/ref/llm-adapter-contract.md)。

## 编译

```bash
cd skills/llm_channel_tokendance
cjpm build
```

产物：`target/release/bin/skill_llm_channel_tokendance.exe`

**独立编译即可，不需要重编宿主**（插件不进宿主编译图）。

## 登记到宿主

无需改任何集中式配置——宿主启动时扫描 `skills/*/plugin.yaml` 去中心化发现
（`PluginDiscoveryService.discover`）。本目录的 `plugin.yaml` 已写好：

```yaml
name: llm_channel_tokendance
mode: process
command: ./skills/llm_channel_tokendance/target/release/bin/skill_llm_channel_tokendance.exe
enabled: true
order: 30
```

生效方式二选一：

- **等周期调谐**（默认 60s，`PLUGIN_RECONCILE_INTERVAL_SECONDS` 控制）——不重启宿主；
- **立即生效**：Agent 工具 `plugin_refresh`，或重启宿主。

## 约束

- 依赖仅 `ystyle::cordis_plugin` / `cordis_core` / `jsonvalue` / `ystyle::jsonrpc`
  （+ 仓颉标准库）——**零 magic 包依赖**，这是插件能独立编译的前提
- 禁用 `@Plugin` 宏：用显式 API `PluginRuntime.run(...)`
- **stdout 是协议通道**：日志/诊断只走 `stderr`（`eprintln`）
- 失败返回 `{ ok: false, error, error_code }`，不抛 JSON-RPC error（保住原始错误原文）
- 凭证经 `host.secret` 按引用名代取，进程内不落明文
- 出网走 `curl`（`src/adapter_http.cj`），不依赖宿主 `http_lib`，也不碰 stdx OpenSSL DLL

## 目录

| 文件 | 职责 |
|------|------|
| `src/main.cj` | `PluginRuntime.run` 入口，注册 adapter + handlers + effects |
| `src/adapter.cj` | `adapter.describe` / `chat` / `chatStream` / `probe` 契约实现 |
| `src/adapter_http.cj` | curl 出网封装（状态码/响应体分离、流式 `--no-buffer`） |
| `src/handlers.cj` | 运维自检 handler（`selftest`，不取密钥明文） |
| `src/effects.cj` | `ctx.effect` 可逆效果注册（卸载时逆序清理） |
| `plugin.yaml` | 插件清单（宿主自动发现） |
