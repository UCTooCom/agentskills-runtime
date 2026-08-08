# kaca_json

> **本项目 不依赖 stdx** — 所有依赖仅来自仓颉 `std` 标准库和 `kaca_*` 系列项目。

## 1. 本项目通过了哪些标准测试
- 标准：RFC 8259/ECMA-404 JSON 语义对齐测试（基于 JSONTestSuite 与 test262 迁移子集）
- 范围：`number/string/structure/array/object` 子集、`implementation/textual` 稳定性子集、`deferred_byte_boundary` 严格字节策略子集、`test262 JSON.parse` 词法子集
- 结果（通过数/总数）：`18/18`（`StandardParserTests`）
- 统计日期：2026-04-29

- 标准：JSON5 语义测试（基于 `json5` 官方仓库迁移子集）
- 范围：合法/非法样例、转义、对象键、错误行为、`NaN/Infinity` 语义子集
- 结果（通过数/总数）：`9/9`（`Json5OfficialSubsetTests`）
- 统计日期：2026-04-29

- 标准：严格 JSON 与 Fast 路径一致性门禁
- 范围：JSONTestSuite 子集 + test262 词法子集 + implementation textual 子集的一致性与确定性
- 结果（通过数/总数）：`4/4`（`LegacyAndFastConformanceTests`）
- 统计日期：2026-04-29

- 当前项目全量测试回归
- 范围：`tests/kaca_json` 全部测试类
- 结果（通过数/总数）：`43/43`
- 统计日期：2026-04-29

## 2. 实现这些标准测试有什么好处
- 行为一致性：解析与序列化行为与主流 JSON/JSON5 语义对齐，减少跨语言与跨实现差异。
- 兼容性：统一 `JSON.parse`、`JSON.parseFast`、`JSON.parseJson5` 的语义门禁，便于上层模块无缝替换解析入口。
- 可维护性：通过标准样例与子集门禁形成稳定回归基线，优化或重构时可快速识别语义回退。

## 3. 本项目暴露哪些接口（含接口说明和简单示例）
接口清单（公开入口位于 `src/main.cj`）：
- `JSON.parse(input: String): JsonValue`
- `JSON.parse(input: Array<Byte>): JsonValue`
- `JSON.parseOrNull(input: String): ?JsonValue`
- `JSON.parseOrNull(input: Array<Byte>): ?JsonValue`
- `JSON.parseFast(input: String): FastValue`
- `JSON.parseFast(input: Array<Byte>): FastValue`
- `JSON.parseFastOrNull(input: String): ?FastValue`
- `JSON.parseFastOrNull(input: Array<Byte>): ?FastValue`
- `JSON.parseJson5(input: String): JsonValue`
- `JSON.parseJson5OrNull(input: String): ?JsonValue`
- `JSON.stringify(value: JsonValue): String`
- `JSON.stringify(value: JsonValue, indent: Int64): String`
- `JSON.stringify(value: JsonValue, options: StringifyOptions): String`
- `JSON.path(value: JsonValue, path: String): ArrayList<JsonValue>`
- `JSON.pathFirst(value: JsonValue, path: String): ?JsonValue`
- `JsonPatch.apply(value: JsonValue, operations: ArrayList<PatchOperation>): JsonValue`
- `JsonPatch.add/remove/replace/move/copy/test(...)`
- `JsonValue` 助手方法：`requireXxx`、`asXxxOrNull`、`push`、`put`

核心接口说明：
- 接口名：`JSON.parse`
- 输入参数：`String` 或 UTF-8 `Array<Byte>`。
- 返回值：`JsonValue`。
- 失败行为：非法 JSON 时抛出 `JsonError`（或其上层异常）。

- 接口名：`JSON.parseOrNull`
- 输入参数：`String` 或 UTF-8 `Array<Byte>`。
- 返回值：`?JsonValue`。
- 失败行为：非法输入时返回 `None`，不抛出异常。

- 接口名：`JSON.parseFast`
- 输入参数：`String` 或 UTF-8 `Array<Byte>`。
- 返回值：`FastValue`（可通过 `toJsonValue()` 物化为 `JsonValue`）。
- 失败行为：非法 JSON 时抛出异常。

- 接口名：`JSON.parseJson5`
- 输入参数：`String`。
- 返回值：`JsonValue`。
- 失败行为：非法 JSON5 时抛出异常；`parseJson5OrNull` 返回 `None`。

- 接口名：`JSON.stringify`
- 输入参数：`JsonValue` 与可选缩进/选项。
- 返回值：JSON 字符串。
- 失败行为：通常不抛语义错误；若输入结构异常则按运行时异常处理。

- 接口名：`JsonPatch.apply`
- 输入参数：目标 `JsonValue`、补丁操作列表 `ArrayList<PatchOperation>`。
- 返回值：应用补丁后的新 `JsonValue`。
- 失败行为：补丁非法或路径错误时抛出 `JsonPatchError`。

简单示例（最小可运行）：
```cangjie
import kaca_json.*

main(): Int64 {
    let value = JSON.parse("{\"user\":{\"name\":\"cj\"},\"age\":3}")
    let name = JSON.pathFirst(value, "$.user.name").getOrThrow().requireString()

    let ops = JsonPatch.createList()
    ops.add(JsonPatch.replace("/age", JsonValue.JsonNumber(4.0)))
    let patched = JsonPatch.apply(value, ops)

    println(name)
    println(JSON.stringify(patched, 2))
    0
}
```

## 4. 通过这些标准测试时引用了哪个项目的测试数据
- 来源项目：`nst/JSONTestSuite`
- 路径/类别：`testdata/kaca_json/standard/json_test_suite/**`
- 引用用途：验证严格 JSON 的合法/非法输入、结构与字符串/数字边界行为。

- 来源项目：`tc39/test262`
- 路径/类别：`testdata/kaca_json/standard/test262/parse/source/**`
- 引用用途：验证 `JSON.parse` 词法子集（空白符、转义、字符串规则等）。

- 来源项目：`json5/json5`
- 路径/类别：`testdata/kaca_json/legacy/compatibility/**` 与 `tests/kaca_json/src/json5_official_subset_test.cj` 对应映射子集
- 引用用途：验证 JSON5 语义子集（对象键、尾逗号、转义、错误输入等）。

## 5. 如何引入本项目
依赖配置（`cjpm.toml`）：
```toml
[dependencies]
kaca_json = { git = "https://gitcode.com/cangjie_no_1/kaca_json.git", tag = "v1.0.0" }
```

推荐使用方式：
- 生产依赖建议锁定已验证版本（tag/commit）。
- 开发联调可使用工作区同级工程依赖进行本地验证。

最小导入与调用：
```cangjie
import kaca_json.*

main(): Int64 {
    let v = JSON.parse("{\"ok\":true}")
    println(JSON.stringify(v))
    0
}
```

## 6. 本项目是使用 AI 进行开发的
本项目使用 AI 辅助开发，覆盖解析器重构、性能优化实验、测试迁移与文档整理。

## 7. 本项目以性能优先作为目标
本项目以性能优先作为目标，在严格标准语义门禁通过的前提下进行关键路径优化，采用基准测试与 A/B 对照控制回归风险。

## 8. 本项目与测试代码、测试数据分离（测试代码统一在 kaca_projects 项目中）
本项目运行时代码与测试资产分离：
- 运行时代码：`kaca_projects/kaca_json/`
- 测试代码：`kaca_projects/tests/kaca_json/`
- 测试数据：`kaca_projects/testdata/kaca_json/`
