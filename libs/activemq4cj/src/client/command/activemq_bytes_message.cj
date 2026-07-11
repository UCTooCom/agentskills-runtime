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

public class ActiveMQBytesMessage <: ActiveMQMessage & BytesMessage {
    private var dataOut: ?ByteBuffer = None
    private var dataIn: ?ByteBuffer = None

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_BYTES_MESSAGE
    }

    public override func beforeMarshall(): Unit {
        super.beforeMarshall()
        storeContent()
    }

    public override func copy(): Message {
        let copy: ActiveMQBytesMessage = ActiveMQBytesMessage()
        this.copy(copy)
        return copy
    }

    private func copy(copy: ActiveMQBytesMessage): Unit {
        storeContent()
        super.copy(copy)
        copy.dataOut = None
        copy.dataIn = None
    }

    public override func clearBody(): Unit {
        super.clearBody()
        this.dataIn = None
        this.dataOut = None
    }

    public override func getBodyLength(): Int64 {
        initializeReading()
        if (let Some(content) <- this.content) {
            return content.size
        }
        return 0
    }

    public override func readByte(): Byte {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return dataIn.getByte()
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Byte from Bytes")
    }

    public override func writeByte(value: Byte): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putByte(value)
        }
    }

    public override func readInt8(): Int8 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return dataIn.getInt8()
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Int8 from Bytes")
    }

    public override func writeInt8(value: Int8): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putInt8(value)
        }
    }

    public override func readBool(): Bool {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return MarshallingSupport.getBool(dataIn)
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Bool from Bytes")
    }

    public override func writeBool(value: Bool): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            MarshallingSupport.putBool(value, dataOut)
        }
    }

    public override func readChar(): Rune {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return Rune(dataIn.getUInt32())
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Char from Bytes")
    }

    public override func writeChar(value: Rune): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putUInt32(UInt32(value))
        }
    }

    public override func readInt16(): Int16 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return dataIn.getInt16()
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Int16 from Bytes")
    }

    public override func writeInt16(value: Int16): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putInt16(value)
        }
    }

    public override func readUInt16(): UInt16 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return dataIn.getUInt16()
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a UInt16 from Bytes")
    }

    public override func writeUInt16(value: UInt16): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putUInt16(value)
        }
    }

    public override func readInt32(): Int32 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return dataIn.getInt32()
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Int32 from Bytes")
    }

    public override func writeInt32(value: Int32): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putInt32(value)
        }
    }

    public override func readUInt32(): UInt32 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return dataIn.getUInt32()
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a UInt32 from Bytes")
    }

    public override func writeUInt32(value: UInt32): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putUInt32(value)
        }
    }

    public override func readInt64(): Int64 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return dataIn.getInt64()
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Int64 from Bytes")
    }

    public override func writeInt64(value: Int64): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putInt64(value)
        }
    }

    public override func readUInt64(): UInt64 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return dataIn.getUInt64()
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a UInt64 from Bytes")
    }

    public override func writeUInt64(value: UInt64): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.putUInt64(value)
        }
    }

    public override func readFloat32(): Float32 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return MarshallingSupport.getFloat32(dataIn)
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Float32 from Bytes")
    }

    public override func writeFloat32(value: Float32): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            MarshallingSupport.putFloat32(value, dataOut)
        }
    }

    public override func readFloat64(): Float64 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                return MarshallingSupport.getFloat64(dataIn)
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Float64 from Bytes")
    }

    public override func writeFloat64(value: Float64): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            MarshallingSupport.putFloat64(value, dataOut)
        }
    }

    public override func readString(): String {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                if (let Some(str) <- MarshallingSupport.readUTF(dataIn)) {
                    return str
                }
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a String from Bytes")
    }

    public override func writeString(value: String): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            MarshallingSupport.writeUTF(value, dataOut)
        }
    }

    public override func readUTF(): String {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                if (let Some(str) <- MarshallingSupport.readUTF(dataIn)) {
                    return str
                }
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a UTF from Bytes")
    }

    public override func writeUTF(value: String): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            MarshallingSupport.writeUTF(value, dataOut)
        }
    }

    public override func readBytes(dest: Array<Byte>): Unit {
        initializeReading()
        try {
            if (let Some(dataIn) <- dataIn) {
                dataIn.get(dest)
            }
        } catch (e: IndexOutOfBoundsException) {
            throw ExceptionHelper.createMessageEOFException(e)
        }
    }

    public override func writeBytes(value: Array<Byte>): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.put(value)
        }
    }

    public override func reset(): Unit {
        storeContent()
        readOnlyBody = true
        this.dataIn = None
        this.dataOut = None
    }

    private func initializeWriting(): Unit {
        checkReadOnlyBody()
        if (this.dataOut.isNone()) {
            let byteBuffer = ByteBuffer.allocate(8192, expandSupport: true)
            if (let Some(content) <- this.content) {
                MarshallingSupport.putByteArray(doDecompress(content), byteBuffer)
            }
            this.dataOut = byteBuffer
        }
    }

    protected func checkWriteOnlyBody() {
        if (!readOnlyBody) {
            throw MessageNotReadableException("Message body is write-only")
        }
    }

    private func initializeReading(): Unit {
        checkWriteOnlyBody()
        if (this.dataIn.isNone()) {
            if (let Some(content) <- this.content) {
                this.dataIn = ByteBuffer.wrap(doDecompress(content))
            } else {
                this.dataIn = ByteBuffer.wrap(Array<Byte>())
            }
        }
    }

    public func storeContent(): Unit {
        if (let Some(dataOut) <- this.dataOut) {
            dataOut.flip()
            this.content = doCompress(dataOut.toArray())
            this.dataOut = None
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQBytesMessage)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQBytesMessage)) {
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQBytesMessage)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQBytesMessage)) {
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
