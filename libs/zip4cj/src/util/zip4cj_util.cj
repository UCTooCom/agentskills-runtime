/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.util

public class Zip4cjUtil {
    private init(){}
    private static let DOSTIME_BEFORE_1980: Int64 = (1 << 21) | (1 << 16)

    private static let MAX_RAW_READ_FULLY_RETRY_ATTEMPTS: Int32 = 15

    public static func isStringNullOrEmpty(str: ?String): Bool {
        return str.isNone() || str.getOrThrow().trim().size == 0 || str.getOrThrow().trim() == "\0"
    }

    public static func isStringNotNullAndNotEmpty(str: ?String): Bool {
        return str != None && str.getOrThrow().trim().size > 0
    }

    public static func createDirectoryIfNotExists(file: Path): Bool {
        /* Temporal and Temporal Implementation */
        if (exists(file)) {
            if (!FileInfo(file).isDirectory()) {
                throw ZipException("${file} output directory is not valid")
            }
        } else {
            Directory.create(file, recursive: true)
        }
        return true
    }

    public static func epochToExtendedDosTime(time: Int64): Int64 {
        if (time < 0) {
            return DOSTIME_BEFORE_1980
        }
        let FileTime = DateTime.ofEpoch(second: time / 1000000000, nanosecond: 0)
        return (FileTime.year - 1980) << 25 |
                FileTime.month.value() << 21 |
                (FileTime.dayOfYear + 1) << 16 |
                (FileTime.hour * 2) << 11 |
                FileTime.minute << 5 |
                FileTime.second >> 1
    }

    private static func dosToEpochTime(dosTime: Int64): Int64 {
        let sec: Int64 = Int64(((dosTime << 1) & 0x3e))
        let min: Int64 = Int64((dosTime >> 5) & 0x3f)
        let hrs: Int64 = Int64(((dosTime >> 11) & 0x1f))
        let day: Int64 = Int64(((dosTime >> 16) & 0x1f))
        let mon: Int64 = Int64((((dosTime >> 21) & 0xf) - 1))
        let year: Int64 = Int64((((dosTime >> 25) & 0x7f) + 1980))

        var date: DateTime = DateTime.of(year: year, month: Month.of(mon), dayOfMonth: day, hour: hrs, minute: min,
            second: sec, nanosecond: 0)
        return date.toUnixTimeStamp().toMilliseconds()
    }

    public static func convertCharArrayToByteArray(charArray: Array<Rune>, useUtf8Charset: Bool): Array<Byte> {
        return if (useUtf8Charset) {
            convertCharArrayToByteArrayUsingUtf8(charArray)
        } else {
            convertCharArrayToByteArrayUsingDefaultCharset(charArray)
        }
    }

    public static func getCompressionMethod(localFileHeader: AbstractFileHeader): CompressionMethod {
        if (localFileHeader.getCompressionMethod().getOrThrow().getCode() !=
            CompressionMethod.AES_INTERNAL_ONLY.getCode()) {
            return localFileHeader.getCompressionMethod().getOrThrow()
        }
        match (localFileHeader.getAesExtraDataRecord()) {
            case None => throw ZipException("AesExtraDataRecord not present in local header for aes encrypted data")
            case Some(v) => return v.getCompressionMethod()
        }
    }

    public static func readFully(inputStream: InputStream, bufferToReadInto: Array<Byte>): Int64 {
        if (bufferToReadInto.size == 0) {
            return 0
        }
        var readLen: Int64 = inputStream.read(bufferToReadInto)
        if (readLen == 0) {
            throw ZipIOException("Unexpected EOF reached when trying to read stream")
        }
        if (Int64(readLen) != bufferToReadInto.size) {
            readLen = readUntilBufferIsFull(inputStream, bufferToReadInto, readLen)
            if (Int64(readLen) != bufferToReadInto.size) {
                throw ZipIOException("Cannot read fully into byte buffer")
            }
        }
        return readLen
    }

    public static func readFully(inputStream: InputStream, b: Array<Byte>, offset: Int64, length: Int64): Int64 {
        if (offset < 0) {
            throw IllegalArgumentException("Negative offset")
        }
        if (length < 0) {
            throw IllegalArgumentException("Negative length")
        }
        if (length == 0) {
            return 0
        }
        if (Int64(offset + length) > b.size) {
            throw IllegalArgumentException("Length greater than buffer size")
        }
        return inputStream.read(b[offset..offset + length])
    }

    private static func readUntilBufferIsFull(inputStream: InputStream, bufferToReadInto: Array<Byte>, readLength: Int64): Int64 {
        if (readLength < 0) {
            throw ZipIOException("Invalid readLength")
        }
        if (readLength == 0) {
            return 0
        }
        var remainingLength: Int64 = bufferToReadInto.size - readLength
        var loopReadLength: Int64 = 0

        // first attempt is already done before this method is called
        var retryAttempt: Int32 = 1
        var readLengthNew: Int64 = readLength
        while (readLengthNew < bufferToReadInto.size && loopReadLength != -1 && retryAttempt <
                MAX_RAW_READ_FULLY_RETRY_ATTEMPTS) {
            loopReadLength = inputStream.read(
                    bufferToReadInto[Int64(readLengthNew)..Int64(readLengthNew) + Int64(remainingLength)])
            if (loopReadLength > 0) {
                readLengthNew += loopReadLength
                remainingLength -= loopReadLength
            }
            retryAttempt++
        }
        return readLengthNew
    }

    private static func convertCharArrayToByteArrayUsingUtf8(charArray: Array<Rune>): Array<Byte> {
        try {
            return String(charArray).toArray()
        } catch (e: Exception) {
            return convertCharArrayToByteArrayUsingDefaultCharset(charArray)
        }
    }

    @OverflowWrapping
    private static func convertCharArrayToByteArrayUsingDefaultCharset(charArray: Array<Rune>): Array<Byte> {
        var bytes: Array<Byte> = Array<Byte>(charArray.size, repeat: 0)
        for (i in 0..charArray.size) {
            bytes[i] = UInt8(UInt32(charArray[i]))
        }
        return bytes
    }
}

