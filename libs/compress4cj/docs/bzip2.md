# bzip2 使用手册

`import compress4cj.bzip2.*`

## 概述

bzip2 子包提供标准 bzip2（`.bz2`）格式的解压能力。实现基于块排序压缩算法（Burrows-Wheeler Transform + Move-to-Front + Huffman 编码）。

仅支持解压，不支持压缩。

## 公开函数

### bzip2Decompress(data)

解压标准 bzip2 格式数据。

| 参数 | 类型 | 说明 |
|------|------|------|
| data | `Array<UInt8>` | bzip2 压缩数据 |

```cangjie
import compress4cj.bzip2.*

// 读取 .bz2 文件
let file = FileInputStream("data.bz2")
let bz2Data = file.readAll()
file.close()

// 解压
let decompressed = bzip2Decompress(bz2Data)
```

## 边界处理

### 空数据

```cangjie
// 空输入直接返回空
let result = bzip2Decompress([])
// result.size == 0

// 空的 bz2 流（仅文件尾标记）
let emptyBz2: Array<UInt8> = [
    0x42, 0x5a, 0x68, 0x39, 0x17, 0x72, 0x45, 0x38,
    0x50, 0x90, 0x00, 0x00, 0x00, 0x00
]
let result = bzip2Decompress(emptyBz2)
// result.size == 0
```

### 非法数据

```cjacjie
// 无效 magic 标识
try {
    let _ = bzip2Decompress([0x00, 0x00, 0x00])
} catch (e: Zlib4cjException) {
    // "bzip2: invalid magic"
}
```

### 截断数据

```cangjie
try {
    let truncated = bzip2Data[..10]
    let _ = bzip2Decompress(truncated)
} catch (e: Zlib4cjException) {
    // "bzip2: unexpected end of data"
}
```

## 完整示例

### 文件解压

```cangjie
import compress4cj.bzip2.*
import std.io.*

func decompressBz2(filename: String): Array<UInt8> {
    let file = FileInputStream(filename)
    let data = file.readAll()
    file.close()
    bzip2Decompress(data)
}

// 使用
let content = decompressBz2("backup.tar.bz2")
```

### 校验解压结果

```cangjie
import compress4cj.common.bytesEqual

let expected: Array<UInt8> = [/* 原始数据 */]
let decompressed = bzip2Decompress(bz2Data)
if (bytesEqual(decompressed, expected)) {
    println("CRC 校验通过")
}
```

## 错误处理

```cangjie
import compress4cj.bzip2.*
import compress4cj.common.Zlib4cjException

try {
    let data = bzip2Decompress(input)
} catch (e: Zlib4cjException) {
    // 可能原因：
    // "bzip2: invalid magic"            — 非 bz2 格式
    // "bzip2: unexpected end of data"   — 数据不完整
    // "bzip2: bad block magic"          — 块标记损坏
    // "bzip2: file CRC mismatch"         — CRC 校验失败
    // "bzip2: no symbols in block"      — 格式错误
    println(e.message)
}
```

## 限制

- 当前仅支持解压，不支持压缩
- 不支持 randomized blocks（bzip2 早期遗留特性，极少遇见）
- 不支持流式增量解压（需一次性传入完整 bz2 数据）
