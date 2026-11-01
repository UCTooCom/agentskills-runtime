# 设计方案：PC 客户端首次运行引导（PcFirstRunBootstrap）

> 阶段：design
> 工程：`specs/PcFirstRunBootstrap`
> 上游：`research.md`（草稿）+ `spec.md`（草稿）
> 日期：2026-10-21 · 版本 v0.1 · 状态：草稿

---

## 1. 需求与存量功能关系分析

| 能力（对应 spec §5） | 存量基础设施 | 状态 | 本设计动作 |
|---|---|---|---|
| §5.1 安装后自动初始化 | `installer/cmd/install_cmd.cj`（S0~S8 编排）、`installer/services/bcrypt_admin.cj`（管理员创建）、`installer/services/seed/*`（seed 导入） | 已实现（installer 侧） | **NSIS 脚本改造**：安装后调 `ucInstaller.exe install`，传随机管理员参数 |
| §5.2 自动启停 | `installer/serve/manage.cj`（`serve --manage` 运维管控）、`pc-client/electron/main/index.ts:607`（autoStart 判断）、`pc-client/electron/modules/config.ts`（autoStart 配置） | 部分实现（PC 侧 Phase 4 未完成） | **Electron 主进程改造**：接通 `serve --manage` 启停调用，填补 Phase 4 缺口 |
| §5.3 首次欢迎页面 | `pc-client/electron/modules/setup.ts`（安装向导）、`pc-client/src/views/`（Vue 页面目录） | 未实现 | **新建**：`first-run.ts` 检测 + `Welcome.vue` 欢迎页 |
| §5.4 重装数据保留选择 | `pc-client/build/installer.nsh`（NSIS 钩子） | 未实现 | **NSIS 脚本改造**：增加自定义页面 + 保留/覆盖逻辑 |
| 管理员凭据传递 | `installer` `--json` NDJSON 输出 | 已实现 | **新建**：`admin-credentials.ts` 解析 NDJSON + 写标记文件 |
| installer 路径发现 | `pc-client/electron/modules/runtime-integrator.ts`（`getRuntimeBinPath()`） | 已实现 | **复用**：同目录取 `ucInstaller.exe` |
| installer 桥接 | `pc-client/electron/modules/installer-bridge.ts`（Phase 3 已落盘） | 已实现 | **改造复用**：增加 `install` + `serveManage` 方法 |

> 结论：本工程**不新建任何仓颉代码、不新建数据库表**，纯编排 + 三处改造（NSIS 脚本 / Electron 主进程 / Vue 欢迎页）+ 两处新建（first-run.ts / Welcome.vue）。符合 SDD 铁律 9（复用优先）。

---

## 2. 实现模型

### 2.1 安装时序：NSIS → installer → 标记文件

```
用户双击 Installer.exe
  │
  ▼
NSIS 解压文件（electron-builder 原有）
  │
  ▼
NSIS 检测目标目录是否已有安装
  ├─ 无已有安装 → 首次安装流程
  └─ 有已有安装 → 弹出数据保留选择页面
      ├─ 覆盖安装 → 首次安装流程
      └─ 保留数据 → 仅更新程序文件，跳过初始化
  │
  ▼  [首次安装流程]
NSIS 生成随机管理员 email + 密码
  │  email = <8位随机>@uctoo.com
  │  password = <16位随机含大小写+数字+特殊>
  │
  ▼
NSIS 执行: ucInstaller.exe install --json --progress=ndjson \
    --admin-email=<email> --admin-password=<password> --admin-name=admin
  │
  ├─ NDJSON 事件流 → NSIS 进度条实时更新
  │  {kind:"start"} → {kind:"step",step:"S0",...} → ... → {kind:"final",exitCode:0}
  │
  ├─ install 成功 (exitCode=0):
  │    → 从 NDJSON final 事件提取管理员信息
  │    → 写 first-run-credentials.json
  │    → 安装完成
  │
  └─ install 失败 (exitCode!=0):
       → 提示错误原因
       → 提供"回滚"按钮 → ucInstaller.exe rollback
```

### 2.2 启动时序：Electron → serve --manage → 欢迎页/首页

```
用户打开 PC 客户端
  │
  ▼
Electron app.whenReady()
  │
  ├─ 读取 default-config.json
  │
  ├─ if runtime.autoStart:
  │    → installerBridge.serveManage()
  │      → spawn ucInstaller.exe serve --manage
  │      → 监听 NDJSON 事件 → 更新 runtime/PG 服务状态
  │      → 失败 → 导航栏显示异常，不阻塞
  │
  ├─ if webadmin.autoStart:
  │    → 启动 web-admin HTTP 服务（既有逻辑）
  │
  ├─ firstRun.checkCredentials()
  │    → 读取 first-run-credentials.json
  │    ├─ 存在且有效 → 渲染 Welcome.vue
  │    │    → 显示 email / username / password
  │    │    → 用户点击"已记录" → 删除标记文件 → 跳转首页
  │    └─ 不存在/损坏 → 直接加载首页
  │
  └─ 加载首页 iframe（既有逻辑）
```

### 2.3 退出时序：自动停止

```
Electron app.on('before-quit')
  │
  ├─ installerBridge.stopManage()
  │    → 向 serve --manage 发送停止信号
  │    → 等待 runtime + PG 进程退出（超时 10s）
  │
  └─ app.exit()
```

### 2.4 NSIS 脚本改造（installer.nsh）

```nsis
; === PcFirstRunBootstrap 新增 ===

; 1. 检测已有安装
Function CheckExistingInstall
  IfFileExists "$INSTDIR\AgentSkills Runtime.exe" 0 firstInstall
    ; 有已有安装 → 弹出选择页面
    Call ShowDataChoicePage
    Goto installDone
  firstInstall:
    StrCpy $isFirstInstall "true"
  installDone:
FunctionEnd

; 2. 数据保留选择页面
Function ShowDataChoicePage
  ; NSIS 自定义页面：单选"覆盖安装/保留数据"
  ; 覆盖 → StrCpy $isFirstInstall "true"
  ; 保留 → StrCpy $preserveData "true"
FunctionEnd

; 3. 安装后初始化
Section "PostInstall" SEC_POST
  ${If} $isFirstInstall == "true"
    ; 生成随机管理员
    Call GenerateRandomAdmin
    ; 执行 ucInstaller.exe install
    nsExec::ExecToLog '"$INSTDIR\resources\runtime\release\bin\ucInstaller.exe" install --json --progress=ndjson --admin-email=$adminEmail --admin-password=$adminPassword --admin-name=admin'
    Pop $exitCode
    ${If} $exitCode == 0
      ; 写标记文件
      Call WriteCredentialsMarker
    ${Else}
      MessageBox MB_OK "初始化失败，请选择回滚或重试"
    ${EndIf}
  ${EndIf}
SectionEnd
```

### 2.5 Electron 主进程改造（index.ts）

```typescript
// === PcFirstRunBootstrap 新增 ===

// 1. 自动启停（填补 Phase 4）
async function autoStartServices(config: AppConfig) {
  if (config.runtime?.autoStart !== false) {
    try {
      await installerBridge.serveManage();
      ipcHandler.sendToRenderer('service:started', { service: 'runtime' });
    } catch (err) {
      ipcHandler.sendToRenderer('service:startFailed', { service: 'runtime', error: err.message });
    }
  }
  if (config.webadmin?.autoStart !== false) {
    await webAdminServer.start();
  }
}

// 2. 首次欢迎页检测
async function checkFirstRun() {
  const credentials = await firstRun.readCredentials();
  if (credentials) {
    mainWindow.loadURL(`file://${__dirname}/../renderer/welcome.html`);
    ipcHandler.registerHandler('first-run:confirm', async () => {
      await firstRun.deleteCredentials();
      mainWindow.loadURL(HOME_URL);
    });
  } else {
    mainWindow.loadURL(HOME_URL);
  }
}

// 3. 退出时自动停止
app.on('before-quit', async () => {
  await installerBridge.stopManage();
});

// 在 app.whenReady() 中串接
app.whenReady().then(async () => {
  const config = await loadConfig();
  await autoStartServices(config);
  await checkFirstRun();
});
```

### 2.6 欢迎页面（Welcome.vue）

```vue
<template>
  <div class="welcome-container">
    <h1>欢迎使用 AgentSkills Runtime</h1>
    <p>系统已自动创建管理员账号，请妥善保管以下信息：</p>
    <div class="credentials-card">
      <div class="field">
        <label>邮箱</label>
        <code>{{ credentials.email }}</code>
      </div>
      <div class="field">
        <label>用户名</label>
        <code>{{ credentials.username }}</code>
      </div>
      <div class="field">
        <label>密码</label>
        <code>{{ credentials.password }}</code>
        <button @click="copyPassword">复制</button>
      </div>
    </div>
    <button class="confirm" @click="confirm">已记录并理解</button>
  </div>
</template>
```

---

## 3. 接口设计

### 3.1 NSIS → installer CLI

| 命令 | 参数 | 说明 |
|---|---|---|
| `ucInstaller.exe install` | `--json --progress=ndjson --admin-email=<email> --admin-password=<pwd> --admin-name=admin` | 安装后初始化，NDJSON 流式输出 |
| `ucInstaller.exe rollback` | 无 | 初始化失败回滚 |
| `ucInstaller.exe serve --manage` | `--auto-exit`（可选） | PC 启动时运维管控 |

### 3.2 Electron 内部 IPC

| 通道 | 方向 | 说明 |
|---|---|---|
| `service:started` | main → renderer | 服务启动成功 |
| `service:startFailed` | main → renderer | 服务启动失败 |
| `first-run:confirm` | renderer → main | 用户确认已记录管理员账号 |

### 3.3 标记文件格式（first-run-credentials.json）

```json
{
  "version": 1,
  "email": "a3k9x2m1@uctoo.com",
  "username": "admin",
  "name": "admin",
  "password": "Rk9#mP2xLq!7vN4w",
  "createdAt": "2026-10-21T10:46:00Z"
}
```

---

## 4. 数据模型

- **不新建任何数据库表**（铁律 9）。
- 管理员写入既有 `uctoo_user` 表（installer S5 已实现）。
- seed 导入既有表（installer S6 已实现）。
- 标记文件 `first-run-credentials.json` 存放于 `<用户数据目录>/`（非安装目录，卸载不删除，但展示后自动删除）。

---

## 5. 进度可观测

- **安装初始化进度**：NSIS 安装页面显示进度条，来自 installer NDJSON 流的 `step` 事件。
- **启停状态**：PC 导航栏显示 runtime/PG 服务状态图标（绿/红/黄），来自 `serve --manage` NDJSON 事件。
- **日志**：
  - 安装初始化日志：`<安装目录>/logs/install-init.log`（NDJSON 流重定向）。
  - 启停日志：`<安装目录>/logs/serve-manage.log`。

---

## 6. 人在回路

- **安装后初始化**：全自动，不需人工介入。失败时提供回滚选项。
- **欢迎页面**：用户必须主动点击"已记录并理解"才删除标记文件并跳转首页。
- **重装选择**：用户必须主动选择"覆盖安装"或"保留数据"。
- **自动启停**：全自动，不需人工介入。失败时显示异常状态 + 手动重启入口。

---

## 7. 防回退约束

| 风险 | 约束 |
|---|---|
| NSIS 脚本改造导致安装失败 | 改造后必须人工执行 `pnpm build:pc` 验证安装包可正常安装 |
| installer 路径发现错误 | 复用 `runtime-integrator.ts` 的 `getRuntimeBinPath()`，与 runtime 同目录 |
| 标记文件明文密码泄露 | 展示后立即删除；文件权限仅当前用户可读；不写入日志 |
| 自动启停阻塞首页 | 启停失败不阻塞首页加载（catch + 显示异常状态） |
| 保留数据安装误覆盖 | NSIS 保留数据分支不执行 `ucInstaller.exe install`，仅解压程序文件 |
| serve --manage 与既有 pgsql.ts 冲突 | 既有 `pgsql.ts` 降级为 fallback，`serve --manage` 为主通道（Q-3 决策） |

---

## 8. 实施分期

- **P0（核心闭环）**：NSIS 安装后初始化 + Electron 自动启停 + 欢迎页面。覆盖 spec §5.1~§5.3。
- **P1（重装体验）**：NSIS 数据保留选择页面。覆盖 spec §5.4。
- **P2（健壮性）**：初始化失败回滚 + 端口冲突处理 + 标记文件损坏恢复。

---

## 9. 与 PcClientInstallerIntegration 的关系

本工程与 `PcClientInstallerIntegration` Phase 4（托管层）有交集：

| 交集点 | 本工程负责 | PcClientInstallerIntegration 负责 |
|---|---|---|
| `serve --manage` 启停 | PC 启动时自动调用 | Phase 4 托管层完整对接（含手动启停 UI） |
| `installer-bridge.ts` | 增加 `serveManage` 方法 | Phase 3 已有 `install` 桥接基础 |
| `pgsql.ts` 降级 | 降级为 fallback | Phase 4 统一管控 |

> 本工程聚焦"首次运行引导"（安装后初始化 + 首次欢迎 + 自动启停），PcClientInstallerIntegration 聚焦"长期托管"（手动启停 UI + 版本升级 + 配置管理）。两者互补，不冲突。