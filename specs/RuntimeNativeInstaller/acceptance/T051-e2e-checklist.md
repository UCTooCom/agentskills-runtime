# T051 端到端验收清单（干净机器）

> **前置**：T050 出包已完成，`dist/ucInstaller-win-x64/` 可用。
> **环境要求**：一台**干净机器**——无 Node、无 runtime、无数据库数据。
> **填写方式**：每行勾 `通过 / 失败 / 不适用`，失败行必须留证据（命令输出或截图）。
> 判据原文引自 `spec.md` / `tasks.md`，不改写。

---

## 0. 出包前置（T050 门禁复检）

在**打包机**上执行，产物再拷到干净机器。

```powershell
cd apps\agentskills-runtime\installer
powershell -NoProfile -ExecutionPolicy Bypass -File package.ps1
```

| # | 判据 | 通过标准 |
|---|---|---|
| 0.1 | 脚本末行 `Packaged OK`，`exit=0` | 门禁 0 issue |
| 0.2 | `ucInstaller.exe help` 退出码 0 并打印用法 | 证明 DLL 全解析（不做这一步，缺 `libblowfish.dll` 时表现为 `0xC0000135` 秒退，肉眼看不出来） |
| 0.3 | 产物目录同时存在 `libcrypto-3-x64.dll` 与 `libssl-3-x64.dll` | AC-159 原文："WHEN 完成动态库对齐，THEN THE SYSTEM SHALL 保证可执行文件所在目录同时存在两个指定名称的加密库文件，缺一即判定该组件自检失败" |

---

## 1. 引导服务

| # | 判据（原文） | 怎么验 | 通过标准 |
|---|---|---|---|
| 1.1 | AC-023："WHEN 收到 `GET /healthCheck`，THEN THE SYSTEM SHALL 返回 HTTP 200 与响应体 `success`，且该响应体不含引号、不含空白、不含 JSON 包装" | `curl -s -i http://localhost:3000/healthCheck` | 状态行 `200`；body 字节数 == 7，严格等于 `success` |
| 1.2 | AC-037：30 次 × 2 秒轮询返回同一份纯文本，"不得附加 BOM、换行或 JSON 包装" | 连续请求 30 次比对 | 30 次响应字节完全一致，无 BOM（`EF BB BF`） |
| 1.3 | 17 端点全通 | 逐个 `GET/POST /api/setup/<x>` | 无 404、无 500；未实现项须返回结构化失败而非空体 |
| 1.4 | CORS `*` | `curl -s -i -H "Origin: http://x" /api/setup/check-environment` | 响应头 `Access-Control-Allow-Origin: *`；OPTIONS 预检 200 |

---

## 2. 环境检测

| # | 判据 | 怎么验 | 通过标准 |
|---|---|---|---|
| 2.1 | 三级降级如实标记（pass / degraded / fail），不得把不可达标成成功 | `GET /api/setup/check-environment` | 每一项带明确档位；缺失项标 `degraded/fail` 并带 `fix` |
| 2.2 | `--json` 报告可解析（CLI 与 HTTP 双通道，design §4.2.4 / R-42） | `ucInstaller.exe --json check-environment` | stdout 单行 JSON，`schema == "ucinstaller/report/v1"`，可被 JSON 解析器解析 |
| 2.3 | CLI 通道驱动主流程（安装/DevKit/回滚/卸载不再是 HTTP 唯一通道） | `ucInstaller.exe install` / `ucInstaller.exe devkit install DK-3` / `ucInstaller.exe rollback` / `ucInstaller.exe uninstall` | 与 HTTP 端点共用 `core/`+`services/` 同一份实现，CLI 返回 §4.11.1 报告 |
| 2.4 | 运维管控模式（T056） | `ucInstaller.exe --manage serve` | 启动 `127.0.0.1:<port>` 仅挂运维端点；`--auto-exit` 观测到 runtime 停止后以 0 退出 |
| 2.5 | 流式进度（T053，与 `--json` 互斥） | `ucInstaller.exe --progress=ndjson install` | 每行一条 NDJSON 事件；末行含 `exitCode`/`ok`；诊断走 stderr |

> **2.2 已解决**：CLI 分支（`cli/env_check.cj` ← `services/envcheck.cj`）已落地，环境检测可走命令行，
> 与 HTTP 端点同一底座；`--json` 判据不再只能依赖 `seed verify` 等旁路子命令。

---

## 3. 管理员

| # | 判据 | 怎么验 | 通过标准 |
|---|---|---|---|
| 3.1 | `uctoo_user` 真实落库 | `SELECT count(*) FROM uctoo_user WHERE user_type='human' AND deleted_at IS NULL;` | `>= 1` |
| 3.2 | 哈希以 `$2a$10$` 开头（AC-005） | `SELECT password FROM uctoo_user WHERE user_type='human' LIMIT 1;` | `left(password,7) = '$2a$10$'` |
| 3.3 | 单次哈希 ≤ 3 s | 登录一次并计时（前端 15 s 超时，需留足余量） | ≤ 3 s |

---

## 4. 账号二元组

| # | 判据 | 怎么验 | 通过标准 |
|---|---|---|---|
| 4.1 | 恰好 2 个账号（AC-215/216：不得出现 `liming`/`wangfang`/`chenwei`/`liuyang`/`zhaoxue`/`test1`） | `SELECT login_name FROM uctoo_user WHERE deleted_at IS NULL;` | 行数 == 2；无上述演示账号 |
| 4.2 | AC-214 双向指针非空且一致 | `SELECT count(*) FROM uctoo_user u JOIN agents a ON u.agent_id = a.id AND a.user_id = u.id WHERE u.deleted_at IS NULL;` | `== 1` |
| 4.3 | 主 agent 可自动登录 | 用主 agent 账号走一次登录 | 登录成功，无需人工输口令 |

---

## 5. Seed 导入

| # | 判据 | 怎么验 | 通过标准 |
|---|---|---|---|
| 5.1 | 悬空引用 == 0 | `ucInstaller.exe seed verify --source-dir <repoRoot>` | 报告里 dangling refs == 0 |
| 5.2 | 菜单树非空（**这一条最关键**：裸 `psql -f` 会一路报成功但菜单是空的） | 以超管登录前端看菜单；或走 `PermissionsService.getUserMenuTree` 同口径 SQL | 菜单项 > 0 |
| 5.3 | `agent_skills` / `db_connection` 无导入数据 | `SELECT count(*) FROM agent_skills;` / `SELECT count(*) FROM db_connection;` | 均为 0（同步派生表不落数据行） |

---

## 6. 脱敏

| # | 判据 | 怎么验 | 通过标准 |
|---|---|---|---|
| 6.1 | 产物无 `ghp_` / `sk-` / `postgres://` | `grep -E "ghp_\|sk-\|postgres://" sql/uctooDB.sql` | 无命中 |
| 6.2 | `website.appid` 原值保留（OQ-C1） | `SELECT value FROM config WHERE key='website.appid';` | 与源库一致，非 `{{secret:...}}` 占位符 |
| 6.3 | `site.API_URL` 原样保留 | `SELECT value FROM config WHERE key='site.API_URL';` | 同上 |

---

## 7. 自退役

| # | 判据（原文） | 怎么验 | 通过标准 |
|---|---|---|---|
| 7.1 | AC-126：周期性探测健康端点，连续 3 次 200 后标记"可退役" | 完整安装后观察安装器日志 | 日志出现可退役标记 |
| 7.2 | AC-127："WHILE 启用自动退出开关，WHEN 退役判据满足，THEN THE SYSTEM SHALL 以退出码 0 结束自身进程" | `--auto-exit` 启动 | 进程退出码 0 |
| 7.3 | AC-128："不得停止已启动的 runtime 进程……保留全部安装产物、环境文件与状态文件" | 安装器退出后查 runtime | runtime 仍在运行；`release/`、`.env`、`.install-state.json` 均在 |

---

## 8. 失败路径（**不能只跑主路径**）

| # | 判据 | 怎么验 | 通过标准 |
|---|---|---|---|
| 8.1 | 断网 → **明确失败**而非降级 | 拔网线 / 断代理后跑安装（可加 `--truthful`） | 明确失败 + 带 `fix`；不得报成功 |
| 8.2 | git 缺失 → 明确失败（DK-3 只 `git clone`，无兜底） | 临时把 `git.exe` 移出 PATH 后跑 DevKit 安装 | 明确失败并提示安装 git |
| 8.3 | 非空非本仓库目录 → 拒绝 | 指向一个非空且非本仓库的目录 | 拒绝执行，不删不写 |

---

## 本轮发现、需拍板的两处偏差（已解决）

1. **`assets/` 路径口径不一致**：`design.md` §4.12.3 原图画的 `assets/install/{html,js,css}` 与代码
   `core/paths.cj:72`（`installRoot.join("assets")`）+ `routes.cj` 的 `serveStatic` 不一致。
   **已按代码订正 design 图**：出包脚本 `package.ps1` 平铺输出 `assets/install.html|js|css`。
2. **`check-environment` 无 CLI 分支**：已落地 `cli/env_check.cj`（← `services/envcheck.cj`），
   `main.cj` 增加 `check-environment` 分支，CLI 与 HTTP 共用同一底座（design §4.2.4 / R-42）。

## 仍属 Phase 10 跨工程项（不在 installer 工程内，需另立任务单 + 各自编译）

| 项 | 落点 | 内容 |
|---|---|---|
| T052 / T057 | `apps/web-admin` | 向导占位符 `{{principal/agent/secret/env}}` 呈现；四面板适配（修 N-4 进程名判定） |
| T054 | `apps/agentskills-runtime/src` | runtime 侧日志端点（与 installer 的 `GET /api/setup/...` 对齐） |
| T055 | 同上 | 环境检测端点（呼应 installer 的 `check-environment`） |
| T058 | 同上 | `/api/v1/health` 的 `chatModel.available` 假绿灯修复（N-5） |

> installer 工程自身代码至 T056 已闭环；上述项改动落在其它子仓库，需在其各自构建环境验证。
