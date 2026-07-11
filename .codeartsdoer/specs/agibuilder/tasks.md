# AI Builder 平台 - 编码任务规划

## 开发规范

### 仓颉代码开发
- 所有仓颉（.cj）代码必须使用 **cangjie-coder 技能** 编写
- **严格遵循 V4 通用模块开发流程**：先执行DDL → load-db-info → crudgen生成标准CRUD → 在AutoCreateCode区域外进行定制开发
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 遵循 cangjie-coder 技能的四步工作流程：查阅 CangjieSkills 技能 → 检索代码片段 → 编辑适配 → 写入文件
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式
- 数据库列名使用 snake_case（deleted_at, updated_at），仓颉代码使用 camelCase（createdAt, updatedAt）
- **禁止使用SQL保留字作为列名**：`type`、`status`等关键字必须加前缀（task_type、task_status、member_role、message_type、msg_related_type）
- `type` 是保留关键字，用作变量名时用反引号转义 `` `type` ``
- String 的 trim 方法是 `trimAscii()`
- HashMap 用 `add()` 而不是 `put()`
- 获取当前用户 ID：`let userIdOpt = req.getLocals("userId")`，参考现有Controller中的模式
- **同包内的类默认可见，不需要显式 import，否则会产生循环依赖**
- **标准CRUD代码由crudgen自动生成到`//#region AutoCreateCode`区域，定制代码必须写在区域外**

### V4模块分层规范
```
magic.app.models.uctoo       ← 数据模型层（PO）— crudgen生成，手动扩展字段
    ↑
magic.app.dao.uctoo          ← 数据访问层（DAO）— crudgen生成标准方法，定制方法写在区域外
    ↑
magic.app.services.uctoo     ← 业务逻辑层（Service）— crudgen生成标准CRUD，定制方法写在区域外
    ↑
magic.app.controllers.uctoo  ← 控制器层（Controller）— crudgen生成标准接口，定制方法写在区域外
    ↑
magic.app.routes.uctoo       ← 路由层（Route）— crudgen生成标准路由，定制路由写在registerCustomRoutes
```
- 下层不能 import 上层
- DAO层使用setSql方法构建查询，不使用FROM().WHERE().first()链式调用
- DAO层不过滤软删除数据，软删除过滤由Service层或API使用方决定
- 统一使用ErrorHandler处理错误
- 使用APIResult作为Service层返回类型

### 前端代码开发
- 使用 TypeScript 编写前端代码
- 使用 Vue 3 + Vite + TinyVue 组件库构建
- 使用 Pinia + pinia-orm + @pinia-orm/axios 进行状态管理
- **严格遵循UMI同构规范**：所有后端API调用通过Pinia-ORM模型的`useAxiosRepo(table_name).api().method()`模式进行，模型文件位于`src/store/models/uctoo/`目录
- **禁止创建独立的api/*.ts文件**，所有API调用都通过Model.api()进行
- 标准CRUD方法参照现有模型（sms_log.ts、agent_tasks.ts、uctoo_user.ts）模板手写，定制方法写在`//#region Human-Code Preservation`区域内
- 公开页面使用 `PublicLayout` 布局（无侧边栏）
- 需登录页面使用 `DefaultLayout` 布局（有侧边栏）
- 公开页面路由 meta 设置 `{ requiresAuth: false }`
- 列表方法dataKey为表名直接加"s"（不做英文复数变化），如tasks→taskss、company→companys、messages→messagess

---

## 任务概览

| 统计项 | 数量 |
|--------|------|
| 主任务组 | 8 |
| 子任务数 | 28+7=35 |
| 覆盖需求 | REQ-AI-01 ~ REQ-AI-16（全部覆盖） |

---

## Phase 0 - 数据库准备与代码生成（人工操作）

> **本阶段为人工操作步骤**，DDL文件已创建完成，需人工执行数据库操作和代码生成。

### TASK-00：人工执行DDL并生成标准CRUD模块（人工操作）

- **关联需求**：REQ-AI-01
- **优先级**：P0
- **预估复杂度**：S
- **涉及文件**：
  - **已创建**：`sql/aibuilder_init.sql` — AI Builder数据库DDL脚本
- **任务描述**：
  按以下步骤执行：

  **步骤1：执行数据库DDL**
  - 连接PostgreSQL数据库（uctoo数据库）
  - 执行 `sql/aibuilder_init.sql` 脚本
  - 验证：company表新增7个字段，tasks/user_has_company/user_has_tasks/messages四张新表创建成功，索引创建成功

  **步骤2：刷新数据库元数据**
  - 启动agentskills-runtime服务
  - 调用 `POST /api/v1/uctoo/db_info/load-db-info` 接口刷新db_info表
  - 验证：db_info表中包含新表和新字段的元数据

  **步骤3：使用crudgen生成标准CRUD模块**
  - 进入crudgen脚本目录：`cd apps/agentskills-runtime/src/app/tools`（或参考crudgen使用文档）
  - 使用crudgen分别为以下4张表生成标准CRUD模块：
    - `tasks` 表 → 生成 TasksPO/TasksDAO/TasksService/TasksController/TasksRoute
    - `user_has_company` 表 → 生成 UserHasCompanyPO/DAO/Service/Controller/Route
    - `user_has_tasks` 表 → 生成 UserHasTasksPO/DAO/Service/Controller/Route
    - `messages` 表 → 生成 MessagesPO/DAO/Service/Controller/Route
  - 可选：使用crudgen重新生成company模块（获取新字段映射），**注意备份原有定制代码**
  - 可选：使用crudweb生成web管理界面

  **步骤4：验证生成结果**
  - 确认生成的文件位于正确目录：
    - `src/app/models/uctoo/TasksPO.cj`
    - `src/app/dao/uctoo/TasksDAO.cj`
    - `src/app/services/uctoo/TasksService.cj`
    - `src/app/controllers/uctoo/tasks/TasksController.cj`
    - `src/app/routes/uctoo/tasks/TasksRoute.cj`
  - 确认路由注册入口中注册了新模块的路由
  - 执行 `cjpm build` 确认生成的代码编译通过

  **crudgen生成后的验证清单**：
  - [ ] company表org_*字段已添加到CompanyPO（如果重新生成了company模块）
  - [ ] tasks表的`task_type`映射为`taskType`（不是type）
  - [ ] tasks表的`task_status`映射为`taskStatus`（不是status）
  - [ ] user_has_company表的`member_role`映射为`memberRole`（不是role）
  - [ ] messages表的`message_type`映射为`messageType`
  - [ ] messages表的`msg_related_type`映射为`msgRelatedType`
  - [ ] 所有生成的文件包含`//#region AutoCreateCode`和`//#endregion AutoCreateCode`标记
  - [ ] cjpm build编译通过

- **验收标准**：
  1. DDL执行成功，数据库表结构正确
  2. load-db-info刷新成功
  3. crudgen成功生成4个新模块的标准CRUD代码
  4. 生成的代码编译通过
  5. 标准CRUD API（/add, /edit, /del, /:id等）可正常访问

---

## Phase 1 - 数据模型层与DAO层定制开发

> crudgen生成标准代码后，在AutoCreateCode区域外添加定制方法。

### TASK-01：CompanyPO扩展org_*字段

- **关联需求**：REQ-AI-01
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：TASK-00
- **涉及文件**：
  - **修改文件**：`src/app/models/uctoo/CompanyPO.cj`
- **任务描述**：
  如果crudgen重新生成了CompanyPO，确认org_*字段已自动映射；如果未重新生成，手动添加以下字段：
  ```cangjie
  @ORMField['org_description'] public var orgDescription: String = ""
  @ORMField['member_count']    public var memberCount: Int32 = 0
  @ORMField['task_count']      public var taskCount: Int32 = 0
  @ORMField['follower_count']  public var followerCount: Int32 = 0
  @ORMField['is_verified']     public var isVerified: Bool = false
  @ORMField['org_type']        public var orgType: String = "community"
  @ORMField['tags']            public var tags: String = "[]"
  ```
  同时在toJsonValue方法中添加这些字段的序列化（使用addFieldToJson辅助方法）。

  **注意**：如果crudgen已经根据新的表结构生成了这些字段，只需验证映射正确即可。

- **验收标准**：
  1. CompanyPO包含所有org_*字段
  2. toJsonValue正确序列化新字段
  3. 编译通过

### TASK-02：TasksDAO添加定制查询方法

- **关联需求**：REQ-AI-02
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-00
- **涉及文件**：
  - **修改文件**：`src/app/dao/uctoo/TasksDAO.cj`
- **任务描述**：
  在TasksDAO的`//#endregion AutoCreateCode`之后的「定制开发区域」添加以下方法：
  1. `findTasksByCondition(where: HashMap<String, String>, orderBy: String, page: Int64, size: Int64): (ArrayList<TasksPO>, Int64)` — 公开任务分页查询（复用 requestParser 解析 filter/sort）
     - 使用setSql构建查询
     - WHERE条件：deleted_at IS NULL + 动态拼接筛选条件
     - tag使用JSONB包含查询：`tags @> ${arg(jsonArray)}`
     - orderBy动态排序，支持多字段，负号表示降序
  2. `incrementViewCount(taskId: String): Int64` — view_count + 1
  3. `incrementFollowerCount(taskId: String): Int64` — follower_count + 1
  4. `decrementFollowerCount(taskId: String): Int64` — follower_count - 1（确保不低于0：GREATEST(follower_count - 1, 0)）
  5. `incrementParticipantCount(taskId: String): Int64` — participant_count + 1
  6. `updateTaskStatus(taskId: String, taskStatus: String): Int64` — 更新task_status，根据状态设置started_at/completed_at
  7. `findHomeTaskStats(): Int64` — 统计open状态的任务总数（WHERE deleted_at IS NULL AND task_status = 'open'）
  8. `findTasksByCompanyId(companyId: String, page: Int64, pageSize: Int64): Pagination<TasksPO>` — 查询组织下的公开任务

  **开发规范**：
  - 必须使用 cangjie-coder 技能编写
  - 使用setSql方法，不使用链式调用
  - 参考EntityDAO.cj中的分页查询模式

- **验收标准**：
  1. 所有定制方法在AutoCreateCode区域外
  2. 分页查询支持筛选和排序
  3. 计数增减方法不会产生负数
  4. 编译通过

### TASK-03：UserHasCompanyDAO添加定制方法

- **关联需求**：REQ-AI-06
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-00
- **涉及文件**：
  - **修改文件**：`src/app/dao/uctoo/UserHasCompanyDAO.cj`
- **任务描述**：
  在定制开发区域添加：
  1. `findRelation(userId: String, companyId: String, memberRole: String): Option<UserHasCompanyPO>` — 查询指定关系
  2. `findUserRolesInCompany(userId: String, companyId: String): ArrayList<UserHasCompanyPO>` — 查询用户在组织的所有角色
  3. `isMember(userId: String, companyId: String): Bool` — 判断是否为成员（owner/admin/member），SQL: EXISTS查询member_role IN ('owner','admin','member')
  4. `findFollowersByCompanyId(companyId: String): ArrayList<UserHasCompanyPO>` — 查询组织关注者
  5. `findCompaniesByUserIdAndRole(userId: String, memberRole: String, page: Int64, pageSize: Int64): Pagination<UserHasCompanyPO>` — 查询用户某角色的组织

- **验收标准**：
  1. isMember对owner/admin/member返回true，follower返回false
  2. 编译通过

### TASK-04：UserHasTasksDAO添加定制方法

- **关联需求**：REQ-AI-07
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-00
- **涉及文件**：
  - **修改文件**：`src/app/dao/uctoo/UserHasTasksDAO.cj`
- **任务描述**：
  在定制开发区域添加：
  1. `findRelation(userId: String, taskId: String, relationType: String): Option<UserHasTasksPO>` — 查询指定关系
  2. `isFollowing(userId: String, taskId: String): Bool` — 判断是否关注
  3. `findFollowersByTaskId(taskId: String): ArrayList<UserHasTasksPO>` — 查询任务所有关注者（用于通知）
  4. `findTasksByUserIdAndRelation(userId: String, relationType: String, page: Int64, pageSize: Int64): Pagination<UserHasTasksPO>` — 查询用户某类关系的任务关联

- **验收标准**：
  1. 关系查询正确
  2. 关注者列表正确返回
  3. 编译通过

### TASK-05：MessagesDAO添加定制方法

- **关联需求**：REQ-AI-08
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-00
- **涉及文件**：
  - **修改文件**：`src/app/dao/uctoo/MessagesDAO.cj`
- **任务描述**：
  在定制开发区域添加：
  1. `queryMessagesByUserId(userId: String, page: Int64, pageSize: Int64, messageType: String): Pagination<MessagesPO>` — 分页查询用户消息（按created_at DESC）
  2. `countUnread(userId: String): Int64` — 统计未读消息数（is_read = false）
  3. `markAsRead(msgId: String): Int64` — 标记单条已读（设置is_read=true, read_at=now()）
  4. `markAllAsRead(userId: String): Int64` — 标记用户所有消息已读
  5. `batchInsert(messages: ArrayList<MessagesPO>): Unit` — 批量插入消息（用于批量通知）

- **验收标准**：
  1. 分页查询按时间倒序
  2. 未读计数正确
  3. 批量插入正确
  4. 编译通过

### TASK-06：CompanyDAO添加定制方法

- **关联需求**：REQ-AI-03, REQ-AI-05
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-00
- **涉及文件**：
  - **修改文件**：`src/app/dao/uctoo/CompanyDAO.cj`
- **任务描述**：
  在定制开发区域添加：
  1. `queryPublicCompaniesWithPagination(page: Int64, pageSize: Int64, orgType: String, tag: String, sortBy: String): Pagination<CompanyPO>` — 公开组织分页查询
     - WHERE：deleted_at IS NULL AND org_type IS NOT NULL AND org_type != ''
     - 支持org_type筛选、tag JSONB筛选
     - sortBy：latest→created_at DESC, popular→follower_count DESC, task_count DESC
  2. `findPublicCompanyById(companyId: String): Option<CompanyPO>` — 查询公开组织详情（同样过滤org_type条件）
  3. `incrementTaskCount(companyId: String): Int64` — task_count + 1
  4. `decrementTaskCount(companyId: String): Int64` — task_count - 1
  5. `incrementFollowerCount(companyId: String): Int64` — follower_count + 1
  6. `decrementFollowerCount(companyId: String): Int64` — follower_count - 1
  7. `incrementMemberCount(companyId: String): Int64` — member_count + 1
  8. `decrementMemberCount(companyId: String): Int64` — member_count - 1
  9. `countPublicCompanies(): Int64` — 统计公开组织总数

- **验收标准**：
  1. 公开列表正确过滤org_type条件
  2. 计数增减不产生负数
  3. 编译通过

---

## Phase 2 - Service层定制业务逻辑

> 在crudgen生成的Service基础上，添加AI Builder的定制业务逻辑。

### TASK-07：TasksService添加定制业务方法

- **关联需求**：REQ-AI-02, REQ-AI-04, REQ-AI-06
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-02, TASK-04, TASK-05
- **涉及文件**：
  - **修改文件**：`src/app/services/uctoo/TasksService.cj`
- **任务描述**：
  TasksService需要注入TasksDAO、CompanyDAO、UserHasTasksDAO、MessagesService（注意跨Service引用方式）。在定制区域添加：
  1. `listPublicTasksWithFilter(page: Int32, pageSize: Int32, sort: String, filter: String): (ArrayList<TasksPO>, Int64)` — 获取公开任务列表，返回(列表, 总数)元组
     - 复用 requestParser 解析 filter 为 HashMap<String, String>
     - 解析 sort 为 orderBy SQL 字符串
     - 调用 tasksDAO.findTasksByCondition 查询
  2. `getPublicTaskDetail(taskId: String, userId: String): APIResult<JsonObject>` — 获取任务详情
     - 调用findTaskById查询任务
     - 调用incrementViewCount增加浏览数
     - 如果userId非空，查询是否已关注/参与
     - 关联查询创建者信息（uctoo_user表的nickname、avatar）
     - 如果companyId非空，查询组织名称和logo
  3. `getHomeStats(): APIResult<JsonObject>` — 首页统计：open任务数、公开组织数、参与者总数
  4. `createAiTask(userId: String, data: JsonObject): APIResult<String>` — 创建AI Builder任务
     - 验证title/description非空
     - 如果companyId非空，验证用户为该组织成员（调用userHasCompanyService或DAO）
     - 构建TasksPO，设置creatorId=userId, taskStatus="open"
     - 调用DAO插入
     - 创建UserHasTasksPO（relation_type="creator"）
     - 如果companyId非空，调用companyDAO.incrementTaskCount
     - 调用messagesService向组织成员发送通知
  5. `updateTaskStatus(userId: String, taskId: String, taskStatus: String): APIResult<Bool>` — 更新任务状态
     - 验证权限（创建者或组织管理员）
     - 更新task_status，设置started_at/completed_at
     - 通知关注者
  6. `getMyTasks(userId: String, relation: String, page: Int32, pageSize: Int32): APIResult<JsonObject>` — 我的任务列表

  **开发规范**：
  - 必须使用 cangjie-coder 技能
  - 使用APIResult作为返回类型
  - 参考现有Service的代码模式
  - Service之间注入注意避免循环依赖

- **验收标准**：
  1. 所有定制方法在AutoCreateCode区域外
  2. 公开查询正确过滤软删除和状态
  3. 创建任务正确维护关联关系和计数
  4. 状态变更触发通知
  5. 权限验证正确
  6. 编译通过

### TASK-08：UserHasCompanyService和UserHasTasksService关注/成员逻辑

- **关联需求**：REQ-AI-06, REQ-AI-07
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-03, TASK-04, TASK-06
- **涉及文件**：
  - **修改文件**：`src/app/services/uctoo/UserHasCompanyService.cj`
  - **修改文件**：`src/app/services/uctoo/UserHasTasksService.cj`
- **任务描述**：

  **A. UserHasCompanyService** 注入UserHasCompanyDAO、CompanyDAO，添加：
  1. `isMember(userId: String, companyId: String): Bool` — 委托DAO
  2. `toggleCompanyFollow(userId: String, companyId: String): APIResult<Bool>` — 关注/取消关注组织
  3. `joinCompany(userId: String, companyId: String): APIResult<Bool>` — 加入组织（创建member关系，增加member_count）
  4. `leaveCompany(userId: String, companyId: String): APIResult<Bool>` — 退出组织（owner不能退出）
  5. `getMyCompanies(userId: String, page: Int32, pageSize: Int32): APIResult<JsonObject>` — 我的组织

  **B. UserHasTasksService** 注入UserHasTasksDAO、TasksDAO、MessagesService，添加：
  1. `toggleTaskFollow(userId: String, taskId: String): APIResult<Bool>` — 关注/取消关注任务
  2. `joinTask(userId: String, taskId: String): APIResult<Bool>` — 参与任务（创建participant关系，增加participant_count）
  3. `getMyFollowedTasks(userId: String, page: Int32, pageSize: Int32): APIResult<JsonObject>` — 我关注的任务

  **关注/取消逻辑模式**：
  ```
  查询现有关系 → 
    存在：软删除 → 计数-1 → 返回false（已取消）
    不存在：创建关系 → 计数+1 → 返回true（已关注）
  ```

- **验收标准**：
  1. 关注切换是幂等操作
  2. 计数与关系一致
  3. owner不能退出组织
  4. 编译通过

### TASK-09：MessagesService添加通知业务方法

- **关联需求**：REQ-AI-08
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-05
- **涉及文件**：
  - **修改文件**：`src/app/services/uctoo/MessagesService.cj`
- **任务描述**：
  在定制区域添加：
  1. `sendMessage(userId, senderId, messageType, title, content, msgRelatedType, relatedId): APIResult<Bool>` — 发送单条消息
  2. `notifyTaskFollowers(taskId: String, excludeUserId: String, title: String, content: String): Unit` — 批量通知任务关注者
  3. `notifyCompanyMembers(companyId: String, excludeUserId: String, title: String, content: String): Unit` — 批量通知组织成员
  4. `getMessageList(userId: String, page: Int32, pageSize: Int32, messageType: String): APIResult<JsonObject>` — 获取消息列表
  5. `getUnreadCount(userId: String): APIResult<Int64>` — 未读消息数
  6. `markAsRead(userId: String, msgId: String): APIResult<Bool>` — 标记已读（验证归属）
  7. `markAllAsRead(userId: String): APIResult<Bool>` — 全部已读

- **验收标准**：
  1. 批量通知排除操作者
  2. 标记已读验证消息归属
  3. 编译通过

### TASK-10：CompaniesService添加组织业务方法

- **关联需求**：REQ-AI-03, REQ-AI-05
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-06, TASK-08
- **涉及文件**：
  - **修改文件**：`src/app/services/uctoo/CompaniesService.cj`
- **任务描述**：
  在定制区域添加：
  1. `getPublicCompanyList(page: Int32, pageSize: Int32, orgType: String, tag: String, sortBy: String): APIResult<JsonObject>` — 公开组织列表
  2. `getPublicCompanyDetail(companyId: String, userId: String): APIResult<JsonObject>` — 组织详情（含用户关系状态、最新任务列表）
  3. `getCompanyGrowth(companyId: String): APIResult<JsonObject>` — 组织成长数据（统计数据）
  4. `createAiOrg(userId: String, data: JsonObject): APIResult<String>` — 创建AI Builder组织
     - 设置org_type字段
     - 创建后自动建立owner关系
     - 返回companyId
  5. `getPublicCompanyTasks(companyId: String, page: Int32, pageSize: Int32): APIResult<JsonObject>` — 组织公开任务列表

- **验收标准**：
  1. 公开列表正确过滤
  2. 创建组织自动建立owner关系
  3. 详情包含用户关系状态
  4. 编译通过

---

## Phase 3 - Controller层与公开API

> 扩展crudgen生成的Controller，添加定制接口；创建PublicTasksController/PublicCompaniesController公开控制器；配置公开路由。

### TASK-11：扩展RequirePermissionMiddleware配置公开路由

- **关联需求**：REQ-AI-02, REQ-AI-03
- **优先级**：P0
- **预估复杂度**：S
- **依赖**：无
- **涉及文件**：
  - **修改文件**：`src/app/middlewares/auth/RequirePermissionMiddleware.cj`
- **任务描述**：
  在isPublicRoute方法中添加AI Builder公开API路径判断：
  ```cangjie
  // AI Builder公开API
  if (route.contains("/tasks/public") || route.contains("/company/public")) {
      return true
  }
  ```

- **验收标准**：
  1. /tasks/public/*路径无需登录
  2. /company/public/*路径无需登录
  3. 其他路径权限逻辑不受影响
  4. 编译通过

### TASK-12：创建PublicTasksController和PublicTasksRoute

- **关联需求**：REQ-AI-02
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-07, TASK-11
- **涉及文件**：
  - **新建文件**：`src/app/controllers/uctoo/tasks/PublicTasksController.cj`
  - **新建文件**：`src/app/routes/uctoo/tasks/PublicTasksRoute.cj`
  - **修改文件**：路由注册入口（注册PublicTasksRoute）
- **任务描述**：

  **A. PublicTasksController**（包名`magic.app.controllers.uctoo.tasks`，全部为定制代码）：
  1. 注入TasksService
  2. `getHomeStats(req, res)` — GET /public/home-stats
  3. `getPublicList(req, res)` — GET /public/:limit/:page，从路径参数解析 limit/page，从查询参数解析 sort/filter，可选获取userId
  4. `getPublicDetail(req, res)` — GET /public/:id

  **B. PublicTasksRoute**（包名`magic.app.routes.uctoo.tasks`）：
  注册公开路由：
  ```
  GET /api/v1/uctoo/tasks/public/home-stats
  GET /api/v1/uctoo/tasks/public/:limit/:page
  GET /api/v1/uctoo/tasks/public/:id
  ```

  **C. 在路由注册入口注册PublicTasksRoute**

  **开发规范**：
  - 使用ErrorHandler统一错误处理
  - 列表查询返回格式 `{currentPage, totalCount, totalPage, tasks: [...]}`
  - 参考现有Controller的代码结构

- **验收标准**：
  1. 公开API无需登录即可访问
  2. 参数解析正确
  3. 返回格式正确
  4. 路由正确注册
  5. 编译通过

### TASK-13：创建PublicCompaniesController和PublicCompaniesRoute

- **关联需求**：REQ-AI-03
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-10, TASK-11
- **涉及文件**：
  - **新建文件**：`src/app/controllers/uctoo/company/PublicCompaniesController.cj`
  - **新建文件**：`src/app/routes/uctoo/company/PublicCompaniesRoute.cj`
  - **修改文件**：路由注册入口
- **任务描述**：

  **A. PublicCompaniesController**：
  1. 注入CompaniesService
  2. `getPublicList(req, res)` — GET /public/:limit/:page，从路径参数解析 limit/page，从查询参数解析 sort/filter
  3. `getPublicDetail(req, res)` — GET /public/:id
  4. `getCompanyTasks(req, res)` — GET /public/:id/tasks/:limit/:page
  5. `getCompanyGrowth(req, res)` — GET /public/:id/growth

  **B. PublicCompaniesRoute** 注册路由：
  ```
  GET /api/v1/uctoo/company/public/:limit/:page
  GET /api/v1/uctoo/company/public/:id
  GET /api/v1/uctoo/company/public/:id/tasks/:limit/:page
  GET /api/v1/uctoo/company/public/:id/growth
  ```

- **验收标准**：
  1. 公开API无需登录
  2. 组织详情正确返回
  3. 编译通过

### TASK-14：扩展TasksController/CompanyController/MessagesController添加定制接口

- **关联需求**：REQ-AI-04~REQ-AI-08
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-07, TASK-08, TASK-09, TASK-10
- **涉及文件**：
  - **修改文件**：`src/app/controllers/uctoo/tasks/TasksController.cj`
  - **修改文件**：`src/app/controllers/uctoo/company/CompanyController.cj`
  - **修改文件**：`src/app/controllers/uctoo/messages/MessagesController.cj`
  - **修改文件**：`src/app/controllers/uctoo/user_has_tasks/UserHasTasksController.cj`
  - **修改文件**：`src/app/controllers/uctoo/user_has_company/UserHasCompanyController.cj`
  - **修改文件**：各对应Route文件（在registerCustomRoutes注册定制路由）
- **任务描述**：
  在各Controller的定制区域添加接口方法，并在Route的registerCustomRoutes中注册定制路由：

  **TasksController定制方法**：
  1. `updateStatus(req, res)` — POST /:id/update-status → 调用tasksService.updateTaskStatus
  2. `toggleFollow(req, res)` — POST /:id/toggle-follow → 调用userHasTasksService.toggleTaskFollow
  3. `joinTask(req, res)` — POST /:id/join → 调用userHasTasksService.joinTask
  4. `getMyTasks(req, res)` — GET /my → 调用tasksService.getMyTasks

  **CompanyController定制方法**：
  1. `toggleFollow(req, res)` — POST /:id/toggle-follow → 调用userHasCompanyService.toggleCompanyFollow
  2. `joinCompany(req, res)` — POST /:id/join → 调用userHasCompanyService.joinCompany
  3. `leaveCompany(req, res)` — POST /:id/leave → 调用userHasCompanyService.leaveCompany
  4. `getMyCompanies(req, res)` — GET /my → 调用companiesService相关方法
  5. 扩展add方法支持创建AI Builder组织（根据org_type字段区分）

  **MessagesController定制方法**：
  1. `getUnreadCount(req, res)` — GET /unread-count
  2. `markAsRead(req, res)` — POST /:id/mark-read
  3. `markAllAsRead(req, res)` — POST /mark-all-read

  **Route定制路由注册**（在registerCustomRoutes方法中）：
  ```cangjie
  // TasksRoute
  router.post("/api/v1/uctoo/tasks/:id/update-status", controller.updateStatus)
  router.post("/api/v1/uctoo/tasks/:id/toggle-follow", controller.toggleFollow)
  router.post("/api/v1/uctoo/tasks/:id/join", controller.joinTask)
  router.get("/api/v1/uctoo/tasks/my", controller.getMyTasks)

  // CompanyRoute
  router.post("/api/v1/uctoo/company/:id/toggle-follow", controller.toggleFollow)
  router.post("/api/v1/uctoo/company/:id/join", controller.joinCompany)
  router.post("/api/v1/uctoo/company/:id/leave", controller.leaveCompany)
  router.get("/api/v1/uctoo/company/my", controller.getMyCompanies)

  // MessagesRoute
  router.get("/api/v1/uctoo/messages/unread-count", controller.getUnreadCount)
  router.post("/api/v1/uctoo/messages/:id/mark-read", controller.markAsRead)
  router.post("/api/v1/uctoo/messages/mark-all-read", controller.markAllAsRead)
  ```

- **验收标准**：
  1. 所有定制接口在AutoCreateCode区域外
  2. 所有定制路由在registerCustomRoutes中注册
  3. 需认证接口正确获取userId
  4. 编译通过

### TASK-15：后端编译与基础API测试

- **关联需求**：所有后端需求
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-11~TASK-14
- **任务描述**：
  1. 执行 `cjpm build` 编译整个项目
  2. 修复所有编译错误
  3. 启动服务，测试API：
     - 公开API：curl访问无需token
     - 认证API：先登录获取token，带token访问
  4. 验证标准CRUD和定制API都正常工作

- **验收标准**：
  1. cjpm build编译通过
  2. 服务正常启动
  3. 公开API无需登录返回200
  4. 认证API未登录返回401
  5. 基本CRUD功能正常

---

## Phase 4 - 前端基础设施与Pinia-ORM模型

> 创建前端布局、Pinia-ORM模型（遵循UMI规范）、路由配置。

### TASK-16：创建前端Pinia-ORM模型（遵循UMI同构规范）

- **关联需求**：REQ-AI-10
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-15
- **涉及文件**：
  - **新建文件**：`apps/web-admin/web/src/store/models/uctoo/tasks.ts`
  - **新建文件**：`apps/web-admin/web/src/store/models/uctoo/company.ts`
  - **新建文件**：`apps/web-admin/web/src/store/models/uctoo/user_has_tasks.ts`
  - **新建文件**：`apps/web-admin/web/src/store/models/uctoo/user_has_company.ts`
  - **新建文件**：`apps/web-admin/web/src/store/models/uctoo/messages.ts`
  - **修改文件**：`apps/web-admin/web/src/store/models/uctoo/uctoo_user.ts`
  - **修改文件**：`apps/web-admin/web/src/store/models/uctoo/index.ts`
- **任务描述**：
  严格遵循UMI同构规范创建Pinia-ORM模型，参照现有模型文件（sms_log.ts、agent_tasks.ts、uctoo_user.ts）的代码风格：

  **模型文件统一模板**：
  1. 文件顶部保留空的`//#region Human-Code Preservation`区域
  2. 使用注释说明apiURL用途：`// 使用 VITE_BACKEND_URL（install.html 配置的后端服务域名）`
  3. 定义`const apiURL = import.meta.env.VITE_BACKEND_URL || 'https://localhost:443';`
  4. 类继承Model，`static override entity = 'table_name'`
  5. 字段声明使用snake_case（与数据库列名一致），使用@Uid/@Str/@Num/@Attr装饰器
  6. static override.config.axiosApi.actions中包含标准CRUD方法：
     - `get{Entity}List(page, pageSize, searchParams)` — GET列表，设置dataKey为表名+"s"（直接加s，不做复数变化）
     - `get{Entity}(id)` — GET单条
     - `add{Entity}(data)` — POST新增（/add）
     - `edit{Entity}(data)` — POST编辑（/edit）
     - `delete{Entity}(data)` — POST删除（/del）
     - `batchDelete{Entity}(params)` — POST批量删除
     - `batchRestore{Entity}(ids)` — POST批量恢复
     - `emptyRecycleBin()` — POST清空回收站
  7. 标准方法之后是`//#region Human-Code Preservation`区域，放置定制API方法
  8. 需认证API携带Authorization头，公开API不携带
  9. index.ts中使用`export * from './filename';`导出新模型

  **各模型需实现的定制方法**（Human-Code区域）：
  - **tasks.ts**：getHomeStats、getPublicList、getPublicDetail、toggleFollow、joinTask、updateStatus、getMyTasks
  - **company.ts**：getPublicList、getPublicDetail、getPublicTasks、getOrgGrowth、toggleFollow、joinCompany、leaveCompany、getMyCompanies
  - **messages.ts**：getUnreadCount、markRead、markAllRead
  - **user_has_tasks.ts**：标准CRUD即可
  - **user_has_company.ts**：标准CRUD即可
  - **uctoo_user.ts**：在现有Human-Code区域添加getMyPoints方法（个人资料复用getCurrentUser/editUctooUser）

- **验收标准**：
  1. 所有模型文件代码风格与sms_log.ts/agent_tasks.ts完全一致
  2. 标准CRUD方法命名正确（get{Entity}List/get{Entity}/add{Entity}/edit{Entity}/delete{Entity}）
  3. dataKey设置正确（tasks→taskss、company→companys、messages→messagess）
  4. 公开API方法不携带Authorization头
  5. 定制方法位于Human-Code Preservation区域内
  6. index.ts正确导出所有新模型
  7. **禁止创建独立的api/*.ts文件**
  8. TypeScript类型检查通过

### TASK-17：创建PublicLayout公开布局组件

- **关联需求**：REQ-AI-09
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：无
- **涉及文件**：
  - **新建文件**：`apps/web-admin/web/src/layout/public-layout.vue`
- **任务描述**：
  创建公开页面布局：
  1. 顶部导航栏：Logo（AI Builder）、导航链接（首页、任务广场、组织）
  2. 右侧：未登录显示"登录"/"注册"按钮；已登录显示用户头像+下拉菜单（个人中心、消息、我的任务、我的关注、退出）
  3. 消息未读数红点
  4. 无侧边栏，内容区router-view
  5. 简洁现代风格，参考截图设计

- **验收标准**：
  1. 导航正确高亮当前路由
  2. 登录/未登录状态正确切换
  3. 未读消息数显示
  4. router-view正常渲染子页面

### TASK-18：配置前端路由

- **关联需求**：REQ-AI-09, REQ-AI-10
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-17
- **涉及文件**：
  - **新建文件**：`apps/web-admin/web/src/router/routes/modules/aibuilder.ts`
  - **修改文件**：路由注册入口（确认新路由模块被加载）
- **任务描述**：
  按照design.md中的路由表配置，公开页面使用PublicLayout+requiresAuth:false，登录页面使用DefaultLayout+requiresAuth:true。

- **验收标准**：
  1. 公开路由无需登录可访问
  2. 需登录路由未登录跳转登录页
  3. 所有路由正确懒加载

---

## Phase 5 - 前端页面开发

> 参考截图开发所有页面。

### TASK-19：开发公开页面（首页、任务列表、任务详情、组织列表、组织详情、组织成长）

- **关联需求**：REQ-AI-02, REQ-AI-03
- **优先级**：P0
- **预估复杂度**：XL
- **依赖**：TASK-16, TASK-18
- **涉及文件**：
  - **新建文件**：6个公开页面（见design.md页面清单）
- **任务描述**：
  参考截图开发6个公开页面，使用TinyVue组件库：
  - 首页：Hero区、统计数据、精选任务、热门组织
  - 任务列表：筛选栏、搜索、卡片列表、分页
  - 任务详情：标题、描述、创建者、组织信息、标签、关注/参与按钮
  - 组织列表：组织卡片、筛选、分页
  - 组织详情：组织信息、统计、任务列表、成员
  - 组织成长：成长时间线、数据展示

  需要登录的操作（关注、参与）未登录时提示登录。

- **验收标准**：
  1. 页面正常渲染，数据正确加载
  2. 筛选/排序/分页功能正常
  3. 关注按钮交互正常
  4. 页面风格与截图一致

### TASK-20：开发需登录页面（创建任务、创建组织、个人中心、消息、我的关注、我的任务）

- **关联需求**：REQ-AI-04~REQ-AI-08
- **优先级**：P0
- **预估复杂度**：XL
- **依赖**：TASK-16, TASK-18
- **涉及文件**：
  - **新建文件**：7个登录页面（见design.md页面清单）
- **任务描述**：
  参考截图开发7个需登录页面：
  - 创建任务：表单（标题、描述、类型、优先级、关联组织、截止时间、标签、技能）、预览确认流程
  - 创建组织：表单（名称、Logo上传、简介、类型、标签）
  - 个人中心：头像、昵称、简介编辑，我的组织
  - 消息列表：分类Tab、消息卡片、未读标记、全部已读
  - 我的关注：Tab切换关注的任务/组织，取消关注
  - 我的任务：Tab切换（发布的/参与的/关注的）、任务卡片、状态更新

- **验收标准**：
  1. 表单验证正确
  2. 创建流程（含预览确认）完整
  3. 消息已读/未读状态正确
  4. Tab切换正常
  5. 页面风格与截图一致

---

## Phase 5.5 - 积分系统开发

> 实现积分冻结、结算、退还、流水记录、多人分配和计划任务。

> **重要前置条件**：需人工执行 `sql/aibuilder_points_update_20260628.sql`，然后刷新db_info，使用crudgen生成point_transactions、task_settlements两张新表的标准模块 + 已有user_score表的CRUD模块，并重新生成tasks、user_has_tasks、company模块以包含新字段。不修改uctoo_user表结构。

### TASK-22：执行积分系统数据库变更并重新生成模块

- **关联需求**：REQ-AI-12, REQ-AI-13, REQ-AI-14, REQ-AI-15
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-1至TASK-8（基础模块已生成）
- **操作步骤**（人工执行）：
  1. 执行 `sql/aibuilder_points_update_20260628.sql` 变更脚本（company添加points_balance字段、新建point_transactions和task_settlements表、更新注释和索引）
  2. 调用 `/api/v1/uctoo/db_info/load-db-info?table_schema=uctoo` 刷新数据库元数据
  3. 使用crudgen生成 `point_transactions` 和 `task_settlements` 两张新表的标准CRUD模块
  4. 使用crudgen为已有的 `user_score` 表生成标准CRUD模块（之前未生成）
  5. 使用crudgen重新生成 `tasks`、`user_has_tasks`、`company` 模块（包含新字段），注意合并之前的定制代码（AutoCreateCode区域外的代码需要手动合并）
  6. **不重新生成uctoo_user模块**（不修改uctoo_user表结构）
  7. 使用crudweb生成前端Pinia-ORM模型和管理界面
- **验收标准**：
  1. point_transactions、task_settlements、user_score的PO/DAO/Service/Controller/Route五层代码生成成功
  2. tasks/user_has_tasks/company模块包含新增字段
  3. uctoo_user模块未被修改
  4. 项目编译通过（cjpm build成功）

### TASK-23：实现积分核心服务（PointTransactionsService + UserScoreService定制开发）

- **关联需求**：REQ-AI-12, REQ-AI-13
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-22
- **涉及文件**：
  - **修改文件**：`src/app/services/uctoo/PointTransactionsService.cj`（定制开发区域）
  - **修改文件**：`src/app/services/uctoo/UserScoreService.cj`（定制开发区域）
- **任务描述**：
  **UserScoreService中实现用户积分操作方法**（写在AutoCreateCode区域外）：
  1. `getOrCreateUserScore(userId)` - 获取或创建用户积分记录（from_umodel='uctoo_user'）
  2. `getUserTotalScore(userId)` - 查询用户积分余额（返回user_score.total_score，Int64类型）
  3. `addUserScore(userId, points)` - 增加用户积分
  4. `deductUserScore(userId, points)` - 扣减用户积分（用于未来可能的消费场景）
  
  **PointTransactionsService中实现积分核心操作方法**（写在AutoCreateCode区域外）：
  1. `freezeCompanyPoints(companyId, points, taskId)` - 冻结公司积分：检查company.points_balance余额→扣减company.points_balance→设置tasks.points_frozen→记录freeze流水
  2. `unfreezeCompanyPoints(companyId, points, taskId)` - 解冻/退还公司积分：增加company.points_balance→清零tasks.points_frozen→记录refund流水
  3. `settlePointsToUser(companyId, userId, points, taskId)` - 单人结算：扣减tasks.points_frozen→调用UserScoreService.addUserScore增加用户积分→记录双方流水（settle_pay/settle）
  4. `settlePointsMulti(companyId, allocations, taskId)` - 多人结算：按分配比例分别调用addUserScore转账→未分配部分退还公司
  5. `refundExpiredTaskPoints(taskId)` - 超期任务退还积分：调用unfreezeCompanyPoints
  6. `getUserPointsBalance(userId)` - 查询用户积分余额（委托UserScoreService）
  7. `getCompanyPointsBalance(companyId)` - 查询公司积分余额（查询company.points_balance）
  8. `getUserTransactions(userId, page, pageSize)` - 查询用户积分流水
  9. `getCompanyTransactions(companyId, page, pageSize)` - 查询公司积分流水
  
  **重要**：
  - 所有积分变动操作必须使用数据库事务，确保原子性
  - 用户积分操作user_score表（total_score字段，Int32），与流水表的Int64之间注意类型转换
  - 用户没有user_score记录时需要自动创建（from_umodel='uctoo_user'）

- **验收标准**：
  1. 冻结积分后公司余额减少，tasks.points_frozen增加
  2. 结算后user_score.total_score增加，tasks.points_frozen减少
  3. 流水记录完整包含balance_before和balance_after
  4. 余额不足时抛出业务异常
  5. 新用户自动创建user_score记录
  6. 所有操作在事务中执行，异常时自动回滚

### TASK-24：扩展TasksService实现积分冻结和状态机

- **关联需求**：REQ-AI-13, REQ-AI-16
- **优先级**：P0
- **预估复杂度**：L
- **依赖**：TASK-23
- **涉及文件**：
  - **修改文件**：`src/app/services/uctoo/TasksService.cj`（定制开发区域）
  - **修改文件**：`src/app/services/uctoo/UserHasTasksService.cj`（定制开发区域）
- **任务描述**：
  在TasksService的add方法定制区域中：
  1. 发布任务时，如果reward_points > 0，调用PointTransactionsService.freezeCompanyPoints冻结积分
  2. 实现joinTask(userId, taskId)方法：承接任务→更新user_has_tasks为accepted→任务状态更新为in_progress→达到max_participants后不再接受新承接
  3. 实现submitWork(userId, taskId, content, attachments)方法：承接者提交成果→join_status=submitted→task_status=reviewing
  4. 实现reviewSubmission(taskId, userId, approved, comment)方法：公司审核→通过则join_status=approved；拒绝则rejected（可重新提交）
  5. 单人任务审核通过后自动触发结算：调用settlePointsToUser→task_status=completed→settlement_status=settled→发送消息通知
  6. 实现状态校验：不允许非法状态转换（如open→completed必须经过in_progress→submitted→reviewing流程）

- **验收标准**：
  1. 发布带积分的任务时积分被正确冻结
  2. 余额不足时无法发布任务
  3. 承接/提交/审核流程状态流转正确
  4. 单人审核通过后积分自动结算到用户
  5. 状态非法转换时返回错误

### TASK-25：实现多人任务分配结算（TaskSettlementsService定制开发）

- **关联需求**：REQ-AI-14
- **优先级**：P1
- **预估复杂度**：L
- **依赖**：TASK-23, TASK-24
- **涉及文件**：
  - **修改文件**：`src/app/services/uctoo/TaskSettlementsService.cj`（定制开发区域）
  - **修改文件**：`src/app/services/uctoo/TasksService.cj`
- **任务描述**：
  1. 多人任务所有承接者审核完成后，创建task_settlements草稿单
  2. 实现setAllocation(settlementId, allocations)方法：设置每个用户的分配比例（总和≤100%）
  3. 实现confirmSettlement(settlementId)方法：公司确认后调用settlePointsMulti执行批量结算
  4. 未分配的积分自动退还公司
  5. 结算完成后所有相关user_has_tasks的join_status更新为completed，task_status=completed

- **验收标准**：
  1. 多人任务审核完成后可创建结算单
  2. 分配比例总和校验（不能超过100%）
  3. 确认结算后各用户按比例收到积分
  4. 未分配积分退还公司
  5. 结算后状态更新正确

### TASK-26：实现超期任务积分退还Crontab定时任务

- **关联需求**：REQ-AI-15
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-23
- **涉及文件**：
  - **新建文件**：`src/app/services/crontab/executor/builtin/AibuilderTaskRefundHandler.cj`（新建BuiltinTaskHandler）
  - **修改文件**：`src/app/services/crontab/SchedulerEngine.cj`（注册新的builtin任务处理器）
- **任务描述**：
  1. 新建AibuilderTaskRefundHandler，实现BuiltinTaskHandler接口
  2. 执行逻辑：查询accept_deadline < NOW()且task_status='open'且points_frozen>0的任务（每次最多处理100条）
  3. 对每个任务执行：调用PointTransactionsService.refundExpiredTaskPoints退还积分→更新task_status='expired'→settlement_status='refunded'→发送消息通知公司创建者
  4. 在SchedulerEngine.initExecutors()中注册：`builtinExecutor.registerBuiltinTask("aibuilder-task-refund", AibuilderTaskRefundHandler())`
  5. crontab任务URI格式：`builtin://aibuilder-task-refund`
  6. 提供crontab记录的INSERT语句（在SQL文件注释中或通过管理界面添加），cron表达式：`0 0 * * * *`（每小时整点执行）
  
- **验收标准**：
  1. Handler正确实现BuiltinTaskHandler接口
  2. 在SchedulerEngine中正确注册
  3. 超期open状态任务的积分被退还
  4. 退还后任务状态更新为expired
  5. 公司收到消息通知
  6. 单次执行限制数量，不会长时间阻塞
  7. 异常任务不影响其他任务处理（单任务异常try-catch）

### TASK-27：积分相关Controller和Route定制开发

- **关联需求**：REQ-AI-12, REQ-AI-13, REQ-AI-14
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-23, TASK-24, TASK-25
- **涉及文件**：
  - **修改文件**：TasksController.cj、UserHasTasksController.cj（添加承接/提交/审核等定制接口）
  - **修改文件**：PointTransactionsController.cj（添加查询流水接口）
  - **修改文件**：TaskSettlementsController.cj（添加分配/确认结算接口）
  - **修改文件**：UctooUserController.cj（添加my-points积分余额查询接口，内部查询user_score表）
  - **修改文件**：CompanyController.cj（添加积分余额查询、充值接口预留）
  - **修改文件**：UserScoreController.cj（crudgen已生成，可能不需要定制API，积分操作通过PointTransactionsService内部调用）
  - **修改文件**：对应Route文件注册新路由
- **任务描述**：
  1. 在TasksController中添加submitWork、reviewSubmission、confirmSettlement、participants等定制接口
  2. 在UserHasTasksController中添加joinTask、leaveTask等接口
  3. 在PointTransactionsController中添加myTransactions、companyTransactions接口
  4. 在TaskSettlementsController中添加setAllocation、confirmSettlement接口
  5. 在UctooUserController中添加myPoints接口（查询当前用户的user_score.total_score）
  6. 在CompanyController中添加getPoints接口（预留rechargePoints接口）
  7. 权限控制：只有任务所属公司的管理员可以审核和结算
- **验收标准**：
  1. 所有API接口可正常调用
  2. 权限校验正确（非公司成员无法审核）
  3. 参数校验正确
  4. 返回格式符合APIResponse统一格式

### TASK-28：前端Pinia-ORM模型扩展积分相关方法

- **关联需求**：REQ-AI-10, REQ-AI-12
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-22（crudweb生成基础模型后）
- **涉及文件**：
  - **修改文件**：`web/src/store/models/uctoo/tasks.ts`（添加submit/review/join等方法）
  - **新建文件**：`web/src/store/models/uctoo/point_transactions.ts`
  - **新建文件**：`web/src/store/models/uctoo/task_settlements.ts`
  - **新建文件**：`web/src/store/models/uctoo/user_score.ts`（crudweb生成基础上扩展）
  - **修改文件**：`web/src/store/models/uctoo/company.ts`（添加getPoints方法）
  - **修改文件**：`web/src/store/models/uctoo/user_has_tasks.ts`（添加join/leave方法）
  - **修改文件**：`web/src/store/models/uctoo/index.ts`（导出新模型）
- **任务描述**：
  按照UMI同构规范创建/扩展Pinia-ORM模型，所有定制方法写在`//#region Human-Code Preservation`区域。
  
  模型中需要添加的方法：
  - tasks.ts: joinTask, submitWork, reviewSubmission, getParticipants, confirmSettlement
  - user_has_tasks.ts: leaveTask
  - point_transactions.ts: getMyTransactions, getCompanyTransactions
  - task_settlements.ts: setAllocation, confirmSettlement
  - user_score.ts: getMyScore（查询当前用户积分）
  - company.ts: getPoints

  注意：用户积分余额通过接口`GET /api/v1/uctoo/user/my-points`获取（该接口在UctooUserController中实现，内部查询user_score表），不直接在前端调用user_score模型的list方法。

- **验收标准**：
  1. 所有模型创建/更新完成
  2. index.ts正确导出
  3. 方法遵循useAxiosRepo(table_name).api().method()模式
  4. TypeScript类型检查通过

---

## Phase 6 - 端到端集成验证

### TASK-21：端到端功能验证

- **关联需求**：所有需求
- **优先级**：P0
- **预估复杂度**：M
- **依赖**：TASK-19, TASK-20, TASK-23, TASK-24, TASK-25, TASK-27
- **任务描述**：
  启动前后端，完整验证：
  1. 游客访问公开页面正常
  2. 用户注册/登录正常
  3. 创建组织→充值积分→发布任务（积分冻结）→承接任务→提交成果→审核通过→积分结算完整链路
  4. 超期任务积分自动退还流程
  5. 多人任务分配比例结算流程
  6. 个人中心/消息/我的任务/我的关注/积分余额数据正确
  7. 公开API和认证API权限控制正确
  8. 积分流水记录完整可查

- **验收标准**：
  1. 端到端流程完整（含积分流转）
  2. 无控制台错误
  3. 无后端报错
  4. 数据一致性正确（计数、关系、积分余额）
  5. 积分流水账实相符
