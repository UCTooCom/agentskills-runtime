# 需求规格文档

## 文档信息
- **项目名称**: uctoo v4 web管理后台迁移
- **版本**: 2.0
- **创建日期**: 2025-01-18
- **更新日期**: 2025-03-28
- **作者**: SDD Agent
- **状态**: 已更新

## 1. 概述

### 1.1 项目背景
uctoo v3的web端管理后台（uctoo-app-client-pc）基于老旧技术栈开发，底层框架官方已不再更新维护。为保障系统长期稳定运行，需要将其迁移至新技术栈，开发uctoo v4的web端管理后台（web-admin）。

**当前状态**：
- ✅ 已在`D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\web-admin\uctoo-admin`创建并运行初始版本
- ✅ web目录：基于tiny-pro的前端项目，已包含完整的权限体系
- ✅ nestJs目录：tiny-pro内置的NestJS后端服务
- 🔄 待开发：状态管理库迁移、agentskills-runtime融合、CRUD生成器

### 1.2 项目范围

**包含内容**：
1. **状态管理库迁移**：从uctoo-app-client-pc迁移符合UMI架构的pinia-orm特性到新版web/src/store
2. **后端服务融合**：将nestJs的功能、API和数据库结构融合到agentskills-runtime v0.0.20
3. **数据库迁移**：MySQL到PostgreSQL的数据结构和数据迁移方案
4. **CRUD生成器开发**：基于entity表示例开发标准CRUD模块和crud-web-generator技能

**不包含内容**：
- 旧项目uctoo-app-client-pc其他特性的迁移（直接在新版开发）
- nestJs的独立维护（将被agentskills-runtime替代）
- 业务逻辑功能的新增或修改

### 1.3 术语定义

| 术语 | 定义 |
|------|------|
| web-admin | uctoo v4的web端管理后台项目 |
| uctoo-app-client-pc | uctoo v3的web端管理后台旧项目 |
| agentskills-runtime | uctoo v4的后端运行时服务（v0.0.20） |
| nestJs | tiny-pro内置的NestJS后端服务 |
| crud-web-generator | CRUD界面生成器技能 |
| pinia-orm | 基于Pinia的ORM状态管理库 |
| UMI | 全栈模型同构架构，在分布式系统间一致性同步状态的设计规范 |
| EARS | Easy Approach to Requirements Syntax，需求语法格式 |

## 2. 系统需求

### 2.1 功能需求

#### 2.1.1 状态管理库迁移

##### REQ-STORE-001: pinia-orm特性迁移
**需求描述**: 系统应从旧项目迁移符合UMI架构的pinia-orm特性到新版状态管理库。

**验收标准**:
- [ ] 分析旧项目`uctoo-app-client-pc/src/store`的pinia-orm实现
- [ ] 迁移Model基类定义和装饰器
- [ ] 迁移UMI自动保存机制
- [ ] 迁移本地数据优先策略
- [ ] 保持与新版web/src/store的兼容性
- [ ] 不迁移qintong和qintongdev定制化内容

**优先级**: P0

##### REQ-STORE-002: UMI模型同构实现
**需求描述**: 系统应在新版状态管理库中实现UMI全栈模型同构特性。

**验收标准**:
- [ ] 实现API调用后自动保存到本地存储
- [ ] 实现本地数据优先使用策略
- [ ] 支持save:false配置控制自动保存
- [ ] 实现模型关系映射（HasOne、HasMany、BelongsTo等）
- [ ] 保持与tiny-pro Pinia的兼容性

**优先级**: P0

#### 2.1.2 后端服务融合

##### REQ-BACKEND-001: API功能融合
**需求描述**: 系统应将nestJs的API功能融合到agentskills-runtime v0.0.20，以agentskills-runtime已有API为主。

**验收标准**:
- [ ] 分析nestJs的所有API接口
- [ ] 分析agentskills-runtime已有的API接口
- [ ] 复用agentskills-runtime已有的认证机制（JWT）
- [ ] 复用agentskills-runtime已有的权限API（permissions、uctoo_role、uctoo_user）
- [ ] 新增menu相关API（基于uctoo.menu和uctoo.role_menu表）
- [ ] 新增application、i18、lang表的CRUD API
- [ ] 保持API遵循uctoo规范（非nestJs规范）

**优先级**: P0

##### REQ-BACKEND-002: 权限体系融合
**需求描述**: 系统应将nestJs的权限体系融合到agentskills-runtime。

**验收标准**:
- [ ] 迁移RBAC权限模型
- [ ] 迁移JWT认证机制
- [ ] 迁移路由权限守卫逻辑
- [ ] 迁移菜单权限过滤逻辑
- [ ] 保持与前端权限体系的兼容性

**优先级**: P0

#### 2.1.3 数据库迁移

##### REQ-DB-001: 数据结构迁移分析
**需求描述**: 系统应分析MySQL到PostgreSQL的数据结构对应关系，以agentskills-runtime已有基础设施为主。

**验收标准**:
- [ ] 分析tinypro.sql中的11张表结构
- [ ] 分析uctoov4InitData.sql中的表结构
- [ ] 建立表映射关系（nestJs → uctoo）：
  - tinypro.permission → uctoo.permissions（已存在，复用）
  - tinypro.role → uctoo.uctoo_role（已存在，复用）
  - tinypro.role_permission → uctoo.role_has_permission（已存在，复用）
  - tinypro.user → uctoo.uctoo_user（已存在，复用）
  - tinypro.user_role → uctoo.user_has_roles（已存在，复用）
  - tinypro.menu → uctoo.menu（需新建）
  - tinypro.role_menu → uctoo.role_menu（需新建）
  - tinypro.application → uctoo.application（需新建）
  - tinypro.i18 → uctoo.i18（需新建）
  - tinypro.lang → uctoo.lang（需新建）
- [ ] 识别需要新增的表和字段
- [ ] 识别需要转换的数据格式

**优先级**: P0

##### REQ-DB-002: 数据迁移方案设计
**需求描述**: 系统应设计MySQL到PostgreSQL的数据迁移方案。

**验收标准**:
- [ ] 设计表结构转换SQL脚本
- [ ] 设计数据迁移脚本
- [ ] 处理自增ID到UUID的转换
- [ ] 处理时间格式差异
- [ ] 处理JSON字段格式差异
- [ ] 提供数据验证方案

**优先级**: P0

##### REQ-DB-003: 权限数据初始化
**需求描述**: 系统应在agentskills-runtime中初始化权限相关数据。

**验收标准**:
- [ ] 迁移user表数据
- [ ] 迁移role表数据
- [ ] 迁移permission表数据
- [ ] 迁移menu表数据
- [ ] 迁移user_role关联数据
- [ ] 迁移role_permission关联数据
- [ ] 迁移role_menu关联数据

**优先级**: P1

#### 2.1.4 CRUD生成器开发

##### REQ-CRUD-001: 标准CRUD模块开发
**需求描述**: 系统应基于entity表开发标准CRUD数据表格模块作为示例。

**验收标准**:
- [ ] 开发entity列表页面（包含搜索、分页、排序）
- [ ] 开发entity新增表单页面
- [ ] 开发entity编辑表单页面
- [ ] 开发entity删除功能（支持批量删除）
- [ ] 开发entity详情页面
- [ ] 集成tiny-pro的数据表格组件
- [ ] 遵循UMI架构规范

**优先级**: P0

##### REQ-CRUD-002: CRUD生成器技能开发
**需求描述**: 系统应开发crud-web-generator技能自动生成标准CRUD模块。

**验收标准**:
- [ ] 创建skills/crud-web-generator目录结构
- [ ] 实现数据库表结构读取功能
- [ ] 实现字段类型映射逻辑
- [ ] 实现代码模板生成
- [ ] 生成列表页、表单页、API、Store、路由、国际化资源
- [ ] 提供命令行调用接口
- [ ] 提供生成代码预览功能

**优先级**: P0

##### REQ-CRUD-003: 代码模板设计
**需求描述**: 系统应设计可复用的CRUD代码模板。

**验收标准**:
- [ ] 设计列表页模板（基于tiny-pro数据表格组件）
- [ ] 设计表单页模板（包含字段验证）
- [ ] 设计API接口模板（遵循UMI规范）
- [ ] 设计Store模型模板（pinia-orm）
- [ ] 设计路由配置模板
- [ ] 设计国际化资源模板
- [ ] 支持模板自定义

**优先级**: P1

### 2.2 非功能需求

#### 2.2.1 性能需求
- 页面首屏加载时间不超过3秒
- 列表页面支持至少1000条数据的流畅展示
- 代码生成执行时间不超过10秒（单表）
- API响应时间不超过500ms

#### 2.2.2 安全需求
- 所有API请求必须携带认证Token
- 敏感配置信息不得硬编码在源码中
- 用户输入必须进行校验与过滤
- 遵循RBAC权限控制模型

#### 2.2.3 可用性需求
- 生成的代码应符合项目代码规范
- 生成的代码应包含必要的注释
- 技能执行失败应提供明确的错误提示
- 提供详细的开发文档

#### 2.2.4 可维护性需求
- CRUD生成器应支持模板自定义
- 状态管理模型应保持与数据库结构同步
- 代码结构应清晰、模块化
- 遵循tiny-pro的代码规范

### 2.3 约束性需求

#### 2.3.1 技术约束
- 前端框架：Vue 3.x（基于tiny-pro）
- 构建工具：Vite（基于tiny-pro）
- 状态管理：Pinia + pinia-orm（迁移UMI特性）
- UI组件库：@opentiny/vue（基于tiny-pro）
- 开发语言：TypeScript
- 国际化：vue-i18n（基于tiny-pro）
- 后端服务：agentskills-runtime v0.0.20（替代nestJs）
- 数据库：PostgreSQL（从MySQL迁移）
- 架构规范：UMI全栈模型同构

#### 2.3.2 业务约束
- 必须兼容tiny-pro的权限体系
- 必须保持API接口向后兼容
- 不得影响现有uctoo数据库的运行
- agentskills-runtime v0.0.20必须完全替代nestJs

#### 2.3.3 环境约束
- 开发环境：Node.js 18+
- 包管理器：pnpm
- 目标浏览器：Chrome、Firefox、Edge最新版本
- 数据库：PostgreSQL 14+

## 3. 接口需求

### 3.1 用户接口
- 提供Web UI界面，支持管理员操作
- 提供CRUD生成器命令行调用接口
- 提供生成代码预览界面
- 提供数据库迁移工具界面

### 3.2 系统接口
- 对接agentskills-runtime v0.0.20的RESTful API
- 对接agentskills-runtime的权限管理API
- 对接uctoo数据库（PostgreSQL）
- 对接agentskills-runtime的技能系统
- 遵循UMI全栈模型同构规范

### 3.3 数据接口
- 支持JSON格式数据交换
- 支持分页查询参数标准化
- 支持搜索筛选参数标准化
- 支持MySQL到PostgreSQL数据转换

## 4. 数据需求

### 4.1 数据模型
- 复用uctoo数据库现有表结构（PostgreSQL版本）
- 状态管理模型与数据库表一一对应（UMI同构）
- 支持模型关系映射（一对一、一对多、多对多）
- API返回数据自动保存到本地存储（UMI特性）
- 优先使用本地存储数据（UMI特性）

### 4.2 数据迁移
**uctoo v3数据库完整表结构**：
- 文件：`agentskills-runtime/sql/uctooDB.sql`
- 表数量：150张表
- 说明：uctoo v4复用此表结构，实现平滑升级
- 当前状态：已创建支持uctoo运行的核心必要表
- 扩展策略：如有更多需求可以此表定义为基础进行融合和新建

**源数据**：nestJs/migrations/tinypro.sql（MySQL）
- application表（11条记录）
- i18表（国际化资源）
- lang表（语言配置）
- menu表（菜单配置）
- permission表（权限配置）
- role表（角色配置）
- user表（用户数据）
- 关联表：user_role、role_menu、role_permission

**目标数据**：agentskills-runtime（PostgreSQL）
- 融合到uctoov4InitData.sql
- 转换为PostgreSQL格式
- 保持数据一致性
- 遵循uctooDB.sql定义的表结构规范

### 4.3 数据存储
- 前端不直接存储业务数据
- 可使用localStorage存储用户偏好设置
- 可使用sessionStorage存储临时会话数据
- UMI自动保存机制使用localStorage

## 5. 验收标准

### 5.1 功能验收
- web-admin项目可正常启动运行
- 状态管理库成功迁移UMI特性
- agentskills-runtime v0.0.20成功替代nestJs
- 数据库迁移方案完整可行
- CRUD生成器可成功生成标准CRUD模块
- Entity示例模块通过功能测试

### 5.2 性能验收
- 页面加载性能满足要求
- 代码生成性能满足要求
- API响应性能满足要求
- 无内存泄漏问题

### 5.3 安全验收
- API认证机制正常工作
- 权限控制正确有效
- 无安全漏洞（XSS、CSRF等）
- 敏感信息保护到位

## 6. 附录

### 6.1 参考文档
- tiny-pro项目文档（template/tinyvue）
- tiny-pro NestJS后端文档（template/nestJs）
- tiny-robot-skill技能文档
- tiny-vue-skill技能文档
- pinia-orm官方文档：https://pinia-orm.cycraft.de/
- batchCreateViewFromDb.ts源码
- UMI架构规范（uctoo-api-design-specification.md）
- UMI参考文章：https://mp.weixin.qq.com/s/ja0jfsfkyIK2hdW6bDg2Ow

### 6.2 相关项目
- **web-admin**: `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\web-admin\uctoo-admin` - uctoo v4 web管理后台
- **nestJs**: `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\web-admin\uctoo-admin\nestJs` - 待融合的后端服务
- **agentskills-runtime**: `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime` - 目标后端服务v0.0.20
- **uctoo-app-client-pc**: `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\uctoo-app-client-pc` - 旧项目参考

### 6.3 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2025-01-18 | SDD Agent | 初始版本 |
| 2.0  | 2025-03-28 | SDD Agent | 基于实际开发评估更新需求 |
