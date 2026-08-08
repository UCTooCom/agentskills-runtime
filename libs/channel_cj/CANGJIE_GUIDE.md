# 仓颉编程语言AI Agent编程指导

## 仓颉编程语言标准库概述

仓颉编程语言标准库（std）是安装仓颉 SDK 时默认自带的库。标准库预先定义了一组函数、类、结构体等，旨在提供常用的功能和工具，以便开发者能够更快速、更高效地编写程序。

### 使用指导

在仓颉编程语言中，标准库包含了若干包（package），而包是编译的最小单元。每个包可以单独输出 AST（Abstract Syntax Trees，抽象语法树）文件、静态库文件、动态库文件等产物。包可以定义子包，从而构成树形结构。没有父包的包称为 root 包，root 包及其子包（包括子包的子包）构成的整棵树称为模块（module）。模块的名称与 root 包相同，是开发者发布的最小单元。

#### 包的导入规则

可以导入某个包中的一个顶层声明或定义，语法如下：

```
import fullPackageName.itemName
```

其中 `fullPackageName` 为完整路径包名，`itemName` 为声明的名字，例如：

```
import std.collection.ArrayList
```

如果要导入的多个 `itemName` 同属于一个 `fullPackageName`，可以使用：

```
import fullPackageName.{itemName[, itemName]*}
```

例如：

```
import std.collection.{ArrayList, HashMap}
```

还可以将 `fullPackageName` 包中所有 public 修饰的顶层声明或定义全部导入，语法如下：

```
import fullPackageName.*
```

例如：

```
import std.collection.*
```

### 包列表

`std` 含若干包，提供丰富的基础功能：

| 包名 | 功能 |
| --- | --- |
| core | 包是标准库的核心包，提供了适用仓颉语言编程最基本的一些 API 能力。 |
| argopt | 包提供从命令行参数字符串解析出参数名和参数值的相关能力。 |
| ast | 包主要包含了仓颉源码的语法解析器和仓颉语法树节点，提供语法解析函数。 |
| binary | 包提供了基础数据类型和二进制字节数组的不同端序转换接口，以及端序反转接口。 |
| collection | 包提供了常见数据结构的高效实现、相关抽象的接口的定义以及在集合类型中常用的函数功能。 |
| collection.concurrent | 包提供了并发安全的集合类型实现。 |
| console | 包提供和标准输入、标准输出、标准错误进行交互的方法。 |
| convert | 包提供从字符串转到特定类型的 Convert 系列函数以及提供格式化能力，主要为将仓颉类型实例转换为格式化字符串。 |
| crypto.cipher | 包提供对称加解密通用接口。 |
| crypto.digest | 包提供常用摘要算法的通用接口，包括 MD5、SHA1、SHA224、SHA256、SHA384、SHA512、HMAC、SM3。 |
| database.sql | 包提供仓颉访问数据库的接口。 |
| deriving | 包提供一组宏来自动生成接口实现。 |
| env | 包提供当前进程的相关信息与功能，包括环境变量、命令行参数、标准流、退出程序。 |
| fs | 包提供对文件、文件夹、路径、文件元数据信息的一些操作函数。 |
| io | 包提供程序与外部设备进行数据交换的能力。 |
| math | 包提供常见的数学运算，常数定义，浮点数处理等功能。 |
| math.numeric | 包对基础类型可表达范围之外提供扩展能力。 |
| net | 包提供常见的网络通信功能。 |
| objectpool | 包提供了对象缓存和复用的功能。 |
| overflow | 包提供了溢出处理相关能力。 |
| posix | 包封装 POSIX 系统调用，提供跨平台的系统操作接口。 |
| process | 包主要提供 Process 进程操作接口，主要包括进程创建、标准流获取、进程等待、进程信息查询等。 |
| random | 包提供生成伪随机数的能力。 |
| reflect | 包提供了反射功能，使得程序在运行时能够获取到各种实例的类型信息，并进行各种读写和调用操作。 |
| regex | 包使用正则表达式分析处理文本的能力（支持 UTF-8 编码的 Unicode 字符串），支持查找、分割、替换、验证等功能。 |
| runtime | 包的作用是与程序的运行时环境进行交互，提供了一系列函数和变量，用于控制、管理和监视程序的执行。 |
| sort | 包提供数组类型的排序函数。 |
| sync | 包提供并发编程相关的能力。 |
| time | 包提供了与时间相关的类型，包括日期时间、时间间隔、单调时间和时区等，并提供了计算和比较的功能。 |
| unicode | 包提供了按 Unicode 编码标准处理字符的能力。 |
| unittest | 包用于编写仓颉项目单元测试代码，提供包括代码编写、运行和调测在内的基本功能。 |
| unittest.mock | 包提供仓颉单元测试的 mock 框架，提供 API 用于创建和配置 mock 对象，这些 mock 对象与真实对象拥有签名一致的 API。 |
| unittest.testmacro | 为单元测试框架提供了用户所需的宏。 |
| unittest.mock.mockmacro | 为 mock 框架提供了用户所需的宏。 |
| unittest.common | 为单元测试框架提供了打印所需的类型和一些通用方法。 |
| unittest.diff | 为单元测试框架提供了打印差异对比信息所需的 API。 |
| unittest.prop_test | 为单元测试框架提供了参数化测试所需的类型和一些通用方法。 |

## 字符串处理

- 获取字符数组应使用`String.toRuneArray()`而非`String.toArray()`，`String[n]`等效于`String.toArray()[n]`，`String[n..m]`等效于`String.toArray()[n..m]`
- 字符串长度获取应使用`String.toRuneArray().size`而非`String.size`
- `UInt8`等效于`Byte`,`Array<UInt8>`等效于`Array<Byte>`
- 字节数组转字符串为`String.fromUtf8(Array<UInt8>)`，字符数组转字符串为`String(Array<Rune>)`
- 字符串切割应使用`String(String.toRuneArray()[n..m])`
- 字符串拼接应改为`String(String.toRuneArray()[n..m]) + String`
- `String.toAsciiLower()`将该字符串中所有 Ascii 大写字母转化为 Ascii 小写字母
- `String.toAsciiUpper()`将该字符串中所有 Ascii 小写字母转化为 Ascii 大写字母
- `String.toAsciiTitle()`该函数只转换 Ascii 英文字符，当该英文字符是字符串中第一个字符或者该字符的前一个字符不是英文字符，则该字符大写，其他英文字符小写

## 并发集合

### std.collection.concurrent

collection.concurrent 包提供了并发安全的集合类型实现。

本包实现了以下几种并发安全的集合类型：

- **ArrayBlockingQueue**：以数组的形式实现的具有固定大小的有界队列。
- **ConcurrentHashMap**：线程安全的哈希表实现，支持高并发的读写操作。
- **ConcurrentLinkedQueue**：一种线程安全的队列数据结构，特点是在添加元素时，如果当前的尾部 Block 已满，那么会创建一个新的 Block，而不是阻塞等待。这样可以保证在多线程环境下，队列的操作不会因为阻塞而导致线程的阻塞，从而提高了程序的性能。
- **LinkedBlockingQueue**：一种阻塞队列，它支持在队列为空时阻塞获取元素的操作，以及在队列已满时阻塞添加元素的操作。

#### API 列表

##### 类型别名

| 类型别名 | 功能 |
| --- | --- |
| BlockingQueue<E> (deprecated) | LinkedBlockingQueue 的别名。 |
| NonBlockingQueue<E> (deprecated) | ConcurrentLinkedQueue 的别名。 |

##### 接口

| 接口名 | 功能 |
| --- | --- |
| ConcurrentMap<K, V> | 保证线程安全和操作原子性的 Map 接口定义。 |

##### 类

| 类名 | 功能 |
| --- | --- |
| ArrayBlockingQueue<E> | 基于数组实现的 Blocking Queue 数据结构及相关操作函数。 |
| ConcurrentHashMapIterator<K, V> where K <: Hashable & Equatable<K> | 此类主要实现 Concurrent HashMap 的迭代器功能。 |
| ConcurrentHashMap<K, V> where K <: Hashable & Equatable<K> | 此类用于实现并发场景下线程安全的哈希表 ConcurrentHashMap 数据结构及相关操作函数。 |
| ConcurrentLinkedQueue<E> | 提供一个线程安全的队列，可以在多线程环境下安全地进行元素的添加和删除操作。 |
| LinkedBlockingQueue<E> | 实现是带阻塞机制并支持用户指定容量上界的并发队列。 |

## 同步

### std.sync

sync 包提供并发编程相关的能力。

随着越来越多的计算机开始使用多核处理器，要充分发挥多核的优势，并发编程也变得越来越重要。

不同编程语言会以不同的方式实现线程。一些编程语言通过调用操作系统 API 来创建线程，意味着每个语言线程对应一个操作系统线程，一般称之为 1:1 的线程模型；也有一些编程语言提供特殊的线程实现，允许多个语言线程在不同数量的操作系统线程的上下文中切换执行，这种也被称为 M:N 的线程模型，即 M 个语言线程在 N 个操作系统线程上调度执行，其中 M 和 N 不一定相等。

仓颉编程语言希望给开发者提供一个友好、高效、统一的并发编程界面，让开发者无需关心操作系统线程、用户态线程等概念上的差异，同时屏蔽底层实现细节，因此我们只提供一个仓颉线程的概念。仓颉线程采用的是 M:N 线程模型的实现，因此本质上它是一种用户态的轻量级线程，支持抢占，且相比操作系统线程内存资源占用更小。

当开发者希望并发执行某一段代码时，只需创建一个仓颉线程即可。

要创建一个新的仓颉线程，可以使用关键字 spawn 并传递一个无形参的 lambda 表达式，该 lambda 表达式即为我们想在新线程中执行的代码。

示例:

通过 spawn 关键字创建一个仓颉线程：
```cj
main () {
    spawn {
        // 在新线程中执行
        println("Thread: ${Thread.currentThread.id}")
    }
    // 在主线程中执行
    println("Thread: ${Thread.currentThread.id}")
    sleep(Duration.second)
    0
}
```
可能的运行结果：
```
Thread: 1
Thread: 2
```
sync 包主要提供了不同类型的原子操作，可重入互斥锁及其接口，利用共享变量的线程同步机制以及定时器的功能。

原子操作提供了包括整数类型、Bool 类型和引用类型的原子操作。

其中整数类型包括：Int8、Int16、Int32、Int64、UInt8、UInt16、UInt32、UInt64。

整数类型的原子操作支持基本的读(load)写(store)、交换(swap/compareAndSwap)以及算术运算(fetchAdd/fetchSub)等操作，需要注意的是：

交换操作和算术操作的返回值是修改前的值。

compareAndSwap 是判断当前原子变量的值是否等于指定值，如果等于，则使用另一值替换；否则不替换。

Bool 类型和引用类型的原子操作只提供读写和交换操作，需要注意的是：

引用类型原子操作只对引用类型有效。

互斥锁 Lock 在使用的时候存在诸多不便，比如稍不注意会忘了解锁，或者在持有互斥锁的情况下抛出异常不能自动释放持有的锁等。因此，仓颉编程语言提供 synchronized 关键字，搭配 Lock 一起使用，来解决类似的问题。

通过在 synchronized 后面加上一个互斥锁实例，对其后面修饰的代码块进行保护，可以使得任意时刻最多只有一个线程可以执行被保护的代码：

一个线程在进入 synchronized 修饰的代码块之前，会自动获取 Lock 实例对应的锁，如果无法获取锁，则当前线程被阻塞。
一个线程在退出 synchronized 修饰的代码块之前（包括在代码块中使用 break、continue、return、throw 等控制转移表达式），会自动释放该 Lock 实例的锁。
示例:

在每个 for 循环的线程进入 synchronized 代码块前，会自动获取 mtx 实例对应的锁，在退出代码块前，会释放 mtx 实例对应的锁。
```cj
import std.sync.Mutex

main () {
    let mtx = Mutex()
    let cnt = Box<Int64>(0)

    for (_ in 0..5) {
        spawn {
            synchronized(mtx) {
                cnt.value ++
                println("count: ${cnt.value}")
            }
        }
    }
    sleep(Duration.second)
    0
}
```
可能的运行结果：
```
count: 1
count: 2
count: 3
count: 4
count: 5
```

#### API 列表

##### 常量&变量

| 常量&变量名 | 功能 |
| --- | --- |
| DefaultMemoryOrder (deprecated) | 默认内存顺序，详见枚举 MemoryOrder (deprecated)。 |

##### 接口

| 接口名 | 功能 |
| --- | --- |
| Condition | 提供使线程阻塞并等待来自另一个线程的信号以恢复执行的功能的接口。 |
| IReentrantMutex (deprecated) | 提供可重入互斥锁接口。 |
| Lock | 提供实现可重入互斥锁的接口。 |
| UniqueLock | 提供实现独占锁的接口。 |

##### 类

| 类名 | 功能 |
| --- | --- |
| AtomicBool | 提供 Bool 类型的原子操作相关函数。 |
| AtomicInt16 | 提供 Int16 类型的原子操作相关函数。 |
| AtomicInt32 | 提供 Int32 类型的原子操作相关函数。 |
| AtomicInt64 | 提供 Int64 类型的原子操作相关函数。 |
| AtomicInt8 | 提供 Int8 类型的原子操作相关函数。 |
| AtomicOptionReference | 提供引用类型原子操作相关函数。 |
| AtomicReference | 引用类型原子操作相关函数。 |
| AtomicUInt16 | 提供 UInt16 类型的原子操作相关函数。 |
| AtomicUInt32 | 提供 UInt32 类型的原子操作相关函数。 |
| AtomicUInt64 | 提供 UInt64 类型的原子操作相关函数。 |
| AtomicUInt8 | 提供 UInt8 类型的原子操作相关函数。 |
| Barrier | 提供协调多个线程一起执行到某一个程序点的功能。 |
| Monitor (deprecated) | 提供使线程阻塞并等待来自另一个线程的信号以恢复执行的功能。 |
| MultiConditionMonitor (deprecated) | 提供对同一个互斥锁绑定多个条件变量的功能。 |
| Mutex | 提供可重入锁相关功能。 |
| ReadWriteLock | 提供可重入读写锁相关功能。 |
| ReentrantMutex (deprecated) | 提供可重入锁相关功能。 |
| ReentrantReadMutex (deprecated) | 提供可重入读写锁中的读锁类型。 |
| ReentrantReadWriteMutex (deprecated) | 提供可重入读写锁相关功能。 |
| ReentrantWriteMutex (deprecated) | 提供可重入读写锁中的写锁类型。 |
| Semaphore | 提供信号量相关功能。 |
| SyncCounter | 提供倒数计数器功能。 |
| Timer | 提供定时器功能。 |

##### 枚举

| 枚举类型 | 功能 |
| --- | --- |
| MemoryOrder (deprecated) | 内存顺序类型枚举。 |
| ReadWriteMutexMode (deprecated) | 读写锁公平模式枚举。 |
| CatchupStyle | 重复性任务定时器需要使用的追平策略枚举。 |

##### 结构体

| 结构体 | 功能 |
| --- | --- |
| ConditionID (deprecated) | 用于表示互斥锁的条件变量，详见 MultiConditionMonitor。 |

##### 异常类

| 异常类名 | 功能 |
| --- | --- |
| IllegalSynchronizationStateException | 此类为非法同步状态异常。 |

## 其他语法

- `match` 的 `case` 后不能接`{}`, `case`后直接写多行列表式而不需要`{}`
- 单元测试使用`@Test`、`@TestCase`注解组合
- 基准测试使用`@Test`、`@Bench`注解组合
- 可以使用`if-let`表达式简化代码，`if (let Some(a) <- (fun() as Option<Int64>)) {}`、`if (let Some(a) <- b && a + b > 3) {}`、`if (let m <- 0..generateSomeInt()) {}`、`if (let Some(e) <- a && let Some(f) <- d) {}`、`if (let Some(f) <- d && f > 3) {}`、`if (let Some(_) <- a || let Some(_) <- d) {}`、`if (let Some(_) <- a || g > 1) {}`
- `Option<T>` 不支持 `==` 比较，使用 `.isSome()` / `.isNone()` 配合模式匹配
- 枚举必须显式实现 `==` 和 `!=`；若用作 `HashMap` 键，还需实现 `Hashable & Equatable`
- `panic()` 可能不可用，改用 `throw Exception(...)`。
- Lambda 语法: `{key, value => body}` — 无类型标注、无括号
- 命名参数: 构造函数参数需加 `!` 后缀才能以命名参数方式调用

## Agent工具/技能

- 使用 [`CangjieSkills`](https://gitcode.com/Cangjie-SIG/CangjieSkills) 技能和 [`cangjie-docs`](https://atomgit.com/Cangjie-SIG/cangjie-docs-mcp) MCP 进行 API/文档查找——不要猜测 API
- 在 `cangjie-mem` 没有的直接在文档里查找，不要猜api和语法
- 在提示语法错误时重新使用 `cangjie-mem` 加载语言级记忆
- 在上下文压缩后，如果没有仓颉语法相关的，需要马上使用 `cangjie_mem_list` 工具加载所有仓颉语言级记忆

## 工具链

- 使用`cjfmt`工具格式化文件，使用命令行操作`cjfmt [option] file [option] file`，获取帮助信息`cjfmt -h`，文件格式化`cjfmt -f`，文件夹格式化`cjfmt -d`，格式化配置文件`cjfmt -c`
- 使用`cjlint`进行静态检查，获取帮助信息`cjlint -h`，检查指定目录`cjlint -f`

## 任务指南

- **不要考虑时间，不要简化算法，不要简化测试，按最佳效果进行实现**
- 在实现功能总结后，需记录到`cangjie-mem`项目级记忆里
- 新功能、新特性一定要写单元测试，原则上每个公共函数`public func`有一个或多个单元测试
- 不要在项目外创建仓颉单文件测试，非cjpm项目没法导入当前项目
- 新功能需要做好，且有单元测试后提交, 以仓颉单元测试为主
- 测试发现的新问题需要解决，且要添加新用例到仓颉的单元测试里
- 测试出现语法问题不通过时，可以使用`cangjie_docs`相关工具在手册或lib std查找解决方法
- 需格式化所有`*.cj`文件和项目配置文件
