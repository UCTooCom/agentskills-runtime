# 研究文档：PC 客户端安装工程优化（PcClientInstallProvisioning）

> 阶段：research
> 工程：`specs/PcClientInstallProvisioning`
> 日期：2026-10-21 · 版本 v1.0 · 状态：草稿（待 gate-research 确认）
> 方法：`.codeartsdoer/skills/sdd` 研究步；结论均经 installer / pc-client 源码实证（非估算）

---

# 一、用户原始需求（摘编 + v2 决策修订）

用户安装 `AgentSkills Runtime-Windows-0.1.0-Installer.exe` 后，PC 客户端仅 web 服务可用，内嵌 runtime 与数据库无法通过界面启动、数据库无法初始化。初始期望（v1）是「安装期自动建管理员 + seed + 欢迎页展示随机凭据」。

**v2 决策修订（本工程最终采用）**：用户进一步决定**不在安装期自动建管理员、不用 seed 初始化数据库**；改为**首次运行 PC 客户端时，在设置/欢迎页由用户自行录入 email/username/name/password，提交时替换 seed SQL 中的占位符，再初始化数据库**。对应四条期望修订为：

1. **安装期只备空壳**：安装仅完成环境 + 内嵌 PG 空集群 initdb + runtime 部署 + 生成 .env，**不导入 schema、不导入 seed、不建管理员**。
2. **打开即用**：用户打开 PC 客户端后，内置数据库与 runtime 自动启动服务（初始化完成后）。
3. **首次运行设置页（兼具欢迎页）**：首次运行（或覆盖安装后首次运行）检测到库未初始化时，展示设置页供用户自行创建管理员账号并初始化数据库。
4. **重装选择**：重装时可选覆盖安装（drop 库 → 重新走设置页）或保留已有数据（不动库 → 跳过设置页）。

> 复核三份既有 spec：`PcClientInstallerIntegration`、`RuntimeNativeInstaller`、`.codeartsdoer/specs/pc_desktop_client`（见本工程 `STATUS.md` 根因分析）。本工程不是重复造轮子，而是补齐「安装期只备空壳 + 首次启动期由用户自助建号并完成 seed 初始化」的确定性闭环。

---

# 二、范围

- **In Scope**：NSIS 安装后钩子、管理员自动创建、seed 自动导入、PC 启动时自动启停、欢迎页面、重装数据保留选择、凭据产物契约。
- **Out of Scope**：installer 自身能力重造（复用已有）、web-admin 业务功能、runtime 内部逻辑、runtime 版本升级（属 `PcClientInstallerIntegration` Phase 4 长期托管）。
- **关键约束**：复用 installer 已有 `bcrypt_admin` + `AdminRepo` + `seed apply` + `serve --manage`；不新建数据库表（SDD 铁律 9）；AI 不跑 `cjpm build`。

---

# 三、与既有相关工程的关系

| 工程 | 路径 | 关系 |
|---|---|---|
| RuntimeNativeInstaller | `specs/RuntimeNativeInstaller/` | **上游供给方**：installer 已实现 `bcrypt_admin`（哈希）、`AdminRepo`（落库）、`seed apply/verify`（seed 导入）、`serve --manage`（启停管控）、`install` CLI（S0~S8 编排）。本工程复用这些能力，仅在 S5 新增「自动建号 + 写凭据产物」。 |
| PcClientInstallerIntegration | `specs/PcClientInstallerIntegration/` | **并行工程**：负责 PC 委托层（Phase 3 已落盘）与托管层（Phase 4 待做）。本工程与 Phase 4 交集——PC 启停经 `serve --manage` 管控是共同目标。 |
| pc_desktop_client | `.codeartsdoer/specs/pc_desktop_client/` | **历史基线**：定义了 PC 客户端架构（含 `pgsql.ts`/`setup.ts`/`runtime-integrator.ts`）。本工程在其上补齐「安装后自动初始化 + 首次欢迎 + 自动启停 + 覆盖保留」。 |

---

# 四、存量可复用基础设施盘点（经源码实证）

## 4.1 installer 侧（仓颉原生安装器）

- `installer/src/services/bcrypt_admin.cj`：仅 `hashPassword(plain)` / `verifyPassword(plain,hash)`（bcrypt cost 10，前缀归一 `$2a$10$`）。**注意：不落库、不建号**，只是被建号动作复用的哈希工具（已 grep 全量确认无 INSERT）。
- `installer/src/services/db.cj`（`AdminRepo`）：提供 `insertAdmin(name,username,email,password)` / `existsByEmail` / `existsByUsername` / `verifyStoredPassword` —— **真正的建号落库入口**，被 HTTP 处理器调用。
- `installer/src/http/handlers/admin.cj::createAdminHandler`（L14-75）：**真·建号处理器**——读 `.env` 连接串 → 查重 → `AdminRepo.insertAdmin` 落库 `uctoo_user` → 写后回读自校验；路由注册于 `routes.cj` L64（`POST create-admin`）。随 `buildRouter` 挂载，故 `serve --manage`（运维管控 HTTP 服务，仅回环监听）与安装引导服务均暴露此端点。
- `installer/src/services/seed/{importer,rbac,verify}.cj`：seed 导入 + RBAC 权限骨架 + 身份重绑定（`{{principal:super_admin}}` 解析为 A1 超管行）。**直接复用**：S6 自动串接。
- `installer/src/cli/seed_cmd.cj`：`seed apply` / `seed verify` CLI。**直接复用**。
- `installer/src/serve/manage.cj`：`serve --manage` 运维管控模式（T056），只挂运维端点（含 `start-runtime`/`stop-runtime`/`restart-runtime`/`create-admin`），不推进 S0~S8，仅回环监听。**直接复用**：PC 启动时调此命令管控 runtime/PG 启停。
- `installer/src/core/orchestrator.cj`：S0~S8 编排。**S5 仅做闸口+handoff**（见 `STATUS.md` 六），本工程在 S5 内新增「自动建号 + 写凭据产物」分支。

## 4.2 PC 客户端侧（Electron）

- `apps/pc-client/build/installer.nsh`：NSIS 安装脚本钩子。**改造复用**：增加安装后执行 + 重装选择。
- `apps/pc-client/electron/modules/config.ts`：已有 `runtime.autoStart` / `pgsql.embedded.autoStart` 配置项。**改造复用**：确保 autoStart 默认 true 并接通启停逻辑。
- `apps/pc-client/electron/modules/pgsql.ts`：内嵌 PG 初始化/启停/连接测试。**降级复用**：Phase 4 完成后改为调 `serve --manage`，旧逻辑保留为 fallback（开关 `useInstaller`）。
- `apps/pc-client/electron/modules/runtime-integrator.ts`：runtime 解压 + `getRuntimeBinPath()`。**直接复用**：获取 `ucInstaller.exe` 路径（同目录 `release/bin/`）。
- `apps/pc-client/electron/modules/setup.ts`：安装向导编排。**改造复用**：增加首次欢迎页面分支。
- `apps/pc-client/electron/modules/installer-bridge.ts`：Phase 3 已落盘 `runInstall()`（即 `ucInstaller.exe install --progress=ndjson --no-serve`）、`runSeedApply()`。**改造复用**：新增 `runProvision(opts)` 封装 `--auto-admin [--keep-data]`。
- `apps/pc-client/electron/main/index.ts::initializeApp()`（L550-722）：启动编排。**改造复用**：embedded 分支从裸 `pgManager.initialize()` 改走 installer 委托（兑现 PcClientInstallerIntegration G-1）。

## 4.3 数据资源

- `apps/agentskills-runtime/sql/uctooDB.sql`：数据库 schema（1MB）。**直接复用**：installer S4 导入。
- `apps/agentskills-runtime/sql/seed/*.json`：seed 主体清单 + 权限骨架。**直接复用**：installer S6 导入。
- `apps/pc-client/resources/defaults/default-config.json`：默认配置（runtime port 8080, pgsql embedded port 5432, autoStart true）。**直接复用**。

---

# 五、能力缺口分析

| 缺口 | 现状 | 待建（本工程范围，v2） | 复用/新建 |
|---|---|---|---|
| 安装期只备空壳 | `install` 当前会跑 S4/S5/S6（schema/建号/seed） | `install --no-data` 跳过 S4/S5/S6，仅 S0~S3（环境+空集群+runtime+.env） | 改造 installer `install` 加 `--no-data` 门控 |
| 首次运行自助建号 + seed | `install`/`S5` 不自动建号（仅 handoff 给不存在的端点） | 新增 `seed-init` 子命令：hash + 占位替换 + schema + 含管理员 seed + seed apply | 新建 `seed_init.cj`（复用 `AdminRepo`/`bcrypt_admin`/`seed apply`） |
| seed 模板占位符 | seed SQL 无管理员占位符 | 新增 `sql/seed-admin-template.sql`（含 `{{ADMIN_*}}`） | 新建模板文件 |
| 首次运行检测 + 设置页 | PC 无「是否初始化」检测、无设置页 | Electron 检测超管 → 展示设置页（SetupView）+ IPC | 新建 `db-probe.ts` + `SetupView` + `modules/setup.ts` |
| PC 启动时自动启停 | Phase 4 托管层未完成 | PC 启动调 `serve --manage` 拉起 runtime + PG（初始化完成后） | 改造 `index.ts` + `pgsql.ts`（保留旧链路 fallback） |
| 重装数据保留选择 | NSIS 无保留选项 | NSIS 增加覆盖/保留单选 + 覆盖时 drop 库 + 写 `provision-state.json` | 改造 `installer.nsh` |
| 首次/重装检测 | PC 无区分 | `dbProbe.hasSuperAdmin()` 实时查库（权威）+ `provision-state.json` 兜底 | 新增 `modules/db-probe.ts` |

---

# 六、推荐工程方案

### 6.1 总体形态（纯编排层，v2）

本工程**不新建任何仓颉建号/seed 能力、不新建数据库表**，只做：
1. installer `install` 增加 `--no-data` 门控（PC 安装走空壳）
2. installer 新增 `seed-init` 子命令（复用 `AdminRepo`/`bcrypt_admin`/`seed apply`，按用户录入值经占位符替换初始化）
3. 新增 `sql/seed-admin-template.sql`（含 `{{ADMIN_*}}` 占位符）
4. Electron 主进程改造（先拉 PG → 检测超管 → 设置页或正常启动 → 自动启停）
5. Electron 渲染进程新增设置页（SetupView）
6. NSIS 改造（空壳安装 + 重装覆盖/保留 + 覆盖时 drop 库）

### 6.2 核心编排草图

```
【安装时】
NSIS Installer
  ├─ 解压文件（electron-builder 原有）
  ├─ 检测是否已有安装（IfFileExists "$INSTDIR\AgentSkills Runtime.exe"）
  │   ├─ 首次安装 → 默认空壳
  │   └─ 重装 → 弹出选择：覆盖 / 保留
  ├─ if (覆盖): 执行 ucInstaller.exe db drop --db=uctoo（仅留空集群）→ 写 keepData=false
  ├─ if (保留): 不动库 → 写 keepData=true
  └─ 执行 ucInstaller.exe install --no-data --no-serve --progress=ndjson
        ├─ S0~S3: 环境检查 + 空集群 initdb + runtime 部署 + 生成 .env
        └─ (跳过 S4 schema / S5 建号 / S6 seed)

【PC 客户端首次启动】
Electron main
  ├─ 拉起内嵌 PG（供检测/初始化）
  ├─ dbProbe.hasSuperAdmin()
  │   ├─ 无超管 → 展示设置页(SetupView)
  │   │     用户录入 email/username/name/password → 提交
  │   │     → ucInstaller.exe seed-init --email --username --name (--password 走 stdin)
  │   │         ├─ bcrypt(password) → hash
  │   │         ├─ 替换 seed-admin-template.sql 的 {{ADMIN_*}}
  │   │         ├─ createdb uctoo(若缺) + 导入 uctooDB.sql schema
  │   │         ├─ 导入含管理员 seed + user_role 绑定
  │   │         └─ seed apply (principal = 新建管理员 id)
  │   │     → 初始化完成 → 标记
  │   └─ 有超管 → 跳过
  ├─ 拉起 runtime（serve --manage 或 runtimeManager.start）
  ├─ 启动 web-admin HTTP 服务
  └─ 加载首页
```

### 6.3 复用决策（机制勘误后）

| 复用项 | 来源 | 方式 |
|---|---|---|
| 管理员落库 | `installer/services/db.cj::AdminRepo.insertAdmin` | `seed-init` 内部直接调用（无 HTTP 往返） |
| 管理员哈希 | `installer/services/bcrypt_admin.cj::hashPassword` | `seed-init` 建号时复用 |
| seed 导入 | `installer/services/seed/*` | `seed-init` 串接 |
| 启停管控 | `installer/serve/manage.cj` | PC 调 `ucInstaller.exe serve --manage` |
| runtime 路径 | `pc-client/electron/modules/runtime-integrator.ts` | `getRuntimeBinPath()` 取同目录 `ucInstaller.exe` |
| 安装委托 | `pc-client/electron/modules/installer-bridge.ts` | 扩展 `runSeedInit()` / `runBareInstall()` |
| NSIS 钩子 | `pc-client/build/installer.nsh` | 改造增加空壳安装 + 重装选择 + drop 库 |

> 注：installer 也暴露 `POST /setup/create-admin` HTTP 端点（真·建号），本工程 `seed-init` 直接复用其同源落库 `AdminRepo.insertAdmin`（等价且更直接，无本地 HTTP 往返），不依赖该端点、也不调用它。彻底绕开「runtime 缺 `POST /api/setup/create-admin` 端点」的真实缺口。详见 `STATUS.md` 第六节。

---

# 七、需新建的最小集合

| 文件 | 类型 | 说明 |
|---|---|---|
| `pc-client/build/installer.nsh`（改造） | NSIS 脚本 | 空壳安装 + 重装覆盖/保留选择 + 覆盖时 drop 库 |
| `pc-client/electron/main/index.ts`（改造） | TypeScript | 先拉 PG → 检测超管 → 设置页/正常启动 → 自动启停 |
| `pc-client/electron/modules/db-probe.ts`（新建） | TypeScript | `hasSuperAdmin()` 实时查库（表不存在按未初始化） |
| `pc-client/electron/modules/setup.ts`（新建） | TypeScript | 设置页 IPC（submit/progress/failed）+ 调 `runSeedInit` |
| `pc-client/src/views/SetupView`（新建） | Vue/HTML 组件 | 设置页，录入 email/username/name/password |
| `installer/src/core/orchestrator.cj`（改造） | 仓颉 | `install` 增 `--no-data` 门控；新增 `seed-init` 子命令 |
| `installer/src/seed/seed_init.cj`（新建） | 仓颉 | hash + 占位替换 + schema + 含管理员 seed + seed apply |
| `sql/seed-admin-template.sql`（新建） | SQL 模板 | 含 `{{ADMIN_*}}` 占位符 |

---

# 八、关键设计决策与风险

1. **管理员建号时机（D-A）**：决策为 **首次运行由用户在设置页录入，installer `seed-init` 内部调 `AdminRepo.insertAdmin`**，不依赖 runtime 端点、不依赖安装期自动建号。
2. **凭据保密（D-B，已消解）**：不再落盘明文密码；password 经 stdin 传入 installer，bcrypt 后即丢弃，不写日志/文件。`provisioning-result.json` 从本工程移除。
3. **自动启停方式（PC-2）**：初始化完成后 PC 调 `ucInstaller.exe serve --manage`（运维管控，仅回环）；填补 PcClientInstallerIntegration Phase 4 缺口。设置页期间不拉起 WebAdmin/runtime。
4. **重装数据保留（PC-4）**：NSIS 自定义页面单选「覆盖/保留」；覆盖→安装期 drop 库→首次运行再走设置页；保留→不动库→跳过设置页。结果写入 `provision-state.json` 的 `keepData`。
5. **风险：installer 路径发现** — 复用 `runtime-integrator.ts::getRuntimeBinPath()`，与 runtime 同目录。
6. **风险：初始化耗时** — `ucInstaller.exe seed-init` 经 `--progress=ndjson` 流式输出进度；超时按 `failed` 处理（沿用 `DEFAULT_TIMEOUT_MS=30min`）；用户交互时间不计入。
7. **风险：password 泄露** — 走 stdin、bcrypt 后即丢弃、不写日志；进程参数不含密码。
8. **风险：保留数据误覆盖** — NSIS 保留分支不执行 `db drop`、不执行 `seed-init`。
9. **约束**：AI 不运行 `cjpm build`；installer 仓颉改动由用户在独立 cmd 编译回传；NSIS/TS 改造后需 `pnpm build:pc` / `vue-tsc` 人工验证。

---

# 九、后续步骤指引

- **下一步（需求规格）**：固化 PC-1~PC-4 四项行为 + DFX 约束（见 `spec.md`）。
- **再下一步（设计）**：细化 NSIS/Electron/欢迎页伪代码、凭据产物契约、覆盖/保留标记（见 `design.md`）。
- **任务规划**：拆为 installer 建号 / NSIS 改造 / Electron 改造 / Vue 欢迎页 / 端到端验证（见 `tasks.md`）。

---

# 附录 A：本研究直接复用的关键文件索引

| 用途 | 文件 | 备注 |
|---|---|---|
| 管理员哈希 | `installer/src/services/bcrypt_admin.cj` | 仅哈希，不落库 |
| 管理员落库 | `installer/src/services/db.cj`（`AdminRepo`） | `insertAdmin` 真落库入口 |
| 建号 HTTP 端点 | `installer/src/http/handlers/admin.cj` | `POST /setup/create-admin`，随 buildRouter 挂载 |
| seed 导入 | `installer/src/services/seed/{importer,rbac,verify}.cj` | 经 `install` S6 调用 |
| 启停管控 | `installer/src/serve/manage.cj` | `serve --manage` |
| 安装编排 | `installer/src/core/orchestrator.cj` | S0~S8，S5 待扩展 |
| NSIS 钩子 | `pc-client/build/installer.nsh` | 改造复用 |
| runtime 路径 | `pc-client/electron/modules/runtime-integrator.ts` | `getRuntimeBinPath()` |
| 安装委托 | `pc-client/electron/modules/installer-bridge.ts` | Phase 3 已落盘 |
| 默认配置 | `pc-client/resources/defaults/default-config.json` | autoStart 默认 true |
