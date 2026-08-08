# 技能自进化闭环 - 任务清单

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

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 | 状态 |
|--------|---------|--------|---------|------|------|
| SE-T001 | 数据库表设计与创建 | P0 | 0.5天 | 无 | ⏳待完成 |
| SE-T002 | SkillUsageStats CRUD模块 | P0 | 0.5天 | SE-T001 | ⏳待完成 |
| SE-T003 | SkillUsageTracker使用追踪器 | P0 | 1天 | SE-T002 | ⏳待完成 |
| SE-T004 | SkillStateTransitionEngine状态流转引擎 | P0 | 1.5天 | SE-T002 | ⏳待完成 |
| SE-T005 | SkillCuratorYamlParser规则解析器 | P0 | 1天 | 无 | ⏳待完成 |
| SE-T006 | SkillCuratorHandler Curator处理器 | P0 | 1.5天 | SE-T004, SE-T005 | ⏳待完成 |
| SE-T007 | Curator注册为Crontab任务 | P0 | 0.5天 | SE-T006 | ⏳待完成 |
| SE-T008 | SkillScriptGenerator脚本动态生成 | P1 | 1.5天 | SE-T002 | ⏳待完成 |
| SE-T009 | SKILL.md扩展字段解析 | P0 | 1天 | 无 | ⏳待完成 |
| SE-T010 | API接口与路由实现 | P0 | 1天 | SE-T003, SE-T004 | ⏳待完成 |
| SE-T011 | 集成测试与验证 | P0 | 1天 | SE-T001~T010 | ⏳待完成 |

---

## SE-T001: 数据库表设计与创建

**描述**: 创建 skill_usage_stats 数据库表，存储技能使用统计和状态信息。

**子任务**:
1. **[自动化]** 编写DDL文件放置在 `sql/incremental/` 目录
2. **[人工操作]** 通知人工执行数据库变更
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表
4. **[人工操作]** 人工使用 `crudgen` 生成标准CRUD骨架，使用 `crudweb` 生成Web管理界面

**关键文件**:
- `sql/incremental/skill_usage_stats.sql`

**验收标准**:
- [ ] skill_usage_stats表创建成功
- [ ] 唯一索引idx_skill_usage_stats_name创建成功
- [ ] 状态索引idx_skill_usage_stats_state创建成功
- [ ] crudgen生成CRUD模块成功

---

## SE-T002: SkillUsageStats CRUD模块

**描述**: 基于crudgen生成的标准CRUD模块，迭代开发技能使用统计服务。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 确认crudgen生成的SkillUsageStatsPO/DAO/Service/Controller/Route
2. 扩展SkillUsageStatsService增加统计相关方法
3. 实现incrementUsage/incrementView/incrementModify方法
4. 实现getBySkillName方法（按技能名查询）
5. 实现getTopUsedSkills方法（按使用频率排序）

**关键文件**:
- `src/app/models/uctoo/SkillUsageStatsPO.cj`（crudgen生成）
- `src/app/dao/uctoo/SkillUsageStatsDAO.cj`（crudgen生成）
- `src/app/services/uctoo/SkillUsageStatsService.cj`（crudgen生成+扩展）

**验收标准**:
- [ ] 标准CRUD API可正常调用
- [ ] incrementUsage/incrementView/incrementModify正确递增计数
- [ ] getBySkillName按技能名正确查询
- [ ] getTopUsedSkills按使用频率正确排序

---

## SE-T003: SkillUsageTracker使用追踪器

**描述**: 实现技能使用追踪器，拦截技能执行事件并更新使用统计。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义SkillUsageType枚举（Use/View/Modify）
2. 实现SkillUsageTracker类
3. recordUsage方法：记录使用事件，更新统计和operate_log
4. 与ProgressiveSkillLoader集成，在技能加载时触发View事件
5. 与CompositionExecutor集成，在技能执行时触发Use事件
6. 与skill-creator技能集成，在技能修改时触发Modify事件

**关键文件**:
- `src/skill/evolution/skill_usage_tracker.cj`
- `src/skill/evolution/skill_usage_type.cj`

**验收标准**:
- [ ] 技能使用事件正确拦截
- [ ] use_count/view_count/modify_count正确递增
- [ ] lastActivityAt正确更新
- [ ] operate_log中正确记录module="skill"

---

## SE-T004: SkillStateTransitionEngine状态流转引擎

**描述**: 实现技能状态自动流转引擎，基于使用频率自动转换active→stale→archived。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义SkillState枚举（Active/Stale/Archived）
2. 定义SkillTransitionConfig配置类（staleThresholdDays/archivedThresholdDays/enabled）
3. 实现SkillStateTransitionEngine
4. checkAndTransition方法：检查单个技能并执行流转
5. checkAllActiveSkills方法：批量检查所有active/stale技能
6. isPinned方法：检查技能是否固定（固定技能豁免）
7. 流转规则从YAML配置读取（默认30天→stale，90天→archived）
8. 流转时更新SKILL.md的state和last_activity_at字段

**关键文件**:
- `src/skill/evolution/skill_state_transition_engine.cj`
- `src/skill/evolution/skill_state.cj`
- `src/skill/evolution/skill_transition_config.cj`

**验收标准**:
- [ ] active→stale流转正确（超过stale阈值天数）
- [ ] stale→archived流转正确（超过archived阈值天数）
- [ ] Pinned技能豁免流转
- [ ] SKILL.md的state字段正确更新
- [ ] 流转规则可通过配置调整

---

## SE-T005: SkillCuratorYamlParser规则解析器

**描述**: 实现Curator审查规则的YAML配置解析器。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义CuratorRuleSet数据类（schedule/rules/scope）
2. 定义CuratorRule数据类（name/type/condition/action/enabled）
3. 定义CuratorScope数据类（onlyAgentCreated/excludePinned/targetStates）
4. 实现YAML解析器，支持curator_rules.yaml格式
5. 支持条件表达式解析（last_activity_at > 30d, use_count < 3等）
6. 编写默认curator_rules.yaml配置文件

**关键文件**:
- `src/skill/evolution/skill_curator_yaml_parser.cj`
- `src/skill/evolution/curator_models.cj`
- `config/curator_rules.yaml`

**验收标准**:
- [ ] curator_rules.yaml正确解析
- [ ] CuratorScope.onlyAgentCreated正确识别
- [ ] 条件表达式正确解析
- [ ] 默认配置文件格式正确

---

## SE-T006: SkillCuratorHandler Curator处理器

**描述**: 实现Curator审查处理器，实现BuiltinTaskHandler接口，定期审查Agent创建的技能。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现SkillCuratorHandler，继承BuiltinTaskHandler接口
2. handle方法：读取审查规则→扫描Agent创建的技能→执行审查→生成报告
3. 状态检查规则：调用SkillStateTransitionEngine
4. 统计检查规则：读取SkillUsageStatsService，标记低频使用技能
5. 脚本检查规则：检查scripts声明是否已生成，未生成则触发SkillScriptGenerator
6. 严格不变量保证：只触碰creator_type='agent'的技能
7. 严格不变量保证：永不自动删除，只归档（transition_to_archived）
8. 审查结果写入operate_log

**关键文件**:
- `src/skill/evolution/skill_curator_handler.cj`

**验收标准**:
- [ ] Curator正确注册为BuiltinTaskHandler
- [ ] 只审查Agent创建的技能（creator_type='agent'）
- [ ] 永不自动删除技能（只归档）
- [ ] 状态流转检查正确触发
- [ ] 低频使用技能正确标记
- [ ] 审查报告正确生成

---

## SE-T007: Curator注册为Crontab任务

**描述**: 将SkillCuratorHandler注册到SchedulerEngine，通过Crontab定期触发。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 在SchedulerEngine.initExecutors()中注册SkillCuratorHandler到BuiltinExecutor
2. 在crontab_init.sql中插入builtin:skill-curator定时任务
3. 默认cron表达式从curator_rules.yaml的schedule字段读取
4. 支持通过CrontabSchedulerService手动触发
5. 支持通过API手动触发Curator审查

**关键文件**:
- `src/app/services/crontab/SchedulerEngine.cj`（修改initExecutors）
- `sql/crontab_init.sql`（新增skill-curator任务）

**验收标准**:
- [ ] skill-curator正确注册到BuiltinExecutor
- [ ] Crontab定期触发Curator审查
- [ ] 手动触发API正常工作
- [ ] CrontabSchedulerService可管理Curator任务

---

## SE-T008: SkillScriptGenerator脚本动态生成

**描述**: 实现技能脚本动态生成器，在首次使用时自动生成SKILL.md中声明的脚本。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义ScriptDeclaration数据类（name/description/language/generationStrategy/capabilities/version）
2. 实现SkillScriptGenerator
3. generateIfMissing方法：检查脚本是否存在，不存在则生成
4. generateAllMissing方法：批量生成所有声明的脚本
5. 支持多种generationStrategy：llm-generate（LLM生成）、template（模板填充）、copy（从参考路径复制）
6. 生成的脚本在WASM沙箱中执行验证
7. 脚本与技能版本绑定，记录在script_generation_status JSONB字段
8. 与SkillUsageTracker集成，首次使用时触发脚本生成

**关键文件**:
- `src/skill/evolution/skill_script_generator.cj`
- `src/skill/evolution/script_declaration.cj`

**验收标准**:
- [ ] 首次使用时自动检测scripts声明
- [ ] 脚本文件正确生成到scripts/目录
- [ ] 生成的脚本可在WASM沙箱中执行
- [ ] 脚本版本与技能版本正确绑定
- [ ] script_generation_status正确记录生成状态

---

## SE-T009: SKILL.md扩展字段解析

**描述**: 扩展SkillManifest和ProgressiveSkillLoader，支持state/last_activity_at/pinned/scripts字段。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 扩展SkillManifest增加state/last_activity_at/pinned/scripts字段
2. 修改ProgressiveSkillLoader解析SKILL.md时读取新字段
3. 修改YamlFrontmatter解析器支持scripts数组
4. state字段默认值为active
5. pinned字段默认值为false
6. scripts字段解析为Array<ScriptDeclaration>
7. 加载时同步到skill_usage_stats表（如不存在则创建）

**关键文件**:
- `src/skill/domain/models/skill_manifest.cj`（扩展）
- `src/skill/application/progressive_skill_loader.cj`（扩展）
- `src/skill/domain/models/yaml_frontmatter.cj`（扩展）

**验收标准**:
- [ ] SKILL.md的state字段正确解析
- [ ] SKILL.md的pinned字段正确解析
- [ ] SKILL.md的scripts声明正确解析为ScriptDeclaration数组
- [ ] 加载时自动同步到skill_usage_stats表
- [ ] 向后兼容（无新字段的SKILL.md正常加载）

---

## SE-T010: API接口与路由实现

**描述**: 实现技能使用统计和状态流转的RESTful API。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. SkillUsageStatsController扩展方法
2. GET /api/v1/uctoo/skill_usage_stats/:skillName - 查询单个技能统计
3. GET /api/v1/uctoo/skill_usage_stats/limit/:limit/page/:page - 分页查询
4. POST /api/v1/uctoo/skill_usage_stats/record - 记录使用事件
5. POST /api/v1/uctoo/skill_usage_stats/transition/check - 手动触发状态检查
6. POST /api/v1/uctoo/skill_usage_stats/transition/:skillName - 手动触发单个技能流转
7. POST /api/v1/uctoo/skill_usage_stats/curator/trigger - 手动触发Curator审查
8. SkillUsageStatsRoute路由注册

**关键文件**:
- `src/app/controllers/uctoo/skill_usage_stats/SkillUsageStatsController.cj`
- `src/app/routes/uctoo/skill_usage_stats/SkillUsageStatsRoute.cj`

**验收标准**:
- [ ] 所有API接口可正常调用
- [ ] 统计查询返回正确数据
- [ ] 状态流转API正确触发
- [ ] Curator手动触发API正常工作

---

## SE-T011: 集成测试与验证

**描述**: 编写技能自进化闭环的集成测试。

**子任务**:
1. 编写SkillUsageTracker集成测试（使用/查看/修改事件追踪）
2. 编写SkillStateTransitionEngine集成测试（状态流转正确性）
3. 编写SkillCuratorHandler集成测试（审查流程正确性）
4. 编写SkillScriptGenerator集成测试（脚本生成正确性）
5. 编写不变量验证测试（只触碰Agent创建的技能、永不自动删除）
6. 编写端到端测试：技能使用→统计更新→状态流转→Curator审查

**验收标准**:
- [ ] 使用统计正确记录
- [ ] 自动状态流转按规则正确执行
- [ ] Curator定期审查技能
- [ ] 技能脚本首次使用时自动生成
- [ ] 不变量保证验证通过