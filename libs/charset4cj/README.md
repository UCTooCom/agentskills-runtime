<div align="center">
<h1> charset4cj </h1>
</div>

<p align="center">
<img alt="" src="https://img.shields.io/badge/release-v1.0.5-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/build-pass-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/cjc-v1.1.3-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/cjcov-90.7%25-brightgreen" style="display: inline-block;" />
<img alt="" src="https://img.shields.io/badge/project-open-brightgreen" style="display: inline-block;" />
</p>

## <img alt="" src="https://raw.gitcode.com/Cangjie-TPC/charset4cj/blobs/15213299d979e856624253d41858a9369a44ad5c/readme-icon-introduction.png" style="display: inline-block;" width=3%/> 介绍

仓颉语言编解码库

### 特性

+ 🚀 只有两种方式获取字符集Charset

  + 通过 Charsets 的常量获取，例如： Charsets.UTF8
  + 通过 Charsets 的forName 方法获取， 比如 Charsets.forName("UTF-8")

- 🚀 通过 Charset 创建编码解码器

+ 💪 待开发特性
  + 增加bom支持

##    <img alt="" src="https://raw.gitcode.com/Cangjie-TPC/charset4cj/blobs/cde6bdb14ced62261c2f5cb6bd976b9a9aa10fa9/readme-icon-framework.png" style="display: inline-block;" width=3%/> 架构

### 架构图：

<p align="center">
<img src="https://raw.gitcode.com/Cangjie-TPC/charset4cj/blobs/3b02677c9328c7605ecf1414551ed8de4785a624/framework.png" width="60%" >
</p>

- 将字节数组转成String对象

解码器提供了下面两个方法，能够将字节数组转成String对象
```
func decode(src:Array<UInt8>):String
func decode(src:Array<UInt8>, dest:Array<Char>): (Int64, Int64)
```
io流（包含文件流、网络流）读取的都是字节数组，要将字节数组转成String，就需要上面2个方法。每种字符集的解码方法各不相同

- 将String转成字节数组

要将String写入到io流，需要将String转成字节数组，此时就需要编码器，
编码器提供了编码方法，能将String转成字节数组，传统字符集的字符数量小于unicode， 一些字符在传统字符集中没有，
从unicode(String)编码到传统字符集，会将没有的字符替换成其它（如：0xF3）字节
```
func encode(str:String): Array<UInt8>
```

+ 字符集分类

  + unicode。 仓颉的String是Char数组，一个Char是32位，表示一个unicode代码点。仓颉的String转utf8,utf16le, utf16be,utf32都可以通过计算得到编码
  + 简体中文，如gbk, 无法通过计算与unicode互相转化，需要维护一个gbk代码点与unicode代码点映射表，通过查表方式去转化
  + 繁体中文，big5, 无法通过计算与unicode互相转化，需要维护一个big5代码点与unicode代码点映射表，通过查表方式去转化
  + 韩语，EUC-KR， 需要映射表
  + 日语，需要映射表
  + 阿拉伯语，拉丁语等等这些字符数量少于256，一个字节就能保存下来的字符集。这些字符集有个特点，代码点小于128的与ascii相同，无需转码。128~256的字符转码unicode需要查表

### 源码目录：

```
├── doc
│   └── assets
│   └── feature_api.md
├── src
│   └── charset
│       ├── charsets.cj     // 常量类，提供forName方法根据字符集名称获取字符集类型，并提供所有支持的字符集常量
│       ├── text_reader.cj
│       ├── text_writer.cj
│       ├── encoding        // 字符集接口
│       │   ├── charset.cj
│       │   ├── decoder.cj
│       │   └── encoder.cj
│       ├── exception
│       │   ├── charset_exception.cj
│       │   ├── decoder_exception.cj
│       │   └── encoder_exception.cj
│       ├── japanese        // 日语字符集编码实现
│       │   ├── eucjp.cj
│       │   ├── iso_2022_jp_katakana_mapping.cj
│       │   ├── iso_2022_jp.cj
│       │   ├── jis0208_mapping.cj
│       │   ├── jis0212_mapping.cj
│       │   ├── jp_charset.cj
│       │   └── shift_jis.cj
│       ├── korean          // 韩语字符集编码实现
│       │   ├── euc_kr_mapping.cj
│       │   └── euckr.cj
│       ├── simplechinese   // 简体中文字符集编码实现
│       │   ├── gb18030_charset.cj
│       │   ├── gb18030_decoder.cj
│       │   ├── gb18030_encoder.cj
│       │   ├── gb18030_mapping.cj
│       │   └── gb18030_ranges_mapping.cj
│       ├── singlebyte      //  西欧、阿拉伯单字节字符集编解码实现
│       │   ├── ibm866_mapping.cj
│       │   ├── iso_8859_10_mapping.cj
│       │   ├── ......
│       │   ├── windows_874_mapping.cj
│       │   └── x_mac_cyrillic_mapping.cj
│       ├── traditionchinese  // 繁体中文字符集编解码实现
│       │   ├── big5.cj
│       │   └── big5_mapping.cj
│       └── unicode           // unicode 编解码实现
│           ├── utf16.cj
│           ├── utf32.cj
│           └── utf8.cj
├── test
│   └── DOC
│   └── FUZZ
│   └── HLT
│   └── LLT
│   └── UT
├── tools
│   └── generate
│         └── cj
│             └── mapping_generate.cj // mapping 映射集生成工具
├── CHANGELOG.md
├── gitee_gate.cfg
├── LICENSE
├── module.json
├── README.md
```

- `doc` 存放库使用文档
- `src` 是库源码目录
- `test` 是存放测试用例的文件夹，含有 DOC 文档用例、FUZZ 测试用例、HLT 测试用例、LLT 自测用例 和 UT测试用例

### 接口说明

主要是核心类和成员函数说明,详情见 [API](https://gitcode.com/Cangjie-TPC/charset4cj/blob/develop/doc/feature_api.md)

## <img alt="" src="https://raw.gitcode.com/Cangjie-TPC/charset4cj/blobs/da64231ac2d2bf0a586c6a35353585af005e2faf/readme-icon-compile.png" style="display: inline-block;" width=3%/> 使用说明

### 编译构建

#### linux环境编译

编译描述和具体shell命令

```shell
cjpm build
```

#### Windows环境编译

编译描述和具体cmd命令

```cmd
cjpm build
```

### 执行用例
编译用例并执行，步骤如下：

#### 1. 进入 test/ 目录下创建 tmp 文件夹，然后编译测试用例
```shell
cd test/
mkdir tmp
cjc -O2 --import-path xxxxx/target/release -L xxxxx/target/release/charset -l charset_charset.unicode -l charset_charset.korean -l charset_charset.exception -l charset_charset.simplechinese -l charset_charset.encoding -l charset_charset.japanese -l charset_charset.singlebyte -l charset_charset.traditionchinese -l charset_charset test/HLT/test_CharSets_forName_01.cj -o test/tmp/test.cj.out --test
```

##### 1.1 具体说明

- cjc命令, -O2表示开启优化
```shell
cjc -O2
```
- --import-path 导入charset库编译出来的库文件地址, 注意地址最后有".."
- xxx 代表自己的工作目录，应替换成自己的实际工作目录
- -L 导入库文件的完整路径
- 导入多个库,每个库都需要--import-path和 -L

```shell
--import-path xxxxx/target/release -L xxxxx/target/release/charset -l charset_charset.unicode -l charset_charset.korean -l charset_charset.exception -l charset_charset.simplechinese -l charset_charset.encoding -l charset_charset.japanese -l charset_charset.singlebyte -l charset_charset.traditionchinese -l charset_charset
```
- -l 要导入的具体的包, 用"库名_包名",一般库文件生成时是"lib库名_包名.后缀"的格式
- 导入一个库中有多个包时,用多个 -l

- 测试用例的完整路径和用例中引入文件的完整路径
- -o 用例编译后输出的位置和名称, .out结尾, 一般使用"用例名称.out"
- --test 用例编译命令结尾
```shell
test/HLT/test_CharSets_forName_01.cj -o test/tmp/test.cj.out --test
```

#### 2. 把编译好的文件复制到 .out 文件下(test/tmp/)
- 把target/release/charset 目录中的文件都复制到 .out 文件位置(test/tmp/ 中)

#### 3. 进入到.out文件位置，执行用例
- 进入到.out文件位置执行用例
```shell
cd test/tmp
```
- windows系统打开cmd,输入.out文件完整名称即可执行
```shell
test.cj.out
```
- Linux系统使用 ./.out文件完整名称
```shell
./test.cj.out
```

### 读取字符集功能示例

注意：字符集简介文件存放于项目的 test/LLT 目录下

```cangjie
import std.fs.*
import charset4cj.charset.*
import std.unittest.*
import std.unittest.testmacro.*

main() {
    let ccc = Test_ReadMe01()
    let res = ccc.asTestSuite().runTests()
    let fail = res.failedCount + res.errorCount
    if (fail == 0) {
      return 0
    }
    return 1
}
@Test
public class Test_ReadMe01 {
    @TestCase
    public func testReadMe01(): Unit {
		var f:File = File("./字符集简介.md", Read)
		var sr = TextReader(f, charset: Charsets.GB18030, bufSize:120)
		var lineOp:Option<String>=Option<String>.Some("origin")
		while(true){
			lineOp = sr.readln()
			if(lineOp == None){
				break
			}
			lineOp.getOrThrow()
		}
        @Assert(lineOp==None, true)
    }
}
```

执行结果如下：
```shell
0
```

### EUCJP 字符集编码解码功能示例

```cangjie
import std.fs.*
import charset4cj.charset.*
import std.unittest.*
import std.unittest.testmacro.*

main() {
    let ccc = Test_ReadMe02()
    let res = ccc.asTestSuite().runTests()
    let fail = res.failedCount + res.errorCount
    if (fail == 0) {
      return 0
    }
    return 1
}
@Test
public class Test_ReadMe02 {
    let str: String = "z,ncm,xzjiu"
    let str_en: String = "￡％＃＆＊＠§"
    @TestCase
    public func testReadMe02(): Unit {
        var jp = Charsets.EUCJP
        var jpen = jp.newEncoder()
        var jpde = jp.newDecoder()
        let src: Array<UInt8> = jpen.encode(str)
        let src2: Array<UInt8> = jpen.encode(str_en)
        let des=Array<Char>(30,repeat:'0')
        let res = jpde.decode(src, des)
        jpde.decode(src2, des)
        @Assert(res[0], 11)
        @Assert(res[1], 11)
    }
}
```

执行结果如下：
```shell
0
```

注意：用例需放入 `test/LLT` 下

## 约束与限制

 在下述版本验证通过： 

| 编号 | 依赖构建工具                                 | 版本号         |
| ---- | -------------------------------------------- | -------------- |
| 1    | **cjc**                                      | v1.1.3 |

## 开源协议

本项目基于 [MulanPSL-2.0](https://gitcode.com/Cangjie-TPC/charset4cj/blob/develop/LICENSE) ，请自由的享受和参与开源。

## <img alt="" src="https://raw.gitcode.com/Cangjie-TPC/charset4cj/blobs/db89f3665c31896952fbb4c657fd09d30adf952b/readme-icon-contribute.png" style="display: inline-block;" width=3%/> 参与贡献

欢迎给我们提交 PR，欢迎给我们提交 issue，欢迎参与任何形式的贡献。
