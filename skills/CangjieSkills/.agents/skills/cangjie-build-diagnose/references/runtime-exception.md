# 仓颉运行时异常

本页整理仓颉程序已经通过编译、但在执行期间抛出异常、卡住、异常退出或进入非法状态时的定位、修复和验证方法。

代码示例分为可独立编译的最小示例和依赖当前场景的替换片段。替换片段沿用同一场景中已声明的类型、导入、资源和辅助函数，业务接口需接入目标项目的真实实现并验证正常与异常路径。

可执行 DT 优先沿用目标项目已有测试结构；项目没有现成用例时参考 `cangjie-coding` 中的 `std.unittest` 文档。

原样保存异常类型、完整消息、调用栈、标准输出、标准错误、启动命令、退出状态、SDK、target、平台和最小输入。`cjpm run` 可能在程序打印未捕获异常后仍返回 `0`；需要确认退出语义时，直接运行生成的二进制并记录真实状态。

先定位第一个用户代码栈帧，再区分业务缺省、可恢复 `Exception`、`Error`、环境故障、原生崩溃和阻塞，最后在能够恢复的最小边界捕获具体异常。

## 1. Option 与缺省值

### 1.1 NoneValueException 与业务缺省

常见表现包括：`NoneValueException`、无条件 `getOrThrow()`，或者用异常表达业务允许的“没有值”。

问题代码：

```cangjie
func display(value: ?Int64): String {
    return "value=${value.getOrThrow()}"
}
```

问题说明：`?T` 是 `Option<T>` 的简写；只有由程序不变量证明值必然存在时才能调用 `getOrThrow()`。外部输入、配置读取和 `tryParse` 的结果都不能视为这种证明，修复这些路径时不得重新引入 `getOrThrow()`。业务缺省不等于程序异常。

修正代码：

```cangjie
func display(value: ?Int64): String {
    return match (value) {
        case Some(number) => "value=${number}"
        case None => "missing"
    }
}
```

#### 诊断与修复

1. 定位最早调用 `getOrThrow()` 的用户代码栈帧，追踪 Option 来源，判断 `None` 是合法缺失、解析失败还是被吞掉的异常。

2. 显式覆盖 `Some` 和 `None`；DT 同时验证原始生产路径，不通过删除断言或返回无依据默认值消除异常。

3. 业务没有定义“缺失”与“失败”的区别时，不擅自把 `None` 转成异常或把异常转成 `None`。

4. 只有违反程序内部不变量时才考虑让 `None` 终止当前操作，并在代码旁写出该不变量；面向外部输入的建议应返回 `Option`、显式 `match`，或提供能区分失败原因的业务结果。

### 1.2 缺失、空值与解析失败

常见表现包括：未提供配置、空字符串、格式非法和数值越界全部被压成 `None` 或统一替换为零。

问题代码：

```cangjie
import std.convert.*

func readPort(raw: ?String): Int64 {
    let value = raw.getOrThrow()
    return Int64.tryParse(value).getOrThrow()
}
```

问题说明：链式 Option 把字段缺失和解析失败混在一起，双重 `getOrThrow()` 又把两种情况变成相同异常。调用方无法给出准确错误信息。

修正代码：

```cangjie
import std.convert.*

enum PortParseResult {
    | Missing
    | Invalid(String)
    | Value(Int64)
}

func readPort(raw: ?String): PortParseResult {
    match (raw) {
        case None => Missing
        case Some(value) =>
            match (Int64.tryParse(value)) {
                case Some(port) => Value(port)
                case None => Invalid(value)
            }
    }
}
```

#### 诊断与修复

1. 固定原始输入，分别记录字段缺失、空字符串、格式非法和越界值的实际路径。

2. 按 API 契约选择 `parse`、`tryParse` 或能够携带失败原因的业务结果类型；需要区分原因时，让 `Missing`、`Invalid(raw)` 和 `Value(port)` 成为不同构造器。DT 覆盖合法、缺失、空值、非法和边界输入。

3. 调用方需要具体失败原因时，不只返回 `Option`；`?Int64` 的单个 `None` 不能同时表达缺失和格式非法，更不存在 `Some(None)` 这一层级。应保留异常或定义能够区分原因的业务结果。

4. 回答解析问题时，不在修正代码、注释或备选建议中把 `getOrThrow()` 描述为“安全处理”；即使选择业务默认值，也要说明默认值的业务依据，不能用 `0`、空字符串等无依据值掩盖失败。

### 1.3 可选链短路与副作用

常见表现包括：`a?.b()` 返回 `None` 后仍假定 `b()` 已执行，或者可选链赋值在接收者为 `None` 时被误认为写入成功。

问题代码：

```cangjie
class Counter {
    var value: Int64 = 0
    func increase() { value++ }
}

func update(counter: ?Counter) {
    counter?.increase()
    println("updated")
}
```

问题说明：可选链在首个 `None` 处短路，`increase()` 可能根本没有执行；无条件打印成功信息会制造错误状态。

修正代码：

```cangjie
func update(counter: ?Counter): Bool {
    match (counter) {
        case Some(value) =>
            value.increase()
            true
        case None => false
    }
}
```

#### 诊断与修复

1. 记录链上每一级 Option 来源和实际副作用，用 `Some`/`None` 两条最小路径确认哪一步被跳过。

2. 对必须发生的操作显式解包并返回可观察状态；仅对允许跳过的读取使用可选链。

3. 链上操作是否必须执行不明确时，先澄清业务语义，不把短路改成自动创建对象。

---

## 2. 输入解析与参数契约

### 2.1 解析异常与错误上下文

常见表现包括：数值、时间、正则、参数或配置解析抛异常，上层只看到“格式错误”而不知道字段和原始输入。

问题代码：

```cangjie
import std.convert.*

func parseRetry(raw: String): Int64 {
    try {
        return Int64.parse(raw)
    } catch (_: IllegalArgumentException) {
        return 0
    }
}
```

问题说明：返回 `0` 会让格式错误与合法零值无法区分，同时丢失字段名、原始输入和失败位置。

修正代码：

```cangjie
import std.convert.*

class ConfigException <: Exception {
    init(message: String) { super(message) }
}

func parseRetry(raw: String): Int64 {
    try {
        return Int64.parse(raw)
    } catch (error: IllegalArgumentException) {
        throw ConfigException("invalid retry `${raw}`: ${error.message}")
    }
}
```

#### 诊断与修复

1. 保存实际异常类型、字段名、原始输入的安全摘要和首个用户栈帧，区分语法错误、范围错误和字段缺失。

2. 在 API 边界补充业务上下文并保持失败语义；DT 覆盖合法、非法、空值和边界输入。

3. 输入包含密码、令牌或个人信息时，不把原始值直接写入异常或日志。

### 2.2 IllegalArgument 与负容量

常见表现包括：负容量、非法超时、错误 Range 步长或不满足前置条件的参数触发 `IllegalArgumentException`、`NegativeArraySizeException`。

问题代码：

```cangjie
import std.collection.*

func createBuffer(capacity: Int64): ArrayList<UInt8> {
    return ArrayList<UInt8>(capacity)
}
```

问题说明：构造器会拒绝负容量，但异常发生在底层 API，调用方无法看到参数的业务来源。

修正代码：

```cangjie
import std.collection.*

func createBuffer(capacity: Int64): ArrayList<UInt8> {
    if (capacity < 0) {
        throw IllegalArgumentException("capacity must be non-negative: ${capacity}")
    }
    return ArrayList<UInt8>(capacity)
}
```

#### 诊断与修复

1. 记录参数值、单位、来源和合法范围，确认负值来自输入、溢出还是缺省值转换。

2. 在最接近业务边界的位置校验，DT 覆盖最小值、零、正常值和最大允许值。

3. 底层异常已经提供完整稳定契约时，不重复增加没有信息量的检查。

### 2.3 IllegalState 与调用顺序

常见表现包括：对象尚未启动、已经关闭或当前状态不允许操作时继续调用，最终抛 `IllegalStateException` 或产生错误结果。

问题代码：

```cangjie
class Session {
    var isOpen = false
    func open() { isOpen = true }
    func send(message: String) {
        println(message)
    }
}
```

问题说明：`send` 没有检查生命周期，调用方可以在 `open` 前发送，错误会延迟到更深的 I/O 层。

修正代码：

```cangjie
class Session {
    var isOpen = false
    func open() { isOpen = true }
    func send(message: String) {
        if (!isOpen) {
            throw IllegalStateException("session is not open")
        }
        println(message)
    }
}
```

#### 诊断与修复

1. 记录对象状态转换和调用顺序，找出首次进入非法状态的位置，而不是只处理最后一次调用。

2. 在公共边界建立状态前置条件；DT 覆盖正常顺序、重复调用、关闭后调用和异常恢复。

3. 状态允许自动恢复还是必须失败没有定义时，不擅自重建连接或重置对象。

---

## 3. 数值、Range 与集合边界

### 3.1 溢出、除零与算术策略

常见表现包括：`ArithmeticException`、`OverflowException`、除数为零，或者代码依赖未说明的回绕行为。

问题代码：

```cangjie
func average(total: Int64, count: Int64): Int64 {
    return total / count
}
```

问题说明：`count == 0` 会触发算术异常；加减乘还需要明确 checked、throwing、saturating 或 wrapping 语义。

修正代码：

```cangjie
func average(total: Int64, count: Int64): ?Int64 {
    if (count == 0) {
        return None
    }
    return Some(total / count)
}
```

#### 诊断与修复

1. 记录操作数类型、最大最小值、原始输入和业务要求的算术语义，不只看异常最后一行。

2. DT 覆盖零、正常值、`T.Min`、`T.Max` 和刚刚越界的运算；只有协议明确要求时才使用回绕。

3. 业务未定义溢出或除零语义时，列出不同选择和影响，不替调用方静默选择零、饱和或回绕。

### 3.2 Range 与数组越界

常见表现包括：`IndexOutOfBoundsException` 指向数组访问，循环使用包含结束值的 Range，长度为 N 时访问索引 N。

问题代码：

```cangjie
func sum(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (index in 0..=values.size) {
        total += values[index]
    }
    return total
}
```

问题说明：`0..=values.size` 包含结束值，最后一次访问的索引等于数组长度，超出合法范围。

修正代码：

```cangjie
func sum(values: Array<Int64>): Int64 {
    var total: Int64 = 0
    for (index in 0..values.size) {
        total += values[index]
    }
    return total
}
```

#### 诊断与修复

1. 保存数组长度、实际索引和 Range 上下界，用最小输入确认最后一个索引。

2. 让迭代边界与集合长度语义一致；DT 覆盖空数组、单元素、普通输入和最大合法索引。

3. 循环本意是处理包含结束值的业务区间时，不机械修改 Range；应调整索引映射或数据结构。

### 3.3 迭代期间修改集合

常见表现包括：遍历 `ArrayList`、`HashMap` 或 `HashSet` 时增删同一集合，触发 `ConcurrentModificationException`。

问题代码：

```cangjie
import std.collection.*

func removeNegative(values: ArrayList<Int64>) {
    for (value in values) {
        if (value < 0) {
            values.remove(at: 0)
        }
    }
}
```

问题说明：迭代器活动期间结构性修改集合会使迭代状态失效，而且删除索引 `0` 也不一定是当前负数。

修正代码：

```cangjie
import std.collection.*

func removeNegative(values: ArrayList<Int64>) {
    values.removeIf { value => value < 0 }
}
```

#### 诊断与修复

1. 保存集合类型、迭代方式、修改位置和异常栈，区分同线程结构修改与真正的跨线程竞态。

2. 使用集合提供的批量删除 API，或遍历副本后集中修改；DT 覆盖连续匹配、首尾匹配和空集合。

3. 修改顺序、回调副作用或并发可见性属于业务契约时，不只为消除异常更换 API。

---

## 4. 异常层次与传播

### 4.1 宽泛捕获与默认值

常见表现包括：`catch (_)` 或 `catch (e: Exception)` 后返回默认值，原始异常类型、输入和调用栈全部消失。

问题代码：

```cangjie
import std.fs.*

func loadCount(): Int64 {
    try {
        return readCountFromFile()
    } catch (_) {
        return 0
    }
}
```

问题说明：返回合法零值会让文件不存在、权限不足、格式错误和程序缺陷无法区分。

修正代码：

```cangjie
func loadCount(): Int64 {
    try {
        return readCountFromFile()
    } catch (error: FSException) {
        println("failed to read count: ${error.message}")
        throw error
    }
}
```

#### 诊断与修复

1. 保存被捕获的实际异常类型、首个用户栈帧和调用方契约，确认哪些异常可以恢复。

2. 捕获最具体的可恢复异常，保留或补充上下文；DT 同时覆盖目标异常和不应被捕获的异常。

3. API 边界没有定义默认值语义时，不通过默认值改变外部可观察行为。

### 4.2 异常转换与上下文保留

常见表现包括：底层异常被替换成没有字段、操作和输入信息的新异常，排查只能看到包装层。

问题代码：

```cangjie
class ServiceException <: Exception {
    init(message: String) { super(message) }
}

func loadUser(id: String): String {
    try {
        return queryUser(id)
    } catch (_: Exception) {
        throw ServiceException("load failed")
    }
}
```

问题说明：宽泛捕获和固定消息会丢失底层类型、用户标识和操作阶段，甚至错误地转换程序缺陷。

修正代码：

```cangjie
import std.io.*

class ServiceException <: Exception {
    let cause: Exception

    init(message: String, cause: Exception) {
        super(message)
        this.cause = cause
    }
}

func loadUser(id: String): String {
    try {
        return queryUser(id)
    } catch (error: IOException) {
        throw ServiceException("load user `${id}` failed: ${error.message}", error)
    }
}
```

#### 诊断与修复

1. 明确 API 边界允许转换的底层异常集合，并通过自定义字段保留原异常对象和安全上下文；仓颉 `Exception` 没有内置 `cause` 构造参数。

2. 只转换需要稳定外部契约的异常；DT 检查消息、类型和不应转换的异常仍然传播。

3. 上下文包含敏感信息或原异常无法安全公开时，记录关联标识而不是完整原始数据。

### 4.3 finally 掩盖根因

常见表现包括：业务代码先抛异常，`finally` 中的清理再次抛异常或返回，最终只能看到清理故障。

问题代码：

```cangjie
func execute() {
    try {
        runBusiness()
    } finally {
        runCleanupThatMayThrow()
    }
}
```

问题说明：清理异常可能覆盖原始业务异常。`finally` 应保持简单，资源优先使用 try-with-resources 管理；但资源的 `close()` 也可能抛异常，自动释放不等于自动解决双故障优先级。

修正代码：

```cangjie
import std.fs.*

func execute(path: Path) {
    try (file = File(path, Write)) {
        runBusiness(file)
    }
}
```

#### 诊断与修复

1. 同时保存业务异常和清理阶段输出，确认最终传播的异常是否覆盖第一根因。

2. 使用 `Resource` 统一所有权，把业务逻辑移出 `finally`；DT 覆盖正常、业务异常和清理异常路径。

3. 清理本身可能失败且必须上报时，先定义双故障优先级，不静默丢弃任一异常。

---

## 5. Future 与任务生命周期

### 5.1 Future 异常传播

常见表现包括：`spawn` 内已经抛异常，但调用方没有观察；直到 `Future.get()` 才出现根因。

问题代码：

```cangjie
func startJob() {
    spawn { =>
        throw Exception("task failed")
    }
}
```

问题说明：`spawn` 返回 `Future<T>`，任务异常由 Future 保存；丢弃 Future 会同时丢失结果、异常和生命周期控制。

修正代码：

```cangjie
func runJob() {
    let future = spawn { =>
        throw Exception("task failed")
    }
    try {
        future.get()
    } catch (error: Exception) {
        println(error.message)
    }
}
```

#### 诊断与修复

1. 保存 `spawn`/`get` 顺序、任务栈和调用方栈，确认异常是在任务内部产生还是等待时包装。

2. 保留 Future 并在生命周期边界观察结果；DT 覆盖正常结果、任务异常和调用方处理。

3. 任务明确允许 fire-and-forget 时，也要定义未捕获异常记录和进程退出策略。

### 5.2 超时不等于取消

常见表现包括：`Future.get(timeout)` 抛 `TimeoutException` 后，调用方假定任务已经停止，任务却继续修改共享状态。

问题代码：

```cangjie
import std.time.*

func waitJob(future: Future<Int64>): Int64 {
    try {
        return future.get(Duration.second)
    } catch (_: TimeoutException) {
        return 0
    }
}
```

问题说明：超时只表示期限内没有结果；`cancel()` 也是协作请求，不会强制终止任务。

本场景关注迟到任务继续修改共享状态、异常语义或生命周期的正确性；若主要证据是超时任务挤占在途窗口并拖低吞吐，应另按性能容量问题测量。

修正代码：

```cangjie
import std.time.*

func cancellableWork(): Int64 {
    var total: Int64 = 0
    for (value in 0..100000) {
        if (Thread.currentThread.hasPendingCancellation) {
            return total
        }
        total += value
    }
    return total
}

func waitJob(future: Future<Int64>): ?Int64 {
    try {
        return Some(future.get(Duration.second))
    } catch (_: TimeoutException) {
        future.cancel()
        return None
    }
}
```

#### 诊断与修复

1. 记录超时时长、任务状态、共享副作用和取消检查点，区分慢任务、阻塞和循环等待。

2. 把超时作为明确结果，决定是否请求协作取消；任务内部必须在循环、批次或 I/O 边界检查 `Thread.currentThread.hasPendingCancellation`，DT 覆盖迟到结果和取消后状态。仅调用 `cancel()` 不能证明任务已经停止。

3. 外部 C 调用不响应取消或任务不可安全中断时，`cancel()` 只表示已经发送取消请求。

### 5.3 主线程退出与后台任务

常见表现包括：后台任务输出、写盘或清理偶尔不发生，程序在 `main` 返回后直接结束。

问题代码：

```cangjie
main() {
    spawn { =>
        saveResult()
    }
    ()
}
```

问题说明：末尾的 `()` 让 `main` 保持 `Unit` 返回类型，但没有保存和等待 `spawn` 返回的 Future。主线程退出时未完成的仓颉线程会结束，不能依赖后台任务自然完成。

修正代码：

```cangjie
main() {
    let future = spawn { =>
        saveResult()
    }
    future.get()
}
```

#### 诊断与修复

1. 保存 Future 持有关系、main 返回时机和任务输出，区分任务未启动、未完成和异常退出。

2. 在应用生命周期边界等待必须完成的任务；DT 覆盖正常完成、任务异常和关闭流程。

3. 长期服务或守护任务不适合由 main 无限等待时，应设计明确的服务生命周期和关闭信号。

---

## 6. 同步与并发状态

### 6.1 Condition 与 Mutex 状态

常见表现包括：未持有 Mutex 时调用 `condition()`、`wait()`、`notify()` 或 `unlock()`，抛 `IllegalSynchronizationStateException`。

问题代码：

```cangjie
import std.sync.*

let mutex = Mutex()
let condition = mutex.condition()
```

问题说明：Condition 与创建它的 Mutex 绑定，创建和等待、通知都要求持有对应锁。

修正代码：

```cangjie
import std.sync.*

let mutex = Mutex()
let condition = synchronized(mutex) {
    mutex.condition()
}
```

#### 诊断与修复

1. 保存锁对象、Condition 创建位置、lock/unlock 次数和异常栈，确认操作使用同一 Mutex。

2. 在 `synchronized` 或成对 lock/unlock 作用域内创建和操作 Condition；等待使用循环重新检查谓词。

3. 没有共享状态谓词或通知方时，增加 `sleep` 只能改变时序，不能建立同步关系。

### 6.2 死锁与锁顺序

常见表现包括：程序没有异常但永久卡住，两条任务分别持有一把锁并等待另一把锁。

问题代码：

```cangjie
import std.sync.*

let first = Mutex()
let second = Mutex()

func pathA() { synchronized(first) { synchronized(second) { work() } } }
func pathB() { synchronized(second) { synchronized(first) { work() } } }
```

问题说明：两条路径锁顺序相反，满足循环等待条件。增加超时或线程数不会消除根因。

修正代码：

```cangjie
func pathA() { synchronized(first) { synchronized(second) { work() } } }
func pathB() { synchronized(first) { synchronized(second) { work() } } }
```

#### 诊断与修复

1. 获取所有相关线程栈、持有锁和等待锁，画出最小等待图，确认存在稳定循环。

2. 统一锁顺序或合并不必要的锁；压力 DT 使用可控同步点稳定复现，而不是依赖随机时序。

3. 没有等待链证据时，不把慢 I/O、阻塞队列或外部 C 调用误报为死锁。

### 6.3 共享状态与复合操作

常见表现包括：多个任务执行“读取—计算—写入”，最终计数丢失；使用并发集合后复合业务操作仍竞态。

问题代码：

```cangjie
var count: Int64 = 0

func increase() {
    count = count + 1
}
```

问题说明：读取和写入不是一个原子步骤，多任务可能基于同一个旧值计算并相互覆盖。

修正代码：

```cangjie
import std.sync.*

let count = AtomicInt64(0)

func increase() {
    count.fetchAdd(1)
}
```

#### 诊断与修复

1. 固定并发度和操作次数，多轮记录实际结果、预期不变量和复现率。

2. 单值计数使用 Atomic；跨字段不变量使用锁。压力 DT 检查最终状态、重复执行和异常路径。

3. 不变量跨多个对象或操作时，单个字段改为 Atomic 只能保护该字段，整体一致性仍需同步协议。

---

## 7. Resource、文件与流

### 7.1 try-with-resources 与离开路径

常见表现包括：异常或提前返回后文件、流或其他 `Resource` 未关闭，FD/句柄随请求单调增长，最终出现 `too many open files`、句柄耗尽或已占用错误。

问题代码：

```cangjie
import std.fs.*

func writeData(path: Path, data: Array<Byte>) {
    let file = File(path, Write)
    file.write(data)
    file.close()
}
```

问题说明：`write` 抛异常或中途返回时，`close()` 不会执行。实现 `Resource` 的对象应交给 try-with-resources。

本场景处理资源创建和使用都在同一函数内、但异常离开路径漏关的问题；若 API 把仍然打开的资源返回给调用方，首要问题是跨层所有权和关闭责任，而不是本节的局部异常路径。

观察到“重复打开 + 漏关路径 + FD/句柄单调增长”时，先修复资源关闭路径并验证 FD 稳态。关闭计数恢复对称后若仍有堆/RSS 增长或长期对象持有，再分析独立的持有关系。

修正代码：

```cangjie
import std.fs.*

func writeData(path: Path, data: Array<Byte>) {
    try (file = File(path, Write)) {
        file.write(data)
    }
}
```

#### 诊断与修复

1. 记录资源创建者、关闭责任和正常、异常、提前返回路径的打开/关闭次数。

2. 把资源放入最小 try-with-resources 作用域；DT 强制在创建后抛异常并验证只关闭一次。

3. 资源所有权属于调用方或类型未实现 `Resource` 时，不擅自关闭；先明确生命周期契约。

4. 使用固定并发度和请求数重复施压，验证应用级创建/关闭计数对称，并确认平台 FD/句柄数达到有界稳态；一次下降或一次成功请求不能证明泄漏已修复。

### 7.2 EOF、短读与实际字节数

常见表现包括：读取缓冲区后忽略返回字节数，把未填充区域当成有效数据；EOF 被误判为异常或完整消息。

问题代码：

```cangjie
import std.fs.*

func readBlock(file: File): Array<Byte> {
    let buffer = Array<Byte>(1024, repeat: 0)
    file.read(buffer)
    return buffer
}
```

问题说明：`read` 返回实际字节数，可能小于缓冲区长度；返回 `0` 表示流结束。直接返回整个数组会带入未读取区域。

修正代码：

```cangjie
import std.fs.*

func readBlock(file: File): Array<Byte> {
    let buffer = Array<Byte>(1024, repeat: 0)
    let count = file.read(buffer)
    return buffer.slice(0, count)
}
```

#### 诊断与修复

1. 记录请求长度、实际返回长度、EOF 位置和协议期望，区分短读、正常结束和 I/O 异常。

2. 只消费实际读取字节；DT 覆盖零字节、短块、完整块和多轮读取。

3. 协议要求读满固定长度时，不把短读当成功；应循环读取或返回明确的不完整数据错误。

### 7.3 路径、权限与关闭所有权

常见表现包括：`FSException`、路径不存在、权限不足、工作目录变化，或调用方和被调用方重复关闭同一资源。

问题代码：

```cangjie
import std.fs.*

func loadConfig(): File {
    return File(Path("./config.json"), Read)
}
```

问题说明：相对路径依赖当前工作目录，返回打开的 File 又把关闭责任隐式交给调用方。

修正代码：

```cangjie
import std.fs.*

func readConfig(path: Path): Int64 {
    var readCount: Int64 = 0
    try (file = File(path, Read)) {
        let buffer = Array<Byte>(4096, repeat: 0)
        readCount = file.read(buffer)
    }
    return readCount
}
```

#### 诊断与修复

1. 保存绝对路径、当前工作目录、权限、文件类型和资源所有者，不只记录“打开失败”。

2. 由参数显式提供路径并在函数内完成资源生命周期；DT 覆盖不存在、空文件、权限失败和正常路径。

3. API 本意是把流交给调用方持续消费时，不在函数内关闭；用文档明确所有权。

---

## 8. CFFI、unsafe 与原生故障

### 8.1 空指针与指针有效期

常见表现包括：`CPointer.read()` 访问空指针、C 侧保存只在调用期间有效的 `inout` 指针，或返回后继续访问失效内存。

问题代码：

```cangjie
func readValue(pointer: CPointer<Int64>): Int64 {
    return unsafe { pointer.read() }
}
```

问题说明：`unsafe` 只表示开发者承担安全责任，不会自动校验空指针、长度或生命周期。

修正代码：

```cangjie
func readValue(pointer: CPointer<Int64>): ?Int64 {
    if (pointer.isNull()) {
        return None
    }
    return Some(unsafe { pointer.read() })
}
```

#### 诊断与修复

1. 保存指针来源、分配者、释放者、有效长度和崩溃位置，确认 C 侧是否跨调用保存指针。

2. 在最小 unsafe 边界检查空指针和长度，使用所有权类型管理生命周期；DT 覆盖空指针和合法指针。

3. 指针已经悬空时，判空不能修复问题；必须重新设计所有权和保存期限。

### 8.2 原生内存所有权与重复释放

常见表现包括：`mallocCString`、`LibC.malloc` 后遗漏释放、多个所有者重复 `free`，或者异常路径跳过释放。

问题代码：

```cangjie
func sendText(text: String) {
    unsafe {
        let value = LibC.mallocCString(text)
        nativeSend(value)
        LibC.free(value)
    }
}
```

问题说明：`nativeSend` 抛出仓颉异常或提前离开时，手工 `free` 不会执行；如果 C 侧接管所有权，再次释放又会形成 double free。

修正代码：

```cangjie
func sendText(text: String) {
    let value = unsafe { LibC.mallocCString(text) }
    try (resource = value.asResource()) {
        unsafe { nativeSend(resource.value) }
    }
}
```

#### 诊断与修复

1. 明确每个指针由谁分配、谁释放、是否转移所有权以及异常时责任归属。

2. 所有权不转移时使用 `CStringResource`/`CPointerResource`；DT 覆盖正常、异常和重复调用。

3. C API 明确接管所有权时，不再由仓颉 Resource 自动释放；需要单独封装转移语义。

### 8.3 ABI、回调与原生崩溃

常见表现包括：仓颉侧声明能够编译，但结构体布局、调用约定或回调生命周期与 C 不一致，运行时出现乱码、signal 或崩溃。

问题代码：

```cangjie
@C
struct NativePoint {
    var x: Int64 = 0
    var y: Int64 = 0
}

foreign func consumePoint(point: NativePoint): Unit
```

问题说明：如果 C 头文件实际使用 `int32_t` 字段，仓颉的 `Int64` 声明会形成 ABI 不一致；这类原生故障通常不会变成可捕获 `Exception`。

修正代码：

```cangjie
@C
struct NativePoint {
    var x: Int32 = 0
    var y: Int32 = 0
}

foreign func consumePoint(point: NativePoint): Unit
```

#### 诊断与修复

1. 对照真实 C 头文件、平台位宽、调用约定和符号，保存 signal、原生栈和最小输入。

2. 逐字段校准 ABI，并确保回调和指针在 C 使用期间保持有效；在目标架构运行最小 round-trip DT。

3. 原生崩溃的修复结论需要原生栈、头文件或目标平台复现作为验证依据，仓颉 `try/catch` 只能处理可捕获异常。

---

## 9. Error、进程崩溃与平台边界

### 9.1 StackOverflowError 与无限递归

常见表现包括：深递归或缺失终止条件导致 `StackOverflowError`，程序无法通过普通业务异常恢复。

问题代码：

```cangjie
func countDown(value: Int64): Int64 {
    return countDown(value - 1)
}
```

问题说明：递归没有终止条件，每次调用继续消耗栈空间。捕获 `Error` 不能让已经破坏的执行状态安全恢复。

修正代码：

```cangjie
func countDown(value: Int64): Int64 {
    var current = value
    var count: Int64 = 0
    while (current > 0) {
        current--
        count++
    }
    return count
}
```

#### 诊断与修复

1. 保存重复栈帧、递归输入和终止条件，区分无限递归与合法但过深的输入。

2. 补终止条件或改为迭代/显式栈；DT 覆盖零、负数、普通值和大输入。

3. 算法必须递归且深度有严格上限时，不为形式统一强制改写，但要验证最大深度。

### 9.2 OOM 与资源耗尽证据

常见表现包括：集合或缓存无界增长，最终出现 OOM、系统杀进程或分配失败；宽泛捕获后程序继续处于不安全状态。

问题代码：

```cangjie
import std.collection.*

func retainForever(load: () -> Array<UInt8>) {
    let retained = ArrayList<Array<UInt8>>()
    while (true) {
        retained.add(load())
    }
}
```

问题说明：问题是无界生命周期，不是缺少 `catch`。OOM 属于内存取证入口，应分析持有链、增长速率和容量策略。

修正代码：

```cangjie
func processContinuously(load: () -> Array<UInt8>) {
    while (true) {
        let batch = load()
        process(batch)
    }
}
```

#### 诊断与修复

1. 保存 RSS、仓颉堆、条目数量和多轮负载时间线，区分堆增长、原生内存和系统资源限制。

2. 修复持有关系、容量或批次生命周期，并通过多轮相同负载验证稳态；DT 使用有界压力复现资源耗尽前的增长趋势。

3. 进程终止原因需结合内存证据判断；捕获 `Error` 不表示执行状态已经恢复。

### 9.3 平台差异与退出状态

常见表现包括：相同代码只在特定 SDK、target 或操作系统异常；API 不受支持，或者 `cjpm run` 与直接产物退出状态不同。

问题代码：

```shell
cjpm run
echo $?
```

问题说明：只保存 `cjpm run` 的 shell 状态不足以证明程序成功，也无法定位 target、动态库或平台 API 差异。

修正代码：

```shell
cjpm build
./path/to/generated-binary >stdout.log 2>stderr.log
status=$?
echo "binary_status=${status}"
```

#### 诊断与修复

1. 保存 SDK、target triple、平台、构建 Profile、stdout、stderr、动态库和产物真实退出状态。

2. 在可用平台运行最小复现并与正常平台对照；对不支持的 API 提供显式能力判断或平台实现。

3. 跨平台修复结论需包含目标平台、产物路径和复现条件；缺少这些信息时记录当前证据和待验证范围。

---

## 10. 完成门槛

- 原始输入不再触发意外异常、卡死或崩溃，或者预期异常类型和消息保持兼容；
- 正常、缺省、错误输入、边界、超时、取消、并发和资源清理路径有聚焦 DT；
- 原始启动命令、生成产物和相关 `cjpm test` 均按适用范围复测；
- 没有通过宽泛捕获、忽略返回值、增大超时或删除断言掩盖故障；
- native crash、OOM、Error 或目标平台不可用时，记录对应证据和未验证边界。
