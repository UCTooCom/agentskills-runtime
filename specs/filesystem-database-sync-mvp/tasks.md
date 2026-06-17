# 文件系统与数据库双向同步 MVP - 编码任务规划

**版本**: v1.0.0-mvp  
**创建日期**: 2026-06-03  
**关联需求**: spec.md v1.0.0-mvp  
**关联设计**: design.md v1.0.0-mvp  
**技术栈**: 仓颉语言 v1.0.4 / cjpm / PostgreSQL / f_aspect / crontab / f_orm / crudgen  
**项目根目录**: `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime`

---

## 任务依赖关系图

```
Phase 1: 数据模型与基础设施
  1.1 DB迁移 ──┐
  1.2 SyncLogPO+DAO ──┤
  1.3 枚举与数据类型 ──┼──> Phase 2: 核心同步引擎
  1.4 SyncContext ─────┘      │
                               ├── 2.1 TopologySorter
                               ├── 2.2 RetryManager
                               ├── 2.3 DataMapper
                               ├── 2.4 ConflictResolver
                               ├── 2.5 SyncStatusManager
                               └── 2.6 SyncHandler接口
                                      │
                               Phase 3: 实体同步处理器
                               ├── 3.1 AgentSyncHandler
                               ├── 3.2 AgentSkillSyncHandler
                               └── 3.3 ChangeDetector
                                      │
                               Phase 4: 同步管理器与拦截器
                               ├── 4.1 SyncManager
                               ├── 4.2 SyncInterceptor
                               └── 4.3 SyncScanJob
                                      │
                               Phase 5: 服务层与接入层
                               ├── 5.1 SyncService
                               ├── 5.2 SyncLogService
                               ├── 5.3 SyncController
                               └── 5.4 SyncRoute
                                      │
                               Phase 6: 集成与配置
                               ├── 6.1 AgentLoadManager集成
                               ├── 6.2 配置项定义
                               └── 6.3 应用启动流程集成
                                      │
                               Phase 7: 测试
                               ├── 7.1 单元测试
                               └── 7.2 集成测试
```

---

## 1. 数据模型与基础设施 [Phase 1]

### 1.1 数据库迁移脚本 [P0 | 1h]
- [ ] 创建迁移脚本文件 `scripts/migration/sync_system_mvp_v1.sql`
  - 编写 agents 表新增字段 DDL：`source_path VARCHAR(512)`、`sync_status VARCHAR(32) DEFAULT 'pending'`、`last_sync_at TIMESTAMPTZ`
  - 编写 agents 表唯一索引 `uk_agents_source_path`（仅非空值唯一）和普通索引 `idx_agents_sync_status`
  - 编写 agents 表字段 COMMENT
  - 编写 agent_skills 表新增字段 DDL：同上三个字段
  - 编写 agent_skills 表唯一索引 `uk_agent_skills_source_path` 和普通索引 `idx_agent_skills_sync_status`
  - 编写 agent_skills 表字段 COMMENT
  - 编写 sync_log 表建表 DDL（id, entity_type, source_path, operation, direction, status, message, error_detail, sync_source, duration_ms, created_at）
  - 编写 sync_log 表索引（idx_sync_log_entity, idx_sync_log_time, idx_sync_log_status）
  - 使用 `BEGIN/COMMIT` 事务包裹，每阶段提供注释形式回滚语句
  - 使用 `IF NOT EXISTS` 保证幂等执行
- **输入**: design.md §4.2 数据模型 DDL
- **输出**: `scripts/migration/sync_system_mvp_v1.sql`
- **验收**: 在 PostgreSQL 上执行迁移脚本无报错，重复执行幂等，agents/agent_skills 表包含新增字段，sync_log 表创建成功

### 1.2 AgentPO/AgentSkillPO 新增同步字段 [P0 | 0.5h]
- [ ] 修改 `src/app/models/uctoo/AgentsPO.cj`，新增三个字段：
  - `@ORMField['source_path'] public var sourcePath: Option<String> = None`
  - `@ORMField['sync_status'] public var syncStatus: String = "pending"`
  - `@ORMField['last_sync_at'] public var lastSyncAt: Option<DateTime> = None`
- [ ] 修改 `src/app/models/uctoo/AgentSkillsPO.cj`，新增同上三个字段
- **输入**: design.md §4.2.4/§4.2.5 PO 新增字段定义
- **输出**: 修改后的 `AgentsPO.cj`、`AgentSkillsPO.cj`
- **验收**: 编译通过，PO 字段与数据库列名正确映射（snake_case → camelCase）

### 1.3 SyncLogPO 持久化对象与 SyncLogDAO [P0 | 1h]
- [ ] 使用 crudgen 生成 sync_log 表的标准 CRUD 模块（Model + DAO）
  - 若 crudgen 不支持，则手动创建 `src/app/models/uctoo/SyncLogPO.cj`
  - 使用 `@DataAssist[fields]` + `@QueryMappersGenerator["sync_log"]` 注解
  - 字段：id, entityType, sourcePath, operation, direction, status, message, errorDetail, syncSource, durationMs, createdAt
- [ ] 创建 `src/app/dao/uctoo/SyncLogDAO.cj`
  - 使用 `@DAO` 注解，继承 `RootDAO`
  - 提供基础 CRUD + 分页查询 + 按条件过滤（entity_type, status, 时间范围）
- **输入**: design.md §4.2.6 SyncLogPO 定义
- **输出**: `src/app/models/uctoo/SyncLogPO.cj`、`src/app/dao/uctoo/SyncLogDAO.cj`
- **验收**: 编译通过，DAO 可执行基本 CRUD 操作

### 1.4 关键数据类型定义 [P0 | 1h]
- [ ] 创建 `src/app/services/sync/model/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/model/SyncDirection.cj`：枚举 `FileSystemToDB | DBToFileSystem | Bidirectional`
- [ ] 创建 `src/app/services/sync/model/SyncStatus.cj`：枚举 `Pending | Synced | Error | DependencyMissing`
- [ ] 创建 `src/app/services/sync/model/TriggerSource.cj`：枚举 `Business | SyncSystem | Manual | Startup`
- [ ] 创建 `src/app/services/sync/model/SyncResult.cj`：同步结果类（success, entityType, entityId, status, message, errorDetail, durationMs, timestamp）
- [ ] 创建 `src/app/services/sync/model/SyncBatchResult.cj`：批量同步结果类（totalCount, successCount, failedCount, details）
- [ ] 创建 `src/app/services/sync/model/ConflictResult.cj`：冲突结果类（winner, message）
- [ ] 创建 `src/app/services/sync/model/SyncWinner.cj`：枚举 `FileSystem | Database | NoChange`
- [ ] 创建 `src/app/services/sync/model/FileChange.cj`：文件变更信息类（path, sourcePath, changeType, lastModified, entityType）
- [ ] 创建 `src/app/services/sync/model/ChangeType.cj`：枚举 `Created | Modified | Deleted`
- [ ] 创建 `src/app/services/sync/model/SyncStatusSummary.cj`：同步状态摘要类
- [ ] 创建 `src/app/services/sync/model/SyncEntityStatus.cj`：实体同步状态类
- **输入**: design.md §1.3.13 关键数据类型
- **输出**: `src/app/services/sync/model/` 目录下所有枚举和类文件
- **验收**: 编译通过，所有枚举值与 design.md 定义一致

### 1.5 SyncContext 同步上下文 [P0 | 1.5h]
- [ ] 创建 `src/app/services/sync/context/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/context/SyncContext.cj`
  - ThreadLocal 存储：`private static let threadLocal: ThreadLocal<Option<SyncContext>>`
  - 属性：triggerSource, direction, entityType, entityId
  - 静态方法：`enter(context)` 设置 ThreadLocal 标记、`exit()` 清除标记、`isPresent()` 检查是否处于同步上下文、`current()` 获取当前上下文
- **输入**: design.md §1.3.5 SyncContext 设计
- **输出**: `src/app/services/sync/context/SyncContext.cj`
- **验收**: 编译通过，enter/exit/isPresent 语义正确，ThreadLocal 线程隔离

---

## 2. 核心同步引擎 [Phase 2]

> **前置依赖**: Phase 1 全部完成

### 2.1 TopologySorter 拓扑排序器 [P0 | 1.5h]
- [ ] 创建 `src/app/services/sync/infrastructure/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/infrastructure/TopologySorter.cj`
  - `sort(handlers: Array<SyncHandler>): Array<SyncHandler>`：按依赖关系拓扑排序，被依赖实体排在前面
  - `detectCircularDependency(handlers: Array<SyncHandler>): Option<Array<String>>`：检测循环依赖，返回循环依赖的实体类型列表
  - 实现算法：Kahn 算法或 DFS 拓扑排序
- **输入**: design.md §1.3.11 TopologySorter 设计，SyncHandler 接口的 dependencies 属性
- **输出**: `src/app/services/sync/infrastructure/TopologySorter.cj`
- **验收**: agent 排在 agent_skill 前面，循环依赖能检测并返回告警

### 2.2 RetryManager 重试管理器 [P0 | 1h]
- [ ] 创建 `src/app/services/sync/retry/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/retry/RetryManager.cj`
  - `executeWithRetry(task, operation): SyncResult`：包装同步操作，加入重试逻辑
  - `calculateRetryDelay(attempt): Int64`：指数退避计算（1s, 2s, 4s），`baseMs * (1 << attempt)`
  - `maxRetries` 属性：默认 3 次，可通过配置覆盖
  - 每次重试前记录日志，重试耗尽后返回最终失败结果
- **输入**: design.md §1.3.12 RetryManager 设计，spec.md §4.2 可靠性约束
- **输出**: `src/app/services/sync/retry/RetryManager.cj`
- **验收**: 失败操作自动重试最多3次，重试间隔为1s/2s/4s，重试耗尽后返回失败

### 2.3 DataMapper 数据映射器 [P0 | 2h]
- [ ] 创建 `src/app/services/sync/mapper/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/mapper/DataMapper.cj`
  - `parseAgent(content, sourcePath): AgentPO`：解析 Agent Markdown Frontmatter → AgentPO
    - 提取 YAML frontmatter（name, type, description, model, tools 等）
    - Markdown 正文作为 systemPrompt
    - 设置 sourcePath
    - 宽容模式下缺失字段使用默认值
  - `serializeAgent(agent: AgentPO): String`：AgentPO → Markdown Frontmatter
    - 构建 YAML frontmatter
    - systemPrompt 作为 Markdown 正文
  - `parseAgentSkill(content, sourcePath): AgentSkillPO`：解析 AgentSkill Markdown Frontmatter → AgentSkillPO
  - `serializeAgentSkill(skill: AgentSkillPO): String`：AgentSkillPO → Markdown Frontmatter
  - `extractFrontmatter(content): JsonValue`：提取 YAML frontmatter
  - `buildFrontmatter(data: JsonValue): String`：构建 YAML frontmatter
  - `CURRENT_VERSION` 静态常量：映射版本号 = 1
- [ ] 复用现有 `yaml4cj` 库进行 YAML 解析，复用 `commonmark4cj` 进行 Markdown 处理
- **输入**: design.md §1.3.9 DataMapper 设计，§5.5 字段映射表
- **输出**: `src/app/services/sync/mapper/DataMapper.cj`
- **验收**: AGENTS.md 可正确解析为 AgentPO，AgentPO 可正确序列化为 Markdown Frontmatter，向前兼容处理缺失字段

### 2.4 ConflictResolver 冲突解决器 [P0 | 1h]
- [ ] 创建 `src/app/services/sync/resolver/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/resolver/ConflictResolver.cj`
  - `detectByTimestamp(fileModifiedAt, dbUpdatedAt, lastSyncAt): Option<ConflictResult>`：基于时间戳检测冲突
    - 冲突条件：fileModifiedAt > lastSyncAt && dbUpdatedAt > lastSyncAt
    - 首次同步（lastSyncAt 为 None）无冲突
  - `resolveByTimestamp(fileModifiedAt, dbUpdatedAt): ConflictResult`：Last-Write-Wins 解决策略
    - 文件侧较新 → FileSystem 胜出
    - 数据库侧较新 → Database 胜出
    - 相同 → NoChange
- **输入**: design.md §1.3.8 ConflictResolver 设计，spec.md §5.5 冲突解决规则
- **输出**: `src/app/services/sync/resolver/ConflictResolver.cj`
- **验收**: 并发修改正确检测，时间戳较晚方胜出，相同时间戳返回 NoChange

### 2.5 SyncStatusManager 同步状态管理器 [P0 | 1.5h]
- [ ] 创建 `src/app/services/sync/status/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/status/SyncStatusManager.cj`
  - `updateStatus(entityType, entityId, status, message?)`：更新实体表的 sync_status 字段
  - `updateAfterSync(entityType, entityId, sourcePath)`：同步完成后设置 synced + last_sync_at = now()
  - `getStatusSummary(): SyncStatusSummary`：查询全局同步状态概览（聚合 agents + agent_skills 表的 sync_status 统计）
  - `listStatus(entityType?, syncStatus?, page, pageSize): Pagination<SyncEntityStatus>`：分页查询实体同步状态
  - 内部通过 AgentsDAO/AgentSkillsDAO 查询和更新实体表字段
- **输入**: design.md §1.3.10 SyncStatusManager 设计
- **输出**: `src/app/services/sync/status/SyncStatusManager.cj`
- **验收**: 状态更新正确持久化到实体表，概览统计准确，分页查询正常

### 2.6 SyncHandler 接口定义 [P0 | 0.5h]
- [ ] 创建 `src/app/services/sync/handler/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/handler/SyncHandler.cj`
  - `prop entityType: String`：支持的实体类型
  - `prop basePath: String`：实体基础路径
  - `prop fileExtension: String`：文件扩展名
  - `prop dependencies: Array<String>`：实体依赖列表
  - `func syncFromFileSystem(sourcePath, context): SyncResult`：文件系统→数据库同步
  - `func syncToFileSystem(entityId, context): SyncResult`：数据库→文件系统同步
  - `func detectChanges(): Array<FileChange>`：检测文件变更
  - `func buildFilePath(sourcePath): String`：构建文件路径
- **输入**: design.md §1.3.2 SyncHandler 接口设计
- **输出**: `src/app/services/sync/handler/SyncHandler.cj`
- **验收**: 编译通过，接口契约完整

---

## 3. 实体同步处理器 [Phase 3]

> **前置依赖**: Phase 2 全部完成

### 3.1 AgentSyncHandler Agent 实体同步处理器 [P0 | 2h]
- [ ] 创建 `src/app/services/sync/handler/AgentSyncHandler.cj`
  - 实现 `SyncHandler` 接口
  - `entityType = "agent"`，`basePath = Config.syncAgentBasePath`，`fileExtension = ".md"`，`dependencies = []`
  - `syncFromFileSystem(sourcePath, context)`:
    1. 读取文件内容（FileSystemUtils.readFile）
    2. 解析为 AgentPO（DataMapper.parseAgent，向前兼容处理）
    3. 携带同步上下文执行 upsert（SyncContext.enter → AgentDAO.upsertBySourcePath → SyncContext.exit）
    4. 更新同步状态（SyncStatusManager.updateAfterSync）
    5. 返回 SyncResult
  - `syncToFileSystem(entityId, context)`:
    1. 从数据库读取 AgentPO（AgentDAO.selectById）
    2. 序列化为 Markdown Frontmatter（DataMapper.serializeAgent）
    3. 携带同步上下文写入文件（SyncContext.enter → FileSystemUtils.writeFile → SyncContext.exit）
    4. 更新同步状态
    5. 返回 SyncResult
  - `detectChanges()`: 调用 ChangeDetector.detectByTimestamp(basePath, entityType)
  - `buildFilePath(sourcePath)`: 拼接 basePath + sourcePath
- [ ] 在 AgentDAO 中新增 `upsertBySourcePath(agent: AgentPO)` 方法（以 source_path 为匹配键的 upsert）
- **输入**: design.md §1.3.3 AgentSyncHandler 设计
- **输出**: `src/app/services/sync/handler/AgentSyncHandler.cj`，修改 `AgentsDAO.cj`
- **验收**: Agent Markdown 文件可同步到数据库（upsert），数据库 Agent 可同步到文件系统，循环同步防护生效

### 3.2 AgentSkillSyncHandler AgentSkill 实体同步处理器 [P0 | 2h]
- [ ] 创建 `src/app/services/sync/handler/AgentSkillSyncHandler.cj`
  - 实现 `SyncHandler` 接口
  - `entityType = "agent_skill"`，`basePath = Config.syncSkillBasePath`，`fileExtension = ".md"`，`dependencies = ["agent"]`
  - `syncFromFileSystem(sourcePath, context)`:
    1. 读取文件内容
    2. 解析为 AgentSkillPO（DataMapper.parseAgentSkill）
    3. **依赖检查**：AgentDAO.existsById(skill.agentId)，不存在则标记 dependency_missing 并返回失败
    4. 携带同步上下文执行 upsert（AgentSkillDAO.upsertBySourcePath）
    5. 更新同步状态
    6. 返回 SyncResult
  - `syncToFileSystem(entityId, context)`: 同 AgentSyncHandler 模式
  - `detectChanges()`: 调用 ChangeDetector.detectByTimestamp
  - `buildFilePath(sourcePath)`: 拼接 basePath + sourcePath
- [ ] 在 AgentSkillDAO 中新增 `upsertBySourcePath(skill: AgentSkillPO)` 方法
- **输入**: design.md §1.3.4 AgentSkillSyncHandler 设计
- **输出**: `src/app/services/sync/handler/AgentSkillSyncHandler.cj`，修改 `AgentSkillsDAO.cj`
- **验收**: AgentSkill 文件可同步到数据库，依赖缺失时标记 dependency_missing，依赖满足后可正常同步

### 3.3 ChangeDetector 变更检测器 [P0 | 1.5h]
- [ ] 创建 `src/app/services/sync/detector/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/detector/ChangeDetector.cj`
  - `detectByTimestamp(path, entityType): Array<FileChange>`：
    1. 扫描目录获取文件列表及修改时间戳（递归扫描 .md 文件）
    2. 查询数据库中该实体类型的 last_sync_at
    3. 比对：文件修改时间 > last_sync_at 则判定为变更
    4. 检测已删除文件（数据库有 source_path 但文件不存在）
    5. 返回变更列表
  - `periodicScan()`：定时扫描入口
    1. 对每种注册的实体类型执行 detectByTimestamp
    2. 将检测到的变更合并为批量同步请求
    3. 按拓扑排序提交给 SyncManager
- **输入**: design.md §1.3.6 ChangeDetector 设计，spec.md §5.3 变更检测规则
- **输出**: `src/app/services/sync/detector/ChangeDetector.cj`
- **验收**: 修改时间戳晚于 last_sync_at 的文件被检测为变更，已删除文件被检测，多个变更合并为批量请求

---

## 4. 同步管理器与拦截器 [Phase 4]

> **前置依赖**: Phase 3 全部完成

### 4.1 SyncManager 核心同步控制器 [P0 | 3h]
- [ ] 创建 `src/app/services/sync/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/SyncManager.cj`
  - 单例模式：`private static let instance_ = AtomicOptionReference<SyncManager>()`
  - 内部组件：handlers（ConcurrentHashMap）、logService、dataMapper、conflictResolver、topologySorter、retryManager
  - `initialize(): SyncManager`：初始化同步管理器
    - 加载同步配置
    - 初始化同步基础设施（SyncContext）
    - 注册实体同步处理器（AgentSyncHandler, AgentSkillSyncHandler）
    - 注册 AOP 切面拦截器
    - 注册定时扫描任务
    - 异步执行初始化全量同步（不阻塞启动，超时阈值可配置）
  - `instance` 静态属性：获取单例实例
  - `registerHandler(entityType, handler)`：注册同步处理器
  - `triggerSync(entityType, entityId, direction, triggerSource): Future<SyncResult>`：触发同步（异步，携带同步上下文）
    - 构建同步上下文（SyncContext.enter）
    - 冲突检测（ConflictResolver.detectByTimestamp）
    - 根据冲突结果和同步方向调用对应 SyncHandler
    - 重试包装（RetryManager.executeWithRetry）
    - 记录同步日志（SyncLogService）
    - 更新同步状态（SyncStatusManager）
    - 退出同步上下文（SyncContext.exit）
  - `syncAll(entityType?): SyncBatchResult`：批量同步所有实体（按拓扑排序执行）
    - 获取所有注册的 SyncHandler
    - TopologySorter.sort 排序
    - 对每个 handler 执行 detectChanges + syncFromFileSystem
    - 汇总结果
  - `getStatusSummary(): SyncStatusSummary`：获取同步状态概览
  - `stop()`：停止同步管理器
- **输入**: design.md §1.3.1 SyncManager 设计，§1.2 应用启动流程
- **输出**: `src/app/services/sync/SyncManager.cj`
- **验收**: 单例初始化成功，单实体同步端到端流程正确，批量同步按拓扑排序执行，循环同步防护生效

### 4.2 SyncInterceptor AOP 同步拦截器 [P0 | 2h]
- [ ] 创建 `src/app/services/sync/interceptor/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/interceptor/SyncInterceptor.cj`
  - 使用 `@AspectRoute` 注解定义切点规则：
    - 包路径包含：`magic.app.dao.uctoo.*`
    - 包路径排除：`magic.app.dao.sync.*`（预留，当前同步系统 DAO 在 uctoo 包下，需通过实体类型白名单排除）
    - 方法名匹配：`insert*|update*|delete*`
  - 实现 `Aspect` 接口，重写 `after` 方法：
    1. **循环同步防护**：检查 `SyncContext.isPresent()`，若为 true 则跳过拦截
    2. **拦截范围限定**：实体类型白名单检查（agent, agent_skill）
    3. 提取实体类型和实体 ID
    4. 异步触发文件同步（`spawn { SyncManager.instance?.triggerSync(...) }`）
    5. 不影响原数据库操作返回
  - 实体类型白名单：`HashSet(["agent", "agent_skill"])`
  - `extractEntityType(funcInfo)`: 从 DAO 类名提取实体类型（AgentDAO → agent）
  - `extractEntityId(entity)`: 从实体对象提取 ID
- [ ] 在 SyncManager.initialize() 中注册切面：`AspectRegistry.register(SyncInterceptor())` 或通过 `@Bean` 自动注册
- **输入**: design.md §1.3.7 SyncInterceptor 设计，§3.2 f_aspect 集成
- **输出**: `src/app/services/sync/interceptor/SyncInterceptor.cj`
- **验收**: AgentDAO/AgentSkillDAO 的 insert/update/delete 操作被拦截并触发文件同步，SyncLogDAO 操作不被拦截，同步系统触发的数据库操作不触发反向同步

### 4.3 SyncScanJob 定时扫描任务 [P0 | 1h]
- [ ] 创建 `src/app/services/sync/job/pkg.cj` 包声明
- [ ] 创建 `src/app/services/sync/job/SyncScanJob.cj`
  - 实现 `BuiltinTaskHandler` 接口（复用现有 crontab 内置任务处理器模式）
  - `handle(context: CrontabExecutionContext): ExecutionResult`:
    1. 检查同步功能开关（`Config.syncEnabled`），关闭则跳过
    2. 执行变更检测（`ChangeDetector.periodicScan()`）
    3. 返回执行结果
  - 在 `BuiltinExecutor` 初始化时注册：`builtinExecutor.registerBuiltinTask("sync-periodic-scan", SyncScanJob())`
- [ ] 在 crontab_task_registry 表中插入初始数据（`ON CONFLICT DO NOTHING`）：
  - type: 'builtin', prefix: 'builtin://sync-periodic-scan', name: 'sync-periodic-scan'
- [ ] 在 crontab 表中插入默认定时任务记录（每60秒执行，可配置）
- **输入**: design.md §3.3 crontab 集成，现有 BuiltinTaskHandler 模式
- **输出**: `src/app/services/sync/job/SyncScanJob.cj`，修改 `BuiltinExecutor.cj`，迁移脚本补充
- **验收**: 定时任务注册成功，每60秒触发一次变更检测扫描，同步功能开关关闭时不执行扫描

---

## 5. 服务层与接入层 [Phase 5]

> **前置依赖**: Phase 4 全部完成

### 5.1 SyncService 同步编排服务 [P0 | 1.5h]
- [ ] 创建 `src/app/services/uctoo/SyncService.cj`
  - `syncEntity(entityType, entityId, direction): APIResult<SyncResult>`：手动触发单个实体同步
    - 构建 TriggerSource.Manual 上下文
    - 调用 SyncManager.triggerSync
  - `syncBatch(entityType?): APIResult<SyncBatchResult>`：批量同步
    - 调用 SyncManager.syncAll
  - `getStatusSummary(): APIResult<SyncStatusSummary>`：获取同步状态概览
  - `listEntityStatus(entityType?, syncStatus?, page, pageSize): APIResult<Pagination<SyncEntityStatus>>`：分页查询实体同步状态
  - `getEntityStatus(entityType, entityId): APIResult<SyncEntityStatus>`：获取单个实体同步状态
  - `healthCheck(): APIResult<HealthResult>`：健康检查
- **输入**: design.md §2.2 接口清单
- **输出**: `src/app/services/uctoo/SyncService.cj`
- **验收**: 服务方法正确委托给 SyncManager/SyncStatusManager，返回 APIResult 封装

### 5.2 SyncLogService 日志管理服务 [P0 | 1h]
- [ ] 创建 `src/app/services/uctoo/SyncLogService.cj`
  - `logSync(result: SyncResult, direction, triggerSource)`：记录同步日志
    - 构建 SyncLogPO 对象
    - 调用 SyncLogDAO.insert
  - `listLogs(entityType?, status?, page, pageSize): APIResult<Pagination<SyncLogPO>>`：分页查询同步日志
  - `cleanup(retentionDays)`：清理过期日志（默认30天）
- **输入**: design.md §4.2.3 sync_log 表设计，spec.md §6.3 同步日志数据约束
- **输出**: `src/app/services/uctoo/SyncLogService.cj`
- **验收**: 同步日志正确记录和查询，过期日志可清理

### 5.3 SyncController 同步管理控制器 [P0 | 1.5h]
- [ ] 创建 `src/app/controllers/uctoo/sync/SyncController.cj`
  - `getStatus(req, res)`：GET /api/v1/uctoo/sync/status → SyncService.getStatusSummary
  - `listEntities(req, res)`：GET /api/v1/uctoo/sync/entities → SyncService.listEntityStatus
  - `listEntitiesByType(req, res)`：GET /api/v1/uctoo/sync/entities/:type → SyncService.listEntityStatus（按类型过滤）
  - `getEntityStatus(req, res)`：GET /api/v1/uctoo/sync/entities/:type/:id → SyncService.getEntityStatus
  - `syncEntity(req, res)`：POST /api/v1/uctoo/sync/entities/:type/:id → SyncService.syncEntity
  - `syncBatch(req, res)`：POST /api/v1/uctoo/sync/entities/:type/batch → SyncService.syncBatch
  - `syncAll(req, res)`：POST /api/v1/uctoo/sync/batch → SyncService.syncBatch（所有类型）
  - `listLogs(req, res)`：GET /api/v1/uctoo/sync/logs → SyncLogService.listLogs
  - `healthCheck(req, res)`：GET /api/v1/uctoo/sync/health → SyncService.healthCheck
  - 所有接口需认证鉴权（JWT），权限检查（sync:read / sync:write）
- **输入**: design.md §2.2 接口清单，现有 Controller 模式
- **输出**: `src/app/controllers/uctoo/sync/SyncController.cj`
- **验收**: 所有 API 端点可达，未授权请求返回 401，响应格式符合 UMI 规范

### 5.4 SyncRoute 路由注册 [P0 | 0.5h]
- [ ] 创建 `src/app/routes/uctoo/sync/SyncRoute.cj`
  - 注册所有同步管理 API 路由：
    - GET /api/v1/uctoo/sync/status
    - GET /api/v1/uctoo/sync/entities
    - GET /api/v1/uctoo/sync/entities/:type
    - GET /api/v1/uctoo/sync/entities/:type/:id
    - POST /api/v1/uctoo/sync/entities/:type/:id
    - POST /api/v1/uctoo/sync/entities/:type/batch
    - POST /api/v1/uctoo/sync/batch
    - GET /api/v1/uctoo/sync/logs
    - GET /api/v1/uctoo/sync/health
  - 使用 `@AutoRoute` 注解或手动注册到 Router
  - 挂载认证和权限中间件
- **输入**: design.md §3.5 路由注册，现有 Route 模式
- **输出**: `src/app/routes/uctoo/sync/SyncRoute.cj`
- **验收**: 路由注册成功，API 端点可通过 HTTP 请求访问

---

## 6. 集成与配置 [Phase 6]

> **前置依赖**: Phase 5 全部完成

### 6.1 与 AgentLoadManager 集成 [P0 | 1.5h]
- [ ] 修改 `src/core/agent/agent_loader.cj` 中的 `AgentLoadManager`
  - 在 `loadFromDirs()` 方法执行完成后，触发 SyncManager 的初始化全量同步
  - 集成方式：`AgentLoadManager.loadFromDirs()` 完成后 → `SyncManager.instance?.syncAll(None)`（异步，不阻塞）
  - 确保启动顺序：ORM.initialize → AgentLoadManager.loadFromDirs → SyncManager.initialize → async syncAll
- **输入**: design.md §3.1 与 AgentManager 集成，现有 AgentLoadManager 代码
- **输出**: 修改后的 `src/core/agent/agent_loader.cj`
- **验收**: 应用启动时自动触发全量同步，不阻塞启动流程，超时后应用正常启动

### 6.2 配置项定义 [P0 | 0.5h]
- [ ] 在 `.env` 文件中新增同步配置项：
  - `SYNC_ENABLED=true`：同步功能开关
  - `SYNC_SCAN_INTERVAL=60`：文件扫描间隔（秒）
  - `SYNC_MAX_RETRIES=3`：最大重试次数
  - `SYNC_STARTUP_TIMEOUT=30`：启动全量同步超时（秒）
  - `SYNC_AGENT_BASE_PATH=./`：Agent 基础路径
  - `SYNC_SKILL_BASE_PATH=./.codeartsdoer/skills`：AgentSkill 基础路径
  - `SYNC_MAPPING_MODE=lenient`：映射模式（strict/lenient）
  - `SYNC_LOG_RETENTION_DAYS=30`：日志保留天数
- [ ] 在 `.env.example` 文件中同步新增上述配置项（含注释说明）
- [ ] 创建 `src/app/services/sync/SyncConfig.cj` 配置类，读取环境变量并提供默认值
- **输入**: design.md §3.4 配置项，现有 .env 配置模式
- **输出**: 修改后的 `.env`、`.env.example`，新增 `src/app/services/sync/SyncConfig.cj`
- **验收**: 配置项可通过环境变量读取，SYNC_ENABLED=false 时同步功能完全关闭

### 6.3 应用启动流程集成 [P0 | 1h]
- [ ] 修改 `src/app/main.cj` 的启动流程，在 `setupRoutes()` 之后新增：
  - `SyncManager.initialize()`：初始化同步管理器（注册处理器、注册拦截器、注册定时任务）
  - 异步执行 `SyncManager.instance?.syncAll(None)`，设置超时阈值
- [ ] 确保 SyncManager 初始化在 ORM 初始化和路由注册之后
- [ ] 确保同步功能开关（SYNC_ENABLED）关闭时，跳过所有同步初始化
- **输入**: design.md §1.2 应用启动流程，现有 main.cj 启动流程
- **输出**: 修改后的 `src/app/main.cj`
- **验收**: 应用启动时 SyncManager 正确初始化，全量同步异步执行不阻塞，开关关闭时无同步行为

### 6.4 cjpm.toml 依赖声明 [P0 | 0.5h]
- [ ] 确认 `cjpm.toml` 中已包含所需依赖：
  - `f_aspect`（通过 f_orm 间接依赖，确认可访问）
  - `f_filesystem`（如需新增则添加：`f_filesystem = { path = "./libs/fountain/f_filesystem" }`）
  - `yaml4cj`（已存在）
  - `commonmark4cj`（已存在）
  - `json4cj`（已存在）
- [ ] 如需新增依赖，更新 `cjpm.toml` 并执行 `cjpm update`
- **输入**: design.md §9.1 依赖声明，现有 cjpm.toml
- **输出**: 修改后的 `cjpm.toml`（如需）
- **验收**: 编译通过，所有依赖可正确解析

---

## 7. 测试 [Phase 7]

> **前置依赖**: Phase 6 全部完成

### 7.1 单元测试 [P1 | 4h]
- [ ] 创建 `tests/sync/` 测试目录
- [ ] TopologySorter 单元测试
  - 测试正常拓扑排序（agent → agent_skill）
  - 测试循环依赖检测
  - 测试无依赖实体排序
- [ ] RetryManager 单元测试
  - 测试成功操作不重试
  - 测试失败操作重试3次
  - 测试指数退避间隔计算
- [ ] DataMapper 单元测试
  - 测试 Agent Markdown Frontmatter 解析
  - 测试 AgentPO 序列化为 Markdown
  - 测试 AgentSkill Markdown Frontmatter 解析
  - 测试 AgentSkillPO 序列化
  - 测试向前兼容处理（缺失字段）
  - 测试严格模式/宽容模式
- [ ] ConflictResolver 单元测试
  - 测试无冲突场景
  - 测试文件侧较新
  - 测试数据库侧较新
  - 测试首次同步无冲突
  - 测试相同时间戳
- [ ] SyncContext 单元测试
  - 测试 enter/exit 上下文生命周期
  - 测试 isPresent 检测
  - 测试 ThreadLocal 线程隔离
- [ ] ChangeDetector 单元测试
  - 测试基于时间戳的变更检测
  - 测试已删除文件检测
  - 测试无变更场景
- **输入**: spec.md §7 验收标准
- **输出**: `tests/sync/` 目录下所有测试文件
- **验收**: 所有单元测试通过

### 7.2 集成测试 [P1 | 3h]
- [ ] 端到端同步流程集成测试
  - 测试文件系统→数据库同步（Agent Markdown → agents 表 upsert）
  - 测试数据库→文件系统同步（Agent 记录 → Markdown 文件创建/更新/删除）
  - 测试双向同步幂等性（多次执行结果一致）
- [ ] 循环同步防护集成测试
  - 测试同步系统写入数据库不触发反向同步
  - 测试 SyncContext 标记正确传递
- [ ] AOP 拦截集成测试
  - 测试 AgentDAO.insert 触发文件同步
  - 测试 AgentSkillDAO.update 触发文件同步
  - 测试 SyncLogDAO 操作不被拦截
- [ ] 实体依赖集成测试
  - 测试批量同步按拓扑排序执行（agent 先于 agent_skill）
  - 测试 agent_skill 依赖缺失时标记 dependency_missing
- [ ] API 接口集成测试
  - 测试手动触发同步 API
  - 测试同步状态查询 API
  - 测试同步日志查询 API
  - 测试健康检查 API
  - 测试未授权请求返回 401
- [ ] 启动流程集成测试
  - 测试应用启动时全量同步触发
  - 测试同步功能开关关闭时无同步行为
- **输入**: spec.md §7 全部验收标准
- **输出**: `tests/sync/integration/` 目录下所有测试文件
- **验收**: 所有集成测试通过，覆盖 spec.md §7 全部验收标准

---

## 任务统计

| Phase | 任务组 | 任务数 | 优先级 | 预估总工时 |
|-------|--------|--------|--------|-----------|
| 1 | 数据模型与基础设施 | 5 | P0 | 5h |
| 2 | 核心同步引擎 | 6 | P0 | 7.5h |
| 3 | 实体同步处理器 | 3 | P0 | 5.5h |
| 4 | 同步管理器与拦截器 | 3 | P0 | 6h |
| 5 | 服务层与接入层 | 4 | P0 | 4.5h |
| 6 | 集成与配置 | 4 | P0 | 3.5h |
| 7 | 测试 | 2 | P1 | 7h |
| **合计** | **7 个阶段** | **27 个任务** | - | **39h** |

### 需求覆盖映射

| spec.md 验收标准章节 | 覆盖任务 |
|---------------------|---------|
| §7.1 双向同步功能验收 | 3.1, 3.2, 4.1, 7.2 |
| §7.2 循环同步防护验收 | 1.5, 4.2, 7.2 |
| §7.3 幂等性验收 | 3.1, 3.2, 4.1, 7.2 |
| §7.4 AOP 拦截验收 | 4.2, 7.2 |
| §7.5 变更检测验收 | 3.3, 4.3, 7.1 |
| §7.6 冲突解决验收 | 2.4, 7.1 |
| §7.7 数据映射验收 | 2.3, 7.1 |
| §7.8 实体依赖验收 | 2.1, 3.2, 7.2 |
| §7.9 source_path 唯一标识验收 | 1.1, 1.2, 3.1, 3.2, 7.2 |
| §7.10 性能验收 | 4.1, 7.2 |
| §7.11 可靠性验收 | 2.2, 4.1, 7.2 |
| §7.12 API 验收 | 5.3, 5.4, 7.2 |
| §7.13 数据库设计验收 | 1.1, 1.2, 7.2 |

---

**文档维护者**: UCToo Team  
**最后更新**: 2026-06-03