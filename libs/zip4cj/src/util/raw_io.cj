/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

public class RawIO {
    public let shortBuff = Array<Byte>(2, repeat: 0)
    public let intBuff = Array<Byte>(4, repeat: 0)
    public let longBuff = Array<Byte>(8, repeat: 0)

    public func readLongLittleEndian(randomAccessFile: RandomAccessFile): Int64 {
        randomAccessFile.readFully(longBuff)
        return readLongLittleEndian(longBuff, 0)
    }

    public func readLongLittleEndian(randomAccessFile: RandomAccessFile, readLen: Int64): Int64 {
        resetBytes(longBuff)
        randomAccessFile.readFully(longBuff[0..readLen])
        return readLongLittleEndian(longBuff, 0)
    }

    public func readLongLittleEndian(inputStream: InputStream): Int64 {
        readFully(inputStream, longBuff, longBuff.size)
        return readLongLittleEndian(longBuff, 0)
    }

    public func readLongLittleEndian(inputStream: InputStream, readLen: Int64): Int64 {
        resetBytes(longBuff)
        readFully(inputStream, longBuff, readLen)
        return readLongLittleEndian(longBuff, 0)
    }

    public func readLongLittleEndian(array: Array<Byte>, pos: Int64) {
        if (array.size - pos < 8) {
            resetBytes(longBuff)
        }
        ArrayCopy(array, pos, longBuff, 0, min(array.size - pos, 8))

        var temp = 0
        temp |= Int64(longBuff[7] & 0xff)
        temp <<= 8
        temp |= Int64(longBuff[6] & 0xff)
        temp <<= 8
        temp |= Int64(longBuff[5] & 0xff)
        temp <<= 8
        temp |= Int64(longBuff[4] & 0xff)
        temp <<= 8
        temp |= Int64(longBuff[3] & 0xff)
        temp <<= 8
        temp |= Int64(longBuff[2] & 0xff)
        temp <<= 8
        temp |= Int64(longBuff[1] & 0xff)
        temp <<= 8
        temp |= Int64(longBuff[0] & 0xff)
        return temp
    }

    public func readIntLittleEndian(randomAccessFile: RandomAccessFile): Int32 {
        randomAccessFile.readFully(intBuff)
        return readIntLittleEndian(intBuff)
    }

    public func readIntLittleEndian(inputStream: InputStream): Int32 {
        readFully(inputStream, intBuff, 4)
        return readIntLittleEndian(intBuff)
    }

    public func readIntLittleEndian(b: Array<Byte>): Int32 {
        return readIntLittleEndian(b, 0)
    }

    public func readIntLittleEndian(b: Array<Byte>, pos: Int64): Int32 {
        return (Int32(b[pos] & 0xff) | Int32(b[1 + pos] & 0xff) << 8) |
            (Int32(b[2 + pos] & 0xff) | Int32(b[3 + pos] & 0xff) << 8) << 16
    }

    public func readShortLittleEndian(randomAccessFile: RandomAccessFile): Int32 {
        randomAccessFile.readFully(shortBuff)
        return readShortLittleEndian(shortBuff, 0)
    }

    public func readShortLittleEndian(inputStream: InputStream): Int32 {
        readFully(inputStream, shortBuff, shortBuff.size)
        return readShortLittleEndian(shortBuff, 0)
    }

    public func readShortLittleEndian(buff: Array<Byte>, position: Int64): Int32 {
        return Int32(buff[position] & 0xff) | Int32(buff[1 + position] & 0xff) << 8
    }

    public func writeShortLittleEndian(outputStream: OutputStream, value: Int32): Unit {
        writeShortLittleEndian(shortBuff, 0, value)
        outputStream.write(shortBuff)
    }

    @OverflowWrapping
    public func writeShortLittleEndian(array: Array<Byte>, pos: Int64, value: Int32): Unit {
        array[pos + 1] = UInt8(value[8])
        array[pos] = UInt8(value & 0xFF)
    }

    public func writeIntLittleEndian(outputStream: OutputStream, value: Int32): Unit {
        writeIntLittleEndian(intBuff, 0, value)
        outputStream.write(intBuff)
    }

    @OverflowWrapping
    public func writeIntLittleEndian(array: Array<Byte>, pos: Int64, value: Int32): Unit {
        array[pos + 3] = UInt8(value[24])
        array[pos + 2] = UInt8(value[16])
        array[pos + 1] = UInt8(value[8])
        array[pos] = UInt8(value & 0xFF)
    }

    public func writeLongLittleEndian(outputStream: OutputStream, value: Int64): Unit {
        writeLongLittleEndian(longBuff, 0, value)
        outputStream.write(longBuff)
    }

    @OverflowWrapping
    public func writeLongLittleEndian(array: Array<Byte>, pos: Int64, value: Int64): Unit {
        array[pos + 7] = UInt8(value[56])
        array[pos + 6] = UInt8(value[48])
        array[pos + 5] = UInt8(value[40])
        array[pos + 4] = UInt8(value[32])
        array[pos + 3] = UInt8(value[24])
        array[pos + 2] = UInt8(value[16])
        array[pos + 1] = UInt8(value[8])
        array[pos] = UInt8(value & 0xFF)
    }

    private func readFully(inputStream: InputStream, buff: Array<Byte>, readLen: Int64): Unit {
        var actualReadLength = Zip4cjUtil.readFully(inputStream, buff, 0, readLen)
        if (actualReadLength != readLen) {
            throw ZipException("Could not fill buffer")
        }
    }

    private func resetBytes(b: Array<Byte>) {
        fill(b, 0)
    }
}
