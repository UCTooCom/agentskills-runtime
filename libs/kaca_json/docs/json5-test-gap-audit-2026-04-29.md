# JSON5 测试遗漏审查（对照官方 json5）
日期：2026-04-29
对照源：`C:\Users\27482\Desktop\json5\test\parse.js`、`C:\Users\27482\Desktop\json5\test\errors.js`

## 结论
当前 `kaca_json` 的 JSON5 测试已按测试驱动补齐一批官方核心子集。
本轮补充后，`Json5OfficialSubsetTests` 从 7 个用例扩展到 9 个用例，并且全量测试通过（`43/43`）。

## 本轮新增覆盖
- 数值解析：
  - 裸十六进制：`0x1`
  - 指数前导零：`1e01`
  - 小数规范化：`1.0`
  - 长负十六进制：`-0x0123456789abcdefABCDEF`
- 结构解析：
  - 嵌套对象 `{a:{b:2}}`
  - 数组多元素 `[1,2]`
- 字符串：
  - 引号混合 `['"',"'"]`
- 错误子集：
  - `0x`（无十六进制数字）
  - `{a:1`（对象未闭合）
  - 原始控制字符输入
  - `"\\u000g"`（非法 Unicode 转义）

## 实现修复（由测试驱动触发）
- 文件：`kaca_json/src/json/number_parser.cj`
- 修复点：JSON5 十六进制数解析不再用 `Int64` 累积，改为 `Float64` 直接累积，避免长十六进制溢出。
- 同时增加：
  - 至少一个十六进制数字校验
  - 后缀字符校验

## 当前仍未覆盖/暂不覆盖
- 官方 `parse(text, reviver)` 相关测试尚未纳入。
- 原因：当前 `kaca_json` 对外 API 不支持 reviver 参数，这是能力边界，不是遗漏。
- 错误信息细节（message/line/column）尚未与官方逐项精确对齐断言，目前以“成功/失败语义”与关键行为为主。

## 建议下一步
1. 继续从 `errors.js` 迁移更细粒度的定位断言（line/column），提升标准一致性信心。
2. 若后续计划支持 reviver，再引入官方 `parse(text, reviver)` 对应测试组。
3. 新增用例时同步维护 `kaca_json/docs/json5-official-source-mapping-2026-04-29.md`，保持来源可追溯。
