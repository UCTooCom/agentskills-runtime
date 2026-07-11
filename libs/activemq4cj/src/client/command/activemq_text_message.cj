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

public open class ActiveMQTextMessage <: ActiveMQMessage & TextMessage {
    private var textVal: ?String = None

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_TEXT_MESSAGE
    }

    public override func beforeMarshall(): Unit {
        super.beforeMarshall()
        storeContentAndClear()
    }

    public func copy(): Message {
        let copy: ActiveMQTextMessage = ActiveMQTextMessage()
        copy.textVal = this.textVal
        super.copy(copy)
        return copy
    }

    public mut prop text: ?String {
        get() {
            if (this.textVal.isNone()) {
                if (let Some(content) <- this.content) {
                    let byteBuffer = ByteBuffer.wrap(doDecompress(content))
                    this.textVal = MarshallingSupport.readUTF8(byteBuffer)
                    this.content = None
                }
            }
            return this.textVal
        }
        set(value) {
            checkReadOnlyBody()
            this.textVal = value
            content = None
        }
    }

    public override func clearBody() {
        super.clearBody()
        this.textVal = None
    }

    public func storeContentAndClear() {
        storeContent()
        this.textVal = None
    }

    public func storeContent(): Unit {
        let dataOut = ByteBuffer.allocate(1024, expandSupport: true)
        if (let Some(text) <- this.textVal) {
            MarshallingSupport.writeUTF8(text, dataOut)
            dataOut.flip()
            this.content = doCompress(dataOut.toArray())
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQTextMessage)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQTextMessage)) {
            if (this.textVal != other.textVal) {
                return false
            }

            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQTextMessage)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQTextMessage)) {
            if (this.textVal != other.textVal) {
                return true
            }
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }

    public open func toString(): String {
        return "ActiveMQTextMessage: {${super.toString()}, text: ${text}}"
    }
}
