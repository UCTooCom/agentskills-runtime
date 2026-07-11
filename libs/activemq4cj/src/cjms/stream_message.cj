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

public interface StreamMessage <: Message {
    func readBool(): Bool

    func readByte(): Byte

    func readInt8(): Int8

    func readInt16(): Int16

    func readUInt16(): UInt16

    func readChar(): Rune

    func readInt32(): Int32

    func readUInt32(): UInt32

    func readInt64(): Int64

    func readUInt64(): UInt64

    func readFloat32(): Float32

    func readFloat64(): Float64

    func readString(): ?String

    func readBytes(dest: Array<Byte>): Unit

    func readObject(): Any

    func writeBool(value: Bool): Unit

    func writeByte(value: Byte): Unit

    func writeInt8(value: Int8): Unit

    func writeInt16(value: Int16): Unit

    func writeUInt16(value: UInt16): Unit

    func writeChar(value: Rune): Unit

    func writeInt32(value: Int32): Unit

    func writeUInt32(value: UInt32): Unit

    func writeInt64(value: Int64): Unit

    func writeUInt64(value: UInt64): Unit

    func writeFloat32(value: Float32): Unit

    func writeFloat64(value: Float64): Unit

    func writeString(value: ?String): Unit

    func writeBytes(value: Array<Byte>): Unit

    func writeBytes(value: Array<Byte>, offset: Int32, length: Int32): Unit

    func writeObject(value: Any): Unit

    func reset(): Unit
}
