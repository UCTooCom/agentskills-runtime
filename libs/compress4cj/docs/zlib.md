# DEFLATE / zlib / gzip 使用手册

`import compress4cj.zlib.*`

## 概述

zlib 子包提供 DEFLATE 压缩/解压引擎（RFC 1951）及其上的 zlib（RFC 1950）和 gzip（RFC 1952）封装格式支持。共分三个调用层次：

- **便捷 API**：整块数据压缩/解压
- **底层引擎**：精细控制压缩参数
- **流式封装**：文件、网络等分块读写场景

## 便捷 API

### Zlib 类型

```cangjie
ZlibType: ZLIB | GZIP | DEFLATE | AUTO_DETECT
```

### Zlib.compress(data, ...)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| data | `Array<Byte>` | — | 待压缩数据 |
| wrap | `ZlibType` | `DEFLATE` | 封装格式 |
| bufferSize | `Int64` | `1024` | 内部缓冲区大小 |
| level | `Int64` | `6` | 压缩级别 0~9 |
| memLevel | `UInt32` | `8` | 内存使用级别 1~9 |
| strategy | `UInt32` | `Z_DEFAULT_STRATEGY` | 压缩策略 |
| dict | `?Array<Byte>` | `None` | 预设字典 |

```cangjie
// 三种封装格式
let zlibData   = Zlib.compress(data, wrap: ZlibType.ZLIB)
let gzipData   = Zlib.compress(data, wrap: ZlibType.GZIP)
let rawData    = Zlib.compress(data, wrap: ZlibType.DEFLATE)

// 不同压缩级别
let bestSize   = Zlib.compress(data, level: 9)    // 最大压缩比
let fastest    = Zlib.compress(data, level: 1)     // 最快速度
let noCompress = Zlib.compress(data, level: 0)     // 不压缩

// 使用预设字典
let dict = strToBytes("common prefix")
let compressed = Zlib.compress(data, wrap: ZlibType.ZLIB, dict: dict)
```

### Zlib.uncompress(data, ...)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| data | `Array<Byte>` | — | 待解压数据 |
| wrap | `ZlibType` | `AUTO_DETECT` | 封装格式（自动检测） |
| bufferSize | `Int64` | `1024` | 内部缓冲区大小 |
| dict | `?Array<Byte>` | `None` | 预设字典（与压缩时一致） |
| maxOutputSize | `Int64` | `0` | 解压炸弹防护（0=不限制） |

```cangjie
// 自动检测格式（ZLIB/GZIP/DEFLATE）
let decompressed = Zlib.uncompress(data)

// 显式指定格式
let out = Zlib.uncompress(data, wrap: ZlibType.GZIP)

// 字典解压
let out = Zlib.uncompress(compressed, wrap: ZlibType.ZLIB, dict: dict)

// 解压炸弹防护：限制输出 10MB
let safe = Zlib.uncompress(data, maxOutputSize: 10 * 1024 * 1024)
// 超过限制抛 Zlib4cjException
```

## 底层 DEFLATE 引擎

需要精细控制时直接使用 `Deflate` 和 `Inflate` 类。

### Deflate 类 (压缩)

```cangjie
let def = Deflate()

// 初始化（必须）
def.deflateInit2(level: 6, wbits: 15, memLevel: 8, strategy: 0)
// wbits:  15=zlib 格式,  15+16=31=gzip 格式,  -15=raw deflate
// level:  0-9（0=不压缩, 1=最快, 6=默认, 9=最大压缩）
// memLevel:  1-9（1=最少内存, 9=最快速度）
// strategy:  Z_DEFAULT_STRATEGY(0) | Z_FILTERED(1) |
//            Z_HUFFMAN_ONLY(2) | Z_RLE(3) | Z_FIXED(4)

// 或者使用默认参数
def.deflateInit(level: 6)
// 等价于 deflateInit2(level, 15, 8, Z_DEFAULT_STRATEGY)

// 设置输入输出
def.setInBuf(input)
def.setOutBuf(outputBuffer)

// 执行压缩
let err = def.deflate(Z_FINISH)   // flush: Z_NO_FLUSH / Z_FULL_FLUSH / Z_FINISH
let written = def.pos_out          // 本次输出字节数

// 清理
def.deflateEnd()

// 支持字典
def.setDictionary(dict)
```

### Inflate 类 (解压)

```cangjie
let inf = Inflate(wrap: 1)
// wrap:  1=zlib,  2=gzip,  -1=raw deflate

// 初始化
inf.inflateInit()
// 或指定 window bits
inf.inflateInit2(wbits: 15)

// 设置输入输出
inf.setInBuf(compressed)
inf.setOutBuf(buffer)

// 执行解压
while (inf.avail_in > 0) {
    let err = inf.inflate(Z_NO_FLUSH)
    if (err == Z_STREAM_END) { break }
}

// 获取解压结果
inf.inflateEnd()
inf.end()

// 支持字典
inf.setDictionary(dict)

// 获取 gzip 头信息
if (let Some(gzh) <- inf.getGzipHeader()) {
    println(gzh.text)
    println(gzh.time)
    println(gzh.os)
    println(gzh.extra)
    println(gzh.name)
    println(gzh.comment)
}

// 数据错误时尝试同步恢复
let syncRet = inf.inflateSync()  // Z_OK=恢复成功
```

### Stream 基类属性

```cangjie
// 公共字段
def.avail_in: Int64     // 输入缓冲区剩余未处理字节数
def.avail_out: Int64    // 输出缓冲区剩余空间
def.pos_out: Int64      // 输出缓冲区已写入位置
def.total_in: Int64     // 已处理输入总字节
def.total_out: Int64    // 已输出总字节
def.message: String     // 最后一次错误消息

// 常用方法
def.setInBuf(buf, start?, len?)
def.setOutBuf(buf, start?, len?)
def.resetOutBuf()
def.isInbufEmpty(): Bool
def.isHaveOutData(): Bool
```

## 流式封装

适合文件、网络流的压缩/解压场景。包装仓颉标准 `OutputStream` / `InputStream`。

### 压缩输出流

```cangjie
// 写入时实时压缩
let fileOut = FileOutputStream("data.gz")

// 选择封装格式
let gzipOut     = GzipOutputStream(fileOut)
let zlibOut     = ZlibOutputStream(fileOut)
let deflateOut  = DeflaterOutputStream(fileOut)

gzipOut.write(data)
gzipOut.close()     // 写入尾标记并关闭

// 设置字典
gzipOut.setDictionary(dict)
```

### 压缩输入流

```cangjie
// 读取时实时解压
let fileIn = FileInputStream("data.gz")

// 选择解压格式
let gzipIn    = GzipInputStream(fileIn)
let zlibIn    = ZlibInputStream(fileIn)
let deflateIn = DeflaterInputStream(fileIn)

let result = gzipIn.readAll()
gzipIn.close()
```

### 解压输出流

```cangjie
// 解压数据写入文件
let outFile = FileOutputStream("output.bin")
let gunzipOut = GunzipOutputStream(outFile)
gunzipOut.write(decompressed)
gunzipOut.close()
```

### 解压输入流

```cangjie
// 读取时实时解压
let inFile = FileInputStream("data.z")
let unzlibIn = UnZlibInputStream(inFile)
let result = unzlibIn.readAll()

// 自动检测格式
let unknown = FileInputStream("unknown")
let autoIn = AutoDecompressInputStream(unknown)
let data = autoIn.readAll()

// 流信息
autoIn.getTotalIn()      // 已读取压缩数据大小
autoIn.getTotalOut()     // 已输出解压数据大小
autoIn.getAvailIn()      // 输入缓冲区剩余
autoIn.getRemaining()    // 未读取的解压缓冲区数据
autoIn.isClosed()
autoIn.getInflater()     // 获取底层 Inflate 对象
```

## 校验和函数

```cangjie
// Adler-32
let a32: UInt32 = adler32(1, data, start: 0, length: data.size)

// CRC-32
let c32: UInt32 = crc32(0, data, start: 0, length: data.size)

// 分块续算
var crc = UInt32(0)
crc = crc32(crc, chunk1, 0, chunk1.size)
crc = crc32(crc, chunk2, 0, chunk2.size)
```

## GZIPHeader

```cangjie
let header = GZIPHeader()
header.text    = true       // 文本数据标识
header.time    = 0          // Unix 时间戳
header.os      = FAT_FILESYSTEM  // 操作系统标识
header.extra   = []         // 额外字段
header.name    = ""         // 文件名
header.comment = ""         // 注释

// 设置到压缩器
def.deflateSetHeader(header)
```

## 错误码常量

```cangjie
Z_OK(0)          Z_STREAM_END(1)   Z_NEED_DICT(2)
Z_ERRNO(-1)      Z_STREAM_ERROR(-2)  Z_DATA_ERROR(-3)
Z_MEM_ERROR(-4)  Z_BUF_ERROR(-5)

// Flush 类型
Z_NO_FLUSH(0)     Z_FULL_FLUSH(3)   Z_FINISH(4)
Z_BLOCK(5)        Z_TREES(6)

// 压缩级别
Z_NO_COMPRESSION(0)   Z_BEST_SPEED(1)
Z_DEFAULT_COMPRESSION(6)  Z_BEST_COMPRESSION(9)

// 内存级别
MIN_MEM_LEVEL(1)   DEF_MEM_LEVEL(8)   MAX_MEM_LEVEL(9)
```

## 完整示例

### gzip 文件处理

```cangjie
import compress4cj.zlib.*
import std.io.*

// 压缩文件
func writeGzip(filename: String, data: Array<Byte>): Unit {
    let out = GzipOutputStream(FileOutputStream(filename))
    out.write(data)
    out.close()
}

// 解压文件
func readGzip(filename: String): Array<Byte> {
    let in_ = GzipInputStream(FileInputStream(filename))
    let result = in_.readAll()
    in_.close()
    result
}
```

### 字典压缩

```cangjie
let dict = strToBytes("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n")
let data = strToBytes("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<html>...")

let compressed = Zlib.compress(data, wrap: ZlibType.ZLIB, dict: dict)
let back = Zlib.uncompress(compressed, wrap: ZlibType.ZLIB, dict: dict)
// back == data
```

### 解压炸弹防护

```cangjie
try {
    let result = Zlib.uncompress(input, maxOutputSize: 1_000_000)
} catch (e: Zlib4cjException) {
    // "解压后数据超过最大允许大小: 1000000 字节"
}
```

### 流式分块压缩

```cangjie
let def = Deflate(15, 1)    // zlib 格式
def.deflateInit2(6, 15, 8, 0)

let input: Array<Byte> = [/* 大块数据 */]
let buf = Array<Byte>(4096, repeat: 0)
def.setInBuf(input)

while (def.avail_in > 0) {
    def.setOutBuf(buf)
    let err = def.deflate(Z_NO_FLUSH)
    let chunk = buf[0..def.pos_out]
    // 输出 chunk
    def.resetOutBuf()
    if (err == Z_STREAM_END) { break }
}
def.deflateEnd()
```

## 错误处理

```cangjie
try {
    let result = Zlib.uncompress(corrupted)
} catch (e: Zlib4cjException) {
    // 检查 e.message
    println(e.message)
}

// 底层 API 返回错误码
let err = def.deflate(Z_FINISH)
if (err != Z_STREAM_END) {
    println(def.message)    // 获取错误描述
}
```
