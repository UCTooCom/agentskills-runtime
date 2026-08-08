### 三方库设计说明

#### 1 需求场景分析

基于仓颉语言实现的文件压缩和解压缩。

#### 2 三方库对外提供的特性

(1) zip 压缩和解压缩。

(2) gzip 的压缩和解压缩。

(3) tar 的创建和提取。

(4) tar.gz 的压缩和解压缩。

#### 3 License分析

Apache License 2.0

|  Permissions   | Limitations  |
|  ----  | ----  |
| Commercial use | Trademark use |
| Modification | Liability |
| Distribution | Warranty |
| Patent use |  |
| Private use |  |

#### 4 依赖分析 

仓颉三方库 charset


#### 5 特性设计文档

##### 5.1 核心特性1 

###### 5.1.1 特性介绍

    支持 tar 创建和提取。

###### 5.1.2 实现方案

    参考：https://github.com/srikanth-lingala/zip4j

###### 5.1.3 接口设计

💡 TarFile  tar 创建和解压。

| 成员函数 | 入参 | 返回值 | 作用描述 |
| --- | --- |  --- | --- |
| extractTar  | file: Array&lt;UInt8&gt; | / | 实现 tar 解压 |
| storeTar   | targetFile: String | / |  将目标文件夹里的文件打包成 tar 文件|

###### 5.1.4 展示示例

```
var tf = TarFile()
tf.outPath = "/mnt/c/Users/lizhenjie/Desktop/"
var file = FileUtils.readFile("/mnt/c/Users/lizhenjie/Desktop/water_analysis.tar")
tf.extractTar(file)
``` 
##### 5.2 核心特性1 

###### 5.2.1 特性介绍

    支持 GZIP 压缩和解压。

###### 5.2.2 实现方案

    参考：https://github.com/srikanth-lingala/zip4j

###### 5.2.3 接口设计

💡 GZUtils GZIP 压缩和解压。

| 成员变量  | 类型 | 返回值 |作用描述 |
| --- | --- | --- | --|
| compress   |filePath: String<br> outPath: String|Int64|实现 GZIP 压缩 |
| decompress   | filePath: String<br> outPath: String|Int64|实现 GZIP 解压 |

###### 5.2.4 展示示例

GZIP 压缩

```
GZUtils.compress("/mnt/c/Users/lizhenjie/Desktop/test.txt", "test.gz")
```
GZIP 解缩

```
GZUtils.deCompress("/mnt/c/Users/lizhenjie/Desktop/test.gz,text.txt")

```

##### 5.3 核心特性1 

###### 5.3.1 特性介绍

    支持 ZIP 压缩文件功能。

###### 5.3.2 实现方案

    参考：https://github.com/srikanth-lingala/zip4j

###### 5.3.3 接口设计

💡 ZipFile  提供 ZIP 压缩文件功能

| 成员函数 | 入参 | 返回值 | 作用描述 |
| --- | --- | --- | ---  |
| init   |/  | / | Zip 压缩初始化 |
| init   |filePath: String  | / |Zip 压缩初始化 |
|addFile  |file: String  |/  |Zip 添加压缩的文件 |
| addFiles |files: HashSet&lt;String&gt;  |/  |Zip 添加压缩的文件集合 |
|writeZip  |/  | / | Zip 压缩|
| extractAll |ArrayList&lt;LocalFileHeader&gt;  | / |Zip 提取所有解压后的数据 |
|nameList  | / | Array&lt;Stringr&gt;|获取压缩包中的目录 |
|setOutPath  |outPath: String  | / | Zip 设置文件压缩后的路径|

###### 5.3.4 展示示例

ZIP 压缩
```
var zipFile= ZipFile()
zipFile.setOutPath("/mnt/c/Users/lizhenjie/Desktop/test.zip")
zipFile.addFile("/mnt/c/Users/lizhenjie/Desktop/test.txt")
zipFile.addFile("/mnt/c/Users/lizhenjie/Desktop/aaa.docx")
zipFile.writeZip()
```
ZIP 压缩

```
var zipFile= ZipFile("/mnt/c/Users/lizhenjie/Desktop/MisLinks.zip")
zipFile.setOutPath("/mnt/c/Users/lizhenjie/Desktop/MisLinks")
zipFile.extractAll()
```

##### 5.4 核心特性1 

###### 5.4.1 特性介绍

    提供了一些文件操作方法。

###### 5.4.2 实现方案

    参考：https://github.com/srikanth-lingala/zip4j

###### 5.4.3 接口设计
💡 FileUtils 该类提供了一些文件操作方法。

| 成员函数 | 入参 | 返回值 | 作用描述 |
| --- | --- | --- | ---  |
| getFilePath   |outPath: String<br/> fileName: String  |String | 获取文件名 |
| getFileName   |path: String  |String | 获取文件名 |
| readFile   | path: String |Array&lt;UInt8&gt; | 根据文件路径读取文件 |
| writeFile   | outData: Array&lt;UInt8&gt;, filePath: String |/ |根据文件内容和路径写入文件 |

###### 5.4.4 展示示例

```
FileUtils.getFileName("/mnt/c/Users/lizhenjie/Desktop/MisLinks.zip")
```
