# PC 客户端安装工程优化 —— 需求规格

**文档版本**：v2.0（按用户决策改为「首次运行自助建号 + seed 占位替换初始化」）
**创建日期**：2026-10-21
**工程目录**：`apps/agentskills-runtime/specs/PcClientInstallProvisioning/`
**上游基线**：
- `specs/PcClientInstallerIntegration/`（G-1：安装与初始化交由 installer）
- `specs/RuntimeNativeInstaller/`（S0~S8、`seed apply`、`bcrypt_admin`）
- `.codeartsdoer/specs/pc_desktop_client/`（PC 作为壳的基线，未覆盖本工程行为）
**现状依据**：`electron/main/index.ts`、`electron/modules/{pgsql,runtime,setup,runtime-integrator,installer-bridge}.ts`、`installer/src/core/orchestrator.cj`、`installer/src/http/handlers/admin.cj` 源码实证（见 `STATUS.md`）
**人在回路闸口**：spec 步产出后须 `gate-spec` 确认（confirm / revise / abandon）

---

## 1. 组件定位

### 1.1 核心职责

本组件负责在 **PC 客户端安装期只备好空壳、在首次启动期由用户自助建号并完成数据库初始化** 的确定性编排，把安装结果从「只有 web 服务能用」提升到「开箱即用的完整本地栈（web + runtime + 数据库）」。

### 1.2 核心输入

1. 安装包自带的 runtime 发行包（`resources/runtime/*.tar.gz`，含 `ucInstaller.exe`）与 `sql/uctooDB.sql` + `sql/seed/*.json` + 新增的 `sql/seed-admin-template.sql`。
2. NSIS 安装向导中用户对「覆盖安装 / 保留已有数据」的选择。
3. **用户在首次运行设置页录入的管理员信息**：email、username、name、password。

### 1.3 核心输出

1. 一个可用的内嵌 PostgreSQL 实例（库 `uctoo`，含 schema + seed 数据 + 一个由用户创建的管理员账号）。
2. 用户在设置页自助创建的管理员账号（email/username/name 由用户输入，password 由用户设定并经 bcrypt 落库）。
3. 自动拉起的内嵌 runtime 进程（经 installer 管控者，R-39）。
4. 首次/覆盖安装后弹出的**设置页（即欢迎页）**，供用户创建管理员账号；创建完成后不再出现。

### 1.4 职责边界

- **不**重写 web-admin 前端与 runtime 业务功能（PC 是壳）。
- **不**在启动路径里自行 `pgManager.initialize()` 承担建号+seed（该项按 G-1 交由 installer，本工程只做编排与呈现）。
- **不**在**安装期**自动建管理员、不导入 seed、不初始化数据（用户决策：安装只备空壳）。
- **不**把密码以明文落盘（不再需要 `provisioning-result.json`）。
- 覆盖安装时若用户选择「保留已有数据」，**不**重建管理员、**不**覆盖既有库。

---

## 2. 领域术语

**安装期空壳（Bare Install）**
: 安装包完成文件落盘后、用户首次打开客户端前，installer 仅执行「环境检查 + 内嵌 PG 空集群 initdb + runtime 部署 + 生成 .env」，**不导入 schema、不导入 seed、不建管理员**。

**首次运行设置页（Setup Page / 欢迎页）**
: PC 客户端在判定为「库尚未初始化（无超管）」时展示的页面，用户录入 email/username/name/password 并点提交，触发数据库初始化；兼具「欢迎页」语义。

**seed 占位替换初始化（Seed-Placeholder Init）**
: 用户提交后，installer `seed-init` 子命令计算 password 的 bcrypt 哈希、把 `{{ADMIN_*}}` 占位符替换为录入值、随后导入 schema + 含管理员的 seed，完成数据库初始化。

**覆盖安装 / 保留数据（Overwrite / Keep）**
: NSIS 提供的二选一：覆盖安装 = drop 既有 `uctoo` 库（仅留空集群），首次运行重新走设置页；保留数据 = 复用既有数据库与账号，跳过设置页。

**管理员 principal**
: seed 数据中 `{{principal:super_admin}}` 占位符解析目标，必须指向用户首次运行真实创建的管理员账号 id（禁止写死常量 uuid，见 `installer-bridge.ts` L165-179 红线）。

---

## 3. 角色与边界

### 3.1 核心角色

- **终端用户**：安装 PC 客户端、在 NSIS 选择覆盖/保留、首次运行在设置页录入管理员信息并完成初始化。
- **运维/分发者**：产出含 `ucInstaller.exe` 与 `sql/*` 的安装包。

### 3.2 外部系统

- **ucInstaller.exe**（installer）：承担空集群 initdb、schema 导入、管理员落库、seed 导入（新增 `seed-init` 子命令）。
- **内嵌 PostgreSQL**：数据持久层。
- **agentskills-runtime（宿主）**：被启动的业务后端，提供 web-admin 所需的 HTTP API。

### 3.3 交互上下文

```
              ┌─────────────────────────┐
              │     PC 客户端 (Electron)   │
              │  ┌───────────────────┐   │
  用户 ──────▶│  │ 启动编排 / 设置页   │   │
              │  └─────────┬─────────┘   │
              │            │ 委托          │
              │            ▼              │
              │  ┌───────────────────┐   │
  用户选择 ──▶│  │ NSIS 覆盖/保留页    │   │
              │  └─────────┬─────────┘   │
              └────────────┼─────────────┘
                           │ install --no-data (空壳) / 覆盖则 drop 库
                           ▼
                   ┌───────────────────┐
                   │   ucInstaller.exe  │
                   │  (S0~S3 + 本工程)   │──▶ 内嵌 PostgreSQL (空集群)
                   └───────────────────┘
                           │ 首次运行: seed-init --email --username --name (--password via stdin)
                           ▼
                   ┌───────────────────┐
                   │   ucInstaller.exe  │──▶ 内嵌 PG (schema + 管理员 + seed)
                   │   seed-init        │
                   └───────────────────┘
                           │ 启动
                           ▼
                   ┌───────────────────┐
                   │ agentskills-runtime│ (业务后端 / web-admin API)
                   └───────────────────┘
```

---

## 4. DFX 约束

### 4.1 性能

- **PC-Perf-1**：installer `install --no-data`（空壳）单次上限 **5 分钟**；`seed-init`（schema+seed+建号）上限 **30 分钟**（`installer-bridge.ts` `DEFAULT_TIMEOUT_MS = 30*60*1000`）；进度须经 `--progress=ndjson` 实时回传，禁止界面「盲等」。
- **PC-Perf-2**：用户打开客户端后，内嵌 PG + runtime 自动拉起，冷启动到 runtime `/api/v1/health` 可达 **≤ 60s**（沿用 RuntimeNativeInstaller OQ-D5）。

### 4.2 可靠性

- **PC-Rel-1**：初始化须**幂等**——重复执行（重装、崩溃重跑）不得重复建号或破坏既有数据（覆盖安装除外）。
- **PC-Rel-2**：任一环节失败（installer 退出码 2/6、超时、无 final 行）必须如实呈现，禁止静默降级为「成功」（沿用 AC-PCI-022）。
- **PC-Rel-3**：保留数据模式下，初始化完全跳过，既有库与账号零改动。

### 4.3 安全性

- **PC-Sec-1**：password 由用户设定，设置页须在密码输入框下方提供**密码强度进度条**（按长度 + 大小写 + 数字 + 符号实时评估，分弱/中/强三档并以颜色区分），给出视觉提示；建议 ≥8 位、推荐 12 位含大小写+数字+符号；**不强制**必须达到某强度，用户可自由选择弱口令（风险自担）。不以任何默认值硬编码；禁止在进度条/提示中回显明文密码。
- **PC-Sec-2**：password **绝不**以明文落盘、绝不写入日志；installer 仅持有明文做 bcrypt 哈希，哈希后即丢弃；PC→installer 传密走 stdin/临时文件，不走进程参数（避免被任务管理器/日志捕获）。
- **PC-Sec-3**：seed 中 `{{secret:…}}` / `{{env:…}}` 占位符**绝不猜值**，一律由 installer 现场解析（AC-254）。
- **PC-Sec-4**：设置页须在醒目位置明示——**「您正在创建的是本机本地管理员账号，仅用于登录本机 PC 客户端与本地 runtime，不是网络账号 / 云端账号，不会同步到任何远程服务器」**，避免用户误以为是可联网的云端账户。

### 4.4 可维护性

- **PC-Maint-1**：installer 与 PC 通过 `release/bin` 同目录契约发现彼此（REQ-PCI-005/006）；seed 模板占位符集与 `seed-init` 契约须写入 `design.md` 作为显式契约。
- **PC-Maint-2**：启动编排改动须保留旧 `pgManager` 链路开关（`useInstaller` 回退），任一新链路失败可回退（AC-PCI-025）。

### 4.5 兼容性

- **PC-Comp-1**：覆盖/保留选择结果须跨版本可识别（写入稳定标记，如注册表项或 `%APPDATA%/<app>/provision-state.json`），不受安装路径变化影响。
- **PC-Comp-2**：保留数据模式下，旧版本创建的库须能被新版本 runtime 直接复用，不因版本升级而强制重建。

---

## 5. 核心能力

### 5.1 首次运行自助建号 + 初始化库（PC-1）

#### 5.1.1 业务规则

1. **触发条件**：PC 启动后检测到「内嵌 PG 已运行，但 `uctoo_user` 中不存在超管」时，展示设置页；用户录入并提交后执行初始化。
   - a. 验收条件：全新安装首次打开 → 展示设置页；提交后库含且仅含一个用户录入的超管行 → 预期成立。
2. **录入字段与约束**：
   - **email**：用户录入，必填，合法邮箱格式（不再强制 `@uctoo.com` 域名）。
   - **username**：用户录入，必填，唯一（库内不重复）。
   - **name**：用户录入，必填，昵称/显示名。
   - **password**：用户设定，必填；设置页提供强度进度条提示（见 PC-Sec-1），**不强制**强度阈值，用户可自定弱口令。
   - a. 验收条件：提交后 `uctoo_user` 存在一行 `username=<录入值>`、`email=<录入值>`、`name=<录入值>`、`password` 为 bcrypt 哈希（非明文）的超管 → 预期成立。
3. **seed 以该账号为 principal**：`sql/seed/*.json` 中的 `{{principal:super_admin}}` 必须解析为该新建管理员 id（经 `seed-admin-template.sql` 先行插入 + 既有 A1 复用逻辑）。
   - a. 验收条件：seed 导入后，原引用 `principal:super_admin` 的业务数据（默认权限、菜单、角色绑定）owner 指向该账号 → 预期成立。
4. **禁止项**：禁止安装期自动建号（用户决策）；禁止 PC 侧自行生成弱口令替代用户录入；禁止把 password 明文写入任何产物或日志。
   - a. 验收条件：安装目录与 `%APPDATA%` 下不存在含明文 password 的文件 → 预期成立。

#### 5.1.2 交互流程

```
PC 启动 → 拉起内嵌 PG → 查询「是否有超管」
   ├─ 无超管 → 展示设置页(SetupView)
   │    用户录入 email/username/name/password → 点「创建并初始化」
   │    → PC 调 ucInstaller.exe seed-init (--email --username --name, --password 走 stdin)
   │         ├─ 计算 password 的 bcrypt 哈希
   │         ├─ 替换 seed-admin-template.sql 的 {{ADMIN_*}} 占位符
   │         ├─ 导入 uctooDB.sql schema
   │         ├─ 导入含管理员的 seed (含 user_role 绑定)
   │         └─ seed apply (principal = 新建管理员 id)
   │    → 初始化完成 → 标记已初始化
   └─ 有超管 → 跳过设置页
随后：拉起 runtime + 启动 WebAdmin + 加载首页
```

#### 5.1.3 异常场景

1. **installer 不可用**（runtime 包内无 `ucInstaller.exe`）：
   - a. 触发条件：`installerBridge.isAvailable()` 为 false。
   - b. 系统行为：按 AC-PCI-025 回退旧 `pgManager` 链路（仍完成建库+seed，但**不提供用户自助建号界面**，设置页降级提示）。
   - c. 用户感知：web 可用，但设置页提示「无法初始化数据库，请手动在设置中配置」。
2. **installer 退出码 6（需人工介入）**：
   - a. 触发条件：`seed-init` 返回 `outcome='manual_intervention'`。
   - b. 系统行为：如实展示诊断与修复建议，不显示为成功（AC-PCI-022）。
   - c. 用户感知：初始化失败页 + 诊断信息，可重试。
3. **seed 模板占位符缺失/格式错**：
   - a. 触发条件：`seed-admin-template.sql` 缺少某个 `{{ADMIN_*}}` 或替换后 SQL 非法。
   - b. 系统行为：installer 校验占位符完整性，缺失则退出码 2 + 明确错误；PC 如实呈现。
   - c. 用户感知：提示「初始化模板不完整，请联系分发者」。
4. **用户录入校验失败**：
   - a. 触发条件：email 非法 / username 已存在 / password 强度不足。
   - b. 系统行为：设置页前端拦截，不发起 `seed-init`；username 已存在需先判定（通常为重复初始化，引导用户直接用既有账号登录）。
   - c. 用户感知：行内错误提示。

### 5.2 打开客户端自动启动服务（PC-2）

#### 5.2.1 业务规则

1. **内嵌 PG 自动启动**：用户打开 PC 客户端时，若 `pgsql.mode==='embedded'` 且 PG 未运行，自动 `pgManager.start()`（已具备，须确保其在初始化检测之前）。
   - a. 验收条件：客户端启动后 `pgsql:status` 返回 `running` → 预期成立。
2. **runtime 自动启动（经 installer 管控者，R-39）**：初始化完成后，runtime 经 installer `serve --manage` 或等效管控者拉起，PC 不自行 kill/拉起作为主路径。
   - a. 验收条件：客户端启动后 `runtime:status` 返回 `running` 且 `/api/v1/health` 可达 → 预期成立。
3. **未初始化时服务延后**：若检测到无超管，PG 先启动（供检测/初始化使用），但 **WebAdmin / runtime 在用户完成设置页初始化之前不启动**（避免连到空库报错）。
   - a. 验收条件：设置页展示期间 WebAdmin 不监听业务端口 / runtime 未拉起；初始化完成后才拉起 → 预期成立。

#### 5.2.2 交互流程

```
用户打开 PC 客户端
   ├─ 内嵌 PG start（embedded 模式，供检测/初始化使用）
   ├─ 检测「是否有超管」
   │    ├─ 无 → 展示设置页 → 用户提交初始化 → 完成后 continue
   │    └─ 有 → continue
   ├─ WebAdmin HTTP 服务器启动
   ├─ runtime start（经 installer 管控者）
   └─ 加载首页 iframe
```

#### 5.2.3 异常场景

1. **PG 端口被占用**：
   - a. 触发条件：`allocatePgsqlPort` 协商到 5433+ 但启动仍失败。
   - b. 系统行为：沿用既有动态端口协商 + `syncConfPort` 落盘（已修复）；失败则 `service:startFailed` 事件上报。
   - c. 用户感知：提示「数据库启动失败」+ 日志路径。
2. **runtime 进程崩溃**：
   - a. 触发条件：runtime 进程异常退出（非用户主动停止）。
   - b. 系统行为：PC 监听进程退出事件，导航栏显示崩溃状态，提供「重启服务」按钮（调 `serve --manage` 或旧 `runtimeManager.start` 回退）。
   - c. 用户感知：导航栏红点 + 「服务未启动 / 重启」入口，设置页/首页仍可加载。
3. **启动期端口冲突（runtime 8080 / PG 5432）**：
   - a. 触发条件：目标端口被本机其它进程占用。
   - b. 系统行为：`serve --manage` 报错，PC 弹「端口冲突」提示，不阻塞首页加载。
   - c. 用户感知：错误提示「端口 8080/5432 被占用，请释放后重启客户端」。

### 5.3 首次/覆盖安装设置页（PC-3，兼具欢迎页）

#### 5.3.1 业务规则

1. **触发条件**：判定为「库尚未初始化（无超管）」时展示设置页（覆盖全新安装与覆盖安装后首次打开两种情形）。
   - a. 验收条件：全新安装首次打开 → 展示；覆盖安装首次打开 → 展示；保留数据 → 不展示 → 预期符合。
2. **展示内容**：录入表单（email、username、name、password + 强度进度条提示），提交后触发初始化；初始化期间显示进度；完成后自动进入首页。表单上方须以醒目文案明示「创建的是本机本地管理员账号（非网络 / 云端账号）」（见 PC-Sec-4）。
   - a. 验收条件：表单字段与约束符合 §5.1.1 规则2、且页面可见本地账号声明 → 预期成立。
3. **一次性**：用户完成创建并初始化后，库中存在超管，后续启动检测通过，设置页不再出现。
   - a. 验收条件：完成后重启客户端 → 设置页不再出现 → 预期成立。

#### 5.3.2 交互流程

```
PC 启动 → 检测「是否有超管」
   ├─ 无 → 展示设置页(SetupView, 本地 HTML)
   │     用户输入 → 校验 → 提交
   │     → IPC setup:submit → main 调 installerBridge.seedInit({email,username,name}, passwordViaStdin)
   │     → 进度回传 setup:progress → 完成 → 标记已初始化
   │     → 拉起 WebAdmin + runtime → 加载首页
   └─ 有 → 直接拉起服务 + 加载首页
```

#### 5.3.3 异常场景

1. **初始化产物/能力缺失（回退旧链路）**：
   - a. 触发条件：`ucInstaller.exe` 不可用（AC-PCI-025 回退）。
   - b. 系统行为：设置页降级为「无法自动初始化，请手动在设置中配置」，不阻塞正常使用。
   - c. 用户感知：提示文案 + 跳转设置入口。
2. **初始化中途失败（用户可重试）**：
   - a. 触发条件：`seed-init` 退出码非 0 / 超时。
   - b. 系统行为：设置页保持，展示错误与「重试」按钮；不标记已初始化（下次启动仍走设置页）。
   - c. 用户感知：错误提示 + 重试入口。
3. **DB 已有超管但检测误判**：
   - a. 触发条件：查询因 PG 瞬时未就绪而失败。
   - b. 系统行为：重试查询（带有限重试与超时），仍失败则按「未初始化」安全展示设置页（用户提交时若发现超管已存在则引导登录）。
   - c. 用户感知：短暂重试或提示。

### 5.4 重装覆盖/保留选择（PC-4）

#### 5.4.1 业务规则

1. **NSIS 提供选择**：安装向导提供「覆盖安装（清空并重建数据）」与「保留已有数据」二选一。
   - a. 验收条件：安装过程中出现该选项页 → 预期成立。
2. **保留数据**：选择保留后，安装期**不 drop 库、不重建**，首次运行检测到超管 → 跳过设置页。
   - a. 验收条件：保留模式下重装后，原 `uctoo` 库数据完整、原管理员账号不变 → 预期成立。
3. **覆盖安装**：选择覆盖后，安装期 drop 掉 `uctoo` 库（仅留空集群），首次运行检测到无超管 → 再走设置页让用户重新建号。
   - a. 验收条件：覆盖后数据库被清空、首次运行出现设置页、用户重新建号 → 预期成立。
4. **选择持久化**：选择结果写入稳定标记，供安装期决定是否 drop 库。
   - a. 验收条件：选择结果可从标记文件/注册表读回 → 预期成立。

#### 5.4.2 交互流程

```
NSIS 自定义页(覆盖/保留)
   ├─ 覆盖 → 写 keepData=false → 安装期 drop uctoo 库(仅留空集群)
   └─ 保留 → 写 keepData=true  → 安装期不动库
PC 首次启动 → 检测超管
   ├─ 无(覆盖后) → 设置页 → 用户建号
   └─ 有(保留后) → 跳过设置页
```

#### 5.4.3 异常场景

1. **标记损坏/缺失**：
   - a. 触发条件：`provision-state.json` 不可读。
   - b. 系统行为：默认按「覆盖」安全处理（drop 重建），并在日志告警。
   - c. 用户感知：若无意外数据丢失风险则无感；否则提示。
2. **drop 库失败（覆盖安装）**：
   - a. 触发条件：PG 未运行或库被占用导致 drop 失败。
   - b. 系统行为：安装期报错并提示用户先关闭正在运行的客户端；不静默跳过。
   - c. 用户感知：提示「请先退出 PC 客户端再覆盖安装」。

---

## 6. 数据约束

### 6.1 管理员账号（uctoo_user）

- **email**：必填，合法邮箱格式（用户录入，域名不限）。
- **username**：必填，唯一，用户录入。
- **name**：必填，用户录入的昵称/显示名。
- **password**：必填，密文存储（bcrypt），**明文仅存在于用户输入表单与 installer 进程内存（哈希后即丢弃）**。
- **角色**：超管（`*` 或等价 super_admin 角色），seed 的 `principal:super_admin` 解析目标。

### 6.2 seed-admin-template.sql（新增模板，含占位符）

- **path**：`<runtimeHome>/sql/seed-admin-template.sql`（随安装包分发）。
- **占位符集**（由 installer `seed-init` 在初始化时替换）：
  - `{{ADMIN_ID}}`：installer 生成的 UUID。
  - `{{ADMIN_EMAIL}}`：用户录入 email。
  - `{{ADMIN_USERNAME}}`：用户录入 username。
  - `{{ADMIN_NAME}}`：用户录入 name。
  - `{{ADMIN_PASSWORD_HASH}}`：installer 对用户输入 password 计算的 bcrypt 哈希。
- **应用顺序**：schema（`uctooDB.sql`）导入之后、seed JSON（`sql/seed/*.json`）导入之前，使 `{{principal:super_admin}}` 可解析为该管理员 id。
- **内容**：`INSERT INTO uctoo_user (...)`（含上述占位符）+ 对应的 `user_role` 超管角色绑定。

### 6.3 provision-state.json（PC 侧状态，跨版本稳定）

- **path**：`%APPDATA%/<app>/provision-state.json`。
- **字段**：
  - **keepData**：布尔，最近一次安装的选择（覆盖=false / 保留=true）。
  - **initialized**：布尔，库是否已含超管（亦可经 DB 查询实时判定，此字段作缓存/兜底）。
  - **provisionedVersion**：字符串，已初始化的客户端版本（用于跨版本判定）。
- **注意**：本工程**不再使用 `provisioning-result.json`**（无明文密码产物）。

### 6.4 密码传输契约（PC → installer）

- PC 调 `ucInstaller.exe seed-init` 时，`--email/--username/--name` 走命令行参数，`--password` **走 stdin 或一次性临时文件**（installer 读后立即删除），**绝不**以命令行参数传密码。
