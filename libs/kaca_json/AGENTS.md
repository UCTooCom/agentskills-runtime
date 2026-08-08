# Repository Guidelines

## 项目概览

- **名称**: `kaca_json` — 仓颉 JSON/JSON5 解析与序列化库
- **语言**: 仓颉 (Cangjie) v1.0.5 (cjc v1.0.5, cjpm v1.0.5)
- **类型**: 静态库 (`output-type = "static"`)，编译选项 `-Woff all -O2`
- **目标**: 提供严格 JSON (RFC 8259/ECMA-404)、Fast 路径、JSON5 的完整语义对齐实现，以及序列化、JSON Path、JSON Patch (RFC 6902) 能力
- **设计原则**: 不依赖 `stdx`，仅使用仓颉 `std` 标准库；测试代码与测试数据统一位于独立项目 `kaca_projects` 中

## 目录布局

```
src/                   # 运行时库源码
  main.cj              # 公开 API 入口：JSON 类 (parse/stringify/path) + JsonPatch 类
  json_value.cj        # JsonValue 枚举 (Null/Bool/Number/String/Array/Object) 及助手方法
  json_error.cj        # JsonError 异常体系 (含 JsonErrorCode 枚举与行列号追踪)
  json_fast_parser.cj  # Fast 路径解析器 (FastValue 零拷贝惰性解析)
  json5_parser.cj      # JSON5 解析器 (支持注释、单引号、尾逗号、NaN/Infinity)
  json_number_parser.cj # 数字解析 (严格 JSON 与 JSON5 双路径)
  json_stringifier.cj  # 序列化器 (紧凑/缩进/过滤器模式)
  json_patch.cj        # JSON Patch (PatchOp 枚举 + PatchOperation 类)
  json_path.cj         # JSON Path 查询引擎 (支持通配符与递归下降)
  json_utf8_utils.cj   # UTF-8 工具函数 (查表转义、字符分类、Unicode 代理对)
examples/              # 7 个示例程序 (basic_usage, fast_usage, json5_usage, patch_usage 等)
scripts/               # Node.js 基准/兼容性测试脚本 + CI 入口 (ci.sh/ci.ps1)
docs/                  # 开发文档 (性能迭代记录、标准测试来源审计、JSON5 源码映射)
```

## 构建、测试与开发命令

```bash
cjpm build              # 完整构建 (release 模式, -O2)
cjpm build -i           # 增量构建 (仅编译变更文件)
cjpm test               # 运行测试 (测试代码位于 kaca_projects/tests/kaca_json/)
cjpm test --filter NAME # 按 TestCase 方法名筛选
```

编译器: `cjc v1.0.5`，编译选项 `-Woff all -O2`。无第三方依赖（仅 `std` 标准库）。

## 编码风格

- **注释**: 全部使用简体中文。文档（`*.md`）也使用简体中文。
- **文件**: 仓颉源文件使用 `.cj` 扩展名。
- **命名**: 类/枚举/接口使用 PascalCase（`JsonValue`、`FastValue`、`PatchOperation`）；方法与变量使用 camelCase（`parse`、`getString`、`toJsonValue`）；枚举变体使用 PascalCase（`JsonNull`、`JsonBool`、`PatchOp.Add`）。
- **match 表达式**: `case` 后不使用 `{}`，分支体直接书写，最后一个表达式即为返回值。
- **公开 API**: 使用 `public class` / `public enum` / `public func` 声明；内部辅助函数使用 `private func`。
- **导入风格**: 统一使用 `import std.collection.*` 通配导入。
- **错误处理**: 自定义异常类继承 `Exception`，使用 `throw` 抛出；非抛出版本使用 `try { ... } catch (_: Exception) { None }`。
- **字符串操作**: 使用 `str.toArray()` 将 `String` 转为 `Array<Byte>`；使用 `"${...}"` 进行字符串插值。

## 公开 API 概览

所有公开入口位于 `src/main.cj` 的 `JSON` 和 `JsonPatch` 类：

```
JSON.parse(input: String | Array<Byte>): JsonValue
JSON.parseOrNull(input: String | Array<Byte>): ?JsonValue       # 解析失败返回 None
JSON.parseFast(input: String | Array<Byte>): FastValue          # 零拷贝惰性解析路径
JSON.parseFastOrNull(input: String | Array<Byte>): ?FastValue
JSON.parseJson5(input: String): JsonValue                       # JSON5 解析入口
JSON.parseJson5OrNull(input: String): ?JsonValue
JSON.stringify(value: JsonValue, [indent | options]): String
JSON.path(value: JsonValue, path: String): ArrayList<JsonValue>
JSON.pathFirst(value: JsonValue, path: String): ?JsonValue
JsonPatch.apply(value, operations) / .add / .remove / .replace / .move / .copy / .test
```

`FastValue` 提供惰性解析（按需物化），通过 `toJsonValue()` 转为完整 `JsonValue`。`JsonValue` 提供 `requireXxx()` / `asXxxOrNull()` / `push()` / `put()` 等助手方法。

## 仓颉语言要点

- **Option\<T\>**: 不支持 `==` 比较，使用 `isSome()` / `isNone()` 配合模式匹配。
- **枚举相等性**: 枚举必须显式实现 `==` 和 `!=`；若用作 `HashMap` 键，还需实现 `Hashable & Equatable`。
- **类型互换**: `UInt8` 与 `Byte` 等效，`Array<UInt8>` 和 `Array<Byte>` 可互换。
- **异常**: `panic()` 不可用，使用 `throw Exception(...)` 或 `throw JsonError(code, msg, line, col, ctx)`。
- **Lambda**: 语法为 `{key, value => body}`，无类型标注、无括号。
- **If 表达式**: `if (cond) { expr } else { expr }` — if 是表达式，可以赋值。
- **循环**: 使用 `while (cond) { ... }` 和 `for (elem in collection) { ... }`。

## Commit 规范

项目 Git 历史遵循 [Conventional Commits](https://www.conventionalcommits.org/) 约定：

| 前缀 | 用途 | 示例 |
|------|------|------|
| `feat:` | 新功能 | `feat: add JSON5 hex integer literal support` |
| `fix:` | 修复 | `fix: reset pos on failed surrogate pair attempt` |
| `perf:` | 性能优化 | `perf: precompute lookup table for string scan` |
| `refactor:` | 重构 | `refactor: merge strict parser and optimize json5 parsing path` |
| `docs:` | 文档 | `docs: add stdx independence declaration` |
| `chore:` | 构建/工具/元数据 | `chore: update README with tag reference` |

变更描述可使用中文，建议将 scope（如 `(json5)`）嵌入前缀后的括号中。PR 应附带变更说明和测试通过依据。

## 性能与优化指南

本项目以性能优先作为目标，在标准语义门禁通过的前提下进行关键路径优化：

- **Fast 路径**: `FastValue` 使用零拷贝惰性解析，仅在访问具体字段时才物化子节点。
- **查表优化**: 关键扫描路径使用预计算查找表（`ESCAPE_BYTE_MAP`、`HEX_VALUE_TABLE`、`CHAR_CLASS_TABLE`）替代条件分支。
- **单遍解析**: 数字解析与 JSON5 解析器采用单遍扫描，避免回溯。
- **基准测试**: 使用 `scripts/benchmark.js` 和 `scripts/comparison_report.js` 控制性能回归；详细迭代记录见 `docs/perf-iteration-2026-04-29.md`。

性能变更应附带基准数据对比，并在 PR 中注明吞吐量变化。
