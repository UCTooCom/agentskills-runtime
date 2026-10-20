# RuntimeNativeInstaller — 编码任务规划

**版本**：v1.1.0
**创建日期**：2026-10-07
**最后修订**：2026-10-08（全量文档一致性复核；任务总表 REQ/AC 列按 spec 权威映射重排，见下方「⚠️ 映射修订说明」）
**关联需求**：`spec.md`（1982 行，**REQ-RNI-001~109**，**AC-001~276**，能力面 **M1~M18**）
**关联设计**：`design.md` **v1.7**（**13 个关键设计点** §4.1~§4.13、防回退 **R-01~R-42**）
**关联研究**：`research.md`（发行版安装）、`research-devenv.md`（DevKit）、`research-seed-identity.md`（SIC）、`research-seed-export.md`（SEP）、`research-seed-content.md`（内容定档与脱敏）
**技术栈**：仓颉 1.1.3 / cjpm / `libs/http_lib` / `libs/pgsql-driver` / `libs/blowfish-cj` / PostgreSQL 16 / openssl
**项目根目录**：`D:\UCT\projects\uctoo\apps\agentskills-runtime`
**本期唯一新建工程根**：`apps/agentskills-runtime/installer/`

---

## 开发规范（硬性，逐条遵守）

### 仓颉代码开发

1. 所有 `.cj` 文件编写**必须使用 cangjie-coder 技能**，遵循「查阅文档 → 检索代码 → 编辑适配 → 写入文件」四步流程。
2. 查仓颉 std API 走 `scripts/search_docs.py`，**禁止**直接 file_read 知识库。
3. 编写前必须在项目中找到同类既有代码作参考（如 HTTP 起服务参考 `src/app/core/server/HTTPServer.cj`，subprocess 参考既有 `executeWithOutput` 用法）。
4. 数据库列名 snake_case，仓颉变量 camelCase。

### 编译与构建（职责边界）

5. **编译职责边界（2026-10-09 修订）**：默认仍是「AI 不运行 `cjpm build`，由人工独立 cmd 编译后回传日志」，但 `installer/` 子工程（独立 executable、依赖 `../libs/*`、不回写宿主根 `cjpm.toml`）**例外**——AI 可自行运行 `cjpm build`、修复 bug 持续迭代，直至 installer 全部开发完成；仅当遇到需人工决策/协助的事项才暂停并通知人工。
6. 编译错误按「AI 自编译 → 日志定位 → AI 改代码 → 重编」闭环推进；其余大工程（宿主根 / `skills/` / `libs/` 本体）仍走人工编译回传流程。
7. **`-O2` 不可省**：`installer/cjpm.toml` 的 `[package].compile-option` 必须含 `-O2`，`blowfish` 依赖必须含 `-O2 --int-overflow=wrapping`（bcrypt 在 `-O0` 下需 7~22 s，是登录超时的根因）。改依赖级 `compile-option` 后**必须全量重编**（`cjpm clean && cjpm build`）。
8. `[target.x86_64-w64-mingw32.bin-dependencies]` 的 stdx `path-option` **必须存在**，否则编译能过但运行时找不到 DLL。

### 数据库与数据结构

9. **不新建任何表或列**（SDD 铁律 9）。本期只写既有表：`uctoo_user` / `user_has_roles` / `user_has_group` / `agents` / `config` / `permissions` 等，**结构一律复用** `sql/uctooDB.sql`。
10. 值一律参数化：字符串/JSON 走 `?` + `add`；Number/Boolean/NULL/`$raw:` 内联。
11. 需要新表/新列时**停下来报告**，不得自行 DDL。

### 已拍板闸口（无需再确认，直接体现于代码）

| # | 决议 |
|---|---|
| ① | 形态 = **独立 install 应用**（仓颉原生单二进制 `ucInstaller.exe`），**不做** L3 插件轨；Stage B 薄适配器本期不做 |
| ② | `create-admin` **只做真路径**：必须真实落库写 `uctoo_user`（bcrypt cost 10）；**删除** nestJs 的"返回 `admin-<timestamp>` 却不落库"假路径 |
| ③ | R1 SDK 分发 = **引导下载 + SHA256 校验 + 断点续传**，支持 `--sdk-path`；不内置 SDK |
| ④ | R2 离线介质 = **仅 SDK 需联网**，源码树/依赖库/sql 基线/知识库/前端依赖全部离线预置 |
| ⑤ | bcrypt 前缀**归一在仓颉侧**：写库前改写为 `$2a$`；**禁止改动** `libs/blowfish-cj`（vendored 库，其 `genSalt` 产出 `$2b$`） |
| ⑥ | DK-3 源码获取 = **`git clone` 单路径**（无离线兜底）；git 缺失或地址不可达 ⇒ **明确失败** + 处置指引，退出码非 0 |
| ⑦ | 初始数据身份重绑定 = Seed Identity Contract（占位符化 + 导入解析 + RBAC 补种 + 零悬空门禁） |
| ⑧ | 初始账号**二元组**：1 个人类超管 + 1 个主 agent 账号；**不创建任何演示/测试账号** |
| ⑨ | 初始数据**内容定档**：同步/派生表不导、`.env` 镜像行不导、其余脱敏后导 |
| ⑩ | **OQ-C1**：`config.website.appid` / `config.site.API_URL` **原样保留**（v3 配置项，v4 暂未用，后续小程序端需要） |
| ⑪ | **OQ-C2**：`ConfigSyncHandler` 敏感遮蔽**移交 runtime**，本工程只做防御 |
| ⑫ | **OQ-C3**：占位符在界面统一显示"未配置"（实现在 web-admin 前端，跨工程） |
| ⑬ | **OQ-C4**：6 行无 `source_path` 的 `agent_skills` **不补建** |

---

## 任务依赖关系图

```
Phase 0 工程骨架与 CLI
  T001 installer/cjpm.toml ─┐
  T002 main.cj 入口         ├─> Phase 1 平台层
  T003 cli/args.cj          │     T006 subprocess_timeout
  T004 cli/report.cj        │     T007 process_table
  T005 util/{log,json_out,  │     T008 envvars
           redact}.cj       │     T009 net
                            │          │
                            └──────────┴─> Phase 2 核心层
                                             T010 paths
                                             T011 state（.install-state.json）
                                             T012 probe（三级降级探测）
                                             T013 atomic（原子安装）
                                             T014 winfs（占用文件延迟删除）
                                                    │
                                                    ├─> Phase 3 HTTP 引导服务
                                                    │     T015 bootstrap（:3000 + CORS）
                                                    │     T016 routes（17 端点）
                                                    │     T017 static_site（向导三件套）
                                                    │     T018~T026 handlers ×9
                                                    │
                                                    ├─> Phase 4 服务层
                                                    │     T027 db（直连 PG）
                                                    │     T028 bcrypt_admin（$2a$ 归一）
                                                    │     T029 envfile_service（行级 in-place）
                                                    │     T030 ssl_service（openssl 单路径）
                                                    │     T031 media（tar.exe 解压）
                                                    │     T032 download（SDK 引导下载+校验）
                                                    │
                                                    └─> Phase 5 编排与自退役
                                                          T033 orchestrator（断点续装）
                                                          T034 自退役 GC
                                                                │
                          ┌───────────────────────────────────┘
                          ├─> Phase 6 DevKit（M11/M12）
                          │     T035 devkit/registry（DK-1~DK-8）
                          │     T036 devkit/install（含 DK-3 git clone 单路径）
                          │     T037 devkit/verify
                          │     T038 devkit/init（I1~I9）
                          │
                          └─> Phase 7 Seed 导出（SEP）
                                T039 seed/policy（export-policy + sanitize-policy）
                                T040 seed/scanner（引号感知词法扫描）
                                T041 seed/exporter（T-A~T-F 分层）
                                T042 seed/sanitizer（R1~R4 + keepVerbatim）
                                T043 seed/identity（匿名化 + 孤儿策略）
                                T044 seed/guards（六条门禁）
                                T045 CLI: db export
                                      │
                                      └─> Phase 8 Seed 导入（SIC）
                                            T046 seed/importer（占位符解析）
                                            T047 seed/rbac（账号二元组 + 补种）
                                            T048 seed/verify（零悬空 + 菜单非空）
                                            T049 CLI: seed apply / seed verify
                                                  │
                                                  └─> Phase 9 出包与端到端验收
                                                        T050 出包布局 + start-installer.bat
                                                        T051 端到端验收（真机全新环境）
                                                        T052 跨工程：web-admin 占位符呈现
```

---

## 任务总表

| 编号 | 任务 | 对应 REQ / AC | 依赖 | 产出文件 |
|---|---|---|---|---|
| T001 | `installer/cjpm.toml` 工程配置 | AC-030~032 | — | `installer/cjpm.toml` |
| T002 | `main.cj` 入口与子命令分派 | AC-001~004 | T001 | `src/main.cj` |
| T003 | CLI 参数解析 `cli/args.cj` | AC-001, AC-117~120 | T001 | `src/cli/args.cj` |
| T004 | 机器可读报告 `cli/report.cj` | REQ-RNI-066~070 / AC-148~165 | T003 | `src/cli/report.cj` |
| T005 | 日志/JSON/脱敏工具 | AC-006, AC-140 | T001 | `src/util/{log,json_out,redact}.cj` |
| T006 | 子进程超时强杀 `subprocess_timeout.cj` | AC-007~011 | T001 | `src/platform/subprocess_timeout.cj` |
| T007 | 进程表查询 `process_table.cj` | AC-012~015 | T006 | `src/platform/process_table.cj` |
| T008 | 环境变量读写 `envvars.cj` | AC-016~019 | T006 | `src/platform/envvars.cj` |
| T009 | 端口/网络探测 `net.cj` | AC-020~022 | T006 | `src/platform/net.cj` |
| T010 | 路径解析 `paths.cj` | AC-023~025 | T001 | `src/core/paths.cj` |
| T011 | 安装状态 `state.cj` | REQ-RNI-045~050 / AC-100~110 | T010 | `src/core/state.cj` |
| T012 | 三级降级探测 `probe.cj` | REQ-RNI-012~017 / AC-033~045 | T006, T009 | `src/platform/probe.cj`（v1.8 由 `src/core/` 下沉，见 design §4.2.4） |
| T013 | 原子安装 `atomic.cj` | REQ-RNI-030~035 / AC-070~080 | T010 | `src/core/atomic.cj` |
| T014 | Windows 文件占用处理 `winfs.cj` | AC-081~086 | T013 | `src/core/winfs.cj` |
| T015 | HTTP 引导服务 `bootstrap.cj` | REQ-RNI-005~008 / AC-023~029 | T002 | `src/http/bootstrap.cj` |
| T016 | 路由注册 `routes.cj` | AC-026~029 | T015 | `src/http/routes.cj` |
| T017 | 静态向导托管 `static_site.cj` | AC-027 | T015 | `src/http/static_site.cj` + `assets/install/*` |
| T018 | `handlers/env.cj`（check-environment，HTTP 通道） | AC-033~045 | T012 | `src/http/handlers/env.cj`（v1.8 起只做封装，实现在 `src/services/envcheck.cj`） |
| T019 | `handlers/config.cj`（save/load/test-config） | REQ-RNI-018~023 / AC-046~060 | T027 | `src/http/handlers/config.cj` |
| T020 | `handlers/status.cj`（service-status） | REQ-RNI-024~026 / AC-061~066 | T007, T009 | `src/http/handlers/status.cj` |
| T021 | `handlers/admin.cj`（create-admin 真路径） | REQ-RNI-036~041 / AC-087~099 | T028 | `src/http/handlers/admin.cj` |
| T022 | `handlers/runtime.cj`（install/start runtime） | REQ-RNI-027~029 / AC-067~069 | T031, T032 | `src/http/handlers/runtime.cj` |
| T023 | `handlers/envfile.cj`（save/read runtime env） | REQ-RNI-042~044 / AC-090~095 | T029 | `src/http/handlers/envfile.cj` |
| T024 | `handlers/ssl.cj`（generate/save-ssl） | REQ-RNI-051~054 / AC-111~116 | T030 | `src/http/handlers/ssl.cj` |
| T025 | `handlers/process.cj`（进程治理） | REQ-RNI-055~058 / AC-121~130 | T007 | `src/http/handlers/process.cj` |
| T026 | `handlers/devkit.cj`（DevKit 端点） | REQ-RNI-059~065 / AC-131~147 | T035 | `src/http/handlers/devkit.cj` |
| T027 | 直连 PostgreSQL `db.cj` | AC-046~050, AC-088 | T001 | `src/services/db.cj` |
| T028 | bcrypt 与 `$2a$` 归一 `bcrypt_admin.cj` | REQ-RNI-038 / AC-005, AC-112 | T001 | `src/services/bcrypt_admin.cj` |
| T029 | `.env` 行级 in-place 更新 | REQ-RNI-042 / AC-090~093 | T010 | `src/services/envfile_service.cj` |
| T030 | openssl 证书 `ssl_service.cj` | REQ-RNI-051~053 / AC-111~114 | T006 | `src/services/ssl_service.cj` |
| T031 | 离线介质解压 `media.cj` | REQ-RNI-031 / AC-071~076 | T014 | `src/services/media.cj` |
| T032 | SDK 引导下载 + 校验 `download.cj` | REQ-RNI-009~011 / AC-030~032 | T006 | `src/services/download.cj` |
| T033 | 编排器（断点续装）`orchestrator.cj` | REQ-RNI-045~050 / AC-100~110 | T011, T013 | `src/core/orchestrator.cj` |
| T034 | 安装器自退役 | REQ-RNI-071~074 / AC-155~165 | T033 | `src/core/orchestrator.cj`（增补） |
| T035 | DevKit 组件注册表 `devkit/registry.cj` | REQ-RNI-059~061 / AC-131~140 | T027 | `src/services/devkit/registry.cj` |
| T036 | DevKit 安装 `devkit/install.cj`（含 DK-3 clone） | REQ-RNI-071~077 / AC-166~187 | T035, T032 | `src/services/devkit/install.cj` |
| T037 | DevKit 自检 `devkit/verify.cj` | AC-141~147 | T035 | `src/services/devkit/verify.cj` |
| T038 | 开发环境初始化 `devkit/init.cj` | REQ-RNI-062~065 / AC-148~154 | T036, T049 | `src/services/devkit/init.cj` |
| T039 | 导出/脱敏策略文件与加载器 | REQ-RNI-092~097, 101, 105 / AC-220~223, 248~252, 260~261 | T027 | `sql/seed/export-policy.json`、`sql/seed/sanitize-policy.json`、`src/services/seed/policy.cj` |
| T040 | 引号感知 SQL 词法扫描器 | REQ-RNI-078~080 / AC-188~196 | T001 | `src/services/seed/scanner.cj` |
| T041 | 分层导出器（T-A~T-F） | REQ-RNI-092~094, 098 / AC-220~223, 240~242 | T039, T040 | `src/services/seed/exporter.cj` |
| T042 | 脱敏器（R1~R4 + keepVerbatim） | REQ-RNI-101, 103, 105 / AC-248~252, 256~261 | T039 | `src/services/seed/sanitizer.cj` |
| T043 | 身份匿名化与孤儿策略 | REQ-RNI-078~087, 091 / AC-188~219, 244 | T039, T040 | `src/services/seed/identity.cj` |
| T044 | 六条导出门禁 | REQ-RNI-093, 099 / AC-224~226, 243~244, 252 | T041~T043 | `src/services/seed/guards.cj` |
| T045 | CLI：`db export` 子命令 | REQ-RNI-095~097 / AC-227~239 | T044 | `src/cli/db_export.cj` |
| T046 | Seed 导入器（占位符解析） | REQ-RNI-081~084, 102 / AC-197~207, 253~255 | T040, T047 | `src/services/seed/importer.cj` |
| T047 | 账号二元组与 RBAC 补种 | REQ-RNI-089, 090 / AC-210~216 | T027, T028 | `src/services/seed/rbac.cj` |
| T048 | 导入后校验（零悬空 + 菜单非空） | REQ-RNI-085~087 / AC-208~209 | T046 | `src/services/seed/verify.cj` |
| T049 | CLI：`seed apply` / `seed verify` | REQ-RNI-081 / AC-197~200 | T046~T048 | `src/cli/seed_cmd.cj` |
| T050 | 出包布局与 `start-installer.bat` | REQ-RNI-031 / AC-071~076 | T034 | `release/`、`start-installer.bat` |
| T051 | 端到端验收（全新环境） | 全部 AC | T050 | 验收报告 |
| T052 | **跨工程**：web-admin 占位符呈现"未配置" | AC-255 | T046 | `apps/web-admin/src/**`（另立任务） |
| T053 | NDJSON 流式进度输出 | AC-262~266 | Phase 1 | `installer/src/cli/progress.cj` |
| T054 | **runtime 侧**：运行日志读取端点（M2·豁免 1/2） | AC-267/270 | T001 | `runtime/src/app/**`（跨子工程） |
| T055 | **runtime 侧**：运行环境检测端点（M2·豁免 2/2） | AC-268 | T001 | `runtime/src/app/**`（跨子工程） |
| T056 | 安装器 `serve --manage` 承接启停（M3） | AC-271 | T053 | `installer/src/serve/manage.cj` |
| T057 | **跨工程**：web-admin 管理页适配 + 状态判定修正（修 N-4） | AC-269~271 | T054/T055/T056 | `apps/web-admin/src/**`（另立任务） |
| T058 | **runtime 侧**：修复健康状态"假绿灯"（N-5） | AC-272~274 | T001 | `runtime/src/app/main.cj`（跨子工程） |

---

## Phase 0：工程骨架与 CLI（T001~T005）

### T001 `installer/cjpm.toml` 工程配置

- **目标**：建立可独立于根工程构建的 executable 子工程。
- **对应**：AC-030（不修改既有依赖的 `compile-option`）、AC-031、AC-032（不动根 `cjpm.toml`）。
- **要点**：
  - `[package]`：`cjc-version = "1.1.3"`、`name = "uc_installer"`、`output-type = "executable"`、`compile-option = "-O2 --dy-std -Woff all -Woff unused"`。
  - `[dependencies]`：`http_lib` / `kaca_json` / `json4cj` / `logcj` / `pgsql` / `blowfish` / `jinguissl` / `jinguissl_core` / `compress4cj` / `quic_cj` / `kaca_cookies`；**热路径逐个显式带 `-O2`**（path-dependency 不继承父级 `compile-option`）；`blowfish` 必须 `-O2 --int-overflow=wrapping`。
  - `[target.x86_64-w64-mingw32.bin-dependencies]` 的 stdx `path-option` 必填。
- **验收**：`cjpm build` 通过（**人工执行**）；根 `cjpm.toml` 未被修改（`git diff` 为空）。
- **红线**：本文件为**新建**，不得回写根工程。

### T002 `main.cj` 入口与子命令分派

- **目标**：统一入口，支持两组用法——① 无参启动 = HTTP 引导服务（默认 :3000）；② 子命令 = `check-environment` / `install` / `devkit install` / `db export` / `seed apply` / `seed verify` / `rollback` / `uninstall`。
- **对应**：AC-001~004。
- **要点**：`--json` 模式下**只**输出机器可读 JSON（不得混入人类可读文本）；`--truthful` 语义新建。
- **验收**：`ucInstaller.exe --json check-environment` 输出可被 JSON 解析；退出码符合 §4.11 退出码表。

### T003 CLI 参数解析 `cli/args.cj`

- **目标**：解析 `--port` / `--offline` / `--force` / `--rollback` / `--json` / `--truthful` / `--with-devkit` / `--devkit-only` / `--sdk-path` / `--auto-exit` / `--system-env` / `--source-dir` / `--db` / `--user` / `--password`。
- **对应**：AC-001、AC-117~120。
- **验收**：未知参数 → 退出码非 0 并给出修复建议；`--json` 下错误信息也是 JSON。

### T004 机器可读报告 `cli/report.cj`

- **目标**：统一 `--json` 报告骨架（status / steps / items / diagnostics / remediation），供 DevKit 与 seed 各子命令复用。
- **对应**：REQ-RNI-066~070 / AC-148~165。
- **要点**：`degraded` 标记逐项可见；**禁止静默降级**（git 缺失、网络不可达都必须出现在报告里）。
- **验收**：每个失败项都带 `remediation` 字段（可执行的修复命令或指引）。

### T005 日志 / JSON / 脱敏工具 `util/{log,json_out,redact}.cj`

- **目标**：日志落文件、JSON 序列化、日志脱敏。
- **对应**：AC-006、AC-140。
- **要点**：`redact.cj` 负责在日志与 `--json` 输出中遮蔽口令/密钥/令牌（**本工程自己不输出明文凭据**，这是 §8.1 的落地）。
- **验收**：在 `.env` 中放一个 `TEST_SECRET=xxx` 后跑任意子命令，日志中不出现 `xxx`。

---

## Phase 1：平台层（T006~T009）

### T006 子进程超时强杀 `platform/subprocess_timeout.cj`

- **目标**：带超时的子进程执行，超时强杀（含子进程树），避免 hang。
- **对应**：AC-007~011。
- **要点**：
  - `std.process.executeWithOutput` 有 `workingDirectory!` / `environment!`，**无 `timeout!`** ⇒ 超时必须自建。
  - `environment!` 会**整体替换**环境变量，必须自基底：`HashMap(getVariables())` 再增改。
  - `git clone` 必须设 `GIT_TERMINAL_PROMPT=0` 等防卡 stdin。
- **验收**：执行 `ping -n 20 127.0.0.1` 设 2 s 超时 → 2 s 内返回且进程被杀净。

### T007 进程表查询 `platform/process_table.cj`

- **目标**：`tasklist` 解析，判定 runtime 进程存活。
- **对应**：AC-012~015。

### T008 环境变量读写 `platform/envvars.cj`

- **目标**：读写用户/系统环境变量（`CANGJIE_HOME` / `CANGJIE_STDX_PATH` / `PATH`）。
- **对应**：AC-016~019。

### T009 端口与网络探测 `platform/net.cj`

- **目标**：端口占用检测、可达性探测。
- **对应**：AC-020~022。

---

## Phase 2：核心层（T010~T014）

### T010 路径解析 `core/paths.cj`

- **目标**：安装目录 / 介质目录 / 备份目录 / 开发者源码目录（`devSourceDir`）的统一解析。
- **对应**：AC-023~025、AC-175/186/187（`devSourceDir` 与 `releaseDir` 互不嵌套）。
- **要点**：进入 DevKit 初始化前断言两目录互不嵌套，违反即不进入（R-23）。

### T011 安装状态 `core/state.cj`（`.install-state.json`）

- **目标**：断点续装的状态持久化。
- **对应**：REQ-RNI-045~050 / AC-100~110。
- **要点**：schema 严格按 design §4.5；`devkitComponents` 逐组件记录状态。

### T012 三级降级探测 `platform/probe.cj`

- **目标**：版本命令 → 端口 → 进程 三级降级，记录 `probe.method`。
- **对应**：REQ-RNI-012~017 / AC-033~045。
- **要点**：**如实标记**——探测手段降级必须在结果里体现，不得冒充"版本命令探测成功"。
- **位置订正（v1.8）**：原落 `src/core/probe.cj`，现下沉到 `src/platform/probe.cj`。原因：`core → cli` 已存在依赖边（`core/ctx.cj` 用 `CliArgs`），而 `check-environment` 的 CLI 子命令必须复用探测能力，留在 `core` 会让 `cli → core` 成环。唯一消费者是 `services/envcheck.cj`（design §4.2.4）。

### T013 原子安装 `core/atomic.cj`

- **目标**：staging + 原子切换；失败可回滚。
- **对应**：REQ-RNI-030~035 / AC-070~080。

### T014 Windows 文件占用处理 `core/winfs.cj`

- **目标**：被占用文件延迟删除（重命名 + 重启删除）。
- **对应**：AC-081~086。

---

## Phase 3：HTTP 引导服务（T015~T026）

### T015 HTTP 引导服务 `http/bootstrap.cj`

- **目标**：起 `:3000`，托管静态向导，CORS `*`。
- **对应**：REQ-RNI-005~008 / AC-023~029。
- **要点**：
  - 基座是 **`libs/http_lib`**（`src/app/core/server/HTTPServer.cj:4-6`），**不是** `hyperion`（TCP 框架）——R-01 的事实纠错。
  - `/healthCheck` **严格返回 `success`**（`apps/web-admin/public/install.js` 依赖此字面值）。
- **验收**：`curl http://localhost:3000/healthCheck` 返回含 `success`；跨域请求带 `Access-Control-Allow-Origin: *`。

### T016 路由注册 `http/routes.cj`

- **目标**：17 个端点路由。
- **对应**：AC-026~029。

### T017 静态向导托管 `http/static_site.cj` + `assets/install/*`

- **目标**：托管 `install.html` / `install.js` / `install.css`。
- **对应**：AC-027。
- **要点**：复用 `apps/web-admin/public/install.js` 的既有形态（源地址硬编码 `http://localhost:3000`）。

### T018~T026 各 handler

逐个实现 9 类 handler，分别对应上表所列 REQ/AC。共同的**实现红线**：

- 所有 handler 的错误必须进 `--json` 报告（不能只写日志）；
- `create-admin`（T021）**必须真实落库**，删除假路径（闸口 ②）；
- `devkit.cj`（T026）的降级必须**显式**，禁止静默（R-22）。

---

## Phase 4：服务层（T027~T032）

### T027 直连 PostgreSQL `services/db.cj`

- **目标**：建库、建表（执行基线 SQL）、参数化读写。
- **对应**：AC-046~050、AC-088。
- **要点**：值一律参数化；默认库名 **`uctoo`**（闸口 / REQ-RNI-088）。

### T028 bcrypt 与 `$2a$` 归一 `services/bcrypt_admin.cj`

- **目标**：生成 cost 10 的哈希，**写库前把前缀改写为 `$2a$`**。
- **对应**：REQ-RNI-038 / AC-005（单次哈希 ≤3 s）、AC-112（目标口径 `$2a$10$`）。
- **红线**：**禁止修改 `libs/blowfish-cj`**（vendored 库 `genSalt` 产出 `$2b$`，见 `bcrypt.cj:247`）；归一在**安装器侧**做。
- **验收**：产出的哈希以 `$2a$10$` 开头；可被 bcryptjs 与仓颉侧双向校验（`Bcrypt.verify` 只取前 29 字符作 salt，不校验前缀）。

### T029 `.env` 行级 in-place 更新 `services/envfile_service.cj`

- **目标**：修改 `.env` 中单个键的值，**保留注释与其它行**。
- **对应**：REQ-RNI-042 / AC-090~093。
- **要点**：`.env` 键正则 `[\w.]+`；值不能含 `#`。

### T030 openssl 证书 `services/ssl_service.cj`

- **目标**：单路径 openssl 调用生成自签证书。
- **对应**：REQ-RNI-051~053 / AC-111~114。
- **要点**：出包时 OpenSSL DLL 必须命名为 `libcrypto-3-x64.dll` / `libssl-3-x64.dll`（stdx 写死文件名，机器装 4.x 会 100% 失败）。

### T031 离线介质解压 `services/media.cj`

- **目标**：用系统 `tar.exe`（bsdtar）解压 `release/agentskills-runtime-win-x64.tar.gz`。
- **对应**：REQ-RNI-031 / AC-071~076。

### T032 SDK 引导下载 + 校验 `services/download.cj`

- **目标**：官方下载引导、SHA256 校验、断点续传、`--sdk-path` 支持。
- **对应**：REQ-RNI-009~011 / AC-030~032。

---

## Phase 5：编排与自退役（T033~T034）

### T033 编排器（断点续装）`core/orchestrator.cj`

- **目标**：按 `.install-state.json` 续装，失败可重试，不重复已完成步骤。
- **对应**：REQ-RNI-045~050 / AC-100~110。

### T034 安装器自退役

- **目标**：安装完成后 GC 自身（`.installer-gc.json` 协助）。
- **对应**：REQ-RNI-071~074 / AC-155~165。

---

## Phase 6：DevKit（T035~T038）

### T035 DevKit 组件注册表 `devkit/registry.cj`

- **目标**：DK-1~DK-8 的声明、自检判据、期望值、修复命令。
- **对应**：REQ-RNI-059~061 / AC-131~140。
- **要点**：DK-4 的判据是**三条**（表数 + 悬空身份引用 0 + 超管菜单非空），不是"表数 ≈207"。

### T036 DevKit 安装 `devkit/install.cj`（含 DK-3 `git clone` 单路径）

- **目标**：逐组件安装；DK-3 走**唯一路径** `git clone`。
- **对应**：REQ-RNI-071~077 / AC-166~187。
- **要点**：
  - **单路径，无兜底**：git 缺失 → 失败（退出码非 0，提示先安装 git 再重跑）；主地址 `https://atomgit.com/UCToo/agentskills-runtime` 不可达 → 回落镜像 `https://github.com/UCTooCom/agentskills-runtime.git`，仍不可达 → 失败。**不写任何源码文件、不留残缺目录**。
  - 目录三分：不存在 → clone；存在且空 → clone；存在非空且 remote 匹配 → `fetch`（dirty 仅提示不阻断）；非空非本仓库 → **默认拒绝**（仅 `--force-nonempty`）。
  - clone 设 `GIT_TERMINAL_PROMPT=0` 防卡 stdin（注意 `environment!` 整体替换需以 `HashMap(getVariables())` 为基底）。
- **源码红线（R-22）**：安装器源码中**不得出现** `git checkout .` / `git reset --hard` / `git clean` / `.SOURCE_PROVENANCE` / `offline-copy` / `gitHistory` 任何字符串——开发者工作副本只可被 clone/fetch，**绝不可被安装器丢弃改动**。
- **验收**：在非空非本仓库目录执行 → 退出码非 0 且未改动该目录；`--json` 报告中 `gitMissing` / `networkUnreachable` 可区分。

### T037 DevKit 自检 `devkit/verify.cj`

- **对应**：AC-141~147。

### T038 开发环境初始化 `devkit/init.cj`

- **目标**：I1~I9（含 `cjpm build`、`loaddbinfo`、`seed apply`）。
- **对应**：REQ-RNI-062~065 / AC-148~154。
- **要点**：所有子进程的 `workingDirectory!` 取值**恒为 `devSourceDir`**；`skills/devkit_smoke/` 生成在 `<devSourceDir>/skills/` 下，不在 `releaseDir`（R-23）。

---

## Phase 7：Seed 导出（T039~T045）

> 依据 `research-seed-export.md`（含第二轮修订 §3.3.1）与 `research-seed-content.md`。
> **本 Phase 的产物是版本发布用的一次性工具**，不是运行时能力 ⇒ 做成安装器子命令 `ucInstaller.exe db export`（OQ-S4 建议 ①）。

### T039 导出/脱敏策略文件与加载器

- **目标**：`sql/seed/export-policy.json`、`sql/seed/sanitize-policy.json` 及其加载校验。
- **对应**：REQ-RNI-092~097 / 101 / 105；AC-220~223、248~252、260~261。
- **要点**：
  - `defaultTier: "structure-only"` —— **白名单优先、默认拒绝**（整个机制最重要的字段）。
  - `bootstrap`（9 表）：`permissions` / `i18` / `config` / `role_has_permission` / `uctoo_role` / `user_group` / `agent_executors` / `crontab_task_registry` / `lang`。
  - `bootstrapRowPredicates.config = "env_key IS NULL"`（102 → **17**）。
  - `runtime-generated.config = "env_key IS NOT NULL"`（**不导** 85 行）。
  - `sync-derived`：`agents` / `agent_skills` / `db_connection` / `db_info`（**不导**，T-F）。
  - `installer-generated`：`uctoo_user` / `user_has_roles` / `user_has_group` / `agents`。
  - `sanitize-policy.json`：R1 凭据 / R2 环境标识 / R3 保留占位值 / R4 整表降级；**`keepVerbatim`** 含 `config.website.appid` 与 `config.site.API_URL`（**三要素必填**：表/键/理由；理由 = v3 配置项，v4 暂未消费，后续小程序端沿用）。
  - `guards`：`maxFileBytes` / `maxRowsPerTable` / `forbidStatements` / `secretScan`（含 `sk-` `ghp_` `fc-` `postgres://` `jdbc:` `eyJ` `$2a$` `$2b$` `BEGIN PRIVATE KEY`）/ `forbidSyncDerivedRows` / `failOnUnsanitizedSensitiveColumn`。
- **验收**：策略缺 `keepVerbatim` 的理由字段 → 判定策略不合法（AC-261）。

### T040 引号感知 SQL 词法扫描器 `seed/scanner.cj`

- **目标**：解析 `uctooDB.sql` 一类的 INSERT 文件，按单元格取值。
- **对应**：REQ-RNI-078~080 / AC-188~196。
- **红线**：**必须引号感知单遍扫描**——实测 **474 条 INSERT 的文本列内嵌换行**，禁止按行切分或按 `);\n` 切分。
- **验收**：构造含 `'` 转义、`\n`、`,`、`)`,`;` 的样例 → 单元格切分正确。

### T041 分层导出器 `seed/exporter.cj`

- **目标**：T-A 结构（226 表）+ T-B 引导（9 表，含行级谓词）+ T-C 示例（`entity` ≤200 行）+ T-D/T-D′/T-E/T-F 不导。
- **对应**：REQ-RNI-092~094 / 098；AC-220~223、240~242。
- **要点**：
  - `CREATE TABLE IF NOT EXISTS`（旧基线 206 条 `DROP TABLE` 是 Navicat 默认值，**不继承**）。
  - `ORDER BY` 主键 ⇒ **确定性**（两次导出 diff 为空）；时间戳只落文件头，不落 SQL 体内。
  - 流式分页读，逐行生成 INSERT。
  - **体量目标**：≈0.87 MB（原 105.3 MB 的 0.83%）。
- **验收**：产物中不存在 `INSERT INTO …"agent_skills"` / `"db_connection"` / `"db_info"` / `"uctoo_user"`。

### T042 脱敏器 `seed/sanitizer.cj`

- **目标**：R1~R4 四条规则 + `keepVerbatim` + `is_sensitive` 回填。
- **对应**：REQ-RNI-101 / 103 / 105；AC-248~252、256~261。
- **要点**：
  - **执行顺序**：R3（已是占位值 → 保留）**先行** → R1（凭据/密钥/令牌 → `{{secret:<kind>}}`）→ R2（环境标识 → `{{env:<kind>}}`；时间戳 → `{{ts:epoch}}`）→ R4（不可脱敏且 NOT NULL → 整表降级为仅结构）。
  - `keepVerbatim` **只对 R2 生效**；**R1 不受豁免**（不允许以"历史配置项"为由保留真实密钥）——这条写死防滥用。
  - 敏感列判定：**清单为主 + 正则为辅**；正则命中但清单未收录 → 报告列出供人工确认，**不得**直接按敏感处理（实测 `*total_tokens` / `prompt_tokens` / `completion_tokens` / `avg_tokens` 是误命中）。
  - 回填 `config.is_sensitive = true`，并在报告中列出被标记条目。
- **验收**：产物中不含 `ghp_` / `sk-` / `fc-` / `postgres://`；`website.appid` 与 `site.API_URL` 保持原值。

### T043 身份匿名化与孤儿策略 `seed/identity.cj`

- **目标**：身份引用 → 占位符；孤儿按策略处理。
- **对应**：REQ-RNI-078~087 / 091；AC-188~219、244。
- **要点**：
  - **双命名空间**：`{{principal:<ref>}}` → `uctoo_user.id`；`{{agent:<ref>}}` → `agents.id`。
  - **红线**：`agent_id` 列指向 `agents.id`，**不是** `uctoo_user.id`；搞反会静默写错、运行期才炸。
  - 判定必须**双条件**（列名属于声明集合 **且** 取值命中主体清单）——非身份 uuid 极多（`permissions.parent_id` 2190、`db_info.id` 2913），单条件会误伤。
  - 身份列类型混杂 uuid / varchar(36) ⇒ 校验须 `::text` 归一。
  - 保留集内身份引用实测 **392 处 / 8 组表.列 / 2 个主体**，全在 `creator` 一列。
  - 孤儿默认策略 **`fail`**；`entity.creator` 的 33 行 test1 数据按 `map-to: super_admin` 显式覆盖（须在报告逐条可见）。
  - **注意**：`entity.creator` 在本机库已有 FK `Entity_creatorId_fkey → uctoo_user(id)`，该约束进入基线后未处置的 33 行会直接导入失败。
- **验收**：产物中身份列不含裸 uuid；报告中孤儿处理条目逐条可见。

### T044 六条导出门禁 `seed/guards.cj`

- **对应**：REQ-RNI-093 / 099；AC-224~226、243~244、252。
- **六条**：① 体积/行数上限；② 破坏性语句扫描（`DROP TABLE` / `TRUNCATE` / `DELETE FROM`）；③ 敏感形态扫描；④ **脱敏生效校验**（敏感列值必须为占位符）；⑤ **同步残留校验**（放行表中不得有 `source_path` 非空的行）；⑥ 身份列裸 uuid 残留 + 外键自洽。
- **要件**：任一不过 → **导出失败，不覆盖既有产物**。

### T045 CLI：`db export` 子命令

- **目标**：串起 E0~E7 流水线，含 **E7 临时库重放验真**。
- **对应**：REQ-RNI-095~097；AC-227~239。
- **要点**：E7 在**临时库** replay，断言三条：表总数一致、悬空身份引用 == 0、超管菜单树非空；不过则**作废产物**。
- **验收**：`--json` 报告含每表导了什么、为什么、被 orphanPolicy 处理了几条、被脱敏/保留/降级了哪些。

---

## Phase 8：Seed 导入（T046~T049）

### T047 账号二元组与 RBAC 补种 `seed/rbac.cj`（**先于 T046**，因占位符解析依赖超管 id）

- **目标**：建立 2 个账号并完成全部绑定。
- **对应**：REQ-RNI-089 / 090；AC-210~216。
- **顺序不可颠倒**：

  ```
  A1 uctoo_user     超管（user_type='human'）              ← create-admin 真路径
  A2 uctoo_user     主 agent 账号（user_type='agent'，password=不可登录随机串）
  A3 user_has_roles 超管 → 超管角色（2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d，持 '*'）
  A4 user_has_roles 主 agent → agents 角色（a686ff1f-7fb4-48df-8609-2b2d5267c682）
  A5 user_has_group 主 agent → user_group(code='agents')
  A6 agents         MainAgent 实体（agent_type='MAIN'，status=1，user_id=A2.id）
     + 回填 A2.agent_id = A6.id
  ```

- **红线**：A6 需要 A2 的 id，A2.agent_id 需要 A6 的 id ⇒ **A2 → A6 → UPDATE A2.agent_id**。
- **验收**：`uctoo_user.agent_id` 与 `agents.user_id` **双向非空且一致**（AC-214）；`uctoo_user` 中不出现 `liming`/`wangfang`/`chenwei`/`liuyang`/`zhaoxue`/`test1`（AC-215/216）。

### T046 Seed 导入器 `seed/importer.cj`

- **目标**：解析占位符并落库（**字符串级重写，零 UPDATE**）。
- **对应**：REQ-RNI-081~084 / 102；AC-197~207、253~255。
- **要点**：
  - `{{principal:super_admin}}` → 解析为 A1 的真实 id；`{{agent:main}}` → 解析为 A6 的真实 id。
  - **`{{secret:…}}` / `{{env:…}}` 绝不解析、绝不猜值填充**——原样入库（AC-254）。
  - 引号感知扫描（复用 T040）。
  - 重复执行 → 幂等（识别已存在主体，报告"复用"，不产生第二个超管）。
- **验收**：导入后 `creator` 列悬空引用 == 0。

### T048 导入后校验 `seed/verify.cj`

- **目标**：三判据 + 菜单非空。
- **对应**：REQ-RNI-085~087；AC-208~209。
- **判据**：① 表总数一致；② 身份列悬空引用 == 0；③ **超管菜单树非空**（这一条最关键——裸 `psql -f` 会一路报成功但菜单是空的）。

### T049 CLI：`seed apply` / `seed verify`

- **对应**：REQ-RNI-081；AC-197~200。

---

## Phase 9：出包与端到端验收（T050~T052）

### T050 出包布局与 `start-installer.bat`

- **目标**：`ucInstaller.exe` + 全部 DLL + 离线介质 + 启动脚本。
- **对应**：REQ-RNI-031；AC-071~076。
- **要点**：OpenSSL DLL 必须命名为 `libcrypto-3-x64.dll` / `libssl-3-x64.dll`；所有 DLL 与 exe **同目录**，避免 PATH 依赖。

### T051 端到端验收（全新环境）

- **目标**：在一台**干净机器**（无 Node、无 runtime、无数据库数据）跑完整流程。
- **验收矩阵**（逐条打勾，不能只跑主路径）：

  | 类别 | 断言 |
  |---|---|
  | 引导服务 | `/healthCheck` 返回 `success`；17 端点全通；CORS `*` |
  | 环境检测 | 三级降级如实标记；`--json` 报告可解析 |
  | 管理员 | `uctoo_user` 真实落库；哈希以 `$2a$10$` 开头；单次哈希 ≤3 s |
  | 账号二元组 | 恰好 2 个账号；双向指针非空一致；主 agent 可自动登录 |
  | Seed 导入 | 悬空引用 0；菜单树非空；`agent_skills` / `db_connection` 无导入数据 |
  | 脱敏 | 产物无 `ghp_`/`sk-`/`postgres://`；`website.appid` 原值保留 |
  | 自退役 | 安装完成后安装器自身被清理 |
  | **失败路径** | 断网 → 明确失败而非降级；git 缺失 → 明确失败；非空非本仓库目录 → 拒绝 |

### T052 **跨工程**：web-admin 占位符呈现"未配置"

- **归属**：`apps/web-admin`（**不在 installer 工程内**，需另立任务单）。
- **目标**：凡值匹配占位符形态（统一 `{{ }}` 包裹）一律显示"未配置"并给补齐入口。
- **对应**：AC-255。
- **前置**：T046 保证占位符形态统一且导入期不解析。

---

## Phase 10：流式进度与运维能力归位（T053~T057）

> **闸口依据**：用户已拍板 **OQ-D1（NDJSON 纳入）** 与 **OQ-D7（M2 立项，冻结区有限豁免）**，并明确"nestJs 完全退役是本工程目标"。
> **范围红线**：M2 的冻结区豁免**仅限两个端点**（日志读取、环境检测）。状态与配置**复用既有**接口，不得另建第二套。

### T053 NDJSON 流式进度输出 `cli/progress.cj`

- **目标**：在 `--json`（结束时一行）之外，提供 `--progress=ndjson` 流式形态，供宿主进程实时渲染进度。
- **对应**：REQ-RNI-106 / AC-262~266。
- **契约**：
  - `stdout`：每行一个完整 JSON 事件对象，可独立解析，**禁止跨行**；
  - **末行**必须含最终退出码与终态摘要（缺失即判"未正常结束"）；
  - `stderr`：诊断/告警/错误详情**只走 stderr**，不得混入 stdout 事件序列；
  - `--progress=ndjson` 与 `--json` **互斥**，同时指定即参数冲突拒绝执行（AC-265）；
  - 事件必须按发生顺序输出，**禁止**缓冲至结束时一次性吐出（AC-266）。
- **验收**：宿主按行解析可完整还原进度；中途 kill 进程时不产出终态行，消费方判"未正常结束"。
- **注意**：这与 L3 插件"stdout 是 RPC 独占通道"的红线不冲突——本项是**安装器主进程**的 CLI 输出，非插件进程。

### T054 **runtime 侧**：运行日志读取端点（M2 · 冻结区豁免 1/2）

- **归属**：`apps/agentskills-runtime/src/app/`（**跨子工程，需用户编译 runtime 主工程**）。
- **目标**：暴露运行系统自身日志，供运维界面"日志查看"面板取数。
- **对应**：REQ-RNI-107 / AC-267、AC-270。
- **日志源**：`logs/agentskills-runtime.log`（`main.cj:1094`）与 `logs/startup-trace.txt`（`main.cj:44`）。
- **硬约束**：**不得以业务数据表（`crontab_log` / `llm_usage_logs`）查询替代**进程运行日志（AC-267 明令禁止）。
- **红线**：只读、分页、限量；不得暴露日志目录外的任意文件（防目录穿越）。

### T055 **runtime 侧**：环境能力采集器 + 运维检测端点（M2 · 冻结区豁免 2/2）

> **⚠️ 不另起炉灶**：用户指出环境探测**已有需求**，见 `.codeartsdoer/specs/system-env-capability/spec.md`
> （2026-09-16，"设计稿，待实现"，`src/` 与 `skills/` 源码零命中）。该规格的消费者是**大模型/主 Agent**
> （产物 `./runtime/capabilities.json` + 注入系统提示词），运维面板的消费者是**人** ——
> **两个消费者、同一类探测能力**。因此本任务 = **实现唯一采集器**，运维端点复用其结果。

- **归属**：`apps/agentskills-runtime`（采集器 + `src/app/` 端点；**跨子工程，需用户编译 runtime 主工程**）。
- **目标**：运维期可确认数据库、版本管理工具、磁盘空间、端口占用等项；同时产出供智能体消费的能力清单。
- **对应**：REQ-RNI-107 / AC-268；REQ-RNI-109 / AC-275~276。
- **做法**：
  1. 实现 `system-env-capability` 采集器（按其 spec §3 探测项：OS/架构、shell、浏览器、LLM 能力 `vision` 等、必需环境变量缺失、已装工具与技能）；
  2. 运维端点**复用**该采集结果，只补运维特有项（数据库连通性、磁盘、端口占用）；
  3. 采集部分失败返回"部分能力未知"并**继续启动**（AC-276，该 spec §5 降级要求）；
  4. 复用 `Config.modelCapabilities` / `Config.modelSupportsVision()`，**不得**另立模型能力真相（该 spec §4）。
- **红线（R-42）**：**禁止**为"给大模型看"和"给人看"维护两份探测清单。
- **注意**：**不得**把 Node.js 列为必需项（仓颉 runtime 不依赖 node；`nestJs/setup.service.ts:25-60` 的错误判据不得照抄）。
- **与安装器侧的关系**：安装器的环境检测面向"能否安装"，本任务面向"当前环境具备什么能力"；
  两侧**探测项口径对齐 §6.3**，避免同一台机器给出两个互相打架的结论。

### T056 安装器 `serve --manage`：承接启停（M3）

- **目标**：补齐 M2 **原理上做不了**的部分——进程的启动/停止/重启。
- **对应**：REQ-RNI-107 / AC-271。
- **铁律**：**启停必须由运行系统之外的管控者提供**。安装器本来就 spawn runtime，天然是父进程；**禁止**让 runtime 宣称可自行停止并重启自身。
- **形态**：`ucInstaller.exe serve --manage [--port 3000]`，仅挂载运维端点，**不做安装流程**；用毕即退（保留"零常驻"卖点）。
- **注意**：PC 客户端**不需要**本项——它已有自己的管控者（`runtime.ts:317 isRunning()`）。

### T057 **跨工程**：web-admin 管理页适配与状态判定修正

- **归属**：`apps/web-admin`（另立任务单）；可与 T052 合并推进。
- **目标**：让 `setup.vue` 的四个面板在"M2 自述 + M3 启停"组合下全部可用。
- **对应**：AC-269、AC-270、AC-271。
- **内容**：
  1. 面板取数改指 runtime（状态/配置**复用既有** `/api/v1/health` 与 `/api/v1/uctoo/config/*`，日志/环境走 T054/T055 新端点）；
  2. 增加"管控后端未运行"态：请求失败时提示 + 「启动管理后端」拉起入口（对应 AC-271 的异常场景 3）；
  3. **修 N-4**：服务存活判定不得再按进程名字符串匹配（`nestJs/setup.service.ts:340-351` 用 `tasklist /FI "IMAGENAME eq node.exe"` 匹配不到 `magic.app.exe`，状态显示本身就是错的）。
- **注意 `farm.config.ts:48-58`**：dev 期 `/api` 代理 `:3000`，需同步确认新端点路由不被代理规则误伤。

### T058 **runtime 侧**：修复健康状态"假绿灯"（N-5）

- **归属**：`apps/agentskills-runtime/src/app/main.cj`（**跨子工程，需用户编译 runtime 主工程**）。
- **目标**：让 `/api/v1/health` 的 `chatModel.available` 反映**真实可用性**，而不是恒为 `true`。
- **对应**：REQ-RNI-108 / AC-272~274。
- **现状（源码实证）**：
  - `main.cj:706-713` 判据为 `if (_chatModel.isNone())`；
  - `main.cj:239` 与 `:448` 恒赋值 `_chatModel = Some(LazyChatModel(modelName))`；
  - `lazy_chat_model.cj:27-29` 的 `init` 只存模型名字符串、**构造永不抛错**，真实实例在请求边界才 `resolve()`；
  - ⇒ **`_chatModel` 永远 `Some` ⇒ `available` 永远 `true`**，通道全挂也显示正常。
- **根因**：T010 把 `_chatModel` 从"真实实例"改为"惰性解析器"，但 health 的判据**语义未同步**。
- **修复方向**：判据改为探测**通道实际可用性**（按 `ChannelRegistry` 解析默认通道是否成功 / 探针健康态），
  **不得**用"对象是否构造出来"代替（AC-272）。
- **验收（AC-273 硬性）**：构造一个通道全失效的场景（如清空注册表或置所有 provider 失效），
  该字段**必须**报 `available:false`。报 `true` 即判定未修复。
- **连带复查（AC-274）**：凡依赖 `_chatModel` "是否已就绪"语义的消费点都要同步复核
  （`main.cj:655/661/671` 的路由注册分支等），避免同类语义漂移残留。

---

## OUT-OF-SCOPE（明确不做，移交其他方）

| 项 | 说明 | 去向 |
|---|---|---|
| `ConfigSyncHandler` 敏感值遮蔽 | 现状：`.env` 明文密钥无过滤写进 `config.value` 且 `is_sensitive` 恒 `false`（实测 102 行全 false，含 `ghp_…`、`sk-…`、含密码连接串） | **移交 runtime**：应支持按 `is_sensitive` 遮蔽、敏感键不同步进库。本工程只在导出期做防御性脱敏与回填 |
| 占位符呈现层 | 见 T052 | web-admin 前端 |
| Stage B（L3 薄适配器） | 本期不做 | 后续可选 |
| **runtime 发行包同步收归脚本 + SHA256 校验**（OQ-D3 / 缺口 N-1） | runtime 打好的 419 MB 包目前**手工复制**给 PC 客户端，两份副本已差 39 MB；用户拍板"记录到 PC 客户端工程目录，后续完善 PC 客户端时再落地实现" | **已记录**至 `apps/pc-client/docs/RUNTIME_PACKAGE_SYNC_TODO.md`；**本工程不实现**，但须在 PC 集成前完成（安装器进包后版本错配风险放大） |
| NestJS 其余 10 个 Controller 的能力补齐 | OQ-D6 已拍板 **NestJS 全部退役**（runtime 已全部实现对应功能） | 若 T057 核对发现某 Controller 实际未被覆盖，**先补实现再退役**；不得留缺口退役 |

---

## 人工执行清单（AI 不执行，需用户操作）

| # | 时机 | 动作 |
|---|---|---|
| M-1 | Phase 0 后 | `cd apps/agentskills-runtime/installer && cjpm build`，回传日志 |
| M-2 | 每个 Phase 结束 | 同上；若改动了依赖 `compile-option`，用 `cjpm clean && cjpm build` 全量重编 |
| M-3 | Phase 7 完成 | `ucInstaller.exe db export --json` 生成 `sql/uctooDB.sql`，人工 diff 检查产物（应 ≈0.87 MB） |
| M-4 | Phase 7 完成 | 在临时库 replay 验真（E7），确认三条断言 |
| M-5 | Phase 8 完成 | 在全新数据库跑 `seed apply`，确认菜单树非空、账号恰好 2 个 |
| M-6 | Phase 9 | 干净机器端到端跑一轮，按 T051 验收矩阵逐条打勾 |
| M-7 | Phase 10（T054/T055 完成后） | **runtime 主工程** `cd apps/agentskills-runtime && cjpm build`，回传日志（M2 改动落在 `src/app/`，属冻结区豁免项，编译须人工执行） |
| M-8 | Phase 10（T057/T058 完成后） | 在**已安装环境**验证四面板：状态与 `magic.app.exe` 实际存活一致、日志可取、检测项无 Node.js、点"停止/启动"经 M3 管控者生效；**并补三项实测**：① **N-5**（`chatModel.available` 在通道失效场景须报 false —— T058 硬性验收）；② **OQ-D4**（PC 端首次登录主 agent 自动登录成功，确认 N-2 已消除）；③ **OQ-D5**（PC 冷启动实测，与 ≤60 s 指标比对，**以实测为准不改指标**） |

---

## 附录：任务 ↔ 防回退约束对照

| 防回退 | 落地任务 |
|---|---|
| R-01（HTTP 基座 = `http_lib`，非 `hyperion`） | T015 |
| R-20（`blowfish` 必须 `-O2`） | T001 |
| R-21（bcrypt 归一 `$2a$`，不改 vendored 库） | T028 |
| R-22（DK-3 单路径；源码禁现 `git checkout .` / `reset --hard` / `clean` / `.SOURCE_PROVENANCE` / `offline-copy` / `gitHistory`） | T036 |
| R-23（`devSourceDir` 与 `releaseDir` 互不嵌套；子进程 cwd 恒为 `devSourceDir`） | T010、T038 |
| R-24~R-28（SIC：身份重绑定、零悬空、RBAC 补种） | T043、T046~T048 |
| R-30（不创建演示账号） | T047 |
| R-31（主 agent 双向指针） | T047 |
| R-32（`defaultTier = structure-only`） | T039 |
| R-33（无 `DROP TABLE`、无 `db_info` 派生数据） | T041、T044 |
| R-34（同步派生表不导 + `forbidSyncDerivedRows`） | T039、T041、T044 |
| R-35（`config` 行级谓词 `env_key IS NULL`） | T039、T041 |
| R-36（脱敏强制 + `failOnUnsanitizedSensitiveColumn`） | T042、T044 |
| R-37（占位符不解析、呈现层识别） | T046、T052 |
| R-38（敏感列清单为主，正则误命中须人工复核） | T042 |
| R-39（启停不得由 runtime 自举；管控者外置） | T056、T057 |
| R-40（M2 豁免仅限两端点；状态/配置复用既有；禁业务表冒充日志；禁列 Node.js） | T054、T055、T057 |
| R-41（健康状态不得用"惰性壳子是否拿到"代替实际可用性） | T058 |
| R-42（环境探测唯一实现，复用 `system-env-capability`） | T055 |
