package magic.app

import magic.app.core.server.HTTPServer
import magic.app.core.router.Router
import magic.app.registry.AutoRouteRegistry
import magic.app.core.middleware.{Middleware, OperateLogMiddleware}
import magic.app.core.log.{LoggerFactory, Logger}
import magic.app.core.cache.{CacheManager, CacheConfig}
import magic.app.core.database.{DatabaseConnection, DatabaseConfig, DatabaseConnectionPool}
import magic.app.middlewares.auth.{DeserializeUserMiddleware, RequirePermissionMiddleware}
import magic.app.middlewares.permission.RowLevelPermissionMiddleware
import magic.app.middlewares.CORSMiddleware
import magic.app.services.uctoo.{PermissionsService, UserHasRolesService, RoleHasPermissionService, UctooSessionService, UctooPermissionProvider}
import magic.app.utils.auth.{JWTUtil, CookieUtil}
import magic.app.controllers.uctoo.ws.WsChatController
import magic.app.routes.skill.SkillRoutes
import magic.app.routes.tool.ToolRoutes
import magic.app.routes.webmcp.WebMCPRoutes
import magic.app.routes.uctoo.ai.AIRoutes
import magic.app.routes.aip.AipRoute
import magic.tool.{ToolDispatcher, BuiltinToolsRegistry, SimpleToolManager}
import magic.app.services.tool.ToolAuditService
import magic.app.services.uctoo.OperateLogService
import magic.config.{Config as AppConfig}
import magic.core.skill.SkillManager
import magic.skill.CompositeSkillToolManager
import magic.skill.application.{ProgressiveSkillLoader, SkillManagementService}
import magic.skill.domain.models.{SecurityPolicy, ResourceLimits}
import magic.log.LogUtils
import magic.model.ModelManager
import magic.core.model.ChatModel
import magic.app.services.crontab.SchedulerEngine
import magic.app.services.crontab.model.SchedulerStatus
import magic.app.dao.uctoo.{CrontabDAO, CrontabLogDAO, CrontabTaskRegistryDAO}
import std.convert.*
import std.env.{getWorkingDirectory, getVariable}
import std.fs.*
import std.fs.Path
import std.database.sql.DriverManager
import f_orm.*
import f_config.Config
import f_orm.wrap.ORMConfig
import pgsql.PostgresDriver // 导入 PostgreSQL 驱动
import magic.core.agent.{AgentLoadManager, AgentLoader} // 导入 Agent 加载模块
import magic.app.services.sync.SyncManager // 导入同步管理器
import magic.app.services.sync.model.TriggerSource // 导入同步触发源
import magic.app.services.uctoo.ConfigSyncHandler // 导入配置同步处理器
import magic.app.routes.uctoo.sync.SyncRoute // 导入同步路由
import magic.app.services.billing.{BillingEventHandler, QuotaCheckHandler} // 导入计费事件处理器
import magic.app.services.bridge.{WebSocketEventBridge, AgentRuntimeBridge} // 导入桥接层
import magic.app.services.bridge.AgentPersistenceEventHandler // 导入持久化事件处理器
import std.core.Duration

/**
 * 从 cjpm.toml 读取 package.version 字段，供健康检查/应用信息端点使用。
 * 解析失败时返回默认值 "0.0.0"，避免阻塞 runtime 启动。
 */
func getVersionFromCjpm(): String {
    let cjpmPath = Path("./cjpm.toml")
    if (exists(cjpmPath)) {
        try {
            let contentBytes = File.readFrom(cjpmPath)
            let content = String.fromUtf8(contentBytes)
            let lines = content.split('\n')
            for (line in lines) {
                if (line.trimAscii().startsWith("version = ")) {
                    let versionPart = line.trimAscii()["version = ".size..]
                    let version = versionPart.trimAscii().replace("\"", "")
                    return version
                }
            }
        } catch (e: Exception) {
            LogUtils.warn("Application", "Failed to read version from cjpm.toml: ${e.message}")
        }
    }
    return "0.0.0"
}

public class Application {
    private var server: HTTPServer
    private var router: Router = Router()
    private var logger: Logger
    private var dbPool: DatabaseConnectionPool
    private var cacheManager: CacheManager
    private let _skillManager: SkillManager
    private let _progressiveSkillLoader: ProgressiveSkillLoader
    private let _skillInstallPath: String
    private var _chatModel: Option<ChatModel> = None
    private var _chatModelError: Option<String> = None
    private var schedulerEngineInitialized: Bool = false
    private var _agentLoadManager: AgentLoadManager
    private let _requestTimeout: Duration  // 请求超时时间
    
    // 默认超时时间：120秒（2分钟）
    private static var DEFAULT_REQUEST_TIMEOUT: Duration = Duration.second * 120
    
    public init(port: Int32, host: String) {
        this(port, host, DEFAULT_REQUEST_TIMEOUT)
    }
    
    public init(port: Int32, host: String, requestTimeout: Duration) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.app")
        this._requestTimeout = requestTimeout

        let dbConfig = DatabaseConfig.fromEnv()
        let databaseUrl = dbConfig.url
        LogUtils.info("Database URL: ${databaseUrl}")
        
        // 手动注册 PostgreSQL 驱动
        try {
            let driver = DriverManager.getDriver("postgres")
            if (driver.isNone()) {
                let pgDriver = PostgresDriver()
                DriverManager.register("postgres", pgDriver)
            }
        } catch (e: Exception) {
            LogUtils.error("Failed to register PostgreSQL driver: ${e.message}")
        }
        
        // 使用 ORM.initialize() 初始化 ORM
        try {
            LogUtils.info("Attempting to initialize ORM")
            ORM.initialize()
            LogUtils.info("ORM initialized successfully")
            // 测试ORM连接
            let connection = ORM.connection()
            LogUtils.info("Successfully connected to database")
            connection.close()
        } catch (e: Exception) {
            LogUtils.error("Failed to initialize ORM: ${e.message}")
            LogUtils.info("Database features will be disabled")
        }
        
        // Log ORM status after initialization
        try {
            let testConnection = ORM.connection()
            testConnection.close()
        } catch (e: Exception) {
            LogUtils.warn("ORM connection failed after initialization: ${e.message}")
        }
        dbPool = DatabaseConnectionPool.getInstance(dbConfig)

        let cacheConfig = CacheConfig.fromEnv()
        cacheManager = CacheManager.getInstance(cacheConfig)

        _skillManager = CompositeSkillToolManager()

        let currentDir = getWorkingDirectory().toString()
        let skillInstallPath = if (let Some(configuredPath) <- getVariable("SKILL_INSTALL_PATH")) {
            if (!configuredPath.isEmpty()) {
                LogUtils.info("Using SKILL_INSTALL_PATH from environment: ${configuredPath}")
                configuredPath
            } else {
                "${currentDir}/skills"
            }
        } else {
            "${currentDir}/skills"
        }
        _skillInstallPath = skillInstallPath

        let skillDirs = [
            skillInstallPath,
            "${currentDir}/src/examples"
        ]
        _progressiveSkillLoader = ProgressiveSkillLoader(
            skillBaseDirectories: skillDirs,
            defaultSecurityPolicy: SecurityPolicy.default(),
            defaultResourceLimits: ResourceLimits.default()
        )

        try {
            let loadedSkills = _progressiveSkillLoader.loadSkillsToManager(_skillManager)
            LogUtils.info("Successfully loaded ${loadedSkills.size} skills from directories")
        } catch (ex: Exception) {
            LogUtils.error("Failed to load skills: ${ex.message}")
        }

        let modelConfigOpt = getVariable("MODEL_CONFIG")
        let modelProviderOpt = getVariable("MODEL_PROVIDER")
        let modelNameOpt = getVariable("MODEL_NAME")

        let modelName = if (modelConfigOpt.isSome()) {
            let mc = modelConfigOpt.getOrThrow()
            if (!mc.isEmpty()) {
                mc
            } else if (modelProviderOpt.isSome() && modelNameOpt.isSome()) {
                let mp = modelProviderOpt.getOrThrow()
                let mn = modelNameOpt.getOrThrow()
                "${mp}:${mn}"
            } else {
                "stepfun:step-3"
            }
        } else if (modelProviderOpt.isSome() && modelNameOpt.isSome()) {
            let mp = modelProviderOpt.getOrThrow()
            let mn = modelNameOpt.getOrThrow()
            "${mp}:${mn}"
        } else {
            "stepfun:step-3"
        }
        LogUtils.info("Using chat model: ${modelName}")
        _chatModel = None
        _chatModelError = None
        try {
            _chatModel = Some(ModelManager.createChatModel(modelName))
            LogUtils.info("Chat model created successfully")
        } catch (e: Exception) {
            _chatModelError = Some("${e.message}")
            LogUtils.error("Chat model creation failed (framework continues with degraded AI): ${e.message}")
            println("WARN: Chat model configuration invalid - AI features disabled until fixed. Error: ${e.message}")
        }

        // 初始化并加载 Agent
        let agentsDirs = [
            "${currentDir}/agents",
            "${currentDir}/src/agents",
            "${currentDir}/AGENTS.md"
        ]
        _agentLoadManager = AgentLoadManager("${currentDir}")
        _agentLoadManager.loadFromDirs(agentsDirs)
        LogUtils.info("Agent definitions loaded from agents.md")
        
        // 打印加载的主 Agent 信息
        match (_agentLoadManager.getMainAgent()) {
            case Some(mainAgent) =>
                LogUtils.info("Main Agent loaded: ${mainAgent.name}, type: ${mainAgent.agentType.toString()}")
            case None =>
                LogUtils.warn("No main agent found in agents.md")
        }

        server = HTTPServer(port, host, _requestTimeout)
        setupMiddlewares()
        setupRoutes()
        
        // 初始化同步管理器
        let agentBasePath = getVariable("SYNC_AGENT_BASE_PATH").getOrDefault({ => "./" })
        let skillBasePath = getVariable("SYNC_SKILL_BASE_PATH").getOrDefault({ => "./.codeartsdoer/skills" })
        SyncManager.initialize(agentBasePath, skillBasePath)
        LogUtils.info("SyncManager initialized with agentBasePath: ${agentBasePath}, skillBasePath: ${skillBasePath}")
        
        // 启动时同步 .env 配置到 config 表（同步执行，确保在服务就绪前完成）
        try {
            let configSyncHandler = ConfigSyncHandler()
            let configSyncResult = configSyncHandler.startupSync()
            LogUtils.info("Config startup sync completed - total:${configSyncResult.totalCount}, success:${configSyncResult.successCount}, failed:${configSyncResult.failedCount}")
            for (detail in configSyncResult.details) {
                if (!detail.success) {
                    LogUtils.error("Config sync failed for ${detail.envKey}: ${detail.errorMessage ?? "unknown"}")
                }
            }
        } catch (e: Exception) {
            LogUtils.error("Config startup sync failed: ${e.message}")
        }
        
        // 异步执行启动全量同步（不阻塞启动）
        spawn {
            try {
                let result = SyncManager.instance?.syncAll(TriggerSource.Startup)
                match (result) {
                    case Some(batchResult) =>
                        LogUtils.info("Initial sync completed - total:${batchResult.totalCount}, success:${batchResult.successCount}, failed:${batchResult.failedCount}")
                    case None =>
                        LogUtils.warn("SyncManager not initialized, skipping initial sync")
                }
            } catch (e: Exception) {
                LogUtils.error("Initial sync failed: ${e.message}")
            }
        }
        
        LogUtils.info("Application init complete")
    }
    
    /// HTTPS构造函数
    public init(port: Int32, host: String, certPath: String, keyPath: String) {
        this(port, host, certPath, keyPath, DEFAULT_REQUEST_TIMEOUT)
    }
    
    public init(port: Int32, host: String, certPath: String, keyPath: String, requestTimeout: Duration) {
        logger = LoggerFactory.getInstance().getLogger("uctoo.app")
        this._requestTimeout = requestTimeout

        let dbConfig = DatabaseConfig.fromEnv()
        let databaseUrl = dbConfig.url
        LogUtils.info("Database URL: ${databaseUrl}")
        
        // 手动注册 PostgreSQL 驱动
        try {
            let driver = DriverManager.getDriver("postgres")
            if (driver.isNone()) {
                let pgDriver = PostgresDriver()
                DriverManager.register("postgres", pgDriver)
                LogUtils.info("PostgreSQL driver registered manually")
            } else {
                LogUtils.info("PostgreSQL driver already registered")
            }
        } catch (e: Exception) {
            LogUtils.error("Failed to register PostgreSQL driver: ${e.message}")
        }
        
        // 初始化ORM
        try {
            LogUtils.info("Attempting to initialize ORM")
            ORM.initialize()
            LogUtils.info("ORM initialized successfully")
            let connection = ORM.connection()
            LogUtils.info("Successfully connected to database")
            connection.close()
        } catch (e: Exception) {
            LogUtils.error("Failed to initialize ORM: ${e.message}")
        }
        
        dbPool = DatabaseConnectionPool.getInstance(dbConfig)
        let cacheConfig = CacheConfig.fromEnv()
        cacheManager = CacheManager.getInstance(cacheConfig)
        _skillManager = CompositeSkillToolManager()

        let currentDir = getWorkingDirectory().toString()
        let skillInstallPath = if (let Some(configuredPath) <- getVariable("SKILL_INSTALL_PATH")) {
            if (!configuredPath.isEmpty()) {
                LogUtils.info("Using SKILL_INSTALL_PATH from environment: ${configuredPath}")
                configuredPath
            } else {
                "${currentDir}/skills"
            }
        } else {
            "${currentDir}/skills"
        }
        _skillInstallPath = skillInstallPath

        let skillDirs = [
            skillInstallPath,
            "${currentDir}/src/examples"
        ]
        _progressiveSkillLoader = ProgressiveSkillLoader(
            skillBaseDirectories: skillDirs,
            defaultSecurityPolicy: SecurityPolicy.default(),
            defaultResourceLimits: ResourceLimits.default()
        )

        try {
            let loadedSkills = _progressiveSkillLoader.loadSkillsToManager(_skillManager)
            LogUtils.info("Successfully loaded ${loadedSkills.size} skills from directories")
        } catch (ex: Exception) {
            LogUtils.error("Failed to load skills: ${ex.message}")
        }

        let modelConfigOpt = getVariable("MODEL_CONFIG")
        let modelProviderOpt = getVariable("MODEL_PROVIDER")
        let modelNameOpt = getVariable("MODEL_NAME")

        let modelName = if (modelConfigOpt.isSome()) {
            let mc = modelConfigOpt.getOrThrow()
            if (!mc.isEmpty()) {
                mc
            } else if (modelProviderOpt.isSome() && modelNameOpt.isSome()) {
                let mp = modelProviderOpt.getOrThrow()
                let mn = modelNameOpt.getOrThrow()
                "${mp}:${mn}"
            } else {
                "stepfun:step-3"
            }
        } else if (modelProviderOpt.isSome() && modelNameOpt.isSome()) {
            let mp = modelProviderOpt.getOrThrow()
            let mn = modelNameOpt.getOrThrow()
            "${mp}:${mn}"
        } else {
            "stepfun:step-3"
        }
        LogUtils.info("Using chat model: ${modelName}")
        _chatModel = None
        _chatModelError = None
        try {
            _chatModel = Some(ModelManager.createChatModel(modelName))
            LogUtils.info("Chat model created successfully")
        } catch (e: Exception) {
            _chatModelError = Some("${e.message}")
            LogUtils.error("Chat model creation failed (framework continues with degraded AI): ${e.message}")
            println("WARN: Chat model configuration invalid - AI features disabled until fixed. Error: ${e.message}")
        }

        // 初始化并加载 Agent
        let agentsDirs = [
            "${currentDir}/agents",
            "${currentDir}/src/agents",
            "${currentDir}/AGENTS.md"
        ]
        _agentLoadManager = AgentLoadManager("${currentDir}")
        _agentLoadManager.loadFromDirs(agentsDirs)
        LogUtils.info("Agent definitions loaded from agents.md")
        
        // 打印加载的主 Agent 信息
        match (_agentLoadManager.getMainAgent()) {
            case Some(mainAgent) =>
                LogUtils.info("Main Agent loaded: ${mainAgent.name}, type: ${mainAgent.agentType.toString()}")
            case None =>
                LogUtils.warn("No main agent found in agents.md")
        }

        // 使用HTTPS服务器
        server = HTTPServer(port, host, certPath, keyPath, _requestTimeout)
        
        setupMiddlewares()
        setupRoutes()
        
        // 初始化同步管理器
        let agentBasePath = getVariable("SYNC_AGENT_BASE_PATH").getOrDefault({ => "./" })
        let skillBasePath = getVariable("SYNC_SKILL_BASE_PATH").getOrDefault({ => "./.codeartsdoer/skills" })
        SyncManager.initialize(agentBasePath, skillBasePath)
        LogUtils.info("SyncManager initialized with agentBasePath: ${agentBasePath}, skillBasePath: ${skillBasePath}")
        
        // 启动时同步 .env 配置到 config 表（同步执行，确保在服务就绪前完成）
        try {
            let configSyncHandler = ConfigSyncHandler()
            let configSyncResult = configSyncHandler.startupSync()
            LogUtils.info("Config startup sync completed - total:${configSyncResult.totalCount}, success:${configSyncResult.successCount}, failed:${configSyncResult.failedCount}")
            for (detail in configSyncResult.details) {
                if (!detail.success) {
                    LogUtils.error("Config sync failed for ${detail.envKey}: ${detail.errorMessage ?? "unknown"}")
                }
            }
        } catch (e: Exception) {
            LogUtils.error("Config startup sync failed: ${e.message}")
        }
        
        // 异步执行启动全量同步（不阻塞启动）
        spawn {
            try {
                let result = SyncManager.instance?.syncAll(TriggerSource.Startup)
                match (result) {
                    case Some(batchResult) =>
                        LogUtils.info("Initial sync completed - total:${batchResult.totalCount}, success:${batchResult.successCount}, failed:${batchResult.failedCount}")
                    case None =>
                        LogUtils.warn("SyncManager not initialized, skipping initial sync")
                }
            } catch (e: Exception) {
                LogUtils.error("Initial sync failed: ${e.message}")
            }
        }
        
        LogUtils.info("Application init complete")
    }

    private func setupMiddlewares(): Unit {
        // 0. CORS 中间件 - 处理跨域请求
        let corsMiddleware = CORSMiddleware()
        server.use(corsMiddleware)
        
        let jwtSecret = if (let Some(secret) <- getVariable("JWT_SECRET")) {
            secret
        } else {
            "uctoo-v4-secret-key"
        }

        // 创建JWT工具和Cookie工具
        let jwtUtil = JWTUtil(jwtSecret, 1728000, 6048000)  // access_token: 20天, refresh_token: 70天
        let cookieUtil = CookieUtil(true, None<String>)
        let sessionService = UctooSessionService()

        // 1. Token反序列化中间件 - 解析Token但不阻止请求
        let deserializeUserMiddleware = DeserializeUserMiddleware(jwtUtil, sessionService, cookieUtil)
        server.use(deserializeUserMiddleware)

        // 2. V4标准RBAC权限检查中间件 - 检查用户权限
        let permissionsService = PermissionsService()
        let userHasRolesService = UserHasRolesService()
        let roleHasPermissionService = RoleHasPermissionService()
        let requirePermissionMiddleware = RequirePermissionMiddleware(
            permissionsService,
            userHasRolesService,
            roleHasPermissionService
        )
        server.use(requirePermissionMiddleware)

        // 3. 行级数据权限中间件 - 检查数据行级别的访问控制
        let rowLevelPermissionMiddleware = RowLevelPermissionMiddleware("entity")
        server.use(rowLevelPermissionMiddleware)

        // 4. 操作日志中间件 - 记录所有API请求
        let operateLogMiddleware = OperateLogMiddleware()
        server.use(operateLogMiddleware)

        logger.info("Middlewares configured: CORS -> DeserializeUser -> RequirePermission (V4 RBAC) -> RowLevelPermission -> OperateLog")
    }

    private func setupRoutes(): Unit {
        // 注册全局Router引用（供loadRouteFromApp等接口在运行时获取所有路由）
        router.registerAsGlobal()
        
        // 使用自动路由注册器注册所有路由
        let routeRegistry = AutoRouteRegistry(router)
        routeRegistry.registerAllRoutes()
        
        // 注册技能管理路由（独立，不与CRUD混合）
        let skillManagementService = SkillManagementService()
        let skillRoutes = SkillRoutes(
            router,
            _skillManager,
            skillManagementService,
            _progressiveSkillLoader
        )
        skillRoutes.register()
        
        // 注册工具管理路由
        let userHasRolesService = UserHasRolesService()
        let roleHasPermissionService = RoleHasPermissionService()
        let permissionProvider = UctooPermissionProvider(userHasRolesService, roleHasPermissionService)
        let operateLogService = OperateLogService()
        let toolAuditService = ToolAuditService(operateLogService)
        let toolManager = SimpleToolManager()
        BuiltinToolsRegistry.registerAll(toolManager)
        let toolDispatcher = ToolDispatcher(
            toolManager,
            permissionProvider,
            toolAuditService
        )
        let toolRoutes = ToolRoutes(router, toolDispatcher)
        toolRoutes.register()
        LogUtils.info("Tool routes registered successfully")
        
        // 注册聊天相关路由（ChatModel 配置错误时跳过，仅禁用 AI 聊天功能，框架其余部分照常运行）
        if (let Some(chatModel) <- _chatModel) {
            // 注册WebSocket路由（需要特殊处理）
            let wsChatController = WsChatController(_skillManager, chatModel)
            server.registerWebSocketRoute("/api/v1/uctoo/ws/chat", wsChatController.handleChat)

            // 注册 WebMCP 路由（支持前端 webmcp-sdk 通信）
            let webmcpRoutes = WebMCPRoutes(router, _skillManager, chatModel, _agentLoadManager)
            webmcpRoutes.register()
            LogUtils.info("WebMCP routes registered successfully")

            // 注册 WebMCP WebSocket 路由（需要特殊处理）
            let webmcpController = webmcpRoutes.getController()
            server.registerWebSocketRoute("/api/v1/uctoo/webmcp/mcp", webmcpController.handleConnection)
            server.registerWebSocketRoute("/api/v1/webmcp/mcp", webmcpController.handleConnection)

            // 注册 AI 聊天路由（OpenAI 兼容 API）
            let aiRoutes = AIRoutes(router, _skillManager, chatModel)
            aiRoutes.register()
            LogUtils.info("AI routes registered successfully")
        } else {
            LogUtils.warn("Chat routes skipped (AI features disabled): invalid model configuration - fix MODEL_CONFIG/MODEL_PROVIDER/MODEL_NAME in .env and restart")
            println("WARN: Chat routes skipped - AI features disabled until MODEL_CONFIG is fixed. Other framework features work normally.")
        }
        
        // 注册同步管理路由
        let syncRoute = SyncRoute(router)
        syncRoute.register()
        LogUtils.info("Sync routes registered successfully")
        
        // 注册 AIP 智能体互联路由
        let aipRoute = AipRoute(router)
        aipRoute.register()
        LogUtils.info("AIP routes registered successfully")
        
        // 注册健康检查和应用信息接口（version 从 cjpm.toml 读取）
        let runtimeVersion = getVersionFromCjpm()
        router.get("/api/v1/health", { req, res =>
            var schedulerJson = "\"scheduler\":{\"running\":false}"
            match (SchedulerEngine.instance) {
                case Some(engine) =>
                    let status = engine.getStatus()
                    schedulerJson = "\"scheduler\":{\"running\":${status.isRunning},\"totalTasks\":${status.totalTasks},\"activeTasks\":${status.activeTasks},\"runningTasks\":${status.runningTasks}}"
                case None =>
                    schedulerJson = "\"scheduler\":{\"running\":false,\"error\":\"not initialized\"}"
            }
            // 暴露 ChatModel 配置状态，供 web/PC 端检测大模型配置是否正确
            var chatModelJson = "\"chatModel\":{\"available\":true}"
            if (_chatModel.isNone()) {
                let errMsg = _chatModelError.getOrDefault({ => "unknown error" })
                // 转义 JSON 字符串中的特殊字符
                let safeErrMsg = errMsg.replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r")
                chatModelJson = "\"chatModel\":{\"available\":false,\"error\":\"${safeErrMsg}\"}"
            }
            res.status(200).json("{\"status\":\"ok\",\"version\":\"${runtimeVersion}\",${schedulerJson},${chatModelJson}}")
        })
        // todo:从cjpm.toml配置文件读取系统信息
        router.get("/api/v1/info", { req, res =>
            res.status(200).json("{\"name\":\"uctoo-backend-v4\",\"version\":\"${runtimeVersion}\",\"language\":\"cangjie\"}")
        })
        
        // 初始化调度引擎
        try {
            let sqlExecutor = ORM.executor()
            let crontabDAO = sqlExecutor as CrontabDAO
            let crontabLogDAO = sqlExecutor as CrontabLogDAO
            let crontabTaskRegistryDAO = sqlExecutor as CrontabTaskRegistryDAO
            if (crontabDAO.isSome() && crontabLogDAO.isSome() && crontabTaskRegistryDAO.isSome()) {
                SchedulerEngine.initialize(crontabDAO.getOrThrow(), crontabLogDAO.getOrThrow(), crontabTaskRegistryDAO.getOrThrow())
                schedulerEngineInitialized = true
                LogUtils.info("SchedulerEngine initialized successfully")
            } else {
                LogUtils.error("Failed to cast SqlExecutor to DAO interfaces")
            }
        } catch (e: Exception) {
            LogUtils.error("Failed to initialize SchedulerEngine: ${e.message}")
        }
        
        // 注册全局事件处理器（数据流闭环关键步骤）
        try {
            let billingHandler = BillingEventHandler()
            billingHandler.registerGlobalHandlers()
            LogUtils.info("BillingEventHandler registered to EventHandlerManager.global")
        } catch (e: Exception) {
            LogUtils.error("Failed to register BillingEventHandler: ${e.message}")
        }
        
        try {
            let quotaHandler = QuotaCheckHandler()
            quotaHandler.registerGlobalHandlers()
            LogUtils.info("QuotaCheckHandler registered to EventHandlerManager.global")
        } catch (e: Exception) {
            LogUtils.error("Failed to register QuotaCheckHandler: ${e.message}")
        }
        
        try {
            WebSocketEventBridge.instance.registerGlobalHandlers()
            LogUtils.info("WebSocketEventBridge registered to EventHandlerManager.global")
        } catch (e: Exception) {
            LogUtils.error("Failed to register WebSocketEventBridge: ${e.message}")
        }
        
        try {
            let persistenceHandler = AgentPersistenceEventHandler()
            persistenceHandler.registerGlobalHandlers()
            LogUtils.info("AgentPersistenceEventHandler registered to EventHandlerManager.global")
        } catch (e: Exception) {
            LogUtils.error("Failed to register AgentPersistenceEventHandler: ${e.message}")
        }
        
        // 预加载数据库中的 Agent 到运行时
        try {
            let agents = AgentRuntimeBridge.instance.loadAllFromDatabase()
            LogUtils.info("Loaded ${agents.size.toString()} agents from database into runtime")
        } catch (e: Exception) {
            LogUtils.error("Failed to load agents from database: ${e.message}")
        }
        
        server.setRouter(router)
        logger.info("All routes configured successfully")
    }

    public func start(): Unit {
        logger.info("Starting uctoo-backend-v4 on ${server.getHost()}:${server.getPort()}")
        server.start()
    }

    public func stop(): Unit {
        logger.info("Stopping uctoo-backend-v4")
        
        // 优雅关闭调度引擎
        if (schedulerEngineInitialized) {
            match (SchedulerEngine.instance) {
                case Some(engine) =>
                    try {
                        engine.gracefulShutdown()
                        LogUtils.info("SchedulerEngine shutdown completed")
                    } catch (e: Exception) {
                        LogUtils.error("SchedulerEngine shutdown error: ${e.message}")
                    }
                case None =>
                    LogUtils.info("SchedulerEngine not initialized, skip shutdown")
            }
        }
        
        server.stop()
        dbPool.closeAll()
        cacheManager.close()
    }
}

main() {
    let envPaths = [Path("./.env"), Path("../.env")]
    for (envPath in envPaths) {
        let result = AppConfig.env.load(envPath)
        if (!result.contains("does not exist")) {
            break
        }
    }

    // 将 .env 中的 ORM 配置同步到 fountain 的 Config 中
    let ormDrivers = AppConfig.env["orm_drivers"].getOrDefault({ => "postgres" })
    let ormDefaultDriver = AppConfig.env["orm_defaultDriver"].getOrDefault({ => "postgres" })
    let ormConnectionUrl = AppConfig.env["orm_connectionUrl"].getOrDefault({ => "postgresql://postgres:uctoo123@127.0.0.1:5432/nuanshou" })
    let postgresOrmConnectionUrl = AppConfig.env["postgres_orm_connectionUrl"].getOrDefault({ => ormConnectionUrl })
    
    let ormConfigs: Array<(String, String)> = [
        ("orm_drivers", ormDrivers),
        ("orm_defaultDriver", ormDefaultDriver),
        ("orm_connectionUrl", ormConnectionUrl),
        ("postgres_orm_connectionUrl", postgresOrmConnectionUrl)
    ]
    
    // 设置到 fountain 的 Config 中
    Config.set(ormConfigs)
    
    // 刷新 ORMConfig
    ORMConfig.refresh {
    }

    AppConfig.logLevel = AppConfig.env["LOG_LEVEL"].getOrDefault({ => "debug" })
    AppConfig.logFile = AppConfig.env["LOG_FILE"].getOrDefault({ => "./logs/agentskills-runtime.log" })

    // 读取端口配置
    let portStr = AppConfig.env["PORT"]
    let port = if (let Some(p) <- portStr) {
        Int32.parse(p)
    } else {
        Int32(8080)
    }

    // 读取主机配置
    let hostStr = AppConfig.env["HOST"]
    let host = if (let Some(h) <- hostStr) {
        h
    } else {
        "0.0.0.0"
    }
    
    // 读取请求超时配置（秒）
    let timeoutStr = AppConfig.env["WEBMCP_REQUEST_TIMEOUT"]
    let requestTimeout = if (let Some(t) <- timeoutStr) {
        let seconds = Int64.parse(t)
        Duration.second * seconds
    } else {
        Duration.second * 300  // 默认300秒（5分钟），Agent执行技能需要更长时间
    }
    
    // 检查是否启用HTTPS
    let backendUrlOpt = AppConfig.env["BACKEND_URL"]
    let useHttps = if (let Some(url) <- backendUrlOpt) {
        url.startsWith("https://")
    } else {
        false
    }
    
    if (useHttps) {
        // HTTPS模式 - 读取SSL证书配置
        let certFileName = AppConfig.env["CERT_FILE_NAME"].getOrDefault({ => "ssl/server.crt" })
        let keyFileName = AppConfig.env["KEY_FILE_NAME"].getOrDefault({ => "ssl/server.key" })
        
        // 如果配置的不是绝对路径，则相对于当前工作目录
        let certPath = if (certFileName.startsWith("/") || certFileName.startsWith("./") || certFileName.contains(":/") || certFileName.contains(":\\\\")) {
            certFileName
        } else {
            "./${certFileName}"
        }
        
        let keyPath = if (keyFileName.startsWith("/") || keyFileName.startsWith("./") || keyFileName.contains(":/") || keyFileName.contains(":\\\\")) {
            keyFileName
        } else {
            "./${keyFileName}"
        }
        
        println("Starting HTTPS server on ${host}:${port}")
        println("SSL Certificate: ${certPath}")
        println("SSL Private Key: ${keyPath}")
        try {
            let app = Application(port, host, certPath, keyPath, requestTimeout)
            app.start()
        } catch (ex: Exception) {
            println("FATAL: Application failed: ${ex.message}")
            ex.printStackTrace()
        }
    } else {
        // HTTP模式
        println("Starting HTTP server on ${host}:${port}")
        try {
            let app = Application(port, host, requestTimeout)
            app.start()
        } catch (ex: Exception) {
            println("FATAL: Application failed: ${ex.message}")
            ex.printStackTrace()
        }
    }
}
