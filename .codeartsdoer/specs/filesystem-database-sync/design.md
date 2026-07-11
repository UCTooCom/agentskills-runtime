# 文件系统与数据库双向同步系统设计文档

## 文档信息
- **项目名称**: agentskills-runtime 文件系统与数据库同步系统
- **版本**: 2.0.0
- **创建日期**: 2026-06-02
- **最后更新**: 2026-06-02
- **作者**: spec-design-agent
- **状态**: 待实现
- **关联需求**: spec.md v2.0.0
- **目录规范**: 工程级目录 `.codeartsdoer/specs/filesystem-database-sync/design.md`

---

# **1. 实现模型**

## **1.1 上下文视图**

### 系统上下文图

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                        文件系统与数据库双向同步系统 v2.0                           │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐  │
│  │                      同步管理器 (SyncManager)                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────────┐ │  │
│  │  │ 变更检测器   │  │ AOP拦截器    │  │   冲突解决器                      │ │  │
│  │  │ChangeDetector│  │SyncInterceptor│ │ ConflictResolver                  │ │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────────────────┘ │  │
│  │         │                 │                      │                         │  │
│  │  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────────▼───────────────────────┐ │  │
│  │  │ 数据映射器   │  │ 同步处理器   │  │   同步状态管理器                  │ │  │
│  │  │ DataMapper   │  │ SyncHandler  │  │   SyncStatusManager              │ │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────────────────────────────────┘ │  │
│  │         │                 │                                              │  │
│  │  ┌──────▼─────────────────▼──────────────────────────────────────────────┐ │  │
│  │  │                    同步引擎基础设施层                                  │ │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐ │ │  │
│  │  │  │SyncContext│ │RateLimiter│ │SyncMetrics│ │EventPub  │ │ContentHash│ │ │  │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └───────────┘ │ │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐               │ │  │
│  │  │  │VersionVec│ │DebounceWin│ │CircuitBrkr│ │PriorityQ │               │ │  │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘               │ │  │
│  │  └─────────────────────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────────────────────────┘  │
│            │                 │                                                      │
│            ▼                 ▼                                                      │
│  ┌────────────────┐  ┌────────────────────────┐                                    │
│  │   文件系统     │  │         数据库          │                                    │
│  │  (Markdown/    │  │   (PostgreSQL/ORM)     │                                    │
│  │   JSON/YAML)   │  │                        │                                    │
│  └────────────────┘  └────────────────────────┘                                    │
│                                                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                         监控系统 (可观测性)                                │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────────────┐  │   │
│  │  │ Metrics  │  │ Tracing  │  │ HealthChk│  │ AlertRules              │  │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────────────────┘  │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### 核心参与者

| 参与者 | 角色 | 交互方式 |
|--------|------|----------|
| **同步管理器** | 核心协调器，管理同步任务、拓扑排序、幂等性、并发互斥、限流背压 | 内部 API 调用 |
| **变更检测器** | 检测文件系统变更，支持 content-hash/timestamp/hybrid 三种策略 | 文件系统监听/定时扫描 |
| **AOP拦截器** | 拦截业务实体 DAO 操作，携带同步上下文检查，触发文件同步 | 切面织入 |
| **数据映射器** | 文件格式与实体对象的双向转换，维护映射版本兼容 | 解析/序列化 |
| **冲突解决器** | 基于版本向量检测冲突，支持三路合并与多种解决策略 | 策略选择 |
| **同步处理器** | 执行具体的同步逻辑，声明实体依赖关系 | 实体类型注册 |
| **同步上下文** | ThreadLocal 同步上下文，携带同步源标记、触发链路、任务ID | 线程本地变量 |
| **限流器** | 令牌桶/滑动窗口限流，控制同步 QPS | 令牌分配 |
| **同步度量** | 采集同步 Metrics（成功率、延迟、冲突率、队列深度） | 指标采集 |
| **事件发布器** | 发布同步领域事件到内部事件总线 | 事件发布 |
| **文件系统** | 存储 Agent/Skill 定义文件 | 文件读写 |
| **数据库** | 存储结构化元数据 | ORM 操作 |

## **1.2 服务/组件总体架构**

### 架构分层图

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     接入层 (Entry Layer)                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │ SyncController   │  │ SyncLogController│ │   SyncCLI        │       │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘     │
├───────────┼──────────────────────┼──────────────────────┼──────────────┤
│           │        服务层 (Service Layer)               │               │
│  ┌────────┴─────────┐  ┌────────┴─────────┐  ┌────────┴─────────┐    │
│  │   SyncService    │  │ SyncStatusService│  │ SyncLogService   │    │
│  │  (同步编排)      │  │  (状态管理)      │  │  (日志管理)      │    │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘    │
├───────────┼──────────────────────┼──────────────────────┼──────────────┤
│           │        同步引擎层 (Sync Engine)              │               │
│  ┌────────┴────────────────────────────────────────────┴─────────┐     │
│  │                    SyncManager (核心协调器)                     │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐    │     │
│  │  │Detector  │  │Interceptor│ │Resolver  │  │Mapper     │    │     │
│  │  └──────────┘  └──────────┘  └──────────┘  └───────────┘    │     │
│  └────────────────────────┬──────────────────────────────────────┘     │
├───────────────────────────┼────────────────────────────────────────────┤
│       处理器层 (Handler Layer)                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │
│  │AgentSyncHandler│ │SkillSyncHandler││DefaultHandler│                │
│  └──────────────┘  └──────────────┘  └──────────────┘                │
├────────────────────────────────────────────────────────────────────────┤
│       数据层 (Data Access Layer)                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │
│  │SyncStatusDAO │  │ SyncLogDAO   │  │SyncTaskDAO   │                │
│  └──────────────┘  └──────────────┘  └──────────────┘                │
│  ┌──────────────┐  ┌──────────────────────────────────────┐          │
│  │SyncConflictDAO│  │ EntityDAO (业务实体, 复用现有)       │          │
│  └──────────────┘  └──────────────────────────────────────┘          │
├────────────────────────────────────────────────────────────────────────┤
│       基础设施层 (Infrastructure)                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │  f_orm   │  │LogUtils  │  │ AspectLib│  │ FileSystemUtils     │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────────┘  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │ContentHash│ │VersionVec│  │DebounceWin│ │ EventBus            │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### 数据流图

```
文件系统→数据库同步流:
  文件变更事件 ──> DebounceWindow.collect() ──> ChangeDetector.detect(strategy)
                                                          │
                                                          ├──> ContentHasher.computeSHA256()
                                                          │        │
                                                          │        └──> 比对 sync_status.content_hash
                                                          │
                                                          ├──> [变更确认] ──> SyncContext.enter()
                                                          │                        │
                                                          │                        ├──> SyncManager.triggerSync()
                                                          │                        │        │
                                                          │                        │        ├──> RateLimiter.acquire()
                                                          │                        │        ├──> CircuitBreaker.check()
                                                          │                        │        ├──> DataMapper.parseFile()
                                                          │                        │        │        │
                                                          │                        │        │        └──> EntityDAO.upsert() [携带SyncContext]
                                                          │                        │        │
                                                          │                        │        └──> SyncStatusManager.updateStatus()
                                                          │                        │
                                                          │                        └──> SyncContext.exit()
                                                          │
                                                          └──> [未变更] ──> 跳过

数据库→文件系统同步流:
  数据库操作 ──> SyncInterceptor.after()
                      │
                      ├──> SyncContext.isPresent()? ──[是]──> 跳过(防循环)
                      │
                      └──> [否] ──> 实体类型白名单检查
                                        │
                                        ├──> SyncContext.enter()
                                        │        │
                                        │        ├──> SyncManager.triggerSync()
                                        │        │        │
                                        │        │        ├──> EntityDAO.select()
                                        │        │        │        │
                                        │        │        │        └──> DataMapper.serializeToFile()
                                        │        │        │
                                        │        │        └──> SyncStatusManager.updateStatus()
                                        │        │
                                        │        └──> SyncContext.exit()

冲突检测与解决流:
  同步触发 ──> ConflictResolver.detectByVersionVector() ──> [冲突?]
                                                    │
                                                    ├─ 是 ──> ThreeWayMerge.merge(base, ours, theirs)
                                                    │            │
                                                    │            ├─ 自动合并成功 ──> 写入合并结果
                                                    │            └─ 重叠修改 ──> 标记待人工解决
                                                    │
                                                    └─ 否 ──> 继续同步
```

### 应用启动流程

```
Application.init()
    │
    ├── ORM.initialize()                    (现有)
    ├── setupMiddlewares()                  (现有)
    ├── setupRoutes()                       (现有)
    │       └── AutoRouteRegistry.registerAllRoutes()
    │               └── SyncRoute.register()         (新增)
    │
    └── [新增] SyncManager.initialize()
            │
            ├── 加载同步配置（开关、限流阈值、防抖窗口等）
            ├── 初始化同步基础设施
            │       ├── SyncContext (ThreadLocal)
            │       ├── RateLimiter (令牌桶/滑动窗口)
            │       ├── SyncMetrics (Metrics采集器)
            │       ├── SyncEventPublisher (事件发布器)
            │       └── CircuitBreakerManager (熔断管理器)
            ├── 加载同步状态表（恢复未完成任务）
            ├── 注册实体同步处理器
            │       └── AgentSyncHandler, AgentSkillSyncHandler, SkillSyncHandler, DefaultSyncHandler
            ├── 注册AOP切面拦截器（实体类型白名单 + 包路径排除规则）
            │       └── AspectRegistry.register(SyncInterceptor())
            ├── 启动文件变更监听
            │       └── ChangeDetector.startListening() + DebounceWindow
            └── [异步] 执行初始化全量同步（不阻塞启动）
                    └── async { syncAll(None) } with timeout=60s
```

## **1.3 实现设计文档**

### 1.3.1 SyncManager（同步管理器）

**职责**: 核心同步控制器，协调所有同步操作，负责拓扑排序、幂等性保证、并发互斥、限流背压

**包路径**: `magic.app.services.sync`

```cangjie
package magic.app.services.sync

public class SyncManager {
    // 单例模式
    private static let instance_ = AtomicOptionReference<SyncManager>()
    
    // 注册的同步处理器
    private let handlers: ConcurrentHashMap<String, SyncHandler>
    
    // 同步状态服务
    private let statusService: SyncStatusService
    
    // 同步日志服务
    private let logService: SyncLogService
    
    // 数据映射器
    private let dataMapper: DataMapper
    
    // 冲突解决器
    private let conflictResolver: ConflictResolver
    
    // 优先级同步任务队列
    private let syncQueue: PrioritySyncQueue<SyncTask>
    
    // 限流器
    private let rateLimiter: RateLimiter
    
    // 熔断管理器
    private let circuitBreakerMgr: CircuitBreakerManager
    
    // 同步度量采集器
    private let metrics: SyncMetrics
    
    // 事件发布器
    private let eventPublisher: SyncEventPublisher
    
    // 实体并发互斥锁表
    private let entityLocks: ConcurrentHashMap<String, ReentrantMutex>
    
    // 同步任务去重表
    private let taskDedupMap: ConcurrentHashMap<String, SyncResult>
    
    // 实体依赖拓扑排序器
    private let topologySorter: TopologySorter
    
    // === 核心方法 ===
    
    /// 初始化同步管理器
    public static func initialize(): SyncManager
    
    /// 获取单例实例
    public static prop instance: Option<SyncManager>
    
    /// 注册同步处理器
    public func registerHandler(entityType: String, handler: SyncHandler): Unit
    
    /// 触发同步（异步，携带同步上下文）
    public func triggerSync(
        entityType: String,
        entityId: String,
        direction: SyncDirection,
        triggerSource: TriggerSource,
        priority: SyncPriority
    ): Future<SyncResult>
    
    /// 触发同步（同步，携带同步上下文）
    public func sync(
        entityType: String,
        entityId: String,
        direction: SyncDirection,
        triggerSource: TriggerSource
    ): SyncResult
    
    /// 批量同步所有实体（按拓扑排序执行）
    public func syncAll(entityType: String?): SyncBatchResult
    
    /// 获取同步状态概览
    public func getStatusSummary(): SyncStatusSummary
    
    /// 获取指定实体的同步状态
    public func getStatus(entityType: String, entityId: String): Option<SyncStatusPO>
    
    /// 解决冲突
    public func resolveConflict(
        entityType: String,
        entityId: String,
        strategy: ConflictStrategy
    ): SyncResult
    
    /// 取消同步任务
    public func cancelTask(taskId: String): CancelResult
    
    /// 恢复熔断实体
    public func recoverCircuitBreaker(entityType: String, entityId: String): Unit
    
    /// 停止同步管理器
    public func stop(): Unit
}
```

### 1.3.2 SyncHandler（同步处理器接口）

**职责**: 定义特定实体类型的同步契约，声明实体依赖关系

**包路径**: `magic.app.services.sync.handler`

```cangjie
package magic.app.services.sync.handler

public interface SyncHandler {
    /// 获取支持的实体类型
    prop entityType: String
    
    /// 获取实体基础路径
    prop basePath: String
    
    /// 文件扩展名（.md, .json, .yaml）
    prop fileExtension: String
    
    /// 实体依赖列表（拓扑排序依据）
    /// 例: agent_skill 的 dependencies = ["agent"]
    prop dependencies: Array<String>
    
    /// 从文件系统同步到数据库（upsert 语义）
    func syncFromFileSystem(entityId: String, context: SyncContext): SyncResult
    
    /// 从数据库同步到文件系统
    func syncToFileSystem(entityId: String, context: SyncContext): SyncResult
    
    /// 检测文件变更（支持 hash/timestamp/hybrid 策略）
    func detectChanges(strategy: DetectStrategy): Array<FileChange>
    
    /// 获取实体ID（从文件名提取）
    func extractEntityId(fileName: String): String
    
    /// 构建文件路径
    func buildFilePath(entityId: String): String
    
    /// 计算实体内容哈希（用于内容寻址变更检测）
    func computeContentHash(entityId: String): String
}
```

### 1.3.3 AgentSyncHandler（Agent同步处理器）

**职责**: 处理 Agent 实体的同步逻辑

**包路径**: `magic.app.services.sync.handler`

```cangjie
package magic.app.services.sync.handler

public class AgentSyncHandler : SyncHandler {
    prop entityType: String = "agent"
    prop basePath: String = Config.syncAgentBasePath
    prop fileExtension: String = ".md"
    prop dependencies: Array<String> = []  // agent 无前置依赖
    
    public func syncFromFileSystem(entityId: String, context: SyncContext): SyncResult {
        // 1. 读取文件内容
        let content = FileSystemUtils.readFile(buildFilePath(entityId))
        // 2. 计算内容哈希
        let contentHash = ContentHasher.computeSHA256(content)
        // 3. 解析为 AgentPO（向前兼容处理）
        let agent = DataMapper.parseAgent(content)
        // 4. 携带同步上下文执行 upsert（触发 SyncContext 标记）
        SyncContext.enter(context)
        try {
            AgentDAO.upsert(agent)  // upsert 语义：不存在则创建，存在则更新
        } finally {
            SyncContext.exit()
        }
        // 5. 更新版本向量与同步状态
        SyncStatusManager.updateAfterSync(entityType, entityId, contentHash, ...)
        // 6. 返回结果
        return SyncResult(success: true, ...)
    }
    
    public func syncToFileSystem(entityId: String, context: SyncContext): SyncResult {
        // 1. 从数据库读取 AgentPO
        let agent = AgentDAO.selectById(entityId)
        // 2. 序列化为 Markdown（向后兼容处理）
        let content = DataMapper.serializeAgent(agent)
        // 3. 携带同步上下文写入文件
        SyncContext.enter(context)
        try {
            FileSystemUtils.writeFile(buildFilePath(entityId), content)
        } finally {
            SyncContext.exit()
        }
        // 4. 计算内容哈希并更新同步状态
        let contentHash = ContentHasher.computeSHA256(content)
        SyncStatusManager.updateAfterSync(entityType, entityId, contentHash, ...)
        // 5. 返回结果
        return SyncResult(success: true, ...)
    }
    
    public func detectChanges(strategy: DetectStrategy): Array<FileChange> {
        // 按策略检测变更：hash/timestamp/hybrid
        ChangeDetector.detect(basePath, strategy)
    }
    
    public func extractEntityId(fileName: String): String {
        // 从文件名提取 ID（如 "agent-123.md" -> "agent-123"）
    }
    
    public func buildFilePath(entityId: String): String {
        return "\(basePath)/\(entityId)\(fileExtension)"
    }
    
    public func computeContentHash(entityId: String): String {
        let content = FileSystemUtils.readFile(buildFilePath(entityId))
        ContentHasher.computeSHA256(content)
    }
}
```

### 1.3.4 SyncContext（同步上下文）

**职责**: ThreadLocal 同步上下文，携带同步源标记、触发链路、任务ID、TraceID，用于循环同步防护和分布式追踪

**包路径**: `magic.app.services.sync.context`

```cangjie
package magic.app.services.sync.context

public class SyncContext {
    // ThreadLocal 存储
    private static let threadLocal: ThreadLocal<Option<SyncContext>>
    
    // 同步任务ID（幂等性去重键）
    public let taskId: String
    
    // 同步触发源
    public let triggerSource: TriggerSource
    
    // 同步触发链路（用于循环检测）
    public let triggerChain: ArrayList<TriggerStep>
    
    // 分布式追踪 TraceID
    public let traceId: String
    
    // 同步方向
    public let direction: SyncDirection
    
    // 实体类型
    public let entityType: String
    
    // 实体ID
    public let entityId: String
    
    // 进入同步上下文（设置 ThreadLocal 标记）
    public static func enter(context: SyncContext): Unit {
        threadLocal.set(Some(context))
    }
    
    // 退出同步上下文（清除 ThreadLocal 标记）
    public static func exit(): Unit {
        threadLocal.set(None<SyncContext>())
    }
    
    // 检查当前是否处于同步上下文中
    public static func isPresent(): Bool {
        match threadLocal.get() {
            case Some(_) => true
            case None => false
        }
    }
    
    // 获取当前同步上下文
    public static func current(): Option<SyncContext> {
        threadLocal.get()
    }
    
    // 检查触发链路中是否已包含指定实体（循环检测）
    public func hasCircularTrigger(entityType: String, entityId: String): Bool {
        triggerChain.any({ step =>
            step.entityType == entityType && step.entityId == entityId
        })
    }
}

/// 同步触发源
public enum TriggerSource {
    | Business        // 业务操作触发
    | SyncSystem      // 同步系统自身触发（携带此标记的变更不触发反向同步）
    | Manual          // 手动触发（API/CLI）
    | Startup         // 启动初始化触发
}

/// 触发步骤（链路追踪）
public class TriggerStep {
    public var entityType: String
    public var entityId: String
    public var direction: SyncDirection
    public var timestamp: DateTime
}
```

### 1.3.5 ChangeDetector（变更检测器）

**职责**: 检测文件系统变更，支持 content-hash/timestamp/hybrid 三种检测策略，集成防抖与节流机制

**包路径**: `magic.app.services.sync.detector`

```cangjie
package magic.app.services.sync.detector

public class ChangeDetector {
    // 监听的目录列表
    private let watchedPaths: ConcurrentHashMap<String, Watcher>
    
    // 扫描定时器
    private let scanTimer: Option<Timer>
    
    // 防抖窗口
    private let debounceWindow: DebounceWindow
    
    // 节流器
    private let throttler: Throttler
    
    // 变更回调
    private let onChange: (Array<FileChange>) -> Unit
    
    /// 构造函数
    public init(
        onChange: (Array<FileChange>) -> Unit,
        debounceMs: Int64 = 500,    // 防抖窗口，默认 500ms
        maxQps: Int32 = 100          // 最大 QPS，默认 100
    )
    
    /// 开始监听目录
    public func startListening(path: String): Unit
    
    /// 停止监听目录
    public func stopListening(path: String): Unit
    
    /// 停止所有监听
    public func stopAll(): Unit
    
    /// 手动扫描目录（按检测策略）
    public func scan(path: String, strategy: DetectStrategy): Array<FileChange>
    
    /// 启动定时扫描
    public func startPeriodicScan(intervalSeconds: Int32): Unit
    
    /// 停止定时扫描
    public func stopPeriodicScan(): Unit
    
    /// 检测变更（核心方法，支持三种策略）
    public func detect(path: String, strategy: DetectStrategy): Array<FileChange> {
        match strategy {
            case DetectStrategy.Hash =>
                detectByHash(path)       // 仅比对 content-hash
            case DetectStrategy.Timestamp =>
                detectByTimestamp(path)  // 仅比对时间戳
            case DetectStrategy.Hybrid =>
                detectByHybrid(path)     // 先时间戳快速筛选，再 hash 确认
        }
    }
    
    /// hash 策略：计算文件 SHA-256，与 sync_status.content_hash 比对
    private func detectByHash(path: String): Array<FileChange>
    
    /// timestamp 策略：比对文件修改时间与 sync_status.last_sync_at
    private func detectByTimestamp(path: String): Array<FileChange>
    
    /// hybrid 策略：先时间戳快速排除未变更，再 hash 确认内容是否真正变更
    private func detectByHybrid(path: String): Array<FileChange>
}

/// 变更检测策略
public enum DetectStrategy {
    | Hash         // 内容寻址（SHA-256）
    | Timestamp    // 时间戳比对
    | Hybrid       // 混合策略（默认）
}

/// 文件变更信息
public class FileChange {
    public var path: String              // 文件路径
    public var changeType: ChangeType    // 变更类型: created, modified, deleted
    public var lastModified: DateTime    // 最后修改时间
    public var entityType: String        // 实体类型
    public var entityId: String          // 实体ID
    public var contentHash: String       // 内容哈希（SHA-256，64位十六进制）
}

/// 变更类型
public enum ChangeType {
    | Created
    | Modified
    | Deleted
}
```

### 1.3.6 DebounceWindow（防抖窗口）

**职责**: 文件变更事件防抖与批量合并，窗口内同一实体的多次变更合并为一次同步

**包路径**: `magic.app.services.sync.detector`

```cangjie
package magic.app.services.sync.detector

public class DebounceWindow {
    // 防抖窗口时长（毫秒）
    private let windowMs: Int64
    
    // 待合并变更表：key = "entityType:entityId"
    private let pendingChanges: ConcurrentHashMap<String, FileChange>
    
    // 窗口定时器
    private let windowTimer: Timer
    
    /// 构造函数
    public init(windowMs: Int64 = 500)  // 默认 500ms，可配置范围 [100, 5000]
    
    /// 收集变更事件（防抖合并）
    public func collect(change: FileChange): Unit {
        let key = "\(change.entityType):\(change.entityId)"
        // 窗口内同一实体的多次变更合并，保留最终状态
        pendingChanges.put(key, change)
        // 重置窗口定时器
        resetWindowTimer()
    }
    
    /// 批量收集变更事件
    public func collectBatch(changes: Array<FileChange>): Unit
    
    /// 获取并清空窗口内的所有变更（窗口到期时调用）
    public func flush(): Array<FileChange>
    
    /// 获取防抖合并率 Metrics
    public prop mergeRate: Float64  // 被合并事件数 / 原始事件数
}
```

### 1.3.7 SyncInterceptor（AOP同步拦截器）

**职责**: 通过 AOP 切面拦截业务实体 DAO 操作，携带同步上下文检查，触发文件同步

**包路径**: `magic.app.services.sync.interceptor`

**设计说明**: 
1. 复用 fountain 框架的 `f_aspect` 子模块，通过 `@AspectRoute` 注解定义切点规则
2. **拦截范围限定**：仅拦截业务实体 DAO（通过实体类型白名单 + 包路径排除规则）
3. **循环同步防护**：触发前检查 SyncContext，若当前操作携带同步源标记则跳过

```cangjie
package magic.app.services.sync.interceptor

import f_aspect.{Aspect, AspectRoute, InvocationFuncInfo, WithinRouteRule, FuncNameRouteRule, ExecutionRouteRule, ArgsRouteRule, ReturnTypeRouteRule}

/**
 * 同步拦截器：拦截业务实体 DAO 操作，触发文件同步
 * 
 * 切点规则：
 * - 拦截 magic.app.dao.uctoo 包下所有 DAO 类（业务实体 DAO）
 * - 排除 magic.app.dao.sync 包下所有 DAO 类（同步系统自身 DAO）
 * - 拦截 insert/update/delete 开头的方法
 */
@AspectRoute(ExecutionRouteRule(
    within = WithinRouteRule("magic.app.dao.uctoo.*") & !WithinRouteRule("magic.app.dao.sync.*"),
    funcType = FuncNameRouteRule("insert*|update*|delete*") & ArgsRouteRule("**") & ReturnTypeRouteRule("*")
))
public class SyncInterceptor : Aspect {
    // 实体类型白名单（仅拦截白名单内的实体类型）
    private let entityTypeWhitelist: HashSet<String> = HashSet(["agent", "agent_skill", "skill"])
    
    /**
     * 在原方法执行后执行（after 通知）
     */
    public override func after(funcInfo: InvocationFuncInfo, result: Any): Any {
        // === 循环同步防护：检查同步上下文 ===
        if (SyncContext.isPresent()) {
            // 当前操作由同步系统触发，跳过拦截，防止递归
            return result
        }
        
        // 获取被拦截的方法名
        let methodName = funcInfo.funcInfo.name
        
        // 获取方法参数（第一个参数通常是实体对象）
        if let Some(entity) <- funcInfo.args.first {
            // === 拦截范围限定：实体类型白名单检查 ===
            let entityType = extractEntityType(funcInfo)
            if !entityTypeWhitelist.contains(entityType) {
                return result  // 非白名单实体类型，跳过拦截
            }
            
            let entityId = extractEntityId(entity)
            if !entityId.isEmpty {
                // 异步触发文件同步，不阻塞主线程
                async {
                    do {
                        // 构建同步上下文（标记为同步系统触发）
                        let context = SyncContext(
                            taskId: UUID.randomUUID().toString(),
                            triggerSource: TriggerSource.SyncSystem,
                            traceId: TraceContext.currentTraceId(),
                            direction: SyncDirection.DBToFileSystem,
                            entityType: entityType,
                            entityId: entityId
                        )
                        
                        SyncManager.instance?.triggerSync(
                            entityType,
                            entityId,
                            SyncDirection.DBToFileSystem,
                            TriggerSource.SyncSystem,
                            SyncPriority.Medium
                        )
                    } catch {
                        // 忽略同步异常，不影响主业务
                        LogUtils.warn("Failed to trigger sync for ${methodName}")
                    }
                }
            }
        }
        
        // 返回原方法结果
        result
    }
    
    /**
     * 从调用信息中提取实体类型（从类名提取，如 AgentDAO -> agent）
     */
    private func extractEntityType(funcInfo: InvocationFuncInfo): String {
        let className = funcInfo.typeInfo.qualifiedName
        // 移除 "DAO" 后缀，转为小写
        className.replace("DAO", "").toLowerCase()
    }
    
    /**
     * 从实体对象中提取实体ID
     */
    private func extractEntityId(entity: Any): String {
        match entity {
            case e: { prop id: String } => e.id
            case e: { prop entityId: String } => e.entityId
            case _ => ""
        }
    }
}
```

### 1.3.8 ContentHasher（内容哈希计算器）

**职责**: 计算文件内容的 SHA-256 哈希值，用于内容寻址变更检测

**包路径**: `magic.app.services.sync.infrastructure`

```cangjie
package magic.app.services.sync.infrastructure

public class ContentHasher {
    /// 计算字符串内容的 SHA-256 哈希值
    public static func computeSHA256(content: String): String
    
    /// 计算文件内容的 SHA-256 哈希值
    public static func computeFileHash(filePath: String): String
    
    /// 验证内容哈希是否匹配
    public static func verifyHash(content: String, expectedHash: String): Bool {
        computeSHA256(content) == expectedHash
    }
}
```

### 1.3.9 VersionVector（版本向量）

**职责**: 为每个实体维护分布式版本向量，记录文件侧/数据库侧修改逻辑时钟，用于精确检测并发冲突

**包路径**: `magic.app.services.sync.infrastructure`

```cangjie
package magic.app.services.sync.infrastructure

public class VersionVector {
    // 文件侧修改逻辑时钟
    public var fileClock: Int64
    
    // 数据库侧修改逻辑时钟
    public var dbClock: Int64
    
    // 基线版本（上次同步时的快照）
    public var baseFileClock: Int64
    public var baseDbClock: Int64
    
    /// 递增文件侧时钟
    public func incrementFileClock(): Unit {
        fileClock += 1
    }
    
    /// 递增数据库侧时钟
    public func incrementDbClock(): Unit {
        dbClock += 1
    }
    
    /// 检测并发冲突：
    /// 冲突条件：fileClock > baseFileClock && dbClock > baseDbClock
    /// （两侧自上次同步后均有修改）
    public func hasConflict(): Bool {
        fileClock > baseFileClock && dbClock > baseDbClock
    }
    
    /// 同步完成后更新基线
    public func updateBase(): Unit {
        baseFileClock = fileClock
        baseDbClock = dbClock
    }
    
    /// 序列化为 JSON（存储到 sync_status.version_vector）
    public func toJson(): String
    
    /// 从 JSON 反序列化
    public static func fromJson(json: String): Option<VersionVector>
}
```

### 1.3.10 ThreeWayMerge（三路合并）

**职责**: 以两个版本的最近公共祖先为参考，进行三方合并

**包路径**: `magic.app.services.sync.resolver`

```cangjie
package magic.app.services.sync.resolver

public class ThreeWayMerge {
    /// 执行三路合并
    /// - base: 最近公共祖先版本
    /// - ours: 文件侧版本
    /// - theirs: 数据库侧版本
    /// 返回: 合并结果（成功/冲突需人工解决）
    public static func merge(
        base: EntitySnapshot,
        ours: EntitySnapshot,
        theirs: EntitySnapshot
    ): MergeResult
    
    /// 查找最近公共祖先版本
    public static func findBaseVersion(
        entityType: String,
        entityId: String
    ): Option<EntitySnapshot>
}

/// 实体快照（用于三路合并）
public class EntitySnapshot {
    public var contentHash: String       // 版本哈希
    public var fields: HashMap<String, Any>  // 字段键值对
    public var versionVector: VersionVector
    public var timestamp: DateTime
}

/// 合并结果
public class MergeResult {
    public var success: Bool             // 是否自动合并成功
    public var mergedSnapshot: Option<EntitySnapshot>  // 合并后快照
    public var conflictFields: Array<String>  // 冲突字段列表（需人工解决）
}
```

### 1.3.11 ConflictResolver（冲突解决器）

**职责**: 基于版本向量检测并发修改冲突，支持三路合并与多种解决策略

**包路径**: `magic.app.services.sync.resolver`

```cangjie
package magic.app.services.sync.resolver

public class ConflictResolver {
    /// 冲突解决策略
    public enum ConflictStrategy {
        | ThreeWayMerge       // 三路合并（默认）
        | SourcePriority      // 源优先（指定来源）
        | TimestampPriority   // 时间戳优先（降级策略）
        | ManualResolve       // 手动解决
    }
    
    /// 基于版本向量检测冲突
    public func detectByVersionVector(
        entityType: String,
        entityId: String,
        versionVector: VersionVector
    ): Option<ConflictInfo>
    
    /// 解决冲突
    public func resolve(
        entityType: String,
        entityId: String,
        strategy: ConflictStrategy
    ): SyncResult
    
    /// 获取冲突列表（分页）
    public func listConflicts(
        entityType: String?,
        page: Int32,
        pageSize: Int32
    ): Pagination<ConflictInfo>
    
    /// 获取冲突详情
    public func getConflictDetail(conflictId: String): Option<ConflictInfo>
}

/// 冲突信息
public class ConflictInfo {
    public var id: String
    public var entityType: String
    public var entityId: String
    public var conflictStatus: ConflictStatus  // detected, auto_resolved, manual_resolved, pending
    public var resolutionStrategy: Option<ConflictStrategy>
    public var baseVersionHash: Option<String>  // 公共祖先版本哈希
    public var oursVersionHash: String          // 文件侧版本哈希
    public var theirsVersionHash: String        // 数据库侧版本哈希
    public var resolvedVersionHash: Option<String>  // 解决后版本哈希
    public var versionVector: VersionVector
    public var detectedAt: DateTime
    public var resolvedAt: Option<DateTime>
}
```

### 1.3.12 RateLimiter（限流器）

**职责**: 令牌桶/滑动窗口限流，控制同步触发 QPS

**包路径**: `magic.app.services.sync.infrastructure`

```cangjie
package magic.app.services.sync.infrastructure

public class RateLimiter {
    // 限流算法
    private let algorithm: RateLimitAlgorithm
    
    // 全局 QPS 上限
    private let globalMaxQps: Int32
    
    // 单实体类型 QPS 上限
    private let perTypeMaxQps: ConcurrentHashMap<String, Int32>
    
    /// 构造函数
    public init(
        algorithm: RateLimitAlgorithm = RateLimitAlgorithm.TokenBucket,
        globalMaxQps: Int32 = 100
    )
    
    /// 尝试获取令牌（全局限流）
    public func tryAcquire(): Bool
    
    /// 尝试获取令牌（按实体类型限流）
    public func tryAcquire(entityType: String): Bool
    
    /// 获取当前限流拒绝数
    public prop rejectedCount: Int64
}

/// 限流算法
public enum RateLimitAlgorithm {
    | TokenBucket      // 令牌桶（允许短时突发）
    | SlidingWindow    // 滑动窗口（严格限制平均 QPS）
}
```

### 1.3.13 CircuitBreakerManager（熔断管理器）

**职责**: 循环同步检测与熔断，同一实体在检测窗口内双向同步超过阈值时熔断

**包路径**: `magic.app.services.sync.infrastructure`

```cangjie
package magic.app.services.sync.infrastructure

public class CircuitBreakerManager {
    // 实体同步计数器表：key = "entityType:entityId"
    private let counters: ConcurrentHashMap<String, CircularCounter>
    
    // 检测窗口（秒）
    private let windowSeconds: Int64 = 10
    
    // 熔断阈值（窗口内双向同步触发次数上限）
    private let threshold: Int32 = 3
    
    // 熔断持续时间（秒）
    private let breakerDurationSeconds: Int64 = 60
    
    // 熔断状态表
    private let breakerStates: ConcurrentHashMap<String, CircuitBreakerState>
    
    /// 记录同步触发（循环检测）
    public func recordTrigger(entityType: String, entityId: String): Unit
    
    /// 检查实体是否被熔断
    public func isCircuitBroken(entityType: String, entityId: String): Bool
    
    /// 手动恢复熔断
    public func recover(entityType: String, entityId: String): Unit
    
    /// 获取熔断实体数
    public prop circuitBreakerCount: Int32
}

/// 循环计数器
public class CircularCounter {
    public var count: Int32
    public var windowStart: DateTime
}

/// 熔断状态
public class CircuitBreakerState {
    public var entityType: String
    public var entityId: String
    public var brokenAt: DateTime
    public var recoverAt: DateTime      // 自动恢复时间
    public var triggerCount: Int32      // 触发熔断的同步次数
}
```

### 1.3.14 PrioritySyncQueue（优先级同步队列）

**职责**: 同步任务优先级调度队列，支持背压机制

**包路径**: `magic.app.services.sync.infrastructure`

```cangjie
package magic.app.services.sync.infrastructure

public class PrioritySyncQueue<T> {
    // 队列容量上限
    private let capacity: Int32
    
    // 高/中/低优先级队列
    private let highQueue: AsyncQueue<T>
    private let mediumQueue: AsyncQueue<T>
    private let lowQueue: AsyncQueue<T>
    
    // 高水位阈值（触发背压）
    private let highWatermark: Float64 = 0.8  // 80%
    
    // 背压策略
    private let backpressureStrategy: BackpressureStrategy
    
    /// 入队（按优先级）
    public func enqueue(task: T, priority: SyncPriority): BackpressureResult
    
    /// 出队（高优先级优先，同优先级 FIFO）
    public func dequeue(): Option<T>
    
    /// 当前队列深度
    public prop depth: Int32
    
    /// 队列是否超过高水位
    public prop isHighWatermark: Bool
    
    /// 获取队列容量使用率
    public prop usageRate: Float64
}

/// 同步优先级
public enum SyncPriority {
    | High      // 手动触发、冲突解决
    | Medium    // 事件监听触发
    | Low       // 定时扫描触发、启动全量同步
}

/// 背压策略
public enum BackpressureStrategy {
    | Degrade    // 降级：仅记录变更事件，队列空闲时补偿
    | Delay      // 延迟：等待队列水位下降后入队
    | Reject     // 拒绝：返回错误，调用方决定是否重试
}

/// 背压处理结果
public enum BackpressureResult {
    | Accepted            // 正常入队
    | Degraded           // 降级为仅记录变更
    | Delayed(durationMs) // 延迟入队
    | Rejected           // 拒绝入队
}
```

### 1.3.15 SyncMetrics（同步度量采集器）

**职责**: 采集同步 Metrics 指标，支持成功率、延迟分布、冲突率、队列深度等

**包路径**: `magic.app.services.sync.metrics`

```cangjie
package magic.app.services.sync.metrics

public class SyncMetrics {
    // 同步请求总数（按实体类型、方向、结果分类）
    private let totalCounter: AtomicInt64
    private let successCounter: AtomicInt64
    private let failureCounter: AtomicInt64
    private let conflictCounter: AtomicInt64
    
    // 延迟分布（P50/P95/P99）
    private let latencyHistogram: Histogram
    
    // 限流拒绝数
    private let rateLimitRejectedCounter: AtomicInt64
    
    // 熔断实体数
    private let circuitBreakerCounter: AtomicInt32
    
    // 队列深度
    private prop queueDepth: Int32
    
    /// 记录同步成功
    public func recordSuccess(entityType: String, direction: SyncDirection, durationMs: Int64): Unit
    
    /// 记录同步失败
    public func recordFailure(entityType: String, direction: SyncDirection, durationMs: Int64): Unit
    
    /// 记录冲突检测
    public func recordConflict(entityType: String): Unit
    
    /// 记录限流拒绝
    public func recordRateLimitRejected(): Unit
    
    /// 记录熔断
    public func recordCircuitBreaker(): Unit
    
    /// 获取同步成功率
    public prop successRate: Float64
    
    /// 获取同步延迟分布
    public prop latencyP50: Int64
    public prop latencyP95: Int64
    public prop latencyP99: Int64
    
    /// 获取冲突率
    public prop conflictRate: Float64
    
    /// 获取防抖合并率
    public prop debounceMergeRate: Float64
    
    /// 导出 Metrics 快照
    public func snapshot(): SyncMetricsSnapshot
}

/// Metrics 快照
public class SyncMetricsSnapshot {
    public var totalRequests: Int64
    public var successCount: Int64
    public var failureCount: Int64
    public var conflictCount: Int64
    public var successRate: Float64
    public var conflictRate: Float64
    public var latencyP50: Int64
    public var latencyP95: Int64
    public var latencyP99: Int64
    public var queueDepth: Int32
    public var queueCapacity: Int32
    public var rateLimitRejectedCount: Int64
    public var circuitBreakerCount: Int32
    public var debounceMergeRate: Float64
}
```

### 1.3.16 SyncEventPublisher（同步事件发布器）

**职责**: 发布同步领域事件到内部事件总线

**包路径**: `magic.app.services.sync.event`

```cangjie
package magic.app.services.sync.event

public class SyncEventPublisher {
    // 内部事件总线
    private let eventBus: EventBus
    
    /// 发布 SyncCompleted 事件
    public func publishSyncCompleted(
        entityType: String, entityId: String, direction: SyncDirection,
        taskId: String, traceId: String, durationMs: Int64
    ): Unit
    
    /// 发布 SyncFailed 事件
    public func publishSyncFailed(
        entityType: String, entityId: String, direction: SyncDirection,
        taskId: String, traceId: String, errorCode: String, errorMessage: String, retryCount: Int32
    ): Unit
    
    /// 发布 ConflictDetected 事件
    public func publishConflictDetected(
        entityType: String, entityId: String, conflictId: String,
        oursVersion: String, theirsVersion: String, baseVersion: Option<String>
    ): Unit
    
    /// 发布 ConflictResolved 事件
    public func publishConflictResolved(
        entityType: String, entityId: String, conflictId: String,
        resolutionStrategy: String, resolvedVersion: String
    ): Unit
    
    /// 发布 SyncCircuitBreakerTriggered 事件
    public func publishCircuitBreakerTriggered(
        entityType: String, entityId: String, triggerCount: Int32, windowSeconds: Int64
    ): Unit
    
    /// 发布 SyncCircuitBreakerRecovered 事件
    public func publishCircuitBreakerRecovered(
        entityType: String, entityId: String, recoveryType: String
    ): Unit
    
    /// 发布 SyncBackpressureTriggered 事件
    public func publishBackpressureTriggered(
        queueDepth: Int32, queueCapacity: Int32, strategy: String
    ): Unit
    
    /// 发布 SyncTaskCancelled 事件
    public func publishTaskCancelled(
        taskId: String, entityType: String, entityId: String, reason: String
    ): Unit
}

/// 领域事件基类
public class SyncDomainEvent {
    public var eventId: String          // 事件唯一ID
    public var eventType: String        // 事件类型
    public var eventSource: String = "sync-system"  // 事件源
    public var timestamp: DateTime      // 事件时间戳
    public var payload: HashMap<String, Any>  // 事件载荷
}
```

### 1.3.17 TopologySorter（拓扑排序器）

**职责**: 实体依赖拓扑排序，确保被依赖实体先同步

**包路径**: `magic.app.services.sync.infrastructure`

```cangjie
package magic.app.services.sync.infrastructure

public class TopologySorter {
    /// 对实体类型列表按依赖关系拓扑排序
    /// 依赖关系：agent_skill 依赖 agent
    /// 排序结果：agent → agent_skill → skill
    public static func sort(handlers: Array<SyncHandler>): Array<SyncHandler>
    
    /// 检测循环依赖
    public static func detectCircularDependency(handlers: Array<SyncHandler>): Option<Array<String>>
}
```

### 1.3.18 DataMapper（数据映射器）

**职责**: 文件格式与实体对象的双向转换，维护映射版本兼容

**包路径**: `magic.app.services.sync.mapper`

```cangjie
package magic.app.services.sync.mapper

public class DataMapper {
    /// 解析 Agent Markdown 文件（向前兼容处理）
    public func parseAgent(content: String, mappingVersion: Int32 = CURRENT_VERSION): AgentPO
    
    /// 序列化 AgentPO 为 Markdown（向后兼容处理，支持指定目标版本）
    public func serializeAgent(agent: AgentPO, targetVersion: Int32 = CURRENT_VERSION): String
    
    /// 解析 Skill Markdown 文件
    public func parseSkill(content: String, mappingVersion: Int32 = CURRENT_VERSION): SkillPO
    
    /// 序列化 SkillPO 为 Markdown
    public func serializeSkill(skill: SkillPO, targetVersion: Int32 = CURRENT_VERSION): String
    
    /// 解析 JSON 文件
    public func parseJson(content: String): JsonValue
    
    /// 序列化为 JSON
    public func serializeJson(obj: Object): String
    
    /// 解析 YAML 文件
    public func parseYaml(content: String): JsonValue
    
    /// 序列化为 YAML
    public func serializeYaml(obj: Object): String
    
    /// 提取 Markdown Frontmatter
    public func extractFrontmatter(content: String): JsonValue
    
    /// 构建 Markdown Frontmatter
    public func buildFrontmatter(data: JsonValue): String
    
    /// 当前映射版本号
    public static let CURRENT_VERSION: Int32 = 1
}
```

### 1.3.19 SyncStatusManager（同步状态管理器）

**职责**: 管理和维护同步状态，支持原子性状态更新

**包路径**: `magic.app.services.sync.status`

```cangjie
package magic.app.services.sync.status

public class SyncStatusManager {
    /// 更新同步状态（原子操作）
    public func updateStatus(
        entityType: String, entityId: String, status: SyncStatus, message: String?
    ): Unit
    
    /// 同步完成后更新状态（含版本向量和内容哈希）
    public func updateAfterSync(
        entityType: String, entityId: String, contentHash: String,
        versionVector: VersionVector, direction: SyncDirection
    ): Unit
    
    /// 获取同步状态
    public func getStatus(entityType: String, entityId: String): Option<SyncStatusPO>
    
    /// 获取状态概览
    public func getStatusSummary(): SyncStatusSummary
    
    /// 批量更新状态
    public func batchUpdateStatus(updates: Array<StatusUpdate>): Unit
    
    /// 获取运行中同步任务快照
    public func getRunningSyncs(): ArrayList<RunningSyncInfo>
    
    /// 优雅关闭：等待运行中同步任务完成
    public func gracefulShutdown(timeout: Duration): Unit
}

/// 同步状态摘要
public class SyncStatusSummary {
    public var systemStatus: SystemStatus   // normal, degraded, circuit_breaker
    public var totalEntities: Int32
    public var syncedCount: Int32
    public var pendingCount: Int32
    public var failedCount: Int32
    public var conflictCount: Int32
    public var circuitBreakerCount: Int32
    public var dependencyMissingCount: Int32
    public var queueDepth: Int32
    public var queueCapacity: Int32
    public var lastSyncAt: Option<DateTime>
}

/// 系统运行状态
public enum SystemStatus {
    | Normal          // 正常
    | Degraded        // 降级（部分功能受限）
    | CircuitBreaker  // 熔断（同步暂停）
}

/// 运行中同步任务信息
public class RunningSyncInfo {
    public var taskId: String
    public var entityType: String
    public var entityId: String
    public var direction: SyncDirection
    public var startTime: DateTime
    public var progress: Int32  // 0-100
}
```

### 1.3.20 RetryManager（重试管理器）

**职责**: 同步失败时自动重试，采用指数退避策略（1s, 2s, 4s），复用计划任务模块

**包路径**: `magic.app.services.sync.retry`

```cangjie
package magic.app.services.sync.retry

public class RetryManager {
    /// 包装同步操作，加入重试逻辑
    public func executeWithRetry(
        task: SyncTask,
        operation: () -> SyncResult
    ): SyncResult
    
    /// 计算下一次重试的延迟时间（指数退避：1s, 2s, 4s）
    public func calculateRetryDelay(attempt: Int32): Int64 {
        // 指数退避：baseMs * 2^attempt
        // attempt=0: 1000ms, attempt=1: 2000ms, attempt=2: 4000ms
        let baseMs: Int64 = 1000
        baseMs * (1 << attempt)
    }
    
    /// 获取最大重试次数（默认 3 次）
    public prop maxRetries: Int32
}
```

### 1.3.21 AsyncLogWriter（异步日志写入器）

**职责**: 异步写入同步日志，不阻塞主线程，复用计划任务模块

**包路径**: `magic.app.services.sync.logging`

```cangjie
package magic.app.services.sync.logging

public class AsyncLogWriter {
    /// 异步写入日志
    public func writeLog(log: SyncLogPO): Future<Unit>
    
    /// 批量写入日志
    public func writeLogs(logs: Array<SyncLogPO>): Future<Unit>
    
    /// 刷新缓冲
    public func flush(): Unit
    
    /// 停止写入器
    public func stop(): Unit
}
```

### 1.3.22 关键数据类型

**包路径**: `magic.app.services.sync.model`

```cangjie
package magic.app.services.sync.model

/// 同步方向
public enum SyncDirection {
    | FileSystemToDB    // 文件系统→数据库
    | DBToFileSystem    // 数据库→文件系统
    | Bidirectional     // 双向同步
}

/// 同步状态
public enum SyncStatus {
    | Pending             // 待同步
    | Syncing             // 同步中
    | Synced              // 已同步
    | Failed              // 同步失败
    | Conflict            // 冲突
    | CircuitBreaker      // 熔断
    | DependencyMissing   // 依赖缺失
}

/// 同步结果
public class SyncResult {
    public var success: Bool
    public var taskId: String           // 同步任务ID（幂等性去重键）
    public var entityType: String
    public var entityId: String
    public var status: SyncStatus
    public var message: String
    public var errorDetail: String?
    public var durationMs: Int64        // 同步耗时（毫秒）
    public var timestamp: DateTime
}

/// 批量同步结果
public class SyncBatchResult {
    public var taskId: String
    public var totalCount: Int32
    public var successCount: Int32
    public var failedCount: Int32
    public var conflictCount: Int32
    public var details: Array<SyncResult>
}

/// 同步任务
public class SyncTask {
    public var taskId: String           // 唯一任务ID（幂等性保证）
    public var taskType: TaskType       // 任务类型
    public var entityType: String
    public var entityId: String
    public var direction: SyncDirection
    public var priority: SyncPriority
    public var triggerSource: TriggerSource  // 触发源
    public var traceId: String          // 分布式追踪ID
    public var createdAt: DateTime
}

/// 任务类型
public enum TaskType {
    | Single       // 单实体同步
    | Batch        // 批量同步
    | FullSync     // 全量同步
}

/// 冲突状态
public enum ConflictStatus {
    | Detected       // 已检测
    | AutoResolved   // 自动解决
    | ManualResolved // 手动解决
    | Pending        // 待解决
}
```

---

# **2. 接口设计**

## **2.1 总体设计**

1. 遵循 UCTOO V4 RESTful 规范，路由前缀 `/api/v1/uctoo/sync/`
2. 所有接口受 JWT 认证 + RBAC 权限保护（sync:read / sync:write）
3. 响应格式遵循 UMI 全栈模型同构规范
4. 支持异步同步，返回任务 ID 用于后续查询
5. 支持分页参数（page, pageSize）和过滤参数（status, type）

## **2.2 接口清单**

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/uctoo/sync/status` | 获取同步状态概览 | sync:read |
| GET | `/api/v1/uctoo/sync/entities` | 获取所有实体的同步状态（分页） | sync:read |
| GET | `/api/v1/uctoo/sync/entities/:type` | 获取指定类型实体的同步状态（分页） | sync:read |
| GET | `/api/v1/uctoo/sync/entities/:type/:id` | 获取单个实体的同步状态 | sync:read |
| POST | `/api/v1/uctoo/sync/entities/:type/:id` | 手动触发单个实体同步 | sync:write |
| DELETE | `/api/v1/uctoo/sync/tasks/:taskId` | 取消正在执行的同步任务 | sync:write |
| POST | `/api/v1/uctoo/sync/entities/:type/batch` | 批量同步指定类型的实体 | sync:write |
| POST | `/api/v1/uctoo/sync/batch` | 批量同步所有实体 | sync:write |
| GET | `/api/v1/uctoo/sync/conflicts` | 获取冲突列表（分页） | sync:read |
| GET | `/api/v1/uctoo/sync/conflicts/:id` | 获取冲突详情 | sync:read |
| POST | `/api/v1/uctoo/sync/conflicts/:id/resolve` | 手动解决冲突 | sync:write |
| GET | `/api/v1/uctoo/sync/logs` | 查询同步日志（分页） | sync:read |
| DELETE | `/api/v1/uctoo/sync/logs` | 清理同步日志 | sync:write |
| GET | `/api/v1/uctoo/sync/health` | 同步系统健康检查 | sync:read |

### **请求/响应示例**

**手动触发同步**

请求:
```json
POST /api/v1/uctoo/sync/entities/agent/agent-123
{
  "direction": "bidirectional",
  "force": false,
  "priority": "high"
}
```

响应:
```json
{
  "taskId": "sync-task-uuid-001",
  "entityType": "agent",
  "entityId": "agent-123",
  "status": "pending",
  "message": "同步任务已提交",
  "timestamp": "2026-06-02T10:30:00Z"
}
```

**同步状态概览**

请求:
```json
GET /api/v1/uctoo/sync/status
```

响应:
```json
{
  "systemStatus": "normal",
  "totalEntities": 150,
  "syncedCount": 145,
  "pendingCount": 3,
  "failedCount": 2,
  "conflictCount": 0,
  "circuitBreakerCount": 0,
  "queueDepth": 5,
  "queueCapacity": 10000,
  "lastSyncAt": "2026-06-02T10:25:00Z"
}
```

**实体同步状态列表（分页）**

请求:
```json
GET /api/v1/uctoo/sync/entities?page=1&pageSize=20&status=failed&type=agent
```

响应:
```json
{
  "total": 2,
  "page": 1,
  "pageSize": 20,
  "items": [
    {
      "entityType": "agent",
      "entityId": "agent-456",
      "syncStatus": "failed",
      "lastSyncAt": "2026-06-02T10:20:00Z",
      "errorMessage": "文件格式错误: 第3行YAML语法无效",
      "retryCount": 3
    }
  ]
}
```

**批量同步**

请求:
```json
POST /api/v1/uctoo/sync/entities/agent/batch
{
  "direction": "fs_to_db",
  "force": false,
  "priority": "low"
}
```

响应:
```json
{
  "taskId": "sync-batch-uuid-002",
  "entityType": "agent",
  "totalEntities": 50,
  "status": "in_progress",
  "message": "批量同步任务已提交",
  "timestamp": "2026-06-02T10:30:00Z"
}
```

**取消同步任务**

请求:
```json
DELETE /api/v1/uctoo/sync/tasks/sync-task-uuid-001
```

响应:
```json
{
  "taskId": "sync-task-uuid-001",
  "status": "cancelled",
  "message": "同步任务已取消",
  "timestamp": "2026-06-02T10:31:00Z"
}
```

**冲突列表（分页）**

请求:
```json
GET /api/v1/uctoo/sync/conflicts?page=1&pageSize=20&type=agent
```

响应:
```json
{
  "total": 1,
  "page": 1,
  "pageSize": 20,
  "items": [
    {
      "conflictId": "conflict-uuid-001",
      "entityType": "agent",
      "entityId": "agent-789",
      "detectedAt": "2026-06-02T10:15:00Z",
      "status": "pending",
      "strategy": "three_way_merge"
    }
  ]
}
```

**健康检查**

请求:
```json
GET /api/v1/uctoo/sync/health
```

响应:
```json
{
  "status": "normal",
  "queueDepth": 5,
  "queueCapacity": 10000,
  "recentFailCount1m": 0,
  "circuitBreakerCount": 0,
  "lastSuccessfulSyncAt": "2026-06-02T10:29:00Z"
}
```

## **2.3 CLI 命令体系**

```
skill sync <command> [options]

命令列表:
  status                            查看同步状态概览
  list [<entity-type>]              列出实体同步状态（分页）
  show <entity-type> <entity-id>    显示单个实体同步状态
  sync <entity-type> <entity-id>    手动同步单个实体
  sync-all [<entity-type>]          同步所有实体
  conflicts                         列出冲突列表
  resolve <conflict-id> <strategy>  解决冲突
  logs [options]                    查看同步日志
  cancel <task-id>                  取消同步任务
  recover <entity-type> <entity-id> 恢复熔断实体
  enable                            启用同步功能
  disable                           禁用同步功能
  config                            查看同步配置
  health                            健康检查

sync 选项:
  --direction <value>    同步方向: fs_to_db, db_to_fs, bidirectional (default: bidirectional)
  --force               强制同步（覆盖冲突）
  --priority <value>    优先级: high, medium, low (default: medium)

resolve 选项:
  --strategy <value>    解决策略: three_way_merge, source_priority, timestamp_priority, manual
  --source <value>      源优先时指定来源: fs, db

通用选项:
  --format json         JSON格式输出
  --limit <n>           限制条数
  --page <n>            页码
  --page-size <n>       每页条数
```

---

# **3. 集成设计**

## **3.1 应用启动流程集成**

**文件**: `src/app/main.cj` 中 `Application` 类

```cangjie
// Application 类新增成员变量:
private var syncManager: Option<SyncManager> = None
private var changeDetector: Option<ChangeDetector> = None

// init() 末尾新增（在 setupRoutes 之后）:
if (Config.syncEnabled) {
    try {
        // 初始化同步管理器
        syncManager = Some(SyncManager.initialize())
        
        // 注册同步处理器
        syncManager.get().registerHandler("agent", AgentSyncHandler())
        syncManager.get().registerHandler("agent_skill", AgentSkillSyncHandler())
        syncManager.get().registerHandler("skill", SkillSyncHandler())
        
        // 注册AOP切面拦截器（含实体类型白名单 + 包路径排除规则）
        AspectRegistry.register(SyncInterceptor())
        
        // 创建变更检测器（含防抖窗口 + 节流）
        changeDetector = Some(ChangeDetector(
            onChange: { changes in
                // 批量触发同步（按拓扑排序）
                let sortedChanges = TopologySorter.sortByDependency(changes)
                for change in sortedChanges {
                    syncManager.get().triggerSync(
                        change.entityType,
                        change.entityId,
                        SyncDirection.FileSystemToDB,
                        TriggerSource.Business,
                        SyncPriority.Medium
                    )
                }
            },
            debounceMs: Config.syncDebounceMs,
            maxQps: Config.syncMaxQps
        ))
        
        // 启动文件监听
        changeDetector.get().startListening(Config.syncAgentBasePath)
        changeDetector.get().startListening(Config.syncSkillBasePath)
        
        // 启动定时扫描
        changeDetector.get().startPeriodicScan(Config.syncScanInterval)
        
        // [异步] 执行初始化全量同步（不阻塞启动，超时后应用正常启动）
        async {
            try {
                syncManager.get().syncAll(None)
                LogUtils.info("Initial sync completed successfully")
            } catch (e: Exception) {
                LogUtils.warn("Initial sync failed (will retry in background): ${e.message}")
            }
        }
        
        LogUtils.info("Sync system initialized successfully")
    } catch (e: Exception) {
        LogUtils.error("Failed to initialize sync system: ${e.message}")
        // 同步系统初始化失败不影响应用启动
    }
}

// stop() 中新增（在 server.stop() 之前）:
public func stop(): Unit {
    logger.info("Stopping uctoo-backend-v4")
    
    // 优雅关闭同步管理器
    if (let Some(manager) <- syncManager) {
        manager.gracefulShutdown(Duration.seconds(30))
    }
    
    // 停止变更检测器
    if (let Some(detector) <- changeDetector) {
        detector.stopAll()
    }
    
    server.stop()
    dbPool.closeAll()
    cacheManager.close()
}
```

## **3.2 配置项**

**文件**: `.env` 或配置文件

```ini
# === 同步功能开关 ===
SYNC_ENABLED=true

# === 同步方向 ===
# 默认同步方向: fs_to_db, db_to_fs, bidirectional
SYNC_DEFAULT_DIRECTION=bidirectional

# === 变更检测 ===
# 文件扫描间隔（秒），最小 5 秒
SYNC_SCAN_INTERVAL=30
# 变更检测策略: hash, timestamp, hybrid
SYNC_DETECT_STRATEGY=hybrid
# 文件变更防抖窗口（毫秒），范围 [100, 5000]
SYNC_DEBOUNCE_MS=500

# === 限流与背压 ===
# 同步触发 QPS 上限
SYNC_MAX_QPS=100
# 限流算法: token_bucket, sliding_window
SYNC_RATE_LIMIT_ALGORITHM=token_bucket
# 同步任务队列深度上限
SYNC_QUEUE_CAPACITY=10000
# 队列高水位阈值（百分比，触发背压）
SYNC_QUEUE_HIGH_WATERMARK=80
# 背压策略: degrade, delay, reject
SYNC_BACKPRESSURE_STRATEGY=degrade

# === 重试 ===
# 最大重试次数
SYNC_MAX_RETRIES=3
# 重试策略: fixed_delay, exponential_backoff
SYNC_RETRY_STRATEGY=exponential_backoff

# === 冲突解决 ===
# 冲突解决策略: three_way_merge, source_priority, timestamp_priority, manual
SYNC_CONFLICT_STRATEGY=three_way_merge
# 默认源优先级（当策略为 source_priority 时）: fs, db
SYNC_SOURCE_PRIORITY=db

# === 循环同步防护 ===
# 循环检测窗口（秒）
SYNC_CIRCULAR_WINDOW_SECONDS=10
# 循环检测阈值（窗口内双向同步触发次数上限）
SYNC_CIRCULAR_THRESHOLD=3
# 熔断持续时间（秒）
SYNC_CIRCUIT_BREAKER_DURATION=60

# === 启动同步 ===
# 启动全量同步超时（秒），超时后应用正常启动
SYNC_STARTUP_TIMEOUT=60

# === 文件路径 ===
# Agent 基础路径
SYNC_AGENT_BASE_PATH=./data/agents
# Skill 基础路径
SYNC_SKILL_BASE_PATH=./data/skills

# === 线程池 ===
# 同步任务线程池大小
SYNC_THREAD_POOL_SIZE=4

# === 日志 ===
# 日志保留天数
SYNC_LOG_RETENTION_DAYS=30

# === 可观测性 ===
# Tracing 采样率（0.0-1.0，默认 10%）
SYNC_TRACING_SAMPLE_RATE=0.1

# === 数据映射 ===
# 映射模式: strict, lenient
SYNC_MAPPING_MODE=lenient
```

## **3.3 路由注册**

**文件**: `src/app/routes/uctoo/sync/SyncRoute.cj`（新增）

```cangjie
package magic.app.routes.uctoo.sync

public class SyncRoute {
    private let router: Router
    private let controller: SyncController
    
    public init(router: Router, controller: SyncController) {
        this.router = router
        this.controller = controller
    }
    
    public func register(): Unit {
        // 状态查询
        router.get("/api/v1/uctoo/sync/status", controller.getStatus)
        router.get("/api/v1/uctoo/sync/entities", controller.listEntities)
        router.get("/api/v1/uctoo/sync/entities/:type", controller.listEntitiesByType)
        router.get("/api/v1/uctoo/sync/entities/:type/:id", controller.getEntityStatus)
        
        // 同步操作
        router.post("/api/v1/uctoo/sync/entities/:type/:id", controller.syncEntity)
        router.delete("/api/v1/uctoo/sync/tasks/:taskId", controller.cancelTask)
        router.post("/api/v1/uctoo/sync/entities/:type/batch", controller.syncBatch)
        router.post("/api/v1/uctoo/sync/batch", controller.syncAll)
        
        // 冲突处理
        router.get("/api/v1/uctoo/sync/conflicts", controller.listConflicts)
        router.get("/api/v1/uctoo/sync/conflicts/:id", controller.getConflictDetail)
        router.post("/api/v1/uctoo/sync/conflicts/:id/resolve", controller.resolveConflict)
        
        // 日志管理
        router.get("/api/v1/uctoo/sync/logs", controller.listLogs)
        router.delete("/api/v1/uctoo/sync/logs", controller.cleanLogs)
        
        // 健康检查
        router.get("/api/v1/uctoo/sync/health", controller.healthCheck)
    }
}
```

**路由注册配置**（在 `AutoRouteConfig.initRegistry` 中新增）:

```cangjie
registry.add(RouteEntry(
    "sync",
    "/api/v1/uctoo/sync",
    220,
    true,
    { router: Router =>
        let service = SyncService()
        let controller = SyncController(service)
        let route = SyncRoute(router, controller)
        route.register()
    }
))
```

---

# **4. 数据模型**

## **4.1 设计目标**

1. 支持同步状态持久化，含内容哈希、版本向量、触发源
2. 支持同步日志记录，含任务ID、耗时、追踪ID
3. 支持冲突检测和解决，含公共祖先版本、合并策略、解决详情
4. 支持同步任务队列持久化，含优先级、幂等性约束
5. 兼容现有实体模型

## **4.2 模型实现**

### 4.2.1 同步状态表 (`sync_status`)

```sql
CREATE TABLE IF NOT EXISTS sync_status (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type         VARCHAR(50) NOT NULL,           -- 实体类型: agent, agent_skill, skill
    entity_id           VARCHAR(100) NOT NULL,          -- 实体ID
    file_path           VARCHAR(512),                   -- 文件系统路径
    content_hash        CHAR(64),                       -- 文件内容 SHA-256 哈希值（64位十六进制）
    db_version_clock    INT8 DEFAULT 0,                 -- 数据库侧修改逻辑时钟
    file_version_clock  INT8 DEFAULT 0,                 -- 文件侧修改逻辑时钟
    base_db_clock       INT8 DEFAULT 0,                 -- 基线数据库侧时钟
    base_file_clock     INT8 DEFAULT 0,                 -- 基线文件侧时钟
    sync_status         VARCHAR(30) DEFAULT 'pending',  -- 同步状态
    sync_direction      VARCHAR(20) DEFAULT 'bidirectional',  -- 同步方向
    trigger_source      VARCHAR(20),                    -- 触发源: business, sync_system, manual, startup
    last_sync_at        TIMESTAMPTZ,                    -- 最后同步时间
    error_message       TEXT,                           -- 错误信息
    retry_count         INT4 DEFAULT 0,                 -- 重试次数
    mapping_version     INT4 DEFAULT 1,                 -- 映射版本号
    creator             UUID,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,
    
    -- 唯一性约束：(entity_type, entity_id) 组合唯一
    CONSTRAINT uk_sync_status_entity UNIQUE (entity_type, entity_id)
);

CREATE INDEX idx_sync_status_entity ON sync_status(entity_type, entity_id);
CREATE INDEX idx_sync_status_status ON sync_status(sync_status);
CREATE INDEX idx_sync_status_content_hash ON sync_status(content_hash);
```

### 4.2.2 同步日志表 (`sync_log`)

```sql
CREATE TABLE IF NOT EXISTS sync_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type     VARCHAR(50) NOT NULL,
    entity_id       VARCHAR(100) NOT NULL,
    operation       VARCHAR(30) NOT NULL,       -- 操作类型: create, update, delete, sync, merge, conflict_resolve
    direction       VARCHAR(20) NOT NULL,       -- 同步方向
    status          VARCHAR(20) NOT NULL,       -- 状态: success, failed, conflict, circuit_breaker
    message         TEXT,                       -- 操作消息
    error_detail    TEXT,                       -- 错误详情
    operator_id     VARCHAR(100),               -- 操作者ID
    sync_source     VARCHAR(20) NOT NULL,       -- 同步源标记: business, sync_system, manual, startup
    trace_id        VARCHAR(64),                -- 分布式追踪ID
    task_id         VARCHAR(64),                -- 同步任务ID
    duration_ms     INT4,                       -- 耗时(毫秒)
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sync_log_entity ON sync_log(entity_type, entity_id);
CREATE INDEX idx_sync_log_time ON sync_log(created_at);
CREATE INDEX idx_sync_log_status ON sync_log(status);
CREATE INDEX idx_sync_log_task_id ON sync_log(task_id);
CREATE INDEX idx_sync_log_duration ON sync_log(duration_ms);
```

### 4.2.3 冲突记录表 (`sync_conflict`)

```sql
CREATE TABLE IF NOT EXISTS sync_conflict (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type         VARCHAR(50) NOT NULL,
    entity_id           VARCHAR(100) NOT NULL,
    conflict_status     VARCHAR(20) DEFAULT 'detected',  -- detected, auto_resolved, manual_resolved, pending
    resolution_strategy VARCHAR(30),                    -- 解决策略: three_way_merge, source_priority, timestamp_priority, manual
    base_version_hash   CHAR(64),                       -- 公共祖先版本哈希
    ours_version_hash   CHAR(64) NOT NULL,              -- 文件侧版本哈希
    theirs_version_hash CHAR(64) NOT NULL,              -- 数据库侧版本哈希
    resolved_version_hash CHAR(64),                     -- 解决后版本哈希
    resolution_detail   TEXT,                           -- 解决详情
    detected_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_by         UUID,
    resolved_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    
    -- 唯一性约束：同一实体同一时刻仅一个冲突
    CONSTRAINT uk_sync_conflict_entity_time UNIQUE (entity_type, entity_id, detected_at)
);

CREATE INDEX idx_sync_conflict_entity ON sync_conflict(entity_type, entity_id);
CREATE INDEX idx_sync_conflict_status ON sync_conflict(conflict_status);
```

### 4.2.4 同步任务表 (`sync_task`)

```sql
CREATE TABLE IF NOT EXISTS sync_task (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id         VARCHAR(64) NOT NULL,       -- 同步任务唯一标识
    task_type       VARCHAR(20) NOT NULL,       -- 任务类型: single, batch, full_sync
    entity_type     VARCHAR(50),                -- 实体类型（full_sync 时可为空）
    entity_id       VARCHAR(100),               -- 实体ID（batch/full_sync 时可为空）
    direction       VARCHAR(20) NOT NULL,       -- 同步方向
    priority        VARCHAR(10) DEFAULT 'medium',  -- 优先级: high, medium, low
    task_status     VARCHAR(20) DEFAULT 'pending',  -- 任务状态: pending, running, completed, failed, cancelled
    sync_source     VARCHAR(20) NOT NULL,       -- 同步源标记
    trace_id        VARCHAR(64) NOT NULL,       -- 分布式追踪ID
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    
    -- 幂等性约束：同一 task_id 全局唯一
    CONSTRAINT uk_sync_task_task_id UNIQUE (task_id)
);

CREATE INDEX idx_sync_task_status ON sync_task(task_status);
CREATE INDEX idx_sync_task_entity ON sync_task(entity_type, entity_id);
CREATE INDEX idx_sync_task_created ON sync_task(created_at);
```

### 4.2.5 SyncStatusPO

**文件**: `src/app/models/uctoo/SyncStatusPO.cj`（新增）

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["sync_status"]
public class SyncStatusPO {
    @ORMField['id']
    public var id: String = ""
    
    @ORMField['entity_type']
    public var entityType: String = ""
    
    @ORMField['entity_id']
    public var entityId: String = ""
    
    @ORMField['file_path']
    public var filePath: Option<String> = None<String>
    
    @ORMField['content_hash']
    public var contentHash: Option<String> = None<String>
    
    @ORMField['db_version_clock']
    public var dbVersionClock: Int64 = 0
    
    @ORMField['file_version_clock']
    public var fileVersionClock: Int64 = 0
    
    @ORMField['base_db_clock']
    public var baseDbClock: Int64 = 0
    
    @ORMField['base_file_clock']
    public var baseFileClock: Int64 = 0
    
    @ORMField['sync_status']
    public var syncStatus: String = "pending"
    
    @ORMField['sync_direction']
    public var syncDirection: String = "bidirectional"
    
    @ORMField['trigger_source']
    public var triggerSource: Option<String> = None<String>
    
    @ORMField['last_sync_at']
    public var lastSyncAt: Option<DateTime> = None<DateTime>
    
    @ORMField['error_message']
    public var errorMessage: Option<String> = None<String>
    
    @ORMField['retry_count']
    public var retryCount: Int32 = 0
    
    @ORMField['mapping_version']
    public var mappingVersion: Int32 = 1
    
    @ORMField['creator']
    public var creator: Option<String> = None<String>
    
    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()
    
    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()
    
    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>
    
    public init() {}
}
```

### 4.2.6 SyncTaskPO

**文件**: `src/app/models/uctoo/SyncTaskPO.cj`（新增）

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["sync_task"]
public class SyncTaskPO {
    @ORMField['id']
    public var id: String = ""
    
    @ORMField['task_id']
    public var taskId: String = ""
    
    @ORMField['task_type']
    public var taskType: String = "single"
    
    @ORMField['entity_type']
    public var entityType: Option<String> = None<String>
    
    @ORMField['entity_id']
    public var entityId: Option<String> = None<String>
    
    @ORMField['direction']
    public var direction: String = "bidirectional"
    
    @ORMField['priority']
    public var priority: String = "medium"
    
    @ORMField['task_status']
    public var taskStatus: String = "pending"
    
    @ORMField['sync_source']
    public var syncSource: String = "business"
    
    @ORMField['trace_id']
    public var traceId: String = ""
    
    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()
    
    @ORMField['started_at']
    public var startedAt: Option<DateTime> = None<DateTime>
    
    @ORMField['completed_at']
    public var completedAt: Option<DateTime> = None<DateTime>
    
    public init() {}
}
```

### 4.2.7 SyncConflictPO

**文件**: `src/app/models/uctoo/SyncConflictPO.cj`（新增）

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["sync_conflict"]
public class SyncConflictPO {
    @ORMField['id']
    public var id: String = ""
    
    @ORMField['entity_type']
    public var entityType: String = ""
    
    @ORMField['entity_id']
    public var entityId: String = ""
    
    @ORMField['conflict_status']
    public var conflictStatus: String = "detected"
    
    @ORMField['resolution_strategy']
    public var resolutionStrategy: Option<String> = None<String>
    
    @ORMField['base_version_hash']
    public var baseVersionHash: Option<String> = None<String>
    
    @ORMField['ours_version_hash']
    public var oursVersionHash: String = ""
    
    @ORMField['theirs_version_hash']
    public var theirsVersionHash: String = ""
    
    @ORMField['resolved_version_hash']
    public var resolvedVersionHash: Option<String> = None<String>
    
    @ORMField['resolution_detail']
    public var resolutionDetail: Option<String> = None<String>
    
    @ORMField['detected_at']
    public var detectedAt: DateTime = DateTime.now()
    
    @ORMField['resolved_by']
    public var resolvedBy: Option<String> = None<String>
    
    @ORMField['resolved_at']
    public var resolvedAt: Option<DateTime> = None<DateTime>
    
    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()
    
    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()
    
    public init() {}
}
```

---

# **5. 部署与集成**

## **5.1 依赖声明**

**文件**: `cjpm.toml`

```toml
[dependencies]
  # ... 现有依赖 ...
  
  # AOP 切面库
  f_aspect = {path = "libs/fountain/f_aspect", version = "1.0.0"}
  
  # 文件系统工具
  f_filesystem = {path = "libs/fountain/f_filesystem", version = "1.0.0"}
  
  # JSON/YAML 解析
  f_json = {path = "libs/fountain/f_json", version = "1.0.0"}
  f_yaml = {path = "libs/fountain/f_yaml", version = "1.0.0"}
  
  # 加密哈希（SHA-256）
  f_crypto = {path = "libs/fountain/f_crypto", version = "1.0.0"}
```

## **5.2 数据库迁移**

**文件**: `scripts/migration/sync_system_v2.sql`

```sql
-- ============================================================
-- 文件系统与数据库双向同步系统 v2.0 数据库迁移脚本
-- ============================================================

-- 创建同步状态表
CREATE TABLE IF NOT EXISTS sync_status (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type         VARCHAR(50) NOT NULL,
    entity_id           VARCHAR(100) NOT NULL,
    file_path           VARCHAR(512),
    content_hash        CHAR(64),
    db_version_clock    INT8 DEFAULT 0,
    file_version_clock  INT8 DEFAULT 0,
    base_db_clock       INT8 DEFAULT 0,
    base_file_clock     INT8 DEFAULT 0,
    sync_status         VARCHAR(30) DEFAULT 'pending',
    sync_direction      VARCHAR(20) DEFAULT 'bidirectional',
    trigger_source      VARCHAR(20),
    last_sync_at        TIMESTAMPTZ,
    error_message       TEXT,
    retry_count         INT4 DEFAULT 0,
    mapping_version     INT4 DEFAULT 1,
    creator             UUID,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT uk_sync_status_entity UNIQUE (entity_type, entity_id)
);

-- 创建同步日志表
CREATE TABLE IF NOT EXISTS sync_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type     VARCHAR(50) NOT NULL,
    entity_id       VARCHAR(100) NOT NULL,
    operation       VARCHAR(30) NOT NULL,
    direction       VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL,
    message         TEXT,
    error_detail    TEXT,
    operator_id     VARCHAR(100),
    sync_source     VARCHAR(20) NOT NULL,
    trace_id        VARCHAR(64),
    task_id         VARCHAR(64),
    duration_ms     INT4,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 创建冲突记录表
CREATE TABLE IF NOT EXISTS sync_conflict (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type         VARCHAR(50) NOT NULL,
    entity_id           VARCHAR(100) NOT NULL,
    conflict_status     VARCHAR(20) DEFAULT 'detected',
    resolution_strategy VARCHAR(30),
    base_version_hash   CHAR(64),
    ours_version_hash   CHAR(64) NOT NULL,
    theirs_version_hash CHAR(64) NOT NULL,
    resolved_version_hash CHAR(64),
    resolution_detail   TEXT,
    detected_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_by         UUID,
    resolved_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uk_sync_conflict_entity_time UNIQUE (entity_type, entity_id, detected_at)
);

-- 创建同步任务表
CREATE TABLE IF NOT EXISTS sync_task (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id         VARCHAR(64) NOT NULL,
    task_type       VARCHAR(20) NOT NULL,
    entity_type     VARCHAR(50),
    entity_id       VARCHAR(100),
    direction       VARCHAR(20) NOT NULL,
    priority        VARCHAR(10) DEFAULT 'medium',
    task_status     VARCHAR(20) DEFAULT 'pending',
    sync_source     VARCHAR(20) NOT NULL,
    trace_id        VARCHAR(64) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    CONSTRAINT uk_sync_task_task_id UNIQUE (task_id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_sync_status_entity ON sync_status(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_status_status ON sync_status(sync_status);
CREATE INDEX IF NOT EXISTS idx_sync_status_content_hash ON sync_status(content_hash);
CREATE INDEX IF NOT EXISTS idx_sync_log_entity ON sync_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_time ON sync_log(created_at);
CREATE INDEX IF NOT EXISTS idx_sync_log_status ON sync_log(status);
CREATE INDEX IF NOT EXISTS idx_sync_log_task_id ON sync_log(task_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_duration ON sync_log(duration_ms);
CREATE INDEX IF NOT EXISTS idx_sync_conflict_entity ON sync_conflict(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_conflict_status ON sync_conflict(conflict_status);
CREATE INDEX IF NOT EXISTS idx_sync_task_status ON sync_task(task_status);
CREATE INDEX IF NOT EXISTS idx_sync_task_entity ON sync_task(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_sync_task_created ON sync_task(created_at);
```

---

# **6. 安全性与可靠性**

## **6.1 安全性**

1. **权限控制**: 所有同步操作受 RBAC 权限保护（sync:read / sync:write）
2. **审计日志**: 记录所有同步操作的操作者ID、同步源、触发方式
3. **敏感信息脱敏**: 日志中不记录敏感字段（如 API Key、Token），脱敏后记录
4. **文件权限**: 限制文件读写权限，防止未授权访问
5. **API 认证**: 同步 API 必须认证鉴权，未授权请求返回 401

## **6.2 可靠性**

1. **重试机制**: 同步失败自动重试，最多 3 次，指数退避（1s, 2s, 4s）
2. **异步执行**: 同步操作异步执行，不阻塞主线程
3. **故障恢复**: 应用重启后从 sync_task 表自动恢复未完成的同步任务
4. **状态持久化**: 同步状态持久化到数据库，支持断点续传
5. **幂等性保证**: 同步任务携带唯一 task_id，重复提交返回已有结果
6. **数据最终一致性 SLA**: 同步触发后，目标侧数据在 10 秒内（P99）与源侧一致
7. **循环同步防护**: 同步源标记 + 熔断机制，同一实体 10 秒内超过 3 次双向同步时熔断

## **6.3 循环同步防护**

| 防护层级 | 机制 | 说明 |
|----------|------|------|
| **第一层** | SyncContext 标记 | 同步系统触发的变更携带 SyncSystem 标记，AOP 切面检查后跳过 |
| **第二层** | 触发链路追踪 | SyncContext.triggerChain 记录同步触发链路，检测循环 |
| **第三层** | 熔断机制 | CircularCounter 统计窗口内同步次数，超过阈值（3次/10秒）触发熔断 |
| **第四层** | 熔断恢复 | 熔断持续 60 秒后自动恢复，或通过 API 手动恢复 |

## **6.4 AOP 拦截范围限定**

| 限定机制 | 规则 | 说明 |
|----------|------|------|
| **包路径包含** | `magic.app.dao.uctoo.*` | 仅拦截业务实体 DAO 包 |
| **包路径排除** | `magic.app.dao.sync.*` | 排除同步系统自身 DAO 包 |
| **实体类型白名单** | `{agent, agent_skill, skill}` | 仅拦截白名单内的实体类型 |
| **同步上下文检查** | `SyncContext.isPresent()` | 携带同步源标记的操作跳过拦截 |

---

# **7. 可观测性设计**

## **7.1 Metrics 指标**

| 指标名称 | 类型 | 说明 |
|----------|------|------|
| sync_requests_total | Counter | 同步请求总数（按实体类型、方向、结果分类） |
| sync_success_rate | Gauge | 同步成功率 |
| sync_latency_p50/p95/p99 | Histogram | 同步延迟分布 |
| sync_conflict_rate | Gauge | 冲突率 |
| sync_queue_depth | Gauge | 同步队列当前深度 |
| sync_queue_capacity | Gauge | 同步队列容量上限 |
| sync_rate_limit_rejected | Counter | 限流拒绝数 |
| sync_circuit_breaker_count | Gauge | 熔断实体数 |
| sync_debounce_merge_rate | Gauge | 防抖合并率 |

## **7.2 分布式 Tracing**

- 每个同步任务生成唯一 TraceID（存储在 SyncContext.traceId）
- Span 链路：变更检测 → 同步管理器 → 数据映射 → 目标写入 → 状态更新
- TraceID 传递到同步源标记中，关联双向同步链路
- Tracing 采样率可配置（默认 10%），错误链路 100% 采样

## **7.3 健康检查**

- 端点：`GET /api/v1/uctoo/sync/health`
- 返回信息：
  - `status`: 正常 / 降级 / 熔断
  - `queueDepth`: 当前队列深度
  - `queueCapacity`: 队列容量
  - `recentFailCount1m`: 最近 1 分钟失败数
  - `circuitBreakerCount`: 熔断实体数
  - `lastSuccessfulSyncAt`: 最后成功同步时间

## **7.4 告警规则**

| 告警条件 | 告警级别 | 说明 |
|----------|----------|------|
| 同步失败率 > 5% 持续 1 分钟 | WARNING | 同步质量下降 |
| 冲突率 > 10% | WARNING | 冲突频繁，需关注 |
| 队列深度 > 80% 上限 | WARNING | 同步队列过载 |
| 熔断实体数 > 0 | INFO | 存在循环同步防护 |
| 冲突超过 24 小时未解决 | CRITICAL | 冲突长期未解决 |

---

# **8. 领域事件设计**

## **8.1 事件清单**

| 事件名称 | 触发条件 | 事件载荷 |
|----------|----------|----------|
| **SyncCompleted** | 同步操作成功完成 | entityType, entityId, direction, taskId, traceId, durationMs |
| **SyncFailed** | 同步操作失败（重试耗尽） | entityType, entityId, direction, taskId, traceId, errorCode, errorMessage, retryCount |
| **ConflictDetected** | 检测到同步冲突 | entityType, entityId, conflictId, oursVersion, theirsVersion, baseVersion |
| **ConflictResolved** | 冲突被解决 | entityType, entityId, conflictId, resolutionStrategy, resolvedVersion |
| **SyncCircuitBreakerTriggered** | 实体同步被熔断 | entityType, entityId, triggerCount, windowSeconds |
| **SyncCircuitBreakerRecovered** | 熔断恢复 | entityType, entityId, recoveryType |
| **SyncBackpressureTriggered** | 背压策略触发 | queueDepth, queueCapacity, strategy |
| **SyncTaskCancelled** | 同步任务被取消 | taskId, entityType, entityId, reason |

## **8.2 事件约束**

1. 所有领域事件必须包含事件ID、事件时间戳、事件源（sync-system）
2. 事件必须按发生顺序发布，同一实体的事件顺序必须与操作顺序一致
3. 事件发布失败不得影响同步操作本身，事件必须持久化后异步发布
4. 事件载荷中的敏感字段必须脱敏

---

# **9. 性能优化**

## **9.1 批量同步优化**

1. **批量数据库操作**: 使用批量 INSERT/UPDATE 减少数据库连接开销
2. **并行同步**: 使用线程池并行处理多个实体的同步
3. **增量同步**: 仅同步发生变更的文件，避免全量扫描
4. **拓扑排序并行化**: 无依赖关系的实体类型可并行同步

## **9.2 缓存策略**

1. **状态缓存**: 缓存同步状态，减少数据库查询
2. **文件缓存**: 缓存最近访问的文件内容，减少磁盘 IO
3. **变更检测优化**: 使用文件系统事件监听替代定时全量扫描
4. **哈希缓存**: 缓存已计算的文件哈希值，避免重复计算

## **9.3 防抖与节流**

1. **防抖窗口**: 500ms 内同一实体的多次变更合并为一次同步
2. **节流限流**: 100 QPS 上限控制同步触发速率
3. **批量合并**: 防抖窗口内多个不同实体的变更合并为一次批量同步

---

# **10. 测试计划**

## **10.1 单元测试**

| 测试模块 | 测试内容 | 预期结果 |
|----------|----------|----------|
| SyncManager | 注册处理器、触发同步、拓扑排序、幂等性去重 | 正确注册、触发、排序和去重 |
| SyncContext | ThreadLocal 标记、循环检测 | 正确标记和检测循环 |
| ChangeDetector | hash/timestamp/hybrid 三种策略 | 正确检测变更 |
| DebounceWindow | 防抖合并、批量合并 | 窗口内变更合并为一次 |
| ContentHasher | SHA-256 计算、哈希比对 | 正确计算和比对 |
| VersionVector | 冲突检测、基线更新 | 正确检测并发冲突 |
| ThreeWayMerge | 自动合并、重叠修改检测 | 正确合并或标记冲突 |
| ConflictResolver | 版本向量冲突检测、策略选择 | 正确检测和解决冲突 |
| RateLimiter | 令牌桶/滑动窗口限流 | 正确限流 |
| CircuitBreakerManager | 循环检测、熔断触发/恢复 | 正确熔断和恢复 |
| PrioritySyncQueue | 优先级调度、背压 | 正确调度和背压处理 |
| DataMapper | 文件解析、序列化、版本兼容 | 正确转换格式 |
| SyncEventPublisher | 事件发布 | 正确发布领域事件 |

## **10.2 集成测试**

| 测试场景 | 测试内容 | 预期结果 |
|----------|----------|----------|
| 文件→数据库同步 | 创建/修改/删除文件，验证数据库变更 | 数据库记录同步更新 |
| 数据库→文件同步 | 创建/修改/删除数据库记录，验证文件变更 | 文件同步更新 |
| 循环同步防护 | 同步系统写入数据库，验证AOP不触发反向同步 | 无循环同步 |
| 熔断机制 | 同一实体短时多次双向同步，验证熔断触发 | 熔断后仅记录变更 |
| 冲突处理 | 并发修改文件和数据库，验证版本向量检测 | 正确检测并解决冲突 |
| 批量同步 | 同步大量实体，验证拓扑排序 | 在规定时间内完成，依赖顺序正确 |
| 幂等性 | 重复提交同一任务ID，验证去重 | 返回相同结果，不重复执行 |
| 背压 | 队列满时提交同步请求，验证背压策略 | 按策略降级/延迟/拒绝 |
| 启动同步 | 应用启动，验证异步全量同步不阻塞 | 启动不阻塞，同步后台执行 |

## **10.3 性能测试**

| 测试指标 | 目标值 |
|----------|--------|
| 单条记录同步耗时 | ≤ 100ms (P99) |
| 批量同步 100 条记录 | ≤ 5 秒 (P99) |
| 批量同步 1000 条记录 | ≤ 30 秒 (P99) |
| 同步队列吞吐量 | ≥ 100 条/秒 |
| 数据最终一致性延迟 | ≤ 10 秒 (P99) |

---

# **11. 基础设施复用**

## **11.1 f_aspect 框架复用（核心）**

### **11.1.1 f_aspect 框架核心能力**

| 组件 | 说明 | 复用价值 |
|------|------|----------|
| **Aspect 接口** | 定义切面契约，包含 before/after/around/throwing/final 五个生命周期方法 | 实现数据库操作拦截 |
| **@AspectRoute 注解** | 修饰切面实现类，定义切点规则 | 声明式配置拦截规则 |
| **RouteRule 体系** | 支持多种匹配规则（包名、方法名、参数、注解等） | 灵活定义拦截范围 |
| **@Pointcut 宏** | 编译期织入切面代码 | 无侵入式拦截 |
| **Aspects 工具类** | 切面执行协调器，支持递归调用保护 | 统一管理切面执行 |

### **11.1.2 切点规则配置**

同步系统使用以下切点规则（含排除规则）：

```cangjie
// 拦截业务实体 DAO 层 CRUD 操作，排除同步系统自身 DAO
@AspectRoute(ExecutionRouteRule(
    within = WithinRouteRule("magic.app.dao.uctoo.*") & !WithinRouteRule("magic.app.dao.sync.*"),
    funcType = FuncNameRouteRule("insert*|update*|delete*") & ArgsRouteRule("**") & ReturnTypeRouteRule("*")
))
```

**规则说明**:
- **WithinRouteRule("magic.app.dao.uctoo.*")**: 匹配业务实体 DAO 包下所有类
- **!WithinRouteRule("magic.app.dao.sync.*")**: 排除同步系统自身 DAO 包
- **FuncNameRouteRule("insert*|update*|delete*")**: 匹配方法名以 insert、update、delete 开头的方法
- **ArgsRouteRule("**")**: 匹配任意参数
- **ReturnTypeRouteRule("*")**: 匹配任意返回类型

### **11.1.3 切面执行流程**

```
数据库操作调用
    │
    ▼
┌───────────────────────────────────────┐
│      @Pointcut 宏织入                  │  ← 编译期自动生成
│  Aspects.proceed() 调用               │
└───────────────────────────────────────┘
    │
    ▼
┌───────────────────────────────────────┐
│      Aspects.doProceed()              │  ← 运行时切面匹配
│  1. 查找匹配的切面                     │
│  2. 构建切面链                        │
│  3. 按顺序执行切面                     │
└───────────────────────────────────────┘
    │
    ▼
┌───────────────────────────────────────┐
│    SyncInterceptor.after()            │  ← 本系统自定义切面
│  1. 检查 SyncContext.isPresent()      │  ← 循环同步防护
│  2. 检查实体类型白名单                  │  ← 拦截范围限定
│  3. 获取实体类型和ID                    │
│  4. 异步触发文件同步                    │
└───────────────────────────────────────┘
```

## **11.2 计划任务模块复用**

| 组件/模式 | 来源模块 | 复用价值 | 复用方式 |
|-----------|----------|----------|----------|
| **RetryManager** | crontab_sched | 同步失败自动重试（指数退避） | 直接复用实现逻辑 |
| **AsyncLogWriter** | crontab_sched | 异步日志写入 | 直接复用异步队列机制 |
| **优雅关闭机制** | crontab_sched | 等待运行中任务完成 | 复用 gracefulShutdown 模式 |
| **并发控制** | crontab_sched | 运行中任务追踪 | 复用 ConcurrentHashMap 管理 |
| **单例模式** | crontab_sched | 全局唯一实例 | 复用 AtomicOptionReference 模式 |
| **执行器注册表** | crontab_sched | 动态注册处理器 | 复用 ConcurrentHashMap 注册表模式 |

## **11.3 复用收益**

| 收益类型 | 说明 |
|----------|------|
| **代码复用** | 减少重复代码，降低维护成本 |
| **一致性** | 保持系统行为一致（重试策略、日志写入等） |
| **稳定性** | 复用经过验证的成熟组件 |
| **开发效率** | 节省开发时间，专注业务逻辑 |

---

**文档维护者**: UCToo Team  
**最后更新**: 2026-06-02
