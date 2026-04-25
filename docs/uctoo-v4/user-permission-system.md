# uctoo v4 用户权限体系

## 文档信息
- **版本**: 4.0
- **创建日期**: 2026-04-04
- **更新日期**: 2026-04-04
- **状态**: 初稿

## 1. 概述

uctoo v4 实现了标准的 RBAC（Role-Based Access Control，基于角色的访问控制）权限体系，相比 v3 版本进行了重大改进：

### 1.1 v3 到 v4 的主要变化

| v3 组件 | v4 组件 | 变化说明 |
|---------|---------|----------|
| user_group | uctoo_role | v4 使用角色替代用户组进行权限管理 |
| group_has_permission | role_has_permission | 角色与权限的关联表 |
| user_has_group | user_has_roles | 用户与角色的关联表 |
| user_group (分组) | user_has_group | v4 中 user_group 仅用于用户分组，不与权限关联 |

### 1.2 RBAC 标准模型

uctoo v4 实现了 RBAC3 权限体系，包含以下核心概念：

- **用户（User）**: uctoo_user 表
- **角色（Role）**: uctoo_role 表
- **权限（Permission）**: permissions 表
- **用户-角色关联**: user_has_roles 表
- **角色-权限关联**: role_has_permission 表

权限关系链：
```
用户 (uctoo_user) 
  → user_has_roles 
  → 角色 (uctoo_role) 
  → role_has_permission 
  → 权限 (permissions)
```

## 2. 权限类型体系

### 2.1 权限类型定义

permissions 表中的 `type` 字段定义权限类型：

| type 值 | 权限类型 | 说明 |
|---------|---------|------|
| 1 | 菜单权限 | 前端菜单项的显示权限 |
| 2 | 按钮权限 | 页面按钮的操作权限 |
| 3 | API权限 | 后端接口的访问权限 |
| 4 | 工具权限 | 工具功能的访问权限 |

### 2.2 通配符权限设计

为了简化权限配置，uctoo v4 引入了通配符权限机制：

| permission_name | 权限范围 | 说明 |
|----------------|---------|------|
| `*` | 所有权限 | 不区分 type 的所有权限（超级管理员权限） |
| `/*` | 所有 API 权限 | type=3 的所有 API 权限（API 以 `/` 开头） |
| `menu:*` | 所有菜单权限 | type=1 的所有菜单权限 |
| `button:*` | 所有按钮权限 | type=2 的所有按钮权限 |
| `tool:*` | 所有工具权限 | type=4 的所有工具权限 |

### 2.3 通配符权限匹配规则

**优先级规则**（从高到低）：
1. 精确匹配：`permission_name = 'Board'`
2. 类型通配符：`permission_name = 'menu:*'`
3. 全局通配符：`permission_name = '*'`

**匹配逻辑**：
```cangjie
// 检查用户是否有特定权限
func hasPermission(userPermissions: ArrayList<String>, requiredPermission: String, permissionType: Int32): Boolean {
    // 1. 检查全局通配符
    if (userPermissions.contains("*")) {
        return true
    }
    
    // 2. 检查类型通配符
    let typeWildcard = getTypeWildcard(permissionType)  // menu:*, button:*, /*, tool:*
    if (userPermissions.contains(typeWildcard)) {
        return true
    }
    
    // 3. 检查精确匹配
    if (userPermissions.contains(requiredPermission)) {
        return true
    }
    
    return false
}

// 获取类型通配符
func getTypeWildcard(type: Int32): String {
    match (type) {
        case 1 => "menu:*"    // 菜单权限
        case 2 => "button:*"  // 按钮权限
        case 3 => "/*"        // API权限
        case 4 => "tool:*"    // 工具权限
        case _ => ""
    }
}
```

## 3. 数据库表结构

### 3.1 核心表结构

#### uctoo_user（用户表）
```sql
CREATE TABLE uctoo_user (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE,
    password VARCHAR(255),
    name VARCHAR(255),
    -- 其他字段...
    created_at TIMESTAMPTZ(6),
    updated_at TIMESTAMPTZ(6),
    deleted_at TIMESTAMPTZ(6)
);
```

#### uctoo_role（角色表）
```sql
CREATE TABLE uctoo_role (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name VARCHAR(255) UNIQUE NOT NULL,
    description VARCHAR(255),
    -- 其他字段...
    created_at TIMESTAMPTZ(6),
    updated_at TIMESTAMPTZ(6),
    deleted_at TIMESTAMPTZ(6)
);
```

#### permissions（权限表）
```sql
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_name VARCHAR(255) UNIQUE NOT NULL,
    type INT NOT NULL,              -- 权限类型：1=菜单, 2=按钮, 3=API, 4=工具
    path VARCHAR(255),              -- 路由路径或API路径
    component VARCHAR(255),         -- 前端组件路径
    icon VARCHAR(255),              -- 图标
    title VARCHAR(255),             -- 标题
    parent_id UUID,                 -- 父权限ID
    weight INT,                     -- 排序权重
    menu_type VARCHAR(50),          -- 菜单类型：normal, admin
    locale VARCHAR(255),            -- 国际化标识
    method VARCHAR(10),             -- HTTP方法（API权限）
    -- 其他字段...
    created_at TIMESTAMPTZ(6),
    updated_at TIMESTAMPTZ(6),
    deleted_at TIMESTAMPTZ(6)
);
```

#### user_has_roles（用户-角色关联表）
```sql
CREATE TABLE user_has_roles (
    user_id UUID NOT NULL REFERENCES uctoo_user(id),
    role_id UUID NOT NULL REFERENCES uctoo_role(id),
    status INT DEFAULT 1,
    created_at TIMESTAMPTZ(6),
    updated_at TIMESTAMPTZ(6),
    deleted_at TIMESTAMPTZ(6),
    PRIMARY KEY (user_id, role_id)
);
```

#### role_has_permission（角色-权限关联表）
```sql
CREATE TABLE role_has_permission (
    role_id UUID NOT NULL REFERENCES uctoo_role(id),
    permission_name VARCHAR(255) NOT NULL,
    status INT DEFAULT 1,
    creator UUID,
    created_at TIMESTAMPTZ(6),
    updated_at TIMESTAMPTZ(6),
    deleted_at TIMESTAMPTZ(6),
    PRIMARY KEY (role_id, permission_name)
);
```

### 3.2 索引设计

```sql
-- 用户角色查询索引
CREATE INDEX idx_user_has_roles_user_id ON user_has_roles(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_has_roles_role_id ON user_has_roles(role_id) WHERE deleted_at IS NULL;

-- 角色权限查询索引
CREATE INDEX idx_role_has_permission_role_id ON role_has_permission(role_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_role_has_permission_perm_name ON role_has_permission(permission_name) WHERE deleted_at IS NULL;

-- 权限查询索引
CREATE INDEX idx_permissions_type ON permissions(type) WHERE deleted_at IS NULL;
CREATE INDEX idx_permissions_parent_id ON permissions(parent_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_permissions_perm_name ON permissions(permission_name) WHERE deleted_at IS NULL;
```

## 4. 权限检查机制

### 4.1 API 权限检查

**中间件实现**：`RequirePermissionMiddleware`

**检查流程**：
1. 从 JWT token 中获取用户 ID
2. 查询用户的所有角色
3. 查询角色的所有权限
4. 检查是否有匹配的权限（支持通配符）

**示例代码**：
```cangjie
public func handle(req: HttpRequest, res: HttpResponse, next: Function): Unit {
    // 1. 获取用户ID
    let userId = getUserIdFromToken(req)
    
    // 2. 获取用户权限
    let permissions = getUserPermissions(userId)
    
    // 3. 检查权限
    let route = req.path
    let method = req.method
    
    if (hasAPIPermission(permissions, route, method)) {
        next(req, res)
    } else {
        res.status(403).json("{\"errno\":\"40300\",\"errmsg\":\"无权限\"}")
    }
}

private func hasAPIPermission(permissions: ArrayList<String>, route: String, method: String): Boolean {
    // 检查通配符权限
    if (permissions.contains("*") || permissions.contains("/*")) {
        return true
    }
    
    // 检查精确权限
    let permissionName = "${method}:${route}"
    return permissions.contains(permissionName)
}
```

### 4.2 菜单权限检查

**查询流程**：
1. 获取用户的所有角色
2. 获取角色的所有权限名称
3. 检查是否有通配符权限
   - 如果有 `*` 或 `menu:*`，返回所有菜单
   - 否则，根据权限名称查询菜单
4. 构建菜单树形结构

**示例代码**：
```cangjie
public func getUserMenuTree(userId: String): ArrayList<PermissionsPO> {
    // 1. 获取用户角色
    let roleIds = findUserRoles(userId)
    
    // 2. 获取权限名称
    let permissionNames = ArrayList<String>()
    var hasMenuWildcard = false
    
    for (roleId in roleIds) {
        let perms = findRolePermissionNames(roleId)
        for (permName in perms) {
            permissionNames.add(permName)
            
            // 检查通配符
            if (permName == "*" || permName == "menu:*") {
                hasMenuWildcard = true
            }
        }
    }
    
    // 3. 查询菜单
    let menus = if (hasMenuWildcard) {
        findAllMenuPermissions()  // 返回所有菜单
    } else {
        findPermissionsByNames(permissionNames)  // 按权限名称查询
    }
    
    // 4. 构建树形结构
    return buildMenuTree(menus)
}
```

## 5. 初始权限数据

### 5.1 超级管理员角色

```sql
-- 创建超级管理员角色
INSERT INTO uctoo_role (id, role_name, description) 
VALUES ('2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d', '超级管理员', '拥有所有权限');

-- 分配全局通配符权限
INSERT INTO role_has_permission (role_id, permission_name, status) 
VALUES ('2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d', '*', 1);
```

### 5.2 普通管理员角色

```sql
-- 创建普通管理员角色
INSERT INTO uctoo_role (id, role_name, description) 
VALUES ('角色UUID', '管理员', '拥有菜单和API权限');

-- 分配菜单权限
INSERT INTO role_has_permission (role_id, permission_name, status) 
VALUES ('角色UUID', 'menu:*', 1);

-- 分配API权限
INSERT INTO role_has_permission (role_id, permission_name, status) 
VALUES ('角色UUID', '/*', 1);
```

### 5.3 访客角色

```sql
-- 创建访客角色
INSERT INTO uctoo_role (id, role_name, description) 
VALUES ('角色UUID', '访客', '无任何权限');

-- 访客角色默认无权限，需要时单独分配
```

## 6. 权限管理最佳实践

### 6.1 角色设计原则

1. **最小权限原则**: 默认无权限，按需分配
2. **角色职责单一**: 每个角色对应明确的职责
3. **避免角色嵌套**: 不支持角色继承，避免复杂性
4. **定期审计权限**: 定期检查和清理不必要的权限

### 6.2 权限命名规范

#### 6.2.1 命名格式选择

uctoo v4 采用**单冒号 (:) 格式**作为权限命名标准，这是基于业界最佳实践的决策。

**业界主流实践对比**：

| 系统 | 权限格式 | 示例 |
|------|---------|------|
| Kubernetes RBAC | 单冒号 | `pods:create`, `deployments:update` |
| Azure RBAC | 单冒号 | `Microsoft.Compute/virtualMachines/start/action` |
| Spring Security | 单冒号 | `user:read`, `user:write` |
| Apache Shiro | 单冒号 | `user:create`, `user:delete` |
| Linux 文件权限 | 单冒号 | `user:group:rwx` |

**选择单冒号的优势**：

1. **业界标准**: 符合 Kubernetes、Azure、Spring Security 等主流系统的命名规范
2. **简洁明了**: 单冒号更简洁，减少输入和阅读负担
3. **易于解析**: 单冒号在字符串处理中更常见，解析逻辑更简单
4. **通配符支持**: 更容易实现通配符匹配（如 `user:*` 匹配所有用户操作）
5. **国际化友好**: 单冒号在不同语言和字符集中更通用

**原版双冒号格式的问题**：

1. **非标准**: 双冒号在大多数权限系统中不常见
2. **冗余**: 双冒号没有增加语义价值，反而增加了输入负担
3. **解析复杂**: 需要特殊处理双冒号的分割逻辑

#### 6.2.2 权限命名详细规范

uctoo v4 支持**多数据库权限管理**，权限命名采用三段式结构，清晰区分不同数据库和表的权限。

**三段式命名结构**：
```
{数据库名}:{表名}:{操作名}
```

**命名规则说明**：
1. **第一段 - 数据库名**：与实际数据库名称一致（如 `uctoo`）
2. **第二段 - 表名**：与数据库表名一致（如 `i18`, `uctoo_user`, `permissions`）
3. **第三段 - 操作名**：与路由API定义一致（如 `add`, `edit`, `del`）

**菜单权限 (type=1)**：
- 格式：`{数据库名}:{表名}` 或 `menu.{模块名}`
- 示例：
  - `uctoo:uctoo_user` - 用户管理菜单
  - `uctoo:permissions` - 权限管理菜单
  - `uctoo:i18` - 国际化管理菜单
  - `menu.settings` - 设置菜单
  - `menu.profile` - 个人中心菜单

**按钮权限 (type=2)**：
- 格式：`{数据库名}:{表名}:{操作名}`
- 操作名标准词汇（与路由API一致）：
  - `add` - 创建（对应路由：`/api/v1/{db}/{table}/add`）
  - `edit` - 编辑（对应路由：`/api/v1/{db}/{table}/edit`）
  - `del` - 删除（对应路由：`/api/v1/{db}/{table}/del`）
  - `all` - 获取全部（对应路由：`/api/v1/{db}/{table}/all`）
  - `:id` - 单条查询（对应路由：`/api/v1/{db}/{table}/:id`）
  - `:limit/:page` - 列表查询（对应路由：`/api/v1/{db}/{table}/:limit/:page`）
- 示例：
  - `uctoo:i18:add` - 添加国际化词条
  - `uctoo:i18:edit` - 编辑国际化词条
  - `uctoo:i18:del` - 删除国际化词条
  - `uctoo:uctoo_user:add` - 创建用户
  - `uctoo:uctoo_user:edit` - 编辑用户
  - `uctoo:uctoo_user:del` - 删除用户
  - `uctoo:permissions:add` - 创建权限
  - `uctoo:permissions:edit` - 编辑权限
  - `uctoo:permissions:del` - 删除权限
  - `uctoo:lang:add` - 创建语言
  - `uctoo:lang:edit` - 编辑语言
  - `uctoo:lang:del` - 删除语言

**API权限 (type=3)**：
- 格式：`/api/{版本}/{数据库名}/{表名}`
- 示例：
  - `/api/v1/uctoo/user` - 用户API
  - `/api/v1/uctoo/role` - 角色API
  - `/api/v1/uctoo/permissions` - 权限API
  - `/api/v1/uctoo/i18` - 国际化API
  - `/api/v1/skills/execute` - 技能执行API

**工具权限 (type=4)**：
- 格式：`tool:{工具名}`
- 示例：
  - `tool:crud-generator` - CRUD生成器
  - `tool:api-docs` - API文档生成器

**多数据库支持优势**：
1. **数据库隔离**：不同数据库的权限完全独立，避免权限冲突
2. **易于扩展**：新增数据库只需按照命名规范添加权限即可
3. **权限粒度细**：可以精确控制到每个表的每个操作
4. **路由一致性**：权限名称与API路由路径保持一致，便于理解和维护

#### 6.2.3 从原版迁移的权限列表

以下是从原版 MySQL (tinypro.sql) 迁移到新版 PostgreSQL 的权限数据：

| 原版权限名 | 新版权限名 | 权限类型 | 说明 |
|-----------|-----------|---------|------|
| `*` | `*` | 通配符 | 超级权限 |
| `user::add` | `uctoo:uctoo_user:add` | 按钮权限 | 创建用户 |
| `user::update` | `uctoo:uctoo_user:edit` | 按钮权限 | 编辑用户 |
| `user::remove` | `uctoo:uctoo_user:del` | 按钮权限 | 删除用户 |
| `user::query` | `uctoo:uctoo_user:all` | 按钮权限 | 查询所有用户 |
| `user::batch-remove` | `uctoo:uctoo_user:batch-del` | 按钮权限 | 批量删除用户 |
| `user::password::force-update` | `uctoo:uctoo_user:force-update-password` | 按钮权限 | 强制修改密码 |
| `role::add` | `uctoo:uctoo_role:add` | 按钮权限 | 创建角色 |
| `role::update` | `uctoo:uctoo_role:edit` | 按钮权限 | 编辑角色 |
| `role::remove` | `uctoo:uctoo_role:del` | 按钮权限 | 删除角色 |
| `role::query` | `uctoo:uctoo_role:all` | 按钮权限 | 查询所有角色 |
| `menu::add` | `uctoo:permissions:add` | 按钮权限 | 创建菜单 |
| `menu::update` | `uctoo:permissions:edit` | 按钮权限 | 编辑菜单 |
| `menu::remove` | `uctoo:permissions:del` | 按钮权限 | 删除菜单 |
| `menu::query` | `uctoo:permissions:all` | 按钮权限 | 查询所有菜单 |
| `permission::add` | `uctoo:permissions:add-permission` | 按钮权限 | 创建权限 |
| `permission::update` | `uctoo:permissions:edit-permission` | 按钮权限 | 编辑权限 |
| `permission::remove` | `uctoo:permissions:del-permission` | 按钮权限 | 删除权限 |
| `permission::get` | `uctoo:permissions:all-permissions` | 按钮权限 | 查询所有权限 |
| `i18n::add` | `uctoo:i18:add` | 按钮权限 | 创建国际化词条 |
| `i18n::update` | `uctoo:i18:edit` | 按钮权限 | 编辑国际化词条 |
| `i18n::remove` | `uctoo:i18:del` | 按钮权限 | 删除国际化词条 |
| `i18n::query` | `uctoo:i18:all` | 按钮权限 | 查询所有国际化词条 |
| `i18n::batch-remove` | `uctoo:i18:batch-del` | 按钮权限 | 批量删除国际化词条 |
| `lang::add` | `uctoo:lang:add` | 按钮权限 | 创建语言 |
| `lang::update` | `uctoo:lang:edit` | 按钮权限 | 编辑语言 |
| `lang::remove` | `uctoo:lang:del` | 按钮权限 | 删除语言 |
| `lang::query` | `uctoo:lang:all` | 按钮权限 | 查询所有语言 |

**迁移说明**：
- 原版所有权限都是按钮权限 (type=2)
- 原版使用双冒号 (::) 格式，新版统一改为三段式单冒号 (:) 格式
- 三段式结构：`{数据库名}:{表名}:{操作名}`
- 操作名与路由API定义一致：`add`, `edit`, `del`, `all`, `:id`, `:limit/:page`
- 详细迁移脚本见：`apps/agentskills-runtime/sql/migrate-permissions-from-tinypro.sql`

### 6.3 前端权限控制

#### 6.3.1 菜单权限控制

**菜单显示逻辑**：
```typescript
// 根据用户权限过滤菜单
function filterMenuByPermission(menuList: Menu[], userPermissions: string[]): Menu[] {
  return menuList.filter(menu => {
    // 检查通配符
    if (userPermissions.includes('*') || userPermissions.includes('menu:*')) {
      return true
    }
    
    // 检查精确权限
    return userPermissions.includes(menu.permissionName)
  })
}
```

**Vue 组件示例**：
```vue
<template>
  <a-menu v-for="menu in filteredMenus" :key="menu.id">
    <a-menu-item>{{ menu.title }}</a-menu-item>
  </a-menu>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useUserStore } from '@/store/user'

const userStore = useUserStore()
const userPermissions = computed(() => userStore.permissions)

const filteredMenus = computed(() => {
  return menuList.filter(menu => {
    // 检查通配符
    if (userPermissions.value.includes('*') || 
        userPermissions.value.includes('menu:*')) {
      return true
    }
    
    // 检查精确权限
    return userPermissions.value.includes(menu.permissionName)
  })
})
</script>
```

#### 6.3.2 按钮权限控制

**权限指令实现**：
```typescript
// src/directive/permission/index.ts
import { useUserStore } from '@/store/user'

function checkPermission(el: HTMLElement, binding: { value: string }) {
  const { value } = binding
  const userStore = useUserStore()
  const { permissions } = userStore
  
  // 检查权限
  const hasPermission = 
    permissions.includes('*') ||           // 全局通配符
    permissions.includes('button:*') ||    // 按钮通配符
    permissions.includes(value)            // 精确权限
  
  if (!hasPermission) {
    el.remove()  // 无权限则移除元素
  }
}

export default {
  mounted(el: HTMLElement, binding: any) {
    checkPermission(el, binding)
  },
  updated(el: HTMLElement, binding: any) {
    checkPermission(el, binding)
  },
}
```

**Vue 组件使用示例**：
```vue
<template>
  <div class="user-management">
    <!-- 操作按钮区域 -->
    <div class="action-buttons">
      <a-button v-permission="'user:create'" type="primary">
        创建用户
      </a-button>
      <a-button v-permission="'user:edit'" type="default">
        编辑用户
      </a-button>
      <a-button v-permission="'user:delete'" type="danger">
        删除用户
      </a-button>
      <a-button v-permission="'user:batch-delete'" type="danger">
        批量删除
      </a-button>
      <a-button v-permission="'user:export'" type="default">
        导出用户
      </a-button>
    </div>
    
    <!-- 用户列表表格 -->
    <a-table :data-source="userList">
      <a-table-column title="用户名" data-index="name" />
      <a-table-column title="邮箱" data-index="email" />
      <a-table-column title="操作">
        <template #default="{ record }">
          <a-button v-permission="'user:edit'" size="small" @click="editUser(record)">
            编辑
          </a-button>
          <a-button v-permission="'user:delete'" size="small" danger @click="deleteUser(record)">
            删除
          </a-button>
        </template>
      </a-table-column>
    </a-table>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const userList = ref([])

function editUser(user: any) {
  // 编辑用户逻辑
}

function deleteUser(user: any) {
  // 删除用户逻辑
}
</script>
```

**权限检查函数**：
```typescript
// src/utils/permission.ts
import { useUserStore } from '@/store/user'

/**
 * 检查用户是否有指定权限
 * @param permission 权限名称
 * @returns 是否有权限
 */
export function hasPermission(permission: string): boolean {
  const userStore = useUserStore()
  const permissions = userStore.permissions
  
  return permissions.includes('*') ||           // 全局通配符
         permissions.includes('button:*') ||    // 按钮通配符
         permissions.includes(permission)       // 精确权限
}

/**
 * 检查用户是否有任意一个权限
 * @param permissionList 权限列表
 * @returns 是否有权限
 */
export function hasAnyPermission(permissionList: string[]): boolean {
  return permissionList.some(permission => hasPermission(permission))
}

/**
 * 检查用户是否有所有权限
 * @param permissionList 权限列表
 * @returns 是否有权限
 */
export function hasAllPermissions(permissionList: string[]): boolean {
  return permissionList.every(permission => hasPermission(permission))
}
```

#### 6.3.3 角色管理页面示例

```vue
<template>
  <div class="role-management">
    <!-- 操作按钮 -->
    <div class="action-buttons">
      <a-button v-permission="'role:create'" type="primary">
        创建角色
      </a-button>
    </div>
    
    <!-- 角色列表 -->
    <a-table :data-source="roleList">
      <a-table-column title="角色名称" data-index="roleName" />
      <a-table-column title="描述" data-index="description" />
      <a-table-column title="操作">
        <template #default="{ record }">
          <a-button v-permission="'role:edit'" size="small" @click="editRole(record)">
            编辑
          </a-button>
          <a-button v-permission="'role:delete'" size="small" danger @click="deleteRole(record)">
            删除
          </a-button>
          <a-button v-permission="'permission:assign'" size="small" @click="assignPermission(record)">
            分配权限
          </a-button>
        </template>
      </a-table-column>
    </a-table>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const roleList = ref([])

function editRole(role: any) {
  // 编辑角色逻辑
}

function deleteRole(role: any) {
  // 删除角色逻辑
}

function assignPermission(role: any) {
  // 分配权限逻辑
}
</script>
```

### 6.4 后端权限控制

#### 6.4.1 仓颉后端权限中间件

**权限中间件实现**：
```cangjie
// src/app/middlewares/auth/RequirePermissionMiddleware.cj
public class RequirePermissionMiddleware <: Middleware {
    private let permissionsService: PermissionsService
    private let userHasRolesService: UserHasRolesService
    private let roleHasPermissionService: RoleHasPermissionService

    public func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit {
        // 1. 获取用户ID
        let userId = req.getLocals("userId")
        
        if (let Some(uid) <- userId) {
            let uidStr = uid as String
            if (let Some(userIdStr) <- uidStr) {
                // 2. 获取当前路由路径
                let routePattern = req.uri.path
                let httpMethod = httpMethodToString(req.method)
                
                // 3. 检查权限
                if (checkPermission(userIdStr, routePattern, httpMethod)) {
                    next()
                } else {
                    res.status(403).json("{\"errno\":\"40301\",\"errmsg\":\"no permission\"}")
                }
            } else {
                res.status(403).json("{\"errno\":\"40302\",\"errmsg\":\"invalid user info\"}")
            }
        } else {
            res.status(401).json("{\"errno\":\"40100\",\"errmsg\":\"not login\"}")
        }
    }

    private func checkPermission(userId: String, routePattern: String, httpMethod: String): Bool {
        // 1. 查询用户所属角色
        let userRoles = userHasRolesService.findByUserId(userId)
        if (userRoles.isEmpty()) {
            return false
        }

        // 2. 收集角色ID
        let roleIds = ArrayList<String>()
        for (ur in userRoles) {
            roleIds.add(ur.roleId)
        }

        // 3. 检查是否有全部权限（*）
        if (hasWildcardPermission(roleIds)) {
            return true
        }

        // 4. 检查是否有特定路由权限
        if (hasRoutePermission(roleIds, routePattern, httpMethod)) {
            return true
        }

        false
    }

    private func hasWildcardPermission(roleIds: ArrayList<String>): Bool {
        let permissions = roleHasPermissionService.findByRoleIds(roleIds)
        for (p in permissions) {
            let permName = p.permissionName
            
            // 检查全局通配符
            if (permName == "*") {
                return true
            }
            
            // 检查API通配符
            if (permName == "/*") {
                return true
            }
        }
        false
    }

    private func hasRoutePermission(roleIds: ArrayList<String>, routePattern: String, httpMethod: String): Bool {
        let permissions = roleHasPermissionService.findByRoleIds(roleIds)
        for (rp in permissions) {
            // 精确匹配
            if (rp.permissionName == routePattern) {
                return true
            }

            // 路由参数匹配
            if (matchRoutePattern(rp.permissionName, routePattern)) {
                return true
            }
        }
        false
    }
}
```

**路由配置示例**：
```cangjie
// src/app/routes/uctoo/user/UserRoute.cj
public class UserRoute <: Route {
    public func register(router: Router): Unit {
        // 用户管理路由（需要权限）
        router.group("/api/v1/uctoo/user", (group) => {
            // 所有路由都需要权限检查
            group.use(requirePermissionMiddleware)
            
            // 创建用户 - 需要 user:create 权限
            group.post("/", userController.create)
            
            // 更新用户 - 需要 user:edit 权限
            group.put("/:id", userController.update)
            
            // 删除用户 - 需要 user:delete 权限
            group.delete("/:id", userController.delete)
            
            // 查询用户列表 - 需要 user:query 权限
            group.get("/:limit/:page", userController.getList)
            
            // 查询用户详情 - 需要 user:query 权限
            group.get("/:id", userController.getById)
        })
    }
}
```

#### 6.4.2 NestJS 后端权限守卫（原版实现）

**权限装饰器**：
```typescript
// src/public/permission.decorator.ts
import { SetMetadata } from '@nestjs/common'

export const PERMISSION_KEYS = 'permissions'

export const Permission = (...permissions: string[]) =>
  SetMetadata(PERMISSION_KEYS, permissions)
```

**权限守卫**：
```typescript
// src/permission/permission.guard.ts
import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common'
import { Reflector } from '@nestjs/core'
import { UserService } from '../user/user.service'
import { Request } from 'express'
import { User } from '@app/models'
import { PERMISSION_KEYS } from '../public/permission.decorator'

interface CustomReq extends Request {
  user: User
}

@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(private reflector: Reflector, private userSerivce: UserService) {}
  
  async canActivate(ctx: ExecutionContext) {
    const req: CustomReq = ctx.switchToHttp().getRequest()
    
    // 获取所需权限
    const requiredPermission = this.reflector.getAllAndOverride<string[]>(
      PERMISSION_KEYS,
      [ctx.getClass(), ctx.getHandler()]
    )
    
    if (!requiredPermission || requiredPermission.length === 0) {
      return true
    }
    
    // 获取用户权限
    const [, token] = (req.headers.authorization ?? '').split(' ') ?? ['', '']
    const permissionNames = await this.userSerivce.getUserPermission(
      token,
      req.user
    )
    
    // 检查超级权限
    if (permissionNames.includes('*')) {
      return true
    }
    
    // 检查所需权限
    const isContainedPermission = requiredPermission.every((item) =>
      permissionNames.includes(item)
    )
    
    if (!isContainedPermission) {
      throw new HttpException(
        `需要权限: ${requiredPermission.join(',')}`,
        HttpStatus.FORBIDDEN
      )
    }
    
    return true
  }
}
```

**控制器使用示例**：
```typescript
// src/user/user.controller.ts
@Controller('user')
@UseGuards(PermissionGuard)
export class UserController {
  @Post()
  @Permission('user:create')  // 需要 user:create 权限
  create(@Body() createUserDto: CreateUserDto) {
    return this.userService.create(createUserDto)
  }

  @Patch()
  @Permission('user:edit')  // 需要 user:edit 权限
  update(@Body() updateUserDto: UpdateUserDto) {
    return this.userService.updateUser(updateUserDto)
  }

  @Delete('/:id')
  @Permission('user:delete')  // 需要 user:delete 权限
  remove(@Param('id') id: number) {
    return this.userService.deleteUser(id)
  }

  @Get()
  @Permission('user:query')  // 需要 user:query 权限
  findAll(
    @Query('page', new DefaultValuePipe('1'), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe('10'), ParseIntPipe) limit: number,
  ) {
    return this.userService.getAllUser({ page, limit })
  }
}
```

#### 6.4.3 权限检查流程对比

| 检查步骤 | 仓颉实现 | NestJS实现 |
|---------|---------|-----------|
| 获取用户ID | `req.getLocals("userId")` | `req.user.id` |
| 获取用户角色 | `userHasRolesService.findByUserId()` | `user.role` |
| 获取角色权限 | `roleHasPermissionService.findByRoleIds()` | `role.permission` |
| 检查通配符 | `hasWildcardPermission()` | `permissionNames.includes('*')` |
| 检查精确权限 | `hasRoutePermission()` | `requiredPermission.every()` |
| 无权限响应 | `res.status(403).json()` | `throw HttpException(403)` |

#### 6.4.4 权限数据获取流程

**仓颉实现**：
```cangjie
// 获取用户角色和权限
public func getUserRolesAndPermissions(userId: String): (ArrayList<String>, ArrayList<String>) {
    let roles = ArrayList<String>()
    let permissions = ArrayList<String>()
    
    // 1. 获取用户的角色关联
    let userRoles = userHasRolesService.findByUserId(userId)
    
    // 2. 获取角色ID列表
    let roleIds = ArrayList<String>()
    for (userRole in userRoles) {
        roleIds.add(userRole.roleId)
    }
    
    // 3. 获取角色详情
    for (roleId in roleIds) {
        let roleResult = uctooRoleService.getById(roleId)
        if (roleResult.success) {
            if (let Some(role) <- roleResult.data) {
                roles.add(role.name)
            }
        }
    }
    
    // 4. 获取角色的权限
    let rolePermissions = roleHasPermissionService.findByRoleIds(roleIds)
    
    // 5. 获取权限名称列表（去重）
    let permissionSet = HashSet<String>()
    for (rolePermission in rolePermissions) {
        permissionSet.add(rolePermission.permissionName)
    }
    
    for (permissionName in permissionSet) {
        permissions.add(permissionName)
    }
    
    (roles, permissions)
}
```

**NestJS实现**：
```typescript
// 获取用户权限
async getUserPermission(token: string, userInfo: User) {
  const { email } = userInfo
  const { role } = (await this.getUserInfo(email, [
    'role',
    'role.permission',
  ])) ?? { role: [] as Role[] }
  
  // 扁平化权限列表
  const permission = role.flatMap((r) => r.permission)
  const permissionNames = permission.map((p) => p.name)
  
  // 去重
  return [...new Set([...permissionNames])]
}
```

### 7.1 为什么菜单只显示顶级菜单？

**原因**：用户只有顶级菜单的权限，没有子菜单的权限。

**解决方案**：
1. 使用通配符权限 `menu:*` 分配所有菜单权限
2. 或者为角色分配具体的子菜单权限

### 7.2 如何实现数据权限？

uctoo v4 支持行级数据权限：

1. 所有数据表包含 `creator` 字段，记录数据创建者
2. 通过 `data_access_authorization` 表配置数据授权规则
3. 在查询时自动过滤无权限的数据行

#### 7.2.1 creator 字段设计规范

**字段定义**：
- **类型**：`uuid`
- **可空性**：**可空（NULL）**
- **语义**：
  - `NULL`：系统数据或公共数据，所有用户可见
  - `非NULL`：用户私有数据，仅创建者可见（或根据权限配置）

**统一为可空的原因**：

1. **业务场景需要**：
   - 系统初始化数据可能没有创建者（如系统默认数据）
   - 批量导入数据时可能无法确定创建者
   - 某些自动化任务创建的数据可能没有用户上下文
   - 匿名用户创建的数据（如公开表单提交）

2. **代码实现已考虑可空情况**：
   - Service 模板中有 `isEmpty()` 检查
   - 多处使用 `Option<String>` 类型
   - Controller 中有处理 `None` 的逻辑

3. **数据迁移和兼容性**：
   - 避免为所有现有数据填充 creator 值
   - 保护历史数据的完整性
   - 降低数据迁移的复杂度

4. **权限检查的灵活性**：
   - 可空 creator 可以区分"系统数据"和"用户数据"
   - 便于实现"公共数据"（creator 为空）和"私有数据"（creator 有值）的权限控制

**权限检查逻辑**：

```sql
-- 用户可见数据：自己创建的 + 公共数据
SELECT * FROM table_name
WHERE creator IS NULL OR creator = :currentUserId;

-- 仅查看自己的数据
SELECT * FROM table_name
WHERE creator = :currentUserId;

-- 仅查看公共数据
SELECT * FROM table_name
WHERE creator IS NULL;
```

**当前实现状态**：
- 数据库中 153 个表包含 creator 字段
- 其中 152 个表定义为可空：`"creator" uuid`
- 1 个表（entity）定义为不可空：`"creator" uuid NOT NULL`
- **建议**：将 entity 表的 creator 字段改为可空，实现完全统一

**修改建议**：

```sql
-- 统一 entity 表的 creator 字段为可空
ALTER TABLE entity ALTER COLUMN creator DROP NOT NULL;
```

### 7.3 如何实现权限继承？

uctoo v4 不支持角色继承，但可以通过以下方式实现类似效果：

1. 创建基础角色，分配公共权限
2. 创建派生角色，分配额外权限
3. 用户可以拥有多个角色，权限自动合并

## 8. 迁移指南

### 8.1 从 v3 迁移到 v4

**数据迁移**：
```sql
-- 1. 迁移用户组到角色
INSERT INTO uctoo_role (id, role_name, description)
SELECT id, group_name, description FROM user_group;

-- 2. 迁移用户-组关联到用户-角色关联
INSERT INTO user_has_roles (user_id, role_id, status)
SELECT user_id, group_id, status FROM user_has_group;

-- 3. 迁移组-权限关联到角色-权限关联
INSERT INTO role_has_permission (role_id, permission_name, status)
SELECT group_id, permission_name, status FROM group_has_permission;
```

**代码迁移**：
- 将 `user_group` 相关代码改为 `uctoo_role`
- 将 `group_has_permission` 改为 `role_has_permission`
- 将 `user_has_group` 改为 `user_has_roles`
- 更新权限检查逻辑，支持通配符权限

## 9. 参考资料

- [RBAC 标准规范](https://en.wikipedia.org/wiki/Role-based_access_control)
- [uctoo v3 权限文档](../backend/docs/user-permission-system.md)
- [PostgreSQL Row Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
