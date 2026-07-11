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
package activemq4cj.client.transport.api

public open class TransportFilter <: TransportListener & Transport {
    protected let next: Transport

    protected var transportListenerVal: ?TransportListener = None

    public TransportFilter(next: Transport) {
        this.next = next
    }

    public mut prop transportListener: ?TransportListener {
        get() {
            return this.transportListenerVal
        }
        set(value) {
            this.transportListenerVal = value
            next.transportListener = this
        }
    }

    /**
     * 单向异步发送
     */
    public open func oneway(command: Command): Unit {
        next.oneway(command)
    }

    public open func asyncRequest(command: Command, responseCallback: ?(FutureResponse) -> Unit): FutureResponse {
        return next.asyncRequest(command, None)
    }

    public open func request(command: Command): ?Response {
        return next.request(command)
    }

    public open func request(command: Command, timeout: Duration): ?Response {
        return next.request(command, timeout)
    }

    public prop faultTolerant: Bool {
        get() {
            return next.faultTolerant
        }
    }

    public prop disposed: Bool {
        get() {
            return next.disposed
        }
    }

    public override func updateURLs(rebalance: Bool, urls: Array<String>): Unit {
        next.updateURLs(rebalance, urls)
    }

    /**
     * 侦听服务端发送的响应命令
     */
    public open func onCommand(command: Command): Unit {
        if (let Some(listener) <- this.transportListener) {
            listener.onCommand(command)
        }
    }

    public open func onException(error: TransportException): Unit {
        if (let Some(transportListener) <- this.transportListener) {
            transportListener.onException(error)
        }
    }

    public func transportInterupted(): Unit {
        if (let Some(transportListener) <- transportListener) {
            transportListener.transportInterupted()
        }
    }

    public func transportResumed(): Unit {
        if (let Some(transportListener) <- transportListener) {
            transportListener.transportResumed()
        }
    }

    public func narrow(target: TypeInfo): Any {
        if (TypeInfo.of(this).isSubtypeOf(target)) {
            return this
        }
        return next.narrow(target)
    }

    public open func start(): Unit {
        //listener是消息侦听组件，必须要配置
        if (transportListener.isNone()) {
            throw ActiveMQException("The transport listener not registered.")
        }
        next.start()
    }

    public open func stop(): Unit {
        next.stop()
    }

    public open func toString(): String {
        return "TransportFilter"
    }
}
