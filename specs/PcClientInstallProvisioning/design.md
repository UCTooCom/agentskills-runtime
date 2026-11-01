# PC 客户端安装工程优化 —— 技术设计

**文档版本**：v2.0（按用户决策改为「首次运行自助建号 + seed 占位替换初始化」）
**创建日期**：2026-10-21
**关联需求**：`spec.md`
**关联状态**：`STATUS.md`（根因与缺口）
**人在回路闸口**：design 步产出后须 `gate-design` 确认

---

## 1. 设计概述

### 1.1 设计目标

把 PC 客户端从「只有 web 可用」修复为「开箱即用的完整本地栈」，并在**首次运行**由用户自助完成：建库 + 录入管理员 + seed 导入；安装期只备空壳（环境 + 空集群 + runtime 部署），支持重装时的「覆盖 / 保留」选择。

### 1.2 设计原则

- **G-1 落地**：启动路径的安装与初始化一律委托 `ucInstaller.exe`，PC 只做编排与呈现，保留旧链路回退开关（`useInstaller`）。
- **安装期零数据**：安装只备空壳（initdb + runtime 部署 + .env），不导入 schema/seed、不建管理员（用户决策）。
- **首次运行自助**：无超管 → 设置页录入 → `seed-init` 占位替换初始化；有超管 → 跳过。
- **密码不落盘**：password 仅存于用户输入与 installer 内存（bcrypt 后即丢弃），不写任何文件/日志。
- **如实呈现**：installer 退出码 2/6、超时、缺 final 一律如实上报，不冒充成功（AC-PCI-022）。

### 1.3 技术选型

| 组件 | 技术 | 说明 |
|---|---|---|
| PC 编排 | Electron Main (TypeScript) | `electron/main/index.ts` + `modules/*` |
| 安装器 | 仓颉 `ucInstaller.exe` | `installer/src`，S0~S3 + 本工程新增 `seed-init` 子命令 |
| 安装向导 | NSIS（`electron-builder` `build/installer.nsh`） | 覆盖/保留自定义页 + 覆盖时 drop 库 |
| 数据库 | 内嵌 PostgreSQL 16 | `pgsql.ts` 管理启动，`installer` 管理建库+seed |
| seed 模板 | 新增 `sql/seed-admin-template.sql` | 含 `{{ADMIN_*}}` 占位符 |

---

## 2. 系统架构

### 2.1 架构图

```
┌──────────────────────────────────────────────────────────────┐
│  NSIS Installer (installer.nsh)                                │
│   ├─ 自定义页：覆盖安装 / 保留已有数据                           │
│   ├─ 覆盖 → drop uctoo 库(仅留空集群) → 写 keepData=false      │
│   └─ 保留 → 不动库 → 写 keepData=true                          │
└───────────────────────────┬──────────────────────────────────┘
                             │ install --no-data (空壳: initdb + runtime + .env)
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  PC 客户端首次启动                                              │
│   1. 拉起内嵌 PG                                                │
│   2. 查询「uctoo_user 是否有超管」                               │
│      ├─ 无 → 展示设置页(SetupView, 本地 HTML)                    │
│      │     用户录入 email/username/name/password                 │
│      │     → ucInstaller.exe seed-init (占位替换初始化)           │
│      └─ 有 → 跳过                                               │
│   3. 拉起 runtime + WebAdmin → 加载首页                          │
└───────────────────────────┬──────────────────────────────────┘
                             │ seed-init --email --username --name (--password via stdin)
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  ucInstaller.exe seed-init                                    │
│   ① bcrypt(password) → hash                                    │
│   ② 读 seed-admin-template.sql, 替换 {{ADMIN_*}}                │
│   ③ createdb uctoo(若缺) → 导入 uctooDB.sql schema             │
│   ④ 导入含管理员的 seed(含 user_role 绑定)                      │
│   ⑤ seed apply (principal = 新建管理员 id)                      │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 模块划分

| 模块 | 位置 | 职责 |
|---|---|---|
| 启动编排器 | `electron/main/index.ts::initializeApp` | 先拉 PG → 检测超管 → 决定展示设置页或正常启动；初始化完成后拉起 runtime+WebAdmin |
| Installer 委托 | `modules/installer-bridge.ts`（扩展） | 新增 `runSeedInit(fields, password)`：封装 `seed-init` + NDJSON 进度；新增 `runBareInstall()`：`install --no-data` |
| 初始化检测 | 新增 `modules/db-probe.ts` | 连接 PG，查询 `uctoo_user` 是否存在超管（带有限重试） |
| 设置页 | 渲染层（新增 `SetupView`）+ `modules/setup.ts` | 表单收集 + 校验 + `setup:submit` IPC；进度展示 |
| NSIS 页 | `build/installer.nsh`（扩展） | 覆盖/保留自定义页；覆盖时 drop 库 |
| installer seed-init | `installer/src`（扩展） | 新增 `seed-init` 子命令：hash + 占位替换 + schema + 含管理员 seed |

---

## 3. 详细设计

### 3.1 PC 启动编排（PC-1 + PC-2）

**改造点**：`electron/main/index.ts` L550-722 整体重构启动顺序。

```ts
async function initializeApp() {
  const config = loadConfig()
  // 1) 先拉起内嵌 PG（供检测/初始化使用）
  if (pgsql.mode === 'embedded') {
    if (!pgManager.isRunning()) await pgManager.start()
  }
  // 2) 检测是否已初始化（存在超管）
  const adminExists = await dbProbe.hasSuperAdmin()
  if (!adminExists) {
    // 3) 展示设置页，阻塞到用户完成初始化
    await showSetupAndWait(config)   // 内部调 installerBridge.runSeedInit
  }
  // 4) 初始化完成后拉起业务服务
  if (config.runtime?.autoStart !== false) await ensureRuntimeRunning()
  if (config.webadmin?.autoStart !== false) await webAdminServer.start()
  mainWindow.loadURL(HOME_URL)
}
```

**关键约束**：
- WebAdmin / runtime **必须**在 `hasSuperAdmin()===true` 之后才拉起（避免连空库）。
- `envGenerator.generateForRuntime()` 仍须在 PG 可达后执行（runtime 需要 DB 连接串）。
- `--no-data` 安装产生的空集群，`dbProbe` 查询 `uctoo_user` 会因表不存在而抛错 → 统一按「未初始化」处理（捕获 SQLState 42P01 表不存在）。

### 3.2 installer `seed-init` 子命令（PC-1 的执行侧）

**新增 `ucInstaller.exe seed-init`**（取代 v1 的 `install --auto-admin`）：

1. 参数：`--email`、`--username`、`--name` 走命令行；`--password` **走 stdin**（installer 读一行后即丢弃明文）。
2. 内部流程：
   - `hash = bcrypt_admin.hashPassword(password)`（cost 10，前缀归一 `$2a$10$`）。
   - `adminId = CryptoUtils.uuid()`。
   - 读 `sql/seed-admin-template.sql`，把 `{{ADMIN_ID}}`/`{{ADMIN_EMAIL}}`/`{{ADMIN_USERNAME}}`/`{{ADMIN_NAME}}`/`{{ADMIN_PASSWORD_HASH}}` 替换为对应值。
   - 若 `uctoo` 库不存在 → `createdb uctoo`。
   - 导入 `sql/uctooDB.sql`（schema）。
   - 执行替换后的 seed-admin 模板（插入管理员 + `user_role` 绑定）。
   - `seed apply`（复用 `services/seed/*`，`{{principal:super_admin}}` 解析为 `adminId`）。
3. 退出码遵循既有契约：0 成功 / 2 参数错误（含占位符缺失）/ 6 需人工介入。
4. 进度经 `--progress=ndjson` 输出 `kind=step/item/final`（沿用 installer-bridge 解析）。

> **与 RuntimeNativeInstaller S5 的关系**：当前 `runS5` 仅做闸口并把建号 handoff 给不存在的 `POST /api/setup/create-admin`。本工程**不依赖该端点**，改为 `seed-init` 内部直接复用 `AdminRepo.insertAdmin`（与 `admin.cj` 同源落库路径）+ `bcrypt_admin` + 既有 `seed apply`，彻底绕开 runtime 缺端点的缺口（详见 STATUS 第六节）。

### 3.3 seed-admin-template.sql（PC-1 规则3 的载体）

新增文件，含两个语句（占位符由 installer 替换）：

```sql
-- 管理员账号（占位符在 seed-init 时替换）
INSERT INTO uctoo_user (id, email, username, name, password, role, status, created_at, updated_at)
VALUES (
  '{{ADMIN_ID}}',
  '{{ADMIN_EMAIL}}',
  '{{ADMIN_USERNAME}}',
  '{{ADMIN_NAME}}',
  '{{ADMIN_PASSWORD_HASH}}',
  'super_admin',
  'active',
  now(), now()
)
ON CONFLICT (username) DO NOTHING;

-- 超管角色绑定（假设超管角色 id 为常量/或由 seed 提供；此处以 username 反查确保绑定）
INSERT INTO user_role (user_id, role_id)
SELECT u.id, r.id FROM uctoo_user u, role r
WHERE u.username = '{{ADMIN_USERNAME}}}' AND r.name = 'super_admin'
ON CONFLICT DO NOTHING;
```

> 实际 role 绑定方式以 `sql/seed/*.json` 的 RBAC 骨架为准；模板仅保证「管理员行存在 + 与超管角色绑定」，使后续 `{{principal:super_admin}}` 可解析。字段名以 `uctooDB.sql` 实际 DDL 为准（SDD 不重造表结构）。

### 3.4 设置页（PC-3，兼具欢迎页）

新增渲染层 `SetupView`（PC 壳内本地 HTML 页面，非 web-admin 业务页）：
- 入口判定：`dbProbe.hasSuperAdmin() === false` 时由 main 加载 `file://.../setup.html`。
- 表单字段：email / username / name / password（带强度进度条与显隐切换）。
- 顶部声明：醒目文案——「您正在创建的是本机本地管理员账号，仅用于登录本机 PC 客户端与本地 runtime，非网络 / 云端账号，不会同步到远程服务器」（对应 PC-Sec-4）。
- 前端校验：email 格式、username 非空且符合规则；password 仅做强度进度条提示（PC-Sec-1），**不强制**强度，弱口令可提交；格式校验不通过则行内提示，不发起提交。
- 提交：`setup:submit` IPC → main 调 `installerBridge.runSeedInit({email,username,name}, password)`（password 经 stdin 管道传入 installer）。
- 进度：监听 `setup:progress` 展示 NDJSON 进度；完成 → main 标记初始化完成 → 拉起服务 → 加载首页。
- 主进程侧新增 `modules/setup.ts`：`runSeedInit()` / 进度转发。

### 3.5 NSIS 覆盖/保留页（PC-4）

`build/installer.nsh` 增加自定义页（在 `customInstall` 之前）：
- 单选：「覆盖安装（清空并重建数据）」 / 「保留已有数据」。
- **覆盖**：安装期调用 `ucInstaller.exe` 或 `psql` drop 掉 `uctoo` 库（仅留空集群），写 `provision-state.json.keepData=false`。
- **保留**：不动库，写 `keepData=true`。
- 兼容旧包：标记缺失时默认 `keepData=false`（覆盖，安全重建）。
- 注：覆盖安装的「drop 库」只删除数据，不删除程序文件；若 PG 仍在运行（用户未退客户端），drop 失败 → 提示先退出。

### 3.6 自动启动（PC-2，Phase 4 托管层）

- 内嵌 PG：`pgManager.start()` 已具备，确保其在检测/初始化之前调用（§3.1）。
- runtime 启停：沿用 `runtimeManager.start()`（当前 spawn `agentskills-runtime.exe`）。若后续落实 R-39「经 installer 管控者」，改为 spawn `ucInstaller.exe serve --manage` 并让 runtime 自举；本工程先保证「能自动拉起并 `/api/v1/health` 可达」，R-39 管控者作为后续 Phase 4 收尾项。

---

## 4. 数据设计

### 4.1 数据模型（复用既有）

- `uctoo_user`：用户录入的超管行（见 spec §6.1）。
- `role` / `user_role` / `role_has_permission`：沿用既有 RBAC（超管持 `*`）。

### 4.2 新增契约

**seed-admin-template.sql 占位符**（installer 在 `seed-init` 时替换）：
```
{{ADMIN_ID}}            → 生成的 UUID
{{ADMIN_EMAIL}}         → 用户录入 email
{{ADMIN_USERNAME}}      → 用户录入 username
{{ADMIN_NAME}}          → 用户录入 name
{{ADMIN_PASSWORD_HASH}} → bcrypt(password)
```

**provision-state.json**（PC 管理，跨版本稳定路径 `%APPDATA%/<app>/`）：
```json
{ "keepData": false, "initialized": false, "provisionedVersion": "0.1.0" }
```
> `initialized` 为缓存/兜底；权威判定以 DB 查询 `hasSuperAdmin()` 为准。

---

## 5. API 设计

### 5.1 installer 子命令（新增/扩展）

| 命令 | 参数 | 说明 |
|---|---|---|
| `ucInstaller.exe install --no-data` | `--no-serve --progress=ndjson` | 空壳安装：环境 + initdb 空集群 + runtime 部署 + .env；**跳过** schema/seed/建号 |
| `ucInstaller.exe seed-init` | `--email --username --name`（password 走 stdin）`--no-serve --progress=ndjson` | 建库(若缺)+schema+含管理员 seed+seed apply |
| `ucInstaller.exe serve --manage` | `[--auto-exit]` | PC 启动时运维管控（拉起/停止 runtime + PG，仅回环） |

### 5.2 PC 主进程 IPC（新增）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `setup:submit` | renderer → main：提交录入的 {email,username,name} + 经 stdin 的 password，触发 `seed-init` |
| — | `setup:progress` | main → renderer：`seed-init` 的 NDJSON 进度事件 |
| POST | `setup:cancel` | renderer → main：取消（可选） |

---

## 6. 安全设计

- **密码不落盘**：`seed-init` 的 password 经 stdin 传入，installer 仅用于 bcrypt，哈希后即丢弃；绝不明文写文件/日志。
- **密码不进进程参数**：避免被任务管理器/命令行审计捕获。
- **bcrypt 复用**：沿用 `bcrypt_admin.cj`（cost 10），与既有账号哈希策略一致。
- **占位符不猜值**：`{{secret:…}}` / `{{env:…}}` 一律 installer 现场解析（AC-254），PC 不触碰。
- **保留模式零写入**：`--no-data` + 保留选择下 installer 不建号、不动库。

---

## 7. 性能设计

- 进度实时：沿用 `--progress=ndjson`（installer-bridge 已解析 `kind=step/item/final`），设置页逐步渲染。
- 超时：复用 `DEFAULT_TIMEOUT_MS = 30min`；超时按 `failed` 处理并提示。
- 冷启动：PG + runtime 自动拉起目标 ≤60s（OQ-D5），但**设置页阶段不计入**（需用户交互）。

---

## 8. 部署与回退

- **回退开关**：`configStore.getUseInstaller()` 为 false 时，启动编排回退旧 `pgManager.initialize()` 链路（AC-PCI-025）。旧链路**不提供用户自助建号界面**，设置页须降级（PC-3 异常场景 1）。
- **不破坏既有布局**：仅新增 installer 子命令、一个 seed 模板文件、一个 JSON 状态；不改变 `release/` 既有结构。

---

## 9. 已知缺口与待拍板

| # | 缺口 | 影响 | 决策 |
|---|---|---|---|
| D-A | 建号时机 | 已定：首次运行由用户录入（非安装期） | `seed-init` 承接 |
| D-B | 凭据保密 | 已消解：无明文文件 | 移除 `provisioning-result.json` |
| D-C | 邮箱域名 | 已放宽：用户自行录入，格式校验即可 | — |
| D-D | 密码强度阈值 | **已采纳**：建议 ≥8 / 推荐 12 含大小写+数字+符号；设置页显示强度进度条做视觉提示，但**不强制**（用户可自选弱口令）；首次运行设置页须明示「本地管理员账号，非网络账号」（PC-Sec-1 / PC-Sec-4） | ✅ 已定 |
| D-E | seed 模板占位符集 | 建议 5 个（见 §4.2） | 待 gate-design 确认 |
| GAP-X | runtime 缺 `POST /api/setup/create-admin` 端点 | 本工程不调用它，`seed-init` 走 installer 内部落库 | 已绕过 |

> **机制勘误补充**（复核 `PcFirstRunBootstrap` 后源码核实）：installer 已自带真·建号 HTTP 处理器 `POST /setup/create-admin`（`http/handlers/admin.cj`，经 `AdminRepo.insertAdmin` 落库），随 `serve --manage` 与安装引导服务一并挂载。本工程默认 `seed-init` 直接复用 `AdminRepo.insertAdmin`（无 HTTP 往返）与之等价且更直接；方案 A'（先起 `serve --manage` 再 POST 该端点）为等价备选。详见 `STATUS.md` 第六节。

---

## 10. 关键实现伪代码（参考 PcFirstRunBootstrap 合并，已按 v2 改写）

### 10.1 NSIS 安装后钩子 + 重装选择（`build/installer.nsh`）

```nsis
; === PcClientInstallProvisioning v2 新增 ===
Function CheckExistingInstall
  IfFileExists "$INSTDIR\AgentSkills Runtime.exe" 0 firstInstall
    Call ShowDataChoicePage        ; 重装 → 弹出 覆盖/保留 单选
    Goto installDone
  firstInstall:
    StrCpy $isFirstInstall "true"
  installDone:
FunctionEnd

Function ShowDataChoicePage
  ; NSIS 自定义页：单选「覆盖安装 / 保留已有数据」
  ; 覆盖 → StrCpy $overwriteData "true"
  ; 保留 → StrCpy $preserveData "true"
FunctionEnd

Section "PostInstall" SEC_POST
  ${If} $overwriteData == "true"
    ; 覆盖：drop 既有 uctoo 库（仅留空集群）；需 PG 已运行
    nsExec::ExecToLog '"$INSTDIR\resources\runtime\release\bin\ucInstaller.exe" db drop --db=uctoo --no-serve'
    ; 写 keepData=false（首次运行将走设置页）
    Call WriteProvisionStateOverwrite
  ${ElseIf} $preserveData == "true"
    Call WriteProvisionStateKeep
  ${EndIf}
  ; 空壳安装（不导入 schema/seed/建号）
  nsExec::ExecToLog '"$INSTDIR\resources\runtime\release\bin\ucInstaller.exe" install --no-data --no-serve --progress=ndjson'
SectionEnd
```

### 10.2 Electron 主进程改造（`electron/main/index.ts`）

```typescript
// === PcClientInstallProvisioning v2 新增 ===
async function initializeApp() {
  const config = await loadConfig();
  // 1) 先拉起内嵌 PG（供检测/初始化）
  if (config.pgsql?.mode === 'embedded' && !pgManager.isRunning()) {
    await pgManager.start();
  }
  // 2) 检测是否已初始化（存在超管）
  let adminExists = false;
  try { adminExists = await dbProbe.hasSuperAdmin(); }
  catch (e) { adminExists = false; }   // 表不存在等 → 视为未初始化
  // 3) 未初始化 → 展示设置页并等待用户完成
  if (!adminExists) {
    await showSetupAndWait(config);    // 内部：load setup.html → 监听 setup:submit → runSeedInit
  }
  // 4) 拉起业务服务
  if (config.runtime?.autoStart !== false) {
    try { await ensureRuntimeRunning(); ipc.send('service:started',{service:'runtime'}); }
    catch (err) { ipc.send('service:startFailed',{service:'runtime',error:err.message}); }
  }
  if (config.webadmin?.autoStart !== false) { await webAdminServer.start(); }
  mainWindow.loadURL(HOME_URL);
}

function showSetupAndWait(config): Promise<void> {
  return new Promise((resolve) => {
    mainWindow.loadURL(`file://${__dirname}/../renderer/setup.html`);
    ipc.registerHandler('setup:submit', async (fields, password) => {
      const result = await installerBridge.runSeedInit(fields, password); // password 经 stdin
      ipc.send('setup:progress', result.progress);
      if (result.ok) { resolve(); }
      else { ipc.send('setup:failed', result.error); }  // 用户可重试
    });
  });
}
```

### 10.3 设置页（`SetupView.vue` / `setup.html`，节选）

```vue
<template>
  <div class="setup-container">
    <h1>欢迎，创建您的管理员账号</h1>
    <p class="notice">您正在创建的是<strong>本机本地管理员账号</strong>，仅用于登录本机 PC 客户端与本地 runtime，<strong>不是</strong>网络 / 云端账号，不会同步到任何远程服务器。</p>
    <form @submit.prevent="submit">
      <input v-model="email" type="email" placeholder="邮箱" />
      <input v-model="username" placeholder="账号名 (username)" />
      <input v-model="name" placeholder="昵称 (name)" />
      <input v-model="password" :type="showPw ? 'text':'password'" placeholder="密码" />
      <div class="strength" :class="strengthClass">{{ strengthText }}</div>
      <button type="submit" :disabled="!valid">创建并初始化</button>
    </form>
    <p v-if="error" class="error">{{ error }}</p>
    <progress v-if="initiating" :value="progress" max="100" />
  </div>
</template>
```

---

## 11. 接口契约（显式）

### 11.1 NSIS → installer CLI

| 命令 | 参数 | 说明 |
|---|---|---|
| `ucInstaller.exe install --no-data` | `--no-serve --progress=ndjson` | 空壳安装（跳过 schema/seed/建号） |
| `ucInstaller.exe db drop` | `--db=uctoo --no-serve` | 覆盖安装时 drop 库（仅留空集群） |
| `ucInstaller.exe seed-init` | `--email --username --name`（password 走 stdin）`--no-serve --progress=ndjson` | 建库(若缺)+schema+含管理员 seed+seed apply |
| `ucInstaller.exe serve --manage` | `[--auto-exit]` | PC 启动时运维管控（仅回环） |

### 11.2 Electron 内部 IPC

| 通道 | 方向 | 说明 |
|---|---|---|
| `setup:submit` | renderer → main | 提交 {email,username,name} + password（main 经 stdin 传给 installer） |
| `setup:progress` | main → renderer | `seed-init` 的 NDJSON 进度 |
| `setup:failed` | main → renderer | 初始化失败 + 错误信息（可重试） |
| `service:started` / `service:startFailed` | main → renderer | 服务启停状态 |

### 11.3 seed-admin-template.sql 占位符

| 占位符 | 替换来源 |
|---|---|
| `{{ADMIN_ID}}` | installer 生成的 UUID |
| `{{ADMIN_EMAIL}}` | 用户录入 email |
| `{{ADMIN_USERNAME}}` | 用户录入 username |
| `{{ADMIN_NAME}}` | 用户录入 name |
| `{{ADMIN_PASSWORD_HASH}}` | `bcrypt_admin.hashPassword(password)` |

### 11.4 PC 状态产物（`provision-state.json`，`%APPDATA%/<app>/`）

```json
{ "keepData": false, "initialized": false, "provisionedVersion": "0.1.0" }
```

---

## 12. 实施分期

- **P0（核心闭环）**：installer `seed-init` 建号+占位替换+seed + NSIS 空壳安装 + Electron 检测超管→设置页→初始化→自动启停。覆盖 PC-1~PC-3。
- **P1（重装体验）**：NSIS 重装覆盖/保留选择页 + drop 库 + `provision-state.json` 持久化。覆盖 PC-4。
- **P2（健壮性）**：初始化失败重试 + 端口冲突处理 + 旧链路 `useInstaller` 回退 + DB 查询重试。

---

## 13. 防回退约束

| 风险 | 约束 |
|---|---|
| NSIS 脚本改造导致安装失败 | 改造后必须人工执行 `pnpm build:pc` 验证安装包可正常安装 |
| installer `seed-init` 路径发现错误 | 复用 `runtime-integrator.ts::getRuntimeBinPath()`，与 runtime 同目录 |
| password 泄露 | 走 stdin、bcrypt 后即丢弃、不写日志/文件 |
| 自动启停阻塞首页 | 设置页未完成前不拉起 WebAdmin/runtime；启停失败不阻塞首页加载（`catch` + 异常状态） |
| 保留数据安装误覆盖 | NSIS 保留分支不执行 `db drop`、不执行 `seed-init` |
| `serve --manage` 与既有 `pgsql.ts` 冲突 | 既有 `pgsql.ts` 降级为 fallback（开关 `useInstaller`），不删除 |
| 建号与 seed 顺序错 | 严格 模板(建号) → seed apply（principal 解析），否则 `{{principal:super_admin}}` 悬空 |
| 表不存在误判 | `dbProbe` 捕获「表不存在」SQLState，统一按未初始化 |

---

## 14. 发布包技能/插件布局与技能-插件融合机制对齐（2026-11-01 补）

> 背景：实测最新版本安装/解包后，`dataRoot/runtime/win-x64/release/bin/` 下同时出现
> `bin/skills/` 与 `bin/plugins/` 两个目录，且 `bin/plugins/` 与 `bin/skills/` 内容重叠。
> 这与本项目的**技能-插件融合机制**冲突，须对齐。

### 14.1 融合机制口径（权威依据）

- 设计基线：`.codeartsdoer/specs/plugin-system/` 与 `specs/plugin-system-enhancement/`。
  - **REQ-PS-007（插件 + Skills 融合）**：一个插件 = `SKILL.md`（AI 行为）+ `plugin.yaml`（确定性能力清单与配置）+ 可执行文件，**三者同住在 `skills/{name}/`** 目录。
  - **REQ-PS-016（去中心化自动发现）**：运行时经 `PluginDiscoveryService` **扫描 `skills/` 目录**自动发现 `plugin.yaml`，**不存在独立的 `plugins/` 顶层目录**；新增插件只需放到技能目录，零中心配置。
- 因此发布包内**只有 `bin/skills/{name}/`**，不应出现 `bin/plugins/`。

### 14.2 现状偏差与修正

| 项 | 现状（错误） | 修正（融合机制） |
|---|---|---|
| 发布包技能/插件目录 | `bin/skills/{name}/` **+** `bin/plugins/{name}/` 双目录 | 仅 `bin/skills/{name}/` |
| `bin/plugins/{name}/` 内容 | 仅 `plugin.yaml` + `SKILL.md`（从 `skills/{name}` 抄来）+ 根级 `plugin_manifest.json` | **不存在** |
| 运行时读取 | 真正只读 `bin/skills`（经 `SKILL_INSTALL_PATH=./skills`，cwd=bin）；`bin/plugins` 从未被读取 | 同上，且明确无 `plugins` 读取路径 |

- **根因**：打包脚本 `src/scripts/package_release/main.cj` 的 **PS-T016 段落**曾把 `skills/{name}` 里的 `plugin.yaml`+`SKILL.md` 又抄一份到 `bin/plugins/{name}/` 并写 `plugin_manifest.json`。该段落**已废弃**，后续应从 `main.cj` 移除（移除不影响运行时，因运行时从不读 `bin/plugins`；`pluginuninstall.cj` 对 `bin/plugins` 的清理路径随之变为无害的 no-op）。
- `plugins/` 的残留清理责任：已安装旧版本的 `bin/plugins/` 由 `PcClientUninstall` 在卸载时一并删除（见该工程 design §3.4 对 `runtime` 的整体 `RMDir /r`，`bin/plugins` 位于 `runtime` 内随之清除）。

### 14.3 权威技能目录澄清

- **发布态真实用户技能目录 = `dataRoot/runtime/<plat>/release/bin/skills/`**（运行时 `SKILL_INSTALL_PATH=./skills` 指向此处）。
- `dataRoot/skills/` 实测常为**空目录**（历史/兜底路径），**不是**权威技能目录，卸载清理中以兜底 `RMDir` 处理即可，勿将其误当作"用户技能资产"保留。
- 根目录的 **`AGENTS.md`** 等提示词文件是用户可二次编辑内容，按 `specs/PcClientUserDataBackup` 由"备份用户数据"功能导出，**不在卸载保留范围**（卸载保留模式已简化为仅保数据库，见 `PcClientUninstall`）。

### 14.4 配套文档

- `README_cn.md`（发布包目录结构 + 内置技能发布形态）：已同步修订，删除 `bin/plugins/` 声明，明确融合布局。
- `specs/RuntimeNativeInstaller`、`specs/PcClientUserDataBackup`：本节的互补工程文档。
