# Cordis 插件机制 vs npm 插件机制：全面对比分析

> 分析对象：DeepSeek Harness（dsh）采用的 Cordis 插件机制 vs Node.js 生态原生的 npm 包/插件机制
> 核心问题：dsh 若直接采用 npm 插件机制，能否实现与当前开源项目等效的能力？新建一套 Cordis 插件机制的作用和意义是什么？
> 分析日期：2026-08-17

---

## 摘要（先说结论）

**npm 与 Cordis 不在同一个层面，二者不是"二选一"的替代关系，而是"地基与楼宇"的分层关系。**

- **npm 是包分发与依赖管理协议**（部署期机制）：解决"插件代码怎么装进来、版本怎么对齐、依赖树怎么解析"。它服务于一切 Node.js 项目，不是为运行时插件组装设计的。
- **Cordis 是运行时插件组装框架**（运行期机制）：解决"插件代码怎么活起来、怎么找到彼此、怎么协作、怎么在卸载时干净地退出"。它跑在 npm/pnpm 之上，**dsh 仓库里 cordis 本身就是通过 pnpm workspace 解析的**。

**直接回答核心问题：**

1. **dsh 若只用 npm 插件机制，无法实现等效能力。** npm 能覆盖的只有"分发、版本、入口约定"约两成能力；服务定位、依赖注入、生命周期状态机、可逆卸载、事件分发语义、热更新、配置插值、以及 dsh 最核心的"Agent 自修改自身运行时"（self-referential toolset），全部需要运行时层机制——这些 npm 一概不提供。
2. **"用 npm 生态的包自己实现"就等于再造一个 Cordis。** dsh 的 vendor/README.md 记录了 18 条对 Cordis 上游的本地修改，条条都是对 fiber 生命周期、effect 回收、waterfall 分发这类内部语义的精确控制——这证明 dsh 的 Agent 循环正确性保证已经深度绑定 Cordis 的运行时语义，而非 npm 能给出的任何东西。
3. **Cordis 机制的意义，恰恰在于它超越了 npm 的"静态依赖"世界观，提供了"动态可逆组合"的运行时底座**——这是"一切皆插件"能否支撑"软件系统自进化"的关键。Cordis 背后有一篇论文（《A Programming Paradigm for Spatiotemporal Composability》），用保持性、恢复精确性、合流性等定理保证了"插件怎么装都能干净卸载、怎么交错加载都收敛到同一终态"，这个理论保证是 npm 永远给不了的。

---

## 一、背景：两个机制的定位分野

### 1.1 npm 是什么：包分发与依赖管理协议

npm 诞生于 2010 年，是 Node.js 的官方包管理器。它的核心职责是：

| 能力 | 说明 |
|---|---|
| 包分发 | 将代码打包发布到中心仓（registry），`npm install` 拉取安装 |
| 版本管理 | semver 语义化版本 + 依赖树解析（`dependencies`/`devDependencies`/`peerDependencies`） |
| 入口约定 | `main`/`exports`/`bin` 字段声明包的入口与可执行文件 |
| 生命周期脚本 | `preinstall`/`postinstall` 等安装钩子 |
| 本地开发 | `workspaces`/`npm link` 支持 monorepo 与本地联调 |

npm 对"插件"的唯一专门支持是 **peerDependencies**（对等依赖）——它解决的是"插件需要宿主存在且版本兼容"的声明问题。npm 官方博客对它的定义非常明确：*"A plugin package is meant to be used with another 'host' package"*（插件包意味着与另一个"宿主"包一起使用）。但请注意：**peerDependencies 只是安装期的版本契约，它完全不涉及插件在运行时如何被宿主加载、激活、协调、卸载。**

### 1.2 Cordis 是什么：运行时插件组装框架

Cordis 的作者是 Shigma（Koishi 聊天机器人框架的作者），上游在 cordiverse/cordis，最初是 Koishi v4 的底层，Koishi 生态累计 4000+ 社区插件。Cordis 的自我定位是：

> **A Meta-Framework of Spatiotemporal Composability**（时空可组合性的元框架）

"元框架"的意思是：**它不提供任何业务能力**——没有 HTTP、没有数据库、没有调度器，只有约 2700 行 TypeScript 核心代码（dsh vendor 的 `cordis/src` 实测：fiber.ts 754 行、reflect.ts 418 行、events.ts 352 行、registry.ts 337 行、logger.ts 270 行、context.ts 146 行、service.ts 115 行、utils.ts 287 行）。它只提供组装业务能力的范式：

- **Service**：命名的 ctx 键，任何插件可以提供（provide）/消费（inject）
- **Fiber**：插件的生命周期状态机（PENDING → LOADING → ACTIVE → DISPOSED）
- **Effect**：注册即 disposer 的副作用管理（可逆注册）
- **inject**：声明式依赖等待（服务就绪才激活插件）
- **Events**：类型化的 emit/waterfall/serial/parallel 四种事件分发

### 1.3 一个关键事实：Cordis 跑在 npm/pnpm 之上，不是 npm 的替代品

这是最容易混淆的一点。**dsh 并没有"抛弃 npm 用 cordis"**——恰恰相反：

- dsh 是 pnpm monorepo（`pnpm-workspace.yaml` + `pnpm-lock.yaml`），全部 50+ 包通过 pnpm workspace 解析；
- dsh 把 Cordis 的 9 个包（cordis、loader、include、group、timer、hmr、logger-console、cosmokit、schemastery）**源码 vendor 进 `vendor/` 目录**，重命名为 `@deepseek-ai` scope，再通过 `pnpm-workspace.yaml#linkWorkspacePackages: true` 让 semver 范围解析到这些本地 workspace；
- 第三方依赖（js-yaml、chokidar、@standard-schema/spec 等）仍然走 npm registry。

所以准确的说法是：**dsh = pnpm（npm 协议）管理包分发 + Cordis 管理运行时组装。两者各司其职，npm 是 Cordis 能跑起来的地基。**

---

## 二、npm 插件机制的能力盘点

### 2.1 npm 为插件生态提供了什么（部署期）

1. **分发与安装**：插件打包发布到 registry，用户 `npm install <plugin>` 即得。
2. **版本契约（peerDependencies）**：插件声明"我要求宿主版本 ≥ x"，安装器校验宿主存在且版本兼容，冲突时报 `ERESOLVE`。
3. **入口与可执行约定（exports/main/bin）**：`exports` 字段还能做条件导出（import/require 双入口）。
4. **生命周期脚本**：安装前后执行钩子（但这是"安装期"钩子，不是"运行期"钩子）。
5. **monorepo/本地开发（workspaces、link）**：多包仓库内互相引用。

### 2.2 npm 不提供什么（运行期组装缺失）

npm 世界观的核心是 **"静态依赖树"**：安装时解析一次，运行时各包通过 `require()` 互相引用。它缺少一个运行时插件框架需要的全部能力：

| 缺失能力 | 说明 | 对 dsh 意味着什么 |
|---|---|---|
| 服务定位与依赖注入 | 插件通过 `ctx.tools`/`ctx.llm` 找服务，而非 `import` 具体实现 | 没有它，"替换一个 provider 改变整个产品"（Seam 概念）无法实现 |
| 生命周期状态机 | Fiber 管理 PENDING→LOADING→ACTIVE→DISPOSED | 没有它，加载/卸载顺序无法保证 |
| 可逆卸载（effect/disposer） | 每次注册都返回逆操作，卸载时自动清理 | 没有它，Agent 会话会累积孤儿监听器/工具/定时器 |
| 响应式依赖协调 | inject 声明依赖，服务被替换时只有相关插件重启 | 没有它，热替换 provider 会连锁错误 |
| 事件分发语义 | emit/waterfall/parallel/serial 四种模式 | waterfall 是 dsh 中间件/策略拦截的核心 |
| 配置系统 | schemastery schema 定义 + 校验 + `!!js` 表达式插值 | 没有它，声明式配置（cordis.yml）无法实现 |
| 热更新（HMR） | 配置文件变更自动重载 | 没有它，改配置必须重启进程 |
| 运行时反射 | 枚举当前服务/插件/事件 | 没有它，"Agent 检视自身运行时"无从谈起 |

**一句话：npm 是"安装期"的，Cordis 是"运行期"的。npm 管"插件怎么进来"，Cordis 管"插件怎么活、怎么协作、怎么干净地死"。**

---

## 三、Cordis 插件机制的能力盘点

### 3.1 五个核心概念（dsh docs/cordis-primer.md 原话）

> - **A plugin is a object that implements Service.** 插件是一个实现 Service 的对象，可以是带可选 `inject`/`apply(ctx)` 字段的函数，也可以是生命周期由 Cordis 挂载到当前上下文的 Service 子类。
> - **A context is a repository of services.** 上下文是服务的仓库。服务在上下文中占据稳定的 `ctx.<key>`（如 `ctx.tools`、`ctx.llm`、`ctx.sessions`），其他插件通过 key 而非 import 具体实现来寻找服务。
> - **Declare service dependency via `inject`.** 插件通过 `inject` 声明所需服务，等到服务存在才激活——加载顺序由服务依赖表达，而非手工编排启动序列。
> - **Typed Events for communication.** 服务通过 TypeScript 声明合并声明事件名，再以 `emit`（观察）、`waterfall`（包装/短路）、`parallel`（并行扇出）、`serial`（顺序处理）四种模式分发。
> - **Registrations are reversible effects.** 提示词片段、工具 schema、适配器、provider、监听器都通过 `ctx.effect()`/`ctx.on()` 安装，重载和卸载时按预测顺序展开。

### 3.2 元理论：时空可组合性（论文核心）

Cordis 的设计被形式化为一篇论文：《A Programming Paradigm for Spatiotemporal Composability》。两个正交维度：

- **时间可组合性（Temporal）**：组件被移除时，它对共享环境的**所有改动被完全撤销**。每个注册都是可逆的 effect——卸载即"世界回到它来之前的样子"（恢复精确性）。
- **空间可组合性（Spatial）**：组件之间的依赖是声明式、响应式的。上下文每次变化，运行时把变化对每个组件分类为"激活/停用/中性"——只有依赖真正改变的组件被重新激活。

元理论给出五条性质（juejin 前端视角解读）：

| 定理 | 人话 |
|---|---|
| 保持性 | 无论走哪条规则，系统结构不会被搞坏 |
| 恢复精确性 | 组件拆掉后，世界回到它来之前的样子 |
| 排序 | 依赖解析一旦确定就不变；提供者一定比消费者活得久 |
| 进展 | 无死锁，且一定会到达静止态（有步数上界） |
| 合流性 | 加载顺序不影响终态——同样的编排意图怎么交错执行，最后收敛到同一状态 |

**合流性是声明式加载器的理论靠山**：因为终态只取决于最终配置，加载器才敢做增量协调而非推倒重建，编排者才不需要手工安排加载顺序。

### 3.3 核心实现：五个服务挂在一个 Context 上

Cordis 核心层（~2700 行）由五个服务组成，全部挂在同一个 Context 对象上（iceyao 源码解读）：

- **Fiber**：生命周期状态机 + effect 副作用回收，一个插件实例对应一个 Fiber；
- **Registry**：插件注册表，负责插件去重与 `inject` 依赖声明；
- **Reflect**：服务注册表，同时也是 Context 这个 Proxy 的陷阱处理器；
- **Events**：事件系统，提供四种分派模式；
- **Logger**：日志缓冲与 exporter 机制。

### 3.4 dsh 对 Cordis 的深度定制：vendor + 18 条本地修改

这是理解 Cordis 价值的**最硬核证据**。dsh 没有走"npm 装个 cordis 依赖"的常规路线，而是：

1. **把 9 个 Cordis 系包源码 vendor 进仓库**，重命名 `@deepseek-ai` scope；
2. **维护了一份 18 条的本地修改日志**，每条都登记了理由与测试覆盖。

vendor/README.md 的原话说明了动机：

> *"Copy the needed Cordis packages into `vendor/` as source... so that the harness fully owns its framework layer (auditable, patchable, pinned) — an RC upstream can't break us, and we can fix framework bugs in-tree."*
> （把需要的 Cordis 包作为源码拷入 vendor/，让 harness 完全拥有自己的框架层——可审计、可打补丁、可锁定——上游 RC 版本无法破坏我们，我们可以在仓库内修框架 bug。）

18 条修改的典型条目（全部围绕运行时语义）：

- **fiber.ts 生命周期加固**：修复三处重入式卸载漏洞（effect 在卸载过程中注册会逃逸、异步清理不可见、父子 fiber 注册时序）；
- **事务性 Loader/Include 配置协调**：配置加载失败时回滚到上一状态；
- **Lazy Loader 配置解析**：移植上游 PR #41，保留原始 fiber 配置、在声明的注入激活后才解析；
- **HMR 精确配置监听**：Windows 路径短名防冲突；
- **include 补丁语义导出**：`dsh --dump-config` 与挂载共用同一套补丁算法，防止配置工具与运行时漂移。

**这说明什么？** dsh 的 Agent 循环正确性保证（事件瀑布语义、可逆卸载、会话日志不变量）**已经深度绑定在 Cordis 的运行时内部机制上**。这不是"用 npm 装个库"能获得的东西——因为 npm 只能给你"装好的代码"，给不了"这些代码在你运行时里如何被精确调度"。

---

## 四、核心问题：dsh 若采用 npm 插件机制，能否实现等效能力？

### 4.1 能力映射表

| 能力 | npm（纯包管理） | Cordis（运行时框架） | 等效性 |
|---|---|---|---|
| 插件代码分发 | ✅ registry + semver | ❌ 不管（依赖 pnpm/npm 分发） | npm 覆盖 |
| 宿主版本契约 | ✅ peerDependencies | ❌ 不管 | npm 覆盖 |
| 入口约定 | ✅ exports/main/bin | ❌ 不管 | npm 覆盖 |
| 服务定位（ctx.tools） | ❌ 只能 import 硬编码 | ✅ Context Proxy + Reflect | **Cordis 独有** |
| 声明式依赖注入（inject） | ❌ | ✅ 响应式等待服务就绪 | **Cordis 独有** |
| 生命周期状态机（Fiber） | ❌ 只有安装钩子 | ✅ PENDING→ACTIVE→DISPOSED | **Cordis 独有** |
| 可逆卸载（effect/disposer） | ❌ | ✅ 注册即逆操作 | **Cordis 独有** |
| 事件分发（waterfall 等 4 模式） | ❌ | ✅ | **Cordis 独有** |
| 配置系统（schemastery + !!js） | ❌ | ✅ | **Cordis 独有** |
| 热更新（HMR） | ❌ 装完即固定 | ✅ 配置变更自动重载 | **Cordis 独有** |
| 运行时反射（检视自身） | ❌ | ✅ cordis_inspect | **Cordis 独有** |
| 动态挂载/卸载插件（自修改） | ❌ 需重启进程 | ✅ cordis_mount/stop | **Cordis 独有** |
| 理论保证（合流性/恢复精确性） | ❌ | ✅ 论文定理 | **Cordis 独有** |

**npm 覆盖约 2 成（纯分发层），Cordis 覆盖约 8 成（运行组装层）。**

### 4.2 反驳"用 npm 生态的库也能实现"

有人会说：Node 生态有 InversifyJS、tsyringe、NestJS 等 DI 容器，dsh 为什么不用它们？这正是 dsh 团队在 agent note 里回答过的问题（`why not InversifyJS/tsyringe/NestJS`）：

> **"没有自动 dispose：你 bind 了一个 service，谁来负责 unbind + cleanup？"**

传统 DI 容器解决的是"依赖注入"一个点，但 Cordis 把"依赖注入 + 生命周期 + 副作用回收 + 事件分发"合成了一个有理论保证的整体。即使用 InversifyJS 之类的库拼装，**"可逆卸载 + 合流性"这些性质依然要自己从头实现并自己证明**——那实际上就是"再造一个 Cordis"，而且没有论文背书。

再退一步，就算 dsh 团队自己写一套运行时机制（不叫 cordis），**它依然不是"npm 插件机制"**——npm 从头到尾没有参与运行时组装。所以问题的答案清晰：**npm 插件机制不是"另一种实现方案"，而是"分发层"；等效能力必须在运行时层另行实现，Cordis 就是那个实现。**

### 4.3 四个具体论证：为什么纯 npm 达不到 dsh 的等效能力

**论证 1：dsh 的 Agent 循环正确性绑定 Cordis 内部语义。**
vendor 修改日志第 6 条（fiber.ts 生命周期加固）修复的是"重入式卸载"这类极端时序问题，第 9、12、14、15 条（HMR 精确监听、Include 子树串行化、Windows 短暂句柄占用重试、Lazy 配置解析）都是真实生产环境踩出来的坑。这些语义不可能从 npm 获得，甚至从 Cordis 的 npm 发布版都拿不到——所以 dsh 选择 vendor 源码自己掌控。

**论证 2：自引用工具集（self-referential toolset）是"一切皆插件"的灵魂，纯 npm 无法实现。**
dsh 的 `tool-cordis` 扩展包实现了五个模型可见工具：`cordis_inspect`（检视运行时）、`cordis_define`（定义动态包）、`cordis_run`（运行）、`cordis_stop`（停止）、`cordis_undefine`（撤销）。它的定位原话是：

> *"Everything in this harness is a cordis plugin, but the agent running inside that plugin runtime cannot see or touch it... Handing the model that power is worth exploring — a self-referential agent that inspects and modifies its own runtime."*
> （这个 harness 里的一切都是 cordis 插件，但运行在其中的 Agent 却看不到也摸不到它们……把这种权力交给模型值得探索——一个能检视并修改自身运行时的自引用 Agent。）

这需要：运行时反射（inspect 枚举服务/插件/事件）、动态求值（vm 沙箱中挂载插件）、可逆卸载（stop 后所有注册回滚）。**这三样全部依赖 Cordis 的运行时机制**。npm 能做的极限是"安装一个新包"，但安装后进程不会自动加载它，更不可能让 Agent 在会话中试运行再干净地撤回。

**论证 3：四种运行模式（标准/PTC/极简/创造）建立在配置层组合之上。**
官方发布文章说：dsh 提供四种模式，每种模式默认加载不同插件集合。其中"创造模式：可以检查当前运行时、在内存中试验 Cordis 插件，并据此组合和创作新的模式"——**这本质上是让用户（和 Agent）在运行时动态组合插件集合**，靠的是 Cordis Loader 的声明式配置 + 增量协调（合流性保证"怎么交错加载都收敛到同一终态"）。npm 的安装模型是静态的，装完还得重启才能生效，无法支撑这种模式。

**论证 4：dsh 的终极目标是"软件系统可自主进化"，这正是 Cordis 论文的靶子。**
社区分析（chooseai）直接点明：

> *"论文真正的靶子是『自进化 agent harness』：未来一个 agent 框架可能一边持续服务请求，一边由 AI 生成、替换自己的组件，每一次替换都是一次动态组合，卸载不干净就会让缓存、连接、监听器越积越多。"*

**"AI 生成、替换自己的组件"**——这正是 dsh（以及用户团队的 agentskills-runtime）的共同终极目标。Cordis 的时间可组合性保证"替换 = 干净卸载 + 新组件装上，世界回到正确状态"，空间可组合性保证"被替换的 provider 的消费者自动重新激活"。这是自进化安全性的**理论底线**，npm 作为分发工具完全不涉及这一层。

---

## 五、Cordis 机制的作用与意义

综合以上分析，Cordis 之于 dsh 的作用可以归纳为五点：

### 5.1 为"一切皆插件"提供理论保证，而非工程巧合

"一切皆插件"很容易做成"所有东西都是 npm 包"——但那只是"一切皆包"，装进去后插件之间怎么协作、卸载会不会留垃圾，全无保证。Cordis 用论文定理（保持性/恢复精确性/排序/进展/合流性）把"可逆组合"从代码纪律升级为**运行时保证**。这让 dsh 敢把模型、工具、技能、会话、沙箱、存储、循环、调度、UI 全部插件化——**因为任何插件都可以在运行时被安全替换而不破坏系统**。

### 5.2 支撑"Agent 修改自身运行时"（自引用），这是自进化的起点

dsh 的 extensions 目录定位是 *"the agent modifies its own runtime"*（Agent 修改自身运行时）。tool-cordis 让模型能：检视当前进程里的全部服务/插件/事件 → 在内存中定义并试运行一个动态插件 → 用完后干净撤回。**这意味着 dsh 的"自进化"已经不止于"Agent 写代码提交到仓库"，而是"Agent 在当前进程里直接试错、验证、撤回"**——进化的试错成本从"重启进程"降到"一次工具调用"。这只能建立在 Cordis 的可逆卸载与运行时反射之上。

### 5.3 深度定制（vendor + 18 条修改）说明：框架层必须"自有"

dsh 不依赖 npm 上的 cordis 发布版，而是 vendor 源码 + 18 条本地修改。原因有三：
1. **RC 稳定性**：上游当时是 4.0.0-rc.x，Agent 循环的正确性不能押在未稳定版本上；
2. **内部语义依赖**：fiber lifecycle、effect disposal、waterfall dispatch 的精确行为是 dsh 正确性保证的一部分；
3. **可审计可修补**：框架 bug 可以在仓库内直接修，不必等上游。

**这对所有把"自进化"作为目标的项目都是重要启示：框架层是自进化系统的"底层操作系统"，必须完全可控。**

### 5.4 生态验证：Koishi 4000+ 插件的实战证明

Cordis 不是实验室玩具——它是 Koishi（跨平台聊天机器人框架）的底座，发展四年累计 4000+ 社区插件、官方市场收录 3000+。**一个插件框架的成熟度，最终要由生态规模验证**。Cordis 从聊天机器人场景沉淀出的"可逆插件"范式，被 dsh 迁移到 Agent Harness 场景，说明这套机制具有场景通用性。

### 5.5 "元框架"定位：dsh 的领域词汇由自己定义

Cordis 只提供组装范式（Service/Fiber/Effect/inject/Events），不提供任何业务能力。因此 dsh 的 `ctx.tools`、`ctx.llm`、`ctx.sessions`、`ctx.sandbox` 等服务全部由 dsh 自己定义——**框架层与业务层职责清晰分离**。这也是为什么 dsh 能 50+ 包快速演进而不互相踩踏。

---

## 六、对 agentskills-runtime 的启示（插件 + Skills 融合）

结合用户团队正在推进的"插件与 skills 融合"规划，本次分析提供以下参考：

### 6.1 "智能插件连接神经系统"与 Cordis 的 Service/inject 模型高度同构

用户规划的核心理念是：

> *"如果将软件比作生命体，那么传统插件只是相当于连接了血管、骨骼这些机械结构，但是没有连接神经系统。我规划的插件希望插件本身也具有 AI 驱动的能力，就是用 skills 的机制让插件也可以连接上神经系统。"*

映射到 Cordis 的世界观：
- **传统插件（连接血管骨骼）** = npm 包：代码装进去了，但插件之间互相看不见、没有协作协议；
- **智能插件（连接神经系统）** = Cordis Service：插件通过 `ctx.<key>` 暴露/消费服务，通过事件协作，通过 inject 声明依赖——**这就是插件之间的"神经系统"**；
- **Skills 机制 = 神经系统的语义层**：Cordis 的"服务 + 事件"是神经系统的基础设施（神经纤维），skills（可执行 SOP）是神经系统承载的"行为模式"。二者恰好互补：cordis 提供连接机制，skills 提供智能行为。

**结论：用户规划的"插件 + skills 融合"与 Cordis 的"Service + 事件"机制在架构上同构，cordis 可以作为一个成熟的理论与实现参考。** 但不需要照搬——见下一条。

### 6.2 静态语言（仓颉）与动态语言（TS）的插件机制差异

Cordis 的很多魔法依赖 TypeScript/JavaScript 的动态特性：
- **Context 是 Proxy**（reflect.ts 是 Proxy 的陷阱处理器）——`ctx.tools` 这种"没定义过的属性"能安全访问，靠的是 Proxy 拦截；
- **Fiber 用协程/异步**管理生命周期；
- **事件用声明合并**做类型化。

仓颉是静态语言，实现插件机制必然走"**编译时确定 + 运行时配置**"路线（这与第一轮报告中 agentskills-runtime 的架构判断一致）。可借鉴的是 Cordis 的**语义**（Service/inject/effect/事件分发/合流性），不可照搬的是它的**实现手段**（Proxy/原型链/动态类型）。静态语言版本的可逆卸载可以用"注册表 + 逆操作列表 + 确定性销毁顺序"实现——这正是 dsh vendor 修改日志里 fiber.ts 做的事，语义一样，实现路径不同。

### 6.3 定量评估自进化的借鉴：Cordis 的"性质证明"思路 vs 指标体系

Cordis 论文提供的是**性质证明**（无论怎么加载卸载，系统行为由终态决定——合流性），这是插件机制正确性的"结构性保证"。dsh 进一步工程化：**会话日志 append-only 不变量 + 覆盖率门禁 + vendor manifest 门禁**（改 vendor 代码必须同步更新 manifest，否则 CI 拒绝）。

agentskills-runtime 做"自进化定量评估"时，可以分层：
- **机制层**：借鉴 Cordis 性质（卸载后无孤儿资源、加载顺序不影响终态）作为**不变量断言**；
- **效果层**：保留 dsh 的足迹阶梯（Footprint Ladder：扩展已有代码 → CLI 命令 + 技能 → 服务门控工具 → 插件 → MCP 服务器 → 新核心工具）作为**能力边界评估**；
- **业务层**：效率、token 消耗、代码质量等可量化指标。

### 6.4 插件中心仓的思考：npm registry vs Koishi 插件市场

npm 的教训是：**中心仓只解决分发，不解决"插件与宿主的能力契约"**——peerDependencies 只能声明版本，声明不了"我的插件要求宿主提供 ctx.llm 服务"。Koishi 的插件市场（4000+ 插件）的经验是：**插件市场必须绑定运行时能力描述**（声明提供/消费哪些服务），才能让用户安全地组合插件。dsh 的 tool-cordis 的 `cordis_inspect` 把"插件能力契约"做成模型可读的生成式目录（api-catalog.ts，AST 生成 + 门禁保鲜）——**这是插件生态走向"AI 可消费"的关键一步**，值得 agentskills-runtime 的 skills 中心仓借鉴。

---

## 七、结论

1. **npm 与 Cordis 是分层关系，不是替代关系。** npm/pnpm 是包分发与依赖管理的地基，Cordis 是运行在地基之上的运行时组装框架。dsh 实际同时使用了二者。

2. **dsh 若只用 npm 插件机制，无法实现等效能力。** npm 覆盖"分发/版本/入口"约两成，缺"服务注入/生命周期/可逆卸载/事件分发/热更新/运行时反射"约八成；尤其"Agent 在会话中检视、试运行、撤回插件"的自引用能力，纯 npm 在架构上就不可能实现（npm 是安装期机制，装完要重启）。

3. **Cordis 机制的作用与意义，在于把"一切皆插件"从口号变成有理论保证的工程现实。** 它提供了：
   - 动态组合的**理论底线**（合流性/恢复精确性，论文背书）——自进化的安全网；
   - 运行时**自引用的基础设施**（反射 + 动态挂载 + 可逆卸载）——自进化的试错通道；
   - **生态验证**（Koishi 4000+ 插件）——机制成熟度证据；
   - **框架层完全自有**的工程实践（vendor + 18 条修改）——自进化系统的控制权保证。

4. **对 agentskills-runtime 而言，cordis 的核心价值是"参考坐标"而非"模仿对象"。** 用户规划的"插件 + skills 融合"（智能插件连接神经系统）与 Cordis 的"Service + 事件"机制在架构上同构；静态语言实现上可借鉴其语义（可逆卸载、声明式依赖、合流性），但实现路径必然不同（编译时确定 + 运行时配置）。定量评估自进化时，可借鉴 Cordis 的"性质证明"思路与 dsh 的门禁工程实践（不变量断言、生成物保鲜、vendor manifest）。

---

## 附录 A：参考材料清单

### dsh 仓库内一手材料
1. `docs/cordis-primer.md` — Cordis 五概念与 Waterfall 语义
2. `vendor/README.md` — vendor manifest、18 条本地修改日志、同步流程
3. `vendor/cordis/src/*.ts` — Cordis 核心源码（实测 2693 行）
4. `packages/extensions/tool-cordis/README.md` — 自引用工具集（inspect/define/run/stop/undefine）
5. `packages/extensions/cordis-host-runner/README.md` — node:vm 沙箱与 fiber 生命周期
6. `.agents/notes/implemented/feature/2026-07-08-self-referential-cordis-toolset.md` — 自引用设计文档（三大正确性问题、方案对比）
7. `.agents/notes/implemented/process/2026-06-11-vendor-cordis-as-source.md` — vendor 决策记录
8. `docs/cordis-tutorial/07-into-the-harness.md` — Cordis 概念到 harness 工具的映射示例

### 官方发布与社区分析
9. DeepSeek Harness 官方发布文章《DeepSeek Harness 开发者预览版：一切皆插件》（2026.08.13）— https://mp.weixin.qq.com/s/mANdGRI4fO_sEbC1ECEoZQ
10. openEuler 社区分析《连 Agent 循环都可以替换：DeepSeek Harness 的插件架构》— https://openeuler.csdn.net/6a7ea78a10ee7a33f29ad9fd.html
11. 《为什么用 Cordis 做 AI Agent 运行时：从 QQ 机器人框架到 DeepSeek Harness》— https://yuqingteck.blog.csdn.net/article/details/163735444
12. 《Cordis 驱动 DeepSeek Harness 一切皆插件的架构的原理解读-前端视角》（元理论五条）— https://juejin.cn/post/7673438154771824674
13. 《Cordis 时空可组合性：4000 插件的可逆底座》（论文靶子=自进化 harness）— https://www.chooseai.net/news/5846
14. 《Cordis 源码解读：用 Proxy 与原型链写成的「时空可组合」元框架》— https://www.iceyao.com.cn/2026/08/14/cordis-source-code-read

### npm 机制参考
15. npm 官方博客《Peer Dependencies》（Domenic Denicola）— https://nodejs.org/en/blog/npm/peer-dependencies/
16. 《peerDependencies vs dependencies vs devDependencies 区别》— https://blog.csdn.net/kalman2019/article/details/128503333
17. 《从零到一：理解 peerDependencies 与 Monorepo 的联动机制》— https://blog.csdn.net/2401_87810889/article/details/161282274

### 相关论文
18. Cordis 论文《A Programming Paradigm for Spatiotemporal Composability》（时空可组合性编程范式）
