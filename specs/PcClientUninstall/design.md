# PC 客户端卸载技术设计（Design）

> SDD 阶段：design（第 3 步）。
> 落盘位置：`apps/agentskills-runtime/specs/PcClientUninstall/design.md`
> 上游：`research.md`、`spec.md`；下游：`tasks.md`、`test-report.md`
> 关联工程：`PcClientUninstall`

---

## 文档信息
- **项目名称**: PC 客户端卸载残留修复（PcClientUninstall）
- **版本**: 1.0.0
- **创建日期**: 2026-11-01
- **作者**: SDD 编排（基于 research/spec）
- **状态**: 草稿（待闸口确认）

---

## 1. 设计概述

### 1.1 设计目标

在现有 `apps/pc-client/build/installer.nsh` 内**对称新增卸载分支**，使 Windows 卸载程序具备：(1) 第一步选择「保留/删除用户数据」；(2) 第二步按选择真正清理 `dataRoot`/`userData`，彻底解决"卸载后 1.5G 残留、磁盘未释放"问题。

### 1.2 设计原则

- **对称复用**：卸载期的 dataRoot 推算、进程强杀、单选页范式，全部仿写安装分支既有实现，避免另起炉灶与公式漂移。
- **最小侵入**：仅在 `installer.nsh` 增加 `!ifdef BUILD_UNINSTALLER` 分支 + 一处 `electron-builder.json` 配置确认；不动运行时业务代码。
- **安全优先**：默认"保留用户数据"，完全卸载才删数据库；删除范围严格限定本应用命名目录。

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 卸载脚本 | NSIS（`installer.nsh` 宏 + 自定义页） | electron-builder 已定义为 `nsis.include`，编译两遍（安装/卸载） |
| 进程管理 | `taskkill /F /IM ... /T` | 与安装期 `CloseRunningInstances` 同款 |
| 目录清理 | `RMDir /r` / `Delete` | NSIS 内置，支持递归删目录 |
| 用户选择 UI | `nsDialogs` | 与安装期 `DataChoicePage` 同框架 |
| 配置开关 | `electron-builder.json` `deleteAppDataOnUninstall` | 维持 `false`，由 NSIS 接管数据清理 |

---

## 2. 系统架构

### 2.1 卸载期模块划分（在 `installer.nsh` 内）

```
installer.nsh
├─ !ifndef BUILD_UNINSTALLER        （既有，安装期，不动）
│    ├─ ResolvePcDataRoot / ApplyDataChoice / customInstall / DataChoicePage ...
└─ !ifdef BUILD_UNINSTALLER         （新增，卸载期）
     ├─ UninstallDataChoicePage / Leave   ← Step1 选择页
     ├─ UninstallResolveDataRoot          ← 重算 dataRoot（默认公式 + config.json 覆盖）
     ├─ UninstallKillProcesses            ← taskkill /T 强杀
     └─ customUnInstall 宏               ← Step2 按选择清理
```

> electron-builder 编译卸载器时定义 `BUILD_UNINSTALLER`，安装分支的 Var/函数不展开；卸载分支同理包裹在 `!ifdef` 内，避免 warning 6010/6001（`-WX` 下会导致出包失败，见既有 `installer.nsh:22-32` 注记）。

### 2.2 与 electron-builder 默认卸载流的关系

```
electron-builder 卸载 Section
   ├─ (默认) 删除 $INSTDIR 安装文件
   ├─ (默认) 删除开始菜单/桌面快捷方式、注册表卸载项
   └─ !insertmacro customUnInstall   ← 本设计注入点
         1. UninstallKillProcesses
         2. UninstallResolveDataRoot（推算 dataRoot 候选列表）
         3. 分支：保留 / 完全
         4. 打印释放摘要
```

`customUnInstall` 由 electron-builder 在卸载 Section 内调用（约定钩子名，与安装期 `customInstall` 对称）。本宏**不删 `$INSTDIR`**（由默认流负责），只清理 `dataRoot`/`userData`。

---

## 3. 详细设计

### 3.1 卸载选择页（Step 1）

仿写安装期 `DataChoicePage`（`installer.nsh:55-77`），使用 `nsDialogs` 创建单选页，两个 RadioButton：

| 控件 | 文案 | 绑定变量 |
|---|---|---|
| RadioButton A（默认选中） | 保留用户数据（仅内嵌数据库与设置指针） | `$UninstallKeepData = "keep"` |
| RadioButton B | 完全卸载（删除全部，释放全部空间） | `$UninstallKeepData = "remove"` |

- 页面须展示信息文本：「保留模式仅保留内嵌数据库文件与设置指针，删除运行时、技能、登录态、日志等全部其余内容（约可释放 90%+ 空间）；可二次编辑的提示词/技能如需留存，请事先使用『备份用户数据』功能导出。完全卸载将不可逆删除数据库。」
- 页离开回调 `UninstallDataChoiceLeave`：确保选择已落入 `$UninstallKeepData`（缺省按 `keep`）。
- 注册方式：`UninstPage custom UninstallDataChoicePage UninstallDataChoiceLeave`（注意用 `UninstPage` 而非 `Page`，卸载期专用）。

### 3.2 dataRoot 卸载期重算

仿写 `ResolvePcDataRoot`（`installer.nsh:146-150`），新增卸载专用 `UninstallResolveDataRoot`：

```
1. 取 $INSTDIR 盘符（如 "D:"）+ 去掉盘符的 $APPDATA（"Users\x\AppData\Roaming"）
   → $DefaultDataRoot = "$Drive\$AppDataRel\agentskills-runtime-pc"
2. 读 $APPDATA\agentskills-runtime-pc\config.json：
   - 解析 JSON 的 "dataRoot" 字段
   - 若存在且路径合法（位于用户可写区、末段为 agentskills-runtime-pc）→ 加入候选 $CustomDataRoot
3. 候选列表 = [ $DefaultDataRoot, $CustomDataRoot(若有且≠默认) ]
   （旧版全在 userData 的情况：$DefaultDataRoot 已覆盖；config.json 覆盖处理高级场景）
```

> 与安装期公式逐字一致，杜绝"装卸载两边推算不一致导致漏删"。

### 3.3 进程强杀（Step 2 前置）

仿写 `CloseRunningInstances`（`installer.nsh:97-101`）：

```
Function UninstallKillProcesses
  nsExec::ExecToLog 'taskkill /F /IM "${PRODUCT_FILENAME}.exe" /T'
  Pop $0
  Sleep 1500
FunctionEnd
```

必须在 `RMDir` 之前调用，否则 PG/runtime 句柄占用导致删除失败。杀不掉不致命（重试一次后继续）。

### 3.4 自定义卸载宏（Step 2 核心）

```
!macro customUnInstall
  Call UninstallKillProcesses
  Call UninstallResolveDataRoot

  ${If} $UninstallKeepData == "remove"
    ; —— 完全卸载：删整个 dataRoot + 整个 userData ——
    RMDir /r "$DefaultDataRoot"
    ${If} $CustomDataRoot != ""
      RMDir /r "$CustomDataRoot"
    ${EndIf}
    RMDir /r "$APPDATA\agentskills-runtime-pc"
  ${Else}
    ; —— 保留用户数据：仅留内嵌数据库数据文件，删其余一切 ——
    ; 对每个候选 dataRoot 执行：
    RMDir /r "$DataRoot\runtime"          ; 大头，含 win-x64/release/bin/skills 发布态技能，可重建
    RMDir /r "$DataRoot\runtime-backups"
    RMDir /r "$DataRoot\pgsql\backup"
    RMDir /r "$DataRoot\logs"
    RMDir /r "$DataRoot\temp"
    RMDir /r "$DataRoot\auth"             ; 登录态可重登再生
    RMDir /r "$DataRoot\skills"           ; dataRoot/skills（实测常为空，兜底清理）
    Delete "$DataRoot\AGENTS.md"          ; 根目录用户可编辑提示词（备份由专用功能负责，卸载不保留）
    ; 保留：$DataRoot\pgsql\data（内嵌数据库数据文件）
    ; userData 仅保留 config.json（dataRoot 指针）；其余设置文件删除
    Delete "$APPDATA\agentskills-runtime-pc\window-state.json"
    Delete "$APPDATA\agentskills-runtime-pc\provision-state.json"
  ${EndIf}

  DetailPrint "卸载完成：已按『$UninstallKeepData』模式清理用户数据目录。"
!macroend
```

**目录清单（design 阶段集中常量，便于维护）**：

| 路径（相对 dataRoot） | 保留模式 | 完全模式 |
|---|---|---|
| `pgsql/data` | **保留**（唯一保留的数据） | 删（随 dataRoot 整体） |
| `auth` | **删**（可重登再生） | 删 |
| `skills` / `runtime/.../bin/skills` | **删**（用户技能，备份功能负责导出） | 删 |
| `AGENTS.md`（根目录） | **删**（可编辑提示词，备份功能负责导出） | 删 |
| `runtime` | **删**（含 bin/skills 发布态技能，可重建，大头） | 删 |
| `runtime-backups` | **删** | 删 |
| `pgsql/backup` | **删** | 删 |
| `logs` | **删** | 删 |
| `temp` | **删** | 删 |
| `userData`（整体） | **保留 `config.json`**，删除 window-state.json / provision-state.json | **删** |

### 3.5 与 `deleteAppDataOnUninstall` 的交互

`electron-builder.json:92` 维持 `"deleteAppDataOnUninstall": false`。原因：若设为 `true`，electron-builder 会在卸载**开头无条件**删除 `$APPDATA\<appName>`（userData），使"保留用户数据"模式无法保留 `config.json`。本设计由 NSIS 在 `customUnInstall` 内**条件化**控制 userData 去留，故必须保持 `false`。

### 3.6 静默卸载（/S）

非交互场景不显示 `UninstallDataChoicePage`，`$UninstallKeepData` 缺省为 `keep`（与 spec §4.1 / §5.1.4 一致）。electron-builder 对 `/S` 会跳过自定义页、直接进卸载 Section，`customUnInstall` 按 `keep` 执行即可，无需额外分支（变量缺省即安全默认）。

### 3.7 异常与边界（对应 spec §5.1.3）

| 场景 | 处理 |
|---|---|
| 进程强杀失败 | 重试一次；仍失败则跳过该目录并 `DetailPrint` 警告，继续其余清理 |
| dataRoot 不存在 | `RMDir /r` 对不存在目录为空跑，不报错，正常继续 |
| config.json 解析失败/非法 | 忽略覆盖值，仅用默认推算路径 |
| 目录被锁/无权限 | 记录路径，继续其余；结束页提示手动清理 |
| 旧版全在 userData | 默认推算路径已覆盖 `userData\agentskills-runtime-pc` 同级，且 `RMDir /r $APPDATA\agentskills-runtime-pc` 处理之 |

---

## 4. 数据设计

本设计**不引入任何新表/新文件格式**。仅复用既有 `config.json`（`userData` 内，字段 `dataRoot` 已存在）做最佳-effort 覆盖读取。删除动作均为文件系统 `RMDir`/`Delete`，无数据库写操作（卸载阶段不应再触碰已可能停服的数据库写路径；直接删文件即可）。

---

## 5. API / 接口设计

无新增 API。仅 NSIS 内部宏与页函数（非对外接口）：

| 名称 | 类型 | 说明 |
|---|---|---|
| `UninstallDataChoicePage` / `Leave` | NSIS 函数 | Step1 选择页 |
| `UninstallResolveDataRoot` | NSIS 函数 | 推算 dataRoot 候选列表 |
| `UninstallKillProcesses` | NSIS 函数 | taskkill /T |
| `customUnInstall` | NSIS 宏 | Step2 清理（注入卸载 Section） |

---

## 6. 安全设计

- **删除作用域锁定**：所有 `RMDir /r` 目标均为 `$DefaultDataRoot` / `$CustomDataRoot` / `$APPDATA\agentskills-runtime-pc`——均含固定后缀 `agentskills-runtime-pc` 且位于用户区，绝不拼接上层父目录，杜绝误删系统/其他用户数据。
- **数据库保护**：仅 `remove` 模式删 `pgsql/data`；`keep` 模式硬保留。删除前已强杀进程，避免写一半被截断。
- **config.json 覆盖校验**：自定义 dataRoot 须末段为 `agentskills-runtime-pc` 才采纳，防止恶意/误操作指向系统目录。

---

## 7. 性能设计

- 主耗时在 `RMDir /r runtime`（约 1.5G）。NSIS `RMDir /r` 为同步删除，本机 SSD 通常 < 30s；spec 上限 120s。若超时，NSIS 不会自动中止，但会在日志标记；后续可在结束页提示。当前不引入异步 shred。
- `taskkill` + `Sleep 1500` 为固定开销，远小于删除耗时。

---

## 8. 部署 / 出包设计

- 改动文件：`apps/pc-client/build/installer.nsh`（新增卸载分支）、`apps/pc-client/electron-builder.json`（确认 `deleteAppDataOnUninstall:false`，可能无需改）。
- 出包：`pnpm build:pc`（按既有红线，由用户在本地执行；AI 不跑 NSIS/makensis）。
- 验证：本机卸载 → 检查 dataRoot/userData 残留与磁盘释放，见 `test-report.md`。

---

## 9. 附录

### 9.1 与既有功能对比（已实现 / 需扩展 / 需新增）

| 能力 | 安装分支（既有） | 卸载分支（本设计） | 关系 |
|---|---|---|---|
| dataRoot 推算 | `ResolvePcDataRoot` 已实现 | `UninstallResolveDataRoot` 复刻同公式 | 复用公式，反向操作 |
| 进程强杀 | `CloseRunningInstances` 已实现 | `UninstallKillProcesses` 复刻 | 复用范式 |
| 选择页 | `DataChoicePage` 已实现 | `UninstallDataChoicePage` 仿写 | 反向语义（保留 vs 删） |
| 数据清理 | `ApplyDataChoice`（覆盖时清 pgsql）已实现 | `customUnInstall` 新增 | 全新（卸载侧原空白） |
| userData 清理 | 无（依赖 deleteAppDataOnUninstall） | `customUnInstall` 条件清理 | 新增且接管 |

### 9.2 参考文档
- `apps/pc-client/build/installer.nsh`（安装分支范式）
- `apps/pc-client/electron/utils/paths.ts`（dataRoot 权威定义）
- `apps/pc-client/electron-builder.json`（NSIS 配置）
- `apps/pc-client/electron/main/index.ts:637-660`（旧目录残留告警，提示重装风险）
- `skills/sdd/templates/*`（SDD 文档模板）
