# AgentSkills Runtime v0.0.28 发布说明

**发布日期**: 2026-09-19
**版本**: 0.0.28
**代号**: Long-Running Autonomy（长程自主 · 链路稳态）
**平台**: Windows x64, Linux x64, macOS x64/ARM64

---

## 重大变更

### 1. long-running-task：AI 自主驱动长程任务系统（L3 进程隔离轨插件）

本版本的核心交付。插件以 **L3 进程隔离轨**（`mode: process`，JSON-RPC over stdio + cordis-cj）形态落地，承担"人设目标 → AI 自主规划执行 → 人评审交付"的完整闭环，支持分钟级到天级任务的持久化、可中断恢复、树式分解与产物验核。

#### 架构

```
┌────────────────────────────────────────────────────────────────────────────┐
│                 long-running-task 插件（L3 进程隔离轨）                        │
│                 JSON-RPC over stdio · cordis-cj · maxRounds 30              │
│                                                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │ LrtPlanner   │  │ LrtExecutor  │  │ LrtVerifier  │  │ LrtSelfEvolve  │ │
│  │ 目标解析      │  │ 回合循环      │  │ 产物验核      │  │ 自进化闭环      │ │
│  │ 任务树分解    │  │ 检查点        │  │ 验核报告      │  │ 五环节          │ │
│  │ 技能发现      │  │ 子任务派发    │  │              │  │                │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └───────┬────────┘ │
│         └────────────┬────┴─────────────────┴─────────────────┘            │
│                      ▼                                                      │
│         ┌────────────────────────────────────────────────┐                 │
│         │  LrtEventRelay → LrtEventBridge（lrt_event）    │                 │
│         │  step_start / step_complete / checkpoint_saved  │                 │
│         │  progress_update / goal_achieved                │                 │
│         │  review_required / contract_drift               │                 │
│         └──────────────────────┬─────────────────────────┘                 │
│                                ▼                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  宿主侧服务代理（插件不直连数据库）                                    │  │
│  │  host.db  受控 CRUD（tableWhitelist + 行级权限）                       │  │
│  │  host.db_schema_lookup  表结构 / 幂等键 / 示例行（数据契约注入）        │  │
│  │  host.mcp / host.event / host.cache / host.log                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 接口面

**用户 API**（HTTP，前缀 `/api/v1/uctoo/long_running_task`，实际落地 10 个端点）：

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/add` | 创建长程任务（高层目标 → 解析 → 规划 → 建 crontab → 立即首回合） |
| POST | `/intervene/:taskId` | 人工干预：暂停 / 恢复 / 取消 / 调整目标 |
| GET | `/tree/:rootId` | 取任务树（含子任务层级与状态） |
| GET | `/progress/:taskId` | 取实时进度（步状态 / 检查点 / 最近事件） |
| GET | `/checkpoints/:taskId` | 取检查点列表 |
| POST | `/verify/:taskId` | 触发验核（产物结构校验 + 验核报告） |
| POST | `/evolve/:agentId` | 触发自进化闭环 |
| POST | `/deliver/:taskId` | 交付决策：`confirm` / `abandon` |
| POST | `/review/:taskId` | 评审决策：`improve` / `abandon`（改进 → 触发 replan） |
| GET | `/trace` | 全量链路追踪（跨任务 trace 查询） |

**插件 RPC**（JSON-RPC over stdio，经 `CordisHostManager` 透传，7 个方法）：
`lrt-plan` / `lrt-execute` / `lrt-intervene` / `lrt-verify` / `lrt-evolve` / `lrt-deliver` / `lrt-review`

> 规格原规划 7 个用户 API + 6 个插件 RPC，实际落地为 **10 + 7**（多出 `intervene`、`checkpoints`、`trace` 与 `lrt-intervene`），能力较规划更完整。

#### 核心能力

| 能力 | 说明 |
|------|------|
| 自主规划 | AI 按高层目标自主分解任务树、选择技能、编排流程，而非按硬编码步骤执行 |
| 可中断恢复 | 检查点落 `agent_contexts` 表，故障/干预后断点续跑 |
| 子任务派发 | DAG 步骤分发 + 结果聚合 + 并发控制（`LrtCompositionRunner`） |
| 产物验核 | `long_running_task_artifact` 记录每步产物，含 `verification_status` 与结构化 `verification_result` |
| 自进化闭环 | `LrtSelfEvolutionLoop` 五环节：实测驱动 → 根因分析 → 增量优化 → 防回退 → 显式约束注入 |
| 人在回路 | SKILL.md `decision-points` 声明 6 个结构化决策点：`pause`/`resume`/`cancel`/`replan`/`human_confirm`/`review`，宿主按 `skillName` + `decisionPointId` 校验时效，失效自动降级为普通审批 |
| 数据契约 | `DATA_CONTRACT.yaml` 描述表角色 / 幂等键 / 写入纪律 / 示例行，契约漂移经 `contract_drift` 事件告警 |
| 复用现有基建 | 不重造调度引擎（crontab SchedulerEngine + f_ticktock）、检查点（CheckpointManager）、DAG（DagScheduler）、通知通道（WebSocketEventBridge / SseEventBridge） |

#### 交付状态

插件源码 23 个 `.cj` 文件，规格任务完成度 **177/237（74.7%）**；`spec.md`（87KB）、`design.md`（115KB）、`tasks.md`（211KB）三件套齐全，另有 5 轮问题分析、3 份评审报告与失断语义诊断记录。

---

### 2. multi-search-engine：替换低质量的 web-search-assistant

旧 `skills/web-search-assistant` 用 BeautifulSoup 硬编码解析百度/搜狗结果页 CSS 选择器（`div.result`、`div.c-container`、`.c-abstract`），一旦站点改版或缺失 `BAIDUID` cookie 就**静默返回 0 条结果**，agent 反复重试空耗推理步数；百度 `href` 还是 `link?url=` 重定向而非真实 URL。

本版本引入成熟的 **multi-search-engine** 技能（v2.1.3，无需任何 API Key）取而代之，其本质是**纯 SOP**——直接调 `web_fetch` 抓各引擎搜索 URL，把"易碎"从脚本选择器转移到了"可选数据源"上。

#### 引擎矩阵

| 分类 | 数量 | 引擎 |
|------|------|------|
| 国内 | 7 | 百度、Bing CN、Bing INT、360、Sogou、微信、神马 |
| 国际 | 9 | Google、Google HK、DuckDuckGo、Yahoo、Startpage、Brave、Ecosia、Qwant、WolframAlpha |

#### 工作流要点

| 环节 | 做法 |
|------|------|
| 语言评估 | 中文查询走国内引擎，非中文走国际引擎 |
| 受控抓取 | 批量 3~4 个引擎串行，请求间隔 1~2 秒，携带标准浏览器请求头 |
| Cookie 管理 | **仅内存持有**，按需在 403/429 时从引擎首页获取，检索结束即清除，不落 `config.json` |
| 重试 | Cookie/Session 类失败隔 2 秒重试一次 |
| 结果聚合 | 汇总成功结果，输出核心检索报告 |

支持高级算子（`site:` / `filetype:` / `""` / `-` / `OR`）、时间过滤器（`tbs=qdr:h|d|w|m|y`）、DuckDuckGo Bangs（`!g` / `!gh` / `!so` / `!w` / `!yt`）与 WolframAlpha 知识查询。

---

### 3. plugingen 插件生成工具适配 L3 进程隔离轨

`plugingen` 此前只能产出 L1 内嵌轨 / L2 动态库轨插件。本版本补齐 **`--mode process`**，一键生成可直接被 `CordisHostManager` 加载的 L3 进程隔离轨插件工程。

#### 生成的 L3 工程

| 产物 | 内容 |
|------|------|
| `plugin.yaml` | `mode: process` + `command` 指向编译产物（相对宿主工作目录） |
| `cjpm.toml` | `output-type = "executable"`，依赖 `ystyle::cordis_plugin` / `ystyle::cordis_core` / `jsonvalue` |
| `main.cj` | `PluginRuntime.run` 显式入口，`import ystyle::cordis_plugin.{PluginRuntime, HostContext}` |
| `handlers.cj` | V4 CRUD RPC handler 框架（`jsonvalue` 枚举版 JsonValue，不混用 `stdx.encoding.json`） |
| `SKILL.md` / `pkg.cj` | 技能定义与包声明 |

同时接入 **§14.1 数据契约骨架生成**：`--contract` 与代码一起产出 `DATA_CONTRACT.yaml`，`--contract-only` 只产出契约。生成器确定性地从 `db_info` 提取表名/列名/类型/可空性/注释，并在骨架顶部显式标注三处**必须人工补齐**的字段（`role`、`idempotent_key`、`write_rule`）与不可省略的 `sample_rows`。

> `process` 轨不连数据库（无 `db_info` 可读），故 `--contract` 在该模式下自动忽略。

---

### 4. package_release 打包发布脚本适配 L3 进程隔离轨

L3 插件的可执行文件是**宿主之外的独立进程**，不进入主包的链接产物。原打包脚本只会收 DLL/CJO 与 `skills/*/plugin.yaml`，进程插件即使写好了也**进不了发布包**。本版本在 `src/scripts/package_release/main.cj` 补齐三段打包逻辑：

| 标记 | 内容 | 说明 |
|------|------|------|
| PS-T029 | L3 可执行文件入包 | 扫描 `skills/*/target/release/bin/skill_*.exe`，落到 `bin/skills/{name}/target/release/bin/` |
| PS-LRT-01 | 技能随包资源与 exe 同根 | `scripts/`（递归且保持子目录结构）、`COMPOSITION.yaml`、`DATA_CONTRACT.yaml`、`OPS.md`、`README.md`、`AGENTS.md`、`agents/` |
| PS-T029 | cordis-cj 依赖 DLL 收集 | `jsonvalue` / `jsonrpc` / `cordis_core` / `cordis_host` / `cordis_plugin` / `gjson` / `tomlcj` |
| PS-LRT-02 | 补写 VERSION 文件 | 此前只在收尾打印里写到它，从不落盘，解压后没有版本标识别 |

三处值得注意的实现约束：

1. **exe 的落点刻意保留 `target/release/bin/` 层级，不做扁平化。** `plugingen` 写入 `plugin.yaml` 的 `command` 是 `./skills/{name}/target/release/bin/skill_{name}.exe`，相对**宿主工作目录**解析（`CordisHostManager.resolvePluginCommand` 直接 `${cwd}/${command}`，无校验、无兜底）；发布态 cwd 为 `bin/`，故必须与开发态 `./skills/...` 逐层对齐，否则宿主启动时定位不到 exe。
2. **随包资源必须与 exe 同根，否则「能起来、跑不出结果」。** 进程插件的函数体虽已静态链接进 exe，但外层 Python 脚本（D 层降级后端）与 `COMPOSITION.yaml` / `DATA_CONTRACT.yaml` 是运行时按相对路径读取的：`LrtScriptRunner` 按 `<skillRoot>/scripts` 解析脚本目录，脚本内再以相对路径读写 `output/xxx`。只打 `plugin.yaml` + `SKILL.md` 会让已安装的进程插件所有 `cli_execute` / `llm` / `template` 降级后端全部失效。
3. **依赖目录名可能带组织名后缀。** cjpm 对 `organization="ystyle"` 的包产出目录是 `<name>@ystyle/` 而非 `<name>/`；漏了后缀会**静默跳过整批 DLL**（且只给 `[INFO]` 级提示），现象是进程插件起不来却看不到任何报错。脚本已对 `@ystyle` 做回退查找。

打包收尾摘要新增 `L3 process plugin executables: {N}`，并在目录结构说明中列出 `bin/skills/` 一行。

### 5. pluginuninstall 卸载脚本适配 L3 进程轨

原脚本虽支持 `--mode process`，但**只是打印一段不同的提示**，`--purge` 仍去删 `plugins/<name>/`——而进程插件的产物根本不在那里，实际表现为「卸载成功、exe 与随包资源全部残留」。本版本补齐：

| 项 | 改动 |
|------|------|
| 加载轨自动识别 | 未显式 `--mode` 时读 `skills/<name>/plugin.yaml` 的 `mode:`；显式指定则与文件声明交叉校验并告警 |
| process 轨清理路径 | 新增 `--skills-root`（默认 `./skills`）与 `--bin-root`（默认 `./bin`），覆盖 `skills/<name>/`、`bin/skills/<name>/`、`bin/plugins/<name>/` |
| 递归删除保护 | 上述三者都可能是一整棵含源码的目录树，默认只**列出待清理计划**，须追加 `--force` 才真正执行；sync/dylib 轨行为不变 |
| 收尾核对 | 删除后复核仍存在的路径并提示——最常见原因是 `.exe` 被仍在运行的插件进程占用（Windows 上尤为常见） |
| **清单误删修复** | 原条目匹配用 `contains` 做子串判定，卸载 `entity` 会命中 `- name: entity-ext` 行，把**另一个插件**的条目整段删除；改为 `trimAscii` 后的整行等值比较（兼容引号变体） |

> 该误删的实际影响与清单顺序相关：`entity-ext` 排在 `entity` 之前时，`contains` 会优先命中它，被删掉的是后者前的邻居条目本身。

---

## 新增功能

### OpenTiny 技术栈升级

前端 `apps/web-admin/web` 的 OpenTiny 依赖升级，对齐官方最新发行线：

| 包 | 版本 |
|------|------|
| `@opentiny/vue` | 3.31.0 |
| `@opentiny/vue-theme` | 3.31.0 |
| `@opentiny/vue-huicharts` / `vue-icon` / `vue-locale` | ~3.28.0 系列跟随 `vue` 主版本 |
| `@opentiny/tiny-robot` / `tiny-robot-kit` / `tiny-robot-svgs` | 0.5.1 |
| `@opentiny/next-remoter` / `next-sdk` | 0.4.9（本地二次开发副本 `src/lib/webmcp-sdk/packages/`） |
| `@mcp-b/webmcp-polyfill` / `webmcp-types` | ^2.0.0 |

### 对话界面与流式思维链体验优化

用户反馈最多的界面问题（"只显示第一条思维链"、"后续多轮全并入同条消息"、"工具气泡只有 `{"arguments": {}}`"、"第二轮直接显示上一轮内容"）本版本系统性修复，涉及**前后端共十余份文件**。

| 问题 | 根因 | 修复 |
|------|------|------|
| 思维链完全不显示 | 后端主 Agent 思维链是按 ReAct 文本协议以 `<thinking>` 内联在 `content` 中的，而 SSE 桥接仅在 `message.reason` 非空时推 reasoning 事件 | 前端新增 `InlineThinkingStreamSplitter`：对正文流做增量状态机解析（text/thinking/action 三态 + 跨 chunk 尾部扣留缓冲），`<thinking>` → reasoning 事件，`<action>` 抑制 |
| 思维链只吐半句 | `AsyncChatResponseIterator.next()` 是 `reason ?? content` **二选一**，带 reasoning 时同 chunk 的 content 被整段丢弃 | 后端新增独立 `reasoning` 累积 + `reasoningContent` 出口，标签流不再被吞 |
| 多轮思维链并入同条消息 | tiny-robot-kit 0.5.1 的 chunk 合并对字符串是**拼接**语义，且 `thinkingPlugin` 在首个文本 chunk 就收起面板 | 新增 `reactStepSplitter.ts`：按 `__reactStep` 标记在第 N≥2 轮追加**独立** assistant 消息并自行合并增量，状态隔离键为引擎 `currentTurn` |
| 拆分静默失效 | `reactStepSplitter` 原用的 `context.mutate/createMessage` 在 0.5.1 实测不存在，异常被吞 | 改用引擎实际提供的运行时上下文 API |
| 工具气泡只有空 `{}` | `tool-call-start` 只推 `id+name` 未推参数；`tool-call-end` 无 id 配对；Tool 渲染器读 `store.toolCallResults[id]` 但无人写入 | 三处分别补齐：参数注入、id 配对状态、结果区写入（后端同步补 `tool-call-start/end` SSE 事件） |
| 第二轮显示上一轮内容 | `/events` 首连回放了上一轮遗留环形缓冲（1063 条），生成器一见终态帧就提前 `return` | 新增 `fromTail=1`：首连跳过回放，只要连接之后的新事件；并在写 SSE 头**之前** `resetBuffer` |
| 中间轮次内容丢失 | `sse_event_bridge.cj` 各 handler 以 `hasConnection` 为前置条件，短暂断线期间事件被直接丢弃 | 去掉门闩，事件**永远**写入环形缓冲，断线可续传 |

### 提示词可视化配置（替代硬编码）

原 `prompts.cj` 里的工具结果压缩提示词硬编码在 `.cj` 源码里，改一句话要重编译，且通用措辞（`"Summarize the tool execution result."`）不要求跨回合保留"目标 / 当前进度 / 已完成与待办 / 失败项 / 下一步"，长程任务依赖的上下文被压缩丢失。

新增 `src/compactor/prompt_config.cj` 的 **PromptConfig**，采用"组合根注入目录"设计（`magic.compactor` 不下向依赖 `magic.config`）：

- **内置默认仍保留** —— 什么都不配也能跑，零回归；
- **多目录扫描** —— `main.cj` 按「技能内 `skills/<name>/prompts`（高优先级）→ 全局 `PROMPTS_DIR` / `./prompts`（兜底）」顺序注入，技能内配置**自动优先生效**；
- **profile 覆盖** —— `tool-summarize.user.<profile>.md`，profile 由调用方给出（AgentTask 传 agent 名 / 技能名），长程任务与普通对话各用一套；
- **失败静默回落** —— 目录不存在、文件缺失、读取异常一律回落到上一级默认，绝不因配置读不到而让任务跑不起来。

`skills/long-running-task/prompts/tool-summarize.user.long-running-task.md` 即为第一个技能内置覆盖实例。

> 实现坑已沉淀：`FILE_TOOL_SUMMARIZE_USER_BASE` 必须是**不含扩展名**的基础名，否则拼出 `tool-summarize.user.md.<profile>.md` 双扩展名，profile 提示词永远命中不了。

### image_understand：图片直传视觉工具

此前运行时虽在传输层支持 `Message.image`（`openai/chat.cj` 会组装 `image_url` content part），但**没有任何工具能把一张图片塞进 `Message.image`**，多模态模型能力形同虚设。

新增 `src/tool/vision_tools.cj` 的 `ImageUnderstandTool`（工具名 `image_understand`）：读图 → base64 → `Message.user(content, image!: Option<String>)` → 复用既有 `ModelManager.createChatModel` + `ChatRequest` 链路。内置 base64 体积保护，上限 **10 MB**（超出返回明确错误而非静默失败），支持本地路径与 URL 两种来源。

配套新增 `Config.modelCapabilities` / `Config.modelSupportsVision()`，让 agent 与技能能查询"模型是否原生多模态"，避免把图片强行降级 OCR。

---

## 改进

### 仓颉工具链基线（cjc 1.1.3）

本版本的开发、编译与验证全部在 **仓颉 1.1.3** 工具链上完成：

| 组件 | 版本 |
|------|------|
| cjc（Cangjie Compiler, cjnative） | 1.1.3 |
| cjpm（Cangjie Project Manager） | 1.1.3 |
| 主包声明 `cjc-version` | 1.1.3 |

> **工具链升级本身发生在 v0.0.27**（cjc 0.55.x → 1.1.3，stdx 1.0.5.1 → 1.1.3.1，详见
> [release-notes-0.0.27.md §2「cjc 1.1.3 工具链升级与依赖全量本地化」](./release-notes-0.0.27.md)）。
> v0.0.28 **沿用**同一工具链基线、未做切换；从 v0.0.26 及更早版本升级时，须先按 v0.0.27 的说明完成工具链迁移。

本版本完成了一次**字段声明与实际编译基线的对齐**：全仓 **187 份 `cjpm.toml`** 中，**185 份含 `[package]` 段者现已全部统一声明 `cjc-version = "1.1.3"`（100% 覆盖）**；余下 2 份为 `[workspace]` 聚合清单（`libs/cordis-cj/cjpm.toml`、`libs/fountain/fdemo/cjpm.toml`），结构上无 `[package]` 段、不存在该字段，不属遗漏。

此前共有 4 份声明停留在旧版本，本版本将其补齐：

| 包 | 原声明 | 现声明 | 说明 |
|------|------|------|------|
| `jsonrpc` | `1.0.0` | `1.1.3` | JSON-RPC 2.0 框架，**主包直接依赖** |
| `jsonvalue` | `1.0.0` | `1.1.3` | 通用动态 JSON 值类型，**主包直接依赖**，L3 cordis 链路 |
| `tomlcj` | `1.1.0` | `1.1.3` | TOML 解析（提取自 cjpm） |
| `CJson` | `0.55.3` | `1.1.3` | 遗留 JSON 库，当前**无任何包引用**，属冗余 |

值得记录的一点：这 4 个库的 stdx `path-option` **早已**指向 `cangjie-stdx-windows-x64-1.1.3.1`，说明它们实际处于「stdx 已跟进、`cjc-version` 字段未同步」的**半升级状态**，一直在 1.1.3 工具链下正常编译——本次修的是声明失真，不是编译故障。

改动范围仅 `cjc-version` 一个字段，各库自身的 `name` 与 `version`（如 `jsonrpc 0.7.0`、`jsonvalue 1.1.0`、`tomlcj 1.0.0`）**一律未动**，故不影响依赖解析；全仓 110 份 `cjpm.lock` 不含 `cjc-version` 字段，无需重新生成。

### 前后端网络连接健壮性

这条线上先后定位到**三个不同层级的独立根因**，全部修复：

| 层级 | 根因 | 修复 |
|------|------|------|
| 反向代理缓冲 | 三处流式 SSE 响应头缺 `X-Accel-Buffering: no`，代理缓冲 SSE 首部，浏览器始终收不到响应头 → `net::ERR_TIMED_OUT` | `WebMCPController.cj` 三处流式分支 + 非流式 fallback 全部补齐该响应头 |
| **TLS 并发写竞态**（主因） | 同一 TLS `conn` 被 3 条未同步路径并发写（SSE 事件 writer / `connected` 事件 / 15s 心跳协程）→ `Socket is already writing: concurrent write is not allowed` → TLS 会话损坏 → `net::ERR_SSL_PROTOCOL_ERROR` | 三处 SSE 方法各引入 per-connection `Mutex` + `writeSSE` 闭包，所有 `conn.write/flush` **只**在 `writeSSE` 内发生；平行 MCP SSE 传输 `sse_mcp_server.cj` 同款竞态一并加锁 |
| 前端无重连续传 | 单条 POST 真流式连接绑定整轮 agent 循环，断连即全丢 | 新增 `GET /api/v1/uctoo/webmcp/events`：服务端 `SSEConnectionManager` 重写为多订阅者 + 2048 条环形缓冲 + 单调 eventId + `replayEvents(fromId)`；前端 `eventStream.ts` 按 lastEventId 续传 |

另修复：

- **SSE 心跳协程泄漏** —— `/events` 心跳原为 `while(true)` 无上限，对端断开后内核发送缓冲让 `conn.write` 仍"成功"，协程与连接永久泄漏，累积耗尽可用连接 → 新增 `EVENTS_HEARTBEAT_MAX_TICKS = 120`（30 分钟）到点主动注销并关闭连接。
- **前端静默停滞看门狗** —— 连接建立后 >45s 未收到任何字节（含心跳）即主动 abort 走 lastEventId 重连；成功收事件时重置重连预算，长程任务可无限续传。
- **`/events` 404** —— 前端在已含前缀的 `agentRoot` 后又拼接完整相对路径，URL 前缀翻倍（属前端 URL 构造 bug，非路由未注册）。
- **`tool_calls` 数组空洞** —— SSE 重连回放时 `toolCall.index` 不连续导致渲染读 `.id` 抛异常并逃逸 try/catch 死循环，已加占位补齐。

### 数据库并发写

日志中占比最高的报错（`Socket is already reading: concurrent read is not allowed`、`parameter index N out of range [0, N)`、`no value specified for parameter 1`）本质是同一个根因：

f_orm 的 `SqlExecutor` 虽按 `ThreadLocal` 持有连接，但底层 `NamedDatasource.connect()` 发下来的**连接被多条并发路径共用**——`AsyncLogWriter` 后台线程、`SchedulerEngine` tick、`BillingEventHandler` / `AgentPersistenceEventHandler`、`AgentExecutionExecutor`。语句与绑定参数在线程间错位。此前只在 `SchedulerEngine` 内部加锁，挡不住别的线程，错误照旧。

**修复**：新增 `src/app/core/database/DbSerialLock.cj`（进程级 `ReentrantMutex` + `withLock<T>`），将 5 条路径全部切到**同一把锁**（共 28 处调用点）。选 `ReentrantMutex` 而非 `Mutex` 是因为事务里再查询会嵌套进入。

### 网络抓取链路

| 问题 | 根因 | 修复 |
|------|------|------|
| `incomplete chunk data` | `HttpResponseParser.parse()` 只被"刚读完响应头"的调用方使用，缓冲区里只有首块开头几个字节，却调 `ChunkedDecoder.decode()` 一次性解码 | 解码失败不再硬抛，回传**原始分块字节**，交给外层 `readStreaming(reader, prefetched:)` 增量续读；完整报文仍一次解出，老调用方行为不变 |
| 百度返回 HTTP 200 但正文仅 21 字节 | User-Agent 自报家门 `compatible; AgentSkillsRuntime/1.0`，被识别为 bot 静默拦截 | 改为桌面浏览器 UA + `Accept` / `Accept-Language` / `Cache-Control` |
| 结果页几十万字符 HTML 灌爆上下文 | 原样回灌模型 | `web_fetch` 新增 `mode`（默认 `auto`）：识别为 HTML 即提炼正文（去 script/style/注释/标签 → 实体反转义 → 折叠空白），60K 截断；`mode=raw` 可拿原报文 |
| 失败不可诊断，agent 只能盲目重试 | 无法区分"被拦"还是"网络不通" | 结构化返回 `status=ok/blocked/empty/no_response/error` + `reason` + `suggestion`，按 `ENOTFOUND` / 超时 / TLS 握手 / chunk 分类给下一步动作；命中验证页特征词时明确告知"换引擎，不要同参数重试" |
| TLS 握手失败无退路 | 单一 CA 路径 | `web_fetch` 先 `verify=false`，失败再用系统 CA（`SSL_CERT_FILE`）重试一次 |

### 模型名规范化（DeepSeek 官方 ID 变更）

DeepSeek 官方已将正式模型 ID 简化为 **`deepseek-flash`**（对应 DeepSeek-V4.1-Flash，支持图像理解）与 **`deepseek-v4-pro`**（不支持图像理解）；`deepseek-v4-flash`、`deepseek-v4-flash-vision-exp` 虽仍可调用但对应模型已下线，而 `deepseek-v4-1-flash` **官方从未提供过**，属配置里自造的写法。

**修复**：`model_manager.cj` 新增 `normalizeModelName()`，在 `parseModel()` 的两个分支（裸名、`provider:name`）都做收敛，老配置不改库也能继续用；`config.cj` 的 vision 推断口径同步更新为「`deepseek` 且含 `flash`」——新名里既无 `v4-1` 也无 `vl`/`vision`，靠老特征词会漏判，但**不能只判 `deepseek`**，因为 `deepseek-v4-pro` 无视觉能力。全仓 11 处旧名硬编码（含 `AGENTS.md`、`long-running-task/SKILL.md`、3 个技能的 Python 默认值）一并清理。

> 排查口诀已沉淀：报 `xxx is invalid` 时先 grep **`AGENTS.md` 的 `model:` 字段**（它会灌进 `Agents` 表的 `model` 列），不要急着改 `.env`。

### 其他

- **工具缺参数不再抛解析错** —— 模型有时只吐 `{"name":"file_write"}` 不带参数，原逻辑直接抛解析异常，agent 收到笼统的"解析失败"要白烧一轮 ReAct。改为按空参数放行，让工具自己回 `Parameter 'path' is required`。
- **`cli_execute` 的 `cwd` 曾为死代码** —— `cli_tool.cj` 算了 `workingDir` 却从不透传，进程 CWD 恒为 runtime 根目录导致相对路径脚本必失败；已给 `newProcess` 加 `workingDirectory!: ?Path` 并透传。
- **多步任务提前终止** —— `tag_stream_parser.cj` 曾把未知标签输出静默判为最终 Answer，导致异步 ReAct 路径一步即终止；已恢复 `throw ParserException` 并在 `asyncRunOnce` 校验 `hasAnswerOpenTag`。

---

## 数据库变更

### 长程任务增量 SQL

新增 `sql/incremental/20260911_long_running_task.sql`：

| 表 | 说明 |
|------|------|
| `long_running_task_artifact` | 长程任务产物表：每步/每回合产出的文件或对象，含 `artifact_path`、`artifact_type`、`verification_status`（pending/verifying/passed/failed）与结构化 `verification_result`（`{checks:[{name,passed,detail}], summary, checked_at}`），带行级权限字段 `creator` |
| `long_running_task_evolution` | 自进化记录表：按 `agent_id` 聚合，`round` 递增，记录 `root_cause`、`optimization_plan`、`anti_regression`（防回退约束文本）、`skill_md_updates`（SKILL.md 变更 JSON） |

> 长程任务本体复用既有 `agent_tasks`（任务树经 `parent_task_id`）与 `agent_contexts`（检查点），不新增表。

---

## 迁移指南

### 从 v0.0.27 升级

1. **升级 Runtime 服务**
   ```bash
   npm install @opencangjie/skills@latest
   npx skills install-runtime --runtime-version 0.0.28
   npx skills restart
   ```

2. **执行长程任务增量 SQL**
   ```bash
   psql -U postgres -d uctoo -f sql/incremental/20260911_long_running_task.sql
   ```

3. **编译并部署 long-running-task 插件**
   ```bash
   cd skills/long-running-task && cjpm build
   # 确认 config/plugins.yaml 中 command 路径相对于**宿主工作目录**
   # 正确形态：./skills/long-running-task/target/release/bin/skill_long_running_task.exe
   ```

4. **前端依赖重装**
   ```bash
   cd apps/web-admin/web && pnpm install
   ```

5. **模型名检查**
   ```bash
   # AGENTS.md 与 .env 应使用 DeepSeek 官方当前 ID
   # ✅ model: deepseek-flash        ❌ deepseek-v4-1-flash / deepseek-v4-flash
   # 若数据库 agents 表仍存旧名无需改库 —— normalizeModelName() 会在加载时自动收敛
   ```

> 对外 REST API 路径、WebSocket 消息协议、既有 SSE 事件格式均保持不变，业务侧无需修改。仅新增 `/api/v1/uctoo/long_running_task/*` 与 `/api/v1/uctoo/webmcp/events` 两组端点。

---

## 下载

### Windows x64
- 文件: `agentskills-runtime-win-x64.tar.gz`
- 大小: ~430MB（解压 ~1.4GB）
- 包含: 所有依赖 DLL，内嵌 http_lib 依赖链 + cordis-cj 依赖链

### Linux x64
- 文件: `agentskills-runtime-linux-x64.tar.gz`

### macOS
- x64: `agentskills-runtime-darwin-x64.tar.gz`
- ARM64: `agentskills-runtime-darwin-arm64.tar.gz`

---

## 安装使用

### 使用 JavaScript SDK

```bash
npm install @opencangjie/skills@latest
npx skills install-runtime --runtime-version 0.0.28
npx skills start
```

### 构建说明

```bash
# 主包构建（自动编译 cjpm.toml 中全部 path 依赖，含 cordis_core/cordis_host）
cjpm build

# cordis-cj 独立产物（产出被运行时动态加载的 cordis_plugin）
cd libs/cordis-cj && cjpm build

# long-running-task 插件（独立包，不在 runtime path 依赖链中，须单独构建）
cd skills/long-running-task && cjpm build

# 前端
cd apps/web-admin/web && pnpm install && pnpm dev
```

> 注意：`skills/long-running-task` 是独立包，**不在** runtime 的 `[dependencies]` 中，`cjpm build` 不会自动编译它。

### 生成 L3 进程轨插件

```bash
cjpm run --skip-build --name magic.plugin.tools.plugingen -- \
  --name {table} --db {db} --table {table} --mode process --contract

cd skills/{table} && cjpm build
# 在 config/plugins.yaml 追加 mode:process + command 条目
```

卸载同一个进程插件（自动识别轨→先列计划→确认后加 `--force`）：

```bash
cjpm run --skip-build --name magic.plugin.tools.pluginuninstall -- \
  --name {table} --purge

# 确认待清理目录无误后
cjpm run --skip-build --name magic.plugin.tools.pluginuninstall -- \
  --name {table} --purge --force
```

> 若 `.exe` 删除失败，通常是插件进程仍在运行占用文件；先经 `plugin_deactivate` 或重启宿主再清理。

---

## 相关文档

| 文档 | 说明 |
|------|------|
| [长程任务需求规格](./.codeartsdoer/specs/long-running-task/spec.md) | 组件定位、领域术语、需求条目（含 RU/AC 编号） |
| [长程任务设计文档](./.codeartsdoer/specs/long-running-task/design.md) | 架构、数据模型、接口契约、技术选型 |
| [长程任务任务清单](./.codeartsdoer/specs/long-running-task/tasks.md) | 章节化开发任务与完成状态（177/237） |
| [长程任务接口文档](./skills/long-running-task/README.md) | 用户 API / 插件 RPC / 事件 / 决策点真实接口面 |
| [长程任务运维手册](./skills/long-running-task/OPS.md) | 部署、监控、故障处置 |
| [流式思维链规格](./.codeartsdoer/specs/stream_thinking_chain/spec.md) | 前端思维链流式渲染设计 |
| [系统环境能力采集](./.codeartsdoer/specs/system-env-capability/spec.md) | 启动时采集 OS/bash/浏览器/模型/环境变量能力清单 |
| [多引擎检索技能](./skills/multi-search-engine/SKILL.md) | 16 引擎检索 SOP |
| [长程任务增量 SQL](./sql/incremental/20260911_long_running_task.sql) | 产物表与自进化记录表 DDL |

---

## 已知问题

- `long-running-task` 插件尚有 60 个规格任务未完成（完成度 74.7%），集中在高阶自进化策略与跨 Agent 协作部分
- `plugingen --mode process` 生成的 V4 CRUD handler 为框架桩，需按具体业务逻辑实现
- `multi-search-engine` 的 SKILL.md frontmatter 存在引擎计数不一致（frontmatter 描述为 17 个 / 8 国内 + 9 国际，正文列表为 16 个 / 7 国内 + 9 国际），实际可用引擎以正文的 7 + 9 为准
- `skills/long-running-task/output/parsed/goal.json` 等历史运行产物仍含旧模型名，属上次运行生成，会随下次运行覆盖
- cordis-cj 的 UDS 传输在 Windows 上不可用，L3 轨固定使用 stdio
- L3 进程轨插件的 `stdx` DLL 路径注入依赖 `CANGJIE_STDX_PATH` 环境变量，某些 cjpm 配置下可能需手动设置
- `pluginuninstall` 是**配置态** CLI：它不负责终止进程实例，`.exe` 被运行中进程占用时删除会失败，须先经 `plugin_deactivate` 或重启宿主
- L3 轨尚无与 `pluginuninstall` 配对的 `plugininstall` 命令，第三方进程插件目前靠手动放置 + 编辑 `plugins.yaml` 完成安装
- `libs/CJson` 已随依赖声明统一升级到 `cjc-version = "1.1.3"`，但当前**全仓无任何包引用它**，属冗余依赖，可在后续版本评估移除
- `plugingen` 的 `process` 轨不写 `plugins.yaml`，登记条目需手工追加（参见「安装使用」一节）

---

## 贡献者

感谢以下贡献者对本版本的贡献：
- UCToo Team
- OpenCangjie 开源社区
- OpenTiny 开源社区（TinyRobot / next-remoter / next-sdk）
- zcwl / multi-search-engine 技能原作者（MIT 许可）
- cordis-cj 开源项目（ystyle）

---

## 支持

如有问题，请通过以下方式获取帮助：
- GitHub Issues: https://atomgit.com/uctoo/agentskills-runtime/issues
- 技术支持: support@uctoo.com
- 文档: https://atomgit.com/uctoo/agentskills-runtime/tree/main/docs

---

## 下一版本计划

v0.0.29 计划功能：
- long-running-task 插件剩余 60 个规格任务收口（自进化高阶策略、跨 Agent 协作）
- Agent 直接操作 Web 应用端到端打通（`.codeartsdoer/specs/webmcp-agent-web-operation`，规格已成型，链路断点已定位）
- 插件市场 Web UI（技能市场可视化展示与一键安装）
- L3 进程轨插件热更新（不重启宿主替换插件版本）
- 性能监控面板（插件加载耗时、路由响应时间、进程资源占用）
- OpenTiny 依赖跟随官方 3.32.x 发行线

---

**完整变更日志**: 查看 [CHANGELOG.md](../CHANGELOG.md)
