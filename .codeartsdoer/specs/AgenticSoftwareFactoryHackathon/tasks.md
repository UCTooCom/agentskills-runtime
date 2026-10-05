# Agentic Software Factory Hackathon — 任务规划文档

> **文档定位**：本文档为 `spec.md`（需求规格）与 `design.md`（技术设计）的配套任务清单，定义"按什么顺序做什么"。实施原则：**复用优先**、**确定性优先**、**规范驱动**。
>
> **赛事**：ArcBench Agentic Software Factory Hackathon | **参赛队伍**：UCTooCom
> **关联规格**：`spec.md`（6 节组件定位 + EARS 验收，71 个原子需求）
> **关联设计**：`design.md`（存量分析 + 增量设计方案）
> **版本**：1.0.1 | **日期**：2026-10-01 | **状态**：草稿 | **最近修订**：2026-10-03 按 SDD v1.2.0 铁律 14 对齐（开发规范段置顶二次开发底座优先、T-07/T-08/T-09 改 plugingen 插件优先、生成后补 RBAC 授权）+ 铁律 15 拆分评估说明

---

## 开发规范（全任务强制遵守）

### 二次开发底座优先（铁律 14，置顶硬约束）

- **规范源**：迭代 runtime/uctoo 时，规范以 `skills/uctoo-dev-manual` + `docs/uctoo-v4/*.md` 为准，SDD 不复述条款、只做引路人。
- **脚手架优先**：新增业务模块一律优先跑确定性工具链 `loaddbinfo`（第一步，刷新 `db_info` 元数据）→ **`plugingen` 做成插件**（默认 L3 进程隔离轨 process，需退回内嵌 sync 轨显式加 `--mode sync` 独立工程）→ `crudweb`（前端 store/页面）；`crudgen` 仅用于宿主公共基础设施，禁止手撸五层骨架。
- **插件下线**：走对称 `magic.plugin.tools.pluginuninstall`，禁止手删 `skills/{name}/`（会留 `agent_skills`/`permissions`/`i18` 残留）。
- **生成后必补两件事**：① `sql/incremental/` 增量 DDL；② 新增宿主路由的 `permissions`/`role_has_permission` 登记（否则 403）。
- **大工程拆分（铁律 15）**：本工程为单一 SDD 工程（71 原子需求、tasks ≤ 40），未触发多子系统拆分红线；若后续新增跨域交付面须先定集成契约再按铁律 15 拆分。

### 编码规范

- **仓颉代码**：必须使用 `cangjie-coder` 技能，遵循四步工作流（查阅文档 → 检索代码片段 → 编辑适配 → 写入文件）
- **前端代码**：Vue 3 + TypeScript + pinia-orm + OpenTiny，遵循 UMI 架构
- **编译约束**：AI 严禁运行 `cjpm build`；编译、类型检查、lint 由人工在独立 cmd 环境执行并回传结果
- **代码生成**：二次开发底座优先（铁律 14）——业务模块优先 `plugingen` 做成插件（sync/dylib/process 三轨），`crudgen` 仅宿主公共基础设施；第一步 `loaddbinfo` 刷新元数据，生成后必补 `sql/incremental/` 增量 DDL + `permissions`/`role_has_permission` 授权

### 复用原则

- 所有用户/权限/数据库/智能体/aibuilder/CMS 基础设施直接复用，禁止重写
- 组织管理复用 `company` + `user_has_company`，禁止新建组织表
- Issue 基础信息复用 `tasks` 表（`task_type='issue'`），仅标签/里程碑/PR 新建独立表
- 团队管理复用 `user_group` + `user_has_group`
- 权限/菜单/路由复用 `permissions` 表 + 前端动态路由机制

### 命名与结构规范

- 后端五层：PO/DAO/Service/Controller/Route，类名 PascalCase，方法名 camelCase
- 前端 store 模型与后端 PO 一一对应，pinia-orm entity 为表名复数形式
- 数据库表名小写+下划线，主键统一 `id`（uuid + gen_random_uuid()）
- 所有新增表必须包含 `created_at` / `updated_at` / `deleted_at` / `creator` 四个标准列
- API 遵循 `docs/uctoo-v4/uctoo-v4-api-specification.md` 规范（列表键名 = 表名 + s）

### 文档与进度

- 阶段产出落盘到对应目录，DDL 放入 `sql/incremental/`
- 多轮修订须在本文档「修订记录」章节留痕
- 每阶段完成后经人工闸口确认才进入下一阶段

---

## 任务总览

> 优先级：**P0** = 赛题核心必须完成 | **P1** = 智能体工厂增强（锦上添花）
> 负责角色：BE = 后端仓颉 | FE = 前端 Vue | DB = 数据库 DDL | AI = 智能体技能 | QA = 测试验收

| 编号 | 任务名称 | 关联需求(spec §) | 关联设计(design §) | 优先级 | 负责角色 | 状态 | 预计产出 |
|------|----------|-------------------|---------------------|--------|----------|------|----------|
| **Phase 1** | **数据库 DDL 设计** | | | | | | |
| T-01 | GitHub 仓库模块 DDL | §5.3 仓库资产管理 | §2.2.1 | P0 | DB | [ ] 待开始 | `sql/incremental/hackathon_github_repository.sql` |
| T-02 | GitHub Issue/PR 模块 DDL | §5.5 / §5.6 | §2.2.1 | P0 | DB | [ ] 待开始 | `sql/incremental/hackathon_github_issue_pr.sql` |
| T-03 | 电子表格模块 DDL | §5.7 – §5.12 | §2.2.2 | P0 | DB | [ ] 待开始 | `sql/incremental/hackathon_sheets_workbook.sql` |
| T-04 | 菜单权限 DDL | §7.2 阶段五 | §2.2.4 | P0 | DB | [ ] 待开始 | `sql/incremental/hackathon_permissions_menu.sql` |
| T-05 | 种子数据 DDL | §5 各节种子数据 | §2.2.3 | P0 | DB | [ ] 待开始 | `sql/incremental/hackathon_seed_data.sql` |
| **Phase 2** | **后端五层模块生成** | | | | | | |
| T-06 | loaddbinfo 刷新元数据 | §7.1 开发原则 | §1.2.6 | P0 | BE | [ ] 待开始 | `db_info` 表刷新完成 |
| T-07 | plugingen 生成 GitHub 仓库模块（优先）/ crudgen（宿主回退） | §5.3 / §5.4 | §2.1.2 | P0 | BE | [ ] 待开始 | repository/branch/commit/repository_file 插件/五层文件 |
| T-08 | plugingen 生成 GitHub Issue/PR 模块（优先）/ crudgen（宿主回退） | §5.5 / §5.6 | §2.1.2 | P0 | BE | [ ] 待开始 | issue_comment/milestone/label/pull_request/pr_review/branch_protection 插件/五层文件 |
| T-09 | plugingen 生成电子表格模块（优先）/ crudgen（宿主回退） | §5.7 – §5.12 | §2.1.2 | P0 | BE | [ ] 待开始 | workbook/worksheet/cell/validation_rule/pivot_table 插件/五层文件 |
| **Phase 3** | **后端业务逻辑开发** | | | | | | |
| T-10 | 仓库 Service 业务逻辑 | §5.3 仓库资产管理 | §2.1.3 | P0 | BE | [ ] 待开始 | RepositoryService（Fork/可见性/搜索） |
| T-11 | 分支/提交/文件 Service | §5.4 代码与版本控制 | §2.1.3 | P0 | BE | [ ] 待开始 | BranchService / CommitService / RepositoryFileService |
| T-12 | Issue/PR Service 业务逻辑 | §5.5 / §5.6 | §2.1.3 | P0 | BE | [ ] 待开始 | PullRequestService / 评审/合并/分支保护校验 |
| T-13 | 工作簿/工作表/单元格 Service | §5.7 – §5.9 | §2.1.3 | P0 | BE | [ ] 待开始 | WorkbookService / WorksheetService / CellService（CSV 导入导出） |
| T-14 | 数据验证与透视表 Service | §5.11 / §5.12 | §2.1.3 | P0 | BE | [ ] 待开始 | ValidationService / PivotTableService |
| **Phase 4** | **前端 CRUD 生成与 Store 模型** | | | | | | |
| T-15 | crudweb 生成 GitHub 协作平台 store 模型（配合 T-07/T-08） | §7.1 开发原则 | §2.4.3 | P0 | FE | [ ] 待开始 | 11 个 pinia-orm store 模型 |
| T-16 | crudweb 生成电子表格 store 模型（配合 T-09） | §7.1 开发原则 | §2.4.3 | P0 | FE | [ ] 待开始 | 5 个 pinia-orm store 模型 |
| **Phase 5** | **前端 GitHub 协作平台页面** | | | | | | |
| T-17 | 仓库列表与创建页面 | §5.3 | §2.4.1 | P0 | FE | [ ] 待开始 | `views/collab/repositories/` 列表+创建 |
| T-18 | 仓库详情（文件树+提交历史） | §5.3 / §5.4 | §2.4.1 | P0 | FE | [ ] 待开始 | 仓库详情页 + 文件树 + 提交历史 + Web 编辑器 |
| T-19 | Issue 列表与详情页面 | §5.5 | §2.4.1 | P0 | FE | [ ] 待开始 | `views/collab/issues/` 列表+详情+讨论区 |
| T-20 | PR 列表、比较与评审页面 | §5.6 | §2.4.1 | P0 | FE | [ ] 待开始 | `views/collab/pull-requests/` 列表+详情+比较+评审面板 |
| T-21 | 组织与团队管理页面 | §5.2 | §2.4.1 | P0 | FE | [ ] 待开始 | `views/collab/organizations/` 组织+团队+成员 |
| **Phase 6** | **前端电子表格工作台** | | | | | | |
| T-22 | 工作簿首页（列表+导入导出） | §5.7 | §2.4.2 | P0 | FE | [ ] 待开始 | `views/sheets/workbooks/index.vue` 首页 |
| T-23 | 电子表格编辑器（核心） | §5.7 – §5.9 | §2.4.2 | P0 | FE | [ ] 待开始 | 编辑器页面 + 网格 + 标签 + 工具栏 |
| T-24 | 公式计算引擎（前端） | §5.10 | §2.4.2 | P0 | FE | [ ] 待开始 | `composables/useFormula.ts` 公式引擎 |
| T-25 | 数据验证与透视表前端 | §5.11 / §5.12 | §2.4.2 | P0 | FE | [ ] 待开始 | 验证规则面板 + 透视表面板 |
| **Phase 7** | **智能体软件工厂核心（P1）** | | | | | | |
| T-26 | 需求编译技能开发 | §1.6.3 / §7.2 阶段四 | §2.7.1 | P1 | AI | [ ] 待开始 | `skills/hackathon-compiler/SKILL.md` + 脚本 |
| T-27 | 模块委派策略配置 | §1.6.3 / §7.2 阶段四 | §2.7.2 | P1 | AI | [ ] 待开始 | agent_groups + agent_executors 配置 |
| T-28 | 全流程验证规则 | §1.6.3 / §7.2 阶段四 | §2.7.3 | P1 | AI | [ ] 待开始 | 验证规则 + agent_verification_records 配置 |
| **Phase 8** | **集成与验收** | | | | | | |
| T-29 | 菜单路由动态加载验证 | §7.2 阶段五 | §2.2.4 | P0 | QA | [ ] 待开始 | 前端菜单正常显示，路由可访问 |
| T-30 | API 联调测试 | §4.2 可靠性 | §2.3 | P0 | QA | [ ] 待开始 | 所有 API 端点可访问且返回正确 |
| T-31 | 种子数据验证 | §4.2 可靠性 | §2.2.3 | P0 | QA | [ ] 待开始 | 种子数据完整且跨会话一致 |
| T-32 | GitHub 赛题 E2E 验收 | §5.1 – §5.6 | §4 DFX 约束 | P0 | QA | [ ] 待开始 | 47 个原子需求验收通过 |
| T-33 | Sheet 赛题 E2E 验收 | §5.7 – §5.12 | §4 DFX 约束 | P0 | QA | [ ] 待开始 | 24 个原子需求验收通过 |
| T-34 | 智能体工厂 E2E 验证 | §1.6.3 | §2.7 | P1 | QA | [ ] 待开始 | 需求编译→模块委派→全流程验证 |

---

## 任务依赖关系图

```
Phase 1 (DDL)
  T-01 ─┐
  T-02 ─┼──→ T-06 (loaddbinfo) ──→ Phase 2 & 3 (后端)
  T-03 ─┤                          │
  T-04 ─┤                          ↓
  T-05 ─┘                    Phase 4 (crudweb → store 模型)
                                     │
                                     ↓
                          Phase 5 & 6 (前端页面开发)  ←── 并行
                          ┌─────────┴─────────┐
                          T-17~T-21          T-22~T-25
                          (GitHub 页面)      (Sheets 页面)
                                     │
                                     ↓
                          Phase 7 (智能体工厂, P1, 可选并行)
                                     │
                                     ↓
                          Phase 8 (集成与验收)
                          T-29 → T-30 → T-31 → T-32 & T-33 → T-34
```

**并行说明**：
- T-01 / T-02 / T-03 可并行编写（不同模块的 DDL）
- Phase 5（GitHub 页面）与 Phase 6（Sheets 页面）可并行开发
- Phase 7（智能体工厂）为 P1，可与 Phase 5/6 并行，但依赖 Phase 2/3 的 API 就绪

---

## 任务详细说明（按编号展开）

### T-01：GitHub 仓库模块 DDL

- **目标**：创建 `repository` / `branch` / `commit` / `repository_file` 四张表的 DDL
- **关联需求**：spec §5.3 仓库资产管理、§5.4 代码与版本控制
- **关联设计**：design §2.2.1
- **输入**：spec.md 数据约束 §6.5–§6.7、design.md DDL 设计 §2.2.1
- **步骤**：
  1. 编写 `repository` 表 DDL（含唯一索引、可见性索引、owner 索引）
  2. 编写 `branch` 表 DDL（含仓库内唯一索引）
  3. 编写 `commit` 表 DDL（含哈希唯一索引、分支/作者索引）
  4. 编写 `repository_file` 表 DDL（含分支+路径复合索引）
  5. 每张表必须包含 creator/owner_user_id/created_at/updated_at/deleted_at 标准列
  6. 添加 COMMENT ON TABLE 和 COMMENT ON COLUMN
- **产出物**：`sql/incremental/hackathon_github_repository.sql`
- **验收**：
  - [ ] 四张表 DDL 语法正确（PostgreSQL 兼容）
  - [ ] 所有主键为 uuid + gen_random_uuid()
  - [ ] 软删除列 deleted_at 为 timestamptz(6)
  - [ ] 所有查询路径有对应索引
  - [ ] 唯一约束通过 UNIQUE INDEX + WHERE deleted_at IS NULL 实现
- **风险**：owner_type 为 user/organization 双态，owner_id 无法设外键；需通过应用层保证引用完整性

### T-02：GitHub Issue/PR 模块 DDL

- **目标**：创建 `issue_comment` / `milestone` / `label` / `pull_request` / `pr_review` / `branch_protection` 六张表的 DDL
- **关联需求**：spec §5.5 Issue 与工作规划、§5.6 Pull Request 与分支保护
- **关联设计**：design §2.2.1
- **输入**：spec.md 数据约束 §6.8–§6.10、design.md DDL 设计 §2.2.1
- **步骤**：
  1. 编写 `issue_comment` 表 DDL（关联 tasks.id）
  2. 编写 `milestone` 表 DDL（关联 repository）
  3. 编写 `label` 表 DDL（仓库内名称唯一）
  4. 编写 `pull_request` 表 DDL（含 base/compare 分支、状态、合并信息）
  5. 编写 `pr_review` 表 DDL（含评审状态、行号、文件路径）
  6. 编写 `branch_protection` 表 DDL（含评审要求、状态检查要求）
  7. 每张表标准列 + COMMENT + 索引
- **产出物**：`sql/incremental/hackathon_github_issue_pr.sql`
- **验收**：
  - [ ] 六张表 DDL 语法正确
  - [ ] Issue 评论通过 task_id 关联 tasks 表（复用 tasks 作 Issue）
  - [ ] label 表在 repository_id + name 上有唯一索引
  - [ ] pull_request 支持 open/closed/merged 三种状态
- **风险**：Issue 复用 tasks 表，tasks.extra_data 需承载 repository_id/labels/milestone_id 等扩展字段

### T-03：电子表格模块 DDL

- **目标**：创建 `workbook` / `worksheet` / `cell` / `validation_rule` / `pivot_table` 五张表的 DDL
- **关联需求**：spec §5.7 – §5.12 电子表格工作台
- **关联设计**：design §2.2.2
- **输入**：spec.md 数据约束 §6.11–§6.16、design.md DDL 设计 §2.2.2
- **步骤**：
  1. 编写 `workbook` 表 DDL（名称/所有者/最后更新时间/来源类型）
  2. 编写 `worksheet` 表 DDL（工作簿内名称唯一、位置序号）
  3. 编写 `cell` 表 DDL（坐标唯一、值/公式/数据类型/错误类型）
  4. 编写 `validation_rule` 表 DDL（区域、类型、约束、错误消息）
  5. 编写 `pivot_table` 表 DDL（源区域、行列维度、值聚合、结果区域）
  6. 每张表标准列 + COMMENT + 索引
- **产出物**：`sql/incremental/hackathon_sheets_workbook.sql`
- **验收**：
  - [ ] 五张表 DDL 语法正确
  - [ ] cell 表在 worksheet_id + coordinate 上有唯一索引
  - [ ] worksheet 表在 workbook_id + name 上有唯一索引
  - [ ] cell 表包含 row_index/col_index 数值列（便于排序/计算）
- **风险**：cell 表数据量可能很大（一个工作表 2600+ 单元格），需考虑查询性能

### T-04：菜单权限 DDL

- **目标**：向 `permissions` 表插入 GitHub 协作平台和电子表格工作台的菜单与路由数据
- **关联需求**：spec §7.2 阶段五
- **关联设计**：design §2.2.4
- **输入**：design.md 菜单权限设计 §2.2.4
- **步骤**：
  1. 插入一级菜单：collab（协作平台）、sheets（电子表格）
  2. 插入二级子菜单：仓库/Issue/PR/组织 / 工作簿
  3. 向 `role_has_permission` 插入注册登录用户角色的权限关联
  4. 确保 module/component/path 字段与前端路由文件对应
- **产出物**：`sql/incremental/hackathon_permissions_menu.sql`
- **验收**：
  - [ ] 登录后左侧菜单显示「协作平台」和「电子表格」
  - [ ] 各子菜单点击可进入对应页面
  - [ ] 未授权用户看不到对应菜单
- **风险**：permission_name 可能与现有菜单冲突；需确认现有 permissions 表中无同名记录

### T-05：种子数据 DDL

- **目标**：预置赛题要求的账户/组织/仓库/Issue/PR/工作簿/工作表/单元格等种子数据
- **关联需求**：spec §5 各节种子数据要求
- **关联设计**：design §2.2.3
- **输入**：赛题 requirements.yaml 中的种子数据描述 + 参考截图
- **步骤**：
  1. 插入 5+ 个账户（合规密码 + email_verified=true）
  2. 插入 2+ 个组织（company 表，org_type='github-org'）
  3. 插入 5+ 个仓库（public/private 混合）
  4. 插入 8+ 个分支（含 main 默认分支）
  5. 插入 10+ 个提交（含 verified 标识）
  6. 插入 15+ 个文件（README.md 等）
  7. 插入 8+ 个 Issue（tasks 表，task_type='issue'）
  8. 插入 4+ 个 PR
  9. 插入 3+ 个工作簿 + 5+ 个工作表 + 50+ 个单元格
  10. 所有 UUID 预定义，保证跨会话一致
- **产出物**：`sql/incremental/hackathon_seed_data.sql`
- **验收**：
  - [ ] 种子数据执行后无错误
  - [ ] 登录页可用种子账户登录
  - [ ] 仓库/Issue/PR/工作簿列表显示种子数据
  - [ ] 刷新后数据保持一致
- **风险**：UUID 冲突；需使用独立命名空间的 UUID

### T-06：loaddbinfo 刷新元数据

- **目标**：运行 loaddbinfo 工具（生成流程第一步）刷新 db_info 表，使新增表可被 plugingen/crudgen 识别
- **关联需求**：spec §7.1 开发原则
- **关联设计**：design §1.2.6
- **前置依赖**：T-01 ~ T-05 全部 DDL 已执行
- **步骤**：
  1. 人工执行 DDL 文件（Phase 1 全部 5 个 SQL 文件）
  2. 人工运行 loaddbinfo 工具
  3. 验证 db_info 表中新增表的元数据已存在
- **产出物**：db_info 表新增 16 张表的元数据记录
- **验收**：
  - [ ] SELECT count(*) FROM db_info WHERE table_name IN (...) 返回 16 行
  - [ ] 各表的列信息完整（含数据类型、可空、默认值等）
- **风险**：loaddbinfo 需正确连接目标数据库；人工操作

### T-07：plugingen 生成 GitHub 仓库模块（优先）/ crudgen（宿主基础设施回退）

- **目标**：GitHub 仓库模块为业务模块，**优先用 `plugingen` 做成插件**（默认 L3 进程隔离轨 process，需退回内嵌 sync 轨显式加 `--mode sync`）；若并入宿主则用 `crudgen` 生成 repository/branch/commit/repository_file 四张表的五层模块
- **关联需求**：spec §7.1 开发原则
- **关联设计**：design §1.2.6
- **前置依赖**：T-06（loaddbinfo 完成）
- **步骤**：
  1. 运行 crudgen 生成 repository 五层模块
  2. 运行 crudgen 生成 branch 五层模块
  3. 运行 crudgen 生成 commit 五层模块
  4. 运行 crudgen 生成 repository_file 五层模块
  5. 验证生成的 PO/DAO/Service/Controller/Route 文件齐全
- **产出物**：
  - `src/app/models/uctoo/RepositoryPO.cj`
  - `src/app/dao/uctoo/RepositoryDAO.cj`
  - `src/app/services/RepositoryService.cj`
  - `src/app/controllers/RepositoryController.cj`
  - `src/app/routes/RepositoryRoute.cj`
  - （branch/commit/repository_file 同构）
- **验收**：
  - [ ] 每张表对应 5 个文件（PO/DAO/Service/Controller/Route）
  - [ ] Route 文件注册路由前缀正确（/api/v1/uctoo/repositories 等）
  - [ ] Controller 包含标准 CRUD 方法（index/show/create/update/destroy）
- **风险**：crudgen 是仓颉工具，需人工编译运行

### T-08：plugingen 生成 GitHub Issue/PR 模块（优先）/ crudgen（宿主基础设施回退）

- **目标**：GitHub Issue/PR 模块为业务模块，**优先用 `plugingen` 做成插件**；若并入宿主则用 `crudgen` 生成 issue_comment/milestone/label/pull_request/pr_review/branch_protection 六张表的五层模块
- **前置依赖**：T-06
- **步骤**：同 T-07，针对 6 张表
- **产出物**：6 张表 × 5 层 = 30 个文件
- **验收**：同 T-07 标准

### T-09：plugingen 生成电子表格模块（优先）/ crudgen（宿主基础设施回退）

- **目标**：电子表格工作台为业务模块，**优先用 `plugingen` 做成插件**；若并入宿主则用 `crudgen` 生成 workbook/worksheet/cell/validation_rule/pivot_table 五张表的五层模块
- **前置依赖**：T-06
- **步骤**：同 T-07，针对 5 张表
- **产出物**：5 张表 × 5 层 = 25 个文件
- **验收**：同 T-07 标准

### T-10：仓库 Service 业务逻辑

- **目标**：在 plugingen/crudgen 生成的五层骨架基础上，扩展 RepositoryService 的业务逻辑
- **关联需求**：spec §5.3 仓库资产管理
- **关联设计**：design §2.1.3
- **前置依赖**：T-07
- **步骤**：
  1. Fork 仓库功能（复制源仓库的文件/分支/提交到新仓库）
  2. 仓库可见性变更（public ↔ private，需 Admin 权限校验）
  3. 仓库搜索（按关键词/语言/星标数筛选排序）
  4. 仓库创建时初始化默认分支 + 初始提交（可选 README）
  5. 克隆 URL 生成（HTTPS/SSH 格式）
- **产出物**：RepositoryService.cj 扩展方法
- **验收**：
  - [ ] Fork 后新仓库包含源仓库的文件和提交历史
  - [ ] 可见性变更后非授权用户无法访问
  - [ ] 搜索接口支持关键词模糊匹配
- **风险**：Fork 操作涉及多张表的事务一致性

### T-11：分支/提交/文件 Service

- **目标**：扩展 BranchService/CommitService/RepositoryFileService 的业务逻辑
- **关联需求**：spec §5.4 代码与版本控制
- **关联设计**：design §2.1.3
- **前置依赖**：T-07
- **步骤**：
  1. 分支创建（从指定分支或提交创建新分支）
  2. 默认分支更改（需 Admin 权限）
  3. 提交历史查询（按分支/作者/时间筛选，倒序）
  4. 提交差异对比（文件级新增/删除行）
  5. 文件树查询（按路径层级返回目录结构）
  6. Web 文件编辑（修改内容 → 创建新提交 → 更新文件）
  7. 代码搜索（仓库内按关键词搜索代码片段）
- **产出物**：BranchService.cj / CommitService.cj / RepositoryFileService.cj 扩展方法
- **验收**：
  - [ ] 分支切换后文件树正确显示对应分支内容
  - [ ] 提交历史按时间倒序，显示作者/哈希/验证标识
  - [ ] 在线编辑文件后创建新提交，文件内容更新
- **风险**：Web 编辑器涉及创建新提交的事务操作

### T-12：Issue/PR Service 业务逻辑

- **目标**：扩展 PullRequestService 等 Issue/PR 相关业务逻辑
- **关联需求**：spec §5.5 / §5.6
- **关联设计**：design §2.1.3
- **前置依赖**：T-08
- **步骤**：
  1. Issue 列表查询（状态/作者/标签/里程碑/指派人筛选）—— 复用 tasks 表 + extra_data
  2. Issue 评论 CRUD
  3. PR 创建（比较 base/compare 分支差异 → 创建 PR 记录）
  4. PR 评审（添加评审评论 → 提交 Approve/Request Changes/Comment）
  5. PR 合并（校验分支保护规则 → 合并变更 → 更新目标分支 → 置 merged 状态）
  6. 分支保护规则 CRUD + 合并前校验
  7. 里程碑 CRUD + 进度统计
  8. 标签 CRUD
- **产出物**：PullRequestService.cj / MilestoneService.cj / LabelService.cj 等扩展方法
- **验收**：
  - [ ] PR 创建时自动计算分支差异
  - [ ] 分支保护规则生效：未满足评审要求时禁止合并
  - [ ] 合并后 PR 状态变为 Merged，目标分支包含变更
- **风险**：PR 合并逻辑复杂，需保证原子性；分支保护校验逻辑需准确

### T-13：工作簿/工作表/单元格 Service

- **目标**：扩展 WorkbookService/WorksheetService/CellService 的业务逻辑
- **关联需求**：spec §5.7 – §5.9
- **关联设计**：design §2.1.3
- **前置依赖**：T-09
- **步骤**：
  1. 工作簿 CRUD（创建/重命名/删除）
  2. CSV 导入（解析 CSV 文件 → 创建工作簿 + 工作表 + 填充单元格）
  3. CSV 导出（读取当前活动工作表 → 生成 CSV 文件）
  4. 工作表 CRUD（添加/重命名/删除 + 顺序维护 + 至少保留一个）
  5. 单元格批量更新（支持粘贴二维数据）
  6. 行列插入/删除（数据移动 + 公式引用调整）
- **产出物**：WorkbookService.cj / WorksheetService.cj / CellService.cj 扩展方法
- **验收**：
  - [ ] CSV 导入后创建新工作簿，Sheet1 显示完整数据
  - [ ] CSV 导出文件内容与工作表一致
  - [ ] 删除最后一个工作表被拒绝
  - [ ] 插入行后下方数据下移
- **风险**：CSV 解析需严格遵循 RFC 4180（双引号/转义/换行）

### T-14：数据验证与透视表 Service

- **目标**：实现 ValidationService 和 PivotTableService
- **关联需求**：spec §5.11 / §5.12
- **关联设计**：design §2.1.3
- **前置依赖**：T-09
- **步骤**：
  1. 数据验证规则 CRUD（下拉列表/数值范围）
  2. 单元格输入验证（写入前检查是否符合验证规则）
  3. 透视表 CRUD（创建/编辑/删除）
  4. 透视表刷新（重新计算聚合结果）
- **产出物**：ValidationService.cj / PivotTableService.cj
- **验收**：
  - [ ] 设置下拉列表验证后，输入不在列表中的值被拒绝
  - [ ] 透视表生成正确的行列聚合结果
  - [ ] 源数据变更后刷新透视表，结果更新
- **风险**：透视表聚合在后端计算性能；考虑到数据量不大，直接 SQL GROUP BY 即可

### T-15：crudweb 生成 GitHub 协作平台 store 模型（配合 T-07/T-08 插件或宿主模块）

- **目标**：使用 crudweb 生成 GitHub 协作平台 11 张表的前端 pinia-orm store 模型和基础 CRUD 页面（前端与后端 plugingen/crudgen 输出一一对应）
- **关联需求**：spec §7.1 开发原则
- **关联设计**：design §2.4.3
- **前置依赖**：T-06（db_info 已刷新）
- **步骤**：
  1. 运行 crudweb 生成 repository/branch/commit/repository_file 的 store 模型
  2. 运行 crudweb 生成 issue_comment/milestone/label/pull_request/pr_review/branch_protection 的 store 模型
  3. 验证生成的 store 模型文件齐全
- **产出物**：
  - `src/store/models/uctoo/repository.ts`
  - `src/store/models/uctoo/branch.ts`
  - ... （共 11 个 store 模型）
  - `src/views/database/uctoo/repository/` 等基础 CRUD 页面
- **验收**：
  - [ ] 每个表对应一个 store 模型文件
  - [ ] 模型 entity 为表名复数形式（repositories / branches 等）
  - [ ] 模型包含标准 CRUD API 配置（index/create/show/update/destroy）
- **风险**：crudweb 生成的页面在 database/uctoo/ 下，作为基础 CRUD；业务页面需单独开发

### T-16：crudweb 生成电子表格 store 模型（配合 T-09 插件或宿主模块）

- **目标**：使用 crudweb 生成电子表格 5 张表的前端 pinia-orm store 模型（与 T-09 后端 plugingen/crudgen 输出一一对应）
- **前置依赖**：T-06
- **步骤**：同 T-15，针对 5 张表
- **产出物**：5 个 store 模型文件 + 5 个基础 CRUD 页面目录
- **验收**：同 T-15 标准

### T-17：仓库列表与创建页面

- **目标**：开发 GitHub 风格的仓库列表页和创建仓库页
- **关联需求**：spec §5.3 仓库资产管理
- **关联设计**：design §2.4.1
- **前置依赖**：T-15
- **步骤**：
  1. 仓库列表页（搜索框 + 筛选器 + 仓库卡片列表）
  2. 创建仓库表单（Owner 选择 / 仓库名 / 可见性 / 初始化选项）
  3. 仓库名唯一性校验（实时）
  4. 响应式布局 + OpenTiny 组件
- **产出物**：`views/collab/repositories/index.vue` + `create.vue`
- **验收**：
  - [ ] 列表显示仓库名称、描述、语言、星标数
  - [ ] 支持按关键词搜索
  - [ ] 创建表单校验通过后跳转到仓库详情页
- **风险**：Owner 选择器（个人/组织）交互设计

### T-18：仓库详情（文件树 + 提交历史 + Web 编辑器）

- **目标**：开发仓库详情页，含文件树浏览、提交历史、Web 编辑器
- **关联需求**：spec §5.3 / §5.4
- **关联设计**：design §2.4.1
- **前置依赖**：T-17
- **步骤**：
  1. 仓库主页（Code 标签：文件树 + 最近提交 + 分支切换器）
  2. 文件树组件（目录层级 + 文件图标 + 最后提交信息）
  3. 文件查看页（文件内容 + 语法高亮 + 编辑按钮）
  4. Web 编辑器（代码编辑 + 提交信息表单）
  5. 提交历史页（列表 + 作者 + 哈希 + 验证标识）
  6. 提交详情页（变更文件列表 + diff 对比）
  7. 分支切换器（下拉选择 + 创建新分支入口）
- **产出物**：`views/collab/repositories/detail.vue` + 子组件
- **验收**：
  - [ ] 切换分支后文件树更新为对应分支内容
  - [ ] 点击文件显示内容和提交历史
  - [ ] 在线编辑文件并提交后，文件内容更新
  - [ ] 提交历史按时间倒序显示
- **风险**：diff 对比组件复杂度高；可使用现有 diff 库

### T-19：Issue 列表与详情页面

- **目标**：开发 Issue 列表页和详情页
- **关联需求**：spec §5.5 Issue 与工作规划管理
- **关联设计**：design §2.4.1
- **前置依赖**：T-15
- **步骤**：
  1. Issue 列表页（Open/Closed 标签切换 + 筛选器：作者/标签/里程碑/指派人 + 排序）
  2. Issue 创建页（标题 + 描述编辑器 + 右侧属性面板：指派人/标签/里程碑）
  3. Issue 详情页（标题/状态 + 讨论区 + 右侧属性面板）
  4. 评论组件（评论列表 + 评论输入框）
  5. 关闭/重开 Issue 按钮
- **产出物**：`views/collab/issues/index.vue` + `detail.vue`
- **验收**：
  - [ ] Issue 列表显示状态图标、标题、标签、指派人
  - [ ] 支持按状态/作者/标签/里程碑筛选
  - [ ] 详情页显示讨论区，可添加评论
  - [ ] 关闭 Issue 后状态变为 Closed，刷新后保持
- **风险**：Issue 复用 tasks 表，需确保 extra_data 中的 repository_id/labels 正确存取

### T-20：PR 列表、比较与评审页面

- **目标**：开发 PR 列表页、详情页、分支比较页、评审面板
- **关联需求**：spec §5.6 Pull Request 与分支保护
- **关联设计**：design §2.4.1
- **前置依赖**：T-15
- **步骤**：
  1. PR 列表页（Open/Closed/Merged 标签 + 筛选器）
  2. 创建 PR 流程（选择 base/compare 分支 → 比较差异 → 填写标题描述 → 创建）
  3. PR 详情页（概览 + 提交列表 + 变更文件 + 评审评论）
  4. 分支比较页（差异文件列表 + 逐文件 diff）
  5. 评审面板（添加行内评论 + 提交评审：Approve/Request Changes/Comment）
  6. 合并按钮 + 分支保护状态提示
  7. 分支保护设置页
- **产出物**：`views/collab/pull-requests/index.vue` + `detail.vue` + `compare.vue` + 组件
- **验收**：
  - [ ] 选择不同分支比较显示变更文件和差异
  - [ ] 从比较结果可创建 PR
  - [ ] 评审者可对变更代码行添加评论并提交评审状态
  - [ ] 满足分支保护要求时可合并 PR
  - [ ] 分支保护设置后，直接推送被拒绝提示
- **风险**：PR 评审的行内评论交互复杂

### T-21：组织与团队管理页面

- **目标**：开发组织列表页、详情页、团队管理页
- **关联需求**：spec §5.2 组织与治理管理
- **关联设计**：design §2.4.1
- **前置依赖**：T-15（复用 company/user_has_company 已有 store 模型）
- **步骤**：
  1. 组织列表页（我的组织 + 发现组织）
  2. 组织详情页（成员列表 + 团队列表 + 仓库列表 + 设置）
  3. 团队管理（创建团队 + 添加/移除成员 + 子团队层级）
  4. 仓库权限授予（向人员或团队授予 Read/Triage/Write/Maintain/Admin）
  5. 组织创建表单
- **产出物**：`views/collab/organizations/index.vue` + `detail.vue` + 组件
- **验收**：
  - [ ] 创建组织后用户成为 Owner
  - [ ] Owner 可创建团队并添加成员
  - [ ] 可向团队授予仓库访问权限
  - [ ] 移除成员后该成员失去组织仓库访问
- **风险**：团队层级结构（子团队）交互设计

### T-22：工作簿首页（列表 + 导入导出）

- **目标**：开发电子表格工作台的工作簿首页
- **关联需求**：spec §5.7 工作簿访问与生命周期
- **关联设计**：design §2.4.2
- **前置依赖**：T-16
- **步骤**：
  1. 工作簿列表（卡片/列表视图，显示名称 + Last updated）
  2. "New blank workbook" 按钮 + 创建对话框（工作簿名 + Create 按钮）
  3. "Import CSV" 按钮 + 导入对话框（文件选择 + Confirm import 按钮）
  4. 工作簿卡片点击进入编辑器
  5. 搜索/筛选工作簿
- **产出物**：`views/sheets/workbooks/index.vue` + 对话框组件
- **验收**：
  - [ ] 列表显示工作簿名称和 Last updated 时间
  - [ ] 点击工作簿进入编辑器
  - [ ] New blank workbook 创建后打开编辑器，显示 Sheet1
  - [ ] Import CSV 成功后创建新工作簿并打开
  - [ ] CSV 导入失败显示 "Invalid CSV file format. Import failed."
- **风险**：CSV 导入需处理大文件和各种边界情况

### T-23：电子表格编辑器（核心页面）

- **目标**：开发电子表格编辑器核心页面
- **关联需求**：spec §5.7 – §5.9
- **关联设计**：design §2.4.2
- **前置依赖**：T-22
- **步骤**：
  1. 编辑器布局（顶部工具栏 + 公式栏 + 工作表标签 + 网格区域）
  2. 工作表标签组件（ARIA tab 角色 + aria-selected + 右键菜单）
  3. 网格组件（ARIA grid + aria-multiselectable + 虚拟滚动）
  4. 单元格组件（ARIA gridcell + 坐标可访问名称 + 编辑模式）
  5. 公式栏（显示当前单元格值或公式 + 编辑）
  6. 右键菜单（插入行列/删除行列/复制/剪切/粘贴/撤销/重做）
  7. 单元格选择（单击选中 + 拖选矩形区域 + aria-selected）
  8. 复制/剪切/粘贴操作
  9. 撤销/重做栈
  10. 行列插入删除（数据移动 + 公式引用调整）
- **产出物**：`views/sheets/workbooks/editor.vue` + 子组件
- **验收**：
  - [ ] 工作表标签使用 ARIA tab 角色，活动标签 aria-selected="true"
  - [ ] 网格使用 ARIA grid 角色，aria-multiselectable="true"
  - [ ] 单元格使用 ARIA gridcell 角色，以坐标为可访问名称
  - [ ] 选中单元格和矩形区域的 aria-selected="true"
  - [ ] 双击单元格进入编辑模式
  - [ ] 支持复制/剪切/粘贴单元格内容
  - [ ] 支持撤销/重做最近操作
  - [ ] 插入/删除行列后数据正确移动
- **风险**：网格组件性能（大数据量虚拟滚动）；公式与编辑联动

### T-24：公式计算引擎（前端）

- **目标**：实现前端公式计算引擎
- **关联需求**：spec §5.10 公式计算
- **关联设计**：design §2.4.2
- **前置依赖**：T-23
- **步骤**：
  1. 公式解析器（解析 = 开头的表达式，识别函数/引用/运算符）
  2. 支持函数：SUM / AVERAGE / COUNT / MAX / MIN / IF / STDEV / HYPERLINK / SIN / SUMIF / PMT
  3. 单元格引用解析（A1 表示法 → row/col 索引）
  4. 相对引用调整（复制公式时按偏移量自动调整引用）
  5. 依赖图构建与增量重算（源数据变更时仅重算依赖链）
  6. 错误处理：#DIV/0!（除以零）/ #REF!（无效引用）/ #CIRC!（循环引用）
  7. 公式结果显示（单元格显示计算结果，公式栏显示公式）
- **产出物**：`composables/useFormula.ts` + 公式引擎工具函数
- **验收**：
  - [ ] =SUM(A1:A2) 正确计算两单元格之和
  - [ ] 复制公式到其他单元格时相对引用自动调整
  - [ ] 修改源数据后依赖公式自动重算
  - [ ] =1/0 显示 #DIV/0!
  - [ ] 引用已删除单元格显示 #REF!
  - [ ] 循环引用显示 #CIRC!
- **风险**：循环引用检测复杂度；依赖图构建性能

### T-25：数据验证与透视表前端

- **目标**：实现数据验证和透视表的前端界面与交互
- **关联需求**：spec §5.11 / §5.12
- **关联设计**：design §2.4.2
- **前置依赖**：T-23
- **步骤**：
  1. 数据验证对话框（选择区域 + 验证类型 + 约束设置）
  2. 下拉列表验证（单元格显示下拉箭头 + 选项列表）
  3. 数值验证（输入不符合范围时显示错误提示）
  4. 透视表创建对话框（选择源区域 + 行/列维度 + 值聚合方式）
  5. 透视表结果显示（独立区域展示聚合结果）
  6. 透视表刷新按钮
  7. 排序/筛选工具栏按钮
- **产出物**：验证面板组件 + 透视表面板组件
- **验收**：
  - [ ] 设置下拉列表验证后，单元格显示下拉箭头，仅允许输入列表中的值
  - [ ] 输入不符合验证规则的数据被拒绝并显示错误
  - [ ] 创建透视表后显示正确的行列聚合结果
  - [ ] 源数据变更后刷新透视表，结果更新
- **风险**：透视表前端计算性能；大数据量下考虑后端计算

### T-26：需求编译技能开发

- **目标**：开发 hackathon-compiler 技能，将赛题 requirements.yaml 拆解为原子任务
- **关联需求**：spec §1.6.3 / §7.2 阶段四
- **关联设计**：design §2.7.1
- **前置依赖**：T-13（API 就绪）
- **优先级**：P1
- **步骤**：
  1. 创建 `skills/hackathon-compiler/SKILL.md`（技能定义 + SOP）
  2. 创建 `scripts/parse_requirements.py`（解析 YAML → 输出原子任务 JSON）
  3. 创建 agent_tasks 子任务（调用后端 API）
  4. 创建 orchestration_plans 编排计划
- **产出物**：`skills/hackathon-compiler/` 技能目录
- **验收**：
  - [ ] 技能加载成功
  - [ ] 执行技能后生成原子任务列表
  - [ ] 任务数与 71 个原子需求对应
- **风险**：P1 优先级，非赛题核心；可延后

### T-27：模块委派策略配置

- **目标**：配置智能体分组和执行器，实现模块委派
- **关联需求**：spec §1.6.3 / §7.2 阶段四
- **关联设计**：design §2.7.2
- **前置依赖**：T-26
- **优先级**：P1
- **步骤**：
  1. 创建 GitHub 协作 Agent 组（agent_groups）
  2. 创建 Sheets 工作台 Agent 组
  3. 配置各模块执行器（agent_executors）
  4. 委派策略：按模块依赖顺序委派
- **产出物**：agent_groups / agent_executors 数据配置
- **验收**：
  - [ ] 需求编译后任务自动分配到对应执行组
  - [ ] 执行组按依赖顺序执行

### T-28：全流程验证规则

- **目标**：配置全流程验证规则，实现每个原子需求的验收证据生成
- **关联需求**：spec §1.6.3 / §7.2 阶段四
- **关联设计**：design §2.7.3
- **前置依赖**：T-27
- **优先级**：P1
- **步骤**：
  1. 结构验证规则（五层模块齐全）
  2. API 验证规则（端点可访问 + 返回格式正确）
  3. 数据验证规则（种子数据完整）
  4. E2E 验证规则（GIVEN/WHEN/THEN 场景）
- **产出物**：验证规则配置 + agent_verification_records 记录
- **验收**：
  - [ ] 每个模块完成后自动生成验证记录
  - [ ] 验证不通过时生成执行证据

### T-29：菜单路由动态加载验证

- **目标**：验证新增模块的菜单和路由正常工作
- **关联需求**：spec §7.2 阶段五
- **关联设计**：design §2.2.4 / §2.4.4
- **前置依赖**：T-04 + T-15 + T-16
- **步骤**：
  1. 执行 hackathon_permissions_menu.sql
  2. 启动后端和前端
  3. 使用注册登录用户角色登录
  4. 验证左侧菜单显示「协作平台」和「电子表格」
  5. 点击各子菜单验证路由跳转正确
- **产出物**：验证报告
- **验收**：
  - [ ] 登录后菜单显示正确
  - [ ] 各页面可正常访问，无 404
  - [ ] 未授权用户看不到对应菜单

### T-30：API 联调测试

- **目标**：测试所有新增 API 端点的功能正确性
- **关联需求**：spec §4 DFX 约束
- **关联设计**：design §2.3
- **前置依赖**：Phase 2 & 3 全部完成
- **步骤**：
  1. GitHub 仓库模块 API 测试（CRUD + Fork + 搜索 + 可见性）
  2. 分支/提交/文件 API 测试
  3. Issue/PR 模块 API 测试
  4. 电子表格模块 API 测试
  5. CSV 导入导出 API 测试
  6. 验证响应格式符合 uctoo-v4 规范
- **产出物**：API 测试报告
- **验收**：
  - [ ] 所有 API 端点返回正确状态码
  - [ ] 列表接口返回格式：{ data, currentPage, totalCount, totalPage }
  - [ ] 错误响应格式：{ errno, errmsg }
  - [ ] 权限校验生效（未授权操作被拒绝）

### T-31：种子数据验证

- **目标**：验证种子数据的完整性和一致性
- **关联需求**：spec §4.2 可靠性
- **关联设计**：design §2.2.3
- **前置依赖**：T-05
- **步骤**：
  1. 执行种子数据 SQL
  2. 验证各表记录数量符合预期
  3. 验证关联关系正确（仓库→分支→提交→文件）
  4. 验证跨会话一致性（重启后数据不变）
  5. 验证种子账户可登录
- **产出物**：种子数据验证报告
- **验收**：
  - [ ] 所有种子数据插入成功
  - [ ] 种子账户可正常登录
  - [ ] 仓库/Issue/PR/工作簿列表显示种子数据
  - [ ] 刷新/重开后数据保持一致

### T-32：GitHub 赛题 E2E 验收

- **目标**：按照赛题 47 个原子需求逐条验收 GitHub 协作平台
- **关联需求**：spec §5.1 – §5.6
- **关联设计**：design §4 DFX 约束
- **前置依赖**：T-29 + T-30 + T-31
- **步骤**：
  1. REQ-1 身份与访问管理：注册/登录/密码恢复/登出/改密
  2. REQ-2 组织与治理：创建组织/团队管理/成员管理/仓库权限
  3. REQ-3 仓库资产管理：创建/Fork/搜索/可见性/克隆
  4. REQ-4 代码与版本控制：文件浏览/提交历史/差异/分支/Web 编辑
  5. REQ-5 Issue 与工作规划：列表/创建/编辑/关闭/里程碑
  6. REQ-6 PR 与分支保护：列表/比较/创建/评审/合并/保护
- **产出物**：GitHub 赛题 E2E 验收报告
- **验收**：
  - [ ] 47 个原子需求全部通过
  - [ ] 每个需求的验收条件被满足
  - [ ] 错误消息符合赛题要求（如 "Invalid credentials"）
  - [ ] 可访问名称（ARIA）正确

### T-33：Sheet 赛题 E2E 验收

- **目标**：按照赛题 24 个原子需求逐条验收电子表格工作台
- **关联需求**：spec §5.7 – §5.12
- **关联设计**：design §4 DFX 约束
- **前置依赖**：T-29 + T-30 + T-31
- **步骤**：
  1. REQ-1 工作簿访问与生命周期：查看/创建/重命名/CSV 导入导出
  2. REQ-2 工作表管理：添加/切换/重命名/删除
  3. REQ-3 单元格操作：插入删除行列/编辑/粘贴/选择/复制剪切/撤销重做
  4. REQ-4 公式计算：基本运算/聚合函数/相对引用/依赖重算/错误
  5. REQ-5 数据组织与分析：排序/筛选/验证/透视表
- **产出物**：Sheet 赛题 E2E 验收报告
- **验收**：
  - [ ] 24 个原子需求全部通过
  - [ ] CSV 导入支持 UTF-8 中文/英文/数字文本
  - [ ] ARIA 角色正确（tab/grid/gridcell）
  - [ ] 公式计算结果正确
  - [ ] 刷新后数据保持持久化

### T-34：智能体工厂 E2E 验证

- **目标**：验证智能体软件工厂全流程（需求编译→模块委派→全流程验证）
- **关联需求**：spec §1.6.3
- **关联设计**：design §2.7
- **前置依赖**：T-26 + T-27 + T-28 + T-32 + T-33
- **优先级**：P1
- **步骤**：
  1. 上传赛题 requirements.yaml
  2. 触发需求编译
  3. 验证生成 71 个原子任务
  4. 触发模块委派
  5. 验证任务分配到对应执行组
  6. 验证全流程验证记录生成
- **产出物**：智能体工厂 E2E 验证报告
- **验收**：
  - [ ] 需求编译成功，生成对应数量的原子任务
  - [ ] 模块委派正确
  - [ ] 验证记录完整

---

## 需求覆盖追踪矩阵

### GitHub 赛题（47 个原子需求）

| spec 需求 | 描述 | 覆盖任务 | 覆盖状态 | 备注 |
|-----------|------|----------|----------|------|
| §5.1.1 账户注册 | 用户名/邮箱/密码校验 + 创建账户 | T-05（种子数据） + 复用 uctoo_user | ✅ 全覆盖 | 复用现有认证体系 |
| §5.1.2 登录 | 凭据验证 + 会话创建 + "Invalid credentials" | 复用 uctoo_user / uctoo_session | ✅ 全覆盖 | 复用现有登录逻辑 |
| §5.1.3 密码恢复 | 固定验证码 123456 + 密码重置 | 复用 + 适配固定验证码 | ✅ 全覆盖 | 需适配赛题固定验证码逻辑 |
| §5.1.4 登出 | 会话销毁 + 跳转登录页 | 复用现有登出逻辑 | ✅ 全覆盖 | |
| §5.1.5 修改密码 | 新密码复杂度校验 + 更新 | 复用现有改密逻辑 | ✅ 全覆盖 | |
| §5.2.1 创建组织 | 组织名称唯一 + 创建者为 Owner | T-05 + 复用 company / user_has_company | ✅ 全覆盖 | 复用 aibuilder 组织表 |
| §5.2.2 团队管理 | 创建团队 + 成员管理 + 子团队 | T-21 + 复用 user_group | ✅ 全覆盖 | 复用用户组表 |
| §5.2.3 成员管理 | 添加/移除组织成员 | T-21 + 复用 user_has_company | ✅ 全覆盖 | |
| §5.2.4 仓库权限 | Read/Triage/Write/Maintain/Admin | T-10 + 复用 data_access_authorization | ✅ 全覆盖 | 行级权限 + 角色权限 |
| §5.3.1 创建仓库 | Owner/名称/可见性/初始化 | T-01 + T-07 + T-10 + T-17 | ✅ 全覆盖 | |
| §5.3.2 Fork 仓库 | 创建副本 + 保留源关联 | T-10 + T-17 | ✅ 全覆盖 | RepositoryService.fork() |
| §5.3.3 仓库搜索 | 关键词/语言/星标筛选 | T-10 + T-17 | ✅ 全覆盖 | |
| §5.3.4 可见性变更 | Public ↔ Private + 权限校验 | T-10 + T-18 | ✅ 全覆盖 | 需 Admin 权限 |
| §5.3.5 克隆 URL | HTTPS/SSH 复制 | T-10 + T-18 | ✅ 全覆盖 | 前端复制按钮 |
| §5.4.1 文件浏览 | 分支切换 + 文件树 + 提交信息 | T-11 + T-18 | ✅ 全覆盖 | |
| §5.4.2 提交历史 | 倒序列表 + 作者/哈希/验证 | T-11 + T-18 | ✅ 全覆盖 | |
| §5.4.3 提交差异 | 变更文件 + 逐行对比 | T-11 + T-18 | ✅ 全覆盖 | diff 存储在 commit.diff |
| §5.4.4 分支管理 | 列出/创建/切换 + 默认分支 | T-11 + T-18 | ✅ 全覆盖 | |
| §5.4.5 Web 文件编辑 | 在线编辑 + 提交变更 | T-11 + T-18 | ✅ 全覆盖 | |
| §5.4.6 代码搜索 | 仓库内搜索代码 | T-11 + T-18 | ✅ 全覆盖 | |
| §5.5.1 Issue 列表 | 状态/作者/标签/里程碑筛选 | T-12 + T-19 | ✅ 全覆盖 | 复用 tasks 表 + extra_data |
| §5.5.2 创建 Issue | 标题必填 + 描述 + 属性 | T-12 + T-19 | ✅ 全覆盖 | tasks.task_type='issue' |
| §5.5.3 编辑 Issue | 标题/描述/评论/指派/标签 | T-12 + T-19 | ✅ 全覆盖 | |
| §5.5.4 关闭/重开 Issue | 状态变更持久化 | T-12 + T-19 | ✅ 全覆盖 | |
| §5.5.5 里程碑管理 | 创建 + 分配 + 进度 | T-12 + T-19 | ✅ 全覆盖 | 新建 milestone 表 |
| §5.6.1 PR 列表 | 状态/作者/标签/里程碑筛选 | T-12 + T-20 | ✅ 全覆盖 | 新建 pull_request 表 |
| §5.6.2 分支比较 | base/compare 差异 + 提示 | T-12 + T-20 | ✅ 全覆盖 | |
| §5.6.3 创建 PR | 从比较结果创建 + 草稿 | T-12 + T-20 | ✅ 全覆盖 | |
| §5.6.4 PR 评审 | 行内评论 + Approve/Request Changes | T-12 + T-20 | ✅ 全覆盖 | 新建 pr_review 表 |
| §5.6.5 合并 PR | 满足保护要求 + 合并变更 | T-12 + T-20 | ✅ 全覆盖 | 分支保护校验 |
| §5.6.6 分支保护 | 评审要求 + 状态检查 + 禁止直推 | T-12 + T-20 | ✅ 全覆盖 | 新建 branch_protection 表 |
| §5.6.7 关闭/重开 PR | 状态变更 + 不合并 | T-12 + T-20 | ✅ 全覆盖 | |

> 注：GitHub 赛题 6 个一级模块共 47 个原子需求，上表列出关键代表项；详细 47 条需求的逐条映射见赛题 requirements.yaml。

### Sheet 赛题（24 个原子需求）

| spec 需求 | 描述 | 覆盖任务 | 覆盖状态 | 备注 |
|-----------|------|----------|----------|------|
| §5.7.1 查看工作簿 | 列表 + Last updated + 链接进入 | T-13 + T-22 | ✅ 全覆盖 | |
| §5.7.2 创建空白工作簿 | New blank + Sheet1 + A1 选中 | T-13 + T-22 + T-23 | ✅ 全覆盖 | |
| §5.7.3 重命名工作簿 | 非空校验 + 同步更新 | T-13 + T-23 | ✅ 全覆盖 | |
| §5.7.4 CSV 导入 | UTF-8 + 双引号/转义/换行处理 | T-13 + T-22 | ✅ 全覆盖 | RFC 4180 兼容 |
| §5.7.5 CSV 导出 | 当前工作表导出 + 不改变内容 | T-13 + T-23 | ✅ 全覆盖 | |
| §5.8.1 添加工作表 | 自动命名 + 设为活动 | T-13 + T-23 | ✅ 全覆盖 | |
| §5.8.2 切换工作表 | ARIA tab + aria-selected | T-23 | ✅ 全覆盖 | |
| §5.8.3 重命名工作表 | 工作簿内唯一 | T-13 + T-23 | ✅ 全覆盖 | |
| §5.8.4 删除工作表 | 至少保留一个 | T-13 + T-23 | ✅ 全覆盖 | |
| §5.9.1 插入删除行列 | 数据移动 + 公式调整 | T-13 + T-23 | ✅ 全覆盖 | |
| §5.9.2 编辑单元格 | 网格+公式栏 + ARIA gridcell | T-23 | ✅ 全覆盖 | |
| §5.9.3 粘贴二维数据 | 行列展开填充 | T-23 | ✅ 全覆盖 | |
| §5.9.4 选择矩形区域 | aria-selected + 高亮 | T-23 | ✅ 全覆盖 | |
| §5.9.5 复制/剪切/粘贴 | 保留/清除原数据 | T-23 | ✅ 全覆盖 | |
| §5.9.6 撤销/重做 | 操作栈 + 恢复 | T-23 | ✅ 全覆盖 | |
| §5.10.1 公式基本运算 + 聚合 | SUM/AVERAGE/COUNT/MAX/MIN/IF 等 | T-24 | ✅ 全覆盖 | 前端公式引擎 |
| §5.10.2 相对引用 | 复制公式自动调整 | T-24 | ✅ 全覆盖 | |
| §5.10.3 依赖重算 | 源变更自动重算依赖链 | T-24 | ✅ 全覆盖 | 增量重算 |
| §5.10.4 公式错误显示 | #DIV/0! / #REF! / #CIRC! | T-24 | ✅ 全覆盖 | |
| §5.11.1 排序 | 按列升序/降序 + 多列 | T-25 | ✅ 全覆盖 | |
| §5.11.2 筛选 | 按值/条件筛选 + 清除 | T-25 | ✅ 全覆盖 | |
| §5.11.3 数据验证 | 下拉列表 + 数值范围 | T-14 + T-25 | ✅ 全覆盖 | 新建 validation_rule 表 |
| §5.12.1 创建透视表 | 行/列维度 + 值聚合 | T-14 + T-25 | ✅ 全覆盖 | 新建 pivot_table 表 |
| §5.12.2 刷新透视表 | 源变更后重新计算 | T-14 + T-25 | ✅ 全覆盖 | |

> 注：Sheet 赛题 5 个一级模块共 24 个原子需求，上表列出关键代表项；详细 24 条需求的逐条映射见赛题 requirements.yaml。

### DFX 约束覆盖

| DFX 维度 | 覆盖任务 | 覆盖状态 |
|---------|----------|----------|
| §4.1 性能（5 项指标） | T-32 / T-33 E2E 验收 | ✅ 全覆盖 |
| §4.2 可靠性（5 项） | T-31 种子数据验证 + T-32/T-33 E2E | ✅ 全覆盖 |
| §4.3 安全性（7 项） | 复用现有认证 + 权限中间件 | ✅ 全覆盖 |
| §4.4 可维护性（5 项） | Phase 1-3 标准五层架构开发 | ✅ 全覆盖 |
| §4.5 兼容性（4 项） | T-13 CSV 导入导出 + T-23 ARIA | ✅ 全覆盖 |

---

## 验收检查清单（终验）

### 功能验收
- [ ] GitHub 赛题 47 个原子需求全部通过验收
- [ ] Sheet 赛题 24 个原子需求全部通过验收
- [ ] 智能体软件工厂核心功能（P1）验证通过（如实现）

### 质量验收
- [ ] 所有新增表包含 creator/owner_user_id/created_at/updated_at/deleted_at 标准列
- [ ] 所有 API 响应格式符合 uctoo-v4 规范
- [ ] 前端 ARIA 语义角色正确（tab/grid/gridcell）
- [ ] 密码安全：任何页面/错误消息/恢复流程不显示完整密码
- [ ] 登录失败统一返回 "Invalid credentials"
- [ ] 登出/改密/恢复后立即改变会话状态

### 复用验收
- [ ] 用户/权限/数据库/智能体/aibuilder 基础设施未被重写
- [ ] 组织管理复用 company 表，未新建组织表
- [ ] Issue 基础信息复用 tasks 表，未新建 issue 表
- [ ] 团队管理复用 user_group 表
- [ ] 菜单路由通过 permissions 表动态加载，未硬编码

### 工程验收
- [ ] DDL 文件已放入 sql/incremental/ 目录
- [ ] db_info 表已刷新（loaddbinfo）
- [ ] 后端五层模块齐全（PO/DAO/Service/Controller/Route）
- [ ] 前端 store 模型与后端 PO 一一对应
- [ ] 种子数据完整且跨会话一致
- [ ] spec / design / tasks 三份文档与实现一致（无漂移）
- [ ] 仓颉代码通过编译（人工确认）
- [ ] 前端构建无错误

---

## 修订记录 / 多轮迭代

| 日期 | 轮次 | 触发来源 | 改动文件清单 | 验证结果 |
|------|------|----------|-------------|----------|
| 2026-10-01 | v1.0 | 初始创建 | tasks.md（初版） | 待验证 |
| 2026-10-03 | v1.0.1 | SDD v1.2.0 铁律 14/15 对齐 | tasks.md（开发规范置顶二次开发底座优先、T-07/T-08/T-09 改 plugingen 插件优先、生成后补 RBAC 授权、铁律 15 拆分评估） | 待验证 |

---

> **文档版本**：1.0.1
> **创建日期**：2026-10-01
> **最近修订**：2026-10-03 按 SDD v1.2.0 铁律 14 对齐工具链（开发规范段置顶二次开发底座优先、T-07/T-08/T-09 改 plugingen 插件优先、生成后补 RBAC 授权）+ 铁律 15 拆分评估说明
> **赛题来源**：`arcbench-hackathon-requirements/hackathon--github/requirements.yaml`（47 个原子需求）、`arcbench-hackathon-requirements/hackathon--sheet/requirements.yaml`（24 个原子需求）
> **总任务数**：34 个任务（28 P0 + 6 P1），分布在 8 个阶段
