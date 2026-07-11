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

/**
 * 
 * @author yangfuping
 */
public class EchoRequestHandler <: SingularMessageIoFilter {

    // 每个连接一个接收响应的Map
    private let allRequestsMap = ConcurrentHashMap<Connection, ConcurrentHashMap<Int64, EchoRequest>>()

    /**
     * 处理入栈消息
     */
    public func processInboundMessage(context: IoFilterContext, session: Session, inMessage: Any): Unit {
        if (let Some(responseMessage) <- (inMessage as String)) {
            let arrays = responseMessage.split(":")
            if (arrays.size == 2) {
                let id = Int64.parse(arrays[0])
                let message = arrays[1]
                let echoResponse = EchoResponse(id, message)

                let requestMap = getRequestMap(session.connection)
                if (let Some(echoRequest) <- requestMap.remove(id)) {
                    echoRequest.setResponse(echoResponse)
                } else {
                    println("Drop message: ${responseMessage}")
                }
            } else {
                println("Drop message: ${responseMessage}")
            }
        } else {
            let exception = Exception("Only accept string message")
            context.exceptionCaught(exception)
        }
    }

    public func processInboundException(context: IoFilterContext, session: Session, ex: Exception) {
        if (let Some(requestMap) <- allRequestsMap.remove(session.connection)) {
            singalExceptionToRequests(requestMap, ex)
        }
    }

    private func singalExceptionToRequests(requests: ConcurrentHashMap<Int64, EchoRequest>, exception: Exception) {
        for ((id, echoRequest) in requests) {
            echoRequest.setException(exception)
        }
    }

    /**
     *  处理出栈消息
     */
    public func processOutboundMessage(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        if (let Some(echoRequest) <- (outMessage as EchoRequest)) {
            let writeMessage = echoRequest.getMessageId().toString() + ":" + echoRequest.getMessage()
            context.offerMessage(writeMessage)

            let requestMap = getRequestMap(session.connection)
            requestMap.add(echoRequest.getMessageId(), echoRequest)
        } else {
            let exception = Exception("Only accept string message")
            context.exceptionCaught(exception)
        }
    }

    public func processOutboundException(context: IoFilterContext, session: Session, ex: Exception): Unit {
        context.exceptionCaught(ex)
    }

    /**
     * 获取连接对应的命令队列
     */
    private func getRequestMap(conn: Connection): ConcurrentHashMap<Int64, EchoRequest> {
        var requestMap = allRequestsMap.get(conn)
        if (let Some(requestMap) <- requestMap) {
            return requestMap
        }

        let createdRequestMap = ConcurrentHashMap<Int64, EchoRequest>()
        requestMap = allRequestsMap.addIfAbsent(conn, createdRequestMap)
        if (let Some(requestMap) <- requestMap) {
            return requestMap
        } else {
            return createdRequestMap
        }
    }

    public func toString() {
        return "EchoRequestHandler"
    }
}
