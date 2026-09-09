# 插件轻量化方案

> 版本：v1.0（2026-09-03）
> 状态：方案制定阶段，待实施
> 目标：使 L3 进程插件达到可商业化应用和推广的水平
> 关联：design.md §0.7、spec.md v3.1

## 一、问题背景

### 1.1 当前状态

阶段四 L3 进程隔离轨（cordis-cj 集成）编码完成并测试通过：
- codelabs 插件完整 V4 CRUD 已实现并测试通过（列表/编辑/删除/回收站/创建全部功能正确）
- plugingen 新增 `CrudPluginGenerator` 表驱动生成器
- host.db 服务支持 `$raw:` 前缀约定生成原始 SQL 函数
- 回收站筛选基于 `filter` 查询参数动态构建 WHERE 子句
- `empty-recycle-bin` 路由已实现

### 1.2 核心问题：插件发布包过重

以 codelabs 插件为例，最终编译出的发布包需要将宿主中的大量依赖复制到插件中才能正常运行。

**具体表现**：

| 问题 | 说明 |
|------|------|
| 插件包体积大 | 包含完整 cordis-cj 库、jsonvalue 库、jsonrpc 库等 |
| 依赖重复复制 | 每个插件都包含相同的基础库 |
| 版本管理复杂 | 插件依赖版本需与宿主一致 |
| 分发不便 | 插件包不能简单复制即用 |

**根因分析**：

当前插件编译为独立 cjpm executable 工程，其 `cjpm.toml` 配置如下：

```toml
[dependencies]
  "ystyle::cordis_plugin" = { path = "../../libs/cordis-cj/cordis_plugin" }
  "ystyle::cordis_core" = { path = "../../libs/cordis-cj/cordis_core" }
  "jsonvalue" = { path = "../../libs/jsonvalue" }
  "ystyle::jsonrpc" = { path = "../../libs/jsonrpc" }

[target.x86_64-w64-mingw32.bin-dependencies]
  path-option = ["../../libs/cangjie-stdx-windows-x64-1.1.3.1/windows_x86_64_cjnative/dynamic/stdx"]
```

插件编译时，`path` 依赖指向宿主的 `libs/` 目录。编译产物（`.exe`）静态链接了这些依赖库，导致：

1. 每个 `.exe` 都包含完整的 cordis-cj、jsonvalue、jsonrpc 库代码
2. 插件分发时必须携带这些依赖，否则无法运行
3. 不同插件包含相同依赖的副本，浪费空间

## 二、架构调研

### 2.1 宿主架构（agentskills-runtime）

```
agentskills-runtime/
├── src/
│   ├── app/                    # 宿主存量模块（存量冻结）
│   ├── plugin/                 # 插件系统（框架包 magic.plugin）
│   │   ├── cordis_host_manager.cj      # L3 宿主管理器
│   │   ├── cordis_host_services.cj     # 宿主侧服务代理
│   │   ├── external_plugin_route_gateway.cj  # L3 路由网关
│   │   └── tools/
│   │       ├── plugingen/      # 插件生成器
│   │       └── pluginuninstall/  # 插件卸载工具
│   └── ...
├── skills/                     # 插件目录
│   ├── codelabs/               # L3 进程隔离轨插件
│   └── ...
├── libs/                       # 依赖库（关键目录）
│   ├── cordis-cj/              # cordis-cj 库
│   │   ├── cordis_plugin/      # 插件侧 SDK
│   │   ├── cordis_core/        # 核心库
│   │   └── cordis_host/        # 宿主侧实现
│   ├── jsonvalue/              # JSON 处理库
│   ├── jsonrpc/                # JSON-RPC 协议库
│   └── cangjie-stdx-windows-x64-1.1.3.1/  # 仓颉标准扩展库
└── ...
```

### 2.2 cordis-cj 架构

```
libs/cordis-cj/
├── cordis_plugin/              # 插件侧 SDK（插件依赖）
│   ├── plugin_runtime.cj       # PluginRuntime.run 入口
│   ├── plugin_context.cj       # PluginContext 上下文
│   └── ...
├── cordis_core/                # 核心库（插件+宿主共用）
│   ├── json_value.cj           # JsonValue 类型
│   └── ...
├── cordis_host/                # 宿主侧实现（仅宿主依赖）
│   ├── plugin_manager.cj       # PluginManager(stdio)
│   ├── plugin_host.cj          # PluginHost/reconcile
│   └── ...
└── ...
```

### 2.3 插件编译流程

```
skills/codelabs/
├── cjpm.toml                   # 独立 executable 工程配置
├── src/
│   ├── main.cj                 # PluginRuntime.run 入口
│   ├── handlers.cj             # V4 CRUD handler
│   └── effects.cj              # ctx.effect 可逆效果
└── target/                     # 编译产物
    └── release/
        └── bin/
            └── skill_codelabs.exe  # 独立可执行文件
```

编译命令：`cd skills/codelabs && cjpm build`

产物：`target/release/bin/skill_codelabs.exe`

**问题**：这个 `.exe` 文件静态链接了 cordis-cj、jsonvalue、jsonrpc 等所有依赖，体积庞大。运行时它通过 stdio JSON-RPC 与宿主通信，不直接访问宿主的内存空间。

### 2.4 宿主加载流程

宿主通过 `CordisHostManager` 加载 L3 进程插件：

1. 读取 `plugins.yaml` 中 `mode: process` 的插件配置
2. 通过 `command` 字段定位插件可执行文件路径
3. 使用 `ystyle::cordis_host` 的 `PluginManager(stdio)` 拉起插件进程
4. 通过 stdio JSON-RPC 进行握手、服务注册、invoke 调用
5. 宿主侧注册 `host.db`/`host.log`/`host.cache` 服务 handler
6. 插件进程经 `ctx.invoke` 反向调用宿主服务

**关键点**：宿主通过 `command` 字段定位插件二进制文件。当前配置：

```yaml
command: ./target/release/bin/skill_codelabs.exe
```

这意味着插件二进制文件的路径是相对于插件目录的。

## 三、可行优化方向

### 方向一：插件安装到宿主目录（宿主共享依赖）

**核心思路**：插件安装时不将依赖复制到插件目录，而是将插件二进制复制到宿主中的合适位置运行。宿主提供共享依赖目录，所有插件共享同一份基础库。

**实现方案**：

1. **宿主共享依赖目录**：在宿主根目录创建 `plugins/shared/` 目录，存放所有插件共享的基础库（cordis-cj、jsonvalue、jsonrpc 等）。

2. **插件安装到宿主目录**：插件安装工具将插件二进制复制到 `plugins/{name}/` 目录，而不是在 `skills/{name}/` 目录中独立编译。

3. **共享依赖配置**：插件的 `cjpm.toml` 中 `[target.*.bin-dependencies]` path-option 指向宿主共享目录：

```toml
[target.x86_64-w64-mingw32.bin-dependencies]
  path-option = ["../../../plugins/shared/stdx"]
```

4. **运行时路径**：宿主通过 `plugins.yaml` 的 `command` 字段定位插件二进制：

```yaml
command: ./plugins/{name}/skill_{name}.exe
```

**优点**：
- 最小改动达到轻量化目标
- 所有插件共享同一份基础库，无重复复制
- 版本管理统一（宿主管理基础库版本）

**缺点**：
- 插件安装位置受限（必须在宿主目录树内）
- 插件不能完全独立分发（依赖宿主共享目录）

**实施工作量**：低
- 修改 `plugingen` 生成的 `cjpm.toml` 模板
- 修改 `pluginuninstall` 清理逻辑
- 创建 `plugins/shared/` 目录结构

### 方向二：插件 SDK 精简包

**核心思路**：将 `cordis-cj` 拆分为精简 SDK 和完整宿主实现，插件只依赖精简 SDK。

**实现方案**：

1. **拆分 cordis-cj**：
   - `cordis-plugin-sdk`：精简 SDK，仅含 `PluginRuntime`/`PluginContext`/`HostContext` 等核心接口
   - `cordis-host`：完整宿主实现，仅宿主使用
   - `cordis-core`：核心库（JsonValue 等），插件+宿主共用

2. **插件依赖精简 SDK**：

```toml
[dependencies]
  "ystyle::cordis-plugin-sdk" = { path = "../../libs/cordis-cj/cordis-plugin-sdk" }
  "ystyle::cordis-core" = { path = "../../libs/cordis-cj/cordis_core" }
  "jsonvalue" = { path = "../../libs/jsonvalue" }
```

3. **SDK 静态链接基础库**：精简 SDK 可进一步静态链接基础库，生成单一静态库文件，插件编译时只需链接这一个文件。

**优点**：
- 进一步减小插件体积
- 插件依赖更清晰（只依赖核心接口）

**缺点**：
- 需要重构 cordis-cj 库的包结构
- SDK 版本升级时所有插件需重新编译

**实施工作量**：中
- 重构 cordis-cj 库的包结构
- 修改 `plugingen` 生成的 `cjpm.toml` 模板
- 更新所有现有插件的依赖配置

### 方向三：WASM 沙箱插件（v1.1+ 增强形态）

**核心思路**：插件编译为 WASM 模块，宿主通过 WASM 运行时加载执行。WASM 模块天然轻量（仅含业务逻辑），基础库由宿主 WASM 运行时提供。

**实现方案**：

1. **评估仓颉 WASM 编译能力**：确认仓颉编译器是否支持编译为 WASM 模块。
2. **宿主集成 WASM 运行时**：评估 Wasmtime、Wasmer 等 WASM 运行时的仓颉绑定可行性。
3. **插件编译为 WASM 模块**：插件源码编译为 `.wasm` 文件，宿主通过 WASM 运行时加载执行。
4. **宿主提供 WASM 导入函数**：宿主通过 WASM 导入函数提供 `host.db`/`host.log`/`host.cache` 服务，插件通过 WASM 导出函数提供 handler。

**优点**：
- 极致轻量化（WASM 模块仅含业务逻辑）
- 天然沙箱隔离（WASM 安全模型）
- 跨平台（WASM 模块可在任何 WASM 运行时执行）

**缺点**：
- 技术复杂度高（需评估仓颉 WASM 编译能力）
- 性能开销（WASM 运行时开销）
- 需要大量基础设施工作

**实施工作量**：高
- 评估仓颉 WASM 编译能力
- 集成 WASM 运行时
- 重构插件编译流程
- 实现 WASM 导入/导出函数绑定

## 四、推荐实施路径

| 阶段 | 版本 | 实施方向 | 目标 | 工作量 |
|------|------|----------|------|--------|
| 短期 | v1.0 | 方向一（插件安装到宿主目录） | 最小改动达到轻量化目标 | 低 |
| 中期 | v1.1 | 方向二（插件 SDK 精简包） | 进一步减小插件体积 | 中 |
| 长期 | v1.2+ | 评估方向三（WASM 沙箱插件） | 实现极致轻量化 | 高 |

### 4.1 短期实施计划（方向一）

**目标**：插件安装到宿主目录，共享依赖，减小插件包体积。

**步骤**：

1. **创建宿主共享依赖目录**：
   ```
   plugins/
   ├── shared/                  # 共享依赖目录
   │   ├── cordis-cj/           # cordis-cj 库
   │   ├── jsonvalue/           # jsonvalue 库
   │   ├── jsonrpc/             # jsonrpc 库
   │   └── stdx/                # 仓颉标准扩展库
   └── {name}/                  # 插件安装目录
       └── skill_{name}.exe     # 插件二进制
   ```

2. **修改 plugingen 生成的 cjpm.toml**：
   ```toml
   [target.x86_64-w64-mingw32.bin-dependencies]
     path-option = ["../../../plugins/shared/stdx"]
   ```

3. **修改 plugins.yaml 的 command 字段**：
   ```yaml
   command: ./plugins/{name}/skill_{name}.exe
   ```

4. **创建插件安装工具**（`plugininstall`）：
   - 编译插件：`cd skills/{name} && cjpm build`
   - 复制二进制：`cp target/release/bin/skill_{name}.exe plugins/{name}/`
   - 复制共享依赖（首次安装时）：`cp -r libs/cordis-cj plugins/shared/`
   - 更新 `plugins.yaml`

5. **修改 pluginuninstall 清理逻辑**：
   - 删除 `plugins/{name}/` 目录
   - 不删除 `plugins/shared/` 目录（其他插件可能还在使用）

**预期效果**：

| 指标 | 当前值 | 目标值 |
|------|--------|--------|
| 插件包体积 | ~50MB（含依赖） | ~5MB（仅业务逻辑） |
| 依赖重复复制 | 每个插件都包含基础库 | 宿主共享目录 |
| 版本管理复杂度 | 每个插件独立管理 | 宿主统一管理 |

### 4.2 中期实施计划（方向二）

**目标**：拆分 cordis-cj 为精简 SDK 和完整宿主实现，进一步减小插件体积。

**步骤**：

1. **重构 cordis-cj 库的包结构**：
   ```
   libs/cordis-cj/
   ├── cordis-plugin-sdk/        # 精简 SDK（插件依赖）
   │   ├── plugin_runtime.cj     # PluginRuntime.run 入口
   │   ├── plugin_context.cj     # PluginContext 上下文
   │   └── ...
   ├── cordis-host/              # 完整宿主实现（仅宿主依赖）
   │   ├── plugin_manager.cj     # PluginManager(stdio)
   │   ├── plugin_host.cj        # PluginHost/reconcile
   │   └── ...
   └── cordis-core/              # 核心库（插件+宿主共用）
       ├── json_value.cj         # JsonValue 类型
       └── ...
   ```

2. **修改 plugingen 生成的 cjpm.toml**：
   ```toml
   [dependencies]
     "ystyle::cordis-plugin-sdk" = { path = "../../libs/cordis-cj/cordis-plugin-sdk" }
     "ystyle::cordis-core" = { path = "../../libs/cordis-cj/cordis_core" }
     "jsonvalue" = { path = "../../libs/jsonvalue" }
   ```

3. **更新所有现有插件的依赖配置**。

**预期效果**：

| 指标 | 当前值 | 目标值 |
|------|--------|--------|
| 插件包体积 | ~50MB（含依赖） | ~2MB（精简 SDK） |
| 插件依赖清晰度 | 依赖完整 cordis-cj | 仅依赖核心接口 |

### 4.3 长期实施计划（方向三）

**目标**：评估 WASM 沙箱插件方案，实现极致轻量化。

**步骤**：

1. **评估仓颉 WASM 编译能力**：确认仓颉编译器是否支持编译为 WASM 模块。
2. **评估 WASM 运行时**：评估 Wasmtime、Wasmer 等 WASM 运行时的仓颉绑定可行性。
3. **原型验证**：实现一个最小 WASM 插件原型，验证可行性。
4. **全面实施**：如果原型验证通过，全面实施 WASM 沙箱插件方案。

**预期效果**：

| 指标 | 当前值 | 目标值 |
|------|--------|--------|
| 插件包体积 | ~50MB（含依赖） | ~100KB（WASM 模块） |
| 沙箱隔离 | 进程级隔离 | WASM 安全模型隔离 |
| 跨平台 | 需为每个平台编译 | WASM 模块跨平台 |

## 五、评估指标

| 指标 | 当前值 | 目标值（方向一） | 目标值（方向二） | 目标值（方向三） |
|------|--------|------------------|------------------|------------------|
| 插件包体积 | ~50MB | ~5MB | ~2MB | ~100KB |
| 依赖重复复制 | 每个插件都包含基础库 | 宿主共享目录 | 宿主共享目录 | 无依赖（WASM 运行时提供） |
| 版本管理复杂度 | 每个插件独立管理 | 宿主统一管理 | 宿主统一管理 | 宿主统一管理 |
| 分发便利性 | 需复制依赖 | 需安装到宿主目录 | 需安装到宿主目录 | WASM 模块可直接分发 |
| 沙箱隔离 | 进程级隔离 | 进程级隔离 | 进程级隔离 | WASM 安全模型隔离 |
| 实施工作量 | - | 低 | 中 | 高 |

## 六、风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| 方向一：插件安装位置受限 | 文档明确说明插件必须安装到宿主目录树内 |
| 方向一：共享依赖版本冲突 | 宿主统一管理依赖版本，插件不自带依赖 |
| 方向二：cordis-cj 重构风险 | 保持向后兼容，渐进式重构 |
| 方向二：SDK 版本升级影响 | 提供 SDK 版本兼容性矩阵 |
| 方向三：仓颉 WASM 编译能力未知 | 先进行技术评估，如果不可行则放弃此方向 |
| 方向三：WASM 运行时性能开销 | 进行性能基准测试，评估是否可接受 |

## 七、决策建议

**推荐方案**：短期实施方向一（插件安装到宿主目录），中期实施方向二（插件 SDK 精简包），长期评估方向三（WASM 沙箱插件）。

**理由**：
1. 方向一工作量最低，能立即解决插件包过重的问题
2. 方向二在方向一的基础上进一步优化，渐进式改进
3. 方向三作为长期目标，需要先评估技术可行性

**下一步行动**：
1. 评审本方案，确认实施方向
2. 制定详细实施计划（任务分解、时间节点、验收标准）
3. 分配开发资源，启动实施

---

## 八、plugin-spi 架构研究（2026-09-03 补充）

### 8.1 plugin-spi 库的架构分析

`libs/plugin-spi/` 是阶段三 L2 动态库轨的硬前置——从宿主 `magic.plugin` 包抽出的独立基础包，定义插件面向的稳定 API 契约。

**核心组件**：

| 组件 | 文件 | 职责 |
|------|------|------|
| `Plugin` 接口 | `plugin.cj` | 插件生命周期契约：`getName`/`onLoad`/`onActivate`/`onDeactivate`/`onUnload` |
| `PluginAnnotation` | `plugin_annotation.cj` | `@Annotation` 插件声明注解：`name`/`version`/`dependencies`（逗号分隔 String） |
| `PluginContext` | `plugin_context.cj` | 三合一容器句柄：`ServiceRegistry` + `PluginEventBus` + `PluginSkillBridge` + `config`；`onCleanup` 可逆清理栈 |
| `ServiceRegistry` 接口 | `service_registry.cj` | 服务注册表契约：字符串名轨 + 类型安全轨（`registerBean<T>` 委托 `BeanFactory`） |
| `PluginEventBus` 接口 | `plugin_event_bus.cj` | 事件总线契约：`subscribe`/`emit`/`waterfall`/`unsubscribeAll` |
| `PluginSpiLogger` | `service_registry.cj` | SPI 包日志钩子：`errorSink`/`warnSink`/`infoSink` 三个 sink，宿主注入 `LogUtils` 适配 |

**关键设计模式**：

1. **接口层纯净（零宿主依赖）**：`plugin-spi` 只定义契约（纯接口），不依赖宿主 `magic` 包、`fountain` 或任何运行时设施。实现层（`BeanFactoryServiceRegistry` 等）在宿主 `magic.plugin` 中引入 `fountain` 依赖。

2. **Sink 注入模式**：`PluginSpiLogger` 的三个 sink 默认输出到控制台（`infoSink` 默认静默），宿主 `PluginManager` 初始化时注入 `LogUtils` 适配，使 SPI 内日志汇入宿主日志文件。这是"宿主能力经注入而非复制"的典型模式。

3. **委托 BeanFactory 模式**：`ServiceRegistry` 的类型安全轨 `registerBean<T>(name, creator)` 委托 `BeanFactory.register<T>(creator)`，`getService<T>()` 委托 `BeanFactory.getFirst<T>()`——复用 IOC 容器的类型安全 + 并发控制 + 生命周期管理，插件无需自带这些能力。

4. **PluginSkillBridge 接口隔离**：`PluginSkillBridge` 接口只暴露 `registerPluginSkills`/`buildCapabilityCatalog`/`clearPluginSkills` 三个无宿主类型依赖的方法。实现留在宿主 `magic.plugin.SkillBridge`（依赖 `SkillManagementService`/`SkillManager` 存量技能管线，SPI 不感知）。

### 8.2 plugin-spi 对 L3 轨轻量化的启示

**核心启示**：plugin-spi 的"接口层纯净 + 实现层委托"模式可以直接应用于 L3 轨的 host.db 服务代理。

**当前 L3 轨的问题**：
- 插件 `.exe` 静态链接 `cordis-cj`、`jsonvalue`、`jsonrpc` 等所有依赖，体积庞大
- 每个插件都包含完整的 `cordis_host` 实现（宿主侧的 PluginManager/PluginHost/reconcile），但插件进程实际上只需要 `cordis_plugin`（插件侧 SDK）

**plugin-spi 模式的 L3 轨等价物**：

| plugin-spi 模式 | L3 轨等价物 | 轻量化效果 |
|-----------------|------------|------------|
| 接口层纯净（零宿主依赖） | 插件只依赖 `cordis_plugin`（插件侧 SDK），不依赖 `cordis_host`（宿主侧实现） | 移除宿主侧实现代码 |
| Sink 注入模式 | 插件经 `ctx.invoke("host.log", ...)` 调用宿主日志，不自带日志库 | 移除日志库依赖 |
| 委托 BeanFactory 模式 | 插件经 `ctx.invoke("host.db", ...)` 调用宿主数据库服务，不自带 `f_orm`/连接池 | 移除 ORM 库依赖 |
| PluginSkillBridge 接口隔离 | 插件经 `ctx.invoke("host.cache", ...)` 调用宿主缓存服务，不自带缓存库 | 移除缓存库依赖 |

**结论**：plugin-spi 的设计理念——"将宿主能力封装成服务，让插件可调用，而不用将能力复制到插件中"——正是 L3 轨轻量化的核心思路。方向一和方向二的实施应当借鉴 plugin-spi 的接口隔离模式。

---

## 九、research.md 历史经验研究（2026-09-03 补充）

### 9.1 L2 轨动态库加载的历史经验

`research.md` 记录了阶段三 L2 动态库轨的关键技术决策：

1. **`PackageInfo.load()` 直接复用 fountain `App.run()` 管线**：
   - fountain `f_app/App.cj` L116-171 有一套完整、生产级、成熟的动态库扫描 + 加载实现
   - 通过 `Directory.walk()` + 正则匹配 `.so`/`.dll`/`.dylib` → `PackageInfo.load(去扩展名路径)` 加载
   - 插件系统 PS-T012 L2 动态库加载原型实现了完全相同的机制

2. **`PackageInfo.load()` 的跨平台验证**：
   - fountain 已在 Windows/Linux/macOS/OpenHarmony 四平台上验证 `PackageInfo.load` 行为
   - `PackageInfo.load` 要求动态库文件名与包名严格一致（仓颉官方文档约束）
   - 插件独立 cjpm 包的 `name = "skill_{name}"` 编译产物为 `libskill_{name}.so`，加载时传入 `"skill_{name}"`（去扩展名去掉 `lib` 前缀）即可

3. **`--dy-std` 编译选项必需**：
   - 仓颉动态库默认静态链接标准库，多个 `.so` 同时加载会重复包含标准库符号，触发 `ld.lld: error: _CGP15xxx was replaced` 符号冲突
   - 必须为动态库编译添加 `--dy-std` 选项，使动态库使用动态链接的标准库

### 9.2 L2 轨经验对 L3 轨轻量化的启示

**关键启示**：L2 轨的 `PackageInfo.load()` 机制可以实现"插件不进宿主编译图、不重编宿主装上新插件"，但插件动态库仍然需要携带依赖。L3 轨的进程隔离机制可以进一步轻量化：

1. **共享动态链接标准库**：L3 轨的插件 `.exe` 使用 `--dy-std` 编译选项，动态链接标准库而非静态链接。宿主提供 `CANGJIE_STDX_DYNAMIC_PATH` 环境变量指向共享目录，所有插件共享同一份动态链接标准库。

2. **宿主侧服务代理（host.db/host.log/host.cache）**：插件进程经 `ctx.invoke` 反向调用宿主服务，不自带 `f_orm`/连接池/日志库/缓存库。这是 plugin-spi "接口隔离 + 实现委托"模式的进程级等价物。

3. **cordis-cj 包拆分**：将 `cordis-cj` 拆分为 `cordis_plugin`（插件侧 SDK，轻量）和 `cordis_host`（宿主侧实现，重量级），插件只依赖 `cordis_plugin`。

---

## 十、仓颉语言级别可利用机制研究（2026-09-03 补充）

### 10.1 动态加载机制（PackageInfo.load / ModuleInfo.load）

**仓颉标准库 `std.reflect` 提供的运行时动态加载 API**：

```cangjie
// 运行时动态加载指定路径下的一个仓颉动态库模块
public static func load(path: String): PackageInfo

// 获取模块信息
let myPackage = PackageInfo.load("../myPackage/target/release/myPackage/libmyPackage")
println(myPackage.name)
TypeInfo.get("myPackage.MyPublicType") |> println
```

**关键约束**：
- 路径 `path` 中的共享库文件名不需要后缀名（如 `.so` 和 `.dll` 等）
- 如果某个 `package` 通过静态加载方式（如 `import`）已经导入过，那么动态加载该 `package` 会抛出异常
- `PackageInfo.load` 根据文件名判断包名，不允许修改文件名

**轻量化应用**：
- L2 轨已验证 `PackageInfo.load()` 可实现"不重编宿主装上新插件"
- 插件动态库文件名与包名严格一致，编译产物路径可预测
- 动态加载后通过反射 API（`TypeInfo.get`/`ClassTypeInfo.get`）访问其中声明的类型

### 10.2 反射 API（ClassTypeInfo / TypeInfo / findAnnotation / ConstructorInfo）

**仓颉反射 API 能力**：

| API | 功能 |
|-----|------|
| `ClassTypeInfo.get(全限定类名)` | 跨包反射发现类 |
| `TypeInfo.get(全限定类型名)` | 获取类型信息 |
| `findAnnotation<注解类>()` | 查找注解 |
| `ConstructorInfo.apply(args)` | 反射实例化（返回 `Any`） |
| `PackageInfo.load(path)` | 运行时动态加载仓颉动态库 |
| `TypeInfo.getMember(name)` | 获取成员信息 |

**轻量化应用**：
- L1 内嵌轨已验证反射 API 可实现"注解声明 + 反射发现 + 生命周期状态机"
- L2 动态库轨已验证 `PackageInfo.load()` + 反射 API 可实现"运行时加载动态库 + 反射访问类型"
- L3 进程隔离轨不需要反射 API（路由由宿主网关注册，插件不经反射发现）

### 10.3 FFI 外部函数接口

**仓颉 FFI 能力**：
- `@C` foreign function interface，可调用 C/C++ 原生库
- `@C` struct/class 可与 C 互操作
- 跨语言互操作能力（仓颉 ↔ C ↔ 其他语言）

**轻量化应用**：
- L3 轨插件可通过 FFI 调用宿主的 C ABI 接口，而非携带完整 cordis-cj 库
- 但 FFI 仍需插件自带 C ABI 桩代码，轻量化效果有限
- 更适合作为方向三（WASM 沙箱插件）的补充——WASM 模块可通过 FFI 调用宿主能力

### 10.4 宏编程（macro）

**仓颉宏编程能力**：
- `@macro` 编译期代码生成
- 可在编译期注入代码、生成类型、变换 AST
- 编译期元编程能力

**轻量化应用**：
- 可用宏在编译期自动生成 `ctx.invoke("host.db", ...)` 的类型安全包装代码，减少运行时开销
- 可用宏在编译期自动生成 `plugin.yaml` 路由声明，减少手动维护成本
- 但宏编程本身不直接减小插件体积，更适合作为方向一/二的开发体验优化

### 10.5 动态链接机制（--dy-std）

**仓颉 `--dy-std` 编译选项**：
- 使动态库使用动态链接的标准库，而非静态链接
- 解决多个动态库同时加载时标准库符号重复冲突问题
- 需要配合 `[target.*.bin-dependencies] path-option` 指定动态链接标准库路径

**轻量化应用**：
- L3 轨插件 `.exe` 使用 `--dy-std` 编译选项，动态链接标准库
- 宿主提供 `CANGJIE_STDX_DYNAMIC_PATH` 环境变量指向共享目录
- 所有插件共享同一份动态链接标准库，无需各自携带
- 这是方向一（插件安装到宿主目录）的核心技术手段

### 10.6 包管理（cjpm）的 workspace 和 dependencies 机制

**cjpm 包管理能力**：

| 机制 | 功能 | 轻量化应用 |
|------|------|------------|
| `[workspace] members` | 声明 workspace 成员包 | 可将插件声明为 workspace 成员，共享宿主依赖 |
| `[dependencies] path` | 声明本地路径依赖 | 插件依赖可指向宿主共享目录 |
| `output-type = "dynamic"` | 编译为动态库 | L2 轨插件编译为动态库 |
| `output-type = "executable"` | 编译为可执行文件 | L3 轨插件编译为独立可执行文件 |
| `[target.*.bin-dependencies]` | 声明二进制依赖路径 | 指定动态链接标准库路径 |

**轻量化应用**：
- 方向一（插件安装到宿主目录）利用 `[target.*.bin-dependencies] path-option` 指向宿主共享目录
- 方向二（插件 SDK 精简包）利用 `[dependencies] path` 指向拆分后的精简 SDK
- `--dy-std` + 共享目录是核心技术手段

### 10.7 WASM 编译支持

**仓颉 WASM 编译能力（待评估）**：
- 仓颉编译器是否支持编译为 WASM 模块，需要查阅官方文档或进行原型验证
- 如果支持，插件可编译为 `.wasm` 文件，宿主通过 WASM 运行时加载执行
- WASM 模块天然轻量（仅含业务逻辑），基础库由宿主 WASM 运行时提供

**轻量化应用**：
- 方向三（WASM 沙箱插件）的可行性取决于仓颉 WASM 编译能力
- 如果可行，可实现极致轻量化（WASM 模块体积 ~100KB vs 当前 ~50MB）
- 需要先进行技术评估，如果不可行则放弃此方向

---

## 十一、补充轻量化方案（2026-09-03 补充）

### 11.1 方向一补充：插件安装到宿主目录（宿主共享依赖）

**基于 plugin-spi 启示的细化方案**：

1. **宿主共享依赖目录结构**：
   ```
   agentskills-runtime/
   ├── plugins/
   │   ├── shared/                  # 共享依赖目录
   │   │   ├── cordis-cj/           # cordis-cj 库（插件侧 SDK + 核心库）
   │   │   │   ├── cordis_plugin/
   │   │   │   ├── cordis_core/
   │   │   │   └── ...
   │   │   ├── jsonvalue/           # jsonvalue 库
   │   │   ├── jsonrpc/             # jsonrpc 库
   │   │   └── stdx/                # 仓颉标准扩展库（动态链接）
   │   └── {name}/                  # 插件安装目录
   │       └── skill_{name}.exe     # 插件二进制（仅业务逻辑 + 轻量 SDK）
   └── ...
   ```

2. **插件 cjpm.toml 配置（指向宿主共享目录）**：
   ```toml
   [package]
     cjc-version = "1.1.3"
     compile-option = "--dy-std -Woff all"
     name = "skill_{name}"
     output-type = "executable"
     ...

   [dependencies]
     "ystyle::cordis_plugin" = { path = "../../../plugins/shared/cordis-cj/cordis_plugin" }
     "ystyle::cordis_core" = { path = "../../../plugins/shared/cordis-cj/cordis_core" }
     "jsonvalue" = { path = "../../../plugins/shared/jsonvalue" }
     "ystyle::jsonrpc" = { path = "../../../plugins/shared/jsonrpc" }

   [target.x86_64-w64-mingw32.bin-dependencies]
     path-option = ["../../../plugins/shared/stdx"]
   ```

3. **plugins.yaml 配置（command 指向宿主目录）**：
   ```yaml
   name: {name}
   version: 1.0.0
   mode: process
   protocol: jsonrpc-stdio
   command: ./plugins/{name}/skill_{name}.exe
   ```

4. **插件安装工具（plugininstall）**：
   - 编译插件：`cd skills/{name} && cjpm build`
   - 复制二进制：`cp target/release/bin/skill_{name}.exe plugins/{name}/`
   - 首次安装时复制共享依赖到 `plugins/shared/`
   - 更新 `plugins.yaml`

**预期轻量化效果**：

| 指标 | 当前值 | 方向一目标值 |
|------|--------|-------------|
| 插件 `.exe` 体积 | ~50MB（含依赖） | ~5MB（仅业务逻辑 + 轻量 SDK） |
| 依赖携带方式 | 每个插件自带完整依赖 | 宿主共享目录，插件不携带 |
| 标准库链接方式 | 静态链接（每个 `.exe` 包含完整标准库） | 动态链接（`--dy-std`，所有插件共享） |
| 分发方式 | 需复制依赖 | 需安装到宿主 `plugins/` 目录 |

### 11.2 方向二补充：插件 SDK 精简包（借鉴 plugin-spi 接口隔离模式）

**基于 plugin-spi "接口层纯净 + 实现层委托"模式的细化方案**：

1. **cordis-cj 包拆分**：
   ```
   libs/cordis-cj/
   ├── cordis_plugin/              # 插件侧 SDK（轻量，仅核心接口）
   │   ├── plugin_runtime.cj       # PluginRuntime.run 入口
   │   ├── plugin_context.cj       # PluginContext 上下文
   │   ├── host_service_proxy.cj   # host.db/host.log/host.cache 服务代理接口
   │   └── ...
   ├── cordis_host/                # 宿主侧实现（重量级，仅宿主依赖）
   │   ├── plugin_manager.cj       # PluginManager(stdio)
   │   ├── plugin_host.cj          # PluginHost/reconcile
   │   └── ...
   └── cordis_core/                # 核心库（插件+宿主共用，轻量）
       ├── json_value.cj           # JsonValue 类型
       └── ...
   ```

2. **插件只依赖精简 SDK**：
   ```toml
   [dependencies]
     "ystyle::cordis_plugin" = { path = "../../libs/cordis-cj/cordis_plugin" }
     "ystyle::cordis_core" = { path = "../../libs/cordis-cj/cordis_core" }
     "jsonvalue" = { path = "../../libs/jsonvalue" }
   ```
   注意：插件不依赖 `cordis_host`（宿主侧实现），因为插件进程不需要宿主侧的 PluginManager/PluginHost/reconcile 逻辑。

3. **host.db 服务代理接口隔离**：
   - 插件侧 `cordis_plugin` 只定义 `ctx.invoke(service, method, args)` 契约
   - 实现层在宿主 `cordis_host` 中，通过 stdio JSON-RPC 转发
   - 插件不自带 `f_orm`/连接池/日志库/缓存库，全部经 `ctx.invoke` 调用宿主服务

**预期轻量化效果**：

| 指标 | 当前值 | 方向二目标值 |
|------|--------|-------------|
| 插件 `.exe` 体积 | ~50MB（含完整 cordis-cj） | ~2MB（仅精简 SDK + 业务逻辑） |
| 依赖清晰度 | 依赖完整 cordis-cj（含宿主侧实现） | 仅依赖 cordis_plugin + cordis_core（核心接口） |
| 宿主能力访问方式 | 插件自带 f_orm/连接池等 | 经 ctx.invoke 调用宿主服务代理 |

### 11.3 方向三补充：WASM 沙箱插件（评估仓颉 WASM 编译能力）

**基于语言级别机制研究的细化方案**：

1. **仓颉 WASM 编译能力评估**：
   - 需要查阅仓颉官方文档或进行原型验证，确认仓颉编译器是否支持编译为 WASM 模块
   - 如果支持，评估 WASM 运行时（Wasmtime/Wasmer）的仓颉绑定可行性

2. **如果仓颉支持 WASM 编译**：
   - 插件编译为 `.wasm` 文件，宿主通过 WASM 运行时加载执行
   - WASM 模块天然轻量（仅含业务逻辑），基础库由宿主 WASM 运行时提供
   - 天然沙箱隔离（WASM 安全模型），比进程隔离更轻量

3. **如果仓颉不支持 WASM 编译**：
   - 放弃方向三，聚焦方向一和方向二
   - 或评估其他轻量化方案（如 Lua 沙箱插件、JS 沙箱插件等）

**预期轻量化效果**：

| 指标 | 当前值 | 方向三目标值 |
|------|--------|-------------|
| 插件包体积 | ~50MB（含依赖） | ~100KB（WASM 模块仅含业务逻辑） |
| 沙箱隔离 | 进程级隔离 | WASM 安全模型隔离（更轻量） |
| 跨平台 | 需为每个平台编译 | WASM 模块跨平台（一次编译，到处运行） |

### 11.4 语言级别机制综合应用

**方向一核心技术手段**：
- `--dy-std` 编译选项：动态链接标准库，所有插件共享同一份标准库
- `[target.*.bin-dependencies] path-option`：指向宿主共享目录
- `cjpm` path 依赖：插件依赖指向宿主共享目录

**方向二核心技术手段**：
- cordis-cj 包拆分：插件只依赖精简 SDK（cordis_plugin + cordis_core），不依赖宿主侧实现（cordis_host）
- plugin-spi 接口隔离模式：host.db/host.log/host.cache 服务代理接口在插件侧只定义契约，实现层在宿主侧
- Sink 注入模式：插件经 ctx.invoke 调用宿主服务，不自带 ORM/日志/缓存库

**方向三核心技术手段**：
- 仓颉 WASM 编译能力（待评估）：插件编译为 WASM 模块
- WASM 运行时集成：宿主通过 WASM 运行时加载执行 WASM 模块
- WASM 导入/导出函数绑定：宿主提供 host.db 等 WASM 导入函数，插件通过 WASM 导出函数提供 handler

### 11.5 修订后的推荐实施路径

| 阶段 | 版本 | 实施方向 | 核心技术手段 | 目标 |
|------|------|----------|------------|------|
| 短期 | v1.0 | 方向一（插件安装到宿主目录） | `--dy-std` + 共享目录 + path 依赖 | 插件 `.exe` 体积从 ~50MB 降至 ~5MB |
| 中期 | v1.1 | 方向二（插件 SDK 精简包） | cordis-cj 拆分 + plugin-spi 接口隔离模式 | 插件 `.exe` 体积进一步降至 ~2MB |
| 长期 | v1.2+ | 评估方向三（WASM 沙箱插件） | 仓颉 WASM 编译能力评估 | 插件包体积降至 ~100KB（如果可行） |

### 11.6 修订后的评估指标

| 指标 | 当前值 | 方向一目标值 | 方向二目标值 | 方向三目标值 |
|------|--------|-------------|-------------|-------------|
| 插件 `.exe` 体积 | ~50MB | ~5MB | ~2MB | ~100KB |
| 依赖携带方式 | 每个插件自带完整依赖 | 宿主共享目录 | 宿主共享目录 + 精简 SDK | 无依赖（WASM 运行时提供） |
| 标准库链接方式 | 静态链接 | 动态链接（`--dy-std`） | 动态链接（`--dy-std`） | 无需链接（WASM 运行时提供） |
| 宿主能力访问方式 | 插件自带 f_orm/连接池等 | 经 ctx.invoke 调用宿主服务代理 | 经 ctx.invoke 调用宿主服务代理 | 经 WASM 导入函数调用宿主服务 |
| 沙箱隔离级别 | 进程级隔离 | 进程级隔离 | 进程级隔离 | WASM 安全模型隔离 |
| 分发便利性 | 需复制依赖 | 需安装到宿主 `plugins/` 目录 | 需安装到宿主 `plugins/` 目录 | WASM 模块可直接分发 |
| 实施工作量 | - | 低 | 中 | 高（需评估 WASM 可行性） |

### 11.7 风险与缓解（修订）

| 风险 | 缓解措施 |
|------|----------|
| 方向一：插件安装位置受限 | 文档明确说明插件必须安装到宿主目录树内 |
| 方向一：共享依赖版本冲突 | 宿主统一管理依赖版本，插件不自带依赖 |
| 方向二：cordis-cj 重构风险 | 保持向后兼容，渐进式重构 |
| 方向二：SDK 版本升级影响 | 提供 SDK 版本兼容性矩阵 |
| 方向三：仓颉 WASM 编译能力未知 | 先进行技术评估，如果不可行则放弃此方向 |
| 方向三：WASM 运行时性能开销 | 进行性能基准测试，评估是否可接受 |
| 通用：`--dy-std` 跨平台行为差异 | 在 Windows/Linux/macOS 三平台验证动态链接标准库行为 |
| 通用：`PackageInfo.load` 与 `--dy-std` 的交互 | 验证动态加载动态库时标准库符号是否正确解析 |

### 11.8 决策建议（修订）

**推荐方案**：短期实施方向一（插件安装到宿主目录），中期实施方向二（插件 SDK 精简包），长期评估方向三（WASM 沙箱插件）。

**核心理念**（借鉴 plugin-spi）："将宿主能力封装成服务，让插件可调用，而不用将能力复制到插件中"。

**实施优先级**：
1. **P0（立即实施）**：方向一——`--dy-std` + 共享目录 + path 依赖，最小改动达到轻量化目标
2. **P1（短期实施）**：方向二——cordis-cj 拆分 + plugin-spi 接口隔离模式，进一步减小插件体积
3. **P2（长期评估）**：方向三——评估仓颉 WASM 编译能力，如果可行则实施极致轻量化

**下一步行动**：
1. 评审本补充方案，确认实施方向和优先级
2. 制定方向一详细实施计划（任务分解、时间节点、验收标准）
3. 评估方向三的仓颉 WASM 编译能力
4. 分配开发资源，启动实施
