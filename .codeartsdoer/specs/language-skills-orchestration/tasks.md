# 专用语言多Skills编排协作 - 任务清单

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
| LSO-T001 | LanguageMappingYamlParser语言映射配置解析器 | P0 | 1天 | P0-4 skill-composition-engine已完成 |
| LSO-T002 | LanguageMappingConfig语言映射配置管理 | P0 | 1天 | LSO-T001 |
| LSO-T003 | language-mappings.yaml配置文件 | P0 | 0.5天 | LSO-T002 |
| LSO-T004 | LanguageContextProvider语言上下文注入器 | P0 | 1.5天 | LSO-T002 |
| LSO-T005 | LanguageOrchestrator编排协作引擎 | P0 | 2.5天 | LSO-T002, LSO-T004 |
| LSO-T006 | SubAgentTool参数扩展 | P0 | 1天 | P0-5 cangjie-coder-agents已完成 |
| LSO-T007 | AgentDefinition扩展(language/language_context) | P0 | 1天 | LSO-T006 |
| LSO-T008 | SubAgentProgressTracker进度追踪器 | P1 | 1.5天 | LSO-T006 |
| LSO-T009 | cangjie-coder agents .md文件frontmatter扩展 | P0 | 0.5天 | LSO-T007 |
| LSO-T010 | CrossLanguageOrchestrator跨语言协作编排器 | P0 | 2天 | LSO-T005 |
| LSO-T011 | typescript-coder技能集创建 | P1 | 2天 | LSO-T005, LSO-T009 |
| LSO-T012 | python-coder技能集创建 | P1 | 2天 | LSO-T005, LSO-T009 |
| LSO-T013 | LanguageOrchestration API与Controller | P0 | 1天 | LSO-T005, LSO-T010 |
| LSO-T014 | 集成测试与端到端验证 | P0 | 1.5天 | LSO-T001~T013 |

---

## 任务详细说明

### LSO-T001: LanguageMappingYamlParser语言映射配置解析器

**描述**: 实现语言映射YAML配置文件解析器，复用CompositionYamlParser的YAML解析模式，解析language-mappings.yaml中的语言→技能集映射配置。

**子任务**:
1. 定义ProgrammingLanguage枚举（Cangjie/TypeScript/Python/Java/Go/Rust/Custom）
2. 定义LanguageSkillMapping数据类（language, skillNames, contextSources, defaultModel, orchestrationTemplate）
3. 实现LanguageMappingYamlParser.parseFromFile() - 从YAML文件解析语言映射
4. 实现LanguageMappingYamlParser.parseFromString() - 从字符串解析语言映射
5. 实现LanguageMappingYamlParser.validate() - 验证映射配置完整性
6. 实现ProgrammingLanguage枚举的toString/fromString转换方法
7. 实现LanguageSkillMapping.toJsonValue()/fromJsonValue()序列化方法

**关键文件**:
- `src/skill/language_mapping_yaml_parser.cj`（新建）

**验收标准**:
- [ ] 可正确解析language-mappings.yaml配置文件
- [ ] 支持仓颉、TypeScript、Python等语言的映射解析
- [ ] 验证逻辑可检测缺失技能、循环依赖等错误
- [ ] 复用yaml4cj库解析YAML

---

### LSO-T002: LanguageMappingConfig语言映射配置管理

**描述**: 实现语言映射配置管理类，提供映射的增删查改和验证功能，作为LanguageOrchestrator的配置数据源。

**子任务**:
1. 实现LanguageMappingConfig类，内部维护HashMap<String, LanguageSkillMapping>
2. 实现loadFromFile() - 从YAML文件加载配置
3. 实现getMapping() - 按编程语言查询映射
4. 实现addMapping()/removeMapping() - 动态增删映射
5. 实现getAllMappings() - 获取所有映射
6. 实现validate() - 验证所有映射的技能可用性和上下文源存在性
7. 实现toJsonValue() - 序列化为JSON

**关键文件**:
- `src/skill/language_mapping_config.cj`（新建）

**验收标准**:
- [ ] 可从YAML文件加载语言映射配置
- [ ] 可按语言查询映射，返回LanguageSkillMapping
- [ ] 验证可检测未安装的技能和缺失的上下文源
- [ ] 支持运行时动态添加新的语言映射

---

### LSO-T003: language-mappings.yaml配置文件

**描述**: 创建语言映射YAML配置文件，定义仓颉、TypeScript、Python三种语言的技能集映射和跨语言协作模板。

**子任务**:
1. 创建language-mappings.yaml文件，定义cangjie/typescript/python三种语言映射
2. 定义每种语言的skills列表、context_sources、default_model
3. 定义cross_language_templates节，包含fullstack-cangjie-vue跨语言模板
4. 定义fullstack-cangjie-vue模板的4个步骤（crud-generator→cangjie-coder→crudweb→tiny-vue-skill）
5. 定义步骤间数据传递映射（${generate-backend.output.api_endpoints}等）

**关键文件**:
- `skills/language-mappings.yaml`（新建）

**验收标准**:
- [ ] YAML文件语法正确，可被LanguageMappingYamlParser解析
- [ ] 仓颉映射指向cangjie-coder技能，上下文源指向cangjie-language-guide和cangjie-full-docs
- [ ] 跨语言模板正确定义步骤依赖和数据传递
- [ ] 配置文件可扩展新增语言映射

---

### LSO-T004: LanguageContextProvider语言上下文注入器

**描述**: 实现语言上下文注入器，根据编程语言自动加载相关文档、编程规范和最佳实践，注入到subagent的system prompt中。

**子任务**:
1. 定义LanguageContext数据类（language, documentation, codingStandards, bestPractices, referencePaths）
2. 实现LanguageContext.toSystemPromptFragment() - 将上下文转换为system prompt片段
3. 实现LanguageContextProvider.loadContext() - 根据语言加载上下文
4. 实现LanguageContextProvider.loadContextFromSkill() - 从技能依赖的文档技能加载上下文
5. 实现LanguageContextProvider.injectContext() - 将语言上下文注入到system prompt
6. 实现LanguageContextProvider.registerContext() - 注册自定义语言上下文
7. 实现LanguageContextProvider.getContext() - 获取已注册的语言上下文
8. 实现仓颉语言上下文加载（从cangjie-language-guide技能目录读取文档）

**关键文件**:
- `src/skill/language_context_provider.cj`（新建）

**验收标准**:
- [ ] 可根据编程语言自动加载对应的文档和规范
- [ ] 上下文正确注入到subagent的system prompt末尾
- [ ] 仓颉语言上下文包含语言规范、API文档、最佳实践
- [ ] 支持自定义上下文注册

---

### LSO-T005: LanguageOrchestrator编排协作引擎

**描述**: 实现编排协作引擎核心类，根据编程语言自动选择和编排对应的技能集，委托CompositionExecutor执行，注入语言上下文。

**子任务**:
1. 定义OrchestrationRequest数据类（language, task, input, modelOverride, background）
2. 定义OrchestrationResult数据类（language, compositionName, status, stepResults, finalOutput, languageContext）
3. 实现LanguageOrchestrator构造器，初始化CompositionExecutor/LanguageContextProvider/LanguageMappingConfig/SubAgentProgressTracker
4. 实现orchestrate() - 核心编排方法：查询映射→加载上下文→构建组合→注入上下文→执行
5. 实现buildComposition() - 根据语言映射动态构建CompositionDefinition
6. 实现getMapping() - 查询语言映射
7. 实现registerMapping() - 注册新的语言映射
8. 实现listSupportedLanguages() - 列出所有支持的语言
9. 集成LanguageContextProvider，在组合执行前注入语言上下文

**关键文件**:
- `src/skill/language_orchestrator.cj`（新建）

**验收标准**:
- [ ] 根据仓颉语言自动选择cangjie-coder技能集
- [ ] 动态构建的CompositionDefinition可被CompositionExecutor正确执行
- [ ] 语言上下文正确注入到每个subagent的system prompt
- [ ] 编排结果包含完整的步骤执行结果和最终输出

---

### LSO-T006: SubAgentTool参数扩展

**描述**: 扩展SubAgentTool，新增language_context、subagent_type、model_override、background、task_id五个参数，支持语言上下文注入、类型选择、模型覆盖和后台执行。

**子任务**:
1. 在SubAgentTool参数列表中新增language_context参数
2. 在SubAgentTool参数列表中新增subagent_type参数
3. 在SubAgentTool参数列表中新增model_override参数
4. 在SubAgentTool参数列表中新增background参数
5. 在SubAgentTool参数列表中新增task_id参数
6. 修改executeSubAgent()方法，支持language_context注入到system prompt
7. 修改executeSubAgent()方法，支持subagent_type选择Agent类型
8. 修改executeSubAgent()方法，支持model_override覆盖默认模型
9. 修改executeSubAgent()方法，支持background异步执行模式
10. 修改executeSubAgent()方法，支持task_id进度追踪注册
11. 更新buildSuccessResponse/buildErrorResponse包含新参数信息

**关键文件**:
- `src/tool/sub_agent_tool.cj`（修改）

**验收标准**:
- [ ] 新增5个参数可正确传递到executeSubAgent
- [ ] language_context正确注入到subagent的system prompt
- [ ] subagent_type可正确选择Agent类型
- [ ] model_override可覆盖默认模型
- [ ] background=true时异步执行，返回taskId
- [ ] 向后兼容：不传新参数时行为与原有一致

---

### LSO-T007: AgentDefinition扩展(language/language_context)

**描述**: 扩展AgentDefinition和AgentDefinitionBuilder，新增language和language_context字段，支持从.md文件frontmatter解析语言信息。

**子任务**:
1. 在AgentDefinition中新增language: Option<String>字段
2. 在AgentDefinition中新增languageContext: Option<String>字段
3. 在AgentDefinition.toJson()中输出新字段
4. 在AgentDefinitionBuilder中新增setLanguage()方法
5. 在AgentDefinitionBuilder中新增setLanguageContext()方法
6. 在AgentDefinitionBuilder.build()中包含新字段
7. 修改agent_loader.cj中的frontmatter解析逻辑，支持language和language_context字段

**关键文件**:
- `src/core/agent/agent_definition.cj`（修改）
- `src/core/agent/agent_loader.cj`（修改）

**验收标准**:
- [ ] AgentDefinition可存储language和languageContext字段
- [ ] 从.md文件frontmatter正确解析language和language_context
- [ ] toJson()输出包含新字段
- [ ] 向后兼容：不声明新字段时行为与原有一致

---

### LSO-T008: SubAgentProgressTracker进度追踪器

**描述**: 实现subagent进度追踪器，支持后台执行任务的进度查询、结果聚合和状态管理。

**子任务**:
1. 定义SubAgentTaskStatus枚举（Queued/Running/Completed/Failed/Cancelled）
2. 定义SubAgentTaskProgress数据类（taskId, agentName, language, status, progress, startedAt, completedAt, result, errorMessage）
3. 实现SubAgentProgressTracker.registerTask() - 注册新任务
4. 实现SubAgentProgressTracker.updateProgress() - 更新进度
5. 实现SubAgentProgressTracker.completeTask() - 标记完成并存储结果
6. 实现SubAgentProgressTracker.failTask() - 标记失败并记录错误
7. 实现SubAgentProgressTracker.cancelTask() - 取消任务
8. 实现SubAgentProgressTracker.getProgress() - 查询单任务进度
9. 实现SubAgentProgressTracker.getActiveTasks() - 获取所有活跃任务
10. 实现SubAgentProgressTracker.aggregateResults() - 聚合多个任务结果为SkillOutput
11. 实现SubAgentProgressTracker.getOverallProgress() - 计算多任务整体进度

**关键文件**:
- `src/skill/sub_agent_progress_tracker.cj`（新建）

**验收标准**:
- [ ] 可注册和追踪后台执行任务
- [ ] 进度更新正确反映任务执行状态
- [ ] 多任务结果可聚合为统一SkillOutput
- [ ] 整体进度计算正确

---

### LSO-T009: cangjie-coder agents .md文件frontmatter扩展

**描述**: 扩展cangjie-coder技能的4个agent .md文件，新增language和language_context字段，作为其他语言技能集的参考模板。

**子任务**:
1. 在doc-consultant.md的frontmatter中新增language: cangjie
2. 在doc-consultant.md的frontmatter中新增language_context: cangjie-language-guide,cangjie-full-docs
3. 在code-searcher.md的frontmatter中新增language: cangjie
4. 在code-searcher.md的frontmatter中新增language_context: cangjie-language-guide,cangjie-full-docs
5. 在code-editor.md的frontmatter中新增language: cangjie
6. 在code-editor.md的frontmatter中新增language_context: cangjie-language-guide,cangjie-full-docs
7. 在code-verifier.md的frontmatter中新增language: cangjie
8. 在code-verifier.md的frontmatter中新增language_context: cangjie-language-guide,cangjie-full-docs

**关键文件**:
- `skills/cangjie-coder/agents/doc-consultant.md`（修改）
- `skills/cangjie-coder/agents/code-searcher.md`（修改）
- `skills/cangjie-coder/agents/code-editor.md`（修改）
- `skills/cangjie-coder/agents/code-verifier.md`（修改）

**验收标准**:
- [ ] 4个agent .md文件的frontmatter包含language和language_context字段
- [ ] AgentDefinition可正确解析新增字段
- [ ] 不影响cangjie-coder技能的现有编排流程

---

### LSO-T010: CrossLanguageOrchestrator跨语言协作编排器

**描述**: 实现跨语言协作编排器，支持多语言项目的动态技能编排，通过标准化的SkillOutput格式实现跨语言数据传递。

**子任务**:
1. 定义CrossLanguageStep数据类（name, language, skillName, dependsOn, inputMapping, outputKey）
2. 定义CrossLanguageRequest数据类（languages, task, input, steps, background）
3. 定义CrossLanguageResult数据类（languages, compositionName, status, stepResults, finalOutput, crossLanguageData）
4. 实现CrossLanguageOrchestrator构造器，初始化LanguageOrchestrator/CompositionExecutor/ResultAggregator/SubAgentProgressTracker
5. 实现orchestrate() - 核心跨语言编排方法
6. 实现buildCrossLanguageComposition() - 将跨语言步骤转换为CompositionDefinition
7. 实现validateCrossLanguageData() - 验证跨语言数据传递的完整性
8. 集成ResultAggregator聚合跨语言执行结果
9. 集成SubAgentProgressTracker追踪多语言步骤进度

**关键文件**:
- `src/skill/cross_language_orchestrator.cj`（新建）

**验收标准**:
- [ ] 可编排仓颉后端+Vue前端的全栈CRUD流程
- [ ] 跨语言数据传递通过SkillOutput标准化格式
- [ ] 后端API端点数据可正确传递到前端生成步骤
- [ ] 跨语言结果可正确聚合

---

### LSO-T011: typescript-coder技能集创建

**描述**: 参照cangjie-coder的编排器模式，创建typescript-coder技能集，包含4个专用subagent（doc-consultant→code-searcher→code-editor→code-verifier）。

**子任务**:
1. 创建skills/typescript-coder/目录
2. 创建SKILL.md（编排器模式，agents声明4个subagent）
3. 创建agents/ts-doc-consultant.md（TypeScript文档查阅Agent）
4. 创建agents/ts-code-searcher.md（TypeScript代码检索Agent）
5. 创建agents/ts-code-editor.md（TypeScript代码编辑Agent）
6. 创建agents/ts-code-verifier.md（TypeScript代码验证Agent）
7. 创建references/目录（TypeScript参考文档）
8. 创建scripts/目录（TypeScript语法检查、编译、测试脚本）

**关键文件**:
- `skills/typescript-coder/SKILL.md`（新建）
- `skills/typescript-coder/agents/ts-doc-consultant.md`（新建）
- `skills/typescript-coder/agents/ts-code-searcher.md`（新建）
- `skills/typescript-coder/agents/ts-code-editor.md`（新建）
- `skills/typescript-coder/agents/ts-code-verifier.md`（新建）

**验收标准**:
- [ ] typescript-coder技能可被ProgressiveSkillLoader自动加载
- [ ] 4个subagent的.md文件格式与cangjie-coder一致
- [ ] frontmatter包含language: typescript和language_context字段
- [ ] 编排流程：文档查阅→代码检索→代码编辑→代码验证

---

### LSO-T012: python-coder技能集创建

**描述**: 参照cangjie-coder的编排器模式，创建python-coder技能集，包含4个专用subagent（doc-consultant→code-searcher→code-editor→code-verifier）。

**子任务**:
1. 创建skills/python-coder/目录
2. 创建SKILL.md（编排器模式，agents声明4个subagent）
3. 创建agents/py-doc-consultant.md（Python文档查阅Agent）
4. 创建agents/py-code-searcher.md（Python代码检索Agent）
5. 创建agents/py-code-editor.md（Python代码编辑Agent）
6. 创建agents/py-code-verifier.md（Python代码验证Agent）
7. 创建references/目录（Python参考文档）
8. 创建scripts/目录（Python语法检查、测试脚本）

**关键文件**:
- `skills/python-coder/SKILL.md`（新建）
- `skills/python-coder/agents/py-doc-consultant.md`（新建）
- `skills/python-coder/agents/py-code-searcher.md`（新建）
- `skills/python-coder/agents/py-code-editor.md`（新建）
- `skills/python-coder/agents/py-code-verifier.md`（新建）

**验收标准**:
- [ ] python-coder技能可被ProgressiveSkillLoader自动加载
- [ ] 4个subagent的.md文件格式与cangjie-coder一致
- [ ] frontmatter包含language: python和language_context字段
- [ ] 编排流程：文档查阅→代码检索→代码编辑→代码验证

---

### LSO-T013: LanguageOrchestration API与Controller

**描述**: 创建语言编排的RESTful API，提供单语言编排、跨语言编排、映射配置查询、进度查询等接口。

**子任务**:
1. 创建LanguageOrchestrationService（Service层）
2. 实现orchestrate()方法 - 单语言编排
3. 实现crossLanguageOrchestrate()方法 - 跨语言编排
4. 实现getMappings()方法 - 查询语言映射
5. 实现addMapping()方法 - 新增语言映射
6. 实现getProgress()方法 - 查询subagent进度
7. 实现getActiveTasks()方法 - 查询活跃任务
8. 创建LanguageOrchestrationController（Controller层）
9. 创建LanguageOrchestrationRoute（Route层）
10. 注册路由到AutoRouteConfig

**关键文件**:
- `src/app/services/uctoo/LanguageOrchestrationService.cj`（新建）
- `src/app/controllers/uctoo/LanguageOrchestrationController.cj`（新建）
- `src/app/routes/uctoo/LanguageOrchestrationRoute.cj`（新建）

**验收标准**:
- [ ] POST /api/v1/uctoo/language_orchestration/orchestrate 可触发单语言编排
- [ ] POST /api/v1/uctoo/language_orchestration/cross-language 可触发跨语言编排
- [ ] GET /api/v1/uctoo/language_orchestration/mappings 可查询语言映射
- [ ] GET /api/v1/uctoo/language_orchestration/progress/:taskId 可查询进度

---

### LSO-T014: 集成测试与端到端验证

**描述**: 编写集成测试，验证编排协作引擎、语言上下文注入、跨语言协作和subagent配置增强的端到端功能。

**子任务**:
1. 编写LanguageMappingYamlParser单元测试（解析、验证）
2. 编写LanguageOrchestrator集成测试（仓颉语言编排）
3. 编写LanguageContextProvider测试（上下文加载和注入）
4. 编写CrossLanguageOrchestrator集成测试（仓颉+TypeScript跨语言编排）
5. 编写SubAgentTool扩展参数测试（language_context注入、model_override、background）
6. 编写SubAgentProgressTracker测试（进度追踪、结果聚合）
7. 编写LanguageOrchestration API端到端测试
8. 编写Python测试脚本验证完整流程

**关键文件**:
- `tests/test_language_orchestrator.py`（新建）
- `tests/test_cross_language_orchestrator.py`（新建）
- `tests/test_language_context_provider.py`（新建）

**验收标准**:
- [ ] 编排协作引擎根据编程语言自动选择技能集
- [ ] 语言上下文正确注入到subagent
- [ ] 跨语言协作（仓颉+Vue）可正确执行
- [ ] subagent支持类型选择、模型覆盖、后台执行
- [ ] 进度追踪和结果聚合功能正确