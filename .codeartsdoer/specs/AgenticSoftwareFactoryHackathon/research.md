> **本文档由运行时日志恢复（2026-10-02）**：原始会话因 file_read 恒返回空（endLine=-1 语义缺陷）
> 叠加 30 步预算耗尽，研究正文只以聊天回复形式吐出、未落盘。现从
> `logs/agentskills-runtime-20261002-002418.log`（00:50:54 的 `<answer>`）完整抽取原样保留。
> 落盘目录遵循**用户显式指定**（sdd 铁律 #1 冲突消解：用户指定优先于默认目录）。
>
> [注意] 文末「给后续 agent 的提示」第 2 条（`file_read` 会致中文乱码）**已于本次修复后失效**：
> `src/utils/file.cj` 已把 endLine<0 归一为「读到末尾」，file_read 不再返回空/乱码。

# SDD 研究文档（Research）——Agentic Software Factory Hackathon 可复用基础设施前置研究

> 说明：本步为 SDD 六步流水线第 1 步「research（可选，由 enable_research 闸口控制）」。按 sdd 技能铁律，研究文档最终须落到 **runtime 自有目录** `apps/agentskills-runtime/specs/{feature_name}/research.md`，**不得落入 `.codeartsdoer/specs/`**（该目录归 CodeArts Agent）。以下为已完成调研的汇总成果，可直接作为 research.md 正文基础。

---

## 1. 背景与问题（Background / Problem）

**赛事**：Agentic Software Factory Hackathon（ArcBench，https://arc-bench.com/competitions/hackathon），赛期 2026-09-01 → 2026-10-17，队伍 UCTooCom，剩余额度 ¥500.00。主题是"为需求构建软件工厂"——把大需求编译为多个可运行模块的多模块 Agent 系统，而非一次性 demo。

**两道赛题（requirements.yaml 为唯一事实来源）**：

| 赛题 | 根节点 | 规模 | 模块 |
|---|---|---|---|
| 软件工程 · GitHub 风格 ERP | GitHub Collaboration Platform Core Requirements | 3819 行 | Accounts、Organizations、Teams、Repositories、Branches、Issues、Pull requests、Permissions |
| 数据工作区 · Google Sheets 风格 | Core Requirements for an Online Spreadsheet Data Workspace | 3022 行 | Workbooks、Worksheets、Cells、Formulas、Data operations、Filters、Validation、Pivot summaries |

**需求树摘要**：
- GitHub（REQ-1~REQ-6）：身份与访问（注册/登录/找回/登出/改密）、组织与治理（组织发现、团队与成员、仓库授权）、仓库资产管理（搜索、创建/分发、Fork、可见性）、代码与版本控制（浏览文件、提交历史与代码搜索、分支管理、Web UI 管理文件）、工作规划与 Issue（发现、创建讨论、元数据、关闭重开）、变更评审与合并控制（保护分支、PR 发现创建、评审工作区、评审人、合并、关闭重开）。
- Sheet（REQ-1~REQ-5）：工作簿访问与生命周期（导航、创建重命名、CSV 导入导出）、工作表与表结构（增删切换重命名、行列增删）、单元格与区域编辑（直接录入/粘贴二维表/选区、区域复制剪切粘贴/撤销重做）、公式计算（表达式与聚合函数、相对引用复制、依赖重算与错误处理）、数据组织与分析（排序筛选、数据验证、透视汇总）。

**参赛流程**：①上传/选择 agent 快照 → ②把大需求编译为更小可运行模块 → ③按顺序跑 GitHub 风格、表格风格任务 → ④检查证据并迭代至稳定。**规则**：需求文档即事实来源；改动小而可验证；用任务产物解释变更。**提交**：语言限 Python / JavaScript / TypeScript；ZIP 拖拽上传；运行入口在 ZIP 根；提交名 "submission"。

**目标**：产出一套可复用的软件工厂式 SDD 工程方案，将 71 条原子需求（GitHub 47 + Sheet 24）编译为可运行、可验核的模块化交付物，并沉淀可复用的研究/规格/设计/任务文档。

---

## 2. 现状调研（Current State）

### 2.1 赛事提供物（参考 agent 与模板）
- **agent-claude-code-based**（参考实现）：入口契约为 `python3 main.py /path/to/requirements --output-dir /path/to/output --type web`；输入目录须含 `id: ROOT` 的 `requirements.yaml`；agent 先把 `template/` 内容复制到输出目录，再**按 ROOT 的直接子节点逐个**（模块级）交给 Claude Code 顺序实现（在同一输出目录上迭代）；`skills/` 会复制到输出项目 `.claude/skills/`；运行器注入 `OPENAI_API_KEY / OPENAI_BASE_URL / MODEL`（内部映射为 ANTHROPIC_* 并清空 ANTHROPIC_API_KEY）。
- **arcbench-agent-runtime**（Python 包）：提供评测信号能力——`runtime.events`（写入 `.arc/runner-events.jsonl`，如 `mark_design_done`）、`runtime.traceability`（`.arc/traceability/*.json` 需求 CRUD）、`runtime.git`（`ensure_repo` / `commit` / `reset`）。
- **template/**：后端 Node/Express + playwright + vitest（`src/database/{db_runtime,index,init_db,prepare_e2e,seed_db,test_harness}.js`）；前端 Vite/React TS（`src/{App.tsx,main.tsx,pages/HomePage.tsx,api/index.ts}`）。
- **skills/**（3 个）：`arcbench-checkpoint`、`arcbench-runtime-signals`、`arcbench-traceability`。

### 2.2 本仓库已有 SDD 工程文档（`.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/`）
| 文档 | 规模 | 关键内容 |
|---|---|---|
| spec.md | 33915 字 / 1257 行 | 6 节 + EARS 验收，71 条原子需求；后端 `apps/agentskills-runtime`（仓颉 + Fountain ORM + PostgreSQL），前端 `apps/web-admin/web`（Vue 3 + Vite + pinia-orm + OpenTiny）；列出既有表 `uctoo_user / uctoo_session / uctoo_role / user_has_roles / permissions / role_has_permission / db_connection / db_info / crudgen / crudweb / agents / agent_skills / agent_tasks / agent_contexts...` |
| design.md | 45269 字 / 1046 行 | v1.0.0（2026-10-01）；需求拆分 GitHub 47 / Sheet 24 = 71；既有后端分层：74 PO、74 DAO、201 Service、107 Controller、93 Route；前端 70+ store 模型；规划新表 repository/branch/commit/repository_file、issue/issue_comment/milestone/label/pull_request/pr_review/branch_protection、workbook/worksheet/cell/validation_rule/pivot_table |
| tasks.md | 30666 字 / 926 行 | v1.0.0 草案（2026-10-01）；T-01…T-23+ 覆盖 Phase 1–6：DDL 设计、`loaddbinfo`→`crudgen`→`crudweb` 后端五层生成、后端服务、前端 store 模型、GitHub 协作页、表格工作台；优先级 P0/P1；角色 BE/FE/DB/AI/QA；约束：AI 不得执行 `cjpm build` |

### 2.3 可复用基础设施清单（runtime）

**五层架构**（`src/app/`）：`main.cj` + `constants/ controllers/ core/ dao/ middlewares/ models/ registry/ routes/ services/ tools/ utils/`

- **Service 层**（`services/uctoo/`，约 90 个 `.cj`）：TasksService(57KB)、PermissionsService(52KB)、DbInfoService(44KB)、OperateLogService、PointTransactionsService、ConfigService、CompanyService、TaskSettlementsService、MessagesService、SmsLogService、AttachmentsService、UserHasCompanyService、SubAgentInvocationsService、DataAccessAuthorizationService、SddProjectsService、SkillUsageStatsService、AgentApprovalsService 等；另有 `services/{aip,billing,bridge,crontab,lrt,mcp,sync,tool,webmcp,ws_support}/`
- **Controller 层**（`controllers/uctoo/`，约 100 个子包）：agents、agent_*/、ai、aip_*/、company、config、crontab、data_access_authorization、db_connection、db_info、entity、sdd、sdd_projects、skill*、sub_agent_invocations、uctoo_user/session/role、user_has_*、webmcp、ws 等
- **DAO/Model/Route 层**：与 Controller/Service 一一对应的 74 PO / 74 DAO / 93 Route
- **插件系统**（`src/plugin/`，L3 进程隔离三轨架构）：`cordis_host_manager.cj`(23.6KB)、`cordis_host_services.cj`(60.7KB)、`external_plugin_route_gateway.cj`(25KB)、`plugin_loader/registry/discovery_service/dylib_loader/config/agent_tools/sync_bridge/skill_bridge`、`integration/`、`tools/`
- **内置代码生成工具**（`src/app/tools/`，本工程核心复用资产）：
  - `crudgen/CrudGenerator.cj`(84.9KB) + `TemplateEngine.cj` + `templates/`（读 db_info 生成 Model/DAO/Service/Controller/Route + 权限节点）
  - `crudweb/WebCrudGenerator.cj`(49.2KB) + `templates/`（同构生成前端页面）
  - `loaddbinfo/loaddbinfo.cj`（把库表结构装载进 db_info）
- **技能库**（`skills/`，约 50 个）：sdd（+ sdd-design/flow/spec/task/test）、cangjie-coder、web-coder、app-coder、crud-generator、fullstack-codegen、loaddbinfo、long-running-task、uctoo-dev-manual、uctoo-doc、skill-creator 等
- **已有 specs**：001-mcp-agent-skills、002-agentskills-standard-support、003-agentskills-enhancement、web-admin-migration

### 2.4 可复用基础设施清单（web-admin/web）

- **技术栈**：Vue 3 + Vite + TypeScript + TinyVue(@opentiny/vue) + pinia-orm；构建配置齐全（rspack/webpack/farm/vite）
- `src/` 结构：`App.vue / main.ts / locales.json(66KB)` + `api/ assets/ components/ composables/ config/ directive/ hooks/ layout/ lib(webmcp-sdk) locale/ mcp-servers/ mock/ router/ skills/ store/ types/ utils/ views/ webmcp/`
- **api/**：user.ts、role.ts、permission.ts、menu.ts、message.ts、interceptor.ts、request.ts、dashboard.ts、local.ts 等（标准请求/拦截/权限接口）
- **store/**：`models/`（ProfileData、UserData、Board、Ns* 等）+ `models/uctoo/`（生成的模块模型，本工程扩展点）、`modules/`、`seeds/`；并有 `apiContractCheck.ts`、`seedLoader.ts`
- **views/**：ai/（agent_skills/agent_detail/agent_monitor/billing_report/token_dashboard/observability_timeline/data_flow）、aibuilder/、database/（info/uctoo 各表页）、login/、userManager/、system/、board/ 等
- **lib/webmcp-sdk**：含 doc-ai / doc-ai-react / doc-ai-angular / next-remoter / next-sdk——前端智能化（WebMCP/WebAgent + GenUI + PageTool）复用底座
- **数据表**：database/uctoo 页面已覆盖 crontab、entity、permissions、uctoo_user、sdd_projects、long_running_task_artifact、sub_agent_invocations 等大量表，可作为页面/接口复用样板

---

## 3. 方案对比与可行性

| 维度 | 方案 A：纯新写（从零搭） | 方案 B：复用优先（本仓库基建 + 代码生成） |
|---|---|---|
| 后端 | 自建五层 + 新表 | 复用 74PO/74DAO/201Service/107Controller/93Route + `loaddbinfo→crudgen` 生成新模块五层 |
| 前端 | 自建页面 | 复用 Vue3+TinyVue+pinia-orm + `crudweb` 同构生成页面 + WebMCP 智能化 |
| 表设计 | 全部新建 | 除规划新表外，尽量复用既有表与 CRUD 契约 |
| 评测信号 | 需自建 | 复用参考 agent 的 `.arc/runner-events.jsonl` + `.arc/traceability/*.json` + git 契约 |
| 风险 | 工期/一致性风险高 | 需严守"不得新增表以外资产/不得 AI 执行 cjpm build"等约束 |

**结论**：采用**方案 B（复用优先，最小新增）**。本仓库已具备"需求→表→五层→前端页"的完整自动生成链（loaddbinfo/crudgen/crudweb），且已有 spec/design/tasks 与 71 条需求映射，可直接承接赛题；新增聚焦于 GitHub 协作与表格工作区所需的**新表 + 新服务 + 新页面**，其余全部复用。

---

## 4. 技术方案（Recommended）

**4.1 核心思路**：以 requirements.yaml 为事实来源，做**模块级顺序编译**（对齐赛事流程与参考 agent 契约）：
1. 需求解析：ROOT 直接子节点 → 模块列表（GitHub 6 大域 / Sheet 5 大域）；
2. 数据层：为新域设计 DDL（repository/branch/commit/repository_file；issue/issue_comment/milestone/label/pull_request/pr_review/branch_protection；workbook/worksheet/cell/validation_rule/pivot_table）；
3. 后端五层：`loaddbinfo` → `crudgen` 生成 Model/DAO/Service/Controller/Route + 权限节点；
4. 前端：`crudweb` 同构生成页面 + 按赛题场景定制（GitHub 页 / 表格工作台）；
5. 评测与证据：每次模块交付写 `.arc/runner-events.jsonl` 与 `.arc/traceability/*.json`，git 提交留痕。

**4.2 架构（ASCII）**
```
requirements.yaml (ROOT)
  └─ 模块切分（ROOT 直接子节点）
       ├─ GitHub 域 → DDL → loaddbinfo → crudgen(五层) → crudweb(页面) → 场景增强
       └─ Sheet   域 → DDL → loaddbinfo → crudgen(五层) → crudweb(页面) → 公式/透视增强
                          │
        运行时基建：Fountain ORM / PostgreSQL / 插件L3 / 技能库(sdd,cangjie-coder,web-coder,fullstack-codegen)
        前端基建：Vue3+Vite+TinyVue+pinia-orm / WebMCP-SDK
        评测契约：.arc/runner-events.jsonl + .arc/traceability/*.json + git
```

**4.3 评测/可行性方法**：以 tasks.md 的 T-01…T-23+（Phase 1–6，P0/P1）为执行清单，逐模块"生成→构建校验→场景验收"；用 traceability 记录每条 REQ 的落地证据；禁止 AI 执行 `cjpm build`，构建由人工/CI 触发。

**4.4 备选**：仅文档交付（不出代码）；或仅生成后端不生成前端——均因不满足赛题"可运行模块 + 可见证据"而弃用。

---

## 5. 关键风险与未决问题

- **编码坑**：`file_read` 对中文回退为 `?`（BOM 剥离 + 非 ASCII 替换），导致 spec/design/tasks 正文中文不可读。已产出 UTF-8 安全读取脚本 `_u8.py`（+ `_dump.py`/`_head.py`/`_tree.py`/`_req_summary.py`）规避；后续读取中文文档必须走该脚本，且工具结果汇总仍可能丢中文——**待核实**：是否需要以 ASCII 转义方式落盘。
- **规范文档落盘路径**：研究/规格/设计文档必须落 `apps/agentskills-runtime/specs/{feature_name}/`，误落 `.codeartsdoer/specs/` 会违反 sdd 铁律。
- **构建约束**：AI 不得执行 `cjpm build`（tasks.md 明确）。
- **新增表约束**：spec.md §6.7 已声明配额用尽，需确认新表是否在允许清单内（design.md 已规划新表，**待核实**）。
- **需求规模**：两份 requirements.yaml 合计 6800+ 行，需确保模块切分粒度与验收可追踪（REQ 编号一对一）。
- **模型能力**：runtime 需确认 deepseek-flash 的 vision/tools/reasoning 能力（Config.modelCapabilities），以决定评审图/PDF 类素材处理策略。

---

## 6. 对 spec / design / tasks 的输入

- **→ spec**：以 71 条原子需求为主键，保持 GitHub 47 / Sheet 24 拆分与 REQ 编号一致；新增表需补 EARS 验收；既有表复用需在 spec 中标注"复用既有基座"。
- **→ design**：沿用既有分层统计口径（74/74/201/107/93）；明确新表清单与五层生成映射；明确前后端复用组件（TinyVue、WebMCP-SDK、TinyRobot/TinyVue 技能）。
- **→ tasks**：沿用 T-01…T-23+ 的 Phase 1–6 与 P0/P1、BE/FE/DB/AI/QA 角色；保留"AI 不得执行 cjpm build"约束；增加 traceability/runner-events 证据任务。

---

## 附录 A 关键复用文件索引

| 类别 | 路径 |
|---|---|
| 赛事信息 | `.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/hackathon-info.md` |
| 需求（GitHub） | `.codeartsdoer/specs/.../arcbench-hackathon-requirements/hackathon--github/requirements.yaml` |
| 需求（Sheet） | `.codeartsdoer/specs/.../arcbench-hackathon-requirements/hackathon--sheet/requirements.yaml` |
| 参考 agent | `.codeartsdoer/specs/.../agent-claude-code-based/{main.py,README.md,arcbench-agent-runtime/,template/,skills/}` |
| 代码生成 | `apps/agentskills-runtime/src/app/tools/{crudgen,crudweb,loaddbinfo}/` |
| 五层基座 | `apps/agentskills-runtime/src/app/{services/uctoo,controllers/uctoo,dao,models,routes}/` |
| 插件系统 | `apps/agentskills-runtime/src/plugin/` |
| SDD 技能 | `apps/agentskills-runtime/skills/sdd/{SKILL.md,templates/research-template.md}` |
| 前端基座 | `apps/web-admin/web/src/{api,store,views,lib/webmcp-sdk}/` |
| 调研脚本 | `.codeartsdoer/specs/.../{_u8.py,_tree.py,_dump.py,_head.py,_req_summary.py}` |

## 给后续 agent 的提示
1. 研究文档请落 `apps/agentskills-runtime/specs/{feature_name}/research.md`，禁止落 `.codeartsdoer/specs/`。
2. 读中文文档务必用 `_u8.py`（UTF-8 安全），`file_read` 会致中文乱码。
3. 坚持复用优先、最小新增：新表之外不新增框架资产；能力缺口表见第 5 节。
4. 所有未证实信息标"待核实"，尤其是新表配额与模型能力清单。
5. research 阶段只做"清单 + 缺口 + 推荐方案"，不产出实现代码与最终 spec。

**状态**：研究调研已完成（赛事/需求/基座/缺口均已盘点），下一步为把上述内容正式写入 `specs/{feature_name}/research.md` 并过 `gate-research` 闸口。