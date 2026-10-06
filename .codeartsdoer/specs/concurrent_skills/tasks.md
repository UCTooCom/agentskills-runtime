# 技能并行机制编码任务分解

> **工程目录**: `.codeartsdoer/specs/concurrent_skills/`
> **生成日期**: 2026-10-05
> **更新日期**: 2026-10-05（纳入 spec.md 第 5.6 节"技能内容自动渐进式加载"补充需求）
> **上游文档**: `spec.md`（需求规格，含 5.6 节补充需求）、`research.md`（研究报告）、`design.md`（技术设计，含模块 H-L 和阶段 9-16）
> **技术栈**: Cangjie（仓颉）+ cjpm + fountain 框架
> **任务总数**: 82 个任务（20 个任务组）
> **优先级划分**: P0（注入核心 + 自动注入漂移修复，阶段 1-4/9/12-14）/ P1（互斥+个性化+日志+决策记录+路径修复+去重，阶段 5-7/10/15-16）/ P2（预算管理+预算降级+性能测试，阶段 8/11）
> **本次更新摘要**: 新增 TG13-TG20 共 8 个任务组、35 个任务（T048-T082），覆盖 design.md 阶段 9-16，修复"渐进式加载设计漂移"——将技能完整内容加载从"agent 主动调用 `get_skill_content` 工具"恢复为"框架自动注入到上下文"

---

## 任务总览

### 任务编号规则
- 主任务组：`TG{NN}`（如 TG01）
- 子任务：`T{NNN}`（如 T001），全局唯一递增
- TG01-TG12：原有任务（阶段 1-8 + 集成/性能/文档/审查）
- TG13-TG20：补充需求任务（阶段 9-16，自动渐进式加载漂移修复）

### 依赖关系图
```
== 原有路径（阶段 1-8） ==
TG01 (声明解析) ──→ TG02 (渲染) ──→ TG03 (注入核心) ──→ TG04 (Agent 扩展)
                                          │
                                          ├──→ TG05 (互斥过滤)
                                          ├──→ TG06 (个性化插件)
                                          ├──→ TG07 (决策日志)
                                          └──→ TG08 (预算分配)

== 补充需求路径（阶段 9-16，漂移修复） ==
TG01 ──→ TG13 (AutoInjectConfig) ──→ TG14 (TaskMatcher) ──────────────────┐
TG07 ──→ TG16 (InjectDecisionRecorder) ────────────────────────────────────┤
TG08 ──→ TG17 (BudgetManager 带降级) ──────────────────────────────────────┤
TG03 + TG13 + TG14 + TG16 + TG17 ──→ TG15 (SkillAutoInjector) ────────────┤
                                                                           │
TG15 ──→ TG18 (漂移修复: WebMCPProtocol/WsChatController/GetSkillContentTool)
TG15 ──→ TG19 (buildAgentFromDefinition 修复)
TG15 + TG18 + TG19 ──→ TG20 (自动渐进式加载集成测试)

== 最终验证 ==
TG04 + TG05 + ... + TG20 ──→ TG09 (端到端集成测试) ──→ TG10 (性能测试)
                                                                      │
                                                                      ├──→ TG11 (文档配置)
                                                                      └──→ TG12 (审查验证)
```

### 执行顺序与并行可能性
- **串行必执行（原有 P0）**：TG01 → TG02 → TG03 → TG04（驻留型注入最小可用路径）
- **可并行执行（原有 P1/P2）**：TG05 / TG06 / TG07 / TG08 在 TG03 完成后可并行开发
- **串行必执行（补充需求 P0）**：TG13 → TG14；TG03 + TG13 + TG14 + TG16 + TG17 → TG15 → TG18
- **可并行执行（补充需求）**：TG13/TG14（阶段 9）与 TG16（阶段 10）与 TG17（阶段 11）在各自依赖满足后可并行
- **漂移修复最小路径**：TG01 → TG02 → TG03 → TG13 → TG15 → TG18（实现驻留型技能完整内容自动注入替换第3段漂移）
- **测试随开发同步**：每个任务组内含单元测试任务，不延后到 TG09/TG20
- **最终验证串行**：TG20 → TG09 → TG10 → TG11 → TG12

### 复用基础设施清单
| 复用组件 | 文件路径 | 包名 | 复用方式 |
|---------|---------|------|---------|
| `Skill` 接口 | `src/core/skill/skill.cj` | `magic.core.skill` | 通过 `metadata` 承载扩展字段，不修改接口 |
| `BaseSkill` | `src/skill/base_skill.cj` | `magic.skill` | 继承创建 `PersonalizationSkillPlugin` |
| `SkillDependencyResolver` | `src/skill/dependency_resolver.cj` | `magic.skill` | 复用 `resolve()` / `detectCycles()` / `topologicalSort()` |
| `CompositeSkillToolManager` | `src/skill/composite_skill_tool_manager.cj` | `magic.skill` | 复用 `availableSkills` / `enabledSkills` |
| `AgentWorkspace` | `src/memory/workspace/agent_workspace.cj` | `magic.memory.workspace` | 复用 `getCombinedMemory()` / `getFile()` |
| `SkillAwareAgent` | `src/skill/skill_aware_agent.cj` | `magic.skill` | 扩展接入 `SkillContextInjector` / `SkillAutoInjector` |
| `GetSkillContentTool` | `src/tool/get_skill_content_tool.cj` | `magic.tool` | 扩展去重机制（向后兼容） |
| `LogUtils` | `src/log/log_utils.cj` | `magic.log` | 用于结构化日志输出 |
| `WebMCPProtocol` | `src/protocol/web_mcp_protocol.cj` | `magic.protocol` | 扩展 `buildAgentSystemPrompt()` 接入自动注入替换第3段漂移 |
| `WsChatController` | `src/controller/ws_chat_controller.cj` | `magic.controller` | 扩展用户消息处理接入任务匹配自动注入 |
| `AgentRuntimeBridge` | `src/runtime/agent_runtime_bridge.cj` | `magic.runtime` | 修复 `buildAgentFromDefinition()` 空技能管理器 |

---

## 1. 实现 SKILL.md 并行声明解析（阶段 1，P0）

**写作指导**：本组对应 design.md 阶段 1，是后续所有模块的基础。必须先完成枚举类型和配置类，再实现解析器。

### 1.1 实现并行声明枚举类型
- [ ] **T001** 实现 `LoadPolicy` 枚举（`AlwaysOn` / `OnDemand` / `Conditional`），位于 `src/skill/parallel/load_policy.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：无
  - 描述：定义技能加载策略枚举，`AlwaysOn` 表示驻留型（会话生命周期内持续生效），`OnDemand` 表示按需型（显式触发时加载），`Conditional` 表示条件型
  - 输入：无
  - 输出：`src/skill/parallel/load_policy.cj`
  - 验收标准：枚举三值齐全，可被 `match` 表达式消费
  - 风险点：无
  - 回滚点：删除文件即可

- [ ] **T002** 实现 `SkillPriority` 枚举（`High` / `Medium` / `Low`），位于 `src/skill/parallel/skill_priority.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：无
  - 描述：定义技能优先级枚举，用于互斥冲突裁决和预算超限淘汰时的排序依据
  - 输入：无
  - 输出：`src/skill/parallel/skill_priority.cj`
  - 验收标准：枚举三值齐全，提供 `compare()` 比较方法
  - 风险点：无
  - 回滚点：删除文件即可

- [ ] **T003** 实现 `SkillLoadDecision` 枚举（`Loaded` / `Skipped` / `Evicted` / `Rejected`），位于 `src/skill/parallel/skill_load_decision.cj`，包名 `magic.skill.parallel`
  - 优先级：P1（提前实现以避免后续返工）
  - 依赖任务：无
  - 描述：定义加载决策枚举，`Loaded` 表示成功加载，`Skipped` 表示跳过（如依赖缺失），`Evicted` 表示被淘汰（如互斥冲突或预算超限），`Rejected` 表示被拒绝（如循环依赖）
  - 输入：无
  - 输出：`src/skill/parallel/skill_load_decision.cj`
  - 验收标准：枚举四值齐全
  - 风险点：无
  - 回滚点：删除文件即可

### 1.2 实现并行配置类
- [ ] **T004** 实现 `SkillParallelConfig` 配置类，位于 `src/skill/parallel/skill_parallel_config.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T001、T002
  - 描述：实现配置类，字段包括 `totalBudgetTokens: Int64`（默认 8192）、`reservedForAlwaysOn: Float64`（默认 0.3）、`defaultLoadPolicy: LoadPolicy`（默认 `OnDemand`）、`defaultPriority: SkillPriority`（默认 `Medium`）、`defaultContextBudgetTokens: Int64`（默认 2000）、`enableConflictFilter: Bool`（默认 true）、`enableBudgetAllocator: Bool`（默认 true）；提供 `static func default(): SkillParallelConfig` 工厂方法
  - 输入：T001、T002 的枚举类型
  - 输出：`src/skill/parallel/skill_parallel_config.cj`
  - 验收标准：所有字段有默认值，`default()` 方法返回配置实例
  - 风险点：默认值需与 design.md 2.1.2 节配置表一致
  - 回滚点：删除文件即可

### 1.3 实现声明解析器
- [ ] **T005** 实现 `SkillParallelDeclarationParser` 静态工具类，位于 `src/skill/parallel/skill_parallel_declaration_parser.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T001、T002、T004
  - 描述：实现静态方法 `parseLoadPolicy(metadata)` / `parsePriority(metadata)` / `parseDependsOn(metadata)` / `parseConflictsWith(metadata)` / `parseContextBudgetTokens(metadata)` / `parseCompatibleWith(metadata)`，从 `HashMap<String, String>` 解析字段；缺失字段返回默认值（`OnDemand` / `Medium` / 空数组 / 2000）；列表型字段用逗号分隔存储
  - 输入：`Skill.metadata: HashMap<String, String>`
  - 输出：`src/skill/parallel/skill_parallel_declaration_parser.cj`
  - 验收标准：
    1. `metadata` 含 `load_policy=always_on` 时 `parseLoadPolicy()` 返回 `AlwaysOn`
    2. `metadata` 不含 `load_policy` 时返回 `OnDemand`
    3. `metadata` 含 `conflicts_with=sdd,cangjie-coder` 时 `parseConflictsWith()` 返回 `["sdd", "cangjie-coder"]`
    4. `metadata` 含 `context_budget_tokens=3000` 时返回 3000，缺失时返回 2000
  - 风险点：列表解析需 `trimAscii()` 去除空格，过滤空字符串
  - 回滚点：删除文件即可

### 1.4 声明解析器单元测试
- [ ] **T006** 为 `SkillParallelDeclarationParser` 编写单元测试，位于 `src/skill/parallel/test/test_skill_parallel_declaration_parser.cj`
  - 优先级：P0
  - 依赖任务：T005
  - 描述：测试用例覆盖：有字段/无字段/非法值/列表单元素/列表多元素/空 metadata
  - 输入：T005 的解析器
  - 输出：`src/skill/parallel/test/test_skill_parallel_declaration_parser.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节声明解析器测试矩阵
  - 风险点：仓颉测试框架用法需参考 `libs/yaml4cj/test/LLT/` 现有测试
  - 回滚点：删除测试文件

---

## 2. 实现技能内容渲染（阶段 2，P0）

**写作指导**：本组对应 design.md 阶段 2，将技能渲染为 `<skill_content>` 和 `<available_skills>` XML 块，是上下文注入的输出格式基础。

### 2.1 实现技能内容渲染器
- [ ] **T007** 实现 `SkillContentRenderer` 类，位于 `src/skill/parallel/skill_content_renderer.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T001（无直接依赖，但同包）
  - 描述：实现 `renderSkillContent(skill: Skill): String` 渲染单个技能为 `<skill_content name="...">` XML 块；实现 `renderMultipleSkills(skills: Array<Skill>): String` 合并多个技能的渲染结果；XML 格式参考 design.md 2.2.2.5 节调用示例
  - 输入：`Skill` 实例（含 `name` / `instructions`）
  - 输出：`src/skill/parallel/skill_content_renderer.cj`
  - 验收标准：
    1. 渲染输出以 `<skill_content name="${skill.name}">` 开头，`</skill_content>` 结尾
    2. 包含 `<skill_instructions>` 子标签包裹 `skill.instructions`
    3. `renderMultipleSkills()` 多技能时各 XML 块用 `\n\n` 分隔
    4. `instructions` 为空时返回空字符串
  - 风险点：XML 转义（技能名或指令体含 `<` / `>` 时需转义，本期可暂不处理但需记录 TODO）
  - 回滚点：删除文件即可

### 2.2 实现技能目录渲染器
- [ ] **T008** 实现 `SkillCatalogRenderer` 类，位于 `src/skill/parallel/skill_catalog_renderer.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T001
  - 描述：实现 `renderCatalog(skills: Array<Skill>): String` 渲染技能目录为 `<available_skills>` XML 块，每行格式 `- \`{name}\`: {description}`；空列表时返回空 `<available_skills></available_skills>`
  - 输入：`Array<Skill>`
  - 输出：`src/skill/parallel/skill_catalog_renderer.cj`
  - 验收标准：
    1. 输出以 `<available_skills>` 开头，`</available_skills>` 结尾
    2. 每个技能一行，格式 `- \`name\`: description`
    3. 空列表返回空标签
  - 风险点：description 过长时需截断（design.md 未明确截断长度，本期保留全文）
  - 回滚点：删除文件即可

### 2.3 渲染器单元测试
- [ ] **T009** 为 `SkillContentRenderer` 和 `SkillCatalogRenderer` 编写单元测试，位于 `src/skill/parallel/test/test_skill_renderers.cj`
  - 优先级：P0
  - 依赖任务：T007、T008
  - 描述：测试用例覆盖：单技能渲染/多技能合并/空指令/空目录/多技能目录
  - 输入：T007、T008 的渲染器
  - 输出：`src/skill/parallel/test/test_skill_renderers.cj`
  - 验收标准：所有测试用例通过，XML 格式严格匹配 design.md 示例
  - 风险点：无
  - 回滚点：删除测试文件

---

## 3. 实现上下文注入核心（阶段 3，P0）

**写作指导**：本组对应 design.md 阶段 3，是整个机制的核心编排器。本期先实现驻留型技能收集 + 依赖闭包计算 + 注入，互斥过滤和预算分配在后续阶段接入。

### 3.1 实现注入结果数据类
- [ ] **T010** 实现 `SkillInjectionResult` 数据类，位于 `src/skill/parallel/skill_injection_result.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T003
  - 描述：实现字段 `status: SkillInjectionStatus`（`Success` / `Partial` / `Failed`）、`injectedContext: String`、`activeSkills: Array<String>`、`decisions: Array<SkillLoadDecisionRecord>`、`errorMessage: Option<String>`；`SkillInjectionStatus` 可定义为同文件枚举
  - 输入：T003 的 `SkillLoadDecision`
  - 输出：`src/skill/parallel/skill_injection_result.cj`
  - 验收标准：所有字段可读写，`errorMessage` 默认 `None`
  - 风险点：`SkillLoadDecisionRecord` 在 T022 实现，本期可先用占位类型或同任务内联定义
  - 回滚点：删除文件即可

### 3.2 实现上下文注入核心编排器
- [ ] **T011** 实现 `SkillContextInjector` 类骨架，位于 `src/skill/parallel/skill_context_injector.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T004、T005、T007、T008、T010
  - 描述：实现 `init()` 注入 `CompositeSkillToolManager` / `SkillDependencyResolver` / `SkillContentRenderer` / `SkillCatalogRenderer` / `SkillParallelConfig`；实现 `activeSkills` 属性（`ArrayList<String>` 维护存活技能列表）；互斥过滤器和预算分配器字段暂为 `Option`，本期传 `None`
  - 输入：复用 `CompositeSkillToolManager`、`SkillDependencyResolver`
  - 输出：`src/skill/parallel/skill_context_injector.cj`
  - 验收标准：可构造实例，`activeSkills` 初始为空
  - 风险点：`SkillDependencyResolver` 需传入 `CompositeSkillToolManager` 构造，注意依赖注入顺序
  - 回滚点：删除文件即可

- [ ] **T012** 在 `SkillContextInjector` 中实现 `injectAlwaysOnSkills(sessionId)` 方法
  - 优先级：P0
  - 依赖任务：T011
  - 描述：实现流程：① 遍历 `skillManager.availableSkills`，用 `SkillParallelDeclarationParser.parseLoadPolicy()` 过滤 `AlwaysOn` 技能；② 调用 `SkillDependencyResolver.resolve()` 计算依赖闭包；③ 检测循环依赖（`hasCycles=true` 时返回 `Failed`）；④ 跳过缺失依赖技能（`missingSkills` 非空时记录告警）；⑤ 调用 `SkillContentRenderer.renderMultipleSkills()` 渲染存活技能；⑥ 更新 `activeSkills`；⑦ 返回 `SkillInjectionResult`
  - 输入：`sessionId: String`
  - 输出：`SkillInjectionResult`
  - 验收标准：
    1. `load_policy=always_on` 的技能全部注入上下文
    2. 驻留型技能的依赖闭包同时注入
    3. 循环依赖时返回 `status=Failed`，`errorMessage` 含循环路径
    4. 缺失依赖时跳过该技能，`status=Partial`
  - 风险点：`SkillDependencyResolver.extractDependencies()` 把 `allowedTools` 也当依赖（design.md 1.2.1 节差异点），本期需在调用后过滤掉非技能的工具名
  - 回滚点：方法返回空 `SkillInjectionResult`，不影响现有机制

- [ ] **T013** 在 `SkillContextInjector` 中实现 `injectSkills(skillNames, sessionId)` 方法
  - 优先级：P0
  - 依赖任务：T012
  - 描述：实现用户显式/模型按需加载技能的注入流程：① 收集 `skillNames` 对应的 `Skill` 实例；② 合并已存活的驻留型技能；③ 复用 `injectAlwaysOnSkills` 的依赖闭包计算和渲染逻辑；④ 更新 `activeSkills`
  - 输入：`skillNames: Array<String>`、`sessionId: String`
  - 输出：`SkillInjectionResult`
  - 验收标准：
    1. 显式加载的技能注入上下文
    2. 其依赖闭包同时注入
    3. 已存活的驻留型技能不被重复注入
  - 风险点：去重逻辑需注意 `activeSkills` 已有技能
  - 回滚点：方法返回空结果

- [ ] **T014** 在 `SkillContextInjector` 中实现 `renderCatalog()` 方法
  - 优先级：P0
  - 依赖任务：T011、T008
  - 描述：调用 `SkillCatalogRenderer.renderCatalog()` 渲染当前 `activeSkills` 对应的技能目录
  - 输入：无（读取 `activeSkills`）
  - 输出：`String`（`<available_skills>` XML 块）
  - 验收标准：返回的 XML 块包含所有存活技能
  - 风险点：无
  - 回滚点：返回空字符串

### 3.3 注入核心单元测试
- [ ] **T015** 为 `SkillContextInjector` 编写单元测试，位于 `src/skill/parallel/test/test_skill_context_injector.cj`
  - 优先级：P0
  - 依赖任务：T012、T013、T014
  - 描述：测试用例覆盖：无驻留型技能/单驻留型技能/多驻留型技能/驻留型技能有依赖/驻留型技能循环依赖/驻留型技能依赖缺失/显式加载技能/显式加载已存活技能
  - 输入：T012、T013、T014 的方法
  - 输出：`src/skill/parallel/test/test_skill_context_injector.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节注入核心测试矩阵
  - 风险点：需构造 mock `CompositeSkillToolManager` 和 mock `Skill` 实例
  - 回滚点：删除测试文件

---

## 4. 扩展 SkillAwareAgent 接入注入器（阶段 4，P0）

**写作指导**：本组对应 design.md 阶段 4，将 `SkillContextInjector` 接入 `SkillAwareAgent`，是 P0 最小可用路径的最后一环。

### 4.1 扩展 SkillAwareAgent
- [ ] **T016** 在 `SkillAwareAgent` 中新增 `skillContextInjector: Option<SkillContextInjector>` 字段，修改文件 `src/skill/skill_aware_agent.cj`
  - 优先级：P0
  - 依赖任务：T011
  - 描述：在 `SkillAwareAgent` 类中新增 `private let _skillContextInjector: Option<SkillContextInjector>` 字段，`init()` 参数新增 `skillParallelConfig!: Option<SkillParallelConfig> = None`；当配置非 `None` 时构造 `SkillContextInjector`，否则保持 `None` 退回现有机制
  - 输入：T011 的 `SkillContextInjector`
  - 输出：修改 `src/skill/skill_aware_agent.cj`
  - 验收标准：
    1. 现有 `init()` 调用不传 `skillParallelConfig` 时行为不变
    2. 传入配置时构造注入器
    3. 不修改 `_registerSkillsAsTools()` 签名和现有逻辑
  - 风险点：向后兼容是关键，现有调用方不传新参数时必须正常工作
  - 回滚点：字段设为 `None` 即退回现有机制

- [ ] **T017** 在 `SkillAwareAgent` 中新增 `_injectSkillContext()` 私有方法
  - 优先级：P0
  - 依赖任务：T016
  - 描述：实现私有方法 `_injectSkillContext(sessionId: String): Option<String>`，当 `_skillContextInjector` 为 `Some` 时调用 `injectAlwaysOnSkills()` 返回注入的上下文文本，`None` 时返回 `None`；在 `init()` 末尾调用此方法，将返回的上下文追加到 `systemPrompt`
  - 输入：T012 的 `injectAlwaysOnSkills()`
  - 输出：修改 `src/skill/skill_aware_agent.cj`
  - 验收标准：
    1. Agent 初始化时驻留型技能自动注入 `systemPrompt`
    2. 注入失败时不影响 Agent 构造
    3. `_skillContextInjector` 为 `None` 时 `systemPrompt` 不变
  - 风险点：注入的上下文追加到 `systemPrompt` 的位置需谨慎，避免覆盖用户传入的 `systemPrompt`
  - 回滚点：方法返回 `None`，`systemPrompt` 不变

### 4.2 SkillAwareAgent 扩展集成测试
- [ ] **T018** 编写 `SkillAwareAgent` 扩展集成测试，位于 `src/skill/test/test_skill_aware_agent_parallel.cj`
  - 优先级：P0
  - 依赖任务：T017
  - 描述：测试用例覆盖：不传配置时行为不变/传配置时驻留型技能注入 systemPrompt/无驻留型技能时 systemPrompt 不变
  - 输入：T017 的扩展
  - 输出：`src/skill/test/test_skill_aware_agent_parallel.cj`
  - 验收标准：所有测试用例通过，现有 `_registerSkillsAsTools()` 行为不变
  - 风险点：需构造 mock `ChatModel` 和 mock `AgentExecutor`
  - 回滚点：删除测试文件

---

## 5. 实现互斥技能过滤（阶段 5，P1）

**写作指导**：本组对应 design.md 阶段 5，实现互斥技能过滤和优先级裁决，并接入 `SkillContextInjector`。

### 5.1 实现互斥过滤结果数据类
- [ ] **T019** 实现 `ConflictFilterResult` 数据类，位于 `src/skill/parallel/conflict_filter_result.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：无
  - 描述：实现字段 `survived: Array<String>`（存活技能名）、`evicted: Array<String>`（被淘汰技能名）、`conflictPairs: Array<(String, String)>`（冲突对）
  - 输入：无
  - 输出：`src/skill/parallel/conflict_filter_result.cj`
  - 验收标准：所有字段可读写
  - 风险点：无
  - 回滚点：删除文件即可

### 5.2 实现互斥过滤器
- [ ] **T020** 实现 `ConflictFilter` 类，位于 `src/skill/parallel/conflict_filter.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：T002、T005、T019
  - 描述：实现 `filter(skills: Array<Skill>, loadOrder: Array<String>): ConflictFilterResult`；私有方法 `buildConflictGraph(skills)` 从 `metadata.conflicts_with` 构建互斥关系图；私有方法 `resolveConflicts(graph, skills)` 按 `priority` 裁决，优先级相同时按 `loadOrder` 先到先得
  - 输入：`Array<Skill>` + `loadOrder`
  - 输出：`src/skill/parallel/conflict_filter.cj`
  - 验收标准：
    1. `A conflicts_with B`，`A.priority > B.priority` → 保留 A，淘汰 B
    2. `A conflicts_with B`，优先级相同，A 在 `loadOrder` 前 → 保留 A
    3. `survived` 中无互斥对
    4. 双向互斥声明不一致时记录告警，按声明的方向处理
  - 风险点：互斥关系图构建时需双向检查（A 声明与 B 互斥，但 B 未声明时需告警）
  - 回滚点：`filter()` 返回所有技能存活，不淘汰任何技能

### 5.3 接入 SkillContextInjector
- [ ] **T021** 在 `SkillContextInjector` 中接入 `ConflictFilter`，修改 `src/skill/parallel/skill_context_injector.cj`
  - 优先级：P1
  - 依赖任务：T012、T020
  - 描述：在 `injectAlwaysOnSkills()` 和 `injectSkills()` 的依赖闭包计算后、渲染前，插入互斥过滤步骤；当 `config.enableConflictFilter = false` 时跳过；过滤后淘汰的技能记录决策日志（P1 阶段先记录到 `LogUtils.warn`）
  - 输入：T020 的 `ConflictFilter`
  - 输出：修改 `src/skill/parallel/skill_context_injector.cj`
  - 验收标准：
    1. 互斥技能不共存于 `activeSkills`
    2. `config.enableConflictFilter = false` 时不过滤
    3. 淘汰技能时记录告警日志
  - 风险点：过滤顺序在依赖闭包计算之后，避免过滤掉被依赖的技能
  - 回滚点：`enableConflictFilter = false` 关闭过滤

### 5.4 互斥过滤单元测试
- [ ] **T022** 为 `ConflictFilter` 编写单元测试，位于 `src/skill/parallel/test/test_conflict_filter.cj`
  - 优先级：P1
  - 依赖任务：T020
  - 描述：测试用例覆盖：无冲突/单冲突高优先级保留/单冲突优先级相同先到先得/多冲突链式淘汰/双向声明不一致/空技能列表
  - 输入：T020 的过滤器
  - 输出：`src/skill/parallel/test/test_conflict_filter.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节互斥过滤测试矩阵
  - 风险点：无
  - 回滚点：删除测试文件

---

## 6. 实现 personalization 技能插件（阶段 6，P1）

**写作指导**：本组对应 design.md 阶段 6，将 `AgentWorkspace` 的个性化文件抽象为 `load_policy=always_on` 的技能插件。

### 6.1 实现个性化技能插件
- [ ] **T023** 实现 `PersonalizationSkillPlugin` 类，位于 `src/skill/parallel/personalization_skill_plugin.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：T001、T002
  - 描述：实现 `loadFromWorkspace(workspace: AgentWorkspace): Option<Skill>` 方法，调用 `workspace.getCombinedMemory()` 获取合并内容，包装为 `BaseSkill` 实例，设置 `name="personalization"`、`metadata.load_policy="always_on"`、`metadata.priority="high"`、`instructions=合并内容`；实现 `static func isPersonalizationSkill(skill: Skill): Bool` 判断 `skill.name == "personalization"`；所有个性化文件缺失时返回 `None`
  - 输入：复用 `AgentWorkspace.getCombinedMemory()`
  - 输出：`src/skill/parallel/personalization_skill_plugin.cj`
  - 验收标准：
    1. 存在 SOUL.md 时返回的 `Skill` 含 SOUL.md 内容
    2. 返回的 `Skill` 的 `metadata.load_policy = "always_on"`
    3. 所有个性化文件缺失时返回 `None`
    4. `isPersonalizationSkill()` 正确识别
  - 风险点：`AgentWorkspace` 在 `magic.memory.workspace` 包，需 `import` 跨包依赖
  - 回滚点：返回 `None`，不注入个性化内容

### 6.2 接入 SkillAwareAgent
- [ ] **T024** 在 `SkillAwareAgent` 初始化时加载 personalization 技能，修改 `src/skill/skill_aware_agent.cj`
  - 优先级：P1
  - 依赖任务：T017、T023
  - 描述：在 `SkillAwareAgent.init()` 中，当 `skillParallelConfig` 非 `None` 且传入 `AgentWorkspace` 时，调用 `PersonalizationSkillPlugin.loadFromWorkspace()` 获取个性化技能，注册到 `CompositeSkillToolManager`（通过 `addSkill()`），使其参与驻留型技能注入流程
  - 输入：T023 的 `PersonalizationSkillPlugin`
  - 输出：修改 `src/skill/skill_aware_agent.cj`
  - 验收标准：
    1. Agent 初始化时 personalization 技能自动加载
    2. personalization 技能与其他技能并行存在于上下文
    3. 无个性化文件时不报错
  - 风险点：`SkillAwareAgent.init()` 参数需新增 `workspace!: Option<AgentWorkspace> = None`，保持向后兼容
  - 回滚点：不传 `workspace` 参数时不加载个性化技能

### 6.3 个性化插件单元测试
- [ ] **T025** 为 `PersonalizationSkillPlugin` 编写单元测试，位于 `src/skill/parallel/test/test_personalization_skill_plugin.cj`
  - 优先级：P1
  - 依赖任务：T023
  - 描述：测试用例覆盖：全文件存在/部分文件缺失/全文件缺失/单 SOUL.md/单 IDENTITY.md
  - 输入：T023 的插件
  - 输出：`src/skill/parallel/test/test_personalization_skill_plugin.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节个性化插件测试矩阵
  - 风险点：需构造 mock `AgentWorkspace`
  - 回滚点：删除测试文件

---

## 7. 实现加载决策日志（阶段 7，P1）

**写作指导**：本组对应 design.md 阶段 7，实现结构化加载决策日志，支持事后归因。

### 7.1 实现决策记录数据类
- [ ] **T026** 实现 `SkillLoadDecisionRecord` 数据类，位于 `src/skill/parallel/skill_load_decision_record.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：T003
  - 描述：实现字段 `skillName: String`、`decision: SkillLoadDecision`、`reason: String`、`sessionId: String`、`timestamp: Int64`（用 `DateTime.now().toUnixTimeStamp()` 填充）
  - 输入：T003 的 `SkillLoadDecision`
  - 输出：`src/skill/parallel/skill_load_decision_record.cj`
  - 验收标准：所有字段可读写，`timestamp` 自动填充
  - 风险点：无
  - 回滚点：删除文件即可

### 7.2 实现决策日志记录器
- [ ] **T027** 实现 `SkillLoadDecisionLogger` 类，位于 `src/skill/parallel/skill_load_decision_logger.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：T026
  - 描述：实现 `logDecision(skillName, decision, reason, sessionId)` 方法，构造 `SkillLoadDecisionRecord` 并存入 `ArrayList`，同时通过 `LogUtils.info()` 输出结构化日志（格式 `[SkillLoadDecision] skill={name}, decision={decision}, reason={reason}, session={sessionId}`）；实现 `queryDecisions(sessionId)` 查询指定会话的决策历史
  - 输入：复用 `LogUtils`
  - 输出：`src/skill/parallel/skill_load_decision_logger.cj`
  - 验收标准：
    1. `logDecision()` 后 `queryDecisions()` 可查到记录
    2. 日志格式统一
    3. 不同 `sessionId` 的记录隔离
  - 风险点：内存存储，会话结束后记录丢失，本期不持久化（design.md 2.3.2 节持久化策略）
  - 回滚点：`logDecision()` 改为空实现

### 7.3 接入 SkillContextInjector
- [ ] **T028** 在 `SkillContextInjector` 中接入 `SkillLoadDecisionLogger`，修改 `src/skill/parallel/skill_context_injector.cj`
  - 优先级：P1
  - 依赖任务：T012、T027
  - 描述：在 `injectAlwaysOnSkills()` 和 `injectSkills()` 的各决策点（加载/跳过/淘汰/拒绝）调用 `logDecision()`；将决策记录汇总到 `SkillInjectionResult.decisions` 字段
  - 输入：T027 的日志记录器
  - 输出：修改 `src/skill/parallel/skill_context_injector.cj`
  - 验收标准：
    1. `SkillInjectionResult.decisions` 包含所有加载决策
    2. 决策记录的 `reason` 字段语义明确（`always_on` / `dependency` / `conflict` / `budget_exceeded` / `circular_dependency` / `missing_dependency`）
  - 风险点：无
  - 回滚点：不调用 `logDecision()`，`decisions` 为空数组

### 7.4 决策日志单元测试
- [ ] **T029** 为 `SkillLoadDecisionLogger` 编写单元测试，位于 `src/skill/parallel/test/test_skill_load_decision_logger.cj`
  - 优先级：P1
  - 依赖任务：T027
  - 描述：测试用例覆盖：单决策记录/多决策记录/跨会话查询/空会话查询
  - 输入：T027 的日志记录器
  - 输出：`src/skill/parallel/test/test_skill_load_decision_logger.cj`
  - 验收标准：所有测试用例通过
  - 风险点：无
  - 回滚点：删除测试文件

---

## 8. 实现上下文预算分配（阶段 8，P2）

**写作指导**：本组对应 design.md 阶段 8，实现上下文 token 预算管理，是 P2 完善路径。

### 8.1 实现预算分配结果数据类
- [ ] **T030** 实现 `BudgetAllocationResult` 数据类，位于 `src/skill/parallel/budget_allocation_result.cj`，包名 `magic.skill.parallel`
  - 优先级：P2
  - 依赖任务：无
  - 描述：实现字段 `allocated: Array<String>`（分配成功技能名）、`evicted: Array<String>`（因超限淘汰技能名）、`usedTokens: Int64`（实际使用 token）、`totalBudget: Int64`（总预算）
  - 输入：无
  - 输出：`src/skill/parallel/budget_allocation_result.cj`
  - 验收标准：所有字段可读写，`usedTokens <= totalBudget`
  - 风险点：无
  - 回滚点：删除文件即可

### 8.2 实现预算分配器
- [ ] **T031** 实现 `BudgetAllocator` 类，位于 `src/skill/parallel/budget_allocator.cj`，包名 `magic.skill.parallel`
  - 优先级：P2
  - 依赖任务：T004、T005、T030
  - 描述：实现 `allocate(skills: Array<Skill>): BudgetAllocationResult`；私有方法 `calculateUsedTokens(skills)` 累加 `metadata.context_budget_tokens`；私有方法 `evictForBudget(skills, totalBudget)` 按优先级从低到高淘汰，驻留型技能（`load_policy=always_on`）豁免优先；超限时记录告警
  - 输入：`Array<Skill>` + `SkillParallelConfig`
  - 输出：`src/skill/parallel/budget_allocator.cj`
  - 验收标准：
    1. 预算内时所有技能分配成功
    2. 超限时按 `priority` 从低到高淘汰
    3. 驻留型技能优先保留（淘汰非驻留型）
    4. 全驻留型超限时按 `priority` 从低到高淘汰驻留型
    5. `usedTokens <= totalBudget`
  - 风险点：淘汰顺序需稳定（相同优先级按加载顺序）
  - 回滚点：`allocate()` 返回所有技能分配成功，不淘汰

### 8.3 接入 SkillContextInjector
- [ ] **T032** 在 `SkillContextInjector` 中接入 `BudgetAllocator`，修改 `src/skill/parallel/skill_context_injector.cj`
  - 优先级：P2
  - 依赖任务：T021、T031
  - 描述：在互斥过滤后、渲染前，插入预算分配步骤；当 `config.enableBudgetAllocator = false` 时跳过；淘汰的技能记录决策日志
  - 输入：T031 的预算分配器
  - 输出：修改 `src/skill/parallel/skill_context_injector.cj`
  - 验收标准：
    1. 预算超限时低优先级技能被淘汰
    2. `config.enableBudgetAllocator = false` 时不过滤
    3. 淘汰技能记录决策日志
  - 风险点：无
  - 回滚点：`enableBudgetAllocator = false` 关闭预算管理

### 8.4 预算分配单元测试
- [ ] **T033** 为 `BudgetAllocator` 编写单元测试，位于 `src/skill/parallel/test/test_budget_allocator.cj`
  - 优先级：P2
  - 依赖任务：T031
  - 描述：测试用例覆盖：预算内/超限淘汰低优先级/超限淘汰非驻留型/全驻留型超限/空技能列表/单技能超限
  - 输入：T031 的分配器
  - 输出：`src/skill/parallel/test/test_budget_allocator.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节预算分配测试矩阵
  - 风险点：无
  - 回滚点：删除测试文件

---

## 13. 实现 AutoInjectConfig 配置模块（阶段 9 部分，P0）

**写作指导**：本组对应 design.md 阶段 9 的配置部分，是自动渐进式加载的配置基础。必须先完成配置类和枚举，后续 TaskMatcher 和 SkillAutoInjector 才能依赖。

### 13.1 实现任务匹配策略枚举
- [ ] **T048** 实现 `TaskMatchStrategy` 枚举（`Keyword` / `Semantic` / `Hybrid`），位于 `src/skill/parallel/task_match_strategy.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：无
  - 描述：定义任务匹配策略枚举，`Keyword` 表示关键词匹配（本期实现，Jaccard 系数），`Semantic` 表示语义匹配（未来扩展），`Hybrid` 表示混合匹配（未来扩展）
  - 输入：无
  - 输出：`src/skill/parallel/task_match_strategy.cj`
  - 验收标准：枚举三值齐全，可被 `match` 表达式消费
  - 风险点：无
  - 回滚点：删除文件即可

### 13.2 实现自动注入配置类
- [ ] **T049** 实现 `AutoInjectConfig` 配置类，位于 `src/skill/parallel/auto_inject_config.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T048
  - 描述：实现配置类，字段包括 `autoInjectEnabled: Bool`（默认 true）、`taskMatchThreshold: Float64`（默认 0.6）、`taskMatchStrategy: TaskMatchStrategy`（默认 `Keyword`）、`maxAutoInjectSkills: Int64`（默认 5）、`fallbackToolRetained: Bool`（默认 true）、`dedupOnReinject: Bool`（默认 true）；提供 `static func default(): AutoInjectConfig` 工厂方法
  - 输入：T048 的 `TaskMatchStrategy` 枚举
  - 输出：`src/skill/parallel/auto_inject_config.cj`
  - 验收标准：
    1. 所有字段有默认值，与 design.md 2.1.2 节配置表一致
    2. `default()` 方法返回配置实例
    3. `autoInjectEnabled=false` 时后续自动注入扩展点不生效
  - 风险点：默认值需与 spec.md 6.4 节和 design.md 2.1.2 节一致
  - 回滚点：删除文件即可

### 13.3 AutoInjectConfig 单元测试
- [ ] **T050** 为 `AutoInjectConfig` 编写单元测试，位于 `src/skill/parallel/test/test_auto_inject_config.cj`
  - 优先级：P0
  - 依赖任务：T049
  - 描述：测试用例覆盖：默认配置正确性/自定义配置/阈值边界值（0.0 和 1.0）/`autoInjectEnabled=false` 场景
  - 输入：T049 的配置类
  - 输出：`src/skill/parallel/test/test_auto_inject_config.cj`
  - 验收标准：所有测试用例通过，默认值与 design.md 配置表一致
  - 风险点：无
  - 回滚点：删除测试文件

---

## 14. 实现 TaskMatcher 任务匹配器（阶段 9 部分，P0）

**写作指导**：本组对应 design.md 阶段 9 的匹配器部分，实现用户任务描述与技能 description 的匹配度计算，是任务匹配自动注入的核心算法。

### 14.1 实现任务匹配结果数据类
- [ ] **T051** 实现 `TaskMatchResult` 数据类，位于 `src/skill/parallel/task_match_result.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T048
  - 描述：实现字段 `skillName: String`、`matchScore: Float64`（匹配度 0.0-1.0）、`matchStrategy: TaskMatchStrategy`、`matchedKeywords: Array<String>`（匹配到的关键词，keyword 策略使用）
  - 输入：T048 的 `TaskMatchStrategy` 枚举
  - 输出：`src/skill/parallel/task_match_result.cj`
  - 验收标准：所有字段可读写，`matchScore` 范围 [0.0, 1.0]
  - 风险点：无
  - 回滚点：删除文件即可

### 14.2 实现任务匹配器
- [ ] **T052** 实现 `TaskMatcher` 类，位于 `src/skill/parallel/task_matcher.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T049、T051
  - 描述：实现 `init(config: AutoInjectConfig)`；实现 `match(taskDescription: String, skills: Array<Skill>): Array<TaskMatchResult>` 主入口：① 按 `config.taskMatchStrategy` 调用对应匹配算法；② 过滤匹配度超过 `config.taskMatchThreshold` 的技能；③ 按匹配度降序排序；④ 取前 `config.maxAutoInjectSkills` 个；实现 `matchByKeyword(taskDescription, skillDescription): Float64` 关键词匹配：分词后计算 Jaccard 系数（|交集| / |并集|）；实现 `matchBySemantic(taskDescription, skillDescription): Float64` 语义匹配占位方法（本期返回 0.0，记录 TODO）
  - 输入：用户任务描述 `String` + 候选技能 `Array<Skill>`
  - 输出：`src/skill/parallel/task_matcher.cj`
  - 验收标准：
    1. 完全匹配时 `matchScore = 1.0`
    2. 无交集时 `matchScore = 0.0`
    3. 返回数组按 `matchScore` 降序排序
    4. 返回数组长度 ≤ `config.maxAutoInjectSkills`
    5. 匹配度低于阈值的技能不返回
    6. 空输入返回空数组
  - 风险点：分词算法需处理中英文混合（仓颉代码场景常见），本期可按空格和标点分词，中文按字分词
  - 回滚点：`match()` 返回空数组，不自动注入任何技能

### 14.3 TaskMatcher 单元测试
- [ ] **T053** 为 `TaskMatcher` 编写单元测试，位于 `src/skill/parallel/test/test_task_matcher.cj`
  - 优先级：P0
  - 依赖任务：T052
  - 描述：测试用例覆盖：高匹配/低匹配/无匹配/阈值边界（恰好等于 0.6）/多技能排序/上限截断（超过 5 个只返 5 个）/空任务描述/空技能列表/中英文混合分词
  - 输入：T052 的匹配器
  - 输出：`src/skill/parallel/test/test_task_matcher.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节 TaskMatcher 测试矩阵
  - 风险点：Jaccard 系数计算需注意分母为 0 的情况（两个空词集）
  - 回滚点：删除测试文件

---

## 15. 实现 SkillAutoInjector 自动注入器（阶段 12，P0）

**写作指导**：本组对应 design.md 阶段 12，是补充需求的核心组件。编排初始化/任务匹配/显式调用三种自动注入场景，修复"渐进式加载设计漂移"。

### 15.1 实现 SkillAutoInjector 类骨架
- [ ] **T054** 实现 `SkillAutoInjector` 类骨架，位于 `src/skill/parallel/skill_auto_injector.cj`，包名 `magic.skill.parallel`
  - 优先级：P0
  - 依赖任务：T011、T049、T052、T063、T066
  - 描述：实现 `init(contextInjector: SkillContextInjector, taskMatcher: TaskMatcher, budgetManager: BudgetManager, decisionRecorder: InjectDecisionRecorder, config: AutoInjectConfig)`；维护 `injectedCache: HashMap<String, String>` 字段（键为 `{sessionId}:{skillName}`，值为已注入的完整内容，用于去重检查）
  - 输入：T011 的 `SkillContextInjector`、T052 的 `TaskMatcher`、T066 的 `BudgetManager`、T063 的 `InjectDecisionRecorder`、T049 的 `AutoInjectConfig`
  - 输出：`src/skill/parallel/skill_auto_injector.cj`
  - 验收标准：可构造实例，`injectedCache` 初始为空
  - 风险点：依赖组件较多，注意构造顺序（需在 `SkillContextInjector` 之后创建）
  - 回滚点：删除文件即可

### 15.2 实现 injectOnInitialization 方法
- [ ] **T055** 在 `SkillAutoInjector` 中实现 `injectOnInitialization(sessionId: String): SkillInjectionResult` 方法
  - 优先级：P0
  - 依赖任务：T054、T012
  - 描述：实现 Agent 初始化阶段自动注入：① 检查 `config.autoInjectEnabled`，为 false 时返回空结果；② 调用 `contextInjector.injectAlwaysOnSkills(sessionId)` 收集驻留型技能并计算依赖闭包；③ 调用 `budgetManager.allocateWithDegrade()` 预算分配带降级；④ 调用 `SkillContentRenderer.renderMultipleSkills()` 渲染存活技能完整 instructions；⑤ 将注入的技能写入 `injectedCache`；⑥ 调用 `decisionRecorder.logInjectionDecision()` 记录决策（`injectSource=AutoInit`，`contentLevel=Full` 或 `Frontmatter`）；⑦ 返回 `SkillInjectionResult`
  - 输入：`sessionId: String`
  - 输出：`SkillInjectionResult`（含完整 instructions 上下文）
  - 验收标准：
    1. `load_policy=always_on` 技能完整 instructions 自动注入上下文
    2. 驻留型技能的依赖闭包完整 instructions 同时注入
    3. 预算超限时低优先级技能降级为 frontmatter 摘要（`contentLevel=Frontmatter`）
    4. `autoInjectEnabled=false` 时返回空结果
    5. 注入的技能写入 `injectedCache`
  - 风险点：与 `SkillContextInjector.injectAlwaysOnSkills()` 的职责区分——后者负责收集和依赖闭包，前者负责自动注入编排和决策记录
  - 回滚点：`autoInjectEnabled=false` 时返回空结果，回退为纯 `get_skill_content` 工具模式

### 15.3 实现 injectOnUserMessage 方法
- [ ] **T056** 在 `SkillAutoInjector` 中实现 `injectOnUserMessage(taskDescription: String, sessionId: String): SkillInjectionResult` 方法
  - 优先级：P0
  - 依赖任务：T054、T055、T052
  - 描述：实现用户消息阶段任务匹配自动注入：① 检查 `config.autoInjectEnabled`；② 调用 `taskMatcher.match(taskDescription, availableSkills)` 匹配技能；③ 无匹配时返回空结果（仅保留 frontmatter 目录，agent 可后备调用）；④ 收集高匹配度技能，调用 `contextInjector` 计算依赖闭包；⑤ 调用 `budgetManager.allocateWithDegrade()` 预算检查；⑥ 渲染完整 instructions；⑦ 追加注入上下文（不覆盖初始化阶段已注入的内容）；⑧ 写入 `injectedCache`；⑨ 记录决策（`injectSource=AutoTaskMatch`）
  - 输入：`taskDescription: String`、`sessionId: String`
  - 输出：`SkillInjectionResult`（含匹配技能的完整 instructions）
  - 验收标准：
    1. 高匹配度技能完整 instructions 自动注入上下文
    2. 无匹配时返回空结果，不注入任何技能完整内容
    3. 匹配技能的依赖闭包同时注入
    4. 追加注入不覆盖初始化阶段已注入内容
    5. 注入的技能写入 `injectedCache`
  - 风险点：追加注入需与初始化注入去重（同一技能不重复注入）
  - 回滚点：返回空结果，agent 通过 `get_skill_content` 后备工具获取

### 15.4 实现 injectExplicit 方法
- [ ] **T057** 在 `SkillAutoInjector` 中实现 `injectExplicit(skillName: String, sessionId: String): SkillInjectionResult` 方法
  - 优先级：P0
  - 依赖任务：T054、T013
  - 描述：实现用户显式 `/skill-name` 调用自动注入：① 检查 `config.autoInjectEnabled`；② 直接加载该技能完整 instructions（调用 `contextInjector.injectSkills([skillName], sessionId)`）；③ 依赖闭包自动注入（`injectSource=AutoDependency`）；④ 预算检查；⑤ 渲染完整 instructions；⑥ 写入 `injectedCache`；⑦ 记录决策（`injectSource=AutoInit`，因为显式调用是用户主动触发）；⑧ 返回结果，agent 无需再调用 `get_skill_content`
  - 输入：`skillName: String`、`sessionId: String`
  - 输出：`SkillInjectionResult`
  - 验收标准：
    1. 用户输入 `/skill-name` 后该技能完整 instructions 自动注入
    2. 该技能的依赖闭包同时注入
    3. agent 无需再调用 `get_skill_content` 获取该技能
  - 风险点：技能名不存在时需记录告警并返回空结果
  - 回滚点：返回空结果，agent 通过 `get_skill_content` 后备工具获取

### 15.5 实现去重检查方法
- [ ] **T058** 在 `SkillAutoInjector` 中实现 `isAlreadyInjected(skillName: String, sessionId: String): Bool` 和 `getInjectedCache(skillName: String, sessionId: String): Option<String>` 方法
  - 优先级：P1
  - 依赖任务：T054
  - 描述：`isAlreadyInjected()` 检查 `injectedCache` 中是否存在键 `{sessionId}:{skillName}`；`getInjectedCache()` 返回缓存内容（`Some`）或 `None`；供 `GetSkillContentTool` 去重使用
  - 输入：`skillName: String`、`sessionId: String`
  - 输出：`Bool` / `Option<String>`
  - 验收标准：
    1. 已自动注入的技能 `isAlreadyInjected()` 返回 true
    2. 未自动注入的技能返回 false
    3. `getInjectedCache()` 对已注入技能返回 `Some(内容)`
    4. `dedupOnReinject=false` 时 `isAlreadyInjected()` 始终返回 false（关闭去重）
  - 风险点：缓存键需包含 `sessionId` 避免跨会话污染
  - 回滚点：`isAlreadyInjected()` 始终返回 false，去重不生效

### 15.6 SkillAutoInjector 单元测试
- [ ] **T059** 为 `SkillAutoInjector` 编写单元测试，位于 `src/skill/parallel/test/test_skill_auto_injector.cj`
  - 优先级：P0
  - 依赖任务：T055、T056、T057、T058
  - 描述：测试用例覆盖：初始化注入有驻留型/无驻留型/驻留型依赖闭包/驻留型互斥；任务匹配注入有匹配/无匹配/匹配数超上限/匹配技能依赖闭包；显式调用注入正常/技能不存在；去重检查已注入/未注入/去重开关关闭；`autoInjectEnabled=false` 全部回退
  - 输入：T055-T058 的方法
  - 输出：`src/skill/parallel/test/test_skill_auto_injector.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节 SkillAutoInjector 测试矩阵
  - 风险点：需构造 mock `SkillContextInjector`、mock `TaskMatcher`、mock `BudgetManager`、mock `InjectDecisionRecorder`
  - 回滚点：删除测试文件

---

## 16. 实现 InjectDecisionRecorder 注入决策记录（阶段 10，P1）

**写作指导**：本组对应 design.md 阶段 10，扩展 `SkillLoadDecisionLogger`，新增 `injectSource` 和 `contentLevel` 字段，支持区分"自动注入"与"agent 主动调用"、"完整内容"与"摘要"。

### 16.1 实现注入来源和内容级别枚举
- [ ] **T060** 实现 `InjectSource` 枚举（`AutoInit` / `AutoTaskMatch` / `AutoDependency` / `AgentToolCall`），位于 `src/skill/parallel/inject_source.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：无
  - 描述：定义注入来源枚举，`AutoInit` 表示 Agent 初始化自动注入，`AutoTaskMatch` 表示任务匹配自动注入，`AutoDependency` 表示依赖闭包自动注入，`AgentToolCall` 表示 agent 主动调用后备工具
  - 输入：无
  - 输出：`src/skill/parallel/inject_source.cj`
  - 验收标准：枚举四值齐全
  - 风险点：无
  - 回滚点：删除文件即可

- [ ] **T061** 实现 `ContentLevel` 枚举（`Full` / `Frontmatter`），位于 `src/skill/parallel/content_level.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：无
  - 描述：定义内容级别枚举，`Full` 表示完整 instructions，`Frontmatter` 表示仅 frontmatter 摘要（预算降级时使用）
  - 输入：无
  - 输出：`src/skill/parallel/content_level.cj`
  - 验收标准：枚举两值齐全
  - 风险点：无
  - 回滚点：删除文件即可

### 16.2 实现注入决策记录数据类
- [ ] **T062** 实现 `InjectionDecisionRecord` 数据类，位于 `src/skill/parallel/injection_decision_record.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：T003、T060、T061
  - 描述：扩展 `SkillLoadDecisionRecord`，新增字段 `injectSource: InjectSource`、`contentLevel: ContentLevel`；原有字段 `skillName` / `decision` / `reason` / `sessionId` / `timestamp` 保持兼容
  - 输入：T003 的 `SkillLoadDecision`、T060 的 `InjectSource`、T061 的 `ContentLevel`
  - 输出：`src/skill/parallel/injection_decision_record.cj`
  - 验收标准：所有字段可读写，`timestamp` 自动填充
  - 风险点：与 `SkillLoadDecisionRecord` 的兼容性——可通过继承或组合实现
  - 回滚点：删除文件即可

### 16.3 实现注入决策记录器
- [ ] **T063** 实现 `InjectDecisionRecorder` 类，位于 `src/skill/parallel/inject_decision_recorder.cj`，包名 `magic.skill.parallel`
  - 优先级：P1
  - 依赖任务：T062
  - 描述：实现 `logInjectionDecision(skillName, decision, reason, sessionId, injectSource, contentLevel)` 方法，构造 `InjectionDecisionRecord` 并存入 `ArrayList`，同时通过 `LogUtils.info()` 输出结构化日志（格式 `[InjectDecision] skill={name}, decision={decision}, reason={reason}, session={sessionId}, source={injectSource}, level={contentLevel}`）；实现 `queryByInjectSource(sessionId, injectSource)` 按注入来源查询；实现 `queryAll(sessionId)` 查询会话所有注入决策
  - 输入：复用 `LogUtils`
  - 输出：`src/skill/parallel/inject_decision_recorder.cj`
  - 验收标准：
    1. `logInjectionDecision()` 后 `queryAll()` 可查到记录
    2. `queryByInjectSource()` 可按来源过滤（如只查自动注入的）
    3. 日志格式统一，含 `source` 和 `level` 字段
    4. 不同 `sessionId` 的记录隔离
  - 风险点：内存存储，会话结束后记录丢失，本期不持久化
  - 回滚点：`logInjectionDecision()` 改为空实现

### 16.4 InjectDecisionRecorder 单元测试
- [ ] **T064** 为 `InjectDecisionRecorder` 编写单元测试，位于 `src/skill/parallel/test/test_inject_decision_recorder.cj`
  - 优先级：P1
  - 依赖任务：T063
  - 描述：测试用例覆盖：单决策记录/多决策记录/按来源查询（AutoInit/AutoTaskMatch/AgentToolCall）/全量查询/跨会话查询/空会话查询
  - 输入：T063 的记录器
  - 输出：`src/skill/parallel/test/test_inject_decision_recorder.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节 InjectDecisionRecorder 测试矩阵
  - 风险点：无
  - 回滚点：删除测试文件

---

## 17. 实现 BudgetManager 预算管理器带降级（阶段 11，P2）

**写作指导**：本组对应 design.md 阶段 11，扩展 `BudgetAllocator`（TG08），新增"降级为 frontmatter 摘要"能力。预算超限时先降级再淘汰，是补充需求 5.6.1 第 5 条的实现。

### 17.1 扩展预算分配结果数据类
- [ ] **T065** 扩展 `BudgetAllocationResult` 数据类，修改 `src/skill/parallel/budget_allocation_result.cj`
  - 优先级：P2
  - 依赖任务：T030、T061
  - 描述：在原有字段（`allocated` / `evicted` / `usedTokens` / `totalBudget`）基础上新增 `degraded: Array<String>`（降级为 frontmatter 的技能名）和 `contentLevels: HashMap<String, ContentLevel>`（技能名 → 内容级别）；保持向后兼容，原有字段语义不变
  - 输入：T030 的 `BudgetAllocationResult`、T061 的 `ContentLevel`
  - 输出：修改 `src/skill/parallel/budget_allocation_result.cj`
  - 验收标准：
    1. 新增字段可读写
    2. 原有字段语义不变
    3. `contentLevels` 标注每个技能的内容级别（`Full` 或 `Frontmatter`）
  - 风险点：向后兼容——原有使用 `BudgetAllocationResult` 的代码不需修改
  - 回滚点：新增字段设为空数组/空 map

### 17.2 实现 BudgetManager 类
- [ ] **T066** 实现 `BudgetManager` 类，位于 `src/skill/parallel/budget_manager.cj`，包名 `magic.skill.parallel`
  - 优先级：P2
  - 依赖任务：T031、T065、T061
  - 描述：实现 `init(config: SkillParallelConfig)`；实现 `allocateWithDegrade(skills: Array<Skill>, totalBudget: Int64): BudgetAllocationResult`：① 累计 `context_budget_tokens`，预算内时全部 `allocated` + `contentLevel=Full`；② 超限时按 `priority` 从低到高尝试降级为 frontmatter（调用 `degradeToFrontmatter()`），降级后重新计算 token；③ 降级后仍超限则完全淘汰（`evicted`）；④ 驻留型技能优先保留完整内容；实现 `degradeToFrontmatter(skill: Skill): Skill`：保留 name + description，清空 instructions，标记 `contentLevel=Frontmatter`；实现 `calculateFullTokens(skills)` 和 `calculateFrontmatterTokens(skills)` 计算 token 数
  - 输入：T031 的 `BudgetAllocator`（可继承或组合）、T065 的扩展结果类
  - 输出：`src/skill/parallel/budget_manager.cj`
  - 验收标准：
    1. 预算内时所有技能 `contentLevel=Full`
    2. 超限时低优先级技能先降级为 `Frontmatter`，`degraded` 数组含被降级技能名
    3. 降级后仍超限则完全淘汰，`evicted` 含被淘汰技能名
    4. 驻留型技能优先保留 `Full`
    5. `usedTokens <= totalBudget`
    6. `degradeToFrontmatter()` 返回的技能 instructions 为空，name/description 保留
  - 风险点：frontmatter token 计算需估算（name + description 的 token 数），本期可用字符数 / 4 估算
  - 回滚点：`allocateWithDegrade()` 退化为 `BudgetAllocator.allocate()`（不降级，直接淘汰）

### 17.3 接入 SkillContextInjector
- [ ] **T067** 在 `SkillContextInjector` 中接入 `BudgetManager`（可选），修改 `src/skill/parallel/skill_context_injector.cj`
  - 优先级：P2
  - 依赖任务：T032、T066
  - 描述：在 `SkillContextInjector` 中新增 `budgetManager: Option<BudgetManager>` 字段；当传入 `BudgetManager` 时使用 `allocateWithDegrade()` 替代 `BudgetAllocator.allocate()`；降级的技能渲染时仅注入 frontmatter（调用 `SkillCatalogRenderer` 渲染摘要而非 `SkillContentRenderer` 渲染完整内容）
  - 输入：T066 的 `BudgetManager`
  - 输出：修改 `src/skill/parallel/skill_context_injector.cj`
  - 验收标准：
    1. 传入 `BudgetManager` 时使用带降级的预算分配
    2. 降级技能仅注入 frontmatter 摘要
    3. 不传入时退回原 `BudgetAllocator` 行为
  - 风险点：降级技能的渲染需区分完整内容和摘要
  - 回滚点：`budgetManager` 设为 `None`，退回原预算分配行为

### 17.4 BudgetManager 单元测试
- [ ] **T068** 为 `BudgetManager` 编写单元测试，位于 `src/skill/parallel/test/test_budget_manager.cj`
  - 优先级：P2
  - 依赖任务：T066
  - 描述：测试用例覆盖：预算内全 Full/超限降级低优先级/超限淘汰非驻留型/全降级仍超限则淘汰/驻留型优先保留 Full/空技能列表/`degradeToFrontmatter` 返回正确
  - 输入：T066 的预算管理器
  - 输出：`src/skill/parallel/test/test_budget_manager.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.1 节 BudgetManager 测试矩阵
  - 风险点：无
  - 回滚点：删除测试文件

---

## 18. 漂移修复：WebMCPProtocol/WsChatController/GetSkillContentTool 集成（阶段 13/14/15，P0）

**写作指导**：本组对应 design.md 阶段 13/14/15，是漂移修复的接入点。将 `SkillAutoInjector` 接入 `WebMCPProtocol` 和 `WsChatController`，替换第3段"agent 主动调用"漂移；扩展 `GetSkillContentTool` 去重机制保证向后兼容。

### 18.1 WebMCPProtocol 接入自动注入
- [ ] **T069** 在 `WebMCPProtocol.buildAgentSystemPrompt()` 中接入 `SkillAutoInjector.injectOnInitialization()`，修改 `src/protocol/web_mcp_protocol.cj`
  - 优先级：P0
  - 依赖任务：T055
  - 描述：修改 `buildAgentSystemPrompt()` 方法体 L1963-1983 的第3段注入逻辑：① 第1段（frontmatter）和第2段（`get_skill_content` 工具说明）保留不变；② 第3段原"agent 主动调用工具获取"替换为调用 `skillAutoInjector.injectOnInitialization(sessionId)` 自动注入驻留型技能完整 instructions；③ 将返回的 `SkillInjectionResult.injectedContext` 追加到系统提示；④ `autoInjectEnabled=false` 时不调用自动注入，退回原第3段行为（注释引导 agent 调用 `get_skill_content`）
  - 输入：T055 的 `injectOnInitialization()` 方法
  - 输出：修改 `src/protocol/web_mcp_protocol.cj`
  - 验收标准：
    1. Agent 初始化后驻留型技能完整 instructions 在系统提示中
    2. agent 无需调用 `get_skill_content` 获取驻留型技能
    3. 第1段和第2段注入行为不变
    4. `autoInjectEnabled=false` 时退回原"三段渐进式加载"逻辑
  - 风险点：系统提示长度增加，需确保不超模型上下文窗口（由 `BudgetManager` 控制）
  - 回滚点：`autoInjectEnabled=false` 时 `buildAgentSystemPrompt()` 退回原逻辑

### 18.2 WsChatController 接入任务匹配注入
- [ ] **T070** 在 `WsChatController` 用户消息处理中接入 `SkillAutoInjector.injectOnUserMessage()`，修改 `src/controller/ws_chat_controller.cj`
  - 优先级：P0
  - 依赖任务：T056
  - 描述：在 `WsChatController` 用户消息处理阶段（L412-423 附近）：① 解析用户消息文本作为 `taskDescription`；② 检测 `/skill-name` 显式调用语法，若匹配则调用 `skillAutoInjector.injectExplicit(skillName, sessionId)`；③ 否则调用 `skillAutoInjector.injectOnUserMessage(taskDescription, sessionId)` 任务匹配自动注入；④ 将返回的 `injectedContext` 追加注入到流式响应的上下文；⑤ 自动注入需在首帧前完成（延迟 < 100ms）；⑥ `autoInjectEnabled=false` 时不调用，退回原行为
  - 输入：T056 的 `injectOnUserMessage()` 和 T057 的 `injectExplicit()` 方法
  - 输出：修改 `src/controller/ws_chat_controller.cj`
  - 验收标准：
    1. 用户输入任务后高匹配度技能完整 instructions 自动注入上下文
    2. 用户输入 `/skill-name` 后该技能完整 instructions 自动注入
    3. 自动注入在首帧前完成
    4. `autoInjectEnabled=false` 时退回原行为
    5. 与 `WebMCPProtocol` 的注入逻辑统一到 `SkillAutoInjector`，避免双重注入
  - 风险点：流式响应场景下自动注入需在首帧前完成；与 `WebMCPProtocol` 双重注入需通过去重机制避免
  - 回滚点：`autoInjectEnabled=false` 时用户消息处理退回原行为

### 18.3 GetSkillContentTool 扩展去重机制
- [ ] **T071** 扩展 `GetSkillContentTool` 新增去重机制，修改 `src/tool/get_skill_content_tool.cj`
  - 优先级：P1
  - 依赖任务：T058
  - 描述：① 新增 `setAutoInjector(injector: SkillAutoInjector)` 方法（静态注入引用）；② 在 `execute()` 方法内增加去重检查：调用 `autoInjector.isAlreadyInjected(skillName, sessionId)`，若已注入则调用 `getInjectedCache()` 返回缓存内容，记录 debug 日志"技能 X 已自动注入，返回缓存"；③ 未注入时正常获取技能完整内容（原行为）；④ `dedupOnReinject=false` 时跳过去重检查；⑤ 去重检查失败时降级为原行为（不报错）
  - 输入：T058 的 `isAlreadyInjected()` 和 `getInjectedCache()` 方法
  - 输出：修改 `src/tool/get_skill_content_tool.cj`
  - 验收标准：
    1. 已自动注入的技能调用 `get_skill_content` 返回缓存内容
    2. 未自动注入的技能正常获取
    3. 去重时记录 debug 日志
    4. `dedupOnReinject=false` 时去重不生效，退回原行为
    5. 去重检查失败时不报错，降级为原行为
    6. 不修改工具签名（`execute()` 签名不变）
  - 风险点：`setAutoInjector()` 需在工具使用前调用，注意初始化顺序
  - 回滚点：`dedupOnReinject=false` 或不调用 `setAutoInjector()` 时退回原行为

### 18.4 漂移修复单元测试
- [ ] **T072** 为漂移修复编写单元测试，位于 `src/skill/parallel/test/test_drift_fix.cj`
  - 优先级：P0
  - 依赖任务：T069、T070、T071
  - 描述：测试用例覆盖：WebMCPProtocol 注入驻留型完整内容/`autoInjectEnabled=false` 退回原逻辑；WsChatController 任务匹配注入/显式调用注入/无匹配不注入；GetSkillContentTool 去重返回缓存/未注入正常获取/去重开关关闭
  - 输入：T069-T071 的修改
  - 输出：`src/skill/parallel/test/test_drift_fix.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.2 节漂移修复集成测试矩阵
  - 风险点：需构造 mock `WebMCPProtocol` 和 mock `WsChatController` 上下文
  - 回滚点：删除测试文件

---

## 19. 修复 buildAgentFromDefinition 空技能管理器（阶段 16，P1）

**写作指导**：本组对应 design.md 阶段 16，修复 `AgentRuntimeBridge.buildAgentFromDefinition()` L184 创建空 `CompositeSkillToolManager()` 的缺陷，使自动注入流程在该路径也能生效。

### 19.1 修复空技能管理器
- [ ] **T073** 修复 `AgentRuntimeBridge.buildAgentFromDefinition()` 空技能管理器问题，修改 `src/runtime/agent_runtime_bridge.cj`
  - 优先级：P1
  - 依赖任务：T055
  - 描述：修改 `buildAgentFromDefinition()` L184 附近：① 检测创建的 `CompositeSkillToolManager()` 是否为空（`availableSkills` 为空）；② 为空时尝试复用 `buildAgent()` 路径的技能加载逻辑（通过 `ProgressiveSkillLoader` 加载技能目录）；③ 若复用失败则记录告警"Agent 创建时技能管理器为空，自动渐进式加载未生效"，跳过自动注入流程；④ 非空时正常接入 `SkillAutoInjector`
  - 输入：T055 的 `injectOnInitialization()` 方法
  - 输出：修改 `src/runtime/agent_runtime_bridge.cj`
  - 验收标准：
    1. 通过 `buildAgentFromDefinition()` 创建 agent 时技能管理器非空（或记录告警）
    2. 技能管理器非空时自动注入生效
    3. 技能管理器为空时记录告警，不阻断 agent 创建
    4. 不影响 `buildAgent()` 路径的现有行为
  - 风险点：复用 `buildAgent()` 路径技能加载逻辑需注意两路径的参数差异
  - 回滚点：修复失败时退回原空技能管理器行为，仅记录告警

### 19.2 buildAgentFromDefinition 修复单元测试
- [ ] **T074** 为 `buildAgentFromDefinition` 修复编写单元测试，位于 `src/runtime/test/test_build_agent_from_definition.cj`
  - 优先级：P1
  - 依赖任务：T073
  - 描述：测试用例覆盖：技能管理器非空时自动注入生效/技能管理器为空时记录告警不崩溃/复用 buildAgent 路径技能加载成功/`buildAgent()` 路径行为不变
  - 输入：T073 的修复
  - 输出：`src/runtime/test/test_build_agent_from_definition.cj`
  - 验收标准：所有测试用例通过，覆盖 design.md 2.6.2 节 buildAgentFromDefinition 修复测试矩阵
  - 风险点：需构造 mock `AgentRuntimeBridge` 上下文
  - 回滚点：删除测试文件

---

## 20. 自动渐进式加载集成测试（补充需求 5.6 节）

**写作指导**：本组对应 design.md 2.6.2 节补充需求集成测试，验证漂移修复端到端用户操作路径和向后兼容性。

### 20.1 驻留型完整内容自动注入集成测试
- [ ] **T075** 编写驻留型技能完整内容自动注入集成测试，位于 `src/skill/parallel/test/integration/test_always_on_auto_inject.cj`
  - 优先级：P0
  - 依赖任务：T055、T069
  - 描述：验证场景：Agent 初始化后 `load_policy=always_on` 技能完整 instructions 在系统提示中，agent 无需调用 `get_skill_content`
  - 输入：T055 的 `injectOnInitialization`、T069 的 WebMCPProtocol 集成
  - 输出：`src/skill/parallel/test/integration/test_always_on_auto_inject.cj`
  - 验收标准：系统提示含 `<skill_content>` 块，包含驻留型技能完整 instructions
  - 风险点：需构造完整的 `WebMCPProtocol` + 驻留型技能实例
  - 回滚点：删除测试文件

### 20.2 任务匹配自动注入集成测试
- [ ] **T076** 编写任务匹配自动注入集成测试，位于 `src/skill/parallel/test/integration/test_task_match_auto_inject.cj`
  - 优先级：P0
  - 依赖任务：T056、T070
  - 描述：验证场景：用户输入任务"编写仓颉代码实现用户登录"，高匹配度技能（如 cangjie-coder）完整 instructions 自动注入上下文
  - 输入：T056 的 `injectOnUserMessage`、T070 的 WsChatController 集成
  - 输出：`src/skill/parallel/test/integration/test_task_match_auto_inject.cj`
  - 验收标准：匹配度超过阈值的技能完整 instructions 注入上下文，低匹配度技能不注入
  - 风险点：任务匹配需构造真实的技能 description
  - 回滚点：删除测试文件

### 20.3 用户显式调用自动注入集成测试
- [ ] **T077** 编写用户显式 `/skill-name` 调用自动注入集成测试，位于 `src/skill/parallel/test/integration/test_explicit_auto_inject.cj`
  - 优先级：P0
  - 依赖任务：T057、T070
  - 描述：验证场景：用户输入 `/cangjie-coder`，该技能完整 instructions 自动注入上下文，agent 无需再调用 `get_skill_content`
  - 输入：T057 的 `injectExplicit`、T070 的 WsChatController 集成
  - 输出：`src/skill/parallel/test/integration/test_explicit_auto_inject.cj`
  - 验收标准：显式调用的技能完整 instructions 注入上下文
  - 风险点：需解析 `/skill-name` 语法
  - 回滚点：删除测试文件

### 20.4 向后兼容后备机制集成测试
- [ ] **T078** 编写向后兼容 `get_skill_content` 后备机制集成测试，位于 `src/skill/parallel/test/integration/test_backward_compat_fallback.cj`
  - 优先级：P1
  - 依赖任务：T071
  - 描述：验证场景：自动注入生效后 agent 仍调用 `get_skill_content` 正常返回，不报错；已自动注入的技能返回缓存内容
  - 输入：T071 的 GetSkillContentTool 去重
  - 输出：`src/skill/parallel/test/integration/test_backward_compat_fallback.cj`
  - 验收标准：
    1. 自动注入生效后 `get_skill_content` 正常返回
    2. 已自动注入的技能返回缓存内容
    3. 未自动注入的技能正常获取
  - 风险点：无
  - 回滚点：删除测试文件

### 20.5 预算降级为摘要集成测试
- [ ] **T079** 编写预算降级为 frontmatter 摘要集成测试，位于 `src/skill/parallel/test/integration/test_budget_degrade.cj`
  - 优先级：P2
  - 依赖任务：T066、T067
  - 描述：验证场景：驻留型 + 任务匹配技能完整内容总和超过上下文预算，低优先级技能降级为 frontmatter 摘要注入，高优先级保留完整内容
  - 输入：T066 的 `BudgetManager`、T067 的接入
  - 输出：`src/skill/parallel/test/integration/test_budget_degrade.cj`
  - 验收标准：
    1. 预算超限时低优先级技能降级为 frontmatter 摘要
    2. 高优先级技能保留完整 instructions
    3. 降级技能的 `contentLevel=Frontmatter`
  - 风险点：需构造超预算场景
  - 回滚点：删除测试文件

### 20.6 auto_inject_enabled=false 回退集成测试
- [ ] **T080** 编写 `auto_inject_enabled=false` 回退集成测试，位于 `src/skill/parallel/test/integration/test_auto_inject_disabled.cj`
  - 优先级：P1
  - 依赖任务：T069、T070
  - 描述：验证场景：关闭自动注入后退回纯 `get_skill_content` 工具模式，行为与漂移前一致——系统提示仅含 frontmatter + 工具说明，agent 需主动调用 `get_skill_content` 获取完整内容
  - 输入：T069、T070 的扩展
  - 输出：`src/skill/parallel/test/integration/test_auto_inject_disabled.cj`
  - 验收标准：
    1. `autoInjectEnabled=false` 时系统提示不含 `<skill_content>` 完整内容
    2. 系统提示仍含 frontmatter 和 `get_skill_content` 工具说明
    3. 行为与补充需求前一致
  - 风险点：无
  - 回滚点：删除测试文件

### 20.7 自动注入性能测试
- [ ] **T081** 编写自动注入性能测试，位于 `src/skill/parallel/test/perf/test_auto_inject_latency.cj`
  - 优先级：P2
  - 依赖任务：T055、T056
  - 描述：测试指标：① 任务匹配耗时（50 技能 keyword 匹配，目标 < 50ms）；② 自动注入端到端延迟（初始化注入 + 任务匹配注入总耗时，目标 < 200ms）；③ 去重检查耗时（缓存命中检查，目标 < 5ms）
  - 输入：T055、T056 的方法
  - 输出：`src/skill/parallel/test/perf/test_auto_inject_latency.cj`
  - 验收标准：三项性能指标均达标
  - 风险点：测试环境性能波动，需取多次平均值
  - 回滚点：删除测试文件

### 20.8 WebMCPProtocol/WsChatController 双重注入防护集成测试
- [ ] **T082** 编写双重注入防护集成测试，位于 `src/skill/parallel/test/integration/test_no_double_inject.cj`
  - 优先级：P1
  - 依赖任务：T069、T070、T071
  - 描述：验证场景：`WebMCPProtocol` 初始化注入 + `WsChatController` 任务匹配注入同一技能时不重复注入，通过 `injectedCache` 去重保证幂等性
  - 输入：T069-T071 的修改
  - 输出：`src/skill/parallel/test/integration/test_no_double_inject.cj`
  - 验收标准：同一技能在上下文中只出现一次，不重复注入
  - 风险点：双重注入是 design.md 2.7 节风险点，需通过去重机制保证
  - 回滚点：删除测试文件

---

## 9. 端到端集成测试

**写作指导**：本组对应 design.md 2.6.2 节集成测试，验证跨模块协作和端到端用户操作路径。补充需求 5.6 节的集成测试已在 TG20 完成，本组聚焦原有路径的集成测试 + 补充需求回归测试。

### 9.1 多技能并行注入集成测试
- [ ] **T034** 编写多技能并行注入集成测试，位于 `src/skill/parallel/test/integration/test_multi_skill_parallel.cj`
  - 优先级：P1
  - 依赖任务：T018、T022、T025
  - 描述：验证场景：Agent 初始化 + personalization 技能自动注入 + sdd + cangjie-coder 三技能同时存在于上下文
  - 输入：T018 的 `SkillAwareAgent` 扩展
  - 输出：`src/skill/parallel/test/integration/test_multi_skill_parallel.cj`
  - 验收标准：三技能同时出现在 `SkillInjectionResult.activeSkills` 和 `injectedContext` 中
  - 风险点：需构造完整的 `CompositeSkillToolManager` + 多个 `Skill` 实例
  - 回滚点：删除测试文件

- [ ] **T035** 编写循环依赖检测集成测试，位于 `src/skill/parallel/test/integration/test_circular_dependency.cj`
  - 优先级：P1
  - 依赖任务：T015
  - 描述：验证场景：A depends_on B，B depends_on A，加载 A 时报错且不崩溃
  - 输入：T015 的注入核心
  - 输出：`src/skill/parallel/test/integration/test_circular_dependency.cj`
  - 验收标准：`SkillInjectionResult.status = Failed`，`errorMessage` 含循环路径 "A → B → A"
  - 风险点：无
  - 回滚点：删除测试文件

- [ ] **T036** 编写现有 49 个技能兼容性回归测试，位于 `src/skill/parallel/test/integration/test_backward_compatibility.cj`
  - 优先级：P1
  - 依赖任务：T018
  - 描述：验证场景：现有 49 个技能无扩展字段时按默认值处理（`load_policy=on_demand` / `priority=medium`），不报错；`SkillAwareAgent._registerSkillsAsTools()` 行为不变
  - 输入：T018 的 `SkillAwareAgent` 扩展
  - 输出：`src/skill/parallel/test/integration/test_backward_compatibility.cj`
  - 验收标准：
    1. 现有技能无扩展字段时正常加载
    2. `_registerSkillsAsTools()` 注册行为不变
    3. 不传 `skillParallelConfig` 时 Agent 行为完全不变
  - 风险点：需加载真实技能目录或构造 49 个 mock 技能
  - 回滚点：删除测试文件

---

## 10. 性能测试

**写作指导**：本组对应 design.md 2.6.3 节性能测试，验证 DFX 约束的延迟指标。补充需求 5.6 节的性能测试（任务匹配耗时/自动注入端到端延迟/去重检查耗时）已在 T081 完成，本组聚焦原有路径的性能指标。

### 10.1 性能指标验证
- [ ] **T037** 编写上下文注入延迟性能测试，位于 `src/skill/parallel/test/perf/test_injection_latency.cj`
  - 优先级：P2
  - 依赖任务：T015
  - 描述：测试 10 个技能注入耗时，目标 < 100ms
  - 输入：T015 的注入核心
  - 输出：`src/skill/parallel/test/perf/test_injection_latency.cj`
  - 验收标准：10 技能注入耗时 < 100ms
  - 风险点：测试环境性能波动，需取多次平均值
  - 回滚点：删除测试文件

- [ ] **T038** 编写依赖闭包计算性能测试，位于 `src/skill/parallel/test/perf/test_dependency_closure_latency.cj`
  - 优先级：P2
  - 依赖任务：T015
  - 描述：测试 5 层依赖链计算耗时，目标 < 50ms
  - 输入：T015 的注入核心
  - 输出：`src/skill/parallel/test/perf/test_dependency_closure_latency.cj`
  - 验收标准：5 层依赖链计算耗时 < 50ms
  - 风险点：无
  - 回滚点：删除测试文件

- [ ] **T039** 编写互斥过滤性能测试，位于 `src/skill/parallel/test/perf/test_conflict_filter_latency.cj`
  - 优先级：P2
  - 依赖任务：T022
  - 描述：测试 10 技能 5 互斥对过滤耗时，目标 < 30ms
  - 输入：T022 的互斥过滤器
  - 输出：`src/skill/parallel/test/perf/test_conflict_filter_latency.cj`
  - 验收标准：过滤耗时 < 30ms
  - 风险点：无
  - 回滚点：删除测试文件

- [ ] **T040** 编写预算检查性能测试，位于 `src/skill/parallel/test/perf/test_budget_check_latency.cj`
  - 优先级：P2
  - 依赖任务：T033
  - 描述：测试 10 技能预算分配耗时，目标 < 20ms
  - 输入：T033 的预算分配器
  - 输出：`src/skill/parallel/test/perf/test_budget_check_latency.cj`
  - 验收标准：预算分配耗时 < 20ms
  - 风险点：无
  - 回滚点：删除测试文件

---

## 11. 文档与配置

**写作指导**：本组确保功能可上线，包含配置示例和文档更新。

### 11.1 配置与文档
- [ ] **T041** 在 `skills/personalization/SKILL.md` 中创建 personalization 技能的 SKILL.md 声明文件
  - 优先级：P1
  - 依赖任务：T023
  - 描述：创建 `skills/personalization/SKILL.md`，声明 `name: personalization`、`load_policy: always_on`、`priority: high`、`description: 个性化技能插件，加载 SOUL.md / IDENTITY.md / USER.md / MEMORY.md 等工作空间文件`
  - 输入：T023 的个性化插件
  - 输出：`skills/personalization/SKILL.md`
  - 验收标准：SKILL.md 符合 agentskills 标准，扩展字段正确
  - 风险点：无
  - 回滚点：删除文件

- [ ] **T042** 在项目文档中更新 SKILL.md 扩展字段说明，位于 `docs/ref/ConcurrentSkills.md` 或同级文档
  - 优先级：P2
  - 依赖任务：T005
  - 描述：文档化扩展字段 `load_policy` / `priority` / `depends_on` / `conflicts_with` / `context_budget_tokens` / `compatible_with` 的语义、取值、默认值；提供配置示例
  - 输入：T005 的解析器
  - 输出：`docs/ref/ConcurrentSkills.md`（追加章节）
  - 验收标准：文档覆盖所有扩展字段，含配置示例
  - 风险点：无
  - 回滚点：删除追加章节

- [ ] **T043** 添加 `SkillParallelConfig` 配置示例到项目配置文档
  - 优先级：P2
  - 依赖任务：T004
  - 描述：文档化 `SkillParallelConfig` 各字段含义和配置方式，提供默认配置和自定义配置示例
  - 输入：T004 的配置类
  - 输出：配置文档（追加章节）
  - 验收标准：配置示例可直接复制使用
  - 风险点：无
  - 回滚点：删除追加章节

- [ ] **T043a** 添加 `AutoInjectConfig` 配置说明到项目文档，文档化自动渐进式加载配置
  - 优先级：P2
  - 依赖任务：T049
  - 描述：文档化 `AutoInjectConfig` 各字段含义（`autoInjectEnabled` / `taskMatchThreshold` / `taskMatchStrategy` / `maxAutoInjectSkills` / `fallbackToolRetained` / `dedupOnReinject`），提供配置示例；说明 `autoInjectEnabled=false` 时的回退行为；说明漂移修复的设计目标
  - 输入：T049 的 `AutoInjectConfig` 类
  - 输出：`docs/ref/ConcurrentSkills.md`（追加"自动渐进式加载"章节）
  - 验收标准：文档覆盖所有配置字段，含配置示例和回退说明
  - 风险点：无
  - 回滚点：删除追加章节

---

## 12. 审查与最终验证

**写作指导**：本组对应 design.md 2.5 节回滚方案和 2.6.4 节回归测试，确保交付质量。

### 12.1 代码审查
- [ ] **T044** 代码审查：确认未修改 `Skill` / `SkillManager` / `ToolManager` 接口
  - 优先级：P0
  - 依赖任务：T018
  - 描述：审查 `src/core/skill/skill.cj` / `src/core/skill/skill_manager.cj` / `src/core/tool/tool_manager.cj` 未被修改；扩展仅通过 `metadata` 承载和新增类实现
  - 输入：所有新增和修改的文件
  - 输出：审查报告
  - 验收标准：核心接口文件无变更
  - 风险点：无
  - 回滚点：无

- [ ] **T045** 代码审查：确认 `SkillAwareAgent._registerSkillsAsTools()` 签名和现有逻辑不变
  - 优先级：P0
  - 依赖任务：T017
  - 描述：审查 `src/skill/skill_aware_agent.cj` 的 `_registerSkillsAsTools()` 方法签名未变，现有工具注册逻辑未改，仅新增字段和方法
  - 输入：T017 的修改
  - 输出：审查报告
  - 验收标准：`_registerSkillsAsTools()` 行为完全不变
  - 风险点：无
  - 回滚点：无

- [ ] **T045a** 代码审查：确认 `WebMCPProtocol` / `WsChatController` / `GetSkillContentTool` 扩展向后兼容
  - 优先级：P0
  - 依赖任务：T069、T070、T071
  - 描述：审查 `WebMCPProtocol.buildAgentSystemPrompt()` 第1段和第2段注入行为不变（仅第3段漂移修复）；`WsChatController` 流式响应行为不变（自动注入在首帧前完成）；`GetSkillContentTool.execute()` 签名不变（仅新增去重逻辑和 `setAutoInjector` 方法）；`autoInjectEnabled=false` 时所有扩展退回原行为
  - 输入：T069-T071 的修改
  - 输出：审查报告
  - 验收标准：
    1. 第1段和第2段注入行为不变
    2. `GetSkillContentTool` 签名不变
    3. `autoInjectEnabled=false` 时退回漂移前行为
  - 风险点：无
  - 回滚点：无

### 12.2 设计回顾
- [ ] **T046** 设计回顾：核对 design.md 与实现一致性
  - 优先级：P1
  - 依赖任务：T018、T022、T025、T029、T033、T059、T064、T068、T072、T074
  - 描述：核对 22 个接口/类均已实现（含补充需求新增的 `SkillAutoInjector` / `TaskMatcher` / `BudgetManager` / `InjectDecisionRecorder` / `AutoInjectConfig`），15 个接口清单的方法签名一致，16 个实施阶段依赖关系正确
  - 输入：design.md + 所有实现文件
  - 输出：回顾报告
  - 验收标准：实现与 design.md 一致，偏差需记录原因
  - 风险点：无
  - 回滚点：无

### 12.3 变更范围确认
- [ ] **T047** 变更范围最终确认
  - 优先级：P0
  - 依赖任务：T044、T045、T045a、T046
  - 描述：汇总所有新增文件、修改文件、新增测试文件，确认变更范围与 design.md 2.5.2 节回滚安全性一致；确认无数据库 DDL；确认无现有 SKILL.md 修改
  - 输入：所有任务输出
  - 输出：变更范围清单
  - 验收标准：
    1. 新增文件均在 `src/skill/parallel/` 目录下（含补充需求新增的 `skill_auto_injector.cj` / `task_matcher.cj` / `budget_manager.cj` / `inject_decision_recorder.cj` / `auto_inject_config.cj` 等）
    2. 修改文件含 `src/skill/skill_aware_agent.cj`、`src/protocol/web_mcp_protocol.cj`、`src/controller/ws_chat_controller.cj`、`src/tool/get_skill_content_tool.cj`、`src/runtime/agent_runtime_bridge.cj`
    3. 无数据库 DDL
    4. 现有 49 个技能的 SKILL.md 无修改
    5. `autoInjectEnabled=false` 时所有修改退回原行为
  - 风险点：无
  - 回滚点：无

---

## 任务统计

| 优先级 | 任务组 | 任务数 | 说明 |
|--------|--------|--------|------|
| P0 | TG01-TG04 + TG13 + TG14 + TG15 + TG18(部分) + T044/T045/T045a/T047 | 30 | 注入核心 + 自动注入漂移修复最小路径 + 关键审查 |
| P1 | TG05-TG07 + TG16 + TG18(部分) + TG19 + T034-T036 + T041/T046 + TG20(部分) | 27 | 互斥+个性化+日志+决策记录+路径修复+去重 + 集成测试 |
| P2 | TG08 + TG17 + T037-T040 + T042/T043/T043a + TG20(部分) | 15 | 预算管理+预算降级 + 性能测试 + 文档 |
| **合计** | **20 个任务组** | **82 个任务** | **覆盖 design.md 全部 16 个实施阶段** |

### 补充需求任务统计（TG13-TG20）

| 任务组 | 阶段 | 任务数 | 优先级 | 说明 |
|--------|------|--------|--------|------|
| TG13 | 阶段 9（配置） | 3 (T048-T050) | P0 | AutoInjectConfig + TaskMatchStrategy 枚举 |
| TG14 | 阶段 9（匹配器） | 3 (T051-T053) | P0 | TaskMatcher 任务匹配器 |
| TG15 | 阶段 12 | 6 (T054-T059) | P0 | SkillAutoInjector 自动注入器（漂移修复核心） |
| TG16 | 阶段 10 | 5 (T060-T064) | P1 | InjectDecisionRecorder 注入决策记录 |
| TG17 | 阶段 11 | 4 (T065-T068) | P2 | BudgetManager 预算管理带降级 |
| TG18 | 阶段 13/14/15 | 4 (T069-T072) | P0/P1 | 漂移修复接入点 + GetSkillContentTool 去重 |
| TG19 | 阶段 16 | 2 (T073-T074) | P1 | buildAgentFromDefinition 修复 |
| TG20 | 集成测试 | 8 (T075-T082) | P0/P1/P2 | 自动渐进式加载集成测试 + 性能测试 |
| **小计** | **阶段 9-16** | **35** | - | **补充需求 5.6 节全部任务** |

## 关键约束

1. **不修改核心接口**：`Skill` / `SkillManager` / `ToolManager` / `SkillAwareAgent._registerSkillsAsTools()` 签名不变
2. **不修改数据库**：本期无 DDL，决策日志和注入决策记录走 `LogUtils` 不持久化
3. **不修改现有 SKILL.md**：扩展字段可选，现有 49 个技能无需修改
4. **功能开关可控**：通过 `SkillParallelConfig.enableConflictFilter` / `enableBudgetAllocator` 和 `AutoInjectConfig.autoInjectEnabled` 可逐功能开关
5. **整体回滚**：`SkillAwareAgent` 中 `skillContextInjector` 设为 `None` 时退回现有机制；`AutoInjectConfig.autoInjectEnabled=false` 时退回纯 `get_skill_content` 工具模式（漂移前行为）
6. **漂移修复可回退**：`autoInjectEnabled=false` 时 `WebMCPProtocol` / `WsChatController` / `GetSkillContentTool` 全部退回原行为，无副作用
7. **向后兼容保证**：`get_skill_content` 工具保留（`fallbackToolRetained=true` 默认），agent 仍可主动调用获取技能内容；去重机制仅影响性能不影响正确性
8. **编译验证**：每个任务组完成后需在独立 cmd 环境运行 `cjpm build` 验证编译（人工反馈结果，不在开发工具中运行）

## 漂移修复最小路径

```
TG01 (声明解析) → TG02 (渲染) → TG03 (注入核心) → TG13 (AutoInjectConfig) → TG15 (SkillAutoInjector) → TG18 (WebMCPProtocol/WsChatController 接入)
```

此路径实现驻留型技能完整内容自动注入，替换原第3段"agent 主动调用 `get_skill_content`"漂移，是补充需求 5.6 节的最小可用路径。

---

**文档状态**: tasks.md 已更新（纳入 spec.md 第 5.6 节"技能内容自动渐进式加载"补充需求），等待用户确认
**本次更新摘要**:
- 新增 8 个任务组（TG13-TG20）、35 个任务（T048-T082），覆盖 design.md 阶段 9-16
- 修复"渐进式加载设计漂移"——将技能完整内容加载从"agent 主动调用 `get_skill_content` 工具"恢复为"框架自动注入到上下文"
- 新增 5 个组件实现任务：`AutoInjectConfig`（配置）、`TaskMatcher`（任务匹配）、`SkillAutoInjector`（自动注入器）、`BudgetManager`（预算管理带降级）、`InjectDecisionRecorder`（注入决策记录）
- 新增 3 个存量组件扩展任务：`WebMCPProtocol`/`WsChatController`（接入自动注入替换第3段漂移）、`GetSkillContentTool`（去重机制向后兼容）、`AgentRuntimeBridge`（修复 buildAgentFromDefinition 空技能管理器）
- 新增 8 个集成测试任务（TG20），覆盖驻留型自动注入/任务匹配注入/显式调用注入/向后兼容/预算降级/回退/双重注入防护
- 漂移修复最小路径：TG01 → TG02 → TG03 → TG13 → TG15 → TG18
- 保留 `get_skill_content` 工具作为后备机制（`fallbackToolRetained=true` 默认），`auto_inject_enabled=false` 可回退为纯工具模式
**下一步**: 用户确认后，可进入编码实施阶段