---
name: github
description: >
  GitHub 风格软件工程协作平台插件（AgenticSoftwareFactoryHackathon 参赛成果）。
  提供 uctoo 库 repository / branch / commit / repository_file / issue_comment /
  milestone / label / pull_request / pr_review / branch_protection 十张表的标准
  CRUD 能力：新增、编辑、软删/硬删、恢复、分页列表（Prisma 风格 filter/sort）。
  触发场景：仓库/分支/提交/Issue 评论/PR 等协作数据管理请求、github 插件能力发现。
license: MIT
plugin: github
---

# github 插件（GitHub 风格协作平台）

本插件是 AgenticSoftwareFactoryHackathon 黑客松参赛作品「GitHub 风格软件工程协作
平台」（对齐赛题 REQ-1 ~ REQ-6）的后端实现，由 plugingen 以 L3 进程隔离轨
（process）生成，三维一体提供 Service + Skill + Route，覆盖 `uctoo` 库以下表的
标准 CRUD 能力：

- `repository` — 仓库（owner 复用 `uctoo_user` / `company`，可见性 / 默认分支 / 描述）
- `branch` — 分支（关联仓库，是否默认 / 保护规则）
- `commit` — 提交（author 复用 `uctoo_user`，哈希 / 差异 / 验证标识）
- `repository_file` — 文件树节点（关联仓库 / 分支，支持在线编辑）
- `issue_comment` — Issue 评论（commenter 复用 `uctoo_user`）
- `milestone` — 里程碑（关联仓库，跟踪 Issue / PR 进度）
- `label` — 标签（关联仓库）
- `pull_request` — PR（关联仓库 / 分支，base / compare 分支 / 评审 / 合并状态）
- `pr_review` — PR 评审评论（reviewer 复用 `uctoo_user`）
- `branch_protection` — 分支保护规则（关联分支）

## 能力说明

- 每张表均支持 新增 / 编辑 / 删除（软删 + 硬删）/ 恢复
- 分页列表（Prisma 风格 filter/sort 查询参数）
- 按创建者过滤与计数
- 增量 DDL：`sql/incremental/hackathon_github_repository.sql`、
  `sql/incremental/hackathon_github_issue_pr.sql`

## 使用方式

1. **服务调用（确定性通道）**：宿主经
   `ServiceRegistry.getService<RepositoryService>()` 类型安全轨获取服务
   （其余表服务类名类同：`BranchService` / `CommitService` /
   `RepositoryFileService` / `IssueCommentService` / `MilestoneService` /
   `LabelService` / `PullRequestService` / `PrReviewService` /
   `BranchProtectionService`）。
2. **HTTP 调用（插件路由通道）**：路由前缀 `/api/v1/uctoo/<table>`，按表归类：
   - `POST /api/v1/uctoo/<table>/add`
   - `POST /api/v1/uctoo/<table>/edit`
   - `POST /api/v1/uctoo/<table>/del`
   - `POST /api/v1/uctoo/<table>/empty-recycle-bin`
   - `GET  /api/v1/uctoo/<table>/:id`
   - `GET  /api/v1/uctoo/<table>/:limit/:page?sort=&filter=`
   其中 `<table>` ∈ { repository, branch, commit, repository_file,
   issue_comment, milestone, label, pull_request, pr_review, branch_protection }。
3. **智能体调用（技能轨）**：智能体可通过本 SKILL.md 发现插件能力，经宿主
   WebMCP / agent_skills 体系以工具形式调用上述 HTTP 路由完成仓库、分支、提交、
   Issue / PR 等协作数据操作，支撑「需求编译器 → 模块委派器 → 全流程验证」的
   智能体软件工厂工作流。

## 管理界面（web-admin/web）

在 `apps/web-admin/web` 前端（Vue 3 + pinia-orm + OpenTiny）中，本插件十张表的
可视化管理界面由 crudweb 生成，菜单位置：**数据库管理 → uctoo 库**，页面路径
`src/views/database/uctoo/<table>/index.vue`：

| 表 | 管理页面目录 |
|----|-------------|
| repository | `views/database/uctoo/repository`（仓库列表，支持新增/编辑/删除/恢复） |
| branch | `views/database/uctoo/branch` |
| commit | `views/database/uctoo/commit` |
| repository_file | `views/database/uctoo/repository_file` |
| issue_comment | `views/database/uctoo/issue_comment` |
| milestone | `views/database/uctoo/milestone` |
| label | `views/database/uctoo/label` |
| pull_request | `views/database/uctoo/pull_request` |
| pr_review | `views/database/uctoo/pr_review` |
| branch_protection | `views/database/uctoo/branch_protection` |

使用方式：登录 web-admin 后进入「数据库管理」菜单，选择对应表页面，即可分页浏览
数据、按条件筛选、新增/编辑记录、软删除与从回收站恢复；页面数据经由上表 HTTP 路由
读写后端。

## 约束

- 遵循 uctoo-v4 API 规范：成功直接返回数据对象，错误返回 `{ errno, errmsg }`。
- 列表响应格式 `{ currentPage, totalCount, totalPage, <table>s }`。
- 插件停用后 HTTP 路由降级为 503（路由注册不删除），服务注销后类型安全轨取值为 None。
- 组织（Organization）复用 aibuilder 模块 `company` 表、Issue 载体复用 `tasks`
  表，本插件不重复建表；仓库可见性行级权限复用 `data_access_authorization`。
