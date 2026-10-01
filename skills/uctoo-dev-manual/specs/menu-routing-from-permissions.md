# 菜单与动态路由机制：权限表即路由表

> 适用场景：理解 web 管理后台的页面路由地址从何而来、为什么不能靠猜 URL、agent 操作 web 时导航目标应如何正确取得。
> 关联：`webmcp-agent-web-operation` 规格（agent 操作 web 应用）、`user-permission-system`（RBAC 三层体系）。

## 1. 核心结论（先说人话）

web 管理后台（web-admin）**没有任何一个页面路由地址是硬编码在源码里的**。左侧菜单、每个页面的访问地址，全部在运行时由前端向 runtime 的菜单接口拉取，runtime 再从 `permissions` 表里读出来，组装成树返回。

也就是说：

- 页面"叫什么、挂在哪、路径是什么、对应哪个 Vue 组件"——这些全部由 `permissions` 表的一行行记录决定。
- 你（或 agent）看到的 URL，比如 `http://localhost:3031/vue-pro/database/uctoo/entity`，其中的 `database/uctoo/entity` 这一段，是 `permissions` 表里顺着 `parent_id` 父子链一层层拼出来的；前面的 `/vue-pro/` 是 Vite 构建的 `base`（环境变量 `VITE_CONTEXT`），与业务无关。

**这直接解释了早期一个 bug**：最初实现"导航到 entity 表页面"时，AI 凭印象写了错误的 URL（先写成 `/uctoo/entity`，又写成 `/database/uctoo/entity` 但漏了 `/vue-pro` 前缀）。根因就是**没有去 `permissions` 表 / 菜单接口取真值，而是猜**。正确做法见第 6 节。

## 2. 数据来源：`permissions` 表

建表语句（节选自 `sql/public20260924.sql`）：

```sql
CREATE TABLE "public"."permissions" (
  "id"             uuid         NOT NULL DEFAULT gen_random_uuid(),
  "permission_name" varchar      NOT NULL,          -- 权限/菜单唯一名，如 'database.uctoo.entity'
  "level"          varchar,                         -- 层级标识（可选）
  "icon"           varchar,                         -- 菜单图标名
  "module"         varchar,                         -- 所属模块
  "component"      varchar,                         -- Vue 组件路径（相对 src/views/），如 'database/uctoo/entity/index'
  "redirect"       varchar,                         -- 重定向（可选）
  "type"           int4         NOT NULL DEFAULT 1, -- 1=菜单 2=按钮/操作 3=API 路由权限节点
  "hidden"         int4         NOT NULL DEFAULT 1, -- 1=在菜单中隐藏（API 节点恒为 1）
  "weight"         int4         NOT NULL DEFAULT 0, -- 排序权重
  "creator"        uuid,                            -- 创建者（行级权限用）
  "created_at"     timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"     timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at"     timestamptz(6),                  -- 软删除
  "keepalive"      int4         NOT NULL DEFAULT 1, -- 路由缓存
  "path"           varchar,                         -- ★ 本节点相对路径（不是完整路由！）
  "title"          varchar,                         -- 菜单显示名
  "parent_id"      uuid,                            -- ★ 父菜单 id，构成树结构（根节点为 NULL 或空串）
  "meta"           jsonb,                           -- 扩展元信息
  "method"         varchar,                         -- API 节点用：HTTP 方法（GET/POST/.../ANY）
  "menu_type"      varchar      DEFAULT 'normal',    -- 菜单类型
  "locale"         varchar      DEFAULT ''          -- i18n key，如 'menu.database.uctoo.entity'
);
```

### 2.1 字段要点

| 字段 | 含义 | 对路由的作用 |
|------|------|--------------|
| `permission_name` | 权限/菜单唯一标识 | 同时是 vue-router 的 `route.name` |
| `path` | **当前节点自身的相对路径片段** | 完整路由 = 父链 `path` 依次拼接 + 本节点 `path` |
| `component` | Vue 视图路径（相对 `src/views/`） | `views[`../../views/${component}.vue`]` 动态加载 |
| `parent_id` | 父菜单 id | 决定树结构与完整路径前缀 |
| `type` | 1 菜单 / 2 按钮 / 3 API 路由权限 | 菜单树只取 `type=1`；`type=3` 是 `loadRouteFromApp` 自动同步的 API 权限节点（恒 `hidden=1`） |
| `title` / `locale` | 显示名 / i18n key | 侧边栏文案 |
| `weight` | 排序 | 同层菜单顺序 |
| `hidden` | 是否隐藏 | `1`=侧边栏不显示（多用于 API 节点） |

> **最关键的认知**：`path` 不等于完整 URL。一个叶子菜单的 `path` 往往只是最后一段（如 `'entity'`），前面还有多层父级路径，必须沿 `parent_id` 向上回溯拼接。

## 3. runtime 菜单接口

实现位置：`src/app/controllers/uctoo/permissions/PermissionsController.cj`，服务层 `PermissionsService`。

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/v1/uctoo/permissions/user/menu` | **POST** | 取**当前用户**可见菜单树（按角色→权限过滤，仅 `type=1`） |
| `/api/v1/uctoo/permissions/menu/all` | GET | 取全部菜单树（含隐藏，超管用） |
| `/api/v1/uctoo/permissions/role/menu` | POST | 按角色 id 取菜单树（body `{id}`） |
| `/api/v1/uctoo/permissions/user/all` | POST | 取当前用户全部权限（不区分类型） |
| `/api/v1/uctoo/permissions/loadRouteFromApp` | POST | 把 runtime 已注册路由同步成 `type=3` 权限节点（增量更新） |

### 3.1 前端实际调用的接口

web 端 `store/models/uctoo/user_menu.ts` 中：

```ts
getUserMenuTree(userId?: string) {
  const body = userId ? { id: userId } : {}
  return useAxiosRepo(user_menu).api().post(
    '/api/v1/uctoo/permissions/user/menu', body,
    { baseURL: getRuntimeApiURL(), /* runtime 主机，如 localhost:port 或 javatoarktsapi.uctoo.com */
      headers: { 'Authorization': `Bearer ${localStorage.getItem('accessToken')}` },
      dataKey: 'data' })
}
```

返回结构（节选，`errno='0'` 成功）：

```json
{
  "errno": "0", "errmsg": "success",
  "data": [
    {
      "id": "…0033", "permission_name": "database", "path": "database",
      "component": "…", "icon": "…", "menu_type": "normal",
      "parent_id": null, "weight": 1, "type": 1, "hidden": 1,
      "title": "database", "locale": "menu.database",
      "children": [
        { "id": "…0035", "permission_name": "database.uctoo", "path": "uctoo",
          "parent_id": "…0033", "type": 1,
          "children": [
            { "id": "…0036", "permission_name": "database.uctoo.entity",
              "path": "entity", "parent_id": "…0035", "type": 1,
              "component": "database/uctoo/entity/index", "title": "entity",
              "children": [] }
          ] }
      ]
    }
  ]
}
```

> 注意：接口返回的 `path` 是**节点自身相对片段**（`entity`），不是完整路径。完整路径由前端 vue-router 的父子嵌套自动拼出。

## 4. web 侧动态路由装配

流程：`store/modules/router.ts` → `getMenuList()` → `userMenuRepo.api().getUserMenuTree(userId)` → `menuList` → `router/guard/menu.ts` 的 `toRoutes()` 生成 vue-router 路由。

`router/guard/menu.ts` 关键逻辑：

```ts
export function toRoutes(menus: ITreeNodeData[]) {
  for (const menu of menus) {
    const path = `../../views/${menu.component}${menu.component.includes('.vue') ? '' : '.vue'}`
    router.push({
      name: menu.permission_name,   // = permission_name
      path: menu.path,              // = 节点自身 path，作为父/子相对路径
      component: views[path],
      children: [...toRoutes(menu.children ?? [])],  // 递归嵌套 → 完整 path 自动拼接
      meta: { locale: menu.locale, requiresAuth: true },
    })
  }
}
```

最终用户访问地址 = `import.meta.env.VITE_CONTEXT` + 拼接后的 `path`。

`.env` 中：`VITE_CONTEXT=/vue-pro/`。因此：

```
完整 URL = /vue-pro/  +  database/uctoo/entity  =  http://localhost:3031/vue-pro/database/uctoo/entity
```

（生产环境 `VITE_CONTEXT` 视部署配置可能不同，但 `/vue-pro` 这一段是 Vite `base`，与 `permissions` 表内容无关。）

## 5. 真实示例：entity 表页面的路由是怎么拼出来的

`sql/public20260924.sql` 中三条 `permissions` 记录（已用 Python 解析确认）：

| id | permission_name | path | parent_id | type | component |
|----|-----------------|------|-----------|------|-----------|
| `…0033` | `database` | `database` | NULL（根） | 1 | `…` |
| `…0035` | `database.uctoo` | `uctoo` | `…0033` | 1 | `database/uctoo/index` |
| `…0036` | `database.uctoo.entity` | `entity` | `…0035` | 1 | `database/uctoo/entity/index` |

拼接过程：

```
根 database      path = 'database'
 └ 子 uctoo      path = 'uctoo'     → 累计 'database/uctoo'
    └ 子 entity  path = 'entity'    → 累计 'database/uctoo/entity'
                                        + VITE_CONTEXT '/vue-pro/'
                                        = /vue-pro/database/uctoo/entity
```

组件文件定位：`src/views/database/uctoo/entity/index.vue`（由 `component='database/uctoo/entity/index'` 拼出）。

## 6. 对 agent 操作 web 的关键约束（经验教训）

1. **导航 URL 必须来自菜单树，不能猜。**
   正确来源二选一：
   - 调 `POST /api/v1/uctoo/permissions/user/menu`，在返回的树里找到目标 `permission_name`（如 `database.uctoo.entity`），沿 `parent_id` 链把各节点 `path` 拼成 `database/uctoo/entity`；
   - 或直接从 `permissions` 表用递归 SQL 查出完整 path（见第 8 节）。
   然后**补上 `VITE_CONTEXT` 前缀**：传给 `navigate_url` 的完整地址应是 `/vue-pro/database/uctoo/entity`。

2. **`navigate_url` 收的是"完整前端路由"，不是后端接口、也不是叶子片段。**
   - ❌ 错误：`/uctoo/entity`、`/entity`、`entity`、`database/uctoo/entity`（缺 `/vue-pro` 前缀）
   - ✅ 正确：`/vue-pro/database/uctoo/entity`

3. **查询类操作优先用页面级工具，而非重新导航+截图。**
   entity 页面挂载时已通过 `registerPageTool` 注册了 `query-entity-list` 等工具（见 `webmcp-agent-web-operation` 规格）。agent 应先 `navigate_url` 到正确页面，再调页面级工具拿数据——不要在独立浏览器里打开（那会丢失登录态，见该规格 T-011）。

4. **`type=3` 的 API 节点与页面导航无关**，那是接口级 RBAC 权限，路径形如 `/*` 或具体 API 路径，别和菜单 `path` 混淆。

## 7. 新增页面时菜单/路由如何注册

- **crudweb 生成**：`cjpm run ... crudweb --db uctoo --table entity` 生成页面 Vue 代码的同时，会在 `permissions` 表写入菜单节点（`type=1`）及其父链（如 `database`、`database.uctoo`），保证前端菜单树与组件一一对应。
- **API 权限自动同步**：runtime 启动或调用 `loadRouteFromApp` 时，`PermissionsController.collectAppRoutes` 把所有已注册 HTTP 路由写入 `permissions`（`type=3`、`hidden=1`、`parent_id` 指向名为 `API` 的父菜单），用于接口级 RBAC。这是增量更新，不会重复插入。
- **卸载清理**：`pluginuninstall` 的三层卸载模型会连带清理 `permissions` 表中该插件对应的菜单节点（见 SKILL.md 工具说明）。

## 8. 给开发者 / agent 的自查 SQL

已知页面 `permission_name`（如 `database.uctoo.entity`），递归上溯 `parent_id` 拼出完整路由：

```sql
WITH RECURSIVE chain AS (
  SELECT id, permission_name, path, parent_id, 0 AS depth
  FROM permissions
  WHERE permission_name = 'database.uctoo.entity' AND deleted_at IS NULL
  UNION ALL
  SELECT p.id, p.permission_name, p.path, p.parent_id, c.depth + 1
  FROM permissions p
  JOIN chain c ON p.id = c.parent_id
  WHERE p.deleted_at IS NULL
)
-- 自顶向下拼接（根在前）
SELECT string_agg(path, '/' ORDER BY depth DESC) AS full_route
FROM chain;
-- 结果：database/uctoo/entity
-- 前端完整地址 = current_setting('VITE_CONTEXT', true) || '/' || full_route  →  /vue-pro/database/uctoo/entity
```

> 说明：上述 `current_setting('VITE_CONTEXT', true)` 仅为示意；`VITE_CONTEXT` 是前端构建期环境变量（`.env` 中 `/vue-pro/`），不存于数据库，需按部署环境拼接。

## 9. 一图速记

```
permissions 表 (type=1 菜单节点, parent_id 成树)
        │  runtime: POST /api/v1/uctoo/permissions/user/menu
        ▼
前端 getMenuList()  →  menuList (树, 每节点仅含自身 path)
        │  router/guard/menu.ts: toRoutes()  →  vue-router 嵌套路由
        ▼
完整 path = 父链 path 拼接 + 叶子 path  =  database/uctoo/entity
        │  前缀 import.meta.env.VITE_CONTEXT (= /vue-pro/)
        ▼
最终 URL: /vue-pro/database/uctoo/entity   ← agent navigate_url 的目标
```
