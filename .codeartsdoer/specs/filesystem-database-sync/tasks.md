# 文件系统与数据库双向同步系统 - 编码任务规划

**版本**: v2.0.0  
**创建日期**: 2026-06-02  
**关联需求**: spec.md v2.0.0  
**关联设计**: design.md v2.0.0  
**目标模块**: agentskills-runtime

---

## 任务总览

### Phase 划分

| Phase | 名称 | 任务数 | 优先级 | 说明 |
|-------|------|--------|--------|------|
| **Phase 0** | 数据库建模与DDL | 4 | P0 | 四张表DDL、索引、约束 |
| **Phase 1** | CRUD代码生成 | 4 | P0 | crudgen生成标准五层模块 |
| **Phase 2** | 同步引擎基础设施层 | 12 | P0 | SyncContext、ContentHasher、VersionVector等 |
| **Phase 3** | 同步引擎核心层 | 8 | P0 | SyncManager、SyncHandler接口、ChangeDetector等 |
| **Phase 4** | AOP拦截与循环防护 | 4 | P0 | SyncInterceptor、CircuitBreakerManager |
| **Phase 5** | 数据映射与处理器 | 6 | P1 | DataMapper、AgentSyncHandler等 |
| **Phase 6** | 冲突解决机制 | 4 | P1 | ConflictResolver、ThreeWayMerge |
| **Phase 7** | 限流背压与队列 | 4 | P1 | RateLimiter、PrioritySyncQueue、DebounceWindow |
| **Phase 8** | 服务层与接入层 | 6 | P0 | SyncService、SyncController、SyncRoute |
| **Phase 9** | 可观测性与事件 | 4 | P2 | SyncMetrics、SyncEventPublisher、健康检查 |
| **Phase 10** | 应用集成与配置 | 5 | P0 | 启动流程集成、配置项、权限 |
| **Phase 11** | 测试与验证 | 6 | P0 | 单元测试、集成测试、性能测试 |

**总计**: 11 个 Phase，67 个任务

### 优先级分布

| 优先级 | 任务数 | 说明 |
|--------|--------|------|
| P0（必须） | 35 | 循环同步防护、AOP拦截范围限定、核心同步引擎、接入层、集成、测试 |
| P1（重要） | 14 | 变更检测、冲突解决、幂等性、限流背压 |
| P2（增强） | 18 | 可观测性、领域事件、数据映射、处理器 |

### 关键路径

```
Phase 0 (DDL) → Phase 1 (CRUD) → Phase 2 (基础设施) → Phase 3 (核心引擎) → Phase 4 (AOP拦截) → Phase 8 (服务/接入) → Phase 10 (集成) → Phase 11 (测试)
```

**关键路径耗时估算**: 约 12-15 个工作日

---

## Phase 0: 数据库建模与DDL

> **目标**: 创建同步系统四张核心表的DDL文件  
> **依赖**: 无  
> **预估耗时**: 0.5 天

### T0-1 编写 sync_status 表 DDL
- [ ] 创建 `scripts/migration/sync_system_v2.sql`，编写 sync_status 表建表语句
- **描述**: 包含 id、entity_type、entity_id、file_path、content_hash、db_version_clock、file_version_clock、base_db_clock、base_file_clock、sync_status、sync_direction、trigger_source、last_sync_at、error_message、retry_count、mapping_version、creator、created_at、updated_at、deleted_at 字段，以及唯一约束 `uk_sync_status_entity(entity_type, entity_id)` 和索引 `idx_sync_status_entity`、`idx_sync_status_status`、`idx_sync_status_content_hash`
- **优先级**: P0
- **验收标准**: DDL 可在 PostgreSQL 中执行，表结构与 design.md 4.2.1 一致

### T0-2 编写 sync_log 表 DDL
- [ ] 在同一迁移脚本中编写 sync_log 表建表语句
- **描述**: 包含 id、entity_type、entity_id、operation、direction、status、message、error_detail、operator_id、sync_source、trace_id、task_id、duration_ms、created_at 字段，以及索引 `idx_sync_log_entity`、`idx_sync_log_time`、`idx_sync_log_status`、`idx_sync_log_task_id`、`idx_sync_log_duration`
- **优先级**: P0
- **验收标准**: DDL 可在 PostgreSQL 中执行，表结构与 design.md 4.2.2 一致

### T0-3 编写 sync_conflict 表 DDL
- [ ] 在同一迁移脚本中编写 sync_conflict 表建表语句
- **描述**: 包含 id、entity_type、entity_id、conflict_status、resolution_strategy、base_version_hash、ours_version_hash、theirs_version_hash、resolved_version_hash、resolution_detail、detected_at、resolved_by、resolved_at、created_at、updated_at 字段，以及唯一约束 `uk_sync_conflict_entity_time(entity_type, entity_id, detected_at)` 和索引 `idx_sync_conflict_entity`、`idx_sync_conflict_status`
- **优先级**: P0
- **验收标准**: DDL 可在 PostgreSQL 中执行，表结构与 design.md 4.2.3 一致

### T0-4 编写 sync_task 表 DDL
- [ ] 在同一迁移脚本中编写 sync_task 表建表语句
- **描述**: 包含 id、task_id、task_type、entity_type、entity_id、direction、priority、task_status、sync_source、trace_id、created_at、started_at、completed_at 字段，以及唯一约束 `uk_sync_task_task_id(task_id)` 和索引 `idx_sync_task_status`、`idx_sync_task_entity`、`idx_sync_task_created`
- **优先级**: P0
- **验收标准**: DDL 可在 PostgreSQL 中执行，表结构与 design.md 4.2.4 一致

---

## Phase 1: CRUD代码生成

> **目标**: 使用 crudgen 生成四张表的标准 CRUD 五层模块  
> **依赖**: Phase 0  
> **预估耗时**: 0.5 天

### T1-1 执行数据库DDL并刷新db_info
- [ ] 人工执行 `scripts/migration/sync_system_v2.sql`，然后调用 `/api/v1/uctoo/db_info/load-db-info` 接口刷新 db_info 表
- **描述**: 确保四张新表已创建且 db_info 已更新，crudgen 依赖 db_info 元数据
- **优先级**: P0
- **验收标准**: 四张表在数据库中存在，db_info 中包含四张表的元数据

### T1-2 使用crudgen生成 sync_status 标准CRUD
- [ ] 运行 crudgen 为 sync_status 表生成 Model、DAO、Service、Controller、Route 五层代码
- **描述**: 生成文件：`models/uctoo/SyncStatusPO.cj`、`dao/uctoo/SyncStatusDAO.cj`、`services/uctoo/SyncStatusService.cj`、`controllers/uctoo/sync_status/SyncStatusController.cj`、`routes/uctoo/sync_status/SyncStatusRoute.cj`
- **优先级**: P0
- **验收标准**: 五层代码生成，编译通过，标准 CRUD 接口可用

### T1-3 使用crudgen生成 sync_log/sync_conflict/sync_task 标准CRUD
- [ ] 运行 crudgen 为 sync_log、sync_conflict、sync_task 三张表生成五层代码
- **描述**: 生成文件包括 SyncLogPO/DAO/Service/Controller/Route、SyncConflictPO/DAO/Service/Controller/Route、SyncTaskPO/DAO/Service/Controller/Route
- **优先级**: P0
- **验收标准**: 三组五层代码生成，编译通过，标准 CRUD 接口可用

### T1-4 在AutoRouteConfig中注册四组标准路由
- [ ] 在 `src/app/registry/AutoRouteConfig.cj` 中添加四张表的 RouteEntry 注册
- **描述**: 添加 sync_status、sync_log、sync_conflict、sync_task 四个模块的路由注册项，遵循现有模块注册模式
- **优先级**: P0
- **验收标准**: 应用启动后四组标准 CRUD API 可访问

---

## Phase 2: 同步引擎基础设施层

> **目标**: 实现同步引擎的基础设施工具类和核心数据类型  
> **依赖**: Phase 1  
> **预估耗时**: 3 天

### T2-1 定义同步引擎核心枚举与数据类型
- [ ] 创建 `src/app/services/sync/model/` 包，实现 SyncDirection、SyncStatus、SyncPriority、TriggerSource、TaskType、ConflictStatus、BackpressureStrategy 等枚举，以及 SyncResult、SyncBatchResult、SyncTask、FileChange、ChangeType 等数据类
- **描述**: 包路径 `magic.app.services.sync.model`，参照 design.md 1.3.22 关键数据类型定义
- **优先级**: P0
- **依赖**: 无（纯类型定义）
- **验收标准**: 所有枚举和数据类编译通过，字段完整

### T2-2 实现 SyncContext（同步上下文）
- [ ] 创建 `src/app/services/sync/context/SyncContext.cj`，实现 ThreadLocal 同步上下文
- **描述**: 包含 taskId、triggerSource、triggerChain、traceId、direction、entityType、entityId 字段，实现 `enter()`/`exit()`/`isPresent()`/`current()`/`hasCircularTrigger()` 方法，参照 design.md 1.3.4
- **优先级**: P0
- **依赖**: T2-1
- **验收标准**: ThreadLocal 标记正确设置和清除，循环检测逻辑正确

### T2-3 实现 ContentHasher（内容哈希计算器）
- [ ] 创建 `src/app/services/sync/infrastructure/ContentHasher.cj`，实现 SHA-256 哈希计算
- **描述**: 实现 `computeSHA256(content: String): String`、`computeFileHash(filePath: String): String`、`verifyHash(content: String, expectedHash: String): Bool` 方法，使用仓颉标准库或 f_crypto 库
- **优先级**: P0
- **依赖**: T2-1
- **验收标准**: SHA-256 计算结果正确，64位十六进制输出，文件哈希计算正确

### T2-4 实现 VersionVector（版本向量）
- [ ] 创建 `src/app/services/sync/infrastructure/VersionVector.cj`，实现分布式版本向量
- **描述**: 包含 fileClock、dbClock、baseFileClock、baseDbClock 字段，实现 `incrementFileClock()`、`incrementDbClock()`、`hasConflict()`、`updateBase()`、`toJson()`、`fromJson()` 方法，参照 design.md 1.3.9
- **优先级**: P1
- **依赖**: T2-1
- **验收标准**: 冲突检测逻辑正确（fileClock > baseFileClock && dbClock > baseDbClock），JSON 序列化/反序列化正确

### T2-5 实现 TopologySorter（拓扑排序器）
- [ ] 创建 `src/app/services/sync/infrastructure/TopologySorter.cj`，实现实体依赖拓扑排序
- **描述**: 实现 `sort(handlers: Array<SyncHandler>): Array<SyncHandler>` 和 `detectCircularDependency()` 方法，确保 agent → agent_skill → skill 排序顺序
- **优先级**: P0
- **依赖**: T2-1, T3-1（SyncHandler接口）
- **验收标准**: 拓扑排序结果正确，循环依赖检测正确

### T2-6 实现 DebounceWindow（防抖窗口）
- [ ] 创建 `src/app/services/sync/detector/DebounceWindow.cj`，实现文件变更事件防抖与批量合并
- **描述**: 实现 `collect(change: FileChange)`、`collectBatch(changes)`、`flush(): Array<FileChange>`、`mergeRate` 属性，窗口默认 500ms，参照 design.md 1.3.6
- **优先级**: P1
- **依赖**: T2-1
- **验收标准**: 窗口内同一实体多次变更合并为一次，防抖合并率 Metrics 正确

### T2-7 实现 RateLimiter（限流器）
- [ ] 创建 `src/app/services/sync/infrastructure/RateLimiter.cj`，实现令牌桶/滑动窗口限流
- **描述**: 实现 `tryAcquire()`/`tryAcquire(entityType)`/`rejectedCount`，支持全局 QPS + 单实体类型 QPS 双维度限流，默认 100 QPS，参照 design.md 1.3.12
- **优先级**: P1
- **依赖**: T2-1
- **验收标准**: 限流正确，超出 QPS 上限的请求被拒绝，rejectedCount 计数正确

### T2-8 实现 PrioritySyncQueue（优先级同步队列）
- [ ] 创建 `src/app/services/sync/infrastructure/PrioritySyncQueue.cj`，实现三级优先级队列与背压
- **描述**: 实现 `enqueue(task, priority)`/`dequeue()`/`depth`/`isHighWatermark`/`usageRate`，支持高/中/低三级队列，高水位 80% 触发背压，参照 design.md 1.3.14
- **优先级**: P1
- **依赖**: T2-1
- **验收标准**: 高优先级优先出队，背压策略正确触发，队列深度统计正确

### T2-9 实现 CircuitBreakerManager（熔断管理器）
- [ ] 创建 `src/app/services/sync/infrastructure/CircuitBreakerManager.cj`，实现循环同步检测与熔断
- **描述**: 实现 `recordTrigger()`/`isCircuitBroken()`/`recover()`/`circuitBreakerCount`，检测窗口默认 10 秒，阈值默认 3 次，熔断持续 60 秒，参照 design.md 1.3.13
- **优先级**: P0
- **依赖**: T2-1
- **验收标准**: 窗口内超过阈值触发熔断，熔断后 `isCircuitBroken()` 返回 true，超时自动恢复，手动恢复正确

### T2-10 实现 RetryManager（重试管理器）
- [ ] 创建 `src/app/services/sync/retry/RetryManager.cj`，实现同步失败自动重试（指数退避）
- **描述**: 实现 `executeWithRetry(task, operation)`/`calculateRetryDelay(attempt)`/`maxRetries`，指数退避 1s/2s/4s，最多 3 次，复用 crontab_sched 模式，参照 design.md 1.3.20
- **优先级**: P0
- **依赖**: T2-1
- **验收标准**: 重试次数不超过 3 次，退避间隔 1s/2s/4s，重试耗尽后返回失败结果

### T2-11 实现 AsyncLogWriter（异步日志写入器）
- [ ] 创建 `src/app/services/sync/logging/AsyncLogWriter.cj`，实现异步写入同步日志
- **描述**: 实现 `writeLog(log: SyncLogPO)`/`writeLogs(logs)`/`flush()`/`stop()`，复用 crontab_sched 的 AsyncLogWriter 模式，参照 design.md 1.3.21
- **优先级**: P0
- **依赖**: T1-3（SyncLogPO）
- **验收标准**: 日志异步写入不阻塞主线程，flush 刷新缓冲正确

### T2-12 扩展DAO定制查询方法
- [ ] 在 SyncStatusDAO、SyncTaskDAO、SyncConflictDAO、SyncLogDAO 的定制区域添加自定义查询方法
- **描述**:
  - SyncStatusDAO: `upsertSyncStatus()`、`findByEntityTypeAndEntityId()`、`findBySyncStatus()`、`countBySyncStatus()`
  - SyncTaskDAO: `findByTaskId()`、`findByTaskStatus()`、`updateTaskStatus()`
  - SyncConflictDAO: `findByConflictStatus()`、`findByEntityTypeAndEntityId()`
  - SyncLogDAO: `findByTimeRange()`、`cleanBeforeDate()`
- **优先级**: P0
- **依赖**: T1-2, T1-3
- **验收标准**: 自定义查询方法编译通过，查询结果正确

---

## Phase 3: 同步引擎核心层

> **目标**: 实现同步管理器、同步处理器接口、变更检测器、同步状态管理器  
> **依赖**: Phase 2  
> **预估耗时**: 3 天

### T3-1 定义 SyncHandler 接口
- [ ] 创建 `src/app/services/sync/handler/SyncHandler.cj`，定义同步处理器契约
- **描述**: 包含 `entityType`、`basePath`、`fileExtension`、`dependencies` 属性，以及 `syncFromFileSystem()`、`syncToFileSystem()`、`detectChanges()`、`extractEntityId()`、`buildFilePath()`、`computeContentHash()` 方法，参照 design.md 1.3.2
- **优先级**: P0
- **依赖**: T2-1
- **验收标准**: 接口定义完整，所有方法签名与设计一致

### T3-2 实现 SyncStatusManager（同步状态管理器）
- [ ] 创建 `src/app/services/sync/status/SyncStatusManager.cj`，实现同步状态管理
- **描述**: 实现 `updateStatus()`/`updateAfterSync()`/`getStatus()`/`getStatusSummary()`/`batchUpdateStatus()`/`getRunningSyncs()`/`gracefulShutdown()` 方法，参照 design.md 1.3.19
- **优先级**: P0
- **依赖**: T2-12（SyncStatusDAO定制方法）
- **验收标准**: 状态更新原子性，概览统计正确，优雅关闭等待运行中任务完成

### T3-3 实现 ChangeDetector（变更检测器）
- [ ] 创建 `src/app/services/sync/detector/ChangeDetector.cj`，实现文件变更检测
- **描述**: 实现 `startListening()`/`stopListening()`/`scan()`/`startPeriodicScan()`/`detect()` 方法，支持 hash/timestamp/hybrid 三种策略，集成防抖窗口与节流，参照 design.md 1.3.5
- **优先级**: P1
- **依赖**: T2-3（ContentHasher）, T2-6（DebounceWindow）, T2-12（SyncStatusDAO）
- **验收标准**: 三种检测策略正确，hybrid 策略先时间戳快速排除再 hash 确认

### T3-4 实现 SyncManager 核心框架
- [ ] 创建 `src/app/services/sync/SyncManager.cj`，实现同步管理器核心框架
- **描述**: 单例模式，实现 `initialize()`/`registerHandler()`/`triggerSync()`/`sync()`/`syncAll()`/`getStatusSummary()`/`getStatus()`/`cancelTask()`/`stop()` 方法，集成 handlers 注册表、entityLocks 互斥锁、taskDedupMap 去重表，参照 design.md 1.3.1
- **优先级**: P0
- **依赖**: T2-1, T2-2, T2-5, T2-8, T2-9, T2-10, T3-2
- **验收标准**: 处理器注册正确，同步触发异步执行，拓扑排序执行批量同步，任务去重正确

### T3-5 实现 SyncManager 幂等性保证
- [ ] 在 SyncManager 中实现任务幂等性保证逻辑
- **描述**: 同步任务携带唯一 taskId，taskDedupMap 存储已执行任务结果，重复提交返回已有结果不重复执行，upsert 语义确保重复执行结果一致
- **优先级**: P1
- **依赖**: T3-4
- **验收标准**: 同一 taskId 重复提交返回相同结果，不产生副作用

### T3-6 实现 SyncManager 并发互斥
- [ ] 在 SyncManager 中实现同一实体并发同步互斥逻辑
- **描述**: entityLocks (ConcurrentHashMap<String, ReentrantMutex>) 保证同一实体同一时刻仅一个同步任务执行，后续请求排队或合并
- **优先级**: P0
- **依赖**: T3-4
- **验收标准**: 同一实体并发同步请求仅执行一个，其他排队等待

### T3-7 实现 SyncManager 冲突解决集成
- [ ] 在 SyncManager 中集成 ConflictResolver，实现 `resolveConflict()` 方法
- **描述**: 同步触发时通过版本向量检测冲突，冲突时调用 ConflictResolver 解决，解决后更新同步状态
- **优先级**: P1
- **依赖**: T3-4, T6-1（ConflictResolver）
- **验收标准**: 冲突检测和解决流程正确

### T3-8 实现 SyncManager 熔断恢复
- [ ] 在 SyncManager 中实现 `recoverCircuitBreaker()` 方法
- **描述**: 调用 CircuitBreakerManager.recover() 恢复熔断实体，更新同步状态，发布 SyncCircuitBreakerRecovered 事件
- **优先级**: P0
- **依赖**: T3-4, T2-9
- **验收标准**: 手动恢复熔断实体后，该实体可正常触发同步

---

## Phase 4: AOP拦截与循环防护

> **目标**: 实现 AOP 切面拦截业务实体 DAO 操作，实现循环同步防护  
> **依赖**: Phase 3  
> **预估耗时**: 2 天

### T4-1 实现 SyncInterceptor（AOP同步拦截器）
- [ ] 创建 `src/app/services/sync/interceptor/SyncInterceptor.cj`，实现 AOP 切面
- **描述**: 使用 `@AspectRoute` 注解定义切点规则（包路径包含 `magic.app.dao.uctoo.*`，排除 `magic.app.dao.sync.*`，方法名 `insert*|update*|delete*`），实现 `after()` 通知，包含 SyncContext 标记检查、实体类型白名单检查、异步触发文件同步，参照 design.md 1.3.7
- **优先级**: P0
- **依赖**: T2-2（SyncContext）, T3-4（SyncManager）
- **验收标准**: 业务实体 DAO 操作触发文件同步，同步系统自身 DAO 不触发，携带同步源标记的操作跳过拦截

### T4-2 实现实体类型白名单与包路径排除规则
- [ ] 在 SyncInterceptor 中实现实体类型白名单和包路径排除规则
- **描述**: 白名单 `HashSet(["agent", "agent_skill", "skill"])`，从 DAO 类名提取实体类型（如 AgentDAO → agent），非白名单实体跳过拦截
- **优先级**: P0
- **依赖**: T4-1
- **验收标准**: 仅拦截白名单内的实体类型，非白名单实体操作不触发同步

### T4-3 实现循环同步防护集成
- [ ] 在 SyncInterceptor 中集成 CircuitBreakerManager 循环同步检测
- **描述**: AOP 触发同步前检查 CircuitBreakerManager.isCircuitBroken()，熔断实体跳过自动同步仅记录变更，同步触发后调用 recordTrigger()
- **优先级**: P0
- **依赖**: T4-1, T2-9
- **验收标准**: 熔断实体不触发自动同步，非熔断实体正常触发，循环检测计数正确

### T4-4 注册AOP切面到AspectRegistry
- [ ] 在应用启动流程中注册 SyncInterceptor 到 AspectRegistry
- **描述**: 调用 `AspectRegistry.register(SyncInterceptor())`，确保切面在编译期通过 `@Pointcut` 宏织入
- **优先级**: P0
- **依赖**: T4-1
- **验收标准**: 应用启动后 AOP 切面生效，业务 DAO 操作被正确拦截

---

## Phase 5: 数据映射与处理器

> **目标**: 实现文件格式与实体对象的双向转换，实现各实体类型的同步处理器  
> **依赖**: Phase 3  
> **预估耗时**: 3 天

### T5-1 实现 DataMapper 核心框架
- [ ] 创建 `src/app/services/sync/mapper/DataMapper.cj`，实现数据映射器核心框架
- **描述**: 实现 Markdown Frontmatter 提取/构建、JSON 解析/序列化、YAML 解析/序列化基础方法，参照 design.md 1.3.18
- **优先级**: P1
- **依赖**: T2-1
- **验收标准**: Frontmatter 提取和构建正确，JSON/YAML 解析序列化正确

### T5-2 实现 DataMapper Agent 解析/序列化
- [ ] 在 DataMapper 中实现 Agent Markdown 文件的解析与序列化
- **描述**: 实现 `parseAgent(content, mappingVersion): AgentPO` 和 `serializeAgent(agent, targetVersion): String`，支持向前兼容（旧格式解析）和向后兼容（降级输出），参照 design.md 1.3.18
- **优先级**: P1
- **依赖**: T5-1
- **验收标准**: Agent Markdown 正确解析为 AgentPO，AgentPO 正确序列化为 Markdown，向前/向后兼容正确

### T5-3 实现 DataMapper Skill 解析/序列化
- [ ] 在 DataMapper 中实现 Skill Markdown/JSON 文件的解析与序列化
- **描述**: 实现 `parseSkill(content, mappingVersion): SkillPO` 和 `serializeSkill(skill, targetVersion): String`
- **优先级**: P1
- **依赖**: T5-1
- **验收标准**: Skill 文件正确解析和序列化

### T5-4 实现 AgentSyncHandler
- [ ] 创建 `src/app/services/sync/handler/AgentSyncHandler.cj`，实现 Agent 实体同步处理器
- **描述**: 实现 SyncHandler 接口，entityType="agent"，basePath=Config.syncAgentBasePath，fileExtension=".md"，dependencies=[]，实现 syncFromFileSystem/syncToFileSystem/detectChanges 等方法，参照 design.md 1.3.3
- **优先级**: P1
- **依赖**: T3-1, T5-2, T2-3
- **验收标准**: Agent 文件→数据库同步正确，数据库→文件同步正确，变更检测正确

### T5-5 实现 SkillSyncHandler
- [ ] 创建 `src/app/services/sync/handler/SkillSyncHandler.cj`，实现 Skill 实体同步处理器
- **描述**: 实现 SyncHandler 接口，entityType="skill"，dependencies=[]，复用 DataMapper 的 Skill 解析/序列化
- **优先级**: P1
- **依赖**: T3-1, T5-3, T2-3
- **验收标准**: Skill 文件→数据库同步正确，数据库→文件同步正确

### T5-6 实现 DefaultSyncHandler
- [ ] 创建 `src/app/services/sync/handler/DefaultSyncHandler.cj`，实现默认同步处理器（兜底）
- **描述**: 对未注册专用处理器的实体类型提供默认同步行为，使用 JSON 格式序列化
- **优先级**: P2
- **依赖**: T3-1
- **验收标准**: 未注册实体类型可使用默认处理器同步

---

## Phase 6: 冲突解决机制

> **目标**: 实现基于版本向量的冲突检测与三路合并解决  
> **依赖**: Phase 2, Phase 3  
> **预估耗时**: 2 天

### T6-1 实现 ConflictResolver（冲突解决器）
- [ ] 创建 `src/app/services/sync/resolver/ConflictResolver.cj`，实现冲突检测与解决
- **描述**: 实现 `detectByVersionVector()`/`resolve()`/`listConflicts()`/`getConflictDetail()` 方法，支持 ThreeWayMerge/SourcePriority/TimestampPriority/ManualResolve 四种策略，参照 design.md 1.3.11
- **优先级**: P1
- **依赖**: T2-4（VersionVector）, T2-12（SyncConflictDAO）
- **验收标准**: 版本向量冲突检测正确，四种策略解决逻辑正确

### T6-2 实现 ThreeWayMerge（三路合并）
- [ ] 创建 `src/app/services/sync/resolver/ThreeWayMerge.cj`，实现三路合并算法
- **描述**: 实现 `merge(base, ours, theirs): MergeResult` 和 `findBaseVersion()` 方法，无重叠修改时自动合并，重叠修改时标记需人工解决，参照 design.md 1.3.10
- **优先级**: P2
- **依赖**: T2-4
- **验收标准**: 无冲突字段自动合并，冲突字段标记需人工解决，公共祖先查找正确

### T6-3 实现冲突降级策略
- [ ] 在 ConflictResolver 中实现冲突自动降级策略
- **描述**: 版本向量丢失时降级为时间戳优先，公共祖先不可用时降级为源优先，策略配置错误时使用默认策略
- **优先级**: P1
- **依赖**: T6-1
- **验收标准**: 降级策略正确执行，降级时记录告警日志

### T6-4 实现冲突超时告警
- [ ] 实现冲突超过 24 小时未解决时触发告警
- **描述**: 定时扫描 sync_conflict 表中 conflict_status='detected' 或 'pending' 且 detected_at 超过 24 小时的记录，发布告警事件
- **优先级**: P2
- **依赖**: T6-1
- **验收标准**: 超时冲突正确触发告警

---

## Phase 7: 限流背压与队列

> **目标**: 实现限流、背压、优先级调度的完整集成  
> **依赖**: Phase 2, Phase 3  
> **预估耗时**: 1.5 天

### T7-1 集成 RateLimiter 到 SyncManager
- [ ] 在 SyncManager.triggerSync() 中集成限流检查
- **描述**: 触发同步前调用 `rateLimiter.tryAcquire()` 和 `rateLimiter.tryAcquire(entityType)`，限流拒绝时记录 Metrics 并按背压策略处理
- **优先级**: P1
- **依赖**: T3-4, T2-7
- **验收标准**: 超出 QPS 上限的同步请求被限流，限流拒绝数 Metrics 正确

### T7-2 集成 PrioritySyncQueue 到 SyncManager
- [ ] 在 SyncManager 中集成优先级同步队列
- **描述**: triggerSync() 入队按优先级，后台消费线程从队列 dequeue 执行，队列超过高水位时按背压策略处理
- **优先级**: P1
- **依赖**: T3-4, T2-8
- **验收标准**: 高优先级任务优先执行，背压策略正确触发

### T7-3 实现背压策略处理
- [ ] 实现三种背压策略：降级（仅记录变更）、延迟（等待水位下降）、拒绝（返回错误）
- **描述**: 根据配置 `SYNC_BACKPRESSURE_STRATEGY` 选择策略，降级时记录 SyncLog，延迟时等待队列水位下降，拒绝时返回 BackpressureResult.Rejected
- **优先级**: P1
- **依赖**: T7-2
- **验收标准**: 三种背压策略正确执行

### T7-4 集成 DebounceWindow 到 ChangeDetector
- [ ] 在 ChangeDetector 中集成防抖窗口
- **描述**: 文件变更事件先通过 DebounceWindow.collect() 收集，窗口到期后 flush() 批量提交同步
- **优先级**: P1
- **依赖**: T3-3, T2-6
- **验收标准**: 防抖窗口内同一实体多次变更合并为一次同步

---

## Phase 8: 服务层与接入层

> **目标**: 实现同步业务服务、控制器和路由，提供完整 API  
> **依赖**: Phase 3, Phase 4  
> **预估耗时**: 2 天

### T8-1 实现 SyncService（同步编排服务）
- [ ] 创建 `src/app/services/uctoo/SyncService.cj`，实现同步编排服务
- **描述**: 封装 SyncManager 的业务调用，提供 `triggerSync()`/`syncAll()`/`getStatusSummary()`/`getEntityStatus()`/`listEntities()`/`cancelTask()`/`resolveConflict()` 等方法，处理权限检查和参数校验
- **优先级**: P0
- **依赖**: T3-4
- **验收标准**: 服务方法正确调用 SyncManager，权限检查和参数校验正确

### T8-2 实现 SyncStatusService（同步状态服务）
- [ ] 创建 `src/app/services/uctoo/SyncStatusService.cj`，实现同步状态管理服务
- **描述**: 封装 SyncStatusManager 的业务调用，提供状态查询、状态更新、概览统计等方法
- **优先级**: P0
- **依赖**: T3-2
- **验收标准**: 状态查询和更新正确

### T8-3 实现 SyncLogService（同步日志服务）
- [ ] 创建 `src/app/services/uctoo/SyncLogService.cj`，实现同步日志管理服务
- **描述**: 封装 SyncLogDAO 和 AsyncLogWriter，提供日志查询、日志清理等方法
- **优先级**: P0
- **依赖**: T2-11, T2-12
- **验收标准**: 日志查询分页正确，日志清理正确

### T8-4 实现 SyncController（同步控制器）
- [ ] 创建 `src/app/controllers/uctoo/sync/SyncController.cj`，实现同步 API 控制器
- **描述**: 实现 getStatus/listEntities/listEntitiesByType/getEntityStatus/syncEntity/cancelTask/syncBatch/syncAll/listConflicts/getConflictDetail/resolveConflict/listLogs/cleanLogs/healthCheck 方法，遵循 UCTOO V4 Controller 规范，参照 design.md 2.2 接口清单
- **优先级**: P0
- **依赖**: T8-1, T8-2, T8-3
- **验收标准**: 所有 API 端点实现，请求解析和响应格式正确

### T8-5 实现 SyncRoute（同步路由）
- [ ] 创建 `src/app/routes/uctoo/sync/SyncRoute.cj`，实现同步路由注册
- **描述**: 注册 14 个 API 端点，路由前缀 `/api/v1/uctoo/sync/`，参照 design.md 3.3 路由注册
- **优先级**: P0
- **依赖**: T8-4
- **验收标准**: 所有路由正确注册，API 可访问

### T8-6 在AutoRouteConfig中注册SyncRoute
- [ ] 在 `AutoRouteConfig.initRegistry()` 中添加 Sync 模块路由注册
- **描述**: 添加 RouteEntry("sync", "/api/v1/uctoo/sync", 220, true, registerFunc)，参照 design.md 3.3
- **优先级**: P0
- **依赖**: T8-5
- **验收标准**: 应用启动后同步 API 可访问

---

## Phase 9: 可观测性与事件

> **目标**: 实现 Metrics 采集、领域事件发布、健康检查端点  
> **依赖**: Phase 3  
> **预估耗时**: 1.5 天

### T9-1 实现 SyncMetrics（同步度量采集器）
- [ ] 创建 `src/app/services/sync/metrics/SyncMetrics.cj`，实现 Metrics 采集
- **描述**: 实现 recordSuccess/recordFailure/recordConflict/recordRateLimitRejected/recordCircuitBreaker 方法，提供 successRate/conflictRate/latencyP50/P95/P99/queueDepth 属性，实现 snapshot() 导出快照，参照 design.md 1.3.15
- **优先级**: P2
- **依赖**: T2-1
- **验收标准**: Metrics 指标采集正确，延迟分布统计正确

### T9-2 实现 SyncEventPublisher（同步事件发布器）
- [ ] 创建 `src/app/services/sync/event/SyncEventPublisher.cj`，实现领域事件发布
- **描述**: 实现 publishSyncCompleted/publishSyncFailed/publishConflictDetected/publishConflictResolved/publishCircuitBreakerTriggered/publishCircuitBreakerRecovered/publishBackpressureTriggered/publishTaskCancelled 方法，事件发布失败不影响同步操作，参照 design.md 1.3.16
- **优先级**: P2
- **依赖**: T2-1
- **验收标准**: 8 种领域事件正确发布，事件发布失败不影响主流程

### T9-3 实现健康检查端点
- [ ] 在 SyncController 中实现 `/api/v1/uctoo/sync/health` 健康检查端点
- **描述**: 返回同步系统运行状态（normal/degraded/circuit_breaker）、队列深度、最近1分钟失败数、熔断实体数、最后成功同步时间
- **优先级**: P2
- **依赖**: T9-1, T3-2
- **验收标准**: 健康检查返回信息正确

### T9-4 集成Metrics到SyncManager
- [ ] 在 SyncManager 的同步流程中集成 Metrics 采集
- **描述**: 同步成功/失败/冲突/限流拒绝/熔断时调用对应 Metrics 记录方法，同步开始/结束时记录延迟
- **优先级**: P2
- **依赖**: T3-4, T9-1
- **验收标准**: 同步操作自动采集 Metrics

---

## Phase 10: 应用集成与配置

> **目标**: 将同步系统集成到应用启动流程，添加配置项和权限  
> **依赖**: Phase 4, Phase 5, Phase 8  
> **预估耗时**: 1.5 天

### T10-1 添加同步配置项到.env和Config
- [ ] 在 `.env.example` 和 `src/config/config.cj` 中添加同步系统配置项
- **描述**: 添加 SYNC_ENABLED、SYNC_DEFAULT_DIRECTION、SYNC_SCAN_INTERVAL、SYNC_DETECT_STRATEGY、SYNC_DEBOUNCE_MS、SYNC_MAX_QPS、SYNC_RATE_LIMIT_ALGORITHM、SYNC_QUEUE_CAPACITY、SYNC_QUEUE_HIGH_WATERMARK、SYNC_BACKPRESSURE_STRATEGY、SYNC_MAX_RETRIES、SYNC_RETRY_STRATEGY、SYNC_CONFLICT_STRATEGY、SYNC_SOURCE_PRIORITY、SYNC_CIRCULAR_WINDOW_SECONDS、SYNC_CIRCULAR_THRESHOLD、SYNC_CIRCUIT_BREAKER_DURATION、SYNC_STARTUP_TIMEOUT、SYNC_AGENT_BASE_PATH、SYNC_SKILL_BASE_PATH、SYNC_THREAD_POOL_SIZE、SYNC_LOG_RETENTION_DAYS、SYNC_TRACING_SAMPLE_RATE、SYNC_MAPPING_MODE 等配置项，参照 design.md 3.2
- **优先级**: P0
- **依赖**: 无
- **验收标准**: 配置项可读取，默认值与设计一致

### T10-2 集成同步系统到Application启动流程
- [ ] 在 `src/app/main.cj` 的 Application 类中集成同步系统初始化
- **描述**: 在 setupRoutes() 之后添加 SyncManager.initialize()、注册处理器（AgentSyncHandler/SkillSyncHandler）、注册AOP切面、创建ChangeDetector、启动文件监听和定时扫描、异步执行初始化全量同步，在 stop() 中添加优雅关闭，参照 design.md 3.1
- **优先级**: P0
- **依赖**: T3-4, T4-4, T5-4, T5-5, T3-3
- **验收标准**: 应用启动后同步系统初始化成功，全量同步异步执行不阻塞启动，关闭时优雅等待

### T10-3 添加同步权限节点
- [ ] 在权限系统中添加 sync:read 和 sync:write 权限节点
- **描述**: 在 PermissionConstants 或权限初始化脚本中添加同步系统权限节点
- **优先级**: P0
- **依赖**: 无
- **验收标准**: sync:read 和 sync:write 权限可分配和校验

### T10-4 添加cjpm.toml依赖声明
- [ ] 在 `cjpm.toml` 中添加 f_aspect、f_filesystem、f_json、f_yaml、f_crypto 依赖
- **描述**: 参照 design.md 5.1 依赖声明
- **优先级**: P0
- **依赖**: 无
- **验收标准**: 依赖声明正确，编译通过

### T10-5 实现同步功能开关
- [ ] 实现同步功能可配置开关（SYNC_ENABLED）
- **描述**: 开关关闭时系统行为与无同步模块完全一致，Application.init() 中根据 SYNC_ENABLED 决定是否初始化同步系统
- **优先级**: P0
- **依赖**: T10-2
- **验收标准**: SYNC_ENABLED=false 时不触发任何同步操作，系统行为正常

---

## Phase 11: 测试与验证

> **目标**: 编写单元测试、集成测试，验证功能正确性和性能指标  
> **依赖**: Phase 10  
> **预估耗时**: 3 天

### T11-1 基础设施层单元测试
- [ ] 编写基础设施层组件的单元测试
- **描述**: 测试 ContentHasher（SHA-256计算）、VersionVector（冲突检测、基线更新）、DebounceWindow（防抖合并）、RateLimiter（限流）、PrioritySyncQueue（优先级调度、背压）、CircuitBreakerManager（熔断触发/恢复）、RetryManager（指数退避重试）、SyncContext（ThreadLocal标记、循环检测）
- **优先级**: P0
- **验收标准**: 所有测试用例通过

### T11-2 核心引擎层单元测试
- [ ] 编写核心引擎层组件的单元测试
- **描述**: 测试 SyncManager（处理器注册、触发同步、拓扑排序、幂等性去重、并发互斥）、ChangeDetector（三种检测策略）、SyncStatusManager（状态更新、概览统计）、DataMapper（文件解析/序列化、版本兼容）
- **优先级**: P0
- **验收标准**: 所有测试用例通过

### T11-3 AOP拦截与循环防护集成测试
- [ ] 编写 AOP 拦截和循环同步防护的集成测试
- **描述**: 测试业务实体 DAO 操作触发文件同步、同步系统自身 DAO 不触发、SyncContext 标记跳过拦截、熔断机制（10秒内3次双向同步触发熔断）、熔断恢复
- **优先级**: P0
- **验收标准**: 循环同步防护正确，AOP 拦截范围限定正确

### T11-4 双向同步与冲突解决集成测试
- [ ] 编写双向同步和冲突解决的集成测试
- **描述**: 测试文件→数据库同步（创建/修改/删除）、数据库→文件同步、冲突检测（版本向量）、冲突解决（三路合并/源优先/手动）、幂等性（重复提交去重）、启动全量同步
- **优先级**: P0
- **验收标准**: 双向同步正确，冲突检测和解决正确，幂等性保证

### T11-5 API端点与权限集成测试
- [ ] 编写同步 API 端点和权限的集成测试
- **描述**: 测试所有 14 个 API 端点的请求/响应格式、分页参数、过滤参数、权限校验（sync:read/sync:write）、未授权返回 401
- **优先级**: P0
- **验收标准**: API 端点功能正确，权限校验正确

### T11-6 性能测试与验收
- [ ] 编写性能测试，验证性能指标
- **描述**: 测试单条实体同步耗时 ≤ 100ms (P99)、批量同步 100 条 ≤ 5s (P99)、批量同步 1000 条 ≤ 30s (P99)、同步不阻塞主线程、数据最终一致性延迟 ≤ 10s (P99)
- **优先级**: P0
- **验收标准**: 所有性能指标达标

---

## 任务依赖关系图

```
Phase 0 ─────────────────────────────────────────────────────────────┐
  T0-1 → T0-2 → T0-3 → T0-4                                        │
                                                                      │
Phase 1 ─────────────────────────────────────────────────────────────┤
  T1-1 → T1-2 → T1-3 → T1-4                                        │
  (依赖 Phase 0)                                                     │
                                                                      │
Phase 2 ─────────────────────────────────────────────────────────────┤
  T2-1 → T2-2, T2-3, T2-4, T2-6, T2-7, T2-8, T2-9, T2-10          │
  T2-5 (依赖 T2-1, T3-1)                                            │
  T2-11 (依赖 T1-3)                                                  │
  T2-12 (依赖 T1-2, T1-3)                                           │
  (依赖 Phase 1)                                                     │
                                                                      │
Phase 3 ─────────────────────────────────────────────────────────────┤
  T3-1 (依赖 T2-1)                                                   │
  T3-2 (依赖 T2-12)                                                  │
  T3-3 (依赖 T2-3, T2-6, T2-12)                                     │
  T3-4 (依赖 T2-1, T2-2, T2-5, T2-8, T2-9, T2-10, T3-2)           │
  T3-5, T3-6 (依赖 T3-4)                                            │
  T3-7 (依赖 T3-4, T6-1)                                            │
  T3-8 (依赖 T3-4, T2-9)                                            │
  (依赖 Phase 2)                                                     │
                                                                      │
Phase 4 ─────────────────────────────────────────────────────────────┤
  T4-1 (依赖 T2-2, T3-4)                                            │
  T4-2, T4-3 (依赖 T4-1)                                            │
  T4-4 (依赖 T4-1)                                                   │
  (依赖 Phase 3)                                                     │
                                                                      │
Phase 5 ─────────────────────────────────────────────────────────────┤
  T5-1 → T5-2, T5-3                                                  │
  T5-4 (依赖 T3-1, T5-2, T2-3)                                      │
  T5-5 (依赖 T3-1, T5-3, T2-3)                                      │
  T5-6 (依赖 T3-1)                                                   │
  (依赖 Phase 3)                                                     │
                                                                      │
Phase 6 ─────────────────────────────────────────────────────────────┤
  T6-1 (依赖 T2-4, T2-12)                                            │
  T6-2 (依赖 T2-4)                                                   │
  T6-3, T6-4 (依赖 T6-1)                                            │
  (依赖 Phase 2, Phase 3)                                            │
                                                                      │
Phase 7 ─────────────────────────────────────────────────────────────┤
  T7-1 (依赖 T3-4, T2-7)                                            │
  T7-2 (依赖 T3-4, T2-8)                                            │
  T7-3 (依赖 T7-2)                                                   │
  T7-4 (依赖 T3-3, T2-6)                                            │
  (依赖 Phase 2, Phase 3)                                            │
                                                                      │
Phase 8 ─────────────────────────────────────────────────────────────┤
  T8-1 (依赖 T3-4)                                                   │
  T8-2 (依赖 T3-2)                                                   │
  T8-3 (依赖 T2-11, T2-12)                                          │
  T8-4 (依赖 T8-1, T8-2, T8-3)                                      │
  T8-5 (依赖 T8-4)                                                   │
  T8-6 (依赖 T8-5)                                                   │
  (依赖 Phase 3, Phase 4)                                            │
                                                                      │
Phase 9 ─────────────────────────────────────────────────────────────┤
  T9-1, T9-2 (依赖 T2-1)                                            │
  T9-3 (依赖 T9-1, T3-2)                                            │
  T9-4 (依赖 T3-4, T9-1)                                            │
  (依赖 Phase 3)                                                     │
                                                                      │
Phase 10 ────────────────────────────────────────────────────────────┤
  T10-1, T10-3, T10-4 (无依赖)                                      │
  T10-2 (依赖 T3-4, T4-4, T5-4, T5-5, T3-3)                       │
  T10-5 (依赖 T10-2)                                                │
  (依赖 Phase 4, Phase 5, Phase 8)                                   │
                                                                      │
Phase 11 ────────────────────────────────────────────────────────────┘
  T11-1 ~ T11-6 (依赖 Phase 10)
```

### 关键路径（最长依赖链）

```
T0-1 → T1-1 → T1-2 → T2-12 → T3-2 → T3-4 → T4-1 → T4-4 → T10-2 → T10-5 → T11-3
```

**关键路径任务数**: 11  
**关键路径预估耗时**: 约 8-10 个工作日

---

## 验收标准总览

| 验收类别 | 关键标准 | 对应Phase |
|----------|----------|-----------|
| **双向同步** | 文件→数据库、数据库→文件同步正确 | Phase 5, 11 |
| **循环同步防护** | SyncContext标记跳过拦截，熔断机制正确 | Phase 4, 11 |
| **AOP拦截范围限定** | 仅拦截业务实体DAO，排除同步系统DAO | Phase 4, 11 |
| **幂等性** | 同一taskId重复提交返回相同结果 | Phase 3, 11 |
| **变更检测** | hash/timestamp/hybrid三种策略正确 | Phase 3, 11 |
| **冲突解决** | 版本向量检测、三路合并正确 | Phase 6, 11 |
| **限流背压** | QPS限流、背压策略正确 | Phase 7, 11 |
| **API完整性** | 14个API端点功能正确、权限校验正确 | Phase 8, 11 |
| **性能** | 单条≤100ms、100条≤5s、1000条≤30s | Phase 11 |
| **可观测性** | Metrics采集、事件发布、健康检查正确 | Phase 9 |

---

**文档维护者**: UCToo Team  
**最后更新**: 2026-06-02