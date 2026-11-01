# PC 客户端卸载测试验收报告（Test Report）

> SDD 阶段：test（第 6 步，末步）。
> 落盘位置：`apps/agentskills-runtime/specs/PcClientUninstall/test-report.md`
> 依据：`spec.md`（验收/DFX）、`design.md`（方案）、`tasks.md`（任务与产出）。
> 关联工程：`PcClientUninstall`
> 状态：本文档为**验收用例与一致性核查基线**；实际执行依赖用户本地 `pnpm build:pc` 出包（T-08），执行结果回填此表。

---

## 文档信息
- 被测对象：PC 客户端卸载器（NSIS `installer.nsh` 卸载分支）
- 版本：1.0.0（对应 design v1.0.0）
- 测试轮次：v1（首轮，待出包执行）
- 测试日期：待填（出包后）
- 测试人：人工（用户）+ 主 agent 核对

---

## 一、测试概述

验证 Windows 卸载程序在「保留用户数据」与「完全卸载」两种模式下，是否正确清理 `dataRoot`/`userData`，真正释放磁盘空间且不误删真实用户数据。范围：卸载期 NSIS 逻辑（非安装器、非运行时业务代码）。

---

## 二、测试依据

- `spec.md` §3.1（两步选择页）、§5.1（主流程规则）、§6.1/§6.2（目录边界）、§4.x（DFX）。
- `design.md` §3.1–§3.7（页/宏/异常/静默）。
- `tasks.md` T-01~T-08 产出（`installer.nsh` 卸载分支、`electron-builder.json` 确认）。

---

## 三、测试环境与工具

- 环境：Windows 10/11 64 位；安装盘与系统盘可异盘（复现 D 盘 dataRoot 场景）。
- 工具：`pnpm build:pc` 出包、控制面板/开始菜单卸载入口、`/S` 静默参数、`du -sh` 体积核对。
- 前置：先安装并启动一次 PC 客户端，确保 `dataRoot`（含 `runtime`/`pgsql/data`）与 `userData` 已生成。

---

## 四、测试执行与结果（待回填）

表格：**用例ID | 所属需求 | 测试项 | 前置 | 步骤 | 预期 | 实际 | 结果**

| 用例ID | 所属需求 | 测试项 | 前置 | 步骤 | 预期 | 实际 | 结果 |
|---|---|---|---|---|---|---|---|
| TC-01 | §3.1, §5.1.1 | 选择页出现+默认保留 | 已安装 | 启动卸载（非静默） | 出现"保留/完全"两选项，默认"保留" | | |
| TC-02 | §5.1.1 规则3(保留) | 保留模式删可重建产物、留数据库 | 已安装并运行过 | 选"保留"→完成 | `runtime`/`runtime-backups`/`pgsql/backup`/`logs`/`temp` 被删；`pgsql/data`/`auth`/`skills`/`config.json` 留存 | | |
| TC-03 | §4.1, §5.1.4 | 保留模式释放空间 | 同 TC-02 | 卸载前后 `du -sh dataRoot` | 释放约 90%+（本例 1.5G→约 80M） | | |
| TC-04 | §5.1.1 规则3(完全) | 完全模式删全部 | 已安装 | 选"完全卸载"→完成 | `dataRoot` 与 `userData` 均不存在 | | |
| TC-05 | §3.1, §4.1 | 静默卸载默认保留 | 已安装 | `Uninstall.exe /S` | 无弹窗；等同保留模式（runtime 删、数据库留） | | |
| TC-06 | §5.2.1, §4.3 | config.json 自定义 dataRoot | 曾自定义 dataRoot | 卸载 | 按自定义路径清理而非默认推算 | | |
| TC-07 | §4.2, §5.1.3 | 进程强杀前置 | PC 运行中 | 启动卸载 | 卸载前 PC/PG 进程被终止，无句柄占用导致删失败 | | |
| TC-08 | §5.1.3, §4.2 | dataRoot 不存在幂等 | 从未运行过 | 卸载 | 不报错，正常完成 | | |
| TC-09 | §4.5, T-01 | NSIS 编译两遍无警告 | 改动后 | `pnpm build:pc` | 无 warning 6010/6001（-WX） | | |
| TC-10 | §4.3 | 删除作用域不越界 | 任意 | 卸载 | 仅删含 `agentskills-runtime-pc` 后缀的本应用目录，不碰其他 | | |

统计：总数 10 / 通过 __ / 失败 __ / 阻塞 __、通过率 __%。

---

## 五、与 SDD 文档的一致性核查

- **实现 vs spec**：功能需求（两步选择、保留/删除目录边界、静默默认、dataRoot 重算）逐条核对（满足/偏离/缺失）。
- **实现 vs design**：是否按 `customUnInstall` 清单落地、是否对称复用安装分支公式、是否维持 `deleteAppDataOnUninstall:false`。
- **文档 vs 代码**：spec/design/tasks 是否仍与实现一致（漂移检测）。
  - 当前（未出包）：文档自洽，待代码落地后回填偏离项。

---

## 六、完成度评估

- 功能需求完成度：文档 100%；代码实现待 T-08 出包后评估。
- DFX：性能（§4.1）、可靠性（§4.2 强杀/幂等）、安全性（§4.3 作用域）、可维护（§4.4 对称）、兼容（§4.5）均已设计覆盖，待执行验证。

---

## 七、缺陷清单（分级）

| 缺陷ID | 级别(P0/P1/P2) | 关联需求 | 现象 | 根因 | 建议修复 | 状态 |
|---|---|---|---|---|---|---|
| （待出包执行后填写） | | | | | | |

---

## 八、完善意见

- 架构：是否需要在 PC 应用内提供"卸载"入口（委托系统卸载器）以便用户发现——建议作为后续增强，不在本工程 scope。
- 可维护性：保留/删除目录清单当前硬编码于 `customUnInstall`，后续若目录结构演进，建议提取为 NSIS `!define` 常量集中管理。
- 安全：完全卸载删库不可逆，可考虑在"完全卸载"页增加二次确认 CheckBox（默认不勾选）以强化防误删——若用户接受可补入 spec。

---

## 九、验收结论

- 当前状态：**待出包执行（T-08）**。
- 文档侧：research→spec→design→tasks→test 五步文档齐备、相互一致，可作为实现与验收基线。
- 验收通过判据：TC-01~TC-10 全部 P/F 回填且 P0=0，NSIS 出包绿。

---

## 十、附录

- 相关文件：`apps/pc-client/build/installer.nsh`、`apps/pc-client/electron-builder.json`、`apps/pc-client/electron/utils/paths.ts`。
- 残流质检基线（2026-11-01 实测）：`D:\...\agentskills-runtime-pc` = 1.5G（runtime 1.5G / pgsql 77M / logs 3.8M）；`C:\...\agentskills-runtime-pc` 残留。修复目标：保留模式降至约 80M 且数据库完好，完全模式降至 0。
