# cjpm 宏包依赖缺陷排查记录：带 organization 的宏包跨模块传递失败

**日期**：2026-08-15（cordis-cj P4 开发期间）
**项目**：cordis-cj（仓颉 Cordis 动态组合框架）
**结论**：cjpm 对**带 organization 的宏包**做跨模块依赖传递时，宏 .so 未链接到调用方的可执行目标，导致 `import xxx.macros.*` 报 `undeclared identifier`。去掉 `organization` 字段后宏立即可用。

---

## 1. 现象

在 cordis-cj 的 `cordis_plugin` 模块中实现了宏包：

```cangjie
// cordis_plugin/src/macros/plugin_macros.cj
macro package ystyle::cordis_plugin.macros
import std.ast.*
public import ystyle::cordis_plugin.PluginRuntime   // 重导出运行时符号

public macro Plugin(attr: Tokens, input: Tokens): Tokens { ... }
public macro Provide(attr: Tokens, input: Tokens): Tokens { ... }
```

调用方（**独立模块** `cordis_examples`，依赖 `ystyle::cordis_plugin`）：

```cangjie
package ystyle::cordis_examples
import ystyle::cordis_plugin.macros.Plugin

@Plugin[]          // ← 报错：undeclared identifier 'plugin'
public class SimplePlugin {}
```

**编译错误**：

```
error: undeclared identifier 'plugin'
  ==> .../cordis_examples/src/main.cj:5:2:
   |
 5 | @plugin
   |  ^

warning: unused import 'ystyle::cordis_plugin.macros.Plugin'   ← 符号根本没导入成功
error: 'main' is missing
```

即：import 语句被当作「未使用」忽略（符号未解析），宏调用报未声明。

## 2. 排查过程

### 2.1 确认宏包本身编译正常

宏包产物已正确生成：

```
target/release/cordis_plugin@ystyle/cordis_plugin.macros@ystyle.cjo
target/release/cordis_plugin@ystyle/lib-macro_cordis_plugin.macros@ystyle.so
```

cjo 头部元数据确认宏包身份与符号：

```
{"package":"ystyle::cordis_plugin.macros","isMacro":true,"accessLevel":"public",...}
_CN27ystyle:cordis_plugin.macros47macroCall_a_Plugin_ystyle__cordis_plugin_macrosHPhlPhlPuE16callMacroCallPtrIuE
```

`isMacro: true` + `Plugin` 宏符号都在 → **宏包编译与导出本身无问题**。

### 2.2 排除宏代码本身的问题

- 单独用 `cjc` 编译宏包：通过（仅 unused 警告）。
- 宏代码的 quote/插值/Token 构造经多轮修正后已能生成正确的 main 代码（见下方「宏展开成功」的对照实验）。

### 2.3 同模块调用 → 假失败与真成功的区分

把宏示例移入 `cordis_plugin` 模块内（`cordis_plugin/src/examples/macro_demo/`，即 CJson 的模式）后，**当时**遇到 `undeclared identifier 'plugin'`。但后续排查发现，那个失败是**宏代码本身的多个问题**导致的（见 §2.5 与 P4 踩坑：属性宏大小写不匹配 `@plugin` vs `@Plugin[]`、宏展开代码用限定路径引用运行时符号等），**并非 organization 问题**。

**最终实证（clean 后重建）**：同模块 + 带 organization 的宏调用**稳定可用**——`cjpm clean && cjpm build` 成功产出宏插件可执行文件，38 个用例（含宏插件端到端）全部通过。

### 2.4 决定性对照实验：跨模块去掉 organization

临时把 `cordis_plugin/cjpm.toml` 的 `organization = "ystyle"` 注释掉（包名随之从 `ystyle::cordis_plugin` 变为 `cordis_plugin`），同时把**独立模块**调用方的 import 和依赖名改为无 org 形式：

```toml
# cordis_plugin/cjpm.toml
[package]
  name = "cordis_plugin"
  # organization = "ystyle"   ← 注释掉
```

```cangjie
import cordis_plugin.macros.Plugin
```

```toml
# cordis_examples/cjpm.toml
[dependencies]
  "cordis_plugin" = { path = "../cordis_plugin" }   ← 无 org 引用
```

结果：**立即编译成功，宏正常展开**。这确认了根因与 `organization` 强相关。

### 2.5 业界对照

| 项目 | organization | 宏包 | 调用方 | 是否可用 |
|---|---|---|---|---|
| kux-cj | 无 | `kux.macros` | 独立模块 `example`，`import kux.macros.*` | ✅ 可用 |
| CJson | 无 | `CJson.jsonmacro` | 同模块 test/example，`import CJson.jsonmacro.*` | ✅ 可用 |
| cordis-cj（带 org，跨模块） | `ystyle` | `ystyle::cordis_plugin.macros` | 独立模块 `cordis_examples` | ❌ 失败 |
| cordis-cj（带 org，同模块） | `ystyle` | `ystyle::cordis_plugin.macros` | 同模块 `examples/macro_demo` | ✅ 可用（clean 重建验证） |
| cordis-cj（去掉 org，跨模块） | 无 | `cordis_plugin.macros` | 独立模块 | ✅ 立即可用 |

对照结论：kux / CJson 均无 organization 且可用；cordis-cj **带 org 时同模块可用、跨模块失败**；**去掉 org 后跨模块立即可用**。

## 3. 根因结论

**cjpm 对「带 organization 的宏包」存在跨模块依赖传递缺陷**：

- 宏包编译为 `lib-macro_<pkg>.so`（宏动态库），调用方编译宏调用时需要把该 .so 加入宏解析/链接路径。
- 当宏包所在模块声明了 `organization`（包名变为 `org::pkg`）时，cjpm **跨模块**传递依赖时没有把宏 .so 正确带给调用方，调用方编译时宏符号缺失。
- 去掉 `organization` 后包名退化为 `pkg`（与 kux/CJson 相同），cjpm 的宏依赖传递路径恢复正常。
- **同模块内**（宏包与调用方同属一个模块）带 organization 仍可用——缺陷只影响跨模块消费。

具体到 cjpm 内部是「宏 .so 未链接」还是「import 元数据未传递」，从外部可观察的行为是：import 报 unused（符号未解析）+ 宏调用 undeclared。需要 cjpm 源码层面进一步确认（未深入）。

## 4. 规避方案

### 方案 A（推荐）：宏包与调用方同模块（cordis-cj 采用的最终方案）

宏包与插件 SDK 放同一模块（`cordis_plugin/src/macros/`），宏示例/宏消费方放同模块（`cordis_plugin/src/examples/macro_demo/`）。带 organization 时**同模块稳定可用**（`cjpm clean && cjpm build` 验证通过）。

配合的关键修复（P4 踩坑）：
1. 宏调用大小写匹配定义：`@Plugin[]`（不是 `@plugin`），属性宏必须带 `[]`
2. 宏包 `public import ystyle::cordis_plugin.PluginRuntime` 重导出运行时符号，展开代码用**短名**引用（不能写 `ystyle::cordis_plugin.PluginRuntime` 限定路径）

### 方案 B：去掉 organization（kux 模式，供跨模块消费）

发布库若主要消费方是**外部独立模块**的宏用户，去掉 organization（包名 = 模块名），与 kux/CJson 保持一致。代价：包名不带组织前缀，发布名规则不同。

### 方案 C：等待 cjpm 修复

缺陷属 cjpm 宏生态通用问题，建议向官方反馈「宏 .so 依赖传递不应依赖 organization 有无」。

## 5. 复现步骤（最小示例）

> 分隔符约定：`orgname::pkgname.subpkg` —— organization 与包名之间用 `::`，包内子包用 `.`。
> 注意：`organization` 本身必须是合法标识符（字母/数字/下划线），**不能含 `.`**，例如 `example_org`（而非 `com.example`）。

1. 模块 `mylib` 声明 `organization = "example_org"`（完整包名 `example_org::mylib`），内含 `macro package example_org::mylib.macros`，定义 `public macro Foo(...)`。
2. 另一模块 `myapp` 依赖 `"example_org::mylib" = { path = "../mylib" }`，源码 `import example_org::mylib.macros.Foo` + `@Foo[]`。
3. `cjpm build` → `undeclared identifier 'foo'` + import unused。
4. 去掉 `mylib/cjpm.toml` 的 `organization`（完整包名变为 `mylib`），同步改依赖名为 `"mylib"` → 编译通过。

## 6. 关联影响与建议

- **发布宏库**：若宏包与运行时同模块发布（CJson/embed-cj 模式），消费者 `import <module>.macros.*`；建议测试时覆盖「带 organization 的跨模块消费」场景。
- **给 cjpm 的反馈**：宏 .so 的依赖传递应不依赖 organization 有无；这是 cjpm 宏生态的通用问题，值得上报。
- **cordis-cj 决策**：保留 organization（保证包名规范），宏示例/插件同模块；跨模块宏消费留待 cjpm 修复或按需去掉 org。
