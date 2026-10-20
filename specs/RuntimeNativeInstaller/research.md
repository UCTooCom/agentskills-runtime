# 研究文档：RuntimeNativeInstaller

> SDD 研究步产出。feature_name = `RuntimeNativeInstaller`，落盘位置 `apps/agentskills-runtime/specs/RuntimeNativeInstaller/research.md`。
> 本文所有结论均标注了证据来源（`文件:行号` 或命令输出），未查实项一律显式标注「缺口」并给出人工确认路径。
>
> **本文档覆盖「发行版安装」（对标 nestJs，§一~§六）。开发者本地开发环境安装与初始化见补充章 `research-devenv.md`**——
> 该部分需求原 nestJs 不覆盖，由用户在研究步闸口追加，逆向归纳自本项目 runtime 本地开发环境。
>
> **闸口决议留痕（gate-research，用户已拍板）**：
> ① 研究结论确认，形态定为「独立 install 应用（仓颉单二进制）」，L3 插件仅作 Stage B 可选薄适配器、本期不做；
> ② `create-admin` **只做真路径（落库），删除假路径**（原 §4.3 末条与 §五决策 3 的"保留假路径开关"方案作废，以本决议为准）。
>
> **闸口决议留痕（gate-design 事实纠错，2026-10-07 追加）**：
> ③ 全文 HTTP 基座由 `hyperion` 更正为 **`http_lib`**。`libs/hyperion/README.md:1` 原文为「Hyperion: 一个支持自定义编解码器的**TCP**通信框架」，**不是 HTTP 服务器**；runtime 实际 HTTP 栈为 `libs/http_lib`（证据：`src/app/core/server/HTTPServer.cj:4-6` 的 `import http_lib.server.{HttpServer as LibHttpServer, HttpServerConfig}` 与 `http_lib.router.{Router, Handler}`；根依赖声明 `cjpm.toml:45`）。`hyperion`（`cjpm.toml:44`）仅作为 `http_lib` 的传递依赖，**安装器不得直接 import 其作为 HTTP 用法**。受影响位置：§2.1、缺口表 G2、§4.2 编排图、§4.3 复用决策、附录 A 依赖清单。

---

# 用户原始需求

> 在 web 项目中有一个退化了的后端应用 `D:\UCT\projects\uctoo\apps\web-admin\nestJs`，目前只用来作为安装 `D:\UCT\projects\uctoo\apps\agentskills-runtime` 的一个引导程序，但是这个退化的引导程序看起来很冗余，请研究一下是否可以在 agentskills-runtime 中采用仓颉原生实现和这个 nestJs 完全一致的引导安装 agentskills-runtime 的功能，或许可以做成一个 L3 进程隔离轨 install 技能插件，但是插件机制好像依赖于 runtime 的正常启动运行，那么或者需要做成一个不依赖 runtime 启动运行的独立 install 应用，由你研究制定超越业界最佳实践的方案。

- 目标：用仓颉原生实现替换 `apps/web-admin/nestJs` 引导程序，功能与 nestJs **完全一致**（逐个端点对齐）。
- 范围（In Scope）：确定目标形态（L3 进程隔离轨插件 vs 独立 install 应用 vs 组合）；盘点可复用的 runtime 侧原生能力；给出超越业界最佳实践的机制清单；产出交接给 spec/design 的最小新建集合。
- 非范围（Out of Scope）：本研究阶段不写实现代码、不改任何 `.cj`/`.ts` 源文件；不执行编译；不改动前端 `install.html/install.js` 现有文案（只识别兼容约束）。
- 关键约束（用户原话隐含，全文守住）：
  1. 必须在「L3 进程隔离轨 install 技能插件」与「不依赖 runtime 启动运行的独立 install 应用」之间做出**有理有据的抉择**或给出组合方案；
  2. 功能与 nestJs 引导程序**完全一致**，逐个对齐，不允许"大致相当"；
  3. 方案要**超越业界最佳实践**，须有明确对标物与可验证的超越点，不许空喊口号。

---

# 研究结果

## 一、现状与定位

### 1.1 与既有相关工程的关系

nestJs 是**一次性引导器**，不是业务后端。`apps/web-admin/nestJs/INSTALL_README.md:7-22` 原文说明了它的存在理由与退役条件：

> "浏览器端的 mock 代码无法执行系统命令（如 `node --version`、`psql --version` 等），也无法访问文件系统。因此，在首次安装时，我们需要启动一个 NestJS 后端服务器来处理：- 环境检测（Node.js、PostgreSQL、Redis 版本检测）…"
> "当 agentskills-runtime 安装完成并正常运行后，NestJS 后端服务器可以停止。"

工程关系判定：**全新实现 + 部分能力复用**。runtime 侧已有 HTTP 服务框架、PG 驱动、bcrypt、配置加载、日志等基础设施（见第二章），可"原样调用/仿写"；业务逻辑层（SetupService 1322 行）需按端点逐个对齐重写，不存在可复用代码。

### 1.2 逐端点语义对齐表（核心事实）

nestJs 契约入口：`src/setup/setup.controller.ts`（146 行，`@Controller('setup')`，全部 `@Public()`），全局前缀 `/api`（`src/main.ts:17`，由 `.env:17` 的 `GLOBAL_PREFIX=/api` 驱动）。共 **16 个声明**，其中 `create-admin` 被声明两次（第 60 行、第 140 行），实现分别落到不同 service 方法——这是本研究最有价值的发现之一。

| # | 端点 | 真实行为（证据） | 依赖的系统能力 | 返回值形态 |
|---|---|---|---|---|
| 1 | `GET check-environment` | `exec('node --version')`(:30)→正则 `v(\d+)\.(\d+)\.(\d+)`(:32)→要求 major≥18(:35)；PostgreSQL 三级降级：`psql --version`(:71)→`netstat -an\|findstr ":5432.*LISTENING"`(:91)→`tasklist /FI "IMAGENAME eq postgres.exe" /FO CSV`(:109)，要求 ≥14(:79)；Redis（**optional:true**, :204）三级降级：`redis-cli --version`(:142)→遍历端口 6379/6380/6381 做 netstat(:161-165)→`tasklist`(:186)，要求 ≥6(:150) | 子进程 exec（带 timeout）、正则、Windows netstat/tasklist | `{code:200,data:[{name,label,passed,current,required,optional?}],message:'环境检测完成'}`(:208-212) |
| 2 | `POST save-config` | 校验 dbHost/dbPort/dbName/dbUser 四必填(:218)，写 `<cwd>/config.json`(:226)，同时刷新内存 `configStore`(:227)。**不写 runtime 的 .env** | 文件读写 | `{code:200\|400\|500,message}` |
| 3 | `GET load-config` | 读 `config.json` 覆盖内存；**读失败仍返回 code:200 并回吐内存默认值**(:257-260) | 文件读写 | `{code:200,data:configStore,message}` |
| 4 | `POST test-config` | 三级：psql `-c "SELECT 1"`(:280)→`powershell Test-NetConnection`(:299)→**兜底无条件返回成功**(:320-324)。即该端点**永不返回失败** | psql / PowerShell TCP 探测 | `{code:200,message:'数据库连接测试成功（…）'}` |
| 5 | `GET service-status` | `tasklist` 查 node.exe/postgres.exe/redis-server.exe；**cpu/memory/uptime 全部是 `Math.random()` 伪造**(:344-347, :366-368, :388-390) | tasklist | `{code:200,data:[{name,status,cpu,memory,uptime}]}` |
| 6 | `GET logs` | 读 `<cwd>/logs/{app,runtime,error,combined}.log` 与 `<cwd>/server.log`(:409-415)；三种时间戳正则(:427,:438,:449)，都不匹配则整行兜底为 info(:460-465)；无日志时吐**两条伪造日志**(:473-488)；最后 `slice(-100)`(:490) | 文件系统扫描 | `{code:200,data:[{id,time,level,message}]}` |
| 7 | `POST create-admin`（controller:60 → `createAdmin`:499） | **不落库**：邮箱正则(:511)、密码≥8 位且含大小写数字符号(:520-537)后，直接返回 `id:'admin-'+Date.now()`(:544) | 无 | `{code:200,data:{id,email,name,role,createdAt}}` |
| 8 | `POST create-admin`（controller:140 重复声明 → `createAdminAccount`:1186） | **真实落库**：先读 runtime .env 拿数据库配置(:1204)→`bcryptjs.hash(password, 10)`(:1221)→`pg.Client` 直连(:1225)→按 email(:1242)、username(:1258)查重→`INSERT INTO uctoo_user (name,username,email,password,auth_provider,status,created_at,updated_at,last_login_time) VALUES ($1..$6, 3×CURRENT_TIMESTAMP)`(:1273-1278)，auth_provider=0、status=1 | PostgreSQL 客户端、bcrypt cost 10 | `{code:200,message,user:{id,name,username,email}}` |
| 9 | `POST start-runtime` | 先 `checkRuntime()`；未装返回 500(:558-563)；已装则 `spawn(runtimePath,[],{cwd:releaseDir,detached:true,stdio:'ignore',windowsHide:true})` 并 `unref()`(:568-577) | 进程 spawn + detach | `{code:200,message,pid,path}` |
| 10 | `POST stop-runtime` | `taskkill /F /IM node.exe`(:598) —— **杀死本机全部 node 进程**，与服务归属无关 | taskkill | `{code:200,message}` |
| 11 | `POST restart-runtime` | `taskkill /F /IM node.exe` + `sleep(2000)`(:622-627) → 若存在 `<cwd>/start-runtime.bat|sh` 则 spawn 它(:629-637)，否则按 pnpm-lock/yarn.lock 判定包管理器跑 `start`(:644-656) | taskkill + 脚本/包管理器 | `{code:200,message}` |
| 12 | `GET check-runtime` | 判据 = 文件 `../node_modules/@opencangjie/skills/dist/runtime/{win\|darwin\|linux}-{x64\|arm64}/release/bin/agentskills-runtime[.exe]` 存在(:678-704)；附加信息 = `release/VERSION` 中 `AGENTSKILLS_RUNTIME_VERSION=` 行(:714-724) 与 `release/.env` 是否存在(:708-709) | 文件系统探测 | **裸对象，不含 code 字段**：`{installed,path,runtimeDir,releaseDir,version,hasEnv,message}`(:729-737) |
| 13 | `POST install-runtime` | 幂等：已装且 `!options.force` 直接跳过(:756)；否则在 `../web` 目录执行 `npx skills install-runtime[ --runtime-version <v>]`，timeout 300000(:774-783)；装完再 `checkRuntime()` 复核。**不执行 cjpm build**：真实动作在 npm 包内，见 1.3 | npm/npx、网络 | `{code:200,message,installed,path,…,output}` |
| 14 | `GET read-runtime-env` | 读 `releaseDir/.env`，逐行跳过注释/空行、按首个 `=` 切分、剥掉成对引号(:848-867)；再用 `parseDatabaseUrl` 正则解析 `DATABASE_URL` 或 `orm_connectionUrl`(:871, :984) | 文件读写、正则 | `{code:200,config,dbConfig,envPath}`；未安装→500，无 .env→**404** |
| 15 | `POST save-runtime-env` | 行级 in-place 更新：命中 key 则保留缩进重写该行(:932-937)，未命中则追加到末尾(:943-948)，最后 join('\n') 写回(:951) | 文件读写 | `{code:200,message,envPath}` |
| 16 | `POST generate-ssl` | 首选 `openssl req -x509 -newkey rsa:2048 -keyout <key> -out <crt> -days 365 -nodes -subj "/CN=<domain>"`(:1034)，输出到 `releaseDir/ssl/`(:1022-1031)；openssl 失败降级 `createSelfSignedCert`(:1122-1131) —— **该降级产物是把 `Buffer.from(domain).toString('base64')` 直接拼进证书体的伪 PEM(:1127)，无效证书** | openssl CLI | `{code:200,certPath,keyPath,domain}` |
| 17 | `POST save-ssl` | 写 `<releaseDir>/ssl/server.crt` 与 `server.key`(:1153-1166) | 文件写入 | `{code:200,certPath,keyPath}` |

> 端点 7 与 8 同名同方法同路径。NestJS 按类内声明顺序向 Express 注册路由，先注册者先匹配，因此 **`declaration order` 决定 `POST /api/setup/create-admin` 实际命中的是第 60 行的假实现 `createAdmin`**（第 140 行的真实现很可能长期不可达）。此为代码事实推演，**需人工确认**：请在有 Node 环境时实际调用该端点验证是否落库。仓颉实现对这两条同名路由的处理策略见 4.3 与第五章决策 3。

### 1.3 `install-runtime` 的技术真相（决定"安装"到底等于什么）

npm 包已实际安装在 `apps/web-admin/node_modules/@opencangjie/skills`（version `1.0.2`，`package.json:3`；内嵌 `runtime.version = "0.0.20"`，`package.json:92`）。其 `dist/index.js` 揭示：

- 安装根目录 = `path.join(__dirname, 'runtime')`，即 `.../node_modules/@opencangjie/skills/dist/runtime`(:52-54) —— 与 nestJs `checkRuntime` 的期望路径**完全一致**（`setup.service.ts:682-692`）。
- `downloadRuntime()`(:104-183)：拼 `<mirror>/v<version>/agentskills-runtime-<platform>-<arch>.tar.gz`(:110-112)，镜像列表为 atomgit 优先、github 兜底(:19-32)，下载→`tar.x` 解压(:139-143)→非 Windows `chmod 755`(:146-148)→无 `.env` 时从 `.env.example` 复制或写默认内容(:149-165)。
- CLI 层 `dist/cli.js:590-627`：`install-runtime` 在已安装时会用 **inquirer 交互式询问是否重装**(:595-606)。这意味着 nestJs 用 `execAsync` 拉起它时，若两侧"是否已安装"判定不一致，进程会等待 stdin 直到 5 分钟超时——**现存隐患**。
- 事实核查命令输出：`ls dist` 只有 `cli.js/index.js` 等 JS 产物、**没有 `runtime/` 子目录**（即当前该机器上的 runtime 尚未通过此路径安装）；而 runtime 仓库本地已存在离线介质 `apps/agentskills-runtime/release/agentskills-runtime-win-x64.tar.gz`。

结论：**安装 = 下载并解压预编译发行包 + 生成 .env，与编译无关**。这为"离线优先 + 本地介质直装"这一超越点提供了直接依据。

### 1.4 前端消费方与接口兼容约束（决定替换方案必须长什么样）

消费方有**两组**，彼此不同：

1. **静态向导页**（主消费方）：`apps/web-admin/public/install.html` + `install.js`（62,188 字节）+ `install.css`。硬编码 `const API_BASE_URL = 'http://localhost:3000'`（`install.js:4`）；启动即轮询 `GET /healthCheck` 且要求响应体文本**严格等于** `success`（`install.js:20-25`，对应 `nestJs/src/health-check.controller.ts:14-16`），30 次 × 2 秒（`install.js:11-12`）。实际调用 12 个端点：check-environment(119/143/167/1503)、service-status(197)、save-config(268)、load-config(296)、test-config(359)、create-admin(384/1089)、check-runtime(450)、install-runtime(464)、generate-ssl(823)、save-ssl(858)、save-runtime-env(881/1011/1669)、read-runtime-env(1557/1579/1600)、start-runtime(1719)。**不使用** `/api/setup/logs`（grep 计数 0）。完成跳转首页 `window.location.href='/'`(:1766)。
2. **Vue 管理组件**（次消费方，经 dev server 代理）：`src/views/components/EnvironmentCheck.vue:44`、`LogViewer.vue:50`、`ServiceMonitor.vue:45`、`ConfigManagement.vue:60/72/92` 使用**相对路径** `/api/setup/*`。代理规则在 `farm.config.ts:49-63`：`target: 'http://localhost:3000'`，`pathRewrite: {'^/api': ''}`，过滤掉 `/api/v1/uctoo`。

> **缺口（需人工确认）**：按 `main.ts:17` 全局前缀 `/api` + `.env:17`，nestJs 实际路由是 `/api/setup/logs`；而代理会把 Vue 组件的 `/api/setup/logs` 转发成 `http://localhost:3000/setup/logs`，路径不匹配。据此推断这组 Vue 组件当前大概率拿不到数据。请人工在 `pnpm start` 后点开对应页面确认。无论结论如何，**仓颉替换实现必须在 3000 端口上同时保留 `/api/setup/*` 前缀语义**，两组消费方才都不会被破坏。

另一硬约束：runtime 自身默认监听 **8080**（`apps/agentskills-runtime/src/app/main.cj:1120-1125`），与安装器端口 3000 不同；runtime 侧可用健康端点是 `GET /api/v1/health`（`main.cj:698`，返回 `{"status":"ok","version":…,"scheduler":…,"chatModel":…}`）与 `GET /api/v1/info`（`main.cj:718`）。

### 1.5 鸡生蛋问题的技术真相（形态抉择的第一性依据）

`main.cj` 的启动时序（命令 `sed -n` 与逐行阅读确认，`main.cj` 共 1191 行）：

```
构造函数 Application.init(:123-964)
  ├ :140  DatabaseConfig.fromEnv()
  ├ :156-167  ORM.initialize() + 试连（try 包裹，失败仅降级）
  ├ :176  dbPool = DatabaseConnectionPool.getInstance(dbConfig)   ← **未在 try 内**
  ├ :239  LazyChatModel / :244-253 ChannelRegistry bootstrap
  ├ :698  router.get("/api/v1/health", …)
  ├ :822-830  AgentRuntimeBridge.loadAllFromDatabase（查库）
  ├ :833-895  **插件系统：PluginHostManager(:840) → loadAll(:858) → ExternalPluginRouteGateway 注册路由**
  └ :960  server.setRouter(router)
main() → Application(...) (:1184) → app.start() (:1185)
  └ :971  server.start()          ← HTTP 监听在此刻才建立
public func start(): Unit (:966-973)
```

据此得到三条确定性结论：

1. **插件宿主初始化处于构造函数中段**（`:832-895`），**严格晚于** DB/ORM/Channel/Agent 引导、**严格早于** `server.start()`（`:971`）。安装器要修的恰恰是 DB 配置与 .env —— 也就是说，"把 DB 修好"是"插件可用"的**前置条件**，而非后置结果。**用户的直觉判断成立，且窗口比直觉更糟**：不只是"runtime 未完全就绪"，而是 runtime 只要构造期任一步抛出（例如 `:1122 Int32.parse(PORT)` 未被 try 包裹、`.env` 里 PORT 写错一个字符即 FATAL，见 `:1186-1189`），插件就从未被加载，安装端点根本不存在。
2. **即便宿主起来了，L3 插件的 HTTP 路由仍穿不过鉴权白名单。** `src/plugin/external_plugin_route_gateway.cj:62-64` 原文："中间件链宿主侧执行：CORS → DeserializeUser → RequirePermission → RowLevel → OperateLog 在网关 handler 前完成"。而 `RequirePermissionMiddleware.isPublicRoute` 是**硬编码白名单**（`src/app/middlewares/auth/RequirePermissionMiddleware.cj:86-126`），当前只放行 `/login`、`/signup`、`/public/`、`/health`、`/api/v1/health`、`/api/v1/info`、`/api/v1/ai/`、`/webmcp/`、`/api/v1/uctoo/lang/` 等；未命中且未登录一律 `401 {"errno":"40100","errmsg":"not login"}`（`:74`）。要让 `/api/setup/*` 免鉴权，必须**新增** `src/app/` 下的白名单分支 —— 直接撞红线"宿主 `src/app/` 是存量冻结、只减不增"。
3. **L3 插件进程不继承宿主环境变量**（红线，亦见 `skills/llm_channel_tokendance/plugin.yaml:15-16` 注释原文："插件**不继承**宿主环境变量，命令行也不带密文。密钥由插件经 `ctx.invoke("host.secret","get",{ref:"env:TOKENDANCE_API_KEY"})` 代取"）。而安装器需要的是**完整的机器视角**：PATH、`PGPASSWORD`、openssl 可用性、任意工作目录、以及对 `node_modules` 之外的文件系统写权限。

### 1.6 业界对标基线（用于第 4.5 节做超越对比）

| 对标物 | 做法（1~2 句） | 本方案可超越处 |
|---|---|---|
| **rustup / rustup-init** | 单二进制自举安装器，`install_bins` 把运行中的可执行文件复制到 `$CARGO_HOME/bin` 并为 toolchain 建代理；Windows 下自更新走 `--self-replace` + 「GC 延迟删除」绕过文件占用；支持 `--default-toolchain none` 的纯离线装 modes（<https://deepwiki.com/rust-lang/rustup/4-self-update-system>）。 | 缺快照式回滚；失败后重跑从零开始；无浏览器向导、无自身可观测寿命管理。 |
| **Supabase CLI** | 单二进制编排全栈，`supabase init/start/status` + `--ignore-health-check` 健康检查；却强依赖 Docker 且 `supabase db push` 非原子，两人并发推送即冲突报错（<https://supabase.com/docs/reference/cli/install>；<https://github.com/supabase/cli>）。 | 缺断点续装、缺安装产物回滚、缺离线优先。 |
| **Docker Desktop Installer (Windows)** | MSI 安装包 + WSL2 前置检测，前置不满足即中止，修复后需重新完整安装。 | 无 resume、无回滚、安装器与运行时资源解耦差。 |
| **Homebrew install.sh** | 一条 shell 脚本引导 git clone 到 `/opt/homebrew`，幂等性靠重复执行兜底。 | 无状态机、无原子性、无回退。 |
| **winget** | 声明式 manifest（YAML）做包安装，交付是"安装别人的包"，不做被装系统的环境预检与修复引导。 | 不承担引导向导职责、无端到端自校验。 |

---

## 二、已有可复用基础设施盘点

> 仅列出与本次任务强相关项。依赖均已在根 `cjpm.toml` 声明，可直接 import。

### 2.1 HTTP 服务端与 SSL
- `libs/http_lib`（`cjpm.toml:45` 已声明，`output-type = "static"`，**未继承父级 `-O2`**）：**宿主真正的 HTTP 服务框架**（HTTP/1.1 + HTTP/2 客户端与服务器）。参考实现 `src/app/core/server/HTTPServer.cj`，其 `:4-6` 原文 import `http_lib.server.{HttpServer as LibHttpServer, HttpServerConfig}`、`http_lib.router.{Router, Handler}`、`http_lib.message.{HttpRequest, HttpResponse}`，其中 `:464` 已打印 `GET /api/v1/info - Service info`，说明路由注册/静态挂载范式可**直接仿写**。
  - **事实纠错**：本文先前曾把 HTTP 基座误记为 `libs/hyperion`，现更正——`libs/hyperion/README.md:1` 原文「Hyperion: 一个支持自定义编解码器的**TCP**通信框架」，它是 `http_lib` 的传递依赖（`cjpm.toml:44`），**不得当作 HTTP 服务器 import**。
- `src/app/middlewares/CORSMiddleware.cj`：宿主已实现 CORS。因前端 `install.js:4` 用绝对 `http://localhost:3000` 跨域调用，CORS 是**硬性必需**，沿用同款实现。
- `libs/jinguissl`、`libs/jinguissl_core`：SSL/TLS 支撑；`main.cj:1152-1179` 给出 HTTPS 模式的证书/私钥路径解析（`CERT_FILE_NAME`/`KEY_FILE_NAME`），安装器的 HTTPS 分支可仿写。

### 2.2 数据库与密码学
- `libs/pgsql`（`main.cj:69` 已 `import pgsql.PostgresDriver`）：`main.cj:144-153` 给出驱动注册范式（`DriverManager.register("postgres", PostgresDriver())`）。安装器 `create-admin` 走直连 DB 的路线由它承载。
- `src/app/utils/auth/BcryptUtil.cj`：默认 `saltRounds = 10`（`:24`），注释 `:14` 明确"与 backend 项目中的 bcryptjs 保持兼容"，`:32` 说明哈希格式 `$2a$cost$salt$hash`。与 nestJs `bcryptjs.hash(password, 10)`（`setup.service.ts:1221`）**逐位对齐**，这是保证两端创建的账号可互登的关键证据。
- `libs/blowfish`（bcrypt）：已单独开 `-O2 --int-overflow=wrapping`，`cjpm.toml` 注释记录了"bcrypt 单次校验约 6800 万次整数运算"的性能根因，说明在 -O0 下哈希一次可能达 7~22 秒；安装器进程须沿用同等优化等级。

### 2.3 配置与 .env 语义
- `src/config/config.cj`：`AppConfig.env`（`:217`）+ `load(path: Path)`（`:33`），注释 `:29-31` 原文：".env 文件中的值会覆盖已存在的系统环境变量，确保 .env 文件是配置的最终权威来源"。安装器的 `read-runtime-env` / `save-runtime-env` 必须与之一致，否则写进去的 .env 被 runtime 读出来语义不同。
- `libs/f_config`、`libs/f_util`、`libs/f_ticktock`、`libs/json4cj`：JSON 序列化、时间格式化（`getLogs` 需要生成 `YYYY-MM-DD HH:mm:ss`）。

### 2.4 进程与文件
- 仓颉 std `std.process`：`executeWithOutput` 支持 `workingDirectory!` / `environment!`，**无 `timeout!`**（红线已知）——对应 nestJs 里 `execAsync(cmd,{timeout})` 的地方必须改用 spawn + 轮询时长的做法。
- 仓颉 std `std.fs` + `std.env`（`getWorkingDirectory`、`getVariable`，宿主已在 `main.cj:183-193` 使用）：承担版本/端口/进程探测与环境补齐。

### 2.5 日志
- `libs/logcj` + `src/log/LogUtils`：`LogUtils` 已在引入套电（水位告警注入见 `main.cj:127-135`）。安装器的 `--json` 日志与 wizard 日志建议先用 `eprintln` + 落盘，保持与 L3 stdout 独占约定一致（即便最终形态不是插件，也留出未来做成插件的可能）。

### 2.6 插件宿主（L3 进程隔离轨）
- `libs/cordis-cj`（`ystyle::cordis_host` / `ystyle::cordis_core`）、`src/plugin/cordis_host_manager.cj`、`src/plugin/external_plugin_route_gateway.cj`：成熟可用，但按 1.5 判定**不作为 Stage A 载体**。
- 生成器先例：`skills/llm_channel_tokendance/plugin.yaml:8-9` 记录了 `cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name llm-channel-tokendance --mode process"` 的骨架生成方式，及其独立 `cjpm.toml`（`output-type = "executable"`，并显式声明 `[target.x86_64-w64-mingw32.bin-dependencies]` 的 stdx DLL 路径）。**这套"独立子工程 + 独立 executable"正是本项目构造第二个二进制的既有先例**，Stage A 直接沿用该范式而不需要动根 `cjpm.toml` 的 `output-type`（当前根包 `output-type = "static"`，`cjpm.toml:11`）。

### 2.7 离线介质
- `apps/agentskills-runtime/release/agentskills-runtime-win-x64.tar.gz`（实测存在），以及 `target/release/bin/agentskills-runtime.exe`（本机已编译产物）。二者构成"离线优先安装"的数据来源。

### 2.8 既有目录占位（免编译举证）
- `apps/agentskills-runtime/specs/RuntimeNativeInstaller/` 目录已存在且为空目录（本次落盘目标），说明该 feature 已在 SDD 流水线上排期。

---

## 三、能力缺口分析（已有 vs 待建）

| 缺口 | 现状 | 待建（本工程范围） | 复用/新建 |
|---|---|---|---|
| G1 16 个 setup 端点的原生实现 | nestJs `setup.service.ts`（1322 行）垄断全部实现；runtime 侧无 `/api/setup/*` 任何路由（grep `src/app/routes` 无命中） | 逐个对齐的端点处理层（含"永不失败的 test-config""随机数的 service-status""两条伪造日志"等**必须复刻的既有行为**） | 新建 |
| G2 3000 端口上的独立 HTTP 服务 | runtime 只有 8080 端口的服务实例（`main.cj:1120-1125`） | 安装器自带 http_lib 服务，`--port` 默认 3000 | 复用 http_lib + 仿写 `HTTPServer.cj` |
| G3 `/healthCheck` 文本契约 | 仅 nestJs `health-check.controller.ts:14-16` 返回 `'success'` | 安装器提供 `GET /healthCheck`，响应体纯文本 `success` | 新建（3 行） |
| G4 静态向导页自托管 | 需同时起 nestJs(3000) + web dev server(3031)（`start-installer.bat:70,98`） | 安装器直接托管 `install.html/install.js/install.css`，单进程可达 | 新建（静态根挂载） |
| G5 Bcrypt  ADMIN 创建 | nestJs 用 `bcryptjs.hash(pw,10)` + `pg` 写 `uctoo_user`（`:1221,:1273`） | 用 `BcryptUtil` + `pgsql` 直连，落同样的列与 `auth_provider=0/status=1` | 复用 `BcryptUtil.cj`、`libs/pgsql` |
| G6 tar.gz 解压 | 仓颉 std 未提供 tar 解压能力；nestJs 借道 npm `tar` 包（`dist/index.js:139-143`） | 三种候选：优先 zip 发行介质；或调用系统 `tar.exe`（Windows 10+ 自带 bsdtar）；或 fallback 到"目录复制安装" | **缺口 → 人工确认**：请确认目标机器 `where tar` 可用，或批准改用 zip 介质 |
| G7 子进程超时 | `executeWithOutput` 无 `timeout!`；而 install 需要 5 分钟超时（nestJs `:782`） | spawn + 状态轮询 + 超时强杀的封装 | 新建（薄封装） |
| G8 安装状态持久化/断点续装 | nestJs 只有内存 `configStore` + 单文件 `config.json`（`:16-23,:226`） | `.install-state.json` 日志式状态机（每个 step 完成写一次） | 新建 |
| G9 原子替换与回滚 | npm 包解压是"直接落位"（`dist/index.js:140-144`），中途失败留残骸 | staging 目录 → 原子 rename → 保留 `previous/` 快照 → `--rollback` 一键回退 | 新建 |
| G10 精确进程治理 | `taskkill /F /IM node.exe` 全杀（`:598`） | PID 文件 + 进程镜像交叉校验 + `taskkill /PID <pid>` | 新建 |
| G11 ARCHIVEdad的前提： addSubview 是否需要管理面 | 不确定是否有其他系统依赖 `/api/setup/*` | **缺口 → 人工确认**：请确认除 `install.js` 与 4 个 Vue 组件外无第三方调用方（含 CI 脚本、Postman 集合） | — |
| G12 数据库表 | `uctoo_user` 已存在（`sql/nuanshouInit.sql:11632-11651`，列含 name/username/email/password/auth_provider/status/created_at/updated_at/last_login_time） | **不新建任何表或列**（SDD 铁律 9） | 复用现有表 |

---

## 四、推荐工程方案

### 4.1 总体形态（抉择结论）

**抉择：Stage A = 不依赖 runtime 启动运行的「独立 install 应用」（仓颉原生单二进制）；Stage B = 运行期管理面的 L3 进程隔离轨薄适配器，本期列为可选后续，不进入 Stage A 范围。**

三条决定性理由（全部有行号证据）：

1. **时序不可调和**：插件 `loadAll` 位于 `main.cj:858`，在 DB/ORM/Channel 引导（`:140-253`）之后、`server.start()`（`:971`）之前。安装器的职责正是修复 DB 配置与 .env —— 它是宿主导通的**前提**，不可能同时是宿主内部的插件。且构造期任一步抛出（如 `:1122` 未兜底的 PORT 解析）都会让插件从未加载，"鸡生蛋"在运行形态上成立且不可绕过。
2. **鉴权白名单撞红线**：L3 插件 HTTP 路由必经 `RequirePermissionMiddleware`（`external_plugin_route_gateway.cj:62-64`），而该白名单是 `src/app/middlewares/auth/RequirePermissionMiddleware.cj:86-126` 的硬编码列表。开放 `/api/setup/*` 必须在冻结区 `src/app/` **新增**分支，直接违反"宿主 `src/app/` 是存量冻结、只减不增"。
3. **能力模型不匹配**：插件进程不继承宿主环境变量（`plugin.yaml:15-16` 注释原文），而安装器需要完整机器视角（PATH、`PGPASSWORD`、openssl、任意 cwd、跨目录写 `node_modules`）。把这种"上帝权限"塞进隔离轨，等于取消隔离轨的意义。

Stage B 的存在价值：runtime 起来之后，管理控制台仍可能需要 `/api/setup/*`（见 G11 缺口）。届时可把 Stage A 的核心逻辑抽成静态库 `installer_core`，由 L3 插件做薄壳复用——**但这是 Stage A 之后的独立提案，本期不做**。

### 4.2 核心编排草图

```
                       ┌──────────────────────────────────────────┐
  start-installer.bat │  ucInstaller.exe --port 3000 [--offline]  │  单二进制，零 node_modules
   (改造：只起它一个)   └───────────────────┬──────────────────────┘
                                            │ 自举 + 自托管静态资源
                         ┌──────────────────▼─────────────────────┐
                         │ http_lib  HTTP :3000  CORS(*)          │
                         │  GET  /healthCheck          → "success"│
                         │  GET  /install.html|js|css   → 静态    │
                         │  /api/setup/* 16 端点 ← nestJs 语义对齐 │
                         └──────────────────┬─────────────────────┘
                                            │
   ┌────────────────────────────────────────▼────────────────────────────────┐
   │  install state machine（每一步完成写 .install-state.json = 断点续装）    │
   │   S0 探测环境 ──闸口A──▶ S1 DB 配置/试连 ──闸口B──▶ S2 SSL           │
   │        ▲                        │                        │             │
   │        │                 ┌──────▼──────┐          ┌──────▼──────┐      │
   │        │                 │ S3 安装介质 │          │ openssl 自签│      │
   │        │                 │ 离线 tarball 优先 → staging → 原子 rename │  │
   │        │                 └──────┬──────┘          └──────┬──────┘      │
   │        │                        │ 保留 previous/ 快照     │             │
   │        │                 ┌──────▼──────┐                 │             │
   │        │                 │ S4 .env 写入│◀────────────────┘             │
   │        │                 └──────┬──────┘                              │
   │        │                 ┌──────▼──────┐   BcryptUtil(cost10)          │
   │        │                 │ S5 建管理员 │──▶ INSERT uctoo_user + 回读自校验│
   │        │                 └──────┬──────┘                              │
   │        │                 ┌──────▼────────────────────────┐            │
   │        └─────────────────│ S6 起进程 + 轮询 /api/v1/health│            │
   │          失败可回滚       └──────┬────────────────────────┘            │
   │                                 ▼                                     │
   │                    闸门：health=200 → 提示 installer 可自退出          │
   └───────────────────────────────────────────────────────────────────────┘
```

### 4.3 复用决策（严守"优先复用"）

- **复用** `libs/http_lib`（`cjpm.toml:45`，TCP 框架 `libs/hyperion` 只是其传递依赖，不可当 HTTP 用）+ `HTTPServer.cj` 的服务范式（`HTTPServer.cj:4-6` 的 import 即为范式出处）、`CORSMiddleware.cj` 的跨域处理：`install.js:4` 跨域直连 3000，CORS 是硬需求（`nestJs/src/main.ts:12-15` 亦为 `origin:'*'`）。
- **复用** `BcryptUtil.cj`（cost 10，与 bcryptjs 兼容，`BcryptUtil.cj:14,24`）：保证仓颉侧与 Node 侧创建的账号哈希格式互认（`$2a$10$…`）。
- **复用** `libs/pgsql` + `main.cj:144-153` 的驱动注册范式：直连 `uctoo_user`，与 nestJs `createAdminAccount`（`:1225-1278`）逐列对齐。
- **复用** `src/config/config.cj` 的 `.env` 语义（`.env 覆盖环境变量`）：保证 `save-runtime-env` 写出的文件被 runtime 读到的语义一致。
- **复用** `libs/logcj` + `f_util`/`f_ticktock`：日志解析与时间格式。
- **复用** `skills/llm_channel_tokendance/` 的"独立子工程 + 独立 executable + stdx DLL 显式声明"工程范式（`plugin.yaml:8-9` 注释 + 其 `cjpm.toml`），用于产出第二个二进制，**不改根 `cjpm.toml`**。
- **明确不新建**：
  - **不新建数据库表/列**：只写 `uctoo_user`（`sql/nuanshouInit.sql:11632`），遵守 SDD 铁律 9。
  - **不改** `src/app/` 任何文件（含鉴权白名单）。
  - **不改** 根 `cjpm.toml` 的 `output-type` 与 `compile-option`（改后者触发全量重编红线）。
  - **不改** `install.js:4` 的 `http://localhost:3000`（保持接口兼容；端口可配但默认 3000）。
- **必须复刻的既有行为**（"完全一致"约束的一部分，不做"改良"，改良单列到 4.5 的可选开关）：
  - `test-config` 三级兜底到无条件成功（`:320-324`）；
  - `service-status` 的随机 cpu/memory/uptime（`:344-347`）——建议以 `--truthful-metrics` 开关的形式提供真实值，默认复刻；
  - `getLogs` 无日志时的两条伪造日志（`:473-488`）与 `slice(-100)`（`:490`）；
  - `check-runtime` 返回值**不含 `code` 字段**（`:729-737`）；
  - `read-runtime-env` 无 .env 时返回 **404**（`:836`）；
  - `create-admin` **只实现真路径**（`:1186`，真实落库），**不实现**假路径（`:499-552`，返回 `admin-<timestamp>` 却不落库）。依据：gate-research 用户拍板「只做真路径，删除假路径」。

### 4.4 需新建的最小集合

1. `apps/agentskills-runtime/installer/`（新子工程）：`cjpm.toml`（仿 `skills/llm_channel_tokendance/cjpm.toml`，`output-type = "executable"`，显式声明 stdx DLL 路径）、`src/main.cj`。
2. `installer/src/http/`：`health_route.cj`（`/healthCheck` → `success`）、`static_route.cj`（托管 `install.html/js/css`）、`setup_routes.cj`（16 端点路由表）。
3. `installer/src/setup/`：`environment_check.cj`、`config_store.cj`（config.json + `.install-state.json`）、`secret_store.cj`（API Key 保存；SSL 产物写 `<releaseDir>/ssl/`）、`db_probe.cj`（psql → TCP → 兜底三级）、`runtime_install.cj`（离线优先 → staging → 原子 rename → `previous/` 回滚）、`env_file.cj`（读写 `.env`）、`ssl_gen.cj`（openssl 单路径 + 显式失败）、`process_ctl.cj`（PID 文件 + taskkill /PID）、`logs_reader.cj`。
4. `installer/src/util/`：`subprocess_timeout.cj`（补 `executeWithOutput` 缺失的 timeout）、`extract.cj`（见 G6 缺口）。
5. 脚本：`apps/web-admin/start-installer.bat` **改造**（去掉 nestJs/前端两段的 `pnpm install` 与 `:3000/:3031` 双等待，改为拉起 `ucInstaller.exe` 并保留健康探活，见 `start-installer.bat:39-62,70-98,120`）。

### 4.5 业界对标与超越清单（落到可验证机制）

| 编号 | 超越点 | 机制（可栈 Test 验证） | 对标物差在哪 |
|---|---|---|---|
| T1 | **单二进制零依赖** | 交付物只有一个 `.exe`；对比现状需 `node_modules` 且 `start-installer.bat:39-43` 会跑 `npm/pnpm install` | Supabase CLI 虽单二进制但需 Docker；winget 交付仍需运行时 |
| T2 | **单进程完成向导** | 安装器自带静态资源服务 + API，`install.html` 直连单一进程，不再需要 3000(nestJs) + 3031(web dev) 双 Node 进程（`start-installer.bat:70,98`） | Homebrew/ Docker Desktop 均需额外宿主 UI/服务 |
| T3 | **安装原子性 + 快照回滚** | staging 落地 → 原子 rename → 保留 `previous/`；提供 `--rollback`。失败态不留残骸（对比 `dist/index.js:140-144` 直接解到目标目录） | rustup 只有自替换/自删除 GC，无失败快照回滚；Supabase `db push` 明确非原子（其文档承认并发冲突） |
| T4 | **断点续装** | `.install-state.json` 记录已完成步骤，刷新/重开浏览器后从上次闸口继续（对比现状只有内存 `configStore` + 单个 `config.json`，`:16-23,:226`） | 上述对标物全部缺失：失败即重头 |
| T5 | **离线优先 + 本地介质直装** | 优先用仓库内 `release/agentskills-runtime-win-x64.tar.gz` 或已编译的 `target/release/bin/agentskills-runtime.exe`，缺失才回落 atomgit→github 镜像（`dist/index.js:19-32`） | Supabase/winget 强在线；rustup 离线需手工拼包名 + `toolchain link` 多步 |
| T6 | **精确进程治理** | PID 文件 + 进程名交叉校验 + `taskkill /PID`，替代 `taskkill /F /IM node.exe`（`:598`）这种误伤同机全部 node 的粗暴做法 | 对标物普遍不管被装服务的生命周期 |
| T7 | **端到端自校验闭环** | 写 `uctoo_user` 后回读哈希并用 `BcryptUtil.comparePassword` 自校验一遍再返回成功；再轮询 runtime `/api/v1/health`（`main.cj:698`）确认"真起来了"才宣告安装完成 | 对标物多在写盘/解压后即宣告成功 |
| T8 | **机器可读契约 + 非零退出码** | 全部检查提供 `--json` 输出与稳定退出码，并给出可执行的修复建议命令；对比现状 `test-config` 永不失败、`service-status` 随机数、`getLogs` 伪造日志 —— 真实性与可观测性从根纠正 | nestJs 现状连"失败"都无法表达 |
| T9 | **安装器自我退役** | 检测到 runtime `/api/v1/health` 持续 200 即提示并可 `--auto-exit`，兑现 `INSTALL_README.md` 原文"NestJS 后端服务器可以停止"这一至今未被自动化的承诺 | 对标物的安装器通常转为常驻或需人工收尾 |

---

## 五、关键设计决策与风险

1. **形态抉择**：决策为 Stage A「独立 install 应用」+ Stage B「可选薄 L3 适配器」。原因见 4.1 三条行号级证据（时序 `:858` vs `:971`；白名单 `:86-126` 属冻结区；插件不继承环境变量 `plugin.yaml:15-16`）。
2. **端点语义的取舍**：决策为"默认复刻 nestJs 行为，另设显式开关提供真实语义"。原因：用户要求"完全一致"；直接改良会让 `install.js` 的既有判断逻辑失配（例如 `data.data.find(item=>item.name==='nodejs')`，`install.js:121`）。
3. **`create-admin` 双实现的处置**：**已拍板（gate-research）** —— **只做真路径（落库，`setup.service.ts:1186`），删除假路径**（`:499-552`）。原因：假路径"返回成功却不建账号"会让安装流程走完却无管理员，属缺陷而非兼容性资产；`install.js:384/1089` 只消费返回体中的 `code/message/data`，删除假路径不影响既有前端判断。注意：假路径返回体含 `data.id`，真路径返回体是 `data.user{id,name,username,email}`——**字段形状不同，需在 spec 步固定为其中一种并同步核对 `install.js` 的消费点**（列为 spec 步必答项）。
4. **风险 — 编译红线**：AI 绝不运行 `cjpm build`（红线）。缓解：本研究及后续 spec/design 只产出源码与改造后的 `.bat`，编译由用户在独立 cmd 执行并回传日志，AI 依据日志修复。
5. **风险 — G6 tar.gz 解压**：仓颉 std 无原生解压。缓解优先级：① 改发 zip 介质；② 调系统 `tar.exe`（Windows 10+ 自带 bsdtar）；③ 目录复制安装。**需人工确认目标机 `tar` 可用性**或批准介质格式变更。
6. **风险 — G7 子进程超时**：`executeWithOutput` 支持 `workingDirectory!`/`environment!` 但**无 `timeout!`**；而安装下载允许 5 分钟（`:782`）。缓解：统一走 `subprocess_timeout.cj`（spawn + 轮询 + 超时强杀），并**禁止**把 `npx skills install-runtime` 这类**交互式**命令直接拉起（`dist/cli.js:595-606` 的 inquirer 会卡住 stdin）——这是不能靠 noreplace 复用 npm CLI 的关键理由。
7. **风险 — 依赖级 compile-option 变更**：改动任一依赖的 `compile-option` 必须 `cjpm clean && cjpm build` 全量重编（红线）。缓解：Stage A 新建独立子工程，**不触碰根包与既有依赖的编译选项**。
8. **风险 — L3 stdout 独占**：若未来落到 Stage B（L3 插件），插件进程诊断日志一律走 stderr，stdout 是 stdio RPC 独占通道（红线）。Stage A 虽非插件，仍建议诊断输出走 stderr，为 Stage B 留通路。
9. **风险 — SDD 铁律 9**：本方案**不新建库表或列**，仅写 `uctoo_user`（已存在，`sql/nuanshouInit.sql:11632`）。若后续 S5 步骤需要额外字段，必须显式标注并请人工确认。
10. **风险 — 端口 3000 占用与双消费方**：`install.js:4` 硬编码 3000；Vue 组走代理且代理存在 `/api` 去前缀的不一致（1.4 缺口）。缓解：Stage A 默认绑 3000 并把实际端口写入 `<installRoot>/.installer-port` 便于排查；代理侧是否修正待人工确认后再单独立项。
11. **约束 — SS L 生成**：仅保留 openssl 单路径。nestJs 的 Node 降级路径产出的是伪 PEM（`:1127` 把 base64(domain) 拼进证书体），属于"假成功"，不予复刻；openssl 缺失时返回明确错误 + 安装指引。

---

## 六、后续步骤指引（交接给 spec / design / tasks）

- **下一步（需求规格 spec）** 要固化的 REQ：
  - REQ-1：17 个端点行为逐条契约化（含 1.2 表中的返回码与"不含 code 字段"、404、假数据等细节）。
  - REQ-2：`GET /healthCheck` 返回纯文本 `success`；3000 端口默认；CORS `*`。
  - REQ-3：静态向导自托管，单进程可达。
  - REQ-4：`.install-state.json` 断点续装状态机的步骤与闸口（S0~S6）。
  - REQ-5：原子安装 + `previous/` 快照 + `--rollback`。
  - REQ-6：离线介质优先，镜像次之。
  - REQ-7：PID 文件化进程治理，禁止按镜像名全杀。
  - REQ-8：`uctoo_user` 写入字段与 bcrypt cost 10 一致性；写后回读自校验。
  - REQ-9：installer 自退役条件（runtime `/api/v1/health` 连续 N 次 200）。
- **再下一步（设计 design）** 要细化的内容：`installer/` 子工程结构与依赖清单（哪些必须 `-O2`，哪些禁 `f_base`/`magic.*`）；`subprocess_timeout` 的并发模型；原子 rename 在 Windows 上对被占用文件的延迟删除策略；`.install-state.json` 的 schema 与迁移策略；16 端点的 handler → 内部服务调用拓扑图。
- **任务规划**（大致拆分）：① 子工程骨架 + 空端点返回对齐测试（用 curl 逐端点比对本机 nestJs 的响应 JSON）；② 环境与探测类 4 个端点；③ 安装/起停类 5 个端点；④ 配置/SSL 类 5 个端点；⑤ 状态机/回滚/离线介质；⑥ `start-installer.bat` 改造与联调；⑦ 与 4 个 Vue 组件的一致性核对（依赖 G11 人工确认结论）。

---

# 附录 A：本研究直接复用的关键文件索引

| 用途 | 文件 | 备注 |
|---|---|---|
| 待替换的端点契约（逐 measure对齐基准） | `apps/web-admin/nestJs/src/setup/setup.controller.ts`；`setup.service.ts`（1322 行） | 逐 USD 行号已在 1.2 表内联引用属 — 直接仿写 |
| 安装向导前端（接口兼容约束源） | `apps/web-admin/public/install.js`（`:4` API_BASE_URL；`:20-25` /healthCheck） | 原样兼容，不改动 |
| Vue 管理组件（次消费方） | `EnvironmentCheck.vue:44`、`LogViewer.vue:50`、`ServiceMonitor.vue:45`、`ConfigManagement.vue:60/72/92`；`farm.config.ts:49-63` | 兼容待确认（1.4 缺口） |
| 健康文本契约 | `apps/web-admin/nestJs/src/health-check.controller.ts:14-16` | 直接仿写 |
| 安装器启动脚本（待改造） | `apps/web-admin/start-installer.bat:39-62,70-98,120`；`nestJs/start-installer.bat` | 改造后复用 |
| 存在理由原文 | `apps/web-admin/nestJs/INSTALL_README.md:7-22` | 引用原文，作为退役条件依据 |
| 安装包真实语义 | `apps/web-admin/node_modules/@opencangjie/skills/dist/index.js:52-66,104-183`；`dist/cli.js:590-627`；`package.json:92` | 依据（266行period），不作为依赖 |
| 启动时序与端口默认值 | `apps/agentskills-runtime/src/app/main.cj:140,156-176,832-895,960-971,1120-1125,1184-1189` | 形态抉择首要证据 |
| 健康/信息端点（用作安装完成判据） | `src/app/main.cj:698`（`/api/v1/health`）、`:718`（`/api/v1/info`） | 原样调用（HTTP 探测） |
| HTTP 服务范式 | `src/app/core/server/HTTPServer.cj`；`src/app/middlewares/CORSMiddleware.cj` | 直接仿写 |
| 鉴权白名单（Stage A 不触碰） | `src/app/middlewares/auth/RequirePermissionMiddleware.cj:86-126` | 只读，作为决策证据 |
| 密码哈希（cost 10 对齐） | `src/app/utils/auth/BcryptUtil.cj:14,24,32` | 原样调用 |
| .env 语义 | `src/config/config.cj:29-33,217` | 原样调用/仿写 |
| 表结构（不新建） | `sql/nuanshouInit.sql:11632-11651`（`uctoo_user`） | 只读，作为写入契约 |
| 独立 executable 子工程范式 | `apps/agentskills-runtime/skills/llm_channel_tokendance/cjpm.toml`；`plugin.yaml:8-9,15-16,25` | 仿写工程结构 |
| L3 路由网关（Stage B 预留） | `src/plugin/external_plugin_route_gateway.cj:48-74,90-133`；`src/plugin/cordis_host_manager.cj` | 本期不启用，仅存档 |
| 离线安装介质 | `apps/agentskills-runtime/release/agentskills-runtime-win-x64.tar.gz`；`target/release/bin/agentskills-runtime.exe` | 原样使用（T5 依据） |
| 依赖清单 | `apps/agentskills-runtime/cjpm.toml`（根包 `output-type="static"`，HTTP 基座 `http_lib`(`:45`)/`hyperion`(`:44`，TCP 框架、仅传递依赖)/pgsql/blowfish/jinguissl/yaml4cj/json4cj/logcj 等） | 只读，作为 import 依据 |
| 业界对标（外部） | rustup self-update 文档；Supabase CLI 安装与命令参考 | 外部 URL 见 1.6 表格 |
