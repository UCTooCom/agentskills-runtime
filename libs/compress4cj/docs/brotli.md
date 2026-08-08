# Brotli 使用手册

`import compress4cj.brotli.*`

## 概述

当前 Brotli 实现包含：
- 基于非压缩 metablock 的编码器（生成合法 brotli 格式流）
- 完整 RFC 7932 解码器（支持标准 brotli 压缩流）

编码器输出可被标准 brotli 解码器读取，解码器可处理标准 brotli 压缩器生成的流。

## 公开函数

### brotliAvailable()

检查 Brotli 是否可用。

```cangjie
let ok = brotliAvailable()   // 始终返回 true
```

### brotliCompress(data, quality?)

压缩数据。使用非压缩 metablock 编码，输出合法 brotli 格式流但无实际压缩比。

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| data | `Array<UInt8>` | — | 待压缩数据 |
| quality | `Int64` | `6` | 压缩质量（当前未使用） |

```cangjie
// 基本压缩
let compressed = brotliCompress(origData)

// 空数据
let emptyResult = brotliCompress([])    // 返回 []
```

### brotliDecompress(data)

解压 brotli 数据。

```cangjie
// 解压 brotliCompress 的输出
let back = brotliDecompress(compressed)

// 解压标准 brotli 流
let standardBrotli: Array<UInt8> = [/* 来自外部工具压缩 */]
let decompressed = brotliDecompress(standardBrotli)

// 空数据
let empty = brotliDecompress([])  // 返回 []

// 非法 brotli 流抛异常
try {
    let _ = brotliDecompress([0x00, 0x01, 0x02])
} catch (e: Exception) {
    // Zlib4cjException: "Brotli 解压失败: ..."
}
```

### brotliRawEncode(input)

直接编码为非压缩 metablock 格式。`brotliCompress` 内部使用此函数。

```cangjie
let encoded = brotliRawEncode(data)    // 返回非压缩 brotli 流
```

## 完整示例

### 压缩/解压 Roundtrip

```cangjie
import compress4cj.brotli.*

let data = strToBytes("Hello, Brotli!")

let compressed = brotliCompress(data)
// compressed.size > 0

let decompressed = brotliDecompress(compressed)
// decompressed == data
```

### 各类数据测试

```cangjie
// 大数据
let largeData = Array<UInt8>(1024, {i => UInt8(i % 256)})
let enc = brotliCompress(largeData)
let dec = brotliDecompress(enc)
// dec.size == 1024

// 重复数据
let repeated = Array<UInt8>(500, repeat: 0x41)
let enc2 = brotliCompress(repeated)
let dec2 = brotliDecompress(enc2)
// 全部 roundtrip 一致
```

## 错误处理

```cangjie
import compress4cj.brotli.*
import compress4cj.common.Zlib4cjException

try {
    let result = brotliDecompress(badData)
} catch (e: Zlib4cjException) {
    println(e.message)
    // "Brotli 解压失败: ..."
}
```

## 限制

- 当前编码器仅支持非压缩 metablock，无实际压缩比
- 对于需要压缩比的场景，建议使用 zlib（DEFLATE/gzip）替代
- 解码器是完整的，可以处理标准 brotli 压缩流
