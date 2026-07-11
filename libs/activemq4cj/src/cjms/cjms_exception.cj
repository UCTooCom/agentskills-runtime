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
package activemq4cj.cjms

/**
 * JMS2.0规范要求提供以下信息：
 * 1、标准异常信息，可以通过getMessage方法获得
 * 2、特定的错误代码
 * 3、对另一个异常的引用
 */
public open class CJMSException <: Exception {
    private var errorCodeVal: ?String = None

    private var linkedExceptionVal: ?Exception = None<Exception>

    public init(reason: String, errorCode: String, linkedException: Exception) {
        super(reason)
        this.errorCodeVal = errorCode
        this.linkedExceptionVal = linkedException
    }

    public init(reason: String, errorCode: String) {
        super(reason)
        this.errorCodeVal = errorCode
        linkedExceptionVal = None
    }

    public init(reason: String) {
        super(reason)
        this.errorCodeVal = None
        linkedExceptionVal = None
    }

    public prop errorCode: ?String {
        get() {
            return this.errorCodeVal
        }
    }

    public mut prop linkedException: ?Exception {
        get() {
            return this.linkedExceptionVal
        }
        set(value) {
            this.linkedExceptionVal = value
        }
    }
}
