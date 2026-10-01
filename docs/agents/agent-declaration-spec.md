# Agent 声明文件规范

## 文档信息
- **版本**: 1.0.0
- **创建日期**: 2026-05-29
- **适用范围**: agentskills-runtime Agent 系统

---

## 1. 概述

Agent 声明文件使用 Markdown 格式，通过 frontmatter 定义 Agent 的元数据和配置，正文部分定义 Agent 的系统提示词和工作流程。

## 2. 文件结构

```markdown
---
name: Agent 名称
type: main|sub|analyzer|comparator|grader
description: Agent 描述
version: 1.0.0
author: 作者名
tools:
  - tool_name1
  - tool_name2
model: claude-3-sonnet
maxTurns: 200
memory: user|project|local
background: false
permissions:
  - database.uctoo.agents:read
  - database.uctoo.agents:write
---

# Agent 角色定义

[Agent 的角色和职责描述]

## 输入

[Agent 接收的输入参数]

## 处理流程

[Agent 的处理步骤]

## 输出

[Agent 的输出格式]

## 指南

[Agent 的行为指南和最佳实践]
```

## 3. Frontmatter 字段说明

### 3.1 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| name | String | Agent 名称 | `AnalyzerAgent` |
| **agent_type** | String | Agent 类型 | `main`, `sub`, `analyzer` |
| description | String | Agent 描述 | `代码分析专家` |

> **键名红线**：类型键是 **`agent_type`**，不是 `type`。
> `src/core/agent/agent_loader.cj` 解析的就是 `agent_type`；早期文档与部分旧声明文件
> 写作 `type`，会导致解析不到类型而落入默认分支——**新文件一律用 `agent_type`**，
> 旧文件迁移时同步改名。

### 3.2 可选字段

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| version | String | `1.0.0` | Agent 版本 |
| author | String | - | 作者名 |
| tools | Array | `[]` | 可用工具列表 |
| model | String | - | 使用的模型 |
| maxTurns | Integer | `200` | 最大对话轮数 |
| memory | String | `user` | 内存范围 |
| background | Boolean | `false` | 是否后台运行 |
| permissions | Array | `[]` | 权限列表 |
| color | String | - | 显示颜色 |
| isolation | String | - | 隔离模式 |
| parent_id | String | - | 父 Agent **名称**（文件里写名字；落库时按名字解析成 uuid，解析不到记 `sync_status='dependency_missing'`，不得静默 NULL） |
| skill_name | String | - | 所属技能名。子 agent 归属 `skills/<skill_name>/agents/` 时**必填**；主 agent 留空 |
| capabilities | Array | `[]` | 能力声明列表（每项 `id` + `description`）。T-21 起**派单结果契约校验**的规则就取自这里（见 §9.4） |
| model_capabilities | Array | `[]` | 模型能力要求 |
| capabilities_skill | String | - | 能力所依赖的技能 |
| identity_status | String | `none` | 身份状态 |
| discoverable | Boolean | `true` | 是否可被全局发现（false 时只有归属技能可派生） |
| input_types | Array | `[]` | 输入契约（落 `default_input_types`） |
| output_types | Array | `[]` | 输出契约（落 `default_output_types`） |

## 4. Agent 类型

### 4.1 Main Agent

主 Agent，负责主要任务和协调子 Agent。

```markdown
---
name: MainAgent
type: main
description: 主 Agent，负责任务分解和协调
tools:
  - file_read
  - file_write
  - bash
model: claude-3-sonnet
maxTurns: 500
---

# 主 Agent

你是系统的主 Agent，负责任务的分解、分配和协调。

## 职责

1. 接收用户任务
2. 分析任务并分解为子任务
3. 创建和分配子 Agent
4. 汇总结果并返回给用户
```

### 4.2 Sub Agent

子 Agent，负责执行特定的子任务。

```markdown
---
name: SubAgent
type: sub
description: 子 Agent，执行特定任务
tools:
  - file_read
  - bash
model: claude-3-haiku
maxTurns: 100
---

# 子 Agent

你是子 Agent，负责执行特定的子任务。

## 职责

1. 接收主 Agent 分配的任务
2. 执行任务并返回结果
3. 遵循主 Agent 的指示
```

### 4.3 Analyzer Agent

分析 Agent，负责分析结果和生成改进建议。

```markdown
---
name: AnalyzerAgent
type: analyzer
description: 分析专家，负责分析结果并生成建议
tools:
  - file_read
  - json_parse
model: claude-3-sonnet
---

# 分析 Agent

你是分析专家，负责分析执行结果并生成改进建议。
```

### 4.4 Comparator Agent

比较 Agent，负责盲评比较两个输出。

```markdown
---
name: ComparatorAgent
type: comparator
description: 盲评比较专家
tools:
  - file_read
model: claude-3-sonnet
---

# 比较 Agent

你是盲评比较专家，负责比较两个输出并判断优劣。
```

### 4.5 Grader Agent

评估 Agent，负责评估期望是否达成。

```markdown
---
name: GraderAgent
type: grader
description: 评估专家
tools:
  - file_read
model: claude-3-sonnet
---

# 评估 Agent

你是评估专家，负责评估期望是否达成。
```

## 5. 系统提示词编写指南

### 5.1 角色定义

清晰定义 Agent 的角色和身份：

```markdown
# 角色

你是 [角色名称]，负责 [职责描述]。

## 专业领域

- 领域 1
- 领域 2
- 领域 3
```

### 5.2 输入输出定义

明确定义输入参数和输出格式：

```markdown
## 输入

你接收以下参数：
- **param1**: 参数 1 描述
- **param2**: 参数 2 描述

## 输出

你的输出应包含：
1. 输出项 1
2. 输出项 2
```

### 5.3 处理流程

定义清晰的处理步骤：

```markdown
## 处理流程

### 步骤 1: 准备

[准备步骤描述]

### 步骤 2: 执行

[执行步骤描述]

### 步骤 3: 验证

[验证步骤描述]
```

## 6. 示例文件

### 6.1 代码审查 Agent

```markdown
---
name: CodeReviewerAgent
type: sub
description: 代码审查专家
version: 1.0.0
tools:
  - file_read
  - file_write
  - bash
model: claude-3-sonnet
maxTurns: 150
permissions:
  - database.uctoo.agents:read
---

# 代码审查 Agent

你是代码审查专家，负责审查代码质量并提供改进建议。

## 输入

- **file_path**: 待审查的文件路径
- **review_focus**: 审查重点（可选）

## 处理流程

### 步骤 1: 阅读代码

1. 读取指定文件
2. 理解代码结构和功能

### 步骤 2: 分析代码

1. 检查代码规范
2. 识别潜在问题
3. 评估代码质量

### 步骤 3: 生成报告

1. 列出发现的问题
2. 提供改进建议
3. 给出总体评价

## 输出

生成代码审查报告，包含：
- 问题列表
- 改进建议
- 代码质量评分

## 指南

- 保持客观和建设性
- 提供具体的代码示例
- 优先关注严重问题
```

### 6.2 测试生成 Agent

```markdown
---
name: TestGeneratorAgent
type: sub
description: 测试用例生成专家
version: 1.0.0
tools:
  - file_read
  - file_write
model: claude-3-sonnet
maxTurns: 100
---

# 测试生成 Agent

你是测试用例生成专家，负责根据代码生成全面的测试用例。

## 输入

- **source_file**: 源代码文件路径
- **test_framework**: 测试框架（可选，默认 jest）

## 处理流程

### 步骤 1: 分析源代码

1. 阅读源代码
2. 识别功能和接口
3. 确定边界条件

### 步骤 2: 设计测试用例

1. 正常场景测试
2. 边界条件测试
3. 异常场景测试

### 步骤 3: 生成测试代码

1. 创建测试文件
2. 编写测试用例
3. 添加测试说明

## 输出

生成测试文件，包含：
- 完整的测试用例
- 测试说明文档
- 运行指南

## 指南

- 覆盖所有主要功能
- 包含边界条件测试
- 测试用例独立可执行
```

## 7. 加载机制

### 7.1 加载顺序

> **本节已按 runtime 现状重写（2026-09-28）**。原写的
> built-in / user / project / policy 四级目录**在代码中不存在**，属早期设计残留；
> 按它排查会找不到任何真实加载点。

真实链路分两条，缺一不可：

**① 文件 → DB（同步链路，启动时 + `POST /api/v1/uctoo/sync/all` 手动触发）**

```
main.cj 启动 → SyncManager.syncAll
             → AgentSyncHandler.detectChanges
             → ChangeDetector.detectAgentChanges(basePath, bundledSkillRoots!)
             → collectAgentDeclarationFiles 收三类：
                 ① <basePath>/AGENTS.md
                 ② <basePath>/agents/ 下的 .md
                 ③ 各技能根目录下的 agents 子目录里的 .md（约定即注册，见 §9）
```

**② DB → 运行时（加载链路）**

```
AgentRuntimeBridge.loadFromDatabase(agentId)
  或 SubAgentDispatchServiceImpl 按 skill_name + name 查 agents 表
     → AgentLoader 造 AgentDefinition → 造 Agent
```

**③ 加载期探测（仅挂内存，不落库）**

`BundledAgentScanner.scan(skillDir)` 在技能加载时把 `<skill-root>/` 下 agents 子目录里的
声明文件名挂进 `SkillManifest.bundledAgents`。**注意它不写库**——要落库必须走 ①。

### 7.2 优先级规则

- 后加载的 Agent 覆盖先加载的同名 Agent
- 内置 Agent 优先级最低
- 策略 Agent 优先级最高

### 7.3 缓存机制

- Agent 定义加载后缓存
- 文件变更时自动刷新
- 提供手动刷新接口

## 8. 验证规则

### 8.1 Frontmatter 验证

- `name` 不能为空
- `type` 必须是预定义类型之一
- `tools` 必须是数组
- `maxTurns` 必须是正整数

### 8.2 正文验证

- 必须包含角色定义
- 必须包含处理流程
- 必须包含输出定义

## 9. 错误处理

### 9.1 解析错误

- Frontmatter 格式错误：跳过该文件
- 必填字段缺失：跳过该文件
- 类型错误：使用默认值

### 9.2 加载错误

- 文件不存在：记录日志，继续加载其他文件
- 权限不足：记录日志，跳过该文件
- 格式错误：记录详细错误信息

## 10. 最佳实践

1. **单一职责**: 每个 Agent 专注于一个特定任务
2. **清晰命名**: Agent 名称应反映其职责
3. **详细文档**: 提供完整的角色、输入、输出定义
4. **适度工具**: 只授予必要的工具权限
5. **合理限制**: 设置适当的 maxTurns 防止无限循环

## 9. 技能内 agents 目录约定（约定即注册）

> 本章为 runtime 现行规范（2026-09-28 新增，SDD T-17/T-19/T-20 落地后的事实标准）。

### 9.1 目录形态

```
skills/<skill-name>/
├── SKILL.md
└── agents/
    ├── <sub-agent-a>.md
    └── <sub-agent-b>.md
```

文件名（去 `.md`）即子 agent 名，与 frontmatter 的 `name` 应一致。

### 9.2 必需键

| 键 | 要求 |
|---|---|
| `name` | 与文件名一致 |
| `agent_type` | 子 agent 写 `sub`（**不是 `type`**，见 §3.1） |
| `description` | 一句话职责 |
| `skill_name` | **必填**，取所属技能名；同步层按路径推导，也建议显式写 |
| `parent_id` | 父 agent 名（文件里写名字，落库时解析成 uuid） |
| `discoverable` | 是否可被非归属技能发现（默认 true） |

缺 `agent_type` 的文件会被**跳过并报错**，不会入库。

### 9.3 自动探测与双向同步

- **新增**：放入声明文件 → 重启或调 `POST /api/v1/uctoo/sync/all` → `agents` 表出现该行
  （`skill_name` 由路径推导，`source_path` 记相对路径）。
- **删除**：删文件后需**显式清理**——同步链路当前**只增不删**
  （`SyncManager.syncAll` 对 `ChangeType.Deleted` 只跳过），
  删文件不会自动下线库里的行。这是已知缺口，清理请用显式 SQL 并留痕。

### 9.4 派单结果契约（可选，建议配）

在 frontmatter 写 `output_contract` 段，派单回传会按它自动校验（T-21）：

```yaml
output_contract:
  kind: markdown            # markdown | json | text
  required_sections:        # 必须出现的章节串（**必须与模板真实标题逐字一致**）
    - 1. 组件定位
    - 4. DFX约束
  forbidden_placeholders: [TODO, 待补充, TBD, xxx]
  min_chars: 2000
```

校验不过 → 携结构化错误**自动重派 1 次** → 仍不过转人工闸口（不无限重试）。
**未配置时**降级为"仅非空 + 最小长度"，并在 `contract_type` 记 `contract_absent`
（可观测，非静默通过）。

> ⚠️ `required_sections` 里的串会做**子串包含**判断，必须与模板标题逐字一致。
> 写"决策风险"而模板是"关键设计决策与风险"会导致**每次派单都误判失败**并卡在闸口。

### 9.5 判别准则：什么技能该建 agents 目录

| 类别 | 建 `agents/`？ | 理由 |
|---|---|---|
| **流程编排类**（如 SDD 六步） | ✅ 建 | 每步需要换脑子（不同的角色设定与验收标准） |
| **编程 / 领域类**（cangjie-coder、web-coder、app-coder） | ❌ 不建 | 只需要换说明书（SOP + 官方文档），不需要换脑子 |

已按此准则下线：`skills/cangjie-coder/agents/`（原 4 个角色职责已并入 SKILL.md 四步工作流）。
