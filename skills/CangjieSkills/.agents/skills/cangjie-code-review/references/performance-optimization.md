# 仓颉性能优化

本页整理仓颉性能问题的测量方法、高性能编码方式和验证要点。性能结论以瓶颈证据、功能等价检查和相同环境下的复测结果为依据。

代码示例分为可独立编译的最小示例和依赖当前场景的替换片段。替换片段沿用同一场景中已声明的类型、导入、数据源和被测函数，业务接口需接入目标项目的真实实现并补充语义 DT。

## 1. 基线与可比性

先确定延迟、吞吐、CPU 时间、分配量或峰值内存中的一个主指标，并固定 SDK、机器、目标平台、构建配置、输入、并发度、预热和测量轮数。将数据准备、日志和无关的外部 I/O 移出被测逻辑，保存中位数和离散程度，不采用一次最快值。

优先使用仓颉基准框架：

```shell
cjpm bench
cjpm bench --filter "目标基准名称"
```

仓颉基准函数使用 `@Bench` 宏。需要给出可执行基准代码时，先查询 `cangjie-coding` 中的 `std.unittest` 文档或复用项目已有 `@Bench` 结构，数据准备应移出被测函数。

基准命令参数以当前 SDK 的 `cjpm bench --help` 为准。

优化前后使用相同的 SDK、机器、构建配置、输入、并发度、预热和测量方法。取得真实可比数据后，报告绝对值、中位数、离散程度以及按实测值计算的变化比例；没有基线时只给出优化假设和验证方案。

---

## 2. 算法复杂度与重复工作

### 2.1 嵌套扫描与输入规模

常见表现包括：双层循环扫描同一批数据，输入扩大后执行次数呈平方增长，CPU profile 指向比较或累加逻辑。

低效代码：

```cangjie
func duplicateScanSum(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (value in values) {
        for (candidate in values) {
            if (candidate == value) {
                total += candidate
            }
        }
    }
    return total
}
```

问题说明：旧实现会为每个外层元素再次累加所有相等项。直接改为一次求和会改变重复值语义；例如 `[1, 1, 2]` 的旧结果是 `6`，普通求和只有 `4`。

修正代码：

```cangjie
import std.collection.*

func frequencySum(values: Array<Int64>): Int64 {
    let counts = HashMap<Int64, Int64>()
    for (value in values) {
        match (counts.get(value)) {
            case Some(count) => counts.add(value, count + 1)
            case None => counts.add(value, 1)
        }
    }

    var total: Int64 = 0
    for ((value, count) in counts) {
        total += count * count * value
    }
    return total
}
```

#### 诊断与修复

1. 固定元素分布并测量至少两个输入规模，记录循环执行次数、最终结果、重复值和顺序要求；只看到循环嵌套还不足以证明可以换算法。

2. 用空输入、单元素、重复值、负数和大输入建立新旧等价 DT，再在相同 Profile 下运行 benchmark。

3. 键没有稳定的 `Hashable`/`Equatable` 语义、额外内存不符合约束或旧算法依赖访问顺序时，不直接使用频次表。

### 2.2 不变结果的重复计算

常见表现包括：外层循环中反复计算与循环变量无关的总和、解析结果或配置派生值，profile 显示同一函数被相同输入重复调用。

低效代码：

```cangjie
func sum(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (value in values) {
        total += value
    }
    return total
}

func addStableTotal(values: Array<Int64>, rounds: Int64): Int64 {
    var result: Int64 = 0
    for (_ in 0..rounds) {
        result += sum(values)
    }
    return result
}
```

问题说明：`values` 在函数执行期间不变，`sum(values)` 的结果也不变，却被执行 `rounds` 次。优化成立的前提是不变性真实存在，而不是只看函数名像“纯函数”。

修正代码：

```cangjie
func addStableTotal(values: Array<Int64>, rounds: Int64): Int64 {
    var total: Int64 = 0
    for (value in values) {
        total += value
    }

    var result: Int64 = 0
    for (_ in 0..rounds) {
        result += total
    }
    return result
}
```

#### 诊断与修复

1. 记录函数调用次数、参数摘要和输入修改位置，证明重复调用的输入与外部状态一致。

2. 将不变结果提升到最小安全作用域；DT 覆盖 `rounds` 为零、空数组、负数和溢出策略，确认计算顺序变化没有改变异常行为。

3. 函数读取时间、随机数、全局状态、I/O 或可变对象时，不把结果当作不变量提升。

### 2.3 全量扫描与可提前停止

常见表现包括：业务只需要“是否存在”，代码却统计全部匹配数量或构造完整结果，命中位置靠前时仍遍历所有元素。

低效代码：

```cangjie
func containsNegative(values: Array<Int64>): Bool {
    var count: Int64 = 0
    for (value in values) {
        if (value < 0) {
            count++
        }
    }
    return count > 0
}
```

问题说明：调用方只需要布尔结果。统计所有命中既增加工作量，也容易诱导后续代码依赖无用的计数。

修正代码：

```cangjie
func containsNegative(values: Array<Int64>): Bool {
    for (value in values) {
        if (value < 0) {
            return true
        }
    }
    return false
}
```

#### 诊断与修复

1. 确认调用契约只关心存在性，并记录匹配元素通常位于输入的前部、后部还是根本不存在。

2. 以无匹配、首元素匹配、末元素匹配和多个匹配建立 DT；使用相同数据分布比较全量扫描与提前停止。

3. 谓词具有必须执行的副作用、调用方需要精确数量或所有错误都必须被收集时，不提前结束遍历。

---

## 3. 集合与访问模式

### 3.1 成员查询与集合选型

常见表现包括：在 `Array`/`ArrayList` 热点循环中反复 `contains`，去重或集合关系操作随输入扩大明显变慢。

低效代码：

```cangjie
func countAllowed(values: Array<Int64>, allowed: Array<Int64>): Int64 {
    var count: Int64 = 0
    for (value in values) {
        if (allowed.contains(value)) {
            count++
        }
    }
    return count
}
```

问题说明：数组成员查询需要顺序扫描；当 `values` 很大且 `allowed` 被重复查询时，扫描成本会被放大。

修正代码：

```cangjie
import std.collection.*

func countAllowed(values: Array<Int64>, allowed: Array<Int64>): Int64 {
    let allowedSet = HashSet<Int64>(allowed)
    var count: Int64 = 0
    for (value in values) {
        if (allowedSet.contains(value)) {
            count++
        }
    }
    return count
}
```

#### 诊断与修复

1. 记录集合大小、查询次数、重复率、顺序要求以及键的相等性和哈希实现，不只凭 `contains` 的出现判断。

2. 在查询前构建一次 `HashSet`；DT 覆盖重复值、空集合、缺失项和顺序输出，再运行相同输入 benchmark。

3. 集合很小、只查询一次、哈希语义不稳定或额外内存不符合约束时，保留顺序集合。

### 3.2 容量增长与预分配

常见表现包括：已知输出规模却使用默认容量的 `ArrayList`/`HashMap`，profile 或容量记录显示构建阶段多次扩容和复制。

低效代码：

```cangjie
import std.collection.*

func copyPositive(values: Array<Int64>): ArrayList<Int64> {
    let result = ArrayList<Int64>()
    for (value in values) {
        if (value > 0) {
            result.add(value)
        }
    }
    return result
}
```

问题说明：默认容量适合规模未知的普通路径；当上界已知且结果经常较大时，反复扩容会重新分配并复制元素。

修正代码：

```cangjie
import std.collection.*

func copyPositive(values: Array<Int64>): ArrayList<Int64> {
    let result = ArrayList<Int64>(values.size)
    for (value in values) {
        if (value > 0) {
            result.add(value)
        }
    }
    return result
}
```

#### 诊断与修复

1. 记录最终 `size`、构建过程中的 `capacity` 和输入规模分布，确认扩容确实位于热点。

2. 只按可信上界预分配；DT 覆盖空输入、小输入和峰值输入，并同时观察延迟与分配量。

3. 上界远大于常见值、输入不可信或预分配会显著提高常驻内存时，不使用最大可能值作为容量。

### 3.3 顺序、去重与哈希迭代

常见表现包括：为去重反复线性扫描输出列表，或换成 `HashSet` 后结果顺序发生变化。

低效代码：

```cangjie
import std.collection.*

func distinctInOrder(values: Array<Int64>): ArrayList<Int64> {
    let result = ArrayList<Int64>()
    for (value in values) {
        if (!result.contains(value)) {
            result.add(value)
        }
    }
    return result
}
```

问题说明：只用 `HashSet(values).toArray()` 虽然能够去重，但哈希集合不保证业务顺序。需要同时维护“是否见过”和“首次出现顺序”。

修正代码：

```cangjie
import std.collection.*

func distinctInOrder(values: Array<Int64>): ArrayList<Int64> {
    let seen = HashSet<Int64>(values.size)
    let result = ArrayList<Int64>(values.size)
    for (value in values) {
        if (seen.add(value)) {
            result.add(value)
        }
    }
    return result
}
```

#### 诊断与修复

1. 明确输出是否要求首次出现顺序、排序、稳定性或仅集合相等，记录重复率和键语义。

2. 使用 `HashSet` 负责查询、`ArrayList` 负责顺序；DT 覆盖重复值、相等键、全重复和无重复输入。

3. 输出顺序本来未定义、数据量很小或键不适合哈希时，不引入双集合结构。

---

## 4. 字符串与 Unicode

### 4.1 循环字符串拼接

常见表现包括：热点循环中反复使用 `result = result + part`、大量字符串插值，profile 或分段计时显示格式化和复制占主要时间。

低效代码：

```cangjie
func joinParts(parts: Array<String>): String {
    var result = ""
    for (part in parts) {
        result = result + part
    }
    return result
}
```

问题说明：`String` 不可变，连续 `+` 会产生中间字符串；小规模一次性拼接仍应优先保持可读性。

修正代码：

```cangjie
func joinParts(parts: Array<String>): String {
    let builder = StringBuilder()
    for (part in parts) {
        builder.append(part)
    }
    return builder.toString()
}
```

#### 诊断与修复

1. 固定字符串数量和长度，分别测量原写法与 `StringBuilder`，同时检查最终内容、顺序、分隔符和 Unicode 结果。

2. 只有循环或热点中存在重复临时量时才替换；DT 覆盖空数组、单元素、多元素、空字符串和非 ASCII 文本。

3. 热点不在字符串构造，或者 I/O 和日志占据主要时间时，不把 `StringBuilder` 当作通用修复。

### 4.2 Byte、Rune 与重复转换

常见表现包括：热点循环反复把同一 `String` 转为 Rune/字节数组，或把 UTF-8 字节数量误当字符数量后进行多余修补。

低效代码：

```cangjie
func repeatRuneCount(text: String, rounds: Int64): Int64 {
    var total: Int64 = 0
    for (_ in 0..rounds) {
        total += text.toRuneArray().size
    }
    return total
}
```

问题说明：`String.toRuneArray()` 每次都会生成完整数组；直接迭代 `String` 得到的是 UTF-8 字节，不是字符。优化时不能用 `text.size` 替换 Rune 数量。

修正代码：

```cangjie
func repeatRuneCount(text: String, rounds: Int64): Int64 {
    var runeCount: Int64 = 0
    for (_ in text.runes()) {
        runeCount++
    }
    return runeCount * rounds
}
```

#### 诊断与修复

1. 使用 ASCII、中文、组合字符和空文本记录转换次数与结果，先证明转换位于主路径。

2. 在输入不变的最小作用域内复用计数或转换结果；DT 比较 Rune 顺序、字节序列和非法编码处理。

3. 输入每轮变化、流式解码状态不能复用或调用方需要独立可变副本时，不缓存完整转换结果。

### 4.3 split、lazySplit 与提前消费

常见表现包括：字符串较长或字段很多，并且只需要前几个字段、匹配后即可停止，却用 `split` 构造全部子字符串数组；此时无用字段的扫描与分配可能进入热点。仅仅“字符串较长”并不足以选择 `lazySplit`，还应确认调用方只消费部分结果或能够提前退出。

低效代码：

```cangjie
func firstField(line: String): Option<String> {
    let fields = line.split(",")
    if (fields.size == 0) {
        return None
    }
    return Some(fields[0])
}
```

问题说明：`split` 会物化完整 `Array<String>`。长字符串只消费少量字段时，可以使用惰性迭代，减少未访问字段的结果构造，同时保持返回值、空字段和 `removeEmpty` 语义一致。

空字符串的 `split` 和 `lazySplit` 都没有元素，因此使用 `Option<String>` 显式表达“没有首字段”。`lazySplit` 仍有迭代器开销，更适合只消费部分字段的长输入；短字符串、完整遍历、随机访问或多次遍历应通过基准选择实现。

修正代码：

```cangjie
func firstField(line: String): Option<String> {
    return line.lazySplit(",").next()
}
```

#### 选择边界

| 需求 | 优先选择 | 原因 |
|---|---|---|
| 长字符串只消费前几个字段，或匹配后立即停止 | `lazySplit` | 避免物化尚未访问的全部结果 |
| 只需要固定数量字段，并且仍需数组或随机访问 | `split(str, maxSplits)` | 有界分割后直接得到数组；例如 `split(",", 2)` 最多返回两个字符串，第二个保留剩余文本 |
| 最终遍历全部字段、长期保存结果或多次遍历 | `split` | 避免一次性迭代器开销，保留稳定集合语义 |
| 按文本行处理 | `lines()` | 同时识别 `\n`、`\r` 和 `\r\n`，语义比 `lazySplit("\n")` 完整 |
| 文件本身无法完整放入内存 | 分块或按行读取 | `lazySplit` 的输入仍是已完整创建的 `String`，不是真正的流式文件解析 |

#### 语义边界

1. 空字符串会得到空迭代器；调用方应通过 `Option`、默认值或明确异常定义无字段契约，不能在修复性能时顺带改变行为。

2. `removeEmpty: true` 会删除首部、尾部和连续分隔符产生的空字段，从而改变字段位置；它是业务语义选项，不是单纯的性能开关。

3. 空分隔符会按字符分割，中文等非 ASCII 文本也会产生逐字符结果；多字符分隔符、开头或结尾分隔符需要单独验证。

4. 性能取决于退出位置而不只是返回数量。目标字段、匹配项或首个分隔符靠近文本末尾时，`lazySplit` 仍可能扫描大部分输入。

5. `lazySplit` 只推迟分割并减少未消费结果的物化，不代表零分配，也不能降低已经创建完整输入 `String` 的内存占用。

#### 可比基准示例

下面的基准固定同一输入，分别消费 `split` 和 `lazySplit` 的第一个结果；数据准备位于被测函数之外。

```cangjie
@Test
class SplitVsLazySplit {
    let prefix: String = String(Array(8, repeat: r'x'))
    let suffix: String = String(Array(1000, repeat: r'y'))
    let input: String = prefix + "," + suffix

    @Bench
    func benchSplit() {
        let fields = input.split(",")
        if (fields.size > 0) {
            let _ = fields[0]
        }
    }

    @Bench
    func benchLazySplit() {
        let _ = input.lazySplit(",").next()
    }
}
```

在目标项目的测试文件中沿用现有 `package` 声明，通过 `cjpm bench` 执行。短输入、长输入、前部退出、末尾退出和完整遍历应分别建立基准，结果解释以同一轮实测数据为准。

#### 诊断与修复

1. 记录文本长度、字段数量、分隔符密度、实际消费数量和退出位置，确认输入足够大，并且主路径确实只扫描前部或存在稳定的提前退出条件。

2. 在 `lazySplit`、有界 `split(str, maxSplits)` 和普通 `split` 中选择与消费方式匹配的 API；不要收集完整迭代结果后仍宣称获得惰性收益。

3. DT 覆盖空文本、首尾空字段、连续分隔符、`removeEmpty`、空或多字符分隔符、非 ASCII 字段、无分隔符及 `maxSplits` 的 0、1、2、负数和超大取值。

4. 性能验证在同一构建模式下预热后，至少比较短/长输入、前部/末尾退出和完整遍历，并同时校验结果一致；短字符串或完整遍历不快时保留 `split`。

---

## 5. 分配、复制与对象生命周期

### 5.1 中间集合与循环融合

常见表现包括：过滤、映射和收集被拆成多轮遍历，每一步创建一个临时 `ArrayList`，profile 指向分配和复制。

低效代码：

```cangjie
import std.collection.*

func doublePositive(values: Array<Int64>): ArrayList<Int64> {
    let positives = ArrayList<Int64>()
    for (value in values) {
        if (value > 0) {
            positives.add(value)
        }
    }

    let result = ArrayList<Int64>()
    for (value in positives) {
        result.add(value * 2)
    }
    return result
}
```

问题说明：`positives` 只服务于下一轮转换，既增加一次遍历，也延长中间元素生命周期。

修正代码：

```cangjie
import std.collection.*

func doublePositive(values: Array<Int64>): ArrayList<Int64> {
    let result = ArrayList<Int64>(values.size)
    for (value in values) {
        if (value > 0) {
            result.add(value * 2)
        }
    }
    return result
}
```

#### 诊断与修复

1. 记录每个中间集合的创建次数、元素数量、逃逸位置和分配量，确认它没有独立业务含义。

2. 融合相邻且无副作用的遍历；DT 验证过滤顺序、异常顺序、重复值和空输入，再比较分配量与延迟。

3. 中间结果被复用、需要独立调试观察或每一步存在必须保持的副作用时，不强行融合。

### 5.2 clone、toArray 与所有权

常见表现包括：热点循环内重复 `clone()`、数组/列表互转，或者为只读调用复制完整容器。

低效代码：

```cangjie
import std.collection.*

func repeatedRead(values: ArrayList<Int64>, rounds: Int64): Int64 {
    var total: Int64 = 0
    for (_ in 0..rounds) {
        let snapshot = values.clone()
        for (value in snapshot) {
            total += value
        }
    }
    return total
}
```

问题说明：函数只读访问数据，循环内快照没有提供额外隔离，却复制了整个容器。删除复制前必须证明调用期间不会并发修改。

修正代码：

```cangjie
import std.collection.*

func repeatedRead(values: ArrayList<Int64>, rounds: Int64): Int64 {
    var total: Int64 = 0
    for (_ in 0..rounds) {
        for (value in values) {
            total += value
        }
    }
    return total
}
```

#### 诊断与修复

1. 记录复制次数、元素数量、修改位置和并发访问范围，确认调用方是否真的需要独立所有权。

2. 将不变快照移出循环，或在只读契约明确时直接遍历；DT 覆盖源集合被修改时的原有隔离语义。

3. 并发隔离、快照一致性或后续修改依赖独立副本时，不删除复制。

### 5.3 缓冲复用与容量高水位

常见表现包括：复用 `ArrayList`/`ByteBuffer` 后旧数据串入下一轮、异常路径未清空，或一次峰值使容量长期保持很大。

低效代码：

```cangjie
import std.collection.*

let sharedBuffer = ArrayList<UInt8>()

func loadBytes(input: Array<UInt8>): ArrayList<UInt8> {
    for (value in input) {
        sharedBuffer.add(value)
    }
    return sharedBuffer
}
```

问题说明：全局可变缓冲会把多次调用的数据和生命周期连接起来，也会让一次峰值容量长期保留；跨线程使用还会产生竞态。

修正代码：

```cangjie
import std.collection.*

func loadBytes(input: Array<UInt8>): ArrayList<UInt8> {
    let buffer = ArrayList<UInt8>(input.size)
    for (value in input) {
        buffer.add(value)
    }
    return buffer
}
```

#### 诊断与修复

1. 同时记录 `size`、`capacity`、每轮分配量、峰值输入和异常路径，区分逻辑清空与物理容量保留。

2. 默认保持局部所有权；只有容量上限明确、对象不逃逸且每轮可靠清空时才引入复用，DT 覆盖大小输入交替和并发访问。

3. 无分配热点、峰值不可控或复用会引入共享可变状态时，不使用对象池或全局缓冲。

---

## 6. 函数、Lambda 与热路径抽象

### 6.1 循环内创建 Lambda

常见表现包括：热点循环每次创建相同 Lambda 或嵌套函数，profile 显示大量短生命周期闭包和间接调用。

低效代码：

```cangjie
func transform(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (value in values) {
        let double = { item: Int64 => item * 2 }
        total += double(value)
    }
    return total
}
```

问题说明：Lambda 不捕获循环状态且逻辑稳定，没必要在每轮构造函数值。是否构成热点仍应由分配或 CPU 证据确认。

修正代码：

```cangjie
func doubleValue(value: Int64): Int64 {
    return value * 2
}

func transform(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (value in values) {
        total += doubleValue(value)
    }
    return total
}
```

#### 诊断与修复

1. 记录 Lambda 创建次数、捕获集合、调用次数和热点占比，不因存在 Lambda 就判定需要重写。

2. 将无捕获且稳定的逻辑提升为函数或在循环外构造；DT 比较返回值、异常和求值顺序。

3. Lambda 只创建一次、可读性收益明显或编译器已经消除开销且 profile 无热点时，保留抽象。

### 6.2 闭包捕获与逃逸范围

常见表现包括：长期保存的回调捕获大型上下文对象，或只需要一个字段却延长整个对象图的生命周期。

低效代码：

```cangjie
class RequestContext {
    let threshold: Int64
    let payload: Array<UInt8>

    init(threshold: Int64, payload: Array<UInt8>) {
        this.threshold = threshold
        this.payload = payload
    }
}

func makePredicate(context: RequestContext): (Int64) -> Bool {
    return { value: Int64 => value > context.threshold }
}
```

问题说明：返回的闭包只使用 `threshold`，却捕获 `context` 引用，使 `payload` 也可能随闭包继续存活。

修正代码：

```cangjie
func makePredicate(context: RequestContext): (Int64) -> Bool {
    let threshold = context.threshold
    return { value: Int64 => value > threshold }
}
```

#### 诊断与修复

1. 通过堆引用或生命周期证据确认闭包实际逃逸，并列出捕获变量及其对象图；源码形态只用于提出待验证假设。

2. 只捕获必要的不可变标量或轻量值；DT 验证上下文修改后的旧契约、回调结果和并发可见性。

3. 回调必须观察上下文的后续变化或复制字段本身成本更高时，不缩小为快照语义。

### 6.3 预期缺省值与异常热路径

常见表现包括：大量正常的缓存未命中或可选查询通过抛出、捕获 `NoneValueException` 完成控制流。

低效代码：

```cangjie
import std.collection.*

func findOrZero(values: HashMap<String, Int64>, key: String): Int64 {
    try {
        return values[key]
    } catch (_: NoneValueException) {
        return 0
    }
}
```

问题说明：缺失键是可预期状态，`HashMap.get` 已用 `Option` 表达；异常路径还会混淆真正的异常诊断。

修正代码：

```cangjie
import std.collection.*

func findOrZero(values: HashMap<String, Int64>, key: String): Int64 {
    match (values.get(key)) {
        case Some(value) => value
        case None => 0
    }
}
```

#### 诊断与修复

1. 记录未命中比例和异常类型，确认它是正常业务分支，而不是上游数据损坏。

2. 使用 `Option`/`match` 表达预期缺省；DT 覆盖命中、未命中和真正异常，比较语义后再测量。

3. API 契约明确要求缺失即失败，或异常极少且不在热点时，不为性能擅自改变错误语义。

---

## 7. 缓存与预计算

### 7.1 请求内记忆化

常见表现包括：同一次请求内对相同参数重复执行昂贵纯计算，调用次数远高于不同参数数量。

低效代码：

```cangjie
func fibonacci(value: Int64): Int64 {
    if (value < 2) {
        return value
    }
    return fibonacci(value - 1) + fibonacci(value - 2)
}
```

问题说明：递归树会重复计算相同输入。局部缓存可以把生命周期限制在一次调用内，避免引入全局无界状态。

修正代码：

```cangjie
import std.collection.*

func fibonacci(value: Int64): Int64 {
    let memo = HashMap<Int64, Int64>()
    func calculate(current: Int64): Int64 {
        match (memo.get(current)) {
            case Some(result) => return result
            case None => ()
        }
        let result = if (current < 2) {
            current
        } else {
            calculate(current - 1) + calculate(current - 2)
        }
        memo.add(current, result)
        return result
    }
    return calculate(value)
}
```

#### 诊断与修复

1. 记录总调用次数、不同键数量、单次成本和键稳定性，证明重复工作足以抵消缓存查找成本。

2. 优先使用请求内或批次内缓存；DT 覆盖边界值、重复键、溢出策略和异常，并测量命中与未命中负载。

3. 函数有副作用、结果依赖外部状态、键空间接近调用次数或单次计算很便宜时，不添加缓存。

### 7.2 缓存失效与版本语义

常见表现包括：缓存命中率看似很高，但配置或源数据变化后仍返回旧结果；性能修复造成正确性回归。

低效代码：

```cangjie
import std.collection.*

let prices = HashMap<String, Int64>()

func priceWithRate(name: String, base: Int64, rate: Int64): Int64 {
    match (prices.get(name)) {
        case Some(value) => value
        case None =>
            let value = base * rate
            prices.add(name, value)
            value
    }
}
```

问题说明：缓存键只有 `name`，但结果还依赖 `base` 和 `rate`。命中旧条目会返回错误结果，不能把高命中率当成成功。

修正代码：

```cangjie
import std.collection.*
import std.deriving.*

@Derive[Hashable, Equatable]
class PriceKey {
    PriceKey(let name: String, let base: Int64, let rate: Int64) {}
}

let prices = HashMap<PriceKey, Int64>()

func priceWithRate(name: String, base: Int64, rate: Int64): Int64 {
    let key = PriceKey(name, base, rate)
    match (prices.get(key)) {
        case Some(value) => value
        case None =>
            let value = base * rate
            prices.add(key, value)
            value
    }
}
```

#### 诊断与修复

1. 列出结果依赖的全部输入、版本和租户边界，使用变更前后相同业务键验证是否出现陈旧结果。

2. 将必要版本纳入键，或在状态变更时显式失效；DT 覆盖配置更新、同名不同输入和异常路径。

3. 无法定义可靠失效条件、键会包含敏感数据或缓存正确性无法验证时，不跨请求缓存。

### 7.3 低命中缓存与计算成本

常见表现包括：为便宜计算增加缓存后反而变慢，高基数键只访问一次，哈希、分配和同步成本超过被缓存的工作。

低效代码：

```cangjie
import std.collection.*

let lengthCache = HashMap<String, Int64>()

func cachedLength(key: String): Int64 {
    if (let Some(value) <- lengthCache.get(key)) {
        return value
    }
    let value = key.size
    lengthCache.add(key, value)
    return value
}
```

问题说明：`String.size` 是便宜操作。输入键很少复用时，缓存不会省下足够计算，反而为每次调用增加哈希查询、条目分配和持有成本。是否值得缓存必须由命中率与同负载基准决定，不能只因函数被重复调用就加入 `HashMap`。

修正代码：

```cangjie
func stringLength(key: String): Int64 {
    key.size
}
```

#### 诊断与修复

1. 记录调用次数、唯一键数量、命中率、计算耗时、缓存查询耗时和分配；用相同键分布比较直接计算与缓存版本。

2. 计算便宜且命中率低时删除缓存；DT 覆盖空字符串、Unicode、多次重复键和高基数一次性键，先证明返回值完全一致，再比较同一构建配置下的基准。

3. 计算昂贵且命中率足够高时可以保留缓存，但容量、过期和失效仍需单独设计；缓存带来的性能变化以命中率和成本数据为依据。

---

## 8. spawn、Future 与同步

### 8.1 spawn 任务粒度

常见表现包括：为每个很小的元素创建一个 `spawn`，任务调度、Future 保存和汇合成本超过实际工作。

低效代码：

```cangjie
import std.collection.*

func sumSpawnEach(values: Array<Int64>): Int64 {
    let futures = ArrayList<Future<Int64>>(values.size)
    for (value in values) {
        futures.add(spawn { => value * value })
    }
    var total: Int64 = 0
    for (future in futures) {
        total += future.get()
    }
    return total
}
```

问题说明：仓颉线程采用 M:N 调度且较轻量，但并非零成本。极小任务的大量 `spawn` 会放大调度和对象管理成本。

修正代码：

```cangjie
func sumRange(values: Array<Int64>, start: Int64, end: Int64): Int64 {
    var total: Int64 = 0
    for (index in start..end) {
        total += values[index] * values[index]
    }
    return total
}

func sumInTwoTasks(values: Array<Int64>): Int64 {
    let middle = values.size / 2
    let left = spawn { => sumRange(values, 0, middle) }
    let right = spawn { => sumRange(values, middle, values.size) }
    return left.get() + right.get()
}
```

#### 诊断与修复

1. 固定并发度，记录任务数量、单任务时长、调度占比和共享写比例，先与串行基线比较。

2. 按足够大的批次提交独立工作，并设置最大并发度；DT 覆盖空输入、奇数长度、异常传播和结果等价。

3. 数据量小、任务间依赖强、共享热点或外部阻塞占主导时，不通过增加 `spawn` 掩盖瓶颈。

### 8.2 Future 等待位置与并行退化

常见表现包括：每次 `spawn` 后立即 `get()`，代码形式上使用并发，执行顺序却仍然串行。

低效代码：

```cangjie
func runTwoJobs(): Int64 {
    let first = spawn { => expensiveJob(1) }.get()
    let second = spawn { => expensiveJob(2) }.get()
    return first + second
}
```

问题说明：`Future.get()` 会阻塞到任务完成。第一次立即等待结束后才会提交第二个任务，二者无法重叠。

修正代码：

```cangjie
func runTwoJobs(): Int64 {
    let first = spawn { => expensiveJob(1) }
    let second = spawn { => expensiveJob(2) }
    return first.get() + second.get()
}
```

#### 诊断与修复

1. 画出 `spawn`/`get` 顺序，记录同时存活任务数、依赖关系和正确汇合点。

2. 先提交相互独立的任务，再在汇合点等待；DT 保持返回顺序、异常传播、取消和超时语义。

3. 后一任务依赖前一结果、任务极小或并发会违反外部资源限制时，不批量提交。

### 8.3 锁范围、Atomic 与复合操作

常见表现包括：耗时解析或 I/O 被放在锁内，锁等待占热点；或者把多步业务更新误认为并发集合会自动原子化。

低效代码：

```cangjie
import std.collection.*
import std.sync.*

let mutex = Mutex()
let parsedValues = HashMap<String, Int64>()

func parseAndStore(key: String, raw: String) {
    synchronized(mutex) {
        let value = expensiveParse(raw)
        parsedValues.add(key, value)
    }
}
```

问题说明：只有共享映射更新需要互斥，昂贵解析放在临界区会串行化所有调用。把解析移出锁后，也要接受同键可能被重复计算的语义。

修正代码：

```cangjie
func parseAndStore(key: String, raw: String) {
    let value = expensiveParse(raw)
    synchronized(mutex) {
        parsedValues.add(key, value)
    }
}
```

#### 诊断与修复

1. 记录锁持有时间、等待时间、共享写比例和必须保持的复合不变量，不凭“用了并发集合”判定无竞态。

2. 缩小锁内工作；纯单值计数可评估 `Atomic`，跨字段不变量继续使用锁。压力 DT 验证最终状态、异常和重复执行。

3. 锁内计算决定检查后写入的原子语义、重复计算不可接受或无竞争证据时，不简单把工作移出锁。

---

## 9. I/O、日志与批处理

### 9.1 循环日志与输出放大

常见表现包括：短循环中每项调用 `println` 或格式化日志，CPU 优化后端到端耗时几乎不变。

低效代码：

```cangjie
func printValues(values: Array<Int64>) {
    for (value in values) {
        println("value=${value}")
    }
}
```

问题说明：每项格式化和输出可能主导耗时。生产日志是否允许合并取决于实时性、级别、审计和故障定位契约。

修正代码：

```cangjie
func printValues(values: Array<Int64>) {
    let builder = StringBuilder()
    for (value in values) {
        builder.append("value=${value}\n")
    }
    print(builder.toString())
}
```

#### 诊断与修复

1. 分段测量业务计算、格式化和输出，并记录日志条数与字节量。关闭日志后的结果只表示日志开销，不作为生产配置的整体优化结果。

2. 在契约允许时批量输出、降低不必要级别或异步交付；DT 检查内容、顺序、换行、异常和刷新语义。

3. 日志要求逐条实时落盘、审计不可丢失或内存批次过大时，不合并为无界字符串。

### 9.2 逐项调用与批量接口

常见表现包括：每条记录独立调用数据库、文件或序列化边界，固定开销随记录数线性放大。

低效代码：

```cangjie
func saveAll(records: Array<String>) {
    for (record in records) {
        writeOne(record)
    }
}
```

问题说明：`writeOne` 可能包含连接、系统调用、刷新或事务开销。批处理能减少边界次数，但会改变失败粒度和背压行为。

修正代码：

```cangjie
func saveAll(records: Array<String>) {
    const BATCH_SIZE: Int64 = 128
    var batch = ArrayList<String>(BATCH_SIZE)
    for (record in records) {
        batch.add(record)
        if (batch.size == BATCH_SIZE) {
            writeBatch(batch)
            batch = ArrayList<String>(BATCH_SIZE)
        }
    }
    if (!batch.isEmpty()) {
        writeBatch(batch)
    }
}
```

#### 诊断与修复

1. 记录每项固定成本、批次大小、端到端延迟、队列深度和下游限制，确认瓶颈在边界调用而非业务计算。

2. 设置有界批次和刷新条件；DT 覆盖零条、未满批次、刚好满批次、单条失败、重试和顺序。

3. 下游不支持批量、单条必须立即可见、失败必须精确隔离或批次会超过资源限制时，不强行合并。

### 9.3 基准中的准备、序列化与消费

常见表现包括：benchmark 每轮重新生成输入、序列化日志或下载文件，测到的是准备工作而非目标算法。

低效代码：

```cangjie
func measuredRound(raw: String): Int64 {
    let values = parseInput(raw)
    let result = coreAlgorithm(values)
    println(result)
    return result
}
```

问题说明：解析和输出会污染核心算法指标；另一方面，完全不消费结果又可能让测量失去可观察性。

修正代码：

```cangjie
func prepare(raw: String): Array<Int64> {
    return parseInput(raw)
}

func measuredRound(values: Array<Int64>): Int64 {
    return coreAlgorithm(values)
}
```

#### 诊断与修复

1. 分段测量准备、核心算法、格式化和 I/O，明确本次报告是核心基准还是端到端指标。

2. 把稳定输入准备移出基准体，并在测量外校验或消费结果；同一配置重跑多轮，报告绝对值和离散程度。

3. 生产路径本身必须包含解析、序列化或 I/O 时，不从端到端报告中删除这些工作；分别报告两个指标。

---

## 10. CFFI 与跨语言边界

### 10.1 逐元素 foreign 调用

常见表现包括：循环中为每个元素调用一次短 C 函数，profile 显示大量仓颉/C 边界切换而非 C 侧计算。

低效代码：

```cangjie
foreign func transformOne(value: Int64): Int64

func transformAll(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (value in values) {
        total += unsafe { transformOne(value) }
    }
    return total
}
```

问题说明：即使单次 foreign 调用很短，逐元素跨边界也会累积调用成本。批量 API 必须同时明确长度、ABI 和错误语义。

修正代码：

```cangjie
foreign func transformBatch(values: CPointer<Int64>, size: Int64): Int64

func transformAll(values: Array<Int64>): Int64 {
    unsafe {
        let handle = acquireArrayRawData(values)
        let result = transformBatch(handle.pointer, values.size)
        releaseArrayRawData(handle)
        return result
    }
}
```

#### 诊断与修复

1. 记录跨边界次数、每次数据量、C 侧执行时间和总耗时，证明调用固定成本占比明显。

2. 设计有界批量接口；DT 覆盖空数组、边界长度、C 错误码、ABI 和结果等价，并保证 handle 配对释放。

3. C API 只能逐项处理、批量会增加复制或单次调用本身很重时，不重写接口。

### 10.2 String 与 CString 转换

常见表现包括：循环中对同一 `String` 反复 `LibC.mallocCString` 和 `LibC.free`，原生分配与编码转换成为热点。

低效代码：

```cangjie
foreign func consume(text: CString): Unit

func repeatConsume(text: String, rounds: Int64) {
    for (_ in 0..rounds) {
        unsafe {
            let cText = LibC.mallocCString(text)
            consume(cText)
            LibC.free(cText)
        }
    }
}
```

问题说明：输入在循环期间不变，却重复分配和释放 `CString`。提升生命周期时仍必须保证 C 侧不在调用后保存悬空指针。

修正代码：

```cangjie
foreign func consume(text: CString): Unit

func repeatConsume(text: String, rounds: Int64) {
    let cText = unsafe { LibC.mallocCString(text) }
    try (resource = cText.asResource()) {
        for (_ in 0..rounds) {
            unsafe { consume(resource.value) }
        }
    }
}
```

#### 诊断与修复

1. 记录转换次数、字符串大小、所有权约定和 C 侧是否保存指针，不只测仓颉堆。

2. 在最小安全作用域内复用 `CStringResource`；DT 覆盖空串、非 ASCII、异常离开、零轮和 C 侧错误。

3. 文本每轮变化、C 侧接管所有权或指针必须长期保存时，不套用此局部复用方案。

### 10.3 原始数组窗口与阻塞 C 调用

常见表现包括：为 C 调用先复制完整数组，或在 `acquireArrayRawData` 与 `releaseArrayRawData` 之间执行复杂仓颉逻辑；阻塞 C 调用还可能占住原生线程。

低效代码：

```cangjie
foreign func process(values: CPointer<Int64>, size: Int64): Unit

func processValues(values: Array<Int64>) {
    let copy = values.clone()
    unsafe {
        let handle = acquireArrayRawData(copy)
        println("processing ${copy.size} values")
        process(handle.pointer, copy.size)
        releaseArrayRawData(handle)
    }
}
```

问题说明：无独立所有权需求时复制数组是额外开销；原始数据窗口内不应构造仓颉对象或执行复杂逻辑。长时间阻塞的 C 调用会占用对应原生线程，不能仅靠增加 `spawn` 解决。

修正代码：

```cangjie
foreign func process(values: CPointer<Int64>, size: Int64): Unit

func processValues(values: Array<Int64>) {
    println("processing ${values.size} values")
    unsafe {
        let handle = acquireArrayRawData(values)
        process(handle.pointer, values.size)
        releaseArrayRawData(handle)
    }
}
```

#### 诊断与修复

1. 记录复制量、raw-data 窗口时长、C 调用阻塞时间和并发吞吐，并确认 C 侧不会在返回后使用指针。

2. 将日志和仓颉对象构造移到窗口外，保持 acquire/process/release 最短配对路径；DT 覆盖异常、空数组和 C 错误路径。

3. C 侧会异步保存指针、修改需要独立快照或调用可能长期阻塞且无法改造时，不直接暴露仓颉数组底层数据；应重新设计所有权和调度边界。

---

## 11. 类型与数据表示

### 11.1 小型不可变记录与 class 分配

常见表现包括：大量只读坐标、键值或测量记录使用 `class` 表示，profile 显示对象分配和间接访问集中在热路径。

低效代码：

```cangjie
class Point {
    let x: Int64
    let y: Int64

    init(x: Int64, y: Int64) {
        this.x = x
        this.y = y
    }
}

func sumPoints(points: Array<Point>): Int64 {
    var total: Int64 = 0
    for (point in points) {
        total += point.x + point.y
    }
    return total
}
```

问题说明：`class` 是引用类型，每个实例具有对象身份；当数据只是小型不可变记录且大量密集存放时，对象分配和间接访问可能成为额外成本。`class` 与 `struct` 的性能差异仍需按真实数据布局和负载测量。

修正代码：

```cangjie
struct Point {
    let x: Int64
    let y: Int64

    init(x: Int64, y: Int64) {
        this.x = x
        this.y = y
    }
}

func sumPoints(points: Array<Point>): Int64 {
    var total: Int64 = 0
    for (point in points) {
        total += point.x + point.y
    }
    return total
}
```

#### 诊断与修复

1. 记录实例数量、分配热点、记录大小和访问模式，使用相同输入比较 `class` 与 `struct` 的延迟和分配。

2. 仅在对象没有身份、继承、共享修改和空引用语义时改为小型 `struct`；DT 覆盖字段值、集合顺序和序列化结果。

3. 对象需要多处共享、运行时多态、可空引用，或结构体较大且频繁复制时，保留 `class`。

### 11.2 大型 struct 的值复制

常见表现包括：较大的可变 `struct` 在函数参数、返回值和集合更新之间反复复制；修改副本后原值不变，热点中出现额外数据搬运。

低效代码：

```cangjie
struct BatchStats {
    var accepted: Int64 = 0
    var rejected: Int64 = 0
    var bytesRead: Int64 = 0
    var bytesWritten: Int64 = 0
    var retries: Int64 = 0
    var elapsedNanos: Int64 = 0

    mut func record(ok: Bool) {
        if (ok) { accepted++ } else { rejected++ }
    }
}

func recordCopy(stats: BatchStats, ok: Bool): BatchStats {
    var next = stats
    next.record(ok)
    return next
}
```

问题说明：`struct` 是值类型，赋值和传参使用值语义。小值复制未必昂贵，但字段较多、调用频繁或多轮返回新值时，需要用 profile 和可比基准确认复制成本。

修正代码：

```cangjie
class BatchStats {
    var accepted: Int64 = 0
    var rejected: Int64 = 0
    var bytesRead: Int64 = 0
    var bytesWritten: Int64 = 0
    var retries: Int64 = 0
    var elapsedNanos: Int64 = 0

    func record(ok: Bool) {
        if (ok) { accepted++ } else { rejected++ }
    }
}

func recordShared(stats: BatchStats, ok: Bool) {
    stats.record(ok)
}
```

#### 诊断与修复

1. 记录结构体大小、复制位置、调用次数和修改后的身份语义，先排除算法和集合重建造成的更大开销。

2. 仅在调用方接受共享可变状态时改为 `class`，并为并发访问建立同步边界；DT 覆盖连续更新、别名访问和异常路径。

3. 需要快照、值相等、线程间隔离或复制成本没有进入热点时，保留 `struct`，不要为了少一次复制改变业务语义。

### 11.3 Any 容器与热路径类型检查

常见表现包括：本应同类型的数据放入 `Array<Any>`，循环中反复使用 `as` 判断并转换，错误类型被静默跳过。

低效代码：

```cangjie
func sumValues(values: Array<Any>): Int64 {
    var total: Int64 = 0
    for (value in values) {
        match (value as Int64) {
            case Some(number) => total += number
            case None => ()
        }
    }
    return total
}
```

问题说明：`Any` 适合确实异构的边界，但会丢失静态类型信息；`as Int64` 返回 `Option<Int64>`，每个元素都要进行运行时类型检查，也可能掩盖上游数据错误。

修正代码：

```cangjie
func sumValues(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (value in values) {
        total += value
    }
    return total
}
```

#### 诊断与修复

1. 记录容器真实类型分布、转换次数、失败次数和调用规模，确认数据在进入热路径前已经具备同质契约。

2. 在解析或插件边界完成一次类型校验，内部改用具体泛型类型；DT 覆盖非法元素拒绝、空集合和总和等价。

3. 数据确实异构、需要开放扩展或类型分发本身就是业务逻辑时，保留 `Any`，但应显式处理不匹配而不是静默丢弃。

---

## 12. 背压与有界并发

### 12.1 无界在途任务

常见表现包括：为整个输入集合一次性创建 `Future`，生产速度超过执行和下游速度，在途任务、闭包和结果持续占用内存。

低效代码：

```cangjie
import std.collection.*

func runAll(values: Array<Int64>): Int64 {
    let futures = ArrayList<Future<Int64>>(values.size)
    for (value in values) {
        let item = value
        futures.add(spawn { => work(item) })
    }
    var total: Int64 = 0
    for (future in futures) {
        total += future.get()
    }
    return total
}
```

问题说明：仓颉线程较轻量但并非零成本。任务总数、在途数量和下游容量是不同概念；一次性提交会把输入规模直接变成调度和内存压力。

修正代码：

```cangjie
import std.collection.*

func collectBatch(futures: ArrayList<Future<Int64>>): Int64 {
    var total: Int64 = 0
    try {
        for (future in futures) { total += future.get() }
        return total
    } catch (error: Exception) {
        for (future in futures) { future.cancel() }
        throw error
    }
}

func runWithWindow(values: Array<Int64>, maxInFlight: Int64): Int64 {
    if (maxInFlight <= 0) {
        throw IllegalArgumentException("maxInFlight must be positive")
    }
    let futures = ArrayList<Future<Int64>>(maxInFlight)
    var total: Int64 = 0
    for (value in values) {
        let item = value
        futures.add(spawn { => work(item) })
        if (futures.size == maxInFlight) {
            total += collectBatch(futures)
            futures.clear()
        }
    }
    total += collectBatch(futures)
    return total
}
```

#### 诊断与修复

1. 记录任务总数、最大在途数、队列深度、单任务耗时、下游容量和峰值内存，确认压力来自提交速度。

2. 将 `maxInFlight` 设为大于零的有界配置并按窗口汇合；任一任务失败时观察第一根因并向同批任务发送取消请求。示例使用最小批次屏障，长尾任务明显时再改为滚动窗口或有界队列。DT 覆盖空输入、非法窗口、未满窗口、刚好满窗口、任务异常和结果等价。

3. `cancel()` 只发送协作请求；`work` 没有取消检查点时，失败后的同批任务仍可能运行。任务很少、天然受外部队列约束或必须同时启动后协同工作时，不机械分批；窗口值必须用目标负载测量，不等同于 CPU 核数。

### 12.2 超时、取消与协作检查点

常见表现包括：调用方超时后返回，但后台任务仍占用 CPU、文件句柄或锁；新任务不断进入，系统的有效并发持续上升。

低效代码：

```cangjie
import std.time.*

func waitJob(future: Future<Int64>): ?Int64 {
    try {
        return Some(future.get(Duration.second))
    } catch (_: TimeoutException) {
        return None
    }
}
```

问题说明：`get(timeout)` 超时只表示期限内没有结果，不会停止任务；`cancel()` 也是协作请求，任务必须在安全位置检查取消状态。

本场景只在主要问题是超时任务继续占用并发容量、CPU或文件句柄时使用；若主要风险是迟到任务继续修改业务状态，应按运行时正确性处理，而不是把吞吐优化当作异常修复。

修正代码：

```cangjie
import std.time.*

func cancellableWork(): ?Int64 {
    var total: Int64 = 0
    for (value in 0..100000) {
        if (Thread.currentThread.hasPendingCancellation) {
            return None
        }
        total += value
    }
    return Some(total)
}

func waitJob(future: Future<?Int64>): ?Int64 {
    try {
        return future.get(Duration.second)
    } catch (_: TimeoutException) {
        future.cancel()
        return None
    }
}
```

#### 诊断与修复

1. 记录超时数、超时后的存活任务、资源占用、共享副作用和取消到退出的延迟，区分慢任务与无法中断的阻塞调用。

2. 超时时请求协作取消，并在循环、分块 I/O 或批次边界设置有限检查点；DT 覆盖正常完成、超时、取消后状态和迟到结果。

3. 外部 C 调用、不可中断系统调用或临界区不能安全退出时，`cancel()` 只表示取消请求；在更外层限制在途任务并隔离阻塞资源。

---

## 13. Profiler 选择与证据

- Linux 且当前工具支持时，使用 `cjprof record/report` 获取 CPU 热点；需要权限时先说明原因，不自动使用 `sudo`。
- `record/report` 不可用时，使用 `cjpm bench`、重复端到端测量或可撤销的分段计时。
- `cjprof heap` 只用于内存证据，不能替代 CPU 热点采样。
- 算法与集合问题先看输入规模和调用次数；字符串、闭包、缓存和 CFFI 同时观察分配；并发和 I/O 同时观察等待、队列与吞吐。

---

## 14. 完成门槛

- 热点、复杂度、等待或分配证据与修改位置一致；
- 每个修改都有功能等价 DT，顺序、重复值、异常、Unicode、并发和所有权语义没有退化；
- 相同环境和负载下重复测量，报告绝对值、单位、离散程度和方法；
- 延迟、吞吐、CPU 和内存护栏没有明显劣化；
- 无法在目标平台复测时，将结果范围限定为当前已测平台。
