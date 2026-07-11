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

package echo_server

/**
 * 
 * @author yangfuping
 */
main() {
    let config = EndpointConfig()
    config.address = "127.0.0.1"
    config.port = 8090
    config.backlogSize = 4096
    config.noDelay = true
    config.readTimeout = Duration.second * 60
    config.writeTimeout = Duration.second * 30
    config.receiveBufferSize = 32768
    config.sendBufferSize = 32768
    config.reuseAddress = false

    // 服务端使用的线程池
    let threadPool = ThreadPoolFactory.createThreadPool(3, 128, 4096, Duration.minute * 2)
    // 创建服务端Endpoint
    let tcpEndpoint = TcpEndpoint(config, threadPool)

    // 使用4字节记录报文长度的编解码器
    let lengthFrameEncoder = LengthBasedFrameEncoder(4)
    let lengthFrameDecoder = LengthBasedFrameDecoder(4)
    // 判断报文是否包含完整消息的MessageCompletedHandler
    tcpEndpoint.setMessageCompletedHandler(lengthFrameDecoder)
    // 解析报文长度的IoFilter
    tcpEndpoint.addFilter(LengthBasedFrameCodec(lengthFrameEncoder, lengthFrameDecoder))
    // 字符串和二进制数组转换的IoFilter
    tcpEndpoint.addFilter(ByteAndStringCodec())
    // 调用服务的IoFilter
    tcpEndpoint.addFilter(EchoHanlder())

    // 启动服务端Endpoint
    tcpEndpoint.start()
    println("TcpEndpoint start")
    println("TcpEndpoint wait request")

    sleep(Duration.hour * 1)
}

public class EchoService {
    public func processMessage(message: String) {
        return message
    }
}

public class EchoHanlder <: SingularMessageIoFilter {
    private let service = EchoService()

    /**
     * 处理入栈消息
     */
    public func processInboundMessage(context: IoFilterContext, session: Session, inMessage: Any): Unit {
        if (let Some(text) <- (inMessage as String)) {
            println("Received Message: ${text}")
            // 调用业务处理逻辑
            let result = service.processMessage(text)
            context.offerMessage(result)
        } else {
            let exception = Exception("Only accept string message")
            context.exceptionCaught(exception)
        }
    }

    public func processInboundException(context: IoFilterContext, session: Session, ex: Exception) {
        context.exceptionCaught(ex)
    }

    /**
     *  处理出栈消息
     */
    public func processOutboundMessage(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        // 转交给下一个IoFilter处理
        context.offerMessage(outMessage)
    }

    public func processOutboundException(context: IoFilterContext, session: Session, ex: Exception): Unit {
        context.exceptionCaught(ex)
    }

    public func toString() {
        return "EchoHanlder"
    }
}
