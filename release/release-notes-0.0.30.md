# AgentSkills Runtime v0.0.30 发布说明

**发布日期**: 2026-10-18
**版本**: 0.0.30
**代号**: Recursive Self-Improvement · Native Multimodal（递归自进化 · 原生多模态）
**平台**: Windows x64, Linux x64, macOS x64/ARM64

> 本版是 0.0.29（Sub-Agent Orchestration）之后的一次大型迭代。主线两条：**① RSI 递归自进化系统从方法论落地为可运行能力**，配套大模型通道管理体系；**② 多模态原生对话 v2**，把文档解析外置为可独立装卸的 L2/L3 插件。同时完成了原生安装器（RuntimeNativeInstaller）的代码闭环、PC 客户端对接、以及 monorepo 开发主目录的奠基。本周期还用 SDD 工程化方法在 `specs/` 下新建/推进了 16 个工程目录（约 80 份文档），并回补修订了 `.codeartsdoer/specs` 中的 6 个目录（22 份文档，含 3 份特性规范）；该目录合计 66 个工程目录为跨 9 个月的历史累积归档，非本周期产出。

---

## 重大变更

### 1. RSI 递归自进化系统（落地）

RSI（Recursive Self-Improvement）是 ASR 的一级能力子系统，定位为"AI 驱动开发框架"的方法论执行中枢。本版把《人工智能软件工程方法论》从理论完整落地为 `skills/RSI` 技能，核心是一套**五阶段循环**：

```
实测 → 根因 → 优化方案 → 防回退 → 约束注入
```

#### 设计铁律与方法论

- **Iron Law RSI-0（确定性优先）**：框架级结构正确性由确定性代码生成工具链保障
  （`loaddbinfo → plugingen|crudgen → crudweb`），LLM 只在需要的流程与位置生成胶水逻辑与非标准实现，
  **不再让其概率性输出单独承担框架级结构正确性**。这是 ASR 相对所有同业 harness 的根本分水岭——不是"去 LLM"，而是让合适的子系统特性由合适的组件提供。
- **Human-Code Preservation（代码保护区）**：自定义代码写在 `//#region Human-Code Preservation` 内，生成器不覆盖，对二次开发友好。
- **不越界**：RSI 不接管框架级结构的手写、不取代人工架构决策、不覆盖保护区内的用户代码、不改动生产数据、不越权改其他子系统私有表/目录。

#### 五阶段循环落地的"心跳"基础设施：大模型通道管理（llm_channel）

RSI 循环需要稳定、可治理、可加密的模型通道支撑。本版随之交付了完整的 **llm_channel 大模型通道管理体系**（代码侧 controllers / daos / services 全套就位，配套 13 个增量 SQL）：

| 子系统 | 内容 |
|--------|------|
| `llm_channel`（通道） | 多通道注册、加密存储 `api_key`（`secret_crypto.cj` 可逆加密，读时掩码）、默认通道解析 |
| `llm_channel_model`（模型目录） | 通道下的模型清单、视觉能力标记（`vision_capability`，2026-10-16 补） |
| `llm_route_rule`（路由规则） | 按前缀/场景的模型路由与影子菜单归并（2026-10-16 权限与菜单修复） |
| `llm_channel_health`（健康） | 通道探活与审计 |
| `llm_channel_audit`（审计） | 通道变更/调用审计留痕 |
| RBAC | `database.uctoo.llm_channel.*` 等权限节点 + 菜单项（2026-10-04~16 分多批注册与修正） |

> 注：原 `config` 表中散落的 LLM 配置项已清理（2026-10-14 `config_cleanup_llm.sql`），`MODEL_*` 真相源收归 `llm_channel`；默认通道回退到 `deepseek` 已修正（2026-10-14/16）。

#### 调度与闭环

- RSI 循环以 **LRT（长程任务）为心跳** 注册为 scheme，支持周期或事件（"构建失败""新需求到来"）触发。
- 验证即闸口：每次变异须经确定性工具生成 + 自动化编译绿条 + SDD 测试步，方可纳入版本管理；失败变异可一键回滚。
- 多技能并行（`src/skill/parallel/*`）受预算与冲突管控，防上下文爆炸。

### 2. 多模态原生对话 v2（解析外置为插件）

把聊天中"图片 / 文档"附件到模型理解回复的端到端链路打通，关键架构决策是：**宿主只做附件的接收、消费与随聊天提交，具体文档格式解析全部外置为宿主外 L2/L3 轨插件**，复用技能生态而非改宿主源码。

工程按铁律 15 拆分为 4 个子系统（`specs/multimodal-native-chat` + 4 个子目录），**代码已先行落地并接线**，`cjpm build` 于 2026-10-15 通过，集成契约已于 2026-10-16 冻结：

| 子系统 (feature_name) | 交付 | 状态 |
|----------------------|------|------|
| `host-attach-core` | 宿主附件消费内核；SPI + 注册表 + 调度降级 + 事件；9 接口（IF-01a~04g）已冻结 | code（契约 2026-10-16 冻结） |
| `doc-parser-plugins` | 文档解析插件轨；存量抽取器搬迁为 `builtin.pdf/text/docx/pptx` 参考解析器（`src/plugin/multimodal/builtin/`） | code（真·外部 L3 插件安装待演示） |
| `web-multimodal` | 前端上传/门控/归一化；WebMCP content 块数组 wire 契约（text/image_url/file）已冻结 | code |
| `attachment-persistence` | 附件元数据加列 + 落库 + 审计；DDL `20261015_attachment_metadata_columns.sql` + Service + Controller + bridge 接线完成 | code |

要点：

- **图片留在宿主通道**：图片不落地解析，直接随聊天提交；文档才走外置解析插件 → 不污染 L3 stdout，新增格式不改宿主源码即可扩展。
- **声明式格式命中**：`ParserRegistry.resolve` 依 `descriptor.formats` 匹配（替代原拟的 `DocumentParser.supports()`，避免单边漂移）。
- **持久化走直传**：`AttachmentSummary` 随 `AgentRequest` 透传落 `agent_messages.attachments` JSON 列；`AttachmentParsed` 事件为冗余通道（已留痕登记）。

> 已知偏差（诚实记录）：`builtin.*` 参考解析器仍在宿主源码树内，非可独立装卸的外部插件；图片元数据尚未进 `attachment-persistence`（P2）；IF-07a 事件总线无订阅者。见各子系统 design.md。

### 3. 插件系统增强：6 子系统 SDD 设计 + 契约草案冻结

基于插件机制横向对比报告（《plugin-mechanism-comparison-wx.html》§9 的 8 条建议）完成基线侦察，把插件系统从"能加载、能跑"推进到"敢让第三方二进制进来"的设计。按铁律 15 拆出 **6 个子系统**（`specs/plugin-system-enhancement` + 6 个子目录），**SDD 全套文档（research/spec/design/tasks/contract 共 29 份）已落盘，集成契约 IF-01~IF-12 冻结为草案**，status 推进到 `task`（待 `gate-task` 确认后进入代码）。

| 子系统 | 对应报告建议 | 要点 |
|--------|------------|------|
| `version-guard` | P0-1 | 加载前版本协商，拒绝不兼容插件（process 轨；dylib 轨预留接口待复活） |
| `capability-handshake` | P0-2 | L3 启动能力宣告握手，声明 vs 实际注册比对，不匹配拒绝挂载 |
| `capability-governance` | P1 | 能力清单 + 运行时门禁（**缺省全拒**）；顺带修复宿主环境全量泄漏给插件进程的安全缺陷 |
| `authoring-toolchain` | P1 | 插件创作工具链增强：模板带测试 + `plugin validate` CLI |
| `lifecycle-observability` | P2→P1 | L3 崩溃自愈可观测（退避/计数/风暴熔断） |
| `dependency-graph` | P2 | 依赖拓扑编排替代 `order` 数字排序 |

实测结论已写入设计：① `dylib` 轨在运行时根本不存在（`PluginDylibLoader` 零调用），本工程只交付 process 轨版本协商；② `src/security/`（六类策略 + DENY 审计）是零引用死代码，要求 `capability-governance` 优先改造复用而非新建；③ `autoRestart`/`healCrashed` 等字段/方法有实现漂移，由 `lifecycle-observability` 补齐。

> 当前状态：**设计 + 契约冻结完成，代码实现待 0.0.31 推进**。这是本版最重要的"规范资产"。

---

## 新增功能

### 大模型通道管理（llm_channel）

如上 §1，提供多通道、加密密钥、路由规则、健康审计、模型目录与视觉能力标记的完整管理体系，并把默认通道真相源修回 `deepseek`。

### 原生安装器 RuntimeNativeInstaller（代码闭环）

installer 工程自身代码至 **T056 闭环**（59 文件 / ~15.0k 行，CLI 主流程通道补齐）：

- **CLI 主流程下沉**：新增 `uc_installer.cmd` 包，`install` / `rollback` / `uninstall` / `devkit install|verify|init` 全部可由 CLI 驱动，HTTP 复用同一底座。
- **NDJSON 流式进度**（`--progress=ndjson`）：逐事件单行输出，诊断走 stderr，末行含 `exitCode/ok`（与 `--json` 互斥）。
- **运维管控模式**（`serve --manage`）：只挂运维端点不推进 S0~S8；观测 runtime 停止后以 0 退出（T056）。
- **跨工程运维端点**（代码已落盘，runtime / web-admin 两侧，待编译验证）：
  - `GET /api/v1/uctoo/ops/logs`：只读运行日志读取，路径白名单防穿越，严禁查业务表冒充日志。
  - `GET /api/v1/uctoo/ops/env`：环境能力采集器（OS/shell/browser/llm/env/skills + 数据库连通/磁盘水位），启动即 `collectAndPersist()` 落 `./runtime/capabilities.json`。
  - `/api/v1/health` 假绿灯修复：`chatModel.available` 改按 `ChannelRegistry.shared().getDefault()` 真实状态判定（禁用/降级/缺失 → false）。
  - web-admin 四面板（配置/日志/环境/监控）改接上述端点，新增"管控后端未运行"态与启动入口。

### PC 客户端对接 ucInstaller（PcClientInstallerIntegration）

| Phase | 内容 | 状态 |
|-------|------|------|
| 1 同步层 | runtime→PC 同步脚本 `scripts/sync-runtime-to-pc.ps1` + 自包含校验 `verify-runtime-sync.ps1` + CI 守卫，消除 39 MB 版本漂移 | ✅ 落地并在跑 |
| 2 installer 接口 | 补 `--version` / `--no-serve` / `--json --version`；`ucInstaller.exe` 进 `release/bin/` | ✅ 代码落地，待出包 |
| 3 委托层 | `installer-bridge.ts`（NDJSON `kind` 事件流解析 + 布局断言）+ `setup.ts` 嵌入式分支 + 进度推送 + 退出码 0-2-6 语义；一并修掉 GAP-6 版本格式不一致（PC 旧解析器读不到 runtime `0.0.29` 空格格式） | ✅ 代码落地并通过 `tsc --noEmit`（2026-10-18） |
| 5 web-admin 副本治理 | `build:web-admin` 链入主链路 + `WEB-ADMIN-MANIFEST.json` 来源指纹 + `verify-web-admin-sync.ps1` 过期检出 | ✅ 代码落地 |
| 4 托管层 / 6 端到端 | 启停经 `serve --manage` 管控、旧启停降级、端到端实测 | ⬜ 待做 |

### 并发技能（concurrent_skills）

技能并行机制评审收尾（2026-10-14）：`concurrent_skills` 全量 SDD 更新至 v2 并代码复核，多技能可同时注入/执行，受预算与冲突管控（见 RSI §"多技能并行"）。

### Agentic Software Factory / 金融行业智能体黑客松

本版作为"7 月之后新进展"的落地载体，内置了金融行业智能体黑客松与 Agentic Software Factory 的种子数据与协作骨架（`sql/incremental/hackathon_*.sql` 系列）：协作平台 + 表格工作台由确定性代码腿工具链生成，印证"一切皆技能 + 确定性代码腿"的可复用性。对应 `.codeartsdoer/specs` 中 `AgenticSoftwareFactoryHackathon` / `fintech-agent-hackathon`。

---

## 改进

### 运行时构建链路

- 2026-10-15 runtime 编译通过：**cjc 1.1.3 + cordis-cj 升级 + 多步任务执行链路修复**（git: `build: runtime 编译通过`）。
- 多步任务（multi-step）执行链路修复，长程任务与子 agent 编排更稳。

### monorepo 开发主目录奠基（UctooMonorepoWorkspace）

- 选定 `D:\UCT\projects\uctoo` 为开发主目录，与 `D:\UCT\products\uctoo`（v4 开源库）语义分离（开发 vs 发行）。
- 选型 **pnpm Workspace + Turborepo**（与 v4 开源库 100% 同构），语言无关地统一编排仓颉（cjpm）/ 前端（vite）/ PC 客户端（electron-builder）/ 小程序（uniapp）/ 鸿蒙（cjpm/DevEco）多套构建系统。
- 固化新人 onboarding 全流程（装 PC 客户端 → clone → `pnpm install` → 各子工程初始化）。
- 2026-10-13 完成仓库初版推送（含 `.gitattributes` 统一行尾为 LF、真实 README）。

### 配置与目录治理

- `20261011_drop_uctoo_api_skill_dir_config.sql`：下线过时的 `UCTOO_API_SKILL_DIR` 配置项。
- `20261014_config_cleanup_llm.sql`：LLM 配置从 `config` 表收归 `llm_channel`。
- `20261013_agents_profile_skills.sql`：agents 画像/技能相关字段（对应 profile 特性规范）。

### SDD 工程化产出（规范资产）

> **口径更正（2026-10-21 复核）**：下文原先表述的"本周期沉淀 66 份特性规范、多数处于 spec/design 待实现"与目录实际更新时间不符，已按实测数据重写。

`.codeartsdoer/specs` 现共 **66 个工程目录 / 451 份文档**，时间跨度 **2025-12 ~ 2026-10-14**（其中 17 个目录的最新修改时间完全相同，为 2026-07-24 05:30 的批量补写）。按文件修改时间统计，**本周期（0.0.29 发布 10-03 → 0.0.30 发布 10-18）内实际有更新的仅 6 个目录、22 个文件**：

| 目录 | 更新时间 | 文件数 | 性质 |
|------|---------|--------|------|
| `concurrent_skills` | 10-13 ~ 10-14 | 5 | 特性规范（v2 修订） |
| `dynamic-model-channel` | 10-04 ~ 10-06 | 5 | 特性规范（本版主线配套） |
| `AgenticSoftwareFactoryHackathon` | 10-03 ~ 10-04 | 4 | 黑客松参赛材料 |
| `profile` | 10-13 | 1 | 参考资料单文件 |
| `plugin-system` | 10-07 | 1 | 单篇缺口记录 |
| `sdd` | 10-14 | 5 | SDD 方法论模板（非特性规范） |

即真正属于「特性规范」的本周期产出是 **3 个目录**（`concurrent_skills` / `dynamic-model-channel` / `plugin-system`），另 2 个为参考资料与黑客松材料、1 个为 SDD 方法论模板——合计 6 个目录、22 份文件，而非 66 份。

**实现方式以"代码先行、文档回补"为主**。具体证据：

- 66 个目录中 **31 个的文档含「存量功能」分析章节**（29 个特性目录 + `sdd`/`sdd-skills` 方法论目录）。典型如 `fullstack-codegen/design.md`、`skill-evolution/design.md`，首章即"一、需求与存量功能关系分析 → 1.1 已实现功能"，逐条列出「需求功能 / 存量功能 / 代码位置 / 匹配度」，匹配度标到 100%（后端 CRUD 生成 → `src/app/tools/crudgen/`）、90%（定时任务调度 → `src/app/services/crontab/SchedulerEngine.cj`）。这是**从既有代码反向整理规范**的结构，不是先设计后实现。
- `concurrent_skills/tasks.md` 头部明载：`完成状态（2026-10-14 复核）：96 项已标注完成 / 15 项待办`，且 v2 修订摘要为"修复渐进式加载设计漂移"——即文档用于记录并校正既有实现。
- 抽样核对源码：已有实现的包括 `concurrent_skills`（→ `src/skill/parallel/budget_manager.cj`、`profile_context_assembler.cj` 等）、`dynamic-model-channel`（→ `src/app/controllers/uctoo/llm_channel/`、`src/app/dao/uctoo/LlmChannelDAO.cj`）、`memory-provider`（→ `src/interaction/memory_provider.cj`）；**查无对应实现**的包括 `agent-intelligence`（RepoMap / PageRank）、`context-optimization`（5 层压缩管道）。

因此这批文档的正确定性是：**既有实现的规范化沉淀 + 未落地特性的设计输入，两者混合**，而非统一"待实现的规范资产"。

**本周期真正新建的 SDD 工程在 `specs/` 下**（19 个目录 / 111 份文档，其中 80 份写于 2026-10）：`plugin-system-enhancement` 主工程 + 6 子系统（10-19，29 份）、`PcClientInstallerIntegration`（10-18）、`RuntimeNativeInstaller`（10-17）、`RSI`（10-17）、`multimodal-native-chat` 主工程 + 4 子系统（10-16）、`web-admin-migration`（10-11）、`UctooMonorepoWorkspace`（10-10）；另 3 个（`001-mcp-agent-skills`、`002-agentskills-standard-support`、`003-agentskills-enhancement`）为 2026-01~02 的历史目录。

---

## 数据库变更

| 脚本 | 内容 |
|------|------|
| `20261004_llm_channel.sql` | `llm_channel` 主表 + 索引 |
| `20261005_llm_channel_permissions.sql` / `llm_route_rule_permissions.sql` / `llm_channel_health_audit_permissions.sql` / `llm_channel_catalog_permission.sql` | 通道/路由/健康/目录 RBAC 注册 |
| `20261006_llm_channel_seed_enabled.sql` / `llm_channel_tighten_permissions.sql` | 默认通道启用 + 权限收紧 |
| `20261014_llm_channel_api_key.sql` | `api_key` 加密列；`llm_channel_default_deepseek.sql` 默认通道修正 |
| `20261015_attachment_metadata_columns.sql` / `attachment_records_permission.sql` | 多模态附件元数据加列 + 权限 |
| `20261016_llm_channel_vision_capability.sql` / `llm_channel_default_deepseek_fix.sql` / `llm_channel_restore_indexes.sql` / `llm_channel_menu_fix_and_crud_pages.sql` / `llm_channel_shadow_menu_reparent.sql` | 视觉能力、默认通道二次修正、索引恢复、菜单与 CRUD 页修复、影子菜单归并 |
| `20261013_agents_profile_skills.sql` | agents 画像/技能字段 |
| `hackathon_*.sql`（2026-10-03~06） | 金融行业智能体黑客松 / Agentic Software Factory 种子数据与锚点重定位 |

> 全部为增量、幂等脚本；`llm_channel` 相关表与 `agent_messages`/`messages` 加列均不含破坏性变更。

---

## 迁移指南

### 从 v0.0.29 升级

1. **执行增量 SQL（幂等，按序执行）**
   ```bash
   psql -U postgres -d uctoo -f sql/incremental/20261004_llm_channel.sql
   psql -U postgres -d uctoo -f sql/incremental/20261005_llm_channel_permissions.sql
   psql -U postgres -d uctoo -f sql/incremental/20261005_llm_route_rule_permissions.sql
   psql -U postgres -d uctoo -f sql/incremental/20261006_llm_channel_seed_enabled.sql
   psql -U postgres -d uctoo -f sql/incremental/20261014_llm_channel_api_key.sql
   psql -U postgres -d uctoo -f sql/incremental/20261014_llm_channel_default_deepseek.sql
   psql -U postgres -d uctoo -f sql/incremental/20261015_attachment_metadata_columns.sql
   psql -U postgres -d uctoo -f sql/incremental/20261016_llm_channel_vision_capability.sql
   psql -U postgres -d uctoo -f sql/incremental/20261016_llm_channel_default_deepseek_fix.sql
   # 其余 20261016_* / 20261013_agents_profile_skills / hackathon_* 按需要执行
   ```

2. **重编主包**（cordis-cj 已升级，建议 clean 以重编依赖）
   ```bash
   cd apps/agentskills-runtime
   cjpm clean && cjpm build
   ```

3. **重出安装器包**（installer 本轮有代码改动）
   ```bash
   cd apps/agentskills-runtime/installer
   cjpm build
   powershell -File package.ps1
   ```

4. **重编 PC 客户端**（Phase 2/3/5 代码已落）
   ```bash
   cd apps/pc-client && npm install && npm run build
   ```

5. **前端依赖重装与构建**
   ```bash
   cd apps/web-admin/web && pnpm install && npm run build
   ```

> 对外 REST API 路径、WebSocket 消息协议、既有 SSE 事件格式保持不变。
> 新增 `llm_channel` 相关端点与 `/api/v1/uctoo/ops/{logs,env}` 只读运维端点；
> `plugin-system-enhancement` 的 6 子系统契约已冻结但**代码尚未实现**，本版不引入插件加载行为变更。

---

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~440MB（解压 ~1.4GB）
- 构建日期: 2026-10-18
- 包含: 所有依赖 DLL，内嵌 http_lib 依赖链 + cordis-cj 依赖链；`libcrypto-3-x64.dll` / `libssl-3-x64.dll` 已由出包脚本复制

### Linux x64
- 待构建发布

### macOS
- x64 / ARM64：待构建发布

---

## 安装使用

### 构建说明

```bash
# 主包（cordis-cj 升级后建议 clean）
cd apps/agentskills-runtime
cjpm clean && cjpm build

# 安装器（独立包，须单独构建并出包）
cd installer && cjpm build && powershell -File package.ps1

# PC 客户端
cd apps/pc-client && npm install && npm run build

# 前端
cd apps/web-admin/web && pnpm install && npm run build
```

### 大模型通道管理快速开始

```bash
# 注册一个通道（api_key 将被加密存储）
curl -X POST /api/v1/uctoo/llm_channel \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"my-deepseek","base_url":"...","api_key":"sk-xxx","is_default":true}'
```

### 启动排障开关（沿用）

```bash
# 怀疑某个 process 插件拖死启动：在拉起前跳过它
set CORDIS_SKIP_PROCESS_PLUGINS=sdd
```

---

## 相关文档

| 文档 | 说明 |
|------|------|
| [RSI 需求规格](./specs/RSI/spec.md) | 递归自进化系统定位、五阶段循环、Iron Law RSI-0 |
| [RSI 研究](./specs/RSI/research.md) | 三层闭环、确定性优先实证 |
| [多模态主工程账本](./specs/multimodal-native-chat/SPECS_INDEX.md) | 4 子系统目录 + 集成契约 IF-01~07 冻结 |
| [host-attach-core 契约](./specs/multimodal-native-chat--host-attach-core/contract.md) | 宿主附件消费内核 9 接口 |
| [插件系统增强主工程账本](./specs/plugin-system-enhancement/SPECS_INDEX.md) | 6 子系统 + 集成契约 IF-01~IF-12 草案 |
| [插件机制横向对比报告](./docs/ref/plugin-mechanism-comparison-wx.html) | §9 对 ASR 的 8 条启示（本版设计来源） |
| [RuntimeNativeInstaller 状态盘点](./specs/RuntimeNativeInstaller/STATUS.md) | 安装器完成度与跨工程项 |
| [PcClientInstallerIntegration 状态](./specs/PcClientInstallerIntegration/STATUS.md) | PC 客户端对接 Phase 1~5 状态 |
| [UctooMonorepoWorkspace 规格](./specs/UctooMonorepoWorkspace/spec.md) | monorepo 目录与工具选型 |
| [特性规范资产目录](./.codeartsdoer/specs/) | 历史累积归档 66 个工程目录 / 451 份文档（本周期更新 6 个、22 份） |

---

## 已知问题

- **插件系统增强 6 子系统尚未进入代码实现**：本版只交付设计与契约草案冻结（status=task），加载行为无变化；dylib 轨版本协商无落点（该轨在运行时不存在），需单独立项复活。
- **多模态 v2 偏差**：`builtin.*` 参考解析器仍在宿主源码树内（非可独立装卸的外部插件），新增格式目前仍需改宿主源码重编；图片元数据未进 `attachment-persistence`（P2）；`AttachmentParsed` 事件总线无订阅者（持久化实际走直传）。真·外部 L3 文档解析插件安装尚未演示（AC4/AC5 需实际证据）。
- **PC 客户端 Phase 4（托管层）与 Phase 6（端到端实测）未做**：当前启停仍部分依赖旧逻辑降级 fallback。
- **会话永不过期 / 日志无滚动**：沿用 0.0.29 已知问题，`login_health_check_20261003.sql` 默认 `ROLLBACK` 干跑，需人工改 `COMMIT` 才生效。
- **stdx 的 OpenSSL DLL 硬编码问题**尚未在 stdx 侧修复：Windows 上用 stdx crypto 且装了 OpenSSL 4.x 的用户仍可能 401，靠出包复制 `*-3-x64.dll` 规避。
- **cjpm 增量构建不因「依赖 compile-option 变更」重编依赖**：cordis-cj 升级后务必 `cjpm clean && cjpm build`，否则新依赖不生效。
- **`.codeartsdoer/specs` 系累积归档，不计入本版交付**：66 个目录中本周期仅 6 个有更新（22 个文件）；其中 29 个特性目录是以「存量功能 / 代码位置 / 匹配度」对照开篇的回补式规范（如 `concurrent_skills` 已 96/111 完成、`fullstack-codegen` 匹配度 100%），另有 `agent-intelligence`、`context-optimization` 等确无源码落地。整体不等同于"66 份待实现的规范"，不构成本版可交付功能。
- **L3 进程轨插件的 `stdx` DLL 路径注入**依赖 `CANGJIE_STDX_PATH` 环境变量，某些 cjpm 配置下可能需手动设置。
- **OpenTiny `genui-sdk-vue` 依赖断裂**、frameworks/vue 与 tiny-robot 0.5.1 版本冲突，GenUI 渲染器集成暂缓（P2）。
- cordis-cj 的 UDS 传输在 Windows 上不可用，L3 轨固定使用 stdio。

---

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区
- OpenTiny 开源社区（TinyRobot / next-remoter / next-sdk）
- cordis-cj 开源项目（ystyle）
- 反馈 OpenTiny 升级、登录 401、PC 客户端版本漂移等问题的社区开发者

---

## 支持

如有问题，请通过以下方式获取帮助：
- AtomGit Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

---

## 下一版本计划

- **插件系统增强 6 子系统进入代码实现**（version-guard / capability-governance / capability-handshake / dependency-graph / lifecycle-observability / authoring-toolchain），落地"缺省全拒"能力门禁与加载前版本协商。
- **多模态 v2 收口**：演示真·外部 L3 文档解析插件安装（AC4/AC5）；图片元数据进 `attachment-persistence`；补 `AttachmentParsed` 事件订阅或移除冗余通道。
- **PC 客户端 Phase 4/6**：`serve --manage` 管控启停、端到端实测。
- **插件市场 Web UI**：技能市场可视化展示与一键安装（呼应 0.0.29 计划）。
- **L3 进程轨插件热更新**：不重启宿主替换插件版本。
- **运维可视化**：把 `/api/v1/uctoo/ops/{logs,env}` 能力接入前端面板（环境能力、日志、健康看板）。
- **会话过期与日志滚动**：把 `login_health_check` 软删与保留策略产品化。
- **SDD 规范资产转化**：把 `.codeartsdoer/specs` 中已评审的特性规范（agent-intelligence / skill-evolution / concurrent-skills / profile / memory-provider 等）逐步推进到代码实现。
- **OpenTiny 依赖跟随官方发行线**；`tiny-robot` 维持 0.5.1 直至官方 catalog 放开。

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
