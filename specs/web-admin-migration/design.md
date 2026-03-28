# 技术设计文档

## 文档信息
- **项目名称**: uctoo v4 web管理后台迁移
- **版本**: 2.0
- **创建日期**: 2025-01-18
- **更新日期**: 2025-03-28
- **作者**: SDD Agent
- **状态**: 已更新

## 1. 设计概述

### 1.1 设计目标
本设计旨在将uctoo v3的web管理后台迁移至现代化技术栈，实现以下目标：
1. 迁移状态管理库的UMI特性，保持数据一致性
2. 融合nestJs到agentskills-runtime v0.0.20，以agentskills-runtime已有基础设施为主
3. 完成MySQL到PostgreSQL的数据库迁移，复用已有表结构
4. 开发CRUD生成器技能，提升开发效率

**融合原则**：
- agentskills-runtime已有机制始终是统一的一套机制
- 符合uctoo的API规范、模块规范、数据库规范等成熟规范
- 不为融合nestJs而新建另一套机制
- nestJs只是内置初始示例项目，成熟度比uctoo v4差很多

**项目当前状态**：
- ✅ web-admin初始版本已创建运行
- ✅ 基于tiny-pro的前端和后端已就绪
- 🔄 待迁移状态管理库UMI特性
- 🔄 待融合后端服务
- 🔄 待开发CRUD生成器

### 1.2 设计原则
- **最小迁移**：仅迁移必要的pinia-orm特性，其他直接开发
- **服务融合**：nestJs功能完全融合到agentskills-runtime
- **数据兼容**：确保MySQL到PostgreSQL迁移的数据一致性
- **UMI同构**：保持全栈模型同构规范
- **类型安全**：使用TypeScript强类型，避免any类型

### 1.3 技术选型
| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 前端框架 | Vue 3.5+ | 基于tiny-pro，已初始化 |
| 构建工具 | Vite 6+ | 基于tiny-pro配置 |
| 状态管理 | Pinia 2.1+ pinia-orm | 迁移UMI特性 |
| UI组件库 | @opentiny/vue 3.29+ | 基于tiny-pro |
| 开发语言 | TypeScript 5.1+ | 强类型 |
| 国际化 | vue-i18n 11+ | 基于tiny-pro |
| HTTP客户端 | axios 1.8+ | 基于tiny-pro |
| 后端服务 | agentskills-runtime v0.0.20 | 替代nestJs |
| 数据库 | PostgreSQL 14+ | 从MySQL迁移 |
| 架构规范 | UMI | 全栈模型同构 |

## 2. 系统架构

### 2.1 架构图
```
┌─────────────────────────────────────────────────────────────┐
│                   web-admin (uctoo v4)                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    Presentation Layer                  │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │   Views     │  │ Components  │  │   Layouts   │   │  │
│  │  │  (Pages)    │  │  (TinyVue)  │  │  (Router)   │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    Business Layer                      │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │   Stores    │  │   Hooks     │  │    APIs     │   │  │
│  │  │(Pinia+ORM)  │  │ (Composable)│  │  (Axios)    │   │  │
│  │  │  (UMI迁移)  │  │             │  │             │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                      UMI Layer                         │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │   Models    │  │  LocalStore │  │  AutoSave   │   │  │
│  │  │  (pinia-orm)│  │(localStorage)│  │  (Callback) │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP/HTTPS (RESTful API)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              agentskills-runtime v0.0.20                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   API Gateway Layer                    │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │  Auth API   │  │  CRUD API   │  │  Skill API  │   │  │
│  │  │(JWT Token)  │  │  (UMI)      │  │(Generator)  │   │  │
│  │  │ (nestJs融合)│  │             │  │             │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  Business Logic Layer                  │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │ Permission  │  │   CRUD      │  │ crud-web-   │   │  │
│  │  │  Service    │  │  Service    │  │ generator   │   │  │
│  │  │ (nestJs融合)│  │             │  │             │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    Data Layer                          │  │
│  │  ┌─────────────┐  ┌─────────────┐                     │  │
│  │  │   Prisma    │  │  Database   │                     │  │
│  │  │    ORM      │  │(PostgreSQL) │                     │  │
│  │  │             │  │(MySQL迁移)  │                     │  │
│  │  └─────────────┘  └─────────────┘                     │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 模块划分

#### 2.2.1 web-admin前端模块
**已初始化项目结构**：
```
web-admin/uctoo-admin/web/
├── src/
│   ├── api/              # API接口层（已就绪）
│   ├── components/       # 公共组件（已就绪）
│   ├── hooks/            # 组合式函数（已就绪）
│   ├── layout/           # 布局组件（已就绪）
│   ├── locale/           # 国际化资源（已就绪）
│   ├── router/           # 路由配置（已就绪）
│   ├── store/            # 状态管理（需迁移UMI特性）
│   │   ├── index.ts
│   │   └── modules/
│   │       ├── user/         # 用户状态（已就绪）
│   │       ├── locales.ts    # 国际化状态（已就绪）
│   │       ├── router.ts     # 路由状态（已就绪）
│   │       ├── tabs.ts       # 标签页状态（已就绪）
│   │       └── uctoo/        # uctoo模型（需新增）
│   ├── types/            # TypeScript类型定义
│   ├── utils/            # 工具函数（已就绪）
│   └── views/            # 页面组件（已就绪）
└── config/               # 构建配置（已就绪）
```

#### 2.2.2 agentskills-runtime后端模块
```
agentskills-runtime/
├── skills/
│   └── crud-web-generator/    # CRUD生成器技能（需开发）
│       ├── SKILL.md
│       ├── index.ts
│       ├── templates/
│       └── utils/
├── src/
│   ├── api/
│   │   ├── auth/              # 认证API（需融合nestJs）
│   │   ├── permission/        # 权限API（需融合nestJs）
│   │   └── uctoo/             # uctoo数据库API
│   └── services/
│       ├── permission.service.ts  # 权限服务（需融合）
│       └── crud.service.ts
└── sql/
    └── uctoov4InitData.sql    # PostgreSQL初始化数据（需融合）
```

### 2.3 组件交互

#### 2.3.1 UMI数据流
```
用户操作 → View组件 → Store Action → API调用
                                    ↓
                              agentskills-runtime
                                    ↓
                              API响应
                                    ↓
                        UMI自动保存（pinia-orm）
                                    ↓
                          LocalStorage
                                    ↓
                          View自动更新（响应式）
```

## 3. 详细设计

### 3.1 状态管理库迁移设计

#### 3.1.1 迁移范围分析
**需要迁移的内容**：
- pinia-orm的Model基类定义
- 字段装饰器（Attr、Str、Num、Bool、Uid等）
- 关系装饰器（HasOne、HasMany、BelongsTo等）
- UMI自动保存机制
- 本地数据优先策略

**不需要迁移的内容**：
- qintong和qintongdev定制化模型
- 旧项目的业务逻辑代码

#### 3.1.2 UMI特性实现设计
**自动保存机制**：
```typescript
// src/store/plugins/umiPlugin.ts
export const umiPlugin = ({ store }) => {
  store.$onAction(({ name, after, onError }) => {
    after((result) => {
      if (store.$config?.umi?.autoSave !== false) {
        saveToLocal(store.$id, result)
      }
    })
  })
}

function saveToLocal(entity: string, data: any) {
  const key = `umi_${entity}`
  const existing = JSON.parse(localStorage.getItem(key) || '[]')
  const merged = mergeData(existing, data)
  localStorage.setItem(key, JSON.stringify(merged))
}
```

**本地数据优先策略**：
```typescript
// src/store/plugins/localPriorityPlugin.ts
export function useLocalData(model: typeof UmiModel) {
  const key = `umi_${model.entity}`
  const localData = JSON.parse(localStorage.getItem(key) || '[]')
  
  if (localData.length > 0 && model.$config?.umi?.localPriority) {
    return localData
  }
  
  return model.api().get('/api/...')
}
```

### 3.2 后端服务融合设计

#### 3.2.1 API融合映射
**融合原则**：以agentskills-runtime已有API为主，nestJs仅作为参考，不复用nestJs的API设计。

**已有API（复用）**：
- agentskills-runtime已实现JWT认证机制 → 直接复用
- agentskills-runtime已实现permissions API → 直接复用
- agentskills-runtime已实现uctoo_role API → 直接复用
- agentskills-runtime已实现uctoo_user API → 直接复用
- agentskills-runtime已实现role_has_permission API → 直接复用
- agentskills-runtime已实现user_has_roles API → 直接复用

**需新增API**：
- menu相关API（基于新建的uctoo.menu和uctoo.role_menu表）
- application CRUD API（基于新建的uctoo.application表）
- i18 CRUD API（基于新建的uctoo.i18表）
- lang CRUD API（基于新建的uctoo.lang表）

**API规范**：遵循uctoo API规范，非nestJs规范

#### 3.2.2 权限体系融合设计
**融合原则**：agentskills-runtime已有完整的权限体系，直接复用，无需迁移nestJs的权限实现。

**已有权限体系（复用）**：
- JWT认证机制：agentskills-runtime已实现，直接复用
- RBAC模型：uctoo_user、uctoo_role、permissions、user_has_roles、role_has_permission
- 权限验证中间件：agentskills-runtime已实现
- 路由权限守卫：agentskills-runtime已实现

**需新增**：
- menu表和role_menu表（扩展菜单管理功能）
- menu相关业务逻辑和API

**RBAC模型**：
```
uctoo_user (用户) ←→ user_has_roles ←→ uctoo_role (角色)
                                            ↓
                                    role_has_permission
                                            ↓
                                    permissions (权限)
```

### 3.3 数据库迁移设计

#### 3.3.1 表结构映射
**uctoo v3数据库完整表结构参考**：
- 文件：`agentskills-runtime/sql/uctooDB.sql`
- 表数量：150张表
- 用途：作为新建表的参考规范

**MySQL → PostgreSQL类型映射**：

| MySQL类型 | PostgreSQL类型 | 说明 |
|-----------|---------------|------|
| int AUTO_INCREMENT | UUID | 主键转换（uctoo规范） |
| varchar(255) | varchar(255) | 字符串 |
| longtext | text | 长文本 |
| datetime | timestamptz | 时间戳（uctoo规范） |
| json | jsonb | JSON数据 |
| tinyint(1) | boolean | 布尔值 |

**uctoo表结构规范**：
- 主键：使用UUID（gen_random_uuid()）
- 时间戳：使用timestamptz(6)
- 软删除：deleted_at字段
- 审计字段：created_at、updated_at、creator

#### 3.3.2 数据迁移表清单
**融合原则**：以agentskills-runtime已有表为主，nestJs表映射到uctoo表。

**已有表（复用）**：
- tinypro.permission → uctoo.permissions（已存在，数据迁移）
- tinypro.role → uctoo.uctoo_role（已存在，数据迁移）
- tinypro.role_permission → uctoo.role_has_permission（已存在，数据迁移）
- tinypro.user → uctoo.uctoo_user（已存在，数据迁移）
- tinypro.user_role → uctoo.user_has_roles（已存在，数据迁移）

**需新建表**：
- uctoo.menu（对应tinypro.menu，扩展菜单管理）
- uctoo.role_menu（对应tinypro.role_menu，角色菜单关联）
- uctoo.application（对应tinypro.application，应用配置）
- uctoo.i18（对应tinypro.i18，国际化资源）
- uctoo.lang（对应tinypro.lang，语言配置）

**忽略表**：
- tinypro.migrations（迁移记录，不需要）

#### 3.3.3 数据迁移脚本设计
```sql
-- 用户数据迁移示例
INSERT INTO "public"."user" (id, email, name, password, ...)
SELECT 
  gen_random_uuid() as id,  -- UUID转换
  email,
  name,
  password,
  ...
FROM mysql_user;

-- 角色数据迁移
INSERT INTO "public"."role" (id, name, description, ...)
SELECT 
  gen_random_uuid() as id,
  name,
  description,
  ...
FROM mysql_role;
```

### 3.4 CRUD生成器设计

#### 3.4.1 技能目录结构
```
skills/crud-web-generator/
├── SKILL.md                    # 技能描述
├── index.ts                    # 技能入口
├── config.ts                   # 配置选项
├── templates/                  # 代码模板
│   ├── list.vue.ejs           # 列表页模板
│   ├── form.vue.ejs           # 表单页模板
│   ├── api.ts.ejs             # API模板
│   ├── store.ts.ejs           # Store模板
│   ├── route.ts.ejs           # 路由配置模板
│   └── locale.json.ejs        # 国际化模板
└── utils/                      # 工具函数
    ├── db-reader.ts           # 数据库结构读取
    ├── field-mapper.ts        # 字段类型映射
    ├── template-engine.ts     # 模板引擎
    └── file-writer.ts         # 文件写入
```

#### 3.4.2 代码生成流程
```
1. 读取数据库表结构
   ↓
2. 分析字段类型和关系
   ↓
3. 映射到前端组件类型
   ↓
4. 生成代码模板
   ↓
5. 写入文件到目标目录
   ↓
6. 生成路由和国际化配置
```

#### 3.4.3 Entity示例模块设计
**列表页功能**：
- 数据表格展示（tiny-grid）
- 搜索筛选表单
- 分页控制
- 新增、编辑、删除操作
- 批量操作支持

**表单页功能**：
- 字段自动渲染
- 表单验证
- 提交和取消操作

## 4. 数据设计

### 4.1 数据模型
**UMI同构模型定义**：
- 前端Model定义与后端Prisma schema保持一致
- 字段类型、关系映射完全对应
- 支持软删除（deleted_at字段）
- 支持时间戳（created_at、updated_at）

### 4.2 数据迁移方案
**uctoo v3数据库完整表结构**：
- 文件：`agentskills-runtime/sql/uctooDB.sql`
- 表数量：150张表（完整的uctoo数据库定义）
- 说明：uctoo v4复用此表结构，实现平滑升级
- 当前状态：已创建支持uctoo运行的核心必要表
- 扩展策略：如有更多需求可以此表定义为基础进行融合和新建

**迁移步骤**：
1. 分析MySQL表结构（tinypro.sql）
2. 参考uctooDB.sql的表结构定义
3. 设计PostgreSQL表结构（遵循uctoo规范）
4. 编写数据转换脚本
5. 执行数据迁移
6. 验证数据一致性

### 4.3 本地存储设计
**UMI本地存储结构**：
```typescript
// localStorage
{
  "umi_uctoo_entity": [...],
  "umi_uctoo_user": [...],
  // ... 其他模型数据
}
```

## 5. API设计

### 5.1 API列表
| 方法 | 路径 | 描述 |
|------|------|------|
| POST | /api/v1/auth/login | 用户登录 |
| POST | /api/v1/auth/logout | 用户登出 |
| GET | /api/v1/user/info/:email | 获取用户信息 |
| GET | /api/v1/permission | 获取权限列表 |
| GET | /api/v1/role/:id | 获取角色信息 |
| GET | /api/v1/menu | 获取菜单列表 |
| POST | /api/:db/:table/add | 新增记录 |
| POST | /api/:db/:table/edit | 更新记录 |
| POST | /api/:db/:table/del | 删除记录 |
| GET | /api/:db/:table/:id | 查询单条 |
| GET | /api/:db/:table/:limit/:page | 查询多条 |

## 6. 安全设计

### 6.1 认证机制
- 使用JWT进行身份认证
- accessToken有效期：172800秒（2天）
- refreshToken有效期：604800秒（7天）
- Token存储在localStorage，请求时自动注入

### 6.2 权限控制
- 基于角色的访问控制（RBAC）
- 路由权限守卫
- 菜单权限过滤
- 按钮权限指令

### 6.3 数据安全
- 敏感字段不输出
- 软删除机制（deleted_at字段）
- SQL注入防护（Prisma ORM）
- XSS防护（Vue自动转义）

## 7. 性能设计

### 7.1 性能目标
- 页面首屏加载时间 < 3秒
- 列表页支持1000+数据流畅展示
- CRUD生成执行时间 < 10秒（单表）
- API响应时间 < 500ms

### 7.2 优化策略
- **前端优化**：
  - 路由懒加载
  - 组件按需加载
  - Vite构建优化
  - 本地数据优先（UMI特性）
  
- **后端优化**：
  - 数据库索引优化
  - 分页查询
  - Prisma查询优化

## 8. 部署设计

### 8.1 部署架构
```
┌─────────────┐
│   Nginx     │  反向代理
└─────────────┘
       │
       ├─────────────┐
       │             │
       ▼             ▼
┌─────────────┐ ┌─────────────┐
│  web-admin  │ │ agentskills │
│  (静态资源) │ │  -runtime   │
└─────────────┘ └─────────────┘
                     │
                     ▼
              ┌─────────────┐
              │  PostgreSQL │
              │  (uctoo)    │
              └─────────────┘
```

## 9. 附录

### 9.1 参考文档
- tiny-pro项目文档
- pinia-orm官方文档
- UMI架构规范
- PostgreSQL迁移指南

### 9.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2025-01-18 | SDD Agent | 初始版本 |
| 2.0  | 2025-03-28 | SDD Agent | 基于实际开发评估更新设计 |
