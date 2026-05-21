# AgentSkills Runtime v0.0.21 发布说明

**发布日期**: 2026-05-21  
**版本**: 0.0.21  
**平台**: Windows x64, Linux x64, macOS x64/ARM64

## 重大变更

### 1. 行级数据权限特性

本版本实现了完整的行级数据权限控制机制，支持细粒度的数据访问控制。

#### 核心特性

- **行级权限配置**: 通过`data_access_authorization`表配置各表的行级权限策略
- **权限节点验证**: 在Service层自动进行权限检查
- **动态SQL过滤**: 根据用户权限动态生成WHERE条件
- **权限继承**: 支持角色级和用户级权限配置

#### 权限配置结构

```sql
-- data_access_authorization 表结构
CREATE TABLE data_access_authorization (
    id uuid PRIMARY KEY,
    entity_type varchar NOT NULL,       -- 实体类型/表名
    entity_id uuid NOT NULL,           -- 实体ID
    user_id uuid NOT NULL,              -- 用户ID
    permission_level int NOT NULL,      -- 权限级别(1:READ, 2:WRITE, 3:AUTHORIZE)
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP
);
```

#### 权限级别定义

| 级别 | 名称 | 说明 |
|------|------|------|
| 1 | READ | 可读 |
| 2 | WRITE | 可写 |
| 3 | AUTHORIZE | 可授权 |

#### 使用示例

```cangjie
// Service层权限检查
public func getByIdWithPermission(id: String, userId: String): APIResult<CrontabPO> {
    // 自动检查用户是否有权限访问该行数据
    let (hasPermission, errMsg) = PermissionUtils.checkReadPermission(userId, id, "crontab")
    if (!hasPermission) {
        return APIResult(false, errMsg)
    }
    // 执行查询
    let result = getExecutor().findCrontabById(id)
    // ...
}
```

#### 授权管理API路由

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/v1/uctoo/data_access_authorization/authorize` | POST | 授权用户访问实体 |
| `/api/v1/uctoo/data_access_authorization/revoke` | POST | 撤销用户授权 |
| `/api/v1/uctoo/data_access_authorization/{entityType}/{entityId}/authorizations` | GET | 查询实体的所有授权 |

### 2. CRUD生成器行级权限支持

完善了crudgen工具，支持生成带有行级数据权限的标准模块。

#### 新增功能

- **权限感知代码生成**: 自动生成权限检查逻辑
- **DAO层优化**: 支持动态权限过滤查询
- **Service层增强**: 集成权限验证方法
- **Controller层适配**: 传递用户ID进行权限检查

#### 生成代码结构

```
module/
├── xxxPO.cj           # 持久化对象
├── xxxDAO.cj          # 数据访问对象（含权限过滤）
├── xxxService.cj      # 业务服务层（含权限验证）
├── xxxController.cj   # 控制器层
└── xxxRoute.cj        # 路由配置
```

#### 使用命令

```bash
# 生成CRUD模块（权限自动集成）
crudgen --db uctoo --table <table_name>

# 全量刷新所有标准模块（保留自定义代码）
crudgen --db uctoo --all
```

#### 命令行参数说明

| 参数 | 说明 |
|------|------|
| `--db` | 指定数据库名称（必填） |
| `--table` | 指定表名（与--all二选一） |
| `--all` | 全量刷新所有模块 |
| `--output` | 指定输出目录 |
| `--help` | 显示帮助信息 |

### 3. 标准模块统一刷新

完成了所有标准CRUD模块的统一刷新，确保代码一致性和权限支持。

#### 刷新内容

| 模块 | 状态 | 说明 |
|------|------|------|
| entity | ✅ | 实体管理模块 |
| crontab | ✅ | 计划任务模块 |
| crontab_log | ✅ | 任务日志模块 |
| crontab_task_registry | ✅ | 任务执行器注册模块 |
| db_info | ✅ | 数据库信息模块 |
| permissions | ✅ | 权限配置模块 |
| uctoo_user | ✅ | 用户管理模块 |
| i18 | ✅ | 国际化模块 |

#### 刷新特性

- **增量更新**: 保留`//#region Human-Code Preservation`区域的自定义代码
- **权限集成**: 所有模块自动集成行级权限检查
- **代码格式化**: 统一代码风格和格式
- **类型安全**: 完整的类型检查

### 4. 计划任务模块

实现了完整的计划任务（Crontab）模块，支持定时任务调度和执行。

#### 核心功能

- **任务调度引擎**: 基于Cron表达式的任务调度
- **多种执行器**: 支持HTTP、Script、Builtin三种执行器类型
- **任务管理**: 创建、编辑、删除、暂停、恢复任务
- **执行日志**: 完整的任务执行记录和统计
- **系统任务保护**: 标记为系统任务的计划任务不可删除或暂停
- **错过执行策略**: MisfireManager + MisfirePolicy 处理任务错过执行的情况
- **失败重试策略**: RetryManager + RetryStrategy 实现智能重试机制

#### 数据库结构

```sql
CREATE TABLE crontab (
    id uuid PRIMARY KEY,
    name varchar NOT NULL,          -- 任务名称
    "group" varchar DEFAULT '1',    -- 分组(1:默认, 2:系统)
    task varchar NOT NULL,          -- 任务地址
    cron varchar NOT NULL,          -- Cron表达式
    tactics varchar NOT NULL,       -- 策略(IGNORE/RUN_NOW)
    status int DEFAULT 1,           -- 状态(0:禁用, 1:启用)
    timeout int DEFAULT 30,         -- 超时时间(秒)
    max_retries int DEFAULT 3,      -- 最大重试次数
    concurrentable bool DEFAULT false,  -- 是否允许并发
    once bool DEFAULT false,        -- 是否单次执行
    priority int DEFAULT 5,         -- 优先级
    parameters text DEFAULT '{}',   -- 参数(JSON)
    misfire_threshold int DEFAULT 300,  -- 错过执行阈值(秒)
    -- ...
);
```

#### API接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/v1/uctoo/crontab/{pageSize}/{page}` | GET | 分页查询任务列表 |
| `/api/v1/uctoo/crontab/{id}` | GET | 查询单个任务 |
| `/api/v1/uctoo/crontab/add` | POST | 创建任务 |
| `/api/v1/uctoo/crontab/edit` | POST | 更新任务 |
| `/api/v1/uctoo/crontab/del` | POST | 删除任务 |
| `/api/v1/uctoo/crontab/trigger/{id}` | POST | 手动触发任务 |
| `/api/v1/uctoo/crontab/pause/{id}` | POST | 暂停任务 |
| `/api/v1/uctoo/crontab/resume/{id}` | POST | 恢复任务 |
| `/api/v1/uctoo/crontab/reload` | POST | 重载调度器 |

#### 使用示例

```bash
# 创建HTTP执行器任务
curl -X POST http://localhost:8080/api/v1/uctoo/crontab/add \
  -H "Content-Type: application/json" \
  -d '{
    "name": "health_check",
    "task": "http://localhost:8080/api/v1/health",
    "cron": "0 */5 * * * *",
    "tactics": "IGNORE",
    "timeout": 30
  }'

# 手动触发任务
curl -X POST http://localhost:8080/api/v1/uctoo/crontab/trigger/<task_id>
```

### 5. 数据库管理模块完善

完善了数据库管理模块，提供数据库表结构管理和CRUD模块生成能力。

#### 新增功能

- **表结构查询**: 查询所有表和字段信息
- **CRUD模块生成**: 一键生成标准CRUD代码
- **权限节点管理**: 管理各模块的权限配置
- **数据库连接测试**: 测试数据库连接状态

#### db_info表结构

```sql
CREATE TABLE db_info (
    id uuid PRIMARY KEY,
    table_name varchar NOT NULL,     -- 表名
    field_name varchar NOT NULL,     -- 字段名
    field_type varchar NOT NULL,     -- 字段类型
    is_nullable bool DEFAULT true,   -- 是否可空
    is_primary bool DEFAULT false,   -- 是否主键
    default_value text,              -- 默认值
    comment text,                    -- 注释
    creator uuid,                    -- 创建人
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamptz
);
```

### 6. Web端管理界面适配

完成了Web-Admin管理端与新功能的适配。

#### 新增页面

- **计划任务管理**: 任务列表、创建、编辑、触发、暂停、恢复
- **数据库管理**: 表结构查看、CRUD模块生成
- **权限配置**: 行级权限配置管理

#### 页面结构

```
web-admin/web/src/views/
├── crontab/           # 计划任务管理
│   ├── index.vue      # 任务列表
│   ├── add.vue        # 创建任务
│   └── edit.vue       # 编辑任务
├── db/                # 数据库管理
│   ├── index.vue      # 表列表
│   └── detail.vue     # 表详情
└── permission/        # 权限配置
    └── index.vue      # 权限列表
```

## 新增功能

### 1. 任务执行器扩展

新增多种任务执行器类型：

| 类型 | 前缀 | 说明 |
|------|------|------|
| HTTP | `http://` / `https://` | HTTP回调执行器 |
| Script | `script://` | 脚本执行器 |
| Builtin | `builtin://` | 内置任务执行器 |

#### 执行器安全防护

- **SSRF防护**: HttpExecutor 实现了严格的URL白名单和DNS解析验证
- **路径穿越防护**: ScriptExecutor 限制脚本执行路径，防止目录遍历攻击

#### 内置任务列表

| 执行器 | 说明 |
|--------|------|
| `DatabaseCleanupHandler` | 数据库清理 |
| `CacheRefreshHandler` | 缓存刷新 |
| `LogRotationHandler` | 日志轮转 |
| `HealthCheckHandler` | 健康检查 |
| `MetricsReportHandler` | 指标上报 |

### 2. 调度器状态监控

新增调度器状态监控接口：

#### 综合健康检查接口

```bash
# 获取健康状态（综合）
curl http://localhost:8080/api/v1/health

# 返回示例
{
  "status": "ok",
  "version": "0.0.21",
  "scheduler": {
    "running": true,
    "totalTasks": 10,
    "activeTasks": 8,
    "runningTasks": 2
  }
}
```

#### 调度器状态详情接口

```bash
# 获取调度器详细状态
curl http://localhost:8080/api/v1/uctoo/crontab/scheduler/status

# 返回示例
{
  "errno": "0",
  "errmsg": "success",
  "data": {
    "status": "running",
    "totalTasks": 10,
    "activeTasks": 8,
    "runningTasks": 2,
    "pausedTasks": 2
  }
}
```

### 3. 任务执行日志查询

完善任务执行日志功能：

```bash
# 查询执行日志
curl http://localhost:8080/api/v1/uctoo/crontab_log/10/1

# 查询执行统计
curl http://localhost:8080/api/v1/uctoo/crontab_log/statistics
```

## 改进

### 1. 打包流程优化

- **自动化打包**: `cjpm build` 完成后自动执行打包脚本
- **简化部署**: 一键构建即可获得完整发布包
- **手动打包可选**: 保留手动打包命令作为可选操作

### 2. 性能优化

- **SQL查询优化**: 使用显式列名代替`SELECT *`
- **关键字转义**: 自动处理PostgreSQL关键字字段
- **NULL值处理**: 使用COALESCE函数处理NULL值

### 3. 代码质量

- **CRUD生成器模板改进**: 添加关键字转义和NULL值处理
- **统一代码风格**: 所有生成代码格式一致
- **完整的错误处理**: 完善异常捕获和日志记录

## 依赖更新

### 仓颉运行时

| 依赖 | 版本 | 说明 |
|------|------|------|
| cangjie | 1.0.4 | 仓颉编程语言运行时 |
| fountain | latest | Web框架 |
| f_orm | latest | ORM框架 |

### 前端依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| Vue | 3.5+ | 前端框架 |
| Pinia ORM | 1.10.2 | 状态管理 |
| OpenTiny Vue | 3.28+ | UI组件库 |

## 迁移指南

### 从v0.0.20升级

1. **更新数据库表结构**
   ```sql
   -- 运行SQL脚本
   psql -d uctoo -f sql/public20260518.sql
   ```

2. **刷新CRUD模块**
   ```bash
   # 刷新所有标准模块
   crudgen --db uctoo --all
   ```

3. **配置行级权限**
   - 复制 `.env.example` 到 `.env`
   - 配置 `RLP_*` 行级权限开关（共20个表）

4. **部署Web-Admin更新**
   ```bash
   cd apps/web-admin
   git pull
   npm install
   npm run build
   ```

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~165MB
- 包含: 所有依赖DLL

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`
- 大小: ~155MB

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

### Web-Admin
- 文件: `web-admin-4.1.0.tar.gz`
- 包含: 完整的前后端项目

## 安装使用

### 使用JavaScript SDK

```bash
# 安装SDK
npm install @opencangjie/skills

# 安装runtime
npx skills install-runtime --runtime-version 0.0.21

# 启动runtime
npx skills start

# 生成CRUD模块
npx skills run crud-generator
```

### 手动安装

```bash
# 1. 下载发布包
wget https://atomgit.com/uctoo/agentskills-runtime/releases/download/v0.0.21/agentskills-runtime-win-x64.tar.gz

# 2. 解压
tar -xzf agentskills-runtime-win-x64.tar.gz

# 3. 配置
cd release
cp .env.example bin/.env
# 编辑.env文件配置API密钥

# 4. 运行
./bin/agentskills-runtime.exe 8080
```

### 构建说明

```bash
# 构建项目（自动打包）
cjpm build

# 手动打包（可选）
cjpm run --name magic.scripts.package_release
```

## 已知问题

- 无

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie开源社区

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/UCToo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/UCToo/agentskills-runtime/tree/main/docs

## 下一版本计划

v0.0.22计划功能：
- 技能市场Web UI
- 性能监控面板
- 集群部署支持
- 更多数据库支持

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
