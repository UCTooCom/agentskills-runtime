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

package benchmark_client

/**
 * 请求响应
 * 
 * @author yangfuping
 */
public class EchoResponse <: ToString {
    private let messageId: Int64

    private var message: String

    public init(messageId: Int64, message: String) {
        this.messageId = messageId
        this.message = message
    }

    public func setMessage(message: String) {
        this.message = message
    }

    public func getMessage(): ?String {
        return message
    }

    public func toString(): String {
        return "EchoResponse{messageId: ${messageId}, message: ${message}}"
    }
}
