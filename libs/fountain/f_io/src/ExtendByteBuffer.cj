/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_io

import std.binary.*
import std.io.ByteBuffer
import f_base.*

public interface ExtendByteBuffer {
    func readBool(endian!: Endian): ?Bool
    func readUInt8(endian!: Endian): ?UInt8
    func readUInt16(endian!: Endian): ?UInt16
    func readUInt32(endian!: Endian): ?UInt32
    func readUInt64(endian!: Endian): ?UInt64

    func readInt8(endian!: Endian): ?Int8
    func readInt16(endian!: Endian): ?Int16
    func readInt32(endian!: Endian): ?Int32
    func readInt64(endian!: Endian): ?Int64

    func readFloat16(endian!: Endian): ?Float16
    func readFloat32(endian!: Endian): ?Float32
    func readFloat64(endian!: Endian): ?Float64

    func writeBool(value: Bool, endian!: Endian): Unit
    func writeUInt8(value: UInt8, endian!: Endian): Unit
    func writeUInt16(value: UInt16, endian!: Endian): Unit
    func writeUInt32(value: UInt32, endian!: Endian): Unit
    func writeUInt64(value: UInt64, endian!: Endian): Unit

    func writeInt8(value: Int8, endian!: Endian): Unit
    func writeInt16(value: Int16, endian!: Endian): Unit
    func writeInt32(value: Int32, endian!: Endian): Unit
    func writeInt64(value: Int64, endian!: Endian): Unit

    func writeFloat16(value: Float16, endian!: Endian): Unit
    func writeFloat32(value: Float32, endian!: Endian): Unit
    func writeFloat64(value: Float64, endian!: Endian): Unit
}

extend ByteBuffer <: ExtendByteBuffer {
    private func read<T>(len: Int64, endian: Endian): ?T where T <: BigEndianOrder<T> & LittleEndianOrder<T> {
        let bytes = Array<Byte>(len, repeat: 0)
        if (len == 0) {
            None
        } else {
            match (endian) {
                case Big => T.readBigEndian(bytes[0..len])
                case Little => T.readLittleEndian(bytes[0..len])
            }
        }
    }
    public func readBool(endian!: Endian = Endian.Platform): ?Bool {
        if (let Some(x) <- this.readByte()) {
            x != 0
        } else {
            None
        }
    }
    public func readUInt8(endian!: Endian = Endian.Platform): ?UInt8 {
        readByte()
    }
    public func readUInt16(endian!: Endian = Endian.Platform): ?UInt16 {
        read<UInt16>(2, endian)
    }
    public func readUInt32(endian!: Endian = Endian.Platform): ?UInt32 {
        read<UInt32>(4, endian)
    }
    public func readUInt64(endian!: Endian = Endian.Platform): ?UInt64 {
        read<UInt64>(8, endian)
    }
    public func readInt8(endian!: Endian = Endian.Platform): ?Int8 {
        readByte()?.toInt()
    }
    public func readInt16(endian!: Endian = Endian.Platform): ?Int16 {
        read<Int16>(2, endian)
    }
    public func readInt32(endian!: Endian = Endian.Platform): ?Int32 {
        read<Int32>(4, endian)
    }
    public func readInt64(endian!: Endian = Endian.Platform): ?Int64 {
        read<Int64>(8, endian)
    }

    public func readFloat16(endian!: Endian = Endian.Platform): ?Float16 {
        read<Float16>(2, endian)
    }
    public func readFloat32(endian!: Endian = Endian.Platform): ?Float32 {
        read<Float32>(4, endian)
    }
    public func readFloat64(endian!: Endian = Endian.Platform): ?Float64 {
        read<Float64>(8, endian)
    }

    private func write<T>(value: T, len: Int64, endian: Endian): Unit where T <: BigEndianOrder<T> & LittleEndianOrder<T> {
        let bytes = Array<Byte>(len, repeat: 0)
        match (endian) {
            case Big => value.writeBigEndian(bytes)
            case Little => value.writeLittleEndian(bytes)
        }
        write(bytes)
    }
    public func writeBool(value: Bool, endian!: Endian = Endian.Platform): Unit {
        writeUInt8(if (value) {
            1
        } else {
            0
        }, endian: endian)
    }
    public func writeUInt8(value: UInt8, endian!: Endian = Endian.Platform): Unit {
        writeByte(value)
    }
    public func writeUInt16(value: UInt16, endian!: Endian = Endian.Platform): Unit {
        write<UInt16>(value, 2, endian)
    }
    public func writeUInt32(value: UInt32, endian!: Endian = Endian.Platform): Unit {
        write<UInt32>(value, 4, endian)
    }
    public func writeUInt64(value: UInt64, endian!: Endian = Endian.Platform): Unit {
        write<UInt64>(value, 8, endian)
    }

    public func writeInt8(value: Int8, endian!: Endian = Endian.Platform): Unit {
        writeByte(value.toUInt())
    }
    public func writeInt16(value: Int16, endian!: Endian = Endian.Platform): Unit {
        write<Int16>(value, 2, endian)
    }
    public func writeInt32(value: Int32, endian!: Endian = Endian.Platform): Unit {
        write<Int32>(value, 4, endian)
    }
    public func writeInt64(value: Int64, endian!: Endian = Endian.Platform): Unit {
        write<Int64>(value, 8, endian)
    }

    public func writeFloat16(value: Float16, endian!: Endian = Endian.Platform): Unit {
        write<Float16>(value, 2, endian)
    }
    public func writeFloat32(value: Float32, endian!: Endian = Endian.Platform): Unit {
        write<Float32>(value, 4, endian)
    }
    public func writeFloat64(value: Float64, endian!: Endian = Endian.Platform): Unit {
        write<Float64>(value, 8, endian)
    }
}
