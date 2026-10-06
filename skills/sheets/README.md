# sheets 插件（L3 进程隔离轨）

独立 cjpm executable 工程，对标 DeepSeek Harness Cordis 的进程隔离插件轨。

<!-- #region AutoCreateCode -->
## 覆盖表（5 张）

分多次生成时表清单自动累积合并：

- `workbook`
- `worksheet`
- `cell`
- `validation_rule`
- `pivot_table`

## V4 API 端点

每张表 6 条路由，basePath 为 `/api/v1/uctoo/{表名}`：

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /api/v1/uctoo/workbook/:limit/:page | workbook 分页列表 |
| GET | /api/v1/uctoo/workbook/:id | workbook 单条查询 |
| POST | /api/v1/uctoo/workbook/add | workbook 创建 |
| POST | /api/v1/uctoo/workbook/edit | workbook 更新（含批量/恢复） |
| POST | /api/v1/uctoo/workbook/del | workbook 删除（含批量/硬删） |
| POST | /api/v1/uctoo/workbook/empty-recycle-bin | workbook 清空回收站 |
| GET | /api/v1/uctoo/worksheet/:limit/:page | worksheet 分页列表 |
| GET | /api/v1/uctoo/worksheet/:id | worksheet 单条查询 |
| POST | /api/v1/uctoo/worksheet/add | worksheet 创建 |
| POST | /api/v1/uctoo/worksheet/edit | worksheet 更新（含批量/恢复） |
| POST | /api/v1/uctoo/worksheet/del | worksheet 删除（含批量/硬删） |
| POST | /api/v1/uctoo/worksheet/empty-recycle-bin | worksheet 清空回收站 |
| GET | /api/v1/uctoo/cell/:limit/:page | cell 分页列表 |
| GET | /api/v1/uctoo/cell/:id | cell 单条查询 |
| POST | /api/v1/uctoo/cell/add | cell 创建 |
| POST | /api/v1/uctoo/cell/edit | cell 更新（含批量/恢复） |
| POST | /api/v1/uctoo/cell/del | cell 删除（含批量/硬删） |
| POST | /api/v1/uctoo/cell/empty-recycle-bin | cell 清空回收站 |
| GET | /api/v1/uctoo/validation_rule/:limit/:page | validation_rule 分页列表 |
| GET | /api/v1/uctoo/validation_rule/:id | validation_rule 单条查询 |
| POST | /api/v1/uctoo/validation_rule/add | validation_rule 创建 |
| POST | /api/v1/uctoo/validation_rule/edit | validation_rule 更新（含批量/恢复） |
| POST | /api/v1/uctoo/validation_rule/del | validation_rule 删除（含批量/硬删） |
| POST | /api/v1/uctoo/validation_rule/empty-recycle-bin | validation_rule 清空回收站 |
| GET | /api/v1/uctoo/pivot_table/:limit/:page | pivot_table 分页列表 |
| GET | /api/v1/uctoo/pivot_table/:id | pivot_table 单条查询 |
| POST | /api/v1/uctoo/pivot_table/add | pivot_table 创建 |
| POST | /api/v1/uctoo/pivot_table/edit | pivot_table 更新（含批量/恢复） |
| POST | /api/v1/uctoo/pivot_table/del | pivot_table 删除（含批量/硬删） |
| POST | /api/v1/uctoo/pivot_table/empty-recycle-bin | pivot_table 清空回收站 |
<!-- #endregion AutoCreateCode -->

## 编译

```bash
cd ./skills/sheets
cjpm build
```

产物：`target/release/bin/skill_sheets.exe`

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
