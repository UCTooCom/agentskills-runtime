# 行级数据权限系统 — 编码任务规划

## 1. P0-基础组件：权限级别枚举 PermissionLevel

- [ ] **T1.1** 新建 `src/app/core/PermissionLevel.cj`，定义权限级别枚举
  - 枚举值：READ=1, WRITE=2, AUTHORIZE=3
  - 实现 `value(): Int32` 获取整数值
  - 实现 `toString(): String` 枚举名称
  - 实现 `static func fromInt32(v: Int32): Option<PermissionLevel>` 整数到枚举双向映射
  - 实现全局函数 `hasPermission(userPermission: PermissionLevel, required: PermissionLevel): Bool` 权限继承判断（AUTHORIZE > WRITE > READ）
  - 需求映射：RLP-001, RLP-002

- [ ] **T1.2** 修改 `src/app/middlewares/permission/PermissionMiddleware.cj`，将现有 PermissionLevel 枚举替换为引用 `core.PermissionLevel`
  - 删除文件中第8-20行的本地 PermissionLevel 枚举定义
  - 在头部引入区新增 `import magic.app.core.PermissionLevel`
  - 确保 PermissionMiddleware 和 PermissionCheck 类的编译不受影响
  - 需求映射：RLP-001

## 2. P0-基础组件：配置管理 PermissionConfig

- [ ] **T2.1** 新建 `src/app/core/PermissionConfig.cj`，实现行级权限配置管理
  - 实现 `static func isRowLevelPermissionEnabled(): Bool` — 读取环境变量 `ROW_LEVEL_PERMISSION_ENABLED`，默认 true
  - 实现 `static func isRowLevelPermissionEnabledForTable(entityType: String): Bool` — 读取 `ROW_LEVEL_PERMISSION_<表名>`，表级优先于全局；未配置时使用全局开关值
  - 实现 `static func getPermissionCacheTTL(): Int64` — 读取 `PERMISSION_CACHE_TTL`，默认 300
  - 实现 `static func getPermissionCacheMaxSize(): Int64` — 读取 `PERMISSION_CACHE_MAX_SIZE`，默认 10000
  - 实现 `static func refreshConfig(): Unit` — 重新从环境变量读取配置（热加载）
  - 非法配置值处理：TTL非正整数时使用默认值300并记录警告日志
  - 需求映射：RLP-019~RLP-023, RLP-021a

- [ ] **T2.2** 在项目 `.env` 文件中添加行级权限配置区块
  - 添加 `# ========== Row Level Permission Config ==========` 区块
  - 添加 `ROW_LEVEL_PERMISSION_ENABLED=true`
  - 添加 `PERMISSION_CACHE_TTL=300`
  - 添加 `PERMISSION_CACHE_MAX_SIZE=10000`
  - 添加 `ROW_LEVEL_PERMISSION_entity=true`
  - 添加 `ROW_LEVEL_PERMISSION_data_access_authorization=true`
  - 添加 `# ========== End Row Level Permission Config ==========`
  - 需求映射：RLP-019, RLP-021a

## 3. P0-基础组件：缓存机制 PermissionCache

- [ ] **T3.1** 新建 `src/app/core/PermissionCache.cj`，实现权限缓存
  - 缓存条目结构：key=`userId:entityType:entityId`, value=`(permission: Int32, createdAt: Int64)`
  - 使用 `Mutex` 保护缓存的 `HashMap` 读写并发安全
  - 实现 `static func get(userId, entityType, entityId): Option<Int32>` — 查询缓存，TTL过期返回None
  - 实现 `static func put(userId, entityType, entityId, permission): Unit` — 写入缓存，超限时淘汰最早条目
  - 实现 `static func getFilterCache(userId, entityType): Option<ArrayList<String>>` — 查询过滤缓存
  - 实现 `static func putFilterCache(userId, entityType, entityIds): Unit` — 写入过滤缓存
  - 实现 `static func invalidate(userId, entityType, entityId): Unit` — 失效指定条目
  - 实现 `static func invalidateByUserAndEntityType(userId, entityType): Unit` — 失效用户+类型所有缓存
  - 实现 `static func invalidateByEntity(entityType, entityId): Unit` — 失效实体所有用户缓存
  - 实现 `static func clearAll(): Unit` — 清空所有缓存
  - 需求映射：RLP-024~RLP-028

## 4. P0-基础组件：权限常量扩展 PermissionConstants

- [ ] **T4.1** 修改 `src/app/constants/PermissionConstants.cj`，新增行级权限相关常量
  - 行级数据权限API (type=3)：`DATA_ACCESS_AUTHORIZATION_API`、`DATA_ACCESS_AUTHORIZATION_AUTHORIZE_API`、`DATA_ACCESS_AUTHORIZATION_REVOKE_API`、`DATA_ACCESS_AUTHORIZATION_LIST_API`
  - 行级数据权限菜单 (type=1)：`DATA_ACCESS_AUTHORIZATION_MENU`
  - 行级数据权限按钮 (type=2)：`DATA_ACCESS_AUTHORIZATION_GRANT_BUTTON`、`DATA_ACCESS_AUTHORIZATION_REVOKE_BUTTON`、`DATA_ACCESS_AUTHORIZATION_VIEW_BUTTON`
  - 需求映射：RLP-014~RLP-018

## 5. P0-DAO层扩展：权限查询方法

- [ ] **T5.1** 修改 `src/app/dao/uctoo/DataAccessAuthorizationDAO.cj`，在AutoCreateCode区域内新增5个标准化权限查询方法（每个表都需要的通用查询支持，由crudgen模板生成）
  - `findAuthByUserIdAndEntityTypeAndEntityId(userId, entityType, entityId): ArrayList<DataAccessAuthorizationPO>` — 精确查询有效授权记录
  - `findAuthByUserIdAndEntityTypeAndPermissionGte(userId, entityType, minPermission): ArrayList<DataAccessAuthorizationPO>` — 权限级别 >= 指定值
  - `findAuthByEntityTypeAndEntityId(entityType, entityId): ArrayList<DataAccessAuthorizationPO>` — 查询实体所有授权记录
  - `findAuthByUserIdAndEntityType(userId, entityType): ArrayList<DataAccessAuthorizationPO>` — 查询用户对某类型的所有授权
  - `findAuthByUserIdAndEntityTypeAndEntityIds(userId, entityType, entityIds): ArrayList<DataAccessAuthorizationPO>` — 批量查询
  - 所有查询均附加 `AND deleted_at IS NULL` 条件
  - 使用 `executor.setSql()` + 参数化查询（`${arg()}`）
  - **代码位置**：AutoCreateCode区域内（//#region AutoCreateCode ~ //#endregion AutoCreateCode）
  - 需求映射：RLP-053

## 6. P0-核心工具：公共权限工具 PermissionUtils

- [ ] **T6.1** 新建 `src/app/utils/PermissionUtils.cj`，实现权限检查核心方法
  - 实现 `static func checkReadPermission(userId, entityId, entityType): (Bool, String)` — 检查READ权限
  - 实现 `static func checkWritePermission(userId, entityId, entityType): (Bool, String)` — 检查WRITE权限
  - 实现 `static func checkAuthorizePermission(userId, entityId, entityType): (Bool, String)` — 检查AUTHORIZE权限
  - 实现 `static func checkUserHasPermission(userId, entityType, entityId, requiredPermission): (Bool, String)` — 通用权限检查
    - 流程：PermissionConfig表级检查 → PermissionCache缓存查询 → 创建者判断(查目标表creator字段) → DAO查询授权记录 → hasPermission级别比较 → 缓存写入 → 审计日志
    - 安全优先：服务不可用时拒绝访问
  - 所有方法接受 entityType 参数，禁止硬编码表名
  - 需求映射：RLP-002~RLP-009, RLP-044, RLP-047, RLP-058, RLP-059

- [ ] **T6.2** 在 `PermissionUtils.cj` 中实现权限过滤方法
  - 实现 `static func appendPermissionFilter(userId, entityType): (String, ArrayList<String>)` — 生成WHERE过滤条件
    - 流程：表级配置检查 → 缓存查询 → DAO查询授权记录+创建者数据 → 合并授权ID集合 → 缓存写入 → 生成参数化WHERE条件
    - 有授权：`(creator = ? OR id IN (?, ?, ...))`
    - 仅创建者：`creator = ?`
    - 无权限：`1=0`（空结果集）
    - 表级未启用：`1=1`（不添加过滤）
  - 实现 `static func getUserAuthorizedEntityIds(userId, entityType, requiredPermission): ArrayList<String>` — 获取有权限的实体ID列表
  - 需求映射：RLP-007, RLP-010~RLP-013, RLP-051

- [ ] **T6.3** 在 `PermissionUtils.cj` 中实现自动授权和批量检查方法
  - 实现 `static func autoGrantCreatorPermission(userId, entityId, entityType): Bool` — 为创建者自动授予AUTHORIZE权限
    - 创建授权记录写入data_access_authorization表
    - 失败仅记录日志不回滚
  - 实现 `static func batchCheckUserHasPermission(userId, entityType, entityIds, requiredPermission): HashMap<String, Bool>` — 批量权限检查
    - 上限100个entityId，超限返回错误
    - 优先从缓存获取，仅未缓存项查询数据库
    - 部分失败时安全优先，失败项返回false
  - 实现 `static func createDataAccessRule(entityType, entityId, userId, permission, authorizerId): (Bool, String)` — 创建授权（含越权验证）
  - 实现 `static func deleteDataAccessRule(authId, operatorId, entityType, entityId): (Bool, String)` — 删除授权
  - 需求映射：RLP-003, RLP-005, RLP-039, RLP-041~RLP-043, RLP-052

## 7. P0-Service层扩展：授权管理业务方法

- [ ] **T7.1** 修改 `src/app/services/uctoo/DataAccessAuthorizationService.cj`，头部引入区新增import
  - 新增：`import magic.app.core.PermissionLevel`、`import magic.app.core.PermissionConfig`、`import magic.app.utils.PermissionUtils`、`import magic.app.core.PermissionCache`
  - 需求映射：RLP-040

- [ ] **T7.2** 修改 `src/app/services/uctoo/DataAccessAuthorizationService.cj`，尾部定制开发区新增授权管理方法（data_access_authorization表专属的业务逻辑）
  - `createAuthorization(entityType, entityId, granteeId, permission, authorizerId): APIResult<DataAccessAuthorizationPO>`
    - 验证授权者拥有AUTHORIZE权限
    - 禁止自授权（granteeId == authorizerId → 400）
    - 禁止越权授权（授权者权限 < 授予权限 → 403）
    - 重复授权处理（相同级别返回已有记录，更高级别存在返回409）
    - 创建成功后失效相关缓存
  - `deleteAuthorization(authId, operatorId): APIResult<Bool>`
    - 验证操作者拥有AUTHORIZE权限
    - 软删除授权记录
    - 失效相关缓存
  - `getEntityAuthorizations(entityType, entityId, operatorId): APIResult<ArrayList<DataAccessAuthorizationPO>>`
    - 验证操作者拥有READ权限
    - 返回该实体的所有有效授权记录
  - 需求映射：RLP-014~RLP-018

## 8. P0-Controller层扩展：授权管理API端点

- [ ] **T8.1** 修改 `src/app/controllers/uctoo/data_access_authorization/DataAccessAuthorizationController.cj`，头部引入区新增import
  - 新增：`import magic.app.core.PermissionLevel`、`import magic.app.utils.PermissionUtils`
  - 需求映射：RLP-040

- [ ] **T8.2** 修改 `src/app/controllers/uctoo/data_access_authorization/DataAccessAuthorizationController.cj`，尾部定制开发区新增API端点（data_access_authorization表专属的授权管理API）
  - `authorize(req: HttpRequest, res: HttpResponse): Unit` — POST 创建授权
    - 请求体：entity_type, entity_id, user_id, permission
    - 响应：200成功/400自授权/403权限不足/409已存在更高级别
  - `revoke(req: HttpRequest, res: HttpResponse): Unit` — POST 删除授权
    - 请求体：id
    - 响应：200成功/403权限不足/404记录不存在
  - `getAuthorizations(req: HttpRequest, res: HttpResponse): Unit` — GET 查询实体授权记录
    - 路径参数：entityType, entityId
    - 响应：200授权记录列表/403无READ权限
  - 需求映射：RLP-014~RLP-017

## 9. P0-Route层扩展：授权管理路由注册

- [ ] **T9.1** 修改 `src/app/routes/uctoo/data_access_authorization/DataAccessAuthorizationRoute.cj`，在 `registerCustomRoutes()` 方法中注册授权管理路由
  - `router.post("/api/v1/uctoo/data_access_authorization/authorize", controller.authorize)`
  - `router.post("/api/v1/uctoo/data_access_authorization/revoke", controller.revoke)`
  - `router.get("/api/v1/uctoo/data_access_authorization/:entityType/:entityId/authorizations", controller.getAuthorizations)`
  - 需求映射：RLP-014~RLP-017

## 10. P0-中间件完善：RowLevelPermissionMiddleware完整实现

- [ ] **T10.1** 修改 `src/app/middlewares/permission/PermissionMiddleware.cj`，完善 RowLevelPermissionMiddleware
  - 在 RowLevelPermissionMiddleware 头部新增 `import magic.app.core.PermissionConfig`、`import magic.app.utils.PermissionUtils`、`import magic.app.core.PermissionLevel`
  - 实现 `checkRowLevelPermission` 完整逻辑：
    - 检查全局开关 `PermissionConfig.isRowLevelPermissionEnabled()`，关闭直接放行（RLP-030）
    - 检查表级开关 `PermissionConfig.isRowLevelPermissionEnabledForTable(tableName)`，未启用直接放行（RLP-033）
    - 调用 `PermissionUtils.checkUserHasPermission()` 执行权限检查
    - 异常时安全优先，拒绝请求并记录错误日志（RLP-034）
  - 增强 `handle` 方法：根据 HTTP 方法自动映射权限级别
    - GET → PermissionLevel.READ（RLP-031）
    - PUT/DELETE → PermissionLevel.WRITE（RLP-032）
    - 权限不足返回 HTTP 403 + 拒绝原因（RLP-046）
  - 需求映射：RLP-029~RLP-034, RLP-044, RLP-046

## 11. P0-业务模块集成：EntityService 行级权限集成

- [ ] **T11.1** 修改 `src/app/services/uctoo/EntityService.cj`，头部引入区新增import
  - 新增：`import magic.app.core.PermissionLevel`、`import magic.app.core.PermissionConfig`、`import magic.app.utils.PermissionUtils`
  - 需求映射：RLP-040

- [ ] **T11.2** 修改 `src/app/services/uctoo/EntityService.cj`，在AutoCreateCode区域内新增行级权限集成方法（每个表都需要的标准化代码，由crudgen模板生成）
  - `createWithPermission(entity: EntityPO, creatorId: String): APIResult<EntityPO>` — 创建含自动授权
    - 调用标准 create 方法
    - 成功后调用 `PermissionUtils.autoGrantCreatorPermission(creatorId, data.id, "entity")`
    - 授权失败仅记录日志，不影响创建结果
  - `getByIdWithPermission(entityId: String, userId: String): APIResult<EntityPO>` — 查询含READ权限检查
    - 调用 `PermissionUtils.checkReadPermission(userId, entityId, "entity")`
  - `getListWithPermission(page, pageSize, sort, filter, userId): (ArrayList<EntityPO>, Int64)` — 列表含权限过滤
    - 调用 `PermissionUtils.appendPermissionFilter(userId, "entity")`
    - 合并权限过滤到业务查询
  - `updateWithPermission(entityId, entity, userId): APIResult<EntityPO>` — 更新含WRITE权限检查
    - 调用 `PermissionUtils.checkWritePermission(userId, entityId, "entity")`
  - `deleteWithPermission(entityId, force, userId): APIResult<Bool>` — 删除含WRITE权限检查
    - 调用 `PermissionUtils.checkWritePermission(userId, entityId, "entity")`
  - **代码位置**：AutoCreateCode区域内（//#region AutoCreateCode ~ //#endregion AutoCreateCode）
  - 需求映射：RLP-035~RLP-040, RLP-049~RLP-052

## 12. P0-业务模块集成：EntityController/EntityRoute 集成

- [ ] **T12.1** 修改 `src/app/controllers/uctoo/entity/EntityController.cj`，头部引入区+AutoCreateCode区域
  - 头部引入区新增：`import magic.app.core.PermissionLevel`、`import magic.app.utils.PermissionUtils`
  - AutoCreateCode区域：修改 getById/create/update/delete/getList 端点，改为调用 Service 层的 `WithPermission` 后缀方法（每个表都需要的标准化代码）
  - **代码位置**：AutoCreateCode区域内（//#region AutoCreateCode ~ //#endregion AutoCreateCode）
  - 需求映射：RLP-054

- [ ] **T12.2** 修改 `src/app/routes/uctoo/entity/EntityRoute.cj`，在 `registerCustomRoutes()` 中注册行级权限中间件
  - 为 entity 相关路由添加 RowLevelPermissionMiddleware 中间件
  - 需求映射：RLP-029, RLP-054

## 13. P1-模板化集成：crudgen Service模板扩展

- [ ] **T13.1** 修改 crudgen 的 `Service.cj.tpl` 模板，新增 `{{#if hasCreatorField}}` 条件块
  - 头部引入区：当 `hasCreatorField=true` 时，生成权限 import 语句（PermissionLevel、PermissionConfig、PermissionUtils）
  - AutoCreateCode区域内：当 `hasCreatorField=true` 时，生成5个 WithPermission 方法模板代码（每个表都需要的标准化代码）
    - `createWithPermission`、`getByIdWithPermission`、`getListWithPermission`、`updateWithPermission`、`deleteWithPermission`
  - 模板变量：`{{TableName}}`、`{{tableName}}`（表名大驼峰/小写）
  - **代码位置**：AutoCreateCode区域内（//#region AutoCreateCode ~ //#endregion AutoCreateCode）
  - 需求映射：RLP-055~RLP-057, RLP-060

- [ ] **T13.2** 修改 crudgen 的 `DAO.cj.tpl` 模板
  - 当目标表为 `data_access_authorization` 时，在AutoCreateCode区域内生成标准化权限查询方法（每个表都需要的通用查询支持）
  - **代码位置**：AutoCreateCode区域内（//#region AutoCreateCode ~ //#endregion AutoCreateCode）
  - 需求映射：RLP-053

- [ ] **T13.3** 修改 crudgen 的 `CrudGenerator.cj`，新增 creator 字段检测逻辑
  - 读取 db_info 表元数据获取字段列表
  - 检查是否包含 `creator` 字段，设置 `hasCreatorField = true/false`
  - 无法检测时默认 `false` 并记录警告日志（RLP-062）
  - 需求映射：RLP-056, RLP-057, RLP-062

- [ ] **T13.4** 修改 crudgen 的 `CrudGenerator.cj`，新增 `.env` 配置自动添加逻辑
  - 检查 `.env` 是否已存在 `ROW_LEVEL_PERMISSION_<表名>=` 配置，已存在则跳过（RLP-064）
  - 不存在时查找行级权限配置区块，区块存在则末尾追加（RLP-063）
  - 区块不存在则在 `.env` 末尾新增区块并添加配置（RLP-065）
  - 需求映射：RLP-063~RLP-065

## 14. P1-批量权限检查与审计日志

- [ ] **T14.1** 完善 PermissionUtils 审计日志
  - 所有权限检查操作记录审计日志，包含：用户ID、实体类型、实体ID、操作类型、检查结果
  - 权限拒绝时记录安全审计日志
  - 需求映射：RLP-047

## 15. 编译验证

- [ ] **T15.1** 执行仓颉项目编译，验证所有新增和修改文件无编译错误
  - 验证 `core/PermissionLevel.cj` 编译通过
  - 验证 `core/PermissionConfig.cj` 编译通过
  - 验证 `core/PermissionCache.cj` 编译通过
  - 验证 `utils/PermissionUtils.cj` 编译通过
  - 验证 `PermissionMiddleware.cj` 编译通过（PermissionLevel枚举迁移后）
  - 验证 `DataAccessAuthorizationDAO.cj` 编译通过（AutoCreateCode区域内新增方法）
  - 验证 `DataAccessAuthorizationService.cj` 编译通过
  - 验证 `DataAccessAuthorizationController.cj` 编译通过
  - 验证 `DataAccessAuthorizationRoute.cj` 编译通过
  - 验证 `EntityService.cj` 编译通过
  - 验证 `EntityController.cj` 编译通过
  - 验证 `EntityRoute.cj` 编译通过

## 16. 功能验证

- [ ] **T16.1** 验证权限级别枚举
  - READ=1, WRITE=2, AUTHORIZE=3 双向映射正确
  - 权限继承：hasPermission(AUTHORIZE, READ)=true, hasPermission(WRITE, READ)=true, hasPermission(READ, WRITE)=false

- [ ] **T16.2** 验证配置管理
  - ROW_LEVEL_PERMISSION_ENABLED=false 时所有检查放行
  - 表级配置优先于全局配置
  - 缓存TTL默认值300秒

- [ ] **T16.3** 验证缓存机制
  - 缓存命中时直接返回，不查数据库
  - TTL过期后重新加载
  - 授权变更后缓存失效
  - 并发安全（Mutex保护）

- [ ] **T16.4** 验证权限检查
  - 未授权用户访问数据 → 403
  - 创建者自动获得AUTHORIZE权限
  - READ权限检查：GET请求
  - WRITE权限检查：PUT/DELETE请求

- [ ] **T16.5** 验证权限过滤
  - 列表查询仅返回有权限的数据行
  - 无权限用户查询 → 空结果集
  - 过滤条件使用参数化查询，防SQL注入

- [ ] **T16.6** 验证授权管理API
  - POST /authorize 创建授权成功
  - POST /authorize 自授权 → 400
  - POST /authorize 越权授权 → 403
  - POST /revoke 删除授权成功
  - GET /:entityType/:entityId/authorizations 查询授权记录

- [ ] **T16.7** 验证中间件集成
  - RBAC通过后执行行级权限检查
  - 全局关闭时中间件放行
  - 表级未启用时中间件放行
  - 异常时安全优先拒绝请求

- [ ] **T16.8** 验证代码位置分层策略
  - 所有新增import在 `//#region AutoCreateCode` 之前的头部引入区
  - 每个表都需要的标准化权限检查代码在 `//#region AutoCreateCode` ~ `//#endregion AutoCreateCode` 区域内（Service层WithPermission方法、Controller层权限调用、DAO层权限查询方法）
  - 仅特定表专属的业务逻辑在 `//#endregion AutoCreateCode` 之后的定制开发区域（如data_access_authorization表的授权管理API）
  - PermissionUtils/PermissionConfig/PermissionCache等公共组件在独立公共文件中

- [ ] **T16.9** 验证 crudgen 模板化
  - crudgen对含creator字段的表在AutoCreateCode区域内生成权限集成代码
  - crudgen对不含creator字段的表不生成权限代码
  - .env 自动添加表级配置

---

## 任务依赖关系

```
T1.1 ──→ T1.2 (PermissionLevel枚举迁移)
T1.1 ──→ T2.1 (PermissionConfig依赖PermissionLevel)
T1.1 ──→ T3.1 (PermissionCache依赖PermissionLevel)
T2.1 ──→ T6.1 (PermissionUtils依赖PermissionConfig)
T3.1 ──→ T6.1 (PermissionUtils依赖PermissionCache)
T1.1 ──→ T5.1 (DAO方法返回值依赖PermissionLevel)
T5.1 ──→ T6.1 (PermissionUtils依赖DAO查询方法)
T6.1 ──→ T6.2 (过滤方法依赖检查方法)
T6.1 ──→ T6.3 (自动授权/批量检查依赖检查方法)
T6.1+T6.2+T6.3 ──→ T7.1+T7.2 (Service依赖PermissionUtils)
T7.2 ──→ T8.1+T8.2 (Controller依赖Service)
T8.2 ──→ T9.1 (Route依赖Controller)
T6.1 ──→ T10.1 (中间件依赖PermissionUtils)
T6.1+T6.2 ──→ T11.1+T11.2 (EntityService依赖PermissionUtils)
T11.2 ──→ T12.1 (EntityController依赖EntityService)
T12.1 ──→ T12.2 (EntityRoute依赖EntityController)
T11.2 ──→ T13.1 (模板化依赖集成示例)
T5.1 ──→ T13.2 (DAO模板依赖DAO方法定义)
T6.1 ──→ T14.1 (审计日志依赖PermissionUtils)
T全部 ──→ T15.1 (编译验证)
T15.1 ──→ T16.1~T16.9 (功能验证依赖编译通过)
```

## 任务统计

| 优先级 | 任务组数 | 任务数 | 需求覆盖 |
|--------|---------|--------|---------|
| P0 | 12 | 22 | RLP-001~RLP-052, RLP-055~RLP-061 |
| P1 | 2 | 5 | RLP-041~RLP-043, RLP-047, RLP-053~RLP-065 |
| 验证 | 2 | 10 | 全部功能验收 |
| **合计** | **16** | **37** | **RLP-001~RLP-065（全部66项需求）** |
