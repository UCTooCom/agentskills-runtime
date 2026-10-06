---
name: sheets
description: >
  电子表格工作台插件（AgenticSoftwareFactoryHackathon 参赛成果）。
  提供 uctoo 库 workbook / worksheet / cell / validation_rule / pivot_table
  五张表的标准 CRUD 能力：新增、编辑、软删/硬删、恢复、分页列表
  （Prisma 风格 filter/sort）。触发场景：工作簿/工作表/单元格数据管理请求、
  sheets 插件能力发现。
license: MIT
plugin: sheets
---

# sheets 插件（电子表格工作台）

本插件是 AgenticSoftwareFactoryHackathon 黑客松参赛作品「电子表格工作台」（对齐
Google Sheets 风格赛题 REQ-1 ~ REQ-6）的后端实现，由 plugingen 以 L3 进程隔离轨
（process）生成，三维一体提供 Service + Skill + Route，覆盖 `uctoo` 库以下表的标准
CRUD 能力：

- `workbook` — 工作簿（名称 / 最后更新时间 / 所有者）
- `worksheet` — 工作表（关联工作簿，名称 / 位置 / ARIA tab 角色）
- `cell` — 单元格（关联工作表，坐标如 A1 / 值 / 公式）
- `validation_rule` — 数据验证规则（关联工作表 / 区域）
- `pivot_table` — 透视表配置（关联工作表 / 源区域）

## 能力说明

- 每张表均支持 新增 / 编辑 / 删除（软删 + 硬删）/ 恢复
- 分页列表（Prisma 风格 filter/sort 查询参数）
- 按创建者过滤与计数
- 增量 DDL：`sql/incremental/hackathon_sheets_workbook.sql`

## 使用方式

1. **服务调用（确定性通道）**：宿主经
   `ServiceRegistry.getService<WorkbookService>()` 类型安全轨获取服务
   （其余表服务类名类同：`WorksheetService` / `CellService` /
   `ValidationRuleService` / `PivotTableService`）。
2. **HTTP 调用（插件路由通道）**：路由前缀 `/api/v1/uctoo/<table>`，按表归类：
   - `POST /api/v1/uctoo/<table>/add`
   - `POST /api/v1/uctoo/<table>/edit`
   - `POST /api/v1/uctoo/<table>/del`
   - `POST /api/v1/uctoo/<table>/empty-recycle-bin`
   - `GET  /api/v1/uctoo/<table>/:id`
   - `GET  /api/v1/uctoo/<table>/:limit/:page?sort=&filter=`
   其中 `<table>` ∈ { workbook, worksheet, cell, validation_rule, pivot_table }。
3. **智能体调用（技能轨）**：智能体可通过本 SKILL.md 发现插件能力，经宿主
   WebMCP / agent_skills 体系以工具形式调用上述 HTTP 路由完成工作簿与单元格
   数据操作。

## 管理界面（web-admin/web）

在 `apps/web-admin/web` 前端（Vue 3 + pinia-orm + OpenTiny）中，本插件五张表的
可视化管理界面由 crudweb 生成，菜单位置：**数据库管理 → uctoo 库**，页面路径
`src/views/database/uctoo/<table>/index.vue`：

| 表 | 管理页面路由/目录 |
|----|------------------|
| workbook | `views/database/uctoo/workbook`（工作簿列表，支持新增/编辑/删除/恢复） |
| worksheet | `views/database/uctoo/worksheet` |
| cell | `views/database/uctoo/cell` |
| validation_rule | `views/database/uctoo/validation_rule` |
| pivot_table | `views/database/uctoo/pivot_table` |

使用方式：登录 web-admin 后进入「数据库管理」菜单，选择对应表页面，即可分页浏览
数据、按条件筛选、新增/编辑记录、软删除与从回收站恢复；页面数据经由上表 HTTP 路由
读写后端。

## 约束

- 遵循 uctoo-v4 API 规范：成功直接返回数据对象，错误返回 `{ errno, errmsg }`。
- 列表响应格式 `{ currentPage, totalCount, totalPage, <table>s }`。
- 插件停用后 HTTP 路由降级为 503（路由注册不删除），服务注销后类型安全轨取值为 None。
- 公式计算（SUM/AVERAGE/IF 等聚合与依赖重算）属赛题上层能力，本插件提供单元格
  公式存储（`cell.formula`），计算引擎见黑客松工程文档
  `.codeartsdoer/specs/AgenticSoftwareFactoryHackathon/spec.md` 5.10 节。
