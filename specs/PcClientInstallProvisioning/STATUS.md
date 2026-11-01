# PC 客户端安装工程优化 —— 完成度盘点与根因分析

**盘点日期**：2026-10-21（v2：按用户决策改为「首次运行自助建号 + seed 占位替换初始化」）
**盘点依据**：`apps/pc-client/electron/main/index.ts`、`electron/modules/{pgsql,runtime,setup,runtime-integrator,installer-bridge}.ts`、`installer/src/core/orchestrator.cj`、`installer/src/http/handlers/admin.cj`、`installer/src/services/{bcrypt_admin,db,seed/*}.cj` 实地核对（非估算）
**工程目录**：`apps/agentskills-runtime/specs/PcClientInstallProvisioning/`
**上游基线**：
- `specs/PcClientInstallerIntegration/`（PC ↔ installer 对接，G-1「安装与初始化交由 installer」）
- `specs/RuntimeNativeInstaller/`（installer S0~S8 + seed apply + bcrypt_admin）
- `.codeartsdoer/specs/pc_desktop_client/`（旧 PC 壳基线，未覆盖本工程的 4 项行为）

---

## 一、用户实测现象（2026-10-21）

安装 `release/0.1.0/AgentSkills Runtime-Windows-0.1.0-Installer.exe` 后：

- ✅ **web 服务正确启动**（首页 + 左侧菜单栏可见）
- ❌ **内嵌 runtime 无法通过界面启动**
- ❌ **内嵌数据库无法初始化 / 无法通过界面启动**
- 结论：客户端实际只有 web 服务可用，runtime 与数据库（含 seed、管理员账号）均未就绪。

---

## 二、根因分析（基于源码实证，解释「为什么只有 web 能用」）

### 根因 1：启动路径不执行「管理员建号 + seed 导入」的确定性编排

`electron/main/index.ts::initializeApp()`（L550-722）的启动顺序是：

1. L584 先启动 **WebAdmin HTTP 服务器** → 这就是「web 正常」的原因；
2. L607-622 若 runtime 未集成则解压归档；
3. L637-681 **仅当 `pgsql.mode === 'embedded'`（默认）** 时跑 `pgManager.initialize()` + `pgManager.start()`；
4. L683-697 若 runtime 已安装则 `runtimeManager.start()`。

关键点：`pgManager.initialize()`（`pgsql.ts` L126-256）虽然会 `initdb` → `createdb uctoo` → 导入 `sql/uctooDB.sql`，
但它**不创建用户可用的管理员账号**（无 email/username/name 录入入口），也**不向用户呈现任何「建号 / 初始化」的交互**——因此「用户自行创建管理员并初始化数据库」这件事当前在启动路径里**完全不存在**。

### 根因 2：installer 委托层（L2）已存在，但启动路径从不自动调用它

`setup.ts::executeDatabaseStep`（L23-130）里的 `executeInstallerInstall()` → `installerBridge.runInstall()`
（即 `ucInstaller.exe install --progress=ndjson --no-serve`，见 `installer-bridge.ts` L154-157）**只在用户走安装向导 UI（`setup:database` IPC）时才触发**，
`initializeApp()` 根本不调用它，而是直接走旧 `pgManager.initialize()`。

这与 `PcClientInstallerIntegration` 的 **G-1「PC 不再自行初始化 PostgreSQL、初始化交由 installer」** 直接冲突——启动路径绕过了 installer。

### 根因 3：installer 的「建管理员」步骤指向一个不存在的运行时端点

`installer/src/core/orchestrator.cj` **S5「建管理员」**（`runS5` L360-392）只做闸口校验（DB 可达），
然后把建号动作**handoff 给 `POST /api/setup/create-admin`**（`ev.add("handoff", "POST /api/setup/create-admin")`，L391）。

但全文检索 `apps/agentskills-runtime/src/app/**` **不存在该端点**（仅命中 crudweb 代码生成器的 `<script setup>` 噪声）。
即：installer 把建管理员委托给了 runtime，而 runtime 侧该端点尚未实现 → 无论走 installer 还是旧链路，
「按用户指定形态自动建管理员」这一能力当前**整条链路都不闭环**（详见第六节勘误）。

### 根因 4：无「首次运行建号页」、无「覆盖/保留」选择

- 启动路径没有任何环节把用户引导到「创建管理员 / 初始化数据库」的交互界面；
- NSIS 安装脚本（`electron-builder.json` → `build/installer.nsh`）未提供「覆盖安装 / 保留已有数据」选项，重装一律重新初始化。

---

## 三、与三份既有 spec 的关系

| 既有 spec | 已覆盖 | 本工程补的缺口 |
|---|---|---|
| `PcClientInstallerIntegration` | L1 同步层、L2 委托层（向导内调用 installer）、L3 托管层代码已落 | **启动路径自动调用 installer 完成初始化（G-1 启动期未满足）**；首次运行建号页；覆盖/保留选择 |
| `RuntimeNativeInstaller` | S0~S8、`seed apply`、`bcrypt_admin` | **S5 handoff 的 `POST /api/setup/create-admin` 端点缺失**；本工程改为「首次运行由 `seed-init` 子命令建号+seed」，绕开该缺口 |
| `.codeartsdoer/specs/pc_desktop_client` | PC 作为壳整合 web-admin + runtime | 完全未覆盖「首次运行自助建号 / seed 占位替换初始化 / 覆盖保留」——本工程是全新能力 |

**结论**：本工程不是重复造轮子，而是把「安装期只备空壳 + 首次启动期由用户自助建号并完成 seed 初始化」的确定性闭环补齐，
并把启动路径从「旧 pgManager 直连」迁到「installer 委托」（兑现 PcClientInstallerIntegration 的 G-1）。

---

## 四、新方案概览（v2：用户决策后的落地形态）

> 用户明确：**安装阶段不自动建管理员、不用 seed 初始化数据库**；改为**首次运行 PC 客户端时，在设置/欢迎页由用户自行录入 email/username/name/password，提交时替换 seed SQL 中的占位符，再初始化数据库**。

1. **安装期（NSIS → `ucInstaller.exe install --no-data`）**：只完成「环境检查 + 内嵌 PG 空集群 initdb + runtime 部署 + 生成 .env」，**不导入 schema、不导入 seed、不建管理员**。既有的 S4/S5/S6（schema/建号/seed）被 `--no-data` 跳过，保留给非 PC 部署场景复用。
2. **首次运行（PC 启动编排）**：先拉起内嵌 PG → 查询「是否已有超管」→
   - 若无超管（全新安装 / 覆盖安装后）：展示**设置页（SetupView）**，用户录入 email/username/name/password，点提交 → PC 调用 `ucInstaller.exe seed-init --email --username --name --password`（密码经 stdin/临时文件传入，不在进程参数暴露）→ installer 计算 bcrypt 哈希、替换 `seed-admin-template.sql` 占位符、导入 schema + 含管理员的 seed。
   - 若已有超管（保留数据重装）：跳过设置页，直接进入正常启动。
3. **初始化完成后**：拉起 runtime + 启动 WebAdmin + 加载首页（此时库已就绪，可登录）。
4. **重装选择（NSIS 覆盖/保留）**：覆盖安装 → 安装期 drop 掉 `uctoo` 库（仅留空集群）→ 首次运行检测到无超管 → 再次显示设置页；保留数据 → 不动库 → 首次运行检测到超管 → 跳过。

**相较 v1（安装期随机建号 + 明文凭据文件）的优势**：
- 密码由用户自选，不再生成「用户记不住的随机密码」；
- 不再需要 `provisioning-result.json` 明文密码产物，消除凭据泄露面；
- 设置页即「欢迎页」，语义统一（用户自己创建账号），无需「展示随机凭据再擦除」的脆弱流程。

---

## 五、已知决策点（须在 gate 阶段与用户拍板）

- **D-A 建号时机**：已定 —— **首次运行由用户在设置页录入，不再在安装期自动建号**。installer 新增 `seed-init` 子命令承接（取代 v1 的 `install --auto-admin`）。
- **D-B 凭据保密**：已消解 —— 不再落盘明文密码；密码仅存在于用户输入表单与 installer 进程内存（bcrypt 后即丢弃），`provisioning-result.json` 从本工程移除。
- **D-C 邮箱域名**：已放宽 —— 用户自行录入 email（不再强制 `@uctoo.com`），故 email 校验改为「合法邮箱格式」即可；username 唯一、name 为昵称。
- **D-D 密码强度策略（已采纳）**：建议最低 8 位、推荐 12 位含大小写+数字+符号；设置页显示密码强度进度条做视觉提示，但**不强制**（用户可自选弱口令）；首次运行设置页须明示「创建的是本机本地管理员账号，非网络 / 云端账号」（PC-Sec-1 / PC-Sec-4）。
- **D-E seed 模板占位符集**：建议 `{{ADMIN_ID}}` / `{{ADMIN_EMAIL}}` / `{{ADMIN_USERNAME}}` / `{{ADMIN_NAME}}` / `{{ADMIN_PASSWORD_HASH}}`；seed 模板为新增文件 `sql/seed-admin-template.sql`，在 schema 之后、seed JSON 之前应用，使 `{{principal:super_admin}}` 可解析。

---

## 六、机制勘误（复核 PcFirstRunBootstrap 后源码复核修正）

> 复核 `specs/PcFirstRunBootstrap` 时，发现其对「管理员建号」机制的假设**不准确**，已回到 installer 源码逐项核实，结论如下，作为本工程权威事实：

1. **`bcrypt_admin.cj` 只做哈希，不做建号**：该文件仅有 `hashPassword(plain)` / `verifyPassword(plain,hash)` 两个函数，**没有任何 INSERT `uctoo_user` 的逻辑**（已 grep 全量确认）。它只是被建号动作复用的工具。
2. **`orchestrator.cj::runS5`（L360-393）不建号**：S5 仅校验 `release/.env` 存在、解析出数据库连接串、ping 通 DB，随即 handoff 给 `POST /api/setup/create-admin`（L391）。注释 L383-384 明确写「管理员账号由 HTTP 端点 #8 承接，编排器这一步只判定 DB 可连」。
3. **但 installer 自身确实有「真·建号」HTTP 处理器**：`installer/src/http/handlers/admin.cj::createAdminHandler`（L14-75）读取 `.env` 连接串 → 查重 → **`AdminRepo.insertAdmin(...)` 真落库 `uctoo_user`** → 写后回读自校验，路由注册在 `routes.cj` L64（`POST create-admin`）。该路由随 `buildRouter` 一并挂载，故 **`ucInstaller.exe serve --manage`（运维管控 HTTP 服务，仅回环监听）与安装引导服务均暴露此端点**。
4. **结论（权威）**：管理员建号能力在 installer 侧**已存在**（经 `POST /setup/create-admin` 或 `AdminRepo.insertAdmin`），只是**不会在 `install`/`S5` 流程中自动触发**。本工程据此设计：
   - **v2 方案（默认）**：新增 `ucInstaller.exe seed-init --email --username --name --password`，在内部直接复用 `AdminRepo.insertAdmin` + `bcrypt_admin` + 既有 `seed apply`，**把用户录入的 4 字段经占位符替换灌入 seed 模板后初始化数据库**。无 HTTP 往返、不依赖 runtime 早期端点。
   - 备选：先 `serve --manage` 再 `POST /setup/create-admin`（等价，但多一次本地 HTTP 往返），不采用。
   - 这样彻底绕开「runtime 缺 `POST /api/setup/create-admin` 端点」这一真实缺口——因为我们根本不调用该端点，而是走 installer 内部落库路径 + seed 模板占位替换。

> 因此 PcFirstRunBootstrap 文档中「S5 创建管理员」「`install` 自动建号」的表述是**不准确的**（S5 只做闸口+handoff，真正建号在 HTTP handler）；但其「installer 侧已完成建号能力、PC 只需编排触发」的总体判断方向正确，本工程已采纳并升级为「`seed-init` + seed 模板占位替换」的首次运行自助方案。
