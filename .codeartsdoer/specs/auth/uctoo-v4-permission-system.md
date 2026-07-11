# UCToo V4 权限体系完整设计方案

**文档版本**: 1.0.0  
**创建日期**: 2026-03-24  
**基于**: UCToo Backend V3 权限体系 + agentskills-runtime 现状分析  
**目标**: 设计完整的V4权限体系,修复当前权限问题

---

## 一、V3权限体系回顾与调研结果

### 1.1 V3实际实现架构

**V3采用的权限模型** (基于代码调研):
```
用户(uctoo_user)
  ↓ N:M (user_has_group)
用户组(user_group)
  ↓ N:M (group_has_permission)
权限节点(permissions)
```

**关键发现**:
- ❌ **未实现标准RBAC**: V3直接使用用户组关联权限,跳过了角色层
- ✅ **角色表已预留**: `uctoo_role`和`user_has_roles`表存在但未使用
- ✅ **功能完整**: 虽然简化了模型,但权限控制功能完整可用
- ⚠️ **用户组承担角色功能**: 用户组实际上替代了RBAC中的角色

### 1.2 V3关键表结构

**核心表**:
- `uctoo_user` - 用户表
- `user_group` - 用户组表(支持树形结构,承担角色功能)
- `permissions` - 权限节点表(菜单/按钮/接口)
- `user_has_group` - 用户-组关联表(支持多态关联)
- `group_has_permission` - 组-权限关联表(复合主键)
- `uctoo_session` - 会话表

**预留但未使用的表**:
- `uctoo_role` - 角色表(已定义,代码中未使用)
- `user_has_roles` - 用户-角色关联表(已定义,代码中未使用)

**数据权限表**:
- `data_access_authorization` - 行级数据权限控制表

### 1.3 V3权限检查流程

**中间件链**:
```
请求 → deserializeUser → requireUser → [rowLevelPermission] → 业务处理
         (Token解析)      (权限检查)      (行级权限,可选)
```

**权限检查逻辑** (requireUser.ts):
1. 从`res.locals.id`获取用户信息
2. 查询用户所属的所有用户组(`user_has_group`)
3. 检查用户组是否有全部权限(`permission_name = '/*'`)
4. 如果没有全部权限,检查用户组是否有当前路由权限
5. 返回权限检查结果

**关键代码**:
```typescript
const checkUserPermission = async (req, res, id) => {
  const user = res.locals.id.user;
  const reqRoute = req.route.pattern;

  // 1. 查询用户所属用户组
  const uctooUserGroup = await db.user_has_group.findMany({
    where: { groupable_id: user },
    select: { group_id: true }
  });
  const userGroupIds = uctooUserGroup.map(uug => uug.group_id);

  // 2. 检查全部权限
  const userGroupAllPermissions = await db.group_has_permission.findMany({
    where: {
      group_id: { in: userGroupIds },
      permission_name: '/*'
    }
  });
  if(Object.keys(userGroupAllPermissions).length !== 0) return true;

  // 3. 检查路由权限
  const userGroupPermissions = await db.group_has_permission.findMany({
    where: {
      group_id: { in: userGroupIds },
      permission_name: reqRoute
    }
  });

  return Object.keys(userGroupPermissions).length !== 0;
}
```

### 1.2 权限类型

| 类型 | type值 | 说明 |
|------|--------|------|
| 菜单权限 | 1 | 前端菜单项显示控制 |
| 按钮权限 | 2 | 页面按钮级操作控制 |
| 接口权限 | 3 | 后端API路由访问控制 |

### 1.3 权限检查机制

**中间件链**:
```
DeserializeUserMiddleware  →  RequireUserMiddleware  →  RequirePermissionMiddleware
     (Token解析)                  (用户认证)                (权限检查)
```

**权限检查逻辑**:
1. 检查通配符权限 `/*` (全部权限)
2. 检查具体路由权限 (精确匹配)
3. 检查HTTP方法 (GET/POST/PUT/DELETE)

### 1.4 行级数据权限

**机制**: 通过 `data_access_authorization` 表控制
- 权限级别: READ(1) / WRITE(2) / AUTHORIZE(3)
- 数据归属: `creator` 字段标识数据所有者
- 授权访问: 支持将数据授权给其他用户

---

## 二、V4权限体系设计 - 标准RBAC实现

### 2.1 设计目标

**核心目标**: 实现标准RBAC(基于角色的访问控制)权限体系

**与V3的主要区别**:
| 维度 | V3实现 | V4设计 |
|------|--------|--------|
| 权限模型 | 用户→用户组→权限 | 用户→角色→权限 |
| 角色使用 | ❌ 未使用 | ✅ 核心概念 |
| 用户组作用 | 承担角色功能 | 仅用于分组 |
| 权限继承 | ❌ 不支持 | ✅ 支持角色继承 |
| 权限缓存 | ❌ 无 | ✅ Redis缓存 |
| 数据兼容 | - | ✅ 兼容V3数据 |

### 2.2 设计原则

1. **标准RBAC**: 严格遵循RBAC模型,用户-角色-权限三层结构
2. **安全优先**: 默认无权限,显式授权
3. **最小权限**: 只授予必要的权限
4. **职责分离**: 认证与授权分离,用户组与角色分离
5. **细粒度控制**: 支持菜单/按钮/接口/数据四级权限
6. **可扩展性**: 支持动态权限配置和角色继承
7. **性能优化**: 权限缓存机制,减少数据库查询
8. **数据兼容**: 兼容V3数据库结构,平滑迁移

### 2.3 V4数据库设计

#### 2.3.1 核心表结构(兼容V3)

**permissions表结构** (沿用V3,完全兼容):

```sql
-- 权限表 (完全兼容V3结构)
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 权限唯一标识 (V3核心字段)
    permission_name VARCHAR NOT NULL UNIQUE,  
    -- 命名规则:
    -- type=1(菜单): 
    --   - 数据库菜单: database.{数据库名}.{表名} (如: database.uctoo.entity)
    --   - 普通菜单: 自定义名称 (如: Dashboard, Workspace)
    -- type=2(按钮): button.{模块}.{操作} (如: button.user.create)
    -- type=3(API): 路由路径 (如: /api/v1/uctoo/entity, /*表示全部权限)
    
    -- 权限类型 (V3核心字段)
    type INT DEFAULT 1,
    -- 1: 菜单权限 (前端菜单显示控制)
    -- 2: 按钮权限 (页面按钮级操作控制)
    -- 3: API权限 (后端接口访问控制)
    
    -- 菜单相关字段 (type=1时使用)
    level VARCHAR,                          -- 层级,顶层为'0'
    icon VARCHAR,                           -- 菜单图标
    component VARCHAR,                      -- 前端组件路径 (如: /uctoo/entity/index)
    redirect VARCHAR,                       -- 跳转地址
    path VARCHAR,                           -- 路由路径 (如: /database/uctoo/entity)
    hidden INT DEFAULT 1,                   -- 是否隐藏: 0=隐藏, 1=显示
    keepalive INT DEFAULT 1,                -- 是否缓存: 1=缓存, 2=不缓存
    meta JSONB,                             -- 元数据 (如: {"icon": "mdi:database-sync", "title": "xxx"})
    
    -- API相关字段 (type=3时使用)
    method VARCHAR,                         -- HTTP方法: GET, POST, PUT, DELETE, ANY
    
    -- 通用字段
    title VARCHAR,                          -- 权限标题
    module VARCHAR,                         -- 所属模块
    weight INT DEFAULT 0,                   -- 排序权重
    
    -- 树形结构
    parent_id UUID REFERENCES permissions(id), -- 父权限节点ID
    
    -- 审计字段
    creator UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

-- 创建索引
CREATE INDEX idx_permissions_type ON permissions(type);
CREATE INDEX idx_permissions_permission_name ON permissions(permission_name);
CREATE INDEX idx_permissions_parent_id ON permissions(parent_id);
```

**V3典型权限数据示例**:

```sql
-- 1. 全部权限 (type=3, API权限)
INSERT INTO permissions (id, permission_name, type, path, method, parent_id) VALUES
('xxx-xxx-xxx', '/*', 3, '/*', 'ANY', 'api-root-id');

-- 2. 数据库菜单权限 (type=1, 菜单权限)
INSERT INTO permissions (id, permission_name, type, level, component, path, parent_id, meta, weight) VALUES
('xxx-xxx-xxx', 'database.uctoo.entity', 1, '2', '/uctoo/entity/index', '/database/uctoo/entity', 'database-uctoo-id', 
 '{"icon": "mdi:database-sync", "title": "database.uctoo.entity"}', 10);

-- 3. 普通菜单权限 (type=1, 菜单权限)
INSERT INTO permissions (id, permission_name, type, level, component, path, title, parent_id, meta, weight) VALUES
('xxx-xxx-xxx', 'Dashboard', 1, '0', 'BasicLayout', '/', 'page.dashboard.title', NULL, 
 '{"order": -1, "title": "page.dashboard.title"}', 0);

-- 4. API接口权限 (type=3, API权限)
INSERT INTO permissions (id, permission_name, type, path, method, parent_id) VALUES
('xxx-xxx-xxx', '/api/v1/uctoo/entity', 3, '/api/v1/uctoo/entity', 'GET', 'api-root-id');

-- 5. 按钮权限 (type=2, 按钮权限)
INSERT INTO permissions (id, permission_name, type, title, parent_id) VALUES
('xxx-xxx-xxx', 'button.entity.create', 2, '创建实体', 'database.uctoo.entity');
```

**标准RBAC表** (新增,启用V3预留表):

```sql
-- 1. 用户表 (沿用V3)
CREATE TABLE uctoo_user (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR UNIQUE NOT NULL,
    email VARCHAR UNIQUE NOT NULL,
    password VARCHAR NOT NULL,
    name VARCHAR,
    avatar VARCHAR,
    access_token VARCHAR,                   -- 当前有效的access_token
    auth_provider INT DEFAULT 0,            -- 认证提供者
    last_login_time TIMESTAMPTZ,
    last_login_ip VARCHAR,
    status INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

-- 2. 角色表 (启用V3预留表,新增字段)
CREATE TABLE uctoo_role (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR UNIQUE NOT NULL,           -- 角色唯一标识 (如: admin, user, guest)
    title VARCHAR NOT NULL,                 -- 角色显示名称 (如: 管理员, 普通用户, 访客)
    code VARCHAR UNIQUE,                    -- 角色编码 (兼容V3用户组code)
    description VARCHAR,                    -- 角色描述
    parent_id UUID REFERENCES uctoo_role(id), -- 支持角色继承
    level INT DEFAULT 0,                    -- 角色层级
    status INT DEFAULT 1,                   -- 状态: 1=启用, 0=禁用
    weight INT DEFAULT 0,                   -- 排序权重
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

-- 3. 用户-角色关联表 (启用V3预留表)
CREATE TABLE user_has_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES uctoo_user(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES uctoo_role(id) ON DELETE CASCADE,
    status INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, role_id)
);

-- 4. 角色-权限关联表 (新增,替代group_has_permission)
CREATE TABLE role_has_permission (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES uctoo_role(id) ON DELETE CASCADE,
    permission_name VARCHAR NOT NULL,       -- 直接使用permission_name关联(V3兼容)
    status INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, permission_name)
);

-- 创建索引
CREATE INDEX idx_user_has_roles_user_id ON user_has_roles(user_id);
CREATE INDEX idx_user_has_roles_role_id ON user_has_roles(role_id);
CREATE INDEX idx_role_has_permission_role_id ON role_has_permission(role_id);
CREATE INDEX idx_role_has_permission_permission_name ON role_has_permission(permission_name);
```

**用户组表** (重新定位,仅用于分组):

```sql
-- 用户组表 (不再关联权限,仅用于用户分组)
CREATE TABLE user_group (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    code VARCHAR UNIQUE,                    -- 组编码
    description VARCHAR,
    parent_id UUID REFERENCES user_group(id),
    status INT DEFAULT 1,
    weight INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);

-- 用户-组关联表 (仅用于分组,支持多态关联)
CREATE TABLE user_has_group (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    groupable_id UUID NOT NULL,             -- 用户ID (支持多种用户类型)
    groupable_type VARCHAR,                 -- 用户类型 (如: uctoo_user, wechatopen_users)
    group_id UUID NOT NULL REFERENCES user_group(id) ON DELETE CASCADE,
    status INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(groupable_id, group_id, groupable_type)
);
```

**会话和数据权限表** (沿用V3):

```sql
-- 会话表 (沿用V3)
CREATE TABLE uctoo_session (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES uctoo_user(id),
    valid BOOLEAN DEFAULT true,
    user_agent VARCHAR,
    ip VARCHAR,
    auth_provider INT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 行级数据权限表 (沿用V3)
CREATE TABLE data_access_authorization (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL,       -- 实体类型
    entity_id VARCHAR NOT NULL,             -- 实体ID
    user_id UUID NOT NULL REFERENCES uctoo_user(id),
    permission INT NOT NULL,                -- 权限级别: 1=读, 2=写, 3=授权
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
```

#### 2.3.2 数据迁移策略(V3→V4)

**迁移原则**:
1. ✅ 完全兼容V3的permissions表结构和数据
2. ✅ 将V3的user_group转换为V4的uctoo_role
3. ✅ 将V3的group_has_permission转换为role_has_permission
4. ✅ 保留user_group表用于用户分组(不再关联权限)

**迁移SQL脚本**:

```sql
-- ========== V3到V4迁移脚本 ==========

-- 步骤1: 将V3的用户组转换为角色
-- 注意: 只转换有code字段的用户组,这些是V3中实际用于权限控制的组
INSERT INTO uctoo_role (id, name, title, code, description, parent_id, level, status, weight, created_at, updated_at)
SELECT 
    id,
    LOWER(REPLACE(code, ' ', '_')) AS name,    -- 转换为角色标识(小写,下划线)
    name AS title,                              -- 使用组名作为角色标题
    code,                                        -- 保留原code
    description,
    NULL AS parent_id,                          -- V3用户组不支持继承,设为NULL
    0 AS level,
    status,
    weight,
    created_at,
    updated_at
FROM user_group
WHERE code IS NOT NULL
ON CONFLICT (name) DO NOTHING;

-- 步骤2: 迁移用户-角色关联
-- 将V3的user_has_group数据迁移到user_has_roles
INSERT INTO user_has_roles (user_id, role_id, status, created_at)
SELECT 
    groupable_id AS user_id,
    group_id AS role_id,
    status,
    created_at
FROM user_has_group
WHERE groupable_type = 'uctoo_user'
  AND group_id IN (SELECT id FROM uctoo_role)  -- 只迁移已转换为角色的组
ON CONFLICT (user_id, role_id) DO NOTHING;

-- 步骤3: 迁移角色-权限关联
-- 将V3的group_has_permission转换为role_has_permission
INSERT INTO role_has_permission (role_id, permission_name, status, created_at)
SELECT 
    group_id AS role_id,
    permission_name,
    status,
! created_at
FROM group_has_permission
WHERE group_id IN (SELECT id FROM uctoo_role)  -- 只迁移已转换为角色的组
ON CONFLICT (role_id, permission_name) DO NOTHING;

-- 步骤4: 创建默认角色(如果不存在)
-- 访客角色
INSERT INTO uctoo_role (id, name, title, code, description, status, weight)
VALUES (
    gen_random_uuid(),
    'guest',
    '访客',
    'guest',
    '访客用户,默认无权限',
    1,
    0
) ON CONFLICT (name) DO NOTHING;

-- 普通用户角色
INSERT INTO uctoo_role (id, name, title, code, description, status, weight)
VALUES (
    gen_random_uuid(),
    'user',
    '普通用户',
    'user',
    '普通用户,基础权限',
    1,
    10
) ON CONFLICT (name) DO NOTHING;

-- 管理员角色
INSERT INTO uctoo_role (id, name, title, code, description, status, weight)
VALUES (
    gen_random_uuid(),
    'admin',
    '管理员',
    'admin',
    '管理员,管理权限',
    1,
    20
) ON CONFLICT (name) DO NOTHING;

-- 超级管理员角色
INSERT INTO uctoo_role (id, name, title, code, description, status, weight)
VALUES (
    gen_random_uuid(),
    'super_admin',
    '超级管理员',
    'super_admin',
    '超级管理员,全部权限',
    1,
    30
) ON CONFLICT (name) DO NOTHING;

-- 步骤5: 为超级管理员角色分配全部权限
INSERT INTO role_has_permission (role_id, permission_name, status)
SELECT 
    r.id AS role_id,
    '/*' AS permission_name,
    1 AS status
FROM uctoo_role r
WHERE r.name = 'super_admin'
ON CONFLICT (role_id, permission_name) DO NOTHING;

-- 步骤6: 清理V3的权限关联表(可选,建议保留用于回滚)
-- TRUNCATE TABLE group_has_permission CASCADE;

-- ========== 迁移验证查询 ==========

-- 验证角色迁移
SELECT 
    'V3用户组数量' AS item,
    COUNT(*) AS count
FROM user_group
WHERE code IS NOT NULL

UNION ALL

SELECT 
    'V4角色数量' AS item,
    COUNT(*) AS count
FROM uctoo_role;

-- 验证用户-角色关联迁移
SELECT 
    'V3用户-组关联数量' AS item,
    COUNT(*) AS count
FROM user_has_group
WHERE groupable_type = 'uctoo_user'

UNION ALL

SELECT 
    'V4用户-角色关联数量' AS item,
    COUNT(*) AS count
FROM user_has_roles;

-- 验证角色-权限关联迁移
SELECT 
    'V3组-权限关联数量' AS item,
    COUNT(*) AS count
FROM group_has_permission

UNION ALL

SELECT 
    'V4角色-权限关联数量' AS item,
    COUNT(*) AS count
FROM role_has_permission;
```

**迁移后数据验证**:

```sql
-- 1. 检查权限数据完整性
SELECT 
    p.type,
    CASE p.type
        WHEN 1 THEN '菜单权限'
        WHEN 2 THEN '按钮权限'
        WHEN 3 THEN 'API权限'
        ELSE '未知'
    END AS type_name,
    COUNT(*) AS count
FROM permissions p
GROUP BY p.type
ORDER BY p.type;

-- 2. 检查用户权限分配情况
SELECT 
    u.username,
    r.name AS role_name,
    r.title AS role_title,
    COUNT(rhp.permission_name) AS permission_count
FROM uctoo_user u
LEFT JOIN user_has_roles uhr ON u.id = uhr.user_id
LEFT JOIN uctoo_role r ON uhr.role_id = r.id
LEFT JOIN role_has_permission rhp ON r.id = rhp.role_id
GROUP BY u.username, r.name, r.title
ORDER BY u.username;

-- 3. 检查API权限覆盖情况
SELECT 
    p.permission_name,
    p.method,
    COUNT(rhp.role_id) AS role_count
FROM permissions p
LEFT JOIN role_has_permission rhp ON p.permission_name = rhp.permission_name
WHERE p.type = 3  -- API权限
GROUP BY p.permission_name, p.method
HAVING COUNT(rhp.role_id) = 0  -- 未分配给任何角色的API权限
ORDER BY p.permission_name;
```

### 2.4 V4权限检查实现

#### 2.4.1 权限检查中间件

**RequirePermissionMiddleware.cj**:

```cangjie
public class RequirePermissionMiddleware {
    private let permissionService: PermissionService
    private let cacheService: CacheService
    
    public func intercept(context: HttpContext, next: () -> Unit): Unit {
        // 1. 获取用户ID
        let userId = context.getUser()?.id ?? return context.abort(401, "未登录")
        
        // 2. 获取所需权限
        let requiredPermission = context.getRequiredPermission()
        
        // 3. 检查权限(带缓存)
        let hasPermission = checkPermissionWithCache(userId, requiredPermission)
        
        if (!hasPermission) {
            return context.abort(403, "无权限访问")
        }
        
        next()
    }
    
    private func checkPermissionWithCache(userId: String, permission: String): Bool {
        // 1. 尝试从缓存获取
        let cacheKey = "user:${userId}:permissions"
        let cachedPermissions = cacheService.get<Array<String>>(cacheKey)
        
        if (cachedPermissions != null) {
            return matchPermission(cachedPermissions, permission)
        }
        
        // 2. 从数据库查询
        let permissions = getUserPermissions(userId)
        
        // 3. 写入缓存(TTL: 5分钟)
        cacheService.set(cacheKey, permissions, 300)
        
        return matchPermission(permissions, permission)
    }
    
    private func getUserPermissions(userId: String): Array<String> {
        // 查询用户的所有权限(通过角色)
        let roles = db.user_has_roles.findMany({
            where: { user_id: userId },
            select: { role_id: true }
        })
        
        let roleIds = roles.map({ r => r.role_id })
        
        // 查询角色的所有权限
        let permissions = db.role_has_permission.findMany({
            where: { role_id: { in: roleIds } },
            select: { 
                permission: { 
                    select: { permission_name: true } 
                } 
            }
        })
        
        return permissions.map({ p => p.permission.permission_name })
    }
    
    private func matchPermission(permissions: Array<String>, required: String): Bool {
        // 1. 检查通配符权限
        if (permissions.contains("/*")) {
            return true
        }
        
        // 2. 检查模块通配符
        let module = required.split(":")[0]
        if (permissions.contains("${module}:*")) {
            return true
        }
        
        // 3. 检查资源通配符
        let parts = required.split(":")
        if (parts.size() >= 2) {
            let resourceWildcard = "${parts[0]}:${parts[1]}:*"
            if (permissions.contains(resourceWildcard)) {
                return true
            }
        }
        
        // 4. 精确匹配
        return permissions.contains(required)
    }
}
```

```
┌─────────────────────────────────────────────────────────┐
│                     应用层权限                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ 菜单权限 │  │ 按钮权限 │  │ 接口权限 │            │
│  └──────────┘  └──────────┘  └──────────┘            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│                     数据层权限                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ 表级权限 │  │ 行级权限 │  │ 字段权限 │            │
│  └──────────┘  └──────────┘  └──────────┘            │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│                     操作层权限                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐│
│  │  CREATE  │  │  READ    │  │  UPDATE  │  │ DELETE ││
│  └──────────┘  └──────────┘  └──────────┘  └────────┘│
└─────────────────────────────────────────────────────────┘
```

### 2.3 权限节点设计

#### 2.3.1 权限节点命名规范(兼容V3)

**permission_name字段命名规则** (基于V3数据库设计和实际数据):

**1. API权限 (type=3)**

**格式**: 路由路径

**规则**:
- 直接使用API路由路径作为permission_name
- 支持路由参数(如`:id`, `:limit`, `:page`等)
- 支持通配符`/*`表示全部权限

**示例**:
```
/*                              # 全部权限(超级管理员)
/api/v1/uctoo/entity            # 实体API
/api/v1/uctoo/entity/:id        # 单个实体API
/api/v1/uctoo/entity/:limit/:page  # 分页查询API
/api/v1/uctoo/user/signin       # 用户登录API
/api/v1/skills/install          # 技能安装API
/api/v1/mcp/stream              # MCP流式接口
```

**HTTP方法字段** (method):
- `GET` - 查询操作
- `POST` - 创建操作
- `PUT` - 更新操作
- `DELETE` - 删除操作
- `ANY` - 所有方法(用于通配符权限)

**2. 菜单权限 (type=1)**

**2.1 数据库菜单**

**格式**: `database.{数据库名}.{表名}`

**规则**:
- 用于数据库表的管理菜单
- 数据库名通常为`uctoo`
- 表名为实际的数据库表名

**示例**:
```
database.uctoo.entity           # 实体管理菜单
database.uctoo.uctoo_user       # 用户管理菜单
database.uctoo.uctoo_session    # 会话管理菜单
database.uctoo.user_group       # 用户组管理菜单
database.uctoo.permissions      # 权限管理菜单
database.uctoo.agent_skills     # 技能管理菜单
```

**2.2 普通菜单**

**格式**: 自定义名称(建议使用大驼峰命名)

**规则**:
- 用于非数据库表的功能菜单
- 如Dashboard、Workspace等
- V4建议统一使用`menu.`前缀,便于区分

**示例**:
```
Dashboard                       # 仪表板(V3格式)
Workspace                       # 工作台(V3格式)
menu.dashboard                  # 仪表板(V4建议格式)
menu.workspace                  # 工作台(V4建议格式)
menu.settings                   # 设置菜单(V4建议格式)
menu.profile                    # 个人中心(V4建议格式)
```

**3. 按钮权限 (type=2)**

**格式**: `button.{模块}.{操作}` 或 `button.{菜单}.{操作}`

**规则**:
- 用于页面按钮级别的权限控制
- V3中暂无规律,V4建议统一使用`button.`前缀
- 操作名称使用英文小写

**示例**:
```
button.entity.create            # 创建实体按钮
button.entity.edit              # 编辑实体按钮
button.entity.delete            # 删除实体按钮
button.user.create              # 创建用户按钮
button.user.edit                # 编辑用户按钮
button.user.delete              # 删除用户按钮
button.permission.assign        # 分配权限按钮
button.role.create              # 创建角色按钮
```

**4. 权限节点命名总结**

| 权限类型 | type值 | permission_name格式 | 示例 | 说明 |
|---------|--------|---------------------|------|------|
| API权限 | 3 | 路由路径 | `/api/v1/uctoo/entity` | 后端接口访问控制 |
| 数据库菜单 | 1 | `database.{db}.{table}` | `database.uctoo.entity` | 数据库表管理菜单 |
| 普通菜单 | 1 | 自定义名称 | `Dashboard` 或 `menu.dashboard` | 功能菜单 |
| 按钮权限 | 2 | `button.{module}.{action}` | `button.entity.create` | 页面按钮控制 |

#### 2.3.2 权限节点分类

**按模块分类**:

| 模块 | 权限前缀 | permission_name示例 | 说明 |
|------|---------|---------------------|------|
| 用户管理 | `database.uctoo.uctoo_user` | `/api/v1/uctoo/user` | 用户CRUD操作 |
| 实体管理 | `database.uctoo.entity` | `/api/v1/uctoo/entity` | 实体CRUD操作 |
| 会话管理 | `database.uctoo.uctoo_session` | `/api/v1/uctoo/session` | 会话管理 |
| 用户组管理 | `database.uctoo.user_group` | `/api/v1/uctoo/group` | 用户组管理 |
| 角色管理 | `database.uctoo.uctoo_role` | `/api/v1/uctoo/role` | 角色管理 |
| 权限管理 | `database.uctoo.permissions` | `/api/v1/uctoo/permission` | 权限配置 |
| 技能管理 | `database.uctoo.agent_skills` | `/api/v1/skills` | 技能安装/执行 |
| MCP接口 | - | `/api/v1/mcp/stream` | MCP流式接口 |

**按操作分类** (API权限):

| 操作 | HTTP方法 | 路由示例 | 说明 |
|------|---------|---------|------|
| 创建 | POST | `/api/v1/uctoo/entity` | 新增数据 |
| 批量创建 | POST | `/api/v1/uctoo/entity/batch` | 批量新增 |
| 查询列表 | GET | `/api/v1/uctoo/entity/:limit/:page` | 分页查询 |
| 查询详情 | GET | `/api/v1/uctoo/entity/:id` | 单条查询 |
| 更新 | PUT | `/api/v1/uctoo/entity/:id` | 修改数据 |
| 删除 | DELETE | `/api/v1/uctoo/entity/:id` | 删除数据 |
| 全部权限 | ANY | `/*` | 所有操作 |

**按操作分类** (按钮权限):

| 操作 | 权限格式 | 示例 | 说明 |
|------|---------|------|------|
| 创建 | `button.{module}.create` | `button.entity.create` | 创建按钮 |
| 编辑 | `button.{module}.edit` | `button.entity.edit` | 编辑按钮 |
| 删除 | `button.{module}.delete` | `button.entity.delete` | 删除按钮 |
| 查看 | `button.{module}.view` | `button.entity.view` | 查看按钮 |
| 导出 | `button.{module}.export` | `button.entity.export` | 导出按钮 |
| 导入 | `button.{module}.import` | `button.entity.import` | 导入按钮 |

### 2.4 中间件设计

#### 2.4.1 标准中间件链

```cangjie
// 公开接口 - 无需认证
PublicRoute: 
  → Controller

// 需要认证的接口 - 基硈权限
ProtectedRoute:
  → DeserializeUserMiddleware    // Token解析
  → RequireUserMiddleware        // 用户认证
  → Controller

// 需要特定权限的接口 - 细粒度权限
PermissionRequiredRoute:
  → DeserializeUserMiddleware    // Token解析
  → RequireUserMiddleware        // 用户认证
  → RequirePermissionMiddleware  // 权限检查
  → RowLevelPermissionMiddleware // 行级权限(可选)
  → Controller
```

#### 2.4.2 权限检查中间件增强

**RequirePermissionMiddleware V4**:

```cangjie
public class RequirePermissionMiddleware {
    // 权限检查策略
    public func checkPermission(
        context: HttpContext,
        requiredPermission: String
    ): Bool {
        // 1. 获取用户ID
        let userId = context.getUser()?.id ?? return false
        
        // 2. 检查缓存
        let cachedPermissions = permissionCache.get(userId)
        if (cachedPermissions != null) {
            return checkInCache(cachedPermissions, requiredPermission)
        }
        
        // 3. 查询数据库
        let permissions = getUserPermissions(userId)
        
        // 4. 缓存权限
        permissionCache.set(userId, permissions, TTL: 300)
        
        // 5. 检查权限
        return checkPermissionLogic(permissions, requiredPermission)
    }
    
    // 权限匹配逻辑
    private func checkPermissionLogic(
        permissions: Array<String>,
        required: String
    ): Bool {
        // 1. 检查通配符权限
        if (permissions.contains("/*")) {
            return true
        }
        
        // 2. 检查模块通配符
        let module = required.split(":")[0]
        if (permissions.contains("${module}:*")) {
            return true
        }
        
        // 3. 检查资源通配符
        let resource = required.split(":")[0] + ":" + required.split(":")[1]
        if (permissions.contains("${resource}:*")) {
            return true
        }
        
        // 4. 检查管理权限
        let managePerm = required.split(":")[0] + ":" + 
                        required.split(":")[1] + ":manage"
        if (permissions.contains(managePerm)) {
            return true
        }
        
        // 5. 精确匹配
        return permissions.contains(required)
    }
}
```

### 2.5 行级权限增强

#### 2.5.1 数据访问控制

**权限级别**:
```cangjie
public enum PermissionLevel {
    | NONE(0)       // 无权限
    | READ(1)       // 只读
    | WRITE(2)      // 可读写
    | AUTHORIZE(3)  // 可授权
    | ADMIN(4)      // 完全控制
}
```

**数据过滤逻辑**:
```cangjie
public class RowLevelPermissionMiddleware {
    public func filterData(
        context: HttpContext,
        query: QueryBuilder,
        resource: String
    ): QueryBuilder {
        let user = context.getUser() ?? return query.where("1 = 0") // 无权限
        
        // 1. 管理员跳过过滤
        if (user.hasPermission("${resource}:admin")) {
            return query
        }
        
        // 2. 数据归属过滤
        query.where("creator = ?", user.id)
        
        // 3. 授权访问过滤
        let authorizedData = getAuthorizedData(user.id, resource)
        if (authorizedData.isNotEmpty()) {
            query.orWhere("id IN (?)", authorizedData)
        }
        
        return query
    }
}
```

### 2.6 权限缓存设计

#### 2.6.1 缓存策略

```cangjie
public class PermissionCache {
    // 缓存结构
    // Key: user_id
    // Value: PermissionCacheEntry
    // TTL: 300秒(5分钟)
    
    public class PermissionCacheEntry {
        let permissions: HashSet<String>    // 权限集合
        let groups: Array<String>           // 用户组
        let expireTime: DateTime            // 过期时间
    }
    
    // 缓存失效策略
    public func invalidate(userId: String) {
        cache.remove(userId)
    }
    
    public func invalidateByGroup(groupId: String) {
        // 查找该组下所有用户
        let users = getUsersByGroup(groupId)
        // 批量失效
        users.forEach({ user => cache.remove(user.id) })
    }
}
```

---

## 三、权限配置方案

### 3.1 默认权限节点

#### 3.1.1 系统内置权限(兼容V3)

**API权限自动生成机制**:
- type=3的API权限节点通过读取main中注册的路由批量添加和维护
- 保持与系统实际API功能一致
- 自动扫描路由注册表,生成对应的权限节点

**权限生成工具**:

```cangjie
// 自动生成API权限节点
public class PermissionGenerator {
    public func generateAPIPermissions(router: Router): Unit {
        let routes = router.getRoutes()
        
        for (route in routes) {
            // 跳过公开路由
            if (isPublicRoute(route.path)) {
                continue
            }
            
            // 检查权限节点是否已存在
            let existing = db.permissions.findFirst({
                where: {
                    permission_name: route.path,
                    type: 3
                }
            })
            
            if (existing == null) {
                // 创建新的API权限节点
                db.permissions.create({
                    data: {
                        permission_name: route.path,
                        type: 3,
                        path: route.path,
                        method: route.method,
                        module: extractModule(route.path),
                        title: generateTitle(route.path),
                        parent_id: getAPIRootId()
                    }
                })
            }
        }
    }
}
```

**系统内置权限SQL** (基于V3实际数据):

```sql
-- ========== API权限 (type=3) ==========

-- 全部权限(超级管理员)
INSERT INTO permissions (id, permission_name, type, path, method, parent_id) VALUES
('d547c232-2873-43f6-b947-b27533d2c9cc', '/*', 3, '/*', 'ANY', '386b8b46-de88-4caf-b6e3-11f747c85cc0');

-- 认证相关API
INSERT INTO permissions (permission_name, type, path, method, parent_id) VALUES
('/api/auth/authcheck', 3, '/api/auth/authcheck', 'GET', 'api-root-id'),
('/api/auth/healthcheck', 3, '/api/auth/healthcheck', 'GET', 'api-root-id'),
('/api/auth/me', 3, '/api/auth/me', 'GET', 'api-root-id'),
('/api/auth/logout', 3, '/api/auth/logout', 'GET', 'api-root-id'),
('/api/auth/uctoosignin', 3, '/api/auth/uctoosignin', 'GET', 'api-root-id');

-- OAuth认证API
INSERT INTO permissions (permission_name, type, path, method, parent_id) VALUES
('/api/auth/signin/github', 3, '/api/auth/signin/github', 'GET', 'api-root-id'),
('/api/auth/signin/github/callback', 3, '/api/auth/signin/github/callback', 'GET', 'api-root-id'),
('/api/auth/signin/google', 3, '/api/auth/signin/google', 'GET', 'api-root-id'),
('/api/auth/signin/google/callback', 3, '/api/auth/signin/google/callback', 'GET', 'api-root-id'),
('/api/auth/signin/wechatopen/oauthRedirect', 3, '/api/auth/signin/wechatopen/oauthRedirect', 'GET', 'api-root-id');

-- 实体管理API
INSERT INTO permissions (permission_name, type, path, method, parent_id) VALUES
('/api/v1/uctoo/entity', 3, '/api/v1/uctoo/entity', 'POST', 'api-root-id'),
('/api/v1/uctoo/entity/:id', 3, '/api/v1/uctoo/entity/:id', 'GET', 'api-root-id'),
('/api/v1/uctoo/entity/:limit/:page', 3, '/api/v1/uctoo/entity/:limit/:page', 'GET', 'api-root-id'),
('/api/v1/uctoo/entity/:limit/:page/:skip', 3, '/api/v1/uctoo/entity/:limit/:page/:skip', 'GET', 'api-root-id');

-- 技能管理API
INSERT INTO permissions (permission_name, type, path, method, parent_id) VALUES
('/api/v1/skills/install', 3, '/api/v1/skills/install', 'POST', 'api-root-id'),
('/api/v1/skills/execute', 3, '/api/v1/skills/execute', 'POST', 'api-root-id');

-- MCP接口API
INSERT INTO permissions (permission_name, type, path, method, parent_id) VALUES
('/api/v1/mcp/stream', 3, '/api/v1/mcp/stream', 'GET', 'api-root-id');

-- ========== 菜单权限 (type=1) ==========

-- 仪表板菜单
INSERT INTO permissions (permission_name, type, level, component, path, title, parent_id, meta, weight) VALUES
('Dashboard', 1, '0', 'BasicLayout', '/', 'page.dashboard.title', NULL, '{"order": -1, "title": "page.dashboard.title"}', 0),
('Workspace', 1, NULL, '/dashboard/workspace/index', '/workspace', 'page.dashboard.workspace', 'dashboard-id', '{"title": "page.dashboard.workspace"}', 2),
('Analytics', 1, '1', '/dashboard/analytics/index', '/analytics', NULL, 'dashboard-id', '{"title": "page.dashboard.analytics", "affixTab": true}', 3);

-- 数据库管理菜单
INSERT INTO permissions (permission_name, type, level, component, path, parent_id, meta, weight) VALUES
('Database', 1, '0', 'BasicLayout', '/database', NULL, NULL, '{"icon": "mdi:database-sync", "order": 50}', 50),
('database.uctoo.entity', 1, '2', '/uctoo/entity/index', '/database/uctoo/entity', 'database-uctoo-id', '{"icon": "mdi:database-sync", "title": "database.uctoo.entity"}', 10),
('database.uctoo.uctoo_user', 1, '2', '/uctoo/uctoo_user/index', '/database/uctoo/uctoo_user', 'database-uctoo-id', '{"icon": "mdi:database-sync", "title": "database.uctoo.uctoo_user"}', 20),
('database.uctoo.uctoo_session', 1, '2', '/uctoo/uctoo_session/index', '/database/uctoo/uctoo_session', 'database-uctoo-id', '{"icon": "mdi:database-sync", "title": "database.uctoo.uctoo_session"}', 30),
('database.uctoo.user_group', 1, '2', '/uctoo/user_group/index', '/database/uctoo/user_group', 'database-uctoo-id', '{"icon": "mdi:database-sync", "title": "database.uctoo.user_group"}', 40),
('database.uctoo.uctoo_role', 1, '2', '/uctoo/uctoo_role/index', '/database/uctoo/uctoo_role', 'database-uctoo-id', '{"icon": "mdi:database-sync", "title": "database.uctoo.uctoo_role"}', 50),
('database.uctoo.permissions', 1, '2', '/uctoo/permissions/index', '/database/uctoo/permissions', 'database-uctoo-id', '{"icon": "mdi:database-sync", "title": "database.uctoo.permissions"}', 60),
('database.uctoo.agent_skills', 1, '2', '/uctoo/agent_skills/index', '/database/uctoo/agent_skills', 'database-uctoo-id', '{"icon": "mdi:database-sync", "title": "database.uctoo.agent_skills"}', 70);

-- 权限管理菜单
INSERT INTO permissions (permission_name, type, level, component, path, parent_id, meta, weight) VALUES
('permission', 1, '0', 'BasicLayout', '/permission', NULL, NULL, '{"icon": "mdi:database-sync", "order": 80, "title": "page.permission", "keepAlive": true}', 80);

-- ========== 按钮权限 (type=2) ==========
-- V4建议统一使用button.前缀

INSERT INTO permissions (permission_name, type, title, parent_id) VALUES
-- 实体管理按钮
('button.entity.create', 2, '创建实体', 'database.uctoo.entity'),
('button.entity.edit', 2, '编辑实体', 'database.uctoo.entity'),
('button.entity.delete', 2, '删除实体', 'database.uctoo.entity'),
('button.entity.view', 2, '查看实体', 'database.uctoo.entity'),
('button.entity.export', 2, '导出实体', 'database.uctoo.entity'),

-- 用户管理按钮
('button.user.create', 2, '创建用户', 'database.uctoo.uctoo_user'),
('button.user.edit', 2, '编辑用户', 'database.uctoo.uctoo_user'),
('button.user.delete', 2, '删除用户', 'database.uctoo.uctoo_user'),
('button.user.view', 2, '查看用户', 'database.uctoo.uctoo_user'),

-- 角色管理按钮
('button.role.create', 2, '创建角色', 'database.uctoo.uctoo_role'),
('button.role.edit', 2, '编辑角色', 'database.uctoo.uctoo_role'),
('button.role.delete', 2, '删除角色', 'database.uctoo.uctoo_role'),
('button.role.assignPermission', 2, '分配权限', 'database.uctoo.uctoo_role'),

-- 权限管理按钮
('button.permission.create', 2, '创建权限', 'database.uctoo.permissions'),
('button.permission.edit', 2, '编辑权限', 'database.uctoo.permissions'),
('button.permission.delete', 2, '删除权限', 'database.uctoo.permissions'),
('button.permission.assign', 2, '分配权限', 'database.uctoo.permissions');
```

#### 3.1.2 默认角色(V4标准RBAC)

```sql
-- 访客角色
INSERT INTO uctoo_role (id, name, title, code, description, status, weight) VALUES
(gen_random_uuid(), 'guest', '访客', 'guest', '访客用户,默认无权限', 1, 0);

-- 普通用户角色
INSERT INTO uctoo_role (id, name, title, code, description, status, weight) VALUES
(gen_random_uuid(), 'user', '普通用户', 'user', '普通用户,基础权限', 1, 10);

-- 管理员角色
INSERT INTO uctoo_role (id, name, title, code, description, status, weight) VALUES
(gen_random_uuid(), 'admin', '管理员', 'admin', '管理员,管理权限', 1, 20);

-- 超级管理员角色
INSERT INTO uctoo_role (id, name, title, code, description, status, weight) VALUES
(gen_random_uuid(), 'super_admin', '超级管理员', 'super_admin', '超级管理员,全部权限', 1, 30);

-- 为超级管理员角色分配全部权限
INSERT INTO role_has_permission (role_id, permission_name, status)
SELECT 
    r.id AS role_id,
    '/*' AS permission_name,
    1 AS status
FROM uctoo_role r
WHERE r.name = 'super_admin';
```

#### 3.1.3 审计日志表(沿用V3)

**login_log表** - 登录日志:
```sql
CREATE TABLE login_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    login_name VARCHAR,                    -- 登录用户名
    login_ip VARCHAR,                      -- 登录IP
    browser VARCHAR,                       -- 浏览器
    os VARCHAR,                            -- 操作系统
    login_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- 登录时间
    status INT DEFAULT 0,                  -- 状态: 1=成功, 0=失败
    creator UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);
```

**operate_log表** - 操作日志:
```sql
CREATE TABLE operate_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module VARCHAR,                        -- 模块名称
    operate VARCHAR,                       -- 操作模块
    route VARCHAR,                         -- 路由
    params VARCHAR,                        -- 参数
    ip VARCHAR,                            -- IP地址
    method VARCHAR,                        -- 请求方法
    creator UUID,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ
);
```

### 3.2 API权限映射

#### 3.2.1 CRUD接口权限映射(兼容V3)

**权限检查逻辑**:
- API权限使用路由路径作为permission_name
- 权限检查时匹配当前请求的路由路径
- 支持路由参数匹配(如`:id`, `:limit`, `:page`等)

| 路由模式 | HTTP方法 | permission_name | 说明 |
|---------|---------|-----------------|------|
| `/api/v1/uctoo/entity` | POST | `/api/v1/uctoo/entity` | 创建实体 |
| `/api/v1/uctoo/entity/:id` | GET | `/api/v1/uctoo/entity/:id` | 查询详情 |
| `/api/v1/uctoo/entity/:limit/:page` | GET | `/api/v1/uctoo/entity/:limit/:page` | 分页查询 |
| `/api/v1/uctoo/entity/:limit/:page/:skip` | GET | `/api/v1/uctoo/entity/:limit/:page/:skip` | 分页查询(带skip) |
| `/api/v1/uctoo/entity/:id` | PUT | `/api/v1/uctoo/entity/:id` | 更新实体 |
| `/api/v1/uctoo/entity/:id` | DELETE | `/api/v1/uctoo/entity/:id` | 删除实体 |

**权限匹配规则**:

```cangjie
public func matchRoutePermission(requestPath: String, permissionPath: String): Bool {
    // 1. 精确匹配
    if (requestPath == permissionPath) {
        return true
    }
    
    // 2. 通配符匹配
    if (permissionPath == "/*") {
        return true
    }
    
    // 3. 路由参数匹配
    // 将permissionPath中的:xxx替换为正则表达式
    let pattern = permissionPath
        .replace("/:id", "/[^/]+")
        .replace("/:limit", "/[^/]+")
        .replace("/:page", "/[^/]+")
        .replace("/:skip", "/[^/]+")
    
    return regexMatch(pattern, requestPath)
}
```

#### 3.2.2 特殊接口权限映射

| 路由 | HTTP方法 | permission_name | 说明 |
|------|---------|-----------------|------|
| `/api/v1/uctoo/user/signin` | POST | (公开,无需权限) | 用户登录 |
| `/api/v1/uctoo/user/signup` | POST | (公开,无需权限) | 用户注册 |
| `/api/v1/uctoo/user/me` | GET | `/api/auth/me` | 获取当前用户 |
| `/api/v1/uctoo/user/logout` | POST | `/api/auth/logout` | 用户登出 |
| `/api/v1/skills/install` | POST | `/api/v1/skills/install` | 技能安装 |
| `/api/v1/skills/execute` | POST | `/api/v1/skills/execute` | 技能执行 |
| `/api/v1/mcp/stream` | GET | `/api/v1/mcp/stream` | MCP流式接口 |

#### 3.2.3 菜单权限映射

| 菜单类型 | permission_name格式 | 示例 | 前端路由 |
|---------|---------------------|------|---------|
| 数据库菜单 | `database.{db}.{table}` | `database.uctoo.entity` | `/database/uctoo/entity` |
| 普通菜单 | 自定义名称 | `Dashboard` | `/` |
| 功能菜单 | `menu.{name}` | `menu.settings` | `/settings` |

#### 3.2.4 按钮权限映射

| 按钮类型 | permission_name格式 | 示例 | 所属菜单 |
|---------|---------------------|------|---------|
| 创建按钮 | `button.{module}.create` | `button.entity.create` | `database.uctoo.entity` |
| 编辑按钮 | `button.{module}.edit` | `button.entity.edit` | `database.uctoo.entity` |
| 删除按钮 | `button.{module}.delete` | `button.entity.delete` | `database.uctoo.entity` |
| 查看按钮 | `button.{module}.view` | `button.entity.view` | `database.uctoo.entity` |
| 导出按钮 | `button.{module}.export` | `button.entity.export` | `database.uctoo.entity` |

---

## 四、权限修复方案

### 4.1 当前问题分析

**问题清单**:
1. ❌ 约60个CRUD接口缺少权限控制
2. ❌ 敏感操作接口(技能安装/执行)无权限检查
3. ❌ MCP流式接口无权限保护
4. ❌ 权限管理接口自身无权限控制
5. ❌ 系统配置接口无权限保护

### 4.2 修复策略

#### 4.2.1 分级修复

**优先级P0 - 立即修复**:
- 权限管理接口
- 用户管理接口
- 系统配置接口

**优先级P1 - 高优先级**:
- 技能安装/执行接口
- MCP流式接口
- 实体CRUD接口

**优先级P2 - 中优先级**:
- 会话管理接口
- 用户组管理接口
- 其他CRUD接口

#### 4.2.2 修复步骤

**步骤1: 定义权限常量**

```cangjie
// src/app/constants/PermissionConstants.cj
public class PermissionConstants {
    // 用户管理
    public static let USER_CREATE = "uctoo:user:create"
    public static let USER_READ = "uctoo:user:read"
    public static let USER_UPDATE = "uctoo:user:update"
    public static let USER_DELETE = "uctoo:user:delete"
    public static let USER_MANAGE = "uctoo:user:manage"
    
    // 实体管理
    public static let ENTITY_CREATE = "uctoo:entity:create"
    public static let ENTITY_READ = "uctoo:entity:read"
    public static let ENTITY_UPDATE = "uctoo:entity:update"
    public static let ENTITY_DELETE = "uctoo:entity:delete"
    public static let ENTITY_MANAGE = "uctoo:entity:manage"
    
    // 技能管理
    public static let SKILL_INSTALL = "skill:install"
    public static let SKILL_EXECUTE = "skill:execute"
    public static let SKILL_MANAGE = "skill:manage"
    
    // MCP接口
    public static let MCP_READ = "mcp:read"
    public static let MCP_WRITE = "mcp:write"
    public static let MCP_MANAGE = "mcp:manage"
    
    // 系统配置
    public static let SYSTEM_CONFIG_READ = "system:config:read"
    public static let SYSTEM_CONFIG_WRITE = "system:config:write"
}
```

**步骤2: 修改路由定义**

```cangjie
// 示例: EntityRoute.cj
public class EntityRoute {
    public func register(router: Router) {
        let group = router.group("/api/v1/uctoo/entity")
        
        // 查询列表 - 需要读取权限
        group.get("/", 
            deserializeUserMiddleware,
            requireUserMiddleware,
            requirePermissionMiddleware.require(PermissionConstants.ENTITY_READ),
            entityController.list
        )
        
        // 查询详情 - 需要读取权限
        group.get("/:id",
            deserializeUserMiddleware,
            requireUserMiddleware,
            requirePermissionMiddleware.require(PermissionConstants.ENTITY_READ),
            entityController.get
        )
        
        // 创建 - 需要创建权限
        group.post("/",
            deserializeUserMiddleware,
            requireUserMiddleware,
            requirePermissionMiddleware.require(PermissionConstants.ENTITY_CREATE),
            entityController.create
        )
        
        // 更新 - 需要更新权限
        group.put("/:id",
            deserializeUserMiddleware,
            requireUserMiddleware,
            requirePermissionMiddleware.require(PermissionConstants.ENTITY_UPDATE),
            entityController.update
        )
        
        // 删除 - 需要删除权限
        group.delete("/:id",
            deserializeUserMiddleware,
            requireUserMiddleware,
            requirePermissionMiddleware.require(PermissionConstants.ENTITY_DELETE),
            entityController.delete
        )
    }
}
```

**步骤3: 批量修复脚本**

创建自动化修复工具:

```cangjie
// scripts/fix-permissions.cj
public class PermissionFixer {
    public func fixAllRoutes() {
        // 1. 扫描所有路由文件
        let routeFiles = scanRouteFiles()
        
        // 2. 分析路由定义
        for (file in routeFiles) {
            let routes = parseRoutes(file)
            
            // 3. 检查权限配置
            for (route in routes) {
                if (!route.hasPermission()) {
                    // 4. 自动添加权限中间件
                    addPermissionMiddleware(route)
                }
            }
            
            // 5. 写回文件
            writeFile(file)
        }
    }
}
```

### 4.3 修复验证

#### 4.3.1 权限测试用例

```cangjie
// tests/permission-tests.cj
public class PermissionTests {
    // 测试未登录访问
    public func testUnauthorizedAccess() {
        let response = http.get("/api/v1/uctoo/entity")
        assert(response.status == 401)
    }
    
    // 测试无权限访问
    public func testNoPermissionAccess() {
        let user = loginAs("guest")
        let response = http.get("/api/v1/uctoo/entity", 
            headers: ["Authorization": "Bearer ${user.token}"])
        assert(response.status == 403)
    }
    
    // 测试有权限访问
    public func testHasPermissionAccess() {
        let user = loginAs("admin")
        let response = http.get("/api/v1/uctoo/entity",
            headers: ["Authorization": "Bearer ${user.token}"])
        assert(response.status == 200)
    }
    
    // 测试行级权限
    public func testRowLevelPermission() {
        let user1 = loginAs("user1")
        let user2 = loginAs("user2")
        
        // user1创建数据
        let data = createEntity(user1, {"name": "test"})
        
        // user2无法访问user1的数据
        let response = http.get("/api/v1/uctoo/entity/${data.id}",
            headers: ["Authorization": "Bearer ${user2.token}"])
        assert(response.status == 404)
    }
}
```

#### 4.3.2 权限审计日志

```cangjie
public class PermissionAuditLogger {
    public func logAccess(
        userId: String,
        permission: String,
        resource: String,
        action: String,
        result: Bool
    ) {
        auditLog.insert({
            "user_id": userId,
            "permission": permission,
            "resource": resource,
            "action": action,
            "result": result ? "ALLOW" : "DENY",
            "timestamp": DateTime.now(),
            "ip": context.ip,
            "user_agent": context.userAgent
        })
    }
}
```

---

## 五、实施计划

### 5.1 阶段一: 基础设施 (1-2天)

- [x] 完善权限中间件
- [x] 实现权限缓存
- [x] 定义权限常量
- [x] 创建权限节点数据

### 5.2 阶段二: 接口修复 (3-5天)

**优先级P0**:
- [ ] 修复权限管理接口
- [ ] 修复用户管理接口
- [ ] 修复系统配置接口

**优先级P1**:
- [ ] 修复技能管理接口
- [ ] 修复MCP接口
- [ ] 修复实体CRUD接口

**优先级P2**:
- [ ] 修复会话管理接口
- [ ] 修复用户组管理接口
- [ ] 修复其他CRUD接口

### 5.3 阶段三: 测试验证 (2-3天)

- [ ] 编写权限测试用例
- [ ] 执行权限测试
- [ ] 修复测试问题
- [ ] 性能测试

### 5.4 阶段四: 文档完善 (1天)

- [ ] 更新API文档
- [ ] 编写权限配置指南
- [ ] 编写运维手册

---

## 六、监控与运维

### 6.1 权限监控指标

```cangjie
public class PermissionMetrics {
    // 权限检查次数
    public static let CHECK_COUNT = Counter("permission_check_count")
    
    // 权限拒绝次数
    public static let DENY_COUNT = Counter("permission_deny_count")
    
    // 权限检查耗时
    public static let CHECK_DURATION = Histogram("permission_check_duration")
    
    // 缓存命中率
    public static let CACHE_HIT_RATE = Gauge("permission_cache_hit_rate")
}
```

### 6.2 权限运维工具

**权限查询工具**:
```bash
# 查询用户权限
cjpm run permission:check --user=user123

# 查询权限使用情况
cjpm run permission:usage --permission=uctoo:entity:read

# 权限审计报告
cjpm run permission:audit --start=2026-03-01 --end=2026-03-24
```

**权限管理工具**:
```bash
# 批量授权
cjpm run permission:grant --group=admin --permission=uctoo:entity:*

# 批量撤销
cjpm run permission:revoke --group=guest --permission=*

# 权限同步
cjpm run permission:sync --from=prod --to=dev
```

---

## 七、最佳实践建议

### 7.1 权限设计原则

1. **最小权限原则**: 只授予必要的权限
2. **职责分离**: 不同角色分配不同权限
3. **定期审计**: 定期检查权限配置
4. **权限过期**: 敏感权限设置有效期
5. **操作审计**: 记录所有权限操作

### 7.2 常见问题处理

**问题1: 权限配置过于复杂**
- 解决: 使用权限模板和批量配置工具

**问题2: 权限检查性能问题**
- 解决: 使用缓存和预加载机制

**问题3: 权限继承问题**
- 解决: 明确权限继承规则,避免循环依赖

**问题4: 权限迁移问题**
- 解决: 使用版本化权限配置和迁移脚本

---

## 八、总结

### 8.1 V4权限体系优势

1. ✅ **安全性**: 默认无权限,显式授权
2. ✅ **灵活性**: 支持多层级权限控制
3. ✅ **性能**: 权限缓存机制
4. ✅ **可维护性**: 模块化设计
5. ✅ **可扩展性**: 支持动态权限配置
6. ✅ **可审计性**: 完整的审计日志

### 8.2 与V3对比

| 维度 | V3 | V4 |
|------|----|----|
| 权限粒度 | 路由级 | 路由+数据+操作级 |
| 权限命名 | 路由路径 | 模块:资源:操作 |
| 权限缓存 | 无 | Redis缓存 |
| 权限审计 | 基础 | 完整审计日志 |
| 性能优化 | 无 | 缓存+预加载 |
| 运维工具 | 无 | 完整CLI工具 |

### 8.3 下一步工作

1. 实施权限修复方案
2. 完善权限测试覆盖
3. 优化权限检查性能
4. 编写运维文档
5. 培训开发团队

---

**文档版本**: 1.0.0  
**最后更新**: 2026-03-24  
**文档状态**: 已完成  
**审核状态**: 待审核
