/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 * 
 * 此文件由 crud-generator 自动生成，请勿手动修改
 * 生成时间：2026-03-24
 * 
 * 路由注册配置
 * 每次使用 crud-generator 生成新的 CRUD 模块时，会自动更新此文件
 */
package magic.app.registry

import magic.app.core.router.Router
import magic.app.routes.uctoo.entity.EntityRoute
import magic.app.routes.uctoo.uctoo_user.UctooUserRoute
import magic.app.routes.uctoo.uctoo_session.UctooSessionRoute
import magic.app.routes.uctoo.user_group.UserGroupRoute
import magic.app.routes.uctoo.permissions.PermissionsRoute
import magic.app.routes.uctoo.user_has_group.UserHasGroupRoute
import magic.app.routes.uctoo.group_has_permission.GroupHasPermissionRoute
import magic.app.routes.uctoo.user_has_account.UserHasAccountRoute
import magic.app.routes.uctoo.uctoo_role.UctooRoleRoute
import magic.app.routes.uctoo.user_has_roles.UserHasRolesRoute
import magic.app.routes.uctoo.role_has_permission.RoleHasPermissionRoute
import magic.app.routes.uctoo.data_access_authorization.DataAccessAuthorizationRoute
import magic.app.routes.uctoo.login_log.LoginLogRoute
import magic.app.routes.uctoo.operate_log.OperateLogRoute
import magic.app.controllers.uctoo.entity.EntityController
import magic.app.controllers.uctoo.uctoo_user.UctooUserController
import magic.app.controllers.uctoo.uctoo_session.UctooSessionController
import magic.app.controllers.uctoo.user_group.UserGroupController
import magic.app.controllers.uctoo.permissions.PermissionsController
import magic.app.controllers.uctoo.user_has_group.UserHasGroupController
import magic.app.controllers.uctoo.group_has_permission.GroupHasPermissionController
import magic.app.controllers.uctoo.user_has_account.UserHasAccountController
import magic.app.controllers.uctoo.uctoo_role.UctooRoleController
import magic.app.controllers.uctoo.user_has_roles.UserHasRolesController
import magic.app.controllers.uctoo.role_has_permission.RoleHasPermissionController
import magic.app.controllers.uctoo.data_access_authorization.DataAccessAuthorizationController
import magic.app.controllers.uctoo.login_log.LoginLogController
import magic.app.controllers.uctoo.operate_log.OperateLogController
import magic.app.services.uctoo.{
    EntityService,
    UctooUserService,
    UctooSessionService,
    UserGroupService,
    PermissionsService,
    UserHasGroupService,
    GroupHasPermissionService,
    UserHasAccountService,
    UctooRoleService,
    UserHasRolesService,
    RoleHasPermissionService,
    DataAccessAuthorizationService,
    LoginLogService,
    OperateLogService
}

/**
 * AutoRouteConfig - 自动路由配置
 * 
 * 此类提供所有 CRUD 路由的自动注册配置
 * 由 crud-generator 自动维护
 */
public class AutoRouteConfig {
    
    /**
     * 初始化路由注册表
     * @param registry 路由注册表
     */
    public static func initRegistry(registry: RouteRegistry): Unit {
        
        // OperateLog 路由
        registry.add(RouteEntry(
            "operate_log",
            "/api/v1/uctoo/operate_log",
            10,
            true,
            { router: Router =>
                let service = OperateLogService()
                let controller = OperateLogController(service)
                let route = OperateLogRoute(router, controller)
                route.register()
            }
        ))
        
        // LoginLog 路由
        registry.add(RouteEntry(
            "login_log",
            "/api/v1/uctoo/login_log",
            10,
            true,
            { router: Router =>
                let service = LoginLogService()
                let controller = LoginLogController(service)
                let route = LoginLogRoute(router, controller)
                route.register()
            }
        ))
        // ==================== CRUD 路由配置 ====================
        
        // 1. Entity 路由
        registry.add(RouteEntry(
            "entity",
            "/api/v1/uctoo/entity",
            10,
            true,
            { router: Router =>
                let service = EntityService()
                let controller = EntityController(service)
                let route = EntityRoute(router, controller)
                route.register()
            }
        ))
        
        // 2. UctooUser 路由
        registry.add(RouteEntry(
            "uctoo_user",
            "/api/v1/uctoo/uctoo_user",
            20,
            true,
            { router: Router =>
                let service = UctooUserService()
                let controller = UctooUserController(service)
                let route = UctooUserRoute(router, controller)
                route.register()
            }
        ))
        
        // 3. UctooSession 路由
        registry.add(RouteEntry(
            "uctoo_session",
            "/api/v1/uctoo/uctoo_session",
            30,
            true,
            { router: Router =>
                let service = UctooSessionService()
                let controller = UctooSessionController(service)
                let route = UctooSessionRoute(router, controller)
                route.register()
            }
        ))
        
        // 4. UserGroup 路由
        registry.add(RouteEntry(
            "user_group",
            "/api/v1/uctoo/user_group",
            40,
            true,
            { router: Router =>
                let service = UserGroupService()
                let controller = UserGroupController(service)
                let route = UserGroupRoute(router, controller)
                route.register()
            }
        ))
        
        // 5. Permissions 路由
        registry.add(RouteEntry(
            "permissions",
            "/api/v1/uctoo/permissions",
            50,
            true,
            { router: Router =>
                let service = PermissionsService()
                let controller = PermissionsController(service)
                let route = PermissionsRoute(router, controller)
                route.register()
            }
        ))
        
        // 6. UserHasGroup 路由 (复合主键)
        registry.add(RouteEntry(
            "user_has_group",
            "/api/v1/uctoo/user_has_group",
            60,
            true,
            { router: Router =>
                let service = UserHasGroupService()
                let controller = UserHasGroupController(service)
                let route = UserHasGroupRoute(router, controller)
                route.register()
            }
        ))
        
        // 7. GroupHasPermission 路由 (复合主键)
        registry.add(RouteEntry(
            "group_has_permission",
            "/api/v1/uctoo/group_has_permission",
            70,
            true,
            { router: Router =>
                let service = GroupHasPermissionService()
                let controller = GroupHasPermissionController(service)
                let route = GroupHasPermissionRoute(router, controller)
                route.register()
            }
        ))
        
        // 8. UserHasAccount 路由
        registry.add(RouteEntry(
            "user_has_account",
            "/api/v1/uctoo/user_has_account",
            80,
            true,
            { router: Router =>
                let service = UserHasAccountService()
                let controller = UserHasAccountController(service)
                let route = UserHasAccountRoute(router, controller)
                route.register()
            }
        ))
        
        // ==================== V4 权限体系路由配置 ====================
        
        // 9. UctooRole 路由 (角色表)
        registry.add(RouteEntry(
            "uctoo_role",
            "/api/v1/uctoo/uctoo_role",
            90,
            true,
            { router: Router =>
                let service = UctooRoleService()
                let controller = UctooRoleController(service)
                let route = UctooRoleRoute(router, controller)
                route.register()
            }
        ))
        
        // 10. UserHasRoles 路由 (用户-角色关联表)
        registry.add(RouteEntry(
            "user_has_roles",
            "/api/v1/uctoo/user_has_roles",
            100,
            true,
            { router: Router =>
                let service = UserHasRolesService()
                let controller = UserHasRolesController(service)
                let route = UserHasRolesRoute(router, controller)
                route.register()
            }
        ))
        
        // 11. RoleHasPermission 路由 (角色-权限关联表, 复合主键)
        registry.add(RouteEntry(
            "role_has_permission",
            "/api/v1/uctoo/role_has_permission",
            110,
            true,
            { router: Router =>
                let service = RoleHasPermissionService()
                let controller = RoleHasPermissionController(service)
                let route = RoleHasPermissionRoute(router, controller)
                route.register()
            }
        ))
        
        // 12. DataAccessAuthorization 路由 (行级数据权限表)
        registry.add(RouteEntry(
            "data_access_authorization",
            "/api/v1/uctoo/data_access_authorization",
            120,
            true,
            { router: Router =>
                let service = DataAccessAuthorizationService()
                let controller = DataAccessAuthorizationController(service)
                let route = DataAccessAuthorizationRoute(router, controller)
                route.register()
            }
        ))
    }
}
