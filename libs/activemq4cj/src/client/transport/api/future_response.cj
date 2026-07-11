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

/**
 * 用于设置异步响应的结果
 */
public class FutureResponse {
    private let monitor: Monitor = Monitor()

    private var responseCallback: ?(FutureResponse) -> Unit = None
    private var responseSlot: ?Response = None

    public init() {
    }

    public init(responseCallback: ?(FutureResponse) -> Unit) {
        this.responseCallback = responseCallback
    }

    public func getResult(): ?Response {
        //阻塞获取Response
        if (responseSlot.isNone()) {
            synchronized(monitor) {
                monitor.wait()
            }
        }
        return responseSlot
    }

    public func getResult(timeout: Duration): ?Response {
        if (responseSlot.isNone()) {
            synchronized(monitor) {
                monitor.wait(timeout: timeout)
            }
        }
        return responseSlot
    }

    public func set(result: Response): Unit {
        responseSlot = result
        synchronized(monitor) {
            monitor.notifyAll()
        }

        if (let Some(responseCallback) <- responseCallback) {
            responseCallback(this)
        }
    }
}
