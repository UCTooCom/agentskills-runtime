/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.registry

import magic.app.core.router.Router
import magic.app.core.log.{Logger, LoggerFactory}
import magic.log.LogUtils
import magic.app.routes.uctoo.uctoo_user.UctooUserAuthRoute
import magic.app.controllers.uctoo.uctoo_user.UctooUserAuthController
import magic.app.services.uctoo.{UctooUserService, UctooSessionService, UserHasRolesService, UctooRoleService, RoleHasPermissionService, PermissionsService}
import magic.app.middlewares.auth.{DeserializeUserMiddleware, RequireUserMiddleware}
import magic.app.utils.auth.{JWTUtil, BcryptUtil, CookieUtil, AuthorizeUtil}
import magic.app.routes.uctoo.mcp.McpRoute
import magic.app.controllers.uctoo.mcp.McpController

/**
 * AutoRouteRegistry - 自动路由注册器
 * 
 * 自动注册所有CRUD路由和认证路由
 * 遵循UCTOO V4规范，提供统一的路由注册入口
 * 
 * 使用方法：
 * ```cangjie
 * let registry = AutoRouteRegistry(router)
 * registry.registerAllRoutes()
 * ```
 * 
 * 新增路由：
 * 1. 使用 crud-generator 生成 CRUD 模块
 * 2. 生成的路由会自动添加到 AutoRouteConfig.cj 中
 * 3. 无需手动修改此文件
 */
public class AutoRouteRegistry {
    private let router: Router
    private let logger: Logger
    private let registry: RouteRegistry
    
    public init(router: Router) {
        this.router = router
        this.logger = LoggerFactory.getInstance().getLogger("AutoRouteRegistry")
        this.registry = RouteRegistry()
        
        // 初始化路由配置
        AutoRouteConfig.initRegistry(registry)
    }
    
    /**
     * 注册所有路由
     * 
     * 包括：
     * 1. CRUD路由（自动生成的标准CRUD接口）
     * 2. 认证路由（登录、注册、登出等）
     * 3. MCP路由
     */
    public func registerAllRoutes(): Unit {
        logger.info("=== Starting automatic route registration ===")
        
        // 注册CRUD路由（自动注册）
        registerCrudRoutes()
        
        // 注册认证路由
        registerAuthRoutes()
        
        // 注册MCP路由
        registerMcpRoutes()
        
        logger.info("=== All routes registered successfully ===")
    }
    
    /**
     * 注册CRUD路由
     * 
     * 通过 RouteRegistry 自动注册所有配置的路由
     */
    public func registerCrudRoutes(): Unit {
        logger.info("Registering CRUD routes...")
        registry.registerAll(router)
    }
    
    /**
     * 注册认证路由
     * 
     * 包括登录、注册、登出等认证相关路由
     */
    public func registerAuthRoutes(): Unit {
        logger.info("Registering Auth routes...")
        
        // 创建认证相关服务
        let uctooUserService = UctooUserService()
        let uctooSessionService = UctooSessionService()
        let jwtUtil = JWTUtil("uctoo-v4-secret-key", 1728000, 6048000)
        let bcryptUtil = BcryptUtil(saltRounds: 10)
        let cookieUtil = CookieUtil(true, None<String>)
        
        // 创建权限相关服务
        let userHasRolesService = UserHasRolesService()
        let uctooRoleService = UctooRoleService()
        let roleHasPermissionService = RoleHasPermissionService()
        let permissionsService = PermissionsService()
        
        let authorizeUtil = AuthorizeUtil(
            uctooUserService, 
            uctooSessionService, 
            jwtUtil, 
            cookieUtil,
            userHasRolesService,
            uctooRoleService,
            roleHasPermissionService,
            permissionsService
        )
        
        // 创建认证控制器
        let uctooUserAuthController = UctooUserAuthController(uctooUserService, bcryptUtil, authorizeUtil, jwtUtil)
        
        // 创建中间件
        let deserializeUserMiddleware = DeserializeUserMiddleware(jwtUtil, uctooSessionService, cookieUtil)
        let requireUserMiddleware = RequireUserMiddleware(uctooUserService)
        
        // 注册认证路由
        let uctooUserAuthRoute = UctooUserAuthRoute(router, uctooUserAuthController, deserializeUserMiddleware, requireUserMiddleware)
        uctooUserAuthRoute.register()
        logger.info("✓ UctooUserAuthRoute registered")
    }
    
    /**
     * 注册MCP路由
     */
    public func registerMcpRoutes(): Unit {
        logger.info("Registering MCP routes...")
        
        let mcpController = McpController()
        let mcpRoute = McpRoute(router, mcpController)
        mcpRoute.register()
        logger.info("✓ McpRoute registered")
    }
    
    /**
     * 获取Router实例
     */
    public func getRouter(): Router {
        return router
    }
    
    /**
     * 获取路由注册表
     */
    public func getRegistry(): RouteRegistry {
        return registry
    }
}
