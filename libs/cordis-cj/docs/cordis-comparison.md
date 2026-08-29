# cordis-cj 与 Cordis 4.x 差距对比

> 对比基准：**Cordis 4.0.1**（DeepSeek Harness `vendor/cordis`，即 `@deepseek-ai/cordis`，dsh 实际运行版本）
> 参考源码：`/home/ystyle/Projects/deepseek-harness/vendor/cordis/src/`（context/fiber/registry/reflect/events/service/logger）
> 官方插件：`vendor/{loader,group,include,hmr,timer,logger-console}/`
> 论文：`docs/paper.pdf`（Revertible Effects and Reactive Coeffects）
> 更新日期：2026-02

## 1. Cordis 4.x 能力全景

### 1.1 核心运行时（`@deepseek-ai/cordis`）

| 子系统 | 关键 API | 语义 |
| :--- | :--- | :--- |
| **Context** | `extend(meta)` / `isolate(name,label)` / `intercept(name,config)` / `root` | 上下文即服务仓库；子上下文原型继承；isolate 隔离同名服务作用域；intercept 注入服务级配置 |
| **Fiber** | `effect()` / `dispose()` / `restart()` / `update(config)` / `await()` / `getEffects()` | 插件实例状态机 PENDING→LOADING→ACTIVE→FAILED→UNLOADING→DISPOSED；依赖未满足保持 PENDING 等待 |
| **Registry** | `ctx.plugin(plugin, config)` / `ctx.inject(deps, cb)` / `Inject` 装饰器 | 插件三形态（函数/类/apply 对象）；声明式依赖；`Config` schema 校验 |
| **Reflect** | `ctx.get` / `set` / `provide` / `accessor` / `mixin` | 服务注册与解析；`notify(names)` 依赖变更时自动重载依赖者 fiber |
| **Events** | `on` / `once` / `emit` / `parallel` / `serial` / `bail` / `waterfall` | 5 种派发模式 + 上下文过滤 + prepend/global 选项；事件随 fiber 自动清理 |
| **Service** | `class X extends Service` / `[check]` / `[invoke]` / `[resolveConfig]` | 类即服务：`super(ctx, name)` 自动注册；可用性谓词；可调用服务；拦截配置合并 |
| **Logger** | `ctx.logger(name)` | 命名日志器，`%s`/`%C` 格式化，彩色输出 |

### 1.2 官方插件（Cordis 生态）

| 插件 | 职责 |
| :--- | :--- |
| `loader` | 配置驱动加载：EntryTree/EntryGroup、config 持久化回写、`!!js` 表达式插值、inject 合并 |
| `group` | 嵌套插件组（EntryGroup） |
| `include` | 配置 include 文件（YAML/JSON），配置持久化 |
| `hmr` | 热模块替换：chokidar 监听 + 模块依赖图 + reload |
| `timer` | `ctx.timeout/interval/throttle/debounce` 可撤销定时器 |
| `logger-console` | 控制台日志输出 |

### 1.3 dsh 实际使用规模（packages/ 统计）

- `ctx.effect`：**140 文件**；`ctx.on(`：**223 文件** —— 可逆效果 + 事件是核心范式
- `extends Service`：**134 个**服务子类（ctx.llm / ctx.tools / ctx.sessions ...）
- `ctx.provide`：**178 文件**；`inject:` 声明：**567 处**；`Config =` schema：**136 处**
- 事件模式：`waterfall`/`parallel`/`serial`/`bail`/`once` 全部在用（tool pipeline、agent dispatch、session、UI 等）

## 2. 逐项对比

| # | 能力 | Cordis 4.x | cordis-cj | 差距 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | 依赖未满足 Waiting 重试 | PENDING 状态，服务就绪自动启动 | ✅ Pending 状态 + 重试循环 + notify 唤醒 | 🔴→✅ 已实现 |
| 2 | 依赖变更自动通知重载 | `reflect.notify()` → 依赖者 fiber 重载 | ✅ PROVIDER_CHANGED/DEPENDENCY_LOST 通知 | 🔴→✅ 已实现 |
| 3 | 事件派发模式 | emit / parallel / serial / bail / waterfall | ✅ 全部（含 once/prepend） | 🔴→✅ 已实现 |
| 4 | 事件 `once` / prepend / global / 过滤 | 完整 | 🟡 once/prepend 已实现；global/过滤未做 | 🟡 |
| 4b | 事件 `on<T>` 类型安全 | TS 泛型 | ✅ on<T>/once<T>/onVal<T>/emit<T>/onWaterfall<T> | ✅ 已实现 |
| 4c | 事件 `waterfall` 洋葱 next | next 回调推进链 + veto 短路 | ✅ events/next 跨进程远程回调（§4 P13） | 🔴→✅ 已实现 |
| 5 | Service 基类（类即服务） | 134 个服务子类 | ✅ Service 基类（provide/register/bind/check） | 🟡→✅ 已实现 |
| 6 | Config schema 校验 | standard-schema + ValidationError（含路径） | ✅ ConfigSchema（白名单/类型/必填 + 路径化） | 🟡→✅ 已实现 |
| 7 | Fiber 状态机 | 6 态 + await/restart/update | ✅ awaitActive/restartPlugin/updatePlugin + transitionStatus/onStatusChange（P14） | 🔴→✅ 已实现 |
| 8 | 配置热更新 | loader `internal/update` + 持久化回写 | ✅ 配置传递 + reconcile 检测 config 变更重启 | 🟡→✅ 已实现 |
| 9 | 服务隔离 `isolate` | 同名服务多实现按作用域分隔 | 无 | 🟢 |
| 10 | 服务拦截 `intercept` | 服务级配置合并 | 无 | 🟢 |
| 11 | `accessor` / `mixin` | ctx 属性动态扩展 | 无 | 🟢 |
| 12 | effect 诊断树 `getEffects()` | 效果元数据树 | ✅ effect(label) + getEffects() | 🟢→✅ 已实现 |
| 13 | async / generator effect | 完整 | ✅ effectAsync（disposer 返回 Future，disposeAll 等待完成） | 🟢→✅ 已实现 |
| 13b | timer / 命名 Logger | ctx.timeout/interval + logger(name) | ✅ 全部实现 | ✅ 已实现 |
| 14 | 嵌套插件组 `group` | 支持 | 无 | 🟢 |
| 15 | 配置 include / 继承 | 支持 | 无 | 🟢 |
| 16 | timer 服务 | timeout/interval/throttle/debounce | 无 | 🟢 |
| 17 | 命名 Logger | `ctx.logger(name)` + 格式化 | `ctx.log(level, msg)` | 🟢 |
| 18 | HMR 热重载 | 模块级热替换 | 进程隔离下 HMR=重启（已有崩溃自愈） | ⚪ 不适用 |
| 19 | 进程隔离 | ❌（同进程） | ✅ 卸载杀进程回收资源 | ✅ 优势 |
| 20 | 崩溃自愈 | ❌（进程级） | ✅ | ✅ 优势 |
| 21 | 双传输 stdio/UDS | ❌ | ✅ | ✅ 优势 |
| 22 | 宏零样板（@Plugin/@Provide/@Inject） | 装饰器（TS） | ✅ 仓颉宏 | ✅ 对等 |
| 23 | 泛型类型安全 invoke/registerHandler | TS 类型 | ✅ 仓颉泛型 | ✅ 对等 |
| 24 | 可逆效果（基础） | ✅ | ✅ ctx.effect | ✅ 对等 |

🔴 = 语义核心差距（论文重点 / dsh 高频）｜🟡 = 重要功能差距｜🟢 = 增强性差距｜⚪ = 不适用

## 3. 差距分析（论文视角）

论文《Revertible Effects and Reactive Coeffects》的核心主张与对应状态：

| 论文概念 | 含义 | cordis-cj 状态 |
| :--- | :--- | :--- |
| **Revertible Effects**（§3.1） | 效果可逆：注册即得 disposer，卸载逆序执行 | ✅ 基础已实现（ctx.effect），缺 async/generator/诊断树 |
| **Reactive Coeffects**（§3.2） | 上下文感知依赖：服务规格化 + 变更通知 | 🔴 **半实现**：依赖声明（inject/provide）有，**变更通知（notification）缺失** |
| **Specification and Notification**（§3.2.2） | 服务就绪通知 + 依赖者响应 | 🔴 initialize 一次握手后无持续响应 |
| **Isolation and Interception**（§3.2.3） | 服务作用域隔离 + 配置拦截 | 🔴 未实现 |
| **Context 范式**（§3.3） | 统一上下文，代理解析服务 | 🟡 PluginContext 是简化版（无代理/无 get/set/accessor） |
| **组件生命周期**（§4） | PENDING/LOADING/ACTIVE/FAILED/UNLOADING | 🟡 简化版（Starting/Active/Unloading） |
| **Withdrawal/Iteration/Asynchrony/Failure**（§4.3） | 卸载中的并发转换 | 🟡 未建模（terminate 直接杀进程简化了语义） |
| **声明式配置**（§5.2） | loader + 配置持久化 | 🟡 ConfigLoader + reconcile 有，缺热更新/持久化回写 |
| **HMR**（§5.2.2） | 热替换 | ⚪ 进程隔离下等价为重启 |

## 4. 建议补齐路线（按价值/成本排序）

### 第一阶段：语义核心（✅ 已完成，P9）—— 对齐论文 + dsh 高频

1. ✅ **依赖 Waiting 重试**：initialize 依赖缺失 → 插件保持 PENDING 而非退出；插件侧重试循环 + 宿主置 `InstanceStatus.Pending`（`InstanceStatus.Pending`）
2. ✅ **事件总线 v2**：`emit`（现有）/ `parallel` / `serial` / `bail` / `waterfall` + `once` + `prepend` + 订阅者返回值（`onVal`）—— 宿主聚合派发，对齐 Cordis DispatchMode
3. ✅ **依赖变更通知**：服务提供 → `PROVIDER_CHANGED` 唤醒 Pending 依赖者立即重试；服务撤销 → `DEPENDENCY_LOST` 通知依赖者（对齐 Cordis `reflect.notify`）

### 第二阶段：服务系统完善（✅ 已完成，P10）

4. ✅ **Service 类化**：`cordis_plugin/src/service.cj`——`Service` 抽象基类（类即服务）：构造 `super(ctx, name)` 自动 `ctx.provide`；`register(method, handler)` 注册服务方法；`bind()` 构造末尾接入 invoke 分发（仓颉限制：可继承类构造不能捕获 `this`，故用构造后钩子对齐 Cordis `[Service.init]`）；`check()` 可用性谓词可覆写
5. ✅ **Config schema 校验**：`cordis_core/src/config_schema.cj`——`ConfigFieldSpec`（name/typeName/required）+ `ConfigSchema`（`validate` 宽松 / `validateStrict` 含未知字段检查），类型含 string/bool/int/float/array/object；错误带完整路径（如 `plugins[0].config.port: expected int, got string`）；`PluginHost.registerSchema(pluginId, schema)` + `launchPlugin` 前置校验（失败抛路径化异常）
6. ✅ **配置热更新 + 配置传递**：`InitializeResult.config` 宿主下发 `entry.config`（DataModel→JsonValue），插件侧 `PluginContext.config`（toDataModel 转回）；reconcile 的 `entryChanged` 检测 config 变更 → 重启插件 → 新配置生效（e2e：offset 10→100，add 结果 15→105）

### 第三阶段：增强（✅ 已完成，P11/P12/P13/P14）

7. **`isolate` 服务隔离**：⚪ 不做——进程隔离天然满足（每个插件即独立进程/实例，同名服务多实例即多插件），跨进程作用域隔离意义有限
8. **`intercept` 服务级配置**：⚪ 不做——entry.config 已透传给插件（P10 配置传递），跨进程拦截语义弱
9. **`accessor` / `mixin`**：⚪ 不做——仓颉无 Proxy 机制，PluginContext 为固定类，动态属性扩展不可行
10. ✅ **effect 诊断树 `getEffects()`**：`ServiceRegistry.effect(disposer, label)` + `getEffects(): ArrayList<String>`；`ctx.effect(disposer, label)` + `ctx.getEffects()` 暴露
11. ✅ **timer 工具**：`ctx.timeout/interval/throttle/debounce`（std.sync.Timer，全部可撤销，返回 cancel 函数）
12. ✅ **命名 Logger**：`ctx.logger(name)` → `PluginLogger`（trace/debug/info/warn/error）；`LogParams.logger` 携带来源
13. ✅ **事件 `on<T>` 类型安全**：`ctx.on<T>` / `once<T>` / `onVal<T>`（`T <: JsonDeserializable<T>`，args[0] 自动反序列化）
14. ✅ **发布侧类型安全 `emit<T>`（P12）**：`ctx.emit<T>/parallel<T>/serial<T>/bail<T>/waterfall<T>`（`T <: JsonSerializable`，参数自动序列化，与订阅侧 `on<T>` 配套）
15. ✅ **async effect（P12）**：`ctx.effectAsync(disposer)`（disposer 返回 `Future<Unit>`，disposeAll 逆序执行并 `fut.get()` 等待完成）
16. ✅ **完整 waterfall next 洋葱回调（P13）**：`ctx.onWaterfall(event, (args, next) -> ?JsonValue)`（+ 泛型 `onWaterfall<T>`）——订阅者收到 next 回调，调 `next()` 推进链（最终内置行为），不调直接返回 = veto 短路；跨进程经 `events/next` 远程回调实现（宿主按 emitId 存链状态 + `DispatchParams.nextAllowed`），与 Cordis `waterfall` 语义一致（最外层订阅者返回值 = 链结果，见 design-events.md §7.1）
17. ✅ **Fiber 状态机（P14）**：`PluginHost.awaitActive/restartPlugin/updatePlugin` + `transitionStatus` 统一状态转换入口 + `onStatusChange` 监听（对齐 Cordis `await()/restart()/update()` 与 `internal/status` 事件）——awaitActive 等待 Active 且服务注册完成（重抛启动错误）；restartPlugin 终止重拉；updatePlugin schema 校验后重启；reconcile 热更新复用 updatePlugin；崩溃自愈先标 Failed。详见 design-impl.md §2.2 与 FiberStateTest

### 明确不做

- **模块级 HMR**：进程隔离的卸载=杀进程，插件代码更新只需重启进程（reconcile 已支持），模块热替换与进程隔离架构冲突
- **同进程插件**：论文虽支持（Koishi 场景），但 dsh 需要进程沙箱（landlock），保持进程隔离是正确选择

## 5. 参考

- dsh vendor/cordis 源码：`/home/ystyle/Projects/deepseek-harness/vendor/cordis/src/`
- dsh cordis 教程：`/home/ystyle/Projects/deepseek-harness/docs/cordis-primer.md`、`docs/cordis-api/`
- Cordis 官方仓库：`/home/ystyle/Projects/Cangjie/ref/cordis/`（cordiverse/cordis，同源）
- 论文：`/home/ystyle/Projects/deepseek-harness/docs/paper.pdf`
