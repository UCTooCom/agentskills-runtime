### 2.2.3 种子数据设计

> DDL 放置于 `sql/incremental/hackathon_seed_data.sql`，预置赛题要求的隔离浏览器会话种子数据。

种子数据覆盖以下实体（均为预定义 UUID，保证跨会话一致）：

| 实体 | 数量 | 关键字段 |
|------|------|----------|
| 账户（uctoo_user） | 5+ | username/email/password（合规密码）/email_verified=true/status=available |
| 组织（company） | 2+ | company_name/org_type='github-org'/member_count |
| 仓库（repository） | 5+ | name/visibility=public/private/default_branch=main |
| 分支（branch） | 8+ | name/repository_id/is_default |
| 提交（commit） | 10+ | hash/message/author_id/verified |
| 文件（repository_file） | 15+ | path/content/branch_id |
| Issue（tasks, task_type='issue'） | 8+ | title/description/task_status/priority |
| PR（pull_request） | 4+ | title/status/base_branch/compare_branch |
| 工作簿（workbook） | 3+ | name/owner_id/last_updated |
| 工作表（worksheet） | 5+ | name/workbook_id/position |
| 单元格（cell） | 50+ | coordinate/value/formula |

### 2.2.4 菜单权限数据设计

> DDL 放置于 `sql/incremental/hackathon_permissions_menu.sql`，通过插入 `permissions` 表注册前端动态路由。
