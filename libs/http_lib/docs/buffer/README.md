 # ByteBuffer 文档

 
 ## 概述

 `ByteBuffer` 是 `http_lib` 底层 I/O 的基础数据结构，一个可增长的字节缓冲区，为 HTTP 协议解析、帧读写和消息序列化提供底层存储支持。

 ByteBuffer 通过 `position`（当前读写位置）和 `limit`（有效数据末尾）两个游标管理缓冲区的读写状态，支持高效的顺序读写和随机访问。

 ## 快速参考

 ```cangjie
 import http_lib.buffer.ByteBuffer
 ```

 ## 创建 ByteBuffer

 ```cangjie
 // 默认容量 4096 字节
 let buf = ByteBuffer()

 // 自定义初始容量
 let buf = ByteBuffer(capacity: 1024)

 // 从已有数据创建（克隆数据）
 let data = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"
 let buf = ByteBuffer(data)

 // 零拷贝包装（直接使用已有数组，不复制）
 let buf = ByteBuffer.fromOwned(data)
 ```

 ## 写入数据

 ```cangjie
 // 写入字节数组
 buf.write([0x48, 0x65, 0x6C, 0x6C, 0x6F])

 // 写入指定偏移和长度
 buf.write(bytes, offset: 2, length: 3)

 // 写入单字节
 buf.writeByte(0x0A'U8)

 // 写入字符串（UTF-8 编码）
 buf.writeString("Hello")

 // 预留可写空间
 buf.reserveWritable(1024)
 ```

 ## 读取数据

 ```cangjie
 // 读取单字节
 match (buf.readByte()) {
     case Some(b) => println("${b}")
     case None => println("缓冲区已空")
 }

 // 读取到指定数组
 let dest = Array<UInt8>(10, repeat: 0)
 let n = buf.read(dest)
 let n = buf.read(dest, offset: 2, length: 5)
 ```

 ## 游标操作

 ```cangjie
 let pos = buf.getPosition()
 buf.setPosition(0)
 let end = buf.getLimit()
 let remaining = buf.remaining()
 buf.isReadable()
 ```

 ## 数据转换

 ```cangjie
 let text = buf.toString()
 let bytes = buf.toArray()
 let raw = buf.getArray()
 let hex = buf.toHexString()
 ```

 ## 缓冲区管理

 ```cangjie
 buf.clear()
 buf.compact()
 buf.isEmpty()
 buf.isNotEmpty()
 let cap = buf.capacity()
 buf.skip(10)
 let idx = buf.indexOf([0x0D, 0x0A])
 buf.flip()
 buf.rewind()
 ```

 ## 自动扩容

 当写入数据超出当前容量时，自动扩容：`max(capacity * 2, 所需最小容量)`。

 ## WriteBuffer 辅助类

 ```cangjie
 let writer = WriteBuffer()
 writer.writeByte(0x01'U8)
 writer.writeString("HTTP/1.1")
 writer.writeBytes([0x0D, 0x0A])
 let buf = writer.toBuffer()
 let bytes = writer.toBytes()
 ```

 ## 注意事项

 - **非线程安全**: 多线程共享需外部加锁
 - **零拷贝包装**: `fromOwned()` 直接使用传入数组
 - **游标语义**: position 指向下一次读/写位置，limit 指向有效数据末尾
