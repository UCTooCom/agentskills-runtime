# UCToo AgentSkills Runtime Installer（`ucInstaller`）使用文档

> 工程包名：`uc_installer`（产物亦可称 `ucInstaller.exe`）。
> 本文件是 installer 的完整使用文档。SDD 工程目录见仓库 `specs/RuntimeNativeInstaller/`
> （含 `design.md` / `spec.md` / `tasks.md` / `acceptance/`）。

---

## 1. 概述

`ucInstaller` 是 **agentskills-runtime** 的原生安装器，基于仓颉（Cangjie）实现。
它以 **CLI 为基础、HTTP 引导服务封装同一套实现**，覆盖一条龙能力：

| 能力 | 子命令 |
|------|--------|
| 环境自检 | `check-environment` |
| 安装 runtime | `install` |
| 安装/校验/初始化开发套件 | `devkit install` / `devkit verify` / `devkit init` |
| **导出数据库种子（基线库）** | `db export` |
| **应用 / 校验种子数据** | `seed apply` / `seed verify` |
| 回滚 / 卸载 | `rollback` / `uninstall` |
| 运维管控服务 | `serve --manage` |
| 无参启动 | HTTP 引导服务（默认 `:3000`） |

**本文档重点**是日常最常使用的两条数据流水线：`db export`（生成基线库 `sql/uctooDB.sql`）与 `seed apply` / `seed verify`（把种子落库并校验）。其余子命令仅给出调用口径。

---

## 2. 仓库位置与构建

```
agentskills-runtime/
├── installer/                # 本工程（uc_installer）
│   ├── cjpm.toml            # name=uc_installer, output-type=executable, cjc-version=1.1.3
│   ├── src/                 # 源码
│   └── target/release/bin/main.exe   # 构建产物
├── sql/
│   ├── uctooDB.sql          # 初始库基线（由 db export 生成/更新）
│   ├── uctooDB.sql.tmp      # db export 过程临时文件（勿手动改）
│   └── seed/
│       ├── export-policy.json     # 导出策略（门禁/脱敏/身份列）
│       ├── sanitize-policy.json   # 脱敏策略
│       ├── seed-manifest.json     # 导出元数据（每表原因/统计）
│       └── seed-manifest.json.tmp # 过程临时文件
└── .env                     # 含 DATABASE_URL（db export / seed apply 连接源）
```

**依赖**：installer 全部依赖 `../libs/*`（http_lib、kaca_json、jinguissl 等，均为 `static` 输出型），
不依赖 runtime 宿主编译图，因此**独立编译、互不干扰**。

**构建**：

```bash
cd agentskills-runtime/installer
cjpm build
# 产物：installer/target/release/bin/main.exe
```

**版本号**取自仓库根的 `release/VERSION`（`ucInstaller.exe --version`）。

---

## 3. 通用约定（所有子命令通用）

### 3.1 全局 `--` 选项必须出现在子命令之前

解析器规则（`args.cj`）：遇到**第一个非 `--` 参数**即进入子命令模式，之后的 token 一律视为子命令/参数。
因此全局开关与取值开关都要**前置**：

```bash
# ✅ 正确：全局选项在前
./target/release/bin/main.exe --source-dir "/path/to/agentskills-runtime" db export

# ❌ 错误：子命令在后、全局选项插在中间会被当成子命令参数而失效
./target/release/bin/main.exe db export --source-dir "/path/to/agentskills-runtime"
```

### 3.2 关键全局选项

| 选项 | 取值 | 说明 |
|------|------|------|
| `--source-dir <dir>` | 路径 | **源码目录，必须是 `agentskills-runtime` 仓库根**（含 `.env` 与 `sql/seed/`）。缺省为当前目录 `.`。 |
| `--db <name>` | 库名 | 目标库名，默认 `uctoo`。 |
| `--user <u>` / `--password <p>` | 字符串 | 直连凭据；**优先于** `.env` 的 `DATABASE_URL`（仅覆盖凭据，不覆盖库名）。 |
| `--json` | 开关 | stdout 仅输出机器可读 JSON（人读报告关闭）。 |
| `--progress=ndjson` | 开关 | 逐事件流式 NDJSON（与 `--json` 互斥）。 |
| `--truthful` | 开关 | 不可达即非成功，禁止静默降级。 |
| `--force` | 开关 | 破坏性动作确认（如 `uninstall`）。 |
| `--offline` / `--rollback` / `--with-devkit` / `--devkit-only` / `--auto-exit` / `--system-env` / `--manage` / `--no-serve` | 开关 | 安装/运维相关，详见 `ucInstaller.exe --help`。 |
| `--port <n>` / `--sdk-path <dir>` | 取值 | HTTP 服务端口 / 开发套件路径。 |
| `--version` / `--help` / `-h` | 开关 | 元操作。 |

### 3.3 连接来源

`db export` 与 `seed apply/verify` 共用同一套连接构建逻辑（`db_export.cj` 的 `buildConn`）：

1. 优先读 `--source-dir` 下 `.env` 的 `DATABASE_URL`；
2. 否则用 `--user` / `--password` 直连 `127.0.0.1:5432/<--db>`；
3. 二者皆无 → 报 `无法构建数据库连接`，不执行。

### 3.4 退出码

| 退出码 | 常量 | 含义 |
|--------|------|------|
| `0` | `EXIT_OK` | 成功（或 `serve` 正常退出）。 |
| `1` | `EXIT_GENERIC` | 业务失败：门禁未过、重放失败、seed 校验失败等。 |
| `2` | `EXIT_ARGS` | 参数错误：未知命令、缺值、选项冲突。 |
| `6` | `EXIT_MANUAL` | 已识别但本阶段未接入实现，需人工/待实现（不冒充成功）。 |

> 脚本判断成功只看退出码 `0`；`--json` 模式下 stdout 为单行 JSON，`report.ok` 为最终成败。

---

## 4. 子命令详解

### 4.1 `db export` —— 导出数据库种子（基线库）

**用途**：从源库导出「整库结构 + 种子数据（含身份匿名化与脱敏）」到 `sql/uctooDB.sql`，
并生成 `sql/seed/seed-manifest.json`。这是 **`sql/uctooDB.sql` 基线库的唯一生成途径**（注意：
`loaddbinfo` 只把结构读进 `db_info` 表，并不产出 `uctooDB.sql`）。

**调用**：

```bash
./target/release/bin/main.exe \
  --source-dir "/path/to/agentskills-runtime" \
  db export
```

**流水线（E0 ~ E7）**：

| 阶段 | 名称 | 说明 |
|------|------|------|
| E0 | 读策略 | 加载并校验 `export-policy.json` + `sanitize-policy.json`。 |
| E1 | 连源库 | 连接 `--db`（默认 `uctoo`）。 |
| E2–E4.5 | 分层导出 | 结构 + 数据 + 身份匿名化 + 脱敏，**先落临时文件** `sql/uctooDB.sql.tmp`。 |
| E5 | 六条门禁 | `guards.cj` 逐单元格扫描临时 SQL，不过则不提升（绝不覆盖既有 `uctooDB.sql`）。门禁包含：体积上限、单表行数上限、禁止破坏性语句（`DROP TABLE`/`TRUNCATE`/`DELETE`）、**敏感形态**（机密前缀 `^sk-`/`^ghp_`/`^fc-` 及子串 `eyJ`/`$2a$`/`BEGIN PRIVATE KEY`/`postgres://`/`jdbc:`）、脱敏生效、同步残留、身份列校验。 |
| E6 | 落盘 | 生成 `sql/seed/seed-manifest.json`（每表导出原因/孤儿/脱敏统计，先写 `.tmp`）。 |
| E7 | 临时库重放验真 | 在可写 postgres 维护库 `CREATE DATABASE` 后重放导出 SQL，断言：**表总数一致 / 悬空身份引用 == 0 / 超管菜单非空**。 |

**产物**：

- `sql/uctooDB.sql`：完整 `CREATE TABLE` + `COMMENT` + `CREATE INDEX` + `INSERT` 种子。
- `sql/seed/seed-manifest.json`：导出元数据（策略摘要、门禁结论、每表统计）。

**占位符（重要）**：导出中的身份/时间戳/机密/环境变量以占位符呈现，例如
`{{principal:super_admin}}`、`{{ts:epoch}}`、`{{secret:…}}`、`{{env:…}}`。
这些行**无法作为原生 SQL 字面量落库**，因此 E7 原生重放会跳过它们（计数降级、非致命），
**完整身份/菜单校验交由 `seed apply` 的 P4（占位符解析后执行）**。导出产物里的占位符是预期状态，不是缺陷。

**E7 降级**：若环境无法提供可写 postgres 维护库（无 `CREATE DATABASE` 权限），
E7 以 `DEGRADED` 明确标记、不静默通过，也不阻断 E0–E6 的本地验证；产物仍会提升。

**红线**：E5 或 E7 不过 → 临时产物**不提升**为正式，绝不覆盖既有 `uctooDB.sql`。

---

### 4.2 `seed apply` / `seed verify` —— 应用与校验种子

**用途**：把 `sql/uctooDB.sql` 中的种子数据**解析占位符后落库**，并做完整性校验。

**调用**：

```bash
./target/release/bin/main.exe --source-dir "/path/to/agentskills-runtime" seed apply
./target/release/bin/main.exe --source-dir "/path/to/agentskills-runtime" seed verify
```

**`seed apply` 五步（P0 ~ P4）**：

| 阶段 | 名称 | 说明 |
|------|------|------|
| P0 | 身份解析 | 解析主体二元组：超管（固定 UUID `2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d`）、主 agent 账号、主 agent 实体，并补 RBAC。主 agent 随机初始口令**仅在本次报告展示一次、不落任何文件**。 |
| P1 | 结构与非身份数据导入 | 执行 DDL 与不含身份占位符的 INSERT。 |
| P2 | 身份重绑定 | 字符串级重绑定（零 `UPDATE`）。 |
| P3 | 孤儿与脱敏占位符处置 | 孤儿按策略处理；`{{secret:*}}` / `{{env:*}}` **原样保留、绝不解析**（防机密泄漏）。 |
| P4 | 校验 | 表总数一致 / 悬空身份引用 == 0 / 超管菜单树非空。 |

**导入幂等**：`seed apply` 可重跑；已存在数据的表会被识别为「复用」不再重复写入，失败会整体回滚、库中不残留本轮数据。

**`seed verify` 只跑 P4 三条判据，不改库**——适合部署后巡检。

---

### 4.3 其余子命令（调用口径）

| 子命令 | 说明 |
|--------|------|
| `check-environment` | 环境自检（与 HTTP 同实现）。 |
| `install` | 驱动核心编排 S0~S8 安装 runtime。 |
| `devkit install` / `devkit verify` / `devkit init` | 安装 / 校验 / 初始化开发套件（与 HTTP 同实现）。 |
| `rollback` | 把 `previous/` 下最新备份换回 `release/`。 |
| `uninstall` | 破坏性动作，**必须 `--force` 才真正执行**（否则只报告不执行）。 |
| `serve --manage` | 运维管控模式（只挂运维端点，不推进 S0~S8）。 |
| （无参） | 启动 HTTP 安装引导服务（默认 `:3000`）。 |

---

## 5. 种子策略文件（`sql/seed/`）

| 文件 | 作用 | 关键点 |
|------|------|--------|
| `export-policy.json` | 导出策略 | `defaultTier`（如 `structure-only`）、`bootstrapTables`、`samples`、`guards`（门禁阈值与 `secretScan` 机密形态列表）、`principalColumns` / `agentColumns`（身份列）。 |
| `sanitize-policy.json` | 脱敏策略 | 列级脱敏规则（如 `R2_env` 用 `^(ghp_\|sk-\|fc-)` 锚定前缀）。 |
| `seed-manifest.json` | 导出元数据 | 由 `db export`(E6) 生成，供 `seed apply`(P4)/`seed verify` 比对表总数与统计。 |

> **机密形态语义**：`secretScan` 中带 `^` 前缀的模式（如 `^sk-`、`^ghp_`、`^fc-`）表示「值必须以该形态**开头**」，
> 未带 `^` 的子串（如 `eyJ`、`postgres://`）表示「值中任意位置包含」。该区分曾因裸 `contains` 误伤
> UUID 十六进制段（`04fc-`）与路径段（`task-status`）而修正——新增机密模式时务必带 `^` 锚定前缀形态。

---

## 6. 基线库重生成工作流

当数据库结构发生变更、需要刷新 `sql/uctooDB.sql` 基线时：

```
1. 改库（在源库执行 DDL / 调整种子数据）
2. （如新增表）先 loaddbinfo 刷新 db_info（否则 crudgen/crudweb/plugingen 读不到新表）
3. 跑 db export 重新生成基线：
     ucInstaller.exe --source-dir <仓库根> db export
   → 过了 E5/E7 门禁后，sql/uctooDB.sql 与 sql/seed/seed-manifest.json 被提升
4. 提交新的 uctooDB.sql（它是表结构与数据类型的唯一基线）
```

**与增量 SQL 的关系**：日常「新增/变更表结构」仍走 `sql/incremental/<YYYYMMDD>_<模块>_<动作>.sql`
（幂等、禁 DROP、可直接 psql 跑）；`db export` 是**整库重新基线化**的手段，二者互补——
增量脚本负责演进，export 负责把演进后的整库固化成新基线。

---

## 7. 并发编译注意事项

installer 与 runtime 是**独立仓颉工程、独立 `target/` 目录、依赖以 static 形式分别编入各自产物**，
因此两者编译互不耦合。但「运行时编译某产物」仍有两点需注意：

1. **runtime 运行中编译 installer**：无副作用。installer 的构建只写 `installer/target/`，
   不触碰 runtime 已加载的二进制或共享库；运行中的 runtime 进程不受影响。
2. **L3 进程隔离轨插件运行中编译该插件**：L3 插件是独立 `cjpm executable` 进程（stdio 拉起）。
   编译会重写其 `target/` 下的二进制——**Windows 下运行中的进程持有该二进制文件锁，编译可能因「文件正在使用」而失败**；
   Linux 下 inode 被替换、旧进程仍跑旧代码，直到重启才生效。L2 动态库轨同理（`.dll`/`.so` 被加载时无法覆盖）。
   **结论**：对正在运行的插件/L2 动态库做重编译前，应先停止对应进程/卸载插件，避免覆盖写失败或新旧代码不一致。

---

## 8. 排错速查

| 现象 | 可能原因 | 处理 |
|------|----------|------|
| `无法构建数据库连接` | 缺 `.env` 的 `DATABASE_URL`，也未给 `--user/--password` | 提供凭据或确保 `--source-dir` 仓库根 `.env` 正确。 |
| `E5-*` 门禁失败 | 含 `DROP`/`TRUNCATE`/`DELETE`、未脱敏机密、超体积/超行数 | 按 diagnostics 的 `fix` 修正导出内容后重跑；**不覆盖既有产物**。 |
| `E7-replay` 失败（非占位符语句） | 导出 SQL 含无法重放的语句（如非法类型） | 检查 diagnostics 中「重放语句失败」明细；例如数组列曾被导出为裸 `ARRAY`（已修复为 `text[]` 等带元素类型）。 |
| `E7-replay` degraded | 环境无 `CREATE DATABASE` 权限 | 提供可写 postgres 维护库；否则以 DEGRADED 通过、产物仍提升。 |
| `未知命令` / `缺少 --xxx 的值` | 退出码 2，全局选项放在子命令之后 | 把 `--source-dir` 等全局选项移到子命令之前。 |
| `uninstall` 只报告不执行 | 缺 `--force` | 加 `--force`。 |

---

## 9. 相关文档

- SDD 工程：`specs/RuntimeNativeInstaller/`（`design.md` / `spec.md` / `tasks.md` / `acceptance/T051-e2e-checklist.md`）
- 开发手册技能：`skills/uctoo-dev-manual/`（含数据库设计规范、增量 SQL 规范、V4 API 规范等）
