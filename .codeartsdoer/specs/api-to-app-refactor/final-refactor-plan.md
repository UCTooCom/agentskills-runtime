# API 模块重构至 APP 模块最终方案

> **版本**: v2.0  
> **日期**: 2026-03-26  
> **作者**: CodeArts Agent  
> **状态**: 待执行

## 一、重构背景

### 1.1 问题现状

agentskills-runtime 项目当前存在以下问题：

1. **循环依赖**: 从 `src/api` 合并到 `src/app` 的代码引入了循环依赖
2. **编译错误**: 多个文件存在语法错误、导入错误、类型不匹配等问题
3. **架构混乱**: 原本独立的 API 模块被强行合并到 CRUD 模块中

### 1.2 循环依赖链

```
magic.app.services.uctoo.agent_skills (SkillRuntimeService)
    ↓ 依赖
magic.skill.application (SkillManagementService)
    ↓ 依赖
magic.tool (ToolDispatcher)
    ↓ 依赖
magic.app.services.uctoo (UserHasRolesService, RoleHasPermissionService)
    ↓ 循环依赖
magic.app.services.uctoo.agent_skills (SkillRuntimeService)
```

### 1.3 重构目标

1. **消除循环依赖**: 删除引入循环依赖的代码
2. **保留工具代码**: builtin-tools-v2 的成果完整保留
3. **保留 CRUD 模块**: 标准 CRUD 模块不受影响
4. **独立重构 API**: 技能管理 API 独立实现，不与 CRUD 混合
5. **唯一主入口**: 保持 `app/main.cj` 为唯一主入口

### 1.4 依赖倒置分析

#### 1.4.1 是否需要依赖倒置？

**结论：不需要**

**分析过程**:

1. **检查循环依赖风险**:
   - `magic.tool` 依赖 `magic.app.services.uctoo`（权限服务）
   - `magic.app.services.uctoo` 不依赖 `magic.tool`
   - **无循环依赖风险**

2. **依赖关系验证**:
   ```
   magic.tool (ToolDispatcher)
       ↓ 直接依赖
   magic.app.services.uctoo (UserHasRolesService, RoleHasPermissionService)
   ```
   
   检查反向依赖：
   - `magic.app.services.uctoo` 不导入 `magic.tool`
   - **无反向依赖，无循环依赖**

3. **设计权衡**:
   - **使用依赖倒置**: 增加抽象层，理解成本高，维护成本高
   - **使用直接依赖**: 直观易懂，维护成本低，无循环依赖风险
   - **选择**: 直接依赖

#### 1.4.2 推荐方案

**使用直接依赖，不使用依赖倒置**

理由：
1. **无循环依赖风险**: 已验证无循环依赖
2. **更易理解**: 直接依赖比接口抽象更直观
3. **更易维护**: 减少抽象层，降低维护成本
4. **符合常规**: 大多数项目都是直接依赖，不需要依赖倒置

## 二、重构原则

### 2.1 核心原则

1. **职责分离**: 数据库 CRUD 与运行时管理完全分离
2. **直接依赖**: 使用直接依赖，不使用依赖倒置（无循环依赖风险）
3. **保持独立**: API 模块功能保持独立，不与 CRUD 模块混合
4. **不动工具**: 所有工具相关代码保持不变

### 2.2 不变的内容

**工具相关代码**（builtin-tools-v2 成果，完全相同，不需要动）:
- `src/tool/tool_dispatcher.cj` - 保持不变
- `src/tool/tool_permission.cj` - 保持不变
- `src/tool/tool_audit_log.cj` - 保持不变
- `src/app/services/tool/ToolAuditService.cj` - 保持不变
- `src/app/routes/tool/ToolRoutes.cj` - 保持不变

**CRUD 模块**（标准 CRUD，不受影响）:
- `src/app/controllers/uctoo/agent_skills/AgentSkillsController.cj` - 保持不变
- `src/app/services/uctoo/agent_skills/AgentSkillsService.cj` - 保持不变
- `src/app/models/uctoo/AgentSkills.cj` - 保持不变
- `src/app/dao/uctoo/AgentSkillsDao.cj` - 保持不变

**权限相关**（直接依赖，不使用依赖倒置）:
- `src/app/services/uctoo/UserHasRolesService.cj` - 保持不变
- `src/app/services/uctoo/RoleHasPermissionService.cj` - 保持不变

**主入口**:
- `src/app/main.cj` - 保持不变（已经是唯一主入口）

## 三、重构方案

### 3.1 需要删除的文件

**从 api 合并到 app 且引入循环依赖的代码**:

```
src/app/controllers/uctoo/agent_skills/SkillRuntimeController.cj  # 删除
src/skill/application/skill_runtime_service.cj                    # 删除
```

**说明**:
- `SkillRuntimeController.cj` 是从 api 合并的运行时控制器，引入了循环依赖
- `skill_runtime_service.cj` 是我们创建的运行时服务，也引入了循环依赖

### 3.2 需要新增的文件

**独立的技能管理 API**（不与 CRUD 混合）:

```
src/app/routes/skill/SkillRoutes.cj           # 技能管理 API 路由
src/app/controllers/skill/SkillController.cj  # 技能管理控制器
```

**关键设计**:
- 技能管理 API 不放在 `uctoo/agent_skills/` 下
- 技能管理 API 独立实现，不依赖 CRUD 模块
- 技能管理 API 直接使用 `SkillManager`，不通过 `AgentSkillsService`

### 3.3 需要修改的文件

**app/main.cj**:
- 在 `setupRoutes()` 中注册 `SkillRoutes`

## 四、详细实现

### 4.1 步骤 1: 删除循环依赖代码

**删除文件**:
```bash
rm src/app/controllers/uctoo/agent_skills/SkillRuntimeController.cj
rm src/skill/application/skill_runtime_service.cj
```

**说明**: 这些文件是从 api 合并到 app 且引入循环依赖的代码。

### 4.2 步骤 2: 创建独立的技能管理 API

#### 4.2.1 创建 SkillRoutes.cj

**文件路径**: `src/app/routes/skill/SkillRoutes.cj`

**设计要点**:
1. 直接依赖 `SkillManager`，不依赖 `AgentSkillsService`
2. 独立实现，不与 CRUD 混合
3. 路由前缀为 `/api/v1/uctoo/skills`，符合 uctoo API 规范

**核心结构**:
```cangjie
package magic.app.routes.skill

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.router.Router
import magic.core.skill.SkillManager
import magic.skill.application.SkillManagementService
import magic.skill.application.ProgressiveSkillLoader
import magic.skill.search.PublicSkillSearchService
import magic.log.LogUtils
import std.collection.HashMap
import stdx.encoding.json.*

public class SkillRoutes {
    private let router: Router
    private let skillManager: SkillManager
    private let skillManagementService: SkillManagementService
    private let progressiveSkillLoader: ProgressiveSkillLoader
    private let searchService: PublicSkillSearchService
    
    public init(
        router: Router,
        skillManager: SkillManager,
        skillManagementService: SkillManagementService,
        progressiveSkillLoader: ProgressiveSkillLoader
    ) {
        this.router = router
        this.skillManager = skillManager
        this.skillManagementService = skillManagementService
        this.progressiveSkillLoader = progressiveSkillLoader
        this.searchService = PublicSkillSearchService()
    }
    
    public func register(): Unit {
        // GET /api/v1/uctoo/skills - 获取技能列表
        router.get("/api/v1/uctoo/skills", { req, res =>
            handleGetSkills(req, res)
        })
        
        // GET /api/v1/uctoo/skills/:id - 获取技能详情
        router.get("/api/v1/uctoo/skills/:id", { req, res =>
            handleGetSkillById(req, res)
        })
        
        // POST /api/v1/uctoo/skills/add - 安装技能
        router.post("/api/v1/uctoo/skills/add", { req, res =>
            handleAddSkill(req, res)
        })
        
        // POST /api/v1/uctoo/skills/edit - 更新技能
        router.post("/api/v1/uctoo/skills/edit", { req, res =>
            handleEditSkill(req, res)
        })
        
        // POST /api/v1/uctoo/skills/del - 卸载技能
        router.post("/api/v1/uctoo/skills/del", { req, res =>
            handleDeleteSkill(req, res)
        })
        
        // POST /api/v1/uctoo/skills/execute - 执行技能
        router.post("/api/v1/uctoo/skills/execute", { req, res =>
            handleExecuteSkill(req, res)
        })
        
        // POST /api/v1/uctoo/skills/search - 搜索技能
        router.post("/api/v1/uctoo/skills/search", { req, res =>
            handleSearchSkills(req, res)
        })
        
        // GET /hello - 健康检查（保持原 api 模块的接口）
        router.get("/hello", { req, res =>
            handleHello(req, res)
        })
    }
    
    // 实现各个处理方法（参考原 api_router.cj 的实现）
    private func handleGetSkills(req: HttpRequest, res: HttpResponse): Unit { ... }
    private func handleGetSkillById(req: HttpRequest, res: HttpResponse): Unit { ... }
    private func handleAddSkill(req: HttpRequest, res: HttpResponse): Unit { ... }
    private func handleEditSkill(req: HttpRequest, res: HttpResponse): Unit { ... }
    private func handleDeleteSkill(req: HttpRequest, res: HttpResponse): Unit { ... }
    private func handleExecuteSkill(req: HttpRequest, res: HttpResponse): Unit { ... }
    private func handleSearchSkills(req: HttpRequest, res: HttpResponse): Unit { ... }
    private func handleHello(req: HttpRequest, res: HttpResponse): Unit { ... }
}
```

#### 4.2.2 实现细节

**从原 api_router.cj 迁移功能**:
- 将 `api_router.cj` 中的所有处理方法迁移到 `SkillRoutes.cj`
- 保持原有的业务逻辑不变
- 适配新的 HTTP 框架（从 `stdx.net.http` 到 `magic.app.core.http`）

**关键差异**:
- 原 `api_router.cj` 使用 `stdx.net.http.HttpContext`
- 新 `SkillRoutes.cj` 使用 `magic.app.core.http.HttpRequest` 和 `HttpResponse`

### 4.3 步骤 3: 更新 app/main.cj

**修改 `setupRoutes()` 方法**:

```cangjie
private func setupRoutes(): Unit {
    // 使用自动路由注册器注册所有路由
    let routeRegistry = AutoRouteRegistry(router)
    routeRegistry.registerAllRoutes()
    
    // 注册技能管理路由（独立，不与 CRUD 混合）
    let skillManagementService = SkillManagementService()
    let skillRoutes = SkillRoutes(
        router,
        _skillManager,
        skillManagementService,
        _progressiveSkillLoader
    )
    skillRoutes.register()
    
    // 注册WebSocket路由
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
```

### 4.4 步骤 4: 验证构建

**执行构建**:
```bash
cd D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime
cjpm build
```

**检查项**:
1. 无循环依赖错误
2. 无编译错误
3. 所有功能正常

## 五、预期结果

### 5.1 目录结构

```
src/
├── app/
│   ├── main.cj                          # 唯一主入口（不变）
│   ├── routes/
│   │   ├── skill/
│   │   │   └── SkillRoutes.cj           # 技能管理 API（新增）
│   │   ├── tool/
│   │   │   └── ToolRoutes.cj            # 工具 API（不变）
│   │   └── uctoo/
│   │       └── agent_skills/
│   │           └── AgentSkillsRoutes.cj # CRUD 路由（不变）
│   ├── services/
│   │   ├── tool/
│   │   │   └── ToolAuditService.cj      # 工具服务（不变）
│   │   └── uctoo/
│   │       ├── AgentSkillsService.cj    # CRUD 服务（不变）
│   │       └── UctooPermissionProvider.cj # 权限提供者（不变）
│   └── ...
├── skill/
│   └── application/
│       ├── SkillManagementService.cj    # 技能管理服务（不变）
│       └── SkillPackageManager.cj       # 技能包管理器（不变）
└── tool/
    ├── ToolDispatcher.cj                # 工具调度器（不变）
    ├── ToolPermission.cj                # 工具权限（不变）
    └── ToolAuditLog.cj                  # 工具审计日志（不变）
```

### 5.2 依赖关系

```
src/app/routes/skill (SkillRoutes)
    ↓ 依赖
src/skill/application (SkillManager)
    ↓ 依赖
src/tool (ToolDispatcher)
    ↓ 直接依赖
src/app/services/uctoo (UserHasRolesService, RoleHasPermissionService)
```

**关键点**:
- 技能管理 API 独立，不与 CRUD 混合
- 使用直接依赖，不使用依赖倒置（无循环依赖风险）
- 工具相关代码完整保留

### 5.3 API 路由

| 方法 | 路径 | 描述 | 实现位置 |
|------|------|------|---------|
| GET | /hello | 健康检查 | SkillRoutes.cj |
| GET | /api/v1/uctoo/skills | 获取技能列表 | SkillRoutes.cj |
| GET | /api/v1/uctoo/skills/:id | 获取技能详情 | SkillRoutes.cj |
| POST | /api/v1/uctoo/skills/add | 安装技能 | SkillRoutes.cj |
| POST | /api/v1/uctoo/skills/edit | 更新技能 | SkillRoutes.cj |
| POST | /api/v1/uctoo/skills/del | 卸载技能 | SkillRoutes.cj |
| POST | /api/v1/uctoo/skills/execute | 执行技能 | SkillRoutes.cj |
| POST | /api/v1/uctoo/skills/search | 搜索技能 | SkillRoutes.cj |
| GET | /api/v1/health | uctoo 健康检查 | app/main.cj |
| GET | /api/v1/info | uctoo 系统信息 | app/main.cj |
| WS | /api/v1/uctoo/ws/chat | WebSocket 聊天 | WsChatController.cj |

## 六、风险评估

### 6.1 潜在风险

1. **功能丢失**: 删除代码可能导致功能丢失
   - **缓解措施**: 将功能迁移到新的 `SkillRoutes.cj`，功能不丢失

2. **接口不兼容**: 修改后的接口可能与现有客户端不兼容
   - **缓解措施**: 保持 API 路由不变，客户端无需修改

3. **编译错误**: 新代码可能引入编译错误
   - **缓解措施**: 逐步验证，及时修复

### 6.2 回滚计划

如果重构失败，可以：
1. 恢复到 `agentskills-runtime-backup` 目录的备份
2. 重新分析问题，制定新的重构方案

## 七、执行计划

### 7.1 执行顺序

1. **删除循环依赖代码**（步骤 1）
2. **创建独立的技能管理 API**（步骤 2）
3. **更新 app/main.cj**（步骤 3）
4. **验证构建**（步骤 4）

### 7.2 验证清单

- [ ] 删除 `SkillRuntimeController.cj`
- [ ] 删除 `skill_runtime_service.cj`
- [ ] 创建 `SkillRoutes.cj`
- [ ] 更新 `app/main.cj`
- [ ] 运行 `cjpm build` 无错误
- [ ] 无循环依赖
- [ ] 所有 API 端点正常工作

## 八、总结

### 8.1 核心思想

这个重构方案的核心思想是：

1. **删除循环依赖代码**: 删除从 api 合并到 app 且引入循环依赖的代码
2. **保留工具代码**: builtin-tools-v2 的成果完整保留
3. **保留 CRUD 模块**: 标准 CRUD 模块不受影响
4. **独立重构 API**: 技能管理 API 独立实现，不与 CRUD 混合
5. **依赖倒置**: 使用接口解耦，避免循环依赖

### 8.2 预期收益

通过这个方案，我们可以：

- ✅ 消除循环依赖
- ✅ 保留所有工具功能
- ✅ 保持 CRUD 模块独立
- ✅ 实现 API 功能的独立重构
- ✅ 保持唯一主入口 `app/main.cj`
- ✅ 提高代码可维护性
- ✅ 符合 uctoo V4.0 架构规范

### 8.3 关键差异

与之前的重构方案相比，本方案的关键差异：

1. **不动工具代码**: 所有工具相关代码保持不变
2. **不动 CRUD 模块**: 标准 CRUD 模块不受影响
3. **独立重构**: 技能管理 API 独立实现，不与 CRUD 混合
4. **最小改动**: 只删除引入循环依赖的代码，其他保持不变
5. **直接依赖**: 使用直接依赖，不使用依赖倒置（无循环依赖风险，更易理解和维护）

---

**文档版本**: v2.0  
**最后更新**: 2026-03-26  
**状态**: 待执行
