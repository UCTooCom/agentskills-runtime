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
package activemq4cj.client.transport.codec

public class ActiveMQCommandHandler <: SingularMessageIoFilter {
    private var transportListener: ?TransportListener = None

    public func setTransportListener(listener: ?TransportListener) {
        this.transportListener = listener
    }

    public init() {
        // 出现异常时不能跳过此IoFilter
        super(skipOnException: false)
    }

    /**
     * 处理入栈消息
     *
     * @throws TransportException
     */
    public func processInboundMessage(context: IoFilterContext, session: Session, inMessage: Any): Unit {
        if (let Some(listener) <- this.transportListener) {
            if (let Some(command) <- (inMessage as Command)) {
                listener.onCommand(command)
            }
            return
        }
        throw TransportException("No transport listener registered")
    }

    /**
     * 处理入栈异常
     *
     */
    public func processInboundException(context: IoFilterContext, session: Session, ex: Exception): Unit {
        if (let Some(transportListener) <- this.transportListener) {
            transportListener.onException(TransportException(ex.message))
        }
    }

    /**
     *  处理出栈消息
     *
     * @throws TransportException
     */
    public func processOutboundMessage(context: IoFilterContext, session: Session, outMessage: Any): Unit {
        if (context.isExceptionCaughted()) {
            return
        }

        if (outMessage is Command) {
            context.offerMessage(outMessage)
            return
        }
        let exception = TransportException("Unsupported message, only accept ActiveMQCommand")
        context.exceptionCaught(exception)
    }

    /**
     * 处理出栈异常
     *
     */
    public func processOutboundException(context: IoFilterContext, session: Session, ex: Exception): Unit {
        context.exceptionCaught(ex)
    }

    public func toString(): String {
        return "ActiveMQCommandHanlder"
    }
}
