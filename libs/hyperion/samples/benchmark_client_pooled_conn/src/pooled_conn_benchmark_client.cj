/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */

package benchmark_client_pooled_conn

let DEFAULT_HOST = "127.0.0.1"
let DEFAULT_PORT: UInt16 = 8090
let DEFAULT_THRED_COUNT = 100
let DEFAULT_TOTAL_REQUEST_COUNT = 10000000
let DEFAULT_MAX_CONNECTION = 1
let message = "Hello, world!"

let HOST_ARG = "--host"
let PORT_ARG = "--port"
let THREAD_COUNT_ARG = "--threadCount"
let TOTAL_REQUEST_COUNT = "--totalRequestCount"
let MAX_CONNECTIONS = "--maxConnections"
let LONG_ARG_LIST: Array<String> = 
    ["host=", "port=", "threadCount=", "totalRequestCount=", "maxConnections="]

/**
 * 
 * @author yangfuping
 */
main(args: Array<String>) {
    // LoggerFactory.setLevel(LogLevel.TRACE)
    println(
        "Usage: pooled_conn_benchmark_client/build/release/bin/main --host=127.0.0.1 --port=8090 --maxConnections=1 --threadCount=100 --totalRequestCount=10000000"
    )
    if (args.size > 0) {
        println("Command line args: ${args}")
    }

    println("Start Pooled Connection BenchMarkClient")
    let argOpt = ArgOpt(args, "", LONG_ARG_LIST)

    var host = DEFAULT_HOST
    var port = DEFAULT_PORT
    var threadCount = DEFAULT_THRED_COUNT
    var totalRequestCount = DEFAULT_TOTAL_REQUEST_COUNT
    var maxConnections = DEFAULT_MAX_CONNECTION
    if (let Some(argHost) <- argOpt.getArg(HOST_ARG)) {
        host = argHost
    }

    if (let Some(argPort) <- argOpt.getArg(PORT_ARG)) {
        port = UInt16.parse(argPort)
    }

    if (let Some(argThreadCount) <- argOpt.getArg(THREAD_COUNT_ARG)) {
        threadCount = Int64.parse(argThreadCount)
    }

    if (let Some(argTotalRequestCount) <- argOpt.getArg(TOTAL_REQUEST_COUNT)) {
        totalRequestCount = Int64.parse(argTotalRequestCount)
    }

    if (let Some(argMaxConnections) <- argOpt.getArg(MAX_CONNECTIONS)) {
        maxConnections = Int64.parse(argMaxConnections)
    }

    println("Server: ${host}:${port}")
    println("Thread count: ${threadCount}")
    println("Total request count: ${totalRequestCount}")
    println("Max connections: ${maxConnections}")

    let config = ClientEndpointConfig()
    config.host = host
    config.port = port
    config.noDelay = true
    config.readTimeout = Duration.second * 60
    config.writeTimeout = Duration.second * 30

    // 是否允许借出的连接被多个线程同时使用
    config.useNonExclusiveObjectPool = false
    // 是否开启每个连接一个写线程
    config.asyncWrite = true
    // 是否通过切片方式减少数组拷贝
    config.sliceExceedBuffer = true
    // 是否将ByteBuffer池化重用
    config.usePooledBufferAllocator = true

    config.minConnections = maxConnections
    config.maxConnections = maxConnections

    // 客户端使用的线程池
    let threadPool = ThreadPoolFactory.createThreadPool(3, 128, 4096, Duration.minute * 2)
    // 创建客户端Endpoint
    let tcpEndpoint = ClientTcpEndpoint(config, threadPool)

    // 使用4字节记录报文长度的编解码器
    let lengthFrameEncoder = LengthBasedFrameEncoder(4)
    let lengthFrameDecoder = LengthBasedFrameDecoder(4)
    // 判断报文是否包含完整消息的MessageCompletedHandler
    tcpEndpoint.setMessageCompletedHandler(lengthFrameDecoder)
    // 解析报文长度的IoFilter
    tcpEndpoint.addFilter(LengthBasedFrameCodec(lengthFrameEncoder, lengthFrameDecoder))
    // 字符串和二进制数组转换的IoFilter
    tcpEndpoint.addFilter(ByteAndStringCodec())
    // 接收消息并缓存消息到队列中的IoFilter
    let clientHandler = EchoRequestHandler()
    tcpEndpoint.addFilter(clientHandler)
    // 启动客户端Endpoint
    tcpEndpoint.start()
    println("Start ClientTcpEndpoint")

    // 创建会话
    try (session = tcpEndpoint.createSession()) {
        // 发送消息，并收取对应的响应
        for (i in 1..=100) {
            let echoRequest = EchoRequest(i, "Message${i}")
            println("Send message: ${echoRequest}")
            session.writeAndFlushMessage(echoRequest)

            try {
                let echoResponse = echoRequest.waitForResponse()
                println("Client receive message: ${echoResponse}")
            } catch (ex: Exception) {
                ex.printStackTrace()
            }
        }
    }

    let barrier = Barrier(threadCount + 1)
    var executeNum = totalRequestCount / threadCount
    if (totalRequestCount % threadCount > 0) {
        executeNum = executeNum + 1
    }
    let loopCount = executeNum
    let finalTotalRequestCount = totalRequestCount
    // 启动压测线程
    for (i in 1..=threadCount) {
        spawn {
             =>
            let task = PooledConnPerformanceTask(tcpEndpoint, finalTotalRequestCount, loopCount, message, barrier)
            task.run()
        }
    }

    var startTime = DateTime.now()
    barrier.wait()
    let startDateFromat = formatDateTime(startTime);
    println("${startDateFromat}, start bench mark");

    // statistic tps
    var lastCount = 0
    var lastTime = startTime
    while (true) {
        sleep(Duration.second * 10);
        if (TaskController.stopTime.load() != 0) {
            break;
        }

        let currentCount = TaskController.totalInvokeCount.load()
        let now = DateTime.now()
        let formatDate = formatDateTime(now)
        let delatCount = currentCount - lastCount
        let tps = currentCount * 1000 / (now.toUnixTimeStamp().toMilliseconds() -
            startTime.toUnixTimeStamp().toMilliseconds())
        let delatTps = delatCount * 1000 / (now.toUnixTimeStamp().toMilliseconds() -
            lastTime.toUnixTimeStamp().toMilliseconds())
        lastCount = currentCount
        lastTime = now
        println("${formatDate}, total count: ${currentCount}, total tps: ${tps}, immediately tps: ${delatTps}")

        if (totalRequestCount != -1 && (currentCount >= totalRequestCount)) {
            if (TaskController.running.load()) {
                TaskController.running.compareAndSwap(true, false)
            }
        }
    }

    let endTimeMills = TaskController.stopTime.load()
    let endDateTime = DateTime.fromUnixTimeStamp(Duration.millisecond * endTimeMills)
    let endDateFromat = formatDateTime(endDateTime);
    let totalCount = TaskController.totalInvokeCount.load()
    let totalTps = totalCount * 1000 / (endTimeMills - startTime.toUnixTimeStamp().toMilliseconds());
    println("${endDateFromat}, total count: ${totalCount}  final tps: ${totalTps}.")

    println("Stop BenchMarkClient")
    // GC后打HeapDump，查看是否有内存泄露
    GC(heavy: false)

    sleep(Duration.minute * 5)
}

func formatDateTime(dateTime: DateTime): String {
    let year = dateTime.year
    let month = dateTime.month.toInteger()
    let day = dateTime.dayOfMonth
    let hour = dateTime.hour
    let minute = dateTime.minute
    let second = dateTime.second
    let millSecond = dateTime.nanosecond / (1000 * 1000)

    return year.format("04") + "-" + month.format("02") + "-" + day.format("02") + "-" + hour.format("02") + ":" +
        minute.format("02") + ":" + second.format("02") + "." + millSecond.format("03")
}
