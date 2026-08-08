<div align="center">
<h1>zip4cj</h1>
</div>

<p align="center">
<img alt="" src="https://img.shields.io/badge/release-v1.0.5-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/build-pass-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/cjc-v1.0.0-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/cjcov-92%25-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/project-open-brightgreen" style="display: inline-block;" />
</p>



## <img alt="" src="./doc/assets/readme-icon-introduction.png" style="display: inline-block;" width=3%/>介绍

zip4cj 是基于仓颉语言实现的文件压缩和解压缩，目前基本实现了zip 的压缩和解压缩。

### 特性

- 🚀 文件夹级别解压和压缩
- 🚀 支持Zip64大文件压缩和解压
- 🚀 支持zip文件中重命名
- 🚀 支持zip文件中删除文件
- 🚀 支持zip文件中添加文件
- 🚀 支持子线程解压和压缩
- 🚀 支持分包压缩和解压
- 🚀 支持AES解密和加密
- 🚀 支持ZIP标准解密和加密
- 🚀 支持压缩和解压进度监控


##    <img alt="" src="./doc/assets/readme-icon-framework.png" style="display: inline-block;" width=3%/> 架构

### 源码目录

```shell
.
├── LICENSE  
├── README.md
├── doc
│   ├── assets
│   └── cjcov
├── src                             // 源码
│   ├── crypto                  // 加解密功能包
│   │   ├── engine              
│   │   └── PBKDF2
│   ├── exception               // 异常类包
│   ├── headers                 // zip文件头包
│   ├── io                      // zip IO流包
│   │   ├── inputstream
│   │   └── outputstream
│   ├── model                   // zip 配置和参数模式包
│   │   └── enums
│   ├── progress                // 进度监控包
│   ├── tasks                   // 支持多种压缩和解压缩方式包
│   ├── util                    // 工具包
│   └── zip_file.cj             // 主程序入口类
└── test
    ├── HLT
    ├── LLT
    └── UT
```

- `doc` 存放库的设计文档、提案、库的使用文档、LLT 覆盖率报告
- `src` 是库源码目录
- `test` 存放测试用例，包括 HLT 用例、LLT 用例和 UT 用例

### 类和接口说明：

详情见 [API](./doc/feature_api.md)

## <img alt="" src="./doc/assets/readme-icon-compile.png" style="display: inline-block;" width=3%/> 使用说明

### 编译

两种编译方式

1. 使用脚本编译 
    1. 下载配置[编译脚本](https://gitcode.com/Cangjie-TPC/TPC-Test-Framework.git)
    2. ciTest build
2. 使用cjpm编译 
    1. 该三方库依赖stdx，请参考[stdx](https://gitcode.com/Cangjie/Cangjie-STDX#%E4%BD%BF%E7%94%A8%E6%8C%87%E5%AF%BC)文档配置`CANGJIE_STDX_PATH`路径
    2. cjpm build

### 功能示例

#### zip 解压

```cangjie
import zip4cj.*                       // 引入zip4cj包 
import std.os.posix.*
import std.fs.*
import std.sync.*
import std.time.*
main() { 
    let zipFile = ZipFile("demo.zip")  // 创建ZipFile类
    zipFile.setRunInThread(false)                 // 设置是否用子线程运行任务
    zipFile.extractAll("./output")                // 解压到 output 文件夹, 文件夹不存在则创建
    zipFile.close()                               // 资源关闭
    0
}
```

#### zip 创建zip文件

```cangjie
import zip4cj.*                      // 引入zip4cj包 
import std.os.posix.*
import std.fs.*
import std.sync.*
import std.time.*
main() { 
    let zipParameters = ZipParameters()         // 创建 zip 参数配置 类
    zipParameters.setCompressionMethod(CompressionMethod.STORE)  // 设置压缩方式为存储
    let zipFile = ZipFile("output.zip")         // 创建ZipFile类, 并指定文件为 output.zip
    let files = [                               // 创建 文件集合
        Path("123.txt")
    ]
    zipFile.createSplitZipFile(files, zipParameters, false, InternalZipConstants.MIN_SPLIT_LENGTH)                           // 创建文件
    zipFile.close()                                           // 资源关闭
    return 0
}
```
#### 压缩文件夹
```cangjie
import zip4cj.*                      // 引入zip4cj包 
import std.os.posix.*
import std.fs.*
import std.sync.*
import std.time.*
main() { 
    let zipParameters = ZipParameters()         // 创建 zip 参数配置 类
    zipParameters.setCompressionMethod(CompressionMethod.DEFLATE)  // 设置压缩方式为DEFLATE压缩
    let zipFile = ZipFile("output.zip")         // 创建ZipFile类, 并指定文件为 output.zip
    zipFile.addFolder("test")                   // 添加文件夹压缩
    zipFile.close()                             // 资源关闭
    return 0
}
```

#### 在zip文件中重命名/删除/添加文件
```cangjie
import zip4cj.*                      // 引入zip4cj包 
import std.os.posix.*
import std.fs.*
import std.sync.*
import std.time.*
main() { 
    let zipParameters = ZipParameters()         // 创建 zip 参数配置 类
    zipParameters.setCompressionMethod(CompressionMethod.DEFLATE)  // 设置压缩方式为DEFLATE压缩
    let zipFile = ZipFile("output.zip")         // 创建ZipFile类, 并指定文件为 output.zip
    zipFile.removeFile("a.txt")                               // 删除文件
    zipFile.renameFile("old_file", "new_file")                // 重命名文件
    zipFile.addFile(Path("a.txt"), zipParameters) // 添加文件
    var paths=[
        Path("1.mp3")
        Path("12.mp3")
        Path("123.mp3")
        Path("1234.mp3")
    ]
    zipFile.addFiles(paths, zipParameters)        // 添加文件集合
    zipFile.close()                                           // 资源关闭
    return 0
}
```


#### 压缩时使用子线程压缩, 不阻塞主线程并使用进度监控
```cangjie
import zip4cj.*
import std.fs.*

main() { 
    var zipParameters = ZipParameters();
    zipParameters.setCompressionMethod(CompressionMethod.STORE);                // 设置压缩方式, 存储
    let zipFile = ZipFile("output.zip")
    zipFile.setRunInThread(true);                                               // 设置子线程压缩
    zipFile.createSplitZipFile([Path("FILE_0")],zipParameters, false, 65536);   // 添加 FILE_0(4Gb大小) 文件到zip
    let progress = zipFile.getProgressMonitor()                                 // 获取压缩进度类
    let state = progress.getState()                                             // 获取 压缩状态
    println(state)
    while (progress.getState() != ProgressMonitorState.READY) {
        sleep(Duration.millisecond * 1000)
    }
    println(progress.getState())
    zipFile.close()                                                             // 资源关闭
    0
}
```

#### 加密压缩, 密码方式AES-256, 压缩方式 STORE
```cangjie
import zip4cj.*
import std.fs.*
main () {
    let zipParameters = ZipParameters()                          // 创建压缩参数类
    zipParameters.setEncryptFiles(true)                          // 加密时必须要设置为true
    zipParameters.setEncryptionMethod(EncryptionMethod.AES)      // 设置密码方式为AES-256
    zipParameters.setCompressionMethod(CompressionMethod.STORE)  // 设置压缩方式为SOTRE, 不进行压缩文件
    let zipFile = ZipFile("66666.zip", "123456".toRuneArray())   // 设置输出文件名和密码
    zipFile.addFile("fields.c", zipParameters)                   // 添加文件和压缩参数
    zipFile.close()
}
```

#### 加密压缩, 密码方式ZIP_STANDARD(zip自带加密算法), 压缩方式 STORE
```cangjie
import zip4cj.*
import std.fs.*
main () {
    let zipParameters = ZipParameters()                          // 创建压缩参数类
    zipParameters.setEncryptFiles(true)                          // 加密时必须要设置为true
    zipParameters.setEncryptionMethod(EncryptionMethod.ZIP_STANDARD)      // 设置密码方式为AES-256
    zipParameters.setCompressionMethod(CompressionMethod.STORE)  // 设置压缩方式为SOTRE, 不进行压缩文件
    let zipFile = ZipFile("66666.zip", "123456".toRuneArray())   // 设置输出文件名和密码
    zipFile.addFile("fields.c", zipParameters)                   // 添加文件和压缩参数
    zipFile.close()
}
```

#### 加密压缩, 密码方式ZIP_STANDARD(zip自带加密算法), 压缩方式 DEFLATE
```cangjie
import zip4cj.*
import std.fs.*
main () {
    let zipParameters = ZipParameters()                          // 创建压缩参数类
    zipParameters.setEncryptFiles(true)                          // 加密时必须要设置为true
    zipParameters.setEncryptionMethod(EncryptionMethod.ZIP_STANDARD)      // 设置密码方式为AES-256
    zipParameters.setCompressionMethod(CompressionMethod.DEFLATE)  // 设置压缩方式为DEFLATE, 使用deflate算法压缩文件
    let zipFile = ZipFile("66666.zip", "123456".toRuneArray())   // 设置输出文件名和密码
    zipFile.addFile("fields.c", zipParameters)                   // 添加文件和压缩参数
    zipFile.close()
}
```

#### 解密解压, 无需设置解压密码方式和压缩方式
```cangjie
import  zip4cj.*

main() { 
    try (file = ZipFile("Animal_world.zip", "123".toRuneArray())) {  // 设置输入的zip文件名和解压密码
        file.extractAll("./")                                         // 解压到当前目录
        file.close()
    }    
}
```

## 约束和限制
#### 压缩方式支持（[其他压缩方式可参阅zip格式规范](https://pkwaredownloads.blob.core.windows.net/pkware-general/Documentation/APPNOTE-6.3.10.TXT)）
- 0 -  （支持）The file is stored (no compression)
- 8 -  （支持）The file is Deflated

#### 加密方式和版本支持（[其他不支持方式可参阅zip格式规范](https://pkwaredownloads.blob.core.windows.net/pkware-general/Documentation/APPNOTE-6.3.10.TXT)）

- 1.0 - （支持）Default value
- 1.1 - （支持）File is a volume label
- 2.0 - （支持）File is a folder (directory)
- 2.0 - （支持）File is compressed using Deflate compression
- 2.0 - （支持）File is encrypted using traditional PKWARE encryption
- 4.5 - （支持）File uses ZIP64 format extensions
- 5.1 - （支持）File is encrypted using AES encryption

#### 流式解压和压缩方式限制

- 流式解压文件, 如果流式zip中的frcompressSize为0时, 可能解压失败[链接](https://gitcode.com/Cangjie-TPC/zip4cj/issues/3) .

## 开源协议

本项目基于 [Apache License 2.0](/LICENSE) ，请自由的享受和参与开源。

## <img alt="" src="./doc/assets/readme-icon-contribute.png" style="display: inline-block;" width=3%/> 参与贡献

欢迎给我们提交 PR，欢迎给我们提交 issue，欢迎参与任何形式的贡献。