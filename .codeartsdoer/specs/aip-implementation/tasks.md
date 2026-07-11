# 智能体互联国家标准（GB/Z 185）实现 - 编码任务规划

**版本**: v1.0.0  
**创建日期**: 2026-07-08  
**关联需求**: spec.md v1.2.0  
**关联设计**: design.md v1.0.0  
**技术栈**: 仓颉语言 / cjpm / PostgreSQL / f_orm / crudgen  
**项目根目录**: `D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime`

---

## 任务依赖关系图

```
Phase P0: 本地模式 MVP
  1.1 DDL迁移脚本 ─────────────────────────┐
  1.2 uctoo_user PO/DAO扩展 ────────────────┤
  1.3 agents PO/DAO扩展 ───────────────────┤
  1.4 agent_messages PO/DAO扩展 ────────────┤
  1.5 agent_tasks PO/DAO扩展 ──────────────┤
  1.6 智能体用户组数据初始化 ────────────────┤
                                            ↓
  2.1 AipMode枚举与AipModeManager ─────────┐
  2.2 AgentAuthService ────────────────────┤
  2.3 UctooUserService登录拦截 ────────────┤
                                            ↓
  3.1 AipIdentityService(本地) ────────────┐
  3.2 AipDescriptionService(本地) ─────────┤
  3.3 AipDiscoveryService(本地) ───────────┤
  3.4 AipInteractionService(本地) ─────────┤
  3.5 AipConfigService ────────────────────┤
                                            ↓
  4.1 AipController + AipRoute ────────────┤
  4.2 AipHealthController ─────────────────┤
                                            ↓
  5.1 编译验证 ────────────────────────────┤
  5.2 集成验证 ────────────────────────────┘

Phase P1: 本地模式增强
  P0全部 → 6.1~6.5

Phase P2: 互联模式基础
  P1全部 → 7.1~7.8

Phase P3: 互联模式增强
  P2全部 → 8.1~8.5

Phase P4: 远期规划
  9.1~9.4
```

---

## 关键约定

1. **开发流程**：数据库变更遵循「DDL → crudgen/loadDbInfo → 扩展 Service/Controller」流程
2. **代码区域**：crudgen 生成的代码写在 `//#region AutoCreateCode` 区域内，增量开发代码写在该区域外
3. **日志规范**：统一使用 `magic.log.LogUtils`
4. **命名规范**：数据库列名 snake_case，仓颉代码 camelCase
5. **仓颉代码编写**：使用 cangjie-coder 技能
6. **复用原则**：优先复用和完善已有基础设施，不重新开发

---

## 1. 数据库迁移与模型扩展 [P0]

### 1.1 数据库迁移脚本 [P0 | 必须 | 1h]
- [ ] 创建迁移脚本文件 `scripts/migration/aip_local_mode_v1.sql`
  - 编写 uctoo_user 表新增字段 DDL：`user_type VARCHAR(20) NOT NULL DEFAULT 'human'`、`agent_id UUID DEFAULT NULL`
  - 编写 uctoo_user 表索引：`idx_uctoo_user_user_type`、`idx_uctoo_user_agent_id`（部分索引，仅非空值）
  - 编写 agents 表新增字段 DDL：`aic VARCHAR(128) DEFAULT NULL`、`identity_status VARCHAR(20) NOT NULL DEFAULT 'none'`、`aip_registered_at TIMESTAMPTZ DEFAULT NULL`、`capabilities JSONB DEFAULT NULL`、`default_input_types JSONB DEFAULT NULL`、`default_output_types JSONB DEFAULT NULL`、`discoverable BOOLEAN NOT NULL DEFAULT true`
  - 编写 agents 表索引：`idx_agents_aic`（唯一部分索引）、`idx_agents_identity_status`、`idx_agents_discoverable`
  - 编写 agent_messages 表新增字段 DDL：`aip_session_id UUID DEFAULT NULL`、`aip_message_id VARCHAR(128) DEFAULT NULL`、`sender_role VARCHAR(20) DEFAULT NULL`、`data_items JSONB DEFAULT NULL`
  - 编写 agent_messages 表索引：`idx_agent_messages_aip_session_id`、`idx_agent_messages_aip_message_id`
  - 编写 agent_tasks 表新增字段 DDL：`aip_session_id UUID DEFAULT NULL`、`aip_task_id VARCHAR(128) DEFAULT NULL`、`aip_task_state VARCHAR(20) DEFAULT NULL`
  - 编写 agent_tasks 表索引：`idx_agent_tasks_aip_session_id`、`idx_agent_tasks_aip_task_id`
  - 编写 user_group 表新增智能体用户组数据 INSERT
  - 使用 `BEGIN/COMMIT` 事务包裹，每阶段提供注释形式回滚语句
  - 使用 `IF NOT EXISTS` 保证幂等执行
- **依赖**: 无
- **输入**: design.md §2.3.2 现有表扩展 DDL
- **输出**: `scripts/migration/aip_local_mode_v1.sql`
- **验收**: 在 PostgreSQL 上执行迁移脚本无报错，重复执行幂等，4张表包含新增字段，索引创建成功

### 1.2 uctoo_user 表 PO/DAO 扩展 [P0 | 必须 | 0.5h]
- [ ] 修改 `src/app/models/uctoo/UctooUserPO.cj`，在 `//#region AutoCreateCode` 区域内新增字段：
  - `@ORMField['user_type'] public var userType: String = "human"`
  - `@ORMField['agent_id'] public var agentId: Option<String> = None`
  - 在 `toJsonValue()` 中添加对应字段序列化（key 使用 snake_case）
- [ ] 修改 `src/app/dao/uctoo/UctooUserDAO.cj`，在 `//#endregion AutoCreateCode` 之外新增方法：
  - `findUctooUserByUserType(userType: String, page: Int64, size: Int64): Pagination<UctooUserPO>`：按用户类型分页查询
  - `findUctooUserByAgentId(agentId: String): Option<UctooUserPO>`：按 agent_id 查询用户
- **依赖**: 1.1
- **输入**: design.md §2.3.2 uctoo_user 扩展字段
- **输出**: 修改后的 `UctooUserPO.cj`、`UctooUserDAO.cj`
- **验收**: 编译通过，PO 字段与数据库列名正确映射（user_type → userType, agent_id → agentId），DAO 新方法可执行

### 1.3 agents 表 PO/DAO 扩展 [P0 | 必须 | 1h]
- [ ] 修改 `src/app/models/uctoo/AgentsPO.cj`，在 `//#region AutoCreateCode` 区域内新增字段：
  - `@ORMField['aic'] public var aic: Option<String> = None`
  - `@ORMField['identity_status'] public var identityStatus: String = "none"`
  - `@ORMField['aip_registered_at'] public var aipRegisteredAt: Option<DateTime> = None`
  - `@ORMField['capabilities'] public var capabilities: Option<String> = None`
  - `@ORMField['default_input_types'] public var defaultInputTypes: Option<String> = None`
  - `@ORMField['default_output_types'] public var defaultOutputTypes: Option<String> = None`
  - `@ORMField['discoverable'] public var discoverable: Bool = true`
  - 在 `toJsonValue()` 中添加对应字段序列化
- [ ] 修改 `src/app/dao/uctoo/AgentsDAO.cj`，在 `//#endregion AutoCreateCode` 之外新增方法：
  - `findAgentsByAic(aic: String): Option<AgentsPO>`：按 AIC 查询智能体
  - `findDiscoverableAgentsPage(page: Int64, size: Int64): Pagination<AgentsPO>`：查询可发现的智能体
  - `searchAgentsByNameOrDescription(keyword: String, page: Int64, size: Int64): Pagination<AgentsPO>`：按名称或描述模糊搜索
  - `searchAgentsBySkillKeyword(skillKeyword: String, page: Int64, size: Int64): Pagination<AgentsPO>`：按技能关键词搜索
  - `updateAgentsAic(agentId: String, aic: String, identityStatus: String): Int64`：更新 AIC 和身份状态
  - `updateAgentsAcsFields(agentId: String, capabilities: Option<String>, inputTypes: Option<String>, outputTypes: Option<String>, discoverable: Bool): Int64`：更新 ACS 标准字段
- **依赖**: 1.1
- **输入**: design.md §2.3.2 agents 扩展字段
- **输出**: 修改后的 `AgentsPO.cj`、`AgentsDAO.cj`
- **验收**: 编译通过，7个新字段正确映射，6个新 DAO 方法可执行

### 1.4 agent_messages 表 PO/DAO 扩展 [P0 | 必须 | 0.5h]
- [ ] 修改 `src/app/models/uctoo/AgentMessagesPO.cj`，在 `//#region AutoCreateCode` 区域内新增字段：
  - `@ORMField['aip_session_id'] public var aipSessionId: Option<String> = None`
  - `@ORMField['aip_message_id'] public var aipMessageId: Option<String> = None`
  - `@ORMField['sender_role'] public var senderRole: Option<String> = None`
  - `@ORMField['data_items'] public var dataItems: Option<String> = None`
  - 在 `toJsonValue()` 中添加对应字段序列化
- [ ] 修改 `src/app/dao/uctoo/AgentMessagesDAO.cj`，在 `//#endregion AutoCreateCode` 之外新增方法：
  - `findMessagesByAipSessionId(sessionId: String): ArrayList<AgentMessagesPO>`：按 AIP 会话 ID 查询消息列表
  - `findMessagesByAipSessionIdPage(sessionId: String, page: Int64, size: Int64): Pagination<AgentMessagesPO>`：按 AIP 会话 ID 分页查询
- **依赖**: 1.1
- **输入**: design.md §2.3.2 agent_messages 扩展字段
- **输出**: 修改后的 `AgentMessagesPO.cj`、`AgentMessagesDAO.cj`
- **验收**: 编译通过，4个新字段正确映射，2个新 DAO 方法可执行

### 1.5 agent_tasks 表 PO/DAO 扩展 [P0 | 必须 | 0.5h]
- [ ] 修改 `src/app/models/uctoo/AgentTasksPO.cj`，在 `//#region AutoCreateCode` 区域内新增字段：
  - `@ORMField['aip_session_id'] public var aipSessionId: Option<String> = None`
  - `@ORMField['aip_task_id'] public var aipTaskId: Option<String> = None`
  - `@ORMField['aip_task_state'] public var aipTaskState: Option<String> = None`
  - 在 `toJsonValue()` 中添加对应字段序列化
- [ ] 修改 `src/app/dao/uctoo/AgentTasksDAO.cj`，在 `//#endregion AutoCreateCode` 之外新增方法：
  - `findTasksByAipSessionId(sessionId: String): ArrayList<AgentTasksPO>`：按 AIP 会话 ID 查询任务列表
  - `findTasksByAipSessionIdPage(sessionId: String, page: Int64, size: Int64): Pagination<AgentTasksPO>`：按 AIP 会话 ID 分页查询
  - `updateTaskAipState(taskId: String, aipTaskState: String): Int64`：更新 AIP 任务状态
- **依赖**: 1.1
- **输入**: design.md §2.3.2 agent_tasks 扩展字段
- **输出**: 修改后的 `AgentTasksPO.cj`、`AgentTasksDAO.cj`
- **验收**: 编译通过，3个新字段正确映射，3个新 DAO 方法可执行

### 1.6 智能体用户组数据初始化 [P0 | 必须 | 0.5h]
- [ ] 确认 `scripts/migration/aip_local_mode_v1.sql` 中已包含智能体用户组 INSERT 语句：
  - `INSERT INTO user_group (id, group_name, code, intro, created_at, updated_at) VALUES (gen_random_uuid(), '智能体', 'agents', '智能体专用用户组，用于RBAC权限管理', NOW(), NOW())`
- [ ] 确认 agents 角色（id: a686ff1f-7fb4-48df-8609-2b2d5267c682）在 uctoo_role 表中已存在
- [ ] 若 agents 角色不存在，在迁移脚本中补充 INSERT
- **依赖**: 1.1
- **输入**: design.md §2.5.1 本地模式身份管理
- **输出**: 修改后的 `scripts/migration/aip_local_mode_v1.sql`
- **验收**: 执行迁移后 user_group 表包含 code='agents' 的用户组，uctoo_role 表包含 agents 角色

---

## 2. 核心服务层实现 [P0]

### 2.1 AipMode 枚举与 AipModeManager [P0 | 必须 | 1.5h]
- [ ] 创建 `src/app/services/aip/pkg.cj` 包声明
- [ ] 创建 `src/app/services/aip/model/pkg.cj` 包声明
- [ ] 创建 `src/app/services/aip/model/AipMode.cj`：枚举 `Local | Interconnection`
- [ ] 创建 `src/app/services/aip/model/AcsDescription.cj`：ACS 描述数据类（name, version, description, capabilities, defaultInputTypes, defaultOutputTypes, skills, discoverable）
- [ ] 创建 `src/app/services/aip/model/AcsSkill.cj`：ACS 技能数据类（skillId, skillName, skillDescription, tags, inputTypes, outputTypes）
- [ ] 创建 `src/app/services/aip/model/LocalIdentityRequest.cj`：本地身份注册请求类
- [ ] 创建 `src/app/services/aip/model/LocalIdentityResult.cj`：本地身份注册结果类（agentId, userId, identityStatus, createdAt）
- [ ] 创建 `src/app/services/aip/model/AgentLoginResult.cj`：Agent 登录结果类（accessToken, authType, expiresIn）
- [ ] 创建 `src/app/services/aip/model/LocalDiscoveryRequest.cj`：本地发现请求类（name, skillKeyword, descriptionKeyword, page, limit）
- [ ] 创建 `src/app/services/aip/model/LocalSessionRequest.cj`：本地会话请求类
- [ ] 创建 `src/app/services/aip/model/LocalMessageRequest.cj`：本地消息请求类
- [ ] 创建 `src/app/services/aip/model/SessionResult.cj`：会话结果类
- [ ] 创建 `src/app/services/aip/model/MessageResult.cj`：消息结果类
- [ ] 创建 `src/app/services/aip/model/IdentityInfo.cj`：身份信息结果类
- [ ] 创建 `src/app/services/aip/AipModeManager.cj`：
  - `getCurrentMode(): AipMode`：获取当前运行模式
  - `isInterconnectionMode(): Bool`：判断是否为互联模式
  - `switchToInterconnection(): APIResult<Bool>`：切换到互联模式
  - `switchToLocal(): APIResult<Bool>`：切换到本地模式
  - `checkAcpsAvailability(): Bool`：检查 ACPs 服务可用性
  - `autoDegrade(reason: String): Unit`：自动降级
  - 启动时读取 AIP_MODE 环境变量，默认 auto 模式
  - auto 模式下检查 AIP_REGISTRY_ENDPOINT 和 AIP_CA_ENDPOINT 是否配置且可用
- **依赖**: 无
- **输入**: design.md §2.4.2 AipModeManager 接口、§2.9 模式切换机制
- **输出**: `src/app/services/aip/` 目录下 model 包和 AipModeManager.cj
- **验收**: 编译通过，AipModeManager 可根据配置正确判断运行模式

### 2.2 AgentAuthService 实现 [P0 | 必须 | 1.5h]
- [ ] 创建 `src/app/services/aip/AgentAuthService.cj`
  - `agentAutoLogin(agentId: String): APIResult<AgentLoginResult>`：Agent 无密码自动登录
    1. 根据 agentId 查询 agents 表获取 userId
    2. 根据 userId 查询 uctoo_user 表，验证 user_type='agent'
    3. 若 user_type ≠ 'agent'，返回错误 AUTH-AGENT-001
    4. 验证 agents.status 为运行状态（1）
    5. 生成 JWT access_token，session 中标注 auth_type='agent_auto'
    6. 更新 uctoo_user.access_token
    7. 返回 AgentLoginResult（accessToken, authType='agent_auto', expiresIn=172800）
  - `generateAgentToken(userId: String): String`：生成 Agent 专用 JWT token
    - 复用现有 JWT 生成逻辑，payload 中额外添加 auth_type='agent_auto' 字段
- **依赖**: 1.2, 1.3
- **输入**: design.md §2.5.1 本地模式身份管理，spec.md §5.1.1 业务规则2
- **输出**: `src/app/services/aip/AgentAuthService.cj`
- **验收**: Agent 帐号可通过 agentAutoLogin 获取 JWT token，人类帐号调用此接口返回错误

### 2.3 UctooUserService 登录拦截 [P0 | 必须 | 0.5h]
- [ ] 修改 `src/app/services/uctoo/UctooUserService.cj`，在标准登录方法中增加 user_type 检查：
  - 在密码验证前，查询 uctoo_user 表获取 user_type
  - 若 user_type='agent'，拒绝登录并返回错误"该帐号为智能体专用帐号，不支持密码登录"（错误码 AUTH-AGENT-001）
  - 仅对标准登录接口（用户名+密码）生效，不影响 AgentAuthService 的自动登录
- **依赖**: 1.2
- **输入**: design.md §2.5.1 本地模式身份管理，spec.md §5.1.1 业务规则4
- **输出**: 修改后的 `UctooUserService.cj`
- **验收**: 人类用户尝试使用 agent 帐号密码登录时被拒绝，正常人类帐号登录不受影响

---

## 3. AIP 业务服务实现 [P0]

### 3.1 AipIdentityService 实现（本地模式） [P0 | 必须 | 2h]
- [ ] 创建 `src/app/services/aip/AipIdentityService.cj`
  - `registerLocalIdentity(request: LocalIdentityRequest, creatorId: String): APIResult<LocalIdentityResult>`：创建 Agent 并自动注册本地身份
    1. 生成 Agent ID（UUID）
    2. 在 uctoo_user 表创建用户帐号：username=`agent_{agentId前8位}`，email=`agent_{agentId前8位}@agents.internal`，password=不可登录的随机哈希值，user_type="agent"，agent_id=agentId
    3. 在 user_has_roles 表插入 agents 角色关联
    4. 在 user_has_group 表插入智能体用户组关联
    5. 在 agents 表创建 Agent 记录（关联 userId，设置 identity_status="none"）
    6. 返回 LocalIdentityResult（agentId, userId, identityStatus='none', createdAt）
  - `getIdentityInfo(agentId: String): APIResult<IdentityInfo>`：查询 Agent 身份信息
  - 帐号创建失败时回滚 Agent 创建操作，返回错误码 AIP-LOCAL-001
- **依赖**: 1.2, 1.3, 1.6, 2.1
- **输入**: design.md §2.5.1 本地模式身份管理，spec.md §5.1.1 业务规则1
- **输出**: `src/app/services/aip/AipIdentityService.cj`
- **验收**: 创建 Agent 时自动创建 uctoo_user 帐号、分配角色和用户组

### 3.2 AipDescriptionService 实现（本地模式） [P0 | 必须 | 1.5h]
- [ ] 创建 `src/app/services/aip/AipDescriptionService.cj`
  - `registerLocalDescription(agentId: String, acs: AcsDescription, creatorId: String): APIResult<AgentsPO>`：本地描述注册/更新
    1. 验证 Agent 存在且已有本地身份
    2. 更新 agents 表的 capabilities/default_input_types/default_output_types/discoverable 字段
    3. 将 skills 数组中的技能信息同步到 agent_skills 表
    4. 返回更新后的 Agent 信息
  - `getDescription(agentId: String): APIResult<AcsDescription>`：查询智能体描述
    1. 查询 agents 表获取 Agent 基本信息
    2. 查询 agent_skills 表获取技能列表
    3. 组装 AcsDescription 返回
- **依赖**: 1.3, 2.1
- **输入**: design.md §2.6.1 本地模式描述管理，spec.md §5.2.1 业务规则1-3
- **输出**: `src/app/services/aip/AipDescriptionService.cj`
- **验收**: 描述注册后 agents 表 ACS 字段更新，技能信息同步到 agent_skills 表

### 3.3 AipDiscoveryService 实现（本地模式） [P0 | 必须 | 1.5h]
- [ ] 创建 `src/app/services/aip/AipDiscoveryService.cj`
  - `discoverLocal(request: LocalDiscoveryRequest): APIResult<Pagination<AgentsPO>>`：本地智能体发现
    1. 构建查询条件：discoverable=true 且 deleted_at IS NULL
    2. 若 request.name 非空，添加名称模糊匹配条件
    3. 若 request.descriptionKeyword 非空，添加描述模糊匹配条件
    4. 若 request.skillKeyword 非空，关联 agent_skills 表按技能名称/描述模糊匹配
    5. 执行分页查询，返回匹配的智能体列表
  - `discoverLocalById(agentId: String): APIResult<AgentsPO>`：按 ID 查询单个智能体
- **依赖**: 1.3, 2.1
- **输入**: design.md §2.4.2 AipDiscoveryService 接口，spec.md §5.3.1 业务规则1-4
- **输出**: `src/app/services/aip/AipDiscoveryService.cj`
- **验收**: 本地发现查询返回匹配的智能体列表，discoverable=false 的智能体不出现在结果中

### 3.4 AipInteractionService 实现（本地模式） [P0 | 必须 | 2h]
- [ ] 创建 `src/app/services/aip/AipInteractionService.cj`
  - `createLocalSession(request: LocalSessionRequest, creatorId: String): APIResult<SessionResult>`：创建本地交互会话
    1. 验证请求者 JWT 认证通过
    2. 生成本地会话标识（UUID 格式）
    3. 验证 receiverAgentIds 中的智能体存在且可用
    4. 返回 SessionResult
  - `sendLocalMessage(request: LocalMessageRequest, creatorId: String): APIResult<MessageResult>`：发送本地交互消息
    1. 验证 sessionId 有效
    2. 创建 agent_messages 记录（含 aip_session_id/aip_message_id/sender_role/data_items）
    3. 若有 taskId，更新 agent_tasks 的 aip_session_id
    4. 返回 MessageResult
  - `getSessionMessages(sessionId: String, page: Int64, size: Int64): APIResult<Pagination<AgentMessagesPO>>`：查询会话消息列表
  - `getSessionTasks(sessionId: String): APIResult<ArrayList<AgentTasksPO>>`：查询会话任务列表
  - `closeSession(sessionId: String): APIResult<Bool>`：关闭交互会话
- **依赖**: 1.4, 1.5, 2.1
- **输入**: design.md §2.7.1 本地模式交互，spec.md §5.4.1 业务规则1-7
- **输出**: `src/app/services/aip/AipInteractionService.cj`
- **验收**: 本地交互会话可创建，消息通过 agent_messages 传递并关联 aip_session_id

### 3.5 AipConfigService 实现 [P0 | 必须 | 1h]
- [ ] 创建 `src/app/services/aip/AipConfigService.cj`
  - `getConfig(): APIResult<JsonObject>`：获取 AIP 配置（读取环境变量）
  - `getMode(): APIResult<AipMode>`：获取 AIP 运行模式
  - `switchMode(targetMode: AipMode): APIResult<Bool>`：切换 AIP 运行模式
  - `healthCheckLocal(): APIResult<JsonObject>`：本地模式健康检查
- **依赖**: 2.1
- **输入**: design.md §2.10 配置管理设计，spec.md §5.6.1 业务规则1-3
- **输出**: `src/app/services/aip/AipConfigService.cj`
- **验收**: 可获取 AIP 配置和运行模式，本地模式健康检查返回各组件状态

---

## 4. API 接入层实现 [P0]

### 4.1 AipController + AipRoute [P0 | 必须 | 1.5h]
- [ ] 创建 `src/app/controllers/aip/pkg.cj` 包声明
- [ ] 创建 `src/app/controllers/aip/AipIdentityController.cj`
  - `registerLocal(req, res): POST /api/v1/uctoo/aip/identity/register-local`
  - `agentLogin(req, res): POST /api/v1/uctoo/aip/identity/agent-login`
  - `getIdentity(req, res): GET /api/v1/uctoo/aip/identity/:agentId`
  - 所有接口受 JWT 认证 + RBAC 权限保护
- [ ] 创建 `src/app/controllers/aip/AipDescriptionController.cj`
  - `registerLocal(req, res): POST /api/v1/uctoo/aip/description/register-local`
  - `getDescription(req, res): GET /api/v1/uctoo/aip/description/:agentId`
- [ ] 创建 `src/app/controllers/aip/AipDiscoveryController.cj`
  - `discoverLocal(req, res): POST /api/v1/uctoo/aip/discovery/local`
- [ ] 创建 `src/app/controllers/aip/AipInteractionController.cj`
  - `createLocalSession(req, res): POST /api/v1/uctoo/aip/interaction/session/local`
  - `sendLocalMessage(req, res): POST /api/v1/uctoo/aip/interaction/message/local`
  - `getSession(req, res): GET /api/v1/uctoo/aip/interaction/session/:sessionId`
  - `getSessionMessages(req, res): GET /api/v1/uctoo/aip/interaction/session/:sessionId/messages/:limit/:page`
  - `closeSession(req, res): POST /api/v1/uctoo/aip/interaction/session/:sessionId/close`
- [ ] 创建 `src/app/controllers/aip/AipConfigController.cj`
  - `getConfig(req, res): GET /api/v1/uctoo/aip/config`
  - `getMode(req, res): GET /api/v1/uctoo/aip/config/mode`
  - `switchMode(req, res): POST /api/v1/uctoo/aip/config/mode/switch`
- [ ] 创建 `src/app/routes/aip/pkg.cj` 包声明
- [ ] 创建 `src/app/routes/aip/AipRoute.cj`：注册所有 AIP 路由
- [ ] 修改路由注册入口，注册 AipRoute
- **依赖**: 3.1~3.5
- **输入**: design.md §2.2.2 接口清单，uctoo-v4-api-specification
- **输出**: `src/app/controllers/aip/` 目录下5个 Controller、`src/app/routes/aip/AipRoute.cj`
- **验收**: 所有 AIP API 可通过 HTTP 请求正确访问，受 JWT 认证保护

### 4.2 AipHealthController [P0 | 必须 | 0.5h]
- [ ] 创建 `src/app/controllers/aip/AipHealthController.cj`
  - `healthLocal(req, res): GET /api/v1/uctoo/aip/health/local`：本地模式健康检查
  - 返回 JSON：`{"status": "healthy", "mode": "local", "components": {"database": "healthy", "localDiscovery": "healthy", "localInteraction": "healthy"}}`
- [ ] 在 AipRoute.cj 中注册健康检查路由
- **依赖**: 3.5, 4.1
- **输入**: design.md §2.2.2 健康检查接口
- **输出**: `src/app/controllers/aip/AipHealthController.cj`，修改 `AipRoute.cj`
- **验收**: GET /api/v1/uctoo/aip/health/local 返回正确的健康状态 JSON

---

## 5. 编译验证与集成测试 [P0]

### 5.1 编译验证 [P0 | 必须 | 0.5h]
- [ ] 执行 `cjpm build` 确保所有新增和修改文件编译通过
  - 验证 PO 文件中新增字段的 @ORMField 注解正确
  - 验证 DAO 文件中新增方法的 SQL 语法正确
  - 验证 Service 文件中 import 引用完整
  - 验证 Controller 文件中路由处理方法签名正确
  - 验证 Route 文件中路由注册无冲突
- **依赖**: 4.1, 4.2
- **输入**: 全部新增和修改文件
- **输出**: 编译通过确认
- **验收**: `cjpm build` 成功，无错误输出

### 5.2 集成验证 [P0 | 必须 | 2h]
- [ ] 执行数据库迁移脚本，验证表结构变更正确
- [ ] 验证本地身份注册流程：创建 Agent → 自动创建 uctoo_user 帐号 → 分配角色和用户组
- [ ] 验证 Agent 自动登录流程：agentLogin → 获取 JWT token → 使用 token 调用 AIP 接口
- [ ] 验证登录拦截：agent 帐号密码登录 → 返回 AUTH-AGENT-001 错误
- [ ] 验证本地描述管理：注册描述 → agents 表 ACS 字段更新 → agent_skills 表技能同步
- [ ] 验证本地智能体发现：按名称/技能搜索 → discoverable=false 的智能体不出现在结果中
- [ ] 验证本地交互：创建会话 → 发送消息 → agent_messages 包含 aip_session_id → 查询会话 → 关闭会话
- [ ] 验证健康检查：GET /api/v1/uctoo/aip/health/local → 返回正确健康状态
- **依赖**: 5.1
- **输入**: 全部 P0 功能
- **输出**: 集成验证报告
- **验收**: 所有 P0 功能场景验证通过

---

## 6. 本地模式增强 [P1] — ✅ 已完成

### 6.1 RBAC 权限隔离规则完善 [P1 | 应当 | 1h] — ✅
- [x] 在 RequirePermissionMiddleware 中将 AIP 健康检查和 agent-login 设为公开路由
- [x] 创建 `scripts/migration/aip_rbac_permissions_v1.sql`：为 agents 角色添加 AIP 路由权限
- **依赖**: 3.1, 4.1
- **验收**: Agent 帐号仅能访问授权范围内的 API

### 6.2 本地模式健康检查增强 [P1 | 应当 | 0.5h] — ✅
- [x] 增强 AipConfigService.healthCheckLocal()：检查数据库连接、agent数量、可发现agent数量、AIP消息数量
- **依赖**: 4.2
- **验收**: 健康检查返回各组件详细状态

### 6.3 Agent 帐号管理接口 [P1 | 应当 | 1h] — ✅
- [x] 在 AipIdentityController 中增加：listIdentities / disableAgent / enableAgent
- [x] 在 AipIdentityService 中增加：禁用/启用 Agent 时同步更新 agents.status 和 uctoo_user.status
- [x] 在 AipRoute 中注册新路由
- **依赖**: 3.1, 4.1
- **验收**: Agent 帐号可查询、禁用、启用，状态同步更新

### 6.4 技能与 ACS skills 双向映射完善 [P1 | 应当 | 1.5h] — ✅
- [x] 创建 `src/app/services/aip/AgentSkillAcsMapper.cj`：AgentSkillsPO ↔ AcsSkill 双向转换
- [x] 在 AipDescriptionService.getDescription() 中查询技能列表并转换为 ACS 格式
- **依赖**: 3.2
- **验收**: ACS 技能可同步到 agent_skills 表，agent_skills 表可转换为 ACS 格式

### 6.5 本地交互消息 GB/Z 185.6 格式校验 [P1 | 应当 | 1h] — ✅
- [x] 创建 `src/app/services/aip/AipMessageValidator.cj`：校验 senderRole/dataItems/sessionId 格式
- [x] 在 AipInteractionService.sendLocalMessage() 中调用校验
- [x] 校验失败返回错误码 AIP-LOCAL-INTER-003
- **依赖**: 3.4
- **验收**: 不符合 GB/Z 185.6 参考结构的消息被拒绝

---

## 7. 互联模式基础 [P2] — ✅ 已完成

### 7.1 AIP 独立新建8张表 [P2 | 应当 | 3h] — ✅
- [x] 创建迁移脚本 `scripts/migration/aip_interconnection_v1.sql`：8张表 DDL + 索引
- [x] 使用 crudgen 生成8张表的标准 CRUD 模块（PO + DAO）
- **依赖**: P0 全部完成
- **验收**: 迁移脚本执行成功，8张表创建成功，CRUD 模块编译通过

### 7.2 ACPs 注册服务适配器 [P2 | 应当 | 3h] — ✅
- [x] 创建 `src/app/services/aip/acps/AcpsRegistryAdapter.cj`：submitRegistration / submitUpdate / submitRevocation / submitDescription / submitPublish / checkConnectivity
- [x] 创建适配器所需的请求/响应数据类
- **依赖**: 7.1
- **验收**: 适配器可连接 ACPs 注册服务，提交注册请求并返回结果

### 7.3 CA 服务适配器 [P2 | 应当 | 2h] — ✅
- [x] 创建 `src/app/services/aip/acps/AcpsCaAdapter.cj`：requestCertificate / verifyCertificate / revokeCertificate / checkConnectivity
- **依赖**: 7.1
- **验收**: 适配器可连接 ACPs CA 服务，申请和验证证书

### 7.4 互联身份注册/更新/注销 [P2 | 应当 | 2h] — ✅
- [x] 扩展 AipIdentityService：registerInterconnectionIdentity / updateIdentity / lockIdentity / unlockIdentity / revokeIdentity
- [x] 扩展 AipIdentityController：register-interconnection / update / lock / unlock / revoke
- [x] 在 AipRoute 中注册新路由
- **依赖**: 7.2, 7.3
- **验收**: 互联身份注册成功后 aip_agent_identity 表有记录，agents.aic 更新

### 7.5 互联描述注册/发布 [P2 | 应当 | 2h] — ✅
- [x] 扩展 AipDescriptionService：registerInterconnectionDescription / publishDescription / updateInterconnectionDescription
- [x] 扩展 AipDescriptionController：register-interconnection / publish / update
- **依赖**: 7.2, 7.4
- **验收**: 互联描述注册成功后 aip_agent_description 表有记录，发布后 ACPs 发现服务可查询

### 7.6 ACPs 发现服务适配器 [P2 | 应当 | 2h] — ✅
- [x] 创建 `src/app/services/aip/acps/AcpsDiscoveryAdapter.cj`：discover / checkConnectivity
- **依赖**: 7.1
- **验收**: 适配器可连接 ACPs 发现服务，提交发现请求并返回结果

### 7.7 互联智能体发现 [P2 | 应当 | 1h] — ✅
- [x] 扩展 AipDiscoveryService：discoverInterconnection / getDiscoveryCache
- [x] 扩展 AipDiscoveryController：interconnection / cache
- **依赖**: 7.6
- **验收**: 互联发现查询返回跨系统智能体列表，结果缓存到 aip_discovery_cache 表

### 7.8 互联交互会话/消息/任务 [P2 | 应当 | 3h] — ✅
- [x] 扩展 AipInteractionService：createInterconnectionSession / sendInterconnectionMessage / closeInterconnectionSession
  - 消息双写到 aip_interaction_message 和 agent_messages
  - 任务关联通过 aip_session_id 实现
- [x] 扩展 AipInteractionController：session/interconnection / message/interconnection
- **依赖**: 7.1, 7.4
- **验收**: 互联交互会话可创建，消息双写到 AIP 表和现有表

---

## 8. 互联模式增强 [P3]

### 8.1 MQ 消息分发适配器 [P3 | 可以 | 3h]
- [ ] 创建 `src/app/services/aip/acps/AcpsMqAdapter.cj`：createGroup / publishMessage / subscribeGroup / unsubscribeGroup
- [ ] 在 AipInteractionService 中集成 MQ 群组交互
- **依赖**: 7.8
- **验收**: 群组交互通过 MQ 消息分发，ACL 校验生效

### 8.2 互联模式健康检查 [P3 | 可以 | 1h]
- [ ] 扩展 AipHealthController：healthInterconnection，检查各 ACPs 服务连通性
- **依赖**: 7.2~7.8
- **验收**: 互联模式健康检查返回各 ACPs 服务连通性状态

### 8.3 AIC 合法性验证 [P3 | 可以 | 1h]
- [ ] 创建 `src/app/services/aip/AicValidator.cj`：validate / parseAic
- [ ] 在 AipIdentityService 中集成 AIC 验证
- **依赖**: 7.4
- **验收**: 输入 AIC 后返回格式是否合法及解析结果

### 8.4 运行时模式切换（升级/降级） [P3 | 可以 | 2h]
- [ ] 完善 AipModeManager 的运行时模式切换逻辑：升级到互联模式 / 降级到本地模式 / 定期检查 ACPs 服务可用性
- **依赖**: 7.4, 7.5, 7.7
- **验收**: ACPs 服务不可用时自动降级为本地模式，恢复后可升级回互联模式

### 8.5 发现缓存管理 [P3 | 可以 | 1h]
- [ ] 扩展 AipDiscoveryService：cleanExpiredCache / refreshCache
- [ ] 可选：通过 Crontab 定时任务定期清理过期缓存
- **依赖**: 7.7
- **验收**: 过期缓存可清理，指定缓存可刷新

---

## 9. 远期规划 [P4]

### 9.1 跨注册中心的联邦发现 [P4 | 远期]
- [ ] 支持 AIP 发现服务跨注册中心联邦查询
- **依赖**: P3 全部完成

### 9.2 智能体监控协议（AMP） [P4 | 远期]
- [ ] 实现 GB/Z 185 智能体监控协议
- **依赖**: P3 全部完成

### 9.3 数据同步协议（DSP） [P4 | 远期]
- [ ] 实现 GB/Z 185 数据同步协议
- **依赖**: P3 全部完成

### 9.4 ACPs 协议版本升级支持 [P4 | 远期]
- [ ] 支持 ACPs 协议从 v2.1.0 平滑升级到新版本
- **依赖**: P3 全部完成

---

## 需求覆盖追踪

| spec.md 核心能力 | P0 任务 | P1 任务 | P2 任务 | P3 任务 | 覆盖状态 |
|-----------------|---------|---------|---------|---------|----------|
| 5.1 智能体身份管理（本地） | 1.2, 1.3, 1.6, 2.2, 2.3, 3.1 | 6.1, 6.3 | | | ✅ |
| 5.1 智能体身份管理（互联） | | | 7.2, 7.3, 7.4 | 8.3, 8.4 | ✅ |
| 5.2 智能体描述管理（本地） | 1.3, 3.2 | 6.4 | | | ✅ |
| 5.2 智能体描述管理（互联） | | | 7.5 | | ✅ |
| 5.3 智能体发现（本地） | 1.3, 3.3 | | | | ✅ |
| 5.3 智能体发现（互联） | | | 7.6, 7.7 | 8.5 | ✅ |
| 5.4 智能体交互（本地） | 1.4, 1.5, 3.4 | 6.5 | | | ✅ |
| 5.4 智能体交互（互联） | | | 7.8 | 8.1 | ✅ |
| 5.5 智能体工具调用（本地） | 复用MCP | | | | ✅ |
| 5.5 智能体工具调用（互联） | | | | 待规划 | ⏳ |
| 5.6 AIP 配置与管理（本地） | 2.1, 3.5 | 6.2 | | | ✅ |
| 5.6 AIP 配置与管理（互联） | | | | 8.2, 8.4 | ✅ |