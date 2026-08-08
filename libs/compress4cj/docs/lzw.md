# LZW 使用手册

`import compress4cj.lzw.*`

## 概述

LZW（Lempel-Ziv-Welch）是一种无损压缩算法，适用于 GIF、TIFF、PDF 等格式。本实现支持可变宽度编码（9~12 位），包含 Clear 和 EOI 控制码。

## 公开类型与函数

### LzwOrder 枚举

```cangjie
public enum LzwOrder {
    LSB     // 最低有效位优先（GIF 格式）
    MSB     // 最高有效位优先（TIFF / PDF）
}
```

### lzwCompress(data, order?, litWidth?)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| data | `Array<UInt8>` | — | 待压缩数据 |
| order | `LzwOrder` | `LSB` | 比特顺序 |
| litWidth | `Int64` | `8` | 字面量位宽（2~8） |

```cangjie
// 默认 LSB 顺序，位宽 8
let compressed = lzwCompress(data)

// MSB 顺序（TIFF/PDF）
let msbCompressed = lzwCompress(data, order: LzwOrder.MSB, litWidth: 8)

// 小位宽（数据范围有限时）
let smallData: Array<UInt8> = [0x00, 0x01, 0x02, 0x03]
let compressed = lzwCompress(smallData, litWidth: 2)
```

### lzwDecompress(data, order?, litWidth?)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| data | `Array<UInt8>` | — | LZW 压缩数据 |
| order | `LzwOrder` | `LSB` | 比特顺序 |
| litWidth | `Int64` | `8` | 字面量位宽（必须与压缩时一致） |

```cangjie
// 解压
let decompressed = lzwDecompress(compressed)

// MSB 顺序解压
let msbBack = lzwDecompress(msbCompressed, order: LzwOrder.MSB, litWidth: 8)
```

## 参数限制

- `litWidth` 取值范围：**2 ~ 8**
- `litWidth` 决定了可表达的最大字面量值：`2^litWidth - 1`
- 数据中出现超过 `2^litWidth - 1` 的字节值会抛异常

```cangjie
// 位宽 7 → 最大字面量 127
try {
    let _ = lzwCompress([0xFF], litWidth: 7)  // 0xFF > 127
} catch (e: Zlib4cjException) {
    // 字节值超出位宽限制
}

// 有效使用
let data: Array<UInt8> = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
let compressed4 = lzwCompress(data, litWidth: 4)
let back = lzwDecompress(compressed4, litWidth: 4)
```

## 完整示例

### 基本 Roundtrip

```cangjie
import compress4cj.lzw.*

// LSB 顺序（GIF）
let data: Array<UInt8> = [0x41, 0x42, 0x43]  // "ABC"
let compressed = lzwCompress(data)
let decompressed = lzwDecompress(compressed)
// decompressed == data
```

### MSB 顺序（TIFF/PDF）

```cangjie
let data: Array<UInt8> = [0x48, 0x65, 0x6C, 0x6C, 0x6F]
let compressed = lzwCompress(data, order: LzwOrder.MSB, litWidth: 8)
let decompressed = lzwDecompress(compressed, order: LzwOrder.MSB, litWidth: 8)
// roundtrip 一致
```

### 大数据压缩

```cangjie
// 256 字节递增序列
let largeData = Array<UInt8>(256, {i => UInt8(i % 256)})
let compressed = lzwCompress(largeData)
let back = lzwDecompress(compressed)
// back == largeData

// 1024 字节重复模式
let repeated = Array<UInt8>(1024, {i => UInt8(i % 256)})
let enc = lzwCompress(repeated)
let dec = lzwDecompress(enc)
// dec == repeated
```

### 各类序列

```cangjie
// 全相同数据
let allSame = Array<UInt8>(100, repeat: 0x42)
let enc1 = lzwCompress(allSame)
let dec1 = lzwDecompress(enc1)

// 交替数据
let alternating = Array<UInt8>(100, {i =>
    if (i % 2 == 0) { UInt8(0x41) } else { UInt8(0x42) }
})
let enc2 = lzwCompress(alternating)
let dec2 = lzwDecompress(enc2)

// 重复模式
let pattern = Array<UInt8>(500, {i => UInt8((i % 10) + 0x30)})
let enc3 = lzwCompress(pattern)
let dec3 = lzwDecompress(enc3)
```

### 错误处理

```cangjie
import compress4cj.lzw.*
import compress4cj.common.Zlib4cjException

// 无效的 litWidth
try {
    let _ = lzwCompress([0x41], litWidth: 1)   // < 2
} catch (e: Zlib4cjException) {
    // "litWidth must be >= 2"
}

try {
    let _ = lzwDecompress([0x41], litWidth: 9)  // > 8
} catch (e: Zlib4cjException) {
    // "litWidth must be between 2 and 8"
}

// 字节值超限
try {
    let _ = lzwCompress([0xFF], litWidth: 7)
} catch (e: Zlib4cjException) {
    // 具体错误消息
}
```

## 与 GIF/TIFF/PDF 配合

LZW 在这些格式中的典型参数：

| 格式 | 比特顺序 | 字面量位宽 | 说明 |
|------|----------|-----------|------|
| GIF | LSB | 8 | GIF 格式标准 |
| TIFF | MSB | 8 | TIFF 6.0 规范 |
| PDF | MSB | 8 | PDF 1.7 规范 |
| 自定义 | 任意 | 2~8 | 小比特位宽场景 |

```cangjie
// GIF 数据解压
let gifLzwData: Array<UInt8> = [/* 来自 GIF 文件的 LZW 数据 */]
let rasterData = lzwDecompress(gifLzwData, order: LzwOrder.LSB, litWidth: 8)

// PDF 数据解压
let pdfLzwData: Array<UInt8> = [/* 来自 PDF 流的 LZW 数据 */]
let streamData = lzwDecompress(pdfLzwData, order: LzwOrder.MSB, litWidth: 8)
```
