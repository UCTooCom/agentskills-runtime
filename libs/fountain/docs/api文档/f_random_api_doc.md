# f_random API Documentation

## 功能介绍

`f_random` 模块提供了强大的随机数据生成能力。它扩展了标准库的 `Random` 和 `SecureRandom`，使其支持生成指定范围的数字，还提供了用于生成各类随机字符串的 `RandomString` 类，以及用于大数据集抽样的蓄水池算法 `randomReservoir`。此外，它还提供了线程本地安全的随机实例和各种随机数迭代器。

## 接口

| 接口名 | 功能 |
| --- | --- |
| `ExtendRandom<R>` | 提供区间随机数生成能力，支持闭区间与半开区间可选。 |
| `BaseRandom<R>` | 提供布尔值、整型、浮点型及高斯分布随机数生成，以及随机数迭代器支持。 |

## 类

| 类名 | 功能 |
| --- | --- |
| `RandomString` | 提供随机字符串生成功能。 |
| `ThreadLocalRandom` | 提供线程本地安全的 `SecureRandom` 实例。 |
| `RandomIterator<R, T>` | 随机数迭代器抽象基类。 |
| `RangeRandomInt32Iterator<R>` | `Int32` 区间随机数迭代器。 |
| `RangeRandomUInt32Iterator<R>` | `UInt32` 区间随机数迭代器。 |
| `RangeRandomInt64Iterator<R>` | `Int64` 区间随机数迭代器。 |
| `RangeRandomUInt64Iterator<R>` | `UInt64` 区间随机数迭代器。 |
| `RandomBoolIterator<R>` | 布尔随机数迭代器。 |
| `RandomInt8Iterator<R>` | `Int8` 随机数迭代器。 |
| `RandomUInt8Iterator<R>` | `UInt8` 随机数迭代器。 |
| `UpperRandomInt8Iterator<R>` | `Int8` 上限区间随机数迭代器。 |
| `UpperRandomUInt8Iterator<R>` | `UInt8` 上限区间随机数迭代器。 |
| `RandomUInt8sIterator<R>` | `UInt8` 数组随机数迭代器。 |
| `RandomInt16Iterator<R>` | `Int16` 随机数迭代器。 |
| `RandomUInt16Iterator<R>` | `UInt16` 随机数迭代器。 |
| `UpperRandomInt16Iterator<R>` | `Int16` 上限区间随机数迭代器。 |
| `UpperRandomUInt16Iterator<R>` | `UInt16` 上限区间随机数迭代器。 |
| `RandomInt32Iterator<R>` | `Int32` 随机数迭代器。 |
| `RandomUInt32Iterator<R>` | `UInt32` 随机数迭代器。 |
| `UpperRandomInt32Iterator<R>` | `Int32` 上限区间随机数迭代器。 |
| `UpperRandomUInt32Iterator<R>` | `UInt32` 上限区间随机数迭代器。 |
| `RandomInt64Iterator<R>` | `Int64` 随机数迭代器。 |
| `RandomUInt64Iterator<R>` | `UInt64` 随机数迭代器。 |
| `UpperRandomInt64Iterator<R>` | `Int64` 上限区间随机数迭代器。 |
| `UpperRandomUInt64Iterator<R>` | `UInt64` 上限区间随机数迭代器。 |
| `RandomFloat16Iterator<R>` | `Float16` 随机数迭代器。 |
| `RandomFloat32Iterator<R>` | `Float32` 随机数迭代器。 |
| `RandomFloat64Iterator<R>` | `Float64` 随机数迭代器。 |
| `RandomGaussianFloat16Iterator<R>` | `Float16` 高斯随机数迭代器。 |
| `RandomGaussianFloat32Iterator<R>` | `Float32` 高斯随机数迭代器。 |
| `RandomGaussianFloat64Iterator<R>` | `Float64` 高斯随机数迭代器。 |

## 顶层函数

| 函数名 | 功能 |
| --- | --- |
| `randomReservoir<T>(...)` | 实现蓄水池抽样算法，从一个大的数据源中随机抽取指定数量的元素。 |

---

## 接口详情

### public interface ExtendRandom<R> where R <: ExtendRandom<R>

**功能：**
为随机数生成器（如 `Random`, `SecureRandom`）扩展了生成指定范围随机数的能力，支持闭区间与半开区间可选。

**方法：**

*   `func nextFloat64()`
    `func nextFloat64(): Float64`
    **功能：** 返回一个 `Float64` 类型的随机数，范围 `[0.0, 1.0)`。
    **返回：**
    *   一个 `Float64` 类型的随机数。

*   `func nextFloat32()`
    `func nextFloat32(): Float32`
    **功能：** 返回一个 `Float32` 类型的随机数，范围 `[0.0, 1.0)`。
    **返回：**
    *   一个 `Float32` 类型的随机数。

*   `func nextFloat64(min: Float64, max: Float64, closed!: Bool)`
    `func nextFloat64(min: Float64, max: Float64, closed!: Bool): Float64`
    **功能：** 在指定区间内生成 `Float64` 随机数，支持闭区间或半开区间。
    **参数：**
    *   `min: Float64` - 区间下界。
    *   `max: Float64` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `Float64` 类型的随机数。

*   `func nextFloat32(min: Float32, max: Float32, closed!: Bool)`
    `func nextFloat32(min: Float32, max: Float32, closed!: Bool): Float32`
    **功能：** 在指定区间内生成 `Float32` 随机数，支持闭区间或半开区间。
    **参数：**
    *   `min: Float32` - 区间下界。
    *   `max: Float32` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `Float32` 类型的随机数。

*   `func nextInt64(min: Int64, max: Int64, closed!: Bool)`
    `func nextInt64(min: Int64, max: Int64, closed!: Bool): Int64`
    **功能：** 在指定区间内生成 `Int64` 随机整数，支持闭区间或半开区间。
    **参数：**
    *   `min: Int64` - 区间下界。
    *   `max: Int64` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `Int64` 类型的随机整数。

*   `func nextUInt64(min: UInt64, max: UInt64, closed!: Bool)`
    `func nextUInt64(min: UInt64, max: UInt64, closed!: Bool): UInt64`
    **功能：** 在指定区间内生成 `UInt64` 随机整数，支持闭区间或半开区间。
    **参数：**
    *   `min: UInt64` - 区间下界。
    *   `max: UInt64` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `UInt64` 类型的随机整数。

*   `func nextInt32(min: Int32, max: Int32, closed!: Bool)`
    `func nextInt32(min: Int32, max: Int32, closed!: Bool): Int32`
    **功能：** 在指定区间内生成 `Int32` 随机整数，支持闭区间或半开区间。
    **参数：**
    *   `min: Int32` - 区间下界。
    *   `max: Int32` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `Int32` 类型的随机整数。

*   `func nextUInt32(min: UInt32, max: UInt32, closed!: Bool)`
    `func nextUInt32(min: UInt32, max: UInt32, closed!: Bool): UInt32`
    **功能：** 在指定区间内生成 `UInt32` 随机整数，支持闭区间或半开区间。
    **参数：**
    *   `min: UInt32` - 区间下界。
    *   `max: UInt32` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `UInt32` 类型的随机整数。

### public interface BaseRandom<R> where R <: BaseRandom<R>

**功能：**
提供布尔值、整型、浮点型及高斯分布随机数生成，以及随机数迭代器支持。

**方法：**

*   `func nextBool()`
    `func nextBool(): Bool`
    **功能：** 获取一个布尔类型的随机数。
    **返回：**
    *   一个布尔类型的随机数。

*   `func nextUInt8()`
    `func nextUInt8(): UInt8`
    **功能：** 获取一个 `UInt8` 类型的随机数。
    **返回：**
    *   一个 `UInt8` 类型的随机数。

*   `func nextUInt16()`
    `func nextUInt16(): UInt16`
    **功能：** 获取一个 `UInt16` 类型的随机数。
    **返回：**
    *   一个 `UInt16` 类型的随机数。

*   `func nextUInt32()`
    `func nextUInt32(): UInt32`
    **功能：** 获取一个 `UInt32` 类型的随机数。
    **返回：**
    *   一个 `UInt32` 类型的随机数。

*   `func nextUInt64()`
    `func nextUInt64(): UInt64`
    **功能：** 获取一个 `UInt64` 类型的随机数。
    **返回：**
    *   一个 `UInt64` 类型的随机数。

*   `func nextInt8()`
    `func nextInt8(): Int8`
    **功能：** 获取一个 `Int8` 类型的随机数。
    **返回：**
    *   一个 `Int8` 类型的随机数。

*   `func nextInt16()`
    `func nextInt16(): Int16`
    **功能：** 获取一个 `Int16` 类型的随机数。
    **返回：**
    *   一个 `Int16` 类型的随机数。

*   `func nextInt32()`
    `func nextInt32(): Int32`
    **功能：** 获取一个 `Int32` 类型的随机数。
    **返回：**
    *   一个 `Int32` 类型的随机数。

*   `func nextInt64()`
    `func nextInt64(): Int64`
    **功能：** 获取一个 `Int64` 类型的随机数。
    **返回：**
    *   一个 `Int64` 类型的随机数。

*   `func nextUInt8(max: UInt8)`
    `func nextUInt8(max: UInt8): UInt8`
    **功能：** 获取一个 `UInt8` 类型且在区间 `[0, max)` 内的随机数。
    **参数：**
    *   `max: UInt8` - 区间最大值。
    **返回：**
    *   一个 `UInt8` 类型的随机数。

*   `func nextUInt16(max: UInt16)`
    `func nextUInt16(max: UInt16): UInt16`
    **功能：** 获取一个 `UInt16` 类型且在区间 `[0, max)` 内的随机数。
    **参数：**
    *   `max: UInt16` - 区间最大值。
    **返回：**
    *   一个 `UInt16` 类型的随机数。

*   `func nextUInt32(max: UInt32)`
    `func nextUInt32(max: UInt32): UInt32`
    **功能：** 获取一个 `UInt32` 类型且在区间 `[0, max)` 内的随机数。
    **参数：**
    *   `max: UInt32` - 区间最大值。
    **返回：**
    *   一个 `UInt32` 类型的随机数。

*   `func nextUInt64(max: UInt64)`
    `func nextUInt64(max: UInt64): UInt64`
    **功能：** 获取一个 `UInt64` 类型且在区间 `[0, max)` 内的随机数。
    **参数：**
    *   `max: UInt64` - 区间最大值。
    **返回：**
    *   一个 `UInt64` 类型的随机数。

*   `func nextInt8(max: Int8)`
    `func nextInt8(max: Int8): Int8`
    **功能：** 获取一个 `Int8` 类型且在区间 `[0, max)` 内的随机数。
    **参数：**
    *   `max: Int8` - 区间最大值。
    **返回：**
    *   一个 `Int8` 类型的随机数。

*   `func nextInt16(max: Int16)`
    `func nextInt16(max: Int16): Int16`
    **功能：** 获取一个 `Int16` 类型且在区间 `[0, max)` 内的随机数。
    **参数：**
    *   `max: Int16` - 区间最大值。
    **返回：**
    *   一个 `Int16` 类型的随机数。

*   `func nextInt32(max: Int32)`
    `func nextInt32(max: Int32): Int32`
    **功能：** 获取一个 `Int32` 类型且在区间 `[0, max)` 内的随机数。
    **参数：**
    *   `max: Int32` - 区间最大值。
    **返回：**
    *   一个 `Int32` 类型的随机数。

*   `func nextInt64(max: Int64)`
    `func nextInt64(max: Int64): Int64`
    **功能：** 获取一个 `Int64` 类型且在区间 `[0, max)` 内的随机数。
    **参数：**
    *   `max: Int64` - 区间最大值。
    **返回：**
    *   一个 `Int64` 类型的随机数。

*   `func nextFloat16()`
    `func nextFloat16(): Float16`
    **功能：** 获取一个 `Float16` 类型的随机数，范围在 `[0.0, 1.0)` 之间。
    **返回：**
    *   一个 `Float16` 类型的随机数。

*   `func nextFloat32()`
    `func nextFloat32(): Float32`
    **功能：** 获取一个 `Float32` 类型的随机数，范围在 `[0.0, 1.0)` 之间。
    **返回：**
    *   一个 `Float32` 类型的随机数。

*   `func nextFloat64()`
    `func nextFloat64(): Float64`
    **功能：** 获取一个 `Float64` 类型的随机数，范围在 `[0.0, 1.0)` 之间。
    **返回：**
    *   一个 `Float64` 类型的随机数。

*   `func nextGaussianFloat16(mean!: Float16, sigma!: Float16)`
    `func nextGaussianFloat16(mean!: Float16, sigma!: Float16): Float16`
    **功能：** 获取一个 `Float16` 类型且符合均值为 `mean` 标准差为 `sigma` 的高斯分布的随机数。
    **参数：**
    *   `mean!: Float16` - 高斯分布均值。
    *   `sigma!: Float16` - 高斯分布标准差。
    **返回：**
    *   一个 `Float16` 类型的高斯随机数。

*   `func nextGaussianFloat32(mean!: Float32, sigma!: Float32)`
    `func nextGaussianFloat32(mean!: Float32, sigma!: Float32): Float32`
    **功能：** 获取一个 `Float32` 类型且符合均值为 `mean` 标准差为 `sigma` 的高斯分布的随机数。
    **参数：**
    *   `mean!: Float32` - 高斯分布均值。
    *   `sigma!: Float32` - 高斯分布标准差。
    **返回：**
    *   一个 `Float32` 类型的高斯随机数。

*   `func nextGaussianFloat64(mean!: Float64, sigma!: Float64)`
    `func nextGaussianFloat64(mean!: Float64, sigma!: Float64): Float64`
    **功能：** 获取一个 `Float64` 类型且符合均值为 `mean` 标准差为 `sigma` 的高斯分布的随机数。
    **参数：**
    *   `mean!: Float64` - 高斯分布均值。
    *   `sigma!: Float64` - 高斯分布标准差。
    **返回：**
    *   一个 `Float64` 类型的高斯随机数。

*   `func randomInt64(min: Int64, max: Int64, closed!: Bool)`
    `func randomInt64(min: Int64, max: Int64, closed!: Bool): Iterator<Int64>`
    **功能：** 返回一个生成指定区间 `Int64` 随机数的迭代器。
    **参数：**
    *   `min: Int64` - 区间下界。
    *   `max: Int64` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `Iterator<Int64>` 类型的迭代器。

*   `func randomUInt64(min: UInt64, max: UInt64, closed!: Bool)`
    `func randomUInt64(min: UInt64, max: UInt64, closed!: Bool): Iterator<UInt64>`
    **功能：** 返回一个生成指定区间 `UInt64` 随机数的迭代器。
    **参数：**
    *   `min: UInt64` - 区间下界。
    *   `max: UInt64` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `Iterator<UInt64>` 类型的迭代器。

*   `func randomInt32(min: Int32, max: Int32, closed!: Bool)`
    `func randomInt32(min: Int32, max: Int32, closed!: Bool): Iterator<Int32>`
    **功能：** 返回一个生成指定区间 `Int32` 随机数的迭代器。
    **参数：**
    *   `min: Int32` - 区间下界。
    *   `max: Int32` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `Iterator<Int32>` 类型的迭代器。

*   `func randomUInt32(min: UInt32, max: UInt32, closed!: Bool)`
    `func randomUInt32(min: UInt32, max: UInt32, closed!: Bool): Iterator<UInt32>`
    **功能：** 返回一个生成指定区间 `UInt32` 随机数的迭代器。
    **参数：**
    *   `min: UInt32` - 区间下界。
    *   `max: UInt32` - 区间上界。
    *   `closed!: Bool` - `true` 生成闭区间 `[min,max]`，`false` 生成半开区间 `[min,max)`。
    **返回：**
    *   一个 `Iterator<UInt32>` 类型的迭代器。

*   `func nextBytes(length: Int64)`
    `func nextBytes(length: Int64): Array<Byte>`
    **功能：** 生成指定长度的随机字节数组。
    **参数：**
    *   `length: Int64` - 数组长度。
    **返回：**
    *   一个 `Array<Byte>` 类型的随机字节数组。

*   `func nextUInt8s(array: Array<UInt8>)`
    `func nextUInt8s(array: Array<UInt8>): Array<UInt8>`
    **功能：** 生成随机数替换入参数组中的每个元素。
    **参数：**
    *   `array: Array<UInt8>` - 传入一个 `UInt8` 数组。
    **返回：**
    *   返回替换后的 `Array<UInt8>`。

*   `func randomGaussianFloat16Stream(mean!: Float16, sigma!: Float16)`
    `func randomGaussianFloat16Stream(mean!: Float16, sigma!: Float16): Iterator<Float16>`
    **功能：** 获取 `Float16` 高斯随机数迭代器。
    **参数：**
    *   `mean!: Float16` - 高斯分布均值。
    *   `sigma!: Float16` - 高斯分布标准差。
    **返回：**
    *   一个 `Iterator<Float16>` 类型的迭代器。

*   `func randomGaussianFloat32Stream(mean!: Float32, sigma!: Float32)`
    `func randomGaussianFloat32Stream(mean!: Float32, sigma!: Float32): Iterator<Float32>`
    **功能：** 获取 `Float32` 高斯随机数迭代器。
    **参数：**
    *   `mean!: Float32` - 高斯分布均值。
    *   `sigma!: Float32` - 高斯分布标准差。
    **返回：**
    *   一个 `Iterator<Float32>` 类型的迭代器。

*   `func randomGaussianFloat64Stream(mean!: Float64, sigma!: Float64)`
    `func randomGaussianFloat64Stream(mean!: Float64, sigma!: Float64): Iterator<Float64>`
    **功能：** 获取 `Float64` 高斯随机数迭代器。
    **参数：**
    *   `mean!: Float64` - 高斯分布均值。
    *   `sigma!: Float64` - 高斯分布标准差。
    **返回：**
    *   一个 `Iterator<Float64>` 类型的迭代器。

---

## 类详情

### public class RandomString

**功能：**
提供随机字符串生成功能。

**构造函数：**

*   `public init(rand!: SecureRandom = ThreadLocalRandom.current)`
    **功能：** 构造一个使用默认线程本地随机实例的 `RandomString`。
    **参数：**
    *   `rand!: SecureRandom` - 用于生成随机数的 `SecureRandom` 实例，默认为 `ThreadLocalRandom.current`。

*   `public init(priv: Bool)`
    **功能：** 构造一个使用指定安全级别的 `SecureRandom` 的 `RandomString`。
    **参数：**
    *   `priv: Bool` - `true` 表示使用更安全的随机源，`false` 表示使用默认随机源。

**方法（仅列 public）：**

*   `func randomAscii(count: Int64)`
    `func randomAscii(count: Int64): String`
    **功能：** 生成指定长度的 ASCII 字符串（0–127）。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机 ASCII 字符串。

*   `func randomAscii(min: Int64, max: Int64)`
    `func randomAscii(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机 ASCII 字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机 ASCII 字符串。

*   `func random(count: Int64, source: Array<Rune>)`
    `func random(count: Int64, source: Array<Rune>): String`
    **功能：** 从给定字符数组中随机抽取指定长度字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    *   `source: Array<Rune>` - 字符源数组。
    **返回：**
    *   一个 `String` 类型的随机字符串。

*   `func random(count: Int64, source: String)`
    `func random(count: Int64, source: String): String`
    **功能：** 从给定字符串中随机抽取指定长度字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    *   `source: String` - 字符源字符串。
    **返回：**
    *   一个 `String` 类型的随机字符串。

*   `func random(min: Int64, max: Int64, source: String)`
    `func random(min: Int64, max: Int64, source: String): String`
    **功能：** 从给定字符串中随机抽取长度在 `[min,max]` 区间的字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    *   `source: String` - 字符源字符串。
    **返回：**
    *   一个 `String` 类型的随机字符串。

*   `func randomLowerLetters(count: Int64)`
    `func randomLowerLetters(count: Int64): String`
    **功能：** 生成指定长度的小写字母字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机小写字母字符串。

*   `func randomLowerLetters(min: Int64, max: Int64)`
    `func randomLowerLetters(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机小写字母字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机小写字母字符串。

*   `func randomUpperLetters(count: Int64)`
    `func randomUpperLetters(count: Int64): String`
    **功能：** 生成指定长度的大写字母字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机大写字母字符串。

*   `func randomUpperLetters(min: Int64, max: Int64)`
    `func randomUpperLetters(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机大写字母字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机大写字母字符串。

*   `func randomAllLetters(count: Int64)`
    `func randomAllLetters(count: Int64): String`
    **功能：** 生成指定长度的字母字符串（大小写）。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机字母字符串。

*   `func randomAllLetters(min: Int64, max: Int64)`
    `func randomAllLetters(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机字母字符串（大小写）。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机字母字符串。

*   `func randomNumbers(count: Int64)`
    `func randomNumbers(count: Int64): String`
    **功能：** 生成指定长度的数字字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机数字字符串。

*   `func randomNumbers(min: Int64, max: Int64)`
    `func randomNumbers(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机数字字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机数字字符串。

*   `func randomLowerLettersNumbers(count: Int64)`
    `func randomLowerLettersNumbers(count: Int64): String`
    **功能：** 生成指定长度的小写字母+数字字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机小写字母+数字字符串。

*   `func randomLowerLettersNumbers(min: Int64, max: Int64)`
    `func randomLowerLettersNumbers(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机小写字母+数字字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机小写字母+数字字符串。

*   `func randomUpperLettersNumbers(count: Int64)`
    `func randomUpperLettersNumbers(count: Int64): String`
    **功能：** 生成指定长度的大写字母+数字字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机大写字母+数字字符串。

*   `func randomUpperLettersNumbers(min: Int64, max: Int64)`
    `func randomUpperLettersNumbers(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机大写字母+数字字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机大写字母+数字字符串。

*   `func randomLettersNumbers(count: Int64)`
    `func randomLettersNumbers(count: Int64): String`
    **功能：** 生成指定长度的字母（大小写）+数字字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机字母+数字字符串。

*   `func randomLettersNumbers(min: Int64, max: Int64)`
    `func randomLettersNumbers(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机字母+数字字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机字母+数字字符串。

*   `func randomPrintableAsciis(count: Int64)`
    `func randomPrintableAsciis(count: Int64): String`
    **功能：** 生成指定长度的可打印 ASCII 字符串。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机可打印 ASCII 字符串。

*   `func randomPrintableAsciis(min: Int64, max: Int64)`
    `func randomPrintableAsciis(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机可打印 ASCII 字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机可打印 ASCII 字符串。

*   `func randomAllChars(count: Int64)`
    `func randomAllChars(count: Int64): String`
    **功能：** 生成指定长度的 Unicode 字符串（跳过代理区）。
    **参数：**
    *   `count: Int64` - 字符串长度。
    **返回：**
    *   一个 `String` 类型的随机 Unicode 字符串。

*   `func randomAllChars(min: Int64, max: Int64)`
    `func randomAllChars(min: Int64, max: Int64): String`
    **功能：** 生成长度在 `[min,max]` 区间的随机 Unicode 字符串。
    **参数：**
    *   `min: Int64` - 最小长度。
    *   `max: Int64` - 最大长度。
    **返回：**
    *   一个 `String` 类型的随机 Unicode 字符串。

### public class ThreadLocalRandom

**功能：**
提供线程本地安全的 `SecureRandom` 实例。

**属性：**

*   `current` (getter)
    `public static prop current: SecureRandom`
    **功能：** 返回当前线程的 `SecureRandom` 实例；若未创建则自动初始化。
    **返回：**
    *   一个 `SecureRandom` 实例。

### public abstract class RandomIterator<R, T>

**功能：**
随机数迭代器抽象基类，用于产生无限的随机数流。

**构造函数：**

*   `protected init(rand: R)`
    **功能：** 接收随机实例，供子类使用。
    **参数：**
    *   `rand: R` - 用于生成随机数的随机实例。

### public class RangeRandomInt32Iterator<R>

**功能：**
提供 `Int32` 区间随机数迭代。

**构造函数：**

*   `public init(rand: R, minValue: Int32, maxValue: Int32, closed: Bool)`
    **功能：** 指定随机实例、区间边界及是否闭区间。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `minValue: Int32` - 区间下界。
    *   `maxValue: Int32` - 区间上界。
    *   `closed: Bool` - 是否为闭区间。

**方法：**

*   `func next()`
    `public func next(): Option<Int32>`
    **功能：** 返回下一个区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int32>` 类型的随机数。

### public class RangeRandomUInt32Iterator<R>

**功能：**
提供 `UInt32` 区间随机数迭代。

**构造函数：**

*   `public init(rand: R, minValue: UInt32, maxValue: UInt32, closed: Bool)`
    **功能：** 指定随机实例、区间边界及是否闭区间。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `minValue: UInt32` - 区间下界。
    *   `maxValue: UInt32` - 区间上界。
    *   `closed: Bool` - 是否为闭区间。

**方法：**

*   `func next()`
    `public func next(): Option<UInt32>`
    **功能：** 返回下一个区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt32>` 类型的随机数。

### public class RangeRandomInt64Iterator<R>

**功能：**
提供 `Int64` 区间随机数迭代。

**构造函数：**

*   `public init(rand: R, minValue: Int64, maxValue: Int64, closed: Bool)`
    **功能：** 指定随机实例、区间边界及是否闭区间。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `minValue: Int64` - 区间下界。
    *   `maxValue: Int64` - 区间上界。
    *   `closed: Bool` - 是否为闭区间。

**方法：**

*   `func next()`
    `public func next(): Option<Int64>`
    **功能：** 返回下一个区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int64>` 类型的随机数。

### public class RangeRandomUInt64Iterator<R>

**功能：**
提供 `UInt64` 区间随机数迭代。

**构造函数：**

*   `public init(rand: R, minValue: UInt64, maxValue: UInt64, closed: Bool)`
    **功能：** 指定随机实例、区间边界及是否闭区间。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `minValue: UInt64` - 区间下界。
    *   `maxValue: UInt64` - 区间上界。
    *   `closed: Bool` - 是否为闭区间。

**方法：**

*   `func next()`
    `public func next(): Option<UInt64>`
    **功能：** 返回下一个区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt64>` 类型的随机数。

### public class RandomBoolIterator<R>

**功能：**
提供布尔随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<Bool>`
    **功能：** 返回下一个布尔随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Bool>` 类型的随机数。

### public class RandomInt8Iterator<R>

**功能：**
提供 `Int8` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<Int8>`
    **功能：** 返回下一个 `Int8` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int8>` 类型的随机数。

### public class RandomUInt8Iterator<R>

**功能：**
提供 `UInt8` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<UInt8>`
    **功能：** 返回下一个 `UInt8` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt8>` 类型的随机数。

### public class UpperRandomInt8Iterator<R>

**功能：**
提供 `Int8` 上限区间随机数迭代。

**构造函数：**

*   `public init(rand: R, upper: Int8)`
    **功能：** 指定随机实例和上限值。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `upper: Int8` - 上限值。

**方法：**

*   `func next()`
    `public func next(): Option<Int8>`
    **功能：** 返回下一个 `[0, upper)` 区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int8>` 类型的随机数。

### public class UpperRandomUInt8Iterator<R>

**功能：**
提供 `UInt8` 上限区间随机数迭代。

**构造函数：**

*   `public init(rand: R, upper: UInt8)`
    **功能：** 指定随机实例和上限值。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `upper: UInt8` - 上限值。

**方法：**

*   `func next()`
    `public func next(): Option<UInt8>`
    **功能：** 返回下一个 `[0, upper)` 区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt8>` 类型的随机数。

### public class RandomUInt8sIterator<R>

**功能：**
提供 `UInt8` 数组随机数迭代。

**构造函数：**

*   `public init(rand: R, size: Int64)`
    **功能：** 指定随机实例和数组大小。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `size: Int64` - 数组大小。

**方法：**

*   `func next()`
    `public func next(): Option<Array<UInt8>>`
    **功能：** 返回下一个随机 `UInt8` 数组；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Array<UInt8>>` 类型的随机数组。

### public class RandomInt16Iterator<R>

**功能：**
提供 `Int16` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<Int16>`
    **功能：** 返回下一个 `Int16` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int16>` 类型的随机数。

### public class RandomUInt16Iterator<R>

**功能：**
提供 `UInt16` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<UInt16>`
    **功能：** 返回下一个 `UInt16` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt16>` 类型的随机数。

### public class UpperRandomInt16Iterator<R>

**功能：**
提供 `Int16` 上限区间随机数迭代。

**构造函数：**

*   `public init(rand: R, upper: Int16)`
    **功能：** 指定随机实例和上限值。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `upper: Int16` - 上限值。

**方法：**

*   `func next()`
    `public func next(): Option<Int16>`
    **功能：** 返回下一个 `[0, upper)` 区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int16>` 类型的随机数。

### public class UpperRandomUInt16Iterator<R>

**功能：**
提供 `UInt16` 上限区间随机数迭代。

**构造函数：**

*   `public init(rand: R, upper: UInt16)`
    **功能：** 指定随机实例和上限值。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `upper: UInt16` - 上限值。

**方法：**

*   `func next()`
    `public func next(): Option<UInt16>`
    **功能：** 返回下一个 `[0, upper)` 区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt16>` 类型的随机数。

### public class RandomInt32Iterator<R>

**功能：**
提供 `Int32` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<Int32>`
    **功能：** 返回下一个 `Int32` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int32>` 类型的随机数。

### public class RandomUInt32Iterator<R>

**功能：**
提供 `UInt32` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<UInt32>`
    **功能：** 返回下一个 `UInt32` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt32>` 类型的随机数。

### public class UpperRandomInt32Iterator<R>

**功能：**
提供 `Int32` 上限区间随机数迭代。

**构造函数：**

*   `public init(rand: R, upper: Int32)`
    **功能：** 指定随机实例和上限值。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `upper: Int32` - 上限值。

**方法：**

*   `func next()`
    `public func next(): Option<Int32>`
    **功能：** 返回下一个 `[0, upper)` 区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int32>` 类型的随机数。

### public class UpperRandomUInt32Iterator<R>

**功能：**
提供 `UInt32` 上限区间随机数迭代。

**构造函数：**

*   `public init(rand: R, upper: UInt32)`
    **功能：** 指定随机实例和上限值。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `upper: UInt32` - 上限值。

**方法：**

*   `func next()`
    `public func next(): Option<UInt32>`
    **功能：** 返回下一个 `[0, upper)` 区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt32>` 类型的随机数。

### public class RandomInt64Iterator<R>

**功能：**
提供 `Int64` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<Int64>`
    **功能：** 返回下一个 `Int64` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int64>` 类型的随机数。

### public class RandomUInt64Iterator<R>

**功能：**
提供 `UInt64` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<UInt64>`
    **功能：** 返回下一个 `UInt64` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt64>` 类型的随机数。

### public class UpperRandomInt64Iterator<R>

**功能：**
提供 `Int64` 上限区间随机数迭代。

**构造函数：**

*   `public init(rand: R, upper: Int64)`
    **功能：** 指定随机实例和上限值。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `upper: Int64` - 上限值。

**方法：**

*   `func next()`
    `public func next(): Option<Int64>`
    **功能：** 返回下一个 `[0, upper)` 区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Int64>` 类型的随机数。

### public class UpperRandomUInt64Iterator<R>

**功能：**
提供 `UInt64` 上限区间随机数迭代。

**构造函数：**

*   `public init(rand: R, upper: UInt64)`
    **功能：** 指定随机实例和上限值。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `upper: UInt64` - 上限值。

**方法：**

*   `func next()`
    `public func next(): Option<UInt64>`
    **功能：** 返回下一个 `[0, upper)` 区间随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<UInt64>` 类型的随机数。

### public class RandomFloat16Iterator<R>

**功能：**
提供 `Float16` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<Float16>`
    **功能：** 返回下一个 `Float16` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Float16>` 类型的随机数。

### public class RandomFloat32Iterator<R>

**功能：**
提供 `Float32` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<Float32>`
    **功能：** 返回下一个 `Float32` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Float32>` 类型的随机数。

### public class RandomFloat64Iterator<R>

**功能：**
提供 `Float64` 随机数迭代。

**构造函数：**

*   `public init(rand: R)`
    **功能：** 指定随机实例。
    **参数：**
    *   `rand: R` - 随机实例。

**方法：**

*   `func next()`
    `public func next(): Option<Float64>`
    **功能：** 返回下一个 `Float64` 随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Float64>` 类型的随机数。

### public class RandomGaussianFloat16Iterator<R>

**功能：**
提供 `Float16` 高斯随机数迭代。

**构造函数：**

*   `public init(rand: R, mean!: Float16, sigma!: Float16)`
    **功能：** 指定随机实例、均值和标准差。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `mean!: Float16` - 高斯分布均值。
    *   `sigma!: Float16` - 高斯分布标准差。

**方法：**

*   `func next()`
    `public func next(): Option<Float16>`
    **功能：** 返回下一个 `Float16` 高斯随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Float16>` 类型的随机数。

### public class RandomGaussianFloat32Iterator<R>

**功能：**
提供 `Float32` 高斯随机数迭代。

**构造函数：**

*   `public init(rand: R, mean!: Float32, sigma!: Float32)`
    **功能：** 指定随机实例、均值和标准差。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `mean!: Float32` - 高斯分布均值。
    *   `sigma!: Float32` - 高斯分布标准差。

**方法：**

*   `func next()`
    `public func next(): Option<Float32>`
    **功能：** 返回下一个 `Float32` 高斯随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Float32>` 类型的随机数。

### public class RandomGaussianFloat64Iterator<R>

**功能：**
提供 `Float64` 高斯随机数迭代。

**构造函数：**

*   `public init(rand: R, mean!: Float64, sigma!: Float64)`
    **功能：** 指定随机实例、均值和标准差。
    **参数：**
    *   `rand: R` - 随机实例。
    *   `mean!: Float64` - 高斯分布均值。
    *   `sigma!: Float64` - 高斯分布标准差。

**方法：**

*   `func next()`
    `public func next(): Option<Float64>`
    **功能：** 返回下一个 `Float64` 高斯随机数；无更多元素时返回 `None`。
    **返回：**
    *   一个 `Option<Float64>` 类型的随机数。

---

## 顶层函数详情

### public func randomReservoir<T>

**功能：**
实现蓄水池抽样算法。当数据量大到无法全部加载到内存时，此函数可以公平地从数据流中随机抽取 `count` 个元素。

**方法签名：**

*   `func randomReservoir<T>(count: Int64, source: Iterable<T>, priv!: Bool = false): ArrayList<T>`
    **参数：**
    *   `count: Int64` - 要抽取的样本数量。
    *   `source: Iterable<T>` - 数据源，必须是可迭代的（`Iterable<T>`）。
    *   `priv!: Bool` - 是否使用更高安全性的随机源，默认为 `false`。
    **返回：**
    *   一个包含 `count` 个随机样本的 `ArrayList<T>`。

# 快速上手

以下是一个 `f_random` 模块的最小可行示例：

```cj
package user.controller

import fountain.mvc.*
import fountain.mvc.macros.*
import f_random.*

/**
 * 一个用于演示 f_random 模块功能的最小可行示例。
 */
@Controller
public class RandomDemoController {

    /**
     * 定义一个 /random-demo 接口。
     * 每次调用，它都会演示 f_random 的核心功能并以纯文本形式返回结果。
     */
    @GetMapping[path:"/random-demo", produces:'text/plain;charset=UTF-8']
    @IgnoreSecurity
    public func demonstrateRandom(): String {
        // 1. 获取一个线程安全的随机数生成器
        let rand = ThreadLocalRandom.current

        // 2. 生成一个 [100, 200] 范围内的随机整数 (包含边界)
        let randomNumber = rand.nextInt64(100, 200, closed: true)

        // 3. 初始化随机字符串生成器
        let stringGenerator = RandomString()
        // 生成一个长度为 12 的、由大小写字母和数字组成的随机字符串
        let randomString = stringGenerator.randomLettersNumbers(12)

        // 4. 使用蓄水池抽样从一个集合中随机抽取样本
        let dataSource = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        let samples = randomReservoir<Int64>(5, dataSource)

        // 5. 格式化并返回结果字符串
        let result = '''
        f_random 模块使用示例:

        1. 指定范围的随机数 [100, 200]:
           ${randomNumber}

        2. 12位字母和数字组成的随机字符串:
           ${randomString}

        3. 从15个元素中进行蓄水池抽样 (抽取5个):
           ${samples}
        '''
        return result
    }
}
```
