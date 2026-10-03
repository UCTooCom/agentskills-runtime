# 插件系统开发指南：一切皆技能的插件机制

> 本文整合自 `.codeartsdoer/specs/plugin-system`（spec.md v3.3 / design.md v5.2）与 `ROADMAP.md`。
> 聚焦 **v0.0.27 之后落地的「一切皆技能」去中心化插件机制**，含三轨架构、自动发现、cordis-cj L3 集成与新增插件的实操。
> 详细需求项见 `spec.md`（REQ-PS-001~016），详细限制条件见 `design.md §0`。

## 1. 为什么是「一切皆技能」

框架的设计哲学来自 `AIDrivenArchitecture.md` 的两个核心观点：

- **§观点1「不硬编码业务功能」**：所有能力都用可视化、可配置的方式声明，不写进宿主代码。
- **§观点2「双驱动」**：无 AI 时纯确定性机制（目录扫描）仍完备运行；有 AI 时 AI 经 Agent 工具对能力做 inspect/activate/deactivate。

由此导出「一切皆技能」的插件定义：

> 一个插件 = `SKILL.md`（AI 行为 / 自然语言 SOP） + `plugin.yaml`（确定性能力 + 自完备配置） + 可执行文件（仓颉编译产物）。
> `SKILL.md` 与 `plugin.yaml` 在**同一轮目录扫描**中被发现，二者天然一体，不存在独立的插件扫描根。

长程任务系统（见 `long-running-task.md`）正是这一理念的典型载体：**L3 轨插件 + 技能内 SKILL.md + COMPOSITION.yaml 编排**。

## 2. 三轨架构

| 轨道 | mode | 编译图归属 | 加载机制 | 适用场景 |
|------|------|------------|----------|----------|
| 内嵌轨 | `sync` | 宿主 magic 包 | build-sync 同步到 `src/plugins/{name}/`，包名 `magic.plugins.{name}` | 开发期增量编译、强耦合宿主的 CRUD |
| L2 动态库轨 | `dylib` | 独立 cjpm 包（动态库） | `PackageInfo.load` 热加载 | 预编译 `.so/.dll/.dylib` 热插拔 |
| L3 进程隔离轨 | `process` | 不进宿主编译图（独立 cjpm executable） | `CordisHostManager` 以 stdio 拉起独立进程 | 故障隔离、第三方可闭源发布、AI 动态启停 |

> **存量冻结红线**：`src/app` 已有模块（97 controller / 83 route）不迁移、不重构、不向 `AutoRouteConfig.cj` 追加新功能代码。新能力一律以**插件形态**交付（`plugingen` 生成），走 `PluginRouteScanner` 动态注册，与存量 `AutoRouteConfig.cj` 硬编码路由**双轨并存**。

## 3. 一切皆技能：去中心化自动发现（§5.5.2）

**问题背景**（design.md 原文）：

> §5.5.1 的 `plugins.yaml` 声明式配置虽消除了宿主代码硬编码，但仍需维护一个**中心化配置文件**——新增插件需编辑 `config/plugins.yaml`，与「一切皆技能」的自完备、自发现设计哲学存在差距。

**设计目标**：去掉 `plugins.yaml` 中心化配置文件，将插件配置信息去中心化迁移到各自的 `plugin.yaml` 中，复用已有的技能目录扫描机制（`ProgressiveSkillLoader`）自动发现 `plugin.yaml` 并加载插件，实现**自完备描述 + 自动发现 + 零中心配置**。

### 3.1 plugin.yaml 自完备化

每个插件的 `plugin.yaml` 成为**唯一配置源**。从 `plugins.yaml` 迁入的字段：`enabled` / `order` / `autoRestart` / `tableWhitelist`。示例：

```yaml
# skills/{name}/plugin.yaml — 自完备描述（去中心化后）
name: long-running-task             # 插件唯一名（原有）
version: 1.0.0
mode: process                       # 加载轨（原有）
command: ./target/release/bin/skill_long_running_task.exe
description: AI 自主驱动长程任务智能体

# ↓ 从 plugins.yaml 迁入的字段
enabled: true                      # 启用开关（缺省 true）
order: 6                           # 加载顺序（缺省 0）
autoRestart: true                  # 崩溃自愈（缺省 true）
tableWhitelist:                    # host.db 表白名单（必须配置，否则 host.db 调用被拒）
  - agent_tasks
  - agent_contexts
  - crontab

# ↓ 原有字段不变
routes:
  - method: POST
    path: /api/v1/uctoo/lrt/plan
```

> ⚠️ **已删除的字段**：原设计第 9 条 `protocol: jsonrpc-stdio`。经核对 `src/plugin/plugin_config.cj` 全字段解析逻辑，**`protocol` 无任何解析代码，写了也会被静默忽略**；L3 进程轨与宿主的传输固定为 **stdio**，无需声明。

### 3.2 PluginDiscoveryService — 自动发现服务

新建 `src/plugin/plugin_discovery_service.cj`，复用 `ProgressiveSkillLoader` 的多目录配置（`SKILL_INSTALL_PATH` 环境变量 + 默认 `./skills`）与目录扫描框架：

```
PluginDiscoveryService.discover(skillBaseDirectories: Array<String>):
  for each baseDir:
    Directory.walk → 遍历直接子目录
    for each subdir:
      pluginYamlPath = "${subdir}/plugin.yaml"
      if (File.exists(pluginYamlPath)):
        entry = PluginManifestEntry.fromPluginYaml(pluginYamlPath)  ← yaml4cj 全量解析
        if (entry.enabled && entry.mode == Process):
          discovered.add(entry)
  return discovered  ← ArrayList<PluginManifestEntry>
```

**关键设计**：

- 与 `SKILL.md` 发现在**同一目录扫描**中完成，零额外 I/O 开销。
- `plugin.yaml` 不存在的子目录自动跳过（纯技能目录无插件）。
- `enabled: false` 的插件跳过。

### 3.3 向后兼容

`PluginHostManager.loadAll` 先走 `PluginDiscoveryService.discover(...)`，再合并 `config/plugins.yaml`（若存在，legacy 覆盖 discovered 的同名字段），最终阶段删除 `plugins.yaml` 支持。

### 3.4 演进路线

```
当前：plugin.yaml 随插件自完备描述（去中心化，自动发现）
  ↓
近期：crudweb 生成插件管理页面，可视化查看/编辑各插件 plugin.yaml
  ↓
远期：plugingen 生成新插件时自动产出自完备 plugin.yaml（含 tableWhitelist 推断）—— **sync 内嵌轨已实现**：`PluginGenerator` 基于（历史 + 本次请求）合并表清单整体重渲聚合 `plugin.yaml`，含 `tableWhitelist` / `tables` / `routes`，支持多表与同名累积（不改 `AutoRouteConfig.cj` 存量轨）
  ↓
终极：loaddbinfo 扫描 DDL → plugingen 自动生成插件 → plugin.yaml 自完备 → 自动发现加载
```

## 4. L3 进程隔离轨（cordis-cj 集成）关键点

**前置闸门（一票否决项，Spike 先行）**：

- Spike-1 工具链兼容：cordis-cj 声明 cjc 1.1.3，需用宿主工具链编译验证。
- Spike-2 Windows 可编译性：`cordis_host` 依赖 `ystyle::jsonrpc_unix`（UDS 不支持 Windows），需在 x86_64-w64-mingw32 目标验证；失败则 vendor 后剥离 UDS 代码（stdio 模式不受影响）。

**固定约束**：

- **传输固定 stdio**：NewlineFraming + JSON-RPC 2.0，全平台；UDS 不启用。
- **宿主侧服务代理**（插件进程经 `ctx.invoke` 反向调用，不直连数据库）：
  - `host.db`：`query` / `count` / `execute`（insert/update/delete），参数受 `tableWhitelist` + 行级权限宿主侧强制。
  - `host.log` / `host.cache`。
- **`$raw:` 前缀约定**：`jsonValueToSqlLiteral` 对 `JsonValue.String` 检查 `$raw:` 前缀，去除后作为原始 SQL 片段直接输出（如 `"$raw:CURRENT_TIMESTAMP"` → `CURRENT_TIMESTAMP`）。
- **生命周期**：`plugin_activate`/`plugin_deactivate` 映射为 reconcile 期望状态 enabled 变更 → 拉起/terminate（杀进程 = OS 级资源回收）；崩溃自愈 `stdout EOF → Failed → 下一轮 reconcile 自动重拉`（探活 ping 超时 → Unreachable → 重启）。
- **可逆效果**：插件侧 `ctx.effect` 注册，卸载逆序执行（对齐 Cordis `fiber.dispose`）。

## 5. 六大限制条件（为什么不能 100% 对标 deepseek-harness）

落地后与原设计仍存在差距（design.md §0.2），开发者需心里有数：

| # | 限制 | 根因 | 实际落地 |
|---|------|------|----------|
| 1 | 插件无法真正独立 | cjpm `[workspace]` 与 `[package]` 互斥 | 内嵌轨：build-sync 同步进宿主编译图 |
| 2 | 插件深度依赖宿主子包 | cjpm 依赖单向性 → 独立包产生循环依赖 | 内嵌轨编译；L2 动态库预编译时编译期不检查 |
| 3 | 反射跨包查询不稳定 | LTO 剪除未被静态引用的类 | build-sync 生成 `generated_anchors.cj` 反射锚点 |
| 4 | 动态库符号重复 | 仓颉动态库默认静态链接标准库 | L2 编译加 `--dy-std`；内嵌轨无需 |
| 5 | 包名须为简单标识符 | cjpm `name` 字段约束 | 内嵌轨 `magic.plugins.{name}`；独立轨 `skill_{name}` |
| 6 | HMR/合流性无定理背书 | 静态编译语言无运行时 fiber | 表述为「确定性插件生命周期」 |

> **核心结论**：agentskills-runtime 的插件是「编译期静态资产 + 运行时实例」双重生命周期，因此**工程级卸载（文件/配置/编译产物/数据库痕迹清理）是它独有的能力**，对应 `pluginuninstall` 工具（`src/plugin/tools/pluginuninstall/`），而非照搬 DSH 的 `undefine`。

## 6. 开发者视角：如何新增一个插件

1. **选轨**：快速原型 / 强耦合宿主 → `sync`；需热插拔 → `dylib`；故障隔离 / 第三方发布 / 长程任务 → `process`。
2. **生成骨架**：
   ```bash
   # 空白骨架
   cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --blank --mode process"
   # 或表驱动完整 CRUD 插件
   cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "--name <插件名> --db uctoo --table <表> --mode process"
   ```
3. **填 plugin.yaml**：`mode` / `command` / `tableWhitelist`（**必须**）/ `routes` 自完备，无需再编辑 `config/plugins.yaml`。
4. **放即生效**：`skills/<name>/` 置于任一技能基目录下，`PluginDiscoveryService` 自动发现；启动日志出现 `[PluginDiscoveryService] discovered plugin: <name>`。
5. **卸载**：
   ```bash
   cjpm run --skip-build --name magic.plugin.tools.pluginuninstall --run-args "--name <插件名> [--force]"
   ```

## 7. 关键工程约束（踩坑清单）

- `tableWhitelist` **必须配置**，否则所有 `host.db` 调用被拒绝（报 `no table whitelist configured for plugin`）。
- `plugin.yaml` 不要写 `protocol` 字段（被忽略）。
- `permissions` 空数组是陷阱（见 long-running-task design.md 附录 A），勿留空。
- L3 插件禁用 `@Plugin` 宏（规避 cjpm 宏包 organization 跨模块缺陷），入口用 `PluginRuntime.run(...)` 显式 API。
- 凭证（如第三方 Token）仅存宿主 `.env`，插件/脚本经 MCP 调用时宿主注入，插件不接触凭证本体。
