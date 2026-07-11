# API到APP子系统真实重构方案

## 重构原则
1. **不偷懒** - 每个功能都必须真实实现,不能有桩程序
2. **遵循架构** - 严格遵循uctoo v4三层架构: Controller → Service → Repository
3. **功能完整** - 原api子系统的所有功能都必须迁移
4. **保留设计** - 保留已有的Controller/Service/Route框架

## 重构任务清单

### 任务1: 技能管理API (7个端点)

**原实现位置**: `D:\UCT\products\gitcode\agentskills-runtime\src\api\api_router.cj`

**目标位置**: 
- Controller: `src/app/controllers/uctoo/agent_skills/AgentSkillsController.cj`
- Service: `src/app/services/uctoo/AgentSkillsService.cj`
- Route: `src/app/routes/uctoo/agent_skills/AgentSkillsRoute.cj`

**需要实现的端点**:
1. `GET /skills` - 获取技能列表 (原函数: handleGetSkills, 行536)
2. `GET /skills/:id` - 获取技能详情 (原函数: handleGetSkillById, 行638)
3. `POST /skills/add` - 安装技能 (原函数: handleAddSkill, 行738)
4. `POST /skills/edit` - 编辑技能 (原函数: handleEditSkill, 行983)
5. `POST /skills/del` - 删除技能 (原函数: handleDeleteSkill, 行1067)
6. `POST /skills/execute` - 执行技能 (原函数: handleExecuteSkill, 行1134)
7. `POST /skills/search` - 搜索技能 (原函数: handleSearchSkills, 行1227)

**重构步骤**:
1. 读取原api_router.cj中每个handle函数的完整实现
2. 将业务逻辑迁移到AgentSkillsService
3. 将HTTP请求处理迁移到AgentSkillsController
4. 在AgentSkillsRoute中注册路由
5. 在main.cj中调用AgentSkillsRoute.register()

### 任务2: WebSocket支持

**原实现位置**: `D:\UCT\products\gitcode\agentskills-runtime\src\api\websocket_handler.cj`

**目标位置**: 
- Controller: `src/app/controllers/uctoo/ws/WsChatController.cj`
- Route: `src/app/routes/uctoo/ws/WsRoute.cj`

**需要实现的端点**:
- `WS /ws/chat` - WebSocket聊天接口

**重构步骤**:
1. 读取原websocket_handler.cj的完整实现
2. 将WebSocket处理逻辑迁移到WsChatController
3. 在WsRoute中注册WebSocket路由
4. 在main.cj中集成WebSocket支持

### 任务3: MCP流式接口

**原实现位置**: `D:\UCT\products\gitcode\agentskills-runtime\src\api\api_router.cj:行1300+`

**目标位置**: 
- Controller: `src/app/controllers/uctoo/mcp/McpController.cj`
- Route: `src/app/routes/uctoo/mcp/McpRoute.cj`

**需要实现的端点**:
- `GET /mcp/stream` - MCP流式接口

**重构步骤**:
1. 读取原handleMCPStream函数的实现
2. 将MCP处理逻辑迁移到McpController
3. 在McpRoute中注册MCP路由
4. 在main.cj中集成MCP支持

### 任务4: 实体管理API (5个端点)

**原实现位置**: `D:\UCT\products\gitcode\agentskills-runtime\src\api\api_router.cj:行320-530`

**目标位置**: 
- Controller: `src/app/controllers/uctoo/entity/EntityController.cj` (已存在)
- Service: `src/app/services/uctoo/EntityService.cj` (已存在)
- Route: `src/app/routes/uctoo/entity/EntityRoute.cj` (已存在)

**需要实现的端点**:
1. `POST /api/v1/uctoo/entity/add` - 添加实体
2. `POST /api/v1/uctoo/entity/edit` - 编辑实体
3. `POST /api/v1/uctoo/entity/del` - 删除实体
4. `GET /api/v1/uctoo/entity` - 获取实体列表(查询参数)
5. `GET /api/v1/uctoo/entity/:id` - 获取单个实体

**重构步骤**:
1. 读取原handleUctooEntity*函数的实现
2. 将业务逻辑迁移到EntityService
3. 将HTTP请求处理迁移到EntityController
4. 在EntityRoute中注册路由
5. 在main.cj中调用EntityRoute.register()

### 任务5: 健康检查和服务信息

**原实现位置**: `D:\UCT\products\gitcode\agentskills-runtime\src\api\api_router.cj`

**需要实现的端点**:
1. `GET /hello` - 健康检查
2. `GET /api/v1/health` - uctoo健康检查
3. `GET /api/v1/info` - 服务信息

**重构步骤**:
1. 在main.cj中直接注册这些简单路由

### 任务6: 中间件链真实实现

**目标位置**: `src/app/core/middleware/Middleware.cj`

**需要实现**:
1. `MiddlewareChain.use()` - 添加中间件
2. `MiddlewareChain.execute()` - 执行中间件链
3. `MiddlewareChain.runNext()` - 执行下一个中间件

**重构步骤**:
1. 实现真实的中间件链执行逻辑
2. 确保中间件按顺序执行
3. 支持next()调用

### 任务7: 路由注册

**目标位置**: `src/app/main.cj`

**需要实现**:
1. 初始化所有Service
2. 初始化所有Controller
3. 注册所有Route
4. 启动HTTP服务器

## 执行计划

### 阶段1: 准备工作 (已完成)
- ✅ 修复HTTPServer使用stdx.net.http
- ✅ 删除复制的文件

### 阶段2: 核心功能重构 (进行中)
- [ ] 任务1: 技能管理API (7个端点)
- [ ] 任务2: WebSocket支持
- [ ] 任务3: MCP流式接口
- [ ] 任务4: 实体管理API (5个端点)
- [ ] 任务5: 健康检查和服务信息

### 阶段3: 基础设施完善
- [ ] 任务6: 中间件链真实实现
- [ ] 任务7: 路由注册

### 阶段4: 测试验证
- [ ] 编译项目
- [ ] 启动服务器
- [ ] 测试所有API端点

## 预计工作量

| 任务 | 预计时间 | 优先级 |
|------|---------|--------|
| 任务1: 技能管理API | 2-3小时 | P0 |
| 任务2: WebSocket | 1-2小时 | P0 |
| 任务3: MCP接口 | 1小时 | P1 |
| 任务4: 实体管理API | 1-2小时 | P0 |
| 任务5: 健康检查 | 30分钟 | P0 |
| 任务6: 中间件链 | 1小时 | P1 |
| 任务7: 路由注册 | 30分钟 | P0 |

**总计**: 约7-10小时

## 注意事项

1. **不要偷懒** - 每个函数都要真实实现,不能只写TODO
2. **保持架构** - 严格遵循Controller → Service → Repository三层架构
3. **完整迁移** - 原api_router.cj的1411行代码都要迁移
4. **测试验证** - 每个功能都要测试验证

## 下一步行动

请确认这个重构方案,然后我将立即开始执行任务1: 技能管理API的真实重构。
