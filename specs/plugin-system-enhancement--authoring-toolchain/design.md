# 技术设计文档（authoring-toolchain · 插件创作工具链增强）

> 子系统 `feature_name`：`plugin-system-enhancement--authoring-toolchain`
> 契约版本 `v1`（草案）｜ 配套：`contract.md`（IF-12.1~IF-12.4，接口编号以其为准）/ `spec.md` / `tasks.md`
> 章节序：沿用 `templates/design_template.md` 的 §1~§10；因本子系统为**离线工具链 + 0 新表**，无 HTTP API 面，故 §5 API 设计退化为进程内清单并显式声明「无 HTTP 接口」

## 文档信息

| 项 | 值 |
|---|---|
| 项目名称 | `plugin-system-enhancement--authoring-toolchain`（插件创作工具链增强） |
| 版本 | v1 |
| 创建日期 | 2026-10-19 |
| 作者 | SDD 文档步（authoring-toolchain 子系统） |
| 状态 | 草稿（待主工程闸口 confirm） |
| 语言 | 仓颉（Cangjie），代码编写使用 `cangjie-coder` 技能 |
| 编译约定 | **AI 不运行 `cjpm build`**；编译/类型检查/lint 由人工在独立 cmd 环境执行并回传 |
| 权威边界账本 | `specs/plugin-system-enhancement/SPECS_INDEX.md` |

---

## 1. 设计概述

### 1.1 设计目标

1. **G1 补「生成无测试」缺口**：实证 —— `plugingen` 各生成分支（`plugingen.cj:151-195` process CRUD、`:204-214` process blank、`:217-225` `--blank`、`:301-309` sync CRUD、`:286-299` contract）的产出文件为 `plugin.yaml`、`cjpm.toml`、`src/main.cj`、`src/effects.cj`、`src/handlers.cj`、`README.md`、`SKILL.md`（sync 轨另出 `pkg.cj` 与 PO/DAO/Service/Controller/Route.cj），**无 `test/` 目录、无 `*_test.cj`、无 `TESTING.md`**。本设计让它自带「跑得起的最小测试」。
2. **G2 补「无独立校验」缺口**：实证 —— 全仓唯一 validate 是 `PluginLoader.validate`（`src/plugin/plugin_loader.cj:111-117`），**仅检查 `getName().isEmpty()`**，无 CLI 暴露、无 manifest 静态校验、无可分发形态。本设计交付独立 `plugin validate`（IF-12.1）。
3. **G3 让第三方「敢改」**：任何清单改动（能力删一项、版本字段写错、`mode` 打错字）都在**打开宿主之前**被指名到具体的 `文件:行号`。典型场景：宿主 `parseMode`（`plugin_config.cj:270-277`）对未知值静默降级为 `Sync`，这类「悄悄降级」必须先在静态侧被报出（`AT-MODE-01`）。
4. **G4 不造第二处事实来源**：能力枚举消费 IF-05/IF-07，版本口径消费 IF-02，**不自建能力枚举、不自建 semver 解析器、不调用 `VersionGuard.check`**。
5. **G5 存量零回归（R-04）**：既有 51 个 skill 插件 + 4 个 sync 锚点，默认选项下不因新增校验项转 error。
6. **G6 0 新表 0 新列 0 新路由**（铁律 9）：输入面是文件系统，报告生命周期等于一次进程执行。

### 1.2 设计原则

| 原则 | 在本设计中的体现 |
|---|---|
| **边界清晰（铁律 15）** | 只做**生成器侧**与**离线静态校验侧**；不改宿主加载/门禁/握手实现 |
| **复用优先（铁律 9）** | 0 新表；报告用进程内对象；清单解析复用宿主既有 `PluginManifestEntry` 口径；测试脚手架复用 `TemplateEngine.updateFileWithMarkers`（`TemplateEngine.cj:84-116`）的保护区机制 |
| **底座优先（铁律 14）** | 规范源 `skills/uctoo-dev-manual/` + `docs/uctoo-v4/*.md`；工具链沿用 `loaddbinfo → plugingen/crudgen → crudweb` 的既有确定性链路，本子系统只扩展 `plugingen` 与新增一个 CLI，**不插队、不改既有工具的健壮性语义** |
| **确定性与可机读** | 规则编号 `AT-<域>-<序号>` + 严重级 + 位置三元组；json 报告结构稳定，CI 可直接断言 |
| **单入口、不双生** | `plugin validate` 与生成器末尾自校验共用同一 `PluginManifestValidator` 实现；**不新增 `plugingen --validate`**（现选项清单 `plugingen.cj:345-354` 无该项） |
| **失败可观测** | 单规则异常 → 该规则 `skipped`；上游未就位 → 该域 `skipped` 并显式计数，**禁止**蒙混为通过 |
| **只读无副作用** | `plugin validate` 不写任何文件（含临时文件），此为一项可在 CI 中自动验证的硬约束（A-01） |

### 1.3 技术选型

| 组件 | 技术选型 | 说明 |
|---|---|---|
| 编程语言 | 仓颉（Cangjie） | 与宿主、生成器同源 |
| CLI 参数解析 | **手写，镜像既有风格** `plugingen.cj:54-118`（逐参数 `if/else if` + 未知参数 `printHelp` + return） | 不引入新依赖；与既有工具的可维护性惯例一致 |
| 清单解析 | 复用宿主既有解析口径（`plugin_config.cj` 的 `PluginManifestEntry` / `ExternalRoute` 字段语义） | 交叉校验 oracle，见 §3.2；**不修改其一行代码** |
| YAML 读取 | 复用既有 yaml4cj 依赖（`plugin_config.cj` 已用） | 不引入第二个 YAML 实现 |
| HTTP 方法口径 | 复用既有 `HttpMethod`（`external_plugin_route_gateway.cj:565-573` 引用类型） | 路由校验不重定义方法集合 |
| 能力语义 | **消费** `magic.security.capability`（IF-05 / IF-07），仅在一个收口文件内 import | 依赖收口，见 §3.4 |
| 版本解析 | **消费** version-guard 的版本解析内核（IF-02 同口径），仅做 `parse` | **不调用** `VersionGuard.check`（IF-03） |
| 构建登记 | `cjpm.toml` 新增 `[package.package-configuration."magic.plugin.tools.pluginvalidate"] output-type = "executable"`，**镜像 `cjpm.toml:146-147`** | 与 `plugingen` 同范式分发 |
| 数据库 | **无** | 0 新表 0 新列 |

---

## 2. 系统架构

### 2.1 架构图

```
┌──────────────────────── 作者 / CI（进程外命令行） ────────────────────────┐
│  cjpm run --skip-build --name magic.plugin.tools.plugingen --run-args "..." │
│  cjpm run --skip-build --name magic.plugin.tools.pluginvalidate --run-args  │
│           "validate --path skills/demo --format json --strict"              │
└───────────────┬──────────────────────────────────┬────────────────────────┘
                │ ① 生成                            │ ② 校验（只读）
┌───────────────▼──────────────────┐   ┌────────────▼──────────────────────┐
│ src/plugin/tools/plugingen/      │   │ src/plugin/tools/pluginvalidate/   │
│   plugingen.cj（既有，微调）      │   │   pluginvalidate.cj（新增 CLI）     │
│   CrudPluginGenerator.cj（改）   │   └────────────┬──────────────────────┘
│   PluginGenerator.cj（改）       │                │ 进程内调用（同源码一套）
│   TestScaffoldGenerator.cj（新增）│   ┌────────────▼──────────────────────┐
└───────────────┬──────────────────┘   │ src/plugin/validator/（新增）       │
                │ 生成末尾自校验        │   plugin_manifest_validator.cj     │
                └─────────────────────►│   validation_types.cj              │
                    （IF-12.3 同一实现）│   validation_rule.cj               │
                                       │   rules_manifest.cj（IO/CORE/MODE/ │
                                       │                 EXE/RT）           │
                                       │   rules_upstream.cj（CAP/VER 收口） │
                                       │   report_renderer.cj（IF-12.4）     │
                                       └───┬───────────────┬────────────────┘
                                           │ CAP           │ VER
                          ┌────────────────▼──┐   ┌────────▼──────────────┐
                          │ capability-        │   │ version-guard          │
                          │ governance         │   │ IF-02（字段口径+parse） │
                          │ IF-05 / IF-07      │   │ 不调用 IF-03           │
                          │ 不调用 IF-06       │   └───────────────────────┘
                          └────────────────────┘
        ┌──────────────────────────────────────────────────────────────┐
        │ 输入/输出面：skills/{name}/{plugin.yaml, cjpm.toml, src/**,    │
        │ TESTING.md} —— 只读扫描，不写任何东西                          │
        └──────────────────────────────────────────────────────────────┘
```

### 2.2 模块划分

| 模块 | 落点 | 职责 | 是否本轮新建 | 契约接口 |
|---|---|---|---|---|
| A1 CLI 入口 | `src/plugin/tools/pluginvalidate/pluginvalidate.cj`（对齐 `src/plugin/tools/plugingen/plugingen.cj`） | 参数解析、调用内核、渲染报告、返回退出码 | 新建 | IF-12.1 |
| A2 报告与类型 | `src/plugin/validator/validation_types.cj` | `Diagnostic` / `Severity` / `ValidationReport` / `Summary` / `ValidateOptions` | 新建 | IF-12.4 |
| A3 规则接口 | `src/plugin/validator/validation_rule.cj` | `ValidationRule` 接口 + `RuleContext`（只读输入视图）+ 默认规则表构造 | 新建 | IF-12.3（构造注入） |
| A4 清单/轨/可执行/路由规则 | `src/plugin/validator/rules_manifest.cj` | `AT-IO-*` / `AT-CORE-*` / `AT-MODE-*` / `AT-EXE-*` / `AT-RT-*` | 新建 | IF-12.3 内部分解 |
| A5 上游收口规则 | `src/plugin/validator/rules_upstream.cj` | `AT-CAP-*`（IF-05/IF-07）/ `AT-VER-*`（IF-02）+ **唯一允许 import 上游的文件** | 新建 | 消费 IF-05/IF-07/IF-02 |
| A6 编排内核 | `src/plugin/validator/plugin_manifest_validator.cj` | `validate(dir, opts)`；规则遍历、异常降级、`--skip` 前缀、`summary` 聚合 | 新建 | IF-12.3 |
| A7 渲染器 | `src/plugin/validator/report_renderer.cj` | `toText()` / `toJson()` + 凭证脱敏 + 稳定排序 | 新建 | IF-12.4 |
| A8 测试脚手架生成器 | `src/plugin/tools/plugingen/TestScaffoldGenerator.cj` | 产 `TESTING.md` + 测试源码 + test target 登记（process / sync 两轨） | 新建 | IF-12.2 |
| A9 process 轨接线 | `src/plugin/tools/plugingen/CrudPluginGenerator.cj`（**改造**） | 在既有产物写入之后调用 A8 + 生成末尾自校验（A6） | 改造 | IF-12.2 / IF-12.3 |
| A10 sync 轨接线 | `src/plugin/tools/plugingen/PluginGenerator.cj`（**改造**） | 同上（sync 轨测试源码 + 宿主 `cjpm.toml` target 登记） | 改造 | IF-12.2 |
| A11 构建登记 | `cjpm.toml` | 新增 pluginvalidate executable 段（镜像 `:146-147`） | 改造 | IF-12.1 分发形态 |
| — | `src/plugin/plugin_loader.cj:111-117` 既有 `validate` | **不改动**、不复用 | 既有 | — |

### 2.3 组件交互（两条主干）

**主干 ①：生成即自证**

```
作者 → plugingen(main) → 参数/mode 校验（既有 plugingen.cj:113-118 白名单）
     → 分支生成（既有 5 条分支，见 §1.1 G1）
     → 【新增】TestScaffoldGenerator.writeTestScaffold(mode, name, tables)
           · process: skills/{n}/src/test/smoke_test.cj + cjpm.toml test target
           · sync   : skills/{n}/src/test/{n}_smoke_test.cj + 宿主 cjpm.toml target
     → 【新增】TestScaffoldGenerator.writeTestingDoc()
     → 【新增】PluginManifestValidator.validate(dir, 默认 opts)   ← --no-selfcheck 可关
     → println 生成日志（沿用「已生成: 」风格）+ 自校验摘要行
```

**主干 ②：离线校验**

```
CI/作者 → pluginvalidate(main)
        → 解析 validate --path ...（未知参数用法 → printHelp + 退出码 2）
        → PluginManifestValidator.validate(dir, opts)
              · 读 plugin.yaml（不可读/不可解析 → I/O 域不可用 → 退出码 2）
              · 逐规则 check(ctx)：IO→CORE→MODE→EXE→RT→CAP→VER→DOC
              · 单规则异常 → skipped；上游不可用 → 该域 skipped
        → report_renderer.toText()/toJson()（脱敏 + 稳定排序）
        → 退出码：2 > 1(strict 下含 warn) > 0
```

---

## 3. 详细设计

### 3.1 模块 A1：`pluginvalidate.cj`（IF-12.1 CLI）

#### 3.1.1 类设计

`public func main(args: Array<String>): Unit` —— 与 `plugingen.cj:40` 的同名入口同构，无类封装（沿用既有工具写法，不引入新的 CLI 抽象）。

#### 3.1.2 参数设计与解析

严格镜像 `plugingen.cj:54-118` 的风格：

| 参数 | 行为 | 缺省 |
|---|---|---|
| `validate`（子命令位） | 必须为第一个 token；缺失或不识别 → `printHelp()` + 退出码 `2` | — |
| `--path <dir>` | 必填；指向插件目录 | — |
| `--format text\|json` | 非白名单值 → `printHelp()` + `2` | `text` |
| `--min-level error\|warn\|info` | 仅**显示**过滤（spec 5.2.1 规则 3） | `info` |
| `--strict` | warn 计入阻断 | 关 |
| `--skip <前缀>` | 可重复；前缀匹配规则号 | 空 |
| `--help` / `-h` | 打印帮助并退出 `0` | — |
| 其他 token | `printHelp()` + 退出码 `2`（对齐 `plugingen.cj:106-109` 的未知参数处理） | — |

> `printHelp()` 的选项清单必须覆盖上表全部条目，**不得**出现 `--fix` / `--write` 等暗示写能力的选项（只读契约）。

#### 3.1.3 交互地狱→退出码映射

```
读 plugin.yaml / 解析失败 / 路径不可用      → 退出码 2（先输出 AT-IO-01/03 再退出）
存在 ≥1 条 error                            → 退出码 1
--strict 且存在 ≥1 条 warn（无 error）       → 退出码 1
其余                                        → 退出码 0
```

#### 3.1.4 数据流

`args → ValidateOptions → PluginManifestValidator → ValidationReport → Renderer → stdout + 退出码`。全程不写盘。

### 3.2 模块 A2 / A3：类型与规则接口（IF-12.3 / IF-12.4）

#### 3.2.1 类型设计

```cangjie
// src/plugin/validator/validation_types.cj（新增示意，实际签名以 cangjie-coder 实现为准）
public enum Severity { | Error | Warn | Info }

public class Diagnostic {
    public let ruleId: String      // AT-<域>-<序号>
    public let level: Severity
    public let location: String    // <相对路径>:<行号>，不可定位时退化为文件名
    public let message: String     // 陈述事实；凭证值已 <redacted>
    public let hint: String        // error/warn 必非空（spec M-02）
}

public class Summary {
    public var errors: Int32 = 0
    public var warns: Int32 = 0
    public var infos: Int32 = 0
    public var skipped: Int32 = 0
    public var skipSources: ArrayList<String> = ArrayList<String>()  // 可辨来源
}

public class ValidationReport {
    public let plugin: String
    public let diagnostics: ArrayList<Diagnostic>
    public let summary: Summary
    public func passed(opts: ValidateOptions): Bool   // error==0 && (strict ? warns==0 : true)
    public func toText(): String
    public func toJson(): String
}

public class ValidateOptions {
    public let path: String
    public let format: String          // text | json
    public let minLevel: Severity      // 仅显示过滤
    public let strict: Bool
    public let skipPrefixes: ArrayList<String>
}
```

#### 3.2.2 规则接口（构造注入）

```cangjie
// src/plugin/validator/validation_rule.cj（新增示意）
public interface ValidationRule {
    func id(): String                                  // "AT-RT-02"
    func check(ctx: RuleContext): Array<Diagnostic>
}

public class RuleContext {
    public let pluginDir: String                       // 只读根目录
    public let manifestRaw: String                     // plugin.yaml 原文（用于行号定位）
    public let entries: Array<PluginManifestEntry>     // 复用宿主既有解析结果（oracle，不改其源码）
    public let cjpmToml: ?String                       // 可空；process 轨必需
    public func hasFile(rel: String): Bool             // 只读存在性查询
    public func lineOf(keyPath: String): Int32         // 键 → 行号；不可定位返回 -1
}
```

- **为什么用构造注入**：`PluginManifestValidator(rules: Array<ValidationRule>)` —— 下游测试可注入空规则数组单测框架本身；同时把「增加一条新规则」变成加一个实现 + 注册，不碰编排代码（spec M-01）。
- **为什么 `entries` 复用宿主 `PluginManifestEntry`**：与宿主同源 == 与第二处事实来源绝缘。它是**只读式复用**，本子系统不修改 `plugin_config.cj` 的一行代码（契约 §3）。

#### 3.2.3 类型 vs 清单 schema 的分工

`PluginManifestEntry.fromJsonValue`（`plugin_config.cj:122-208`）为**向后兼容**而对类型不符字段静默降级（`:156-165`）。静态侧因此必须在 A4 里对**原始 YAML 节点**逐字段做类型体检（`AT-CORE-06`），二者互补而不是替代。

### 3.3 模块 A4：`rules_manifest.cj`（本地规则）

| 规则组 | 判定输入 | 关键实现要点 |
|---|---|---|
| IO | 文件系统 + YAML 原文 | 不可用态直接由编排层短路到退出码 `2`；`AT-IO-04` 仅在 `mode == process` 时生效 |
| CORE | YAML 原始节点 + `PluginManifestEntry` | 必填组合（`name` / `className` / `command`）+ 重名 + **类型不符**（宿主在函数内静默降级为缺省值，静态侧补报） |
| MODE | `mode` 字符串 | 白名单 {`sync`,`dylib`,`process`} 取自宿主 `parseMode`（`plugin_config.cj:270-277`）的 `match` 分支集合，但**本子系统独立实现一份比较，不调用 `parseMode`**（它是 private） |
| EXE | `command` 路径 | 只做 `exists()` 与路径形态判断，**不执行、不读取内容**；相对路径与越界 `..` 只报 warn（spec S-03） |
| RT | `httpRoutes` / YAML `routes` 节点 | 复用既有 `ExternalRoute{method, path}`（`external_plugin_route_gateway.cj:565-573`）语义；method 解析口径与宿主一致，`path` 形态做四条子约束（5.4.1 规则 2） |

**行号定位策略**：对每条 YAML 键在 `manifestRaw` 中做「首个匹配键 + 缩进层级」定位；定位失败进 `-1`，渲染时退化为文件名（仍在退化点保留可诊断性）。

### 3.4 模块 A5：`rules_upstream.cj`（CAP / VER，**唯一的上游依赖收口点**）

> 这是本设计的**关键结构决策**：所有跨子系统依赖集中在一个文件。新增它的收益有三：① 依赖面可用 grep 一行验证（spec M-04）；② 上游未就位时可整文件替换为空实现来完成 §5 降级演练；③ 避免 CAP 语义散落到多处形成第二处事实来源。

#### 3.4.1 CAP 规则（消费 IF-05 / IF-07）

```
checkCap(ctx):
  1. 未声明 capabilities 且未声明 tableWhitelist
        → AT-CAP-03 warn（文案：实际策略由 capability-governance 在加载期经 CG-06 推导）
        → return
  2. 逐项能力串 → IF-05 的串→枚举解析入口
        · None     → AT-CAP-01 error（hint：参照 capability-governance 的 PluginCapability 枚举）
        · Some(cap) → 继续
  3. mode == process 时，用 IF-07 禁列表比对
        · 命中 → AT-CAP-02 error（hint **直接取用** IF-07 每条目自带的禁用理由串）
  4. 资源清单为空/非数组 → AT-CAP-04 warn（hint 不定义资源单位语义，指向 IF-05）
```

- **禁止**调用 `CapabilityGate.check`（IF-06）（spec 5.5.1 规则 5）。
- **自研禁令**：本文件**不得**出现任何能力字符串字面量（实现项目中若为了测试而出现，必须属测试替身文件，不得进主源码）。
- 上游不可引用 → 整组规则返回 `[skipped]`，由编排层计入 `summary.skipped` + `skipSources`（契约 §5）。

#### 3.4.2 VER 规则（消费 IF-02）

```
checkVer(ctx):
  1. pluginApi 缺失(Option::None) → AT-VER-01 warn
       文案模板：「插件未声明 pluginApi；兼容性由 version-guard 在加载前判定」
  2. version / pluginApi / hostVersionRange 存在但非 string → AT-CORE-06 error（YAML 隐式类型转换陷阱）
  3. 存在时，用 IF-02 同口径的版本解析入口做 parse
       · 解析失败 → AT-VER-02 error
       文案模板：「版本字段 '<field>' 格式非法；合法形如 X / X.Y / X.Y.Z；兼容性由 version-guard 在加载前判定」
  4. version 字段存在 → AT-VER-03 info（宿主当前忽略，消费方为 version-guard）
```

- **只 `parse`，不 `satisfies`、不 `check`**：保留 version-guard 对「是否满足」的唯一裁定权。
- 所有 VER 域文案**禁止**出现「拒绝加载 / 将被拒绝 / 不兼容」措辞（spec 5.6.1 规则 3）。

### 3.5 模块 A6：`plugin_manifest_validator.cj`（编排，IF-12.3）

#### 3.5.1 编排流程

```
validate(dir, opts):
  1. 前置：路径存在性 / plugin.yaml 存在性 / YAML 可解析性
       任一失败 → 返回「不可用」结果（CLI 映射退出码 2）
  2. 构造 RuleContext（只读视图）
  3. for rule in rules:
        if opts.skipPrefixes 命中 rule.id() → skipped++ ; continue
        try: diags = rule.check(ctx)
        catch: skipped++ ; skipSources.add(rule.id() + ":exception")   // A-02
        diags 逐条入池
  4. summary 聚合（errors/warns/infos/skipped）
  5. 稳定排序：ruleId 升序 → location 升序
  6. return ValidationReport
```

#### 3.5.2 为什么 `AT-CAP-*` / `AT-VER-*` 的 skipped 与 `--skip` 要分开计数

`summary.skipSources` 逐条记录来源串（`"AT-CAP-01:upstream-missing"` / `"AT-RT-01:exception"` / `"AT-DOC-02:cli-skip"`），使 CI 能区分「我没跑」与「跑不了」—— 若混计，一次上游未就绪会被误读成一次配置 omission。

### 3.6 模块 A7：`report_renderer.cj`（IF-12.4）

| 形态 | 格式 |
|---|---|
| text | `<ruleId> [<level>] <location>: <message> → <hint>`，末尾附 `Summary: errors=N warns=N infos=N skipped=N passed=<bool>` |
| json | `{"plugin":"...","passed":true,"summary":{...},"diagnostics":[{"ruleId","level","location","message","hint"}]}` |

- **脱敏在渲染层做**（而非规则层）：规则产出原文，渲染时对 `config` / `env` / secret 类键的值统一替换为 `<redacted>`（spec S-01）。这样规则单元测试不必重复断言脱敏。
- json 序列化失败 → 降级 text + stderr 一行原因，退出码不变（spec 5.7.3）。

### 3.7 模块 A8：`TestScaffoldGenerator.cj`（IF-12.2 测试脚手架）

#### 3.7.1 现状与差距

| 事实 | 证据 |
|---|---|
| 生成器产出不含任何测试 | §1.1 G1 实证；五条生成分支均落不到 `test/` |
| 宿主构建图里确有后置自检，但那是**框架自身集成自检**，不是可分发给作者的脚手架产物 | `src/plugin/integration/plugin_system_check.cj`（24KB）、`cordis_l3_check.cj`（8.8KB），由 `cjpm.toml:144-145` 登记 `magic.plugin.integration` executable |
| process 轨生成包名规则为 `skill_{name}`，`src-dir = "src"` | `CrudPluginGenerator.cj:207`、`:218`（`sb.append(" name = \"${pkgName}\"")` / `src-dir = "src"`，实际行段 `:208-243`） |

#### 3.7.2 产物矩阵

| 轨 | 测试源码 | 构建登记 | 文档 |
|---|---|---|---|
| process | `skills/{name}/src/test/smoke_test.cj` | `skills/{name}/cjpm.toml` 内 `[package.package-configuration."skill_{name}.test"] output-type = "executable"` | `skills/{name}/TESTING.md` |
| sync | `skills/{name}/src/test/{name}_smoke_test.cj` | 宿主 `cjpm.toml` 内 `[package.package-configuration."magic.plugins.{name}.test"] output-type = "executable"` | `skills/{name}/TESTING.md` |
| `--blank` | 同轨规则产出**占位级**测试（结构存在性断言） | 同上 | 同上 |
| `--contract-only` | **不产出**（无插件工程形态） | 不登记 | 生成日志说明原因 |

#### 3.7.3 测试内容设计（离线、纯函数级，≥3 项断言）

脚手架测试**只**断言可在离线环境成立的对象，典型三项起：

1. 清单自洽：`plugin.yaml` 可解析且 `plugins[0].name` 等于期望插件名（断言 1）；
2. 表白名单/能力声明存在性与形态（断言 2）；
3. 纯函数行为：对生成产物里某个**无 IO 依赖**的函数（如入参解析 / 文案拼装 / 路由表构造）做输入-输出断言（断言 3）。

> **待核实（O-4）**：sync 轨是否能在宿主 `cjpm.toml` 中以 `magic.plugins.{name}.test` 形式登记 target 而不污染宿主主包编译单元；若不可行，退化为「在 `skills/{name}` 下给出 `cjpm test` 说明 + 手工编译命令」，并在 TESTING.md 明示。**禁止**为了登记方便而把测试源码写进 `src/plugins/`。

#### 3.7.4 幂等与保护区

所有写入经 `templateEngine.updateFileWithMarkers(...)`（`TemplateEngine.cj:84-116`）并使用与文件类型匹配的标记对（CJ 源码 `//` 注释标记、TOML `#`、Markdown HTML 注释），与 `CrudPluginGenerator.cj:192/:237/:428/:491` 的既有调用同构。测试文件**整体在保护区内**，作者在区外的补充保留。

#### 3.7.5 写入原子性

`writeTestScaffold` 与 TESTING.md 属一个逻辑单元：**测试源码 + cjpm target 登记必须成对出现**；任一写入失败则打印原因并返回 `false`，由调用方按既有生成器失败语义处理（不抛异常、不留半截文件，spec A-05）。`AT-DOC-03` 是该不变式的静态侧兜底。

### 3.8 模块 A9 / A10：生成器接线

| 生成分支 | 源码位置 | 本轮新增动作 |
|---|---|---|
| process + CRUD | `CrudPluginGenerator.generate`（`plugingen.cj:151-195` 调用） | 既有产物写入完毕后 → `TestScaffoldGenerator`（process 形态）→ 末尾自校验 |
| process blank | `generateProcessPlugin`（`:204-214`） | 同上（占位级测试） |
| `--blank` | `generateBlankPlugin`（`:217-225`） | 同上（占位级测试） |
| sync CRUD（默认需 `--mode sync`，因为 `plugingen.cj:48` 缺省 `process`） | `generateCrudPlugin`（`:301-309`） | `TestScaffoldGenerator`（sync 形态 + 宿主 target 登记）→ 末尾自校验 |
| contract | `ContractGenerator.generate`（`:286-299`） | **不产出测试**（无工程形态），自校验不适用 → 跳过 |
| `--help` | `printHelp()`（`:338-372`） | 在选项清单（`:345-354`）中补充 `--no-selfcheck` 一行；**不新增 `--validate`** |

**自校验的行为口径**（避免与 `--mode` 白名单之外的既有语义冲突）：

- 默认开启；`--no-selfcheck` 关闭。
- 自校验**只输出摘要**（error 计数 + 前 N 条 error 的规则号），不替代作者显式跑 `plugin validate`。
- 自校验**不阻断生成结果**：生成已成功即返回成功；这是因为「生成成功但清单需要作者补全」与「生成失败」是两类事情，混淆会让 CI 无法区分。

### 3.9 关键决策记录（ADR）

| 编号 | 决策 | 备选 | 理由 |
|---|---|---|---|
| ADR-AT-1 | 校验能力落**独立 CLI** `plugin validate`，不给 `plugingen` 加 `--validate` | 加 `plugingen --validate` | 一个能力一个入口；`plugingen.cj:345-354` 无该项，新增会产生「生成时才校验」的错误暗示，CI 也难以只依赖生成器做门禁 |
| ADR-AT-2 | CLI 与生成末尾自校验**共用** `PluginManifestValidator` | 各写各的 | 两套实现必然漂移，而 S-01 的硬验收正是「生成完立即 validate 全绿」 |
| ADR-AT-3 | 上游依赖收口到 `rules_upstream.cj` 单文件 | 各规则自行 import | 依赖面可用一行 grep 验证；上游未就位时可整文件替换完成降级演练 |
| ADR-AT-4 | 清单解析**只读式复用**宿主 `PluginManifestEntry`，不改 `plugin_config.cj` | 自建一份解析以便加严格 schema | 与第二处事实来源绝缘（契约 §3）；宿主侧口径变更属 version-guard / 宿主，跨界改即 P0 |
| ADR-AT-5 | 版本仅 `parse`，不 `satisfies` / 不 `check` | 调 `VersionGuard.check` 给出「会被拒」预判 | 拒绝是加载期行为，静态期预判会造第二处事实来源；且 v1 `version-guard` 采缺省放行（ADR-VG-3），预判与缺省语义更易冲突 |
| ADR-AT-6 | `dylib` 报 error 而非 warn | warn | R-01 已证该轨运行时不可达（`plugin_dylib_loader.cj:146-151` 空实现），声明 `dylib` 必属错误；如需体检存量可用 `--skip AT-MODE` |
| ADR-AT-7 | 测试脚手架离线纯函数级 | 带 DB/宿主的集成测试模板 | authors 首次生成后应能在无环境下立即跑通（spec 5.1.1 规则 3 / S-06）；需要 DB 的测试由作者自选手段 |
| ADR-AT-8 | `plugin validate` **零写盘** | 写 `.validate-cache` 加速 | 只读契约是 CI 可信的前提；重复执行一致性（A-01）比缓存收益重要 |
| ADR-AT-9 | 0 新表 0 新列 0 新路由 | 落 `plugin_validation_log` 表 | 报告生命周期=一次进程；历史归属 CI 自身（契约 §2.4） |

---

## 4. 数据设计

### 4.1 数据模型

全部为**进程内对象**，无持久化：`ValidateOptions` / `Diagnostic` / `Summary` / `ValidationReport` / `RuleContext` / 各 `ValidationRule` 实现；测试脚手架产物为**文件**（见 §3.7.2 产物矩阵）。

### 4.2 数据表设计

**0 张新建表 / 0 个新建列。**

| 候选载体 | 为什么不需要 |
|---|---|
| `plugin_validation_result` 表 / `operate_log` 落校验结果 | 报告生命周期等于一次进程执行；历史报告的保留属 CI 自身职责（契约 §2.4） |
| 宿主配置文件记录「已跳过规则」 | `--skip` 是命令行瞬时选项，写盘即引入状态与漂移 |

**因此**：

- `sql/incremental/` **无新增 DDL**；
- `permissions` / `role_has_permission` **无新增登记行** —— 本子系统不新增任何宿主 HTTP 路由；
- 若实现中发现确需新列，须**先回主工程 `SPECS_INDEX.md` §6 登记**并写明复用不成立理由，再走 `loaddbinfo → crudgen/crudweb` 确定性生成，**禁止手写 DDL**。

### 4.3 数据关系

```
ValidateOptions 1 ── 1 ValidationReport 1 ── N Diagnostic
ValidateOptions 1 ── N skipPrefix ──→（前缀匹配）ValidationRule.id
RuleContext     1 ── N PluginManifestEntry（只读引用宿主既有解析结果，不持有副本语义）
RuleContext     1 ── 1 plugin.yaml 原文（用于行号定位）
ValidationReport 1 ── 1 Summary
```

---

## 5. API 设计

### 5.1 API 列表

**本子系统不提供任何 HTTP API / 宿主路由**（故无 `permissions` + `role_has_permission` 登记）。下表为对内/进程内等效清单：

| 类别 | 标识 | 契约条目 | 描述 |
|---|---|---|---|
| 命令行 | `plugin validate --path ... [--format ...] [--min-level ...] [--strict] [--skip ...]` | IF-12.1 | 唯一对外可对 CI 承诺的接口面 |
| 进程内 | `PluginManifestValidator.validate(dir, opts)` | IF-12.3 | 构造注入规则数组；`plugingen` 末尾自校验与 CLI 共用 |
| 进程内 | `ValidationRule.check(ctx)` | IF-12.3 | 规则插件点；新增规则 = 新增实现 + 注册 |
| 进程内 | `ValidationReport.toText()` / `toJson()` | IF-12.4 | 报告双形态渲染 |
| 文件产物 | `TESTING.md` + 测试源码 + cjpm test target | IF-12.2 | 生成器侧交付物 |

### 5.2 CLI 详细设计（`plugin validate`）

- **请求**：`plugin validate --path <插件目录> [--format text\|json] [--min-level error\|warn\|info] [--strict] [--skip <规则号前缀>...] [--help]`
- **响应**：stdout 报告；**退出码** `0` / `1` / `2`（语义见 §3.1.3）
- **错误约定**：**不新造错误码空间**；诊断一律以 `AT-<域>-<序号>` 规则号 + 严重级 + 位置 表达。规则号不进宿主 HTTP API 错误码空间，不与 `PluginError`（`plugin_types.cj` / `plugin_loader.cj`）混用。
- **幂等性**：只读幂等 —— 不写任何文件、不联网、不连 DB、不起宿主；同输入同输出。
- **副作用清单**：**无**。

---

## 6. 接口设计

### 6.1 内部接口

见 §5.1 表。

### 6.2 外部接口（跨子系统）

| 方向 | 对象 | 内容 | 稳定性承诺 |
|---|---|---|---|
| **入（我依赖）** | `capability-governance` IF-05 | `PluginCapability` 枚举与其串解析入口 | v1 冻结；新增枚举要素属 minor |
| **入（我依赖）** | `capability-governance` IF-07 | `HostUnsupportedCapabilities`（禁列表 + 每条目禁用理由串） | v1 冻结 |
| **入（我依赖）** | `version-guard` IF-02 | 清单版本字段口径与版本 parse 入口 | v1 冻结；**不调 IF-03** |
| **出（被消费）** | CI / 准入门禁 | 退出码 + json 报告 | v1 冻结；json 加 `schemaVersion` 属 minor |
| **出（被消费）** | `lifecycle-observability` | 存量清单体检 json 数据（**无接口调用**，纯数据消费） | 只读 |
| **出（被消费）** | 主工程 §5.1 用例 5 | 存量体检 report | 只读 |

> **显式不做**：不 import `CapabilityGate`（IF-06）、不 import `VersionGuard.check`（IF-03）、不 import `HandshakeVerifier`（IF-09）；上游不得反向 import 本子系统。违反按契约 §3.3 判 P0。

---

## 7. 安全设计

### 7.1 认证机制

不适用（本地 CLI，无跨进程鉴权面）。

### 7.2 权限控制

- 本子系统不新增宿主路由与权限项（0 新路由 → 无 `permissions` 登记），因此不涉及行级权限口径。
- 若将来 `plugin validate` 被包装成宿主 HTTP 管理端点，**不在本子系统范围内**，须回主工程登记组件归属与权限项。

### 7.3 数据安全

| 措施 | 落地 |
|---|---|
| 凭证不回显 | 渲染层统一 `<redacted>`；规则层产出原文但引用键值前先走脱敏谓词（§3.6） |
| 不执行被校验方代码 | 只做文本/结构扫描，无反射、无 import、无子进程（§3.3 EXE 组） |
| 不暴露宿主结构 | 报告 `location` 一律用**相对**路径；`AT-EXE-02` hint 不拼接宿主绝对路径 |
| 异常不外泄 | 单规则异常被编排层捕获 → `skipped + exception` 标记，不输出原始栈到 stdout（stderr 只在 `--format json` 渲染失败时输出一行原因） |

### 7.4 审计

本子系统自身**不写审计**（0 新表）。若宿主未来要求「谁校验了什么」，应复用于调用方 CI 日志或既有 `operate_log`，且须先回主工程登记。

---

## 8. 性能设计

### 8.1 性能目标

见 spec §4.1 P-01~P-04：单插件 ≤ 500 ms；51 个存量全量体检 ≤ 30 s；全程零网络/零 DB/零进程拉起；生成总耗时增量 ≤ 10%。

### 8.2 优化策略

1. **单次读取**：`plugin.yaml` 原文读一次，供解析与行号定位共用；`cjpm.toml` 惰性读取（仅 process 轨或 RT/DOC 域需要时）。
2. **线性扫描**：规则遍历为单次线性，规则数量级 < 40，无需建索引。
3. **零 IO 规则**：除 IO 域外，其余规则**只读内存视图**（`RuleContext`），避免在规则层反复 `open()`。
4. **排序一次**：稳定排序在报告产出前做一次（O(n log n)，n 为诊断条数，量级个位数到几十）。
5. **生成器增量可控**：测试脚手架为 2~3 个小文件写入，相对既有 10+ 文件产物，增量符合 P-04。

---

## 9. 部署设计

### 9.1 部署架构

无独立常驻进程。交付形态为两个随 release 分发的 executable：

| 目标 | `cjpm.toml` 登记 | 变更类型 |
|---|---|---|
| `magic.plugin.tools.plugingen` | 既有 `cjpm.toml:146-147` | 源码改造（不换包名） |
| `magic.plugin.tools.pluginvalidate` | **新增** `[package.package-configuration."magic.plugin.tools.pluginvalidate"]` + `output-type = "executable"`（镜像 `:146-147` 写法） | 新增段 |

> **待核实（O-1）**：新增包 `magic.plugin.validator` 是否需在 `cjpm.toml` 显式登记源码目录/包路径；实现步第一步须确认本仓的包布局与 `cjpm.toml` 约定，避免「文件在但不参与编译」。

### 9.2 环境配置

| 开关 | 缺省 | 作用 |
|---|---|---|
| `--no-selfcheck` | 关（即自校验**默认开**） | 生成器末尾跳过进程内自校验 |
| `--strict` | 关 | warn 计入阻断退出码 |
| `--skip <前缀>` | 空 | 关闭指定规则域；存量体检建议 `--skip AT-DOC` |

无环境变量、无 DB 迁移、无 `sql/incremental/` 变更。

### 9.3 编译与回归

- AI **不运行 `cjpm build`**；编译、类型检查、lint 由人工在独立 cmd 环境执行并回传。
- 回归锚点：既有 51 个 skill 插件 + 4 个 sync 锚点清单零修改、行为零变化（R-04）。

---

## 10. 附录

### 10.1 风险登记（对齐 SPECS_INDEX §7）

| 编号 | 风险 | 本子系统处置 |
|---|---|---|
| R-01 | `dylib` 轨运行时不可达 | 报 `AT-MODE-02`（error）+ hint 说明无落点；不复活该轨（ADR-AT-6） |
| R-04 | 存量 51 + 4 防回退 | 默认档不引入新必填项；S-05 只读体检 + 哈希比对（spec §5.8） |
| R-05 | `InitializeParams` 双子系统抢改 | 本子系统**不碰** `libs/cordis-cj`，无共享文件冲突面 |
| R-09（建议） | `pluginuninstall` 未登记 executable + `--mode` 行级匹配仅 warn（`pluginuninstall.cj:295-317`） | 本子系统**不改**；已建议在契约 §4 由主工程登记为 R-09 |
| — | RSI 自评循环 | **明确不纳入**：不提供每 N 轮后台自评触发器与 LRT 五环节编排（已移交 `specs/RSI`） |

### 10.2 开放项 / 待核实清单

| 编号 | 问题 | 影响 | 建议处理 |
|---|---|---|---|
| O-1 | 新包 `magic.plugin.validator` 与 `magic.plugin.tools.pluginvalidate` 是否需显式登记源码目录 | 不登记则文件不参与编译 | 实现步第一步确认 `cjpm.toml` 包/路径约定 |
| O-2 | `PluginLoader.validate`（`plugin_loader.cj:111-117`）的调用点是否已为零 | 若仍有调用点，其「仅查空名」行为与本组件并存可能造成误解 | grep 复核调用点；无论是否有调用点，本组件**不改动它** |
| O-3 | process 轨测试 target 的运行命令是否确为 `cjpm run --skip-build --name skill_{name}.test`（在 `skills/{name}/` 下执行） | 决定 S-06 用例脚本写法 | 与宿主导出约定核对；若不同，以实际可执行命令为准并回写 tasks.md 用例 |
| O-4 | sync 轨能否在宿主 `cjpm.toml` 登记 `magic.plugins.{name}.test` 而不污染主包 | 决定 sync 轨测试的可执行方式 | 见 §3.7.3；不可行则退化为文档化手工编译命令 |
| O-5 | `PluginCapability` 串解析入口的确切导出名与包路径（IF-05 冻结后的最终形态） | 决定 `rules_upstream.cj` 的 import 书写 | 实现步以 `capability-governance` 最终 code 为准，**不得**臆造 API |
| O-6 | version-guard 版本 parse 入口的确切导出名（IF-02） | 同上 | 同上；不得自建 semver 解析器 |
| O-7 | 既有 51 个 `skills/*` 中是否存在 `mode: dylib` 或异常 `mode` 值的清单 | 决定 S-05 的默认档是否会立刻红 | 体检首跑时统计；若存在，主工程决定是否将其列入 R-09 或直接修清单（本子系统不擅自代修清单） |

### 10.3 参考文档

| 文档 | 路径 |
|---|---|
| 主工程边界账本 | `specs/plugin-system-enhancement/SPECS_INDEX.md` |
| 集成契约 | `specs/plugin-system-enhancement--authoring-toolchain/contract.md` |
| 需求规格 | `specs/plugin-system-enhancement--authoring-toolchain/spec.md` |
| 任务规划 | `specs/plugin-system-enhancement--authoring-toolchain/tasks.md` |
| 上游 contract / design | `specs/plugin-system-enhancement--capability-governance/{contract,design}.md`、`specs/plugin-system-enhancement--version-guard/design.md` |
| 开发规范源 | `skills/uctoo-dev-manual/` + `docs/uctoo-v4/*.md`（接口→`uctoo-v4-api-specification`；表字段→`uctoo-database-design-specification`；CRUD→`uctoo-v4-module-development` + `uctoo-v4-orm-specification`；权限→`user-permission-system` / `row-level-permission-system`） |
| 模板 | `skills/sdd/templates/{spec_template,ears-format,design_template,tasks-template}.md` |
| 源码实证 | `src/plugin/tools/plugingen/{plugingen,CrudPluginGenerator,PluginGenerator,TemplateEngine}.cj`、`src/plugin/{plugin_config,plugin_loader,external_plugin_route_gateway}.cj`、`cjpm.toml:146-147` |

### 10.4 变更历史

| 版本 | 日期 | 作者 | 变更说明 |
|---|---|---|---|
| 1.0 | 2026-10-19 | SDD 文档步（authoring-toolchain） | 初始版本：A1~A11 模块设计 + ADR-AT-1~9 + 风险/开放项；确认 0 新表 0 新列 0 新路由；锁定两条 GAP 实证（生成无测试、无独立 validate） |
