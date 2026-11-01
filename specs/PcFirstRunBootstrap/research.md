# 研究文档：PC 客户端首次运行引导（PcFirstRunBootstrap）

> 阶段：research
> 工程：`specs/PcFirstRunBootstrap`
> 日期：2026-10-21 · 版本 v0.1 · 状态：草稿

---

# 用户原始需求

用户安装 `AgentSkills Runtime-Windows-0.1.0-Installer.exe` 后，PC 客户端仅 web 服务可用，内嵌 runtime 和数据库无法通过界面启动，数据库无法初始化。期望效果：

1. **安装后自动初始化**：安装完成后，内置数据库自动创建管理员账号（`随机字符串@uctoo.com` 作为 email，`admin` 作为 name 和 username，密码随机），并用该账号从 seed 数据自动初始化。
2. **打开即用**：用户打开 PC 客户端后，内置数据库和 runtime 自动启动服务。
3. **首次欢迎页**：首次安装或覆盖安装后，首次打开显示欢迎页面，展示自动创建的管理员账号，提示用户记录。
4. **重装选择**：重装时可选覆盖安装（执行步骤 1）或保留已有数据（不覆盖数据、不创建新管理员）。

- 目标：PC 客户端安装后"开箱即用"，runtime + 数据库自动启动，首次显示管理员账号
- 范围（In Scope）：NSIS 安装后钩子、管理员自动创建、seed 自动导入、PC 启动时自动启停、欢迎页面、重装数据保留选择
- 非范围（Out of Scope）：installer 自身功能改造（复用已有）、web-admin 业务功能、runtime 内部逻辑
- 关键约束：复用 installer 已有 `bcrypt_admin` + `seed` + `serve --manage`；不新建数据库表；AI 不跑 `cjpm build`

---

# 研究结果

## 一、现状与定位

### 1.1 与既有相关工程的关系

| 工程 | 路径 | 关系 |
|---|---|---|
| RuntimeNativeInstaller | `specs/RuntimeNativeInstaller/` | **上游供给方**：installer 已实现 `bcrypt_admin`（管理员创建）、`seed apply/verify`（seed 导入）、`serve --manage`（启停管控）、`install` CLI（S0~S8 编排）。本工程复用这些能力，不重新实现。 |
| PcClientInstallerIntegration | `specs/PcClientInstallerIntegration/` | **并行工程**：负责 PC 委托层（Phase 3 已落盘）和托管层（Phase 4 待做）。本工程与 Phase 4 有交集——PC 启停经 `serve --manage` 管控是共同目标。 |
| pc_desktop_client | `.codeartsdoer/specs/pc_desktop_client/` | **历史基线**：v2.6 定义了 PC 客户端架构，含 `pgsql.ts`（内嵌 PG 启停）、`setup.ts`（安装向导）、`runtime-integrator.ts`（runtime 解压）。本工程在此基础上补齐"安装后自动初始化 + 首次欢迎 + 自动启停"。 |

### 1.2 本质区别

本工程不是重新设计安装流程，而是**编排已有能力**：

| 已有能力（installer 侧） | 已有缺口（PC 侧） | 本工程动作 |
|---|---|---|
| `bcrypt_admin.cj` 创建管理员 | NSIS 安装后未调用 | NSIS 钩子调 `ucInstaller.exe install` |
| `seed apply` 导入 seed | PC 安装后未调用 | NSIS 钩子串接 seed 导入 |
| `serve --manage` 启停管控 | PC Phase 4 托管层未完成 | PC 启动时调 `serve --manage` 自动启停 |
| — | 无首次欢迎页面 | 新增 Electron 欢迎页 |
| — | 无重装数据保留选择 | NSIS 增加保留/覆盖选项 |

## 二、已有可复用基础设施盘点

### 2.1 installer 侧（仓颉原生安装器）

- `installer/src/services/bcrypt_admin.cj`：创建管理员账号，bcrypt cost 10，真实落库 `uctoo_user`。**直接复用**：NSIS 安装后调 `ucInstaller.exe install` 触发 S5（管理员创建）。
- `installer/src/services/seed/{importer,rbac,verify}.cj`：seed 导入 + RBAC 权限骨架 + 身份重绑定。**直接复用**：S6（seed 导入）自动串接。
- `installer/src/cli/seed_cmd.cj`：`seed apply` / `seed verify` CLI 命令。**直接复用**：PC 可独立调用补导。
- `installer/src/serve/manage.cj`：`serve --manage` 运维管控模式（只挂运维端点、不推进 S0~S8）。**直接复用**：PC 启动时调此命令管控 runtime/PG 启停。
- `installer/src/cmd/install_cmd.cj`：`runInstall`（S0~S8 编排 + 骨架校验 + 自退役）。**直接复用**：NSIS 安装后调 `ucInstaller.exe install --json` 完成全部初始化。
- `installer/src/core/orchestrator.cj`：S0~S8 编排（环境检查→DB→runtime→admin→seed→env→SSL→自退役）。**间接复用**：经 `install` 命令触发。

### 2.2 PC 客户端侧（Electron）

- `apps/pc-client/build/installer.nsh`：NSIS 安装脚本钩子。**改造复用**：增加安装后执行 `ucInstaller.exe install` 的逻辑。
- `apps/pc-client/electron/modules/config.ts`：已有 `runtime.autoStart` / `pgsql.embedded.autoStart` 配置项。**改造复用**：确保 autoStart 默认 true 并接通启停逻辑。
- `apps/pc-client/electron/modules/pgsql.ts`（16KB）：内嵌 PG 初始化/启停/连接测试。**降级复用**：Phase 4 完成后改为调 `serve --manage`，旧逻辑保留为 fallback。
- `apps/pc-client/electron/modules/runtime-integrator.ts`：runtime 解压 + `getRuntimeBinPath()`。**直接复用**：获取 `ucInstaller.exe` 路径（同目录 `release/bin/`）。
- `apps/pc-client/electron/modules/setup.ts`：安装向导编排。**改造复用**：增加首次欢迎页面分支。
- `apps/pc-client/electron/main/index.ts:607`：已有 `runtime.autoStart` 判断逻辑。**改造复用**：接通 `serve --manage` 启停调用。

### 2.3 数据资源

- `apps/agentskills-runtime/sql/uctooDB.sql`：数据库 schema（1MB）。**直接复用**：installer S4 导入。
- `apps/agentskills-runtime/sql/seed/`：seed 主体清单 + 权限骨架。**直接复用**：installer S6 导入。
- `apps/pc-client/resources/defaults/default-config.json`：默认配置（runtime port 8080, pgsql embedded port 5432, autoStart true）。**直接复用**。

## 三、能力缺口分析

| 缺口 | 现状 | 待建（本工程范围） | 复用/新建 |
|---|---|---|---|
| NSIS 安装后自动初始化 | `installer.nsh` 无安装后执行 | NSIS 钩子调 `ucInstaller.exe install` | 改造 `installer.nsh` |
| 管理员账号随机生成 | `bcrypt_admin.cj` 需传入账号参数 | 生成 `随机字符串@uctoo.com` + 随机密码 | 新增随机生成逻辑（NSIS 或 installer 参数） |
| 首次欢迎页面 | PC 无欢迎页 | Electron 欢迎页显示管理员账号 | 新增 Electron 页面 |
| 管理员账号传递给 PC | installer 创建管理员后 PC 不知 | installer 输出管理员信息 → PC 读取 | 复用 installer `--json` 输出 |
| PC 启动时自动启停 | Phase 4 托管层未完成 | PC 启动调 `serve --manage` | 改造 `index.ts` + `pgsql.ts` |
| 重装数据保留选择 | NSIS 无保留选项 | NSIS 增加覆盖/保留单选 | 改造 `installer.nsh` |
| 首次安装检测 | PC 无首次/重装区分 | 检测数据目录是否已有数据 | 新增检测逻辑 |
| 管理员账号持久化展示 | 欢迎页需读取管理员信息 | installer 写入标记文件 → PC 读取 | 复用 installer 产物 |

## 四、推荐工程方案

### 4.1 总体形态

本工程是**纯编排层**——不新建任何仓颉代码、不新建数据库表，只做：
1. NSIS 脚本改造（安装后钩子）
2. Electron 主进程改造（自动启停 + 欢迎页）
3. Electron 渲染进程新增欢迎页面

### 4.2 核心编排草图

```
【安装时】
NSIS Installer
  ├─ 解压文件（electron-builder 原有）
  ├─ 检测是否已有数据目录
  │   ├─ 首次安装 → 标记 firstRun=true
  │   └─ 重装 → 弹出选择：覆盖 / 保留
  ├─ if (首次 or 覆盖):
  │   └─ 执行 ucInstaller.exe install --json
  │       ├─ S0~S3: 环境检查 + DB 初始化 + runtime 部署
  │       ├─ S4: 导入 uctooDB.sql schema
  │       ├─ S5: 创建管理员（随机字符串@uctoo.com / admin / 随机密码）
  │       ├─ S6: seed 导入 + RBAC + 身份重绑定
  │       ├─ S7: 生成 .env
  │       └─ S8: 自退役
  ├─ 管理员信息写入标记文件（first-run-credentials.json）
  └─ 创建桌面快捷方式

【PC 客户端启动时】
Electron main
  ├─ 读取 default-config.json
  ├─ if (runtime.autoStart):
  │   └─ 调 ucInstaller.exe serve --manage（启动 runtime + PG）
  ├─ if (webadmin.autoStart):
  │   └─ 启动 web-admin HTTP 服务
  ├─ 检测 first-run-credentials.json
  │   ├─ 存在 → 显示欢迎页面（管理员账号）→ 用户确认后删除标记
  │   └─ 不存在 → 正常加载首页
  └─ 加载首页 iframe
```

### 4.3 复用决策

| 复用项 | 来源 | 方式 |
|---|---|---|
| 管理员创建 | `installer/services/bcrypt_admin.cj` | NSIS 调 `ucInstaller.exe install` 触发 S5 |
| seed 导入 | `installer/services/seed/*` | 同上，S6 自动串接 |
| 启停管控 | `installer/serve/manage.cj` | PC 调 `ucInstaller.exe serve --manage` |
| runtime 路径 | `pc-client/electron/modules/runtime-integrator.ts` | `getRuntimeBinPath()` 取同目录 `ucInstaller.exe` |
| 配置 | `pc-client/electron/modules/config.ts` | autoStart 默认 true |
| NSIS 钩子 | `pc-client/build/installer.nsh` | 改造增加安装后执行 |

### 4.4 需新建的最小集合

| 文件 | 类型 | 说明 |
|---|---|---|
| `pc-client/build/installer.nsh`（改造） | NSIS 脚本 | 增加安装后执行 + 重装选择 |
| `pc-client/electron/main/index.ts`（改造） | TypeScript | 接通自动启停 + 欢迎页检测 |
| `pc-client/electron/modules/first-run.ts`（新建） | TypeScript | 首次运行检测 + 凭据读取 |
| `pc-client/electron/modules/installer-bridge.ts`（改造） | TypeScript | 调 `ucInstaller.exe` 的桥接（Phase 3 已有基础） |
| `pc-client/src/views/Welcome.vue`（新建） | Vue 组件 | 欢迎页面，显示管理员账号 |
| `pc-client/electron/modules/admin-credentials.ts`（新建） | TypeScript | 随机管理员账号生成 + 标记文件读写 |

## 五、关键设计决策与风险

1. **管理员账号生成位置**：决策为 **NSIS 脚本生成随机字符串，传给 `ucInstaller.exe install` 作为参数**。原因：installer 的 `bcrypt_admin.cj` 已接受账号参数，NSIS 侧生成随机字符串只需简单脚本，不需改 installer 代码。

2. **管理员信息传递**：决策为 **installer `--json` 输出 + 标记文件 `first-run-credentials.json`**。原因：installer 已支持 `--json` 输出（NDJSON 事件流），PC 从中提取管理员信息写入标记文件，首次启动时读取展示。

3. **自动启停方式**：决策为 **PC 启动时调 `ucInstaller.exe serve --manage`**。原因：`serve --manage` 是 installer 的运维管控模式（T056 已完成），只挂运维端点不推进 S0~S8，正好用于 PC 托管 runtime/PG 启停。这填补了 PcClientInstallerIntegration Phase 4 的缺口。

4. **重装数据保留**：决策为 **NSIS 增加自定义页面，单选"覆盖安装/保留数据"**。原因：NSIS 原生支持自定义页面，保留数据时跳过 `ucInstaller.exe install`，仅更新程序文件。

5. **风险：installer 路径发现**：PC 需找到 `ucInstaller.exe`。缓解：`runtime-integrator.ts` 的 `getRuntimeBinPath()` 已返回 `release/bin/` 目录，`ucInstaller.exe` 同目录（OQ-D2），复用同一路径常量。

6. **风险：安装后初始化耗时**：`ucInstaller.exe install` 执行 S0~S8 可能耗时数分钟。缓解：NSIS 安装页面显示进度条，installer `--progress=ndjson` 流式输出进度。

7. **风险：管理员密码安全**：随机密码需安全传递。缓解：密码仅写入 `first-run-credentials.json`（用户目录，权限受限），展示后用户可选择删除；installer 侧 bcrypt 哈希落库，不存明文。

8. **约束**：AI 不运行 `cjpm build`；NSIS 脚本改造后需人工编译验证（`pnpm build:pc`）。

## 六、后续步骤指引

- **下一步（需求规格）**：固化 REQ-FRB-001~010（安装后初始化 / 自动启停 / 欢迎页 / 重装选择）
- **再下一步（设计）**：细化 NSIS 脚本改造、Electron 主进程改造、欢迎页面设计、标记文件格式
- **任务规划**：拆为 NSIS 改造 / Electron 改造 / Vue 欢迎页 / 端到端验证 四类任务

---

# 附录 A：本研究直接复用的关键文件索引

| 用途 | 文件 | 备注 |
|---|---|---|
| 管理员创建 | `installer/src/services/bcrypt_admin.cj` | 原样调用（经 `install` 命令 S5） |
| seed 导入 | `installer/src/services/seed/{importer,rbac,verify}.cj` | 原样调用（经 `install` 命令 S6） |
| 启停管控 | `installer/src/serve/manage.cj` | 原样调用（`serve --manage`） |
| 安装编排 | `installer/src/cmd/install_cmd.cj` | 原样调用（`install --json`） |
| NSIS 钩子 | `pc-client/build/installer.nsh` | 改造复用 |
| runtime 路径 | `pc-client/electron/modules/runtime-integrator.ts` | 原样调用 |
| 配置 | `pc-client/electron/modules/config.ts` | 改造复用 |
| installer 桥接 | `pc-client/electron/modules/installer-bridge.ts` | 改造复用（Phase 3 已有基础） |
| 默认配置 | `pc-client/resources/defaults/default-config.json` | 原样复用 |