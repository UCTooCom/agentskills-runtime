# AgentSkills Runtime v0.0.26 发布说明

**发布日期**: 2026-08-07  
**版本**: 0.0.26  
**代号**: Agent Infra  
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 1. HTTP 库迁移：从 stdx.net.http 到 http_lib

本版本完成了 HTTP 服务层从 stdx.net.http 到 http_lib 的全面迁移，实现了 HTTP/HTTPS 服务、WebSocket、SSE、HTTP 客户端能力的统一承载。此次迁移从根本上消除了 10053 SocketException。

#### 技术架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                       HTTP 库迁移 整体架构                               │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────┐   │
│  │  HTTP 服务层   │  │  WebSocket   │  │    SSE 服务                │   │
│  │  http_lib     │  │  http_lib    │  │  http_lib                   │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┬───────────────┘   │
│         └────────┬────────┘                           │                   │
│                  ▼                                     ▼                   │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                      接入层 (Entry Layer)                         │    │
│  │  HttpRouter (标准 HTTP 路由 + WebSocket 路由 + SSE 路由)            │    │
│  │  HttpHandler (标准 HTTP 处理 + WebSocket 处理 + SSE 处理)           │    │
│  └──────────────────────────┬───────────────────────────────────────┘    │
│                             │                                            │
│  ┌──────────────────────────▼───────────────────────────────────────┐    │
│  │                      服务层 (Service Layer)                       │    │
│  │  HttpService (连接状态管理/流式传输/响应压缩)                      │    │
│  │  WebSocketService (WebSocket 升级/帧处理/连接管理)                 │    │
│  │  SseService (事件流构建/ETag 管理/缓存头设置)                      │    │
│  └──────────────────────────┬───────────────────────────────────────┘    │
│                             │                                            │
│  ┌──────────────────────────▼───────────────────────────────────────┐    │
│  │                      安全层 (Security Layer)                     │    │
│  │  CertificateManager (TLS 证书管理)                               │    │
│  │  RequestValidator (请求安全校验)                                 │    │
│  │  ResponseSanitizer (响应内容过滤)                                │    │
│  └──────────────────────────────────────────────────────────────────────┘
```

#### 核心能力

| 能力 | 说明 |
|------|------|
| 纯仓颉实现 | http_lib 基于仓颉标准库实现，零 stdx 依赖、零 C FFI，支持 HTTP/1.0/1.1/2 |
| 声明式响应 | Handler 以 `(HttpRequest) -> HttpResponse` 函数式签名返回响应对象，写入前统一检测连接可用性 |
| 连接生命周期管理 | 通过 connState 回调与 errorLog 回调接入 LoggerFactory，连接状态（NEW/ACTIVE/IDLE/HIJACKED/CLOSED）完全可观测 |
| 10053 根治 | 客户端中断连接后服务端不再向失效 socket 写入数据，进程不崩溃 |
| WebSocket 升级 | 通过 http_lib ConnectionController 升级，支持 readMessage/writeText 双向消息 |
| SSE 事件流 | 使用 SSEWriter 封装事件 ID、事件类型、数据分帧与 flush 语义 |
| HTTP 客户端 | 声明式 HttpClient 出站调用，支持 TLS 与 JSON 请求构造 |

#### 关键架构决策

- **保留应用层抽象**：`magic.app.core.router.Router` 与 `MiddlewareChain` 对外 API 不变，内部委托 http_lib Router（基数树，自动注入路径参数与 404/405）
- **Handler 双签名桥接**：现有 `(AppHttpRequest, AppHttpResponse) -> Unit` 业务 Handler 通过桥接函数无缝迁移至声明式范式，无需全量改造
- **WebSocket 路由合并**：不再走独立旁路，注册到 http_lib Router 的 GET 路由，Handler 内完成升级与消息循环
- **依赖链全量本地化**：http_lib 及其 7 个传递依赖（kaca_json、jinguissl、jinguissl_core、kaca_cookies、compress4cj、quic_cj、channel_cj）克隆至 `libs/` 目录，cjpm.toml 改为 path 声明，整条依赖链无 git 网络请求
- **职责边界**：不修改 fountain 框架代码，不迁移独立库（activemq4cj、cj_mail、cos-sdk、hyperion），不改变现有对外 REST API 路径与消息协议

### 2. 数据库驱动迁移：从 opengauss 到 pgsql-driver

本版本将 PostgreSQL 驱动从 opengauss 替换为 pgsql-driver，统一仓颉生态数据库驱动栈，消除 opengauss 驱动在仓颉 0.55+ 工具链下的兼容性问题，并与依赖链全量本地化策略一致。

#### 技术架构

| 维度 | v0.0.25 (opengauss) | v0.0.26 (pgsql-driver) |
|------|----------------------|------------------------|
| cjpm 依赖声明 | git 仓 `opengauss` 声明 | `pgsql = { path = "./libs/pgsql-driver" }` 本地 path 声明 |
| 驱动类 | `opengauss.driver.PostgresDriver` | `pgsql.PostgresDriver` |
| 依赖位置 | git 远端拉取 | `libs/pgsql-driver/` 本地化，无 git 网络请求 |
| 仓颉工具链兼容 | 0.55+ 存在符号冲突 | 与 http_lib 依赖链同步适配 0.55+ |

#### 核心能力

| 能力 | 说明 |
|------|------|
| 驱动注册 | `DriverManager.register("postgres", PostgresDriver())` API 不变，运行时透明切换 |
| ORM 适配 | `ORM.initialize()` 与 `ORM.connection()` 调用链不变，fountain ORM 层无感 |
| 连接池复用 | `DatabaseConnectionPool.getInstance(dbConfig)` 连接池语义一致，连接字符串 `postgresql://...` 不变 |
| 本地化依赖 | pgsql-driver 克隆至 `libs/pgsql-driver/`，与 http_lib 本地化策略一致，cjpm.lock 刷新为 path 依赖 |

#### 关键架构决策

- **对外配置不变**：`.env` 中 `orm_drivers=postgres`、`orm_defaultDriver=postgres`、`orm_connectionUrl=postgresql://...` 配置项保持不变，用户无需修改环境配置
- **import 路径更新**：源码 `import opengauss.driver.PostgresDriver` 改为 `import pgsql.PostgresDriver`，仅在 `src/app/main.cj` 两处驱动注册点（HTTP/HTTPS init 各一处）
- **依赖链一致性**：与 http_lib 的 7 个传递依赖一并本地化，cjpm.toml 全部改为 path 声明，消除 git/path 混用残留

### 3. PC 桌面客户端：内嵌 runtime 发布版，实现安装即用

为提升用户体验和系统稳定性，本版本完成 PC 桌面客户端的架构重构。runtime 发布版压缩包（`agentskills-runtime-win-x64.tar.gz`，约 380MB 压缩/1.27GB 解压）已内嵌到 PC 客户端安装包中，安装时自动解压到指定集成目录，取代原"首次启动时通过 SDK downloadRuntime() 网络下载"方案，实现安装即用。

#### 技术架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                   PC 桌面客户端 整体架构 (Electron)                       │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                    渲染进程 (Vue 3)                               │    │
│  │  HomeView (iframe 加载 web-admin)   SetupView (配置向导)           │    │
│  │  RuntimeStatus / PgsqlView / SkillsView / AgentsView             │    │
│  └───────────────────────────┬──────────────────────────────────────┘    │
│                              │ preload contextBridge (electronAPI)       │
│  ┌───────────────────────────▼──────────────────────────────────────┐    │
│  │                    主进程 (Electron Main)                          │    │
│  │  RuntimeIntegrator (runtime 压缩包解压/版本检测/.env 生成/降级下载)│    │
│  │  RuntimeManager + RuntimeHealthCheck + RuntimeCrashRecovery        │    │
│  │  RuntimeVersionManager (升级/备份/回滚)                            │    │
│  │  PgManager (内置 PostgreSQL 初始化/启停/备份恢复/连接测试)          │    │
│  │  AuthBridge (登录态共享)   DependencyManager (OpenSSL/环境依赖)     │    │
│  │  EnvGenerator + EnvSyncManager (runtime/web-admin .env 生成同步)    │    │
│  │  ConfigStore (加密持久化)   TrayManager / WindowManager / AutoUpdater│    │
│  └───────────────────────────┬──────────────────────────────────────┘    │
│                              │ spawn / 健康检查                           │
│  ┌───────────────────────────▼──────────────────────────────────────┐    │
│  │                    agentskills-runtime (内嵌)                      │    │
│  │  REST API + WebSocket + SSE (http_lib)                              │    │
│  │  PostgreSQL (内置实例)                                            │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

#### 核心能力

| 能力 | 说明 |
|------|------|
| runtime 内嵌安装 | 安装包内嵌 `agentskills-runtime-win-x64.tar.gz`，安装时自动解压至 `%APPDATA%/agentskills/runtime/` |
| 安装即用 | 解压后自动生成 .env 默认配置文件并启动 runtime 服务，冷启动 ≤ 60 秒（含解压验证和 PostgreSQL 初始化） |
| 版本检测 | RuntimeVersionDetector 检测 runtime 版本，为后续切换 runtime 静态文件服务做准备；当前 web-admin 由内置 HTTP 服务器托管 |
| 生命周期管理 | RuntimeManager 全生命周期管理（spawn/kill/healthCheck），5s 轮询健康检查，崩溃自动重启（5 分钟 3 次保护） |
| 版本升级回滚 | SDK downloadRuntime() 降级为版本升级和降级修复方案，支持备份与回滚 |
| 内置 PostgreSQL | 内嵌 PostgreSQL 实例，支持初始化、启停、备份恢复（pg_dump -Fc）、外部连接测试，uctoo 用户 + scram-sha-256 认证 |
| 登录态共享 | iframe 复用 web-admin 登录功能，postMessage 监听登录状态，access_token 存储到 Electron safeStorage 并自动恢复 |
| 依赖管理 | OpenSSL 运行时依赖检测/自动安装/内置 DLL，一键式安装整合所有桌面端依赖 |
| web-admin 集成 | 构建产物由 PC 客户端内置 HTTP 服务器托管，.env 配置自动同步（VITE_ 前缀变量）；待 runtime 静态文件服务落地（v0.0.27）后切换为 runtime 托管 |
| 安装包打包 | electron-builder NSIS 打包，含 runtime 压缩包约 600-800MB，支持 Windows/Linux/macOS 多平台 |

#### 主要重构内容

- **UI 布局重构**：从顶部水平导航改为左侧竖向导航（四区域导航结构），新增技能管理/智能体管理路由，移除底部状态栏
- **首页重构**：占位页升级为友好等待界面（应用名称、runtime 状态说明、启动进度指示、一键启动按钮、超时错误提示），iframe 全屏展示 web-admin
- **配置向导重构**：3 步流程扩展为 4 步（欢迎 → AI Key → 数据库 → 完成），支持内置/外部 PostgreSQL 选择
- **PostgreSQL 增强**：initdb 参数对齐 `-U uctoo --auth-host=scram-sha-256`，端口冲突自动分配并同步 .env 连接串，orm_connectionUrl 自动更新
- **EnvGenerator 增强**：新增 `generateForWebAdmin()` 生成 web-admin .env（VITE_SERVER_HOST/VITE_BACKEND_URL/VITE_WS_URL 等），`syncWebAdminEnv()` 随 BACKEND_URL 变更自动同步

### 4. GOAI2026「新智基座」赛道：多 Agent 协同基础设施工程化

本版本完成了 GOAI2026 赛事编码任务规划与 P0/P1 工程的设计复核、合规性审查和编码落地，将 22 个工程（9 个 P0 核心工程 + 8 个 P1 增强工程 + 5 个 P2 锦上添花工程）的需求设计转化为可执行的编码任务，全部工程编码实现完成，占位实现已修复。

#### 工程全景

| 层级 | 工程 | 对标维度 |
|------|------|---------|
| P0 核心 | agent-teams、agent-orchestration、execution-audit、skill-composition-engine、cangjie-coder-agents、code-gen-skills、fullstack-codegen、sdd-skills、ai-dev-demo | 场景价值(25%)、多Agent协同(25%)、Skill工程体系(25%)、工程落地与安全审计(20%)、开放开源(5%) |
| P1 增强 | agent-memory-persistence、agent-context-verify、agent-loop、approval-rollback、language-skills-orchestration、skill-evolution、collaboration-skills、test-generator | 全部 5 项维度 |
| P2 锦上添花 | agent-error-recovery、open-source-plan、memory-provider、context-optimization、agent-intelligence | 增强竞争力 |

#### 关键设计原则

1. **确定性优先，AI 增强**：确定性代码做确定的事（CRUD、权限、调度），AI 做推理决策（任务分解、技能选择、代码生成）
2. **可配置引擎优先于硬编码程序**：功能通过 YAML/Markdown 配置动态调整
3. **复用已有基础设施**：优先复用 crudgen/crudweb/loaddbinfo/cangjie-coder 等既有能力
4. **技能是一等公民**：新功能优先通过 SKILL.md 技能实现
5. **仓颉代码统一使用 cangjie-coder 技能**：遵循查阅文档 → 检索代码 → 编辑适配 → 写入文件的四步工作流程
6. **数据库变更遵循 uctoo-v4 通用模块开发流程**：DDL 生成 → 人工变更 → CRUD 生成 → 迭代开发

#### 设计复核与规范治理

- **仓颉语言规范合规性复核**（cangjie-compliance-review.md）：对 11 个设计文档（9 个 P0 + 2 个 P1）完成合规复核，识别 8 个严重问题（如 TeamManager 缺少 `public` 修饰符、接口方法未用 `Option<T>`/`APIResult<T>` 包装失败操作、`JsonObject` 应明确为 `JsonValue` 等）、12 个中等问题、9 个轻微问题并全部落实到任务清单
- **数据库规范全面复核**（design-review.md）：对 9 个 P0 + 2 个 P1 设计文档完成数据库规范合规性复核，识别 12 个严重问题（如主键 BIGSERIAL 应为 UUID `gen_random_uuid()`、时间字段 TIMESTAMP 应为 `timestamptz(6)`、外键类型与 UUID 主键不兼容等）、8 个中等问题、5 个轻微问题，统一对齐 uctooDB.sql 既有规范

### 5. WebMCP OOM 问题修复

修复了登录后前端调用 `/api/v1/uctoo/webmcp/mcp` 发送 `notifications/initialized` 请求时 runtime 发生 Out of Memory 错误、导致登录流程卡在登录页面的问题。根因分析覆盖了从路由注册 → Controller → WebMCPProtocol → TieredMemory/SemanticSet 初始化的完整调用链路，定位了内存溢出点并完成修复，完整分析与修复方案见 `.codeartsdoer/specs/webmcp-oom-fix/oom-analysis-and-fix-plan.md`。

## 新增功能

### HTTP 服务层（仓颉）

| 模块 | 说明 |
|------|------|
| HTTPServer 重构 | 服务端入口切换至 http_lib `HttpServer.listenAndServeTls`，路由/中间件/WebSocket/SSE 统一承载 |
| 声明式 Handler 桥接 | `bridgeHandler()` 将业务 `(AppHttpRequest, AppHttpResponse) -> Unit` 无缝桥接为 `(HttpRequest) -> HttpResponse` |
| 连接状态可观测 | HttpServerConfig.connState + errorLog 回调接入 LoggerFactory，连接状态全生命周期可追踪 |
| HTTP 客户端 | 声明式 HttpClient，TLS + JSON 请求构造，替换 stdx 客户端 |

### PC 桌面客户端（Electron + Vue 3）

| 模块 | 文件 | 说明 |
|------|------|------|
| RuntimeIntegrator | electron/modules/runtime-integrator.ts | runtime 压缩包解压、集成目录版本检测、.env 自动生成、降级下载 |
| AuthBridge | electron/modules/auth-bridge.ts | iframe postMessage 登录态监听、access_token safeStorage 持久化 |
| DependencyManager | electron/modules/dep-manager.ts | OpenSSL 检测/自动安装、运行时环境依赖检查 |
| RuntimeVersionDetector | electron/modules/runtime-version-detector.ts | runtime 版本检测，为静态文件服务切换做准备（当前内置服务器托管） |
| EnvSyncManager | electron/modules/env-sync-manager.ts | runtime .env 与 web-admin .env 同步 |
| AppSidebar | src/components/AppSidebar.vue | 左侧四区域竖向导航 |
| SkillsView / AgentsView | src/views/skills、src/views/agents | 技能管理、智能体管理视图 |

### GOAI2026 工程（P0 核心）

| 工程 | 说明 |
|------|------|
| agent-teams | Manager–Team Leader–Worker 三层 Agent 协同架构，TeamConfig YAML 解析、TeamMessenger 分层消息传递 |
| agent-orchestration | DAG 编排引擎，任务分解与混合框架调度 |
| execution-audit | 执行证据链与审计，失败回滚（RollbackManager） |
| skill-composition-engine | 技能组合与编排，`@agentTeams` DSL 扩展 |
| cangjie-coder-agents / code-gen-skills / fullstack-codegen | 仓颉代码生成技能与全栈代码生成 |
| sdd-skills / ai-dev-demo | 规范驱动开发技能与可运行 Demo |

### 金融行业智能投研技能（investment-research-assistant）

本版本随附金融行业应用 Agent 黑客松参赛作品，新增"智能投研助理（Investment Research Assistant）"技能，实现金融行业 Agent 核心场景"自动抓取 → 数据清洗 → 要素提取 → 研报生成 → 结果落库 → 每日投资简报"的全流程自动化：

| 能力 | 说明 |
|------|------|
| 多源数据自动抓取 | 行情/公告/新闻/宏观等多源数据抓取（`web_fetch` / `http_request` / `scripts/fetch_market_data.py`） |
| 数据清洗去重 | 去噪、去重、统一格式、剔除无效数据（`scripts/clean_market_data.py`） |
| 投资要素提取 | 估值、财务、事件、情绪等结构化要素提取（`scripts/extract_factors.py`） |
| 研报生成 | 调用大模型（昇腾 API / AtomGit）生成结构化每日投资简报，含一句话结论/行情概览/核心看点/风险提示 |
| 结果落库 | 公司信息 upsert 至 `company` 表，研报内容写入关联 `tasks` 表（`scripts/save_report_to_db.py`） |
| aibuilder 呈现 | 通过 aibuilder 模块可视化呈现公司列表与研报详情 |
| 全流程编排 | COMPOSITION.yaml 声明式组合步骤（抓取 → 清洗 → 提取 → 生成 → 落库 → 简报） |

- **技能位置**：`skills/investment-research-assistant/`（SKILL.md + COMPOSITION.yaml + 5 个 Python 脚本）
- **触发词**："投研"、"投资简报"、"研报"、"每日投资简报"、"股票分析"、"Investment Research"
- **演示视频**：`public/demo.mp4`（金融行业应用 Agent 黑客松作品录屏）

## 改进

### 1. 服务稳定性

- 彻底消除 Windows 下 10053 SocketException，客户端中断连接不再导致服务端异常或进程崩溃
- 修复 WebMCP 登录初始化路径的 Out of Memory 问题
- 服务连续运行 24h 无崩溃、无端口失效

### 2. 架构可维护性

- HTTP 层从命令式副作用范式升级为声明式响应范式，框架统一负责连接可用性检测
- 依赖链全量本地化（path 声明），规避 cjpm 缓存冲突与版本漂移，构建无需 git 网络请求
- 连接状态完全可观测，替换原有"框架黑盒 + WARN 日志"排障模式

### 3. PC 客户端体验

- 从"首次启动网络下载 runtime"升级为"安装即用"，消除网络失败导致的安装失败场景
- 安装包统一为含 runtime 的完整包，冷启动 ≤ 60 秒（含解压验证和 PostgreSQL 初始化）
- 登录态共享与 safeStorage 持久化，简化用户登录流程

### 4. 规范治理

- GOAI2026 全部 22 个工程完成仓颉语言规范合规性复核与数据库规范全面复核，严重问题全部落实到任务清单并修复

## 数据库变更

### GOAI2026 工程数据表（按 uctoo-v4 规范）

P0 核心工程按 uctooDB.sql 既有规范新建数据表（UUID 主键 `gen_random_uuid()`、`timestamptz(6)` 时间字段），包括：

- `agent_teams` / `agent_team_members`（agent-teams 团队与成员表）
- agent-orchestration / execution-audit / skill-composition-engine / agent-memory-persistence 等工程关联表

> 本版本不涉及存量表结构变更；HTTP 库迁移与 pgsql-driver 驱动迁移均明确不引入数据库 schema 变更。

### 驱动栈迁移（opengauss → pgsql-driver）

- PostgreSQL 驱动从 opengauss 切换为 pgsql-driver，属运行时组件替换，不涉及数据库 schema 或连接协议变更
- `orm_drivers` / `orm_defaultDriver` / `orm_connectionUrl` 等 `.env` 配置项保持不变，存量 PostgreSQL 数据库连接透明兼容

## 迁移指南

### 从 v0.0.25 升级

1. **重启 Runtime 服务**
   ```bash
   # 使用 SDK 重新安装
   npm install @opencangjie/skills@latest
   npx skills install-runtime --runtime-version 0.0.26
   npx skills restart
   ```

2. **验证 HTTP 服务**
   ```bash
   # 健康检查接口返回 JSON
   curl http://127.0.0.1:443/api/v1/uctoo/health
   ```

3. **PC 客户端用户**：卸载旧版客户端后安装新版安装包（约 600-800MB，含 runtime 压缩包），安装完成后自动解压并启动 runtime

4. **数据库驱动透明迁移**：PostgreSQL 驱动从 opengauss 切换为 pgsql-driver，`.env` 中 `orm_drivers`/`orm_defaultDriver`/`orm_connectionUrl` 配置项保持不变，存量 PostgreSQL 数据库连接无需任何调整，重启 runtime 即可透明切换

> 对外 REST API 路径、请求/响应 JSON 结构、WebSocket 消息协议、SSE 事件格式均保持不变，业务侧无需修改。

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~380MB（解压 ~1.27GB）
- 包含: 所有依赖 DLL，内嵌 http_lib 依赖链

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~160MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

## 安装使用

### 使用 JavaScript SDK

```bash
# 安装 SDK
npm install @opencangjie/skills@latest

# 安装 runtime
npx skills install-runtime --runtime-version 0.0.26

# 启动 runtime
npx skills start
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.26/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑 .env 文件配置数据库连接、AI 模型 API Key 等

# 4. 运行
./bin/agentskills-runtime.exe 443
```

### 构建说明

```bash
# 构建项目（自动打包）
cjpm build

# 手动打包（可选）
cjpm run --skip-build --name magic.scripts.package_release
```

## 相关文档

| 文档 | 说明 |
|------|------|
| [HTTP 库迁移需求规格](./.codeartsdoer/specs/http-lib-migration/spec.md) | stdx.net.http → http_lib 完整需求规格 |
| [HTTP 库迁移技术设计](./.codeartsdoer/specs/http-lib-migration/design.md) | 迁移架构与模块级技术设计 |
| [HTTP 库对比分析](./.codeartsdoer/specs/http-lib-migration/http-lib-vs-stdx-analysis.md) | http_lib 与 stdx 方案对比 |
| [HTTP 库迁移评审报告](./.codeartsdoer/specs/http-lib-migration/review-report.md) | 代码实现评审结论与风险 |
| [PC 桌面客户端需求规格](./.codeartsdoer/specs/pc_desktop_client/spec.md) | PC 客户端完整需求规格（v2.5） |
| [PC 桌面客户端技术设计](./.codeartsdoer/specs/pc_desktop_client/design.md) | Electron 架构与模块设计 |
| [PC 桌面客户端调研报告](./.codeartsdoer/specs/pc_desktop_client/pc_desktop_client_research_report.md) | 技术选型依据 |
| [GOAI2026 编码任务规划](./.codeartsdoer/specs/goai2026/coding-task-plan.md) | 22 个工程任务规划与完成状态 |
| [仓颉规范合规性复核](./.codeartsdoer/specs/goai2026/cangjie-compliance-review.md) | 设计文档仓颉规范合规报告 |
| [设计文档全面复核](./.codeartsdoer/specs/goai2026/design-review.md) | 数据库规范合规性复核报告 |
| [WebMCP OOM 分析与修复](./.codeartsdoer/specs/webmcp-oom-fix/oom-analysis-and-fix-plan.md) | OOM 根因分析与修复方案 |

## 已知问题

- SSE 实现尚未完全使用 SSEWriter 规范封装，存在维护风险（详见 http-lib-migration review-report）
- http_lib 迁移后的集成测试覆盖仍在进行中，长时间运行稳定性需持续观察
- PC 客户端安装包体积较大（约 600-800MB，含 runtime 压缩包）
- 静态文件服务（STATIC_FILE_ROOT）尚未实现，规划于 v0.0.27；web-admin 静态资源暂由 PC 客户端内置 HTTP 服务器托管

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区
- GOAI2026 新智基座赛道参赛团队

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

## 下一版本计划

v0.0.27 计划功能：
- 静态文件服务（`STATIC_FILE_ROOT` 配置 + MIME 自动检测 / ETag 缓存 / Gzip 压缩 / SPA History Fallback / 路径遍历防护，托管 web-admin 构建产物）
- PC 桌面客户端跨平台发布（Linux/macOS 安装包）
- GOAI2026 复赛提交（P0 工程 Demo 完善与 P1 工程交付）
- SSE 实现规范重构（SSEWriter 全面落地）
- DAG 调度引擎强化
- 技能市场 Web UI
- 性能监控面板
- 集群部署支持

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
