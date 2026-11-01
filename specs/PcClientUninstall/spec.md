# PC 客户端卸载需求规格（Spec）

> SDD 阶段：spec（第 2 步）。
> 落盘位置：`apps/agentskills-runtime/specs/PcClientUninstall/spec.md`
> 上游：`research.md`（根因分析）；下游：`design.md`、`tasks.md`
> 关联工程：`PcClientUninstall`

---

# 1. 组件定位

## 1.1 核心职责

本组件负责在 Windows 卸载流程中**按用户选择真正清理 PC 客户端**，既支持彻底释放全部磁盘空间，也支持保留用户数据后仅清理可重建产物。

## 1.2 核心输入

1. Windows 卸载程序启动（来自控制面板 / 开始菜单卸载项 / 安装包修复入口）。
2. 用户在卸载自定义页的选择：**保留用户数据** 或 **完全卸载（删除全部）**。
3. 系统现状：`$INSTDIR`（安装目录）、`dataRoot`（跟随安装盘的数据根）、`userData`（Electron AppData）。

## 1.3 核心输出

1. 按选择清理后的文件系统状态（dataRoot / userData 的保留或删除）。
2. 卸载结束页的空间释放摘要（可选但推荐）。
3. Windows 注册表卸载项与快捷方式被移除（由 electron-builder 默认流程负责，本组件不重复）。

## 1.4 职责边界

- **负责**：卸载期的数据目录清理（dataRoot、userData 内的用户数据与可重建产物）。
- **不负责**：安装流程、覆盖安装的数据保留逻辑（那是 `installer.nsh` 安装分支的职责，本组件不改动）。
- **不负责**：修改运行时业务代码、数据库结构、发布包内容。
- **不负责**：跨平台（macOS dmg / Linux AppImage）卸载清理——本规格仅覆盖 Windows NSIS。

# 2. 领域术语

**dataRoot（数据根目录）**
: PC 客户端实际存放数据库、运行时、技能、登录态、日志的私有根目录；按"跟随安装盘"规则由 `paths.ts` 推导，如 `D:\Users\<user>\AppData\Roaming\agentskills-runtime-pc`。

**userData（Electron 用户数据目录）**
: `app.getPath('userData')` 返回的路径，即 `C:\Users\<user>\AppData\Roaming\agentskills-runtime-pc`，通常仅含 `config.json`、`window-state.json`、`provision-state.json`。

**用户数据（User Data）**
: 在本卸载流程中，**仅指内嵌 PostgreSQL 的业务数据库数据文件**（`pgsql/data`）——这是用户生成且不可再生的内容，保留模式下必须保留。
: 注：登录态（`auth`）、用户技能（`skills`/`bin/skills`）、根目录提示词文件（`AGENTS.md` 等）虽也是用户产物，但属「用户可二次编辑、可经『备份用户数据』功能导出」的内容，**不在卸载保留范围内**（见 `specs/PcClientUserDataBackup`）；卸载一律删除，以简化保留模式实现并避免残留不一致。

**可重建产物（Regenerable Artifacts）**
: 可由发布包重解压/重生成的内容——运行时本体（`runtime`）、运行时备份（`runtime-backups`）、数据库备份（`pgsql/backup`）、日志（`logs`）、临时文件（`temp`）。

**完全卸载（Full Uninstall）**
: 用户选择删除全部，卸载器移除安装目录、dataRoot、userData 全部内容，释放最大磁盘空间。

**保留模式（Keep-Data Mode）**
: 用户选择保留用户数据，卸载器仅删除可重建产物，保留真实用户数据。

# 3. 角色与边界

## 3.1 核心角色

- **终端用户**：启动卸载、在第一步做出"保留/删除"选择，期望卸载后系统干净或数据可恢复。
- **系统管理员（可选）**：通过静默卸载（`/S`）触发，无交互页，需有明确默认行为（见 DFX §4.1）。

## 3.2 外部系统

- **Windows Installer / NSIS 运行时**：承载卸载页与卸载区段执行。
- **electron-builder 默认卸载流**：负责 `$INSTDIR`、快捷方式、注册表；本组件在其 `customUnInstall` 钩子内插入数据清理。
- **PC 主进程 / 内嵌 PostgreSQL**：卸载前需被强杀以释放文件句柄（非调用方，是清理对象）。

## 3.3 交互上下文

```
┌──────────┐   启动卸载    ┌──────────────────┐   写入选择   ┌──────────────┐
│ 终端用户 │ ───────────▶ │ Windows 卸载程序  │ ───────────▶ │ (选择状态)   │
└──────────┘              │ (NSIS)           │              └──────────────┘
                          │  ├─ Step1 选择页  │
                          │  └─ Step2 清理    │
                          └────────┬─────────┘
                                   │ 强杀进程 + 按范围删文件
                 ┌─────────────────┼─────────────────┐
                 ▼                 ▼                 ▼
          ┌────────────┐   ┌──────────────┐   ┌──────────────┐
          │ $INSTDIR   │   │ dataRoot     │   │ userData     │
          │ (默认删)   │   │ (按选择清理) │   │ (按选择清理) │
          └────────────┘   └──────────────┘   └──────────────┘
```

# 4. DFX 约束

## 4.1 性能

- 卸载清理（含 1.5G runtime 删除）须在 **120 秒**内完成（`RMDir /r` 同步执行，超时视为异常需提示）。
- 静默卸载（`/S`）无交互页时，默认行为须确定：**默认"保留用户数据"**（防误删数据库），且不弹任何对话框。

## 4.2 可靠性

- 清理前**必须**先 `taskkill /F /IM "${PRODUCT_FILENAME}.exe" /T` 强杀 PC 主进程及其子进程（runtime、PostgreSQL），释放文件句柄后再删；杀不掉须重试一次并记日志，仍失败则跳过该目录并提示，不得中断整个卸载。
- dataRoot 不存在（如从未运行过）时，清理逻辑须**幂等空跑**，不得报错中断卸载。

## 4.3 安全性

- 删除范围**只限**本应用拥有的 `dataRoot` 与 `userData` 目录，**不得**递归删除其他用户目录、系统目录或 `$APPDATA` 父级。
- 仅当选择"完全卸载"时才删除 `pgsql/data` 数据库；保留模式**禁止**删除数据库。
- 自定义 `dataRoot`（config.json 覆盖）须先校验其确实位于用户可写区域且属于本应用命名（`agentskills-runtime-pc`），否则退回默认推算路径，避免误删。

## 4.4 可维护性

- 卸载分支与安装分支在 `installer.nsh` 内对称组织（`!ifdef BUILD_UNINSTALLER` / `!ifndef BUILD_UNINSTALLER`），dataRoot 推算逻辑两处**共用同一公式**，禁止各自硬编码。
- 保留/删除目录清单须集中在 design 阶段定义的可配置常量，便于后续调整。

## 4.5 兼容性

- 须兼容两种历史残留：`dataRoot` 在 D 盘（跟随安装盘）与 `userData` 在 C 盘（系统盘）并存；也兼容旧版全部落在 `userData` 的情况（`index.ts:637-660` 描述的旧目录残留）。
- NSIS 脚本必须用 `-WX` 兼容写法（避免 warning 6010/6001），与现有 `installer.nsh` 约束一致。

# 5. 核心能力

## 5.1 两步卸载主流程

### 5.1.1 业务规则

1. **卸载自定义页（Step 1）**：卸载器必须展示数据处理方式选择，至少两项——"保留用户数据"与"完全卸载（删除全部）"。
   a. 验收条件：用户启动非静默卸载 → 看到选择页且两项可选。
2. **默认与信息呈现**：默认选中"保留用户数据"；页面须展示两种模式各自将释放的磁盘空间估算与"完全卸载将不可逆删除数据库"警告。
   a. 验收条件：选择页默认勾选项为"保留用户数据"；页面含空间/警告信息。
3. **按选择执行清理（Step 2）**：
   - 完全卸载：删除 `$INSTDIR` 之外，还必须 `RMDir /r` 整个 `dataRoot` 与整个 `userData`。
     a. 验收条件：选"完全卸载"并完成后 → `dataRoot` 与 `userData` 目录均不存在。
   - 保留用户数据：仅保留内嵌数据库数据文件 `pgsql/data` 与指向它的 `userData/config.json`；删除其余一切（含 `runtime`、`runtime-backups`、`pgsql/backup`、`logs`、`temp`、`auth`、技能目录 `bin/skills`/`skills`、根目录 `AGENTS.md` 等可编辑提示词文件）。
     a. 验收条件：选"保留"并完成后 → `dataRoot/pgsql/data` 与 `userData/config.json` 仍存在，`runtime`/`skills`/`AGENTS.md`/`auth` 等已删除（实测空间大幅下降）；用户可编辑内容如需留存应事先用『备份用户数据』功能导出。
4. **静默卸载默认**：`/S` 模式不显示选择页，按"保留用户数据"执行。
   a. 验收条件：以 `/S` 卸载 → 不弹页，dataRoot 的 `runtime` 被删、数据库保留。

### 5.1.2 交互流程

```
用户 → 卸载程序: 启动卸载
卸载程序 → 用户: Step1 选择页（保留 / 完全卸载）
用户 → 卸载程序: 选择并继续
卸载程序 → customUnInstall:
   1. taskkill /T 强杀 PC/PG
   2. 重算 dataRoot（默认公式 + config.json 覆盖）
   3. 分支：
      保留 → 删除可重建产物，留 pgsql/data+auth+skills+config
      完全 → RMDir /r dataRoot + userData
   4. 打印释放摘要
卸载程序 → Windows: 继续默认卸载（$INSTDIR/快捷方式/注册表）
```

### 5.1.3 异常场景

1. **进程强杀失败**
   a. 触发条件：`taskkill` 返回非零且进程仍在。
   b. 系统行为：重试一次；仍失败则跳过该目录删除并 `DetailPrint` 警告，继续其余清理。
   c. 用户感知：结束页提示"部分文件可能被占用，请重启后手动删除：<路径>"。
2. **dataRoot 不存在**
   a. 触发条件：用户从未启动过 PC（dataRoot 未创建）。
   b. 系统行为：跳过 dataRoot 清理，仅处理 userData。
   c. 用户感知：无。
3. **目录删除权限不足**
   a. 触发条件：某子目录被其他进程锁定或无写权限。
   b. 系统行为：记录路径，继续其余；不中断卸载。
   c. 用户感知：结束页列出未删除路径。

## 5.2 dataRoot 卸载期重算

### 5.2.1 业务规则

1. **默认公式**：与安装期 `ResolvePcDataRoot` 逐字一致——取 `$INSTDIR` 盘符 + 去掉盘符的 `$APPDATA` 拼接 `agentskills-runtime-pc`。
   a. 验收条件：安装在 D 盘 → 推算 `D:\Users\<user>\AppData\Roaming\agentskills-runtime-pc`。
2. **config.json 覆盖**：读取 `userData/config.json` 的 `dataRoot` 字段；若存在且为合法本应用路径则作为真实 dataRoot 一并处理。
   a. 验收条件：用户曾自定义 dataRoot → 卸载按自定义路径清理而非默认推算。

### 5.2.2 交互流程

```
customUnInstall → 读 $INSTDIR 盘符 / $APPDATA → 推算默认 dataRoot
customUnInstall → 读 userData/config.json → (有 dataRoot?) → 加入候选列表
customUnInstall → 对候选列表逐个执行保留/删除分支
```

### 5.2.3 异常场景

1. **config.json 解析失败 / dataRoot 非法**
   a. 触发条件：JSON 损坏或 dataRoot 指向系统目录。
   b. 系统行为：忽略覆盖值，仅用默认推算路径。
   c. 用户感知：无（降级到安全路径）。

# 6. 数据约束

## 6.1 保留模式目录边界（逻辑约束）

> 简化原则：保留模式**只保护不可再生的内嵌数据库数据文件**，其余一律删除，使实现与验收都极简；用户可二次编辑的提示词/技能交由专门的『备份用户数据』功能处理（见 `specs/PcClientUserDataBackup`），卸载不再保留它们。

1. **pgsql/data**：必须保留（真实数据库，不可再生——唯一保留的数据）。
2. **config.json（userData）**：必须保留（它是 dataRoot 指针，删除后保留的 `pgsql/data` 将与新装实例失联；体积可忽略）。
3. **runtime**：必须删除（可重建，占空间大头；其下 `win-x64/release/bin/skills` 发布态技能随之删除）。
4. **runtime-backups**：必须删除（可重建）。
5. **pgsql/backup**：必须删除（非在线备份）。
6. **logs**：必须删除（可再生 + 可能含敏感信息）。
7. **temp**：必须删除（临时文件）。
8. **auth**：必须删除（登录态可经重新登录再生；不属保留范围）。
9. **skills / bin/skills / dataRoot/skills**：必须删除（用户技能资产，可经『备份用户数据』导出；卸载不保留以简化实现）。
10. **AGENTS.md 等根目录提示词文件**：必须删除（用户可二次编辑的提示词，卸载不保留；如需留存应先备份）。

## 6.2 完全卸载目录边界

1. **dataRoot（整体）**：必须删除。
2. **userData（整体）**：必须删除。
3. **$INSTDIR**：由 electron-builder 默认卸载负责删除，本组件不重复（避免与卸载器自删除冲突）。
