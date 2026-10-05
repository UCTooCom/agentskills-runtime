---
name: {{name}}
description: >
  L3 process-isolated plugin {{name}} ({{className}}). Loaded by the host via
  stdio JSON-RPC (cordis), registered from plugin.yaml, no host recompile needed.
  Provides versioned service handlers consumed by the host; declare your own
  capabilities in the handler bodies. Triggers on: {{name}} plugin capability
  discovery, {{name}} host integration.
license: MIT
plugin: {{name}}
---

# {{className}}（L3 进程隔离轨插件）

本插件是**独立 cjpm executable 工程**，运行在与宿主分离的进程里，通过 stdio
JSON-RPC（cordis NewlineFraming）与宿主通信。

## 运行模型

- 宿主启动时扫描 `plugin.yaml`，`mode: process` 的条目交由 `CordisHostManager` 拉起；
- 传输固定 stdio，握手协议由 `PluginRuntime.run(...)` 完成，业务代码只写 handler；
- 插件**不继承**宿主环境变量，命令行也不带密文；需要凭证时经
  `ctx.invoke("host.secret", "get", { ref: "env:NAME" })` 按引用名向宿主代取；
- 插件不进入宿主编译图：改代码只需在本目录 `cjpm build`，**不必重编宿主**。

## 能力说明

- 由 `src/{className}Handlers.cj` 注册的服务方法（生成器给出 CRUD 骨架，按需改写）
- 可逆效果：`src/{className}Effects.cj` 的 `ctx.effect` 清理栈，卸载时逆序执行

## 使用方式

1. **服务调用**：宿主经 `client.call("invoke", { service, method, args })` 调用，
   `service` 为插件名，`method` 为注册时的 key。
2. **HTTP 路由**（如在 `plugin.yaml` 声明了 `routes`）：
   宿主经 `ExternalPluginRouteGateway` 注册，路径按需声明。

## 约束

- **stdout 是协议通道**：日志/诊断只能写 `stderr`（`eprintln`）。任何
  `print`/`println` 都会破坏帧解析导致握手失败。
- **失败不要抛 JSON-RPC error**：返回结构化失败结果（如 `{ errno, errmsg }`），
  这样宿主能把原文透传给调用方；抛异常会被包成字符串、丢失结构。
- **不要把密钥写进日志、配置或 `.env`**：只用 `host.secret` 代取。
- 插件停用后 HTTP 路由降级为 503（路由注册不删除），服务注销后调用返回未就绪。
