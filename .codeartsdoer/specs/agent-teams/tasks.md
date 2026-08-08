# AgentTeams 分层协作架构 - 任务清单

## 开发规范

### 仓颉代码开发
- 所有仓颉代码(.cj文件)的编写必须使用 **cangjie-coder 技能**，遵循查阅文档→检索代码→编辑适配→写入文件的四步工作流程
- 编写代码前，必须先在项目中查找确认正确的仓颉代码作为参考
- 仓颉代码必须符合 CangjieMagic 框架和 V4 模块的约定和模式
- 数据库列名使用 snake_case，仓颉代码使用 camelCase
- crudgen 生成的代码写在 `//#region AutoCreateCode` 区域内，增量开发代码写在该区域外

### 数据库结构变更流程（uctoo-v4 通用模块开发流程）
- 涉及数据库结构变更和新增时，必须遵循以下流程：
  1. **[自动化]** 在 `sql/incremental/` 目录生成数据库DDL脚本
  2. **[人工操作]** 通知人工执行数据库变更（执行DDL）
  3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表，使用 `crudgen` 生成标准CRUD模块（Model/DAO/Service/Controller/Route），使用 `crudweb` 生成Web管理界面
  4. **[自动化]** 基于生成的CRUD模块进行迭代开发（定制代码写在 `//#region AutoCreateCode` 区域外）

---

## 任务总览

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 |
|--------|---------|--------|---------|------|
| AT-T001 | 数据库表设计与创建 | P0 | 0.5天 | 无 | ✅已完成 |
| AT-T002 | TeamConfig YAML配置解析器 | P0 | 1天 | 无 | ✅已完成 |
| AT-T003 | ManagerGroup核心实现 | P0 | 2天 | AT-T001 | ✅已完成 |
| AT-T004 | TeamMessenger分层消息传递 | P0 | 1天 | AT-T003 | ✅已完成 |
| AT-T005 | TeamManager生命周期管理 | P0 | 1天 | AT-T002, AT-T003 | ✅已完成 |
| AT-T006 | AgentTeams DSL扩展 | P0 | 0.5天 | AT-T003 | ✅已完成 |
| AT-T007 | CRUD模块生成与API实现 | P0 | 1天 | AT-T001 | ✅已完成(crudgen已生成) |
| AT-T008 | 集成测试与Demo验证 | P0 | 1天 | AT-T001~T007 | ⏳待完成 |

---

## 仓颉规范合规性要求（来自cangjie-compliance-review.md）

- [ ] TeamManager/TeamMessenger类添加`public`修饰符（需被继承的使用`open public`）
- [ ] 方法返回值使用`Option<T>`（DAO层）或`APIResult<T>`（Service层）包装可能失败的操作
- [ ] PlantUML数据模型中`JsonObject`改为`JsonValue`（JSONB字段对应JsonValue类型）
- [ ] PO类补充`@DataAssist[fields]`和`@QueryMappersGenerator`注解
- [ ] DAO接口使用`@DAO`注解并继承`RootDAO`
- [ ] Service方法统一返回`APIResult<T>`
- [ ] 补充标准包名：`magic.app.models.uctoo`、`magic.app.dao.uctoo`、`magic.app.services.uctoo`等

---

## AT-T001: 数据库表设计与创建

**描述**: 创建 agent_teams 和 agent_team_members 数据库表，遵循 uctoo-v4 数据库设计规范。

**子任务**:
1. **[自动化]** 编写 DDL 文件放置在 `sql/incremental/` 目录
2. **[人工操作]** 通知人工执行数据库变更
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表
4. **[人工操作]** 人工使用 `crudgen` 生成 Model/DAO/Service/Controller/Route 骨架，使用 `crudweb` 生成Web管理界面

**验收标准**:
- [x] agent_teams 表创建成功，包含所有必要字段
- [x] agent_group_members 表创建成功，外键约束正确
- [x] 索引创建成功
- [x] db_info 表已更新

---

## AT-T002: TeamConfig YAML配置解析器

**描述**: 实现 agent_teams.yaml 配置文件的解析器，将YAML配置转换为 TeamConfig 对象。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义 TeamConfig 数据类（TeamConfig、AgentRoleConfig、LeaderConfig）
2. 实现 YamlTeamConfigParser 解析器
3. 支持从文件路径和字符串两种方式加载配置
4. 实现配置校验（必填字段检查、角色类型校验、技能存在性校验）
5. 编写单元测试

**关键文件**:
- `src/agent_group/team_config.cj` - TeamConfig 数据类
- `src/agent_group/yaml_team_config_parser.cj` - YAML解析器

**验收标准**:
- [x] agent_teams.yaml 可正确解析为 TeamConfig 对象
- [x] 配置校验能检测出缺失字段和无效角色类型
- [x] 支持从文件和字符串两种方式加载
- [ ] 单元测试覆盖正常和异常场景

---

## AT-T003: ManagerGroup核心实现

**描述**: 实现 ManagerGroup 类，支持 Manager-TeamLeader-Worker 三层协作架构。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义 ManagerGroup 类，继承 AgentGroup 接口
2. 实现 Manager 角色的任务分解逻辑（委托给 LLM）
3. 实现 TeamLeader 角色的子任务分配逻辑
4. 实现 Worker 角色的任务执行逻辑（复用 SubAgentTool）
5. 实现三层 Agent 的创建和组装
6. 实现 chat 方法：Manager 接收任务→分解→分配→聚合→返回
7. 实现结果聚合框架

**关键文件**:
- `src/agent_group/manager_group.cj` - ManagerGroup 主类
- `src/agent_group/team_agent_factory.cj` - 团队Agent工厂

**验收标准**:
- [x] ManagerGroup 可正确创建三层 Agent 组
- [x] Manager 正确分解任务并分配给 TeamLeader
- [x] TeamLeader 正确管理 Worker 并聚合结果
- [x] Worker 执行任务并返回结果
- [x] 结果聚合框架正确工作

---

## AT-T004: TeamMessenger分层消息传递

**描述**: 实现分层消息传递机制，支持 Manager↔TeamLeader↔Worker 间的结构化通信。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义 TeamMessage 数据类（sender、receiver、type、payload、timestamp）
2. 定义 MessageType 枚举（TASK_ASSIGN、RESULT_REPORT、STATUS_UPDATE、ERROR_REPORT）
3. 实现 TeamMessenger 类
4. 实现 send 方法（点对点消息）
5. 实现 broadcast 方法（按角色广播）
6. 实现 request 方法（请求-响应模式）
7. 与 EventHandlerManager 集成

**关键文件**:
- `src/agent_group/team_message.cj` - 消息定义
- `src/agent_group/team_messenger.cj` - 消息传递器

**验收标准**:
- [x] TeamMessage 格式标准化
- [x] 点对点消息正确传递
- [x] 按角色广播正确工作
- [x] 请求-响应模式正确工作
- [x] 与 EventHandlerManager 集成正常

---

## AT-T005: TeamManager生命周期管理

**描述**: 实现团队生命周期管理器，支持团队的创建、运行、暂停、销毁。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现 TeamManager 类
2. 实现 createTeam 方法（从 TeamConfig 创建 ManagerGroup）
3. 实现 destroyTeam 方法
4. 实现 addWorker / removeWorker 方法（动态调整）
5. 实现 getTeamStatus / listTeams 方法
6. 与 AgentTeamService 集成（数据库持久化）
7. 实现团队状态机（Draft→Initializing→Ready→Running→Paused→Completed/Failed）

**关键文件**:
- `src/agent_group/team_manager.cj` - 团队管理器

**验收标准**:
- [x] 从 TeamConfig 正确创建 ManagerGroup 实例
- [x] 团队状态机正确流转
- [x] 动态添加/移除 Worker 正确工作
- [x] 团队状态持久化到数据库
- [x] 团队列表查询正确

---

## AT-T006: AgentTeams DSL扩展

**描述**: 扩展 AgentGroup DSL，新增 @agentTeams 宏和对应运算符。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 在 AgentCollaboration 接口中新增 `~` 运算符（创建 ManagerGroup）
2. 实现 manager <= [leaders] <= [workers] 语法
3. 在 AGENTS.md 中支持 agent_teams 配置声明
4. 编写 DSL 使用示例

**关键文件**:
- `src/agent_group/agent_group_dsl.cj` - 扩展DSL

**验收标准**:
- [x] `~` 运算符正确创建 ManagerGroup
- [x] AGENTS.md 中的 agent_teams 配置正确解析
- [ ] DSL 使用示例可运行

---

## AT-T007: CRUD模块生成与API实现

**描述**: 基于crudgen生成的标准CRUD模块，迭代开发团队执行相关API。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 使用 crudgen 生成 AgentTeamPO 和 AgentTeamMemberPO 的 CRUD 代码
2. 实现 AgentTeamService 扩展方法：
   - executeTeam(task) - 执行团队任务
   - pauseTeam() - 暂停团队
   - resumeTeam() - 恢复团队
3. 实现 AgentTeamController 和 Route
4. 遵循 uctoo-v4 API 规范

**关键文件**:
- `src/app/models/uctoo/AgentTeamPO.cj`
- `src/app/dao/uctoo/AgentTeamDAO.cj`
- `src/app/services/uctoo/AgentTeamService.cj`
- `src/app/controllers/uctoo/agent_teams/AgentTeamController.cj`
- `src/app/routes/uctoo/agent_teams/AgentTeamRoute.cj`

**验收标准**:
- [ ] 标准 CRUD API 可正常调用
- [ ] executeTeam API 正确触发团队执行
- [ ] pauseTeam/resumeTeam API 正确工作
- [ ] API 遵循 uctoo-v4 规范

---

## AT-T008: 集成测试与Demo验证

**描述**: 编写集成测试，验证 AgentTeams 分层协作架构的完整功能。

**子任务**:
1. 编写 ManagerGroup 集成测试
2. 编写 TeamMessenger 集成测试
3. 编写 TeamManager 生命周期测试
4. 编写 API 端到端测试
5. 创建 Demo 场景：简单的三层团队执行任务

**验收标准**:
- [ ] 所有集成测试通过
- [ ] Demo 可重复运行
- [ ] 三层 Agent 协作正确
- [ ] 消息传递正确
- [ ] 团队生命周期管理正确