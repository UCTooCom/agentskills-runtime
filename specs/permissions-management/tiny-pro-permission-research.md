# Tiny-Pro 原始版权限模块研究报告

> 研究对象：`D:\UCT\products\github\opentiny\tiny-pro\template\tinyvue\src\views\permission` 及相关模块
> 研究日期：2026-05-03

---

## 一、模块文件清单

### 1. Views - 权限管理页面

| 文件路径 | 功能 |
|---------|------|
| `views/permission/index.vue` | 路由容器组件，仅包含 `<router-view />` |
| `views/permission/info/index.vue` | 权限信息页面外层壳，GeneralLayout + 面包屑导航 |
| `views/permission/info/components/info-tab.vue` | **核心页面**：权限列表展示、新增/删除/行内编辑 |

### 2. API - 接口定义

| 文件路径 | 功能 |
|---------|------|
| `api/permission.ts` | 权限 CRUD：GET（分页+名称过滤）、PATCH、DELETE、POST |
| `api/role.ts` | 角色 CRUD：含 `getRoleInfo` 返回角色权限列表 |
| `api/user.ts` | 用户管理：登录/登出/获取用户信息/重置密码等 |
| `api/menu.ts` | 菜单管理：`getAllMenu`、`getRoleMenu(email)` 按角色获取菜单 |
| `api/interceptor.ts` | 请求/响应拦截器：注入 Bearer token、处理 401/403/400 |

### 3. Store - 状态管理

| 文件路径 | 功能 |
|---------|------|
| `store/modules/user/index.ts` | 用户 Store：含 `rolePermission[]` 权限名称数组 |
| `store/modules/user/types.ts` | 类型定义：`Role`、`UserInfo`、`RoleType` |
| `store/modules/router.ts` | 菜单 Store：按角色获取菜单树、动态路由注册 |

### 4. Router - 路由守卫

| 文件路径 | 功能 |
|---------|------|
| `router/guard/index.ts` | 守卫注册入口 |
| `router/guard/permission.ts` | 登录守卫：未登录重定向到 /login |
| `router/guard/info.ts` | 信息守卫：获取用户信息+刷新 rolePermission |
| `router/guard/menu.ts` | 菜单守卫：按角色获取菜单→动态注册路由 |

### 5. Directive - 权限指令

| 文件路径 | 功能 |
|---------|------|
| `directive/index.ts` | 全局指令注册入口 |
| `directive/permission/index.ts` | `v-permission` 自定义指令实现 |

### 6. Auth 工具

| 文件路径 | 功能 |
|---------|------|
| `utils/auth.ts` | Token 管理：sessionStorage 存取 |

---

## 二、整体架构与数据流

### 架构图

```
┌──────────────────────────────────────────────────────────────┐
│                       后端 API 服务                           │
│  POST /auth/login        → accessToken + refreshToken        │
│  GET  /user/info/:email  → UserInfo (含 role[])              │
│  GET  /role/info/:id     → Role (含 permission[])            │
│  GET  /menu/role/:email  → MenuTree (角色可见菜单)            │
│  GET  /permission        → CRUD 权限数据                      │
└──────────────────────────┬───────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │    axios interceptor     │
              │  请求: 注入 Bearer token │
              │  响应: 401→跳登录 403→提示│
              └────────────┬────────────┘
                           │
       ┌───────────────────▼───────────────────────┐
       │              路由守卫链（beforeEach）        │
       │  1. permission guard → 检查登录状态         │
       │  2. info guard → 获取用户信息+权限列表        │
       │  3. menu guard → 获取角色菜单→动态路由        │
       │  4. tabs guard → 标签页管理                  │
       └───────────────────┬───────────────────────┘
                           │
    ┌──────────────────────▼──────────────────────────┐
    │                 Pinia Store                      │
    │  useUserStore:                                  │
    │    - role / roleId / rolePermission[]            │
    │    - login() → 获取token+用户信息+角色权限        │
    │  useMenuStore:                                  │
    │    - menuList / flatMenuList                    │
    │    - getMenuList() → 按角色获取菜单树             │
    └──────────┬────────────────────┬─────────────────┘
               │                    │
    ┌──────────▼──────┐  ┌─────────▼──────────┐
    │  v-permission   │  │   动态路由注册       │
    │  按钮级权限控制  │  │   菜单级权限控制     │
    └─────────────────┘  └────────────────────┘
```

### 核心数据流

1. **登录阶段**：
   ```
   login API → accessToken/refreshToken → sessionStorage
   → getUserInfo → 提取 role[0]
   → getRoleInfo(roleId) → 提取 permission[].name
   → 存入 userStore.rolePermission
   ```

2. **路由跳转阶段**：
   ```
   permission guard → isLogin() 检查 sessionStorage token
   info guard → getUserInfo() → 刷新 userStore.rolePermission
   menu guard → getRoleMenu(email) → 菜单树 → toRoutes() → router.addRoute()
   ```

3. **按钮/元素级权限**：
   ```
   v-permission="'permission::add'"
   → 读取 userStore.rolePermission
   → permissionList.includes(value) || permissionList.includes('*')
   → 不匹配则 el.remove()
   ```

---

## 三、三层权限控制体系

### 第1层：菜单/路由级权限

**实现方式**：动态路由守卫（`guard/menu.ts`）

- 调用 `getRoleMenu(userStore.email)` 获取当前用户角色可见的菜单树
- 通过 `toRoutes()` 将菜单树转换为 `RouteRecordRaw[]`
- 使用 `router.addRoute('root', route)` 动态注册路由
- 不同角色用户看到的侧边栏菜单不同，路由也只包含其角色允许访问的页面
- 首次加载后缓存 `menuList`，避免重复请求

**菜单数据结构**：
```typescript
interface ITreeNodeData {
  id; label; children?; url; component; customIcon;
  menuType; parentId; order; locale;
}
```

### 第2层：按钮/元素级权限

**实现方式**：`v-permission` 自定义指令（`directive/permission/index.ts`）

```typescript
async function checkPermission(el: HTMLElement, binding: { value: string }) {
  const { rolePermission } = useUserStore()
  const hasPermission = rolePermission.includes(binding.value) || rolePermission.includes('*')
  if (!hasPermission) { el.remove() } // 直接移除DOM元素
}
```

**使用示例**：
```html
<TinyButton v-permission="'permission::add'" type="primary">添加权限</TinyButton>
<a v-permission="'permission::remove'">删除</a>
```

**特点**：
- `'*'` 是超级权限通配符，拥有 `'*'` 的用户可以看到所有受控元素
- 使用 `el.remove()` 彻底移除 DOM，而非 `display:none` 隐藏

### 第3层：API/HTTP级权限

**实现方式**：axios 拦截器（`api/interceptor.ts`）

- **请求拦截**：自动注入 `Authorization: Bearer {token}` 和 `x-lang` 头
- **响应拦截**：
  - `401`：清除 token，跳转登录页
  - `403`：弹出 "无权限" 错误提示
  - `400`：提取服务端验证错误消息

---

## 四、API 接口定义

| 模块 | 方法 | HTTP | 路径 | 参数 | 返回 |
|------|------|------|------|------|------|
| 权限 | `getAllPermission` | GET | `/permission` | `page, limit, name` | `{ items: Permission[], meta }` |
| 权限 | `createPermission` | POST | `/permission` | `{ name, desc }` | Permission |
| 权限 | `updatePermission` | PATCH | `/permission` | `{ id, name, desc }` | - |
| 权限 | `deletePermission` | DELETE | `/permission/:id` | id | - |
| 角色 | `getAllRoleDetail` | GET | `/role/detail` | `page, limit, name` | `{ roleInfo, menuTree }` |
| 角色 | `getRoleInfo` | GET | `/role/info/:id` | roleId | Role（含 permission[]） |
| 角色 | `createRole` | POST | `/role` | `{ name, permission, menus }` | - |
| 角色 | `updateRole` | PATCH | `/role` | `{ id, name, permission, menus }` | - |
| 角色 | `deleteRole` | DELETE | `/role/:id` | id | - |
| 菜单 | `getAllMenu` | GET | `/menu` | - | `ITreeNodeData[]` |
| 菜单 | `getRoleMenu` | GET | `/menu/role/:email` | email | 菜单树（按角色过滤） |
| 用户 | `login` | POST | `/auth/login` | `{ email, password }` | `{ accessToken, refreshToken }` |
| 用户 | `getUserInfo` | GET | `/user/info/:email` | email | `UserInfo`（含 role[]） |
| Token | `flushToken` | POST | `/auth/token/refresh` | `{ token }` | `{ accessToken, refreshToken }` |

---

## 五、Store 状态管理

### useUserStore

```typescript
state: {
  role: [],              // 当前角色名（如 'admin'、'user'）
  roleId: 0,             // 当前角色ID
  rolePermission: [],    // 权限名称字符串数组
                         // 例：['permission::add', 'permission::remove', '*']
  accessToken: '',       // JWT访问令牌
  refreshToken: '',      // JWT刷新令牌
}
```

**权限状态更新时机**：

1. **登录时**（`login` action）：
   ```typescript
   const res = await userLogin(loginForm)
   setToken(accessToken); setRefreshToken(refreshToken)
   const userRes = await getUserInfo(loginForm.email)
   userInfo.role = userRes.data.role[0].name
   userInfo.roleId = userRes.data.role[0].id
   const { data } = await getRoleInfo(userInfo.roleId)
   for (permissions) { userInfo.rolePermission.push(permissions[i].name) }
   this.setInfo(userInfo)
   ```

2. **路由跳转时**（`info` guard）：
   ```typescript
   const { data } = await getUserInfo()
   userStore.rolePermission = (data.role as unknown as Role[])
     .flatMap(role => role.permission)
     .map(permission => permission.name)
   ```
   每次路由跳转都重新计算，确保权限变更实时生效。

### useMenuStore

```typescript
state: {
  menuList: [],       // 树形菜单数据（按角色过滤后）
  flatMenuList: [],   // 扁平化菜单列表
}
actions: {
  async getMenuList() {
    const { data } = await getRoleMenu(userStore.email)
    this.menuList = data
    this.menuListFlat()  // DFS扁平化
  }
}
```

---

## 六、权限管理页面功能（info-tab.vue）

### 数据展示
- 使用 `TinyGrid` 表格展示权限列表
- 支持分页（远程分页）
- 支持远程过滤（按名称搜索）
- 支持行内编辑（`edit-config: { trigger: 'click', mode: 'cell' }`）

### 新增权限
- 点击"添加权限"按钮弹出 `TinyModal` 对话框
- 表单包含 `name`（必填）和 `desc`
- 提交调用 `createPermission(data)`

### 删除权限
- 使用 `TinyPopconfirm` 确认
- 调用 `deletePermission(id)`

### 编辑权限
- 行内编辑，`edit-closed` 事件触发
- 调用 `updatePermission({ id, name, desc })`

### 权限指令
- `v-permission="'permission::add'"` — 控制添加按钮可见性
- `v-permission="'permission::remove'"` — 控制删除按钮可见性

### MCP 集成
- `registerPageTool` 注册 `add-permission` 工具
- 支持外部 AI 工具调用新增权限

---

## 七、核心设计模式总结

### 1. 数据模型关系

```
User ──N:N── Role ──N:N── Permission
  │                │
  │                └──N:N── Menu
  │
  └── 1:N ── Session
```

- **User-Role**：多对多，通过 `user.role[]` 关联
- **Role-Permission**：多对多，通过 `role.permission[]` 关联
- **Role-Menu**：多对多，通过 `role.menus[]` 关联
- 前端只存储扁平化的 `rolePermission: string[]`（权限名称数组）

### 2. 权限判断逻辑

```typescript
// 按钮级：v-permission 指令
hasPermission = rolePermission.includes(requiredPermission) || rolePermission.includes('*')

// 菜单级：动态路由
visibleMenus = getRoleMenu(userEmail)  // 后端按角色过滤

// API级：HTTP 拦截器
401 → 跳登录 | 403 → 提示无权限
```

### 3. Token 管理

- 存储：`sessionStorage`（关闭浏览器即失效）
- 类型：JWT（accessToken + refreshToken）
- 刷新：`flushToken` 接口，支持无感刷新
- 注入：axios 请求拦截器自动添加 `Authorization: Bearer {token}`

### 4. 通配符权限

- `'*'` 表示超级权限
- 在 `v-permission` 指令中：`permissionList.includes('*')` 为 true 则跳过所有权限检查
- 在 `RoleType` 中：`'*' | 'admin' | 'user'` 定义角色枚举

---

## 八、与 UCToo V4 的对比

| 特性 | Tiny-Pro 原始版 | UCToo V4 当前实现 |
|------|----------------|-----------------|
| 权限数据模型 | Permission(name, desc) | PermissionsPO(permission_name, type, menu_type, path, component, ...) |
| 权限类型 | 单一类型 | 菜单权限(type=1) + API权限(type=2) |
| 角色-权限关联 | role.permission[] | role_has_permission 表 |
| 用户-角色关联 | user.role[] | user_has_roles 表 |
| 菜单获取 | GET /menu/role/:email | POST /permissions/user/menu |
| 权限列表 | GET /permission | POST /permissions/user/all |
| 权限判断 | v-permission 指令 | v-permission 指令（相同） |
| Token 存储 | sessionStorage | localStorage |
| 动态路由 | menu guard + router.addRoute | menu guard + router.addRoute（相同） |
| 超级权限 | '*' 通配符 | '*' 通配符（相同） |

### UCToo V4 增强点

1. **权限类型细分**：type=1(菜单) + type=2(API/操作)，支持更精细的权限控制
2. **RBAC 四表模型**：uctoo_role + user_has_roles + role_has_permission + permissions，标准数据库级 RBAC
3. **软删除支持**：所有表支持 deleted_at 软删除
4. **权限树结构**：permissions 表支持 parent_id 树形结构，与菜单树统一
5. **仓颉后端**：使用仓颉语言实现，非 Node.js/Python
