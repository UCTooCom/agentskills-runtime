# crudweb 使用手册

## 概述

`crudweb` 是 agentskills-runtime 的 Web CRUD 代码生成器，从 `db_info` 读表结构，生成 Web 管理界面 CRUD 代码（Vue 组件）。

**源码位置**：`src/app/tools/crudweb/crudweb.cj`、`src/app/tools/crudweb/WebCrudGenerator.cj`

## 用法

```bash
cjpm run --skip-build --name magic.app.tools.crudweb --run-args "--db <数据库名> --table <表名> [--all] [--output <输出目录>]"
```

## 选项

| 选项 | 说明 |
|------|------|
| `--db <数据库名>` | 指定数据库名 |
| `--table <表名>` | 指定表名 |
| `--all` | 生成数据库中所有表的 Web CRUD 代码 |
| `--output <输出目录>` | 指定输出目录（默认 `web/src/views/database/uctoo/`） |
| `--help, -h` | 显示帮助信息 |

> ⚠️ **默认输出目录实际由环境变量决定，不是 `--output`**。crudweb 启动会打印一行
> `=== Using output directory from environment: <dir> ===`（该环境变量配在 runtime 的 `.env`）。
> 实测本机解析为 `D:\...\uctoo-admin\apps\web-admin`，Vue 产物落
> `apps/web-admin/web/src/views/database/uctoo/{table}/`，store model 落
> `apps/web-admin/web/src/store/models/uctoo/{table}.ts`。
> **别按本表「默认 `web/src/views/database/uctoo/`」去仓库根找** —— 这是 monorepo，
> 根层没有 `views/database`，容易岔到 `apps/miniapp*`、`apps/backend/prisma/uctoo` 等无关目录。
> 找不到时先跑一次单表看那行 `Using output directory` 打印。

## 示例

```bash
# 生成指定表的 Web CRUD 代码
cjpm run --skip-build --name magic.app.tools.crudweb --run-args "--db uctoo --table entity"
# 生成数据库中所有表的 Web CRUD 代码
cjpm run --skip-build --name magic.app.tools.crudweb --run-args "--db uctoo --all"
```

## 生成产物

crudweb 为每张表生成 Vue 管理界面组件：

| 文件 | 职责 |
|------|------|
| `index.vue` | 列表页主入口 |
| `components/{name}-table.vue` | 数据表格组件（含列表/回收站/分页/筛选） |
| `components/add-{name}.vue` | 新增表单组件 |
| `components/edit-form.vue` | 编辑表单组件 |

另外每表生成一个 pinia-orm store model `web/src/store/models/uctoo/{table}.ts`，
并**自动向同目录 `index.ts` 追加** `export * from './{table}';`（已存在则跳过，可重复执行）。

### 命名规则（按原表名拼文件名会以为产物缺失）

组件文件里的 `{name}` 是**下划线转连字符**后的表名，目录名与 store model 仍保留下划线：

| 表名 | 组件文件 |
|---|---|
| `repository` | `add-repository.vue` / `repository-table.vue` |
| `pivot_table` | `add-pivot-table.vue` / `pivot-table-table.vue` |

### ⚠️ Vue 产物没有保护区（2026-10-14 说明：web 侧难以界定保护区）

与 crudgen / plugingen 的 `AutoCreateCode` 口径**不同**：只有 store model 带
`//#region Human-Code Preservation` 保护区，**四个 Vue 文件全都不带**，
对同一张表重复执行 `crudweb --table <t>` 会把前端二开改动整文件冲掉。

**为什么 web 侧不定保护区**：web 组件由模板 + 数据绑定 + 事件拼装，人工二开往往散落在 `<template>` / `<script setup>` / 样式多处，难以像后端那样用一行边界框定"机器区 / 人类区"，强行加保护区反而割裂生成逻辑、得不偿失。

**推荐的 web 二次开发方式（而非在标准 crudweb 生成页上二开）**：
1. 把 `crudweb` 生成的**标准数据表格页**（如 `src/views/database/uctoo/<表>/`）当作基线，**整份复制**成一份新的二次开发页面（新路由 / 新目录，例如 `src/views/<业务>/<表>-ext/`）；
2. 在新的二开页上做定制修改（增删字段、改交互、接业务），标准页保持"随时可被 `crudweb` 重生成"的干净状态；
3. 给新二开页在 **`permissions` 表登记权限节点**（并在 `role_has_permission` 授权，否则 403），菜单入口走 `getUserMenuTree` 暴露。

> 注：若仅是**给既有表加字段**（如 `agents.profile_skills` 这类 schema 扩展），属于基线 CRUD 范畴，直接补在标准生成页上即可，不必另起二开页。

## 前置条件

1. 已执行 `cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args "--db <数据库名>"` 加载表结构到 `db_info` 表
2. `.env` 文件已配置 `orm_*` 数据源

## 与 crudgen 的关系

- **crudgen**：生成宿主后端 CRUD 模块（仓颉代码，五层架构）
- **crudweb**：生成前端管理界面（Vue 组件，数据表格/表单）

两者配合使用：crudgen 生成后端 API，crudweb 生成前端界面调用这些 API。

---

## 后续规划 / TODO：crudweb 一并生成「agent 操作页面的说明」，让页面原生智能化

### 背景与设计动机

`views/database/uctoo/*` 下的所有页面（entity、crontab、codelabs …）都由 crudweb 从数据库结构**确定性同构生成**，结构完全一致：顶部工具栏（新增/批量删除/导出 + 回收站开关）、筛选区（添加筛选条件 / 字段下拉 / 运算符 / 值 / 搜索 / 重置）、数据表格（多选 + 行内操作 编辑/查看/删除，回收站视图下 恢复/彻底删除）、分页器、新增对话框、编辑/查看模态框。

既然结构同构，agent 操作它们的「人类式交互流程」也完全通用：**导航到页面 → `page-agent-tool` 读界面(browserState) → 定位并 click 按钮 / fill 表单 / select 下拉 / 翻页 → 二次确认**。当前这份「像真实用户一样操作界面」的指引是**手写在 `web/src/skills/crontab-operator/SKILL.md`** 里的（规避了 `registerPageTool` 业务句柄「直连后端、非人类行为」的坑）。每新增一张表都要手写一篇，既不经济也易漂移。

### TODO 目标

拓展 crudweb：在生成 Vue 组件的同时，**一并生成该页面的 agent 操作说明（SKILL.md）**，使每个 crudweb 生成的页面开箱即「原生智能」——agent 无需单独手写的指导文档即可像人一样操作。

### 建议落地内容（供实现时参考）

1. **生成物**：在 `web/src/skills/{table}-operator/SKILL.md`（或统一的 `web/src/skills/database-crud-operator/` 共享一份、按表名参数化）产出与 crontab-operator 同构的操作指引，内容自动从 `db_info` 字段推导：
   - 页面路由（`/database/uctoo/{table}`，来自 `permissions` 菜单链，不硬编码）；
   - 筛选区可选字段与运算符清单（来自 `db_info` 列定义）；
   - 新增/编辑表单字段清单与必填项（来自 `db_info` 列 + 非空约束）；
   - 「人类式操作配方」模板：导航 → browserState → click/fill/select → 确认，覆盖 查询/新增/编辑/删除/恢复/回收站/翻页 七类操作；
   - **明确禁令**：不得使用页面 `registerPageTool` 业务句柄（直连后端，非人类行为）。
2. **配套放开写动作白名单（已实现集中式放行）**：`web/src/webmcp/pagetool-init.ts` 已通过官方 `window.__webmcpcli_beforeGetBrowserState` 钩子，在 pathname 含 `/database/uctoo/`（即所有 crudweb 生成的数据库表页，含 crontab）时显式放开写动作——`fill` / `select` / `click` / `scroll` / `hover` 在当前 next-sdk 版本本就由 handler 无条件执行，钩子额外将 `enableExecuteJavascript` 置 `true`，使 agent 可像真实用户一样点按钮、填表单、选下拉。AI 对话界面仍被黑名单排除。
   - **剩余工作**：本放行是按「路由前缀 `/database/uctoo/`」集中式覆盖的。若未来需要**更细粒度**（如仅对特定表、或仅对新增表单对话框容器放开 executeJavascript），可由 crudweb 在生成页面时**一并注入对应的 `a11yConfig` / 路由标记**，但当前集中式方案对「agent 像人操作所有 crudweb 表」已足够，无需每表单独配置。
3. **与 crudgen 协同**：crudgen 已有 `db_info` 读取逻辑，可复用字段元数据，避免重复解析。
4. **避免重复造轮子**：手写版 `crontab-operator` 作为「黄金样例」与回归基准，crudweb 生成器产出后应与之结构对齐（人类对齐哲学、导航护栏、禁用 registerPageTool 捷径三者一致）。

### 验收口径

- 对任意 `uctoo` 库的新表执行 `crudweb --table <t>`，除 Vue 组件外还产出 `<t>-operator/SKILL.md`，且内容可被 agent 直接用于「像人一样操作该表页」；
- 该说明明确禁止调用 `<t>` 页的 `registerPageTool` 业务句柄；
- 对应页面的 `pagetool-init` 写动作白名单已放开，agent 实际能完成一次「点新增 → 填表单 → 确认」的端到端操作。
