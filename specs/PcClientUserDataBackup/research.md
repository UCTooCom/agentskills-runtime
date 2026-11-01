# PC 客户端用户数据备份 —— 研究（Research）

> SDD 阶段：research（第 1 步）。
> 落盘位置：`apps/agentskills-runtime/specs/PcClientUserDataBackup/research.md`
> 上游关联：`specs/PcClientUninstall`（卸载保留模式已简化为仅保留内嵌数据库）
> 下游：`specs/PcClientUserDataBackup/spec.md`、`design.md`

---

## 1. 问题背景

在 `PcClientUninstall` 工程中将"保留用户数据"模式**简化**为：卸载时仅保留内嵌数据库数据文件
（`pgsql/data`）与 `config.json` 指针，**删除其余一切**——包括登录态、日志、以及**用户可二次编辑的
提示词文件（如根目录 `AGENTS.md`）与用户技能目录（`bin/skills`）**。

这一简化带来一个缺口：**用户若在 PC 客户端里自定义过 `AGENTS.md`、全局提示词（`prompts/`）、或
往 `bin/skills` 里增删改过技能，选择"保留用户数据"卸载后将丢失这些可编辑内容**；"完全卸载"更是
连数据库一起清空。过去这些内容隐含地随 `skills`/`AGENTS.md` 被保留，简化后不再保留。

### 残留目录实证（2026-11-01）

- `D:\users\patrick\AppData\Roaming\agentskills-runtime-pc\` 顶层除 `runtime/`、`pgsql/`、`logs/` 外，
  最新版本还会多出 **根目录 `AGENTS.md`** 等用户可能二次编辑的智能体提示词文件。
- 真正的用户技能目录是 `runtime\win-x64\release\bin\skills`（含 L3 进程插件的
  `target/release/bin/skill_<name>.exe` 与 `scripts/`），而 `dataRoot/skills` 实测常为空、非权威路径。
- 这些提示词/技能**可编辑、可定制、对用户有留存价值**，但与"数据库"性质不同：它们是**资产**而非
  "不可再生的业务数据"，适合在卸载前**主动导出备份**，而非在卸载保留逻辑里无条件保留。

## 2. 业界最佳实践对标

| 产品 | 做法 | 启示 |
|---|---|---|
| VS Code / JetBrains | 设置页提供「导出/导入设置」「导出扩展」 | 用户可编辑资产应在销毁前提供显式导出入口 |
| npm / pip / git | `package.json` / `requirements.txt` / 仓库即备份单元 | 用户资产以"目录 + 元数据清单"整体归档 |
| Docker / Kubernetes | `export` / `kubectl get -o yaml` 产出可迁移快照 | 导出物应自描述（含版本/时间/来源） |

结论：**可编辑内容不应靠"卸载保留"兜底，而应由用户在销毁前主动备份**；卸载保留逻辑只负责
"不可再生的数据库"，从而把保留模式的实现复杂度降到最低（呼应 `PcClientUninstall` 的简化决策）。

## 3. 备份范围（本工程界定）

| 类别 | 路径（相对 dataRoot） | 是否纳入 | 理由 |
|---|---|---|---|
| 主 agent 定义 | `AGENTS.md`（根目录） | ✅ | 用户可二次编辑的核心提示词 |
| 全局提示词模板 | `prompts/`（根目录，`PROMPTS_DIR` 默认 `./prompts`） | ✅ | 用户定制提示词，被 compactor 等引用 |
| 用户技能 | `runtime/<plat>/release/bin/skills/`（发布态真实目录） | ✅ | 用户增删改的技能资产（含 L3 进程插件 exe/脚本） |
| 内嵌数据库 | `pgsql/data` | ❌（由卸载保留模式负责） | 卸载保留模式已专门保留；DB 备份属独立议题 |
| 登录态 | `auth` | ❌ | 可重新登录再生 |
| 设置指针 | `config.json` | ❌ | 可重新生成；且导出它会把绝对路径带入备份，反而不利迁移 |
| 运行时/日志 | `runtime`、`logs`、`pgsql/backup`、`temp` | ❌ | 可重建 / 无留存价值 |

> 边界：**本功能只备份"用户可二次编辑的提示词与技能"**，不碰数据库与登录态。这与
> `PcClientUninstall` 的"保留模式只保数据库"形成互补——用户想留存提示词/技能，就在卸载前用本功能导出。

## 4. 导出形态与落点

- **形态**：ZIP 归档（跨平台、易迁移、便于二次导入）。
- **内部布局**（自描述，便于将来导入）：
  ```
  agentskills-runtime-backup-<YYYYMMDD-HHMMSS>.zip
  ├── manifest.json        # 版本 / 时间戳 / 来源 dataRoot / 各目录文件计数 / 校验和
  ├── AGENTS.md            # 根目录主 agent 定义（若存在）
  ├── prompts/             # 全局提示词（若存在）
  └── skills/              # 用户技能（来自 bin/skills，保持子目录结构）
  ```
- **默认目标路径**：用户在系统设置页用系统文件选择器指定；缺省建议
  `~/Documents/agentskills-runtime-backup-<timestamp>.zip`。
- **幂等/覆盖**：同名文件直接覆盖；已存在目标目录则提示替换或自动加序号。

## 5. 关键设计约束（预览，详见 design.md）

- 备份范围**严格限定在 dataRoot 内**，禁止越权读取其他目录（安全红线）。
- `bin/skills` 可能较大（每个 L3 进程插件约 50MB），备份前须向用户展示**预估体积**与"是否包含技能 exe"。
- 源目录不存在（如未自定义 `AGENTS.md`）时该项跳过并在 `manifest.json` 标注 `skipped`，不报错。
- 备份为**只读导出**，不修改/删除源；与卸载流程解耦（卸载前用户自行触发，或卸载页提供"先备份"入口）。

## 6. 复用与依赖

- **dataRoot 权威路径**：复用 `electron/utils/paths.ts` 的 `getDataRoot()`（与安装/卸载推算公式一致）。
- **ZIP 能力**：复用 Electron 生态的归档库（如 `archiver` / `jszip`），或调用系统 `tar`；PC 壳已有
  相似打包经验（runtime 包以 `tar.gz` 分发），可参考。
- **IPC 通道**：沿用既有 `modules/*` 的 IPC 范式（renderer → main → 进度回传）。

## 7. 结论

本功能填补"卸载保留模式简化"后出现的用户可编辑资产丢失缺口，符合业界"销毁前显式导出"最佳实践，
且将卸载保留逻辑与用户资产备份两条职责彻底解耦，互不拖累。建议在 PC 客户端**系统设置页**新增
「备份用户数据」区块，并在卸载向导第一步提供"先备份再卸载"的可选入口。
