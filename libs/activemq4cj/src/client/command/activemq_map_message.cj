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

public class ActiveMQMapMessage <: ActiveMQMessage & MapMessage {
    private var map: HashMap<String, Any> = HashMap<String, Any>()

    public func getDataStructureType(): Byte {
        return CommandTypes.ACTIVEMQ_MAP_MESSAGE
    }

    public override func beforeMarshall(): Unit {
        super.beforeMarshall()
        storeContent()
    }

    public func copy(): Message {
        let copy: ActiveMQMapMessage = ActiveMQMapMessage()
        this.copy(copy)
        return copy
    }

    private func copy(copy: ActiveMQMapMessage): Unit {
        storeContent()
        super.copy(copy)
    }

    public override func clearBody(): Unit {
        super.clearBody()
        this.map.clear()
    }

    public override func itemExists(name: String): Bool {
        initializeReading()
        return map.contains(name)
    }

    public override func getMapNames(): ?LinkedList<String> {
        initializeReading()
        return LinkedList<String>(map.keys().toArray())
    }

    public override func getBool(name: String): Bool {
        initializeReading()
        if (let Some(val) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<Bool>(val, TypeInfo.of<Bool>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a Bool")
            }
        }
        return false
    }

    public override func setBool(name: String, value: Bool): Unit {
        initializeWriting()
        put(name, value)
    }

    public override func getChar(name: String): Rune {
        initializeReading()
        let value = map.get(name)
        if (let Some(val) <- value) {
            if (let Some(char) <- (val as Rune)) {
                return char
            }
            if (let Some(value) <- (val as UInt32)) {
                //并非所有的有效u32都是有效的char
                return Rune(value)
            }
            throw MessageFormatException("Cannot read a Char")
        }
        throw MessageFormatException("Cannot read a Char from a None value")
    }

    public override func setChar(name: String, value: Rune): Unit {
        initializeWriting()
        put(name, value)
    }

    public override func getByte(name: String): Byte {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<Byte>(value, TypeInfo.of<Byte>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a Byte")
            }
        }
        return 0
    }

    public func setByte(name: String, value: Byte): Unit {
        initializeWriting()
        put(name, value)
    }

    public override func getInt8(name: String): Int8 {
        initializeReading()
        let value = map.get(name)
        if (let Some(value) <- value) {
            try {
                return TypeConversionSupport.genericConvert<Int8>(value, TypeInfo.of<Int8>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a Int8")
            }
        }
        return 0
    }

    public func setInt8(name: String, value: Int8): Unit {
        initializeWriting()
        put(name, Convert.convertToUInt8(value))
    }

    public override func getInt16(name: String): Int16 {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<Int16>(value, TypeInfo.of<Int16>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a Int16")
            }
        }
        return 0
    }

    public override func setInt16(name: String, value: Int16): Unit {
        initializeWriting()
        put(name, value)
    }

    public override func getUInt16(name: String): UInt16 {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<UInt16>(value, TypeInfo.of<UInt16>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a UInt16")
            }
        }
        return 0
    }

    public override func setUInt16(name: String, value: UInt16): Unit {
        initializeWriting()
        put(name, Convert.convertToInt16(value))
    }

    public override func getInt32(name: String): Int32 {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<Int32>(value, TypeInfo.of<Int32>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a Int32")
            }
        }
        return 0
    }

    public override func setInt32(name: String, value: Int32): Unit {
        initializeWriting()
        put(name, value)
    }

    public override func getUInt32(name: String): UInt32 {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<UInt32>(value, TypeInfo.of<UInt32>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a UInt32")
            }
        }
        return 0
    }

    public override func setUInt32(name: String, value: UInt32): Unit {
        initializeWriting()
        put(name, Convert.convertToInt32(value))
    }

    public override func getInt64(name: String): Int64 {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<Int64>(value, TypeInfo.of<Int64>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a Int64")
            }
        }
        return 0
    }

    public override func setInt64(name: String, value: Int64): Unit {
        initializeWriting()
        put(name, value)
    }

    public override func getUInt64(name: String): UInt64 {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<UInt64>(value, TypeInfo.of<UInt64>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a UInt64")
            }
        }
        return 0
    }

    public override func setUInt64(name: String, value: UInt64): Unit {
        initializeWriting()
        put(name, Convert.convertToInt64(value))
    }

    public override func getFloat32(name: String): Float32 {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<Float32>(value, TypeInfo.of<Float32>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a Float32")
            }
        }
        return Float32(0)
    }

    public override func setFloat32(name: String, value: Float32): Unit {
        initializeWriting()
        put(name, value)
    }

    public override func getFloat64(name: String): Float64 {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            try {
                return TypeConversionSupport.genericConvert<Float64>(value, TypeInfo.of<Float64>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a Float64")
            }
        }
        return Float64(0)
    }

    public override func setFloat64(name: String, value: Float64): Unit {
        initializeWriting()
        put(name, value)
    }

    public override func getString(name: String): ?String {
        initializeReading()
        let value = map.get(name)
        if (let Some(str) <- value) {
            if (let Some(str) <- (str as String)) {
                return str
            }

            if (let Some(char) <- (str as Rune)) {
                return char.toString()
            }

            if (str is Array<Byte>) {
                throw MessageFormatException("Use getBytes to read a byte array")
            }

            try {
                return TypeConversionSupport.genericConvert<String>(value, TypeInfo.of<String>())
            } catch (e: IllegalArgumentException) {
                throw MessageFormatException("Cannot read a String")
            }
        }
        return None
    }

    public override func setString(name: String, value: ?String): Unit {
        initializeWriting()
        if (let Some(value) <- value) {
            put(name, value)
        } else {
            put(name, None<Any>)
        }
    }

    public override func getBytes(name: String): ?Array<Byte> {
        initializeReading()
        let value = map.get(name)
        if (let Some(value) <- value) {
            if (let Some(value) <- (value as Array<Byte>)) {
                return value
            }
            throw MessageFormatException("Cannot read a byte array")
        }
        return None
    }

    public override func setBytes(name: String, value: ?Array<Byte>): Unit {
        initializeWriting()
        if (let Some(value) <- value) {
            put(name, value)
        } else {
            map.remove(name)
        }
    }

    public override func setBytes(name: String, value: Array<Byte>, offset: Int32, length: Int32): Unit {
        initializeWriting()
        let data = Array<Byte>(Int64(length), repeat: 0)
        value.copyTo(data, Int64(offset), 0, Int64(length))
        put(name, data)
    }

    public override func getObject(name: String): Any {
        initializeReading()
        if (let Some(value) <- map.get(name)) {
            return value
        }
        return None<Any>
    }

    public override func setObject(name: String, vaue: ?Any): Unit {
        initializeWriting()
        if (let Some(value) <- vaue) {
            if (!(value is Array<Byte>)) {
                checkValidObject(value)
            }
            put(name, value)
        } else {
            put(name, None<Any>)
        }
    }

    private func initializeWriting(): Unit {
        checkReadOnlyBody()
        this.content = None
    }

    private func initializeReading(): Unit {
        if (this.content.isSome() && map.isEmpty()) {
            if (let Some(content) <- this.content) {
                if (let Some(map) <- MarshallingSupport.unmarshalPrimitiveMap(ByteBuffer.wrap(doDecompress(content)))) {
                    this.map = map
                }
            }
        }
    }

    protected func put(name: String, value: Any): Unit {
        let trimName = name.trimAscii()
        if (trimName.isEmpty()) {
            throw IllegalArgumentException("The name of the property cannot be an emprty string.")
        }
        map.add(trimName, value)
    }

    public func storeContent(): Unit {
        if (this.content.isNone() && !this.map.isEmpty()) {
            let dataOut = ByteBuffer.allocate(8192, expandSupport: true)
            MarshallingSupport.marshalPrimitiveMap(map, dataOut)
            dataOut.flip()
            this.content = doCompress(dataOut.toArray())
            this.map.clear()
        }
    }

    public operator override func ==(other: DataStructure): Bool {
        if (!(other is ActiveMQMapMessage)) {
            return false
        }
        if (let Some(other) <- (other as ActiveMQMapMessage)) {
            if (!super.checkEquals(other)) {
                return false
            }
        }
        return true
    }

    public operator override func !=(other: DataStructure): Bool {
        if (!(other is ActiveMQMapMessage)) {
            return true
        }
        if (let Some(other) <- (other as ActiveMQMapMessage)) {
            if (!super.checkEquals(other)) {
                return true
            }
        }
        return false
    }
}
