# PC 客户端对接 ucInstaller —— 任务清单

**版本**：v1.0（2026-10-10）
**对应规格**：`spec.md`（REQ-PCI-001~031 / AC-PCI-001~041）
**代码基线**：runtime `0.0.29`（tar 439,929,547 B @ 10-10 07:12）；PC gitcode `v0.0.26`（副本 398,829,380 B @ 8-8 23:40）

> **交付顺序原则**：先做 **L1 同步层**（收益最大、风险最低、能立刻消除 39 MB 漂移），
> 再做 installer 接口补齐（GAP-1/2），最后动 PC 主进程（L2/L3，风险最高）。
> 三层可独立交付、独立回退。

---

## Phase 1：同步层（消除 N-1 漂移）—— 建议最先做

| # | 任务 | 落点 | 依赖 | 验收 |
|---|---|---|---|---|
| **T001** | 新增共享同步脚本：runtime `release/*.tar.gz` → PC `resources/runtime/` | 新文件 `apps/agentskills-runtime/scripts/sync-runtime-to-pc.ps1`（供两侧共用） | — | AC-PCI-001 |
| **T002** | 复制后计算并比对源/目标 SHA256，**不一致 exit 非 0** | 同上 | T001 | AC-PCI-002 |
| **T003** | 输出并落盘 `版本/大小/SHA256` 三元组（校验文件放 `resources/runtime/` 旁） | 同上 | T001 | AC-PCI-003 |
| **T004** | 校验包内 `release/VERSION` 与 PC 期望版本一致，不符即失败 | 同上 | T001 | AC-PCI-004 |
| **T005** | PC 的 `.github/` 工作流接入一次同步校验（防再次漂移） | `apps/pc-client/.github/` | T001~T004 | AC-PCI-004 |

> 性能提示：tar.gz 已 **439 MB**，全量 SHA256 有可观 I/O。建议 **先比大小、再比 SHA256**（大小不同直接失败，省掉一次全量哈希）。

---

## Phase 2：installer 接口补齐（PC 集成的硬前提）

| # | 任务 | 落点 | 依赖 | 验收 |
|---|---|---|---|---|
| **T010** | 实现 `--version`：输出与 runtime `release/VERSION` 一致的版本号（**C-D3**） | `installer/src/cli/args.cj`（开关）+ `main.cj`（分支） | — | AC-PCI-010 |
| **T011** | 实现 `--no-serve`：任何子命令下均不监听端口（**C-D1**） | 同上 | T010 | AC-PCI-011 |
| **T012** | `--json --version` 组合可用，stdout 单行 JSON | `main.cj` | T010 | AC-PCI-012 |
| **T013** | 把 `ucInstaller.exe` 放入 runtime 发行包 `release/bin/`（**D1 轨道 / OQ-D2**） | `src/scripts/package_release/main.cj` | — | REQ-PCI-005 |
| **T014** | 同步更新 `printUsage()` 帮助文案，纳入新开关 | `installer/src/main.cj` | T010/T011 | 与 T013 一致 |

> ⚠️ T010/T011 是**已确认缺口**（GAP-1/GAP-2）：全量 grep `installer/src` 未命中 installer 自身的
> `--version` / `--no-serve`（只命中探测外部命令的 `git/cjc/cjpm --version`）。不补则 PC 无法可靠取版本。

---

## Phase 3：PC 委托层（L2）—— 安装交给 installer

| # | 任务 | 落点 | 依赖 | 验收 |
|---|---|---|---|---|
| **T020** | 新增 installer 桥接模块：定位 `binDir/ucInstaller.exe`（复用 `runtime-integrator.ts:73` 的 `getBinDir()`） | `apps/pc-client/electron/modules/installer-bridge.ts`（新） | T013 | — |
| **T021** | 数据库/初始化步骤改为调用 `ucInstaller.exe install`，**不再 `pgManager.initialize()`** | `electron/modules/setup.ts` | T020 | AC-PCI-020 |
| **T022** | 用 `--progress=ndjson` 消费进度并实时推送到渲染层 | `installer-bridge.ts` + IPC | T021 | AC-PCI-021 |
| **T023** | 按退出码 0/2/6 区分呈现，6 显示「需人工介入」 | `setup.ts` / 渲染层 | T021 | AC-PCI-022 |
| **T024** | 保留旧链路开关，新链路失败可回退 | `config.ts` 增开关 | T021 | AC-PCI-025 |
| **T025** | 版本显示改为取 `ucInstaller.exe --version` | `runtime-version.ts` / `runtime-version-detector.ts` | T010 | AC-PCI-024 |

---

## Phase 4：PC 托管层（L3）—— 启停归位（R-39）

| # | 任务 | 落点 | 依赖 | 验收 |
|---|---|---|---|---|
| **T030** | runtime 启停改为经 installer 管控者（`serve --manage`），PC 不自行 kill 作为主路径 | `electron/modules/runtime.ts` | T020 | AC-PCI-023 |
| **T031** | 旧启停逻辑降级为 fallback，仅在管控者不可用时触发 | `runtime.ts` | T030 | AC-PCI-025 |
| **T032** | `dep-manager.ts` 的探测结果不再作为判据，仅作提示（**R-PC-1**：唯一实现在 installer） | `dep-manager.ts` | T021 | R-PC-1 |

---

## Phase 5：web-admin 副本治理

| # | 任务 | 落点 | 依赖 | 验收 |
|---|---|---|---|---|
| **T040** | 把 `build:web-admin` 纳入 `build` 主链路（或显式前置步骤） | `apps/pc-client/package.json:21` | — | AC-PCI-030 |
| **T041** | 副本写入来源版本/构建时间标记，支持过期检出 | `scripts/build-web-admin.ps1` | T040 | AC-PCI-031 |
| **T042** | 重新构建一次，把 Phase 10 四面板 + 新 favicon + 官网修复同步进 PC | 产物 `resources/web-admin/` | T040 | AC-PCI-030 |

> 现状：`resources/web-admin/` 的 `index.html` 停留在 **8-30**、`favicon.png` 是 **3-27 旧蓝方块**，
> 缺 Phase 10 全部改动（四面板改指 runtime 端点、T052 占位符红标、T058 健康修复消费端等）。

---

## Phase 6：实测验收

| # | 任务 | 说明 | 验收 |
|---|---|---|---|
| **T050** | **OQ-D4 实测**：PC 安装后首次登录，主 agent 自动登录是否成功 | `research-deployment.md` §OQ-D4 标记「静态取证如此、未实测」；若失败则 PC 复用 installer 的优先级从「应该」升为「必须」 | AC-PCI-040 |
| **T051** | **OQ-D5 实测**：冷启动 ≤60 s（接入 seed 导入后） | seed ≈0.87 MB、本地 PG，预估增量秒级，需实测确认 | AC-PCI-041 |
| **T052** | 端到端：同步脚本 → 出包 → PC 安装 → 首登 → 冷启动计时 | 串起 Phase 1~5 | AC-PCI-001~041 |

---

## 不在本工程范围

- PC 客户端自身 UI / Electron 外壳重写。
- runtime `release/` 布局调整（维持「tar 根为 `release/`」的既有隐式契约；若调整须先升级为显式校验，见 `spec.md` 风险 3）。
- `package_release` 与 `installer/package.ps1` 的 DLL 规则去重（另立议题，见 `RuntimeNativeInstaller/STATUS.md` §四）。
