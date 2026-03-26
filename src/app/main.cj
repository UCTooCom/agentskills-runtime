package magic.app

import magic.app.core.server.HTTPServer
import magic.app.core.router.Router
import magic.app.registry.AutoRouteRegistry
import magic.app.core.middleware.Middleware
import magic.app.core.log.{LoggerFactory, Logger}
import magic.app.core.cache.{CacheManager, CacheConfig}
import magic.app.core.database.{DatabaseConnection, DatabaseConfig, DatabaseConnectionPool}
import magic.app.middlewares.auth.{DeserializeUserMiddleware, RequirePermissionMiddleware}
import magic.app.services.uctoo.{PermissionsService, UserHasRolesService, RoleHasPermissionService, UctooSessionService}
import magic.app.utils.auth.{JWTUtil, CookieUtil}
import magic.app.controllers.uctoo.ws.WsChatController
import magic.app.routes.skill.SkillRoutes
import magic.app.routes.tool.ToolRoutes
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
import std.convert.*
import std.env.{getWorkingDirectory, getVariable}
import std.fs.Path
import std.database.sql.DriverManager
import f_orm.*
import f_config.Config
import f_orm.wrap.ORMConfig
import opengauss.driver.PGDriver // 导入 PostgreSQL 驱动

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

    public init(port: Int32, host: String) {
        eprintln("=== Application.init() called ===")
        logger = LoggerFactory.getInstance().getLogger("uctoo.app")
        eprintln("=== Logger created ===")

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

        server = HTTPServer(port, host)
        
        setupMiddlewares()
        setupRoutes()
    }
    
    /// HTTPS构造函数
    public init(port: Int32, host: String, certPath: String, keyPath: String) {
        eprintln("=== Application.init() with HTTPS called ===")
        logger = LoggerFactory.getInstance().getLogger("uctoo.app")
        eprintln("=== Logger created ===")

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

        // 使用HTTPS服务器
        server = HTTPServer(port, host, certPath, keyPath)
        
        setupMiddlewares()
        setupRoutes()
    }

    private func setupMiddlewares(): Unit {
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

        logger.info("Middlewares configured: DeserializeUser -> RequirePermission (V4 RBAC)")
    }

    private func setupRoutes(): Unit {
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
        let operateLogService = OperateLogService()
        let toolAuditService = ToolAuditService(operateLogService)
        let toolManager = SimpleToolManager()
        let toolDispatcher = ToolDispatcher(
            toolManager,
            userHasRolesService,
            roleHasPermissionService,
            toolAuditService
        )
        let toolRoutes = ToolRoutes(router, toolDispatcher)
        toolRoutes.register()
        LogUtils.info("Tool routes registered successfully")
        
        // 注册WebSocket路由（需要特殊处理）
        let wsChatController = WsChatController(_skillManager, _chatModel)
        server.registerWebSocketRoute("/api/v1/uctoo/ws/chat", wsChatController.handleChat)
        
        // 注册健康检查和应用信息接口
        router.get("/api/v1/health", { req, res =>
            res.status(200).json("{\"status\":\"ok\",\"version\":\"0.0.19\"}")
        })
        
        router.get("/api/v1/info", { req, res =>
            res.status(200).json("{\"name\":\"uctoo-backend-v4\",\"version\":\"0.0.19\",\"language\":\"cangjie\"}")
        })
        
        server.setRouter(router)
        logger.info("All routes configured successfully")
    }

    public func start(): Unit {
        logger.info("Starting uctoo-backend-v4 on ${server.getHost()}:${server.getPort()}")
        server.start()
    }

    public func stop(): Unit {
        logger.info("Stopping uctoo-backend-v4")
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
    
    // 强制使用 opengauss 驱动（因为 PGDriver 的 name 属性是 "opengauss"）
    let ormConfigs: Array<(String, String)> = [
        ("orm_drivers", "opengauss"),
        ("orm_defaultDriver", "opengauss"),
        ("orm_connectionUrl", "postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo"),
        ("opengauss_orm_connectionUrl", "postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo")
    ]
    
    eprintln("=== orm_drivers: opengauss ===")
    eprintln("=== orm_defaultDriver: opengauss ===")
    eprintln("=== orm_connectionUrl: postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo ===")
    eprintln("=== opengauss_orm_connectionUrl: postgresql://postgres:uctoo123@127.0.0.1:5432/uctoo ===")
    
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
        let app = Application(port, host, certPath, keyPath)
        app.start()
    } else {
        // HTTP模式
        eprintln("=== Starting HTTP server on ${host}:${port} ===")
        let app = Application(port, host)
        app.start()
    }
}
