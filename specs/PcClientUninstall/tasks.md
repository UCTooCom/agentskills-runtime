# PC 客户端卸载任务规划（Tasks）

> SDD 阶段：task（第 4 步）。
> 落盘位置：`apps/agentskills-runtime/specs/PcClientUninstall/tasks.md`
> 关联需求：`spec.md`；关联设计：`design.md`
> 关联工程：`PcClientUninstall`

---

## 文档信息
- 关联需求：`spec.md`（两步卸载、保留/删除目录边界、DFX）
- 关联设计：`design.md`（NSIS 卸载分支、customUnInstall 宏）
- 生成日期：2026-11-01 / 版本：1.0.0 / 状态：草稿（待闸口）

---

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：本工程为 NSIS 脚本（`installer.nsh`）+ 一处 JSON 配置，**不触发仓颉/前端编程技能**；由主 agent 按 SDD design 直接编辑，编译/打包（`pnpm build:pc`、makensis）由用户在本地执行（红线：AI 不跑 NSIS/cjpm 编译与出包）。
- **对称复用**：卸载分支的 dataRoot 推算、进程强杀、单选页须**仿写** `installer.nsh` 既有安装分支，禁止新写不一致公式。
- **-WX 合规**：卸载分支全部符号须包裹在 `!ifdef BUILD_UNINSTALLER` 内，避免卸载器编译时出现 warning 6010/6001（warning 即错误会断出包，见 `installer.nsh:22-32`）。
- **幂等与安全**：`RMDir /r` 对不存在目录空跑不报错；删除作用域必须含固定后缀 `agentskills-runtime-pc`，不得拼接父目录。
- **不改动运行时业务代码**；不动 `electron-builder.json` 的 `files`/`extraResources`。

---

## 任务总览

| 编号 | 任务 | 关联需求(spec §) | 关联设计(design §) | 负责子 agent | 状态 | 预计产出 |
|---|---|---|---|---|---|---|
| T-01 | 新增 `!ifdef BUILD_UNINSTALLER` 分支骨架 + 卸载专用 Var 声明 | §1.4, §4.5 | §2.1 | 主 agent | 待开始 | installer.nsh 卸载分支骨架 |
| T-02 | 实现 `UninstallResolveDataRoot`（默认公式 + config.json 覆盖） | §3.2, §5.2, §6.1 | §3.2 | 主 agent | 待开始 | dataRoot 候选列表逻辑 |
| T-03 | 实现 `UninstallKillProcesses`（taskkill /T 强杀） | §4.2, §5.1.3 | §3.3 | 主 agent | 待开始 | 进程强杀函数 |
| T-04 | 实现 `UninstallDataChoicePage` + Leave（Step1 选择页） | §3.1, §5.1.1 | §3.1 | 主 agent | 待开始 | nsDialogs 卸载页 |
| T-05 | 实现 `customUnInstall` 宏（Step2 保留/完全 两分支删除清单） | §3.1, §5.1.1, §6.2 | §3.4, §3.5 | 主 agent | 待开始 | 条件清理宏 |
| T-06 | 接入 `UninstPage custom` 与 `!insertmacro customUnInstall` | §3.1, §5.1.2 | §2.2 | 主 agent | 待开始 | 页+宏接线 |
| T-07 | 确认 `electron-builder.json` `deleteAppDataOnUninstall:false` 不改 | §4.3, §6.1 | §3.5 | 主 agent | 待开始 | 配置确认（可能零改动） |
| T-08 | 本地出包 + 双模式卸载验证（保留/完全）+ 磁盘释放核验 | §4.1, §5.1 | §8 | 用户+主 agent 辅助 | 阻塞（依赖出包） | 验证报告（见 test-report.md） |

---

## 任务依赖关系图

```
T-01 → T-02 → T-03 ┐
        T-01 → T-04 ┤
        T-01 → T-05 ┘→ T-06 → T-07 → T-08(人工出包验证)
```

- T-02/T-03/T-04/T-05 均依赖 T-01 骨架，彼此可并行。
- T-06 依赖 T-04（页）、T-05（宏）完成。
- T-07 可在任意阶段确认（零改动风险低）。
- T-08 为人工出包验证闸门，阻塞于 T-06。

---

## 任务详细说明

### T-01 卸载分支骨架
- **目标**：在 `installer.nsh` 文件末尾（安装分支 `!endif` 之后）新增 `!ifdef BUILD_UNINSTALLER ... !endif` 包裹区，声明卸载专用 Var（`UninstallKeepData`、`UnDataRoot`、`UnCustomDataRoot` 等）。
- **输入**：既有安装分支结构（`installer.nsh:33-231`）。
- **步骤**：① 在文件尾部 `!endif ; BUILD_UNINSTALLER`（第 231 行之后）追加 `!ifdef BUILD_UNINSTALLER`；② 声明 `Var /GLOBAL UninstallKeepData` 等；③ 确保安装分支的 Var 不在卸载编译期报未使用（已因其 `!ifndef` 包裹而隔离）。
- **产出物**：installer.nsh 卸载分支空骨架。
- **验收**：NSIS 编译两遍时卸载分支无 warning 6010/6001（人工 `pnpm build:pc` 回传）。
- **风险**：Var 声明位置错误导致两遍编译冲突——必须放在 `!ifdef BUILD_UNINSTALLER` 内。

### T-02 dataRoot 重算
- **目标**：实现 `UninstallResolveDataRoot`，与安装期 `ResolvePcDataRoot`（`installer.nsh:146-150`）公式逐字一致，并读 `userData/config.json` 的 `dataRoot` 覆盖。
- **步骤**：① `$Drive = $INSTDIR` 前 2 字符；② `$Rel = $APPDATA` 去盘符；③ `$UnDataRoot = "$Drive\$Rel\agentskills-runtime-pc"`；④ `FileRead`/`nsJSON` 或字符串截取解析 config.json 的 `dataRoot`，校验末段为 `agentskills-runtime-pc` 后赋 `$UnCustomDataRoot`。
- **产出物**：dataRoot 候选列表（默认 + 覆盖）。
- **验收**：装在 D 盘 → `$UnDataRoot = D:\Users\...\agentskills-runtime-pc`（对应 spec §5.2.1）。
- **风险**：config.json 解析在 NSIS 较繁琐——建议仅做"末段匹配"的轻量校验，不引入重 JSON 解析；解析失败静默忽略。

### T-03 进程强杀
- **目标**：`UninstallKillProcesses` = `nsExec::ExecToLog 'taskkill /F /IM "${PRODUCT_FILENAME}.exe" /T'` + `Sleep 1500`。
- **验收**：卸载前 PC/PG 进程被终止，无文件句柄占用（对应 spec §4.2）。

### T-04 Step1 选择页
- **目标**：`UninstallDataChoicePage` 用 nsDialogs 建两 RadioButton（保留/完全），默认选"保留"；`Leave` 回填 `$UninstallKeepData`（缺省 `keep`）；`UninstPage custom ...` 注册。
- **步骤**：仿 `DataChoicePage`（`installer.nsh:55-77`）结构；文案含空间/警告信息（design §3.1）。
- **验收**：非静默卸载可见两选项且默认"保留"；`/S` 跳过页时 `$UninstallKeepData=keep`（spec §4.1, §5.1.4）。

### T-05 customUnInstall 宏
- **目标**：`!macro customUnInstall` 按 `$UninstallKeepData` 分支执行 design §3.4 的删除清单。
- **保留模式**：`RMDir /r "$UnDataRoot\runtime"`、`runtime-backups`、`pgsql\backup`、`logs`、`temp`；保留 `pgsql\data`/`auth`/`skills`；userData 整体保留。
- **完全模式**：`RMDir /r "$UnDataRoot"`、`RMDir /r "$UnCustomDataRoot"`（若有）、`RMDir /r "$APPDATA\agentskills-runtime-pc"`。
- **验收**：对应 spec §5.1.1 规则 3/4、§6.1/§6.2。
- **风险**：`RMDir /r` 路径若含空格需引号——已有 `${PRODUCT_FILENAME}` 经验，路径变量统一加引号。

### T-06 接线
- **目标**：`UninstPage custom UninstallDataChoicePage UninstallDataChoiceLeave` 注册页；`!insertmacro customUnInstall` 注入卸载 Section（electron-builder 约定钩子名）。
- **验收**：出包后卸载流程顺序正确（先页→强杀→清理）。

### T-07 配置确认
- **目标**：核对 `electron-builder.json:92` `deleteAppDataOnUninstall` 仍为 `false`；若是则零改动，否则改回 `false`。
- **理由**：为让 NSIS 接管 userData 条件清理（design §3.5）；若误为 `true` 会无条件删 userData，破坏保留模式。

### T-08 验证（人工闸门）
- **目标**：用户本地 `pnpm build:pc` 出包 → 安装 → 启动一次（生成 dataRoot）→ 卸载，分别验证两种模式。
- **步骤**：① 保留模式：确认 `runtime` 被删、`pgsql/data`+`config.json` 留存、磁盘释放 ~1.4G；② 完全模式：确认 dataRoot+userData 全消失；③ 静默 `/S`：等同保留模式。
- **产出**：填入 `test-report.md` 验收用例结果。

---

## 需求覆盖追踪矩阵

| spec 需求 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| §1.1 两步清理职责 | T-05, T-06 | 全覆盖 | — |
| §3.1 Step1 选择页 + 默认保留 + 信息 | T-04 | 全覆盖 | — |
| §3.1 完全模式删 dataRoot+userData | T-05 | 全覆盖 | — |
| §3.1 保留模式仅删可重建产物 | T-05 | 全覆盖 | 清单见 design §3.4 |
| §3.1 静默默认保留 | T-04, T-07 | 全覆盖 | /S 跳过页 |
| §3.2 dataRoot 重算 + config 覆盖 | T-02 | 全覆盖 | — |
| §4.1 性能/静默默认 | T-04 | 全覆盖 | — |
| §4.2 强杀后清理、幂等 | T-03, T-05 | 全覆盖 | — |
| §4.3 删除范围限定本应用 | T-05, T-07 | 全覆盖 | 后缀锁定 |
| §4.4 对称复用/集中清单 | T-01, T-05 | 全覆盖 | — |
| §4.5 -WX 兼容 | T-01 | 全覆盖 | — |
| §5.1 主流程规则 1-4 | T-04, T-05, T-06 | 全覆盖 | — |
| §5.1.3 异常场景 | T-03, T-05 | 全覆盖 | — |
| §6.1/§6.2 目录边界 | T-05 | 全覆盖 | — |

---

## 验收检查清单（终验）

- [ ] 非静默卸载出现"保留/完全"两步选择，默认"保留"。
- [ ] 保留模式：删 `runtime` 等可重建产物，`pgsql/data`+`auth`+`skills`+`config.json` 留存，磁盘释放 ~90%+。
- [ ] 完全模式：`dataRoot` 与 `userData` 均消失。
- [ ] 静默 `/S`：等同保留模式，无弹窗。
- [ ] 卸载前 PC/PG 进程被强杀，无句柄占用导致删失败。
- [ ] `deleteAppDataOnUninstall` 保持 `false`。
- [ ] NSIS 编译两遍无 warning 6010/6001（出包绿）。
- [ ] spec/design/tasks 与最终实现一致（无漂移）。

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件 | 验证结果 |
|---|---|---|---|---|
| 2026-11-01 | v1.0 | 用户需求（卸载残留） | 新建 research/spec/design/tasks | 文档初稿，待闸口确认与出包验证 |
