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
import magic.app.routes.uctoo.db_info.DbInfoRoute
import magic.app.routes.uctoo.application.ApplicationRoute
import magic.app.routes.uctoo.i18.I18Route
import magic.app.routes.uctoo.lang.LangRoute
import magic.app.routes.uctoo.app_access_token.AppAccessTokenRoute
import magic.app.routes.uctoo.agent_skills.AgentSkillsRoute
import magic.app.routes.uctoo.db_connection.DbConnectionRoute
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
import magic.app.controllers.uctoo.db_info.DbInfoController
import magic.app.controllers.uctoo.application.ApplicationController
import magic.app.controllers.uctoo.i18.I18Controller
import magic.app.controllers.uctoo.lang.LangController
import magic.app.controllers.uctoo.app_access_token.AppAccessTokenController
import magic.app.controllers.uctoo.agent_skills.AgentSkillsController

import magic.app.controllers.uctoo.db_connection.DbConnectionController
import magic.app.routes.uctoo.crontab.CrontabRoute
import magic.app.controllers.uctoo.crontab.CrontabController
import magic.app.routes.uctoo.crontab_log.CrontabLogRoute
import magic.app.controllers.uctoo.crontab_log.CrontabLogController
import magic.app.routes.uctoo.crontab_task_registry.CrontabTaskRegistryRoute
import magic.app.controllers.uctoo.crontab_task_registry.CrontabTaskRegistryController

import magic.app.routes.uctoo.agents.AgentsRoute
import magic.app.controllers.uctoo.agents.AgentsController
import magic.app.routes.uctoo.agent_contexts.AgentContextsRoute
import magic.app.controllers.uctoo.agent_contexts.AgentContextsController
import magic.app.routes.uctoo.agent_messages.AgentMessagesRoute
import magic.app.controllers.uctoo.agent_messages.AgentMessagesController
import magic.app.routes.uctoo.agent_tasks.AgentTasksRoute
import magic.app.controllers.uctoo.agent_tasks.AgentTasksController
import magic.app.routes.uctoo.sync_log.SyncLogRoute
import magic.app.controllers.uctoo.sync_log.SyncLogController
import magic.app.routes.uctoo.agent_memories.AgentMemoriesRoute
import magic.app.controllers.uctoo.agent_memories.AgentMemoriesController
import magic.app.routes.uctoo.llm_usage_logs.LlmUsageLogsRoute
import magic.app.controllers.uctoo.llm_usage_logs.LlmUsageLogsController
import magic.app.routes.uctoo.model_pricing.ModelPricingRoute
import magic.app.controllers.uctoo.model_pricing.ModelPricingController
import magic.app.routes.uctoo.agent_groups.AgentGroupsRoute
import magic.app.controllers.uctoo.agent_groups.AgentGroupsController
import magic.app.routes.uctoo.agent_executors.AgentExecutorsRoute
import magic.app.controllers.uctoo.agent_executors.AgentExecutorsController
import magic.app.routes.uctoo.agent_approvals.AgentApprovalsRoute
import magic.app.controllers.uctoo.agent_approvals.AgentApprovalsController
import magic.app.routes.uctoo.retrievers.RetrieversRoute
import magic.app.controllers.uctoo.retrievers.RetrieversController
import magic.app.routes.uctoo.usage_quotas.UsageQuotasRoute
import magic.app.controllers.uctoo.usage_quotas.UsageQuotasController
import magic.app.routes.uctoo.event_handlers.EventHandlersRoute
import magic.app.controllers.uctoo.dashboard.AgentDashboardController
import magic.app.controllers.uctoo.llm_usage.{BillingReportController, LlmUsageStatsController}
import magic.app.controllers.uctoo.event_handlers.EventHandlersManagementController
import magic.app.controllers.uctoo.executor.ExecutorSwitchController
import magic.app.controllers.uctoo.skill.SkillValidationController
import magic.app.controllers.uctoo.event_handlers.EventHandlersController
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
    OperateLogService,
    DbInfoService,
    ApplicationService,
    I18Service,
    LangService,
    AppAccessTokenService,
    AgentSkillsService,
    DbConnectionService,
    CrontabService,
    CrontabLogService,

    CrontabTaskRegistryService,

    AgentsService,
    AgentContextsService,
    AgentMessagesService,
    AgentTasksService,
    SyncLogService,
    AgentMemoriesService,
    LlmUsageLogsService,
    ModelPricingService,
    AgentGroupsService,
    AgentExecutorsService,
    AgentApprovalsService,
    RetrieversService,
    UsageQuotasService,
    EventHandlersService,}
import magic.app.services.crontab.SchedulerService


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
        
        // DbInfo 路由
        registry.add(RouteEntry(
            "db_info",
            "/api/v1/uctoo/db_info",
            10,
            true,
            { router: Router =>
                let service = DbInfoService()
                let controller = DbInfoController(service)
                let route = DbInfoRoute(router, controller)
                route.register()
            }
        ))
        
        // Entity 路由
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

        // CrontabTaskRegistry 路由
        registry.add(RouteEntry(
            "crontab_task_registry",
            "/api/v1/uctoo/crontab_task_registry",
            10,
            true,
            { router: Router =>
                let service = CrontabTaskRegistryService()
                let controller = CrontabTaskRegistryController(service)
                let route = CrontabTaskRegistryRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // CrontabLog 路由
        registry.add(RouteEntry(
            "crontab_log",
            "/api/v1/uctoo/crontab_log",
            10,
            true,
            { router: Router =>
                let service = CrontabLogService()
                let controller = CrontabLogController(service)
                let route = CrontabLogRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // Crontab 路由
        registry.add(RouteEntry(
            "crontab",
            "/api/v1/uctoo/crontab",
            10,
            true,
            { router: Router =>
                let service = CrontabService()
                let schedulerService = SchedulerService()
                let logService = CrontabLogService()
                let controller = CrontabController(service, schedulerService, logService)
                let route = CrontabRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // DbConnection 路由
        registry.add(RouteEntry(
            "db_connection",
            "/api/v1/uctoo/db_connection",
            10,
            true,
            { router: Router =>
                let service = DbConnectionService()
                let controller = DbConnectionController(service)
                let route = DbConnectionRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        
        // 1. UctooUser 路由
        registry.add(RouteEntry(
            "uctoo_user",
            "/api/v1/uctoo/uctoo_user",
            20,
            true,
            { router: Router =>
                let service = UctooUserService()
                let userHasRolesService = UserHasRolesService()
                let controller = UctooUserController(service, userHasRolesService)
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
                route.registerCustomRoutes()
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
        
        // 13. Application 路由 (应用管理)
        registry.add(RouteEntry(
            "application",
            "/api/v1/uctoo/application",
            160,
            true,
            { router: Router =>
                let service = ApplicationService()
                let controller = ApplicationController(service)
                let route = ApplicationRoute(router, controller)
                route.register()
            }
        ))
        
        // 14. I18 路由 (国际化内容)
        registry.add(RouteEntry(
            "i18",
            "/api/v1/uctoo/i18",
            170,
            true,
            { router: Router =>
                let service = I18Service()
                let controller = I18Controller(service)
                let route = I18Route(router, controller)
                route.register()
            }
        ))
        
        // 15. Lang 路由 (语言管理)
        registry.add(RouteEntry(
            "lang",
            "/api/v1/uctoo/lang",
            180,
            true,
            { router: Router =>
                let service = LangService()
                let controller = LangController(service)
                let route = LangRoute(router, controller)
                route.register()
            }
        ))
        
        // 16. AppAccessToken 路由 (应用access_token)
        registry.add(RouteEntry(
            "app_access_token",
            "/api/v1/uctoo/app_access_token",
            190,
            true,
            { router: Router =>
                let service = AppAccessTokenService()
                let controller = AppAccessTokenController(service)
                let route = AppAccessTokenRoute(router, controller)
                route.register()
            }
        ))
        
        // 17. AgentSkills 路由 (Agent技能管理)
        registry.add(RouteEntry(
            "agent_skills",
            "/api/v1/uctoo/agent_skills",
            200,
            true,
            { router: Router =>
                let service = AgentSkillsService()
                let controller = AgentSkillsController(service)
                let route = AgentSkillsRoute(router, controller)
                route.register()
            }
        ))
        
        // ==================== CRUD 路由配置 ====================
        // EventHandlers 路由
        registry.add(RouteEntry(
            "event_handlers",
            "/api/v1/uctoo/event_handlers",
            10,
            true,
            { router: Router =>
                let service = EventHandlersService()
                let controller = EventHandlersController(service)
                let route = EventHandlersRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // UsageQuotas 路由
        registry.add(RouteEntry(
            "usage_quotas",
            "/api/v1/uctoo/usage_quotas",
            10,
            true,
            { router: Router =>
                let service = UsageQuotasService()
                let controller = UsageQuotasController(service)
                let route = UsageQuotasRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // Retrievers 路由
        registry.add(RouteEntry(
            "retrievers",
            "/api/v1/uctoo/retrievers",
            10,
            true,
            { router: Router =>
                let service = RetrieversService()
                let controller = RetrieversController(service)
                let route = RetrieversRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // AgentApprovals 路由
        registry.add(RouteEntry(
            "agent_approvals",
            "/api/v1/uctoo/agent_approvals",
            10,
            true,
            { router: Router =>
                let service = AgentApprovalsService()
                let controller = AgentApprovalsController(service)
                let route = AgentApprovalsRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // AgentExecutors 路由
        registry.add(RouteEntry(
            "agent_executors",
            "/api/v1/uctoo/agent_executors",
            10,
            true,
            { router: Router =>
                let service = AgentExecutorsService()
                let controller = AgentExecutorsController(service)
                let route = AgentExecutorsRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // AgentGroups 路由
        registry.add(RouteEntry(
            "agent_groups",
            "/api/v1/uctoo/agent_groups",
            10,
            true,
            { router: Router =>
                let service = AgentGroupsService()
                let controller = AgentGroupsController(service)
                let route = AgentGroupsRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // ModelPricing 路由
        registry.add(RouteEntry(
            "model_pricing",
            "/api/v1/uctoo/model_pricing",
            10,
            true,
            { router: Router =>
                let service = ModelPricingService()
                let controller = ModelPricingController(service)
                let route = ModelPricingRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // LlmUsageLogs 路由
        registry.add(RouteEntry(
            "llm_usage_logs",
            "/api/v1/uctoo/llm_usage_logs",
            10,
            true,
            { router: Router =>
                let service = LlmUsageLogsService()
                let controller = LlmUsageLogsController(service)
                let route = LlmUsageLogsRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // AgentMemories 路由
        registry.add(RouteEntry(
            "agent_memories",
            "/api/v1/uctoo/agent_memories",
            10,
            true,
            { router: Router =>
                let service = AgentMemoriesService()
                let controller = AgentMemoriesController(service)
                let route = AgentMemoriesRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        // SyncLog 路由
        registry.add(RouteEntry(
            "sync_log",
            "/api/v1/uctoo/sync_log",
            10,
            true,
            { router: Router =>
                let service = SyncLogService()
                let controller = SyncLogController(service)
                let route = SyncLogRoute(router, controller)
                route.register()
                route.registerCustomRoutes()
            }
        ))

        
        // Agents 路由 (Agent管理)
        registry.add(RouteEntry(
            "agents",
            "/api/v1/uctoo/agents",
            210,
            true,
            { router: Router =>
                let service = AgentsService()
                let controller = AgentsController(service)
                let route = AgentsRoute(router, controller)
                route.register()
            }
        ))
        
        // AgentContexts 路由 (Agent上下文)
        registry.add(RouteEntry(
            "agent_contexts",
            "/api/v1/uctoo/agent_contexts",
            220,
            true,
            { router: Router =>
                let service = AgentContextsService()
                let controller = AgentContextsController(service)
                let route = AgentContextsRoute(router, controller)
                route.register()
            }
        ))
        
        // AgentMessages 路由 (Agent消息)
        registry.add(RouteEntry(
            "agent_messages",
            "/api/v1/uctoo/agent_messages",
            230,
            true,
            { router: Router =>
                let service = AgentMessagesService()
                let controller = AgentMessagesController(service)
                let route = AgentMessagesRoute(router, controller)
                route.register()
            }
        ))
        
        // AgentTasks 路由 (Agent任务)
        registry.add(RouteEntry(
            "agent_tasks",
            "/api/v1/uctoo/agent_tasks",
            240,
            true,
            { router: Router =>
                let service = AgentTasksService()
                let controller = AgentTasksController(service)
                let route = AgentTasksRoute(router, controller)
                route.register()
            }
        ))

        // AgentDashboard 路由 (Agent监控仪表板)
        registry.add(RouteEntry(
            "agent_dashboard",
            "/api/v1/uctoo/agent-dashboard",
            250,
            true,
            { router: Router =>
                let controller = AgentDashboardController()
                router.get("/api/v1/uctoo/agent-dashboard/overview", controller.overview)
                router.get("/api/v1/uctoo/agent-dashboard/agent-type-distribution", controller.agentTypeDistribution)
                router.get("/api/v1/uctoo/agent-dashboard/task-status-distribution", controller.taskStatusDistribution)
                router.get("/api/v1/uctoo/agent-dashboard/memory-stats", controller.memoryStats)
                router.get("/api/v1/uctoo/agent-dashboard/token-consumption", controller.tokenConsumption)
                router.get("/api/v1/uctoo/agent-dashboard/collaboration-topology", controller.collaborationTopology)
            }
        ))

        // BillingReport 路由 (计费报表)
        registry.add(RouteEntry(
            "billing_report",
            "/api/v1/uctoo/billing-report",
            260,
            true,
            { router: Router =>
                let controller = BillingReportController()
                router.get("/api/v1/uctoo/billing-report/daily", controller.dailyReport)
                router.get("/api/v1/uctoo/billing-report/monthly", controller.monthlyReport)
                router.get("/api/v1/uctoo/billing-report/export-csv", controller.exportCsv)
            }
        ))

        // LlmUsageStats 路由 (Token 统计)
        registry.add(RouteEntry(
            "llm_usage_stats",
            "/api/v1/uctoo/llm-usage-stats",
            261,
            true,
            { router: Router =>
                let controller = LlmUsageStatsController()
                router.get("/api/v1/uctoo/llm-usage-stats/summary", controller.summary)
                router.get("/api/v1/uctoo/llm-usage-stats/by-agent", controller.byAgent)
                router.get("/api/v1/uctoo/llm-usage-stats/by-model", controller.byModel)
            }
        ))

        // EventHandlersManagement 路由 (事件处理器管理)
        registry.add(RouteEntry(
            "event_handlers_management",
            "/api/v1/uctoo/event-handlers-management",
            270,
            true,
            { router: Router =>
                let controller = EventHandlersManagementController()
                router.get("/api/v1/uctoo/event-handlers/active", controller.listActive)
                router.get("/api/v1/uctoo/event-handlers/history", controller.history)
                router.post("/api/v1/uctoo/event-handlers/register", controller.registerHandler)
                router.post("/api/v1/uctoo/event-handlers/unregister", controller.unregisterHandler)
                router.post("/api/v1/uctoo/event-handlers/toggle", controller.toggleHandler)
            }
        ))

        // ExecutorSwitch 路由 (执行策略运行时切换)
        registry.add(RouteEntry(
            "executor_switch",
            "/api/v1/uctoo/executor-switch",
            280,
            true,
            { router: Router =>
                let controller = ExecutorSwitchController()
                router.post("/api/v1/uctoo/executor/switch", controller.switchExecutor)
                router.get("/api/v1/uctoo/executor/list", controller.listExecutors)
                router.get("/api/v1/uctoo/executor/agent-executor", controller.getAgentExecutor)
            }
        ))

        // SkillValidation 路由 (技能验证)
        registry.add(RouteEntry(
            "skill_validation",
            "/api/v1/uctoo/skill-validation",
            290,
            true,
            { router: Router =>
                let controller = SkillValidationController()
                router.post("/api/v1/uctoo/skill/validate", controller.validate)
                router.post("/api/v1/uctoo/skill/validate-security", controller.validateSecurity)
                router.post("/api/v1/uctoo/skill/execute-secure", controller.executeSecure)
                router.get("/api/v1/uctoo/skill/validate-all", controller.validateAll)
            }
        ))
    }
}
