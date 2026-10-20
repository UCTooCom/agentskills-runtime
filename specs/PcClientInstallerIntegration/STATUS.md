# PC 客户端对接 ucInstaller —— 状态快照

**盘点日期**：2026-10-10
**盘点方式**：源码与产物实地核对（非估算）
**配套文档**：`spec.md`（需求与验收）、`tasks.md`（任务拆解）

---

## 一、一句话状态

> **决策已拍板(Q-1~Q-4)，Phase 1 同步层已开工。** 已落地：runtime 侧同步脚本 `scripts/sync-runtime-to-pc.ps1`(T001~T004) + PC 侧自包含校验 `scripts/verify-runtime-sync.ps1` 与 CI 守卫 `.github/workflows/sync-runtime-check.yml`(T005)，并正在执行首次同步消除 39 MB 漂移。**Phase 2 installer 接口补齐代码已全部落盘**（T010 `--version` / T011 `--no-serve` / T012 `--json --version` / T013 `ucInstaller.exe` 入 `release/bin/` / T014 `printUsage` 文案），installer 已编译通过（用户确认），待 `package_release` 重跑产出 `release/bin/ucInstaller.exe`。**Phase 5 web-admin 副本治理代码已落**（T040 `build:web-admin` 链入 `build` 主链路 / T041 `build-web-admin.ps1` 写来源指纹标记 `WEB-ADMIN-MANIFEST.json` + 新增 `verify-web-admin-sync.ps1` 过期检出），**T042 重建（把 Phase 10 四面板 + 新 favicon + 官网修复同步进 `resources/web-admin/`）待用户执行 `npm run build:web-admin`**。
**Phase 3 委托层代码已全部落盘并通过 `tsc --noEmit`（2026-10-18）**：T020 `installer-bridge.ts`（NDJSON `kind` 事件流解析 + 布局断言）/ T021 `setup.ts` 嵌入式分支改调桥接 / T022 进度经 `install:progress` 推渲染层 / T023 退出码 0-2-6 语义区分 / T024 `config.ts` `useInstaller` 回退开关 / T025 版本取自 `ucInstaller.exe --version`；并**一并修掉 GAP-6**（两处旧解析改用共用 `parseRuntimeVersionText`）。
**GAP-2 经复核已闭环**：`--no-serve` 的消费点在 `orchestrator.cj:408`（S6 跳过 runtime 自启动）/ `serve/manage.cj:46`（拒绝不 bind）/ `bootstrap.cj:24`（拒绝），三条会 bind 端口的路径均已处理，**不再阻塞 Phase 3**。

---

## 二、版本差实测（用户反馈「落后几个版本」的量化）

| 项 | PC 侧 | runtime / web 侧 | 差 |
|---|---|---|---|
| runtime 版本 | `v0.0.26`（gitcode 末次提交 `1c51eb6`） | `0.0.29` | **落后 3 个版本** |
| runtime tarball | 398,829,380 B（8-8 23:40） | 439,929,547 B（10-10 07:12） | **约 39 MB** |
| web-admin 副本 | `index.html` 8-30；`favicon.png` 3-27（旧蓝方块） | `dist` 10-10（含 Phase 10 全部改动） | **约 6 周** |

**gitcode 仓库结构**：仅 2 个提交（`97fef27 Initial commit`、`1c51eb6 'v0.0.26'`）；`resources/runtime/` **为空**（tarball 被 `.gitignore` 排除）⇒ **git 仓库天然无法体现 runtime 版本**，漂移只能靠校验文件发现。

---

## 三、已识别缺口（按阻塞程度排序）

| # | 缺口 | 实证 | 归属 | 阻塞 |
|---|---|---|---|---|
| **GAP-1** | installer 无 `--version`（C-D3） | grep `installer/src` 未命中自身开关 | installer | 阻塞 T025 / AC-PCI-024 |
| **GAP-2** | installer `--no-serve` **已闭环**（C-D1，2026-10-18 复核）：标记被 `args.cj:88-90` 接受，消费点分布在 `main.cj` 派发到的子模块——`core/orchestrator.cj:408`（S6 跳过 runtime 自启动）、`serve/manage.cj:46`（矛盾时 `EXIT_ARGS` 拒绝）、`http/bootstrap.cj:24`（无参 HTTP 引导拒绝）；三条会 bind 端口的路径均已处理 | `orchestrator.cj:408`；`serve/manage.cj:46`；`bootstrap.cj:24`（`design.md §12.3-3` 已修订） | installer | **不再阻塞 Phase 3** |
| **GAP-3** | tarball 同步无 SHA256（N-1 / OQ-D3） | 两份副本差 39 MB 且无提示 | PC | **已闭环**（Phase 1 同步脚本 + 校验文件 + CI 守卫） |
| **GAP-4** | PC 自带 web-admin 过期 | 8-30 vs 10-10；favicon 仍 3-27 旧图 | PC | **已闭环**（Phase 5 T040 链入 build 主链路 / T041 写来源指纹标记 `WEB-ADMIN-MANIFEST.json` + 新增 `verify-web-admin-sync.ps1` 过期检出；T042 重建待用户执行） |
| **GAP-5** | OQ-D4 / OQ-D5 未实测 | `research-deployment.md` 标记「建议实测」 | 验收 | 阻塞 T050~T052 |
| **GAP-6** | **VERSION 格式不一致** —— **已闭环（2026-10-18，随 Phase 3 T025 一并处理）** | `package_release/main.cj:1415` 写 `agentskills-runtime 0.0.29`（**空格分隔**）；PC 原按 `AGENTSKILLS_RUNTIME_VERSION=` 前缀逐行读取 → 永远命中不到，version 恒 `undefined` | runtime ↔ PC | **已修**：新增共用解析 `apps/pc-client/electron/utils/version.ts::parseRuntimeVersionText`（按真实空格格式解析，兼容历史等号格式，并**拒绝** `0.0.1 (VERSION file not found)` 兜底值）；`runtime-integrator.ts:82-88` 与 `runtime.ts:128-136` 两处旧解析均已改用它；`runtime-version.ts` 新链路改调 `installerBridge.getVersion()`（`ucInstaller.exe --version`），旧链路保留 fallback。**不再阻塞** T025 / Q-4 |

---

## 四、已拍板 / 待拍板

### 已拍板（沿用上游决策）

| # | 决策 | 出处 |
|---|---|---|
| OQ-D2 | installer 放 `release/bin/`，与 runtime 共用 DLL，PC 零改动 | `research-deployment.md` §OQ-D2 |
| D1 + D3 | installer 随 runtime 发行包分发；PC 从 tar.gz 取，**不内嵌第二份** | 同上 §2.3 |
| OQ-D6 | NestJS 全部退役 | `RuntimeNativeInstaller` 已拍板 |

### 已拍板（本工程新增，2026-10-10 用户拍板）

| # | 议题 | 拍板结论 | 影响 |
|---|---|---|---|
| **Q-1** | 同步脚本放哪 | **放 runtime 侧** `apps/agentskills-runtime/scripts/sync-runtime-to-pc.ps1`，PC 引用 | T001~T004 落点已定 |
| **Q-2** | T013（installer 进 `release/bin/`）由谁做 | **`package_release`**（它才是 runtime 发行包生产者） | T013 归属明确 |
| **Q-3** | PC 旧模块（pgsql/dep-manager/env-generator） | **先保留为 fallback**，验收通过后再删 | T024/T031 默认保留 |
| **Q-4** | PC `version` 语义 | **分开显示**：客户端 `0.1.0` 与运行时 `0.0.29` 分别展示 | 影响 T025 / Q-4 验收 |

### 待拍板

> 本工程新增议题已全部拍板（Q-1~Q-4）。仅剩 GAP-6 的修法待 Phase 3 定（PC 解析器改读真实格式 vs `package_release` 增补等号行）。

---

## 五、建议执行顺序（2026-10-10 确认）

> 用户拍板：**Phase 1 同步层最先做，然后 Phase 2 installer 接口补齐**。

1. **Phase 1（T001~T005）** —— 同步脚本 + SHA256 + CI 守卫。**收益最大、风险最低**，已开工，正在消除 39 MB 漂移。✅ 进行中
2. **Phase 2（T010~T014）** —— 补 `--version` / `--no-serve`，把 installer 放进 `release/bin/`（T013 由 `package_release` 做，Q-2）。这是 Phase 3 的硬前提。✅ 代码已落，待人工编译验证
3. **Phase 5（T040~T042）** —— web-admin 副本纳入主链路（可与 1、2 并行）。✅ 代码已落（T040/T041），T042 重建待用户执行 `npm run build:web-admin`
4. **Phase 3（T020~T025）** —— PC 委托层 + GAP-6 修复。✅ **代码已落盘并通过 `tsc --noEmit`**（2026-10-18）
5. **Phase 4（T030~T032）** —— PC 托管层：启停经 `serve --manage` 管控者、旧启停逻辑降级 fallback、`dep-manager` 探测结果降级为提示。⬜ 待做
6. **Phase 6（T050~T052）** —— 端到端实测。⬜

---

## 六、关联文档

- 上游：`specs/RuntimeNativeInstaller/{spec.md,design.md,research-deployment.md,STATUS.md}`
- 既有待办：`apps/pc-client/docs/RUNTIME_PACKAGE_SYNC_TODO.md`（N-1 的原始记录，本文档已将其升级为 REQ-PCI-001~004）
- 历史基线：`apps/agentskills-runtime/.codeartsdoer/specs/pc_desktop_client/`
