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
package activemq4cj.client.transport

public class ResponseCorrelator <: TransportFilter {
    protected static let logger = LoggerFactory.getLogger("responseCorrelator")

    /**
     * 存放commandId与FutureResponse的映射
     */
    private let requestMap: ConcurrentHashMap<Int32, FutureResponse> = ConcurrentHashMap<Int32, FutureResponse>()
    private var error: ?TransportException = None

    /**
     * command序号生成
     */
    private let commandIdGenerator = AtomicInt32(1)

    public init(next: Transport) {
        super(next)
    }

    /**
     * 单向异步发送消息，设置commandId值和responseRequired为false
     */
    public override func oneway(command: Command): Unit {
        command.commandId = commandIdGenerator.fetchAdd(1)
        command.responseRequired = false
        next.oneway(command)
    }

    /**
     * 有响应的异步发送，发送时会初始化一个FutureResponse并注册到map中，name为commandId，因为Response的correlationId与commandId一一对应，
     * 所以在onCommand收到Response时会根据Response的correlationId把对应的FutureResponse取出，设置Response
     */
    private func asyncRequest(command: Command): FutureResponse {
        return this.asyncRequest(command, None)
    }

    public override func asyncRequest(command: Command, responseCallback: ?(FutureResponse) -> Unit): FutureResponse {
        command.commandId = commandIdGenerator.fetchAdd(1)
        command.responseRequired = true

        let future = FutureResponse(responseCallback)
        //处理异常
        if (let Some(error) <- this.error) {
            future.set(ExceptionResponse(createThrowable(error)))
            throw error
        } else {
            requestMap.put(command.commandId, future)
        }

        next.oneway(command)
        return future
    }

    public override func request(command: Command): ?Response {
        let response = asyncRequest(command)
        return response.getResult()
    }

    public override func request(command: Command, timeout: Duration): ?Response {
        let response = asyncRequest(command)
        return response.getResult(timeout)
    }

    public override func onCommand(command: Command): Unit {
        //拦截处理所有的response,其他的给下游处理
        if (let Some(response) <- (command as Response)) {
            if (logger.isTraceEnabled()) {
                logger.log(LogLevel.TRACE, "Receive response: ${response}")
            }
            let future = requestMap.remove(response.correlationId)
            if (let Some(future) <- future) {
                future.set(response)
            }
            return
        }
        if (let Some(listener) <- transportListener) {
            listener.onCommand(command)
        }
    }

    public func onException(error: TransportException) {
        dispose(error)
        super.onException(error)
    }

    public override func stop(): Unit {
        dispose(TransportException("Stopped"))
        super.stop()
    }

    private func dispose(error: TransportException) {
        var exceptionResp = ExceptionResponse(Throwable(error.message))

        if (this.error.isNone()) {
            this.error = error
        }

        for ((k, v) in requestMap) {
            v.set(exceptionResp)
        }
    }

    private func createThrowable(error: Exception): Throwable {
        var throwable = Throwable(error.message)
        throwable.stackTrace = error.getStackTrace()
        return throwable
    }

    public override func toString(): String {
        return "ResponseCorrelator"
    }
}
