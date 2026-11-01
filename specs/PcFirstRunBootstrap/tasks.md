# 任务规划文档：PC 客户端首次运行引导（PcFirstRunBootstrap）

> 阶段：task
> 工程：`specs/PcFirstRunBootstrap`
> 上游：`research.md`（草稿）+ `spec.md`（草稿）+ `design.md`（草稿）
> 日期：2026-10-21 · 版本 v0.1 · 状态：草稿

---

## 文档信息
- 关联需求：`spec.md`
- 关联设计：`design.md`
- 生成日期 / 版本 / 状态：2026-10-21 / v0.1 / 草稿

---

## 开发规范（全任务强制遵守）

- **语言与工具绑定**：NSIS 脚本 → 主 agent 直接编写（.nsh）；Electron 主进程（TypeScript）→ web-coder / 主 agent；Vue 组件 → web-coder。本工程**不涉及仓颉代码**。
- **编译约束**：NSIS 脚本改造后需人工执行 `pnpm build:pc` 验证安装包；TypeScript 改造后需 `tsc --noEmit` 验证类型。AI 不运行 `cjpm build`。
- **复用优先（铁律 9）**：不新建数据库表；管理员创建/seed 导入/启停全部委托 `ucInstaller.exe`，不重新实现 installer 已有能力。
- **installer 路径**：复用 `runtime-integrator.ts` 的 `getRuntimeBinPath()`，`ucInstaller.exe` 在同目录 `release/bin/`。
- **既有逻辑保留**：`pgsql.ts` 降级为 fallback（Q-3 决策），不删除；`installer-bridge.ts` 在 Phase 3 基础上增加方法，不重写。
- **进度与日志**：遵循既有日志/进度通道约定；多轮修订须留痕。

---

## 任务总览

| 编号 | 任务 | 关联 spec | 关联 design | 语言/产物 | 状态 |
|---|---|---|---|---|---|
| T-01 | NSIS 安装后初始化钩子（调 `ucInstaller.exe install`） | §5.1 | §2.1,§2.4 | NSIS(.nsh) | 待开始 |
| T-02 | NSIS 随机管理员账号生成 | §5.1.1-规则2 | §2.4 | NSIS(.nsh) | 待开始 |
| T-03 | NSIS 标记文件写入（first-run-credentials.json） | §5.1.1-规则5 | §2.4,§3.3 | NSIS(.nsh) | 待开始 |
| T-04 | NSIS 重装数据保留选择页面 | §5.4 | §2.4 | NSIS(.nsh) | 待开始 |
| T-05 | Electron 自动启停（`installerBridge.serveManage()`） | §5.2 | §2.2,§2.5 | TypeScript | 待开始 |
| T-06 | Electron 退出时自动停止 | §5.2.1-规则4 | §2.3 | TypeScript | 待开始 |
| T-07 | `first-run.ts` 首次运行检测 + 凭据读取/删除 | §5.3 | §2.5 | TypeScript(新建) | 待开始 |
| T-08 | `Welcome.vue` 欢迎页面 | §5.3 | §2.6 | Vue(新建) | 待开始 |
| T-09 | `admin-credentials.ts` NDJSON 解析 + 标记文件读写 | §5.1.1-规则5 | §3.3 | TypeScript(新建) | 待开始 |
| T-10 | 端到端验证（首次安装 + 重装 + 自动启停） | 全部 | 全部 | 手动验证 | 待开始 |

---

## 任务依赖关系图

```
T-02 (随机管理员生成) ──► T-01 (NSIS 安装后初始化) ──► T-03 (标记文件写入)
                                                          │
T-04 (重装选择页面) ──────────────────────────────────────┤
                                                          │
T-09 (NDJSON 解析+标记读写) ──► T-07 (首次运行检测) ──► T-08 (欢迎页面)
                                                          │
T-05 (自动启停) ──────────────────────────────────────────┤
T-06 (退出自动停止) ──────────────────────────────────────┤
                                                          ▼
                                                       T-10 (端到端验证)
```

可并行：T-02/T-04 可并行（均改 NSIS 不同段）；T-05/T-06 可并行（均改 Electron 不同段）；T-07/T-08/T-09 可并行（均为新建文件）。

---

## 任务详细说明

### T-01 [NSIS 安装后初始化钩子]
- **目标**：NSIS 安装完成后自动执行 `ucInstaller.exe install`，完成 DB 初始化 + 管理员创建 + seed 导入。
- **输入**：`pc-client/build/installer.nsh`（既有）、随机管理员 email + 密码（T-02 产出）。
- **步骤**：
  1. 在 `installer.nsh` 的安装 Section 末尾新增 `SEC_POST` Section。
  2. 检测 `$isFirstInstall == "true"`（T-04 设置）。
  3. 构造命令：`ucInstaller.exe install --json --progress=ndjson --admin-email=$adminEmail --admin-password=$adminPassword --admin-name=admin`。
  4. 用 `nsExec::ExecToLog` 执行，捕获退出码。
  5. 退出码 0 → 继续 T-03；非 0 → `MessageBox MB_OK "初始化失败"` + 提供回滚选项。
- **产出物**：`pc-client/build/installer.nsh`（改造）。
- **验收**：首次安装后 `uctoo_user` 表有管理员记录 + seed 数据已导入。
- **风险**：`ucInstaller.exe` 路径错误 → 复用 `resources/runtime/release/bin/` 路径常量。

### T-02 [NSIS 随机管理员账号生成]
- **目标**：NSIS 脚本生成随机管理员 email 和密码。
- **输入**：无。
- **步骤**：
  1. 在 `installer.nsh` 新增 `GenerateRandomAdmin` Function。
  2. email：生成 8 位随机字符串（小写字母+数字）+ `@uctoo.com`。
  3. password：生成 16 位随机字符串（大小写+数字+特殊字符 `!@#$%^&*`）。
  4. 存入 NSIS 变量 `$adminEmail` / `$adminPassword`。
- **产出物**：`pc-client/build/installer.nsh`（改造）。
- **验收**：email 匹配 `^[a-z0-9]{8}@uctoo\.com$`；password 长度 ≥ 16 含大小写+数字+特殊。
- **风险**：NSIS 随机数质量不足 → 用 `Math::Random` 或系统时间种子。

### T-03 [NSIS 标记文件写入]
- **目标**：初始化成功后写 `first-run-credentials.json`。
- **输入**：管理员 email/username/password（T-02）、installer NDJSON final 事件。
- **步骤**：
  1. 在 `installer.nsh` 新增 `WriteCredentialsMarker` Function。
  2. 构造 JSON：`{version:1, email, username:"admin", name:"admin", password, createdAt:<ISO8601>}`。
  3. 写入 `<用户数据目录>/first-run-credentials.json`（用 `APPDATA` 环境变量）。
  4. 设置文件权限仅当前用户可读。
- **产出物**：`pc-client/build/installer.nsh`（改造）。
- **验收**：安装后 `first-run-credentials.json` 存在且 JSON 合法。
- **风险**：用户数据目录不可写 → fallback 到安装目录 `logs/` 下。

### T-04 [NSIS 重装数据保留选择页面]
- **目标**：重装时弹出"覆盖安装/保留数据"选择页面。
- **输入**：`pc-client/build/installer.nsh`（既有）。
- **步骤**：
  1. 在 `installer.nsh` 新增 `CheckExistingInstall` Function。
  2. `IfFileExists "$INSTDIR\AgentSkills Runtime.exe"` 检测已有安装。
  3. 有已有安装 → 调 `ShowDataChoicePage`（NSIS 自定义页面，两个单选按钮）。
  4. 覆盖 → `$isFirstInstall="true"`；保留 → `$preserveData="true"`。
  5. 保留数据 → 跳过 T-01 的 `SEC_POST` Section。
- **产出物**：`pc-client/build/installer.nsh`（改造）。
- **验收**：重装时弹出选择页面；选保留 → 数据库不变；选覆盖 → 执行完整初始化。
- **风险**：NSIS 自定义页面语法复杂 → 参考 electron-builder NSIS 模板。

### T-05 [Electron 自动启停]
- **目标**：PC 启动时自动调 `ucInstaller.exe serve --manage` 启动 runtime + PG。
- **输入**：`pc-client/electron/main/index.ts`（既有）、`pc-client/electron/modules/installer-bridge.ts`（Phase 3 既有）、`pc-client/electron/modules/config.ts`（既有）。
- **步骤**：
  1. 在 `installer-bridge.ts` 新增 `serveManage()` 方法：spawn `ucInstaller.exe serve --manage`，监听 NDJSON 事件。
  2. 在 `installer-bridge.ts` 新增 `stopManage()` 方法：向 `serve --manage` 发停止信号，等待进程退出（超时 10s）。
  3. 在 `index.ts` 的 `app.whenReady()` 中，`config.runtime.autoStart` 为 true 时调 `installerBridge.serveManage()`。
  4. 失败 → `ipcHandler.sendToRenderer('service:startFailed', ...)`，不阻塞。
  5. 既有 `pgsql.ts` 启停逻辑降级为 fallback（`config.useInstaller` 开关控制，Q-3 决策）。
- **产出物**：`pc-client/electron/modules/installer-bridge.ts`（改造）、`pc-client/electron/main/index.ts`（改造）。
- **验收**：PC 启动后 runtime + PG 进程自动启动；导航栏显示服务状态。
- **风险**：`serve --manage` 与既有 `pgsql.ts` 冲突 → Q-3 开关控制，默认走 installer。

### T-06 [Electron 退出时自动停止]
- **目标**：PC 退出时自动停止 runtime + PG。
- **输入**：`pc-client/electron/main/index.ts`（既有）。
- **步骤**：
  1. 在 `index.ts` 注册 `app.on('before-quit', ...)`。
  2. 调 `installerBridge.stopManage()`。
  3. 等待进程退出（超时 10s），超时则 `process.kill` 强制终止。
- **产出物**：`pc-client/electron/main/index.ts`（改造）。
- **验收**：PC 退出后 runtime + PG 进程终止。
- **风险**：退出时 hang → 超时 10s 后强制终止 + 记录日志。

### T-07 [first-run.ts 首次运行检测]
- **目标**：检测首次安装、读取/删除管理员凭据标记文件。
- **输入**：`first-run-credentials.json`（T-03 产出）。
- **步骤**：
  1. 新建 `pc-client/electron/modules/first-run.ts`。
  2. `readCredentials()`：读取 `<APPDATA>/first-run-credentials.json`，JSON 解析，返回 `{email, username, name, password, createdAt, version}` 或 null。
  3. `deleteCredentials()`：删除标记文件。
  4. JSON 解析失败 → 记录日志 + 删除损坏文件 + 返回 null。
- **产出物**：`pc-client/electron/modules/first-run.ts`（新建）。
- **验收**：标记文件存在 → 返回凭据；不存在 → 返回 null；损坏 → 删除 + 返回 null。
- **风险**：文件路径跨平台差异 → 用 Electron `app.getPath('userData')` 统一。

### T-08 [Welcome.vue 欢迎页面]
- **目标**：首次启动显示管理员账号欢迎页面。
- **输入**：`first-run.ts` 返回的凭据（T-07）。
- **步骤**：
  1. 新建 `pc-client/src/views/Welcome.vue`。
  2. 显示 email / username / password，每个字段可复制。
  3. "已记录并理解"按钮 → 触发 `first-run:confirm` IPC → 删除标记文件 → 跳转首页。
  4. 密码字段默认明文显示（供用户记录），可切换隐藏。
  5. 新建 `pc-client/electron/renderer/welcome.html`（Electron 加载入口）。
- **产出物**：`pc-client/src/views/Welcome.vue`（新建）、`pc-client/electron/renderer/welcome.html`（新建）。
- **验收**：首次启动显示欢迎页；用户确认后跳转首页；非首次启动不显示。
- **风险**：Vue 路由集成 → welcome.html 独立入口，不走 Vue Router。

### T-09 [admin-credentials.ts NDJSON 解析 + 标记文件读写]
- **目标**：从 installer NDJSON 流解析管理员信息，提供标记文件读写工具。
- **输入**：installer `install --json` 的 NDJSON 输出。
- **步骤**：
  1. 新建 `pc-client/electron/modules/admin-credentials.ts`。
  2. `parseAdminFromNdjson(lines: string[])`：从 NDJSON final 事件提取管理员信息。
  3. `writeCredentialsFile(credentials)`：写 `first-run-credentials.json` 到 `app.getPath('userData')`。
  4. `generateRandomEmail()`：生成 `<8位随机>@uctoo.com`。
  5. `generateRandomPassword()`：生成 16 位随机密码（大小写+数字+特殊）。
- **产出物**：`pc-client/electron/modules/admin-credentials.ts`（新建）。
- **验收**：NDJSON 解析正确；标记文件 JSON 合法；随机 email/password 符合 spec §6.1 约束。
- **风险**：NDJSON 格式变化 → 按 installer `--progress=ndjson` 契约解析，容错处理。

### T-10 [端到端验证]
- **目标**：验证首次安装 + 重装 + 自动启停全链路。
- **输入**：T-01~T-09 全部完成。
- **步骤**：
  1. **首次安装**：全新目录安装 → 验证 DB 初始化 + 管理员创建 + seed 导入 + 标记文件。
  2. **首次启动**：打开 PC → 验证 runtime + PG 自动启动 + 欢迎页显示管理员账号。
  3. **确认后跳转**：点击"已记录" → 验证标记文件删除 + 首页加载。
  4. **重装-覆盖**：覆盖安装 → 验证新管理员创建 + 欢迎页显示新账号。
  5. **重装-保留**：保留数据安装 → 验证数据库不变 + 不显示欢迎页。
  6. **退出**：关闭 PC → 验证 runtime + PG 进程终止。
  7. **启停失败**：模拟端口冲突 → 验证首页不阻塞 + 异常状态显示。
- **产出物**：验证报告。
- **验收**：全部 7 项验证通过。
- **风险**：环境差异 → 在干净 Windows 环境验证。

---

## 需求覆盖追踪矩阵

| spec 需求 | 覆盖任务 | 覆盖状态 | 备注 |
|---|---|---|---|
| §5.1 安装后自动初始化 | T-01,T-02,T-03,T-09 | 全覆盖 | NSIS 钩子 + installer install |
| §5.1.1-规则1 首次安装自动初始化 | T-01,T-04 | 全覆盖 | T-04 检测首次/重装 |
| §5.1.1-规则2 管理员自动生成 | T-02,T-09 | 全覆盖 | NSIS 生成随机账号 |
| §5.1.1-规则3 seed 自动导入 | T-01 | 全覆盖 | installer S6 |
| §5.1.1-规则4 初始化进度展示 | T-01 | 全覆盖 | NDJSON → NSIS 进度条 |
| §5.1.1-规则5 标记文件写入 | T-03,T-09 | 全覆盖 | |
| §5.2 自动启停 | T-05,T-06 | 全覆盖 | serve --manage |
| §5.2.1-规则1 runtime 自动启动 | T-05 | 全覆盖 | |
| §5.2.1-规则2 数据库自动启动 | T-05 | 全覆盖 | serve --manage 统一管控 |
| §5.2.1-规则3 web-admin 自动启动 | T-05 | 全覆盖 | 既有逻辑保留 |
| §5.2.1-规则4 退出时自动停止 | T-06 | 全覆盖 | |
| §5.3 首次欢迎页面 | T-07,T-08 | 全覆盖 | |
| §5.3.1-规则1 首次显示欢迎页 | T-07 | 全覆盖 | 标记文件检测 |
| §5.3.1-规则2 展示管理员账号 | T-08 | 全覆盖 | |
| §5.3.1-规则3 确认后删除标记 | T-07,T-08 | 全覆盖 | |
| §5.4 重装数据保留选择 | T-04 | 全覆盖 | NSIS 选择页面 |
| §5.4.1-规则1 重装检测 | T-04 | 全覆盖 | |
| §5.4.1-规则2 覆盖安装 | T-04,T-01 | 全覆盖 | |
| §5.4.1-规则3 保留数据 | T-04 | 全覆盖 | 跳过 install |
| §4.1 性能 | T-01,T-05 | 全覆盖 | NDJSON 流式 + 超时控制 |
| §4.2 可靠性 | T-01,T-05,T-07 | 全覆盖 | 回滚 + 不阻塞 + 原子写入 |
| §4.3 安全性 | T-03,T-07,T-08 | 全覆盖 | 删除标记 + 文件权限 + 随机性 |
| §4.4 可维护性 | T-01,T-05 | 全覆盖 | 日志写入 |
| §4.5 兼容性 | T-04,T-07 | 全覆盖 | 保留数据 + 标记文件不存在 |

---

## 验收检查清单（终验）

- [ ] 全部 spec 功能需求有对应实现并通过其验收条件
- [ ] DFX 约束（性能/可靠/安全/可维护/兼容）已验证或标注豁免
- [ ] 复用项未被重新实现（installer 能力全部委托，不重写）
- [ ] NSIS 脚本改造后 `pnpm build:pc` 产出的安装包可正常安装
- [ ] TypeScript 改造后 `tsc --noEmit` 通过
- [ ] 首次安装：DB 初始化 + 管理员创建 + seed 导入 + 标记文件 + 欢迎页
- [ ] 重装-覆盖：新管理员 + 欢迎页
- [ ] 重装-保留：数据库不变 + 不显示欢迎页
- [ ] 自动启停：PC 启动 → runtime + PG 就绪；PC 退出 → 进程终止
- [ ] 启停失败不阻塞首页
- [ ] spec / design / tasks 三份文档与最终实现一致（无漂移）

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件清单 | 验证结果 |
|---|---|---|---|---|
| 2026-10-21 | r1 | 用户需求（PC 客户端首次运行引导） | research.md/spec.md/design.md/tasks.md（新建） | 待 gate 闸口 confirm |

---

> 配套模板：`test-report-template.md`（测试验收报告）、`research-template.md`（研究文档）均见 `skills/sdd/templates/`。