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
 * Echo Request
 *
 * @author yangfuping
 */
public class EchoRequest <: ToString {
    private let messageId: Int64

    private let message: String

    private var response: ?EchoResponse = None

    private var exception: ?Exception = None<Exception>

    // 因发送请求和等待请求响应在同一个线程，可以使用ThreadLocal中缓存的Monitor
    private let monitor = MonitorCaches.getMonitor()

    public init(messageId: Int64, message: String) {
        this.messageId = messageId
        this.message = message
    }

    public func getMessageId(): Int64 {
        return messageId
    }

    public func getMessage(): String {
        return message
    }

    public func setResponse(response: EchoResponse) {
        this.response = response
        synchronized(monitor.mutex) {
            monitor.condition.notify()
        }
    }

    public func setException(exception: Exception) {
        this.response = response
        synchronized(monitor.mutex) {
            monitor.condition.notify()
        }
    }

    public func waitForResponse(): EchoResponse {
        synchronized(monitor.mutex) {
            while (true) {
                if (let Some(exception) <- exception) {
                    throw exception
                }

                if (let Some(response) <- response) {
                    return response
                } else {
                    monitor.condition.wait()
                }
            }
        }

        throw Exception("Unable to obtain response")
    }

    public func toString(): String {
        return "EchoRequest{messageId: ${messageId}, message: ${message}}"
    }
}
