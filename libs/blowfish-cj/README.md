<div align="center">
<h1>blowfish-cj</h1>
</div>

<p align="center">
<img src="https://img.shields.io/badge/LICENSE-MIT-blue"/>
<img src="https://img.shields.io/badge/LICENSE-BSD_3--Clause-orange"/>
<img src="https://img.shields.io/badge/coverage-100%25-green"/>
</p>

本项目是一个 Blowfish 分组密码算法的 Cangjie 实现。它实现了 `std.crypto.cipher.BlockCipher` 接口，提供了标准的加密和解密功能。

该实现参考了 Go 语言标准库 [`golang.org/x/crypto/blowfish`](https://pkg.go.dev/golang.org/x/crypto/blowfish) 的实现。

## 特性

*   标准的 Blowfish 算法。
*   分组大小 (Block Size): 8 字节 (64 位)。
*   密钥长度 (Key Size):
    *   标准模式：1 至 56 字节。
    *   带 Salt 模式：密钥长度至少 1 字节，通过提供的 Salt 进行密钥扩展。
*   实现了 `std.crypto.cipher.BlockCipher` 接口。

## 如何集成

1.  将以下内容放在您项目中`cjpm.toml`的`[dependencies]`下
```
blowfish = {git = "https://gitcode.com/Dacec/blowfish-cj.git", branch = "main", output-type = "static"}
```
2.  运行`cjpm update`

## 使用示例

以下是如何使用 `Blowfish` 类进行加密和解密操作的示例。

```cangjie
package example

import blowfish.Blowfish

main(): Unit {
    let key = Array(16) { i => UInt8(i) } // 1 - 56 Bytes
    let salt = Array(8) { i => UInt8(i) + 16 }
    let text = "Cangjie!" // 8 Bytes

    let blowfish = Blowfish(key, salt)

    // 加密生成新的Array<Byte>
    let buf1 = blowfish.encrypt(text.toArray())
    println(buf1)

    // 加密到指定buf
    let buf2 = Array(8, repeat: 0u8)
    blowfish.encrypt(text.toArray(), to: buf2)
    println(buf2)

    // 解密生成新的Array<Byte>
    let buf3 = blowfish.decrypt(buf1)
    println(String.fromUtf8(buf3))

    // 解密到指定buf
    let buf4 = Array(8, repeat: 0u8)
    blowfish.decrypt(buf2, to: buf4)
    println(String.fromUtf8(buf4))
}
```

## API文档
[api-reference.md](./docs/api-reference.md)

## 许可证 (License)

本项目主要采用 **MIT License**。详细信息请参阅 [`LICENSE.MIT`](./LICENSE.MIT) 文件。

本项目的部分代码实现参考了 Go 语言标准库 `golang.org/x/crypto/blowfish`，该部分代码受 **BSD-style license** 约束。详细信息请参阅 [`LICENSE.BSD`](./LICENSE.BSD) 文件。