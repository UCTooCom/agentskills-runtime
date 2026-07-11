# 计划任务调度系统（Crontab Scheduler）技术设计文档

## 文档信息
- **项目名称**: agentskills-runtime 计划任务调度系统
- **版本**: 1.0.0
- **创建日期**: 2026-05-17
- **最后更新**: 2026-05-17
- **作者**: SDD Agent
- **状态**: 草稿
- **关联需求**: spec.md v1.0.0

---

# **1. 实现模型**

## **1.1 上下文视图**

### 系统上下文图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          外部系统交互视图                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────┐                   │
│  │ 管理员UI │───>│  HTTP API    │───>│  数据库       │                   │
│  │ (前端)   │    │  /api/v1/... │    │  PostgreSQL  │                   │
│  └──────────┘    └──────────────┘    └──────────────┘                   │
│                         │                                               │
│                         │                                               │
│  ┌──────────┐          │          ┌──────────────┐                     │
│  │ CLI 终端 │──────────┼────────>│  调度引擎     │                     │
│  │ (运维)   │          │          │  Ticktock    │                     │
│  └──────────┘          │          └──────────────┘                     │
│                         │              │                               │
│  ┌──────────┐          │              ├──> script:// (Shell脚本)       │
│  │ 定时触发 │<─────────┘              ├──> http://   (HTTP回调)        │
│  │ (Chrono) │                         └──> builtin:// (内置执行器)     │
│  └──────────┘                                                        │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │  日志系统 (异步写入)                                          │      │
│  │  crontab_log 表 + 文件日志                                    │      │
│  └──────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

### 核心参与者

| 参与者 | 角色 | 交互方式 |
|--------|------|----------|
| 管理员/前端 | 创建/管理计划任务 | HTTP API |
| 运维人员 | 手动触发/调试任务 | CLI 命令 |
| Ticktock 调度器 | 按CRON表达式自动触发 | 内部事件驱动 |
| 执行器 | 执行具体任务逻辑 | script/http/builtin 协议 |
| 数据库 | 持久化任务定义和日志 | f_orm ORM |

## **1.2 服务/组件总体架构**

### 架构分层图

```
┌──────────────────────────────────────────────────────────────────────┐
│                     接入层 (Entry Layer)                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │ CrontabController │  │ CrontabLogController│ │  CrontabCLI    │   │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘   │
├───────────┼──────────────────────┼──────────────────────┼────────────┤
│           │        服务层 (Service Layer)               │            │
│  ┌────────┴─────────┐  ┌────────┴─────────┐  ┌────────┴─────────┐  │
│  │ CrontabService   │  │ CrontabLogService │  │SchedulerService  │  │
│  │  (CRUD+权限)     │  │  (日志查询)       │  │ (调度核心)       │  │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘  │
├───────────┼──────────────────────┼──────────────────────┼────────────┤
│           │        调度引擎层 (Scheduler Engine)         │            │
│  ┌────────┴────────────────────────────────────────────┴─────────┐  │
│  │                    SchedulerEngine                             │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │  │
│  │  │TaskLoader│  │TaskRunner │  │MisfireMgr│  │ RetryManager │ │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────┘ │  │
│  └────────────────────────┬──────────────────────────────────────┘  │
├───────────────────────────┼─────────────────────────────────────────┤
│       执行器层 (Executor Layer)                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │ScriptExecutor│  │ HttpExecutor │  │BuiltinExecutor│             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│         │                  │                  │                      │
│  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐               │
│  │ExecutorRegistry│             │  │ 内置任务注册  │               │
│  └──────────────┘               │  └──────────────┘               │
├─────────────────────────────────┼──────────────────────────────────┤
│       数据层 (Data Access Layer) │                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  CrontabDAO  │  │CrontabLogDAO │  │TaskRegistryDAO│             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
├────────────────────────────────────────────────────────────────────┤
│       基础设施层 (Infrastructure)                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ Ticktock │  │  f_orm   │  │  f_log   │  │ PermissionUtils │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

### 数据流图

```
任务创建流:
  API/CLI ──> CrontabService.create() ──> CrontabDAO.insert() ──> DB
                                            │
                                            └──> SchedulerEngine.reloadTask() ──> Ticktock.addOrReplaceTask()

任务触发流:
  Chrono(每秒) ──> Ticktock.emit(now) ──> CronTicktockTask.run()
      │
      └──> SchedulerEngine.executeTask()
              │
              ├──> ExecutorRegistry.getExecutor(taskType)
              │        │
              │        ├── script:// ──> ScriptExecutor.execute()
              │        ├── http://   ──> HttpExecutor.execute()
              │        └── builtin://──> BuiltinExecutor.execute()
              │
              ├──> MisfireManager.checkAndRecord()  (错过执行检测)
              │
              ├──> RetryManager.wrapExecution()      (重试包装)
              │
              └──> CrontabLogDAO.insert()            (异步日志写入)

任务更新/删除流:
  API/CLI ──> CrontabService.update/delete() ──> CrontabDAO ──> DB
                                                    │
                                                    ├──> SchedulerEngine.reloadTask()    (更新)
                                                    └──> SchedulerEngine.removeTask()    (删除)
```

### 应用启动流程

```
Application.init()
    │
    ├── ORM.initialize()                    (现有)
    ├── setupMiddlewares()                  (现有)
    ├── setupRoutes()                       (现有)
    │       └── AutoRouteRegistry.registerAllRoutes()
    │               └── CrontabRoute.register()         (现有)
    │
    └── [新增] SchedulerEngine.initialize()
            │
            ├── 从 DB 加载所有 status=1 的任务定义
            ├── 注册到 Ticktock 单例调度器
            │       └── Ticktock.addOrReplaceTask(FuncCronTicktockTask)
            ├── 注册进程退出钩子
            │       └── env.atExit { gracefulShutdown() }
            └── 启动 MisfireManager 检测循环
```

## **1.3 实现设计文档**

### 1.3.1 SchedulerEngine（调度引擎）

**职责**: 核心调度控制器，连接数据库任务定义与 f_ticktock 调度器

```cangjie
package magic.app.services.crontab

public class SchedulerEngine {
    // 单例模式
    private static let instance_ = AtomicOptionReference<SchedulerEngine>()
    
    // 调度器引用
    private let ticktock: Ticktock
    
    // 执行器注册表
    private let executorRegistry: ExecutorRegistry
    
    // 错过执行管理器
    private let misfireManager: MisfireManager
    
    // 重试管理器
    private let retryManager: RetryManager
    
    // 运行中任务追踪（用于并发控制和优雅关闭）
    private let runningTasks: ConcurrentHashMap<String, CrontabExecutionContext>
    
    // === 核心方法 ===
    
    /// 初始化调度引擎：从DB加载任务并注册到Ticktock
    public static func initialize(): SchedulerEngine
    
    /// 从数据库重新加载单个任务到调度器
    public func reloadTask(crontabId: String): Unit
    
    /// 从调度器移除任务
    public func removeTask(crontabId: String): Unit
    
    /// 批量加载所有活跃任务
    public func loadAllActiveTasks(): Unit
    
    /// 手动触发一次任务执行（CLI/API触发）
    public func triggerTask(crontabId: String, triggerType: TriggerType): ExecutionResult
    
    /// 执行任务（由Ticktock回调）
    public func executeTask(crontabId: String): Unit
    
    /// 优雅关闭：等待运行中任务完成或超时
    public func gracefulShutdown(timeout: Duration): Unit
    
    /// 获取运行中任务快照
    public func getRunningTasks(): ArrayList<CrontabExecutionContext>
    
    /// 获取调度器状态
    public func getStatus(): SchedulerStatus
}
```

### 1.3.2 ExecutorRegistry（执行器注册表）

**职责**: 管理三类执行器的注册与查找

```cangjie
package magic.app.services.crontab.executor

public class ExecutorRegistry {
    private let executors: ConcurrentHashMap<String, CrontabExecutor>
    
    /// 注册执行器
    public func register(scheme: String, executor: CrontabExecutor): Unit
    
    /// 根据任务URI获取执行器
    /// taskUri格式: script:///path/to/script.sh
    ///              http://host:port/api/callback
    ///              builtin://taskName
    public func getExecutor(taskUri: String): Option<CrontabExecutor>
    
    /// 解析URI协议
    public static func parseScheme(taskUri: String): String
    
    /// 解析URI路径（去掉协议前缀后的部分）
    public static func parsePath(taskUri: String): String
}
```

### 1.3.3 CrontabExecutor（执行器接口）

**职责**: 统一的任务执行器抽象

```cangjie
package magic.app.services.crontab.executor

/// 计划任务执行器接口
public interface CrontabExecutor {
    /// 执行器支持的协议scheme
    prop scheme: String
    
    /// 执行任务
    /// @param context 执行上下文（包含任务定义、参数等）
    /// @return 执行结果
    func execute(context: CrontabExecutionContext): ExecutionResult
    
    /// 验证任务URI是否合法
    func validate(taskUri: String): Bool
}
```

### 1.3.4 ScriptExecutor（脚本执行器）

```cangjie
package magic.app.services.crontab.executor

/// 执行 script:// 协议的任务
/// 示例: script:///opt/scripts/backup.sh
///       script://python3 /opt/scripts/analyze.py
public class ScriptExecutor <: CrontabExecutor {
    prop scheme: String = "script"
    
    public func execute(context: CrontabExecutionContext): ExecutionResult {
        // 1. 解析脚本路径和参数
        // 2. spawn 子进程执行脚本
        // 3. 捕获 stdout/stderr
        // 4. 等待执行完成或超时
        // 5. 返回执行结果
    }
    
    public func validate(taskUri: String): Bool {
        // 验证脚本路径存在且可执行
    }
}
```

### 1.3.5 HttpExecutor（HTTP回调执行器）

```cangjie
package magic.app.services.crontab.executor

/// 执行 http:// 协议的任务
/// 示例: http://localhost:8080/api/internal/cleanup
///       http://external-service/api/sync?force=true
public class HttpExecutor <: CrontabExecutor {
    prop scheme: String = "http"
    
    public func execute(context: CrontabExecutionContext): ExecutionResult {
        // 1. 解析URL和请求参数
        // 2. 构建HTTP请求（POST，携带任务元数据Header）
        // 3. 发送请求，设置超时
        // 4. 解析响应状态码和body
        // 5. 返回执行结果
    }
    
    public func validate(taskUri: String): Bool {
        // 验证URL格式合法
    }
}
```

### 1.3.6 BuiltinExecutor（内置执行器）

```cangjie
package magic.app.services.crontab.executor

/// 执行 builtin:// 协议的任务
/// 示例: builtin://database-cleanup
///       builtin://cache-refresh
public class BuiltinExecutor <: CrontabExecutor {
    prop scheme: String = "builtin"
    
    // 内置任务注册表
    private let builtinTasks: ConcurrentHashMap<String, BuiltinTaskHandler>
    
    /// 注册内置任务处理器
    public func registerBuiltinTask(name: String, handler: BuiltinTaskHandler): Unit
    
    public func execute(context: CrontabExecutionContext): ExecutionResult {
        // 1. 从注册表查找内置任务处理器
        // 2. 调用处理器执行
        // 3. 返回执行结果
    }
    
    public func validate(taskUri: String): Bool {
        // 验证内置任务已注册
    }
}

/// 内置任务处理器接口
public interface BuiltinTaskHandler {
    func handle(context: CrontabExecutionContext): ExecutionResult
}
```

### 1.3.7 MisfireManager（错过执行管理器）

```cangjie
package magic.app.services.crontab.misfire

/// 错过执行策略
public enum MisfirePolicy {
    | Ignore          // 忽略（默认）
    | FireNow         // 立即补执行一次
    | FireAll         // 补执行所有错过的
}

public class MisfireManager {
    /// 检测并处理错过执行的任务
    /// 在每次任务触发前调用
    public func checkAndHandle(
        crontab: CrontabPO, 
        now: DateTime
    ): MisfireAction
    
    /// 计算错过的执行次数
    public func countMissedExecutions(
        cron: String, 
        from: DateTime, 
        to: DateTime
    ): Int64
}
```

### 1.3.8 RetryManager（重试管理器）

```cangjie
package magic.app.services.crontab.retry

/// 重试策略
public enum RetryStrategy {
    | FixedDelay(Duration)          // 固定间隔
    | ExponentialBackoff(Duration, Float64)  // 指数退避（基础间隔, 乘数）
}

public class RetryManager {
    /// 包装任务执行，加入重试逻辑
    public func executeWithRetry(
        crontab: CrontabPO,
        executor: CrontabExecutor,
        context: CrontabExecutionContext
    ): ExecutionResult
    
    /// 计算下一次重试的延迟时间
    public func calculateRetryDelay(
        strategy: RetryStrategy,
        attempt: Int32
    ): Duration
}
```

### 1.3.9 关键数据类型

```cangjie
package magic.app.services.crontab.model

/// 执行上下文
public class CrontabExecutionContext {
    public var crontabId: String         // 任务ID
    public var taskName: String          // 任务名称
    public var taskUri: String           // 任务URI (script/http/builtin)
    public var parameters: String        // JSON格式参数
    public var timeout: Int32            // 超时时间(秒)
    public var triggerType: TriggerType  // 触发类型
    public var retryAttempt: Int32       // 当前重试次数
    public var maxRetries: Int32         // 最大重试次数
    public var startTime: DateTime       // 开始时间
}

/// 触发类型
public enum TriggerType {
    | Cron         // CRON定时触发
    | Manual       // 手动触发(API/CLI)
    | Misfire      // 错过执行补触发
    | Retry        // 重试触发
}

/// 执行结果
public class ExecutionResult {
    public var success: Bool
    public var exitCode: Int32
    public var output: String            // 标准输出(截断)
    public var errorOutput: String       // 错误输出(截断)
    public var duration: Int64           // 耗时(毫秒)
    public var resultSummary: String     // 结果摘要
}

/// 调度器状态
public class SchedulerStatus {
    public var isRunning: Bool
    public var totalTasks: Int32
    public var activeTasks: Int32
    public var runningTasks: Int32
    public var lastTickTime: DateTime
}
```

---

# **2. 接口设计**

## **2.1 总体设计**

### API 设计原则
1. 遵循 UCTOO V4 RESTful 规范，路由前缀 `/api/v1/uctoo/crontab/`
2. 复用现有 CRUD 接口（add/edit/del/get），仅扩展调度专用接口
3. 所有接口受 JWT 认证 + RBAC 权限 + 行级权限保护
4. group=2 的系统任务不可通过 API 删除/禁用
5. 响应格式统一使用 `APIResult<T>`

### CLI 设计原则
1. 命令入口: `skill crontab <sub-command> [options]`
2. 支持 `--json` 输出格式用于脚本集成
3. 支持无数据库直接运行模式（开发调试用）

## **2.2 接口清单**

### 2.2.1 HTTP API 接口

#### 现有 CRUD 接口（保持不变）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/uctoo/crontab/add` | 创建任务 |
| POST | `/api/v1/uctoo/crontab/edit` | 编辑任务 |
| POST | `/api/v1/uctoo/crontab/del` | 删除任务 |
| GET  | `/api/v1/uctoo/crontab/:id` | 查询单个任务 |
| GET  | `/api/v1/uctoo/crontab/:limit/:page` | 分页查询任务列表 |
| GET  | `/api/v1/uctoo/crontab/export` | 导出任务 |

#### 新增调度控制接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/uctoo/crontab/trigger/:id` | 手动触发任务执行 | crontab:write |
| POST | `/api/v1/uctoo/crontab/enable/:id` | 启用任务 | crontab:write |
| POST | `/api/v1/uctoo/crontab/disable/:id` | 禁用任务（group=2禁止） | crontab:write |
| GET  | `/api/v1/uctoo/crontab/status` | 获取调度器运行状态 | crontab:read |
| GET  | `/api/v1/uctoo/crontab/running` | 获取正在执行的任务列表 | crontab:read |
| POST | `/api/v1/uctoo/crontab/reload` | 重新加载所有任务到调度器 | crontab:write |
| GET  | `/api/v1/uctoo/crontab/:id/next-exec` | 计算任务下次执行时间 | crontab:read |

#### 执行器注册表接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET  | `/api/v1/uctoo/crontab/executors` | 获取所有注册执行器 | crontab:read |
| GET  | `/api/v1/uctoo/crontab/builtin-tasks` | 获取所有内置任务 | crontab:read |

#### 执行日志扩展接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET  | `/api/v1/uctoo/crontab_log/by-crontab/:id` | 按任务ID查询日志 | crontab:read |
| GET  | `/api/v1/uctoo/crontab_log/recent` | 获取最近执行日志 | crontab:read |
| GET  | `/api/v1/uctoo/crontab_log/stats` | 获取执行统计信息 | crontab:read |

### 2.2.2 CLI 命令体系

```
skill crontab <command> [options]

命令列表:
  list                            列出所有计划任务
  show <id>                       显示任务详情
  add --name <n> --cron <c> --task <t> [options]  创建任务
  edit <id> [options]             编辑任务
  delete <id>                     删除任务
  trigger <id>                    手动触发任务执行
  enable <id>                     启用任务
  disable <id>                    禁用任务
  reload                          重新加载所有任务
  status                          查看调度器状态
  logs [options]                  查看执行日志
  executors                       列出注册执行器

add/edit 选项:
  --name <value>        任务名称
  --group <value>       分组 (default: 1)
  --cron <value>        CRON表达式
  --task <value>        任务URI (script://|http://|builtin://)
  --tactics <value>     执行策略
  --timeout <seconds>   超时时间 (default: 300)
  --max-retries <n>     最大重试次数 (default: 3)
  --concurrent          允许并发执行
  --once                仅执行一次
  --priority <n>        优先级 (default: 0)
  --params <json>       参数JSON
  --misfire <policy>    错过执行策略 (ignore|fire-now|fire-all)

通用选项:
  --json                JSON格式输出
  --limit <n>           限制条数
  --page <n>            页码
```

---

# **3. 集成设计**

## **3.1 f_ticktock 集成方式**

### 集成架构

```
SchedulerEngine (新增)
    │
    ├── 持有 Ticktock.instance 引用（单例，线程安全）
    │
    ├── 任务注册方式:
    │   ┌──────────────────────────────────────────────────┐
    │   │  Ticktock.instance.addOrReplaceTask(             │
    │   │      taskName: "crontab:${crontabId}",           │
    │   │      taskCron: cronExpression,                   │
    │   │      execOnce: crontab.once,                     │
    │   │      concurrenctly: crontab.concurrentable,      │
    │   │      executor: { =>                              │
    │   │          SchedulerEngine.instance                │
    │   │              .executeTask(crontabId)             │
    │   │      }                                          │
    │   │  )                                              │
    │   └──────────────────────────────────────────────────┘
    │
    └── 任务命名约定: "crontab:${id}" （确保全局唯一）
```

### 集成要点
1. **不修改 f_ticktock 源码**，仅通过其公开API操作
2. 使用 `FuncCronTicktockTask` 动态注册，无需预定义类
3. 任务名采用 `crontab:${id}` 格式，与 f_ticktock 内部任务区分
4. 利用 `concurrentable` 参数控制并发执行策略
5. 利用 `once` 参数实现一次性任务

## **3.2 Application 启动流程变更**

```cangjie
// Application.init() 中新增:
private var schedulerEngine: ?SchedulerEngine = None

// init() 末尾新增:
try {
    schedulerEngine = Some(SchedulerEngine.initialize())
    LogUtils.info("SchedulerEngine initialized successfully")
} catch (e: Exception) {
    LogUtils.error("Failed to initialize SchedulerEngine: ${e.message}")
}

// stop() 中新增:
public func stop(): Unit {
    logger.info("Stopping uctoo-backend-v4")
    
    // 新增：优雅关闭调度引擎
    if (let Some(engine) <- schedulerEngine) {
        engine.gracefulShutdown(Duration.second * 30)  // 等待30秒
    }
    
    server.stop()
    dbPool.closeAll()
    cacheManager.close()
}
```

## **3.3 AutoRouteConfig 变更**

CrontabRoute 注册时注入 SchedulerEngine：

```cangjie
// AutoRouteConfig.initRegistry() 中 Crontab 路由变更:
registry.add(RouteEntry(
    "crontab",
    "/api/v1/uctoo/crontab",
    10,
    true,
    { router: Router =>
        let service = CrontabService()
        let schedulerEngine = SchedulerEngine.instance
        let controller = CrontabController(service, schedulerEngine)
        let route = CrontabRoute(router, controller)
        route.register()
        route.registerCustomRoutes()  // 注册新增调度控制路由
    }
))
```

## **3.4 CLI 集成**

在 `SkillCLI.executeCommand()` 中新增 `crontab` 子命令：

```cangjie
case "crontab" => executeCrontabCommand(subArgs)

private func executeCrontabCommand(args: Array<String>): Unit {
    let cli = CrontabCLI()
    cli.execute(args)
}
```

新增 `CrontabCLI` 类（package magic.cli）：

```cangjie
public class CrontabCLI {
    public func execute(args: Array<String>): Unit {
        if (args.size == 0) { printUsage(); return }
        match (args[0]) {
            case "list"      => listCommand(args[1..])
            case "show"      => showCommand(args[1..])
            case "add"       => addCommand(args[1..])
            case "edit"      => editCommand(args[1..])
            case "delete"    => deleteCommand(args[1..])
            case "trigger"   => triggerCommand(args[1..])
            case "enable"    => enableCommand(args[1..])
            case "disable"   => disableCommand(args[1..])
            case "reload"    => reloadCommand()
            case "status"    => statusCommand()
            case "logs"      => logsCommand(args[1..])
            case "executors" => executorsCommand()
            case _           => printUsage()
        }
    }
}
```

---

# **4. 数据模型**

## **4.1 设计目标**

1. 向下兼容现有 crontab/crontab_log 表结构
2. 通过 ALTER TABLE 增量添加新字段，不破坏现有数据
3. 新增 crontab_task_registry 表管理执行器注册
4. 所有时间字段使用 PostgreSQL timestamptz 类型
5. 所有主键使用 UUID

## **4.2 模型实现**

### 4.2.1 crontab 表增强 DDL

```sql
-- 增量迁移：不删除现有字段，仅新增
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS timeout INT4 DEFAULT 300;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS max_retries INT4 DEFAULT 3;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS retry_count INT4 DEFAULT 0;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS concurrentable BOOLEAN DEFAULT FALSE;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS once BOOLEAN DEFAULT FALSE;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS priority INT4 DEFAULT 0;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS parameters TEXT DEFAULT '{}';
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS misfire_threshold INT4 DEFAULT 60;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS misfire_policy VARCHAR(20) DEFAULT 'ignore';
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS last_executed_at TIMESTAMPTZ;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS next_executed_at TIMESTAMPTZ;
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS exec_count INT4 DEFAULT 0;

-- 索引
CREATE INDEX IF NOT EXISTS idx_crontab_status ON crontab(status);
CREATE INDEX IF NOT EXISTS idx_crontab_group ON crontab("group");
CREATE INDEX IF NOT EXISTS idx_crontab_next_exec ON crontab(next_executed_at) WHERE status = 1 AND deleted_at IS NULL;
```

### 4.2.2 CrontabPO 增强字段

```cangjie
// CrontabPO 新增字段（在现有字段之后追加）
@ORMField['timeout']
public var timeout: Int32 = 300

@ORMField['max_retries']
public var maxRetries: Int32 = 3

@ORMField['retry_count']
public var retryCount: Int32 = 0

@ORMField['concurrentable']
public var concurrentable: Bool = false

@ORMField['once']
public var once: Bool = false

@ORMField['priority']
public var priority: Int32 = 0

@ORMField['parameters']
public var parameters: String = "{}"

@ORMField['misfire_threshold']
public var misfireThreshold: Int32 = 60

@ORMField['misfire_policy']
public var misfirePolicy: String = "ignore"

@ORMField['last_executed_at']
public var lastExecutedAt: Option<DateTime> = None<DateTime>

@ORMField['next_executed_at']
public var nextExecutedAt: Option<DateTime> = None<DateTime>

@ORMField['exec_count']
public var execCount: Int32 = 0
```

### 4.2.3 crontab_log 表增强 DDL

```sql
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ;
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS end_time TIMESTAMPTZ;
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS trigger_type VARCHAR(20) DEFAULT 'cron';
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS retry_attempt INT4 DEFAULT 0;
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS executor_type VARCHAR(20) DEFAULT 'unknown';
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS result_summary TEXT DEFAULT '';

-- 索引
CREATE INDEX IF NOT EXISTS idx_crontab_log_crontab_id ON crontab_log(crontab_id);
CREATE INDEX IF NOT EXISTS idx_crontab_log_start_time ON crontab_log(start_time);
CREATE INDEX IF NOT EXISTS idx_crontab_log_trigger_type ON crontab_log(trigger_type);
```

### 4.2.4 CrontabLogPO 增强字段

```cangjie
// CrontabLogPO 新增字段
@ORMField['start_time']
public var startTime: Option<DateTime> = None<DateTime>

@ORMField['end_time']
public var endTime: Option<DateTime> = None<DateTime>

@ORMField['trigger_type']
public var triggerType: String = "cron"

@ORMField['retry_attempt']
public var retryAttempt: Int32 = 0

@ORMField['executor_type']
public var executorType: String = "unknown"

@ORMField['result_summary']
public var resultSummary: String = ""
```

### 4.2.5 新增 crontab_task_registry 表

```sql
CREATE TABLE IF NOT EXISTS crontab_task_registry (
    id              VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name            VARCHAR(100) NOT NULL UNIQUE,     -- 执行器名称
    scheme          VARCHAR(20) NOT NULL,              -- 协议: script/http/builtin
    description     TEXT DEFAULT '',                   -- 描述
    handler_class   VARCHAR(200) DEFAULT '',           -- 处理器类名（builtin用）
    config          TEXT DEFAULT '{}',                 -- JSON配置
    status          INT4 DEFAULT 1,                    -- 1:启用 0:禁用
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 初始数据
INSERT INTO crontab_task_registry (name, scheme, description) VALUES
    ('script-executor', 'script', '脚本执行器，执行本地脚本文件'),
    ('http-executor', 'http', 'HTTP回调执行器，调用远程API'),
    ('builtin-executor', 'builtin', '内置执行器，执行注册的内置任务');
```

### 4.2.6 CrontabTaskRegistryPO

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["crontab_task_registry"]
public class CrontabTaskRegistryPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['name']
    public var name: String = ""

    @ORMField['scheme']
    public var scheme: String = ""

    @ORMField['description']
    public var description: String = ""

    @ORMField['handler_class']
    public var handlerClass: String = ""

    @ORMField['config']
    public var config: String = "{}"

    @ORMField['status']
    public var status: Int32 = 1

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    public init() {}
}
```

### 4.2.7 数据库迁移策略

| 阶段 | 操作 | 风险 | 回滚方案 |
|------|------|------|----------|
| Phase 1 | ALTER TABLE crontab ADD COLUMN | 低（仅新增，默认值兼容） | ALTER TABLE DROP COLUMN |
| Phase 2 | ALTER TABLE crontab_log ADD COLUMN | 低 | ALTER TABLE DROP COLUMN |
| Phase 3 | CREATE TABLE crontab_task_registry | 低 | DROP TABLE |
| Phase 4 | CREATE INDEX | 低 | DROP INDEX |

迁移脚本位置: `scripts/migration/crontab_sched_v1.sql`

---

# **5. 执行器设计**

## **5.1 执行器架构**

```
                    ┌─────────────────────────┐
                    │    CrontabExecutor       │  (接口)
                    │  + scheme: String        │
                    │  + execute(ctx): Result  │
                    │  + validate(uri): Bool   │
                    └──────────┬──────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
   ┌──────────┴──────┐ ┌──────┴──────┐ ┌───────┴───────┐
   │ ScriptExecutor  │ │ HttpExecutor│ │BuiltinExecutor│
   │ scheme: script  │ │ scheme: http│ │scheme: builtin│
   └─────────────────┘ └─────────────┘ └───────────────┘
```

## **5.2 ScriptExecutor 详细设计**

### URI 格式
- `script:///absolute/path/to/script.sh` - 绝对路径
- `script://python3 /path/to/script.py --arg1 val1` - 带解释器

### 执行流程
1. 解析URI，提取脚本路径和参数
2. 安全检查：脚本路径必须在允许目录内（防路径穿越）
3. `spawn` 子进程，设置环境变量（CRONTAB_ID, CRONTAB_NAME, CRONTAB_PARAMS）
4. 捕获 stdout/stderr 流
5. 设置超时定时器，超时则 kill 子进程
6. 等待执行完成
7. 截断输出（resultSummary 最大 2000 字符）
8. 返回 ExecutionResult

### 安全约束
- 脚本执行目录白名单（从配置读取）
- 禁止 `../` 路径穿越
- 子进程以最小权限运行

## **5.3 HttpExecutor 详细设计**

### URI 格式
- `http://host:port/path` - HTTP
- `https://host:port/path` - HTTPS

### 执行流程
1. 解析URL
2. 构建POST请求，携带Header：
   - `X-Crontab-Id`: 任务ID
   - `X-Crontab-Name`: 任务名称
   - `X-Crontab-Trigger`: 触发类型
   - `Content-Type`: application/json
3. Body 为任务的 parameters JSON
4. 设置超时（从 crontab.timeout 读取）
5. 发送请求，获取响应
6. 2xx 视为成功，其他视为失败
7. 响应体截断存入 resultSummary

## **5.4 BuiltinExecutor 详细设计**

### URI 格式
- `builtin://database-cleanup` - 内置数据库清理
- `builtin://cache-refresh` - 内置缓存刷新
- `builtin://log-rotation` - 内置日志轮转

### 注册机制
1. 应用启动时，`BuiltinExecutor` 自动注册以下内置任务：

| 内置任务名 | 说明 | Handler类 |
|------------|------|-----------|
| database-cleanup | 清理过期数据 | DatabaseCleanupHandler |
| cache-refresh | 刷新缓存 | CacheRefreshHandler |
| log-rotation | 日志轮转 | LogRotationHandler |
| health-check | 健康检查 | HealthCheckHandler |
| metrics-report | 指标上报 | MetricsReportHandler |

2. 支持通过 `@Bean` 注解自动发现注册（利用 fountain.bean IOC）
3. 支持运行时动态注册/注销

---

# **6. 错过执行策略设计**

## **6.1 检测机制**

```
每次 Ticktock 触发前:
  1. 读取 crontab.last_executed_at 和 crontab.next_executed_at
  2. 计算当前时间与上次执行时间的差值
  3. 如果差值 > misfire_threshold 秒:
     → 判定为错过执行
  4. 根据 misfire_policy 决定处理方式
```

## **6.2 策略行为**

| 策略 | 行为 | 适用场景 |
|------|------|----------|
| `ignore` | 跳过错过的执行，按正常计划继续 | 默认，适用于频率高的任务 |
| `fire-now` | 立即补执行一次，然后恢复正常计划 | 适用于不能遗漏的关键任务 |
| `fire-all` | 计算错过的次数，依次补执行全部 | 适用于严格幂等的任务 |

## **6.3 数据更新**

```cangjie
// 每次成功触发后:
crontab.lastExecutedAt = Some(now)
crontab.nextExecutedAt = Some(CronCompiler.nextExecution(cron, now))
crontab.execCount += 1
CrontabDAO.updateExecutionMeta(crontab)
```

---

# **7. 重试机制设计**

## **7.1 重试流程**

```
任务执行失败时:
  1. 检查 retry_count < max_retries
  2. 如果可以重试:
     - retry_count += 1
     - 计算延迟时间（根据策略）
     - 创建 DelayedTicktockTask 延迟重试
     - 写入日志（trigger_type = 'retry', retry_attempt = retry_count）
  3. 如果达到最大重试次数:
     - 标记任务最终失败
     - 写入日志（status = 2, error_message 包含最终错误）
```

## **7.2 重试策略**

| 策略 | 延迟计算 | 示例 |
|------|----------|------|
| FixedDelay(5s) | delay = 5s | 每次重试等待5秒 |
| ExponentialBackoff(2s, 2.0) | delay = base * multiplier^attempt | 2s → 4s → 8s → 16s |

## **7.3 重试状态追踪**

- `crontab.retry_count`: 当前重试计数
- `crontab_log.retry_attempt`: 本次日志对应第几次重试
- `crontab_log.trigger_type = 'retry'`: 标识重试触发

执行成功后重置 `retry_count = 0`

---

# **8. 优雅关闭设计**

## **8.1 关闭流程**

```
收到 SIGTERM/SIGINT 信号:
  1. 停止接受新任务触发
     └── Ticktock.shutdown() 停止 Chrono 时钟
  
  2. 等待运行中任务完成
     └── 循环检查 runningTasks，每秒打印进度
     └── 超时后（默认30秒）强制终止
     
  3. 取消所有待执行的重试任务
  
  4. 写入最终状态
     └── 更新 crontab.next_executed_at（便于重启后错过执行检测）
     
  5. 关闭数据库连接
```

## **8.2 ShutdownHook 注册**

```cangjie
// SchedulerEngine.initialize() 中:
env.atExit {
    gracefulShutdown(Duration.second * 30)
}
```

## **8.3 运行中任务追踪**

```cangjie
// 任务开始执行时:
runningTasks.put(crontabId, context)

// 任务执行完成时:
runningTasks.remove(crontabId)
```

---

# **9. 监控设计**

## **9.1 指标采集**

| 指标 | 类型 | 说明 |
|------|------|------|
| crontab_tasks_total | Gauge | 注册任务总数 |
| crontab_tasks_active | Gauge | 活跃任务数 |
| crontab_tasks_running | Gauge | 正在执行的任务数 |
| crontab_executions_total | Counter | 总执行次数 |
| crontab_executions_success | Counter | 成功执行次数 |
| crontab_executions_failed | Counter | 失败执行次数 |
| crontab_execution_duration_ms | Histogram | 执行耗时分布 |
| crontab_misfire_total | Counter | 错过执行次数 |
| crontab_retry_total | Counter | 重试次数 |

## **9.2 日志规范**

### 调度引擎日志
```
[SchedulerEngine] Task triggered: id=${id}, name=${name}, trigger=${type}
[SchedulerEngine] Task completed: id=${id}, duration=${ms}ms, success=${bool}
[SchedulerEngine] Task failed: id=${id}, error=${msg}, retry=${attempt}/${max}
[SchedulerEngine] Misfire detected: id=${id}, missed=${count}, policy=${policy}
[SchedulerEngine] Shutdown: waiting ${running} tasks, timeout=${sec}s
```

### 执行器日志
```
[ScriptExecutor] Executing: ${path}, pid=${pid}, timeout=${sec}s
[HttpExecutor] Request: POST ${url}, timeout=${sec}s
[HttpExecutor] Response: ${status}, body=${truncated}
[BuiltinExecutor] Executing builtin: ${name}
```

## **9.3 健康检查**

`/api/v1/health` 端点扩展：

```json
{
  "status": "ok",
  "version": "0.0.20",
  "scheduler": {
    "running": true,
    "totalTasks": 15,
    "activeTasks": 12,
    "runningTasks": 2
  }
}
```

---

# **10. 安全设计**

## **10.1 API 安全**

### 认证与授权
- 所有 crontab API 受 JWT 认证保护（现有中间件）
- RBAC 权限节点：`crontab:read` / `crontab:write` / `crontab:delete`
- 行级权限：通过 `PermissionUtils.checkWritePermission()` 控制

### 系统任务保护
```cangjie
// group=2 的系统任务保护逻辑:
func delete(entityId: String, ...): APIResult {
    let existing = findCrontabById(entityId)
    if (existing.group == "2") {
        return APIResult(false, "系统任务不允许删除")
    }
    // 正常删除流程
}

func disable(entityId: String, ...): APIResult {
    let existing = findCrontabById(entityId)
    if (existing.group == "2") {
        return APIResult(false, "系统任务不允许禁用")
    }
    // 正常禁用流程
}
```

### CRON 表达式注入防护
```cangjie
// 创建/编辑任务时验证CRON表达式:
func validateCronExpression(cron: String): Bool {
    try {
        CronCompiler.compile(cron)  // 编译验证
        return true
    } catch (e: Exception) {
        return false
    }
}
```

## **10.2 执行器安全**

### ScriptExecutor 安全
- 脚本路径白名单（配置项 `CRONTAB_SCRIPT_DIRS`）
- 禁止路径穿越（`..` 检测）
- 子进程以低权限用户运行
- 超时强制 kill

### HttpExecutor 安全
- 仅允许 HTTP/HTTPS 协议
- SSRF 防护：内网IP黑名单（配置项 `CRONTAB_HTTP_BLACKLIST`）
- 请求超时上限（不超过任务 timeout）
- 不自动跟随重定向（防止无限循环）

### BuiltinExecutor 安全
- 仅允许注册表中的内置任务
- 内置任务需显式声明 `@CrontabBuiltinTask` 注解

## **10.3 日志安全**
- 敏感参数脱敏（parameters 中的 password/token 等）
- 执行输出截断（最大 2000 字符，防日志膨胀）
- 错误信息不暴露内部路径/堆栈

---

# **11. 模块目录结构**

```
src/app/
├── models/uctoo/
│   ├── CrontabPO.cj              (增强: 新增11个字段)
│   ├── CrontabLogPO.cj           (增强: 新增6个字段)
│   └── CrontabTaskRegistryPO.cj  (新增)
├── dao/uctoo/
│   ├── CrontabDAO.cj             (增强: 新增查询方法)
│   ├── CrontabLogDAO.cj          (增强: 新增查询方法)
│   └── CrontabTaskRegistryDAO.cj (新增)
├── services/uctoo/
│   ├── CrontabService.cj         (增强: 调度控制方法)
│   └── CrontabLogService.cj      (增强: 统计查询方法)
├── services/crontab/             (新增目录)
│   ├── SchedulerEngine.cj        (调度引擎核心)
│   ├── ExecutorRegistry.cj       (执行器注册表)
│   ├── MisfireManager.cj         (错过执行管理)
│   ├── RetryManager.cj           (重试管理)
│   ├── model/                    (数据类型定义)
│   │   ├── CrontabExecutionContext.cj
│   │   ├── ExecutionResult.cj
│   │   ├── TriggerType.cj
│   │   ├── MisfirePolicy.cj
│   │   ├── RetryStrategy.cj
│   │   └── SchedulerStatus.cj
│   ├── executor/                 (执行器实现)
│   │   ├── CrontabExecutor.cj    (接口)
│   │   ├── ScriptExecutor.cj
│   │   ├── HttpExecutor.cj
│   │   ├── BuiltinExecutor.cj
│   │   └── builtin/              (内置任务处理器)
│   │       ├── BuiltinTaskHandler.cj (接口)
│   │       ├── DatabaseCleanupHandler.cj
│   │       ├── CacheRefreshHandler.cj
│   │       └── HealthCheckHandler.cj
│   └── log/                      (异步日志写入)
│       └── AsyncLogWriter.cj
├── controllers/uctoo/crontab/
│   └── CrontabController.cj      (增强: 调度控制Action)
├── routes/uctoo/crontab/
│   └── CrontabRoute.cj           (增强: 调度控制路由)
└── registry/
    └── AutoRouteConfig.cj        (增强: 注入SchedulerEngine)

src/cli/
├── skill_cli.cj                  (增强: 新增crontab子命令)
└── crontab_cli.cj                (新增: 计划任务CLI)

scripts/migration/
└── crontab_sched_v1.sql          (数据库迁移脚本)
```

---

# **12. 异步日志写入设计**

## **12.1 AsyncLogWriter**

```cangjie
package magic.app.services.crontab.log

/// 异步日志写入器
/// 避免日志写入阻塞调度线程
public class AsyncLogWriter {
    // 日志缓冲队列（有界，防内存溢出）
    private let queue: Channel<CrontabLogPO>
    
    // 消费线程
    private var consumerThread: ?Thread
    
    /// 写入日志（非阻塞，放入队列）
    public func writeLog(log: CrontabLogPO): Unit {
        // 队列满时丢弃并记录警告
        queue.trySend(log)
    }
    
    /// 批量写入（消费者线程调用）
    private func consume(): Unit {
        // 从队列批量取出（最多100条）
        // 批量INSERT到数据库
        // 错误时重试一次
    }
    
    /// 关闭（等待队列消费完）
    public func close(timeout: Duration): Unit
}
```

## **12.2 日志写入流程**

```
任务执行完成
    │
    ├── 构造 CrontabLogPO 对象
    │       ├── crontabId
    │       ├── startTime / endTime
    │       ├── usedTime = (end - start) 毫秒
    │       ├── status = success ? 1 : 2
    │       ├── errorMessage (截断)
    │       ├── triggerType
    │       ├── retryAttempt
    │       ├── executorType (script/http/builtin)
    │       └── resultSummary (截断2000字符)
    │
    └── AsyncLogWriter.writeLog(logPO)  [非阻塞，微秒级]
            │
            └── [异步消费线程] 
                    └── CrontabLogDAO.batchInsert(logs)
```

---

# **13. 关键方法签名汇总**

## CrontabService（增强）

```cangjie
// 现有方法保持不变，新增以下方法:

/// 手动触发任务
public func triggerTask(crontabId: String, userId: String): APIResult<CrontabLogPO>

/// 启用任务
public func enableTask(crontabId: String, userId: String): APIResult<CrontabPO>

/// 禁用任务（group=2禁止）
public func disableTask(crontabId: String, userId: String): APIResult<CrontabPO>

/// 重新加载所有任务到调度器
public func reloadAllTasks(): APIResult<Bool>

/// 获取调度器状态
public func getSchedulerStatus(): APIResult<SchedulerStatus>

/// 获取运行中任务
public func getRunningTasks(): APIResult<ArrayList<CrontabExecutionContext>>

/// 计算下次执行时间
public func calculateNextExecution(crontabId: String): APIResult<DateTime>
```

## CrontabDAO（增强）

```cangjie
// 新增方法:

/// 查询所有活跃任务（status=1，未删除）
func findAllActiveCrontab(): ArrayList<CrontabPO>

/// 更新执行元数据（last_executed_at, next_executed_at, exec_count）
func updateExecutionMeta(id: String, lastExecutedAt: DateTime, nextExecutedAt: DateTime, execCount: Int32): Int64

/// 重置重试计数
func resetRetryCount(id: String): Int64

/// 增加重试计数
func incrementRetryCount(id: String): Int64

/// 按任务ID查询日志（分页）
func findLogByCrontabIdPage(crontabId: String, page: Int64, size: Int64): Pagination<CrontabLogPO>

/// 获取执行统计
func getExecutionStats(crontabId: String, since: DateTime): ExecutionStats
```

## CrontabController（增强）

```cangjie
// 新增Action方法:

/// POST /api/v1/uctoo/crontab/trigger/:id
public func trigger(req: HttpRequest, res: HttpResponse): Unit

/// POST /api/v1/uctoo/crontab/enable/:id
public func enable(req: HttpRequest, res: HttpResponse): Unit

/// POST /api/v1/uctoo/crontab/disable/:id
public func disable(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/status
public func status(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/running
public func running(req: HttpRequest, res: HttpResponse): Unit

/// POST /api/v1/uctoo/crontab/reload
public func reload(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/:id/next-exec
public func nextExec(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/executors
public func executors(req: HttpRequest, res: HttpResponse): Unit
```

---

# **14. 配置项设计**

| 配置项 | 环境变量 | 默认值 | 说明 |
|--------|----------|--------|------|
| 调度器开关 | CRONTAB_SCHEDULER_ENABLED | true | 是否启用调度引擎 |
| 脚本目录白名单 | CRONTAB_SCRIPT_DIRS | /opt/scripts | ScriptExecutor允许的目录 |
| HTTP黑名单 | CRONTAB_HTTP_BLACKLIST | 127.0.0.1,10.0.0.0/8 | HttpExecutor禁止访问的IP |
| 默认超时 | CRONTAB_DEFAULT_TIMEOUT | 300 | 默认任务超时(秒) |
| 默认重试次数 | CRONTAB_DEFAULT_MAX_RETRIES | 3 | 默认最大重试次数 |
| 日志队列大小 | CRONTAB_LOG_QUEUE_SIZE | 1000 | 异步日志缓冲队列大小 |
| 优雅关闭超时 | CRONTAB_SHUTDOWN_TIMEOUT | 30 | 优雅关闭等待时间(秒) |
| 日志保留天数 | CRONTAB_LOG_RETENTION_DAYS | 30 | 日志自动清理天数 |