# 系统配置管理实现方案设计文档

## 文档信息
- **项目名称**: agentskills-runtime 系统配置管理
- **版本**: v1.0.0
- **创建日期**: 2026-07-18
- **最后更新**: 2026-07-18
- **作者**: spec-design-agent
- **状态**: 待实现
- **关联需求**: spec.md v1.0.0
- **目录规范**: `.codeartsdoer/specs/system-config/design.md`

---

# 一、需求与存量功能关系分析

## 1.1 需求功能与存量功能对比

### 1.1.1 已实现功能

| 需求功能 | 存量功能 | 代码位置 | 匹配度 |
|---------|---------|---------|--------|
| config 表基础 CRUD 操作 | config 表已存在，含 id/name/parent_id/component/key/value/status/creator/created_at/updated_at/deleted_at 字段 | `sql/public20260709.sql:6412-6435` | 50% |
| .env 文件加载与解析 | EnvWrapper.load() 方法可解析 .env 文件并加载到环境变量 | `src/config/config.cj:30-64` | 75% |
| 环境变量读写 | EnvWrapper 提供 `[]` 运算符和 getEnv/setEnv 工具方法 | `src/config/config.cj:17-25` | 50% |
| 标准 CRUD 模块开发框架 | crudgen 生成 Model/DAO/Service/Controller/Route 五层架构 | `src/app/models/uctoo/AipServiceConfigPO.cj`、`src/app/dao/uctoo/AipServiceConfigDAO.cj`、`src/app/services/uctoo/AipServiceConfigService.cj`、`src/app/controllers/uctoo/aip_service_config/AipServiceConfigController.cj`、`src/app/routes/uctoo/aip_service_config/AipServiceConfigRoute.cj` | 75% |
| RBAC 权限中间件 | PermissionMiddleware 和 RowLevelPermissionMiddleware 已实现表级和行级权限控制 | `src/app/middlewares/permission/PermissionMiddleware.cj:12-58` | 75% |
| 前端 pinia-orm Model 规范 | sys_config 等 Model 已定义标准 CRUD API actions 模式 | `src/store/models/uctoo/sys_config.ts` | 50% |
| 文件系统与数据库同步框架 | SyncManager/ChangeDetector/SyncInterceptor 等同步基础设施已实现 | `src/app/services/sync/SyncManager.cj`、`src/app/services/sync/detector/`、`src/app/services/sync/interceptor/` | 50% |
| 审计日志基础设施 | OperateLogService 和 OperateLogMiddleware 已实现操作日志记录 | `src/app/services/uctoo/OperateLogService.cj`、`src/app/core/middleware/OperateLogMiddleware.cj` | 50% |
| 前端路由注册机制 | Vue Router 模块化路由，已有 permission/role/user 等系统管理路由 | `src/router/routes/modules/permission.ts` | 50% |
| 权限表数据注册 | permissions 表已有系统管理相关菜单和路由权限数据 | `sql/public20260709.sql` permissions 表 | 50% |
| 安装配置向导参考 | install.html 实现了分组 Tab 布局的配置界面 | `apps/web-admin/web/public/install.html` | 25% |

### 1.1.2 需要扩展的功能

| 需求功能 | 存量功能 | 差异说明 | 扩展方向 |
|---------|---------|---------|---------|
| config 表扩展字段（env_key/config_group/config_type/is_sensitive 等） | config 表仅有 name/parent_id/component/key/value/status 基础字段 | 缺少 env_key（.env键名映射）、config_group（分组）、config_type（类型）、is_sensitive（敏感标记）、default_value（默认值）、validation_rule（验证规则）、description（描述）、display_order（排序）、editable（可编辑）、last_synced_at（同步时间）10个字段 | 通过增量 SQL 在 config 表上新增字段，保持向后兼容；使用 crudgen 重新生成或手动更新 ConfigPO 模型 |
| .env 文件写入与备份 | EnvWrapper 仅有 load() 读取方法，无写入能力 | 缺少 .env 文件写入、备份、格式保持、原子写入等功能 | 新建 EnvFileService，实现 .env 文件的备份、写入（保持注释格式）、回滚等能力 |
| 配置项验证规则引擎 | 无存量验证框架 | 缺少按 config_type（string/int/bool/url/password/path/json）和 validation_rule 进行输入验证的能力 | 新建 ConfigValidator，基于 config_type 和 validation_rule 元数据实现验证逻辑 |
| 敏感配置项脱敏 | 无脱敏处理逻辑 | 缺少敏感配置项读取时的脱敏显示（前4后4中间*替代） | 在 ConfigService 读取方法中增加脱敏处理分支 |
| config 表与 .env 文件同步 | SyncManager 是通用文件-数据库同步框架，不直接支持 .env 文件格式 | .env 是键值对格式，不同于 Markdown Frontmatter；需要 env_key 与 config 表记录的一一对应映射 | 新建 ConfigSyncHandler 实现 SyncHandler 接口，或独立实现配置同步逻辑，复用 SyncManager 的定时扫描和变更检测基础设施 |
| 配置变更审计日志 | OperateLogService 是通用操作日志，不包含配置变更的前后值对比 | 缺少配置项变更前后值记录、变更通道标记、敏感项脱敏等专用审计信息 | 扩展 OperateLogService 或新建 ConfigAuditLog 专用记录，在 config 表中增加 audit_trail 字段或新建 config_audit_log 表 |
| 命令行配置通道 | CLI 仅有 crontab_cli/skill_cli/tool_cli，无 config 命令 | 缺少 config get/set/unset/export/import 命令 | 新建 config_cli.cj，调用 ConfigService API 实现命令行配置操作 |
| API 配置通道（RESTful 风格） | 标准 CRUD Route 使用 POST /add、POST /edit、POST /del 风格 | 需求要求 RESTful 风格（GET/PUT），且需支持按 key 查询、批量写入、元数据查询等定制接口 | 在 ConfigRoute.registerCustomRoutes() 中注册 RESTful 风格的自定义路由，保留标准 CRUD 路由 |
| 前端可视化配置界面 | 无系统配置管理页面 | 缺少分组 Tab 布局的配置表单、敏感项密码框、元数据驱动的表单渲染 | 新建 Vue 3 组件 system/config/index.vue，参考 install.html 的分组 Tab 布局 |
| 权限与菜单注册 | permissions 表已有数据，但无"系统配置"菜单和 config:read/config:write 权限 | 需新增系统配置菜单项、API 路由权限、i18n 国际化 key | 输出增量 SQL 到 sql/incremental/ 目录 |

### 1.1.3 需要新增的功能或接口

**后端（agentskills-runtime 仓颉模块）**：

1. **ConfigPO 模型扩展**：在现有 config 表基础上新增 10 个字段的 ORM 映射
2. **EnvFileService**：.env 文件读写服务，包含备份、原子写入、格式保持、回滚
3. **ConfigValidator**：配置项验证引擎，基于 config_type 和 validation_rule
4. **ConfigService 扩展**：在标准 CRUD Service 基础上增加配置专用业务逻辑（脱敏、同步、审计）
5. **ConfigController 扩展**：RESTful 风格的配置 API（GET/PUT/batch/metadata）
6. **ConfigRoute 扩展**：注册自定义 RESTful 路由
7. **ConfigSyncHandler**：config 表与 .env 文件的一致性同步处理器
8. **config_cli**：命令行配置通道
9. **增量 SQL**：config 表结构变更、权限菜单注册、i18n 注册

**前端（web-admin Vue 3 组件）**：

1. **config pinia-orm Model**：配置项前端数据模型和 API actions
2. **system/config/index.vue**：系统配置管理主页面（分组 Tab + 表单）
3. **路由注册**：system/config 路由模块
4. **i18n 国际化**：菜单和界面文本的多语言支持

## 1.2 存量功能详细分析

### 1.2.1 config 表结构

**接口契约**：
- 表名：`public.config`
- 主键：`id` (uuid, 自动生成)
- 业务字段：`name`（配置名称）、`parent_id`（父级配置UUID）、`component`（tab组件名）、`key`（配置键名）、`value`（配置键值）、`status`（1启用/0禁用）
- 审计字段：`creator`（创建人UUID）、`created_at`、`updated_at`、`deleted_at`
- 现有数据：基础配置、上传配置、微信配置、腾讯云配置、SaaS配置、认证鉴权等分组配置

**业务规则**：
- 采用 parent_id 实现配置分组的树形结构（parent_id 为 NULL 的是分组，非 NULL 的是配置项）
- component 字段标识分组对应的 tab 组件名
- key 字段为配置键名，value 字段为配置键值
- status 字段控制启用/禁用

**约束**：
- 现有 config 表的 key 字段与 .env 文件的键名无对应关系
- 现有数据是面向 web-admin 前端站点配置的，与 agentskills-runtime 的 .env 配置是两套体系
- 需要通过新增 env_key 字段建立 config 表记录与 .env 键名的映射

### 1.2.2 EnvWrapper（.env 文件加载器）

**接口契约**：
- `load(path: Path): String`：从指定路径加载 .env 文件到环境变量
- `[](name: String): Option<String>`：读取环境变量
- `[](name: String, value!: String): Unit`：设置环境变量

**业务规则**：
- 使用正则 `^\s*([\w.]+)\s*=\s*("[^"]*"|'[^']*'|[^#]*)\s*(?:#.*)?$` 解析键值对
- 已设置的环境变量不会被覆盖
- 支持引号包裹的值（自动去除引号）

**扩展点**：
- EnvWrapper 是 struct 类型，无法继承，需新建独立的 EnvFileService
- 需要在 EnvWrapper 的正则解析基础上增加写入能力（保持注释和格式）

**约束**：
- 当前仅支持读取，不支持写入
- 不支持备份和回滚
- 不支持文件变更监听

### 1.2.3 标准 CRUD 模块架构（以 AipServiceConfig 为例）

**接口契约**：
- **Model**：`@DataAssist[fields]` + `@QueryMappersGenerator["table_name"]` + `@ORMField['column']` 注解驱动的 PO 类
- **DAO**：封装 f_orm 的 SqlExecutor 操作，提供 findXxxById/insertXxx/updateXxx/deleteXxx 等方法
- **Service**：业务逻辑层，提供 CRUD + 权限控制 + 分页查询 + 排序过滤
- **Controller**：HTTP 请求处理，包含 add/edit/delete/getSingle/getMany 等方法
- **Route**：路由注册，标准路径 `/api/v1/uctoo/{table_name}/add|edit|del|:id|:limit/:page`

**业务规则**：
- 所有 PO 类必须包含 id/creator/created_at/updated_at/deleted_at 基础字段
- 支持软删除（deleted_at 字段）
- 支持行级权限控制（createWithPermission/updateWithPermission/deleteWithPermission/getByIdWithPermission）
- 支持批量操作（ids 参数）
- 支持导出功能

**扩展点**：
- Controller 和 Route 均有 `registerCustomRoutes()` / 自定义引入区域，支持在标准 CRUD 基础上扩展
- Service 层支持通过继承或组合方式扩展业务逻辑

**约束**：
- 标准 CRUD 路由使用 POST 方法（add/edit/del），不遵循 RESTful 规范
- 需要在 registerCustomRoutes() 中注册 RESTful 风格的额外路由
- AutoRouteConfig.cj 由 crudgen 自动生成，新增模块需在此文件中注册

### 1.2.4 SyncManager（文件系统与数据库同步框架）

**接口契约**：
- `initialize(agentBasePath, skillBasePath)`：初始化同步管理器
- `syncAll(triggerSource)`：执行全量同步
- ChangeDetector：基于文件修改时间戳检测变更
- SyncInterceptor：AOP 切面拦截 DAO 操作触发反向同步
- SyncHandler：实体类型同步处理器接口

**业务规则**：
- 采用 Last-Write-Wins 冲突解决策略
- 支持 Markdown Frontmatter 格式的文件解析
- 通过 SyncContext（ThreadLocal）防止循环同步
- 支持定时扫描和启动时全量同步

**扩展点**：
- SyncHandler 接口可注册新的实体类型同步处理器
- ChangeDetector 可扩展新的文件格式检测

**约束**：
- 当前仅支持 Markdown Frontmatter 格式，不支持 .env 键值对格式
- 同步方向是文件 ↔ 数据库双向，但 .env 同步需求是"文件为主、数据库为辅"的单向主同步
- 需要新建 ConfigSyncHandler 适配 .env 格式，或独立实现配置同步逻辑

### 1.2.5 前端 pinia-orm Model 规范

**接口契约**：
- 继承 `Model` 类，使用 `@Uid/@Str/@Num/@Bool/@Attr` 装饰器定义字段
- `static override entity` 定义实体名
- `static override config.axiosApi.actions` 定义 API 操作方法
- 标准 actions：getList、getSingle、add、edit、delete、restore、emptyRecycleBin

**业务规则**：
- API 路径格式：`/api/v1/uctoo/{entity_name}/${pageSize}/${page}`
- 认证方式：Bearer Token（从 localStorage 获取 accessToken）
- baseURL 从 `import.meta.env.VITE_BACKEND_URL` 读取

**约束**：
- 当前 sys_config Model 的字段与 config 表不匹配（sys_config 有 config_key/config_value，config 表有 name/key/value）
- 需要新建 config Model 或更新 sys_config Model 以匹配扩展后的 config 表结构

---

# 二、整体架构设计

## 2.1 系统架构图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          系统配置管理 整体架构                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────────┐  │
│  │  命令行通道   │  │  API 通道     │  │       界面通道 (web-admin)        │  │
│  │  config_cli  │  │  RESTful API │  │  system/config/index.vue        │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┬───────────────────┘  │
│         │                 │                         │                      │
│         └────────┬────────┘                         │                      │
│                  │          HTTP 请求                │                      │
│                  ▼                                  ▼                      │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      接入层 (Entry Layer)                             │   │
│  │  ┌─────────────────┐  ┌──────────────────────────────────────────┐  │   │
│  │  │ ConfigRoute      │  │ ConfigController                        │  │   │
│  │  │ (标准CRUD路由 +   │  │ (标准CRUD方法 + RESTful扩展方法)         │  │   │
│  │  │  RESTful扩展路由) │  │                                          │  │   │
│  │  └────────┬────────┘  └──────────────────┬───────────────────────┘  │   │
│  └───────────┼──────────────────────────────┼──────────────────────────┘   │
│              │                              │                              │
│  ┌───────────┼──────────────────────────────┼──────────────────────────┐   │
│  │           │      服务层 (Service Layer)   │                          │   │
│  │  ┌────────▼──────────────────────────────▼───────────────────────┐  │   │
│  │  │                    ConfigService                               │  │   │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐   │  │   │
│  │  │  │ 脱敏处理      │  │ 审计日志      │  │ 配置同步协调       │   │  │   │
│  │  │  │ maskSensitive │  │ auditLog     │  │ syncConfig        │   │  │   │
│  │  │  └──────────────┘  └──────────────┘  └───────────────────┘   │  │   │
│  │  └──────────────────────────┬───────────────────────────────────┘  │   │
│  │                             │                                      │   │
│  │  ┌──────────────────────────▼───────────────────────────────────┐  │   │
│  │  │                   EnvFileService                              │  │   │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │  │   │
│  │  │  │ readEnv  │  │ writeEnv │  │ backupEnv│  │ restoreEnv │  │  │   │
│  │  │  └──────────┘  └──────────┘  └──────────┘  └────────────┘  │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  │                                                                     │   │
│  │  ┌──────────────────────────────────────────────────────────────┐  │   │
│  │  │                   ConfigValidator                             │  │   │
│  │  │  validate(type, rule, value) -> ValidationResult             │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│              │                              │                              │
│  ┌───────────┼──────────────────────────────┼──────────────────────────┐   │
│  │           │      同步层 (Sync Layer)      │                          │   │
│  │  ┌────────▼──────────────────────────────▼───────────────────────┐  │   │
│  │  │                 ConfigSyncHandler                              │  │   │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐   │  │   │
│  │  │  │ startupSync  │  │ dualWrite    │  │ scheduledSync     │   │  │   │
│  │  │  │ (启动全量同步) │  │ (双写同步)   │  │ (定时增量同步)    │   │  │   │
│  │  │  └──────────────┘  └──────────────┘  └───────────────────┘   │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│              │                              │                              │
│  ┌───────────┼──────────────────────────────┼──────────────────────────┐   │
│  │           │      数据层 (Data Layer)      │                          │   │
│  │  ┌────────▼────────┐  ┌──────────────────▼───────────────────────┐  │   │
│  │  │ ConfigDAO        │  │ .env 文件 (source of truth)             │  │   │
│  │  │ (f_orm CRUD)     │  │ 读写/备份/回滚                           │  │   │
│  │  └────────┬────────┘  └──────────────────────────────────────────┘  │   │
│  └───────────┼─────────────────────────────────────────────────────────┘   │
│              │                                                              │
│              ▼                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     PostgreSQL (config 表)                            │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     基础设施层 (Infrastructure)                       │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐ │   │
│  │  │  f_orm   │  │ f_config │  │ RBAC     │  │ OperateLogService    │ │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────────────┘ │   │
│  │  ┌──────────┐  ┌──────────────────────────────────────────────────┐ │   │
│  │  │ SyncMgr  │  │ SyncLogService (复用)                            │ │   │
│  │  └──────────┘  └──────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 2.2 模块依赖关系

```
config_cli ──────────┐
                      │
ConfigRoute ──────────┼──► ConfigController ──► ConfigService ──┬──► ConfigDAO
                      │                                       │
web-admin Vue ────────┘                                       ├──► EnvFileService
                                                              ├──► ConfigValidator
                                                              ├──► ConfigSyncHandler
                                                              └──► OperateLogService
                                                                        │
ConfigSyncHandler ──► EnvFileService ──► .env 文件                       │
                 ──► ConfigDAO ──► config 表                             │
                 ──► SyncLogService (复用)                               │
```

**模块依赖说明**：

| 模块 | 依赖 | 被依赖 | 说明 |
|------|------|--------|------|
| ConfigRoute | ConfigController | AutoRouteRegistry | 路由注册入口 |
| ConfigController | ConfigService | ConfigRoute | HTTP 请求处理 |
| ConfigService | ConfigDAO, EnvFileService, ConfigValidator, ConfigSyncHandler, OperateLogService | ConfigController, config_cli | 核心业务编排 |
| ConfigDAO | f_orm | ConfigService, ConfigSyncHandler | 数据库访问 |
| EnvFileService | std.fs, std.regex | ConfigService, ConfigSyncHandler | .env 文件读写 |
| ConfigValidator | 无外部依赖 | ConfigService | 输入验证 |
| ConfigSyncHandler | ConfigDAO, EnvFileService, SyncLogService | ConfigService | 配置同步 |
| config_cli | ConfigService | 无 | 命令行入口 |

## 2.3 技术选型说明

| 技术领域 | 选型 | 选型理由 |
|---------|------|---------|
| 后端语言 | 仓颉（Cangjie） | 项目技术栈要求，使用 cjpm 项目结构 |
| ORM 框架 | f_orm（本地 libs 依赖） | 项目标准 ORM 框架，crudgen 代码生成器配套 |
| 数据库 | PostgreSQL | 项目标准数据库，config 表已存在 |
| HTTP 框架 | fountain/spire（内置 HTTPServer/Router） | 项目标准 HTTP 框架 |
| 前端框架 | Vue 3 + tiny-pro | web-admin 项目技术栈 |
| 前端状态管理 | pinia-orm | 项目标准 ORM 状态管理，与后端 API 对应 |
| 配置文件格式 | .env（键值对） | agentskills-runtime 已有 .env 配置格式 |
| 同步框架 | 复用 SyncManager 基础设施 | 已有文件-数据库同步框架，扩展 .env 格式支持 |
| 权限控制 | RBAC（permissions 表 + PermissionMiddleware） | 项目标准权限体系 |
| 审计日志 | 复用 OperateLogService | 项目标准操作日志服务 |
| 代码生成 | crudgen + crudweb | 项目标准 CRUD 模块生成工具 |

---

# 三、后端模块设计

## 3.1 config 表扩展方案

config 表在现有字段基础上新增 10 个字段，所有新增字段均设置默认值，确保向后兼容。

**新增字段**：

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| env_key | varchar | NULL | 对应 .env 文件中的键名，唯一约束 |
| config_group | varchar | 'other' | 配置分组标识 |
| config_type | varchar | 'string' | 配置项类型 |
| is_sensitive | bool | false | 是否敏感配置项 |
| default_value | varchar | NULL | 默认值 |
| validation_rule | varchar | NULL | 验证规则描述 |
| description | varchar | NULL | 描述说明 |
| display_order | int4 | 0 | 显示排序 |
| editable | bool | true | 是否可编辑 |
| last_synced_at | timestamptz | NULL | 最后同步时间 |

**设计决策**：
- env_key 允许 NULL：现有 config 表数据（站点配置等）可能没有 .env 对应项，NULL 表示该记录不参与 .env 同步
- config_group 默认 'other'：未指定分组的配置项归入"其他"分组
- is_sensitive 默认 false：安全优先，默认非敏感
- editable 默认 true：默认可编辑，仅特殊项（如 NODE_ENV）标记为不可编辑

## 3.2 ConfigPO 模型设计

**文件位置**：`src/app/models/uctoo/ConfigPO.cj`

**设计原则**：
- 使用 `@DataAssist[fields]` + `@QueryMappersGenerator["config"]` + `@ORMField['column']` 注解
- 包含现有字段和新增字段的完整映射
- 使用 crudgen 从扩展后的 config 表重新生成，或手动更新现有 ConfigPO（如存在）

**核心字段映射**：

| ORM 字段名 | @ORMField 注解值 | 仓颉类型 | 默认值 |
|------------|------------------|---------|--------|
| id | 'id' | String | "" |
| name | 'name' | String | "" |
| parentId | 'parent_id' | Option\<String\> | None |
| component | 'component' | String | "" |
| key | 'key' | String | "" |
| value | 'value' | Option\<String\> | None |
| status | 'status' | Int32 | 1 |
| creator | 'creator' | Option\<String\> | None |
| createdAt | 'created_at' | DateTime | DateTime.now() |
| updatedAt | 'updated_at' | DateTime | DateTime.now() |
| deletedAt | 'deleted_at' | Option\<DateTime\> | None |
| envKey | 'env_key' | Option\<String\> | None |
| configGroup | 'config_group' | String | "other" |
| configType | 'config_type' | String | "string" |
| isSensitive | 'is_sensitive' | Bool | false |
| defaultValue | 'default_value' | Option\<String\> | None |
| validationRule | 'validation_rule' | Option\<String\> | None |
| description | 'description' | Option\<String\> | None |
| displayOrder | 'display_order' | Int32 | 0 |
| editable | 'editable' | Bool | true |
| lastSyncedAt | 'last_synced_at' | Option\<DateTime\> | None |

**JSON 序列化**：使用 `toJsonValue()` / `fromJsonValue()` 方法，由 `@DataAssist[fields]` 宏自动生成。

## 3.3 ConfigDAO 设计

**文件位置**：`src/app/dao/uctoo/ConfigDAO.cj`

**设计原则**：
- 由 crudgen 自动生成标准 DAO 方法
- 在自定义区域增加配置专用查询方法

**标准 DAO 方法**（crudgen 生成）：
- `findConfigById(id)` / `insertConfig(entity)` / `updateConfig(entity)` / `deleteConfigById(id)`
- `softDeleteConfigById(id)` / `restoreConfigById(id)`
- `findAllConfigPage(page, pageSize)` / `findConfigByCondition(where, orderBy, page, pageSize)`
- `batchDeleteConfig(ids)` / `batchSoftDeleteConfig(ids)`

**自定义扩展方法**（在自定义引入区域添加）：
- `findConfigByEnvKey(envKey: String): Option<ConfigPO>` — 按 .env 键名查询配置项
- `findConfigsByGroup(configGroup: String): ArrayList<ConfigPO>` — 按分组查询配置项列表
- `findAllEnvConfigs(): ArrayList<ConfigPO>` — 查询所有有 env_key 的配置项（env_key IS NOT NULL）
- `upsertByEnvKey(entity: ConfigPO): Int64` — 按 env_key 执行 upsert（INSERT ON CONFLICT UPDATE）

## 3.4 ConfigService 设计

**文件位置**：`src/app/services/uctoo/ConfigService.cj`

**设计原则**：
- 继承标准 CRUD Service 模式（由 crudgen 生成基础方法）
- 在自定义区域增加配置专用业务逻辑
- 组合 EnvFileService、ConfigValidator、ConfigSyncHandler

**标准 CRUD 方法**（crudgen 生成）：
- `create(entity, creatorId)` / `update(entityId, entity)` / `delete(entityId, force)`
- `getById(entityId)` / `getList(page, pageSize)` / `getListWithFilter(page, pageSize, sort, filter)`
- 带权限版本：`createWithPermission` / `updateWithPermission` / `deleteWithPermission` / `getByIdWithPermission` / `getListWithPermission`

**自定义扩展方法**：

| 方法签名 | 业务说明 |
|---------|---------|
| `getConfigByKey(envKey: String): APIResult<ConfigPO>` | 按 .env 键名读取配置项，敏感项脱敏后返回 |
| `getConfigsByGroup(group: String): APIResult<ArrayList<ConfigPO>>` | 按分组读取配置项列表，敏感项脱敏后返回 |
| `getAllConfigs(): APIResult<ArrayList<ConfigPO>>` | 全量读取配置项，敏感项脱敏后返回 |
| `getConfigMetadata(): APIResult<ArrayList<ConfigMetadataVO>>` | 获取所有配置项的元数据（不含值，用于前端表单渲染） |
| `updateConfigByKey(envKey: String, value: String, operatorId: String, channel: String): APIResult<ConfigPO>` | 按 .env 键名写入配置项（验证 → 备份 → 写 .env → 同步 config 表 → 审计日志） |
| `batchUpdateConfigs(items: ArrayList<ConfigUpdateItem>, operatorId: String, channel: String): APIResult<ArrayList<ConfigPO>>` | 批量写入配置项（≤50项） |
| `exportConfig(format: String): APIResult<String>` | 导出配置（JSON 或 .env 格式） |
| `importConfig(data: String, format: String, operatorId: String): APIResult<Bool>` | 导入配置 |
| `maskSensitiveValue(value: String): String` | 敏感值脱敏（前4后4，中间 * 替代） |
| `syncFromEnvFile(): APIResult<Bool>` | 手动触发从 .env 文件同步到 config 表 |

**核心业务流程（updateConfigByKey）**：

```
1. 根据 envKey 查询 ConfigPO，获取 configType/isSensitive/validationRule
2. ConfigValidator.validate(configType, validationRule, value)
   ├── 验证失败 → 返回 CONFIG_VALIDATION_FAILED
3. EnvFileService.backup(envFilePath)
4. EnvFileService.writeEnvKeyValue(envFilePath, envKey, value)
   ├── 写入失败 → EnvFileService.restoreBackup() → 返回 CONFIG_WRITE_FAILED
5. ConfigDAO.upsertByEnvKey(entity)  // 同步更新 config 表
6. OperateLogService.recordConfigAudit(envKey, oldValue, maskedNewValue, channel, operatorId)
7. 返回更新后的 ConfigPO（敏感项脱敏）
```

## 3.5 ConfigController 设计

**文件位置**：`src/app/controllers/uctoo/config/ConfigController.cj`

**设计原则**：
- 由 crudgen 生成标准 CRUD 方法（add/edit/delete/getSingle/getMany）
- 在自定义引入区域增加 RESTful 风格的配置专用方法

**标准 CRUD 方法**（crudgen 生成，路由前缀 `/api/v1/uctoo/config`）：
- `add(req, res)` — POST /api/v1/uctoo/config/add
- `edit(req, res)` — POST /api/v1/uctoo/config/edit
- `delete(req, res)` — POST /api/v1/uctoo/config/del
- `getSingle(req, res)` — GET /api/v1/uctoo/config/:id
- `getManyWithPathParams(req, res)` — GET /api/v1/uctoo/config/:limit/:page

**RESTful 扩展方法**（在自定义引入区域添加）：

| 方法名 | HTTP 方法 | 路由路径 | 业务说明 |
|--------|----------|---------|---------|
| `getConfigs` | GET | /api/v1/uctoo/config | 读取全部/分组配置项 |
| `getConfigByKey` | GET | /api/v1/uctoo/config/:key | 按 .env 键名读取单个配置项 |
| `updateConfigByKey` | PUT | /api/v1/uctoo/config/:key | 按 .env 键名写入单个配置项 |
| `batchUpdateConfigs` | PUT | /api/v1/uctoo/config/batch | 批量写入配置项 |
| `getConfigMetadata` | GET | /api/v1/uctoo/config/metadata | 获取配置元数据 |
| `exportConfig` | GET | /api/v1/uctoo/config/export | 导出配置 |
| `importConfig` | POST | /api/v1/uctoo/config/import | 导入配置 |

**权限校验**：
- GET 方法：检查 `config:read` 权限
- PUT/POST 方法：检查 `config:write` 权限
- 通过 `req.getLocals("user")` 获取当前用户，使用 PermissionUtils 校验

## 3.6 ConfigRoute 设计

**文件位置**：`src/app/routes/uctoo/config/ConfigRoute.cj`

**设计原则**：
- 由 crudgen 生成标准路由注册
- 在 `registerCustomRoutes()` 中注册 RESTful 扩展路由
- **关键**：自定义路由必须在标准动态路由（:id）之前注册，避免 :key 被 :id 匹配

**路由注册顺序**：

```
registerCustomRoutes():
  1. GET  /api/v1/uctoo/config/metadata      → controller.getConfigMetadata
  2. GET  /api/v1/uctoo/config/export         → controller.exportConfig
  3. PUT  /api/v1/uctoo/config/batch           → controller.batchUpdateConfigs
  4. POST /api/v1/uctoo/config/import          → controller.importConfig
  5. GET  /api/v1/uctoo/config/:key            → controller.getConfigByKey
  6. PUT  /api/v1/uctoo/config/:key            → controller.updateConfigByKey

标准路由（crudgen 生成）：
  7. POST /api/v1/uctoo/config/add             → controller.add
  8. POST /api/v1/uctoo/config/edit            → controller.edit
  9. POST /api/v1/uctoo/config/del             → controller.delete
  10. GET  /api/v1/uctoo/config/:id             → controller.getSingle
  11. GET  /api/v1/uctoo/config/:limit/:page    → controller.getManyWithPathParams
```

**路由冲突避免**：
- `:key` 和 `:id` 都是动态路径参数，但 key 是 .env 键名（如 LOG_LEVEL），id 是 UUID
- `metadata`、`export`、`batch`、`import` 是固定路径，必须在 `:key` 之前注册
- GET /api/v1/uctoo/config（无参数）用于读取全部/分组配置，通过 queryParam `group` 过滤

## 3.7 EnvFileService 设计

**文件位置**：`src/app/services/uctoo/EnvFileService.cj`（新建）

**设计原则**：
- 独立于 EnvWrapper，提供完整的 .env 文件读写能力
- 复用 EnvWrapper 的正则解析逻辑
- 保持 .env 文件的注释和格式不变

**核心方法**：

| 方法签名 | 业务说明 |
|---------|---------|
| `getEnvFilePath(): String` | 解析 .env 文件路径（支持环境变量覆盖、跨平台路径） |
| `readAllEnvValues(path: String): HashMap<String, String>` | 读取 .env 文件所有键值对 |
| `readEnvValue(path: String, key: String): Option<String>` | 读取 .env 文件指定键名的值 |
| `writeEnvKeyValue(path: String, key: String, value: String): Bool` | 写入单个键值对（保持注释和格式） |
| `writeEnvKeyValues(path: String, items: HashMap<String, String>): Bool` | 批量写入键值对 |
| `backupEnvFile(path: String): Option<String>` | 备份 .env 文件（.env.backup-{timestamp}） |
| `restoreBackup(backupPath: String, targetPath: String): Bool` | 从备份恢复 .env 文件 |
| `parseEnvFile(content: String): ArrayList<EnvLine>` | 解析 .env 文件内容为行列表（含注释行、空行、键值行） |
| `serializeEnvFile(lines: ArrayList<EnvLine>): String` | 将行列表序列化为 .env 文件内容 |

**.env 文件写入流程**：

```
1. 读取 .env 文件全部内容
2. parseEnvFile() 解析为行列表（保留注释行和空行）
3. 在行列表中查找匹配 key 的键值行
   ├── 找到 → 更新该行的值
   └── 未找到 → 在文件末尾追加新的键值行
4. serializeEnvFile() 将行列表序列化为字符串
5. 原子写入：先写入临时文件，再 rename 覆盖原文件
```

**EnvLine 数据结构**：

| 字段 | 类型 | 说明 |
|------|------|------|
| lineType | Enum(Comment, Blank, KeyValue) | 行类型 |
| key | Option\<String\> | 键名（仅 KeyValue 类型） |
| value | Option\<String\> | 值（仅 KeyValue 类型） |
| rawLine | String | 原始行内容（用于保持格式） |

## 3.8 ConfigValidator 设计

**文件位置**：`src/app/services/uctoo/ConfigValidator.cj`（新建）

**设计原则**：
- 基于 config_type 和 validation_rule 进行输入验证
- 验证失败返回具体的错误信息（字段名 + 验证规则）
- 无状态工具类，所有方法为纯函数

**核心方法**：

| 方法签名 | 业务说明 |
|---------|---------|
| `validate(configType: String, validationRule: Option<String>, value: String): ValidationResult` | 综合验证入口 |
| `validateString(value: String): ValidationResult` | 字符串类型验证（非空） |
| `validateInt(value: String): ValidationResult` | 整数类型验证（可解析为 Int32） |
| `validateBool(value: String): ValidationResult` | 布尔类型验证（true/false） |
| `validateUrl(value: String): ValidationResult` | URL 类型验证（格式合法性） |
| `validatePassword(value: String): ValidationResult` | 密码类型验证（不验证内容，仅非空） |
| `validatePath(value: String): ValidationResult` | 路径类型验证（可选验证存在性） |
| `validateJson(value: String): ValidationResult` | JSON 类型验证（可解析为合法 JSON） |
| `validateByRule(rule: String, value: String): ValidationResult` | 按自定义规则验证 |

**ValidationResult 数据结构**：

| 字段 | 类型 | 说明 |
|------|------|------|
| isValid | Bool | 是否验证通过 |
| errorMessage | Option\<String\> | 验证失败时的错误信息 |

**内置验证规则**：

| 规则格式 | 说明 | 示例 |
|---------|------|------|
| `port:1-65535` | 端口号范围验证 | PORT 配置项 |
| `url` | URL 格式验证 | DATABASE_URL 配置项 |
| `bool:true\|false` | 布尔值验证 | ENABLE_XXX 配置项 |
| `not_empty` | 非空验证 | 必填配置项 |
| `path:exists` | 路径存在性验证（可选） | SKILL_INSTALL_PATH |

## 3.9 ConfigSyncHandler 设计

**文件位置**：`src/app/services/uctoo/ConfigSyncHandler.cj`（新建）

**设计原则**：
- 独立实现配置同步逻辑，不复用 SyncManager 的 SyncHandler 接口（.env 格式与 Markdown Frontmatter 差异太大）
- 复用 SyncManager 的定时扫描基础设施（CrontabScheduler）
- 复用 SyncLogService 记录同步日志

**核心方法**：

| 方法签名 | 业务说明 |
|---------|---------|
| `startupSync(): SyncResult` | 启动时全量同步：.env → config 表 |
| `dualWrite(envKey: String, value: String): SyncResult` | API 写入时双写：.env + config 表 |
| `scheduledSync(): SyncResult` | 定时增量同步：检测 .env 变更 → config 表 |
| `manualSyncFromEnv(): SyncResult` | 手动触发：.env → config 表 |
| `resolveConflict(envKey: String, envValue: String, dbValue: String): String` | 冲突解决：以 .env 值为准 |

**启动同步流程**：

```
1. EnvFileService.readAllEnvValues() 读取 .env 全部键值对
2. 遍历每个键值对：
   a. ConfigDAO.findConfigByEnvKey(key) 查询 config 表
   b. 如果存在 → 比较值是否一致
      ├── 一致 → 更新 last_synced_at
      └── 不一致 → 以 .env 值为准，更新 config 表 value 字段
   c. 如果不存在 → 在 config 表中 upsert 新记录（env_key = key, value = envValue）
3. 记录同步日志到 sync_log 表
4. 返回同步结果（总数/成功数/失败数）
```

**定时同步流程**：

```
1. 获取 .env 文件的最后修改时间
2. 与上次同步时间比较
   ├── 未变更 → 跳过
   └── 已变更 → 执行增量同步
3. 增量同步：仅同步有差异的配置项
4. 记录同步日志
```

**SyncResult 数据结构**：

| 字段 | 类型 | 说明 |
|------|------|------|
| totalCount | Int32 | 同步总数 |
| successCount | Int32 | 成功数 |
| failedCount | Int32 | 失败数 |
| details | ArrayList\<SyncDetail\> | 同步详情列表 |

## 3.10 config_cli 设计

**文件位置**：`src/cli/config_cli.cj`（新建）

**设计原则**：
- 遵循 runtime 项目 CLI 规范（参考 crontab_cli.cj / skill_cli.cj）
- 通过 HTTP 请求调用 ConfigService 的 API 接口
- 支持认证凭据传递（Token 或用户名/密码）

**命令列表**：

| 命令 | 参数 | 说明 |
|------|------|------|
| `config get <key>` | key: .env 键名 | 读取单个配置项 |
| `config list` | --group: 分组名（可选）, --json: JSON输出（可选） | 列出配置项 |
| `config set <key> <value>` | key: .env 键名, value: 配置值 | 写入配置项 |
| `config unset <key>` | key: .env 键名 | 标记配置项为禁用 |
| `config export` | --format: json\|env（可选，默认env） | 导出配置 |
| `config import --file <path>` | --format: json\|env（可选）, --file: 文件路径 | 导入配置 |

**CLI 执行流程**：

```
1. 解析命令行参数
2. 获取认证凭据（从环境变量 CONFIG_CLI_TOKEN 或命令行 --token 参数）
3. 构造 HTTP 请求（携带 Authorization: Bearer <token>）
4. 调用对应的 ConfigService API
5. 格式化输出结果（表格或 JSON）
```

---

# 四、前端模块设计

## 4.1 config pinia-orm Model 设计

**文件位置**：`apps/web-admin/web/src/store/models/uctoo/config.ts`（新建）

**设计原则**：
- 遵循项目 pinia-orm Model 规范
- 字段与扩展后的 config 表一一对应
- API actions 包含标准 CRUD + RESTful 扩展

**Model 字段定义**：

| 装饰器 | 字段名 | 类型 | 说明 |
|--------|--------|------|------|
| @Uid() | id | string | 主键 |
| @Str('') | name | string | 配置名称 |
| @Str('') | parentId | string | 父级配置ID |
| @Str('') | component | string | tab 组件名 |
| @Str('') | key | string | 配置键名 |
| @Str('') | value | string | 配置键值 |
| @Num(1) | status | number | 状态 |
| @Str('') | creator | string | 创建人 |
| @Attr('') | createdAt | string | 创建时间 |
| @Attr('') | updatedAt | string | 更新时间 |
| @Attr('') | deletedAt | string | 删除时间 |
| @Str('') | envKey | string | .env 键名 |
| @Str('other') | configGroup | string | 配置分组 |
| @Str('string') | configType | string | 配置类型 |
| @Bool(false) | isSensitive | boolean | 是否敏感 |
| @Str('') | defaultValue | string | 默认值 |
| @Str('') | validationRule | string | 验证规则 |
| @Str('') | description | string | 描述说明 |
| @Num(0) | displayOrder | number | 显示排序 |
| @Bool(true) | editable | boolean | 是否可编辑 |
| @Attr('') | lastSyncedAt | string | 最后同步时间 |

**API Actions**：

| Action 名 | HTTP 方法 | API 路径 | 说明 |
|-----------|----------|---------|------|
| getConfigList | GET | /api/v1/uctoo/config/{pageSize}/{page} | 标准分页列表 |
| getConfig | GET | /api/v1/uctoo/config/{id} | 按 ID 获取 |
| addConfig | POST | /api/v1/uctoo/config/add | 新增 |
| editConfig | POST | /api/v1/uctoo/config/edit | 编辑 |
| deleteConfig | POST | /api/v1/uctoo/config/del | 删除 |
| getAllConfigs | GET | /api/v1/uctoo/config | 读取全部/分组配置 |
| getConfigByKey | GET | /api/v1/uctoo/config/{key} | 按 .env 键名读取 |
| updateConfigByKey | PUT | /api/v1/uctoo/config/{key} | 按 .env 键名写入 |
| batchUpdateConfigs | PUT | /api/v1/uctoo/config/batch | 批量写入 |
| getConfigMetadata | GET | /api/v1/uctoo/config/metadata | 获取元数据 |

## 4.2 系统配置页面组件设计

**文件位置**：`apps/web-admin/web/src/views/system/config/index.vue`（新建）

**页面布局**：

```
┌──────────────────────────────────────────────────────┐
│  系统配置                              [导出] [导入]  │
├──────────────────────────────────────────────────────┤
│  [日志配置] [环境配置] [数据库配置] [SSL配置]          │
│  [模型配置] [API密钥配置] [技能配置] [邮件配置]        │
│  [存储配置] [Token配置] [其他]                         │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │  LOG_LEVEL        [debug        ▼]  日志级别    │  │
│  │  LOG_FILE         [./logs/xxx      ]  日志文件   │  │
│  │  ENABLE_AGENT_LOG [✓]  启用Agent日志            │  │
│  │  AGENT_LOG_DIR    [./logs/agent    ]  日志目录   │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│                              [恢复默认] [保存]        │
└──────────────────────────────────────────────────────┘
```

**组件结构**：

| 组件 | 职责 | 说明 |
|------|------|------|
| `index.vue` | 主页面容器 | 加载元数据和配置值，渲染分组 Tab 和表单 |
| `ConfigGroupTab` | 分组 Tab 组件 | 渲染分组标签页，切换分组时加载对应配置项 |
| `ConfigFormItem` | 配置项表单控件 | 根据 configType 渲染不同控件（文本框/密码框/开关/数字输入等） |

**表单控件与 configType 映射**：

| configType | 表单控件 | tiny-pro 组件 |
|-----------|---------|--------------|
| string | 文本输入框 | t-input |
| int | 数字输入框 | t-input-number |
| bool | 开关 | t-switch |
| url | URL 输入框 | t-input |
| password | 密码输入框 | t-input type="password" |
| path | 路径输入框 | t-input |
| json | 文本域 | t-textarea |

**页面交互流程**：

```
1. 页面加载 → 调用 getConfigMetadata() 获取元数据
2. 调用 getAllConfigs() 获取当前配置值
3. 根据 configGroup 分组渲染 Tab
4. 每个分组内按 displayOrder 排序渲染 ConfigFormItem
5. 敏感项使用密码框，显示脱敏值
6. 用户修改配置项 → 点击"保存"
7. 前端表单验证（基于 configType 和 validationRule）
8. 验证通过 → 调用 batchUpdateConfigs() 批量提交变更
9. 后端返回结果 → 显示成功/失败提示
10. 保存成功 → 刷新页面数据
```

## 4.3 路由注册设计

**文件位置**：`apps/web-admin/web/src/router/routes/modules/system.ts`（新建或扩展）

**路由配置**：

```typescript
// system.ts
export default {
  path: 'system',
  name: 'System',
  component: () => import('@/layout/default-layout.vue'),
  meta: {
    locale: 'menu.systemManager',
    requiresAuth: true,
    order: 8,
    roles: [RoleType.admin],
  },
  children: [
    {
      path: 'config',
      name: 'SystemConfig',
      component: () => import('@/views/system/config/index.vue'),
      meta: {
        locale: 'menu.systemManager.systemConfig',
        requiresAuth: true,
        roles: [RoleType.admin],
      },
    },
  ],
}
```

**设计说明**：
- "系统管理"（systemManager）作为一级菜单，"系统配置"（systemConfig）作为二级菜单
- 路由权限通过 meta.roles 限制为管理员角色
- 菜单显示通过 permissions 表数据和 i18n 配置驱动

## 4.4 i18n 国际化设计

**菜单国际化 key**：

| key | 中文 | 英文 |
|-----|------|------|
| menu.systemManager | 系统管理 | System |
| menu.systemManager.systemConfig | 系统配置 | System Config |

**配置分组国际化 key**：

| key | 中文 | 英文 |
|-----|------|------|
| config.group.logging | 日志配置 | Logging |
| config.group.environment | 环境配置 | Environment |
| config.group.database | 数据库配置 | Database |
| config.group.ssl | SSL配置 | SSL |
| config.group.model | 模型配置 | Model |
| config.group.api_key | API密钥配置 | API Keys |
| config.group.skill | 技能配置 | Skills |
| config.group.mail | 邮件配置 | Mail |
| config.group.storage | 存储配置 | Storage |
| config.group.token | Token配置 | Token |
| config.group.other | 其他配置 | Other |

---

# 五、数据库变更设计

## 5.1 config 表结构变更 SQL

**文件位置**：`sql/incremental/config_table_extension.sql`

```sql
-- =============================================
-- 系统配置管理 - config 表扩展字段
-- 版本: v1.0.0
-- 日期: 2026-07-18
-- 说明: 在 config 表基础上新增字段以支持 .env 文件同步
-- =============================================

-- 新增 env_key 字段（对应 .env 文件中的键名）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "env_key" varchar;
COMMENT ON COLUMN "public"."config"."env_key" IS '对应.env文件中的键名，唯一约束';

-- 新增 config_group 字段（配置分组标识）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "config_group" varchar DEFAULT 'other';
COMMENT ON COLUMN "public"."config"."config_group" IS '配置分组标识：logging/environment/database/ssl/model/api_key/skill/mail/storage/token/other';

-- 新增 config_type 字段（配置项类型）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "config_type" varchar DEFAULT 'string';
COMMENT ON COLUMN "public"."config"."config_type" IS '配置项类型：string/int/bool/url/password/path/json';

-- 新增 is_sensitive 字段（是否敏感配置项）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "is_sensitive" bool DEFAULT false;
COMMENT ON COLUMN "public"."config"."is_sensitive" IS '是否为敏感配置项（脱敏显示）';

-- 新增 default_value 字段（默认值）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "default_value" varchar;
COMMENT ON COLUMN "public"."config"."default_value" IS '配置项默认值';

-- 新增 validation_rule 字段（验证规则）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "validation_rule" varchar;
COMMENT ON COLUMN "public"."config"."validation_rule" IS '验证规则描述，如 port:1-65535、url、bool:true|false';

-- 新增 description 字段（描述说明）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "description" varchar;
COMMENT ON COLUMN "public"."config"."description" IS '配置项中文描述说明';

-- 新增 display_order 字段（显示排序）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "display_order" int4 DEFAULT 0;
COMMENT ON COLUMN "public"."config"."display_order" IS '在分组内的显示排序，数值越小越靠前';

-- 新增 editable 字段（是否可编辑）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "editable" bool DEFAULT true;
COMMENT ON COLUMN "public"."config"."editable" IS '是否允许通过界面编辑';

-- 新增 last_synced_at 字段（最后同步时间）
ALTER TABLE "public"."config" ADD COLUMN IF NOT EXISTS "last_synced_at" timestamptz(6);
COMMENT ON COLUMN "public"."config"."last_synced_at" IS 'config表与.env文件最后一致的时间';

-- 为 env_key 创建唯一索引（仅对非 NULL 值）
CREATE UNIQUE INDEX IF NOT EXISTS "idx_config_env_key" ON "public"."config" ("env_key") WHERE "env_key" IS NOT NULL;

-- 为 config_group 创建索引
CREATE INDEX IF NOT EXISTS "idx_config_group" ON "public"."config" ("config_group");
```

## 5.2 permissions 表增量数据 SQL

**文件位置**：`sql/incremental/config_permissions.sql`

```sql
-- =============================================
-- 系统配置管理 - 权限与菜单注册
-- 版本: v1.0.0
-- 日期: 2026-07-18
-- =============================================

-- 1. 系统管理一级菜单（如果不存在则创建）
INSERT INTO "public"."permissions" ("id", "permission_name", "type", "parent_id", "path", "component", "locale", "sort", "status", "created_at", "updated_at")
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  '系统管理', 1, NULL,
  '/system', NULL,
  'menu.systemManager', 8, 1,
  NOW(), NOW()
) ON CONFLICT (id) DO NOTHING;

-- 2. 系统配置二级菜单
INSERT INTO "public"."permissions" ("id", "permission_name", "type", "parent_id", "path", "component", "locale", "sort", "status", "created_at", "updated_at")
VALUES (
  'a0000000-0000-0000-0000-000000000002',
  '系统配置', 1,
  'a0000000-0000-0000-0000-000000000001',
  '/system/config', 'system/config/index',
  'menu.systemManager.systemConfig', 1, 1,
  NOW(), NOW()
) ON CONFLICT (id) DO NOTHING;

-- 3. 配置读取 API 权限（config:read）
INSERT INTO "public"."permissions" ("id", "permission_name", "type", "parent_id", "path", "method", "sort", "status", "created_at", "updated_at")
VALUES (
  'a0000000-0000-0000-0000-000000000010',
  '/api/v1/uctoo/config', 3,
  'a0000000-0000-0000-0000-000000000002',
  '/api/v1/uctoo/config', 'GET',
  1, 1, NOW(), NOW()
) ON CONFLICT (id) DO NOTHING;

-- 4. 配置写入 API 权限（config:write）- 单个
INSERT INTO "public"."permissions" ("id", "permission_name", "type", "parent_id", "path", "method", "sort", "status", "created_at", "updated_at")
VALUES (
  'a0000000-0000-0000-0000-000000000011',
  '/api/v1/uctoo/config/:key', 3,
  'a0000000-0000-0000-0000-000000000002',
  '/api/v1/uctoo/config/:key', 'PUT',
  2, 1, NOW(), NOW()
) ON CONFLICT (id) DO NOTHING;

-- 5. 批量配置写入 API 权限
INSERT INTO "public"."permissions" ("id", "permission_name", "type", "parent_id", "path", "method", "sort", "status", "created_at", "updated_at")
VALUES (
  'a0000000-0000-0000-0000-000000000012',
  '/api/v1/uctoo/config/batch', 3,
  'a0000000-0000-0000-0000-000000000002',
  '/api/v1/uctoo/config/batch', 'PUT',
  3, 1, NOW(), NOW()
) ON CONFLICT (id) DO NOTHING;

-- 6. 配置元数据 API 权限
INSERT INTO "public"."permissions" ("id", "permission_name", "type", "parent_id", "path", "method", "sort", "status", "created_at", "updated_at")
VALUES (
  'a0000000-0000-0000-0000-000000000013',
  '/api/v1/uctoo/config/metadata', 3,
  'a0000000-0000-0000-0000-000000000002',
  '/api/v1/uctoo/config/metadata', 'GET',
  4, 1, NOW(), NOW()
) ON CONFLICT (id) DO NOTHING;

-- 7. 将权限分配给管理员角色（假设管理员角色ID为已知UUID）
-- 需根据实际管理员角色ID调整
INSERT INTO "public"."role_has_permission" ("role_id", "permission_id")
SELECT r.id, p.id
FROM "public"."uctoo_role" r, "public"."permissions" p
WHERE r.name = 'admin'
  AND p.id IN (
    'a0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000010',
    'a0000000-0000-0000-0000-000000000011',
    'a0000000-0000-0000-0000-000000000012',
    'a0000000-0000-0000-0000-000000000013'
  )
ON CONFLICT DO NOTHING;
```

## 5.3 i18n 表增量数据 SQL

**文件位置**：`sql/incremental/config_i18n.sql`

```sql
-- =============================================
-- 系统配置管理 - i18n 国际化注册
-- 版本: v1.0.0
-- 日期: 2026-07-18
-- =============================================

-- 菜单国际化
INSERT INTO "public"."i18" ("id", "key", "lang", "value", "created_at", "updated_at")
VALUES
  (gen_random_uuid(), 'menu.systemManager', 'zh-CN', '系统管理', NOW(), NOW()),
  (gen_random_uuid(), 'menu.systemManager', 'en-US', 'System', NOW(), NOW()),
  (gen_random_uuid(), 'menu.systemManager.systemConfig', 'zh-CN', '系统配置', NOW(), NOW()),
  (gen_random_uuid(), 'menu.systemManager.systemConfig', 'en-US', 'System Config', NOW(), NOW())
ON CONFLICT DO NOTHING;

-- 配置分组国际化
INSERT INTO "public"."i18" ("id", "key", "lang", "value", "created_at", "updated_at")
VALUES
  (gen_random_uuid(), 'config.group.logging', 'zh-CN', '日志配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.logging', 'en-US', 'Logging', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.environment', 'zh-CN', '环境配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.environment', 'en-US', 'Environment', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.database', 'zh-CN', '数据库配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.database', 'en-US', 'Database', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.ssl', 'zh-CN', 'SSL配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.ssl', 'en-US', 'SSL', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.model', 'zh-CN', '模型配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.model', 'en-US', 'Model', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.api_key', 'zh-CN', 'API密钥配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.api_key', 'en-US', 'API Keys', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.skill', 'zh-CN', '技能配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.skill', 'en-US', 'Skills', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.mail', 'zh-CN', '邮件配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.mail', 'en-US', 'Mail', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.storage', 'zh-CN', '存储配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.storage', 'en-US', 'Storage', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.token', 'zh-CN', 'Token配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.token', 'en-US', 'Token', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.other', 'zh-CN', '其他配置', NOW(), NOW()),
  (gen_random_uuid(), 'config.group.other', 'en-US', 'Other', NOW(), NOW())
ON CONFLICT DO NOTHING;
```

---

# 六、接口设计

## 6.1 标准 CRUD API 列表

| HTTP 方法 | 路径 | 权限 | 说明 |
|----------|------|------|------|
| POST | /api/v1/uctoo/config/add | config:write | 新增配置项 |
| POST | /api/v1/uctoo/config/edit | config:write | 编辑配置项 |
| POST | /api/v1/uctoo/config/del | config:write | 删除配置项（软删除） |
| GET | /api/v1/uctoo/config/:id | config:read | 按 ID 获取单个配置项 |
| GET | /api/v1/uctoo/config/:limit/:page | config:read | 分页获取配置项列表 |

## 6.2 RESTful 扩展 API 列表

### 6.2.1 读取全部/分组配置

- **路径**：`GET /api/v1/uctoo/config`
- **权限**：config:read
- **Query 参数**：
  - `group`（可选）：配置分组标识，如 logging/database/api_key 等
- **响应示例**：

```json
{
  "configs": [
    {
      "id": "uuid",
      "env_key": "LOG_LEVEL",
      "name": "日志级别",
      "value": "debug",
      "config_group": "logging",
      "config_type": "string",
      "is_sensitive": false,
      "default_value": "error",
      "validation_rule": null,
      "description": "日志级别：error/warn/info/debug/trace",
      "display_order": 1,
      "editable": true,
      "last_synced_at": "2026-07-18T10:00:00Z"
    }
  ]
}
```

### 6.2.2 按 .env 键名读取单个配置项

- **路径**：`GET /api/v1/uctoo/config/:key`
- **权限**：config:read
- **路径参数**：`key` — .env 文件中的键名（如 LOG_LEVEL）
- **响应**：单个 ConfigPO 的 JSON（敏感项脱敏）
- **异常**：404 — 配置项不存在

### 6.2.3 按 .env 键名写入单个配置项

- **路径**：`PUT /api/v1/uctoo/config/:key`
- **权限**：config:write
- **路径参数**：`key` — .env 文件中的键名
- **请求体**：

```json
{
  "value": "info"
}
```

- **响应**：更新后的 ConfigPO JSON（敏感项脱敏）
- **异常**：
  - 400 — 验证失败（CONFIG_VALIDATION_FAILED）
  - 404 — 配置项不存在
  - 500 — 写入失败（CONFIG_WRITE_FAILED）

### 6.2.4 批量写入配置

- **路径**：`PUT /api/v1/uctoo/config/batch`
- **权限**：config:write
- **请求体**：

```json
{
  "items": [
    { "env_key": "LOG_LEVEL", "value": "info" },
    { "env_key": "LOG_FILE", "value": "./logs/runtime.log" }
  ]
}
```

- **响应**：批量更新结果列表
- **约束**：单次批量不超过 50 项

### 6.2.5 获取配置元数据

- **路径**：`GET /api/v1/uctoo/config/metadata`
- **权限**：config:read
- **响应**：所有配置项的元数据列表（不含 value，用于前端表单渲染）

```json
{
  "metadata": [
    {
      "env_key": "LOG_LEVEL",
      "name": "日志级别",
      "config_group": "logging",
      "config_type": "string",
      "is_sensitive": false,
      "default_value": "error",
      "validation_rule": null,
      "description": "日志级别：error/warn/info/debug/trace",
      "display_order": 1,
      "editable": true
    }
  ]
}
```

### 6.2.6 导出配置

- **路径**：`GET /api/v1/uctoo/config/export`
- **权限**：config:read
- **Query 参数**：`format` — json 或 env（默认 env）
- **响应**：配置文件内容（JSON 或 .env 格式）

### 6.2.7 导入配置

- **路径**：`POST /api/v1/uctoo/config/import`
- **权限**：config:write
- **请求体**：

```json
{
  "data": "LOG_LEVEL=info\nDATABASE_URL=postgresql://...",
  "format": "env"
}
```

- **响应**：导入结果（成功数/失败数）

## 6.3 命令行 CLI 接口列表

| 命令 | 参数 | 说明 | 对应 API |
|------|------|------|---------|
| `config get <key>` | key: .env 键名 | 读取单个配置项 | GET /api/v1/uctoo/config/:key |
| `config list` | --group, --json | 列出配置项 | GET /api/v1/uctoo/config |
| `config set <key> <value>` | key, value | 写入配置项 | PUT /api/v1/uctoo/config/:key |
| `config unset <key>` | key | 标记禁用 | PUT /api/v1/uctoo/config/:key (value=) |
| `config export` | --format | 导出配置 | GET /api/v1/uctoo/config/export |
| `config import --file <path>` | --format, --file | 导入配置 | POST /api/v1/uctoo/config/import |

---

# 七、配置同步策略设计

## 7.1 同步策略总体原则

**核心原则**：.env 文件是配置的真实来源（source of truth），config 表是配置的结构化镜像。

**同步方向**：
- **主同步方向**：.env → config 表（单向，.env 变更自动同步到 config 表）
- **反向同步方向**：config 表 → .env（仅通过 API 写入时触发，不自动反向同步）

**设计理由**：
1. .env 文件是 agentskills-runtime 启动时实际读取的配置源
2. config 表提供结构化查询、分组管理、元数据驱动等能力
3. 防止数据库直接修改意外覆盖 .env 文件中的有效配置

## 7.2 启动同步机制

**触发时机**：Application.init() 中，ORM 初始化完成后，与 SyncManager.initialize() 并行执行

**同步流程**：

```
Application.init()
    │
    ├── ORM.initialize()                    (现有)
    ├── SyncManager.initialize()            (现有)
    │
    └── [新增] ConfigSyncHandler.startupSync()
            │
            ├── EnvFileService.getEnvFilePath()  // 解析 .env 文件路径
            ├── EnvFileService.readAllEnvValues() // 读取全部键值对
            │
            └── 遍历每个键值对：
                    ├── ConfigDAO.findConfigByEnvKey(key)
                    ├── [存在] 比较值 → 不一致则更新（以 .env 为准）
                    ├── [不存在] upsert 新记录到 config 表
                    └── 更新 last_synced_at = NOW()
```

**异常处理**：
- .env 文件不存在 → 记录警告日志，跳过启动同步
- config 表写入失败 → 记录错误日志，继续处理下一个配置项
- 启动同步不阻塞主线程，使用 spawn 异步执行

## 7.3 双写同步机制

**触发时机**：通过 API 写入配置项时（ConfigService.updateConfigByKey / batchUpdateConfigs）

**同步流程**：

```
ConfigService.updateConfigByKey(envKey, value)
    │
    ├── 1. ConfigValidator.validate()         // 验证输入值
    ├── 2. EnvFileService.backupEnvFile()      // 备份 .env 文件
    ├── 3. EnvFileService.writeEnvKeyValue()   // 写入 .env 文件
    │       ├── [成功] 继续
    │       └── [失败] EnvFileService.restoreBackup() → 返回错误
    ├── 4. ConfigDAO.upsertByEnvKey()          // 同步写入 config 表
    │       ├── [成功] 继续
    │       └── [失败] 记录同步失败日志，标记 last_synced_at = NULL
    ├── 5. OperateLogService.recordConfigAudit()  // 记录审计日志
    └── 6. 返回更新后的 ConfigPO
```

**原子性保证**：
- .env 文件写入使用"先写临时文件再 rename"的原子写入策略
- .env 写入失败时自动恢复备份
- config 表写入失败时，.env 文件中的值已更新，通过定时同步机制最终一致

## 7.4 定时同步机制

**触发时机**：通过 CrontabScheduler 注册定时任务，默认每 5 分钟执行一次

**同步流程**：

```
ConfigSyncHandler.scheduledSync()  (每5分钟)
    │
    ├── 1. 获取 .env 文件最后修改时间
    ├── 2. 与上次同步时间比较
    │       ├── [未变更] → 跳过
    │       └── [已变更] → 继续
    ├── 3. EnvFileService.readAllEnvValues()   // 读取 .env 全部键值对
    ├── 4. ConfigDAO.findAllEnvConfigs()        // 读取 config 表所有有 env_key 的记录
    ├── 5. 比较两侧数据，找出差异项
    │       ├── .env 有但 config 表无 → upsert 到 config 表
    │       ├── .env 和 config 表都有但值不同 → 以 .env 为准更新 config 表
    │       └── config 表有但 .env 无 → 不删除 config 表记录（仅记录警告）
    ├── 6. 更新 last_synced_at
    └── 7. 记录同步日志到 sync_log 表
```

**定时任务注册**：
- 在 Application.init() 中注册 CrontabScheduler 定时任务
- 任务名称：`config-env-sync`
- Cron 表达式：`0 */5 * * * *`（每5分钟）
- 复用现有 CrontabScheduler 基础设施

## 7.5 冲突解决策略

**冲突定义**：.env 文件中某个键的值与 config 表中对应记录的 value 不一致

**解决规则**：

| 场景 | 解决策略 | 理由 |
|------|---------|------|
| .env 较新（文件修改时间 > last_synced_at） | 以 .env 值覆盖 config 表 | .env 是 source of truth |
| config 表较新（updated_at > .env 修改时间） | 以 .env 值覆盖 config 表 | .env 始终是最终来源，config 表通过 API 修改时已双写到 .env |
| 时间不可比 | 以 .env 值为准 | 安全优先，.env 是运行时实际使用的值 |

**冲突检测**：
- 定时同步时，比较 .env 文件修改时间与 config 表 last_synced_at
- API 读取时，如果 last_synced_at 为 NULL，标记该配置项同步状态为"异常"

**同步日志记录**：
- 每次同步操作记录到 sync_log 表
- 日志内容包含：同步方向、变更项数量、成功/失败数、详细变更列表
- 复用现有 SyncLogService 的日志记录能力