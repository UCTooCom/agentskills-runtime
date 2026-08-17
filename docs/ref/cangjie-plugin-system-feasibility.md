# 仓颉版插件系统可行性研究报告

> 研究对象：在 agentskills-runtime（仓颉语言实现）上建设运行时插件系统，支撑"插件 + Skills 融合"（智能插件连接神经系统）规划
> 前置报告：《Cordis 插件机制 vs npm 插件机制：全面对比分析》（docs/ref/cordis-vs-npm-plugin.md）
> 分析日期：2026-08-17
> 依据：仓颉官方文档（宏/反射与注解/FFI/CJC/部署运行）逐条核对，非凭印象

---

## 摘要（先说结论）

**仓颉版插件系统完全可行，但形态与 Cordis（TypeScript 动态语言）必然不同：静态语言走"编译时注册 + 运行时配置"双阶段路线。**

一句话总结三种形态的可行性：

| 形态 | 一句话结论 | 可行性 |
|---|---|---|
| L0 代码内插件（接口 + 多实现 + 配置选择） | 现有 MemoryProvider 已是此形态，最成熟 | ✅ 已验证 |
| L1 编译时插件（注解 + 反射动态实例化） | 仓颉原生最优解，官方反射 API 完整支持 | ✅ 可行 |
| L2 运行时插件（动态库 / WASM 沙箱） | **已更正**：仓颉标准库有 `PackageInfo.load()` 动态加载API + ArkTS互操作 `requireArkModule()` 双通道，WASM 留 v1.1+ | ✅ 可行（有官方API支撑） |

**核心判断（对应 Cordis 报告 §6.2 的预判，本次逐条验证成立）：**

1. **Cordis 的"Context 是 Proxy"等动态魔法在仓颉中做不了**——仓颉没有 Proxy/原型链/动态类型。但**服务定位、依赖注入、可逆卸载、事件分发这些语义全部可以用显式注册表 + 逆操作栈实现**，语义等价，实现路径不同。
2. **仓颉反射 API 恰好覆盖插件系统的关键环节**：`ClassTypeInfo.get("模块.包.类型")` 按名查类型、`ConstructorInfo.apply(args)` 动态实例化、`findAnnotation<T>()` 按注解发现插件——官方文档白纸黑字，L1 形态的"运行时发现 + 实例化"闭环完整成立。
3. **"Agent 检视/试运行/撤回插件"的自引用能力（dsh tool-cordis 的灵魂）在仓颉下退化为"进程内插件注册表的检视/启用/停用"**——不能运行时加载新代码，但能运行时激活/停用编译期已注册的插件。对"自进化"而言，这仍是有效的试错通道（成本从"重启进程"降到"一次注册表操作"）。
4. **"插件连接神经系统"（AI 驱动插件）在仓颉中的落地方式是：插件 = Service（确定性能力）+ Skill（AI 行为），由统一的 Context 组装**。神经系统 = ServiceRegistry + EventBus + SkillRegistry 三合一的运行时容器，这与 Cordis 的 Service/inject/Events 架构同构，且与 agentskills-runtime 现有的 SkillEngine 天然衔接。

---

## 一、背景：为什么研究这个问题

### 1.1 用户规划（原文）

> "如果将软件比作生命体，那么传统插件只是相当于连接了血管、骨骼这些机械结构，但是没有连接神经系统。我规划的插件希望插件本身也具有 AI 驱动的能力，就是用 skills 的机制让插件也可以连接上神经系统。"

这是插件系统建设的总纲：插件不只是"代码模块"，而是**能感知、能协作、能被 AI 驱动**的运行时公民。要落地这个规划，必须先回答：**仓颉语言到底能不能支撑一个运行时插件系统？支撑到什么程度？**

### 1.2 项目路线图的硬需求

ROADMAP.md 已明确：

- v0.4.0（已完成）：记忆提供者插件体系（MemoryProvider 接口 / BuiltinProvider / PostgresProvider）
- v1.0.0（规划）：插件市场基础设施
- v1.1.0（规划）：插件市场上线

即：**插件机制不是可选项，是 v1.0 的必选项**。本研究为 v1.0 的插件机制选型提供语言能力层面的可行性依据。

### 1.3 现有实践：L0 形态已经在跑

`src/interaction/memory_provider.cj` 的 MemoryProvider 接口 + 多个实现 + 运行时按配置选择，就是最朴素的"插件"——**接口约定 + 实现替换**。这是仓颉插件系统的第一级台阶，问题在于：它靠"开发者手动 new 具体实现"完成组装，没有注册表、没有生命周期、没有依赖声明。本研究要回答的正是：从这级台阶往上，仓颉能走到哪一级。

---

## 二、仓颉语言插件能力盘点（官方文档逐条核对）

### 2.1 可用能力（6 项）

| 能力 | 官方 API / 语法 | 文档依据 | 在插件系统中的用途 |
|---|---|---|---|
| **自定义注解** | `@Annotation` 标记 class，`@Plugin[name]` 使用，`findAnnotation<T>()` 查询 | kernel/source_zh_cn/reflect_and_annotation/anno.md | 声明式标记插件类（名称、版本、依赖） |
| **反射按名查类型** | `TypeInfo.get("module.package.Type")` / `ClassTypeInfo.get(...)` | std/reflect/reflect_package_classes.md | 运行时"发现"插件类型——**L1 的核心入口** |
| **反射动态实例化** | `ClassTypeInfo.getConstructor(Array<TypeInfo>)` → `ConstructorInfo.apply(args): Any` | std/reflect/reflect_package_classes.md:594-704 | 运行时创建插件实例——**替代 `new` 的运行时开关** |
| **反射访问成员** | `getInstanceVariable` / `getInstanceProperty` / `getStaticFunction(...).apply(...)` | kernel reflect_and_annotation/dynamic_feature.md | 运行时调用插件方法、读取状态 |
| **宏（编译期代码生成）** | `macro package` + 属性宏 `@Foo[attr](input)` + `std.ast` AST 操作 | kernel Macro 文档 | 编译期生成注册代码、DSL 解析、自动装配 |
| **动态库输出** | `cjc --output-type=dylib`（生成 libxxx.so）+ FFI `foreign` 调用 C 库 | cjc 文档 + FFI 文档 | L2 形态的基础：插件可编译为独立动态库 |

### 2.2 缺失/受限能力（3 项，如实说明）

| 缺失能力 | Cordis/JS 中的做法 | 仓颉现状 | 影响与对策 |
|---|---|---|---|
| **运行时加载新代码** | `node:vm` 沙箱 + `require()` 动态加载 | **已更正**：仓颉标准库提供 `ModuleInfo.load()` / `PackageInfo.load()` 可运行时加载 .so 仓颉动态库并反射访问类型/变量/函数（官方文档：docs.cangjie-lang.cn "动态加载的使用"）。另可通过 ArkTS 互操作 `context.requireArkModule()` 运行时加载动态语言模块。详见《鸿蒙仓颉动态特性综合分析》报告。~~原判断"无原生 dlopen API"有误，已更正。~~ | 插件可走仓颉动态库加载（`PackageInfo.load` + 反射）或 ArkTS 桥接（`requireArkModule`），见 §3.3 |
| **Proxy 动态属性** | `ctx.tools` 这种"没定义也能访问"的魔法 | 无 Proxy；属性访问编译期确定 | 服务定位改为显式注册表 `ServiceRegistry`（`Map<String, Any>` + 接口约束） |
| **动态类型/原型链** | 事件声明合并、鸭子类型 | 强类型 + 接口继承 | 事件改编译期接口定义 + 运行时注册；类型安全反而更强 |

### 2.3 一句话总结

> **仓颉能做的：编译期（宏）把插件"登记在册"，运行期（反射）把登记的类型"激活成实例"，注册表（显式容器）把实例"组装协作"。**
> **仓颉不能做的：在运行中凭空加载一份从未链接过的代码。**——这与 Cordis 报告 §6.2 的判断一致：静态语言必然走"编译时确定 + 运行时配置"路线。

---

## 三、三种插件形态：逐一可行性分析

### 3.1 L0 — 代码内插件（接口 + 多实现 + 配置选择）

**现状**：MemoryProvider 已是此形态。接口定义契约，多个 Provider 实现，配置或工厂函数决定用哪个。

**可行性**：✅ 已验证，无需论证。

**局限**：插件与宿主强编译耦合；无注册表（靠手动 new）；无生命周期（没有加载/卸载概念）；无依赖声明。

### 3.2 L1 — 编译时插件（注解 + 反射动态实例化）【推荐主形态】

**机制设计**（伪代码级）：

```cangjie
// 1. 插件注解（一个 @Annotation class）
@Annotation[target: [AnnotationKind.Type]]
public class PluginAnnotation {
    public let name: String
    public let version: String
    public let dependencies: Array<String> = []
    public const init(name: String, version: String) { ... }
}

// 2. 插件类（声明式标记 + 实现统一接口）
@PluginAnnotation["git-tool", "1.0.0"]
public class GitToolPlugin <: Plugin {
    public override func onLoad(ctx: PluginContext): Unit { ... }
    public override func onUnload(ctx: PluginContext): Unit { ... }
}

// 3. 插件加载器（核心：按名发现 + 动态实例化）
public class PluginLoader {
    // 编译期登记的插件清单（可由宏自动生成，见 §4.4）
    private var registry = HashMap<String, ClassTypeInfo>()

    public func load(pluginName: String): Option<Plugin> {
        // 按名查类型（反射）
        let cls = registry.get(pluginName).getOrThrow()
        // 验证注解
        let ann = cls.findAnnotation<PluginAnnotation>()
        // 动态实例化（反射调用构造函数）
        let ctor = cls.getConstructor([])      // Array<TypeInfo>
        let instance = ctor.apply([]) as Plugin
        return Some(instance)
    }
}
```

**关键 API 逐条验证**（全部来自官方文档，非设计推演）：

1. `ClassTypeInfo.get("module.package.Type")` —— 按限定名获取类型信息 ✅
   > 官方：*"传入参数需要符合 `module.package.type` 的完全限定模式规则……当运行时无法查询到对应类型的实例，则会抛出 `InfoNotFoundException`"*
2. `ConstructorInfo.apply(args: Array<Any>): Any` —— 动态调用构造函数，返回实例 ✅
   > 官方：*"调用该 ConstructorInfo 对应的构造函数，传入实参列表，并返回调用结果……由该构造函数构造得到的类型实例"*
3. `findAnnotation<T>()` —— 按注解类型查找 ✅
4. 反射只暴露 `public` 成员 ✅（插件接口必须 public，这恰好是合理的契约约束）

**能力边界（诚实标注）**：
- 插件必须在编译链接期进入宿主程序（直接依赖或动态库链接），反射才能看到它；
- "运行时装新插件"= 重新编译/重新部署（L2 才有真正运行时加载）；
- 但"运行时启用/停用/替换已注册插件"完全成立——这已经覆盖插件市场的绝大多数使用场景（安装后重启生效是行业常态，npm 装完也要重启进程）。

**可行性结论**：✅ **可行，且是静态语言的最优解。** 工程上等价于 Java 的 ServiceLoader + 注解扫描，但比 Java SPI 更强——仓颉反射直接支持按名实例化，连 `newInstance()` 都不用自己写。

### 3.3 L2 — 运行时插件（动态库 / WASM 沙箱）

#### 3.3.1 动态库路线（FFI + dlopen）

**技术事实**：
- `cjc --output-type=dylib` 可将仓颉代码编译为动态库（libxxx.so / .dll）✅
- 仓颉 FFI 支持 `foreign func` 声明任意 C 函数——**可以自己声明 `dlopen`/`dlsym`（POSIX）或 `LoadLibrary`/`GetProcAddress`（Windows）**，官方无封装但有通道 ✅（技术上可行）
- 但：**仓颉动态库依赖仓颉 runtime**（部署文档明确：运行时库存放全部动态库）；dlopen 拿到的是 C ABI 函数符号，**无法直接操作仓颉对象**，需要 `@C` 导出桥接函数（工厂 + 回调）

**机制设计**：插件编译为 dylib → 导出 `@C` 工厂函数（如 `create_plugin() -> CPointer<Unit>` 返回不透明句柄）→ 宿主 dlopen → dlsym 取工厂函数 → 调用获取句柄 → 通过导出的 C 回调接口（`register_callbacks(CFunc...)`）与宿主通信。

**可行性结论**：⚠️ **技术通路存在，但工程代价高**：
- 桥接层要维护 C ABI 契约（插件接口的每一次演进都要同步桥接代码）；
- 卸载/重载涉及 dlclose，仓颉 runtime 对象能否安全回收需实证；
- 沙箱隔离（ROADMAP v0.5 的 WASM 规划）比裸 dlopen 更安全。

#### 3.3.2 WASM 沙箱路线

**技术事实**：ROADMAP v0.5.0 已规划"WASM 沙箱安全隔离完善"；WASM 插件 = 独立运行时，通过 host functions 与宿主通信，天然隔离。

**可行性结论**：⚠️ **方向正确（安全隔离的最优解），但工程量最大**：需要 WASM 运行时集成 + 宿主接口定义 + 插件 SDK。适合作为 v1.1+ 的增强形态，不建议阻塞 v1.0 的插件市场。

#### 3.3.3 L2 小结

| 子路线 | 运行时加载 | 安全隔离 | 工程成本 | 建议 |
|---|---|---|---|---|
| 动态库 dlopen | ✅ | ❌（同进程裸加载） | 高（C ABI 桥接） | 有特殊需要再做 |
| WASM 沙箱 | ✅ | ✅ | 最高 | v1.1+ 增强形态 |

---

## 四、Cordis 六大语义的仓颉映射（本报告核心价值）

Cordis 报告 §6.2 提出"借鉴语义、不照搬实现"，本节给出每条语义的仓颉落地方式。

### 4.1 Service（服务定位）：Proxy → 显式 ServiceRegistry

| Cordis | 仓颉版 |
|---|---|
| `ctx.tools` / `ctx.llm`，Proxy 拦截任意属性访问 | `Context.service<T>("tools")`，内部 `HashMap<String, Any>` + 类型断言 |
| 服务可以替换，消费者无感 | 服务以接口类型注册：`ctx.register<IToolService>(impl)`；消费者拿接口，不拿实现 |

```cangjie
public class Context {
    private var services = HashMap<String, Any>()
    public func register<T>(name: String, svc: T): Unit where T <: Any { ... }
    public func get<T>(name: String): Option<T> { ... }  // 类型断言 + 查找
}
```

**要点**：显式注册表比 Proxy 更啰嗦，但类型安全更强（拿错类型编译期报错，而不是运行时 undefined）。

### 4.2 inject（声明式依赖）：注解声明 + 加载器校验

| Cordis | 仓颉版 |
|---|---|
| 插件 `inject: ['tools', 'llm']`，服务就绪才激活 | 插件注解 `dependencies: Array<String>`，加载器激活前逐一校验 `services.containsKey()` |

**要点**：Cordis 的 inject 是"响应式等待"（服务被替换时相关插件自动重启）；仓颉版先做"启动期校验"（依赖缺失则拒绝激活并报错），响应式重载作为 v1.1 增强。**语义分层：先保证正确，再追求动态。**

### 4.3 effect/disposer（可逆卸载）：逆操作栈

| Cordis | 仓颉版 |
|---|---|
| 每次注册返回 disposer，卸载时按序执行 | `PluginContext.cleanup: ArrayList<() -> Unit>`，`onUnload` 时**逆序**执行全部清理闭包 |

```cangjie
public class PluginContext {
    private var disposers = ArrayList<() -> Unit>()
    public func onCleanup(f: () -> Unit): Unit { disposers.add(f) }
    public func dispose(): Unit {
        for (i in disposers.size - 1 downTo 0) { disposers[i]() }  // 逆序，后注册先清理
        disposers.clear()
    }
}
```

**要点**：这正是 Cordis 报告 §6.2 预言的"注册表 + 逆操作列表 + 确定性销毁顺序"。dsh vendor 修改日志里 fiber.ts 修的重入式卸载漏洞，仓颉版在 `dispose()` 加状态位（`disposing` 标志）即可防御。

### 4.4 Events（事件分发）：编译期接口 + 运行时总线

| Cordis | 仓颉版 |
|---|---|
| emit / waterfall / parallel / serial 四种模式 | `EventBus` 按 `(事件名, 载荷类型)` 注册监听器；waterfall 用"链式处理器"实现（每个处理器可短路） |

```cangjie
public interface SkillEvent {}
public class SkillExecuted : SkillEvent { public let skillName: String ... }

public class EventBus {
    private var listeners = HashMap<String, ArrayList<(SkillEvent) -> Unit>>()
    public func emit(e: SkillEvent): Unit { ... }         // 观察
    public func waterfall(e: SkillEvent): Unit { ... }    // 链式，可短路（中间件拦截）
}
```

**要点**：仓颉没有声明合并，事件类型用**接口 + 具体事件类**表达，编译期即类型安全——比 JS 的字符串事件名更可靠。

### 4.5 运行时反射（检视自身）：Registry 快照

| Cordis | 仓颉版 |
|---|---|
| `cordis_inspect` 枚举服务/插件/事件 | `PluginRegistry.snapshot(): PluginReport`——枚举已注册插件、激活状态、服务列表、事件监听数 |

**要点**：dsh 的 tool-cordis 让 Agent 检视/定义/试运行/撤回插件；仓颉版 Agent 工具可做：`plugin_inspect`（检视）+ `plugin_activate/deactivate`（启用/停用已注册插件）。**"定义新插件"受限于无法运行时加载新代码，但"试运行后干净撤回"可以用 L1 形态实现**——注册表快照 + 回滚（激活前记录状态，停用时恢复）。

### 4.6 HMR / 合流性：降级为"配置重载 + 幂等加载"

| Cordis | 仓颉版 |
|---|---|
| 配置变更自动重载（HMR） | 配置文件变更 → 重新解析 → 对差异插件执行停用/激活（增量协调） |
| 合流性（加载顺序不影响终态） | 无法形式化证明；用**幂等加载**工程近似：同一插件重复加载返回同一实例（`HashMap` 去重），停用幂等（不存在则忽略） |

**要点**：合流性的价值在"交错加载收敛到同一终态"。仓颉版用"注册表幂等操作"保证"同一份配置，无论加载顺序如何，最终注册表状态一致"——语义近似，靠工程不变量而非定理。

---

## 五、「智能插件连接神经系统」的仓颉架构设计

### 5.1 神经系统 = 三合一容器

用户的核心规划是"插件连接神经系统"，即插件具备 AI 驱动能力。在仓颉中的落地：

```
                    ┌─────────────────────────────────┐
                    │         PluginContext           │
                    │   (每个插件一个，生命周期载体)      │
                    └──────────────┬──────────────────┘
                                   │ 拥有
        ┌──────────────┬───────────┴────────────┬──────────────┐
        ▼              ▼                        ▼              ▼
 ┌────────────┐ ┌────────────┐        ┌────────────┐   ┌────────────┐
 │ServiceRegistry│ │ EventBus   │        │ SkillRegistry│  │  Lifecycle  │
 │ 确定性能力    │ │ 协作通道    │        │  AI 行为    │   │  状态机      │
 │(tools/db/...)│ │ 事件分发    │        │ (SKILL.md)  │  │ PENDING→... │
 └────────────┘ └────────────┘        └────────────┘   └────────────┘
```

- **ServiceRegistry**：插件的"血管骨骼"（确定性能力：工具、数据源、外部服务）
- **SkillRegistry**：插件的"神经系统"（AI 行为：插件注册 SKILL.md，Agent 可发现并调用）
- **EventBus**：神经信号（插件间协作、Agent 事件感知）
- **Lifecycle**：插件的"生命"（加载/激活/停用/卸载状态机）

### 5.2 生命周期状态机（仓颉版 Fiber）

```
PENDING ──加载──▶ LOADING ──验证依赖+实例化──▶ ACTIVE
   ▲                 │                           │
   └─────重新加载────┴──失败──▶ ERROR ◀──停用─────┘
                                          │
                                     DISPOSED（逆序清理）
```

对应 Cordis 的 PENDING → LOADING → ACTIVE → DISPOSED，加一个 ERROR 态（依赖缺失/注解非法时进入，可重试）。

### 5.3 与现有 SkillEngine 的衔接（关键优势）

agentskills-runtime 已有完整的技能引擎（SkillLoader / CompositeSkillToolManager / SkillExecutionEngine 等）。**插件系统的 AI 能力不必从零造**：

- 插件的"神经系统"注册直接复用现有技能加载管线（插件目录 = 特殊技能目录）；
- 插件内的 AI 行为 = SKILL.md（人类可读、Agent 可消费、可版本化）——**这与 Cordis 报告 §6.4 的"插件市场必须绑定运行时能力描述（AI 可消费目录）"建议天然一致**；
- 技能进化机制（SkillCurator，v0.3 已完成）可直接作用于插件技能，实现"插件能力随使用进化"。

### 5.4 Agent 自引用工具（对应 tool-cordis）

建议实现三个 Agent 可见工具：

| 工具 | 能力 | 对应 dsh |
|---|---|---|
| `plugin_inspect` | 检视已注册插件、状态、依赖、服务、技能 | cordis_inspect |
| `plugin_activate` | 激活某已注册插件（含依赖校验） | cordis_run |
| `plugin_deactivate` | 停用插件（逆序清理 + 快照回滚） | cordis_stop |

**"运行时定义新插件"（cordis_define/undefine）暂不实现**——受限于 §2.2 的代码加载限制，留待 L2（WASM）形态补全。

---

## 六、推荐路线图

### 阶段一（v1.0 前）：L1 插件框架核心

- [ ] `Plugin` 接口 + `PluginContext`（生命周期 + 逆序清理）
- [ ] `PluginAnnotation` 注解（name/version/dependencies）
- [ ] `PluginRegistry`（注册表 + 幂等加载 + 快照回滚）
- [ ] `PluginLoader`（按名发现 + 反射实例化，走 `ClassTypeInfo.get` + `ConstructorInfo.apply`）
- [ ] 事件总线（emit + waterfall，编译期事件接口）
- [ ] 配置驱动（YAML 插件清单：启用哪些插件、参数注入）
- [ ] 三个 Agent 工具（inspect/activate/deactivate）

### 阶段二（v1.0）：插件 + Skills 融合

- [ ] 插件注册技能（插件目录内 SKILL.md 自动进 SkillRegistry）
- [ ] 插件能力目录（AI 可消费的插件能力描述，对应 dsh api-catalog 思路）
- [ ] 插件市场基础（清单格式 + 校验 + 安装目录约定）

### 阶段三（v1.1+）：增强形态

- [ ] 响应式依赖重载（服务替换时相关插件自动重启）
- [ ] WASM 沙箱插件（真正运行时加载 + 隔离）
- [ ] 配置热更新

---

## 七、风险与限制（如实说明）

1. ~~**运行时加载新代码不可行（最大限制）**~~ **已更正（2026-08-17）**：仓颉标准库提供 `ModuleInfo.load()` / `PackageInfo.load()` 可运行时加载 .so 动态库并反射访问（官方文档 docs.cangjie-lang.cn "动态加载的使用"）。另有 ArkTS 互操作 `requireArkModule()` 可运行时加载动态语言模块。详见《鸿蒙仓颉动态特性综合分析》报告。L1 形态的"安装后重启"约束仅适用于编译期已链接的插件；通过 L2 动态加载API，可做到运行时装载新插件。
2. **反射性能**：官方文档明确"反射调用性能通常低于直接调用"。插件激活是低频操作（启动时一次），性能可接受；**热路径（如事件分发）应走编译期接口直调，不走反射**。
3. **动态库加载路线有官方API支撑（已更正）**：仓颉标准库 `PackageInfo.load()` 提供原生动态加载能力，不再依赖 FFI + dlopen 手动桥接。但 dlclose 卸载时对象的回收、动态库依赖的 runtime 版本兼容仍需原型验证。**建议 v1.0 先做 L1，L2 动态加载在 v1.1 评估**。
4. **合流性无定理背书**：Cordis 有论文，仓颉版只能用工程不变量（幂等 + 快照回滚）近似。对外叙事时建议表述为"确定性插件生命周期"，不声称形式化保证。
5. **宏生成注册清单的复杂度**：用宏自动收集所有 `@Plugin` 类生成注册表（避免手工维护清单）是可行的（属性宏 + AST 遍历），但宏的编译期调试成本不低，可先用"手工清单 + 脚本生成"起步，宏作为 v1.1 优化。

---

## 八、结论

1. **仓颉版插件系统完全可行**，推荐主形态为 **L1（注解 + 反射动态实例化）**：官方反射 API（`ClassTypeInfo.get` / `ConstructorInfo.apply` / `findAnnotation`）完整支撑"运行时发现 + 实例化"闭环，这是静态语言能拿到的最优解。
2. **Cordis 六大语义全部可在仓颉落地**：服务定位（显式注册表）、声明式依赖（注解 + 启动校验）、可逆卸载（逆序清理栈）、事件分发（编译期接口 + 总线）、运行时反射（注册表快照）、HMR/合流性（配置重载 + 幂等加载）。**语义等价，实现路径不同，且类型安全更强**。
3. **"插件 + Skills 融合"（神经系统）在仓颉中不是额外设计，而是与现有 SkillEngine 的自然衔接**：插件 = Service（确定性能力）+ Skill（AI 行为），神经系统 = ServiceRegistry + EventBus + SkillRegistry 三合一容器。这正是 agentskills-runtime 相对 dsh 的差异化优势——**AI 驱动插件是仓颉版插件的默认形态，而非事后扩展**。
4. **诚实的边界**：~~运行时加载新代码不可行~~ 已更正：仓颉标准库有 `PackageInfo.load()` 动态加载API（docs.cangjie-lang.cn "动态加载的使用"），另有 ArkTS 互操作 `requireArkModule()` 通道；合流性无定理背书（工程近似）；动态库卸载/回收需实证。建议 v1.0 交付 L1 + 插件技能融合，v1.1+ 评估 L2 动态加载和 WASM 沙箱。详见《鸿蒙仓颉动态特性综合分析》报告。

---

## 附录：文档依据清单

1. 仓颉官方文档 — 动态特性（反射）：`kernel/source_zh_cn/reflect_and_annotation/dynamic_feature.md`
2. 仓颉官方文档 — 反射 API：`std/reflect/reflect_package_api/reflect_package_classes.md`（ClassTypeInfo / ConstructorInfo / apply）
3. 仓颉官方文档 — 注解：`kernel/source_zh_cn/reflect_and_annotation/anno.md`
4. 仓颉官方文档 — 宏：`kernel/source_zh_cn/Macro/`（macro package / 属性宏 / std.ast）
5. 仓颉官方文档 — FFI：`kernel/source_zh_cn/FFI/`（foreign / CFunc / @C struct）
6. 仓颉官方文档 — CJC 输出类型：`cjc --output-type=[exe|staticlib|dylib]`
7. 仓颉官方文档 — 部署运行：`kernel/source_zh_cn/deploy_and_run/runtime_deploy.md`（运行时动态库依赖）
8. 前置报告：`docs/ref/cordis-vs-npm-plugin.md`（§4.3 自引用工具集、§6 对 agentskills-runtime 的启示）
9. 项目文件：`ROADMAP.md`（v0.4 记忆提供者插件体系、v1.0 插件市场）、`src/interaction/memory_provider.cj`（现有 L0 实践）

---

# 附篇：鸿蒙仓颉动态特性、Agent DSL 与插件机制综合分析

> 研究对象：仓颉静态语言如何支撑鸿蒙APP的动态特性、Agent DSL 的适用场景、仓颉-ArkTS互操作对插件机制的启示
> 依据：鸿蒙编程语言白皮书 V2.0（2026-06-08）+ 仓颉官方文档 + ChatUI项目源码 + Cangjie-ArkTS互操作开源代码 + 网络公开资料
> 分析日期：2026-08-17
> 前置报告：本报告主体（cangjie-plugin-system-feasibility.md）

---

## 附·摘要（先说结论）

1. **仓颉作为静态语言开发鸿蒙APP，动态特性通过五条路径实现**：宏（编译期代码生成）、包按需加载、反射、ArkTS互操作（借动态语言的能力）、以及官方文档确认的 `ModuleInfo.load()` / `PackageInfo.load()` 运行时动态加载API。静态语言并非"不能动"，而是"动的路径不同"。

2. **Agent DSL 是编译期 eDSL（内嵌DSL），不是运行时动态机制**。它通过 `@agent` / `@prompt` / `@tool` 宏在编译期生成代码，适合"Agent结构已知、运行时只需调用"的场景。agentskills-runtime 从 AGENTS.md 等文件动态加载编排是数据驱动方案，两者正交互补，不矛盾。

3. **仓颉-ArkTS 互操作是插件系统的重大利好**：ArkTS（动态语言）的模块按需加载 + Cangjie 对 ArkTS 的运行时调用（`context.requireArkModule()`），为仓颉插件系统提供了一条"借道动态语言"的运行时插件通道——不用 dlopen 也能运行时加载新功能。

4. **重大更正**：前报告判断"仓颉无运行时加载新代码能力"是错误的。仓颉标准库提供 `ModuleInfo.load()` / `PackageInfo.load()` 可在运行时加载 `.so` 仓颉动态库并反射访问类型、全局变量、函数。L2 形态的可行性从"⚠️ 需实证"上调为"✅ 有官方API支撑"。

---

## 附·一、仓颉如何满足鸿蒙APP的动态特性

### 附1.1 白皮书的定位

鸿蒙编程语言白皮书 V2.0 第一章明确：鸿蒙是多编程语言生态，ArkTS（动态类型）和仓颉（静态类型）是两大主力语言，各有所长：

> "对于动态更新业务场景、与TS/JS高效互通场景、快速构建等场景建议优先选择ArkTS；对于高吞吐量/高频读写的数据处理场景、高频交互高负载场景、启动时延敏感等场景建议优先选择仓颉。"

白皮书的立场很清楚：**动态性需求大的场景用ArkTS，性能需求大的场景用仓颉**。两者通过互操作协作。

### 附1.2 仓颉实现"动态"的五条路径

从白皮书和官方文档逐条核对，仓颉作为静态语言，通过以下五条路径满足APP的动态需求：

| # | 路径 | 原理 | 动态程度 | ChatUI项目中的体现 |
|---|---|---|---|---|
| 1 | **宏（元编程）** | 编译期分析/变换/生成代码，引入新语法和领域行为 | 编译期"动态"——生成你手写不出来的代码 | `@Entry` / `@Component` / `@State` / `@Builder` 宏生成声明式UI代码 |
| 2 | **包按需加载** | 仓颉以包为粒度组织代码，支持包级按需加载 | 运行期延迟加载，但包须编译期确定 | cjpm.toml `output-type = "dynamic"`，编译为 .so 动态库 |
| 3 | **反射** | 运行时获取类型信息、读写成员、调用函数、动态实例化 | 运行期"检视+调用"，类型须编译期存在 | 白皮书未直接展示，但官方文档 `TypeInfo.of()` / `ClassTypeInfo` / `ConstructorInfo.apply()` |
| 4 | **ArkTS互操作** | 仓颉通过 `ohos.ark_interop` 库调用ArkTS动态模块 | 运行期加载动态语言模块——**借道动态语言实现真动态** | `context.requireArkModule("模块名")` 加载NAPI/ABC模块 |
| 5 | **ModuleInfo.load / PackageInfo.load** | 仓颉标准库API，运行时加载 .so 仓颉动态库并反射访问 | **运行期加载新代码**（真正的动态加载） | 官方文档示例：`PackageInfo.load("path/libmyPackage")` |

### 附1.3 ChatUI项目源码分析

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

### 附1.4 白皮书揭示的未来动态能力增强

白皮书第三章"演进策略"明确规划了仓颉-ArkTS互操作的未来增强：

> "引入渐进/动态类型改进当前仓颉-ArkTS反射式互操作机制，在强类型框架下引入更具弹性的语法语义支持"
> - **非侵入式动态类型传播**：定义 Extern 类型作为中立的数据载体，保留动态语言灵活性的同时，防止外部不确定类型干扰仓颉静态检查
> - **自动化边界类型契约**：在赋值、传参及显式转换等关键交互边界建立自动化契约协议

这意味着华为官方正在规划让仓颉"在不牺牲静态安全的前提下获得更多动态能力"——这对插件系统是直接利好。

---

## 附·二、Agent DSL 的适用场景与 agentskills-runtime 的对比

### 附2.1 Agent DSL 是什么

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

### 附2.2 Agent DSL 的本质：编译期eDSL

**关键判断：Agent DSL 是编译期机制，不是运行时动态机制。**

`@agent` / `@prompt` / `@tool` 是**宏注解**——在编译期：
1. 宏解析类定义和注解参数
2. 生成Agent基础设施代码（模型调用、提示词管理、工具注册、执行流程）
3. 生成的代码在运行时是一段"已固化的执行逻辑"

运行时不能"动态定义一个新Agent"——所有Agent类必须在源码中写好，编译期已知。

### 附2.3 agentskills-runtime 的方案：数据驱动的运行时动态编排

agentskills-runtime 的方案是：
- 从 AGENTS.md 或 subagent 定义文件（数据文件）动态读取Agent配置
- 通过程序逻辑和数据库数据动态编排Agent行为
- 运行时可增删改Agent定义，无需重新编译

这是**数据驱动方案**——Agent结构是运行时数据，不是编译期代码。

### 附2.4 两种方案的对比

| 维度 | Agent DSL（仓颉原生） | agentskills-runtime（数据驱动） |
|---|---|---|
| 定义方式 | 源码中 `@agent` 宏注解 | AGENTS.md / 数据库 / JSON等数据文件 |
| 生效时机 | 编译期 | 运行期 |
| 增删Agent | 需重新编译 | 修改数据文件即可 |
| 类型安全 | 编译期检查，类型安全最强 | 运行时校验，灵活但需自行保证安全 |
| 开发体验 | IDE自动补全、编译期报错 | 需要运行时才能发现配置错误 |
| 适合场景 | Agent结构固定、需高性能和高可靠 | Agent结构灵活多变、需运行时动态编排 |
| 业界对照 | 类似Android的注解框架 | 类似LangChain/AutoGen等Python动态方案 |

### 附2.5 谁在用Agent DSL？

从公开资料看，Agent DSL 的用户群体主要是：

1. **鸿蒙原生应用开发者**：Agent DSL 是仓颉语言原生能力，开发鸿蒙智能应用（如日程助理、设备控制等）时，用 `@agent` 宏比手写模型调用+提示词+工具注册代码效率高得多。

2. **CangjieMagic框架用户**：基于仓颉开源的LLM Agent开发框架（gitcode.com/Cangjie-TPC/CangjieMagic），使用Agent DSL + MCP协议构建企业级Agent系统，已有文档问答、智能运维等实践案例。

3. **需要"声明式"开发体验的开发者**：从传统命令式编程转向声明式，Agent DSL让开发者只描述"做什么"，框架处理"怎么做"。

### 附2.6 两种方案不矛盾，是正交互补关系

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

## 附·三、仓颉-ArkTS互操作对插件机制的启示

### 附3.1 互操作机制总览

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

### 附3.2 模块系统的动态特性

从开源代码分析（deepwiki.com/openharmony/arkcompiler_cangjie_ark_interop/2.4-module-system）：

- **JSModule.registerModule**：仓颉模块在编译时注册导出，运行时由ArkTS通过native require加载
- **ArkModuleHelper**：运行时验证和解析模块规范名
- **白名单机制**：KIT_CONFIGS / BUNDLE_MAP 控制仓颉可加载哪些ArkTS模块
- **配置生成工具**：构建时解析SDK .d.ts文件生成模块配置

**关键点**：ArkTS侧的模块加载是动态的（Node-API的require机制），仓颉通过`requireArkModule`可以在运行时按需加载ArkTS模块。这意味着**通过ArkTS互操作，仓颉可以获得"运行时加载新功能"的能力**。

### 附3.3 对插件系统的具体应用

基于互操作机制，仓颉版插件系统可以设计出比纯静态方案更动态的形态：

#### 方案A：ArkTS动态插件桥（⚠️ 仅鸿蒙系统可用）

> **平台限制**：此方案依赖 `ohos.ark_interop` 库（OpenHarmony 系统组件），仅在鸿蒙系统上可用。Windows/macOS/Linux 上无此库。详见附篇第六章跨平台分析。

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

> **跨平台注意**：仓颉动态库通道（方案B）全平台可用；ArkTS通道（方案A）仅鸿蒙可用。在非鸿蒙平台上，混合方案退化为"仓颉动态库单一通道"。详见附篇第六章。

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
│    │ 全平台 ✅   │  │ 仅鸿蒙 ⚠️          │         │
│    └────────────┘  └────────────────────┘         │
└─────────────────────────────────────────────────┘
```

**这个方案让仓颉版插件系统同时具备**：
- 仓颉插件（高性能、类型安全，全平台可用，适合核心能力插件）
- ArkTS插件（动态加载、生态丰富，仅鸿蒙可用，适合鸿蒙业务逻辑插件）
- AI驱动的Skill融合（仓颉侧SkillRegistry统一管理，全平台）

### 附3.4 与Cordis插件机制的对照

| Cordis机制 | 仓颉版对应方案 | 动态程度 |
|---|---|---|
| `require()` 动态加载 | `PackageInfo.load()`（全平台 ✅）或 `requireArkModule()`（仅鸿蒙 ⚠️） | ✅ 运行时加载 |
| `ctx.inject()` 依赖注入 | 注解 + 反射实例化 + 显式注册表 | ✅ 运行时注入 |
| `ctx.effect()` 可逆副作用 | 逆序清理栈 | ✅ 运行时注册/卸载 |
| Proxy 动态属性 | `JSValue` 动态对象（通过ArkTS桥，仅鸿蒙 ⚠️） | ⚠️ 需借道ArkTS，非跨平台 |
| 事件合流性 | 幂等加载 + 注册表快照 | ⚠️ 工程近似 |

**关键结论**：通过仓颉原生 `PackageInfo.load()` 动态加载API，Cordis 的"运行时加载新代码"语义可在全平台实现。ArkTS 互操作作为鸿蒙增强通道，提供额外的动态能力（如 Proxy 式动态对象），但**不是跨平台依赖项**——详见附篇第六章跨平台分析。

---

## 附·四、对前报告的更正

### 附4.1 重大更正：仓颉有运行时加载新代码能力

前报告（本报告主体部分）原第72行写道：

> "运行时加载新代码 | 无原生 dlopen API；反射只能查'编译链接时已存在'的类型 | 影响最大的一条"

**这是错误的。** 仓颉标准库 `std.reflect` 提供了：
- `ModuleInfo.load(path)` — 运行时加载仓颉动态模块
- `PackageInfo.load(path)` — 运行时加载仓颉动态包
- 加载后可通过 `TypeInfo.get()` 反射访问类型
- 可读写全局变量、调用函数、动态实例化

来源：仓颉官方文档 `docs.cangjie-lang.cn` 的"动态特性"章节和"动态加载的使用"章节。

### 附4.2 更正后的L2可行性

| 形态 | 前报告结论 | 更正后结论 |
|---|---|---|
| L2 运行时插件 | ⚠️ 可行但需实证（dlopen + C ABI桥接） | ✅ **可行，有官方API支撑**（`PackageInfo.load()` + 反射） |

前报告的L2方案只考虑了"FFI声明dlopen + C ABI桥接"的路线，忽略了仓颉标准库自带的动态加载API。`PackageInfo.load()` 是仓颉原生的动态加载方案，加载后直接用反射操作仓颉类型，不需要C ABI桥接层。

### 附4.3 不变的部分

以下结论不受影响，仍然成立：
- L1（注解+反射动态实例化）是仓颉原生最优解 ✅
- Cordis六大语义全部可仓颉化 ✅
- 插件=Service+Skill的神经系统设计 ✅
- 合流性无定理背书（工程近似） ✅

---

## 附·五、总结与建议

### 附5.1 核心发现

1. **仓颉静态语言在鸿蒙APP中的动态特性**通过五条路径实现：宏生成、包按需加载、反射、ArkTS互操作、ModuleInfo/PackageInfo.load()动态加载。ChatUI项目展示了典型的"编译期结构 + 运行时数据"模式。

2. **Agent DSL是编译期eDSL**，适合"Agent结构已知"的声明式开发场景。agentskills-runtime的运行时动态编排方案与Agent DSL正交互补，不矛盾——前者是框架层动态编排，后者是语言层声明式定义，可以组合使用。

3. **仓颉-ArkTS互操作为插件系统打开了一扇大门**：ArkTS的动态模块加载 + 仓颉的运行时调用，构成了一条"借道动态语言"的运行时插件通道。混合方案（仓颉骨架 + ArkTS/仓颉动态库双通道插件）是最优解。

4. **前报告需更正**：仓颉标准库有 `ModuleInfo.load()` / `PackageInfo.load()` 动态加载API，L2形态可行性从"⚠️"上调为"✅"。

### 附5.2 对agentskills-runtime的具体建议

1. **v1.0插件系统设计应纳入混合方案**（跨平台基线 + 鸿蒙增强）：
   - 仓颉插件走 `PackageInfo.load()` + 反射实例化（类型安全、高性能、**全平台可用**）——跨平台基线
   - ArkTS插件走 `requireArkModule()` + JSValue桥接（动态加载、生态丰富、**仅鸿蒙可用**）——鸿蒙增强，通过 `@When` 条件编译隔离
   - 两条通道统一由PluginManager管理，插件清单标注 `platform` 字段

2. **Agent DSL不是必须用的**：agentskills-runtime作为框架，自身的Agent编排是数据驱动的。但如果用户想用仓颉写一个嵌入式Agent，可以用`@agent`宏，然后被框架编排——这是可选增强，不是必选项。

3. **白皮书预告的"渐进/动态类型"演进值得关注**：华为正在规划让仓颉在不牺牲静态安全的前提下获得更多动态能力（Extern类型、自动化边界类型契约），这将直接利好插件系统的类型安全与动态性的平衡。

4. **CORDIS对照更新**：有了`PackageInfo.load()`动态加载通道，Cordis的"运行时加载新代码"语义在仓颉中可以做到真正的运行时加载，不再需要"重启进程"的妥协。**但ArkTS互操作通道（`requireArkModule`）仅在鸿蒙系统可用**——详见附篇第六章跨平台分析。

> **架构师更正（2026-08-17）**：前文原表述"至少在非鸿蒙APP场景下如此"有误，实际情况恰恰相反——ArkTS互操作仅在鸿蒙可用，非鸿蒙平台只有`PackageInfo.load()`一条通道。经详细研究后新增附篇第六章"跨平台插件加载能力分析"。

---

## 附·六、跨平台插件加载能力分析（架构师询问后的专项研究）

### 附6.1 问题背景

架构师指出：agentskills-runtime 是跨平台框架，运行在 Windows、macOS、Linux、鸿蒙等多种操作系统上。ArkTS 的运行时（方舟运行时）是鸿蒙系统专属的，`ohos.ark_interop` 库是 OpenHarmony 系统组件。因此 ArkTS + 仓颉的互操作插件机制未必能在多种操作系统中适配。

**经详细研究确认：架构师的判断完全正确。**

### 附6.2 两条动态加载通道的平台可用性

| 动态加载通道 | 依赖库 | Windows | macOS | Linux | 鸿蒙(HarmonyOS) | Android | iOS |
|---|---|---|---|---|---|---|---|
| **`PackageInfo.load()`** | `std.reflect`（仓颉标准库） | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **`requireArkModule()`** | `ohos.ark_interop`（鸿蒙系统库） | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **FFI + dlopen/LoadLibrary** | 平台原生 API | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |

**关键事实（均有官方文档/源码佐证）：**

1. **`PackageInfo.load()` 是仓颉标准库 `std.reflect` 的组成部分**，属于仓颉语言原生能力。仓颉 SDK 提供 Windows、macOS、Linux、鸿蒙、Android、iOS 全平台版本（官网下载页 cangjie-lang.cn/download 可验证）。`cjc --output-type=dylib` 在 Linux 产出 `.so`、Windows 产出 `.dll`、macOS 产出 `.dylib`（官方编译选项文档明确列出）。因此 **`PackageInfo.load()` 是真正的跨平台动态加载通道**。

2. **`ohos.ark_interop` 是 OpenHarmony 系统组件**，不是仓颉标准库。官方文档原文："在 OpenHarmony 系统上，ArkTS 具备完整广泛的生态，为复用 ArkTS 生态，仓颉支持与 ArkTS 高效跨语言互通。"开源仓库位于 `gitcode.com/openharmony/arkcompiler_cangjie_ark_interop`，依赖 `ability_runtime`（鸿蒙系统能力）和 `napi`（Node-API，鸿蒙运行时接口）。`import ohos.ark_interop.*` 中的 `ohos` 前缀表明这是鸿蒙系统库。**在 Windows/macOS/Linux 上运行的仓颉程序无法导入此库**——这些平台上没有鸿蒙系统运行时。

3. **ArkTS 运行时（方舟运行时）本身确实有跨平台规划**：白皮书提到"支持在主流操作系统（鸿蒙、Android、iOS、Windows、Linux、macOS）上运行的语言运行时"，ArkUI-X 项目也将 ArkUI 扩展到 Android/iOS。**但这不等于仓颉-ArkTS 互操作库在非鸿蒙平台可用**——互操作库依赖的是鸿蒙系统的 `ability_runtime` 和 `napi` 接口，这些系统级依赖在 Windows/macOS/Linux 上不存在。即使未来 ArkTS 运行时被移植到更多平台，`ohos.ark_interop` 桥接库也需要专门适配才能工作。

### 附6.3 对 agentskills-runtime 插件系统的影响

agentskills-runtime 作为跨平台 AI 驱动开发框架，插件系统必须兼顾全平台。修正后的方案矩阵：

```
┌──────────────────────────────────────────────────────────┐
│              agentskills-runtime 插件系统                    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │         PluginManager (仓颉核心)                    │    │
│  │  - 插件注册表 / 生命周期 / 事件总线 / Skill融合       │    │
│  └─────────┬──────────┬───────────┬──────────────────┘    │
│            │          │           │                        │
│  ┌─────────┴──┐ ┌────┴─────┐ ┌───┴──────────────┐        │
│  │ L1 编译时   │ │ L2 仓颉   │ │ L2 ArkTS 桥       │        │
│  │ 注解+反射   │ │ 动态库    │ │ (仅鸿蒙可用)       │        │
│  │ (全平台)   │ │ (全平台)  │ │ (HarmonyOS only)  │        │
│  └────────────┘ └──────────┘ └────────────────────┘        │
│   全平台基线       全平台增强      鸿蒙专属增强              │
└──────────────────────────────────────────────────────────┘
```

| 插件形态 | 通道 | 平台覆盖 | 定位 |
|---|---|---|---|
| L1 编译时插件 | 注解 + 反射实例化 | 全平台 ✅ | 基线方案，所有平台都支持 |
| L2 仓颉动态库 | `PackageInfo.load()` | 全平台 ✅ | **跨平台运行时加载的主力通道** |
| L2 ArkTS 桥 | `requireArkModule()` | 仅鸿蒙 ⚠️ | 鸿蒙场景增强，非跨平台依赖项 |
| L2 WASM 沙箱 | WASM 运行时 | 全平台 ✅（计划中） | v1.1+ 安全隔离增强 |

### 附6.4 修正后的设计原则

1. **跨平台基线优先**：agentskills-runtime 的插件系统以 L1（注解+反射）+ L2 仓颉动态库（`PackageInfo.load()`）为跨平台基线。这两个通道在 Windows/macOS/Linux/鸿蒙 上均可用，是插件系统的主干。

2. **ArkTS 桥接是鸿蒙增强，不是跨平台依赖**：仅在 agentskills-runtime 运行在鸿蒙系统时启用 ArkTS 插件通道。通过 `@When` 条件编译隔离平台差异：
   ```cangjie
   @When[os == "ohos"]
   func loadArkTSPlugin(path: String): Plugin {
       let runtime = JSRuntime()
       let context = runtime.mainContext
       let module = context.requireArkModule(path)
       // ... ArkTS 插件加载逻辑
   }

   @When[os != "ohos"]
   func loadArkTSPlugin(path: String): Plugin {
       throw UnsupportedPlatformException("ArkTS plugin requires HarmonyOS")
   }
   ```

3. **不对 ArkTS 通道做跨平台假设**：插件市场中的 ArkTS 插件应标注 `platform: harmonyos`，非鸿蒙平台不展示/不安装。仓颉动态库插件标注 `platform: all`，全平台可用。

4. **FFI + dlopen 作为备选**：如果 `PackageInfo.load()` 在某些边缘场景不满足需求（如需要加载非仓颉原生库），FFI 声明 `dlopen`/`LoadLibrary` 是跨平台备选（Linux `.so` / Windows `.dll` / macOS `.dylib`），但需要 C ABI 桥接，工程成本高。

### 附6.5 对前文表述的更正清单

| 位置 | 原表述 | 更正后 |
|---|---|---|
| 附5.2 第4条 | "有了`PackageInfo.load()`和ArkTS互操作两条动态加载通道……不再需要'重启进程'的妥协（至少在非鸿蒙APP场景下如此）" | "有了`PackageInfo.load()`动态加载通道……不再需要'重启进程'的妥协。**但ArkTS互操作通道仅在鸿蒙系统可用**" |
| 附3.3 方案A | 未标注平台限制 | 补充标注"仅鸿蒙系统可用" |
| 附3.3 方案C | 混合方案未区分平台覆盖 | 补充"仓颉动态库通道全平台可用，ArkTS通道仅鸿蒙" |
| 附3.4 对照表 | `requireArkModule()` 标注"✅ 运行时加载" | 更正为"✅ 运行时加载（仅鸿蒙）" |

### 附6.6 结论

**架构师的判断完全正确**：ArkTS 运行时是鸿蒙系统专属的，`ohos.ark_interop` 库是 OpenHarmony 系统组件，在 Windows/macOS/Linux 上不可用。agentskills-runtime 作为跨平台框架，不能将 ArkTS 互操作作为插件系统的跨平台依赖。

**跨平台动态加载的主力通道是 `PackageInfo.load()`**——这是仓颉标准库 `std.reflect` 的原生能力，全平台可用，有官方文档和示例支撑。ArkTS 互操作作为鸿蒙场景的增强通道，通过条件编译隔离，不影响跨平台基线。

**修正后的插件系统设计**：L1（全平台基线）+ L2 仓颉动态库（全平台增强）+ L2 ArkTS 桥（鸿蒙专属增强）+ L2 WASM（v1.1+ 全平台安全隔离）。

---

架构师补充需求：
1）请阅读D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\docs\uctoo-v4\uctoo-v4-module-development.md ，并详细研究一下agentskills-runtime 中的已有的标准数据库crud模块机制。D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\sql\uctooDB.sql 这个文件是现有系统中所有的数据库表结构。可以看到很多表其实是冗余的，目前在runtime项目中并没有用到，他们是各个业务子系统的表，runtime项目能够正常运行的最小模块保留大致只需要RBAC模块。我希望新开发的插件机制可以覆盖已有的模块机制的全部功能特性。也就是说目前的模块机制的代码，可以不用物理上都放置到D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\src\app 目录中，而是可以通过插件机制，分布到各个skills的scripts目录中，编译的时候，这些分布在各个skills\scripts中的模块代码可以正确的编译，可能需要详细研究仓颉的编译机制，目前架构师已知的限制条件是仓颉的cjpm如果没有检测到目录中有.cj文件，则不会再进一步扫描子目录，例如，D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\src\app\controllers 目录中需要有一个占位的D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\src\app\controllers\pkg.cj才能继续扫描编译各子目录中的.cj源码。最终发布时可以正确的用D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\src\scripts\package_release打包进D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\release 中进行发布，相应的现有版本的package_release打包工具应该需要进行适配插件机制的迭代。运行的时候，对api的请求可以正确的路由到各个skills\scripts中的仓颉模块进行响应提供服务。
如果能够实现以上机制，那我们agentskills-runtime的插件机制也就非常接近甚至超越deepseek-harness的一切皆插件理念了，我们可以用“一切皆技能”的叙事，更高一个段位的进行推广，真正实现了AI Native架构，也能更有利于开源开发者合作众创发展插件生态和技能生态。请将研究结果补充到D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime\docs\ref\cangjie-plugin-system-feasibility.md 文档末尾

## 附篇七：模块机制插件化覆盖——"一切皆技能"架构方案

> 架构师补充需求：将现有标准 CRUD 模块机制纳入插件体系，模块代码从 `src/app` 集中部署改为分布到各 skill 的 `scripts` 目录，编译时正确编译，发布时正确打包，运行时 API 请求正确路由到分布式模块。目标：接近甚至超越 deepseek-harness 的"一切皆插件"理念，用"一切皆技能"的更高维度叙事推广。

### 附7.1 现有模块机制全景

#### 附7.1.1 五层 CRUD 架构

每个数据库表对应一个完整模块，遵循 `uctoo-v4-module-development.md` 规范：

| 层 | 目录约定 | 职责 | 代码量（当前项目） |
|---|---|---|---|
| Model | `src/app/models/uctoo/{Table}PO.cj` | 持久化对象 + JSON 序列化 + ORM 注解 | 69 个文件 |
| DAO | `src/app/dao/uctoo/{Table}DAO.cj` | 数据访问层（Fountain ORM `setSql`） | 69 个文件 |
| Service | `src/app/services/uctoo/{Table}Service.cj` | 业务逻辑 + 查询构建 | 182 个文件（含非 CRUD） |
| Controller | `src/app/controllers/uctoo/{table}/{Table}Controller.cj` | HTTP 请求处理 + 参数映射 | 97 个文件 |
| Route | `src/app/routes/uctoo/{table}/{Table}Route.cj` | 路由注册 + 路径映射 | 83 个文件 |

**代码生成工具链**：`loaddbinfo`（数据库结构→db_info 表）→ `crudgen`（生成五层代码）→ `crudweb`（生成前端），均通过 `cjpm run` 运行，从 `db_info` 表读取表结构自动生成。

**AutoCreateCode 区域机制**：`//#region AutoCreateCode` / `//#endregion AutoCreateCode` 标识自动生成区域，区域外的定制代码在重新生成时保留——这是模块代码"确定性生成 + 个性化扩展"共存的关键设计。

#### 附7.1.2 路由注册机制

当前路由注册是一个**硬编码的集中式注册器**：

```
main.cj → AutoRouteRegistry.registerAllRoutes()
         → RouteRegistry.registerAll(router)
         → 遍历 AutoRouteConfig.initRegistry() 注册的 RouteEntry 列表
         → 每个 RouteEntry 调用 registerFunc(router)
         → registerFunc 内部: new Controller(new Service()) → new Route(router, controller).register()
```

**关键文件**：
- `src/app/registry/AutoRouteConfig.cj`（1364 行）——由 crudgen 自动生成维护，硬编码 import 所有 Route/Controller/Service 类，逐条注册到 `RouteRegistry`
- `src/app/registry/RouteRegistry.cj`——按 priority 排序后遍历调用 `registerFunc`
- `src/app/registry/AutoRouteRegistry.cj`——入口，还注册认证路由和 MCP 路由

**核心限制**：每新增一个 CRUD 模块，`AutoRouteConfig.cj` 就需要追加 import + 注册条目。虽然 crudgen 自动完成，但这是**编译期静态绑定**——所有 Controller/Route 类必须在编译时已知。

#### 附7.1.3 pkg.cj 占位机制（cjpm 编译约束）

仓颉 cjpm 的包扫描规则（官方文档 `project_management` Skill §4.1 原文）：

> **有效源包**：目录须直接包含至少一个 `.cj` 文件；所有父包（直到根包）也须为有效源包；无 `.cj` 文件的目录及其子目录被忽略（带警告）。

项目现有 13 个 `pkg.cj` 占位文件，分布于 `src/app/controllers/`、`src/app/routes/`、`src/app/models/`、`src/app/dao/`、`src/app/services/` 等层级目录。内容仅为 `package magic.app.xxx` 声明 + 注释，无实际代码，纯粹为了让 cjpm 继续扫描子目录。

**`cjpm.toml` 关键配置**：`src-dir = ""`（根目录就是 src 的父目录），`output-type = "static"`，包名 `magic`。所有子包声明为 `magic.app.xxx`、`magic.skill.xxx` 等。

### 附7.2 数据库表结构分析

#### 附7.2.1 表规模对比

| 维度 | 数量 | 说明 |
|---|---|---|
| SQL 文件总表数 | 195 | `uctooDB.sql` 完整导出 |
| runtime 实际使用的表 | 69 | DAO 层 `from` 语句引用的去重表 |
| 冗余表（未使用） | 126 | 各业务子系统表，runtime 不需要 |

#### 附7.2.2 RBAC 最小运行集（9 张表）

| 表名 | 用途 |
|---|---|
| `uctoo_user` | 用户账号 |
| `uctoo_role` | 角色定义 |
| `uctoo_session` | 会话管理 |
| `permissions` | 权限节点 |
| `role_has_permission` | 角色-权限关联 |
| `user_has_roles` | 用户-角色关联 |
| `user_group` | 用户组 |
| `group_has_permission` | 组-权限关联 |
| `user_has_group` | 用户-组关联 |

加上 `db_info`（代码生成工具依赖）、`operate_log`、`login_log` 等系统表，runtime 最小运行集约 15-20 张表。其余 50+ 张表是 Agent/技能/AIP/同步/定时任务等核心功能表，126 张冗余表属于小程序商城（minishop_*）、CMS（cms_*）、微信（wechat*）、CRM（crm_*）等业务子系统。

#### 附7.2.3 冗余表分类

| 子系统 | 表前缀 | 约表数 | 说明 |
|---|---|---|---|
| 小程序商城 | `minishop_*` | ~40 | 商品/订单/物流/营销 |
| CMS 内容管理 | `cms_*` | ~12 | 文章/栏目/表单/模型 |
| 微信生态 | `wechat*` / `wechatopen*` | ~16 | 公众号/小程序/素材/模板 |
| 支付 | `unipay*` / `wechatpay_*` | ~5 | 支付配置/交易 |
| CRM | `crm_*` | ~3 | 名片/拜访 |
| 用户增值 | `user_wallet*` / `user_sign` / `user_messages` | ~8 | 钱包/签到/消息 |
| 其他 | `developer*` / `codelabs*` / `vue_editor*` / `tag` / `link*` | ~42 | 开发者/教程/编辑器/标签 |

**结论**：这 126 张表对应的模块代码如果也放在 `src/app` 中，会显著增大编译体积和维护负担。插件化后，这些业务子系统的模块代码应该可以独立分发，按需安装。

### 附7.3 仓颉编译机制与插件化编译方案

#### 附7.3.1 编译机制关键约束

1. **目录扫描规则**：cjpm 只扫描直接包含 `.cj` 文件的目录。如果目录 A 下没有 `.cj` 文件，则 A 的子目录不会被扫描——即使子目录中有 `.cj` 文件。
2. **包声明映射**：每个 `.cj` 文件的 `package` 声明必须与目录路径匹配。例如 `src/app/controllers/uctoo/entity/EntityController.cj` 的包声明是 `magic.app.controllers.uctoo.entity`。
3. **`build.cj` 钩子**：cjpm 支持 `pre-build` / `post-build` 钩子，项目已有 `build.cj`（pre-build 下载 stdx，post-build 调用 package_release）。
4. **`src-dir = ""`**：当前项目根目录就是模块根，`src/` 是源码目录，`src/pkg.cj` 声明根包 `magic`。

#### 附7.3.2 插件化目录结构设计

> ⚠️ **本节方案已被附7.8修正**：`src/skill/plugins/` 会与项目根目录既有的 `skills/`（技能资产目录）分裂，且污染 SkillEngine 引擎包（magic.skill）。修正后的目标方案是技能升格为独立 cjpm 包留在 `skills/{name}/`（附7.8.1 方案二），过渡方案为构建期同步（附7.8.1 方案三）。以下原文保留供对照。

目标：模块代码从 `src/app/` 分布到各 skill 的 `scripts/` 目录，编译时 cjpm 能正确扫描。

```
src/
├── pkg.cj                         # 根包 magic
├── app/                           # 核心框架（仅保留 RBAC + 框架基础设施）
│   ├── pkg.cj                     # magic.app
│   ├── core/                      # HTTP/Routing/Middleware/ORM 核心
│   ├── registry/                  # 路由注册器（改造为动态发现）
│   ├── models/uctoo/              # RBAC 模型（核心保留）
│   ├── dao/uctoo/                 # RBAC DAO（核心保留）
│   ├── services/uctoo/            # RBAC 服务（核心保留）
│   ├── controllers/uctoo/         # RBAC 控制器（核心保留）
│   └── routes/uctoo/              # RBAC 路由（核心保留）
├── skill/
│   ├── pkg.cj                     # magic.skill
│   ├── ...（现有 skill 框架代码）
│   └── plugins/                   # 插件化技能模块目录（新增）
│       ├── pkg.cj                 # magic.skill.plugins（占位）
│       └── {skill-name}/          # 每个技能一个目录
│           ├── scripts/
│           │   ├── pkg.cj         # magic.skill.plugins.{name}.scripts（占位）
│           │   ├── models/        # Model 层
│           │   │   └── pkg.cj     # 占位
│           │   ├── dao/           # DAO 层
│           │   │   └── pkg.cj     # 占位
│           │   ├── services/      # Service 层
│           │   │   └── pkg.cj     # 占位
│           │   ├── controllers/   # Controller 层
│           │   │   └── pkg.cj     # 占位
│           │   └── routes/        # Route 层
│           │       └── pkg.cj     # 占位
│           ├── SKILL.md           # 技能定义文件
│           └── plugin.yaml        # 插件清单（name/version/dependencies/tables）
```

#### 附7.3.3 编译可行性分析

**cjpm 目录扫描链**：

```
src/pkg.cj (magic) 
  → src/skill/pkg.cj (magic.skill)
    → src/skill/plugins/pkg.cj (magic.skill.plugins)
      → src/skill/plugins/{name}/scripts/pkg.cj (magic.skill.plugins.{name}.scripts)
        → src/skill/plugins/{name}/scripts/models/pkg.cj (magic.skill.plugins.{name}.scripts.models)
          → src/skill/plugins/{name}/scripts/models/{Table}PO.cj
```

每一级目录都有 `pkg.cj` 占位文件，cjpm 会递归扫描到最底层的 `.cj` 源码文件。**关键点**：仓颉的包名用 `.` 分隔，与目录路径一致——`magic.skill.plugins.entitygen.scripts.models` 对应 `src/skill/plugins/entitygen/scripts/models/` 目录。

**import 路径**：插件模块间引用通过标准 import：
```cangjie
import magic.skill.plugins.entitygen.scripts.models.EntityPO
import magic.skill.plugins.entitygen.scripts.dao.EntityDAO
import magic.skill.plugins.entitygen.scripts.services.EntityService
```

**跨插件引用**（依赖声明）：通过 `plugin.yaml` 中的 `dependencies` 声明，编译时 build.cj 钩子校验依赖目录存在。

**增量编译**：cjpm 支持 `-i`/`--incremental` 包级增量编译。新增插件的 `.cj` 文件只会触发该包及其依赖包的重新编译，不影响其他插件。

#### 附7.3.4 build.cj 钩子增强

现有 `build.cj` 已有 `pre-build`（下载 stdx）和 `post-build`（调用 package_release）。增加插件化编译的预处理步骤：

```
pre-build:
  1. 下载 stdx（现有）
  2. 扫描 src/skill/plugins/*/plugin.yaml（新增）
  3. 校验每个插件的 pkg.cj 占位文件存在（新增）
  4. 为缺失 pkg.cj 的目录自动生成占位文件（新增）
  5. 生成插件注册清单（plugin_manifest.cj）（新增）
```

### 附7.4 API 路由动态注册方案

#### 附7.4.1 当前方案的问题

当前 `AutoRouteConfig.cj`（1364 行）是 crudgen 自动生成的硬编码文件，每新增一个模块就追加 import + 注册条目。问题：
- 所有模块的 Controller/Route 类在编译时必须已知
- 新增模块需要修改 `AutoRouteConfig.cj` 并重新编译
- 126 张冗余表对应的模块如果都在 `src/app` 中，这个文件会膨胀到不可维护

#### 附7.4.2 反射动态注册方案

利用已验证的反射闭环（`ClassTypeInfo.get` → `findAnnotation` → `ConstructorInfo.apply`），将路由注册从硬编码改为运行时反射发现：

**步骤一：定义 `@ModuleRoute` 注解**

```cangjie
@Annotation
public class ModuleRouteAnnotation {
    public let basePath: String        // 路由前缀，如 "/api/v1/uctoo/entity"
    public let table: String           // 数据库表名
    public let database: String        // 数据库名，如 "uctoo"
    public let controllerClass: String // 控制器全限定类名

    public const init(
        basePath: String,
        table: String,
        database: String,
        controllerClass: String
    )
}
```

**步骤二：每个插件的 Route 类标注注解**

```cangjie
@ModuleRouteAnnotation[
    basePath: "/api/v1/uctoo/entity",
    table: "entity",
    database: "uctoo",
    controllerClass: "magic.skill.plugins.entitygen.scripts.controllers.EntityController"
]
public class EntityRoute {
    public func register(router: Router, controller: Any): Unit { ... }
}
```

**步骤三：PluginRouteScanner 运行时扫描注册**

```cangjie
public class PluginRouteScanner {
    /// 从 plugin.yaml 注册表扫描所有声明的 Route 类
    /// 对每个 Route 类：ClassTypeInfo.get → findAnnotation<ModuleRouteAnnotation>
    /// → ConstructorInfo.apply 实例化 → 调用 register(router, controller)
    public func scanAndRegister(router: Router, pluginManager: PluginManager): Unit
}
```

**步骤四：Application 启动流程改造**

```cangjie
// main.cj 中的改造
let registry = AutoRouteRegistry(router, skillManager, chatModel)
registry.registerCoreRoutes()        // 仅注册 RBAC + 认证 + MCP 核心路由
let scanner = PluginRouteScanner()
scanner.scanAndRegister(router, pluginManager)  // 动态注册插件路由
```

#### 附7.4.3 与现有 AutoRouteConfig 的兼容

- **过渡期**：`AutoRouteConfig.cj` 继续保留，注册 RBAC 和核心模块路由。插件化的模块通过 `PluginRouteScanner` 动态注册。两套机制并存。
- **迁移完成**：所有模块迁移到 `skill/plugins/` 后，`AutoRouteConfig.cj` 退化为仅注册框架核心路由（认证/MCP/AI），或被完全替换。
- **crudgen 适配**：crudgen 生成代码时输出到 `skill/plugins/{name}/scripts/` 而非 `src/app/`，并自动生成 `plugin.yaml` 和 `pkg.cj` 占位文件。

### 附7.5 package_release 打包工具适配

#### 附7.5.1 当前实现分析

`src/scripts/package_release/main.cj`（971 行）的核心流程：

1. 从 `cjpm.toml` 读取版本号
2. 扫描 `target/release/magic/` 目录，复制所有 `.dll`/`.so`/`.dylib` 到 `bin/`
3. 排除 `examples`/`tests` 目录的产物
4. 复制依赖库（f_orm/f_data/logcj 等 20+ 个依赖）
5. 复制 stdx 和 cangjie 运行时库
6. 复制所有 `.cjo` 文件到 `bin/`
7. 创建入口 `agentskills-runtime.exe`（复制 `magic.app.exe`）
8. 复制 `.env.example`，创建 `ssl/` 和 `logs/` 目录
9. 打包为 `agentskills-runtime-{platform}.tar.gz`

#### 附7.5.2 需要适配的变更

| 变更项 | 说明 |
|---|---|
| **插件产物识别** | `target/release/magic/skill/plugins/` 目录下的 `.cjo`/`.dll` 需要被正确收集 |
| **插件清单打包** | 将 `plugin.yaml` 清单文件打包到 `bin/plugins/` 目录，供运行时扫描 |
| **插件目录结构保持** | 发布包中保持 `plugins/{name}/` 目录结构，便于按需启用/禁用 |
| **排除规则适配** | `shouldExcludeDll` 函数增加对禁用插件的排除逻辑 |
| **插件清单生成** | post-build 阶段生成 `plugin_manifest.json`，记录所有已编译插件的元信息 |

**核心变更点**：package_release 的 `Directory.walk` 逻辑已经递归扫描整个 `magic/` 目录，插件化后的 `.cjo`/`.dll` 产物会自动被收集（因为它们在 `target/release/magic/skill/plugins/` 下）。**主要变更是增加插件清单的打包和插件目录结构的保持**。

#### 附7.5.3 发布包目录结构（适配后）

```
release/
├── bin/
│   ├── agentskills-runtime.exe      # 入口
│   ├── *.dll / *.so / *.dylib       # 所有动态库（框架 + 插件）
│   ├── *.cjo                         # 所有编译产物（框架 + 插件）
│   ├── .env.example
│   ├── ssl/
│   ├── logs/
│   └── plugins/                      # 插件清单目录（新增）
│       ├── plugin_manifest.json      # 插件注册清单
│       ├── entitygen/
│       │   └── plugin.yaml           # 插件元信息
│       ├── aip/
│       │   └── plugin.yaml
│       └── ...
├── magic/                            # 运行时模块
├── f_orm/                            # ORM 框架
└── ...
```

### 附7.6 "一切皆技能"叙事定位

#### 附7.6.1 与 deepseek-harness "一切皆插件"的对比

| 维度 | deepseek-harness "一切皆插件" | agentskills-runtime "一切皆技能" |
|---|---|---|
| 基本单位 | 插件（Plugin = 代码单元） | 技能（Skill = AI 行为 + 确定性能力） |
| 插件内涵 | 纯代码插件（JS/TS 模块） | 技能 = SKILL.md（AI 行为定义）+ scripts/（确定性代码模块）+ plugin.yaml（插件清单） |
| AI 关系 | 插件是工具，AI 调用插件 | 技能本身包含 AI 行为，AI 是技能的组成部分 |
| CRUD 模块 | 插件即 CRUD 模块 | CRUD 模块是技能的 scripts/ 子目录 |
| 叙事高度 | "一切皆插件"——代码组装 | "一切皆技能"——AI 行为 + 代码组装 |

**核心差异**：dsh 的"一切皆插件"是**代码组织层面的统一**——所有功能都是插件。agentskills-runtime 的"一切皆技能"是**AI 与代码的统一**——每个功能单元既是 AI 可理解的行为（SKILL.md），又是可执行的代码（scripts/），还是可管理的插件（plugin.yaml）。三维一体，比 dsh 高一个维度。

#### 附7.6.2 AI Native 架构实现路径

```
┌─────────────────────────────────────────────────────┐
│              AGENTS.md (动态编排入口)                  │
│         AI 读取 → 选择技能 → 编排执行                  │
├─────────────────────────────────────────────────────┤
│  Skill A              Skill B              Skill C   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────┐│
│  │ SKILL.md    │     │ SKILL.md    │     │SKILL.md ││
│  │ (AI 行为)    │     │ (AI 行为)    │     │(AI 行为) ││
│  ├─────────────┤     ├─────────────┤     ├─────────┤│
│  │ scripts/    │     │ scripts/    │     │scripts/ ││
│  │ ├─models/   │     │ ├─models/   │     │...      ││
│  │ ├─dao/      │     │ ├─dao/      │     │         ││
│  │ ├─services/ │     │ ├─services/ │     │         ││
│  │ ├─control/  │     │ ├─control/  │     │         ││
│  │ └─routes/   │     │ └─routes/   │     │         ││
│  ├─────────────┤     ├─────────────┤     ├─────────┤│
│  │plugin.yaml  │     │plugin.yaml  │     │plugin   ││
│  │(插件清单)    │     │(插件清单)    │     │.yaml    ││
│  └─────────────┘     └─────────────┘     └─────────┘│
│                                                      │
│  每个技能 = AI 行为 + CRUD 模块 + 插件清单             │
│  编译时: cjpm 递归扫描 scripts/ 编译为 .cjo           │
│  运行时: PluginRouteScanner 反射注册 API 路由         │
│  AI 层:  SkillEngine 加载 SKILL.md 编排执行           │
└─────────────────────────────────────────────────────┘
```

#### 附7.6.3 开源生态价值

1. **开发者众创**：每个技能是自包含的目录（SKILL.md + scripts/ + plugin.yaml），可以独立 Git 仓库分发，clone 到 `skill/plugins/` 下即可集成。
2. **crudgen 输出适配**：crudgen 生成的代码直接输出到 `skill/plugins/{table_name}/scripts/`，同时生成 SKILL.md 模板和 plugin.yaml——**从数据库表到 AI 技能的一键转化**。
3. **技能市场**：插件清单（plugin.yaml）标准化后，可以建立类似 npm/cordis 的技能注册中心，开发者发布技能包，用户按需安装。
4. **AI 自进化**：AI 通过 AGENTS.md 编排技能时，如果发现缺失能力，可以调用 crudgen 从数据库表生成新技能模块——**AI 自己创建新的 CRUD 技能并注册路由**。

### 附7.7 可行性结论与实施路线

#### 附7.7.1 可行性判定

| 维度 | 结论 | 依据 |
|---|---|---|
| 编译可行性 | ✅ 可行 | pkg.cj 占位机制已验证（项目 13 个占位文件正常运行）；cjpm 递归扫描只要每级目录有 .cj 文件即可 |
| 路由动态注册 | ✅ 可行 | 反射闭环已验证（ClassTypeInfo.get + findAnnotation + ConstructorInfo.apply）；现有 RouteRegistry 已支持 registerFunc 回调模式 |
| 打包适配 | ✅ 可行 | package_release 已递归扫描 target/release/magic/ 全目录，插件产物自动收集；主要变更是插件清单打包 |
| 模块迁移 | ✅ 可行 | 五层 CRUD 代码结构不变，只是物理位置从 src/app/ 移到 skill/plugins/{name}/scripts/，包声明从 magic.app.xxx 改为 magic.skill.plugins.{name}.scripts.xxx |
| crudgen 适配 | ✅ 可行 | crudgen 已支持 `--output` 参数，改默认输出路径 + 生成 pkg.cj 占位 + plugin.yaml 即可 |

#### 附7.7.2 实施路线图

> ⚠️ **本路标已被附7.9修订**：存量 `src/app` 模块不迁移、不重构（它们是 harness 与框架运行的核心），插件机制仅面向未来新插件开发。阶段二/阶段三的"存量迁移"目标已取消，修订后的路标见附7.9.2。以下原文保留供对照。

**阶段一（v0.1 插件框架 + RBAC 核心保留）**：
- 实现 Plugin 接口 / @Plugin 注解 / PluginManager / PluginRouteScanner（按 SDD spec/design/tasks 执行）
- 将 RBAC 9 张表的模块保留在 `src/app/` 中（核心框架的一部分）
- `AutoRouteConfig.cj` 保留，仅注册核心路由

**阶段二（v0.2 模块迁移验证）**：
- 选一个非核心模块（如 `entity` 表）迁移到 `skill/plugins/entitygen/scripts/`
- 验证编译、路由注册、API 响应全链路
- 适配 crudgen 输出到 `skill/plugins/` 目录
- 适配 package_release 打包插件产物

**阶段三（v0.3 批量迁移 + 清理）**：
- 将 69 个已使用表对应的模块分批迁移到 `skill/plugins/`
- 每个模块生成 SKILL.md + plugin.yaml
- 清理 `src/app/` 中迁移后的代码
- `AutoRouteConfig.cj` 退化为仅注册框架核心路由

**阶段四（v1.0 "一切皆技能" 生态）**：
- 技能市场原型（plugin registry + install/search/activate/deactivate 工具）
- crudgen 一键生成完整技能包（SKILL.md + scripts/ + plugin.yaml）
- AI 自进化闭环：AI 发现缺失能力 → 调用 crudgen 生成技能 → 自动注册路由

#### 附7.7.3 风险与限制

1. **包名迁移工作量**：69 个模块的包声明从 `magic.app.xxx` 改为 `magic.skill.plugins.{name}.scripts.xxx`，涉及大量 import 语句修改。建议编写迁移脚本自动化。
2. **AutoRouteConfig 过渡期维护**：迁移期间两套路由注册机制并存，需要确保路由不重复注册（HTTPServer 已有去重逻辑）。
3. **反射性能**：运行时反射注册路由相比编译期硬编码有微小性能开销，但只在启动时执行一次，运行时无影响。
4. **crudgen 迁移**：crudgen 代码生成器需要适配新的输出路径和文件结构（生成 pkg.cj 占位 + plugin.yaml），但生成逻辑本身不变。

### 附7.8 修正：技能插件目录归属——为什么不是根目录 skills/

> 架构师质询：附7.3.2 把插件目录设计为 `src/skill/plugins/`，而项目中真实存在的技能资产目录是项目根的 `skills/`（20+ 个技能：crud-generator、sdd-flow、cangjie-coder 等，各含 SKILL.md / templates / scripts / references，目前 0 个 .cj 文件）。`src/skill/` 则是 SkillEngine 框架源码包（magic.skill）。这合理吗？

**自查结论：附7.3.2 的设计是一个只顾编译约束、忽略了目录语义的错误选择，本节予以修正。**

两个目录的身份完全不同：

| 目录 | 身份 | 性质 |
|---|---|---|
| `skills/`（项目根） | 运行时技能资产目录，"一切皆技能"的家 | 数据资产，SkillEngine 从这里加载，从不参与编译 |
| `src/skill/` | SkillEngine 引擎源码（magic.skill 包） | 框架代码，参与编译 |

附7.3.2 的问题：(1) 把技能实例塞进了引擎包，污染 `magic.skill` 的语义边界；(2) 在 src 树里制造了"第二个技能之家"，与根目录 `skills/` 并存分裂——技能要么搬家离开 skills/，要么 SKILL.md 与可编译代码分居两地；(3) 与"一切皆技能"叙事直接矛盾：叙事说一切归 skills/，机制上却另起炉灶。

编译约束本身是真的：cjpm 只编译 src 源码树（magic 包），根目录 `skills/` 永不参与编译。修正方案有三条路：

#### 附7.8.1 方案对比

**方案一（附7.3.2 原案，应废弃）**：`src/skill/plugins/{name}/` 整棵技能树进 src。
- 优点：零构建改动，编译立刻通过。
- 缺点：如上三条，且 20+ 个现有技能是否也要搬进 src？不搬则双标准，搬则 skills/ 目录废弃——两难。

**方案二（目标态，推荐）：技能升格为独立 cjpm 包，物理上完整留在 `skills/{name}/`**。

项目已有完全同构的先例：`cjpm.toml` 的 `[dependencies]` 里 20+ 个 path 依赖（libs/yaml4cj、libs/f_orm、libs/json4cj…），每个都是"目录 + 自己的 cjpm.toml"的独立包。照此，含插件的技能目录结构为：

```
skills/
└── entitygen/                 # 技能完整地在一个目录里
    ├── cjpm.toml              # 独立包声明（name = "skill_entitygen"）
    ├── SKILL.md
    ├── plugin.yaml
    ├── templates/ assets/ references/   # 数据资产（不编译）
    └── scripts/
        └── src/
            ├── pkg.cj
            ├── models/ dao/ services/ controllers/ routes/
```

根 cjpm.toml 只需追加一行 `skill_entitygen = { path = "./skills/entitygen" }`（可由 skill-creator / find-skills 技能自动化，或由 build.cj pre-build 钩子扫描 skills/*/cjpm.toml 自动写入）。

- 优点：技能物理完整（SKILL.md + 代码 + 清单同目录）；独立版本化、独立编译缓存；与 libs/ 生态模型完全一致；最接近 npm/cordis 的插件包模型，为未来独立分发（git clone 即安装）铺路；"一切皆技能"在物理目录层面成立。
- **代价（必须诚实指出）**：cjpm 依赖是单向的——技能插件包**不能 import 根包 magic**。当前 Controller/Route 基类、Plugin 接口、事件总线都在 magic 包内，必须先把插件面向的稳定 API（Plugin SPI、@Plugin 注解、Controller/Route 基类、PluginEventBus 接口）抽取为独立基础包（如 `libs/plugin-spi`），根包和技能插件包都依赖它。这是一次真正的架构重构，但方向与 npm 生态完全一致——插件依赖独立发布的 API 包，而非宿主本体。反射发现（ClassTypeInfo.get 按包名跨包查类型）在链接后同样有效，路由动态注册方案（附7.4）不受影响。

**方案三（过渡态）：canonical 代码在 `skills/{name}/scripts/cj/`，构建期同步到 src 生成目录**。

build.cj 的 pre-build 钩子把 `skills/{name}/scripts/cj/` 复制到 `src/generated/skill-plugins/{name}/`（并自动生成 pkg.cj 占位与包声明映射），代码仍属于 magic 包。

- 优点：无依赖方向问题，SPI 不用抽取，改动最小，可先行落地验证附7.4~附7.6 的全链路。
- 缺点：双路径（源路径与生成路径），IDE 跳转落到生成目录，开发者需理解同步机制。

#### 附7.8.2 修正后的结论

| 阶段 | 方案 | 理由 |
|---|---|---|
| 短期（阶段二单模块验证） | 方案三 | 最小改动跑通编译→路由→打包全链路 |
| 中期（阶段三批量迁移前） | 方案二 | 先做 SPI 抽取重构（这本身就是 SDD plugin-system 的 PS-T001~T005 接口设计的正确归位），再批量迁移 |
| 长期（v1.0 生态） | 方案二 + 技能市场 | git clone / 市场下载到 skills/ 即装，"一切皆技能"物理成立 |

方案一不再作为选项。SDD（.codeartsdoer/specs/plugin-system）的接口设计（Plugin/@Plugin/PluginManager/事件总线）在三个方案中通用，但落地目录以本节修正为准；实施路线图（附7.7.2）中"迁移到 skill/plugins/"的表述统一理解为"迁移到 skills/{name}/scripts/（方案二）或经构建同步等效落地（方案三）"。

#### 附7.8.3 一个补充澄清

`skills/*/scripts/` 目前存放的是 SKILL.md 体系里的脚本资产（按 AgentSkills 规范，scripts/ 是技能自带的确定性脚本，通常是 python/shell）。方案二/三把仓颉可编译代码也放进 scripts/ 子树，与现有语义兼容——AgentSkills 规范并不限制脚本语言，仓颉代码只是"脚本的一种"，但需按方案二放入 `scripts/src/`（独立包需要自己的 src 布局）或方案三的 `scripts/cj/`（源路径），避免与非编译资产混放。

### 附7.9 决策修订：存量冻结、增量插件化（2026-08-18）

> 架构师指示：`src/app` 已有模块代码不用重构——这些模块大部分与 harness 及框架运行的主要功能相关，先保持目前状态。新开发的插件机制，主要用于未来新插件的开发。

**自查结论：这是对附7.7.2 实施路线的重要简化，本节据此修订路标。**

#### 附7.9.1 决策内容

1. **存量冻结**：`src/app` 下 97 个 controller、83 个 route、69 个 model/dao 全部保持现状，不迁移、不重构、不改包名。`AutoRouteConfig.cj`（1364 行硬编码注册）继续作为存量模块的路由注册机制，**不退化、不拆除**。
2. **增量插件化**：今后所有新能力（新 CRUD 模块、新工具服务、新数据源）一律以插件形式开发，走 `@Plugin` + `plugins.yaml` + `PluginRouteScanner` 通道，不再向 `src/app` 和 `AutoRouteConfig.cj` 追加代码。
3. **取消存量迁移目标**：附7.7.2 的阶段二（选 entity 模块迁移验证）、阶段三（69 个模块批量迁移 + 清理 src/app + AutoRouteConfig 退化）中的"迁移存量"部分全部取消。阶段二的"全链路验证"目标保留，但验证载体从"迁移一个存量模块"改为"开发第一个真实新插件"。
4. **SPI 抽取推迟**：附7.8.1 方案二的前置重构（抽取 `libs/plugin-spi`）不再需要抢先做。存量模块不动，就没有"插件包不能 import 根包"的紧迫问题；SPI 抽取推迟到首个 L2 动态库插件出现时（那时它从"可选"变为"必须"，见附7.9.2 阶段三）。

这个决策和 cordis/npm 的宿主-插件模型是一致的：**harness + 核心 CRUD 模块 = 宿主（host），稳定、整体版本化；插件 = 宿主之上的增量扩展**。deepseek-harness 也是核心 harness 不动、外围插件化。存量模块本来就是"框架本体"的一部分，不是等着被插件化偿还的债务——按附7.7.2 原计划把它们搬进 skills/ 反而是为统一而统一。

#### 附7.9.2 修订后的演进路标

| 阶段 | 版本锚点 | 内容 | 对应任务 |
|---|---|---|---|
| **阶段一：插件框架核心** | v0.5 生产就绪层 | 按 SDD 落地 Plugin/@Plugin/PluginRegistry/PluginLoader/PluginEventBus/plugins.yaml/PluginManager/SkillBridge + 2 个示例插件 + 集成测试。**存量代码零改动**；示例插件 in-tree（src/examples/plugins/）。验证双轨路由并存（插件路由 vs AutoRouteConfig 存量路由，HTTPServer 去重保证无冲突） | SDD PS-T001~T009、T011（P0） |
| **阶段二：增量插件化就位** | v0.6 | ① Agent 自引用工具上线（plugin_inspect/activate/deactivate）；② 新插件标准目录定型为 `skills/{name}/` 三维一体（SKILL.md + scripts/cj/ + plugin.yaml），首用附7.8.1 方案三（build.cj 构建期同步到 src/generated/）；③ crudgen 适配：新生成的表模块默认输出插件形态，不再写入 src/app/AutoRouteConfig；④ 开发第一个真实业务插件完成全链路验证（编译→路由→打包→Agent 调用→启停） | SDD PS-T010、新增 PS-T013 |
| **阶段三：L2 动态加载** | v0.7~v0.9 | 封装 `PackageInfo.load()` 实现运行时加载动态库插件（.so/.dll/.dylib），插件安装不再需要重编宿主。**此时触发 SPI 抽取**：动态库插件编译期不能依赖宿主 magic 包，`libs/plugin-spi`（Plugin 接口/@Plugin 注解/Controller 基类/EventBus 接口）抽取成为硬前置；插件目录从方案三升格为方案二（skills/{name} 独立 cjpm 包） | SDD PS-T012 扩展为完整任务 |
| **阶段四：插件市场** | v1.0 / v1.1 | 插件清单标准化、marketplace 原型、install/search/activate/deactivate 工具链；git clone 到 skills/ 即装，L2 使其真正运行时生效——"一切皆技能"生态在物理目录与运行机制两个层面同时成立 | 另立 SDD（市场基础设施） |

每个阶段有一个明确的**晋级门槛**：阶段一验收 = 集成测试全绿且存量功能回归无损；阶段二验收 = 第一个真实插件不经任何框架代码修改上线；阶段三验收 = 不重编宿主装上一个新插件；阶段四验收 = 第三方开发者可独立发布插件。

#### 附7.9.3 与旧路标（附7.7.2）的差异对照

| 附7.7.2 原计划 | 附7.9 修订后 | 说明 |
|---|---|---|
| 阶段二：迁移 entity 模块到插件目录验证 | 开发第一个**新**插件验证 | 迁移取消；验证目标（编译→路由→打包全链路）不变 |
| 阶段三：69 个模块分批迁移 + 清理 src/app + AutoRouteConfig 退化 | 取消；AutoRouteConfig 只减不增（crudgen 停止追加，人工不再新增） | 双轨长期并存，见附7.9.4 风险 1 |
| SPI 抽取：批量迁移前必须做 | 推迟到阶段三（首个 L2 动态库插件前） | 存量不动则无跨包 import 紧迫性 |
| 附7.8.2 表格"短期方案三 / 中期方案二" | 阶段二用方案三，阶段三升方案二 | 时点后移，路径不变 |
| RBAC 9 表保留在 src/app | 不变，且扩展为"全部存量保留" | 原计划的 RBAC 特例不再特殊 |

#### 附7.9.4 风险与代价（诚实指出）

1. **双轨路由长期并存**：AutoRouteConfig（存量）与 PluginRouteScanner（插件）两套注册机制将长期共存，有认知成本。缓解：文档明确"新能力一律走插件"，AutoRouteConfig 进入只减不增的维护态；两套机制在 RouteRegistry 汇合，HTTPServer 已有去重逻辑兜底。
2. **存量模块的演进决策**：未来某存量模块需要大改时，就地改还是迁插件？给出决策规则：**小修就地改（它是宿主的一部分）；功能重写或扩展以新插件叠加**，待 L2 就绪后自然吸走。避免"一次大重构"冲动。
3. **126 张冗余表**：SQL 中未被 runtime 使用的表与本次决策无关（存量冻结不新增债务），清理另行立项，不挂在插件系统名下。
4. **"一切皆技能"叙事口径微调**：从"把所有存量功能都迁入 skills/"调整为"**宿主 + 技能生态**"——宿主提供确定性基座（dual-drive 的确定性一翼），技能生态承载全部增量扩展（AI 增强的一翼）。这反而更贴合 dual-drive 主张：宿主离了 AI 也是完备框架，插件生态让 AI 有处发力。对外表述时不再宣称"69 个存量模块都是技能"，而是"新能力 100% 以技能形态交付"。

#### 附7.9.5 对 SDD 的影响（2026-08-18 已执行 v2 全面重写，同日 v2.1 修订）

SDD 三份文档（`.codeartsdoer/specs/plugin-system/`）已按全部研究文件全面复核重写：
- spec.md v2：新增 REQ-PS-008（插件路由双轨并存）、REQ-PS-009（skills/{name} 目录与构建集成）、REQ-PS-010~012（L2/SPI 分期）；范围边界固化存量冻结决策。
- design.md v2：新增 §2.5 plugin.yaml 清单格式、§2.6 框架与插件代码位置（magic.plugin vs magic.plugins.{name}）、§2.7 目录结构与 build-sync/独立包分期、§2.8 双轨路由设计、§2.10 Cordis 六语义对照自检；接口清单补 ModuleRouteAnnotation / PluginRouteScanner。
- tasks.md v2：任务 17 项按四阶段重排——阶段一（v0.5）：PS-T001~T009、T011、T014（@ModuleRoute+PluginRouteScanner，双轨验证入阶段一）；阶段二（v0.6）：T010、T013（crudgen 插件输出）、T015（build-sync 构建钩子）、T016（package_release 适配）；阶段三（v0.7~v0.9）：T017（plugin-spi 抽取，硬前置）、T012（L2 动态库原型）。

#### 附7.9.6 v2.1 修订：agent_skills 表复核、skills 同步机制兼容性、plugigen 决策（2026-08-18）

**1. agent_skills 表复核结论：无必须 DDL 变更。** 该表 54 列已具备承载插件技能元数据的全部常用字段（name/version/dependencies JSON/install_path/source_path/runtime_status/scripts_dir_exists/extra_metadata JSON）。插件机制不新建表，但**读写这一张既有表**：PluginState 五态回写 runtime_status；plugin.yaml 特有信息（entry 类全名、tables）合并进 extra_metadata，无需加列。可选拓展（is_plugin 过滤列）留待插件市场阶段按需 ALTER TABLE。

**2. 存量 skills 双向同步机制天然兼容，零改动。** 现有机制（SyncManager + AgentSkillSyncHandler：文件→库按 SKILL.md 解析、source_path 为唯一标识、库→文件只回写 SKILL.md）对插件目录的 SKILL.md 无差别同步，无需修改即工作。插件态回写由**新建 PluginSyncBridge**（src/plugin/，订阅 EventBus 生命周期事件，单向内存→库，回写失败只降级记日志不阻断插件）承担——存量 sync 代码零改动，符合存量冻结红线。反向红线：plugin.yaml 永不被数据库侧覆盖。

**3. crudgen/crudweb 保留不重构，插件生成另建 plugigen。** 原方案"crudgen 新增插件输出模式"取消——crudgen/crudweb 完整保留为**宿主代码通道**（未来宿主功能新增/迭代仍生成到 src/app + 追加 AutoRouteConfig；"只减不增"红线约束的是插件化新业务能力，不约束宿主自身演进）。插件形态生成由**新建 plugigen** 承担（架构同构：TemplateEngine + templates/，位置 src/plugin/tools/plugingen/，从 db_info 读表结构或 --blank 生成 skills/{name}/ 三维一体）。两条生成通道并行独立、模板互不依赖。PS-T013 已改写为 plugigen（1.5 天），新增 PS-T018 PluginSyncBridge（1 天，阶段二）。


