# PC 客户端对接原生安装器（ucInstaller）工程规格

**文档版本**：v1.0
**创建日期**：2026-10-10
**工程目录**：`apps/agentskills-runtime/specs/PcClientInstallerIntegration/`
**上游基线**：`specs/RuntimeNativeInstaller/`（`spec.md` REQ-RNI-001~109 / AC-001~276、`design.md` v1.8、`research-deployment.md`）
**历史基线**：`apps/agentskills-runtime/.codeartsdoer/specs/pc_desktop_client/`（`spec.md` / `design.md` / `tasks.md` / `pc_desktop_client_research_report.md`）
**现状依据**：源码与产物实地核对（见 §2，每条均附文件与实测值）

---

## 1. 一句话结论

> **PC 客户端当前在 Electron 主进程里自己实现了整套安装链路（内嵌 PostgreSQL、依赖探测、`.env` 生成、runtime 解压、安装向导），而这套能力仓颉原生安装器 `ucInstaller.exe` 已经全部实现且更完整。本工程的目标是：把 PC 的「安装/初始化」职责移交给 installer，PC 只保留「Electron 外壳 + 进程托管 + 进度呈现」；同时把 runtime 发行包 → PC `resources/` 的手工复制收归为带 SHA256 校验的脚本，消除版本漂移。**

---

## 2. 现状盘点（实测）

### 2.1 三处代码位置与角色

| 位置 | 角色 | 技术栈 | 实测状态 |
|---|---|---|---|
| `apps/agentskills-runtime` | **runtime 宿主 + installer 源码** | 仓颉 cjc 1.1.3 | `target/release/VERSION` = `agentskills-runtime 0.0.29`，build 2026-10-10 07:10；`release/agentskills-runtime-win-x64.tar.gz` = **439,929,547 B**（10-10 07:12） |
| `apps/pc-client`（本仓库内） | **PC 客户端开发副本** | Electron 42 + Vue 3 + Vite 8 + electron-builder 26 | `package.json` version `0.1.0`；`resources/runtime/*.tar.gz` = **398,829,380 B**（**8-8 23:40**） |
| `D:\UCT\products\gitcode\agentskills-runtime-pc` | **PC 客户端对外 git 仓库** | 同上 | `git log` 仅 2 个提交：`97fef27 Initial commit`、`1c51eb6 'v0.0.26'`；`resources/runtime/` **为空**（tarball 未入 git） |

### 2.2 版本差实测（用户反馈「落后几个版本」的量化）

| 项 | PC 侧 | runtime 侧 | 差 |
|---|---|---|---|
| 版本标记 | `v0.0.26`（gitcode 末次提交） | `0.0.29` | **落后 3 个版本** |
| runtime tarball 大小 | 398,829,380 B（8-8 23:40） | 439,929,547 B（10-10 07:12） | **差 41,100,167 B（约 39 MB）** |
| 自带 web-admin | `resources/web-admin/`：`index.html` **8-30**、`favicon.png` **3-27**（旧蓝方块 logo）、`install.html/js/css` **4-1** | `apps/web-admin/dist`：10-10（含 Phase 10 四面板改造、favicon 换「U」logo、官网视差修复、视频统一） | **落后约 6 周，缺 Phase 10 全部改动** |

> ⚠️ 两条漂移**互相独立且都会静默发生**：
> ① tarball 手工 `cp` 无校验（`research-deployment.md` §2.5 缺口 **N-1**，已在 `pc/docs/RUNTIME_PACKAGE_SYNC_TODO.md` 记录为待办）；
> ② web-admin 副本靠 `scripts/build-web-admin.ps1` 手动触发（`package.json:20` 的 `build:web-admin`），**不在 `build` 主链路里**（`build` 仅为 `vite build && electron-builder`）。

### 2.3 PC 端现状：安装逻辑写在 Electron 里

`electron/modules/` 下与安装/初始化直接相关的模块（实测文件与体积）：

| 文件 | 职责 | 与 installer 的重叠 |
|---|---|---|
| `setup.ts`（4.9 KB） | 安装向导编排：`executeDatabaseStep`（内嵌/外部 PG 二选一）、`executeAIStep`（provider+apiKey）、`completeSetup`（`envGenerator.generateForRuntime()`） | 完全重叠 installer 的 S0~S8 + `envfile_service` + `bcrypt_admin` |
| `pgsql.ts`（16 KB） | 内嵌 PostgreSQL 初始化/启停/连接测试 | 重叠 installer 的 DB 步骤与 seed 导入 |
| `dep-manager.ts`（11 KB） | 系统依赖探测（含 `detectSystemPostgresql()`） | 重叠 installer `services/envcheck.cj` + `platform/probe.cj`（**R-42 唯一实现**） |
| `env-generator.ts` / `env-sync.ts` | 生成与同步 runtime `.env` | 重叠 installer `services/envfile_service.cj` |
| `runtime-integrator.ts`（7.3 KB） | 解压 `resources/runtime/*.tar.gz` → `<runtimeHome>/<plat>/release`；`getRuntimeBinPath()` = `release/bin/agentskills-runtime<suffix>` | **这正是 installer 构件的落点依据（见 §4.2）** |
| `runtime-version.ts` / `runtime-version-detector.ts` | runtime 版本探测与升级 | 需改为向 installer 取版本（**C-D3 缺口**） |
| `webadmin-server.ts` | 以 `Paths.getResourcesPath('web-admin')` 提供管理界面 | 副本过期（§2.2） |

`electron-builder.json` 的 `extraResources` 打包了 `pgsql/{bin,lib,share}`、`sql`、`web-admin`、`openssl`、`defaults`、`runtime/*.tar.gz` —— **即 PC 安装包自带一整套运行时依赖**，这正是 installer 已经能按需安装/校验的东西。

### 2.4 installer 已具备的能力（PC 可复用）

`specs/RuntimeNativeInstaller/STATUS.md` 与 `installer/src` 实证：

- **CLI 子命令全通道**：`check-environment` / `install` / `devkit install|verify|init` / `db export` / `seed apply` / `seed verify` / `rollback` / `uninstall`（`main.cj` dispatch 已全部接通，非 `notImplemented`）。
- **运维模式**：`serve --manage`（T056，只挂运维端点、不推进 S0~S8）；无参启动 = HTTP 安装引导服务（默认 :3000）。
- **机器可读输出**：`--json`（stdout 仅 JSON）、`--progress=ndjson`（T053 流式进度，与 `--json` 互斥）。
- **编排与数据**：`core/orchestrator.cj`（S0~S8 + 自退役）、`services/seed/{importer,rbac,verify}.cj`（主 agent 账号、超管复用、身份重绑定）。
- **退出码语义**：0 成功 / 2 参数错误 / 6 待实现或需人工介入。

---

## 3. 目标与非目标

### 3.1 目标（G）

| # | 目标 |
|---|---|
| G-1 | PC 的「安装与初始化」由 installer 执行，PC 不再自行初始化 PostgreSQL、不再自行生成 `.env` |
| G-2 | runtime 发行包 → PC `resources/` 的同步**脚本化 + SHA256 校验**，消除 N-1 漂移 |
| G-3 | PC 的安装进度来自 installer 的 NDJSON 流，不再「盲等」 |
| G-4 | runtime 进程的启停交由 installer 管控者（**R-39**：启停不得由 runtime 自举），PC 只做呈现 |
| G-5 | PC 自带的 web-admin 副本纳入构建主链路并可校验版本 |

### 3.2 非目标（明确不做）

- 不重写 PC 的 UI 与 Electron 外壳。
- 不让 installer 承担 PC 客户端自身的构建流程（沿用 `research-deployment.md` 的边界划分）。
- 不立即删除 PC 侧旧模块：采用**可回退的双轨**（§4.3），旧链路保留至新链路验收通过。
- 不在本工程改变 runtime 的 `release/` 布局（维持 tar 根为 `release/` 的既有隐式契约）。

---

## 4. 集成方案

### 4.1 发布轨道：采用 D1 + D3

沿用 `research-deployment.md` §2.3 已拍板的轨道划分：

- **D1（主）**：`ucInstaller.exe` 作为构件放进 runtime 发行包 `release/bin/`，与 runtime 共用 DLL，**零额外分发成本**。
- **D3（PC 采用）**：PC **不单独内嵌一份 installer 二进制**，而是从 D1 的 tar.gz 解压后取 `release/bin/ucInstaller.exe`。理由：避免同一份二进制在安装包里存两份（400 MB 量级）。

### 4.2 构件落点与 PC 零改动发现（**OQ-D2 已拍板**）

installer 落点为 `release/bin/ucInstaller.exe`。PC 侧**无需改动路径常量**即可发现它：

- `runtime-integrator.ts:58`：`runtimeBin = <runtimeHome>/<plat>/release/bin/agentskills-runtime<suffix>`
- `runtime-integrator.ts:73`：`getBinDir() = <releaseDir>/bin`

⇒ `ucInstaller.exe` 与 `agentskills-runtime.exe` **同目录**，PC 只需把「取 runtime 二进制」的同一 `binDir` 用于「取 installer」。这是 OQ-D2 选择 `release/bin/` 而非同级 `installer/` 子目录的直接收益。

### 4.3 PC 侧改造分三层（可独立交付、可回退）

| 层 | 内容 | 回退方式 |
|---|---|---|
| **L1 同步层**（先做，收益最大） | 新增共享同步脚本：runtime `release/*.tar.gz` → PC `resources/runtime/`，**复制后比对 SHA256，不一致即失败退出**；输出 `版本/大小/SHA256` 三元组并落盘校验文件；顺带校验包内 `release/VERSION` | 脚本失败不阻塞手工构建，但应在 CI 报警 |
| **L2 委托层** | PC 的安装向导改为调用 `ucInstaller.exe`：DB 步骤 → `install`（或 `check-environment` + 分步）；AI 配置 → 交给 installer 的 envfile 通道；进度 → `--progress=ndjson` | 保留 `setupWizardService` 旧实现，用配置开关切换 |
| **L3 托管层** | runtime 启停改为经 installer 管控者（`serve --manage` / R-39）；版本显示改为 `ucInstaller.exe --version`（需先补 C-D3） | 旧 `runtime.ts` 启停保留为 fallback |

### 4.4 进度与状态回传

- PC 用 `--progress=ndjson` 拉流式事件（start → step → item → final），末行含 `exitCode/ok`，诊断走 stderr 不污染 stdout。
- 退出码语义映射：0 成功 / 2 参数错误（PC 应提示用法）/ 6 待实现或需人工介入（PC 应提示「需人工介入」而非显示成功）。

### 4.5 已识别缺口（必须在集成中补齐）

| # | 缺口 | 实证 | 归属 |
|---|---|---|---|
| **GAP-1** | installer **未提供 `--version`**（约束 **C-D3**：须输出与 runtime `VERSION` 一致的版本号） | 全量 grep `installer/src` 未命中自身 `--version` 开关（仅命中探测外部命令的 `git/cjc/cjpm --version`） | installer |
| **GAP-2** | installer `--no-serve` 标记已实现但**透传缺口**（约束 **C-D1**：完全不监听端口，仅 CLI/stdout 交互）：`args.cj` 已接受该标记（T011 已落），但 `main.cj` 子命令路径未消费它，`serve --manage` 仍可能监听端口；需补强透传以硬保证零端口交互 | `args.cj` 接受标记、`main.cj` 子命令路径未消费（`design.md §12.3-3` / `args.cj:88-90`） | installer |
| **GAP-3** | tarball 同步**无 SHA256**（N-1 / OQ-D3） | 两份副本差 39 MB 且无任何提示 | PC（L1） |
| **GAP-4** | PC 自带 **web-admin 副本过期** | 8-30 vs 10-10；`favicon.png` 仍为 3-27 旧图 | PC（L1/G-5） |
| **GAP-5** | OQ-D4/OQ-D5 未实测（首登主 agent 自动登录、冷启动 ≤60 s） | `research-deployment.md` §OQ-D4/D5 标记「建议实测」 | 验收阶段 |

---

## 5. 需求（REQ-PCI）

### 5.1 发布与同步

- **REQ-PCI-001**：runtime 发行包（`release/agentskills-runtime-win-x64.tar.gz`）同步到 PC `resources/runtime/` 必须经脚本完成，禁止手工 `cp`。
- **REQ-PCI-002**：同步后必须计算并比对源与目标的 SHA256，**不一致即失败退出**（非警告）。
- **REQ-PCI-003**：同步脚本须输出并落盘 `版本 / 大小 / SHA256` 三元组。
- **REQ-PCI-004**（口径修订，据 `design.md §12.3-4`）：同步脚本须校验运行时包声明的版本与 PC 期望版本一致。**版本权威源为包清单 `cjpm.toml`**（硬性来源，`sync-runtime-to-pc.ps1` 据此解析并比对 `$ExpectedVersion`）；`release/VERSION` 若存在则作为**软交叉校验**（不一致仅告警、不阻断），以解决 tarball 不入库导致版本只能靠校验文件发现的盲区（N-1 / OQ-D3）。
- **REQ-PCI-005**：`ucInstaller.exe` 必须位于发行包 `release/bin/` 内（D1/D3 轨道，OQ-D2）。
- **REQ-PCI-006**：PC 安装包内**不得**存在第二份 installer 二进制副本。

### 5.2 installer 侧接口补齐

- **REQ-PCI-010**：installer 须提供 `--version`，输出与 runtime `release/VERSION` 一致的版本号（C-D3）。
- **REQ-PCI-011**：installer 须提供 `--no-serve`，执行任何子命令时均不监听端口（C-D1）。
- **REQ-PCI-012**：`--version` / `--no-serve` 须与 `--json` 组合可用，且 stdout 仅含约定内容。

### 5.3 PC 侧委托与托管

- **REQ-PCI-020**：PC 安装向导的数据库与初始化步骤须委托 installer 执行，不得自行 `pgManager.initialize()`。
- **REQ-PCI-021**：PC 须以 `--progress=ndjson` 消费安装进度并实时呈现，禁止「盲等」。
- **REQ-PCI-022**：PC 须按 installer 退出码（0/2/6）区分呈现，禁止把 6 显示为成功。
- **REQ-PCI-023**：runtime 启停须经 installer 管控者（R-39），PC 不自行拉起/杀进程作为主路径。
- **REQ-PCI-024**：PC 显示的 runtime 版本须取自 installer（`--version`），不得仅靠本地文件猜测。
- **REQ-PCI-025**：改造须保留旧链路开关，任一新链路失败可回退。

### 5.4 web-admin 副本

- **REQ-PCI-030**：PC 的 web-admin 副本构建须纳入 `build` 主链路或由显式前置步骤保证，禁止「手工触发、忘了就过期」。
- **REQ-PCI-031**：副本须带来源版本/构建时间标记，可校验是否过期。

---

## 6. 验收标准（AC-PCI）

| # | 验收项 | 判据 |
|---|---|---|
| **AC-PCI-001** | 同步脚本可用 | 执行一次即完成复制，输出 `版本/大小/SHA256` |
| **AC-PCI-002** | SHA256 不一致即失败 | 人为篡改目标文件后重跑，**退出码非 0** 且明确报错 |
| **AC-PCI-003** | 版本断言生效 | `release/VERSION` 与期望值不符时脚本失败 |
| **AC-PCI-004** | PC 侧 tarball 与 runtime 同源 | 脚本执行后两侧 SHA256 完全一致 |
| **AC-PCI-010** | `--version` 可用 | `ucInstaller.exe --version` 输出与 `release/VERSION` 的 `agentskills-runtime <ver>` 一致 |
| **AC-PCI-011** | `--no-serve` 生效 | 带 `--no-serve` 执行任一子命令，**全程无端口监听** |
| **AC-PCI-012** | `--json --version` 可解析 | stdout 为单行 JSON，可解析出版本号 |
| **AC-PCI-020** | PC 不再自初始化 PG | 新链路下 `pgManager.initialize()` 不再被调用（以日志/断点验证） |
| **AC-PCI-021** | 进度实时呈现 | PC 安装界面能逐步显示 step/item 事件，而非结束时一次性出现 |
| **AC-PCI-022** | 退出码区分 | 构造 exit 6 场景，PC 显示「需人工介入」而非成功 |
| **AC-PCI-023** | 启停归位 | 停止 runtime 由 installer 管控者执行；PC 侧无自行 kill 主路径 |
| **AC-PCI-024** | 版本来源正确 | PC 显示版本与 `ucInstaller.exe --version` 一致 |
| **AC-PCI-025** | 可回退 | 关闭开关后旧链路仍可完成安装 |
| **AC-PCI-030** | web-admin 副本新鲜 | 执行 `build` 后副本的构建时间标记晚于 `apps/web-admin/dist` |
| **AC-PCI-031** | 过期可检出 | 副本与源不一致时有明确提示 |
| **AC-PCI-040** | **OQ-D4 实测** | PC 安装完成后首次登录，主 agent 自动登录成功（或明确记录失败证据） |
| **AC-PCI-041** | **OQ-D5 实测** | PC 冷启动 ≤60 s（接入 seed 导入后实测，不推翻原指标则保留） |

---

## 7. 约束与风险

- **R-PC-1（唯一实现）**：环境探测以 installer `services/envcheck.cj` 为唯一实现，PC 的 `dep-manager.ts` 不再作为判据来源（沿用 R-42）。
- **R-PC-2（不冒充成功）**：任何一步失败必须如实呈现，禁止静默降级（沿用 `--truthful` 语义）。
- **R-PC-3（启停外置）**：沿用 R-39，runtime 启停由 installer 管控者承担。
- **风险 1**：tar.gz 已达 **439 MB**，同步脚本若每次全量重算 SHA256 会有可观 I/O 耗时；建议校验文件缓存 + 大小快筛。
- **风险 2**：PC 的 `resources/runtime/` 未入 git（tarball 以 `.gitignore` 排除），因此 **gitcode 仓库天然无法体现 runtime 版本**，版本差只能靠校验文件发现 —— 这加剧了 REQ-PCI-003/004 的必要性。
- **风险 3**：installer 与 runtime 共用 DLL，若 `release/bin/` 布局变动，PC 的 `runtime-integrator.ts:58` 会静默找不到二进制 —— 该布局应从隐式契约升级为显式校验。

---

## 8. 参考

- `specs/RuntimeNativeInstaller/spec.md`、`design.md` v1.8、`tasks.md`
- `specs/RuntimeNativeInstaller/research-deployment.md` §2.2（D1 轨道）、§2.3（轨道表）、§2.5（缺口 N-1）、§OQ-D1~D6、§C-D1/C-D3
- `apps/pc-client/docs/RUNTIME_PACKAGE_SYNC_TODO.md`（N-1 的既有待办记录）
- `apps/agentskills-runtime/.codeartsdoer/specs/pc_desktop_client/`（原 PC 端工程文档）
