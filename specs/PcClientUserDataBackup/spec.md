# PC 客户端用户数据备份 —— 需求规格（Spec）

> SDD 阶段：spec（第 2 步）。
> 落盘位置：`apps/agentskills-runtime/specs/PcClientUserDataBackup/spec.md`
> 上游：`research.md`；下游：`design.md`、`tasks.md`（按需）
> 关联工程：`PcClientUserDataBackup`（与 `PcClientUninstall` 互补）

---

# 1. 组件定位

## 1.1 核心职责

在 PC 客户端的**系统设置页**提供「备份用户数据」功能，将用户可二次编辑的提示词文件
（根目录 `AGENTS.md`、`prompts/`）与用户技能目录（`bin/skills`）导出为一个**自描述的 ZIP 归档**，
供用户在卸载/重装/迁移前留存其定制内容。

## 1.2 核心输入

1. 用户在系统设置页触发「备份用户数据」。
2. 用户选定的备份目标路径（文件选择器；缺省为 `~/Documents/agentskills-runtime-backup-<timestamp>.zip`）。
3. 当前 `dataRoot` 下的源内容：`AGENTS.md`、`prompts/`、`runtime/<plat>/release/bin/skills/`。

## 1.3 核心输出

1. 一个 ZIP 归档，内部含 `manifest.json`（版本/时间戳/来源/计数/校验和）+ `AGENTS.md` + `prompts/` + `skills/`。
2. 备份进度与结果（成功/失败/跳过项）回传设置页展示。
3. 失败/部分跳过时在 `manifest.json` 标注 `skipped` 项，不静默丢弃。

## 1.4 职责边界

- **负责**：只读导出用户可编辑资产；生成自描述归档；展示进度与结果。
- **不负责**：备份内嵌数据库（`pgsql/data`，由卸载保留模式负责）、备份登录态（`auth`，可重登再生）。
- **不负责**：导入/恢复（本工程仅导出；导入可列为后续独立议题）。
- **不负责**：修改或删除任何源文件（纯只读导出）。
- **不负责**：跨平台（本工程仅 Windows PC 客户端；归档为通用 ZIP，未来可在其它平台复用逻辑）。

# 2. 领域术语

**用户可编辑资产（User-Editable Assets）**
: 用户在 PC 客户端使用过程中可能二次编辑的内容——根目录提示词（`AGENTS.md`、`prompts/`）与用户技能（`bin/skills`）。区别于不可再生的业务数据库。

**备份归档（Backup Archive）**
: 本功能产出的 ZIP 文件，含 `manifest.json` + 上述资产，自描述、可迁移。

**dataRoot**
: PC 客户端私有数据根目录（跟随安装盘，由 `paths.ts` 推导），所有源均位于其下。

# 3. 角色与边界

## 3.1 核心角色

- **终端用户**：在设置页触发备份、选择目标路径、查看结果。
- **系统管理员（可选）**：通过脚本/CLI 静默触发（后续议题，本工程以 GUI 为主）。

## 3.2 外部系统

- **Electron 主进程**：实际执行文件读取/归档（renderer 不直接碰文件系统）。
- **系统文件选择器**：选取备份目标路径。
- **（解耦）卸载向导**：可在卸载第一步提供"先备份"入口，但备份动作本身与卸载解耦。

# 4. DFX 约束

## 4.1 性能
- 备份（含 L3 进程插件 exe，单技能约 50MB、整体可能数百 MB）须在 **120 秒**内完成；超时应提示而非卡死。
- 开始前须向用户展示**预估体积**与"是否包含技能可执行文件"。

## 4.2 可靠性
- 任一源目录不存在（如未自定义 `AGENTS.md`）时，该项**跳过并标注 `skipped`**，不中断整体备份。
- 目标路径写入失败（磁盘满/无权限）须明确报错并保留已写入的部分（或清理半成品），不残留损坏归档。
- 备份为只读：**绝不**修改/删除 `dataRoot` 下任何源文件。

## 4.3 安全性
- 读取范围**严格限定在 `dataRoot` 内**；禁止越权读取其他用户目录或系统目录。
- 归档内容仅含用户资产，不含 `config.json`（避免带入绝对路径、反而妨碍迁移）与凭据。
- 目标路径须为用户显式选择或确认，禁止静默写入系统目录。

## 4.4 可维护性
- 源清单（路径集合）集中定义，新增可备份项（如未来加 `auth`）只需扩展清单。
- `manifest.json` 须含 `toolVersion` 与 `schemaVersion`，便于未来导入工具识别。

## 4.5 兼容性
- 归档为通用 ZIP + JSON manifest，与平台无关，便于跨版本/跨机器迁移。
- 兼容 `dataRoot/skills` 为空或不存在的情况（以 `bin/skills` 为权威；`dataRoot/skills` 为空时跳过）。

# 5. 核心能力

## 5.1 备份主流程

### 5.1.1 业务规则

1. **触发与范围展示**：用户在设置页点「备份用户数据」→ 展示将备份的三类资产与预估体积。
   a. 验收条件：打开备份面板 → 看到 `AGENTS.md` / `prompts/` / `skills` 三项及其预估大小。
2. **目标路径选择**：默认 `~/Documents/agentskills-runtime-backup-<timestamp>.zip`，用户可用文件选择器改。
   a. 验收条件：用户可修改目标路径；未选则使用默认。
3. **执行导出**：主进程读取三类资产 → 写入临时 staging → 打包 ZIP（含 `manifest.json`）→ 移动到目标路径。
   a. 验收条件：目标 ZIP 存在且含 `manifest.json` + `AGENTS.md`（若有）+ `prompts/`（若有）+ `skills/`。
4. **结果呈现**：展示成功/失败/跳过项与归档大小；失败项定位到具体路径。
   a. 验收条件：备份完成后设置页显示"已备份 N 项、跳过 M 项（原因）"。

### 5.1.2 交互流程

```
用户 → 设置页: 点「备份用户数据」
设置页 → 主进程: userdata:backup { targetPath }
主进程 → 设置页: userdata:backup-progress { phase, current, total }
主进程: 读 dataRoot/AGENTS.md, prompts/, bin/skills
主进程: 写 staging + manifest.json → 打包 ZIP → 移到 targetPath
主进程 → 设置页: userdata:backup-result { ok, skipped[], size, path }
```

### 5.1.3 异常场景

1. **源不存在**
   a. 触发：`AGENTS.md` 或 `prompts/` 未自定义。
   b. 行为：跳过该项，manifest 标 `skipped`，不报错。
2. **目标路径无写入权限 / 磁盘满**
   a. 行为：报错并清理半成品归档，提示用户换路径。
3. **bin/skills 超大导致超时**
   a. 行为：进度停滞超时 → 提示"技能目录过大，建议仅备份提示词"，不强制完成。

# 6. 数据约束

## 6.1 备份源清单（逻辑约束）

| 源（相对 dataRoot） | 必含 | 说明 |
|---|---|---|
| `AGENTS.md` | 否（可缺省，缺则跳过） | 根目录主 agent 定义 |
| `prompts/` | 否（可缺省） | 全局提示词模板 |
| `runtime/<plat>/release/bin/skills/` | 否（可缺省） | 发布态用户技能（含 L3 进程插件 exe/脚本）；`dataRoot/skills` 为空时以本目录为准 |

## 6.2 归档内部结构约束

1. `manifest.json` 必须含：`toolVersion`、`schemaVersion`、`createdAt`、`sourceDataRoot`（可脱敏为相对/占位）、各源 `fileCount` 与 `skipped` 列表、整体 `checksum`。
2. 技能目录保持子目录结构（不扁平化），确保 `bin/skills/<name>/` 原样入库。
3. **禁止**将 `config.json`、`auth/`、`pgsql/` 纳入归档。
