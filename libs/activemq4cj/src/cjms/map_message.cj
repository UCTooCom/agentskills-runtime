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

public interface MapMessage <: Message {
    func getBool(name: String): Bool

    func getByte(name: String): Byte

    func getInt8(name: String): Int8

    func getInt16(name: String): Int16

    func getUInt16(name: String): UInt16

    func getChar(name: String): Rune

    func getInt32(name: String): Int32

    func getUInt32(name: String): UInt32

    func getInt64(name: String): Int64

    func getUInt64(name: String): UInt64

    func getFloat32(name: String): Float32

    func getFloat64(name: String): Float64

    func getString(name: String): ?String

    func getBytes(name: String): ?Array<Byte>

    func getObject(name: String): Any

    func getMapNames(): ?LinkedList<String>

    func setBool(name: String, value: Bool): Unit

    func setByte(name: String, value: Byte): Unit

    func setInt8(name: String, value: Int8): Unit

    func setInt16(name: String, value: Int16): Unit

    func setUInt16(name: String, value: UInt16): Unit

    func setChar(name: String, value: Rune): Unit

    func setInt32(name: String, value: Int32): Unit

    func setUInt32(name: String, value: UInt32): Unit

    func setInt64(name: String, value: Int64): Unit

    func setUInt64(name: String, value: UInt64): Unit

    func setFloat32(name: String, value: Float32): Unit

    func setFloat64(name: String, value: Float64): Unit

    func setString(name: String, value: ?String): Unit

    func setBytes(name: String, value: ?Array<Byte>): Unit

    func setBytes(name: String, value: Array<Byte>, offset: Int32, length: Int32): Unit

    func setObject(name: String, value: ?Any): Unit

    func itemExists(name: String): Bool
}
