# PC 客户端对接原生安装器（ucInstaller）技术设计文档

**文档版本**：v1.0
**创建日期**：2026-10-17
**作者**：sdd-design-writer（SDD 技术设计撰写子 agent）
**状态**：已批准（待落盘实现）
**配套文档**：`spec.md`（REQ-PCI-001~031 / AC-PCI-001~041）、`tasks.md`（T001~T052）、`STATUS.md`（存量判定）

---

# 一、需求与存量功能关系分析

本章对 `spec.md` 的全部 REQ-PCI 需求做「已实现 / 需扩展 / 需新增」三态判定，并逐条给出存量依据（installer 已具备什么、PC 已有什么、缺口在哪）。判定全部基于实地读取的真实代码，行号见附录。

## 1.1 三张对比表

### 表 A：已实现（代码已在磁盘，本工程仅消费或已闭环）

| 需求 | 存量依据 | 说明 |
|---|---|---|
| REQ-PCI-001 同步脚本化 | `apps/agentskills-runtime/scripts/sync-runtime-to-pc.ps1:140-162`（T001） | 复制走脚本，禁止手工 `cp` 已被脚本默认值固化 |
| REQ-PCI-002 SHA256 比对 | `sync-runtime-to-pc.ps1:167-173`（T002） | 大小不同即失败，再比 SHA256，不一致 `exit 1` |
| REQ-PCI-003 三元组落盘 | `sync-runtime-to-pc.ps1:179-190`（T003） | 写 `<archive>.sha256.json`（version/sizeBytes/sha256/syncedAt）+ `SYNCED_VERSION` |
| REQ-PCI-004 版本断言 | `sync-runtime-to-pc.ps1:113-115`（T004硬门，以 cjpm.toml 为准） | 见 §1.2 需扩展项 |
| REQ-PCI-005 installer 入 release/bin | `src/scripts/package_release/main.cj:1368-1384`（T013） | 从 `installer/target/release/bin/main.exe` 拷为 `release/bin/ucInstaller.exe` |
| REQ-PCI-006 不内嵌第二份 | D3 轨道设计（`spec.md` §4.1）+ `runtime-integrator.ts:72-74` | PC 从 tar.gz 解压取用，不另打包；待 §7 显式校验加固 |
| REQ-PCI-010 `--version` | `installer/src/cli/args.cj:85-87`、`installer/src/main.cj:183-195`（T010/GAP-1 已闭环） | 短路打印 `release/VERSION` 首行 `agentskills-runtime <ver>` |
| REQ-PCI-011 `--no-serve` | `installer/src/cli/args.cj:88-90`（T011/GAP-2 已闭环） | 标记已接受，需扩展见 §1.2 |
| REQ-PCI-012 `--json --version` | `installer/src/main.cj:187-194`（T012） | stdout 单行 JSON `{"version":"..."}` |
| REQ-PCI-030 web-admin 入主链路 | `apps/pc-client/package.json:20-21`（T040） | `build` = `build:web-admin && vite build && electron-builder` |
| REQ-PCI-031 副本来源指纹 | `apps/pc-client/scripts/build-web-admin.ps1:80-91` + `verify-web-admin-sync.ps1:30-41`（T041/GAP-4 已闭环） | 写 `WEB-ADMIN-MANIFEST.json`，CI/手工比对 `sourceIndexSha256` |

### 表 B：需扩展（存量已部分落地，但契约/语义需补全或修正）

| 需求 | 缺口 | 扩展点 |
|---|---|---|
| REQ-PCI-004 包内 VERSION 硬断言 | 脚本以 `cjpm.toml` 为权威源，`release/VERSION` 仅作为软告警（`sync-runtime-to-pc.ps1:16-19` 注释） | 应把 tar 内 `release/VERSION` 与 `cjpm.toml` 的一致性升为硬失败，或文档化「权威源=cjpm.toml」并统一两侧格式 |
| REQ-PCI-011 `--no-serve` 透传 | **2026-10-18 复核：已闭环**。消费点分布在 `main.cj` 派发到的子模块，而非 `main.cj` 字面：`core/orchestrator.cj:408`（S6 步骤跳过 runtime 自启动，R-39）、`serve/manage.cj:46`（语义矛盾时 `EXIT_ARGS` 拒绝，不 bind）、`http/bootstrap.cj:24`（无参 HTTP 引导同理拒绝） | 后续若新增会 bind 端口的子命令，须沿用同款「不冒充成功」的提前拒绝，而非静默忽略该开关 |
| REQ-PCI-024 版本取自 installer | PC 现有解析器按 `AGENTSKILLS_RUNTIME_VERSION=` 前缀读（`runtime-integrator.ts:82-96`、`runtime.ts:126-141`），与 runtime/installer 实际写的 `agentskills-runtime <ver>` 格式不符（GAP-6） | 新链路改调 `ucInstaller.exe --version` 并解析 `space` 分隔第二段；旧解析器保留仅作 fallback |
| REQ-PCI-006 隐式契约显式化 | `release/bin/` 布局靠 `runtime-integrator.ts:56-60` 隐式约定 | 解压后增加一次断言：`<binDir>/ucInstaller.exe` 与 `<binDir>/agentskills-runtime.exe` 共存（§7 风险 3） |

### 表 C：需新增（本工程待设计/实现，对应 STATUS 待设计区间）

| 需求 | 落点 | 对应任务 |
|---|---|---|
| REQ-PCI-020 委托 installer 安装 | `apps/pc-client/electron/modules/installer-bridge.ts`（新）+ 改 `setup.ts` | T020~T021 |
| REQ-PCI-021 ndjson 进度呈现 | `installer-bridge.ts` + IPC 推送 | T022 |
| REQ-PCI-022 退出码 0/2/6 区分 | `setup.ts`/渲染层 | T023 |
| REQ-PCI-023 启停经 installer 管控者 | `runtime.ts` 改调 `serve --manage`，旧 `gracefulKill` 降级 fallback | T030~T031 |
| REQ-PCI-025 旧链路开关 | `config.ts` 增开关，默认旧链路 | T024 |
| REQ-PCI-032（GAP-4 重建）web-admin 副本刷新 | 产物 `resources/web-admin/`（T042，代码已落，待执行 `npm run build:web-admin`） | T042 |
| 验收实测 | OQ-D4/OQ-D5 | T050~T052 |

## 1.2 逐条存量详细分析

- **REQ-PCI-001~003（同步层 L1）**：完全已实现。installer 不参与此层；runtime 侧 `sync-runtime-to-pc.ps1` 是全新脚本，但复用 `Get-FileHash -Algorithm SHA256` 与 `cjpm.toml` 解析，无任何 installer 能力重造。PC 侧 `verify-runtime-sync.ps1:26-41` 与 CI `sync-runtime-check.yml`（T005）形成双层守卫。

- **REQ-PCI-004（版本门）**：installer 写 `release/VERSION` 在 `package_release/main.cj:1413-1421`，首行 `agentskills-runtime ${version}`（如 `agentskills-runtime 0.0.29`）。同步脚本的硬版本门基于 `cjpm.toml`（`sync-runtime-to-pc.ps1:76-86`、`113-115`），与 `package_release` 取版本同源（`main.cj:129-148` 的 `getVersionFromCjpm`），因此硬门与发行包版本必然一致。缺口在「包内 VERSION 软校验」——设计建议 Phase 1 收尾时把 `release/VERSION` 首行解析出的版本与 `cjpm.toml` 做交叉硬断言，彻底闭合 REQ-PCI-004 的字面要求。

- **REQ-PCI-005（installer 构件落点）**：`package_release/main.cj:1368-1384` 显式把 `installer/target/release/bin/main.exe` 重命名为 `ucInstaller.exe` 拷入 `release/bin/`。这正是 OQ-D2 选择 `release/bin/` 而非 `installer/` 子目录的收益：PC 用既有 `getRuntimeBinDir()`（`runtime-integrator.ts:72-74`）即可在同一目录取到 `ucInstaller.exe`，零路径改动。

- **REQ-PCI-006（不内嵌第二份）**：D3 轨道决定 PC 安装包不单独打包 installer 二进制，仅通过 `extraResources` 携带 `runtime/*.tar.gz`（`spec.md` §2.3）。风险 3 指出 `runtime-integrator.ts:56-60` 的布局是隐式契约，本设计在 §7 增加显式校验：解压后断言 `bin/ucInstaller.exe` 存在且与 `agentskills-runtime.exe` 同目录。

- **REQ-PCI-010~012（installer 接口补齐）**：installer 现有子命令全表由 `main.cj:22-25` 的 `knownHead` 白名单定义：`check-environment` / `install` / `devkit` / `db` / `seed` / `rollback` / `uninstall`，外加 `serve --manage`（`main.cj:210-212`）与无参引导服务。退出码常量 `EXIT_OK=0`、`EXIT_ARGS=2`、`EXIT_MANUAL=6` 从 `args.cj:10` 导入，与 `spec.md` §2.4 语义一致。`--version` 在 `main.cj:183-195` 短路处理，先 `readInstallerVersion()`（`main.cj:65-83`，候选 `<cwd>/release/VERSION`、`<cwd>/../VERSION`、`cwd/VERSION`，返回首行如 `agentskills-runtime 0.0.29`），`--json` 时输出 `{"version": "..."}`。三项 GAP-1/GAP-2 已闭环。

- **REQ-PCI-020（委托安装）**：PC 现状 `setup.ts:20-99` 的 `executeDatabaseStep` 在嵌入式分支调用 `pgManager.initialize()`（`setup.ts:59`），并调用 `dependencyManager.detectSystemPostgresql()`（`setup.ts:38`）。这与 installer 的 S0~S8 编排 + `envfile_service` + `bcrypt_admin` 完全重叠。**禁止重造**：新链路由 `installer-bridge.ts` 调用 `ucInstaller.exe install`（或 `check-environment` + 分步），DB 与初始化彻底交给 installer；`setup.ts` 仅保留 `pgManager` 调用作为 fallback（受开关控制）。

- **REQ-PCI-021（ndjson 进度）**：installer 的 NDJSON 流由 `main.cj:221-227` 定义调用顺序：`emitStart(joinCommand)` → `dispatch(parsed)`（内部经 `emitReportEvents` 产出 step/item 事件）→ `emitDiagnosticsStderr(report)`（诊断走 stderr，不污染 stdout）→ `emitFinal(report)`（末行含终态与 `exitCode/ok`）。PC 侧 `installer-bridge.ts` 只需按行解析 stdout 的 NDJSON，逐事件经 IPC 推到渲染层，`--progress=ndjson` 与 `--json` 互斥（`main.cj:214-218`）。

- **REQ-PCI-022/023（退出码与启停外置）**：`runtime.ts:275-299` 的 `stop()` 当前用 `ProcessUtils.gracefulKill(this.process.pid, 5000)`（`runtime.ts:284`）直接杀进程，属 R-PC-3 违规主路径。新链路改由 installer 管控者 `serve --manage` 承担启停（`main.cj:210-212`），`runtime.ts` 的旧 `spawn`/`gracefulKill` 仅作为「installer 管控者不可用时」的 fallback（T031）。退出码 0/2/6 映射：`runtime.ts` 与渲染层按 installer 末行 `exitCode` 区分——0 成功、2 提示用法、6 显示「需人工介入」，绝不把 6 渲染成成功（R-PC-2）。

- **REQ-PCI-024（版本来源）**：GAP-6 实证——`package_release/main.cj:1415` 写 `agentskills-runtime ${version}`，installer `readInstallerVersion` 返回该首行；而 PC 的 `runtime-integrator.ts:82-96`（按 `AGENTSKILLS_RUNTIME_VERSION=` 前缀）与 `runtime.ts:126-141`（同前缀）永远解析不到，`getInstalledVersion()` 恒返回 `null`，UI 版本恒为空。新链路改为 `ucInstaller.exe --version`（REQ-PCI-010 已实现），解析 `space` 分隔第二段得 `0.0.29`；旧解析器保留为 fallback。

- **REQ-PCI-030/031（web-admin 副本治理）**：`package.json:21` 已把 `build:web-admin` 链入 `build` 主链路（T040 已实现）。`build-web-admin.ps1:80-91` 写 `WEB-ADMIN-MANIFEST.json`（`schema="web-admin-replica/v1"`、`sourceDir`、`sourcePackageVersion`、`sourceIndexSha256`、`builtAt`、`note`）；`verify-web-admin-sync.ps1:30-41` 重算 `apps/web-admin/web/dist/index.html` 的 SHA256 与清单比对，漂移即 `exit 1`。T042 重建待用户执行 `npm run build:web-admin` 把 Phase 10 四面板 + 新 favicon 同步进 `resources/web-admin/`。

---

# 二、增量设计方案

## 2.1 实现模型

采用 `spec.md` §4.3 的三层可独立交付、可回退模型，自底向上：

- **L1 同步层（已实现）**：runtime→PC 的 tar.gz 同步脚本化 + SHA256 校验 + 版本门 + CI 守卫，消除 39 MB 漂移。复用 `Get-FileHash` 与 `cjpm.toml`，不依赖 installer。
- **L2 委托层（待新增）**：PC 安装向导经 `installer-bridge.ts` 调用 `ucInstaller.exe install`，消费 `--progress=ndjson`，按退出码 0/2/6 区分呈现。installer 已具备 S0~S8 编排、envfile 通道、seed 导入，**PC 只做桥接 + 呈现**，不自建 PG、不自己生成 `.env`（改由 installer 的 envfile 通道产出）。
- **L3 托管层（待新增）**：runtime 启停经 installer 管控者 `serve --manage`；版本显示改取 `ucInstaller.exe --version`。旧 `runtime.ts` 启停逻辑降级为 fallback。

**铁律 9（复用优先）**：installer 已有的 CLI 子命令、orchestrator S0~S8、envfile 通道、ndjson 进度、退出码语义一律直接复用；PC 禁止重造其中任何一项。本设计对每条需求先判定 已实现/需扩展/需新增（见 §1.1），新增项仅限于「PC 侧桥接、呈现、托管调用、开关与校验」。

## 2.2 接口设计（概要，详见第七章）

- installer CLI 契约：`ucInstaller.exe [--version][--no-serve][--json][--progress=ndjson] <subcmd>`，子命令白名单 `main.cj:22-25`。
- PC `installer-bridge.ts` 契约：暴露 `locateInstaller()`、`runInstall(opts)`、`runCheckEnvironment()`、`getVersion()`、`stopRuntime()`，内部均以 `child_process.spawn` 调 `ucInstaller.exe` 并解析 stdout。
- ndjson 流形：start → step → item → final，末行 `exitCode/ok`，诊断走 stderr。
- 退出码：0 成功 / 2 参数错误（PC 提示用法）/ 6 待实现或需人工介入（PC 提示「需人工介入」）。

## 2.3 数据模型（概要，详见第六章）

- 同步校验文件 `<archive>.sha256.json`：version / platform / sizeBytes / sha256 / syncedAt / source。
- `SYNCED_VERSION`：单行版本锚点。
- `WEB-ADMIN-MANIFEST.json`：web-admin 副本来源指纹。

## 2.4 进度与可观测

所有安装/初始化进度来自 installer 的 NDJSON 流（`main.cj:221-227`），PC 经 IPC 实时推送 step/item 事件到渲染层，杜绝「盲等」。诊断信息走 stderr（`emitDiagnosticsStderr`），不在 stdout JSON/NDJSON 中污染。版本、校验和、副本指纹均落盘可查。

## 2.5 人在回路

安装向导的「数据库模式选择（embedded/external）」「AI provider/apiKey 录入」仍由 PC UI 采集，通过 installer 的 envfile 通道或 `install` 参数传入；遇到退出码 6（需人工介入）时，PC 如实展示 installer 的诊断文本并等待用户处理，不自动降级、不冒充成功（R-PC-2）。

## 2.6 防回退约束（概要）

禁止复现的问题与判据见第十二章。要点：环境探测唯一实现归 installer（R-PC-1）、禁止冒充成功（R-PC-2）、启停外置经 installer（R-PC-3）、439MB 同步快筛、tarball 不入库靠校验文件发现版本、release/bin 布局升为显式校验。

---

# 三、系统架构

## 3.1 架构图

```
┌──────────────────────────────────────────────────────────────────────┐
│                         PC 客户端 (apps/pc-client)                    │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Electron 主进程                                                 │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────────────────┐  │  │
│  │  │ setup.ts    │  │ runtime.ts   │  │ webadmin-server.ts     │  │  │
│  │  │ (L2 委托)   │  │ (L3 托管)    │  │ (resources/web-admin) │  │  │
│  │  └──────┬──────┘  └──────┬───────┘  └───────────────────────┘  │  │
│  │         │ 开关(config)    │                                      │  │
│  │  ┌──────▼───────────────▼───────────────────────────────────┐  │  │
│  │  │ installer-bridge.ts  (新增 L2/L3 桥接层)                  │  │  │
│  │  │  locateInstaller() / runInstall() / getVersion() /       │  │  │
│  │  │  stopRuntime()  —— 解析 NDJSON、退出码 0/2/6              │  │  │
│  │  └───────────────────────┬──────────────────────────────────┘  │  │
│  │  旧链路 fallback: pgsql.ts / dep-manager.ts / env-generator.ts  │  │
│  └───────────────────────────┼───────────────────────────────────┘  │
└───────────────────────────────┼──────────────────────────────────────┘
                                │ spawn / --progress=ndjson / --version
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│   runtime 发行包 (release/bin/)  —— 解压自 tar.gz (D1+D3 轨道)          │
│   ┌────────────────────┐   ┌─────────────────────────────────────┐  │
│   │ agentskills-runtime│   │ ucInstaller.exe  (installer 构件)    │  │
│   │   .exe              │   │  CLI: install/check-environment/... │  │
│   │                    │   │  serve --manage (L3 管控者)          │  │
│   │  S0~S8 orchestrator│   │  envfile 通道 / seed / ndjson 进度   │  │
│   └────────────────────┘   └─────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
        ▲                                          │
        │ sync-runtime-to-pc.ps1 (L1, 已实现)      │ 共享 DLL / runtimeHome
        │ 大小+SHA256+版本门                        ▼
┌──────────────────────────────────────────────────────────────────────┐
│   runtime 工程 (apps/agentskills-runtime)                             │
│   src/scripts/package_release/main.cj  → release/agentskills-*.tar.gz │
│   scripts/sync-runtime-to-pc.ps1        → PC resources/runtime/       │
└──────────────────────────────────────────────────────────────────────┘

L1 = 同步层(已实现)  L2 = 委托层(待新增)  L3 = 托管层(待新增)
```

三层职责边界：L1 负责「发行包到 PC 的资源同步与校验」；L2 负责「安装/初始化委托 installer 并呈现进度」；L3 负责「runtime 进程生命周期外置到 installer 管控者」。installer 自身是「已实现侧」，PC 是「待集成侧」，二者通过 `release/bin/` 同目录共享 DLL 与二进制。

## 3.2 模块划分

| 模块 | 工程/文件 | 状态 | 职责 |
|---|---|---|---|
| 同步脚本 | `apps/agentskills-runtime/scripts/sync-runtime-to-pc.ps1` | 已实现 | L1 复制 + SHA256 + 版本门 + 校验文件 |
| 同步校验 | `apps/pc-client/scripts/verify-runtime-sync.ps1` + `sync-runtime-check.yml` | 已实现 | L1 CI 守卫 |
| installer 构件 | `installer/target/release/bin/main.exe` → `release/bin/ucInstaller.exe` | 已实现（T013） | L2/L3 执行体 |
| installer CLI | `installer/src/main.cj` + `cli/args.cj` | 已实现（T010~T014） | `--version/--no-serve/--json/--progress` |
| 桥接层 | `apps/pc-client/electron/modules/installer-bridge.ts` | 待新增 | L2/L3 调 installer、解析 NDJSON/退出码 |
| 安装向导 | `apps/pc-client/electron/modules/setup.ts` | 待扩展 | 新链路改调 bridge，旧链路保留 |
| 运行时管理 | `apps/pc-client/electron/modules/runtime.ts` | 待扩展 | 启停改经 installer，旧 kill 降级 |
| 依赖管理 | `apps/pc-client/electron/modules/dep-manager.ts` | 待扩展 | 探测结果降为提示，判据归 installer |
| 版本管理 | `apps/pc-client/electron/modules/runtime-version.ts` + `runtime-version-detector.ts` + `runtime-integrator.ts` | 待扩展 | 版本改取 installer（修 GAP-6） |
| web-admin 副本 | `scripts/build-web-admin.ps1` + `verify-web-admin-sync.ps1` | 已实现 | L1/G-5 指纹 + 过期检出 |

## 3.3 组件交互

- **L1 同步**：`package_release`（runtime）→ 产出 `release/agentskills-runtime-win-x64.tar.gz` + 内部 `release/VERSION`；`sync-runtime-to-pc.ps1` 复制并比对大小/SHA256，写 `<archive>.sha256.json` 与 `SYNCED_VERSION`；PC 构建时 `verify-runtime-sync.ps1` 校验。
- **L2 委托**：`setup.ts` → `installer-bridge.runInstall(opts)` → spawn `ucInstaller.exe install --progress=ndjson [--no-serve]` → 解析 stdout NDJSON 经 IPC 到渲染层；末行 `exitCode` 决定 AC-PCI-022 呈现。
- **L3 托管**：`runtime.ts.start/stop` → `installer-bridge.startRuntime/stopRuntime` → spawn `ucInstaller.exe serve --manage`（启停指令经管控者）；管控者不可用时回退旧 `spawn/gracefulKill`。
- **版本**：`runtime-version.ts.getCurrentVersion` → 新链路 `installer-bridge.getVersion()`（`ucInstaller.exe --version`）；旧链路 `runtimeManager.getInstalledVersion()`（保留 fallback，需修 GAP-6 解析）。

---

# 四、详细设计（按 Phase 展开）

## 4.1 Phase 1：同步层（L1，已实现，REQ-PCI-001~004 / AC-PCI-001~004）

- **T001 复制**：`sync-runtime-to-pc.ps1:140-162`，默认 `RuntimeRoot` = 脚本上级（runtime 工程），`PcRoot` 默认指向 `apps/pc-client`（见 §12.2）；先比大小、大小不同再比 SHA256，相同则跳过复制。
- **T002 SHA256**：`:167-173`，复制后比对 `sizeBytes` 与 `sha256`，任一不符 `Fail`（exit 1）。
- **T003 三元组**：`:179-190`，写 `<archive>.sha256.json`（artifact/version/platform/sizeBytes/sha256/syncedAt/source）与 `SYNCED_VERSION`（单行版本）。
- **T004 版本门**：`:113-115` 以 `-ExpectedVersion` 做硬失败；`:16-19` 注释明确 `cjpm.toml` 为权威源，`release/VERSION` 仅软告警。设计建议闭环：在 Phase 1 收尾把 tar 内 `release/VERSION` 首行解析版本与 `cjpm.toml` 交叉硬断言（修 REQ-PCI-004 字面要求）。
- **T005 CI 守卫**：`verify-runtime-sync.ps1:26-41` + `sync-runtime-check.yml`（Windows runner，PR/push 到 `resources/runtime/**` 触发），漂移即失败。

## 4.2 Phase 2：installer 接口补齐（已实现，REQ-PCI-010~012 / AC-PCI-010~012）

- **T010 `--version`**：`args.cj:85-87` 置 `parsed.version`；`main.cj:183-195` 短路，`readInstallerVersion()`（`main.cj:65-83`）返回 `release/VERSION` 首行（如 `agentskills-runtime 0.0.29`），兜底 `0.0.1 (VERSION file not found)`。
- **T011 `--no-serve`**：`args.cj:88-90` 置 `parsed.noServe`。**需扩展**：当前 `main.cj` 未在子命令路径消费该字段；CLI 子命令（`install`/`check-environment`）本就不监听端口，故 AC-PCI-011 在 CLI 模式天然成立；`serve --manage`（`main.cj:210-212`）需把 `noServe` 透传以跳过端口绑定，作为双保险。
- **T012 `--json --version`**：`main.cj:187-194` 输出 `{"version":"..."}` 单行 JSON。
- **T013 installer 入 bin**：`package_release/main.cj:1368-1384`。
- **T014 printUsage**：`main.cj:143-173` 已纳入 `--version --no-serve` 与全部子命令，并声明「未识别/未接入以 exitCode 6 如实报告」。

## 4.3 Phase 3：PC 委托层（L2，待新增，REQ-PCI-020~025 / AC-PCI-020~025）

- **T020 installer-bridge.ts（新增）**：`locateInstaller()` 复用 `runtime-integrator.ts:72-74` 的 `getRuntimeBinDir()` 拼接 `ucInstaller.exe`；`runInstall(opts)` 以 `spawn(binDir/ucInstaller.exe, ['install','--progress=ndjson','--no-serve', ...opts])` 启动，收集 stdout 逐行 `JSON.parse` 为 NDJSON 事件；`getVersion()` 调 `ucInstaller.exe --version` 解析版本。
- **T021 setup.ts 改调**：`executeDatabaseStep`（`setup.ts:20-99`）嵌入式分支不再 `pgManager.initialize()`（`setup.ts:59`），改 `await installerBridge.runInstall(...)`；外部 PG 模式仍由 PC 采集连接信息后传给 installer。受 `config.ts` 开关控制（T024）：开关关闭时走旧 `pgManager` 路径。
- **T022 进度呈现**：`installer-bridge` 解析 NDJSON 的 step/item 事件，经 IPC `webContents.send('install:progress', event)` 推到渲染层，实现逐步显示（AC-PCI-021）。
- **T023 退出码区分**：`runInstall` 读取末行 `emitFinal` 的 `exitCode`：`0` → 成功；`2` → 渲染「参数错误，请检查用法」；`6` → 渲染「需人工介入」并展示 stderr 诊断文本（AC-PCI-022），绝不显示为成功。
- **T024 旧链路开关**：`config.ts` 增 `useInstallerForSetup`（默认 `false`，验收通过后再切 `true`），保证任一新链路失败可回退（AC-PCI-025）。
- **T025 版本改取 installer**：`runtime-version.ts:44-46` 的 `getCurrentVersion` 新链路改 `installerBridge.getVersion()`；旧 `runtimeManager.getInstalledVersion()`（`runtime.ts:126-141`）保留为 fallback，并修 GAP-6 解析（按 `space` 取第二段，而非 `AGENTSKILLS_RUNTIME_VERSION=` 前缀）。

## 4.4 Phase 4：PC 托管层（L3，待新增，REQ-PCI-023 / AC-PCI-023）

- **T030 runtime.ts 启停外置**：`runtime.ts:184-273` 的 `start()` 与 `:275-299` 的 `stop()` 改为优先经 `installer-bridge.stopRuntime()/startRuntime()`，后者 spawn `ucInstaller.exe serve --manage` 并把启停指令交给 installer 管控者（R-PC-3，`main.cj:210-212`）。
- **T031 旧逻辑降级 fallback**：当 installer 管控者不可用时（spawn 失败/二进制缺失），回退到现有 `spawn`/`ProcessUtils.gracefulKill`（`runtime.ts:284`）作为兜底，保证可回退。
- **T032 dep-manager 降级**：`dep-manager.ts:209-260`（`detectSystemPostgresql`）、`:262-283`（`checkAll`）的探测结果不再作为安装判据，仅作为 UI 提示；环境判定的唯一实现归 installer 的 `services/envcheck.cj`（R-PC-1）。

## 4.5 Phase 5：web-admin 副本治理（已基本落地，REQ-PCI-030~031 / AC-PCI-030~031）

- **T040 入主链路**：`package.json:21` 已落（`build:web-admin && vite build && electron-builder`）。
- **T041 来源指纹**：`build-web-admin.ps1:80-91` 写 `WEB-ADMIN-MANIFEST.json`（字段见第六章）；`verify-web-admin-sync.ps1:30-41` 比对 `sourceIndexSha256`。
- **T042 重建副本**：待用户执行 `npm run build:web-admin`，把 Phase 10 四面板 + 新 favicon + 官网修复同步进 `resources/web-admin/`。

## 4.6 Phase 6：实测验收（REQ-PCI-040~041 / AC-PCI-040~041）

- **T050 OQ-D4**：PC 安装后首登主 agent 自动登录实测，失败则升级 installer 复用优先级为「必须」。
- **T051 OQ-D5**：冷启动 ≤60 s 实测（seed ≈0.87 MB + 本地 PG，预估秒级增量）。
- **T052 端到端**：同步脚本 → 出包 → PC 安装 → 首登 → 冷启动计时，串起 Phase 1~5。

---

# 五、数据设计

## 5.1 同步校验文件 schema（REQ-PCI-003，落盘于 `resources/runtime/<archive>.sha256.json`）

由 `sync-runtime-to-pc.ps1:179-190` 生成，字段如下（均为实测字段，非编造）：

```json
{
  "artifact": "agentskills-runtime-win-x64.tar.gz",
  "version": "0.0.29",
  "platform": "win-x64",
  "sizeBytes": 439929547,
  "sha256": "<小写十六进制>",
  "syncedAt": "2026-10-17T12:00:00+08:00",
  "source": "apps/agentskills-runtime/release"
}
```

配套 `SYNCED_VERSION`：单行纯文本版本号（如 `0.0.29`）。CI 守卫 `verify-runtime-sync.ps1:29-38` 重算 `sizeBytes`/`sha256` 与文件比对，任一不符即 `Fail`。

## 5.2 WEB-ADMIN-MANIFEST.json schema（REQ-PCI-031，落盘于 `resources/web-admin/`）

由 `build-web-admin.ps1:80-91` 生成（`ConvertTo-Json -Compress`）：

```json
{
  "schema": "web-admin-replica/v1",
  "sourceDir": "apps/web-admin/web",
  "sourcePackageVersion": "1.0.0",
  "sourceIndexSha256": "<dist/index.html 的 SHA256，小写>",
  "builtAt": "2026-10-17T12:00:00Z",
  "note": "Staleness is detected by comparing sourceIndexSha256 against a recomputed SHA256 of apps/web-admin/web/dist/index.html"
}
```

`verify-web-admin-sync.ps1:30-41` 重算 `apps/web-admin/web/dist/index.html` 的 SHA256 与 `sourceIndexSha256` 比对，漂移即 `exit 1`。注意 `sourcePackageVersion` 是 web-admin 模板静态 `1.0.0`，不随代码变化；真实溯源指纹是 `sourceIndexSha256`（Vite 资源哈希使 `index.html` 内容随代码变化），此点已在 `build-web-admin.ps1:16-18` 注释说明。

## 5.3 包内 VERSION（ installer 与 runtime 同源）

`package_release/main.cj:1413-1421` 写入 `release/VERSION` 首行 `agentskills-runtime ${version}`（如 `agentskills-runtime 0.0.29`），installer `readInstallerVersion`（`main.cj:65-83`）返回该首行。`--version` 输出即 `agentskills-runtime 0.0.29`，与 AC-PCI-010 要求一致。

---

# 六、接口设计

## 6.1 installer CLI 契约

调用形态：`ucInstaller.exe [全局开关] <子命令>`

全局开关（源自 `installer/src/cli/args.cj:8-37`，均为实测字段）：
- 元操作：`--version`（`:85`）、`--no-serve`（`:88`）、`--help/-h`（`:100`）
- 输出形态：`--json`（`:65`）、`--progress=ndjson`（`:91-99`，仅支持 `ndjson`）
- 行为：`--truthful`（`:67`）、`--offline`（`:69`）、`--force`（`:71`）、`--rollback`（`:73`）、`--with-devkit`（`:75`）、`--devkit-only`（`:77`）、`--auto-exit`（`:79`）、`--system-env`（`:81`）、`--manage`（`:83`）
- 取值：`--port`、`--sdk-path`、`--source-dir`、`--db`、`--user`、`--password`

子命令白名单（`main.cj:22-25` `knownHead`）：`check-environment` / `install` / `devkit install|verify|init` / `db export` / `seed apply|verify` / `rollback` / `uninstall`；外加 `serve --manage`（`main.cj:210-212`）、无参引导服务。未命中白名单 → exit 2；命中未接入 → exit 6（`main.cj:40-59`）。

退出码（`args.cj:10` 导入 `EXIT_OK/EXIT_ARGS/EXIT_MANUAL`）：
- `0` 成功
- `2` 参数错误 / 未知命令（PC 应提示用法）
- `6` 待实现或需人工介入（PC 应提示「需人工介入」，禁止显示为成功）

## 6.2 PC installer-bridge.ts 契约（新增，T020）

| 方法 | 调 installer | 说明 |
|---|---|---|
| `locateInstaller()` | — | 复用 `runtime-integrator.ts:72-74` `getRuntimeBinDir()` + `ucInstaller.exe` |
| `runInstall(opts)` | `ucInstaller.exe install --progress=ndjson --no-serve [opts]` | 返回 NDJSON 事件流 + 末行 exitCode |
| `runCheckEnvironment()` | `ucInstaller.exe check-environment --progress=ndjson --no-serve` | 环境自检 |
| `getVersion()` | `ucInstaller.exe --version` | 解析 `space` 第二段为版本号 |
| `startRuntime()` / `stopRuntime()` | `ucInstaller.exe serve --manage` | L3 启停经管控者 |

bridge 内部用 `child_process.spawn`，stdout 逐行 `JSON.parse`；`--progress=ndjson` 与 `--json` 互斥（`main.cj:214-218`），故进度用 NDJSON、版本用 `--version` 明文/JSON 各取所需。

## 6.3 NDJSON 事件流形（start → step → item → final）

依据 `main.cj:221-227` 调用顺序，stdout 流形为：
1. `emitStart(command)` —— 起始事件，含 command 字段；
2. `dispatch(parsed)` 内部 `emitReportEvents(report)` —— 逐 step/item 事件（含 phase/step/item/status 等字段，具体字段定义见 `installer/src/cli/report.cj` 的 `emit*` 实现，本设计以 `main.cj` 调用顺序为准定义流形，不编造其字段名）；
3. `emitDiagnosticsStderr(report)` —— 诊断信息走 **stderr**，不污染 stdout（`main.cj:226`）；
4. `emitFinal(report)` —— 末行终态事件，含 `exitCode` 与 `ok` 标志（`main.cj:227`）。

PC 渲染层以末行 `exitCode` 决定 AC-PCI-022 呈现；中间 step/item 经 IPC 实时推送（AC-PCI-021）。

## 6.4 升级/回退接口

`runtime-version.ts` 的 `upgrade()`（`:94-160`）仍走 SDK `downloadRuntime`；本工程不改动升级通道，仅改「当前版本展示」来源（T025）。回退靠 `config.ts` 开关（T024）与 `runtime.ts` 旧逻辑（T031），均为可回退双轨。

---

# 七、安全设计

- **R-PC-1 环境探测唯一实现（§十二 防回退）**：installer `services/envcheck.cj` 为唯一判据；PC `dep-manager.ts:209-260` 探测结果降为提示（T032），不再作为安装/启动的判据来源。
- **R-PC-2 不冒充成功（§十二 防回退）**：退出码 6 必须如实显示「需人工介入」；`--truthful` 语义（`main.cj:233-235`）启用时不可达即非成功，禁止静默降级。
- **校验防篡改**：同步脚本比对 SHA256（`sync-runtime-to-pc.ps1:167-173`），installer 侧 `package_release` 生成 `SHA256SUMS`（`main.cj:1479-1481`）供解压后复核，介质被篡改即拒绝。
- **敏感信息不入库**：`.env` 不随发行包打包（`main.cj:1404-1407`），`ssl/` 仅建目录不含证书（`main.cj:1002-1068`）；PC 的 `.env` 由 installer envfile 通道或 PC `env-generator.ts` 在本地生成。
- **web-admin 副本可信**：`WEB-ADMIN-MANIFEST.json` 指纹防止过期副本被静默发布（`verify-web-admin-sync.ps1`）。

---

# 八、性能设计

- **439 MB tarball 快筛（风险 1）**：`sync-runtime-to-pc.ps1:146-157` 先比 `sizeBytes`（O(1) 元数据），大小相同才比 SHA256；大小不同直接判定需复制/失败，省去一次全量哈希。CI 守卫 `verify-runtime-sync.ps1:29-30` 同样先比大小再比哈希。
- **校验文件缓存**：`<archive>.sha256.json` 与 `SYNCED_VERSION` 落盘，重复构建时无需重算；`needCopy` 判定（`:148-157`）基于既有校验文件跳过无变化复制。
- **installer 侧 SHA256SUMS 内存安全**：`package_release/main.cj:39-127` 改用 1 MiB 分块流式哈希（`hashFileSha256Hex`），避免整文件读入堆导致 OOM（439 MB 级文件实测会撑爆内存），并对 `release/` 递归收集（`collectReleaseFiles`，修复 `Directory.walk` 非递归缺陷）。
- **NDJSON 流式进度**：安装进度逐事件推送，避免 PC 端「盲等」整段完成（AC-PCI-021），无额外轮询开销。

---

# 九、部署与运维

- **构建顺序**：runtime `cjpm build` → `package_release`（产出 tar.gz + `ucInstaller.exe` 入 bin，T013）→ `sync-runtime-to-pc.ps1` 同步到 PC → PC `npm run build`（已含 `build:web-admin`，T040）→ 出包。
- **CI 守卫**：PC 侧 `sync-runtime-check.yml` 在 `resources/runtime/**` 变更时校验 tarball 校验和（T005）；web-admin 副本过期由 `verify-web-admin-sync.ps1` 在构建/PR 中检出（T041）。
- **运维端点**：runtime 运行期经 installer `serve --manage`（`main.cj:210-212`）暴露运维端点，PC `webadmin-server.ts:28-30` 仍从 `resources/web-admin` 提供管理界面，二者解耦。
- **回退运维**：若新链路异常，将 `config.ts` 开关 `useInstallerForSetup` 置 `false` 即回退旧链路（T024）；installer 管控者不可用时 `runtime.ts` 自动降级旧 kill（T031）。

---

# 十、风险与对策

| 风险 | 描述 | 对策 |
|---|---|---|
| 风险 1（439 MB I/O） | 全量 SHA256 耗 I/O | 先比大小再比 SHA256（`sync-runtime-to-pc.ps1:146-157`），校验文件缓存 |
| 风险 2（tarball 不入库） | PC gitcode 仓库 `resources/runtime/` 被 `.gitignore` 排除，版本差只能靠校验文件发现（`STATUS.md` §二） | 强化 REQ-PCI-003/004：`<archive>.sha256.json` + `SYNCED_VERSION` + 版本门硬失败；CI 守卫 `sync-runtime-check.yml` |
| 风险 3（release/bin 布局隐式契约） | `runtime-integrator.ts:56-60` 静默找二进制，布局变动即找不到 | 解压后显式断言 `bin/ucInstaller.exe` 与 `agentskills-runtime.exe` 共存；CI 增加布局校验 |
| GAP-6（VERSION 格式不一致） | PC 按 `AGENTSKILLS_RUNTIME_VERSION=` 解析；runtime/installer 写 `agentskills-runtime <ver>` | T025 改调 `ucInstaller.exe --version` 并解析空格第二段；旧解析器修前缀或保留 fallback |
| GAP-5（OQ-D4/D5 未实测） | 首登自动登录、冷启动 ≤60 s 仅静态取证 | T050~T052 实测，失败则升级 installer 复用优先级 |

---

# 十一、防回退约束

逐条列出「禁止复现的问题 + 判据」，覆盖 `spec.md` §7 全部约束：

1. **R-PC-1 环境探测唯一实现归 installer**
   - 禁止复现：PC `dep-manager.ts:209-260` 的 `detectSystemPostgresql`/`checkAll` 再次成为安装或启动的判据来源。
   - 判据：T032 后，`setup.ts` 与 `runtime.ts` 不再读取 `dependencyManager` 的 `ready/allReady` 作为分支条件；其输出仅用于 UI 提示。`grep` 确认 `dep-manager` 的判据消费点已移除或仅 log。

2. **R-PC-2 禁止冒充成功 / 静默降级**
   - 禁止复现：installer 退出码 6 被渲染为「成功」；任何步骤失败被吞掉。
   - 判据：T023 渲染层对 exitCode 6 必须显示「需人工介入」并展示 stderr 诊断；`--truthful` 启用时不可达即非成功（`main.cj:233-235`）。单测/手动构造 exit 6 场景验证（AC-PCI-022）。

3. **R-PC-3 启停外置经 installer 管控者**
   - 禁止复现：`runtime.ts` 的 `spawn`/`gracefulKill`（`runtime.ts:232-263`、`:284`）作为 runtime 启停的**主路径**。
   - 判据：T030/T031 后，主路径改 `installer-bridge.startRuntime/stopRuntime` → `ucInstaller.exe serve --manage`；旧 kill 仅当 installer 管控者 spawn 失败时出现（代码分支可见 try/catch fallback）。

4. **风险 1（439 MB 同步 I/O）**
   - 禁止复现：同步脚本每次全量重算 SHA256 而无大小快筛。
   - 判据：`sync-runtime-to-pc.ps1:146-157` 保留「先比大小、再比 SHA256」逻辑；移除须有等价快筛替代，否则不得删。

5. **风险 2（tarball 不入库 → 版本只能靠校验文件）**
   - 禁止复现：移除 `<archive>.sha256.json` / `SYNCED_VERSION` 或版本门，导致版本漂移无感知。
   - 判据：`verify-runtime-sync.ps1:26-41` 与 `sync-runtime-check.yml` 持续存在于构建/CI 中；版本门硬失败逻辑（`sync-runtime-to-pc.ps1:113-115`）不得降级为告警。

6. **风险 3（release/bin 布局从隐式升显式）**
   - 禁止复现：`runtime-integrator.ts:56-60` 静默找不到二进制且无报错。
   - 判据：解压/集成流程增加显式断言 `bin/ucInstaller.exe` 存在且与 `agentskills-runtime.exe` 同目录；缺失时明确报错而非静默 `extracted=false`。

---

# 十二、附录

## 12.1 引用的真实实现文件（路径 + 服务需求/Phase）

**installer 侧（已实现侧）**
- `installer/src/main.cj:22-25` — 子命令白名单 `knownHead`（接口设计 §6.1）
- `installer/src/main.cj:65-83` — `readInstallerVersion` 返回 `release/VERSION` 首行（REQ-PCI-010/024）
- `installer/src/main.cj:143-173` — `printUsage` 含 `--version/--no-serve` 与子命令（T014）
- `installer/src/main.cj:177-241` — `main`：`--version` 短路(:183-195)、`serve --manage`(:210-212)、ndjson 流形(:221-227)、退出码(:240)（REQ-PCI-010~012/021/023）
- `installer/src/cli/args.cj:8-37` — `CliArgs` 全部开关字段 + 退出码常量导入（§6.1、退出码 0/2/6）
- `installer/src/cli/args.cj:65-141` — `applyOption`：`--json`(:65)、`--version`(:85-87)、`--no-serve`(:88-90)、`--progress=ndjson`(:91-99)（REQ-PCI-010~012）

**runtime 侧（同步与构件生产）**
- `src/scripts/package_release/main.cj:1368-1384` — T013 把 `ucInstaller.exe` 放入 `release/bin/`（REQ-PCI-005）
- `src/scripts/package_release/main.cj:1413-1421` — 写 `release/VERSION` 首行 `agentskills-runtime <ver>`（REQ-PCI-010/024、GAP-6 源头）
- `src/scripts/package_release/main.cj:1479-1481` — 生成 `SHA256SUMS`（安全/性能）
- `scripts/sync-runtime-to-pc.ps1:100-195` — T001~T004 同步/SHA256/三元组/版本门（REQ-PCI-001~004，L1）

**PC 客户端侧（待集成侧，真实路径 `apps/pc-client/...`）**
- `apps/pc-client/electron/modules/runtime-integrator.ts:56-60` — `isRuntimeExtracted` 路径约定（风险 3、REQ-PCI-006）
- `apps/pc-client/electron/modules/runtime-integrator.ts:68-74` — `getReleaseDir`/`getRuntimeBinDir`（OQ-D2 零改动发现、T020）
- `apps/pc-client/electron/modules/runtime-integrator.ts:82-96` — `checkIntegrationStatus` 按 `AGENTSKILLS_RUNTIME_VERSION=` 解析（GAP-6）
- `apps/pc-client/electron/modules/setup.ts:20-99` — `executeDatabaseStep` 调 `pgManager.initialize()`(:59)、`detectSystemPostgresql`(:38)（REQ-PCI-020/021、R-PC-1）
- `apps/pc-client/electron/modules/setup.ts:120-132` — `completeSetup` 调 `envGenerator.generateForRuntime()`（L2 待移交）
- `apps/pc-client/electron/modules/dep-manager.ts:209-260` — `detectSystemPostgresql`（R-PC-1 降为提示）
- `apps/pc-client/electron/modules/dep-manager.ts:262-283` — `checkAll`（R-PC-1）
- `apps/pc-client/electron/modules/runtime.ts:126-141` — `getInstalledVersion` 按 `AGENTSKILLS_RUNTIME_VERSION=` 解析（GAP-6）
- `apps/pc-client/electron/modules/runtime.ts:184-273` — `start` 直接 spawn runtime（R-PC-3 待外置）
- `apps/pc-client/electron/modules/runtime.ts:275-299` — `stop` 用 `ProcessUtils.gracefulKill`(:284)（R-PC-3 主路径待降级）
- `apps/pc-client/electron/modules/env-generator.ts:49-195` / `:211-223` — `.env` 生成（L2 待移交 installer envfile 通道）
- `apps/pc-client/electron/modules/webadmin-server.ts:28-30` — `getWebAdminRoot`（`resources/web-admin`）
- `apps/pc-client/electron/modules/runtime-version.ts:44-46` — `getCurrentVersion`（REQ-PCI-024 待改取 installer）
- `apps/pc-client/electron/modules/runtime-version-detector.ts:23-35` — `detectVersion` 默认 `0.0.25`（版本展示基准）
- `apps/pc-client/electron/utils/paths.ts:20` — `runtimeHome`；`:29-34` `getResourcesPath`（web-admin 副本根）
- `apps/pc-client/scripts/build-web-admin.ps1:80-91` — 写 `WEB-ADMIN-MANIFEST.json`（REQ-PCI-031）
- `apps/pc-client/scripts/verify-web-admin-sync.ps1:30-41` — 比对副本 SHA256（REQ-PCI-031）
- `apps/pc-client/scripts/verify-runtime-sync.ps1:26-41` — tarball 校验守卫（REQ-PCI-004，T005）
- `apps/pc-client/.github/workflows/sync-runtime-check.yml` — CI 同步校验（T005）
- `apps/pc-client/package.json:20-21` — `build:web-admin` 与 `build` 主链路（REQ-PCI-030，T040）

## 12.2 PC 客户端路径别名说明

**本仓库 PC 客户端路径为 `apps/pc-client`（与 `agentskills-runtime` 同级，位于 `D:\UCT\projects\uctoo\apps\` 下）。历史文档曾用别名 `apps/agentskills-runtime-pc` 指代同一工程；本次修订已在 `spec.md` / `tasks.md` / `STATUS.md` 与本设计文档中将其统一为 `apps/pc-client`。`sync-runtime-to-pc.ps1` 默认 `PcRoot` 解析为同级 `pc-client`（见 `sync-runtime-to-pc.ps1:60-62`），若解析失败请以 `-PcRoot` 显式传入 `apps/pc-client` 绝对路径。本设计所有 PC 侧 file:行号均使用真实路径 `apps/pc-client/...`。**

## 12.3 与 spec 不一致之处（已于 2026-10-17 修订）

> 以下条目已在 2026-10-17 据本设计发现修订进 `spec.md` / `STATUS.md`；`sync-runtime-to-pc.ps1` 默认 `PcRoot` 亦同步修正为 `apps/pc-client`（`sync-runtime-to-pc.ps1:35,61`）。

1. **PC 路径已统一为 `apps/pc-client`**：`spec.md` / `tasks.md` / `STATUS.md` 及本设计文档中的历史别名 `apps/agentskills-runtime-pc` 已全部改为 `apps/pc-client`（与 `D:\UCT\projects\uctoo\apps` 实际目录一致）；`sync-runtime-to-pc.ps1` 默认 `PcRoot` 已改为 `..\pc-client`（2026-10-17 修订）。
2. **GAP-6 VERSION 格式不一致（已定修法）**：`package_release/main.cj:1415` 写 `agentskills-runtime 0.0.29`（空格分隔），PC `runtime-integrator.ts:87` / `runtime.ts:133` 按 `AGENTSKILLS_RUNTIME_VERSION=` 前缀解析 → 版本恒 `undefined`。**修法已定（本设计推荐）**：PC 解析器改读真实格式（T025），放弃 `package_release` 增补等号行方案（需同步 installer `readInstallerVersion` 解析，改动面更大）。已写入 `STATUS.md` GAP-6（标注 `design.md §12.3-2`）。
3. **`--no-serve` 透传缺口（2026-10-18 复核：已闭环，不再是 Phase 3 阻塞项）**：`args.cj:88-90` 接受标记后，实际消费在 `main.cj` 派发到的子模块：`core/orchestrator.cj:408`（S6 步骤——`--no-serve` 时跳过 runtime 自启动，否则 install 会拉起 runtime 子进程并监听健康端口，与"无端口监听"相悖）、`serve/manage.cj:46`（`serve --manage` 与 `--no-serve` 矛盾时按「不冒充成功」提前 `EXIT_ARGS` 退出，不 bind 端口）、`http/bootstrap.cj:24`（无参 HTTP 引导服务同理拒绝）。三条会 bind 端口的路径均已处理 ⇒ **AC-PCI-011「任何子命令下均不监听端口」在 CLI 模式成立**。此前「`main.cj` 子命令路径未消费」的表述基于"消费点须在 `main.cj` 字面"的误读，已据此修订本条、`STATUS.md` GAP-2 与 §12.3 缺口表。
4. **REQ-PCI-004 权威源差异（已修订口径）**：同步脚本以 `cjpm.toml` 为硬门权威源，`release/VERSION` 仅软告警；与需求字面「校验包内 `release/VERSION`」存在口径差。已在 `spec.md` REQ-PCI-004 修订为「版本权威源为 `cjpm.toml`（硬性），`release/VERSION` 若存在作软交叉校验（不一致仅告警、不阻断）」。

## 12.4 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-17 | sdd-design-writer | 初始版本，基于 spec/tasks/STATUS 与全部真实代码 file:行号 落盘 |
