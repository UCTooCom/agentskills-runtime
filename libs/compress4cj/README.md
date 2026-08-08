# compress4cj

纯仓颉实现的多格式压缩/解压库。零外部依赖，仅使用仓颉 `std` 标准库。

## 安装

在 `cjpm.toml` 中添加依赖：

```toml
[dependencies]
compress4cj = { git = "https://gitcode.com/changeden/compress4cj.git" }
```

然后引入对应子包：

```cangjie
import compress4cj.zlib.*       // DEFLATE / zlib / gzip
import compress4cj.brotli.*     // Brotli
import compress4cj.bzip2.*      // bzip2 解压
import compress4cj.lzw.*        // LZW
```

## API 速览

### zlib — DEFLATE / zlib / gzip 压缩与解压

提供三合一便捷 API，按格式自动识别：

```cangjie
// 压缩：不指定 wrap 时自动选择格式
let compressed = Zlib.compress(data)                      // zlib 格式
let z = Zlib.compress(data, wrap: ZlibType.ZLIB)          // 显式指定 zlib
let g = Zlib.compress(data, wrap: ZlibType.GZIP)          // gzip
let r = Zlib.compress(data, wrap: ZlibType.RAW_DEFLATE)   // 裸 DEFLATE

// 解压：自动检测 zlib/gzip/raw deflate
let decompressed = Zlib.uncompress(compressed)

// 流式读写（大文件/分块处理）
let deflater = DeflaterOutputStream(outputStream, wrap: ZlibType.GZIP)
// ... 写入数据后 close

let inflater = InflaterInputStream(inputStream)
// ... 读取解压后数据
```

支持字典压缩、设置压缩级别、自定义 gzip 头部。

### brotli — Brotli 压缩与解压

```cangjie
import compress4cj.brotli.*

let data: Array<UInt8> = [/* ... */]

// 压缩（构建合法 brotli 流）
let compressed = brotliCompress(data)

// 解压（完整 RFC 7932 解码器，支持标准 brotli 流）
let decompressed = brotliDecompress(compressed)
```

### bzip2 — bzip2 解压

```cangjie
import compress4cj.bzip2.*

// 解压标准 .bz2 文件数据
let bz2Data: Array<UInt8> = [/* 从文件读取 */]
let decompressed = bzip2Decompress(bz2Data)

// 非法数据会抛出 Zlib4cjException
try {
    let _ = bzip2Decompress([0x00, 0x00, 0x00])
} catch (e: Exception) {
    // Zlib4cjException: "bzip2: invalid magic"
}
```

### lzw — LZW 压缩与解压

```cangjie
import compress4cj.lzw.*

let data: Array<UInt8> = [/* ... */]

// LSB 顺序 (GIF 格式)，字面量位宽 8（默认参数）
let compressed = lzwCompress(data)
let decompressed = lzwDecompress(compressed)

// MSB 顺序 (TIFF/PDF)
let msbCompressed = lzwCompress(data, order: LzwOrder.MSB, litWidth: 8)
let msbBack = lzwDecompress(msbCompressed, order: LzwOrder.MSB, litWidth: 8)
```

## 错误处理

所有错误均通过 `Zlib4cjException`（继承 `Exception`）上报，不使用 `panic()`：

```cangjie
import compress4cj.common.Zlib4cjException

try {
    let result = Zlib.uncompress(badData)
} catch (e: Zlib4cjException) {
    // 获得具体错误原因：e.message
}
```

## 支持的算法

| 算法 | 压缩 | 解压 | 遵循标准 |
|------|------|------|----------|
| DEFLATE | ✓ | ✓ | RFC 1951 |
| zlib | ✓ | ✓ | RFC 1950 |
| gzip | ✓ | ✓ | RFC 1952 |
| Brotli | 仅非压缩 metablock | ✓ 完整解码 | RFC 7932 |
| bzip2 | — | ✓ | — |
| LZW | ✓ | ✓ | GIF/PDF 可变宽度编码 |

## 构建

```bash
cjpm build             # 调试构建
cjpm build --release   # 发布构建
cjpm test              # 运行全部单测 (79 个)
```

编译器版本 `cjc-v1.0.5`，编译选项全局设定 `-Woff unused`。

## 许可

基于上游 <https://gitcode.com/Cangjie-TPC/zlib4cj.git> 裁剪。
