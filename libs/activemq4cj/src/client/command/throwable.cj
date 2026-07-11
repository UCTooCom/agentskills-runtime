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
package activemq4cj.client.command

public class ConnectionError <: BaseCommand {
    private var connectionIdVal: ?ConnectionId = None
    private var exceptionVal: ?Throwable = None

    public func getDataStructureType(): Byte {
        return CommandTypes.CONNECTION_ERROR
    }

    public override func visit(visitor: CommandVisitor): ?Response {
        return visitor.processConnectionError(this)
    }

    public mut prop connectionId: ?ConnectionId {
        get() {
            return this.connectionIdVal
        }
        set(value) {
            this.connectionIdVal = value
        }
    }

    public mut prop exception: ?Throwable {
        get() {
            return this.exceptionVal
        }
        set(value) {
            this.exceptionVal = value
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ConnectionError)) {
            return false
        }
        if (let Some(other) <- (other as ConnectionError)) {
            if (this.connectionIdVal != other.connectionIdVal) {
                return false
            }

            if (this.exceptionVal != other.exceptionVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ConnectionError)) {
            return true
        }
        if (let Some(other) <- (other as ConnectionError)) {
            if (this.connectionIdVal != other.connectionIdVal) {
                return true
            }

            if (this.exceptionVal != other.exceptionVal) {
                return true
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString(): String {
        return "ConnectionError: {${super.toString()}, connectionId: ${connectionIdVal}, exception: ${exceptionVal}}"
    }
}

public class ExceptionResponse <: Response {
    private var exceptionVal: ?Throwable = None

    public func getDataStructureType(): Byte {
        return CommandTypes.EXCEPTION_RESPONSE
    }

    public init() {
    }

    public init(exception: Throwable) {
        this.exceptionVal = exception
    }

    public mut prop exception: ?Throwable {
        get() {
            return this.exceptionVal
        }
        set(value) {
            this.exceptionVal = value
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ExceptionResponse)) {
            return false
        }
        if (let Some(other) <- (other as ExceptionResponse)) {
            if (this.exceptionVal != other.exceptionVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ExceptionResponse)) {
            return true
        }
        if (let Some(other) <- (other as ExceptionResponse)) {
            if (this.exceptionVal != other.exceptionVal) {
                return true
            }

            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public override func toString(): String {
        return "ExceptionResponse: {${super.toString()}, exception: ${exceptionVal}}"
    }
}

public class Throwable <: ToString & Hashable & Equatable<Throwable> {
    private var messageVal: ?String = None
    private var classNameVal: ?String = None
    private var stackTraceVal: ?Array<StackTraceElement> = None
    private var causeVal: ?Throwable = None

    public init() {
    }

    public init(message: String) {
        this.messageVal = message
    }

    public mut prop message: ?String {
        get() {
            return this.messageVal
        }
        set(value) {
            this.messageVal = value
        }
    }

    public mut prop className: ?String {
        get() {
            return this.classNameVal
        }
        set(value) {
            this.classNameVal = value
        }
    }

    public mut prop stackTrace: ?Array<StackTraceElement> {
        get() {
            return this.stackTraceVal
        }
        set(value) {
            this.stackTraceVal = value
        }
    }

    public mut prop cause: ?Throwable {
        get() {
            return this.causeVal
        }
        set(value) {
            this.causeVal = value
        }
    }

    public operator func ==(other: Throwable): Bool {
        if (this.messageVal != other.messageVal) {
            return false
        }

        if (this.classNameVal != other.classNameVal) {
            return false
        }

        if (let Some(stackTrace) <- stackTraceVal) {
            if (let Some(otherStackTrace) <- other.stackTraceVal) {
                if (stackTrace.size != otherStackTrace.size) {
                    return false
                }
            } else {
                return false
            }
        } else {
            if (other.stackTraceVal.isSome()) {
                return false
            }
        }

        if (this.causeVal != other.causeVal) {
            return false
        }
        return true
    }

    public operator func !=(other: Throwable): Bool {
        if (this.messageVal != other.messageVal) {
            return true
        }

        if (this.classNameVal != other.classNameVal) {
            return true
        }

        if (let Some(stackTrace) <- stackTraceVal) {
            if (let Some(otherStackTrace) <- other.stackTraceVal) {
                if (stackTrace.size != otherStackTrace.size) {
                    return true
                }
            } else {
                return true
            }
        } else {
            if (other.stackTraceVal.isSome()) {
                return true
            }
        }

        if (this.causeVal != other.causeVal) {
            return true
        }
        return false
    }

    @OverflowWrapping
    public override func hashCode(): Int64 {
        let prime = 53
        var hashCode = 0
        if (let Some(message) <- messageVal) {
            hashCode += prime * message.hashCode()
        }
        if (let Some(className) <- classNameVal) {
            hashCode += prime * className.hashCode()
        }
        if (let Some(cause) <- causeVal) {
            hashCode += prime * cause.hashCode()
        }
        return hashCode
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("Throwable: {")
        if (let Some(message) <- this.messageVal) {
            sb.append("message: ${message}, ")
        }
        if (let Some(className) <- this.classNameVal) {
            sb.append("class: ${className}, ")
        }
        if (let Some(stackTrace) <- stackTraceVal) {
            sb.append("stackTrace : \n")
            for (s in stackTrace) {
                sb.append(s.declaringClass + "\t")
                sb.append(s.fileName + "\t")
                sb.append(s.lineNumber.toString() + "\t")
                sb.append(s.methodName + "\n")
            }
        }
        sb.append(", cause: ${causeVal}}")
        return sb.toString()
    }
}
