# 技能并行机制研究报告

> **工程目录**: `.codeartsdoer/specs/concurrent_skills/`
> **研究日期**: 2026-10-05
> **研究范围**: agentskills-runtime 现有机制、deepseek-harness、OpenClaw、Hermes 等同类产品技能并行机制
> **架构师观点来源**: `docs/ref/ConcurrentSkills.md`

---

## 1. 摘要

本报告基于架构师在 `ConcurrentSkills.md` 中补充的观点，对 agentskills-runtime 已有的 agentskills 机制、deepseek-harness 的技能系统，以及 OpenClaw、Hermes 等同类产品的技能并行机制进行了系统研究。核心结论：

1. **agentskills-runtime 当前仅有"串行编排"能力**：`StepType.Parallel` 枚举值虽已存在，但 `CompositionExecutor` 实际执行链路是拓扑排序后的 for 循环串行执行，没有真正的"多技能同时注入上下文"机制。
2. **deepseek-harness 已具备"上下文并行"的雏形**：通过 `agent/pre-step` 事件钩子注入技能目录（`<available_skills>`），模型可按需加载多个技能的 `<skill_content>` 到同一上下文，这是架构师所说的"提示词工程化并行"的典型实现。
3. **agentskills-runtime 已有个性化文件机制**：`AgentWorkspace` 支持 SOUL.md / IDENTITY.md / USER.md / MEMORY.md 等 8 类工作空间文件，但尚未将其抽象为 personalization 技能插件。
4. **技能并行本质是"多技能同时有效作用于大模型输入"**，不是程序并发；依赖技能应同载，互斥技能应避载。

本报告提出三层并行模型（上下文并行 / 编排并行 / 推理并行）、personalization 技能插件方案，以及若干超越业界最佳实践的演进建议。

---

## 2. 架构师观点解读

### 2.1 原文要点

架构师在 `docs/ref/ConcurrentSkills.md` 中补充了两段关键观点：

**第一段（设计哲学扩展）**：
- agentskills 开放标准本质是**提示词的工程化方案**
- 已在 agentskills-runtime 中实现"一切皆技能"的插件系统
- 有"技能优先"的设计理念，应把这种哲学更广泛应用
- 其他智能体项目一般有 `user.md` / `profile.md` 个性化配置文件机制
- 研究是否可以将个性化机制做成 skills（如 `personalization` 技能插件）
- agentskills-runtime 当前是否只支持技能的串行使用？
- 要支持"将一切都做成技能"，肯定需要技能的并行使用机制
- `personalization` 这样的技能可以一直加载有效使用，并行还可以使用 sdd、cangjie-coder 等开发技能
- 符合现实世界运行机制：人类可以边说话边看东西边听

**第二段（并行的本质澄清）**：
- 技能并行**不是程序并发**
- 技能并行 = 将多个技能同时添加到上下文中，使多个技能同时对于大模型的输入都是有效的
- 大模型可以表现出同时使用了多个技能的输出行为
- 技能之间存在**依赖**或**互斥**关系
- 依赖的技能应该同时加载，互斥的技能应避免同时加载
- 鼓励发散思维头脑风暴，提出超越业界最佳实践的理解

### 2.2 观点解码

将架构师观点解码为可落地的工程语义：

| 概念 | 工程语义 | 与程序并发的区别 |
|---|---|---|
| 技能并行 | 多个 SKILL.md 的指令体同时存在于大模型上下文 | 不涉及多线程、协程、异步 IO |
| 依赖关系 | 技能 A 的有效前提是技能 B 已在上下文 | 不是 import/依赖注入 |
| 互斥关系 | 技能 A 与技能 B 不能同时存在于上下文 | 不是锁/互斥量 |
| 一直加载 | 技能在会话生命周期内持续生效（驻留型技能） | 不是常驻进程/守护线程 |

**关键洞察**：架构师所说的"并行"在 LLM Agent 语境下，更精确的术语是 **context-level skill concurrency**（上下文级技能并发），即多个技能的 prompt 片段同时占据模型上下文窗口，模型在生成时可以综合多个技能的指令行为。

---

## 3. agentskills-runtime 现有技能机制研究

### 3.1 核心架构组件

研究 `src/skill/` 目录，识别出以下核心组件：

| 组件 | 文件 | 职责 |
|---|---|---|
| `SkillAwareAgent` | `skill_aware_agent.cj` | 技能感知 Agent，初始化时把所有技能注册为工具 |
| `CompositeSkillToolManager` | `composite_skill_tool_manager.cj` | 统一管理器，实现 `SkillManager` + `ToolManager` 双接口 |
| `SkillLoader` | `skill_loader.cj` | 从 SKILL.md 文件加载技能 |
| `SkillDependencyResolver` | `dependency_resolver.cj` | 依赖解析，拓扑排序，循环检测 |
| `CompositionExecutor` | `composition_executor.cj` | 组合执行器，按拓扑排序执行步骤 |
| `CompositionDefinition` | `composition_definition.cj` | 组合定义模型（DB 存储态） |
| `CollaborationSkills` | `collaboration_skills.cj` | 协作技能集（TaskDecompose/AgentSelect/ContextPass/ResultMerge） |
| `LrtCompositionRunner` | `lrt_composition_runner.cj` | 长程任务编排运行器（文件态 COMPOSITION.yaml） |
| `KanbanDispatcher` | `kanban_dispatcher.cj` | 看板调度器 |
| `CrossLanguageOrchestrator` | `cross_language_orchestrator.cj` | 跨语言编排器 |

### 3.2 技能注册与工具化机制

`SkillAwareAgent._registerSkillsAsTools()` 的实现（`skill_aware_agent.cj` L63-102）：

```
所有 skills → 逐个包装为 SkillToToolAdapter → 注册到 _toolManager
```

**关键观察**：
- 当前机制是"技能即工具"——每个技能被注册为一个可调用工具
- 模型通过 **tool calling** 选择技能，而非通过上下文注入感知技能
- 这是 **工具级并行**（模型可在一轮内调用多个工具），不是架构师所说的 **上下文级并行**

### 3.3 组合定义与执行机制

#### 3.3.1 StepType 枚举

`composition_definition.cj` L17-21：

```cangjie
public enum StepType {
    | Sequential
    | Parallel
    | Conditional
}
```

**Parallel 枚举值已存在**，但研究 `CompositionExecutor.execute()`（L133-190）发现：

```cangjie
let sortedSteps = topologicalSort(composition.steps)
// ...
for (step in sortedSteps) {
    // 串行执行每一步
    let stepResult = executeStep(step, stepOutputs, input)
}
```

**结论**：`StepType.Parallel` 目前只是**元数据标记**，执行器统一走拓扑排序后的 for 循环，没有真正的并行执行分支。注释（L4-12）也明确指出该文件是"DB 存储态 schema"，与文件态 COMPOSITION.yaml "不同源、不兼容"。

#### 3.3.2 SDD 技能的 COMPOSITION.yaml

研究 `skills/sdd/COMPOSITION.yaml`，SDD 六步流水线是典型的**串行依赖链**：

```yaml
steps:
  - name: research
    depends_on: []
    condition: "${input.enable_research}"
  - name: spec
    depends_on: [research]
  - name: design
    depends_on: [spec]
  - name: task
    depends_on: [design]
  - name: code
    depends_on: [task]
  - name: test
    depends_on: [code]
```

这是**编排级串行**（每步产出文档供下一步消费），与架构师所说的"上下文级并行"是不同层面的概念。

### 3.4 依赖解析机制

`SkillDependencyResolver`（`dependency_resolver.cj`）已实现：

| 能力 | 方法 | 状态 |
|---|---|---|
| 依赖提取 | `extractDependencies()` | ✅ 从 `metadata.dependencies` 和 `allowedTools` 提取 |
| 拓扑排序 | `topologicalSort()` | ✅ Kahn 算法 |
| 循环检测 | `detectCycles()` / `dfsCycle()` | ✅ DFS 三色标记法 |
| 递归收集 | `collectSkillsRecursive()` | ✅ |
| 缺失检测 | `missingSkills` | ✅ |

**关键发现**：`extractDependencies()` L174-185 会把 `allowedTools` 中的工具名也加入依赖列表——这意味着**技能与工具的依赖关系已被部分建模**，但仅限于"技能依赖工具"，没有"技能依赖技能"或"技能互斥技能"的显式声明。

### 3.5 协作技能机制

`collaboration_skills.cj` 实现了四个协作技能：

| 技能 | 职责 | 对标 Hermes |
|---|---|---|
| `TaskDecomposeSkill` | 将复杂任务分解为子任务 | `delegate_task` 的 goal 模式 |
| `AgentSelectSkill` | 为任务选择合适 Agent | Hermes delegation 路由 |
| `ContextPassSkill` | 在 Agent 间传递结构化上下文 | `context_from` 链式传递 |
| `ResultMergeSkill` | 聚合多个 Agent 的执行结果 | batch `delegate_task` |

这些是**多 Agent 协作**层面的并行，不是单 Agent 上下文层面的并行。

### 3.6 工作空间个性化文件机制

`AgentWorkspace`（`agent_workspace.cj`）已支持 8 类工作空间文件：

```cangjie
public enum WorkspaceFileType {
    | Agents      // AGENTS.md - Agent 定义
    | Soul        // SOUL.md - 灵魂文件（人格设定）
    | Tools       // TOOLS.md - 工具配置
    | Identity    // IDENTITY.md - 身份信息
    | User        // USER.md - 用户画像
    | Memory      // MEMORY.md - 记忆
    | Heartbeat   // HEARTBEAT.md - 心跳
    | DailyMemory // 日常记忆
}
```

**关键发现**：
- agentskills-runtime **已有** `USER.md` / `IDENTITY.md` / `SOUL.md` 等个性化配置文件机制
- `getCombinedMemory()` 会将这些文件内容合并注入上下文
- 但这些是**文件级配置**，不是**技能级配置**——没有作为技能插件管理，没有依赖/互斥关系，没有版本化

### 3.7 现有机制总结

| 维度 | 现状 | 与架构师期望的差距 |
|---|---|---|
| 技能即工具 | ✅ 所有技能注册为工具 | 工具调用 ≠ 上下文注入 |
| 串行编排 | ✅ SDD 六步等流水线 | 缺上下文级并行 |
| Parallel 枚举 | ✅ 枚举值存在 | ❌ 执行器未实现并行分支 |
| 依赖解析 | ✅ 拓扑排序+循环检测 | 缺互斥关系建模 |
| 个性化文件 | ✅ 8 类工作空间文件 | ❌ 未抽象为技能插件 |
| 多 Agent 协作 | ✅ 协作技能集 | 这是 Agent 间并行，不是技能间并行 |

---

## 4. deepseek-harness 技能机制研究

### 4.1 核心架构

研究 `packages/skill/` 目录，deepseek-harness 的技能系统采用 **Service Definition / Provider / Consumer** 三角架构：

| 包 | 角色 | ctx key |
|---|---|---|
| `skill/` | Service Definition：技能提供者注册与查找 | `ctx.skills` |
| `skill-badge/` | 内置 dsh badge 技能 | registers on `ctx.skills` |
| `skill-filesystem/` | 本地文件系统技能发现 | registers on `ctx.skills` |
| `tool-skill/` | 模型可见的 `skill` 工具 + 目录注入 | registers on `ctx.tools` |

### 4.2 技能注册表（SkillRegistry）

`packages/skill/skill/src/index.ts` 的 `SkillRegistry`：

- **分层注册**（`ScopedLayers<SkillLayer>`）：host 行 + 仓库插件落全局层，agent preset 的 standing composition 落 preset 层
- **重复名解析**：近层优先，同层内按 rank
- **缓存**：`collectCacheMaxEntries`（默认 128）
- **失效通知**：`skills/change` 事件

**关键接口**：

```typescript
interface SkillInvocationPolicy {
  readonly modelInvocable: boolean  // 模型可调用
  readonly userInvocable: boolean   // 用户可调用
}

interface SkillDefinition extends SkillSummary {
  readonly content: string  // Markdown 指令体
  readonly metadata?: Readonly<Record<string, unknown>>
}
```

### 4.3 技能注入机制（tool-skill）

`packages/skill/tool-skill/src/index.ts` 实现了**上下文级技能并行**的雏形：

#### 4.3.1 技能目录注入

通过 `agent/pre-step` 事件钩子（L213-251），在每步前注入 `<available_skills>` 目录：

```xml
<system-reminder>
A skill is a reusable set of task-specific instructions. The following skills are available in this session:

<available_skills>
- `skill-a`: description A
- `skill-b`: description B
</available_skills>

If the user names a skill, or the task clearly matches a skill's description, call the `skill` tool with the exact skill name before taking task actions. Load all applicable skills, then follow their full instructions.
</system-reminder>
```

#### 4.3.2 技能内容渲染

`renderSkillContent()`（L171-184）将技能渲染为 `<skill_content>` XML 块：

```xml
<skill_content name="skill-name">
<skill_resources>
Resources for this skill are managed by provider "...".
Load referenced resources only as needed.
</skill_resources>

<skill_instructions>
{技能 Markdown 正文}
</skill_instructions>
</skill_content>
```

#### 4.3.3 用户显式调用

`/skill-name` 语法（L177-204）触发技能注入：用户消息首行以 `/` 开头命名 user-invocable 技能时，渲染的技能体作为 `instructions` 形式上下文追加到消息列表末尾。

#### 4.3.4 模型按需加载

`skill` 工具（L81-161）让模型可以主动加载技能内容：

```typescript
const skillTool = defineTool({
  name: 'skill',
  description: 'Load the full instructions for an available skill...',
  parameters: {
    name: { type: 'string', required: true, description: 'The exact skill name...' },
  },
  async execute(args, exec) {
    const skill = await ctx.skills.get(args.name, lookup)
    return { name, provider, content: skill.content, ... }
  },
})
```

### 4.4 并行机制特点

deepseek-harness 的技能并行机制具备以下特点：

| 特点 | 实现方式 | 与架构师观点的契合度 |
|---|---|---|
| 多技能同上下文 | 模型可连续调用 `skill` 工具加载多个技能 | ✅ 完全契合 |
| 技能目录可见 | `<available_skills>` 注入 | ✅ 模型感知所有可用技能 |
| 用户显式触发 | `/skill-name` 语法 | ✅ 类似 personalization 一直加载 |
| 分层作用域 | `ScopedLayers` | ✅ 支持 preset 级技能隔离 |
| 调用策略 | `modelInvocable` / `userInvocable` | ⚠️ 没有"依赖/互斥"声明 |
| 驻留型技能 | 无显式机制 | ❌ 缺 personalization 类驻留技能 |

**关键洞察**：deepseek-harness 的 `agent/pre-step` 钩子是**上下文级并行**的典型实现——技能内容作为 instructions 注入上下文，模型在生成时可以综合多个技能的指令。这正是架构师所说的"提示词工程化并行"。

---

## 5. OpenClaw、Hermes 等同类产品研究

### 5.1 OpenClaw

基于 `docs/ref/GLM5TharnessVSAIinfra.md` 和 `docs/ref/GLM5Tagentskills-runtimeRoadMapAdv.md` 的研究：

| 维度 | OpenClaw | 数据来源 |
|---|---|---|
| 定位 | 开源个人 AI 助手 | GitHub 361K+ stars |
| 技能系统 | skills 插件框架 | 完整 Harness 能力 |
| 多模态 | 20+ IM 平台 | Telegram/QQ/Feishu/CLI/Web |
| 动态提示词 | 动态 System Prompt | 完整 Harness 能力 |
| 持久记忆 | ✅ | 完整 Harness 能力 |
| 仓颉版 | Metis Agent | 性能提升 20+ 倍 |

**OpenClaw 的技能并行机制**：
- skills 作为插件框架加载
- 动态 System Prompt 可组合多个技能的提示词
- Metis（仓颉版）完全兼容 OpenClaw skills 生态

**安全事件印证**（`docs/ref/deepseek-harness-VSAIinfra.md` L792）：
> 架构师 2026年3月7日发表《AgentSkills最佳实践》，呼吁监管层封禁不安全的 OpenClaw——3月8日人民日报和工信部发文提示 OpenClaw 安全风险。

### 5.2 Hermes

基于 `docs/ref/goai2026/gap-analysis.md` 第 12 章的 Hermes 专题研究：

#### 5.2.1 Hermes 核心机制

| 机制 | 说明 | agentskills-runtime 借鉴情况 |
|---|---|---|
| **Curator** | 技能质量管控，定期审查技能 | `skill_curator.cj` ✅ |
| **Kanban** | 多 Agent 工作队列，SQLite 持久化 | `kanban_dispatcher.cj` ✅ |
| **MemoryProvider ABC** | 记忆提供者插件体系 | `memory-provider` spec ✅ |
| **delegation** | 任务委派系统 | `collaboration_skills.cj` ✅ |
| **prompt caching** | 提示缓存机制 | `context-optimization` spec ✅ |
| **verification_evidence** | 验证证据账本 | `execution-audit` spec ✅ |
| **Footprint Ladder** | 优先扩展已有代码 → CLI → 技能 → 服务 → 插件 → MCP | 路线图已采纳 |

#### 5.2.2 Hermes 技能自进化

Hermes 的核心定位是"自进化的 AI 代理"（The self-improving AI agent），其技能并行机制特点：

- **技能创建**：从经验中创建技能
- **技能改进**：在使用中改进技能
- **永不自动删除**：只归档，Pinned 技能豁免
- **被动验证**：记录验证结果但不阻止 Agent 继续执行

#### 5.2.3 Hermes vs agentskills-runtime 架构对比

| 维度 | Hermes (Python) | agentskills-runtime (仓颉) |
|---|---|---|
| 语言 | Python | Cangjie |
| 技能并行 | delegation + Kanban | 协作技能集 + 看板调度 |
| 上下文管理 | prompt caching | 5 层压缩管道 |
| 自进化 | Curator 主动审查 | SkillCurator 被动记录 |

### 5.3 同类产品并行机制对比

| 产品 | 上下文级并行 | 编排级并行 | 推理级并行 | 驻留型技能 | 依赖/互斥声明 |
|---|---|---|---|---|---|
| **agentskills-runtime** | ❌ 缺 | ✅ SDD 流水线 | ❌ 缺 | ❌ 缺 | ⚠️ 仅依赖 |
| **deepseek-harness** | ✅ pre-step 注入 | ❌ 缺 | ❌ 缺 | ⚠️ 用户显式 | ❌ 缺 |
| **OpenClaw** | ✅ 动态 System Prompt | ❌ 缺 | ❌ 缺 | ✅ 插件常驻 | ❌ 缺 |
| **Hermes** | ⚠️ prompt caching | ✅ delegation + Kanban | ❌ 缺 | ✅ Pinned 技能 | ❌ 缺 |

**关键发现**：**没有任何一款产品同时具备"上下文级并行 + 依赖/互斥声明 + 驻留型技能"三要素**。这是 agentskills-runtime 可以超越业界最佳实践的切入点。

---

## 6. 技能并行机制对比分析

### 6.1 三层并行模型

基于研究发现，提出技能并行的三层模型：

```
┌─────────────────────────────────────────────────────────────┐
│                    推理级并行（Inference Parallelism）        │
│  多技能同时影响模型生成行为（架构师所说的"并行"）              │
│  实现：多技能 prompt 片段同时占据上下文窗口                    │
├─────────────────────────────────────────────────────────────┤
│                    编排级并行（Orchestration Parallelism）    │
│  多技能/多步骤并行执行（程序并发）                            │
│  实现：StepType.Parallel + 异步执行 + 结果聚合                │
├─────────────────────────────────────────────────────────────┤
│                    上下文级并行（Context Parallelism）        │
│  多技能同时存在于上下文（架构师核心诉求）                      │
│  实现：技能注入 + 依赖解析 + 互斥过滤 + 驻留管理              │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 架构师诉求映射

| 架构师诉求 | 对应层次 | 当前状态 | 目标状态 |
|---|---|---|---|
| 多技能同时添加到上下文 | 上下文级 | ❌ | ✅ |
| 多技能同时对大模型输入有效 | 推理级 | ❌ | ✅ |
| 依赖技能同时加载 | 上下文级 | ⚠️ 有解析无加载 | ✅ |
| 互斥技能避免同时加载 | 上下文级 | ❌ | ✅ |
| personalization 一直加载 | 上下文级（驻留） | ❌ | ✅ |
| 边说话边看东西边听 | 推理级 | ❌ | ✅ |

### 6.3 与程序并发的本质区别

| 维度 | 程序并发 | 技能并行（架构师所指） |
|---|---|---|
| 执行单元 | 线程/协程/进程 | SKILL.md 指令体 |
| 调度机制 | OS 调度器/事件循环 | LLM 推理引擎 |
| 通信机制 | 共享内存/消息传递 | 上下文窗口 |
| 同步机制 | 锁/信号量/屏障 | 依赖/互斥声明 |
| 冲突解决 | 竞态条件/死锁 | 互斥技能过滤 |
| 性能指标 | 吞吐量/延迟 | 上下文利用率/指令遵循率 |

---

## 7. personalization 技能插件方案研究

### 7.1 现有个性化机制

agentskills-runtime 已有的个性化文件（`AgentWorkspace`）：

| 文件 | 当前用途 | 作为技能的潜力 |
|---|---|---|
| `SOUL.md` | 人格设定 | ✅ 可作为 personalization 技能的"人格层" |
| `IDENTITY.md` | 身份信息 | ✅ 可作为 personalization 技能的"身份层" |
| `USER.md` | 用户画像 | ✅ 可作为 personalization 技能的"用户层" |
| `MEMORY.md` | 记忆 | ✅ 可作为 personalization 技能的"记忆层" |
| `AGENTS.md` | Agent 定义 | ⚠️ 这是 Agent 定义，不是个性化 |
| `TOOLS.md` | 工具配置 | ❌ 不适合作为技能 |

### 7.2 personalization 技能插件设计

#### 7.2.1 SKILL.md 草案

```yaml
---
name: personalization
description: >
  个性化技能插件——将 SOUL.md / IDENTITY.md / USER.md / MEMORY.md 等
  个性化配置文件机制抽象为技能，实现一直加载有效使用。
  与其他智能体项目的 user.md / profile.md 机制实现相同效果。
license: MIT
metadata:
  author: UCToo Team
  category: personalization
  tags: ["personalization", "profile", "always-on", "驻留"]
  load_policy: always_on  # 驻留型：会话生命周期内持续生效
  priority: high          # 高优先级：先于其他技能加载
allowed-tools: filesystem
---
```

#### 7.2.2 与现有机制的集成

```
AgentWorkspace.getCombinedMemory()
    ↓
personalization 技能插件
    ↓
作为 instructions 注入上下文（而非工具调用）
    ↓
模型在生成时持续感知个性化设定
```

#### 7.2.3 与 deepseek-harness 的对比

| 维度 | deepseek-harness `/skill-name` | personalization 技能插件 |
|---|---|---|
| 触发方式 | 用户显式 `/` | 自动驻留 |
| 生效范围 | 单次调用 | 会话全生命周期 |
| 注入形式 | instructions 上下文 | instructions 上下文 |
| 可组合性 | ✅ 多技能 | ✅ 与 sdd/cangjie-coder 并行 |

---

## 8. 技能并行机制设计方案（超越业界最佳实践的头脑风暴）

### 8.1 设计目标

1. **上下文级并行**：多技能同时注入上下文，模型综合多技能指令行为
2. **依赖/互斥声明**：SKILL.md 显式声明 `depends_on` / `conflicts_with`
3. **驻留型技能**：`load_policy: always_on` 的技能持续生效
4. **上下文预算管理**：多技能注入时的 token 预算分配
5. **技能冲突检测**：加载前检测互斥技能，避免上下文污染

### 8.2 SKILL.md 扩展字段

```yaml
---
name: my-skill
description: ...
metadata:
  # 现有字段
  author: ...
  tags: [...]

  # 新增：技能并行声明
  load_policy: always_on | on_demand | conditional
  priority: high | medium | low
  depends_on: [skill-a, skill-b]           # 依赖技能（必须同时加载）
  conflicts_with: [skill-c]                # 互斥技能（不能同时加载）
  context_budget_tokens: 2000              # 该技能占用的上下文 token 预算
  compatible_with: [skill-d, skill-e]      # 显式声明兼容技能（可选）
---
```

### 8.3 技能加载器扩展

```
用户请求 / Agent 初始化
    ↓
1. 收集所有 load_policy=always_on 的技能（驻留型）
    ↓
2. 收集用户显式调用的技能（/skill-name）
    ↓
3. 收集模型按需加载的技能（skill 工具调用）
    ↓
4. 依赖闭包计算：对每个技能计算 depends_on 闭包
    ↓
5. 互斥过滤：检测 conflicts_with，按 priority 保留高优先级
    ↓
6. 上下文预算检查：累计 context_budget_tokens，超预算时按 priority 淘汰
    ↓
7. 渲染注入：将存活技能的 content 渲染为 <skill_content> 注入上下文
    ↓
8. 模型推理：多技能同时作用于模型生成
```

### 8.4 超越业界最佳实践的演进建议

#### 8.4.1 技能权重衰减（超越 Hermes prompt caching）

**问题**：多技能长期驻留会导致上下文膨胀，模型注意力分散。
**方案**：引入**使用频率驱动的权重衰减**——长期未触发工具调用的驻留技能，其 prompt 片段逐步"折叠"为摘要，保留调用入口但释放上下文空间。

```
技能 A（always_on, 最近 10 轮未触发）
    ↓ 衰减
技能 A 摘要（仅保留 name + description + 调用入口）
    ↓ 重新触发
技能 A 完整内容（按需展开）
```

#### 8.4.2 技能冲突的语义级检测（超越所有同类产品）

**问题**：`conflicts_with` 是显式声明，无法捕捉隐式冲突（如两个技能都要求模型"用英文回复"）。
**方案**：引入**技能语义向量**——用 embedding 计算技能指令体的语义相似度，相似度超阈值时告警潜在冲突。

#### 8.4.3 技能组合的上下文预算分配（超越 deepseek-harness）

**问题**：deepseek-harness 的 `catalogDescriptionMaxLength` 只限制目录描述长度，不限制技能内容总 token。
**方案**：引入**技能上下文预算分配器**——按技能 priority 和使用频率分配 token 预算，确保高价值技能获得足够上下文空间。

#### 8.4.4 技能并行的可观测性（超越所有同类产品）

**问题**：多技能同时生效时，难以归因模型行为是由哪个技能驱动的。
**方案**：引入**技能溯源标记**——模型生成时标注受哪些技能指令影响，用于事后归因和技能效果评估。

```
模型输出: "根据 sdd 技能的六步流水线要求，我先写 spec.md..."
    ↓ 溯源
受影响技能: [sdd, cangjie-coder, personalization]
```

#### 8.4.5 技能并行的形式化验证

**问题**：技能依赖/互斥关系可能形成不可满足的约束系统。
**方案**：将技能并行加载建模为**约束满足问题（CSP）**，用 SAT 求解器验证可满足性：

```
变量: x_skill_a ∈ {0, 1}  # 是否加载
约束:
  x_personalization = 1                    # always_on
  x_sdd → x_cangjie_coder = 1             # depends_on
  x_skill_a + x_skill_b ≤ 1               # conflicts_with
  Σ x_i * budget_i ≤ total_budget          # 上下文预算
```

### 8.5 与 agentskills-runtime 现有架构的集成路径

```
现有: SkillAwareAgent._registerSkillsAsTools()
        ↓ 所有技能 → SkillToToolAdapter → _toolManager

演进: SkillAwareAgent._registerSkillsAsTools()
        ↓
      SkillContextInjector（新增）
        ├── collectAlwaysOnSkills()        # 驻留型技能
        ├── resolveDependencies()          # 依赖闭包（复用 SkillDependencyResolver）
        ├── filterConflicts()              # 互斥过滤（新增）
        ├── allocateBudget()               # 预算分配（新增）
        └── injectToContext()              # 上下文注入（新增，借鉴 deepseek-harness）
        ↓
      _registerSkillsAsTools()             # 现有工具注册保留
```

**关键原则**（遵循用户偏好 P6：复用而非重建）：
- 复用 `SkillDependencyResolver` 的拓扑排序和循环检测
- 复用 `CompositeSkillToolManager` 的 `availableSkills` / `enabledSkills`
- 复用 `AgentWorkspace` 的个性化文件加载
- 新增 `SkillContextInjector` 负责上下文级并行注入
- 借鉴 deepseek-harness 的 `renderSkillContent` 渲染格式

---

## 9. 结论与建议

### 9.1 核心结论

1. **架构师诉求明确**：技能并行 = 上下文级多技能同时有效，不是程序并发
2. **agentskills-runtime 有基础但缺关键能力**：有依赖解析、协作技能、个性化文件，但缺上下文注入、互斥过滤、驻留管理
3. **deepseek-harness 有参考实现**：`agent/pre-step` 钩子 + `<skill_content>` 渲染是上下文级并行的典型实现
4. **业界无完整方案**：没有任何产品同时具备"上下文级并行 + 依赖/互斥声明 + 驻留型技能"三要素
5. **personalization 技能插件可行**：现有 `AgentWorkspace` 的 8 类文件可自然抽象为技能

### 9.2 实施建议

| 优先级 | 建议 | 复用基础 | 新增工作 |
|---|---|---|---|
| P0 | 实现 `SkillContextInjector` 上下文注入 | `SkillDependencyResolver` | 注入逻辑 |
| P0 | 扩展 SKILL.md 支持 `load_policy` / `conflicts_with` | 现有 SKILL.md 解析 | 字段扩展 |
| P1 | 实现 personalization 技能插件 | `AgentWorkspace` | SKILL.md 包装 |
| P1 | 实现互斥过滤 | 无 | `ConflictFilter` |
| P2 | 实现上下文预算分配 | 无 | `BudgetAllocator` |
| P2 | 实现技能权重衰减 | 无 | `WeightDecayer` |
| P3 | 实现技能语义冲突检测 | embedding 模型 | `SemanticConflictDetector` |
| P3 | 实现技能溯源标记 | 无 | `ProvenanceTracker` |

### 9.3 与 SDD 规范的关系

本研究报告遵循 SDD 六步流水线的**研究步**产出规范：
- 产出位置：`.codeartsdoer/specs/concurrent_skills/research.md`
- 后续步骤：spec（需求规格）→ design（设计方案）→ task（任务分解）→ code → test
- 建议的 `feature_name`：`concurrent_skills` 或 `skill_parallel`

### 9.4 风险与约束

1. **上下文膨胀风险**：多技能注入可能导致上下文超窗口，需严格预算管理
2. **指令冲突风险**：多技能可能给出矛盾指令，需语义级冲突检测
3. **归因困难风险**：多技能并行时模型行为归因复杂，需溯源标记
4. **性能影响风险**：上下文注入增加每轮推理成本，需权衡
5. **向后兼容风险**：扩展 SKILL.md 字段需保持对现有 49 个技能的兼容

---

## 10. 参考资料

### 10.1 架构师观点
- `apps/agentskills-runtime/docs/ref/ConcurrentSkills.md` — 架构师补充观点（2026-10-05）

### 10.2 agentskills-runtime 源码
- `src/skill/skill_aware_agent.cj` — 技能感知 Agent
- `src/skill/composite_skill_tool_manager.cj` — 统一管理器
- `src/skill/composition_definition.cj` — 组合定义（StepType 枚举）
- `src/skill/composition_executor.cj` — 组合执行器
- `src/skill/dependency_resolver.cj` — 依赖解析器
- `src/skill/collaboration_skills.cj` — 协作技能集
- `src/memory/workspace/agent_workspace.cj` — 工作空间个性化文件
- `skills/sdd/SKILL.md` — SDD 技能定义
- `skills/sdd/COMPOSITION.yaml` — SDD 六步编排

### 10.3 deepseek-harness 源码
- `packages/skill/skill/src/index.ts` — SkillRegistry
- `packages/skill/tool-skill/src/index.ts` — 技能工具 + 目录注入
- `packages/skill/README.md` — 技能能力族说明

### 10.4 同类产品研究
- `docs/ref/GLM5TharnessVSAIinfra.md` — Harness vs AI 基础设施（含 OpenClaw vs Metis）
- `docs/ref/GLM5Tagentskills-runtimeRoadMapAdv.md` — 路线图（含 Metis 实战验证）
- `docs/ref/deepseek-harness-VSAIinfra.md` — deepseek-harness 对比分析
- `.codeartsdoer/specs/goai2026/gap-analysis.md` — Hermes 项目借鉴（第 12 章）

### 10.5 现有相关 spec
- `.codeartsdoer/specs/skill-composition-engine/spec.md` — 技能组合引擎
- `.codeartsdoer/specs/collaboration-skills/spec.md` — 协作技能
- `.codeartsdoer/specs/skill-evolution/spec.md` — 技能自进化
- `.codeartsdoer/specs/context-optimization/spec.md` — 上下文优化
- `.codeartsdoer/specs/memory-provider/spec.md` — 记忆提供者
- `.codeartsdoer/specs/language-skills-orchestration/` — 语言技能编排

---

## 附录 A：技能并行机制术语表

| 术语 | 定义 |
|---|---|
| **上下文级并行** | 多技能 prompt 片段同时占据模型上下文窗口 |
| **编排级并行** | 多技能/多步骤通过程序并发执行 |
| **推理级并行** | 多技能同时影响模型生成行为 |
| **驻留型技能** | `load_policy=always_on`，会话生命周期内持续生效 |
| **依赖技能** | `depends_on` 声明，必须同时加载 |
| **互斥技能** | `conflicts_with` 声明，不能同时加载 |
| **上下文预算** | 多技能注入时的 token 分配限额 |
| **技能溯源** | 标注模型输出受哪些技能指令影响 |

## 附录 B：架构师观点原文

> 我们知道agentskills开放标准本质就是提示词的工程化方案。我们已经在agentskills-runtime中实现了一切皆技能的插件系统。我们也有技能优先的设计理念。那么我们应该把这些设计哲学更广泛的应用。在其他的一些智能体项目中，一般都有user.md或者profile.md这种提供个性化的配置文件机制。研究一下我们是不是可以将类似的个性化机制做成skills，比如叫personalization技能插件，和其他智能体项目中的个性化配置文件机制实现相同的效果。然后研究一下agentskills-runtime当前是不是只支持技能的串行使用？因为我们要支持将一切都做成技能，肯定需要技能的并行使用机制。像personalization技能插件这样的技能可以是一直都加载有效使用的，并行还可以使用其他的技能，比如sdd技能和cangjie-coder等开发技能。也就是我们需要在agentskills-runtime中支持技能的并行使用机制。这个机制也很符合现实世界的运行机制，人类就可以边说话边看东西边听。智能体也应该有类似的技能并行机制。

> 补充一些架构师观点，这里所说的技能并行机制，并不是指程序并发的意思，正如开头所说的agentskills本质是提示词工程化因此技能的并行，其实就是将多个技能可以同时添加到上下文中，使得多个技能同时对于大模型的输入都是有效的。这样大模型就可以表现出同时使用了多个技能的输出行为。而技能之间也就存在了依赖或者互斥的关系，依赖的技能应该同时加载，而互斥的技能就应避免同时加载。请参考这个技能并行的机制进行研究。当然作为一名优秀的技术合伙人你也可以发散思维头脑风暴，提出你对技能并行机制的一些超越业界最佳实践的理解。

---

**报告完成时间**: 2026-10-05
**报告作者**: spec-requirement-agent
**下一步**: 等待用户确认后，可进入 SDD spec 步生成需求规格 spec.md