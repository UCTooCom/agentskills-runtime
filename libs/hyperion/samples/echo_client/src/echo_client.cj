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

package echo_client

/**
 * 
 * @author yangfuping
 */
main() {
    println("Start Client")

    let config = ClientEndpointConfig()
    config.host = "127.0.0.1"
    config.port = 8090
    config.noDelay = true
    config.readTimeout = Duration.second * 60
    config.writeTimeout = Duration.second * 30
    config.receiveBufferSize = 32768
    config.sendBufferSize = 32768

    config.minConnections = 0
    config.maxConnections = 5

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
    let clientHandler = ClientHandler()
    tcpEndpoint.addFilter(clientHandler)
    // 启动客户端Endpoint
    tcpEndpoint.start()
    println("Start ClientTcpEndpoint")

    // 创建会话
    try (session = tcpEndpoint.createSession()) {
        // 发送消息，并收取对应的响应
        for (i in 1..=100) {
            let message = "Message${i}"
            println("Send message: ${message}")
            session.writeAndFlushMessage(message)

            try {
                let receiveMsg = clientHandler.takeMessage()
                println("Client receive message: ${receiveMsg}")
            } catch (ex: Exception) {
                ex.printStackTrace()
            }
        }
    }

    println("Stop ClientTcpEndpoint")
    tcpEndpoint.stop()
}

/**
 * 响应可能为异常，使用一个包装类
 */
public class EchoResponse {
    private var exception: ?Exception = None

    private var message: ?String = None

    public func setException(exception: Exception) {
        this.exception = exception
    }

    public func getException(): ?Exception {
        return this.exception
    }

    public func setMessage(message: String) {
        this.message = message
    }

    public func getMessage(): String {
        if (let Some(ex) <- exception) {
            throw ex
        }

        if (let Some(message) <- message) {
            return message
        }

        throw Exception("No response message")
    }
}

public class ClientHandler <: SingularMessageIoFilter {
    private let messages = LinkedBlockingQueue<EchoResponse>()

    public func takeMessage(): String {
        let echoResponse = messages.remove()
        return echoResponse.getMessage()
    }

    public func takeMessage(timeout: Duration): ?String {
        if (let Some(echoResponse) <- messages.remove(timeout)) {
            return echoResponse.getMessage()
        }

        return None
    }

    /**
     * 处理入栈消息
     */
    public func processInboundMessage(context: IoFilterContext, session: Session, inMessage: Any): Unit {
        let echoResponse = EchoResponse()
        if (let Some(text) <- (inMessage as String)) {
            echoResponse.setMessage(text)
        } else {
            let exception = Exception("Only accept string message")
            echoResponse.setException(exception)
        }

        // 添加到messages队列中，不再交给下一个IoFilter处理
        messages.add(echoResponse)
    }

    public func processInboundException(context: IoFilterContext, session: Session, ex: Exception) {
        let echoResponse = EchoResponse()
        echoResponse.setException(ex)
        // 添加到messages队列中，不再交给下一个IoFilter处理
        messages.add(echoResponse)
    }

    /**
     *  处理出栈消息
     */
    public func processOutboundMessage(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        if (let Some(text) <- (outMessage as String)) {
            // 直接发给下个IoFilter处理
            context.offerMessage(text)
        } else {
            let exception = Exception("Only accept string message")
            context.exceptionCaught(exception)
        }
    }

    public func processOutboundException(context: IoFilterContext, session: Session, ex: Exception): Unit {
        context.exceptionCaught(ex)
    }

    public func toString() {
        return "ClientHanlder"
    }
}
