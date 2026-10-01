# 仓颉内存优化

本页整理仓颉内存增长、分配压力、对象持有、资源生命周期和原生内存问题的诊断、优化与验证方法。

代码示例分为可独立编译的最小示例和依赖当前场景的替换片段。替换片段沿用同一场景中已声明的类型、导入、缓存、资源和辅助函数，业务接口需接入目标项目的真实实现并验证持有关系和多轮稳态。

可执行 DT 优先沿用目标项目已有测试结构；项目没有现成用例时参考 `cangjie-coding` 中的 `std.unittest` 文档。

固定 SDK、平台、Release 配置、输入、并发度和采样间隔，记录空闲、稳定负载、压力负载、释放和下一轮负载的时间线。RSS 上升表示进程物理内存发生变化；结合仓颉堆、对象/条目数、容量、资源数、线程数或原生分配中的至少一类证据，再判断具体增长来源。

## 1. 仓颉堆、RSS 与 GC 证据

### 1.1 仓颉堆指标与平台 RSS

常见表现包括：OOM、RSS持续上涨、GC后数值不回落，或者把`getUsedHeapSize()`在所有平台都解释成仓颉堆。

问题代码：

```cangjie
import std.runtime.*

func report() {
    println("heap=${getUsedHeapSize()}")
}
```

问题说明：`getAllocatedHeapSize()`表示仓颉堆已被使用的大小；`getUsedHeapSize()`在Linux表示仓颉堆实际物理占用，在Windows和macOS表示仓颉进程实际物理内存，不能统一标成仓颉堆使用量。

修正代码：

```cangjie
import std.runtime.*

func report(platform: String, entries: Int64) {
    println("platform=${platform},entries=${entries},heapUsed=${getAllocatedHeapSize()},physicalUsed=${getUsedHeapSize()}")
}
```

#### 诊断与修复

1. 同时记录平台、`heapUsed`、平台含义正确的`physicalUsed`、业务对象/资源计数和负载阶段。

2. 将增长绑定到具体持有路径后再修改，以相同多轮负载复测业务计数、仓颉堆和RSS。

3. 只有单点RSS、没有负载阶段和第二类证据时，只报告“进程内存增长”，不判断仓颉堆泄漏。

### 1.2 多轮负载与有界稳态

常见表现包括：单轮压力后内存没有立即回到空闲值便判断修复失败，或者只比较两个不同时刻的RSS。

问题代码：

```cangjie
import std.runtime.*

func verifyOnce() {
    runLoad()
    gc(heavy: true)
    println(getUsedHeapSize())
}
```

问题说明：GC回收不可达对象不等于运行时立即归还堆区或物理页；单轮和单点无法区分预热、高水位与持续增长。

修正代码：

```cangjie
import std.runtime.*

func verifyRounds(rounds: Int64) {
    for (round in 0..rounds) {
        runLoad()
        releaseLoadData()
        gc(heavy: true)
        println("round=${round},entries=${retainedCount()},heapUsed=${getAllocatedHeapSize()},physicalUsed=${getUsedHeapSize()}")
    }
}
```

#### 诊断与修复

1. 固定输入、并发度和采样间隔，记录空闲、加载、释放、重GC和下一轮加载的时间线。

2. 至少使用多轮相同负载验证对象、资源和容量达到有界稳态，同时检查吞吐与延迟护栏；不要求单次回落到空闲值。

3. 负载、Profile或采样条件一致时再比较数值；条件不一致时将泄漏或回收结论标记为待验证。

### 1.3 堆快照与Profiler边界

常见表现包括：未说明路径、大小和敏感性便执行`dumpHeapData`或`cjprof heap`，或者用仓颉堆快照解释原生内存增长。

仓颉运行时接口签名为`dumpHeapData(path: Path)`；参数必须是`std.fs.Path`，不能把普通字符串直接当作快照路径。

问题代码：

```cangjie
import std.fs.*
import std.runtime.*

func dump() {
    dumpHeapData(Path("./heap.data"))
}
```

问题说明：快照可能包含敏感对象结构并占用大量磁盘；仓颉堆快照不能覆盖所有C分配、映射文件和平台缓存。

修正代码：

```cangjie
import std.fs.*
import std.runtime.*

func dump(path: Path, isAuthorized: Bool) {
    if (!isAuthorized) {
        throw IllegalStateException("heap dump is not authorized")
    }
    dumpHeapData(path)
}
```

#### 诊断与修复

1. 先判断需要CPU、仓颉堆、原生分配还是资源计数证据，并确认平台、目录、磁盘和隐私边界。

2. 仅在授权后采集最小必要快照，将引用关系与业务计数对应；原生增长使用平台Profiler补证。

3. 工具不可用或无法安全保存产物时，使用运行时指标和可撤销计数降级，并明确限制。

---

## 2. 临时对象与分配速率

### 2.1 循环临时集合与字符串

常见表现包括：热点循环每轮创建临时ArrayList、String或格式化结果，分配量和GC频率明显增加。

问题代码：

```cangjie
func render(values: Array<Int64>): String {
    var result = ""
    for (value in values) {
        result = result + "${value},"
    }
    return result
}
```

问题说明：`String`不可变，循环拼接会产生多代中间字符串。对象最终可回收不等于分配成本不存在。

修正代码：

```cangjie
func render(values: Array<Int64>): String {
    let builder = StringBuilder()
    for (value in values) {
        builder.append("${value},")
    }
    return builder.toString()
}
```

#### 诊断与修复

1. 同时记录调用次数、分配量、GC和延迟，确认问题是分配速率而不是长期持有。

2. 删除无业务意义的临时量或使用`StringBuilder`；DT验证内容、顺序、Unicode和异常路径。

3. 临时对象数量小且不在热点时，不为了零分配牺牲可读性。

### 2.2 重复转换、clone与多份副本

常见表现包括：同一文本或集合反复`toArray()`、`toRuneArray()`、`clone()`，多份表示在同一生命周期长期共存。

问题代码：

```cangjie
func inspect(text: String): Int64 {
    let bytes = text.toArray()
    let runes = text.toRuneArray()
    return bytes.size + runes.size
}
```

问题说明：字节和Rune语义不同，两次转换都会物化新数组；如果只需要字符数量，无需同时保存两份数据。

修正代码：

```cangjie
func countRunes(text: String): Int64 {
    var count: Int64 = 0
    for (_ in text.runes()) {
        count++
    }
    return count
}
```

#### 诊断与修复

1. 记录副本大小、创建次数、所有权和存活范围，确认调用方实际需要哪种表示。

2. 按需迭代或只保留一种表示；DT覆盖ASCII、中文、组合字符和空文本。

3. 调用方确实同时需要字节协议和字符语义时，不删除必要副本；应缩短其共同存活时间。

### 2.3 对象池与过度复用

常见表现包括：为减少分配建立无界对象池，峰值后大量大缓冲长期留在池中，常驻内存反而上升。

问题代码：

```cangjie
import std.collection.*

let pool = ArrayList<Array<UInt8>>()

func recycle(buffer: Array<UInt8>) {
    pool.add(buffer)
}
```

问题说明：无界对象池会长期强引用原本短生命周期的对象；一次峰值即可永久扩大池容量并保留字节数组。

修正代码：

```cangjie
import std.collection.*

const MAX_POOL_SIZE: Int64 = 16
const MAX_BUFFER_SIZE: Int64 = 65536
let pool = ArrayList<Array<UInt8>>(MAX_POOL_SIZE)

func recycle(buffer: Array<UInt8>) {
    if (pool.size < MAX_POOL_SIZE && buffer.size <= MAX_BUFFER_SIZE) {
        pool.add(buffer)
    }
}
```

#### 诊断与修复

1. 记录命中率、池条目数、缓冲大小分布、峰值后稳态和同步成本。

2. 只保留高复用、尺寸有界的对象，超大对象直接离开作用域；DT覆盖达到上限和大小交替。

3. 没有分配热点或池命中率低时，删除对象池通常比增加复杂策略更合适。

---

## 3. 集合、缓冲与容量

### 3.1 无界集合与队列

常见表现包括：ArrayList、HashMap或待处理队列随请求和轮次单调增长，GC后条目仍然存在。

问题代码：

```cangjie
import std.collection.*

let history = ArrayList<String>()

func record(value: String) {
    history.add(value)
}
```

问题说明：GC只能回收不可达对象；仍被全局集合持有的元素不会因为调用GC而消失。

修正代码：

```cangjie
import std.collection.*

const MAX_HISTORY: Int64 = 1000
let history = ArrayList<String>(MAX_HISTORY)

func record(value: String) {
    if (history.size == MAX_HISTORY) {
        history.remove(at: 0)
    }
    history.add(value)
}
```

#### 诊断与修复

1. 记录每轮`size`、新增和删除数量、业务上限以及元素大小，而不是只看RSS。

2. 按业务定义容量、消费或生命周期清理；DT覆盖达到上限、异常和并发访问。

3. 数据确实需要永久保存时，不用内存集合承担持久化职责；应设计外部存储。

### 3.2 clear、容量与RSS高水位

常见表现包括：`clear()`后`size`为零但`capacity`、allocated或RSS仍高，一次峰值后长期不降。

问题代码：

```cangjie
import std.collection.*

let buffer = ArrayList<UInt8>()

func reset() {
    buffer.clear()
}
```

问题说明：`clear()`移除逻辑元素，但容器容量、运行时堆区和物理页可能保留供复用。

修正代码：

```cangjie
import std.collection.*

var buffer = ArrayList<UInt8>()

func reset() {
    if (buffer.capacity > 65536) {
        buffer = ArrayList<UInt8>()
    } else {
        buffer.clear()
    }
}
```

#### 诊断与修复

1. 同时记录`size`、`capacity`、下一轮分配、`getAllocatedHeapSize()`、平台含义正确的`getUsedHeapSize()`和峰值输入。

2. 常态容量合理时复用，峰值远高于常态时替换实例；以多轮常态负载验证不继续增长。

3. size和容量已经有界且复用有收益时，不仅为追求RSS立即下降频繁重建。

### 3.3 缓冲复用、旧数据与共享所有权

常见表现包括：共享缓冲跨请求复用，旧数据、旧对象引用或最大容量被下一轮继续持有，并发访问产生竞态。

问题代码：

```cangjie
import std.collection.*

let shared = ArrayList<Array<UInt8>>()

func process(batch: Array<UInt8>) {
    shared.add(batch)
    consume(shared)
}
```

问题说明：全局缓冲把每轮输入都变成长期可达对象，也没有清晰的线程所有权。

修正代码：

```cangjie
import std.collection.*

func process(batch: Array<UInt8>) {
    let local = ArrayList<Array<UInt8>>(1)
    local.add(batch)
    consume(local)
}
```

#### 诊断与修复

1. 记录缓冲创建、清空、逃逸、线程和异常路径，检查旧引用是否仍在集合中。

2. 默认使用局部所有权；确需复用时在每轮可靠清空并设置容量上限，DT覆盖异常和跨线程访问。

3. 复用会引入共享可变状态而分配证据不足时，不建立全局缓冲。

---

## 4. 缓存与有界状态

### 4.1 容量、过期与淘汰

常见表现包括：缓存键空间随用户、请求或版本持续增加，没有容量、TTL、淘汰和失效规则。

问题代码：

```cangjie
import std.collection.*

let cache = HashMap<String, String>()

func remember(key: String, value: String) {
    cache.add(key, value)
}
```

问题说明：HashMap只是容器，不是完整缓存策略；仍被缓存强引用的值不会被GC回收。

修正代码：

```cangjie
import std.collection.*

const MAX_CACHE_SIZE: Int64 = 1024
let cache = HashMap<String, String>(MAX_CACHE_SIZE)

func remember(key: String, value: String) {
    if (cache.size >= MAX_CACHE_SIZE && !cache.contains(key)) {
        cache.clear()
    }
    cache.add(key, value)
}
```

#### 诊断与修复

1. 记录键数量、命中率、淘汰率、条目大小、版本和业务保留期限。

2. 示例的整表清空只是最小有界方案；实际按业务选择TTL、LRU、分代或显式失效，并测试异常路径。

3. 无法定义陈旧结果和失效条件时，不跨请求缓存。

### 4.2 低命中缓存与键持有

常见表现包括：缓存命中率很低，唯一键不断增加，计算本身却很便宜；优化后堆占用和GC压力更高。

问题代码：

```cangjie
import std.collection.*

let normalized = HashMap<String, String>()

func normalizeOnce(key: String): String {
    match (normalized.get(key)) {
        case Some(value) => value
        case None =>
            let value = key.trimAscii()
            normalized.add(key, value)
            value
    }
}
```

问题说明：若每个key只出现一次，缓存同时持有原字符串和结果，却几乎没有命中收益。

修正代码：

```cangjie
func normalizeOnce(key: String): String {
    return key.trimAscii()
}
```

#### 诊断与修复

1. 记录不同键数、总调用数、命中率、单次计算成本和条目大小。

2. 命中收益不足时删除缓存，或只在请求内复用；用相同负载比较内存和延迟。

3. 不因“缓存通常更快”保留没有证据的长期状态。

### 4.3 WeakRef不是缓存策略

常见表现包括：为修复无界缓存直接把值换成WeakRef，却没有容量、过期、失效或`None`处理。

问题代码：

```cangjie
import std.collection.*
import std.ref.*

class Data {}
let cache = HashMap<String, WeakRef<Data>>()

func put(key: String, value: Data) {
    cache.add(key, WeakRef<Data>(value, DEFERRED))
}
```

问题说明：WeakRef不阻止值被GC，但不会删除缓存键，也不定义淘汰顺序；`value`随时可能返回`None`。

修正代码：

```cangjie
func get(key: String): ?Data {
    match (cache.get(key)) {
        case Some(reference) =>
            match (reference.value) {
                case Some(value) => Some(value)
                case None =>
                    cache.remove(key)
                    None
            }
        case None => None
    }
}
```

#### 诊断与修复

1. 记录键数量、其他强引用、对象回收后行为和重建成本，区分可丢缓存与必须保留数据。

2. 先建立容量和失效策略；仅对可重建的class使用WeakRef，并覆盖`Some`和`None`。

3. 值是struct/enum、不可重建或调用方不能处理`None`时，不使用WeakRef。

---

## 5. 大对象、复制与流式处理

### 5.1 整体读入与分块处理

常见表现包括：按预计文件大小一次性分配大数组并整体读入，峰值内存随输入线性扩大。

问题代码：

```cangjie
import std.fs.*

func processFile(path: Path, expectedSize: Int64) {
    let data = Array<Byte>(expectedSize, repeat: 0)
    try (file = File(path, Read)) {
        file.read(data)
    }
    process(data)
}
```

问题说明：大数组在处理完成前持续存活，`read`还可能只填充部分缓冲；不可信长度可能造成巨大预分配。

修正代码：

```cangjie
import std.fs.*

func processFile(path: Path) {
    try (file = File(path, Read)) {
        let buffer = Array<Byte>(65536, repeat: 0)
        while (true) {
            let count = file.read(buffer)
            if (count == 0) { break }
            processChunk(buffer, count)
        }
    }
}
```

#### 诊断与修复

1. 记录输入大小、峰值、实际读取量和同时存活的副本，确认全量物化是主要来源。

2. 采用固定上限分块并只消费实际读取字节；DT覆盖空文件、短块、大文件和读取异常。

3. 算法必须随机访问完整数据时，明确采用完整数据策略，并评估索引、映射或外部存储方案。

### 5.2 无界批次与背压

常见表现包括：生产速度持续高于消费速度，待处理批次或消息队列不断增长，最终耗尽内存。

问题代码：

```cangjie
import std.collection.*

let pending = ArrayList<Array<UInt8>>()

func submit(value: Array<UInt8>) {
    pending.add(value)
}
```

问题说明：没有容量、拒绝、阻塞或降级策略时，队列把流量峰值全部转化为内存持有。

修正代码：

```cangjie
import std.collection.concurrent.*

const MAX_PENDING: Int64 = 256
let pending = ArrayBlockingQueue<Array<UInt8>>(MAX_PENDING)

func submit(value: Array<UInt8>): Bool {
    return pending.tryAdd(value)
}

func consumeNext(): Array<UInt8> {
    return pending.remove()
}
```

#### 诊断与修复

1. 记录生产率、消费率、队列长度、单项大小、等待时间和拒绝数量。

2. 优先使用标准库固定容量阻塞队列，同时定义阻塞、超时或拒绝语义；消费者通过 `remove()` 出队后队列才能恢复。压力DT覆盖队满、恢复和异常消费者。

3. 不能丢数据时，不静默返回false；应阻塞、持久化或向上游传播压力。

### 5.3 多种数据表示同时存活

常见表现包括：同一内容同时保留String、Byte数组、Rune数组和序列化结果，峰值由多份副本叠加。

问题代码：

```cangjie
class ParsedText {
    let raw: String
    let bytes: Array<Byte>
    let runes: Array<Rune>

    init(raw: String) {
        this.raw = raw
        this.bytes = raw.toArray()
        this.runes = raw.toRuneArray()
    }
}
```

问题说明：对象生命周期内永久保存三种表示，即使大部分调用只使用其中一种。

修正代码：

```cangjie
class ParsedText {
    let raw: String

    init(raw: String) { this.raw = raw }
    func bytes(): Array<Byte> { raw.toArray() }
    func runes(): Iterator<Rune> { raw.runes() }
}
```

#### 诊断与修复

1. 记录各表示大小、访问频率和共同存活时间，确认长期缓存是否有命中收益。

2. 保留权威表示，其他表示按需产生并尽快释放；DT验证Unicode和编码语义。

3. 转换非常频繁且成本明确时，可以有界缓存一种派生表示，但要计入对象总大小。

---

## 6. 对象图、全局变量与引用关系

### 6.1 全局变量、静态成员与单例持有

常见表现包括：请求已经结束，但对象仍由全局ArrayList、静态HashMap或单例管理器持有。

仓颉顶层作用域中的 `let`/`var` 是全局变量，不在顶层写 `static let` 或 `static var`；`static` 用于 class/struct 的静态成员，并通过所属类型访问。现场若只说“static 集合”，先确认它是真实类型成员还是顶层全局变量，修复示例必须保留实际所有者，不能把二者混写。

问题代码：

```cangjie
import std.collection.*

class RequestContext { let payload: Array<UInt8>; init(payload: Array<UInt8>) { this.payload = payload } }
let contexts = ArrayList<RequestContext>()

func finish(context: RequestContext) {
    contexts.add(context)
}
```

问题说明：全局集合持有的强引用会让对象继续满足可达性；请求结束后再加入集合会延长整个payload生命周期。

修正代码：

```cangjie
func finish(context: RequestContext) {
    recordSummary(context.payload.size)
}
```

#### 诊断与修复

1. 从堆引用关系寻找全局变量、静态成员或单例形成的长期强引用，并记录条目添加与移除计数。

2. 只保存必要摘要或在生命周期结束移除对象；多轮DT验证请求数增长时持有对象有界。

3. 对象确实承担长期业务状态时，不删除必要引用；应定义容量和持久化策略。

### 6.2 注册表、父子关系与反向引用

常见表现包括：管理器保存会话，会话又引用管理器或监听器；会话关闭后注册表条目仍存在。

问题代码：

```cangjie
import std.collection.*

let sessions = HashMap<String, Session>()

func open(id: String): Session {
    let session = Session(id)
    sessions.add(id, session)
    return session
}
```

问题说明：注册表对Session的强引用独立于局部变量；关闭对象不会自动从HashMap移除。

修正代码：

```cangjie
func close(id: String) {
    match (sessions.remove(id)) {
        case Some(session) => session.close()
        case None => ()
    }
}
```

#### 诊断与修复

1. 记录注册、关闭、移除和重复关闭数量，检查父子及管理器反向引用。

2. 让生命周期结束与注册表移除对称，并使关闭幂等；DT覆盖正常、异常和取消。

3. 注册表承担历史查询时，不直接删除；保存轻量历史记录而不是完整活动对象。

### 6.3 引用环与可达性误判

常见表现包括：看到父子对象互相引用就断定泄漏，或者只断开环的一条边却忽略全局变量仍在长期持有对象。

问题代码：

```cangjie
import std.collection.*

class Node { var peer: ?Node = None }
let roots = ArrayList<Node>()

func createCycle() {
    let left = Node()
    let right = Node()
    left.peer = right
    right.peer = left
    roots.add(left)
}
```

问题说明：不可达引用环可以被GC回收；这里真正的持有路径是全局变量`roots`中的强引用，不是环本身。

修正代码：

```cangjie
func releaseCycles() {
    roots.clear()
}
```

#### 诊断与修复

1. 使用引用关系区分对象间的环和从长期强引用到对象的可达链。

2. 移除不必要的长期强引用，并以WeakRef或对象计数观察回收；DT覆盖仍有业务引用和只剩弱引用两种情况。

3. 没有堆引用证据时，不因为存在双向引用就引入WeakRef或手工拆环。

---

## 7. 闭包、回调与订阅生命周期

### 7.1 闭包捕获与最小持有集

常见表现包括：长期保存的闭包只使用一个字段，却捕获整个请求、页面或大payload对象。

问题代码：

```cangjie
class Context { let id: String; let payload: Array<UInt8>; init(id: String, payload: Array<UInt8>) { this.id = id; this.payload = payload } }

func makeCallback(context: Context): () -> Unit {
    return { => println(context.id) }
}
```

问题说明：闭包捕获`context`引用，使未使用的payload也随回调继续存活。

修正代码：

```cangjie
func makeCallback(context: Context): () -> Unit {
    let id = context.id
    return { => println(id) }
}
```

#### 诊断与修复

1. 列出闭包捕获变量、保存位置和逃逸时间，并用引用路径确认真实持有。

2. 只捕获必要的不可变字段；DT验证回调结果和上下文更新后的语义。

3. 回调必须观察对象后续状态时，不改成快照；应缩短回调注册生命周期。

### 7.2 回调注册与对称注销

常见表现包括：每次任务启动或刷新都注册回调，订阅者数量只增不减，闭包继续持有已结束会话。

问题代码：

```cangjie
import std.collection.*

let callbacks = ArrayList<() -> Unit>()

func subscribe(callback: () -> Unit) {
    callbacks.add(callback)
}
```

问题说明：注册表对闭包的强引用会延长捕获对象生命周期，GC不会替业务自动注销仍可达回调。

修正代码：

```cangjie
import std.collection.*

let callbacks = HashMap<Int64, () -> Unit>()
var nextCallbackId: Int64 = 0

func subscribe(callback: () -> Unit): Int64 {
    let token = nextCallbackId
    nextCallbackId++
    callbacks.add(token, callback)
    return token
}

func unsubscribe(token: Int64) {
    callbacks.remove(token)
}
```

#### 诊断与修复

1. 记录注册、注销、回调所有者和正常/异常/取消离开路径。

2. 注册返回注销句柄，在所有结束路径对称注销；DT覆盖重复注册和幂等注销语义。

3. 示例使用单线程注册表；并发订阅时还必须用锁或并发映射保护令牌分配和增删。所有权未知时先确认真实清理 API。

### 7.3 定时器、周期任务与长期回调

常见表现包括：每次刷新创建新回调或定时任务，旧任务未取消，旧业务上下文及其缓存仍被捕获。

问题代码：

```cangjie
import std.collection.*

class RefreshContext {
    func refresh(): Unit {}
}

let refreshJobs = ArrayList<Future<Unit>>()

func scheduleRefresh(context: RefreshContext) {
    refreshJobs.add(spawn { => context.refresh() })
}
```

问题说明：活动任务的闭包会持有 `RefreshContext`，全局列表又会永久保存 `Future`。任务完成后 `Future` 是否仍保留闭包对象图属于运行时实现细节，必须用堆引用关系确认；列表本身持续增长则已经是确定的问题。

修正代码：

```cangjie
func scheduleRefresh(context: RefreshContext): Future<Unit> {
    return spawn { => context.refresh() }
}
```

#### 诊断与修复

1. 记录调度、完成、取消和列表移除计数，确认同一业务上下文是否存在多个活动任务。

2. 不使用全局历史列表，向任务所有者返回 `Future`；所有者只保存当前必要任务，在完成后丢弃句柄，关闭时请求取消并等待。DT 覆盖重复调度、取消和异常。

3. 周期工作必须后台化时，不改成全局阻塞；应使用有界任务管理器和稳定生命周期句柄。

---

## 8. Future、线程与ThreadLocal

### 8.1 已完成Future仍被保存

常见表现包括：任务已完成，但Future历史列表持续增长，Future及其可观察结果或异常状态仍由业务集合持有。

问题代码：

```cangjie
import std.collection.*

let futures = ArrayList<Future<Int64>>()

func start(): Unit {
    futures.add(spawn { => calculate() })
}
```

问题说明：任务完成不等于保存Future的业务集合自动移除元素。

修正代码：

```cangjie
func start(): Future<Int64> {
    return spawn { => calculate() }
}

func finish(future: Future<Int64>): Int64 {
    return future.get()
}
```

#### 诊断与修复

1. 记录spawn、完成、Future add/remove和任务结束后集合大小。

2. 返回Future给明确的所有者，在汇合点消费结果后丢弃句柄；需要集合管理时，完成后必须移除。DT覆盖正常、异常和取消。

3. Future确实承担有界结果缓存时，不删除必要持有；应明确容量和过期。

### 8.2 ThreadLocal跨请求持有

常见表现包括：线程局部变量保存大数组或请求上下文，处理结束后没有设置`None`，后续空闲线程继续持有对象。

问题代码：

```cangjie
let local = ThreadLocal<Array<UInt8>>()

func handle(payload: Array<UInt8>) {
    local.set(Some(payload))
    process(payload)
}
```

问题说明：ThreadLocal值的生命周期跟随线程，而不是一次请求；线程长期存在时请求对象也可能长期可达。

修正代码：

```cangjie
func handle(payload: Array<UInt8>) {
    local.set(Some(payload))
    try {
        process(payload)
    } finally {
        local.set(None)
    }
}
```

#### 诊断与修复

1. 记录ThreadLocal set/clear、线程数量、请求完成和异常路径。

2. 在最小作用域结束时设置`None`；DT覆盖正常、异常和线程复用。

3. ThreadLocal是有界长期状态时，不每次清空；避免保存整个请求对象。

### 8.3 任务队列、取消与背压

常见表现包括：提交任务快于处理速度，队列和捕获数据增长；取消后待处理任务仍保留在队列。

问题代码：

```cangjie
import std.collection.*

let jobs = ArrayList<() -> Unit>()

func submit(job: () -> Unit) {
    jobs.add(job)
}
```

问题说明：无界任务列表同时持有闭包和捕获对象，没有消费、取消或关闭策略。

修正代码：

```cangjie
import std.collection.concurrent.*
import std.sync.*

const MAX_JOBS: Int64 = 128
let jobs = ArrayBlockingQueue<Job>(MAX_JOBS)

class Job {
    let task: () -> Unit
    let cancelled = AtomicBool(false)

    init(task: () -> Unit) { this.task = task }
    func cancel() { cancelled.store(true) }
    func run() {
        if (!cancelled.load()) { task() }
    }
}

func submit(task: () -> Unit): ?Job {
    let job = Job(task)
    return if (jobs.tryAdd(job)) { Some(job) } else { None }
}

func runNext() {
    jobs.remove().run()
}
```

#### 诊断与修复

1. 记录提交、开始、完成、取消、队列长度和单任务捕获大小。

2. 使用标准库固定容量阻塞队列，返回稳定Job句柄；取消先标记，消费者出队后跳过任务并释放其捕获对象。压力DT覆盖队满、取消、消费者异常和停止接收新任务。

3. 任务不能丢弃时，不静默返回`None`；应改用阻塞`add()`、持久化或向上游传播背压。示例没有定义服务关闭协议，生产实现必须单独定义停止接收和消费者退出信号。

---

## 9. Resource与句柄

本节聚焦长期资源持有、句柄计数增长，以及仓颉堆与平台资源走势不一致的问题。单个函数在异常或提前返回路径漏关时，优先缩小资源作用域并用 try-with-resources 保证关闭，再验证句柄计数达到稳态。

### 9.1 Resource所有权转移与关闭责任

常见表现包括：函数返回打开的 `File`、流或其他 `Resource`，却没有声明调用方取得关闭责任；不同调用点因此遗漏关闭或重复关闭。

问题代码：

```cangjie
import std.fs.*

func openInput(path: Path): File {
    File(path, Read)
}

func firstReadSize(path: Path): Int64 {
    let file = openInput(path)
    let buffer = Array<Byte>(1, repeat: 0)
    return file.read(buffer)
}
```

问题说明：`openInput` 把仍然打开的 `File` 返回给调用方，但 API 没有表达所有权转移；`firstReadSize` 提前返回时也没有关闭它。GC 不负责平台句柄，跨层所有权含糊会使遗漏关闭和 double close 同时存在。

修正代码：

```cangjie
import std.fs.*

func firstReadSize(path: Path): Int64 {
    let buffer = Array<Byte>(1, repeat: 0)
    var count: Int64 = 0
    try (file = File(path, Read)) {
        count = file.read(buffer)
    }
    return count
}
```

#### 诊断与修复

1. 为每个返回 `Resource` 的 API 标出创建者、当前所有者、关闭者和所有正常/异常离开路径；同时记录创建、关闭和重复关闭次数。

2. 资源只在单个操作内使用时，不跨 API 返回，直接放入最小 try-with-resources 作用域；DT 验证正常、异常和提前返回均只关闭一次。

3. 业务确实需要把资源交给调用方时，API 必须明确调用方取得关闭责任，调用方再建立 try-with-resources；不得为了消除持有而提前关闭仍需使用的资源。

### 9.2 句柄数与仓颉堆分离

常见表现包括：仓颉堆相对稳定，但文件描述符、线程或映射数量持续增长，最终出现资源耗尽。

问题代码：

```cangjie
import std.collection.*
import std.fs.*

let openFiles = ArrayList<File>()

func open(path: Path) {
    openFiles.add(File(path, Read))
}
```

问题说明：平台句柄是独立资源；只看堆大小会漏掉未关闭File及其系统资源。

修正代码：

```cangjie
func use(path: Path) {
    try (file = File(path, Read)) {
        consume(file)
    }
}
```

#### 诊断与修复

1. 对照仓颉堆、RSS、句柄、线程和映射计数，定位哪类资源单调增长。

2. 修复创建/关闭不对称并以多轮负载验证资源数有界。

3. 平台无法读取某类计数时，使用应用级创建/关闭计数降级，不把堆稳定当作无泄漏证明。

---

## 10. CFFI与原生内存

### 10.1 malloc、CString与异常路径释放

常见表现包括：RSS增长而仓颉堆稳定，`LibC.malloc`、`mallocCString`和`free`不对称，异常路径跳过释放。

问题代码：

```cangjie
func useNative() {
    unsafe {
        let pointer = LibC.malloc<Int32>()
        nativeWork(pointer)
        LibC.free(pointer)
    }
}
```

问题说明：nativeWork异常或提前离开时不会执行free；仓颉GC不负责任意C分配。

修正代码：

```cangjie
func useNative() {
    let pointer = unsafe { LibC.malloc<Int32>() }
    try (resource = pointer.asResource()) {
        unsafe { nativeWork(resource.value) }
    }
}
```

#### 诊断与修复

1. 为每个原生分配/释放点记录数量、大小、分配器和异常路径，同时比较仓颉堆与RSS。

2. 所有权不转移时使用CPointerResource/CStringResource；DT覆盖正常、异常和重复调用。

3. API未声明释放者或分配器可能不匹配时，不擅自调用LibC.free。

### 10.2 借用、转移与跨分配器

常见表现包括：C返回借用指针后仓颉主动free，或C已经接管所有权但仓颉Resource再次释放。

问题代码：

```cangjie
foreign func borrowedName(): CString

func loadName(): String {
    unsafe {
        let value = borrowedName()
        let result = value.toString()
        LibC.free(value)
        return result
    }
}
```

问题说明：如果返回值由C库静态存储或借用，仓颉调用LibC.free会使用错误所有权甚至错误分配器。

修正代码：

```cangjie
foreign func borrowedName(): CString

func loadName(): String {
    unsafe {
        return borrowedName().toString()
    }
}
```

#### 诊断与修复

1. 为每个接口写明分配者、释放者、有效期、线程和是否转移所有权。

2. 借用数据需要长期保存时复制到仓颉拥有的值；拥有型指针使用库规定的释放器。

3. 头文件和ABI没有说明所有权时，不free，也不包装为拥有型Resource。

### 10.3 raw-data、回调与原生Profiler

常见表现包括：`acquireArrayRawData`与`releaseArrayRawData`不配对，C长期保存仓颉回调或数组指针，RSS上涨但仓颉堆稳定。

问题代码：

```cangjie
foreign func process(pointer: CPointer<Int64>, size: Int64): Unit

func send(values: Array<Int64>) {
    unsafe {
        let handle = acquireArrayRawData(values)
        process(handle.pointer, values.size)
    }
}
```

问题说明：handle没有释放；raw-data窗口期间也不应构造复杂仓颉对象。C侧不能在返回后继续使用该指针。

修正代码：

```cangjie
func send(values: Array<Int64>) {
    unsafe {
        let handle = acquireArrayRawData(values)
        process(handle.pointer, values.size)
        releaseArrayRawData(handle)
    }
}
```

#### 诊断与修复

1. 记录acquire/release、回调注册/注销、原生分配器和跨线程保存位置，并使用平台Profiler对照仓颉堆。

2. 缩短raw-data窗口并严格配对；为长期回调提供显式注销和生命周期句柄，压力测试异常与关闭。

3. 目标库、平台 Profiler 或 ABI 契约不可用时，记录验证限制，并将原生泄漏修复结论标记为待验证。

---

## 11. 工具与完成门槛

- Linux且当前版本支持时，使用`cjprof heap`检查类型占比、对象数和引用关系；macOS/Windows使用运行时指标、业务计数和平台工具降级。
- 完成时必须说明内存类别、长期强引用或所有权路径、相同负载下的有界稳态，以及未验证的平台。
- 功能、异常、资源清理、吞吐和延迟护栏必须通过。
- `clear()`、重GC、WeakRef或RSS单次下降均不能单独证明修复成功。
- 原生内存、句柄和映射不能只用仓颉堆快照判断。
