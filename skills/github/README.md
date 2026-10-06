# github 插件（L3 进程隔离轨）

独立 cjpm executable 工程，对标 DeepSeek Harness Cordis 的进程隔离插件轨。

<!-- #region AutoCreateCode -->
## 覆盖表（10 张）

分多次生成时表清单自动累积合并：

- `issue_comment`
- `milestone`
- `label`
- `pull_request`
- `pr_review`
- `branch_protection`
- `repository`
- `branch`
- `commit`
- `repository_file`

## V4 API 端点

每张表 6 条路由，basePath 为 `/api/v1/uctoo/{表名}`：

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /api/v1/uctoo/issue_comment/:limit/:page | issue_comment 分页列表 |
| GET | /api/v1/uctoo/issue_comment/:id | issue_comment 单条查询 |
| POST | /api/v1/uctoo/issue_comment/add | issue_comment 创建 |
| POST | /api/v1/uctoo/issue_comment/edit | issue_comment 更新（含批量/恢复） |
| POST | /api/v1/uctoo/issue_comment/del | issue_comment 删除（含批量/硬删） |
| POST | /api/v1/uctoo/issue_comment/empty-recycle-bin | issue_comment 清空回收站 |
| GET | /api/v1/uctoo/milestone/:limit/:page | milestone 分页列表 |
| GET | /api/v1/uctoo/milestone/:id | milestone 单条查询 |
| POST | /api/v1/uctoo/milestone/add | milestone 创建 |
| POST | /api/v1/uctoo/milestone/edit | milestone 更新（含批量/恢复） |
| POST | /api/v1/uctoo/milestone/del | milestone 删除（含批量/硬删） |
| POST | /api/v1/uctoo/milestone/empty-recycle-bin | milestone 清空回收站 |
| GET | /api/v1/uctoo/label/:limit/:page | label 分页列表 |
| GET | /api/v1/uctoo/label/:id | label 单条查询 |
| POST | /api/v1/uctoo/label/add | label 创建 |
| POST | /api/v1/uctoo/label/edit | label 更新（含批量/恢复） |
| POST | /api/v1/uctoo/label/del | label 删除（含批量/硬删） |
| POST | /api/v1/uctoo/label/empty-recycle-bin | label 清空回收站 |
| GET | /api/v1/uctoo/pull_request/:limit/:page | pull_request 分页列表 |
| GET | /api/v1/uctoo/pull_request/:id | pull_request 单条查询 |
| POST | /api/v1/uctoo/pull_request/add | pull_request 创建 |
| POST | /api/v1/uctoo/pull_request/edit | pull_request 更新（含批量/恢复） |
| POST | /api/v1/uctoo/pull_request/del | pull_request 删除（含批量/硬删） |
| POST | /api/v1/uctoo/pull_request/empty-recycle-bin | pull_request 清空回收站 |
| GET | /api/v1/uctoo/pr_review/:limit/:page | pr_review 分页列表 |
| GET | /api/v1/uctoo/pr_review/:id | pr_review 单条查询 |
| POST | /api/v1/uctoo/pr_review/add | pr_review 创建 |
| POST | /api/v1/uctoo/pr_review/edit | pr_review 更新（含批量/恢复） |
| POST | /api/v1/uctoo/pr_review/del | pr_review 删除（含批量/硬删） |
| POST | /api/v1/uctoo/pr_review/empty-recycle-bin | pr_review 清空回收站 |
| GET | /api/v1/uctoo/branch_protection/:limit/:page | branch_protection 分页列表 |
| GET | /api/v1/uctoo/branch_protection/:id | branch_protection 单条查询 |
| POST | /api/v1/uctoo/branch_protection/add | branch_protection 创建 |
| POST | /api/v1/uctoo/branch_protection/edit | branch_protection 更新（含批量/恢复） |
| POST | /api/v1/uctoo/branch_protection/del | branch_protection 删除（含批量/硬删） |
| POST | /api/v1/uctoo/branch_protection/empty-recycle-bin | branch_protection 清空回收站 |
| GET | /api/v1/uctoo/repository/:limit/:page | repository 分页列表 |
| GET | /api/v1/uctoo/repository/:id | repository 单条查询 |
| POST | /api/v1/uctoo/repository/add | repository 创建 |
| POST | /api/v1/uctoo/repository/edit | repository 更新（含批量/恢复） |
| POST | /api/v1/uctoo/repository/del | repository 删除（含批量/硬删） |
| POST | /api/v1/uctoo/repository/empty-recycle-bin | repository 清空回收站 |
| GET | /api/v1/uctoo/branch/:limit/:page | branch 分页列表 |
| GET | /api/v1/uctoo/branch/:id | branch 单条查询 |
| POST | /api/v1/uctoo/branch/add | branch 创建 |
| POST | /api/v1/uctoo/branch/edit | branch 更新（含批量/恢复） |
| POST | /api/v1/uctoo/branch/del | branch 删除（含批量/硬删） |
| POST | /api/v1/uctoo/branch/empty-recycle-bin | branch 清空回收站 |
| GET | /api/v1/uctoo/commit/:limit/:page | commit 分页列表 |
| GET | /api/v1/uctoo/commit/:id | commit 单条查询 |
| POST | /api/v1/uctoo/commit/add | commit 创建 |
| POST | /api/v1/uctoo/commit/edit | commit 更新（含批量/恢复） |
| POST | /api/v1/uctoo/commit/del | commit 删除（含批量/硬删） |
| POST | /api/v1/uctoo/commit/empty-recycle-bin | commit 清空回收站 |
| GET | /api/v1/uctoo/repository_file/:limit/:page | repository_file 分页列表 |
| GET | /api/v1/uctoo/repository_file/:id | repository_file 单条查询 |
| POST | /api/v1/uctoo/repository_file/add | repository_file 创建 |
| POST | /api/v1/uctoo/repository_file/edit | repository_file 更新（含批量/恢复） |
| POST | /api/v1/uctoo/repository_file/del | repository_file 删除（含批量/硬删） |
| POST | /api/v1/uctoo/repository_file/empty-recycle-bin | repository_file 清空回收站 |
<!-- #endregion AutoCreateCode -->

## 编译

```bash
cd ./skills/github
cjpm build
```

产物：`target/release/bin/skill_github.exe`

## 约束

- 依赖仅 `ystyle::cordis_plugin` + `jsonvalue`（+仓颉标准库）——零 magic 包依赖
- 禁用 `@Plugin` 宏：用显式 API `PluginRuntime.run(...)`
- 数据访问一律经 `host.db` 服务代理（不直连数据库）
- `getWritableColumns(table)` 按表返回可写列白名单，**需按各表实际字段补全**

## 保护区约定（重新生成时勿丢二开）

本插件由 plugingen 生成，以下文件的自动区块会在重新生成时被覆盖，
**手写代码必须写在区块之外**。各文件的区块起止标记用其语言对应的注释语法：

| 文件 | 区块标记前缀 | 二开位置 |
|---|---|---|
| `handlers.cj` | Cangjie 行注释 + region AutoCreateCode | 结束标记之后（类外顶层函数区） |
| `main.cj` | Cangjie 行注释 + region AutoCreateCode | 结束标记之后 |
| `effects.cj` | Cangjie 行注释 + region AutoCreateCode | 结束标记之后（类外另起 class） |
| `plugin.yaml` | YAML 行注释 + region AutoCreateCode | `enabled` / `order` / `command` 在区块外 |
| `cjpm.toml` | TOML 行注释 + region AutoCreateCode | `[package]` 段（`compile-option` 等在区块外） |
| `README.md` | HTML 注释包裹的 region AutoCreateCode | 区块之外（本节即在区块外） |

> 标记语法随文件类型不同：仓颉源码用 `//`，YAML/TOML 用 `#`，
> Markdown 用 HTML 注释 —— 因为行首 `#` 在 Markdown 里是标题语法。
> 完整标记串见对应文件的开头与结束标记行。
