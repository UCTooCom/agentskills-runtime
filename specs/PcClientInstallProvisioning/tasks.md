# PC 客户端安装工程优化 —— 任务规划

**关联需求**：`spec.md`
**关联设计**：`design.md`
**生成日期**：2026-10-21 ｜ **版本**：v2.0（按用户决策改为「首次运行自助建号 + seed 占位替换初始化」）｜ **状态**：草稿（待 gate-task 确认）

---

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：仓颉（installer 侧）→ cangjie-coder；前端/Electron（PC 侧）→ web-coder / fullstack-codegen；NSIS → 手写 `.nsh`。
- **二次开发底座优先（迭代 runtime / uctoo 时强制）**：规范以 `uctoo-dev-manual` + `docs/uctoo-v4/*.md` 为准；脚手架优先 `loaddbinfo` → `crudgen`/`plugingen` → `crudweb`；本工程大多数改动在 installer 与 PC 壳层，不踏入 runtime 业务层。
- **编译约束**：AI **不运行 `cjpm build`**；installer 仓颉代码编译/回传由用户在独立 cmd 环境完成。PC 侧 TypeScript 由用户 `vue-tsc`/构建验证。
- **复用原则**：优先复用既有 `installer-bridge.ts`、`pgsql.ts`、`runtime.ts`、`setup.ts` 与 installer 的 `bcrypt_admin` / `AdminRepo` / `seed apply`，不重造建号与 seed 能力。
- **如实呈现**：installer 退出码 2/6、超时、缺 final 一律如实上报（AC-PCI-022）；不静默降级。
- **回退开关**：新链路失败必须可回退旧 `pgManager` 链路（`useInstaller`）。

---

## 任务总览

| 编号 | 任务 | 关联需求 | 关联设计 | 负责子 agent | 状态 |
|---|---|---|---|---|---|
| T-01 | installer `seed-init` 子命令（hash + 占位替换 + schema + 含管理员 seed） | PC-1 | §3.2/§3.3 | 主 agent (cangjie-coder) | ✅ 已完成 |
| T-02 | 新增 `sql/seed-admin-template.sql`（含 `{{ADMIN_*}}` 占位符） | PC-1 规则3 | §3.3/§4.2 | 主 agent (cangjie-coder) | ⚠️ 已取消（被 T-01 内联建号取代，见偏离记录） |
| T-03 | installer `install --no-data` 空壳安装（跳过 schema/seed/建号） | PC-1/PC-4 | §5.1/§11.1 | 主 agent (cangjie-coder) | ✅ 已完成 |
| T-04 | PC 启动编排：先拉 PG → 检测超管 → 设置页或正常启动 | PC-1/PC-2 | §3.1 | 主 agent (web-coder) | ✅ 已完成 |
| T-05 | `db-probe` 模块（查询超管存在，表不存在按未初始化） | PC-1/PC-3 | §2.2/§3.1 | 主 agent (web-coder) | ✅ 已完成 |
| T-06 | 设置页（SetupView + setup IPC，含强度校验与进度） | PC-3 | §3.4/§5.2 | 主 agent (web-coder) | ✅ 已完成 |
| T-07 | NSIS 覆盖/保留自定义页 + 覆盖时 drop 库 + 写 keepData | PC-4 | §3.5/§11.1 | 主 agent | ✅ 已完成 |
| T-08 | 自动拉起闭环与 R-39 管控者（Phase 4） | PC-2 | §3.6 | 主 agent (web-coder) | ✅ 已完成（R-39 管控者按 design §3.6 留作 Phase 4 收尾，已预留开关点） |
| T-09 | 回退链路与降级（useInstaller / 初始化失败重试） | PC-Rel-2, PC-3 异常 | §8 | 主 agent (web-coder) | ✅ 已完成 |
| T-10 | 端到端实测（首次安装 / 覆盖 / 保留 / 重装 / 失败重试） | 全验收 | — | 用户+主 agent | ⏳ 待用户+主 agent 执行（AI 不跑 cjpm build / git push） |

---

## 任务依赖关系图

```
T-01 (seed-init) ──┐
T-02 (seed 模板) ──┼──▶ T-04 (PC 编排) ──▶ T-08 (自动拉起)
T-03 (install --no-data) ──▶ T-07 (NSIS 覆盖/保留)
T-05 (db-probe) ──▶ T-04
T-06 (设置页) ──依赖──▶ T-04 (展示) + T-01 (提交触发)
T-07 (NSIS) ──▶ T-04 (keepData 决策)
T-09 (回退/降级) ──并行──▶ T-04, T-06
T-10 (E2E) ──末步──▶ 依赖 T-01~T-09 全部完成
```

---

## 任务详细说明

### T-01 installer `seed-init` 子命令
- **目标**：spec PC-1；design §3.2。
- **输入**：既有 `bcrypt_admin`、`services/db.cj::AdminRepo`、`services/seed/*`。
- **步骤**：
  1. `args.cj` 增加 `seed-init` 子命令，参数 `--email --username --name`，`--password` 从 stdin 读一行；
  2. 计算 `hash = bcrypt_admin.hashPassword(password)`；生成 `adminId = uuid()`；
  3. 读 `sql/seed-admin-template.sql`，替换 `{{ADMIN_ID}}/{{ADMIN_EMAIL}}/{{ADMIN_USERNAME}}/{{ADMIN_NAME}}/{{ADMIN_PASSWORD_HASH}}`；
  4. 若 `uctoo` 库不存在则 `createdb uctoo`；导入 `sql/uctooDB.sql`（schema）；执行替换后的 seed-admin 模板；`seed apply`（principal = adminId）；
  5. 退出码 0/2/6 遵循既有契约；`--progress=ndjson` 输出进度。
- **产出**：`installer/src/**`（args + 新增 `seed_init.cj` + 复用 `seed apply`）。
- **验收**：用户提交后 `uctoo_user` 存在录入的超管、密码为 bcrypt 哈希、seed 的 `principal:super_admin` 指向该账号。

### T-02 新增 seed-admin-template.sql
- **目标**：spec PC-1 规则3；design §3.3/§4.2。
- **步骤**：新建 `sql/seed-admin-template.sql`，含管理员 INSERT（占位符）+ `user_role` 超管绑定；字段名对齐 `uctooDB.sql` 实际 DDL；与 seed JSON 的 RBAC 骨架衔接。
- **产出**：`apps/agentskills-runtime/sql/seed-admin-template.sql`。
- **验收**：占位符集完整（5 个）；应用顺序在 schema 之后、seed JSON 之前。

### T-03 installer `install --no-data`
- **目标**：spec PC-1/PC-4；design §5.1。
- **步骤**：`args.cj` 增加 `--no-data` 标志，使 `install` 跳过 S4（schema）/S5（建号）/S6（seed），仅执行 S0~S3（环境 + initdb 空集群 + runtime 部署 + .env）；非 PC 部署仍走完整 `install`。
- **产出**：`installer/src/core/orchestrator.cj`（S4/S5/S6 受 `--no-data` 门控）。
- **验收**：`install --no-data` 后 PG 空集群就绪、无 schema/seed/管理员；完整 `install` 行为不变。

### T-04 PC 启动编排改造
- **目标**：spec PC-1/PC-2；design §3.1。
- **输入**：T-01（seed-init）、T-03（install --no-data）、T-05（db-probe）、T-07（keepData）。
- **步骤**：
  1. `initializeApp()` 先拉起内嵌 PG；
  2. 调 `dbProbe.hasSuperAdmin()`；捕获表不存在异常 → 视为未初始化；
  3. 未初始化 → `showSetupAndWait()`（T-06）；已初始化 → 跳过；
  4. 之后拉起 runtime + WebAdmin + 加载首页；
  5. 失败按 AC-PCI-022 经 `service:startFailed` 上报，并回退旧链路（T-09）。
- **产出**：`electron/main/index.ts` 改造。
- **验收**：未初始化→设置页；初始化后 PG+runtime 自动 running、web-admin 首页可用。

### T-05 db-probe 模块
- **目标**：spec PC-1/PC-3；design §2.2/§3.1。
- **步骤**：新增 `modules/db-probe.ts`，连接 PG，执行 `SELECT 1 FROM uctoo_user WHERE role='super_admin' LIMIT 1`；捕获「表不存在」SQLState(42P01) → 返回 false（未初始化）；带有限重试与超时。
- **产出**：`electron/modules/db-probe.ts`。
- **验收**：库空/表缺 → false；有超管 → true；瞬时 PG 未就绪 → 重试后判定。

### T-06 设置页
- **目标**：spec PC-3；design §3.4/§5.2。
- **步骤**：新增 `SetupView`（本地 HTML/Vue），表单 email/username/name/password + 强度提示 + 显隐切换 + 行内校验；提交经 `setup:submit` IPC → main 调 `installerBridge.runSeedInit(fields, password)`（password 经 stdin）；监听 `setup:progress` 渲染进度；失败经 `setup:failed` 可重试。
- **产出**：渲染层 + `electron/modules/setup.ts` + IPC 注册。
- **验收**：未初始化展示表单；提交后库含超管、设置页不再出现；校验失败不发起提交。

### T-07 NSIS 覆盖/保留页
- **目标**：spec PC-4；design §3.5。
- **步骤**：`build/installer.nsh` 增自定义页（单选覆盖/保留）；覆盖→安装期 `ucInstaller.exe db drop --db=uctoo`（仅留空集群）+ 写 keepData=false；保留→不动库 + 写 keepData=true；调用 `install --no-data` 空壳安装。
- **产出**：`apps/pc-client/build/installer.nsh` + `electron-builder.json` 钩子。
- **验收**：安装出现该页；覆盖后库被清空、首次运行走设置页；保留后库不变、跳过设置页。

### T-08 自动拉起闭环（Phase 4）
- **目标**：spec PC-2；design §3.6。
- **步骤**：确保初始化后 `pgManager.start()` + `runtimeManager.start()`；预留 R-39 经 `ucInstaller.exe serve --manage` 的切换点（开关控制）；设置页期间不拉起 WebAdmin/runtime。
- **产出**：`electron/main/index.ts` + `runtime.ts`。
- **验收**：打开客户端后 PG+runtime 自动 running、web-admin 首页可用、`/api/v1/health` 可达（≤60s，不含用户交互时间）。

### T-09 回退与降级
- **目标**：spec PC-Rel-2、PC-3 异常；design §8。
- **步骤**：`useInstaller=false` 时回退 `pgManager.initialize()`；设置页在 `ucInstaller.exe` 不可用时降级（不阻塞正常使用）；初始化失败保留未初始化态、提供重试。
- **产出**：`electron/main/index.ts` + `setup.ts` + `db-probe.ts`。
- **验收**：旧链路仍可用；installer 缺失时提示而非崩溃；失败可重试。

### T-10 端到端实测
- **目标**：全验收。
- **步骤**：首次安装 / 覆盖安装 / 保留数据 / 重装 / 初始化失败重试 五条路径各跑一遍，核对 PG、runtime、schema、管理员账号、seed、设置页、keepData。
- **产出**：实测报告。
- **验收**：五类场景均符合 spec 验收条件。

---

## 需求覆盖追踪矩阵

| spec 需求 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| PC-1 首次运行自助建号+初始化 | T-01, T-02, T-04, T-06 | 全覆盖 | `seed-init` + 占位替换 |
| PC-1 规则1 触发条件（无超管→设置页） | T-04, T-05 | 全覆盖 | dbProbe 检测 |
| PC-1 规则2 录入字段与约束 | T-01, T-06 | 全覆盖 | email/username/name/password |
| PC-1 规则3 seed 以管理员为 principal | T-02, T-01 | 全覆盖 | 模板→seed apply 顺序 |
| PC-1 规则4 禁止项（不安装期建号/不落盘明文） | T-01, T-03 | 全覆盖 | 移除 provisioning-result.json |
| PC-1 异常：installer 不可用 | T-04, T-09 | 全覆盖 | 回退旧链路 |
| PC-1 异常：退出码 6 | T-01, T-09 | 全覆盖 | AC-PCI-022 |
| PC-1 异常：模板占位符缺失 | T-01, T-02 | 全覆盖 | 退出码 2 |
| PC-1 异常：用户录入校验失败 | T-06 | 全覆盖 | 前端拦截 |
| PC-2 自动启动（PG + runtime） | T-04, T-08 | 全覆盖 | R-39 管控者留开关 |
| PC-2 规则3 未初始化不拉起业务服务 | T-04 | 全覆盖 | 设置页期间延后 |
| PC-2 异常：PG 端口占用 | T-08 | 全覆盖 | syncConfPort 落盘 |
| PC-2 异常：runtime 崩溃 + 重启入口 | T-08 | 全覆盖 | |
| PC-2 异常：启动期端口冲突 | T-08 | 全覆盖 | |
| PC-3 设置页触发条件 | T-04, T-05, T-06 | 全覆盖 | 无超管判定 |
| PC-3 设置页内容（表单+强度+进度） | T-06 | 全覆盖 | |
| PC-3 设置页一次性 | T-04, T-05 | 全覆盖 | 库有超管即跳过 |
| PC-3 异常：能力缺失降级 | T-06, T-09 | 全覆盖 | |
| PC-3 异常：初始化中途失败可重试 | T-06, T-09 | 全覆盖 | |
| PC-3 异常：DB 检测误判 | T-05 | 全覆盖 | 捕获表不存在 |
| PC-4 覆盖/保留选择 | T-04, T-07 | 全覆盖 | NSIS 自定义页 |
| PC-4 保留数据零改动 | T-04, T-07 | 全覆盖 | 不动库 |
| PC-4 覆盖重跑 + 设置页 | T-01, T-06, T-07 | 全覆盖 | drop 库后重走 |
| PC-4 选择持久化 | T-07 | 全覆盖 | provision-state.json |
| PC-4 异常：标记损坏默认覆盖 | T-07 | 全覆盖 | 安全默认 |
| PC-4 异常：drop 库失败 | T-07 | 全覆盖 | 提示先退出客户端 |
| PC-Rel-1 幂等 | T-01 | 全覆盖 | ON CONFLICT DO NOTHING |
| PC-Rel-2 如实呈现 | T-04, T-09 | 全覆盖 | AC-PCI-022 |
| PC-Sec-1 密码强度 | T-06 | 全覆盖 | 强度进度条提示（不强制弱口令可提交） |
| PC-Sec-4 本地管理员声明 | T-06 | 全覆盖 | 设置页顶部声明文案 |
| PC-Sec-2 密码不落盘/stdin | T-01, T-06 | 全覆盖 | 移除明文文件 |
| PC-Sec-3 占位符不猜值 | T-01 | 全覆盖 | installer 现场解析 |
| PC-Comp-1 选择跨版本可识别 | T-07 | 全覆盖 | |
| PC-Comp-2 保留模式跨版本复用 | T-04, T-07 | 全覆盖 | |

---

## 验收检查清单（终验）

- [ ] 首次安装：PG 空集群就绪、无 schema/seed/管理员；首次启动显示设置页。
- [ ] 设置页录入 email/username/name/password → 提交后库含该超管（password 为 bcrypt 哈希）、seed 的 principal 指向该账号。
- [ ] 初始化完成后 runtime + PG 自动 running、web-admin 首页可用、`/api/v1/health` 可达。
- [ ] 重启客户端：因库已有超管，设置页不再出现。
- [ ] 覆盖安装：库被清空、首次运行再走设置页、用户重新建号。
- [ ] 保留数据：库不变、跳过设置页、服务正常拉起。
- [ ] installer 退出码 2/6/超时 如实呈现，不冒充成功。
- [ ] `useInstaller=false` 可回退旧链路；installer 缺失时设置页降级。
- [ ] 安装目录与 `%APPDATA%` 下不存在含明文 password 的文件。
- [ ] NSIS 出现覆盖/保留选项，选择被 PC 正确读取。
- [ ] 编译/类型检查/lint 通过（人工确认）；spec/design/tasks 与实现无漂移。

### 端到端验证场景（T-10 执行清单）

| 场景 | 步骤 | 预期 |
|---|---|---|
| 首次安装 | 全新目录安装（空壳） | PG 空集群就绪，无 schema/seed/超管 |
| 首次启动 | 打开 PC | 设置页展示，录入并提交 |
| 初始化完成 | 提交 | 库含超管 + seed，`/api/v1/health` 可达，首页加载 |
| 重启 | 关闭再打开 | 跳过设置页，直接进首页 |
| 重装-覆盖 | 覆盖安装 | 库清空，首次运行再走设置页 |
| 重装-保留 | 保留数据安装 | 库不变，跳过设置页 |
| 初始化失败 | 模拟 seed-init 退出码非0 | 设置页保持 + 错误 + 重试 |
| 启停失败 | 模拟端口冲突 | 首页不阻塞 + 导航栏异常状态 |

---

## 修订记录

- 2026-10-21 v1.0：基于 STATUS.md 根因分析初稿，覆盖 PC-1~PC-4（安装期随机建号 + 明文凭据方案）。
- 2026-10-21 v2.0：按用户决策改为「安装期不建号、首次运行设置页自助建号 + seed 占位替换初始化」；移除 `provisioning-result.json`、新增 `seed-init` 子命令与 `seed-admin-template.sql`、NSIS 改为空壳安装 + 覆盖时 drop 库。

---

## 偏离记录（实现与原始设计/任务的不一致，须如实保留）

### 偏离 1：T-02 `sql/seed-admin-template.sql` 被 T-01 内联建号取代（design §3.3 / §4.2）
- **原始设计**：installer 读 `sql/seed-admin-template.sql`，替换 `{{ADMIN_*}}` 占位符后执行，再 `seed apply`。
- **实际实现**：`installer/src/cli/seed_init.cj` 直接内联 `ensureSuperAdmin(db, report, adminId, name, username, email, password)`，在仓颉侧用参数化 SQL 写入 `uctoo_user` + `user_has_roles`，**不再读取任何模板文件**。
- **理由**：① 内联参数化 SQL 杜绝占位符替换漏替/误替风险（design §6 强调「占位符不猜值」）；② 建号与 `seed apply` 同源落库（复用 `applySeed` 的 `principal:super_admin` 解析），逻辑自洽；③ 少一个需随 DDL 同步维护的模板文件。
- **影响**：`apps/agentskills-runtime/sql/seed-admin-template.sql` **未创建**。验收时「应用顺序在 schema 之后、seed JSON 之前」由 `seed_init.cj` 的执行序（RAW 导入 uctooDB.sql → ensureSuperAdmin → applySeed）保证。

### 偏离 2：NSIS 不在安装期调用 `ucInstaller.exe install --no-data`（design §5.1 / §10.1 / §11.1）
- **原始设计**：NSIS PostInstall 调用 `ucInstaller.exe install --no-data` 完成空壳初始化。
- **实际实现**：NSIS 仅做「覆盖/保留选择页 + 写 provision-state.json + 覆盖时删除内嵌 PG 数据目录（并尽力尝试 `ucInstaller.exe db drop`）」；空壳初始化（initdb 空集群 + .env）交由 PC 首启的 `ensureEmbeddedPostgres` 完成。
- **理由**：runtime 发行包以 `*.tar.gz` 经 extraResources 发布、于**首次运行**由 `runtime-integrator` 解包，安装期 `ucInstaller.exe` 通常尚不存在；强行调用会因二进制缺失而失败。首启初始化更稳健且符合「安装期零数据」原则。

### 偏离 3：R-39 管控者按 design §3.6 留作 Phase 4（T-08）
- **实际实现**：`startBusinessServices` 已确保 PG + runtime 自动拉起（runtime 由 `runtimeManager.start()` 拉起，`runtimeHealthCheck` 周期探活 `/api/v1/health`）。
- 已预留 `runtime.serveViaInstaller` 开关点（置 true 时记录日志并**降级回 runtimeManager**，因当前 release 的 installer 尚未实现 `serve --manage`）。完整切换待 Phase 4。

### 偏离 4：provision-state.json 仅作诊断记录（design §11.4）
- PC 启动读取 provision-state.json 仅用于日志诊断；**运行时是否展示设置页仍以 `dbProbe.hasSuperAdmin()` 的 DB 探测为准**，不依赖该文件做逻辑分支。覆盖/保留的「清空 vs 不动库」效果在安装期即已落实（删除/保留 PG 数据目录）。

---

## 补丁记录：0.0.30-p2（2026-10-24）首次运行设置页不显示 / 提交报 pg_ctl Permission denied

### 现象
1. 覆盖安装后首次运行未弹出「首次安装设置页」；
2. 重启后设置页出现，提交建号报：
   `内置数据库启动失败：pg_ctl start failed: ... could not open log file "<userData>/pgsql/data/pg.log": Permission denied`。

### 根因
- **孤儿 postmaster**：上轮退出没停干净，残留实例独占 `pg.log`；新实例 `pg_ctl start -l pg.log` 打不开该文件。
- **孤儿成因**：`before-quit` 写成 async 回调，Electron **不等待**它完成 ⇒ `pgManager.stop()` 从未执行完。
- **设置页被覆盖**：窗口创建时已 `loadFile(index.html)`，随后再 `loadFile(setup.html)`，同一 webContents 两次导航竞争，首页常后完成而盖掉设置页。
- **放大项**：自启 `--hidden` 在未初始化时也会 `win.hide()`，用户彻底看不到建号入口。

### 变更（apps/pc-client）
| 文件 | 变更 |
|---|---|
| `electron/modules/pgsql.ts` | `startInternal()` 先 `pg_ctl status` 探测：**已在跑则复用**（端口取自 `postmaster.pid` 第 4 行）；否则清陈旧 pid → 分配端口 → `syncConfPort` → 启动；`pg.log` 打开失败自动退到 `pg-<ts>.log` 重试。新增 `probePostmasterStatus` / `readPortFromPostmasterPid` / `removeStalePostmasterPid` / `pgCtlStart` / `persistRunningState`。 |
| `electron/main/index.ts` | `before-quit` 改 `preventDefault()` + 清理完成后再 `app.quit()`（PG 必定被停）；`showSetupWizard` 等上一次导航结束再切设置页（5s 超时兜底）并 `show+focus`；setup.html 缺失时 `dialog.showErrorBox` 显式告知（原为静默放行）；新增 `setupWizardShown` 压制 `--hidden`；启动编排补关键日志；去掉 `startBusinessServices` 多余实参。 |
| `electron/modules/window.ts` | `createMainWindow(preload, { skipInitialLoad })`：编排层可决定是否预加载首页，从根上消除导航竞态（默认行为不变）。 |
| `electron/utils/logger.ts` | 主进程日志**落盘**到 `<userData>/logs/pc-client-<日期>.log`（GUI 进程 console 全丢弃，此前无任何可信诊断来源）。 |

### 验证
- esbuild transform 四个改动文件通过（未跑 `vue-tsc` / 未出包，按约定由用户执行 `pnpm build:pc`）。
- 现场处置：`pg_ctl -D <userData>/pgsql/data -w stop` 停掉孤儿实例后，旧包即可继续提交建号。

---

## 补丁记录：0.0.30-p3（2026-10-24）首次启动不弹设置页 / 端口显示 5432 / 提交报 installer 退出码 1

### 现象
1. 覆盖安装后首次启动**停在 website 首页**，设置页不出现；左侧 runtime / 数据库均显示未启动；
   数据库页端口显示 5432（本机 5432 被独立 PostgreSQL 占用，内嵌实例实际在 5433）。
2. 重启后设置页出现，提交建号报「安装失败（installer 退出码 1）」。

### 根因（三条，互相独立）
- **① 启动编排挂死（最关键）**：`execCommand` 只监听子进程 `close` 事件；Windows 下
  `pg_ctl start` 派生的 postmaster **继承 stdio 句柄**且常驻不退 ⇒ 管道永不关闭
  ⇒ `close` 永不触发 ⇒ `startInternal()` 永不返回。日志实证：`pg_ctl start` 之后
  到用户退出之间 **2.5 分钟零日志**，PG 其实已经起来了，但编排再也走不到设置页那一步。
- **② 进度输出解析全废**：`--progress=ndjson` 名不副实，installer 吐的是**跨多行缩进的 JSON**；
  逐行 `JSON.parse` 全部失败 ⇒ events=0、`final` 解析不到 ⇒ `missingFinal=true`、
  退出码与 diagnostics 全丢，用户只看到干巴巴的「退出码 1」。
- **③ 新二进制从未被解压**：`isRuntimeExtracted()` 只判断 `agentskills-runtime.exe` 是否存在。
  覆盖安装后该文件仍在 ⇒ 命中"已解压"跳过 ⇒ 包内 `ucInstaller.exe`（10-23 20:31）
  一直没解出来，磁盘上跑的仍是 10-21 17:26 的旧二进制 ⇒ "修了没生效"。
- **④（installer 侧，见 release-notes-0.0.30 的 p2）**：事务内一条 DDL 失败毒化整个事务。

### 变更（apps/pc-client）
| 文件 | 变更 |
|---|---|
| `electron/modules/pgsql.ts` | `execCommand` 改为以 `exit` 为准 + 150ms 冲刷窗口 + 10 分钟硬超时（`close` 先到则立即结束）；`getDataDir()` 开始消费一直空置的 `config.pgsql.embedded.dataDir`（留空则回落默认） |
| `electron/modules/installer-bridge.ts` | 新增 `drainJsonObjects()` / `findObjectEnd()`：按**顶层 JSON 对象边界**（深度计数 + 字符串转义判定）切流，单行 NDJSON 与多行美化 JSON 通吃；`consumeStdoutLine` → `consumeStdoutObject` |
| `electron/modules/runtime-integrator.ts` | 新增 `needsExtraction()`（归档指纹 size+mtime ≠ 解压标记 / 缺 ucInstaller / 无标记 → 重解）+ `writeIntegrity()`；`doIntegrate()` 改用它；`fallbackDownload()` 成功也落标记（避免无内置包时每次启动重复下载） |
| `electron/main/index.ts` | `ensureRuntimeProvisioned` 不再用「文件存在」本地短路，改由 `runtimeIntegrator.needsExtraction()` 判定 |
| `electron/utils/logger.ts` | 日志文件名与时间戳改用**本地时间**（原为 UTC，10-24 凌晨的日志落在 `pc-client-2026-10-23.log`，按日期找不到） |

### 验证
- esbuild transform 全部通过（未跑 `vue-tsc` / 未出包）。
- 新的 JSON 流解析器用**真实 installer 输出**、按 7 字节极端分块喂入验证：
  3 个事件全解析、`missingFinal=false`、退出码正确取到 1（旧实现为 events=0）。
- 端到端复现（临时 PG 集群 + 包内 installer）已确认 ④ 的完整错误链，并已在 installer 侧修复（待用户编译）。

### 现场处置
- 已把包内的新版 `ucInstaller.exe` 直接换入 `<userData>/runtime/win-x64/release/bin/`（旧版备份移至 `%TEMP%`），
  无需重新编译即可先跑一轮；下次启动 `needsExtraction()` 亦会自动重新解压。

---

## 补丁记录：0.0.30-p4（2026-10-24）数据目录跟随安装盘 + 启动引导页

### 需求
1. 默认数据库数据目录应与**应用安装盘**一致（用户把客户端装到 D 盘，数据却仍在 C 盘 userData）。
2. 首次安装/启动存在长耗时任务时，应先显示 loading 页，等任务跑完再显示设置页；
   不要"先显示 website 首页、再切成设置页"（视觉上来回跳）。
   参考模板：`apps/web-admin/src/views/exception/`。

### 根因（对应现象）
- 数据目录硬编码 `path.join(app.getPath('userData'), 'pgsql', 'data')`：
  与安装位置无关，永远落在 `%APPDATA%`（C 盘）。
- 入口导航两次：createMainWindow 先 `loadFile(index.html)`，主进程随后 `loadFile(setup.html)`，
  同一 webContents 上两次导航竞争，表现就是"首页闪一下再跳到设置页"（p2 只做了"等上一次导航结束"的缓解，
  视觉上仍是两次切换）。

### 变更（apps/pc-client）
| 文件 | 变更 |
|---|---|
| `electron/utils/paths.ts` | 重写。新增 `installDir`（`path.dirname(app.getPath('exe'))`）、`installDrive`、**`dataRoot`**；`pgsqlData`/`pgsqlBackup` 改基于 dataRoot；导出 `setDataRoot()` |
| `public/loading.html`（新增） | 启动引导页：五阶段步进条 + 进度条 + 当前说明 + 失败态 + 打开日志目录 + 3 分钟静默兜底提示 |
| `electron/modules/window.ts` | 入口收敛为 `RendererEntry='home'\|'loading'\|'setup'\|'none'`；新增 `loadEntry()` / `resolveEntryHtml()`（替代 `resolveIndexHtml`）；`createMainWindow` 支持 `entry` + `autoShow`；`loadHome()` 在 `autoShow=false` 时不再强行显示窗口 |
| `electron/preload/index.ts` | 新增 `bootstrap.onProgress`（`bootstrap:progress`） |
| `electron/main/index.ts` | 新增 `sendBootstrap()` / `warnLegacyDataDir()`；启动一律先进 loading 页；编排：数据库 → 探测 → （未初始化）解压 Runtime → 一次性切 setup/home；`startBusinessServices` 补进度上报 |
| `electron/modules/config.ts` | `AppConfig` 新增可选 `dataRoot`（显式覆盖，留空走安装盘规则） |

### dataRoot 解析规则
把 userData 的路径结构**换盘映射**到安装盘（目录语义不变，只换盘）：
```
C:/Users/alice/AppData/Roaming/<app>  +  安装盘 D:/   →   D:/Users/alice/AppData/Roaming/<app>
```
回退链：显式覆盖（`setDataRoot()` / config.dataRoot）→ 安装盘映射（须 mkdir + 写探针通过）
→ 原 userData。安装盘与 userData 同盘时零变化。
⚠️ `utils/paths.ts` 不 import configStore（utils → modules 会成环），配置覆盖由 main 注入。

### 红线
- **启动编排只导航一次**：耗时前置任务期间一律停留在 loading.html，完成后一次性切到最终入口，
  杜绝"首页 → 设置页"的来回跳。
- 旧数据目录（userData/pgsql/data）**不自动搬迁**（跨盘搬 PG data 中断即损坏），只在日志里给出指引：
  把 `pgsql.embedded.dataDir` 指向旧路径，或停库后手工迁移。
- `runtimeHome` 暂仍留在 userData（几百 MB 二进制，是否一并迁到 dataRoot 待定）。

### 验证
- esbuild transform：`main/index.ts`、`window.ts`、`paths.ts`、`preload/index.ts`、`config.ts` 全通过。
- loading.html 脚本语法通过；其 stage key 集合与 main 里 `sendBootstrap` 的 stage 集合**完全一致**（脚本比对，missing=[]）。
- 真实路径实测换盘映射：`D:/Users/patrick/AppData/Roaming/agentskills-runtime-pc` 父目录存在且可写（写探针通过）。

## 补丁记录：0.0.30-p5（2026-10-24）「装哪个盘，全部产物就落哪个盘」

### 需求（用户确认）
安装目录是用户自选的，因此**用户选了哪个盘，Runtime、内嵌 PG、日志、技能、凭据等全部产物
都应在那个盘**——p4 只把 `pgsql/data` 迁到安装盘，其余仍写 C 盘，不符合预期。

### 变更（apps/pc-client）
| 文件 | 变更 |
|---|---|
| `electron/utils/paths.ts` | 新增 `runtimeBackups` / `skills` / `auth` / `provisionStateFile` 四个 dataRoot 下 getter；`runtimeHome`、`logs`、`envFile` 改基于 `dataRoot`；导出 `FILE_PROVISION_STATE` |
| `electron/utils/logger.ts` | `logDir` 改动态 getter（dataRoot 由启动早期注入，构造期固化会写错盘）；新增 `resetLogFile()` |
| `electron/main/index.ts` | `setDataRoot()` 后调 `logger.resetLogFile()`；日志打印 dataRoot/pgsql/runtime/logs 四个真实路径；`warnLegacyDataDir()` 扩展为四项遗留探测（数据库 / Runtime / 技能 / 备份） |
| `electron/modules/auth-bridge.ts` | 凭据目录 → `Paths.auth` |
| `electron/modules/env-generator.ts`、`runtime.ts` | `SKILL_INSTALL_PATH` / 技能目录 → `Paths.skills` |
| `electron/modules/runtime-version.ts` | 备份根目录 → `Paths.runtimeBackups` |
| `electron/modules/provision-state.ts` | 写 dataRoot、读时 dataRoot 优先 + userData 兜底（NSIS 写的是 userData） |
| `electron/modules/tray.ts` | 「打开数据目录」→ `Paths.dataRoot` |
| `electron/modules/pgsql.ts` | 注释同步（默认落 dataRoot，不再是"与安装盘无关"） |
| `build/installer.nsh` | **修覆盖安装清库失效**：新增 `ResolvePcDataRoot`（与 paths.ts 同规则换算安装盘数据根），覆盖时 dataRoot 与 userData 两处 `pgsql` 都清；`ucInstaller.exe` 优先取 dataRoot 下路径；provision-state 写两处 |
| `public/setup.html` | 新增「数据保存位置」展示（读 `system:getPaths` 的 dataRoot），让用户在建号前就知道数据落哪 |

### 落在 dataRoot 的产物（全部跟随安装盘）
```
<dataRoot>/pgsql/data        内嵌 PostgreSQL 集群
<dataRoot>/pgsql/backup      数据库备份
<dataRoot>/runtime/<plat>/   Runtime 本体（含 ucInstaller、.env）
<dataRoot>/runtime-backups/  版本回滚备份
<dataRoot>/skills/           技能包（SKILL_INSTALL_PATH）
<dataRoot>/logs/             主进程日志
<dataRoot>/auth/             本地登录态
<dataRoot>/provision-state.json
```
**唯一留在 userData 的：`config.json`**（它保存 dataRoot 本身，必须在解析 dataRoot 之前
就能从固定位置读到，否则鸡生蛋）与 `window-state.json`（KB 级 UI 状态）。

### 红线
- **NSIS 与 PC 的 dataRoot 换算规则必须逐字一致**（`$INSTDIR` 盘符 + `$APPDATA` 去盘符 + app 名）。
  一旦分叉，覆盖安装会清错目录 → 旧库还在 → 设置页不弹（正是 p3 现象）。
- 旧目录残留只告警不删除：跨盘搬 PG data 中断即损坏，删除属于用户数据处置，交用户决定。
- 迁移后首次启动会重新解压 Runtime（新目录为空 → `needsExtraction()` 为真），这是预期行为。

### 验证
- esbuild transform：10 个改动文件全通过。
- `installer.nsh` 改后仍为 UTF-8 无 BOM；旧函数 `WriteProvisionState_False/True` 已无残留引用。

## 补丁记录：0.0.30-p6（2026-10-24）Runtime 启动即崩溃 0xC0000135：缺 libplugin_spi.dll

### 现象
管理员建号 + 数据库初始化都成功，但 Runtime 起不来；手动拉起也是崩，自动重启仍崩。
主进程日志只有 `Runtime exited with code=3221225781`，stdout/stderr 全空。

### 定性
- `3221225781 = 0xC0000135 STATUS_DLL_NOT_FOUND`：进程在**加载期**就死，进不到 main。
- 解析 `agentskills-runtime.exe` 导入表（63 个直接导入）→ 唯一缺失 `libplugin_spi.dll`。
- 该 DLL 在 `release/plugin_spi/` 下，**没进 `release/bin/`**；Windows 只搜 exe 同目录。
- 补进 bin 后实测正常启动（监听 8080、注册 833 条路由）→ 根因确证。

### 根因
`src/scripts/package_release/main.cj` 用**手写清单**逐包拷 DLL 到 bin，
`plugin_spi`（L3 插件轨 SPI 契约包，path 依赖 / dynamic 产物）**未登记** ⇒ 漏拷。
本地 `target/release/bin` 同样缺失 ⇒ cjpm 也不会自动拷。

### 变更
| 仓 | 文件 | 变更 |
|---|---|---|
| pc-client | `electron/utils/pe-imports.ts`（新增） | 自写 PE 导入表解析（只读文件头）+ `isSystemDll()` |
| pc-client | `electron/modules/dep-manager.ts` | `ensureRuntimeDlls()`：导入表 → 找 bin 缺失 → 从 `release/<包>/` 补齐；`findDllUnderRelease()`（深度 3，跳过 bin） |
| pc-client | `electron/modules/runtime.ts` | spawn 前 `ensureRuntimeDlls()`；exit 时对 0xC0000135 输出可读诊断并自动补齐 |
| pc-client | `electron/main/index.ts` | 修 IPC 报错：`runtimeCrashRecovery.resetAutoRestartCount` → `runtimeHealthCheck.resetAutoRestartCount` |
| runtime | `src/scripts/package_release/main.cj` | ① `extraDeps` 加 `plugin_spi`；② 新增通用兜底：遍历 `target/release/*` 把 bin 里缺的 DLL 补进 bin（不覆盖），命中时提示"有新增依赖未登记" |

### 红线
- 0xC0000135 类故障：先看退出码判族，再解析导入表，别在配置/数据库/端口上浪费轮次。
- 手写清单不可靠 ⇒ 打包侧必须有兜底补齐；PC 侧必须有启动前自愈（已装用户无需重下 Runtime）。
- 出包后唯一可信验活 = 跑 `exe help`。

### 验证
esbuild 4 个改动文件通过；PE 解析在真实 exe 上实测 63 imports、正确报出缺失并定位来源；
补 DLL 后 exe 实测可启动。
