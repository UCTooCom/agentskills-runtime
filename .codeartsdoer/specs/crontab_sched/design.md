# 计划任务调度系统（Crontab Scheduler）技术设计文档

## 文档信息
- **项目名称**: agentskills-runtime 计划任务调度系统
- **版本**: 2.1.0
- **创建日期**: 2026-05-17
- **最后更新**: 2026-05-18
- **作者**: spec-design-agent
- **状态**: 已完善（对照旧版本补充重试机制、优雅关闭、监控、安全、异步日志、方法签名、配置项等章节）
- **关联需求**: spec.md v1.0.0
- **目录规范**: 工程级目录 `.codeartsdoer/specs/crontab_sched/design.md`

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
│  │ (运维)   │          │          │  Scheduler   │                     │
│  └──────────┘          │          └──────────────┘                     │
│                         │              │                               │
│  ┌──────────┐          │              ├──> script:// (Shell脚本)       │
│  │ 定时触发 │<─────────┘              ├──> http://   (HTTP回调)        │
│  │ (Chrono) │                         └──> builtin:// (内置执行器)     │
│  └──────────┘                                                        │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │  日志系统 (异步写入)                                          │      │
│  │  crontab_log 表 + magic.log.LogUtils 文件日志                  │      │
│  └──────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

### 核心参与者

| 参与者 | 角色 | 交互方式 |
|--------|------|----------|
| 管理员/前端 | 创建/管理计划任务 | HTTP API |
| 运维人员 | 手动触发/调试任务 | CLI 命令 |
| f_ticktock 调度器 | 按CRON表达式自动触发 | 内部事件驱动 |
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
│  ┌──────┴──────────────────────────────────────────┐               │
│  │          ExecutorRegistry (执行器注册表)          │               │
│  └─────────────────────────────────────────────────┘               │
├────────────────────────────────────────────────────────────────────┤
│       数据层 (Data Access Layer)                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐         │
│  │  CrontabDAO  │  │CrontabLogDAO │  │TaskRegistryDAO   │         │
│  └──────────────┘  └──────────────┘  └──────────────────┘         │
├────────────────────────────────────────────────────────────────────┤
│       基础设施层 (Infrastructure)                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ Ticktock │  │  f_orm   │  │LogUtils  │  │ PermissionUtils │   │
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
              ├──> MisfireManager.checkAndHandle()   (错过执行检测)
              │
              ├──> RetryManager.executeWithRetry()    (重试包装)
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

**包路径**: `magic.app.services.crontab`

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
    
    /// 获取单例实例
    public static prop instance: Option<SchedulerEngine>
    
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

**包路径**: `magic.app.services.crontab.executor`

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

**包路径**: `magic.app.services.crontab.executor`

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

**包路径**: `magic.app.services.crontab.executor`

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

**包路径**: `magic.app.services.crontab.executor`

```cangjie
package magic.app.services.crontab.executor

/// 执行 http:// 协议的任务
/// 示例: http://localhost:8080/api/internal/cleanup
///       https://external-service/api/sync?force=true
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

**包路径**: `magic.app.services.crontab.executor`

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

**包路径**: `magic.app.services.crontab.misfire`

```cangjie
package magic.app.services.crontab.misfire

/// 错过执行策略（对应数据库 tactics 字段）
/// tactics=1: 立即执行 → FireNow
/// tactics=2: 执行一次 → FireOnce
/// tactics=3: 放弃执行 → Ignore
public enum MisfirePolicy {
    | FireNow         // 立即补执行一次 (tactics=1)
    | FireOnce        // 仅补执行一次 (tactics=2)
    | Ignore          // 忽略，继续正常调度 (tactics=3)
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

**包路径**: `magic.app.services.crontab.retry`

```cangjie
package magic.app.services.crontab.retry

public class RetryManager {
    /// 包装任务执行，加入重试逻辑
    public func executeWithRetry(
        crontab: CrontabPO,
        executor: CrontabExecutor,
        context: CrontabExecutionContext
    ): ExecutionResult
    
    /// 计算下一次重试的延迟时间
    public func calculateRetryDelay(
        attempt: Int32
    ): Int64  // 返回毫秒数，采用固定间隔策略
}
```

### 1.3.9 关键数据类型

**包路径**: `magic.app.services.crontab.model`

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

/// 触发类型（对应 crontab_log.trigger_type）
public enum TriggerType {
    | Cron         // CRON定时触发 → "cron"
    | Manual       // 手动触发(API/CLI) → "manual"
    | Misfire      // 错过执行补触发 → "misfire"
    | Retry        // 重试触发 → "retry"
    | SkippedConcurrent  // 并发冲突跳过 → "skipped_concurrent"
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
5. 响应格式遵循 UMI 全栈模型同构规范：单条直接返回实体对象，列表返回 `{表名}s` 键名

### CLI 设计原则
1. 命令入口: `skill crontab <sub-command> [options]`
2. 支持 `--format json` 输出格式用于脚本集成
3. CLI 命令复用 Service 层方法，不直接操作 DAO

## **2.2 接口清单**

### 2.2.1 HTTP API 接口

#### 现有 CRUD 接口（保持不变，兼容现有前端）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/uctoo/crontab/add` | 创建任务 |
| POST | `/api/v1/uctoo/crontab/edit` | 编辑任务 |
| POST | `/api/v1/uctoo/crontab/del` | 删除任务 |
| POST | `/api/v1/uctoo/crontab/empty-recycle-bin` | 清空回收站 |
| GET  | `/api/v1/uctoo/crontab/:id` | 查询单个任务 |
| GET  | `/api/v1/uctoo/crontab/:limit/:page` | 分页查询任务列表 |
| GET  | `/api/v1/uctoo/crontab/:limit/:page/:skip` | 分页查询（带跳过） |
| GET  | `/api/v1/uctoo/crontab/export` | 导出任务 |

#### 新增调度控制接口（在 CrontabRoute.registerCustomRoutes 中注册）

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/uctoo/crontab/trigger/:id` | 手动触发任务执行 | crontab:write |
| POST | `/api/v1/uctoo/crontab/pause/:id` | 暂停任务（group=2禁止） | crontab:write |
| POST | `/api/v1/uctoo/crontab/resume/:id` | 恢复任务 | crontab:write |
| POST | `/api/v1/uctoo/crontab/reload` | 重新加载所有任务到调度器 | crontab:write |
| GET  | `/api/v1/uctoo/crontab/scheduler/status` | 获取调度器运行状态 | crontab:read |
| GET  | `/api/v1/uctoo/crontab/running` | 获取正在执行的任务列表 | crontab:read |
| GET  | `/api/v1/uctoo/crontab/:id/runtime` | 获取单个任务运行时状态 | crontab:read |
| GET  | `/api/v1/uctoo/crontab/:id/next-exec` | 计算任务下次执行时间 | crontab:read |

#### 执行器注册表接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET  | `/api/v1/uctoo/crontab/executors` | 获取所有注册执行器 | crontab:read |
| GET  | `/api/v1/uctoo/crontab/builtin-tasks` | 获取所有内置任务 | crontab:read |

#### 执行日志扩展接口（在 CrontabLogRoute.registerCustomRoutes 中注册）

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
  pause <id>                      暂停任务
  resume <id>                     恢复任务
  reload                          重新加载所有任务
  status                          查看调度器状态
  logs [options]                  查看执行日志
  executors                       列出注册执行器

add/edit 选项:
  --name <value>        任务名称
  --group <value>       分组 (default: 1)
  --cron <value>        CRON表达式
  --task <value>        任务URI (script://|http://|builtin://)
  --tactics <value>     错过执行策略 (1:立即执行 2:执行一次 3:放弃)
  --timeout <seconds>   超时时间 (default: 0)
  --max-retries <n>     最大重试次数 (default: 0)
  --concurrent          允许并发执行
  --once                仅执行一次
  --priority <n>        优先级 (default: 0)
  --params <json>       参数JSON
  --misfire-threshold <seconds>  错过执行阈值 (default: 0)

通用选项:
  --format json         JSON格式输出
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
    ├── 任务注册方式（直接使用 Ticktock 提供的快捷方法）:
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
    └── 任务命名约定: "crontab:${id}" （确保全局唯一，与f_ticktock内部任务区分）
```

### f_ticktock 已提供的 API（无需修改源码）

| API | 说明 |
|-----|------|
| `Ticktock.instance` | 获取单例调度器（自动初始化） |
| `Ticktock.addOrReplaceTask(taskName!, taskCron!, execOnce!, concurrenctly!, executor!)` | 快捷注册CRON任务 |
| `Ticktock.removeTask(name)` | 按名称移除任务 |
| `Ticktock.shutdown()` | 关闭调度器 |
| `FuncCronTicktockTask` | 函数式CRON任务类，支持 execOnce 和 concurrenctly 参数 |

### 集成要点
1. **不修改 f_ticktock 源码**，仅通过其公开API操作
2. 使用 `Ticktock.addOrReplaceTask` 快捷方法动态注册，无需预定义类
3. 任务名采用 `crontab:${id}` 格式，与 f_ticktock 内部任务区分
4. 利用 `concurrenctly` 参数控制并发执行策略
5. 利用 `execOnce` 参数实现一次性任务
6. CRON 表达式使用 6 位格式（秒 分 时 日 月 周），与 f_ticktock 完全兼容

## **3.2 Application 启动流程变更**

**文件**: `src/app/main.cj` 中 `Application` 类

```cangjie
// Application 类新增成员变量:
private var schedulerEngine: ?SchedulerEngine = None

// init() 末尾新增（在 setupRoutes 之后）:
try {
    schedulerEngine = Some(SchedulerEngine.initialize())
    LogUtils.info("SchedulerEngine initialized successfully")
} catch (e: Exception) {
    LogUtils.error("Failed to initialize SchedulerEngine: ${e.message}")
}

// stop() 中新增（在 server.stop() 之前）:
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

## **3.3 cjpm.toml 依赖变更**

在项目根 `cjpm.toml` 的 `[dependencies]` 中新增:

```toml
[dependencies]
  # ... 现有依赖 ...
  f_ticktock = {path = "libs/fountain/f_ticktock", version = "1.0.45"}
```

**说明**: f_ticktock 已在本地 `libs/fountain/f_ticktock` 中存在，仅需在项目 cjpm.toml 中声明依赖即可。

## **3.4 AutoRouteConfig 变更**

Crontab 路由注册时注入 SchedulerEngine（在 AutoRouteConfig.initRegistry 中修改 Crontab 路由部分）:

```cangjie
// AutoRouteConfig.initRegistry() 中 Crontab 路由变更:
registry.add(RouteEntry(
    "crontab",
    "/api/v1/uctoo/crontab",
    10,
    true,
    { router: Router =>
        let service = CrontabService()
        let schedulerService = SchedulerService()
        let controller = CrontabController(service, schedulerService)
        let route = CrontabRoute(router, controller)
        route.register()
        route.registerCustomRoutes()  // 注册新增调度控制路由
    }
))
```

## **3.5 CLI 集成**

在 `SkillCLI.executeCommand()` 或 `main.cj` 的 CLI 入口中新增 `crontab` 子命令:

```cangjie
case "crontab" => executeCrontabCommand(subArgs)

private func executeCrontabCommand(args: Array<String>): Unit {
    let cli = CrontabCLI()
    cli.execute(args)
}
```

新增 `CrontabCLI` 类（package magic.cli）:

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
            case "pause"     => pauseCommand(args[1..])
            case "resume"    => resumeCommand(args[1..])
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

1. 向下兼容现有 crontab/crontab_log 表结构（现有 DDL 见 publicFull260503.sql）
2. 通过 ALTER TABLE 增量添加新字段，不破坏现有数据和 CRUD 接口
3. 新增 crontab_task_registry 表管理执行器注册
4. 所有时间字段使用 PostgreSQL timestamptz 类型
5. 所有主键使用 UUID（与现有表一致）
6. 新增字段提供合理默认值，确保现有数据兼容

## **4.2 模型实现**

### 4.2.1 现有 crontab 表结构（基线）

```sql
-- 现有字段（来自 publicFull260503.sql 第1827-1840行）
CREATE TABLE "public"."crontab" (
  "id"          uuid NOT NULL DEFAULT gen_random_uuid(),
  "name"        varchar NOT NULL,              -- 任务名称
  "group"       varchar NOT NULL DEFAULT '1',  -- 分组。1 默认 2 系统
  "task"        varchar NOT NULL,              -- 任务执行标识
  "cron"        varchar NOT NULL,              -- cron 表达式
  "tactics"     varchar NOT NULL,              -- 策略。1 立即执行 2 执行一次 3 放弃执行
  "remark"      varchar NOT NULL,              -- 备注
  "creator"     uuid,                          -- 创建人
  "created_at"  timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"  timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at"  timestamptz(6),                -- 删除时间（软删除）
  "status"      int4 NOT NULL DEFAULT 1        -- 状态。1 正常 2 禁用
);
```

### 4.2.2 crontab 表增量扩展 DDL

```sql
-- =====================================================
-- 增量迁移：不删除现有字段，仅新增调度引擎所需字段
-- 迁移脚本位置: scripts/migration/crontab_sched_v1.sql
-- =====================================================

-- 调度控制字段
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS timeout INT4 DEFAULT 0;
COMMENT ON COLUMN crontab.timeout IS '执行超时时间(秒)。0表示不限制';

ALTER TABLE crontab ADD COLUMN IF NOT EXISTS max_retries INT4 DEFAULT 0;
COMMENT ON COLUMN crontab.max_retries IS '最大重试次数。0表示不重试';

ALTER TABLE crontab ADD COLUMN IF NOT EXISTS retry_count INT4 DEFAULT 0;
COMMENT ON COLUMN crontab.retry_count IS '当前重试计数。系统自动维护';

ALTER TABLE crontab ADD COLUMN IF NOT EXISTS concurrentable BOOLEAN DEFAULT FALSE;
COMMENT ON COLUMN crontab.concurrentable IS '是否允许并发执行';

ALTER TABLE crontab ADD COLUMN IF NOT EXISTS once BOOLEAN DEFAULT FALSE;
COMMENT ON COLUMN crontab.once IS '是否为一次性任务';

ALTER TABLE crontab ADD COLUMN IF NOT EXISTS priority INT4 DEFAULT 0;
COMMENT ON COLUMN crontab.priority IS '任务优先级。数值越大优先级越高';

ALTER TABLE crontab ADD COLUMN IF NOT EXISTS parameters TEXT DEFAULT '{}';
COMMENT ON COLUMN crontab.parameters IS '任务执行参数(JSON格式)';

-- 错过执行控制字段
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS misfire_threshold INT4 DEFAULT 0;
COMMENT ON COLUMN crontab.misfire_threshold IS '错过执行阈值(秒)。0表示不限制';

-- 执行元数据字段（系统自动维护）
ALTER TABLE crontab ADD COLUMN IF NOT EXISTS last_executed_at TIMESTAMPTZ;
COMMENT ON COLUMN crontab.last_executed_at IS '上次执行时间';

ALTER TABLE crontab ADD COLUMN IF NOT EXISTS next_executed_at TIMESTAMPTZ;
COMMENT ON COLUMN crontab.next_executed_at IS '下次预计执行时间';

ALTER TABLE crontab ADD COLUMN IF NOT EXISTS exec_count INT4 DEFAULT 0;
COMMENT ON COLUMN crontab.exec_count IS '累计执行次数';

-- 索引
CREATE INDEX IF NOT EXISTS idx_crontab_status ON crontab(status);
CREATE INDEX IF NOT EXISTS idx_crontab_group ON crontab("group");
CREATE INDEX IF NOT EXISTS idx_crontab_next_exec ON crontab(next_executed_at) WHERE status = 1 AND deleted_at IS NULL;
```

### 4.2.3 CrontabPO 增强字段（在现有 CrontabPO 中追加）

**文件**: `src/app/models/uctoo/CrontabPO.cj`

```cangjie
// CrontabPO 新增字段（在现有 status 字段之后追加，在 //#endregion AutoCreateCode 之前）

    @ORMField['timeout']
    public var timeout: Int32 = 0

    @ORMField['max_retries']
    public var maxRetries: Int32 = 0

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
    public var misfireThreshold: Int32 = 0

    @ORMField['last_executed_at']
    public var lastExecutedAt: Option<DateTime> = None<DateTime>

    @ORMField['next_executed_at']
    public var nextExecutedAt: Option<DateTime> = None<DateTime>

    @ORMField['exec_count']
    public var execCount: Int32 = 0
```

**同步更新**: `toJsonValue()` 方法中追加新字段的序列化；全参数 `init()` 构造函数追加新参数；`CrontabDAO.insertCrontab()` 和 `updateCrontab()` 的 SQL 中追加新字段。

### 4.2.4 现有 crontab_log 表结构（基线）

```sql
-- 现有字段（来自 publicFull260503.sql 第1864-1874行）
CREATE TABLE "public"."crontab_log" (
  "id"           uuid NOT NULL DEFAULT gen_random_uuid(),
  "crontab_id"   uuid NOT NULL,                -- crontab 任务ID
  "used_time"    int4 NOT NULL DEFAULT 0,      -- 任务消耗时间
  "error_message" varchar NOT NULL,             -- 错误信息
  "status"       int4 NOT NULL DEFAULT 1,      -- 状态。1 成功 0 失败
  "creator"      uuid,                          -- 创建人
  "created_at"   timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"   timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at"   timestamptz(6)                -- 删除时间
);
```

### 4.2.5 crontab_log 表增量扩展 DDL

```sql
-- 执行时间字段
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ;
COMMENT ON COLUMN crontab_log.start_time IS '执行开始时间';

ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS end_time TIMESTAMPTZ;
COMMENT ON COLUMN crontab_log.end_time IS '执行结束时间';

-- 触发信息字段
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS trigger_type VARCHAR(20) DEFAULT 'cron';
COMMENT ON COLUMN crontab_log.trigger_type IS '触发类型。cron:定时触发 manual:手动触发 misfire:错过执行 retry:重试 skipped_concurrent:并发跳过';

ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS retry_attempt INT4 DEFAULT 0;
COMMENT ON COLUMN crontab_log.retry_attempt IS '重试序号。0表示首次执行';

-- 执行器信息字段
ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS executor_type VARCHAR(20) DEFAULT 'unknown';
COMMENT ON COLUMN crontab_log.executor_type IS '执行器类型。script/http/builtin';

ALTER TABLE crontab_log ADD COLUMN IF NOT EXISTS result_summary TEXT DEFAULT '';
COMMENT ON COLUMN crontab_log.result_summary IS '执行结果摘要';

-- 索引
CREATE INDEX IF NOT EXISTS idx_crontab_log_crontab_id ON crontab_log(crontab_id);
CREATE INDEX IF NOT EXISTS idx_crontab_log_start_time ON crontab_log(start_time);
CREATE INDEX IF NOT EXISTS idx_crontab_log_trigger_type ON crontab_log(trigger_type);
```

### 4.2.6 CrontabLogPO 增强字段

**文件**: `src/app/models/uctoo/CrontabLogPO.cj`

```cangjie
// CrontabLogPO 新增字段（在现有 deletedAt 字段之后追加）

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

### 4.2.7 新增 crontab_task_registry 表

```sql
CREATE TABLE IF NOT EXISTS crontab_task_registry (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type            VARCHAR(20) NOT NULL,           -- 执行器类型: script/http/builtin
    prefix          VARCHAR(50) NOT NULL UNIQUE,    -- 标识前缀: script://, http://, builtin://
    name            VARCHAR(100) NOT NULL UNIQUE,   -- 执行器名称
    description     TEXT DEFAULT '',                 -- 描述
    parameters_template TEXT DEFAULT '{}',           -- 参数模板(JSON)
    status          INT4 DEFAULT 1,                  -- 1:启用 2:禁用
    creator         UUID,                            -- 注册者
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ                      -- 软删除
);

COMMENT ON TABLE crontab_task_registry IS '任务执行器注册表';

-- 初始数据：三种内置执行器
INSERT INTO crontab_task_registry (type, prefix, name, description) VALUES
    ('script', 'script://', 'script-executor', '脚本执行器，执行本地脚本文件'),
    ('http', 'http://', 'http-executor', 'HTTP回调执行器，调用远程API'),
    ('builtin', 'builtin://', 'builtin-executor', '内置执行器，执行注册的内置任务')
ON CONFLICT (prefix) DO NOTHING;
```

### 4.2.8 CrontabTaskRegistryPO

**文件**: `src/app/models/uctoo/CrontabTaskRegistryPO.cj`（新增）

```cangjie
package magic.app.models.uctoo

@DataAssist[fields]
@QueryMappersGenerator["crontab_task_registry"]
public class CrontabTaskRegistryPO {
    @ORMField['id']
    public var id: String = ""

    @ORMField['type']
    public var type: String = ""

    @ORMField['prefix']
    public var prefix: String = ""

    @ORMField['name']
    public var name: String = ""

    @ORMField['description']
    public var description: String = ""

    @ORMField['parameters_template']
    public var parametersTemplate: String = "{}"

    @ORMField['status']
    public var status: Int32 = 1

    @ORMField['creator']
    public var creator: Option<String> = None<String>

    @ORMField['created_at']
    public var createdAt: DateTime = DateTime.now()

    @ORMField['updated_at']
    public var updatedAt: DateTime = DateTime.now()

    @ORMField['deleted_at']
    public var deletedAt: Option<DateTime> = None<DateTime>

    public init() {}
    
    // toJsonValue(), toJson() 等方法遵循 CrontabPO 相同模式
}
```

### 4.2.9 CrontabTaskRegistryDAO

**文件**: `src/app/dao/uctoo/CrontabTaskRegistryDAO.cj`（新增）

遵循现有 CrontabDAO 的 `@DAO` + `RootDAO` + `setSql` 模式，提供标准 CRUD 方法。

### 4.2.10 数据库迁移策略

| 阶段 | 操作 | 风险 | 回滚方案 |
|------|------|------|----------|
| Phase 1 | ALTER TABLE crontab ADD COLUMN (11个字段) | 低（仅新增，默认值兼容现有数据） | ALTER TABLE DROP COLUMN |
| Phase 2 | ALTER TABLE crontab_log ADD COLUMN (6个字段) | 低 | ALTER TABLE DROP COLUMN |
| Phase 3 | CREATE TABLE crontab_task_registry | 低 | DROP TABLE |
| Phase 4 | CREATE INDEX (6个索引) | 低 | DROP INDEX |
| Phase 5 | INSERT 初始执行器数据 | 低 | DELETE FROM |

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

2. 支持运行时动态注册/注销

---

# **6. 错过执行策略设计**

## **6.1 检测机制**

```
每次 Ticktock 触发前:
  1. 读取 crontab.last_executed_at 和 crontab.next_executed_at
  2. 计算当前时间与上次执行时间的差值
  3. 如果差值 > misfire_threshold 秒（且 misfire_threshold > 0）:
     → 判定为错过执行
  4. 根据 tactics 字段决定处理方式:
     - tactics=1: 立即执行 (FireNow)
     - tactics=2: 执行一次 (FireOnce)
     - tactics=3: 放弃执行 (Ignore)
```

## **6.2 策略行为**

| tactics值 | 策略名 | 行为 | 适用场景 |
|-----------|--------|------|----------|
| 1 | FireNow | 立即补执行一次，然后恢复正常计划 | 适用于不能遗漏的关键任务 |
| 2 | FireOnce | 仅补执行一次（不论错过多少次） | 适用于幂等任务 |
| 3 | Ignore | 跳过错过的执行，按正常计划继续 | 默认，适用于频率高的任务 |

## **6.3 数据更新**

```cangjie
// 每次成功触发后:
crontab.lastExecutedAt = Some(now)
crontab.nextExecutedAt = Some(CronCompiler.nextExecution(cron, now))
crontab.execCount += 1
CrontabDAO.updateExecutionMeta(crontab)
```

---

# **7. 新增文件清单**

## **7.1 新增文件**

| 文件路径 | 说明 |
|----------|------|
| `src/app/services/crontab/SchedulerEngine.cj` | 调度引擎核心 |
| `src/app/services/crontab/SchedulerService.cj` | 调度服务层（供Controller调用） |
| `src/app/services/crontab/executor/ExecutorRegistry.cj` | 执行器注册表 |
| `src/app/services/crontab/executor/CrontabExecutor.cj` | 执行器接口 |
| `src/app/services/crontab/executor/ScriptExecutor.cj` | 脚本执行器 |
| `src/app/services/crontab/executor/HttpExecutor.cj` | HTTP执行器 |
| `src/app/services/crontab/executor/BuiltinExecutor.cj` | 内置执行器 |
| `src/app/services/crontab/executor/BuiltinTaskHandler.cj` | 内置任务处理器接口 |
| `src/app/services/crontab/executor/builtin/DatabaseCleanupHandler.cj` | 数据库清理处理器 |
| `src/app/services/crontab/executor/builtin/CacheRefreshHandler.cj` | 缓存刷新处理器 |
| `src/app/services/crontab/executor/builtin/LogRotationHandler.cj` | 日志轮转处理器 |
| `src/app/services/crontab/executor/builtin/HealthCheckHandler.cj` | 健康检查处理器 |
| `src/app/services/crontab/executor/builtin/MetricsReportHandler.cj` | 指标上报处理器 |
| `src/app/services/crontab/misfire/MisfireManager.cj` | 错过执行管理器 |
| `src/app/services/crontab/misfire/MisfirePolicy.cj` | 错过执行策略枚举 |
| `src/app/services/crontab/retry/RetryManager.cj` | 重试管理器 |
| `src/app/services/crontab/model/CrontabExecutionContext.cj` | 执行上下文 |
| `src/app/services/crontab/model/TriggerType.cj` | 触发类型枚举 |
| `src/app/services/crontab/model/ExecutionResult.cj` | 执行结果 |
| `src/app/services/crontab/model/SchedulerStatus.cj` | 调度器状态 |
| `src/app/models/uctoo/CrontabTaskRegistryPO.cj` | 执行器注册表PO |
| `src/app/dao/uctoo/CrontabTaskRegistryDAO.cj` | 执行器注册表DAO |
| `src/cli/CrontabCLI.cj` | CLI命令处理 |
| `scripts/migration/crontab_sched_v1.sql` | 数据库迁移脚本 |

## **7.2 需修改的现有文件**

| 文件路径 | 修改内容 |
|----------|----------|
| `src/app/models/uctoo/CrontabPO.cj` | 追加11个新字段、更新toJsonValue/init/构造函数 |
| `src/app/models/uctoo/CrontabLogPO.cj` | 追加6个新字段、更新toJsonValue/init/构造函数 |
| `src/app/dao/uctoo/CrontabDAO.cj` | insert/update SQL追加新字段、新增updateExecutionMeta方法 |
| `src/app/dao/uctoo/CrontabLogDAO.cj` | insert SQL追加新字段、新增按crontabId查询等方法 |
| `src/app/services/uctoo/CrontabService.cj` | 新增调度联动方法（创建后注册、删除后移除等） |
| `src/app/controllers/uctoo/crontab/CrontabController.cj` | 新增trigger/pause/resume/status等Controller方法 |
| `src/app/routes/uctoo/crontab/CrontabRoute.cj` | registerCustomRoutes中注册新增调度控制路由 |
| `src/app/main.cj` (Application) | 新增SchedulerEngine初始化和优雅关闭 |
| `src/app/registry/AutoRouteConfig.cj` | Crontab路由注册时注入SchedulerService |
| `cjpm.toml` | 新增f_ticktock依赖声明 |

---

# **8. 重试机制详细设计**

## **8.1 重试流程**

```
任务执行失败时:
  1. 检查 retry_count < max_retries
  2. 如果可以重试:
     - retry_count += 1
     - 计算延迟时间（根据重试策略）
     - 创建 DelayedTicktockTask 延迟重试
     - 写入日志（trigger_type = 'retry', retry_attempt = retry_count）
  3. 如果达到最大重试次数:
     - 标记任务最终失败（重试耗尽）
     - 写入日志（status = 0, error_message 包含最终错误与重试耗尽标识）
```

## **8.2 重试策略**

| 策略 | 延迟计算 | 示例 | 适用场景 |
|------|----------|------|----------|
| FixedDelay(base) | delay = base | FixedDelay(5s) → 每次等待5秒 | 简单场景，失败原因固定 |
| ExponentialBackoff(base, multiplier) | delay = base × multiplier^attempt | ExponentialBackoff(2s, 2.0) → 2s → 4s → 8s → 16s | 外部服务调用，避免雪崩 |

**策略选择原则**：
- HTTP 调用器默认使用指数退避（ExponentialBackoff），避免对下游服务造成重试风暴
- 脚本执行器和内置执行器默认使用固定间隔（FixedDelay）
- 最大延迟上限为 300 秒，超过则截断

```cangjie
package magic.app.services.crontab.retry

/// 重试策略
public enum RetryStrategy {
    | FixedDelay(Int64)                              // 固定间隔(毫秒)
    | ExponentialBackoff(Int64, Float64)             // 指数退避(基础间隔毫秒, 乘数)
}

/// 重试策略扩展方法
public extend RetryStrategy {
    /// 计算第 attempt 次重试的延迟时间(毫秒)
    public func calculateDelay(attempt: Int32): Int64 {
        match (this) {
            case FixedDelay(base) =>
                base
            case ExponentialBackoff(base, multiplier) =>
                let delay = base * (multiplier ^ attempt.toFloat64()).toInt64()
                // 最大延迟上限 300 秒
                if (delay > 300000) { 300000 } else { delay }
        }
    }
}
```

## **8.3 重试状态追踪**

| 字段 | 位置 | 说明 |
|------|------|------|
| `crontab.retry_count` | crontab 表 | 当前重试计数，每次重试递增，成功后重置为 0 |
| `crontab_log.retry_attempt` | crontab_log 表 | 本次日志对应第几次重试（0=首次执行） |
| `crontab_log.trigger_type = 'retry'` | crontab_log 表 | 标识重试触发的日志记录 |

**状态转换**：
- 正常执行失败 → retry_count=0，若 max_retries>0 则 retry_count += 1 并触发重试
- 第 N 次重试失败 → retry_count=N，若 N < max_retries 则继续重试
- 第 N 次重试成功 → retry_count 重置为 0，恢复正常调度
- retry_count >= max_retries → 标记重试耗尽，下次 CRON 触发时 retry_count 重置为 0

## **8.4 重试耗尽处理**

当任务重试次数达到 max_retries 仍失败时：

1. 写入最终失败执行日志，error_message 追加 `[RETRY_EXHAUSTED]` 标识
2. 不自动禁用任务（与 Quartz 等框架不同），允许下次 CRON 触发时正常调度
3. 下次正常触发时，retry_count 重置为 0，开始新一轮执行-重试循环
4. 可通过监控指标 `crontab_retry_exhausted_total` 触发告警

---

# **9. 优雅关闭详细设计**

## **9.1 关闭流程**

```
收到 SIGTERM/SIGINT 信号:
  1. 标记调度器为关闭中状态（拒绝新任务触发和 API 请求）
     └── SchedulerEngine.shuttingDown = true
  
  2. 停止 Ticktock 时钟脉冲
     └── Ticktock.shutdown() 停止 Chrono 时钟
  
  3. 等待运行中任务完成
     └── 循环检查 runningTasks，每秒打印等待进度
     └── 超时后（默认30秒）强制终止未完成任务
     
  4. 取消所有待执行的重试任务
  
  5. 关闭异步日志写入器
     └── AsyncLogWriter.close(timeout: 10s) 等待队列消费完
  
  6. 写入最终状态
     └── 更新每个活跃任务的 crontab.next_executed_at（便于重启后错过执行检测）
     
  7. 释放 Ticktock 资源
     └── Ticktock.shutdown() 确认完成
```

## **9.2 ShutdownHook 注册**

```cangjie
// SchedulerEngine.initialize() 中注册进程退出钩子:
env.atExit {
    gracefulShutdown(Duration.second * 30)
}
```

## **9.3 运行中任务追踪**

```cangjie
// 任务开始执行时:
runningTasks.put(crontabId, context)

// 任务执行完成时（无论成功/失败）:
runningTasks.remove(crontabId)

// 优雅关闭时检查:
public func gracefulShutdown(timeout: Duration): Unit {
    shuttingDown = true
    ticktock.shutdown()  // 停止时钟脉冲
    
    let deadline = DateTime.now() + timeout
    while (runningTasks.size > 0 && DateTime.now() < deadline) {
        LogUtils.info("Waiting for ${runningTasks.size} running tasks to complete...")
        Thread.sleep(Duration.second)  // 每秒打印进度
    }
    
    if (runningTasks.size > 0) {
        LogUtils.warn("Force terminating ${runningTasks.size} tasks after timeout")
        // 强制终止逻辑
    }
    
    asyncLogWriter.close(Duration.second * 10)
    // 更新所有活跃任务的 next_executed_at
}
```

## **9.4 关闭期间行为约束**

| 操作 | 关闭期间行为 |
|------|-------------|
| CRON 时钟触发 | 跳过，不启动新执行 |
| 手动触发 API | 返回 503 Service Unavailable |
| 调度管理 API（pause/resume/reload） | 返回 503 Service Unavailable |
| 状态查询 API | 正常返回（只读） |
| CLI 命令 | 输出"服务正在关闭，请稍后重试" |

---

# **10. 监控设计**

## **10.1 指标采集**

| 指标名 | 类型 | 说明 | 采集来源 |
|--------|------|------|----------|
| `crontab_tasks_total` | Gauge | 注册任务总数 | Ticktock.getTaskCount() |
| `crontab_tasks_active` | Gauge | 活跃任务数（status=1） | DB 查询 |
| `crontab_tasks_running` | Gauge | 正在执行的任务数 | runningTasks.size |
| `crontab_executions_total` | Counter | 总执行次数 | 执行完成时递增 |
| `crontab_executions_success` | Counter | 成功执行次数 | 执行成功时递增 |
| `crontab_executions_failed` | Counter | 失败执行次数 | 执行失败时递增 |
| `crontab_execution_duration_ms` | Histogram | 执行耗时分布(毫秒) | ExecutionResult.duration |
| `crontab_misfire_total` | Counter | 错过执行次数 | MisfireManager 检测到错过时递增 |
| `crontab_retry_total` | Counter | 重试次数 | RetryManager 触发重试时递增 |
| `crontab_retry_exhausted_total` | Counter | 重试耗尽次数 | 重试达到上限仍失败时递增 |

## **10.2 结构化日志规范**

### 调度引擎日志

```
[SchedulerEngine] Task triggered: id=${id}, name=${name}, trigger=${type}
[SchedulerEngine] Task completed: id=${id}, name=${name}, duration=${ms}ms, success=${bool}
[SchedulerEngine] Task failed: id=${id}, name=${name}, error=${msg}, retry=${attempt}/${max}
[SchedulerEngine] Misfire detected: id=${id}, name=${name}, missed=${count}, policy=${policy}
[SchedulerEngine] Retry exhausted: id=${id}, name=${name}, maxRetries=${max}
[SchedulerEngine] Shutdown: waiting ${running} tasks, timeout=${sec}s
[SchedulerEngine] Initialized: loaded ${count} tasks, ticktock=${status}
```

### 执行器日志

```
[ScriptExecutor] Executing: path=${path}, pid=${pid}, timeout=${sec}s
[ScriptExecutor] Completed: path=${path}, exitCode=${code}, duration=${ms}ms
[HttpExecutor] Request: POST ${url}, timeout=${sec}s
[HttpExecutor] Response: url=${url}, status=${statusCode}, duration=${ms}ms
[BuiltinExecutor] Executing builtin: name=${name}
[BuiltinExecutor] Completed: name=${name}, success=${bool}, duration=${ms}ms
```

### 日志格式要求

- 使用项目现有 `magic.log.LogUtils` 框架输出（与项目中 EntityController/AIController 等保持一致）
- 调用方式：`import magic.log.LogUtils`，使用 `LogUtils.info("Tag", "message")`、`LogUtils.error("Tag", "message")`、`LogUtils.warn("Tag", "message")`、`LogUtils.debug("Tag", "message")`
- 每条日志必须包含 `id` 和 `name` 字段用于任务追踪
- 错误日志包含错误摘要，但不暴露内部路径和凭证
- 执行结果输出截断至 2000 字符

## **10.3 健康检查**

在现有 `/api/v1/health` 端点中扩展调度器状态：

```json
{
  "status": "ok",
  "version": "0.0.20",
  "scheduler": {
    "running": true,
    "totalTasks": 15,
    "activeTasks": 12,
    "runningTasks": 2,
    "uptime": "2h30m15s"
  }
}
```

**健康判定规则**：
- 调度引擎未初始化 → `"scheduler": {"running": false}`
- 调度引擎关闭中 → `"scheduler": {"running": false, "state": "shutting_down"}`
- 正常运行 → `"scheduler": {"running": true, ...}`

---

# **11. 安全设计**

## **11.1 API 安全**

### 认证与授权

- 所有 crontab API 受 JWT 认证保护（复用现有中间件）
- RBAC 权限节点：`crontab:read` / `crontab:write` / `crontab:delete`
- 行级权限：通过 `PermissionUtils.checkWritePermission()` 控制，与现有 CRUD 接口保持一致
- CLI 命令复用 agentskills-runtime 的鉴权机制

### 系统任务保护

```cangjie
// group=2 的系统任务保护逻辑（在 Controller 层拦截）:

/// 删除保护
func delete(entityId: String, ...): APIResult {
    let existing = findCrontabById(entityId)
    if (existing.group == "2") {
        return APIResult(false, "系统任务不允许删除")
    }
    // 正常删除流程
}

/// 禁用保护
func pause(entityId: String, ...): APIResult {
    let existing = findCrontabById(entityId)
    if (existing.group == "2") {
        return APIResult(false, "系统任务不允许禁用")
    }
    // 正常禁用流程
}
```

### CRON 表达式注入防护

```cangjie
// 创建/编辑任务时验证 CRON 表达式合法性，防止注入攻击:
func validateCronExpression(cron: String): Bool {
    // 1. 长度检查：最大100字符
    if (cron.size > 100) { return false }
    // 2. 编译验证：通过 CronCompiler.compile() 编译
    try {
        CronCompiler.compile(cron)
        return true
    } catch (e: Exception) {
        return false
    }
}
```

## **11.2 执行器安全**

### ScriptExecutor 安全

| 安全项 | 实现方式 | 配置项 |
|--------|----------|--------|
| 脚本路径白名单 | 仅允许在白名单目录下执行脚本 | `CRONTAB_SCRIPT_DIRS`（默认: `/opt/scripts`） |
| 路径穿越防护 | 检测并拒绝含 `..` 的路径 | 内置校验 |
| 子进程权限降级 | 以低权限用户运行子进程 | 系统级配置 |
| 执行超时 | 超时后强制 kill 子进程 | `crontab.timeout` |
| 输出截断 | stdout/stderr 截断至 2000 字符 | 内置限制 |

```cangjie
/// ScriptExecutor 安全校验
private func validateScriptPath(path: String): Bool {
    // 1. 路径穿越检测
    if (path.contains("..")) { return false }
    // 2. 白名单目录检查
    let allowedDirs = ConfigUtils.getString("CRONTAB_SCRIPT_DIRS", "/opt/scripts").split(",")
    for (dir in allowedDirs) {
        if (path.startsWith(dir.trim())) { return true }
    }
    return false
}
```

### HttpExecutor 安全

| 安全项 | 实现方式 | 配置项 |
|--------|----------|--------|
| 协议限制 | 仅允许 http:// 和 https:// 协议 | 内置校验 |
| SSRF 防护 | 内网 IP 黑名单，禁止访问内部服务 | `CRONTAB_HTTP_BLACKLIST`（默认: `127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16`） |
| 请求超时 | 不超过任务的 timeout 设置 | `crontab.timeout` |
| 重定向限制 | 不自动跟随重定向（防止无限循环） | 内置限制 |
| 响应体截断 | 截断至 2000 字符 | 内置限制 |

```cangjie
/// HttpExecutor SSRF 防护
private func isBlockedHost(url: String): Bool {
    let blacklist = ConfigUtils.getString("CRONTAB_HTTP_BLACKLIST", 
        "127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16").split(",")
    // 解析 URL 的 host，检查是否在黑名单网段内
    let host = parseHost(url)
    for (cidr in blacklist) {
        if (isInNetwork(host, cidr.trim())) { return true }
    }
    return false
}
```

### BuiltinExecutor 安全

| 安全项 | 实现方式 |
|--------|----------|
| 白名单校验 | 仅允许执行在 `crontab_task_registry` 中注册的内置任务 |
| 标识注入防护 | 内置任务名称仅允许字母、数字、连字符（`[a-zA-Z0-9-]+`） |
| 异常隔离 | 内置任务处理器异常不传播到调度引擎，捕获后记录到执行日志 |

## **11.3 日志安全**

| 安全项 | 实现方式 |
|--------|----------|
| 敏感参数脱敏 | `parameters` 中 `password`/`token`/`secret`/`key` 等字段值替换为 `***` |
| 执行输出截断 | `resultSummary` 和 `error_message` 最大 2000 字符，防止日志膨胀攻击 |
| 内部路径隐藏 | 错误信息中不暴露服务器内部路径和堆栈详情 |
| 系统凭证隐藏 | 错误信息中不暴露数据库连接串、API 密钥等凭证信息 |

```cangjie
/// 参数脱敏
private func sanitizeParameters(params: String): String {
    // 对 password/token/secret/key 等敏感字段的值替换为 ***
    // 正则匹配: ("password"|"token"|"secret"|"key")\s*:\s*"[^"]*" → $1: "***"
}
```

---

# **12. 异步日志写入设计**

## **12.1 AsyncLogWriter**

**包路径**: `magic.app.services.crontab.log`

```cangjie
package magic.app.services.crontab.log

/// 异步日志写入器
/// 避免日志写入阻塞调度线程，使用 Channel 实现生产者-消费者模式
public class AsyncLogWriter {
    // 日志缓冲队列（有界，防内存溢出）
    private let queue: Channel<CrontabLogPO>
    
    // 队列容量（从配置读取）
    private static let QUEUE_CAPACITY = ConfigUtils.getInt("CRONTAB_LOG_QUEUE_SIZE", 1000)
    
    // 消费线程
    private var consumerThread: ?Thread
    
    // 运行标志
    private var isRunning: AtomicBool
    
    /// 初始化：启动消费线程
    public func start(): Unit {
        isRunning.set(true)
        consumerThread = Some(spawn {
            consume()
        })
    }
    
    /// 写入日志（非阻塞，放入队列）
    /// 队列满时丢弃最早的日志条目并记录告警
    public func writeLog(log: CrontabLogPO): Unit {
        if (!isRunning.get()) { return }
        match (queue.trySend(log)) {
            case true => {}  // 入队成功
            case false => LogUtils.warn("[AsyncLogWriter] Queue full, log entry dropped: crontabId=${log.crontabId}")
        }
    }
    
    /// 批量写入（消费者线程循环调用）
    private func consume(): Unit {
        while (isRunning.get() || queue.size > 0) {
            // 从队列批量取出（最多100条或等待1秒）
            let batch = queue.tryReceiveBatch(maxSize: 100, timeout: Duration.second)
            if (batch.size > 0) {
                try {
                    CrontabLogDAO.batchInsert(batch)  // 批量INSERT
                } catch (e: Exception) {
                    LogUtils.error("[AsyncLogWriter] Batch insert failed: ${e.message}, retrying...")
                    try {
                        CrontabLogDAO.batchInsert(batch)  // 重试一次
                    } catch (e2: Exception) {
                        LogUtils.error("[AsyncLogWriter] Retry failed, ${batch.size} logs lost")
                    }
                }
            }
        }
    }
    
    /// 关闭（等待队列消费完或超时）
    public func close(timeout: Duration): Unit {
        isRunning.set(false)
        // 等待消费线程结束
        if (let Some(t) <- consumerThread) {
            t.join(timeout)  // 等待超时后强制退出
        }
    }
}
```

## **12.2 日志写入流程**

```
任务执行完成
    │
    ├── 构造 CrontabLogPO 对象
    │       ├── crontabId        ← 执行上下文中的任务ID
    │       ├── startTime        ← 执行开始时间
    │       ├── endTime          ← 执行结束时间
    │       ├── usedTime         ← (endTime - startTime) 毫秒
    │       ├── status           ← success ? 1 : 0
    │       ├── errorMessage     ← 错误信息（截断2000字符，脱敏）
    │       ├── triggerType      ← 触发类型(cron/manual/misfire/retry/skipped_concurrent)
    │       ├── retryAttempt     ← 当前重试序号
    │       ├── executorType     ← 执行器类型(script/http/builtin)
    │       └── resultSummary    ← 执行结果摘要（截断2000字符）
    │
    └── AsyncLogWriter.writeLog(logPO)  [非阻塞，微秒级入队]
            │
            └── [异步消费线程] 
                    └── CrontabLogDAO.batchInsert(logs)  [批量写入，默认100条/批]
```

## **12.3 日志清理策略**

| 策略 | 实现方式 | 配置项 |
|------|----------|--------|
| 定期清理 | 内置任务 `builtin://log-rotation` 每日自动清理过期日志 | `CRONTAB_LOG_RETENTION_DAYS`（默认: 30天） |
| 清理规则 | 删除 `created_at < NOW() - RETENTION_DAYS` 且 `id` 不在7天保护期内的日志 | 内置逻辑 |
| 保护期 | 禁止删除 7 天内的执行日志 | 内置硬编码 |
| 清理方式 | 按日分批 DELETE（每批 1000 条），避免长事务锁表 | 内置逻辑 |

---

# **13. 关键方法签名汇总**

## CrontabService（增强）

**文件**: `src/app/services/uctoo/CrontabService.cj`

```cangjie
// 现有方法保持不变，新增以下方法:

/// 手动触发任务
public func triggerTask(crontabId: String, userId: String): APIResult<CrontabLogPO>

/// 暂停任务（group=2禁止）
public func pauseTask(crontabId: String, userId: String): APIResult<CrontabPO>

/// 恢复任务
public func resumeTask(crontabId: String, userId: String): APIResult<CrontabPO>

/// 重新加载所有任务到调度器
public func reloadAllTasks(): APIResult<Bool>

/// 获取调度器状态
public func getSchedulerStatus(): APIResult<SchedulerStatus>

/// 获取运行中任务
public func getRunningTasks(): APIResult<ArrayList<CrontabExecutionContext>>

/// 获取单个任务运行时状态
public func getTaskRuntimeStatus(crontabId: String): APIResult<TaskRuntimeStatus>

/// 计算下次执行时间
public func calculateNextExecution(crontabId: String): APIResult<DateTime>
```

## SchedulerService（新增）

**文件**: `src/app/services/crontab/SchedulerService.cj`

```cangjie
/// 调度服务层（供Controller调用，封装SchedulerEngine操作）
public class SchedulerService {
    /// 手动触发任务
    public func triggerTask(crontabId: String): ExecutionResult
    
    /// 暂停任务
    public func pauseTask(crontabId: String): Unit
    
    /// 恢复任务
    public func resumeTask(crontabId: String): Unit
    
    /// 重新加载所有任务
    public func reloadAllTasks(): Unit
    
    /// 获取调度器状态
    public func getSchedulerStatus(): SchedulerStatus
    
    /// 获取运行中任务
    public func getRunningTasks(): ArrayList<CrontabExecutionContext>
    
    /// 获取单个任务运行时状态
    public func getTaskRuntimeStatus(crontabId: String): TaskRuntimeStatus
    
    /// 计算下次执行时间
    public func calculateNextExecution(crontabId: String): Option<DateTime>
}
```

## CrontabDAO（增强）

**文件**: `src/app/dao/uctoo/CrontabDAO.cj`

```cangjie
// 新增方法:

/// 查询所有活跃任务（status=1，未软删除）
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

/// 批量更新 next_executed_at（优雅关闭时调用）
func batchUpdateNextExecutedAt(ids: ArrayList<String>, nextTimes: ArrayList<Option<DateTime>>): Int64
```

## CrontabLogDAO（增强）

**文件**: `src/app/dao/uctoo/CrontabLogDAO.cj`

```cangjie
// 新增方法:

/// 批量插入日志（异步写入器调用）
func batchInsert(logs: ArrayList<CrontabLogPO>): Int64

/// 按任务ID查询最近日志
func findRecentByCrontabId(crontabId: String, limit: Int64): ArrayList<CrontabLogPO>

/// 查询最近执行日志（全局）
func findRecentLogs(limit: Int64): ArrayList<CrontabLogPO>

/// 按时间范围统计执行结果
func getStatsByTimeRange(since: DateTime): ExecutionStats
```

## CrontabController（增强）

**文件**: `src/app/controllers/uctoo/crontab/CrontabController.cj`

```cangjie
// 新增Action方法（在 registerCustomRoutes 中注册）:

/// POST /api/v1/uctoo/crontab/trigger/:id
public func trigger(req: HttpRequest, res: HttpResponse): Unit

/// POST /api/v1/uctoo/crontab/pause/:id
public func pause(req: HttpRequest, res: HttpResponse): Unit

/// POST /api/v1/uctoo/crontab/resume/:id
public func resume(req: HttpRequest, res: HttpResponse): Unit

/// POST /api/v1/uctoo/crontab/reload
public func reload(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/scheduler/status
public func schedulerStatus(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/running
public func running(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/:id/runtime
public func runtime(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/:id/next-exec
public func nextExec(req: HttpRequest, res: HttpResponse): Unit

/// GET /api/v1/uctoo/crontab/executors
public func executors(req: HttpRequest, res: HttpResponse): Unit
```

---

# **14. 配置项设计**

| 配置项 | 环境变量 | 默认值 | 说明 |
|--------|----------|--------|------|
| 调度器开关 | `CRONTAB_SCHEDULER_ENABLED` | `true` | 是否启用调度引擎（设为 false 则跳过初始化） |
| 脚本目录白名单 | `CRONTAB_SCRIPT_DIRS` | `/opt/scripts` | ScriptExecutor 允许执行的目录，逗号分隔 |
| HTTP 黑名单 | `CRONTAB_HTTP_BLACKLIST` | `127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` | HttpExecutor 禁止访问的内网 IP/网段，逗号分隔 |
| 默认超时 | `CRONTAB_DEFAULT_TIMEOUT` | `0` | 默认任务超时(秒)，0 表示不限制 |
| 默认重试次数 | `CRONTAB_DEFAULT_MAX_RETRIES` | `0` | 默认最大重试次数，0 表示不重试 |
| 日志队列大小 | `CRONTAB_LOG_QUEUE_SIZE` | `1000` | 异步日志缓冲队列容量 |
| 优雅关闭超时 | `CRONTAB_SHUTDOWN_TIMEOUT` | `30` | 优雅关闭等待时间(秒) |
| 日志保留天数 | `CRONTAB_LOG_RETENTION_DAYS` | `30` | 执行日志自动清理保留天数 |
| 重试延迟上限 | `CRONTAB_RETRY_MAX_DELAY` | `300` | 指数退避最大延迟(秒) |

**配置读取方式**：通过 `ConfigUtils.getString(key, defaultValue)` 或 `ConfigUtils.getInt(key, defaultValue)` 读取，支持环境变量覆盖。

---

# **15. 模块目录结构**

```
src/app/
├── models/uctoo/
│   ├── CrontabPO.cj              (增强: 新增11个字段)
│   ├── CrontabLogPO.cj           (增强: 新增6个字段)
│   └── CrontabTaskRegistryPO.cj  (新增)
├── dao/uctoo/
│   ├── CrontabDAO.cj             (增强: 新增查询方法)
│   ├── CrontabLogDAO.cj          (增强: 新增批量写入/统计方法)
│   └── CrontabTaskRegistryDAO.cj (新增)
├── services/uctoo/
│   ├── CrontabService.cj         (增强: 调度控制方法)
│   └── CrontabLogService.cj      (增强: 统计查询方法)
├── services/crontab/             (新增目录)
│   ├── SchedulerEngine.cj        (调度引擎核心)
│   ├── SchedulerService.cj       (调度服务层)
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
│   │       ├── LogRotationHandler.cj
│   │       └── HealthCheckHandler.cj
│   └── log/                      (异步日志写入)
│       └── AsyncLogWriter.cj
├── controllers/uctoo/crontab/
│   └── CrontabController.cj      (增强: 调度控制Action)
├── routes/uctoo/crontab/
│   └── CrontabRoute.cj           (增强: 调度控制路由)
└── registry/
    └── AutoRouteConfig.cj        (增强: 注入SchedulerService)

src/cli/
├── skill_cli.cj                  (增强: 新增crontab子命令)
└── crontab_cli.cj                (新增: 计划任务CLI)

scripts/migration/
└── crontab_sched_v1.sql          (数据库迁移脚本)
```

---

# **16. 需求覆盖追踪**

| spec.md 核心能力章节 | design.md 对应设计 | 覆盖状态 |
|----------------------|-------------------|----------|
| 5.1 调度引擎集成与初始化 | 1.3.1 SchedulerEngine + 3.2 Application变更 | ✅ |
| 5.2 任务注册与动态管理 | 1.3.1 reloadTask/removeTask + 2.2.1 调度控制API | ✅ |
| 5.3 任务执行与执行器 | 1.3.2-1.3.6 执行器体系 + 5.1-5.4 执行器详细设计 | ✅ |
| 5.4 失败重试机制 | 1.3.8 RetryManager + 第8章重试机制详细设计 | ✅ |
| 5.5 一次性任务管理 | FuncCronTicktockTask.execOnce + SchedulerEngine逻辑 | ✅ |
| 5.6 执行日志记录 | 4.2.5-4.2.6 crontab_log增强 + 第12章异步日志写入设计 | ✅ |
| 5.7 错过执行策略处理 | 1.3.7 MisfireManager + 第6章详细设计 | ✅ |
| 5.8 任务执行器注册与管理 | 4.2.7-4.2.9 crontab_task_registry + ExecutorRegistry | ✅ |
| 5.9 系统任务保护 | 第11章安全设计(系统任务保护) + 2.1 API设计原则(第4条) | ✅ |
| 5.10 优雅关闭 | 1.3.1 gracefulShutdown + 第9章优雅关闭详细设计 | ✅ |
| 5.11 运行状态监控 | 第10章监控设计 + 2.2.1 scheduler/status + running + runtime API | ✅ |
| 5.12 CLI命令行管理 | 2.2.2 CLI命令体系 + 3.5 CLI集成 | ✅ |
| 4.1 性能约束 | 第10章指标采集 + 第12章异步日志写入 | ✅ |
| 4.2 可靠性约束 | 第8章重试机制 + 第9章优雅关闭 + 第12章异步日志写入 | ✅ |
| 4.3 安全性约束 | 第11章安全设计（API安全+执行器安全+日志安全） | ✅ |
| 4.4 可维护性约束 | 第10章结构化日志规范 + 第10章健康检查 + 第14章配置项设计 | ✅ |
| 4.5 兼容性约束 | 4.2 数据模型（增量扩展+默认值兼容）+ 2.1 API设计原则 | ✅ |
| 6.1-6.4 数据约束 | 4.2 数据模型设计（完全对齐spec数据约束） | ✅ |
| 7.1 打包发布DLL依赖修复 | 第17章补充设计（DLL复制修复方案） | ✅ |
| 7.2 测试脚本 | 第18章补充设计（Python测试脚本方案） | ✅ |

---

# **17. 补充设计：打包发布程序DLL依赖修复**

## **17.1 问题分析**

### 17.1.1 运行时报错清单

| 编号 | 报错信息 | 根因分析 |
|------|----------|----------|
| 1 | "无法定位程序输入点 magic.app.dao.uctoo:CrontabDAO.ti 于动态链接库 magic.app.exe 上" | `libmagic.app.dao.uctoo.dll` 为旧版本，不含新增的 CrontabDAO 类型信息（ti） |
| 2 | "无法定位程序输入点...CrontabPO14lastExecutedAt...于 libmagic.app.services.crontab.misfire.dll 上" | misfire 模块依赖的 CrontabPO 新增字段（lastExecutedAt）所在 DLL 版本不匹配 |
| 3 | "magic.app.dao.uctoo:CrontabLogDAO.ti 于 libmagic.app.services.crontab.log.dll 上" | `libmagic.app.dao.uctoo.dll` 旧版本不含 CrontabLogDAO 新增方法签名 |
| 4 | "magic.app.dao.uctoo:CrontabLogDAO.ti 于 libmagic.app.services.crontab.dll 上" | 同上，crontab 主模块也依赖 CrontabLogDAO 的新增方法 |

### 17.1.2 根因定位

**根因1：f_ticktock 模块未加入 fountainModules 数组**

当前 `package_release/main.cj` 行516-521的 fountainModules 数组：

```cangjie
let fountainModules = [
    "f_aspect", "f_base", "f_bean", "f_cache", "f_cmd", 
    "f_collection", "f_concurrent", "f_exception", "f_io", 
    "f_log", "f_macros", "f_mockdb", "f_pool", 
    "f_random", "f_regex", "f_time", "f_util", "f_version"
]
```

**缺少 `"f_ticktock"`**，导致 `target/release/f_ticktock/` 目录下的 DLL 不会被遍历和复制。

验证：`target/release/f_ticktock/` 目录存在且包含：
- `libf_ticktock.dll`
- `libf_ticktock.exception.dll`

**根因2：overwrite: false 导致旧版 DLL 不被更新**

当前所有 DLL 复制步骤均使用 `overwrite: false` 参数：

```cangjie
copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
```

当 bin/ 目录已存在旧版 `libmagic.app.dao.uctoo.dll`（不含 CrontabDAO 新增方法签名）时，重新编译生成的新版 DLL 不会被覆盖到 bin/ 目录，导致运行时类型信息（ti）找不到。

**根因3：CJO 文件同样存在旧版覆盖问题**

行716-721的 CJO 复制逻辑同样使用 `overwrite: false`：

```cangjie
if (name.endsWith(".cjo")) {
    let destPath = Path("${binDir}/${name}")
    if (!exists(destPath)) {
        copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
        cjoCount.add(name)
    }
}
```

## **17.2 修复方案**

### 17.2.1 修改点1：fountainModules 数组增加 f_ticktock

**文件**: `apps/agentskills-runtime/src/scripts/package_release/main.cj`

**修改位置**: 行516-521

**修改前**:
```cangjie
let fountainModules = [
    "f_aspect", "f_base", "f_bean", "f_cache", "f_cmd", 
    "f_collection", "f_concurrent", "f_exception", "f_io", 
    "f_log", "f_macros", "f_mockdb", "f_pool", 
    "f_random", "f_regex", "f_time", "f_util", "f_version"
]
```

**修改后**:
```cangjie
let fountainModules = [
    "f_aspect", "f_base", "f_bean", "f_cache", "f_cmd", 
    "f_collection", "f_concurrent", "f_exception", "f_io", 
    "f_log", "f_macros", "f_mockdb", "f_pool", 
    "f_random", "f_regex", "f_ticktock", "f_time", "f_util", "f_version"
]
```

**效果**: `target/release/f_ticktock/` 目录下的 `libf_ticktock.dll` 和 `libf_ticktock.exception.dll` 将随其他 Fountain 模块一同被遍历和复制到 bin/ 目录。

### 17.2.2 修改点2：DLL 复制改为 overwrite: true

**文件**: `apps/agentskills-runtime/src/scripts/package_release/main.cj`

**修改范围**: 所有 DLL 复制语句中的 `overwrite: false` 改为 `overwrite: true`

**涉及位置**:
1. 行186: magic 目录 DLL 复制
2. 行217: commonmark4cj 目录 DLL 复制
3. 行249: json4cj 目录 DLL 复制
4. 行277: yaml4cj 目录 DLL 复制
5. 行305: f_orm 目录 DLL 复制
6. 行333: charset4cj 目录 DLL 复制
7. 行361: jwt4cj 目录 DLL 复制
8. 行389: logcj 目录 DLL 复制
9. 行417: f_data 目录 DLL 复制
10. 行445: f_config 目录 DLL 复制
11. 行473: opengauss 目录 DLL 复制
12. 行501: blowfish 目录 DLL 复制
13. 行538: fountainModules 循环中的 DLL 复制
14. 行567: stdx 目录 DLL 复制
15. 行598: cangjie runtime 目录 DLL 复制

**修改前**:
```cangjie
copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
```

**修改后**:
```cangjie
copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: true)
```

**效果**: 重新编译后生成的新版 DLL（含 CrontabDAO/CrontabLogDAO 新增类型信息）将覆盖 bin/ 目录中的旧版 DLL，解决"无法定位程序输入点"错误。

### 17.2.3 修改点3：CJO 复制改为 overwrite: true

**文件**: `apps/agentskills-runtime/src/scripts/package_release/main.cj`

**修改位置**: 行718

**修改前**:
```cangjie
copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: false)
```

**修改后**:
```cangjie
copy(fileInfo.path.toString(), to: destPath.toString(), overwrite: true)
```

**效果**: 确保新版 CJO 文件（含新增类型反射信息）也同步更新到 bin/ 目录。

### 17.2.4 修改点4：移除冗余的 exists 检查（可选优化）

当前 DLL 复制逻辑在每个复制点都先检查 `if (!exists(destPath))`，改为 `overwrite: true` 后此检查不再必要（copy 本身可处理覆盖），但保留不影响逻辑正确性，暂不修改以降低变更风险。

## **17.3 修复方案架构图**

```
package_release/main.cj
│
├── [修改1] fountainModules += "f_ticktock"
│       │
│       └──> target/release/f_ticktock/  ──遍历──>  bin/
│            ├── libf_ticktock.dll           ✅ 复制
│            └── libf_ticktock.exception.dll ✅ 复制
│
├── [修改2] overwrite: false → true (所有DLL复制点)
│       │
│       └──> target/release/magic/  ──遍历──>  bin/
│            ├── libmagic.app.dao.uctoo.dll     ✅ 覆盖（含CrontabDAO.ti）
│            ├── libmagic.app.services.crontab.*.dll  ✅ 覆盖
│            └── ...其他DLL                     ✅ 覆盖
│
└── [修改3] overwrite: false → true (CJO复制点)
        │
        └──> *.cjo 文件  ✅ 覆盖（含新增类型反射信息）
```

## **17.4 验证方案**

| 步骤 | 操作 | 预期结果 |
|------|------|----------|
| 1 | 执行 `cjpm build` 重新编译 | target/release/ 下生成最新 DLL |
| 2 | 删除 target/release/bin/ 目录 | 确保旧 DLL 被清除 |
| 3 | 执行 `package_release` 脚本 | 日志输出包含 "Copied N f_ticktock DLLs" |
| 4 | 检查 bin/ 目录 | 包含 libf_ticktock.dll、libf_ticktock.exception.dll |
| 5 | 检查 bin/ 目录 | libmagic.app.dao.uctoo.dll 为最新版（文件时间戳与编译时间一致） |
| 6 | 启动 agentskills-runtime.exe | 无"无法定位程序输入点"错误 |

## **17.5 异常场景处理**

| 异常场景 | 处理策略 |
|----------|----------|
| f_ticktock 目录不存在 | 现有逻辑已有 `else { println("[WARN] Directory not found: ...") }` 处理，无需额外修改 |
| DLL 被占用无法覆盖 | overwrite: true 模式下，操作系统会返回错误；建议在 package_release 开头增加提示：运行前关闭占用 DLL 的进程 |
| 新增 crontab 子模块 | 现有 magic/ 目录遍历机制自动发现新 DLL，无需修改脚本（满足 spec 7.1.1 第6条禁止项要求） |

---

# **18. 补充设计：计划任务模块Python测试脚本**

## **18.1 脚本定位**

**文件路径**: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`

**运行环境**: Python 3.9+，依赖 `requests` 库

**运行方式**:
```bash
# 先启动 agentskills-runtime 服务
python tests/test_crontab_scheduler.py --base-url http://localhost:8080
```

## **18.2 整体架构**

```
test_crontab_scheduler.py
│
├── TestConfig                 # 测试配置（base_url, 超时, 认证信息）
├── AuthHelper                 # 认证辅助（登录获取token）
├── TestResult                 # 单个测试结果记录
├── TestReporter               # 测试报告生成器（JSON + Markdown）
│
├── TestCrontabCRUD            # CRUD 操作测试类
│   ├── test_create_task()
│   ├── test_query_task()
│   ├── test_query_task_list()
│   ├── test_edit_task()
│   └── test_delete_task()
│
├── TestCrontabScheduler       # 调度控制测试类
│   ├── test_trigger_task()
│   ├── test_pause_task()
│   ├── test_resume_task()
│   ├── test_reload_tasks()
│   ├── test_scheduler_status()
│   ├── test_running_tasks()
│   ├── test_task_runtime_status()
│   └── test_next_execution()
│
├── TestCrontabLog             # 日志查询测试类
│   ├── test_query_log_by_crontab()
│   ├── test_recent_logs()
│   └── test_log_stats()
│
├── TestCrontabExecutor        # 执行器/内置任务测试类
│   ├── test_executors()
│   └── test_builtin_tasks()
│
├── TestSystemTaskProtection   # 系统任务保护测试类
│   ├── test_delete_system_task_forbidden()
│   └── test_pause_system_task_forbidden()
│
└── main()                     # 测试执行入口（顺序执行+报告生成）
```

## **18.3 核心类设计**

### 18.3.1 TestConfig（测试配置）

```python
class TestConfig:
    BASE_URL: str = "http://localhost:8080"
    TIMEOUT: int = 30
    AUTH_USERNAME: str = "admin"
    AUTH_PASSWORD: str = "123456"
    API_PREFIX: str = "/api/v1/uctoo"
    CRONTAB_PREFIX: str = "/api/v1/uctoo/crontab"
    CRONTAB_LOG_PREFIX: str = "/api/v1/uctoo/crontab_log"
```

### 18.3.2 AuthHelper（认证辅助）

```python
class AuthHelper:
    """登录认证辅助类"""
    - token: str                    # access_token
    - session: requests.Session     # 带 token 的 HTTP 会话

    + login(base_url, username, password) -> bool
        # POST /api/v1/uctoo/uctoo_user/signin
        # 请求体: {"username": "admin", "password": "123456"}
        # 成功: 提取 response.data.access_token
        # 失败: 输出错误信息，返回 False

    + get_headers() -> dict
        # 返回 {"Authorization": "Bearer <token>"}

    + get_session() -> requests.Session
        # 返回已设置 Authorization header 的 session
```

### 18.3.3 TestResult（测试结果记录）

```python
class TestResult:
    """单个测试用例结果"""
    - name: str            # 用例名称
    - status: str          # "PASS" | "FAIL" | "SKIP" | "ERROR"
    - duration_ms: float   # 执行耗时(毫秒)
    - error_message: str   # 错误/跳过信息
    - timestamp: str       # 执行时间戳
```

### 18.3.4 TestReporter（测试报告生成器）

```python
class TestReporter:
    """测试报告生成器"""
    - results: list[TestResult]    # 所有测试结果
    - start_time: datetime         # 测试开始时间
    - end_time: datetime           # 测试结束时间

    + add_result(result: TestResult) -> None
    + generate_json_report() -> str
        # 生成 JSON 格式报告文件: test_crontab_scheduler_result.json
        # 结构: { "summary": {total, passed, failed, skipped, error, duration_ms},
        #         "results": [ {name, status, duration_ms, error_message, timestamp} ] }
    + generate_markdown_report() -> str
        # 生成 Markdown 格式报告文件: test_crontab_scheduler_report.md
        # 包含: 汇总统计表、各用例结果明细表
```

## **18.4 测试类详细设计**

### 18.4.1 TestCrontabCRUD（CRUD操作测试）

| 方法 | API端点 | HTTP方法 | 验证逻辑 |
|------|---------|----------|----------|
| `test_create_task` | `/api/v1/uctoo/crontab/add` | POST | 返回200，包含任务ID；保存ID供后续测试使用 |
| `test_query_task` | `/api/v1/uctoo/crontab/:id` | GET | 返回200，字段name/cron_expression与创建时一致 |
| `test_query_task_list` | `/api/v1/uctoo/crontab/10/1` | GET | 返回200，data为列表，包含分页信息 |
| `test_edit_task` | `/api/v1/uctoo/crontab/edit` | POST | 修改cron_expression，返回200；查询验证已更新 |
| `test_delete_task` | `/api/v1/uctoo/crontab/del` | POST | 传入非系统任务ID，返回200；查询验证不再存在 |

**测试数据创建**：
```python
test_task_data = {
    "name": "test_scheduler_task",
    "cron_expression": "*/5 * * * *",
    "task_uri": "echo hello",
    "status": 1,
    "group": 1,
    "once": False,
    "concurrentable": False,
    "timeout": 60,
    "max_retries": 3
}
```

### 18.4.2 TestCrontabScheduler（调度控制测试）

| 方法 | API端点 | HTTP方法 | 验证逻辑 |
|------|---------|----------|----------|
| `test_trigger_task` | `/api/v1/uctoo/crontab/trigger/:id` | POST | 返回200；查询日志验证trigger_type="manual" |
| `test_pause_task` | `/api/v1/uctoo/crontab/pause/:id` | POST | 返回200；查询任务验证status=2 |
| `test_resume_task` | `/api/v1/uctoo/crontab/resume/:id` | POST | 返回200；查询任务验证status=1 |
| `test_reload_tasks` | `/api/v1/uctoo/crontab/reload` | POST | 返回200；验证调度器状态正常 |
| `test_scheduler_status` | `/api/v1/uctoo/crontab/scheduler/status` | GET | 返回200；包含scheduler_state、registered_task_count字段 |
| `test_running_tasks` | `/api/v1/uctoo/crontab/running` | GET | 返回200；data为列表 |
| `test_task_runtime_status` | `/api/v1/uctoo/crontab/:id/runtime` | GET | 返回200；包含任务运行时信息 |
| `test_next_execution` | `/api/v1/uctoo/crontab/:id/next-exec` | GET | 返回200；包含下次执行时间 |

**执行顺序约束**：trigger测试须在create之后、pause须在trigger之后、resume须在pause之后。

### 18.4.3 TestCrontabLog（日志查询测试）

| 方法 | API端点 | HTTP方法 | 验证逻辑 |
|------|---------|----------|----------|
| `test_query_log_by_crontab` | `/api/v1/uctoo/crontab_log/by-crontab/:id` | GET | 返回200；验证日志字段完整性（crontab_id, start_time, end_time, used_time, trigger_type, status） |
| `test_recent_logs` | `/api/v1/uctoo/crontab_log/recent` | GET | 返回200；data为列表，按时间倒序 |
| `test_log_stats` | `/api/v1/uctoo/crontab_log/stats` | GET | 返回200；包含统计汇总信息 |

### 18.4.4 TestCrontabExecutor（执行器/内置任务测试）

| 方法 | API端点 | HTTP方法 | 验证逻辑 |
|------|---------|----------|----------|
| `test_executors` | `/api/v1/uctoo/crontab/executors` | GET | 返回200；data包含执行器类型列表（script/http/builtin） |
| `test_builtin_tasks` | `/api/v1/uctoo/crontab/builtin-tasks` | GET | 返回200；data包含内置任务信息 |

### 18.4.5 TestSystemTaskProtection（系统任务保护测试）

| 方法 | API端点 | HTTP方法 | 验证逻辑 |
|------|---------|----------|----------|
| `test_delete_system_task_forbidden` | `/api/v1/uctoo/crontab/del` | POST | 查找group=2任务，尝试删除，验证返回403或错误 |
| `test_pause_system_task_forbidden` | `/api/v1/uctoo/crontab/pause/:id` | POST | 查找group=2任务，尝试暂停，验证返回403或错误 |

**前置条件**：先查询任务列表找到group=2的系统任务。若无系统任务则SKIP。

## **18.5 认证流程**

```
1. POST /api/v1/uctoo/uctoo_user/signin
   请求体: {"username": "admin", "password": "123456"}
   │
   ├── 成功 (200)
   │   └── 提取 response["data"]["access_token"]
   │       └── 设置 session.headers["Authorization"] = "Bearer <token>"
   │
   └── 失败 (非200)
       └── 所有需认证测试用例标记为 SKIP
           └── 报告中记录 "登录认证失败: <status_code> <reason>"
```

## **18.6 测试执行流程**

```
main()
│
├── 1. 解析命令行参数 (--base-url, --timeout)
├── 2. AuthHelper.login() → 获取 access_token
│       └── 失败 → 所有测试标记 SKIP，生成报告并退出
├── 3. TestCrontabCRUD.test_create_task() → 保存 test_task_id
│       └── 失败 → 依赖测试标记 SKIP
├── 4. TestCrontabCRUD.test_query_task()
├── 5. TestCrontabCRUD.test_query_task_list()
├── 6. TestCrontabCRUD.test_edit_task()
├── 7. TestCrontabScheduler.test_trigger_task()
├── 8. TestCrontabScheduler.test_pause_task()
├── 9. TestCrontabScheduler.test_resume_task()
├── 10. TestCrontabScheduler.test_reload_tasks()
├── 11. TestCrontabScheduler.test_scheduler_status()
├── 12. TestCrontabScheduler.test_running_tasks()
├── 13. TestCrontabScheduler.test_task_runtime_status()
├── 14. TestCrontabScheduler.test_next_execution()
├── 15. TestCrontabLog.test_query_log_by_crontab()
├── 16. TestCrontabLog.test_recent_logs()
├── 17. TestCrontabLog.test_log_stats()
├── 18. TestCrontabExecutor.test_executors()
├── 19. TestCrontabExecutor.test_builtin_tasks()
├── 20. TestSystemTaskProtection.test_delete_system_task_forbidden()
├── 21. TestSystemTaskProtection.test_pause_system_task_forbidden()
├── 22. TestCrontabCRUD.test_delete_task() → 清理测试数据
├── 23. TestReporter.generate_json_report() → test_crontab_scheduler_result.json
└── 24. TestReporter.generate_markdown_report() → test_crontab_scheduler_report.md
```

## **18.7 报告格式**

### 18.7.1 JSON 报告格式

```json
{
    "summary": {
        "total": 21,
        "passed": 20,
        "failed": 0,
        "skipped": 1,
        "error": 0,
        "duration_ms": 5230.5,
        "start_time": "2026-05-19T10:00:00",
        "end_time": "2026-05-19T10:00:05"
    },
    "results": [
        {
            "name": "test_create_task",
            "status": "PASS",
            "duration_ms": 150.3,
            "error_message": "",
            "timestamp": "2026-05-19T10:00:00"
        }
    ]
}
```

### 18.7.2 Markdown 报告格式

```markdown
# Crontab Scheduler Test Report

## Summary
| Metric | Value |
|--------|-------|
| Total  | 21    |
| Passed | 20    |
| Failed | 0     |
| Skipped| 1     |
| Duration| 5.23s |

## Test Results
| # | Test Name | Status | Duration | Error |
|---|-----------|--------|----------|-------|
| 1 | test_create_task | PASS | 150ms | - |
| 2 | test_query_task | PASS | 50ms | - |
```

## **18.8 依赖与约束**

| 项目 | 说明 |
|------|------|
| Python 版本 | >= 3.9 |
| 外部依赖 | `requests` (HTTP客户端) |
| 运行前置 | agentskills-runtime 服务已启动且数据库已初始化 |
| 测试数据 | 自包含（脚本自行创建和清理，不依赖外部数据） |
| 系统任务保护 | 仅查询group=2任务进行保护测试，不修改系统任务 |
| 并发安全 | 顺序执行，不并发运行测试用例 |

## **18.9 测试用例与spec需求映射**

| 测试用例 | spec.md 需求编号 | 覆盖状态 |
|----------|------------------|----------|
| test_create_task | 7.2.1-3 | ✅ |
| test_query_task | 7.2.1-4 | ✅ |
| test_query_task_list | 7.2.1-4 | ✅ |
| test_edit_task | 7.2.1-5 | ✅ |
| test_delete_task | 7.2.1-6 | ✅ |
| test_trigger_task | 7.2.1-7 | ✅ |
| test_pause_task | 7.2.1-8 | ✅ |
| test_resume_task | 7.2.1-9 | ✅ |
| test_reload_tasks | 7.2.1-10 | ✅ |
| test_query_log_by_crontab | 7.2.1-11 | ✅ |
| test_recent_logs | 7.2.1-11 | ✅ |
| test_log_stats | 7.2.1-11 | ✅ |
| test_scheduler_status | 7.2.1-12 | ✅ |
| test_running_tasks | 7.2.1-13 | ✅ |
| test_task_runtime_status | 7.2.1-13 | ✅ |
| test_next_execution | 7.2.1-12 | ✅ |
| test_executors | 7.2.1-14 | ✅ |
| test_builtin_tasks | 7.2.1-15 | ✅ |
| test_delete_system_task_forbidden | 7.2.1-16 | ✅ |
| test_pause_system_task_forbidden | 7.2.1-16 | ✅ |
| 数据清理（test_delete_task） | 7.2.1-17 | ✅ |
| 报告生成 | 7.2.1-18/19 | ✅ |
