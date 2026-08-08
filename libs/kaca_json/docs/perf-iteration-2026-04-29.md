# kaca_json 性能优化记录（2026-04-29）

## 本轮目标
1. 在严格标准模式前提下继续寻找 `parseFast` 与 `parseFast(...).toJsonValue()` 的优化空间。
2. 使用 WSL/Linux 的 `cjprof` 做采样，禁止使用 Windows 原生 `cjprof` 结果。

## 环境与命令
- 环境：WSL + `/opt/cangjie-1.1.0/cangjie/envsetup.sh`
- 目录：`/mnt/c/Users/27482/Desktop/kaca_projects/tests/kaca_json`
- 关键命令：
  - `cjpm test --no-color`
  - `cjpm bench --filter ParserBenchLarge --no-color`
  - `cjpm bench --filter StrictParseStrategyBench --no-color`
  - `cjpm bench --filter PublicApiFastWrapperBench --no-color`
  - `cjprof record ... --filter=ParserBenchLarge.fastParse`
  - `cjprof report ...`

## 采样结论（改动前）
- `ParserBenchLarge.fastParse` 热点集中在 `StrictJsonValidator`：
  - `StrictJsonValidator::parseValue`
  - `StrictJsonValidator::parseString`
  - `StrictJsonValidator::parseNumber`
- `PublicApiFastWrapperBench.apiParseToJson` 路径热点在：
  - `parseFastJsonValueNested`
  - `parseFastObjectValueToJson`
  - `StrictJsonValidator::parseValue`

## 本轮改动
文件：`kaca_json/src/json/strict_validator.cj`
1. 将 `parseObject/parseArray` 中重复的“先判断空白再调用 skip”逻辑提取为 `skipWhitespaceIfAny()`，减少分支重复。
2. 重写 `parseString` 主循环，保持语义不变并简化热路径分支。
3. 标准兼容修正：允许字符串中的原始 `0x7F`（DEL）字节。

文件：`tests/kaca_json/src/standard_parser_test.cj`
1. 新增 `jsonStringWithRawDelByteShouldPass`，固定 `0x7F` 标准行为。

## 正确性验证
- `cjpm test --no-color`：`31/31 PASSED`（新增测试后通过）。

## 性能观察（本轮）
- `ParserBenchLarge`
  - 一次测量：`fastParse` 中位数 `135012 ns`
  - 二次复测：`fastParse` 中位数 `153807 ns`
  - 结论：相对历史样本（约 `158730 ns`）有小幅改善趋势，但存在噪声，需继续复测确认。
- `PublicApiFastWrapperBench`
  - `apiParseToJson` 相对 `oldWrapperStyleParseToJson` 约 `-21.6%`。
  - 注意：该基线存在重复校验，不适合直接作为算法优劣最终依据。

## 决策
1. 保留本轮改动：
   - 通过全部测试；
   - 严格模式语义更完整（补齐 `0x7F`）；
   - 性能未见回归。
2. 下一轮优先项：
   - 继续围绕 `StrictJsonValidator::parseString/parseNumber` 做低风险微优化；
   - 对 `parseFast(...).toJsonValue()` 路径单独做对象写入热点（`HashMap add`）实验。

## 补充修复（同日）
在新增 `0x7F` 标准测试后，发现标准解析器路径（`JSON.parse`）也存在同类问题。

文件：`kaca_json/src/json/lexer.cj`
1. `scanString` ASCII 快路径从 `0x20..0x7E` 调整为 `0x20..0x7F`（通过 `< 0x80` 实现），避免将 `0x7F` 误判为 UTF-8 非法序列。

回归：
- `cjpm test --no-color`：`32/32 PASSED`。
- 基准（关键项）
  - `ParserBenchLarge.fastParse`：`157768 ns`（无回归）
  - `StrictParseStrategyBench.onePassStrictParse`：`76914 ns`
  - `PublicApiFastWrapperBench.apiParseToJson`：`50688 ns`

结论更新：
- 标准性修复与性能目标兼容，可保留。
- 下一轮继续围绕 `StrictJsonValidator` 热点做微优化；对 `PublicApiFastWrapperBench` 仍只作趋势参考，不作最终算法优劣判据。

## 继续推进（同日第二轮微优化）

### 目标
继续降低 `parseFast` 严格校验阶段开销，聚焦 `StrictJsonValidator` 热点。

### 先验采样（WSL cjprof）
`ParserBenchLarge.fastParse` 采样显示热点仍集中：
1. `StrictJsonValidator::parseValue`
2. `StrictJsonValidator::parseString`
3. `StrictJsonValidator::parseNumber`

### 本轮改动
文件：`kaca_json/src/json/strict_validator.cj`
1. `parseValue`：数字分支改为内联 ASCII 范围判断，减少函数调用。
2. `parseString`：恢复连续 ASCII 快扫循环（并保留 `0x7F` 合规）。
3. `parseNumber`：使用局部游标 `p` 扫描，减少对成员 `pos` 的频繁写入。

### 正确性
- `cjpm test --no-color`：`32/32 PASSED`。

### 性能（A/B）
- `ParserBenchLarge.fastParse`
  - run1: `128525 ns`
  - run2: `135687 ns`
  - 对比此前常见区间（约 `157k~177k ns`）有稳定改善。
- `PublicApiFastWrapperBench.apiParseToJson`
  - run1: `55884 ns`（ratio `-13.6%`）
  - run2: `50821 ns`（ratio `-17.1%`）

### 决策
- 保留本轮改动：无语义回归，且 `fastParse` 关键 case 有实测收益。
- 下一轮优先：
  1. 继续压缩 `parseValue` 分支开销（分支顺序与局部函数内联）；
  2. 评估 `parseStringEscape` 调用边界（只在 escape 稀疏场景下做微调，避免过度复杂化）。

## 继续推进（同日第三轮微实验）

### 改动
文件：`kaca_json/src/json/strict_validator.cj`
- 将 `parseValue` 的数字分支前置（在字符串/对象/数组分支之前），匹配当前基准数据中数字占比更高的分布。

### 验证
- `cjpm test --no-color`：`32/32 PASSED`。

### 性能
- `ParserBenchLarge.fastParse`
  - run1: `127824 ns`
  - 与上一轮（`128525 ns`、`135687 ns`）一致，维持改进区间。
- `PublicApiFastWrapperBench.apiParseToJson`
  - run1: `57191 ns`（ratio `-15.5%`）
  - 与上一轮（`-13.6%` 到 `-17.1%`）一致。

### 结论
- 该分支顺序调整可保留：无语义风险，且与前两轮结果一致保持收益。

## 继续推进（同日第四轮微优化）

### 改动
文件：`kaca_json/src/json/strict_validator.cj`
1. `parseString` 改为局部游标 `p` 扫描，并内联转义/`\u` 解析逻辑，减少成员 `pos` 的高频读写与函数调用。
2. `skipWhitespace` 改为局部游标扫描后一次性回写 `pos`。
3. `validateUtf8Char` 改为 `validateUtf8CharAt(p)`，配合局部游标使用。
4. 删除未使用函数：`parseStringEscape`、`parseUnicodeHex`（代码收敛）。

### 正确性
- `cjpm test --no-color`：`32/32 PASSED`。

### 性能
- `ParserBenchLarge.fastParse`：`140054 ns`（本轮回归后复测）
- 对比早前基线区间（`157k~177k ns`）仍保持改进。

### 结论
- 保留本轮改动：严格模式语义不变，代码更收敛，性能保持在优化后区间。

## 继续推进（同日第五轮：fast_parser 空白路径实验）

### 改动
文件：`kaca_json/src/json/fast_parser.cj`
- `parseFastArrayValueToJson` / `parseFastObjectValueToJson` 中多处“先判空白再调用 skip”改为统一调用 `skipWhitespaceFast(...)`，减少重复分支代码。

### 正确性
- `cjpm test --no-color`：`32/32 PASSED`。

### 性能观察（PublicApiFastWrapperBench）
- run1: ratio `-8.0%`
- run2: ratio `-22.7%`
- run3: ratio `-15.5%`
- 结论：结果有噪声，但整体仍在既有改进区间内，未显示系统性回归。

### cjprof（apiParseToJson）
热点结构基本不变：
1. `parseFastJsonValueNested`
2. `parseFastObjectValueToJson`
3. `StrictJsonValidator::parseValue`
4. `HashMap<String, JsonValue>::add`

### 决策
- 保留本轮改动（无语义回归，性能无确定性回退）。
- 下一轮优先转向 `HashMap add` 路径与对象写入策略实验。

## 继续推进（同日第六轮：NoSkip 快路径 + 回滚验证）

### 目标
减少 `fast_parser` 在数组/对象循环中的重复空白跳过开销；保持严格模式语义不变。

### 先验采样（WSL cjprof）
`PublicApiFastWrapperBench.apiParseToJson` 热点：
1. `parseFastJsonValueNested`
2. `parseFastObjectValueToJson`
3. `StrictJsonValidator::parseValue`
4. `HashMap<String, JsonValue>::add`

### 改动 A（保留）
文件：`kaca_json/src/json/fast_parser.cj`
1. 新增 `parseFastJsonValueNestedNoSkip(...)`，由 `parseFastJsonValueNested(...)` 先做一次 `skipWhitespaceFast` 后转入 NoSkip。
2. 新增 `parseFastValueNestedNoSkip(...)`，同理用于 `FastValue` 路径。
3. `parseFastArray/parseFastObject/parseFastArrayValueToJson/parseFastObjectValueToJson` 在已完成空白处理的循环位置改为调用对应 `NoSkip` 版本。

说明：该改动仅减少重复空白判定，不改变词法与语义分支。

### 改动 B（已回滚）
文件：`kaca_json/src/json/strict_validator.cj`
- 实验将 `skipWhitespaceIfAny()` 全部替换为 `skipWhitespace()`，以减少一层调用。
- 结果在 `ParserBenchLarge.fastParse` 上出现明显回退（约 `143667 ns`、`150302 ns`），故已完整回滚，不进入主线。

### 正确性
- `cjpm test --no-color`：`32/32 PASSED`。

### 性能（A/B）
说明：出现一次并行 bench 导致 `.test-logs` 清理冲突，该样本按无效处理，后续全部串行重跑。

1) 改动 A 后（稳定串行样本）
- `ParserBenchLarge.fastParse`：`120100 ns`、`114897 ns`
- `PublicApiFastWrapperBench.apiParseToJson`：`47790 ns`、`48508 ns`

2) 回滚改动 B 后复测（主线当前）
- `ParserBenchLarge.fastParse`：`121240 ns`（另一次 `125107 ns`）
- `PublicApiFastWrapperBench.apiParseToJson`：`55139 ns`、`56720 ns`

### cjprof（改动 A 后）
`apiParseToJson` 热点名称迁移为：
1. `parseFastJsonValueNestedNoSkip`
2. `parseFastObjectValueToJson`
3. `StrictJsonValidator::parseValue`
4. `HashMap<String, JsonValue>::add`

### 决策
- 保留改动 A（NoSkip 快路径）。
- 回滚改动 B（`strict_validator` 空白调用收敛实验）。
- 下一轮优先：
  1. 在 `parseFastObjectValueToJson` 继续做对象键值写入微优化（重点围绕 `HashMap::add` 热点）。
  2. 仅在不引入额外分配/分支成本前提下评估“共享 vs 隔离”实现策略。

## 架构收敛（同日）：删除劣势解析器，仅保留 fast 严格算法

### 目标
按项目维护目标，删除性能劣势且重复维护成本高的 `Lexer + Parser` 标准解析实现，统一到单一严格解析算法。

### 执行
1. `kaca_json/src/json/json_parser.cj` 改为薄入口：
   - `parseStrict(input)` -> `parseFastBytes(unsafe { input.rawData() }).toJsonValue()`
   - `parseStrictBytes(input)` -> `parseFastBytes(input).toJsonValue()`
2. 删除旧算法文件：
   - `kaca_json/src/json/lexer.cj`
   - `kaca_json/src/json/token.cj`
3. 保留公共 API 兼容：`parse/parseStrict/parseStrictBytes/parseOrNull` 签名不变。

### 正确性
- `cjpm test --no-color`：`32/32 PASSED`。

### 性能与一致性验证
在统一后，`PublicApiStrictParseBench.directStandardParse` 与 `PublicApiFastWrapperBench.apiParseToJson` 已指向同一算法族，性能接近并维持快路径区间：
- `directStandardParse`: `48183 ns`
- `apiParseToJson`: `49128 ns`

### 决策
- 保留：单算法（fast 严格）方案。
- 删除：旧 `Lexer + Parser` 路径，减少重复实现与后续维护面。

## 架构优化（同日）：parseFastBytes 合并两遍为一遍严格解析

### 背景
此前 `parseFastBytes` 先执行 `StrictJsonValidator.validate()` 再进入 fast 解析，存在两遍扫描。

### 改动
文件：`kaca_json/src/json/fast_parser.cj`
1. 删除 `parseFastBytes` 对 `StrictJsonValidator` 的前置调用。
2. 新增一遍严格入口 `parseFastTopLevelStrict(...)`：在同一遍中完成
   - 严格语法校验
   - 顶层 `FastValue` 构造
   - 尾随 token 检查（仅允许尾随空白）
3. 增加严格子解析函数（对象/数组/字符串/数字/UTF-8 校验）用于嵌套递归：
   - `parseFastValueStrictTop`
   - `parseValueStrictFastNoSkip`
   - `parseObjectStrictFast`
   - `parseArrayStrictFast`
   - `parseStringStrictFast`
   - `parseNumberStrictFast`
   - `validateUtf8CharAtFast`
4. 清理本轮冗余：删除未使用的 `trimRightWhitespaceFast`。

### 正确性
- `cjpm test --no-color`：`32/32 PASSED`。

### 性能抽样
- `ParserBenchLarge.fastParse`: `118963 ns`
- `PublicApiFastWrapperBench.apiParseToJson`: `49210 ns`

### 结论
- `parseFastBytes` 已从“两遍（先校验再解析）”收敛为“一遍（校验+解析合并）”。
- 严格模式测试保持通过。

## 架构优化（同日）：parseStrictBytes 改为单遍直出 JsonValue

### 目标
`parseStrictBytes` 不再走 `parseFastBytes(...).toJsonValue()` 二次展开路径，改为单遍严格解析并直接构建 `JsonValue`。

### 设计落地
文件：`kaca_json/src/json/fast_parser.cj`
1. 新增 `parseStrictJsonBytes(bytes)` 公共入口。
2. 新增 `parseJsonTopLevelStrict(...)` + `parseJsonValueStrictNoSkip(...)`，在一遍中完成：
   - 严格语法校验
   - 直接构建 `JsonValue`
   - 顶层尾随 token 校验
3. 新增对象/数组严格构建函数：
   - `parseObjectValueStrictFast(...)`
   - `parseArrayValueStrictFast(...)`
4. 新增字符串严格解码函数：
   - `parseStringValueStrictFast(...)`
   在严格校验同时直接生成 `String`，避免先 `FastValue` 后再 `toJsonValue` 的二次遍历。

文件：`kaca_json/src/json/json_parser.cj`
- `parse(input: String)` 与 `parseStrictBytes(input: Array<Byte>)` 改为调用 `parseStrictJsonBytes(...)`。

### 中间修正
- 首版 `parseStringValueStrictFast` 存在无条件大容量 `ByteBuilder` 分配，导致 `directStandardParse` 明显回退。
- 已修正为：仅在出现转义时启用 builder（无转义字符串保持 raw-slice 快路径）。

### 正确性
- `cjpm test --no-color`：`32/32 PASSED`。

### 性能抽样（串行）
- `PublicApiStrictParseBench.directStandardParse`：`74181 ns`（另一次 `64460 ns`）
- `PublicApiFastWrapperBench.apiParseToJson`：`61206 ns`（另两次 `52010 ns`、`48538 ns`）

### 结论
- `parseStrictBytes` 已从“近两遍（`parseFastBytes` + `toJsonValue`）”收敛到“单遍直出 `JsonValue`”。
- 严格标准行为保持通过，性能维持在既有优化区间（存在正常基准噪声）。
