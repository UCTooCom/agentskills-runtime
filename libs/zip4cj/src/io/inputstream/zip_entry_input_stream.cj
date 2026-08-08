/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

public class ZipEntryInputStream <: InputStream & Resource {
    private static let MAX_RAW_READ_FULLY_RETRY_ATTEMPTS: Int64 = 15

    private var inputStream: InputStream
    private var numberOfBytesRead: Int64 = 0
    private var singleByteArray: Array<Byte> = [1]
    private var compressedSize: Int64
    var closed = false
    public init(inputStream: InputStream, compressedSize: Int64) {
        this.inputStream = inputStream
        this.compressedSize = compressedSize
    }

    public func read(b: Array<Byte>): Int64 {
        return read(b, 0, b.size)
    }

    func read(b: Array<Byte>, off: Int64, len: Int64): Int64 {
        var length = len
        if (compressedSize != -1) {
            if (numberOfBytesRead >= compressedSize) {
                return -1
            }
            if (length > compressedSize - numberOfBytesRead) {
                length = compressedSize - numberOfBytesRead
            }
        }
        var readLen: Int64 = inputStream.read(b[off..off + length]) //read(b, off, len)
        if (readLen > 0) {
            numberOfBytesRead += readLen
        }
        return readLen
    }

    public func readRawFully(b: Array<Byte>): Int64 {
        var readLen: Int64 = inputStream.read(b)

        if (readLen == -1) {
            throw ZipIOException("Unexpected EOF reached when trying to read stream")
        }

        if (readLen != b.size) {
            readLen = readUntilBufferIsFull(b, readLen)

            if (readLen != b.size) {
                throw ZipIOException("Cannot read fully into byte buffer")
            }
        }

        return readLen
    }

    private func readUntilBufferIsFull(b: Array<Byte>, readLength: Int64): Int64 {
        var readlength = readLength
        var remainingLength: Int64 = b.size - readlength
        var loopReadLength = 0
        var retryAttempt = 0

        while (readlength < b.size && loopReadLength != -1 && retryAttempt < MAX_RAW_READ_FULLY_RETRY_ATTEMPTS) {
            loopReadLength += inputStream.read(b) //read(b, readLength, remainingLength)

            if (loopReadLength > 0) {
                readlength += loopReadLength
                remainingLength -= loopReadLength
            }

            retryAttempt++
        }

        return readlength
    }

    public func close(): Unit {
        match ((this.inputStream as Resource)) {
            case Some(v) => v.close()
            case _ => ()
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func getNumberOfBytesRead(): Int64 {
        return numberOfBytesRead
    }
}
