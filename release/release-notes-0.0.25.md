# AgentSkills Runtime v0.0.25 发布说明

**发布日期**: 2026-07-23  
**版本**: 0.0.25  
**代号**: System-Config  
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 1. 可视化系统配置管理

本版本实现了对 agentskills-runtime `.env` 配置文件的全生命周期管理，提供命令行（CLI）、API、可视化界面三种配置通道，实现配置的读取、修改、验证和持久化。采用规范驱动开发模式，完整需求规格和设计文档位于 `.codeartsdoer/specs/system-config/`。

#### 技术架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                       系统配置管理 整体架构                               │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────┐   │
│  │  命令行通道   │  │  API 通道     │  │    界面通道 (web-admin)       │   │
│  │  config_cli  │  │  RESTful API │  │  system/config/index.vue     │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┬───────────────┘   │
│         └────────┬────────┘                           │                   │
│                  ▼                                     ▼                   │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                      接入层 (Entry Layer)                         │    │
│  │  ConfigRoute (标准CRUD路由 + RESTful扩展路由)                     │    │
│  │  ConfigController (标准CRUD方法 + RESTful扩展方法)                │    │
│  └──────────────────────────┬───────────────────────────────────────┘    │
│                             │                                            │
│  ┌──────────────────────────▼───────────────────────────────────────┐    │
│  │                      服务层 (Service Layer)                       │    │
│  │  ConfigService (脱敏处理/审计日志/配置同步协调)                    │    │
│  │  EnvFileService (.env文件读写/备份/回滚)                          │    │
│  │  ConfigValidator (配置项验证引擎)                                  │    │
│  └──────────────────────────┬───────────────────────────────────────┘    │
│                             │                                            │
│  ┌──────────────────────────▼───────────────────────────────────────┐    │
│  │                      同步层 (Sync Layer)                          │    │
│  │  ConfigSyncHandler (启动同步/双写同步/定时同步)                    │    │
│  └──────────────────────────┬───────────────────────────────────────┘    │
│                             │                                            │
│  ┌──────────────────────────▼───────────────────────────────────────┐    │
│  │                      数据层 (Data Layer)                          │    │
│  │  ConfigDAO (f_orm CRUD)    .env 文件 (source of truth)            │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

#### 核心能力

| 能力 | 说明 |
|------|------|
| .env 文件读写 | 读取、写入、备份、回滚，保持注释和格式不变 |
| 配置项验证 | 基于 config_type（string/int/bool/url/password/path/json）和 validation_rule 的输入验证 |
| 敏感配置脱敏 | API Key、密码等敏感项读取时脱敏显示（前4后4，中间 * 替代） |
| 配置同步 | .env 文件与 config 表的双向一致性同步（启动同步/双写同步/定时同步） |
| 配置审计 | 记录配置变更的操作者、时间、变更前后值、操作通道 |
| 配置导入导出 | 支持 JSON 和 .env 格式的配置导入导出 |
| 元数据驱动 | 配置项元数据（分组、类型、验证规则）驱动前端表单渲染 |
| RBAC 权限 | 所有配置读写操作经过 RBAC 权限校验（config:read / config:write） |

#### 三种配置通道

**1. 命令行通道（CLI）**

```bash
# 读取配置
config get LOG_LEVEL

# 列出配置
config list --group logging
config list --json

# 写入配置
config set LOG_LEVEL debug

# 导出配置
config export --format json

# 导入配置
config import --file ./config-backup.env
```

**2. API 通道（RESTful）**

| HTTP 方法 | 路径 | 说明 |
|----------|------|------|
| GET | /api/v1/uctoo/config | 读取全部/分组配置项 |
| GET | /api/v1/uctoo/config/:key | 按 .env 键名读取单个配置项 |
| PUT | /api/v1/uctoo/config/:key | 按 .env 键名写入单个配置项 |
| PUT | /api/v1/uctoo/config/batch | 批量写入配置项（≤50项） |
| GET | /api/v1/uctoo/config/metadata | 获取配置元数据 |
| GET | /api/v1/uctoo/config/export | 导出配置 |
| POST | /api/v1/uctoo/config/import | 导入配置 |

**3. 可视化界面通道（Web）**

- 分组 Tab 布局：日志配置、环境配置、数据库配置、SSL配置、模型配置、API密钥配置、技能配置、邮件配置、存储配置、Token配置
- 元数据驱动的表单渲染：根据 configType 自动渲染对应的表单控件（文本框、密码框、开关、数字输入等）
- 敏感配置项密码框显示，只读配置项禁用编辑
- 配置项描述说明展示
- 恢复默认值功能

### 2. config 表扩展

在 config 表基础上新增 10 个字段，支持与 .env 文件的同步映射：

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

### 3. 配置同步机制

采用".env 文件为真实来源（source of truth），config 表为结构化镜像"的同步策略：

- **启动同步**：runtime 启动时从 .env 文件全量加载配置并同步到 config 表
- **双写同步**：通过 API 写入配置时，同时更新 .env 文件和 config 表
- **定时同步**：每 5 分钟检测 .env 文件变更，增量同步差异到 config 表
- **冲突解决**：.env 文件与 config 表值不一致时，始终以 .env 值为准

### 4. .env 文件原子写入

- 写入前自动创建 .env 文件备份（`.env.backup-{timestamp}`）
- 采用"先写临时文件再 rename"的原子写入策略
- 写入失败时自动恢复备份
- 保持 .env 文件的注释和格式不变

## 新增功能

### 后端模块（仓颉）

| 模块 | 文件 | 说明 |
|------|------|------|
| ConfigPO | src/app/models/uctoo/ConfigPO.cj | config 表 ORM 模型（含扩展字段） |
| ConfigDAO | src/app/dao/uctoo/ConfigDAO.cj | 数据访问层（含 findConfigByEnvKey 等扩展方法） |
| ConfigService | src/app/services/uctoo/ConfigService.cj | 配置服务（脱敏、审计、同步协调） |
| EnvFileService | src/app/services/uctoo/EnvFileService.cj | .env 文件读写服务（备份/原子写入/回滚） |
| ConfigValidator | src/app/services/uctoo/ConfigValidator.cj | 配置项验证引擎 |
| ConfigSyncHandler | src/app/services/uctoo/ConfigSyncHandler.cj | 配置同步处理器 |
| ConfigController | src/app/controllers/uctoo/config/ConfigController.cj | 控制器（标准CRUD + RESTful扩展） |
| ConfigRoute | src/app/routes/uctoo/config/ConfigRoute.cj | 路由注册（含 RESTful 扩展路由） |
| config_cli | src/cli/config_cli.cj | 命令行配置通道 |

### 前端模块（Vue 3）

| 模块 | 文件 | 说明 |
|------|------|------|
| config Model | store/models/uctoo/config.ts | Pinia-ORM 数据模型 |
| 系统配置页面 | views/system/config/index.vue | 分组 Tab 布局主页面 |
| ConfigFormItem | views/system/config/components/ConfigFormItem.vue | 元数据驱动的表单控件 |
| 路由注册 | router/routes/modules/system.ts | 系统管理路由模块 |

### 数据库变更

| 文件 | 说明 |
|------|------|
| sql/incremental/config_table_extension.sql | config 表扩展 10 个字段 |
| sql/incremental/config_permissions.sql | 权限菜单注册（系统配置菜单 + API 路由权限） |
| sql/incremental/config_i18n.sql | i18n 国际化注册（菜单 + 配置分组） |

### 权限注册

| 权限 | 类型 | 说明 |
|------|------|------|
| 系统管理 | 菜单 | 一级菜单 |
| 系统配置 | 菜单 | 二级菜单，parent_id 指向系统管理 |
| config:read | API 路由 | GET /api/v1/uctoo/config 等读取操作 |
| config:write | API 路由 | PUT /api/v1/uctoo/config/:key 等写入操作 |

## 改进

### 1. 配置管理体验

- 从手动编辑 .env 文件升级为可视化界面管理
- 支持配置项分组分类管理，界面布局清晰
- 敏感配置项自动脱敏，提升安全性
- 配置变更审计日志，支持变更追溯

### 2. 配置一致性保障

- .env 文件与 config 表自动同步，避免数据不一致
- 启动时全量同步确保配置初始一致
- 定时同步检测外部修改，自动同步到数据库

### 3. 配置验证体系

- 基于 config_type 的类型验证（string/int/bool/url/password/path/json）
- 基于 validation_rule 的自定义规则验证（如 port:1-65535、url、not_empty）
- 前端表单验证 + 后端 API 验证双重保障

## 数据库变更

### config 表扩展

```sql
-- 运行 config 表扩展迁移
psql -d uctoo -f sql/incremental/config_table_extension.sql

-- 运行权限菜单注册
psql -d uctoo -f sql/incremental/config_permissions.sql

-- 运行 i18n 国际化注册
psql -d uctoo -f sql/incremental/config_i18n.sql
```

## 迁移指南

### 从 v0.0.24 升级

1. **执行数据库迁移**
   ```bash
   # 执行 config 表扩展
   psql -d uctoo -f sql/incremental/config_table_extension.sql
   psql -d uctoo -f sql/incremental/config_permissions.sql
   psql -d uctoo -f sql/incremental/config_i18n.sql
   ```

2. **刷新数据库信息**
   ```bash
   # 使用 loaddbinfo CLI 工具刷新 db_info 表
   cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args="--db uctoo"
   ```

3. **重新生成 ConfigPO 模块**（可选，如需基于扩展后的 config 表重新生成）
   ```bash
   # 使用 crudgen 重新生成 config 表的 CRUD 模块
   cjpm run --skip-build --name magic.app.tools.crudgen --run-args="--db uctoo --table config"
   ```

4. **重启 Runtime 服务**
   ```bash
   # 使用 SDK 重新安装
   npm install @opencangjie/skills@latest
   npx skills install-runtime --runtime-version 0.0.25
   npx skills restart
   ```

5. **验证系统配置功能**
   ```bash
   # 登录 web-admin 管理后台
   # 访问"系统管理 > 系统配置"页面
   # 验证配置项加载和保存功能
   ```

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~170MB
- 包含: 所有依赖 DLL

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~160MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

## 安装使用

### 使用 JavaScript SDK

```bash
# 安装 SDK
npm install @opencangjie/skills@latest

# 安装 runtime
npx skills install-runtime --runtime-version 0.0.25

# 启动 runtime
npx skills start
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.25/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑 .env 文件配置数据库连接、AI 模型 API Key 等

# 4. 运行
./bin/agentskills-runtime.exe 443
```

### 构建说明

```bash
# 构建项目（自动打包）
cjpm build

# 手动打包（可选）
cjpm run --skip-build --name magic.scripts.package_release
```

## 相关文档

| 文档 | 说明 |
|------|------|
| [系统配置需求规格](./.codeartsdoer/specs/system-config/spec.md) | 完整需求规格说明 |
| [系统配置设计文档](./.codeartsdoer/specs/system-config/design.md) | 实现方案设计文档 |
| [系统配置任务清单](./.codeartsdoer/specs/system-config/tasks.md) | 编码任务清单 |
| [模块开发规范](./docs/uctoo-v4/uctoo-v4-module-development.md) | UCToo V4 通用模块开发流程 |
| [API 设计规范](./docs/uctoo-v4/uctoo-v4-api-specification.md) | UCToo V4 API 设计规范 |

## 已知问题

- .env 文件路径在生产环境需根据安装方式手动配置 ENV_FILE_PATH 环境变量
- 定时同步检测 .env 文件变更依赖文件修改时间戳，秒级内连续修改可能无法立即检测
- 前端配置页面首次加载需获取全部元数据和配置值，配置项较多时可能需要优化分页

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区
- OpenTiny 开源社区

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

## 下一版本计划

v0.0.26 计划功能：
- DAG 调度引擎
- 技能组合 DSL
- 跨会话记忆自动加载
- 技能市场 Web UI
- 性能监控面板
- 集群部署支持
- 更多数据库支持

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
