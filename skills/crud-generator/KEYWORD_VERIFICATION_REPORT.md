# 仓颉关键字列表对比分析报告

**分析日期**: 2026-03-21  
**目的**: 复核crud-generator中仓颉关键字列表的正确性和完备性

---

## 一、官方关键字列表（共70个）

根据仓颉语言官方文档（kernel/source_zh_cn/Appendix/keyword.md），仓颉语言的完整关键字列表如下：

| 关键字          | 关键字        | 关键字       |
|--------------|------------|-----------|
| as           | abstract   | break     |
| Bool         | case       | catch     |
| class        | const      | continue  |
| Rune         | do         | else      |
| enum         | extend     | for       |
| func         | false      | finally   |
| foreign      | Float16    | Float32   |
| Float64      | if         | in        |
| is           | init       | import    |
| interface    | Int8       | Int16     |
| Int32        | Int64      | IntNative |
| let          | mut        | main      |
| macro        | match      | Nothing   |
| open         | operator   | override  |
| prop         | public     | package   |
| private      | protected  | quote     |
| redef        | return     | spawn     |
| super        | static     | struct    |
| synchronized | try        | this      |
| true         | type       | throw     |
| This         | unsafe     | Unit      |
| UInt8        | UInt16     | UInt32    |
| UInt64       | UIntNative | var       |
| VArray       | where      | while     |

---

## 二、当前实现的关键字列表（共50+个）

### 当前列表
```javascript
const CJ_KEYWORDS = new Set([
    // 类型定义关键字
    'type', 'class', 'interface', 'enum', 'struct', 'unit',
    // 函数和变量关键字
    'func', 'var', 'let', 'const', 'prop', 'mut',
    // 访问控制关键字
    'public', 'private', 'protected', 'internal', 'open', 'sealed',
    // 继承和扩展关键字
    'extend', 'abstract', 'override', 'redef', 'super', 'this',
    // 控制流关键字
    'if', 'else', 'match', 'case', 'default', 'when',
    'for', 'while', 'do', 'break', 'continue', 'return',
    // 异常处理关键字
    'try', 'catch', 'throw', 'finally',
    // 包和导入关键字
    'import', 'package', 'from',
    // 布尔和空值关键字
    'true', 'false', 'null', 'None', 'Some',
    // 类型操作关键字
    'in', 'is', 'as', 'where',
    // 其他关键字
    'static', 'defer', 'spawn', 'sync', 'unsafe',
    // 查询关键字
    'select', 'from', 'order', 'by', 'asc', 'desc',
    // 常用但可能冲突的关键字
    'value', 'key', 'data', 'result', 'error', 'status'
])
```

---

## 三、对比分析

### 1. 缺失的官方关键字（需要添加）

**类型关键字**:
- ❌ `Bool` - 布尔类型
- ❌ `Rune` - 字符类型
- ❌ `Float16`, `Float32`, `Float64` - 浮点类型
- ❌ `Int8`, `Int16`, `Int32`, `Int64`, `IntNative` - 整数类型
- ❌ `UInt8`, `UInt16`, `UInt32`, `UInt64`, `UIntNative` - 无符号整数类型
- ❌ `Nothing` - Nothing类型
- ❌ `Unit` - Unit类型（当前有'unit'但大小写不对）
- ❌ `VArray` - 值数组类型
- ❌ `This` - This类型（当前有'this'但大小写不对）

**函数和初始化关键字**:
- ❌ `init` - 初始化函数
- ❌ `main` - 主函数
- ❌ `operator` - 操作符重载

**宏相关关键字**:
- ❌ `macro` - 宏定义
- ❌ `quote` - quote表达式

**并发相关关键字**:
- ❌ `synchronized` - 同步（当前有'sync'但不对）

**其他关键字**:
- ❌ `foreign` - 外部函数接口

**总计**: 缺失 **28个** 官方关键字

### 2. 多余的非官方关键字（需要移除或标记）

以下关键字不在官方列表中，可能是：
- 其他语言的关键字
- 常见但非保留的标识符

**需要移除**:
- ❌ `internal` - 不是仓颉关键字
- ❌ `sealed` - 不是仓颉关键字
- ❌ `default` - 不是仓颉关键字
- ❌ `when` - 不是仓颉关键字
- ❌ `from` - 不是仓颉关键字（import使用但不是关键字）
- ❌ `null` - 不是仓颉关键字（使用None代替）
- ❌ `None` - 不是关键字（是Option类型的一部分）
- ❌ `Some` - 不是关键字（是Option类型的一部分）
- ❌ `defer` - 不是仓颉关键字
- ❌ `sync` - 不是仓颉关键字（应该是synchronized）
- ❌ `select`, `order`, `by`, `asc`, `desc` - 不是仓颉关键字
- ❌ `value`, `key`, `data`, `result`, `error`, `status` - 不是关键字，是常见标识符

**总计**: 多余 **20个** 非官方关键字

### 3. 大小写错误的关键字

- ⚠️ `unit` → 应该是 `Unit`
- ⚠️ `this` → 应该是 `this`（正确，但缺少`This`）

---

## 四、改进建议

### 1. 更新为官方完整列表

```javascript
const CJ_KEYWORDS = new Set([
    // 官方关键字列表（按字母排序）
    'abstract', 'as', 'Bool', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'do', 'else', 'enum',
    'extend', 'false', 'finally', 'Float16', 'Float32', 'Float64',
    'for', 'foreign', 'func', 'if', 'import', 'in',
    'init', 'Int16', 'Int32', 'Int64', 'Int8', 'IntNative',
    'interface', 'is', 'let', 'macro', 'main', 'match',
    'mut', 'Nothing', 'open', 'operator', 'override', 'package',
    'private', 'prop', 'protected', 'public', 'quote', 'redef',
    'return', 'Rune', 'spawn', 'static', 'struct', 'super',
    'synchronized', 'this', 'This', 'throw', 'true', 'try',
    'type', 'UInt16', 'UInt32', 'UInt64', 'UInt8', 'UIntNative',
    'Unit', 'unsafe', 'var', 'VArray', 'where', 'while'
])
```

### 2. 添加额外检查

虽然以下不是保留关键字，但建议也避免使用：
- `None`, `Some` - Option类型的构造器
- `null` - 虽然不是关键字，但仓颉使用None
- 常见类型名如 `String`, `Array`, `ArrayList` 等

### 3. 分类整理

**类型关键字** (19个):
```
Bool, Rune, Float16, Float32, Float64,
Int8, Int16, Int32, Int64, IntNative,
UInt8, UInt16, UInt32, UInt64, UIntNative,
Nothing, Unit, VArray, This
```

**定义关键字** (11个):
```
class, interface, enum, struct, type,
func, init, main, operator, macro, prop
```

**访问控制关键字** (5个):
```
public, private, protected, open, static
```

**继承扩展关键字** (5个):
```
extend, abstract, override, redef, super
```

**控制流关键字** (11个):
```
if, else, match, case, for, while, do,
break, continue, return, where
```

**异常处理关键字** (4个):
```
try, catch, throw, finally
```

**包和导入关键字** (3个):
```
import, package, foreign
```

**其他关键字** (12个):
```
as, const, false, finally, in, is, let, mut,
quote, spawn, synchronized, unsafe, var, true
```

---

## 五、影响分析

### 1. 当前实现的问题

**问题1: 缺失关键字**
- 如果数据库列名是 `Bool`, `Int32`, `Float64` 等类型名，不会被检测为关键字
- 可能导致编译错误

**问题2: 多余关键字**
- `None`, `Some` 不是关键字，但被当作关键字处理
- `value`, `key`, `data` 等常见标识符被误判为关键字

**问题3: 大小写错误**
- `unit` vs `Unit` - 可能导致误判

### 2. 实际影响

**低风险**:
- 大多数数据库不会使用类型名作为列名（如 `Bool`, `Int32`）
- `None`, `Some` 被误判为关键字影响较小（避免使用也是好的）

**中等风险**:
- `value`, `key`, `data` 等常见列名被误判为关键字
- 可能导致不必要的字段重命名

**高风险**:
- 如果有列名是 `init`, `main`, `operator` 等，当前不会被检测
- 可能导致编译错误

---

## 六、改进优先级

### 高优先级（必须修复）
1. ✅ 添加所有缺失的官方关键字
2. ✅ 修正大小写错误（`unit` → `Unit`）
3. ✅ 移除明确的非关键字（`internal`, `sealed`, `defer` 等）

### 中优先级（建议修复）
1. ⚠️ 移除 `None`, `Some`（不是关键字）
2. ⚠️ 移除 `value`, `key`, `data` 等常见标识符

### 低优先级（可选）
1. 💡 添加额外检查列表（`String`, `Array` 等类型名）
2. 💡 提供配置选项允许用户自定义关键字列表

---

## 七、总结

### 当前状态
- ✅ 正确性: 部分正确（包含大部分常用关键字）
- ❌ 完备性: 不完备（缺失28个官方关键字）
- ⚠️ 准确性: 有误判（包含20个非官方关键字）

### 改进后状态（预期）
- ✅ 正确性: 完全正确（基于官方文档）
- ✅ 完备性: 完全完备（包含所有70个官方关键字）
- ✅ 准确性: 完全准确（移除所有非官方关键字）

### 建议
**立即更新**关键字列表为官方完整列表，确保：
1. 所有官方关键字都被检测
2. 不会误判非关键字
3. 与仓颉语言规范完全一致

---

**参考文档**: kernel/source_zh_cn/Appendix/keyword.md  
**官方关键字总数**: 70个  
**当前实现总数**: 50+个  
**需要添加**: 28个  
**需要移除**: 20个
