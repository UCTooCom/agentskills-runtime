# JSON5 官方用例映射表（kaca_json）
日期：2026-04-29
目标：将 `tests/kaca_json/src/json5_official_subset_test.cj` 的断言与官方 `json5` 测试来源建立可追溯映射。

来源仓库：`C:\Users\27482\Desktop\json5`
- `test/parse.js`
- `test/errors.js`

## 映射规则
1. 优先映射到官方断言文案所在行（`parse.js` / `errors.js`）。
2. 一个本地测试组可对应多个官方断言。
3. 本表仅覆盖当前已实现的官方子集。

## 映射清单
| 本地测试组 | 本地文件 | 官方来源定位 |
|---|---|---|
| `officialValidSubsetShouldParse` | `json5_official_subset_test.cj` | `parse.js:12`(empty objects), `30`(unquoted property names), `143`(signed numbers), `167`(hex), `173`(Infinity), `262`(single-line comments), `274`(multi-line comments), `284`(whitespace) |
| `officialInvalidSubsetShouldFail` | `json5_official_subset_test.cj` | `errors.js:15`(empty), `25`(comments-only), `35`(incomplete line comment), `45`(unterminated block comment), `65`(invalid value char), `317`(unclosed object), `367`(unclosed array) |
| `officialNaNBehaviorShouldHold` | `json5_official_subset_test.cj` | `parse.js:177`(NaN), `183`(signed NaN) |
| `officialObjectKeyAdvancedCases` | `json5_official_subset_test.cj` | `parse.js:36`(special property names), `42`(unicode property names), `48`(escaped property names), `55`(`__proto__`) |
| `officialStringEscapeCases` | `json5_official_subset_test.cj` | `parse.js:234`(escaped characters), `237`(line/paragraph separators) |
| `officialErrorSubsetFromErrorsJs` | `json5_official_subset_test.cj` | `errors.js:75`(identifier start escape), `85`(identifier start char), `95`(identifier continue escape), `105`(identifier continue char), `155`(hex indicator), `165`(newline in string), `245`/`255`(hex escape digits), `265`(unicode escape), `276`(escaped digits), `287`(octal) |
| `officialAdditionalParseCases` | `json5_official_subset_test.cj` | `parse.js:55`(`__proto__`), `193`(`+1.23e100`), `207`(long hex), `268`(line comment at EOF), `237`(U+2028/U+2029) |
| `officialRemainingParseCoverage` | `json5_official_subset_test.cj` | `parse.js:201`(bare hex), `207`(bare long hex), `193`(plus exponent), `143`(signed numbers), `12`/`30`(object/keys), `234`(quotes/escapes family) |
| `officialRemainingErrorCoverage` | `json5_official_subset_test.cj` | `errors.js:155`(`0xg` family), `297`(multiple values family), `317`/`367`(unclosed structures), `265`(invalid unicode escape) |

## 维护说明
1. 当本地新增 JSON5 用例时，必须在本表追加来源定位。
2. 若官方 `json5` 更新导致行号变化，先更新本表，再更新测试。
3. 本表与 `kaca_json/docs/json5-test-gap-audit-2026-04-29.md` 配套使用：
   - `gap-audit` 记录“还缺什么”；
   - 本表记录“已有用例来自哪里”。
