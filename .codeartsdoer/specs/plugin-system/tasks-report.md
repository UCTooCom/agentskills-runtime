好的，让我查看插件系统开发工程目录，分析后续需要进行的工作。

用户要求我参考插件系统开发工程目录，分析后续插件系统还有哪些需要进行的工作。根据文档 tasks.md 的信息，当前进度：

阶段一（v0.5）：✅ 已完成
阶段二（v0.6）：✅ 已完成（2026-08-28）——晋级门槛"第一个真实新插件不经框架代码修改上线"达成；package_release 发布包验证待人工执行
阶段三（v0.7~v0.9）：✅ 编码完成（2026-08-28）——PS-T017 SPI 抽取 / PS-T012 L2 动态库加载原型 / PS-T019 pluginuninstall / PS-T020 build-sync 删除检测 / PS-T021 卸载集成测试——全部编译通过。**晋级门槛"不重编宿主装上一个新插件"通过 PS-T012 L2 动态库加载原型实现**。**关键限制**：因 cjpm `[workspace]` 与 `[package]` 互斥，放弃 workspace 成员模式，改用宿主内嵌轨（详见 design.md §0 限制 #1）
阶段四（v1.0/v1.1）：⏳ 未启动——另立 SDD（插件市场基础设施）

根据 [tasks.md](file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/.codeartsdoer/specs/plugin-system/tasks.md#L41-L45) 的进度标记，当前插件系统阶段进度如下：

```
阶段一（v0.5）✅ 完成（38 个集成测试全绿）
阶段二（v0.6）✅ 完成（entity 运行时达标，package_release 验证待人工执行）
阶段三（v0.7~v0.9）✅ 编码完成（PS-T017/PS-T012/PS-T019/PS-T020/PS-T021 全部编译通过）
阶段四（v1.0/v1.1）⏳ 未启动（插件市场，另立 SDD）
```

---

## 实际落地与限制条件摘要（2026-08-28，详见 design.md §0 / spec.md §0）

编码落地后，原设计多项方案因架构、fountain 框架、仓颉编程语言方面的原因未能完全对标 deepseek-harness（Cordis）"一切皆插件"理念。六项关键限制：

| # | 限制 | 类型 | 实际落地方案 |
|---|------|------|-------------|
| 1 | 插件无法真正"独立"——cjpm `[workspace]` 与 `[package]` 互斥 | 架构限制 | 放弃 workspace 成员模式，改用宿主内嵌轨（`src/plugins/{name}/`，包名 `magic.plugins.{name}`） |
| 2 | 插件深度依赖宿主子包——独立包模式产生循环依赖 | 架构限制 | entity/feedback 保留对宿主 `magic` 包的依赖，通过宿主内嵌轨编译 |
| 3 | 仓颉反射 API 限制——ClassTypeInfo.get 跨包查询在 LTO 下被剪除 | 语言限制 | build-sync 自动生成 `generated_anchors.cj`，显式 import + 实例化插件 Route/Plugin 类作为 L1 反射锚点 |
| 4 | 仓颉动态库标准库符号重复——`--dy-std` 编译选项必需 | 语言/工具链限制 | entity/feedback 的 `cjpm.toml` 编译选项统一为 `compile-option = "-O2 --dy-std -Woff all"` |
| 5 | 插件包名必须为简单标识符——cjpm `name` 字段约束 | 工具链限制 | 内嵌轨包名 `magic.plugins.{name}`；独立包轨包名 `skill_{name}`（如 `skill_entity`） |
| 6 | HMR/合流性无定理背书——对外表述"确定性插件生命周期" | 设计限制 | PluginEventBus 实现 emit/waterfall，未实现 parallel/serial/bail；HMR 需待 v1.1+ 增强形态（WASM 沙箱插件） |

---

## 后续需要进行的工作清单

### 🔧 阶段二收尾（当前立即可以做）

| # | 工作项 | 说明 | 关联任务 | 优先级 |
|---|--------|------|----------|--------|
| 1 | **package_release 发布包验证** | tasks.md v2.5 明确标注的"阶段二剩余收尾"：将 entity/hello/doc-helper 三个插件的编译产物（.cjo/.dll）与各自 plugin.yaml 一起打进发布包，解压后验证插件正常加载、路由可达 | PS-T016 | P1 |
| 2 | **宿主 entity 路由彻底移除** | 当前用人工多行注释处理 [AutoRouteConfig.cj:267-278](file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/src/app/registry/AutoRouteConfig.cj#L267-L278)。应在下次 AutoRouteConfig.cj 正式清理时直接删除（含对应 import 的 entity 包引用），彻底消除双轨冲突风险 | PS-T014 配套 | P1 |
| 3 | **plugingen 生成模板一致性验证** | 刚修复的三个模板同步缺口（`DAO.cj.tpl` 缺 `emptyRecycleBin{{className}}`、`Service/Controller/Route` 模板 V4 路由与权限 `WithPermission` 方法对齐）需对 2-3 张新表重跑 plugingen，生成新插件后完整走一遍 build-sync→编译→CRUD 测试闭环，确认以后用 plugingen 生成的插件能直接工作，不再需要人工补代码 | PS-T013 | P1 |
| 4 | **PermissionUtils 其他 SQL 参数化** | 本次修复了 `hasWildcardPermission` 和 creator 检查。`appendPermissionFilter`（[PermissionUtils.cj:147/169](file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/src/app/utils/PermissionUtils.cj#L147-L169)）与 `buildFilterCondition`（第 416/419 行）仍在拼接 `'${userId}'::uuid` 的 SQL 片段字符串——虽注入风险低，但参数化改造可作为债务清理项 | 无（修复遗留） | P2 |
| 5 | **行级权限与通配符绕过的单元测试** | 本次修复了 admin（有 `*` 权限）编辑非 creator 数据被错误拦截的 bug。应补两个确定性用例：① admin 编辑非归属 creator 数据→放行；② 普通用户编辑非归属 creator 数据→拒绝，确保后续回归不复发 | PS-T011 扩展用例 | P2 |

---

### 🚀 阶段三：L2 动态加载（预计 4~5 个工作日）

这是下一阶段的核心任务，按依赖顺序严格执行：

| # | 工作项 | 说明 | 关联任务 | 预估工时 | 依赖 |
|---|--------|------|----------|----------|------|
| 6 | **新建 libs/plugin-spi 独立包** | 参考 libs/yaml4cj 等 23 个 path 依赖先例，新增 `libs/plugin-spi/cjpm.toml`，迁入 Plugin 接口、PluginAnnotation 注解、ModuleRouteAnnotation、PluginContext 契约、PluginEventBus 接口、Controller 基类等插件面向的稳定 API。**只迁契约，不迁实现** | PS-T017 子任务 1-2 | 0.5 天 | 无 |
| 7 | **宿主 magic.plugin 改依赖 plugin-spi** | [design.md §2.2.2](file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/.codeartsdoer/specs/plugin-system/design.md#L390-L428) 的框架内部实现（PluginManager/Registry/Loader 等）留在 magic.plugin，import 路径改为从 plugin-spi 拿契约；宿主根 cjpm.toml 追加 path 依赖 | PS-T017 子任务 3 | 0.5 天 | #6 |
| 8 | **插件目录升格为独立 cjpm 包** | `skills/entity/`、`skills/hello/`、`skills/doc-helper/` 增加 `cjpm.toml`（name = `skill_entity` 等），代码移到 `scripts/src/`，根 cjpm.toml 追加 path 依赖 | PS-T017 子任务 4 | 1 天 | #7 |
| 9 | **移除 build-sync 钩子 + src/generated 清理** | build.cj 中 PS-T015 pre-build 同步钩子移除；.gitignore 的 src/generated 规则保留（或删除对应目录） | PS-T017 子任务 5 | 0.5 天 | #8 |
| 10 | **跨包反射验证 + 依赖单向性校验** | ClassTypeInfo.get 跨包（libspi ↔ 宿主 ↔ 独立插件包）查类型、findAnnotation、实例化链路跑通；源码扫描确认插件包无 `import magic.*`（除 plugin-spi）。此时 L2 就绪 | PS-T017 子任务 6-7 + 验收 | 0.5 天 | #9 |
| 11 | **实现 PluginDylibLoader** | 直接参考 fountain [f_app/App.cj L116-171](file:///d:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/agentskills-runtime/libs/fountain/f_app/src/App.cj#L116-L171) 的生产级 L2 实现（Directory.walk→平台扩展名过滤→正则匹配→**PackageInfo.load(去扩展名路径)**→加载后反射引导），差异是按 plugins.yaml 清单加载而非全目录扫描，加载后走 @PluginAnnotation 注解发现 | PS-T012 子任务 1-2 | 1 天 | #10 |
| 12 | **最小动态库插件 + 运行时验证** | `cjpm init --type=dynamic` 建 dylib-sample，依赖 plugin-spi；**不重编宿主**：编译出 .dll→放入发布包 plugins/→启动宿主→PackageInfo.load→反射发现 @Plugin→实例化→注册→路由/技能可用。同时验证 dlclose 卸载回收无崩溃；晋级门槛达成 | PS-T012 子任务 3-7 + 验收 | 1 天 | #11 |

---

### 🎯 阶段四：插件市场（需另立 SDD，不在本工程范围）

tasks.md/design.md 均明确标注"另立 SDD（市场基础设施）"。候选内容骨架：

- **发布侧**：插件包签名校验、版本兼容矩阵（与 runtime version 区间匹配）、插件包索引服务（搜索/排序/推荐）
- **消费侧**：runtime 内 `plugin_install` Agent 工具、从远端拉取并校验签名后落地 plugins/ 目录、PackageInfo.load 热装载
- **治理侧**：is_plugin 过滤列触发（阶段二预留决策）、插件元数据检索 UI、评论/评分/统计

---

## 推荐推进顺序

如果不打算立即上 L2（动态库），当前最优先做的三件事：

1. ✅ **立即**：package_release 发布包验证（实体插件能走发布包）
2. ✅ **立即**：plugingen 对一张新表完整跑一遍生成→编译→CRUD 测试，确认模板零缺口
3. 🅿️ **技术债务**：PermissionUtils 剩余 SQL 参数化 + 行级权限回归测试

是否按此优先级推进？如需启动其中某项，直接告知即可。

---

## PS-T018 复核：skills 双向同步（2026-08-23）

**复核范围**：`agent_skills` 表 ↔ `skills/` 目录 `SKILL.md` 的双向数据同步，对照 design.md §2.3 PluginSyncBridge 设计与 tasks.md PS-T018 验收标准。

### 双向同步链路（四个触发点）

| 触发点 | 方向 | 机制 | 状态 |
|--------|------|------|------|
| **启动全量同步** | file→db | `main.cj:260` `spawn { syncAll(TriggerSource.Startup) }` 扫描 `skills/` 全目录 | ✅ 正常 |
| **定时扫描** | file→db | `SyncScanJob` cron `0 0 */5 * * *`，每 5 分钟触发 `syncAll` | ❌ **未注册**（已修复） |
| **DAO 写入触发** | db→file | `SyncInterceptor` AOP 切面拦截 `AgentSkillsDAO.insert*/update*`，异步触发 `syncToFileSystem` | ❌ **extractEntityId 缺陷**（已修复） |
| **手动 API** | 双向 | `SyncController` 三个端点：`syncAll` / `syncFromFileSystem` / `syncToFileSystem` | ✅ 正常 |

### 发现的同步缺陷与修复

**缺陷 #1：SyncScanJob 未注册到 Ticktock 调度器**

- **根因**：`SyncScanJob` 继承 `CronTicktockTask` 并定义了 cron 表达式，但全项目无 `ticktock.addOrReplaceTask(SyncScanJob())` 注册点，定时扫描从未运行
- **影响**：`skills/` 目录下新增/修改的 `SKILL.md` 不会自动同步到 `agent_skills` 表（仅在启动时全量同步一次）
- **修复**：在 `SchedulerEngine.loadAllActiveTasks` 末尾注册 `SyncScanJob`（`SchedulerEngine.cj:149`），定时扫描每 5 分钟自动运行
- **文件**：`src/app/services/crontab/SchedulerEngine.cj`（+1 import，+5 行注册代码）

**缺陷 #2：SyncInterceptor.extractEntityId 无法处理 update* 返回的 Int64**

- **根因**：`extractEntityId(result)` 把 DAO 返回值 `as String`，但 `insertAgentSkills` 返回 UUID 字符串（正确），`updateAgentSkills` 返回 `Int64`（影响行数，`as String` 失败返回空串），导致 update 操作无法触发 db→file 回写
- **影响**：通过 API 或业务逻辑更新 `agent_skills` 表记录后，不会自动把变更回写到 `SKILL.md` 文件
- **修复**：新增 `extractIdFromArgs(args)` 方法，当 `extractEntityId(result)` 返回空串时（update 路径），从 `funcInfo.args[0]`（即被更新的 PO 实体）用 `as AgentsPO`/`as AgentSkillsPO` 类型转换直接读取 `po.id` 字段
- **文件**：`src/app/services/sync/interceptor/SyncInterceptor.cj`（重写，98 行）

### PluginSyncBridge 复核结果

| 验收项 | 结果 | 备注 |
|--------|------|------|
| 订阅 EventBus 生命周期事件 | ✅ | `bind(pluginEventBus)` 在 `loadAll` 之前调用（`main.cj:664-665`），时序正确 |
| 状态回写 `runtime_status` | ✅ | `writeRuntimeState` 按 name 匹配行，无行跳过等待首扫 |
| 元数据合并 `extra_metadata` | ✅ | `mergePluginMetadata` 读-改-写，保留其他键，带 `plugin:true` 标记 |
| 回写失败不影响插件运行 | ✅ | 失败降级：记日志 + `sync_status=error`，不阻断生命周期 |
| 单向红线 | ✅ | 只做 内存→库 回写，不提供 库→plugin.yaml 路径 |
| 表结构零变更 | ✅ | 无 DDL 执行，复用存量 `agent_skills` 表 |

### 静态验证结果

| 验证项 | 结果 |
|--------|------|
| `SchedulerEngine` 注册 `SyncScanJob` | ✅（第 149 行 `addOrReplaceTask(SyncScanJob())`） |
| `SyncInterceptor.extractIdFromArgs` 类型转换提取 id | ✅（`as AgentsPO`/`as AgentSkillsPO` 双路径） |
| `SyncInterceptor.dispatchSync` 统一异步分发 | ✅（insert/update 两路径均触发 `syncToFileSystem`） |
| 循环同步阻断 | ✅（`SyncContext.isPresent()` 检查，file→db 同步期间的 DAO 写入不会反向触发 db→file） |

### 待人工编译验证

由于开发工具环境禁止 `cjpm build`（编译超时），以下验证需在单独的 cmd 环境执行：

```
cjpm build
```

编译通过后启动 runtime，观察日志应出现：

```
SchedulerEngine", "内置定时任务注册完成: sync-periodic-scan (cron='0 0 */5 * * *')"
SyncScanJob", "starting periodic file scan sync"
SyncScanJob", "completed - total:N, success:N, failed:0"
```

且 `agent_skills` 表应在启动全量同步和定时扫描后反映 `skills/` 目录的最新状态。

---

## 阶段三插件卸载需求补齐（2026-08-24）

**触发背景**：阶段二删除 entitygen/feedbackgen 时全程手工（删目录、清 plugins.yaml、清 generated_anchors.cj、清 target 产物、清数据库痕迹），暴露了阶段二"只有运行时停用（plugin_deactivate）、无工程级卸载"的缺口。经研究对比 deepseek-harness（Cordis）卸载机制（详见 `docs/ref/deepseek-harness-plugin.md`），确认 agentskills-runtime 因插件生命周期模型不同（编译期静态资产 vs 会话级动态 effect），工程级卸载是本项目独有的能力，DSH 不需要也不具备这一层。

**三层文档变更概要**：

| 文档 | 变更内容 | 位置 |
|---|---|---|
| spec.md | 新增 REQ-PS-014 插件卸载（阶段三完整卸载能力）：卸载三层模型、pluginuninstall 工具、卸载安全机制、卸载幂等性、卸载事件溯源、与 DSH 对标表 | REQ-PS-013 之后、REQ-PS-012 之前 |
| spec.md | 演进路标阶段三需求新增 REQ-PS-014（卸载） | 演进路标表阶段三行 |
| design.md | 新增 §2.11 插件卸载设计：§2.11.1 卸载三层模型、§2.11.2 卸载状态机、§2.11.3 逆向清理栈（对应 Cordis effect/disposer）、§2.11.4 pluginuninstall 工具设计、§2.11.5 卸载安全机制、§2.11.6 卸载事件溯源、§2.11.7 与 DSH 卸载机制对标 | §2.10 之后追加 |
| tasks.md | 任务总览表新增 PS-T019（pluginuninstall 工具）、PS-T020（build-sync 删除检测增强）、PS-T021（卸载集成测试与验证）三个阶段三任务 | 任务总览表阶段三行 |
| tasks.md | 新增 PS-T019/PS-T020/PS-T021 完整任务定义：描述、前置、子任务、关键文件、验收标准 | PS-T012 之后追加 |

**阶段三卸载任务清单**：

| 任务ID | 任务名称 | 优先级 | 预估工时 | 依赖 | 状态 |
|--------|---------|--------|---------|------|------|
| PS-T019 | pluginuninstall插件卸载工具 | P1 | 2天 | PS-T007, PS-T013, PS-T015, PS-T018 | ⏳待完成 |
| PS-T020 | build-sync删除检测增强 | P2 | 0.5天 | PS-T015 | ⏳待完成 |
| PS-T021 | 卸载集成测试与验证 | P1 | 1天 | PS-T019, PS-T020 | ⏳待完成 |

**卸载三层模型摘要**（对应 design.md §2.11.1）：

| 层 | 职责 | 关键动作 | 对标 DSH |
|---|---|---|---|
| **运行时层** | 停用运行时实例，撤销所有运行时副作用 | deactivate → onDeactivate → onUnload → 逆序清理栈 → unregister → removeByPlugin → unsubscribeAll → unregisterByPlugin。L2 额外 dlclose | ✅ Cordis fiber.dispose() 撤销所有 effect |
| **静态资产层** | 删除插件文件资产与构建产物 | 删除 skills/{name}/、src/generated/skill-plugins/{name}/、target 编译产物、plugins.yaml 条目、generated_anchors.cj import | ❌ DSH 不做（沙箱级生命周期） |
| **数据库痕迹层** | 清理数据库中该插件的持久化痕迹 | 清理 agent_skills、permissions、i18 表中该插件的记录 | ❌ DSH 不做（会话级，无持久化） |

**与 deepseek-harness（Cordis）卸载机制核心对标结论**：

agentskills-runtime 的卸载能力设计对标了 Cordis 的"运行时 effect 撤销"语义（逆向清理栈 + 卸载幂等 + 级联卸载），但因为插件生命周期模型不同（编译期静态资产 vs 会话级动态 effect），**工程级卸载（文件/配置/编译产物/数据库痕迹的清理）是 agentskills-runtime 独有的能力，DSH 不需要也不具备这一层**。这个能力由新建的 `pluginuninstall` 工具承载，而非简单照搬 DSH 的 `undefine`。

**阶段三卸载任务推进顺序**：

```
PS-T020（build-sync 删除检测增强）  ←─┐
                                        ├─→ PS-T019（pluginuninstall 工具）→ PS-T021（卸载集成测试）
PS-T007/PS-T013/PS-T015/PS-T018（前置）←┘
```

PS-T020 与 PS-T019 可并行开发，PS-T019 依赖 PS-T020 完成后才能实现"反射锚点自动清理"。PS-T021 在 PS-T019 与 PS-T020 均完成后进行。