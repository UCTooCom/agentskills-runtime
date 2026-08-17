# 鸿蒙仓颉动态特性、Agent DSL 与插件机制综合分析

> 研究对象：仓颉静态语言如何支撑鸿蒙APP的动态特性、Agent DSL 的适用场景、仓颉-ArkTS互操作对插件机制的启示
> 依据：鸿蒙编程语言白皮书 V2.0（2026-06-08）+ 仓颉官方文档 + ChatUI项目源码 + Cangjie-ArkTS互操作开源代码 + 网络公开资料
> 分析日期：2026-08-17
> 前置报告：《仓颉版插件系统可行性研究报告》（cangjie-plugin-system-feasibility.md）

---

## 摘要（先说结论）

1. **仓颉作为静态语言开发鸿蒙APP，动态特性通过五条路径实现**：宏（编译期代码生成）、包按需加载、反射、ArkTS互操作（借动态语言的能力）、以及官方文档确认的 `ModuleInfo.load()` / `PackageInfo.load()` 运行时动态加载API。静态语言并非"不能动"，而是"动的路径不同"。

2. **Agent DSL 是编译期 eDSL（内嵌DSL），不是运行时动态机制**。它通过 `@agent` / `@prompt` / `@tool` 宏在编译期生成代码，适合"Agent结构已知、运行时只需调用"的场景。agentskills-runtime 从 AGENTS.md 等文件动态加载编排是数据驱动方案，两者正交互补，不矛盾。

3. **仓颉-ArkTS 互操作是插件系统的重大利好**：ArkTS（动态语言）的模块按需加载 + Cangjie 对 ArkTS 的运行时调用（`context.requireArkModule()`），为仓颉插件系统提供了一条"借道动态语言"的运行时插件通道——不用 dlopen 也能运行时加载新功能。

4. **重大更正**：前报告判断"仓颉无运行时加载新代码能力"是错误的。仓颉标准库提供 `ModuleInfo.load()` / `PackageInfo.load()` 可在运行时加载 `.so` 仓颉动态库并反射访问类型、全局变量、函数。L2 形态的可行性从"⚠️ 需实证"上调为"✅ 有官方API支撑"。

---

## 一、仓颉如何满足鸿蒙APP的动态特性

### 1.1 白皮书的定位

鸿蒙编程语言白皮书 V2.0 第一章明确：鸿蒙是多编程语言生态，ArkTS（动态类型）和仓颉（静态类型）是两大主力语言，各有所长：

> "对于动态更新业务场景、与TS/JS高效互通场景、快速构建等场景建议优先选择ArkTS；对于高吞吐量/高频读写的数据处理场景、高频交互高负载场景、启动时延敏感等场景建议优先选择仓颉。"

白皮书的立场很清楚：**动态性需求大的场景用ArkTS，性能需求大的场景用仓颉**。两者通过互操作协作。

### 1.2 仓颉实现"动态"的五条路径

从白皮书和官方文档逐条核对，仓颉作为静态语言，通过以下五条路径满足APP的动态需求：

| # | 路径 | 原理 | 动态程度 | ChatUI项目中的体现 |
|---|---|---|---|---|
| 1 | **宏（元编程）** | 编译期分析/变换/生成代码，引入新语法和领域行为 | 编译期"动态"——生成你手写不出来的代码 | `@Entry` / `@Component` / `@State` / `@Builder` 宏生成声明式UI代码 |
| 2 | **包按需加载** | 仓颉以包为粒度组织代码，支持包级按需加载 | 运行期延迟加载，但包须编译期确定 | cjpm.toml `output-type = "dynamic"`，编译为 .so 动态库 |
| 3 | **反射** | 运行时获取类型信息、读写成员、调用函数、动态实例化 | 运行期"检视+调用"，类型须编译期存在 | 白皮书未直接展示，但官方文档 `TypeInfo.of()` / `ClassTypeInfo` / `ConstructorInfo.apply()` |
| 4 | **ArkTS互操作** | 仓颉通过 `ohos.ark_interop` 库调用ArkTS动态模块 | 运行期加载动态语言模块——**借道动态语言实现真动态** | `context.requireArkModule("模块名")` 加载NAPI/ABC模块 |
| 5 | **ModuleInfo.load / PackageInfo.load** | 仓颉标准库API，运行时加载 .so 仓颉动态库并反射访问 | **运行期加载新代码**（真正的动态加载） | 官方文档示例：`PackageInfo.load("path/libmyPackage")` |

### 1.3 ChatUI项目源码分析

ChatUI项目（05-ChatUI）是一个纯仓颉编写的鸿蒙聊天界面APP，展示了仓颉在移动端的典型用法：

**项目结构**：
- `entry/src/main/cangjie/` — 仓颉源码目录
- `cjpm.toml` — 仓颉包管理配置，`output-type = "dynamic"`（编译为.so动态库）
- `src/main/module.json5` — 鸿蒙模块配置

**动态特性体现**：

1. **声明式UI（宏生成的"动态"UI）**：
   ```cangjie
   @Entry
   @Component
   class IndexView {
     @State var activeInd: Int64 = 0  // 状态管理，UI自动响应
     func build() {
       if (activeInd == 0) { ChatList() }      // 条件渲染
       else if (activeInd == 3) { FriendList() }
     }
   }
   ```
   `@State` 变量变化时，UI自动重渲染——这是宏在编译期生成的响应式代码，运行时表现如同"动态"。

2. **组件化与回调（编译期确定的动态行为）**：
   ```cangjie
   @Component
   public class ChatList {
     func privateChatOnClick(target: (Chat, User)) {
       CURRENT_CHAT.set(target[0])
       Router.push(url: "ChatView")  // 路由跳转
     }
   }
   ```
   `Router.push` 是运行时路由——页面跳转路径运行时决定，但目标页面编译期已注册。

3. **数据驱动渲染**：
   ```cangjie
   ForEach(privateChatDataSource, itemGeneratorFunc: {elem: (Chat, User), index: Int64 =>
     ListItem() { ChatListItem(src: elem[1].avatar, ...) }
   })
   ```
   `ForEach` 根据数据数组动态生成列表项——数据运行时变化，UI自动更新。

4. **全局状态存储**：
   ```cangjie
   public var CURRENT_CHAT: DataStore<Chat> = DataStore<Chat>(chat1)
   public var TARGET_USER: DataStore<User> = DataStore<User>(user1)
   ```
   全局可变状态，页面间通过引用传递——非响应式但运行时可修改。

**关键观察**：ChatUI中所有"动态"行为本质都是**编译期已知的结构 + 运行时变化的数据**。这正是静态语言做APP的标准模式——类型编译期确定，数据运行时流动。

### 1.4 白皮书揭示的未来动态能力增强

白皮书第三章"演进策略"明确规划了仓颉-ArkTS互操作的未来增强：

> "引入渐进/动态类型改进当前仓颉-ArkTS反射式互操作机制，在强类型框架下引入更具弹性的语法语义支持"
> - **非侵入式动态类型传播**：定义 Extern 类型作为中立的数据载体，保留动态语言灵活性的同时，防止外部不确定类型干扰仓颉静态检查
> - **自动化边界类型契约**：在赋值、传参及显式转换等关键交互边界建立自动化契约协议

这意味着华为官方正在规划让仓颉"在不牺牲静态安全的前提下获得更多动态能力"——这对插件系统是直接利好。

---

## 二、Agent DSL 的适用场景与 agentskills-runtime 的对比

### 2.1 Agent DSL 是什么

白皮书第二章"智能化"章节和仓颉官方文档明确：

> "仓颉通过元编程能力和DSL能力构建Agent DSL能力，兼顾细粒度控制与开放扩展，构建动态、意图驱动的AI计算范式。"

Agent DSL 是基于仓颉宏能力构建的**内嵌领域特定语言（eDSL）**，核心语法：

```cangjie
@agent [
  model: "deepseek:deepseek-v3.2",
  description: "鸿蒙应用内的智能日程助理",
  tools: [scheduleToolManager],
  executor: "react"
]
class ScheduleAssistant {
    @prompt("你是一个日程助理，负责理解用户需求，并生成规范的日程处理结果。")
}

let assistant = ScheduleAssistant()
let result = assistant.run("明天上午10点提醒我参加项目评审")
```

多Agent协同通过流式符号：
- 线性协同：`agent1 |> agent2 |> agent3`
- 主从协同：`agent1 <= [agent2, agent3]`
- 自由协同：`agent1 | agent2 | agent3`

### 2.2 Agent DSL 的本质：编译期eDSL

**关键判断：Agent DSL 是编译期机制，不是运行时动态机制。**

`@agent` / `@prompt` / `@tool` 是**宏注解**——在编译期：
1. 宏解析类定义和注解参数
2. 生成Agent基础设施代码（模型调用、提示词管理、工具注册、执行流程）
3. 生成的代码在运行时是一段"已固化的执行逻辑"

运行时不能"动态定义一个新Agent"——所有Agent类必须在源码中写好，编译期已知。

### 2.3 agentskills-runtime 的方案：数据驱动的运行时动态编排

agentskills-runtime 的方案是：
- 从 AGENTS.md 或 subagent 定义文件（数据文件）动态读取Agent配置
- 通过程序逻辑和数据库数据动态编排Agent行为
- 运行时可增删改Agent定义，无需重新编译

这是**数据驱动方案**——Agent结构是运行时数据，不是编译期代码。

### 2.4 两种方案的对比

| 维度 | Agent DSL（仓颉原生） | agentskills-runtime（数据驱动） |
|---|---|---|
| 定义方式 | 源码中 `@agent` 宏注解 | AGENTS.md / 数据库 / JSON等数据文件 |
| 生效时机 | 编译期 | 运行期 |
| 增删Agent | 需重新编译 | 修改数据文件即可 |
| 类型安全 | 编译期检查，类型安全最强 | 运行时校验，灵活但需自行保证安全 |
| 开发体验 | IDE自动补全、编译期报错 | 需要运行时才能发现配置错误 |
| 适合场景 | Agent结构固定、需高性能和高可靠 | Agent结构灵活多变、需运行时动态编排 |
| 业界对照 | 类似Android的注解框架 | 类似LangChain/AutoGen等Python动态方案 |

### 2.5 谁在用Agent DSL？

从公开资料看，Agent DSL 的用户群体主要是：

1. **鸿蒙原生应用开发者**：Agent DSL 是仓颉语言原生能力，开发鸿蒙智能应用（如日程助理、设备控制等）时，用 `@agent` 宏比手写模型调用+提示词+工具注册代码效率高得多。

2. **CangjieMagic框架用户**：基于仓颉开源的LLM Agent开发框架（gitcode.com/Cangjie-TPC/CangjieMagic），使用Agent DSL + MCP协议构建企业级Agent系统，已有文档问答、智能运维等实践案例。

3. **需要"声明式"开发体验的开发者**：从传统命令式编程转向声明式，Agent DSL让开发者只描述"做什么"，框架处理"怎么做"。

### 2.6 两种方案不矛盾，是正交互补关系

**agentskills-runtime 不用Agent DSL，不是因为Agent DSL没用，而是因为两者的适用场景不同。**

agentskills-runtime 作为一个**AI驱动开发框架**本身，需要：
- 运行时动态编排Agent（用户可以随时增删Agent配置）
- 框架使用者不需要写仓颉代码来定义Agent
- 数据库驱动的Agent配置和技能管理

Agent DSL 适合：
- 开发者写仓颉代码时，想快速定义一个"编译期已知的Agent"嵌入应用中
- Agent结构相对稳定，不需要运行时动态增删
- 追求编译期类型安全和性能

**两者的关系**：agentskills-runtime 是"框架层"（运行时动态编排），Agent DSL 是"语言层"（编译期声明式定义）。agentskills-runtime 管理的Agent定义文件中，如果某个Agent是仓颉代码写的（用`@agent`宏定义），那它就是Agent DSL写成的Agent被agentskills-runtime编排——两者可以组合使用。

---

## 三、仓颉-ArkTS互操作对插件机制的启示

### 3.1 互操作机制总览

白皮书第一章"语言互操作介绍"和开源代码（gitcode.com/openharmony/arkcompiler_cangjie_ark_interop）揭示了完整的互操作架构：

**ArkTS调用仓颉**：
```
ArkTS侧: import { addNumber } from "libohos_app_cangjie_entry.so"
          ↓
仓颉侧: @Interop[ArkTS] public func addNumber(a: Float64, b: Float64): Float64 { a + b }
          ↓ 宏自动生成
        - TypeScript声明文件 (.d.ts)
        - 桥接代码（参数转换 + 模块注册）
        - JSModule.registerModule 注册到ArkTS运行时
```

**仓颉调用ArkTS**：
```cangjie
let context = runtime.mainContext
let sysMod = context.requireArkModule("@ohos.usbManager").asObject()
let getDevices = sysMod["getDevices"].asFunction()
getDevices.call()  // 调用ArkTS模块函数
```

### 3.2 模块系统的动态特性

从开源代码分析（deepwiki.com/openharmony/arkcompiler_cangjie_ark_interop/2.4-module-system）：

- **JSModule.registerModule**：仓颉模块在编译时注册导出，运行时由ArkTS通过native require加载
- **ArkModuleHelper**：运行时验证和解析模块规范名
- **白名单机制**：KIT_CONFIGS / BUNDLE_MAP 控制仓颉可加载哪些ArkTS模块
- **配置生成工具**：构建时解析SDK .d.ts文件生成模块配置

**关键点**：ArkTS侧的模块加载是动态的（Node-API的require机制），仓颉通过`requireArkModule`可以在运行时按需加载ArkTS模块。这意味着**通过ArkTS互操作，仓颉可以获得"运行时加载新功能"的能力**。

### 3.3 对插件系统的具体应用

基于互操作机制，仓颉版插件系统可以设计出比纯静态方案更动态的形态：

#### 方案A：ArkTS动态插件桥（推荐探索）

**思路**：插件逻辑用ArkTS（动态语言）编写，编译为.abc字节码或NAPI模块，仓颉运行时通过`requireArkModule`动态加载。

```
插件开发者写ArkTS代码 → 编译为 .so/.abc → 部署到插件目录
                                           ↓
agentskills-runtime运行时 → context.requireArkModule("插件路径") → 调用插件函数
```

**优势**：
- 真正的运行时加载，不需要重新编译宿主
- ArkTS是鸿蒙生态首选语言，插件开发者基数大
- ArkTS有TS/JS生态，可直接复用npm包

**限制**：
- 插件接口需要通过JSValue/JSContext桥接，有跨语言开销
- 类型安全在边界处降级（JSValue是动态类型）
- 白名单机制限制了可加载的系统模块范围

#### 方案B：仓颉动态库加载（官方API支撑）

**思路**：用仓颉标准库的 `ModuleInfo.load()` / `PackageInfo.load()` 运行时加载仓颉.so动态库。

```cangjie
// 官方文档示例
let myPackage = PackageInfo.load("path/to/libmyPackage")
let at = TypeInfo.get("myPackage.MyPublicType")
let var0 = myPackage.getVariable("myPublicGlobalVariable0")
// 读写全局变量、调用静态函数、通过反射实例化类型
```

**这是对前报告的重大更正**：前报告判断"仓颉无运行时加载新代码能力"是错误的。仓颉标准库（`std.reflect`）提供：
- `ModuleInfo.load(path)` — 运行时加载仓颉动态模块
- `PackageInfo.load(path)` — 运行时加载仓颉动态包
- 加载后可通过 `TypeInfo.get("module/package.Type")` 反射访问类型
- 可读写全局变量、调用全局函数、通过 `ConstructorInfo.apply()` 动态实例化

**操作步骤**（官方文档示例）：
1. `cjpm init --type=dynamic --name myPackage` — 创建动态库模块
2. `cjpm build` — 编译为 `libmyPackage.so`
3. 运行时：`PackageInfo.load("path/libmyPackage")` 加载
4. `TypeInfo.get("myPackage.MyPublicType")` 获取类型信息
5. 反射读写变量、调用函数、实例化对象

**优势**：
- 仓颉原生方案，类型安全在仓颉侧保持
- 反射API完整（变量/函数/构造函数全覆盖）
- 插件与宿主同语言，无跨语言桥接开销

**限制**：
- 插件必须是仓颉编写（受众比ArkTS小）
- 加载后是否能卸载（dlclose）需实证
- 动态库依赖仓颉runtime，部署需保证版本兼容

#### 方案C：混合方案（最优解）

**思路**：仓颉定义插件接口和框架核心，ArkTS和仓颉动态库都可以作为插件实现。

```
┌─────────────────────────────────────────────────┐
│            agentskills-runtime (仓颉)              │
│  ┌─────────────────────────────────────────┐     │
│  │       PluginManager (仓颉核心)           │     │
│  │  - 插件注册表 / 生命周期管理 / 事件总线    │     │
│  │  - @Plugin 注解发现 + 反射实例化          │     │
│  └───────────┬──────────┬──────────────────┘     │
│              │          │                         │
│    ┌─────────┴──┐  ┌───┴──────────────┐         │
│    │ 仓颉动态库  │  │ ArkTS动态模块      │         │
│    │ (方案B)    │  │ (方案A)            │         │
│    │ PackageInfo │  │ requireArkModule  │         │
│    │ .load()    │  │ + JSValue桥接      │         │
│    └────────────┘  └────────────────────┘         │
└─────────────────────────────────────────────────┘
```

**这个方案让仓颉版插件系统同时具备**：
- 仓颉插件（高性能、类型安全，适合核心能力插件）
- ArkTS插件（动态加载、生态丰富，适合业务逻辑插件）
- AI驱动的Skill融合（仓颉侧SkillRegistry统一管理）

### 3.4 与Cordis插件机制的对照

| Cordis机制 | 仓颉版对应方案 | 动态程度 |
|---|---|---|
| `require()` 动态加载 | `PackageInfo.load()` 或 `requireArkModule()` | ✅ 运行时加载 |
| `ctx.inject()` 依赖注入 | 注解 + 反射实例化 + 显式注册表 | ✅ 运行时注入 |
| `ctx.effect()` 可逆副作用 | 逆序清理栈 | ✅ 运行时注册/卸载 |
| Proxy 动态属性 | `JSValue` 动态对象（通过ArkTS桥） | ⚠️ 需借道ArkTS |
| 事件合流性 | 幂等加载 + 注册表快照 | ⚠️ 工程近似 |

**关键结论**：通过ArkTS互操作 + 仓颉原生动态加载API，Cordis的大部分动态语义可以在仓颉中实现——不是纯仓颉实现，而是"仓颉骨架 + ArkTS动态层"的混合架构。

---

## 四、对前报告的更正

### 4.1 重大更正：仓颉有运行时加载新代码能力

前报告（cangjie-plugin-system-feasibility.md）第72行写道：

> "运行时加载新代码 | 无原生 dlopen API；反射只能查'编译链接时已存在'的类型 | 影响最大的一条"

**这是错误的。** 仓颉标准库 `std.reflect` 提供了：
- `ModuleInfo.load(path)` — 运行时加载仓颉动态模块
- `PackageInfo.load(path)` — 运行时加载仓颉动态包
- 加载后可通过 `TypeInfo.get()` 反射访问类型
- 可读写全局变量、调用函数、动态实例化

来源：仓颉官方文档 `docs.cangjie-lang.cn` 的"动态特性"章节和"动态加载的使用"章节。

### 4.2 更正后的L2可行性

| 形态 | 前报告结论 | 更正后结论 |
|---|---|---|
| L2 运行时插件 | ⚠️ 可行但需实证（dlopen + C ABI桥接） | ✅ **可行，有官方API支撑**（`PackageInfo.load()` + 反射） |

前报告的L2方案只考虑了"FFI声明dlopen + C ABI桥接"的路线，忽略了仓颉标准库自带的动态加载API。`PackageInfo.load()` 是仓颉原生的动态加载方案，加载后直接用反射操作仓颉类型，不需要C ABI桥接层。

### 4.3 不变的部分

以下结论不受影响，仍然成立：
- L1（注解+反射动态实例化）是仓颉原生最优解 ✅
- Cordis六大语义全部可仓颉化 ✅
- 插件=Service+Skill的神经系统设计 ✅
- 合流性无定理背书（工程近似） ✅

---

## 五、总结与建议

### 5.1 核心发现

1. **仓颉静态语言在鸿蒙APP中的动态特性**通过五条路径实现：宏生成、包按需加载、反射、ArkTS互操作、ModuleInfo/PackageInfo.load()动态加载。ChatUI项目展示了典型的"编译期结构 + 运行时数据"模式。

2. **Agent DSL是编译期eDSL**，适合"Agent结构已知"的声明式开发场景。agentskills-runtime的运行时动态编排方案与Agent DSL正交互补，不矛盾——前者是框架层动态编排，后者是语言层声明式定义，可以组合使用。

3. **仓颉-ArkTS互操作为插件系统打开了一扇大门**：ArkTS的动态模块加载 + 仓颉的运行时调用，构成了一条"借道动态语言"的运行时插件通道。混合方案（仓颉骨架 + ArkTS/仓颉动态库双通道插件）是最优解。

4. **前报告需更正**：仓颉标准库有 `ModuleInfo.load()` / `PackageInfo.load()` 动态加载API，L2形态可行性从"⚠️"上调为"✅"。

### 5.2 对agentskills-runtime的具体建议

1. **v1.0插件系统设计应纳入混合方案**：
   - 仓颉插件走 `PackageInfo.load()` + 反射实例化（类型安全、高性能）
   - ArkTS插件走 `requireArkModule()` + JSValue桥接（动态加载、生态丰富）
   - 两条通道统一由PluginManager管理

2. **Agent DSL不是必须用的**：agentskills-runtime作为框架，自身的Agent编排是数据驱动的。但如果用户想用仓颉写一个嵌入式Agent，可以用`@agent`宏，然后被框架编排——这是可选增强，不是必选项。

3. **白皮书预告的"渐进/动态类型"演进值得关注**：华为正在规划让仓颉在不牺牲静态安全的前提下获得更多动态能力（Extern类型、自动化边界类型契约），这将直接利好插件系统的类型安全与动态性的平衡。

4. **CORDIS对照更新**：有了`PackageInfo.load()`和ArkTS互操作两条动态加载通道，Cordis的"运行时加载新代码"语义在仓颉中可以做到真正的运行时加载，不再需要"重启进程"的妥协（至少在非鸿蒙APP场景下如此）。
