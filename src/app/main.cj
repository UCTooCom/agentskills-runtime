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
import std.fs.Path
import std.database.sql.DriverManager
import f_orm.*
import f_config.Config
import f_orm.wrap.ORMConfig
import opengauss.driver.PGDriver // 导入 PostgreSQL 驱动
import magic.core.agent.{AgentLoadManager, AgentLoader} // 导入 Agent 加载模块
import magic.app.services.sync.SyncManager // 导入同步管理器
import magic.app.services.sync.model.TriggerSource // 导入同步触发源
import magic.app.routes.uctoo.sync.SyncRoute // 导入同步路由
import magic.app.services.billing.{BillingEventHandler, QuotaCheckHandler} // 导入计费事件处理器
import magic.app.services.bridge.{WebSocketEventBridge, AgentRuntimeBridge} // 导入桥接层
import magic.app.services.bridge.AgentPersistenceEventHandler // 导入持久化事件处理器
import std.core.Duration

public class Application {
    private var server: HTTPServer
    private var router: Router = Router()
    private var logger: Logger
    private var dbPool: DatabaseConnectionPool
    private var cacheManager: CacheManager
    private let _skillManager: SkillManager
    private let _progressiveSkillLoader: ProgressiveSkillLoader
    private let _skillInstallPath: String
    private let _chatModel: ChatModel
    private var schedulerEngineInitialized: Bool = false
    private var _agentLoadManager: AgentLoadManager
    private let _requestTimeout: Duration  // 请求超时时间
    
    // 默认超时时间：120秒（2分钟）
    private static var DEFAULT_REQUEST_TIMEOUT: Duration = Duration.second * 120
    
    public init(port: Int32, host: String) {
        this(port, host, DEFAULT_REQUEST_TIMEOUT)
    }
    
    public init(port: Int32, host: String, requestTimeout: Duration) {
        eprintln("=== Application.init() called ===")
        logger = LoggerFactory.getInstance().getLogger("uctoo.app")
        eprintln("=== Logger created ===")
        this._requestTimeout = requestTimeout

        let dbConfig = DatabaseConfig.fromEnv()
        let databaseUrl = dbConfig.url
        eprintln("=== Database URL: ${databaseUrl} ===")
        LogUtils.info("Database URL: ${databaseUrl}")
        
        // 手动注册 PostgreSQL 驱动
        try {
            eprintln("=== Registering PostgreSQL driver ===")
            let driver = DriverManager.getDriver("postgres")
            if (driver.isNone()) {
                eprintln("=== PostgreSQL driver not found, registering manually ===")
                // 导入 opengauss.driver 会自动注册驱动
                // 但如果静态初始化没有执行，我们需要手动触发
                let pgDriver = PGDriver("postgres")
                DriverManager.register("postgres", pgDriver)
                eprintln("=== PostgreSQL driver registered manually ===")
            } else {
                eprintln("=== PostgreSQL driver already registered ===")
            }
        } catch (e: Exception) {
            eprintln("=== Failed to register PostgreSQL driver: ${e.message} ===")
        }
        
        // 调试：检查 ORMConfig 是否正确读取配置
        eprintln("=== Checking ORMConfig ===")
        try {
            let defaultDriver = ORMConfig.getDefaultDriver()
            eprintln("=== ORMConfig.getDefaultDriver(): ${defaultDriver} ===")
            
            let driverNames = ORMConfig.getDriverNames()
            eprintln("=== ORMConfig.getDriverNames(): ${driverNames.toArray()} ===")
            
            let url = ORMConfig.getUrl(driverName: "postgres")
            eprintln("=== ORMConfig.getUrl(postgres): ${url} ===")
            
            let useThirdPartyPool = ORMConfig.getUseThirdPartyPool("postgres")
            eprintln("=== ORMConfig.getUseThirdPartyPool(postgres): ${useThirdPartyPool} ===")
            
            let drivers = ORMConfig.getDrivers()
            for (d in drivers) {
                eprintln("=== Driver: ${d.name} ===")
            }
        } catch (e: Exception) {
            eprintln("=== Failed to read ORMConfig: ${e.message} ===")
        }
        
        // 使用 ORM.initialize() 初始化 ORM
        try {
            eprintln("=== Attempting to initialize ORM ===")
            LogUtils.info("Attempting to initialize ORM")
            
            ORM.initialize()
            eprintln("=== ORM.initialize() completed ===")
            LogUtils.info("ORM initialized successfully")
            
            // 测试ORM连接
            eprintln("=== Testing ORM connection ===")
            let connection = ORM.connection()
            eprintln("=== Successfully connected to database ===")
            LogUtils.info("Successfully connected to database")
            connection.close()
            eprintln("=== ORM initialization completed successfully ===")
        } catch (e: Exception) {
            eprintln("=== Failed to initialize ORM: ${e.message} ===")
            LogUtils.error("Failed to initialize ORM: ${e.message}")
            LogUtils.info("Database features will be disabled")
        }
        
        // Log ORM status after initialization
        eprintln("=== ORM status after initialization ===")
        try {
            let testConnection = ORM.connection()
            eprintln("=== ORM connection still works after initialization ===")
            testConnection.close()
        } catch (e: Exception) {
            eprintln("=== ORM connection failed after initialization: ${e.message} ===")
        }
        eprintln("=== Creating DatabaseConnectionPool ===")
        dbPool = DatabaseConnectionPool.getInstance(dbConfig)
        eprintln("=== DatabaseConnectionPool created ===")

        let cacheConfig = CacheConfig.fromEnv()
        cacheManager = CacheManager.getInstance(cacheConfig)
        eprintln("=== CacheManager created ===")

        eprintln("=== Creating CompositeSkillToolManager ===")
        _skillManager = CompositeSkillToolManager()
        eprintln("=== CompositeSkillToolManager created ===")

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

        eprintln("=== Creating ProgressiveSkillLoader ===")
        let skillDirs = [
            skillInstallPath,
            "${currentDir}/src/examples"
        ]
        _progressiveSkillLoader = ProgressiveSkillLoader(
            skillBaseDirectories: skillDirs,
            defaultSecurityPolicy: SecurityPolicy.default(),
            defaultResourceLimits: ResourceLimits.default()
        )
        eprintln("=== ProgressiveSkillLoader created ===")

        eprintln("=== Loading skills ===")
        try {
            let loadedSkills = _progressiveSkillLoader.loadSkillsToManager(_skillManager)
            eprintln("=== Loaded ${loadedSkills.size} skills ===")
            LogUtils.info("Successfully loaded ${loadedSkills.size} skills from directories")
        } catch (ex: Exception) {
            eprintln("=== Failed to load skills: ${ex.message} ===")
            LogUtils.error("Failed to load skills: ${ex.message}")
        }

        eprintln("=== Configuring ChatModel ===")
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
        eprintln("=== Creating ChatModel: ${modelName} ===")
        _chatModel = ModelManager.createChatModel(modelName)
        eprintln("=== ChatModel created ===")

        // 初始化并加载 Agent
        eprintln("=== Initializing AgentLoadManager ===")
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
                eprintln("=== Main Agent loaded: ${mainAgent.name} ===")
                LogUtils.info("Main Agent loaded: ${mainAgent.name}, type: ${mainAgent.agentType.toString()}")
            case None =>
                eprintln("=== No main agent found in agents.md ===")
                LogUtils.warn("No main agent found in agents.md")
        }

        eprintln("=== Creating HTTPServer ===")
        server = HTTPServer(port, host, _requestTimeout)
        eprintln("=== HTTPServer created with timeout=${_requestTimeout.toSeconds()}s ===")
        
        eprintln("=== Setting up middlewares ===")
        setupMiddlewares()
        eprintln("=== Setting up routes ===")
        setupRoutes()
        
        // 初始化同步管理器
        eprintln("=== Initializing SyncManager ===")
        let agentBasePath = getVariable("SYNC_AGENT_BASE_PATH").getOrDefault({ => "./" })
        let skillBasePath = getVariable("SYNC_SKILL_BASE_PATH").getOrDefault({ => "./.codeartsdoer/skills" })
        SyncManager.initialize(agentBasePath, skillBasePath)
        LogUtils.info("SyncManager initialized with agentBasePath: ${agentBasePath}, skillBasePath: ${skillBasePath}")
        
        // 异步执行启动全量同步（不阻塞启动）
        spawn {
            eprintln("=== Starting async initial sync ===")
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
            eprintln("=== Async initial sync finished ===")
        }
        
        eprintln("=== Application init complete ===")
    }
    
    /// HTTPS构造函数
    public init(port: Int32, host: String, certPath: String, keyPath: String) {
        this(port, host, certPath, keyPath, DEFAULT_REQUEST_TIMEOUT)
    }
    
    public init(port: Int32, host: String, certPath: String, keyPath: String, requestTimeout: Duration) {
        eprintln("=== Application.init() with HTTPS called ===")
        logger = LoggerFactory.getInstance().getLogger("uctoo.app")
        eprintln("=== Logger created ===")
        this._requestTimeout = requestTimeout

        let dbConfig = DatabaseConfig.fromEnv()
        let databaseUrl = dbConfig.url
        eprintln("=== Database URL: ${databaseUrl} ===")
        LogUtils.info("Database URL: ${databaseUrl}")
        
        // 手动注册 PostgreSQL 驱动
        try {
            eprintln("=== Registering PostgreSQL driver ===")
            let driver = DriverManager.getDriver("postgres")
            if (driver.isNone()) {
                eprintln("=== PostgreSQL driver not found, registering manually ===")
                let pgDriver = PGDriver("postgres")
                DriverManager.register("postgres", pgDriver)
                eprintln("=== PostgreSQL driver registered manually ===")
            } else {
                eprintln("=== PostgreSQL driver already registered ===")
            }
        } catch (e: Exception) {
            eprintln("=== Failed to register PostgreSQL driver: ${e.message} ===")
        }
        
        // 初始化ORM
        try {
            eprintln("=== Attempting to initialize ORM ===")
            LogUtils.info("Attempting to initialize ORM")
            
            ORM.initialize()
            eprintln("=== ORM.initialize() completed ===")
            LogUtils.info("ORM initialized successfully")
            
            eprintln("=== Testing ORM connection ===")
            let connection = ORM.connection()
            eprintln("=== Successfully connected to database ===")
            LogUtils.info("Successfully connected to database")
            connection.close()
        } catch (e: Exception) {
            eprintln("=== Failed to initialize ORM: ${e.message} ===")
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
        _chatModel = ModelManager.createChatModel(modelName)

        // 初始化并加载 Agent
        eprintln("=== Initializing AgentLoadManager ===")
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
                eprintln("=== Main Agent loaded: ${mainAgent.name} ===")
                LogUtils.info("Main Agent loaded: ${mainAgent.name}, type: ${mainAgent.agentType.toString()}")
            case None =>
                eprintln("=== No main agent found in agents.md ===")
                LogUtils.warn("No main agent found in agents.md")
        }

        // 使用HTTPS服务器
        server = HTTPServer(port, host, certPath, keyPath, _requestTimeout)
        eprintln("=== HTTPServer created with timeout=${_requestTimeout.toSeconds()}s ===")
        
        setupMiddlewares()
        setupRoutes()
        
        // 初始化同步管理器
        eprintln("=== Initializing SyncManager ===")
        let agentBasePath = getVariable("SYNC_AGENT_BASE_PATH").getOrDefault({ => "./" })
        let skillBasePath = getVariable("SYNC_SKILL_BASE_PATH").getOrDefault({ => "./.codeartsdoer/skills" })
        SyncManager.initialize(agentBasePath, skillBasePath)
        LogUtils.info("SyncManager initialized with agentBasePath: ${agentBasePath}, skillBasePath: ${skillBasePath}")
        
        // 异步执行启动全量同步（不阻塞启动）
        spawn {
            eprintln("=== Starting async initial sync ===")
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
            eprintln("=== Async initial sync finished ===")
        }
        
        eprintln("=== Application init complete ===")
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
        
        // 注册WebSocket路由（需要特殊处理）
        let wsChatController = WsChatController(_skillManager, _chatModel)
        server.registerWebSocketRoute("/api/v1/uctoo/ws/chat", wsChatController.handleChat)
        
        // 注册 WebMCP 路由（支持前端 webmcp-sdk 通信）
        let webmcpRoutes = WebMCPRoutes(router, _skillManager, _chatModel, _agentLoadManager)
        webmcpRoutes.register()
        LogUtils.info("WebMCP routes registered successfully")
        
        // 注册 AI 聊天路由（OpenAI 兼容 API）
        let aiRoutes = AIRoutes(router, _skillManager, _chatModel)
        aiRoutes.register()
        LogUtils.info("AI routes registered successfully")
        
        // 注册同步管理路由
        let syncRoute = SyncRoute(router)
        syncRoute.register()
        LogUtils.info("Sync routes registered successfully")
        
        // 注册健康检查和应用信息接口,todo:从cjpm.toml配置文件读取version版本号
        router.get("/api/v1/health", { req, res =>
            var schedulerJson = "\"scheduler\":{\"running\":false}"
            match (SchedulerEngine.instance) {
                case Some(engine) =>
                    let status = engine.getStatus()
                    schedulerJson = "\"scheduler\":{\"running\":${status.isRunning},\"totalTasks\":${status.totalTasks},\"activeTasks\":${status.activeTasks},\"runningTasks\":${status.runningTasks}}"
                case None =>
                    schedulerJson = "\"scheduler\":{\"running\":false,\"error\":\"not initialized\"}"
            }
            res.status(200).json("{\"status\":\"ok\",\"version\":\"0.0.21\",${schedulerJson}}")
        })
        // todo:从cjpm.toml配置文件读取系统信息
        router.get("/api/v1/info", { req, res =>
            res.status(200).json("{\"name\":\"uctoo-backend-v4\",\"version\":\"0.0.21\",\"language\":\"cangjie\"}")
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
            eprintln("=== Loaded .env from: ${envPath} ===")
            break
        }
    }

    // 将 .env 中的 ORM 配置同步到 fountain 的 Config 中
    eprintln("=== Syncing ORM config to fountain Config ===")
    
    // 从 .env 读取 ORM 配置
    let ormDrivers = AppConfig.env["orm_drivers"].getOrDefault({ => "opengauss" })
    let ormDefaultDriver = AppConfig.env["orm_defaultDriver"].getOrDefault({ => "opengauss" })
    let ormConnectionUrl = AppConfig.env["orm_connectionUrl"].getOrDefault({ => "postgresql://postgres:uctoo123@127.0.0.1:5432/nuanshou" })
    let opengaussOrmConnectionUrl = AppConfig.env["opengauss_orm_connectionUrl"].getOrDefault({ => ormConnectionUrl })
    
    let ormConfigs: Array<(String, String)> = [
        ("orm_drivers", ormDrivers),
        ("orm_defaultDriver", ormDefaultDriver),
        ("orm_connectionUrl", ormConnectionUrl),
        ("opengauss_orm_connectionUrl", opengaussOrmConnectionUrl)
    ]
    
    eprintln("=== orm_drivers: ${ormDrivers} ===")
    eprintln("=== orm_defaultDriver: ${ormDefaultDriver} ===")
    eprintln("=== orm_connectionUrl: ${ormConnectionUrl} ===")
    eprintln("=== opengauss_orm_connectionUrl: ${opengaussOrmConnectionUrl} ===")
    
    // 设置到 fountain 的 Config 中
    Config.set(ormConfigs)
    eprintln("=== ORM config synced to fountain Config ===")
    
    // 刷新 ORMConfig
    ORMConfig.refresh {
        eprintln("=== ORMConfig refreshed ===")
    }

    // 验证ORM配置是否加载
    eprintln("=== Verifying ORM configuration ===")
    match (AppConfig.env["orm_drivers"]) {
        case Some(v) => eprintln("=== orm_drivers: ${v} ===")
        case None => eprintln("=== orm_drivers: NOT SET ===")
    }
    match (AppConfig.env["orm_defaultDriver"]) {
        case Some(v) => eprintln("=== orm_defaultDriver: ${v} ===")
        case None => eprintln("=== orm_defaultDriver: NOT SET ===")
    }
    match (AppConfig.env["orm_connectionUrl"]) {
        case Some(v) => eprintln("=== orm_connectionUrl: ${v} ===")
        case None => eprintln("=== orm_connectionUrl: NOT SET ===")
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
    eprintln("=== WEBMCP_REQUEST_TIMEOUT: ${requestTimeout.toSeconds()}s ===")
    
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
        
        eprintln("=== Starting HTTPS server on ${host}:${port} ===")
        eprintln("=== SSL Certificate: ${certPath} ===")
        eprintln("=== SSL Private Key: ${keyPath} ===")
        let app = Application(port, host, certPath, keyPath, requestTimeout)
        app.start()
    } else {
        // HTTP模式
        eprintln("=== Starting HTTP server on ${host}:${port} ===")
        let app = Application(port, host, requestTimeout)
        app.start()
    }
}
