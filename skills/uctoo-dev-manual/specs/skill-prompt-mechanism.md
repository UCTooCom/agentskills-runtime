# 技能内置提示词机制（PromptConfig 多目录扫描）

> 来源：`src/compactor/prompt_config.cj`（v0.0.27 引入，对齐「尽量可视化配置而不硬编码」的设计哲学）。
> 解决的问题：① 工具结果压缩/会话压缩提示词原先硬编码在 `prompts.cj`，改一句提示词要重新编译，业务同学改不了；② 长程任务需要「保留跨回合进度」的摘要提示词，而通用 `Summarize the tool execution result.` 不要求保留目标/进度。

## 1. 设计

- **内置默认仍在 `prompts.cj`**（保证「什么都不配也能跑」，零回归）。
- **多目录扫描**：`PromptConfig.loadFromDirs(dirs)` 接收**有序目录列表**，依次扫描，首个命中即生效；机制对齐 `AgentLoadManager.loadFromDirs`。
- **组合根注入优先级**（见 `main.cj`）：
  ```
  技能内 prompts（skills/<name>/prompts，最高优先级）
        ↓
  全局 PROMPTS_DIR / ./prompts（兜底，最低优先级）
        ↓
  内置默认（prompts.cj）
  ```
  即：`skills/long-running-task/prompts/tool-summarize.user.long-running-task.md` **高于** `./prompts/` 同名文件生效——编辑技能目录内的 prompts 即可，无需同步到全局。
- **可被同名文件覆盖**：`<dir>/tool-summarize.user.md` 等。
- **可按 profile 再覆盖**：`<dir>/tool-summarize.user.<profile>.md`，profile 由调用方给出（`AgentTask` 传 `agent.name` / 技能名）。

## 2. 三类提示词与内置默认

| 文件基础名 | 用途 | 内置默认（prompts.cj） |
|------------|------|------------------------|
| `tool-summarize.system.md` | 工具结果压缩 system | — |
| `tool-summarize.user.md` | 工具结果压缩 user（须保留 `{tool_call}` / `{tool_result}` 占位） | `Summarize the tool execution result.` |
| `conversation-summary.system.md` | 会话压缩 system | — |

> 内置默认 `Summarize the tool execution result.` 在长程任务场景的缺陷：不要求保留「目标 / 当前进度 / 已完成与待办 / 失败项 / 下一步」，而长程任务恰恰依赖这些跨回合信息不被压缩丢失。

## 3. profile 候选链（关键）

调用方（`SimpleToolCompactor`）拿到的 profile 是 `agent.name`（如 `MainAgent`），而长程任务的定制提示词文件名是 `tool-summarize.user.long-running-task.md`——**技能名与 agent 名天然不一致**，单个名字永远命中不了。

因此 `resolveToolSummarizeUser(profile)` 把 profile 当作**逗号分隔的候选链**：按书写顺序探测，首个命中即用；全未命中再回落全局文件、内置默认。`tryProfileUser(key)` 严格只查 `<dir>/tool-summarize.user.<key>.md` 一个文件，未命中返回**空串**（回落由候选链统一负责，否则第一个候选就会拿默认值，后面候选轮不到）。

## 4. 文件名约定（含一个真实踩坑教训）

拼 profile 文件必须用**不含扩展名的基础名**：

```cangjie
FILE_TOOL_SUMMARIZE_USER_BASE = "tool-summarize.user"   // 不含 .md
// 正确：tool-summarize.user.long-running-task.md
PromptConfig.readFirstMatch("${FILE_TOOL_SUMMARIZE_USER_BASE}.${key}.md")
```

⚠️ **踩坑**：曾用 `FILE_TOOL_SUMMARIZE_USER = "tool-summarize.user.md"` 直接拼 `${key}.md`，导致拼出 `tool-summarize.user.md.long-running-task.md`（**双扩展名**），而磁盘真实文件名是 `tool-summarize.user.long-running-task.md`，于是永远读不到、始终回落内置默认。此 bug 已修复（新增 `FILE_TOOL_SUMMARIZE_USER_BASE`）。

## 5. 失败策略

目录不存在、文件缺失、读取异常 —— 一律**静默回落到上一级默认**，绝不因提示词读不到而让任务跑不起来。

## 6. 如何为技能新增一段定制提示词（实操）

以「让长程任务工具摘要保留进度」为例：

1. 在技能目录建 `prompts/`：`skills/long-running-task/prompts/`
2. 新增 profile 文件：`tool-summarize.user.long-running-task.md`（内容须保留 `{tool_call}` / `{tool_result}` 占位，并写明要保留 Status/Artifacts/Progress/Blockers/Next 等结构）。
3. 若想覆盖全局默认（所有技能通用），也可放 `./prompts/tool-summarize.user.md`。
4. 启动 runtime 主包 `cjpm build` + 重启，无需改 `prompts.cj` 源码。

## 7. 如何验证生效

- 启动日志应出现：`多目录提示词已加载（优先级高→低）: <技能 prompts> > ./prompts（覆盖文件 N 个）`。
- 工具调用后摘要应命中：`命中 profile 摘要提示词: long-running-task`，且摘要变为定制结构（Status/Artifacts/Progress/Blockers/Next），而非 `Summarize the tool execution result.`。
- `PromptConfig.loadedFrom`（只读属性）返回完整优先级链（分号分隔），供 OPS 排查。

## 8. 多目录目录发现（main.cj 侧）

`main.cj` 的 `discoverSkillPromptDirs()` 复用 `ProgressiveSkillLoader` 的技能基目录公式（`${currentDir}/skills` + `${currentDir}/src/examples`，尊重 `SKILL_INSTALL_PATH`），用 `Directory.readFrom` 枚举每个基目录的子目录，凡含 `prompts/` 子目录者加入结果；`PROMPTS_DIR`（默认 `./prompts`）排最后作为兜底。空目录/缺失文件均跳过，不报错。
