# JSON5 性能优化审查（2026-04-29）

## 本轮变更
1. 为 JSON5 增加独立基准：`Json5ParserBenchMedium.json5Parse`（`tests/kaca_json/src/main_test.cj`）。
2. 移除 JSON5 热路径中的字面量临时分配：
- `json5_parser.cj` 中 `true/false/null/Infinity/NaN` 匹配由 `stringToBytes` 改为固定字节比较。
- `json_number_parser.cj` 中 `Infinity/NaN` 匹配由 `stringToBytes` 改为固定字节比较。

## 正确性
- `cjpm test --no-color --filter Json5OfficialSubsetTests`：通过。
- `cjpm test --no-color`：43/43 全通过。

## 性能观测（WSL）
环境：WSL + `source /opt/cangjie-1.1.0/cangjie/envsetup.sh`

`cjpm bench --filter Json5ParserBenchMedium` 多次观测（中位数）：
- 103157 ns（改动前历史样本）
- 80625 ns
- 77148 ns
- 120514 ns
- 91254 ns
- 99753 ns

结论：有改善迹象，但噪声仍明显（抖动较大），需要更稳定的重复采样脚本收敛中位数。

## cjprof 热点（WSL）
采样入口：`Json5ParserBenchMedium.json5Parse`

主要热点（抽样）：
1. `Json5Parser::parseValue`
2. `Json5Parser::skipWhitespaceAndComments`
3. `Json5Parser::parseStringValue`
4. `Json5Parser::parseNumberValue`
5. `parseJson5NumberBytesRange`
6. `HashMap::add`
7. `String::init`

说明：当前热点已主要集中在解析核心和容器写入，不再是字面量匹配字符串构造。

## 剩余优化空间（按优先级）
1. 数字解析单次遍历化（高优先级）
- 现状：`parseNumberValue` 先扫描边界，再调用 `parseJson5NumberBytesRange` 再解析一次。
- 方向：在 `Json5Parser` 内直接完成数字语义解析，减少二次解析和函数往返。

2. 空白/注释跳过的 ASCII 快路径（中高优先级）
- 现状：`skipWhitespaceAndComments` 仍有较高自耗时。
- 方向：将常见 ASCII 空白与非注释字符快速判定，减少分支和函数调用。

3. 字符串路径继续分层（中优先级）
- 现状：已具备 no-escape 快路径，但 `parseStringValue` 仍占比较高。
- 方向：进一步优化纯 ASCII 连续段处理，减少 `utf8DecodeByte` 调用次数。

## 本轮决策
- 保留本轮修改（低风险、无行为回归、热点结构更健康）。
- 下一轮优先做“数字解析单次遍历化”，再复测 JSON5 基准和 `cjprof` 热点。

## 追加轮次：数字单次遍历化（同日）
### 变更
1. `json5_parser.cj` 的 `parseNumberValue` 改为单次遍历直接求值：
- 删除 `scanNumberFastShared + parseJson5NumberBytesRange` 两段式流程。
- 在扫描过程中直接处理：符号、`Infinity/NaN`、十六进制、小数、指数。
2. `parseKeywordValue` 中 `Infinity/NaN` 改为直接返回常量，去掉额外数值解析调用。

### 正确性
- `cjpm test --no-color --filter Json5OfficialSubsetTests`：通过。
- `cjpm test --no-color`：43/43 全通过。

### 性能与热点
- WSL 基准一轮：`json5Parse` 中位数 `81510 ns`。
- WSL `cjprof` 抽样热点中，`parseJson5NumberBytesRange` 已不再进入主要热点列表。
- 当前主要热点仍为：`parseValue`、`skipWhitespaceAndComments`、`parseStringValue`、`parseNumberValue`、`HashMap::add`。

### 结论
- 该轮优化保留：功能无回归，且数值路径热区已收敛为单次解析。
- 下一轮建议优先优化 `skipWhitespaceAndComments` 的 ASCII 快路径。

## 追加轮次：字符串无转义快扫（参考 fast 思路）
### 变更
1. `json5_parser.cj` 的 `parseStringValue` 在无转义路径增加 ASCII 连续段快扫：
- 内层循环批量跳过 `0x20..0x7F` 且非引号/反斜杠字符。
- 保持原有转义与 Unicode 路径不变，仅优化常见无转义字符串扫描。

### 正确性
- `cjpm test --no-color --filter Json5OfficialSubsetTests`：通过。
- `cjpm test --no-color`：43/43 全通过。

### 性能观测（WSL）
`cjpm bench --filter Json5ParserBenchMedium` 中位数样本：
- 79274 ns
- 80928 ns

相对前一稳定样本（约 87712 ns）继续下降，收益明确。

### cjprof 热点（WSL）
- `Json5Parser::parseStringValue` 抽样占比约 `3.11%`。
- 主要热点继续集中在 `parseValue / skipWhitespaceAndComments / HashMap::add / parseNumberValue`。

### 决策
- 保留该改动。

## 追加轮次：空白/注释跳过内联化（参考 fast 思路）
### 变更
1. `json5_parser.cj` 的 `skipWhitespaceAndComments` 改为单函数内联扫描：
- 使用本地游标 `p/ln/col` 批量推进，循环结束后一次性回写状态。
- 内联处理：ASCII 空白、换行、`//` 注释、`/* */` 注释、Unicode 空白。
2. 删除仅被该热路径使用的包装函数：
- `consumeWhitespaceOrLineTerminator`
- `skipLineComment`
- `skipBlockComment`

### 正确性
- `cjpm test --no-color --filter Json5OfficialSubsetTests`：通过。
- `cjpm test --no-color`：43/43 全通过。

### 性能观测（WSL）
`cjpm bench --filter Json5ParserBenchMedium` 中位数样本：
- 80401 ns
- 76842 ns

相对上一轮（约 79us~81us）继续下降，尤其第二轮达到当前最低样本。

### cjprof 热点（WSL）
- `skipWhitespaceAndComments` 仍在热点中，但保持在低个位数占比（约 `4.67%`）。
- 当前主要热点仍以 `parseValue`、容器写入和字符串/数字解析为主。

### 决策
- 保留该改动。
