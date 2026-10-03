# 主 Agent 系统提示词管理（禁止硬编码）

> 一句话原则：**提示词是数据，不是代码**。改提示词不该改 `.cj`、不该重新编译，业务同学在后台就能改。
> 违规实例（2026-10-02）：曾在 `WebMCPProtocol.cj` 里加了 `deliveryGuardPrompt()`，把「交付约束」5 条
> 写死在仓颉代码里——后台看不见、改不掉、改一次要编译一次。已迁到 `AGENTS.md` 并删除该函数。

## 1. 三级来源（按优先级，命中即返回）

| 级别 | 来源 | 谁维护 | 怎么改 |
|------|------|--------|--------|
| ① | **Agent 定义文件** `AGENTS.md` 的 `---` 以下正文（真相源） | 开发 / 运维 | 直接编辑文件，重启 runtime |
| ② | 数据库 `agents` 表 `agent_type=MAIN` 的 `system_prompt` | 后台可视化 | 「Agent 管理」里编辑 MAIN agent 的 system_prompt |
| ③ | 数据库 `config` 表 key=`MAIN_AGENT_FALLBACK_PROMPT` 的 `value` | 后台可视化 | 「系统配置」新增该 key |
| ④ | 都没有 → **空串 + WARN 日志** | — | 不存在「代码里的默认提示词」这一级 |

解析入口只有一个：`src/app/services/bridge/main_agent_prompt_resolver.cj` 的
`MainAgentPromptResolver.resolve(agentDef, tag)`。所有聊天链路（WebMCP 流式 / 非流式、WS）都走它。

**为什么第 ④ 级不留硬编码兜底**：按「配置即事实」原则，不做用户看不见的隐藏动作。没配就是没配，
宁可让 agent 缺少人格设定并留下明确告警，也不塞一份与后台配置脱节、用户改不掉的默认文案。

### ① 与 ② 的一致性

`AGENTS.md` 的正文由 `AgentLoader`（`src/core/agent/agent_loader.cj` 的 `buildAgentFromYaml`）解析为
`AgentDefinition.systemPrompt`；启动时 `AgentRuntimeBridge.createRuntimeAgent` 会把它回写 `agents` 表
（同名记录走 `update`，不是只 insert）。所以**改 AGENTS.md 后后台看到的是同一份内容**，不存在两份真相。

## 2. 代码里允许什么 / 禁止什么

**允许**：装配**运行时才存在**的数据。目前只有一处——`WebMCPProtocol.buildAgentSystemPrompt()`：

- 当前装了哪些技能（frontmatter 摘要）
- 前端注册了哪些工具（`FrontendToolRegistry`）
- 该用户能访问哪些菜单（`MenuDataProvider` 按 userId 查）

这些内容在编译期不存在、因人而异，无法写进静态文件。

**禁止**：任何策略性 / 业务性文案——人格设定、交付约束、委派规则、输出格式要求、安全约束……
一律写进 `AGENTS.md`（或子 agent 的 `agents/<name>.md`）。判断标准很简单：
**这段文案换个项目还成立吗？** 成立 → 它是运行时装配骨架；不成立 → 它是业务规则，必须落到定义文件里。

## 3. 工具 / 功能模块里的提示词：走 PromptConfig 文件覆盖

不是所有提示词都属于 Agent 人格。工具内部的指令（如图片理解的系统提示词）应当用
`PromptConfig` 已有的多目录扫描机制外置，而不是写死：

```cangjie
// 1) prompt_config.cj 提供通用入口（已新增）
PromptConfig.resolveCustom("vision-understand.system.md")   // 未命中返回空串

// 2) 调用方：先取可配置文件，未配置才回落内置默认
public static func resolveSystemPrompt(): String {
    let custom = PromptConfig.resolveCustom(ImageUnderstandTool.FILE_SYSTEM_PROMPT)
    if (!custom.trimAscii().isEmpty()) { return custom }
    ImageUnderstandTool.SYSTEM_PROMPT
}
```

文件放 `skills/<name>/prompts/`（技能内，高优先级）或 `./prompts/`（全局兜底）即生效，
改提示词不重新编译。机制细节见 [技能内置提示词机制](./skill-prompt-mechanism.md)。

已外置：`src/tool/vision_tools.cj` 的 `SYSTEM_PROMPT` / `DEFAULT_QUESTION`
（对应 `vision-understand.system.md` / `vision-understand.question.md`）。

**暂未外置（框架内核，不建议动）**：`agent_op.cj` 的 JSON 修复提示词、`tool_select_agent.cj`
的工具选择提示词、`naive_executor.cj` / `plan_react/*.cj` 的规划与知识抽取模板、
`rag/graph/mini_rag.cj` 的实体抽取与摘要模板。它们带 `{占位符}`、是执行器算法的一部分，
调整即改变框架行为——真要外置需连同模板变量一起做成配置，属于独立议题。

## 4. 改提示词的三种姿势

1. **改文件**（推荐，可版本化）：编辑 `AGENTS.md` → 重启 runtime → 后台自动同步。
2. **改后台**（无需重启进程但仍需新建会话）：「Agent 管理」→ MAIN agent → `system_prompt`。
   注意：下次 runtime 启动若 `AGENTS.md` 存在，会以文件为准回写覆盖这里的手改内容。
3. **配置兜底**：「系统配置」新增 `MAIN_AGENT_FALLBACK_PROMPT`，仅在 ①② 都缺失时生效。

## 5. 子 Agent 与其它 agent

`agents/<name>.md`、`skills/<skill>/agents/<name>.md` 同样由 `AgentLoader` 解析，
frontmatter + 正文 = 定义 + systemPrompt，规则与主 Agent 完全一致——**也不要在代码里拼它们的提示词**。

## 6. 已知限制

- 改 `AGENTS.md` 目前**需要重启 runtime**（`AgentLoadManager` 在启动期 `loadFromDirs`，
  agent 实例的 `systemPrompt` 在构造时确定）。热更新的整体规划见
  `.codeartsdoer/specs/dynamic-model-channel/`（通道与配置的运行时热生效），
  提示词热加载可作为该方案的延伸项。
- 本次改动清单（2026-10-02）：新增 `main_agent_prompt_resolver.cj`；
  `WebMCPProtocol.cj` 删除 `deliveryGuardPrompt()` 及两处注入、两条构造路径改走 resolver；
  `WsChatController.cj` 硬编码 fallback 改走 resolver；`AGENTS.md` 新增「交付与落盘约束」与
  「关于本文件（提示词怎么维护）」两节；`prompt_config.cj` 新增 `resolveCustom()`，
  `vision_tools.cj` 的两段提示词改为「可配置文件优先 + 内置默认回落」。
