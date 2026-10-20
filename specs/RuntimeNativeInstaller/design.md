# 技术设计文档：RuntimeNativeInstaller

## 文档信息

- **项目名称**：RuntimeNativeInstaller（可执行文件名 `ucInstaller.exe`）
- **版本**：1.8
- **创建日期**：2026-10-07
- **最后修订**：2026-10-09（`check-environment` CLI/HTTP 分层落地 + §4.12.3 出包图订正，见 §12.3 v1.8）
- **作者**：sdd-design-writer（SDD 流程技术设计步）
- **状态**：草稿（待设计评审）
- **需求依据**：`apps/agentskills-runtime/specs/RuntimeNativeInstaller/spec.md`（1982 行，**REQ-RNI-001~109**，**AC-001~276**，能力面 **M1~M18**）
- **上游研究**：
  - `research.md`（17 端点真值表 §1.2、形态抉择 §1.5）
  - `research-devenv.md`（DevKit 组件表 §二、初始化动作 §五）
  - `research-seed-identity.md`（Seed Identity Contract：身份引用实测 §1.2、导入五步 P0~P4 §3.3）
  - `research-seed-export.md`（默认库名 §一、初始账号二元组 §二、导出机制 SEP §三）
  - `research-seed-content.md`（T-F 同步/派生档 §一、`config` 双源 §二、脱敏 R1~R4 §三）
  - `research-deployment.md`（发布形式 §二、消费形式 §三、PC 复用 §四、替代 nestJs 的 M1~M3 路线与缺口 N-3 §五）
- **仓颉 API 取证来源**：`skills/CangjieSkills/references/api/std/process/…`（std API 知识库，19.1 MB / 7822 文件）

> **形态决议（闸口已拍板，本文直接体现）**：Stage A = 独立 install 应用（仓颉单二进制 `ucInstaller.exe`），hyperion/http_lib 自托管 `:3000`；**不做 L3 进程隔离轨 install 技能插件**（`spec.md:11`）。

---

## 1. 需求与存量功能关系分析

### 1.1 分析方法与口径

以 `spec.md` §5 的 **M1~M18 共 18 项能力**为行，拆解为 **20 个需求面**，逐项与 runtime 仓库既有资产比对，判定归属「已实现（100% 复用）/ 需扩展（部分复用）/ 需新增（存量不适用）」。判定依据一律为仓库代码事实（`文件:行号`），不使用印象结论。

> **口径说明**：M14~M18 是 gate-design 阶段后续追加的能力面（对应 §4.10.1.1、§4.10.5、§4.10.6、§4.13），其需求面在 §1.4 中以 **N-06~N-09** 登记；M1~M13 的 16 个需求面（R-01~R-06 / E-01~E-05 / N-01~N-05）编号与结论**不作改动**。

**复用度口径**：

- `100%` = 既有资产可直接调用或整段照抄，无需改写；
- `部分` = 既有资产提供能力基座，但语义、调用形态或宿主约束导致必须重写上层逻辑；
- `不适用` = 仓库内不存在对应资产，必须新建。

**汇总**：20 个需求面中，100% 复用 6 项、部分复用 5 项、不适用 9 项。  
**可复用项占比 =（6 + 5 × 0.5）/ 20 ≈ 43%**。

### 1.2 已实现（可直接复用，复用度 100%）

| 编号   | 需求面（对应 spec 能力）                 | 存量资产与取证位置                                                                                                                                                                                  | 复用度  | 复用方式                                                                      |
| ---- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- | ------------------------------------------------------------------------- |
| R-01 | M1 HTTP 服务与路由（17 端点承载）          | `libs/http_lib`：`HttpServer`（`src/server/server.cj:112`）、`HttpServerConfig`（`:45`）、`Router.get/post/options/group/use`（`src/router/router.cj:108,116,156,96,60`）                           | 100% | 直接 `import http_lib.*`；子工程以 `path` 依赖引入                                   |
| R-02 | M1 跨域放行（CORS `*`）               | `libs/http_lib/src/router/cors.cj:23` `CorsConfig`（默认 `allowOrigins=["*"]`）、`:37` `corsMiddleware(config)`，已内置预检处理                                                                         | 100% | `router.use(corsMiddleware(config))`，零改默认值即满足 AC-041/042                  |
| R-03 | M1 静态向导自托管                      | `libs/http_lib/src/server/file_server.cj:98` `serveStatic(root, config!)`、`:66` `mimeTypeByExtension`、`:78` `FileServerConfig`                                                             | 100% | 托管 `assets/install/` 目录，MIME 由库给出（AC-043~045）                             |
| R-04 | M8 直连 PostgreSQL 写 `uctoo_user` | `libs/pgsql-driver`：`PostgresDriver`（`src/driver.cj:17`）、`PgDatasource(host,port,user,password,database)`（`src/datasource.cj:26`）、`PgStatement.query()/update()`（`src/statement.cj:83,94`） | 100% | 直连建连 → `prepareStatement` → `update()`；驱动注册范式照抄 `src/app/main.cj:144-153` |
| R-05 | M8 bcrypt cost 10 哈希            | `libs/blowfish-cj/src/bcrypt.cj:221` `Bcrypt.hash(password, cost!: Int64 = 10)`、`:229` `Bcrypt.verify(password, hash)`                                                                     | 100% | 直接调用；与 bcryptjs `$2a$10$…` 互认（验证方案与前缀事实见 §4.7.5）                          |
| R-06 | 独立 executable 子工程范式             | `skills/llm_channel_tokendance/cjpm.toml:1-25`（`output-type = "executable"` + `[target.x86_64-w64-mingw32.bin-dependencies]` 显式声明 stdx DLL）                                                | 100% | 照抄其 `cjpm.toml` 骨架作为 `installer/cjpm.toml` 模板                             |

### 1.3 需扩展（部分复用）

| 编号   | 需求面                         | 存量资产                                                                                                                                                                                                       | 复用度 | 必须扩展的点                                                                                                                                         |    |                                                                           |
| ---- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --- | ---------------------------------------------------------------------------------------------------------------------------------------------- | -- | ------------------------------------------------------------------------- |
| E-01 | M2 三级降级探测（版本命令→端口→进程）       | `std.process.executeWithOutput`（`…/functions/executewithoutput-…md:9-16`）；端口/进程手段沿用 nestJs 的 `netstat`/`tasklist` 命令形态（`research.md:48`）                                                                   | 部分  | 三级编排、超时回落、探测手段记录（`probe.method`）全部新建；`--truthful` 语义新建                                                                                         |    |                                                                           |
| E-02 | 子进程超时强杀（AC-035）             | `std.process.launch(…): SubProcess`（`…/process/index.md:31`）、`Process.pid/isAlive()/terminate(force!)`（`…/classes/process/index.md:14-24`）、`SubProcess.wait(timeout!)`（`…/classes/subprocess/index.md:19`） | 部分  | `executeWithOutput` **无 `timeout!`** → 必须自建 `launch + wait(timeout) + terminate(force:true) + 进程树兜底`；进程树终止在 Windows 上须额外 `taskkill /PID /T /F` |    |                                                                           |
| E-03 | M6 `.env` 解析与行级 in-place 更新 | 解析语义参考 `src/config/config.cj:41` 键名正则与「跳过注释/空行、首个 `=` 切分、剥成对引号」（`research.md:61`）                                                                                                                          | 部分  | installer 是独立工程，**不能 import `magic.config`**（宿主包为 `output-type = "static"`，`cjpm.toml:11`）→ 按同一语义在 installer 内重写解析器与写入器                        |    |                                                                           |
| E-04 | M1 静态向导三件套字节                | \`apps/web-admin/public/install.html                                                                                                                                                                   | js  | css`（`install.js`62818 字节，硬编码`<http://localhost:3000\`> 在 `:4`）                                                                                | 部分 | 字节原样搬入 `installer/assets/install/`；**禁止改动任何一行**（AC-028）；托管层与 `/` 根路径重定向新建 |
| E-05 | M7 进程治理                     | 进程查询沿用 `tasklist /FI "IMAGENAME eq <name>" /FO CSV`（`research.md:48`）；停止手段沿用 `taskkill` 命令形态                                                                                                               | 部分  | PID 文件化（`pid + imageName` 双字段）与交叉校验为**新建**；`taskkill /F /IM node.exe`（`research.md:57`）**必须删除**，改为 `/PID` 精确终止（AC-104）                         |    |                                                                           |

### 1.4 需新增（存量不适用）

| 编号   | 需求面                                                      | 为何存量不适用                                                                            | 新建位置（本设计）                                             |
| ---- | -------------------------------------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------- |
| N-01 | M5 原子安装：staging → rename → `previous/` 快照 → `--rollback` | runtime 仓内无任何安装/发布逻辑；npm 包侧仅 `downloadRuntime + tar.x`（`research.md:70-73`），无快照与回滚 | `installer/src/core/atomic.cj`                        |
| N-02 | M9 状态机 S0~S8 与断点续装                                       | nestJs 无状态文件概念，中断即从零重跑                                                             | `installer/src/core/state.cj` + `.install-state.json` |
| N-03 | M5 Windows 目标文件被占用时的延迟删除                                 | 仓内无先例；Windows 删除/重命名被占用文件必失败（ERROR_SHARING_VIOLATION）                              | `installer/src/core/winfs.cj` + `.installer-gc.json`  |
| N-04 | M11/M12 DevKit DK-1~DK-8 组件化安装与自检、S8 初始化编排               | 对应对象（SDK/stdx/源码树/sql 基线/知识库）在仓内是**源文件**，不是可安装组件；无任何安装器表达                          | `installer/src/services/devkit/`                      |
| N-05 | M13 机器可读契约（`--json`、七类退出码、`fix` 命令生成）                    | 仓内无统一 CLI 契约层                                                                      | `installer/src/cli/report.cj`                         |
| N-06 | M14 DK-3 源码获取：`git clone` 单路径 + 开发者自选目标目录                  | 仓内源码树是**源文件**不是可分发组件；且 git 不可用/地址不可达时必须**明确失败**，无既有表达      | `installer/src/services/devkit/install.cj`（§4.10.1.1） |
| N-07 | M15/M16 Seed 身份重绑定（SIC）与导出机制（SEP）                        | 基线 `sql/uctooDB.sql` 的身份列硬编码来源环境 uuid（293 处 / 18 组「表.列」），无占位符与主体清单机制 | `installer/src/services/seed/{identity,scanner,exporter,importer}.cj`（§4.10.5） |
| N-08 | M17 初始数据内容定档与脱敏                                          | `sql/uctooDB.sql` 只做过 99 处替换，无敏感列清单、无同步/派生档概念、无脱敏占位符协议             | `installer/src/services/seed/{policy,sanitizer}.cj`（§4.10.6） |
| N-09 | M18 流式进度契约（NDJSON）与运维能力归位（M2 + M3）                     | 仓内无流式进度契约；运维侧日志/环境能力在 runtime 侧确实缺失（N-5/N-6），且启停原理上不可由 runtime 自举 | `installer/src/cli/progress.cj` + `installer/src/serve/manage.cj` + **runtime 侧** `src/app/**`（§4.13，冻结区有限豁免） |

### 1.5 存量详细分析

**1.5.1 HTTP 栈的真实归属（重要事实修正）**

派单描述中提到「HTTP `libs/hyperion`」。取证结论：**`libs/hyperion` 是 TCP 通信框架，不是 HTTP 服务器**（`libs/hyperion/README.md:1` 原文："Hyperion: 一个支持自定义编解码器的TCP通信框架"；其组件为 `buffer/logadapter/objectpool/threadpool/transport`，`README.md:20-24`）。runtime 实际使用的 HTTP 栈是 **`libs/http_lib`**，证据：`src/app/core/server/HTTPServer.cj:4-6` 的 `import http_lib.server.{HttpServer as LibHttpServer, HttpServerConfig}` 与 `http_lib.router.{Router, Handler}`。

因此本设计以 **`http_lib`** 为 HTTP 基座（`hyperion` 仅作为 `http_lib` 的传递依赖被间接引入，不直接 import）。该事实修正写入 §11 防回退约束 R-01。

**1.5.2 宿主包不可复用（决定"重写而非引用"）**

根 `cjpm.toml:11` 的 `output-type = "static"`，且 `magic.app.*` 下的 `HTTPServer`（`src/app/core/server/HTTPServer.cj:16`）、`DatabaseConnection`（`src/app/core/database/DatabaseConnection.cj:31`）、`CORSMiddleware`（`src/app/middlewares/CORSMiddleware.cj`）均属宿主包。**独立子工程无法通过 path 依赖引入宿主包源码**（且红线禁止改 `src/app/`，AC-031）。故 §1.3 的 E-03/E-05 只能"照语义重写"，不能"照抄调用"。

**1.5.3 编译选项不继承（决定 installer 的 compile-option 写法）**

根 `cjpm.toml:35` 注释原文："path-dependency 不继承父级 compile-option，热路径依赖必须单独开优化"。且 `cjpm.toml:3-7` 记录了 `-O2` 是登录超时根因的修复项（bcrypt 在 `-O0` + 溢出检查下需 7~22 秒）。因此 `installer/cjpm.toml` **必须对每个依赖逐个显式声明 `-O2`**，且 `blowfish` 必须带 `--int-overflow=wrapping`（`cjpm.toml:39`），否则 AC-005（单次哈希 ≤3s）不可达。

**1.5.4 可复用资产清单（含取证）**

| 资产                                 | 取证位置                                                                                        | 本设计中用途                                                         |
| ---------------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `http_lib`（HTTP/CORS/静态）           | `cjpm.toml:45`；`src/router/cors.cj:23,37`；`src/server/file_server.cj:98`                    | M1 全部                                                          |
| `pgsql` 驱动                         | `cjpm.toml:31`；`libs/pgsql-driver/src/driver.cj:17`、`datasource.cj:26`、`statement.cj:83,94` | M8、M12 的 I2/I3/I5                                              |
| `pgsql.sha256`                     | `libs/pgsql-driver/src/crypto.cj:149` `public func sha256(data: Array<Byte>): Array<Byte>`  | DK-1 SDK 包的 SHA256 校验（AC-140），**无需再引入第三方哈希库**                  |
| `blowfish`（Bcrypt）                 | `cjpm.toml:39`；`libs/blowfish-cj/src/bcrypt.cj:221,229`                                     | M8 口令哈希与回读自校验                                                  |
| `json4cj`                          | `cjpm.toml:40`                                                                              | 17 端点响应体与 `.install-state.json` 序列化                            |
| `logcj`                            | `cjpm.toml:30`                                                                              | 诊断日志（走 stderr，AC-019）                                          |
| `jinguissl`                        | `cjpm.toml:48`（由 `http_lib` 传递依赖）                                                           | 不直接使用；出包时需注意其 stdx DLL 依赖                                      |
| `cangjie-stdx-windows-x64-1.1.3.1` | `skills/llm_channel_tokendance/cjpm.toml:23-24`                                             | `[target.x86_64-w64-mingw32.bin-dependencies]` 的 `path-option` |
| `.env` 语义                          | `src/config/config.cj:41`；`research.md:61,62`                                               | M6 读写实现的语义对齐基准                                                 |

**1.5.5 不予复刻的既有行为（逐条）**

| 既有行为                                                | 取证                                          | 处置                                                          |
| --------------------------------------------------- | ------------------------------------------- | ----------------------------------------------------------- |
| `create-admin` 假路径（返回 `admin-<ts>` 不落库）             | `research.md:54`；`setup.service.ts:541-551` | **删除**，只留真路径（闸口决议② = REQ-RNI-034）                            |
| `test-config` 三级兜底无条件成功                             | `research.md:51`（`:320-324`）                | 默认保留不阻断语义 + 附 `probe{}` 真实字段；`--truthful` 下不可达即非 200（REQ-RNI-014 / AC-064~066）；上游红线为 spec §1.4.9「不提供假成功」 |
| `service-status` 随机指标                               | `research.md:52`（`:344-347`）                | 默认复刻、`--truthful-metrics` 给真实采样（REQ-RNI-015 / AC-067~068）  |
| `getLogs` 无日志时伪造两条                                  | `research.md:53`（`:473-488`）                | 默认返回空数组、`--legacy-fake-logs` 可复刻并标记 `synthetic:true`（REQ-RNI-016 / AC-069~070） |
| `generate-ssl` 伪 PEM 降级                             | `research.md:63`；`setup.service.ts:1127`    | **不予复刻**，仅 openssl 单路径，缺失即报错+指引（REQ-RNI-028 / AC-096~098）；上游红线同为 spec §1.4.9 |
| `stop/restart-runtime` 的 `taskkill /F /IM node.exe` | `research.md:57,58`（`:598`、`:622-627`）      | **不予复刻**，改 PID 文件 + 进程名交叉校验 + `taskkill /PID`（REQ-RNI-031~032 / AC-103~105） |

---

## 2. 设计概述

### 2.1 设计目标

1. **G-1 契约等价替换**：以单二进制 `ucInstaller.exe` 替换 `apps/web-admin/nestJs`，17 条端点契约逐字段兼容，`install.js` 与 4 个 Vue 组件零改动（AC-025/028）。
2. **G-2 零 Node 依赖交付**：交付物不依赖 Node 运行时与 `node_modules`（AC-033）；`start-installer.bat` 不再执行任何 `pnpm install`。
3. **G-3 可验证的成功**：任何步骤缺乏成功证据即返回非成功（AC-012）；三处既有"假成功"逐条给出默认语义与真实语义开关（闸口决议⑥）。
4. **G-4 原子与可回滚**：staging → 校验 → 一次性切换 → `previous/` 快照 → `--rollback`（AC-007/009）。
5. **G-5 断点续装**：S0~S8 每步完成即落盘，中断重启从最后完成态继续（AC-008/122）。
6. **G-6 进程治理零误杀**：PID 文件 + 进程名交叉校验 + `/PID` 精确终止（AC-011/104）。
7. **G-7 面向二次开发者可延伸**：S7/S8 提供 DK-1~DK-8 组件化安装与初始化，且红线（AI 不跑 `cjpm build`）被显式产品化为「人工执行项 + 判据」（AC-154）。
8. **G-8 机器可读**：所有检查类能力提供 `--json` + 七类稳定退出码 + 可执行 `fix` 命令（AC-162~165）。

### 2.2 设计原则

| 原则            | 具体约束                                                                              |
| ------------- | --------------------------------------------------------------------------------- |
| **契约优先，语义次之** | 路径、方法、字段形状、特殊状态码（404/500）严格对齐 nestJs；内部语义可改为真实实现                                  |
| **宿主冻结**      | 不改 `src/app/` 任何文件；不改根 `cjpm.toml` 的 `output-type` 与 `compile-option`（AC-031/032） |
| **子工程自治**     | `installer/` 为独立 executable 工程，可脱离根工程单独 `cjpm build`                              |
| **证据驱动**      | 所有"成功"结论必须来自可观测证据（退出码 + 产物存在 + 内容校验 + 回读），不来自"命令没报错"                              |
| **通道分离**      | 诊断一律 stderr（AC-019/165），stdout 仅供机器可读结果独占（为 Stage B L3 stdio RPC 留通路，AC-034）      |
| **降级显式**      | 任何降级（提权失败、工具缺失、介质回退）必须在响应与状态文件中留痕，不得静默成功                                          |
| **不代用户提权/编译** | 需管理员、需授权、需编译的动作一律转为「人工执行清单 + 判据」                                                  |

### 2.3 技术选型

| 组件      | 技术选型                                                                             | 说明与取证                                                                                                                           |
| ------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 编程语言    | 仓颉 1.1.3                                                                         | `cjc-version = "1.1.3"`（`cjpm.toml:2`；`skills/llm_channel_tokendance/cjpm.toml:2`）                                              |
| HTTP 框架 | `libs/http_lib`（HTTP/1.1 + HTTP/2 客户端与服务器）                                       | `cjpm.toml:45`；`src/app/core/server/HTTPServer.cj:4-6` 的 import 事实。**非** `hyperion`（后者是 TCP 框架，`libs/hyperion/README.md:1`）     |
| CORS    | `http_lib.router.cors.corsMiddleware` + `CorsConfig`                             | `libs/http_lib/src/router/cors.cj:23,37`，默认 `allowOrigins=["*"]`                                                                |
| 静态托管    | `http_lib.server.file_server.serveStatic`                                        | `libs/http_lib/src/server/file_server.cj:98`                                                                                    |
| 序列化     | `libs/json4cj` + `libs/kaca_json`（http_lib 传递）                                   | `cjpm.toml:40`                                                                                                                  |
| 数据库访问   | `libs/pgsql-driver` 直连（`PgDatasource`/`PgStatement`）                             | `cjpm.toml:31`；`src/datasource.cj:26`、`src/statement.cj:83,94`                                                                  |
| 口令哈希    | `libs/blowfish-cj` `Bcrypt.hash(cost: 10)`                                       | `cjpm.toml:39`；`src/bcrypt.cj:221`                                                                                              |
| 摘要      | `pgsql.sha256`（`Array<Byte>` → `Array<Byte>`）                                    | `libs/pgsql-driver/src/crypto.cj:149`，用于 SDK 包 SHA256 校验                                                                        |
| 日志      | `libs/logcj` + 自写 stderr 通道封装                                                    | `cjpm.toml:30`                                                                                                                  |
| 子进程     | `std.process.launch` / `Process.terminate(force!)` / `SubProcess.wait(timeout!)` | `skills/CangjieSkills/references/api/std/process/index.md:31`、`classes/process/index.md:14-24`、`classes/subprocess/index.md:19` |
| 目标平台    | Windows x64（`x86_64-w64-mingw32`）                                                | spec §1.4.7                                                                                                                     |
| 构建方式    | 人工在独立终端 `cjpm build`；AI 不执行（AC-029）                                              | —                                                                                                                               |

---

## 3. 系统架构与模块分层

> 本章为 v1.7 复核补齐：此前文档自 §2.3 直接跳至 §4，缺少"整体长什么样"的锚点，导致 §4 的关键设计点之间没有归属关系。本章只做**分层与职责划分**，具体实现对口 §4。

### 3.1 分层结构

```
┌─────────────────────────────────────────────────────────────┐
│ 消费方（三类，research-deployment.md §三）                        │
│   ① 人：install.html/js（硬编码 :3000） ② 脚本/CI：CLI --json   │
│   ③ 宿主进程（PC Electron/图形外壳）：CLI --progress=ndjson     │
└───────────────┬─────────────────────────────────────────────┘
                │
┌───────────────▼─────────────────────────────────────────────┐
│ 接入层                                                        │
│   http/   ── :3000 引导服务 + 17 端点（双前缀）+ 静态托管（§4.2） │
│   cli/    ── args / report / progress：--json 与 NDJSON（§4.11、§4.13）│
└───────────────┬─────────────────────────────────────────────┘
                │
┌───────────────▼─────────────────────────────────────────────┐
│ 编排层  core/orchestrator ── S0~S8 状态机 + 断点续装 + 自退役（§4.6）│
│        core/state        ── .install-state.json（原子写）      │
└───────────────┬─────────────────────────────────────────────┘
                │
┌───────────────▼─────────────────────────────────────────────┐
│ 服务层  services/                                             │
│   db（直连 PG） bcrypt_admin（$2a$ 归一） envfile（行级 in-place） │
│   ssl（openssl 单路径） media（离线介质） download（SDK 引导）      │
│   devkit/*（DK-1~DK-8 + I1~I9） seed/*（导出/脱敏/身份/导入）     │
└───────────────┬─────────────────────────────────────────────┘
                │
┌───────────────▼─────────────────────────────────────────────┐
│ 平台层  platform/（与业务无关的 OS 能力，唯一出口）                  │
│   subprocess_timeout（超时强杀） process_table（进程表）          │
│   envvars（环境变量/PATH） net（端口与连通性）                    │
│   core/{paths,atomic,winfs,probe}（路径/原子落地/占用文件/三级降级）│
└─────────────────────────────────────────────────────────────┘
```

### 3.2 分层铁律

1. **平台层是子进程与环境操作的唯一出口**：任何 `launch` / `taskkill` / `setx` / `netstat` 调用只能出现在 `platform/` 与 `core/`，业务层不得自起子进程（否则 R-04/R-05/R-06 无法用 grep 判据守住）。
2. **接入层不持有业务状态**：`http/handlers/*` 与 `cli/*` 只做参数校验与序列化，状态一律经 `core/state.cj`。
3. **服务层不直接写 stdout**：诊断走 `util/log.cj`（stderr），机器可读结果走 `cli/report.cj` / `cli/progress.cj`（stdout），二者不得混用（R-13 / AC-019 / AC-165 / AC-264）。
4. **跨工程改动单独成层**：M18 的 runtime 侧改动落在**另一个子工程** `src/app/`，属冻结区有限豁免（R-40），与 installer 分层不交叉。

### 3.3 模块 ↔ 需求能力面对照

| 模块（目录）                 | 覆盖的 spec 能力面                  | 详细设计位置                     |
| --------------------- | ---------------------------- | -------------------------- |
| `cli/`                | M13、M18（流式进度）                | §4.11、§4.13                |
| `http/`               | M1、M2、M3、M4、M7、M8、M11（端点）     | §4.2                       |
| `core/`               | M5、M9、M10、M2（探测）             | §4.3~§4.6                  |
| `services/`（非 devkit/seed） | M3、M6、M8                    | §4.7~§4.9                  |
| `services/devkit/`    | M11、M12、**M14**             | §4.10、§4.10.1.1            |
| `services/seed/`      | **M15、M16、M17**             | §4.10.5、§4.10.6            |
| `serve/`              | **M18（M3 启停管控）**            | §4.13                      |
| *runtime 侧* `src/app/` | **M18（M2 自述能力，冻结区豁免）**      | §4.13                      |
| `util/`               | 横切（日志、JSON、脱敏）              | §4.1                       |

---

## 4. 详细设计

### 4.1 子工程结构与构建配置（关键设计点 1）

#### 4.1.1 目录结构

```
apps/agentskills-runtime/
├── installer/                            ← 本期新增（唯一新建工程根）
│   ├── cjpm.toml
│   ├── assets/install/{install.html, install.js, install.css}
│   ├── src/
│   │   ├── main.cj
│   │   ├── cli/{args.cj, report.cj}
│   │   ├── http/
│   │   │   ├── bootstrap.cj
│   │   │   ├── routes.cj
│   │   │   ├── static_site.cj
│   │   │   └── handlers/{env.cj, config.cj, status.cj, runtime.cj,
│   │   │                 admin.cj, envfile.cj, ssl.cj, process.cj, devkit.cj}
│   │   ├── core/{state.cj, atomic.cj, winfs.cj, probe.cj, paths.cj, orchestrator.cj}
│   │   ├── platform/{subprocess_timeout.cj, process_table.cj, envvars.cj, net.cj}
│   │   ├── services/{db.cj, bcrypt_admin.cj, envfile_service.cj, ssl_service.cj,
│   │   │             media.cj, download.cj}
│   │   │   └── devkit/{registry.cj, install.cj, verify.cj, init.cj}
│   │   └── util/{log.cj, redact.cj, json_out.cj}
│   └── target/                            ← 构建产出（gitignore）
└── cjpm.toml                              ← **只读引用，不改**
```

#### 4.1.2 `installer/cjpm.toml` 关键字段

```toml
[package]
  cjc-version = "1.1.3"
  name = "uc_installer"
  version = "1.0.0"
  description = "AgentSkills Runtime 原生安装引导器（独立 executable）"
  output-type = "executable"          # 照抄 skills/llm_channel_tokendance/cjpm.toml:7
  src-dir = "src"
  target-dir = "target"
  # -O2 不可省：bcrypt 单次哈希在 -O0 + 溢出检查下需 7~22s（根 cjpm.toml:3-7 的登录超时根因）
  compile-option = "-O2 --dy-std -Woff all -Woff unused"
  link-option = ""

[dependencies]
  # path-dependency 不继承父级 compile-option（根 cjpm.toml:35），热路径依赖逐个显式开 -O2
  http_lib    = { path = "../libs/http_lib",     output-type = "static", compile-option = "-O2 -Woff unused" }
  kaca_json   = { path = "../libs/kaca_json",    output-type = "static" }
  json4cj     = { path = "../libs/json4cj",      compile-option = "-O2 -Woff unused" }
  logcj       = { path = "../libs/logcj",        compile-option = "-O2 -Woff unused" }
  pgsql       = { path = "../libs/pgsql-driver", compile-option = "-O2 -Woff unused" }
  # --int-overflow=wrapping 与根工程保持一致（根 cjpm.toml:39），否则 bcrypt 超 3s（AC-005）
  blowfish    = { path = "../libs/blowfish-cj",  compile-option = "-O2 --int-overflow=wrapping -Woff unused" }
  jinguissl   = { path = "../libs/jinguissl",    output-type = "static" }
  jinguissl_core = { path = "../libs/jinguissl_core", output-type = "static" }
  compress4cj = { path = "../libs/compress4cj",  output-type = "static" }
  quic_cj     = { path = "../libs/quic_cj",      output-type = "static" }
  kaca_cookies= { path = "../libs/kaca_cookies", output-type = "static" }

# stdx DLL 运行时定位。缺这段编译能过但运行时起不来（skills/llm_channel_tokendance/cjpm.toml:20-24）
[target.x86_64-w64-mingw32.bin-dependencies]
  path-option = ["../libs/cangjie-stdx-windows-x64-1.1.3.1/windows_x86_64_cjnative/dynamic/stdx"]
```

> **红线自证**：本文件为**新建**，根 `cjpm.toml` 的 `output-type`（`:11` = `static`）与 `compile-option`（`:7`）保持原值（AC-032）；不对任何既有依赖追加或修改 `compile-option`（AC-030）——上表中的 `compile-option` 只作用于 installer 自己的依赖声明，不回写根工程。

#### 4.1.3 `main.cj` 骨架（可独立于根工程构建）

```cangjie
package ucinstaller

import std.env.*
import std.fs.*
import ucinstaller.cli.{Args, Report}
import ucinstaller.core.{InstallPaths, StateStore, Orchestrator}
import ucinstaller.http.Bootstrap
import ucinstaller.util.{Diag, Redact}
import ucinstaller.platform.Net

main(args: Array<String>): Int64 {
    // 1. 诊断通道先就位：一律 stderr，stdout 留给 --json（AC-019/165）
    Diag.init(stderrOnly: true)

    // 2. 参数解析；非法即以退出码 2 结束并打印用法（AC-163）
    let a = match (Args.parse(args)) {
        case Ok(v) => v
        case Err(e) => { Diag.error(e); print(Args.usage()); return 2 }
    }

    // 3. 路径与状态（断点续装的入口）
    let paths = InstallPaths.resolve(installRoot: a.installRoot)
    let state = StateStore.open(paths.stateFile)              // 损坏即备份 + 从 S0 重来（AC-125）

    // 4. 独占端口探测：被占用即非零退出并报告占用进程（AC-039）
    if (a.mode != Mode.Cli && !a.noServe) {
        match (Net.probePortOccupant(a.port)) {
            case Some(o) => { Diag.error("端口 ${a.port} 被 ${o.image}(PID ${o.pid}) 占用");
                              Report.portConflict(a.port, o).emit(a.json); return 1 }
            case None => ()
        }
    }

    // 5. 模式分派
    let exit = match (a.mode) {
        case Mode.Rollback => Orchestrator.rollback(paths, state, a.json)
        case Mode.Verify   => Orchestrator.verify(paths, state, a.withDevkit, a.json)
        case Mode.Devkit   => Orchestrator.runDevkit(paths, state, a.withDevkit, a.sdkPath, a.json)
        case Mode.Install  => Orchestrator.run(paths, state, a, a.json)
        case Mode.Serve    => { Bootstrap.serve(paths, state, a); 0 }   // 阻塞；退役时自行退出
    }
    return exit
}
```

> **可独立构建性**：`installer/` 的依赖全部指向 `../libs/*` 与 `std`，不含任何 `magic.*` 宿主包，因此 `cd installer && cjpm build` 可在不构建根工程的前提下完成（与 `skills/llm_channel_tokendance/` 同构，其 `cjpm.toml:14-18` 亦只依赖 `../libs/*`）。

### 4.2 HTTP 引导服务：起 :3000、17 端点路由、静态托管、`/healthCheck`、CORS `*`（关键设计点 2）

#### 4.2.1 启动时序（冷启动 ≤3s，AC-006）

1. `Diag.init` → 2. `Args.parse` → 3. `InstallPaths.resolve` + `StateStore.open`（均为本地文件，毫秒级）
2. `Net.probePortOccupant(port)`（一次 `TcpServerSocket` 试绑）→ 5. 路由注册 → 6. `HttpServer.listenAndServe(host, port)`  
   全流程无网络、无子进程、无 DB 连接，常驻内存主要由 http_lib 的连接缓冲池构成，远低于 200 MB（AC-004）。

#### 4.2.2 路由注册（双前缀，AC-046/047）

```cangjie
// http/routes.cj
public func buildRouter(paths: InstallPaths, ctx: AppContext): Router {
    let r = Router()

    // CORS：默认 allowOrigins=["*"]，已内置 OPTIONS 预检（libs/http_lib/src/router/cors.cj:23,37）
    let cors = CorsConfig()
    cors.allowHeaders = ["Content-Type", "Authorization", "Accept", "X-Requested-With"]
    r.use(corsMiddleware(cors))

    // 1) 健康契约：响应体严格等于 success，无引号/无换行/无 JSON 包装（AC-023/036/037）
    r.get("/healthCheck", { _ => HttpResponse.text(HttpStatus.OK, "success") })

    // 2) 静态向导（AC-043~045）：/ 与 /install.html 均返回主文档
    let site = serveStatic(paths.assetsDir, config: FileServerConfig())
    r.get("/", site); r.get("/install.html", site)
    r.get("/install.js", site); r.get("/install.css", site)

    // 3) 17 条 setup 端点：同时挂载 /api/setup/<x> 与 /setup/<x>
    let table = setupTable(ctx)                 // Array<(HttpMethod, String, Handler)>
    for ((m, name, h) in table) {
        r.handle(m, "/api/setup/" + name, h)
        r.handle(m, "/setup/" + name, h)
    }

    // 4) DevKit 三端点（M11/M12）
    r.get ("/api/setup/devkit/components", DevkitHandlers.components(ctx))
    r.post("/api/setup/devkit/install",    DevkitHandlers.install(ctx))
    r.get ("/api/setup/devkit/verify",     DevkitHandlers.verify(ctx))
    // …同表再挂一遍 /setup/devkit/*

    return r
}
```


`HttpServer` 组装（签名取证：`libs/http_lib/src/server/server.cj:112-130`、`listenAndServe(host, port)`）：

```cangjie
let cfg = HttpServerConfig()
cfg.concurrent = true                 // 每连接独立协程
cfg.readTimeout = Duration.second * 30
cfg.serverName = "ucInstaller/1.0"
let server = HttpServer(handler: router.handler(), config: cfg)   // Router.handler(): router.cj:346
server.listenAndServe("127.0.0.1", UInt16(port))                  // 默认仅回环（AC-016）
```

端口标记文件：监听成功后写 `paths.portFile`（`<installRoot>/.installer-port`），内容为实际端口号（AC-040）。

#### 4.2.3 端点表与内部服务拓扑（关键设计点 6）

| #     | 方法       | 路径（双前缀）                                     | Handler               | 调用的内部服务                                                                        | 关键契约                                                                            |
| ----- | -------- | ------------------------------------------- | --------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| 1     | GET      | `/healthCheck`                              | 内联                    | 无                                                                              | 纯文本 `success`                                                                   |
| 2     | GET      | `/setup/check-environment`                  | `handlers/env.cj`     | `services/envcheck.cj` → `platform/probe.cj` → `platform/subprocess_timeout.cj`、`net.cj`、`process_table.cj` | `{code:200,data:[3 项],message:'环境检测完成'}`；单项 ≤5s，异常仍 200；与 `check-environment` CLI 共用同一实现（§4.2.4） |
| 3     | POST     | `/setup/save-config`                        | `handlers/config.cj`  | `core/state.cj`（`<cwd>/config.json` 落盘 + 内存刷新）                                 | 缺必填 → 400；**不写 runtime `.env`**（AC-060）                                         |
| 4     | GET      | `/setup/load-config`                        | `handlers/config.cj`  | `core/state.cj`                                                                | 读失败仍 200 + 内存副本（AC-061）                                                         |
| 5     | POST     | `/setup/test-config`                        | `handlers/config.cj`  | `services/db.cj`（psql `-c "SELECT 1"`）+ `net.cj`（端口）                           | 默认 200 + `probe{method,reachable,detail}`；`--truthful` 下不可达即非 200               |
| 6     | GET      | `/setup/service-status`                     | `handlers/status.cj`  | `process_table.cj`；`--truthful-metrics` 下采样                                    | `{code:200,data:[{name,status,cpu,memory,uptime}]}`                             |
| 7     | GET      | `/setup/logs`                               | `handlers/status.cj`  | `util/log.cj`（5 来源聚合 + 三种时间戳 + `slice(-100)`）                                  | 默认空数组；`--legacy-fake-logs` 复刻两条并标 `synthetic:true`                              |
| 8     | POST     | `/setup/create-admin`                       | `handlers/admin.cj`   | `services/db.cj` + `services/bcrypt_admin.cj`                                  | **真路径**；`{code:200,message,user:{id,name,username,email}}`                      |
| 9     | POST     | `/setup/start-runtime`                      | `handlers/process.cj` | `process_table.cj`                                                             | 未装 → 500；成功返回 `{code:200,message,pid,path}` 并写 PID 文件                           |
| 10    | POST     | `/setup/stop-runtime`                       | `handlers/process.cj` | `process_table.cj`                                                             | 仅 `/PID` 精确终止 + 镜像名校验                                                           |
| 11    | POST     | `/setup/restart-runtime`                    | `handlers/process.cj` | `process_table.cj`（优先执行 `<installRoot>/start-runtime.bat`）                     | 先精确停，再起                                                                         |
| 12    | GET      | `/setup/check-runtime`                      | `handlers/runtime.cj` | `core/paths.cj` + `release/VERSION` 解析                                         | **裸对象无 `code`**：`{installed,path,runtimeDir,releaseDir,version,hasEnv,message}` |
| 13    | POST     | `/setup/install-runtime`                    | `handlers/runtime.cj` | `services/media.cj` → `core/atomic.cj`、`core/winfs.cj`                         | 幂等；本地优先；标注 `source`                                                             |
| 14    | GET      | `/setup/read-runtime-env`                   | `handlers/envfile.cj` | `services/envfile_service.cj`                                                  | 未装 → 500；已装无 `.env` → **404**；成功 `{code:200,config,dbConfig,envPath}`           |
| 15    | POST     | `/setup/save-runtime-env`                   | `handlers/envfile.cj` | `services/envfile_service.cj`                                                  | 行级 in-place；非法键名 → 400                                                          |
| 16    | POST     | `/setup/generate-ssl`                       | `handlers/ssl.cj`     | `services/ssl_service.cj`（openssl 单路径）                                         | 失败即明确错误 + 指引，**不写任何证书文件**                                                       |
| 17    | POST     | `/setup/save-ssl`                           | `handlers/ssl.cj`     | `services/ssl_service.cj`                                                      | 覆盖前备份，失败用备份恢复                                                                   |
| 18~20 | GET/POST | `/setup/devkit/{components,install,verify}` | `handlers/devkit.cj`  | `services/devkit/*`                                                            | `{id,status,actual,expected,fix}`                                               |

> 说明：spec 口径的「17 条端点契约」= nestJs 的 16 条路由声明 + `create-admin` 的两条实现（本期归一为真路径，见 `spec.md` §1.3 第 1 条）。归一后唯一路由 **16 条**，加上本期新增的 DevKit 三端点，实际挂载 **19 条 × 2 前缀**。
>
> **端点总数口径对照**（避免三处文档各说各话）：nestJs 路由声明 **16** 条 → spec 称「17 条端点契约」（含 `create-admin` 双实现）→ 归一后唯一路由 **16** 条 + DevKit **3** 条 = 实际挂载 **19** 条 × 双前缀。前端实际消费：install.js **13** 类、4 个 Vue 组件 **6** 类、`setup.vue` **2** 类（启停），合计去重 **15** 类 + `/healthCheck`（见 `spec.md` §1.2）。

#### 4.2.4 能力复用分层：CLI 为基础，HTTP 为封装（关键设计点 14）

> **补齐说明（v1.8）**：同一项能力若分别在命令行与 HTTP 端点各写一份，必然出现「命令行一套口径、网页另一套口径」。本节确立分层，并以 `check-environment` 为首个落地样例。**本节是 R-42（环境探测唯一实现，禁止两套）在安装器内的落地条款**：R-42 原只约束「运维端点不得另写一套」，此处把约束扩到「命令行 / HTTP 两条通道也不得各写一套」——同一轮探测在两条通道上的 `reachable` / `method` 必须一致。

**范式参照（runtime 侧已验证的做法）**：`crudgen` 既可由命令行直接调用，也可经 API 供 web 端调用——

| 层        | runtime 侧参照                                                        | 安装器对应                                   |
| -------- | ------------------------------------------------------------------ | --------------------------------------- |
| 命令行入口    | `src/app/tools/crudgen/crudgen.cj`                                  | `src/cli/env_check.cj`（`check-environment`） |
| **共享底座** | `src/app/services/tool/CrudGenService.cj`                           | `src/services/envcheck.cj`              |
| HTTP 封装  | `src/app/controllers/uctoo/db_info/DbInfoController.cj`（供 web 端调用） | `src/http/handlers/env.cj`              |

即：**能力只写一份（Service），命令行直接调，HTTP 再包一层**。

**三条硬约束**：

1. **依赖清单唯一**：`environmentTargets()` 是唯一事实源。CLI 与 HTTP 都从 `checkEnvironment()` 取数，禁止任一通道自行维护一份依赖列表（否则 AC-002 的「三项」在两条通道上会漂移）。
2. **HTTP 只做渲染，不做判断**：`handlers/env.cj` 只负责把 `EnvCheckItem` 映射成 `{name,reachable,method,version,detail}` 并装信封，可达性判定与降级手段的记录全部由底座负责。
3. **报告形态各自合规**：CLI 出 §4.11.1 的 `items[]{id,status,actual,expected,fix}`（AC-164 要求非 pass 项必带 `fix`）；HTTP 出 `{code,data,message}` 信封。**形态不同、事实同源**——同一轮探测在两条通道上的 `reachable` / `method` 必须一致。

**底座为什么放在 `services` 而不是 `core`**（包依赖约束，非风格偏好）：包依赖边里已存在 `core → cli`（`core/ctx.cj` 要用 `cli.CliArgs`），而 CLI 子命令必须能调到底座——若底座在 `core`，`cli` 反向 import `core` 即成环，仓颉拒绝构建。`services` 只依赖 `platform` / `util`，`cli` 与 `http.handlers` 都够得着且不成环。同理，三级探测原语从 `core/probe.cj` 下沉到 `platform/probe.cj`（`platform` 不依赖任何 `uc_installer.*` 包，是唯一能被所有上层安全引用的位置）。

**必填 / 非必填的判定口径**：`EnvTarget.required` 区分阻断与降级。必填项不可达 → CLI `status=fail`、`exitCode=EXIT_ENV(3)`；非必填项不可达 → `status=degraded` 且 `degraded=true`，`exitCode` 仍为 0，但**仍给 `fix`**——不静默跳过，也不冒充通过。当前 `node` 标为非必填，依据 AC-033（安装器自身是原生二进制，`start-installer.bat` 不得要求 Node/pnpm；Node 只被 DevKit 校验 DK-7 与服务监控用到）。

### 4.3 `subprocess_timeout.cj`：并发、超时强杀与 `environment!` 正确用法（关键设计点 3）

#### 4.3.1 约束取证

- `std.process.executeWithOutput(command, arguments, workingDirectory!, environment!, stdIn!, stdOut!, stdErr!)` —— **签名中没有 `timeout!`**（`skills/CangjieSkills/references/api/std/process/functions/executewithoutput-…md:9-16`）。因此"等待上限"必须自行实现。
- `launch(...)` 返回 `SubProcess`（`…/process/index.md:31`），`SubProcess.wait(timeout!: ?Duration = None): Int64`（`…/classes/subprocess/index.md:19`）—— 超时只结束等待，**不杀子进程**。
- `Process.pid: Int64`、`isAlive(): Bool`、`terminate(force!: Bool = false)`（`…/classes/process/index.md:14-24`）。
- `ProcessRedirect` 枚举含 `Discard` / `FromFile(File)` / `Inherit` / `Pipe`（`…/enums/processredirect/index.md:16-19`）。

#### 4.3.2 执行模型

```cangjie
public struct RunResult { let exitCode: Int64; let stdout: Array<Byte>; let stderr: Array<Byte>
                          let timedOut: Bool; let killedTree: Bool; let elapsed: Duration }

public func runCapped(cmd: String, args: Array<String>, cap!: Duration = Duration.second * 5,
                      cwd!: ?Path = None, env!: ?HashMap<String,String> = None): RunResult {
    // ① stdin 一律 Discard：杜绝 npx/inquirer 类命令等待 stdin 卡死（research.md:74 的现存隐患）
    //    大输出场景不使用 waitOutput()，改用 stdOutPipe/stdErrPipe 流式读取（契约见 executeWithOutput 文档"契约"段）
    let p = launch(cmd, args,
                   workingDirectory: cwd,
                   environment: env,
                   stdIn: ProcessRedirect.Discard,
                   stdOut: ProcessRedirect.Pipe,
                   stdErr: ProcessRedirect.Pipe)

    // ② 并发：每个探测项一个仓颉协程；check-environment 的三项并行，总时长上限 15s（AC-002）
    let code = p.wait(timeout: cap)
    if (code != TIMEOUT_SENTINEL) { return collect(p, code, timedOut: false) }

    // ③ 超时强杀：先温和终止，再强制，最后进程树兜底
    p.terminate(force: true)                                  // Process.terminate(force!)
    spawnKillTree(p.pid)                                      // taskkill /PID <pid> /T /F（Windows 进程树）
    return RunResult(exitCode: -1, stdout: [], stderr: [], timedOut: true, killedTree: true, elapsed: cap)
}
```

> **⚠️ 本段伪代码已按 cjc 1.1.3 实测订正（2026-10-08，T006 落地时核对）**
>
> 上面这段示意有三处与真实 API 不符，第四点是原设计遗漏，实现一律以订正为准：
>
> 1. **`p.wait(timeout: cap)` 超时是「抛 `TimeoutException`」，不是返回哨兵值。**
>    契约原文（`references/api/std/process/classes/subprocess/wait.md`）：
>    「timeout 值大于 Duration.Zero 时，阻塞等待子进程执行返回或**等待超时后抛出超时异常**」；
>    「异常：`TimeoutException` - 当等待超时，子进程未退出时，抛出异常」。
>    `TimeoutException <: Exception`，package = **`std.core`**（默认可见，无需 import）。
>    ⇒ `if (code != TIMEOUT_SENTINEL)` 这个分支不成立，必须改成 try-catch；
>    「哨兵值」只能由实现自己约定（落地时取 `WAIT_TIMEOUT_SENTINEL = -9`，
>    真实退出码不会是负值：正常退出 >= 0，被信号杀死时返回的是**信号编号**亦为正）。
> 2. **`environment: env` 不能直接传调用方给的 `?HashMap`。** 按 §4.3.3 红线，
>    必须先 `HashMap(getVariables())` 作基底再叠加 —— 直接把增量当整体环境会丢 PATH。
>    实测形参为 `environment!: ?Map<String, String>`，传 `HashMap` 会被自动装箱
>    （宿主实证：`ScriptExecutor.cj:34` 传的就是 `HashMap<String, String>`）。
> 3. **`RunResult(exitCode: ..., stdout: ...)` 这种带标签调用会报错。**
>    仓颉只有声明成 `p!: T` 的形参才是命名参数；`init` 若按位置参数声明就必须按位置调用，
>    带名会报 `invalid named arguments prefix`。要么把 init 形参写成 `exitCode!: Int64`，
>    要么调用时不带标签（落地实现采用后者）。
> 4. **【遗漏，且最重要】Pipe 模式必须在 `wait` 之前把管道交给独立线程排空，否则死锁。**
>    契约原文警告：「对于需要操作标准流的场景（Pipe 模式），使用者需要优先处理标准流，
>    **避免子进程标准流缓冲区满后调用本函数产生死锁**」。
>    机制：子进程输出写满管道缓冲区后阻塞 → 它永远不退出 → `wait` 的超时也救不回来。
>    ⇒ 落地实现用 `spawn { drainToArray(p.stdOutPipe) }`，stdout / stderr 各一个仓颉线程，
>    返回 `Future<Array<Byte>>`，再用 `get(Duration)` 有上限地收敛。
>
> 另注命名参数判据：`Future.get(timeout: Duration)` 的 timeout **不是**命名参数
> （签名里没有感叹号），只能按位置传 `get(cap)`；而 `wait(timeout!: ...)` 与
> `terminate(force!: ...)` 带感叹号，必须按名传。**有无感叹号是唯一判据**。

要点：

1. **并发但不无限**：`check-environment` 的三项探测各占一个协程并行；每单项 `cap = 5s`（AC-057），总上限 15s（AC-002）。使用一个 `Mutex`（可重入，有 `tryLock()`）保护结果收集容器。
2. **超时即视为该级失败**，回落到下一级探测手段，不向上抛（AC-049）。
3. **进程树兜底不可省**：`terminate` 只针对直接子进程；`psql`/`openssl`/`npx` 可能再拉孙进程。Windows 上用 `taskkill /PID <pid> /T /F`（`/T` = 终止进程树）。
4. **禁止以退出码 0 冒充成功**：成功判定必须叠加"产物存在 + 内容校验"（见 §4.8 的 openssl 判据）。

#### 4.3.3 `environment!` 的整体替换语义（红线）

`environment!` 传 `Some(map)` 时是**整体替换**子进程环境，而非增量合并（`executeWithOutput` 文档："指定子进程环境变量，默认继承当前进程环境变量"）。正确用法：

```cangjie
public func fullEnv(extra: HashMap<String,String>): HashMap<String,String> {
    let m = HashMap<String,String>(getVariables())   // 先取当前进程全部变量
    for ((k, v) in extra) { m[k] = v }               // 再叠加
    return m
}
// 用法：runCapped("psql", ["-c", "SELECT 1"], env: fullEnv({"PGPASSWORD": pwd}))
```

判据：任何调用 `launch/execute/executeWithOutput` 且携带 `environment` 的站点，都必须先 `HashMap(getVariables())`。漏一处即出现「子进程 PATH 丢失 → `where psql` 找不到」的隐蔽故障。此条写入 §11 防回退 R-04。

#### 4.3.4 避免交互式命令卡 stdin

- 所有外部命令统一 `stdIn: ProcessRedirect.Discard`，读 stdin 立即得 EOF。
- 对已知会交互的命令（npm 的 `install-runtime` 会 inquirer 询问，`research.md:74`）**一律不经由安装器执行**——安装器自己实现"已安装判定 + force 语义"，不复用该 CLI。
- 长输出命令（`psql -f sql/uctooDB.sql`）不用 `waitOutput()`（契约明确不建议），改 `stdOutPipe` 流式读取并同时写入诊断日志。

### 4.4 原子安装与 Windows 占用文件延迟删除（关键设计点 4）

#### 4.4.1 原子切换主流程

```
stage:  <installRoot>/.staging/<uuid>/           ← 介质在此完整落地并校验
  ├─ 校验：文件清单完整 + SHA256 + 关键产物存在（release/bin/agentskills-runtime.exe）
  └─ 失败 → 删除 .staging/<uuid>，目标目录保持安装前状态（AC-007/088）

snapshot: 若目标已存在 → rename(<releaseDir>, <installRoot>/previous/)
  └─ 仅保留最近一份快照（数据约束 §6.6.4）

switch:  rename(.staging/<uuid>/release, <releaseDir>)      ← 同卷 rename，原子
  └─ 成功后再写 .install-state.json 的 S3 完成标记（AC-084）

verify:  复核 releaseDir/bin/agentskills-runtime.exe 存在；
         保证 releaseDir/.env 存在（已存在则保留原内容，AC-089）
```

#### 4.4.2 Windows 目标文件被占用 —— 结论与具体做法

**结论**：Windows 下被占用的文件（正在执行的 `.exe`、已加载的 `.dll`）**无法删除也无法重命名**（ERROR_SHARING_VIOLATION / ERROR_ACCESS_DENIED）。因此安装器不能假设"先删后装"必然成功；正确做法&#x662F;**「先停进程 → 再 rename → 失败即登记延迟删除（GC 队列）+ 落地 `.pending` 待替换文件」**，把失败从"安装失败"降级为"延后完成"，并保证不留半装状态。

具体算法（`core/winfs.cj`）：

```
func replaceOrDefer(target: Path, staged: Path): ReplaceOutcome
  1. 若 target 不存在 → move(staged, target)；return Switched
  2. 尝试 move(target, <installRoot>/.trash/<ts>-<rand>)      // 先挪走，比删除更容易成功
     ├─ 成功 → move(staged, target)；把 .trash 条目加入 GC 删除队列；return Switched
     └─ 失败（异常）→ 进入步骤 3
  3. 占用诊断（子进程，cap 5s，stdin Discard）：
       powershell -NoProfile -Command
         "Get-Process | Where-Object { $_.Modules.FileName -eq '<target>' } | Select-Object -ExpandProperty Id"
     ├─ 命中 PID 且该 PID 在「本安装器 PID 文件」内（runtime/安装器自记录）
     │    → taskkill /PID <pid>（先温和）；轮询 `tasklist /FI "PID eq <pid>"` 最长 10s
     │    → 进程消失后重试步骤 2；仍失败 → 步骤 4
     └─ 命中 PID 但不属于本安装器记录 → **不杀**（AC-011），直接步骤 4
  4. 写 .pending：把 staged 落为 <target>.pending，并在 <installRoot>/.installer-gc.json 追加
       { "path": "<target>", "pending": "<target>.pending", "firstFailedAt": ISO8601,
         "attempts": 0, "reason": "sharing-violation", "holderPid": <pid|null> }
     return Deferred
  5. GC 时机（每次尝试 remove/move，成功即从队列移除）：
       a. 安装器进程启动时（含 CLI 任意子命令）
       b. 每次原子切换之前
       c. S6 之后每 5s 一轮，单轮上限 20 次
       d. 下一次安装器运行
     GC 成功执行：<target>.pending → replace <target>；随后删除 <target>（若仍占用则保留到下轮）
  6. 超期策略：firstFailedAt 超过 24h 或 attempts > 20 → 只告警不阻断，
     并在 `devkit verify --json` 中输出该项的 fix 命令（见下），状态文件对应步骤标 failed
```

**fix 命令生成示例**：

```
taskkill /PID <holderPid> /F & ucInstaller.exe install --resume
:: 或（占用者非本安装器所属时）：
::  重启机器后重新运行 ucInstaller.exe install --resume，安装器将在 GC 阶段完成 .pending 替换
```

**不采用的方案及理由**：

- `MoveFileEx(MOVEFILE_DELAY_UNTIL_REBOOT)`：需写 `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations`，属系统级写操作且需管理员提权，违反 spec §1.4.8「不代用户完成需人工介入的动作」。改为输出人工命令清单。
- 直接 `taskkill /F /IM <image>` 批量杀：违反 AC-011/104，禁止。

**目录级占用**：`previous/` 快照的目录 rename 若失败，退化为逐文件按上述算法处理，并在状态文件 `snapshot.exists` 如实标记（数据约束 §6.1.6：无快照不得声称可回滚）。

### 4.5 `.install-state.json` schema 与断点续装（关键设计点 5）

#### 4.5.1 Schema

```json
{
  "schemaVersion": 3,
  "installerVersion": "1.0.0",
  "mode": "enduser",
  "installRoot": "D:\\...\\apps\\agentskills-runtime",
  "releaseDir":  "D:\\...\\apps\\agentskills-runtime\\release",
  "currentStep": "S3",
  "port": 3000,
  "runtimeVersion": "0.0.29",
  "steps": {
    "S0": { "status": "done",  "at": "2026-10-07T10:00:00+08:00",
            "evidence": { "nodejs": "v22.11.0", "postgresql": "16.2", "redis": "not-installed" } },
    "S1": { "status": "done",  "at": "...", "evidence": { "probe": { "method": "psql", "reachable": true } } },
    "S2": { "status": "skipped", "at": null },
    "S3": { "status": "running", "at": null, "evidence": { "mediaSource": "local" } },
    "S4": { "status": "pending", "at": null },
    "S5": { "status": "pending", "at": null },
    "S6": { "status": "pending", "at": null },
    "S7": { "status": "pending", "at": null },
    "S8": { "status": "pending", "at": null }
  },
  "devkit": "pending",
  "devkitComponents": {
    "DK-1": { "status": "installed", "at": "...", "actual": "cjc 1.1.3 (1.1.3)", "expected": "cjc --version 含 1.1.3" }
  },
  "mediaSource": "local",
  "snapshot": { "exists": true, "path": "previous/", "at": "..." },
  "corruption": { "recovered": false, "backupPath": null },
  "degraded": [
    { "id": "I8", "reason": "hosts 写入被拒绝（权限不足）", "fallback": "localhost + HTTP", "manualCmd": "..." }
  ]
}
```


**字段约束**（逐条对齐 spec §6.1）：

- `steps[*].status` 枚举：`pending | running | done | failed | skipped | rolledback`；`done` 必须有 `at`，非 `done` 的 `at` 必须为 `null`（§6.1.7）。
- `mode` 取值 `enduser | dev`（§6.1.3）。
- `devkit` 取值 `pending | installed | skipped`；`skipped` 时 `devkitComponents` 必须为空（§6.1.4）。
- `mediaSource` 取值 `local | remote`；`--offline` 下不得出现 `remote`（§6.1.5）。
- `snapshot.exists=false` 时不得声称可回滚（§6.1.6）。
- `corruption.recovered=true` 时必须给出 `backupPath`（§6.1.8）。

#### 4.5.2 写入原子性（AC-010）

```
write:  <installRoot>/.install-state.json.tmp  →  fsync →  rename(tmp, state.json)
```

读者永远看到完整内容；`rename` 在同卷上是原子操作。每次状态变更走同一函数，禁止分多次 write。

#### 4.5.3 版本迁移

| 迁移                    | 规则                                                        |
| --------------------- | --------------------------------------------------------- |
| v1 → v2               | 新增 `mode` 字段，缺失时按 `enduser` 补；`devkitComponents` 缺失补 `{}` |
| v2 → v3               | 新增 `degraded[]`；`steps` 中缺失的 Sn 补 `pending`               |
| 未知/更高 `schemaVersion` | 判为不可解析，进入损坏恢复流程（下条）                                       |

#### 4.5.4 损坏恢复（AC-125）

`StateStore.open()` 解析失败或 schema 不可识别 → 备份原文件到 `.install-state.corrupt-<ts>.json` → 从 S0 重新初始化 → 写 `corruption{recovered:true, backupPath}`，并在 stderr 记录损坏事实。已落地的安装产物**不删除**（禁止静默丢弃用户资产）。

#### 4.5.5 断点续装恢复逻辑

```
resume():
  st = StateStore.open()
  if (st.corruption.recovered) → 诊断提示 + 从 S0 开始
  last = 最大的满足 status==done 的 Sn 下标
  for n in last+1 .. 8:
      if (steps[S(n-1)].status != done && 闸口未过) → 停止并报未通过原因（AC-121）
      if (steps[Sn].status == done && !forceStep.contains(Sn)) → skip（已完成不重复，AC-123）
      else execute(Sn) → 立即持久化（AC-122）
```

**重复执行的幂等保证**（AC-124）：

- S3 介质落地：staging + rename，重复执行只覆盖同名产物，不产生重复目录；
- S4 `.env`：键级覆盖写，无重复条目；
- S5 管理员：先按 email/username 查重，命中即返回 400，不产生重复账号；
- S7 组件：每组件先判"已安装且自检通过"则跳过；
- S8 I2 导基线：增量脚本按名序幂等，禁 DROP（`research-devenv.md:188`）。

### 4.6 编排器与自退役（M9/M10）

- `core/orchestrator.cj` 持有步骤表 `[S0..S8]`，每步声明 `gate(): GateResult{ok, reason, fix}` 与 `run(): StepResult`。
- 闸口未通过即拒绝推进并给出具体原因与 `fix` 命令（AC-121、AC-164）。
- 自退役：S6 启动 runtime 后，每 2s 探测 `GET http://127.0.0.1:8080/api/v1/health`（`src/app/main.cj:698`），连续 3 次 200 标记"可退役"（AC-126）；`--auto-exit` 下以退出码 0 结束自身（AC-127）；退出时**不停止 runtime**、保留全部产物（AC-128）；若状态文件存在未完成步骤则优先提示不退出。

### 4.7 直连 PostgreSQL 写 `uctoo_user`（关键设计点 7）

#### 4.7.1 建连与执行

```cangjie
// services/db.cj（签名取证：libs/pgsql-driver/src/driver.cj:17,48；datasource.cj:26,61；statement.cj:41,64,83,94）
public class AdminRepo {
    private let ds: PgDatasource
    public init(host: String, port: UInt16, db: String, user: String, pwd: String) {
        registerDriver()                                  // 范式照抄 src/app/main.cj:144-153
        ds = PgDatasource(host, port, user, pwd, db)      // datasource.cj:26
    }
    public func withConn<T>(f: (Connection) -> T): T {
        let c = ds.connect(); try { f(c) } finally { c.close() }   // 异常也必须释放（spec §5.8.3 异常 3）
    }
}
```

连接参数来源：读 `releaseDir/.env`，从 `DATABASE_URL` 或 `orm_connectionUrl` 解析出 host/port/db/user/password（`research.md:61`；`parseDatabaseUrl` 语义）。解析不出 → 返回 500「无法读取数据库配置」，**不写库**（AC-118 前置）。

#### 4.7.2 写入契约（与 `setup.service.ts:1273-1278` 对齐）

```sql
INSERT INTO uctoo_user
  (name, username, email, password, auth_provider, status,
   created_at, updated_at, last_login_time)
VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
RETURNING id, name, username, email;
```

| 参数                 | 取值                             | 约束来源            |
| ------------------ | ------------------------------ | --------------- |
| `$1 name`          | 表单 `name`；未提供时取 `username`     | §6.2.1          |
| `$2 username`      | 表单 `username`，表内唯一             | §6.2.2          |
| `$3 email`         | 表单 `email`，基本邮箱形状，表内唯一         | §6.2.3          |
| `$4 password`      | `Bcrypt.hash(plain, cost: 10)` | §6.2.4 / AC-112 |
| `$5 auth_provider` | 常量 `0`                         | §6.2.5          |
| `$6 status`        | 常量 `1`                         | §6.2.6          |
| 三个时间               | `CURRENT_TIMESTAMP`            | §6.2.7          |

**未提及列一律不写**（头像、创建者、删除时间、最后登录 IP、remember_token、access_token、refresh_token 等），沿用数据库默认值（§6.2.8 / AC-117）。

#### 4.7.3 唯一性与返回体

- 先按 `email` 查重 → 命中返回 400「该邮箱已被注册」（AC-114）；
- 再按 `username` 查重 → 命中返回 400「该用户名已被使用」（AC-115）；
- 成功返回 `{code:200, message:'管理员账号创建成功', user:{id,name,username,email}}`，**`user` 与 `code` 同级**（依据 `nestJs/src/setup/setup.service.ts:1285-1294`；`install.js:1089` 只读 `code`/`message`，前端零改动）。
- 入参缺 email/username/password → 400「请填写完整的管理员账号信息」（AC-110）。服务端**不重复施加**前端强度规则（AC-111）。

#### 4.7.4 写后回读自校验（AC-118/119）

```
1. 用 RETURNING 的 id 执行 SELECT password FROM uctoo_user WHERE id = <id>
2. Bcrypt.verify(plain, stored)        // libs/blowfish-cj/src/bcrypt.cj:229
3. 回读不到行 或 verify 为 false → 返回 500 + 失败原因，S5 不得标 done
```

#### 4.7.5 bcrypt 与 bcryptjs 互认的验证方案（含一处事实偏差）

**取证事实**：`libs/blowfish-cj/src/bcrypt.cj:245` 的 `genSalt` 生成的前缀是 **`$2b$`**（源码原文 `var result = "\$2b\$"`），而 nestJs 侧 `bcryptjs.hash(password, 10)`（`setup.service.ts:1221`）生成的是 `$2a$10$`；AC-112 要求"哈希串以 `$2a$10$` 开头"。

**互认性判定**：`Bcrypt.verify` 只取前 29 字符作 salt 且不校验版本前缀（`bcrypt.cj:229-238`），因此仓颉侧可校验 bcryptjs 的 `$2a$` 哈希；bcryptjs 亦支持 `$2a$/$2b$/$2y$` 三种前缀。**结论：双向互认成立**，偏差仅在"输出前缀字面值"。

**验证方式（人工确认路径 G-F）**：

```
固定明文 P = "UcInstaller!Verify#2026"
① 仓颉侧：h1 = Bcrypt.hash(P, cost: 10)；断言 Bcrypt.verify(P, h1) == true
② Node 侧：h2 = require('bcryptjs').hashSync(P, 10)；断言 compareSync(P, h2) == true
③ 交叉：仓颉 Bcrypt.verify(P, h2) == true；Node compareSync(P, h1) == true
④ 落库侧：psql 取该行 password，两侧各自 verify 通过
```

**未确认时的默认行为**：写入前把哈希前缀从 `$2b$10$` 归一为 `$2a$10$`（哈希体不变，`$2a` 与 `$2b` 在 ASCII 口令下语义等价），以满足 AC-112 的字面要求并与 nestJs 产物前缀一致；`verify` 侧对两种前缀均接受。**请人工确认该归一是否为期望语义**（确认路径：在有 Node 的机器上执行上述①②③ 并留存输出）。若确认"保留 `$2b$`"，则 AC-112 需走需求变更。

### 4.8 openssl 单路径与 `.env` 行级 in-place 更新（关键设计点 8）

#### 4.8.1 `generate-ssl`：openssl 单路径

```cangjie
// services/ssl_service.cj
public func generateSelfSigned(domain: String, sslDir: Path, out!: JsonBuilder): Bool {
    // 前置：openssl 可用性探测（runCapped，cap 5s，stdin Discard）
    if (!probeOpenSSL()) {
        out.fail("openssl 不可用")
        out.fix("请安装 OpenSSL（如 WinGet: winget install ShiningLight.OpenSSL.Light）并确保 openssl 在 PATH 中，然后重试")
        return false                       // AC-097：不写任何证书文件
    }
    let key = sslDir / "server.key"; let crt = sslDir / "server.crt"
    let r = runCapped("openssl",
        ["req", "-x509", "-newkey", "rsa:2048", "-keyout", key.toString(), "-out", crt.toString(),
         "-days", "365", "-nodes", "-subj", "/CN=${domain}"],     // 命令形态依据 research.md:63（:1034）
        cap: Duration.second * 60)
    // 成功判据：退出码 0 **且** 两个文件存在且非空 **且** crt 内容含 "BEGIN CERTIFICATE"
    //   —— 杜绝「退出码 0 但没产物」的假成功（AC-012）
    if (r.timedOut || r.exitCode != 0 || !isValidPem(crt) || !isNonEmpty(key)) {
        cleanup(crt); cleanup(key)         // 不留残骸
        out.fail("openssl 执行失败或产物不完整"); out.fix("…")
        return false
    }
    restrictToCurrentUser(key)             // 私钥仅当前用户可读写（AC-015）
    return true
}
```

**不予复刻**：nestJs 的 `createSelfSignedCert` 降级（`setup.service.ts:1122-1131`，把 `Buffer.from(domain).toString('base64')` 拼进证书体，`research.md:63`）**一行不写**；安装器内不存在任何"合成证书"代码路径（AC-098）。

#### 4.8.2 `save-ssl`：备份后写入

写 `<releaseDir>/ssl/server.crt` 与 `server.key`；目标已存在则先复制为 `<name>.bak-<ts>`，写入失败用备份恢复并返回失败（AC-099/100）。

#### 4.8.3 `.env` 行级 in-place 更新算法（对齐 `setup.service.ts:932-951`）

```
func upsertEnv(content: String, key: String, value: String): Result<String>
  0. 校验 key 匹配 ^[\w.]+$（src/config/config.cj:41 键名正则；research-devenv.md:186）
     不匹配 → Err(400)（AC-095）
  1. lines = splitPreservingEol(content)          // 保留 \r\n / \n 原样，绝不统一化
  2. for i in 0..lines.size:
       raw   = lines[i]
       trim  = raw.trimStart()
       if (trim.startsWith("#") || trim.isEmpty()) continue    // 注释与空行原样保留
       idx = trim.indexOf('='); if (idx < 0) continue
       k = trim[0..idx].trim()
       if (k == key):
           indent = raw 的前导空白                 // 保留缩进（:932-937）
           lines[i] = indent + key + "=" + render(value)
           matched = true; break
  3. if (!matched) lines.append(key + "=" + render(value))     // 未命中追加到末尾（:943-948）
  4. return Ok(lines.join(""))                                  // join('\n') 写回（:951）

func render(v: String): String =
    if (v.contains("#") || v.contains(" ")) then "\"" + v + "\"" else v   // 成对引号包裹（research-devenv.md:186）
```

**解析（read-runtime-env）**：逐行跳过注释/空行，按**首个** `=` 切分，剥掉成对引号（`research.md:61`）；再从 `DATABASE_URL` 或 `orm_connectionUrl` 正则解析 host/port/db/user/password。未安装 → 500；已安装但 `.env` 不存在 → **404**（AC-027/090）。

**脱敏**：解析出的口令在日志与 `--json` 中一律以 `***` 呈现（AC-014/018）；仅 `create-admin` 与 `test-config` 内部使用明文，不落日志。

### 4.9 进程治理（关键设计点 9）

| 动作     | 做法                                                                                                                                                                                                                                           | 判据                         |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| 端口占用预检 | `TcpServerSocket(bindAt: port)` 试绑；失败则 `netstat -ano \| findstr ":<port>.*LISTENING"` 取 PID，再 `tasklist /FI "PID eq <pid>" /FO CSV /NH` 取镜像名                                                                                                 | AC-039：非零退出 + 报占用进程；不静默换端口 |
| 启动     | `launch(runtimeExe, [], workingDirectory: releaseDir, stdIn: Discard, stdOut: Discard, stdErr: Discard)`；取 `proc.pid`，用 `tasklist /FI "PID eq <pid>"` 反查镜像名确认                                                                                | AC-101/102                 |
| PID 文件 | `<installRoot>/.installer-runtime.pid` = `{"pid":<Int64>,"image":"agentskills-runtime.exe","exe":<path>,"startedAt":<ISO8601>}`；原子写（tmp+rename）                                                                                              | §6.6.8                     |
| 停止     | ① 读 PID 文件 → ② `findProcess(pid)`；`!isAlive()` 或镜像名不匹配 → 清理文件、报"当前未运行"（AC-106，**不杀复用 PID 的进程**）→ ③ `terminate(force:false)`，轮询 `isAlive()` ≤10s → ④ 仍存活 `terminate(force:true)`，再等 5s → ⑤ 仍存活 `taskkill /PID <pid> /T /F` → ⑥ 仍失败则报失败 + 手工命令 | AC-103/104                 |
| 重启     | 先按上表精确停止，再启动；`<installRoot>/start-runtime.bat` 存在时优先执行该脚本                                                                                                                                                                                    | AC-105                     |
| 自退役探测  | `GET http://127.0.0.1:8080/api/v1/health`，每 2s，连续 3 次 200                                                                                                                                                                                    | AC-126                     |

**禁止项**：`taskkill /F /IM node.exe`（`research.md:57,58`）与任何按镜像名批量终止的命令，一律不出现在代码与生成命令中（写入 §11 防回退 R-06）。

### 4.10 DevKit（M11/M12，关键设计点 10）

#### 4.10.1 DK-1~DK-8 安装动作与自检判据（依据 `research-devenv.md:96-103`）

| ID   | 安装动作                                                                                      | 自检判据（`actual` 的取法）                                                                                                                              | `expected`                    | `fix` 命令                                                                       |
| ---- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------ |
| DK-1 | 引导下载 SDK zip（373.96 MB / 解压 1.2 GB）→ SHA256 校验 → 解压到目标 → 写 `CANGJIE_HOME` 与 PATH          | `cjc --version`、`cjpm --version`、`where cjc` 三条输出拼接                                                                                             | 均含 `1.1.3` 且 `where cjc` 可解析  | `ucInstaller.exe devkit install DK-1 --sdk-path <本地包>`                         |
| DK-2 | 复制 vendored stdx（24 MB）+ 复制 6 MB 的 crypto/ssl DLL 到 `bin/`                                | 判 `libs/cangjie-stdx-windows-x64-1.1.3.1/windows_x86_64_cjnative/dynamic/stdx/` 非空；`bin/` 下 `libcrypto-3-x64.dll` 与 `libssl-3-x64.dll` **同时存在** | 两者均存在                         | `copy libs\...\libcrypto-3-x64.dll <binDir>` 两条                                |
| DK-3 | **`git clone` 到开发者自选目录**（单路径，无兜底）：主地址 `https://atomgit.com/UCToo/agentskills-runtime`，不可达回落镜像 `https://github.com/UCTooCom/agentskills-runtime.git`。详见 §4.10.1.1 | ① `.git/` 存在；② 读 `cjpm.toml` 的 `cjc-version`；③ 判 `libs/cordis-cj/` 存在；④ `git remote get-url origin` ∈ 预期集合；⑤ `git status --porcelain`（dirty 仅提示不阻断） | ① 存在；② `cjc-version = "1.1.3"`；③ 目录存在；④ 匹配；⑤ 干净或已提示 | `ucInstaller.exe devkit install DK-3 --source-dir <开发者自选目录>` |
| DK-4 | 建库（默认名 **`uctoo`**，不存在则 `CREATE DATABASE`）→ 导入 `sql/uctooDB.sql`（由 §4.10.5 的 SEP 生成，默认来自 `uctoo` 库）→ 按名序应用 `sql/incremental/*.sql`（幂等禁 DROP） | `select count(*) from information_schema.tables where table_schema='public'`；**并**判身份列悬空引用数；**并**判超管菜单树非空 | 表数与 `seed-manifest.json` 一致；**悬空 == 0**；**菜单非空** | `psql -U postgres -d uctoo -f sql/uctooDB.sql` |
| DK-5 | 零额外安装（脚手架随源码树，`cjpm.toml:118-135`）；只需跑一次 `loaddbinfo`                                     | `cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo"` 后查 `db_info` 行数                                               | 行数 > 0 且覆盖 `seed-manifest.json` 声明的表数              | 失败降级：引导在管理界面「数据库管理 → 加载数据库信息」操作（`tools/loaddbinfo.md:11`），并**如实标记未完成**（AC-152） |
| DK-6 | 落地 `skills/CangjieSkills`（19.1 MB / 7822 文件，离线）                                           | `python skills/CangjieSkills/scripts/search_docs.py --query "cjpm build"`                                                                       | 返回非空且退出码 0                    | 授权未批准时默认不勾选并给出获取说明（缺口 G-D）                                                     |
| DK-7 | `pnpm install` + `pnpm prebuild` + `pnpm start`（:3031）                                    | `node -v`、`pnpm -v`、`node scripts/check-vue-refs.cjs src/views/ai/` 退出码                                                                         | `node ≥14`、`pnpm` 可解析、检查退出码 0 | `pnpm install && pnpm prebuild`                                                |
| DK-8 | 安装 `cangjie-vscode-1.1.3.tar.gz`（5.5 MB）到 VS Code 扩展目录                                    | 扩展目录中存在 Cangjie 扩展                                                                                                                              | 存在                            | `code --install-extension <vsix>`                                              |


#### 4.10.2 SDK 引导下载 + SHA256 + 断点续传 + `--sdk-path`

```
1. 介质定位顺序：--sdk-path 指定 → 本地预置缓存 → 官方来源（引导）
2. 下载：HTTP GET + 请求头 Range: bytes=<received>-（断点续传，AC-142）
   临时文件：<target>.part；元数据：<target>.part.meta
     {"url": "...", "total": <Int64>, "received": <Int64>, "expectedSha256": "<hex>", "etag": "..."}
   中断后重入：读 meta，从 received 续传；不产生第二个临时文件
3. 校验：pgsql.sha256(bytes)（libs/pgsql-driver/src/crypto.cj:149）逐块或全量比对
   不一致 → 报错 + **保留该文件供人工复查** + 该组件标 failed（AC-140）
4. --sdk-path：对本地包执行同样的 SHA256 校验后再使用（AC-141）
5. 安装器不内置 SDK 二进制（AC-139）
```

#### 4.10.3 初始化编排与幂等（S8）

| 动作                     | 命令                                                                                                   | 判据                                                              | 幂等与降级                                                       |
| ---------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------- |
| I1 生成 `.env`           | 由 `.env.example` 复制并填入 S1~S4 收集值                                                                     | 键符合 `[\w.]+`；值含 `#` 必加引号；`orm_connectionUrl` 可连通                | 键级覆盖写                                                       |
| I2 导入基线（含身份重绑定）        | `psql -U <user> -d uctoo -f sql/uctooDB.sql`；库不存在先 `CREATE DATABASE uctoo`；随后执行 §4.10.5-(2) 的 A1~A6 建号，再做占位符解析 | public 表数 == `seed-manifest.json` 声明值；**悬空身份引用 == 0**；**超管菜单树非空** | 报失败即标未完成，**不伪造表数**（AC-149）；三条判据缺一即失败 |
| I3 增量脚本                | `sql/incremental/*.sql` 按名序                                                                          | 执行无报错                                                           | 幂等、禁 DROP                                                   |
| I5 刷新 `db_info`        | `cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db uctoo"`                    | 行数 > 0 且覆盖 `seed-manifest.json` 声明的表数                           | 报「找不到数据库连接」→ 降级为引导管理界面操作 + **标记未完成**（AC-152）；`db_info` 不随基线分发，本步是它的**唯一来源** |
| I6 生成器冒烟               | `cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name devkit_smoke --blank"` | `skills/devkit_smoke/SKILL.md` 与 `plugin.yaml` 同时存在             | 重复执行同名覆盖                                                    |
| I7 **〔人工〕**&#x7F16;译验证 | `cd skills/devkit_smoke && cjpm build`                                                               | 产物 `target/release/bin/skill_devkit_smoke.exe` 存在               | 安装器**只生成清单与判据，不执行**（AC-154/155）；未回传结果时该项标「待人工确认」且退出码非 0     |
| I8 hosts + 证书          | 追加 `127.0.0.1 javatoarktsapi.uctoo.com`；证书放 `ssl/server.crt` / `ssl/server.key`                      | `curl -k https://javatoarktsapi.uctoo.com/api/v1/health` 返回 200 | 提权失败 → **显式降级** localhost + HTTP 并给出手工命令，**不以成功收尾**（AC-156） |
| I9 前端联调（仅 DK-7）        | `pnpm install`；`pnpm prebuild`；`pnpm start`（:3031）                                                   | `check-vue-refs` 退出码 0                                          | 未勾选 DK-7 即跳过（AC-157）                                        |

**`--skip-build` 的合规说明**：I5/I6 使用 `cjpm run --skip-build`，语义为"运行已构建产物、跳过构建"，不含编译；安装器命令表中**不存在任何 `cjpm build` 调用**。I7 的编译仅以文本形式出现在人工清单中，安装器自身永不执行（对应红线 AC-029）。

#### 4.10.4 幂等与可观测

- 每组件安装前先判"已安装且自检通过"→ 跳过；
- 组件状态写入 `.install-state.json.devkitComponents[id].status`，枚举 `not_installed|installing|installed|failed|rolled_back`（§6.5.7）；
- 依赖未满足（§6.5.8）时报出缺失的前置组件，不允许安装；
- 磁盘闸口：进入 S7 前校验剩余空间，不足则报逐组件体量与总量（AC-144）；
- 组件清单可导出为基线文件并回放（AC-145）；
- `mode` 字段区分 `enduser`/`dev`（AC-146）。

##### 4.10.1.1 DK-3 源码获取：`git clone` 单路径与目标目录选择

**（1）必须先说清的事实**：当前 `apps/agentskills-runtime/` 这棵本地树**本身不是**目标仓库的工作副本——本机 `git remote -v` 显示的 `origin` 是外层单仓，本目录只是其中一个子目录。因此"就地当作二开工作副本"不成立，必须在开发者**自选目录**新建一份真正的 clone 工作副本。

**（2）单路径，无兜底**（2026-10-07 用户裁定）：

| 情形 | 行为 |
|---|---|
| `git` 可用且主地址可达 | `git clone` 主地址到目标目录 |
| 主地址不可达 | 试镜像；成功即 clone |
| `git` 不可用 | **失败终止**（退出码非 0），提示"请先安装 git，然后重跑 `ucInstaller.exe devkit install DK-3 --source-dir <dir>`" |
| 两者均不可达 | **失败终止**（退出码非 0），标记 `networkUnreachable: true` |

**为什么不做离线复制兜底**（用户原话：其他开发者没有我本地目录，也无从复制源码）。两条推论：① 离线复制的输入（作者的本地目录）对其他开发者**不可得**，受益方为零；② 失败是**终点不是降级**——留下一个无历史的残缺源码树，比明确失败更糟（开发者会以为装好了，等要提 PR 时才发现没有历史）。因此失败时**不写任何源码文件、不留残缺目录**。

**（3）目标目录三分状态**（进入前先判）：

| 状态 | 判据 | 行为 |
|---|---|---|
| S-a 不存在 | 路径不存在 | 直接 clone |
| S-b 存在且为空 | 目录项数 0 | clone 到该目录（`git clone <url> .`） |
| S-c1 存在且非空，是本仓库且 remote 匹配 | `git rev-parse` 成功 + remote ∈ 预期 | 提示可复用 → `git fetch` → 计为「复用」 |
| S-c2 存在且非空，是其它 git 仓库 | `git rev-parse` 成功 + remote ∉ 预期 | **拒绝**，要求换目录（默认退出码非 0） |
| S-c3 存在且非空，非 git 目录 | `git rev-parse` 失败 | **拒绝**，要求换目录；仅在其下**新建子层**再 clone 是被允许的（不做覆盖式复制） |

**（4）clone 参数与 stdin 防卡**：`git clone` 可能弹凭据交互导致卡死。执行时置 `GIT_TERMINAL_PROMPT=0`、`GIT_ASKPASS=echo`、`GCM_INTERACTIVE=never`；注意 `std.process.executeWithOutput` 的 `environment!` 是**整体替换**，必须以 `HashMap(getVariables())` 为基底再覆盖（红线 R-04）。

---

#### 4.10.5 初始账号二元组、Seed Identity Contract 与数据库导出机制（SEP）

> 依据 `research-seed-identity.md` 与 `research-seed-export.md`（2026-10-07 追加）。对应 `spec.md` §5.15（REQ-RNI-078~087）+ §5.16（REQ-RNI-088~097）。

##### (1) 默认库名：`uctoo`

`.env:244` / `.env:247` 两条连接串都指向 `...5432/uctoo`。安装器的数据库名**默认值即 `uctoo`**（可改，非必填），库不存在时由安装器 `CREATE DATABASE`。

顺带关闭历史缺口：**现行 `sql/uctooDB.sql` 的 Navicat `Source Catalog` 是 `uctoov3`**（206 表，2026-10-02），比 `.env` 实际连接的 `uctoo` 库**少 20 张表**。基线以 `uctoo` 库为准，由本节的导出机制重新生成。

##### (2) 初始账号二元组：一个超管 + 一个主 agent

初始环境有 **2 个账号**，不多不少。**不创建任何演示/测试账号**。

落库顺序（全部走既有业务代码路径，安装器不自行拼 INSERT）：

```
A1 uctoo_user      超管（user_type='human'）                    ← create-admin 真路径
A2 uctoo_user      主 agent 账号（user_type='agent'，password=不可登录随机串）
A3 user_has_roles  超管 → 超管角色（2338cf7b-…-6a3ca79d683d，持 '*'）
A4 user_has_roles  主 agent → agents 角色（a686ff1f-…-2b2d5267c682）
A5 user_has_group  主 agent → user_group(code='agents')
A6 agents          MainAgent 实体（agent_type='MAIN'，status=1，user_id=A2.id）
   + 回填 A2.agent_id = A6.id
```

**顺序不可颠倒**：A6 需要 A2 的 id，A2.agent_id 需要 A6 的 id ⇒ **A2 → A6 → UPDATE A2.agent_id**。

**为什么主 agent 不是可选项**（源码取证，非推测）：

| 事实 | 出处 |
|---|---|
| agent 账号**不支持密码登录**，只能走 `agentAutoLogin` | `src/app/controllers/uctoo/uctoo_user/UctooUserAuthController.cj:112-116`（403 `AUTH-AGENT-001`） |
| 自动登录要求 `user_type == 'agent'` **且** `agents.status == 1` | `src/app/services/aip/AgentAuthService.cj:61`、`:65-71` |
| `agents.user_id` 与 `uctoo_user.agent_id` **双向指针**，互为兜底 | `AgentAuthService.cj:47-55` |
| 建号同时落 4 张表（账号 / 角色 / 用户组 / 实体） | `src/app/services/aip/AipIdentityService.cj:28-80`；`AGENTS_ROLE_ID` :21、`AGENTS_GROUP_CODE` :22 |

##### (3) 双命名空间占位符（SIC 补丁）

主 agent 是**双身份**，两个命名空间不可混：

```
{{principal:super_admin}}   → uctoo_user.id（人类超管）
{{principal:svc_mainagent}} → uctoo_user.id（agent 账号，实测 351 处引用）
{{agent:main}}              → agents.id（智能体实体，实测 5078 处引用）
```

**红线**：`agent_id` 列指向 `agents.id`，**不是** `uctoo_user.id`（实测 `uctoo_user.agent_id = 4dfc6252…` 而 `uctoo_user.id = 8803ed58…`）。搞反会静默写入错的 uuid——导入期不报错、运行期才炸。

##### (4) 数据库导出机制 SEP：分层与实测账

现状样本 `sql/public20261007.sql`：**105.3 MB / 226 表 / 60,820 条 INSERT / 98 张表有数据**，数据段 103.15 MB，其中 **`agent_contexts` 单表 381 行占 80.66 MB（78.2%）**。

| 档 | 内容 | 体量 |
|---|---|---|
| **T-A 结构**（全部 226 表） | `CREATE TABLE IF NOT EXISTS` + COMMENT + PK/UK/索引（DDL 0.151 + COMMENT 0.205 + 约束索引 0.046） | **0.403 MB** |
| **T-B 引导数据**（**9 表**，第二轮修订） | `i18` 1088 / `permissions` 442 / `config` **17**（仅 `env_key IS NULL`）/ `role_has_permission` 48 / `crontab_task_registry` 13 / `user_group` 8 / `agent_executors` 5 / `uctoo_role` 7 / `lang` 2 | **≈1,633 行 / 0.42 MB** |
| **T-C 示例数据** | `entity` 146 行 | **0.048 MB** |
| **合计** | | **≈ 0.87 MB（原文件的 0.83%）** |

**T-D 由安装器生成（不进 seed）**：`uctoo_user` / `user_has_roles` / `user_has_group` / `agents` —— 即 (2) 的 A1~A6。
**T-D′ 由运行时生成（不进 seed）**：`config` 中 `env_key IS NOT NULL` 的 85 行（每次启动由 `ConfigSyncHandler.startupSync()` 重建）。
**T-F 同步/派生（不进 seed）**：`agents` / `agent_skills` / `db_connection` / `db_info` —— 详见 §4.10.6。
**T-E 排除**：日志审计（`operate_log` 28,426 行 8.05 MB、`crontab_log` 6,504、`llm_usage_logs` 4,484、`llm_channel_health` 5,795、`login_log` 656）、会话令牌（`uctoo_session` 2,548）、派生（`db_info` 3,176 行 1.12 MB —— 可由 `loaddbinfo` 从 `information_schema` 重算，见 `src/app/services/uctoo/DbInfoService.cj:1026-1047`）、业务（电商/代码托管/尽调/微信支付等）。

**`defaultTier: structure-only` 是整个机制最重要的一个字段**——把"导出什么"从黑名单（"我记得要排除这几张"）翻转为白名单（"没被批准只给结构"）。新业务表上线后若无人加入白名单，自动只导结构，**不可能意外泄漏业务数据**。

##### (5) 导出流水线 E0~E7

```
E0 读策略 sql/seed/export-policy.json（默认档 = 仅结构）
E1 连源库（默认 uctoo）→ 枚举表/列序/注释/约束/索引/行数
E2 结构导出：CREATE TABLE IF NOT EXISTS + COMMENT + PK/UK/INDEX（禁 DROP/TRUNCATE/DELETE）
E3 数据导出（仅 T-B/T-C）：ORDER BY 主键 → 确定性；流式逐行 INSERT（引号感知，禁按行切分）
E4 身份匿名化：principal → {{principal:<ref>}}；agent → {{agent:<ref>}}；未命中 → 孤儿策略（默认 fail）
E5 门禁：体积/行数上限 · 破坏性语句扫描 · 敏感内容扫描 · 身份列裸标识残留 · 外键引用自洽
       任一不过 → 失败，**不覆盖既有产物**
E6 落盘：sql/uctooDB.sql + sql/seed/seed-manifest.json + 人类可读报告
E7 临时库重放验真：表总数一致 · 悬空身份引用 == 0 · 超管菜单树非空
       任一不过 → 作废产物
```

**已量化的工作量**（保留集内的身份引用，即导入期真正要处理的全部）：

```
149  permissions.creator = admin     47  role_has_permission.creator = admin
113  entity.creator      = admin     33  entity.creator             = test1 ← 唯一需策略处置
 17  config.creator      = admin     16  i18.creator                = admin
  8  user_group.creator  = admin      7  uctoo_role.creator         = admin
  2  lang.creator        = admin
──── 392 处，仅 creator 一列，仅 2 个主体
```

> **第二轮修订**：`db_connection` 移出引导集（→ T-F）⇒ 减 1 处；`config` 加 `env_key IS NULL` 谓词后仍为 17 处——因为那 85 行 `.env` 镜像的 `creator` 本身为 **NULL**，正是"由 `ConfigSyncHandler` 自动插入、无人归属"的旁证。

`entity` 的 33 行 test1 数据：默认策略 `map-to: super_admin`（示例数据归位到安装环境超管），备选 `drop`。**注意 `entity.creator` 在本机库已有 FK `Entity_creatorId_fkey → uctoo_user(id)`**（不在导出文件内）——该约束一旦进入基线，未处置的 33 行会直接导入失败。

##### (6) 七条硬性质（超越业界最佳实践）

1. **白名单优先、默认拒绝**：未声明表一律只导结构（vs 常见 dump 的"全导 + 手工排除"）；
2. **策略即代码 + 四道门禁**：策略进仓库可 review，体积/语句/敏感/悬空四条在导出期强制；
3. **确定性**：`ORDER BY` 主键 + 时间戳只落文件头 ⇒ 两次导出 diff 为空，产物可进 git、可 code review；
4. **身份匿名化前置**：仓库里永不出现作者环境真实 uuid；
5. **敏感内容扫描**：bcrypt 散列 / JWT / 私钥 / 手机号 / 邮箱，命中即失败；
6. **非破坏性**：产物不含 `DROP TABLE`（旧基线 206 条 DROP 是 Navicat 默认值，不继承）；
7. **派生数据不入库**：`db_info` 排除，改由 `loaddbinfo` 重算。

#### 4.10.6 初始数据内容定档与脱敏（第二轮补充）

> 依据 `research-seed-content.md`。§4.10.5 解决"初始数据文件怎么生成"，本节解决两件更细的事：**哪些数据根本不该进**（同步能再造的、运行时会给的），以及**留下来的必须怎么脱敏**。

##### (1) 新增 T-F 档：同步/派生数据不导

| 表 | 为什么不该导 | 实证 |
|---|---|---|
| `agents` | 启动期由 `AGENTS.md` + `agents/*.md` 同步 upsert（匹配键 `source_path`） | 实测 **9/9** 行带 `source_path` |
| `agent_skills` | 启动期由 `skills/*` 同步 upsert | 实测 **50/56** 行带 `source_path`；另 6 行 `sync_status=pending` 属同步残留 |
| `db_connection` | 描述**本机数据源**（`127.0.0.1:5432/uctoo`）且 `password` **NOT NULL** 存明文 | 实测 1 行，`pw_len=8` |
| `db_info` | `loaddbinfo` 可完全重算 | 派生 |

**源码依据**：`src/app/main.cj:329-342` 启动期 `spawn { SyncManager.instance?.syncAll(TriggerSource.Startup) }`；`SyncManager.cj:51-52` 只注册 `agent` / `agent_skill` 两个 handler；`SyncManager.cj:122-123` 软删**只对有明确 `source_path` 的记录生效**；`AgentSkillSyncHandler.cj:132-135` 含盘符路径视为绝对路径直接采用。

**推论（写进实现约束）**：往 seed 里塞 `agents`/`agent_skills` 的行，会在目标环境第一次启动时被 upsert 覆盖（路径命中）或**软删下线**（文件不存在）；旧基线里 `agent_skills` 那 50 行连 `source_path` 都被手工换成 `xxx/apps/…` 这种非法路径，属于**双重错误**——既不该导，脱敏后又不可用。

`agents` 同时出现在「安装器生成」与「同步/派生」两处**不矛盾**：前者是导入侧（安装器按 A1~A6 真实建一行主 agent），后者是导出侧（恒不导）。策略文件里两处都列，并在注释写明。

##### (2) `config` 表：行级谓词分治

**源码依据**：`ConfigSyncHandler.cj:64` 按 `env_key` 匹配；`:66-75` 命中即无条件覆盖；`:242-244` `resolveConflict` **恒返回 envValue**（`.env` 恒赢）；`:86` 自动插入行 `isSensitive=false`。调用点 `main.cj:315`。

**实测**：102 行 = **85 行带 `env_key`**（且这 85 行 `creator` 为 NULL，印证是自动插入）+ **17 行纯初始**。

| 行类别 | 判据 | 档位 |
|---|---|---|
| `.env` 镜像行 | `env_key IS NOT NULL` | **T-D′ 运行时生成，不导** |
| 纯初始配置行 | `env_key IS NULL` | **T-B 引导数据，导**（17 行） |

##### (3) 发现：`.env` 明文密钥进库且敏感标记全缺（C-3）

实测带 `env_key` 行的值形态（前缀掩码）：

| 组 | key | 长度 | 前缀 |
|---|---|---|---|
| api_key | `GITHUB_TOKEN` | 40 | `ghp_` |
| api_key | `ORBITAI_API_KEY` | 67 | `sk-b` |
| api_key | `TOKENDANCE_API_KEY` | 51 | `sk-4` |
| api_key | `FIRECRAWL_API_KEY` | 35 | `fc-4` |
| api_key | `SOPHNET_API_KEY` / `MAAS_API_KEY` | 86 | — |
| api_key | `STEPFUN_API_KEY` | 65 | — |
| database | `DATABASE_URL` / `opengauss_orm_connectionUrl` | 51 | `post`（连接串含密码） |
| api_key | `GMICLOUD_API_KEY` | 26 | `your`（**占位值**，未真实配置） |

而 `is_sensitive` 统计为 **`f=102 / t=0`**——一行都没标记。

**处置边界**：改 `ConfigSyncHandler` 属 runtime 侧变更，**不在本工程范围**。本工程只做**防御**：导出期脱敏 + seed 回填 `is_sensitive`（OQ-C2）。

##### (4) 脱敏四条规则 R1~R4

| 规则 | 适用 | 做法 |
|---|---|---|
| **R1** | 凭据/口令/密钥/令牌 | → `{{secret:<kind>}}` |
| **R2** | 环境标识（外网 URL、应用标识）、具体时间戳 | → `{{env:<kind>}}` / `{{ts:epoch}}` |
| **R3** | 值本身已是占位形态（`your…`/`changeme`/`xxx`/`TODO`） | **原样保留**，不二次替换 |
| **R4** | 既不可脱敏又不可置空（如 `db_connection.password` NOT NULL） | **整表降级为仅结构** |

**R4 是 R1 的兜底**：`db_connection.password` 置占位符虽满足 NOT NULL，却产出**连不上库的假数据源**——比没有更糟。故走 R4 整表不导（与 §(1) 的 T-F 结论殊途同归）。

**敏感列判定必须"清单为主 + 正则为辅 + 人工复核留痕"**：实测全库 39 个列名正则命中里有 `*total_tokens` / `prompt_tokens` / `completion_tokens` / `avg_tokens` 这类**误命中**（是 LLM 用量计量，不是凭据）。纯正则自动脱敏会把统计值脱成占位符。

##### (4.1) `keepVerbatim` 原样保留清单（OQ-C1 拍板落地）

R2 会把"外网 URL / 应用标识"归一为占位符，但**有一批值是跨环境一致的框架常量，不是部署实例标识**。`config` 中首批两项：

| 表.键 | 长度 | 保留理由 |
|---|---|---|
| `config.website.appid` | 18 | 上一代框架（v3）配置项；**当前 v4 暂未消费**，后续小程序端产品线需要沿用 ⇒ 必须保持跨环境一致 |
| `config.site.API_URL` | 32 | 同上 |

**实现约束**：

- `sanitize-policy.json` 新增 `keepVerbatim: [{ "table": "config", "key": "website.appid", "reason": "…" }, …]`；
- **三要素必填**（表 / 键 / 理由），缺一即策略不合法（AC-261）；
- 保留条目在导出报告中**单独成节并标注"需复审"**——后续版本若重新启用或废弃这些配置项，可据此重新评估是否仍应保留（REQ-RNI-105）；
- 保留清单**只对 R2 生效**；R1（凭据/密钥/令牌）**不受保留清单豁免**——即不允许以"历史配置项"为由把真实密钥保留下来。

##### (5) 占位符协议（两套正交命名空间）

| 命名空间 | 形态 | 导入期 |
|---|---|---|
| 身份 principal | `{{principal:<ref>}}` | 解析为目标环境 `uctoo_user.id` |
| 身份 agent | `{{agent:<ref>}}` | 解析为目标环境 `agents.id` |
| **脱敏 secret** | **`{{secret:<kind>}}`** | **不解析**，原样入库，由开发者补齐 |
| **环境 env** | **`{{env:<kind>}}`** | **不解析**，同上 |

**铁律**：`{{secret:…}}` / `{{env:…}}` **绝不在导入期被猜值填充**。宁可界面显示"未配置"，也不要填一个看似合理的值——后者造成"配过了但不对"的假象，排查成本远高于前者。

##### (6) 流水线升级：新增 E3.5 与 E4.5，门禁增至六条

```
E3.5 行级谓词过滤   ├─ config：仅取 env_key IS NULL（102 → 17）
                    └─ 同步/派生表：即便被误列入白名单也整表剔除
E4   身份匿名化     └─ principal / agent 双命名空间
E4.5 脱敏           ├─ R3 先行 → R1 → R2 → R4
                    └─ 回填 config.is_sensitive
E5   门禁（六条）   ├─ 体积/行数
                    ├─ 破坏性语句
                    ├─ 敏感形态扫描
                    ├─ 脱敏生效校验（敏感列值须为占位符）        ← 新增
                    ├─ 同步残留校验（放行表不得有非空来源路径行） ← 新增
                    └─ 悬空身份引用 / 外键自洽
```

策略文件新增字段：`bootstrapRowPredicates`、`runtime-generated`、`sync-derived`、`sanitizePolicy`、`forbidSyncDerivedRows`、`failOnUnsanitizedSensitiveColumn`。

### 4.11 机器可读契约：`--json` 形态、退出码表与修复建议（关键设计点 11）

#### 4.11.1 输出形态

```json
{
  "schema": "ucinstaller/report/v1",
  "command": "devkit verify",
  "generatedAt": "2026-10-07T10:30:00+08:00",
  "ok": false,
  "exitCode": 6,
  "truncated": false,
  "items": [
    { "id": "DK-1", "status": "fail",
      "actual": "cjc not found in PATH",
      "expected": "cjc --version 含 1.1.3",
      "fix": "ucInstaller.exe devkit install DK-1 --sdk-path C:\\dl\\cangjie-sdk.zip" },
    { "id": "I7",  "status": "manual",
      "actual": "未回传执行结果",
      "expected": "target/release/bin/skill_devkit_smoke.exe 存在",
      "fix": "cd skills/devkit_smoke && cjpm build" }
  ]
}
```

规则：stdout **只**承载上述结构（无装饰性文本，AC-162）；诊断日志全部走 stderr（AC-165）；超长字段截断并置 `truncated:true`（spec §5.13.3 异常 2）。

#### 4.11.2 退出码表（AC-163）

| 退出码 | 类别    | 触发示例                               |
| --- | ----- | ---------------------------------- |
| 0   | 成功    | 全部判据通过                             |
| 1   | 通用失败  | 未分类异常、文件不可写                        |
| 2   | 参数错误  | 未知开关、非法取值                          |
| 3   | 环境不满足 | Node <18、PostgreSQL <14、openssl 缺失 |
| 4   | 网络失败  | 远端介质获取超时（>300s）、连接被拒               |
| 5   | 校验失败  | SHA256 不一致、介质完整性校验不通过              |
| 6   | 需人工介入 | hosts 提权失败、编译验证未回传、SDK 授权未确认       |

多类别并存时：`exitCode = max(所有非 0 类别码)`（0 表示无失败；1 仅在无其他类别时使用），结构化结果中逐项列出全部失败（spec §5.13.3 异常 3）。

#### 4.11.3 修复建议生成

每个失败项必须给出**可直接复制执行**的命令或操作路径（AC-164），禁止只给描述文字。`fix` 由各类别的模板函数生成并注入实际值（路径、PID、端口、组件 ID、缺失工具名）。

### 4.12 `start-installer.bat` 改造与出包布局（关键设计点 12）

#### 4.12.1 现状与改造点（依据 `apps/web-admin/start-installer.bat`）

| 现状（行号）                                                       | 处置                                                                                  |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `:10-19` 检查 Node.js；`:22-32` 检查 pnpm                         | **删除**：交付物零 Node 依赖（AC-033）                                                         |
| `:37-47` `cd nestJs` + `pnpm install` + `pnpm run start:dev` | **删除**                                                                              |
| `:52-62` `cd web` + `pnpm install` + `pnpm run start`        | **删除**（前端工程由 DK-7/I9 按需处理，不在引导阶段）                                                   |
| `:64-80` 等待 :3000 / :3031 双端口                                | **改为单端口**：只对 `http://localhost:3000/healthCheck` 探活，并把期望值从"能连通"提升为"响应体严格等于 success" |

#### 4.12.2 改造后的脚本形态（新文件 `apps/web-admin/start-installer.bat` 覆盖）

```bat
@echo off
cls
title AgentSkills Installer

echo ========================================
echo   AgentSkills Runtime Installer
echo ========================================
echo.

set "EXE=%~dp0..\agentskills-runtime\installer\target\release\bin\ucInstaller.exe"
if not exist "%EXE%" (
    echo [ERROR] ucInstaller.exe not found: %EXE%
    echo Please run: cd ..\agentskills-runtime\installer ^&^& cjpm build
    pause
    exit /b 1
)

echo [1/2] Starting native installer on port 3000...
start "ucInstaller" cmd /c ""%EXE%" --auto-exit"

echo [2/2] Waiting for health check...
set /a N=0
:wait
set /a N+=1
powershell -NoProfile -Command ^
  "try { $r = Invoke-WebRequest -Uri 'http://localhost:3000/healthCheck' -UseBasicParsing -TimeoutSec 2; if ($r.Content.Trim() -eq 'success') { exit 0 } else { exit 2 } } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto :ready
if %N% geq 30 (
    echo [ERROR] Installer did not become healthy within 60s.
    pause
    exit /b 1
)
timeout /t 2 >nul
goto :wait

:ready
echo [OK] Installer is ready.
start "" http://localhost:3000
echo Installer will exit itself after the runtime is healthy (--auto-exit).
pause
```

#### 4.12.3 出包布局（Windows x64）

```
dist/ucInstaller-win-x64/
├── ucInstaller.exe
├── libcrypto-3-x64.dll                 ← stdx OpenSSL，文件名**必须**与 stdx 写死的名称一致
├── libssl-3-x64.dll
├── assets/                             ← 向导静态资源，**平铺**在 assets 根下（不再多一层 install/）
│   ├── install.html
│   ├── install.js
│   └── install.css
├── start-installer.bat                 ← 由 apps/web-admin/start-installer.bat 复制而来
├── （其余 stdx DLL，随 [target.x86_64-w64-mingw32.bin-dependencies] 声明复制）
└── .env.example
```

**DLL 摆放判据**：stdx 在 Windows 上对 OpenSSL 依赖的文件名是**写死**的 `libcrypto-3-x64.dll` / `libssl-3-x64.dll`（与 `research-devenv.md:97` 的 DK-2 判据一致）。出包时若源文件名不同（例如带版本号后缀），**必须重命名对齐**；安装器 DK-2 自检会校验这两个文件名同时存在（AC-159 / §6.5）。所有 DLL 与 `ucInstaller.exe` 放在**同一目录**，避免 PATH 依赖。

> **assets 目录口径（实测订正，v1.8）**：早期草图把静态资源画成 `assets/install/{html,js,css}`，与代码不符。`core/paths.cj:72` 是 `assetsDir = installRoot.join("assets")`，`http/routes.cj:29-32` 用 `serveStatic(assetsDir)` 直接提供 `/install.html`——即三个文件**平铺在 `assets/` 根下**。按旧图落盘会让向导页 404，故本节已订正为平铺形态（`installer/assets/` 源码目录与 `package.ps1` 的复制逻辑同此口径）。

### 4.13 M18：NDJSON 流式进度与运维能力归位（关键设计点 13）

> **补齐说明（v1.7）**：M18（REQ-RNI-106~109 / AC-262~276）此前只在 §12.2 的 OQ-D1/OQ-D7 与 §11 的 R-39~R-42 中被登记，**没有落地到详细设计**，导致 T053~T058 六个任务缺少设计依据。本章补齐。

#### 4.13.1 三种消费形态与互斥关系

| 形态                       | 开关                                        | 通道      | 消费者             | 对应 AC       |
| ------------------------ | ----------------------------------------- | ------- | --------------- | ----------- |
| HTTP 静态向导                | `serve`（默认）                                | HTTP    | 人（install.js）  | AC-036~047  |
| 完整结果 JSON                | `--json`                                  | stdout  | 脚本 / CI        | AC-162~165  |
| **NDJSON 流式进度**          | `--progress=ndjson`                       | stdout  | PC Electron / 图形外壳 | AC-262~266  |

**互斥判据（AC-265）**：`--progress=ndjson` 与 `--json` 同时出现即参数冲突，`Args.parse` 阶段拒绝执行，错误信息须指明二者互斥，不进入任何业务路径。

#### 4.13.2 事件行契约（`cli/progress.cj`）

```
// stdout：每行一个完整 JSON 对象，禁止跨行
{"ts":"2026-10-08T03:20:11.482Z","seq":1,"stage":"S2","event":"step.begin","stepId":"S2","title":"配置数据库"}
{"ts":"...","seq":2,"stage":"S2","event":"probe.result","stepId":"S2","detail":{"name":"postgresql","passed":true,"method":"version"}}
{"ts":"...","seq":3,"stage":"S2","event":"step.end","stepId":"S2","status":"pass"}
...
{"ts":"...","seq":87,"stage":"S8","event":"final","exitCode":0,"status":"pass","summary":{"total":9,"passed":9,"failed":0}}
```

**四条硬约束**：

1. **单行完整**（AC-262）：每个事件对象在写出前先序列化为一行字符串，**一次性 write**；禁止分块写同一行。含中文或非 ASCII 的字段按仓颉 UTF-8 语义处理（`toRuneArray()` 只在需要按字符截断时使用，JSON 序列化本身按字节写即可）。
2. **末行必含 `exitCode`**（AC-263）：无论成功失败，`final` 事件必须输出。进程被 kill 时末行缺失，消费方据此判"未正常结束"（§5.18.3 异常场景 1）。
3. **通道分离**（AC-264）：诊断/告警/错误详情一律 `util/log.cj` → **stderr**；stdout 只允许出现上述事件行。与 R-13 同源。
4. **顺序与不缓冲**（AC-266）：事件在发生的那一刻立即 flush，禁止攒到执行结束时一次性吐出。实现上每行写完即 flush，不依赖进程退出时的隐式 flush。

**与 L3 插件红线的关系**：本项是**安装器主进程**的 CLI 输出，不是插件进程的 stdio RPC 通道，因此不违反"stdout 必须独占"的红线；反过来正因该红线存在，`--progress=ndjson` **只允许安装器主进程使用**。

#### 4.13.3 M2：runtime 自述能力（冻结区有限豁免）

> **豁免范围严格限于两个端点**（R-40，用户拍板）。状态与配置**必须复用既有接口**，不得另建第二套。

| 能力   | 处置                  | 端点                                                                      | 对应 AC       |
| ---- | ------------------- | ----------------------------------------------------------------------- | ----------- |
| 状态   | **复用既有**，不新增        | `/api/v1/health`（`main.cj:698-717`）                                      | AC-269      |
| 配置   | **复用既有**，不新增        | `/api/v1/uctoo/config/*`（`ConfigRoute.cj:27-39`）                         | AC-269      |
| 日志   | **新增**（豁免 1/2）      | 运行日志读取（只读、分页、限量）                                                        | AC-267      |
| 环境   | **新增**（豁免 2/2）      | 运行环境检测                                                                  | AC-268      |
| 启停   | **不在 M2 范围** → 归 M3 | 见 §4.13.4                                                               | AC-271      |

**新增两端点的硬约束**：

- **日志端点**：源必须是运行系统**自身产生的日志文件**（`logs/agentskills-runtime.log`、`logs/startup-trace.txt`）；**禁止**用业务表（`crontab_log` / `llm_usage_logs`）查询冒充（R-40③）；只读 + 分页 + 限量 + 防目录穿越。
- **环境端点**：**不得另写一套探测**。唯一实现是既有需求 `system-env-capability` 的采集器（`.codeartsdoer/specs/system-env-capability/spec.md`），运维端点复用其结果，只补运维特有项（DB 连通性、磁盘、端口）（R-42 / AC-275）。
  - 采集部分失败返回"部分能力未知"并**继续启动**，绝不阻断（AC-276）。
  - **不得**把 Node.js 列为必需项 —— 仓颉 runtime 不依赖 node，这是 nestJs `setup.service.ts:25-60` 的失配判据（N-4）。

#### 4.13.4 M3：外置管控者 `serve --manage`（承接启停）

**为什么不能由 runtime 自己启停**：进程不能自举 —— 停止自己之后就没有执行体可以执行启动（`research-deployment.md` §5.3.1）。因此 `start/stop/restart` 必须由**运行系统之外的管控者**提供（R-39 / AC-271）。

```
ucInstaller.exe serve --manage [--port 3000]
  ├─ 只挂载运维端点，不进入安装流程
  ├─ 用毕即退（保留"零常驻"卖点）
  └─ 安装器本来就 spawn runtime，天然是父进程，是唯一合格的管控者
```

| 场景           | 管控者                                             |
| ------------ | ----------------------------------------------- |
| web-admin 场景 | `ucInstaller.exe serve --manage`（本项目 T056）       |
| PC 客户端场景     | PC 既有管控者 `runtime.ts:317 isRunning()`，**不需要** T056 |

**UI 契约（AC-271 异常场景 3）**：管控者未运行时，运维界面必须提示"未运行 + 拉起入口"，**不得静默失败**。

#### 4.13.5 N-5 修复：健康状态不得"假绿灯"

**现状（源码实证）**：

| 位置                          | 事实                                                          |
| --------------------------- | ----------------------------------------------------------- |
| `main.cj:706-713`           | 判据为 `if (_chatModel.isNone())`                                |
| `main.cj:239` / `:448`      | 恒赋值 `_chatModel = Some(LazyChatModel(modelName))`             |
| `lazy_chat_model.cj:27-29`  | `init` 只存模型名字符串，**构造永不抛错**；真实实例在请求边界才 `resolve()`            |

⇒ **`_chatModel` 永远 `Some` ⇒ `chatModel.available` 永远 `true`**，通道全挂也显示正常。根因是 T010 把 `_chatModel` 从"真实实例"改成"惰性解析器"，但 health 的判据**语义没跟着变**。

**修复判据（AC-272）**：改为探测**通道的实际可用性** —— 按 `ChannelRegistry` 解析默认通道是否成功 / `channel_probe` 的周期健康态。**禁止**用 `Option.isNone()` 或"对象是否构造出来"代替。

**硬性验收（AC-273）**：构造一个通道全失效的场景，该字段**必须**报 `available:false`；报 `true` 即判未修复。

**连带复查（AC-274）**：凡依赖 `_chatModel` "是否已就绪"语义的消费点（`main.cj:655/661/671` 的路由注册分支等）都要同步复核，避免同类语义漂移残留。

---

## 5. 数据设计

### 5.1 数据模型总览

| 载体                                     | 类型      | 归属步骤  | 原子写           | 说明                                                       |
| -------------------------------------- | ------- | ----- | ------------- | -------------------------------------------------------- |
| `.install-state.json`                  | JSON 文件 | S0~S8 | 是（tmp+rename） | 状态机唯一真相源（§4.5）                                           |
| `<cwd>/config.json`                    | JSON 文件 | S1    | 是             | 四项 DB 配置：`dbHost/dbPort/dbName/dbUser`（`research.md:49`） |
| `<releaseDir>/.env`                    | 行文本     | S4/I1 | 是             | 行级 in-place 更新（§4.8.3）                                   |
| `<installRoot>/.installer-runtime.pid` | JSON 文件 | S6    | 是             | `{pid, image, exe, startedAt}`                           |
| `<installRoot>/.installer-port`        | 文本      | 启动    | 是             | 实际监听端口（AC-040）                                           |
| `<installRoot>/.installer-gc.json`     | JSON 文件 | 原子切换  | 是             | 延迟删除队列（§4.4.2）                                           |
| `<installRoot>/previous/`              | 目录      | S3    | rename        | 最近一份快照（§6.6.4）                                           |
| `<installRoot>/.staging/<uuid>/`       | 目录      | S3    | —             | 过渡目录，切走即删                                                |
| `uctoo_user`（既有表）                      | 关系表     | S5    | 事务            | 只写既有列（§4.7.2）                                            |
| `db_info`（既有表）                         | 关系表     | I5    | —             | 只写不建（SDD 铁律 9）                                           |

### 5.2 `uctoo_user` 写入的字段映射（逻辑约束，不改结构）

| 列                                           | 来源                            | 约束                       | 是否新建 |
| ------------------------------------------- | ----------------------------- | ------------------------ | ---- |
| `id`                                        | 数据库自增，由 `RETURNING` 取回        | 用于回读自校验                  | 既有   |
| `name`                                      | 表单 `name`，缺省取 `username`      | 必填，长度不超既有列限制             | 既有   |
| `username`                                  | 表单                            | 必填，表内唯一                  | 既有   |
| `email`                                     | 表单                            | 必填，基本邮箱形状，表内唯一           | 既有   |
| `password`                                  | `Bcrypt.hash(plain, cost:10)` | 以 `$2a$10$` 开头（见 §4.7.5） | 既有   |
| `auth_provider`                             | 常量 `0`                        | —                        | 既有   |
| `status`                                    | 常量 `1`                        | —                        | 既有   |
| `created_at`/`updated_at`/`last_login_time` | `CURRENT_TIMESTAMP`           | —                        | 既有   |

**不新建任何表或列**（AC-017/117）；不写 `avatar`、`creator`、`deleted_at`、`last_login_ip`、`remember_token`、`access_token`、`refresh_token`（§6.2.8）。

### 5.3 `.installer-gc.json` schema

```json
{ "schemaVersion": 1,
  "entries": [
    { "path": "…\\release\\bin\\agentskills-runtime.exe",
      "pending": "…\\release\\bin\\agentskills-runtime.exe.pending",
      "firstFailedAt": "2026-10-07T10:05:00+08:00",
      "attempts": 3,
      "reason": "sharing-violation",
      "holderPid": 8123,
      "holderOwnedByInstaller": false } ] }
```

### 5.4 数据关系

```
.install-state.json ──1:1──> 一次安装过程
        ├── 0..1 ──> previous/（快照，最多一份）
        ├── 1:N ──> devkitComponents（DK-1..DK-8）
        └── 0:N ──> degraded[]（降级留痕，每项含 manualCmd）
.installer-gc.json ──1:N──> 待删除/待替换文件（与 .pending 文件配对）
.installer-runtime.pid ──1:1──> 当前被安装器启动的 runtime 进程
uctoo_user ──(既有表)── 管理员记录（S5 唯一写点）
```

---

## 6. API 设计

### 6.1 API 列表

| #  | 方法   | 路径（`/api/setup/*` 与 `/setup/*` 双前缀） | 说明                                     |
| -- | ---- | ----------------------------------- | -------------------------------------- |
| 1  | GET  | `/healthCheck`                      | 纯文本 `success`                          |
| 2  | GET  | `/setup/check-environment`          | 三项环境检测                                 |
| 3  | POST | `/setup/save-config`                | 保存 DB 四配置到 `config.json`               |
| 4  | GET  | `/setup/load-config`                | 读取配置（失败仍 200 回吐内存）                     |
| 5  | POST | `/setup/test-config`                | 连通性探测（默认不阻断 + `probe`；`--truthful` 严判） |
| 6  | GET  | `/setup/service-status`             | 三项服务状态                                 |
| 7  | GET  | `/setup/logs`                       | 五来源日志聚合，取最后 100 条                      |
| 8  | POST | `/setup/create-admin`               | 真路径建管理员（落库）                            |
| 9  | POST | `/setup/start-runtime`              | 启动 runtime + PID 文件                    |
| 10 | POST | `/setup/stop-runtime`               | 按 PID 精确终止                             |
| 11 | POST | `/setup/restart-runtime`            | 精确停止后重启                                |
| 12 | GET  | `/setup/check-runtime`              | 裸对象安装状态                                |
| 13 | POST | `/setup/install-runtime`            | 介质落地（原子 + 快照）                          |
| 14 | GET  | `/setup/read-runtime-env`           | 读 `.env`（未装 500 / 无文件 404）             |
| 15 | POST | `/setup/save-runtime-env`           | 行级 in-place 更新                         |
| 16 | POST | `/setup/generate-ssl`               | openssl 单路径生成证书                        |
| 17 | POST | `/setup/save-ssl`                   | 备份后写入证书                                |
| 18 | GET  | `/setup/devkit/components`          | 8 组件 + `recommended` + `reason`        |
| 19 | POST | `/setup/devkit/install`             | 按 ID 子集安装                              |
| 20 | GET  | `/setup/devkit/verify`              | 自检汇总 `{id,status,actual,expected,fix}` |

### 6.2 关键 API 详细设计

#### 6.2.1 `GET /healthCheck`

- 响应：`HTTP 200`，`Content-Type: text/plain`，body 严格 `success`（无引号/无 BOM/无换行）
- 错误码：无（服务未起则由调用方连接失败）
- 对应 AC-023/036/037

#### 6.2.2 `POST /setup/create-admin`

- 请求：`{email, username, password, name?}`
- 响应 200：`{code:200, message:"管理员账号创建成功", user:{id,name,username,email}}`
- 响应 400：`{code:400, message:"请填写完整的管理员账号信息" | "该邮箱已被注册" | "该用户名已被使用"}`
- 响应 500：`{code:500, message:"无法读取数据库配置" | <数据库错误> | <回读自校验失败原因>}`
- 对应 AC-107~119

#### 6.2.3 `POST /setup/test-config`

- 请求：`{dbHost, dbPort, dbName, dbUser, dbPassword?}`
- 默认响应 200：`{code:200, message:"数据库连接测试<成功|未通过>：<说明>", probe:{method:"psql"|"port"|"none", reachable:<bool>, detail:<string>}}`
  - 说明文字在 `reachable=false` 时**禁止写成"成功"**（AC-066）
- `--truthful` 且 `reachable=false`：HTTP 非 200 + `fix` 命令（AC-065）
- 对应 AC-062~066

#### 6.2.4 `GET /setup/check-runtime`（裸对象契约）

- 响应 200：`{installed, path, runtimeDir, releaseDir, version, hasEnv, message}` —— **不含 `code` 字段**（AC-025、`research.md:59`）
- `version` 取自 `release/VERSION` 的 `AGENTSKILLS_RUNTIME_VERSION=` 行；缺失时为空串，**不得编造**（§6.6.6）


#### 6.2.5 `POST /setup/install-runtime`

- 请求：`{force?: bool, runtimeVersion?: string}`
- 响应 200：`{code:200, message, installed, path, runtimeDir, releaseDir, version, hasEnv, source:"local"|"remote"}`
- 已安装且 `!force` → 直接返回已安装信息，不重复落地（AC-079）
- 对应 AC-076~089

#### 6.2.6 `GET /setup/read-runtime-env`

- 未安装 → `HTTP 500` + `{code:500, message:"尚未安装 runtime"}`
- 已安装无 `.env` → `HTTP 404`
- 成功 → `{code:200, config:<原始键值对>, dbConfig:{host,port,database,user,password}, envPath:<路径>}`
  - `dbConfig.password` 在日志侧脱敏，响应体按既有契约返回（AC-018）
- 对应 AC-027/090

#### 6.2.7 `POST /setup/generate-ssl`

- 请求：`{domain}`
- 成功 200：`{code:200, certPath, keyPath, domain}`
- 失败：非 200 + `{code:<非200>, message:"openssl 不可用：…", fix:"winget install ShiningLight.OpenSSL.Light …"}`，**磁盘上不产生任何证书文件**
- 对应 AC-096~098

#### 6.2.8 `GET /setup/devkit/verify`

- 响应：`{code:200, data:[{id,status,actual,expected,fix}], summary:{total, passed, failed, manual}}`
- 任一项非 `pass` 时，CLI 侧退出码非 0（HTTP 侧仍 200，由 `summary` 表达）
- 对应 AC-132~134

### 6.3 M18 新增端点（**跨子工程**，落在 runtime `src/app/`，冻结区有限豁免）

> 以下端点**不属于 installer 工程**，是 M2「runtime 自述能力」的落地物，由 T054 / T055 在 `apps/agentskills-runtime/src/app/` 实现。列在此处只为**契约对齐**，避免与 §6.1 的 installer 端点混淆。详见 §4.13.3。

| # | 方法 | 路径                                | 归属             | 说明                                                  | 对应 AC  |
| - | -- | --------------------------------- | -------------- | --------------------------------------------------- | ------ |
| 1 | GET | `/api/v1/health`（**既有，复用不新增**）    | runtime        | 状态；`chatModel.available` 判据须真实探测（N-5 修复，§4.13.5）     | AC-269 |
| 2 | GET | `/api/v1/uctoo/config/*`（**既有，复用不新增**） | runtime        | 配置；不得另建等价端点                                          | AC-269 |
| 3 | GET | 运行日志读取（新增，豁免 1/2）                 | runtime（T054）  | 只读 + 分页 + 限量 + 防目录穿越；**禁**用业务表查询冒充                  | AC-267 |
| 4 | GET | 运行环境检测（新增，豁免 2/2）                 | runtime（T055）  | **复用** `system-env-capability` 采集器，只补运维特有项；**禁**列 Node.js | AC-268 |
| 5 | —  | 启停（`serve --manage`）              | **installer**（T056） | **不在 runtime**；进程不能自举，管控者必须外置                       | AC-271 |

---

## 7. 接口设计

### 7.1 内部接口（模块间契约）

| 提供者                              | 接口                                                                                                 | 消费者                                  | 说明                                     |
| -------------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------ | -------------------------------------- |
| `platform/subprocess_timeout.cj` | `runCapped(cmd, args, cap!, cwd!, env!): RunResult`                                                | `probe`、`ssl`、`media`、`devkit`、`net` | 唯一允许拉外部命令的出口；强制 `stdin=Discard`        |
| `platform/subprocess_timeout.cj` | `fullEnv(extra): HashMap<String,String>`                                                           | 所有带 `env!` 的调用点                      | `HashMap(getVariables())` + 叠加（§4.3.3） |
| `platform/process_table.cj`      | `listByImage(name): Array<ProcEntry>`、`killByPid(pid, escalate!): KillResult`、`isAlive(pid): Bool` | `stop/restart-runtime`、占用诊断          | 唯一允许终止进程的出口                            |
| `platform/net.cj`                | `probePortOccupant(port): ?PortOccupant`、`tcpReachable(host, port, cap!): Bool`                    | `bootstrap`、`probe`、`test-config`    |                                        |
| `platform/probe.cj`              | `probeDependency(name, versionCmd, versionArgs, port, image): ProbeResult`、`probeMethodCode(m): String` | `services/envcheck.cj`（唯一消费者）    | 版本命令 → 端口 → 进程，记录 `method`；原在 `core/`，v1.8 下沉（§4.2.4 包依赖约束） |
| `services/envcheck.cj`           | `environmentTargets(): ArrayList<EnvTarget>`、`checkEnvironment(): EnvCheckResult`                  | `cli/env_check.cj`、`handlers/env.cj` | **环境自检唯一实现**：CLI 与 HTTP 共用（§4.2.4 / R-42） |
| `core/state.cj`                  | `open()` / `advance(step)` / `markFailed(step, reason)` / `setDevkit(id, status)`                  | 全部步骤                                 | 原子写                                    |
| `core/atomic.cj`                 | `stage()` / `verifyStaging()` / `snapshot()` / `switch()` / `rollback()`                           | `media`、`devkit`                     | staging→rename→previous                |
| `core/winfs.cj`                  | `replaceOrDefer(target, staged): ReplaceOutcome`、`runGc(): GcReport`                               | `atomic`                             | §4.4.2                                 |
| `services/db.cj`                 | `withConn<T>(f)`、`existsByEmail/Username`、`insertAdmin`、`readPasswordById`                         | `admin` handler                      | 连接必释放                                  |
| `services/bcrypt_admin.cj`       | `hashPassword(plain): String`（归一前缀）、`verifyPassword(plain, hash): Bool`                            | `db`、回读自校验                           | §4.7.5                                 |
| `services/envfile_service.cj`    | `parse(content): Map`、`readRuntimeEnv()`、`upsert(content, key, value)`                             | `envfile` handler、`db`（取连接参数）        | 保留注释/空行                                |
| `services/ssl_service.cj`        | `generateSelfSigned(domain)`、`saveCert(crt, key)`                                                  | `ssl` handler                        | openssl 单路径                            |
| `services/media.cj`              | `locate()`、`stage()`、`verify()`、`install(force!)`                                                  | `runtime` handler                    | 本地优先                                   |
| `services/download.cj`           | `fetchResumable(url, target, expectedSha256)`、`verifySha256(path)`                                 | `devkit` DK-1                        | `.part` + `.part.meta`                 |
| `services/devkit/*`              | `components()`、`install(ids)`、`verify()`、`init()`                                                  | `devkit` handler、CLI                 |                                        |
| `cli/report.cj`                  | `emit(json!)`、`exitCodeOf(items): Int64`                                                           | `main`                               | 退出码取 max                               |
| `util/redact.cj`                 | `mask(secret): String`                                                                             | 所有日志与报告出口                            | 口令/API Key/私钥                          |

### 7.2 外部接口

| 外部系统                | 接口                                                                                                                             | 方向 | 契约                                     |    |                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------ | -- | -------------------------------------- | -- | --------------------------------------------- |
| 安装向导页               | `GET /healthCheck`、\`/install.html                                                                                             | js | css`、`/api/setup/*\`                   | 入站 | `install.js:4` 硬编码 `http://localhost:3000`，禁改 |
| Vue 管理组件            | `/api/setup/*`（经 `farm.config.ts:49-63` 代理，`pathRewrite:{'^/api':''}`）                                                         | 入站 | 双前缀并存（AC-026）                          |    |                                               |
| PostgreSQL          | `PgDatasource` 直连 + `psql -c`、`psql -f`                                                                                        | 出站 | 只写既有表                                  |    |                                               |
| Redis               | 端口 6379/6380/6381 探测                                                                                                           | 出站 | optional，不阻断                           |    |                                               |
| agentskills-runtime | `GET http://127.0.0.1:8080/api/v1/health`                                                                                      | 出站 | 连续 3 次 200 判可退役（`src/app/main.cj:698`） |    |                                               |
| 系统命令                | `node --version`、`psql --version`、`redis-cli --version`、`openssl req …`、`netstat -ano`、`tasklist`、`taskkill /PID`、`powershell` | 出站 | 全部经 `runCapped`，cap ≤5s（openssl/导库除外）  |    |                                               |
| 仓颉官方 SDK 源          | HTTPS GET + `Range`                                                                                                            | 出站 | 仅 DK-1；SHA256 必校                       |    |                                               |
| 系统设施                | `hosts` 文件、用户/系统环境变量（`setx`）                                                                                                   | 出站 | 提权失败显式降级                               |    |                                               |

---

## 8. 安全设计

### 8.1 凭据处理

- 口令仅以 bcrypt cost 10 单向哈希落库；明文不写入任何文件、日志或响应（AC-013）。
- 日志与 `--json` 中，数据库口令、API Key、私钥内容一律经 `util/redact.cj` 脱敏（AC-014/018）。
- 子进程传密：通过 `fullEnv({"PGPASSWORD": pwd})` 注入，不出现在命令行参数中（避免被进程表看到）。

### 8.2 文件权限

`.env`、SSL 私钥、含凭据的配置文件写出后，将访问权限限制为当前用户可读写（AC-015）。实现要点：写出后立即收紧；失败须在响应与状态文件中留痕（不得静默）。

### 8.3 监听范围

默认绑定 `127.0.0.1`（AC-016）；`HttpServerConfig.tlsConfig` 默认 `None`（明文），仅在用户显式提供证书且证书有效时启用 HTTPS。

### 8.4 数据结构冻结

SQL 语句为**常量字符串**，仅含 `uctoo_user`/`db_info` 既有表与既有列；不存在 `CREATE TABLE`、`ALTER TABLE`、`ADD COLUMN` 等语句（AC-017）。此条写入 §11 防回退 R-08。

### 8.5 进程与删除的最小权限

- 不批量杀进程（AC-011），不写系统注册表，不代用户提权；
- 延迟删除仅作用于安装器自己管理的路径（`<installRoot>` 之下），绝不越界删除。

### 8.6 审计

写数据库、写环境变量、写 hosts、回滚、删除快照五类关键动作，各生成一条含时间戳与结果的结构化审计记录，落盘并可被 `--json` 读出（AC-022）。

---

## 9. 性能设计

| 指标                      | 目标                    | 达成手段                                                                             |
| ----------------------- | --------------------- | -------------------------------------------------------------------------------- |
| `/healthCheck` P95      | ≤200 ms               | 内联 handler，不触磁盘/网络/子进程（AC-001）                                                   |
| 冷启动到可服务                 | ≤3 s                  | 启动路径无网络、无子进程、无 DB 连接（AC-006）                                                     |
| `check-environment` 总时长 | ≤15 s                 | 三项并行协程；单项 `cap=5s`（AC-002/057）                                                   |
| 介质落地                    | 离线 ≤180 s / 联网 ≤300 s | 本地优先；下载走 `.part` 续传；超时即终止并清理（AC-003）                                             |
| 常驻内存                    | ≤200 MB               | 单进程、无内置 SDK/源码树；日志流式写盘（AC-004）                                                   |
| 单次 bcrypt 哈希            | ≤3 s                  | 依赖逐个显式 `-O2`；`blowfish` 带 `--int-overflow=wrapping`（根 `cjpm.toml:3-7,39`；AC-005） |

**并发模型**：`HttpServerConfig.concurrent = true`（每连接独立协程）；探测类任务用仓颉协程并行 + `Mutex` 保护结果容器（`std.sync.Mutex` 可重入且有 `tryLock()`）。

**字符串与遍历的注意点**（写入防回退 R-05）：仓颉 `String` 为 UTF-8，按字节切片会截断中文字符 → 所有可能含中文的解析一律先 `toRuneArray()`；`std.fs.Directory.walk` **非递归**，目录遍历（如统计 `skills/CangjieSkills` 文件数、清理 `.staging`）必须自行递归。

---

## 10. 部署设计

### 10.1 部署架构

```
开发机（人工执行 cjpm build）
   └── cd apps/agentskills-runtime/installer && cjpm build
         └── target/release/bin/ucInstaller.exe
                │  出包脚本复制：stdx DLL + libcrypto-3-x64.dll + libssl-3-x64.dll
                │              + assets/install/{html,js,css} + .env.example
                ▼
        dist/ucInstaller-win-x64/          ← 单一目录，可直接拷贝
                │
                ▼
目标机：双击 start-installer.bat（或 ucInstaller.exe）→ :3000 → 浏览器向导 → S0..S8 → 自退役
```

### 10.2 环境配置

| 配置项     | 来源                                      | 默认          | 说明                                   |
| ------- | --------------------------------------- | ----------- | ------------------------------------ |
| 监听端口    | `--port`                                | 3000        | 与 `install.js:4` 硬编码一致；不可用时非零退出，不换端口 |
| 监听地址    | 固定                                      | `127.0.0.1` | AC-016                               |
| 安装根目录   | `--install-root`                        | 进程 CWD      | 决定 `release/`、`previous/`、状态文件位置     |
| 离线模式    | `--offline`                             | 关闭          | 关闭远端介质来源                             |
| 真实语义    | `--truthful` / `--truthful-metrics`     | 关闭          | §5.3 假成功处置                           |
| 复刻伪造日志  | `--legacy-fake-logs`                    | 关闭          | 默认返回空数组                              |
| DevKit  | `--with-devkit[=ids]` / `--devkit-only` | 未启用         | M11                                  |
| SDK 本地包 | `--sdk-path`                            | 无           | 同样走 SHA256 校验                        |
| 自动退出    | `--auto-exit`                           | 关闭          | 退役判据满足即退出码 0                         |
| 系统级环境变量 | `--system-env`                          | 用户级         | AC-160                               |

### 10.3 构建与出包（人工执行，AI 不跑）

```
1. cd apps/agentskills-runtime/installer
2. cjpm build                      ← 人工在独立终端执行并回传日志（AC-029）
3. 出包：复制 target/release/bin/* 与 stdx DLL 到 dist/ucInstaller-win-x64/
        并**重命名 OpenSSL DLL 为 libcrypto-3-x64.dll / libssl-3-x64.dll**
4. 校验：ucInstaller.exe verify --json   ← 检查 assets 与 DLL 齐备（退出码 0 方可发布）
```

### 10.4 兼容性清单（发布前逐条核对）

- [ ] `GET /healthCheck` 响应体 `Trim()` 后严格等于 `success`
- [ ] 默认端口 3000；`install.js:4` 未被修改
- [ ] CORS 头含 `Access-Control-Allow-Origin: *`，OPTIONS 预检通过
- [ ] `/api/setup/*` 与 `/setup/*` 均可访问
- [ ] `check-runtime` 返回体不含 `code` 字段
- [ ] `read-runtime-env` 未安装返回 500、无 `.env` 返回 404

---

## 11. 防回退约束

> 每条给出「禁止复现的问题 + 判据」。判据必须是可执行、可断言的检查。

| 编号       | 禁止复现的问题                                                                                            | 判据（如何判定未复现）                                                                                                                                              |
| -------- | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **R-01** | 把 `libs/hyperion` 当作 HTTP 服务器使用（它是 TCP 框架）                                                         | `installer/src/**` 中不存在 `import hyperion.transport` / `hyperion.*` 的 HTTP 用法；HTTP 一律 `import http_lib.*`。判据文件：`skills/../libs/hyperion/README.md:1`      |
| **R-02** | 改根 `cjpm.toml` 的 `output-type` 或 `compile-option`                                                  | `git diff` 对根 `cjpm.toml` 中第 7 行（`compile-option`）与第 11 行（`output-type`）无改动（AC-032）                                                                      |
| **R-03** | 改 `src/app/` 下任何文件（含鉴权白名单）                                                                         | `git status -- src/app/` 无新增/修改（AC-031）                                                                                                                  |
| **R-04** | 调用 `launch/execute/executeWithOutput` 时传 `environment` 却未先 `HashMap(getVariables())`，导致子进程 PATH 丢失 | 全仓搜索 `environment:` 调用点，每一处必须形如 `fullEnv(...)`；`fullEnv` 内第一行必须是 `HashMap(getVariables())`                                                               |
| **R-05** | 用 `executeWithOutput` 承担长任务（它无 `timeout!`），或用字节切片解析中文、或用 `Directory.walk` 当递归遍历                    | 长任务一律 `runCapped`；含中文解析处必有 `toRuneArray()`；递归遍历为自写函数。判据：grep `executeWithOutput` 的 `cap` 使用点数为 0                                                         |
| **R-06** | `taskkill /F /IM node.exe` 或任何按镜像名批量终止                                                             | grep `taskkill` 出现处必须同时含 `/PID`；代码中不存在 `/IM` 参数（AC-104）                                                                                                  |
| **R-07** | `generate-ssl` 降级写伪 PEM（base64 域名拼进证书体）                                                            | `services/ssl_service.cj` 中不存在任何字符串拼接生成 `-----BEGIN CERTIFICATE-----` 的代码；openssl 失败路径后磁盘上无 `server.crt`/`server.key`                                    |
| **R-08** | 新建数据库表或列                                                                                           | 全仓 SQL 常量串中不存在 `CREATE TABLE`、`ALTER TABLE`、`ADD COLUMN`（AC-017）                                                                                         |
| **R-09** | `create-admin` 返回合成 ID 不落库（假路径）                                                                    | `handlers/admin.cj` 只有一条成功返回路径，且必经 `insertAdmin` + 回读自校验；返回体含真实 `user.id`（AC-108/118）                                                                    |
| **R-10** | `test-config` 无证据地返回"成功"；`service-status` 无采样就填随机数；`logs` 无来源时伪造两条                                 | 默认开关下：`probe.reachable=false` 时 `message` 不含"成功"；`--truthful-metrics` 下随机数生成器不被调用；默认 `logs` 返回 `[]`，伪造路径仅在 `--legacy-fake-logs` 下可达且响应含 `synthetic:true` |
| **R-11** | 目标文件被占用时直接宣告安装失败或留下半装状态                                                                            | 存在 `.installer-gc.json` 与 `.pending` 机制；构造占用场景后 `.install-state.json` 相应步骤为 `failed` 且 `releaseDir` 保持安装前状态（AC-007/088）                                  |
| **R-12** | 状态文件非原子写导致半截内容                                                                                     | 所有写入走 tmp+rename；`grep` 不存在对 `.install-state.json` 的直接 write（AC-010）                                                                                     |
| **R-13** | 诊断日志写 stdout（占用 L3 stdio RPC 通道）                                                                   | `util/log.cj` 的诊断出口只写 stderr；`--json` 时 stdout 仅一份 JSON（AC-019/165/034）                                                                                  |
| **R-14** | 安装器执行 `cjpm build`                                                                                 | `installer/src/**` 中不存在字符串 `"cjpm build"`（除人工清单文本常量外，且该常量不参与任何执行路径）（AC-029/154）                                                                          |
| **R-15** | stdx/OpenSSL DLL 文件名不对齐导致秒退                                                                        | 出包校验：`bin/` 目录同时存在 `libcrypto-3-x64.dll` 与 `libssl-3-x64.dll`；`devkit verify --json` 的 DK-2 项为 `pass`（AC-159）                                            |
| **R-16** | 修改前端 `install.js` / `install.css` / `install.html` 或 4 个 Vue 组件                                    | `git status` 对 `apps/web-admin/public/install.*` 与 4 个 `.vue` 无改动（AC-028）                                                                            |
| **R-17** | 缺失成功证据仍宣告安装成功                                                                                      | 每个 `Sn` 的 `gate()` 必须返回可观测证据；`verify --json` 任一项非 `pass` 即退出码非 0（AC-012）                                                                                 |
| **R-18** | 断点续装重放产生重复账号/重复目录/重复 `.env` 条目                                                                     | 重放后：S5 走查重返回 400；`releaseDir` 唯一；`.env` 中同一键仅一行（AC-124）                                                                                                  |
| **R-19** | 把 `magic.*` 宿主包引入 installer 子工程                                                                    | `installer/cjpm.toml` 的 `[dependencies]` 中不存在指向 `../../src` 或宿主包的条目；`installer/src/**` 无 `import magic.`                                                 |
| **R-20** | 依赖未逐个声明 `-O2` 导致 bcrypt 超时                                                                         | `installer/cjpm.toml` 中 `blowfish` 依赖必须含 `-O2 --int-overflow=wrapping`；实测单次哈希 ≤3 s（AC-005）                                                               |
| **R-21** | bcrypt 前缀与 nestJs 不互认（`$2b$` vs `$2a$`）                                                             | 安装器写入前统一归一为 `$2a$10$`；`verify` 侧两种前缀均接受。**禁止修改 vendored `libs/blowfish-cj/src/bcrypt.cj`**——归一动作只发生在安装器侧 `bcrypt_admin.cj` |
| **R-22** | 把**无 git 历史的静态副本**当可提交上游的工作副本；或在**非空的非本仓库目录**里直接 clone/覆盖                                              | ① 安装器源码中**不存在** `.SOURCE_PROVENANCE` / `offline-copy` / `gitHistory` / `--source-offline` / `--offline` 任何字符串（单路径已取消离线兜底）；② S-c2/S-c3 目录默认退出码非 0；③ 安装器源码中**不存在** `git checkout .` / `git reset --hard` / `git clean` 任何字符串——开发者工作副本只可被 clone/fetch，绝不可被安装器丢弃改动 |
| **R-23** | S8 初始化打到**发行版安装目录**（或其它非 `devSourceDir`）                                                            | ① I1~I6 的子进程 `workingDirectory!` 取值来源为 `devSourceDir` 单一变量；② `skills/devkit_smoke/` 生成在 `<devSourceDir>/skills/` 下；③ 进入 S8 前断言 `devSourceDir` 与 `releaseDir` 互不嵌套 |
| **R-24** | seed 里出现来源环境的真实账号标识（作者 uuid 随仓库公开）                                                                  | 导出产物中不存在任何 `uctoo_user` 真实主键字面量；身份列取值一律为 `{{principal:…}}` / `{{agent:…}}` 或该列自身合法值（AC-188~190） |
| **R-25** | 导入后"表数达标但数据无归属"（悬空引用）                                                                              | 导入完成判据是**悬空引用数 == 0**，不是表数；校验 SQL 对每个身份列 `count(*) where c is not null and c::text not in (select id::text from uctoo_user)` 必须为 0（AC-196） |
| **R-26** | 导入后"能建表却不能用"（菜单空 + 403）                                                                             | RBAC 补种后必须以超管身份取得**非空**菜单树；空即判定导入未完成（AC-199/200） |
| **R-27** | 用 UPDATE 事后修身份（留下半截中间态）                                                                             | 重绑定必须是**字符串级重写**（一次扫描，零 UPDATE）；安装器源码中不存在针对身份列的 `UPDATE … SET creator` 语句（AC-194） |
| **R-28** | 按行或按 `);` 切分 SQL（含内嵌换行的文本列被截断）                                                                       | 解析必须引号感知单遍扫描；实测 4,002 条语句非单行，含中文时按 `toRuneArray()` 处理（AC-206/207） |
| **R-29** | 把 `agents.id` 当 `uctoo_user.id` 用（双命名空间混淆）                                                           | `agent_id` 列必须解析为 `agents.id`；占位符形式区分 `{{principal:…}}` 与 `{{agent:…}}`；安装器源码中存在显式命名空间声明且两者不可互换（AC-217~219） |
| **R-30** | 创建演示/测试/哨兵账号                                                                                        | 初始环境账号数恒为 2；`uctoo_user` 中不出现 `liming`/`wangfang`/`chenwei`/`liuyang`/`zhaoxue`/`test1` 等名（AC-215/216） |
| **R-31** | 主 agent 账号缺双向指针（任一侧为空）                                                                               | `uctoo_user.agent_id` 与 `agents.user_id` 同时非空且一致；顺序为 A2 → A6 → 回填 A2.agent_id（AC-214） |
| **R-32** | 导出默认全量（黑名单式排除）导致业务数据泄漏                                                                                | 策略文件 `defaultTier` 恒为 `structure-only`；安装器/导出器源码中不存在"未声明表也导数据"的分支（AC-221） |
| **R-33** | 发布版基线含 `DROP TABLE` 或含 `db_info` 派生数据                                                                | 产物中不存在 `DROP TABLE` / `TRUNCATE` / `DELETE FROM`；不存在 `INSERT INTO …"db_info"`（AC-232/233） |
| **R-34** | 把**文件系统同步目标表**（`agents` / `agent_skills`）的数据写进 seed——启动即被 upsert 覆盖或软删下线，且旧基线里的 `source_path` 还被手工换成非法路径 | ① 策略文件 `sync-derived` 必含这四张表；② 导出门禁 `forbidSyncDerivedRows`：放行表中出现 `source_path` 非空的行即失败（AC-240/243/244）；③ 产物中不存在 `INSERT INTO …"agent_skills"` |
| **R-35** | 把**`.env` 镜像行**（`config` 中 `env_key` 非空）写进 seed——首次启动被 `ConfigSyncHandler` 无条件覆盖，还会造成"库里有值、`.env` 里没有"的不一致态 | ① 策略 `bootstrapRowPredicates.config = "env_key IS NULL"` 与 `runtime-generated.config` 同时声明；② 产物中 `config` 数据行数 == 17（AC-245/247）；③ 导出报告分别列出保留与被剔除的行数 |
| **R-36** | 初始数据含**真实凭据/密钥/令牌**（实证：`config` 中有 `ghp_…`/`sk-…`/`fc-…` 与含密码的 `post…` 连接串，而 `is_sensitive` 全表 0 行标记） | ① 导出期 E4.5 脱敏强制；② 门禁 `failOnUnsanitizedSensitiveColumn`：敏感列清单命中的列其导出值必须为 `{{secret:…}}` / `{{env:…}}`（AC-248/252）；③ `secretScan` 含 `sk-`/`ghp_`/`fc-`/`postgres://`/`jdbc:`（AC-226） |
| **R-37** | 脱敏占位符在导入期被**猜值填充**，或被呈现层当作可用字面值 | ① `{{secret:…}}` / `{{env:…}}` 导入期不解析（AC-254）；② 呈现层凡匹配占位符形态一律显示"未配置"并给补齐入口（AC-255）；③ 占位符前缀与身份占位符不同，文本层面可区分（AC-253） |
| **R-38** | **纯正则自动脱敏**误伤统计列（实测 `*total_tokens`/`prompt_tokens`/`completion_tokens`/`avg_tokens` 被"令牌"类正则命中） | ① 敏感列以清单为首要依据；② 正则命中但清单未收录的列不得直接按敏感处理，必须在报告中列出供人工确认（AC-258/259）；③ 报告缺该项即判定导出未完成 |
| **R-39** | **让 runtime 自行启停**（"停止自己再启动自己"）—— 进程不能自举，退出后无执行体可执行启动；一旦宣称支持即为不可实现的假契约 | ① runtime 侧**不得**提供或宣称 `start`/`stop`/`restart` 自身的能力（AC-271）；② 启停一律由**运行系统之外的管控者**提供：web-admin 场景为 `ucInstaller.exe serve --manage`（M3），PC 场景为其既有管控者 `runtime.ts:317`；③ 运维界面在管控者未运行时必须提示"未运行 + 拉起入口"，不得静默失败 |
| **R-40** | **M2 冻结区豁免被扩张**（借"用户已授权"把更多东西塞进 `src/app/`），或**为已有语义另建第二套端点** | ① 豁免范围**仅限两个端点**：运行日志读取（T054）+ 运行环境检测（T055）；超出须另行评审；② 状态与配置**必须复用** `/api/v1/health`（`main.cj:698-717`）与 `/api/v1/uctoo/config/*`（`ConfigRoute.cj:27-39`），**不得**另建 `/api/setup/*` 等价端点（AC-269）；③ 日志端点**不得**以业务表（`crontab_log`/`llm_usage_logs`）查询替代进程日志（AC-267）；④ 环境检测**不得**把 Node.js 列为必需项（N-4：`nestJs/setup.service.ts:25-60` 判据已失配） |
| **R-41** | **健康检查给出"假绿灯"**（N-5 复发）：用"是否拿到惰性壳子"代替"是否真的可用"，导致面板恒显示正常 | ① 健康状态的可用性判据必须探测**通道/资源的实际可用性**（解析默认通道是否成功、探针健康态），**禁止**用 `Option.isNone()` / 对象是否构造出来代替（AC-272）；② 该字段必须能**实际取到 false**：构造一个通道全失效的场景验证其报 `available:false`（AC-273）；③ 凡把某个成员从"真实实例"改为"惰性代理"的重构，**必须同步复查**所有依赖其"是否已就绪"语义的消费点（AC-274） |
| **R-42** | **环境探测出现两套实现**（N-6）：运维端点另写一套探测，与 `system-env-capability` 的采集器各说各话 | ① 环境探测**唯一实现**在 `system-env-capability` 采集器（`.codeartsdoer/specs/system-env-capability/spec.md`），运维端点**复用**其结果、只补运维特有项（AC-275）；② 采集失败返回"部分能力未知"，**绝不阻断启动**（AC-276）；③ 禁止为"给大模型看"和"给人看"分别维护两份探测清单 |

---

## 12. 附录

### 12.1 参考文档

| 文档         | 位置                                                                                              | 用途                                            |
| ---------- | ----------------------------------------------------------------------------------------------- | --------------------------------------------- |
| 需求规格       | `specs/RuntimeNativeInstaller/spec.md`                                                          | REQ/AC 唯一依据                                   |
| 研究主章       | `specs/RuntimeNativeInstaller/research.md`                                                      | 17 端点真值表（§1.2）、形态抉择（§1.5）                     |
| 研究补充章      | `specs/RuntimeNativeInstaller/research-devenv.md`                                               | DK-1~~DK-8 表（§二）、I1~~I9（§五）                   |
| 研究补充章（一）   | `specs/RuntimeNativeInstaller/research-seed-identity.md`                                       | Seed Identity Contract：身份引用实测（§1.2）、导入五步 P0~P4（§3.3） |
| 研究补充章（二）   | `specs/RuntimeNativeInstaller/research-seed-export.md`                                          | 默认库名（§一）、初始账号二元组（§二）、导出机制 SEP 分层与实测账（§三）、第二轮修订（§3.3.1） |
| 研究补充章（三）   | `specs/RuntimeNativeInstaller/research-seed-content.md`                                         | T-F 同步/派生档取证（§一）、`config` 双源与 `.env` 明文密钥隐患（§二）、脱敏 R1~R4 与占位符协议（§三） |
| 研究补充章（四）   | `specs/RuntimeNativeInstaller/research-deployment.md`                                           | **发布形式**（三条分发轨道 D1~D3，主轨道为进既有 `runtime tar.gz`，§二）、**消费形式**（HTTP / CLI `--json` / NDJSON 流式三接口，§三）、**PC 客户端复用**（分层替换，§四）、**替代 nestJs 的 M1~M3 路线与运维期缺口 N-3**（§五） |
| agent 身份源码  | `src/app/services/aip/{AipIdentityService.cj, AgentAuthService.cj}`、`src/app/controllers/uctoo/uctoo_user/UctooUserAuthController.cj` | 主 agent 建号四表、双指针、禁止密码登录取证 |
| `db_info` 派生 | `src/app/services/uctoo/DbInfoService.cj:1026-1047`                                            | 证明 `db_info` 可由 `information_schema` 重算 ⇒ 不随基线分发 |
| 服务范式       | `src/app/core/server/HTTPServer.cj:4-6`                                                         | HTTP 栈归属取证                                    |
| HTTP 库     | `libs/http_lib/src/{server/server.cj, router/router.cj, router/cors.cj, server/file_server.cj}` | 直接依赖 API                                      |
| PG 驱动      | `libs/pgsql-driver/src/{driver.cj, datasource.cj, statement.cj, crypto.cj}`                     | 直连与 SHA256                                    |
| bcrypt     | `libs/blowfish-cj/src/bcrypt.cj:216-256`                                                        | cost 10 与前缀事实                                 |
| 子工程范式      | `skills/llm_channel_tokendance/cjpm.toml`                                                       | 独立 executable + stdx DLL 声明                   |
| std 进程 API | `skills/CangjieSkills/references/api/std/process/index.md`                                      | `launch`/`wait`/`terminate`/`ProcessRedirect` |

### 12.2 缺口与人工确认路径

| 编号  | 缺口                                                  | 人工确认路径                                                    | 未确认时的默认行为                                                          |
| --- | --------------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------ |
| G-A | 归档介质解压能力：仓颉 std 无 tar.gz 原生解压                       | 确认目标机系统 `tar.exe`（Windows 10+ bsdtar）可用；或批准改用 zip；或批准目录复制 | 调用系统 `tar.exe`（先探测可用性），失败回退目录复制；解压失败即报错 + 清理临时产物、不留残骸（spec §4.7.1） |
| G-B | 是否存在除 `install.js` 与 4 个 Vue 组件外的第三方调用方             | 检索仓库内 CI 配置、脚本与接口集合                                       | 保留双前缀与全部既有端点，不删除任何端点                                               |
| G-C | Vue 代理把 `/api/setup/logs` 重写为 `/setup/logs`，与主前缀不一致 | dev server 启动后点开 4 个 Vue 组件页面确认是否取到数据                     | 双前缀并存，两组消费方均不受影响                                                   |
| G-D | `skills/CangjieSkills`（19.1 MB / 7822 文件）再分发授权      | 确认可否随开发套件分发                                               | 默认随开发套件安装；授权不获批则该组件默认不勾选并给出获取说明                                    |
| G-E | `create-admin` 响应体的下游消费方                            | 已核实：`install.js` 唯一生效消费点是 `:1089`，只读 `code`/`message`     | 按真路径返回体 `{code,message,user{id,name,username,email}}` 实现，前端零改动     |


| **G-F（本设计新增）** | `libs/blowfish-cj` 的 `genSalt` 生成前缀为 `$2b$`（`bcrypt.cj:245`），而 AC-112 要求 `$2a$10$` 开头 | 在有 Node 的机器上执行 §4.7.5 的①②③ 交叉验证并留存输出；确认目标是"前缀与 nestJs 一致（`$2a$`）"还是"保留 `$2b$`" | 写入前归一为 `$2a$10$`；`verify` 侧两种前缀均接受。若确认保留 `$2b$`，AC-112 需走需求变更 |  
| **G-G（本设计新增）** | HTTP 基座归属：派单描述指向 `hyperion`，代码事实指向 `http_lib` | 确认 installer 可依赖 `libs/http_lib`（其为根工程已声明依赖，`cjpm.toml:45`） | 采用 `http_lib`；`hyperion` 仅作传递依赖，不直接 import |
| **G-H** | 上游仓库 release tag 的命名前缀未取证 | 执行 `git ls-remote --tags https://atomgit.com/UCToo/agentskills-runtime` 确认前缀（如 `v` / 无前缀） | clone 后默认检出 `main`；版本标识取自仓库内版本文件而非 tag 名 |
| **OQ-S1** | `agents` 表中 8 个 SUB agent（`sdd-researcher` 等，`user_id` 为空）是否算引导数据 | 确认 SUB agent 是否由 SDD 组合在运行时派生（`skills/sdd/COMPOSITION.yaml:53` 表明是） | **归入 T-D**：seed 不导、安装器不建，由 SDD 插件按需注册 |
| **OQ-S2** | 9 张低代码资产表（`component_setting` 145 / `cell` 58 / `vue_editor_*` 49 / `element_components` 6 / `model_pricing` 18 …，合计 0.126 MB）是否算引导数据 | 确认它们是否为启动必需 | **留在 T-E（仅结构）**，但在策略文件中以注释形式保留为候选白名单，需要时一行打开 |
| **OQ-S3** | `entity` 表中 33 行原属 test1 的示例数据如何处置 | 二选一：映射到安装环境超管 / 丢弃 | **默认 `map-to: super_admin`**（保证 `entity` 零悬空）；注意 `entity.creator` 已有 FK `Entity_creatorId_fkey → uctoo_user(id)`，未处置会直接导入失败 |
| **OQ-S4** | 导出机制的实现形态 | 三选一：① 安装器子命令 `ucInstaller.exe db export`；② runtime 侧 `cjpm run --name …dbexport`；③ 独立 `tools/dbexport` | **建议 ①**（复用安装器已有的 DB 连接、凭据、日志与 `--json` 报告骨架，且导出是"版本发布"动作而非运行时能力） |
| ~~**OQ-C1**~~<br>（**已拍板**） | `website.appid`(18) 与 `site.API_URL`(32) 是否按 R2 归一 | 用户拍板：**保留原值**——二者是上一代框架（v3）的配置项，当前 v4 版本暂未消费，但**后续小程序端产品线需要沿用** | **原样保留，不归一、不脱敏**。落地为脱敏策略的 `keepVerbatim` 清单（须带理由），新增 REQ-RNI-105 / AC-260~261；报告中单独成节标注"需复审" |
| ~~**OQ-C2**~~<br>（**已拍板**） | `ConfigSyncHandler` 的 `is_sensitive=false` 与"明文密钥进库"是否在本工程整改 | 用户拍板：**移交 runtime** | 本工程**只做防御**（导出期脱敏 + seed 回填 `is_sensitive`），**不改** `ConfigSyncHandler`；"应支持敏感值遮蔽"作为独立议题移交 runtime，任务清单中以 OUT-OF-SCOPE 标注 |
| ~~**OQ-C3**~~<br>（**已拍板**） | 占位符在界面如何呈现 | 用户拍板：**统一显示"未配置"** | AC-255 已覆盖；实现落在 web-admin 前端（跨工程），安装器侧只需保证占位符形态统一为 `{{ }}` 包裹且不解析 |
| ~~**OQ-C4**~~<br>（**已拍板**） | 6 行无 `source_path` 的 `agent_skills` 是否补建 | 用户拍板：**不补建** | AC-240 已覆盖（T-F 不导）；如需由开发者在自己环境跑一次同步由文件系统生成 |
| ~~**OQ-D1**~~<br>（**已拍板：纳入**） | 是否纳入 **NDJSON 流式进度接口**（`--progress=ndjson`） | 用户拍板：**NDJSON 可以纳入** | 落地为 REQ-RNI-106 / AC-262~266。契约：`stdout` 每行一个 JSON 事件、末行含 `exitCode`、诊断一律走 `stderr`；`--progress=ndjson` 与 `--json` 互斥；不做则 PC 集成只能"盲等"（`research-deployment.md` §3.4） |
| ~~**OQ-D2**~~<br>（**已拍板：采纳**） | `ucInstaller.exe` 放在 runtime 包的哪个目录 | 用户拍板：**采纳 `release/bin/`** | 与 runtime 共用 DLL（281 个）与 CJO，PC 侧既有模块（`runtime-integrator.ts:58`）**零改动**；版本天然同源，不会出现"安装器 v1.2 配 runtime v1.1"的错配。**不再考虑**同级 `installer/` 子目录方案 |
| ~~**OQ-D3**~~<br>（**已拍板：记录到 PC 工程，后续落地**） | `runtime tar.gz` → PC `resources/` 的**手工复制**收归脚本 + 校验 | 用户拍板：**记录到 PC 客户端工程目录，后续完善 PC 客户端时再落地实现** | 已落 `apps/pc-client/docs/RUNTIME_PACKAGE_SYNC_TODO.md`（问题 / 风险 / 建议做法 / 不在本期的原因）。**本工程不实现**，但**需在 PC 集成前完成**，否则安装器进包后「包版本—安装器版本—runtime 版本」三者错配风险放大 |
| ~~**OQ-D4**~~<br>（**已拍板：必须复用**） | PC 是否复用仓颉原生安装器 | 用户拍板：**PC 端必须复用仓颉原生安装器** | 优先级由"建议"升为**强制**。依据 N-2：PC 内置 seed 主 agent uuid `8803ed58…` **0 次**、`505cf909…` 123 次；`AgentAuthService.cj:39-88` 要求 `user_type='agent'` 且 `agents.status=1`。不再需要"先实测确认失败再决定"——直接按复用推进，实测并入 M-8 验收 |
| ~~**OQ-D5**~~<br>（**已拍板：以实测为准**） | PC 冷启动 ≤60 s 目标是否仍成立 | 用户拍板：**以实测为准，不改指标** | 指标维持 ≤60 s；seed ≈0.87 MB + 本地 PG 预估增量秒级，但**以 M-8 实测为准**，实测超标再议，不预先放宽 |
| ~~**OQ-D6**~~<br>（**已拍板：全部退役**） | nestJs 退役范围是否含另外 10 个 Controller（`auth`/`user`/`role`/`menu`/`i18`/`permission`/`application`/`employee`/`mock`） | 用户拍板：**那些全是原 opentiny 开源项目技术栈遗留，agentskills-runtime 已全部实现 NestJS 中的所有功能；NestJS 全部退役** | **退役范围 = 全部**（含该 10 个 Controller），不再是"只替换 `setup` + `healthCheck`"。⇒ 退役判据需增加一条：**逐 Controller 核对 runtime 对应能力已覆盖**（见 §12.2 退役判据补充），避免"以为实现了实际有缺" |
| ~~**OQ-D7**~~<br>（**已拍板：M2 立项，冻结区有限豁免**） | **M2**（runtime 原生承接 `/setup/*`）是否立项 | 用户拍板：**nestJs 完全退役本就是本工程目标；必需由 runtime 承接的功能，允许不受冻结限制补充加入 runtime 宿主** | **M2 立项**，但**豁免范围仅限两个端点**：日志读取（读 `logs/agentskills-runtime.log` 与 `logs/startup-trace.txt`）+ 环境检测（PG/git/磁盘/端口）。状态与配置**复用既有** `/api/v1/health`（`main.cj:698-717`）与 `/api/v1/uctoo/config/*`（`ConfigRoute.cj:27-39`），**不新增**。<br>**启停不在 M2 范围**：进程不能自举（见 `research-deployment.md` §5.3.1），由 M3 的 `serve --manage` 承接 —— **用户已确认"启停的确应该由安装器承载实现"**。<br>**用户追加要求「在 runtime 中实现，需要复核，可能已经实现了，但也许有 bug」** ⇒ 复核结论见 **N-5**：服务监控字段恒为真（假绿灯），配置管理明文返回敏感值，日志与环境两项确认未实现。<br>**环境探测不另起炉灶**：复用既有需求 `system-env-capability`（**N-6**），T055 只实现该采集器并暴露端点。<br>落地 REQ-RNI-107 / AC-267~271；N-5 修复见 REQ-RNI-108 / AC-272~274；探测层唯一性见 REQ-RNI-109 / AC-275~276 |

> **缺口 N-3（已在 gate-design 后闭环）**：`apps/web-admin/src/views/setup.vue` 是**常驻管理页**（四个 Tab + 重启/停止按钮），长期依赖 `/api/setup/*` 打到 `:3000`（`farm.config.ts:48-58`）。而 REQ-9 要求"安装器自退役"——**两者直接冲突**：自退役后四个管理面板一并失效。`nestJs/INSTALL_README.md:20-22` 声称"NestJS 可以停止"，与实际不符。
>
> **用户已拍板：nestJs 完全退役是本工程目标本身**，因此不再采用"绕过冲突"的思路，改为 **M2 + M3 分工彻底解决**（`research-deployment.md` §5.3.1）：
> - **M2**（runtime 自述能力，冻结区有限豁免）：补日志读取与环境检测两个端点；服务状态复用既有 `/api/v1/health`、配置管理复用 `/api/v1/uctoo/config/*`。
> - **M3**（外置管控）：`ucInstaller.exe serve --manage` 承接 `start/stop/restart` —— **进程不能自举**，启停必须活在 runtime 之外，这是物理约束而非设计取舍。

> **缺口 N-4（本轮新发现）：nestJs 的运维实现已与 runtime 失配**。① `setup.service.ts:598` `stopRuntime()` 执行 `taskkill /F /IM node.exe` —— 既**杀不到**仓颉原生 `magic.app.exe`，又会**误杀同机所有 node 进程（含 nestJs 自身）**；② `setup.service.ts:340-351` `getServiceStatus()` 用 `tasklist /FI "IMAGENAME eq node.exe"` 判断 runtime 存活 —— 同样匹配不到，服务监控面板显示的"运行中"**本身就是错的**；③ `setup.service.ts:25-60` `checkEnvironment()` 把 Node.js >= 18 列为必需项，而仓颉 runtime 不依赖 node。这三条说明 nestJs 退役是**修掉已失配的实现**，而非单纯换语言。

> **缺口 N-5（OQ-D7 复核发现）：`/api/v1/health` 的 `chatModel.available` 恒为真**。判据是 `_chatModel.isNone()`（`main.cj:706-713`），但 T010 后 `_chatModel` 恒为 `Some(LazyChatModel(...))`（`main.cj:239/448`），而 `LazyChatModel.init` 只存模型名字符串、构造永不抛错（`lazy_chat_model.cj:27-29`），真实实例要到请求边界才解析 ⇒ **该字段永远 `true`**，即便通道全挂。运维面板"大模型配置是否正常"目前显示的是**假绿灯**，比"没实现"更危险。根因是**语义未随 T010 同步**：`_chatModel` 已从"真实实例"变成"惰性解析器"，判据却还停留在旧语义。正确判据应探测**通道实际可用性**。详见 `research-deployment.md` §5.3.3；修复任务 T058。
>
> **缺口 N-6（环境探测的既有需求）**：环境探测此前**已立需求**，见 `.codeartsdoer/specs/system-env-capability/spec.md`（2026-09-16，"设计稿，待实现"，源码零命中）。它的消费者是**大模型/主 Agent**（产物 `./runtime/capabilities.json` + 注入系统提示词），而运维面板的消费者是人 —— **两个消费者、同一类探测能力**。因此 T055 **不得另写一套探测**，应实现该采集器作为唯一探测层，运维端点复用其结果（详见 `research-deployment.md` §5.3.4）。

#### 退役判据（OQ-D6 拍板"全部退役"后更新）

nestJs 退役范围由「仅 `setup` + `healthCheck`」扩大为**全部 Controller**（用户说明：其余 10 个是原 opentiny 开源项目技术栈遗留，`agentskills-runtime` 已全部实现对应功能）。因此退役判据在原有四条之外**追加第五条**：

1. 17 个安装引导端点逐条响应 JSON 等价；
2. `start-installer.bat` 单端口验收通过；
3. 新环境一次装完能登录、菜单非空、主 agent 自动登录成功；
4. `setup.vue` 四个面板在「M2 自述 + M3 启停」组合下全部可用（含 N-4：服务存活状态须与 `magic.app.exe` 实际存活一致）；
5. **【新增】其余 10 个 Controller 逐 Controller 核对**：`auth` / `user` / `role` / `menu` / `i18` / `permission` / `application` / `employee` / `mock` 等，逐个确认 runtime 侧已有等价能力且端点可达；**任何一项未覆盖即不得退役该项**，须先补实现或明确标注为遗留缺口。

> 判据 5 是"全部退役"与"部分退役"的分水岭 —— 不做这条核对，就会出现"nestJs 删了、功能没了"的事故。

### 12.3 变更历史

| 版本  | 日期         | 作者                | 变更说明                                                 |
| --- | ---------- | ----------------- | ---------------------------------------------------- |
| 1.8 | 2026-10-09 | sdd-doc-revision（CLI/HTTP 分层落地 + 出包图订正） | ㊱ **新增 §4.2.4「能力复用分层：CLI 为基础，HTTP 为封装」（关键设计点 14）** —— 参照 runtime 侧 `crudgen`（`tools/crudgen/crudgen.cj` ← `services/tool/CrudGenService.cj` → `controllers/uctoo/db_info/DbInfoController.cj`）的「能力只写一份、命令行直接调、HTTP 再包一层」范式，把 `check-environment` 的探测实现抽到 `services/envcheck.cj`，CLI（`cli/env_check.cj`）与 HTTP（`handlers/env.cj`）共用，并把三级探测原语从 `core/probe.cj` **下沉到 `platform/probe.cj`**（`core → cli` 已存在，探测留在 `core` 会让 `cli` 反向依赖成环）；㊲ **§4.12.3 出包图订正**：`assets/install/{html,js,css}` 改为 `assets/` **平铺**三文件（依据 `core/paths.cj:72` + `http/routes.cj:29-32`，旧图会让向导页 404），并补画 `start-installer.bat`；㊳ §4.2.3 端点表 #2 调用链同步为 `services/envcheck.cj → platform/probe.cj`；㊴ §7.1 内部接口表同步（删 `core/probe.cj` 行、新增 `platform/probe.cj` 与 `services/envcheck.cj` 两行）；㊵ 确立必填/非必填口径：`node` 标为**非必填**（AC-033：安装器是原生二进制，不得要求 Node），缺失报 `degraded` 且仍给 `fix`，不阻断、不静默 |
| 1.0 | 2026-10-07 | sdd-design-writer | 初始技术设计：两段式首章（存量关系分析）+ 10 节骨架 + 防回退 20 条 + 缺口 G-A~G-G |
| 1.1 | 2026-10-07 | sdd-doc-revision | ① 事实纠错 G-G：HTTP 基座确认为 `http_lib`（`hyperion` 是 TCP 框架），修正 §0 形态决议与 R-01 口径；② G-F 由用户拍板：bcrypt **归一 `$2a$`、改仓颉侧**，落地于安装器侧 `bcrypt_admin.cj`、**不动 vendored 库**，新增 **R-21** |
| 1.2 | 2026-10-07 | sdd-doc-revision | ③ DK-3 改为 **`git clone` 单路径 + 开发者自选目录**（取消离线复制兜底）：新增 §4.10.1.1，更新 DK-3 自检三列，新增 **R-22/R-23**；④ 新增 §4.10.5「初始账号二元组 + Seed Identity Contract + 数据库导出机制 SEP」：默认库名 `uctoo`、双命名空间占位符、T-A~T-E 分层与 0.90 MB 实测账、E0~E7 流水线、七条硬性质；⑤ 新增 **R-24~R-33**；⑥ DK-4/I2/I5 的判据由"表数 ≈207"升级为**表数 + 悬空 0 + 菜单非空**；⑦ 新增缺口 G-H 与 OQ-S1~S4 |
| 1.3 | 2026-10-07 | sdd-doc-revision | ⑧ 新增 §4.10.6「初始数据内容定档与脱敏」：新增 **T-F 同步/派生档**（`agents`/`agent_skills`/`db_connection`/`db_info` 不导，源码依据 `main.cj:329-342`、`SyncManager.cj:51-52,122-123`）；`config` 加**行级谓词** `env_key IS NULL`（102 → 17，依据 `ConfigSyncHandler.cj:64,242-244`）；记录 C-3 隐患（`.env` 明文密钥进库且 `is_sensitive` 全表 0 行标记，**防御性处理、不改 runtime**）；脱敏 **R1~R4** 与两套正交占位符协议；流水线新增 **E3.5 / E4.5**，门禁增至六条；⑨ 新增 **R-34~R-38** 与 OQ-C1~C4；⑩ §4.10.5 的身份引用账由 393 处修正为 **392 处**（`db_connection` 移出） |
| 1.4 | 2026-10-07 | sdd-doc-revision（第五份研究章） | ⑪ 新增研究章（四）`research-deployment.md` 并登记进 §12.1 参考文档；⑫ 记录**发布形式**：安装器不作为新产品线发布，而是作为构件挂进既有 runtime 发布管线（`build_and_release.ps1:74-102` 产出的 `agentskills-runtime-win-x64.tar.gz`），三条分发轨道 **D1（主，随 runtime 包）/ D2（独立 zip，开发者场景）/ D3（PC 免二次分发）**，同一份二进制；⑬ 记录**消费形式**：三类消费方对应三种接口 —— HTTP 静态向导（已有）、CLI `--json` + 退出码（补齐一等子命令清单）、**NDJSON 流式进度（缺口，新增候选约束 C-D1~C-D5）**；⑭ 记录 **PC 客户端复用**结论："外壳不动、数据全交"（保留 NSIS/updater/内嵌 PG/托盘，交出 seed+身份+二元组+`.env`+SSL），并留下 **OQ-D1~D7**；⑮ 记录本轮两处新增缺陷：**N-1**（runtime↔PC 的 tar.gz 手工复制已不同步，419 MB vs 380 MB）与 **N-2**（PC 内置 `uctoov4InitData.sql` 中本机超管 uuid ×123、主 agent uuid ×0）——后者是 PC 复用安装器的首要理由；⑯ 记录**缺口 N-3**（`setup.vue` 常驻管理页长期依赖 `/api/setup/*`，与 REQ-9 自退役冲突），给出 M1/M2/M3 路线对比，**建议 M3**（安装期自退役 + 运维期 `serve --manage` 按需拉起），M2 作为后续独立议题 |
| 1.5 | 2026-10-07 | sdd-doc-revision（OQ-D1~D7 拍板） | ⑰ **OQ-D1 拍板：NDJSON 流式进度接口纳入**（`--progress=ndjson`，stdout 每行一事件、末行含 `exitCode`、诊断走 stderr、与 `--json` 互斥），落地 REQ-RNI-106 / AC-262~266；⑱ **OQ-D7 拍板：M2 立项**——用户明确"nestJs 完全退役是本工程目标"，授权**冻结区 `src/app/` 有限豁免**，但豁免范围**仅限两个端点**（日志读取 + 环境检测），状态/配置复用既有 `/api/v1/health` 与 `/api/v1/uctoo/config/*`，落地 REQ-RNI-107 / AC-267~271；⑲ 确立 **M2 与 M3 是分工不是二选一**：M2 承接 runtime 能自述的，M3（`serve --manage`）承接**启停**——**进程不能自举**（`setup.service.ts:567/598` 为 `spawn`/`taskkill` 进程级管控），这是物理约束；⑳ 新增**缺口 N-4**：nestJs 的 `stopRuntime` 杀 `node.exe`（杀不到 `magic.app.exe` 且误杀自身）、`getServiceStatus` 用 `tasklist` 判存活（状态显示本身就是错的）、`checkEnvironment` 误把 Node.js 列为必需项；㉑ N-3 由"待确认"转为"已闭环"，改为按 M2+M3 分工彻底解决；㉒ 研究章（四）新增 §5.3.1（runtime 原生能力盘点：4 项已具备 / 2 项缺失 / 1 项原理上不可能）与 §5.3.2（N-4） |
| 1.7 | 2026-10-08 | sdd-doc-revision（全量文档一致性复核） | ㉚ **补齐缺失的 §3「系统架构与模块分层」** —— 此前章节自 §2.3 直接跳至 §4，关键设计点之间缺少归属锚点；新增分层结构图、四条分层铁律（平台层是子进程唯一出口 / 接入层不持状态 / 服务层不直接写 stdout / 跨工程改动单独成层）与「模块 ↔ 需求能力面对照」表；㉛ **补齐 §4.13「M18：NDJSON 流式进度与运维能力归位」（关键设计点 13）** —— 此前 M18（REQ-RNI-106~109 / AC-262~276）只登记在 §12.2 与 §11 的 R-39~R-42，**无详细设计**，T053~T058 缺依据；新增三种消费形态互斥关系、事件行四条硬约束、M2 豁免两端点契约、M3 外置管控者形态与 N-5 修复判据；㉜ §1.1 需求面由 16 个扩为 **20 个**（新增 N-06~N-09 覆盖 M14~M18），能力面口径由 M1~M13 更正为 **M1~M18**，复用占比重算为 ≈43%；㉝ §1.5.5 中三处**悬空引用**「闸口决议⑥/⑦」（spec 的⑥是 git clone、⑦是 Seed 身份重绑定，与假成功处置无关）改为可追溯的 `REQ-RNI-014/015/016/028/031~032` 与 §1.4.9 红线；㉞ 文档信息同步：版本 1.0→1.7、需求依据改为 REQ-RNI-001~109 / AC-001~276 / 1982 行、**补齐 4 份此前未登记的上游研究章**；㉟ 补记 v1.5/v1.6 遗漏登记的 **R-39**（启停不得由 runtime 自举）与 **R-40**（M2 豁免仅限两端点、状态/配置复用既有） |
| 1.6 | 2026-10-07 | sdd-doc-revision（OQ-D2~D6 拍板 + OQ-D7 复核） | ㉓ **OQ-D2 拍板：采纳** `ucInstaller.exe` 放 `release/bin/`（与 runtime 共用 281 个 DLL 与 CJO，PC 侧零改动，版本同源防错配），不再考虑同级 `installer/` 方案；㉔ **OQ-D3 拍板：记录到 PC 工程目录、后续落地** —— 已建 `apps/pc-client/docs/RUNTIME_PACKAGE_SYNC_TODO.md`，本工程不实现；㉕ **OQ-D4 拍板：PC 端必须复用**仓颉原生安装器（优先级由"建议"升为**强制**，不再以"先实测确认失败"为前提），实测并入 M-8；㉖ **OQ-D5 拍板：以实测为准，不改指标**（维持 ≤60 s）；㉗ **OQ-D6 拍板：NestJS 全部退役**（其余 10 个 Controller 系原 opentiny 技术栈遗留，runtime 已全部实现对应功能）⇒ 退役判据**新增第 5 条**：逐 Controller 核对覆盖率，任一未覆盖即不得退役该项；㉘ **OQ-D7 复核结果**：新增 **N-5**（`/api/v1/health` 的 `chatModel.available` 恒为真 —— `LazyChatModel` 构造永不抛错致 `_chatModel` 恒 `Some`，判据语义未随 T010 同步，面板显示**假绿灯**）与 **N-6**（环境探测已有需求 `system-env-capability`，不得另起炉灶）；㉙ 新增防回退 **R-41**（禁止用"是否拿到惰性壳子"代替"实际可用性"判据）与 **R-42**（环境探测唯一实现，禁止两套） |
