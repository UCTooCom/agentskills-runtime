# RuntimeNativeInstaller 完成度盘点与收尾清单

**盘点日期**：2026-10-09（更新）
**盘点依据**：`installer/src/**/*.cj` 源码实证（**59 文件 / ~15.0k 行**）、`installer/package.ps1`、`dist/` 产物、`git status`
**规格基线**：`spec.md`（REQ-RNI-001~109 / AC-001~276）、`design.md` **v1.8**、`tasks.md` v1.1.0（T001~T058）
**结论一句话**：**installer 工程自身代码至 T056 已闭环**（T001~T050 + T053 + T056 全部落地，CLI 主流程通道补齐）；剩余 = 重出包（待编译通过后跑 package.ps1）+ git 纳管 + Phase 10 五个**跨子工程**任务（T052/T054/T055/T057/T058，落在 web-admin 与 runtime 另一侧，需各自编译验证）。

---

## 一、完成度总览

| Phase | 任务 | 状态 | 实证 |
|---|---|---|---|
| 0 工程骨架与 CLI | T001~T005 | ✅ 完成 | `cjpm.toml`、`main.cj`、`cli/{args,report,env_check,db_export,seed_cmd,progress}.cj`、`util/` |
| 1 平台层 | T006~T009 | ✅ 完成 | `platform/{subprocess_timeout,process_table,envvars,net,probe}.cj` |
| 2 核心层 | T010~T014 | ✅ 完成 | `core/{paths,state,winfs,relmgr,ctx,runtime_pid}.cj`；**T012 probe 下沉 `platform/probe.cj`**（v1.8） |
| 3 HTTP 引导服务 | T015~T026 | ✅ 完成 | `http/{bootstrap,routes}.cj` + `handlers/` 9 个；静态向导由 `routes.cj serveStatic` 承担 |
| 4 服务层 | T027~T032 | ✅ 完成 | `services/{db,bcrypt_admin,envfile_service,ssl_service,media,download,diskstore}.cj` |
| 5 编排与自退役 | T033~T034 | ✅ 完成 | `core/orchestrator.cj`（S0~S8 + 自退役 GC） |
| 6 DevKit | T035~T038 | ✅ 完成 | `services/devkit/{registry,install,verify,init,disk}.cj` |
| 7 Seed 导出 | T039~T045 | ✅ 完成 | 策略文件实际落于 `apps/agentskills-runtime/sql/seed/{export-policy,sanitize-policy}.json`（见下方订正） |
| 8 Seed 导入 | T046~T049 | ✅ 完成 | `services/seed/{importer,rbac,verify}.cj`、`cli/seed_cmd.cj` |
| 9 出包与验收 | T050 ✅ / T051 ✅(文档) | 完成 | `package.ps1` + `dist/ucInstaller-win-x64`（112 项 smoke 通过）；验收清单已刷新 |
| 10 流式进度与运维归位 | T052~T058 | ✅ 代码落地 | installer 内 T053/T056 完成；跨工程项 T052/T054/T055/T057/T058 **代码已全部写入 web-admin 与 runtime 两侧**，待用户编译验证（M-7/M-8） |

**计数**：59 个 `.cj`（新增 `cmd/{context,devkit_cmd,install_cmd}.cj`、`serve/manage.cj`、`cli/progress.cj`、`services/devkit/disk.cj`）/ 约 15.0k 行。

### 源码与任务表的事实订正（design/tasks 与代码不一致处）

| 任务表写法 | 代码实际 | 说明 |
|---|---|---|
| `src/http/static_site.cj`（T017） | 不存在 | 静态向导内联于 `routes.cj` 的 `serveStatic`，未单独成文件 |
| `src/core/atomic.cj`（T013） | 不存在 | staging + 原子切换落在 `core/relmgr.cj`（`prepareStaging` / `requiredReleaseFiles`） |
| `assets/install/*`（design v1.7 图） | `assets/` 平铺 | v1.8 已订正；`paths.cj:72` 是 `installRoot.join("assets")` |
| `sql/seed/` 为空（早前误判） | 实际在 `apps/agentskills-runtime/sql/seed/` | T039 产物已落盘；`resolve` 默认 `Path(".")`，从 runtime 根执行自动命中，**非缺失** |

---

## 二、本轮收尾动作（已执行）

### A. CLI 主流程通道补齐（design §4.2.4 / R-42「CLI 为基础，HTTP 仅封装」）

新建叶子包 `uc_installer.cmd`（避免 `core→cli` 反向依赖成环），把编排器与 DevKit 能力从「仅 HTTP 可见」下沉为「CLI 可驱动、HTTP 复用」：

| 文件 | 内容 | 复用底座 |
|---|---|---|
| `src/cmd/context.cj` | `buildContext`（与 `http/bootstrap.cj` 同口径：`installRoot=工作目录`）、`addCheck`/`addStepWith` 报告辅助 | `core/ctx.cj`、`cli/report.cj` |
| `src/cmd/install_cmd.cj` | `runInstall`（S0~S8 编排+骨架校验+自退役）、`runRollback`（previous/ 最新备份换回 release/）、`runUninstall`（--force 才落删除，保留 logs/.env/media/previous） | `core/orchestrator.cj`、`core/relmgr.cj` |
| `src/cmd/devkit_cmd.cj` | `runDevkitInstall`/`runDevkitVerify`/`runDevkitInit`（与 HTTP 端点共用 `services/devkit/*`，三条判据：只装点名组件 / 探测不到≠通过 / 不伪造成功） | `services/devkit/*` |
| `src/serve/manage.cj` | `runServeManage`：运维管控模式（`--manage serve`），只挂运维端点不推进 S0~S8；`--auto-exit` 观测 runtime 停止后以 0 退出（T056） | `http/routes.cj buildRouter` |

- **磁盘闸口去重**：`http/handlers/devkit.cj` 私有 `freeSpaceMb/diskGate/...` 已上提至 `services/devkit/disk.cj`（公共唯一实现），HTTP 与 CLI 双通道共用，消除同一条规则两处维护的漂移风险。
- **`main.cj` dispatch** 新增 `install` / `devkit install|verify|init` / `rollback` / `uninstall` 分支；`serve` 在 dispatch 前短路到 `runServeManage`；`--json` 与 `--progress=ndjson` 互斥校验。

### B. T053 流式 NDJSON 进度（`src/cli/progress.cj`）

`--progress=ndjson` 逐事件单行输出（start→step→item→final），诊断只走 stderr，末行含 `exitCode/ok`；与 `--json` 互斥（AC-265）。**已知限制（如实记录）**：步骤级事件目前由报告回放在命令结束后按序吐出，要做到「每一步刚发生即吐出」需 `orchestrator.resume` 暴露逐步骤回调，本轮未改 orchestrator 以免引入编译风险，留给下一轮随回调一起补。

### C2. Phase 10 跨工程项代码落地（2026-10-09，本轮）

> AI 仅写代码、**不跑 `cjpm build`**；runtime 与 web-admin 由用户在独立环境编译验证（M-7/M-8）。

**路由前缀关键约定（已用 `farm.config.ts` 复核）**：dev 期 `/api/v1/uctoo/*` → runtime（实际 `javatoarktsapi.uctoo.com`→127.0.0.1），`/api/*`（非 uctoo）→ installer :3000。故两个新运维端点挂在 `/api/v1/uctoo/ops/logs` 与 `/api/v1/uctoo/ops/env`，**代理不误伤**。

**runtime 侧（T054 / T055 / T058）**：
- `src/app/services/ops/runtime_log_service.cj`（新建，T054）：只读、分页、限量；`resolvePath` 把外部 `file` 参数**固定映射**为白名单路径（startup-trace / 主运行日志指针），参数绝不作为文件系统路径 → 目录穿越在结构上不可能；严禁查业务表冒充日志（AC-267/270）。
- `src/app/services/ops/runtime_capability_collector.cj`（新建，T055）：实现唯一采集器（OS/shell/browser/llm/env/skills/extension + 运维块 database/disk），启动即 `collectAndPersist()` 落盘 `./runtime/capabilities.json`；复用 `Config.modelCapabilities`/`modelSupportsVision()`，**严禁列 Node.js**（R-40/R-42）；DB 探测用 `ORM.connection()`，磁盘复用日志目录占用 vs `LRT_LOG_WATERMARK_BYTES` 阈值。
- `src/app/main.cj`：① T058 修复——`/api/v1/health` 的 `chatModel.available` 改按 `ChannelRegistry.shared().getDefault()` 真实状态（disabled/degraded/默认缺失 → false，AC-273）；② T054/T055 接线——`setupRoutes()` 内实例化两服务、启动即 `collectAndPersist()`、`GET /api/v1/uctoo/ops/logs`（解析 `file`/`lines` query）与 `GET /api/v1/uctoo/ops/env`（调 `buildOpsResponse()`）。
- `src/app/middlewares/auth/RequirePermissionMiddleware.cj`：跳过列表新增 `/api/v1/uctoo/ops/`，两个运维端点公开只读。

**web-admin 侧（T052 / T057）**：
- `views/setup.vue`（T057）：状态栏已用 `/api/v1/health` HTTP 判定（N-4 修复，无进程名匹配）；新增「管控后端未运行」横幅 + 「启动管理后端」入口（`POST /api/setup/start-runtime`，installer 外置管控者 R-39）。
- `views/components/EnvironmentCheck.vue`（T057）：去硬编码 nodejs/postgresql/redis，改接 `/api/v1/uctoo/ops/env`，渲染 shell/browser/llm/env/skills/ops(database/disk) 能力项 + 「管控后端未运行」态。
- `views/components/ConfigManagement.vue`（T052+T057）：`isPlaceholder()` 命中 `{{ }}` 统一显示红标「未配置」+ 可编辑补齐入口（OQ-C3）；读改 `/api/v1/uptoo/config/1000/1`、写改 `/api/v1/uctoo/config/batch`，带 `Authorization: Bearer` 鉴权头（原生 fetch 不走 axios 拦截器）。
- `views/components/ServiceMonitor.vue`（T057）：去硬编码 PostgreSQL/Redis，改接 `/api/v1/uctoo/ops/env` 的 ops 块（database 连通、disk 水位）+ runtime 存活。
- `views/components/LogViewer.vue`（T057）：日志读改 `/api/v1/uctoo/ops/logs?file=&lines=500`，渲染 `lines` 文本 + 路径/行数元信息 + 「管控后端未运行」态。

**未改动**：`apps/web-admin/start-installer.bat` 经前置核查已正确（零 Node 依赖、单端口 3000、`success` 严格匹配），本轮不改动。

### C. 文档刷新

- `acceptance/T051-e2e-checklist.md`：§2.2 改用 `ucInstaller.exe --json check-environment`；新增 §2.3~2.5（CLI 通道 / serve --manage / NDJSON）；文末「两处偏差」标记已解决，并把 Phase 10 跨工程项列为仍在外部仓库。
- 本 STATUS.md。

---

## 三、尚待用户执行 / 跨工程项

### 待用户（编译通过后）

1. **重出包**：`installer/` 本次改动（env-check、cmd 包、serve、progress）需重编后重跑
   `powershell -File installer\package.ps1`（自带 `ucInstaller.exe help` 冒烟门禁）。
2. **git 纳管**：`git add apps/agentskills-runtime/installer`（`dist/`、`target/` 已被 `.gitignore` 忽略）。
3. **离线介质**：`media/` 当前为空，离线安装需 `-Media <path>` 显式指定 `agentskills-runtime-*.tar.gz`。

### Phase 10 跨子工程任务（不在 installer 工程内）

> **2026-10-09 更新**：以下跨工程项**代码已全部落盘**，落点文件见下。runtime 侧与 web-admin 侧均**需用户编译验证**（M-7/M-8），AI 不跑 `cjpm build`。

| 编号 | 任务 | 落点 | 状态 |
|---|---|---|---|
| T053 | NDJSON 流式进度 | installer | ✅ 已完成（见 B） |
| T056 | `serve --manage` 承接启停 | installer | ✅ 已完成（见 A） |
| T052 | web-admin 占位符呈现「未配置」 | **web-admin** | ✅ 代码落地：`ConfigManagement.vue`（`isPlaceholder` → 红标「未配置」+ 可编辑补齐入口） |
| T054 | runtime 侧运行日志读取端点 | **runtime src** | ✅ 代码落地：`services/ops/runtime_log_service.cj` + `main.cj` 注册 `GET /api/v1/uctoo/ops/logs`（防穿越、不查业务表） |
| T055 | 环境能力采集器 + 运维检测端点 | **runtime src** | ✅ 代码落地：`services/ops/runtime_capability_collector.cj`（复用 capability spec，禁 Node.js）+ `main.cj` 注册 `GET /api/v1/uctoo/ops/env`（启动即 `collectAndPersist`） |
| T057 | web-admin 管理页适配（修 N-4 进程名判定） | **web-admin** | ✅ 代码落地：四面板改指 runtime（状态复用 `/api/v1/health`、配置复用 `/api/v1/uctoo/config/*`、日志走 T054、环境走 T055、监控/服务走 T055 ops 块）；新增「管控后端未运行」态 + 「启动管理后端」拉起入口；N-4 已由 `setup.vue` 改用 HTTP 健康判定（无进程名匹配） |
| T058 | runtime 侧修复健康「假绿灯」（N-5） | **runtime src** | ✅ 代码落地：`main.cj` `/api/v1/health` 改按 `ChannelRegistry.shared().getDefault()` 真实状态判定 `chatModel.available`（通道失效/禁用/缺失 → false） |

---

## 四、`src/scripts/package_release/main.cj` 与 installer 的关系

### 定性：上游生产者 ↔ 下游消费者，**不是功能重复的两套**

`package_release`（1429 行，`package magic.scripts.package_release`）打的是 **runtime 发行包**；installer 打的是**安装器自身**。两者的接口是那个 tarball：

| 环节 | package_release | installer 消费证据 |
|---|---|---|
| 产物 | `release/agentskills-runtime-<platform>.tar.gz`（tar 根 = `release/`） | `services/media.cj` 找 `*.tar.gz` 并 `tar -xf` 解压（T031） |
| 版本 | 写 `target/release/VERSION`（PS-LRT-02） | `http/handlers/runtime.cj` 读 `releaseDir.join("VERSION")` |
| 入口 | `magic.app.exe` → `bin/agentskills-runtime.exe` | `core/relmgr.cj` 把 `agentskills-runtime.exe` 列为骨架文件 |
| 配置 | 打包 `.env.example`（不打 `.env`） | `package.ps1` 同样拷一份；`envfile_service.cj` 生成 `.env` |

⇒ **两者通过 `release/` 目录布局隐式耦合**：package_release 改布局，installer 不会报错，只会静默装出起不来的包。

### 真正重叠的三块（同一条规则写成两份，有漂移风险）

| # | 重叠内容 | package_release | installer |
|---|---|---|---|
| 1 | **DLL 四路收集 + 同目录部署** | L318~816 | `package.ps1` L147~188（依赖产物 DLL → SDK std → stdx），规则一致 |
| 2 | **OpenSSL 改名** | L857~887（`libcrypto-3.dll`→`libcrypto-3-x64.dll`） | `package.ps1` L192~204（同一条规则 PowerShell 版） |
| 3 | **入口 exe 改名** | L1239：`magic.app.exe`→`agentskills-runtime.exe` | package.ps1 L142：`main.exe`→`ucInstaller.exe` |

第 3 项合理独立；第 1、2 项是同一份知识的两份实现。

### 共同缺口：离线介质链路没有完整性校验

- `package_release` 不产出 SHA256；installer 的 `media.cj` 只解压不校验；而 T032（SDK 下载）要求 SHA256 —— 同链上 SDK 有校验、runtime 包没校验，标准不一致（OQ-D3）。
- **建议**：把「DLL 四路 + OpenSSL 改名」抽成一份共享清单供两侧引用；把 `release/` 布局写成显式契约；让 `package_release` 在写 `VERSION` 同时产出 `SHA256SUMS`，installer 解压前校验。
