# AgentSkills Runtime v0.0.27 发布说明

**发布日期**: 2026-08-30
**版本**: 0.0.27
**代号**: Everything is a Skill
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 1. 一切皆技能：智能插件系统全面落地

本版本完成了 AgentSkills Runtime 插件系统的全部四个阶段开发，实现了"一切皆技能"的设计理念。插件系统支持三种加载模式（内嵌轨/L2 动态库轨/L3 进程隔离轨），通过 `plugingen` 一键生成标准 CRUD 插件，经 `crudweb` 生成前端数据表格页面，实现从数据库表到全栈 CRUD 的秒级交付。

#### 技术架构

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    智能插件系统 三轨架构 (v0.0.27)                              │
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │  L1 内嵌轨       │  │  L2 动态库轨     │  │  L3 进程隔离轨              │  │
│  │  (sync)         │  │  (dylib)        │  │  (process / cordis-cj)     │  │
│  │  编译期内嵌      │  │  运行期 .dll     │  │  独立子进程 + JSON-RPC      │  │
│  │  反射加载        │  │  PluginLoader   │  │  CordisHostManager         │  │
│  └────────┬────────┘  └────────┬────────┘  └──────────────┬──────────────┘  │
│           └────────┬───────────┘                           │                  │
│                    ▼                                       ▼                  │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    PluginHostManager (三轨统管)                        │   │
│  │  loadAll() → 按 mode 分派 → sync/dylib/process 三轨并行加载            │   │
│  │  registerProcessPluginRoutes() → ExternalPluginRouteGateway 路由注册   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                    │                                                         │
│  ┌─────────────────▼──────────────────────────────────────────────────┐    │
│  │                    服务层 (Service Layer)                           │    │
│  │  PluginRegistry (插件注册表)                                        │    │
│  │  SkillBridge (SKILL.md 技能桥接)                                    │    │
│  │  PluginEventBus (插件事件总线)                                      │    │
│  │  ExternalPluginRouteGateway (L3 路由网关，V4 CRUD 代理)              │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                    │                                                         │
│  ┌─────────────────▼──────────────────────────────────────────────────┐    │
│  │                    工具链 (Toolchain)                               │    │
│  │  plugingen (--mode sync/dylib/process) → 一键生成三轨插件            │    │
│  │  crudgen → 数据库表 → 后端 CRUD 代码生成                            │    │
│  │  crudweb → 数据库表 → 前端 Vue 数据表格页面生成                      │    │
│  │  pluginuninstall (--mode process) → 进程轨插件卸载                   │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### 核心能力

| 能力 | 说明 |
|------|------|
| 三轨插件加载 | L1 内嵌轨（编译期反射）、L2 动态库轨（运行期 .dll 加载）、L3 进程隔离轨（cordis-cj 子进程 + JSON-RPC stdio） |
| plugingen 一键生成 | `plugingen --name {table} --db {db} --table {table} --mode {sync/dylib/process}` 生成完整插件工程 |
| crudgen 后端生成 | 从数据库表元信息生成 V4 标准 CRUD 后端代码（Controller/Service/DAO/Route） |
| crudweb 前端生成 | 从数据库表元信息生成 Vue 3 + TinyVue 前端数据表格页面 |
| V4 CRUD 路由代理 | ExternalPluginRouteGateway 将 L3 进程插件的 V4 CRUD 路由代理到宿主路由表 |
| 进程崩溃自愈 | cordis-cj 内置 reconcile 循环，子进程崩溃 3 秒内自动重拉 |
| 三轨并存 | sync/dylib/process 三轨插件同时加载、激活、运行，路由共存无冲突 |

#### 四阶段开发里程碑

| 阶段 | 版本 | 内容 | 状态 |
|------|------|------|------|
| 阶段一：插件框架核心 | v0.5 | PluginRegistry/PluginLoader/PluginEventBus/SkillBridge/PluginRouteScanner，38 个集成测试全绿 | ✅ 完成 |
| 阶段二：增量插件化就位 | v0.6 | hello/doc-helper/feedback 示例插件，plugingen 工具链，第一个真实新插件不经框架代码修改上线 | ✅ 完成 |
| 阶段三：L2 动态加载 | v0.7~v0.9 | .dll 运行期加载，不重编宿主装上一个新插件，pluginuninstall 卸载工具 | ✅ 完成 |
| 阶段四：L3 进程隔离轨 | v1.0 | cordis-cj 集成，CordisHostManager/ExternalPluginRouteGateway/CordisHostServices，进程崩溃自愈 | ✅ 完成 |

#### 关键架构决策

- **cordis-cj 集成**：vendored 至 `libs/cordis-cj/`（MIT 许可，5 子包：core/host/plugin/examples/tests），对标 deepseek-harness 的进程隔离方案
- **stdio 传输固定**：L3 轨采用 JSON-RPC over stdio（NewlineFraming 逐行读取），不启用 UDS（Windows 不支持 Unix Domain Socket）
- **宿主侧服务代理**：`host.db`/`host.log`/`host.cache` 三服务经 `CordisHostServices` 注册到每个 `PluginInstance.client`，行级权限宿主侧强制
- **缓存键空间隔离**：`host.cache` 按 `{pluginId}:{key}` 隔离，防止插件间缓存串扰
- **宿主类型重命名**：`PluginManager` → `PluginHostManager`、`PluginEntry` → `PluginManifestEntry`，消解与 cordis-cj 的命名冲突
- **JsonValue 统一**：L3 代码统一使用 `jsonvalue` enum 版本的 `JsonValue`（`Null`/`Boolean`/`Number`/`String`/`Array`/`Map`），不混用 `stdx.encoding.json` class 版本

### 2. cjc 1.1.3 工具链升级与依赖全量本地化

本版本完成了仓颉工具链从 1.0.x 到 1.1.3 的全面升级，并将 cordis-cj 及其传递依赖（jsonvalue、jsonrpc、tomlcj）全量本地化至 `libs/` 目录，消除中心仓网络依赖。

#### 技术架构

| 维度 | v0.0.26 | v0.0.27 |
|------|---------|---------|
| cjc 版本 | 0.55.x | 1.1.3 |
| 依赖声明 | git 仓 + path 混用 | 全量 path 声明，零 git 网络请求 |
| cordis-cj | 未引入 | vendored 至 `libs/cordis-cj/`（5 子包） |
| stdx 版本 | 1.0.5.1 | 1.1.3.1（与 cjc 1.1.3 对齐） |

#### 核心能力

| 能力 | 说明 |
|------|------|
| cjc 1.1.3 适配 | 全部源码适配 cjc 1.1.3 编译器，修复枚举变体语法、构造函数调用、类型推断等兼容性问题 |
| 依赖全量本地化 | cordis-cj、jsonvalue、jsonrpc、tomlcj 全量本地化，cjpm.toml 改为 path 声明 |
| stdx 1.1.3.1 升级 | stdx 动态库从 1.0.5.1 升级到 1.1.3.1，与 cjc 1.1.3 运行时对齐 |
| 进程插件 stdx DLL 注入 | CordisHostManager 启动子进程时将 stdx DLL 目录注入 PATH 环境变量，解决进程插件找不到 DLL 的问题 |

### 3. shenicest 黑客松北辰商管赛道作品

本版本作为 shenicest（神策）黑客松北辰商管赛道参赛作品，完整实现了"一切皆技能"的智能插件系统，展示了从数据库表到全栈 CRUD 应用的秒级交付能力。

#### 赛道作品核心价值

| 价值维度 | 实现方式 |
|----------|----------|
| 场景价值 | 企业管理系统标准 CRUD 模块秒级交付，从数据库表到全栈应用的自动化生成 |
| 多 Agent 协同 | 插件系统支持多插件并行加载、事件总线通信、技能组合编排 |
| Skill 工程体系 | SKILL.md 技能定义 + plugingen/crudgen/crudweb 工具链 + 三轨加载架构 |
| 工程落地与安全审计 | L3 进程隔离轨提供最小权限容器、行级权限宿主侧强制、缓存键空间隔离 |
| 开放开源 | cordis-cj（MIT 许可）全量本地化，对标 deepseek-harness 开源方案 |

#### 参赛演示流程

1. **数据库表设计**：在 PostgreSQL 中创建 `codelabs` 表（代码实验室）
2. **一键生成后端**：`plugingen --name codelabs --db uctoo --table codelabs --mode process` 生成 L3 进程轨插件
3. **一键生成前端**：`crudweb` 生成 Vue 3 + TinyVue 数据表格页面
4. **权限菜单配置**：`codelabs_permissions.sql` 生成三级权限菜单 + i18 多语言数据
5. **启动验证**：宿主自动加载 codelabs 进程插件，注册 V4 CRUD 路由，web-admin 数据表格页面可访问

## 新增功能

### L3 进程隔离轨（cordis-cj 集成）

| 模块 | 文件 | 说明 |
|------|------|------|
| CordisHostManager | `src/plugin/cordis_host_manager.cj` | L3 轨宿主侧控制器，包装 cordis PluginManager/PluginHost/reconcile |
| CordisHostServices | `src/plugin/cordis_host_services.cj` | 宿主侧服务代理，注册 host.db/host.log/host.cache 三服务 |
| ExternalPluginRouteGateway | `src/plugin/external_plugin_route_gateway.cj` | L3 路由网关，V4 CRUD 路由代理转发 |
| CordisHostManager 集成测试 | `src/plugin/integration/cordis_l3_check.cj` | L3 轨 7 验证点集成测试 |

### 插件工具链增强

| 工具 | 增强内容 |
|------|----------|
| plugingen | 新增 `--mode process` 参数，支持生成 L3 进程轨插件（cordis-cj 集成） |
| pluginuninstall | 新增 `--mode process` 参数，支持 L3 进程轨插件卸载（终止子进程 + 清理路由） |
| package_release | 新增 L3 进程插件可执行文件打包、cordis-cj 依赖库 DLL 打包、stdx 1.1.3.1 路径适配 |

### AGENTS.md ↔ agents 表双向同步

| 能力 | 说明 |
|------|------|
| 双向同步 | AGENTS.md → agents 表（syncFromFileSystem）、agents 表 → AGENTS.md（syncToFileSystem） |
| 同名记录更新 | syncFromFileSystem 先按 sourcePath 查找，再按 name 查找，避免创建重复的 MainAgent 记录 |
| 文件变更检测 | ChangeDetector 只收集 AGENTS.md 和 agents/ 子目录下的 .md 文件，不递归扫描整个项目目录 |

## 改进

### 1. 插件系统架构

- 三轨插件加载架构（sync/dylib/process）全面落地，支持从内嵌到进程隔离的全谱系插件加载模式
- L3 进程隔离轨提供崩溃自愈（3 秒内自动重拉）、最小权限容器、行级权限宿主侧强制
- plugingen 一键生成三轨插件，crudgen/crudweb 工具链实现从数据库表到全栈 CRUD 的自动化生成

### 2. 工具链升级

- cjc 1.1.3 全面适配，修复枚举变体语法、构造函数调用、类型推断等兼容性问题
- 依赖全量本地化（path 声明），构建无需 git 网络请求，规避 cjpm 缓存冲突与版本漂移
- stdx 1.1.3.1 升级，与 cjc 1.1.3 运行时对齐

### 3. 数据同步稳定性

- AGENTS.md ↔ agents 表双向同步修复同名记录重复创建的 bug
- ChangeDetector 文件变更检测修复 README.md 等非 Agent 定义文件被错误同步到 agents 表的 bug

## 数据库变更

### codelabs 权限菜单（增量 SQL）

新增 `sql/incremental/codelabs_permissions.sql`，包含：

- `database.uctoo.codelabs` 菜单节点（三级菜单结构）
- i18 多语言数据（中文：代码实验室）
- 5 个 API 路由权限节点（add/edit/del/:id/:limit/:page）
- 6 条角色权限分配（默认管理员角色）

> 本版本不涉及存量表结构变更；插件系统新增的配置表（plugins、plugin_instances 等）已在 v0.0.26 中创建。

## 迁移指南

### 从 v0.0.26 升级

1. **升级 Runtime 服务**
   ```bash
   npm install @opencangjie/skills@latest
   npx skills install-runtime --runtime-version 0.0.27
   npx skills restart
   ```

2. **验证插件系统**
   ```bash
   # 健康检查
   curl http://127.0.0.1:443/api/v1/uctoo/health

   # 查看已加载插件
   curl http://127.0.0.1:443/api/v1/uctoo/plugins
   ```

3. **生成 L3 进程轨插件**
   ```bash
   # 生成 codelabs 进程轨插件
   cjpm run --skip-build --name magic.plugin.tools.plugingen -- \
     --name codelabs --db uctoo --table codelabs --mode process

   # 编译插件
   cd skills/codelabs && cjpm build
   ```

4. **执行权限菜单 SQL**
   ```bash
   psql -U postgres -d uctoo -f sql/incremental/codelabs_permissions.sql
   ```

> 对外 REST API 路径、请求/响应 JSON 结构、WebSocket 消息协议、SSE 事件格式均保持不变，业务侧无需修改。

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~400MB（解压 ~1.35GB）
- 包含: 所有依赖 DLL，内嵌 http_lib 依赖链 + cordis-cj 依赖链

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~170MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

## 安装使用

### 使用 JavaScript SDK

```bash
# 安装 SDK
npm install @opencangjie/skills@latest

# 安装 runtime
npx skills install-runtime --runtime-version 0.0.27

# 启动 runtime
npx skills start
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.27/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑 .env 文件配置数据库连接、AI 模型 API Key 等

# 4. 运行
./bin/agentskills-runtime.exe 443
```

### 生成插件

```bash
# 生成 L3 进程轨插件
cjpm run --skip-build --name magic.plugin.tools.plugingen -- \
  --name {table} --db {db} --table {table} --mode process

# 编译插件
cd skills/{table} && cjpm build

# 配置 config/plugins.yaml 追加 mode:process + command 条目
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
| [插件系统设计规格](./.codeartsdoer/specs/plugin-system/design.md) | 三轨插件架构完整设计文档 |
| [插件系统任务清单](./.codeartsdoer/specs/plugin-system/tasks.md) | 四阶段开发任务清单与完成状态 |
| [cordis-cj 可行性报告](./docs/ref/cangjie-plugin-system-feasibility.md) | cordis-cj 集成可行性分析报告 |
| [codelabs 权限菜单 SQL](./sql/incremental/codelabs_permissions.sql) | codelabs 插件权限菜单增量 SQL |
| [打包发布脚本](./src/scripts/package_release/main.cj) | L3 进程插件可执行文件打包逻辑 |

## 已知问题

- L3 进程隔离轨的 stdx DLL 路径注入依赖 `CANGJIE_STDX_PATH` 环境变量，在某些 cjpm 配置下可能需要手动设置
- cordis-cj 的 UDS（Unix Domain Socket）传输在 Windows 上不可用，已剥离相关代码，仅保留 stdio 传输
- `plugingen --mode process` 生成的插件模板中的 V4 CRUD handler 目前为 TODO 桩，需要根据具体业务逻辑实现
- PC 桌面客户端的 L3 进程轨插件打包支持已添加，但尚未在安装包中实际验证

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区
- shenicest 黑客松北辰商管赛道参赛团队
- cordis-cj 开源项目（ystyle）

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

## 下一版本计划

v0.0.28 计划功能：
- 插件市场 Web UI（技能市场可视化展示与一键安装）
- L3 进程轨插件热更新（不重启宿主替换进程插件版本）
- 跨进程事件桥接（PS-T030：cordis EventRegistry ↔ 进程内 PluginEventBus 桥接）
- 性能监控面板（插件加载时间、路由响应时间、进程资源占用）
- 集群部署支持（多节点插件状态同步）
- shenicest 黑客松决赛提交（L3 进程轨 Demo 完善与性能优化）

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
