# API 模块重构至 APP 模块技术设计文档

## 文档信息
- **项目名称**: agentskills-runtime API 模块重构
- **版本**: 1.1.0
- **创建日期**: 2026-03-13
- **最后更新**: 2026-03-13
- **作者**: SDD Agent
- **状态**: 草稿
- **关联需求**: spec.md v1.1.0

## 1. 设计概述

### 1.1 设计目标
1. 将 api 模块的**已实现功能完整保留**并重构到 app 模块中
2. 遵循 uctoo V4.0 三层架构设计规范
3. 实现与 backend 项目一致的架构风格
4. 将 API 路由重构到 `/api/v1/uctoo/` 前缀下
5. 实现 agent_skills 表的标准 CRUD 功能
6. **所有配置参数从 .env 文件读取**（服务器端口、域名、数据库连接等）

### 1.2 功能保留原则
- **api 模块已实现的功能必须完整保留**，包括：
  - HTTP 服务器启动/停止功能
  - 技能管理完整功能（列表、详情、安装、更新、卸载、执行、搜索）
  - WebSocket 聊天功能
  - MCP 流式接口
  - 热重载功能
  - 数据库连接池管理
  - uctoo API 端点
- 重构过程中**不删除、不简化**任何已实现的功能
- 保持与原 api 模块相同的功能行为和接口契约

### 1.2 设计原则
- **分层架构**: Controllers → Services → Models
- **单一职责**: 每个类只负责一个功能
- **依赖注入**: 通过构造函数注入依赖
- **开闭原则**: 对扩展开放，对修改关闭
- **接口隔离**: 使用接口定义契约

### 1.3 技术选型
| 组件 | 技术选型 | 说明 |
|------|---------|------|
| 编程语言 | 仓颉 (Cangjie) | 华为自研编程语言 |
| HTTP 服务器 | 自研 HTTPServer | 基于仓颉标准库 stdx.net.http |
| ORM 框架 | fountain ORM | 仓颉 ORM 框架 |
| 数据库驱动 | opengauss-driver | PostgreSQL 驱动 |
| 数据库 | PostgreSQL | 主数据库 |
| 认证 | JWT | jwt4cj 库 |
| 缓存 | Redis | redis-sdk 库 |
| 日志 | log-cj | 仓颉日志库 |

## 2. 系统架构

### 2.1 架构图
```
┌─────────────────────────────────────────────────────────────────────┐
│                        HTTP Server Layer                             │
│                    (HTTPServer + WebSocket)                          │
├─────────────────────────────────────────────────────────────────────┤
│                       Middleware Layer                               │
│              (JWT Auth + Permission + CORS + Logger)                 │
├─────────────────────────────────────────────────────────────────────┤
│                         Routes Layer                                 │
│                    (URL Mapping + Grouping)                          │
├─────────────────────────────────────────────────────────────────────┤
│                      Controllers Layer                               │
│              (Request Handling + Validation + Response)              │
├─────────────────────────────────────────────────────────────────────┤
│                        Services Layer                                │
│                   (Business Logic + Data)                            │
├─────────────────────────────────────────────────────────────────────┤
│                          Models Layer                                │
│                      (Data Models + ORM)                             │
├─────────────────────────────────────────────────────────────────────┤
│                          ORM Layer                                   │
│                      (fountain ORM)                                  │
├─────────────────────────────────────────────────────────────────────┤
│                       Database Layer                                 │
│                      (PostgreSQL)                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 模块划分

#### 模块设计说明
**重要原则**：技能管理 API 功能（原 /skills 接口）合并到 agent_skills 模块的定制开发区域，不创建单独的 skills 模块。这样可以避免未来创建 skills 数据库表标准 CRUD 模块时代码被覆盖。

```
src/app/
├── core/                           # 核心组件
│   ├── server/                     # HTTP 服务器
│   ├── router/                     # 路由系统
│   ├── middleware/                 # 中间件基础
│   ├── response/                   # 响应封装
│   ├── cache/                      # 缓存管理
│   ├── database/                   # 数据库连接
│   └── log/                        # 日志系统
├── middlewares/                    # 中间件实现
│   ├── auth/                       # 认证中间件
│   └── permission/                 # 权限中间件
├── models/                         # 数据模型
│   └── uctoo/                      # uctoo 数据库模型
│       ├── EntityPO.cj             # entity 表模型
│       └── AgentSkillsPO.cj        # agent_skills 表模型（新增）
├── services/                       # 服务层
│   └── uctoo/                      # uctoo 数据库服务
│       ├── EntityService.cj        # entity 表服务
│       └── AgentSkillsService.cj   # agent_skills 表服务（新增，包含技能管理功能）
├── controllers/                    # 控制器层
│   └── uctoo/                      # uctoo 数据库控制器
│       ├── entity/                 # entity 表控制器
│       ├── agent_skills/           # agent_skills 表控制器（新增，包含技能管理功能）
│       ├── mcp/                    # MCP 控制器（新增）
│       └── ws/                     # WebSocket 控制器（新增）
├── routes/                         # 路由层
│   └── uctoo/                      # uctoo 数据库路由
│       ├── entity/                 # entity 表路由
│       ├── agent_skills/           # agent_skills 表路由（新增，包含技能管理路由）
│       ├── mcp/                    # MCP 路由（新增）
│       └── ws/                     # WebSocket 路由（新增）
└── main.cj                         # 应用入口
```

#### 代码区域划分
每个模块文件内部采用以下区域划分：
```cangjie
// ==================== 自动生成代码区域 ====================
//#region AutoCreateCode
// 标准 CRUD 代码（未来可能被代码生成器覆盖）
//#endregion AutoCreateCode

// ==================== 定制开发代码区域 ====================
// 技能管理 API 相关代码（不会被覆盖）
// 包括：技能列表、安装、卸载、执行、搜索等功能
```

### 2.3 组件交互
```
Client Request
      │
      ▼
┌─────────────┐
│ HTTPServer  │ ──→ 接收 HTTP 请求
└─────────────┘
      │
      ▼
┌─────────────┐
│ Middleware  │ ──→ 认证、权限、日志
└─────────────┘
      │
      ▼
┌─────────────┐
│   Router    │ ──→ 路由匹配
└─────────────┘
      │
      ▼
┌─────────────┐
│ Controller  │ ──→ 参数验证、调用服务
└─────────────┘
      │
      ▼
┌─────────────┐
│  Service    │ ──→ 业务逻辑、数据操作
└─────────────┘
      │
      ▼
┌─────────────┐
│    ORM      │ ──→ 数据持久化
└─────────────┘
      │
      ▼
┌─────────────┐
│  Database   │ ──→ PostgreSQL
└─────────────┘
```

## 3. 详细设计

### 3.1 HTTP 服务器设计

#### 3.1.1 HTTPServer 类设计
```cangjie
public class HTTPServer {
    private var port: Int32 = 8080
    private var host: String = "0.0.0.0"
    private var router: Router
    private var middlewares: ArrayList<Middleware>
    private var server: Server
    
    public func setPort(port: Int32): HTTPServer
    public func setHost(host: String): HTTPServer
    public func setRouter(router: Router): HTTPServer
    public func use(middleware: Middleware): HTTPServer
    public func start(): Unit
    public func stop(): Unit
}
```

#### 3.1.2 Router 类设计
```cangjie
public class Router {
    private var routes: ArrayList<Route>
    private var groups: ArrayList<RouteGroup>
    
    public func get(path: String, handler: Handler): Router
    public func post(path: String, handler: Handler): Router
    public func put(path: String, handler: Handler): Router
    public func delete(path: String, handler: Handler): Router
    public func group(prefix: String, callback: (Router) -> Unit): Router
    public func match(req: HttpRequest): ?Route
}
```

#### 3.1.3 中间件接口设计
```cangjie
public interface Middleware {
    func handle(req: HttpRequest, res: HttpResponse, next: () -> Unit): Unit
}
```

### 3.2 agent_skills 模块设计

#### 3.2.1 数据模型 (AgentSkillsPO.cj)
```cangjie
package magic.app.models.uctoo

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_orm.*

@QueryMappersGenerator["agent_skills"]
public class AgentSkillsPO {
    @ORMField[true]
    public var id: String = ""
    
    public var name: String = ""
    public var description: ?String = None<String>
    
    // 来源信息
    public var source: ?String = None<String>
    public var sourceUrl: ?String = None<String>
    public var sourceType: ?String = None<String>
    public var branch: ?String = None<String>
    public var tag: ?String = None<String>
    public var commit: ?String = None<String>
    
    // 元数据
    public var version: ?String = None<String>
    public var author: ?String = None<String>
    public var homepage: ?String = None<String>
    public var license: ?String = None<String>
    public var keywords: ?String = None<String>
    public var tags: ?String = None<String>
    public var categories: ?String = None<String>
    
    // 安装配置
    public var installPath: ?String = None<String>
    public var compatibility: ?String = None<String>
    public var allowedTools: ?String = None<String>
    public var dependencies: ?String = None<String>
    public var permissions: ?String = None<String>
    
    // 运行时配置
    public var parameters: ?String = None<String>
    public var instructions: ?String = None<String>
    public var scriptsDirExists: Int32 = 0
    public var referencesDirExists: Int32 = 0
    public var assetsDirExists: Int32 = 0
    
    // 状态信息
    public var status: Int32 = 0
    public var runtimeStatus: ?String = None<String>
    public var validationStatus: ?String = None<String>
    public var validationErrors: ?String = None<String>
    public var lastValidatedAt: ?DateTime = None<DateTime>
    
    // 配置
    public var config: ?String = None<String>
    public var envVars: ?String = None<String>
    public var timeout: Int32 = 30000
    public var retryCount: Int32 = 0
    
    // 统计信息
    public var runCount: Int32 = 0
    public var successCount: Int32 = 0
    public var errorCount: Int32 = 0
    public var lastRunAt: ?DateTime = None<DateTime>
    public var lastError: ?String = None<String>
    public var avgExecutionTime: Int32 = 0
    
    // 生成信息
    public var generationPrompt: ?String = None<String>
    public var generationModel: ?String = None<String>
    public var generationStatus: ?String = None<String>
    public var parentSkillId: ?String = None<String>
    
    // 其他
    public var extraMetadata: ?String = None<String>
    public var creator: ?String = None<String>
    public var createdAt: DateTime = DateTime.now()
    public var updatedAt: DateTime = DateTime.now()
    public var deletedAt: ?DateTime = None<DateTime>
    
    public init() {}
    
    //#region AutoCreateCode
    // 自动生成代码区域
    //#endregion AutoCreateCode
    
    // 定制开发代码区域
    public func toJson(): String {
        // JSON 序列化实现
    }
    
    public static func fromJson(json: String): AgentSkillsPO {
        // JSON 反序列化实现
    }
}
```

#### 3.2.2 服务层 (AgentSkillsService.cj)

**设计说明**：服务层同时包含 agent_skills 表的标准 CRUD 方法和技能管理 API 相关方法，后者放在定制开发区域。

```cangjie
package magic.app.services.uctoo

import magic.app.models.uctoo.AgentSkillsPO
import magic.app.core.response.{APIResult, APIResponse}
import magic.app.core.database.DatabaseConnection
import magic.skill.application.SkillManagementService
import magic.skill.application.ProgressiveSkillLoader
import magic.core.skill.SkillManager
import magic.skill.search.PublicSkillSearchService
import std.time.DateTime
import std.collection.{ArrayList, HashMap}

public class AgentSkillsService {
    private var db: DatabaseConnection
    // 技能运行时相关服务
    private let skillManagementService: SkillManagementService
    private let progressiveSkillLoader: ProgressiveSkillLoader
    private let skillManager: SkillManager
    private let searchService: PublicSkillSearchService
    
    public init(db: DatabaseConnection, skillManager: SkillManager, ...) {
        this.db = db
        this.skillManager = skillManager
        // ... 初始化其他服务
    }
    
    // ==================== 自动生成代码区域 ====================
    //#region AutoCreateCode
    // 标准 CRUD 方法（未来可能被代码生成器覆盖）
    
    /**
     * 创建技能记录 - 标准 CRUD
     */
    public func create(skill: AgentSkillsPO, userId: String): APIResult<AgentSkillsPO> {
        // ... 标准实现
    }
    
    /**
     * 更新技能记录 - 标准 CRUD
     */
    public func update(skillId: String, skill: AgentSkillsPO): APIResult<AgentSkillsPO> {
        // ... 标准实现
    }
    
    /**
     * 删除技能记录 - 标准 CRUD（支持软删除）
     */
    public func delete(skillId: String, force: Bool): APIResult<Bool> {
        // ... 标准实现
    }
    
    /**
     * 根据 ID 查询 - 标准 CRUD
     */
    public func getById(skillId: String): APIResult<AgentSkillsPO> {
        // ... 标准实现
    }
    
    /**
     * 分页查询列表 - 标准 CRUD
     */
    public func getList(page: Int32, limit: Int32, filter: ?HashMap<String, Any>): (ArrayList<AgentSkillsPO>, Int64) {
        // ... 标准实现
    }
    
    //#endregion AutoCreateCode
    
    // ==================== 定制开发代码区域 ====================
    // 技能管理 API 相关方法（不会被覆盖）
    
    // ---------- 技能运行时管理功能 ----------
    
    /**
     * 获取运行时技能列表（从 SkillManager）
     * 对应 API: GET /api/v1/uctoo/skills
     */
    public func getRuntimeSkills(page: Int32, limit: Int32): (ArrayList<Skill>, Int64) {
        let skills = skillManager.availableSkills.values().toArray()
        // ... 分页处理
    }
    
    /**
     * 获取运行时技能详情（从 SkillManager）
     * 对应 API: GET /api/v1/uctoo/skills/:id
     */
    public func getRuntimeSkillById(skillId: String): ?Skill {
        return skillManager.getSkill(skillId)
    }
    
    /**
     * 安装技能（从本地路径或 Git 仓库）
     * 对应 API: POST /api/v1/uctoo/skills/add
     */
    public func installSkill(source: String, options: InstallOptions): InstallResult {
        // ... 调用 SkillPackageManager 安装
    }
    
    /**
     * 更新技能信息
     * 对应 API: POST /api/v1/uctoo/skills/edit
     */
    public func updateSkillInfo(skillId: String, updates: HashMap<String, String>): Bool {
        // ... 调用 SkillPackageManager 更新
    }
    
    /**
     * 卸载技能
     * 对应 API: POST /api/v1/uctoo/skills/del
     */
    public func uninstallSkill(skillId: String): Bool {
        // ... 调用 SkillPackageManager 卸载
    }
    
    /**
     * 执行技能
     * 对应 API: POST /api/v1/uctoo/skills/execute
     */
    public func executeSkill(skillId: String, params: HashMap<String, JsonValue>, timeout: Int64): ExecutionResult {
        // ... 调用 Skill 执行
    }
    
    /**
     * 搜索技能（从公共仓库）
     * 对应 API: POST /api/v1/uctoo/skills/search
     */
    public func searchSkills(query: String, source: String, limit: Int32, sort: String): SkillSearchResponse {
        return searchService.search(query, source, limit, sort)
    }
    
    /**
     * 重新加载技能
     */
    public func reloadSkills(): Unit {
        progressiveSkillLoader.reloadSkills(skillManager)
    }
    
    // ---------- 辅助方法 ----------
    
    /**
     * 根据名称查询
     */
    public func getByName(name: String): ?AgentSkillsPO {
        // ... 实现代码
    }
    
    /**
     * 更新运行统计
     */
    public func updateRunStats(skillId: String, success: Bool, executionTime: Int32): Unit {
        // ... 实现代码
    }
}
```

#### 3.2.3 控制器层 (AgentSkillsController.cj)

**设计说明**：控制器同时处理 agent_skills 表的 CRUD 请求和技能管理 API 请求，后者放在定制开发区域。

```cangjie
package magic.app.controllers.uctoo.agent_skills

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult, APIResponse}
import magic.app.services.uctoo.AgentSkillsService
import magic.app.models.uctoo.AgentSkillsPO
import std.json.*
import std.collection.HashMap

public class AgentSkillsController {
    private let service: AgentSkillsService
    
    public init(service: AgentSkillsService) {
        this.service = service
    }
    
    // ==================== 自动生成代码区域 ====================
    //#region AutoCreateCode
    // 标准 CRUD 控制器方法（未来可能被代码生成器覆盖）
    
    /**
     * 创建技能记录 POST /api/v1/uctoo/agent_skills/add
     */
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        // ... 标准 CRUD 实现
    }
    
    /**
     * 更新技能记录 POST /api/v1/uctoo/agent_skills/edit
     */
    public func edit(req: HttpRequest, res: HttpResponse): Unit {
        // ... 标准 CRUD 实现
    }
    
    /**
     * 删除技能记录 POST /api/v1/uctoo/agent_skills/del
     */
    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        // ... 标准 CRUD 实现
    }
    
    /**
     * 查询单个记录 GET /api/v1/uctoo/agent_skills/:id
     */
    public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
        // ... 标准 CRUD 实现
    }
    
    /**
     * 查询列表 GET /api/v1/uctoo/agent_skills
     */
    public func getMany(req: HttpRequest, res: HttpResponse): Unit {
        // ... 标准 CRUD 实现
    }
    
    //#endregion AutoCreateCode
    
    // ==================== 定制开发代码区域 ====================
    // 技能管理 API 控制器方法（不会被覆盖）
    
    /**
     * 获取运行时技能列表 GET /api/v1/uctoo/skills
     */
    public func getSkills(req: HttpRequest, res: HttpResponse): Unit {
        // 1. 解析分页参数
        // 2. 调用 service.getRuntimeSkills()
        // 3. 返回分页响应
    }
    
    /**
     * 获取运行时技能详情 GET /api/v1/uctoo/skills/:id
     */
    public func getSkillById(req: HttpRequest, res: HttpResponse): Unit {
        // 1. 获取路径参数 id
        // 2. 调用 service.getRuntimeSkillById()
        // 3. 返回技能详情
    }
    
    /**
     * 安装技能 POST /api/v1/uctoo/skills/add
     */
    public func installSkill(req: HttpRequest, res: HttpResponse): Unit {
        // 1. 解析请求体（source, branch, tag, commit, skill_subpath 等）
        // 2. 调用 service.installSkill()
        // 3. 返回安装结果
    }
    
    /**
     * 更新技能 POST /api/v1/uctoo/skills/edit
     */
    public func updateSkill(req: HttpRequest, res: HttpResponse): Unit {
        // 1. 解析请求体（id, updates）
        // 2. 调用 service.updateSkillInfo()
        // 3. 返回更新结果
    }
    
    /**
     * 卸载技能 POST /api/v1/uctoo/skills/del
     */
    public func uninstallSkill(req: HttpRequest, res: HttpResponse): Unit {
        // 1. 解析请求体（id）
        // 2. 调用 service.uninstallSkill()
        // 3. 返回卸载结果
    }
    
    /**
     * 执行技能 POST /api/v1/uctoo/skills/execute
     */
    public func executeSkill(req: HttpRequest, res: HttpResponse): Unit {
        // 1. 解析请求体（skill_id, params, timeout）
        // 2. 调用 service.executeSkill()
        // 3. 返回执行结果
    }
    
    /**
     * 搜索技能 POST /api/v1/uctoo/skills/search
     */
    public func searchSkills(req: HttpRequest, res: HttpResponse): Unit {
        // 1. 解析请求体（query, source, limit, sort）
        // 2. 调用 service.searchSkills()
        // 3. 返回搜索结果
    }
}
```

#### 3.2.4 路由层 (AgentSkillsRoute.cj)

**设计说明**：路由层同时注册 agent_skills 表的 CRUD 路由和技能管理 API 路由，后者放在定制开发区域。

```cangjie
package magic.app.routes.uctoo.agent_skills

import magic.app.core.router.Router
import magic.app.controllers.uctoo.agent_skills.AgentSkillsController
import magic.app.services.uctoo.AgentSkillsService
import magic.app.middlewares.auth.JWTAuthMiddleware

public class AgentSkillsRoute {
    private let router: Router
    private let controller: AgentSkillsController
    
    public init(router: Router, controller: AgentSkillsController) {
        this.router = router
        this.controller = controller
    }
    
    public func register(): Unit {
        // ==================== 自动生成代码区域 ====================
        //#region AutoCreateCode
        // agent_skills 表标准 CRUD 路由（未来可能被代码生成器覆盖）
        
        // 需要认证的 CRUD 路由
        router.group("/api/v1/uctoo/agent_skills") { group =>
            group.use(JWTAuthMiddleware())
            
            group.post("/add", controller.add)
            group.post("/edit", controller.edit)
            group.post("/del", controller.delete)
        }
        
        // 不需要认证的 CRUD 路由
        router.get("/api/v1/uctoo/agent_skills/:id", controller.getSingle)
        router.get("/api/v1/uctoo/agent_skills", controller.getMany)
        
        //#endregion AutoCreateCode
        
        // ==================== 定制开发代码区域 ====================
        // 技能管理 API 路由（不会被覆盖）
        
        // 技能管理路由（不需要认证）
        router.get("/api/v1/uctoo/skills", controller.getSkills)
        router.get("/api/v1/uctoo/skills/:id", controller.getSkillById)
        router.post("/api/v1/uctoo/skills/add", controller.installSkill)
        router.post("/api/v1/uctoo/skills/edit", controller.updateSkill)
        router.post("/api/v1/uctoo/skills/del", controller.uninstallSkill)
        router.post("/api/v1/uctoo/skills/execute", controller.executeSkill)
        router.post("/api/v1/uctoo/skills/search", controller.searchSkills)
    }
}
```
    }
}
```

### 3.3 WebSocket 模块设计
     * 更新技能 POST /api/v1/uctoo/skills/edit
     */
    public func updateSkill(req: HttpRequest, res: HttpResponse): Unit {
        // ... 实现代码
    }
    
    /**
     * 卸载技能 POST /api/v1/uctoo/skills/del
     */
    public func uninstallSkill(req: HttpRequest, res: HttpResponse): Unit {
        // ... 实现代码
    }
    
    /**
     * 执行技能 POST /api/v1/uctoo/skills/execute
     */
    public func executeSkill(req: HttpRequest, res: HttpResponse): Unit {
        // ... 实现代码
    }
    
    /**
     * 搜索技能 POST /api/v1/uctoo/skills/search
     */
    public func searchSkills(req: HttpRequest, res: HttpResponse): Unit {
        // ... 实现代码
    }
}
```

### 3.3 WebSocket 模块设计

#### 3.3.1 WebSocket 控制器 (WsChatController.cj)
```cangjie
package magic.app.controllers.uctoo.ws

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.core.model.ChatModel
import magic.core.skill.SkillManager

public class WsChatController {
    private let skillManager: SkillManager
    private let chatModel: ChatModel
    
    public init(skillManager: SkillManager, chatModel: ChatModel) {
        this.skillManager = skillManager
        this.chatModel = chatModel
    }
    
    /**
     * 处理 WebSocket 连接 WS /api/v1/uctoo/ws/chat
     */
    public func handleWebSocket(req: HttpRequest, res: HttpResponse): Unit {
        // 1. 升级 HTTP 连接为 WebSocket
        // 2. 处理消息循环
        // 3. 调用 AI 模型生成响应
        // 4. 支持技能调用
    }
}
}
```

### 3.5 MCP 模块设计

#### 3.5.1 MCP 控制器 (McpController.cj)
```cangjie
package magic.app.controllers.uctoo.mcp

import magic.app.core.http.{HttpRequest, HttpResponse}

public class McpController {
    /**
     * MCP 流式接口 GET /api/v1/uctoo/mcp/stream
     */
    public func stream(req: HttpRequest, res: HttpResponse): Unit {
        // 返回 MCP 服务器的流式接口
    }
}
```

## 4. 数据设计

### 4.1 数据模型映射

#### agent_skills 表字段映射
| 数据库字段 | Cangjie 字段 | 类型 | 说明 |
|-----------|-------------|------|------|
| id | id | String | UUID 主键 |
| name | name | String | 技能名称 |
| description | description | ?String | 描述 |
| source | source | ?String | 来源 |
| source_url | sourceUrl | ?String | 来源 URL |
| source_type | sourceType | ?String | 来源类型 |
| install_path | installPath | ?String | 安装路径 |
| created_at | createdAt | DateTime | 创建时间 |
| updated_at | updatedAt | DateTime | 更新时间 |
| deleted_at | deletedAt | ?DateTime | 删除时间 |
| ... | ... | ... | 其他字段 |

### 4.2 数据关系
- agent_skills 表为独立表，无外键关联
- 通过 creator 字段关联用户表（逻辑关联）

## 5. API 设计

### 5.1 API 列表

| 方法 | 路径 | 控制器方法 | 描述 |
|------|------|-----------|------|
| GET | /hello | - | 健康检查（保持不变） |
| GET | /api/v1/health | - | uctoo 健康检查 |
| GET | /api/v1/info | - | uctoo 系统信息 |
| GET | /api/v1/uctoo/skills | SkillsController.getSkills | 获取技能列表 |
| GET | /api/v1/uctoo/skills/:id | SkillsController.getSkillById | 获取技能详情 |
| POST | /api/v1/uctoo/skills/add | SkillsController.installSkill | 安装技能 |
| POST | /api/v1/uctoo/skills/edit | SkillsController.updateSkill | 更新技能 |
| POST | /api/v1/uctoo/skills/del | SkillsController.uninstallSkill | 卸载技能 |
| POST | /api/v1/uctoo/skills/execute | SkillsController.executeSkill | 执行技能 |
| POST | /api/v1/uctoo/skills/search | SkillsController.searchSkills | 搜索技能 |
| GET | /api/v1/uctoo/mcp/stream | McpController.stream | MCP 流式接口 |
| WS | /api/v1/uctoo/ws/chat | WsChatController.handleWebSocket | WebSocket 聊天 |
| POST | /api/v1/uctoo/agent_skills/add | AgentSkillsController.add | 创建技能记录 |
| POST | /api/v1/uctoo/agent_skills/edit | AgentSkillsController.edit | 更新技能记录 |
| POST | /api/v1/uctoo/agent_skills/del | AgentSkillsController.delete | 删除技能记录 |
| GET | /api/v1/uctoo/agent_skills/:id | AgentSkillsController.getSingle | 查询单个记录 |
| GET | /api/v1/uctoo/agent_skills | AgentSkillsController.getMany | 查询记录列表 |

### 5.2 响应格式

#### 成功响应
```json
{
  "data": { ... },
  "currentPage": 1,
  "totalCount": 100,
  "totalPage": 10
}
```

#### 错误响应
```json
{
  "errno": "40001",
  "errmsg": "参数错误"
}
```

### 5.3 错误码设计
| 错误码 | 说明 |
|--------|------|
| 40001 | 参数错误 |
| 40101 | 未授权访问 |
| 40301 | 权限不足 |
| 40401 | 资源不存在 |
| 50001 | 服务器内部错误 |
| 50002 | Git 操作失败 |
| 50003 | 删除失败 |

## 6. 接口设计

### 6.1 内部接口

#### 服务接口
```cangjie
// AgentSkillsService 接口
public interface IAgentSkillsService {
    func create(skill: AgentSkillsPO, userId: String): APIResult<AgentSkillsPO>
    func update(skillId: String, skill: AgentSkillsPO): APIResult<AgentSkillsPO>
    func delete(skillId: String, force: Bool): APIResult<Bool>
    func getById(skillId: String): APIResult<AgentSkillsPO>
    func getList(page: Int32, limit: Int32, filter: ?HashMap<String, Any>): (ArrayList<AgentSkillsPO>, Int64)
}
```

### 6.2 外部接口
- 数据库连接：通过 DatabaseConnectionPool 获取
- AI 模型：通过 ModelManager 调用
- Git 操作：通过 GitManager 调用
- 技能管理：通过 SkillManager 调用

## 7. 安全设计

### 7.1 认证机制
- 使用 JWT Token 进行身份认证
- Token 放在 Authorization Header 中
- Token 有效期：48 小时（可配置）

### 7.2 权限控制
- 基于角色的访问控制 (RBAC)
- 敏感操作需要认证
- 支持行级数据权限

### 7.3 数据安全
- 输入数据验证
- 防止 SQL 注入（使用参数化查询）
- 错误信息不暴露系统内部细节

## 8. 性能设计

### 8.1 性能目标
- API 响应时间 < 500ms（不含 AI 调用）
- 支持至少 100 个并发连接
- WebSocket 连接稳定，支持长连接

### 8.2 优化策略
- 数据库连接池
- 查询结果缓存
- 分页查询
- 异步处理

## 9. 部署设计

### 9.1 部署架构
```
┌─────────────────────────────────────┐
│         Load Balancer               │
│         (域名: 从 .env 读取)         │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│    agentskills-runtime (app)        │
│    端口: 从 .env 读取 (PORT)         │
└─────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│         PostgreSQL                  │
│    连接: 从 .env 读取 (DB_*)         │
└─────────────────────────────────────┘
```

### 9.2 环境配置（.env 文件）

#### 配置读取原则
**所有配置参数必须从 .env 文件读取**，不硬编码任何配置值。

#### 完整环境变量列表
| 环境变量 | 说明 | 默认值 | 是否必填 |
|---------|------|--------|---------|
| **服务器配置** ||||
| PORT | HTTP 服务器监听端口 | 8080 | 否 |
| HOST | HTTP 服务器监听地址 | 127.0.0.1 | 否 |
| SERVER_DOMAIN | 部署域名 | - | 否 |
| **数据库配置** ||||
| DB_HOST | PostgreSQL 数据库地址 | localhost | 否 |
| DB_PORT | PostgreSQL 数据库端口 | 5432 | 否 |
| DB_NAME | 数据库名称 | uctoo | 否 |
| DB_USER | 数据库用户名 | postgres | 否 |
| DB_PASSWORD | 数据库密码 | - | **是** |
| DB_POOL_SIZE | 连接池大小 | 10 | 否 |
| **认证配置** ||||
| JWT_SECRET | JWT 签名密钥 | - | **是** |
| JWT_EXPIRES_IN | Token 有效期（秒） | 172800 | 否 |
| **技能配置** ||||
| SKILL_INSTALL_PATH | 技能安装路径 | ./skills | 否 |
| SKILL_HOT_RELOAD | 是否启用热重载 | true | 否 |
| SKILL_HOT_RELOAD_INTERVAL | 热重载间隔（秒） | 30 | 否 |
| **AI 模型配置** ||||
| MODEL_CONFIG | 模型配置（provider:name 格式） | stepfun:step-3 | 否 |
| MODEL_PROVIDER | 模型提供商 | stepfun | 否 |
| MODEL_NAME | 模型名称 | step-3 | 否 |
| **Git 配置** ||||
| GIT_ENABLED | 是否启用 Git 功能 | true | 否 |
| **日志配置** ||||
| LOG_LEVEL | 日志级别 | INFO | 否 |
| LOG_FILE | 日志文件路径 | ./logs/app.log | 否 |
| **缓存配置** ||||
| REDIS_HOST | Redis 地址 | localhost | 否 |
| REDIS_PORT | Redis 端口 | 6379 | 否 |
| REDIS_PASSWORD | Redis 密码 | - | 否 |

#### .env 文件示例
```env
# 服务器配置
PORT=8080
HOST=127.0.0.1
SERVER_DOMAIN=api.skill-runtime.uctoo.com

# 数据库配置
DB_HOST=localhost
DB_PORT=5432
DB_NAME=uctoo
DB_USER=postgres
DB_PASSWORD=your_password_here
DB_POOL_SIZE=10

# 认证配置
JWT_SECRET=your_jwt_secret_here
JWT_EXPIRES_IN=172800

# 技能配置
SKILL_INSTALL_PATH=./skills
SKILL_HOT_RELOAD=true
SKILL_HOT_RELOAD_INTERVAL=30

# AI 模型配置
MODEL_CONFIG=stepfun:step-3
MODEL_PROVIDER=stepfun
MODEL_NAME=step-3

# Git 配置
GIT_ENABLED=true

# 日志配置
LOG_LEVEL=INFO
LOG_FILE=./logs/app.log

# 缓存配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

### 9.3 配置加载实现
```cangjie
// ConfigLoader.cj - 配置加载器
public class ConfigLoader {
    private var envVars: HashMap<String, String>
    
    public init() {
        // 从 .env 文件加载配置
        this.envVars = loadEnvFile(".env")
    }
    
    public func get(key: String, defaultValue: String): String {
        if (let Some(value) <- envVars.get(key)) {
            return value
        }
        // 尝试从系统环境变量获取
        if (let Some(sysValue) <- getVariable(key)) {
            return sysValue
        }
        return defaultValue
    }
    
    public func getInt(key: String, defaultValue: Int32): Int32 {
        let str = get(key, defaultValue.toString())
        try {
            return Int32.parse(str)
        } catch {
            return defaultValue
        }
    }
    
    public func getBool(key: String, defaultValue: Bool): Bool {
        let str = get(key, defaultValue ? "true" : "false")
        return str.toLowerCase() == "true"
    }
}
```

### 9.4 应用初始化流程
```cangjie
// main.cj - 应用入口
main() {
    // 1. 加载配置
    let config = ConfigLoader()
    let port = config.getInt("PORT", 8080)
    let host = config.get("HOST", "127.0.0.1")
    
    // 2. 初始化数据库连接池
    let dbConfig = DatabaseConfig(
        host: config.get("DB_HOST", "localhost"),
        port: config.getInt("DB_PORT", 5432),
        database: config.get("DB_NAME", "uctoo"),
        username: config.get("DB_USER", "postgres"),
        password: config.get("DB_PASSWORD", ""),
        poolSize: config.getInt("DB_POOL_SIZE", 10)
    )
    let dbPool = DatabaseConnectionPool.getInstance(dbConfig)
    
    // 3. 初始化技能管理
    let skillPath = config.get("SKILL_INSTALL_PATH", "./skills")
    let hotReload = config.getBool("SKILL_HOT_RELOAD", true)
    
    // 4. 初始化 AI 模型
    let modelConfig = config.get("MODEL_CONFIG", "stepfun:step-3")
    let chatModel = ModelManager.createChatModel(modelConfig)
    
    // 5. 创建应用并启动
    let app = Application(config, dbPool, chatModel)
    app.start(port, host)
}
```

## 10. 重构迁移计划

### 10.1 迁移步骤
1. **阶段一**：创建新的模型、服务、控制器、路由文件
2. **阶段二**：实现 agent_skills 表标准 CRUD 功能（自动生成区域）
3. **阶段三**：在定制开发区域实现技能管理 API 功能
4. **阶段四**：迁移 WebSocket 和 MCP 功能
5. **阶段五**：更新 main.cj 入口，注册新路由
6. **阶段六**：测试验证，保留 api 模块作为参考

### 10.2 文件变更清单

**重要说明**：技能管理 API 功能合并到 agent_skills 模块的定制开发区域，不创建单独的 skills 模块。

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新增 | models/uctoo/AgentSkillsPO.cj | agent_skills 数据模型 |
| 新增 | services/uctoo/AgentSkillsService.cj | agent_skills 服务（包含标准 CRUD + 技能管理功能） |
| 新增 | controllers/uctoo/agent_skills/AgentSkillsController.cj | agent_skills 控制器（包含标准 CRUD + 技能管理 API） |
| 新增 | controllers/uctoo/ws/WsChatController.cj | WebSocket 控制器 |
| 新增 | controllers/uctoo/mcp/McpController.cj | MCP 控制器 |
| 新增 | routes/uctoo/agent_skills/AgentSkillsRoute.cj | agent_skills 路由（包含标准 CRUD + 技能管理路由） |
| 新增 | routes/uctoo/ws/WsRoute.cj | WebSocket 路由 |
| 新增 | routes/uctoo/mcp/McpRoute.cj | MCP 路由 |
| 修改 | main.cj | 注册新路由，初始化配置 |
| 保留 | api/* | 作为参考 |
| 新增 | services/uctoo/SkillsRuntimeService.cj | 技能运行时服务 |
| 新增 | controllers/uctoo/agent_skills/AgentSkillsController.cj | agent_skills 控制器 |
| 新增 | controllers/uctoo/skills/SkillsController.cj | 技能管理控制器 |
| 新增 | controllers/uctoo/ws/WsChatController.cj | WebSocket 控制器 |
| 新增 | controllers/uctoo/mcp/McpController.cj | MCP 控制器 |
| 新增 | routes/uctoo/agent_skills/AgentSkillsRoute.cj | agent_skills 路由（包含标准 CRUD + 技能管理路由） |
| 新增 | routes/uctoo/ws/WsRoute.cj | WebSocket 路由 |
| 新增 | routes/uctoo/mcp/McpRoute.cj | MCP 路由 |
| 修改 | main.cj | 注册新路由，初始化配置 |
| 保留 | api/* | 作为参考 |

## 11. 附录

### 11.1 参考文档
- [uctoo V4.0 子系统架构说明](../../../docs/uctoo-v4/uctoo-v4-architecture.md)
- [uctoo V4.0 模块开发指南](../../../docs/uctoo-v4/uctoo-v4-module-development.md)
- [uctoo V4.0 升级方案](D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\specs\004-agent-skill-runtime\uctoo-v4-upgrade.md)
- [API 契约定义](D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\specs\004-agent-skill-runtime\contracts\api-contract.yaml)

### 11.2 变更历史
| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0  | 2026-03-13 | SDD Agent | 初始版本 |
| 1.1  | 2026-03-13 | SDD Agent | 补充功能保留原则；完善 .env 配置说明；添加配置加载实现 |
| 1.2  | 2026-03-13 | SDD Agent | 将技能管理 API 合并到 agent_skills 模块定制开发区域 |
