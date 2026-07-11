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

public class ActiveMQStreamMessage <: ActiveMQMessage & StreamMessage {
    private var dataOut: ?ByteBuffer = None
    private var dataIn: ?ByteBuffer = None

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_STREAM_MESSAGE
    }

    public override func copy(): Message {
        let copy: ActiveMQStreamMessage = ActiveMQStreamMessage()
        this.copy(copy)
        return copy
    }

    private func copy(copy: ActiveMQStreamMessage): Unit {
        storeContent()
        super.copy(copy)
        copy.dataOut = None
        copy.dataIn = None
    }

    public override func beforeMarshall(): Unit {
        super.beforeMarshall()
        storeContent()
    }

    public override func clearBody(): Unit {
        super.clearBody()
        this.dataIn = None
        this.dataOut = None
    }

    private func initializeWriting(): Unit {
        //初始化写，如果content有值，把content值先写入
        checkReadOnlyBody()
        if (dataOut.isNone()) {
            if (let Some(content) <- this.content) {
                let byteBuffer = ByteBuffer.allocate(8192, expandSupport: true)
                byteBuffer.put(doDecompress(content))
                this.dataOut = byteBuffer
            } else {
                dataOut = ByteBuffer.allocate(1024, expandSupport: true)
            }
        }
    }

    protected func checkWriteOnlyBody() {
        if (!readOnlyBody) {
            throw MessageNotReadableException("Message body is write-only")
        }
    }

    private func initializeReading(): Unit {
        checkWriteOnlyBody()
        //初始化读，把content值包装到ByteBufer
        if (dataIn.isNone()) {
            if (let Some(content) <- content) {
                this.dataIn = ByteBuffer.wrap(doDecompress(content))
            } else {
                dataIn = ByteBuffer.wrap(Array<Byte>())
            }
        }
    }

    public override func readByte(): Byte {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return dataIn.getByte()
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(str) <- MarshallingSupport.readUTF(dataIn)) {
                        return UInt8.parse(str)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Byte.")
                }
                throw MessageFormatException("Not a Byte type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Byte from Stream")
    }

    public override func writeByte(value: Byte): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            MarshallingSupport.marshalByte(value, dataOut)
        }
    }

    public override func readInt8(): Int8 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return Convert.convertToInt8(dataIn.getByte())
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(str) <- MarshallingSupport.readUTF(dataIn)) {
                        return Int8.parse(str)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Int8.")
                }
                throw MessageFormatException("Not a Int8 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Int8 from Stream")
    }

    public override func writeInt8(value: Int8): Unit {
        initializeWriting()
        if (let Some(dataOut) <- this.dataOut) {
            MarshallingSupport.marshalByte(Convert.convertToUInt8(value), dataOut)
        }
    }

    public override func readBool(): Bool {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.BOOLEAN_TYPE) {
                    return MarshallingSupport.getBool(dataIn)
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(str) <- MarshallingSupport.readUTF(dataIn)) {
                        return Bool.parse(str)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Bool.")
                }
                throw MessageFormatException("Not a Bool type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Bool from Stream")
    }

    public override func writeBool(value: Bool): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalBool(value, dataOut)
        }
    }

    public override func readChar(): Rune {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.CHAR_TYPE) {
                    return Rune(dataIn.getUInt32())
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Char.")
                }
                throw MessageFormatException("Not a Char type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Char from Stream")
    }

    public override func writeChar(value: Rune): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalChar(value, dataOut)
        }
    }

    public override func readInt16(): Int16 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.SHORT_TYPE) {
                    return dataIn.getInt16()
                }
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return Int16(dataIn.getInt8())
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(string) <- MarshallingSupport.readUTF(dataIn)) {
                        return Int16.parse(string)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Int16.")
                }
                throw MessageFormatException("Not a Int16 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Int16 from Stream")
    }

    public override func writeInt16(value: Int16): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalInt16(value, dataOut)
        }
    }

    public override func readUInt16(): UInt16 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.SHORT_TYPE) {
                    return Convert.convertToUInt16(dataIn.getInt16())
                }
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return Convert.convertToUInt16(Int16(dataIn.getInt8()))
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(string) <- MarshallingSupport.readUTF(dataIn)) {
                        return UInt16.parse(string)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to UInt16.")
                }
                throw MessageFormatException("Not a UInt16 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a UInt16 from Stream")
    }

    public override func writeUInt16(value: UInt16): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalInt16(Convert.convertToInt16(value), dataOut)
        }
    }

    public override func readInt32(): Int32 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.INTEGER_TYPE) {
                    return dataIn.getInt32()
                }
                if (dataType == MarshallingSupport.SHORT_TYPE) {
                    return Int32(dataIn.getInt16())
                }
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return Int32(dataIn.getInt8())
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(string) <- MarshallingSupport.readUTF(dataIn)) {
                        return Int32.parse(string)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Int32.")
                }
                throw MessageFormatException("Not a Int32 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Int32 from Stream")
    }

    public override func writeInt32(value: Int32): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalInt32(value, dataOut)
        }
    }

    public override func readUInt32(): UInt32 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.INTEGER_TYPE) {
                    return Convert.convertToUInt32(dataIn.getInt32())
                }
                if (dataType == MarshallingSupport.SHORT_TYPE) {
                    return Convert.convertToUInt32(Int32(dataIn.getInt16()))
                }
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return Convert.convertToUInt32(Int32(dataIn.getInt8()))
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(string) <- MarshallingSupport.readUTF(dataIn)) {
                        return UInt32.parse(string)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to UInt32.")
                }
                throw MessageFormatException("Not a UInt32 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a UInt32 from Stream")
    }

    public override func writeUInt32(value: UInt32): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalInt32(Convert.convertToInt32(value), dataOut)
        }
    }

    public override func readInt64(): Int64 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.LONG_TYPE) {
                    return dataIn.getInt64()
                }
                if (dataType == MarshallingSupport.INTEGER_TYPE) {
                    return Int64(dataIn.getInt32())
                }
                if (dataType == MarshallingSupport.SHORT_TYPE) {
                    return Int64(dataIn.getInt16())
                }
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return Int64(dataIn.getInt8())
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(string) <- MarshallingSupport.readUTF(dataIn)) {
                        return Int64.parse(string)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Int64.")
                }
                throw MessageFormatException("Not a Int64 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Int64 from Stream")
    }

    public override func writeInt64(value: Int64): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalInt64(value, dataOut)
        }
    }

    public override func readUInt64(): UInt64 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.LONG_TYPE) {
                    return Convert.convertToUInt64(dataIn.getInt64())
                }
                if (dataType == MarshallingSupport.INTEGER_TYPE) {
                    return Convert.convertToUInt64(Int64(dataIn.getInt32()))
                }
                if (dataType == MarshallingSupport.SHORT_TYPE) {
                    return Convert.convertToUInt64(Int64(dataIn.getInt16()))
                }
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return Convert.convertToUInt64(Int64(dataIn.getInt8()))
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(string) <- MarshallingSupport.readUTF(dataIn)) {
                        return UInt64.parse(string)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to UInt64.")
                }
                throw MessageFormatException("Not a UInt64 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a UInt64 from Stream")
    }

    public override func writeUInt64(value: UInt64): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalInt64(Convert.convertToInt64(value), dataOut)
        }
    }

    public override func readString(): ?String {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.NULL) {
                    return None
                }
                if (dataType == MarshallingSupport.BIG_STRING_TYPE) {
                    return MarshallingSupport.readUTF8(dataIn)
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    return MarshallingSupport.readUTF(dataIn)
                }
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return dataIn.getByte().toString()
                }
                if (dataType == MarshallingSupport.BOOLEAN_TYPE) {
                    return MarshallingSupport.getBool(dataIn).toString()
                }
                if (dataType == MarshallingSupport.CHAR_TYPE) {
                    return Rune(dataIn.getUInt32()).toString()
                }
                if (dataType == MarshallingSupport.SHORT_TYPE) {
                    return dataIn.getInt16().toString()
                }
                if (dataType == MarshallingSupport.INTEGER_TYPE) {
                    return dataIn.getInt32().toString()
                }
                if (dataType == MarshallingSupport.LONG_TYPE) {
                    return dataIn.getInt64().toString()
                }
                if (dataType == MarshallingSupport.FLOAT_TYPE) {
                    return MarshallingSupport.getFloat32(dataIn).toString()
                }
                if (dataType == MarshallingSupport.DOUBLE_TYPE) {
                    return MarshallingSupport.getFloat64(dataIn).toString()
                }
                throw MessageFormatException("Not a string type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a String from Stream")
    }

    public override func writeString(value: ?String): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            if (let Some(value) <- value) {
                MarshallingSupport.marshalPrimitiveString(value, dataOut)
            } else {
                dataOut.putByte(UInt8(MarshallingSupport.NULL))
            }
        }
    }

    public override func readFloat32(): Float32 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.FLOAT_TYPE) {
                    return MarshallingSupport.getFloat32(dataIn)
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(str) <- MarshallingSupport.readUTF(dataIn)) {
                        return Float32.parse(str)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Float32.")
                }
                throw MessageFormatException("Not a Float32 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Float32 from Stream")
    }

    public override func writeFloat32(value: Float32): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalFloat32(value, dataOut)
        }
    }

    public override func readFloat64(): Float64 {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.FLOAT_TYPE) {
                    return Float64(MarshallingSupport.getFloat32(dataIn))
                }
                if (dataType == MarshallingSupport.DOUBLE_TYPE) {
                    return MarshallingSupport.getFloat64(dataIn)
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(str) <- MarshallingSupport.readUTF(dataIn)) {
                        return Float64.parse(str)
                    }
                }
                if (dataType == MarshallingSupport.NULL) {
                    throw MessageFormatException("Cannot convert NULL value to Float64.")
                }
                throw MessageFormatException("Not a Float64 type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a Float64 from Stream")
    }

    public override func writeFloat64(value: Float64): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalFloat64(value, dataOut)
        }
    }

    public override func readBytes(dest: Array<Byte>): Unit {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.BYTE_ARRAY_TYPE) {
                    dataIn.getInt32()
                    dataIn.get(dest)
                    return
                }
                throw MessageFormatException("Not a ByteArray type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
        throw MessageNotReadableException("Cannot read a ByteArray from Stream")
    }

    public override func writeBytes(value: Array<Byte>): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            MarshallingSupport.marshalByteArray(value, dataOut)
        }
    }

    public override func writeBytes(value: Array<Byte>, offset: Int32, length: Int32): Unit {
        let data = Array<Byte>(Int64(length), repeat: 0)
        value.copyTo(data, Int64(offset), 0, Int64(length))
        writeBytes(data)
    }

    public func readObject(): Any {
        initializeReading()
        if (let Some(dataIn) <- dataIn) {
            try {
                let dataType = dataIn.getInt8()
                if (dataType == MarshallingSupport.NULL) {
                    return None<Any>
                }
                if (dataType == MarshallingSupport.BIG_STRING_TYPE) {
                    if (let Some(utf8String) <- MarshallingSupport.readUTF8(dataIn)) {
                        return utf8String
                    }
                    return None<Any>
                }
                if (dataType == MarshallingSupport.STRING_TYPE) {
                    if (let Some(utf8String) <- MarshallingSupport.readUTF(dataIn)) {
                        return utf8String
                    }
                    return None<Any>
                }
                if (dataType == MarshallingSupport.LONG_TYPE) {
                    return dataIn.getInt64()
                }
                if (dataType == MarshallingSupport.INTEGER_TYPE) {
                    return dataIn.getInt32()
                }
                if (dataType == MarshallingSupport.SHORT_TYPE) {
                    return dataIn.getInt16()
                }
                if (dataType == MarshallingSupport.BYTE_TYPE) {
                    return dataIn.getByte()
                }
                if (dataType == MarshallingSupport.FLOAT_TYPE) {
                    return MarshallingSupport.getFloat32(dataIn)
                }
                if (dataType == MarshallingSupport.DOUBLE_TYPE) {
                    return MarshallingSupport.getFloat64(dataIn)
                }
                if (dataType == MarshallingSupport.BOOLEAN_TYPE) {
                    return MarshallingSupport.getBool(dataIn)
                }
                if (dataType == MarshallingSupport.CHAR_TYPE) {
                    return Rune(dataIn.getUInt32())
                }
                if (dataType == MarshallingSupport.BYTE_ARRAY_TYPE) {
                    let len = dataIn.getInt32()
                    let value = Array<Byte>(Int64(len), repeat: 0)
                    dataIn.get(value)
                    return value
                }
                throw MessageFormatException("Unknown type")
            } catch (e: IndexOutOfBoundsException) {
                throw ExceptionHelper.createMessageEOFException(e)
            }
        }
    }

    public func writeObject(value: Any): Unit {
        initializeWriting()
        if (let Some(dataOut) <- dataOut) {
            if (let Some(value) <- (value as Option<Any>)) {
                if (value.isNone()) {
                    dataOut.putByte(UInt8(MarshallingSupport.NULL))
                }
            } else if (let Some(str) <- (value as String)) {
                writeString(str)
            } else if (let Some(char) <- (value as Rune)) {
                writeChar(char)
            } else if (let Some(bool) <- (value as Bool)) {
                writeBool(bool)
            } else if (let Some(byte) <- (value as Byte)) {
                writeByte(byte)
            } else if (let Some(i8) <- (value as Int8)) {
                writeByte(Convert.convertToUInt8(i8))
            } else if (let Some(i16) <- (value as Int16)) {
                writeInt16(i16)
            } else if (let Some(u16) <- (value as UInt16)) {
                writeInt16(Convert.convertToInt16(u16))
            } else if (let Some(i32) <- (value as Int32)) {
                writeInt32(i32)
            } else if (let Some(u32) <- (value as UInt32)) {
                writeInt32(Convert.convertToInt32(u32))
            } else if (let Some(i64) <- (value as Int64)) {
                writeInt64(i64)
            } else if (let Some(u64) <- (value as UInt64)) {
                writeInt64(Convert.convertToInt64(u64))
            } else if (let Some(f32) <- (value as Float32)) {
                writeFloat32(f32)
            } else if (let Some(f64) <- (value as Float64)) {
                writeFloat64(f64)
            } else if (let Some(bytes) <- (value as Array<Byte>)) {
                writeBytes(bytes)
            } else {
                throw MessageFormatException("Unsupported Object type")
            }
        }
    }

    public override func storeContent() {
        if (let Some(dataOut) <- dataOut) {
            dataOut.flip()
            content = doCompress(dataOut.toArray())
            this.dataOut = None
        }
    }

    public override func reset(): Unit {
        storeContent()
        this.dataIn = None
        this.dataOut = None
        readOnlyBody = true
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQStreamMessage)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQStreamMessage)) {
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQStreamMessage)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQStreamMessage)) {
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
