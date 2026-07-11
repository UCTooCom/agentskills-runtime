# 技能组合引擎需求规格

## 项目背景

当前 agentskills-runtime 的技能执行是独立的，缺乏技能间的组合编排能力。AGENTS.md 中提出了"技能是一等公民，优先使用技能的排列组合解决用户需求"的设计理念，但系统层面缺乏技能组合引擎来支撑这一理念。需要结构化的技能组合定义、执行和优化能力。

## 核心问题

1. **无技能组合定义**: 无法声明式定义技能的组合方式（串行、并行、条件分支）
2. **无技能间数据传递**: 技能执行结果无法自动传递给下一个技能作为输入
3. **无技能依赖解析**: 技能间的依赖关系（如 cangjie-coder 依赖 cangjie-language-guide）无自动解析
4. **无技能组合模板**: 常见的技能组合模式无法保存为模板复用
5. **无技能组合验证**: 组合执行前无法验证技能兼容性和依赖完整性
6. **无技能组合性能优化**: 无法对组合执行进行并行化、缓存等优化

## 功能需求

### REQ-SCE-001: 技能组合定义语言

- 定义技能组合描述格式（Skill Composition DSL）：
  ```yaml
  composition:
    name: full-stack-code-gen
    description: 全栈代码生成组合：数据库CRUD + 代码优化 + 测试生成
    steps:
      - name: generate-crud
        skill: crud-generator
        tool: generate
        input:
          table: ${args.table}
      - name: optimize-code
        skill: cangjie-coder
        depends_on: [generate-crud]
        input:
          files: ${generate-crud.output.files}
          action: optimize
      - name: generate-tests
        skill: cangjie-coder
        depends_on: [optimize-code]
        input:
          files: ${optimize-code.output.files}
          action: test
    output:
      files: ${generate-tests.output.all_files}
  ```
- 组合定义存储在技能目录的 `COMPOSITION.yaml` 文件中
- 支持嵌套组合（组合中引用其他组合）

### REQ-SCE-002: 技能间数据传递

- 定义标准化的技能输出格式（SkillOutput）：
  - `files`: 产出文件列表
  - `data`: 结构化数据
  - `metrics`: 执行指标
  - `errors`: 错误信息
- 支持输入映射表达式：`${step_name.output.field}`
- 支持数据转换函数：`map`、`filter`、`reduce`、`flatten`
- 支持类型检查：输入类型与技能期望类型不匹配时报错

### REQ-SCE-003: 技能依赖解析

- 解析 SKILL.md 中的 `dependencies` 字段
- 构建技能依赖图
- 自动加载依赖技能（按依赖顺序）
- 检测循环依赖并报错
- 缺失依赖时自动提示安装（`skill install`）

### REQ-SCE-004: 技能组合模板

- 内置常用组合模板：
  - `code-gen-optimize`: CRUD 生成 + 代码优化
  - `code-gen-test`: CRUD 生成 + 测试生成
  - `create-evaluate-improve`: 技能创建 + 评估 + 改进
  - `analyze-refactor-verify`: 分析 + 重构 + 验证
- 模板存储在 `skills/_templates/` 目录
- 支持从模板实例化组合（提供参数）
- 支持用户自定义模板

### REQ-SCE-005: 组合验证

- 执行前验证：
  - 所有引用的技能已安装
  - 依赖关系无循环
  - 输入映射类型兼容
  - 所需工具和权限可用
- 静态分析组合定义，提前发现潜在问题
- 验证结果包含：valid、warnings、errors

### REQ-SCE-006: 组合执行优化

- **并行化**: 自动识别无依赖步骤，并行执行
- **缓存**: 相同输入的技能执行结果缓存，避免重复计算
- **增量执行**: 输入未变更的步骤跳过，使用缓存结果
- **懒加载**: 技能正文仅在需要时加载（渐进式披露）
- **资源预估**: 执行前预估资源需求，避免 OOM

### REQ-SCE-007: 组合与 Agent 集成

- 技能组合可自动创建所需的 subagent：
  - 组合中每个步骤可声明 `agent_type`
  - 系统根据声明自动创建 Agent 实例
- Agent 执行结果自动回传到组合的数据流
- 组合执行状态通过 AgentTasks 跟踪
- 组合的 agents 声明写入技能的 `agents/` 子目录

### REQ-SCE-008: 组合与同步集成

- 组合定义文件（COMPOSITION.yaml）通过 SyncManager 同步到数据库
- 数据库中存储组合的执行历史和结果
- 支持通过 API 查询组合的执行记录

## 非功能需求

- 组合定义解析延迟 ≤ 100ms
- 组合验证延迟 ≤ 500ms
- 数据传递延迟 ≤ 10ms
- 支持最多 20 个步骤的组合
- 缓存命中率目标 ≥ 30%（重复任务场景）

## 数据模型

### skill_compositions 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| name | varchar(100) | 组合名称 |
| description | varchar(1024) | 组合描述 |
| definition | jsonb | 组合定义（YAML 解析后的 JSON） |
| source_path | varchar(500) | 源文件路径 |
| template_ref | varchar(100) | 引用的模板名称 |
| is_template | boolean | 是否为模板 |
| sync_status | varchar(20) | 同步状态 |
| creator | bigint | 创建者 |
| created_at | timestamp | 创建时间 |
| updated_at | timestamp | 更新时间 |

### composition_executions 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint | 主键 |
| composition_id | bigint | 关联组合 |
| status | varchar(20) | 状态：running/completed/failed |
| step_results | jsonb | 各步骤结果 |
| final_output | jsonb | 最终输出 |
| cache_hits | integer | 缓存命中次数 |
| duration_ms | integer | 总耗时 |
| created_at | timestamp | 创建时间 |
| completed_at | timestamp | 完成时间 |

## 验收标准

1. Skill Composition DSL 正确解析和执行
2. 技能间数据通过映射表达式正确传递
3. 技能依赖自动解析和加载
4. 组合模板可正确实例化和执行
5. 组合验证在执行前正确检测问题
6. 并行化、缓存、增量执行正确优化性能
7. 组合与 Agent 系统正确集成
8. 组合定义通过同步系统正确同步