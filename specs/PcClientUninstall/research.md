# PC 客户端卸载残留问题 — 研究文档（Research）

> SDD 阶段：research（第 1 步，可选但本次强制，因需先定位根因）。
> 落盘位置：`apps/agentskills-runtime/specs/PcClientUninstall/research.md`
> 关联工程：`PcClientUninstall`（卸载规范驱动开发）

---

# 用户原始需求

用户通过 Windows「卸载程序」卸载 PC 客户端后，发现以下两个目录仍残留在系统中：

- `D:\users\patrick\AppData\Roaming\agentskills-runtime-pc`（数据根目录，跟随安装盘）
- `C:\Users\patrick\AppData\Roaming\agentskills-runtime-pc`（Electron userData）

用户诉求：卸载程序应**真正删除**不需要的 PC 客户端文件、释放磁盘空间；并要求卸载分两步——第一步让用户选择是否保留用户数据，第二步按第一步的选择按范围卸载。若选择保留用户数据，须自行分析应保留哪些，给出符合业界最佳实践的方案。

---

# 研究结果

## 一、现状与定位

### 1.1 问题性质

这是一个**卸载器（uninstaller）不完整**的问题，不是安装器问题。安装器（`installer.nsh` 的 `!ifndef BUILD_UNINSTALLER` 分支）逻辑完整，自带「覆盖安装 / 保留已有数据」自定义页。但卸载侧**没有任何自定义逻辑**，electron-builder 在 `deleteAppDataOnUninstall:false` 下只做最小清理，导致用户数据目录被整体遗留。

### 1.2 残留目录实测（只读核验，2026-11-01）

| 路径 | 性质 | 实测体积 | 内部构成 |
|---|---|---|---|
| `D:\users\patrick\AppData\Roaming\agentskills-runtime-pc` | **dataRoot**（跟随安装盘，见 `electron/utils/paths.ts` 的 `getDataRoot`） | **1.5 GB** | `runtime` ≈1.5G（可重建本体+备份）、`pgsql` 77M（其中 `pgsql/data` 真实数据库）、`skills` 0、`logs` 3.8M |
| `C:\Users\patrick\AppData\Roaming\agentskills-runtime-pc` | **userData**（Electron `app.getPath('userData')`） | 极小 | `config.json`（存 dataRoot 指针）、`window-state.json`、`provision-state.json` |

> 关键结论：**1.5 GB 里约 1.5G 是 `runtime` 可重建产物，仅约 77M 是真实用户数据库**。`skills` 在此实例为空、非用户数据负担点。

## 二、根因分析（三连因）

### 2.1 根因 A：electron-builder 被显式配置为「不清理 userData」

`apps/pc-client/electron-builder.json:92`：

```json
"nsis": {
  "deleteAppDataOnUninstall": false,   // ← 关闭了 userData 自动清理
  ...
}
```

该选项为 `true` 时，electron-builder 会在卸载开头无条件删除 `$APPDATA\<appName>`（即 C 盘 userData）。当前为 `false`，C 盘 userData **不会**被清理。

### 2.2 根因 B：`installer.nsh` 只有安装期逻辑，卸载侧完全空白

`apps/pc-client/build/installer.nsh` 的全部自定义逻辑都被 `!ifndef BUILD_UNINSTALLER` 包裹（第 33–231 行），即**仅作用于安装器那一遍编译**。该文件：

- 没有 `!ifdef BUILD_UNINSTALLER` 分支；
- 没有 `customUnInstall` 宏（electron-builder 卸载期唯一可注入的钩子）；
- 没有 `UninstPage custom ...` 卸载自定义页。

因此卸载器只执行 electron-builder 的默认动作：删除 `$INSTDIR`（安装目录）、开始菜单/桌面快捷方式、注册表卸载项。对用户数据目录（`dataRoot` + `userData`）**一无所知**，自然不删。

### 2.3 根因 C：dataRoot 是 PC 应用私有推导路径，打包器无从知晓

`electron/utils/paths.ts:71-96` 的 `getDataRoot()`：把 `userData` 的路径结构**换盘映射**到安装盘（`C:\Users\x\AppData\Roaming\<app>` 装到 D 盘 → `D:\Users\x\AppData\Roaming\<app>`）。这个目录是运行时才存在的私有路径，**不在 electron-builder 的 `files`/`extraResources` 清单里**，打包器在卸载时不可能知道它。

### 2.4 根因链条总结

```
deleteAppDataOnUninstall=false   (根因A)
   + installer.nsh 无卸载分支   (根因B)
   + dataRoot 私有路径           (根因C)
        ↓
Windows 卸载程序执行 → 仅删 $INSTDIR + 快捷方式 + 注册表
        ↓
dataRoot(1.5G) 与 userData 全部残留 → 磁盘未释放、重装可能探测到旧目录异常
```

## 三、已有可复用基础设施盘点

| 类别 | 文件 | 可复用什么 |
|---|---|---|
| 安装期数据根推算 | `installer.nsh:146-150` `ResolvePcDataRoot` | 卸载期可**原样复用**同一套「安装盘 + APPDATA → dataRoot」换算公式 |
| 安装期强杀旧实例 | `installer.nsh:97-101` `CloseRunningInstances`（`taskkill /F /IM ... /T`） | 卸载期同样需要在删文件前强杀 PC/PostgreSQL 进程以释放句柄 |
| 运行时路径权威定义 | `electron/utils/paths.ts` | design 阶段据此枚举 dataRoot 子目录（pgsql/data、runtime、skills、auth、logs…） |
| 安装期「保留/覆盖」页范式 | `installer.nsh:55-127` `DataChoicePage` | 卸载页可**仿写**其 nsDialogs 单选按钮 + leave 回调结构 |
| 配置覆盖读取 | `electron/modules/config.ts`（`config.dataRoot`） | 卸载期读 `userData/config.json` 解析自定义 dataRoot（最佳-effort 增强） |

> 不重复实现：安装器已有的「路径推算」「进程强杀」「单选页」范式是卸载器的直接地基，卸载分支应**仿写 + 反向操作**，而非另起炉灶。

## 四、能力缺口分析（已有 vs 待建）

| 缺口 | 现状 | 待建（本工程范围） | 复用/新建 |
|---|---|---|---|
| 卸载自定义页 | 无 | 第一步「保留/删除用户数据」选择页 | 仿写 DataChoicePage |
| 卸载清理钩子 | 无 | `customUnInstall` 宏按范围清理 dataRoot/userData | 新建（NSIS 宏 + RMDir） |
| dataRoot 卸载期重算 | 无 | 与安装期同公式重算 + 读 config.json 覆盖 | 复用 ResolvePcDataRoot 思路 |
| 卸载期进程强杀 | 无 | 删文件前强杀 PC/PG | 复用 CloseRunningInstances 思路 |
| 保留/删除的精确目录清单 | 无 | 界定「用户数据」边界（见 §五） | 新建（设计决策） |
| `deleteAppDataOnUninstall` 策略 | `false` | 维持 `false`，改由 NSIS 统一条件控制 | 配置调整 |

## 五、推荐工程方案

### 5.1 总体形态

在现有 `installer.nsh` 内**新增一个 `!ifdef BUILD_UNINSTALLER` 分支**，实现「卸载自定义页 + `customUnInstall` 宏」，与现有安装分支对称。不引入新工程、不改动 electron-builder 的默认卸载流程（仅把 `deleteAppDataOnUninstall` 维持 `false`，由 NSIS 接管全部数据目录清理）。

### 5.2 两步卸载编排草图

```
[Windows 卸载程序启动]
        │
        ▼
Step 1  卸载自定义页：选择数据处理方式
        (○ 保留用户数据   ● 完全卸载/删除全部)
        │
        ▼
Step 2  customUnInstall 宏（按选择执行）
        ├─ 强杀 PC/PG 进程（taskkill /T）
        ├─ 始终：删 $INSTDIR 安装目录（electron-builder 默认已做，宏内不重复）
        ├─ 保留模式：保留 真实用户数据，删 可重建产物（释放 ~95% 空间）
        └─ 完全模式：RMDir /r dataRoot + RMDir /r userData（彻底释放）
        │
        ▼
结束页：打印释放空间摘要
```

### 5.3 「保留用户数据」的边界（业界最佳实践，本工程核心设计决策）

业界（VS Code、Docker Desktop、多数 Electron 应用）的「保留数据」指保留**用户生成的、不可再生的内容**，删除**可再生的程序产物/缓存/日志**。据此界定本工程 dataRoot 子目录归属：

| 目录（相对 dataRoot） | 是否用户数据 | 保留模式处理 | 理由 |
|---|---|---|---|
| `pgsql/data` | ✅ 是 | **保留** | 真实业务数据库（agent/entity/技能配置/用户内容），不可再生 |
| `auth` | ✅ 是 | **保留** | 登录态（token.enc / userinfo.json），用户凭证 |
| `skills` | ✅ 是（用户新增/修改的技能） | **保留** | 用户侧技能资产 |
| `config.json`（位于 userData） | ✅ 是 | **保留** | 设置（含 dataRoot 指针） |
| `runtime` | ❌ 否 | **删除** | 从发布包 tar.gz 重解压即可重建，占 1.5G 大头 |
| `runtime-backups` | ❌ 否 | **删除** | 备份，可重建 |
| `pgsql/backup` | ❌ 否 | **删除** | 数据库备份，非在线数据 |
| `logs` | ❌ 否 | **删除** | 诊断日志，可再生且可能含敏感信息 |
| `temp` | ❌ 否 | **删除** | 临时文件 |

> **核心洞察**：即便选「保留用户数据」，也只保留约 77M 的真实数据库，删除 1.5G 可重建 runtime——**既保护用户数据不丢，又释放约 95% 磁盘空间**，正好回应"卸载应真正释放空间"的诉求。

### 5.4 需新建的最小集合

- `installer.nsh`：`!ifdef BUILD_UNINSTALLER` 分支，含 `UninstallDataChoicePage`/`Leave`、`customUnInstall` 宏、`UninstallResolveDataRoot`（复用安装期公式 + 读 config.json 覆盖）。
- `electron-builder.json`：确认 `deleteAppDataOnUninstall:false`（不改动，由 NSIS 接管）。
- 无新表、无新后端、无新依赖。

## 六、关键设计决策与风险

1. **默认选项**：推荐默认「保留用户数据」（防误删数据库），但页面须醒目展示两种模式各自将释放的空间与「完全卸载将不可逆删除数据库」警告。用户明确要求"释放空间"，保留模式通过删 runtime 已能释放 ~95%，故不牺牲安全性。
2. **进程强杀时机**：必须在 `RMDir` 之前 `taskkill /F /IM "${PRODUCT_FILENAME}.exe" /T`，否则 PG/runtime 句柄占用导致删除失败（安装期已踩过同类坑，见 `installer.nsh:80-101`）。
3. **卸载器自删除**：electron-builder 的卸载器会从 temp 副本运行并自删，`$INSTDIR` 删除由它负责；本宏**只管 dataRoot/userData**，不碰 `$INSTDIR`，避免与默认流程冲突。
4. **自定义 dataRoot**：若 `config.json` 显式指定 `dataRoot`（高级场景），卸载期应读它作为真实 dataRoot 一并清理/保留，否则会漏掉实际数据目录（计算出的默认路径此时可能为空）。
5. **约束**：本 SDD 阶段不运行 `cjpm build` / NSIS 编译；NSIS 改动由用户在本地 `pnpm build:pc` 出包验证（与项目既有红线一致：编译/打包由人工执行）。

## 七、后续步骤指引

- **下一步（spec）**：固化 REQ-UNINST-001~00x——两步卸载流程、保留/删除目录清单、EARS 验收、DFX（尤其可靠性：强杀后清理必须成功；安全性：不得误删其他用户数据）。
- **再下一步（design）**：给出 `installer.nsh` 卸载分支的完整 NSIS 实现模型、`customUnInstall` 删除清单、与 `deleteAppDataOnUninstall` 的交互、异常（目录不存在/进程杀不掉/权限不足）处理。
- **任务规划**：约 6–9 条任务，单技术栈（NSIS + 少量 TS 配置），无需多子系统拆分（未触达铁律 15 阈值）。

---

# 附录 A：本研究直接复用的关键文件索引

| 用途 | 文件 | 复用方式 |
|---|---|---|
| 安装期 dataRoot 推算 | `apps/pc-client/build/installer.nsh:146-150` | 原样复用公式 |
| 安装期强杀旧实例 | `apps/pc-client/build/installer.nsh:97-101` | 复用 taskkill /T 范式 |
| 运行时路径权威定义 | `apps/pc-client/electron/utils/paths.ts:71-135` | 枚举待清理子目录 |
| 安装期选择页范式 | `apps/pc-client/build/installer.nsh:55-127` | 仿写卸载页 |
| 卸载配置开关 | `apps/pc-client/electron-builder.json:88-100` | 维持 false，NSIS 接管 |
| 旧目录残留告警逻辑 | `apps/pc-client/electron/main/index.ts:637-660` | 理解重装探测旧目录风险 |

---

> **修订（2026-11-01）**：保留模式已**简化为仅保留内嵌数据库数据文件 `pgsql/data` + `config.json` 指针**。
> 原分析中"保留 `auth`/`skills`"的设想被推翻——`auth` 可重登再生、`skills` 与根目录 `AGENTS.md` 等用户可编辑内容
> 交由专门的 **「备份用户数据」功能**（`specs/PcClientUserDataBackup`）在卸载前导出，卸载不再保留它们，
> 以大幅降低保留模式实现复杂度。权威结论以 `spec.md` §6.1 与 `design.md` §3.4 为准。
> 另：实测权威用户技能目录是 `runtime/win-x64/release/bin/skills/`，而非 `dataRoot/skills/`（后者常为空）；
> 卸载清理对两者均做删除。
