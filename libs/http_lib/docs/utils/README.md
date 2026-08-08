 # Utils 文档

 
 ## 概述

 `utils` 模块提供 HTTP 协议栈所需的通用工具函数，包括字节数组操作、十六进制编解码、
 端口解析、URL 解析以及 HTTP 消息解析的底层字节搜索。

 ## 快速参考

 ```cangjie
 import http_lib.utils.*
 ```

 ## 字节工具 (bytes.cj)

 ```cangjie
 // 查找 HTTP 头结束标记 \r\n\r\n
 let pos = findHeaderEnd(data, data.size)

 // 查找 \r\n 位置
 let crlf = findCrlf(data, data.size)
 let crlf = findCrlfAt(data, start, end)

 // 在范围内查找特定字节
 let idx = findByte(data, 0, data.size, b'\r')

 // 在范围内查找子序列
 let idx = findBytes(data, [0x0D, 0x0A])

 // 跳过空白字符
 let pos = skipSpaces(data, start)

 // 检查是否全部为空白
 let allSp = isSpaces(data)
 ```

 ## 十六进制编解码 (hex.cj)

 ```cangjie
 // 字节数组 <-> 十六进制字符串
 let hex = bytesToHexString([0x48, 0x65])
 let bytes = hexStringToBytes("4865")

 // 高效编解码（预分配输出数组）
 let hex = hexEncode(data, upperCase: false)
 let bytes = hexDecode("48656c6c6f")

 // 单个字节转换
 let ch = byteToHexChar(0x0F)      // -> 'f'
 let val = hexCharToByte(r'f')     // -> 0x0F
 let byte = hexPairToByte(r'4', r'8')  // -> 0x48

 // 大写十六进制表（用于 URL 编码等）
 HEX_CHARS_UPPER  // "0123456789ABCDEF"
 ```

 ## 端口解析 (parse.cj)

 ```cangjie
 let port = parsePortString("8080")  // -> 8080u16
 ```

 ## URL 解析 (url_parser.cj)

 ```cangjie
 let parsed = ParsedUrl.parse("https://user:pass@example.com:8443/path?q=1")
 parsed.scheme        // "https"
 parsed.host          // "example.com"
 parsed.port          // 8443u16
 parsed.path          // "/path?q=1"
 parsed.user          // Some("user")
 parsed.password      // Some("pass")
 parsed.isSecure      // true
 ```

 ## 基础工具 (utils.cj)

 ```cangjie
 // 字节数组复制
 copyBytes(source, srcOff, dest, destOff, length)

 // 大小比较
 maxInt64(a, b)
 minInt64(a, b)

 // Base64 编码
 let b64 = base64EncodeBytes(data)
 let decoded = base64DecodeString(b64)

 // 字符串 <-> 字节数组（安全封装）
 let bytes = stringToBytes("Hello")
 let str = bytesToString([0x48, 0x65])
 ```

 ## 客户端追踪 (trace.cj)

 分布式请求追踪，支持 OpenTelemetry 兼容的上下文传播：

 ```cangjie
 import http_lib.utils.{generateTraceId, getTraceId, setTraceId}

 // 生成唯一追踪 ID
 let traceId = generateTraceId()
 setTraceId(req, traceId)

 // 从请求中提取追踪 ID
 let id = getTraceId(req)
 ```

 ### ClientTrace

 请求生命周期事件钩子，诊断各阶段耗时：

 ```cangjie
 import http_lib.client.ClientTrace

 let trace = ClientTrace()
 trace.dnsStartHook = Some({host => println("DNS 开始: ${host}")})
 trace.dnsDoneHook = Some({host, addrs => println("DNS 完成: ${host} -> ${addrs}")})
 trace.connectStartHook = Some({network, addr => println("连接开始: ${addr}")})
 trace.connectDoneHook = Some({network, addr, err => println("连接完成: ${addr}")})
 trace.tlsHandshakeStartHook = Some({ => println("TLS 握手开始")})
 trace.tlsHandshakeDoneHook = Some({state, err => println("TLS 握手完成")})
 trace.gotFirstResponseByteHook = Some({ => println("收到响应首字节")})

 let config = HttpClientConfig()
 config.trace = trace
 let client = HttpClient(config: config)
 ```

 ### TraceInfo

 请求生命周期各阶段的时间戳集合：

 ```cangjie
 let client = HttpClient()
 client.traceEnabled = true
 client.get("https://example.com/")

 match (client.lastTrace) {
     case Some(t) =>
         t.dnsStart       // DNS 开始时间
         t.dnsDone        // DNS 结束时间
         t.connectStart   // TCP 连接开始
         t.connectDone    // TCP 连接完成
         t.tlsStart       // TLS 握手开始
         t.tlsDone        // TLS 握手结束
         t.gotFirstByte   // 收到响应首字节
         t.totalTime      // 总耗时
     case None => ()
 }
 ```

 ## 相关模块

 - [Connection 模块](../connection/README.md) — TLS 依赖 SecureRandom
 - [Core API](../core/api.md) — 常量与工具函数
