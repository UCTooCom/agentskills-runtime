# PC 客户端用户数据备份 —— 技术设计（Design）

> SDD 阶段：design（第 3 步）。
> 落盘位置：`apps/agentskills-runtime/specs/PcClientUserDataBackup/design.md`
> 上游：`research.md`、`spec.md`；下游：`tasks.md`（按需）

---

## 1. 设计概述

### 1.1 设计目标

在 PC 客户端**系统设置页**新增「备份用户数据」能力：把用户可二次编辑的提示词（`AGENTS.md`、`prompts/`）
与用户技能（`bin/skills`）只读导出为自描述 ZIP 归档，使卸载保留模式可安心简化为"只保数据库"
（见 `PcClientUninstall`），用户资产由本功能在销毁前主动留存。

### 1.2 设计原则

- **只读导出**：备份绝不修改/删除 `dataRoot` 下任何源文件。
- **范围锁定**：源严格限定在 `dataRoot` 内，禁止越权读取。
- **自描述归档**：ZIP 内含 `manifest.json`，便于未来导入与跨机器迁移。
- **解耦卸载**：本功能独立可触发；卸载向导可"可选"调用，但备份逻辑与卸载清理互不直接依赖。

### 1.3 技术选型

| 组件 | 选型 | 说明 |
|---|---|---|
| UI | PC 壳设置页新增「备份用户数据」区块（Vue/HTML，沿用既有设置页框架） | renderer |
| IPC | `userdata:backup` / `userdata:backup-progress` / `userdata:backup-result` | renderer ↔ main |
| 归档 | `archiver`（Node）或系统 `tar -czf` | 主进程执行，产出 `.zip` |
| 源路径 | `electron/utils/paths.ts` `getDataRoot()` | 与安装/卸载公式一致 |
| 技能源 | `dataRoot/runtime/<plat>/release/bin/skills/` | 发布态真实技能目录 |

---

## 2. 系统架构

```
设置页 (renderer)
  ├─ 展示备份范围 + 预估体积
  ├─ 文件选择器选目标路径
  └─ IPC userdata:backup ──▶ main (modules/user-data-backup.ts)
                                │
                                ├─ 解析 dataRoot（paths.ts）
                                ├─ 探测三类源（存在性 + 体积）
                                ├─ 写 staging/（AGENTS.md / prompts/ / skills/）
                                ├─ 生成 manifest.json
                                ├─ 打包 ZIP → 移动到 targetPath
                                └─ IPC userdata:backup-result
```

---

## 3. 详细设计

### 3.1 源探测与预估（`probeBackupSources`）

主进程 `user-data-backup.ts` 在备份前先探测：

```ts
interface BackupSource {
  key: 'agentsMd' | 'prompts' | 'skills'
  relPath: string              // 相对 dataRoot
  exists: boolean
  sizeBytes: number            // 递归求和
}
// 探测逻辑：
//   agentsMd  → dataRoot/AGENTS.md
//   prompts   → dataRoot/prompts/
//   skills    → dataRoot/runtime/<plat>/release/bin/skills/
//               若不存在，回退探测 dataRoot/skills（常为空，兜底）
```

- 预估体积 = 三项 `sizeBytes` 之和，设置页展示（MB/GB）。
- `skills` 含 L3 进程插件 exe（单技能约 50MB），需在 UI 提示"技能目录可能较大"。

### 3.2 归档结构（`buildArchive`）

```
<targetPath>.zip
├── manifest.json
├── AGENTS.md            (仅当存在)
├── prompts/...          (仅当存在)
└── skills/<name>/...    (保持 bin/skills 子目录结构)
```

`manifest.json` 形态：

```json
{
  "toolVersion": "0.0.24",
  "schemaVersion": 1,
  "createdAt": "2026-11-01T19:30:00+08:00",
  "sourceDataRoot": "<dataRoot>",
  "sources": [
    { "key": "agentsMd", "relPath": "AGENTS.md", "fileCount": 1, "sizeBytes": 12345, "skipped": false },
    { "key": "prompts",  "relPath": "prompts/",  "fileCount": 12, "sizeBytes": 56000, "skipped": false },
    { "key": "skills",   "relPath": "runtime/win-x64/release/bin/skills/", "fileCount": 240, "sizeBytes": 380000000, "skipped": false }
  ],
  "checksum": "<整体 sha256>",
  "note": "不含数据库/登录态/设置指针；仅用户可编辑资产"
}
```

### 3.3 执行流程（`runBackup(targetPath)`）

```
1. probeBackupSources → 拼 sources（exists=false 的项直接标 skipped，不进归档）
2. 创建 staging 临时目录（os.tmpdir 下）
3. 逐项拷贝（仅 exists 项）：AGENTS.md → staging/AGENTS.md；prompts/ → staging/prompts/；skills/ → staging/skills/
4. 写 staging/manifest.json
5. 打包 staging → <targetPath>.zip（archiver / tar）
6. 移动/替换目标路径（已存在则提示覆盖或加序号）
7. 清理 staging
8. 回传 userdata:backup-result { ok, skipped[], size, path }
```

> 进度：步骤 3/5 可发 `userdata:backup-progress`（phase + current/total），供设置页展示进度条。

### 3.4 与卸载向导的可选衔接

`PcClientUninstall` 第一步选择页可加一行提示：「如要保留自定义提示词/技能，请先在设置页『备份用户数据』」。
备份动作本身不依赖卸载；卸载清理逻辑不感知本功能（保持解耦）。

### 3.5 安全边界

- 所有源路径 = `path.join(dataRoot, relPath)`，禁止任何 `..` 越权拼接。
- 目标路径须为用户选择；若程序自动给默认路径，须落在用户文档/桌面等可写区，且文件名带时间戳避免覆盖。
- 归档**绝不**包含 `config.json` / `auth/` / `pgsql/`，从源清单层面排除。

---

## 4. 数据设计

仅新增一个临时 staging 目录（进程退出即清理）与一个 `manifest.json`（落入归档，非系统文件）。
不引入新表、不改数据库。

---

## 5. 接口设计

| 通道 | 方向 | 说明 |
|---|---|---|
| `userdata:backup` | renderer → main | 入参 `{ targetPath? }`；缺省用默认路径 |
| `userdata:backup-progress` | main → renderer | `{ phase, current, total }` |
| `userdata:backup-result` | main → renderer | `{ ok, skipped: BackupSource[], sizeBytes, path }` |

---

## 6. 安全设计

- 源范围白名单：`['AGENTS.md','prompts/','runtime/<plat>/release/bin/skills/']`，硬编码相对 dataRoot，禁用任意路径。
- 只读：全程 `fs.copyFile` / `read`，无 `unlink`/`write` 指向源。
- 归档排除：显式跳过 `config.json`/`auth`/`pgsql`/`runtime`（runtime 下的其它子目录如 `magic/`、`*.dll` 也不在源清单内，不会进归档）。

---

## 7. 性能设计

- 大体积主要来自 `bin/skills`（L3 exe）。`probeBackupSources` 先算体积并提示；打包用流式（archiver）避免整库入内存。
- 超时上限 120s（spec §4.1）；超时可中断并提示"技能过大"。

---

## 8. 部署与回退

- 改动文件：`apps/pc-client/electron/modules/user-data-backup.ts`（新增）、设置页 Vue/HTML（新增区块）、`electron/preload`/IPC 注册。
- 出包：`pnpm build:pc`（按红线由用户本地执行；AI 不跑 NSIS/makensis）。
- 回退：纯新增功能，不影响既有安装/卸载流程；禁用该区块即回退。

---

## 9. 参考文档

- `specs/PcClientUninstall/`（卸载保留模式已简化为只保数据库）
- `specs/plugin-system-enhancement` / `.codeartsdoer/specs/plugin-system`（技能-插件融合；`bin/skills` 为权威技能目录）
- `electron/utils/paths.ts`（dataRoot 权威定义）
