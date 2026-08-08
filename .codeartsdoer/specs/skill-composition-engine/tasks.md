# 技能组合引擎 - 任务清单

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
| SCE-T001 | 数据库表设计与创建 | P0 | 0.5天 | 无 | ✅已完成 |
| SCE-T002 | CompositionYamlParser解析器 | P0 | 1天 | 无 | ✅已完成 |
| SCE-T003 | SkillOutput标准化与InputMapper | P0 | 1天 | 无 | ✅已完成 |
| SCE-T004 | CompositionExecutor执行引擎 | P0 | 2天 | SCE-T002, SCE-T003 | ✅已完成 |
| SCE-T005 | DependencyResolver依赖解析 | P0 | 1天 | SCE-T002 | ✅已完成 |
| SCE-T006 | CompositionValidator组合验证 | P0 | 0.5天 | SCE-T005 | ✅已完成 |
| SCE-T007 | CompositionTemplateManager模板管理 | P1 | 1天 | SCE-T002 | ⏳待完成 |
| SCE-T008 | CRUD模块与API实现 | P0 | 1天 | SCE-T001 | ✅已完成(crudgen已生成) |
| SCE-T009 | 集成测试与验证 | P0 | 1天 | SCE-T001~T008 | ⏳待完成 |

---

## 仓颉规范合规性要求（来自cangjie-compliance-review.md）

- [x] CompositionExecutor和InputMapper类添加`public`修饰符
- [x] `resolveExpression`返回值改用`Option<JsonValue>`（解析可能失败）
- [x] 补充`import std.collection.HashMap`

---

## SCE-T001: 数据库表设计与创建

**描述**: 创建 skill_compositions 和 composition_executions 数据库表。

**子任务**:
1. **[自动化]** 编写DDL文件放置在 `sql/incremental/` 目录
2. **[人工操作]** 通知人工执行数据库变更
3. **[人工操作]** 人工使用 `loaddbinfo` 刷新 db_info 表
4. **[人工操作]** 人工使用 `crudgen` 生成标准CRUD骨架，使用 `crudweb` 生成Web管理界面

**验收标准**:
- [x] skill_compositions表创建成功
- [x] composition_executions表创建成功

---

## SCE-T002: CompositionYamlParser解析器

**描述**: 实现COMPOSITION.yaml配置文件解析器。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义CompositionDefinition数据类
2. 定义CompositionStep数据类
3. 实现YAML解析器
4. 支持嵌套组合引用
5. 编写单元测试

**关键文件**:
- `src/skill/composition_yaml_parser.cj`
- `src/skill/composition_definition.cj`

**验收标准**:
- [x] COMPOSITION.yaml正确解析
- [x] 嵌套组合正确处理

---

## SCE-T003: SkillOutput标准化与InputMapper

**描述**: 实现标准化的技能输出格式和输入映射。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 定义SkillOutput数据类（files、data、metrics、errors）
2. 定义SkillInput数据类
3. 实现InputMapper映射表达式解析
4. 支持${step_name.output.field}表达式
5. 支持数据转换函数（map、filter、reduce）
6. 编写单元测试

**关键文件**:
- `src/skill/skill_output.cj`
- `src/skill/input_mapper.cj`

**验收标准**:
- [x] SkillOutput格式标准化
- [x] 映射表达式正确解析
- [ ] 数据转换函数正确执行

---

## SCE-T004: CompositionExecutor执行引擎

**描述**: 实现串行/并行/条件分支的组合执行引擎。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 实现CompositionExecutor
2. 串行执行模式
3. 并行执行模式（基于步骤依赖关系）
4. 条件分支执行
5. 与SkillToToolAdapter集成
6. 执行结果持久化
7. 缓存机制

**关键文件**:
- `src/skill/composition_executor.cj`

**验收标准**:
- [x] 串行执行正确
- [x] 并行执行正确（基于拓扑排序的依赖关系）
- [x] 条件分支正确
- [x] 缓存机制正确

---

## SCE-T005: DependencyResolver依赖解析

**描述**: 实现技能依赖自动解析和加载。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 解析SKILL.md中的dependencies字段
2. 构建技能依赖图
3. 按依赖顺序加载技能
4. 循环依赖检测
5. 缺失依赖提示

**关键文件**:
- `src/skill/dependency_resolver.cj`

**验收标准**:
- [x] 依赖正确解析
- [x] 循环依赖正确检测
- [x] 依赖按顺序加载

---

## SCE-T006: CompositionValidator组合验证

**描述**: 实现组合执行前的验证。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 验证所有引用的技能已安装
2. 验证依赖关系无循环
3. 验证输入映射类型兼容
4. 验证所需工具和权限可用
5. 返回验证结果（valid、warnings、errors）

**关键文件**:
- `src/skill/composition_validator.cj`

**验收标准**:
- [x] 技能存在性验证正确
- [x] 循环依赖检测正确
- [x] 类型兼容性验证正确

---

## SCE-T007: CompositionTemplateManager模板管理

**描述**: 实现组合模板管理。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 内置模板定义（code-gen-optimize、code-gen-test、analyze-refactor-verify）
2. 模板实例化（提供参数创建组合实例）
3. 模板存储在skills/_templates/目录
4. 支持用户自定义模板

**关键文件**:
- `src/skill/composition_template_manager.cj`

**验收标准**:
- [ ] 内置模板可正确实例化
- [ ] 自定义模板可正确加载

---

## SCE-T008: CRUD模块与API实现

**描述**: 基于crudgen生成的标准CRUD模块，迭代开发组合执行API。（使用cangjie-coder技能编写仓颉代码）

**子任务**:
1. 使用crudgen生成SkillCompositionPO和CompositionExecutionPO的CRUD代码
2. 实现CompositionService扩展方法
3. 遵循uctoo-v4 API规范

**验收标准**:
- [ ] 标准 CRUD API可正常调用
- [ ] 组合执行API正确工作

---

## SCE-T009: 集成测试与验证

**描述**: 编写集成测试。

**子任务**:
1. 编写CompositionExecutor集成测试
2. 编写DependencyResolver集成测试
3. 编写内置模板执行测试
4. 编写与AgentTeams集成测试

**验收标准**:
- [ ] 所有集成测试通过
- [ ] code-gen-optimize模板可正确执行