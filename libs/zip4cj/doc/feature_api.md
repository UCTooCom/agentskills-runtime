# zip4cj 库

### 介绍

zip4cj 是基于仓颉语言实现的文件压缩和解压缩。

### 1 支持Zip文件的创建、添加、解压

场景：
1. 支持zip文件的创建、添加、解压.
是否商用：是
目标：功能上与对标库功能保持一致
验收标准：
1.  文件的创建、添加、解压、更新、移除功能正常
设计方案：待补充
依赖的需求：N/A
屏蔽用例：N/A
性能指标：可参考 java 对标库性能用例，与对标库持平
API测试范围：public 接口

#### 1.1 支持Zip文件的创建

支持Zip文件的创建

##### 1.1.1 主要接口

```
public class ZipFile <: Resource {

    /*
     * 构造 
     * 
     * 参数 zipFile - 文件路径字符串
     * 参数 password - 密码
     */
    public init (zipFile: String, password: Array<Rune>)
    
    /*
     * 构造 
     * 
     * 参数 zipFile - 文件路径字符串
     */
    public init (zipFile: String)


    /*
     * 构造 
     * 
     * 参数 zipFile - 文件路径对象
     */
    public init (zipFile: Path)
    
    /*
     * 构造 
     * 
     * 参数 zipFile - 文件路径对象
     * 参数 password - 密码
     */
    public init (zipFile: Path, password: Array<Rune>)

    /*
     * 是否在子线程中执行
     * 
     * 返回值 Bool - 布尔值
     */
    public func isRunInThread(): Bool 

    /*
     * 设置是否在子线程中执行
     * 
     * 参数 Bool - 布尔值
     * 返回值 Unit - Unit
     */
    public func setRunInThread(runInThread: Bool) : Unit
    
    /*
     * 使用默认zip参数将输入源文件添加到zip文件中。如果zip文件不存在，此方法将创建一个新的zip文件。
     * 
     * 参数 fileToAdd - 文件字符串
     * 返回值 Unit - Unit
     */
    public func addFile(fileToAdd: String)

    /*
     * 使用默认zip参数将输入源文件添加到zip文件中。如果zip文件不存在，此方法将创建一个新的zip文件。
     * 
     * 参数 fileToAdd - 文件字符串
     * 参数 parameters - 压缩参数
     * 返回值 Unit - Unit
     */
    public func addFile(fileToAdd: String, parameters: ZipParameters)

    /*
     * 使用默认zip参数将输入源文件添加到zip文件中。如果zip文件不存在，此方法将创建一个新的zip文件。
     * 
     * 参数 fileToAdd - 文件路径
     * 参数 parameters - 参数, 默认为初始类
     * 返回值 Unit - Unit
     */
    public func addFile(fileToAdd: Path)

    /*
     * 使用默认zip参数将输入源文件添加到zip文件中。如果zip文件不存在，此方法将创建一个新的zip文件。
     * 
     * 参数 fileToAdd - 文件路径
     * 参数 parameters - 压缩参数
     * 返回值 Unit - Unit
     */
    public func addFile(fileToAdd: Path, parameters: ZipParameters)
    
    /*
     * 使用默认zip参数将输入文件列表添加到zip文件中。如果zip文件不存在，此方法将创建一个新的zip文件。
     * 
     * 参数 filesToAdd - 文件路径集合
     * 返回值 Unit - Unit
     */
    public func addFiles(filesToAdd: Collection<Path>) 

    /*
     * 使用默认zip参数将输入文件列表添加到zip文件中。如果zip文件不存在，此方法将创建一个新的zip文件。
     * 
     * 参数 filesToAdd - 文件路径集合
     * 参数 parameters - 压缩参数
     * 返回值 Unit - Unit
     */
    public func addFiles(filesToAdd: Collection<Path>, parameters: ZipParameters) 

    /*
     * 使用默认zip参数将输入文件列表添加到zip文件中。如果zip文件不存在，此方法将创建一个新的zip文件。
     * 
     * 参数 filesToAdd - 文件路径数组
     * 返回值 Unit - Unit
     */
    public func addFiles(filesToAdd: Array<Path>) 

    /*
     * 使用默认zip参数将输入文件列表添加到zip文件中。如果zip文件不存在，此方法将创建一个新的zip文件。
     * 
     * 参数 filesToAdd - 文件路径数组
     * 参数 parameters - 压缩参数
     * 返回值 Unit - Unit
     */
    public func addFiles(filesToAdd: Array<Path>, parameters: ZipParameters) 

    /*
     * 创建分卷压缩文件，并将指定的文件添加到压缩文件中
     * 
     * 参数 filesToAdd - 压缩文件列表, 如果路径不存在, 则抛 zipException
     * 参数 parameters - 压缩参数
     * 参数 splitArchive - 是否分卷
     * 参数 splitLength - 分卷大小, 若选择需要分卷, 分卷大小需要大于等于65536
     */
    public func createSplitZipFile(filesToAdd: Collection<Path>, parameters: ZipParameters, splitArchive: Bool, splitLength: Int64)

     /*
     * 创建分卷压缩文件，并将指定的文件添加到压缩文件中
     * 
     * 参数 filesToAdd - 压缩文件列表, 如果路径不存在, 则抛 zipException
     * 参数 parameters - 压缩参数
     * 参数 splitArchive - 是否分卷
     * 参数 splitLength - 分卷大小, 若选择需要分卷, 分卷大小需要大于等于65536
     */
    public func createSplitZipFile(filesToAdd: Array<Path>, parameters: ZipParameters, splitArchive: Bool, splitLength: Int64)
    
    /*
     * 创建压缩文件，并将指定输入流中的文件添加到压缩文件中, 使用此接口时需要先通过parameters设置fileName, 否则会抛ZipException
     * 
     * 参数 inputStream - 压缩流
     * 参数 parameters - 压缩参数
     * 参数 splitArchive - 是否分卷
     * 参数 splitLength - 分卷大小, 若选择需要分卷, 分卷大小需要大于等于65536
     */
    public func createSplitZipFile(inputStream: InputStream, parameters: ZipParameters, splitArchive: Bool, splitLength: Int64)
    
    /*
     * 创建压缩文件，并将指定文件夹中的文件添加到压缩文件中
     * 
     * 参数 folderToAdd - 压缩文件夹路径
     * 参数 parameters - 压缩参数
     * 参数 splitArchive - 是否分卷
     * 参数 splitLength - 分卷大小, 若选择需要分卷, 分卷大小需要大于等于65536
     */
    public func createSplitZipFileFromFolder(folderToAdd: Path, parameters: ZipParameters, splitArchive: Bool, splitLength: Int64)
    
    /*
     * 将给定zip文件中的所有文件提取到输入目标路径。如果zip文件不存在或目标路径无效，则抛出异常
     * 
     * 参数 destinationPath - 解压路径, 如果需要解压的zip文件无效的, 则抛 zipException
     */
    public func extractAll (destinationPath: String)
    
    /*
     * 将给定zip文件中的所有文件提取到输入目标路径。如果zip文件不存在或目标路径无效，则抛出异常
     * 
     * 参数 destinationPath - 解压路径
     * 参数 unzipParameters - 解压参数, 如果需要解压的zip文件无效的, 则抛 zipException
     */
    public func extractAll(destinationPath: String, unzipParameters: UnzipParameters)

    /*
     * 将给定文件对象中的文件夹添加到具有默认zip参数的zip文件中。如果zip文件不存在，则创建一个新的zip文件。如果输入文件夹无效，则抛出异常。
     * 
     * 参数 folderToAdd - Path路径
     */
    public func addFolder(folderToAdd: Path)

    /*
     * 将给定文件对象中的文件夹添加到zip文件中。如果zip文件不存在，则创建一个新的zip文件。如果输入文件夹无效，则抛出异常。可以在输入参数中设置要添加的文件夹中文件的Zip参数
     * 
     * 参数 folderToAdd - Path路径
     * 参数 zipParameters - zipParameters压缩参数
     * 参数 checkSplitArchive - 是否选中拆分存档, 默认为true
     */
    public func addFolder(folderToAdd: Path, zipParameters: ZipParameters, checkSplitArchive: Bool)

    /*
     * 从zip文件中删除输入文件头中提供的文件。如果zip文件是拆分的zip文件，则此方法会抛出异常，因为zip规范不允许更新拆分的zip存档。
     * 如果此文件头是一个目录，则此目录下的所有文件和目录也将被删除。
     * 
     * 参数 fileName - FileHeader
     */
    public func removeFile (fileName: FileHeader)

    /*
     * 从zip文件中删除输入文件头中提供的文件。如果zip文件是拆分的zip文件，则此方法会抛出异常，因为zip规范不允许更新拆分的zip存档。
     * 如果此文件头是一个目录，则此目录下的所有文件和目录也将被删除。
     * 
     * 参数 fileName - fileName
     */
    public func removeFile (fileName: String)


    /*
     * 重命名由文件头表示的条目的文件名。如果输入文件头中的文件名与zip文件中的任何条目都不匹配，则不会修改zip文件。
     * 如果文件头是zip文件中的文件夹，则zip文件中所有的子文件和子文件夹也将被重命名。Zip文件格式不允许修改拆分的Zip文件。
     * 因此，如果处理的zip文件是拆分的zip文件，则此方法会抛出异常
     * 
     * 参数 fileNameToRename - 旧文件名的FileHeader
     * 参数 newFileName - 新文件名
     */
    public func renameFile (fileNameToRename: FileHeader, newFileName: String): Unit

    /*
     * 重命名由文件头表示的条目的文件名。如果输入文件头中的文件名与zip文件中的任何条目都不匹配，则不会修改zip文件。
     * 如果文件头是zip文件中的文件夹，则zip文件中所有的子文件和子文件夹也将被重命名。Zip文件格式不允许修改拆分的Zip文件。
     * 因此，如果处理的zip文件是拆分的zip文件，则此方法会抛出异常
     * 
     * 参数 fileNameToRename - 旧文件名
     * 参数 newFileName - 新文件名
     */
    public func renameFile (fileNameToRename: String, newFileName: String): Unit

    /*
     * 在zip文件中创建一个新条目，并将输入流的内容添加到zip文件中。必须在输入参数中设置ZipParameters.isSourceExternalStream和ZipParameters.fileNameInZip。
     * 如果文件名以/或\结尾，则此方法将内容视为目录。将ProgressMonitor.setRunInThread标志设置为true对此方法无效，因此此方法不能用于在线程模式下向zip添加内容
     * 
     * 参数 inputStream - 输入流
     * 参数 parameters - 参数
     */
    public func addStream (inputStream: InputStream, parameters: ZipParameters): Unit

    /*
     * 从zip文件中删除与输入列表中的名称匹配的所有文件。如果任何文件是目录，则此目录下的所有文件和目录也将被删除。
     * 如果zip文件是拆分的zip文件，则此方法会抛出异常，因为zip规范不允许更新拆分的zip存档。
     * 
     * 参数 fileNames - 文件名集合
     */
    public func removeFiles (fileNames: Collection<String>): Unit

    /*
     * 将zip文件中与映射中的键匹配的所有条目重命名为映射中的相应值。
     * 如果没有与映射中的任何键匹配的条目，则不会修改zip文件。
     * 如果映射中的任何条目表示一个文件夹，则所有文件和文件夹都将被重命名，以便它们的父级表示重命名的文件夹。
     * Zip文件格式不允许修改拆分的Zip文件。因此，如果处理的zip文件是拆分的zip文件，则此方法会抛出异常
     * 
     * 参数 fileNamesMap - 映射文件名<旧文件名, 新文件名>
     */
    public func renameFiles (fileNamesMap: Map<String,String>): Unit

    /*
     * 将拆分的zip文件合并为一个zip文件，而无需提取存档中的文件
     * 
     * 参数 outputZipFile - 输出zipfile
     */
    public func mergeSplitFiles (outputZipFile: Path): Unit
    
    /*
     * 为Zip文件设置注释
     * 
     * 参数 comment - 注释
     * 返回值 Unit - Unit
     */
    public func setComment (comment: String): Unit
    
    /*
     * 返回Zip文件的注释集
     * 
     * 返回值 String - 注释
     */
    public func getComment (): String
    
    /*
     * 返回一个输入流，用于读取与输入FileHeader对应的Zip文件的内容。如果ZipFile中不存在FileHeader，则抛出异常
     * 
     * 参数 fileHeader - 文件头
     * 返回值 ZipInputStream - 输入流
     */
    public func getInputStream (fileHeader: FileHeader): ZipInputStream
    
    /*
     * 检查输入的zip文件是否是有效的zip文件。此方法将尝试读取zip标头。
     * 如果成功读取了标头，则此方法返回true，否则返回false。
     * 如果zip文件是拆分的zip文件，此方法还会检查zip的所有拆分文件是否存在。
     * 
     * 返回值 Bool - 判断 是否有效的zip文件
     */
    public func isValidZipFile (): Bool
    
    /*
     * 返回ArrayList中所有拆分zip文件的完整文件路径和名称。
     * 例如：如果一个分割的zip文件（abc.zip）有10个分割部分，则此方法返回一个数组列表，其中包含路径+“abc.z01”、路径+“abc.z02”等。
     * 如果zip文件不存在，则返回空集合
     * 
     * 返回值 ArrayList<Path> - zip文件集合
     */
    public func getSplitZipFiles (): ArrayList<Path>
    
    /*
     * 关闭此类实例打开的所有开放流, 当底层输入流在尝试关闭时抛出异常
     * 
     * 返回值 Unit - Unit
     */
    public func close (): Unit
    
    /*
     * 设置用于zip文件的密码。如果通过ZipFile构造函数提供密码且password不为None，将覆盖
     * 
     * 参数 password - 密码
     * 返回值 Unit - Unit
     */
    public func setPassword (password: ?Array<Rune>)
    
    /*
     * 获取 缓存大小
     * 
     * 返回值 Int64 - 大小
     */
    public func getBufferSize (): Int64
    
    /*
     * 设置 缓存大小
     * 
     * 参数 bufferSize - 大小, 如果 buffersize小于512, 则抛 无效参数异常
     */
    public func setBufferSize (bufferSize: Int64): Unit
    
    /*
     * 获取 进度监控器
     * 
     * 返回值 ProgressMonitor - 进度监控器
     */
    public func getProgressMonitor (): ProgressMonitor
    
    /*
     * 获取 文件
     * 
     * 返回值 Path - 文件路径
     */
    public func getFile (): Path
    
    /*
     * 获取 ExecutorService 执行组件
     * 
     * 返回值 ExecutorService - 执行组件
     */
    public func getExecutorService (): ExecutorService
    
    /*
     * 返回子类的字符串表示. 
     * 
     * 返回值 String - 字符串
     */
    public func toString (): String
    
    /*
     * 判断 是否使用Utf8字符集进行密码
     * 
     * 返回值 Bool - 是否使用Utf8字符集进行密码
     */
    public func isUseUtf8CharsetForPasswords (): Bool
    
    /*
     * 设置 是否使用Utf8字符集进行密码
     * 
     * 参数 useUtf8CharsetForPasswords - 是否使用Utf8字符集进行密码
     */
    public func setUseUtf8CharsetForPasswords (useUtf8CharsetForPasswords: Bool): Unit
}
```

### 2 支持Zip流式压缩和解压

场景：
1. 支持zip流式压缩和解压
是否商用：是
目标：功能上与对标库功能保持一致
验收标准：
1. 使用大文件和大文件夹对zip的压缩功能进行测试
2. 使用zip大文件对解压功能进行测试
设计方案：待补充
依赖的需求：N/A
屏蔽用例：N/A
性能指标：可参考 java 对标库性能用例，与对标库持平
API测试范围：public 接口

#### 2.1 支持zip的输入流

持zip的输入流

##### 2.1.1 主要接口

```
```

#### 2.2 支持zip的输出流

持zip的输出流

##### 2.2.1 主要接口

```
```

### 3 支持Zip64格式

场景：
1. 对于单个大于4 G的文件, 需要使用zip64进行压缩和解压
是否商用：是
目标：功能上与对标库功能保持一致
验收标准：
1. 使用单个大于4 G的文件进行测试
设计方案：待补充
依赖的需求：N/A
屏蔽用例：N/A
性能指标：可参考 java 对标库性能用例，与对标库持平
API测试范围：public 接口

#### 3.1 支持Zip64格式

支持Zip文件的创建

##### 3.1.1 主要接口

```
```

### 其他接口

```
public class CipherInputStream<T> <: InputStream {
    
    /*
     * 构造 
     * 
     * 参数 zipEntryInputStream - ZipEntryInputStream输入流
     * 参数 localFileHeader - 本地文件头
     * 参数 password - 密码
     * 参数 bufferSize - 缓冲区容量
     * 参数 useUtf8ForPassword - 使用utf8编码密码
     * 参数 decrypter - 解密器
     */
    public init (zipEntryInputStream: ZipEntryInputStream, localFileHeader: LocalFileHeader, password: ?Array<Rune>, bufferSize: Int64, useUtf8ForPassword: Bool, decrypter: initDecrypter<T>)
    
    /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 关闭流
     */
    public func close (): Unit
    
    /*
     * 获取 LastReadRawDataCa
     * 
     * 返回值 Array<Byte> - 获取到的 LastReadRawDataCa
     */
    public func getLastReadRawDataCache (): Array<Byte>
    
    /*
     * 获取 Decryp
     * 
     * 返回值 T - 获取到的 Decryp
     */
    public func getDecrypter (): T
    
    /*
     * 获取 LocalFileHeader
     * 
     * 返回值 LocalFileHeader - 获取到的LocalFileHea
     */
    public func getLocalFileHeader (): LocalFileHeader
}

public class UnzipUtil {
    
    /*
     * 创建一个ZipInputStream
     * 
     * 参数 zipModel - 压缩模型
     * 参数 fileHeader - 文件头
     * 参数 password - 密码
     * 返回值 ZipInputStream - 创建的ZipInputStream
     */
    public static func createZipInputStream (zipModel: ZipModel, fileHeader: FileHeader, password: ?Array<Rune>): ZipInputStream
    
    /*
     * 应用文件属性
     * 
     * 参数 fileHeader - 文件头
     * 参数 path - 路径
     */
    public static func applyFileAttributes (fileHeader: FileHeader, path: Path)
    
    /*
     * 创建一个SplitFileInputStream
     * 
     * 参数 zipModel - 压缩模型
     * 返回值 SplitFileInputStream - 创建的SplitFileInputStream
     */
    public static func createSplitInputStream (zipModel: ZipModel): SplitFileInputStream
}

public class PushbackInputStream<: InputStream {
    
    /*
     * 构造 
     * 
     * 参数 input - 输入流
     * 参数 size - 流大小
     */
    public init (input: InputStream, size: Int64)
    
    /*
     * 构造 
     * 
     * 参数 input - 输入流
     */
    public init (input: InputStream)
    
    /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (): Int64
    
    /*
     * 
     * 
     * 参数 b - 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 回退
     * 
     * 参数 b - 回退数据量
     */
    public func  unread(b: Int64)
    
    /*
     * 回退
     * 
     * 参数 b - 回退的数据
     * 参数 off - 数据开头
     * 参数 len - 数据长度
     */
    public func unread (b: Array<Byte>, off: Int64, len: Int64)
    
    /*
     * 回退
     * 
     * 参数 b - 回退的数据
     */
    public func unread (b: Array<Byte>)
    
    /*
     * 读取跳过
     * 
     * 参数 n - 跳过数量
     * 返回值 Int64 - 跳过数量
     */
    public func skip (n: Int64): Int64
    
    /*
     * 是否支持mark操作
     *
     * 返回值 Bool - 固定返回false
     */
    public func markSupported ()
    
    /*
     * 标记位置
     * 
     * 参数 readlimit - 位置
     */
    public func mark (readlimit: Int64)
    
    /*
     * 重置流
     */
    public func reset ()
    
    /*
     * 关闭流
     */
    public func close ()
}

public class NumberedSplitRandomAccessFile<: RandomAccessFile {
    
    /*
     * 构造 
     * 
     * 参数 name - 文件路径
     * 参数 mode - 打开模式
     */
    public init (name: String, mode: String)
    
    /*
     * 构造 
     * 
     * 参数 file - 文件路径
     * 参数 mode - 打开模式
     */
    public init (file: Path, mode: String)
    
    /*
     * 构造 
     * 
     * 参数 file - 文件路径
     * 参数 mode - 打开模式
     * 参数 allSortedSplitFiles - 文件路径
     */
    public init (file: Path, mode: String, allSortedSplitFiles: Array<Path>)
    
    /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数量
     */
    public func readByte (): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 写数据
     * 
     * 参数 b - 写入大小
     */
    public func write (b: Int32)
    
    /*
     * 写数据
     * 
     * 参数 b - 写入的数据
     */
    public func write (b: Array<Byte>)
    
    /*
     * 写数据
     * 
     * 参数 buffer - 写入的数据
     * 参数 off - 数据开头
     * 参数 count - 数据长度
     */
    public func write (buffer: Array<Byte>, off: Int64, count: Int64)
    
    /*
     * 将光标跳转到指定位置
     * 
     * 参数 pos - 光标位置
     */
    public func seek (pos: Int64)
    
    /*
     * 获取 FilePoin
     * 
     * 返回值 Int64 - 获取当前光标位置
     */
    public func getFilePointer (): Int64
    
    /*
     * 关闭流
     */
    public func close ()
    
    /*
     * 光标移动
     * 
     * 参数 pos - 移动位置
     */
    public func seekInCurrentPart (pos: Int64)
    
    /*
     * 读取最后分割文件
     */
    public func openLastSplitFileForReading ()
}

public abstract class SplitFileInputStream<: InputStream {
    
    /*
     * 准备文件头
     * 
     * 参数 fileHeader - 文件头
     */
    public func prepareExtractionForFileHeader (fileHeader: FileHeader): Unit
}

public class ZipInputStream<: InputStream {

    /*
     * 构造 ZipInputStream类. 
     * 
     * 参数 inputStream - 输入流
     * 参数 password - 密码, 暂时不支持, 默认为None
     * 参数 passwordCallback - 密码回调, 默认为None
     * 参数 zip4jConfig - zip配置对象
     */
    public init (inputStream: InputStream, password!: ?Array<Rune> = None, passwordCallback!: ?PasswordCallback = None, zip4jConfig!: Zip4cjConfig = Zip4cjConfig(Option<Charset>.None, InternalZipConstants.BUFF_SIZE, InternalZipConstants.USE_UTF8_FOR_PASSWORD_ENCODING_DECODING))

    /*
     * 获取 下一个条目
     * 
     * 参数 fileHeader - 文件头
     * 参数 readUntilEndOfCurrentEntryIfOpen - 是否读取到当前结束
     * 返回值 ?LocalFileHeader - 本地文件头
     */
    public func getNextEntry (fileHeader: ?FileHeader, readUntilEndOfCurrentEntryIfOpen: Bool): ?LocalFileHeader
    
    /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 关闭流
     */
    public func close (): Unit
    
    /*
     * 剩余数据
     * 
     * 返回值 Int64 - 剩余数据
     */
    public func available (): Int64
    
    /*
     * 设置 password
     * 
     * 参数 password - 密码
     */
    public func setPassword (password: ?Array<Rune>): Unit
}

public class InflaterInputStream<: DecompressedInputStream {
    
    /*
     * 构造 
     * 
     * 参数 cipherInputStream - CipherInputStream流
     * 参数 bufferSize - 缓冲区大小
     */
    public init (cipherInputStream: CipherInputStream<Decrypter>, bufferSize: Int64)
    
    /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 数据结束
     * 
     * 参数 inputStream - 输入流
     * 参数 numberOfBytesPushedBack - 回退数据
     */
    public func endOfEntryReached (inputStream: InputStream, numberOfBytesPushedBack: Int64)
    
    /*
     * 关闭流
     */
    public func close (): Unit
}

public interface Decrypter {

    /*
     * 解密数据
     * 
     * 参数 buff - 数据缓冲区
     * 参数 start - 开始位置
     * 参数 len - 长度
     * 返回值 Int64 - 解密的数据量
     */
    func decryptData(buff: Array<Byte>, start: Int64, len: Int64): Int64

}

public class DecompressedInputStream<: InputStream {
    
    /*
     * 构造 
     * 
     * 参数 cipherInputStream - 
     */
    public init (cipherInputStream: CipherInputStream<Decrypter>)
    
        /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 关闭流
     */
    public open func close (): Unit
    
    /*
     * 结束
     * 
     * 参数 inputStream - 输入流
     * 参数 numberOfBytesPushedBack - 回退数据
     */
    public open func endOfEntryReached (inputStream: InputStream, numberOfBytesPushedBack: Int64): Unit
    
    /*
     * 回退设置
     * 
     * 参数 pushbackInputStream - pushbackInputStream流
     * 返回值 Int64 - 回退数据量
     */
    public open func pushBackInputStreamIfNecessary (pushbackInputStream: PushbackInputStream): Int64
}

public class ZipEntryInputStream<: InputStream {
    
    /*
     * 构造 
     * 
     * 参数 inputStream - 输入流
     * 参数 compressedSize - 压缩大小
     */
    public init (inputStream: InputStream, compressedSize: Int64)
    
    /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 全部读取
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func readRawFully (b: Array<Byte>): Int64
    
    /*
     * 关闭流
     */
    public func close (): Unit
    
    /*
     * 获取 NumberOfBytesRead
     * 
     * 返回值 Int64 - 获取到的NumberOfBytesRead
     */
    public func getNumberOfBytesRead (): Int64
}

public class ZipStandardSplitFileInputStream<: SplitFileInputStream {
    
    /*
     * 构造 
     * 
     * 参数 zipFile - 文件路径
     * 参数 isSplitZipArchive - 是否分卷
     * 参数 lastSplitZipFileNumber - 分卷大小
     */
    public init (zipFile: Path, isSplitZipArchive: Bool, lastSplitZipFileNumber: Int64)
    
    /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 准备文件头
     * 
     * 参数 fileHeader - 文件头信息
     */
    public func prepareExtractionForFileHeader (fileHeader: FileHeader): Unit
    
    /*
     * 关闭流
     */
    public func close (): Unit
}

public class HeaderReader {
    
    /*
     * 构造 
     */
    public init ()
    
    /*
     * 读取文件头
     * 
     * 参数 zip4cjRaf - 原始文件
     * 参数 zip4cjConfig - 文件配置
     */
    public func readAllHeaders (zip4cjRaf: RandomAccessFile, zip4cjConfig: Zip4cjConfig)
    
    /*
     * 读取Zip64EndOfCentralDirectoryLocator
     * 
     * 参数 zip4cjRaf - 原始文件
     * 参数 rawIO - RawIO对象
     * 参数 offsetEndOfCentralDirectoryRecord - offsetEndOfCentralDirectoryRecord值
     * 返回值 ?Zip64EndOfCentralDirectoryLocator - 返回Zip64EndOfCentralDirectoryLocator
     */
    public func readZip64EndOfCentralDirectoryLocator (zip4cjRaf: RandomAccessFile, rawIO: RawIO, offsetEndOfCentralDirectoryRecord: Int64): ?Zip64EndOfCentralDirectoryLocator
    
    /*
     * 读取文件头
     * 
     * 参数 inputStream - 输入流
     * 参数 charset - charset对象
     * 返回值 ?LocalFileHeader - 获取的文件头
     */
    public func readLocalFileHeader (inputStream: InputStream, charset: ?Charset): ?LocalFileHeader
    
    /*
     * 判断文件夹
     * 
     * 参数 externalFileAttributes - 文件信息
     * 参数 fileName - 文件名
     * 返回值 Bool - 是否文件夹
     */
    public func isDirectory (externalFileAttributes: Array<Byte>, fileName: ?String): Bool
}

public class NumberedSplitFileInputStream<: SplitFileInputStream {
    
    /*
     * 构造 
     * 
     * 参数 zipFile - zip文件
     */
    public init (zipFile: Path)
    
        /*
     * 读取数据
     * 
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    public func read (b: Array<Byte>, off: Int64, len: Int64): Int64
    
    /*
     * 准备文件头
     * 
     * 参数 fileHeader - 文件头
     */
    public func prepareExtractionForFileHeader (fileHeader: FileHeader): Unit
    
    /*
     * 关闭流
     */
    public func close (): Unit
}

public class DeflaterOutputStream<: CompressedOutputStream {
    
    /*
     * 构造 
     * 
     * 参数 cipherOutputStream - CipherOutputStream流对象
     * 参数 compressionLevel - 压缩等级
     * 参数 bufferSize - 缓冲区大小
     */
    public init (cipherOutputStream: CipherOutputStream, compressionLevel: CompressionLevel, bufferSize: Int64)
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     */
    public func write (b: Array<UInt8>): Unit
    
    /*
     * 写数据
     * 
     * 参数 bval - 要写的数据
     */
    public func write (bval: Int32): Unit
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     * 参数 off - 数据开头
     * 参数 len - 数据长度
     */
    public func write (b: Array<UInt8>, off: Int64, len: Int64): Unit
    
    /*
     * 关闭流
     */
    public func closeEntry (): Unit
}

public abstract class CipherOutputStream<: OutputStream {
    
    /*
     * 构造 
     * 
     * 参数 zipEntryOutputStream - ZipEntryOutputStream流
     * 参数 zipParameters - 参数
     * 参数 password - 密码
     * 参数 useUtf8ForPassword - 是否使用utf编码密码
     */
    public init (zipEntryOutputStream: ZipEntryOutputStream, zipParameters: ZipParameters, password: ?Array<Rune>, useUtf8ForPassword: Bool)
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     */
    public func write (b: Array<UInt8>): Unit
    
    /*
     * 写数据
     * 
     * 参数 bval - 要写的数据
     */
    public func write (bval: Int32): Unit
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     * 参数 off - 数据开头
     * 参数 len - 数据长度
     */
    public func write (b: Array<UInt8>, off: Int64, len: Int64): Unit
    
    /*
     * 写头数据
     * 
     * 参数 b - 数据
     */
    open public func writeHeaders (b: Array<UInt8>): Unit
    
    /*
     * 关闭Entry
     */
    open public func closeEntry (): Unit
    
    /*
     * 关闭流
     */
    open public func close (): Unit
    
    /*
     * 获取 NumberOfBytesWrittenForThisEn
     * 
     * 返回值 Int64 - NumberOfBytesWrittenForThisEn值
     */
    open public func getNumberOfBytesWrittenForThisEntry (): Int64
    
    /*
     * 刷新缓冲区
     */
    open public func flush (): Unit
}

public class ZipEntryOutputStream<: OutputStream {
    
    /*
     * 构造 
     * 
     * 参数 outputStream - 输出流
     */
    public init (outputStream: OutputStream)
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     */
    public func write (b: Array<UInt8>): Unit
    
    /*
     * 写数据
     * 
     * 参数 bval - 要写的数据
     */
    public func write (bval: Int32): Unit
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     * 参数 off - 数据开头
     * 参数 len - 数据长度
     */
    public func write (b: Array<UInt8>, off: Int64, len: Int64): Unit

    /*
     * 关闭Entry
     */
    public func closeEntry (): Unit
    
    /*
     * 获取 NumberOfBytesWrittenForThisEn
     * 
     * 返回值 Int64 - NumberOfBytesWrittenForThisEn值
     */
    public func getNumberOfBytesWrittenForThisEntry (): Int64
    
    /*
     * 刷新流
     */
    public func flush (): Unit
    
    /*
     * 关闭流
     */
    public func close (): Unit
}

public class SplitOutputStream<: OutputStream&OutputStreamWithSplitZipSupport&Resource {
    
    /*
     * 构造 
     * 
     * 参数 file - 文件路径
     */
    public init (file: Path)
    
    /*
     * 构造 
     * 
     * 参数 file - 文件路径
     * 参数 splitLength - 分卷大小
     */
    public init (file: Path, splitLength: Int64)
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     */
    public func write (b: Array<UInt8>): Unit
    
    /*
     * 检查文件大小
     * 
     * 参数 bufferSize - 缓冲区大小
     * 返回值 Bool - 是否通过
     */
    public func checkBufferSizeAndStartNextSplitFile (bufferSize: Int64): Bool
    
    /*
     * 移动光标
     * 
     * 参数 pos - 光标位置
     */
    public func seek (pos: Int64): Unit
    
    /*
     * 跳过字节
     * 
     * 参数 n - 跳过量
     * 返回值 Int64 - 跳过的量
     */
    public func skipBytes (n: Int64): Int64
    
    /*
     * 判断是否关闭
     * 
     * 返回值 Bool - 是否关闭
     */
    public func isClosed ()
    
    /*
     * 关闭流
     */
    public func close ()
    
    /*
     * 获取 FilePoin
     * 
     * 返回值 Int64 - FilePoin
     */
    public func getFilePointer (): Int64
    
    /*
     * 判断 
     * 
     * 返回值 Bool - 是否分卷
     */
    public func isSplitZipFile (): Bool
    
    /*
     * 获取 SplitLen
     * 
     * 返回值 Int64 - 分卷大小
     */
    public func getSplitLength (): Int64
    
    /*
     * 获取 CurrentSplitFileCoun
     * 
     * 返回值 Int32 - 文件数量
     */
    public func getCurrentSplitFileCounter (): Int32
}

public open class CompressedOutputStream<: OutputStream {
    
    /*
     * 构造 
     * 
     * 参数 cipherOutputStream - CipherOutputStream流
     */
    public init (cipherOutputStream: CipherOutputStream)
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     */
    public func write (b: Array<UInt8>): Unit
    
    /*
     * 写数据
     * 
     * 参数 bval - 要写的数据
     */
    public func write (bval: Int32): Unit
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     * 参数 off - 数据开头
     * 参数 len - 数据长度
     */
    public func write (b: Array<UInt8>, off: Int64, len: Int64): Unit
    
    /*
     * 关闭Entry
     */
    open public func closeEntry (): Unit
    
    /*
     * 关闭流
     */
    open public func close (): Unit
    
    /*
     * 获取 getCompressedSize
     * 
     * 返回值 Int64 - 压缩大小
     */
    open public func getCompressedSize (): Int64
    
    /*
     * 刷新流
     */
    open public func flush (): Unit
}

public class ZipOutputStream<: OutputStream {
    
    /*
     * 构造 
     * 
     * 参数 outputStream - 输出流
     * 参数 password - 密码
     * 参数 zip4cjConfig - 配置对象
     * 参数 zipModel - zip模型 , 如果 zip4cjConfig.getBufferSize()小于512, 则抛 IllegalArgumentException
     */
    public init (outputStream: OutputStream, password!: ?Array<Rune>, zip4cjConfig!: Zip4cjConfig, zipModel!: ZipModel)
    
    /*
     * 存入压缩参数
     * 
     * 参数 zipParameters - 参数, 如果 zipParameters的fileName为空, 则抛 IllegalArgumentException
     */
    public func putNextEntry (zipParameters: ZipParameters): Unit
    
    /*
     * 写数据, 使用前请先调用putNextEntry函数, 否则会抛 NoneValueException
     * 
     * 参数 b - 要写的数据
     */
    public func write (b: Array<UInt8>): Unit

    /*
     * 关闭Entry
     * 
     * 返回值 FileHeader - 文件头
     */
    public func closeEntry (): FileHeader
    
    /*
     * 关闭流
     */
    public func close (): Unit
    
    /*
     * 打开流
     */
    public func ensureStreamOpen (): Unit
    
    /*
     * 初始化写入文件头
     * 
     * 参数 zipParameters - 压缩参数
     */
    public func initializeAndWriteFileHeader (zipParameters: ZipParameters): Unit
    
    /*
     * 验证压缩参数
     * 
     * 参数 zipParameters - 参数
     */
    public func verifyZipParameters (zipParameters: ZipParameters): Unit
    
    /*
     * 写入crc
     * 
     * 参数 fileHeader - 文件头
     * 返回值 Bool - 是否写入
     */
    public func writeCrc (fileHeader: FileHeader): Bool
    
    /*
     * 关闭流
     * 
     * 参数 zipParameters - 压缩参数
     * 返回值 ZipParameters - 压缩参数
     */
    public func cloneAndPrepareZipParameters (zipParameters: ZipParameters): ZipParameters
}

public class HeaderWriter {
    
    /*
     * 构造 
     */
    public init ()
    
    /*
     * 写文件头
     * 
     * 参数 zipModel - 压缩模型
     * 参数 localFileHeader - 文件头
     * 参数 outputStream - 输出流
     * 参数 charset - charset对象
     * 返回值 Unit - Unit, 如果localFileHeader的GeneralPurposeFlag为空, 则抛NoneValueException.
     */
    public func writeLocalFileHeader (zipModel: ZipModel, localFileHeader: LocalFileHeader, outputStream: OutputStream, charset: ?Charset)
    
    /*
     * 写入文件信息
     * 
     * 参数 localFileHeader - 文件头
     * 参数 outputStream - 输出流
     */
    public func writeExtendedLocalHeader (localFileHeader: ?LocalFileHeader, outputStream: ?OutputStream)
    
    /*
     * 写入最后的压缩文件信息
     * 
     * 参数 zipModel - 压缩模型
     * 参数 outputStream - 输出流
     * 参数 charset - charset对象
     */
    public func finalizeZipFile (zipModel: ZipModel, outputStream: OutputStream, charset: ?Charset): Unit
    
    /*
     * 完成写入件信息
     * 
     * 参数 zipModel - 压缩模型
     * 参数 outputStream - 输出流
     * 参数 charset - charset对象
     */
    public func finalizeZipFileWithoutValidations(zipModel: ZipModel , outputStream: OutputStream, charset: ?Charset )

    /*
     * 更新文件头信息
     * 
     * 参数 fileHeader - 文件头
     * 参数 zipModel - 压缩模型
     * 参数 outputStream - 输出流
     */
    public func updateLocalFileHeader (fileHeader: FileHeader, zipModel: ZipModel, outputStream: SplitOutputStream)
}

public class CountingOutputStream<: OutputStream&OutputStreamWithSplitZipSupport {
    
    /*
     * 构造 
     * 
     * 参数 outputStream - 输出流
     */
    public init (outputStream: OutputStream)
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     */
    public func write (b: Array<UInt8>): Unit
    
    /*
     * 写数据
     * 
     * 参数 bval - 要写的数据
     */
    public func write (bval: Int32): Unit
    
    /*
     * 写数据
     * 
     * 参数 b - 要写的数据
     * 参数 off - 数据开头
     * 参数 len - 数据长度
     */
    public func write (b: Array<UInt8>, off: Int64, len: Int64): Unit
    
    /*
     * 获取 CurrentSplitFileCoun
     * 
     * 返回值 Int32 - CurrentSplitFileCoun值
     */
    public func getCurrentSplitFileCounter (): Int32
    
    /*
     * 获取 OffsetForNextEn
     * 
     * 返回值 Int64 - OffsetForNextEn值
     */
    public func getOffsetForNextEntry (): Int64
    
    /*
     * 获取 SplitLen
     * 
     * 返回值 Int64 - SplitLen值
     */
    public func getSplitLength (): Int64
    
    /*
     * 判断 
     * 
     * 返回值 Bool - 布尔值
     */
    public func isSplitZipFile (): Bool
    
    /*
     * 获取 NumberOfBytesWrit
     * 
     * 返回值 Int64 - NumberOfBytesWrit值
     */
    public func getNumberOfBytesWritten (): Int64
    
    /*
     * 检查是否分卷
     * 
     * 参数 bufferSize - bufferSize值
     * 返回值 Bool - 布尔值
     */
    public func checkBuffSizeAndStartNextSplitFile (bufferSize: Int32): Bool
    
    /*
     * 获取 FilePoin
     * 
     * 返回值 Int64 - 光标位置
     */
    public func getFilePointer (): Int64
    
    /*
     * 关闭流
     */
    public func close (): Unit
    
    /*
     * 刷新流
     */
    public func flush (): Unit
}

public class HeaderUtil {
    
    /*
     * 获取 FileHeader
     * 
     * 参数 zipModel - 压缩模型
     * 参数 fileNameArg - 字符串
     * 返回值 ?FileHeader - 文件头
     */
    public static func getFileHeader (zipModel: ZipModel, fileNameArg: String): ?FileHeader
    
    /*
     * 用字符集解码字符串
     * 
     * 参数 data -  数据
     * 参数 isUtf8Encoded - 是否utf8
     * 参数 charset - charset对象
     */
    public static func decodeStringWithCharset (data: Array<Byte>, isUtf8Encoded: Bool, charset: ?Charset)
    
    /*
     * 获取 BytesFromStr
     * 
     * 参数 string - 字符串
     * 参数 charset - charset对象
     * 返回值 Array<Byte> - 数组
     */
    public static func getBytesFromString (string: String, charset: ?Charset): Array<Byte>
    
    /*
     * 获取 OffsetStartOfCentralDirect
     * 
     * 参数 zipModel - 压缩模型
     * 返回值 Int64 - 大小
     */
    public static func getOffsetStartOfCentralDirectory (zipModel: ZipModel): Int64
    
    /*
     * 获取 FileHeadersUnderDirect
     * 
     * 参数 allFileHeaders - 文件头
     * 参数 fileName - 字符串
     * 返回值 ArrayList<FileHeader> - 文件头, 如果FileHeader的FileName为空, 则抛NoneValueException.
     */
    public static func getFileHeadersUnderDirectory (allFileHeaders: ArrayList<FileHeader>, fileName: String): ArrayList<FileHeader>
    
    /*
     * 获取 TotalUncompressedSizeOfAllFileHead
     * 
     * 参数 fileHeaders - 文件头
     * 返回值 Int64 - 大小
     */
    public static func getTotalUncompressedSizeOfAllFileHeaders (fileHeaders: ArrayList<FileHeader>): Int64
}

public class FileHeaderFactory {
    
    /*
     * 构造 
     */
    public init ()

    /*
     * 生成文件头
     * 
     * 参数 zipParameters - 压缩参数
     * 参数 isSplitZip - 是否分卷
     * 参数 currentDiskNumberStart - 开始位置
     * 参数 charset - charset对象
     * 参数 rawIO - rawIO对象
     * 返回值 FileHeader - 文件头, 如果传入zipParameters参数没有设置FileName, 则抛zipException.
     */
    public func generateFileHeader (zipParameters: ZipParameters, isSplitZip: Bool, currentDiskNumberStart: Int64, charset: ?Charset, rawIO: RawIO): FileHeader
    
    /*
     * 生成文件头
     * 
     * 参数 fileHeader - 文件头
     * 返回值 LocalFileHeader - 文件头, 如果FileHeader的GeneralPurposeFlag为空, 则抛NoneValueException.
     */
    public func generateLocalFileHeader (fileHeader: FileHeader): LocalFileHeader
}

public enum ProgressMonitorState<: Equal<ProgressMonitorState> {
    | READY //就绪
    | BUSY //忙碌

    /*
     * 判等
     * 
     * 参数 that - ProgressMonitorState
     * 返回值 Bool - 是否相等
     */
    public operator func == (that: ProgressMonitorState): Bool
 
}

public enum ProgressMonitorResult {
    | SUCCESS //成功
    | WORK_IN_PROGRESS //运行中
    | ERROR //错误
    | CANCELLED //取消
}

public enum ProgressMonitorTask {
    | NONE //空
    | ADD_ENTRY //添加
    | REMOVE_ENTRY //移除
    | CALCULATE_CRC //计算crc
    | EXTRACT_ENTRY //提取ENTRY
    | MERGE_ZIP_FILES //合并zip文件
    | SET_COMMENT //设置COMMENT
    | RENAME_FILE //重命名文件
}

public class ProgressMonitor {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 更新成功状态
     * 
     * 参数 workCompleted - 成功数量
     */
    public func updateWorkCompleted (workCompleted: Int64): Unit
    
    /*
     * 结束任务
     */
    public func endProgressMonitor (): Unit
    
    /*
     * 结束任务
     * 
     * 参数 e - 异常
     */
    public func endProgressMonitor (e: Exception)
    
    /*
     * 重置
     */
    public func fullReset (): Unit
    
    /*
     * 获取 ProgressMonitorState
     * 
     * 返回值 ProgressMonitorState - ProgressMonitorState值
     */
    public func getState (): ProgressMonitorState
    
    /*
     * 设置 ProgressMonitorState
     * 
     * 参数 state - ProgressMonitorState值
     */
    public func setState (state: ProgressMonitorState): Unit
    
    /*
     * 设置 totalWork
     * 
     * 参数 totalWork - Int64值
     */
    public func setTotalWork (totalWork: Int64): Unit
    
    /*
     * 获取 PercentDone
     * 
     * 返回值 Int32 - PercentDone值
     */
    public func getPercentDone (): Int32
    
    /*
     * 获取 CurrentTask
     * 
     * 返回值 ProgressMonitorTask - ProgressMonitorTask对象
     */
    public func getCurrentTask (): ProgressMonitorTask
    
    /*
     * 设置 currentTask
     * 
     * 参数 currentTask - ProgressMonitorTask对象
     * 返回值 Unit - 
     */
    public func setCurrentTask (currentTask: ProgressMonitorTask): Unit
    
    /*
     * 获取 FileName
     * 
     * 返回值 String - 文件名
     */
    public func getFileName (): String
    
    /*
     * 设置 FileName
     * 
     * 参数 fileName - 文件名
     */
    public func setFileName (fileName: String): Unit
    
    /*
     * 获取 ProgressMonitorResult
     * 
     * 返回值 ProgressMonitorResult - ProgressMonitorResult对象
     */
    public func getResult (): ProgressMonitorResult
    
    /*
     * 设置 ProgressMonitorResult
     * 
     * 参数 result - ProgressMonitorResult对象
     */
    public func setResult (result: ProgressMonitorResult): Unit
    
    /*
     * 获取 Exception
     * 
     * 返回值 Exception - Exception对象
     */
    public func getException (): Exception
    
    /*
     * 设置 Exception
     * 
     * 参数 exception - Exception对象
     */
    public func setException (exception: Exception): Unit
    
    /*
     * 判断是否取消任务
     * 
     * 返回值 Bool - 布尔值
     */
    public func isCancelAllTasks (): Bool
}

public class BitUtils {
    
    /*
     * 判断是否是比特字节
     * 
     * 参数 b - Byte值
     * 参数 pos - 光标位置
     * 返回值 Bool - 布尔值
     */
    public static func isBitSet (b: Byte, pos: Int64): Bool
    
    /*
     * 设置 
     * 
     * 参数 b - Byte值
     * 参数 pos - 光标位置
     * 返回值 Byte - 设置的值
     */
    public static func setBit (b: Byte, pos: Int64): Byte
    
    /*
     * 取消设置
     * 
     * 参数 b - Byte值
     * 参数 pos - 光标位置
     * 返回值 Byte - 取消设置的值
     */
    public static func unsetBit (b: Byte, pos: Int64): Byte
}

public class ZipVersionUtils {
    
    /*
     * 确定版本制作者
     * 
     * 参数 zipParameters - 压缩参数
     * 参数 rawIO - RawIO对象
     * 返回值 Int32 - Int32值
     */
    public static func determineVersionMadeBy (zipParameters: ZipParameters, rawIO: RawIO): Int32
    
    /*
     * 确定需要提取的版本
     * 
     * 参数 zipParameters - 压缩参数
     * 返回值 VersionNeededToExtract - VersionNeededToExtract对象
     */
    public static func determineVersionNeededToExtract (zipParameters: ZipParameters): VersionNeededToExtract
}

public class FileUtils {
    
    /*
     * 设置 FileAttribu
     * 
     * 参数 file - 文件路径
     * 参数 fileAttributes - 文件信息数组
     */
    public static func setFileAttributes (file: Path, fileAttributes: Array<Byte>): Unit
    
    /*
     * 设置 FileLastModifiedT
     * 
     * 参数 file - 文件路径
     * 参数 lastModifiedTime - 修改时间
     */
    public static func setFileLastModifiedTime (file: Path, lastModifiedTime: Int64): Unit
    
    /*
     * 设置 FileLastModifiedTimeWithout
     * 
     * 参数 file - 文件路径
     * 参数 lastModifiedTime - 修改时间
     */
    public static func setFileLastModifiedTimeWithoutNio (file: Path, lastModifiedTime: Int64): Unit
    
    /*
     * 获取 FileAttribu
     * 
     * 参数 file - 文件路径
     * 返回值 Array<Byte> - 文件信息数组
     */
    public static func getFileAttributes (file: Path): Array<Byte>
    
    /*
     * 获取 FilesInDirectoryRecurs
     * 
     * 参数 path - 文件路径
     * 参数 zipParameters - 压缩参数
     * 返回值 ArrayList<Path> - 路径数组
     */
    public static func getFilesInDirectoryRecursive (path: Path, zipParameters: ZipParameters): ArrayList<Path>
    
    /*
     * 获取 FilesInDirectoryRecurs
     * 
     * 参数 path - 文件路径
     * 参数 zipParameters - 压缩参数
     */
    public static func getFilesInDirectoryRecursive (path: File, zipParameters: ZipParameters)
    
    /*
     * 获取 FileNameWithoutExtens
     * 
     * 参数 fileName - 文件名
     * 返回值 String - 扩展名
     */
    public static func getFileNameWithoutExtension (fileName: String): String
    
    /*
     * 获取 ZipFileNameWithoutExtens
     * 
     * 参数 zipFile - 文件名
     * 返回值 String - 扩展名, 如果 zipFile为空串, 则抛 ZipException
     */
    public static func getZipFileNameWithoutExtension (zipFile: String): String
    
    /*
     * 获取 RelativeFileN
     * 
     * 参数 fileToAdd - 要添加的文件
     * 参数 zipParameters - 压缩参数
     * 返回值 String - 字符串
     */
    public static func getRelativeFileName (fileToAdd: Path, zipParameters: ZipParameters): String
    
    /*
     * 判断文件夹
     * 
     * 参数 fileNameInZip - 文件名
     * 返回值 Bool - 布尔值
     */
    public static func isZipEntryDirectory (fileNameInZip: String): Bool
    
    /*
     * 复制文件, 如果 参数不正确, 则抛 ZipException
     * 
     * 参数 randomAccessFile - 文件
     * 参数 outputStream - 输出流
     * 参数 start - 开始位置
     * 参数 end - 结束位置
     * 参数 progressMonitor - 监控器
     * 参数 bufferSize - 缓冲大小
     */
    public static func copyFile (randomAccessFile: RandomAccessFile, outputStream: OutputStream, start: Int64, end: Int64, progressMonitor: ProgressMonitor, bufferSize: Int64)
    
    /*
     * 文件是否存在, 如果 断言失败, 则抛 ZipException
     * 
     * 参数 files - 文件
     * 参数 symLinkAction - 文件链接
     */
    public static func assertFilesExist (files: ArrayList<Path>, symLinkAction: SymbolicLinkAction): Unit
    
    /*
     * 判断是否分卷, 如果 file路径为空字符串, 则抛 IllegalArgumentException
     * 
     * 参数 file - 文件路径
     * 返回值 Bool - 布尔值
     */
    public static func isNumberedSplitFile (file: Path): Bool
    
    /*
     * 获取 FileExtens, 如果 file路径为空字符串, 则抛 IllegalArgumentException
     * 
     * 参数 path - 文件路径
     * 返回值 String - 扩展名
     */
    public static func getFileExtension (path: Path): String
    
    /*
     * 获取 AllSortedNumberedSplitFiles , 如果 路径参数不是一个分包的zip文件 , 则抛 NoneValueException
     * 
     * 参数 firstNumberedFile - 文件路径
     * 返回值 Array<Path> - 路径数组
     */
    public static func getAllSortedNumberedSplitFiles (firstNumberedFile: Path): Array<Path>
    
    /*
     * 判断是否符号链接, 如果 file路径为空字符串, 则抛 IllegalArgumentException
     * 
     * 参数 file - 文件路径
     * 返回值 Bool - 布尔值
     */
    public static func isSymbolicLink (file: Path): Bool
    
    /*
     * 读取符号链接文件, 如果 file路径为空字符串, 则抛 IllegalArgumentException
     * 
     * 参数 file - 文件路径
     * 返回值 String - 原始文件
     */
    public static func readSymbolicLink (file: Path): String
    
    /*
     * 获取 DefaultFileAttributes
     * 
     * 参数 isDirectory - 是否文件夹
     * 返回值 Array<Byte> - Byte数组
     */
    public static func getDefaultFileAttributes (isDirectory: Bool): Array<Byte>
}

public class CRC32 {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 计算crc32
     * 
     * 参数 value - 原始值
     * 参数 buf - 缓冲区
     * 参数 start - 开始位置
     * 参数 length - 结束位置
     * 返回值 UInt32 - 计算值
     */
    public func crc32 (value: UInt32, buf: Array<UInt8>, start: Int64, length: Int64): UInt32
    
    /*
     * 更新buf
     * 
     * 参数 buff - Array<Byte>
     */
    public func update (buff: Array<Byte>)
    
    /*
     * 重置Crc32
     * 
     */
    public func reset ()
    
    /*
     * 获取 Value
     * 
     * 返回值 Int64 - 保存的Value
     */
    public func getValue (): Int64
    
    /*
     * 获取 Final
     * 
     * 返回值 UInt32 - Final值
     */
    public func getFinalCRC ()： UInt32
}

public class CrcUtil {
    
    /*
     * 计算文件Crc值
     * 
     * 参数 inputFile - 文件路径
     * 参数 progressMonitor - 监控器
     * 返回值 UInt32 - 计算值
     */
    public static func computeFileCrc (inputFile: Path, progressMonitor: ?ProgressMonitor): UInt32
}

public open class RandomAccessFile<: Resource {
    
    /*
     * 构造 
     * 
     * 参数 path - 文件路径
     * 参数 mode - 打开模式
     */
    public init (path: String, mode: OpenOption)
    
    /*
     * 构造 
     * 
     * 参数 path - 文件路径
     * 参数 mode - 打开模式
     */
    public init (path: Path, mode: OpenOption)
    
    /*
     * 构造 
     * 
     * 参数 file - 文件
     */
    public init (file: File)
    
    /*
     * 获取 FilePoin
     * 
     * 返回值 Int64 - 光标位置
     */
    open public func getFilePointer (): Int64
    
    /*
     * 移动光标位置
     * 
     * 参数 loc - 光标位置
     */
    open public func seek (loc: Int64): Unit
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 返回值 Int64 - 读取到的数据大小
     */
    open public func read (buffer: Array<Byte>): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     * 参数 off - 读取开头
     * 参数 len - 读取长度
     * 返回值 Int64 - 读取到的数据大小
     */
    open public func read (buffer: Array<Byte>, off: Int64, count: Int64): Int64
    
    /*
     * 读取数据
     * 
     * 参数 b - 数据读取到数组里
     */
    open public func readFully (b: Array<Byte>): Unit
    
    /*
     * 写数据
     * 
     * 参数 bval - 要写的数据
     */
    open public func write (buffer: Array<Byte>): Unit
    
    /*
     * 刷新缓冲区
     */
    open public func flush (): Unit
    
    /*
     * 关闭文件
     */
    open public func close (): Unit
    
    /*
     * 判断是否关闭
     * 
     * 返回值 Bool - 是否关闭
     */
    open public func isClosed (): Bool
}

public enum VersionMadeBy {
    | SPECIFICATION_VERSION
    | WINDOWS
    | UNIX

    /*
     * 获取对应编码
     * 
     * 返回值 Byte - 编码Byte
     */
    public func getCode(): Byte
}

public enum VersionNeededToExtract {

    | DEFAULT
    | DEFLATE_COMPRESSED
    | ZIP_64_FORMAT
    | AES_ENCRYPTED

    /*
     * 获取对应编码
     * 
     * 返回值 Int32 - 编码Int32
     */
    public func getCode(): Int32
}

public class RawIO {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 读取小端文件
     * 
     * 参数 randomAccessFile - RandomAccessFile文件
     * 返回值 Int64 - andomAccessFile文件
     * 参数 readLen - 读取长度
     */
    public func readLongLittleEndian (randomAccessFile: RandomAccessFile): Int64
    
    /*
     * 读取长端文件
     * 
     * 参数 randomAccessFile - RandomAccessFile文件
     * 参数 readLen - 读取长度, 读取长度如果为负, 抛 IndexOutOfBoundsException
     * 返回值 Int64 - 读取长度
     */
    public func readLongLittleEndian (randomAccessFile: RandomAccessFile, readLen: Int64): Int64
    
    /*
     * 读取长端文件
     * 
     * 参数 inputStream - 输入流
     * 返回值 Int64 - 读取长度
     */
    public func readLongLittleEndian (inputStream: InputStream): Int64
    
    /*
     * 读取长端文件
     * 
     * 参数 inputStream - 输入流
     * 参数 readLen - 读取长度, 如果为负, 抛 IndexOutOfBoundsException
     * 返回值 Int64 - 读取长度
     */
    public func readLongLittleEndian (inputStream: InputStream, readLen: Int64): Int64
    
    /*
     * 读取长端数据
     * 
     * 参数 array - 数组
     * 参数 pos - 光标位置
     */
    public func readLongLittleEndian (array: Array<Byte>, pos: Int64)
    
    /*
     * 读取长端数据
     * 
     * 参数 randomAccessFile - RandomAccessFile文件
     * 返回值 Int32 - 读取长度
     */
    public func readIntLittleEndian (randomAccessFile: RandomAccessFile): Int32
    
    /*
     * 读取长端数据
     * 
     * 参数 inputStream - 输入流
     * 返回值 Int32 - 读取长度
     */
    public func readIntLittleEndian (inputStream: InputStream): Int32
    
    /*
     * 读取长端数据
     * 
     * 参数 b - 数组
     * 返回值 Int32 - 读取长度
     */
    public func readIntLittleEndian (b: Array<Byte>): Int32
    
    /*
     * 读取长端数据
     * 
     * 参数 b - 数组
     * 参数 pos - 光标位置, 如果为负, 抛 IndexOutOfBoundsException
     * 返回值 Int32 - 读取长度
     */
    public func readIntLittleEndian (b: Array<Byte>, pos: Int64): Int32
    
    /*
     * 读取长端数据
     * 
     * 参数 randomAccessFile - RandomAccessFile文件
     * 返回值 Int32 - 读取长度
     */
    public func readShortLittleEndian (randomAccessFile: RandomAccessFile): Int32
    
    /*
     * 读取短端数据
     * 
     * 参数 inputStream - 输入流
     * 返回值 Int32 - 读取大小
     */
    public func readShortLittleEndian (inputStream: InputStream): Int32
    
    /*
     * 读取小端数据
     * 
     * 参数 buff - 数组值
     * 参数 position - 位置, 如果为负, 抛 IndexOutOfBoundsException
     * 返回值 Int32 - 读取大小
     */
    public func readShortLittleEndian (buff: Array<Byte>, position: Int64): Int32
    
    /*
     * 读取短端数据
     * 
     * 参数 outputStream - 输出流
     * 参数 value - 值
     */
    public func writeShortLittleEndian (outputStream: OutputStream, value: Int32): Unit
    
    /*
     * 读取短端数据
     * 
     * 参数 array - 数组
     * 参数 pos - 光标位置, 如果为负, 抛 IndexOutOfBoundsException
     * 参数 value - 值
     */
    public func writeShortLittleEndian (array: Array<Byte>, pos: Int64, value: Int32): Unit
    
    /*
     * 读取小端数据
     * 
     * 参数 outputStream - 输出流
     * 参数 value - 值
     */
    public func writeIntLittleEndian (outputStream: OutputStream, value: Int32): Unit
    
    /*
     * 读取小端数据
     * 
     * 参数 array - 数组
     * 参数 pos - 光标位置, 如果为负, 抛 IndexOutOfBoundsException
     * 参数 value - 值
     */
    public func writeIntLittleEndian (array: Array<Byte>, pos: Int64, value: Int32): Unit
    
    /*
     * 读取长端数据
     * 
     * 参数 outputStream - 输出流
     * 参数 value - 值
     */
    public func writeLongLittleEndian (outputStream: OutputStream, value: Int64): Unit
    
    /*
     * 读取长端数据
     * 
     * 参数 array - 数组
     * 参数 pos - 光标, 如果为负, 抛 IndexOutOfBoundsException
     * 参数 value - 值
     */
    public func writeLongLittleEndian (array: Array<Byte>, pos: Int64, value: Int64): Unit
}

public class Zip4cjUtil {
    
    /*
     * 判断空
     * 
     * 参数 str - String
     * 返回值 Bool - 是否空
     */
    public static func isStringNullOrEmpty (str: ?String): Bool
    
    /*
     * 判断空
     * 
     * 参数 str - String
     * 返回值 Bool - 是否空
     */
    public static func isStringNotNullAndNotEmpty (str: ?String): Bool
    
    /*
     * 创建文件
     * 
     * 参数 file - 路径
     * 返回值 Bool - 是否成功, 如果file路径不存在, 则抛ZipException
     */
    public static func createDirectoryIfNotExists (file: Path): Bool
    
    /*
     * 转换之间
     * 
     * 参数 time - 时间
     * 返回值 Int64 - 转换后时间
     */
    public static func epochToExtendedDosTime (time: Int64): Int64
    
    /*
     * 转化时间
     * 
     * 参数 dosTime - dos时间
     * 返回值 Int64 - 时间
     */
    public static func dosToExtendedEpochTme (dosTime: Int64): Int64
    
    /*
     * 转换数组
     * 
     * 参数 charArray - 字符数组
     * 参数 useUtf8Charset - utf8数组
     * 返回值 Array<Byte> - 转换数组
     */
    public static func convertCharArrayToByteArray (charArray: Array<Rune>, useUtf8Charset: Bool): Array<Byte>
    
    /*
     * 获取 CompressionMet
     * 
     * 参数 localFileHeader - AbstractFileHeader对象
     * 返回值 CompressionMethod - CompressionMethod对象, 传入参数AbstractFileHeader的成员为空时, 会抛NoneValueException.
     */
    public static func getCompressionMethod (localFileHeader: AbstractFileHeader): CompressionMethod
    
    /*
     * 读取
     * 
     * 参数 inputStream - 输入流
     * 参数 bufferToReadInto - 数组
     * 返回值 Int32 - 读取长度
     */
    public static func readFully (inputStream: InputStream, bufferToReadInto: Array<Byte>): Int32
    
    /*
     * 读取
     * 
     * 参数 inputStream - 输入流
     * 参数 b - 数组
     * 参数 offset - 开始位置 
     * 参数 length - 长度, 如果为负, 抛 Exception
     * 返回值 Int64 - 读取大小, 如果 offset + length > b.size, 则抛 IllegalArgumentException.
     */
    public static func readFully (inputStream: InputStream, b: Array<Byte>, offset: Int64, length: Int64): Int64
}


public abstract class ZipHeader {
    
    /*
     * 获取 HeaderSignature对象
     * 
     * 返回值 ?HeaderSignature - HeaderSignature对象
     */
    public func getSignature (): ?HeaderSignature
    
    /*
     * 设置 signature
     * 
     * 参数 signature - HeaderSignature类型
     * 
     */
    public func setSignature (signature: HeaderSignature): Unit
}

public class EndOfCentralDirectoryRecord<: ZipHeader {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 获取磁盘的大小
     * 
     * 返回值 Int32 - 返回此磁盘的大小
     */
    public func getNumberOfThisDisk (): Int32
    
    /*
     * 设置磁盘的大小
     * 
     * 参数 numberOfThisDisk - 磁盘的大小
     * 
     */
    public func setNumberOfThisDisk (numberOfThisDisk: Int32): Unit
    
    /*
     * 获取目录的起始位置
     * 
     * 返回值 Int32 - 目录的起始位置
     */
    public func getNumberOfThisDiskStartOfCentralDir (): Int32
    
    /*
     * 设置目录的起始位置
     * 
     * 参数 numberOfThisDiskStartOfCentralDir - 目录的起始位置
     * 
     */
    public func setNumberOfThisDiskStartOfCentralDir (numberOfThisDiskStartOfCentralDir: Int32): Unit
    
    /*
     * 获取目录中的条目总数
     * 
     * 返回值 Int32 - 目录中的条目总数
     */
    public func getTotalNumberOfEntriesInCentralDirectoryOnThisDisk (): Int32
    
    /*
     * 设置目录中的条目总数
     * 
     * 参数 totalNumberOfEntriesInCentralDirectoryOnThisDisk - 目录中的条目总数
     * 
     */
    public func setTotalNumberOfEntriesInCentralDirectoryOnThisDisk (totalNumberOfEntriesInCentralDirectoryOnThisDisk: Int32): Unit
    
    /*
     * 获取中央目录中的条目总数
     * 
     * 返回值 Int64 - 中央目录中的条目总数
     */
    public func getTotalNumberOfEntriesInCentralDirectory (): Int64
    
    /*
     * 设置中央目录中的条目总数
     * 
     * 参数 totalNumberOfEntriesInCentralDirectory - 中央目录中的条目总数
     * 
     */
    public func setTotalNumberOfEntriesInCentralDirectory (totalNumberOfEntriesInCentralDirectory: Int64): Unit
    
    /*
     * 获取中央目录的大小
     * 
     * 返回值 Int32 - 中央目录的大小
     */
    public func getSizeOfCentralDirectory (): Int32
    
    /*
     * 设置中央目录的大小
     * 
     * 参数 sizeOfCentralDirectory - 中央目录的大小
     * 
     */
    public func setSizeOfCentralDirectory (sizeOfCentralDirectory: Int32): Unit
    
    /*
     * 获取开始偏移量
     * 
     * 返回值 Int64 - 开始偏移量
     */
    public func getOffsetOfStartOfCentralDirectory (): Int64
    
    /*
     * 设置开始偏移量
     * 
     * 参数 offsetOfStartOfCentralDirectory - 开始偏移量
     */
    public func setOffsetOfStartOfCentralDirectory (offsetOfStartOfCentralDirectory: Int64): Unit
    
    /*
     * 获取偏移量
     * 
     * 返回值 Int64 - 偏移量
     */
    public func getOffsetOfEndOfCentralDirectory (): Int64
    
    /*
     * 设置偏移量
     * 
     * 参数 offsetOfEndOfCentralDirectory - 偏移量
     *
     */
    public func setOffsetOfEndOfCentralDirectory (offsetOfEndOfCentralDirectory: Int64): Unit
    
    /*
     * 获取comment内容
     * 
     * 返回值 String - comment内容
     */
    public func getComment (): String
    
    /*
     * 设置comment内容
     * 
     * 参数 comment - comment内容
     */
    public func setComment (comment: ?String): Unit
}

public class Zip64EndOfCentralDirectoryLocator<: ZipHeader {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 获取磁盘开始数
     * 
     * 返回值 Int32 - 磁盘开始数
     */
    public func getNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord (): Int32
    
    /*
     * 设置磁盘开始数
     * 
     * 参数 numberOfDiskStartOfZip64EndOfCentralDirectoryRecord - 磁盘开始数
     * 
     */
    public func setNumberOfDiskStartOfZip64EndOfCentralDirectoryRecord (numberOfDiskStartOfZip64EndOfCentralDirectoryRecord: Int32): Unit
    
    /*
     * 获取偏移量
     * 
     * 返回值 Int64 - 偏移量
     */
    public func getOffsetZip64EndOfCentralDirectoryRecord (): Int64
    
    /*
     * 设置偏移量
     * 
     * 参数 offsetZip64EndOfCentralDirectoryRecord - 偏移量大小
     * 
     */
    public func setOffsetZip64EndOfCentralDirectoryRecord (offsetZip64EndOfCentralDirectoryRecord: Int64): Unit
    
    /*
     * 获取光盘总数
     * 
     * 返回值 Int32 - 光盘总数
     */
    public func getTotalNumberOfDiscs (): Int32
    
    /*
     * 设置光盘总数
     * 
     * 参数 totalNumberOfDiscs - 光盘总数
     *
     */
    public func setTotalNumberOfDiscs (totalNumberOfDiscs: Int32): Unit
}

public abstract class AbstractFileHeader<: ZipHeader&Equatable<AbstractFileHeader> {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 获取版本
     * 
     * 返回值 Int32 - 获取所需版本
     */
    public func getVersionNeededToExtract (): Int32
    
    /*
     * 设置版本
     * 
     * 参数 versionNeededToExtract - 版本号
     *
     */
    public func setVersionNeededToExtract (versionNeededToExtract: Int32): Unit
    
    /*
     * 获取通用目的标志
     * 
     * 返回值 ?Array<Byte> - 通用目的标志集合
     */
    public func getGeneralPurposeFlag (): ?Array<Byte>
    
    /*
     * 设置通用目的标志
     * 
     * 参数 generalPurposeFlag - 标志集合Array<Byte>
     * 
     */
    public func setGeneralPurposeFlag (generalPurposeFlag: ?Array<Byte>): Unit
    
    /*
     * 获取压缩方法
     * 
     * 返回值 ?CompressionMethod - 压缩方法
     */
    public func getCompressionMethod (): ?CompressionMethod
    
    /*
     * 设置压缩方法
     * 
     * 参数 compressionMethod - 压缩方法
     *
     */
    public func setCompressionMethod (compressionMethod: ?CompressionMethod): Unit
    
    /*
     * 获取获取上次修改时间
     * 
     * 返回值 Int64 - 获取上次修改时间
     */
    public func getLastModifiedTime (): Int64
    
    /*
     * 设置上次修改时间
     * 
     * 参数 lastModifiedTime - 获取上次修改时间
     * 
     */
    public func setLastModifiedTime (lastModifiedTime: Int64): Unit
    
    /*
     * 获取上次修改时期
     * 
     * 返回值 Int64 - 获取上次修改时期
     */
    public func getLastModifiedTimeEpoch (): Int64
    
    /*
     * 获取校验大小
     * 
     * 返回值 Int64 - 校验 
     */
    public func getCrc (): Int64
    
    /*
     * 设置校验大小
     * 
     * 参数 crc - 
     * 返回值 Unit - 设置校验数据大小
     */
    public func setCrc (crc: Int64): Unit
    
    /*
     * 获取压缩的大小
     * 
     * 返回值 Int64 - 压缩的大小
     */
    public func getCompressedSize (): Int64
    
    /*
     * 设置压缩的大小
     * 
     * 参数 compressedSize - 压缩的大小
     * 
     */
    public func setCompressedSize (compressedSize: Int64): Unit
    
    /*
     * 获取解压的大小
     * 
     * 返回值 Int64 - 解压的大小
     */
    public func getUncompressedSize (): Int64
    
    /*
     * 设置解压的大小
     * 
     * 参数 uncompressedSize - 解压的大小
     * 
     */
    public func setUncompressedSize (uncompressedSize: Int64): Unit
    
    /*
     * 获取文件名的长度
     * 
     * 返回值 Int64 - 文件名的长度
     */
    public func getFileNameLength (): Int64
    
    /*
     * 设置文件名的长度
     * 
     * 参数 fileNameLength - 文件名的长度
     * 
     */
    public func setFileNameLength (fileNameLength: Int64): Unit
    
    /*
     * 获取额外字段长度
     * 
     * 返回值 Int32 - 额外字段长度
     */
    public func getExtraFieldLength (): Int32
    
    /*
     * 设置额外字段长度
     * 
     * 参数 extraFieldLength - 额外字段长度
     *
     */
    public func setExtraFieldLength (extraFieldLength: Int32): Unit
    
    /*
     * 获取文件名
     * 
     * 返回值 ?String - 文件名
     */
    public func getFileName (): ?String
    
    /*
     * 设置文件名
     * 
     * 参数 fileName - 文件名String格式
     * 
     */
    public func setFileName (fileName: ?String): Unit
    
    /*
     * 判断是否加密
     * 
     * 返回值 Bool - 是否加密
     */
    public func isEncrypted (): Bool
    
    /*
     * 设置是否加密
     * 
     * 参数 encrypted - 设置是否加密
     * 
     */
    public func setEncrypted (encrypted: Bool): Unit
    
    /*
     * 获取加密方法
     * 
     * 返回值 EncryptionMethod - 加密方法
     */
    public func getEncryptionMethod (): EncryptionMethod
    
    /*
     * 设置加密方法
     * 
     * 参数 encryptionMethod - 加密方法
     *
     */
    public func setEncryptionMethod (encryptionMethod: EncryptionMethod): Unit
    
    /*
     * 判断数据描述符是否存在
     * 
     * 返回值 Bool - 数据描述符是否存在
     */
    public func isDataDescriptorExists (): Bool
    
    /*
     * 设置是否设置数据描述符
     * 
     * 参数 dataDescriptorExists - 是否设置数据描述符
     * 
     */
    public func setDataDescriptorExists (dataDescriptorExists: Bool): Unit
    
    /*
     * 获取zip64扩展信息
     * 
     * 返回值 ?Zip64ExtendedInfo - Zip64ExtendedInfo对象 
     */
    public func getZip64ExtendedInfo (): ?Zip64ExtendedInfo
    
    /*
     * 设置zip64扩展信息
     * 
     * 参数 zip64ExtendedInfo -  Zip64ExtendedInfo对象
     * 
     */
    public func setZip64ExtendedInfo (zip64ExtendedInfo: Zip64ExtendedInfo): Unit
    
    /*
     * 获取数据记录
     * 
     * 返回值 ?AESExtraDataRecord - AESExtraDataRecord对象
     */
    public func getAesExtraDataRecord (): ?AESExtraDataRecord
    
    /*
     * 设置数据记录
     * 
     * 参数 aesExtraDataRecord - AESExtraDataRecord对象
     * 
     */
    public func setAesExtraDataRecord (aesExtraDataRecord: ?AESExtraDataRecord): Unit
    
    /*
     * 判断文件名是否UTF8编码格式 
     * 
     * 返回值 Bool - 文件名是否UTF8编码格式
     */
    public func isFileNameUTF8Encoded (): Bool
    
    /*
     * 设置设置文件名是否UTF8编码格式
     * 
     * 参数 fileNameUTF8Encoded - 设置文件名是否UTF8编码格式
     * 
     */
    public func setFileNameUTF8Encoded (fileNameUTF8Encoded: Bool): Unit
    
    /*
     * 获取额外数据记录
     * 
     * 返回值 ?ArrayList<ExtraDataRecord> - ArrayList<ExtraDataRecord>集合
     */
    public func getExtraDataRecords (): ?ArrayList<ExtraDataRecord>
    
    /*
     * 设置额外数据记录
     * 
     * 参数 extraDataRecords - ArrayList<ExtraDataRecord>集合
     * 
     */
    public func setExtraDataRecords (extraDataRecords: ?ArrayList<ExtraDataRecord>): Unit
    
    /*
     * 判断判断是否是目录
     * 
     * 返回值 Bool - 判断是否是目录
     */
    public func isDirectory (): Bool
    
    /*
     * 设置是否是目录
     * 
     * 参数 directory - 设置是否是目录
     * 
     */
    public func setDirectory (directory: Bool): Unit
    
    /*
     * 判断两个AbstractFileHeader对象是否相等
     * 
     * 参数 obj - 需要匹配的AbstractFileHeader对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public func equals (obj: AbstractFileHeader): Bool
    
    /*
     * 判断两个AbstractFileHeader对象是否相等
     * 
     * 参数 that - 需要匹配的AbstractFileHeader对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func == (that: AbstractFileHeader): Bool
    
    /*
     * 判断两个AbstractFileHeader对象是否不相等
     * 
     * 参数 that - 需要匹配的AbstractFileHeader对象
     * 返回值 Bool - 判断两个对象是否不相等
     */
    public operator func != (that: AbstractFileHeader): Bool
}

public class CentralDirectory {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 获取文件头
     * 
     * 返回值 ArrayList<FileHeader> - 返回文件Headers集合
     */
    public func getFileHeaders (): ArrayList<FileHeader>
    
    /*
     * 设置文件头
     * 
     * 参数 fileHeaders - 文件Headers集合
     * 
     */
    public func setFileHeaders (fileHeaders: ArrayList<FileHeader>): Unit
    
    /*
     * 获取数字签名
     * 
     * 返回值 DigitalSignature - 数字签名DigitalSignature
     */
    public func getDigitalSignature (): DigitalSignature
    
    /*
     * 设置数字签名
     * 
     * 参数 digitalSignature - 数字签名DigitalSignature
     * 
     */
    public func setDigitalSignature (digitalSignature: DigitalSignature): Unit
}

public enum HeaderSignature <: Equatable<HeaderSignature> {
    
    | LOCAL_FILE_HEADER
    | EXTRA_DATA_RECORD
    | CENTRAL_DIRECTORY
    | END_OF_CENTRAL_DIRECTORY 
    | TEMPORARY_SPANNING_MARKER 
    | DIGITAL_SIGNATURE
    | ARCEXTDATREC
    | SPLIT_ZIP
    | ZIP64_END_CENTRAL_DIRECTORY_LOCATOR
    | ZIP64_END_CENTRAL_DIRECTORY_RECORD
    | ZIP64_EXTRA_FIELD_SIGNATURE
    | AES_EXTRA_DATA_RECORD

    /*
     * 判断两个HeaderSignature对象是否不相等
     * 
     * 参数 that - 需要匹配的HeaderSignature对象
     * 返回值 Bool - 判断两个对象是否不相等
     */
    public operator func !=(that: HeaderSignature): Bool

    /*
     * 判断两个HeaderSignature对象是否相等
     * 
     * 参数 that - 需要匹配的HeaderSignature对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func ==(that: HeaderSignature): Bool

    /*
     * 获取所有的HeaderSignature集合
     * 
     * 
     * 返回值 Array<HeaderSignature> - HeaderSignature集合
     */
    public static func values(): Array<HeaderSignature>

    /*
     * 获取对应的值
     * 
     *
     * 返回值 Int64 - 对应的值
     */
    public func getValue(): Int64
}

public class AESExtraDataRecord<: ZipHeader {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 获取数据的大小
     * 
     * 返回值 Int64 - 返回数据的大小
     */
    public func getDataSize (): Int64
    
    /*
     * 设置数据的大小
     * 
     * 参数 dataSize - 数据的大小
     *
     */
    public func setDataSize (dataSize: Int64): Unit
    
    /*
     * 获取 Aes版本
     * 
     * 返回值 AesVersion - 
     */
    public func getAesVersion (): AesVersion
    
    /*
     * 设置 Aes版本
     * 
     * 参数 aesVersion - Aes版本
     * 
     */
    public func setAesVersion (aesVersion: AesVersion): Unit
    
    /*
     * 获取数据ID
     * 
     * 返回值 String - 数据ID
     */
    public func getVendorID (): String
    
    /*
     * 设置数据ID
     * 
     * 参数 vendorID - 数据ID
     *
     */
    public func setVendorID (vendorID: String): Unit
    
    /*
     * 获取AES加密密钥长度
     * 
     * 返回值 AesKeyStrength - AesKeyStrength类型
     */
    public func getAesKeyStrength (): AesKeyStrength
    
    /*
     * 设置AES加密密钥长度
     * 
     * 参数 aesKeyStrength - AesKeyStrength类型
     * 
     */
    public func setAesKeyStrength (aesKeyStrength: AesKeyStrength): Unit
    
    /*
     * 获取压缩方法
     * 
     * 返回值 CompressionMethod - 压缩的算法
     */
    public func getCompressionMethod (): CompressionMethod
    
    /*
     * 设置压缩方法
     * 
     * 参数 compressionMethod - 压缩的算法
     * 
     */
    public func setCompressionMethod (compressionMethod: CompressionMethod): Unit
}

public class ZipModel {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 获取本地文件头信息
     * 
     * 返回值 ArrayList<LocalFileHeader> - LocalFileHeader集合
     */
    public func getLocalFileHeaders (): ArrayList<LocalFileHeader>
    
    /*
     * 设置本地文件头信息
     * 
     * 参数 localFileHeaderList - LocalFileHeader集合
     *
     */
    public func setLocalFileHeaders (localFileHeaderList: ArrayList<LocalFileHeader>): Unit
    
    /*
     * 获取数据信息
     * 
     * 返回值 ArrayList<DataDescriptor> - DataDescriptor集合
     */
    public func getDataDescriptors (): ArrayList<DataDescriptor>
    
    /*
     * 设置数据信息
     * 
     * 参数 dataDescriptors - DataDescriptor集合 
     *
     */
    public func setDataDescriptors (dataDescriptors: ArrayList<DataDescriptor>): Unit
    
    /*
     * 获取中心目录
     * 
     * 返回值 CentralDirectory - CentralDirectory对象, 如果没有返回None
     */
    public func getCentralDirectory (): Option<CentralDirectory>
    
    /*
     * 设置中心目录
     * 
     * 参数 centralDirectory - CentralDirectory对象
     *
     */
    public func setCentralDirectory (centralDirectory: CentralDirectory): Unit
    
    /*
     * 获取中央目录记录结束
     * 
     * 返回值 EndOfCentralDirectoryRecord - EndOfCentralDirectoryRecord对象
     */
    public func getEndOfCentralDirectoryRecord (): EndOfCentralDirectoryRecord
    
    /*
     * 设置中央目录记录结束
     * 
     * 参数 endOfCentralDirectoryRecord - EndOfCentralDirectoryRecord对象
     *
     */
    public func setEndOfCentralDirectoryRecord (endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord): Unit
    
    /*
     * 获取存档额外数据记录
     *
     * 返回值 ArchiveExtraDataRecord - ArchiveExtraDataRecord对象
     */
    public func getArchiveExtraDataRecord (): ArchiveExtraDataRecord
    
    /*
     * 设置存档额外数据记录
     * 
     * 参数 archiveExtraDataRecord - ArchiveExtraDataRecord对象
     * 
     */
    public func setArchiveExtraDataRecord (archiveExtraDataRecord: ArchiveExtraDataRecord): Unit
    
    /*
     * 判断是否拆分存档
     * 
     * 返回值 Bool - 是否拆分存档
     */
    public func isSplitArchive (): Bool
    
    /*
     * 设置是否拆分存档
     * 
     * 参数 splitArchive - 是否拆分存档
     * 
     */
    public func setSplitArchive (splitArchive: Bool): Unit
    
    /*
     * 获取Zip文件路径
     * 
     * 返回值 ?Path - Zip文件路径
     */
    public func getZipFile (): ?Path
    
    /*
     * 设置Zip文件路径
     * 
     * 参数 zipFile - Zip文件路径
     * 
     */
    public func setZipFile (zipFile: Path): Unit
    
    /*
     * 获取中央目录位置
     * 
     * 返回值 ?Zip64EndOfCentralDirectoryLocator - Zip64EndOfCentralDirectoryLocator对象
     */
    public func getZip64EndOfCentralDirectoryLocator (): ?Zip64EndOfCentralDirectoryLocator
    
    /*
     * 设置中央目录位置
     * 
     * 参数 zip64EndOfCentralDirectoryLocator - Zip64EndOfCentralDirectoryLocator对象
     *
     */
    public func setZip64EndOfCentralDirectoryLocator (zip64EndOfCentralDirectoryLocator: ?Zip64EndOfCentralDirectoryLocator): Unit
    
    /*
     * 获取中央目录记录
     * 
     * 返回值 Zip64EndOfCentralDirectoryRecord - Zip64EndOfCentralDirectoryRecord对象
     */
    public func getZip64EndOfCentralDirectoryRecord (): Zip64EndOfCentralDirectoryRecord
    
    /*
     * 设置中央目录记录
     * 
     * 参数 zip64EndOfCentralDirectoryRecord - Zip64EndOfCentralDirectoryRecord对象
     * 
     */
    public func setZip64EndOfCentralDirectoryRecord (zip64EndOfCentralDirectoryRecord: Zip64EndOfCentralDirectoryRecord): Unit
    
    /*
     * 判断是否是Zip64格式
     * 
     * 返回值 Bool - 如果是true,是Zip64格式,如果是false,则不是
     */
    public func isZip64Format (): Bool
    
    /*
     * 设置Zip64格式
     * 
     * 参数 isZip64FormatBool - Bool是否是Zip64格式
     * 
     */
    public func setZip64Format (isZip64FormatBool: Bool): Unit
    
    /*
     * 判断是否是嵌套Zip64格式
     * 
     * 返回值 Bool - 如果是true,是嵌套Zip64格式,如果是false,则不是
     */
    public func isNestedZipFile (): Bool
    
    /*
     * 设置嵌套Zip64格式
     * 
     * 参数 isNestedZipFileBool - Bool是否是嵌套Zip64格式
     * 
     */
    public func setNestedZipFile (isNestedZipFileBool: Bool): Unit
    
    /*
     * 获取zip起始位置
     * 
     * 返回值 Int64 - 起始位置
     */
    public func getStart (): Int64
    
    /*
     * 设置zip起始位置
     * 
     * 参数 start - 起始位置
     * 
     */
    public func setStart (start: Int64): Unit
    
    /*
     * 获取zip结束位置 
     * 
     * 返回值 Int64 - 结束位置 
     */
    public func getEnd (): Int64
    
    /*
     * 设置zip结束位置 
     * 
     * 参数 end - 结束位置 
     *
     */
    public func setEnd (end: Int64): Unit
    
    /*
     * 获取拆分长度
     * 
     * 返回值 Int64 - 拆分长度
     */
    public func getSplitLength (): Int64
    
    /*
     * 设置拆分长度
     * 
     * 参数 splitLength - 拆分长度
     * 
     */
    public func setSplitLength (splitLength: Int64): Unit
    
    /*
     * 拷贝当前ZipModel对象
     * 
     * 返回值 ZipModel - ZipModel对象
     */
    public func clone (): ZipModel
}

public class FileHeader<: AbstractFileHeader&ToString&Hashable&Equatable<FileHeader> {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 获取版本制造
     * 
     * 返回值 Int32 - 版本制造
     */
    public func getVersionMadeBy (): Int32
    
    /*
     * 设置版本制造
     * 
     * 参数 versionMadeBy - 版本制造
     *
     */
    public func setVersionMadeBy (versionMadeBy: Int32): Unit
    
    /*
     * 获取文件注释长度
     * 
     * 返回值 Int32 - 文件注释长度 
     */
    public func getFileCommentLength (): Int32
    
    /*
     * 设置文件注释长度
     * 
     * 参数 fileCommentLength - 文件注释长度
     * 
     */
    public func setFileCommentLength (fileCommentLength: Int32): Unit
    
    /*
     * 获取磁盘编号开始
     * 
     * 返回值 Int64 - 磁盘编号开始
     */
    public func getDiskNumberStart (): Int64
    
    /*
     * 设置磁盘编号开始
     * 
     * 参数 diskNumberStart - 磁盘编号开始  
     * 
     */
    public func setDiskNumberStart (diskNumberStart: Int64): Unit
    
    /*
     * 获取内部文件属性
     * 
     * 返回值 ?Array<Byte> - 内部文件属性
     */
    public func getInternalFileAttributes (): ?Array<Byte>
    
    /*
     * 设置内部文件属性
     * 
     * 参数 internalFileAttributes - 内部文件属性
     *
     */
    public func setInternalFileAttributes (internalFileAttributes: Array<Byte>): Unit
    
    /*
     * 获取外部文件属性
     * 
     * 返回值 ?Array<Byte> - 外部文件属性
     */
    public func getExternalFileAttributes (): ?Array<Byte>
    
    /*
     * 设置外部文件属性
     * 
     * 参数 externalFileAttributes - 外部文件属性
     * 
     */
    public func setExternalFileAttributes (externalFileAttributes: ?Array<Byte>): Unit
    
    /*
     * 获取本地偏移
     * 
     * 返回值 Int64 - 本地偏移
     */
    public func getOffsetLocalHeader (): Int64
    
    /*
     * 设置本地偏移
     * 
     * 参数 offsetLocalHeader - 本地偏移
     *  
     */
    public func setOffsetLocalHeader (offsetLocalHeader: Int64): Unit
    
    /*
     * 获取文件注释
     * 
     * 返回值 ?String - 文件注释
     */
    public func getFileComment (): ?String
    
    /*
     * 设置文件注释
     * 
     * 参数 fileComment - 文件注释
     *
     */
    public func setFileComment (fileComment: ?String): Unit
    
    /*
     * 返回 FileHeader 实例中的字符串
     * 
     * 返回值 String - FileHeader 实例中的字符串
     */
    public override func toString (): String
    
    /*
     * 判断两个 FileHeader 对象是否不相等
     * 
     * 参数 that - 需要匹配的 FileHeader 对象
     * 返回值 Bool - 判断两个对象是否不相等
     */
    public operator func == (that: FileHeader): Bool
    
    /*
     * 判断两个 FileHeader 对象是否相等
     * 
     * 参数 that - 需要匹配的 FileHeader 对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func != (that: FileHeader): Bool
    
    /*
     * 判断两个 FileHeader 对象是否不相等
     * 
     * 参数 that - 需要匹配的 FileHeader 对象
     * 返回值 Bool - 判断两个对象是否不相等
     */
    public func equals (that: FileHeader): Bool
    
    /*
     * 获取 hashCode 值
     * 
     * 返回值 Int64 - hashCode 值
     */
    public override func hashCode (): Int64
}

public class Zip4cjConfig {
    
    /*
     * 构造 
     * 
     * 参数 charset - Charset类型，编码格式
     * 参数 bufferSize - 数据大小
     * 参数 useUtf8CharsetForPasswords - 是否使用Utf8密码的字符集
     */
    public init (charset: ?Charset, bufferSize: Int64, useUtf8CharsetForPasswords: Bool)
    
    /*
     * 获取编码格式
     * 
     * 返回值 ?Charset - 编码格式
     */
    public func getCharset (): ?Charset
    
    /*
     * 获取数据大小
     * 
     * 返回值 Int64 - 数据大小
     */
    public func getBufferSize (): Int64
    
    /*
     * 判断是否使用Utf8密码的字符集
     * 
     * 返回值 Bool - 是否使用Utf8密码的字符集
     */
    public func isUseUtf8CharsetForPasswords (): Bool
}

public class Zip64EndOfCentralDirectoryRecord<: ZipHeader {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 获取结束中央目录记录大小
     * 
     * 返回值 Int64 - 结束中央目录记录大小
     */
    public func getSizeOfZip64EndCentralDirectoryRecord (): Int64
    
    /*
     * 设置结束中央目录记录大小
     * 
     * 参数 sizeOfZip64EndCentralDirectoryRecord - 结束中央目录记录大小
     *
     */
    public func setSizeOfZip64EndCentralDirectoryRecord (sizeOfZip64EndCentralDirectoryRecord: Int64): Unit
    
    /*
     * 获取版本
     * 
     * 返回值 Int32 - 版本
     */
    public func getVersionMadeBy (): Int32
    
    /*
     * 设置版本
     * 
     * 参数 versionMadeBy - 版本
     * 
     */
    public func setVersionMadeBy (versionMadeBy: Int32): Unit
    
    /*
     * 获取所需的版本
     * 
     * 返回值 Int32 - 所需的版本
     */
    public func getVersionNeededToExtract (): Int32
    
    /*
     * 设置所需的版本
     * 
     * 参数 versionNeededToExtract - 所需的版本
     * 
     */
    public func setVersionNeededToExtract (versionNeededToExtract: Int32): Unit
    
    /*
     * 获取磁盘的数量
     * 
     * 返回值 Int32 - 磁盘的数量
     */
    public func getNumberOfThisDisk (): Int32
    
    /*
     * 设置磁盘的数量
     * 
     * 参数 numberOfThisDisk - 磁盘的数量
     * 
     */
    public func setNumberOfThisDisk (numberOfThisDisk: Int32): Unit
    
    /*
     * 获取磁盘的数目中央目录的起始位置
     * 
     * 返回值 Int32 - 磁盘的数目中央目录的起始位置
     */
    public func getNumberOfThisDiskStartOfCentralDirectory (): Int32
    
    /*
     * 设置磁盘的数目中央目录的起始位置
     * 
     * 参数 numberOfThisDiskStartOfCentralDirectory - 磁盘的数目中央目录的起始位置
     * 
     */
    public func setNumberOfThisDiskStartOfCentralDirectory (numberOfThisDiskStartOfCentralDirectory: Int32): Unit
    
    /*
     * 获取磁盘上中央目录中的条目总数
     * 
     * 返回值 Int64 - 磁盘上中央目录中的条目总数
     */
    public func getTotalNumberOfEntriesInCentralDirectoryOnThisDisk (): Int64
    
    /*
     * 设置磁盘上中央目录中的条目总数
     * 
     * 参数 totalNumberOfEntriesInCentralDirectoryOnThisDisk - 磁盘上中央目录中的条目总数
     * 
     */
    public func setTotalNumberOfEntriesInCentralDirectoryOnThisDisk (totalNumberOfEntriesInCentralDirectoryOnThisDisk: Int64): Unit
    
    /*
     * 获取中央目录中的条目总数
     * 
     * 返回值 Int64 - 中央目录中的条目总数
     */
    public func getTotalNumberOfEntriesInCentralDirectory (): Int64
    
    /*
     * 设置中央目录中的条目总数
     * 
     * 参数 totalNumberOfEntriesInCentralDirectory - 中央目录中的条目总数
     * 
     */
    public func setTotalNumberOfEntriesInCentralDirectory (totalNumberOfEntriesInCentralDirectory: Int64): Unit
    
    /*
     * 获取中央目录的大小
     * 
     * 返回值 Int64 - 中央目录的大小
     */
    public func getSizeOfCentralDirectory (): Int64
    
    /*
     * 设置中央目录的大小
     * 
     * 参数 sizeOfCentralDirectory - 中央目录的大小
     * 
     */
    public func setSizeOfCentralDirectory (sizeOfCentralDirectory: Int64): Unit
    
    /*
     * 获取启动磁盘编号
     * 
     * 返回值 Int64 - 启动磁盘编号
     */
    public func getOffsetStartCentralDirectoryWRTStartDiskNumber (): Int64
    
    /*
     * 设置启动磁盘编号
     * 
     * 参数 offsetStartCentralDirectoryWRTStartDiskNumber - 启动磁盘编号
     * 
     */
    public func setOffsetStartCentralDirectoryWRTStartDiskNumber (offsetStartCentralDirectoryWRTStartDiskNumber: Int64): Unit
    
    /*
     * 获取可扩展数据区
     * 
     * 返回值 ?Array<Byte> - 可扩展数据区
     */
    public func getExtensibleDataSector (): ?Array<Byte>
    
    /*
     * 设置可扩展数据区
     * 
     * 参数 extensibleDataSector - 可扩展数据区
     * 
     */
    public func setExtensibleDataSector (extensibleDataSector: Array<Byte>): Unit
}

public class Zip64ExtendedInfo<: ZipHeader&Equatable<Zip64ExtendedInfo> {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 获取信息的大小
     * 
     * 返回值 Int32 - 信息的大小
     */
    public func getSize (): Int32
    
    /*
     * 设置信息的大小
     * 
     * 参数 size - 信息的大小
     *
     */
    public func setSize (size: Int32): Unit
    
    /*
     * 获取压缩的大小
     * 
     * 返回值 Int64 - 压缩的大小
     */
    public func getCompressedSize (): Int64
    
    /*
     * 设置压缩的大小
     * 
     * 参数 compressedSize - 压缩的大小
     * 
     */
    public func setCompressedSize (compressedSize: Int64): Unit
    
    /*
     * 获取解压的大小
     * 
     * 返回值 Int64 - 解压的大小
     */
    public func getUncompressedSize (): Int64
    
    /*
     * 设置解压的大小
     * 
     * 参数 uncompressedSize - 解压的大小
     *
     */
    public func setUncompressedSize (uncompressedSize: Int64): Unit
    
    /*
     * 获取本地偏移量
     * 
     * 返回值 Int64 - 本地偏移量
     */
    public func getOffsetLocalHeader (): Int64
    
    /*
     * 设置本地偏移量
     * 
     * 参数 offsetLocalHeader - 本地偏移量
     * 
     */
    public func setOffsetLocalHeader (offsetLocalHeader: Int64): Unit
    
    /*
     * 获取磁盘开始编号
     * 
     * 返回值 Int32 - 磁盘开始编号
     */
    public func getDiskNumberStart (): Int32
    
    /*
     * 设置磁盘开始编号
     * 
     * 参数 diskNumberStart - 磁盘开始编号
     * 
     */
    public func setDiskNumberStart (diskNumberStart: Int32): Unit
    
    /*
     * 判断两个 Zip64ExtendedInfo 对象是否相等
     * 
     * 参数 that - 需要匹配的 Zip64ExtendedInfo 对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func == (that: Zip64ExtendedInfo): Bool
    
    /*
     * 判断两个 Zip64ExtendedInfo 对象是否不相等
     * 
     * 参数 that - 需要匹配的 Zip64ExtendedInfo 对象
     * 返回值 Bool - 判断两个对象是否不相等
     */
    public operator func != (that: Zip64ExtendedInfo): Bool
}

public class DataDescriptor<: ZipHeader {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 获取检测原始数据
     * 
     * 返回值 Int64 - 检测原始数据
     */
    public func getCrc (): Int64
    
    /*
     * 设置检测原始数据 
     * 
     * 参数 crc - 检测原始数据
     * 
     */
    public func setCrc (crc: Int64): Unit
    
    /*
     * 获取压缩的大小
     * 
     * 返回值 Int64 - 压缩的大小
     */
    public func getCompressedSize (): Int64
    
    /*
     * 设置压缩的大小
     * 
     * 参数 compressedSize - 压缩的大小
     * 
     */
    public func setCompressedSize (compressedSize: Int64): Unit
    
    /*
     * 获取解压的大小
     * 
     * 返回值 Int64 - 解压的大小
     */
    public func getUncompressedSize (): Int64
    
    /*
     * 设置解压的大小
     * 
     * 参数 uncompressedSize - 解压的大小
     * 
     */
    public func setUncompressedSize (uncompressedSize: Int64): Unit
}

public class ZipParameters {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 构造 
     * 
     * 参数 zipParameters - ZipParameters对象
     */
    public init (zipParameters: ZipParameters)
    
    /*
     * 获取压缩方法
     * 
     * 返回值 CompressionMethod - 压缩方法
     */
    public func getCompressionMethod (): CompressionMethod
    
    /*
     * 设置压缩方法
     * 
     * 参数 compressionMethod - 压缩方法
     */
    public func setCompressionMethod (compressionMethod: CompressionMethod): Unit
    
    /*
     * 判断是否加密文件 
     * 
     * 返回值 Bool - 是否加密文件
     */
    public func isEncryptFiles (): Bool
    
    /*
     * 设置是否加密文件 
     * 
     * 参数 encryptFiles - 是否加密文件 
     */
    public func setEncryptFiles (encryptFiles: Bool): Unit
    
    /*
     * 获取加密方法
     * 
     * 返回值 EncryptionMethod - 加密方法
     */
    public func getEncryptionMethod (): EncryptionMethod
    
    /*
     * 设置加密方法
     * 
     * 参数 encryptionMethod - 加密方法
     */
    public func setEncryptionMethod (encryptionMethod: EncryptionMethod): Unit
    
    /*
     * 获取压缩级别
     * 
     * 返回值 CompressionLevel - 压缩级别
     */
    public func getCompressionLevel (): CompressionLevel
    
    /*
     * 设置压缩级别
     * 
     * 参数 compressionLevel - 压缩级别
     */
    public func setCompressionLevel (compressionLevel: CompressionLevel): Unit
    
    /*
     * 判断文件属性为是否可读
     * 
     * 返回值 Bool - 文件属性是否为可读
     */
    public func isReadHiddenFiles (): Bool
    
    /*
     * 设置文件属性为可读
     * 
     * 参数 readHiddenFiles - 文件属性是否为可读
     */
    public func setReadHiddenFiles (readHiddenFiles: Bool): Unit
    
    /*
     * 判断是否读取隐藏文件夹 
     * 
     * 返回值 Bool - 是否读取隐藏文件夹
     */
    public func isReadHiddenFolders (): Bool
    
    /*
     * 设置是否读取隐藏文件夹
     * 
     * 参数 readHiddenFolders - 是否读取隐藏文件夹
     */
    public func setReadHiddenFolders (readHiddenFolders: Bool): Unit
    
    /*
     * 获取AES加密密钥长度
     * 
     * 返回值 AesKeyStrength - AES加密密钥长度
     */
    public func getAesKeyStrength (): AesKeyStrength
    
    /*
     * 设置AES加密密钥长度
     * 
     * 参数 aesKeyStrength - AES加密密钥长度
     */
    public func setAesKeyStrength (aesKeyStrength: AesKeyStrength): Unit
    
    /*
     * 获取AES加密版本
     * 
     * 返回值 AesVersion - AES加密版本
     */
    public func getAesVersion (): AesVersion
    
    /*
     * 设置AES加密版本
     * 
     * 参数 aesVersion - AES加密版本
     */
    public func setAesVersion (aesVersion: AesVersion): Unit
    
    /*
     * 判断是否包括根文件夹
     * 
     * 返回值 Bool - 是否包括根文件夹
     */
    public func isIncludeRootFolder (): Bool
    
    /*
     * 设置是否包括根文件夹
     * 
     * 参数 includeRootFolder - 是否包括根文件夹
     */
    public func setIncludeRootFolder (includeRootFolder: Bool): Unit
    
    /*
     * 获取CRC校验
     * 
     */
    public func getEntryCRC (): Int64
    
    /*
     * 设置CRC校验
     * 
     * 参数 entryCRC - CRC校验
     */
    public func setEntryCRC (entryCRC: Int64): Unit
    
    /*
     * 获取默认文件夹路径
     * 
     */
    public func getDefaultFolderPath (): ?String
    
    /*
     * 设置默认文件夹路径
     * 
     * 参数 defaultFolderPath - 默认文件夹路径
     */
    public func setDefaultFolderPath (defaultFolderPath: String): Unit
    
    /*
     * 获取Zip中的文件名
     * 
     * 返回值 ?String - Zip中的文件名
     */
    public func getFileNameInZip (): ?String
    
    /*
     * 设置Zip中的文件名
     * 
     * 参数 fileNameInZip - Zip中的文件名
     */
    public func setFileNameInZip (fileNameInZip: String): Unit
    
    /*
     * 获取上次修改的文件时间
     * 
     * 返回值 Int64 - 上次修改的文件时间
     */
    public func getLastModifiedFileTime (): Int64
    
    /*
     * 设置上次修改的文件时间
     * 
     * 参数 lastModifiedFileTime - 上次修改的文件时间
     */
    public func setLastModifiedFileTime (lastModifiedFileTime: Int64): Unit
    
    /*
     * 获取条目大小
     * 
     */
    public func getEntrySize (): Int64
    
    /*
     * 设置条目大小
     * 
     * 参数 entrySize - 
     */
    public func setEntrySize (entrySize: Int64): Unit
    
    /*
     * 判断是否写入扩展的本地文件头 
     * 
     */
    public func isWriteExtendedLocalFileHeader (): Bool
    
    /*
     * 设置是否写入扩展的本地文件头 
     * 
     * 参数 writeExtendedLocalFileHeader - 是否写入扩展的本地文件头 
     */
    public func setWriteExtendedLocalFileHeader (writeExtendedLocalFileHeader: Bool): Unit
    
    /*
     * 判断是否覆盖现有文件 
     * 
     * 返回值 Bool - 是否覆盖现有文件 
     */
    public func isOverrideExistingFilesInZip (): Bool
    
    /*
     * 设置是否覆盖现有文件 
     * 
     * 参数 overrideExistingFilesInZip - 是否覆盖现有文件 
     */
    public func setOverrideExistingFilesInZip (overrideExistingFilesInZip: Bool): Unit
    
    /*
     * 获取Zip中的根文件夹名称
     * 
     * 返回值 ?String - Zip中的根文件夹名称
     */
    public func getRootFolderNameInZip (): ?String
    
    /*
     * 设置Zip中的根文件夹名称
     * 
     * 参数 rootFolderNameInZip - Zip中的根文件夹名称
     */
    public func setRootFolderNameInZip (rootFolderNameInZip: String): Unit
    
    /*
     * 获取文件注释
     * 
     * 返回值 ?String - 文件注释
     */
    public func getFileComment (): ?String
    
    /*
     * 设置文件注释
     * 
     * 参数 fileComment - 文件注释
     */
    public func setFileComment (fileComment: String): Unit
    
    /*
     * 获取符号链接
     * 
     * 返回值 SymbolicLinkAction - 符号链接
     */
    public func getSymbolicLinkAction (): SymbolicLinkAction
    
    /*
     * 设置符号链接
     * 
     * 参数 symbolicLinkAction - 符号链接
     */
    public func setSymbolicLinkAction (symbolicLinkAction: SymbolicLinkAction): Unit
    
    /*
     * 获取文件过滤器
     * 
     * 返回值 ?ExcludeFileFilter - 文件过滤器, 如果获取不到返回None
     */
    public func getExcludeFileFilter (): ?ExcludeFileFilter
    
    /*
     * 设置文件过滤器
     * 
     * 参数 excludeFileFilter - 文件过滤器
     */
    public func setExcludeFileFilter (excludeFileFilter: ExcludeFileFilter): Unit
    
    /*
     * 判断是否是Unix模式 
     * 
     * 返回值 Bool - 是否是Unix模式 
     */
    public func isUnixMode (): Bool
    
    /*
     * 设置是否是Unix模式 
     * 
     * 参数 unixMode - 是否是Unix模式 
     */
    public func setUnixMode (unixMode: Bool): Unit
}

public class UnzipParameters {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 判断是否提取符号链接 
     * 
     * 返回值 Bool - 是否提取符号链接 
     */
    public func isExtractSymbolicLinks (): Bool
    
    /*
     * 设置是否提取符号链接 
     * 
     * 参数 extractSymbolicLinks - 是否提取符号链接 
     * 
     */
    public func setExtractSymbolicLinks (extractSymbolicLinks: Bool): Unit
}

public class DigitalSignature<: ZipHeader {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 获取数据大小
     * 
     * 返回值 Int32 - 数据大小
     */
    public func getSizeOfData (): Int32
    
    /*
     * 设置数据大小
     * 
     * 参数 sizeOfData - 数据大小
     * 
     */
    public func setSizeOfData (sizeOfData: Int32): Unit
    
    /*
     * 获取签名数据
     * 
     * 返回值 ?String - 签名数据
     */
    public func getSignatureData (): ?String
    
    /*
     * 设置签名数据
     * 
     * 参数 signatureData - 签名数据
     * 
     */
    public func setSignatureData (signatureData: String): Unit
}

public class ArchiveExtraDataRecord<: ZipHeader {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 获取额外字段长度
     * 
     * 返回值 Int32 - 额外字段长度
     */
    public func getExtraFieldLength (): Int32
    
    /*
     * 设置额外字段长度
     * 
     * 参数 extraFieldLength - 额外字段长度
     *
     */
    public func setExtraFieldLength (extraFieldLength: Int32): Unit
    
    /*
     * 获取额外字段数据
     * 
     * 返回值 ?String - 额外字段数据
     */
    public func getExtraFieldData (): ?String
    
    /*
     * 设置额外字段数据
     * 
     * 参数 extraFieldData - 额外字段数据
     * 
     */
    public func setExtraFieldData (extraFieldData: String): Unit
}

public class LocalFileHeader<: AbstractFileHeader {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 获取额外字段
     * 
     * 返回值 ?Array<Byte> - 额外字段
     */
    public func getExtraField (): ?Array<Byte>
    
    /*
     * 设置额外字段
     * 
     * 参数 extraField - 额外字段
     * 
     */
    public func setExtraField (extraField: Array<Byte>): Unit
    
    /*
     * 获取数据的偏移起点
     * 
     * 返回值 Int64 - 数据的偏移起点
     */
    public func getOffsetStartOfData (): Int64
    
    /*
     * 设置数据的偏移起点
     * 
     * 参数 offsetStartOfData - 数据的偏移起点
     * 
     */
    public func setOffsetStartOfData (offsetStartOfData: Int64): Unit
    
    /*
     * 判断是否写入压缩大小 
     * 
     * 返回值 Bool - 
     */
    public func isWriteCompressedSizeInZip64ExtraRecord (): Bool
    
    /*
     * 设置是否写入压缩大小 
     * 
     * 参数 writeCompressedSizeInZip64ExtraRecord - 是否写入压缩大小 
     * 
     */
    public func setWriteCompressedSizeInZip64ExtraRecord (writeCompressedSizeInZip64ExtraRecord: Bool): Unit
}

public class ExtraDataRecord<: ZipHeader {

    /*
     * 构造 
     */
    public init ()
    
    /*
     * 获取Header
     * 
     * 返回值 Int64 - Header
     */
    public func getHeader (): Int64
    
    /*
     * 设置Header
     * 
     * 参数 header - Header
     * 
     */
    public func setHeader (header: Int64): Unit
    
    /*
     * 获取数据大小
     * 
     * 返回值 Int64 - 数据大小
     */
    public func getSizeOfData (): Int64
    
    /*
     * 设置数据大小
     * 
     * 参数 sizeOfData - 数据大小
     * 
     */
    public func setSizeOfData (sizeOfData: Int64): Unit
    
    /*
     * 获取数据
     * 
     * 返回值 ?Array<Byte> - 数据
     */
    public func getData (): ?Array<Byte>
    
    /*
     * 设置数据
     * 
     * 参数 data - 数据
     * 
     */
    public func setData (data: Array<Byte>): Unit
}

public enum CompressionMethod<: Equal<CompressionMethod> {

    | STORE                 // 存储方式, 不进行文件压缩
    | DEFLATE               // 使用deflate算法压缩
    | AES_INTERNAL_ONLY     // 不支持

    /*
     * 获取代码编号
     * 
     * 返回值 ?Array<Byte> - 代码编号
     * 
     */
    public func getCode(): Int32 

    /*
     * 设置从代码获取压缩方法
     * 
     * 参数 code - CompressionMethod 压缩方法, 如果 code大于枚举的范围, 则抛 ZipException
     * 
     */
    public static func getCompressionMethodFromCode(code: Int32): CompressionMethod

    /*
     * 判断两个CompressionMethod对象是否相等
     * 
     * 参数 that - 需要匹配的CompressionMethod对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func ==(that: CompressionMethod): Bool
}

public enum CompressionLevel<: Equal<CompressionLevel> {
    | NO_COMPRESSION
    | FASTEST
    | FASTER
    | FAST
    | MEDIUM_FAST
    | NORMAL
    | HIGHER
    | MAXIMUM
    | PRE_ULTRA
    | ULTRA
    
    
    /*
     * 获取压缩级别
     * 
     * 返回值 Int32 - 压缩级别
     */
    public func getLevel (): Int32
    
    /*
     * 判断两个CompressionLevel对象是否相等
     * 
     * 参数 that - 需要匹配的CompressionLevel对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func == (that: CompressionLevel): Bool
}

public enum RandomAccessFileMode {
    | READ
    | WRITE
    
    /*
     * 获取随机访问文件模式
     * 
     * 返回值 String - 
     */
    public func getValue (): String
}

public enum AesKeyStrength<: Equal<AesKeyStrength> {
    | KEY_STRENGTH_128
    | KEY_STRENGTH_192
    | KEY_STRENGTH_256

    /*
     * 获取原始代码
     * 
     * 返回值 Int32 - 原始代码
     */
    public func getRawCode (): Int32
    
    /*
     * 获取salt长度
     * 
     * 返回值 Int32 - salt长度
     */
    public func getSaltLength (): Int32
    
    /*
     * 获取Mac长度
     * 
     * 返回值 Int32 - Mac长度
     */
    public func getMacLength (): Int32
    
    /*
     * 获取Key密钥长度
     * 
     * 返回值 Int32 - Key密钥长度
     */
    public func getKeyLength (): Int32
    
    /*
     * 获取获取AES加密密钥长度
     * 
     * 参数 code - 获取AES加密密钥长度
     * 
     */
    public static func getAesKeyStrengthFromRawCode (code: Int32): ?AesKeyStrength
    
    /*
     * 判断两个 AesKeyStrength 对象是否相等
     * 
     * 参数 that - 需要匹配的 AesKeyStrength 对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func == (that: AesKeyStrength): Bool
}

public enum EncryptionMethod<: Equal<EncryptionMethod> {

    | NONE                           // 设置None, 抛异常
    | ZIP_STANDARD                   // zip自带加密算法
    | ZIP_STANDARD_VARIANT_STRONG    // 不支持, 抛异常
    | AES                            // AES-256加密算法

    /*
     * 判断两个 EncryptionMethod 对象是否相等
     * 
     * 参数 that - 需要匹配的 EncryptionMethod 对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func ==(that: EncryptionMethod): Bool
}

public enum AesVersion<: Equal<AesVersion> {
    | ONE
    | TWO

    /*
     * 获取版本号
     * 
     * 返回值 Int32 - 版本号
     */
    public func getVersionNumber (): Int32
    
    /*
     * 获取版本号
     * 
     * 参数 versionNumber - 版本号1或者2
     * 
     */
    public static func getFromVersionNumber (versionNumber: Int32): AesVersion
    
    /*
     * 判断两个 AesVersion 对象是否相等
     * 
     * 参数 that - 需要匹配的 AesVersion 对象
     * 返回值 Bool - 判断两个对象是否相等
     */
    public operator func == (that: AesVersion): Bool
}

public class ExtractAllFilesTask<: AbstractExtractFileTask<ExtractAllFilesTaskParameters> {
    
    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel对象
     * 参数 password - 密码Array<Rune>类型
     * 参数 unzipParameters - UnzipParameters对象
     * 参数 asyncTaskParameters - AsyncTaskParameters对象
     */
    public init (zipModel: ZipModel, password: ?Array<Rune>, unzipParameters: UnzipParameters, asyncTaskParameters: AsyncTaskParameters)
}

public class AddStreamToZipTask<: AbstractAddFileToZipTask<AddStreamToZipTaskParameters> {

    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel对象
     * 参数 password - 密码Array<Rune>类型
     * 参数 headerWriter - HeaderWriter对象
     * 参数 asyncTaskParameters - AsyncTaskParameters对象
     */
    public init(zipModel: ZipModel, password: ?Array<Rune>, headerWriter: HeaderWriter, asyncTaskParameters: AsyncTaskParameters )
}

public open class ExecutorService {
    
    /*
     * 构造 
     * 
     */
    public init ()
    
    /*
     * 构建一个ExecutorService实例
     * 
     * 返回值 ExecutorService - ExecutorService实例
     */
    public static func new (): ExecutorService
    
    /*
     * 函数执行
     * 
     * 参数 fn - ()->Unit类型
     *
     */
    public func execute (fn: ()->Unit): Unit
    
    /*
     * 关闭数据
     * 
     */
    public func shutdown ()
}

public class AsyncTaskParameters {
    
    /*
     * 构造 
     * 
     * 参数 executorService - ExecutorService 对象
     * 参数 runInThread - 是否使用线程
     * 参数 progressMonitor - ProgressMonitor对象
     */
    public init (executorService: ?ExecutorService, runInThread: Bool, progressMonitor: ProgressMonitor)
}

public abstract class AsyncZipTask<T>  {
    
    /*
     * 执行taskParameters
     * 
     * 参数 taskParameters - 泛型T
     */
    public open func execute (taskParameters: T)
}

public class MergeSplitZipFileTask<: AsyncZipTask<MergeSplitZipFileTaskParameters> {

    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel 对象
     * 参数 asyncTaskParameters - AsyncTaskParameters对象
     * 
     */
    public MergeSplitZipFileTask(zipModel: ZipModel, asyncTaskParameters: AsyncTaskParameters)
}

public abstract class AbstractExtractFileTask<T> <: AsyncZipTask<T> {
    
    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel 对象
     * 参数 unzipParameters - UnzipParameters 对象 
     * 参数 asyncTaskParameters - AsyncTaskParameters 对象 
     */
    public init (zipModel: ZipModel, unzipParameters: UnzipParameters, asyncTaskParameters: AsyncTaskParameters)
    
    /*
     * 获取ZipModel对象
     * 
     * 返回值 ZipModel - ZipModel对象
     */
    public func getZipModel (): ZipModel
}

public class AddFilesToZipTask<: AbstractAddFileToZipTask<AddFilesToZipTaskParameters> {
    
    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel 对象
     * 参数 password - Array<Rune>类型
     * 参数 headerWriter - HeaderWriter 对象 
     * 参数 asyncTaskParameters - AsyncTaskParameters 对象 
     */
    public init(zipModel: ZipModel, password: ?Array<Rune>, headerWriter: HeaderWriter,
                           asyncTaskParameters: AsyncTaskParameters )
}

public class RemoveFilesFromZipTask<: AbstractModifyFileTask<RemoveFilesFromZipTaskParameters> {

    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel 对象
     * 参数 headerWriter - HeaderWriter 对象 
     * 参数 asyncTaskParameters - AsyncTaskParameters 对象 
     */
    public init(zipModel: ZipModel, headerWriter: HeaderWriter, asyncTaskParameters: AsyncTaskParameters )
}

public abstract class AbstractAddFileToZipTask<T> <: AsyncZipTask<T> {
    
    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel 对象
     * 参数 password - Array<Rune>类型
     * 参数 headerWriter - HeaderWriter 对象
     * 参数 asyncTaskParameters - AsyncTaskParameters 对象 
     */
    public init (zipModel: ZipModel, password: ?Array<Rune>, headerWriter: HeaderWriter, asyncTaskParameters: AsyncTaskParameters)
}

public class ExtractAllFilesTaskParameters<: AbstractZipTaskParameters {

    /*
     * 构造 
     * 
     * 参数 outputPath - String类型
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init(outputPath: String, zip4jConfig: Zip4cjConfig)
}

public class RemoveFilesFromZipTaskParameters<: AbstractZipTaskParameters {
    
    /*
     * 构造 
     * 
     * 参数 filesToRemove - ArrayList<String> 类型
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init (filesToRemove: ArrayList<String>, zip4jConfig: Zip4cjConfig)
}

public class AddFolderToZipTaskParameters<: AbstractZipTaskParameters {
    
    /*
     * 构造 
     * 
     * 参数 folderToAdd - Path 类型
     * 参数 zipParameters - ZipParameters 对象
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init (folderToAdd: Path, zipParameters: ZipParameters, zip4jConfig: Zip4cjConfig)
}

public class AddStreamToZipTaskParameters<: AbstractZipTaskParameters {
    
    /*
     * 构造 
     * 
     * 参数 inputStream - InputStream 类型
     * 参数 zipParameters - ZipParameters 对象
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init (inputStream: InputStream, zipParameters: ZipParameters, zip4jConfig: Zip4cjConfig)
}

public class ExtractFileTaskParameters<: AbstractZipTaskParameters {

    /*
     * 构造 
     * 
     * 参数 outputPath - String 类型
     * 参数 fileToExtract - String 类型
     * 参数 newFileName - String 类型
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init(outputPath: String, fileToExtract: String, newFileName: String,
                                        zip4jConfig: Zip4cjConfig)
}

public class MergeSplitZipFileTaskParameters<: AbstractZipTaskParameters {

    /*
     * 构造 
     * 
     * 参数 outputZipFile - File 类型
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init(outputZipFile: Path, zip4jConfig: Zip4cjConfig) 
}

public class RenameFilesTaskParameters<: AbstractZipTaskParameters {
    
    /*
     * 构造 
     * 
     * 参数 fileNamesMap - HashMap<String, String> 类型
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init(fileNamesMap: HashMap<String, String>, zip4jConfig: Zip4cjConfig)
}

public class SetCommentTaskTaskParameters<: AbstractZipTaskParameters {

    /*
     * 构造 
     * 
     * 参数 comment - String 类型
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init(comment: String, zip4jConfig: Zip4cjConfig) 
}

public class AddFilesToZipTaskParameters<: AbstractZipTaskParameters {
    
    /*
     * 构造 
     * 
     * 参数 filesToAdd - Array<Path> 类型
     * 参数 zipParameters - ZipParameters 对象
     * 参数 zip4jConfig - Zip4cjConfig 对象
     */
    public init (filesToAdd: Array<Path>, zipParameters: ZipParameters, zip4jConfig: Zip4cjConfig)
}

public class AddFolderToZipTask<: AbstractAddFileToZipTask<AddFolderToZipTaskParameters> {

    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel 对象
     * 参数 password - ?Array<Rune> 类型
     * 参数 headerWriter - HeaderWriter 对象
     * 参数 asyncTaskParameters - AsyncTaskParameters 对象
     */
    public init(zipModel: ZipModel, password: ?Array<Rune>, headerWriter: HeaderWriter, asyncTaskParameters: AsyncTaskParameters )

}

public class ExtractFileTask<: AbstractExtractFileTask<ExtractFileTaskParameters> {

    /*
     * 构造 
     * 
     * 参数 zipModel - ZipModel 对象
     * 参数 password - ?Array<Rune> 类型
     * 参数 unzipParameters - UnzipParameters 对象
     * 参数 asyncTaskParameters - AsyncTaskParameters 对象
     */
    public init(zipModel: ZipModel, password: ?Array<Rune>, unzipParameters: UnzipParameters,
                         asyncTaskParameters: AsyncTaskParameters )
}

public class ZipException<: Exception {
    
    /*
     * 构造 
     * 
     * 参数 message - String 类型
     */
    public init (message: String)
    
    /*
     * 构造 
     * 
     * 参数 message - String 类型
     * 参数 typeEnum - ZipExceptionType 对象
     */
    public init (message: String, typeEnum: ZipExceptionType)
    
    /*
     * 获取压缩类型
     * 
     * 返回值 ZipExceptionType - ZipExceptionType对象
     */
    public func getType (): ZipExceptionType
    
    /*
     * 返回 ZipException 异常信息字符串
     * 
     * 返回值 String - ZipException 异常信息字符串
     */
    public override func toString (): String
}

public enum ZipExceptionType {
    | WRONG_PASSWORD
    | TASK_CANCELLED_EXCEPTION
    | CHECKSUM_MISMATCH
    | UNKNOWN_COMPRESSION_METHOD
    | FILE_NOT_FOUND
    | UNSUPPORTED_ENCRYPTION
    | UNKNOWN
}

public class ZipIOException<: Exception {
    
    /*
     * 构造 
     * 
     * 参数 message - 异常信息
     */
    public init (message: String)
}

public class UnsupportedOperationException<: Exception {
    
    /*
     * 构造 
     * 
     */
    public init ()
}

public class AESEngine {

    /*
     * 构造 
     * 
     * 参数 key - aes秘钥信息
     */
    public init(key: Array<Int8>)

    /*
     * 处理 input 数据
     * 
     * 参数 input - Array<Int8> 类型
     * 参数 out - Array<Int8> 对象
     * 返回值 Int32 - Int32
     */
    public func processBlock(input: Array<Int8>, out: Array<Int8>): Int32

    /*
     * 处理 input 数据
     * 
     * 参数 input - Array<Int8> 类型
     * 参数 inOff - input数据起始位置
     * 参数 out - Array<Int8> 对象
     * 参数 outOff - out数据起始位置
     * 返回值 Int32 - Int32
     */
    public func processBlock(input: Array<Int8>, inOff: Int64, out: Array<Int8>, outOff: Int64): Int32
}

public class ZipCryptoEngine {

    /*
     * 构造 
     * 
     */
    public init ()

    /*
     * 初始化密钥 
     * 参数 password - 密钥内容
     * 参数 useUtf8ForPassword - 是否使用utf8格式
     */
    public func initKeys(password: Array<Rune>, useUtf8ForPassword: Bool)

    /*
     * 更新密钥数据
     * 
     * 参数 charAt - 密钥数据
     *
     */
    public func updateKeys(charAt: Byte)

    /*
     * crc校验
     * 
     * 参数 oldCrc - crc校验
     * 参数 charAt - 密钥数据
     * 返回值 Int32 - 校验返回值
     */
    private func crc32(oldCrc: Int32, charAt: Byte): Int32

    /*
     * 加密字节
     * 
     * 返回值 Int32 - 加密字节
     */
    public func decryptByte(): Byte
}

public class PBKDF2Engine {

    /*
     * 构造 
     * 
     * 参数 parameters - PBKDF2Parameters对象
     */
    public init (parameters: PBKDF2Parameters)

    /*
     * 衍生密钥
     * 
     * 参数 inputPassword - 密钥数据
     * 参数 dkLen - 密钥长度
     * 参数 useUtf8ForPassword - 是否使用utf8格式
     * 返回值 Array<Byte> - 衍生密钥
     */
    public func deriveKey(inputPassword: Array<Rune>, dkLen: Int32, useUtf8ForPassword: Bool): Array<Byte>
}
 
public class PBKDF2Parameters {

    /*
     * 构造 
     * 
     * 参数 hashAlgorithm - hash算法
     * 参数 hashCharset - 散列字符集
     * 参数 salt - Array<Byte>类型
     * 参数 iterationCount - 迭代计数
     */
    public init(hashAlgorithm: String, hashCharset: String, salt: Array<Byte>, iterationCount: Int32)

    /*
     * 构造 
     * 
     * 参数 hashAlgorithm - hash算法
     * 参数 hashCharset - 散列字符集
     * 参数 salt - Array<Byte>类型
     * 参数 iterationCount - 迭代计数
     * 参数 derivedKey - 派生密钥
     */
    public init(hashAlgorithm: String, hashCharset: String, salt: Array<Byte>, iterationCount: Int32,
                            derivedKey: ?Array<Byte>) 

    /*
     * 获取迭代计数
     * 
     * 返回值 Int32 - 迭代计数
     */
    public func getIterationCount(): Int32

    /*
     * 设置迭代计数
     * 
     * 参数 iterationCount - 迭代计数
     * 
     */
    public func setIterationCount(iterationCount: Int32): Unit

    /*
     * 获取语法盐
     * 
     * 返回值 Array<Byte> - 语法盐
     */
    public func getSalt(): Array<Byte>

    /*
     * 设置语法盐
     * 
     * 参数 salt - 语法盐
     * 
     */
    public func setSalt(salt: Array<Byte>): Unit

    /*
     * 获取派生密钥
     * 
     * 返回值 ?Array<Byte> - 派生密钥
     */
    public func getDerivedKey(): ?Array<Byte>

    /*
     * 设置派生密钥
     * 
     * 参数 derivedKey - 派生密钥
     */
    public func setDerivedKey(derivedKey: Array<Byte>): Unit

    /*
     * 获取hash算法
     * 
     * 返回值 String - hash算法
     */
    public func getHashAlgorithm(): String

    /*
     * 设置hash算法
     * 
     * 参数 hashAlgorithm - hash算法
     */
    public func setHashAlgorithm(hashAlgorithm: String): Unit
}

public interface Encrypter {

    /*
     * 加密数据
     * 
     * 参数 buff - 加密数据
     * 返回值 Int64 - 加密数据长度
     */
    func encryptData(buff: Array<Byte>): Int64

    /*
     * 加密数据
     * 
     * 参数 buff - 加密数据
     * 参数 start - 起始位置
     * 参数 len - 数据长度
     * 返回值 Int64 - 加密数据长度
     */
    func encryptData(buff: Array<Byte>, start: Int64, len: Int64): Int64

}

public class StandardDecrypter <: Decrypter {

    /*
     * 构造 
     * 
     * 参数 password - 密码
     * 参数 crc - crc校验
     * 参数 lastModifiedFileTime - 改进的数据
     * 参数 headerBytes - 标头字节
     * 参数 useUtf8ForPassword - 是否使用uf8格式
     */
    public init(password: ?Array<Rune>, crc: Int64, lastModifiedFileTime: Int64,
                            headerBytes: Array<Byte>, useUtf8ForPassword: Bool)

    /*
     * 加密数据
     * 
     * 参数 buff - 加密数据
     * 参数 start - 起始位置
     * 参数 len - 数据长度
     * 返回值 Int64 - 加密数据长度
     */
    public func decryptData(buff: Array<Byte>, start: Int64, len: Int64): Int64

}

public class StandardEncrypter <: Encrypter {

    /*
     * 构造 
     * 
     * 参数 password - 密码
     * 参数 key - 密钥
     * 参数 useUtf8ForPassword - 是否使用uf8格式
     */
    public StandardEncrypter(password: ?Array<Rune>, key: Int64, useUtf8ForPassword: Bool)

    /*
     * 加密数据
     * 
     * 参数 buff - 加密数据
     * 返回值 Int64 - 加密数据长度
     */
    public func encryptData(buff: Array<Byte>): Int64

    /*
     * 加密数据
     * 
     * 参数 buff - 加密数据
     * 参数 start - 起始位置
     * 参数 len - 数据长度
     * 返回值 Int64 - 加密数据长度
     */
    public func encryptData(buff: Array<Byte>, start: Int64, len: Int64): Int64

    /*
     * 获取标头字节
     * 
     * 返回值 Array<Byte> - 标头字节内容
     */
    public func getHeaderBytes(): Array<Byte>
}

/*
* 解码Cp437数据
* 
* 参数 arr - 需要解码数据
* 返回值 String - 解码后的数据
*/
public func decodeCp437(arr: Array<Byte>): String 

/*
* 编码Cp437
* 
* 参数 str - 数据
* 返回值 Array<Byte>  - 编码后的数据
*/
public func encodeCp437(str: String): Array<Byte> 

public interface OutputStreamWithSplitZipSupport {

    /*
     * 获取 FilePoin
     * 
     * 返回值 Int64 - FilePoin
     */
    public func getFilePointer (): Int64

    /*
     * 获取当前拆分文件计数器
     * 
     * 返回值 Int32 - 文件数量
     */
    public func getCurrentSplitFileCounter (): Int32
}

public interface ExcludeFileFilter {
    
    /* 
     * 文件排除
     * 
     * 参数 file - 文件路径
     * 返回值 Bool - 排除是否成功
     */
    func isExcluded(file: Path): Bool
}

public enum SymbolicLinkAction <: Equal<SymbolicLinkAction> {

    | INCLUDE_LINK_ONLY

    | INCLUDE_LINKED_FILE_ONLY
    | INCLUDE_LINK_AND_LINKED_FILE

    /*
     * 判等
     * 
     * 参数 that - SymbolicLinkAction
     * 返回值 Bool - 是否相等
     */
    public operator func == (that: SymbolicLinkAction): Bool 
}

public interface PasswordCallback {

    /*
     * 获取密码数据
     * 
     * 返回值 Array<Rune> - 数据
     */
    func getPassword(): Array<Rune>
}

```