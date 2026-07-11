# 文件系统与数据库双向同步系统设计文档（MVP）

## 文档信息
- **项目名称**: agentskills-runtime 文件系统与数据库同步系统（MVP）
- **版本**: v1.0.0-mvp
- **创建日期**: 2026-06-03
- **最后更新**: 2026-06-03
- **作者**: spec-design-agent
- **状态**: 待实现
- **关联需求**: spec.md v1.0.0-mvp
- **目录规范**: `.codeartsdoer/specs/filesystem-database-sync-mvp/design.md`

---

# **1. 实现模型**

## **1.1 上下文视图**

### 系统上下文图

```
┌───────────────────────────────────────────────────────────────────────────┐
│                  文件系统与数据库双向同步系统 v1.0.0-mvp                   │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                      同步管理器 (SyncManager)                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐ │  │
│  │  │ 变更检测器   │  │ AOP拦截器    │  │   冲突解决器              │ │  │
│  │  │ChangeDetector│  │SyncInterceptor│ │ ConflictResolver(LWW)    │ │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────────┘ │  │
│  │         │                 │                      │                  │  │
│  │  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────────▼───────────────┐ │  │
│  │  │ 数据映射器   │  │ 同步处理器   │  │   同步状态管理器          │ │  │
│  │  │ DataMapper   │  │ SyncHandler  │  │   SyncStatusManager      │ │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────────────────────────┘ │  │
│  │         │                 │                                          │  │
│  │  ┌──────▼─────────────────▼──────────────────────────────────────┐ │  │
│  │  │                    同步引擎基础设施层                          │ │  │
│  │  │  ┌──────────┐ ┌──────────────┐ ┌──────────────┐             │ │  │
│  │  │  │SyncContext│ │TopologySorter│ │ RetryManager │             │ │  │
│  │  │  └──────────┘ └──────────────┘ └──────────────┘             │ │  │
│  │  └──────────────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│            │                 │                                            │
│            ▼                 ▼                                            │
│  ┌────────────────┐  ┌────────────────────────┐                          │
│  │   文件系统     │  │         数据库          │                          │
│  │  (Markdown     │  │   (PostgreSQL/ORM)     │                          │
│  │   Frontmatter) │  │                        │                          │
│  └────────────────┘  └────────────────────────┘                          │
└───────────────────────────────────────────────────────────────────────────┘
```

### 核心参与者

| 参与者 | 角色 | 交互方式 |
|--------|------|----------|
| **同步管理器** | 核心协调器，管理同步任务、拓扑排序、upsert 幂等性保证 | 内部 API 调用 |
| **变更检测器** | 基于文件修改时间戳检测文件变更 | 定时扫描 |
| **AOP拦截器** | 拦截业务实体 DAO 操作，携带同步上下文检查，触发文件同步 | 切面织入（f_aspect） |
| **数据映射器** | Markdown Frontmatter 与实体对象的双向转换 | 解析/序列化 |
| **冲突解决器** | Last-Write-Wins 策略，基于时间戳比较 | 时间戳比对 |
| **同步处理器** | 执行具体的同步逻辑，声明实体依赖关系 | 实体类型注册 |
| **同步上下文** | ThreadLocal 同步上下文，携带同步源标记，用于循环同步防护 | 线程本地变量 |
| **文件系统** | 存储 Agent/AgentSkill 的 Markdown 定义文件 | 文件读写 |
| **数据库** | 存储结构化元数据 | ORM 操作 |

## **1.2 服务/组件总体架构**

### 架构分层图

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     接入层 (Entry Layer)                                  │
│  ┌──────────────────┐  ┌──────────────────┐                             │
│  │ SyncController   │  │ SyncLogController│                             │
│  └────────┬─────────┘  └────────┬─────────┘                             │
├───────────┼──────────────────────┼───────────────────────────────────────┤
│           │        服务层 (Service Layer)                                 │
│  ┌────────┴─────────┐  ┌────────┴─────────┐                             │
│  │   SyncService    │  │ SyncLogService   │                             │
│  │  (同步编排)      │  │  (日志管理)      │                             │
│  └────────┬─────────┘  └────────┬─────────┘                             │
├───────────┼──────────────────────┼───────────────────────────────────────┤
│           │        同步引擎层 (Sync Engine)                                │
│  ┌────────┴────────────────────────────────────────────┴─────────┐       │
│  │                    SyncManager (核心协调器)                     │       │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐    │       │
│  │  │Detector  │  │Interceptor│ │Resolver  │  │Mapper     │    │       │
│  │  └──────────┘  └──────────┘  └──────────┘  └───────────┘    │       │
│  └────────────────────────┬──────────────────────────────────────┘       │
├───────────────────────────┼──────────────────────────────────────────────┤
│       处理器层 (Handler Layer)                                            │
│  ┌──────────────┐  ┌──────────────────┐                                 │
│  │AgentSyncHandler│ │AgentSkillSyncHandler│                              │
│  └──────────────┘  └──────────────────┘                                 │
├──────────────────────────────────────────────────────────────────────────┤
│       数据层 (Data Access Layer)                                          │
│  ┌──────────────┐  ┌──────────────────────────────────────┐              │
│  │ SyncLogDAO   │  │ EntityDAO (业务实体, 复用现有)       │              │
│  └──────────────┘  └──────────────────────────────────────┘              │
├──────────────────────────────────────────────────────────────────────────┤
│       基础设施层 (Infrastructure)                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐    │
│  │  f_orm   │  │LogUtils  │  │ AspectLib│  │ FileSystemUtils     │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────────┘    │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────┐                      │
│  │ f_yaml   │  │TopologySorter│  │ RetryManager │                      │
│  └──────────┘  └──────────────┘  └──────────────┘                      │
└──────────────────────────────────────────────────────────────────────────┘
```

### 数据流图

```
文件系统→数据库同步流:
  定时扫描/启动触发 ──> ChangeDetector.detectByTimestamp()
                                │
                                ├──> 比对文件修改时间 vs last_sync_at
                                │
                                ├──> [变更确认] ──> SyncContext.enter()
                                │                        │
                                │                        ├──> SyncManager.triggerSync()
                                │                        │        │
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

冲突检测与解决流 (Last-Write-Wins):
  同步触发 ──> ConflictResolver.detectByTimestamp()
                     │
                     ├── 比对文件修改时间 vs 数据库updated_at
                     │
                     ├─ 文件侧较新 ──> 以文件侧数据覆盖数据库
                     │
                     ├─ 数据库侧较新 ──> 以数据库侧数据覆盖文件
                     │
                     └─ 两侧相同 ──> 跳过同步
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
            ├── 加载同步配置（开关、扫描间隔等）
            ├── 初始化同步基础设施
            │       └── SyncContext (ThreadLocal)
            ├── 注册实体同步处理器
            │       └── AgentSyncHandler, AgentSkillSyncHandler
            ├── 注册AOP切面拦截器（实体类型白名单 + 包路径排除规则）
            │       └── AspectRegistry.register(SyncInterceptor())
            ├── 注册定时扫描任务（crontab）
            │       └── CrontabScheduler.register("sync-scan", SyncScanJob)
            └── [异步] 执行初始化全量同步（不阻塞启动）
                    └── async { syncAll(None) } with timeout=30s
```

## **1.3 实现设计文档**

### 1.3.1 SyncManager（同步管理器）

**职责**: 核心同步控制器，协调所有同步操作，负责拓扑排序、upsert 幂等性保证

**包路径**: `magic.app.services.sync`

```cangjie
package magic.app.services.sync

public class SyncManager {
    // 单例模式
    private static let instance_ = AtomicOptionReference<SyncManager>()
    
    // 注册的同步处理器
    private let handlers: ConcurrentHashMap<String, SyncHandler>
    
    // 同步日志服务
    private let logService: SyncLogService
    
    // 数据映射器
    private let dataMapper: DataMapper
    
    // 冲突解决器（Last-Write-Wins）
    private let conflictResolver: ConflictResolver
    
    // 实体依赖拓扑排序器
    private let topologySorter: TopologySorter
    
    // 重试管理器
    private let retryManager: RetryManager
    
    // === 核心方法 ===
    
    /// 初始化同步管理器
    public static func initialize(): SyncManager
    
    /// 获取单例实例
    public static prop instance: Option<SyncManager> {
        get() { instance_.load() }
    }
    
    /// 注册同步处理器
    public func registerHandler(entityType: String, handler: SyncHandler): Unit
    
    /// 触发同步（异步，携带同步上下文）
    public func triggerSync(
        entityType: String,
        entityId: String,
        direction: SyncDirection,
        triggerSource: TriggerSource
    ): Future<SyncResult>
    
    /// 批量同步所有实体（按拓扑排序执行）
    public func syncAll(entityType: String?): SyncBatchResult
    
    /// 获取同步状态概览
    public func getStatusSummary(): SyncStatusSummary
    
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
    prop entityType: String {
        get()
    }
    
    /// 获取实体基础路径
    prop basePath: String {
        get()
    }
    
    /// 文件扩展名
    prop fileExtension: String {
        get()
    }
    
    /// 实体依赖列表（拓扑排序依据）
    /// 例: agent_skill 的 dependencies = ["agent"]
    prop dependencies: Array<String> {
        get()
    }
    
    /// 从文件系统同步到数据库（upsert 语义）
    func syncFromFileSystem(sourcePath: String, context: SyncContext): SyncResult
    
    /// 从数据库同步到文件系统
    func syncToFileSystem(entityId: String, context: SyncContext): SyncResult
    
    /// 检测文件变更（基于时间戳）
    func detectChanges(): Array<FileChange>
    
    /// 构建文件路径
    func buildFilePath(sourcePath: String): String
}
```

### 1.3.3 AgentSyncHandler（Agent同步处理器）

**职责**: 处理 Agent 实体的同步逻辑

**包路径**: `magic.app.services.sync.handler`

```cangjie
package magic.app.services.sync.handler

public class AgentSyncHandler <: SyncHandler {
    override prop entityType: String {
        get() { "agent" }
    }
    override prop basePath: String {
        get() { Config.syncAgentBasePath }
    }
    override prop fileExtension: String {
        get() { ".md" }
    }
    override prop dependencies: Array<String> {
        get() { [] }  // agent 无前置依赖
    }
    
    public func syncFromFileSystem(sourcePath: String, context: SyncContext): SyncResult {
        // 1. 读取文件内容
        let filePath = buildFilePath(sourcePath)
        let content = FileSystemUtils.readFile(filePath)
        // 2. 解析为 AgentPO（向前兼容处理）
        let agent = DataMapper.parseAgent(content, sourcePath)
        // 3. 携带同步上下文执行 upsert
        SyncContext.enter(context)
        try {
            AgentDAO.upsertBySourcePath(agent)  // 以 source_path 为匹配键的 upsert
        } finally {
            SyncContext.exit()
        }
        // 4. 更新同步状态
        SyncStatusManager.updateAfterSync(entityType, agent.id, sourcePath)
        // 5. 返回结果
        return SyncResult(success: true, ...)
    }
    
    public func syncToFileSystem(entityId: String, context: SyncContext): SyncResult {
        // 1. 从数据库读取 AgentPO
        let agent = AgentDAO.selectById(entityId)
        // 2. 序列化为 Markdown Frontmatter
        let content = DataMapper.serializeAgent(agent)
        // 3. 携带同步上下文写入文件
        SyncContext.enter(context)
        try {
            FileSystemUtils.writeFile(buildFilePath(agent.sourcePath), content)
        } finally {
            SyncContext.exit()
        }
        // 4. 更新同步状态
        SyncStatusManager.updateAfterSync(entityType, entityId, agent.sourcePath)
        // 5. 返回结果
        return SyncResult(success: true, ...)
    }
    
    public func detectChanges(): Array<FileChange> {
        // 基于时间戳检测变更
        ChangeDetector.detectByTimestamp(basePath, entityType)
    }
    
    public func buildFilePath(sourcePath: String): String {
        return "${basePath}/${sourcePath}"
    }
}
```

### 1.3.4 AgentSkillSyncHandler（AgentSkill同步处理器）

**职责**: 处理 AgentSkill 实体的同步逻辑

**包路径**: `magic.app.services.sync.handler`

```cangjie
package magic.app.services.sync.handler

public class AgentSkillSyncHandler <: SyncHandler {
    override prop entityType: String {
        get() { "agent_skill" }
    }
    override prop basePath: String {
        get() { Config.syncSkillBasePath }
    }
    override prop fileExtension: String {
        get() { ".md" }
    }
    override prop dependencies: Array<String> {
        get() { ["agent"] }  // agent_skill 依赖 agent
    }
    
    public func syncFromFileSystem(sourcePath: String, context: SyncContext): SyncResult {
        // 1. 读取文件内容
        let filePath = buildFilePath(sourcePath)
        let content = FileSystemUtils.readFile(filePath)
        // 2. 解析为 AgentSkillPO（向前兼容处理）
        let skill = DataMapper.parseAgentSkill(content, sourcePath)
        // 3. 检查依赖：agent 是否已存在
        if (!AgentDAO.existsById(skill.agentId)) {
            // 标记为 dependency_missing，待依赖满足后重试
            SyncStatusManager.updateStatus(entityType, skill.id, SyncStatus.DependencyMissing)
            return SyncResult(success: false, status: SyncStatus.DependencyMissing, ...)
        }
        // 4. 携带同步上下文执行 upsert
        SyncContext.enter(context)
        try {
            AgentSkillDAO.upsertBySourcePath(skill)  // 以 source_path 为匹配键的 upsert
        } finally {
            SyncContext.exit()
        }
        // 5. 更新同步状态
        SyncStatusManager.updateAfterSync(entityType, skill.id, sourcePath)
        // 6. 返回结果
        return SyncResult(success: true, ...)
    }
    
    public func syncToFileSystem(entityId: String, context: SyncContext): SyncResult {
        // 1. 从数据库读取 AgentSkillPO
        let skill = AgentSkillDAO.selectById(entityId)
        // 2. 序列化为 Markdown Frontmatter
        let content = DataMapper.serializeAgentSkill(skill)
        // 3. 携带同步上下文写入文件
        SyncContext.enter(context)
        try {
            FileSystemUtils.writeFile(buildFilePath(skill.sourcePath), content)
        } finally {
            SyncContext.exit()
        }
        // 4. 更新同步状态
        SyncStatusManager.updateAfterSync(entityType, entityId, skill.sourcePath)
        // 5. 返回结果
        return SyncResult(success: true, ...)
    }
    
    public func detectChanges(): Array<FileChange> {
        ChangeDetector.detectByTimestamp(basePath, entityType)
    }
    
    public func buildFilePath(sourcePath: String): String {
        return "${basePath}/${sourcePath}"
    }
}
```

### 1.3.5 SyncContext（同步上下文）

**职责**: ThreadLocal 同步上下文，携带同步源标记，用于循环同步防护

**包路径**: `magic.app.services.sync.context`

```cangjie
package magic.app.services.sync.context

public class SyncContext {
    // ThreadLocal 存储
    private static let threadLocal: ThreadLocal<Option<SyncContext>>
    
    // 同步触发源
    public let triggerSource: TriggerSource
    
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
        threadLocal.set(None)
    }
    
    // 检查当前是否处于同步上下文中
    public static func isPresent(): Bool {
        match (threadLocal.get()) {
            case Some(_) => true
            case None => false
        }
    }
    
    // 获取当前同步上下文
    public static func current(): Option<SyncContext> {
        threadLocal.get()
    }
}

/// 同步触发源
public enum TriggerSource {
    | Business        // 业务操作触发
    | SyncSystem      // 同步系统自身触发（携带此标记的变更不触发反向同步）
    | Manual          // 手动触发（API）
    | Startup         // 启动初始化触发
}
```

### 1.3.6 ChangeDetector（变更检测器）

**职责**: 基于文件修改时间戳检测文件系统变更

**包路径**: `magic.app.services.sync.detector`

```cangjie
package magic.app.services.sync.detector

public class ChangeDetector {
    /// 基于时间戳检测变更
    /// 比对文件最后修改时间与数据库记录的 last_sync_at
    public static func detectByTimestamp(path: String, entityType: String): Array<FileChange> {
        // 1. 扫描目录获取文件列表及修改时间戳
        // 2. 查询数据库中该实体类型的 last_sync_at
        // 3. 比对：文件修改时间 > last_sync_at 则判定为变更
        // 4. 返回变更列表
    }
    
    /// 定时扫描入口（由 crontab 调度）
    public static func periodicScan(): Unit {
        // 1. 对每种注册的实体类型执行 detectByTimestamp
        // 2. 将检测到的变更合并为批量同步请求
        // 3. 按拓扑排序提交给 SyncManager
    }
}

/// 文件变更信息
public class FileChange {
    public var path: String              // 文件路径
    public var sourcePath: String        // 相对路径（source_path）
    public var changeType: ChangeType    // 变更类型: created, modified, deleted
    public var lastModified: DateTime    // 最后修改时间
    public var entityType: String        // 实体类型
}

/// 变更类型
public enum ChangeType {
    | Created
    | Modified
    | Deleted
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
@AspectRoute[ExecutionRouteRule(
    within = WithinRouteRule("magic.app.dao.uctoo.*") & !WithinRouteRule("magic.app.dao.sync.*"),
    funcType = FuncNameRouteRule("insert*|update*|delete*") & ArgsRouteRule("**") & ReturnTypeRouteRule("*")
)]
public class SyncInterceptor <: Aspect {
    // 实体类型白名单（仅拦截白名单内的实体类型）
    private let entityTypeWhitelist: HashSet<String> = HashSet(["agent", "agent_skill"])
    
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
        if (let Some(entity) <- funcInfo.args.first) {
            // === 拦截范围限定：实体类型白名单检查 ===
            let entityType = extractEntityType(funcInfo)
            if (!entityTypeWhitelist.contains(entityType)) {
                return result  // 非白名单实体类型，跳过拦截
            }
            
            let entityId = extractEntityId(entity)
            if (!entityId.isEmpty) {
                // 异步触发文件同步，不阻塞主线程
                spawn {
                    try {
                        // 构建同步上下文（标记为同步系统触发）
                        let context = SyncContext(
                            triggerSource: TriggerSource.SyncSystem,
                            direction: SyncDirection.DBToFileSystem,
                            entityType: entityType,
                            entityId: entityId
                        )
                        
                        SyncManager.instance?.triggerSync(
                            entityType,
                            entityId,
                            SyncDirection.DBToFileSystem,
                            TriggerSource.SyncSystem
                        )
                    } catch (e: Exception) {
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
        className.replace("DAO", "").toLowerCase()
    }
    
    /**
     * 从实体对象中提取实体ID
     * 注：实际实现需根据具体 PO 类型判断，此处为伪代码示意
     */
    private func extractEntityId(entity: Any): String {
        // 实际实现中根据反射或类型转换提取 id 字段
        // 此处为伪代码，示意逻辑
        ""
    }
}
```

### 1.3.8 ConflictResolver（冲突解决器）

**职责**: 基于 Last-Write-Wins 策略检测和解决并发修改冲突

**包路径**: `magic.app.services.sync.resolver`

```cangjie
package magic.app.services.sync.resolver

public class ConflictResolver {
    /// 基于时间戳检测冲突
    /// 冲突条件：文件修改时间 > last_sync_at && 数据库updated_at > last_sync_at
    public static func detectByTimestamp(
        fileModifiedAt: DateTime,
        dbUpdatedAt: DateTime,
        lastSyncAt: Option<DateTime>
    ): Option<ConflictResult> {
        match lastSyncAt {
            case Some(syncAt) =>
                // 两侧均晚于上次同步时间，判定为并发冲突
                if (fileModifiedAt > syncAt && dbUpdatedAt > syncAt) {
                    Some(resolveByTimestamp(fileModifiedAt, dbUpdatedAt))
                } else {
                    None  // 无冲突
                }
            case None =>
                None  // 首次同步，无冲突
        }
    }
    
    /// Last-Write-Wins 解决策略
    private static func resolveByTimestamp(
        fileModifiedAt: DateTime,
        dbUpdatedAt: DateTime
    ): ConflictResult {
        if (fileModifiedAt > dbUpdatedAt) {
            ConflictResult(winner: SyncWinner.FileSystem, message: "文件侧较新，以文件覆盖数据库")
        } else if (dbUpdatedAt > fileModifiedAt) {
            ConflictResult(winner: SyncWinner.Database, message: "数据库侧较新，以数据库覆盖文件")
        } else {
            ConflictResult(winner: SyncWinner.NoChange, message: "两侧时间戳相同，跳过同步")
        }
    }
}

/// 冲突解决结果
public class ConflictResult {
    public var winner: SyncWinner
    public var message: String
}

/// 冲突胜出方
public enum SyncWinner {
    | FileSystem    // 文件侧胜出
    | Database      // 数据库侧胜出
    | NoChange      // 无需同步
}
```

### 1.3.9 DataMapper（数据映射器）

**职责**: Markdown Frontmatter 与实体对象的双向转换，维护映射版本兼容

**包路径**: `magic.app.services.sync.mapper`

```cangjie
package magic.app.services.sync.mapper

public class DataMapper {
    /// 解析 Agent Markdown 文件（向前兼容处理）
    public func parseAgent(content: String, sourcePath: String): AgentPO {
        // 1. 提取 YAML frontmatter
        // 2. 解析 frontmatter 字段到 AgentPO
        // 3. Markdown 正文部分作为 systemPrompt
        // 4. 设置 sourcePath
        // 5. 宽容模式下缺失字段使用默认值
    }
    
    /// 序列化 AgentPO 为 Markdown Frontmatter
    public func serializeAgent(agent: AgentPO): String {
        // 1. 构建 YAML frontmatter（name, type, description, model, tools 等）
        // 2. systemPrompt 作为 Markdown 正文
        // 3. 返回完整 Markdown 内容
    }
    
    /// 解析 AgentSkill Markdown 文件
    public func parseAgentSkill(content: String, sourcePath: String): AgentSkillPO {
        // 1. 提取 YAML frontmatter
        // 2. 解析字段到 AgentSkillPO
        // 3. 设置 sourcePath
        // 4. 宽容模式下缺失字段使用默认值
    }
    
    /// 序列化 AgentSkillPO 为 Markdown Frontmatter
    public func serializeAgentSkill(skill: AgentSkillPO): String {
        // 1. 构建 YAML frontmatter
        // 2. instructions 作为 Markdown 正文
        // 3. 返回完整 Markdown 内容
    }
    
    /// 提取 Markdown Frontmatter
    public func extractFrontmatter(content: String): JsonValue
    
    /// 构建 Markdown Frontmatter
    public func buildFrontmatter(data: JsonValue): String
    
    /// 当前映射版本号
    public static let CURRENT_VERSION: Int32 = 1
}
```

### 1.3.10 SyncStatusManager（同步状态管理器）

**职责**: 管理和维护同步状态，通过实体表的 sync_status 和 last_sync_at 字段持久化

**包路径**: `magic.app.services.sync.status`

```cangjie
package magic.app.services.sync.status

public class SyncStatusManager {
    /// 更新同步状态（直接更新实体表字段）
    public func updateStatus(
        entityType: String, entityId: String, status: SyncStatus, message: String?
    ): Unit
    
    /// 同步完成后更新状态（设置 synced + last_sync_at）
    public func updateAfterSync(
        entityType: String, entityId: String, sourcePath: String
    ): Unit
    
    /// 获取同步状态概览
    public func getStatusSummary(): SyncStatusSummary
    
    /// 获取指定类型实体的同步状态（分页）
    public func listStatus(
        entityType: String?, syncStatus: String?, page: Int32, pageSize: Int32
    ): Pagination<SyncEntityStatus>
}

/// 同步状态摘要
public class SyncStatusSummary {
    public var totalEntities: Int32
    public var syncedCount: Int32
    public var pendingCount: Int32
    public var failedCount: Int32
    public var dependencyMissingCount: Int32
    public var lastSyncAt: Option<DateTime>
}

/// 实体同步状态
public class SyncEntityStatus {
    public var entityType: String
    public var entityId: String
    public var sourcePath: String
    public var syncStatus: String
    public var lastSyncAt: Option<DateTime>
    public var errorMessage: Option<String>
}
```

### 1.3.11 TopologySorter（拓扑排序器）

**职责**: 实体依赖拓扑排序，确保被依赖实体先同步

**包路径**: `magic.app.services.sync.infrastructure`

```cangjie
package magic.app.services.sync.infrastructure

public class TopologySorter {
    /// 对实体类型列表按依赖关系拓扑排序
    /// 依赖关系：agent_skill 依赖 agent
    /// 排序结果：agent → agent_skill
    public static func sort(handlers: Array<SyncHandler>): Array<SyncHandler>
    
    /// 检测循环依赖
    public static func detectCircularDependency(handlers: Array<SyncHandler>): Option<Array<String>>
}
```

### 1.3.12 RetryManager（重试管理器）

**职责**: 同步失败时自动重试，采用指数退避策略（1s, 2s, 4s）

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
        let baseMs: Int64 = 1000
        baseMs * (1 << attempt)
    }
    
    /// 获取最大重试次数（默认 3 次）
    public prop maxRetries: Int32 {
        get() { 3 }
    }
}
```

### 1.3.13 关键数据类型

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
    | Synced              // 已同步
    | Error               // 同步失败
    | DependencyMissing   // 依赖缺失
}

/// 同步结果
public class SyncResult {
    public var success: Bool
    public var entityType: String
    public var entityId: String
    public var status: SyncStatus
    public var message: String
    public var errorDetail: Option<String>
    public var durationMs: Int64        // 同步耗时（毫秒）
    public var timestamp: DateTime
}

/// 批量同步结果
public class SyncBatchResult {
    public var totalCount: Int32
    public var successCount: Int32
    public var failedCount: Int32
    public var details: Array<SyncResult>
}
```

---

# **2. 接口设计**

## **2.1 总体设计**

1. 遵循 UCTOO V4 RESTful 规范，路由前缀 `/api/v1/uctoo/sync/`
2. 所有接口受 JWT 认证 + RBAC 权限保护（sync:read / sync:write）
3. 响应格式遵循 UMI 全栈模型同构规范
4. 支持异步同步，返回任务信息用于后续查询
5. 支持分页参数（page, pageSize）和过滤参数（sync_status, entity_type）

## **2.2 接口清单**

### 同步管理 API

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/uctoo/sync/entities/:type/:id` | 手动触发单个实体同步 | sync:write |
| POST | `/api/v1/uctoo/sync/entities/:type/batch` | 批量同步指定类型的实体 | sync:write |
| POST | `/api/v1/uctoo/sync/batch` | 批量同步所有实体 | sync:write |

### 同步状态查询 API

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/uctoo/sync/status` | 获取同步状态概览 | sync:read |
| GET | `/api/v1/uctoo/sync/entities` | 获取所有实体的同步状态（分页） | sync:read |
| GET | `/api/v1/uctoo/sync/entities/:type` | 获取指定类型实体的同步状态（分页） | sync:read |
| GET | `/api/v1/uctoo/sync/entities/:type/:id` | 获取单个实体的同步状态 | sync:read |
| GET | `/api/v1/uctoo/sync/logs` | 查询同步日志（分页） | sync:read |
| GET | `/api/v1/uctoo/sync/health` | 同步系统健康检查 | sync:read |

### 请求/响应示例

**手动触发同步**

请求:
```json
POST /api/v1/uctoo/sync/entities/agent/agent-123
{
  "direction": "bidirectional"
}
```

响应:
```json
{
  "entityType": "agent",
  "entityId": "agent-123",
  "status": "pending",
  "message": "同步任务已提交",
  "timestamp": "2026-06-03T10:30:00Z"
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
  "totalEntities": 50,
  "syncedCount": 45,
  "pendingCount": 3,
  "failedCount": 2,
  "dependencyMissingCount": 0,
  "lastSyncAt": "2026-06-03T10:25:00Z"
}
```

**实体同步状态列表（分页）**

请求:
```json
GET /api/v1/uctoo/sync/entities?page=1&pageSize=20&sync_status=error&entity_type=agent
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
      "sourcePath": "agents/analyzer.md",
      "syncStatus": "error",
      "lastSyncAt": "2026-06-03T10:20:00Z",
      "errorMessage": "文件格式错误: 第3行YAML语法无效"
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
  "lastSuccessfulSyncAt": "2026-06-03T10:29:00Z"
}
```

---

# **3. 集成设计**

## **3.1 与 AgentManager 集成**

### 集成架构

```
AgentManager (现有)
    │
    ├── AgentLoader: 加载 AGENTS.md 和目录下的 agent 定义文件
    │       └── [新增] 加载完成后触发 SyncManager.triggerSync()
    │
    ├── AgentFactory: 根据定义创建 Agent 实例
    │       └── [新增] 创建实例后触发 fs_to_db 同步
    │
    └── AgentLifecycleManager: 管理 Agent 生命周期状态
            └── [不变] 生命周期操作不触发同步
```

### 集成流程

```
应用启动时:
  1. AgentManager.initialize()  (现有)
  2. SyncManager.initialize()   (新增)
  3. AgentLoader 加载文件 → AgentFactory 创建实例
  4. [异步] SyncManager.syncAll()  (新增，不阻塞启动)
```

## **3.2 与 f_aspect 集成**

### 切面注册

```cangjie
// 在 Application.init() 中注册
AspectRegistry.register(SyncInterceptor())
```

### AOP 拦截范围限定

| 限定机制 | 规则 | 说明 |
|----------|------|------|
| **包路径包含** | `magic.app.dao.uctoo.*` | 仅拦截业务实体 DAO 包 |
| **包路径排除** | `magic.app.dao.sync.*` | 排除同步系统自身 DAO 包 |
| **实体类型白名单** | `{agent, agent_skill}` | 仅拦截白名单内的实体类型 |
| **同步上下文检查** | `SyncContext.isPresent()` | 携带同步源标记的操作跳过拦截 |

## **3.3 与 crontab 集成**

### 定时任务注册

```cangjie
// 注册定时扫描任务
CrontabScheduler.register(
    name: "sync-periodic-scan",
    expression: Config.syncScanCron,  // 默认每60秒: "0 * * * * *"
    handler: SyncScanJob()
)
```

### SyncScanJob 定义

```cangjie
package magic.app.services.sync.job

public class SyncScanJob <: CronJob {
    public func execute(): Unit {
        // 1. 检查同步功能开关
        if (!Config.syncEnabled) { return }
        // 2. 执行变更检测
        ChangeDetector.periodicScan()
    }
}
```

## **3.4 配置项**

**文件**: `.env` 或配置文件

```ini
# === 同步功能开关 ===
SYNC_ENABLED=true

# === 变更检测 ===
# 文件扫描间隔（秒），最小 10 秒
SYNC_SCAN_INTERVAL=60

# === 重试 ===
# 最大重试次数
SYNC_MAX_RETRIES=3

# === 启动同步 ===
# 启动全量同步超时（秒），超时后应用正常启动
SYNC_STARTUP_TIMEOUT=30

# === 文件路径 ===
# Agent 基础路径
SYNC_AGENT_BASE_PATH=./
# AgentSkill 基础路径
SYNC_SKILL_BASE_PATH=./.codeartsdoer/skills

# === 数据映射 ===
# 映射模式: strict, lenient
SYNC_MAPPING_MODE=lenient

# === 日志 ===
# 日志保留天数
SYNC_LOG_RETENTION_DAYS=30
```

## **3.5 路由注册**

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
        router.post("/api/v1/uctoo/sync/entities/:type/batch", controller.syncBatch)
        router.post("/api/v1/uctoo/sync/batch", controller.syncAll)
        
        // 日志管理
        router.get("/api/v1/uctoo/sync/logs", controller.listLogs)
        
        // 健康检查
        router.get("/api/v1/uctoo/sync/health", controller.healthCheck)
    }
}
```

---

# **4. 数据模型**

## **4.1 设计目标**

1. 同步状态通过实体表自身字段（sync_status, last_sync_at）持久化，MVP 不引入独立的 sync_status 表
2. 同步日志独立表，记录同步操作详情
3. source_path 作为文件实体的首要唯一标识（upsert 匹配键）
4. 兼容现有 agents 和 agent_skills 表结构

## **4.2 模型实现**

### 4.2.1 agents 表新增字段 DDL

```sql
-- ============================================================
-- 文件系统与数据库双向同步 MVP - agents 表新增字段
-- ============================================================

ALTER TABLE agents ADD COLUMN IF NOT EXISTS source_path VARCHAR(512);
ALTER TABLE agents ADD COLUMN IF NOT EXISTS sync_status VARCHAR(32) DEFAULT 'pending';
ALTER TABLE agents ADD COLUMN IF NOT EXISTS last_sync_at TIMESTAMPTZ;

-- source_path 唯一索引（仅非空值唯一）
CREATE UNIQUE INDEX IF NOT EXISTS uk_agents_source_path 
    ON agents(source_path) WHERE source_path IS NOT NULL;

-- 同步状态索引
CREATE INDEX IF NOT EXISTS idx_agents_sync_status ON agents(sync_status);

COMMENT ON COLUMN agents.source_path IS '文件系统实体定义文件的相对路径，作为同步的首要数据唯一标识';
COMMENT ON COLUMN agents.sync_status IS '同步状态: synced, pending, error, dependency_missing';
COMMENT ON COLUMN agents.last_sync_at IS '最后成功同步时间';
```

### 4.2.2 agent_skills 表新增字段 DDL

```sql
-- ============================================================
-- 文件系统与数据库双向同步 MVP - agent_skills 表新增字段
-- ============================================================

ALTER TABLE agent_skills ADD COLUMN IF NOT EXISTS source_path VARCHAR(512);
ALTER TABLE agent_skills ADD COLUMN IF NOT EXISTS sync_status VARCHAR(32) DEFAULT 'pending';
ALTER TABLE agent_skills ADD COLUMN IF NOT EXISTS last_sync_at TIMESTAMPTZ;

-- source_path 唯一索引（仅非空值唯一）
CREATE UNIQUE INDEX IF NOT EXISTS uk_agent_skills_source_path 
    ON agent_skills(source_path) WHERE source_path IS NOT NULL;

-- 同步状态索引
CREATE INDEX IF NOT EXISTS idx_agent_skills_sync_status ON agent_skills(sync_status);

COMMENT ON COLUMN agent_skills.source_path IS '文件系统技能定义文件的相对路径，作为同步的首要数据唯一标识';
COMMENT ON COLUMN agent_skills.sync_status IS '同步状态: synced, pending, error, dependency_missing';
COMMENT ON COLUMN agent_skills.last_sync_at IS '最后成功同步时间';
```

### 4.2.3 同步日志表 DDL

```sql
CREATE TABLE IF NOT EXISTS sync_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type     VARCHAR(50) NOT NULL,       -- 实体类型: agent, agent_skill
    source_path     VARCHAR(512) NOT NULL,       -- 实体文件路径
    operation       VARCHAR(30) NOT NULL,       -- 操作类型: create, update, delete, sync
    direction       VARCHAR(20) NOT NULL,       -- 同步方向: fs_to_db, db_to_fs
    status          VARCHAR(20) NOT NULL,       -- 状态: success, failed
    message         VARCHAR(1000),              -- 操作消息
    error_detail    VARCHAR(4000),              -- 错误详情
    sync_source     VARCHAR(20) NOT NULL,       -- 同步源标记: business, sync_system, manual, startup
    duration_ms     INT4,                       -- 耗时(毫秒)
    creator         UUID,                       -- 创建人/操作者
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sync_log_entity ON sync_log(entity_type, source_path);
CREATE INDEX IF NOT EXISTS idx_sync_log_time ON sync_log(created_at);
CREATE INDEX IF NOT EXISTS idx_sync_log_status ON sync_log(status);
```

### 4.2.4 AgentPO 持久化对象（新增字段）

```cangjie
package magic.app.models.uctoo

// AgentPO 新增以下字段:
@ORMField['source_path']
public var sourcePath: Option<String> = None

@ORMField['sync_status']
public var syncStatus: String = "pending"

@ORMField['last_sync_at']
public var lastSyncAt: Option<DateTime> = None
```

### 4.2.5 AgentSkillPO 持久化对象（新增字段）

```cangjie
package magic.app.models.uctoo

// AgentSkillPO 新增以下字段:
@ORMField['source_path']
public var sourcePath: Option<String> = None

@ORMField['sync_status']
public var syncStatus: String = "pending"

@ORMField['last_sync_at']
public var lastSyncAt: Option<DateTime> = None
```

### 4.2.6 SyncLogPO 持久化对象

**文件**: `src/app/models/uctoo/SyncLogPO.cj`（新增）

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["sync_log"]
public class SyncLogPO {
    @ORMField['id']
    public var id: String = ""
    
    @ORMField['entity_type']
    public var entityType: String = ""
    
    @ORMField['source_path']
    public var sourcePath: String = ""
    
    @ORMField['operation']
    public var operation: String = ""
    
    @ORMField['direction']
    public var direction: String = ""
    
    @ORMField['status']
    public var status: String = ""
    
    @ORMField['message']
    public var message: Option<String> = None
    
    @ORMField['error_detail']
    public var errorDetail: Option<String> = None
    
    @ORMField['sync_source']
    public var syncSource: String = ""
    
    @ORMField['duration_ms']
    public var durationMs: Option<Int32> = None
    
    @ORMField['creator']
    public var creator: Option<String> = None
    
    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()
    
    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()
    
    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None
    
    public init() {}
}
```

---

# **5. 核心组件设计**

## **5.1 SyncManager**

| 属性 | 说明 |
|------|------|
| 职责 | 核心同步控制器，协调同步任务、拓扑排序、upsert 幂等性保证 |
| 包路径 | `magic.app.services.sync` |
| 依赖 | SyncHandler, DataMapper, ConflictResolver, TopologySorter, RetryManager, SyncLogService |
| 线程安全 | 单例模式，内部 ConcurrentHashMap 线程安全 |
| MVP 简化 | 省略限流器、熔断管理器、任务去重表、优先级队列 |

## **5.2 SyncHandler**

| 属性 | 说明 |
|------|------|
| 职责 | 定义特定实体类型的同步契约 |
| 接口方法 | syncFromFileSystem, syncToFileSystem, detectChanges, buildFilePath |
| 扩展方式 | 注册新的 SyncHandler 实现即可支持新实体类型 |

## **5.3 AgentSyncHandler**

| 属性 | 说明 |
|------|------|
| 职责 | 处理 Agent 实体的同步逻辑 |
| entityType | "agent" |
| dependencies | [] (无前置依赖) |
| source_path 规则 | AGENTS.md 或 agents 目录下 .md 文件的相对路径 |

## **5.4 AgentSkillSyncHandler**

| 属性 | 说明 |
|------|------|
| 职责 | 处理 AgentSkill 实体的同步逻辑 |
| entityType | "agent_skill" |
| dependencies | ["agent"] (依赖 agent) |
| source_path 规则 | .codeartsdoer/skills 目录下技能定义文件的相对路径 |
| 依赖检查 | agent 不存在时标记为 dependency_missing |

## **5.5 DataMapper**

| 属性 | 说明 |
|------|------|
| 职责 | Markdown Frontmatter 与实体对象的双向转换 |
| 支持格式 | YAML frontmatter + Markdown 正文 |
| 兼容性 | 向前兼容：映射规则升级后旧格式文件仍可正确解析 |
| 部分映射 | 宽容模式下缺失字段使用默认值；严格模式下标记错误 |

### Agent Frontmatter 字段映射

| 文件字段 | 数据库字段 | 说明 |
|----------|-----------|------|
| name | name | Agent 名称 |
| type | type | Agent 类型 |
| description | description | Agent 描述 |
| model | model | 模型名称 |
| tools | tools | 工具列表（JSON） |
| version | - | 版本号（不映射） |
| author | - | 作者（不映射） |
| (Markdown 正文) | system_prompt | 系统提示词 |

### AgentSkill Frontmatter 字段映射

| 文件字段 | 数据库字段 | 说明 |
|----------|-----------|------|
| name | name | 技能名称 |
| description | description | 技能描述 |
| version | version | 版本号 |
| author | author | 作者 |
| license | license | 许可证 |
| keywords | keywords | 关键词 |
| (Markdown 正文) | instructions | 技能指令 |

## **5.6 SyncInterceptor**

| 属性 | 说明 |
|------|------|
| 职责 | AOP 切面拦截业务实体 DAO 操作，触发文件同步 |
| 框架 | 复用 f_aspect，@AspectRoute 注解定义切点 |
| 通知类型 | after 通知（数据库操作成功后触发） |
| 执行方式 | 异步执行，不阻塞主线程 |
| 循环防护 | SyncContext.isPresent() 检查 |
| 拦截范围 | 实体类型白名单 + 包路径排除规则 |

## **5.7 ChangeDetector**

| 属性 | 说明 |
|------|------|
| 职责 | 基于文件修改时间戳检测文件系统变更 |
| 检测策略 | 仅 timestamp（MVP 简化） |
| 比对逻辑 | 文件修改时间 > 数据库 last_sync_at 则判定为变更 |
| 批量合并 | 一次扫描中检测到的多个变更合并为一次批量同步请求 |
| 触发方式 | crontab 定时调度 |

## **5.8 SyncContext**

| 属性 | 说明 |
|------|------|
| 职责 | ThreadLocal 同步上下文，携带同步源标记 |
| 存储方式 | ThreadLocal |
| 核心方法 | enter(), exit(), isPresent(), current() |
| 循环防护 | AOP 切面检查 isPresent()，若为 true 则跳过拦截 |
| MVP 简化 | 省略触发链路追踪、TraceID、循环检测方法 |

## **5.9 ConflictResolver**

| 属性 | 说明 |
|------|------|
| 职责 | Last-Write-Wins 冲突解决策略 |
| 冲突检测 | 文件修改时间 > last_sync_at && 数据库updated_at > last_sync_at |
| 解决策略 | 时间戳较晚的版本胜出 |
| MVP 简化 | 省略版本向量、三路合并、多策略选择 |

## **5.10 SyncStatusManager**

| 属性 | 说明 |
|------|------|
| 职责 | 管理同步状态，通过实体表字段持久化 |
| 持久化字段 | sync_status, last_sync_at（在 agents/agent_skills 表中） |
| MVP 简化 | 不引入独立 sync_status 表，状态直接存储在实体表 |
| 状态取值 | pending, synced, error, dependency_missing |

---

# **6. MVP 与 v2.0.0 差异说明**

| 能力领域 | v2.0.0 | v1.0.0-mvp | 简化原因 |
|----------|--------|------------|----------|
| **SyncManager** | 限流器 + 熔断管理器 + 任务去重表 + 优先级队列 + 事件发布器 | 仅核心协调 + 拓扑排序 + 重试 | MVP 简化，核心功能足够 |
| **ChangeDetector** | content-hash + timestamp + hybrid 三策略 + 防抖窗口 + 节流 | 仅 timestamp 策略 + 定时扫描 | MVP 简化，时间戳检测实现简单，定时扫描天然防抖 |
| **SyncInterceptor** | 同 v2.0.0（核心逻辑一致） | 同 v2.0.0（复用 f_aspect） | 核心拦截逻辑不可简化 |
| **ConflictResolver** | 版本向量 + 三路合并 + 多策略（source_priority/timestamp_priority/manual） | 仅 Last-Write-Wins | MVP 简化，单一策略降低实现复杂度 |
| **SyncStatusManager** | 独立 sync_status 表 + 版本向量 + 内容哈希 + 映射版本 | 实体表字段（sync_status + last_sync_at） | MVP 简化，减少表数量，状态直接存储在实体表 |
| **SyncContext** | ThreadLocal + 触发链路追踪 + TraceID + 循环检测 | ThreadLocal + 同步源标记 | MVP 简化，同步源标记足以防止直接循环 |
| **DataMapper** | 同 v2.0.0（核心逻辑一致） | 同 v1.0.0-mvp | Markdown Frontmatter 双向转换不可简化 |
| **数据模型** | sync_status + sync_log + sync_conflict + sync_task 四表 | sync_log 一表 + 实体表新增字段 | MVP 简化，减少表数量，冲突和任务不持久化 |
| **可观测性** | Metrics + Tracing + 告警 | 仅同步日志 | MVP 简化，日志满足基本排查需求 |
| **限流与背压** | 令牌桶/滑动窗口限流 + 优先级队列 + 背压三策略 | 无 | MVP 简化，MVP 规模下不需要 |
| **熔断机制** | 循环同步检测 + 熔断 + 自动恢复 | 仅同步源标记防护 | MVP 简化，SyncContext 足以防止直接循环 |
| **幂等性** | upsert + 任务去重表 | 仅 upsert | MVP 简化，upsert 语义已保证幂等 |
| **事件溯源** | 领域事件 + 事件发布器 + 事件总线 | 无 | MVP 简化，v2.0.0 迭代时实现 |
| **API 接口** | 13 个接口（含冲突管理、任务取消） | 9 个接口（省略冲突管理、任务取消） | MVP 简化，冲突自动解决无需管理接口 |

---

# **7. 安全性与可靠性**

## **7.1 安全性**

1. **权限控制**: 所有同步操作受 RBAC 权限保护（sync:read / sync:write）
2. **审计日志**: 记录所有同步操作的同步源、触发方式
3. **API 认证**: 同步 API 必须认证鉴权，未授权请求返回 401
4. **文件权限**: 限制文件读写权限，防止未授权访问

## **7.2 可靠性**

1. **重试机制**: 同步失败自动重试，最多 3 次，指数退避（1s, 2s, 4s）
2. **异步执行**: 同步操作异步执行，不阻塞主线程
3. **幂等性保证**: 同步操作采用 upsert 语义（以 source_path 为匹配键）
4. **循环同步防护**: SyncContext 同步源标记，AOP 切面检查后跳过

## **7.3 循环同步防护**

| 防护层级 | 机制 | 说明 |
|----------|------|------|
| **第一层** | SyncContext 标记 | 同步系统触发的变更携带 SyncSystem 标记，AOP 切面检查后跳过 |
| **第二层** | 定时扫描补偿 | AOP 拦截异常时不影响主业务，定时扫描可补偿遗漏同步 |

## **7.4 AOP 拦截范围限定**

| 限定机制 | 规则 | 说明 |
|----------|------|------|
| **包路径包含** | `magic.app.dao.uctoo.*` | 仅拦截业务实体 DAO 包 |
| **包路径排除** | `magic.app.dao.sync.*` | 排除同步系统自身 DAO 包 |
| **实体类型白名单** | `{agent, agent_skill}` | 仅拦截白名单内的实体类型 |
| **同步上下文检查** | `SyncContext.isPresent()` | 携带同步源标记的操作跳过拦截 |

---

# **8. 基础设施复用**

## **8.1 f_aspect 框架复用**

| 组件 | 说明 | 复用价值 |
|------|------|----------|
| **Aspect 接口** | 定义切面契约，包含 before/after/around/throwing/final 五个生命周期方法 | 实现数据库操作拦截 |
| **@AspectRoute 注解** | 修饰切面实现类，定义切点规则 | 声明式配置拦截规则 |
| **RouteRule 体系** | 支持多种匹配规则（包名、方法名、参数、注解等） | 灵活定义拦截范围 |
| **@Pointcut 宏** | 编译期织入切面代码 | 无侵入式拦截 |

## **8.2 crontab 框架复用**

| 组件 | 说明 | 复用价值 |
|------|------|----------|
| **CronJob 接口** | 定时任务契约 | 实现定时变更检测扫描 |
| **CrontabScheduler** | 定时任务调度器 | 注册和管理同步扫描任务 |

## **8.3 f_orm 框架复用**

| 组件 | 说明 | 复用价值 |
|------|------|----------|
| **DAO 层** | 数据访问对象 | 执行 upsert、查询等数据库操作 |
| **@DataAssist** | 数据辅助注解 | 自动生成 PO 基础方法 |
| **@QueryMappersGenerator** | 查询映射生成器 | 自动生成 CRUD 查询映射 |

---

# **9. 部署与集成**

## **9.1 依赖声明**

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
```

## **9.2 数据库迁移**

**文件**: `scripts/migration/sync_system_mvp_v1.sql`

```sql
-- ============================================================
-- 文件系统与数据库双向同步系统 MVP v1.0.0 数据库迁移脚本
-- ============================================================

-- agents 表新增同步字段
ALTER TABLE agents ADD COLUMN IF NOT EXISTS source_path VARCHAR(512);
ALTER TABLE agents ADD COLUMN IF NOT EXISTS sync_status VARCHAR(32) DEFAULT 'pending';
ALTER TABLE agents ADD COLUMN IF NOT EXISTS last_sync_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS uk_agents_source_path 
    ON agents(source_path) WHERE source_path IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_agents_sync_status ON agents(sync_status);

COMMENT ON COLUMN agents.source_path IS '文件系统实体定义文件的相对路径，作为同步的首要数据唯一标识';
COMMENT ON COLUMN agents.sync_status IS '同步状态: synced, pending, error, dependency_missing';
COMMENT ON COLUMN agents.last_sync_at IS '最后成功同步时间';

-- agent_skills 表新增同步字段
ALTER TABLE agent_skills ADD COLUMN IF NOT EXISTS source_path VARCHAR(512);
ALTER TABLE agent_skills ADD COLUMN IF NOT EXISTS sync_status VARCHAR(32) DEFAULT 'pending';
ALTER TABLE agent_skills ADD COLUMN IF NOT EXISTS last_sync_at TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS uk_agent_skills_source_path 
    ON agent_skills(source_path) WHERE source_path IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_agent_skills_sync_status ON agent_skills(sync_status);

COMMENT ON COLUMN agent_skills.source_path IS '文件系统技能定义文件的相对路径，作为同步的首要数据唯一标识';
COMMENT ON COLUMN agent_skills.sync_status IS '同步状态: synced, pending, error, dependency_missing';
COMMENT ON COLUMN agent_skills.last_sync_at IS '最后成功同步时间';

-- 同步日志表
CREATE TABLE IF NOT EXISTS sync_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type     VARCHAR(50) NOT NULL,
    source_path     VARCHAR(512) NOT NULL,
    operation       VARCHAR(30) NOT NULL,
    direction       VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL,
    message         VARCHAR(1000),
    error_detail    VARCHAR(4000),
    sync_source     VARCHAR(20) NOT NULL,
    duration_ms     INT4,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_log_entity ON sync_log(entity_type, source_path);
CREATE INDEX IF NOT EXISTS idx_sync_log_time ON sync_log(created_at);
CREATE INDEX IF NOT EXISTS idx_sync_log_status ON sync_log(status);
```

---

**文档维护者**: UCToo Team  
**最后更新**: 2026-06-03