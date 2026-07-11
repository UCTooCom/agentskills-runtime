# UCToo V4 Auth 架构设计方案

**文档版本**: 2.0.0  
**创建日期**: 2026-03-22  
**目标**: 设计auth功能的最佳架构方案，实现模块化、可维护、可扩展的认证鉴权体系

---

## 一、架构模式对比分析

### 1.1 集中式架构（Backend V3模式）

**结构**：
```
controllers/uctoo/auth/
├── signin.ts          # 登录
├── signup.ts          # 注册
├── logout.ts          # 登出
├── me.ts              # 获取当前用户
├── checkToken.ts      # Token检查
├── resetpassword.ts   # 重置密码
├── github.ts          # GitHub OAuth
├── google.ts          # Google OAuth
└── wechatopen.ts      # 微信OAuth
```

**优点**：
- ✅ 认证逻辑集中，易于查找和维护
- ✅ 统一的认证入口，便于添加全局认证逻辑
- ✅ 适合小型项目，结构简单清晰

**缺点**：
- ❌ 违反单一职责原则，auth控制器承担过多职责
- ❌ 与具体用户模型耦合，难以支持多用户类型
- ❌ 难以扩展，新增认证方式需要修改auth模块
- ❌ 不符合领域驱动设计（DDD）原则
- ❌ 代码复用性差，不同用户类型的认证逻辑混杂

### 1.2 分布式架构（模块化模式）

**结构**：
```
controllers/uctoo/
├── uctoo_user/
│   ├── UctooUserController.cj      # 标准CRUD
│   └── UctooUserAuthController.cj  # 用户认证（登录、注册、登出等）
├── user_group/
│   ├── UserGroupController.cj      # 标准CRUD
│   └── UserGroupAuthController.cj  # 组权限管理
└── permissions/
    ├── PermissionsController.cj    # 标准CRUD
    └── PermissionsAuthController.cj # 权限检查
```

**优点**：
- ✅ 符合单一职责原则，每个模块职责清晰
- ✅ 符合领域驱动设计，按领域划分模块
- ✅ 高内聚低耦合，易于维护和测试
- ✅ 易于扩展，新增用户类型只需添加新模块
- ✅ 代码复用性高，通用认证逻辑可提取为工具类
- ✅ 符合微服务架构思想，便于未来拆分

**缺点**：
- ⚠️ 模块数量增加，需要良好的组织结构
- ⚠️ 跨模块调用需要合理设计接口

---

## 二、业界最佳实践分析

### 2.1 主流框架实践

| 框架 | 架构模式 | 设计理念 |
|------|---------|---------|
| **Spring Security** | 模块化 | 按功能模块划分，支持多种认证方式 |
| **Django Auth** | 模块化 | 用户模型与认证逻辑分离 |
| **Laravel Auth** | 模块化 | 按领域划分，支持多guard |
| **NestJS Auth** | 模块化 | 按模块划分，支持多种策略 |
| **Rails Devise** | 模块化 | 按模型划分，支持多用户类型 |

**结论**：业界主流框架均采用**模块化架构**

### 2.2 设计原则

1. **单一职责原则（SRP）**：每个模块只负责一个领域的功能
2. **开闭原则（OCP）**：对扩展开放，对修改关闭
3. **依赖倒置原则（DIP）**：依赖抽象而非具体实现
4. **接口隔离原则（ISP）**：使用小接口而非大接口
5. **领域驱动设计（DDD）**：按领域划分模块边界

---

## 三、UCToo V4 最佳实践方案

### 3.1 架构设计决策

**采用分布式模块化架构**，理由如下：

1. **符合仓颉语言特性**：仓颉强调模块化和类型安全
2. **符合UCToo V4设计理念**：每个表对应一个独立模块
3. **符合业界最佳实践**：主流框架均采用模块化
4. **便于未来扩展**：支持多用户类型、多认证方式
5. **提高代码质量**：高内聚低耦合，易于测试和维护

### 3.2 目录结构设计

```
src/app/
├── controllers/uctoo/
│   ├── uctoo_user/
│   │   ├── UctooUserController.cj      # 标准CRUD接口
│   │   └── UctooUserAuthController.cj  # 用户认证接口
│   │       ├── signin()                # 登录
│   │       ├── signup()                # 注册
│   │       ├── logout()                # 登出
│   │       ├── me()                    # 获取当前用户
│   │       ├── resetPassword()         # 重置密码
│   │       └── checkToken()            # Token检查
│   ├── uctoo_session/
│   │   ├── UctooSessionController.cj   # 标准CRUD接口
│   │   └── UctooSessionAuthController.cj # 会话管理
│   ├── user_group/
│   │   ├── UserGroupController.cj      # 标准CRUD接口
│   │   └── UserGroupAuthController.cj  # 组权限管理
│   ├── permissions/
│   │   ├── PermissionsController.cj    # 标准CRUD接口
│   │   └── PermissionsAuthController.cj # 权限检查
│   └── oauth/                          # OAuth认证（独立模块）
│       ├── GitHubOAuthController.cj
│       ├── GoogleOAuthController.cj
│       └── WechatOAuthController.cj
├── services/uctoo/
│   ├── UctooUserService.cj             # 用户业务逻辑
│   ├── UctooSessionService.cj          # 会话业务逻辑
│   ├── UserGroupService.cj             # 用户组业务逻辑
│   ├── PermissionsService.cj           # 权限业务逻辑
│   └── UserHasGroupService.cj          # 用户组关联业务逻辑
├── middlewares/auth/
│   ├── DeserializeUserMiddleware.cj    # Token反序列化
│   ├── RequireUserMiddleware.cj        # 用户认证检查
│   └── RequirePermissionMiddleware.cj  # 权限检查
├── utils/auth/
│   ├── JWTUtil.cj                      # JWT工具
│   ├── BcryptUtil.cj                   # 密码加密工具
│   ├── CookieUtil.cj                   # Cookie工具
│   └── AuthorizeUtil.cj                # 授权工具
└── routes/uctoo/
    ├── uctoo_user/
    │   ├── UctooUserRoute.cj           # 标准CRUD路由
    │   └── UctooUserAuthRoute.cj       # 认证路由
    ├── oauth/
    │   ├── GitHubOAuthRoute.cj
    │   ├── GoogleOAuthRoute.cj
    │   └── WechatOAuthRoute.cj
    └── AuthRoute.cj                    # 认证路由汇总
```

### 3.3 模块职责划分

#### 3.3.1 UctooUserAuthController

**职责**：用户认证相关功能

| 方法 | 功能 | 路由 |
|------|------|------|
| signin() | 用户登录 | POST /api/v1/uctoo/uctoo_user/signin |
| signup() | 用户注册 | POST /api/v1/uctoo/uctoo_user/signup |
| logout() | 用户登出 | POST /api/v1/uctoo/uctoo_user/logout |
| me() | 获取当前用户 | GET /api/v1/uctoo/uctoo_user/me |
| resetPassword() | 重置密码 | POST /api/v1/uctoo/uctoo_user/resetpassword |
| checkToken() | Token检查 | GET /api/v1/uctoo/uctoo_user/checktoken |

#### 3.3.2 UctooSessionAuthController

**职责**：会话管理

| 方法 | 功能 | 路由 |
|------|------|------|
| createSession() | 创建会话 | 内部调用 |
| validateSession() | 验证会话 | 内部调用 |
| refreshSession() | 刷新会话 | POST /api/v1/uctoo/uctoo_session/refresh |

#### 3.3.3 PermissionsAuthController

**职责**：权限检查

| 方法 | 功能 | 路由 |
|------|------|------|
| checkPermission() | 检查权限 | 内部调用 |
| getUserPermissions() | 获取用户权限 | GET /api/v1/uctoo/permissions/user/:userId |
| getUserMenus() | 获取用户菜单 | GET /api/v1/uctoo/permissions/menus/:userId |

### 3.4 认证流程设计

#### 3.4.1 登录流程

```
1. 用户提交登录请求
   ↓
2. UctooUserAuthController.signin()
   - 验证用户名密码
   - 检查验证码（可选）
   ↓
3. UctooSessionService.createSession()
   - 创建会话记录
   - 缓存到Redis
   ↓
4. JWTUtil.generateToken()
   - 生成access_token
   - 生成refresh_token
   ↓
5. CookieUtil.setToken()
   - 设置HttpOnly Cookie
   ↓
6. 返回用户信息和Token
```

#### 3.4.2 权限检查流程

```
1. 请求到达中间件
   ↓
2. DeserializeUserMiddleware
   - 解析Token
   - 验证Token有效性
   - 设置req.user
   ↓
3. RequireUserMiddleware
   - 检查用户是否登录
   - 检查用户状态
   ↓
4. RequirePermissionMiddleware
   - 获取用户权限列表
   - 检查路由权限
   - 检查数据权限
   ↓
5. 继续处理请求
```

---

## 四、实现计划

### 4.1 阶段一：基础设施（已完成）

- ✅ 生成标准CRUD模块
- ✅ 实现复合主键表CRUD
- ✅ 编译通过

### 4.2 阶段二：工具类实现

**任务清单**：
- [ ] 实现JWTUtil（JWT Token生成和验证）
- [ ] 实现BcryptUtil（密码加密和验证）
- [ ] 实现CookieUtil（Cookie管理）
- [ ] 实现AuthorizeUtil（授权流程封装）

### 4.3 阶段三：中间件实现

**任务清单**：
- [ ] 实现DeserializeUserMiddleware（Token反序列化）
- [ ] 实现RequireUserMiddleware（用户认证检查）
- [ ] 实现RequirePermissionMiddleware（权限检查）

### 4.4 阶段四：认证接口实现

**任务清单**：
- [ ] 实现UctooUserAuthController（用户认证）
  - [ ] signin() - 登录
  - [ ] signup() - 注册
  - [ ] logout() - 登出
  - [ ] me() - 获取当前用户
  - [ ] resetPassword() - 重置密码
  - [ ] checkToken() - Token检查
- [ ] 实现UctooSessionAuthController（会话管理）
- [ ] 实现PermissionsAuthController（权限检查）

### 4.5 阶段五：OAuth实现

**任务清单**：
- [ ] 实现GitHubOAuthController
- [ ] 实现GoogleOAuthController
- [ ] 实现WechatOAuthController

---

## 五、技术选型

### 5.1 第三方库

| 功能 | 库 | 版本 | 说明 |
|------|-----|------|------|
| JWT | jwt4cj | v1.0.1 | Token生成和验证 |
| 密码加密 | pbkdf2 | v0.0.1 | 密码哈希 |
| Redis | redis-sdk | v3.0.0 | 会话缓存 |
| OAuth | oauth4cj | v0.0.1 | OAuth认证 |

### 5.2 配置管理

```env
# JWT配置
JWT_SECRET=uctoo-v4-secret-key
ACCESS_TOKEN_VALIDITY_SEC=1728000
REFRESH_TOKEN_VALIDITY_SEC=6048000

# 密码加密配置
BCRYPT_SALT_ROUNDS=10

# Redis配置
REDIS_URL=redis://127.0.0.1:6379

# 行级权限开关
ROW_LEVEL_PERMISSION_ENABLED=true
```

---

## 六、对比总结

| 维度 | 集中式架构 | 模块化架构 |
|------|-----------|-----------|
| **代码组织** | 集中在一个目录 | 按领域分散 |
| **职责划分** | 单一大控制器 | 多个小控制器 |
| **可维护性** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **可扩展性** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **可测试性** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **代码复用** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **符合DDD** | ❌ | ✅ |
| **符合SRP** | ❌ | ✅ |
| **业界实践** | 少数 | 主流 |

**最终决策**：采用**模块化架构**

---

## 七、实施建议

### 7.1 开发顺序

1. **工具类** → 2. **中间件** → 3. **认证接口** → 4. **OAuth**

### 7.2 测试策略

- 单元测试：每个工具类和Service方法
- 集成测试：认证流程端到端测试
- 安全测试：Token验证、权限检查

### 7.3 文档要求

- API文档：每个接口的请求响应格式
- 架构文档：模块职责和依赖关系
- 部署文档：配置项和环境变量

---

**文档版本**: 2.0.0  
**最后更新**: 2026-03-22  
**文档状态**: 已批准
