# agentskills-runtime PC 桌面客户端编码任务规划

> **文档定位**：本文档为 agentskills-runtime PC 桌面客户端的编码任务规划文档（tasks.md），将技术设计方案转化为可执行、可验收的任务清单。
>
> **生成日期**：2026-08-06 | **版本**：v2.5
> **规范目录**：`apps/agentskills-runtime/.codeartsdoer/specs/pc_desktop_client/`
> **需求基线**：`spec.md` v2.5 | **设计基线**：`design.md` v2.5
> **v2.5 变更说明**：在 v2.4 基础上重构 runtime 集成策略 — ①新增 M7 RuntimeIntegrator 子任务（runtime 发布版压缩包解压、集成目录版本检测、.env 自动生成、降级下载、进度推送）；②runtime 集成目录从 SDK node_modules 迁移到用户数据目录（`%APPDATA%/agentskills/runtime/`）；③SDK `downloadRuntime()` 从首次安装主方案降级为版本升级和降级修复方案；④M7 新增 runtime:integrate/runtime:integrateStatus/runtime:integrateProgress IPC 通道；⑤M9 新增 runtime tar.gz 资源复制和打包配置；⑥安装包体积约束从"完整版 ≤ 300MB"调整为"含 runtime 压缩包约 600-800MB"；⑦冷启动时间从"≤ 90s"调整为"≤ 60s"；⑧移除"精简版安装包"概念，统一为包含 runtime 的完整安装包；⑨更新需求覆盖矩阵和风险缓解措施
> **v2.4 变更说明**：在 v2.3 基础上新增登录态共享和运行时依赖管理 — ①新增 M5 登录态共享里程碑（AuthBridge 模块、postMessage 通信协议、safeStorage 持久化、HomeView 登录态 UI、验证）；②新增 M6 运行时依赖管理里程碑（DependencyManager 模块、OpenSSL 检测和安装、运行时环境检查、验证）；③原 M5 SDK 集成层重构重编号为 M7；④原 M6 首页与配置向导重构重编号为 M8；⑤原 M7~M9 重编号为 M9~M11；⑥更新总工期为 15.5 周（不含跨平台）
> **v2.3 变更说明**：在 v2.2 基础上修正 runtime 静态文件服务认知 — ①新增 RuntimeVersionDetector 模块任务（检测 runtime 版本，≥ 0.0.26 优先使用 runtime 静态文件服务）；②修正 HomeView.vue aibuilder URL 构建策略（根据 runtime 版本选择不同 URL）；③修正 WebAdminServer 为条件启动（仅 runtime < 0.0.26 时启动）；④修正 web-admin 构建产物嵌入方式（优先放入 runtime STATIC_FILE_ROOT 目录）；⑤修正 web-admin .env 配置管理方式（runtime 提供静态服务时 VITE_ 变量在构建时注入）；⑥修正启动流程（新增版本检测步骤）

---

## 任务依赖关系总览

```
M1 架构清理与模块增强（前置条件，所有后续里程碑依赖）
  1.1 移除 SSL IPC 通道 ──→ 1.2 增强 ConfigStore 配置结构 ──→ 1.3 增强 IPC 通信层
  1.2 ──→ 1.4 增强配置向导服务 ──→ 1.5 增强 .env 生成器
  1.3 ──→ 1.6 更新主进程入口 ──→ 1.7 清理渲染进程残留 ──→ 1.8 更新托盘菜单 ──→ 1.9 M1 验证

M2 UI 重构 — 左侧导航布局（依赖 M1）
  2.1 CSS 架构搭建 ──→ 2.2 AppSidebar 组件 ──→ 2.3 NavItem 组件
  2.1 ──→ 2.4 图标系统集成 ──→ 2.3
  2.2 + 2.3 ──→ 2.5 App.vue 布局重构 ──→ 2.6 路由扩展
  2.6 ──→ 2.7 新增 SkillsView/AgentsView ──→ 2.8 M2 验证

M3 PostgreSQL 集成管理（依赖 M1，可与 M2/M4 并行）
  3.1 PgManager 模块重构/增强 ──→ 3.2 PgsqlView.vue 增强
  3.1 ──→ 3.3 pgsql Store 更新 ──→ 3.4 IPC 通道注册
  3.4 ──→ 3.5 Preload 暴露 pgsql 命名空间
  3.1 ──→ 3.6 PostgreSQL 二进制资源打包 ──→ 3.7 数据库初始化脚本
  3.2 + 3.3 + 3.4 + 3.5 + 3.6 + 3.7 ──→ 3.8 M3 验证

M4 web-admin 集成与 runtime 版本检测（依赖 M1，可与 M2/M3 并行）【v2.3 修正】
  4.0 RuntimeVersionDetector 模块实现 ──→ 4.1 WebAdminServer 模块实现（条件启动） ──→ 4.4 IPC 通道注册（webadmin:*）
  4.0 ──→ 4.7 HomeView.vue aibuilder URL 修正（根据 runtime 版本选择）
  4.2 EnvSyncManager 模块实现 ──→ 4.4 IPC 通道注册（envsync:*）
  4.2 ──→ 4.3 web-admin .env 模板与生成逻辑
  4.4 ──→ 4.5 Preload 暴露 webadmin 和 envsync 命名空间
  4.1 ──→ 4.6 web-admin 构建产物嵌入与打包
  4.5 ──→ 4.7
  4.1 + 4.2 + 4.3 + 4.4 + 4.5 + 4.6 + 4.7 ──→ 4.8 M4 验证

M5 登录态共享（依赖 M1，可与 M2/M3/M4 并行）【v2.4 新增】
  5.1 AuthBridge 模块实现 ──→ 5.2 postMessage 通信协议 ──→ 5.3 safeStorage 持久化
  5.1 ──→ 5.4 IPC 通道注册（auth:*） ──→ 5.5 Preload 暴露 auth 命名空间
  5.5 ──→ 5.6 Auth Pinia Store 实现 ──→ 5.7 HomeView 登录态 UI
  5.1 ──→ 5.8 AppSidebar 登录状态 UI
  5.7 + 5.8 ──→ 5.9 M5 验证

M6 运行时依赖管理（依赖 M1，可与 M2/M3/M4/M5 并行）【v2.4 新增】
  6.1 DependencyManager 模块实现 ──→ 6.2 OpenSSL 检测逻辑 ──→ 6.3 OpenSSL DLL 内置与 PATH 配置
  6.1 ──→ 6.4 运行时环境依赖检查 ──→ 6.5 IPC 通道注册（dep:*）
  6.5 ──→ 6.6 Preload 暴露 dep 命名空间
  6.3 ──→ 6.7 OpenSSL DLL 资源打包
  6.6 ──→ 6.8 启动流程集成依赖检测
  6.1 + 6.2 + 6.3 + 6.4 + 6.5 + 6.6 + 6.7 + 6.8 ──→ 6.9 M6 验证

M7 SDK 集成层重构 + RuntimeIntegrator（依赖 M1，可与 M2/M3/M4/M5/M6 并行）【v2.5 重构】
  7.0 RuntimeIntegrator 模块实现 ──→ 7.1 SDK 集成层封装 ──→ 7.2 重构 RuntimeManager ──→ 7.3 更新 Runtime IPC
  7.0 ──→ 7.3（runtime:integrate/runtime:integrateStatus/runtime:integrateProgress IPC 通道）【v2.5 新增】
  7.2 ──→ 7.4 更新健康检查与崩溃恢复 ──→ 7.5 AI Key 测试连接接口
  7.3 ──→ 7.6 更新 Renderer 状态模块 ──→ 7.7 M7 验证

M8 首页与配置向导重构（依赖 M2 + M3 + M4 + M5 + M7）
  8.1 RuntimeWaitView 组件 ──→ 8.2 HomeView 重构
  8.2 ──→ 8.3 SetupView 扩展为 4 步向导 ──→ 8.4 SettingsView 更新
  8.4 ──→ 8.5 M8 验证

M9 web-admin 构建集成与打包更新（依赖 M8）【v2.5 更新：新增 runtime tar.gz 资源】
  9.1 web-admin 构建脚本 ──→ 9.2 electron-builder.json 更新
  9.2 ──→ 9.3 NSIS 安装脚本更新 ──→ 9.4 安装包体积优化
  9.4 ──→ 9.5 M9 验证

M10 集成测试与体验打磨（依赖 M9）【v2.5 更新：新增解压集成测试和降级下载测试】
  10.1 端到端流程测试 ──→ 10.2 性能指标验证 ──→ 10.3 异常场景完善
  10.3 ──→ 10.4 用户体验打磨 ──→ 10.5 M10 验证

M11 跨平台支持（可选，依赖 M10）
  11.1 macOS 适配 ──→ 11.2 Linux 适配 ──→ 11.3 跨平台验证
```

**可并行执行的任务组**：
- M2（UI 重构）∥ M3（PostgreSQL 集成）∥ M4（web-admin 集成）∥ M5（登录态共享）∥ M6（运行时依赖管理）∥ M7（SDK 集成）— 六者依赖 M1 但互不依赖，可并行开发
- M2 中：2.2 AppSidebar ∥ 2.4 图标系统（均依赖 2.1，可并行）
- M3 中：3.2 PgsqlView ∥ 3.6 PG 资源打包（均依赖 3.1，可并行）
- M4 中：4.1 WebAdminServer ∥ 4.2 EnvSyncManager（均依赖 M1，可并行）
- M5 中：5.2 postMessage 协议 ∥ 5.4 IPC 通道注册（均依赖 5.1，可并行）
- M6 中：6.2 OpenSSL 检测 ∥ 6.4 依赖检查（均依赖 6.1，可并行）
- M7 中：7.0 RuntimeIntegrator ∥ 7.4 健康检查更新（7.0 独立于 7.4，可并行）；7.4 健康检查更新 ∥ 7.5 AI Key 测试接口（均依赖 7.2，可并行）【v2.5 更新】
- M10 中：10.1 端到端测试 ∥ 10.2 性能验证（可并行执行）

---

## 1. M1 架构清理与模块增强 — 保留并增强 PostgreSQL/移除 SSL 管理/新增 webadmin 配置

> **目标**：移除 PC 客户端中 SSL 独立配置管理，保留并增强 PostgreSQL 配置结构为完整嵌套体（PgsqlConfig），新增 webadmin 配置组（WebAdminConfig），扩展 AppConfig 支持 UI/Update/AI 多提供商，为后续 PostgreSQL 集成（M3）、web-admin 集成（M4）、SDK 集成（M7）和 UI 重构（M2）扫清障碍
> **工期**：1 周 | **需求覆盖**：spec 5.3（禁止项）、5.4（PostgreSQL 集成）、5.6（web-admin HTTP 服务器）、5.12（双 .env 配置同步）、design 2.8.1/2.8.3
> **变更性质**：增强为主（pgsql/webadmin 配置扩展），移除为辅（ssl 配置移除）
> **v2.2 变更**：①不再移除 pgsql.ts、PgsqlView.vue、pgsql Store、/pgsql 路由，改为保留并增强；②新增 webadmin 配置组和 envsync 类型定义

### 1.1 移除 SSL IPC 通道

- [ ] TASK-M1-01：从 `electron/preload/index.ts` 中移除 `ssl` 命名空间（`ssl:getConfig`、`ssl:setConfig`、`ssl:validateCert`）
- [ ] TASK-M1-02：从 `electron/main/index.ts` 中移除 SSL 相关 IPC 注册（`registerSetupIPC` 中的 ssl 相关注册）
- [ ] TASK-M1-03：从 `src/electron/ipc.ts` 中移除 `ssl` 相关调用方法

**优先级**：P0 | **依赖**：无 | **预估工时**：0.5 天 | **验收标准**：preload 和 main 中无 ssl IPC 通道，渲染进程无法调用 ssl 接口

### 1.2 增强 ConfigStore 配置结构

- [ ] TASK-M1-04：从 `electron/modules/config.ts` 的 AppConfig 类型中移除 `ssl` 字段（包含 enabled/certFile/keyFile 等子字段）和 `setSSL()` 方法
- [ ] TASK-M1-05：扩展 `electron/modules/config.ts` 的 AppConfig.pgsql 为 PgsqlConfig 嵌套结构：`mode: "embedded" | "external" = "embedded"`、`embedded: EmbeddedPgsqlConfig`（port/dataDir/passwordEncrypted/autoStart/autoBackup/backupDir）、`external: ExternalPgsqlConfig`（host/port/user/passwordEncrypted/database）
- [ ] TASK-M1-06：在 ConfigStore 中新增 `setPgsqlMode(mode)` 方法，支持在内置/外部 PostgreSQL 之间切换
- [ ] TASK-M1-07：在 ConfigStore 中新增 `setExternalPgsql(config)` 方法，保存外部 PostgreSQL 连接配置
- [ ] TASK-M1-08：在 `electron/modules/config.ts` 的 AppConfig 类型中新增 `ui` 配置组：`navWidth: number = 220`、`navCollapsed: boolean = false`
- [ ] TASK-M1-09：在 `electron/modules/config.ts` 的 AppConfig 类型中新增 `update` 配置组：`autoCheck: boolean = true`、`channel: "stable" | "beta" = "stable"`
- [ ] TASK-M1-10：在 `electron/modules/config.ts` 的 AIConfig 类型中新增 `providers: AIProviderMap` 多提供商支持（openai/anthropic/zhipu/qwen/deepseek/ollama），每个提供商包含 `apiKey`、`baseUrl`、`model` 字段
- [ ] TASK-M1-11：在 `electron/modules/config.ts` 的 AppConfig 类型中新增 `webadmin` 配置组为 WebAdminConfig 嵌套结构：`port: number = 3031`、`autoStart: boolean = true`；新增 `setWebAdmin(config)` 和 `getWebAdmin()` 方法【v2.2 新增】
- [ ] TASK-M1-11a：在 `electron/modules/config.ts` 的 RuntimeConfig 类型中新增 `integratedVersion: string = ""`（已集成 runtime 版本号）和 `integratedSource: "archive" | "network" | "sdk" | "" = ""`（集成来源：压缩包解压/网络下载/SDK）字段【v2.5 新增】
- [ ] TASK-M1-12：更新 `resources/defaults/default-config.json`，移除 ssl 配置，扩展 pgsql 为完整嵌套结构（含 mode/embedded/external），新增 ui/update/webadmin 配置和 ai.providers 结构，新增 runtime.integratedVersion 和 runtime.integratedSource 字段【v2.5 更新】

**优先级**：P0 | **依赖**：1.1 | **预估工时**：1.5 天 | **验收标准**：AppConfig 不含 ssl 字段，pgsql 为完整 PgsqlConfig 嵌套结构（含 mode/embedded/external），含 ui/update/webadmin/ai.providers 字段，RuntimeConfig 含 integratedVersion/integratedSource 字段，默认配置文件同步更新

### 1.3 增强 IPC 通信层

- [ ] TASK-M1-13：保留 `electron/preload/index.ts` 中的 `pgsql` 命名空间，新增 `pgsql.updateEnvUrl` 方法暴露
- [ ] TASK-M1-14：从 `src/electron/types.ts` 中移除 ssl 相关类型定义（`SSLConfig`、`SSLValidateResult` 等）
- [ ] TASK-M1-15：在 `src/electron/types.ts` 中扩展 `PgsqlStatusResult` 类型：新增 `mode: "embedded" | "external"`、`connections?: number`、`dbSize?: string` 字段
- [ ] TASK-M1-16：在 `src/electron/types.ts` 中新增 `PgsqlConfig`、`EmbeddedPgsqlConfig`、`ExternalPgsqlConfig`、`UIConfig`、`UpdateConfig`、`AIProviderEntry`、`AIProviderMap` 类型定义
- [ ] TASK-M1-17：在 `src/electron/types.ts` 中新增 `WebAdminConfig`、`WebAdminInfo`、`WebAdminState`、`WebAdminStartResult`、`WebAdminStatusResult`、`EnvSyncResult`、`EnvSyncStatus` 类型定义【v2.2 新增】
- [ ] TASK-M1-17a：在 `src/electron/types.ts` 中新增 `RuntimeIntegrateResult`、`RuntimeIntegrateStatus`、`RuntimeIntegrateProgress` 类型定义【v2.5 新增】
- [ ] TASK-M1-18：在 `src/electron/ipc.ts` 中新增 `pgsql.updateEnvUrl` 调用封装，移除 `ssl` 相关调用方法
- [ ] TASK-M1-19：在 `src/electron/ipc.ts` 中新增 `webadmin` 相关调用封装（start/stop/status）和 `envsync` 相关调用封装（getRuntimeEnv/setRuntimeEnv/syncWebAdminEnv/getSyncStatus）【v2.2 新增】
- [ ] TASK-M1-19a：在 `src/electron/ipc.ts` 中新增 `runtime.integrate` 和 `runtime.integrateStatus` 调用封装【v2.5 新增】
- [ ] TASK-M1-20：在 `electron/utils/port.ts` 中新增 `allocateWebAdminPort(defaultPort: number)` 方法，端口范围 3031-3041【v2.2 新增】

**优先级**：P0 | **依赖**：1.2 | **预估工时**：1.5 天 | **验收标准**：IPC 层保留 pgsql 通道并新增 updateEnvUrl，无 ssl 通道，types.ts 新增 PgsqlConfig/UIConfig/UpdateConfig/AIProvider/WebAdmin*/EnvSync*/RuntimeIntegrate* 类型，ipc.ts 新增 webadmin/envsync/runtime.integrate/runtime.integrateStatus 调用封装，port.ts 新增 allocateWebAdminPort

### 1.4 增强配置向导服务

- [ ] TASK-M1-21：保留 `electron/modules/setup.ts` 中的 `executeDatabaseStep` 方法，重写为支持内置/外部 PostgreSQL 模式：内置模式触发 `PgManager.initialize()`；外部模式调用 `PgManager.testConnection()` 验证连接
- [ ] TASK-M1-22：从 `electron/modules/setup.ts` 中移除 `executeSSLStep` 方法
- [ ] TASK-M1-23：从 `electron/modules/setup.ts` 中移除 `executeNetworkStep` 方法
- [ ] TASK-M1-24：更新 `electron/modules/setup.ts` 的 `completeSetup` 方法：保存 AI 配置 → 保存数据库配置 → 生成 .env（含 orm_connectionUrl + BACKEND_URL）→ **同步 web-admin .env（调用 envSyncManager.syncWebAdminEnv()）**→ 标记 setupCompleted【v2.2 增强：新增同步 web-admin .env 步骤】

**优先级**：P0 | **依赖**：1.2 | **预估工时**：1 天 | **验收标准**：setup.ts 保留数据库配置步骤（支持内置/外部模式），移除 SSL/网络配置步骤，completeSetup 包含数据库配置保存、orm_connectionUrl 生成和 web-admin .env 同步

### 1.5 增强 .env 生成器

- [ ] TASK-M1-25：从 `electron/modules/env-generator.ts` 中移除 SSL 配置生成逻辑（certFile/keyFile 相关环境变量写入）
- [ ] TASK-M1-26：增强 `electron/modules/env-generator.ts` 中的 orm_connectionUrl 生成逻辑：根据 `pgsql.mode`（embedded/external）自动选择连接串格式，内置模式生成 `postgresql://uctoo:<password>@127.0.0.1:<port>/uctoo`，外部模式生成 `postgresql://<user>:<password>@<host>:<port>/<database>`
- [ ] TASK-M1-27：增强 `electron/modules/env-generator.ts` 的 AI 多提供商 .env 生成能力，支持将 AIConfig.providers 中各提供商的 apiKey/baseUrl/model 写入 .env
- [ ] TASK-M1-28：增强 `electron/modules/env-generator.ts` 新增 BACKEND_URL 配置项生成：根据 runtime.host 和 runtime.port 生成 `BACKEND_URL=http://localhost:{port}`【v2.2 新增】

**优先级**：P1 | **依赖**：1.4 | **预估工时**：0.5 天 | **验收标准**：env-generator 不生成 SSL 配置，支持内置/外部 PostgreSQL 连接串生成，支持多提供商 AI 配置写入 .env，支持 BACKEND_URL 生成

### 1.6 更新主进程入口

- [ ] TASK-M1-29：保留 `electron/main/index.ts` 中的 `registerPgsqlIPC` 函数调用和 `setupPgsqlStateBridge` 函数调用
- [ ] TASK-M1-30：新增 `pgsql:updateEnvUrl` IPC 通道注册到 `registerPgsqlIPC` 函数中
- [ ] TASK-M1-31：保留 `electron/main/index.ts` 的 `before-quit` 事件中的 `pgManager.stop()` 调用
- [ ] TASK-M1-32：从 `electron/main/index.ts` 中移除 SSL 相关 IPC 注册代码
- [ ] TASK-M1-33：清理 `electron/modules/index.ts` 中 ssl 模块的导出（如有）

**优先级**：P0 | **依赖**：1.3, 1.4 | **预估工时**：0.5 天 | **验收标准**：主进程入口保留 pgsql 引用和 IPC 注册，新增 pgsql:updateEnvUrl 通道，无 ssl 引用，应用退出时停止 pgsql 进程

### 1.7 清理渲染进程残留

- [ ] TASK-M1-34：从 `src/views/setup/SetupView.vue` 中移除 `executeSSLStep` 调用
- [ ] TASK-M1-35：从 `src/views/settings/SettingsView.vue` 中移除 SSL 配置组 UI（证书文件路径、启用开关等 UI 元素）
- [ ] TASK-M1-36：保留 `src/views/pgsql/PgsqlView.vue` 和 `src/store/modules/pgsql.ts`，不做删除（M3 中增强）

**优先级**：P1 | **依赖**：1.3, 1.4 | **预估工时**：0.5 天 | **验收标准**：SetupView 不含 SSL 步骤调用，SettingsView 不含 SSL 配置 UI，PgsqlView 和 pgsql Store 保留

### 1.8 更新托盘菜单

- [ ] TASK-M1-37：保留 `electron/modules/tray.ts` 的右键菜单中 PostgreSQL 相关菜单项（数据库状态、启动/停止数据库等）
- [ ] TASK-M1-38：从 `electron/modules/tray.ts` 的右键菜单中移除 SSL 相关菜单项（如有）
- [ ] TASK-M1-39：更新 `electron/modules/tray.ts` 中的 `updateContextMenu` 方法，确保菜单项与 v2.2 功能对齐（保留 PG 状态指示和操作菜单，预留 web-admin HTTP 服务器状态指示位置）

**优先级**：P1 | **依赖**：1.6 | **预估工时**：0.5 天 | **验收标准**：托盘右键菜单保留 PostgreSQL 相关项，无 SSL 相关项，菜单功能与 v2.2 架构一致

### 1.9 M1 架构清理验证

- [ ] TASK-M1-40：验证 `pnpm dev` 启动无报错，无 ssl 相关编译错误
- [ ] TASK-M1-41：验证 IPC 通道列表包含 v2.2 定义的通道（runtime/config/system/updater/autoLaunch/setup/pgsql），不含 ssl 通道
- [ ] TASK-M1-42：验证配置文件读写正常（不含 ssl 字段，pgsql 为完整嵌套结构，含 ui/update/webadmin/ai.providers 字段）
- [ ] TASK-M1-43：验证应用退出流程正常（保留 pgsql 进程停止逻辑）
- [ ] TASK-M1-44：全局搜索确认无残留的 ssl 引用（除日志和注释外）
- [ ] TASK-M1-45：验证 pgsql IPC 通道（init/start/stop/status/backup/restore/testConnection/updateEnvUrl）可正常调用
- [ ] TASK-M1-46：验证 WebAdminConfig 类型定义正确，default-config.json 包含 webadmin 配置组【v2.2 新增】
- [ ] TASK-M1-47：验证 EnvSyncResult/EnvSyncStatus 类型定义正确，ipc.ts 包含 envsync 调用封装【v2.2 新增】
- [ ] TASK-M1-48：验证 allocateWebAdminPort(3031) 可正确分配端口【v2.2 新增】
- [ ] TASK-M1-49：验证 RuntimeIntegrateResult/RuntimeIntegrateStatus/RuntimeIntegrateProgress 类型定义正确，ipc.ts 包含 runtime.integrate/runtime.integrateStatus 调用封装【v2.5 新增】
- [ ] TASK-M1-50：验证 RuntimeConfig 中 integratedVersion/integratedSource 字段正确，default-config.json 包含 runtime.integratedVersion 和 runtime.integratedSource 默认值【v2.5 新增】

**优先级**：P0 | **依赖**：1.8 | **预估工时**：0.5 天 | **验收标准**：应用正常启动和退出，无 ssl 残留功能，pgsql IPC 通道与 v2.2 设计一致，pgsql 配置为完整嵌套结构，webadmin/envsync 类型和 IPC 封装就绪

---

## 2. M2 UI 重构 — 左侧竖向导航布局

> **目标**：将应用布局从顶部水平导航重构为左侧竖向导航，实现四区域导航栏、导航图标系统、CSS 变量架构，新增技能管理和智能体管理路由，保留数据库管理路由
> **工期**：2 周 | **需求覆盖**：spec 5.7（左侧竖向导航）、5.8（导航图标）、design 2.5/2.6
> **变更性质**：新增为主（CSS 架构、AppSidebar、NavItem、图标系统），重构为辅（App.vue、路由）
> **v2.2 变更**：保留 /pgsql 路由，导航项增加"数据库管理"

### 2.1 搭建 CSS 架构

- [ ] TASK-M2-01：创建 `src/styles/variables.css`，定义全部 CSS 变量：导航栏变量（--nav-width、--nav-collapsed-width、--nav-bg-color、--nav-text-color、--nav-hover-bg、--nav-active-bg、--nav-active-text、--nav-separator-color、--nav-logo-height、--nav-item-height、--nav-item-gap、--nav-item-padding、--nav-icon-size、--nav-border-radius）、主内容区变量（--content-bg-color、--content-padding、--content-text-color）、品牌色（--brand-primary、--brand-primary-light、--brand-primary-dark）、状态色（--color-success/warning/error/info）、间距变量、字体变量、窗口约束变量（--window-min-width、--window-min-height）
- [ ] TASK-M2-02：创建 `src/styles/layout.css`，定义 `.app-layout`（flex-row、100vh、overflow:hidden）、`.main-content`（flex:1、padding、overflow-y:auto）、`.main-content.no-padding`（padding:0、position:relative）
- [ ] TASK-M2-03：创建 `src/styles/sidebar.css`，定义 `.app-sidebar`（width、height、background、flex-column、user-select:none、flex-shrink:0、transition）、`.app-sidebar.collapsed`（width 缩小为 64px）、`.sidebar-logo`（height:48px、app-region:drag）、`.sidebar-nav-items`（app-region:no-drag、flex-column、gap）、`.sidebar-separator`（1px 分隔线）
- [ ] TASK-M2-04：在 `src/main.ts` 中导入 CSS 文件（variables.css → layout.css → sidebar.css）

**优先级**：P0 | **依赖**：M1 完成 | **预估工时**：1 天 | **验收标准**：CSS 变量在浏览器 DevTools 中可查看，布局类名可正常应用，导航栏样式变量完整定义

### 2.2 实现 AppSidebar 组件

- [ ] TASK-M2-05：创建 `src/components/AppSidebar.vue`，实现四区域导航布局：顶部 Logo 区（应用 Logo + 应用名称"AgentSkills"）、核心功能区（首页/技能/智能体）、系统管理区（Runtime 监控/数据库管理）、底部区（设置/关于）
- [ ] TASK-M2-06：在 AppSidebar 中定义导航配置数据结构 `NavItemConfig[]`（path、label、icon、group），包含 7 个导航项：首页(`/`)、技能(`/skills`)、智能体(`/agents`)、Runtime(`/runtime`)、数据库(`/pgsql`)、设置(`/settings`)、关于(`/about`)
- [ ] TASK-M2-07：实现区域分隔线渲染：核心功能区与系统管理区之间、系统管理区与底部区之间各一条水平分隔线
- [ ] TASK-M2-08：实现拖拽区域设置：Logo 区 `-webkit-app-region: drag`，导航项区域 `-webkit-app-region: no-drag`
- [ ] TASK-M2-09：实现折叠模式：监听窗口宽度，当宽度 < 800px 时自动切换为图标模式（仅显示图标，隐藏文字），导航栏宽度从 220px 缩小为 64px，折叠状态下悬停显示 tooltip
- [ ] TASK-M2-10：通过 `useRoute()` 获取当前路由路径，传递给 NavItem 组件实现选中状态

**优先级**：P0 | **依赖**：2.1 | **预估工时**：2 天 | **验收标准**：AppSidebar 渲染四区域导航（含数据库管理项），Logo 区可拖拽窗口，导航项区域不可拖拽，窗口过窄时自动折叠

### 2.3 实现 NavItem 组件

- [ ] TASK-M2-11：创建 `src/components/NavItem.vue`，实现单个导航项：图标 + 文字，竖向排列
- [ ] TASK-M2-12：实现 NavItem Props 接口：`path: string`、`label: string`、`icon: string`、`collapsed?: boolean`
- [ ] TASK-M2-13：实现导航项状态样式：默认（图标 #cdd6f4、文字 #cdd6f4、背景透明）、悬停（背景 #313244）、选中（背景 #45475a、图标和文字 #89b4fa、左侧 3px 品牌色竖条）
- [ ] TASK-M2-14：实现点击事件：通过 `router.push(path)` 跳转路由
- [ ] TASK-M2-15：实现折叠模式显示：collapsed=true 时仅显示图标，悬停显示 tooltip（文字标签）

**优先级**：P0 | **依赖**：2.1, 2.4 | **预估工时**：1.5 天 | **验收标准**：导航项正确显示图标和文字，选中/悬停状态样式正确，点击可跳转路由，折叠模式正常

### 2.4 集成导航图标系统

- [ ] TASK-M2-16：安装 `lucide-vue-next` 图标库（`pnpm add lucide-vue-next`）
- [ ] TASK-M2-17：在 NavItem 组件中集成 Lucide Icons，通过 `icon` prop 动态渲染图标组件
- [ ] TASK-M2-18：定义导航项图标映射：首页→`home`、技能→`zap`、智能体→`bot`、Runtime→`activity`、数据库→`database`、设置→`settings`、关于→`info`
- [ ] TASK-M2-19：实现图标状态样式：默认中性色（#cdd6f4），选中品牌色（#89b4fa），图标尺寸 20px
- [ ] TASK-M2-20：实现图标加载失败降级方案：图标加载失败时显示文字降级（无图标仅文字），不影响导航功能

**优先级**：P0 | **依赖**：2.1 | **预估工时**：1 天 | **验收标准**：所有导航项显示 Lucide 图标（含数据库图标），图标风格统一（线性简洁），选中/默认状态颜色正确，图标加载失败有降级方案

### 2.5 重构 App.vue 布局

- [ ] TASK-M2-21：将 `src/App.vue` 布局从 `flex-column`（顶部导航 + 底部状态栏）重构为 `flex-row`（左侧导航 + 右侧内容）
- [ ] TASK-M2-22：在 App.vue 中引入 AppSidebar 组件，放置在左侧
- [ ] TASK-M2-23：移除 App.vue 中的顶部 `nav-bar` 和底部 `status-bar` 元素
- [ ] TASK-M2-24：移除 App.vue 中的首页隐藏逻辑（`v-if="!isHomePage"` 条件渲染导航和状态栏）
- [ ] TASK-M2-25：实现主内容区 padding 策略：首页路由下添加 `no-padding` class（iframe 全屏），其他路由保留 `--content-padding` 间距
- [ ] TASK-M2-26：移除 App.vue 中 `-webkit-app-region: drag` 在整个 nav-bar 上的设置（已由 AppSidebar Logo 区处理）
- [ ] TASK-M2-27：设置窗口最小尺寸约束：`min-width: 800px`、`min-height: 600px`

**优先级**：P0 | **依赖**：2.2, 2.3 | **预估工时**：1.5 天 | **验收标准**：App.vue 为左侧导航 + 右侧内容布局，导航栏在所有路由下常驻显示，首页主内容区无 padding，其他页面有 padding

### 2.6 扩展路由系统

- [ ] TASK-M2-28：在 `src/router/index.ts` 中新增 `/skills` 路由（懒加载 `src/views/skills/SkillsView.vue`）
- [ ] TASK-M2-29：在 `src/router/index.ts` 中新增 `/agents` 路由（懒加载 `src/views/agents/AgentsView.vue`）
- [ ] TASK-M2-30：保留 `src/router/index.ts` 中的 `/pgsql` 路由定义（v2.1 恢复数据库管理视图）
- [ ] TASK-M2-31：验证路由守卫（beforeEach 检测 setupCompleted）对新路由和 /pgsql 路由生效

**优先级**：P1 | **依赖**：2.5 | **预估工时**：0.5 天 | **验收标准**：`/skills` 和 `/agents` 路由可访问，`/pgsql` 路由保留，路由守卫正常工作

### 2.7 新增技能管理和智能体管理视图

- [ ] TASK-M2-32：创建 `src/views/skills/SkillsView.vue`，实现技能管理页面占位（可作为 iframe 内跳转快捷入口或通过 runtime API 展示技能列表）
- [ ] TASK-M2-33：创建 `src/views/agents/AgentsView.vue`，实现智能体管理页面占位（同 SkillsView，作为 iframe 内跳转快捷入口或独立视图）
- [ ] TASK-M2-34：在 SkillsView 和 AgentsView 中预留通过 `createClient` SDK 或 runtime API 获取数据的接口

**优先级**：P2 | **依赖**：2.6 | **预估工时**：1 天 | **验收标准**：`/skills` 和 `/agents` 路由可正常渲染页面，页面结构与导航栏对齐

### 2.8 M2 UI 重构验证

- [ ] TASK-M2-35：验证左侧导航栏在所有路由下常驻显示（包括首页 `/` 和数据库管理 `/pgsql`）
- [ ] TASK-M2-36：验证导航项点击可正确跳转路由，选中状态高亮正确（含数据库管理导航项）
- [ ] TASK-M2-37：验证导航图标统一风格，选中/悬停状态视觉反馈正确
- [ ] TASK-M2-38：验证窗口宽度 < 800px 时导航栏自动折叠为图标模式
- [ ] TASK-M2-39：验证首页主内容区无 padding，其他页面有 padding
- [ ] TASK-M2-40：验证窗口拖拽仅在 Logo 区域生效，导航项区域不触发拖拽
- [ ] TASK-M2-41：验证窗口最小尺寸约束生效

**优先级**：P0 | **依赖**：2.7 | **预估工时**：0.5 天 | **验收标准**：左侧导航布局完整可用，所有交互状态正确，窗口约束生效，数据库管理导航项正常

---

## 3. M3 PostgreSQL 集成管理 — 内置 PostgreSQL 初始化/启停/备份恢复/连接配置

> **目标**：增强 PgManager 模块支持 v2.2 规范要求（uctoo 用户/scram-sha-256 认证/pg_dump -Fc 格式/orm_connectionUrl 自动更新），增强 PgsqlView.vue（状态监控/备份列表/自动备份），完善 IPC 通道和 Preload 暴露，配置 PostgreSQL 二进制资源打包和数据库初始化脚本
> **工期**：2 周 | **需求覆盖**：spec 5.4（PostgreSQL 集成管理 REQ-PGDB-01~07）、design 1.2.2/2.2.1/2.5.6
> **变更性质**：增强为主（PgManager/PgsqlView/IPC/Store），新增为辅（updateEnvUrl/资源打包/初始化脚本）
> **v2.2 变更**：恢复并增强 PostgreSQL 集成管理里程碑

### 3.1 PgManager 模块重构/增强

- [ ] TASK-M3-01：重构 `electron/modules/pgsql.ts` 的 `initialize()` 方法：initdb 参数改为 `-U uctoo --auth-host=scram-sha-256 --auth-local=scram-sha-256 --encoding=UTF8 --locale=C`；修改 createdb/psql 命令用户为 `uctoo`；新增 uctoo 用户密码自动生成（`CryptoUtils.generateRandomPassword(16)`）并调用 `configStore.setPgsqlPassword()` 加密存储
- [ ] TASK-M3-02：重构 `electron/modules/pgsql.ts` 的 `backup()` 方法：使用 `pg_dump -Fc` 替代 `pg_dump -f` 纯 SQL 文本格式，输出 `.backup` 文件（命名规则 `uctoo_YYYYMMDD_HHmmss.backup`），存储到默认备份目录 `%APPDATA%/agentskills/backups/`
- [ ] TASK-M3-03：重构 `electron/modules/pgsql.ts` 的 `restore()` 方法：使用 `pg_restore` 替代 `psql -f`，从 `.backup` 自定义格式归档文件恢复 uctoo 数据库
- [ ] TASK-M3-04：增强 `electron/modules/pgsql.ts` 的 `startInternal()` 方法：端口变更后同步更新 `configStore.setPgsqlPort()` 和调用 `envGenerator.generateForRuntime()` 更新 orm_connectionUrl
- [ ] TASK-M3-05：新增 `electron/modules/pgsql.ts` 的 `updateEnvUrl()` 方法：根据 `configStore.pgsql.mode`（embedded/external）构建 orm_connectionUrl，调用 `envGenerator.generateForRuntime()` 更新 runtime .env 文件
- [ ] TASK-M3-06：增强 `electron/modules/pgsql.ts` 的 `testConnection()` 方法：返回结果新增 `databaseExists: boolean` 字段，检测 uctoo 数据库是否存在
- [ ] TASK-M3-07：增强 `electron/modules/pgsql.ts` 的 `getInfo()` 方法：返回 PgsqlInfo 新增 `connections: number`（当前连接数）、`dbSize: string`（uctoo 数据库大小）、`mode: "embedded" | "external"` 字段
- [ ] TASK-M3-08：增强 `electron/modules/pgsql.ts` 的 PostgreSQL 二进制路径管理：通过 `Paths.getPgsqlBinPath()` 获取安装目录 `resources/pgsql/bin/` 下的可执行文件路径，Windows 平台添加 `.exe` 后缀

**优先级**：P0 | **依赖**：M1 完成 | **预估工时**：3 天 | **验收标准**：PgManager.initialize() 使用 uctoo 用户和 scram-sha-256 认证；backup() 使用 pg_dump -Fc 格式；restore() 使用 pg_restore；updateEnvUrl() 可自动更新 .env 中 orm_connectionUrl；testConnection() 返回 databaseExists；getInfo() 返回连接数和数据库大小

### 3.2 PgsqlView.vue 增强

- [ ] TASK-M3-09：增强 `src/views/pgsql/PgsqlView.vue` 的状态 Tab：新增 PostgreSQL 版本显示、uctoo 数据库大小显示、当前连接数显示、数据库模式指示（内置/外部）
- [ ] TASK-M3-10：增强 `src/views/pgsql/PgsqlView.vue` 的备份恢复 Tab：备份格式改为 pg_dump -Fc 自定义格式（`.backup` 文件）；新增备份列表显示（从备份目录 `%APPDATA%/agentskills/backups/` 读取）；新增自动备份开关（调用 configStore 设置 pgsql.embedded.autoBackup）；新增删除备份功能；恢复时自动停止 runtime → 恢复数据库 → 重启 runtime
- [ ] TASK-M3-11：增强 `src/views/pgsql/PgsqlView.vue` 的连接测试 Tab：新增 uctoo 数据库存在性检测结果展示；外部 PostgreSQL 连接测试失败时显示具体失败原因（连接超时/认证失败/数据库不存在）
- [ ] TASK-M3-12：在 PgsqlView 中新增数据库模式切换功能：支持在内置 PostgreSQL 和外部 PostgreSQL 之间切换，切换时需重新配置连接信息并测试连接，测试通过后调用 `pgsql:updateEnvUrl` 更新 .env

**优先级**：P0 | **依赖**：3.1 | **预估工时**：2.5 天 | **验收标准**：状态 Tab 显示版本/数据库大小/连接数/模式；备份恢复 Tab 使用 -Fc 格式、显示备份列表、支持自动备份开关；连接测试 Tab 显示数据库存在性；支持数据库模式切换

### 3.3 pgsql Store 更新

- [ ] TASK-M3-13：增强 `src/store/modules/pgsql.ts` 的 PgsqlInfo 类型：新增 `connections: number`、`dbSize: string`、`mode: "embedded" | "external"` 字段
- [ ] TASK-M3-14：在 `src/store/modules/pgsql.ts` 中新增 `restore` action，通过 IPC 调用 `pgsql:restore`
- [ ] TASK-M3-15：在 `src/store/modules/pgsql.ts` 中新增 `updateEnvUrl` action，通过 IPC 调用 `pgsql:updateEnvUrl`
- [ ] TASK-M3-16：在 `src/store/modules/pgsql.ts` 中新增 `switchMode` action，切换数据库模式后调用 `updateEnvUrl`
- [ ] TASK-M3-17：更新 `src/store/modules/pgsql.ts` 的 `fetchStatus` action，适配 PgsqlStatusResult 新增的 mode/connections/dbSize 字段

**优先级**：P1 | **依赖**：3.1 | **预估工时**：1 天 | **验收标准**：pgsql Store 支持 restore/updateEnvUrl/switchMode action，PgsqlInfo 包含 connections/dbSize/mode 字段

### 3.4 IPC 通道注册

- [ ] TASK-M3-18：在 `electron/main/index.ts` 的 `registerPgsqlIPC` 函数中注册 `pgsql:updateEnvUrl` IPC 通道，签名：`pgsql:updateEnvUrl() → IPCResult<string>`，核心逻辑：根据 configStore.pgsql.mode 构建 orm_connectionUrl，调用 envGenerator.generateForRuntime() 更新 .env
- [ ] TASK-M3-19：验证 `electron/main/index.ts` 中已有的 pgsql IPC 通道注册完整：`pgsql:init`、`pgsql:start`、`pgsql:stop`、`pgsql:status`、`pgsql:backup`、`pgsql:restore`、`pgsql:testConnection`
- [ ] TASK-M3-20：验证 `electron/main/index.ts` 中 `setupPgsqlStateBridge` 函数正常推送 `pgsql:stateChanged` 事件到渲染进程

**优先级**：P0 | **依赖**：3.1 | **预估工时**：0.5 天 | **验收标准**：pgsql IPC 通道完整注册（含 updateEnvUrl），pgsql:stateChanged 事件正常推送

### 3.5 Preload 暴露 pgsql 命名空间

- [ ] TASK-M3-21：验证 `electron/preload/index.ts` 中 pgsql 命名空间完整暴露：`pgsql.init`、`pgsql.start`、`pgsql.stop`、`pgsql.status`、`pgsql.backup`、`pgsql.restore`、`pgsql.testConnection`、`pgsql.updateEnvUrl`
- [ ] TASK-M3-22：在 `electron/preload/index.ts` 中新增 `pgsql.updateEnvUrl` 方法暴露到渲染进程（若 M1 未完成）

**优先级**：P0 | **依赖**：3.4 | **预估工时**：0.5 天 | **验收标准**：渲染进程可通过 window.electronAPI.pgsql.* 调用所有 pgsql IPC 方法（含 updateEnvUrl）

### 3.6 PostgreSQL 二进制资源打包

- [ ] TASK-M3-23：在 `electron-builder.json` 的 `extraResources` 中配置 PostgreSQL 二进制分发包：`{ "from": "resources/pgsql/bin", "to": "pgsql/bin" }`、`{ "from": "resources/pgsql/lib", "to": "pgsql/lib" }`、`{ "from": "resources/pgsql/share", "to": "pgsql/share" }`
- [ ] TASK-M3-24：创建 `resources/pgsql/bin/` 目录占位，添加 `.gitkeep` 文件确保目录结构存在
- [ ] TASK-M3-25：创建 `resources/pgsql/lib/` 目录占位，添加 `.gitkeep` 文件
- [ ] TASK-M3-26：创建 `resources/pgsql/share/` 目录占位，添加 `.gitkeep` 文件
- [ ] TASK-M3-27：验证 PostgreSQL 二进制文件（initdb.exe/pg_ctl.exe/postgres.exe/createdb.exe/psql.exe/pg_dump.exe/pg_restore.exe/pg_isready.exe）放置到 `resources/pgsql/bin/` 后可正常执行

**优先级**：P0 | **依赖**：3.1 | **预估工时**：1 天 | **验收标准**：electron-builder.json 包含 pgsql/bin、pgsql/lib、pgsql/share extraResources 配置，目录结构正确，PG 二进制可执行

### 3.7 数据库初始化脚本

- [ ] TASK-M3-28：在 `resources/sql/` 目录下放置 `uctoov4InitData.sql` 文件（uctoo 数据库 Schema + 初始数据）
- [ ] TASK-M3-29：在 `electron-builder.json` 的 `extraResources` 中配置 SQL 初始化脚本：`{ "from": "resources/sql", "to": "sql" }`
- [ ] TASK-M3-30：验证 `electron/modules/pgsql.ts` 的 `initialize()` 方法中 psql 导入 SQL 路径正确指向安装目录下的 `sql/uctoov4InitData.sql`

**优先级**：P0 | **依赖**：3.1, 3.6 | **预估工时**：0.5 天 | **验收标准**：uctoov4InitData.sql 文件存在于 resources/sql/ 目录，electron-builder.json 包含 sql extraResources 配置，initialize() 可正确导入 SQL

### 3.8 M3 PostgreSQL 集成验证

- [ ] TASK-M3-31：验证 PgManager.initialize() 完整流程：initdb（uctoo 用户/scram-sha-256）→ 配置 postgresql.conf → 配置 pg_hba.conf → 启动 → 设置密码 → createdb uctoo → 导入 SQL → 停止
- [ ] TASK-M3-32：验证 PgManager.start()/stop() 正常工作，端口冲突时自动分配新端口并更新 config 和 .env
- [ ] TASK-M3-33：验证 PgManager.backup() 生成 .backup 格式备份文件，PgManager.restore() 从 .backup 文件恢复
- [ ] TASK-M3-34：验证 PgManager.testConnection() 测试外部 PostgreSQL 连接，返回 databaseExists 字段
- [ ] TASK-M3-35：验证 PgManager.updateEnvUrl() 根据 pgsql.mode 正确更新 runtime .env 中 orm_connectionUrl
- [ ] TASK-M3-36：验证 PgsqlView.vue 状态 Tab 显示版本/连接数/数据库大小/模式
- [ ] TASK-M3-37：验证 PgsqlView.vue 备份恢复 Tab 备份列表、自动备份开关、删除备份功能正常
- [ ] TASK-M3-38：验证数据库模式切换（内置↔外部）后 orm_connectionUrl 自动更新
- [ ] TASK-M3-39：验证 pgsql:stateChanged 事件正常推送到渲染进程

**优先级**：P0 | **依赖**：3.2~3.7 | **预估工时**：1.5 天 | **验收标准**：PostgreSQL 完整生命周期管理正常，备份恢复使用 -Fc 格式，orm_connectionUrl 自动更新，PgsqlView 增强功能正常

---

## 4. M4 web-admin 集成与 runtime 版本检测【v2.3 修正】

> **目标**：实现 RuntimeVersionDetector 模块（检测 runtime 版本，≥ 0.0.26 优先使用 runtime 静态文件服务），实现 WebAdminServer 模块（仅在 runtime < 0.0.26 时作为降级方案启动），实现 EnvSyncManager 模块（双 .env 配置同步），修正 HomeView aibuilder URL 根据 runtime 版本选择不同策略，嵌入 web-admin 构建产物
> **工期**：2 周 | **需求覆盖**：spec 5.6（首页 aibuilder 加载 — runtime 版本检测与服务降级）、5.12（双 .env 配置同步 REQ-ENVSYNC-01~06）、design 1.1.3/2.1.3.5/2.1.3.6/2.2.2
> **变更性质**：新增为主（RuntimeVersionDetector、WebAdminServer 条件启动、EnvSyncManager），修正为辅（aibuilder URL 版本策略）
> **v2.3 变更**：新增 RuntimeVersionDetector 模块，WebAdminServer 改为条件启动，aibuilder URL 根据 runtime 版本选择

### 4.0 RuntimeVersionDetector 模块实现【v2.3 新增】

- [ ] TASK-M4-00a：创建 `electron/modules/runtime-version-detector.ts`，实现 RuntimeVersionDetector 类，检测 runtime 版本号
- [ ] TASK-M4-00b：实现 `detectVersion(runtimeInfo): string` 方法：从 runtime 健康检查响应或 runtime 二进制信息中提取版本号（如 `0.0.26`）
- [ ] TASK-M4-00c：实现 `isStaticFileServiceSupported(version): boolean` 方法：版本 ≥ 0.0.26 返回 true（runtime 支持静态文件服务），< 0.0.26 返回 false
- [ ] TASK-M4-00d：实现 `getAibuilderUrl(runtimeVersion, runtimePort, webAdminPort): string` 方法：根据 runtime 版本返回正确的 aibuilder URL
  - runtime ≥ 0.0.26：`http://127.0.0.1:${runtimePort}/vue-pro/aibuilder`
  - runtime < 0.0.26：`http://localhost:${webAdminPort}/vue-pro/aibuilder`
- [ ] TASK-M4-00e：实现 `shouldStartWebAdminServer(runtimeVersion): boolean` 方法：runtime < 0.0.26 返回 true（需要启动内置 HTTP 服务器），≥ 0.0.26 返回 false
- [ ] TASK-M4-00f：在 `src/electron/types.ts` 中新增 `RuntimeVersionInfo` 类型定义（version: string、staticFileServiceSupported: boolean）

**优先级**：P0 | **依赖**：M1 完成 | **预估工时**：1 天 | **验收标准**：RuntimeVersionDetector 可正确检测 runtime 版本，isStaticFileServiceSupported(0.0.26) 返回 true，isStaticFileServiceSupported(0.0.25) 返回 false，getAibuilderUrl 根据版本返回正确 URL

### 4.1 WebAdminServer 模块实现（条件启动）【v2.3 修正：仅 runtime < 0.0.26 时启动】

- [ ] TASK-M4-01：创建 `electron/modules/webadmin-server.ts`，实现 WebAdminServer 类，使用 `serve-handler` 启动 HTTP 服务器托管 web-admin 构建产物
- [ ] TASK-M4-02：实现 WebAdminServer 的 `start()` 方法：读取 ConfigStore.webadmin.port（默认 3031），检查 web-admin 构建产物目录（`resources/web-admin/`）是否存在，调用 `PortManager.allocateWebAdminPort(3031)` 分配端口（范围 3031-3041），创建 HTTP 服务器，设置 public 目录为 `resources/web-admin/`，启用 Vue SPA history fallback（所有非文件请求返回 index.html），启动监听
- [ ] TASK-M4-03：实现 WebAdminServer 的 `stop()` 方法：关闭 HTTP 服务器，设置状态为 stopped，通知状态变更
- [ ] TASK-M4-04：实现 WebAdminServer 的 `getStatus()` 方法：返回 WebAdminStatusResult（running/port/url/error）
- [ ] TASK-M4-05：实现 WebAdminServer 的状态管理：`onStateChange(listener)` 订阅机制，状态变更时通过 `webadmin:stateChanged` 推送到渲染进程
- [ ] TASK-M4-06：实现 WebAdminServer 的端口冲突处理：默认端口 3031 被占用时自动分配可用端口（3031-3041），分配成功后更新 ConfigStore.webadmin.port
- [ ] TASK-M4-07：安装 `serve-handler` 依赖（`pnpm add serve-handler`），配置 TypeScript 类型声明（如需）
- [ ] TASK-M4-07a：修改主进程启动流程：仅在 `RuntimeVersionDetector.shouldStartWebAdminServer(version)` 返回 true 时启动 WebAdminServer；runtime ≥ 0.0.26 时跳过启动【v2.3 新增】

**优先级**：P0 | **依赖**：M1 完成 + 4.0 | **预估工时**：2 天 | **验收标准**：WebAdminServer 可启动 HTTP 服务器托管 web-admin 构建产物，端口冲突时自动分配，Vue SPA history fallback 正常，状态变更可推送到渲染进程；runtime ≥ 0.0.26 时不启动

### 4.2 EnvSyncManager 模块实现

- [ ] TASK-M4-08：创建 `electron/modules/env-sync.ts`，实现 EnvSyncManager 类，管理 runtime .env 和 web-admin .env 双配置文件的读写和同步
- [ ] TASK-M4-09：实现 `readRuntimeEnv(keys?)` 方法：读取 runtime .env 中指定配置项（不传 keys 则返回全部），runtime .env 路径从 SDK 安装目录获取
- [ ] TASK-M4-10：实现 `writeRuntimeEnv(keyValueMap)` 方法：写入 runtime .env 配置项并持久化
- [ ] TASK-M4-11：实现 `readWebAdminEnv(keys?)` 方法：读取 web-admin .env 中指定配置项，web-admin .env 路径为 `resources/web-admin/.env`
- [ ] TASK-M4-12：实现 `syncWebAdminEnv()` 方法：读取 runtime .env 中 BACKEND_URL，根据配置同步映射表生成 web-admin .env 配置项，调用 EnvGenerator.generateForWebAdmin() 写入 web-admin .env 文件
- [ ] TASK-M4-13：实现配置同步映射逻辑：BACKEND_URL → VITE_SERVER_HOST/VITE_BACKEND_URL/VITE_AGENT_ROOT/VITE_MOCK_HOST/VITE_MOCK_SERVER_HOST（直接同步）；BACKEND_URL + `/api/v1/uctoo/webmcp/mcp` → VITE_WS_URL/VITE_OPENAI_BASE_URL（拼接路径后同步）；VITE_CONTEXT = `/vue-pro/`（固定值）；VITE_OPENAI_API_KEY = `sk-dummy-key`（占位值）
- [ ] TASK-M4-14：实现 `getSyncStatus()` 方法：返回最近一次同步状态（lastSyncTime、lastResult）
- [ ] TASK-M4-15：处理 BACKEND_URL 不存在场景：使用默认值 `http://localhost:8080`

**优先级**：P0 | **依赖**：M1 完成 | **预估工时**：2 天 | **验收标准**：EnvSyncManager 可读写 runtime .env 和 web-admin .env，syncWebAdminEnv() 根据 BACKEND_URL 正确同步所有 web-admin 配置项，配置映射逻辑与 spec 5.12 REQ-ENVSYNC-04 一致

### 4.3 web-admin .env 模板与生成逻辑

- [ ] TASK-M4-16：增强 `electron/modules/env-generator.ts`，新增 `generateForWebAdmin(envConfig?)` 方法：根据传入的配置项生成 web-admin .env 文件内容，包含 VITE_CONTEXT/VITE_SERVER_HOST/VITE_BACKEND_URL/VITE_WS_URL/VITE_OPENAI_BASE_URL/VITE_OPENAI_API_KEY/VITE_AGENT_ROOT/VITE_MOCK_HOST/VITE_MOCK_SERVER_HOST
- [ ] TASK-M4-17：增强 `electron/modules/env-generator.ts`，新增 `generateAndSaveForWebAdmin(envConfig?)` 方法：生成 web-admin .env 并保存到 `resources/web-admin/.env`
- [ ] TASK-M4-18：创建 `resources/web-admin/.env.template` 模板文件，包含所有 web-admin .env 配置项的默认值
- [ ] TASK-M4-19：验证 EnvGenerator.generateForWebAdmin() 生成的 .env 内容与 web-admin 项目 `web-admin/web/.env` 格式兼容

**优先级**：P0 | **依赖**：4.2 | **预估工时**：1 天 | **验收标准**：EnvGenerator 支持 web-admin .env 生成，生成的配置项完整且格式正确，.env.template 模板文件存在

### 4.4 IPC 通道注册（webadmin:* + envsync:*）

- [ ] TASK-M4-20：在 `electron/main/index.ts` 中新增 `registerWebAdminIPC` 函数，注册以下 IPC 通道：`webadmin:start`（启动 web-admin HTTP 服务器）、`webadmin:stop`（停止 web-admin HTTP 服务器）、`webadmin:status`（查询 web-admin HTTP 服务器状态）
- [ ] TASK-M4-21：在 `electron/main/index.ts` 中新增 `registerEnvSyncIPC` 函数，注册以下 IPC 通道：`envsync:getRuntimeEnv`（获取 runtime .env 配置项）、`envsync:setRuntimeEnv`（设置 runtime .env 配置项）、`envsync:syncWebAdminEnv`（同步 runtime .env 到 web-admin .env）、`envsync:getSyncStatus`（获取最近一次同步状态）
- [ ] TASK-M4-22：在 `electron/main/index.ts` 中新增 `setupWebAdminStateBridge` 函数，实现 `webadmin:stateChanged` 事件推送到渲染进程
- [ ] TASK-M4-23：在 `electron/main/index.ts` 的应用初始化流程中调用 `registerWebAdminIPC()` 和 `registerEnvSyncIPC()`
- [ ] TASK-M4-24：在 `electron/main/index.ts` 的 `before-quit` 事件中新增 `webAdminServer.stop()` 调用（在 runtime 停止之前），确保退出顺序：web-admin HTTP 服务器 → runtime → PostgreSQL

**优先级**：P0 | **依赖**：4.1, 4.2 | **预估工时**：1 天 | **验收标准**：webadmin:* 和 envsync:* IPC 通道完整注册，webadmin:stateChanged 事件正常推送，应用退出时按序停止 web-admin HTTP 服务器

### 4.5 Preload 暴露 webadmin 和 envsync 命名空间

- [ ] TASK-M4-25：在 `electron/preload/index.ts` 中新增 `webadmin` 命名空间，暴露以下方法：`webadmin.start`、`webadmin.stop`、`webadmin.status`
- [ ] TASK-M4-26：在 `electron/preload/index.ts` 中新增 `envsync` 命名空间，暴露以下方法：`envsync.getRuntimeEnv`、`envsync.setRuntimeEnv`、`envsync.syncWebAdminEnv`、`envsync.getSyncStatus`
- [ ] TASK-M4-27：验证渲染进程可通过 `window.electronAPI.webadmin.*` 和 `window.electronAPI.envsync.*` 调用所有 IPC 方法

**优先级**：P0 | **依赖**：4.4 | **预估工时**：0.5 天 | **验收标准**：渲染进程可通过 window.electronAPI.webadmin.* 和 window.electronAPI.envsync.* 调用所有 IPC 方法

### 4.6 web-admin 构建产物嵌入与打包

- [ ] TASK-M4-28：创建 `resources/web-admin/` 目录占位，添加 `.gitkeep` 文件确保目录结构存在
- [ ] TASK-M4-29：在 `electron-builder.json` 的 `extraResources` 中新增 web-admin 构建产物：`{ "from": "resources/web-admin", "to": "web-admin" }`
- [ ] TASK-M4-30：创建 `scripts/build-web-admin.sh`（Windows 下为 `.ps1`），实现构建流程：`pnpm --filter web-admin build` → 复制 `apps/web-admin/web/dist/` 到 `apps/agentskills-runtime-pc/resources/web-admin/`
- [ ] TASK-M4-31：在 `apps/agentskills-runtime-pc/package.json` 中新增 `build:web-admin` 脚本命令
- [ ] TASK-M4-32：验证 web-admin 构建产物放置到 `resources/web-admin/` 后，WebAdminServer 可正确托管并提供 aibuilder 页面访问

**优先级**：P0 | **依赖**：4.1 | **预估工时**：1 天 | **验收标准**：resources/web-admin/ 目录存在，electron-builder.json 包含 web-admin extraResources 配置，构建脚本可正确复制 web-admin 产物，WebAdminServer 可托管构建产物

### 4.7 HomeView.vue aibuilder URL 修正【v2.3 修正：根据 runtime 版本选择不同 URL】

- [ ] TASK-M4-33：重构 `src/views/HomeView.vue` 的 `aibuilderUrl` 计算属性，根据 runtime 版本选择不同策略：
  - dev 模式：`http://localhost:3031/vue-pro/aibuilder`
  - 生产模式 + runtime ≥ 0.0.26：`http://127.0.0.1:${runtimePort}/vue-pro/aibuilder`（runtime 静态文件服务）
  - 生产模式 + runtime < 0.0.26：`http://localhost:${webAdminPort}/vue-pro/aibuilder`（PC 客户端内置 HTTP 服务器）
- [ ] TASK-M4-34：在 HomeView 中新增 runtime 版本检测逻辑：通过 RuntimeVersionDetector 获取版本信息，根据版本选择 aibuilder URL 策略
- [ ] TASK-M4-35：在 HomeView 中新增 web-admin HTTP 服务器状态查询（仅 runtime < 0.0.26 时需要）：通过 `webadmin:status` IPC 获取 webAdminRunning 和 webAdminPort
- [ ] TASK-M4-36：创建 `src/store/modules/webadmin.ts`（WebAdmin Pinia Store），管理 web-admin HTTP 服务器状态（running/port/url/error），提供 `fetchStatus` action 和 `start`/`stop` action
- [ ] TASK-M4-36a：在 runtime Store 中新增 `version` 字段，runtime 启动成功后通过健康检查接口获取版本号【v2.3 新增】

**优先级**：P0 | **依赖**：4.0 + 4.5 | **预估工时**：1.5 天 | **验收标准**：aibuilderUrl 在 dev 模式下为 `http://localhost:3031/vue-pro/aibuilder`，runtime ≥ 0.0.26 时为 `http://127.0.0.1:{runtimePort}/vue-pro/aibuilder`，runtime < 0.0.26 时为 `http://localhost:{webAdminPort}/vue-pro/aibuilder`，runtime Store 包含 version 字段

### 4.8 M4 web-admin 集成与 runtime 版本检测验证【v2.3 修正】

- [ ] TASK-M4-37：验证 RuntimeVersionDetector 正确检测 runtime 版本，isStaticFileServiceSupported(0.0.26) 返回 true，isStaticFileServiceSupported(0.0.25) 返回 false
- [ ] TASK-M4-38：验证 runtime ≥ 0.0.26 时 WebAdminServer 不启动，aibuilder 从 runtime 端口加载
- [ ] TASK-M4-39：验证 runtime < 0.0.26 时 WebAdminServer 启动，aibuilder 从 webAdminPort 加载
- [ ] TASK-M4-40：验证 WebAdminServer 端口冲突时自动分配新端口（3031-3041），iframe 使用新端口加载 aibuilder
- [ ] TASK-M4-41：验证 EnvSyncManager.syncWebAdminEnv() 根据 BACKEND_URL 正确同步 web-admin .env 中所有配置项
- [ ] TASK-M4-42：验证 webadmin:* IPC 通道（start/stop/status）和 envsync:* IPC 通道（getRuntimeEnv/setRuntimeEnv/syncWebAdminEnv/getSyncStatus）可正常调用
- [ ] TASK-M4-43：验证 webadmin:stateChanged 事件正常推送到渲染进程
- [ ] TASK-M4-44：验证 HomeView aibuilderUrl 在 dev 模式、runtime ≥ 0.0.26、runtime < 0.0.26 三种场景下均正确
- [ ] TASK-M4-45：验证 web-admin 构建产物嵌入安装包后，安装目录包含 web-admin/ 子目录
- [ ] TASK-M4-46：验证应用退出时按序停止：web-admin HTTP 服务器（仅降级模式）→ runtime → PostgreSQL
- [ ] TASK-M4-47：验证 BACKEND_URL 变更后，envsync:syncWebAdminEnv 可正确同步更新 web-admin .env

**优先级**：P0 | **依赖**：4.1~4.7 | **预估工时**：1 天 | **验收标准**：WebAdminServer 正常托管 web-admin 构建产物，aibuilder 可通过内置 HTTP 服务器加载，双 .env 配置同步正常，IPC 通道完整可用，退出顺序正确

---

## 5. M5 登录态共享 — iframe postMessage 监听 + safeStorage 持久化【v2.4 新增】

> **目标**：实现 AuthBridge 模块（iframe postMessage 监听、登录状态管理、access_token safeStorage 持久化），实现 auth:* IPC 通道，实现 Auth Pinia Store，更新 HomeView 和 AppSidebar 的登录态 UI
> **工期**：1.5 周 | **需求覆盖**：spec 2.6（原则 6：登录态共享）、6.13（REQ-AUTH-01/02）、5.3（安全性）、design 1.1.3（AuthBridge）、2.2.2（auth:* 接口）
> **变更性质**：新增为主（AuthBridge 模块、auth IPC、Auth Store、登录态 UI），集成为辅（HomeView/AppSidebar 登录态响应）

### 5.1 AuthBridge 模块实现

- [ ] TASK-M5-01：创建 `electron/modules/auth-bridge.ts`，实现 AuthBridge 类，负责 iframe postMessage 监听、登录状态管理、access_token safeStorage 持久化
- [ ] TASK-M5-02：实现 `setupMessageListener(webContents)` 方法：在 BrowserWindow 的 webContents 上注册 `did-finish-load` 事件后注入 postMessage 监听脚本到 iframe，或通过渲染进程的 `window.addEventListener('message', ...)` 监听 iframe 发送的消息
- [ ] TASK-M5-03：实现 `handleLoginStateChanged(data)` 方法：处理 iframe 发送的 `auth:loginStateChanged` 消息，提取 access_token 和用户信息，调用 saveToken() 持久化 token，更新 ConfigStore 中 auth.loggedIn 和 auth.userInfo，通过 `auth:loginStateChanged` IPC 通道推送到渲染进程
- [ ] TASK-M5-04：实现 `handleLogout()` 方法：处理登出消息，调用 clearToken() 清除 token，清除 ConfigStore 中 auth 配置，推送登出状态到渲染进程
- [ ] TASK-M5-05：实现 postMessage 消息格式验证：验证 `event.origin`（仅接受 aibuilder iframe 来源，如 `http://localhost:*` 或 `http://127.0.0.1:*`），验证 `data.type`（仅处理 `auth:loginStateChanged` 类型），忽略不合规消息并记录警告日志

**优先级**：P0 | **依赖**：M1 完成 | **预估工时**：1.5 天 | **验收标准**：AuthBridge 可监听 iframe postMessage 消息，正确解析登录状态变更，忽略非合规消息

### 5.2 postMessage 通信协议

- [ ] TASK-M5-06：定义 postMessage 消息格式规范：`{ type: "auth:loginStateChanged", data: { loggedIn: boolean, accessToken?: string, userInfo?: { id, username, avatar, roles, permissions } } }`
- [ ] TASK-M5-07：在 AuthBridge 中实现消息解析逻辑：根据 `data.loggedIn` 区分登录/登出事件，登录时提取 `accessToken` 和 `userInfo`，登出时清除所有登录信息
- [ ] TASK-M5-08：处理异常消息格式：data 缺少 loggedIn 字段时记录警告日志并忽略；accessToken 为空字符串时视为登出

**优先级**：P0 | **依赖**：5.1 | **预估工时**：0.5 天 | **验收标准**：postMessage 消息格式定义清晰，AuthBridge 可正确解析登录/登出消息，异常格式有容错处理

### 5.3 safeStorage 持久化

- [ ] TASK-M5-09：实现 `saveToken(accessToken)` 方法：使用 `safeStorage.encryptString(accessToken)` 加密 access_token，将加密后的字符串写入磁盘（存储到 ConfigStore 或独立文件）
- [ ] TASK-M5-10：实现 `getToken()` 方法：从磁盘读取加密字符串，使用 `safeStorage.decryptString()` 解密获取 access_token，返回 `{ token, valid }` 结构
- [ ] TASK-M5-11：实现 `clearToken()` 方法：删除磁盘上的加密 token 数据，清除 ConfigStore 中 auth.loggedIn 和 auth.userInfo
- [ ] TASK-M5-12：实现 `restoreLoginState()` 方法：客户端启动时调用 getToken() 读取 token，验证 token 有效性（非空且格式正确），有效则推送 `auth:loginStateChanged({ loggedIn: true, userInfo })` 到渲染进程，无效则推送 `{ loggedIn: false }`
- [ ] TASK-M5-13：实现 safeStorage 降级处理：`safeStorage.isEncryptionAvailable()` 返回 false 时，降级到内存存储（Map 存储，本次会话有效），记录警告日志，通知用户"安全存储不可用，登录状态仅在本次会话有效"
- [ ] TASK-M5-14：实现 safeStorage 解密失败处理：`safeStorage.decryptString()` 抛出异常时，清除损坏的 token 数据，视为未登录状态，记录警告日志

**优先级**：P0 | **依赖**：5.1 | **预估工时**：1.5 天 | **验收标准**：access_token 加密存储到 safeStorage，客户端重启后可恢复登录态，safeStorage 不可用时降级到内存存储，解密失败时清除损坏数据

### 5.4 IPC 通道注册（auth:*）

- [ ] TASK-M5-15：在 `electron/main/index.ts` 中新增 `registerAuthIPC` 函数，注册以下 IPC 通道：
  - `auth:getToken`：调用 authBridge.getToken()，返回 `{ token?, valid }`
  - `auth:saveToken`：调用 authBridge.saveToken(token)，返回 `{ success }`
  - `auth:clearToken`：调用 authBridge.clearToken()，返回 `{ success }`
- [ ] TASK-M5-16：在 `electron/main/index.ts` 中实现 `auth:loginStateChanged` 推送：AuthBridge 处理登录状态变更后，通过 `BrowserWindow.webContents.send('auth:loginStateChanged', data)` 推送到渲染进程
- [ ] TASK-M5-17：在 `electron/main/index.ts` 的应用初始化流程中调用 `authBridge.restoreLoginState()`（在主窗口创建后、显示主界面之前）
- [ ] TASK-M5-18：在 `electron/main/index.ts` 的应用初始化流程中调用 `registerAuthIPC()`

**优先级**：P0 | **依赖**：5.3 | **预估工时**：1 天 | **验收标准**：auth:* IPC 通道完整注册，auth:loginStateChanged 事件正常推送，客户端启动时恢复登录态

### 5.5 Preload 暴露 auth 命名空间

- [ ] TASK-M5-19：在 `electron/preload/index.ts` 中新增 `auth` 命名空间，暴露以下方法：`auth.getToken`、`auth.saveToken`、`auth.clearToken`、`auth.onLoginStateChanged`（监听推送事件）
- [ ] TASK-M5-20：验证渲染进程可通过 `window.electronAPI.auth.*` 调用所有 IPC 方法

**优先级**：P0 | **依赖**：5.4 | **预估工时**：0.5 天 | **验收标准**：渲染进程可通过 window.electronAPI.auth.* 调用所有 auth IPC 方法

### 5.6 Auth Pinia Store 实现

- [ ] TASK-M5-21：创建 `src/store/modules/auth.ts`（Auth Pinia Store），管理登录状态和用户信息
- [ ] TASK-M5-22：定义 Auth Store 状态：`loggedIn: boolean`、`userInfo: UserInfo | null`、`tokenStorageReady: boolean`
- [ ] TASK-M5-23：实现 `fetchLoginState` action：通过 `auth:getToken` IPC 获取 token 并验证有效性
- [ ] TASK-M5-24：实现 `onLoginStateChanged` action：监听 `auth:loginStateChanged` 推送事件，更新 loggedIn 和 userInfo 状态
- [ ] TASK-M5-25：实现 `clearLogin` action：通过 `auth:clearToken` IPC 清除登录态
- [ ] TASK-M5-26：在 `src/electron/types.ts` 中新增 `AuthConfig`、`UserInfo` 类型定义
- [ ] TASK-M5-27：在 `src/electron/ipc.ts` 中新增 `auth` 相关调用封装（getToken/saveToken/clearToken/onLoginStateChanged）

**优先级**：P0 | **依赖**：5.5 | **预估工时**：1 天 | **验收标准**：Auth Store 管理登录状态和用户信息，监听 auth:loginStateChanged 事件自动更新状态

### 5.7 HomeView 登录态 UI

- [ ] TASK-M5-28：在 `src/views/HomeView.vue` 中集成 Auth Store，监听 `auth:loginStateChanged` 事件
- [ ] TASK-M5-29：HomeView 登录态 UI 响应：已登录时 aibuilder iframe 正常显示（web-admin 已有登录态）；未登录时 aibuilder iframe 中 web-admin 自动显示登录页面（PC 客户端无需额外处理）
- [ ] TASK-M5-30：在 HomeView 中添加 postMessage 监听脚本：通过 `window.addEventListener('message', handler)` 监听 iframe 发送的登录状态消息，通过 IPC 转发给主进程 AuthBridge
- [ ] TASK-M5-31：验证 HomeView 中 postMessage 消息来源验证：仅接受来自 aibuilder iframe 的消息（验证 event.origin）

**优先级**：P1 | **依赖**：5.6 | **预估工时**：1 天 | **验收标准**：HomeView 可监听 iframe 登录状态变更，已登录时 aibuilder 正常显示，未登录时 web-admin 自动显示登录页面

### 5.8 AppSidebar 登录状态 UI

- [ ] TASK-M5-32：在 `src/components/AppSidebar.vue` 中集成 Auth Store，根据登录状态显示不同 UI
- [ ] TASK-M5-33：已登录时：导航栏顶部区域显示用户头像和用户名
- [ ] TASK-M5-34：未登录时：导航栏顶部区域显示"请登录"提示文字，点击后引导用户在 iframe 中完成登录（路由跳转到首页 `/`）
- [ ] TASK-M5-35：登录/登出时导航栏 UI 平滑过渡（无闪烁）

**优先级**：P1 | **依赖**：5.6, M2 完成（AppSidebar 组件）| **预估工时**：1 天 | **验收标准**：导航栏根据登录状态显示用户信息或登录提示，点击登录提示跳转首页

### 5.9 M5 登录态共享验证

- [ ] TASK-M5-36：验证用户在 iframe 中完成登录后，PC 客户端导航栏显示用户头像和用户名
- [ ] TASK-M5-37：验证用户在 iframe 中退出登录后，PC 客户端导航栏显示登录提示
- [ ] TASK-M5-38：验证客户端重启后自动恢复登录态（token 未过期时），导航栏显示用户信息
- [ ] TASK-M5-39：验证 token 过期后启动客户端，导航栏显示登录提示，引导用户重新登录
- [ ] TASK-M5-40：验证 safeStorage 不可用时降级到内存存储，重启后需重新登录
- [ ] TASK-M5-41：验证 postMessage 消息来源验证生效：非 aibuilder 来源的消息被忽略
- [ ] TASK-M5-42：验证 auth:* IPC 通道（getToken/saveToken/clearToken）可正常调用
- [ ] TASK-M5-43：验证日志文件和配置文件中不包含明文 access_token
- [ ] TASK-M5-44：验证 ConfigStore 中 auth 配置（loggedIn/userInfo/tokenStorageReady）正确读写

**优先级**：P0 | **依赖**：5.7, 5.8 | **预估工时**：1 天 | **验收标准**：登录态共享全流程正常（登录/登出/恢复/过期/safeStorage 降级），安全性验证通过

---

## 6. M6 运行时依赖管理 — OpenSSL 检测/安装/内置 + 依赖检查【v2.4 新增】

> **目标**：实现 DependencyManager 模块（OpenSSL 检测/自动安装/内置 DLL、运行时环境依赖检查），实现 dep:* IPC 通道，集成到启动流程，打包 OpenSSL DLL 资源
> **工期**：1 周 | **需求覆盖**：spec 6.14（REQ-DEP-01/02）、5.2（启动与初始化 — 依赖检测）、5.1（安全性 — 开箱即用）、design 1.1.3（DependencyManager）、2.2.2（dep:* 接口）
> **变更性质**：新增为主（DependencyManager 模块、dep IPC、OpenSSL 资源打包），集成为辅（启动流程集成）

### 6.1 DependencyManager 模块实现

- [ ] TASK-M6-01：创建 `electron/modules/dep-manager.ts`，实现 DependencyManager 类，负责运行时环境依赖检测、安装和配置
- [ ] TASK-M6-02：实现 `checkOpenSSL()` 方法：检测 OpenSSL 依赖是否就绪
  - 检查 PATH 环境变量中是否包含 libssl/libcrypto DLL（通过 `where libssl-3-x64.dll` 或检查常见安装路径）
  - 检查 runtime bin 目录中是否包含 OpenSSL DLL
  - 返回 `{ ready: boolean; source: "system" | "bundled" | "none"; path?: string; version?: string }`
- [ ] TASK-M6-03：实现 `installOpenSSL()` 方法：从安装包的 `resources/openssl/` 目录复制 OpenSSL DLL 到 runtime 的 bin 目录
  - 源路径：`resources/openssl/libssl-3-x64.dll`、`resources/openssl/libcrypto-3-x64.dll`
  - 目标路径：runtime bin 目录（通过 SDK 路径获取）
  - 复制完成后更新 ConfigStore 中 `dep.openSSLBundled = true` 和 `dep.openSSLPath`
  - 返回 `{ success: boolean; error?: string; path?: string }`
- [ ] TASK-M6-04：实现 `checkAll()` 方法：检测所有运行时环境依赖是否就绪
  - 调用 PgManager.getInfo() 获取 PostgreSQL 状态
  - 调用 checkOpenSSL() 获取 OpenSSL 状态
  - 返回 `{ postgresql: DepStatus; openssl: DepStatus; allReady: boolean }`
- [ ] TASK-M6-05：实现 `handleRuntimeStartFailure(error)` 方法：runtime 启动失败时自动检测是否因依赖缺失导致
  - 解析错误信息，判断是否为 OpenSSL DLL 缺失（如 "The specified module could not be found"）
  - 如为 OpenSSL 缺失，自动触发 installOpenSSL() 并重试启动

**优先级**：P0 | **依赖**：M1 完成 | **预估工时**：2 天 | **验收标准**：DependencyManager 可检测 OpenSSL 依赖状态，可安装内置 OpenSSL DLL，可检测所有运行时依赖，runtime 启动失败时可自动检测和修复依赖

### 6.2 OpenSSL 检测逻辑

- [ ] TASK-M6-06：实现系统 OpenSSL 检测：遍历 PATH 环境变量中的目录，检查是否存在 libssl-3-x64.dll / libcrypto-3-x64.dll 文件
- [ ] TASK-M6-07：实现内置 OpenSSL 检测：检查 runtime bin 目录（`node_modules/@opencangjie/skills/dist/runtime/win-x64/release/bin/`）中是否包含 OpenSSL DLL
- [ ] TASK-M6-08：实现 OpenSSL 版本检测：尝试执行 `openssl version` 命令获取版本号（如系统已安装）
- [ ] TASK-M6-09：实现 ConfigStore 中 dep 配置读取：读取 `dep.openSSLBundled` 和 `dep.openSSLPath` 判断是否已内置 OpenSSL

**优先级**：P0 | **依赖**：6.1 | **预估工时**：1 天 | **验收标准**：OpenSSL 检测逻辑可正确判断系统/内置/无 OpenSSL 三种状态

### 6.3 OpenSSL DLL 内置与 PATH 配置

- [ ] TASK-M6-10：实现 OpenSSL DLL 复制逻辑：从 `resources/openssl/` 目录复制所有 DLL 文件到 runtime bin 目录
- [ ] TASK-M6-11：实现 PATH 环境变量配置：将 OpenSSL DLL 所在目录添加到 runtime 进程的 PATH 环境变量中（通过 RuntimeManager 启动时设置 env.PATH）
- [ ] TASK-M6-12：处理 DLL 复制失败场景：磁盘空间不足或权限不足时，记录错误日志，返回安装失败结果
- [ ] TASK-M6-13：处理 OpenSSL DLL 已存在场景：目标目录已包含同名 DLL 时，比较文件大小/版本决定是否覆盖

**优先级**：P0 | **依赖**：6.2 | **预估工时**：1 天 | **验收标准**：OpenSSL DLL 可正确复制到 runtime bin 目录，PATH 环境变量正确配置，复制失败有错误处理

### 6.4 运行时环境依赖检查

- [ ] TASK-M6-14：实现 PostgreSQL 依赖状态检测：调用 PgManager.getInfo() 获取状态，转换为 DepStatus 结构 `{ name: "PostgreSQL", ready: boolean, status, message }`
- [ ] TASK-M6-15：实现 OpenSSL 依赖状态检测：调用 checkOpenSSL() 获取状态，转换为 DepStatus 结构
- [ ] TASK-M6-16：实现 allReady 判断：PostgreSQL 和 OpenSSL 均为 ready 时 allReady 为 true

**优先级**：P1 | **依赖**：6.1 | **预估工时**：0.5 天 | **验收标准**：checkAll() 返回完整的依赖状态信息，allReady 判断正确

### 6.5 IPC 通道注册（dep:*）

- [ ] TASK-M6-17：在 `electron/main/index.ts` 中新增 `registerDepIPC` 函数，注册以下 IPC 通道：
  - `dep:checkOpenSSL`：调用 depManager.checkOpenSSL()，返回 OpenSSLCheckResult
  - `dep:installOpenSSL`：调用 depManager.installOpenSSL()，返回 OpenSSLInstallResult
  - `dep:checkAll`：调用 depManager.checkAll()，返回 DepCheckAllResult
- [ ] TASK-M6-18：在 `electron/main/index.ts` 的应用初始化流程中调用 `registerDepIPC()`
- [ ] TASK-M6-19：在 `src/electron/types.ts` 中新增 `DepConfig`、`OpenSSLCheckResult`、`OpenSSLInstallResult`、`DepStatus`、`DepCheckAllResult` 类型定义
- [ ] TASK-M6-20：在 `src/electron/ipc.ts` 中新增 `dep` 相关调用封装（checkOpenSSL/installOpenSSL/checkAll）

**优先级**：P0 | **依赖**：6.1 | **预估工时**：1 天 | **验收标准**：dep:* IPC 通道完整注册，类型定义正确，ipc.ts 包含 dep 调用封装

### 6.6 Preload 暴露 dep 命名空间

- [ ] TASK-M6-21：在 `electron/preload/index.ts` 中新增 `dep` 命名空间，暴露以下方法：`dep.checkOpenSSL`、`dep.installOpenSSL`、`dep.checkAll`
- [ ] TASK-M6-22：验证渲染进程可通过 `window.electronAPI.dep.*` 调用所有 IPC 方法

**优先级**：P0 | **依赖**：6.5 | **预估工时**：0.5 天 | **验收标准**：渲染进程可通过 window.electronAPI.dep.* 调用所有 dep IPC 方法

### 6.7 OpenSSL DLL 资源打包

- [ ] TASK-M6-23：创建 `resources/openssl/` 目录，放置 OpenSSL DLL 文件（libssl-3-x64.dll、libcrypto-3-x64.dll 等）
- [ ] TASK-M6-24：在 `electron-builder.json` 的 `extraResources` 中新增 OpenSSL DLL：`{ "from": "resources/openssl", "to": "openssl" }`
- [ ] TASK-M6-25：在 `electron/modules/config.ts` 的 AppConfig 类型中新增 `dep` 配置组为 DepConfig 嵌套结构：`openSSLBundled: boolean = false`、`openSSLPath: string = ""`
- [ ] TASK-M6-26：更新 `resources/defaults/default-config.json`，新增 dep 配置组

**优先级**：P0 | **依赖**：6.3 | **预估工时**：0.5 天 | **验收标准**：resources/openssl/ 目录包含 OpenSSL DLL，electron-builder.json 包含 openssl extraResources 配置，AppConfig 包含 dep 配置组

### 6.8 启动流程集成依赖检测

- [ ] TASK-M6-27：在 `electron/main/index.ts` 的启动流程中，在启动 runtime 之前调用 `depManager.checkAll()` 检测所有依赖
- [ ] TASK-M6-28：OpenSSL 未就绪时自动调用 `depManager.installOpenSSL()` 安装，安装完成后继续启动流程
- [ ] TASK-M6-29：OpenSSL 安装失败时显示错误提示，提供重试选项，不继续启动 runtime
- [ ] TASK-M6-30：runtime 启动失败时调用 `depManager.handleRuntimeStartFailure(error)` 自动检测和修复依赖

**优先级**：P0 | **依赖**：6.5, 6.7 | **预估工时**：1 天 | **验收标准**：启动流程在 runtime 启动前检测依赖，OpenSSL 未就绪时自动安装，安装失败有错误提示，runtime 启动失败时自动检测依赖

### 6.9 M6 运行时依赖管理验证

- [ ] TASK-M6-31：验证全新 Windows 机器（无 OpenSSL）启动客户端时，自动检测并安装 OpenSSL 依赖，runtime 正常启动
- [ ] TASK-M6-32：验证系统已安装 OpenSSL 时启动客户端，检测到 OpenSSL 已就绪，无需额外操作
- [ ] TASK-M6-33：验证 OpenSSL 安装失败时（如 resources/openssl/ 目录不存在），显示错误提示和重试选项
- [ ] TASK-M6-34：验证 dep:* IPC 通道（checkOpenSSL/installOpenSSL/checkAll）可正常调用
- [ ] TASK-M6-35：验证 checkAll() 返回 PostgreSQL 和 OpenSSL 的完整依赖状态
- [ ] TASK-M6-36：验证 runtime 因 OpenSSL DLL 缺失启动失败时，自动检测并安装 OpenSSL 后重试启动
- [ ] TASK-M6-37：验证 electron-builder.json 包含 openssl extraResources，打包后安装目录包含 openssl/ 子目录
- [ ] TASK-M6-38：验证 ConfigStore 中 dep 配置（openSSLBundled/openSSLPath）正确读写

**优先级**：P0 | **依赖**：6.1~6.8 | **预估工时**：1 天 | **验收标准**：运行时依赖管理全流程正常（检测/安装/配置/启动集成），OpenSSL DLL 打包正确

---

## 7. M7 SDK 集成层重构 + RuntimeIntegrator — runtime 压缩包解压集成与 SDK 降级方案【v2.5 重构】

> **工期**：2 周 | **需求覆盖**：spec 5.5（Runtime 生命周期管理）、6.1（安装与部署 — runtime 压缩包内嵌与解压）、6.2（启动与初始化 — runtime 集成包解压）、6.5（Runtime 生命周期管理 — Runtime 集成包解压与就绪/降级安装）、design 2.1.3.1（启动状态机 — IntegrateRuntime）、2.2.2（runtime:* 接口）、1.1.3（RuntimeIntegrator 模块）
> **变更性质**：重构为主（runtime.ts、runtime-health.ts、runtime-crash.ts、runtime-version.ts），新增为辅（RuntimeIntegrator 模块、runtime:integrate IPC、SDK 降级方案）
> **v2.5 变更**：①新增 7.0 RuntimeIntegrator 模块子任务（压缩包解压/版本检测/.env 自动生成/降级下载/进度推送）；②SDK `downloadRuntime()` 从首次安装主方案降级为版本升级和降级修复方案；③runtime 集成目录从 SDK node_modules 迁移到用户数据目录（`%APPDATA%/agentskills/runtime/`）；④新增 runtime:integrate/runtime:integrateStatus/runtime:integrateProgress IPC 通道；⑤更新 runtime:install IPC 语义（从"下载安装"改为"解压集成或降级下载"）；⑥RuntimeVersionManager 升级路径更新（下载到用户数据目录，备份到 runtime-backup）

### 7.0 RuntimeIntegrator 模块实现【v2.5 新增】

- [ ] TASK-M7-00a：创建 `electron/modules/runtime-integrator.ts`，实现 RuntimeIntegrator 类，负责 runtime 发布版压缩包解压、集成目录管理、版本检测、.env 自动生成、降级下载
- [ ] TASK-M7-00b：实现 `checkIntegrationStatus()` 方法：检测 runtime 集成目录（`%APPDATA%/agentskills/runtime/`）状态，检查目录是否存在且包含完整 runtime 发布版文件、.env 配置文件是否已生成、runtime 二进制文件是否可执行，返回 `{ status: "integrated" | "partial" | "none"; version?: string; envExists: boolean; binaryPath?: string }`
- [ ] TASK-M7-00c：实现 `integrateFromArchive(archivePath, onProgress?)` 方法：验证压缩包文件完整性（文件大小、格式检查），创建集成目录（若不存在），使用 `tar` 解压 `agentskills-runtime-win-x64.tar.gz` 到 `%APPDATA%/agentskills/runtime/`，提供解压进度回调（`onProgress(percent: number)`），解压完成后自动调用 `generateDefaultEnv()` 生成默认 .env 配置，返回 `{ success: boolean; version?: string; error?: string; envGenerated: boolean }`
- [ ] TASK-M7-00d：实现 `generateDefaultEnv()` 方法：读取集成目录下的 `.env.example` 文件，填充默认配置值（PORT=8080、HOST=0.0.0.0、BACKEND_URL=http://localhost:8080），根据 ConfigStore 中 pgsql 配置生成 `orm_connectionUrl`，随机生成 `AUTH_CORE_SECRET`，写入 `.env` 文件到集成目录，返回 `{ success: boolean; envPath?: string; error?: string }`
- [ ] TASK-M7-00e：实现 `fallbackDownload(onProgress?)` 方法：降级到 SDK `RuntimeManager.downloadRuntime()` 从网络下载 runtime，触发条件为压缩包解压失败或压缩包损坏，下载完成后将文件复制到用户数据目录集成路径，生成默认 .env 配置，返回 `{ success: boolean; version?: string; error?: string; source: "network" }`
- [ ] TASK-M7-00f：实现 `getIntegratedRuntimePath()` 方法：获取已集成的 runtime 二进制路径，优先返回用户数据目录路径（`%APPDATA%/agentskills/runtime/bin/`），回退到 SDK node_modules 路径（`node_modules/@opencangjie/skills/dist/runtime/win-x64/release/bin/`），返回 `{ path: string; source: "integrated" | "sdk" }`
- [ ] TASK-M7-00g：实现 `cleanupExtraction()` 方法：删除 `%APPDATA%/agentskills/temp/runtime-extract/` 临时目录，在解压完成或失败后调用

**优先级**：P0 | **依赖**：M1 完成 | **预估工时**：3 天 | **验收标准**：RuntimeIntegrator 可检测 runtime 集成目录状态，可从压缩包解压 runtime 到集成目录并生成默认 .env，解压失败时可降级到 SDK 网络下载，可获取已集成 runtime 路径（优先用户数据目录），可清理临时文件

### 7.1 封装 SDK 集成层

- [ ] TASK-M7-01：创建 `electron/modules/sdk-runtime.ts`，封装 `@opencangjie/skills` SDK 的 RuntimeManager 编程 API，通过 `createRequire(import.meta.url)` 引入 SDK（ESM 环境下兼容 CJS 模块）
- [ ] TASK-M7-02：实现 SDK RuntimeManager 初始化：检测 SDK 安装状态，获取 runtime 二进制路径 — 生产环境优先从用户数据目录 `%APPDATA%/agentskills/runtime/`（由 RuntimeIntegrator 解压获得），回退到 SDK node_modules 目录 `node_modules/@opencangjie/skills/dist/runtime/win-x64/release/`（开发环境或降级方案）；开发环境从 SDK node_modules 目录获取【v2.5 更新：路径优先级从 SDK 优先改为用户数据目录优先】
- [ ] TASK-M7-03：封装 SDK install-runtime 调用：**降级为版本升级和修复方案**，不再作为首次安装主方案；首次安装改为通过 RuntimeIntegrator.integrateFromArchive() 从安装包内嵌压缩包解压；SDK install-runtime 仅在压缩包解压失败（降级下载）或 runtime 版本升级时使用【v2.5 更新：语义从"首次下载安装"改为"降级下载和版本升级"】
- [ ] TASK-M7-04：封装 SDK start/stop/status 调用：通过 SDK RuntimeManager 启动/停止/查询 runtime 进程

**优先级**：P0 | **依赖**：M1 完成 + 7.0 | **预估工时**：2 天 | **验收标准**：SDK 集成层可正确调用 install-runtime/start/stop/status，生产环境路径优先从用户数据目录查找，开发环境从 SDK node_modules 查找，SDK install-runtime 仅用于降级下载和版本升级

### 7.2 重构 RuntimeManager 模块

- [ ] TASK-M7-05：重构 `electron/modules/runtime.ts`（RuntimeManager），将直接 `child_process.spawn` runtime 二进制的逻辑替换为调用 SDK 集成层（`sdk-runtime.ts`）的 start/stop 方法
- [ ] TASK-M7-06：保留 RuntimeManager 的状态管理接口（`onStateChange`、`getInfo`），内部改为从 SDK 获取状态
- [ ] TASK-M7-07：保留端口冲突自动分配逻辑（通过 PortManager），在 SDK start 前检测端口可用性
- [ ] TASK-M7-08：保留进程 stdout/stderr 日志收集逻辑，从 SDK 启动的 runtime 进程中获取输出
- [ ] TASK-M7-09：更新 runtime 二进制路径查找逻辑：**优先从用户数据目录查找**（`%APPDATA%/agentskills/runtime/bin/`，由 RuntimeIntegrator 解压获得），回退到 SDK node_modules 目录（`node_modules/@opencangjie/skills/dist/runtime/win-x64/release/bin/`）【v2.5 更新：原优先从 SDK node_modules 查找，回退到用户数据目录；现反转优先级】

**优先级**：P0 | **依赖**：7.1 | **预估工时**：2 天 | **验收标准**：RuntimeManager 通过 SDK 管理 runtime 生命周期，不再直接 spawn 二进制，状态管理接口不变

### 7.3 更新 Runtime IPC 接口

- [ ] TASK-M7-10：更新 `runtime:install` IPC 通道语义：**v2.5 语义变更** — 优先从安装包内嵌压缩包解压（调用 RuntimeIntegrator.integrateFromArchive()），解压失败时降级到 SDK downloadRuntime 从网络下载；原语义为"通过 SDK 下载安装"。签名更新为 `runtime:install(options?: { force?: boolean }) → IPCResult<RuntimeIntegrateResult>`
- [ ] TASK-M7-10a：新增 `runtime:integrate` IPC 通道【v2.5 新增】，签名：`runtime:integrate(options?: { force?: boolean }) → IPCResult<RuntimeIntegrateResult>`，业务说明：触发 runtime 压缩包解压集成。若集成目录已存在且 `force` 为 false，则跳过解压；若 `force` 为 true，则重新解压覆盖。解压失败时自动降级到 SDK downloadRuntime 从网络下载
- [ ] TASK-M7-10b：新增 `runtime:integrateStatus` IPC 通道【v2.5 新增】，签名：`runtime:integrateStatus() → IPCResult<RuntimeIntegrateStatus>`，业务说明：查询 runtime 集成状态（集成目录是否存在、版本、.env 是否已生成、runtime 二进制路径、集成来源）
- [ ] TASK-M7-10c：新增 `runtime:integrateProgress` IPC 推送通道（Main → Renderer）【v2.5 新增】，签名：`runtime:integrateProgress(progress: { stage: "extracting" | "generating-env" | "downloading" | "completed" | "failed"; percent: number; message?: string })`，业务说明：runtime 集成进度推送，包含当前阶段和百分比
- [ ] TASK-M7-11：更新 `runtime:start` IPC 通道，支持通过 SDK 启动 runtime，返回 RuntimeInfo
- [ ] TASK-M7-12：在 `electron/preload/index.ts` 中暴露 `runtime.install` 方法到渲染进程
- [ ] TASK-M7-12a：在 `electron/preload/index.ts` 中暴露 `runtime.integrate` 和 `runtime.integrateStatus` 方法到渲染进程，注册 `runtime.integrateProgress` 推送事件监听【v2.5 新增】
- [ ] TASK-M7-13：在 `src/electron/ipc.ts` 中新增 `runtime.install` 调用封装
- [ ] TASK-M7-13a：在 `src/electron/ipc.ts` 中新增 `runtime.integrate` 和 `runtime.integrateStatus` 调用封装【v2.5 新增】
- [ ] TASK-M7-14：在 `src/electron/types.ts` 中新增 `RuntimeInstallResult` 类型定义
- [ ] TASK-M7-14a：在 `src/electron/types.ts` 中新增 `RuntimeIntegrateResult`、`RuntimeIntegrateStatus`、`RuntimeIntegrateProgress` 类型定义（若 M1 未完成）【v2.5 新增】

**优先级**：P0 | **依赖**：7.2 | **预估工时**：1.5 天 | **验收标准**：渲染进程可通过 IPC 调用 runtime:install（语义为解压集成或降级下载）、runtime:integrate、runtime:integrateStatus，runtime:integrateProgress 推送事件正常工作，runtime:start 通过 SDK 启动

### 7.4 更新健康检查与崩溃恢复

- [ ] TASK-M7-15：验证 `electron/modules/runtime-health.ts`（RuntimeHealthCheck）与 SDK 重构后的 RuntimeManager 兼容，健康检查端点 `/api/v1/uctoo/health` 轮询正常
- [ ] TASK-M7-16：验证 `electron/modules/runtime-crash.ts`（RuntimeCrashRecovery）与 SDK 重构后的 RuntimeManager 兼容，崩溃监听和自动重启正常
- [ ] TASK-M7-17：更新崩溃恢复逻辑：SDK 启动的 runtime 进程退出事件监听方式可能不同，需适配 SDK 的进程退出通知机制
- [ ] TASK-M7-18：更新 `electron/modules/runtime-version.ts`（RuntimeVersionManager）与 SDK 重构后的 RuntimeManager 兼容，版本升级和回滚正常；**v2.5 更新升级路径**：upgrade() 下载目标改为用户数据目录（`%APPDATA%/agentskills/runtime/`），备份旧版本到 `%APPDATA%/agentskills/runtime-backup/`，回滚时从 runtime-backup 恢复

**优先级**：P1 | **依赖**：7.2 | **预估工时**：1.5 天 | **验收标准**：健康检查、崩溃恢复、版本管理在 SDK 重构后功能正常

### 7.5 实现 AI Key 测试连接接口

- [ ] TASK-M7-19：在 `electron/modules/setup.ts` 中新增 `testAIConnection` 方法，通过 runtime 代理验证 API Key 有效性
- [ ] TASK-M7-20：新增 `setup:testAI` IPC 通道，签名：`setup:testAI(options: { provider: string; apiKey: string; baseUrl?: string }) → IPCResult<{ success: boolean; error?: string }>`
- [ ] TASK-M7-21：在 `electron/preload/index.ts` 中暴露 `setup.testAI` 方法到渲染进程
- [ ] TASK-M7-22：在 `src/electron/ipc.ts` 中新增 `setup.testAI` 调用封装
- [ ] TASK-M7-23：处理 runtime 未启动时的测试连接场景：跳过实时验证，返回提示"Runtime 未启动，API Key 将在启动后验证"

**优先级**：P1 | **依赖**：7.3 | **预估工时**：1 天 | **验收标准**：配置向导中可点击"测试连接"按钮验证 API Key，runtime 未启动时返回友好提示

### 7.6 更新 Renderer 端 Runtime 状态模块

- [ ] TASK-M7-24：更新 `src/store/modules/runtime.ts`（Pinia 模块），新增 `installRuntime` action，通过 IPC 调用 `runtime:install`
- [ ] TASK-M7-24a：更新 `src/store/modules/runtime.ts`，新增 `integrateRuntime` action，通过 IPC 调用 `runtime:integrate`，监听 `runtime:integrateProgress` 推送事件更新集成进度状态【v2.5 新增】
- [ ] TASK-M7-24b：更新 `src/store/modules/runtime.ts`，新增 `integrateStatus` state 和 `fetchIntegrateStatus` action，通过 IPC 调用 `runtime:integrateStatus`【v2.5 新增】
- [ ] TASK-M7-25：更新 `src/store/modules/runtime.ts`，新增 `testAIConnection` action，通过 IPC 调用 `setup:testAI`
- [ ] TASK-M7-26：验证 Runtime 状态轮询（5 秒间隔）与 SDK 重构后的状态推送兼容

**优先级**：P1 | **依赖**：7.3, 7.5 | **预估工时**：1 天 | **验收标准**：Renderer 端可调用 installRuntime、integrateRuntime 和 testAIConnection，集成进度状态可正常更新，状态轮询正常

### 7.7 M7 SDK 集成 + RuntimeIntegrator 验证

- [ ] TASK-M7-27：验证 runtime 完整生命周期通过 SDK 管理：集成（解压/降级下载）→ 启动 → 健康检查 → 停止 → 重启【v2.5 更新：新增集成步骤】
- [ ] TASK-M7-28：验证 runtime 压缩包解压集成：首次启动时自动从安装包内嵌压缩包解压 runtime 到 `%APPDATA%/agentskills/runtime/`，解压完成后自动生成默认 .env 配置【v2.5 新增】
- [ ] TASK-M7-28a：验证 runtime 压缩包解压失败降级下载：压缩包损坏或不存在时，自动降级到 SDK `downloadRuntime()` 从网络下载，下载完成后复制到用户数据目录并生成 .env【v2.5 新增】
- [ ] TASK-M7-28b：验证 runtime 集成目录已存在时跳过解压：`%APPDATA%/agentskills/runtime/` 已包含完整 runtime 文件时，直接使用已有 runtime【v2.5 新增】
- [ ] TASK-M7-28c：验证 runtime:integrate IPC 通道：force=true 时重新解压覆盖已有 runtime【v2.5 新增】
- [ ] TASK-M7-28d：验证 runtime:integrateStatus IPC 通道：正确返回集成状态（integrated/partial/none + 版本 + .env 是否存在 + 来源）【v2.5 新增】
- [ ] TASK-M7-28e：验证 runtime:integrateProgress 推送事件：解压过程中推送进度百分比和阶段信息到渲染进程【v2.5 新增】
- [ ] TASK-M7-29：验证 runtime 崩溃恢复：手动终止 runtime 进程，观察自动重启和通知
- [ ] TASK-M7-30：验证 AI Key 测试连接：在配置向导中输入 API Key 并点击测试，验证成功/失败结果
- [ ] TASK-M7-31：验证开发环境和生产环境的 runtime 路径解析正确（生产环境优先用户数据目录，开发环境 SDK node_modules）
- [ ] TASK-M7-32：验证 RuntimeVersionManager 升级路径：下载到用户数据目录，备份旧版本到 runtime-backup，回滚时从 runtime-backup 恢复【v2.5 新增】

**优先级**：P0 | **依赖**：7.6 | **预估工时**：1.5 天 | **验收标准**：runtime 全生命周期通过 SDK 管理正常，压缩包解压集成正常（含降级下载），集成进度推送正常，AI Key 测试连接功能正常，版本升级和回滚路径正确

---

## 8. M8 首页与配置向导重构 — aibuilder 全屏加载与 4 步向导

> **目标**：重构首页为 aibuilder iframe 全屏展示（含 dev 模式支持和 runtime 未启动等待界面，aibuilder URL 从 webAdminPort 加载），扩展配置向导为 4 步（欢迎→AI Key→数据库配置→完成，完成后同步 web-admin .env），更新设置视图
> **工期**：2 周 | **需求覆盖**：spec 5.3（配置向导）、5.4（数据库配置）、5.6（首页 aibuilder 加载）、5.12（双 .env 配置同步）、design 2.5.4/2.5.5
> **变更性质**：重构为主（HomeView、SetupView、SettingsView），新增为辅（RuntimeWaitView）
> **v2.2 变更**：①从原 M5 重编号为 M6；v2.4 再重编号为 M8；②aibuilder URL 从 runtime 端口改为 webAdminPort；③配置向导完成后同步 web-admin .env；④依赖新增 M4

### 8.1 实现 RuntimeWaitView 组件

- [ ] TASK-M8-01：创建 `src/components/RuntimeWaitView.vue`，实现 runtime 未启动时的友好等待界面
- [ ] TASK-M8-02：RuntimeWaitView 包含：应用名称（"AgentSkills"）、runtime 状态说明文字、启动进度指示（spinner + 状态文字）、一键启动按钮
- [ ] TASK-M8-03：实现启动超时处理：点击启动后 30 秒内 runtime 未启动成功，显示"Runtime 启动超时，请检查日志"提示 + 查看日志按钮
- [ ] TASK-M8-04：实现 iframe 加载失败提示：aibuilder URL 不可达时显示"AI Builder 加载失败"提示 + 重试按钮
- [ ] TASK-M8-05：实现 dev 模式下开发服务器未启动提示：iframe 加载超时后显示"开发服务器未启动，请先启动 web-admin（端口 3031）"提示
- [ ] TASK-M8-06：实现 web-admin HTTP 服务器未启动提示：生产模式下 webadmin 服务器未运行时显示"Web 管理界面服务未启动"提示 + 重试按钮【v2.2 新增】

**优先级**：P0 | **依赖**：M2 完成（左侧导航布局）| **预估工时**：1.5 天 | **验收标准**：runtime 未启动时显示友好等待界面，启动按钮可触发 runtime 启动，超时和加载失败有对应提示，web-admin 服务器未启动有提示

### 8.2 重构 HomeView 首页

- [ ] TASK-M8-07：重构 `src/views/HomeView.vue` 的 `aibuilderUrl` 计算属性：dev 模式下直接使用 `http://localhost:3031/vue-pro/aibuilder`，不受 runtime 状态限制；生产模式下从 webadmin IPC 获取 webAdminPort，构建 URL 为 `http://localhost:{webAdminPort}/vue-pro/aibuilder`【v2.2 修正：不再依赖 runtimePort】
- [ ] TASK-M8-08：重构 HomeView 的 iframe 全屏展示：移除 `margin: -16px` 抵消方式，改为 `position: absolute; top:0; left:0; width:100%; height:100%` 全屏展示
- [ ] TASK-M8-09：重构 HomeView 的 runtime 未启动占位页：移除跳转链接（Runtime 监控/系统设置），替换为 RuntimeWaitView 组件
- [ ] TASK-M8-10：实现 HomeView 的 runtime 状态监听：runtime 启动成功后自动从 RuntimeWaitView 切换为 iframe 加载 aibuilder
- [ ] TASK-M8-11：实现 HomeView 的 web-admin HTTP 服务器状态监听：webadmin 服务器启动后更新 aibuilderUrl【v2.2 新增】
- [ ] TASK-M8-12：实现 iframe 加载失败处理：新增 `onIframeError` 回调，显示重试按钮
- [ ] TASK-M8-13：实现 dev 模式下 iframe 加载超时处理：显示开发环境提示

**优先级**：P0 | **依赖**：8.1, M4 完成（web-admin 集成）, M7 完成（SDK 集成）| **预估工时**：2 天 | **验收标准**：生产模式 runtime 启动后 iframe 全屏加载 aibuilder（从 webAdminPort），dev 模式直接加载 localhost:3031，runtime 未启动显示等待界面，加载失败有重试提示

### 8.3 扩展 SetupView 为 4 步配置向导

- [ ] TASK-M8-14：重构 `src/views/setup/SetupView.vue` 为 4 步向导：Step 1 欢迎页（功能介绍 + 零配置说明）→ Step 2 AI 模型 API Key 配置 → Step 3 数据库配置（内置/外部 PostgreSQL）→ Step 4 完成并启动
- [ ] TASK-M8-15：Step 1 欢迎页：展示功能介绍（AI 对话、技能管理、智能体管理），强调"仅需配置 AI Key 和选择数据库，其余全部默认"
- [ ] TASK-M8-16：Step 2 AI 配置页扩展：新增提供商选项（OpenAI、Anthropic、智谱 AI、通义千问、DeepSeek、Ollama），每个提供商独立配置 API Key、API Base URL（可选）、模型选择（可选）
- [ ] TASK-M8-17：Step 2 新增"测试连接"按钮：调用 `setup:testAI` IPC 验证 API Key 有效性，显示验证结果（成功/失败 + 原因）
- [ ] TASK-M8-18：Step 2 支持配置多个提供商，设定默认提供商
- [ ] TASK-M8-19：Step 3 数据库配置页：内置 PostgreSQL（默认推荐）— 显示说明文字"PC 客户端将自动管理 PostgreSQL 数据库实例，无需额外操作"，显示默认配置信息（端口 5432、用户 uctoo、数据目录），无需用户输入；外部 PostgreSQL — 主机地址（必填）、端口（默认 5432）、用户名（必填）、密码（必填）、数据库名（默认 uctoo），"测试连接"按钮验证连通性 + 认证 + uctoo 数据库是否存在，连接测试失败不允许继续
- [ ] TASK-M8-20：Step 3 数据库配置页：内置模式选择后点击"下一步"直接进入 Step 4；外部模式需测试连接成功后才允许进入 Step 4
- [ ] TASK-M8-21：Step 4 完成页：内置模式自动执行 PgManager.initialize()，显示初始化进度（initdb → 配置 → 启动 → createdb → 导入 SQL → 停止）；保存 AI 配置 → 保存数据库配置 → 生成 runtime .env（含 orm_connectionUrl + BACKEND_URL）→ **同步 web-admin .env（调用 envsync:syncWebAdminEnv）**→ 标记 setupCompleted → 跳转首页【v2.2 增强：新增同步 web-admin .env 步骤】
- [ ] TASK-M8-22：验证向导完成后：PostgreSQL 自动初始化（内置模式）或连接配置保存（外部模式），runtime .env 中 orm_connectionUrl 自动更新，**web-admin .env 同步生成**，runtime 自动启动，首页自动加载 aibuilder

**优先级**：P0 | **依赖**：M3 完成（PostgreSQL 集成）、M4 完成（web-admin 集成）、M7 完成（AI Key 测试接口）| **预估工时**：3 天 | **验收标准**：配置向导为 4 步流程，Step 2 支持 6 个 AI 提供商和测试连接，Step 3 支持内置/外部 PostgreSQL 选择和测试连接，Step 4 内置模式自动初始化 PG 并更新 orm_connectionUrl，完成后同步 web-admin .env

### 8.4 更新 SettingsView 设置视图

- [ ] TASK-M8-23：从 `src/views/settings/SettingsView.vue` 中移除 SSL 配置组 UI（已在 M1 移除数据层，此处移除 UI 层残留）
- [ ] TASK-M8-24：在 SettingsView 中新增数据库配置区域：支持在内置 PostgreSQL 和外部 PostgreSQL 之间切换，内置模式显示端口/数据目录/自动备份配置，外部模式显示主机/端口/用户名/密码/数据库名配置，支持测试连接
- [ ] TASK-M8-25：在 SettingsView 中新增 AI 模型配置区域：支持修改 AI 提供商、API Key、Base URL、模型选择，支持测试连接
- [ ] TASK-M8-26：在 SettingsView 中新增 runtime 服务地址配置区域：支持修改 BACKEND_URL，修改后自动触发 envsync:syncWebAdminEnv 同步 web-admin .env，并重启 web-admin HTTP 服务器【v2.2 新增】
- [ ] TASK-M8-27：在 SettingsView 中新增"重新进入配置向导"按钮，点击后跳转 `/setup`
- [ ] TASK-M8-28：在 SettingsView 中新增"一键重置为默认配置"按钮，确认后重置 config.json

**优先级**：P1 | **依赖**：8.3 | **预估工时**：1.5 天 | **验收标准**：SettingsView 不含 SSL 配置 UI，含数据库配置区域（内置/外部切换+测试连接），含 AI 模型配置区域，含 runtime 服务地址配置（修改后同步 web-admin .env），支持重新进入向导和重置配置

### 8.5 M8 首页与向导验证

- [ ] TASK-M8-29：验证首页 aibuilder iframe 全屏展示：生产模式下 runtime 启动后 iframe 填满主内容区，URL 为 `http://localhost:{webAdminPort}/vue-pro/aibuilder`，无可见边距和边框【v2.2 修正：验证 webAdminPort 而非 runtimePort】
- [ ] TASK-M8-30：验证首页 dev 模式：iframe 加载 `http://localhost:3031/vue-pro/aibuilder`
- [ ] TASK-M8-31：验证 runtime 未启动时首页显示 RuntimeWaitView，点击启动后自动切换为 iframe
- [ ] TASK-M8-32：验证 web-admin HTTP 服务器未启动时首页显示"Web 管理界面服务未启动"提示【v2.2 新增】
- [ ] TASK-M8-33：验证配置向导 4 步流程完整可用，Step 3 数据库配置（内置/外部）功能正常
- [ ] TASK-M8-34：验证向导选择内置 PostgreSQL 完成后：自动初始化 PG，orm_connectionUrl 自动更新，**web-admin .env 同步生成**，runtime 自动启动
- [ ] TASK-M8-35：验证向导选择外部 PostgreSQL 完成后：连接测试通过，orm_connectionUrl 自动更新为外部连接串
- [ ] TASK-M8-36：验证 SettingsView 中 runtime 服务地址修改后，web-admin .env 自动同步更新【v2.2 新增】
- [ ] TASK-M8-37：验证 SettingsView 中数据库配置修改、AI 配置修改、重新进入向导、重置配置功能正常
- [ ] TASK-M8-38：验证 iframe 安全配置：sandbox 属性和 allow 属性正确，剪贴板读写、弹窗、表单提交功能正常

**优先级**：P0 | **依赖**：8.4 | **预估工时**：1 天 | **验收标准**：首页 aibuilder 加载全场景正常（含 webAdminPort 修正），配置向导 4 步流程完整（含数据库配置和 web-admin .env 同步），设置视图功能正常

---

## 9. M9 web-admin 构建集成与打包更新【v2.5 更新：新增 runtime tar.gz 资源】

> **目标**：集成 web-admin 构建产物到 PC 客户端，更新 electron-builder 打包配置（保留 pgsql 资源、新增 web-admin 资源、新增 runtime 压缩包资源），优化安装包体积
> **工期**：1 周 | **需求覆盖**：spec 5.1（安装与部署 — 安装包内容含 runtime 压缩包）、5.6.1-5（web-admin 集成）、design 2.4（目录结构 — resources/runtime/）、2.7
> **变更性质**：重构为主（electron-builder.json、NSIS 脚本），新增为辅（构建脚本、runtime 压缩包资源目录）
> **v2.5 变更**：①新增 runtime 发布版压缩包（`agentskills-runtime-win-x64.tar.gz`，约 380MB 压缩）打包到安装包；②安装包体积约束从"完整版 ≤ 300MB"调整为"含 runtime 压缩包约 600-800MB"（electron-builder maximum 压缩后）；③移除"精简版安装包"概念，统一为包含 runtime 的完整安装包；④NSIS 安装脚本新增 runtime 压缩包复制步骤

### 9.1 完善 web-admin 构建集成脚本

- [ ] TASK-M9-01：验证 M4 中创建的 `scripts/build-web-admin.sh`（`.ps1`）构建流程正确：`pnpm --filter web-admin build` → 复制 `apps/web-admin/web/dist/` 到 `apps/agentskills-runtime-pc/resources/web-admin/`
- [ ] TASK-M9-02：在 `apps/agentskills-runtime-pc/package.json` 的 `build` 脚本中集成 web-admin 构建步骤（先构建 web-admin，再构建 PC 客户端）
- [ ] TASK-M9-03：验证 web-admin 构建产物中包含 `.env` 文件（由 EnvSyncManager 生成）

**优先级**：P1 | **依赖**：M8 完成 | **预估工时**：0.5 天 | **验收标准**：执行 `pnpm build:web-admin` 后 web-admin 构建产物正确复制到 resources/web-admin/ 目录，含 .env 文件

### 9.2 更新 electron-builder 打包配置

- [ ] TASK-M9-04：保留 `electron-builder.json` 的 `extraResources` 中 pgsql 相关条目：`resources/pgsql/bin` → `pgsql/bin`、`resources/pgsql/lib` → `pgsql/lib`、`resources/pgsql/share` → `pgsql/share`
- [ ] TASK-M9-05：保留 `electron-builder.json` 的 `extraResources` 中 `resources/sql` → `sql` 条目
- [ ] TASK-M9-06：验证 `electron-builder.json` 的 `extraResources` 中 web-admin 构建产物条目：`{ "from": "resources/web-admin", "to": "web-admin" }`（M4 中已添加）
- [ ] TASK-M9-06a：在 `electron-builder.json` 的 `extraResources` 中新增 runtime 发布版压缩包：`{ "from": "resources/runtime/agentskills-runtime-win-x64.tar.gz", "to": "runtime/agentskills-runtime-win-x64.tar.gz" }`【v2.5 新增】
- [ ] TASK-M9-06b：创建 `resources/runtime/` 目录占位，添加 `.gitkeep` 文件确保目录结构存在；放置 `agentskills-runtime-win-x64.tar.gz` runtime 发布版压缩包（约 380MB 压缩，1.27GB 解压）【v2.5 新增】
- [ ] TASK-M9-07：验证 `electron-builder.json` 中保留的 extraResources 完整列表：`resources/pgsql/bin` → `pgsql/bin`、`resources/pgsql/lib` → `pgsql/lib`、`resources/pgsql/share` → `pgsql/share`、`resources/sql` → `sql`、`resources/defaults` → `defaults`、`resources/tray-icon.png` → `tray-icon.png`、`resources/web-admin` → `web-admin`、`resources/runtime/agentskills-runtime-win-x64.tar.gz` → `runtime/agentskills-runtime-win-x64.tar.gz`【v2.5 更新：新增 runtime tar.gz】

**优先级**：P0 | **依赖**：9.1 | **预估工时**：1 天 | **验收标准**：electron-builder.json 包含 pgsql/sql/web-admin/runtime-tar.gz/defaults/tray-icon 资源，打包后安装包中包含 pgsql、sql、web-admin 目录和 runtime/agentskills-runtime-win-x64.tar.gz 文件

### 9.3 更新 NSIS 安装脚本

- [ ] TASK-M9-08：更新 `build/installer.nsh`，确保 PostgreSQL 二进制分发包在安装时正确解压到安装目录的 pgsql/ 子目录
- [ ] TASK-M9-09：更新 `build/installer.nsh`，确保 SQL 初始化脚本在安装时正确解压到安装目录的 sql/ 子目录
- [ ] TASK-M9-10：更新 `build/installer.nsh`，确保 web-admin 构建产物在安装时正确解压到安装目录的 web-admin/ 子目录
- [ ] TASK-M9-10a：更新 `build/installer.nsh`，确保 runtime 发布版压缩包（`agentskills-runtime-win-x64.tar.gz`）在安装时正确复制到安装目录的 runtime/ 子目录（注意：runtime 压缩包不解压，由 PC 客户端首次启动时通过 RuntimeIntegrator 解压到用户数据目录）【v2.5 新增】
- [ ] TASK-M9-11：更新卸载逻辑：保留 PostgreSQL 数据目录清理选项（用户可选择保留或删除数据），保留用户配置和日志的保留选项

**优先级**：P1 | **依赖**：9.2 | **预估工时**：0.5 天 | **验收标准**：NSIS 安装脚本正确处理 pgsql/sql/web-admin 资源解压，卸载逻辑提供数据保留选项

### 9.4 安装包体积优化

- [ ] TASK-M9-12：验证完整安装包体积约 600-800MB（含 runtime 压缩包 ~380MB + PostgreSQL 二进制 ~50MB + Electron 壳 ~80MB + web-admin 构建产物 ~10MB + OpenSSL DLL ~10MB + 其他资源 ~10MB，经 electron-builder maximum 压缩后）【v2.5 更新：从"完整版 ≤ 300MB"调整为"含 runtime 压缩包约 600-800MB"】
- [ ] TASK-M9-13：验证安装后磁盘占用约 2GB（含 runtime 解压后 ~1.27GB + PostgreSQL ~100MB + Electron + 其他 ~630MB）【v2.5 新增】
- [ ] TASK-M9-14：如体积超标，分析各组件体积占比，优化压缩策略（如 electron-builder compression 设为 maximum、web-admin 产物 tree-shaking、PostgreSQL 二进制 strip）
- [ ] TASK-M9-15：更新 `resources/defaults/default-config.json` 中的默认配置，确保与 v2.5 AppConfig 结构一致（含 webadmin 配置组、runtime.integratedVersion/integratedSource 字段）【v2.5 更新】
- [ ] TASK-M9-16：移除"精简版安装包"概念，统一为包含 runtime 压缩包的完整安装包【v2.5 新增】

**优先级**：P2 | **依赖**：9.3 | **预估工时**：1 天 | **验收标准**：完整安装包体积在 600-800MB 范围内（electron-builder maximum 压缩后），安装后磁盘占用约 2GB，无精简版概念

### 9.5 M9 构建集成验证

- [ ] TASK-M9-17：执行完整构建流程：`pnpm build:web-admin` → `pnpm build`，验证构建无错误
- [ ] TASK-M9-18：验证打包后的安装包内容：包含 web-admin 目录、pgsql 目录（bin/lib/share）、sql 目录、**runtime 目录（含 agentskills-runtime-win-x64.tar.gz 压缩包）**【v2.5 更新：新增 runtime 目录验证】
- [ ] TASK-M9-19：在全新 Windows 环境安装验证：双击安装包 → 安装成功 → 桌面出现图标 → 安装目录包含 pgsql/bin/、sql/、web-admin/ 和 **runtime/agentskills-runtime-win-x64.tar.gz**【v2.5 更新：新增 runtime 压缩包验证】
- [ ] TASK-M9-20：验证安装后 runtime 可通过 RuntimeIntegrator 从压缩包解压到用户数据目录并正常启动【v2.5 更新：从"SDK 安装"改为"压缩包解压"】
- [ ] TASK-M9-21：验证安装后 aibuilder 页面可正常加载（web-admin HTTP 服务器启动后，从 webAdminPort 加载）
- [ ] TASK-M9-22：验证安装后 PostgreSQL 二进制可正常执行（initdb --version 返回版本信息）
- [ ] TASK-M9-23：验证安装包体积在 600-800MB 范围内（electron-builder maximum 压缩后）【v2.5 新增】

**优先级**：P0 | **依赖**：9.4 | **预估工时**：1 天 | **验收标准**：完整构建流程无错误，安装包内容与 v2.5 设计一致（含 pgsql/sql/web-admin/runtime-tar.gz），全新安装后功能正常，安装包体积在约束范围内

---

## 10. M10 集成测试与体验打磨【v2.5 更新：新增解压集成测试和降级下载测试】

> **目标**：端到端流程测试、性能指标验证、异常场景完善（含 runtime 解压集成异常、PostgreSQL 和 web-admin 异常场景）、用户体验打磨，确保 v2.5 达到 toC 产品体验标准
> **工期**：2 周 | **需求覆盖**：spec 全模块（含 6.1 安装与部署 — runtime 压缩包解压异常、6.2 启动与初始化 — runtime 集成包解压、6.5 Runtime 生命周期管理 — runtime 压缩包解压失败/降级下载、5.4 PostgreSQL 异常场景、5.6 web-admin 异常场景、5.12 双 .env 配置同步异常场景）、design DFX 约束
> **变更性质**：测试为主，修复为辅
> **v2.5 变更**：①新增 runtime 压缩包解压集成测试和降级下载测试；②冷启动时间从 ≤90s 调整为 ≤60s（含 runtime 解压验证和 PG 初始化，无需网络下载）；③安装包体积验证从"完整版 ≤ 300MB"调整为"约 600-800MB"；④磁盘空间不足阈值从 800MB 调整为 3GB；⑤移除"精简版安装包"测试

### 10.1 端到端流程测试

- [ ] TASK-M10-01：测试全新安装流程：双击安装包 → 安装 → 首次启动 → **runtime 压缩包自动解压到 `%APPDATA%/agentskills/runtime/`** → 配置向导 4 步（含数据库配置）→ 进入主界面 → aibuilder 加载（从 webAdminPort）【v2.5 更新：新增 runtime 压缩包解压步骤】
- [ ] TASK-M10-02：测试常规启动流程：双击桌面图标 → PostgreSQL 自动启动 → runtime 自动启动 → **同步 web-admin .env** → **web-admin HTTP 服务器启动** → 主界面可交互（≤ 15 秒）【v2.2 修正：增加 web-admin .env 同步和 HTTP 服务器启动步骤】
- [ ] TASK-M10-03：测试冷启动流程（含 runtime 解压验证和 PG 初始化）：首次启动 → **runtime 压缩包解压到集成目录** → PG 初始化 → 启动 → 主界面可交互（≤ 60 秒）【v2.5 更新：从"SDK 下载安装 runtime"改为"压缩包解压验证"，冷启动时间从 ≤90s 调整为 ≤60s】
- [ ] TASK-M10-04：测试左侧导航栏所有路由跳转：首页/技能/智能体/Runtime/数据库/设置/关于，验证导航项高亮切换
- [ ] TASK-M10-05：测试系统托盘完整功能：右键菜单所有项（含 PostgreSQL 状态指示和操作、web-admin HTTP 服务器状态指示）、托盘图标点击激活、关闭窗口最小化到托盘
- [ ] TASK-M10-06：测试配置修改流程：SettingsView 修改 AI 配置/数据库配置/runtime 服务地址 → 保存 → web-admin .env 同步 → runtime 和 PG 按需重启
- [ ] TASK-M10-07：测试自动更新流程：检测更新 → 下载 → 安装（客户端和 runtime 分别测试）
- [ ] TASK-M10-08：测试数据库备份恢复完整流程：点击"备份数据库" → 生成 .backup 文件 → 点击"恢复数据库" → 选择备份文件 → runtime 停止 → 恢复 → runtime 重启
- [ ] TASK-M10-09：测试数据库模式切换流程：内置 → 外部（测试连接 → 更新 .env → runtime 重启）→ 内置（启动内置 PG → 更新 .env → runtime 重启）
- [ ] TASK-M10-10：测试双 .env 配置同步流程：修改 runtime BACKEND_URL → web-admin .env 自动同步 → 重启 web-admin HTTP 服务器 → aibuilder 使用新配置【v2.2 新增】

**优先级**：P0 | **依赖**：M9 完成 | **预估工时**：2.5 天 | **验收标准**：所有端到端流程测试通过（含 PostgreSQL 流程和 web-admin 集成流程），无阻塞性问题

### 10.2 性能指标验证

- [ ] TASK-M10-11：验证冷启动时间 ≤ 60 秒（含 runtime 解压验证和 PG 初始化，无需网络下载 runtime）【v2.5 更新：从 ≤90s 调整为 ≤60s】
- [ ] TASK-M10-12：验证热启动时间 ≤ 15 秒（从双击图标到主界面可交互，含 web-admin HTTP 服务器启动）
- [ ] TASK-M10-13：验证 runtime 健康检查响应 ≤ 2 秒
- [ ] TASK-M10-14：验证 PostgreSQL 启动时间 ≤ 10 秒
- [ ] TASK-M10-15：验证 web-admin HTTP 服务器启动时间 ≤ 3 秒【v2.2 新增】
- [ ] TASK-M10-16：验证客户端空闲状态内存占用 ≤ 250MB（含 Electron + runtime + PostgreSQL + web-admin HTTP 服务器）
- [ ] TASK-M10-17：验证客户端活跃状态内存占用 ≤ 500MB
- [ ] TASK-M10-18：验证 CPU 空闲状态占用 ≤ 5%
- [ ] TASK-M10-19：验证导航切换响应 ≤ 100ms

**优先级**：P1 | **依赖**：10.1 | **预估工时**：1 天 | **验收标准**：所有性能指标满足 spec 4.1 DFX 约束（含 PostgreSQL 启动时间和 web-admin HTTP 服务器启动时间）

### 10.3 异常场景完善

- [ ] TASK-M10-20：测试 runtime 压缩包解压失败场景：压缩包损坏或磁盘空间不足时解压失败，验证失败提示 + 重试按钮 + **"从网络下载"降级选项**【v2.5 更新：从"runtime 下载失败"改为"runtime 压缩包解压失败"，新增降级下载选项】
- [ ] TASK-M10-20a：测试 runtime 降级下载场景：压缩包解压失败后，点击"从网络下载"选项，验证 SDK downloadRuntime() 降级下载流程正常，下载完成后 runtime 可正常启动【v2.5 新增】
- [ ] TASK-M10-20b：测试 runtime 降级下载网络超时场景：压缩包解压失败后降级到 SDK 网络下载时网络中断或超时，验证下载超时提示 + 重试按钮【v2.5 新增】
- [ ] TASK-M10-20c：测试 runtime 集成目录部分损坏场景：`%APPDATA%/agentskills/runtime/` 目录存在但不完整（缺少关键文件），验证 RuntimeIntegrator 检测到 partial 状态后重新解压【v2.5 新增】
- [ ] TASK-M10-21：测试 runtime 启动超时场景：runtime 30 秒内未启动，验证超时提示 + 查看日志按钮
- [ ] TASK-M10-22：测试 runtime 端口冲突场景：默认端口 8080 被占用，验证自动分配端口
- [ ] TASK-M10-23：测试 runtime 崩溃恢复场景：手动 kill runtime 进程，验证自动重启和通知
- [ ] TASK-M10-24：测试连续崩溃保护场景：5 分钟内崩溃 3 次，验证停止自动重启 + 提示用户
- [ ] TASK-M10-25：测试 PostgreSQL 初始化失败场景：initdb 执行失败（磁盘空间不足），验证失败提示 + 重试按钮
- [ ] TASK-M10-26：测试 PostgreSQL 启动失败场景：pg_ctl 启动失败（端口冲突），验证自动分配端口或失败提示
- [ ] TASK-M10-27：测试 PostgreSQL 异常停止场景：手动终止 PG 进程，验证自动重启和系统通知
- [ ] TASK-M10-28：测试 PostgreSQL 端口冲突场景：默认端口 5432 被占用，验证自动分配新端口并更新 config 和 .env
- [ ] TASK-M10-29：测试数据库备份恢复异常场景：备份文件损坏，验证恢复失败提示
- [ ] TASK-M10-30：测试外部 PostgreSQL 连接中断场景：运行中外部 PG 变为不可达，验证通知和重新配置选项
- [ ] TASK-M10-31：测试 aibuilder iframe 加载失败场景：web-admin HTTP 服务器启动但 aibuilder URL 不可达，验证重试提示
- [ ] TASK-M10-32：测试 web-admin HTTP 服务器启动失败场景：端口 3031-3041 均被占用或构建产物目录不存在，验证失败提示【v2.2 新增】
- [ ] TASK-M10-33：测试 web-admin HTTP 服务器端口冲突场景：默认端口 3031 被占用，验证自动分配新端口，iframe 使用新端口加载 aibuilder【v2.2 新增】
- [ ] TASK-M10-34：测试 runtime .env 损坏场景：runtime .env 文件不存在或格式错误，验证重新生成默认配置提示【v2.2 新增】
- [ ] TASK-M10-35：测试 web-admin .env 损坏场景：web-admin .env 文件不存在或格式错误，验证根据 runtime BACKEND_URL 自动重新生成【v2.2 新增】
- [ ] TASK-M10-36：测试 dev 模式下开发服务器未启动场景：验证开发环境提示
- [ ] TASK-M10-37：测试 API Key 验证失败场景：输入无效 API Key，验证失败提示
- [ ] TASK-M10-38：测试磁盘空间不足场景：安装目标磁盘 < 3GB（需容纳安装包解压 + runtime 解压 + PostgreSQL 数据），验证安装提示【v2.5 更新：阈值从 800MB 调整为 3GB】
- [ ] TASK-M10-39：测试窗口尺寸过小场景：窗口宽度 < 800px，验证导航栏折叠

**优先级**：P1 | **依赖**：10.1 | **预估工时**：2.5 天 | **验收标准**：所有异常场景（含 PostgreSQL 异常和 web-admin 异常）有友好的用户提示和恢复选项

### 10.4 用户体验打磨

- [ ] TASK-M10-40：优化配置向导 Step 2 的 AI 提供商选择交互：下拉选择 + 自动填充默认 Base URL
- [ ] TASK-M10-41：优化配置向导 Step 3 数据库配置交互：内置模式一键确认、外部模式自动填充默认端口和数据库名
- [ ] TASK-M10-42：优化首页 runtime 等待界面的视觉设计：应用 Logo、渐变背景、状态动画
- [ ] TASK-M10-43：优化导航栏折叠/展开的过渡动画（transition: width 0.2s ease）
- [ ] TASK-M10-44：优化系统通知文案：确保通知内容简洁明了，包含操作建议（含 PostgreSQL 和 web-admin 相关通知）
- [ ] TASK-M10-45：优化日志查看体验：Runtime 监控页面日志流自动滚动、级别过滤
- [ ] TASK-M10-46：优化 PgsqlView 备份列表交互：备份文件大小显示、时间格式化、一键恢复确认对话框
- [ ] TASK-M10-47：验证 iframe 内 aibuilder 的剪贴板读写、弹窗、表单提交功能正常
- [ ] TASK-M10-48：验证单实例锁：启动第二个实例时激活已有窗口

**优先级**：P2 | **依赖**：10.3 | **预估工时**：2 天 | **验收标准**：用户体验流畅，交互细节完善（含数据库配置交互和 web-admin 集成交互），无明显的 UI/UX 问题

### 10.5 M10 体验打磨验证

- [ ] TASK-M10-49：执行完整回归测试：覆盖 spec 10.1 全部 24 个核心验收场景（含 PostgreSQL 相关 AC-04/05/10/18/19/20 和 web-admin 相关 AC-21/22/23/24）【v2.2 更新：验收场景从 20 增加到 24】
- [ ] TASK-M10-50：执行架构验收：验证 Runtime 管理通过 SDK、PostgreSQL 管理完整（初始化/启停/备份恢复/连接配置/orm_connectionUrl 自动更新）、无 SSL 管理、配置向导 4 步、**web-admin 集成正常（内置 HTTP 服务器托管、aibuilder URL 从 webAdminPort 加载）**、**双 .env 配置同步正常**（spec 10.4）
- [ ] TASK-M10-51：执行 UI 验收：导航栏左侧竖向 200-240px、常驻显示（含数据库管理项）、aibuilder 全屏（URL 为 `http://localhost:{webAdminPort}/vue-pro/aibuilder`）、图标统一风格（spec 10.3）
- [ ] TASK-M10-52：执行体积验收：完整安装包约 600-800MB（含 runtime 压缩包 ~380MB + PG ~50MB + web-admin ~10MB + Electron 壳 ~80MB，经 electron-builder maximum 压缩后），安装后磁盘占用约 2GB（含 runtime 解压后 ~1.27GB）（spec 5.1）【v2.5 更新：从"完整版 ≤ 300MB、精简版 ≤ 150MB"调整为"约 600-800MB"】

**优先级**：P0 | **依赖**：10.4 | **预估工时**：1 天 | **验收标准**：全部验收场景通过（含 PostgreSQL 验收、web-admin 集成验收、runtime 解压集成验收），安装包体积和性能指标满足 v2.5 约束，v2.5 达到 toC 产品发布标准

---

## 11. M11 跨平台支持（可选） — macOS 与 Linux 适配

> **目标**：在 Windows 版本稳定后，适配 macOS 和 Linux 平台，实现跨平台分发（含 PostgreSQL 二进制跨平台支持和 web-admin HTTP 服务器跨平台兼容）
> **工期**：2 周 | **需求覆盖**：spec 4.5（兼容性）、7.1（技术约束）
> **变更性质**：新增为主（平台适配代码），重构为辅（路径管理、打包配置）
> **v2.2 变更**：①从原 M8 重编号为 M9；v2.4 再重编号为 M11；②增加 web-admin HTTP 服务器跨平台适配

### 11.1 macOS 适配

- [ ] TASK-M11-01：适配 `electron/utils/paths.ts` 中 macOS 路径常量（`~/Library/Application Support/agentskills/`、`~/Library/Logs/agentskills/`）
- [ ] TASK-M11-02：适配 SDK runtime 二进制路径：macOS 为 `dist/runtime/darwin-arm64/release/` 或 `dist/runtime/darwin-x64/release/`
- [ ] TASK-M11-03：适配 PostgreSQL 二进制路径：macOS 下 pgsql/bin/ 中可执行文件无 .exe 后缀，需调整 PgManager 中的路径拼接逻辑
- [ ] TASK-M11-04：适配 `electron/modules/tray.ts` 中 macOS 托盘行为（macOS 托盘图标点击默认行为不同）
- [ ] TASK-M11-05：适配 `electron/modules/auto-launch.ts` 中 macOS 开机自启（使用 `launchd` 而非注册表）
- [ ] TASK-M11-06：适配 `electron/modules/webadmin-server.ts` 中 macOS 路径：web-admin 构建产物目录路径在 macOS 下的解析【v2.2 新增】
- [ ] TASK-M11-07：配置 electron-builder DMG 打包：`electron-builder.json` 新增 mac 配置（target: DMG、identity、entitlements）
- [ ] TASK-M11-08：适配 macOS 应用图标（.icns 格式）和窗口样式

**优先级**：P2 | **依赖**：M10 完成 | **预估工时**：1 周 | **验收标准**：macOS 版本可正常启动、runtime 管理、PostgreSQL 管理、web-admin HTTP 服务器正常、aibuilder 加载、托盘功能正常

### 11.2 Linux 适配

- [ ] TASK-M11-09：适配 `electron/utils/paths.ts` 中 Linux 路径常量（`~/.config/agentskills/`、`~/.local/share/agentskills/`）
- [ ] TASK-M11-10：适配 SDK runtime 二进制路径：Linux 为 `dist/runtime/linux-x64/release/`
- [ ] TASK-M11-11：适配 PostgreSQL 二进制路径：Linux 下 pgsql/bin/ 中可执行文件无 .exe 后缀
- [ ] TASK-M11-12：适配 Linux 桌面环境托盘（某些桌面环境无系统托盘，需降级处理）
- [ ] TASK-M11-13：适配 `electron/modules/auto-launch.ts` 中 Linux 开机自启（使用 `.desktop` 文件）
- [ ] TASK-M11-14：适配 `electron/modules/webadmin-server.ts` 中 Linux 路径：web-admin 构建产物目录路径在 Linux 下的解析【v2.2 新增】
- [ ] TASK-M11-15：配置 electron-builder AppImage 打包：`electron-builder.json` 新增 linux 配置（target: AppImage、category、icon）
- [ ] TASK-M11-16：适配 Ubuntu 22.04 依赖库（libgtk-3、libnotify 等系统依赖声明）

**优先级**：P2 | **依赖**：M10 完成 | **预估工时**：1 周 | **验收标准**：Linux 版本可正常启动、runtime 管理、PostgreSQL 管理、web-admin HTTP 服务器正常、aibuilder 加载，托盘在支持的桌面环境正常

### 11.3 跨平台验证

- [ ] TASK-M11-17：在 macOS 12 (Monterey) x64 和 ARM64 上验证完整功能（含 PostgreSQL 初始化和备份恢复、web-admin HTTP 服务器和 aibuilder 加载）
- [ ] TASK-M11-18：在 Ubuntu 22.04 x64 上验证完整功能（含 PostgreSQL 初始化和备份恢复、web-admin HTTP 服务器和 aibuilder 加载）
- [ ] TASK-M11-19：验证三个平台的安装包体积均在约束范围内（含 PostgreSQL 二进制和 web-admin 构建产物）
- [ ] TASK-M11-20：验证三个平台的性能指标满足 DFX 约束
- [ ] TASK-M11-21：验证自定义协议（agentskills://）在三个平台正常注册
- [ ] TASK-M11-22：验证三个平台的双 .env 配置同步功能正常【v2.2 新增】

**优先级**：P2 | **依赖**：11.1, 11.2 | **预估工时**：1 周 | **验收标准**：三平台功能对齐（含 PostgreSQL 和 web-admin 集成），性能和体积满足约束

---

## 任务统计总览

| 里程碑 | 主任务数 | 子任务数 | 预估工期 | 变更性质 |
|--------|---------|---------|---------|---------|
| M1 架构清理与模块增强 | 9 | 52 | 1 周 | 增强为主 + 移除为辅 |
| M2 UI 重构 — 左侧导航布局 | 8 | 41 | 2 周 | 新增为主 + 重构为辅 |
| M3 PostgreSQL 集成管理 | 8 | 39 | 2 周 | 增强为主 + 新增为辅 |
| M4 web-admin 集成与 runtime 版本检测 | 8 | 45 | 2 周 | 新增为主 + 修正为辅 |
| M5 登录态共享【v2.4 新增】 | 9 | 44 | 1.5 周 | 新增为主 + 集成为辅 |
| M6 运行时依赖管理【v2.4 新增】 | 9 | 38 | 1 周 | 新增为主 + 集成为辅 |
| M7 SDK 集成层重构 + RuntimeIntegrator【v2.5 重构】 | 8 | 46 | 2 周 | 重构为主 + 新增为辅 |
| M8 首页与配置向导重构 | 5 | 38 | 2 周 | 重构为主 + 新增为辅 |
| M9 web-admin 构建集成与打包【v2.5 更新】 | 5 | 25 | 1 周 | 重构为主 + 新增为辅 |
| M10 集成测试与体验打磨【v2.5 更新】 | 5 | 58 | 2 周 | 测试为主 + 修复为辅 |
| M11 跨平台支持（可选） | 3 | 22 | 2 周 | 新增为主 + 适配为辅 |
| **合计** | **77** | **448** | **16 周**（含跨平台 18 周） | — |

## 需求覆盖矩阵

| spec 需求章节 | 覆盖里程碑 | 关键任务 |
|--------------|-----------|---------|
| 2 顶层设计原则【v2.4 新增】 | M5, M6, 全局 | 原则 6 登录态共享由 M5 覆盖；原则 1-5 作为全局设计约束 |
| 6.1 安装与部署 | M7, M9 | TASK-M7-00a~g（runtime 压缩包解压集成），TASK-M9-06a~b（runtime tar.gz 打包），TASK-M9-10a（NSIS runtime 压缩包复制）【v2.5 更新】 |
| 6.2 启动与初始化 | M3, M4, M6, M7, M8 | TASK-M3-01~08, TASK-M4-01~07, TASK-M6-27~30, TASK-M7-00b~e（runtime 集成检测与解压）, TASK-M7-01~09, TASK-M8-07~13【v2.5 更新：新增 runtime 集成检测与解压】 |
| 6.3 配置向导 | M1, M8 | TASK-M1-21~24, TASK-M8-14~22 |
| 6.4 PostgreSQL 集成管理 | M3 | TASK-M3-01~39 |
| 6.5 Runtime 生命周期管理 | M7 | TASK-M7-00a~g（runtime 集成包解压与就绪/降级安装）, TASK-M7-01~32【v2.5 更新：新增 runtime 集成包解压与降级安装】 |
| 6.6 首页 aibuilder 加载 | M4, M8 | TASK-M4-33~36, TASK-M8-01~13, TASK-M8-29~38 |
| 6.7 左侧竖向导航 | M2 | TASK-M2-01~41 |
| 6.8 导航图标 | M2 | TASK-M2-16~20 |
| 6.9 系统集成 | M1, M10 | TASK-M1-37~39, TASK-M10-05 |
| 6.10 自动更新 | M10 | TASK-M10-07 |
| 6.11 前端复用与适配 | M1, M2, M7 | TASK-M1-13~20, TASK-M2-28~34, TASK-M7-10~14a |
| 6.12 双 .env 配置同步 | M4, M8, M10 | TASK-M4-08~15, TASK-M4-20~27, TASK-M8-21~22, TASK-M8-26, TASK-M10-10, TASK-M10-34~35 |
| 6.13 登录态共享【v2.4 新增】 | M5 | TASK-M5-01~44 |
| 6.14 运行时依赖管理【v2.4 新增】 | M6 | TASK-M6-01~38 |
| DFX 性能 | M10 | TASK-M10-11~19（冷启动 ≤60s）【v2.5 更新】 |
| DFX 可靠性 | M3, M4, M6, M7, M10 | TASK-M3-31~39, TASK-M4-37~45, TASK-M6-31~38, TASK-M7-27~32, TASK-M10-20~20c（runtime 解压异常）, TASK-M10-25~39 |
| DFX 安全性 | M5, M8, M10 | TASK-M5-05, TASK-M5-41, TASK-M5-43, TASK-M8-38, TASK-M10-47 |
| DFX 兼容性 | M11 | TASK-M11-01~22 |

## 关键风险与缓解措施

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| @opencangjie/skills SDK API 不稳定 | M7 进度受阻 | 提前验证 SDK RuntimeManager API，准备 fallback 方案（保留直接 spawn 能力）；v2.5 起 SDK 降级为升级/修复方案，首次安装依赖压缩包解压，SDK API 不稳定的影响范围缩小【v2.5 更新】 |
| runtime 压缩包解压失败（磁盘空间不足/压缩包损坏/权限不足）【v2.5 新增】 | M7 首次启动异常 | RuntimeIntegrator 提供重试选项和降级到 SDK downloadRuntime() 网络下载选项；检测磁盘空间（至少 3GB 可用）和写入权限；压缩包完整性校验（文件大小/格式检查） |
| runtime 压缩包体积过大导致安装包体积超标【v2.5 新增】 | M9 安装包体积超出 600-800MB 约束 | 使用 electron-builder maximum 压缩；runtime 压缩包本身已是 tar.gz 格式（约 380MB 压缩/1.27GB 解压）；如整体体积仍超标，考虑 runtime 压缩包单独分发或增量更新策略 |
| runtime 降级下载网络不可用【v2.5 新增】 | M7 压缩包解压失败后无法降级安装 | 提示用户检查网络连接和镜像源配置；提供手动下载链接；记录详细错误日志便于排查 |
| runtime 集成目录权限不足或被占用【v2.5 新增】 | M7 解压或运行时异常 | 检测 `%APPDATA%/agentskills/runtime/` 目录写入权限；目录被占用时提供重试和强制重新集成选项 |
| PostgreSQL 二进制分发包跨平台兼容性 | M3/M11 进度受阻 | 首版聚焦 Windows x64，提前验证 PostgreSQL 12+ 二进制在 Windows 10 上的运行；macOS/Linux 适配时使用对应平台二进制 |
| PostgreSQL 初始化流程复杂度高 | M3 进度受阻 | PgManager.initialize() 已有 85% 匹配度，增量修改为主；分步实现，每步独立验证 |
| web-admin 构建产物与内置 HTTP 服务器不兼容 | M4 集成失败 | 提前验证 serve-handler 托管 Vue SPA 构建产物的能力，确认 history fallback 和静态资源加载正常；准备 express 降级方案 |
| web-admin .env 运行时覆盖机制不确定 | M4 配置同步失败 | 提前验证 Vue 3 构建产物中 .env 配置的运行时覆盖方式；如构建时注入不可覆盖，改用 web-admin HTTP 服务器动态配置注入 |
| 左侧导航布局与 OpenTiny Vue 组件样式冲突 | M2 UI 异常 | 隔离导航栏 CSS 作用域，使用 CSS 变量避免全局污染 |
| Lucide Icons Vue 与 Electron 渲染进程兼容性 | M2 图标异常 | 提前测试 Lucide Icons 在 Electron 中的渲染，准备 SVG 内联降级方案 |
| runtime 崩溃恢复在 SDK 模式下行为不同 | M7 稳定性问题 | 适配 SDK 的进程退出通知机制，保留原有崩溃计数逻辑 |
| PostgreSQL 端口冲突与系统已有 PG 实例 | M3 启动异常 | PortManager 自动分配可用端口（5432-5442），端口变更后同步更新 config 和 .env |
| orm_connectionUrl 更新后 runtime 未重启导致连接失败 | M8 运行时错误 | updateEnvUrl 后提示用户重启 runtime，或在切换数据库模式时自动重启 runtime |
| web-admin HTTP 服务器端口冲突（3031-3041 均被占用） | M4 启动异常 | PortManager 自动分配可用端口（3031-3041），分配失败时提示用户释放端口 |
| BACKEND_URL 变更后 web-admin .env 同步但 aibuilder 未生效 | M8 配置不一致 | 同步 web-admin .env 后重启 web-admin HTTP 服务器，使新配置生效 |
| Electron safeStorage 不可用【v2.4 新增】 | M5 登录态无法持久化 | 降级到内存存储（本次会话有效），提示用户；检查操作系统加密服务状态 |
| postMessage 消息来源伪造【v2.4 新增】 | M5 安全风险 | 严格验证 event.origin，仅接受 aibuilder iframe 来源；验证 data.type 字段 |
| OpenSSL DLL 与系统已安装版本冲突【v2.4 新增】 | M6 runtime 启动异常 | 内置兼容版本 OpenSSL DLL 到 runtime bin 目录，优先加载内置版本 |
| OpenSSL DLL 复制失败（权限/空间不足）【v2.4 新增】 | M6 依赖安装失败 | 提供重试选项和手动下载链接；检测磁盘空间和权限 |

---

## 集成修复记录

### 2026-08-06 runtime 发布版本集成修复

**背景**：M1~M9 里程碑代码已基本完成，但在 runtime 发布版本集成验证中发现多个关键问题。

**修复内容**：

1. **main/index.ts 自动启动流程增强**（`electron/main/index.ts:496-530`）
   - 问题：runtime 未安装时直接调用 `runtimeManager.start()` 抛异常，导致启动流程中断
   - 修复：新增 SDK 自动下载安装逻辑 — 先检查 `runtimeManager.isInstalled()`，未安装时通过 `@opencangjie/skills` SDK 的 `downloadRuntime()` 自动下载，下载失败发送 `service:startFailed` 事件而非中断流程
   - 新增：在 `envSyncManager.syncWebAdminEnv()` 前调用 `envGenerator.generateForRuntime()` 确保 runtime .env 文件存在

2. **envSyncManager BACKEND_URL 回退逻辑**（`electron/modules/env-sync.ts:51-57`）
   - 问题：`syncWebAdminEnv()` 读取 runtime .env 获取 `BACKEND_URL`，但 runtime .env 可能尚未生成，导致 `BACKEND_URL` 为空
   - 修复：从 `configStore.get()` 读取 `runtime.port` 和 `runtime.host` 作为回退值，确保 `BACKEND_URL` 始终有效

3. **webAdminServer 状态桥接缺失**（`electron/main/index.ts`）
   - 问题：`webAdminServer.onStateChange()` 未注册，渲染进程的 `webadmin:stateChanged` 事件从未被发送
   - 修复：新增 `setupWebAdminStateBridge()` 函数，将 `WebAdminServerInfo` 转换为渲染进程期望的格式（含 `running` 布尔字段）并推送

4. **HomeView.vue 事件数据结构不匹配**（`src/views/HomeView.vue:139-145`）
   - 问题：`webadmin:stateChanged` 事件处理使用 `info.running`，但 `WebAdminServerInfo` 使用 `state` 字段
   - 修复：兼容两种格式 `info.running || info.state === 'running'`

5. **HomeView.vue webadmin.status 返回值不匹配**（`src/views/HomeView.vue:101-104`）
   - 问题：`fetchWebAdminStatus` 中使用 `statusResult.data.running`，但 `webAdminServer.getInfo()` 返回 `state` 字段
   - 修复：改为 `statusResult.data.state === 'running'`

6. **HomeView.vue unsubscribeServiceError 未调用**（`src/views/HomeView.vue:181`）
   - 问题：`unsubscribeServiceError` 缺少 `()` 调用，导致清理时未取消事件监听
   - 修复：添加 `()` 调用

**关键设计决策**：

- **runtime 压缩包内嵌到安装包**【v2.5 变更】：runtime 发布版压缩包（`agentskills-runtime-win-x64.tar.gz`，约 380MB 压缩/1.27GB 解压）内嵌到 PC 客户端安装包中，首次启动时通过 RuntimeIntegrator 模块自动解压到用户数据目录 `%APPDATA%/agentskills/runtime/`。取代原"首次启动时通过 SDK downloadRuntime() 网络下载"方案。SDK `downloadRuntime()` 降级为 runtime 版本升级和降级修复方案（压缩包解压失败时使用）。安装包体积从 ≤300MB 调整为 600-800MB，冷启动时间从 ≤90s 调整为 ≤60s
- **runtime 不打包进安装包**【v2.4 原决策，v2.5 已变更】：~~runtime 发布版本约 1.27 GB（含 LLVM/clang），不应打包进 Electron 安装包。首次启动时通过 SDK `downloadRuntime()` 自动下载到用户数据目录 `%APPDATA%/agentskills/runtime/`~~ → v2.5 起改为压缩包内嵌方案
- **web-admin .env 运行时生成**：web-admin build 产物（dist）中不含 .env 文件，由 `EnvSyncManager.syncWebAdminEnv()` 在 PC 客户端启动时动态生成到 `resources/web-admin/.env`
- **aibuilder URL 策略**：dev 模式 → `http://localhost:3031/vue-pro/aibuilder`；runtime ≥ 0.0.26 → `http://127.0.0.1:{runtimePort}/vue-pro/aibuilder`（SFS）；runtime < 0.0.26 → `http://localhost:{webAdminPort}/vue-pro/aibuilder`（WebAdmin 降级）
