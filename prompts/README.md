# 提示词配置目录（PromptConfig）

本目录用于**可视化配置**框架内的提示词，替代原先硬编码在 `.cj` 源码里的写法。
设计背景见 `src/compactor/prompt_config.cj` 的类注释。

## 覆盖机制

启动时宿主读取环境变量 `PROMPTS_DIR`（缺省 `./prompts`），加载以下文件。
**文件不存在 → 静默回落到内置默认提示词**（零回归，什么都不配也能跑）。

| 文件 | 作用 | 必须保留的占位符 |
|---|---|---|
| `tool-summarize.system.md` | 工具结果压缩：system | — |
| `tool-summarize.user.md` | 工具结果压缩：user（全局默认） | `{tool_call}`、`{tool_result}` |
| `tool-summarize.user.<profile>.md` | 工具结果压缩：user（按 profile 覆盖） | 同上 |
| `conversation-summary.system.md` | 会话压缩：system | — |

**优先级**：`tool-summarize.user.<profile>.md` > `tool-summarize.user.md` > 内置默认。

## profile 是什么

工具结果压缩发生在宿主侧（`AgentTask.doInvokeTool`）。profile 不是一个名字，而是
**逗号分隔的候选链**，按书写顺序探测、首个命中即用：

```
<已注册技能名…>,<agent 名>
```

技能名来自 `SkillAwareAgent.promptProfileCandidates()`。之所以要前置技能名：
技能名与 agent 名天然不一致（长程任务的技能叫 `long-running-task`，
而承载它的 agent 常叫 `MainAgent`），只认 `agent.name` 的话
`tool-summarize.user.long-running-task.md` **永远命中不了**——
2026-09-15 实测日志中「命中 profile 摘要提示词」出现 **0 次**，全部回落默认。

> 多个候选都有同名文件时**靠前者优先**。因为技能名的迭代顺序不保证，
> 同一个 agent 上不要给两个技能配置同用途的提示词文件。

候选名的规整规则（`PromptConfig.sanitizeProfile`）：

- 只保留 ASCII 小写字母、数字、`-`、`.`、`_`；大写转小写；
- 连续的非保留字符（含中文等多字节字符）折叠为**单个** `_`；
- 总长上限 40。

因此 profile 文件名必须是**规整后**的形式。对照示例：

| agent.name | 规整后 profile | 覆盖文件名 |
|---|---|---|
| `long-running-task` | `long-running-task` | `tool-summarize.user.long-running-task.md` |
| `Main Agent` | `main_agent` | `tool-summarize.user.main_agent.md` |
| `投资研究助手` | `_` | 不适用（建议改用全局 `tool-summarize.user.md`） |

> ⚠️ 纯中文的 agent 名规整后只剩 `_`，无法用 profile 文件区分。
> 这类场景请直接修改**全局** `tool-summarize.user.md`（对所有 agent 生效）。

## 本目录随仓库提供的内容

- `tool-summarize.system.md` / `tool-summarize.user.md`：改进版默认提示词，
  显式要求保留「目标 / 进度 / 已完成与待办 / 失败项 / 下一步」——
  这是长程任务跨回合不丢上下文的关键。
- `tool-summarize.user.long-running-task.md`：长程任务技能专用（profile = `long-running-task`）。
  因为候选链会前置**已注册技能名**，只要 `long-running-task` 技能挂在该 agent 上就会自动命中，
  **不要求 agent 名也叫 `long-running-task`**。同名副本在
  `skills/long-running-task/prompts/` 下，供技能随包分发。
- `conversation-summary.system.md`：会话压缩提示词。

## 改完怎么生效

无需重新编译框架源码，改文件后**重启进程**即可（提示词在启动时加载一次）。
