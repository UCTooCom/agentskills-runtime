# Repository Guidelines

## Project Structure

```
src/
├── package.cj                  — 模块入口 (package compress4cj)
├── common/
│   ├── exception.cj            — compress4cj.common: Zlib4cjException（全局异常类型）
│   └── util.cj                 — compress4cj.common: toUInt8Array/strToBytes/bytesEqual（工具函数）
├── zlib/
│   ├── zutil.cj                — compress4cj.zlib: 错误码/adler32/crc32/GZIPHeader/常量
│   ├── stream.cj               — compress4cj.zlib: Stream 流式缓冲区基类
│   ├── deflate.cj              — compress4cj.zlib: DEFLATE 压缩器
│   ├── inflate.cj              — compress4cj.zlib: DEFLATE 解压器
│   ├── deflater_stream.cj      — compress4cj.zlib: 压缩流封装（Deflater/Gzip/Zlib）
│   ├── inflater_stream.cj      — compress4cj.zlib: 解压流封装（Inflater/Gunzip/UnZlib）
│   ├── zlib.cj                 — compress4cj.zlib: 便捷 API（Zlib.compress/uncompress）
│   ├── deflate_test.cj         — compress4cj.zlib: DEFLATE 单测
│   ├── inflate_test.cj         — compress4cj.zlib: Inflate 单测
│   ├── stream_test.cj          — compress4cj.zlib: 流封装单测
│   ├── zlib_test.cj            — compress4cj.zlib: 便捷 API 单测
│   └── zutil_test.cj           — compress4cj.zlib: 工具函数单测
├── brotli/
│   ├── brotli.cj               — compress4cj.brotli: Brotli 压缩/解压 API
│   ├── brotli_dict.cj          — compress4cj.brotli: Brotli 静态字典
│   ├── brotli_impl.cj          — compress4cj.brotli: Brotli 完整解码器
│   └── brotli_test.cj          — compress4cj.brotli: 单测
├── bzip2/
│   ├── bzip2.cj                — compress4cj.bzip2: bzip2 解压实现
│   └── bzip2_test.cj           — compress4cj.bzip2: 单测
└── lzw/
    ├── lzw.cj                  — compress4cj.lzw: LZW 压缩/解压实现
    └── lzw_test.cj             — compress4cj.lzw: 单测

cjpm.toml                       — 仓颉包清单（name = compress4cj, version = 0.1.0）
```

包名 `compress4cj`，仅依赖仓颉 `std` 标准库，不依赖 `stdx`。

### 子包体系

Cangjie 编译器要求子目录中的源文件声明对应的子包名：

| 目录 | 包声明 | 说明 |
|------|--------|------|
| `src/` | `compress4cj` | 模块入口点（`package.cj`） |
| `src/common/` | `compress4cj.common` | 跨算法共享基础设施（`Zlib4cjException` + 工具函数） |
| `src/zlib/` | `compress4cj.zlib` | zlib/DEFLATE/gzip 核心 + 流式封装 + 单测 |
| `src/brotli/` | `compress4cj.brotli` | Brotli 压缩扩展 + 单测 |
| `src/bzip2/` | `compress4cj.bzip2` | bzip2 解压实现 + 单测 |
| `src/lzw/` | `compress4cj.lzw` | LZW 压缩/解压实现 + 单测 |

### 包间引用

- `compress4cj.zlib`、`compress4cj.brotli`、`compress4cj.lzw`、`compress4cj.bzip2` 均使用 `import compress4cj.common.Zlib4cjException`
- 单测文件可引用 `compress4cj.common.strToBytes` 和 `compress4cj.common.bytesEqual`
- 同子包内文件可直接引用彼此的公开类型（无需 import）
- 跨子包引用需显式 import（如上例）

## Build, Test & Development

```bash
cjpm build           # 调试构建
cjpm build -i         # 增量构建
cjpm build --release  # 发布构建
cjpm clean            # 清理产物
cjpm test             # 运行测试（自动发现 @Test 函数）
```

编译器版本 `cjc-v1.0.5`，编译选项 `-Woff unused` 在 `cjpm.toml` 中全局设定（含 test profile）。

## Coding Style & Naming

- 缩进 4 空格，文件编码 UTF-8。
- 类型/类名 PascalCase（`DeflaterOutputStream`），函数/变量 camelCase（`inflateFast`），常量 UPPER_SNAKE_CASE（`MAX_BITS`）。
- `match` 分支不使用 `{}`，表达式直接写在 `case` 后。
- 公开函数标注 `@Frozen`，溢出敏感函数标注 `@OverflowWrapping`。
- `Array<UInt8>` 与 `Array<Byte>` 等价，内部缓冲区统一用 `Array<UInt8>`。
- 错误码统一为 `Int32` 常量（`Z_OK`、`Z_STREAM_END` 等）；禁止使用 `panic()`，改用 `throw Exception(...)`。
- 命名参数需在函数签名中加 `!` 后缀（如 `wrap!: ZlibType`）。
- 数组大小和索引统一使用 `Int64` 类型。

## Testing Guidelines

- 测试框架为仓颉内置 `cjpm test`，无第三方测试库。
- 单测文件（`*_test.cj`）置于对应源码同一子包目录下，`cjpm test` 自动发现并执行 `@Test` 函数。
- 压缩/解压测试应覆盖三种格式（ZLIB / GZIP / DEFLATE）、字典、空数据、破坏数据及解压炸弹防护场景。

## Algorithm Implementations

### Brotli（79 个单测整体通过，其中 Brotli 9 个）
当前实现使用非压缩 metablock 编码器 + 完整解码器（含 Huffman 解码、静态字典、上下文模式）。
编码器输出为非压缩 metablock 格式（存储为 brotli 格式但无实际压缩比），解码器支持解析 RFC 7932 标准压缩流。
9 个单测全部通过，覆盖压缩/解压/空数据/字典/大数据的完整 Roundtrip。

### Bzip2（bzip2 6 个单测通过）
基于 Go compress/bzip2 的算法理解以仓颉惯用风格重写。
完整解压实现已完成（6 个单测全部通过），支持 Huffman 编码 + MTF + BWT + Run-Length 解码。
覆盖正常数据/空数据/入侵检测（错误 magic 和截断数据防护）。

### LZW（LZW 14 个单测通过）
基于 Go compress/lzw 的算法理解。
完整编解码实现已完成（14 个单测全部通过），支持 LSB/MSB 顺序、自定义字面量位宽（2-8），
覆盖空值/小数据/大数据/交替/递增/重复模式等场景。

### Go 参考说明
Go 标准库的实现仅用于算法理解。本项目的 Cangjie 实现使用不同的 API（函数式、Array<UInt8> 缓冲、异常处理）、不同的命名和结构组织，不涉及 Go 源码的直接翻译。
Go `compress/` 标准库中的全部算法（flate/gzip/zlib/bzip2/lzw）均已有对应实现。

## Commit & Pull Request

- 提交遵循 Conventional Commits：`feat:`、`fix:`、`chore:`、`docs:`、`refactor:`。
- 本仓库仅做工作区集成裁剪，核心逻辑修复应向上游 `Cangjie-TPC/zlib4cj`（或 `compress4cj`）提交。

## 仓颉语言要点

- **`match` 是关键字**，不可用作变量名。
- **`Option<T>` 不支持 `==`**，用 `if (let Some(v) <- expr)` 或 `.isSome()`/`.isNone()` 展开。
- **枚举须显式实现 `==` 和 `!=`**，用作 HashMap key 还需 `Hashable & Equatable`。
- **三元表达式不可用**，用 `if (cond) { expr1 } else { expr2 }` 代替。
- **Lambda** 语法 `{key, value => body}`，无需类型标注和括号。
- 字符串操作：`String.size` 返回 UTF-8 字节数；`String[n]` 取字节；字符索引用 `toRuneArray()`。
- **`UInt32` 溢出不自动回绕**：使用 `@OverflowWrapping` 标注或手动控制。

## Upstream

原上游仓库：`https://gitcode.com/Cangjie-TPC/zlib4cj.git`。本地镜像裁剪记录见 `UPSTREAM.md`，变更日志见 `CHANGELOG.md`。
