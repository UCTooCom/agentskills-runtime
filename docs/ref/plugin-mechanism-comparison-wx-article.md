# Agent 框架插件机制横向对比分析报告

> 对 **deepseek-harness（Cordis）**、**openclaw**、**hermes-agent**、**agentskills-runtime** 四个同类型开源项目的插件（扩展）机制做源码级对照，输出统一维度下的差异、权衡与可借鉴点。

**报告日期**：2026-10-17 ｜ **分析方法**：源码实证（非文档转述）｜ **对比维度**：D1–D12 共 12 项 ｜ **证据粒度**：文件 / 行号

> 💡 **缩写约定**（全文通用）：**DSH** = deepseek-harness，**OC** = openclaw，**HM** = hermes-agent，**ASR** = agentskills-runtime。ASR 即本报告项目，缩写取自 *A*gent*S*kills-*R*untime。

---

## 目录

1. 评估方法与公平性声明
2. 四项目画像速览
3. 十二维度对比总矩阵（D1–D12）
4. 分维度深度剖析（D1–D12）
5. 隔离模型专题：四种哲学
6. 插件开发者支持实操对照：从零到插件上线
7. 成熟度校正评分
8. 根因解读：为什么它们如此不同
9. 对 ASR（agentskills-runtime）的启示
10. 拓展 AgentSkills 标准的定位：拓展 vs 创新
11. 附录：证据索引

---

## 1. 评估方法与公平性声明

### 1.1 怎么做到的"公平"

这四个项目处在**完全不同的成熟度阶段**：openclaw 是已大规模分发的产品（版本号 `2026.10.4`），hermes-agent 标称 `1.0.0`，deepseek-harness 自我声明为 `0.2.1-alpha.3` 的"开发者预览"，agentskills-runtime 为 `v0.0.29`。若直接按"现状谁更强"打分，等于用工程投入量碾压设计理念，这不公平。

因此本报告把每个维度拆成**两个独立口径**分别评估：

- **设计完备度（Design）**——机制在架构层面被设计到什么程度，是否覆盖了关键问题。看的是"想到了没有"。
- **落地成熟度（Maturity）**——该机制实际实现到什么程度、是否有生态规模支撑。看的是"做出来了没有"。

> ✅ **评分口径（1–5 分）**：5 = 该维度业界一流 / 4 = 完整且可用 / 3 = 有方案但有明显缺口 / 2 = 只有雏形 / 1 = 基本缺失。每个结论都尽量给出**源码证据**（文件路径 + 关键标识），而非文档转述。文档与代码矛盾时，**以代码为准**。

### 1.2 证据等级

| 等级 | 含义 | 本报告中的用法 |
|---|---|---|
| ✅ A · 源码确证 | 直接读到实现代码 / 类型定义 / 常量表 | 用于所有关键结论 |
| ⚠️ B · 文档确证 | 官方 README / 设计文档明确陈述 | 用于补充设计意图 |
| 🔵 C · 推断 | 由结构推断，未直接验证 | 仅用于次要描述，会显式标注 |

### 1.3 边界声明

- 本报告只看**插件/扩展机制**本身，不评价 Agent 能力、模型适配、UI 等其它方面。
- 四个项目均为 MIT 系许可（ASR 为 MIT，其 package.json 元数据标 ISC，以仓库 LICENSE 为准）。
- "插件"在各项目中叫法不同（plugin / extension / bundle / skill / MCP），本报告统一按"**宿主能力的可装卸扩展单元**"来理解，并在各章节标明其原生术语。

---

## 2. 四项目画像速览

### deepseek-harness（DSH）· Cordis · 一切皆插件

- **版本 / 许可**：0.2.1-alpha.3 · MIT
- **语言 / 运行时**：TypeScript · Node
- **插件内核**：Cordis（Context + Fiber + Service）
- **规模**：58 个 packages 目录
- **核心特征**：声明式组合（`cordis.yml`）+ 依赖注入 + HMR

### openclaw（OC）· 扩展 + 能力契约

- **版本 / 许可**：2026.10.4 · MIT
- **语言 / 运行时**：TypeScript · Node（含 Rust crates）
- **插件内核**：`src/plugins` + plugin-sdk 契约包
- **规模**：**180 个 extensions**
- **核心特征**：清单能力声明 + 安装期能力同意（consent）

### hermes-agent（HM）· Python 插件 + 双隔离档

- **版本 / 许可**：1.0.0 · MIT
- **语言 / 运行时**：Python（+ Electron 桌面端）
- **插件内核**：`PluginManager` + `PluginHost`
- **规模**：65 个 optional-mcps 目录
- **核心特征**：可切换 in-process / host 进程隔离

### agentskills-runtime（ASR）· 三轨插件 + Skill 融合

- **版本 / 许可**：v0.0.29 · MIT
- **语言 / 运行时**：仓颉（Cangjie）· 原生二进制
- **插件内核**：`magic.plugin` + cordis-cj（L3）
- **规模**：51 个 skills 目录
- **核心特征**：Sync / Dylib / Process 三轨并存

> 💡 **先说一个容易误判的点**：四个项目的"扩展单元"不是同一种东西。deepseek-harness 的 bundle 是**运行时可装卸的 npm 包**；openclaw 的 extension 多为**随产品分发的内置集成**（180 个，含 anthropic/openai 等 provider），第三方插件走另一条"外部代码插件"通道；hermes 的 plugin 是 **Python 包 / 目录**，另有 65 个 MCP 目录是**审批制的连接器目录**而非插件；agentskills-runtime 的 plugin 与 **SKILL.md 技能**是"三维一体"融合的。把它们都叫"插件"直接比数量会失真，本报告按机制比，不按数量比。

---

## 3. 十二维度对比总矩阵（D1–D12）

读法：每格先给结论，斜体灰字为源码证据。D1–D12 详见第 4 节；其中 D11（开发者支持）与 D12（原生智能 / 自进化）为本版新增。

| 维度 | deepseek-harness | openclaw | hermes-agent | agentskills-runtime |
|---|---|---|---|---|
| **D1 插件形态** | 导出 `apply(ctx)` 的模块；函数 / 对象 / Service 类三种（*docs/cordis-tutorial/01-first-plugin.md*） | npm 包 + `openclaw.plugin.json` 清单（*extensions/a2a/openclaw.plugin.json*） | Python 包（`__init__.py` + `register()`）或目录 + `plugin.yaml`（*hermes_cli/plugins.py:6*） | 仓颉包 + `plugin.yaml`（三轨 mode）+ `SKILL.md`（*src/plugin/plugin_config.cj:23*） |
| **D2 清单 / 版本契约** | `cordis.yml` 组合 + peer deps 校验 + `compatibility.json` 版本豁免（*plugin-manager/README.md:69-75*） | package.json 内 `openclaw.compat.pluginApi` + `openclaw.build.openclawVersion` 必填（*plugin-package-contract/src/index.ts:29-32*） | `plugin.yaml` + `requires_hermes` 版本范围 + 依赖探测（*plugin_validate.py:115,576*） | `plugin.yaml`（name/className/mode/order/config/env…）（*plugin_config.cj:72-112*） |
| **D3 发现 / 加载** | Loader 读 yml → 模块说明符解析 → 并发挂载（*01-first-plugin.md:31*） | discovery 扫描 + activation planner 规划 + 懒激活（*src/plugins/activation-planner.ts:76*） | 入口组 `hermes_agent.plugins` + 目录扫描 + 后台发现（*plugins.py:6,1774*） | 去中心化扫描 `plugin.yaml` + `@PluginAnnotation` 反射锚点防 LTO 剪除；运行时 `ClassTypeInfo.get → findAnnotation<PluginAnnotation> → ConstructorInfo.apply` 实例化，零配置注册、热插拔（*plugin_discovery_service.cj:29；plugin_loader.cj:48-61；generated_anchors.cj:2*） |
| **D4 隔离模型** | ❌ 进程内（文档明示）；动态定义跑 `node:vm` realm（*plugin-manager/README.md:31；cordis-host-runner/README.md*） | ⚠️ 进程内为主；有 worker-runtime 任务池（*packages/worker-runtime/src*） | ✅ 双档可切换 `in_process` / `host`（每 profile 一进程）（*plugin_isolation.py:28-30*） | ✅ 三轨 Sync（编译进宿主）/ Dylib（`PackageInfo.load`）/ Process（子进程 stdio）（*plugin_config.cj:14-26*） |
| **D5 通信 / IPC** | 同进程直接调用；无跨进程 IPC 需求 | 同进程 facade 调用；gateway-protocol 用于外部（*packages/gateway-protocol*） | Channel + generation 代次 + 对象代理（ref proxy）（*plugin_host.py:307-447*） | JSON-RPC over stdio（L3）（*cordis_host_manager.cj:24,32*） |
| **D6 生命周期 / DI** | ✅ 最强 Fiber 状态机 + `inject` 声明依赖 + effect 逆序清理 + HMR（*docs/cordis-api/fiber.md*） | activation-context / lifecycle / registry（*src/plugins/activation-context.ts*） | load/unload 回调 + 超时保护 + 代次重启（*plugins.py:413,1106*） | 状态机（register/unregister/snapshot/restore）+ 事件总线 emit/waterfall（*plugin_registry.cj:39-160*） |
| **D7 扩展点覆盖** | **一切皆插件**：工具/服务/UI/命令/channel 全走同一 ctx | channel / provider / tool / hook / skill / theme / model catalog…清单声明式 | 21 个 `register_*`：tool/hook/middleware/platform/memory/CLI…（*plugins.py*） | Service / Route / Skill / MCP；HTTP 路由外挂；**一切皆技能**（plugin + SKILL.md 三维一体，业界首创将开发框架插件机制与智能体技能机制有机融合，并拓展 AgentSkills 开放标准支持仓颉静态二进制发布）+ **多技能并行执行**（`src/skill/parallel`）（*skill_bridge.cj:57-92；src/skill/parallel*） |
| **D8 权限 / 安全** | 审批门（`danger-full-access`）+ sandbox 模式；**自述未做安全审计**（*SAFETY.md:3*） | ✅ 能力同意（consent）：安装前比对声明面 + reviewToken 确认（*capability-consent.ts:135*） | ✅ 能力探针：实际 import 探测注册项 vs 声明 diff；内置工具冲突检测（*plugin_validate.py:388-440*） | `tableWhitelist` 表级白名单（声明式）（*plugin_config.cj:106-108*） |
| **D9 分发 / 生态治理** | ✅ 最完整：多 registry 回退、官方 catalog、build script 审批、失败回滚（*plugin-manager/README.md:56,155-162*） | ClawHub catalog 客户端（*catalog-discovery.ts:499-523*） | MCP 目录经 PR 评审准入（"Presence = approval"）（*optional-mcps/airtable/manifest.yaml:2*） | plugingen 脚手架 + pluginuninstall 三层卸载（*src/plugin/tools/plugingen*） |
| **D10 开发体验** | ✅ HMR 原生；PENDING 诊断；7 章教程（*06-composition-and-hmr.md*） | 契约守卫测试（contracts/ 目录大量 *.contract.test.ts） | `hermes plugin dev/validate` CLI + 校验报告（*plugin_dev.py, plugin_validate.py*） | ⚠️ 受静态语言限制：改插件需重编宿主（Sync 轨）（*spec.md §0.2 限制 #1*） |
| **D11 开发者支持** | ❌ 无脚手架；`dsh plugin` 只是 pnpm 转发器。靠 7 章可运行教程起步（*apps/cli/src/plugin.ts:70-107*） | ✅ 最完整 `plugins init --type tool|provider|feature` 生成 7 个文件（含测试 + vitest）（*plugins-authoring-command.ts:716-753*） | ⚠️ 无脚手架；有 `plugins doctor`（真运行时验证）+ `validate`（*plugin_dev.py:370-432*） | ✅ plugingen + 确定性工具链：plugingen 默认生成 L3 process 轨**独立 cjpm 工程**可单独编译；另有 `loaddbinfo / crudgen / crudweb / pluginuninstall` 确定性代码生成工具链与 `sdd / long-running-task / uctoo-dev-manual` AI 驱动开发 SOP 技能（*plugingen.cj:48；src/app/tools；src/plugin/tools*） |
| **D12 原生智能 / 自进化** | ⚠️ 赋能强、自主弱：工具 schema 全自动注入 + SKILL.md + 模型可自装插件；**零反思/零学习库**（*tools/src/index.ts:857；packages/boot/plugin-manager*） | ✅ 四家最强：`skill_workshop` Agent 自写技能 + 后台自动评审 + `reloadAndResume` 自改自重载（*skill-workshop-tool.ts:305；self-learning.md:12*） | ✅ 技能层闭环：每轮后 fork 自评写 memory/skill + `skill_manage` + `/learn` + curator；**契约禁止改框架代码**（*background_review.py:1-6；skill_manager_tool.py:862*） | ✅ 插件↔技能三维一体 + 确定性代码腿：SKILL.md 自动转 LLM Tool + 每请求注入 prompt；**三腿自进化闭环（技能 / 代码 / 数据库）**中**代码腿由确定性代码生成工具链（loaddbinfo / crudgen / crudweb / plugingen / pluginuninstall）承载——可确定地演进框架代码**，并非仅产出方案（*skill_bridge.cj:57-92；src/app/tools；src/plugin/tools*） |

---

## 4. 分维度深度剖析（D1–D12）

### D1 · 插件的定义形态

**deepseek-harness** 把插件定义压到最简：一个导出 `apply` 的模块就是插件，并接受三种形状（函数 / 带 apply 的对象 / Service 子类）。整个应用不是"代码启动框架"，而是 `cordis.yml` 组合出来的插件树——教程里明确写 "There is no framework bootstrap code in your file"。这是**"一切皆插件"最彻底的表达**。

```ts
// docs/cordis-tutorial/01-first-plugin.md:11-19
export const name = 'hello'
export function apply(ctx: Context) {
  console.log('hello from my first plugin')
}
// cordis.yml
- name: './hello.ts'
```

**openclaw** 走"包 + 清单"：扩展目录带 `openclaw.plugin.json`，声明 id、分类、激活条件、channel、configSchema。清单是**机器可读的能力契约**，加载器照着清单决定给它什么。

**hermes-agent** 是 Python 生态的典型：既支持 setuptools entry-point 组 `hermes_agent.plugins`，也支持目录 + `plugin.yaml`，插件入口是包里的 `register(ctx)`。

**agentskills-runtime** 用 `plugin.yaml` 描述，且每条带 `mode` 字段决定走哪条轨：

```yaml
# src/plugin/plugin_config.cj:44-67（清单示例）
plugins:
  - name: memory-postgres
    className: magic.plugins.memory.MemoryPostgresPlugin
    mode: sync            # 缺省 sync；可选 sync/dylib/process
    order: 1
    config: { connectionString: "postgres://..." }
  - name: external-tool
    mode: process         # L3 进程隔离轨
    command: ./skills/external-tool/target/release/skill_external_tool.exe
    args: ["--log-level", "info"]
    autoRestart: true
```

> 💡 **点评（公平）**：DSH 的"零样板"体验最好，代价是插件形态与宿主语言强绑定（必须 TS 模块）。agentskills-runtime 的 `mode` 字段是**四家里唯一把"隔离档位"写成清单一等公民的**——插件作者显式选择跑在哪，这在静态编译语言里是必要的（编译进宿主 vs 动态库 vs 子进程，代价差一个数量级）。DSH/hermes 的隔离是宿主全局开关，runtime 是**逐插件声明**，粒度更细。

### D2 · 清单与版本契约

插件生态真正的难点不是"能不能装"，而是**"装上去会不会因为版本不匹配把宿主搞崩"**。四家的应对差异明显：

| 项目 | 版本约束机制 | 冲突时的行为 |
|---|---|---|
| deepseek-harness | 安装前用 pnpm 解析 registry spec 的 **peer deps** 与 DSH 版本比对；不兼容直接拒绝 | 拒绝 + 报错 `incompatible-version`；支持 `compatibility.json` 按 `pkg@ver → runtime版本` 精确豁免，但需 `acceptRisk: true` |
| openclaw | package.json 两个**必填**字段：`openclaw.compat.pluginApi`、`openclaw.build.openclawVersion` | 缺字段即校验失败（`listMissingExternalCodePluginFieldPaths`） |
| hermes-agent | `requires_hermes` 版本范围 + `requires_env` + Python 依赖探测 | 校验报告逐项列出（ValidationReport） |
| agentskills-runtime | 清单含 `version`，但**未见宿主版本 range 约束的等价机制** | — |

> ⚠️ **agentskills-runtime 的明确短板**：它的 Sync 轨是**编译期**合并进宿主的，版本冲突在编译阶段就暴露了，所以"运行时版本协商"的必要性确实低于其他三家（这不是偷懒，是静态语言的天然免疫）。但 Dylib / Process 两轨一旦成熟，插件与宿主就是**二进制 ABI 关系**——那时候没有版本 range 校验会比动态语言更危险（动态语言不兼容只是报错，ABI 不兼容是段错误）。**建议：L2/L3 轨正式启用前，必须补 ABI/pluginApi 版本协商。**

### D3 · 发现与加载

- **deepseek-harness**：Loader 插件读 `cordis.yml`，把每个 `name` 当模块说明符解析（相对路径或 npm 包名），**并发挂载**。关键设计：列表顺序不保证加载顺序，**顺序由 `inject` 声明的服务依赖推导**。
- **openclaw**：`activation-planner` 解析清单的 `activation` 段（如 `onStartup: false`）决定激活时机，配合 discovery-state 做按需加载——**懒激活**是大生态的必要优化（180 个扩展不可能全启动）。
- **hermes-agent**：入口组 + 目录扫描，另有 `start_background_plugin_discovery()` 把发现挪到后台线程，避免拖慢启动（*plugins.py:1774*）。
- **agentskills-runtime**：`PluginDiscoveryService.discover()` 去中心化扫描 `plugin.yaml`；因为仓颉 LTO 会剪除未被静态引用的类，必须靠 build-sync 生成 `generated_anchors.cj` 显式实例化来"锚住"插件类（*spec.md §0.2 限制 #3*）。扫描到声明后，`PluginLoader` 经 `ClassTypeInfo.get → findAnnotation<PluginAnnotation> → ConstructorInfo.apply` 在运行期动态定位并实例化插件类，无需维护静态注册表——新插件放入目录即生效（零配置注册、热插拔）。

> 💡 **值得记的一点**：DSH 用"依赖推导顺序"取代"声明顺序"，这是个真正的架构洞见——插件多了以后，人工维护顺序必然出错。agentskills-runtime 用 `order` 数字字段排序，在 51 个 skill 规模下够用，但规模上去后会重蹈覆辙。

### D4 · 隔离模型

这是四家差异最大、也最值得单独成章的维度，见第 5 节专题。

### D5 · 通信与 IPC

只有**真正跨了进程**的两家需要 IPC，它们的实现都很讲究：

- **hermes-agent** 的 `PluginHost` 是一个相当完整的 RPC 层：Channel 传输、`generation` 代次（宿主重载后旧代次的调用被拒绝）、对象代理（`_ObjectSlot` + `_object_proxy`，把插件侧对象的方法表发给宿主，宿主构造 ABC 子类，方法调用回到插件进程执行）。还显式列出了**"无法跨进程"的方法清单**（`HOST_UNSUPPORTED_CTX_METHODS`）——比如需要原生 SDK client 的注册项，只能 in-process。
- **agentskills-runtime** L3 用 **JSON-RPC over stdio**（`ystyle::cordis_host.PluginManager(stdio)`），并注明 UDS 不启用（*cordis_host_manager.cj:24,32*）。

> ✅ **hermes 的 `HOST_UNSUPPORTED_CTX_METHODS` 是本次调研里最有工程价值的一处细节**。它诚实地承认"进程隔离不是银弹"：有些能力天然需要活对象（原生 SDK client、event loop 绑定的 adapter、argparse parser），跨进程就拿不到。它的做法是**把这些方法显式列成表 + 给出拒绝理由**，而不是假装全部支持。同一张表还被静态审计脚本复用（`plugin_isolation_audit`），保证"审计说安全"和"实际能加载"不会漂移——文档里原话："the audit says pool-safe and it loads in the host cannot drift apart"（*plugin_isolation.py:14-17*）。

### D6 · 生命周期与依赖注入

**deepseek-harness 在这一项上是断层领先**，Cordis 的 Fiber 模型提供了四家里最完整的语义：

- **Fiber 状态机**：每个插件实例是一个 fiber，有 uid、state、config、store（依赖实现快照）。
- **声明式依赖**：`export const inject = ['timer']`，缺 provider 时 fiber 停在 **PENDING** 而非报错——因为 provider 可能稍后才挂载。这是"迟到的依赖"的正确处理。
- **可逆卸载**：`ctx.effect()` 注册的 disposer 在 fiber 卸载时**逆序执行**，且支持 async（卸载会 await）。这意味着插件真的可以被干净地摘掉。
- **HMR**：`fiber.restart()` / `update()`，配合文件监听实现热重载。
- **诊断**：可遍历 `ctx.registry` 检查每个 fiber 的 state，专门对付"插件什么都不做也不报错"的静默失败。

```ts
// 诊断 PENDING 插件（06-composition-and-hmr.md:67-83）
for (const runtime of ctx.registry.values())
  for (const fiber of runtime.fibers)
    if (fiber.state === FiberState.PENDING)
      console.log(`${fiber.name} is PENDING — a required service is missing`)
```

**agentskills-runtime** 用"注解声明 + 反射发现 + 生命周期状态机"覆盖了六语义中的五个（Service / inject / effect / Events / 检视），事件总线实现 `emit` / `waterfall` 两种；**HMR 明确延后**，spec 里原话是"HMR/合流性无定理背书，对外只表述确定性插件生命周期"——这个自我标注很诚实，值得肯定（*spec.md §0.2 限制 #6*）。

**hermes-agent** 有 load/unload 回调、加载超时保护（插件超时后再调 ctx 会被忽略并记日志）（*plugins.py:1106*）。**openclaw** 有独立的 activation-context / lifecycle / registry-lifecycle 模块。

### D7 · 扩展点覆盖面

| 项目 | 可扩展的东西 | 特点 |
|---|---|---|
| deepseek-harness | 工具、服务、UI、CLI 命令、channel、provider…… | **无分类**——因为一切都是插件，ctx 就是唯一 API 面 |
| openclaw | channel、model provider、tool、hook、skill、theme、model catalog/pricing、TTS、media… | **清单声明式分类**，`categories` 字段 + `PLUGIN_CATEGORY_SLUGS` 白名单校验 |
| hermes-agent | 21 个 `register_*`：tool、hook、middleware、platform、memory provider、context engine、secret source、CLI 命令、locale、system prompt 段… | **方法即扩展点**，ctx 有多少方法就有多少扩展点；清单里用 `provides_tools/hooks/middleware` 声明 |
| agentskills-runtime | Service、HTTP Route、SKILL.md 技能、MCP server | **plugin 与 skill 三维一体融合**（`SkillBridge`：插件目录下的 SKILL.md 自动注册为技能）（*skill_bridge.cj:43-91*） |

> 💡 **agentskills-runtime 的独门设计**："插件 + 技能"融合是本调研中唯一一家把**代码扩展（plugin）**和**提示词级能力（SKILL.md）**放在同一目录约定下的（三维一体：`plugin.yaml` + `SKILL.md` + `scripts/`）。`SkillBridge.registerPluginSkills()` 会扫描插件目录根和子目录的 SKILL.md 自动注册，没有 SKILL.md 的插件按纯 Service 处理。这让"一个插件既能提供 RPC 服务，又能教 Agent 怎么用"，是区别于另外三家的**真实差异化**，不是包装。

### D8 · 权限与安全模型

四家的思路可以分成两派：**"运行时审批派"**（DSH）和**"安装期声明比对派"**（openclaw / hermes）。

**deepseek-harness：运行时审批门**

每次工具动作需要 `danger-full-access` 或逐次审批；低 sandbox 模式下 `ask` 请求批准、`never` 直接拒绝。但它**明确自述**："installed Host code executes in-process outside the workspace sandbox"（宿主插件代码在进程内、**工作区沙箱之外**执行），且 SAFETY.md 开头就写 "It has not undergone a security audit and must not be treated as secure or production-ready"（*plugin-manager/README.md:31；SAFETY.md:3*）。

**openclaw：安装期能力同意（capability consent）**

清单声明 `capabilities`，安装时 `resolvePluginCapabilityConsent()` 拿当前声明面与安装记录比对，变化时触发 `onCapabilityConsent` 让用户用 `reviewToken` 确认。还有官方插件的 `recordOfficialCapabilities` 快速通道。这是**"用户明确知道这个插件要拿什么"再放行**的模型（*capability-consent.ts:135-160*）。

**hermes-agent：能力探针（capability probe）**

这是四家里**最硬核**的：不信任清单声明，而是**真的 import 一次插件**（在隔离环境中跑 `register()`），把实际注册到的 tools/hooks/middleware 与清单 `provides_*` 做 diff：

```py
# plugin_validate.py:409-434
declared = set(_declared_list(manifest, manifest_key))
actual   = set(recorded.get(kind) or [])
undeclared   = sorted(actual - declared)   # 偷偷多注册了 → 失败
unregistered = sorted(declared - actual)   # 声明了却没注册 → 警告
```

另外还有内置工具名冲突检测（`_check_builtin_collisions`）、安全扫描（`_check_security_scan`）。清单声明与实际行为的**一致性由机器验证**，这比"让用户点同意"更可靠——用户其实看不懂能力清单。

**agentskills-runtime：表级白名单**

`tableWhitelist` 声明插件可访问的 DB 表，缺省空列表=拒绝全部表（*plugin_config.cj:106-108*）。方向正确（默认拒绝），但**覆盖面最窄**——只管数据库表，没有覆盖网络、文件、进程等其它能力维度。

> ⚠️ **给 agentskills-runtime 的优先级建议**：hermes 的"能力探针"思路对 runtime 的 L2/L3 轨**特别合适**——因为插件是二进制，用户更没法审查它干什么。可以在 L3 进程启动后做一次"能力宣告握手"：插件上报自己会注册哪些 Service/Route，宿主与 plugin.yaml 声明比对，不符则拒绝挂载。成本低、收益高。

### D9 · 分发、安装与生态治理

**deepseek-harness 在这一项上是四家里唯一达到"产品级"的**，它的 plugin-manager 处理了大量真实世界的脏活：

- **多 registry 回退**：主 registry → `fallbackRegistries`（默认 npmmirror）逐个尝试，超时/无此包才换下一个；私有 registry 永不回落到公共源。
- **失败回滚**：pnpm 跑之前快照 `package.json` + `pnpm-lock.yaml`，失败即还原（明确注明"用户自己写的 patch 配置、应用数据、日志不动"）。
- **构建脚本审批**：pnpm 11 拦截依赖脚本时，收集 pending builds 让用户逐项批准，批准按包名持久化在该 profile。
- **GitHub 预检**：安装前 `git ls-remote` 探活（5s 超时），只因网络失败/超时才中止，认证问题交给 pnpm。
- **取消语义**：`cancelInstall(requestId)` 区分 `cancelled` / `too-late` / `not-running`。
- **请求恢复**：`waitForInstall(requestId)` 让断线客户端重连回正在进行的安装。
- **幂等与锁**：profile 写锁（120s）、`.plugin-manager/run.json` 记录运行中的 pnpm 进程防止并发踩踏。

> 💡 **openclaw** 有 ClawHub catalog 客户端（`fetchClawHubPluginCatalog` / `fetchClawHubSkillCatalog`）（*catalog-discovery.ts:506-523*）；**hermes** 的 MCP 目录是**PR 评审准入制**，manifest 里第一行就写 "Presence in this directory = approval. Merged via PR review."（*optional-mcps/airtable/manifest.yaml:2*）——简单粗暴但有效，适合不敢放开的市场冷启动阶段。**agentskills-runtime** 有 plugingen 生成器和三层卸载（运行时层/静态资产层/数据库痕迹层），卸载模型设计得不错，但分发/市场侧还是空的。

### D10 · 开发体验与可观测性

- **deepseek-harness**：最优。7 章渐进教程 + HMR + PENDING 诊断 + 效果标签（`getEffects()` 返回带 label 的效果树）。它甚至专门用一章讲"插件永远不加载时怎么查"。
- **openclaw**：靠**契约测试**保障——`src/plugins/contracts/` 下有大量 `*.contract.test.ts`（boundary-invariants、config-footprint-guardrails、sdk-subpaths…），用测试锁住 API 面不漂移。这是大团队治理插件生态的正确姿势。
- **hermes-agent**：`hermes plugin dev` / `validate` CLI，校验报告逐项列出 pass/warn/fail，包括真实 import 探测。
- **agentskills-runtime**：⚠️ **受静态语言拖累**。Sync 轨插件改一行要重编宿主（实测整编约 51 分钟），这是**开发体验上最痛的一点**。仓库已用 watcher + 增量编译缓解，但 HMR 级别的体验在静态语言下短期内不可得。

### D11 · 开发者支持：从"读文档"到"一条命令"

这一维度问的是最朴素的问题：**一个第三方开发者想给这个项目写插件，他第一步要做什么？** 四家的答案差距极大。

| 项目 | 脚手架 | 起步动作 | 作者测试支持 |
|---|---|---|---|
| **DSH** | ❌ 无 | `mkdir tmp/cordis-tutorial` → **手抄** `docs/cordis-tutorial/` 七章代码；或 `mkdir scratch-plugin/src` 手写 `my-plugin.ts` + `cordis.yml` | 无对外 SDK；仓库内有 `agent-loop-testkit`、`loader-smoke`，测试政策要求"HMR-safety 契约测试"与真实 Loader 组合测试（*docs/testing.md:9,39*） |
| **OC** | ✅ 有，三种模板 | `openclaw plugins init <id> --type tool|provider|feature` → 生成 `package.json` / `src/index.ts` / `src/index.test.ts` / `README.md` / `openclaw.plugin.json` / `tsconfig.json` / `vitest.config.ts` 共 7 个文件（*plugins-authoring-command.ts:339-423,716-753*） | ✅ 最完整：15 个 SDK 公开测试子路径（`createTestPluginApi`、`describePluginRegistrationContract`、`withServer`…）+ `src/plugins/contracts/*.contract.test.ts`（*docs/plugins/sdk-testing.md:22-44*） |
| **HM** | ❌ 无 | `mkdir -p ~/.hermes/plugins/calculator` → 手写 `plugin.yaml` / `__init__.py` / `schemas.py` / `tools.py` 四文件 → `hermes plugins doctor . --ci`（*plugins/index.md:273-295*） | 有 `plugins doctor`（**走真实发现 + 真实 register + 断网**的验证器，源码自陈"not a plugin test framework"）与 `plugins validate`；**无对外测试 SDK**（*plugin_dev.py:31-61,370-432*） |
| **ASR** | ✅ 有 | `cjpm run --name magic.plugin.tools.plugingen -- --name <n>`，**默认 `--mode process`**（L3 进程隔离轨），生成 `SKILL.md` / `plugin.yaml` / `cjpm.toml` / `src/main.cj` / `{X}Handlers.cj` / `{X}Effects.cj` / `README.md`；此外提供 `loaddbinfo / crudgen / crudweb / pluginuninstall` 确定性代码生成工具链，以及 `sdd`、`long-running-task`、`uctoo-dev-manual` 等 AI 驱动开发 SOP 技能（*plugingen.cj:48；PluginGenerator.cj:296-395；src/app/tools；src/plugin/tools*） | ❌ 最弱：只有宿主侧两个集成验证程序（`plugin_system_check.cj` / `cordis_l3_check.cj`）与 `DATA_CONTRACT.yaml` 骨架；**无插件侧测试脚手架、无 mock 宿主** |

**ASR 的 plugingen：默认轨就是 L3，生成的工程能脱离宿主单独编译**

```cj
// src/plugin/tools/plugingen/plugingen.cj:48
var mode = "process"  // 缺省 L3 process 轨（进程隔离，独立 cjpm executable 工程）；
                      // 内嵌 sync 轨需显式 --mode sync

// 生成的 skills/<name>/cjpm.toml（PluginGenerator.cj:367-395）
[package]
  cjc-version = "1.1.3"
  compile-option = "--dy-std -Woff all"
  name = "skill_<name>"
  output-type = "executable"      # ← 独立可执行文件
[dependencies]
  "ystyle::cordis_plugin" = { path = "../../libs/cordis-cj/cordis_plugin" }
  "ystyle::cordis_core"   = { path = "../../libs/cordis-cj/cordis_core" }
```

这是四家里**唯一一个"默认把第三方插件生成为独立进程工程"的脚手架**——把最安全、最可闭源分发、最易做插件市场的那一轨设为默认，避免了开发者因为"默认最简单"而掉进进程内耦合的坑。代价是：依赖仍以相对路径指向宿主仓库内 `../../libs/*`，**拷出仓库就编译不过**（真正的"独立发布"还需要依赖打包方案）。

**但 plugingen 只是 ASR 开发者支持的一环。** ASR 真正的差异化是围绕**确定性代码生成工具链**构建的 AI 驱动开发框架：`loaddbinfo` 把数据库结构注入生成上下文、`crudgen / crudweb` 确定性产出五层 CRUD 代码、`pluginuninstall` 做三层卸载；这些工具与 `sdd`（SDD 规范化开发流程）、`long-running-task`（长程任务 + LRT 五环节）、`uctoo-dev-manual`（开发手册）等技能 SOP 组合，使开发者（或与模型协作）能在"确定性可编译"的护栏内演进框架。**这正是 DSH / OC / HM 三家全部缺失的"代码腿"**——它们的脚手架只帮你"写个插件壳"，而 ASR 的脚手架把"演进框架本身"也工具化了（*src/app/tools；src/plugin/tools；skills/sdd；skills/long-running-task；skills/uctoo-dev-manual*）。

> ⚠️ **公平指出 ASR 的真实短板**：生成器很强，但**测试侧是空白**——`templates/` 下没有任何 `*_test.cj.tpl`，`skills/*/` 下没有 `test/` 目录。OC 的做法（生成时就带 `index.test.ts` + `vitest.config.ts`）值得直接抄：让模板自带一个"跑得起来的最小测试"，是降低第三方作者门槛成本最低的一招。

### D12 · 原生智能与自进化（RSI）：插件系统能不能让模型"长本事"

业界共识是：智能体要走**递归自我改进（RSI）**，前提是**模型能感知自己有什么能力、并且能扩充它**。插件机制恰好是这条链路的物理载体——**能力是插件给的，模型看不见插件，就谈不上自进化**。四家在这件事上的投入差别，比隔离模型还大。

**第一层：能力能不能自动进入模型视野**

| 项目 | 插件 → 模型的自动通道 | 技能声明式机制 |
|---|---|---|
| **DSH** | ✅ 全自动：`ToolRuntime` 构造里一行 `ctx.systemPrompt.tools(...)` 打通全部工具 → 每 step `assemble()` → provider `tools` 字段（*tools/src/index.ts:857；agent.ts:272*） | 17 个内置 `SKILL.md`；文件系统 + **插件内存注册**（`ctx.skills.register`）双来源（*skill-filesystem/src/index.ts:730-847*） |
| **OC** | ✅ 全自动：TypeBox schema 自动归一化到 OpenAI/Anthropic/Gemini/GBNF；**未列入核心表的插件工具自动按字母序追加进 prompt**（*system-prompt-tool-list.ts:78-84*） | 126 个 `SKILL.md`；prompt 只放 `<available_skills>` 的 name/description/location，按需 `read` 全文，硬限 `Up-front max one`（*skill-contract.ts:98-128；system-prompt-skills.ts:3-37*） |
| **HM** | ✅ 全自动：`register_tool` 进 `tools.registry` → `get_tool_definitions()` 无差别收编；插件技能经 `_plugin_skill_prompt_rows` 进 `<available_skills>`（*model_tools.py:500-541；prompt_builder.py:1312-1341*） | 212 个 `SKILL.md`；三级渐进披露（`skills_list` → `skill_view` → `skill_view(path)`）（*skills.md:172-182*） |
| **ASR** | ✅ 全自动：**插件 ↔ 技能三维一体**——`SkillBridge` 把插件目录下的 SKILL.md 注册为技能，`SkillToToolAdapter` 把 frontmatter 的 name/description 直接映射成 Tool；技能完整内容**由框架自动注入上下文**（`SkillAutoInjector`：初始化注入 always_on 技能 + 用户消息阶段经 `TaskMatcher` 任务匹配自动注入）（*skill_bridge.cj:57-92；skill_to_tool_adapter.cj:28-50；skill_auto_injector.cj:43,126；WebMCPProtocol.cj:2303-2311（webmcp 聊天链路）*） | `templates/SKILL.md.tpl` 的 frontmatter 带 `plugin:` 字段与插件绑定；技能完整内容**已由框架自动注入**（见左列），`get_skill_content` 工具**降级为向后兼容兜底**——仅当自动注入未覆盖时由模型按需调用，且对已自动注入的技能去重返回缓存（*get_skill_content_tool.cj:46,121*） |

**这一层四家都做到了，且都是"零手工注册"**——说明"插件能力自动进 prompt"已是行业基线，不再是差异化。

> ✅ **ASR 技能内容加载已升级（concurrent_skills 工程）**：将技能完整内容加载从"agent 主动调用 `get_skill_content` 工具"改为"**框架自动注入上下文**"——`SkillAutoInjector` 在 Agent 初始化时注入 `load_policy=always_on` 技能（阶段一）、在用户消息阶段经 `TaskMatcher` 任务匹配自动注入高匹配度技能（阶段二）；`get_skill_content` 保留为**向后兼容兜底**（已自动注入的技能去重返回缓存）。这把"技能即工具"进一步推进为"技能指令体即上下文"，区别于 DSH/HM 仍依赖模型自行调用工具取全文。详见 `.codeartsdoer/specs/concurrent_skills/design.md` §更新摘要。

**第二层：模型能不能自己扩充能力（这才是 RSI）**

- **DSH — 会安装，不会反思。** 有 `plugin_manager` 工具让模型列/装/启停插件（需 `danger-full-access` 审批），有 `cordis_inspect_*` 让模型在写插件前自省宿主 API（数据源是从 JSDoc AST 自动生成的 catalog）。但全仓检索 `self-improvement / reflection / memory-learner` **零命中**：没有经验写回、没有自动插件生成。最接近的 `ralph` 循环明确写着"模型只提供数据，不能改写循环本身"，并自认"完成度是 worker 自我声明，无独立验证器"。**定性：赋能（enablement）做得很完整，自主（autonomy）被刻意留白**（*plugin-manager/src/tools.ts:84-109；experimental/tool-ralph/README.md:61,161*）。

- **OC — 四家里最深入。** `skill_workshop` 工具给模型 8 个动作（list/view/create/patch/write_file/remove_file/archive/restore），写操作强制"先 view 再改"，create 时还会提示与既有技能合并去重；更关键的是**后台自动评审**：`skills.workshop.autonomous.mode: "auto"` 默认开启，累计 10 轮未评审就排队一个后台任务，空闲 30s 后自动跑，评审时 `skill_workshop` 是唯一能改变状态的工具。再加 `plugins` 工具的 `reloadAndResume`——模型改完插件文件、触发重载、**在同一会话里继续原任务**。Custodian skills 还把"Agent 自己改配置"变成 Gather→Mutate→Repair→**Prove**→Report 的可审计 playbook（*skill-workshop-tool.ts:305,281；docs/tools/self-learning.md:12,28-44；plugins-reload-handoff.ts:30-38*）。

- **HM — 技能层闭环完整，插件层明令禁止。** 每轮结束后 `background_review` fork 一个 AIAgent 回放整段对话，问"有没有该存/该改的 skill 或 memory"，写工具只有 `skill_manage`（`write_file/patch/terminal` 一律拒绝）；`skill_manage` 被官方定性为 **procedural memory**；`/learn` 让模型从任意素材（仓库/URL/PDF/刚做过的事）现场蒸馏出新技能；`curator` 在无 cron 守护的前提下做合并/归档/去陈旧。但兼容性契约**明文禁止**运行时改写核心（`setattr` 到 Hermes 模块、写 `sys.modules`），Catalog 准入直接拒收；后台分叉也没有任何写插件的能力（*background_review.py:1-6,1088-1128；skill_manager_tool.py:862-928；plugins/index.md:221-228*）。

- **ASR — 唯一拥有"代码腿"的自进化：三腿闭环（技能 / 代码 / 数据库）。** 插件与技能融合不只是"能看到"，`SkillToToolAdapter` 让技能**本身成为 LLM 可调用工具**，且 `src/skill/parallel` 支持**多技能并行执行**；自进化的独到之处在于**代码腿由确定性代码生成工具链承载**：`loaddbinfo` 把数据库结构注入生成上下文、`crudgen / crudweb` 确定性产出五层 CRUD 代码、`plugingen / pluginuninstall` 生成与卸载插件——这些工具**产出的代码"必定确定性可用、可编译"**，从而支撑框架自主迭代而不腐坏架构；`src/app/services/lrt` 的 LRT 五环节（实测 → 根因 → 优化方案 → 防回退 → 约束注入）则把"验证即闸口"做成闭环。**边界不是"禁止改代码"，而是"框架级结构正确性由确定性工具保障"**：LLM 仍在需要的流程与位置生成代码（胶水逻辑、非标准实现），只是不再让其概率性输出单独承担框架级结构——*以系统工程的确定性消解 LLM 的不确定性*（*skill_bridge.cj:57-92；src/app/tools；src/plugin/tools；src/app/services/lrt；docs/ref/AIDrivenArchitecture.md*）。

**第三层：模型能不能自省运行时**

| 项目 | 面向模型的自省工具 |
|---|---|
| **DSH** | `cordis_inspect_list` / `cordis_inspect_query`（只读，AST 生成，专供"写插件前先查宿主"）（*extensions/tool-cordis/README.md:12,28*） |
| **OC** | `skills_search`/`skills_read`、`tool_search`/`tool_describe`/`dispatch_action`、`plugins list/inspect/search`、`gateway`（读宿主 config/schema）四组（*installed-skill-tools.ts:34-86；tool-search-types.ts:10-15*） |
| **HM** | 无统一自省工具；靠 `skills_list`/`skill_view` 与 `tool_search`/`tool_describe` 间接达成；`hermes plugins capabilities` 是 CLI 不是模型工具（*tools/skills_tool.py:675-743*） |
| **ASR** | `plugin_inspect`（含 `buildCapabilityCatalog` 的 plugin→skills 映射）/ `plugin_activate` / `plugin_deactivate` / `plugin_refresh` + `llm_channel_list/test/probe/switch` + `get_skill_content`（向后兼容兜底，早期"按需取全文"主路径现已由框架自动注入取代）（*plugin_agent_tools.cj:112-448；skill_bridge.cj:112-125；get_skill_content_tool.cj:46,121*） |

> ✅ **这一维度最有价值的发现**：在"自进化能不能碰代码"这件事上，四家分成了两派——**DSH / OC / HM 三家都把自进化锁死在技能（SKILL.md 文本）层，且契约或权限明令禁止模型改框架 / 插件代码**（OC 的 workshop 只能改技能文本、HM 的后台分叉无写工具权限且契约禁止改核心、DSH 干脆没有这条链路）。**ASR 是四家里唯一拥有真正"代码腿"的**：它的自进化不是只产出方案，而是经 `loaddbinfo / crudgen / crudweb / plugingen / pluginuninstall` 确定性工具链**实际生成可编译的框架代码**，把"代码 + 技能 + 数据库"三腿做成了闭环（数据库腿当前较弱，UMI-ORM 尚待补全）。四家的**共同原则**是：框架级结构正确性不交给 LLM 自由生成（实践已证含概率的 AI 直写框架代码必走"编译失败—修复"死路）；**ASR 的不同在于"用确定性工具消解不确定性"，而非"靠权限缺省禁止"**——这是它相对所有 harness 的根本差异，也是其"AI 驱动开发框架"定位的核心。

---

## 5. 隔离模型专题：四种哲学

隔离模型是插件机制的**分水岭**——它决定了"敢不敢装第三方插件"。四家选择了四种不同的位置：

| 项目 | 默认档 | 可选档 | 故障爆炸半径 | 哲学 |
|---|---|---|---|---|
| **deepseek-harness** | 进程内（in-process） | 动态定义跑 `node:vm` realm | 插件崩 = 宿主崩 | 信任 + 审批 + 组合优雅性优先 |
| **openclaw** | 进程内 | worker-runtime 任务池 | 插件崩 = 宿主崩 | 契约 + 清单声明 + 安装期同意 |
| **hermes-agent** | `in_process` | `host`（每 profile 一子进程） | ✅ host 档下 = 仅插件宿主崩 | 可切换；诚实标注哪些能力不能跨进程 |
| **agentskills-runtime** | L3 process（plugingen 新插件默认；存量宿主模块 sync 且冻结） | Dylib（动态库）/ Sync（内嵌） | ✅ Process 轨 = 仅插件进程崩 | 三轨并存；增量扩展一律 L3 插件化，宿主存量冻结只减不增 |

**关键原文（避免误读）**

```py
# hermes_cli/plugin_isolation.py:3-12（模块 docstring）
in_process (default) imports every plugin into the Hermes process, as always.
host keeps third-party plugin code OUT of it: general plugins load in one
plugin-host process per profile and talk to Hermes only through ctx ...
That second half is the property a pooled deployment needs: one Hermes process
serving many profiles must never share an interpreter with a profile's plugin code.
The same boundary gives a single-user install crash isolation (a plugin that
segfaults or hangs takes down its host, not the gateway).
```

> ✅ **hermes 这段话说得最透彻**：进程隔离**不只是为了防恶意插件，更是为了部署形态**——"一个 Hermes 进程服务多个 profile"时，绝不能和某个 profile 的插件代码共享解释器。顺带还白拿了崩溃隔离（插件段错误只崩宿主进程，不崩 gateway）。这个"一份设计同时解决多租户和稳定性"的思路，值得 agentskills-runtime 在 L3 轨推广时借鉴。

> 💡 **公平地说 DSH**：它选进程内不是不懂隔离，而是**权衡后的选择**——Cordis 的全部优雅性（Fiber、inject、effect 逆序清理、HMR）都建立在"插件与宿主共享同一个 Context 对象图"之上，一旦跨进程，这些语义全要重写成 RPC。它的补偿手段是**审批门 + 明确告知风险**（SAFETY.md 直言未安全审计、不要作为唯一安全控制）。这叫"把风险讲清楚后让你自己承担"，也是一种负责任的做法，只是不适合跑不可信代码。

---

## 6. 插件开发者支持实操对照：从零到插件上线

上一节的 D11 给的是"有没有"，这一节给的是**"照着做要敲哪些命令"**。四家各用一套可复制的最小路径描述。

**DSH — 文档驱动，无脚手架**

```bash
# 1. 建目录（自己建，没有 init）
mkdir -p scratch-plugin/src
# 2. 手写插件 —— 最小 7 行，导出 apply 即插件
cat > scratch-plugin/src/my-plugin.ts <<'EOF'
import type { Context } from '@deepseek-ai/cordis'
export const name = 'hello'
export function apply(ctx: Context) { console.log('hello') }
EOF
# 3. 手写组合清单
cat > scratch-plugin/cordis.yml <<'EOF'
- name: '/abs/path/scratch-plugin/src/my-plugin.ts'
EOF
# 4. 用 --patch 挂载跑起来（不打包、不安装）
pnpm dsh web --patch ./scratch-plugin/cordis.yml
```

工具 `skill_initializer` 不存在于 DSH；`dsh plugin` 子命令里唯一自有的三个是 `allow-version / revoke-version / version-exemptions`，其余全部转发给 pnpm（*apps/cli/src/plugin.ts:19,97*）。**分发时才 npm 化**：`package.json` 声明 `dsh.bundle` + `cordis.patch.yml` → `dsh plugin --profile demo add ./hello-plugin`。

**OC — 唯一有真正脚手架的一家**

```bash
# 1. 一条命令生成整个工程（tool / provider / feature 三种模板）
openclaw plugins init stock-quotes --name "Stock Quotes" --type tool
cd stock-quotes
# 产物：package.json  src/index.ts  src/index.test.ts  README.md
#       openclaw.plugin.json  tsconfig.json  vitest.config.ts
# 2. 安装依赖 + 构建清单 + 校验
npm install
npm run plugin:build      # 生成/刷新 openclaw.plugin.json
npm run plugin:validate   # 契约校验
# 3. 本地开发用软链接，改源码免重装
openclaw plugins install -l ./stock-quotes
openclaw plugins reload stock-quotes     # 改源码/manifest 后需显式 reload
# 4. 发布到 ClawHub
clawhub package publish your-org/stock-quotes
```

生成的首个工具就是可运行的 `echo` 示例（`defineToolPlugin` + TypeBox schema）（*plugins-authoring-command.ts:367-395*）；`openclaw.json` 里的配置改动在默认 `hybrid` 模式下**自动热生效**，只有源码/manifest 改动才需要 `reload`（*docs/plugins/manage-plugins.md:284-312*）。

**HM — 四文件手写 + 真运行时验证器**

```bash
# 1. 建目录（自己建）
mkdir -p ~/.hermes/plugins/calculator
# 2. 手写四个文件
#    plugin.yaml（name/version/provides_tools/provides_hooks）
#    __init__.py（register(ctx)：把 schema 绑到 handler）
#    schemas.py（LLM 可见的 description + parameters）
#    tools.py（真正执行的 calculate / unit_convert）
# 3. 用真实发现路径验证（走真 register(ctx)，临时 HERMES_HOME + 断网）
hermes plugins doctor . --ci
# 4. 启用并重启生效（Python 工具与 prompt 段延迟到下一会话）
hermes plugins enable calculator
```

没有 `hermes plugin create`；`plugins` 的 16 个子命令（install/search/validate/adopt/pack…）里**没有 create/new/init**（*hermes_cli/subcommands/plugins.py:10-191*）。隔离档位不是插件作者能选的——由运维侧 `config.yaml` 的 `plugins.isolation` 决定，插件只能被静态审计告知"能不能跑在 host"（*config_defaults.py:1731-1740；plugin_isolation_audit.py:182-216*）。

**ASR — plugingen 默认生成 L3 进程隔离轨独立工程**

```bash
# 1. 一条命令生成（默认 --mode process，即 L3 进程隔离轨）
cjpm run --name magic.plugin.tools.plugingen -- --name my_tool --table my_table
# 可选：--mode sync（编译进宿主） / --mode dylib（L2 动态库）
# 2. 产物（skills/my_tool/）
#    SKILL.md   plugin.yaml   cjpm.toml   README.md
#    src/main.cj   src/MyToolHandlers.cj   src/MyToolEffects.cj
# 3. 插件工程是独立 cjpm executable，可单独编译
cd skills/my_tool && cjpm build && cd ../..
#    → skills/my_tool/target/release/bin/skill_my_tool.exe
# 4. 宿主发现：60s 周期 reconcile 自动加载，或手动
cjpm run --name ...   # plugin_refresh 工具（LLM 亦可调用）
#    宿主侧：PLUGIN_RECONCILE_INTERVAL_SECONDS 默认 60s
```

三轨对开发者的实际含义：**Sync** 进宿主编译图（改一行要重编宿主，实测整编约 51 分钟）；**Dylib** 编 `.so` 由 `PackageInfo.load` 热加载（不重编宿主）；**Process** 编独立 exe，只能经 7 个 `host.*` 代理服务（`host.db/log/cache/mcp/event/db_schema_lookup/secret`）访问宿主，且受 `tableWhitelist` 约束、`stdout` 是协议通道必须 `eprintln` 打日志（*plugin_config.cj:13-38；cordis_host_services.cj:72-80*）。

> 💡 **四家一句话总结**：DSH = *文档最厚、工具最少*；OC = *工具最全、契约最严*；HM = *验证最真、起步最手工*；ASR = *生成最狠（直接给你一个可独立编译的工程）、测试最空*。若只抄一条，就抄 OC 的"脚手架自带最小测试"——这是把第三方作者从"能装"推到"敢改"的最短路径。

---

## 7. 成熟度校正评分

> 图例：DSH = deepseek-harness，OC = openclaw，HM = hermes-agent，ASR = agentskills-runtime（ASR）。字符条 █ 表示得分占比（满分 5）。

### 7.1 设计完备度（看"想到了没有"，不看工程量）

| 维度 | DSH | OC | HM | ASR |
|---|---|---|---|---|
| D1 插件形态 | █████ 5 | ████░ 4 | ████░ 4 | ████░ 4 |
| D2 清单/版本契约 | █████ 5 | ████░ 4 | ████░ 4 | ██░░░ 2 |
| D3 发现/加载 | █████ 5 | ████░ 4 | ████░ 4 | ███░░ 3 |
| D4 隔离模型 | ██░░░ 2 | ██░░░ 2 | █████ 5 | █████ 5 |
| D5 通信/IPC | ██░░░ 2 | ███░░ 3 | █████ 5 | ████░ 4 |
| D6 生命周期/DI | █████ 5 | ███░░ 3 | ████░ 4 | ███░░ 3 |
| D7 扩展点覆盖 | █████ 5 | █████ 5 | ████░ 4 | ████░ 4 |
| D8 权限/安全 | ███░░ 3 | ████░ 4 | █████ 5 | ██░░░ 2 |
| D9 分发/治理 | █████ 5 | ████░ 4 | ███░░ 3 | ██░░░ 2 |
| D10 开发体验 | █████ 5 | ████░ 4 | ████░ 4 | ██░░░ 2 |
| D11 开发者支持 | ████░ 4 | █████ 5 | ███░░ 3 | ████░ 4 |
| D12 原生智能/自进化 | ███░░ 3 | █████ 5 | ████░ 4 | █████ 5 |

### 7.2 落地成熟度（看"做出来没有 + 生态规模"）

| 维度 | DSH | OC | HM | ASR |
|---|---|---|---|---|
| D1 插件形态 | ████░ 4 | █████ 5 | ████░ 4 | ███░░ 3 |
| D2 清单/版本契约 | ████░ 4 | █████ 5 | ████░ 4 | ██░░░ 2 |
| D3 发现/加载 | ████░ 4 | █████ 5 | ████░ 4 | ███░░ 3 |
| D4 隔离模型 | ███░░ 3 | ██░░░ 2 | ████░ 4 | ██░░░ 2 |
| D5 通信/IPC | ██░░░ 2 | ███░░ 3 | ████░ 4 | ██░░░ 2 |
| D6 生命周期/DI | ████░ 4 | ████░ 4 | ████░ 4 | ███░░ 3 |
| D7 扩展点覆盖 | ███░░ 3 | █████ 5 | ████░ 4 | ███░░ 3 |
| D8 权限/安全 | ██░░░ 2 | ████░ 4 | ████░ 4 | ██░░░ 2 |
| D9 分发/治理 | ████░ 4 | ████░ 4 | ███░░ 3 | ██░░░ 2 |
| D10 开发体验 | ████░ 4 | ████░ 4 | ████░ 4 | ██░░░ 2 |
| D11 开发者支持 | ████░ 4 | █████ 5 | ███░░ 3 | ██░░░ 2 |
| D12 原生智能/自进化 | ██░░░ 2 | ████░ 4 | ████░ 4 | ████░ 4 |

> ⚠️ **怎么读这两组分数**：deepseek-harness 在"设计完备度"上领先，但它是 alpha、自述未审计；openclaw 在"落地成熟度"上领先，因为它的设计是"够用即可 + 大规模铺量"。ASR 的**设计完备度不低**（三轨、tableWhitelist、plugin+SKILL 三维一体、状态机、**确定性代码生成工具链（代码腿）**都是真设计），但**成熟度受两个硬约束拖累**：仓颉工具链限制（cjpm workspace/package 互斥、LTO 剪除、动态库符号冲突）和项目阶段。把这两组分开看，才能避免"用成熟度否定设计"或"用设计掩盖没做完"。

> 💡 **新增两维（D11 / D12）的读法**：D11 里 ASR 拿到设计 4 / 成熟 2 的**落差分**——plugingen 能一键生成可独立编译的 L3 工程（设计上是四家里唯一敢把"最安全那轨"设为默认的），但模板不带测试、没有插件侧校验器、权威文档躺在 `.codeartsdoer/specs/` 隐藏目录里，第三方作者实际用不起来。D12 的分水岭在第二层——OC 让模型自写技能且后台自动评审、HM 有完整技能层闭环但契约禁止动代码、ASR 独辟"代码腿"（确定性工具链实际演进框架代码）、DSH 则完全没有这条链路。ASR 在"自进化能不能碰代码"上是四家里唯一突破"技能文本层"的：它把 RSI 做成 code+skill+database 三腿闭环，由确定性代码生成工具承载代码演进（设计 5 / 成熟 4）；其唯一待补的是 DB 腿（UMI-ORM 未完整）与"每 N 轮后台自评"的常驻触发。

---

## 8. 根因解读：为什么它们如此不同

看完十二维度会有个疑问：同样是"Agent 框架的插件机制"，为什么能差这么多？答案不在设计品味，在**三个硬约束**：

**约束一：语言与运行时——决定论级别的影响**

| 语言特性 | 带来的能力 | 失去的能力 |
|---|---|---|
| TypeScript / Node（DSH、openclaw） | 运行时 import、模块热替换、Proxy 拦截 ctx、动态对象图 | 无法做真正的进程隔离（除非显式起子进程/Worker） |
| Python（hermes） | entry-point 组、运行时 import、丰富的动态能力 | 同左；GIL 使"进程内多插件"并发受限，反而推动它做进程隔离 |
| 仓颉（agentskills-runtime） | 原生二进制、类型安全、跨平台单一产物 | **HMR 基本不可能**；LTO 剪除未引用类 → 需反射锚点；动态库需 `--dy-std`；workspace/package 互斥 |

agentskills-runtime 的 spec 里把这三条写得非常直白（限制 #1/#3/#4/#5），并逐条对比了"与 DSH 的差距"。**这种把自家短板写成正式文档的态度，本身就是工程成熟度的体现**——比粉饰报告有价值得多（*spec.md §0.2*）。

**约束二：部署形态**

- DSH 是**开发者本机工具**（CLI + Desktop + Web），所以"审批 + 告知风险"够用，不需要强隔离。
- hermes 明确要支持**池化部署**（一个进程服务多 profile），所以必须有进程隔离——这直接决定了它的双档设计。
- openclaw 要接 180 个外部集成（大量是 model provider），稳定性靠"契约 + 清单"而非隔离。
- agentskills-runtime 定位含**插件市场**（v1.0 基础设施 / v1.1 上线），要跑第三方二进制 → 必须有 L3 进程轨。

**约束三：生态冷启动策略**

四家对"谁来审核插件"给出了四种答案：DSH = 用户自己批准；openclaw = 安装时能力比对 + 用户确认；hermes = 机器探针验证声明一致性 + MCP 走 PR 人工评审；agentskills-runtime = 目前主要靠自带 skills 目录。**没有对错，只有阶段适配**——市场为空时 PR 评审最稳，规模上来后必须自动化。

---

## 9. 对 ASR（agentskills-runtime）的启示

基于上面的实证对比，按**性价比排序**给出建议（先做收益最大、成本最低的）：

| 优先级 | 建议 | 借鉴自 | 理由 / 预期收益 |
|---|---|---|---|
| 🔴 P0 | **给 Dylib / Process 两轨补版本协商**（pluginApi range + 宿主版本 range，不符拒绝加载） | openclaw `openclaw.compat.pluginApi`；DSH peer 校验 | ABI 不兼容在原生二进制下是**段错误**而非异常，风险远高于动态语言。这是 L2/L3 启用前的**硬前置**。 |
| 🔴 P0 | **L3 进程启动后做"能力宣告握手"**：插件上报将注册的 Service/Route，宿主与 plugin.yaml 声明比对，不符拒绝挂载 | hermes 能力探针 `_check_capabilities` | 二进制插件用户无法审查，声明一致性必须由机器验证。成本是一次握手，收益是防住"偷偷多注册"。 |
| ⚠️ P1 | **把 `tableWhitelist` 扩成通用能力清单**（网络出口、文件、子进程、环境变量…），缺省全拒 | openclaw `capabilities`；hermes 多维校验 | 目前只管 DB 表，是最窄的一家。L3 轨一旦跑第三方代码，覆盖面必须补齐。 |
| ⚠️ P1 | **公开声明"哪些能力不能跨进程"**（对应 hermes 的 `HOST_UNSUPPORTED_CTX_METHODS`），并让静态审计复用同一张表 | hermes `plugin_isolation.py` | 避免"审计说安全"和"实际能加载"漂移。runtime 已有 cordis-cj 集成，这张表是 L3 推广时的必需品。 |
| 🔵 P2 | **用依赖推导替代 `order` 数字排序**（插件声明所需 Service，由注册表拓扑排序） | DSH `inject` + PENDING | 51 个 skill 时 `order` 够用，规模上去了必然维护失控。DSH 已证明这条路可行。 |
| 🔵 P2 | **给 L3 轨加崩溃自愈的可观测性**（重启次数、退避策略、崩溃原因上报） | DSH install 状态机；hermes generation 代次 | `autoRestart: true` 已有，但缺"重启风暴"防护——一个启动即崩的插件会无限重启。 |
| ⚠️ P1 | **plugingen 模板自带一个"跑得起的最小测试"，并补独立 `plugin validate`** | openclaw `plugins init` 生成 `index.test.ts` + `vitest.config.ts`；hermes `plugins doctor` 走真运行时验证 | D11 是四家里 ASR 设计分与成熟分落差最大的一项（4 / 2）。生成器已经很强，缺的恰恰是"让第三方作者敢改"的那一步——一个模板自带的测试 + 一条校验命令，成本极低、收益极高。 |
| ⚠️ P1 | **把 RSI 三腿闭环从"工具就绪"推进到"常驻自进化循环"：补"每 N 轮后台自评"触发 + 将确定性代码腿接入 LRT 五环节** | openclaw `skills.workshop.autonomous.mode: auto`（累计 N 轮后台自评）；hermes `background_review` 每轮后 fork 自评 | ASR 的**代码腿工具链（loaddbinfo / crudgen / crudweb / plugingen / pluginuninstall）已就绪且生产可用**，LRT 五环节（实测→根因→优化→防回退→约束注入）也已在 `src/app/services/lrt` 落地；当前缺口是**把这些确定性能力串成一个"每 N 轮无条件后台自评"的常驻循环**（目前多在长程任务失败时或按需触发）。OC/HM 的做法是"每 N 轮后台自评一次"——把自进化从"出错才修"变成"常态沉淀"，是 D12 里最该补的一档分。 |
| ✅ 保持 | **plugin + SKILL.md 三维一体**、**三轨 mode 声明**、**"代码腿"确定性自进化（loaddbinfo / crudgen / crudweb / plugingen / pluginuninstall）**、**spec 里诚实标注限制条款** | — | 这四项是 ASR 的**真实差异化优势**，四家里独一份 —— 尤其"以确定性代码生成工具承载框架自进化"这条路线，是 DSH / OC / HM 三家都没有的（它们把自进化锁死在技能文本层）。这是 RSI 议题上最值得对外讲的一点，也是其"AI 驱动开发框架"定位的硬核支撑。 |

> 🔴 **最需要正视的一条**：agentskills-runtime 的 Sync 轨"改一行要重编宿主（约 51 分钟）"，这在开发体验上是四家里**最差**的，且短期无法通过设计优化根治（静态语言决定的）。**但这一点 ASR 已用工程与规范落地化解，而非停在建议层**：开发者插件生成工具 `plugingen` 的缺省轨就是 **L3 process**（`plugingen.cj:48` 写死 `var mode = "process"`），`sdd` / `uctoo-dev-manual` 技能与《模块开发规范》SOP 更明文要求"**能做成插件就做插件**"、宿主 `src/app/` 存量模块"**存量冻结、只减不增**"（*sdd/SKILL.md:285,397,414；uctoo-dev-manual/SKILL.md:70,353；feasibility.md 附7.9；design.md §1.0；tasks.md(AgenticSoftwareFactoryHackathon):17*）。亦即**新扩展一律走 L3 插件、Sync 轨仅留给无法解耦宿主的极少数存量能力**——三轨设计的价值不仅没有被默认档抵消，反而因"**默认即最安全那轨 + 宿主冻结**"成为 ASR 的真实差异化（呼应 §D11：四家里唯一敢把最安全轨设为默认）。**真正剩下的硬前置**是 L2/L3 正式对外跑第三方二进制前必须补齐的 **ABI / pluginApi 版本协商、L3 能力宣告握手、崩溃自愈可观测性**（见 §风险与对策），而不是"是否该把默认档切到 L3"。

---

## 10. 拓展 AgentSkills 标准的定位：拓展 vs 创新

本报告第 3、7、9 章已记录 ASR 在 D7「一切皆技能」维度上的事实——**拓展 AgentSkills 开放标准支持仓颉静态二进制发布**、**plugin + SKILL.md 三维一体**、**三轨 mode 声明**。本节把"这到底算不算对 AgentSkills 标准的拓展与创新"做一个明确的定位判断，供对外叙事（赛事 / 文档 / 论文）引用。

### 10.1 结论速览

| 判断项 | 结论 | 成立条件 |
|---|---|---|
| 是否"拓展" | ✅ 是，站得住 | 保留 `SKILL.md + scripts/` 开放契约不变，在执行底座上**新增一条"静态编译原生二进制"轨道**，这是原生标准没有预见的。 |
| 是否"创新" | ⚠️ 是，但需正确表述 | 创新点是**组合架构**，不是"多支持了一门语言"；单说"支持了仓颉"只是增量，不构成创新。 |

### 10.2 为什么"拓展"成立

原 AgentSkills 标准（deepseek-harness 那条线）的技能脚本是**运行时解释执行**的——JS 走 `node:vm` eval、Python/TS 走解释器，隐性假设"技能源码是可读、可即时运行的文本"。ASR 做的事是：

- 保留 `SKILL.md + scripts/` 契约不变；
- 在执行底座上**新增仓颉轨**：先 `cjc --output-type=dylib` 编译成 `.so/.dll/.dylib`，再用 `PackageInfo.load()` 反射加载、运行时实例化（见 `cangjie-plugin-system-feasibility.md` 第 146、153、805 行）。

这条轨道是原生标准**没有预见到**的：原标准从没要求宿主具备"编译 + OS 动态链接 + 反射实例化"的能力。所以"拓展"用得对——扩的是**执行 substrate**，不是另起炉灶。

### 10.3 "创新"成立靠的是组合拳，不是单点

真正算创新、值得写进赛事叙事的有四点（已在本文 D7 维度记录证据）：

1. **静态二进制作为一等公民技能**：把静态编译语言做成 AgentSkills 兼容框架里的"技能/插件"，而非"调个外部进程"。
2. **三轨隔离 `mode` 写进清单一等公民**（`sync | dylib | process`）：四家里唯一把隔离档位写成清单字段的，且是静态语言的刚需——编译进宿主 vs 动态库 vs 子进程，代价差一个数量级；DSH/hermes 是宿主全局开关，ASR 是**逐插件声明**。
3. **"三维一体"**：plugin + SKILL.md + scripts 统一。dsh 的"一切皆插件"是代码组织层面的统一；ASR 的"一切皆技能"是 **AI 可理解行为 + 可执行代码 + 可管理插件**的统一，维度高一层。
4. **闭源分发**：dylib 二进制可不开源，JS 必须可见（`feasibility.md` 第 1540 行）。对编译型语言是实打实的能力差。

> 🔴 **必须避开的坑**：单说"我们支持了仓颉这门静态语言"**不是创新**，只是"多支持一种语言"——Java SPI/ServiceLoader、OSGi、.NET MEF、原生 dylib 插件都是几十年前的东西。"动态库加载插件"是教科书操作，没人会为这个给一等奖。

### 10.4 对外叙事建议（克制、可落地）

不要写"颠覆性创新""比 dsh 更原生智能"这类营销断言（本报告刻意未写入，保持客观）。建议定调为：

> 💡 **建议表述**：对 AgentSkills 开放标准的**务实拓展**：在保留 `SKILL.md` 契约的前提下，将静态编译型语言（仓颉）原生二进制纳入技能执行底座，并以"三轨隔离声明 + 框架插件机制与智能体技能机制三维一体融合"的架构，补上了动态脚本标准在**确定性、隔离粒度、闭源分发**上的空白。

真正能撑起"创新"叙事的，是 **RSI 主线**——"以系统工程的确定性消解 LLM 的不确定性"：静态编译 + System-1 决策引擎接管结构化决策，才是这套拓展背后**真正有别于"加一门语言"的原创贡献**。赛事材料里应把"支持仓颉"作为**论据**而非**论点**。

---

## 11. 附录：证据索引

| 证据位置 | 支撑的结论 |
|---|---|
| `deepseek-harness/docs/cordis-tutorial/01-first-plugin.md` | 插件三形态、cordis.yml 组合、并发挂载、顺序由依赖决定 |
| `deepseek-harness/docs/cordis-api/fiber.md` | Fiber 状态机、effect 逆序清理、restart/update、EffectMeta 诊断 |
| `deepseek-harness/docs/cordis-api/service.md` | Service 注册为 ctx.\<name\>、Service.init/check/config/invoke 符号键 |
| `deepseek-harness/docs/cordis-tutorial/06-composition-and-hmr.md` | id/disabled/isolate、HMR、PENDING 诊断 |
| `deepseek-harness/packages/boot/plugin-manager/README.md` | 多 registry 回退、失败回滚、peer 校验、版本豁免、build script 审批、in-process 明示 |
| `deepseek-harness/packages/extensions/cordis-host-runner/README.md` | 动态定义跑在 `node:vm` realm |
| `deepseek-harness/SAFETY.md` | 自述未安全审计、不保证隔离、开发者预览 |
| `openclaw/packages/plugin-package-contract/src/index.ts` | `openclaw.compat.pluginApi` / `openclaw.build.openclawVersion` 必填校验 |
| `openclaw/extensions/a2a/openclaw.plugin.json` | 扩展清单实样（id/categories/activation/channels/configSchema） |
| `openclaw/src/plugins/bundle-manifest.ts` | 多格式清单（agent/codex/claude/cursor）、capabilities 字段、256KB 限制 |
| `openclaw/src/plugins/capability-consent.ts` | 安装期能力同意（reviewToken、声明面比对、官方快速通道） |
| `openclaw/src/plugins/activation-planner.ts` / `catalog-discovery.ts` | 懒激活规划、ClawHub catalog 客户端 |
| `openclaw/packages/worker-runtime/src/*` | 任务池 / worker 生命周期（隔离的补充手段） |
| `hermes-agent/hermes_cli/plugin_isolation.py` | 双档隔离、HOST_UNSUPPORTED/SKIPPED/OBJECT_BASES 表、审计同源 |
| `hermes-agent/hermes_cli/plugin_host.py` | Channel、generation 代次、对象代理（_ObjectSlot/_object_proxy） |
| `hermes-agent/hermes_cli/plugins.py` | PluginManager/PluginContext、21 个 register_*、加载超时保护、后台发现 |
| `hermes-agent/hermes_cli/plugin_validate.py` | 能力探针 diff、内置工具冲突、依赖探测、安全扫描 |
| `hermes-agent/optional-mcps/airtable/manifest.yaml` | MCP 目录 PR 评审准入（"Presence = approval"） |
| `agentskills-runtime/src/plugin/plugin_config.cj` | 三轨 PluginMode、plugin.yaml 字段、tableWhitelist、httpRoutes |
| `agentskills-runtime/src/plugin/plugin_registry.cj` | register/get/getState/list/unregister/snapshot/restore |
| `agentskills-runtime/src/plugin/plugin_dylib_loader.cj` | L2 `PackageInfo.load` 热加载、`--dy-std` 约束 |
| `agentskills-runtime/src/plugin/cordis_host_manager.cj` | L3 JSON-RPC over stdio（UDS 不启用） |
| `agentskills-runtime/src/plugin/skill_bridge.cj` | plugin + SKILL.md 三维一体、registerPluginSkills |
| `agentskills-runtime/.codeartsdoer/specs/plugin-system/spec.md` §0.2 | 六条限制条款 + 逐条"与 DSH 的差距"（本报告多处引用） |
| **— D11 开发者支持（本版新增）—** | |
| `deepseek-harness/apps/cli/src/plugin.ts:70-107` | `dsh plugin` 是 pnpm 转发器，无 create/scaffold/init；仅三个版本豁免子命令 |
| `deepseek-harness/docs/cordis-tutorial/*`（7 章） | DSH 的实际起步方式：手抄代码 + `node --import tsx ../../vendor/cordis/bin.js` |
| `deepseek-harness/packages/test-support/agent-loop-testkit` / `loader-smoke` | 真实栈测试脚手架（非对外 SDK）；`docs/testing.md` 的 HMR-safety 强制契约 |
| `openclaw/src/cli/plugins-authoring-command.ts:339-423,716-753` | `plugins init` 三种模板与 7 个生成文件（含 index.test.ts + vitest.config.ts） |
| `openclaw/docs/plugins/sdk-testing.md:22-44` | 15 个 SDK 公开测试子路径；`src/plugins/contracts/*.contract.test.ts` 契约测试 |
| `hermes-agent/hermes_cli/plugin_dev.py:31-61,370-432` | `plugins doctor` 走真实发现 + 真实 register + 临时 HERMES_HOME + 断网；自陈"not a plugin test framework" |
| `hermes-agent/website/docs/developer-guide/plugins/index.md:273-295` | HM 起步方式：手工建目录 + 手写四文件 + doctor + enable（需重启） |
| `agentskills-runtime/src/plugin/tools/plugingen/plugingen.cj:48` | `var mode = "process"` —— 默认生成 L3 进程隔离轨 |
| `agentskills-runtime/src/plugin/tools/plugingen/PluginGenerator.cj:296-395` | process 轨产物清单与生成的 cjpm.toml（`output-type = "executable"`，独立工程） |
| `agentskills-runtime/src/plugin/cordis_host_services.cj:72-80` | Process 轨仅 7 个 `host.*` 代理服务 + `tableWhitelist` 约束 |
| **— D12 原生智能 / 自进化（本版新增）—** | |
| `deepseek-harness/packages/core/tools/src/index.ts:857` | `ctx.systemPrompt.tools(...)` 一行打通全部工具到 prompt（赋能层主证） |
| `deepseek-harness/packages/boot/plugin-manager/src/tools.ts:84-109` | `plugin_manager` 让模型装/启停插件；需 `danger-full-access` 审批 |
| `deepseek-harness/packages/extensions/tool-cordis/README.md:12,28` | `cordis_inspect_*`：模型写插件前自省宿主 API（AST 生成 catalog，只读） |
| `deepseek-harness/packages/experimental/tool-ralph/README.md:61,161` | DSH 最接近 RSI 的形态，但明确拒绝模型改写自身循环、且无独立验证器 |
| `openclaw/src/agents/tools/skill-workshop-tool.ts:281,305` | `skill_workshop` 8 动作；写操作强制"先 view 再改"，create 提示合并去重 |
| `openclaw/docs/tools/self-learning.md:12,28-44` | 后台自动评审默认开启（`auto`），累计 10 轮排队、空闲 30s 后跑 |
| `openclaw/src/agents/tools/plugins-reload-handoff.ts:30-38` | `reloadAndResume`：模型改插件→重载→同一会话续跑 |
| `openclaw/src/skills/loading/skill-contract.ts:98-128`；`system-prompt-skills.ts:3-37` | `<available_skills>` 只放 name/description/location；`Up-front max one` 硬限 |
| `hermes-agent/agent/background_review.py:1-6,1088-1128` | 每轮后 fork AIAgent 自评写 memory/skill；写工具只有 `skill_manage`，write/patch/terminal 全拒 |
| `hermes-agent/tools/skill_manager_tool.py:862-928` | `skill_manage` = procedural memory（create/patch/write_file/remove_file/delete） |
| `hermes-agent/website/docs/developer-guide/plugins/index.md:221-228` | 兼容性契约明文禁止运行时改写核心，Catalog 准入拒收 |
| `agentskills-runtime/src/skill/skill_to_tool_adapter.cj:28-50` | SKILL.md frontmatter → LLM Tool 的 name/description 直映射（一切皆技能） |
| `agentskills-runtime/src/skill/parallel/*` | 多技能并行执行基底（预算分配 / 冲突过滤 / 注入决策记录） |
| `agentskills-runtime/src/app/services/webmcp/WebMCPProtocol.cj:2303-2311` | 创建并注入 `SkillAutoInjector`：阶段一 always_on 注入 + 阶段二 `injectOnUserMessage` 任务匹配自动注入；此即 webmcp/mcp 聊天链路的实际实现 |
| `agentskills-runtime/src/skill/parallel/skill_auto_injector.cj:43,126` + `skill_context_injector.cj:47,134` | `SkillAutoInjector` 自动注入器调用 `SkillContextInjector`：`injectOnInitialization`（always_on 技能）/ `injectOnUserMessage`（`TaskMatcher` 任务匹配）自动注入完整 instructions，含依赖闭包 / 互斥过滤 / 预算降级 |
| `agentskills-runtime/src/tool/get_skill_content_tool.cj:46,121` | `get_skill_content` 现为**向后兼容兜底**：`setAutoInjector` / `isSkillInjected` 去重，已自动注入的技能返回缓存内容 |
| `agentskills-runtime/src/app/tools/{loaddbinfo,crudgen,crudweb}` | **确定性代码腿**：数据库结构注入 → 五层 CRUD 代码确定性生成（必定可编译） |
| `agentskills-runtime/src/plugin/tools/{plugingen,pluginuninstall}` | 插件确定性生成（默认 L3 process 轨独立工程）/ 三层卸载 |
| `agentskills-runtime/src/app/services/lrt/*` | LRT 五环节（实测→根因→优化→防回退→约束注入）自进化闭环，"验证即闸口" |
| `agentskills-runtime/docs/ref/AIDrivenArchitecture.md` | "确定性优先，AI 增强"分层协作原则：以系统工程的确定性消解 LLM 的不确定性 |
| `agentskills-runtime/specs/RSI/research.md` | RSI 三腿闭环（技能/代码/数据库）研究：确定性代码腿是相对 harness 的根本差异 |

---

> **报告说明**
> - 本报告全部结论来自四个仓库的**本地源码实证**（路径与行号见附录），未使用外部资料或记忆推断。
> - 文档与代码冲突时以代码为准；无法确证处已在正文中显式标注为推断或不适用。
> - 评分为基于公开源码的相对判断，不代表项目整体优劣——四个项目定位、阶段、部署形态各不相同，横向分数仅用于定位机制差异。
> - 生成日期：2026-10-17。
